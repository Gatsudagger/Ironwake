// =============================================================================
// obj_combat_controller — Create event
// Bootstraps a single combat encounter: builds the player struct, clones
// enemies, runs combat_init, and sets up all controller state.
// =============================================================================


// -----------------------------------------------------------------------------
// 1. BUILD PLAYER STRUCT
// -----------------------------------------------------------------------------

// Read the class and stats chosen on the character selection screen.
// Falls back to a default Arcanist if the globals are not set (e.g. the room
// is entered directly during development without passing through obj_char_select).
var _class_id;
if (variable_global_exists("chosen_class")) {
    _class_id = global.chosen_class;
} else {
    _class_id = 0;
}
var _base_stats;
if (variable_global_exists("chosen_stats") && !is_undefined(global.chosen_stats)) {
    _base_stats = global.chosen_stats;
} else {
    // Fallback: rebuild from the resolved class (NOT hardcoded 0) so a missing
    // chosen_stats can't silently turn every class into an Arcanist.
    _base_stats = stats_init(_class_id);
}

// Copy stats into a fresh struct so equipment bonuses never mutate global.chosen_stats
var _stats = {
    class_id:    _base_stats.class_id,
    class_name:  _base_stats.class_name,
    STR:         _base_stats.STR,
    DEX:         _base_stats.DEX,
    CON:         _base_stats.CON,
    INT:         _base_stats.INT,
    WIS:         _base_stats.WIS,
    CHA:         _base_stats.CHA,
    free_points: _base_stats.free_points,
};

// Apply equipped gear stat bonuses to the copy; returns armor/el_resist totals
var _equip_bonus = apply_equipment_stats(_stats);

// Add run stat bonuses (XP-leveling point spending within this run)
if (variable_global_exists("run_stat_bonuses")) {
    _stats.STR += global.run_stat_bonuses.STR;
    _stats.DEX += global.run_stat_bonuses.DEX;
    _stats.CON += global.run_stat_bonuses.CON;
    _stats.INT += global.run_stat_bonuses.INT;
    _stats.WIS += global.run_stat_bonuses.WIS;
    _stats.CHA += global.run_stat_bonuses.CHA;
}

// Add permanent meta-progression bonuses
if (variable_global_exists("perm_str_bonus")) {
    _stats.STR += global.perm_str_bonus;
    _stats.DEX += global.perm_dex_bonus;
    _stats.CON += global.perm_con_bonus;
    _stats.INT += global.perm_int_bonus;
    _stats.WIS += global.perm_wis_bonus;
    _stats.CHA += global.perm_cha_bonus;
}

// Calculate derived combat values from the modified copy
var _derived = stats_derive(_stats);

// Reach-gated weapon damage (SYSTEMS_WEAPON_ROLES.md §B) rides on derived so the
// cast resolver can add it by the ability's reach class. Equipment-sourced, not stat-derived.
_derived.melee_dmg_bonus  = _equip_bonus.melee_dmg_bonus;
_derived.ranged_dmg_bonus = _equip_bonus.ranged_dmg_bonus;

// Assemble the player combat struct.
// HP and DODGE come from derived values; armor and el_resist are from the
// starting equipment (robe or leathers, +1 each).
player = {
    name:       (variable_global_exists("player_name") ? global.player_name : "Hero"),
    is_player:  true,
    class_id:   _class_id,

    // Vitals
    HP:         _derived.HP,
    max_HP:     _derived.HP,

    // Mitigation — base 1 each; equipment bonuses stored separately for Step application
    armor:           1,
    el_resist:       1,
    equip_armor:     _equip_bonus.armor,
    equip_el_resist: _equip_bonus.el_resist,

    // Hit and evasion
    dodge:      _derived.DODGE,
    acc:        _derived.ACC_modifier,

    // Action economy — restored to 3 at the start of each turn
    energy:     3,

    // Checked by the turn queue UI and the combat engine defeat logic
    is_defeated: false,

    // Flat damage reduction applied after armor (set by Iron Skin, reset on expiry)
    damage_reduction: 0,

    // Defensive status flags — set by Blink and Shadow Step abilities
    is_untargetable:    false,
    untargetable_turns: 0,
    shadow_step_active: false,

    // Buff duration trackers (read by HUD for status icon display)
    iron_skin_duration:  0,
    bloodthorn_active:   false,
    bloodthorn_duration: 0,
    bloodthorn_value:    0,

    // Typed status layer (vulnerable/weaken/blind/mortality/stun/dot) + shield pool.
    // Lets debuffs land on the player too; shield_hp absorbs damage before HP.
    status_effects: [],
    shield_hp:      0,

    // Raw stats struct — crit functions read STR/DEX/INT/WIS from here
    stats:      _stats,

    // Derived combat values — flat damage bonuses, reductions, crit ceilings
    derived:    _derived,
};

// Restore HP carried from the previous room, or record full HP for room 1
if (variable_global_exists("run_current_hp") && global.run_current_hp > 0) {
    player.HP = min(global.run_current_hp, player.max_HP);
} else {
    global.run_current_hp = player.max_HP;
}

// Apply rest-site heal (granted by floor rest rooms)
if (variable_global_exists("pending_rest_heal") && global.pending_rest_heal > 0) {
    player.HP = min(player.HP + global.pending_rest_heal, player.max_HP);
    global.pending_rest_heal = 0;
}

// Apply trap damage (dealt by floor trap rooms)
if (variable_global_exists("pending_trap_damage") && global.pending_trap_damage > 0) {
    player.HP = max(1, player.HP - global.pending_trap_damage);
    global.pending_trap_damage = 0;
}

// Attach secondary resource fields based on class; abilities come from the
// shared abilities_get_loadout() so the menu and combat always show the same set.
switch (_class_id) {
    case 0: // Arcanist — Souls
        player.souls     = 0;
        player.souls_max = 10;
        break;

    case 1: // Bloodwarden — Blood
        player.blood     = 0;
        player.blood_max = 10;
        break;

    case 2: // Shadowstrider — Preparation
        player.preparation     = 0;
        player.preparation_max = 10;
        player.trap_active     = false;
        break;
}
// Build abilities from the player's confirmed loadout, or fall back to class defaults
var _ab_pool_cc = abilities_class_pool(_class_id);   // class abilities + general pool
var _loadout_valid = false;
if (variable_global_exists("player_loadout") && global.player_loadout[0] != "") {
    var _loadout_max_cc = trait_active("Expanded Arsenal") ? 5 : 4;
    player.abilities = [];
    for (var _li = 0; _li < _loadout_max_cc; _li++) {
        var _lname = global.player_loadout[_li];
        if (_lname == "") continue;
        for (var _ai = 0; _ai < array_length(_ab_pool_cc); _ai++) {
            if (_ab_pool_cc[_ai].name == _lname) {
                array_push(player.abilities, _ab_pool_cc[_ai]);
                break;
            }
        }
    }
    _loadout_valid = (array_length(player.abilities) >= 4 && array_length(player.abilities) <= _loadout_max_cc);
}
if (!_loadout_valid) {
    player.abilities = abilities_get_loadout(_class_id);
}

// Per-combat ability cooldown counters (turns), one slot per loadout ability.
// Decremented at the start of each player turn; set when a cooldown ability
// (Blink / Shadow Step) is cast. Kept off the shared ability struct on purpose.
player.ability_cd = array_create(array_length(player.abilities), 0);

// Restore secondary resources carried from the previous room
if (variable_global_exists("run_souls") && player.class_id == 0) {
    player.souls = min(global.run_souls, player.souls_max);
}
if (variable_global_exists("run_blood") && player.class_id == 1) {
    player.blood = min(global.run_blood, player.blood_max);
}
if (variable_global_exists("run_preparation") && player.class_id == 2) {
    player.preparation = min(global.run_preparation, player.preparation_max);
}

// Apply special equipment bonus fields from affix system
player.max_HP += _equip_bonus.bonus_max_hp;
if (_equip_bonus.bonus_max_hp > 0) {
    player.HP = min(player.HP + _equip_bonus.bonus_max_hp, player.max_HP);
}

// Boons: Ironhide (+20% max HP) / Glass Cannon (-15% max HP).
var _boon_hpm = boon_maxhp_mult();
if (_boon_hpm != 1.0) {
    player.max_HP = max(1, round(player.max_HP * _boon_hpm));
    player.HP     = min(player.HP, player.max_HP);
}
// Curses: Frail / Ruin / Devil's Pact reduce max HP (devil's bargain).
var _curse_hpm = curse_maxhp_mult();
if (_curse_hpm != 1.0) {
    player.max_HP = max(1, round(player.max_HP * _curse_hpm));
    player.HP     = min(player.HP, player.max_HP);
}
player.dodge += _equip_bonus.dodge_flat;
// crit_flat stored in stats so combat_roll_crit can read it from attacker_stats
player.stats.crit_bonus = _equip_bonus.crit_flat;
// gold_find stored for future hook; add_gold will check this when implemented
player.gold_find_pct = _equip_bonus.gold_find;

// Detect equipped legendary unique effects
player.gatewarden_brand  = false;  // first ability each combat costs 0 AP
player.heartstone_aegis  = false;  // heal 5 HP on enemy death
player.thief_of_hours    = false;  // +1 AP on first player turn
player.crown_hollow_king = false;  // +1 trait slot (hub loadout screen)
player.gatewarden_used   = false;  // tracks if the 0-AP proc is available this combat

// Class-weapon ability affixes (set by equipped class-locked weapons; see obj_game_controller/Create_0)
player.cf_first_spell_ap  = false;  // Cracked Focus  — first spell each combat costs 1 less AP (min 1)
player.cf_used            = false;  // tracks whether that discount has fired this combat
player.spell_dmg_bonus    = 0;      // Vaultstone Wand — outgoing spell damage % (e.g. 0.12)
player.spell_crit_ap      = false;  // Void Scepter   — spell crit restores 1 AP
player.weapon_lifesteal   = 0;      // Gravelstone Sword — heal % of melee damage dealt
player.weapon_start_shield = 0;     // Ashkeeper Blade — shield_hp granted at combat start
player.weapon_crit_bonus  = 0;      // Shadow Sickle  — flat % added to crit rolls
player.kill_ap_refund     = false;  // Serpent's Reach — killing an enemy refunds 1 AP

for (var _li = 0; _li < array_length(global.inventory); _li++) {
    var _lit = global.inventory[_li];
    if (_lit == undefined) continue;
    if (!variable_struct_exists(_lit, "unique_effect") || _lit.unique_effect == "") continue;
    if (_lit.unique_effect == "gatewarden_brand")  { player.gatewarden_brand  = true; player.gatewarden_used = false; }
    if (_lit.unique_effect == "heartstone_aegis")  player.heartstone_aegis  = true;
    if (_lit.unique_effect == "thief_of_hours")    player.thief_of_hours    = true;
    if (_lit.unique_effect == "crown_hollow_king") player.crown_hollow_king = true;
    // Class-weapon affixes
    if (_lit.unique_effect == "class_first_spell_ap") player.cf_first_spell_ap   = true;
    if (_lit.unique_effect == "class_spell_dmg")      player.spell_dmg_bonus     = 0.12;
    if (_lit.unique_effect == "class_spell_crit_ap")  player.spell_crit_ap       = true;
    if (_lit.unique_effect == "class_lifesteal")      player.weapon_lifesteal    = 0.10;
    if (_lit.unique_effect == "class_start_shield")   player.weapon_start_shield = 12;
    if (_lit.unique_effect == "class_crit")           player.weapon_crit_bonus   = 8;
    if (_lit.unique_effect == "class_kill_ap")        player.kill_ap_refund      = true;
}

// Thief of Hours: start first turn with +1 AP
if (player.thief_of_hours) {
    player.energy = 4;
}

// Ashkeeper Blade: start each combat with a shield (stacks with any other shield grant)
if (player.weapon_start_shield > 0) {
    player.shield_hp += player.weapon_start_shield;
}

// Apply trait effects that modify combat start state.
// Must run after secondary resources are set (Crimson Reserve needs blood),
// and after HP restoration (Thick Skin adds to the restored HP value).
if (variable_global_exists("player_traits")) {
    combat_apply_start_traits(player);
}

// Damnation curse: begin every combat at a reduced HP fraction (applied last, after
// all max-HP changes and start-of-combat heals/shields are resolved).
var _dmn_frac = curse_combat_start_hp_frac();
if (_dmn_frac < 1.0) {
    player.HP = min(player.HP, ceil(player.max_HP * _dmn_frac));
}


// -----------------------------------------------------------------------------
// 2. CLONE ENEMIES
// -----------------------------------------------------------------------------

// Always clone templates — never pass the template directly into combat, or
// stat mutations (damage taken, status effects) will persist across encounters.
// Enemy pool is chosen by global.next_enemy_type set by obj_floor_controller.
var _enemy_type;
if (variable_global_exists("next_enemy_type")) {
    _enemy_type = global.next_enemy_type;
} else {
    _enemy_type = "standard";
}
var enemy1;
var enemy2;

// Route to the correct dungeon enemy pools
var _dung = variable_global_exists("selected_dungeon") ? global.selected_dungeon : "ashen_vault";
var _std_pool, _eli_pool;
switch (_dung) {
    case "scorched_depths":
        _std_pool = global.enemies_scorched_depths_standard;
        _eli_pool = global.enemies_scorched_depths_elite;
        break;
    case "tundra_tomb":
        _std_pool = global.enemies_tundra_tomb_standard;
        _eli_pool = global.enemies_tundra_tomb_elite;
        break;
    default:
        _std_pool = global.enemies_ashen_vault_standard;
        _eli_pool = global.enemies_ashen_vault_elite;
        break;
}

if (_enemy_type == "elite") {
    var _elite_idx   = irandom(array_length(_eli_pool) - 1);
    var _support_idx = irandom(array_length(_std_pool) - 1);
    enemy1 = enemy_clone(_eli_pool[_elite_idx]);
    enemy2 = enemy_clone(_std_pool[_support_idx]);

} else if (_enemy_type == "boss") {
    var _floor = variable_global_exists("current_floor") ? global.current_floor : 1;

    if (_dung == "scorched_depths") {
        if (_floor == 1) {
            enemy1 = enemy_clone(_eli_pool[0]);
            enemy1.name             = "Forge Tyrant";
            enemy1.HP               = 85; enemy1.max_HP = 85;
            enemy1.damage           = 13;
            enemy1.telegraph_turn   = 3; enemy1.telegraph_damage = 20;
            enemy1.armor            = 8; enemy1.el_resist = 5;
            enemy1.mechanic_type    = "fortify";
            enemy1.mechanic_value   = 0.5; enemy1.mechanic_turns = 3;
        } else if (_floor == 2) {
            enemy1 = enemy_clone(_eli_pool[1]);
            enemy1.name             = "Molten Revenant";
            enemy1.HP               = 110; enemy1.max_HP = 110;
            enemy1.damage           = 16;
            enemy1.telegraph_turn   = 4; enemy1.telegraph_damage = 24;
            enemy1.armor            = 6; enemy1.el_resist = 9;
            enemy1.mechanic_type    = "death_burst";
            enemy1.mechanic_value   = 15;
        } else {
            enemy1 = enemy_clone(_eli_pool[0]);
            enemy1.name             = "The Ashen Colossus";
            enemy1.HP               = 150; enemy1.max_HP = 150;
            enemy1.damage           = 19;
            enemy1.telegraph_turn   = 3; enemy1.telegraph_damage = 30;
            enemy1.armor            = 12; enemy1.el_resist = 8;
            enemy1.mechanic_type    = "fortify";
            enemy1.mechanic_value   = 0.5; enemy1.mechanic_turns = 4;
        }
    } else if (_dung == "tundra_tomb") {
        if (_floor == 1) {
            enemy1 = enemy_clone(_eli_pool[0]);
            enemy1.name             = "Glacial Warden";
            enemy1.HP               = 82; enemy1.max_HP = 82;
            enemy1.damage           = 12;
            enemy1.telegraph_turn   = 3; enemy1.telegraph_damage = 19;
            enemy1.armor            = 9; enemy1.el_resist = 6;
            enemy1.mechanic_type    = "fortify";
            enemy1.mechanic_value   = 0.5; enemy1.mechanic_turns = 3;
        } else if (_floor == 2) {
            enemy1 = enemy_clone(_eli_pool[1]);
            enemy1.name             = "Tomb Archon";
            enemy1.HP               = 105; enemy1.max_HP = 105;
            enemy1.damage           = 14;
            enemy1.telegraph_turn   = 4; enemy1.telegraph_damage = 22;
            enemy1.armor            = 7; enemy1.el_resist = 10;
            enemy1.mechanic_type    = "retribution";
            enemy1.mechanic_value   = 6;
        } else {
            enemy1 = enemy_clone(_eli_pool[0]);
            enemy1.name             = "The Eternal Frost";
            enemy1.HP               = 145; enemy1.max_HP = 145;
            enemy1.damage           = 18;
            enemy1.telegraph_turn   = 3; enemy1.telegraph_damage = 27;
            enemy1.armor            = 11; enemy1.el_resist = 9;
            enemy1.mechanic_type    = "fortify";
            enemy1.mechanic_value   = 0.5; enemy1.mechanic_turns = 4;
        }
    } else {
        // Ashen Vault bosses
        if (_floor == 1) {
            enemy1 = enemy_clone(_eli_pool[0]);
            enemy1.name             = "Vault Sentinel";
            enemy1.HP               = 80; enemy1.max_HP = 80;
            enemy1.damage           = 12;
            enemy1.telegraph_turn   = 3; enemy1.telegraph_damage = 18;
            enemy1.armor            = 10; enemy1.el_resist = 2;
            enemy1.mechanic_type    = "fortify";
            enemy1.mechanic_value   = 0.5; enemy1.mechanic_turns = 3;
        } else if (_floor == 2) {
            enemy1 = enemy_clone(_eli_pool[1]);
            enemy1.name             = "Bone Sovereign";
            enemy1.HP               = 100; enemy1.max_HP = 100;
            enemy1.damage           = 15;
            enemy1.telegraph_turn   = 4; enemy1.telegraph_damage = 22;
            enemy1.armor            = 6; enemy1.el_resist = 8;
            enemy1.mechanic_type    = "retribution";
            enemy1.mechanic_value   = 6;
        } else {
            enemy1 = enemy_clone(_eli_pool[0]);
            enemy1.name             = "Malgrath the Warden";
            enemy1.HP               = 140; enemy1.max_HP = 140;
            enemy1.damage           = 18;
            enemy1.telegraph_turn   = 3; enemy1.telegraph_damage = 28;
            enemy1.armor            = 10; enemy1.el_resist = 6;
            enemy1.mechanic_type    = "fortify";
            enemy1.mechanic_value   = 0.5; enemy1.mechanic_turns = 4;
        }
    }

    // Bosses get a scaling ability set (typed nuke + sparing control slam).
    enemy1.abilities = boss_ability_set(_floor, _dung);

    // Boss support enemy
    enemy2 = enemy_clone(_std_pool[irandom(array_length(_std_pool) - 1)]);
    enemy2.HP     = 35;
    enemy2.max_HP = 35;
    enemy2.damage = 6;

} else {
    // Standard — pick two random different enemies from the standard pool
    var _pool_size = array_length(_std_pool);
    var _idx1 = irandom(_pool_size - 1);
    var _idx2 = irandom(_pool_size - 1);
    var _attempts = 0;
    while (_idx2 == _idx1 && _attempts < 10) {
        _idx2 = irandom(_pool_size - 1);
        _attempts++;
    }
    enemy1 = enemy_clone(_std_pool[_idx1]);
    enemy2 = enemy_clone(_std_pool[_idx2]);
}

// -----------------------------------------------------------------------------
// ENCOUNTER SIZE — 2-4 enemies by room difficulty + RNG.
// enemy1/enemy2 are the base pair; extras are extra standard mobs (weak adds for
// bosses). All enemies below are scaled/initialised via the `enemies` array.
// -----------------------------------------------------------------------------
var _enc_floor = clamp((variable_global_exists("current_floor") ? global.current_floor : 1), 1, 3);
var _enc_count = 2;
if (_enemy_type == "boss") {
    if (irandom(99) < (15 + _enc_floor * 12)) _enc_count = 3;          // boss + 1, sometimes 2 adds
} else if (_enemy_type == "elite") {
    if (irandom(99) < (25 + _enc_floor * 12)) _enc_count = 3;          // elite + 1, sometimes 2
} else {
    var _enc_roll = irandom(99) + (_enc_floor - 1) * 18;              // deeper floors lean larger
    if (_enc_roll < 45)      _enc_count = 2;
    else if (_enc_roll < 80) _enc_count = 3;
    else                     _enc_count = 4;
}

var enemies = [enemy1, enemy2];
while (array_length(enemies) < _enc_count) {
    var _ex_mob = enemy_clone(_std_pool[irandom(array_length(_std_pool) - 1)]);
    if (_enemy_type == "boss") { _ex_mob.HP = 35; _ex_mob.max_HP = 35; _ex_mob.damage = 6; }
    array_push(enemies, _ex_mob);
}

// Apply ascendance stat multipliers (index 0 = the boss/elite/main; gets _boss_extra)
var _asc = variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0;
if (_asc > 0) {
    var _hp_table  = [1.00, 1.20, 1.45, 1.75, 2.10, 2.55];
    var _dmg_table = [1.00, 1.15, 1.35, 1.60, 1.90, 2.30];
    var _hp_mult   = _hp_table[_asc];
    var _dmg_mult  = _dmg_table[_asc];
    var _boss_extra = (_enemy_type == "boss" && _asc >= 5) ? 1.25 : 1.0;
    for (var _ei = 0; _ei < array_length(enemies); _ei++) {
        var _e  = enemies[_ei];
        var _be = (_ei == 0) ? _boss_extra : 1.0;
        _e.max_HP           = round(_e.max_HP * _hp_mult * _be);
        _e.HP               = _e.max_HP;
        _e.damage           = round(_e.damage * _dmg_mult * _be);
        _e.telegraph_damage = round(_e.telegraph_damage * _dmg_mult * _be);
    }
}

// -----------------------------------------------------------------------------
// DIFFICULTY PASS — baseline enemy buff + per-floor scaling.
// Baseline (~+15%) applies to everyone; floor scaling stacks on standard/elite
// only (bosses already escalate via their hand-tuned per-floor stats above).
// Stacks multiplicatively with ascendance. See SYSTEMS_ENEMY_DIFFICULTY.md.
// -----------------------------------------------------------------------------
var _diff_base  = 1.15;
var _diff_floor = clamp((variable_global_exists("current_floor") ? global.current_floor : 1), 1, 3);
var _diff_fmult = [1.00, 1.15, 1.30][_diff_floor - 1];
var _diff_mult  = _diff_base * ((_enemy_type == "boss") ? 1.0 : _diff_fmult);
for (var _ei = 0; _ei < array_length(enemies); _ei++) {
    var _e = enemies[_ei];
    _e.max_HP           = round(_e.max_HP * _diff_mult);
    _e.HP               = _e.max_HP;
    _e.damage           = round(_e.damage * _diff_mult);
    _e.telegraph_damage = round(_e.telegraph_damage * _diff_mult);
}

// -----------------------------------------------------------------------------
// CURSE PASS — opt-in run difficulty (devil's bargain). Doom buffs enemy HP;
// Savagery/Doom/Devil's Pact buff enemy damage. Stacks on top of ascendance +
// difficulty. See SYSTEMS_CURSES.md.
// -----------------------------------------------------------------------------
var _curse_ehp = curse_enemy_hp_mult();
var _curse_edm = curse_enemy_damage_mult();
if (_curse_ehp != 1.0 || _curse_edm != 1.0) {
    for (var _ei = 0; _ei < array_length(enemies); _ei++) {
        var _e = enemies[_ei];
        _e.max_HP           = round(_e.max_HP * _curse_ehp);
        _e.HP               = _e.max_HP;
        _e.damage           = round(_e.damage * _curse_edm);
        _e.telegraph_damage = round(_e.telegraph_damage * _curse_edm);
    }
}

// Placeholder stats structs (initiative sort), status arrays, and combat
// classification (reach + kind) for every enemy in the encounter.
for (var _ei = 0; _ei < array_length(enemies); _ei++) {
    var _e = enemies[_ei];
    _e.stats = { DEX: 3, WIS: 3, STR: 3, INT: 1 };
    _e.status_effects = [];
    _e.reach = enemy_is_ranged(_e.name)      ? "ranged" : "melee";
    _e.kind  = enemy_is_spellcaster(_e.name) ? "spell"  : "attack";
}


// -----------------------------------------------------------------------------
// 3. INITIALISE COMBAT
// -----------------------------------------------------------------------------

// combat_init sorts the array by DEX (WIS tiebreak) and returns a combat_state
// struct that tracks the initiative queue and the active combatant.
var _combatants = [player];
for (var _ei = 0; _ei < array_length(enemies); _ei++) array_push(_combatants, enemies[_ei]);
combat_state = combat_init(_combatants);


// -----------------------------------------------------------------------------
// 4. CONTROLLER VARIABLES (continued)
// -----------------------------------------------------------------------------

// Loot screen shown after combat when items dropped this room
show_loot_screen   = false;
loot_screen_scroll = 0;

// Boss floor-completion XP bonus granted at most once per combat
boss_bonus_granted = false;


// -----------------------------------------------------------------------------
// 4. CONTROLLER VARIABLES
// -----------------------------------------------------------------------------

// Abilities the player has already used in the current player turn.
// Cleared when a new player turn starts (enemy turn → player turn transition).
abilities_used_this_turn = [];

// Set true on each enemy→player transition; consumed at player turn start to
// tick the player's status effects (DoT/debuff durations) exactly once per turn.
need_player_status_tick = false;

// Index into player.abilities for the currently highlighted button
selected_ability = 0;

// Index into the living enemy list (not the full combatant array) for the
// currently targeted enemy. Cycled with Tab. Reset to 0 after each kill via
// the safety fallback in Step_0.
selected_target = 0;

// Append-only array of strings; ui_draw_combat_log renders newest-at-bottom and
// supports mouse-wheel scrollback via combat_log_scroll (0 = pinned to newest).
combat_log          = [];
combat_log_scroll   = 0;    // rows scrolled back from the newest entry
combat_log_last_len = 0;    // tracks growth so new entries snap the view to newest

// Set true once combat_check_victory returns a non-zero result
combat_over = false;

// 0 = ongoing, 1 = player won, -1 = player lost
combat_result = 0;

// True when it is the player's turn to act; false during enemy turns
player_turn = combat_state.active.is_player;

// Frames remaining before the enemy takes its action.
// The delay gives the player time to read the log and any telegraph warning
// before the enemy resolves its attack.
enemy_turn_timer = 0;

// 180 frames at 60 fps (GameMaker default room speed) ≈ 3 seconds.
enemy_turn_delay = 60;


// -----------------------------------------------------------------------------
// 5. OPENING LOG ENTRY
// -----------------------------------------------------------------------------

array_push(combat_log,
    "Combat begins! " + combat_state.combatants[0].name + " acts first."
);


// -----------------------------------------------------------------------------
// 6. VISUAL EFFECTS STATE
// -----------------------------------------------------------------------------

// Floating damage/heal numbers — each entry: { value, x, y, timer, col }
damage_popups = [];

// Attack slide animation — attacker lunges toward target over 20 frames
attack_anim_timer     = 0;
attack_anim_src_x     = 0;
attack_anim_src_y     = 0;
attack_anim_dst_x     = 0;
attack_anim_dst_y     = 0;
attack_anim_is_player = true;   // true = player is attacker
attack_anim_enemy_idx = 0;      // which enemy slot is sliding

// Screen shake — random sprite offset while timer > 0
screen_shake_timer = 0;
screen_shake_x     = 0;
screen_shake_y     = 0;

// VFX impact sprite — drawn at hit position for a few frames.
// vfx_timer_max holds the value vfx_timer was set to, so the Draw event can map
// the countdown onto the sprite's sub-images (multi-frame Gigapack effects).
vfx_timer     = 0;
vfx_timer_max = 0;
vfx_spr       = -1;
vfx_x         = 0;
vfx_y         = 0;

// Hit flash counters on each combatant struct (counts down from 15)
player.hit_flash = 0;
for (var _ei = 0; _ei < array_length(enemies); _ei++) enemies[_ei].hit_flash = 0;

// Battle music — boss gets its own track, everything else gets the combat loop
audio_apply_volumes();   // honor saved Music/SFX volumes
if (_enemy_type == "boss") {
    audio_play_sound(_14_BOSS_y_LOOP, 1, true);
} else {
    audio_play_sound(_3_critical_LOOP, 1, true);
}
combat_music_stopped = false;

// Consumable quick menu (combat-native popup, separate from the character menu)
consumable_quick_open   = false;
consumable_quick_cursor = 0;

// Boss extract choice (shown after defeating floor boss when floor < 3)
boss_extract_open = false;

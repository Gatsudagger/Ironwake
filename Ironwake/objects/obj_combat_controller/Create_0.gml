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
if (variable_global_exists("chosen_stats")) {
    _base_stats = global.chosen_stats;
} else {
    _base_stats = stats_init(0);
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

    // Raw stats struct — crit functions read STR/DEX/INT/WIS from here
    stats:      _stats,
};

// Restore HP carried from the previous room, or record full HP for room 1
if (variable_global_exists("run_current_hp") && global.run_current_hp > 0) {
    player.HP = min(global.run_current_hp, player.max_HP);
} else {
    global.run_current_hp = player.max_HP;
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
var _ab_pool_cc;
switch (_class_id) {
    case 0:  _ab_pool_cc = global.abilities_arcanist;      break;
    case 1:  _ab_pool_cc = global.abilities_bloodwarden;   break;
    case 2:  _ab_pool_cc = global.abilities_shadowstrider; break;
    default: _ab_pool_cc = global.abilities_arcanist;
}
var _loadout_valid = false;
if (variable_global_exists("player_loadout") && global.player_loadout[0] != "") {
    player.abilities = [];
    for (var _li = 0; _li < 4; _li++) {
        var _lname = global.player_loadout[_li];
        for (var _ai = 0; _ai < array_length(_ab_pool_cc); _ai++) {
            if (_ab_pool_cc[_ai].name == _lname) {
                array_push(player.abilities, _ab_pool_cc[_ai]);
                break;
            }
        }
    }
    _loadout_valid = (array_length(player.abilities) == 4);
}
if (!_loadout_valid) {
    player.abilities = abilities_get_loadout(_class_id);
}

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
for (var _li = 0; _li < array_length(global.inventory); _li++) {
    var _lit = global.inventory[_li];
    if (_lit == undefined) continue;
    if (!variable_struct_exists(_lit, "unique_effect") || _lit.unique_effect == "") continue;
    if (_lit.unique_effect == "gatewarden_brand")  { player.gatewarden_brand  = true; player.gatewarden_used = false; }
    if (_lit.unique_effect == "heartstone_aegis")  player.heartstone_aegis  = true;
    if (_lit.unique_effect == "thief_of_hours")    player.thief_of_hours    = true;
    if (_lit.unique_effect == "crown_hollow_king") player.crown_hollow_king = true;
}

// Thief of Hours: start first turn with +1 AP
if (player.thief_of_hours) {
    player.energy = 4;
}

// Apply trait effects that modify combat start state.
// Must run after secondary resources are set (Crimson Reserve needs blood),
// and after HP restoration (Thick Skin adds to the restored HP value).
if (variable_global_exists("player_traits")) {
    combat_apply_start_traits(player);
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

if (_enemy_type == "elite") {
    // One random elite + one random standard as support
    var _elite_idx   = irandom(array_length(global.enemies_ashen_vault_elite) - 1);
    var _support_idx = irandom(array_length(global.enemies_ashen_vault_standard) - 1);
    enemy1 = enemy_clone(global.enemies_ashen_vault_elite[_elite_idx]);
    enemy2 = enemy_clone(global.enemies_ashen_vault_standard[_support_idx]);

} else if (_enemy_type == "boss") {
    // Single powerful enemy + a support unit; Stone Golem used as placeholder boss
    enemy1 = enemy_clone(global.enemies_ashen_vault_elite[0]);
    enemy1.name             = "Malgrath the Warden";
    enemy1.HP               = 120;
    enemy1.max_HP           = 120;
    enemy1.damage           = 14;
    enemy1.telegraph_damage = 22;
    enemy1.armor            = 8;
    enemy2 = enemy_clone(global.enemies_ashen_vault_standard[2]); // Dungeon Wraith support
    enemy2.name   = "Vault Wraith";
    enemy2.damage = 5;

} else {
    // Standard — pick two random different enemies from the standard pool
    var _pool_size = array_length(global.enemies_ashen_vault_standard);
    var _idx1 = irandom(_pool_size - 1);
    var _idx2 = irandom(_pool_size - 1);
    var _attempts = 0;
    while (_idx2 == _idx1 && _attempts < 10) {
        _idx2 = irandom(_pool_size - 1);
        _attempts++;
    }
    enemy1 = enemy_clone(global.enemies_ashen_vault_standard[_idx1]);
    enemy2 = enemy_clone(global.enemies_ashen_vault_standard[_idx2]);
}

// Placeholder stats structs so combat_init can sort initiative by DEX/WIS.
// Enemies use their own acc and damage fields during combat — these values
// only affect turn order.
enemy1.stats = { DEX: 3, WIS: 3, STR: 3, INT: 1 };
enemy2.stats = { DEX: 3, WIS: 3, STR: 3, INT: 1 };

// Status effect arrays — the tick system in Step_0 reads and writes these.
// Must be initialized here because enemy_clone() does not guarantee the field.
enemy1.status_effects = [];
enemy2.status_effects = [];


// -----------------------------------------------------------------------------
// 3. INITIALISE COMBAT
// -----------------------------------------------------------------------------

// combat_init sorts the array by DEX (WIS tiebreak) and returns a combat_state
// struct that tracks the initiative queue and the active combatant.
combat_state = combat_init([player, enemy1, enemy2]);


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

// Index into player.abilities for the currently highlighted button
selected_ability = 0;

// Index into the living enemy list (not the full combatant array) for the
// currently targeted enemy. Cycled with Tab. Reset to 0 after each kill via
// the safety fallback in Step_0.
selected_target = 0;

// Append-only array of strings; ui_draw_combat_log reads the last 4 entries
combat_log = [];

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

// VFX impact sprite — drawn at hit position for a few frames
vfx_timer = 0;
vfx_spr   = -1;
vfx_x     = 0;
vfx_y     = 0;

// Hit flash counters on each combatant struct (counts down from 15)
player.hit_flash = 0;
enemy1.hit_flash = 0;
enemy2.hit_flash = 0;

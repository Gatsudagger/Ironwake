// =============================================================================
// obj_combat_controller - Create event
// Bootstraps a single combat encounter: builds the player struct, clones
// enemies, runs combat_init, and sets up all controller state.
// =============================================================================

// IRONMAN resume (SYSTEMS_RUN_RESUME.md): live-HP watcher state (Step top) +
// the defeat-settlement latch (end_run(-1) runs at the death frame; the Draw
// result handler must not run it again).
run_ckpt_sig      = "";
run_ckpt_cooldown = 0;
defeat_settled    = false;
vow_fallen        = false;   // THE IRON VOW: this defeat was the character's last

// DELIVERY MUTATORS (M 08-11, SYSTEMS_MUTATORS.md): pending delayed sub-hits
// (bounce hops, echoes). Ticked at the top of Step; dies with the encounter.
mutator_queue = [];

// Trap throw-arc transient (P5, 08-11): cleared so a mid-flight prop from a
// fled combat can never replay in the next one.
global.trap_throw = undefined;

// FAUX-2.5D EXPERIMENT (M 08-11): read the lever once per combat from
// settings.ini [ui] combat_25d (default ON for the trial). F7 in combat flips
// it live and persists. Fully reversible - combat_25d()=false is the shipped
// flat look, byte-identical.
if (!variable_global_exists("combat_25d")) {
    ini_open("settings.ini");
    global.combat_25d = (ini_read_real("ui", "combat_25d", 1) > 0.5);
    ini_close();
}


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
// Caster ranged weapons (wand/focus/...) deal their flat damage as this school
// (rolled on the item) instead of physical; "" = a martial ranged weapon (bow).
_derived.ranged_school = variable_struct_exists(_equip_bonus, "ranged_school") ? _equip_bonus.ranged_school : "";

// Reach-gated elemental weapon affix (SYSTEMS_WEAPON_ROLES.md §C): on a damaging
// ability of its reach class it adds a small elemental hit + a setup status.
_derived.melee_elem  = _equip_bonus.melee_elem;
_derived.ranged_elem = _equip_bonus.ranged_elem;

// Flat "+X <school> damage" gear affixes (SYSTEMS_ELEMENT_SCHOOLS.md §C): the cast
// resolver reads player.derived.school_dmg[ability_school(ab)] and adds it as a
// separate truly-flat post-crit component, mitigated by the ability's own type.
_derived.school_dmg = _equip_bonus.school_dmg;
// Ember Memory (wyrmling innate, 08-01): +5% Fire school damage on the gear channel.
var _inn_fire = pet_active_innate("fire");
if (_inn_fire > 0) {
    _derived.school_dmg.fire = (variable_struct_exists(_derived.school_dmg, "fire") ? _derived.school_dmg.fire : 0) + _inn_fire;
}

// Assemble the player combat struct.
// HP and DODGE come from derived values; armor and el_resist are from the
// starting equipment (robe or leathers, +1 each).
player = {
    name:       (variable_global_exists("player_name") ? global.player_name : "Hero"),
    is_player:  true,
    class_id:   _class_id,

    // Vitals - max_HP folds in the equipment +HP affix bonus up front so the
    // carry-over clamp below measures against the TRUE full HP. (Adding the bonus
    // AFTER the clamp re-healed the gear-HP portion every combat - see below.)
    HP:         _derived.HP + _equip_bonus.bonus_max_hp,
    max_HP:     _derived.HP + _equip_bonus.bonus_max_hp,

    // Mitigation - base 1 each; equipment bonuses stored separately for Step application
    armor:           1,
    el_resist:       1,
    equip_armor:     _equip_bonus.armor,
    equip_el_resist: _equip_bonus.el_resist,

    // Hit and evasion
    dodge:      _derived.DODGE,
    acc:        _derived.ACC_modifier,

    // Action economy - restored to 3 at the start of each turn
    energy:     3,

    // Checked by the turn queue UI and the combat engine defeat logic
    is_defeated: false,

    // Flat damage reduction applied after armor (set by Iron Skin, reset on expiry)
    damage_reduction: 0,

    // Defensive status flags.
    // is_untargetable/untargetable_turns - Vanish's chance-dodge window.
    // blink_charges - Blink's staged guard: 3 = next hit auto-dodged, 2 = -50% dmg,
    //   1 = -25% dmg, 0 = inactive (see obj_combat_controller/Step_0 incoming-attack block).
    // shadow_step_charges - Shadow Step rolls a dodge CHANCE on each of the next N attacks.
    is_untargetable:     false,
    untargetable_turns:  0,
    blink_charges:       0,
    shadow_step_charges: 0,

    // Buff duration trackers (read by HUD for status icon display)
    iron_skin_duration:  0,
    bloodthorn_active:   false,
    bloodthorn_duration: 0,
    bloodthorn_value:    0,
    // Audit §6 build 2026-07-03: the previously-unimplemented defensive trio.
    undying_active:      false,       // Undying: cheat death once (cast-armed)
    evasive_roll_armed:  false,       // Evasive Roll: halve the next hit above 10
    soulbind_enemy:      undefined,   // Soulbind: bound enemy ref (combat-long)
    // Combat plan v2 (07-17): per-turn / stance flags.
    adrenaline_turn_used: false,      // Adrenaline Rush: once per TURN (reset at turn start)
    interrupt_used:       false,      // Interrupt: 1-AP refund fires once per turn
    counterblade_active:  false,      // Counterblade: riposte stance until your next turn
    poise_shield:         0,          // shield from last turn's unspent AP (expires next turn)

    // Typed status layer (vulnerable/weaken/blind/mortality/stun/dot) + shield pool.
    // Lets debuffs land on the player too; shield_hp absorbs damage before HP.
    status_effects: [],
    shield_hp:      0,

    // Raw stats struct - crit functions read STR/DEX/INT/WIS from here
    stats:      _stats,

    // Derived combat values - flat damage bonuses, reductions, crit ceilings
    derived:    _derived,
};

// Thick Skin: STATIC +10% max HP while equipped (multiplier, NOT a heal). Folded
// in BEFORE the HP carry-over clamp so the carried HP measures against the true
// full max and out_of_combat_max_hp() (which applies the same mult) matches the
// in-fight bar. Boon/curse max-HP mults stack on top below.
var _trait_hpm = trait_maxhp_mult();
if (_trait_hpm != 1.0) {
    player.max_HP = max(1, round(player.max_HP * _trait_hpm));
    player.HP     = player.max_HP;
}

// Restore HP carried from the previous room, or record full HP for room 1
if (variable_global_exists("run_current_hp") && global.run_current_hp > 0) {
    player.HP = min(global.run_current_hp, player.max_HP);
} else {
    global.run_current_hp = player.max_HP;
}

// Apply rest-site heal (granted by floor rest rooms). The % component is resolved
// HERE against the geared max_HP (the floor room can't know it yet).
var _rest_total = 0;
if (variable_global_exists("pending_rest_heal") && global.pending_rest_heal > 0) {
    _rest_total += global.pending_rest_heal;
    global.pending_rest_heal = 0;
}
if (variable_global_exists("pending_rest_heal_pct") && global.pending_rest_heal_pct > 0) {
    _rest_total += round(player.max_HP * global.pending_rest_heal_pct / 100);
    global.pending_rest_heal_pct = 0;
}
if (_rest_total > 0) {
    player.HP = min(player.HP + _rest_total, player.max_HP);
}

// Apply trap damage (dealt by floor trap rooms)
if (variable_global_exists("pending_trap_damage") && global.pending_trap_damage > 0) {
    player.HP = max(1, player.HP - global.pending_trap_damage);
    global.pending_trap_damage = 0;
}

// Attach secondary resource fields based on class; abilities come from the
// shared abilities_get_loadout() so the menu and combat always show the same set.
switch (_class_id) {
    case 0: // Arcanist - Souls
        player.souls     = 0;
        player.souls_max = 10;
        break;

    case 1: // Bloodwarden - Blood
        player.blood     = 0;
        player.blood_max = 10;
        break;

    case 2: // Shadowstrider - Preparation
        player.preparation     = 0;
        player.preparation_max = 10;
        player.trap_active     = false;   // legacy flag, kept for old save shapes
        // Deployed traps (08-08 rework). Combat-scoped: a fresh board every fight.
        player.traps           = [];
        break;
}
// Build abilities from the player's confirmed loadout, or fall back to class defaults.
// Shared resolver (also used by the out-of-combat character menu) so the two never drift.
player.abilities = abilities_resolve_player_loadout(_class_id);

// Borrowed Memory (expression #6): a run-scoped extra ability from another class's
// pool, granted by rare event outcomes. Appended after the loadout so it gets the
// next button/hotkey; duplicates are impossible (it never comes from the own pool).
var _borrowed = borrowed_memory_resolve();
if (_borrowed != undefined) array_push(player.abilities, ability_web_resolve(_borrowed));

// Per-combat ability cooldown counters (turns), one slot per loadout ability.
// Decremented at the start of each player turn; set when a cooldown ability
// (Blink / Shadow Step) is cast. Kept off the shared ability struct on purpose.
player.ability_cd = array_create(array_length(player.abilities), 0);

// Same-category AP synergy tracker (SYSTEMS_ABILITY_SYNERGY.md): a set of the role
// categories (offense/defense/support/control) already cast THIS player turn. The
// 2nd+ ability of a category costs -1 AP (floor 1). Reset at each player-turn start
// (obj_combat_controller/Step_0, the need_player_status_tick block).
player.turn_cast_categories = {};

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
// Deployed trap board restore (08-11, task #28). global.run_traps is only ever
// non-empty right after an IRONMAN mid-combat resume (the checkpoint's live
// patch) - normal room entry always sees [] here, keeping the fresh-board rule.
// Consumed once so the board can never leak into the NEXT fight.
if (variable_global_exists("run_traps") && is_array(global.run_traps)
    && array_length(global.run_traps) > 0) {
    player.traps = global.run_traps;
    global.run_traps = [];
}

// --- Class trunk resource nodes (P2, 08-05): caps first, then floors, AFTER the
// carry restore above so a floor never clips a carried reserve and a raised cap
// applies to everything downstream. All reads gate on class_id + trunk_has.
if (player.class_id == 0 && trunk_has("soul_cap"))  player.souls_max       = 13;
if (player.class_id == 1 && trunk_has("blood_cap")) player.blood_max       = 13;
if (player.class_id == 2 && trunk_has("prep_cap"))  player.preparation_max = 12;
if (player.class_id == 0 && trunk_has("soul_start")) player.souls = max(player.souls, 2);
if (player.class_id == 2 && trunk_has("prep_start")) player.preparation = max(player.preparation, 2);
if (player.class_id == 1 && trunk_has("blood_start_missing") && player.max_HP > 0) {
    player.blood = min(player.blood_max, max(player.blood, floor((player.max_HP - player.HP) / 10)));
}

// NOTE: the equipment +HP affix bonus (_equip_bonus.bonus_max_hp) is already folded
// into player.max_HP at creation, so the carried-over HP clamp uses the true full max.
// It must NOT be re-added here - doing so silently healed the gear-HP portion at the
// start of every combat (the "Arcanist heals after combat" report).

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
// Corruption (Pets §7): a pushing-corrupted active pet gnaws at you - reduced max HP.
var _pet_corr_hpm = pet_corruption_maxhp_mult();
if (_pet_corr_hpm != 1.0) {
    player.max_HP = max(1, round(player.max_HP * _pet_corr_hpm));
    player.HP     = min(player.HP, player.max_HP);
}
// Vital egg (Pets §3): active hatchling from a Vital Egg raises max HP. Like the boon/curse
// HP mults above, this only lifts the ceiling and clamps - it must NOT heal each combat.
var _pet_vit = pet_active_egg_bonus("vit");
if (_pet_vit > 0) {
    player.max_HP = max(1, round(player.max_HP * (1 + _pet_vit)));
    player.HP     = min(player.HP, player.max_HP);
}
player.dodge += _equip_bonus.dodge_flat;
// crit_flat stored in stats so combat_roll_crit can read it from attacker_stats
// (+ Keen egg: active hatchling adds flat crit-chance points on the same channel)
player.stats.crit_bonus = _equip_bonus.crit_flat + pet_active_egg_bonus("crit") + pet_active_kit_crit();   // gear + egg + Charmed (C5)
// Typed crit gear (07-31): spell-only / phys-only crit channels, applied by
// combat_roll_crit according to the roll's crit_type (STR/DEX = phys, INT/WIS = spell).
// Species innates (08-01, pillar B): Lunar Grace / Pack Snarl ride the same channels.
player.stats.crit_spell_bonus = _equip_bonus.crit_spell + pet_active_innate("crit_spell");
player.stats.crit_phys_bonus  = _equip_bonus.crit_phys  + pet_active_innate("crit_phys");
// Species innates, defensive plates (08-01): Cathedral Calm / Runeshell / Riveted Plate.
player.equip_armor += pet_active_innate("armor");
player.el_resist   += pet_active_innate("el_resist");
// gold_find stored for future hook; add_gold will check this when implemented
player.gold_find_pct = _equip_bonus.gold_find;

// Detect equipped legendary unique effects
player.gatewarden_brand  = false;  // first ability each combat costs 0 AP
player.heartstone_aegis  = false;  // heal 6 HP on enemy death (07-29 buff)
player.thief_of_hours    = 0;      // # of equipped Thief of Hours rings (+1 AP first turn each, stacks)
player.crown_hollow_king = false;  // +1 trait slot (hub loadout screen)
player.gatewarden_used   = false;  // tracks if the 0-AP proc is available this combat
// 07-28 expansion legendaries (M approved 10) - flags read at their effect sites.
player.leg_rebuke        = false;  // Duelist's Rebuke: after a dodge, next ability this turn +50%
player.leg_rebuke_primed = false;  // set by the dodge, consumed by the next ability
// Duelist Arts (DESIGN_DUELIST_CHALLENGE.md)
player.measured_riposte_active = false;  // Measured Riposte: first melee blow answered at 18 (until next turn)
player.leg_ashen         = false;  // The Ashen Blade: dodge/riposte arms -1 AP on the next ability
player.ashen_tempo_ready = false;  // the armed discount (burned at cast commit, like Counterphase)
player.leg_treads        = false;  // Gravewalker Treads: survive lethal at 1 HP once per RUN
player.leg_chalice       = false;  // Sanguine Chalice: overkill on kills heals (cap 20, 07-29 buff)
player.leg_loop          = false;  // Stormcaller's Loop: single-target spells echo 25% (07-29 buff)
player.leg_miser         = false;  // Miser's Blade: +1 dmg per 125g held (cap +10, 07-29 buff)
player.leg_veil          = false;  // Veil of the Patient Dark: first enemy attack auto-misses
player.leg_veil_ready    = false;  // per-combat charge for the veil
player.leg_longshot      = false;  // Longshot's Memory: first hit each combat auto-crits
player.leg_longshot_used = false;  // per-combat spent flag
player.leg_line          = false;  // Aegis of the Unbroken Line: poise 3/AP, cap doubled
player.leg_censer        = false;  // Ember Saint's Censer: DoT ticks +2
player.leg_shard         = false;  // Oathbreaker's Shard: kills grant +1 run max HP (cap +20)
player.leg_diadem        = false;  // Crownfire Diadem: Overcharge pays 4/point (07-29 buff)
player.leg_reliquary     = false;  // Kindled Reliquary: +2 class resource at combat start

// Class-weapon ability affixes (set by equipped class-locked weapons; see obj_game_controller/Create_0)
player.cf_first_spell_ap  = false;  // Cracked Focus  - first spell each combat costs 1 less AP (min 1)
player.cf_used            = false;  // tracks whether that discount has fired this combat
player.spell_dmg_bonus    = 0;      // Vaultstone Wand - outgoing spell damage % (e.g. 0.12)
player.spell_crit_ap      = false;  // Void Scepter   - spell crit restores 1 AP
player.weapon_lifesteal   = 0;      // Gravelstone Sword - heal % of melee damage dealt
player.weapon_start_shield = 0;     // Ashkeeper Blade - shield_hp granted at combat start
player.weapon_crit_bonus  = 0;      // Shadow Sickle  - flat % added to crit rolls
player.kill_ap_refund     = false;  // Serpent's Reach - killing an enemy refunds 1 AP

for (var _li = 0; _li < array_length(global.inventory); _li++) {
    var _lit = global.inventory[_li];
    if (_lit == undefined) continue;
    if (!variable_struct_exists(_lit, "unique_effect") || _lit.unique_effect == "") continue;
    if (_lit.unique_effect == "gatewarden_brand")  { player.gatewarden_brand  = true; player.gatewarden_used = false; }
    if (_lit.unique_effect == "heartstone_aegis")  player.heartstone_aegis  = true;
    if (_lit.unique_effect == "thief_of_hours")    player.thief_of_hours   += 1;
    if (_lit.unique_effect == "crown_hollow_king") player.crown_hollow_king = true;
    // 07-28 expansion legendaries
    if (_lit.unique_effect == "duelists_rebuke")     player.leg_rebuke   = true;
    if (_lit.unique_effect == "ashen_blade")         player.leg_ashen    = true;
    if (_lit.unique_effect == "gravewalker_treads")  player.leg_treads   = true;
    if (_lit.unique_effect == "sanguine_chalice")    player.leg_chalice  = true;
    if (_lit.unique_effect == "stormcallers_loop")   player.leg_loop     = true;
    if (_lit.unique_effect == "misers_blade")        player.leg_miser    = true;
    if (_lit.unique_effect == "veil_patient_dark")   { player.leg_veil = true; player.leg_veil_ready = true; }
    if (_lit.unique_effect == "longshots_memory")    player.leg_longshot = true;
    if (_lit.unique_effect == "aegis_unbroken_line") player.leg_line     = true;
    if (_lit.unique_effect == "ember_saints_censer") player.leg_censer   = true;
    if (_lit.unique_effect == "oathbreakers_shard")  player.leg_shard    = true;
    if (_lit.unique_effect == "crownfire_diadem")    player.leg_diadem   = true;
    if (_lit.unique_effect == "kindled_reliquary")   player.leg_reliquary = true;
    // (hollow_kings_signet / beggars_fortune / lantern_last_door are hub-side -
    // legendary_worn() in scr_stats reads the worn slots directly.)
    // Class-weapon affixes
    if (_lit.unique_effect == "class_first_spell_ap") player.cf_first_spell_ap   = true;
    if (_lit.unique_effect == "class_spell_dmg")      player.spell_dmg_bonus     = 0.12;
    if (_lit.unique_effect == "class_spell_crit_ap")  player.spell_crit_ap       = true;
    if (_lit.unique_effect == "class_lifesteal")      player.weapon_lifesteal    = 0.10;
    if (_lit.unique_effect == "class_start_shield")   player.weapon_start_shield = 12;
    if (_lit.unique_effect == "class_crit")           player.weapon_crit_bonus   = 8;
    if (_lit.unique_effect == "class_kill_ap")        player.kill_ap_refund      = true;
}

// Thief of Hours: start first turn with +1 AP per equipped ring (stacks).
// Add to current energy (still the base 3 here) so it stays correct if base AP changes.
if (player.thief_of_hours > 0) {
    player.energy += player.thief_of_hours;
}

// Kindled Reliquary (07-28 legendary): the class reserve starts warm (+2).
if (player.leg_reliquary) {
    if      (variable_struct_exists(player, "souls"))       player.souls       = min(player.souls_max,       player.souls + 2);
    else if (variable_struct_exists(player, "blood"))       player.blood       = min(player.blood_max,       player.blood + 2);
    else if (variable_struct_exists(player, "preparation")) player.preparation = min(player.preparation_max, player.preparation + 2);
}

// Ashkeeper Blade: start each combat with a shield (stacks with any other shield grant)
if (player.weapon_start_shield > 0) {
    player.shield_hp += player.weapon_start_shield;
// Bonelattice dark gift (08-04): +N Soul Shield at combat start, summed across
// equipped cursed gear.
var _dg_bl = dark_gift_total("shield_start");
if (_dg_bl > 0) {
    player.shield_hp += _dg_bl;
    array_push(combat_log, "Bonelattice knits a ward of " + string(_dg_bl) + ".");
}
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

// Always clone templates - never pass the template directly into combat, or
// stat mutations (damage taken, status effects) will persist across encounters.
// Enemy pool is chosen by global.next_enemy_type set by obj_floor_controller.
var _enemy_type;
if (variable_global_exists("next_enemy_type")) {
    _enemy_type = global.next_enemy_type;
} else {
    _enemy_type = "standard";
}
// Duel state defaults OFF for every ordinary combat (belt + braces - a stale
// flag would wrongly arm the 1-HP mercy net and the riposte).
if (_enemy_type != "duel") global.duel_active = false;
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

} else if (_enemy_type == "duel") {
    // THE ASHEN DUELIST (DESIGN_DUELIST_CHALLENGE.md, M-locked 07-29): a strict
    // 1v1 rival on a humanoid elite frame. Melee/phys, high dodge, and a duel-
    // specific riposte (every melee blow he survives answers for a flat 12 -
    // Counterblade's own number, wired in Step). He grows +10% per PREVIOUS
    // duel fought, forever - the ledger (duelist_encounters) never resets.
    enemy1 = enemy_clone(_eli_pool[0]);
    enemy1.name              = "The Ashen Duelist";
    var _duel_prev   = variable_global_exists("duelist_encounters") ? global.duelist_encounters : 0;
    var _duel_growth = 1.10 * power(1.10, _duel_prev);
    enemy1.HP                = round(85 * _duel_growth); enemy1.max_HP = enemy1.HP;
    enemy1.damage            = round(13 * _duel_growth);
    enemy1.armor             = 7;  enemy1.el_resist = 7;
    enemy1.dodge             = 18; enemy1.acc       = 85;
    enemy1.xp_value          = 30;
    enemy1.gold_min          = 45; enemy1.gold_max  = 70;
    enemy1.telegraph_turn    = 4;
    enemy1.telegraph_damage  = round(21 * _duel_growth);
    enemy1.telegraph_message = "The Duelist coils for the perfect thrust!";
    enemy1.mechanic_type     = "none"; enemy1.mechanic_value = 0; enemy1.mechanic_turns = 0;
    if (variable_struct_exists(enemy1, "reach")) enemy1.reach = "melee";
    enemy1.abilities = [
        enemy_ability("Quickstep Cut",   "spell",  30, 3, round(12 * _duel_growth),
            { msg: "slips inside your guard - a quickstep cut", reach: "melee" }),
        enemy_ability("Disarming Feint", "debuff", 22, 4, 0.15,
            { status_kind: "weaken", turns: 2, msg: "flicks your wrist aside - your blows weaken" }),
    ];
    enemy2 = undefined;
    // Duel state: entry HP is the mercy-restore point; PAR grades the rewards.
    global.duel_active      = true;
    global.duel_mercy_fired = false;
    global.duel_entry_hp    = player.HP;
    global.duel_par         = duel_turn_par();

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
    // Standard - pick two random different enemies from the standard pool
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
// ENCOUNTER SIZE - 2-4 enemies by room difficulty + RNG.
// enemy1/enemy2 are the base pair; extras are extra standard mobs (weak adds for
// bosses). All enemies below are scaled/initialised via the `enemies` array.
// -----------------------------------------------------------------------------
var _enc_floor = clamp((variable_global_exists("current_floor") ? global.current_floor : 1), 1, 3);
var _enc_count = 2;
if (_enemy_type == "duel") {
    _enc_count = 1;   // the duel is STRICTLY 1v1 (M-locked)
} else if (_enemy_type == "boss") {
    if (irandom(99) < (15 + _enc_floor * 12)) _enc_count = 3;          // boss + 1, sometimes 2 adds
} else if (_enemy_type == "elite") {
    if (irandom(99) < (25 + _enc_floor * 12)) _enc_count = 3;          // elite + 1, sometimes 2
} else {
    // Awakening-shifted pack weights (design 2026-07-04): 4-packs were too common
    // everywhere. Low tiers fight mostly 2-3; big packs (and rare 5-packs) become a
    // high-Awakening signature. Deeper floors still nudge the roll toward larger.
    var _enc_asc = clamp(variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0, 0, 5);
    var _enc_w   = [ [55, 35, 10, 0],     // A0: 2s and 3s, 4-pack rare
                     [50, 40, 10, 0],     // A1
                     [35, 40, 25, 0],     // A2: 3 common, 4 picks up
                     [30, 45, 25, 0],     // A3
                     [18, 38, 38, 6],     // A4: 4-pack ~40%, 5-pack appears
                     [12, 38, 42, 8] ];   // A5
    var _enc_row  = _enc_w[_enc_asc];
    var _enc_roll = irandom(99) + (_enc_floor - 1) * 8;
    if      (_enc_roll < _enc_row[0])                             _enc_count = 2;
    else if (_enc_roll < _enc_row[0] + _enc_row[1])               _enc_count = 3;
    else if (_enc_roll < _enc_row[0] + _enc_row[1] + _enc_row[2]) _enc_count = 4;
    else                                                          _enc_count = (_enc_row[3] > 0) ? 5 : 4;

    // OPENING-FIGHT GRACE (M 07-18: "lvl 1 first fight some players ran into 4
    // mobs instantly"). A0's 4-pack chance is only 10%, which is fine variety by
    // fight five - the problem is purely that it can land on a player's FIRST
    // fight, at level 1 with no gear, as their first impression of the game.
    // So we cap the opening fight at 3 instead of flattening A0's weights, which
    // would make every early run feel the same.
    // floor_rooms_cleared flags a node when it's ENTERED, so the opening fight
    // sees a count of 0 or 1 depending on ordering; <= 1 covers both. Erring one
    // fight wide is harmless here - a 2-3 pack is never the wrong opener.
    if (_enc_floor == 1 && _enc_count > 3 && variable_global_exists("floor_rooms_cleared")) {
        var _fr_done = 0;
        for (var _fri = 0; _fri < array_length(global.floor_rooms_cleared); _fri++) {
            if (global.floor_rooms_cleared[_fri]) _fr_done++;
        }
        if (_fr_done <= 1) _enc_count = 3;
    }
}

var enemies = (enemy2 == undefined) ? [enemy1] : [enemy1, enemy2];
while (array_length(enemies) < _enc_count) {
    var _ex_mob = enemy_clone(_std_pool[irandom(array_length(_std_pool) - 1)]);
    if (_enemy_type == "boss") { _ex_mob.HP = 35; _ex_mob.max_HP = 35; _ex_mob.damage = 6; }
    array_push(enemies, _ex_mob);
}

// Apply ascendance stat multipliers (index 0 = the boss/elite/main; gets _boss_extra)
var _asc = variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0;
if (_asc > 0) {
    // Tables live in awaken_hp_mult/awaken_dmg_mult (scr_combat) - shared with the
    // dungeon-select AWAKENING EFFECTS panel so display and combat never drift.
    var _hp_mult   = awaken_hp_mult(_asc);
    var _dmg_mult  = awaken_dmg_mult(_asc);
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
// DIFFICULTY PASS - baseline enemy buff + per-floor scaling.
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
// CURSE PASS - opt-in run difficulty (devil's bargain). Doom buffs enemy HP;
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
    _e.drop_slot = _ei;   // spawn slot - keys the deterministic reward seed (loot_room_seed)
}


// -----------------------------------------------------------------------------
// 3. INITIALISE COMBAT
// -----------------------------------------------------------------------------

// combat_init sorts the array by DEX (WIS tiebreak) and returns a combat_state
// struct that tracks the initiative queue and the active combatant.
var _combatants = [player];
for (var _ei = 0; _ei < array_length(enemies); _ei++) array_push(_combatants, enemies[_ei]);
combat_state = combat_init(_combatants);

// Enemy INTENT opening roll (INTENT_SPEC.md): every foe telegraphs its first
// action from turn one - chips draw above their heads in Draw_64.
for (var _ii = 0; _ii < array_length(combat_state.combatants); _ii++) {
    var _ic = combat_state.combatants[_ii];
    if (!_ic.is_player) enemy_roll_intent(_ic, player, 1, false);
}


// -----------------------------------------------------------------------------
// 4. CONTROLLER VARIABLES (continued)
// -----------------------------------------------------------------------------

// Loot screen shown after combat when items dropped this room.
// Reset the loot buffer on combat ENTRY so the post-combat screen ("Items
// collected this room") shows ONLY what drops during THIS fight. Treasure/event
// rooms also push into global.run_items_found, but they display their own popups
// and store the items in carried_items/consumable_inventory - so clearing here
// just stops those earlier pickups from re-appearing on the next combat's loot
// screen (the "I found the same item again" duplicate-looking bug). run_items_found
// is purely the loot-screen display buffer; it is not the run-history record.
global.run_items_found = [];
show_loot_screen   = false;
loot_screen_scroll = 0;
// Staggered loot reveal (SOUND_ATMOSPHERE_SPEC.md section 1): rows appear one
// by one with a tick; the best item's row fires its rarity stinger.
loot_reveal_timer  = 0;    // frames since the loot screen opened
loot_reveal_shown  = 0;    // rows currently revealed
loot_best_row      = 0;    // index of the highest-rarity item (first if tied)
loot_best_rarity   = 0;
loot_sting_played  = false;
// SPECIAL loot rows (M 07-28 spectacle): pet eggs, the Banshee Bottle, and
// signature trinkets list WITH the haul instead of hiding in the combat log.
// Rolled once at the victory frame (Step) on the room's deterministic stream.
loot_special_rows  = [];   // { kind:"pet"|"banshee"|"trinket", label, sub, tag, ... }
boss_drops_rolled  = false;

// Boss floor-completion XP bonus granted at most once per combat
boss_bonus_granted = false;

// Genie Lamp drop roll (very rare escape item, elite/boss kills only) - once per combat
genie_lamp_rolled = false;

// Board challenge-request ticks (flawless/clean/swift) fire at most once per victory
board_ticks_granted = false;


// -----------------------------------------------------------------------------
// 4. CONTROLLER VARIABLES
// -----------------------------------------------------------------------------

// Abilities the player has already used in the current player turn.
// Cleared when a new player turn starts (enemy turn -> player turn transition).
abilities_used_this_turn = [];

// Set true on each enemy->player transition; consumed at player turn start to
// tick the player's status effects (DoT/debuff durations) exactly once per turn.
need_player_status_tick = false;

// Index into player.abilities for the currently highlighted button
selected_ability = 0;

// D-pad End Turn reachability (07-24, ANDROID_TRACKING): DOWN from the ability
// row focuses the END TURN button so confirm ends the turn; UP/sideways returns
// to the abilities. Keyboard T / touch tap are unaffected.
end_turn_focus = false;

// Index into the living enemy list (not the full combatant array) for the
// currently targeted enemy. Cycled with Tab. Reset to 0 after each kill via
// the safety fallback in Step_0.
selected_target = 0;

// Append-only array of strings; ui_draw_combat_log renders newest-at-bottom and
// supports mouse-wheel scrollback via combat_log_scroll (0 = pinned to newest).
combat_log          = [];
combat_log_scroll   = 0;    // rows scrolled back from the newest entry
// Parallel to combat_log: a damage-breakdown struct per line (undefined for most
// lines). Hovering a damage line shows the math, BG3/Pathfinder-style. Kept aligned
// lazily by combat_log_push_breakdown(). Feature-flagged (global.combat_log_breakdowns)
// so the whole thing reverts by flipping one flag. (Task 1)
combat_log_detail   = [];
combat_log_last_len = 0;    // tracks growth so new entries snap the view to newest

// Set true once combat_check_victory returns a non-zero result
combat_over = false;

// Brief hold after the killing blow so the final hit / damage number and combat log
// are readable before the victory transition fires (loot screen, etc.). (Task 2)
victory_pause_timer  = 0;
victory_pause_frames = 60;   // ~1 second at 60 fps

// 0 = ongoing, 1 = player won, -1 = player lost, 2 = duel mercy (loss, never a death)
combat_result = 0;

// Ashen Duelist bookkeeping (DESIGN_DUELIST_CHALLENGE.md): grading fires once
// on the victory frame; the grade string feeds the result overlay.
duel_rewards_granted = false;
duel_grade           = "";
duel_grade_round     = 0;

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

// The duel opens with its terms (PAR chip also rides the intent area in Draw).
if (global.duel_active) {
    array_push(combat_log, "A DUEL - strict one-on-one. Your companion sits out.");
    array_push(combat_log, "PAR: " + string(global.duel_par) + " turns. Beat it for his finest prize.");
}

// Duelist's Poise (Duelist Arts trait, DESIGN_DUELIST_CHALLENGE.md): one foe,
// one breath - every ONE-ON-ONE combat opens with +1 AP (the duel included).
if (trait_active("Duelist's Poise") && array_length(combat_state.combatants) - 1 == 1) {
    player.energy += 1;
    array_push(combat_log, "Duelist's Poise: single combat - +1 AP.");
}

// Long Winter (hoarfrost_drake signature move, 08-01 pillar D): the first action
// of an elite or boss freezes in its throat - a 1-turn stun laid at the gate,
// before anyone moves (the control check reads stun pre-tick, so it costs the
// full first action). Once per combat by construction.
if (pet_active_sig_move("long_winter")
    && variable_global_exists("next_enemy_type")
    && (global.next_enemy_type == "elite" || global.next_enemy_type == "boss")
    && variable_struct_exists(enemy1, "status_effects")) {
    array_push(enemy1.status_effects, {
        name:         "Long Winter",
        effect_type:  "debuff",
        kind:         "stun",
        effect_value: 0,
        duration:     1,
        element:      "frost",
        source:       "pet"
    });
    array_push(combat_log, "[Companion] " + pet_active().name + " breathes the LONG WINTER - " + enemy1.name + "'s first move freezes in its throat.");
}

// -----------------------------------------------------------------------------
// 5b. DUNGEON FLOOR PASSIVES - consume the pending room-entry effects.
// obj_floor_controller Create accrues these per room (Scorched heat / Tundra cold,
// escalating with Awakening); they land here at the start of the NEXT combat.
// -----------------------------------------------------------------------------

// Scorched Depths: searing air = a fire DoT on the player at combat start.
// Per stack it mirrors the weapon burn affix rate (dmg/turn for 2 turns); capped
// so several combat-free rooms in a row can't snowball into a one-shot.
if (variable_global_exists("pending_fire_stacks") && global.pending_fire_stacks > 0) {
    var _heat_stacks = min(global.pending_fire_stacks, 3);
    global.pending_fire_stacks = 0;
    if (!variable_struct_exists(player, "status_effects")) player.status_effects = [];
    array_push(player.status_effects, {
        name:         "Scorching Air",
        effect_type:  "dot",
        kind:         "dot",
        effect_value: 2 * _heat_stacks,
        duration:     2,
        element:      "fire",
        source:       "dungeon"
    });
    array_push(combat_log, "The searing air clings to you - " + string(2 * _heat_stacks)
        + " fire damage per turn for 2 turns!");
}

// Tundra Tomb: the pending chill numbs the player's FIRST turn (-1/-2 AP, never
// below 1). Applied via chill_ap_penalty, consumed in combat_next_turn when the
// player's turn starts; if the player opens the fight, dock the energy directly.
if (variable_global_exists("pending_ap_penalty") && global.pending_ap_penalty > 0) {
    var _chill_pen = min(global.pending_ap_penalty, 2);
    global.pending_ap_penalty = 0;
    player.chill_ap_penalty = _chill_pen;
    if (combat_state.active.is_player) {
        player.energy = max(1, player.energy - _chill_pen);
        player.chill_ap_penalty = 0;
    }
    array_push(combat_log, "The tomb-cold numbs your limbs - -" + string(_chill_pen)
        + " AP on your first turn!");
}


// -----------------------------------------------------------------------------
// 6. VISUAL EFFECTS STATE
// -----------------------------------------------------------------------------

// Floating damage/heal numbers - each entry: { value, x, y, timer, col }
damage_popups = [];

// Awakened splash hooks (Stage 4 crossover): Vigil arms fresh each combat, and a
// Feral Echo pet lashes out once right now, before anyone takes a turn.
global.pet_vigil_used = false;
combat_pet_echo_open(combat_state, player, combat_log, damage_popups);

// Attack slide animation - attacker lunges toward target over 20 frames
attack_anim_timer     = 0;
attack_anim_src_x     = 0;
attack_anim_src_y     = 0;
attack_anim_dst_x     = 0;
attack_anim_dst_y     = 0;
attack_anim_is_player = true;   // true = player is attacker
attack_anim_enemy_idx = 0;      // which enemy slot is sliding

// Screen shake - random sprite offset while timer > 0
screen_shake_timer = 0;
screen_shake_x     = 0;
screen_shake_y     = 0;

// Cast windup FX (07-09 art track, code-first): on a SPELL cast the caster flares
// in the spell's school color and sheds rising motes while the timer runs down.
cast_fx_timer = 0;
cast_fx_color = c_white;

// VFX impact sprite - drawn at hit position for a few frames.
// vfx_timer_max holds the value vfx_timer was set to, so the Draw event can map
// the countdown onto the sprite's sub-images (multi-frame Gigapack effects).
vfx_timer     = 0;
vfx_timer_max = 0;
vfx_spr       = -1;
vfx_x         = 0;
vfx_y         = 0;
vfx_school    = "";   // school of the cast that spawned the VFX ("" = untinted); spell tints blend it

// --- Conveyance pass (08-04, SYSTEMS_COMBAT_FX.md header): traveling
// projectiles, beam lances, and multi-slot impact bursts. Mechanics resolve
// instantly at cast; a projectile only carries the PRESENTATION (popup delay,
// hit flash, recoil, screen shake, impact burst, HP-bar drain hold) to its
// arrival frame. Dodge sidestep / hit recoil live on the combatant structs
// (hit_flash idiom: dodge_anim / hit_recoil countdowns, ticked in Draw).
combat_projectiles = [];   // { spr, school, impact_spr, ticks, sx, sy, tx, ty, bx, by, t, dur, delay, tgt, shake }
combat_beams       = [];   // { sx, sy, tx, ty, t, dur, col }
vfx_bursts         = [];   // { spr, x, y, timer, timer_max, school }

// Hit flash counters on each combatant struct (counts down from 15)
player.hit_flash = 0;
for (var _ei = 0; _ei < array_length(enemies); _ei++) enemies[_ei].hit_flash = 0;

// Battle music - boss gets its own track, everything else gets the combat loop.
// The dungeon's own bed carries into combat (SOUND_ATMOSPHERE_SPEC.md section 2
// superseded the old drop-to-silence: the quiet low bed keeps the floor's
// identity under the music without eating combat's dramatic range).
audio_apply_volumes();   // honor saved Music/SFX volumes
ambience_set([dungeon_ambience_bed(), snd_amb_torch]);
if (_enemy_type == "boss") {
    audio_play_sound(_14_BOSS_y_LOOP, 1, true);
} else {
    audio_play_sound(_3_critical_LOOP, 1, true);
}
combat_music_stopped = false;

// Consumable quick menu (combat-native popup, separate from the character menu)
consumable_quick_open   = false;
consumable_quick_cursor = 0;
// TOUCH confirm-arming (M 07-18: "items in combat need a confirm press prompt").
// A single stray tap used to consume an item outright - irreversible, and easy to
// do with a thumb. Holds the grouped-row index that is ARMED and awaiting a second
// press; -1 = nothing armed. Touch only; desktop keeps one-press use.
consumable_confirm_idx  = -1;

// Full-screen ability breakdown popup (V key) - same view as the loadout/Vex Tab
// popup (ui_draw_ability_detail). Tab stays bound to target-cycling in combat.
ability_detail_open = false;

// Boss extract choice (shown after defeating floor boss when floor < 3)
boss_extract_open = false;
// #3: arm-then-confirm - the first press/click of a button ARMS it ("", "extract"
// or "continue"); only a second press of the SAME button commits. A held Enter
// from dismissing the victory screen can no longer descend by accident.
boss_extract_arm  = "";

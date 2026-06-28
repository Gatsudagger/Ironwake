// Singleton guard - only one game controller may exist at a time
if (instance_number(obj_game_controller) > 1) {
    instance_destroy();
    exit;
}

// -1 = no slot chosen yet (title screen hasn't selected one); set by the slot picker.
// load_game() and save_game() both no-op when this is -1.
global.save_slot = -1;

depth = -99999; // draw GUI on top of all room controllers

// Native 1920x1080 GUI canvas (clean 1.5x over the old 1280x720; SYSTEMS_RESOLUTION.md).
// The GUI layer is the real drawing surface; in fullscreen GameMaker maps it 1:1 to a
// 1080p display, so there's no upscale blur.
display_set_gui_size(GUI_W, GUI_H);

// Window sizing (auto-fit: native 1920x1080, clamped down only on sub-1080p displays,
// centered) AND the saved fullscreen preference are both handled by video_apply().
video_apply();

// -----------------------------------------------------------------------------
// SPRITE INCLUDE GUARD
// The female class sprites and all Vael skins are referenced ONLY via
// asset_get_index("name") (a string the compiler can't see as a reference), so
// GameMaker excludes them from the build and asset_get_index() returns -1 at
// runtime even though they exist in the project. Referencing them here by their
// bare asset identifiers - stored in a global so the assignment is never
// dead-code-eliminated - forces the compiler to include them in the build.
// (If a sprite is ever renamed/removed, update this list to match.)
global.__sprite_includes = [
    spr_hub_background,
    spr_title_background,
    spr_ui_frame,
    spr_combatbg_ashen_1,
    spr_combatbg_ashen_2,
    spr_combatbg_ashen_3,
    spr_floormap_ashen,
    spr_combatbg_tundra_1,
    spr_combatbg_tundra_2,
    spr_combatbg_tundra_3,
    spr_floormap_tundra,
    spr_combatbg_scorched_1,
    spr_combatbg_scorched_2,
    spr_combatbg_scorched_3,
    spr_floormap_scorched,
    spr_fx_poison,
    spr_fx_burn,
    spr_fx_bleed,
    spr_fx_blind,
    spr_fx_stun,
    spr_fx_weaken,
    spr_fx_impact,
    spr_arcanist_f,
    spr_bloodwarden_f,
    spr_shadowstrider_f,
    spr_skin_ashen,
    spr_skin_bloodsworn,
    spr_skin_bonechoir,
    spr_skin_cinderclad,
    spr_skin_cryptlight,
    spr_skin_dawnbreak,
    spr_skin_doomherald,
    spr_skin_duskhide,
    spr_skin_ember,
    spr_skin_frostbit,
    spr_skin_goldwrought,
    spr_skin_gravewalker,
    spr_skin_hearth,
    spr_skin_ironscale,
    spr_skin_mirewalker,
    spr_skin_pilgrim,
    spr_skin_sanguine,
    spr_skin_sovereign,
    spr_skin_stormcall,
    spr_skin_tide,
    spr_skin_veilbind,
    spr_skin_voidtouch,
    spr_skin_wanderer,
];

// =============================================================================
// obj_game_controller - Create event
// This object is persistent (survives all room transitions) and is the single
// source of truth for all meta-progression data that carries between runs.
// It should exist in the first room and never be destroyed.
// =============================================================================


// -----------------------------------------------------------------------------
// 1. ECONOMY
// Cumulative gold across all runs. add_gold() keeps current_run_gold in sync.
// -----------------------------------------------------------------------------
global.gold = 0;
global.player_name = "Hero";

// Player HP and secondary resources carried between combat rooms within a run.
// All reset to 0 at game start and by end_run() so each new run starts fresh.
global.run_current_hp    = 0;
global.run_souls         = 0;
global.run_blood         = 0;
global.run_preparation   = 0;
global.just_cleared_boss = false;
global.current_floor     = 1;
global.floor_rooms_cleared = [];


// -----------------------------------------------------------------------------
// 2. RUN STATISTICS
// Lifetime counters updated at the end of each run via end_run().
// -----------------------------------------------------------------------------
global.run_count   = 0;   // total attempts started
global.best_floor  = 0;   // deepest floor reached across all runs
global.total_kills = 0;   // cumulative enemy kills across all runs


// -----------------------------------------------------------------------------
// 3. PERMANENT STAT BONUSES
// Earned through leveling and the Vex system. Applied to the player struct
// in obj_combat_controller's Create event on top of the chosen class base.
// -----------------------------------------------------------------------------
global.perm_str_bonus = 0;
global.perm_dex_bonus = 0;
global.perm_con_bonus = 0;
global.perm_int_bonus = 0;
global.perm_wis_bonus = 0;
global.perm_cha_bonus = 0;


// -----------------------------------------------------------------------------
// 4. LAST RUN RESULTS
// Written by end_run() so the hub and result screens can display a post-run
// summary without querying the live run state.
// -----------------------------------------------------------------------------
global.last_run_gold        = 0;   // gold earned during the most recent run
global.last_run_kills       = 0;   // kills during the most recent run
global.last_run_result      = 0;   // 0 = no run yet, 1 = victory, -1 = defeat
global.last_run_mercy_gold  = 0;
global.last_run_perm_points = 0;   // perm points earned in the most recent run (0 = none)   // gold kept on defeat (25% mercy)


// -----------------------------------------------------------------------------
// 5. CURRENT RUN TRACKING
// Reset to 0 at the start of each run (inside end_run). Read by the HUD and
// written by add_gold() and combat kill resolution.
// -----------------------------------------------------------------------------
global.current_run_gold  = 0;
global.current_run_kills = 0;
if (!variable_global_exists("run_boons")) global.run_boons = [];   // active boons this run (Shrine tribute)
if (!variable_global_exists("run_curses")) global.run_curses = []; // active curses this run (devil's bargain)

// Onboarding coach-marks (see SYSTEMS_ONBOARDING.md). tutorial_seen = per-tip flags,
// tutorial_enabled = the Settings toggle, tutorial_active = the tip showing now ("").
if (!variable_global_exists("tutorial_seen"))    global.tutorial_seen    = {};
if (!variable_global_exists("tutorial_enabled")) global.tutorial_enabled = true;
global.tutorial_active          = "";
global.tutorial_dismiss_pending = false;   // 1-frame deferred clear (race-free dismiss)


// -----------------------------------------------------------------------------
// 6. LOOT TABLES
// Equipment pools used by roll_equipment() in scr_stats.
// Rarity: 0=common, 1=uncommon, 2=rare.
// create_item(name, slot, rarity, stat_name, stat_value, effect_desc, gold_value)
//
// Valid slot strings (must match equip_slot_index() in scr_stats exactly):
//   "weapon"  "offhand"  "helm"  "chest"  "gloves"  "boots"  "amulet"  "ring"
// -----------------------------------------------------------------------------
// Weapons with class restrictions are built via create_weapon() (defined in scr_stats).
// class_req: -1 = any, 0 = Arcanist, 1 = Bloodwarden, 2 = Shadowstrider.

// --- COMMON WEAPONS (class_req set post-creation) ---
var _cw_ashen        = create_item("Ashen Blade",    "weapon", 0, "STR", 2, "",                        15);
var _cw_shortbow     = create_item("Worn Shortbow",  "ranged_weapon", 0, "DEX", 2, "",                  14);
var _cw_cracked_wand = create_item("Cracked Focus",  "ranged_weapon", 0, "INT", 2, "still channels power", 13);
_cw_ashen.class_req = -1;  _cw_shortbow.class_req = -1;  _cw_cracked_wand.class_req = 0;
// Class-weapon ability affixes - being class-locked grants a combat bonus (read in obj_combat_controller/Create_0).
_cw_cracked_wand.unique_effect = "class_first_spell_ap";
_cw_cracked_wand.unique_desc   = "First spell each combat costs 1 less AP";

// --- UNCOMMON WEAPONS ---
var _uw_gravel  = create_item("Gravelstone Sword", "weapon", 1, "STR", 4, "dense and brutal",              35);
var _uw_wand    = create_item("Vaultstone Wand",   "ranged_weapon", 1, "INT", 4, "inscribed with vault runes", 38);
var _uw_sickle  = create_item("Shadow Sickle",     "weapon", 1, "DEX", 4, "curved blade of the striders",  36);
_uw_gravel.class_req = 1;  _uw_wand.class_req = 0;  _uw_sickle.class_req = 2;
_uw_gravel.unique_effect = "class_lifesteal";    _uw_gravel.unique_desc = "Heal 10% of the melee damage you deal";
_uw_wand.unique_effect   = "class_spell_dmg";    _uw_wand.unique_desc   = "Spells deal +12% damage";
_uw_sickle.unique_effect = "class_crit";         _uw_sickle.unique_desc = "+8% critical hit chance";

// --- RARE WEAPONS ---
var _rw_ash    = create_item("Ashkeeper Blade",  "weapon", 2, "STR", 6, "forged in ashwalker tradition",  80);
var _rw_vsept  = create_item("Void Scepter",     "ranged_weapon", 2, "INT", 6, "channels the void",       85);
var _rw_serp   = create_item("Serpent's Reach",  "weapon", 2, "DEX", 6, "flexible blade of the deep",    82);
_rw_ash.class_req = 1;  _rw_vsept.class_req = 0;  _rw_serp.class_req = 2;
_rw_ash.unique_effect   = "class_start_shield";  _rw_ash.unique_desc   = "Start each combat with a 12 HP shield";
_rw_vsept.unique_effect = "class_spell_crit_ap"; _rw_vsept.unique_desc = "Spell critical hits restore 1 AP";
_rw_serp.unique_effect  = "class_kill_ap";       _rw_serp.unique_desc  = "Killing an enemy restores 1 AP";
// Explicit req_stat overrides: these names resolve to the WRONG stat under
// weapon_required_stat ("blade"->DEX, "Serpent's Reach"->STR default), which would
// gate each weapon behind a stat its own class doesn't build. Pin to the real stat.
_rw_ash.req_stat  = "STR"; _rw_ash.req_value  = req_stat_curve(2);   // Bloodwarden STR blade
_rw_serp.req_stat = "DEX"; _rw_serp.req_value = req_stat_curve(2);   // Shadowstrider DEX reach

// --- TWO-HANDED WEAPONS (SYSTEMS_WEAPON_ROLES.md §D) ---
// 2H weapons lock the offhand slot, so they carry a bigger weapon_damage budget
// (~+80% over the 1H base for their rarity) plus a secondary affix as payoff.
// class_req -1: 2H weapons are NOT class-locked (no unique_effect). The 2H tag,
// stat bonus, and Rare+ stat requirement steer them without a hard lock.
var _2hw_greatsword = create_item("Ruinous Greatsword", "weapon", 1, "STR", 4, "takes both hands to swing", 44);
_2hw_greatsword.two_handed = true;  _2hw_greatsword.class_req = -1;  _2hw_greatsword.weapon_damage = 9;
_2hw_greatsword.affixes = [{ suffix: "of the Bear", prefix: "Hardy", stat_name: "CON", stat_value: 3 }];

var _2hw_longbow = create_item("Vault Longbow", "ranged_weapon", 1, "DEX", 4, "a tall war-bow drawn two-handed", 46);
_2hw_longbow.two_handed = true;  _2hw_longbow.class_req = -1;  _2hw_longbow.weapon_damage = 9;
_2hw_longbow.affixes = [{ suffix: "of Ruin", prefix: "Keen", stat_name: "crit_flat", stat_value: 5 }];

var _2hw_staff = create_item("Stormcaller Staff", "ranged_weapon", 2, "INT", 6, "a great runed staff held in both hands", 96);
_2hw_staff.two_handed = true;  _2hw_staff.class_req = -1;  _2hw_staff.weapon_damage = 13;
_2hw_staff.affixes = [{ suffix: "of Clarity", prefix: "Wise", stat_name: "WIS", stat_value: 4 }];

// --- ELEMENTAL WEAPONS (SYSTEMS_WEAPON_ROLES.md §C) ---
// Hand-authored examples of the elemental affix so a player reliably sees the
// burn/frost/shock setup->detonation loop (drops also roll it on ~40% of weapons).
// The affix renames the item (Flaming / Frostbound / Storm-touched) and adds a
// small elemental hit + a short setup status, reach-gated by the weapon's slot.
var _ew_flaming = create_item("Iron Brand", "weapon", 1, "STR", 3, "a soldier's blade", 40);
apply_elemental_affix_to_item(_ew_flaming, make_elem_affix("burn", 1));

var _ew_frost = create_item("Hunter's Bow", "ranged_weapon", 1, "DEX", 3, "a steady recurve bow", 42);
apply_elemental_affix_to_item(_ew_frost, make_elem_affix("frost", 1));

var _ew_storm = create_item("Runed Scepter", "ranged_weapon", 2, "INT", 5, "crowned with a storm-glass shard", 88);
apply_elemental_affix_to_item(_ew_storm, make_elem_affix("shock", 2));

// --- DEFENSIVE OFFHANDS (SYSTEMS_WEAPON_ROLES.md §D2) ---
// Shield-type offhands carry real DEFENSIVE value (armor / dodge / max HP) so
// giving up the offhand for a 2H weapon's bigger damage is a genuine trade.
var _off_cracked_shield = create_item("Cracked Shield", "offhand", 0, "CON", 2, "splintered but still turns a blow", 12);
_off_cracked_shield.affixes = [{ suffix: "of Warding", prefix: "Sturdy", stat_name: "armor", stat_value: 2 }];

var _off_buckler = create_item("Warden's Buckler", "offhand", 1, "CON", 4, "light enough to parry with", 30);
_off_buckler.affixes = [
    { suffix: "of Warding", prefix: "Sturdy", stat_name: "armor",      stat_value: 3 },
    { suffix: "of Deflection", prefix: "Nimble", stat_name: "dodge_flat", stat_value: 2 },
];

var _off_bulwark = create_item("Ironhide Bulwark", "offhand", 2, "CON", 6, "processed vault-metal", 80);
_off_bulwark.affixes = [{ suffix: "of the Mountain", prefix: "Ironhide", stat_name: "armor", stat_value: 5 }];

var _off_soul_orb = create_item("Soulbound Orb", "offhand", 2, "INT", 6, "wards the bearer's life", 85);
_off_soul_orb.affixes = [{ suffix: "of Vitality", prefix: "Soulbound", stat_name: "bonus_max_hp", stat_value: 10 }];

// --- PRE-DECLARED MULTI-STAT ITEMS (intrinsic secondary stats as affixes) ---
var _ember_ring = create_item("Ember Ring", "ring", 1, "STR", 2, "glows with a warm inner heat", 26);
_ember_ring.affixes = [{ suffix: "of Insight", prefix: "Arcane", stat_name: "INT", stat_value: 2 }];

var _forsaken_circlet = create_item("Forsaken Circlet", "helm", 2, "INT", 5, "worn by a mage of the fallen court", 82);
_forsaken_circlet.affixes = [{ suffix: "of Clarity", prefix: "Wise", stat_name: "WIS", stat_value: 3 }];

// --- DEMO SCHOOL-DAMAGE JEWELRY (SYSTEMS_ELEMENT_SCHOOLS.md §C, Phase 1) ---
// Hand-authored "+X <school> damage" pieces so the flat school-damage axis is
// reachable before rolled affixes exist (Phase 2). The school_<name> affix adds a
// flat bonus to every damaging ability of that school (mitigated by the ability's
// own type). Magnitudes by affix tier: uncommon +1, rare +2-4 (cap 4), epic +5-6.
var _sch_ember = create_item("Emberheart Talisman", "amulet", 2, "INT", 5, "a warm coal that never cools", 76);
_sch_ember.affixes = [{ suffix: "of Flames", prefix: "Smoldering", stat_name: "school_fire", stat_value: 4 }];

var _sch_blood = create_item("Bloodsoaked Band", "ring", 1, "CON", 3, "darkened with old stains", 28);
_sch_blood.affixes = [{ suffix: "of the Leech", prefix: "Sanguine", stat_name: "school_blood", stat_value: 1 }];

var _sch_venom = create_item("Venomous Signet", "ring", 1, "DEX", 3, "the crest weeps a green bead", 28);
_sch_venom.affixes = [{ suffix: "of Venom", prefix: "Toxic", stat_name: "school_poison", stat_value: 1 }];

global.loot_table_common = [
    // Weapons. Generic (class_req -1) bases fill every archetype so each class
    // finds an equippable, stat-appropriate weapon. Names resolve to the right
    // stat under weapon_required_stat (spear/saber/pike->STR, sickle->DEX, wand->INT).
    _cw_ashen,
    _cw_shortbow,
    _cw_cracked_wand,
    create_item("Chipped Spear", "weapon",        0, "STR", 2, "a notched footman's spear",      14),
    create_item("Rusty Sickle",  "weapon",        0, "DEX", 2, "a farmer's tool gone to rust",   13),
    create_item("Bent Wand",     "ranged_weapon", 0, "INT", 2, "warped but it still channels",   13),
    // Offhand
    _off_cracked_shield,
    create_item("Ash Totem",          "offhand", 0, "WIS", 1, "carved wood talisman",      9),
    create_item("Soulstone Fragment", "offhand", 0, "INT", 1, "chip of raw soulstone",      9),
    // Helm
    create_item("Ashen Hood",         "helm",    0, "DEX", 1, "protects from vault dust",   9),
    create_item("Bone Cap",           "helm",    0, "CON", 1, "crude skull-shaped guard",   8),
    create_item("Tarnished Visor",    "helm",    0, "STR", 1, "bent but still sturdy",      8),
    // Chest - spread across stats so every class finds usable chests (was CON/DEX only).
    create_item("Tattered Robes",     "chest",   0, "CON", 1, "",                          10),
    create_item("Rusted Chainshirt",  "chest",   0, "CON", 2, "rough but solid",            11),
    create_item("Shadowcloth Tunic",  "chest",   0, "DEX", 1, "woven shadow-thread",         9),
    create_item("Spellweave Robe",    "chest",   0, "INT", 1, "rune-stitched cloth",         9),
    create_item("Acolyte Vestment",   "chest",   0, "WIS", 1, "simple temple garb",          9),
    create_item("Padded Brigandine",  "chest",   0, "STR", 1, "quilted and studded",        10),
    // Gloves
    create_item("Worn Gauntlets",     "gloves",  0, "STR", 1, "old iron, liner rotted",     8),
    create_item("Nimble Wraps",       "gloves",  0, "DEX", 1, "tight cloth for grip",       8),
    create_item("Sage's Gloves",      "gloves",  0, "INT", 1, "finger-cut for rune work",   7),
    // Boots
    create_item("Worn Treads",        "boots",   0, "DEX", 1, "good for running",            7),
    create_item("Ironshod Boots",     "boots",   0, "CON", 1, "iron toe-caps",               8),
    create_item("Dustwalker Wraps",   "boots",   0, "WIS", 1, "padded foot-wrappings",       7),
    // Amulet
    create_item("Dusty Amulet",       "amulet",  0, "WIS", 1, "",                            8),
    create_item("Bone Talisman",      "amulet",  0, "CON", 1, "carved from femur bone",      8),
    create_item("Silver Chain",       "amulet",  0, "CHA", 1, "tarnished but charming",      7),
    // Ring
    create_item("Bone Ring",          "ring",    0, "INT", 1, "",                            8),
    create_item("Copper Signet",      "ring",    0, "STR", 1, "crest of no house",           7),
    create_item("Tarnished Band",     "ring",    0, "DEX", 1, "worn smooth",                  7),
];

global.loot_table_uncommon = [
    // Weapons. Class-locked (unique_effect) + generic (class_req -1) bases.
    _uw_gravel,
    _uw_wand,
    _uw_sickle,
    _2hw_greatsword,
    _2hw_longbow,
    _ew_flaming,
    _ew_frost,
    create_item("Iron Saber",     "weapon",        1, "STR", 4, "a heavy cavalry saber",          34),
    create_item("Soldier's Pike", "weapon",        1, "STR", 4, "a long infantry pike",           34),
    create_item("Recurve Bow",    "ranged_weapon", 1, "DEX", 4, "a hunter's recurve",             36),
    create_item("Oak Staff",      "ranged_weapon", 1, "INT", 4, "a channeling staff of seasoned oak", 36),
    create_item("Brass Scepter",  "ranged_weapon", 1, "INT", 4, "a tarnished ceremonial scepter", 35),
    // Offhand
    _off_buckler,
    create_item("Runic Focus",         "offhand", 1, "INT", 3, "inscribed with focusing runes", 32),
    // Helm
    create_item("Watcher's Cowl",      "helm",    1, "INT", 3, "hood of a Vault Watcher",       28),
    create_item("Iron Skullcap",       "helm",    1, "CON", 3, "riveted steel, dented solid",   26),
    // Chest
    create_item("Shadowthread Vest",   "chest",   1, "DEX", 3, "",                              32),
    create_item("Ashwarden Coat",      "chest",   1, "CON", 3, "ash-fiber reinforced leather",  28),
    create_item("Mage's Robe",         "chest",   1, "INT", 3, "woven for spell-focus",         30),
    create_item("Druidic Wrap",        "chest",   1, "WIS", 3, "bound with living vine",         29),
    create_item("Soldier's Cuirass",   "chest",   1, "STR", 3, "battered campaign plate",        30),
    // Gloves
    create_item("Irongrip Gauntlets",  "gloves",  1, "STR", 3, "weighted knuckles",             26),
    create_item("Fleethand Wraps",     "gloves",  1, "DEX", 3, "moves with the wearer",         28),
    // Boots
    create_item("Vaultstrider Boots",  "boots",   1, "DEX", 3, "built for confined spaces",     27),
    create_item("Stoneguard Greaves",  "boots",   1, "CON", 3, "leg plates absorb each blow",   26),
    // Amulet
    create_item("Sentry's Pendant",    "amulet",  1, "WIS", 3, "",                              28),
    create_item("Soul-Linked Talisman","amulet",  1, "INT", 3, "arcane resonance",              30),
    // Ring
    _ember_ring,
    create_item("Voidtouched Ring",    "ring",    1, "INT", 3, "hums with void energy",         28),
    _sch_blood,   // +1 Blood school damage (demo)
    _sch_venom,   // +1 Poison school damage (demo)
];

global.loot_table_rare = [
    // Weapons. Class-locked (unique_effect) + generic (class_req -1) bases.
    // Generic rare names resolve to the matching stat so the Rare+ stat gate
    // (req_stat_curve = 12) steers each one to the right class.
    _rw_ash,
    _rw_vsept,
    _rw_serp,
    _2hw_staff,
    _ew_storm,
    create_item("Tempered Saber",  "weapon",        2, "STR", 6, "folded steel, keen and balanced",      78),
    create_item("Warden's Spear",  "weapon",        2, "STR", 6, "the long spear of a vault warden",      78),
    create_item("Reaper's Sickle", "weapon",        2, "DEX", 6, "a wicked curved harvesting hook",       78),
    create_item("Vaultwood Bow",   "ranged_weapon", 2, "DEX", 6, "cut from rare vault-grown wood",        80),
    create_item("Crystal Wand",    "ranged_weapon", 2, "INT", 6, "a focusing wand tipped with raw crystal", 80),
    create_item("Runed Staff",     "ranged_weapon", 2, "INT", 6, "etched with channeling runes",          80),
    // Offhand
    _off_soul_orb,
    _off_bulwark,
    // Helm
    _forsaken_circlet,
    create_item("Thornwarden Helm",    "helm",    2, "STR", 5, "war-crest of a fallen guardian", 75),
    // Chest
    create_item("Voidskin Coat",       "chest",   2, "DEX", 5, "",                              75),
    create_item("Ironveil Plate",      "chest",   2, "CON", 7, "",                              90),
    create_item("Archmage Vestment",   "chest",   2, "INT", 5, "humming with ley-energy",       80),
    create_item("Oracle Mantle",       "chest",   2, "WIS", 5, "embroidered with seer-sigils",  78),
    create_item("Warplate Cuirass",    "chest",   2, "STR", 7, "forged for front-line wardens",  90),
    // Gloves
    create_item("Crushers",            "gloves",  2, "STR", 5, "massive war-gauntlets",         72),
    create_item("Whispergloves",       "gloves",  2, "DEX", 5, "make no sound at all",          75),
    // Boots
    create_item("Shadowstep Boots",    "boots",   2, "DEX", 5, "move between shadows",          74),
    create_item("Colossus Stompers",   "boots",   2, "CON", 6, "each step shakes the floor",    78),
    // Amulet
    create_item("Medallion of Endurance","amulet",2, "CON", 5, "endures where others break",    72),
    create_item("Warden's Eye",        "amulet",  2, "WIS", 5, "see threats before they strike", 75),
    _sch_ember,   // +4 Fire school damage (demo)
    // Ring
    create_item("Wraithbone Signet",   "ring",    2, "WIS", 5, "",                              70),
    create_item("Bloodpact Ring",      "ring",    2, "STR", 5, "sealed in blood",               72),
];

// --- LEGENDARY LOOT TABLE - boss-drop only (5% weight) ---
// Each legendary has fixed affixes and a unique effect hook (unique_effect string).
// unique_desc is the in-game text shown in gold; unique_effect is the code identifier.
var _leg_brand = create_item("Gatewarden's Brand", "weapon", 4, "STR", 4,
    "carried by those who sealed the vault gates", 400);
_leg_brand.class_req    = -1;
_leg_brand.affixes      = [{ suffix: "of Grit", prefix: "Sturdy", stat_name: "CON", stat_value: 2 }];
_leg_brand.unique_effect = "gatewarden_brand";
_leg_brand.unique_desc   = "First ability each combat costs 0 AP";
_leg_brand.lore = "Forged for the wardens who chained the vault shut from the inside, knowing they would never leave. Its edge still remembers the weight of the gate - and swings as if no burden could ever slow the first blow.";

var _leg_aegis = create_item("Heartstone Aegis", "chest", 4, "CON", 4,
    "warm to the touch, even in the coldest vault", 400);
_leg_aegis.class_req    = -1;
_leg_aegis.affixes      = [{ suffix: "of Clarity", prefix: "Wise", stat_name: "WIS", stat_value: 2 }];
_leg_aegis.unique_effect = "heartstone_aegis";
_leg_aegis.unique_desc   = "Heal 5 HP whenever an enemy dies";
_leg_aegis.lore = "A shard of the vault's buried heart, still beating long after the body around it failed. Those who wear it feel a borrowed warmth with every enemy that falls - the stone feeding on endings to keep its bearer from one.";

var _leg_crown = create_item("Crown of the Hollow King", "helm", 4, "INT", 4,
    "the king who vanished is still being waited for", 400);
_leg_crown.class_req    = -1;
_leg_crown.affixes      = [{ suffix: "of Clarity", prefix: "Wise", stat_name: "WIS", stat_value: 3 }];
_leg_crown.unique_effect = "crown_hollow_king";
_leg_crown.unique_desc   = "+1 trait slot while equipped (3 total)";
_leg_crown.lore = "The Hollow King walked into the deepest vault and never came out; his court still sets a throne for his return. To wear his crown is to carry a little of that endless waiting - and the wider, sharper mind of someone who has stopped expecting an answer.";

var _leg_thief = create_item("Thief of Hours", "ring", 4, "DEX", 2,
    "inscribed with the last seconds of a dying mage", 400);
_leg_thief.class_req    = -1;
_leg_thief.affixes      = [{ suffix: "of Clarity", prefix: "Wise", stat_name: "WIS", stat_value: 2 }];
_leg_thief.unique_effect = "thief_of_hours";
_leg_thief.unique_desc   = "Gain +1 AP on the first turn of every combat";
_leg_thief.lore = "A dying mage spent her final spell not to survive, but to keep the last seconds of her life - and bound them into this ring. Whoever wears it begins each fight already a heartbeat ahead, spending borrowed time she will never get back.";

global.loot_table_legendary = [ _leg_brand, _leg_aegis, _leg_crown, _leg_thief ];

// --- AFFIX POOL - 10 affixes, rolled at drop time for uncommon+ items ---
// u_val/r_val/e_val = stat bonus at uncommon / rare / epic rarity.
// Special stat_names: bonus_max_hp (flat HP), crit_flat (%crit), dodge_flat (flat dodge),
//                     gold_find (% bonus, display only - hook in add_gold for future use).
global.affix_pool = [
    { suffix: "of Might",    prefix: "Iron",    stat_name: "STR",          u_val: 1, r_val: 2, e_val: 3 },
    { suffix: "of Grace",    prefix: "Swift",   stat_name: "DEX",          u_val: 1, r_val: 2, e_val: 3 },
    { suffix: "of Grit",     prefix: "Sturdy",  stat_name: "CON",          u_val: 1, r_val: 2, e_val: 3 },
    { suffix: "of Insight",  prefix: "Arcane",  stat_name: "INT",          u_val: 1, r_val: 2, e_val: 3 },
    { suffix: "of Clarity",  prefix: "Lucid",   stat_name: "WIS",          u_val: 1, r_val: 2, e_val: 3 },
    { suffix: "of Charm",    prefix: "Gilded",  stat_name: "CHA",          u_val: 1, r_val: 2, e_val: 3 },
    { suffix: "of Vitality", prefix: "Vital",   stat_name: "bonus_max_hp", u_val: 5, r_val: 10, e_val: 15 },
    { suffix: "of Ruin",     prefix: "Runed",   stat_name: "crit_flat",    u_val: 3, r_val: 5,  e_val: 8  },
    { suffix: "of Shadows",  prefix: "Ghost",   stat_name: "dodge_flat",   u_val: 3, r_val: 5,  e_val: 8  },
    { suffix: "of Greed",    prefix: "Lucky",   stat_name: "gold_find",    u_val: 3, r_val: 5,  e_val: 8  },
];

// School-damage affix pool (SYSTEMS_ELEMENT_SCHOOLS.md §F1, Phase 2).
// Flat "+X <school> damage" affixes that roll ONLY on caster slots
// (amulet / ring / focus-type offhand) via roll_affixes(). Magnitude is set by
// the per-tier rule in school_affix_value() (uncommon +1, rare +2-4, epic +5-6),
// NOT fixed u/r/e values, so these entries carry only naming + the school key.
// stat_name "school_<name>" is routed into school_dmg by _equip_apply_stat.
// Caster-flavored prefix/suffix, kept distinct from the weapon elemental affixes.
global.school_affix_pool = [
    { school: "fire",   stat_name: "school_fire",   prefix: "Smoldering",   suffix: "of Flames"      },
    { school: "frost",  stat_name: "school_frost",  prefix: "Rimebound",    suffix: "of Rime"        },
    { school: "shock",  stat_name: "school_shock",  prefix: "Voltaic",      suffix: "of Thunder"     },
    { school: "arcane", stat_name: "school_arcane", prefix: "Eldritch",     suffix: "of Mysteries"   },
    { school: "poison", stat_name: "school_poison", prefix: "Toxic",        suffix: "of Venom"       },
    { school: "void",   stat_name: "school_void",   prefix: "Voidtouched",  suffix: "of the Void"    },
    { school: "shadow", stat_name: "school_shadow", prefix: "Umbral",       suffix: "of Shadow"      },
    { school: "blood",  stat_name: "school_blood",  prefix: "Sanguine",     suffix: "of Bloodletting"},
];


// -----------------------------------------------------------------------------
// 7. CONSUMABLES
// Pools used by handle_enemy_drops(); player inventory resets each run.
// -----------------------------------------------------------------------------
global.consumables_standard = [
    create_consumable("Healing Salve",    "heal",           25, "Restore 25 HP",                    20),
    create_consumable("Antidote",         "cleanse_dot",     0, "Clear all active DoT effects",      18),
    create_consumable("Energy Tonic",     "energy",          1, "Gain +1 AP this turn (free to use)", 15),
    create_consumable("Smelling Salts",   "cleanse_debuff",  0, "Remove one active debuff",          16),
];

global.consumables_elite = [
    create_consumable("Greater Healing Salve", "heal",        50, "Restore 50 HP",                          45),
    create_consumable("Purification Draught",  "cleanse_all",  0, "Clear all negative effects",             50),
    create_consumable("Adrenaline Vial",        "energy",       3, "Gain +3 AP this turn (free to use)",     55),
    create_consumable("Warden's Tonic",         "heal_dot",     8, "Restore 8 HP per turn for 3 turns",      48),
];

// Per-run consumable inventory (uncapped; lists scroll) and item drop log
global.consumable_inventory = [];
global.run_items_found      = [];

// Equipment slots - 10 entries, one per slot (undefined = empty)
// Index 8 = Ranged Weapon (appended; SYSTEMS_WEAPON_ROLES.md §A).
// Index 9 = Ring 2 (second ring position; accepts "ring" items).
global.inventory = array_create(EQUIP_SLOT_COUNT, undefined);

// Item codex - records base names of every equipment item ever found or bought
global.items_discovered = [];

// Item storage
global.equipment_stash    = [];   // safe hub storage - never lost on death
global.carried_items      = [];   // unequipped equipment in pack during a run - at risk on death
global.consumable_stash   = [];   // consumables stored safely in the hub
global.secure_slots       = 0;    // future trait: guaranteed-safe carried item count
global.secured_items      = [];   // indices into carried_items marked safe (unused while secure_slots==0)
global.last_run_mercy_item = "";  // name of the one item salvaged on defeat (shown on result screen)


// -----------------------------------------------------------------------------
// 7. RUN HISTORY
// Append-only array of run record structs written by end_run().
// Displayed on the hub history screen (H key).
// -----------------------------------------------------------------------------
global.run_history = [];


// -----------------------------------------------------------------------------
// 8. HUB PROGRESSION
// Incremented on each successful dungeon clear. Used by hub objects to gate
// upgrades, unlock NPCs, and advance the overworld narrative.
// -----------------------------------------------------------------------------
global.hub_unlocks = 0;

// Cleared state for each room on the current floor - persists across the
// combat room transition so the floor map is not reset on return.
global.floor_rooms_cleared = [];


// add_gold() and end_run() live in scripts/scr_stats/scr_stats.gml so they
// are available globally without depending on this object's scope.


// -----------------------------------------------------------------------------
// 9. CHARACTER MENU STATE
// Owned here so the menu works across all rooms without a separate object.
// -----------------------------------------------------------------------------
menu_open            = false;
menu_tab             = 0;
tab_names            = ["Stats", "Equipment", "Abilities", "Consumables", "Compendium"];
items_used_this_turn = 0;

// Compendium (Help) tab state - index of the selected section in the left list
compendium_section   = 0;

// Equipment tab state
equip_slot_selected = 0;
equip_picker_open   = false;
equip_picker_index  = 0;
equip_msg           = "";   // class-restriction warning shown in the picker
equip_notif_msg     = "";   // brief "Equipped X" confirmation
equip_notif_timer   = 0;    // counts down from 150; fades in last 30 frames

comparison_open     = false;
comparison_item     = undefined;
comparison_equipped = undefined;

// Consumable tab submenu state
consumable_submenu_open   = false;
consumable_submenu_cursor = 0;

// Hub stash screen state
stash_mode_open  = false;   // full stash deposit/withdraw screen
stash_mode_side  = 0;       // 0 = carried column, 1 = stash column
stash_mode_index = 0;


// -----------------------------------------------------------------------------
// 10. XP / LEVELING
// -----------------------------------------------------------------------------
global.run_xp              = 0;
global.run_level           = 1;
global.pending_stat_points = 0;
global.run_stat_bonuses    = { STR: 0, DEX: 0, CON: 0, INT: 0, WIS: 0, CHA: 0 };

// Permanent allocation points (accumulate across runs, spent in hub)
global.pending_perm_points = 0;

// Post-combat stat allocation overlay (used by obj_combat_controller Draw/Step)
level_alloc_open         = false;
level_alloc_index        = 0;
level_alloc_pending_stat = -1;  // -1 = nothing chosen yet; 0-5 = provisional stat index

// Hub permanent stat allocation overlay
perm_alloc_open  = false;
perm_alloc_index = 0;


// -----------------------------------------------------------------------------
// 11. SHOP STATE
// -1 = closed, 0 = Petra's Supplies, 1 = Dorn's Forge
// -----------------------------------------------------------------------------
global.petra_stock_special = undefined;   // elite consumable on special offer, or undefined
global.petra_special_qty   = 0;
global.dorn_stock          = [];          // array of { item, price, sold }

// Vex the Trainer overlay state (full-screen, opened from the hub NPC list)
trainer_open         = false;
trainer_tab          = 0;     // 0 = Stats, 1 = Trait Slots, 2 = Abilities, 3 = Potency
trainer_cursor       = 0;     // selected row within the active tab
trainer_confirm      = false; // true while a non-refundable sacrifice awaits Space
trainer_notification = "";

// Shared item-sacrifice picker (Vex stat/trait trade + Shrine tribute). One modal,
// initialized once; see SYSTEMS_ITEM_PICKER.md. Captures input while open so the
// underlying screen is frozen and nothing is consumed without select + confirm.
if (!variable_global_exists("item_picker")) global.item_picker = {
    open:             false,
    purpose:          "",   // "vex_trait" | "vex_stat" | "shrine_boon"
    context:          {},   // purpose-specific payload (gold/effect_id/stat_key/boon_id...)
    candidates:       [],   // [{ source, idx, item, label, rarity, value }]  source 0=stash 1=pack
    cursor:           0,
    scroll:           0,
    confirm:          false,// an item is selected, awaiting yes/no
    resolved_purpose: "",   // one-shot: set on commit so the owning controller does aftermath
    result_msg:       ""    // notification text produced by the resolve
};

// Sable salvage confirm gate (keeps Sable's own dust-preview list; just arms a yes/no).
sable_confirm = false;

shop_open         = -1;
shop_index        = 0;
shop_notification = "";
shop_tab          = 0;    // 0 = BUY tab, 1 = SELL tab
sell_index        = 0;    // sell-list cursor row
sell_scroll       = 0;    // sell-list scroll offset (top visible row)
sell_confirm_name = "";   // non-empty = rare item awaiting Space confirmation

// Initial stock - loot tables are defined above, so this is safe to call here
restock_shops();


// -----------------------------------------------------------------------------
// 12. ABILITY LOADOUT STATE
// global.player_loadout persists between runs; loadout_* are session state.
// -----------------------------------------------------------------------------
if (!variable_global_exists("player_loadout")) {
    global.player_loadout = ["", "", "", "", ""];
}

loadout_open       = false;
ability_detail_open = false;   // Tab detail popup over the loadout ability list
vex_detail_open     = false;   // Tab detail popup over the Vex ability/trait list
loadout_cursor     = 0;
loadout_selected   = [];   // up to 4 ability name strings being built this session
loadout_full_timer = 0;    // countdown for "Loadout full" / "Slots full" flash (frames)
loadout_locked_timer = 0;  // countdown for "ability is locked - unlock at Vex" flash (frames)
loadout_confirmed  = false;
loadout_tab        = 0;    // 0 = Abilities tab, 1 = Traits tab
traits_cursor      = 0;
traits_selected    = [];   // up to 2 trait name strings being built this session


// -----------------------------------------------------------------------------
// 13. TRAIT SYSTEM STATE
// global.player_traits: up to 2 active trait names ("" = empty slot).
// global.traits_unlocked: which traits have been earned through progression.
// The three default universals (Sense, Scavenger, Thick Skin) start unlocked.
// -----------------------------------------------------------------------------
if (!variable_global_exists("player_traits")) {
    global.player_traits = ["", ""];
}
if (!variable_global_exists("traits_unlocked")) {
    global.traits_unlocked = {
        sense:            true,
        scavenger:        true,
        thick_skin:       true,
        lucky_find:       false,
        salvager:         false,
        soul_siphon:      false,
        crimson_reserve:  false,
        phantom_step:     false,
        // New traits - unlocked through progression
        quick_recovery:   false,
        treasure_hunter:  false,
        battle_hardened:  false,
        iron_will:        false,
        ley_tap:          false,
        arcane_surge:     false,
        vampiric_edge:    false,
        berserker_rage:   false,
        shadow_meld:       false,
        serrated_strikes:  false,
        expanded_arsenal:  false,
        prospector:        false,
        last_stand:        false,
        focused_power:     false,
        chain_caster:      false,
        plaguebearer:      false,
    };
}
// Backfill newer trait keys onto save files that predate them.
var _tu_defaults = ["prospector", "last_stand", "focused_power", "chain_caster", "plaguebearer"];
for (var _tui = 0; _tui < array_length(_tu_defaults); _tui++) {
    if (!variable_struct_exists(global.traits_unlocked, _tu_defaults[_tui])) {
        variable_struct_set(global.traits_unlocked, _tu_defaults[_tui], false);
    }
}

// Trait unlock notification - drawn as a toast banner in hub/floor draw events.
// Set trait_notif_msg and trait_notif_timer = 180 wherever a trait unlocks.
trait_notif_msg   = "";
trait_notif_timer = 0;

// -----------------------------------------------------------------------------
// 13b-RUNES. RUNE SYSTEM STATE (Maren the Runesmith) - see SYSTEMS_RUNES.md
// rune_inventory: unsocketed runes the player owns ({id,name,domain,tier} structs)
// rune_dust:      shared crafting reagent (Maren combines / Sable salvages)
// aspect_slots:   unlocked character Aspect-rune slots (start 2, cap 4)
// aspect_runes:   socketed Aspect runes (length <= aspect_slots)
// Socketed GEAR runes ride on each item struct (item.runes / item.socket_count).
// -----------------------------------------------------------------------------
if (!variable_global_exists("rune_inventory")) global.rune_inventory = [];
if (!variable_global_exists("rune_dust"))      global.rune_dust      = 0;
if (!variable_global_exists("aspect_slots"))   global.aspect_slots   = 2;
if (!variable_global_exists("aspect_runes"))   global.aspect_runes   = [];

// Maren the Runesmith screen state (Phase 1 tabs: 0 Socket, 1 Runes)
maren_open         = false;
maren_tab          = 0;    // 0 = Socket gear, 1 = Runes (owned list)
maren_cursor       = 0;    // row cursor in the active list
maren_phase        = 0;    // Socket tab: 0 choose item, 1 choose socket, 2 choose rune
maren_item_sel     = -1;   // chosen equipped-item slot index (0-7) in Socket tab
maren_notification = "";

// Sable the Alchemist screen state (tabs: 0 Salvage, 1 Brew, 2 Upgrade)
sable_open         = false;
sable_tab          = 0;
sable_cursor       = 0;
sable_phase        = 0;    // Salvage tab: 0 menu, 1 gear list, 2 rune list
sable_notification = "";

// Vael the Aesthete - transmog/skins (player_skin = active skin id)
if (!variable_global_exists("player_skin"))    global.player_skin    = "default";
if (!variable_global_exists("unlocked_skins")) global.unlocked_skins = [];

// Cosmetic gender axis ("m"/"f") - chosen at character creation, combat sprite only.
if (!variable_global_exists("player_gender"))  global.player_gender  = "m";
vael_open            = false;
vael_cursor          = 0;
vael_notification    = "";
vael_tab             = 0;   // 0 = Skins (transmog), 1 = Portrait (100g portrait change)
vael_portrait_cursor = 0;   // browse index into global.portrait_sprites on the Portrait tab

// -----------------------------------------------------------------------------
// 13b. VEX THE TRAINER - permanent upgrades bought with gold (+items for stats)
// bonus_trait_slots: extra active-trait slots purchased (base 2, +2 max -> 4 total).
// unlocked_abilities: names of non-starter abilities purchased into the loadout pool.
// trait_potency: struct keyed by trait name -> potency tier (0-5); each tier adds
//                +10% to that trait's magnitude, paid for by permanently sacrificing
//                5 points of the trait's associated permanent stat.
// -----------------------------------------------------------------------------
if (!variable_global_exists("bonus_trait_slots")) global.bonus_trait_slots = 0;
if (!variable_global_exists("unlocked_abilities")) global.unlocked_abilities = [];
if (!variable_global_exists("trait_potency"))      global.trait_potency      = {};

// Persistent Battle Hardened HP bonus (accumulates across runs)
if (!variable_global_exists("perm_hp_battle_hardened")) global.perm_hp_battle_hardened = 0;
// Total boss kills across all runs (for trait/ability unlock gating)
if (!variable_global_exists("total_boss_kills")) global.total_boss_kills = 0;
// Highest character level ever reached in a run (persistent; gates char_level abilities)
if (!variable_global_exists("highest_run_level")) global.highest_run_level = 1;
// Last Stand trait: consumed once per run, reset at run start (end_run)
if (!variable_global_exists("last_stand_used")) global.last_stand_used = false;
// Player portrait selection (index into portrait_sprites array)
if (!variable_global_exists("chosen_portrait")) global.chosen_portrait = 0;

// Pause / Esc menu state (Resume / Settings / Quit to Title)
if (!variable_global_exists("pause_open"))   global.pause_open   = false;
if (!variable_global_exists("pause_cursor")) global.pause_cursor = 0;
// Set true at the top of this controller's Step whenever a gc-managed overlay/modal
// is open, so the hub's pause-menu trigger (a separate object that may step before us)
// won't also open the pause menu on the SAME Esc press that just closed the overlay.
if (!variable_global_exists("ui_overlay_latch")) global.ui_overlay_latch = false;
// Character-creation / hub portrait pool. The 60 class-themed portraits below
// (imported at 512x512) replace the old generic spr_portrait_01..11 placeholders,
// which still exist as resources but are no longer offered. One flat A/D cycle,
// grouped class -> gender (Arcanist M/F, Bloodwarden M/F, Shadowstrider M/F) with
// the named alt portraits (Deathweaver / Plaguehunter) at the end of each class.
global.portrait_sprites = [
    spr_portrait_arc_m1, spr_portrait_arc_m2, spr_portrait_arc_m3,
    spr_portrait_arc_m4, spr_portrait_arc_m5, spr_portrait_arc_m6,
    spr_portrait_arc_m7, spr_portrait_arc_m8, spr_portrait_arc_m9,
    spr_portrait_arc_f1, spr_portrait_arc_f2, spr_portrait_arc_f3,
    spr_portrait_arc_f4, spr_portrait_arc_f5, spr_portrait_arc_f6,
    spr_portrait_arc_f7, spr_portrait_arc_f8, spr_portrait_arc_deathweaver,
    spr_portrait_blood_m1, spr_portrait_blood_m2, spr_portrait_blood_m3,
    spr_portrait_blood_m4, spr_portrait_blood_m5, spr_portrait_blood_m6,
    spr_portrait_blood_m7, spr_portrait_blood_m8, spr_portrait_blood_m9,
    spr_portrait_blood_m10, spr_portrait_blood_m11, spr_portrait_blood_m12,
    spr_portrait_blood_f1, spr_portrait_blood_f2, spr_portrait_blood_f3,
    spr_portrait_blood_f4, spr_portrait_blood_f5, spr_portrait_blood_f6,
    spr_portrait_blood_f7, spr_portrait_blood_f8, spr_portrait_blood_f9,
    spr_portrait_blood_f10, spr_portrait_blood_f11, spr_portrait_blood_f12,
    spr_portrait_blood_f13, spr_portrait_shadow_m1, spr_portrait_shadow_m2,
    spr_portrait_shadow_m3, spr_portrait_shadow_m4, spr_portrait_shadow_m5,
    spr_portrait_shadow_m6, spr_portrait_shadow_m7, spr_portrait_shadow_m8,
    spr_portrait_shadow_m9, spr_portrait_shadow_f1, spr_portrait_shadow_f2,
    spr_portrait_shadow_f3, spr_portrait_shadow_f4, spr_portrait_shadow_f5,
    spr_portrait_shadow_f6, spr_portrait_shadow_f7, spr_portrait_shadow_plaguehunter,
];

// Load persisted meta-progression only if a slot was selected before this room was entered.
// For new games the slot is set but load_game() is skipped - defaults from above apply.
if (global.save_slot >= 0) load_game();


// -----------------------------------------------------------------------------
// 14. DUNGEON SELECTION
// Persisted per-dungeon ascendance unlock level and clear count.
// -----------------------------------------------------------------------------
if (!variable_global_exists("selected_dungeon")) {
    global.selected_dungeon = "ashen_vault";
}
if (!variable_global_exists("selected_ascendance")) {
    global.selected_ascendance = 0;
}
if (!variable_global_exists("dungeon_ascendance_unlocked")) {
    global.dungeon_ascendance_unlocked = {
        ashen_vault:     0,
        scorched_depths: 0,
        tundra_tomb:     0,
    };
}
if (!variable_global_exists("dungeon_clears")) {
    global.dungeon_clears = {
        ashen_vault:     0,
        scorched_depths: 0,
        tundra_tomb:     0,
    };
}
if (!variable_global_exists("dungeon_clears_total")) global.dungeon_clears_total = 0;

dungeon_select_open   = false;
dungeon_select_cursor = 0;   // 0 = ashen_vault, 1 = scorched_depths, 2 = tundra_tomb
dungeon_select_asc    = 0;

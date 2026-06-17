depth = -99999; // draw GUI on top of all room controllers

// Lock window and GUI layer to the designed resolution so playtest and
// compiled game always render at 1280x720 regardless of IDE settings.
window_set_size(1280, 720);
window_center();
display_set_gui_size(1280, 720);

// =============================================================================
// obj_game_controller — Create event
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
var _cw_ashen        = create_item("Ashen Blade",    "weapon", 0, "STR", 2, "+2 STR",                       15);
var _cw_shortbow     = create_item("Worn Shortbow",  "weapon", 0, "DEX", 2, "+2 DEX",                       14);
var _cw_cracked_wand = create_item("Cracked Focus",  "weapon", 0, "INT", 2, "+2 INT, still channels power", 13);
_cw_ashen.class_req = -1;  _cw_shortbow.class_req = -1;  _cw_cracked_wand.class_req = 0;

// --- UNCOMMON WEAPONS ---
var _uw_gravel  = create_item("Gravelstone Sword", "weapon", 1, "STR", 4, "+4 STR, dense and brutal",              35);
var _uw_wand    = create_item("Vaultstone Wand",   "weapon", 1, "INT", 4, "+4 INT, inscribed vault runes",         38);
var _uw_sickle  = create_item("Shadow Sickle",     "weapon", 1, "DEX", 4, "+4 DEX, curved blade of the striders", 36);
_uw_gravel.class_req = 1;  _uw_wand.class_req = 0;  _uw_sickle.class_req = 2;

// --- RARE WEAPONS ---
var _rw_ash    = create_item("Ashkeeper Blade",  "weapon", 2, "STR", 6, "+6 STR, forged in ashwalker tradition", 80);
var _rw_vsept  = create_item("Void Scepter",     "weapon", 2, "INT", 6, "+6 INT, channels the void",            85);
var _rw_serp   = create_item("Serpent's Reach",  "weapon", 2, "DEX", 6, "+6 DEX, flexible blade of the deep",   82);
_rw_ash.class_req = 1;  _rw_vsept.class_req = 0;  _rw_serp.class_req = 2;

global.loot_table_common = [
    // Weapons
    _cw_ashen,
    _cw_shortbow,
    _cw_cracked_wand,
    // Offhand
    create_item("Cracked Shield",     "offhand", 0, "CON", 2, "+2 CON",                        12),
    create_item("Ash Totem",          "offhand", 0, "WIS", 1, "+1 WIS, carved wood talisman",   9),
    create_item("Soulstone Fragment", "offhand", 0, "INT", 1, "+1 INT, chip of raw crystal",     9),
    // Helm
    create_item("Ashen Hood",         "helm",    0, "DEX", 1, "+1 DEX, protects from vault dust", 9),
    create_item("Bone Cap",           "helm",    0, "CON", 1, "+1 CON, crude skull-shaped guard",  8),
    create_item("Tarnished Visor",    "helm",    0, "STR", 1, "+1 STR, bent but still sturdy",     8),
    // Chest
    create_item("Tattered Robes",     "chest",   0, "CON", 1, "+1 CON",                        10),
    create_item("Rusted Chainshirt",  "chest",   0, "CON", 2, "+2 CON, rough but solid",        11),
    create_item("Shadowcloth Tunic",  "chest",   0, "DEX", 1, "+1 DEX, woven shadow-thread",     9),
    // Gloves
    create_item("Worn Gauntlets",     "gloves",  0, "STR", 1, "+1 STR, old iron, liner rotted",  8),
    create_item("Nimble Wraps",       "gloves",  0, "DEX", 1, "+1 DEX, tight cloth for grip",    8),
    create_item("Sage's Gloves",      "gloves",  0, "INT", 1, "+1 INT, finger-cut for rune work", 7),
    // Boots
    create_item("Worn Treads",        "boots",   0, "DEX", 1, "+1 DEX, good for running",        7),
    create_item("Ironshod Boots",     "boots",   0, "CON", 1, "+1 CON, iron toe-caps",            8),
    create_item("Dustwalker Wraps",   "boots",   0, "WIS", 1, "+1 WIS, padded foot-wrappings",    7),
    // Amulet
    create_item("Dusty Amulet",       "amulet",  0, "WIS", 1, "+1 WIS",                          8),
    create_item("Bone Talisman",      "amulet",  0, "CON", 1, "+1 CON, carved from femur bone",   8),
    create_item("Silver Chain",       "amulet",  0, "CHA", 1, "+1 CHA, tarnished but charming",   7),
    // Ring
    create_item("Bone Ring",          "ring",    0, "INT", 1, "+1 INT",                           8),
    create_item("Copper Signet",      "ring",    0, "STR", 1, "+1 STR, crest of no house",        7),
    create_item("Tarnished Band",     "ring",    0, "DEX", 1, "+1 DEX, worn smooth",               7),
];

global.loot_table_uncommon = [
    // Weapons (class-restricted)
    _uw_gravel,
    _uw_wand,
    _uw_sickle,
    // Offhand
    create_item("Warden's Buckler",    "offhand", 1, "CON", 4, "+4 CON",                              30),
    create_item("Runic Focus",         "offhand", 1, "INT", 3, "+3 INT, inscribed with focusing runes",32),
    // Helm
    create_item("Watcher's Cowl",      "helm",    1, "INT", 3, "+3 INT, hood of a Vault Watcher",      28),
    create_item("Iron Skullcap",       "helm",    1, "CON", 3, "+3 CON, riveted steel, dented solid",  26),
    // Chest
    create_item("Shadowthread Vest",   "chest",   1, "DEX", 3, "+3 DEX",                              32),
    create_item("Ashwarden Coat",      "chest",   1, "CON", 3, "+3 CON, ash-fiber reinforced leather", 28),
    // Gloves
    create_item("Irongrip Gauntlets",  "gloves",  1, "STR", 3, "+3 STR, weighted knuckles",            26),
    create_item("Fleethand Wraps",     "gloves",  1, "DEX", 3, "+3 DEX, moves with the wearer",        28),
    // Boots
    create_item("Vaultstrider Boots",  "boots",   1, "DEX", 3, "+3 DEX, built for confined spaces",    27),
    create_item("Stoneguard Greaves",  "boots",   1, "CON", 3, "+3 CON, leg plates absorbing impact",  26),
    // Amulet
    create_item("Sentry's Pendant",    "amulet",  1, "WIS", 3, "+3 WIS",                              28),
    create_item("Soul-Linked Talisman","amulet",  1, "INT", 3, "+3 INT, arcane resonance",             30),
    // Ring
    create_item("Ember Ring",          "ring",    1, "STR", 2, "+2 STR +2 INT",                       26),
    create_item("Voidtouched Ring",    "ring",    1, "INT", 3, "+3 INT, hums with void energy",        28),
];

global.loot_table_rare = [
    // Weapons (class-restricted)
    _rw_ash,
    _rw_vsept,
    _rw_serp,
    // Offhand
    create_item("Soulbound Orb",       "offhand", 2, "INT", 6, "+6 INT",                              85),
    create_item("Ironhide Bulwark",    "offhand", 2, "CON", 6, "+6 CON, processed vault-metal",       80),
    // Helm
    create_item("Forsaken Circlet",    "helm",    2, "INT", 5, "+5 INT +3 WIS",                       82),
    create_item("Thornwarden Helm",    "helm",    2, "STR", 5, "+5 STR, war-crest of a fallen guardian",75),
    // Chest
    create_item("Voidskin Coat",       "chest",   2, "DEX", 5, "+5 DEX",                              75),
    create_item("Ironveil Plate",      "chest",   2, "CON", 7, "+7 CON",                              90),
    // Gloves
    create_item("Crushers",            "gloves",  2, "STR", 5, "+5 STR, massive war-gauntlets",       72),
    create_item("Whispergloves",       "gloves",  2, "DEX", 5, "+5 DEX, make no sound at all",        75),
    // Boots
    create_item("Shadowstep Boots",    "boots",   2, "DEX", 5, "+5 DEX, move between shadows",        74),
    create_item("Colossus Stompers",   "boots",   2, "CON", 6, "+6 CON, each step shakes the floor",  78),
    // Amulet
    create_item("Medallion of Endurance","amulet",2, "CON", 5, "+5 CON, endures where others break",  72),
    create_item("Warden's Eye",        "amulet",  2, "WIS", 5, "+5 WIS, see threats before they strike",75),
    // Ring
    create_item("Wraithbone Signet",   "ring",    2, "WIS", 5, "+5 WIS",                              70),
    create_item("Bloodpact Ring",      "ring",    2, "STR", 5, "+5 STR, sealed in blood",             72),
];

// --- LEGENDARY LOOT TABLE — boss-drop only (5% weight) ---
// Each legendary has fixed affixes and a unique effect hook (unique_effect string).
// unique_desc is the in-game text shown in gold; unique_effect is the code identifier.
var _leg_brand = create_item("Gatewarden's Brand", "weapon", 4, "STR", 4,
    "+4 STR, +2 CON", 400);
_leg_brand.class_req    = -1;
_leg_brand.affixes      = [{ suffix: "of Grit", prefix: "Sturdy", stat_name: "CON", stat_value: 2 }];
_leg_brand.unique_effect = "gatewarden_brand";
_leg_brand.unique_desc   = "First ability each combat costs 0 AP";

var _leg_aegis = create_item("Heartstone Aegis", "chest", 4, "CON", 4,
    "+4 CON, +2 WIS", 400);
_leg_aegis.class_req    = -1;
_leg_aegis.affixes      = [{ suffix: "of Clarity", prefix: "Wise", stat_name: "WIS", stat_value: 2 }];
_leg_aegis.unique_effect = "heartstone_aegis";
_leg_aegis.unique_desc   = "Heal 5 HP whenever an enemy dies";

var _leg_crown = create_item("Crown of the Hollow King", "helm", 4, "INT", 4,
    "+4 INT, +3 WIS", 400);
_leg_crown.class_req    = -1;
_leg_crown.affixes      = [{ suffix: "of Clarity", prefix: "Wise", stat_name: "WIS", stat_value: 3 }];
_leg_crown.unique_effect = "crown_hollow_king";
_leg_crown.unique_desc   = "+1 trait slot while equipped (3 total)";

var _leg_thief = create_item("Thief of Hours", "ring", 4, "DEX", 2,
    "+2 DEX, +2 WIS", 400);
_leg_thief.class_req    = -1;
_leg_thief.affixes      = [{ suffix: "of Clarity", prefix: "Wise", stat_name: "WIS", stat_value: 2 }];
_leg_thief.unique_effect = "thief_of_hours";
_leg_thief.unique_desc   = "Gain +1 AP on the first turn of every combat";

global.loot_table_legendary = [ _leg_brand, _leg_aegis, _leg_crown, _leg_thief ];

// --- AFFIX POOL — 10 affixes, rolled at drop time for uncommon+ items ---
// u_val/r_val/e_val = stat bonus at uncommon / rare / epic rarity.
// Special stat_names: bonus_max_hp (flat HP), crit_flat (%crit), dodge_flat (flat dodge),
//                     gold_find (% bonus, display only — hook in add_gold for future use).
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


// -----------------------------------------------------------------------------
// 7. CONSUMABLES
// Pools used by handle_enemy_drops(); player inventory resets each run.
// -----------------------------------------------------------------------------
global.consumables_standard = [
    create_consumable("Healing Salve",    "heal",           25, "Restore 25 HP",                    20),
    create_consumable("Antidote",         "cleanse_dot",     0, "Clear all active DoT effects",      18),
    create_consumable("Energy Tonic",     "energy",          1, "Restore 1 energy this turn",        15),
    create_consumable("Smelling Salts",   "cleanse_debuff",  0, "Remove one active debuff",          16),
];

global.consumables_elite = [
    create_consumable("Greater Healing Salve", "heal",        50, "Restore 50 HP",                          45),
    create_consumable("Purification Draught",  "cleanse_all",  0, "Clear all negative effects",             50),
    create_consumable("Adrenaline Vial",        "energy",       3, "Restore full energy immediately",        55),
    create_consumable("Warden's Tonic",         "heal_dot",     8, "Restore 8 HP per turn for 3 turns",      48),
];

// Per-run consumable inventory (max 4 slots) and item drop log
global.consumable_inventory = [];
global.run_items_found      = [];

// Equipment slots — 8 entries, one per slot (undefined = empty)
global.inventory = array_create(8, undefined);

// Item storage
global.equipment_stash    = [];   // safe hub storage — never lost on death
global.carried_items      = [];   // unequipped equipment in pack during a run — at risk on death
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

// Cleared state for each room on the current floor — persists across the
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
tab_names            = ["Stats", "Equipment", "Abilities", "Consumables"];
items_used_this_turn = 0;

// Equipment tab state
equip_slot_selected = 0;
equip_picker_open   = false;
equip_picker_index  = 0;
equip_msg           = "";   // class-restriction warning shown in the picker

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

shop_open         = -1;
shop_index        = 0;
shop_notification = "";
shop_tab          = 0;    // 0 = BUY tab, 1 = SELL tab
sell_index        = 0;    // sell-list cursor row
sell_scroll       = 0;    // sell-list scroll offset (top visible row)
sell_confirm_name = "";   // non-empty = rare item awaiting Space confirmation

// Initial stock — loot tables are defined above, so this is safe to call here
restock_shops();


// -----------------------------------------------------------------------------
// 12. ABILITY LOADOUT STATE
// global.player_loadout persists between runs; loadout_* are session state.
// -----------------------------------------------------------------------------
if (!variable_global_exists("player_loadout")) {
    global.player_loadout = ["", "", "", ""];
}

loadout_open       = false;
loadout_cursor     = 0;
loadout_selected   = [];   // up to 4 ability name strings being built this session
loadout_full_timer = 0;    // countdown for "Loadout full" / "Slots full" flash (frames)
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
        sense:           true,
        scavenger:       true,
        thick_skin:      true,
        lucky_find:      false,
        salvager:        false,
        soul_siphon:     false,
        crimson_reserve: false,
        phantom_step:    false,
    };
}

// Trait unlock notification — drawn as a toast banner in hub/floor draw events.
// Set trait_notif_msg and trait_notif_timer = 180 wherever a trait unlocks.
trait_notif_msg   = "";
trait_notif_timer = 0;

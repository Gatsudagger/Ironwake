// =============================================================================
// obj_floor_controller — Create event
// Initialises the dungeon floor map for the current floor. Reads and writes
// global floor-tracking variables managed by obj_game_controller.
// =============================================================================


// -----------------------------------------------------------------------------
// 1. GLOBAL FLOOR STATE
// Only initialised on first entry — preserved across room transitions so the
// player's progress through a run is not reset when returning from combat.
// -----------------------------------------------------------------------------
if (!variable_global_exists("current_floor")) {
    global.current_floor       = 1;
    global.current_room_index  = 0;
    global.rooms_cleared       = [];
    global.dungeon_complete    = false;
}


// -----------------------------------------------------------------------------
// 2. FLOOR LAYOUTS
// One entry per floor. Each floor is an array of room definition structs.
// Fields: type, name, enemies (combat/boss only), gold_min/max (treasure only),
//         cleared (mutated at runtime — do not share references between runs).
// -----------------------------------------------------------------------------
floor_layouts = [

    // Floor 1 — The Ashen Vault, upper level
    [
        { type: "combat",   name: "Dark Corridor",    enemies: "standard", cleared: false },
        { type: "combat",   name: "Collapsed Hall",   enemies: "standard", cleared: false },
        { type: "treasure", name: "Forgotten Cache",  gold_min: 30, gold_max: 60,  cleared: false },
        { type: "combat",   name: "Warden's Post",    enemies: "standard", cleared: false },
        { type: "boss",     name: "Vault Chamber",    enemies: "boss",     cleared: false },
    ],

    // Floor 2 — The Ashen Vault, mid level
    [
        { type: "combat",   name: "Lower Depths",     enemies: "standard", cleared: false },
        { type: "combat",   name: "Bone Gallery",     enemies: "elite",    cleared: false },
        { type: "treasure", name: "Ancient Vault",    gold_min: 50, gold_max: 90,  cleared: false },
        { type: "combat",   name: "Guardian Hall",    enemies: "standard", cleared: false },
        { type: "combat",   name: "Elite Chamber",    enemies: "elite",    cleared: false },
        { type: "boss",     name: "Throne of Ash",    enemies: "boss",     cleared: false },
    ],

    // Floor 3 — The Ashen Vault, depths
    [
        { type: "combat",   name: "The Deep Dark",    enemies: "standard", cleared: false },
        { type: "combat",   name: "Shattered Keep",   enemies: "elite",    cleared: false },
        { type: "treasure", name: "Warden's Hoard",   gold_min: 80, gold_max: 140, cleared: false },
        { type: "combat",   name: "The Killing Floor", enemies: "elite",   cleared: false },
        { type: "combat",   name: "Antechamber",      enemies: "standard", cleared: false },
        { type: "boss",     name: "The Final Seal",   enemies: "boss",     cleared: false },
    ],

];

selected_room = 0;


// -----------------------------------------------------------------------------
// 3. CURRENT ROOMS — built from layout with cleared states restored from global
// global.floor_rooms_cleared persists across room transitions so clearing a
// combat room is not lost when the scene reloads on return.
// -----------------------------------------------------------------------------
returning_from_combat = variable_global_exists("just_cleared_room") && global.just_cleared_room;
if (returning_from_combat) {
    global.just_cleared_room = false;
}

var _layout = floor_layouts[clamp(global.current_floor - 1, 0, 2)];
var _have_saved = variable_global_exists("floor_rooms_cleared")
                  && array_length(global.floor_rooms_cleared) == array_length(_layout);

if (!_have_saved) {
    // First entry on this floor — initialise cleared state in global storage
    global.floor_rooms_cleared = [];
    for (var _i = 0; _i < array_length(_layout); _i++) {
        array_push(global.floor_rooms_cleared, false);
    }
}

// Apply the just-cleared room before rebuilding so the state is already in
// global.floor_rooms_cleared when the struct array is constructed below.
// _have_saved guards against a floor-transition bug: after a boss kill,
// floor_rooms_cleared is reset to [] before room_goto fires, so _have_saved
// is false here. Without the guard, the stale current_room_index from the
// previous floor would pre-clear the room at the same index on the new floor.
if (returning_from_combat && _have_saved && global.current_room_index < array_length(_layout)) {
    global.floor_rooms_cleared[global.current_room_index] = true;
    // DEBUG — strip once floor progression is verified
    show_debug_message("[FLOOR DEBUG] cleared: floor=" + string(global.current_floor)
        + " room_index=" + string(global.current_room_index)
        + " have_saved=true");
    // END DEBUG
} else if (returning_from_combat) {
    // DEBUG — strip once floor progression is verified
    show_debug_message("[FLOOR DEBUG] returning_from_combat guard FAILED: floor=" + string(global.current_floor)
        + " have_saved=" + string(_have_saved)
        + " room_index=" + string(variable_global_exists("current_room_index") ? global.current_room_index : -1)
        + " layout_len=" + string(array_length(_layout)));
    // END DEBUG
}

// Build current_rooms from the layout, restoring cleared flags from global
current_rooms = [];
for (var _i = 0; _i < array_length(_layout); _i++) {
    var _r = _layout[_i];
    array_push(current_rooms, {
        type:     _r.type,
        name:     _r.name,
        enemies:  variable_struct_exists(_r, "enemies")  ? _r.enemies  : "standard",
        gold_min: variable_struct_exists(_r, "gold_min") ? _r.gold_min : 0,
        gold_max: variable_struct_exists(_r, "gold_max") ? _r.gold_max : 0,
        cleared:  global.floor_rooms_cleared[_i]
    });
}


// -----------------------------------------------------------------------------
// 4. TREASURE POPUP STATE
// When the player enters a treasure room the popup is shown before clearing it.
// treasure_timer drives the floating animation in Draw_64.
// treasure_item holds the dropped item struct (or undefined if no item dropped).
// -----------------------------------------------------------------------------
showing_treasure = false;
treasure_gold    = 0;
treasure_timer   = 0;
treasure_item    = undefined;

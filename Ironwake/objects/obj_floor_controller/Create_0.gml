// =============================================================================
// obj_floor_controller - Create event
// Builds a branching dungeon floor map. The map is a DAG of room nodes stored
// in global.floor_map so it survives room transitions without regenerating.
//
// Node struct fields:
//   id, layer, slot, type, name, enemies, gold_min, gold_max,
//   cleared, parents[], children[], px, py
//
// Accessibility rule: a room is enterable if it has no parents (entry node)
// OR any parent node has been cleared.
// =============================================================================


// -----------------------------------------------------------------------------
// 1. GLOBAL FLOOR STATE - initialised once per game session
// -----------------------------------------------------------------------------
if (!variable_global_exists("current_floor")) {
    global.current_floor       = 1;
    global.current_room_index  = 0;
    global.rooms_cleared       = [];
    global.dungeon_complete    = false;
}

if (!variable_global_exists("run_seed")) {
    global.run_seed = irandom(99999) + 1;
}


// -----------------------------------------------------------------------------
// 2. RETURNING-FROM-COMBAT FLAG
// Set by Step_0 before room_goto(Room1). Cleared here so we only use it once.
// -----------------------------------------------------------------------------
returning_from_combat = variable_global_exists("just_cleared_room") && global.just_cleared_room;
if (returning_from_combat) global.just_cleared_room = false;

// Fresh run start: normalize the consumable pack to its carry cap, auto-
// depositing any excess (e.g. bought past the cap in the hub) into the stash.
// Mid-run re-entries skip this so pickups during the dive aren't disturbed.
if (!returning_from_combat) {
    if (variable_global_exists("consumable_overflow")) global.consumable_overflow = [];
    consumable_enforce_cap_to_stash();
}

// Apply dungeon passive effects on each room entry (not the very first room)
if (returning_from_combat) {
    var _dung_passive = variable_global_exists("selected_dungeon") ? global.selected_dungeon : "ashen_vault";
    var _asc_p = variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0;
    if (_dung_passive == "scorched_depths") {
        // Every room: apply 1 fire stack; 2 stacks at A1+
        if (!variable_global_exists("pending_fire_stacks")) global.pending_fire_stacks = 0;
        global.pending_fire_stacks += (_asc_p >= 1) ? 2 : 1;
    } else if (_dung_passive == "tundra_tomb") {
        // Every other room: -1 AP penalty; every room at A3+
        if (!variable_global_exists("pending_ap_penalty")) global.pending_ap_penalty = 0;
        var _floor_odd = (global.current_floor mod 2 == 1);
        if (_asc_p >= 3 || _floor_odd) global.pending_ap_penalty += 1;
    }
}


// -----------------------------------------------------------------------------
// 3. FLOOR MAP - generated once per floor, persisted in global.floor_map
// -----------------------------------------------------------------------------
var _need_new_map = !variable_global_exists("floor_map")
    || !variable_global_exists("floor_map_floor")
    || global.floor_map_floor != global.current_floor;

if (_need_new_map) {

    // ---- Procedurally generate a layered DAG (replaces the old 5 fixed templates).
    //      §6 variety pass: seeded by run_seed+floor so a given run is reproducible
    //      but every floor differs. Produces the same four arrays the rest of this
    //      event consumes (_node_count / _children / _layers / _slots), so all the
    //      downstream position/parent/map code is unchanged. Guarantees a valid DAG:
    //      every node is reachable from the entry AND every node has a path to the
    //      boss (no dead ends). Constrained to the existing draw geometry: entry and
    //      boss layers are single nodes, intermediate layers hold 1-3 nodes, and
    //      there are 5-6 layers total (so at most 6 columns / 3 rows). ----
    var _gen_old_seed = random_get_seed();
    random_set_seed(global.run_seed * 101 + global.current_floor * 17 + 3);

    // 5..6 layers (so 3-4 intermediate layers): keeps every floor from being too
    // short - after the "guarantee >=2 combat/elite" net there's always room left
    // for loot/event/rest. Width per layer (1-3) is the main shape-variety lever.
    var _num_layers = 5 + irandom(1);    // 5 or 6 layers (boss layer index 4..5)
    var _layer_nodes = [];               // _layer_nodes[l] = array of node ids in layer l
    var _layers      = [];
    var _slots       = [];
    var _node_count  = 0;

    for (var _gl = 0; _gl < _num_layers; _gl++) {
        var _cnt;
        if (_gl == 0 || _gl == _num_layers - 1) {
            _cnt = 1;                    // entry + boss are single nodes
        } else {
            // 1-3 nodes, weighted toward WIDER layers for more branching: roll
            // 0..5 -> 0:1node (1/6), 1-3:2nodes (3/6), 4-5:3nodes (2/6). Fewer
            // single-node "pinch" layers means more real forks per floor.
            var _r = irandom(5);
            _cnt = (_r == 0) ? 1 : ((_r >= 4) ? 3 : 2);
        }
        var _ids = [];
        for (var _gs = 0; _gs < _cnt; _gs++) {
            _layers[_node_count] = _gl;
            _slots[_node_count]  = _gs;
            array_push(_ids, _node_count);
            _node_count++;
        }
        array_push(_layer_nodes, _ids);
    }

    // Build edges: connect each layer to the next so the graph is a valid DAG.
    // Both _from and _to are stored TOP->BOTTOM (slot order == vertical order, see
    // py assignment below), so we can connect by vertical PROXIMITY instead of by
    // random index. This is the fix for "I took the top path but got forced into
    // the bottom room": edges now follow the drawn position, and the staircase
    // walk below guarantees no two connection lines ever cross (planar map).
    var _children = array_create(_node_count);
    for (var _ci = 0; _ci < _node_count; _ci++) _children[_ci] = [];

    for (var _gl = 0; _gl < _num_layers - 1; _gl++) {
        var _from = _layer_nodes[_gl];
        var _to   = _layer_nodes[_gl + 1];
        var _nf   = array_length(_from);
        var _nt   = array_length(_to);

        // Monotone "staircase" walk from the two tops to the two bottoms. At each
        // step we advance whichever side is further behind in vertical fraction and
        // connect the new pair. Because both indices only ever move DOWN, edges stay
        // sorted and never cross. Every source and every target is touched, so the
        // graph is fully connected with no dead ends - forks (out-degree 2) appear
        // naturally wherever the next layer is as wide or wider, merges where it's
        // narrower. (Replaces the old random-index fan-out + orphan-adoption pass.)
        var _a = 0;   // index into _from (top -> bottom)
        var _b = 0;   // index into _to
        array_push(_children[_from[0]], _to[0]);

        while (_a < _nf - 1 || _b < _nt - 1) {
            var _advance_source;
            if (_a >= _nf - 1) {
                _advance_source = false;        // source column exhausted -> step target
            } else if (_b >= _nt - 1) {
                _advance_source = true;         // target column exhausted -> step source
            } else {
                // Both can move: step the side whose NEXT node sits higher up (smaller
                // vertical fraction) so the connection stays diagonal/proximate. When
                // the two are level, coin-flip for shape variety (still monotone, so
                // still non-crossing).
                var _fa = (_a + 1) / (_nf - 1);
                var _fb = (_b + 1) / (_nt - 1);
                if (abs(_fa - _fb) < 0.001) _advance_source = (irandom(1) == 0);
                else                        _advance_source = (_fa < _fb);
            }
            if (_advance_source) _a++; else _b++;
            array_push(_children[_from[_a]], _to[_b]);
        }
    }

    random_set_seed(_gen_old_seed);   // restore RNG (the type block reseeds itself next)

    // Build parents from children (reverse edges)
    var _parents = [];
    for (var _i = 0; _i < _node_count; _i++) array_push(_parents, []);
    for (var _i = 0; _i < _node_count; _i++) {
        var _ch = _children[_i];
        for (var _j = 0; _j < array_length(_ch); _j++) {
            array_push(_parents[_ch[_j]], _i);
        }
    }

    // ---- Type + name assignment (seeded for reproducibility) ----
    var _old_seed = random_get_seed();
    random_set_seed(global.run_seed * 31 + global.current_floor * 7);

    // Non-boss non-entry type pools, weighted by floor
    var _type_pools = [
        // floor 1: 4 combat + variety of loot/rest + an event + a shrine (boon tribute)
        ["combat","combat","combat","combat","treasure","treasure_heal","treasure_vault","rest","event","shrine"],
        // floor 2: 3 combat + 2 elite + varied loot + event + shrine
        ["combat","combat","combat","elite","elite","treasure","treasure_heal","treasure_vault","rest","event","treasure_rare","shrine"],
        // floor 3: elite-heavy + rare loot + 2 events + shrine
        ["elite","elite","elite","elite","combat","combat","event","event","treasure","treasure_rare","rest","shrine"]
    ];
    var _pool_base = _type_pools[clamp(global.current_floor - 1, 0, 2)];

    // §6 type-mix polish: copy the base pool and inject 0-2 random bonus optional
    // rooms (floor-appropriate) so the decision/loot mix SHIFTS run-to-run, not just
    // the order. Seeded (we're inside the type-assignment seed block). The downstream
    // "guarantee >=2 combat/elite" safety net keeps every floor fight-bearing.
    var _pool = [];
    for (var _pbi = 0; _pbi < array_length(_pool_base); _pbi++) array_push(_pool, _pool_base[_pbi]);
    var _bonus_pools = [
        ["event", "treasure_heal", "rest",          "shrine"],   // floor 1 bonuses
        ["event", "treasure_vault", "treasure_rare", "shrine"],  // floor 2 bonuses
        ["event", "treasure_rare", "elite",          "shrine"]   // floor 3 bonuses
    ];
    var _bonus_list = _bonus_pools[clamp(global.current_floor - 1, 0, 2)];
    var _bonus_n    = irandom(2);   // 0, 1, or 2 extra optional rooms this floor
    for (var _bk = 0; _bk < _bonus_n; _bk++) {
        array_push(_pool, _bonus_list[irandom(array_length(_bonus_list) - 1)]);
    }

    // Shuffle pool so room sequence varies per run
    var _pool_copy = array_create(array_length(_pool));
    array_copy(_pool_copy, 0, _pool, 0, array_length(_pool));
    for (var _i = array_length(_pool_copy) - 1; _i > 0; _i--) {
        var _j = irandom(_i);
        var _tmp      = _pool_copy[_i];
        _pool_copy[_i] = _pool_copy[_j];
        _pool_copy[_j] = _tmp;
    }

    // Name pools per type
    var _nm_combat      = ["Dark Corridor", "Collapsed Hall", "Warden's Post", "Hollow Chamber", "Ash Pit", "Shattered Keep", "Cinder Pass"];
    var _nm_elite       = ["Bone Gallery", "Guardian Hall", "Elite Chamber", "The Killing Floor", "Death Row", "Iron Gauntlet", "Obsidian Vault"];
    var _nm_treasure    = ["Forgotten Cache", "Ancient Vault", "Warden's Hoard", "Hidden Alcove", "Dusty Coffer", "Sealed Crypt"];
    var _nm_treasure_h  = ["Supply Alcove", "Medic's Cache", "Healing Spring", "Herbalist's Stash", "Restoration Nook"];
    var _nm_treasure_v  = ["Hidden Armory", "Equipment Locker", "Adventurer's Cache", "Armory Alcove", "Gear Cache"];
    var _nm_treasure_r  = ["Ancient Reliquary", "Sanctum of Relics", "The Forgotten Vault", "Relic Chamber"];
    var _nm_rest        = ["Sheltered Nook", "Campfire Recess", "Quiet Alcove", "Safe Harbor", "Rubble Den", "Still Chamber"];
    var _nm_event       = ["Strange Alcove", "Whispering Hollow", "Forked Path", "Ill Omen", "Crossroads", "Eerie Chamber", "Veiled Threshold"];
    var _nm_boss_by_floor = [["Vault Chamber"], ["Throne of Ash"], ["The Final Seal"]];

    // Pre-pick names for all nodes (still inside seeded block)
    var _picked_names = array_create(_node_count, "");
    _picked_names[0] = _nm_combat[irandom(array_length(_nm_combat) - 1)];
    _picked_names[_node_count - 1] = _nm_boss_by_floor[clamp(global.current_floor - 1, 0, 2)][0];
    var _pool_cursor = 0;
    for (var _i = 1; _i < _node_count - 1; _i++) {
        var _t = _pool_copy[_pool_cursor mod array_length(_pool_copy)];
        _pool_cursor++;
        var _nm_pool = _nm_combat;
        switch (_t) {
            case "elite":          _nm_pool = _nm_elite;      break;
            case "treasure":       _nm_pool = _nm_treasure;   break;
            case "treasure_heal":  _nm_pool = _nm_treasure_h; break;
            case "treasure_vault": _nm_pool = _nm_treasure_v; break;
            case "treasure_rare":  _nm_pool = _nm_treasure_r; break;
            case "rest":           _nm_pool = _nm_rest;       break;
            case "event":          _nm_pool = _nm_event;      break;
            case "shrine":         _nm_pool = ["Shrine of Tribute","Forgotten Altar","Offering Stone"]; break;
        }
        _picked_names[_i] = _nm_pool[irandom(array_length(_nm_pool) - 1)];
    }

    random_set_seed(_old_seed); // restore RNG after generation

    // ---- Compute pixel positions ----
    var _max_layer = 0;
    for (var _i = 0; _i < _node_count; _i++) {
        if (_layers[_i] > _max_layer) _max_layer = _layers[_i];
    }

    // Graph draw area: x=30..1320 (w=1290), y=150..1020 (h=870)  [native 1080p x1.5]
    // Node width 195 (130x1.5) so the widest 6-column templates keep a real gutter
    // between columns instead of overlapping. Must match _NW in Draw_64.
    var _gx1 = 30;  var _gx2 = 1320;
    var _gy1 = 150; var _gy2 = 1020;
    var _node_w = 195; var _node_h = 96;
    var _mid_y  = (_gy1 + _gy2) * 0.5;   // 585
    var _y_spread = 165;                   // offset for 2-node layers

    // Count nodes per layer for y spread decision
    var _per_layer = array_create(_max_layer + 1, 0);
    for (var _i = 0; _i < _node_count; _i++) _per_layer[_layers[_i]]++;

    // Layer x centers spread evenly across the graph area
    var _layer_xs = [];
    for (var _l = 0; _l <= _max_layer; _l++) {
        var _t = (_max_layer > 0) ? (_l / _max_layer) : 0.5;
        array_push(_layer_xs, _gx1 + _node_w * 0.5 + _t * (_gx2 - _gx1 - _node_w));
    }

    // ---- Build the map ----
    var _map = [];
    var _pool_cursor2 = 0;
    for (var _i = 0; _i < _node_count; _i++) {
        var _type = "combat";
        if (_i == 0) {
            _type = "combat";
        } else if (_i == _node_count - 1) {
            _type = "boss";
        } else {
            _type = _pool_copy[_pool_cursor2 mod array_length(_pool_copy)];
            _pool_cursor2++;
        }

        var _enemies  = "standard";
        var _gold_min = 0;
        var _gold_max = 0;
        var _fl = clamp(global.current_floor - 1, 0, 2);
        switch (_type) {
            case "combat":   _enemies = "standard"; break;
            case "elite":    _enemies = "elite";    break;
            case "boss":     _enemies = "boss";     break;
            case "treasure":
                _enemies = "none";
                if (_fl == 0)      { _gold_min = 25; _gold_max = 55; }
                else if (_fl == 1) { _gold_min = 45; _gold_max = 85; }
                else               { _gold_min = 70; _gold_max = 130; }
                break;
            case "treasure_heal":
                _enemies = "none";
                if (_fl == 0)      { _gold_min = 5;  _gold_max = 20; }
                else if (_fl == 1) { _gold_min = 10; _gold_max = 30; }
                else               { _gold_min = 15; _gold_max = 40; }
                break;
            case "treasure_vault":
                _enemies = "none";
                if (_fl == 0)      { _gold_min = 15; _gold_max = 35; }
                else if (_fl == 1) { _gold_min = 25; _gold_max = 50; }
                else               { _gold_min = 40; _gold_max = 70; }
                break;
            case "treasure_rare":
                _enemies = "none";
                if (_fl == 0)      { _gold_min = 30; _gold_max = 55; }
                else if (_fl == 1) { _gold_min = 50; _gold_max = 80; }
                else               { _gold_min = 70; _gold_max = 120; }
                break;
            case "event":
                _enemies = "none";   // interactive choice room; self-contained rewards
                break;
            case "shrine":
                _enemies = "none";   // boon-tribute altar, no combat
                break;
        }

        // Y position: spread slots in multi-node layers (supports up to 3 nodes/layer)
        var _px = _layer_xs[_layers[_i]];
        var _py = _mid_y;
        var _lcount = _per_layer[_layers[_i]];
        if (_lcount == 2) {
            _py = (_slots[_i] == 0) ? _mid_y - _y_spread : _mid_y + _y_spread;
        } else if (_lcount >= 3) {
            if (_slots[_i] == 0)      _py = _mid_y - _y_spread;
            else if (_slots[_i] == 1) _py = _mid_y;
            else                      _py = _mid_y + _y_spread;
        }

        array_push(_map, {
            id:       _i,
            layer:    _layers[_i],
            slot:     _slots[_i],
            type:     _type,
            name:     _picked_names[_i],
            enemies:  _enemies,
            gold_min: _gold_min,
            gold_max: _gold_max,
            cleared:  false,
            parents:  _parents[_i],
            children: _children[_i],
            px:       _px,
            py:       _py
        });
    }

    // Guarantee at least 2 combat or elite rooms among intermediate nodes
    var _cmbt_cnt = 0;
    for (var _ci = 1; _ci < _node_count - 1; _ci++) {
        var _ctype = _map[_ci].type;
        if (_ctype == "combat" || _ctype == "elite") _cmbt_cnt++;
    }
    for (var _ci = 1; _ci < _node_count - 1 && _cmbt_cnt < 2; _ci++) {
        var _ctype = _map[_ci].type;
        if (_ctype != "combat" && _ctype != "elite") {
            _map[_ci].type    = "combat";
            _map[_ci].enemies = "standard";
            _map[_ci].gold_min = 0;
            _map[_ci].gold_max = 0;
            _map[_ci].name    = _nm_combat[irandom(array_length(_nm_combat) - 1)];
            _cmbt_cnt++;
        }
    }

    global.floor_map            = _map;
    global.floor_map_floor      = global.current_floor;
    global.floor_rooms_cleared  = array_create(_node_count, false);

} else {
    // Returning from a room transition - restore cleared state for just-completed room
    if (returning_from_combat
        && variable_global_exists("current_room_index")
        && global.current_room_index >= 0
        && global.current_room_index < array_length(global.floor_rooms_cleared)) {
        global.floor_rooms_cleared[global.current_room_index] = true;
        show_debug_message("[FLOOR DEBUG] cleared room " + string(global.current_room_index)
            + " on floor " + string(global.current_floor));
    }
}


// -----------------------------------------------------------------------------
// 4. REBUILD current_rooms FROM global.floor_map + cleared flags
// -----------------------------------------------------------------------------
current_rooms = [];
var _fmap = global.floor_map;
for (var _i = 0; _i < array_length(_fmap); _i++) {
    var _n = _fmap[_i];
    array_push(current_rooms, {
        id:       _n.id,
        layer:    _n.layer,
        slot:     _n.slot,
        type:     _n.type,
        name:     _n.name,
        enemies:  _n.enemies,
        gold_min: _n.gold_min,
        gold_max: _n.gold_max,
        cleared:  global.floor_rooms_cleared[_i],
        parents:  _n.parents,
        children: _n.children,
        px:       _n.px,
        py:       _n.py
    });
}

// Start the cursor on the first room you can actually enter (the frontier),
// so you don't have to navigate off the already-cleared entry node each time.
selected_room = 0;
for (var _i = 0; _i < array_length(current_rooms); _i++) {
    if (floor_room_enterable(current_rooms, _i)) { selected_room = _i; break; }
}


// -----------------------------------------------------------------------------
// 5. POPUP STATE - treasure/event overlay
// showing_treasure: standard gold+item popup
// showing_event:    rest / trap event popup
// -----------------------------------------------------------------------------
showing_treasure = false;
treasure_gold    = 0;
treasure_timer   = 0;
treasure_item    = undefined;

showing_event = false;
event_title   = "";
event_body    = "";
event_color   = c_white;
event_timer   = 0;

// Shrine - interactive altar overlay. Rolls per visit as a Blessing altar (boons,
// bought with tribute) or a Curse altar (curses, accepted for free - devil's bargain).
showing_shrine     = false;
shrine_kind        = "blessing";  // "blessing" = boons | "curse" = curses
shrine_offers      = [];   // array of boon ids OR curse ids offered this shrine
shrine_cursor      = 0;
shrine_notification = "";

// Event room - interactive stat-gated choice overlay (see SYSTEMS_EVENTS.md)
showing_event_choice = false;
event_active         = undefined;  // the rolled event struct
event_cursor         = 0;
event_phase          = "choose";   // "choose" | "result"
event_result_text    = "";


// -----------------------------------------------------------------------------
// 6. DUNGEON MUSIC
// -----------------------------------------------------------------------------
audio_apply_volumes();   // honor saved Music/SFX volumes
audio_play_sound(_2_dungeon_INITIAL, 1, false);
dungeon_music_looping = false;

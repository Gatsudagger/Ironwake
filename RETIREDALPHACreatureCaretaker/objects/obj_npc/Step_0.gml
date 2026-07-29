depth = -round(y);

near_player = instance_exists(obj_player) &&
    (point_distance(x, y, obj_player.x, obj_player.y) < interact_dist);

// Reset challenge state if player walks away
if (!near_player) challenge_state = 0;

// Dialog / battle challenge on E press
if (near_player && keyboard_check_pressed(ord("E"))) {
    if (challenge_state == 0) {
        // First press — show normal dialogue then issue challenge
        if (instance_exists(obj_task_ui)) {
            obj_task_ui.feedback_msg   = npc_name + ": \"I challenge you to a battle! Press E to accept.\"";
            obj_task_ui.feedback_timer = 300;
        }
        challenge_state = 1;
    } else if (challenge_state == 1) {
        // Second press — confirm and start combat
        challenge_state = 0;
        var _gc = obj_game_controller;
        if (is_struct(_gc.starter_creature)) {
            var _species = battle_species;
            var _enemy   = scr_creature_create(_species);
            _enemy.name  = npc_name + "'s " + _enemy.name;
            // Boost each base stat slightly above default
            _enemy.base_strength   = min(100, _enemy.base_strength   + irandom_range(5, 15));
            _enemy.base_agility    = min(100, _enemy.base_agility    + irandom_range(5, 15));
            _enemy.base_dexterity  = min(100, _enemy.base_dexterity  + irandom_range(5, 15));
            _enemy.base_stamina    = min(100, _enemy.base_stamina    + irandom_range(5, 15));
            _enemy.base_intellect  = min(100, _enemy.base_intellect  + irandom_range(5, 15));
            _enemy.base_willpower  = min(100, _enemy.base_willpower  + irandom_range(5, 15));
            _enemy.base_defense    = min(100, _enemy.base_defense    + irandom_range(5, 15));
            _enemy.base_vitality   = min(100, _enemy.base_vitality   + irandom_range(5, 15));
            scr_combat_init(_gc.starter_creature, _enemy, _gc.biome_id);
        }
    }
}

// Wander within patrol radius
patrol_timer++;
if (patrol_timer >= patrol_wait) {
    patrol_timer = 0;
    patrol_wait  = irandom_range(120, 300);

    if (move_dx == 0 && move_dy == 0) {
        var angle = irandom(359);
        var dist  = irandom_range(20, patrol_r);
        var tx    = patrol_cx + lengthdir_x(dist, angle);
        var ty    = patrol_cy + lengthdir_y(dist, angle);
        var ddx   = tx - x;
        var ddy   = ty - y;
        move_dx  = (abs(ddx) > 10) ? sign(ddx) : 0;
        move_dy  = (abs(ddy) > 10) ? sign(ddy) : 0;
        move_dur  = irandom_range(45, 130);
        move_timer = 0;
        if (move_dy < 0) facing = 1;
        else if (move_dy > 0) facing = 0;
        if (move_dx < 0) facing = 2;
        else if (move_dx > 0) facing = 3;
    } else {
        move_dx = 0;
        move_dy = 0;
    }
}

if (move_dx != 0 || move_dy != 0) {
    move_timer++;
    if (move_timer >= move_dur) {
        move_dx = 0;
        move_dy = 0;
    } else {
        x = clamp(x + move_dx * spd, patrol_cx - patrol_r * 1.2, patrol_cx + patrol_r * 1.2);
        y = clamp(y + move_dy * spd, patrol_cy - patrol_r * 1.2, patrol_cy + patrol_r * 1.2);
    }
}

moving = (move_dx != 0 || move_dy != 0);
if (moving) walk_t = (walk_t + 1) mod 30;

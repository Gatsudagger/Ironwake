depth = -round(y);

near_player = instance_exists(obj_player) &&
    (point_distance(x, y, obj_player.x, obj_player.y) < interact_dist);

// Dialog on E press
if (near_player && keyboard_check_pressed(ord("E"))) {
    if (instance_exists(obj_task_ui)) {
        obj_task_ui.feedback_msg   = npc_name + ": \"" + dialog + "\"";
        obj_task_ui.feedback_timer = 300;
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

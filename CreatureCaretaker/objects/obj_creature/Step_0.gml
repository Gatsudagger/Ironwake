idle_bob_t = (idle_bob_t + 1) mod 360;

wander_timer--;
if (wander_timer <= 0) {
	wander_timer = irandom_range(90, 250);
	var dist  = irandom_range(0, 90);
	var angle = random(360);
	if (dist < 20) {
		target_x = home_x;
		target_y = home_y;
	} else {
		target_x = clamp(home_x + lengthdir_x(dist, angle), home_x - 100, home_x + 100);
		target_y = clamp(home_y + lengthdir_y(dist, angle), home_y - 100, home_y + 100);
	}
}

var dx = target_x - x;
var dy = target_y - y;
var d  = sqrt(dx * dx + dy * dy);
if (d > 2) {
	x += (dx / d) * move_spd;
	y += (dy / d) * move_spd;
}

depth = -round(y);

var _ci = obj_game_controller.starter_creature;
var _cd = global.creature_data[_ci];
if (d > 2) {
	var _dir = WALK_DOWN;
	if (abs(dx) >= abs(dy)) {
		_dir = (dx > 0) ? WALK_RIGHT : WALK_LEFT;
	} else {
		_dir = (dy > 0) ? WALK_DOWN : WALK_UP;
	}
	sprite_index = _cd.walk_sprites[_dir];
	image_speed  = 1;
} else {
	image_speed = 0;
	image_index = 0;
}

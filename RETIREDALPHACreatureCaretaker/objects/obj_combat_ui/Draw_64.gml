if (!instance_exists(obj_combat_player) || !instance_exists(obj_combat_enemy)) exit;
if (instance_exists(obj_combat_manager) && obj_combat_manager.result_pending) exit;

var _p = obj_combat_player;
var _e = obj_combat_enemy;

draw_set_font(-1);

// ── Player panel (top-left) — VIT + stamina bars ────────────────────────────
scr_draw_panel(8, 8, 220, 62);
draw_set_halign(fa_left);
draw_set_colour(c_white);
draw_text(16, 12, _p.creature.name);

var _p_ratio = max(0, _p.vitality / _p.vitality_max);
draw_set_colour(c_dkgray);
draw_rectangle(16, 28, 220, 44, false);
draw_set_colour(make_colour_rgb(80, 200, 80));
draw_rectangle(16, 28, 16 + round(204 * _p_ratio), 44, false);
draw_set_colour(c_white);
draw_text(16, 28, "VIT " + string(_p.vitality) + "/" + string(_p.vitality_max));

var _ps_ratio = max(0, _p.combat_stamina / _p.combat_stamina_max);
draw_set_colour(c_dkgray);
draw_rectangle(16, 46, 220, 56, false);
draw_set_colour(make_colour_rgb(60, 120, 220));
draw_rectangle(16, 46, 16 + round(204 * _ps_ratio), 56, false);

// ── Enemy panel (top-right) — VIT bar only ──────────────────────────────────
scr_draw_panel(572, 8, 220, 52);
var _e_ratio = max(0, _e.vitality / _e.vitality_max);
draw_set_halign(fa_right);
draw_set_colour(c_white);
draw_text(784, 12, _e.creature.name);
draw_set_colour(c_dkgray);
draw_rectangle(572, 28, 784, 44, false);
draw_set_colour(make_colour_rgb(200, 80, 80));
draw_rectangle(572, 28, 572 + round(212 * _e_ratio), 44, false);
draw_set_colour(c_white);
draw_set_halign(fa_left);
draw_text(580, 28, "VIT " + string(_e.vitality) + "/" + string(_e.vitality_max));

// ── Move hotbar (bottom-left, stacked vertically) ──────────────────────────
var _moves  = scr_combat_get_moves(_p.species);
var _gui_w  = display_get_gui_width();
var _gui_h  = display_get_gui_height();
var _bw     = 180;
var _bh     = 36;
var _gap    = 6;
var _bx     = 10;
var _by     = _gui_h - (_bh * 3) - (_gap * 2) - 10;

// Dark backing panel
draw_set_colour(make_colour_rgb(10, 10, 25));
draw_set_alpha(0.85);
draw_rectangle(_bx - 4, _by - 4, _bx + _bw + 4, _by + (_bh * 3) + (_gap * 2) + 4, false);
draw_set_alpha(1);

for (var _i = 0; _i < 3; _i++) {
	var _mv      = _moves[_i];
	var _on_cd   = (_p.cooldown[_i] > 0);
	var _cost    = scr_get_move_stamina_cost(_mv);
	var _can_use = (_p.combat_stamina >= _cost);
	var _lbl     = string(_i + 1) + ". " + _mv.name;
	if (_on_cd) _lbl = _mv.name + " (" + string(ceil(_p.cooldown[_i] / 60)) + "s)";
	scr_draw_pixel_button(_bx, _by, _bw, _bh, _lbl, false, 0.85);
	if (_on_cd || !_can_use) {
		draw_set_alpha(_on_cd ? 0.45 : 0.3);
		draw_set_colour(c_black);
		draw_rectangle(_bx, _by, _bx + _bw, _by + _bh, false);
		draw_set_alpha(1);
	}
	_by += _bh + _gap;
}

// ── Item hotbar (bottom-right, stacked vertically) ─────────────────────────
var _ibw  = 140;
var _ibh  = 36;
var _igap = 6;
var _ibx  = display_get_gui_width()  - _ibw - 10;
var _iby  = display_get_gui_height() - (_ibh * 3) - (_igap * 2) - 10;

// Dark backing panel
draw_set_colour(make_colour_rgb(10, 10, 25));
draw_set_alpha(0.85);
draw_rectangle(_ibx - 4, _iby - 4, _ibx + _ibw + 4, _iby + (_ibh * 3) + (_igap * 2) + 4, false);
draw_set_alpha(1);

var _tier_cols = [make_colour_rgb(180, 180, 180), make_colour_rgb(80, 200, 80), make_colour_rgb(255, 215, 0)];

for (var _i = 0; _i < 3; _i++) {
	var _islot = global.hotbar_items[_i];
	var _lbl   = string(4 + _i) + ". Empty";
	var _tcol  = c_dkgray;
	var _has   = false;

	if (_islot >= 0 && _islot < array_length(global.inventory)) {
		var _entry = global.inventory[_islot];
		var _idata = global.item_data[_entry.item_id];
		_lbl  = string(4 + _i) + ". " + _idata.name + " x" + string(_entry.quantity);
		_tcol = _tier_cols[_idata.tier];
		_has  = true;
	}

	scr_draw_pixel_button(_ibx, _iby, _ibw, _ibh, _lbl, false, 0.85);

	if (_has) {
		draw_set_colour(_tcol);
		draw_set_alpha(0.85);
		draw_rectangle(_ibx, _iby, _ibx + 4, _iby + _ibh, false);
		draw_set_alpha(1);
	} else {
		draw_set_alpha(0.4);
		draw_set_colour(c_black);
		draw_rectangle(_ibx, _iby, _ibx + _ibw, _iby + _ibh, false);
		draw_set_alpha(1);
	}

	_iby += _ibh + _igap;
}

draw_set_halign(fa_left);
draw_set_colour(c_white);

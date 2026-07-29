/// @desc Draws a rich biome-specific combat arena background filling (0, 0, w, h).
function scr_draw_combat_background(biome_id, w, h) {
	var _sky_h = floor(h * 0.30);  // atmosphere band
	var _gnd_y = floor(h * 0.58);  // ground horizon
	var _fg_y  = floor(h * 0.86);  // foreground strip

	switch (biome_id) {
		case BIOME.ALPINE_FOREST:   __ca_alpine(w, h, _sky_h, _gnd_y, _fg_y);    break;
		case BIOME.TEMPERATE_FOREST: __ca_temperate(w, h, _sky_h, _gnd_y, _fg_y); break;
		case BIOME.JUNGLE:          __ca_jungle(w, h, _sky_h, _gnd_y, _fg_y);    break;
		case BIOME.OASIS:           __ca_oasis(w, h, _sky_h, _gnd_y, _fg_y);     break;
		case BIOME.MOUNTAIN_VALLEY: __ca_mountain(w, h, _sky_h, _gnd_y, _fg_y);  break;
		default:
			draw_set_colour(make_colour_rgb(20, 20, 40));
			draw_rectangle(0, 0, w, h, false);
	}
	draw_set_alpha(1);
	draw_set_colour(c_white);
}

function __ca_alpine(w, h, sky_h, gnd_y, fg_y) {
	// Sky: dark navy → blue-grey
	draw_rectangle_colour(0, 0, w, sky_h,
		make_colour_rgb(8, 14, 36), make_colour_rgb(8, 14, 36),
		make_colour_rgb(30, 50, 90), make_colour_rgb(30, 50, 90), false);

	// Stars
	draw_set_colour(make_colour_rgb(200, 215, 255));
	var _sfx = [0.08, 0.22, 0.38, 0.55, 0.71, 0.85];
	var _sfy = [0.06, 0.14, 0.05, 0.18, 0.09, 0.16];
	for (var _i = 0; _i < 6; _i++) {
		var _sr = w * 0.003;
		draw_ellipse(w * _sfx[_i] - _sr, sky_h * _sfy[_i] - _sr,
		             w * _sfx[_i] + _sr, sky_h * _sfy[_i] + _sr, false);
	}

	// Mid-zone: snow field behind pines (sky_h to gnd_y)
	draw_set_colour(make_colour_rgb(140, 165, 190));
	draw_rectangle(0, sky_h, w, gnd_y, false);

	// Background mountain range
	draw_set_colour(make_colour_rgb(28, 36, 60));
	draw_triangle(0,         gnd_y, w * 0.30, gnd_y, w * 0.14, sky_h + h * 0.06, false);
	draw_triangle(w * 0.18,  gnd_y, w * 0.52, gnd_y, w * 0.36, sky_h + h * 0.02, false);
	draw_triangle(w * 0.44,  gnd_y, w * 0.78, gnd_y, w * 0.62, sky_h + h * 0.04, false);
	draw_triangle(w * 0.68,  gnd_y, w,         gnd_y, w * 0.84, sky_h + h * 0.07, false);

	// Snow caps
	draw_set_colour(make_colour_rgb(230, 240, 255));
	draw_triangle(w * 0.10, sky_h + h * 0.10, w * 0.18, sky_h + h * 0.10, w * 0.14, sky_h + h * 0.06, false);
	draw_triangle(w * 0.32, sky_h + h * 0.06, w * 0.40, sky_h + h * 0.06, w * 0.36, sky_h + h * 0.02, false);
	draw_triangle(w * 0.58, sky_h + h * 0.08, w * 0.66, sky_h + h * 0.08, w * 0.62, sky_h + h * 0.04, false);

	// Pine silhouettes on both sides of the arena
	draw_set_colour(make_colour_rgb(12, 18, 30));
	__biome_pine(w * 0.06,  gnd_y - h * 0.24, gnd_y, w * 0.052);
	__biome_pine(w * 0.16,  gnd_y - h * 0.20, gnd_y, w * 0.044);
	__biome_pine(w * 0.84,  gnd_y - h * 0.22, gnd_y, w * 0.048);
	__biome_pine(w * 0.94,  gnd_y - h * 0.18, gnd_y, w * 0.042);

	// Ground: snow plane, lighter at horizon, slightly darker near player
	draw_rectangle_colour(0, gnd_y, w, fg_y,
		make_colour_rgb(195, 210, 225), make_colour_rgb(195, 210, 225),
		make_colour_rgb(170, 188, 205), make_colour_rgb(170, 188, 205), false);

	// Foreground snow strip
	draw_set_colour(make_colour_rgb(215, 228, 240));
	draw_rectangle(0, fg_y, w, h, false);
	// Snow shadow edge
	draw_set_colour(make_colour_rgb(155, 175, 195));
	draw_rectangle(0, fg_y, w, fg_y + 4, false);
}

function __ca_temperate(w, h, sky_h, gnd_y, fg_y) {
	// Sky: warm golden top → soft blue-white at horizon
	draw_rectangle_colour(0, 0, w, sky_h,
		make_colour_rgb(108, 168, 228), make_colour_rgb(108, 168, 228),
		make_colour_rgb(178, 210, 238), make_colour_rgb(178, 210, 238), false);

	// Mid-zone: lighter green rolling hills behind arena
	draw_set_colour(make_colour_rgb(55, 115, 55));
	draw_rectangle(0, sky_h, w, gnd_y, false);
	// Rolling hills
	draw_set_colour(make_colour_rgb(40, 100, 40));
	draw_ellipse(-w * 0.05, sky_h + h * 0.04, w * 0.42, gnd_y + h * 0.06, false);
	draw_set_colour(make_colour_rgb(45, 108, 45));
	draw_ellipse(w * 0.35,  sky_h + h * 0.06, w * 1.05, gnd_y + h * 0.06, false);

	// Trees on left and right sides
	var _tree_xs = [w * 0.04, w * 0.14, w * 0.86, w * 0.96];
	var _tree_cr = [w * 0.065, w * 0.055, w * 0.060, w * 0.050];
	for (var _i = 0; _i < 4; _i++) {
		var _tx = _tree_xs[_i];
		var _ty = gnd_y;
		var _cr = _tree_cr[_i];
		// Trunk
		draw_set_colour(make_colour_rgb(75, 48, 18));
		draw_rectangle(_tx - 4, _ty, _tx + 4, _ty + h * 0.08, false);
		// Canopy shadow
		draw_set_colour(make_colour_rgb(30, 90, 30));
		draw_ellipse(_tx - _cr, _ty - _cr * 1.1, _tx + _cr, _ty + _cr * 0.3, false);
		// Canopy highlight
		draw_set_colour(make_colour_rgb(58, 140, 50));
		draw_ellipse(_tx - _cr * 0.5, _ty - _cr * 0.9, _tx + _cr * 0.3, _ty - _cr * 0.1, false);
	}

	// Ground: green grass with perspective fade
	draw_rectangle_colour(0, gnd_y, w, fg_y,
		make_colour_rgb(60, 130, 50), make_colour_rgb(60, 130, 50),
		make_colour_rgb(45, 108, 38), make_colour_rgb(45, 108, 38), false);

	// Foreground grass strip + small flowers
	draw_set_colour(make_colour_rgb(72, 148, 58));
	draw_rectangle(0, fg_y, w, h, false);
	draw_set_colour(make_colour_rgb(62, 138, 48));
	draw_rectangle(0, fg_y, w, fg_y + 4, false);
	// Flowers
	var _fcols = [make_colour_rgb(255, 235, 55), make_colour_rgb(255, 255, 255), make_colour_rgb(255, 140, 180)];
	var _fxs   = [0.08, 0.20, 0.34, 0.48, 0.60, 0.74, 0.87];
	for (var _i = 0; _i < 7; _i++) {
		draw_set_colour(_fcols[_i mod 3]);
		var _fr = w * 0.005;
		var _fy = fg_y + h * (0.025 + (_i mod 3) * 0.012);
		draw_ellipse(w * _fxs[_i] - _fr, _fy - _fr, w * _fxs[_i] + _fr, _fy + _fr, false);
	}
}

function __ca_jungle(w, h, sky_h, gnd_y, fg_y) {
	// Full background: near-black dark green
	draw_rectangle_colour(0, 0, w, h,
		make_colour_rgb(5, 14, 6), make_colour_rgb(5, 14, 6),
		make_colour_rgb(14, 40, 16), make_colour_rgb(14, 40, 16), false);

	// Dense upper canopy draping down from top
	draw_set_colour(make_colour_rgb(14, 46, 16));
	draw_ellipse(-w * 0.10, -h * 0.05, w * 0.48,  sky_h + h * 0.18, false);
	draw_ellipse(w * 0.22,  -h * 0.05, w * 0.78,  sky_h + h * 0.14, false);
	draw_ellipse(w * 0.52,  -h * 0.05, w * 1.10,  sky_h + h * 0.16, false);
	draw_set_colour(make_colour_rgb(20, 62, 22));
	draw_ellipse(-h * 0.05, -h * 0.05, w * 0.40,  sky_h + h * 0.28, false);
	draw_ellipse(w * 0.60,  -h * 0.05, w * 1.05,  sky_h + h * 0.26, false);

	// Light shafts through canopy
	draw_set_alpha(0.06);
	draw_set_colour(make_colour_rgb(180, 255, 120));
	draw_triangle(w * 0.30, 0, w * 0.38, 0, w * 0.22, gnd_y, false);
	draw_triangle(w * 0.58, 0, w * 0.66, 0, w * 0.68, gnd_y, false);
	draw_set_alpha(1);

	// Vines hanging from sides
	draw_set_colour(make_colour_rgb(20, 58, 22));
	var _vxs = [w * 0.04, w * 0.12, w * 0.88, w * 0.96];
	for (var _i = 0; _i < 4; _i++) {
		draw_line_width(_vxs[_i], 0, _vxs[_i] + (_i < 2 ? 4 : -4), gnd_y * 0.80, 3);
	}

	// Ground: dark damp earth
	draw_rectangle_colour(0, gnd_y, w, fg_y,
		make_colour_rgb(18, 52, 20), make_colour_rgb(18, 52, 20),
		make_colour_rgb(12, 38, 14), make_colour_rgb(12, 38, 14), false);

	// Mid-level foliage on sides
	draw_set_colour(make_colour_rgb(16, 52, 18));
	draw_ellipse(-w * 0.06, gnd_y - h * 0.15, w * 0.22, gnd_y + h * 0.08, false);
	draw_ellipse(w * 0.78,  gnd_y - h * 0.14, w * 1.06, gnd_y + h * 0.08, false);

	// Foreground undergrowth
	draw_set_colour(make_colour_rgb(10, 36, 12));
	draw_rectangle(0, fg_y, w, h, false);
	draw_set_colour(make_colour_rgb(16, 48, 18));
	draw_ellipse(-w * 0.05, fg_y - h * 0.04, w * 0.32, h * 1.04, false);
	draw_ellipse(w * 0.68,  fg_y - h * 0.04, w * 1.05, h * 1.04, false);
}

function __ca_oasis(w, h, sky_h, gnd_y, fg_y) {
	// Sky: warm amber sunset gradient
	draw_rectangle_colour(0, 0, w, sky_h,
		make_colour_rgb(198, 92, 28), make_colour_rgb(198, 92, 28),
		make_colour_rgb(238, 172, 70), make_colour_rgb(238, 172, 70), false);

	// Sun disc
	draw_set_alpha(0.75);
	draw_set_colour(make_colour_rgb(255, 215, 80));
	draw_ellipse(w * 0.78, h * 0.02, w * 0.90, h * 0.10, false);
	draw_set_alpha(0.20);
	draw_ellipse(w * 0.75, -h * 0.01, w * 0.93, h * 0.13, false);
	draw_set_alpha(1);

	// Mid-zone: distant sand dunes
	draw_set_colour(make_colour_rgb(185, 152, 78));
	draw_rectangle(0, sky_h, w, gnd_y, false);
	draw_set_colour(make_colour_rgb(168, 136, 65));
	draw_ellipse(-w * 0.05, sky_h + h * 0.05, w * 0.45, gnd_y + h * 0.04, false);
	draw_ellipse(w * 0.38,  sky_h + h * 0.04, w * 1.05, gnd_y + h * 0.04, false);

	// Palm trees framing left and right
	var _px   = [w * 0.06, w * 0.94];
	var _plean = [1, -1];
	for (var _i = 0; _i < 2; _i++) {
		var _cx  = _px[_i];
		var _tby = gnd_y + h * 0.02;
		var _ttx = _cx + _plean[_i] * w * 0.04;
		var _tty = gnd_y - h * 0.22;
		// Trunk
		draw_set_colour(make_colour_rgb(130, 90, 40));
		draw_line_width(_cx, _tby, _ttx, _tty, 5);
		// Fronds
		draw_set_colour(make_colour_rgb(58, 138, 48));
		var _fang = [-70, -40, -10, 20, 50, -100];
		for (var _j = 0; _j < 6; _j++) {
			var _a   = degtorad(_fang[_j] + (_i == 1 ? 180 : 0));
			var _len = w * 0.13;
			draw_line_width(_ttx, _tty, _ttx + cos(_a) * _len, _tty + sin(_a) * _len, 2);
		}
	}

	// Ground: sand with perspective
	draw_rectangle_colour(0, gnd_y, w, fg_y,
		make_colour_rgb(210, 178, 95), make_colour_rgb(210, 178, 95),
		make_colour_rgb(190, 158, 78), make_colour_rgb(190, 158, 78), false);

	// Oasis pool in center ground
	draw_set_colour(make_colour_rgb(52, 168, 192));
	draw_ellipse(w * 0.36, gnd_y + h * 0.03, w * 0.64, gnd_y + h * 0.12, false);
	draw_set_colour(make_colour_rgb(90, 205, 222));
	draw_ellipse(w * 0.42, gnd_y + h * 0.04, w * 0.56, gnd_y + h * 0.08, false);

	// Foreground sandy strip
	draw_set_colour(make_colour_rgb(218, 188, 105));
	draw_rectangle(0, fg_y, w, h, false);
	draw_set_colour(make_colour_rgb(198, 168, 85));
	draw_rectangle(0, fg_y, w, fg_y + 4, false);
}

function __ca_mountain(w, h, sky_h, gnd_y, fg_y) {
	// Sky: deep purple-indigo night
	draw_rectangle_colour(0, 0, w, sky_h,
		make_colour_rgb(10, 6, 28), make_colour_rgb(10, 6, 28),
		make_colour_rgb(28, 18, 58), make_colour_rgb(28, 18, 58), false);

	// Stars
	draw_set_colour(make_colour_rgb(220, 225, 255));
	var _sfx = [0.06, 0.15, 0.26, 0.40, 0.54, 0.66, 0.78, 0.88, 0.95, 0.32, 0.72];
	var _sfy = [0.08, 0.22, 0.10, 0.30, 0.12, 0.26, 0.08, 0.20, 0.32, 0.48, 0.44];
	for (var _i = 0; _i < 11; _i++) {
		var _sr = w * 0.003;
		draw_ellipse(w * _sfx[_i] - _sr, sky_h * _sfy[_i] - _sr,
		             w * _sfx[_i] + _sr, sky_h * _sfy[_i] + _sr, false);
	}
	// Moon
	draw_set_alpha(0.88);
	draw_set_colour(make_colour_rgb(240, 238, 210));
	draw_ellipse(w * 0.82, h * 0.02, w * 0.90, h * 0.08, false);
	draw_set_alpha(1);

	// Mid-zone: rocky valley walls (sky_h to gnd_y)
	draw_set_colour(make_colour_rgb(30, 24, 52));
	draw_rectangle(0, sky_h, w, gnd_y, false);

	// Background mountain peaks
	draw_set_colour(make_colour_rgb(20, 15, 42));
	draw_triangle(0,        gnd_y, w * 0.28, gnd_y, w * 0.12, sky_h + h * 0.02, false);
	draw_triangle(w * 0.16, gnd_y, w * 0.50, gnd_y, w * 0.34, sky_h - h * 0.01, false);
	draw_triangle(w * 0.42, gnd_y, w * 0.72, gnd_y, w * 0.58, sky_h + h * 0.03, false);
	draw_triangle(w * 0.62, gnd_y, w * 0.90, gnd_y, w * 0.76, sky_h + h * 0.01, false);
	draw_triangle(w * 0.78, gnd_y, w,         gnd_y, w * 0.90, sky_h + h * 0.04, false);

	// Mid peaks (lighter, in front)
	draw_set_colour(make_colour_rgb(42, 34, 68));
	draw_triangle(0,        gnd_y, w * 0.22, gnd_y, w * 0.10, sky_h + h * 0.10, false);
	draw_triangle(w * 0.72, gnd_y, w,         gnd_y, w * 0.86, sky_h + h * 0.08, false);

	// Ground: dark rock
	draw_rectangle_colour(0, gnd_y, w, fg_y,
		make_colour_rgb(40, 32, 60), make_colour_rgb(40, 32, 60),
		make_colour_rgb(30, 24, 48), make_colour_rgb(30, 24, 48), false);

	// Rock formations at sides
	draw_set_colour(make_colour_rgb(52, 44, 72));
	draw_triangle(0,        gnd_y + h * 0.08, w * 0.12, gnd_y + h * 0.08, w * 0.06, gnd_y - h * 0.04, false);
	draw_triangle(w * 0.88, gnd_y + h * 0.08, w,         gnd_y + h * 0.08, w * 0.94, gnd_y - h * 0.04, false);

	// Foreground rocky strip
	draw_set_colour(make_colour_rgb(55, 46, 74));
	draw_rectangle(0, fg_y, w, h, false);
	// Rock bumps on foreground
	draw_set_colour(make_colour_rgb(65, 56, 84));
	draw_ellipse(-w * 0.02, fg_y - h * 0.02, w * 0.22, fg_y + h * 0.05, false);
	draw_ellipse(w * 0.78,  fg_y - h * 0.02, w * 1.02, fg_y + h * 0.05, false);
	draw_set_colour(make_colour_rgb(48, 40, 66));
	draw_rectangle(0, fg_y, w, fg_y + 4, false);
}

/// @desc Draws a procedural biome scene inside rectangle (x, y, w, h).
/// biome_id is a BIOME enum value (0–4). Uses current_time for animation.
function scr_draw_biome_background(biome_id, x, y, w, h) {
	var _t = current_time * 0.001; // seconds since game start
	switch (biome_id) {
		case BIOME.ALPINE_FOREST:    __biome_alpine(x, y, w, h, _t);    break;
		case BIOME.TEMPERATE_FOREST: __biome_temperate(x, y, w, h, _t); break;
		case BIOME.JUNGLE:           __biome_jungle(x, y, w, h, _t);    break;
		case BIOME.OASIS:            __biome_oasis(x, y, w, h, _t);     break;
		case BIOME.MOUNTAIN_VALLEY:  __biome_mountain(x, y, w, h, _t);  break;
		default:
			draw_set_colour(make_colour_rgb(20, 20, 40));
			draw_rectangle(x, y, x + w, y + h, false);
	}
}

// ── Private: three-tier layered pine silhouette ────────────────────────────────
function __biome_pine(cx, peak_y, base_y, hw) {
	var _mid_y = lerp(peak_y, base_y, 0.45);
	var _low_y = lerp(peak_y, base_y, 0.72);
	draw_triangle(cx - hw * 0.38, _mid_y,  cx + hw * 0.38, _mid_y,  cx, peak_y, false);
	draw_triangle(cx - hw * 0.65, _low_y,  cx + hw * 0.65, _low_y,  cx, lerp(peak_y, base_y, 0.22), false);
	draw_triangle(cx - hw,        base_y,  cx + hw,        base_y,  cx, lerp(peak_y, base_y, 0.45), false);
}

// ── Alpine Forest ──────────────────────────────────────────────────────────────
function __biome_alpine(x, y, w, h, _t) {
	var _snow_y = y + h * 0.90;

	// Sky: dark navy → slate blue, full card height
	draw_rectangle_colour(x, y, x + w, y + h,
		make_colour_rgb(10, 18, 38), make_colour_rgb(10, 18, 38),
		make_colour_rgb(40, 62, 95), make_colour_rgb(40, 62, 95), false);

	// Pine silhouettes — bases sit ON the snow line
	draw_set_colour(make_colour_rgb(14, 22, 34));
	__biome_pine(x + w * 0.14, y + h * 0.38, _snow_y, w * 0.10);
	__biome_pine(x + w * 0.32, y + h * 0.30, _snow_y, w * 0.09);
	__biome_pine(x + w * 0.58, y + h * 0.35, _snow_y, w * 0.11);
	__biome_pine(x + w * 0.80, y + h * 0.32, _snow_y, w * 0.09);

	// Snow particles
	draw_set_colour(make_colour_rgb(225, 238, 252));
	for (var _i = 0; _i < 14; _i++) {
		var _sx = clamp(x + ((_i * 61) mod w) + sin(_t * 0.55 + _i * 1.13) * 5, x, x + w - 2);
		var _sy = y + frac(_t * 0.055 + _i / 14.0) * (h * 0.80);
		draw_rectangle(_sx, _sy, _sx + 2, _sy + 2, false);
	}
}

// ── Temperate Forest ───────────────────────────────────────────────────────────
function __biome_temperate(x, y, w, h, _t) {
	var _gnd_y = y + h * 0.65;

	// Sky: warm golden top → soft blue bottom
	draw_rectangle_colour(x, y, x + w, _gnd_y,
		make_colour_rgb(215, 195, 140), make_colour_rgb(215, 195, 140),
		make_colour_rgb(102, 158, 215), make_colour_rgb(102, 158, 215), false);

	// Rolling hills — back to front, clamped to card bounds
	draw_set_colour(make_colour_rgb(38, 88, 38));
	draw_ellipse(x,            y + h * 0.52, x + w * 0.55, y + h, false);

	draw_set_colour(make_colour_rgb(54, 118, 54));
	draw_ellipse(x + w * 0.30, y + h * 0.56, x + w,        y + h, false);

	draw_set_colour(make_colour_rgb(72, 142, 58));
	draw_rectangle(x, y + h * 0.72, x + w, y + h, false);

	// Round-canopy trees — canopy and trunk clamped within card
	draw_set_colour(make_colour_rgb(80, 52, 22));
	var _tree_xs = [x + w * 0.18, x + w * 0.50, x + w * 0.78];
	for (var _i = 0; _i < 3; _i++) {
		var _tx = _tree_xs[_i];
		var _ty = y + h * 0.58;  // lowered so canopy top stays inside card
		var _cr = w * 0.055;     // reduced from 0.075 to prevent bleed
		// Trunk
		draw_rectangle(_tx - 3, _ty + _cr * 0.5, _tx + 3, min(_ty + _cr * 1.6, y + h), false);
		// Canopy shadow
		draw_set_colour(make_colour_rgb(38, 100, 36));
		draw_ellipse(_tx - _cr, _ty - _cr, _tx + _cr, _ty + _cr, false);
		// Canopy highlight
		draw_set_colour(make_colour_rgb(68, 148, 58));
		draw_ellipse(_tx - _cr * 0.55, _ty - _cr * 0.80, _tx + _cr * 0.35, _ty + _cr * 0.05, false);
		// Reset for next trunk
		draw_set_colour(make_colour_rgb(80, 52, 22));
	}
}

// ── Jungle ─────────────────────────────────────────────────────────────────────
function __biome_jungle(x, y, w, h, _t) {
	// Sky: near-black dark green
	draw_rectangle_colour(x, y, x + w, y + h,
		make_colour_rgb(6,  18, 8),  make_colour_rgb(6,  18, 8),
		make_colour_rgb(14, 42, 18), make_colour_rgb(14, 42, 18), false);

	// Upper canopy — all ellipses clamped to card bounds, ~40% smaller than before
	draw_set_colour(make_colour_rgb(18, 55, 22));
	draw_ellipse(x,            y,            x + w * 0.52, y + h * 0.36, false);
	draw_ellipse(x + w * 0.24, y,            x + w * 0.74, y + h * 0.34, false);
	draw_ellipse(x + w * 0.48, y,            x + w,        y + h * 0.32, false);
	draw_set_colour(make_colour_rgb(24, 72, 28));
	draw_ellipse(x + w * 0.06, y + h * 0.08, x + w * 0.58, y + h * 0.42, false);
	draw_ellipse(x + w * 0.44, y + h * 0.06, x + w * 0.96, y + h * 0.40, false);

	// Mid-layer foliage — within card bounds
	draw_set_colour(make_colour_rgb(28, 85, 34));
	draw_ellipse(x,            y + h * 0.35, x + w * 0.54, y + h * 0.64, false);
	draw_ellipse(x + w * 0.46, y + h * 0.32, x + w,        y + h * 0.62, false);

	// Undergrowth
	draw_set_colour(make_colour_rgb(22, 68, 26));
	draw_rectangle(x, y + h * 0.72, x + w, y + h, false);
	draw_set_colour(make_colour_rgb(30, 88, 35));
	draw_ellipse(x,            y + h * 0.66, x + w * 0.52, y + h * 0.90, false);
	draw_ellipse(x + w * 0.48, y + h * 0.68, x + w,        y + h * 0.90, false);

	// Hanging vines — gentle sway, swing clamped to stay inside card
	draw_set_colour(make_colour_rgb(22, 65, 26));
	var _vine_xs = [x + w * 0.22, x + w * 0.42, x + w * 0.63, x + w * 0.82];
	for (var _i = 0; _i < 4; _i++) {
		var _vx    = _vine_xs[_i];
		var _swing = sin(_t * 0.4 + _i * 1.7) * 2;
		draw_line_width(_vx + _swing, y + h * 0.10, _vx, y + h * 0.72, 2);
	}
}

// ── Oasis ──────────────────────────────────────────────────────────────────────
function __biome_oasis(x, y, w, h, _t) {
	var _sand_y = y + h * 0.68;

	// Sky: amber → warm gold gradient
	draw_rectangle_colour(x, y, x + w, _sand_y,
		make_colour_rgb(195, 110, 45), make_colour_rgb(195, 110, 45),
		make_colour_rgb(240, 188, 78), make_colour_rgb(240, 188, 78), false);

	// Sand
	draw_set_colour(make_colour_rgb(210, 180, 100));
	draw_rectangle(x, _sand_y, x + w, y + h, false);
	draw_set_colour(make_colour_rgb(228, 200, 120));
	draw_rectangle(x, _sand_y, x + w, _sand_y + 4, false);

	// Oasis pool
	draw_set_colour(make_colour_rgb(55, 175, 195));
	draw_ellipse(x + w * 0.34, _sand_y + h * 0.04, x + w * 0.66, _sand_y + h * 0.20, false);
	// Shimmer
	draw_set_colour(make_colour_rgb(98, 215, 228));
	draw_ellipse(x + w * 0.40, _sand_y + h * 0.05, x + w * 0.56, _sand_y + h * 0.11, false);

	// Palm trunk (slight rightward lean)
	var _px  = x + w * 0.36;
	var _pby = _sand_y + h * 0.02;
	var _ptx = _px + w * 0.06;
	var _pty = y + h * 0.20;
	draw_set_colour(make_colour_rgb(138, 98, 48));
	draw_line_width(_px, _pby, _ptx, _pty, 4);

	// Palm leaves — fan of lines from trunk tip
	draw_set_colour(make_colour_rgb(68, 148, 52));
	var _leaf_angles = [-65, -35, -5, 25, 52, -92];
	for (var _i = 0; _i < 6; _i++) {
		var _ang  = degtorad(_leaf_angles[_i]);
		var _llen = w * 0.18;
		draw_line_width(_ptx, _pty, _ptx + cos(_ang) * _llen, _pty + sin(_ang) * _llen, 2);
	}
}

// ── Ranch background entry point ───────────────────────────────────────────────
/// @desc Draws a parallax biome background in Draw GUI space (0,0)→(w,h).
///       cam_x/cam_y are the room-space camera origin from camera_get_view_x/y.
function scr_draw_ranch_background(biome_id, w, h, cam_x, cam_y) {
	switch (biome_id) {
		case BIOME.ALPINE_FOREST:    __ranch_alpine(w, h, cam_x);          break;
		case BIOME.TEMPERATE_FOREST: __ranch_temperate(w, h, cam_x);       break;
		case BIOME.JUNGLE:           __ranch_jungle(w, h, cam_x);          break;
		case BIOME.OASIS:            __ranch_oasis(w, h, cam_x);           break;
		case BIOME.MOUNTAIN_VALLEY:  __ranch_mountain_valley(w, h, cam_x); break;
		default:
			draw_set_colour(make_colour_rgb(0, 0, 0));
			draw_rectangle(0, 0, w, h, false);
	}
	draw_set_alpha(1.0);
	draw_set_colour(c_white);
}

// Wraps (base_frac*w - off) into [0,w). Draw elements at x, x-w, x+w for edge coverage.
function __ranch_wx(base_frac, off, w) {
	return (((base_frac * w - off) mod w) + w) mod w;
}

// ── Alpine Forest ranch background ────────────────────────────────────────────
function __ranch_alpine(w, h, cam_x) {
	var _gnd_y = floor(h * 0.55);
	var _fg_y  = floor(h * 0.85);
	var _off0  = cam_x * 0.05;   // far: mountains
	var _off1  = cam_x * 0.15;   // mid: background pines
	var _off2  = cam_x * 0.30;   // near: foreground pines + snow patches
	var _off3  = cam_x * 0.55;   // fg: detail layer

	// ── Layer 0: Sky gradient (no parallax) ──────────────────────────────────
	var _c_top = make_colour_rgb(8, 12, 40);
	var _c_bot = make_colour_rgb(40, 30, 80);
	var _bh    = _gnd_y / 8;
	for (var _i = 0; _i < 8; _i++) {
		var _c1 = merge_colour(_c_top, _c_bot, _i / 8);
		var _c2 = merge_colour(_c_top, _c_bot, (_i + 1) / 8);
		draw_rectangle_colour(0, _i * _bh, w, (_i + 1) * _bh, _c1, _c1, _c2, _c2, false);
	}

	// ── Layer 1: Far mountains + snow caps (off0) ─────────────────────────────
	var _mfx = [0.20, 0.55, 0.85];
	var _mfy = [0.10, 0.04, 0.13];
	var _mhw = [0.17, 0.26, 0.20];
	draw_set_colour(make_colour_rgb(35, 40, 65));
	for (var _i = 0; _i < 3; _i++) {
		var _cx = __ranch_wx(_mfx[_i], _off0, w);
		var _py = h * _mfy[_i];
		var _hw = w * _mhw[_i];
		for (var _r = -1; _r <= 1; _r++) {
			var _dx = _cx + _r * w;
			draw_triangle(_dx - _hw, _gnd_y, _dx + _hw, _gnd_y, _dx, _py, false);
		}
	}
	draw_set_colour(make_colour_rgb(240, 245, 255));
	for (var _i = 0; _i < 3; _i++) {
		var _cx  = __ranch_wx(_mfx[_i], _off0, w);
		var _py  = h * _mfy[_i];
		var _hw  = w * _mhw[_i];
		var _sy  = _py + (_gnd_y - _py) * 0.20;
		var _shw = _hw * 0.20;
		for (var _r = -1; _r <= 1; _r++) {
			var _dx = _cx + _r * w;
			draw_triangle(_dx - _shw, _sy, _dx + _shw, _sy, _dx, _py, false);
		}
	}

	// ── Ground fill ───────────────────────────────────────────────────────────
	draw_set_colour(make_colour_rgb(200, 210, 220));
	draw_rectangle(0, _gnd_y, w, h, false);

	// ── Layer 2: Mid pines (off1) ─────────────────────────────────────────────
	draw_set_colour(make_colour_rgb(20, 28, 52));
	var _mfx2 = [0.10, 0.28, 0.48, 0.68, 0.88];
	var _mfh2 = [0.19, 0.22, 0.18, 0.21, 0.20];
	for (var _i = 0; _i < 5; _i++) {
		var _cx = __ranch_wx(_mfx2[_i], _off1, w);
		var _th = h * _mfh2[_i];
		for (var _r = -1; _r <= 1; _r++) {
			__biome_pine(_cx + _r * w, _gnd_y - _th, _gnd_y, w * 0.018);
		}
	}

	// ── Layer 3: Near pines + snow patches (off2) ─────────────────────────────
	draw_set_colour(make_colour_rgb(235, 242, 248));
	var _spfx = [0.06, 0.18, 0.32, 0.48, 0.63, 0.77, 0.90, 0.98];
	var _spfy = [0.62, 0.70, 0.65, 0.75, 0.67, 0.72, 0.68, 0.78];
	var _sprx = [0.038, 0.045, 0.040, 0.048, 0.036, 0.043, 0.038, 0.044];
	for (var _i = 0; _i < 8; _i++) {
		var _cx = __ranch_wx(_spfx[_i], _off2, w);
		var _ey = h * _spfy[_i];
		var _rx = w * _sprx[_i];
		var _ry = h * 0.022;
		for (var _r = -1; _r <= 1; _r++) {
			var _dx = _cx + _r * w;
			draw_ellipse(_dx - _rx, _ey - _ry, _dx + _rx, _ey + _ry, false);
		}
	}
	draw_set_colour(make_colour_rgb(15, 20, 40));
	var _nfx = [0.04, 0.14, 0.24, 0.35, 0.46, 0.57, 0.67, 0.77, 0.87, 0.96];
	var _nfh = [0.26, 0.31, 0.24, 0.29, 0.25, 0.28, 0.31, 0.24, 0.28, 0.26];
	for (var _i = 0; _i < 10; _i++) {
		var _cx = __ranch_wx(_nfx[_i], _off2, w);
		var _th = h * _nfh[_i];
		for (var _r = -1; _r <= 1; _r++) {
			__biome_pine(_cx + _r * w, _gnd_y - _th, _gnd_y, w * 0.025);
		}
	}

	// ── Layer 4: Foreground strip (full-width fill, no parallax) ─────────────
	draw_set_colour(make_colour_rgb(180, 190, 200));
	draw_rectangle(0, _fg_y, w, h, false);
}

// ── Temperate Forest ranch background ─────────────────────────────────────────
function __ranch_temperate(w, h, cam_x) {
	var _gnd_y = floor(h * 0.50);
	var _fg_y  = floor(h * 0.82);
	var _off0  = cam_x * 0.05;
	var _off1  = cam_x * 0.15;
	var _off2  = cam_x * 0.30;
	var _off3  = cam_x * 0.55;

	// ── Layer 0: Sky gradient (no parallax) ──────────────────────────────────
	var _c_top = make_colour_rgb(100, 160, 220);
	var _c_bot = make_colour_rgb(160, 200, 240);
	var _bh    = _gnd_y / 6;
	for (var _i = 0; _i < 6; _i++) {
		var _c1 = merge_colour(_c_top, _c_bot, _i / 6);
		var _c2 = merge_colour(_c_top, _c_bot, (_i + 1) / 6);
		draw_rectangle_colour(0, _i * _bh, w, (_i + 1) * _bh, _c1, _c1, _c2, _c2, false);
	}

	// ── Ground fill ───────────────────────────────────────────────────────────
	draw_set_colour(make_colour_rgb(50, 120, 50));
	draw_rectangle(0, _gnd_y, w, h, false);

	// ── Layer 1: Far rolling hills (off0) ─────────────────────────────────────
	var _hfx = [0.18, 0.52, 0.84];
	var _hhw = [0.32, 0.36, 0.30];
	var _hhh = [0.18, 0.20, 0.17];
	draw_set_colour(make_colour_rgb(40, 100, 40));
	for (var _i = 0; _i < 3; _i++) {
		var _cx  = __ranch_wx(_hfx[_i], _off0, w);
		var _rhw = w * _hhw[_i];
		var _rhh = h * _hhh[_i];
		for (var _r = -1; _r <= 1; _r++) {
			var _dx = _cx + _r * w;
			draw_ellipse(_dx - _rhw, h * 0.36, _dx + _rhw, h * 0.36 + _rhh * 2, false);
		}
	}

	// ── Layer 2: Medium background trees (off1) ───────────────────────────────
	var _mt2x = [0.12, 0.35, 0.62, 0.88];
	var _mt2r = [0.060, 0.072, 0.065, 0.058];
	for (var _i = 0; _i < 4; _i++) {
		var _cx = __ranch_wx(_mt2x[_i], _off1, w);
		var _ty = _gnd_y + h * 0.02;
		var _cr = w * _mt2r[_i];
		for (var _r = -1; _r <= 1; _r++) {
			var _dx = _cx + _r * w;
			draw_set_colour(make_colour_rgb(25, 90, 25));
			draw_ellipse(_dx - _cr, _ty - _cr * 1.2, _dx + _cr, _ty + _cr * 0.4, false);
			draw_set_colour(make_colour_rgb(70, 45, 15));
			draw_rectangle(_dx - w * 0.004, _ty + _cr * 0.3, _dx + w * 0.004, _ty + _cr * 0.9, false);
		}
	}

	// ── Layer 3: Near trees (off2) ────────────────────────────────────────────
	var _nt3x = [0.05, 0.16, 0.27, 0.38, 0.50, 0.61, 0.72, 0.83, 0.94];
	var _nt3r = [0.052, 0.061, 0.056, 0.071, 0.052, 0.066, 0.060, 0.055, 0.071];
	for (var _i = 0; _i < 9; _i++) {
		var _cx = __ranch_wx(_nt3x[_i], _off2, w);
		var _ty = _gnd_y + h * 0.02;
		var _cr = w * _nt3r[_i];
		for (var _r = -1; _r <= 1; _r++) {
			var _dx = _cx + _r * w;
			draw_set_colour(make_colour_rgb(20, 80, 20));
			draw_ellipse(_dx - _cr, _ty - _cr * 1.2, _dx + _cr, _ty + _cr * 0.4, false);
			draw_set_colour(make_colour_rgb(70, 45, 15));
			draw_rectangle(_dx - w * 0.004, _ty + _cr * 0.3, _dx + w * 0.004, _ty + _cr * 0.9, false);
		}
	}

	// ── Layer 4: Foreground strip + flowers (off3) ────────────────────────────
	draw_set_colour(make_colour_rgb(60, 130, 60));
	draw_rectangle(0, _fg_y, w, h, false);
	var _fcols = [make_colour_rgb(255, 240, 50), make_colour_rgb(255, 255, 255), make_colour_rgb(255, 150, 180)];
	var _flfx  = [0.07, 0.18, 0.30, 0.43, 0.56, 0.68, 0.80, 0.92];
	var _flfy  = [0.88, 0.85, 0.91, 0.87, 0.93, 0.86, 0.90, 0.84];
	for (var _i = 0; _i < 8; _i++) {
		draw_set_colour(_fcols[_i mod 3]);
		var _cx = __ranch_wx(_flfx[_i], _off3, w);
		var _fy = h * _flfy[_i];
		var _fr = w * 0.004;
		for (var _r = -1; _r <= 1; _r++) {
			var _dx = _cx + _r * w;
			draw_ellipse(_dx - _fr, _fy - _fr, _dx + _fr, _fy + _fr, false);
		}
	}
}

// ── Jungle ranch background ────────────────────────────────────────────────────
function __ranch_jungle(w, h, cam_x) {
	var _gnd_y = floor(h * 0.55);
	var _fg_y  = floor(h * 0.80);
	var _off0  = cam_x * 0.05;
	var _off1  = cam_x * 0.15;
	var _off2  = cam_x * 0.30;
	var _off3  = cam_x * 0.55;

	// ── Layer 0: Sky fill (no parallax) ──────────────────────────────────────
	draw_set_colour(make_colour_rgb(15, 35, 15));
	draw_rectangle(0, 0, w, h, false);

	// ── Layer 1: Far upper canopy (off0) ──────────────────────────────────────
	var _c1fx = [0.18, 0.52, 0.84];
	var _c1fw = [0.32, 0.30, 0.28];
	draw_set_colour(make_colour_rgb(10, 50, 10));
	for (var _i = 0; _i < 3; _i++) {
		var _cx  = __ranch_wx(_c1fx[_i], _off0, w);
		var _rhw = w * _c1fw[_i];
		for (var _r = -1; _r <= 1; _r++) {
			var _dx = _cx + _r * w;
			draw_ellipse(_dx - _rhw, -h * 0.06, _dx + _rhw, h * 0.50, false);
		}
	}

	// ── Layer 2: Mid canopy + vines (off1) ────────────────────────────────────
	var _c2fx = [0.12, 0.40, 0.68, 0.92];
	var _c2fw = [0.28, 0.30, 0.27, 0.26];
	draw_set_colour(make_colour_rgb(20, 70, 20));
	for (var _i = 0; _i < 4; _i++) {
		var _cx  = __ranch_wx(_c2fx[_i], _off1, w);
		var _rhw = w * _c2fw[_i];
		for (var _r = -1; _r <= 1; _r++) {
			var _dx = _cx + _r * w;
			draw_ellipse(_dx - _rhw, h * 0.12, _dx + _rhw, h * 0.56, false);
		}
	}
	draw_set_colour(make_colour_rgb(30, 80, 20));
	var _vfx = [0.15, 0.30, 0.48, 0.64, 0.78, 0.93];
	for (var _i = 0; _i < 6; _i++) {
		var _cx = __ranch_wx(_vfx[_i], _off1, w);
		for (var _r = -1; _r <= 1; _r++) {
			var _dx = _cx + _r * w;
			draw_line_width(_dx, 0, _dx + w * 0.005, _gnd_y * 0.75, 2);
		}
	}

	// ── Ground fill ───────────────────────────────────────────────────────────
	draw_set_colour(make_colour_rgb(20, 55, 20));
	draw_rectangle(0, _gnd_y, w, h, false);

	// ── Layer 3: Near canopy + fog + bright spots (off2) ─────────────────────
	var _c3fx = [0.20, 0.56, 0.84];
	var _c3fw = [0.28, 0.30, 0.26];
	draw_set_colour(make_colour_rgb(15, 60, 15));
	for (var _i = 0; _i < 3; _i++) {
		var _cx  = __ranch_wx(_c3fx[_i], _off2, w);
		var _rhw = w * _c3fw[_i];
		for (var _r = -1; _r <= 1; _r++) {
			var _dx = _cx + _r * w;
			draw_ellipse(_dx - _rhw, h * 0.30, _dx + _rhw, h * 0.66, false);
		}
	}
	draw_set_alpha(0.15);
	draw_set_colour(make_colour_rgb(255, 255, 255));
	var _fogfx = [0.20, 0.55, 0.85];
	var _fogfw = [0.28, 0.26, 0.27];
	for (var _i = 0; _i < 3; _i++) {
		var _cx  = __ranch_wx(_fogfx[_i], _off2, w);
		var _rhw = w * _fogfw[_i];
		for (var _r = -1; _r <= 1; _r++) {
			var _dx = _cx + _r * w;
			draw_ellipse(_dx - _rhw, _gnd_y - h * 0.05, _dx + _rhw, _gnd_y + h * 0.07, false);
		}
	}
	draw_set_alpha(1.0);
	draw_set_colour(make_colour_rgb(120, 200, 50));
	var _bsfx = [0.22, 0.52, 0.77];
	var _bsfy = [0.22, 0.16, 0.25];
	for (var _i = 0; _i < 3; _i++) {
		var _cx = __ranch_wx(_bsfx[_i], _off2, w);
		var _sy = h * _bsfy[_i];
		var _sr = w * 0.012;
		for (var _r = -1; _r <= 1; _r++) {
			var _dx = _cx + _r * w;
			draw_ellipse(_dx - _sr, _sy - _sr, _dx + _sr, _sy + _sr, false);
		}
	}

	// ── Layer 4: Dense foreground foliage (off3) ──────────────────────────────
	var _fgfx = [0.12, 0.38, 0.65, 0.90];
	var _fgfw = [0.20, 0.22, 0.18, 0.20];
	draw_set_colour(make_colour_rgb(10, 48, 10));
	for (var _i = 0; _i < 4; _i++) {
		var _cx  = __ranch_wx(_fgfx[_i], _off3, w);
		var _rhw = w * _fgfw[_i];
		for (var _r = -1; _r <= 1; _r++) {
			var _dx = _cx + _r * w;
			draw_ellipse(_dx - _rhw, _fg_y, _dx + _rhw, h * 1.05, false);
		}
	}
}

// ── Oasis ranch background ─────────────────────────────────────────────────────
function __ranch_oasis(w, h, cam_x) {
	var _gnd_y = floor(h * 0.50);
	var _fg_y  = floor(h * 0.85);
	var _off0  = cam_x * 0.05;
	var _off1  = cam_x * 0.15;
	var _off2  = cam_x * 0.30;
	var _off3  = cam_x * 0.55;

	// ── Layer 0: Sky gradient + fixed sun (no parallax) ──────────────────────
	var _c_top = make_colour_rgb(200, 120, 40);
	var _c_bot = make_colour_rgb(220, 170, 80);
	draw_rectangle_colour(0, 0, w, _gnd_y, _c_top, _c_top, _c_bot, _c_bot, false);
	draw_set_alpha(0.6);
	draw_set_colour(make_colour_rgb(255, 200, 80));
	var _sun_x = w * 0.82;
	var _sun_y = h * 0.12;
	var _sun_r = w * 0.065;
	draw_ellipse(_sun_x - _sun_r, _sun_y - _sun_r, _sun_x + _sun_r, _sun_y + _sun_r, false);
	draw_set_alpha(0.2);
	draw_ellipse(_sun_x - _sun_r * 1.5, _sun_y - _sun_r * 1.5, _sun_x + _sun_r * 1.5, _sun_y + _sun_r * 1.5, false);
	draw_set_alpha(1.0);

	// ── Ground fill ───────────────────────────────────────────────────────────
	draw_set_colour(make_colour_rgb(190, 160, 90));
	draw_rectangle(0, _gnd_y, w, h, false);

	// ── Layer 1: Far dunes (off0) ─────────────────────────────────────────────
	var _d1fx = [0.18, 0.55, 0.88];
	var _d1fw = [0.32, 0.36, 0.28];
	draw_set_colour(make_colour_rgb(175, 145, 75));
	for (var _i = 0; _i < 3; _i++) {
		var _cx  = __ranch_wx(_d1fx[_i], _off0, w);
		var _rhw = w * _d1fw[_i];
		for (var _r = -1; _r <= 1; _r++) {
			var _dx = _cx + _r * w;
			draw_ellipse(_dx - _rhw, h * 0.38, _dx + _rhw, h * 0.65, false);
		}
	}

	// ── Layer 2: Mid dunes + water pool (off1) ────────────────────────────────
	var _d2fx = [0.28, 0.64, 0.92];
	var _d2fw = [0.28, 0.30, 0.25];
	draw_set_colour(make_colour_rgb(180, 150, 80));
	for (var _i = 0; _i < 3; _i++) {
		var _cx  = __ranch_wx(_d2fx[_i], _off1, w);
		var _rhw = w * _d2fw[_i];
		for (var _r = -1; _r <= 1; _r++) {
			var _dx = _cx + _r * w;
			draw_ellipse(_dx - _rhw, h * 0.40, _dx + _rhw, h * 0.66, false);
		}
	}
	var _pcx = __ranch_wx(0.32, _off1, w);
	for (var _r = -1; _r <= 1; _r++) {
		var _dx = _pcx + _r * w;
		draw_set_colour(make_colour_rgb(60, 120, 180));
		draw_ellipse(_dx - w * 0.12, _gnd_y + h * 0.05, _dx + w * 0.12, _gnd_y + h * 0.14, false);
		draw_set_colour(make_colour_rgb(100, 170, 220));
		draw_ellipse(_dx - w * 0.06, _gnd_y + h * 0.06, _dx + w * 0.06, _gnd_y + h * 0.10, false);
	}

	// ── Layer 3: Palm trees + heat shimmer (off2) ─────────────────────────────
	var _pfx   = [0.15, 0.32, 0.55, 0.72, 0.90];
	var _plean = [1, -1, 1, -1, 1];
	for (var _i = 0; _i < 5; _i++) {
		var _cx  = __ranch_wx(_pfx[_i], _off2, w);
		var _tby = _gnd_y + h * 0.04;
		var _tty = _gnd_y - h * 0.18;
		var _lx  = _plean[_i] * w * 0.022;
		var _lr  = w * 0.045;
		for (var _r = -1; _r <= 1; _r++) {
			var _dx = _cx + _r * w;
			draw_set_colour(make_colour_rgb(100, 70, 30));
			draw_line_width(_dx, _tby, _dx + _lx, _tty, 5);
			draw_set_colour(make_colour_rgb(50, 130, 50));
			draw_ellipse(_dx + _lx - _lr, _tty - _lr * 0.6, _dx + _lx + _lr, _tty + _lr * 0.4, false);
		}
	}
	draw_set_alpha(0.1);
	draw_set_colour(make_colour_rgb(255, 240, 200));
	draw_line_width(0, _gnd_y + h * 0.02, w, _gnd_y + h * 0.02, 2);
	draw_line_width(0, _gnd_y + h * 0.04, w, _gnd_y + h * 0.04, 1);
	draw_set_alpha(1.0);

	// ── Layer 4: Sandy foreground strip (no parallax) ─────────────────────────
	draw_set_colour(make_colour_rgb(200, 168, 95));
	draw_rectangle(0, _fg_y, w, h, false);
}

// ── Mountain Valley ranch background ──────────────────────────────────────────
function __ranch_mountain_valley(w, h, cam_x) {
	var _gnd_y = floor(h * 0.55);
	var _fg_y  = floor(h * 0.85);
	var _off0  = cam_x * 0.05;
	var _off1  = cam_x * 0.15;
	var _off2  = cam_x * 0.30;
	var _off3  = cam_x * 0.55;

	// ── Layer 0: Night sky + static stars + moon (no parallax) ───────────────
	draw_set_colour(make_colour_rgb(15, 10, 35));
	draw_rectangle(0, 0, w, _gnd_y, false);
	draw_set_colour(make_colour_rgb(255, 255, 255));
	var _stfx = [0.05, 0.14, 0.26, 0.37, 0.50, 0.61, 0.73, 0.83, 0.93, 0.20, 0.44, 0.67];
	var _stfy = [0.05, 0.17, 0.08, 0.22, 0.10, 0.26, 0.06, 0.16, 0.32, 0.36, 0.39, 0.43];
	for (var _i = 0; _i < 12; _i++) {
		var _sr = w * 0.003;
		var _sx = w * _stfx[_i];
		var _sy = h * _stfy[_i];
		draw_ellipse(_sx - _sr, _sy - _sr, _sx + _sr, _sy + _sr, false);
	}
	draw_set_alpha(0.9);
	draw_set_colour(make_colour_rgb(240, 240, 200));
	draw_ellipse(w * 0.08, h * 0.05, w * 0.16, h * 0.13, false);
	draw_set_alpha(1.0);

	// ── Layer 1: Far mountain peaks (off0) ────────────────────────────────────
	var _fm1fx = [0.15, 0.40, 0.65, 0.88];
	var _fm1fy = [0.08, 0.04, 0.07, 0.11];
	var _fm1hw = [0.18, 0.20, 0.17, 0.16];
	draw_set_colour(make_colour_rgb(25, 20, 45));
	for (var _i = 0; _i < 4; _i++) {
		var _cx = __ranch_wx(_fm1fx[_i], _off0, w);
		var _py = h * _fm1fy[_i];
		var _hw = w * _fm1hw[_i];
		for (var _r = -1; _r <= 1; _r++) {
			var _dx = _cx + _r * w;
			draw_triangle(_dx - _hw, _gnd_y, _dx + _hw, _gnd_y, _dx, _py, false);
		}
	}

	// ── Layer 2: Mid peaks (darker) + cave entrance (off1) ────────────────────
	var _fm2fx = [0.28, 0.58, 0.82];
	var _fm2fy = [0.18, 0.14, 0.20];
	var _fm2hw = [0.16, 0.18, 0.15];
	draw_set_colour(make_colour_rgb(38, 32, 62));
	for (var _i = 0; _i < 3; _i++) {
		var _cx = __ranch_wx(_fm2fx[_i], _off1, w);
		var _py = h * _fm2fy[_i];
		var _hw = w * _fm2hw[_i];
		for (var _r = -1; _r <= 1; _r++) {
			var _dx = _cx + _r * w;
			draw_triangle(_dx - _hw, _gnd_y, _dx + _hw, _gnd_y, _dx, _py, false);
		}
	}
	var _cvcx = __ranch_wx(0.18, _off1, w);
	for (var _r = -1; _r <= 1; _r++) {
		var _dx = _cvcx + _r * w;
		draw_set_colour(make_colour_rgb(5, 5, 10));
		draw_ellipse(_dx - w * 0.06, _gnd_y + h * 0.04, _dx + w * 0.06, _gnd_y + h * 0.16, false);
	}

	// ── Rocky ground fill ─────────────────────────────────────────────────────
	draw_set_colour(make_colour_rgb(55, 50, 70));
	draw_rectangle(0, _gnd_y, w, h, false);

	// ── Layer 3: Rock formations (off2) ───────────────────────────────────────
	var _rfx  = [0.08, 0.24, 0.42, 0.60, 0.76, 0.92];
	var _rfy  = [0.58, 0.62, 0.59, 0.64, 0.60, 0.62];
	var _rby  = [0.68, 0.72, 0.70, 0.73, 0.71, 0.70];
	var _rhwf = [0.04, 0.05, 0.04, 0.04, 0.05, 0.04];
	draw_set_colour(make_colour_rgb(65, 60, 80));
	for (var _i = 0; _i < 6; _i++) {
		var _cx = __ranch_wx(_rfx[_i], _off2, w);
		var _py = h * _rfy[_i];
		var _by = h * _rby[_i];
		var _hw = w * _rhwf[_i];
		for (var _r = -1; _r <= 1; _r++) {
			var _dx = _cx + _r * w;
			draw_triangle(_dx, _py, _dx - _hw, _by, _dx + _hw, _by, false);
		}
	}

	// ── Layer 4: Foreground rocks strip + bumps (off3) ────────────────────────
	draw_set_colour(make_colour_rgb(70, 65, 85));
	draw_rectangle(0, _fg_y, w, h, false);
	var _fbfx = [0.12, 0.38, 0.65, 0.88];
	var _fbfw = [0.14, 0.16, 0.13, 0.15];
	draw_set_colour(make_colour_rgb(80, 75, 95));
	for (var _i = 0; _i < 4; _i++) {
		var _cx  = __ranch_wx(_fbfx[_i], _off3, w);
		var _rhw = w * _fbfw[_i];
		for (var _r = -1; _r <= 1; _r++) {
			var _dx = _cx + _r * w;
			draw_ellipse(_dx - _rhw, _fg_y - h * 0.025, _dx + _rhw, _fg_y + h * 0.05, false);
		}
	}
}

// ── Ranch sky entry point (world-space Draw event) ────────────────────────────
/// @desc Draws the sky/horizon band in world space starting at (cam_x, cam_y).
///       Only covers the top 42% of the view; ground is left to the room's
///       background colour. cam_x/cam_y come from camera_get_view_x/y.
function scr_draw_ranch_sky(biome_id, cam_x, cam_y, vw, vh) {
	var _sky_h = vh * 0.42;
	var _p0    = 0.06; // far-mountain parallax factor
	var _p1    = 0.18; // mid-element parallax factor

	switch (biome_id) {
		case BIOME.ALPINE_FOREST:
			var _ct = make_colour_rgb(8,  12,  40);
			var _cb = make_colour_rgb(40, 30,  80);
			draw_rectangle_colour(cam_x, cam_y, cam_x+vw, cam_y+_sky_h, _ct,_ct,_cb,_cb, false);
			var _mx_offset = cam_x * (1 - _p0);
			draw_set_colour(make_colour_rgb(35,40,65));
			var _mt_positions = [0.15, 0.48, 0.82];
			var _mt_heights   = [0.12, 0.05, 0.15];
			var _mt_widths    = [0.18, 0.24, 0.20];
			for (var _i = 0; _i < 3; _i++) {
				var _base_world_x = _mt_positions[_i] * vw * 3;
				var _px = _base_world_x - _mx_offset;
				_px = ((_px mod (vw * 3)) + vw * 3) mod (vw * 3) - vw;
				var _hw = vw * _mt_widths[_i];
				var _py = cam_y + _sky_h * _mt_heights[_i];
				draw_triangle(cam_x+_px-_hw, cam_y+_sky_h, cam_x+_px+_hw, cam_y+_sky_h, cam_x+_px, _py, false);
			}
			draw_set_colour(make_colour_rgb(240,245,255));
			for (var _i = 0; _i < 3; _i++) {
				var _base_world_x = _mt_positions[_i] * vw * 3;
				var _px = _base_world_x - _mx_offset;
				_px = ((_px mod (vw * 3)) + vw * 3) mod (vw * 3) - vw;
				var _hw  = vw * _mt_widths[_i] * 0.18;
				var _py  = cam_y + _sky_h * _mt_heights[_i];
				var _sy  = _py + (_sky_h * (1 - _mt_heights[_i])) * 0.20;
				draw_triangle(cam_x+_px-_hw, _sy, cam_x+_px+_hw, _sy, cam_x+_px, _py, false);
			}
			draw_set_alpha(0.3);
			draw_set_colour(make_colour_rgb(80,60,140));
			draw_rectangle(cam_x, cam_y+_sky_h-4, cam_x+vw, cam_y+_sky_h, false);
			draw_set_alpha(1);
			break;

		case BIOME.TEMPERATE_FOREST:
			var _ct = make_colour_rgb(100,160,220);
			var _cb = make_colour_rgb(160,200,240);
			draw_rectangle_colour(cam_x, cam_y, cam_x+vw, cam_y+_sky_h, _ct,_ct,_cb,_cb, false);
			var _hx_off = cam_x * (1 - _p0);
			draw_set_colour(make_colour_rgb(55,115,55));
			var _hill_pos = [0.20, 0.55, 0.85];
			var _hill_w   = [0.30, 0.35, 0.28];
			for (var _i = 0; _i < 3; _i++) {
				var _bx = _hill_pos[_i] * vw * 3 - _hx_off;
				_bx = ((_bx mod (vw*3)) + vw*3) mod (vw*3) - vw;
				var _hw = vw * _hill_w[_i];
				draw_ellipse(cam_x+_bx-_hw, cam_y+_sky_h*0.60, cam_x+_bx+_hw, cam_y+_sky_h*1.10, false);
			}
			draw_set_colour(make_colour_rgb(30,85,30));
			draw_rectangle(cam_x, cam_y+_sky_h*0.82, cam_x+vw, cam_y+_sky_h, false);
			break;

		case BIOME.JUNGLE:
			draw_set_colour(make_colour_rgb(8,22,8));
			draw_rectangle(cam_x, cam_y, cam_x+vw, cam_y+_sky_h, false);
			var _jx_off = cam_x * (1 - _p0);
			draw_set_colour(make_colour_rgb(12,45,12));
			var _can_pos = [0.15, 0.42, 0.70, 0.92];
			var _can_w   = [0.22, 0.26, 0.24, 0.20];
			for (var _i = 0; _i < 4; _i++) {
				var _bx = _can_pos[_i] * vw * 3 - _jx_off;
				_bx = ((_bx mod (vw*3)) + vw*3) mod (vw*3) - vw;
				var _hw = vw * _can_w[_i];
				draw_ellipse(cam_x+_bx-_hw, cam_y, cam_x+_bx+_hw, cam_y+_sky_h*0.85, false);
			}
			draw_set_alpha(0.06);
			draw_set_colour(c_white);
			for (var _i = 0; _i < 3; _i++) {
				var _rx = cam_x + vw * (0.25 + _i * 0.28);
				draw_triangle(_rx-vw*0.04, cam_y, _rx+vw*0.04, cam_y, _rx+vw*0.15, cam_y+_sky_h, false);
			}
			draw_set_alpha(1);
			break;

		case BIOME.OASIS:
			var _ct = make_colour_rgb(210,90, 20);
			var _cb = make_colour_rgb(235,165,60);
			draw_rectangle_colour(cam_x, cam_y, cam_x+vw, cam_y+_sky_h, _ct,_ct,_cb,_cb, false);
			draw_set_alpha(0.7);
			draw_set_colour(make_colour_rgb(255,210,80));
			draw_ellipse(cam_x+vw*0.80, cam_y+vh*0.05, cam_x+vw*0.93, cam_y+vh*0.17, false);
			draw_set_alpha(0.2);
			draw_ellipse(cam_x+vw*0.77, cam_y+vh*0.02, cam_x+vw*0.96, cam_y+vh*0.20, false);
			draw_set_alpha(1);
			var _dx_off = cam_x * (1 - _p0);
			draw_set_colour(make_colour_rgb(170,138,68));
			var _dune_pos = [0.18, 0.52, 0.84];
			var _dune_w   = [0.28, 0.32, 0.26];
			for (var _i = 0; _i < 3; _i++) {
				var _bx = _dune_pos[_i] * vw * 3 - _dx_off;
				_bx = ((_bx mod (vw*3)) + vw*3) mod (vw*3) - vw;
				var _hw = vw * _dune_w[_i];
				draw_ellipse(cam_x+_bx-_hw, cam_y+_sky_h*0.55, cam_x+_bx+_hw, cam_y+_sky_h*1.05, false);
			}
			break;

		case BIOME.MOUNTAIN_VALLEY:
			draw_set_colour(make_colour_rgb(5,3,15));
			draw_rectangle(cam_x, cam_y, cam_x+vw, cam_y+_sky_h, false);
			draw_set_colour(c_white);
			var _star_fx = [0.05,0.14,0.24,0.35,0.48,0.60,0.72,0.83,0.92,0.18,0.42,0.65,0.78,0.30,0.55];
			var _star_fy = [0.06,0.18,0.09,0.24,0.11,0.28,0.07,0.18,0.35,0.38,0.42,0.15,0.30,0.45,0.50];
			for (var _i = 0; _i < 15; _i++) {
				var _sr = vw * 0.003;
				draw_ellipse(cam_x+vw*_star_fx[_i]-_sr, cam_y+_sky_h*_star_fy[_i]-_sr,
				             cam_x+vw*_star_fx[_i]+_sr, cam_y+_sky_h*_star_fy[_i]+_sr, false);
			}
			draw_set_alpha(0.85);
			draw_set_colour(make_colour_rgb(235,230,200));
			draw_ellipse(cam_x+vw*0.10, cam_y+_sky_h*0.06, cam_x+vw*0.18, cam_y+_sky_h*0.20, false);
			draw_set_alpha(1);
			var _mmx_off = cam_x * (1 - _p0);
			draw_set_colour(make_colour_rgb(20,16,38));
			var _mm_pos = [0.12, 0.36, 0.62, 0.86];
			var _mm_h   = [0.10, 0.05, 0.08, 0.12];
			var _mm_w   = [0.16, 0.20, 0.17, 0.15];
			for (var _i = 0; _i < 4; _i++) {
				var _bx = _mm_pos[_i] * vw * 3 - _mmx_off;
				_bx = ((_bx mod (vw*3)) + vw*3) mod (vw*3) - vw;
				var _hw = vw * _mm_w[_i];
				var _py = cam_y + _sky_h * _mm_h[_i];
				draw_triangle(cam_x+_bx-_hw, cam_y+_sky_h, cam_x+_bx+_hw, cam_y+_sky_h, cam_x+_bx, _py, false);
			}
			break;
	}
	draw_set_alpha(1);
	draw_set_colour(c_white);
}

// ── Mountain Valley ────────────────────────────────────────────────────────────
function __biome_mountain(x, y, w, h, _t) {
	var _horiz_y = y + h * 0.62;

	// Sky: deep purple → lavender
	draw_rectangle_colour(x, y, x + w, _horiz_y,
		make_colour_rgb(28, 16, 48),  make_colour_rgb(28, 16, 48),
		make_colour_rgb(88, 68, 118), make_colour_rgb(88, 68, 118), false);

	// Sunset glow band at horizon — gradient fade then sharp bright line on top
	draw_rectangle_colour(x, _horiz_y - h * 0.06, x + w, _horiz_y,
		make_colour_rgb(215, 110, 38), make_colour_rgb(215, 110, 38),
		make_colour_rgb(88,  68, 118), make_colour_rgb(88,  68, 118), false);
	draw_set_colour(make_colour_rgb(255, 140, 40));
	draw_rectangle(x, _horiz_y - 1, x + w, _horiz_y + 1, false);

	// Far mountain peaks — visible blue-grey, within card bounds
	draw_set_colour(make_colour_rgb(80, 80, 120));
	draw_triangle(x,            _horiz_y, x + w * 0.40, _horiz_y, x + w * 0.20, y + h * 0.18, false);
	draw_triangle(x + w * 0.25, _horiz_y, x + w * 0.65, _horiz_y, x + w * 0.45, y + h * 0.10, false);
	draw_triangle(x + w * 0.55, _horiz_y, x + w,        _horiz_y, x + w * 0.75, y + h * 0.20, false);

	// Near peaks — lighter, within card bounds
	draw_set_colour(make_colour_rgb(100, 100, 150));
	draw_triangle(x,            _horiz_y, x + w * 0.38, _horiz_y, x + w * 0.16, y + h * 0.34, false);
	draw_triangle(x + w * 0.48, _horiz_y, x + w,        _horiz_y, x + w * 0.76, y + h * 0.30, false);

	// Valley floor
	draw_set_colour(make_colour_rgb(32, 22, 48));
	draw_rectangle(x, _horiz_y, x + w, y + h, false);

	// Foothills — wide low triangles (replaced circular ellipses), within card bounds
	draw_set_colour(make_colour_rgb(40, 28, 58));
	draw_triangle(x,            y + h, x + w * 0.65, y + h, x + w * 0.28, _horiz_y + h * 0.02, false);
	draw_triangle(x + w * 0.35, y + h, x + w,        y + h, x + w * 0.72, _horiz_y + h * 0.04, false);
}

draw_set_font(-1);
draw_set_alpha(title_alpha);

var W     = room_width;     // 1366
var H     = room_height;    // 768
var _t    = current_time * 0.001;  // seconds, for animation

var sky_h  = H * 0.50;   // 384 — horizon
var mid_y  = H * 0.50;   // 384 — midground starts
var fore_y = H * 0.80;   // 614 — foreground strip starts

// ── Sky: deep twilight gradient, purple-blue top → warm amber horizon ─────────
draw_rectangle_colour(0, 0, W, sky_h,
	make_colour_rgb(22, 12, 52), make_colour_rgb(22, 12, 52),
	make_colour_rgb(195, 108, 40), make_colour_rgb(195, 108, 40),
	false);

// ── Stars: 20 deterministic dots, subtle twinkle via alpha ───────────────────
for (var _i = 0; _i < 20; _i++) {
	var _sx = (_i * 317 + 89)  mod W;
	var _sy = (_i * 173 + 41)  mod (sky_h * 0.68);
	var _tw = 0.50 + 0.50 * sin(_t * (1.1 + _i * 0.19) + _i * 2.3);
	draw_set_alpha(title_alpha * _tw);
	draw_set_colour(make_colour_rgb(230, 220, 255));
	draw_rectangle(_sx, _sy, _sx + 2, _sy + 2, false);
}
draw_set_alpha(title_alpha);

// ── Distant mountains: 5 dark triangle peaks along the horizon ───────────────
draw_set_colour(make_colour_rgb(48, 32, 72));
draw_triangle(0,          sky_h, W * 0.22, sky_h, W * 0.11, sky_h * 0.36, false);
draw_triangle(W * 0.14,   sky_h, W * 0.42, sky_h, W * 0.28, sky_h * 0.20, false);
draw_triangle(W * 0.35,   sky_h, W * 0.60, sky_h, W * 0.48, sky_h * 0.30, false);
draw_triangle(W * 0.56,   sky_h, W * 0.82, sky_h, W * 0.69, sky_h * 0.18, false);
draw_triangle(W * 0.76,   sky_h, W,        sky_h, W * 0.88, sky_h * 0.34, false);

// ── Midground: rolling dark green hills ───────────────────────────────────────
draw_set_colour(make_colour_rgb(18, 46, 18));
draw_ellipse(0,          mid_y - H * 0.07, W * 0.54, H, false);
draw_set_colour(make_colour_rgb(26, 60, 24));
draw_ellipse(W * 0.30,   mid_y - H * 0.11, W,        H, false);
draw_set_colour(make_colour_rgb(14, 38, 14));
draw_rectangle(0, mid_y + H * 0.05, W, fore_y, false);

// Pine silhouettes — reuse __biome_pine from scr_biome_draw
// signature: __biome_pine(cx, peak_y, base_y, hw)
draw_set_colour(make_colour_rgb(8, 16, 10));
__biome_pine(W * 0.06, mid_y - H * 0.18, fore_y, W * 0.026);
__biome_pine(W * 0.14, mid_y - H * 0.13, fore_y, W * 0.020);
__biome_pine(W * 0.79, mid_y - H * 0.16, fore_y, W * 0.024);
__biome_pine(W * 0.88, mid_y - H * 0.21, fore_y, W * 0.030);
__biome_pine(W * 0.96, mid_y - H * 0.12, fore_y, W * 0.019);

// ── Foreground ground strip ───────────────────────────────────────────────────
draw_set_colour(make_colour_rgb(10, 24, 10));
draw_rectangle(0, fore_y, W, H, false);

// Grass texture — short deterministic vertical lines
draw_set_colour(make_colour_rgb(20, 48, 18));
for (var _i = 0; _i < 90; _i++) {
	var _gx = (_i * 137 + 23) mod W;
	var _gh = 5 + ((_i * 53) mod 9);
	draw_line(_gx, fore_y, _gx, fore_y + _gh);
}

// ── Fireflies: 6 drifting glowing dots in the midground ──────────────────────
for (var _i = 0; _i < 6; _i++) {
	var _fx   = ((_i * 211 + 80) mod W) * 0.80 + W * 0.10
	            + sin(_t * 0.38 + _i * 1.9) * 18;
	var _fy   = mid_y + ((_i * 97 + 30) mod (fore_y - mid_y))
	            + sin(_t * 0.55 + _i * 2.7) * 10;
	var _fglow = 0.25 + 0.75 * abs(sin(_t * 1.3 + _i * 1.1));
	draw_set_alpha(title_alpha * _fglow);
	draw_set_colour(make_colour_rgb(195, 255, 130));
	draw_rectangle(_fx, _fy, _fx + 3, _fy + 3, false);
}
draw_set_alpha(title_alpha);

// ── Title glow halo: large soft ellipse behind the title text ─────────────────
draw_set_alpha(title_alpha * 0.16);
draw_set_colour(make_colour_rgb(255, 160, 24));
draw_ellipse(W * 0.5 - 430, 148, W * 0.5 + 430, 308, false);
draw_set_alpha(title_alpha);

// ── Title drop-shadow ─────────────────────────────────────────────────────────
draw_set_halign(fa_center);
draw_set_valign(fa_middle);
draw_set_colour(make_colour_rgb(55, 18, 95));
draw_text_transformed(W / 2 + 5, 235, "CREATURE CARETAKER", 4, 4, 0);

// ── Title ─────────────────────────────────────────────────────────────────────
draw_set_colour(make_colour_rgb(255, 215, 0));
draw_text_transformed(W / 2, 230, "CREATURE CARETAKER", 4, 4, 0);

// ── Subtitle ──────────────────────────────────────────────────────────────────
draw_set_colour(make_colour_rgb(175, 145, 215));
draw_text_transformed(W / 2, 315, "~ A Fantasy Breeding RPG ~", 2, 2, 0);

// ── Version stamp ─────────────────────────────────────────────────────────────
draw_set_halign(fa_right);
draw_set_valign(fa_bottom);
draw_set_colour(make_colour_rgb(70, 70, 100));
draw_text_transformed(W - 16, H - 12, "v0.1", 1, 1, 0);

// ── NEW GAME button ───────────────────────────────────────────────────────────
scr_draw_pixel_button(btn_cx - btn_w / 2, btn_cy - btn_h / 2, btn_w, btn_h,
                      "NEW GAME", btn_hovered, 2);

draw_set_alpha(1);
draw_set_halign(fa_left);
draw_set_valign(fa_top);

var _t     = 1 - (lifetime / max_life); // 0=start 1=end
var _alpha = 1 - _t;

switch (vfx_type) {

    // ── 0: IMPACT_CIRCLE — hit spark sprite, frame driven by lifetime ─────────
    case VFX_TYPE.IMPACT_CIRCLE:
        draw_sprite_ext(spr_vfx_hit_spark, floor(_t * 5), x, y, scale, scale, 0, col1, _alpha);
        break;

    // ── 1: SLASH_LINES — diagonal slash marks ─────────────────────────────────
    case VFX_TYPE.SLASH_LINES:
        draw_set_alpha(_alpha);
        draw_set_color(col1);
        for (var _i = 0; _i < 3; _i++) {
            var _a   = angle + (_i - 1) * 20;
            var _len = radius * (0.5 + _t * 0.5);
            draw_line_width(
                x + lengthdir_x(4, _a + 90),
                y + lengthdir_y(4, _a + 90),
                x + lengthdir_x(_len, _a) + lengthdir_x(4, _a + 90),
                y + lengthdir_y(_len, _a) + lengthdir_y(4, _a + 90),
                3
            );
        }
        draw_set_alpha(1);
        break;

    // ── 2: RING_PULSE — expanding ring (howl/screech/self buffs) ──────────────
    case VFX_TYPE.RING_PULSE:
        draw_set_alpha(_alpha * 0.8);
        draw_set_color(col1);
        draw_circle(x, y, radius * _t, true);
        draw_set_color(col2);
        draw_circle(x, y, radius * _t * 0.85, true);
        draw_set_alpha(1);
        break;

    // ── 3: DUST_PUFF — particles radiating outward (dash/charge) ──────────────
    case VFX_TYPE.DUST_PUFF:
        draw_set_alpha(_alpha);
        for (var _i = 0; _i < 6; _i++) {
            var _a = (_i / 6) * 360 + angle;
            var _d = radius * _t;
            draw_set_color(col1);
            draw_circle(
                x + lengthdir_x(_d, _a),
                y + lengthdir_y(_d, _a),
                4 * (1 - _t), false
            );
        }
        draw_set_alpha(1);
        break;

    // ── 4: GLOW_PULSE — soft glow around creature (Overcharge/Iron Shell) ─────
    case VFX_TYPE.GLOW_PULSE:
        draw_set_alpha(_alpha * 0.5);
        draw_set_color(col1);
        draw_circle(x, y, radius * (1 + sin(_t * pi) * 0.3), false);
        draw_set_alpha(1);
        break;

    // ── 5: CONE_SPRAY — fan of lines in a direction (Wing Dust) ───────────────
    case VFX_TYPE.CONE_SPRAY:
        draw_set_alpha(_alpha);
        draw_set_color(col1);
        for (var _i = 0; _i < 7; _i++) {
            var _a   = angle - 30 + (_i / 6) * 60;
            var _len = radius * (0.4 + _t * 0.6) * (0.7 + random(0.3));
            draw_line_width(x, y,
                x + lengthdir_x(_len, _a),
                y + lengthdir_y(_len, _a), 2);
        }
        draw_set_alpha(1);
        break;
}

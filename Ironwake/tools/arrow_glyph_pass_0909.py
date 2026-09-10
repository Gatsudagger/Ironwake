"""09-09 (M): replace the typed '->' / '<-' arrows in NPC screens and menus with a
drawn arrow glyph. Adds ui_draw_text_arrows() to scr_ui (a draw_text that renders
'->' / '<-' as ui_draw_arrow_glyph, honoring the current font/halign/valign/color)
and re-points every single-line draw_text whose string carries an arrow at it.
Idempotent: skips lines already converted. Run from anywhere.
"""
import os, re
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UI = os.path.join(ROOT, "scripts", "scr_ui", "scr_ui.gml")

HELPER = '''

// =============================================================================
// ui_draw_text_arrows(x, y, str) - draw_text that renders a typed "->" / "<-"
// as a DRAWN arrow glyph (09-09, M: "there are '->' in various npc screens and
// menu systems" - replace the keyboard symbols with proper visuals). Honors
// the current font, halign, valign, color and alpha, so it is a drop-in for
// draw_text at any single-line site. Strings without an arrow draw as before.
// =============================================================================
function ui_draw_text_arrows(_x, _y, _s) {
    _s = string(_s);
    if (string_pos("->", _s) == 0 && string_pos("<-", _s) == 0) { draw_text(_x, _y, _s); return; }
    var _parts = [], _kinds = [], _cur = "";
    var _n = string_length(_s), _i = 1;
    while (_i <= _n) {
        var _two = string_copy(_s, _i, 2);
        if (_two == "->" || _two == "<-") {
            array_push(_parts, _cur); array_push(_kinds, 0);
            array_push(_parts, "");   array_push(_kinds, (_two == "->") ? 1 : -1);
            _cur = ""; _i += 2;
        } else { _cur += string_char_at(_s, _i); _i++; }
    }
    array_push(_parts, _cur); array_push(_kinds, 0);
    var _fh = string_height("A");
    var _aw = round(_fh * 0.95);                       // the glyph's slot width
    var _tot = 0;
    for (var _k = 0; _k < array_length(_parts); _k++) _tot += (_kinds[_k] == 0) ? string_width(_parts[_k]) : _aw;
    var _ha = draw_get_halign(), _va = draw_get_valign();
    var _x0 = _x;
    if (_ha == fa_center) _x0 = _x - _tot * 0.5; else if (_ha == fa_right) _x0 = _x - _tot;
    var _cy = _y;
    if (_va == fa_top) _cy = _y + _fh * 0.5; else if (_va == fa_bottom) _cy = _y - _fh * 0.5;
    var _col = draw_get_color();
    var _len = _aw * 0.78, _thick = max(2, round(_fh * 0.11));
    draw_set_halign(fa_left);
    for (var _k = 0; _k < array_length(_parts); _k++) {
        if (_kinds[_k] == 0) {
            if (_parts[_k] != "") draw_text(_x0, _y, _parts[_k]);
            _x0 += string_width(_parts[_k]);
        } else {
            var _acx = _x0 + _aw * 0.5;
            if (_kinds[_k] > 0) {
                ui_draw_arrow_glyph(_acx, _cy, _len, _thick, _col);
            } else {   // left arrow: the glyph mirrored
                var _head = _thick * 2.6;
                var _l0 = _acx - _len * 0.5, _l1 = _acx + _len * 0.5;
                draw_set_color(_col);
                draw_rectangle(_l0 + _head, _cy - _thick * 0.5, _l1, _cy + _thick * 0.5, false);
                draw_triangle(_l0 + _head, _cy - _head * 0.85, _l0 + _head, _cy + _head * 0.85, _l0, _cy, false);
            }
            _x0 += _aw;
        }
    }
    draw_set_halign(_ha);
    draw_set_color(_col);
}
'''

# (file, 1-based line, required substring) -> swap draw_text( for ui_draw_text_arrows( on that line
SITES = [
    ("scripts/scr_ui/scr_ui.gml", 3131,  "journal_quest_reward_text"),
    ("scripts/scr_ui/scr_ui.gml", 3895,  "journal_quest_reward_text"),
    ("scripts/scr_ui/scr_ui.gml", 5128,  "_fg_txt"),
    ("scripts/scr_ui/scr_ui.gml", 7007,  "_row.tag"),
    ("scripts/scr_ui/scr_ui.gml", 11992, "_fsr.right"),
    ("scripts/scr_ui/scr_ui.gml", 13562, "->"),
    ("scripts/scr_ui/scr_ui.gml", 14116, '"->"'),
    ("scripts/scr_ui/scr_ui.gml", 14500, '"->"'),
    ("scripts/scr_ui/scr_ui.gml", 17538, "draw_text(_list_x2 - 24, _tyc - 11"),
    ("scripts/scr_ui/scr_ui.gml", 17566, "->"),
    ("scripts/scr_ui/scr_ui.gml", 17589, "->"),
    ("scripts/scr_ui/scr_ui.gml", 18124, "->"),
    ("scripts/scr_ui/scr_ui.gml", 18320, '"->"'),
    ("scripts/scr_ui/scr_ui.gml", 18359, '"->"'),
    ("scripts/scr_ui/scr_ui.gml", 19875, '"->"'),
    ("scripts/scr_ui/scr_ui.gml", 21301, "draw_text(1330, _hry + 12"),
    ("scripts/scr_ui/scr_ui.gml", 14990, "draw_text((_x0 + _x1) / 2, (_y0 + _y1) / 2 + 1, _txt)"),   # ui_confirm_button label
    ("objects/obj_hub_controller/Draw_64.gml", 1512, "draw_text(_fx_x1 + (_fx_x2 - _fx_x1) / 2, _fxy,"),
    ("objects/obj_hub_controller/Draw_64.gml", 3269, "->"),
    ("objects/obj_combat_controller/Draw_64.gml", 1680, "->"),
]
files = {}
def load(p):
    fp = os.path.join(ROOT, p)
    if fp not in files:
        files[fp] = open(fp, encoding="utf-8", newline="").read().split("\n")
    return fp
for p, ln, need in SITES:
    fp = load(p); lines = files[fp]
    L = lines[ln - 1]
    if "ui_draw_text_arrows(" in L:
        print("skip (done)", p, ln); continue
    if need not in L or "draw_text(" not in L:
        print("MISMATCH", p, ln, "|", L.strip()[:90]); continue
    lines[ln - 1] = L.replace("draw_text(", "ui_draw_text_arrows(", 1)
    print("ok", p, ln)
# draw_text_ext site 14036 (one line, centered): swap to the helper (no wrap needed)
fp = load("scripts/scr_ui/scr_ui.gml"); lines = files[fp]
L = lines[14035]
if "draw_text_ext(960, _bp_y0 + 78," in L:
    lines[14035] = L.replace("draw_text_ext(960, _bp_y0 + 78,", "ui_draw_text_arrows(960, _bp_y0 + 78,")
    # drop the trailing ", -1, <w>)" args of draw_text_ext on the closing line
    for j in range(14036, 14042):
        if re.search(r",\s*-1,\s*[^,()]+\)\s*;\s*$", lines[j]):
            lines[j] = re.sub(r",\s*-1,\s*[^,()]+\)\s*;\s*$", ");", lines[j]); print("ok ext ->", j + 1); break
    else:
        print("WARN: could not trim draw_text_ext args after 14036")
src = "\n".join(lines)
if "function ui_draw_text_arrows" not in src:
    src = src.rstrip("\n") + HELPER
for fp, ls in files.items():
    open(fp, "w", encoding="utf-8", newline="").write(src if fp.endswith("scr_ui.gml") else "\n".join(ls))
print("done")

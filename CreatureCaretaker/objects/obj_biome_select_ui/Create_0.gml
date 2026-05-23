selected_biome = 0;

card_w   = 230;
card_h   = 360;
card_gap = 12;
var _total_w = BIOME.COUNT * card_w + (BIOME.COUNT - 1) * card_gap;
cards_x0 = (room_width  - _total_w) / 2;
cards_y  = 100;

btn_cx      = room_width / 2;
btn_cy      = 660;
btn_w       = 340;
btn_h       = 56;
btn_hovered = false;

input_name      = "";
keyboard_string = "";

btn_w  = 280;
btn_h  = 52;
btn_cx = room_width / 2;
btn_cy = room_height - 80;
btn_hovered = false;

focused_field = 0;

// Appearance selection state
skin_sel  = 0;
hair_sel  = 0;
style_sel = 0;
eye_sel   = 0;
body_sel  = 0;
shirt_sel = 0;
pants_sel = 0;
boots_sel = 0;
item_sel  = 0;

skin_cols = [
    make_colour_rgb(255, 220, 185),
    make_colour_rgb(235, 190, 145),
    make_colour_rgb(198, 145, 100),
    make_colour_rgb(140, 90,  50 ),
    make_colour_rgb(80,  50,  30 ),
    make_colour_rgb(65,  35,  15 ),
];

hair_cols = [
    make_colour_rgb(40,  30,  20 ),
    make_colour_rgb(100, 65,  30 ),
    make_colour_rgb(185, 135, 55 ),
    make_colour_rgb(215, 65,  25 ),
    make_colour_rgb(210, 200, 180),
    make_colour_rgb(105, 60,  135),
    make_colour_rgb(50,  80,  180),
    make_colour_rgb(140, 50,  160),
];

eye_cols = [
    make_colour_rgb(60,  40,  20 ),
    make_colour_rgb(70,  100, 60 ),
    make_colour_rgb(60,  80,  140),
    make_colour_rgb(100, 60,  40 ),
    make_colour_rgb(80,  80,  80 ),
    make_colour_rgb(140, 60,  60 ),
];

style_names = ["Short", "Long", "Braids", "Mohawk", "Curly", "Shaved"];
body_names  = ["Slim", "Broad"];
shirt_names = ["Plain White", "Blue Tunic", "Green Vest", "Red Shirt", "Dark Cloak", "Striped"];
pants_names = ["Brown Trousers", "Dark Pants", "Green Shorts", "Patched Jeans", "Black Pants"];
boots_names = ["Simple Boots", "Sandals", "Cloth Wrap", "Dark Boots", "Bare Feet"];
item_names  = ["Ranger Boots", "Handler Gloves", "Scholar's Hat", "Hardened Hauberk"];
item_slots  = ["Boots", "Gloves", "Head", "Chest"];
item_descs  = [
    "Move 10% faster. Creatures\ngain +5% AGI on AGI gains.",
    "Bond rate +10%. All stat\ngains increased by +1%.",
    "Creatures gain +5% XP.\nINT gains increased by +5%.",
    "Active creature +10% VIT.\nVIT gains increased by +5%.",
];
item_cols = [
    make_colour_rgb(120, 80,  40 ),
    make_colour_rgb(30,  30,  30 ),
    make_colour_rgb(30,  50,  120),
    make_colour_rgb(70,  50,  30 ),
];

hair_sprites  = [spr_hair_short, spr_hair_long, spr_hair_braids, spr_hair_mohawk, spr_hair_curly, spr_hair_shaved];
shirt_sprites = [spr_shirt_white, spr_shirt_blue, spr_shirt_green, spr_shirt_red, spr_shirt_cloak, spr_shirt_striped];
pants_sprites = [spr_pants_brown, spr_pants_navy, spr_pants_shorts, spr_pants_patched, spr_pants_black];
boots_sprites = [spr_boots_brown, spr_boots_sandals, spr_boots_cloth, spr_boots_dark, spr_boots_bare];
item_sprites  = [spr_item_ranger_boots, spr_item_work_gloves, spr_item_wizard_hat, spr_item_chainmail_vest];

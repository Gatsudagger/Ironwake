if (!instance_exists(obj_game_controller)) {
	instance_create_layer(0, 0, "Instances", obj_game_controller);
}

selected_creature = 0;

// Card layout
card_w   = 240;
card_h   = 340;
card_gap = 14;
var total_w  = CREATURE.COUNT * card_w + (CREATURE.COUNT - 1) * card_gap;
cards_x0 = (room_width - total_w) / 2;
cards_y  = 120;

// Creature description lines (3 per creature)
creature_desc = [
	["Swift pursuit hunter",    "High STR & Stamina",  "Tenacious tracker"  ],  // Harehound
	["Mystic amphibian",        "High INT & DEX",      "Arcane versatility" ],  // Amphibi
	["Stone-armored tank",      "Highest STR & DEF",   "Unyielding wall"    ],  // Bouldeer
	["Shadow serpent",          "High AGI & INT",      "Swift arcane striker"],  // Salapent
	["Aerial predator",         "High AGI & DEX",      "Precision & speed"  ],  // Raptowl
];

// Icon accent colours per creature
icon_col = [
	make_colour_rgb(170, 118, 64),   // Harehound  — warm brown
	make_colour_rgb(56,  148, 116),  // Amphibi    — teal
	make_colour_rgb(128, 112, 90),   // Bouldeer   — stone
	make_colour_rgb(88,  60,  148),  // Salapent   — purple
	make_colour_rgb(148, 118, 48),   // Raptowl    — gold
];

// Stat bar definitions
stat_keys = [STAT_STRENGTH, STAT_AGILITY, STAT_DEXTERITY, STAT_STAMINA, STAT_INTELLECT, STAT_WILLPOWER, STAT_DEFENSE];
stat_labels = ["STR", "AGI", "DEX", "STA", "INT", "WIL", "DEF"];
stat_col = [
	make_colour_rgb(220, 72,  72 ),  // STR — red
	make_colour_rgb(72,  210, 110),  // AGI — green
	make_colour_rgb(72,  170, 220),  // DEX — blue
	make_colour_rgb(220, 155, 72 ),  // STA — orange
	make_colour_rgb(175, 72,  220),  // INT — purple
	make_colour_rgb(220, 215, 72 ),  // WIL — yellow
	make_colour_rgb(130, 130, 200),  // DEF — steel
];

// Choose button
btn_cx = room_width / 2;
btn_cy = 650;
btn_w  = 340;
btn_h  = 56;
btn_hovered = false;

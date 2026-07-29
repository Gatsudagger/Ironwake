// Only one controller may exist; later duplicates (from room reloads) self-destruct.
if (instance_number(obj_game_controller) > 1) {
	instance_destroy();
	exit;
}

scr_creature_data_init();
scr_creature_skills_init();
scr_task_data_init();
scr_biome_data_init();
scr_combat_moves_init();
scr_item_system_init();

// Test inventory
scr_inventory_add(0, 3); // 3x Herb Pouch
scr_inventory_add(1, 2); // 2x Stamina Leaf
scr_inventory_add(2, 1); // 1x Rage Tonic
global.hotbar_items = [0, 1, 2];

// Player identity
player_name      = "";
skin_tone        = 0;
hair_color       = 0;
hair_style       = 0;
eye_color        = 0;
body_type        = 0;
shirt_style      = 0;
pants_style      = 0;
boots_style      = 0;
starting_item    = 0;

// Setup selections
starter_creature = -1;
biome_id         = -1;
var _ground_cols = [
    make_colour_rgb(180,190,200), // Alpine Forest - snow grey
    make_colour_rgb(50, 110, 50), // Temperate Forest - green
    make_colour_rgb(20,  55, 20), // Jungle - dark green
    make_colour_rgb(180,155, 85), // Oasis - sandy
    make_colour_rgb(45,  40, 60), // Mountain Valley - dark purple
];
if (biome_id >= 0 && biome_id < array_length(_ground_cols)) {
    room_set_background_colour(rm_ranch, _ground_cols[biome_id], true);
}

// Populated by scr_biome_bonus_init after biome is chosen
biome_bonus_state = undefined;

// Creature stamina (seeded from STAT_STAMINA after starter is known)
creature_stamina     = 0;
creature_stamina_max = 0;

// Creature roster — filled when starter is chosen
creature_roster = [];
global.creature_roster = creature_roster;

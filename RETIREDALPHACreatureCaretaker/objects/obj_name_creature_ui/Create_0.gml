input_name       = "";
max_length       = 12;
cursor_timer     = 0;
creature_species = obj_game_controller.starter_creature.species;
done             = false;

keyboard_string = "";  // clear any buffered keys from previous rooms

portrait_sprites = [
    spr_portrait_harehound,
    spr_portrait_amphibi,
    spr_portrait_bouldeer,
    spr_portrait_salapent,
    spr_portrait_raptowl,
    spr_portrait_thornback,
    spr_portrait_glowmoth,
];

fantasy_names = [
    "Brisken", "Lumara", "Vayne", "Thicket", "Zorael",
    "Pebble",  "Skiver", "Mira",  "Crux",    "Finch",
];

// Panel layout — shared between Step and Draw
panel_x = 683;
panel_y = room_height * 0.5 - 180;
panel_w = 580;
panel_h = 360;

btn_cx      = panel_x + panel_w * 0.5;
btn_cy      = panel_y + panel_h - 70;
btn_w       = 220;
btn_h       = 48;
btn_hovered = false;

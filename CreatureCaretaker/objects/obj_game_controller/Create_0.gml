// Only one controller may exist; later duplicates (from room reloads) self-destruct.
if (instance_number(obj_game_controller) > 1) {
	instance_destroy();
	exit;
}

scr_creature_data_init();
scr_creature_skills_init();
scr_biome_data_init();

// Player identity
player_name      = "";
skin_tone        = 0;
hair_color       = 0;
hair_style       = 0;

// Setup selections
starter_creature = -1;
biome_id         = -1;

// Populated by scr_biome_bonus_init after biome is chosen
biome_bonus_state = undefined;

// Creature stamina (seeded from STAT_STAMINA after starter is known)
creature_stamina     = 0;
creature_stamina_max = 0;

// Creature roster — filled when starter is chosen
creature_roster = [];

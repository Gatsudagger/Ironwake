/// @desc Populates global.combat_state and transitions to rm_combat.
/// @param {Struct} player_creature   Creature instance struct from creature_roster
/// @param {Struct} enemy_creature    Creature instance struct (wanderer or wild)
/// @param {real}   biome_id          BIOME enum value for the arena background
function scr_combat_init(player_creature, enemy_creature, biome_id) {
	global.combat_state.active          = true;
	global.combat_state.player_creature = player_creature;
	global.combat_state.enemy_creature  = enemy_creature;
	global.combat_state.biome_id        = biome_id;
	global.combat_state.result          = "";
	room_goto(rm_combat);
}

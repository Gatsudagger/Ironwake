var _biome = obj_game_controller.biome_id;
switch (_biome) {
    case BIOME.ALPINE_FOREST:    sprite_index = spr_tree_spruce; break;
    case BIOME.TEMPERATE_FOREST: sprite_index = spr_tree_oak;    break;
    case BIOME.JUNGLE:           sprite_index = spr_tree_jungle;  break;
    case BIOME.OASIS:            sprite_index = spr_tree_palm;    break;
    case BIOME.MOUNTAIN_VALLEY:  sprite_index = spr_tree_spruce; break;
    default:                     sprite_index = spr_tree_oak;    break;
}
depth = -(y);

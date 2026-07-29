/// @desc Enforces a floor of 0 on all 8 base stats (no ceiling — diminishing returns handle scaling).
/// @param {Struct} creature_struct
/// @returns {Struct}
function clamp_base_stats(creature_struct) {
    var _stats = [
        STAT_STRENGTH, STAT_AGILITY, STAT_DEXTERITY, STAT_STAMINA,
        STAT_INTELLECT, STAT_WILLPOWER, STAT_DEFENSE, STAT_VITALITY,
    ];
    var _i = 0;
    repeat (array_length(_stats)) {
        var _key = "base_" + _stats[_i];
        creature_struct[$ _key] = max(0, creature_struct[$ _key]);
        _i++;
    }
    return creature_struct;
}

/// @desc Clamps all 8 bonus stats on a creature struct to [0, biome cap].
///       Requires scr_biome_data_init() to have been called at game start.
///       If biome_id is out of range (no biome assigned), bonus stats are left unchanged.
/// @param {Struct} creature_struct
/// @returns {Struct}
function clamp_bonus_stats(creature_struct) {
    var _biome_id = creature_struct.biome;
    if (_biome_id < 0 || _biome_id >= BIOME.COUNT) return creature_struct;
    var _cap = scr_biome_get_data(_biome_id).cap_per_stat;
    var _stats = [
        STAT_STRENGTH, STAT_AGILITY, STAT_DEXTERITY, STAT_STAMINA,
        STAT_INTELLECT, STAT_WILLPOWER, STAT_DEFENSE, STAT_VITALITY,
    ];
    var _i = 0;
    repeat (array_length(_stats)) {
        var _key = "bonus_" + _stats[_i];
        creature_struct[$ _key] = clamp(creature_struct[$ _key], 0, _cap);
        _i++;
    }
    return creature_struct;
}

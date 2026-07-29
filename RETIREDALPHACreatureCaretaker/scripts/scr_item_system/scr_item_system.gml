enum ITEM_TIER {
	COMMON,
	UNCOMMON,
	RARE,
}

enum ITEM_USE {
	ANY,
	COMBAT_ONLY,
	OVERWORLD_ONLY,
}

/// @desc Populates global.item_data with all 13 item definitions.
///       Also initialises global.inventory and global.hotbar_items.
///       Call once at game start after scr_combat_moves_init().
function scr_item_system_init() {

	global.item_data = array_create(13);

	// ── INDEX 0: Herb Pouch ────────────────────────────────────────────────────
	global.item_data[0] = {
		id:           0,
		name:         "Herb Pouch",
		description:  "Restores 30% max VIT",
		tier:         ITEM_TIER.COMMON,
		use:          ITEM_USE.ANY,
		effect_type:  "heal_vit",
		effect_value: 0.30,
		effect_stat:  "",
		duration:     0,
		max_stack:    5,
		icon_col:     make_colour_rgb(80, 200, 80),
	};

	// ── INDEX 1: Stamina Leaf ─────────────────────────────────────────────────
	global.item_data[1] = {
		id:           1,
		name:         "Stamina Leaf",
		description:  "Restores 50% max stamina",
		tier:         ITEM_TIER.COMMON,
		use:          ITEM_USE.ANY,
		effect_type:  "heal_stamina",
		effect_value: 0.50,
		effect_stat:  "",
		duration:     0,
		max_stack:    5,
		icon_col:     make_colour_rgb(60, 160, 220),
	};

	// ── INDEX 2: Rage Tonic ───────────────────────────────────────────────────
	global.item_data[2] = {
		id:           2,
		name:         "Rage Tonic",
		description:  "Next 5 moves deal +40% damage",
		tier:         ITEM_TIER.UNCOMMON,
		use:          ITEM_USE.COMBAT_ONLY,
		effect_type:  "buff_damage",
		effect_value: 0.40,
		effect_stat:  "",
		duration:     5,
		max_stack:    3,
		icon_col:     make_colour_rgb(220, 80, 40),
	};

	// ── INDEX 3: Iron Bark ────────────────────────────────────────────────────
	global.item_data[3] = {
		id:           3,
		name:         "Iron Bark",
		description:  "+50% DEF for 10 seconds",
		tier:         ITEM_TIER.UNCOMMON,
		use:          ITEM_USE.COMBAT_ONLY,
		effect_type:  "buff_def",
		effect_value: 0.50,
		effect_stat:  "",
		duration:     600,
		max_stack:    3,
		icon_col:     make_colour_rgb(140, 140, 180),
	};

	// ── INDEX 4: Swift Root ───────────────────────────────────────────────────
	global.item_data[4] = {
		id:           4,
		name:         "Swift Root",
		description:  "+40% movement speed for 8 seconds",
		tier:         ITEM_TIER.UNCOMMON,
		use:          ITEM_USE.COMBAT_ONLY,
		effect_type:  "buff_speed",
		effect_value: 0.40,
		effect_stat:  "",
		duration:     480,
		max_stack:    3,
		icon_col:     make_colour_rgb(220, 220, 60),
	};

	// ── INDEX 5–12: Rare stat shards ──────────────────────────────────────────
	var _shards = [
		{ name: "Shard of Might",     stat: STAT_STRENGTH   },   // 5
		{ name: "Shard of Wind",      stat: STAT_AGILITY    },   // 6
		{ name: "Shard of Edge",      stat: STAT_DEXTERITY  },   // 7
		{ name: "Shard of Endurance", stat: STAT_STAMINA    },   // 8
		{ name: "Shard of Mind",      stat: STAT_INTELLECT  },   // 9
		{ name: "Shard of Will",      stat: STAT_WILLPOWER  },   // 10
		{ name: "Shard of Iron",      stat: STAT_DEFENSE    },   // 11
		{ name: "Shard of Life",      stat: STAT_VITALITY   },   // 12
	];
	for (var _i = 0; _i < 8; _i++) {
		global.item_data[5 + _i] = {
			id:           5 + _i,
			name:         _shards[_i].name,
			description:  "+5 " + _shards[_i].stat + " (permanent)",
			tier:         ITEM_TIER.RARE,
			use:          ITEM_USE.ANY,
			effect_type:  "perm_stat",
			effect_value: 5,
			effect_stat:  _shards[_i].stat,
			duration:     0,
			max_stack:    1,
			icon_col:     make_colour_rgb(255, 215, 0),
		};
	}

	// ── Inventory and hotbar ───────────────────────────────────────────────────
	global.inventory     = [];          // array of {item_id, quantity} — max 20 slots
	global.hotbar_items  = [-1, -1, -1]; // inventory slot indices for combat hotbar
}

// ── Inventory helpers ──────────────────────────────────────────────────────────

/// @desc Adds quantity of item_id to inventory, stacking if possible.
/// @param {real}   item_id    Index into global.item_data
/// @param {real}   quantity   Amount to add
/// @returns {bool} true if added, false if inventory full
function scr_inventory_add(item_id, quantity) {
	var _item = global.item_data[item_id];
	// Try to stack onto an existing slot
	for (var _i = 0; _i < array_length(global.inventory); _i++) {
		var _slot = global.inventory[_i];
		if (_slot.item_id == item_id && _slot.quantity < _item.max_stack) {
			_slot.quantity = min(_item.max_stack, _slot.quantity + quantity);
			return true;
		}
	}
	// New slot
	if (array_length(global.inventory) < 20) {
		array_push(global.inventory, { item_id: item_id, quantity: min(_item.max_stack, quantity) });
		return true;
	}
	return false;
}

/// @desc Uses one of an item from inv_slot, applying its effect to target_creature.
///       target_creature must be an obj_combat_player or obj_combat_enemy instance.
///       Decrements quantity and removes the slot if it hits 0, shifting hotbar refs.
/// @param {real}        inv_slot         Index into global.inventory
/// @param {Id.Instance} target_creature  Combat instance to receive the effect
/// @returns {bool} true on success
function scr_inventory_use(inv_slot, target_creature) {
	if (inv_slot < 0 || inv_slot >= array_length(global.inventory)) return false;
	var _entry = global.inventory[inv_slot];
	var _item  = global.item_data[_entry.item_id];

	with (target_creature) {
		var _eff = _item.effect_type;
		var _val = _item.effect_value;
		var _dur = _item.duration;

		if (_eff == "heal_vit") {
			vitality = min(vitality_max, vitality + floor(vitality_max * _val));
		} else if (_eff == "heal_stamina") {
			combat_stamina = min(combat_stamina_max, combat_stamina + floor(combat_stamina_max * _val));
		} else if (_eff == "buff_damage") {
			damage_mult       = 1 + _val;
			damage_mult_moves = _dur;
		} else if (_eff == "buff_def") {
			def_buff_timer = _dur;
			def_buff_value = _val;
		} else if (_eff == "buff_speed") {
			speed_buff_timer = _dur;
			speed_buff_value = _val;
		} else if (_eff == "perm_stat") {
			creature[$ "base_" + _item.effect_stat] += _val;
		}
	}

	_entry.quantity--;
	if (_entry.quantity <= 0) {
		array_delete(global.inventory, inv_slot, 1);
		// Shift or clear hotbar references that pointed at this slot
		for (var _h = 0; _h < 3; _h++) {
			if (global.hotbar_items[_h] == inv_slot) {
				global.hotbar_items[_h] = -1;
			} else if (global.hotbar_items[_h] > inv_slot) {
				global.hotbar_items[_h]--;
			}
		}
	}
	return true;
}

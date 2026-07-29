function scr_get_bond_level(bond) {
	if (bond >= 50) return 5;
	if (bond >= 35) return 4;
	if (bond >= 20) return 3;
	if (bond >= 10) return 2;
	if (bond >= 5)  return 1;
	return 0;
}

function scr_get_bond_label(bond) {
	var _lvl = scr_get_bond_level(bond);
	switch (_lvl) {
		case 0: return "Stranger";
		case 1: return "Acquainted";
		case 2: return "Familiar";
		case 3: return "Trusted";
		case 4: return "Bonded";
		case 5: return "Soulbound";
	}
	return "Unknown";
}

function scr_get_bond_xp_mult(bond) {
	// Level 1+: +5% XP
	return (scr_get_bond_level(bond) >= 1) ? 1.05 : 1.0;
}

function scr_get_bond_stat_bonus(bond) {
	// Level 2+: +3 to all stat gains
	return (scr_get_bond_level(bond) >= 2) ? 3 : 0;
}

function scr_get_bond_stamina_mult(bond) {
	// Level 3+: +25% stamina regen
	return (scr_get_bond_level(bond) >= 3) ? 1.25 : 1.0;
}

function scr_get_bond_damage_mult(bond) {
	// Level 4+: +10% damage
	return (scr_get_bond_level(bond) >= 4) ? 1.10 : 1.0;
}

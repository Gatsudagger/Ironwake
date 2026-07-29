enum VFX_TYPE {
	IMPACT_CIRCLE,  // 0 — expanding circle, fades out
	SLASH_LINES,    // 1 — diagonal slash marks
	RING_PULSE,     // 2 — expanding ring (howl / screech / buffs)
	DUST_PUFF,      // 3 — particles radiating outward (dash / charge)
	GLOW_PULSE,     // 4 — soft glow (Overcharge / Iron Shell)
	CONE_SPRAY,     // 5 — fan of lines in a direction (Wing Dust)
	COUNT,
}

/// @desc Creates a VFX instance at a world position with all parameters set.
/// @param {real}  vfx_type   VFX_TYPE enum value
/// @param {real}  px         World x position
/// @param {real}  py         World y position
/// @param {real}  _col1      Primary colour
/// @param {real}  _col2      Secondary colour
/// @param {real}  _radius    Effect radius in pixels
/// @param {real}  _lifetime  Duration in steps
/// @param {real}  _angle     Direction angle in degrees
/// @returns {Id.Instance}
function scr_spawn_vfx(vfx_type, px, py, _col1, _col2, _radius, _lifetime, _angle) {
	var _inst       = instance_create_layer(px, py, "Instances", obj_combat_vfx);
	_inst.vfx_type  = vfx_type;
	_inst.lifetime  = _lifetime;
	_inst.max_life  = _lifetime;
	_inst.radius    = _radius;
	_inst.col1      = _col1;
	_inst.col2      = _col2;
	_inst.angle     = _angle;
	return _inst;
}

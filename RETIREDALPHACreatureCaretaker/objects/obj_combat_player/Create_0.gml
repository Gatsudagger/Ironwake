depth = 0;
creature   = global.combat_state.player_creature;
species    = creature.species;
spd        = 3;
facing     = WALK_RIGHT;

var _tmpl  = global.creature_data[species];
walk_sprites = _tmpl.walk_sprites;

vitality     = creature.base_vitality * 5;
vitality_max = vitality;

// Cooldown timers for each of the 3 moves (counts down in steps)
cooldown   = [0, 0, 0];

// Active buff/debuff list — each entry: {base_effect, duration, timer, is_buff}
active_buffs = [];

// Knockback / stun state
knockback_vx  = 0;
knockback_vy  = 0;
knockback_dur = 0;
stun_dur      = 0;
slow_factor   = 1.0;
slow_dur      = 0;
poison_tick   = 0;
poison_dur    = 0;

// Next-hit multiplier (Overcharge)
next_hit_mult = 1.0;

anim_frame    = 0;
anim_speed    = 0.15;
hit_flash     = 0;

combat_stamina      = creature.base_stamina * 3;
combat_stamina_max  = combat_stamina;
stamina_regen_timer = 0;

// Item buff state
damage_mult        = 1.0;
damage_mult_moves  = 0;
def_buff_timer     = 0;
def_buff_value     = 0;
speed_buff_timer   = 0;
speed_buff_value   = 0;

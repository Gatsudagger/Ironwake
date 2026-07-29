depth = 0;
creature   = global.combat_state.enemy_creature;
species    = creature.species;
spd        = 2;
facing     = WALK_LEFT;

var _tmpl  = global.creature_data[species];
walk_sprites = _tmpl.walk_sprites;

vitality     = creature.base_vitality * 5;
vitality_max = vitality;

cooldown   = [0, 0, 0];
active_buffs = [];

knockback_vx  = 0;
knockback_vy  = 0;
knockback_dur = 0;
stun_dur      = 0;
slow_factor   = 1.0;
slow_dur      = 0;
poison_tick   = 0;
poison_dur    = 0;
next_hit_mult = 1.0;

anim_frame    = 0;
anim_speed    = 0.15;
hit_flash     = 0;

combat_stamina      = creature.base_stamina * 3;
combat_stamina_max  = combat_stamina;
stamina_regen_timer = 0;

// Simple AI — pick random move when cooldown allows
ai_think_timer = 0;
ai_think_rate  = 90;  // reconsider every 1.5s

// Attack telegraph
telegraphing       = false;
telegraph_timer    = 0;
telegraph_duration = 40;
pending_move_index = 0;

// =============================================================================
// scr_abilities.gml
// Ability data structures and resolution logic for Ironwake.
//
// Ability field reference:
//   name             string  - display name
//   energy_cost      int     - energy spent on cast (1-3)
//   secondary_cost   int     - Souls / Blood / Preparation spent (0 = none)
//   base_damage      int     - raw damage before mitigation (0 = no damage)
//   damage_type      int     - 0=physical, 1=elemental, 2=drain
//   base_acc         int     - flat accuracy added to hit roll; -1 = not applicable
//   guaranteed_hit   bool    - bypasses the hit roll entirely
//   crit_type        int     - 0=power(STR), 1=precision(DEX), 2=arcane(INT),
//                              3=effect(WIS), -1=no crit
//   base_crit        real    - flat crit% added to the stat-based roll (0 = no crit)
//   effect_type      string  - "none","damage","heal","shield","debuff","dot",
//                              "status","resource","passive"
//   effect_value     real    - heal amount / shield HP / debuff magnitude / etc.
//   effect_duration  int     - turns the effect lasts (0 = instant)
//   self_targeted    bool    - ability targets the caster rather than an enemy
//
// Secondary resource mapping (mirrors scr_stats class IDs):
//   Arcanist (0)     -> souls
//   Bloodwarden (1)  -> blood
//   Shadowstrider(2) -> preparation
// =============================================================================

// ---------------------------------------------------------------------------
// ability_define(...)
// Factory function - returns a fully populated ability struct.
// All Phase 1 abilities are built with this call so the shape is always
// consistent and callers never need to set fields manually.
// ---------------------------------------------------------------------------
function ability_define(
    name,
    energy_cost,
    secondary_cost,
    base_damage,
    damage_type,
    base_acc,
    guaranteed_hit,
    crit_type,
    base_crit,
    effect_type,
    effect_value,
    effect_duration,
    self_targeted
) {
    return {
        name:            name,
        energy_cost:     energy_cost,
        secondary_cost:  secondary_cost,
        base_damage:     base_damage,
        damage_type:     damage_type,
        base_acc:        base_acc,
        guaranteed_hit:  guaranteed_hit,
        crit_type:       crit_type,
        base_crit:       base_crit,
        effect_type:     effect_type,
        effect_value:    effect_value,
        effect_duration: effect_duration,
        self_targeted:   self_targeted,
    };
}

// ---------------------------------------------------------------------------
// ability_can_cast(ability, caster)
// Returns true when the caster has enough energy AND enough of their secondary
// resource to pay the ability's costs.
// Reads whichever secondary resource field exists on the caster struct.
// ---------------------------------------------------------------------------
function ability_can_cast(ability, caster) {
    // Energy check
    if (caster.energy < ability.energy_cost) return false;

    // Secondary resource check (souls / blood / preparation)
    return ability_secondary_ok(ability, caster);
}

// ability_secondary_ok(ability, caster) - true when the caster can pay the ability's
// SECONDARY resource cost (souls / blood / preparation), ignoring AP. Split out of
// ability_can_cast so the UI can gate on the synergy-discounted AP cost
// (ability_effective_cost) while still checking the secondary resource separately.
function ability_secondary_ok(ability, caster) {
    if (ability.secondary_cost <= 0) return true;
    if      (variable_struct_exists(caster, "souls"))       return caster.souls       >= ability.secondary_cost;
    else if (variable_struct_exists(caster, "blood"))       return caster.blood       >= ability.secondary_cost;
    else if (variable_struct_exists(caster, "preparation")) return caster.preparation >= ability.secondary_cost;
    return true;
}

// ---------------------------------------------------------------------------
// ability_spend_resources(ability, caster)
// Deducts energy and secondary resource from the caster struct.
// Returns the caster (same reference) for chaining.
// Call only after ability_can_cast() returns true.
// ---------------------------------------------------------------------------
function ability_spend_resources(ability, caster) {
    caster.energy -= ability.energy_cost;

    if (ability.secondary_cost > 0) {
        if      (variable_struct_exists(caster, "souls"))       caster.souls       -= ability.secondary_cost;
        else if (variable_struct_exists(caster, "blood"))       caster.blood       -= ability.secondary_cost;
        else if (variable_struct_exists(caster, "preparation")) caster.preparation -= ability.secondary_cost;
    }

    return caster;
}

// ---------------------------------------------------------------------------
// abilities_get_loadout(class_id)
// Returns the 4-ability starting array for the given class.
// Single source of truth - used by obj_combat_controller Create and the
// character menu when displaying abilities outside combat.
// ---------------------------------------------------------------------------
function abilities_get_loadout(class_id) {
    switch (class_id) {
        case 0: return [
            global.abilities_arcanist[0],  // Soulfire
            global.abilities_arcanist[1],  // Void Drain
            global.abilities_arcanist[2],  // Arcane Burst
            global.abilities_arcanist[4],  // Blink
        ];
        case 1: return [
            global.abilities_bloodwarden[0],  // Blood Leech
            global.abilities_bloodwarden[1],  // Iron Skin
            global.abilities_bloodwarden[2],  // Gore Strike
            global.abilities_bloodwarden[3],  // Blood Surge
        ];
        case 2: return [
            global.abilities_shadowstrider[0],  // Snipe
            global.abilities_shadowstrider[1],  // Bear Trap
            global.abilities_shadowstrider[2],  // Shadow Step
            global.abilities_shadowstrider[3],  // Poison Dart
        ];
    }
    return [];
}

// =============================================================================
// PHASE 1 ABILITY LISTS
// Defined as global arrays so any system can read them by index without
// needing to own the ability data.
// =============================================================================

// -----------------------------------------------------------------------------
// ARCANIST (class_id 0)
// Secondary resource: Souls (max 10, starts at 0 each combat)
// Playstyle: build Souls on kills, spend for high-damage/utility spells.
// -----------------------------------------------------------------------------
// desc_short: one readable line shown in the list row (<=50 chars)
// desc_full:  1-2 sentences for the description box - what it does and when to use it
global.abilities_arcanist = [
    // 0: Soulfire - aggressive generator: hits hard AND builds Souls each cast.
    //    Niche: spam for damage and soul generation; pairs with Arcane Burst.
    ability_define("Soulfire",
        /*energy*/1, /*secondary*/0,
        /*damage*/15, /*dtype*/1,       // elemental
        /*acc*/85, /*guaranteed*/false,
        /*crit_type*/2, /*base_crit*/8, // arcane (INT)
        /*effect_type*/"resource", /*effect_value*/2, /*duration*/0, // +2 Souls on cast
        /*self*/false),

    // 1: Void Drain - cheap sustain: 1 AP on a 2-turn cooldown. Lower damage but heals,
    //    guaranteed, bypasses armor. Also banks 1 Soul on hit (see obj_combat_controller
    //    Step_0 hook). The cooldown is what keeps the cheap heal+Soul from being spammed.
    ability_define("Void Drain",
        /*energy*/1, /*secondary*/0,
        /*damage*/8, /*dtype*/2,        // drain - bypasses all mitigation
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/-1, /*base_crit*/0,
        /*effect_type*/"heal", /*effect_value*/8, /*duration*/0,
        /*self*/false),

    // 2: Arcane Burst - big nuke; costs a Soul, high arcane crit ceiling.
    //    §3 rework: now a true payoff - +40% damage vs a debuffed/Exposed target
    //    (rider in obj_combat_controller/Step_0). Base bumped 28->38 so a committed
    //    3-AP cast finally beats a turn of three cheap 1-AP spells.
    ability_define("Arcane Burst",
        /*energy*/3, /*secondary*/1,
        /*damage*/38, /*dtype*/1,       // elemental
        /*acc*/80, /*guaranteed*/false,
        /*crit_type*/2, /*base_crit*/12, // arcane (INT) + 2 el stacks on crit
        /*effect_type*/"damage", /*effect_value*/0, /*duration*/0,
        /*self*/false),

    // 3: Soul Harvest - passive; logic triggered by the combat engine on-kill
    ability_define("Soul Harvest",
        /*energy*/0, /*secondary*/0,
        /*damage*/0, /*dtype*/0,
        /*acc*/-1, /*guaranteed*/false,
        /*crit_type*/-1, /*base_crit*/0,
        /*effect_type*/"resource", /*effect_value*/2, /*duration*/0, // +2 souls
        /*self*/true),

    // 4: Blink - staged evasion over the next 3 incoming attacks (2-turn CD). The cast
    //    sets player.blink_charges = 3; the incoming-attack block in obj_combat_controller/
    //    Step_0 resolves it: charge 3 = guaranteed full dodge, 2 = 50% dmg taken, 1 = 25%
    //    less, then it ends. Only the first hit is a guaranteed dodge.
    ability_define("Blink",
        /*energy*/1, /*secondary*/0,
        /*damage*/0, /*dtype*/0,
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/-1, /*base_crit*/0,
        /*effect_type*/"status", /*effect_value*/2, /*duration*/2, // 2 charges; absorbs 2 attacks
        /*self*/true),

    // 5: Curse - WIS crit improves status quality; debuffs incoming damage
    ability_define("Curse",
        /*energy*/2, /*secondary*/0,
        /*damage*/0, /*dtype*/2,        // void
        /*acc*/75, /*guaranteed*/false,
        /*crit_type*/3, /*base_crit*/0, // effect (WIS) - no base_crit, formula uses 5+WIS*1.5
        /*effect_type*/"debuff", /*effect_value*/4, /*duration*/3, // +4 damage taken
        /*self*/false),

    // 6: Soul Shield - costs 1 Soul, absorbs 10 HP of incoming damage
    ability_define("Soul Shield",
        /*energy*/1, /*secondary*/1,
        /*damage*/0, /*dtype*/0,
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/-1, /*base_crit*/0,
        /*effect_type*/"shield", /*effect_value*/10, /*duration*/0,
        /*self*/true),

    // 7: Entropy - damage-over-time, WIS crit can upgrade stack quality
    ability_define("Entropy",
        /*energy*/2, /*secondary*/0,
        /*damage*/0, /*dtype*/2,        // void
        /*acc*/78, /*guaranteed*/false,
        /*crit_type*/3, /*base_crit*/0, // effect (WIS)
        /*effect_type*/"dot", /*effect_value*/6, /*duration*/4, // 6 dmg/turn x 4 turns
        /*self*/false),

    // 8: Rift - Soul-fuelled AoE; arcane crit adds elemental stacks to all targets
    ability_define("Rift",
        /*energy*/3, /*secondary*/2,
        /*damage*/20, /*dtype*/1,       // elemental
        /*acc*/88, /*guaranteed*/false,
        /*crit_type*/2, /*base_crit*/6, // arcane (INT)
        /*effect_type*/"damage", /*effect_value*/0, /*duration*/0, // hits all enemies
        /*self*/false),

    // 9: Soulbind - ties enemy fate to caster; reflects 40% damage for full combat
    ability_define("Soulbind",
        /*energy*/2, /*secondary*/1,
        /*damage*/6, /*dtype*/2,        // void - now lands a small hit on cast
        /*acc*/72, /*guaranteed*/false,
        /*crit_type*/3, /*base_crit*/0, // effect (WIS)
        /*effect_type*/"status", /*effect_value*/0.5, /*duration*/-1, // -1 = combat-long
        /*self*/false),
];

// Plain-English descriptions for Arcanist abilities
var _arc_d = [
    { s: "Deal 15 elemental dmg. Gain +2 Soul.",
      f: "A quick elemental blast that also fills your Soul reserve. Cheap to cast - spam it to fuel bigger spells on the next turn." },
    { s: "1 AP: 8 drain dmg, heal 8, +1 Soul. 2-turn CD.",
      f: "A guaranteed drain that heals as much as it deals and banks 1 Soul, bypassing armor entirely. Now 1 AP on a 2-turn cooldown - cheap sustain you can't spam every turn." },
    { s: "Spend 1 Soul. Deal 28 elemental dmg.",
      f: "Your big nuke. Costs 1 Soul for a massive elemental hit with a strong arcane crit chance. Save it for tough or high-HP enemies." },
    { s: "0 AP cost. Gain +2 Soul instantly.",
      f: "Costs zero AP - cast it for free and keep your other abilities available this turn. One use per turn. Save it to top off your Soul reserve before an Arcane Burst." },
    { s: "Fully dodge the next attack; soften the 2 after. 2-turn CD.",
      f: "Phase out: the next enemy attack is fully evaded automatically. The two attacks after that still land but for 50% then 25% less damage. A charge is spent per attacking enemy, so it spans a swarm. 2-turn cooldown." },
    { s: "Target takes +4 dmg from all hits for 3 turns.",
      f: "A debuff that amplifies all incoming damage to the target. Strong when you have multiple damage sources or DoTs ticking per turn." },
    { s: "Spend 1 Soul. Absorb 10 incoming dmg.",
      f: "Converts 1 Soul into a 10 HP damage buffer. Cheap protection - cast it when your Soul bar is stocked and you expect a big hit." },
    { s: "Apply poison: 6 dmg/turn for 4 turns.",
      f: "No upfront damage, but 24 total if the target lives long enough. Best on tough enemies you plan to wear down over several turns." },
    { s: "Spend 2 Souls. Deal 20 elemental dmg to all enemies.",
      f: "An AoE nuke that hits every enemy at once. High Soul cost - save it for multi-enemy fights or finishing off a weakened group." },
    { s: "Spend 1 Soul. Reflect 40% of damage taken at target.",
      f: "A combat-long bond that returns 40% of every hit you receive to the bound enemy. Best in long fights where you're taking sustained damage." },
];
for (var _i = 0; _i < 10; _i++) {
    global.abilities_arcanist[_i].desc_short = _arc_d[_i].s;
    global.abilities_arcanist[_i].desc_full  = _arc_d[_i].f;
}

// -----------------------------------------------------------------------------
// BLOODWARDEN (class_id 1)
// Secondary resource: Blood (max 10, starts at 0 each combat)
// Playstyle: tank damage, accumulate Blood through sustained hits, spend for
//            burst heals and powerful self-buffs.
// -----------------------------------------------------------------------------
global.abilities_bloodwarden = [
    // 0: Blood Leech - reliable drain + heal to sustain
    ability_define("Blood Leech",
        /*energy*/1, /*secondary*/0,
        /*damage*/10, /*dtype*/3,       // blood
        /*acc*/80, /*guaranteed*/false,
        /*crit_type*/2, /*base_crit*/6, // arcane (INT)
        /*effect_type*/"heal", /*effect_value*/8, /*duration*/0,
        /*self*/false),

    // 1: Iron Skin - flat damage reduction for 3 turns
    ability_define("Iron Skin",
        /*energy*/2, /*secondary*/0,
        /*damage*/0, /*dtype*/0,
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/-1, /*base_crit*/0,
        /*effect_type*/"shield", /*effect_value*/4, /*duration*/3, // -4 incoming dmg
        /*self*/true),

    // 2: Gore Strike - physical hit + bleed DoT; power crit spike
    ability_define("Gore Strike",
        /*energy*/2, /*secondary*/0,
        /*damage*/14, /*dtype*/0,       // physical
        /*acc*/82, /*guaranteed*/false,
        /*crit_type*/0, /*base_crit*/10, // power (STR)
        /*effect_type*/"dot", /*effect_value*/3, /*duration*/4, // bleed 3/turn x 4
        /*self*/false),

    // 3: Blood Surge - spend 2 Blood to heal immediately
    ability_define("Blood Surge",
        /*energy*/0, /*secondary*/2,
        /*damage*/0, /*dtype*/0,
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/-1, /*base_crit*/0,
        /*effect_type*/"heal", /*effect_value*/14, /*duration*/0,
        /*self*/true),

    // 4: Marrow Crush - heavy physical hit + 30% damage debuff on target.
    //    §3 rework: base bumped 18->24 so the 3-AP cast is worth a full turn.
    ability_define("Marrow Crush",
        /*energy*/3, /*secondary*/0,
        /*damage*/24, /*dtype*/0,       // physical
        /*acc*/78, /*guaranteed*/false,
        /*crit_type*/0, /*base_crit*/14, // power (STR)
        /*effect_type*/"debuff", /*effect_value*/0.3, /*duration*/3, // -30% damage dealt
        /*self*/false),

    // 5: Vital Theft - drain hit + steal 8 max HP from target for combat
    ability_define("Vital Theft",
        /*energy*/2, /*secondary*/1,
        /*damage*/8, /*dtype*/3,        // blood
        /*acc*/80, /*guaranteed*/false,
        /*crit_type*/2, /*base_crit*/8, // arcane (INT)
        /*effect_type*/"status", /*effect_value*/8, /*duration*/-1, // -8 max HP combat-long
        /*self*/false),

    // 6: Bloodthorn Aura - thorns effect; returns damage when struck
    ability_define("Bloodthorn Aura",
        /*energy*/2, /*secondary*/0,
        /*damage*/0, /*dtype*/0,
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/-1, /*base_crit*/0,
        /*effect_type*/"status", /*effect_value*/8, /*duration*/4, // reflect 8 dmg/hit x 4 turns
        /*self*/true),

    // 7: Undying - ultimate safety net; costs 3 Blood; survive lethal blow at 1 HP
    ability_define("Undying",
        /*energy*/3, /*secondary*/3,
        /*damage*/0, /*dtype*/0,
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/-1, /*base_crit*/0,
        /*effect_type*/"status", /*effect_value*/1, /*duration*/1, // survive lethal at 1 HP this turn
        /*self*/true),

    // 8: Plague Touch - WIS crit improves debuff; halves enemy healing for 5 turns
    ability_define("Plague Touch",
        /*energy*/1, /*secondary*/0,
        /*damage*/0, /*dtype*/3,        // blood
        /*acc*/76, /*guaranteed*/false,
        /*crit_type*/3, /*base_crit*/0, // effect (WIS)
        /*effect_type*/"debuff", /*effect_value*/0.5, /*duration*/5, // -50% healing received
        /*self*/false),

    // 9: Bloodfeast - every ability drains 6 HP from targets for 2 turns
    ability_define("Bloodfeast",
        /*energy*/3, /*secondary*/2,
        /*damage*/0, /*dtype*/3,        // blood
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/-1, /*base_crit*/0,
        /*effect_type*/"status", /*effect_value*/6, /*duration*/2, // +6 drain on each ability
        /*self*/true),
];

// Plain-English descriptions for Bloodwarden abilities
var _bw_d = [
    { s: "Deal 10 blood dmg. Heal 8 HP. 80% accuracy.",
      f: "Your bread-and-butter sustain skill. Blood damage scales with INT, and you heal every cast. Low energy cost - use it freely." },
    { s: "Reduce all incoming dmg by 4 for 3 turns.",
      f: "A flat damage reduction buff on a timer. Cast it before a heavy hit or telegraph - 4 damage off every incoming hit for 3 full turns." },
    { s: "Deal 14 physical dmg. Bleed: 3 dmg/turn for 4 turns.",
      f: "A melee hit that opens a bleed wound. The 12 total bleed damage adds up - strong opener on high-HP targets or bosses." },
    { s: "Spend 2 Blood. Heal 14 HP. Free action.",
      f: "A zero-energy burst heal that costs only Blood. Perfect for recovering mid-fight when your Blood reserve is stocked." },
    { s: "Deal 18 physical dmg. Target deals 30% less dmg for 3 turns.",
      f: "A heavy hit that also cuts the target's damage output. Use it on the hardest-hitting enemy to reduce the pressure on yourself." },
    { s: "Spend 1 Blood. Drain 8 HP. Reduce target max HP by 8.",
      f: "Permanently lowers the enemy's maximum HP for this combat. Combine with Gore Strike's bleed to whittle down a boss faster." },
    { s: "Return 5 dmg to each attacker per hit for 4 turns.",
      f: "A thorns buff that punishes every incoming attack. Pairs well with Iron Skin - you reduce their damage while they take damage for hitting you." },
    { s: "Spend 3 Blood. Survive one lethal hit at 1 HP this turn.",
      f: "An emergency safety net that guarantees you survive one killing blow per cast. Burn it the moment death is imminent." },
    { s: "Target heals 50% less for 5 turns.",
      f: "Neutralizes enemy healing for extended fights. Low energy cost and a wide 5-turn window - cast it early on any regenerating enemy." },
    { s: "Spend 2 Blood. Each ability also drains 6 HP for 2 turns.",
      f: "A short vampiric burst that adds a drain rider to every ability you cast for 2 turns. Stack with Blood Leech for maximum sustain." },
];
for (var _i = 0; _i < 10; _i++) {
    global.abilities_bloodwarden[_i].desc_short = _bw_d[_i].s;
    global.abilities_bloodwarden[_i].desc_full  = _bw_d[_i].f;
}

// -----------------------------------------------------------------------------
// SHADOWSTRIDER (class_id 2)
// Secondary resource: Preparation (max 10, starts 0; gains 1/turn if no trap active)
// Playstyle: build Preparation passively, spend to set traps that trigger with
//            guaranteed hits; high crit ceiling on precision abilities.
// Note: trap abilities (Bear Trap, Spike Trap, Death Snare) set trap_active=true
//       on the caster; the combat engine clears it when the trap fires.
// -----------------------------------------------------------------------------
global.abilities_shadowstrider = [
    // 0: Snipe - high base ACC + precision crit; bonus damage when target is debuffed
    //    (effect_value stores the 20 bonus damage; caller checks debuff state)
    ability_define("Snipe",
        /*energy*/1, /*secondary*/0,
        /*damage*/14, /*dtype*/0,       // physical
        /*acc*/90, /*guaranteed*/false,
        /*crit_type*/1, /*base_crit*/15, // precision (DEX)
        /*effect_type*/"damage", /*effect_value*/20, /*duration*/0, // +20 if target debuffed
        /*self*/false),

    // 1: Bear Trap - place trap (costs 1 Prep); triggers with guaranteed hit + root
    ability_define("Bear Trap",
        /*energy*/2, /*secondary*/1,
        /*damage*/16, /*dtype*/0,       // physical
        /*acc*/-1, /*guaranteed*/true,  // guaranteed on trigger
        /*crit_type*/1, /*base_crit*/8, // precision (DEX)
        /*effect_type*/"status", /*effect_value*/1, /*duration*/1, // root 1 turn
        /*self*/false),

    // 2: Shadow Step - dodge CHANCE on each of the next 3 incoming attacks (2-turn CD).
    //    Cast sets player.shadow_step_charges = 3; resolved in obj_combat_controller/Step_0.
    ability_define("Shadow Step",
        /*energy*/1, /*secondary*/0,
        /*damage*/0, /*dtype*/0,
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/-1, /*base_crit*/0,
        /*effect_type*/"status", /*effect_value*/1, /*duration*/1, // dodge next single-target
        /*self*/true),

    // 3: Poison Dart - low upfront damage; DoT does the real work.
    //    Niche: apply sustained poison at the same energy cost as Snipe.
    //    Crit bumped to 10 so it crits at a reasonable rate despite lower base damage;
    //    crit still trails Snipe (15) to preserve Snipe's identity as the precision burst.
    ability_define("Poison Dart",
        /*energy*/1, /*secondary*/0,
        /*damage*/6, /*dtype*/0,        // physical
        /*acc*/88, /*guaranteed*/false,
        /*crit_type*/1, /*base_crit*/10, // precision (DEX); was 6
        /*effect_type*/"dot", /*effect_value*/5, /*duration*/4, // poison 5/turn x 4
        /*self*/false),

    // 4: Smoke Bomb - AoE accuracy debuff; WIS crit can upgrade duration/magnitude
    ability_define("Smoke Bomb",
        /*energy*/2, /*secondary*/1,
        /*damage*/0, /*dtype*/0,
        /*acc*/-1, /*guaranteed*/false,
        /*crit_type*/3, /*base_crit*/0, // effect (WIS)
        /*effect_type*/"debuff", /*effect_value*/0.4, /*duration*/2, // -40% ACC all enemies
        /*self*/false),

    // 5: Crippling Shot - physical hit + slow and damage reduction debuff
    ability_define("Crippling Shot",
        /*energy*/2, /*secondary*/0,
        /*damage*/10, /*dtype*/0,       // physical
        /*acc*/84, /*guaranteed*/false,
        /*crit_type*/1, /*base_crit*/8, // precision (DEX)
        /*effect_type*/"debuff", /*effect_value*/0.25, /*duration*/3, // -25% dmg + slow
        /*self*/false),

    // 6: Spike Trap - heavy trap; guaranteed on trigger; bleed stacks twice
    ability_define("Spike Trap",
        /*energy*/3, /*secondary*/2,
        /*damage*/26, /*dtype*/0,       // physical
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/1, /*base_crit*/10, // precision (DEX)
        /*effect_type*/"dot", /*effect_value*/6, /*duration*/4, // bleed x2 stacks
        /*self*/false),

    // 7: Marked for Death - no damage; WIS crit upgrades mark quality
    //    effect_value = 8 bonus damage per hit; effect_duration = 4 turns / 3 hits max
    ability_define("Marked for Death",
        /*energy*/1, /*secondary*/0,
        /*damage*/0, /*dtype*/0,
        /*acc*/86, /*guaranteed*/false,
        /*crit_type*/3, /*base_crit*/0, // effect (WIS)
        /*effect_type*/"debuff", /*effect_value*/8, /*duration*/4, // +8/hit up to 3 hits or 4 turns
        /*self*/false),

    // 8: Evasive Roll - reactive: halve next hit above 10 damage; costs 2 Prep
    ability_define("Evasive Roll",
        /*energy*/0, /*secondary*/2,
        /*damage*/0, /*dtype*/0,
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/-1, /*base_crit*/0,
        /*effect_type*/"status", /*effect_value*/10, /*duration*/1, // halve hits >10 dmg
        /*self*/true),

    // 9: Death Snare - apex trap; guaranteed trigger, stun 2 turns, top precision crit
    ability_define("Death Snare",
        /*energy*/3, /*secondary*/2,
        /*damage*/32, /*dtype*/0,       // physical
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/1, /*base_crit*/14, // precision (DEX)
        /*effect_type*/"status", /*effect_value*/1, /*duration*/2, // stun 2 turns
        /*self*/false),
];

// Plain-English descriptions for Shadowstrider abilities
var _ss_d = [
    { s: "Deal 14 physical dmg. +20 bonus dmg if target is debuffed.",
      f: "High accuracy and a strong precision crit. Deals a big bonus on debuffed targets - set up Marked for Death or Smoke Bomb first, then fire." },
    { s: "Spend 1 Prep. Trap: 16 dmg + Root (melee enemy loses a turn).",
      f: "A guaranteed-hit trap that roots the target. A rooted MELEE enemy can't reach you and skips its turn - but ranged enemies still attack through it (use Death Snare's stun for those)." },
    { s: "~(50% + WIS) chance to dodge each of the next 3 attacks. 2-turn CD.",
      f: "A reactive evasion on a 1-energy budget. Each of the next 3 incoming attacks has a (50% + WIS*2)% chance - capped at 85% - to be dodged; otherwise it connects. Stun halves the odds. 2-turn cooldown. Strong against a pack." },
    { s: "Deal 6 physical dmg. Poison: 5 dmg/turn for 4 turns.",
      f: "Low upfront damage but 20 total over time. Cheap to cast - apply it early and let the poison tick while you use other abilities." },
    { s: "Spend 1 Prep. All enemies hit 40% less often for 2 turns.",
      f: "A group accuracy debuff that buys you breathing room. Cast it before a risky turn or when you need to set up traps without taking a beating." },
    { s: "Deal 10 physical dmg. Target deals 25% less dmg for 3 turns.",
      f: "A reliable hit with a lasting damage debuff. Reduces the most dangerous enemy's output for several turns - use it early." },
    { s: "Spend 2 Prep. Trap fires: 22 dmg + bleed 6/turn x 4 turns.",
      f: "Your most powerful trap. Heavy damage and a punishing bleed - the Preparation cost is worth it on elites and the boss." },
    { s: "All hits on target deal +8 bonus dmg for up to 4 turns.",
      f: "A mark that amplifies every attack landing on the target. Apply it early and then stack Snipe and traps on top to maximize the window." },
    { s: "Spend 2 Prep. Next hit above 10 dmg is halved.",
      f: "No energy cost - just Preparation. Hold it in reserve for telegraphed heavy hits. Has no effect on weak attacks below 10 damage." },
    { s: "Spend 2 Prep. Trap: 28 dmg + Stun for 2 turns.",
      f: "The apex trap. Guaranteed massive damage and a 2-turn stun that shuts down ANY enemy - melee or ranged, attacker or caster. Save your Preparation for elites and bosses." },
];
for (var _i = 0; _i < 10; _i++) {
    global.abilities_shadowstrider[_i].desc_short = _ss_d[_i].s;
    global.abilities_shadowstrider[_i].desc_full  = _ss_d[_i].f;
}


// =============================================================================
// ABILITIES EXPANSION - general pool + 3 extra abilities per class
// Gated free / Vex-gold / progression-goal (see ability_unlock_info()).
// New class abilities are appended via array_push so the indexed literals above
// and abilities_get_loadout()'s index references stay valid.
// =============================================================================

// --- GENERAL POOL: any class can slot these (selectable in every loadout) ---
global.abilities_general = [
    ability_define("Strike",          1,0,  10,0,  85,false, 1,8,  "damage",0,0,  false),
    ability_define("Field Dressing",  1,0,  0,0,   -1,true,  -1,0, "heal",14,0,   true),
    ability_define("Second Wind",     2,0,  0,0,   -1,true,  -1,0, "heal",10,0,   true),
    ability_define("Adrenaline Rush", 0,0,  0,0,   -1,true,  -1,0, "status",1,0,  true),
];
var _gen_d = [
    { s:"Deal 10 physical dmg. Reliable, cheap attack.",
      f:"A dependable physical strike any class can throw every turn. Cheap and accurate - your fallback when resources run dry." },
    { s:"Heal 14 HP. 2-turn cooldown.",
      f:"A quick 1-AP patch-up - restores 14 HP on a 2-turn cooldown (no longer once per combat). No setup, no resource; top yourself off between bigger plays." },
    { s:"Heal 10 HP and restore 1 secondary resource.",
      f:"Recovers HP and refunds 1 Soul / Blood / Preparation. Great for stretching a long fight when both bars run low." },
    { s:"+1 AP this turn (once per combat).",
      f:"Costs no AP and instantly grants an extra action point - but only once per fight. Save it for the turn you need a burst of tempo." },
];
for (var _i = 0; _i < array_length(global.abilities_general); _i++) {
    global.abilities_general[_i].desc_short = _gen_d[_i].s;
    global.abilities_general[_i].desc_full  = _gen_d[_i].f;
}

// --- ARCANIST extras (indices 10-12) ---
array_push(global.abilities_arcanist,
    ability_define("Mana Sever",  2,0,  10,2,  80,false, 2,6,  "debuff",4,3,  false),
    ability_define("Arcane Echo", 3,1,  14,1,  85,false, 2,10, "damage",0,0,  false),
    ability_define("Singularity", 3,3,  32,1,  88,false, 2,10, "damage",0,0,  false));
var _arc_x = [
    { s:"Deal 10 void dmg. Silence target 3 turns (can't cast).",
      f:"Sever the target's mana: a silenced enemy can't take spell actions for 3 turns. Shuts down casters and ranged spellcasters cold - useless on pure melee bruisers, who don't cast anyway." },
    { s:"Spend 1 Soul. Deal 14 elemental dmg, +4 per Soul held.",
      f:"An elemental echo that grows with your Soul reserve. The fuller your Souls when you cast, the harder it detonates." },
    { s:"Spend 3 Souls. Deal 32 elemental dmg. Ultimate.",
      f:"Collapse your hoarded Souls into a single devastating arcane detonation - your highest-damage finisher." },
];
for (var _i = 0; _i < 3; _i++) {
    global.abilities_arcanist[10 + _i].desc_short = _arc_x[_i].s;
    global.abilities_arcanist[10 + _i].desc_full  = _arc_x[_i].f;
}

// --- BLOODWARDEN extras (indices 10-12) ---
array_push(global.abilities_bloodwarden,
    ability_define("Sanguine Pact", 1,0,  0,0,   -1,true,  -1,0, "status",0,0,  true),
    ability_define("Bonebreaker",   3,0,  14,0,  78,false, 0,12, "debuff",5,3,  false),
    ability_define("Crimson Apex",  3,3,  22,3,  82,false, 0,12, "heal",20,0,   false));
var _bw_x = [
    { s:"Spend 8 HP to gain 3 Blood.",
      f:"Bleed yourself to fuel your Blood reserve when you need resources faster than combat provides them. Don't cast it low on HP." },
    { s:"Deal 18 physical dmg. Target takes +5 dmg for 3 turns.",
      f:"A bone-shattering blow that shreds the target's defenses, leaving them to take +5 from every follow-up. Strong elite opener." },
    { s:"Spend 3 Blood. Deal 22 blood dmg and heal 18 HP. Ultimate.",
      f:"Your apex strike - a massive blood blow that returns a huge heal on impact. Swings a losing fight back in your favor." },
];
for (var _i = 0; _i < 3; _i++) {
    global.abilities_bloodwarden[10 + _i].desc_short = _bw_x[_i].s;
    global.abilities_bloodwarden[10 + _i].desc_full  = _bw_x[_i].f;
}

// --- SHADOWSTRIDER extras (indices 10-12) ---
array_push(global.abilities_shadowstrider,
    ability_define("Flurry",        2,0,  16,0,  88,false, 1,18, "damage",0,0,  false),
    ability_define("Vanish",        1,0,  0,0,   -1,true,  -1,0, "status",1,1,  true),
    ability_define("Killing Spree", 3,2,  12,0,  86,false, 1,12, "damage",0,0,  false));
var _ss_x = [
    { s:"Deal 16 physical dmg. High precision crit.",
      f:"A rapid flurry of strikes with a sky-high crit chance - your most reliable burst once it's unlocked." },
    { s:"~(50% + WIS) chance to dodge the next attack; your next hit deals +12 dmg.",
      f:"Slip out of sight for a (50% + WIS*2)% chance - capped 85% - to dodge the next attack, then explode from cover for bonus damage on your following strike. Stun halves the dodge odds." },
    { s:"Spend 2 Prep. Deal 14 dmg, +5 per debuff on target. Ultimate.",
      f:"Rewards setup - the more debuffs, traps, and marks stacked on the target, the more this carves off. Your payoff finisher." },
];
for (var _i = 0; _i < 3; _i++) {
    global.abilities_shadowstrider[10 + _i].desc_short = _ss_x[_i].s;
    global.abilities_shadowstrider[10 + _i].desc_full  = _ss_x[_i].f;
}


// =============================================================================
// §3 ABILITY REWORK - setup->payoff damage abilities (one free primer per class,
// one Vex-gated payoff per class). Pushed at indices 13-14 so all earlier index
// literals and abilities_get_loadout() references stay valid. Combo riders live
// in obj_combat_controller/Step_0 next to the Snipe / Arcane Echo hooks. See
// SYSTEMS_ABILITY_REWORK.md.
// =============================================================================

// --- ARCANIST: Scorch (free primer) + Soul Nova (Vex payoff) ---
array_push(global.abilities_arcanist,
    // 13: Scorch - cheap Expose primer. Applies vulnerable so Arcane Burst / Snipe
    //     / Soul Nova land harder. Pure data (effect_type "debuff" -> vulnerable).
    ability_define("Scorch",
        /*energy*/1, /*secondary*/0,
        /*damage*/8, /*dtype*/1,        // elemental
        /*acc*/84, /*guaranteed*/false,
        /*crit_type*/2, /*base_crit*/6, // arcane (INT)
        /*effect_type*/"debuff", /*effect_value*/3, /*duration*/2, // Exposed +3/hit, 2 turns
        /*self*/false),
    // 14: Soul Nova - flexible mid-cost soul DUMP. Consumes up to 4 Souls for +7
    //     damage each (rider). Build with Soulfire/Scorch, dump here or in Burst.
    ability_define("Soul Nova",
        /*energy*/2, /*secondary*/0,    // souls consumed by the rider, not secondary_cost
        /*damage*/8, /*dtype*/1,        // elemental
        /*acc*/86, /*guaranteed*/false,
        /*crit_type*/2, /*base_crit*/8, // arcane (INT)
        /*effect_type*/"damage", /*effect_value*/0, /*duration*/0,
        /*self*/false));
global.abilities_arcanist[13].desc_short = "8 fire dmg. Sear [Fire+]: +3 fire/hit 2t. +1 Soul.";
global.abilities_arcanist[13].desc_full  = "A cheap fire primer: 8 fire damage, then a Searing mark [Fire+] that makes every follow-up hit deal +3 fire damage for 2 turns, and banks 1 Soul. Open with this, then detonate with Arcane Burst or Soul Nova.";
global.abilities_arcanist[14].desc_short = "Spend up to 4 Souls. Deal 8 elem +7 per Soul spent.";
global.abilities_arcanist[14].desc_full  = "Dump your banked Souls into one flexible blast - up to 4 Souls for +7 damage each. Cheaper and more flexible than Arcane Burst; rewards a turn or two of Soul generation.";

// --- BLOODWARDEN: Cleave (free filler) + Rupture (Vex payoff) ---
array_push(global.abilities_bloodwarden,
    // 13: Cleave - a 1-AP sweeping AoE (hits ALL enemies) so it's distinct from
    //     the general-pool Strike (single-target). The cheap clear-the-chaff tool
    //     for Bloodwarden; lower per-target damage than a focused hit. is_aoe set below.
    ability_define("Cleave",
        /*energy*/1, /*secondary*/0,
        /*damage*/9, /*dtype*/0,        // physical
        /*acc*/85, /*guaranteed*/false,
        /*crit_type*/0, /*base_crit*/8, // power (STR)
        /*effect_type*/"damage", /*effect_value*/0, /*duration*/0,
        /*self*/false),
    // 14: Rupture - bleed DETONATOR. Consumes all bleed/DoT stacks on the target
    //     for +5 damage per remaining tick (rider). Pairs with Gore Strike /
    //     Serrated Strikes / poison. Weak with no setup, brutal with a full stack.
    ability_define("Rupture",
        /*energy*/2, /*secondary*/0,
        /*damage*/8, /*dtype*/3,        // blood - bypasses armor
        /*acc*/84, /*guaranteed*/false,
        /*crit_type*/2, /*base_crit*/8, // arcane (INT) - scales with Blood theme
        /*effect_type*/"damage", /*effect_value*/0, /*duration*/0,
        /*self*/false));
global.abilities_bloodwarden[13].desc_short = "Deal 9 physical dmg to ALL enemies. Cheap sweep.";
global.abilities_bloodwarden[13].desc_full  = "A 1-AP sweeping strike that hits every enemy - your cheap clear-the-chaff tool. Less per-target than a focused hit, but it softens a whole pack and opens bleeds across the board.";
global.abilities_bloodwarden[14].desc_short = "Detonate all bleeds on target: +5 dmg per remaining tick.";
global.abilities_bloodwarden[14].desc_full  = "Burst every bleed and poison on the target at once - 8 blood damage plus 5 for each remaining tick, consuming the stacks. Build bleeds with Gore Strike, then Rupture for a payoff hit.";

// --- SHADOWSTRIDER: Throat Slit (free primer) + Assassinate (Vex payoff) ---
array_push(global.abilities_shadowstrider,
    // 13: Throat Slit - dedicated cheap Expose primer (cleaner than waiting on
    //     Poison Dart's slow DoT). Sets up Snipe / Assassinate / Flurry.
    ability_define("Throat Slit",
        /*energy*/1, /*secondary*/0,
        /*damage*/5, /*dtype*/0,        // physical
        /*acc*/88, /*guaranteed*/false,
        /*crit_type*/1, /*base_crit*/8, // precision (DEX)
        /*effect_type*/"debuff", /*effect_value*/4, /*duration*/2, // Exposed +4/hit, 2 turns
        /*self*/false),
    // 14: Assassinate - execute finisher. +100% damage on a target below 30% HP
    //     (rider). Spends 2 Prep. Rewards reading the board for the kill turn.
    ability_define("Assassinate",
        /*energy*/3, /*secondary*/2,
        /*damage*/26, /*dtype*/0,       // physical
        /*acc*/82, /*guaranteed*/false,
        /*crit_type*/1, /*base_crit*/12, // precision (DEX)
        /*effect_type*/"damage", /*effect_value*/0, /*duration*/0,
        /*self*/false));
global.abilities_shadowstrider[13].desc_short = "Deal 5 physical dmg. Expose target (+4 dmg/hit, 2t).";
global.abilities_shadowstrider[13].desc_full  = "A quick cut that Exposes the target - every follow-up hit lands for +4 for 2 turns. Your cheapest setup; chain it into Snipe, Flurry, or Assassinate.";
global.abilities_shadowstrider[14].desc_short = "Spend 2 Prep. Deal 24 dmg, DOUBLED if target below 30% HP.";
global.abilities_shadowstrider[14].desc_full  = "A precision finisher: heavy damage that deals DOUBLE against a target below 30% HP. Save it for the kill - when the execute lands it's your biggest single hit.";


// =============================================================================
// AoE TAGS - abilities that resolve against EVERY living enemy.
// Default (tag absent) = single-target. aoe_falloff defaults to 1.0 (full
// damage to all); combat reads `ab.is_aoe` and `ab.aoe_falloff`.
// =============================================================================
global.abilities_arcanist[8].is_aoe       = true;   // Rift        - elemental nuke, all enemies
global.abilities_arcanist[12].is_aoe      = true;   // Singularity - ultimate, all enemies
global.abilities_shadowstrider[4].is_aoe  = true;   // Smoke Bomb  - blind, all enemies (no damage)
global.abilities_bloodwarden[13].is_aoe   = true;   // Cleave      - 1-AP sweep, all enemies (vs single-target Strike)


// =============================================================================
// SCHOOL TAGS - explicit `school` overrides where flavor deviates from the
// damage_type default (see ability_school()). Everything not listed inherits the
// default: dtype 1->arcane, 2->void, 3->blood, physical->none. So the arcane
// (Arcane Burst/Rift/Echo/Singularity/Soul Nova), void (Void Drain/Entropy/Mana
// Sever) and blood (Blood Leech/Vital Theft/Bloodfeast/Crimson Apex/Rupture)
// abilities need no tag here. (SYSTEMS_ELEMENT_SCHOOLS.md §B.)
// =============================================================================
global.abilities_arcanist[0].school  = "fire";    // Soulfire     - elemental -> fire
global.abilities_arcanist[5].school  = "shadow";  // Curse        - dark hex (no dmg; flavor)
global.abilities_arcanist[9].school  = "shadow";  // Soulbind     - dark binding
global.abilities_arcanist[13].school = "fire";    // Scorch       - burn primer

global.abilities_bloodwarden[8].school = "poison"; // Plague Touch - plague (no dmg; flavor)

global.abilities_shadowstrider[3].school = "poison"; // Poison Dart - the poison ability


// =============================================================================
// ATTACK CLASSIFICATION - reach (melee/ranged) x kind (attack/spell).
// Control effects key off this: root blocks melee, silence blocks spell, stun all.
// See SYSTEMS_ATTACK_CLASS.md.
// =============================================================================

// ability_attack_class(ab) -> "melee_attack" | "ranged_attack" | "melee_spell" |
// "ranged_spell" | "none" (self/buff). kind derives from damage_type (physical =
// attack, else spell); reach from the MELEE name set below.
function ability_attack_class(ab) {
    if (ab.self_targeted) return "none";
    var _melee = false;
    switch (ab.name) {
        case "Strike":      case "Gore Strike":   case "Marrow Crush": case "Bonebreaker":
        case "Blood Leech": case "Vital Theft":   case "Plague Touch": case "Crimson Apex":
        case "Flurry":      case "Killing Spree":
        // §3 rework melee additions
        case "Cleave":      case "Rupture":       case "Throat Slit":  case "Assassinate":
            _melee = true; break;
    }
    var _spell = (variable_struct_exists(ab, "damage_type") && ab.damage_type != 0);
    return (_melee ? "melee_" : "ranged_") + (_spell ? "spell" : "attack");
}

// Convenience predicates used by the control checks.
function ability_class_is_melee(_ac) { return (_ac == "melee_attack" || _ac == "melee_spell"); }
function ability_class_is_ranged(_ac) { return (_ac == "ranged_attack" || _ac == "ranged_spell"); }
function ability_class_is_spell(_ac) { return (_ac == "melee_spell" || _ac == "ranged_spell"); }

// Human-readable label for tooltips / the compendium.
function ability_attack_class_label(_ac) {
    switch (_ac) {
        case "melee_attack":  return "Melee Attack";
        case "ranged_attack": return "Ranged Attack";
        case "melee_spell":   return "Melee Spell";
        case "ranged_spell":  return "Ranged Spell";
    }
    return "";
}

// Compact parenthetical tag appended to the END of ability descriptions, e.g.
// "(melee/phys)", "(ranged/spell)". "phys" == attack, "spell" == spell.
// Returns "" for self-targeted abilities (no attack class). Pass an ability.
function ability_attack_class_tag(ab) {
    switch (ability_attack_class(ab)) {
        case "melee_attack":  return "(melee/phys)";
        case "ranged_attack": return "(ranged/phys)";
        case "melee_spell":   return "(melee/spell)";
        case "ranged_spell":  return "(ranged/spell)";
    }
    return "";
}

// Multi-turn cooldown (in player turns) for an ability, 0 = no cooldown.
// Only the active full-evasion abilities are gated so they can't be spammed
// every turn. The combat controller reads this when a cast succeeds and stores
// the counter in a per-combat player.ability_cd slot array (NOT on the shared
// ability struct). Pass an ability struct.
function ability_cooldown(ab) {
    switch (ab.name) {
        case "Blink":          return 2;
        case "Shadow Step":    return 2;
        case "Field Dressing": return 2;   // was once-per-combat; now a 2-turn CD like Blink
        case "Void Drain":     return 2;   // cheap 1-AP heal/Soul, gated by a 2-turn CD
    }
    return 0;
}

// ability_is_detonator(ab) - true for abilities that trigger status reactions on
// hit (see SYSTEMS_VIABILITY_PASS.md). Accepts a struct or a name string.
function ability_is_detonator(ab) {
    var _n = is_struct(ab) ? ab.name : ab;
    return (_n == "Snipe" || _n == "Assassinate" || _n == "Arcane Burst" || _n == "Soul Nova");
}


// =============================================================================
// ABILITY ROLE CATEGORY - Offense / Defense / Support / Control
// (SYSTEMS_ABILITY_SYNERGY.md). A role axis orthogonal to the reachxkind attack
// class. Drives the same-category AP synergy discount and the category colour
// coding. Name-keyed overrides (hybrids + the design's explicit classifications)
// win over a derivation fallback, so nothing is ever homeless. Pass a struct or a
// bare name string.
// =============================================================================
function ability_category(ab) {
    var _n = is_struct(ab) ? ab.name : ab;

    // --- Name-keyed overrides ---
    switch (_n) {
        // offense - damage IS the point (traps included: damage tools that also CC,
        // classed offense so trap users still get the offense discount - tunable).
        case "Strike":       case "Cleave":        case "Snipe":         case "Flurry":
        case "Killing Spree": case "Throat Slit":  case "Assassinate":   case "Gore Strike":
        case "Marrow Crush": case "Bonebreaker":   case "Crimson Apex":  case "Rupture":
        case "Soulfire":     case "Arcane Burst":  case "Soul Nova":     case "Arcane Echo":
        case "Singularity":  case "Rift":          case "Scorch":        case "Poison Dart":
        case "Crippling Shot": case "Mana Sever":  case "Vital Theft":   case "Soulbind":
        case "Bear Trap":    case "Spike Trap":    case "Death Trap":
            return "offense";

        // defense - self-protection
        case "Iron Skin":    case "Bloodthorn Aura": case "Soul Shield": case "Blink":
        case "Shadow Step":  case "Evasive Roll":  case "Vanish":        case "Undying":
            return "defense";

        // support - heal / buff / resource (incl. sustain-primary hybrids: Void Drain,
        // Blood Leech - judgment calls, tunable).
        case "Field Dressing": case "Void Drain":  case "Blood Surge":   case "Second Wind":
        case "Adrenaline Rush": case "Soul Harvest": case "Sanguine Pact": case "Bloodfeast":
        case "Blood Leech":
            return "support";

        // control - pure debuff / CC, no damage as the point (Entropy is DoT-only
        // debuff - judgment call, tunable).
        case "Curse":        case "Smoke Bomb":    case "Marked for Death": case "Entropy":
        case "Plague Touch":
            return "control";
    }

    // --- Derivation fallback (only reached by abilities not named above) ---
    if (!is_struct(ab)) return "offense";   // bare name, no struct to inspect - safe default
    var _self  = variable_struct_exists(ab, "self_targeted") && ab.self_targeted;
    var _etype = variable_struct_exists(ab, "effect_type")  ? ab.effect_type  : "none";
    var _dmg   = variable_struct_exists(ab, "base_damage")  ? ab.base_damage  : 0;

    if (_self) {
        // self-targeted protective status (shield / dodge / survival / reflect) -> defense;
        // otherwise heal / resource / other self-buff -> support.
        if (_etype == "shield" || _etype == "status") return "defense";
        return "support";
    }
    if (_dmg == 0) return "control";   // no damage, aimed outward = pure debuff / CC
    return "offense";                  // deals damage = offense
}

// Display label for a category string ("offense" -> "Offense"); "" -> "".
function ability_category_label(_cat) {
    switch (_cat) {
        case "offense": return "Offense";
        case "defense": return "Defense";
        case "support": return "Support";
        case "control": return "Control";
    }
    return "";
}

// Short role-tag text for an ability, e.g. "[Offense]" - drawn as a category-coloured
// chip on the loadout / Vex rows (mirrors ability_attack_class_tag). "" if homeless.
function ability_category_tag(ab) {
    var _lbl = ability_category_label(ability_category(ab));
    return (_lbl != "") ? ("[" + _lbl + "]") : "";
}

// UI colour for a category (offense red / defense blue / support green / control purple).
function ability_category_color(_cat) {
    switch (_cat) {
        case "offense": return make_color_rgb(220,  90,  80);
        case "defense": return make_color_rgb( 80, 140, 220);
        case "support": return make_color_rgb( 90, 200, 120);
        case "control": return make_color_rgb(170, 110, 220);
    }
    return c_white;
}

// ability_synergy_active(ab, caster) - true when an ability of THIS ability's role
// category was already cast THIS player turn, so the same-category synergy discount
// applies. Reads the per-turn set caster.turn_cast_categories (reset at player-turn
// start by obj_combat_controller). Safe when the caster/set is missing.
function ability_synergy_active(ab, caster) {
    if (is_undefined(caster) || !variable_struct_exists(caster, "turn_cast_categories")) return false;
    var _cat = ability_category(ab);
    var _set = caster.turn_cast_categories;
    return variable_struct_exists(_set, _cat) && _set[$ _cat];
}

// ability_effective_cost(ab, caster) - SINGLE SOURCE OF TRUTH for the AP a caster
// pays for an ability right now, after the same-category synergy discount (-1 AP,
// floor 1). Used by the UI cost display and standalone gates; the combat cast block
// folds the same -1 into its inline discount stack (Quickcast/Cracked Focus/etc.) so
// every path agrees. Free (0-AP) abilities stay 0; only AP is discounted, never the
// secondary resource. Pass the casting player as `caster` (may be undefined -> no discount).
function ability_effective_cost(ab, caster) {
    var _base = variable_struct_exists(ab, "energy_cost") ? ab.energy_cost : 0;
    if (_base <= 0) return _base;   // free abilities stay free
    // SUPPORT abilities can be discounted all the way to 0 AP (M's call): a 1-AP
    // support cast after another support this turn becomes free, so buff/heal chains
    // are genuinely free. Every other role still floors at 1 AP.
    var _floor = (ability_category(ab) == "support") ? 0 : 1;
    return max(_floor, _base - (ability_synergy_active(ab, caster) ? 1 : 0));
}


// =============================================================================
// ELEMENT SCHOOLS - damage-flavor layer ON TOP of the coarse damage_type buckets
// (SYSTEMS_ELEMENT_SCHOOLS.md). School is METADATA only: damage_type still governs
// mitigation; the school tags an ability for build identity and "+X <school> damage"
// gear affixes. Eight schools: fire / frost / shock / arcane / blood / void /
// shadow / poison. frost & shock have no ability content yet (sparse by design -
// filled by future content + the weapon elemental affixes that apply those statuses).
// =============================================================================

// ability_school(ab) - the school an ability damages with. Returns an explicit
// `school` field if tagged (see the SCHOOL TAGS block below), else a safe default
// inferred from damage_type so nothing is ever homeless. Physical attacks have no
// school ("").
function ability_school(ab) {
    if (variable_struct_exists(ab, "school") && ab.school != "") return ab.school;
    var _dt = variable_struct_exists(ab, "damage_type") ? ab.damage_type : 0;
    switch (_dt) {
        case 3: return "blood";    // blood-type abilities
        case 2: return "void";     // drain/void-type abilities
        case 1: return "arcane";   // generic elemental until tagged fire/frost/shock
    }
    return "";                     // physical (0) - no school
}

// Display label for a school string ("fire" -> "Fire"); "" -> "".
function school_label(school) {
    if (school == "") return "";
    return string_upper(string_char_at(school, 1)) + string_copy(school, 2, string_length(school) - 1);
}

// school_color(school) - canonical tint for each element/school. Used by the
// combat-log color coding and any school-tagged UI text.
function school_color(school) {
    switch (school) {
        case "fire":   return make_color_rgb(235, 110,  45);
        case "frost":  return make_color_rgb( 95, 180, 235);
        case "shock":  return make_color_rgb(235, 215,  75);
        case "arcane": return make_color_rgb(190, 110, 230);
        case "blood":  return make_color_rgb(205,  55,  55);
        case "void":   return make_color_rgb(150,  95, 210);
        case "shadow": return make_color_rgb(150, 140, 185);
        case "poison": return make_color_rgb( 95, 200,  95);
    }
    return c_white;
}

// ability_school_list() - the eight schools in canonical order (Compendium +
// the school_dmg accumulator iteration).
function ability_school_list() {
    return ["fire", "frost", "shock", "arcane", "blood", "void", "shadow", "poison"];
}


// =============================================================================
// DYNAMIC ABILITY DESCRIPTIONS (single source of truth).
// Built entirely from the ability's LIVE fields, so the text auto-updates when
// the numbers change (future ability leveling, buffs, etc.). Used by the combat
// tooltip AND the loadout screen - write nothing twice, nothing can drift.
// See ROADMAP.md §2.
// =============================================================================

function ability_dtype_name(dt) {
    switch (dt) { case 1: return "elemental"; case 2: return "void"; case 3: return "blood"; }
    return "physical";
}

// ability_damage_word(ab) - the damage-type word shown to the player. Prefers the
// concrete elemental school (fire/frost/shock) over the generic "elemental" so a
// schooled ability reads as its actual flavor (Soulfire/Scorch -> "fire"); arcane,
// void, blood and physical fall back to the plain damage_type name. (Element Schools)
function ability_damage_word(ab) {
    var _dt = variable_struct_exists(ab, "damage_type") ? ab.damage_type : 0;
    if (_dt == 1) {
        var _sch = ability_school(ab);
        if (_sch == "fire" || _sch == "frost" || _sch == "shock") return _sch;
    }
    return ability_dtype_name(_dt);
}

// "1 turn" / "N turns"
function ability_turns(n) { return string(n) + (n == 1 ? " turn" : " turns"); }

// ability_effect_full(ab) - everything the ability DOES except the raw damage number
// (shown separately as a stat line). Magnitudes/durations come from live fields.
function ability_effect_full(ab) {
    var _ev = variable_struct_exists(ab, "effect_value")    ? ab.effect_value    : 0;
    var _ed = variable_struct_exists(ab, "effect_duration") ? ab.effect_duration : 0;
    var _et = variable_struct_exists(ab, "effect_type")     ? ab.effect_type     : "none";
    var _parts = [];

    // Bespoke riders (effects not captured by the standard fields).
    var _b = "";
    switch (ab.name) {
        case "Soulfire":        _b = "Generate 2 Souls."; break;
        case "Soul Harvest":    _b = "Free 0-AP action: generate " + string(_ev) + " Souls."; break;
        case "Arcane Echo":     _b = "Deals +4 bonus damage per Soul you hold."; break;
        case "Soul Nova":       _b = "Consumes up to 4 Souls; +7 damage per Soul spent."; break;
        case "Flurry":          _b = "Strikes 3 times; each hit rolls its own crit. +3 damage per debuff on the target."; break;
        case "Rupture":         _b = "Detonates every bleed/poison on the target: +5 damage per remaining tick, consuming them."; break;
        case "Assassinate":     _b = "Execute: deals DOUBLE damage to a target below 30% HP."; break;
        case "Killing Spree":   _b = "Deals +6 bonus damage per debuff or trap on the target."; break;
        case "Entropy":         _b = "Deals DOUBLE damage if the target already carries a void DoT - stack it on itself to ramp up."; break;
        case "Adrenaline Rush": _b = "Gain +1 AP this turn (once per combat)."; break;
        case "Sanguine Pact":   _b = "Spend 8 HP to gain 3 Blood."; break;
        case "Second Wind":     _b = "Also restore 1 secondary resource (Soul / Blood / Prep)."; break;
        case "Blink":           _b = "Fully dodge the next attack; the 2nd hit after takes 50% less and the 3rd 25% less. 2-turn cooldown."; break;
        case "Shadow Step":     _b = "~(50% + WIS) chance to dodge each of the next 3 attacks. 2-turn cooldown."; break;
        case "Evasive Roll":    _b = "Halve the next incoming hit above 10 damage."; break;
        case "Vanish":          _b = "~(50% + WIS) chance to dodge the next attack; your next strike deals +12 damage."; break;
        case "Bloodthorn Aura": _b = "Reflect " + string(_ev) + " damage to attackers for " + ability_turns(_ed) + "."; break;
        case "Undying":         _b = "Survive one otherwise-lethal blow at 1 HP this turn."; break;
        case "Vital Theft":     _b = "Steal " + string(_ev) + " max HP from the target for this combat."; break;
        case "Bloodfeast":      _b = "Each ability also drains " + string(_ev) + " HP for " + ability_turns(_ed) + "."; break;
        case "Soulbind":        _b = "Reflect " + string(round(_ev * 100)) + "% of damage you take back to the target (whole combat)."; break;
    }
    if (_b != "") array_push(_parts, _b);

    // Detonators surface their reaction behavior. Kept to one plain-English line here;
    // the full reaction table lives in the Tab/V ability-detail popup and the
    // Compendium > Status Reactions page. See SYSTEMS_VIABILITY_PASS.md.
    if (ab.name == "Snipe" || ab.name == "Assassinate" || ab.name == "Arcane Burst" || ab.name == "Soul Nova") {
        array_push(_parts, "Detonates debuffs for secondary effects.");
    }

    // Standard effect from the typed status kind / effect_type.
    var _k = ability_status_kind(ab);
    var _s = "";
    switch (_k) {
        case "dot":
            // Name the DoT flavor (bleed / poison / burn / void) so it's clear what
            // kind of tick this is - and which detonation reaction it enables.
            var _dot_el = ability_status_element(ab);
            var _dot_word = (_dot_el != "") ? (_dot_el + " ") : "";
            _s = "Applies " + string(_ev) + " " + _dot_word + "damage/turn for " + ability_turns(_ed)
               + " (a " + (_dot_el != "" ? _dot_el : "damage-over-time") + " effect).";
            break;
        case "silence":    _s = "Silences the target for " + ability_turns(_ed) + " (can't cast spells)."; break;
        case "stun":       _s = "Stuns the target for " + ability_turns(_ed) + " (any enemy can't act)."; break;
        case "root":       _s = "Roots the target for " + ability_turns(_ed) + " (melee enemies skip; ranged still attack)."; break;
        case "vulnerable": _s = "Target takes +" + string(_ev) + " damage per hit for " + ability_turns(_ed) + "."; break;
        case "firemark":
            // Scorch's mark: every follow-up hit deals +N TRUE FIRE damage (reduced by
            // the target's elemental resist). Banks a Soul on cast. Badges [Fire+].
            _s = "Sears the target [Fire+]: every hit on it deals +" + string(_ev) + " fire damage for " + ability_turns(_ed) + ", and banks 1 Soul.";
            break;
        case "weaken":     _s = "Target deals " + string(round(_ev * 100)) + "% less damage for " + ability_turns(_ed) + "."; break;
        case "blind":      _s = "Reduces target accuracy by " + string(round(_ev * 100)) + "% for " + ability_turns(_ed) + "."; break;
        case "mortality":  _s = "Reduces target healing by " + string(round(_ev * 100)) + "% for " + ability_turns(_ed) + "."; break;
        default:
            if (_et == "heal")        _s = "Restores " + string(_ev) + " HP."
                                         + (ability_cooldown(ab) > 0 ? (" " + string(ability_cooldown(ab)) + "-turn cooldown.") : "");
            else if (_et == "shield") _s = (_ed > 0)
                ? ("Reduces incoming damage by " + string(_ev) + " for " + ability_turns(_ed) + ".")
                : ("Absorbs the next " + string(_ev) + " damage.");
    }
    if (_s != "") array_push(_parts, _s);

    var _out = "";
    for (var _i = 0; _i < array_length(_parts); _i++) _out += (_i > 0 ? " " : "") + _parts[_i];
    return _out;
}

// ability_describe(ab) - full standalone description: damage clause + all effects.
// This is the one canonical description shown on every screen.
function ability_describe(ab) {
    var _out = "";
    if (variable_struct_exists(ab, "base_damage") && ab.base_damage > 0) {
        var _dt  = variable_struct_exists(ab, "damage_type") ? ab.damage_type : 0;
        var _aoe = (variable_struct_exists(ab, "is_aoe") && ab.is_aoe && !trait_active("Focused Power"));
        _out = "Deal " + string(ab.base_damage) + " " + ability_damage_word(ab) + " damage"
             + (_aoe ? " to all enemies" : "") + ".";
    }
    var _eff = ability_effect_full(ab);
    if (_eff != "") _out += (_out != "" ? " " : "") + _eff;
    if (_out == "") _out = "A utility action.";
    return _out;
}

// ability_summary(ab) - compact one-line version for tight list rows (loadout list,
// Vex shop). Same live-field source, just abbreviated.
function ability_summary(ab) {
    var _ev = variable_struct_exists(ab, "effect_value")    ? ab.effect_value    : 0;
    var _ed = variable_struct_exists(ab, "effect_duration") ? ab.effect_duration : 0;
    var _et = variable_struct_exists(ab, "effect_type")     ? ab.effect_type     : "none";
    var _p = [];
    if (variable_struct_exists(ab, "base_damage") && ab.base_damage > 0) {
        array_push(_p, string(ab.base_damage) + " " + ability_damage_word(ab));
    }
    var _tag = "";
    switch (ability_status_kind(ab)) {
        case "dot":        _tag = "DoT " + string(_ev) + "/" + string(_ed) + "t"; break;
        case "silence":    _tag = "Silence " + string(_ed) + "t"; break;
        case "stun":       _tag = "Stun " + string(_ed) + "t"; break;
        case "root":       _tag = "Root " + string(_ed) + "t"; break;
        case "vulnerable": _tag = "+" + string(_ev) + " dmg taken " + string(_ed) + "t"; break;
        case "firemark":   _tag = "[Fire+] +" + string(_ev) + " fire/hit " + string(_ed) + "t, +1 Soul"; break;
        case "weaken":     _tag = "-" + string(round(_ev * 100)) + "% dmg " + string(_ed) + "t"; break;
        case "blind":      _tag = "-" + string(round(_ev * 100)) + "% acc " + string(_ed) + "t"; break;
        case "mortality":  _tag = "-" + string(round(_ev * 100)) + "% heal " + string(_ed) + "t"; break;
        default:
            if (_et == "heal")        _tag = "Heal " + string(_ev) + (ability_cooldown(ab) > 0 ? (" " + string(ability_cooldown(ab)) + "t CD") : "");
            else if (_et == "shield") _tag = (_ed > 0) ? ("-" + string(_ev) + " dmg " + string(_ed) + "t") : ("Shield " + string(_ev));
    }
    if (_tag == "") {
        switch (ab.name) {
            case "Soulfire":        _tag = "+2 Soul"; break;
            case "Soul Harvest":    _tag = "+" + string(_ev) + " Soul (0 AP)"; break;
            case "Arcane Echo":     _tag = "+4 per Soul"; break;
            case "Soul Nova":       _tag = "+7 per Soul (max 4)"; break;
            case "Arcane Burst":    _tag = "+40% vs Exposed"; break;
            case "Flurry":          _tag = "+3 per debuff"; break;
            case "Rupture":         _tag = "Detonate bleeds"; break;
            case "Assassinate":     _tag = "x2 if <30% HP"; break;
            case "Killing Spree":   _tag = "+5 per debuff"; break;
            case "Snipe":           _tag = "+" + string(_ev) + " if debuffed"; break;
            case "Adrenaline Rush": _tag = "+1 AP"; break;
            case "Sanguine Pact":   _tag = "HP -> Blood"; break;
            case "Blink":           _tag = "Dodge 1, soften 2 - 2t CD"; break;
            case "Shadow Step":     _tag = "Dodge chance x3 - 2t CD"; break;
            case "Evasive Roll":    _tag = "Halve next hit"; break;
            case "Vanish":          _tag = "Vanish, +12 next"; break;
            case "Bloodthorn Aura": _tag = "Thorns " + string(_ev) + "/" + string(_ed) + "t"; break;
            case "Undying":         _tag = "Cheat death"; break;
            case "Vital Theft":     _tag = "Steal " + string(_ev) + " maxHP"; break;
            case "Bloodfeast":      _tag = "Drain rider " + string(_ed) + "t"; break;
            case "Soulbind":        _tag = "Reflect " + string(round(_ev * 100)) + "%"; break;
        }
    }
    if (_tag != "") array_push(_p, _tag);
    if (variable_struct_exists(ab, "is_aoe") && ab.is_aoe) array_push(_p, "all enemies");

    var _o = "";
    for (var _i = 0; _i < array_length(_p); _i++) _o += (_i > 0 ? " - " : "") + _p[_i];
    return (_o == "") ? "Utility" : _o;
}


// =============================================================================
// TRAIT SYSTEM
// Traits are passive bonuses unlocked through play and chosen at the Dungeon
// Gate before each run (up to 2 active at once via global.player_traits).
//
// Trait field reference:
//   name         string  - display name; also the key stored in player_traits
//   description  string  - one-line effect summary shown in the gate overlay
//   class_req    int     - -1 = any class, 0/1/2 = class-specific
//   unlock_type  string  - "default", "full_clear", "char_level", "boss_kill"
//   unlock_value real    - threshold relevant to unlock_type (0 if not used)
//   effect_id    string  - snake_case key in global.traits_unlocked struct
// =============================================================================

// ---------------------------------------------------------------------------
// trait_define(...)
// Factory function - returns a fully populated trait struct.
// ---------------------------------------------------------------------------
function trait_define(name, description, class_req, unlock_type, unlock_value, effect_id) {
    return {
        name:         name,
        description:  description,
        class_req:    class_req,
        unlock_type:  unlock_type,
        unlock_value: unlock_value,
        effect_id:    effect_id,
    };
}

// ---------------------------------------------------------------------------
// trait_active(trait_name)
// Returns true if the named trait is one of the two selected for this run.
// Since only unlocked traits reach player_traits (gate screen validates),
// no additional unlock check is required here.
// ---------------------------------------------------------------------------
function trait_active(trait_name) {
    if (!variable_global_exists("player_traits")) return false;
    // Loop the whole array so bought/Crown trait slots beyond the first two count.
    for (var _i = 0; _i < array_length(global.player_traits); _i++) {
        if (global.player_traits[_i] == trait_name) return true;
    }
    return false;
}

// ---------------------------------------------------------------------------
// TRAIT DEFINITIONS
// Three universals unlock by default.  The other five require progression.
// ---------------------------------------------------------------------------
global.traits_all = [

    // -------------------------------------------------------------------------
    // UNIVERSAL - unlocked from the start
    // -------------------------------------------------------------------------
    trait_define("Sense",
        "Reveals loot quality and threat level of rooms on the floor map.",
        -1, "default", 0, "sense"),

    trait_define("Scavenger",
        "+15% gold from all sources.",
        -1, "default", 0, "scavenger"),

    trait_define("Thick Skin",
        "+10% maximum HP while equipped (static - not a heal).",
        -1, "default", 0, "thick_skin"),

    // -------------------------------------------------------------------------
    // UNIVERSAL - unlocked through dungeon progression
    // -------------------------------------------------------------------------
    trait_define("Quick Recovery",
        "Rest rooms restore 25 HP instead of 15.",
        -1, "dungeon_clears_total", 2, "quick_recovery"),

    trait_define("Treasure Hunter",
        "Treasure rooms always contain at least one item.",
        -1, "dungeon_clears_total", 3, "treasure_hunter"),

    trait_define("Lucky Find",
        "+5% consumable drop chance from all enemies.",
        -1, "full_clear", 1, "lucky_find"),

    trait_define("Battle Hardened",
        "Each floor boss defeated permanently grants +3 max HP (up to +15).",
        -1, "dungeon_clears_total", 5, "battle_hardened"),

    trait_define("Salvager",
        "Keep 2 random carried items on death instead of 1.",
        -1, "char_level", 5, "salvager"),

    trait_define("Iron Will",
        "The first status effect applied to you each combat is ignored.",
        -1, "dungeon_clears_total", 8, "iron_will"),

    trait_define("Expanded Arsenal",
        "Take 5 abilities into each run instead of 4.",
        -1, "dungeon_clears_total", 4, "expanded_arsenal"),

    trait_define("Prospector",
        "Combat loot rolls one quality tier better.",
        -1, "dungeon_clears_total", 2, "prospector"),

    trait_define("Pack Rat",
        "Carry +5 consumables on a run (base pack holds 10). Each potency tier adds +5 more, up to +15.",
        -1, "dungeon_clears_total", 2, "pack_rat"),

    trait_define("Last Stand",
        "Once per run, survive a lethal blow at 1 HP.",
        -1, "total_boss_kills", 3, "last_stand"),

    // -------------------------------------------------------------------------
    // UNIVERSAL - AoE-themed (the burst-vs-spread levers)
    // -------------------------------------------------------------------------
    trait_define("Focused Power",
        "AoE abilities instead strike only your target for +50% damage.",
        -1, "total_boss_kills", 4, "focused_power"),

    trait_define("Chain Caster",
        "Single-target elemental/void/blood hits splash 40% to all other enemies.",
        -1, "char_level", 8, "chain_caster"),

    trait_define("Plaguebearer",
        "DoTs and debuffs you apply also hit all other enemies at half duration.",
        -1, "dungeon_clears_total", 6, "plaguebearer"),

    // -------------------------------------------------------------------------
    // CLASS: ARCANIST (class_req 0) - unlocked via boss kills
    // -------------------------------------------------------------------------
    trait_define("Soul Siphon",
        "Gain +1 Soul whenever an enemy dies (Arcanist only).",
        0, "boss_kill", 1, "soul_siphon"),

    trait_define("Ley Tap",
        "Start each combat with +1 bonus AP (Arcanist only).",
        0, "total_boss_kills", 2, "ley_tap"),

    trait_define("Arcane Surge",
        "Abilities costing 4 or more AP deal +25% damage (Arcanist only).",
        0, "total_boss_kills", 4, "arcane_surge"),

    // -------------------------------------------------------------------------
    // CLASS: BLOODWARDEN (class_req 1) - unlocked via boss kills
    // -------------------------------------------------------------------------
    trait_define("Crimson Reserve",
        "Start each combat with +20 Blood (Bloodwarden only).",
        1, "boss_kill", 1, "crimson_reserve"),

    trait_define("Vampiric Edge",
        "Restore 2 HP each time you deal bleed/poison damage (Bloodwarden only).",
        1, "total_boss_kills", 2, "vampiric_edge"),

    trait_define("Berserker Rage",
        "Below 40% HP, all damage you deal is increased by 20% (Bloodwarden only).",
        1, "total_boss_kills", 4, "berserker_rage"),

    // -------------------------------------------------------------------------
    // CLASS: SHADOWSTRIDER (class_req 2) - unlocked via boss kills
    // -------------------------------------------------------------------------
    trait_define("Phantom Step",
        "The first enemy attack each combat automatically misses (Shadowstrider only).",
        2, "boss_kill", 1, "phantom_step"),

    trait_define("Shadow Meld",
        "After dodging an attack, gain +15 bonus dodge for 1 turn (Shadowstrider only).",
        2, "total_boss_kills", 2, "shadow_meld"),

    trait_define("Serrated Strikes",
        "Physical abilities apply 1 bleed stack for free (Shadowstrider only).",
        2, "total_boss_kills", 4, "serrated_strikes"),

];


// =============================================================================
// VEX THE TRAINER - helper functions
// Permanent meta-progression bought from Vex: trait slots, ability unlocks,
// and trait potency (stat-sacrifice strengthening).
// =============================================================================

// ---------------------------------------------------------------------------
// max_trait_slots()
// Total active-trait slots available: base 2 + bought bonus_trait_slots
// (Vex, max +2) + 1 while Crown of the Hollow King is equipped. Single source
// of truth used by the loadout select/draw code.
// ---------------------------------------------------------------------------
function max_trait_slots() {
    var _m = 2;
    if (variable_global_exists("bonus_trait_slots")) _m += global.bonus_trait_slots;
    if (variable_global_exists("inventory")) {
        for (var _i = 0; _i < array_length(global.inventory); _i++) {
            var _it = global.inventory[_i];
            if (_it != undefined && variable_struct_exists(_it, "unique_effect")
                && _it.unique_effect == "crown_hollow_king") { _m += 1; break; }
        }
    }
    return _m;
}

// ---------------------------------------------------------------------------
// trait_respec_cost(new_traits)
// 50g for each previously-equipped (non-empty) trait that is NOT in the new
// selection. Adding a trait to a previously-empty slot is free. Generalizes the
// old two-slot respec logic so it works for any number of trait slots.
// ---------------------------------------------------------------------------
function trait_respec_cost(new_traits) {
    if (!variable_global_exists("player_traits")) return 0;
    var _cost = 0;
    for (var _i = 0; _i < array_length(global.player_traits); _i++) {
        var _old = global.player_traits[_i];
        if (_old == "") continue;
        var _kept = false;
        for (var _j = 0; _j < array_length(new_traits); _j++) {
            if (new_traits[_j] == _old) { _kept = true; break; }
        }
        if (!_kept) _cost += 50;
    }
    return _cost;
}

// ---------------------------------------------------------------------------
// commit_player_traits(new_traits)
// Overwrites global.player_traits with the new selection, sized to hold every
// selected trait (minimum length 2 so existing index access stays safe) and
// padded with "" for empty slots.
// ---------------------------------------------------------------------------
function commit_player_traits(new_traits) {
    var _len = max(2, array_length(new_traits));
    var _result = array_create(_len, "");
    for (var _i = 0; _i < array_length(new_traits); _i++) {
        _result[_i] = new_traits[_i];
    }
    global.player_traits = _result;
}

// ---------------------------------------------------------------------------
// ability_unlock_info(ability_name)
// Returns the gating descriptor for an ability, or undefined when the ability is
// FREE (a default starter - never listed here). Single source of truth for all
// ability gating. Fields:
//   type       "vex"  - bought from Vex the Trainer for `cost` gold
//              "goal" - unlocks automatically when a progression goal is met
//   cost       gold price (vex only; 0 for goal)
//   goal_type  "char_level" | "total_boss_kills" | "dungeon_clears_total" (goal only)
//   goal_value threshold for goal_type (goal only)
// ---------------------------------------------------------------------------
function ability_unlock_info(ability_name) {
    switch (ability_name) {
        // ---- VEX (gold purchase) - tiered 100 / 250 / 400 ----
        // The "goal" type is retained in goal_met / ability_is_unlocked below for
        // FUTURE milestone-free abilities, but no ability currently uses it.
        // General pool
        case "Second Wind":      return { type:"vex", cost:100, goal_type:"", goal_value:0 };
        case "Adrenaline Rush":  return { type:"vex", cost:250, goal_type:"", goal_value:0 };
        // Arcanist
        case "Soul Harvest":     return { type:"vex", cost:100, goal_type:"", goal_value:0 };
        case "Curse":            return { type:"vex", cost:100, goal_type:"", goal_value:0 };
        case "Soul Shield":      return { type:"vex", cost:100, goal_type:"", goal_value:0 };
        case "Mana Sever":       return { type:"vex", cost:100, goal_type:"", goal_value:0 };
        case "Entropy":          return { type:"vex", cost:250, goal_type:"", goal_value:0 };
        case "Arcane Echo":      return { type:"vex", cost:250, goal_type:"", goal_value:0 };
        case "Soul Nova":        return { type:"vex", cost:250, goal_type:"", goal_value:0 };
        case "Rift":             return { type:"vex", cost:400, goal_type:"", goal_value:0 };
        case "Soulbind":         return { type:"vex", cost:400, goal_type:"", goal_value:0 };
        case "Singularity":      return { type:"vex", cost:400, goal_type:"", goal_value:0 };
        // Bloodwarden
        case "Bloodthorn Aura":  return { type:"vex", cost:100, goal_type:"", goal_value:0 };
        case "Plague Touch":     return { type:"vex", cost:100, goal_type:"", goal_value:0 };
        case "Sanguine Pact":    return { type:"vex", cost:100, goal_type:"", goal_value:0 };
        case "Marrow Crush":     return { type:"vex", cost:250, goal_type:"", goal_value:0 };
        case "Vital Theft":      return { type:"vex", cost:250, goal_type:"", goal_value:0 };
        case "Bonebreaker":      return { type:"vex", cost:250, goal_type:"", goal_value:0 };
        case "Undying":          return { type:"vex", cost:400, goal_type:"", goal_value:0 };
        case "Bloodfeast":       return { type:"vex", cost:400, goal_type:"", goal_value:0 };
        case "Crimson Apex":     return { type:"vex", cost:400, goal_type:"", goal_value:0 };
        case "Rupture":          return { type:"vex", cost:400, goal_type:"", goal_value:0 };
        // Shadowstrider
        case "Smoke Bomb":       return { type:"vex", cost:100, goal_type:"", goal_value:0 };
        case "Crippling Shot":   return { type:"vex", cost:100, goal_type:"", goal_value:0 };
        case "Marked for Death": return { type:"vex", cost:100, goal_type:"", goal_value:0 };
        case "Spike Trap":       return { type:"vex", cost:250, goal_type:"", goal_value:0 };
        case "Evasive Roll":     return { type:"vex", cost:250, goal_type:"", goal_value:0 };
        case "Flurry":           return { type:"vex", cost:250, goal_type:"", goal_value:0 };
        case "Vanish":           return { type:"vex", cost:250, goal_type:"", goal_value:0 };
        case "Death Snare":      return { type:"vex", cost:400, goal_type:"", goal_value:0 };
        case "Killing Spree":    return { type:"vex", cost:400, goal_type:"", goal_value:0 };
        case "Assassinate":      return { type:"vex", cost:400, goal_type:"", goal_value:0 };
        // §3 rework: Scorch / Throat Slit / Cleave are FREE primers (no entry).
    }
    return undefined;  // free starter
}

// ---------------------------------------------------------------------------
// ability_unlock_cost(name) - gold price (0 for free / goal-gated abilities).
// ---------------------------------------------------------------------------
function ability_unlock_cost(ability_name) {
    var _info = ability_unlock_info(ability_name);
    if (_info == undefined) return 0;
    return cha_price(_info.cost);   // CHA vendor discount
}

// ---------------------------------------------------------------------------
// goal_met(goal_type, goal_value) - true when the named progression goal is met.
// Reads persistent meta-progression globals so the check is valid in the hub.
// ---------------------------------------------------------------------------
function goal_met(goal_type, goal_value) {
    switch (goal_type) {
        case "total_boss_kills":
            return variable_global_exists("total_boss_kills") && global.total_boss_kills >= goal_value;
        case "dungeon_clears_total":
            return variable_global_exists("dungeon_clears_total") && global.dungeon_clears_total >= goal_value;
        case "char_level":
            return variable_global_exists("highest_run_level") && global.highest_run_level >= goal_value;
    }
    return false;
}

// ---------------------------------------------------------------------------
// ability_unlock_condition_text(name) - one-line gate description for the UI.
// ---------------------------------------------------------------------------
function ability_unlock_condition_text(ability_name) {
    var _info = ability_unlock_info(ability_name);
    if (_info == undefined) return "";
    if (_info.type == "vex") return "Unlock from Vex the Trainer (" + string(_info.cost) + "g)";
    switch (_info.goal_type) {
        case "char_level":           return "Unlock: reach level " + string(_info.goal_value) + " in a run";
        case "total_boss_kills":     return "Unlock: defeat " + string(_info.goal_value) + " bosses (lifetime)";
        case "dungeon_clears_total": return "Unlock: clear " + string(_info.goal_value) + " dungeons";
    }
    return "Locked";
}

// ---------------------------------------------------------------------------
// ability_is_unlocked(ability_name)
// True when the ability is available to slot: free starters always; vex-gated
// once purchased (global.unlocked_abilities); goal-gated once the goal is met.
// Ability names are unique across all pools, so a name lookup is safe.
// ---------------------------------------------------------------------------
function ability_is_unlocked(ability_name) {
    var _info = ability_unlock_info(ability_name);
    if (_info == undefined) return true;   // free starter

    if (_info.type == "vex") {
        if (variable_global_exists("unlocked_abilities")) {
            for (var _i = 0; _i < array_length(global.unlocked_abilities); _i++) {
                if (global.unlocked_abilities[_i] == ability_name) return true;
            }
        }
        return false;
    }
    if (_info.type == "goal") return goal_met(_info.goal_type, _info.goal_value);
    return false;
}

// ---------------------------------------------------------------------------
// abilities_class_pool(class_id) - the full selectable pool for a class: its own
// abilities followed by the shared general pool. Used everywhere the loadout
// screen builds its ability list so general abilities are always slottable.
// ---------------------------------------------------------------------------
function abilities_class_pool(class_id) {
    var _pool;
    switch (class_id) {
        case 0:  _pool = global.abilities_arcanist;      break;
        case 1:  _pool = global.abilities_bloodwarden;   break;
        case 2:  _pool = global.abilities_shadowstrider; break;
        default: _pool = global.abilities_arcanist;
    }
    var _out = [];
    for (var _i = 0; _i < array_length(_pool); _i++) array_push(_out, _pool[_i]);
    if (variable_global_exists("abilities_general")) {
        for (var _g = 0; _g < array_length(global.abilities_general); _g++) {
            array_push(_out, global.abilities_general[_g]);
        }
    }
    return _out;
}

// ---------------------------------------------------------------------------
// class_vex_purchasable(class_id) - locked vex-gated abilities offered for sale
// at Vex (class pool + general pool, vex-type only, not yet bought). Goal-gated
// abilities never appear here - they unlock on their own.
// ---------------------------------------------------------------------------
function class_vex_purchasable(class_id) {
    var _pool = abilities_class_pool(class_id);
    var _out  = [];
    for (var _i = 0; _i < array_length(_pool); _i++) {
        var _ab   = _pool[_i];
        var _info = ability_unlock_info(_ab.name);
        if (_info != undefined && _info.type == "vex" && !ability_is_unlocked(_ab.name)) {
            array_push(_out, _ab);
        }
    }
    return _out;
}

// =============================================================================
// VEX TRAIT TRAINER - traits are bought from Vex (gold + a rarity-matched item)
// instead of unlocking free at progression milestones. The 3 default traits
// (Sense / Scavenger / Thick Skin, unlock_type "default") remain free at start.
// =============================================================================

// trait_get_by_name(name) - the trait struct from global.traits_all, or undefined.
function trait_get_by_name(trait_name) {
    if (!variable_global_exists("traits_all")) return undefined;
    for (var _i = 0; _i < array_length(global.traits_all); _i++) {
        if (global.traits_all[_i].name == trait_name) return global.traits_all[_i];
    }
    return undefined;
}

// trait_is_unlocked(name) - true for default traits, or when its effect_id flag is
// set in global.traits_unlocked (a Vex purchase is the only thing that sets it now).
function trait_is_unlocked(trait_name) {
    var _t = trait_get_by_name(trait_name);
    if (_t == undefined) return false;
    if (_t.unlock_type == "default") return true;
    if (!variable_global_exists("traits_unlocked")) return false;
    if (!variable_struct_exists(global.traits_unlocked, _t.effect_id)) return false;
    return variable_struct_get(global.traits_unlocked, _t.effect_id);
}

// trait_unlock_tier(name) - 1/2/3 price tier (see SYSTEMS_VEX_REWORK.md). Anything
// not listed defaults to tier 2.
function trait_unlock_tier(trait_name) {
    switch (trait_name) {
        // Tier 1 - utility / economy
        case "Quick Recovery": case "Treasure Hunter": case "Lucky Find":
        case "Salvager": case "Prospector":
            return 1;
        // Tier 3 - powerful / build-defining
        case "Focused Power": case "Chain Caster": case "Plaguebearer":
        case "Arcane Surge": case "Berserker Rage": case "Serrated Strikes":
            return 3;
    }
    return 2;
}

// trait_unlock_cost(name) - { gold, min_rarity, item_label } for a Vex purchase.
// min_rarity: 1 uncommon+, 2 rare+, 4 legendary.
function trait_unlock_cost(trait_name) {
    // Gold is CHA-discounted (the item requirement is unaffected).
    switch (trait_unlock_tier(trait_name)) {
        case 1: return { gold:cha_price(200), min_rarity:1, item_label:"Uncommon" };
        case 3: return { gold:cha_price(500), min_rarity:4, item_label:"Legendary" };
    }
    return { gold:cha_price(350), min_rarity:2, item_label:"Rare" };
}

// trait_vex_purchasable(class_id) - traits Vex offers for the current class: not a
// default starter, class-appropriate (universal or matching class), not yet owned.
function trait_vex_purchasable(class_id) {
    var _out = [];
    if (!variable_global_exists("traits_all")) return _out;
    for (var _i = 0; _i < array_length(global.traits_all); _i++) {
        var _t = global.traits_all[_i];
        if (_t.unlock_type == "default") continue;
        if (_t.class_req != -1 && _t.class_req != class_id) continue;
        if (trait_is_unlocked(_t.name)) continue;
        array_push(_out, _t);
    }
    return _out;
}

// ---------------------------------------------------------------------------
// ability_in_loadout(name) - true when the ability is in the confirmed loadout.
// ---------------------------------------------------------------------------
function ability_in_loadout(ability_name) {
    if (!variable_global_exists("player_loadout")) return false;
    for (var _i = 0; _i < array_length(global.player_loadout); _i++) {
        if (global.player_loadout[_i] == ability_name) return true;
    }
    return false;
}

// ---------------------------------------------------------------------------
// loadout_list_scroll(cursor, pool_sz, max_vis)
// Scroll offset (index of the first visible row) for the loadout ability list,
// which can now exceed the screen with the general pool + expansion abilities.
// Shared by the renderer (Draw_64) and the mouse hit-test (Step_0) so the two
// always agree on which row sits at which y. The list stays put until the cursor
// nears the bottom of the window, then scrolls to keep the cursor visible.
// ---------------------------------------------------------------------------
function loadout_list_scroll(cursor, pool_sz, max_vis) {
    if (pool_sz <= max_vis) return 0;
    var _cur = clamp(cursor, 0, pool_sz - 1);
    if (_cur <= max_vis - 2) return 0;
    return min(_cur - (max_vis - 2), pool_sz - max_vis);
}

// ---------------------------------------------------------------------------
// class_locked_abilities(class_id)
// Returns the ability structs for the given class that are not yet unlocked -
// i.e. the rows Vex offers for purchase.
// ---------------------------------------------------------------------------
function class_locked_abilities(class_id) {
    var _pool;
    switch (class_id) {
        case 0:  _pool = global.abilities_arcanist;      break;
        case 1:  _pool = global.abilities_bloodwarden;   break;
        case 2:  _pool = global.abilities_shadowstrider; break;
        default: _pool = global.abilities_arcanist;
    }
    var _locked = [];
    for (var _i = 0; _i < array_length(_pool); _i++) {
        if (!ability_is_unlocked(_pool[_i].name)) array_push(_locked, _pool[_i]);
    }
    return _locked;
}

// ---------------------------------------------------------------------------
// trait_upgradable_list()
// The traits whose magnitude scales with potency, each tied to ONE permanent
// stat that is sacrificed to power it. Boolean traits are not upgradable.
// ---------------------------------------------------------------------------
function trait_upgradable_list() {
    return [
        { name: "Thick Skin",       stat: "CON", effect: "+10% max HP while equipped" },
        { name: "Scavenger",        stat: "CHA", effect: "+15% gold from all sources" },
        { name: "Quick Recovery",   stat: "WIS", effect: "Rest rooms heal 25 HP" },
        { name: "Arcane Surge",     stat: "INT", effect: "+25% dmg on 4+ AP abilities" },
        { name: "Berserker Rage",   stat: "STR", effect: "+20% dmg below 40% HP" },
        { name: "Serrated Strikes", stat: "DEX", effect: "Free 3 dmg bleed on phys hits" },
        { name: "Vampiric Edge",    stat: "CON", effect: "+2 HP per bleed/poison tick" },
    ];
}

// ---------------------------------------------------------------------------
// perm_bonus_key(stat) - maps a 3-letter stat to its global.perm_*_bonus name.
// ---------------------------------------------------------------------------
function perm_bonus_key(stat) {
    switch (stat) {
        case "STR": return "perm_str_bonus";
        case "DEX": return "perm_dex_bonus";
        case "CON": return "perm_con_bonus";
        case "INT": return "perm_int_bonus";
        case "WIS": return "perm_wis_bonus";
        case "CHA": return "perm_cha_bonus";
    }
    return "";
}

// ---------------------------------------------------------------------------
// stat_available_points(stat) - PERMANENT points the player can sacrifice for a
// trait-potency upgrade: the starting allocation (global.chosen_stats) PLUS the
// permanently-bought bonus (perm_<stat>_bonus). Per-run XP bonuses are excluded
// (they reset each run). Lets Vex spend down even your starting stats.
// ---------------------------------------------------------------------------
function stat_available_points(stat) {
    var _base = 0;
    if (variable_global_exists("chosen_stats") && is_struct(global.chosen_stats)
        && variable_struct_exists(global.chosen_stats, stat)) {
        _base = variable_struct_get(global.chosen_stats, stat);
    }
    var _pkey = perm_bonus_key(stat);
    var _perm = (_pkey != "" && variable_global_exists(_pkey)) ? variable_global_get(_pkey) : 0;
    return _base + _perm;
}

// ---------------------------------------------------------------------------
// stat_spend_permanent(stat, amount) - permanently remove `amount` points from a
// stat, draining the bought bonus (perm_<stat>_bonus) FIRST, then dipping into the
// starting allocation (chosen_stats), floored at 0 so derived stats never go
// negative. Returns the amount actually spent.
// ---------------------------------------------------------------------------
function stat_spend_permanent(stat, amount) {
    var _remain = amount;
    var _pkey = perm_bonus_key(stat);
    if (_pkey != "" && variable_global_exists(_pkey)) {
        var _perm = variable_global_get(_pkey);
        var _take = min(_perm, _remain);
        variable_global_set(_pkey, _perm - _take);
        _remain -= _take;
    }
    if (_remain > 0 && variable_global_exists("chosen_stats") && is_struct(global.chosen_stats)
        && variable_struct_exists(global.chosen_stats, stat)) {
        var _base  = variable_struct_get(global.chosen_stats, stat);
        var _take2 = min(_base, _remain);
        variable_struct_set(global.chosen_stats, stat, _base - _take2);
        _remain -= _take2;
    }
    return amount - _remain;
}

// ---------------------------------------------------------------------------
// trait_potency_tier(trait_name) - current potency tier (0-5) for a trait.
// trait_potency_mult(trait_name) - magnitude multiplier: 1 + 0.10 per tier.
// Multiply a trait's base magnitude by this at each effect site.
// ---------------------------------------------------------------------------
function trait_potency_tier(trait_name) {
    if (!variable_global_exists("trait_potency")) return 0;
    if (!variable_struct_exists(global.trait_potency, trait_name)) return 0;
    return variable_struct_get(global.trait_potency, trait_name);
}

function trait_potency_mult(trait_name) {
    return 1 + 0.10 * trait_potency_tier(trait_name);
}

// trait_maxhp_mult() - STATIC max-HP multiplier from equipped traits. Thick Skin
// is a flat +10% max HP (scaled by its Vex potency) while equipped - NOT a per-
// combat heal. Applied identically in obj_combat_controller/Create and in
// out_of_combat_max_hp() so the floor/hub HP readout matches the in-fight bar.
function trait_maxhp_mult() {
    var _m = 1.0;
    if (trait_active("Thick Skin")) _m *= 1 + 0.10 * trait_potency_mult("Thick Skin");
    return _m;
}

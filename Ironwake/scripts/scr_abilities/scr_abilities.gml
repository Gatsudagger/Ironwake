// =============================================================================
// scr_abilities.gml
// Ability data structures and resolution logic for Ironwake.
//
// Ability field reference:
//   name             string  — display name
//   energy_cost      int     — energy spent on cast (1–3)
//   secondary_cost   int     — Souls / Blood / Preparation spent (0 = none)
//   base_damage      int     — raw damage before mitigation (0 = no damage)
//   damage_type      int     — 0=physical, 1=elemental, 2=drain
//   base_acc         int     — flat accuracy added to hit roll; -1 = not applicable
//   guaranteed_hit   bool    — bypasses the hit roll entirely
//   crit_type        int     — 0=power(STR), 1=precision(DEX), 2=arcane(INT),
//                              3=effect(WIS), -1=no crit
//   base_crit        real    — flat crit% added to the stat-based roll (0 = no crit)
//   effect_type      string  — "none","damage","heal","shield","debuff","dot",
//                              "status","resource","passive"
//   effect_value     real    — heal amount / shield HP / debuff magnitude / etc.
//   effect_duration  int     — turns the effect lasts (0 = instant)
//   self_targeted    bool    — ability targets the caster rather than an enemy
//
// Secondary resource mapping (mirrors scr_stats class IDs):
//   Arcanist (0)     → souls
//   Bloodwarden (1)  → blood
//   Shadowstrider(2) → preparation
// =============================================================================

// ---------------------------------------------------------------------------
// ability_define(...)
// Factory function — returns a fully populated ability struct.
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

    // Secondary resource check — only relevant when cost > 0
    if (ability.secondary_cost > 0) {
        if      (variable_struct_exists(caster, "souls")       && caster.souls       < ability.secondary_cost) return false;
        else if (variable_struct_exists(caster, "blood")       && caster.blood       < ability.secondary_cost) return false;
        else if (variable_struct_exists(caster, "preparation") && caster.preparation < ability.secondary_cost) return false;
    }

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
// Single source of truth — used by obj_combat_controller Create and the
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
// desc_short: one readable line shown in the list row (≤50 chars)
// desc_full:  1-2 sentences for the description box — what it does and when to use it
global.abilities_arcanist = [
    // 0: Soulfire — aggressive generator: hits hard AND builds Souls each cast.
    //    Niche: spam for damage and soul generation; pairs with Arcane Burst.
    ability_define("Soulfire",
        /*energy*/1, /*secondary*/0,
        /*damage*/15, /*dtype*/1,       // elemental
        /*acc*/85, /*guaranteed*/false,
        /*crit_type*/1, /*base_crit*/8, // precision (DEX)
        /*effect_type*/"resource", /*effect_value*/2, /*duration*/0, // +2 Souls on cast
        /*self*/false),

    // 1: Void Drain — sustain option: lower damage but heals, guaranteed, bypasses armor.
    //    Niche: spend 2 energy to recover HP safely; not a soul generator.
    ability_define("Void Drain",
        /*energy*/2, /*secondary*/0,
        /*damage*/8, /*dtype*/2,        // drain — bypasses all mitigation
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/-1, /*base_crit*/0,
        /*effect_type*/"heal", /*effect_value*/8, /*duration*/0,
        /*self*/false),

    // 2: Arcane Burst — big nuke; costs a Soul, high arcane crit ceiling
    ability_define("Arcane Burst",
        /*energy*/3, /*secondary*/1,
        /*damage*/28, /*dtype*/1,       // elemental
        /*acc*/80, /*guaranteed*/false,
        /*crit_type*/2, /*base_crit*/12, // arcane (INT) + 2 el stacks on crit
        /*effect_type*/"damage", /*effect_value*/0, /*duration*/0,
        /*self*/false),

    // 3: Soul Harvest — passive; logic triggered by the combat engine on-kill
    ability_define("Soul Harvest",
        /*energy*/0, /*secondary*/0,
        /*damage*/0, /*dtype*/0,
        /*acc*/-1, /*guaranteed*/false,
        /*crit_type*/-1, /*base_crit*/0,
        /*effect_type*/"resource", /*effect_value*/2, /*duration*/0, // +2 souls
        /*self*/true),

    // 4: Blink — spend 1 energy to go untargetable for 2 incoming attacks (charge-based).
    //    effect_value = initial charge count; combat_check_blink() in scr_combat decrements
    //    untargetable_turns per attack absorbed and clears is_untargetable at 0.
    ability_define("Blink",
        /*energy*/1, /*secondary*/0,
        /*damage*/0, /*dtype*/0,
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/-1, /*base_crit*/0,
        /*effect_type*/"status", /*effect_value*/2, /*duration*/2, // 2 charges; absorbs 2 attacks
        /*self*/true),

    // 5: Curse — WIS crit improves status quality; debuffs incoming damage
    ability_define("Curse",
        /*energy*/2, /*secondary*/0,
        /*damage*/0, /*dtype*/0,
        /*acc*/75, /*guaranteed*/false,
        /*crit_type*/3, /*base_crit*/0, // effect (WIS) — no base_crit, formula uses 5+WIS*1.5
        /*effect_type*/"debuff", /*effect_value*/4, /*duration*/3, // +4 damage taken
        /*self*/false),

    // 6: Soul Shield — costs 1 Soul, absorbs 10 HP of incoming damage
    ability_define("Soul Shield",
        /*energy*/1, /*secondary*/1,
        /*damage*/0, /*dtype*/0,
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/-1, /*base_crit*/0,
        /*effect_type*/"shield", /*effect_value*/10, /*duration*/0,
        /*self*/true),

    // 7: Entropy — damage-over-time, WIS crit can upgrade stack quality
    ability_define("Entropy",
        /*energy*/2, /*secondary*/0,
        /*damage*/0, /*dtype*/0,
        /*acc*/78, /*guaranteed*/false,
        /*crit_type*/3, /*base_crit*/0, // effect (WIS)
        /*effect_type*/"dot", /*effect_value*/6, /*duration*/4, // 6 dmg/turn × 4 turns
        /*self*/false),

    // 8: Rift — Soul-fuelled AoE; arcane crit adds elemental stacks to all targets
    ability_define("Rift",
        /*energy*/3, /*secondary*/2,
        /*damage*/20, /*dtype*/1,       // elemental
        /*acc*/88, /*guaranteed*/false,
        /*crit_type*/2, /*base_crit*/6, // arcane (INT)
        /*effect_type*/"damage", /*effect_value*/0, /*duration*/0, // hits all enemies
        /*self*/false),

    // 9: Soulbind — ties enemy fate to caster; reflects 40% damage for full combat
    ability_define("Soulbind",
        /*energy*/2, /*secondary*/1,
        /*damage*/0, /*dtype*/0,
        /*acc*/72, /*guaranteed*/false,
        /*crit_type*/3, /*base_crit*/0, // effect (WIS)
        /*effect_type*/"status", /*effect_value*/0.4, /*duration*/-1, // -1 = combat-long
        /*self*/false),
];

// Plain-English descriptions for Arcanist abilities
var _arc_d = [
    { s: "Deal 15 elemental dmg. Gain +2 Soul.",
      f: "A quick elemental blast that also fills your Soul reserve. Cheap to cast — spam it to fuel bigger spells on the next turn." },
    { s: "Deal 8 drain dmg. Heal 8 HP. Always hits.",
      f: "A guaranteed drain that heals you as much as it deals. Bypasses armor entirely. Costs 2 energy — use it when you need to stay alive." },
    { s: "Spend 1 Soul. Deal 28 elemental dmg.",
      f: "Your big nuke. Costs 1 Soul for a massive elemental hit with a strong arcane crit chance. Save it for tough or high-HP enemies." },
    { s: "0 AP cost. Gain +2 Soul instantly.",
      f: "Costs zero AP — cast it for free and keep your other abilities available this turn. One use per turn. Save it to top off your Soul reserve before an Arcane Burst." },
    { s: "Go untargetable for the next 2 hits.",
      f: "Spend 1 energy to phase out completely. The next 2 enemy attacks pass through you. Use it before a telegraph or a hard-hitting turn." },
    { s: "Target takes +4 dmg from all hits for 3 turns.",
      f: "A debuff that amplifies all incoming damage to the target. Strong when you have multiple damage sources or DoTs ticking per turn." },
    { s: "Spend 1 Soul. Absorb 10 incoming dmg.",
      f: "Converts 1 Soul into a 10 HP damage buffer. Cheap protection — cast it when your Soul bar is stocked and you expect a big hit." },
    { s: "Apply poison: 6 dmg/turn for 4 turns.",
      f: "No upfront damage, but 24 total if the target lives long enough. Best on tough enemies you plan to wear down over several turns." },
    { s: "Spend 2 Souls. Deal 20 elemental dmg to all enemies.",
      f: "An AoE nuke that hits every enemy at once. High Soul cost — save it for multi-enemy fights or finishing off a weakened group." },
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
    // 0: Blood Leech — reliable drain + heal to sustain
    ability_define("Blood Leech",
        /*energy*/1, /*secondary*/0,
        /*damage*/10, /*dtype*/2,       // drain
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/-1, /*base_crit*/0,
        /*effect_type*/"heal", /*effect_value*/8, /*duration*/0,
        /*self*/false),

    // 1: Iron Skin — flat damage reduction for 3 turns
    ability_define("Iron Skin",
        /*energy*/2, /*secondary*/0,
        /*damage*/0, /*dtype*/0,
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/-1, /*base_crit*/0,
        /*effect_type*/"shield", /*effect_value*/4, /*duration*/3, // -4 incoming dmg
        /*self*/true),

    // 2: Gore Strike — physical hit + bleed DoT; power crit spike
    ability_define("Gore Strike",
        /*energy*/2, /*secondary*/0,
        /*damage*/14, /*dtype*/0,       // physical
        /*acc*/82, /*guaranteed*/false,
        /*crit_type*/0, /*base_crit*/10, // power (STR)
        /*effect_type*/"dot", /*effect_value*/3, /*duration*/4, // bleed 3/turn × 4
        /*self*/false),

    // 3: Blood Surge — spend 2 Blood to heal immediately
    ability_define("Blood Surge",
        /*energy*/0, /*secondary*/2,
        /*damage*/0, /*dtype*/0,
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/-1, /*base_crit*/0,
        /*effect_type*/"heal", /*effect_value*/14, /*duration*/0,
        /*self*/true),

    // 4: Marrow Crush — heavy physical hit + 30% damage debuff on target
    ability_define("Marrow Crush",
        /*energy*/3, /*secondary*/0,
        /*damage*/18, /*dtype*/0,       // physical
        /*acc*/78, /*guaranteed*/false,
        /*crit_type*/0, /*base_crit*/14, // power (STR)
        /*effect_type*/"debuff", /*effect_value*/0.3, /*duration*/3, // -30% damage dealt
        /*self*/false),

    // 5: Vital Theft — drain hit + steal 8 max HP from target for combat
    ability_define("Vital Theft",
        /*energy*/2, /*secondary*/1,
        /*damage*/8, /*dtype*/2,        // drain
        /*acc*/80, /*guaranteed*/false,
        /*crit_type*/-1, /*base_crit*/0,
        /*effect_type*/"status", /*effect_value*/8, /*duration*/-1, // -8 max HP combat-long
        /*self*/false),

    // 6: Bloodthorn Aura — thorns effect; returns damage when struck
    ability_define("Bloodthorn Aura",
        /*energy*/2, /*secondary*/0,
        /*damage*/0, /*dtype*/0,
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/-1, /*base_crit*/0,
        /*effect_type*/"status", /*effect_value*/5, /*duration*/4, // reflect 5 dmg/hit × 4 turns
        /*self*/true),

    // 7: Undying — ultimate safety net; costs 3 Blood; survive lethal blow at 1 HP
    ability_define("Undying",
        /*energy*/3, /*secondary*/3,
        /*damage*/0, /*dtype*/0,
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/-1, /*base_crit*/0,
        /*effect_type*/"status", /*effect_value*/1, /*duration*/1, // survive lethal at 1 HP this turn
        /*self*/true),

    // 8: Plague Touch — WIS crit improves debuff; halves enemy healing for 5 turns
    ability_define("Plague Touch",
        /*energy*/1, /*secondary*/0,
        /*damage*/0, /*dtype*/0,
        /*acc*/76, /*guaranteed*/false,
        /*crit_type*/3, /*base_crit*/0, // effect (WIS)
        /*effect_type*/"debuff", /*effect_value*/0.5, /*duration*/5, // -50% healing received
        /*self*/false),

    // 9: Bloodfeast — every ability drains 6 HP from targets for 2 turns
    ability_define("Bloodfeast",
        /*energy*/3, /*secondary*/2,
        /*damage*/0, /*dtype*/0,
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/-1, /*base_crit*/0,
        /*effect_type*/"status", /*effect_value*/6, /*duration*/2, // +6 drain on each ability
        /*self*/true),
];

// Plain-English descriptions for Bloodwarden abilities
var _bw_d = [
    { s: "Deal 10 drain dmg. Heal 8 HP. Always hits.",
      f: "Your bread-and-butter sustain skill. Guaranteed hit, drain bypasses armor, and you heal every cast. Low energy cost — use it freely." },
    { s: "Reduce all incoming dmg by 4 for 3 turns.",
      f: "A flat damage reduction buff on a timer. Cast it before a heavy hit or telegraph — 4 damage off every incoming hit for 3 full turns." },
    { s: "Deal 14 physical dmg. Bleed: 3 dmg/turn for 4 turns.",
      f: "A melee hit that opens a bleed wound. The 12 total bleed damage adds up — strong opener on high-HP targets or bosses." },
    { s: "Spend 2 Blood. Heal 14 HP. Free action.",
      f: "A zero-energy burst heal that costs only Blood. Perfect for recovering mid-fight when your Blood reserve is stocked." },
    { s: "Deal 18 physical dmg. Target deals 30% less dmg for 3 turns.",
      f: "A heavy hit that also cuts the target's damage output. Use it on the hardest-hitting enemy to reduce the pressure on yourself." },
    { s: "Spend 1 Blood. Drain 8 HP. Reduce target max HP by 8.",
      f: "Permanently lowers the enemy's maximum HP for this combat. Combine with Gore Strike's bleed to whittle down a boss faster." },
    { s: "Return 5 dmg to each attacker per hit for 4 turns.",
      f: "A thorns buff that punishes every incoming attack. Pairs well with Iron Skin — you reduce their damage while they take damage for hitting you." },
    { s: "Spend 3 Blood. Survive one lethal hit at 1 HP this turn.",
      f: "An emergency safety net that guarantees you survive one killing blow per cast. Burn it the moment death is imminent." },
    { s: "Target heals 50% less for 5 turns.",
      f: "Neutralizes enemy healing for extended fights. Low energy cost and a wide 5-turn window — cast it early on any regenerating enemy." },
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
    // 0: Snipe — high base ACC + precision crit; bonus damage when target is debuffed
    //    (effect_value stores the 20 bonus damage; caller checks debuff state)
    ability_define("Snipe",
        /*energy*/1, /*secondary*/0,
        /*damage*/14, /*dtype*/0,       // physical
        /*acc*/90, /*guaranteed*/false,
        /*crit_type*/1, /*base_crit*/15, // precision (DEX)
        /*effect_type*/"damage", /*effect_value*/20, /*duration*/0, // +20 if target debuffed
        /*self*/false),

    // 1: Bear Trap — place trap (costs 1 Prep); triggers with guaranteed hit + root
    ability_define("Bear Trap",
        /*energy*/2, /*secondary*/1,
        /*damage*/16, /*dtype*/0,       // physical
        /*acc*/-1, /*guaranteed*/true,  // guaranteed on trigger
        /*crit_type*/1, /*base_crit*/8, // precision (DEX)
        /*effect_type*/"status", /*effect_value*/1, /*duration*/1, // root 1 turn
        /*self*/false),

    // 2: Shadow Step — dodge next single-target attack entirely
    ability_define("Shadow Step",
        /*energy*/1, /*secondary*/0,
        /*damage*/0, /*dtype*/0,
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/-1, /*base_crit*/0,
        /*effect_type*/"status", /*effect_value*/1, /*duration*/1, // dodge next single-target
        /*self*/true),

    // 3: Poison Dart — low upfront damage; DoT does the real work.
    //    Niche: apply sustained poison at the same energy cost as Snipe.
    //    Crit bumped to 10 so it crits at a reasonable rate despite lower base damage;
    //    crit still trails Snipe (15) to preserve Snipe's identity as the precision burst.
    ability_define("Poison Dart",
        /*energy*/1, /*secondary*/0,
        /*damage*/6, /*dtype*/0,        // physical
        /*acc*/88, /*guaranteed*/false,
        /*crit_type*/1, /*base_crit*/10, // precision (DEX); was 6
        /*effect_type*/"dot", /*effect_value*/5, /*duration*/4, // poison 5/turn × 4
        /*self*/false),

    // 4: Smoke Bomb — AoE accuracy debuff; WIS crit can upgrade duration/magnitude
    ability_define("Smoke Bomb",
        /*energy*/2, /*secondary*/1,
        /*damage*/0, /*dtype*/0,
        /*acc*/-1, /*guaranteed*/false,
        /*crit_type*/3, /*base_crit*/0, // effect (WIS)
        /*effect_type*/"debuff", /*effect_value*/0.4, /*duration*/2, // -40% ACC all enemies
        /*self*/false),

    // 5: Crippling Shot — physical hit + slow and damage reduction debuff
    ability_define("Crippling Shot",
        /*energy*/2, /*secondary*/0,
        /*damage*/10, /*dtype*/0,       // physical
        /*acc*/84, /*guaranteed*/false,
        /*crit_type*/1, /*base_crit*/8, // precision (DEX)
        /*effect_type*/"debuff", /*effect_value*/0.25, /*duration*/3, // -25% dmg + slow
        /*self*/false),

    // 6: Spike Trap — heavy trap; guaranteed on trigger; bleed stacks twice
    ability_define("Spike Trap",
        /*energy*/3, /*secondary*/2,
        /*damage*/22, /*dtype*/0,       // physical
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/1, /*base_crit*/10, // precision (DEX)
        /*effect_type*/"dot", /*effect_value*/6, /*duration*/4, // bleed ×2 stacks
        /*self*/false),

    // 7: Marked for Death — no damage; WIS crit upgrades mark quality
    //    effect_value = 8 bonus damage per hit; effect_duration = 4 turns / 3 hits max
    ability_define("Marked for Death",
        /*energy*/1, /*secondary*/0,
        /*damage*/0, /*dtype*/0,
        /*acc*/86, /*guaranteed*/false,
        /*crit_type*/3, /*base_crit*/0, // effect (WIS)
        /*effect_type*/"debuff", /*effect_value*/8, /*duration*/4, // +8/hit up to 3 hits or 4 turns
        /*self*/false),

    // 8: Evasive Roll — reactive: halve next hit above 10 damage; costs 2 Prep
    ability_define("Evasive Roll",
        /*energy*/0, /*secondary*/2,
        /*damage*/0, /*dtype*/0,
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/-1, /*base_crit*/0,
        /*effect_type*/"status", /*effect_value*/10, /*duration*/1, // halve hits >10 dmg
        /*self*/true),

    // 9: Death Snare — apex trap; guaranteed trigger, stun 2 turns, top precision crit
    ability_define("Death Snare",
        /*energy*/3, /*secondary*/2,
        /*damage*/28, /*dtype*/0,       // physical
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/1, /*base_crit*/14, // precision (DEX)
        /*effect_type*/"status", /*effect_value*/1, /*duration*/2, // stun 2 turns
        /*self*/false),
];

// Plain-English descriptions for Shadowstrider abilities
var _ss_d = [
    { s: "Deal 14 physical dmg. +20 bonus dmg if target is debuffed.",
      f: "High accuracy and a strong precision crit. Deals a big bonus on debuffed targets — set up Marked for Death or Smoke Bomb first, then fire." },
    { s: "Spend 1 Prep. Trap fires: 16 dmg + root for 1 turn.",
      f: "A guaranteed-hit trap that also immobilizes the target for a turn. Plant it at the start of combat and let the enemy walk into it." },
    { s: "Dodge the very next single-target attack.",
      f: "A reactive dodge on a 1-energy budget. Use it right before a telegraph resolves or whenever you predict the next attack will hit hard." },
    { s: "Deal 6 physical dmg. Poison: 5 dmg/turn for 4 turns.",
      f: "Low upfront damage but 20 total over time. Cheap to cast — apply it early and let the poison tick while you use other abilities." },
    { s: "Spend 1 Prep. All enemies hit 40% less often for 2 turns.",
      f: "A group accuracy debuff that buys you breathing room. Cast it before a risky turn or when you need to set up traps without taking a beating." },
    { s: "Deal 10 physical dmg. Target deals 25% less dmg for 3 turns.",
      f: "A reliable hit with a lasting damage debuff. Reduces the most dangerous enemy's output for several turns — use it early." },
    { s: "Spend 2 Prep. Trap fires: 22 dmg + bleed 6/turn × 4 turns.",
      f: "Your most powerful trap. Heavy damage and a punishing bleed — the Preparation cost is worth it on elites and the boss." },
    { s: "All hits on target deal +8 bonus dmg for up to 4 turns.",
      f: "A mark that amplifies every attack landing on the target. Apply it early and then stack Snipe and traps on top to maximize the window." },
    { s: "Spend 2 Prep. Next hit above 10 dmg is halved.",
      f: "No energy cost — just Preparation. Hold it in reserve for telegraphed heavy hits. Has no effect on weak attacks below 10 damage." },
    { s: "Spend 2 Prep. Trap fires: 28 dmg + stun for 2 turns.",
      f: "The apex trap. Guaranteed massive damage and a 2-turn stun. Save your Preparation for this before elite rooms and boss fights." },
];
for (var _i = 0; _i < 10; _i++) {
    global.abilities_shadowstrider[_i].desc_short = _ss_d[_i].s;
    global.abilities_shadowstrider[_i].desc_full  = _ss_d[_i].f;
}


// =============================================================================
// TRAIT SYSTEM
// Traits are passive bonuses unlocked through play and chosen at the Dungeon
// Gate before each run (up to 2 active at once via global.player_traits).
//
// Trait field reference:
//   name         string  — display name; also the key stored in player_traits
//   description  string  — one-line effect summary shown in the gate overlay
//   class_req    int     — -1 = any class, 0/1/2 = class-specific
//   unlock_type  string  — "default", "full_clear", "char_level", "boss_kill"
//   unlock_value real    — threshold relevant to unlock_type (0 if not used)
//   effect_id    string  — snake_case key in global.traits_unlocked struct
// =============================================================================

// ---------------------------------------------------------------------------
// trait_define(...)
// Factory function — returns a fully populated trait struct.
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
    return (global.player_traits[0] == trait_name
         || global.player_traits[1] == trait_name);
}

// ---------------------------------------------------------------------------
// TRAIT DEFINITIONS
// Three universals unlock by default.  The other five require progression.
// ---------------------------------------------------------------------------
global.traits_all = [
    // Universal — available to all classes, unlocked from the start
    trait_define("Sense",
        "Reveals path difficulty, loot quality, and rare spawns on the floor map.",
        -1, "default", 0, "sense"),

    trait_define("Scavenger",
        "+15% gold from all sources.",
        -1, "default", 0, "scavenger"),

    trait_define("Thick Skin",
        "+10% maximum HP at the start of each combat.",
        -1, "default", 0, "thick_skin"),

    // Universal — unlocked through play
    trait_define("Lucky Find",
        "+5% consumable drop chance from all enemies.",
        -1, "full_clear", 1, "lucky_find"),

    trait_define("Salvager",
        "Keep 2 random carried items on death instead of 1.",
        -1, "char_level", 5, "salvager"),

    // Class traits — unlocked by defeating Malgrath (floor 3 boss) with any class
    trait_define("Soul Siphon",
        "Gain +1 Soul whenever an enemy dies (Arcanist only).",
        0, "boss_kill", 1, "soul_siphon"),

    trait_define("Crimson Reserve",
        "Start each combat with +20 Blood (Bloodwarden only).",
        1, "boss_kill", 1, "crimson_reserve"),

    trait_define("Phantom Step",
        "The first enemy attack each combat automatically misses (Shadowstrider only).",
        2, "boss_kill", 1, "phantom_step"),
];

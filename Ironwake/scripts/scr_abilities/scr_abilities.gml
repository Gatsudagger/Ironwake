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
// Opening Gambit on a FREE (0-AP) ability (07-29 M pass): the web keystone's
// AP discount has nothing to discount there, so on those abilities the FIRST
// cast each combat waives the secondary-resource cost instead (e.g. Blood
// Surge's 2 Blood). Checked by the resource gate AND the spend so they can
// never disagree.
function ability_gambit_waives_secondary(ability, caster) {
    if (is_undefined(caster)) return false;
    return ability.energy_cost <= 0 && ability.secondary_cost > 0
        && ability_web_copy_has_rider(ability, "first_free")
        && !ability_web_first_cast_used(caster, ability.name);
}

function ability_secondary_ok(ability, caster) {
    if (ability.secondary_cost <= 0) return true;
    if (ability_gambit_waives_secondary(ability, caster)) return true;
    // Class-trunk discounts (P2, 08-05) route through the shared effective cost.
    var _sc = ability_secondary_cost_eff(ability, caster);
    if (_sc <= 0) return true;
    if      (variable_struct_exists(caster, "souls"))       return caster.souls       >= _sc;
    else if (variable_struct_exists(caster, "blood"))       return caster.blood       >= _sc;
    else if (variable_struct_exists(caster, "preparation")) return caster.preparation >= _sc;
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

    if (ability.secondary_cost > 0 && !ability_gambit_waives_secondary(ability, caster)) {
        // Class-trunk discounts (P2, 08-05): spend the SAME effective cost the
        // gate checked, never the raw one.
        var _sc = ability_secondary_cost_eff(ability, caster);
        if      (variable_struct_exists(caster, "souls"))       caster.souls       -= _sc;
        else if (variable_struct_exists(caster, "blood"))       caster.blood       -= _sc;
        else if (variable_struct_exists(caster, "preparation")) caster.preparation -= _sc;
        // Red Recycling trunk node: heal 1 HP per Blood actually spent.
        if (_sc > 0 && variable_struct_exists(caster, "blood")
            && variable_struct_exists(caster, "class_id") && caster.class_id == 1
            && trunk_has("blood_spend_heal")
            && variable_struct_exists(caster, "HP") && variable_struct_exists(caster, "max_HP")) {
            caster.HP = min(caster.max_HP, caster.HP + _sc);
        }
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

// abilities_resolve_player_loadout(class_id)
// The player's ACTUAL equipped loadout: resolves the confirmed global.player_loadout
// ability names against the class ability pool (honoring the Expanded Arsenal trait's
// 5th slot), falling back to the class default starters if no valid loadout is set.
// Single source of truth shared by combat (obj_combat_controller Create) AND the
// out-of-combat character menu (scr_ui Abilities tab) so the two never diverge -
// previously the menu called abilities_get_loadout() directly and always showed the
// 4 class starters instead of the real (up to 5) equipped set.
function abilities_resolve_player_loadout(class_id) {
    if (variable_global_exists("player_loadout") && is_array(global.player_loadout)
        && array_length(global.player_loadout) > 0 && global.player_loadout[0] != "") {
        var _pool = abilities_class_pool(class_id);   // class abilities + general pool
        var _max  = trait_active("Expanded Arsenal") ? 5 : 4;
        var _out  = [];
        for (var _li = 0; _li < _max && _li < array_length(global.player_loadout); _li++) {
            var _lname = global.player_loadout[_li];
            if (_lname == "") continue;
            for (var _ai = 0; _ai < array_length(_pool); _ai++) {
                if (_pool[_ai].name == _lname) {
                    // Talent webs: hand out a node-adjusted copy when picks exist.
                    array_push(_out, ability_web_resolve(_pool[_ai]));
                    break;
                }
            }
        }
        if (array_length(_out) >= 4 && array_length(_out) <= _max) return _out;
    }
    // Fallback class defaults get their webs too (same name-keyed picks).
    var _def = abilities_get_loadout(class_id);
    var _dout = [];
    for (var _di = 0; _di < array_length(_def); _di++) array_push(_dout, ability_web_resolve(_def[_di]));
    return _dout;
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
// desc_full:  evocative action line, then "\n" + "- " technical breakdown lines
//             (what it does and when to use it). Rendered via draw_text_ext, so
//             the embedded newlines are safe at both draw sites.
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

    // 5: Curse - Hexed (audit §6): +4 dmg taken, detonations on the target doubled
    // + spread +2 dmg-taken to all other enemies. The Control piece of a detonation build.
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
// Format (flavor pass 7-05): evocative action line, then "\n" + "- " technical
// breakdown lines. School words Capitalized; dtype-1 descs name the resolved
// school (Fire/Arcane), not "elemental".
var _arc_d = [
    { s: "Deal 15 Fire dmg. Gain +2 Souls.",
      f: "Hurl a gout of soulfire that feeds on what it burns.\n- 15 Fire damage. Banks +2 Souls on cast.\n- Cheap to cast - spam it to fuel bigger spells next turn." },
    { s: "1 AP: 8 Void dmg, heal 8, +1 Soul. 2-turn CD.",
      f: "Pull the life out of a foe in one cold breath.\n- Guaranteed 8 Void damage that ignores all armor. Heals you 8 and banks 1 Soul.\n- 1 AP on a 2-turn cooldown - steady sustain, not spam." },
    { s: "Spend 1 Soul. Deal 38 Arcane dmg.",
      f: "Collapse a stored Soul into one roaring detonation of Arcane force.\n- Spend 1 Soul: 38 Arcane damage with a high crit ceiling.\n- Save it for elites and high-HP enemies." },
    { s: "0 AP cost. Gain +2 Souls instantly.",
      f: "Reach out and gather the loose souls the fight has shaken free.\n- Costs no AP: +2 Souls on the spot, once per turn.\n- Top off the reserve before an Arcane Burst or Soul Nova." },
    { s: "Fully dodge the next attack; soften the 2 after. 2-turn CD.",
      f: "Step sideways out of the world and let the blow pass through where you stood.\n- Next incoming attack: fully dodged. The two after: 50% then 25% less damage.\n- One charge is spent per attacking enemy, so it spans a swarm. 2-turn cooldown." },
    { s: "Hex: target takes +4 dmg for 3 turns; detonations x2.",
      f: "Whisper a Shadow hex that opens every seam in their defenses.\n- Hexed: +4 damage taken from all hits for 3 turns.\n- Detonations against the hexed target hit twice as hard and spread +2 damage-taken to every other enemy." },
    { s: "Spend 1 Soul. Absorb 10 dmg, +3 per Soul HELD.",
      f: "Weave a spent Soul into a ward the rest of the reserve strengthens.\n- Spend 1 Soul: a shield absorbs 10 damage, +3 more per Soul still held.\n- The reserve-defense: a stocked Arcanist wards twice as hard. Cast BEFORE dumping Souls." },
    { s: "Void rot that GROWS: 6/8/10/12 dmg over 4 turns.",
      f: "Rot their flesh from the inside and let it worsen with every heartbeat.\n- Void damage over 4 turns that climbs each turn: 6, 8, 10, 12 (36 total).\n- Cast it again while the rot is still ticking to DOUBLE every remaining tick.\n- Detonate it early for a burst that heals you 30% of the damage - at the cost of the big final ticks." },
    { s: "Spend 2 Souls. 20 Arcane to ALL + detonates their statuses.",
      f: "Tear a rift above the field and let the Arcane pour through onto everything.\n- Spend 2 Souls: 20 Arcane damage to every enemy at once - and it DETONATES each enemy's statuses individually.\n- The cascade turn: spread chills, bleeds and hexes, then pull the sky down on all of it." },
    { s: "Spend 1 Soul. Foe takes 40% of dmg YOU take; heals you.",
      f: "Stitch a Shadow thread between your fate and theirs.\n- Combat-long: the bound enemy suffers 40% of every hit you receive, and you heal the same amount.\n- Bind the biggest thing in the room and let it regret hurting you." },
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

    // 7: Undying - ultimate safety net; costs 3 Blood; survive lethal blow at 1 HP.
    //    M 07-16 AP audit: 3 -> 2 AP. Spending a WHOLE turn on not-dying felt dead;
    //    at 2 AP you can still Leech/Cleave the same turn you brace.
    ability_define("Undying",
        /*energy*/2, /*secondary*/3,
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

    // 9: Bloodfeast - every ability drains 6 HP from targets for 2 turns.
    //    M 07-16 AP audit: 3 -> 2 AP. At 3 AP the buff's first turn was always
    //    wasted (no AP left to swing with it) - a setup ability that ate its own payoff.
    ability_define("Bloodfeast",
        /*energy*/2, /*secondary*/2,
        /*damage*/0, /*dtype*/3,        // blood
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/-1, /*base_crit*/0,
        /*effect_type*/"status", /*effect_value*/6, /*duration*/2, // +6 drain on each ability
        /*self*/true),
];

// Plain-English descriptions for Bloodwarden abilities
var _bw_d = [
    { s: "Deal 10 Blood dmg. Heal 8 HP.",
      f: "Open a vein and drink the fight back into yourself.\n- 10 Blood damage, and you heal 8 on the hit.\n- Cheap bread-and-butter sustain - use it freely." },
    { s: "Take -4 dmg from every hit for 3 turns.",
      f: "Set your feet and let your hide turn to metal.\n- Every incoming hit deals 4 less damage for 3 turns.\n- Cast it before a heavy turn or a telegraphed blow." },
    { s: "Deal 14 physical dmg. Bleed: 3 dmg/turn for 4 turns.",
      f: "Rip a jagged wound that keeps bleeding long after the blow lands.\n- 14 physical damage + Bleed 3/turn for 4 turns (12 total).\n- Strong opener on high-HP targets and bosses; feeds Rupture." },
    { s: "Spend 2 Blood. Heal 14 HP. Free action.",
      f: "Command your own blood to close the wound.\n- Costs no AP: spend 2 Blood, heal 14 HP.\n- Mid-fight recovery whenever the reserve is stocked." },
    { s: "Deal 24 physical dmg. Target deals -30% dmg for 3 turns.",
      f: "Bring the full weight of the blow down where the bone is.\n- 24 physical damage. The target deals 30% less damage for 3 turns.\n- Put it on the hardest hitter and take the pressure off yourself." },
    { s: "Spend 1 Blood. 8 Blood dmg. Steal 8 max HP (heal 8).",
      f: "Steal the strength out of a foe and make it your own.\n- 8 Blood damage; the target's max HP drops 8 - and YOUR max HP rises 8 and you heal 8, all for the combat.\n- The theft is real now: gut their pool while you grow yours." },
    { s: "Attackers take 8 dmg per hit for 4 turns.",
      f: "Grow a lattice of thorns from your own spilled blood.\n- Every enemy that hits you takes 8 damage back, for 4 turns.\n- Pair with Iron Skin: they hit softer and bleed for trying." },
    { s: "Spend 3 Blood. Lethal blow: survive at 25% HP, +3 Blood.",
      f: "Plant your feet on the near side of the grave and refuse.\n- The next killing blow fails: you surge back to 25% HP and gain 3 Blood.\n- Fires before Last Stand. Cast it when death is one hit away." },
    { s: "Target heals 50% less for 5 turns.",
      f: "Press a Poisoned palm to them and let the sickness settle in.\n- The target receives 50% less healing for 5 turns.\n- Cast it early on anything that regenerates." },
    { s: "Spend 2 Blood. Abilities drain +6 HP for 2 turns.",
      f: "Give your hunger the reins for a few heartbeats.\n- For 2 turns, every ability you cast also drains 6 HP from its target.\n- Stack with Blood Leech for maximum sustain." },
];
for (var _i = 0; _i < 10; _i++) {
    global.abilities_bloodwarden[_i].desc_short = _bw_d[_i].s;
    global.abilities_bloodwarden[_i].desc_full  = _bw_d[_i].f;
}

// =============================================================================
// DEPLOYED TRAPS (M-approved rework 08-08, SYSTEMS_TRAPS.md)
//
// Traps used to be instant guaranteed-hit attacks that resolved on cast - the
// codebase said so itself ("trap_active is vestigial, traps fire on cast").
// Nothing was ever placed and nothing ever waited, so Shadowstrider played as a
// worse rogue instead of a controller.
//
// Now a trap is DEPLOYED into a slot and sits between the player and the enemy
// until an enemy action matches its trigger filter. The enemy turn already
// classifies incoming actions for Blink/Shadow Step/Counterblade
// (_in_hostile / _in_damaging / _in_reach), so traps hook that same reaction
// stack - no new turn phase and no enemy-AI change.
//
// filter: "melee" | "ranged" | "spell" | "any"   - what springs it
// block:  true  = the incoming attack is cancelled outright (the defensive lever)
// charges: >1 traps survive springing (Caltrops); 1 = consumed
//
// Deploy costs are still the ability's own energy/secondary cost. Payload is
// resolved at SPRING time, not deploy time, so Prep-scaling nodes (Loaded
// Springs) read the Prep you were holding when it actually went off.
// =============================================================================
function trap_catalog() {
    return [
        { name:"Bear Trap",   filter:"melee", block:true,  damage:10, dtype:0, status:"root",    duration:1, charges:1,
          blurb:"Blocks a melee blow and Roots the attacker." },
        { name:"Spike Trap",  filter:"any",   block:false, damage:26, dtype:0, status:"bleed",   duration:4, charges:1,
          blurb:"Springs on anything. Heavy bleed, but does not stop the blow." },
        { name:"Death Snare", filter:"any",   block:true,  damage:20, dtype:0, status:"stun",    duration:2, charges:1,
          blurb:"Blocks any action and Stuns for 2 turns." },
        { name:"Tripline",    filter:"melee", block:true,  damage:0,  dtype:0, status:"exposed", duration:2, charges:1,
          blurb:"No damage - blocks the blow and leaves them Exposed." },
        { name:"Warding Chime",filter:"spell",block:true,  damage:0,  dtype:0, status:"silence", duration:1, charges:1,
          blurb:"Blocks a cast and Silences the caster." },
        // 08-11 (M): was root - but root doesn't stop RANGED attackers, the only
        // thing this trap catches. Blind actually punishes the archer.
        { name:"Wire Snare",  filter:"ranged",block:true,  damage:12, dtype:0, status:"blind",   duration:2, charges:1,
          blurb:"Blocks a shot and Blinds the shooter (-35% accuracy)." },
        { name:"Caltrops",    filter:"any",   block:false, damage:8,  dtype:0, status:"",        duration:0, charges:3,
          blurb:"Springs three times before it is spent. Chip damage, no block." },
    ];
}

function trap_def(_name) {
    var _c = trap_catalog();
    for (var _i = 0; _i < array_length(_c); _i++) if (_c[_i].name == _name) return _c[_i];
    return undefined;
}

function ability_is_trap(_name) {
    return (trap_def(_name) != undefined);
}

// Plain-English label for a filter, used by the log and the trap chips.
function trap_filter_label(_f) {
    switch (_f) {
        case "melee":  return "melee attack";
        case "ranged": return "ranged attack";
        case "spell":  return "spell";
    }
    return "any action";
}

// Deploy capacity. 2 by default; the trunk/web can widen it (SYSTEMS_TRAPS §6).
function trap_slots_max(_p) {
    var _n = 2;
    if (trunk_has("trap_slot_plus")) _n += 1;
    // "Trapper's Bandolier" (P5, Tripline web): +1 slot while the node is woven
    // on any slotted ability. Passive, so it reads the SLOTTED copies (the
    // Shadow Step step_evade idiom), not a cast copy.
    if (is_struct(_p) && variable_struct_exists(_p, "abilities") && is_array(_p.abilities)) {
        for (var _i = 0; _i < array_length(_p.abilities); _i++) {
            if (ability_web_copy_has_rider(_p.abilities[_i], "trap_slots")) { _n += 1; break; }
        }
    }
    if (is_struct(_p) && variable_struct_exists(_p, "trap_slot_bonus")) _n += _p.trap_slot_bonus;
    return max(1, _n);
}

// Spring burst keyed to the trap's PAYLOAD group (SYSTEMS_TRAPS.md anim table,
// 08-11): snapping jaws (Bear/Wire/Tripline), flying shrapnel (Spike/Caltrops),
// ward flash (Warding Chime/Death Snare). All 7 shared spr_vfx_snap before.
function trap_spring_vfx(_name) {
    switch (_name) {
        case "Spike Trap": case "Caltrops":       return spr_vfx_spikes;
        case "Warding Chime": case "Death Snare": return spr_vfx_wardflash;
    }
    return spr_vfx_snap;
}

// P5 (08-11): the payload-group sprite + a per-trap TINT makes all seven
// springs read distinct at zero art cost (the burst draw honors a `col`
// field). Tints follow each trap's prop/icon palette.
function trap_spring_tint(_name) {
    switch (_name) {
        case "Wire Snare":    return make_color_rgb(170, 215, 255);  // cold drawn steel
        case "Tripline":      return make_color_rgb(255, 215, 140);  // brass stakes
        case "Spike Trap":    return make_color_rgb(255, 120, 110);  // bloodied points
        case "Caltrops":      return make_color_rgb(235, 175, 95);   // rusted iron
        case "Warding Chime": return make_color_rgb(150, 235, 255);  // cyan runes
        case "Death Snare":   return make_color_rgb(200, 130, 255);  // verdigris tendrils gone violet
    }
    return c_white;                                                  // Bear Trap: plain steel snap
}

// Does this deployed trap answer that incoming action? Mirrors the reaction
// stack's own classification so the two can never disagree.
function trap_matches(_trap, _hostile, _damaging, _reach, _is_spell) {
    if (!_hostile) return false;                       // never springs on a heal
    switch (_trap.filter) {
        case "melee":  return _damaging && (_reach == "melee");
        case "ranged": return _damaging && (_reach == "ranged");
        case "spell":  return _is_spell;
    }
    return true;                                       // "any"
}

// -----------------------------------------------------------------------------
// SHADOWSTRIDER (class_id 2)
// Secondary resource: Preparation (max 10, starts 0; gains 1/turn while no trap
// is deployed - an empty board refills faster, so over-committing starves you).
// Playstyle: DEPLOY traps that wait for a matching enemy action, then spring.
// The class commits to a PREDICTION in advance and is paid when it reads the
// enemy's intent correctly. See SYSTEMS_TRAPS.md.
// -----------------------------------------------------------------------------
global.abilities_shadowstrider = [
    // 0: Snipe - high base ACC + precision crit; bonus damage when target is debuffed
    //    (effect_value stores the 20 bonus damage; caller checks debuff state)
    ability_define("Snipe",
        /*energy*/1, /*secondary*/0,
        /*damage*/14, /*dtype*/0,       // physical
        /*acc*/90, /*guaranteed*/false,
        /*crit_type*/1, /*base_crit*/15, // precision (DEX)
        /*effect_type*/"damage", /*effect_value*/12, /*duration*/0, // +12 if target debuffed (was 20; 07-17 nerf - "primer+Snipe spam" was the obviously-best line)
        /*self*/false),

    // 1: Bear Trap - place trap (costs 1 Prep); triggers with guaranteed hit + root
    //    07-17: 2 AP -> 1 AP. At 2 AP it was strictly dominated by Spike Trap (~44 dmg);
    //    now the cheap opener trap (16 + root) next to Spike (damage) and Snare (stun).
    // DEPLOYED (08-08): self-targeted so it routes AROUND the instant damage/status
    // path entirely. Payload lives in trap_catalog() and resolves when it SPRINGS.
    ability_define("Bear Trap",
        /*energy*/1, /*secondary*/1,
        /*damage*/0, /*dtype*/0,
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/1, /*base_crit*/8, // precision (DEX)
        /*effect_type*/"trap", /*effect_value*/0, /*duration*/0,
        /*self*/true),

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
    //    P1 RETYPE (08-01, M-approved): truly elemental now - INT gear scales it,
    //    el_resist (not armor) cuts it. +1 base so parity-stat damage is unchanged.
    ability_define("Poison Dart",
        /*energy*/1, /*secondary*/0,
        /*damage*/7, /*dtype*/1,        // elemental (school: poison)
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

    // 5: Frost Shot (renamed from Crippling Shot, combo batch 07-16) - the SS
    //    shatter-primer: physical hit + Weaken, plus a bespoke 1-turn Chill rider
    //    (Step_0) so Shadowstrider has an in-class SHATTER setup. Budget: 10 dmg
    //    + Weaken ~8 + Chill ~6 = 24 on a 2-AP slot.
    //    P1 RETYPE (08-01, M-approved): the exact bug M reported 07-28 - it said
    //    "physical" while wearing a frost school tag. Truly elemental now; +2 base
    //    so parity-stat damage is unchanged, INT investment pure upside.
    ability_define("Frost Shot",
        /*energy*/2, /*secondary*/0,
        /*damage*/12, /*dtype*/1,       // elemental (school: frost)
        /*acc*/84, /*guaranteed*/false,
        /*crit_type*/1, /*base_crit*/8, // precision (DEX)
        /*effect_type*/"debuff", /*effect_value*/0.25, /*duration*/3, // -25% dmg + slow
        /*self*/false),

    // 6: Spike Trap - the BLEED trap (audit §6: was 3AP+2P, strictly dominated by
    // Death Snare at the same cost; now the cheap DoT-build trap vs Snare's control).
    ability_define("Spike Trap",
        /*energy*/2, /*secondary*/1,
        /*damage*/0, /*dtype*/0,
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/1, /*base_crit*/10, // precision (DEX)
        /*effect_type*/"trap", /*effect_value*/0, /*duration*/0,
        /*self*/true),

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
        /*damage*/0, /*dtype*/0,
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/1, /*base_crit*/14, // precision (DEX)
        /*effect_type*/"trap", /*effect_value*/0, /*duration*/0,
        /*self*/true),

    // ---- New deployed traps (08-08, SYSTEMS_TRAPS.md 4). Spread across the
    // filters so which slot you fill is a real decision. Wire Snare and Warding
    // Chime are FREE STARTERS (M 08-08 split): without them the class has no
    // answer at all to archers or casters from level 1. Tripline and Caltrops
    // are bought from Vex. All payload lives in trap_catalog().
    // 10: Tripline - pure defensive stall, no damage.
    ability_define("Tripline",
        /*energy*/1, /*secondary*/1,
        /*damage*/0, /*dtype*/0,
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/-1, /*base_crit*/0,
        /*effect_type*/"trap", /*effect_value*/0, /*duration*/0,
        /*self*/true),

    // 11: Warding Chime - the anti-caster answer the class never had.
    ability_define("Warding Chime",
        /*energy*/1, /*secondary*/1,
        /*damage*/0, /*dtype*/0,
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/-1, /*base_crit*/0,
        /*effect_type*/"trap", /*effect_value*/0, /*duration*/0,
        /*self*/true),

    // 12: Wire Snare - punishes archers for kiting.
    ability_define("Wire Snare",
        /*energy*/1, /*secondary*/1,
        /*damage*/0, /*dtype*/0,
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/1, /*base_crit*/8,
        /*effect_type*/"trap", /*effect_value*/0, /*duration*/0,
        /*self*/true),

    // 13: Caltrops - 3 charges, no block. Rewards a long fight.
    ability_define("Caltrops",
        /*energy*/1, /*secondary*/1,
        /*damage*/0, /*dtype*/0,
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/1, /*base_crit*/6,
        /*effect_type*/"trap", /*effect_value*/0, /*duration*/0,
        /*self*/true),
];

// Plain-English descriptions for Shadowstrider abilities
var _ss_d = [
    { s: "Deal 14 physical dmg. +12 if target is debuffed.",
      f: "One breath, one line, one shot that was always going to land.\n- 14 physical damage, high accuracy, strong Precision crit.\n- +12 damage against a debuffed target - mark first, then fire." },
    { s: "SET a trap. Springs on the next MELEE attack: blocks it, 10 dmg + Root.",
      f: "Set steel jaws where the next foot falls, and wait.\n- DEPLOYED: takes a trap slot and waits. It springs on the first MELEE attack.\n- Springing BLOCKS that attack outright - the blow never lands and their turn is spent - then deals 10 physical damage and Roots them.\n- Useless against a caster or an archer. Read their intent before you set it." },
    { s: "~(50% + WIS) chance to dodge the next 3 attacks. 2-turn CD.",
      f: "Walk half a step behind your own shadow and let the blows guess.\n- Each of the next 3 incoming attacks has a (50% + WIS*2)% dodge chance, capped at 85%. Stun halves the odds.\n- 1 AP on a 2-turn cooldown - strong against a pack." },
    { s: "Deal 7 Poison dmg. Poison: 5 dmg/turn for 4 turns.",
      f: "Flick a needle of something patient into their neck.\n- 7 Poison damage + Poison 5/turn for 4 turns (20 total). Scales with INT gear; armor can't blunt it.\n- Cheap - apply it early and let it tick while you work." },
    { s: "Spend 1 Prep. Enemies -40% acc 2t; YOU +15% dodge.",
      f: "Drop the room into a grey blindness only you can read.\n- Every enemy's accuracy drops 40% for 2 turns - and the smoke cloaks YOU: +15% dodge while it lingers.\n- The panic button: buy a safe turn to set traps or catch your breath." },
    { s: "12 Frost dmg. Weaken -25% 3t + Chill 1t (shatters).",
      f: "Put a sliver of winter where they carry their strength.\n- 12 Frost damage - scales with INT gear, cuts through armor (el_resist applies). Weakened: -25% damage for 3 turns. Chilled 1 turn: detonators SHATTER it for +30% damage.\n- Your own shatter-primer - land it, then detonate with Snipe or Assassinate." },
    { s: "SET a trap. Springs on ANY enemy action: 26 dmg + Bleed. Does NOT block.",
      f: "Line the floor with points that keep cutting on the way out.\n- DEPLOYED: springs on the first hostile action of ANY kind, so it never whiffs.\n- 26 physical damage + Bleed 6/turn for 4 turns - but it does NOT stop the attack. This is the offensive trap: it punishes rather than prevents.\n- The bleed-build engine; take Death Snare when you need the blow stopped." },
    { s: "Mark 4t: below half HP it takes +30% from ALL sources.",
      f: "Chalk an ending on their back that everything can read.\n- Marked for 4 turns: once the target drops below 50% HP, it takes +30% damage from EVERY source - your hits, your companion, your poisons.\n- The execute window: wound them first, then collapse the mark." },
    { s: "Spend 2 Prep. Halve next hit over 10 dmg; refund 1 Prep.",
      f: "Keep your knees bent and your plans loose.\n- Costs no AP: the next hit above 10 damage is halved, and a clean absorb refunds 1 Prep.\n- Hold it for the heavy hits - it ignores weak attacks." },
    { s: "SET a trap. Springs on ANY action: BLOCKS it, 20 dmg + Stun 2 turns.",
      f: "Build the last mistake they will ever step into.\n- DEPLOYED: springs on the first hostile action of ANY kind - it cannot be played around.\n- BLOCKS that action, deals 20 physical damage and Stuns for 2 turns.\n- The apex trap. Expensive, never wasted, and it answers melee, ranged and casters alike. Save the Prep for elites and bosses." },
    { s: "SET a trap. Springs on the next MELEE attack: BLOCKS it, no damage.",
      f: "A cord at ankle height and the patience to leave it there.\n- DEPLOYED: springs on the first MELEE attack and BLOCKS it outright - no damage at all.\n- Leaves the attacker EXPOSED for 2 turns, so the blow you were spared becomes the opening you strike into.\n- The pure stall: cheapest way to buy a turn, and it feeds every Exposed payoff you own." },
    { s: "SET a trap. Springs on the next SPELL: BLOCKS the cast + Silence 1t.",
      f: "Thin brass strung where a working would have to pass.\n- DEPLOYED: springs on the first enemy SPELL, BLOCKS the cast and Silences them for 1 turn.\n- Does nothing whatsoever against a melee or ranged attack. This is a read, not a safety net.\n- The class's only answer to a caster pack - set it when the intent gems show a cast coming." },
    { s: "SET a trap. Springs on the next RANGED attack: BLOCKS it, 12 dmg + Root.",
      f: "Wire at the throat of the only lane they can shoot down.\n- DEPLOYED: springs on the first RANGED attack, BLOCKS the shot, deals 12 physical damage and Roots them.\n- The punishment for kiting. Useless against a melee rusher, so read the room first." },
    { s: "SET a trap. Springs on ANY action 3 TIMES: 8 dmg each. Does NOT block.",
      f: "Scatter the floor and let them pay for every step.\n- DEPLOYED with THREE charges: it springs on any hostile action and stays down until all three are spent.\n- 8 physical damage a spring, and it never blocks anything.\n- The long-fight trap: worst opener in the kit, best value in a grind - but it holds a slot the whole time." },
];
for (var _i = 0; _i < array_length(_ss_d); _i++) {
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
    // The Ashen Duelist's 1st token (DESIGN_DUELIST_CHALLENGE.md): unlocks via
    // the duelist_tokens goal - never sold, only earned in the duel.
    ability_define("Measured Riposte", 1,0,  0,0,  -1,true,  -1,0, "status",18,1, true),
];
var _gen_d = [
    { s:"Deal 10 physical dmg. Refunds its AP on a kill.",
      f:"A plain, honest blow - the kind that keeps a turn moving.\n- 10 physical damage. Momentum: if it kills, the AP comes back.\n- The chaff-clearer any class can carry." },
    { s:"Heal 14 HP. 2-turn cooldown.",
      f:"Cinch the wound tight and keep moving.\n- 1 AP: restore 14 HP, on a 2-turn cooldown.\n- No setup, no resource - patch up between bigger plays." },
    { s:"Heal 10 HP, +1 resource, shake off newest debuff.",
      f:"Spit, straighten up, and shake the worst of it off.\n- Heals 10 HP, refunds 1 Soul / Blood / Prep, and cleanses your newest affliction.\n- The only self-cleanse in the game - your answer to Poison, burns, and hexes." },
    { s:"Pay 5 HP: gain +1 AP. Once per turn.",
      f:"Let the fear do something useful - and keep letting it.\n- Costs no AP: pay 5 HP, gain +1 AP. Once per turn, every turn.\n- The HP-as-fuel lever; feeds lifesteal builds that pay the loan back. Ruinous when you're already bleeding out." },
    { s:"Until next turn: first melee blow is answered for 18.",
      f:"The Ashen Duelist's own opening, learned the hard way.\n- 1 AP: until your next turn, the FIRST melee blow against you is answered with 18 physical - half again Counterblade's riposte.\n- One perfect answer instead of Counterblade's standing stance. Ranged attacks slip past it." },
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
    { s:"Deal 10 Void dmg. Silence target 3 turns (can't cast).",
      f:"Cut the thread between a caster and their power.\n- 10 Void damage. Silenced: no spell actions for 3 turns.\n- Shuts down casters cold; wasted on pure melee bruisers." },
    { s:"Spend 1 Soul. 14 Arcane +4/Soul held; 50% echoes to ALL.",
      f:"Ring one note of Arcane thunder and let the walls answer.\n- Spend 1 Soul: 14 Arcane damage, +4 per Soul still held.\n- Half the damage echoes to every other enemy - cast it into a crowd with a full reserve." },
    { s:"Spend 3 Souls. Deal 32 Arcane dmg. Ultimate.",
      f:"Fold your hoarded Souls into a point of light that refuses to stay small.\n- Spend 3 Souls: 32 Arcane damage in one detonation.\n- Your highest-damage finisher - bank Souls, then end something with them." },
];
for (var _i = 0; _i < 3; _i++) {
    global.abilities_arcanist[10 + _i].desc_short = _arc_x[_i].s;
    global.abilities_arcanist[10 + _i].desc_full  = _arc_x[_i].f;
}

// --- BLOODWARDEN extras (indices 10-12) ---
array_push(global.abilities_bloodwarden,
    ability_define("Sanguine Pact", 1,0,  0,0,   -1,true,  -1,0, "status",0,0,  true),
    ability_define("Bonebreaker",   3,0,  18,0,  78,false, 0,12, "debuff",5,3,  false),   // audit fix: data said 14, tooltip said 18 - 18 is right for a 3-AP hit
    ability_define("Crimson Apex",  3,3,  22,3,  82,false, 0,12, "heal",20,0,   false));
var _bw_x = [
    { s:"Seal up to 3 Blood into 6 shield each (max 18).",
      f:"Set the reserve between yourself and the blade.\n- Convert up to 3 Blood into a ward of 6 shield per Blood sealed (max 18).\n- The Blood DUMP defense - you refill by being hit; seal it before the big swings." },
    { s:"Detonator: 18 dmg. Target takes +5 dmg for 3 turns.",
      f:"Swing through the armor and into the frame beneath it.\n- 18 physical damage that DETONATES the target's strongest status - then the shattered guard takes +5 from every hit for 3 turns.\n- The committed detonation button - break them, then pile on." },
    { s:"Spend 3 Blood. Deal 22 Blood dmg, heal 20 HP. Ultimate.",
      f:"Their blood, your wound, one motion - the high mark of the art.\n- Spend 3 Blood: 22 Blood damage and a 20 HP heal on impact.\n- Swings a losing fight back in your favor." },
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
    { s:"3 strikes, 16 total dmg. +3 per debuff on target.",
      f:"Three cuts in the space most people spend on one.\n- 16 physical damage split across 3 strikes, each rolling its own crit. +3 damage per debuff or DoT on the target.\n- Loves crit scaling; bites softer into heavy armor." },
    { s:"~(50% + WIS) dodge next attack; your next hit +12 dmg.",
      f:"Be somewhere else. Then be the knife.\n- (50% + WIS*2)% chance, capped at 85%, to dodge the next attack; Stun halves the odds.\n- Your next hit deals +12 - vanish, then punish." },
    { s:"Spend 2 Prep. 12 dmg, +5/debuff. Kills refund 2 AP.",
      f:"Collect on every weakness you've sold them - and keep the turn going.\n- Spend 2 Prep: 12 physical damage, +5 per debuff, mark, and trap effect on the target.\n- The spree: every enemy this cast KILLS refunds 2 AP. The multi-kill sweep vs Assassinate's single execute." },
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
global.abilities_arcanist[13].desc_short = "8 Fire dmg. Sear [Fire+]: +3 Fire/hit 2t. +1 Soul.";
global.abilities_arcanist[13].desc_full  = "Drag a burning thumb across the target and leave the mark smoldering.\n- 8 Fire damage, +1 Soul. Sear [Fire+]: every follow-up hit deals +3 Fire for 2 turns.\n- Open with this, then detonate with Arcane Burst or Soul Nova.";
global.abilities_arcanist[14].desc_short = "Spend up to 4 Souls. Deal 8 Arcane +7 per Soul.";
global.abilities_arcanist[14].desc_full  = "Crack your reserve open and release everything at once.\n- 8 Arcane damage, +7 per Soul consumed (up to 4).\n- Cheaper and more flexible than Arcane Burst - rewards a turn of Soul generation.";

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
global.abilities_bloodwarden[13].desc_full  = "Turn the swing wide and let everything standing catch an edge.\n- 1 AP: 9 physical damage to every enemy.\n- Less per target than a focused hit, but it softens a whole pack at once.";
global.abilities_bloodwarden[14].desc_short = "Detonator: 8 Blood dmg; bleeds +5/tick, chills shatter.";
global.abilities_bloodwarden[14].desc_full  = "Seize every open wound at once and tear them all wider.\n- 8 Blood damage, and it DETONATES the target's strongest status: bleeds +5 per remaining tick (consumed), chills SHATTER (+30%), poison spreads Mortality, void heals you.\n- Build with Gore Strike or Spike Trap, then cash out.";

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
global.abilities_shadowstrider[13].desc_full  = "A shallow cut in exactly the wrong place to have one.\n- 5 physical damage. Exposed: every follow-up hit deals +4 for 2 turns.\n- Your cheapest setup - chain it into Snipe, Flurry, or Assassinate.";
global.abilities_shadowstrider[14].desc_short = "Spend 2 Prep. 26 dmg, DOUBLED if target below 30% HP.";
global.abilities_shadowstrider[14].desc_full  = "The job was never the fight. The job was this moment.\n- Spend 2 Prep: 26 physical damage, DOUBLED against a target below 30% HP.\n- Read the board and save it for the kill turn - your biggest single hit.";


// =============================================================================
// #26 ARCANIST MELEE KIT (2026-07-08) - three melee SPELLS so a close-range
// Arcanist build exists (melee weapon flat damage feeds these; root/silence
// rules treat them as melee). Pushed at indices 15-17 so all earlier index
// literals stay valid. Vex-gated at a new 500/800/1200 premium tier.
// Riders live in obj_combat_controller/Step_0 (Soul Rend consumption) and the
// generic resource path (Blazing Palm's +1 Soul on hit).
// =============================================================================
array_push(global.abilities_arcanist,
    // 15: Blazing Palm - 1-AP melee Soul generator. The close-range Soulfire:
    //     less damage than Soulfire's 15 but rides the melee weapon's flat
    //     damage, so a bladed Arcanist out-fuels the ranged spam.
    ability_define("Blazing Palm",
        /*energy*/1, /*secondary*/0,
        /*damage*/12, /*dtype*/1,        // elemental (school tag: fire)
        /*acc*/86, /*guaranteed*/false,
        /*crit_type*/2, /*base_crit*/8,  // arcane (INT)
        /*effect_type*/"resource", /*effect_value*/1, /*duration*/0, // +1 Soul on a landed hit
        /*self*/false),
    // 16: Gravewrack Grip - guaranteed melee drain that Roots. The control
    //     piece: kind override "root" in ability_status_kind; rooted melee
    //     enemies skip, and detonators shatter the hold for +30%.
    ability_define("Gravewrack Grip",
        /*energy*/2, /*secondary*/0,
        /*damage*/16, /*dtype*/2,        // drain - bypasses all mitigation
        /*acc*/-1, /*guaranteed*/true,
        /*crit_type*/-1, /*base_crit*/0,
        /*effect_type*/"debuff", /*effect_value*/1, /*duration*/1, // Root 1 turn (kind override)
        /*self*/false),
    // 17: Soul Rend - the melee finisher. Consumes up to 2 Souls for +8 each
    //     (rider in obj_combat_controller/Step_0, mirrored in combat_estimate_hit)
    //     - a harder base hit than Soul Nova but a smaller Soul dump.
    ability_define("Soul Rend",
        /*energy*/3, /*secondary*/0,     // souls consumed by the rider, not secondary_cost
        /*damage*/30, /*dtype*/1,        // elemental -> arcane (dtype default)
        /*acc*/82, /*guaranteed*/false,
        /*crit_type*/2, /*base_crit*/10, // arcane (INT)
        /*effect_type*/"damage", /*effect_value*/0, /*duration*/0,
        /*self*/false));
global.abilities_arcanist[15].desc_short = "Melee: 12 Fire dmg. +1 Soul on hit.";
global.abilities_arcanist[15].desc_full  = "Drive a burning palm into them at arm's length.\n- Melee spell: 12 Fire damage, +1 Soul on a landed hit. Your melee weapon's damage rides along.\n- Cheap fuel for the reserve when the fight closes in.";
global.abilities_arcanist[16].desc_short = "Melee: 16 Void dmg, always hits. Root 1t.";
global.abilities_arcanist[16].desc_full  = "Close a grave-cold hand around them and let the earth remember its claim.\n- Melee spell: guaranteed 16 Void damage that ignores all armor.\n- Roots the target for 1 turn - melee enemies skip their attack, and detonators shatter the hold for bonus damage.";
global.abilities_arcanist[17].desc_short = "Melee: 30 Arcane dmg +8 per Soul consumed (max 2).";
global.abilities_arcanist[17].desc_full  = "Take hold of whatever keeps them standing and tear it loose.\n- Melee spell: 30 Arcane damage, +8 per Soul consumed (up to 2).\n- The committed finisher - walk in with a stocked reserve and end something.";


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
global.abilities_arcanist[15].school = "fire";    // Blazing Palm - burning melee palm (#26)

global.abilities_bloodwarden[8].school = "poison"; // Plague Touch - plague (no dmg; flavor)

global.abilities_shadowstrider[3].school = "poison"; // Poison Dart - the poison ability
global.abilities_shadowstrider[5].school = "frost";  // Frost Shot - the SS shatter-primer (07-16)


// =============================================================================
// P3 OFF-STAT RIDERS (COMBAT_DEEPENING_PROPOSAL.md P3 slim, M-approved 08-01).
// One small bonus per listed ability that switches ON while a NON-primary stat
// meets its threshold - the answer to "you ignore every stat but your primary".
// Shown as a "Rider:" line in the ability detail popup (grey until met);
// effects fire at each ability's resolution site in obj_combat_controller.
// =============================================================================
function ability_stat_rider(ability_name) {
    switch (ability_name) {
        case "Entropy":         return { stat:"WIS", at:25, label:"every tick +1 damage" };
        case "Soul Shield":     return { stat:"CON", at:20, label:"+5 base absorb" };
        case "Gravewrack Grip": return { stat:"STR", at:25, label:"the Root holds 2 turns" };
        case "Blood Leech":     return { stat:"INT", at:20, label:"+4 healing" };
        case "Iron Skin":       return { stat:"WIS", at:20, label:"holds 4 turns" };
        case "Marrow Crush":    return { stat:"CON", at:25, label:"also braces you: +4 shield" };
        case "Bear Trap":       return { stat:"WIS", at:25, label:"the Root holds 2 turns" };
        case "Snipe":           return { stat:"STR", at:25, label:"+15% crit damage" };
        case "Field Dressing":  return { stat:"CHA", at:20, label:"+20% healing" };
        case "Second Wind":     return { stat:"CHA", at:20, label:"+20% healing" };
    }
    return undefined;
}

// The player's CURRENT total in a stat: the combat player struct mid-fight
// (base + gear + run + perm already summed there), rebuilt the same way at camp.
function ability_rider_stat_total(stat) {
    if (instance_exists(obj_combat_controller)) {
        var _ps = instance_find(obj_combat_controller, 0).player.stats;
        if (is_struct(_ps) && variable_struct_exists(_ps, stat)) return variable_struct_get(_ps, stat);
    }
    var _t = { STR:0, DEX:0, CON:0, INT:0, WIS:0, CHA:0 };
    if (variable_global_exists("chosen_stats") && is_struct(global.chosen_stats)) {
        var _ks = ["STR", "DEX", "CON", "INT", "WIS", "CHA"];
        for (var _i = 0; _i < 6; _i++) {
            if (variable_struct_exists(global.chosen_stats, _ks[_i]))
                variable_struct_set(_t, _ks[_i], variable_struct_get(global.chosen_stats, _ks[_i]));
        }
    }
    apply_equipment_stats(_t);   // folds gear stat affixes onto the copy
    var _v = variable_struct_get(_t, stat);
    if (variable_global_exists("run_stat_bonuses") && is_struct(global.run_stat_bonuses)
        && variable_struct_exists(global.run_stat_bonuses, stat)) _v += variable_struct_get(global.run_stat_bonuses, stat);
    var _pk = perm_bonus_key(stat);
    if (_pk != "" && variable_global_exists(_pk)) _v += variable_global_get(_pk);
    return _v;
}

function ability_stat_rider_active(ability_name) {
    var _r = ability_stat_rider(ability_name);
    if (_r == undefined) return false;
    return ability_rider_stat_total(_r.stat) >= _r.at;
}


// =============================================================================
// D§4 GAP-FILLER WAVE (M-approved 2026-07-09; ABILITY_DIVERSITY_RESEARCH.md).
// Frost = tempo control (Chill rides the existing frost status + its SHATTER
// detonation), Shock = chains, Soul Engine = the ramp "power", Devil's Flip =
// the gamble. All Vex-purchasable (ability_unlock_info); icons use the code
// fallback until the PixelLab round. Indices anchored on array_length so the
// pushes stay valid whatever came before.
// =============================================================================
var _dw_a0 = array_length(global.abilities_arcanist);
array_push(global.abilities_arcanist,
    // Hoarfrost Lance - 16 Frost + Chilled 2t (foe -30% dmg; detonators SHATTER it)
    ability_define("Hoarfrost Lance", 2,0, 16,1, 85,false, 2,8, "debuff",0.30,2, false),
    // Glacial Ward - 8 shield; melee attackers this turn get Chilled (bespoke)
    ability_define("Glacial Ward",    1,0, 0,0,  -1,true,  -1,0, "shield",8,0,   true),
    // Static Arc - 9 Shock, chains 50% to one other foe (to ALL if target Shocked)
    ability_define("Static Arc",      1,0, 9,1,  88,false, 2,8, "damage",0,0,   false),
    // Soul Engine - once/combat power: spells +3 per full turn elapsed, combat-long
    ability_define("Soul Engine",     2,0, 0,0,  -1,true,  -1,0, "status",0,0,   true));
global.abilities_arcanist[_dw_a0    ].school = "frost";
global.abilities_arcanist[_dw_a0 + 2].school = "shock";
global.abilities_arcanist[_dw_a0    ].desc_short = "16 Frost dmg. Chill 2t: foe -30% dmg, shatters.";
global.abilities_arcanist[_dw_a0    ].desc_full  = "Drive a spear of old winter through them and let the cold linger.\n- 16 Frost damage. Chilled 2 turns: the target deals -30% damage, and detonators SHATTER the chill for +30% damage.\n- The tempo opener: slow their swing, then break the ice with Arcane Burst.";
global.abilities_arcanist[_dw_a0 + 1].desc_short = "8 shield. Melee attackers get Chilled.";
global.abilities_arcanist[_dw_a0 + 1].desc_full  = "Raise a pane of ice between you and their teeth.\n- 8 shield now; any melee enemy that strikes you this turn is Chilled.\n- Defense that feeds the shatter loop - punish the ones who come close.";
global.abilities_arcanist[_dw_a0 + 2].desc_short = "9 Shock dmg, chains 50% to another foe.";
global.abilities_arcanist[_dw_a0 + 2].desc_full  = "Snap a living arc between everything that conducts.\n- 9 Shock damage, chaining 50% to one other enemy.\n- Against a target ALREADY Shocked, the chain leaps to EVERY other enemy instead.";
global.abilities_arcanist[_dw_a0 + 3].desc_short = "Once per combat: spells +3 dmg per turn elapsed.";
global.abilities_arcanist[_dw_a0 + 3].desc_full  = "Set a soul turning inside a cage of glass and let it gather speed.\n- Once per combat, combat-long: your spells deal +3 more for every full turn that has passed since you lit it.\n- Dead weight in short fights, monstrous in long ones - the boss-fight engine.";

var _dw_b0 = array_length(global.abilities_bloodwarden);
array_push(global.abilities_bloodwarden,
    // Galvanize - 16 Shock melee; a killing blow grants +1 AP next turn
    //    07-17: 12 -> 16. At 12 the hit was under budget, so the kill->+1 AP rider
    //    almost never got to fire; 16 is an honest hit (Gore Strike parity minus bleed).
    ability_define("Galvanize", 2,0, 16,1, 86,false, 0,8, "damage",0,0, false));
global.abilities_bloodwarden[_dw_b0].school = "shock";
global.abilities_bloodwarden[_dw_b0].desc_short = "Melee: 16 Shock dmg. Kill = +1 AP next turn.";
global.abilities_bloodwarden[_dw_b0].desc_full  = "Put the storm behind your fist.\n- Melee spell: 16 Shock damage. If it kills, the surge carries - +1 AP next turn.\n- The shock-tempo bruiser: finish something and keep swinging.";

var _dw_s0 = array_length(global.abilities_shadowstrider);
array_push(global.abilities_shadowstrider,
    // Winter's Bite - 1 AP + 1 Prep melee frost; +9 and Prep refund vs Chilled
    ability_define("Winter's Bite", 1,1, 9,1, 88,false, 1,8, "damage",0,0, false));
global.abilities_shadowstrider[_dw_s0].school = "frost";
global.abilities_shadowstrider[_dw_s0].desc_short = "Spend 1 Prep. Melee 9 Frost; +9 & refund vs Chilled.";
global.abilities_shadowstrider[_dw_s0].desc_full  = "A knife kept in the coldest pocket.\n- Melee spell: 9 Frost damage. Against a CHILLED target: +9 damage and the Prep comes back.\n- The cross-class frost dip - pairs with chilling weapons and Arcanist ice.";

// =============================================================================
// COMBO BATCH (M-approved 2026-07-16; COMBAT_COMBO_PLAN_2026-07-16.md).
// Ramp coverage for the other two classes (Soul Engine mirrors): Warpath (BW,
// +2 physical/Blood per turn elapsed) and Compounding Dread (SS, each trap cast
// while lit permanently adds +4 to trap damage this combat). Both once-per-
// combat combat-long powers, support category, Vex 500g premium tier.
// Riders live in obj_combat_controller/Step_0 next to Soul Engine's.
// =============================================================================
var _cb_b0 = array_length(global.abilities_bloodwarden);
array_push(global.abilities_bloodwarden,
    ability_define("Warpath", 2,0, 0,0, -1,true, -1,0, "status",0,0, true));
global.abilities_bloodwarden[_cb_b0].desc_short = "Once per combat: phys/Blood hits +2 per turn elapsed.";
global.abilities_bloodwarden[_cb_b0].desc_full  = "Let the rhythm of the fight wind you tighter with every breath.\n- Once per combat, combat-long: your physical and Blood abilities deal +2 more for every full turn since you started the march.\n- Dead weight in short fights, monstrous in long ones - the boss-fight engine.";

var _cb_s0 = array_length(global.abilities_shadowstrider);
array_push(global.abilities_shadowstrider,
    ability_define("Compounding Dread", 2,0, 0,0, -1,true, -1,0, "status",0,0, true));
global.abilities_shadowstrider[_cb_s0].desc_short = "Once per combat: each trap cast adds +4 to trap dmg.";
global.abilities_shadowstrider[_cb_s0].desc_full  = "Teach the floor itself to hate them a little more each time.\n- Once per combat, combat-long: every trap you spring afterwards permanently adds +4 to your trap damage this combat.\n- The trap-build ramp - light it early and let the snares compound.";

var _dw_g0 = array_length(global.abilities_general);
array_push(global.abilities_general,
    // Devil's Flip - 50/50: 26 dmg to your selected target, or 8 to YOU. Runs
    // through the SELF branch (the coin is the roll - no accuracy, no root gate).
    ability_define("Devil's Flip", 1,0, 0,0, -1,true, -1,0, "status",0,0, true));
global.abilities_general[_dw_g0].desc_short = "Flip: 50% deal 26 (+8/win streak) - 50% take 8.";
global.abilities_general[_dw_g0].desc_full  = "The house always deals; sometimes you ARE the house.\n- Flip a coin: heads, the target takes 26 damage +8 per consecutive win this combat. Tails, YOU take 8 and the streak dies.\n- Ride the streak or cash out - for players who'd rather gamble.";

// =============================================================================
// COMBAT PLAN v2 (M-approved 2026-07-17; COMBAT_IMPROVEMENT_PLAN_2026-07-17.md).
// Two new verbs that complete existing engines: Bulwark Slam turns the Sanguine
// Pact / Poise ward into a spendable (StS Body Slam), Counterblade gives SS a
// Darkest-Dungeon riposte stance. Combat riders live in obj_combat_controller.
// Both Vex 400g. Bulwark is NOT a detonator (keep the reaction table stable).
// =============================================================================
var _v2_b0 = array_length(global.abilities_bloodwarden);
array_push(global.abilities_bloodwarden,
    // Bulwark Slam - consume ALL current shield, deal its value + 8 as physical.
    // base_damage 8 = the "+8 base"; the shield value is a bespoke rider (Step_0).
    ability_define("Bulwark Slam", 2,0, 8,0, 82,false, 0,10, "damage",0,0, false));
global.abilities_bloodwarden[_v2_b0].desc_short = "Consume ALL shield; deal it +8 physical dmg.";
global.abilities_bloodwarden[_v2_b0].desc_full  = "Turn the wall you built into the blow that lands.\n- Spend your ENTIRE shield; deal that much +8 as physical damage. Power crit.\n- The Blood engine's payoff: get hit -> Blood -> Sanguine Pact ward -> Slam. Only good with a stocked guard.";

var _v2_s0 = array_length(global.abilities_shadowstrider);
array_push(global.abilities_shadowstrider,
    // Counterblade - riposte stance; counter every melee attacker until next turn.
    // self-targeted status (the stance); the 12 counter is a bespoke rider (Step_0).
    ability_define("Counterblade", 1,0, 0,0, -1,true, -1,0, "status",1,1, true));
global.abilities_shadowstrider[_v2_s0].desc_short = "Stance: counter every melee attacker for 12.";
global.abilities_shadowstrider[_v2_s0].desc_full  = "Stand ready, and let them open themselves on your edge.\n- Until your next turn, whenever a melee attack targets you - landed OR dodged - counter it for 12 physical.\n- The knife-fighter's answer to a melee pack; pairs with Shadow Step / Vanish dodges. Dead vs ranged.";

// =============================================================================
// DELIVERY MUTATORS v2 (M-approved 08-11, SYSTEMS_MUTATORS.md backlog): the
// INNATE-CARRIER abilities - the physical exceptions to "spells only", plus
// Bloodwarden's linger spell. Their mutator identity lives in
// ability_innate_mutator (Ricochet 1-hop 50%, Bomb 2-hop 40%, Gout linger 40%);
// the numbers here are the plain hits the mutator rides on. All Vex-bought.
// =============================================================================
var _mv2_s0 = array_length(global.abilities_shadowstrider);
array_push(global.abilities_shadowstrider,
    // Ricochet Shot - a trick shot built to carom. Modest base for 1 AP + 1
    // Prep because HALF of it arcs on to a second enemy on a real bolt.
    ability_define("Ricochet Shot", 1,1, 12,0, 88,false, 1,10, "damage",0,0, false),
    // Bouncing Bomb - lobbed charge that keeps going: TWO decaying hops at 40%.
    ability_define("Bouncing Bomb", 2,0, 16,0, 90,false, 1,8, "damage",0,0, false));
global.abilities_shadowstrider[_mv2_s0].desc_short = "12 phys; 50% arcs to a 2nd enemy.";
global.abilities_shadowstrider[_mv2_s0].desc_full  = "Loose it at the wall of the world and let geometry finish the job.\n- 12 physical damage; a bolt then CAROMS to one other enemy for 50% of the hit.\n- The pack-fight opener - single targets waste the trick.";
global.abilities_shadowstrider[_mv2_s0 + 1].desc_short = "16 phys; bounces on - 2 hops at 40% each.";
global.abilities_shadowstrider[_mv2_s0 + 1].desc_full  = "An iron sphere with opinions about staying still.\n- 16 physical damage, then it BOUNCES on: up to 2 more enemies, each hop for 40% of the last.\n- The crowd answer; every hop can whiff into an empty room.";

var _mv2_b0 = array_length(global.abilities_bloodwarden);
array_push(global.abilities_bloodwarden,
    // Gout of Rot - Bloodwarden's linger carrier: the hit is the seed, the
    // 2-turn rot at 40%/tick (+poison spice = 50%) is the harvest.
    ability_define("Gout of Rot", 1,1, 11,1, 90,false, 2,8, "damage",0,0, false));
global.abilities_bloodwarden[_mv2_b0].school = "poison";
global.abilities_bloodwarden[_mv2_b0].desc_short = "11 Poison dmg; ROT lingers 2t at half the hit.";
global.abilities_bloodwarden[_mv2_b0].desc_full  = "What the blood cannot claim, the rot inherits.\n- 11 Poison damage, and the wound LINGERS: a 2-turn rot ticking for half the landed hit.\n- Cheap sustained pressure - the hit is the seed, the rot is the harvest.";

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
        case "Flurry":      case "Killing Spree": case "Bulwark Slam":  // Bulwark = melee payoff
        // §3 rework melee additions
        case "Cleave":      case "Rupture":       case "Throat Slit":  case "Assassinate":
        // #26 Arcanist melee kit - the melee SPELLS (dtype != 0 keeps them spells)
        case "Blazing Palm": case "Gravewrack Grip": case "Soul Rend":
        // D§4 wave melee spells (frost knife + shock fist)
        case "Winter's Bite": case "Galvanize":
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
    var _cd = 0;
    switch (ab.name) {
        case "Blink":          _cd = 2; break;
        case "Shadow Step":    _cd = 2; break;
        case "Field Dressing": _cd = 2; break;   // was once-per-combat; now a 2-turn CD like Blink
        case "Void Drain":     _cd = 2; break;   // cheap 1-AP heal/Soul, gated by a 2-turn CD
    }
    // Talent-web Swift Recovery node: resolved copies carry cd_mod (floors at 1).
    if (_cd > 0 && is_struct(ab) && variable_struct_exists(ab, "cd_mod")) _cd = max(1, _cd + ab.cd_mod);
    return _cd;
}

// ability_overcharge_eligible(ab, caster) - true when casting this ability RIGHT
// NOW would trigger OVERCHARGE (07-16, M-approved): the caster's secondary reserve
// is FULL and the ability is a secondary spender/consumer whose effect can carry
// the payout (+2 damage / heal / shield per drained point). Reserve-HELD scalers
// (Soul Shield, Arcane Echo) are excluded - they already are the hoard payoff.
// Single source of truth: the Step_0 arming AND the button tag both read this.
function ability_overcharge_eligible(ab, caster) {
    if (is_undefined(caster) || !is_struct(ab)) return false;
    var _spender = (ab.secondary_cost > 0 || ab.name == "Soul Nova" || ab.name == "Soul Rend"
                    || ab.name == "Sanguine Pact")
                   && ab.name != "Soul Shield" && ab.name != "Arcane Echo";
    if (!_spender) return false;
    var _usable = (ab.base_damage > 0 || ab.effect_type == "heal" || ab.effect_type == "shield"
                   || ab.name == "Sanguine Pact");
    if (!_usable) return false;
    if (variable_struct_exists(caster, "souls"))       return caster.souls       >= caster.souls_max;
    if (variable_struct_exists(caster, "blood"))       return caster.blood       >= caster.blood_max;
    if (variable_struct_exists(caster, "preparation")) return caster.preparation >= caster.preparation_max;
    return false;
}

// ability_is_detonator(ab) - true for abilities that trigger status reactions on
// hit (see SYSTEMS_VIABILITY_PASS.md). Accepts a struct or a name string.
// Combo batch 07-16: Rupture + Bonebreaker join (Bloodwarden finally reaches the
// reaction table - Rupture's old bespoke bleed rider is deleted; the shared bleed
// reaction is the same +5/tick), and Rift joins as the CASCADE - being AoE, it
// detonates each enemy's status individually in the per-target loop.
function ability_is_detonator(ab) {
    // Talent-web keystone (Unstable Charge / Concussive Impact / bespoke):
    // a resolved copy carrying the "detonate" rider joins the reaction table.
    if (is_struct(ab) && ability_web_copy_has_rider(ab, "detonate")) return true;
    var _n = is_struct(ab) ? ab.name : ab;
    return (_n == "Snipe" || _n == "Assassinate" || _n == "Arcane Burst" || _n == "Soul Nova"
         || _n == "Rupture" || _n == "Bonebreaker" || _n == "Rift");
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
        case "Frost Shot":   case "Mana Sever":  case "Vital Theft":   case "Soulbind":
        case "Bear Trap":    case "Spike Trap":    case "Death Snare":
        case "Tripline":     case "Warding Chime": case "Wire Snare":   case "Caltrops":
        case "Blazing Palm": case "Gravewrack Grip": case "Soul Rend":   // #26 melee kit
        case "Hoarfrost Lance": case "Static Arc": case "Galvanize":     // D§4 wave
        case "Winter's Bite":   case "Devil's Flip": case "Bulwark Slam":
        case "Blood Leech":     // 07-29 M ruling: it's a damaging attack that happens to heal
        case "Ricochet Shot": case "Bouncing Bomb": case "Gout of Rot":  // mutator v2 carriers
            return "offense";

        // defense - self-protection (Counterblade = reactive stance; pairs with the
        // SS dodge kit for the same-category discount).
        case "Iron Skin":    case "Bloodthorn Aura": case "Soul Shield": case "Blink":
        case "Shadow Step":  case "Evasive Roll":  case "Vanish":        case "Undying":
        case "Counterblade":
            return "defense";

        // support - heal / buff / resource (Void Drain stays sustain-primary; Blood
        // Leech moved to offense 07-29 - it leads with the bite, not the heal).
        case "Field Dressing": case "Void Drain":  case "Blood Surge":   case "Second Wind":
        case "Adrenaline Rush": case "Soul Harvest": case "Sanguine Pact": case "Bloodfeast":
        case "Soul Engine":   // D§4: the ramp power is a self-buff
        case "Warpath":        case "Compounding Dread":   // 07-16 combo batch ramps
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
// pays for an ability right now: same-category synergy, Quickcast rune, Cracked
// Focus and Gatewarden's Brand all folded in, in the same order the cast block
// applies them. The UI cost pips, the combat resource gate AND the actual spend all
// read this, so they can never disagree (07-09 bug: Cracked Focus was applied at
// spend but not at the gate, so a Singularity that would really cost 1 AP was
// refused at 1 AP with "Not enough resources"). Free (0-AP) abilities stay 0; only
// AP is discounted, never the secondary resource. Pass the casting player as
// `caster` (may be undefined / an enemy -> flag guards skip the player discounts).
function ability_effective_cost(ab, caster) {
    var _cost = variable_struct_exists(ab, "energy_cost") ? ab.energy_cost : 0;
    if (_cost <= 0) return _cost;   // free abilities stay free

    // Same-category synergy (-1 AP). SUPPORT abilities can be discounted all the way
    // to 0 AP (M's call): a 1-AP support cast after another support this turn becomes
    // free, so buff/heal chains are genuinely free. Every other role floors at 1 AP.
    var _floor = (ability_category(ab) == "support") ? 0 : 1;
    if (ability_synergy_active(ab, caster)) _cost = max(_floor, _cost - 1);

    if (is_undefined(caster)) return _cost;
    var _is_spell = ability_class_is_spell(ability_attack_class(ab));

    // Talent-web Opening Gambit keystone: the FIRST cast of this ability each
    // combat costs -1 AP (can reach 0). Flag is burned at cast commit, same
    // pattern as Quickcast below.
    if (_cost > 0 && ability_web_copy_has_rider(ab, "first_free")
        && !ability_web_first_cast_used(caster, ab.name)) {
        _cost -= 1;
    }

    // Blink "Counterphase" web keystone (task #14): a full Blink evade armed a
    // 1-AP discount on the NEXT ability. Cleared at cast commit (the same site
    // that burns the first-cast flags), so display and charge always agree.
    if (_cost > 0 && variable_struct_exists(caster, "blink_tempo_ready") && caster.blink_tempo_ready) {
        _cost -= 1;
    }

    // The Ashen Blade (Duelist Arts legendary): a dodge or riposte armed a 1-AP
    // discount on the NEXT ability. Same commit-burn pattern as Counterphase.
    if (_cost > 0 && variable_struct_exists(caster, "ashen_tempo_ready") && caster.ashen_tempo_ready) {
        _cost -= 1;
    }

    // Expanded Arsenal TRANSCEND "Deep Reserves" (POTENCY V2): the first cast of
    // EVERY slotted ability each combat costs -1 AP. Same flag pattern as the
    // web keystone above; burned at cast commit alongside it.
    if (_cost > 0 && trait_transcended("Expanded Arsenal")
        && variable_struct_exists(caster, "potency_first_casts")
        && !variable_struct_exists(caster.potency_first_casts, ab.name)) {
        _cost -= 1;
    }

    // Quickcast aspect rune: the first SPELL each combat costs -1 AP (can reach 0).
    if (_cost > 0 && _is_spell
        && rune_aspect_socketed("quickcast")
        && variable_struct_exists(caster, "rune_first_spell_used")
        && !caster.rune_first_spell_used) {
        _cost -= 1;
    }

    // Cracked Focus (class weapon): first SPELL each combat costs 1 less AP (min 1).
    // Skipped when a prior discount already has it at 1 or 0, so the charge isn't
    // shown (or burned in the cast block) for zero effect.
    if (_cost > 1 && _is_spell
        && variable_struct_exists(caster, "cf_first_spell_ap") && caster.cf_first_spell_ap
        && variable_struct_exists(caster, "cf_used") && !caster.cf_used) {
        _cost -= 1;
    }

    // Third Wind blessing (Shrine V2, 07-29): every 3rd ability cast in a combat
    // costs 1 less AP. The counter (boon_cast_count) increments at cast commit, so
    // when it reads 2 mod 3 the NEXT cast is the third - display and charge agree.
    if (_cost > 0 && boon_active("thirdwind")
        && variable_struct_exists(caster, "boon_cast_count")
        && (caster.boon_cast_count mod 3) == 2) {
        _cost -= 1;
    }

    // Gatewarden's Brand: the first ability each combat costs 0 AP.
    if (variable_struct_exists(caster, "gatewarden_brand") && caster.gatewarden_brand
        && variable_struct_exists(caster, "gatewarden_used") && !caster.gatewarden_used) {
        _cost = 0;
    }

    return _cost;
}

// Display name + current amount of the caster's SECONDARY resource (mirrors the
// variable_struct_exists chain in ability_secondary_ok). Used by the combat gate's
// refusal message so the player is told exactly what is missing.
function ability_secondary_label(caster) {
    if (variable_struct_exists(caster, "souls"))       return "Souls";
    if (variable_struct_exists(caster, "blood"))       return "Blood";
    if (variable_struct_exists(caster, "preparation")) return "Preparation";
    return "resource";
}
function ability_secondary_amount(caster) {
    if (variable_struct_exists(caster, "souls"))       return caster.souls;
    if (variable_struct_exists(caster, "blood"))       return caster.blood;
    if (variable_struct_exists(caster, "preparation")) return caster.preparation;
    return 0;
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

// school_base_color(school) - the UNTINTED canonical color for each element/school.
// The Vael Tints tab shows this as the "before" swatch; everything else should go
// through school_color() below so purchased tints apply.
function school_base_color(school) {
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

// school_color(school) - canonical tint for each element/school. Used by the
// combat-log color coding and any school-tagged UI text.
// A purchased spell tint (Vael Tints tab, expression #4) fully replaces the
// school's color everywhere this function is consulted.
function school_color(school) {
    var _tid = school_tint_id(school);
    if (_tid != "default") {
        var _t = vael_tint_get(_tid);
        if (_t != undefined) return _t.color;
    }
    return school_base_color(school);
}

// ability_school_list() - the eight schools in canonical order (Compendium +
// the school_dmg accumulator iteration).
function ability_school_list() {
    return ["fire", "frost", "shock", "arcane", "blood", "void", "shadow", "poison"];
}

// =============================================================================
// CAST VFX RESOLVERS (07-29 trial). One-shot burst animation per cast. Before
// this, every non-heal self-cast shared the spr_vfx_buff sword+ and attacks
// only split four ways by damage type. Returns { spr, ticks } - ticks feeds
// vfx_timer/vfx_timer_max so longer animations get room to play (the combat
// Draw event maps the countdown onto the sprite's sub-images).
// Vael-tint gap: the new sprites have no grayscale twins yet, so purchased
// spell tints still only recolor the four original attack bursts
// (school_vfx_sprite falls through to the authored art).
// =============================================================================

// ability_phys_shape(ab) - the MOTION archetype for a school-less (physical)
// attack. Before 08-09 every physical ability shared one generic puff, which is
// why the martial classes read flatter than the casters (SYSTEMS_ANIMATION_AUDIT
// Gap 1). Named abilities are keyed explicitly; anything new falls through to a
// crit_type default, so this never needs touching to stay correct:
//   crit_type 0 = power (STR)      -> crush
//   crit_type 1 = precision (DEX)  -> pierce
//   otherwise                      -> slash
// "snap" is deliberately not reachable from here: it belongs to trap springs,
// which resolve on a later turn and never run the cast VFX path.
function ability_phys_shape(ab) {
    switch (ab.name) {
        case "Cleave": case "Gore Strike": case "Throat Slit":
        case "Flurry": case "Killing Spree": case "Strike":
            return "slash";
        case "Snipe": case "Assassinate":
            return "pierce";
        case "Bonebreaker": case "Marrow Crush": case "Bulwark Slam":
            return "crush";
    }
    var _ct = variable_struct_exists(ab, "crit_type") ? ab.crit_type : -1;
    if (_ct == 0) return "crush";
    if (_ct == 1) return "pierce";
    return "slash";
}

// Burst sprite for a physical motion archetype. Frame counts differ, so each
// carries its own tick budget: a thrust is quick, a shockwave lingers.
function phys_shape_vfx(shape) {
    switch (shape) {
        case "pierce": return { spr: spr_vfx_pierce, ticks: 14 };
        case "crush":  return { spr: spr_vfx_crush,  ticks: 22 };
        case "snap":   return { spr: spr_vfx_snap,   ticks: 16 };
    }
    return { spr: spr_vfx_slash, ticks: 16 };
}

// vfx_variant_pick(name, arr) - deterministic per-ability variant (08-11 VFX
// diversity, M-approved batch): an ability always shows the SAME burst, but two
// abilities of a school no longer have to share one. Plain byte-sum hash - the
// assignment only needs to be stable and spread, not fair.
function vfx_variant_pick(_name, _arr) {
    var _h = 0;
    for (var _i = 1; _i <= string_length(_name); _i++) _h += string_byte_at(_name, _i);
    return _arr[_h mod array_length(_arr)];
}

// Attack impact keyed to the ability's element SCHOOL; physical ("" school)
// splits four ways by motion archetype (08-09). Untinted schools pick between
// the classic Gigapack burst and an 08-11 owned-pack variant per ability; an
// equipped Vael tint pins the classic sprite - only those have the grey twins
// the tint blend needs (school_vfx_sprite).
function ability_attack_vfx(ab) {
    var _sch = ability_school(ab);
    if (_sch == "") return phys_shape_vfx(ability_phys_shape(ab));
    var _classic; var _ticks;
    switch (_sch) {
        case "fire":   _classic = spr_vfx_fire;   _ticks = 20; break;
        case "frost":  _classic = spr_vfx_frost;  _ticks = 20; break;
        case "shock":  _classic = spr_vfx_shock;  _ticks = 16; break;
        case "arcane": _classic = spr_vfx_arcane; _ticks = 20; break;
        case "blood":  _classic = spr_vfx_blood;  _ticks = 18; break;
        case "void":   _classic = spr_vfx_void;   _ticks = 20; break;
        case "shadow": _classic = spr_vfx_shadow; _ticks = 16; break;
        case "poison": _classic = spr_vfx_poison; _ticks = 24; break;
        default: return phys_shape_vfx(ability_phys_shape(ab));
    }
    if (school_tint_id(_sch) != "default") return { spr: _classic, ticks: _ticks };
    // Scorch's bespoke read (M 08-04: flames AT their feet, never traveling).
    if (ab.name == "Scorch") return { spr: spr_vfx_scorch, ticks: 22 };
    var _set;
    switch (_sch) {
        case "fire":   _set = [spr_vfx_fire,   spr_vfx_fire2];   break;
        case "frost":  _set = [spr_vfx_frost,  spr_vfx_frost2];  break;
        case "shock":  _set = [spr_vfx_shock,  spr_vfx_shock2, spr_vfx_shockstrike]; break;
        case "arcane": _set = [spr_vfx_arcane, spr_vfx_arcane2]; break;
        case "blood":  _set = [spr_vfx_blood,  spr_vfx_blood2];  break;
        case "void":   _set = [spr_vfx_void,   spr_vfx_void2];   break;
        // Shadow variant round 2 (08-11): violet smoke burst from the purchased
        // full Gigapack (the round-1 pick duplicated the shipped claw).
        case "shadow": _set = [spr_vfx_shadow, spr_vfx_shadow2]; break;
        case "poison": _set = [spr_vfx_poison, spr_vfx_poison2]; break;
    }
    return { spr: vfx_variant_pick(ab.name, _set), ticks: _ticks };
}

// Self-cast burst keyed to what the ability DOES:
//   heal -> restore | shield -> warded shield | resource -> absorb motes |
//   self-debuff -> skull smoke | evasion/tempo statuses -> haste clock |
//   dark self-pacts (blood/void/shadow school statuses) -> skull smoke |
//   everything else (offense buffs) keeps the classic sword+ burst.
function ability_support_vfx(ab) {
    // IDENTITY OVERRIDES (M 08-11: "base VFX around ability names/effects, not
    // just what it does" - Blood Surge read as a generic white heal). Named
    // abilities whose fantasy demands specific art check FIRST; everything
    // else falls through to the effect-family pick below.
    switch (ab.name) {
        case "Blood Surge":                  // a geyser of blood, not a heart
        case "Sanguine Pact":                // blood sealing into ward
            return { spr: vfx_variant_pick(ab.name, [spr_vfx_blood, spr_vfx_blood2]), ticks: 22 };
    }
    // Each family picks per-ability between its classic burst and the 08-11
    // owned-pack variant (vfx_variant_pick, M-approved batch).
    switch (ab.effect_type) {
        case "heal":     return { spr: vfx_variant_pick(ab.name, [spr_vfx_heal,   spr_vfx_heal2]),   ticks: 20 };
        case "shield":   return { spr: vfx_variant_pick(ab.name, [spr_vfx_shield, spr_vfx_shield2]), ticks: 24 };
        case "resource": return { spr: vfx_variant_pick(ab.name, [spr_vfx_gain,   spr_vfx_gain2]),   ticks: 26 };
        case "debuff":   return { spr: vfx_variant_pick(ab.name, [spr_vfx_dark,   spr_vfx_dark2]),   ticks: 20 };
    }
    var _n = ab.name;
    if (_n == "Blink" || _n == "Evasive Roll" || _n == "Vanish" || _n == "Adrenaline Rush") {
        return { spr: spr_vfx_haste, ticks: 26 };
    }
    // The three once-per-combat ramp powers read as charging up - absorb motes.
    // (Also the only castable route to spr_vfx_gain: no slottable ability
    // self-casts effect_type "resource" - Soul Harvest is engine-triggered.)
    if (_n == "Soul Engine" || _n == "Warpath" || _n == "Compounding Dread") {
        return { spr: vfx_variant_pick(_n, [spr_vfx_gain, spr_vfx_gain2]), ticks: 26 };
    }
    // Dark self-pacts: dark-school statuses, plus the physical-typed ones whose
    // fantasy is clearly grim (cheating death, thorned blood).
    var _sch = ability_school(ab);
    if (_sch == "blood" || _sch == "void" || _sch == "shadow"
        || _n == "Undying" || _n == "Bloodthorn Aura") {
        return { spr: vfx_variant_pick(_n, [spr_vfx_dark, spr_vfx_dark2]), ticks: 20 };
    }
    return { spr: vfx_variant_pick(_n, [spr_vfx_buff, spr_vfx_buff2]), ticks: 20 };
}

// =============================================================================
// DELIVERY ARCHETYPES (08-04 conveyance pass, SYSTEMS_COMBAT_FX.md header).
// How an attack's VISUALS travel: "melee" keeps the lunge, "projectile" flies
// caster->target and defers the hit presentation to arrival, "beam" is an
// instant lance source->target, "overhead" drops at the target (collapse /
// strike-from-above reads), "self" never leaves the caster. Mechanics are
// untouched - damage/riders/AP resolved at cast; only presentation routes here.
// =============================================================================
function ability_delivery(ab) {
    // Explicit overrides where the class/school default reads wrong.
    switch (ab.name) {
        // Collapsing / erupting AT the victim - nothing visibly travels.
        // Scorch (M 08-04 livetest): a skirt of brief flames AT their feet,
        // instantly beneath them - it never travels.
        case "Singularity": case "Soul Nova": case "Arcane Burst": case "Scorch":
            return "overhead";
        // Drains pull a thread OUT of the victim - a lance, not a thrown bolt.
        case "Void Drain": case "Mana Sever": case "Entropy":
            return "beam";
    }
    var _ac = ability_attack_class(ab);
    if (_ac == "none") return "self";
    if (ability_class_is_melee(_ac)) return "melee";
    // Everything ranged is loosed/hurled and travels (M's rule: a lightning
    // BLAST flies to its mark; only strike-from-above effects stay overhead).
    return "projectile";
}

// Traveling sprite for a "projectile" delivery. Every school now has a REAL
// flight animation (Super Pixel Projectiles Pack 1, purchased 08-11, same
// artist as the shipped bursts; sprites face RIGHT, the Draw rotates them).
// A Vael-tinted school falls back to its rotated burst art - only the classic
// bursts have grey twins for the tint blend. Physical returns -1: the combat
// Draw renders a code-drawn streak (arrow/knife read).
function ability_projectile_sprite(ab) {
    var _sch = ability_school(ab);
    if (_sch == "") return -1;   // physical - code-drawn streak
    if (school_tint_id(_sch) != "default") {
        switch (_sch) {
            case "fire":   return spr_vfx_fire;
            case "frost":  return spr_vfx_frost;
            case "shock":  return spr_vfx_shock;
            case "arcane": return spr_vfx_arcane;
            case "blood":  return spr_vfx_blood;
            case "void":   return spr_vfx_void;
            case "shadow": return spr_vfx_shadow;
            case "poison": return spr_vfx_poison;
        }
        return -1;
    }
    switch (_sch) {
        case "fire":   return spr_vfx_bolt_fire;
        case "frost":  return spr_vfx_bolt_frost;
        case "shock":  return spr_vfx_bolt_shock;
        case "arcane": return spr_vfx_bolt_arcane;
        case "blood":  return spr_vfx_bolt_blood;
        case "void":   return spr_vfx_bolt_void;
        case "shadow": return spr_vfx_bolt_shadow;
        case "poison": return spr_vfx_bolt_poison;
    }
    return -1;
}

// TRUE for the dedicated flight-loop bolts: the combat Draw cycles their FULL
// frame count in flight. Burst art doubling as a bolt keeps the early-frames-
// only guard (its late frames are dissipating smoke - M 08-04 "blue ball").
function vfx_is_flight_bolt(_spr) {
    switch (_spr) {
        case spr_vfx_bolt_fire:  case spr_vfx_bolt_frost:  case spr_vfx_bolt_shock:
        case spr_vfx_bolt_arcane: case spr_vfx_bolt_blood: case spr_vfx_bolt_void:
        case spr_vfx_bolt_shadow: case spr_vfx_bolt_poison:
            return true;
    }
    return false;
}

// Beam lance sprite for a "beam" delivery (08-11): school-colored unTied laser
// tiled along the lance by the Draw. -1 = keep the plain code-drawn line
// (tinted schools - the lasers are pre-colored, no grey twins).
function ability_beam_sprite(ab) {
    var _sch = ability_school(ab);
    if (_sch != "" && school_tint_id(_sch) != "default") return -1;
    return (_sch == "poison") ? spr_vfx_beam_green : spr_vfx_beam_violet;
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
        // Name the concrete element (fire/frost/shock/arcane) rather than the generic
        // "elemental" so descriptions read like the school shown under the ability name.
        var _sch = ability_school(ab);
        if (_sch == "fire" || _sch == "frost" || _sch == "shock" || _sch == "arcane") return _sch;
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
        case "Void Drain":      _b = "Banks +1 Soul on hit."; break;
        case "Soul Harvest":    _b = "Free 0-AP action: generate " + string(_ev) + " Souls."; break;
        case "Arcane Echo":     _b = "Deals +4 bonus damage per Soul you hold."; break;
        case "Soul Nova":       _b = "Consumes up to 4 Souls; +7 damage per Soul spent."; break;
        case "Blazing Palm":    _b = "Banks +1 Soul on a landed hit."; break;
        case "Gravewrack Grip": _b = "Cannot miss; void damage ignores armor."; break;
        case "Soul Rend":       _b = "Consumes up to 2 Souls; +8 damage per Soul spent."; break;
        case "Flurry":          _b = "Strikes 3 times; each hit rolls its own crit. +3 damage per debuff on the target."; break;
        case "Rupture":         _b = "Blood detonator: bleeds burst for +5 damage per remaining tick (consumed); other statuses react per the reaction table."; break;
        case "Bonebreaker":     _b = "Detonates the target's strongest status on hit."; break;
        case "Rift":            _b = "The cascade: detonates each enemy's statuses individually as it hits them."; break;
        case "Warpath":         _b = "Once per combat, combat-long: physical and Blood abilities deal +2 per full turn elapsed."; break;
        case "Compounding Dread": _b = "Once per combat, combat-long: each trap you cast afterwards permanently adds +4 to your trap damage this combat."; break;
        case "Frost Shot":      _b = "Also Chills the target for 1 turn - detonators SHATTER the chill for +30% damage."; break;
        case "Assassinate":     _b = "Execute: deals DOUBLE damage to a target below 30% HP."; break;
        case "Killing Spree":   _b = "Deals +5 bonus damage per debuff or trap on the target. Each enemy it KILLS refunds 2 AP."; break;
        case "Entropy":         _b = "The rot ACCELERATES: each tick deals +2 more than the last (6/8/10/12). Recast onto lingering void for DOUBLE ticks."; break;
        case "Adrenaline Rush": _b = "Once per turn: pay 5 HP to gain +1 AP."; break;
        case "Bulwark Slam":    _b = "Consumes ALL your current shield and adds its value to the hit."; break;
        case "Counterblade":    _b = "Until your next turn, counter EVERY melee blow - weapon or spell - for 12 physical (hit or dodged). Ranged attacks slip past."; break;
        case "Sanguine Pact":   _b = "Seals up to 3 Blood into 6 shield each."; break;
        case "Hoarfrost Lance": _b = "Chilled targets deal -30% damage; detonators SHATTER the chill for +30% damage."; break;
        case "Glacial Ward":    _b = "Melee enemies that strike you this turn are Chilled."; break;
        case "Static Arc":      _b = "Chains 50% to one other enemy - to ALL others if the target was already Shocked."; break;
        case "Soul Engine":     _b = "Once per combat, combat-long: spells deal +3 per full turn elapsed."; break;
        case "Galvanize":       _b = "A killing blow grants +1 AP next turn."; break;
        case "Winter's Bite":   _b = "Against a Chilled target: +9 damage and the Prep refunds."; break;
        case "Devil's Flip":    _b = "A coin flip: 50% the target takes 26 (+8 per consecutive win this combat) - 50% YOU take 8 and the streak resets."; break;
        case "Soul Shield":     _b = "The ward absorbs +3 more per Soul still held."; break;
        case "Marked for Death": _b = "Marked: below half HP the target takes +30% from ALL damage sources."; break;
        case "Smoke Bomb":      _b = "The smoke also cloaks YOU: +15% dodge while it lingers."; break;
        case "Second Wind":     _b = "Also restore 1 secondary resource (Soul / Blood / Prep)."; break;
        case "Blink":           _b = "Fully dodge the next attack; the 2nd hit after takes 50% less and the 3rd 25% less. 2-turn cooldown."; break;
        case "Shadow Step":     _b = "~(50% + WIS) chance to dodge each of the next 3 attacks. 2-turn cooldown."; break;
        case "Evasive Roll":    _b = "Halve the next incoming hit above 10 damage; a clean absorb refunds 1 Preparation."; break;
        case "Vanish":          _b = "~(50% + WIS) chance to dodge the next attack; your next strike deals +12 damage."; break;
        case "Bloodthorn Aura": _b = "Reflect " + string(_ev) + " damage to attackers for " + ability_turns(_ed) + "."; break;
        case "Undying":         _b = "Survive the next lethal blow: surge back to 25% max HP and gain 3 Blood."; break;
        case "Vital Theft":     _b = "Steal " + string(_ev) + " max HP from the target, add it to your own max HP, and heal " + string(_ev) + " - all for this combat."; break;
        case "Bloodfeast":      _b = "Each ability also drains " + string(_ev) + " HP for " + ability_turns(_ed) + "."; break;
        case "Soulbind":        _b = "Lifelink: the bound foe takes " + string(round(_ev * 100)) + "% of damage you take, and it heals you the same (whole combat)."; break;
    }
    if (_b != "") array_push(_parts, _b);

    // Detonators surface their reaction behavior. Kept to one plain-English line here;
    // the full reaction table lives in the Tab/V ability-detail popup and the
    // Compendium > Status Reactions page. See SYSTEMS_VIABILITY_PASS.md.
    if (ability_is_detonator(ab) && ab.name != "Rupture" && ab.name != "Bonebreaker" && ab.name != "Rift") {
        array_push(_parts, "Detonates debuffs for secondary effects.");
    }   // (Rupture/Bonebreaker/Rift already disclose it in their bespoke line above)

    // DEPLOYED TRAPS (08-08) describe themselves from trap_catalog(), not from
    // effect_value/effect_duration - those are 0 on a trap now, which is why the
    // combat panel read "Roots the target for 0 turns" (M). Talent riders are
    // folded in AND called out, so the line updates when you weave the web.
    if (ability_is_trap(ab.name)) {
        var _tdd = trap_def(ab.name);
        if (_tdd != undefined) {
            var _t_dmg  = _tdd.damage   + (ability_web_copy_has_rider(ab, "trap_dmg")    ? 6 : 0);
            var _t_dur  = _tdd.duration + (ability_web_copy_has_rider(ab, "trap_dur")    ? 1 : 0);
            var _t_chg  = _tdd.charges  + (ability_web_copy_has_rider(ab, "trap_charge") ? 1 : 0);
            var _t_flt  = ability_web_copy_has_rider(ab, "trap_any") ? "any" : _tdd.filter;
            var _t_blk  = _tdd.block || ability_web_copy_has_rider(ab, "trap_block");
            // Sentence templates per filter (M 08-11: "springs on the next any
            // action" read as jank). "any" gets its own phrasing; multi-charge
            // traps read as a SENSITIVE repeat trigger, per M's Caltrops model.
            var _t_line;
            if (_t_flt == "any") {
                _t_line = (_t_chg > 1)
                    ? "SET a trap. A sensitive trigger - it springs on ANY enemy action, again and again."
                    : "SET a trap. It springs on the next enemy action of ANY kind.";
            } else {
                _t_line = "SET a trap. It waits, then springs on the next "
                        + trap_filter_label(_t_flt) + ".";
            }
            if (_t_blk)        _t_line += " Springing BLOCKS that action outright.";
            if (_t_dmg > 0)    _t_line += " Deals " + string(_t_dmg) + " damage.";
            if (_tdd.status != "" && _t_dur > 0) {
                switch (_tdd.status) {
                    case "root":    _t_line += " Roots for " + ability_turns(_t_dur) + " (melee skips; ranged still attacks)."; break;
                    case "stun":    _t_line += " Stuns for " + ability_turns(_t_dur) + " (any enemy can't act)."; break;
                    case "bleed":   _t_line += " Bleeds for 6 damage/turn over " + ability_turns(_t_dur) + "."; break;
                    case "silence": _t_line += " Silences for " + ability_turns(_t_dur) + " (can't cast)."; break;
                    case "blind":   _t_line += " Blinds for " + ability_turns(_t_dur) + " (-35% accuracy)."; break;
                    case "exposed": _t_line += " Leaves them Exposed for " + ability_turns(_t_dur) + "."; break;
                    default:        _t_line += " Applies " + _tdd.status + " for " + ability_turns(_t_dur) + ".";
                }
            }
            if (_t_chg > 1) _t_line += " Can be triggered " + string(_t_chg) + " times before it expires.";
            // Name the talents that are actually changing these numbers, so the
            // panel explains WHY it differs from the base ability.
            var _t_tal = [];
            if (ability_web_copy_has_rider(ab, "trap_dmg"))    array_push(_t_tal, "Weighted Jaws +6 dmg");
            if (ability_web_copy_has_rider(ab, "trap_dur"))    array_push(_t_tal, "Barbed Edge +1 turn");
            if (ability_web_copy_has_rider(ab, "trap_charge")) array_push(_t_tal, "Twin Jaws +1 spring");
            if (ability_web_copy_has_rider(ab, "trap_any"))    array_push(_t_tal, "Wide Set: catches anything");
            if (ability_web_copy_has_rider(ab, "trap_block"))  array_push(_t_tal, "Iron Plate: now blocks");
            if (ability_web_copy_has_rider(ab, "trap_vuln"))   array_push(_t_tal, "Hunter's Anchor: +Vulnerable");
            if (ability_web_copy_has_rider(ab, "trap_stun"))   array_push(_t_tal, "Second Chance: +Stun 1");
            if (ability_web_copy_has_rider(ab, "trap_splash")) array_push(_t_tal, "Caltrop Spread: hits all");
            if (ability_web_copy_has_rider(ab, "trap_reset"))   array_push(_t_tal, "Resetting Coil: first spring re-arms");
            if (ability_web_copy_has_rider(ab, "trap_patient")) array_push(_t_tal, "Patient Hands: x2 after 3 waiting rounds");
            if (ability_web_copy_has_rider(ab, "trap_slots"))   array_push(_t_tal, "Trapper's Bandolier: 3rd slot");
            if (array_length(_t_tal) > 0) {
                var _t_join = "";
                for (var _tti = 0; _tti < array_length(_t_tal); _tti++)
                    _t_join += ((_tti > 0) ? ", " : "") + _t_tal[_tti];
                _t_line += "  (talents: " + _t_join + ")";
            }
            array_push(_parts, _t_line);
        }
        // Same join the tail of this function uses - traps short-circuit the
        // status switch entirely, so they assemble their own return here.
        var _t_out = "";
        for (var _tj = 0; _tj < array_length(_parts); _tj++)
            _t_out += ((_tj > 0) ? " " : "") + _parts[_tj];
        return _t_out;
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
        case "hexed":
            _s = "Hexes the target for " + ability_turns(_ed) + ": it takes +" + string(_ev)
               + " damage per hit, detonation reactions on it are DOUBLED, and each detonation"
               + " spreads +2 damage-taken to all other enemies.";
            break;
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
        // School/damage word Capitalized (Fire/Frost/Arcane/Physical...) for a consistent,
        // proper-noun look across descriptions, equipment and logs. (Polish)
        _out = "Deal " + string(ab.base_damage) + " " + school_label(ability_damage_word(ab)) + " damage"
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
        array_push(_p, string(ab.base_damage) + " " + school_label(ability_damage_word(ab)));
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
            if (_et == "heal")        _tag = "Heal " + string(_ev)
                                          + (ab.name == "Void Drain" ? ", +1 Soul" : "")
                                          + (ability_cooldown(ab) > 0 ? (" " + string(ability_cooldown(ab)) + "t CD") : "");
            else if (_et == "shield") _tag = (_ed > 0) ? ("-" + string(_ev) + " dmg " + string(_ed) + "t") : ("Shield " + string(_ev));
    }
    if (_tag == "") {
        switch (ab.name) {
            case "Soulfire":        _tag = "+2 Soul"; break;
            case "Soul Harvest":    _tag = "+" + string(_ev) + " Soul (0 AP)"; break;
            case "Arcane Echo":     _tag = "+4 per Soul"; break;
            case "Soul Nova":       _tag = "+7 per Soul (max 4)"; break;
            case "Blazing Palm":    _tag = "+1 Soul on hit"; break;
            case "Soul Rend":       _tag = "+8 per Soul (max 2)"; break;
            case "Arcane Burst":    _tag = "+40% vs Exposed"; break;
            case "Flurry":          _tag = "+3 per debuff"; break;
            case "Rupture":         _tag = "Detonate bleeds"; break;
            case "Assassinate":     _tag = "x2 if <30% HP"; break;
            case "Killing Spree":   _tag = "+5 per debuff"; break;
            case "Snipe":           _tag = "+" + string(_ev) + " if debuffed"; break;
            case "Adrenaline Rush": _tag = "5 HP -> +1 AP"; break;
            case "Bulwark Slam":    _tag = "Shield -> +dmg"; break;
            case "Counterblade":    _tag = "Riposte 12"; break;
            case "Sanguine Pact":   _tag = "Blood -> shield"; break;
            case "Blink":           _tag = "Dodge 1, soften 2 - 2t CD"; break;
            case "Shadow Step":     _tag = "Dodge chance x3 - 2t CD"; break;
            case "Evasive Roll":    _tag = "Halve next hit"; break;
            case "Vanish":          _tag = "Vanish, +12 next"; break;
            case "Bloodthorn Aura": _tag = "Thorns " + string(_ev) + "/" + string(_ed) + "t"; break;
            case "Undying":         _tag = "Cheat death"; break;
            case "Vital Theft":     _tag = "Steal " + string(_ev) + " maxHP"; break;
            case "Bloodfeast":      _tag = "Drain rider " + string(_ed) + "t"; break;
            case "Soulbind":        _tag = "Lifelink " + string(round(_ev * 100)) + "%"; break;
            case "Warpath":         _tag = "+2/turn ramp"; break;
            case "Compounding Dread": _tag = "+4 trap ramp"; break;
            case "Soul Engine":     _tag = "+3/turn ramp"; break;
            case "Devil's Flip":    _tag = "Coin flip, streaks"; break;
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
        "Reveals each room's threat/loot rating on the floor map, and gives +5% success on event-room stat checks.",
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
        "Treasure rooms contain one additional item.",
        -1, "dungeon_clears_total", 3, "treasure_hunter"),

    // Renamed from "Lucky Find" (M 07-08: the name lost its identity when the
    // audit-§6 rework made it about consumables). effect_id stays "lucky_find"
    // so existing unlocks carry over; equipped display names migrate in scr_save.
    trait_define("Blessed Thirst",
        "Consumables have a 20% chance to not be consumed when used.",
        -1, "full_clear", 1, "lucky_find"),

    // The NEW Lucky Find - the name's original fortune identity (and the clover).
    trait_define("Lucky Find",
        "+5% gold and +5% loot find from all sources.",
        -1, "dungeon_clears_total", 3, "lucky_find_gold"),

    trait_define("Battle Hardened",
        "Each floor boss defeated permanently grants +3 max HP (up to +15).",
        -1, "dungeon_clears_total", 5, "battle_hardened"),

    trait_define("Salvager",
        "Keep 2 random carried items on death instead of 1.",
        -1, "char_level", 5, "salvager"),

    trait_define("Iron Will",
        "The first status effect applied to you each combat is ignored.",
        -1, "dungeon_clears_total", 8, "iron_will"),

    // THE ASHEN DUELIST's 2nd token (DESIGN_DUELIST_CHALLENGE.md): hidden
    // progression - unlocks at 2 Duelist Tokens, never sold by Vex, and never
    // listed anywhere while locked (see trait_is_unlocked / the loadout lists).
    trait_define("Duelist's Poise",
        "Start each one-on-one combat with +1 AP.",
        -1, "duelist", 2, "duelist_poise"),

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

    // Mandate from Heaven (P4, COMBAT_DEEPENING_PROPOSAL.md, M-approved 07-30):
    // the premium late-game answer to the A2+ enemy cleanse AI. Sold by Vex only
    // - 2000g + a LEGENDARY sacrifice (trait_unlock_cost special-cases it).
    trait_define("Mandate from Heaven",
        "The heavens ratify your claims: statuses YOU apply cannot be cleansed for 2 turns - enemy menders' hands falter.",
        -1, "vex", 0, "mandate_heaven"),

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
        "Abilities costing 3 AP deal +25% damage (Arcanist only).",
        0, "total_boss_kills", 4, "arcane_surge"),

    // -------------------------------------------------------------------------
    // CLASS: BLOODWARDEN (class_req 1) - unlocked via boss kills
    // -------------------------------------------------------------------------
    trait_define("Crimson Reserve",
        "Start each combat with 4 Blood (Bloodwarden only).",
        1, "boss_kill", 1, "crimson_reserve"),

    trait_define("Vampiric Edge",
        "Restore 2 HP each time you deal bleed/poison damage (Bloodwarden only).",
        1, "total_boss_kills", 2, "vampiric_edge"),

    trait_define("Berserker Rage",
        "Below 40% HP, all damage you deal is increased by 20% (Bloodwarden only).",
        1, "total_boss_kills", 4, "berserker_rage"),

    // M 07-16: the "too many 3-AP abilities" fix - a whole extra action every turn.
    trait_define("Relentless",
        "Base AP raised from 3 to 4 every turn (Bloodwarden only).",
        1, "total_boss_kills", 6, "relentless"),

    // -------------------------------------------------------------------------
    // CLASS: SHADOWSTRIDER (class_req 2) - unlocked via boss kills
    // -------------------------------------------------------------------------
    trait_define("Phantom Step",
        "The first enemy attack each combat automatically misses (Shadowstrider only).",
        2, "boss_kill", 1, "phantom_step"),

    trait_define("Shadow Meld",
        "After dodging an attack, your next attack is a guaranteed critical hit (Shadowstrider only).",
        2, "total_boss_kills", 2, "shadow_meld"),

    trait_define("Serrated Strikes",
        "Physical abilities apply 1 bleed stack for free (Shadowstrider only).",
        2, "total_boss_kills", 4, "serrated_strikes"),

];

// ---------------------------------------------------------------------------
// trait_colloquial(effect_id)
// Plain-language "what this means for you" blurb, shown in the Tab detail popup
// ABOVE the technical description. The trait's own `description` is the technical
// half; this is the friendly half. Keyed by effect_id. Unknown id -> "".
// ---------------------------------------------------------------------------
function trait_colloquial(effect_id) {
    switch (effect_id) {
        case "sense":            return "You scout ahead. Before you set foot in a room you already know whether it's a death-trap or a payday, and you're a little better at talking or sneaking your way through events.";
        case "scavenger":        return "You have a nose for coin. Everything that pays out, pays out a bit more.";
        case "thick_skin":       return "You're simply harder to kill. A flat slab of extra health that's always there.";
        case "quick_recovery":   return "You rest well. Every campfire patches you up more than it would anyone else.";
        case "treasure_hunter":  return "You know where the good stuff hides - every treasure room turns up something extra for you.";
        case "lucky_find":       return "Waste not - one swallow in five, the bottle is somehow still full afterward.";
        case "battle_hardened":  return "Every boss you put down toughens you for good. The deeper you go, the more punishment you can take - forever.";
        case "salvager":         return "When it all goes wrong, you cling to more of your gear. Dying costs you less of what you were carrying.";
        case "iron_will":        return "You grit your teeth through the first hex, poison, or stun each fight like it's nothing.";
        case "expanded_arsenal": return "You travel heavy on tricks - room for one more ability on every run.";
        case "prospector":       return "Your luck runs rich. Loot from fights tends to come out a cut above what it should.";
        case "pack_rat":         return "You hoard supplies. You can haul more potions into a run, and pouring Potency in lets you carry even more.";
        case "last_stand":       return "Once a run, a blow that should kill you instead leaves you standing on a sliver of life.";
        case "focused_power":    return "You trade spread for impact - attacks that would spray the room instead slam your single target far harder.";
        case "chain_caster":     return "Your single-target magic ricochets, throwing a splash of damage onto everyone else in the room.";
        case "plaguebearer":     return "Your rot spreads. The poisons and curses you land creep onto every other enemy too.";
        case "soul_siphon":      return "Death feeds you. Every enemy that falls hands you a Soul to fuel your spells. (Arcanist)";
        case "ley_tap":          return "You start each fight already humming with power - an extra action to spend turn one. (Arcanist)";
        case "arcane_surge":     return "Your big, expensive spells land like a hammer - the costliest casts hit even harder. (Arcanist)";
        case "crimson_reserve":  return "You walk into every fight with the tank already part-full of Blood to spend. (Bloodwarden)";
        case "vampiric_edge":    return "Your bleeds and poisons feed you back - every tick of them mends a little of your own flesh. (Bloodwarden)";
        case "berserker_rage":   return "Cornered and bloodied is exactly where you want to be - the closer to death, the harder you hit. (Bloodwarden)";
        case "relentless":       return "Your fury does not wait. Four actions a turn, every turn - the heavy blows stop costing you the whole round. (Bloodwarden)";
        case "phantom_step":     return "You're a ghost on the first beat - the opening attack of every fight simply passes through you. (Shadowstrider)";
        case "shadow_meld":      return "Slip a blow and answer from the dark - the next strike you land finds something vital. (Shadowstrider)";
        case "serrated_strikes": return "Your edges are wicked - every physical hit leaves a free, lingering bleed. (Shadowstrider)";
    }
    return "";
}


// =============================================================================
// VEX THE TRAINER - helper functions
// Permanent meta-progression bought from Vex: trait slots, ability unlocks,
// and trait potency (stat-sacrifice strengthening).
// =============================================================================

// ---------------------------------------------------------------------------
// max_trait_slots()
// Total active-trait slots available: base 2 + bought bonus_trait_slots
// (Vex, max +4 as of M 07-16) + 1 while Crown of the Hollow King is equipped.
// Single source of truth used by the loadout select/draw code.
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
        // Duelist Arts (DESIGN_DUELIST_CHALLENGE.md): earned, never bought.
        case "Measured Riposte": return { type:"goal", cost:0, goal_type:"duelist_tokens", goal_value:1 };
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
        // #26 Arcanist melee kit - premium tier above the 100/250/400 ladder
        case "Blazing Palm":     return { type:"vex", cost:500,  goal_type:"", goal_value:0 };
        case "Gravewrack Grip":  return { type:"vex", cost:800,  goal_type:"", goal_value:0 };
        case "Soul Rend":        return { type:"vex", cost:1200, goal_type:"", goal_value:0 };
        // D§4 wave (M-approved pricing: 1-AP 250 / 2-AP 400 / engine 500 / gamble 100)
        case "Glacial Ward":     return { type:"vex", cost:250, goal_type:"", goal_value:0 };
        case "Static Arc":       return { type:"vex", cost:250, goal_type:"", goal_value:0 };
        case "Hoarfrost Lance":  return { type:"vex", cost:400, goal_type:"", goal_value:0 };
        case "Soul Engine":      return { type:"vex", cost:500, goal_type:"", goal_value:0 };
        case "Galvanize":        return { type:"vex", cost:400, goal_type:"", goal_value:0 };
        case "Winter's Bite":    return { type:"vex", cost:250, goal_type:"", goal_value:0 };
        case "Devil's Flip":     return { type:"vex", cost:100, goal_type:"", goal_value:0 };
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
        case "Warpath":          return { type:"vex", cost:500, goal_type:"", goal_value:0 };  // 07-16 ramp (Soul Engine tier)
        case "Bulwark Slam":     return { type:"vex", cost:400, goal_type:"", goal_value:0 };  // 07-17 combat plan v2
        // Shadowstrider
        case "Smoke Bomb":       return { type:"vex", cost:100, goal_type:"", goal_value:0 };
        case "Frost Shot":       return { type:"vex", cost:100, goal_type:"", goal_value:0 };
        case "Compounding Dread": return { type:"vex", cost:500, goal_type:"", goal_value:0 };  // 07-16 ramp (Soul Engine tier)
        case "Counterblade":     return { type:"vex", cost:400, goal_type:"", goal_value:0 };  // 07-17 combat plan v2
        case "Marked for Death": return { type:"vex", cost:100, goal_type:"", goal_value:0 };
        case "Spike Trap":       return { type:"vex", cost:250, goal_type:"", goal_value:0 };
        case "Evasive Roll":     return { type:"vex", cost:250, goal_type:"", goal_value:0 };
        case "Flurry":           return { type:"vex", cost:250, goal_type:"", goal_value:0 };
        case "Vanish":           return { type:"vex", cost:250, goal_type:"", goal_value:0 };
        case "Death Snare":      return { type:"vex", cost:400, goal_type:"", goal_value:0 };
        // Deployed-trap kit (08-08). Wire Snare + Warding Chime are deliberately
        // ABSENT from this table - a missing entry means "free starter", and the
        // class needs its anti-ranged and anti-caster answers from level 1 (M).
        case "Tripline":         return { type:"vex", cost:150, goal_type:"", goal_value:0 };
        case "Caltrops":         return { type:"vex", cost:250, goal_type:"", goal_value:0 };
        // Mutator v2 innate carriers (08-11): trick shots are taught, not found.
        case "Ricochet Shot":    return { type:"vex", cost:250, goal_type:"", goal_value:0 };
        case "Bouncing Bomb":    return { type:"vex", cost:400, goal_type:"", goal_value:0 };
        case "Gout of Rot":      return { type:"vex", cost:250, goal_type:"", goal_value:0 };
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
    return vex_price(cha_price(_info.cost));   // CHA vendor discount + Vex Friend perk
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
        case "duelist_tokens":   // Duelist Arts ladder (DESIGN_DUELIST_CHALLENGE.md)
            return variable_global_exists("duelist_tokens") && global.duelist_tokens >= goal_value;
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
        case "duelist_tokens":       return "Unlock: a certain duelist parts with a token...";   // hidden progression - stays cryptic
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
    // TEST LEVER (F8, gc Step): everything reads unlocked while the toggle is on.
    if (variable_global_exists("debug_unlock_all") && global.debug_unlock_all) return true;
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

// =============================================================================
// ABILITY TALENT WEBS (SYSTEMS_TALENT_WEBS.md, design-locked 2026-07-27).
// Replaces the mastery-notch system. Every ability has a 7-node "wishbone":
// a free root (the ability itself) + a POWER branch (p1/p2/pk) and a TWIST
// branch (t1/t2/tk) with a keystone at each branch end. Mastery Points (MP)
// come from lifetime casts of THAT ability (10/30/60/100); the SPEND CAP is
// 4 of 6 nodes - a full branch costs 3, so one keystone + one dip, never both.
// Webs are GENERATED from the ability's shape here; bespoke name-keyed node
// overrides arrive in Phase 3. Picks are handed out as field-adjusted COPIES
// at loadout resolve (pools stay pristine; dynamic descriptions read the
// copy). Storage: global.ability_casts { name: count } and
// global.ability_web { name: [node_ids] } - both saved (SAVE_FORMAT v4;
// pre-v4 mastery picks are dropped on load and every earned MP returns as
// pending, so old saves re-pick - a strict buff).
// =============================================================================

function ability_web_thresholds() { return [10, 30, 60, 100]; }
function ability_web_cap()        { return 4; }

function ability_casts(name) {
    if (!variable_global_exists("ability_casts") || !is_struct(global.ability_casts)) return 0;
    return variable_struct_exists(global.ability_casts, name) ? variable_struct_get(global.ability_casts, name) : 0;
}

// MP earned so far from lifetime casts, clamped to the spend cap (0-4).
function ability_web_mp_earned(name) {
    var _c = ability_casts(name);
    var _th = ability_web_thresholds();
    var _n = 0;
    for (var _i = 0; _i < array_length(_th); _i++) if (_c >= _th[_i]) _n++;
    return min(_n, ability_web_cap());
}

// The node ids already bought for this ability (array, newest last).
function ability_web_picks(name) {
    if (!variable_global_exists("ability_web") || !is_struct(global.ability_web)) return [];
    return variable_struct_exists(global.ability_web, name) ? variable_struct_get(global.ability_web, name) : [];
}

// MP earned but not yet spent on a node.
function ability_web_mp_pending(name) {
    return max(0, ability_web_mp_earned(name) - array_length(ability_web_picks(name)));
}

// Cast count of the next threshold that still yields a spendable MP (-1 = all
// 4 earned). Feeds the web view's "next point at N casts" line.
function ability_web_next_threshold(name) {
    var _c = ability_casts(name);
    var _th = ability_web_thresholds();
    for (var _i = 0; _i < array_length(_th); _i++) if (_c < _th[_i]) return _th[_i];
    return -1;
}

// Count one cast (called from the combat controller at cast commit). Pushes a
// log line when an MP threshold is crossed so the moment lands in the fight.
function ability_web_count_cast(name, combat_log) {
    if (!variable_global_exists("ability_casts") || !is_struct(global.ability_casts)) global.ability_casts = {};
    var _before = ability_web_mp_earned(name);
    variable_struct_set(global.ability_casts, name, ability_casts(name) + 1);
    if (ability_web_mp_earned(name) > _before) {
        if (is_array(combat_log))
            array_push(combat_log, "TALENT POINT earned: " + name + "!  (open its web at the loadout)");
        // First point ever, in the fight where it lands: teach the whole mechanic
        // once (M 08-08 - the log line alone never explained that webs exist).
        tutorial_try_show("talent_first");
    }
}

// ---------------------------------------------------------------------------
// WEB GENERATION. A node: { id, branch ("P"/"T"), tier (1-3), title, label,
// mods (field-mod id array, see ability_web_apply_mod), rider ("" or a key
// the combat controller checks - riders only ever ride DAMAGING abilities;
// pure-debuff abilities must not gain on-hit riders, see
// project_debuff_no_attack_riders). Templates key off the same shape axes the
// old mastery options used, widened with attack-class and cooldown.
// ---------------------------------------------------------------------------
function ability_web_node(id, branch, tier, title, label, mods, rider) {
    return { id: id, branch: branch, tier: tier, title: title, label: label, mods: mods, rider: rider };
}

// Webs must ALWAYS generate from the PRISTINE pool struct - a resolved copy's
// shifted fields (e.g. an AP-cost node lowering energy_cost) would otherwise
// regenerate a different template and silently remap owned node ids. Accepts
// a struct or a name; searches every pool (borrowed abilities included).
function ability_web_pristine(ab_or_name) {
    var _nm = is_struct(ab_or_name) ? ab_or_name.name : ab_or_name;
    var _pools = [global.abilities_arcanist, global.abilities_bloodwarden,
                  global.abilities_shadowstrider, global.abilities_general];
    for (var _p = 0; _p < array_length(_pools); _p++) {
        for (var _i = 0; _i < array_length(_pools[_p]); _i++) {
            if (_pools[_p][_i].name == _nm) return _pools[_p][_i];
        }
    }
    return is_struct(ab_or_name) ? ab_or_name : undefined;
}

function ability_web_nodes(ab) {
    ab = ability_web_pristine(ab);
    var _n        = [];
    var _is_spell = ability_class_is_spell(ability_attack_class(ab));
    var _sure     = (ab.guaranteed_hit || ab.base_acc >= 100);
    var _has_cd   = (ability_cooldown(ab) > 0);
    var _has_dur  = (ab.effect_duration > 0);
    if (ability_is_trap(ab.name)) {
        // DEPLOYED TRAPS (08-08). They need their own branch: post-rework a trap
        // has base_damage 0, no duration and effect_value 0, so it fell through to
        // the INSTANT-EFFECT template - where t1/t2 are literally "Deeper Roots II"
        // and "Concentration II", duplicates of p1/p2, all scaling a value of 0.
        // That is the identical-both-sides web M reported on Bear Trap.
        //
        // The two sides are now genuinely different questions:
        //   POWER  - make the spring HURT more (payload)
        //   TWIST  - change WHEN and HOW OFTEN it springs (behaviour)
        // Payload lives in trap_catalog(), so these are riders read at deploy.
        var _tdf2 = trap_def(ab.name);
        var _tblk = (_tdf2 != undefined && _tdf2.block);
        array_push(_n, ability_web_node("p1", "P", 1, "Weighted Jaws",
            "+6 damage when it springs", [], "trap_dmg"));
        array_push(_n, ability_web_node("p2", "P", 2, "Barbed Edge",
            "Its effect lasts 1 turn longer", [], "trap_dur"));
        array_push(_n, ability_web_node("pk", "P", 3, "Hunter's Anchor",
            "Springing also leaves the target Vulnerable (1 turn)", [], "trap_vuln"));
        array_push(_n, ability_web_node("t1", "T", 1, "Twin Jaws",
            "Springs one extra time before it is spent", [], "trap_charge"));
        // The tier-2 twist depends on what the trap already does, so the choice is
        // never a dead button: a picky trap learns to catch anything, and a trap
        // that already catches everything learns to stop the blow instead.
        array_push(_n, (_tdf2 != undefined && _tdf2.filter != "any")
            ? ability_web_node("t2", "T", 2, "Wide Set",
                "Springs on ANY enemy action, not just " + trap_filter_label(_tdf2.filter), [], "trap_any")
            : ability_web_node("t2", "T", 2, "Iron Plate",
                "It now BLOCKS the action it springs on", [], "trap_block"));
        array_push(_n, _tblk
            ? ability_web_node("tk", "T", 3, "Second Chance",
                "A blocked attacker is Stunned for 1 turn on top of everything else", [], "trap_stun")
            : ability_web_node("tk", "T", 3, "Caltrop Spread",
                "Springing damages EVERY living enemy, not just the one that set it off", [], "trap_splash"));
    } else if (ab.base_damage > 0) {
        // DAMAGING - POWER = raw output, TWIST = tempo/reliability. Keystones
        // draw from a TRANSFORMATIVE POOL via a deterministic per-name hash so
        // sibling abilities diverge (M 07-27: "the talents are all too
        // identical"); bespoke signature overrides below replace these wholesale.
        var _h = 0;
        for (var _hc = 1; _hc <= string_length(ab.name); _hc++) _h += ord(string_char_at(ab.name, _hc));
        array_push(_n, ability_web_node("p1", "P", 1, "Keen Edge", "+3 base damage", ["dmg"], ""));
        array_push(_n, _sure
            ? ability_web_node("p2", "P", 2, "Deadly Precision", "+4% crit chance", ["crit"], "")
            : ability_web_node("p2", "P", 2, "True Aim", "+5 accuracy", ["acc"], ""));
        var _pk;
        if (_is_spell) {
            switch (_h mod 4) {
                case 0:  _pk = ability_web_node("pk", "P", 3, "Unstable Charge", "Hits DETONATE the target's statuses", [], "detonate"); break;
                case 1:  _pk = ability_web_attune_node("pk", ab); break;
                case 2:  _pk = ability_web_node("pk", "P", 3, "Forking Torrent", "Echoes 50% of its damage to another enemy", [], "splash:50"); break;
                default: _pk = ability_web_node("pk", "P", 3, "Overwhelm", "Hits inflict Vulnerable (1 turn)", [], "hit_vuln");
            }
        } else {
            switch (_h mod 3) {
                case 0:  _pk = ability_web_node("pk", "P", 3, "Executioner's Rhythm", "Killing blows refund 1 AP", [], "kill_ap"); break;
                case 1:  _pk = ability_web_node("pk", "P", 3, "Headsman's Edge", "+50% damage below 25% HP", [], "execute:50"); break;
                default: _pk = ability_web_node("pk", "P", 3, "Concussive Impact", "Hits DETONATE the target's statuses", [], "detonate");
            }
        }
        array_push(_n, _pk);
        array_push(_n, _sure
            ? ability_web_node("t1", "T", 1, "Heavy Hand", "+15% base damage", ["dmgp"], "")
            : ability_web_node("t1", "T", 1, "Killer Instinct", "+4% crit chance", ["crit"], ""));
        if (_has_cd)       array_push(_n, ability_web_node("t2", "T", 2, "Swift Recovery", "Cooldown -1 turn", ["cdm"], ""));
        else if (_has_dur) array_push(_n, ability_web_node("t2", "T", 2, "Lasting Mark", "+1 turn effect duration", ["dur"], ""));
        else               array_push(_n, ability_web_node("t2", "T", 2, "Brutal Momentum", "+15% base damage", ["dmgp"], ""));
        var _tk;
        switch ((_h div 7) mod 3) {
            case 0:  _tk = ability_web_node("tk", "T", 3, "Opening Gambit", "First cast each combat costs 1 less AP", [], "first_free"); break;
            case 1:  _tk = ability_web_node("tk", "T", 3, "Red Harvest", "Heals you for 25% of damage dealt", [], "lifesteal:25"); break;
            default: _tk = _is_spell
                ? ability_web_node("tk", "T", 3, "Culling Wave", "+50% damage below 25% HP", [], "execute:50")
                : ability_web_node("tk", "T", 3, "Cleaving Follow-through", "Echoes 50% of its damage to another enemy", [], "splash:50");
        }
        array_push(_n, _tk);
    } else if (_has_dur) {
        // TIMED EFFECT, no damage (pure debuffs/buffs - no on-hit riders).
        // Value nodes name the CONCRETE unit + numbers via ability_web_val_node
        // (M 07-28: "+2 effect strength" on Blink says nothing).
        array_push(_n, ability_web_val_node(ab, "p1", "P", 1, "Deeper Roots", "add"));
        array_push(_n, ability_web_val_node(ab, "p2", "P", 2, "Concentration", "mult20"));
        array_push(_n, ability_web_node("pk", "P", 3, "Lingering Grip", "+2 turns duration", ["dur2"], ""));
        array_push(_n, ability_web_node("t1", "T", 1, "Endurance", "+1 turn duration", ["dur"], ""));
        if (_has_cd)                   array_push(_n, ability_web_node("t2", "T", 2, "Swift Recovery", "Cooldown -1 turn", ["cdm"], ""));
        else if (ab.energy_cost >= 2)  array_push(_n, ability_web_node("t2", "T", 2, "Efficient Form", "Costs 1 less AP", ["apc"], ""));
        else                           array_push(_n, ability_web_val_node(ab, "t2", "T", 2, "Taproot", "mult50"));
        array_push(_n, (ab.energy_cost <= 0 && ab.secondary_cost > 0)
            ? ability_web_node("tk", "T", 3, "Opening Gambit", "First cast each combat costs no class resource", [], "first_free")
            : ability_web_node("tk", "T", 3, "Opening Gambit", "First cast each combat costs 1 less AP", [], "first_free"));
    } else {
        // INSTANT EFFECT (heals, shields, resource bursts).
        array_push(_n, ability_web_val_node(ab, "p1", "P", 1, "Deeper Roots", "add"));
        array_push(_n, ability_web_val_node(ab, "p2", "P", 2, "Concentration", "mult20"));
        array_push(_n, ability_web_val_node(ab, "pk", "P", 3, "Overflowing Power", "mult50"));
        array_push(_n, (ab.energy_cost >= 2)
            ? ability_web_node("t1", "T", 1, "Efficient Form", "Costs 1 less AP", ["apc"], "")
            : ability_web_val_node(ab, "t1", "T", 1, "Taproot", "add4"));
        if (_has_cd) array_push(_n, ability_web_node("t2", "T", 2, "Swift Recovery", "Cooldown -1 turn", ["cdm"], ""));
        else         array_push(_n, ability_web_val_node(ab, "t2", "T", 2,
                         (ab.energy_cost >= 2) ? "Taproot" : "Floodgate",
                         (ab.energy_cost >= 2) ? "add4" : "mult50"));
        array_push(_n, (ab.energy_cost <= 0 && ab.secondary_cost > 0)
            ? ability_web_node("tk", "T", 3, "Opening Gambit", "First cast each combat costs no class resource", [], "first_free")
            : ability_web_node("tk", "T", 3, "Opening Gambit", "First cast each combat costs 1 less AP", [], "first_free"));
    }
    // Bespoke SIGNATURE overrides (Phase 3 pulled forward, M 07-27): a
    // hand-authored node replaces the template node with the same id.
    // ⚠ REPLACE-ONLY: the web UI draws exactly six ids (p1/p2/pk/t1/t2/tk),
    // so a bespoke node with any OTHER id is silently dropped here. New
    // bespoke nodes must claim one of the six slots (08-11 lesson: four
    // mutator nodes shipped with id "mt" and never appeared).
    var _bs = ability_web_bespoke(ab);
    for (var _bi = 0; _bi < array_length(_bs); _bi++) {
        for (var _bj = 0; _bj < array_length(_n); _bj++) {
            if (_n[_bj].id == _bs[_bi].id) { _n[_bj] = _bs[_bi]; break; }
        }
    }
    return _n;
}

// What this ability's effect_value MEANS, in the player's words - feeds the
// generic web-node descriptions (M 07-28: "+2 effect strength" on Blink says
// nothing; "+2 healing (14 -> 16)" is the standard we want).
function ability_web_val_noun(ab) {
    // Name-keyed first. "effect potency" is meaningless next to a sibling node
    // reading "+1 turn duration" - M 08-08 could not tell whether "+2 effect
    // potency" on Shadow Step meant two more dodges or something else entirely.
    // Where the stored value has a concrete in-fiction unit, SAY the unit.
    switch (ab.name) {
        case "Shadow Step":  return "dodge charges";
        case "Blink":        return "guarded attacks";
        case "Evasive Roll": return "damage threshold";
    }
    switch (ab.effect_type) {
        case "heal":     return "healing";
        case "shield":   return "shield";
        case "dot":      return "damage per turn";
        case "resource": return "resource gained";
        case "debuff":   return "debuff potency";
        case "status":   return "effect potency";
    }
    return "effect strength";
}

// Build a generic value node with a CONCRETE description (unit + base -> new
// numbers). kind: "add" (+2 flat), "mult20" (x1.2), "mult50" (x1.5).
// FRACTION-VALUED abilities (a -30% debuff stores 0.3) always get the
// multiplicative rider - the flat +2 would explode a 0.3 fraction to 2.3
// ("-230%"), which was a live defect in the launch template. The shown numbers
// mirror the rider math exactly (ceil for whole values, 95% cap for fractions).
function ability_web_val_node(ab, _id, _br, _lv, _nm, _kind) {
    var _v    = ab.effect_value;
    var _frac = (_v > 0 && _v < 1);
    var _noun = ability_web_val_noun(ab);
    var _desc, _rider;
    if (_kind == "add4" && !_frac) {
        // 08-08: the template only had add / mult20 / mult50, and the POWER side
        // used all three - so both TWIST fallbacks were forced to re-emit a node
        // the player had already seen. The Whetstone shows two web nodes side by
        // side and asks you to pick ONE, which turned into a non-choice: M shot
        // "Deeper Roots" and "Deeper Roots II" both reading +2 effect strength.
        // A fourth tier gives the twist side something of its own to say.
        _rider = ["val", "val"];
        _desc  = "+4 " + _noun + "  (" + string(_v) + " -> " + string(_v + 4) + ")";
    } else if (_kind == "add" && !_frac) {
        _rider = ["val"];
        _desc  = "+2 " + _noun + "  (" + string(_v) + " -> " + string(_v + 2) + ")";
    } else if (_kind == "mult50") {
        _rider = ["valh"];
        _desc  = _frac
            ? ("+50% " + _noun + "  (" + string(round(_v * 100)) + "% -> " + string(round(min(0.95, _v * 1.5) * 100)) + "%)")
            : ("+50% " + _noun + "  (" + string(_v) + " -> " + string(ceil(_v * 1.5)) + ")");
    } else {
        _rider = ["valp"];
        _desc  = _frac
            ? ("+20% " + _noun + "  (" + string(round(_v * 100)) + "% -> " + string(round(min(0.95, _v * 1.2) * 100)) + "%)")
            : ("+20% " + _noun + "  (" + string(_v) + " -> " + string(ceil(_v * 1.2)) + ")");
    }
    return ability_web_node(_id, _br, _lv, _nm, _desc, _rider, "");
}

// School adjacency for Attunement choice nodes - which schools an ability can
// convert to (never its own; elemental trio cross-converts, dark schools stay
// in their family). Player-facing choice: this is a rare point of expression.
function ability_web_attune_schools(school) {
    switch (school) {
        case "arcane": return ["fire", "frost", "shock"];
        case "fire":   return ["frost", "shock"];
        case "frost":  return ["fire", "shock"];
        case "shock":  return ["fire", "frost"];
        case "blood":  return ["void", "shadow"];
        case "void":   return ["blood", "shadow"];
        case "shadow": return ["void", "poison"];
        case "poison": return ["shadow", "void"];
    }
    return ["fire", "frost", "shock"];
}

// An Attunement CHOICE node: staging it cycles through the offered schools
// (stored as "pk@fire"). Converting rebases what +school% gear feeds the
// ability, its log color and its VFX tint.
function ability_web_attune_node(id, ab) {
    var _sc  = ability_web_attune_schools(ability_school(ab));
    var _lbl = "Convert its school: ";
    for (var _i = 0; _i < array_length(_sc); _i++) _lbl += ((_i > 0) ? " / " : "") + school_label(_sc[_i]);
    var _nd = ability_web_node(id, (id == "pk") ? "P" : "T", 3, "Attunement", _lbl, [], "");
    _nd.schools = _sc;
    return _nd;
}

// Hand-authored signature nodes (M 07-27: unique, ability-changing usage).
// Each returned node REPLACES the template node with the same id. All numbers
// first-pass/tunable; riders are the shared primitives wired in the combat
// controller, so bespoke here means curated PAIRINGS + names, not new systems.
function ability_web_bespoke(ab) {
    var _out = [];
    switch (ab.name) {
        // --- Arcanist ---
        case "Soulfire":
            array_push(_out, ability_web_node("pk", "P", 3, "Pyre Unending", "Killing blows refund 1 AP", [], "kill_ap"));
            var _sf = ability_web_node("tk", "T", 3, "Cinderheart", "Soulfire burns as FIRE - fire gear now feeds it", [], "");
            _sf.school_to = "fire";
            array_push(_out, _sf);
            break;
        case "Arcane Burst": {
            var _abu = ability_web_attune_node("pk", ab);
            _abu.title = "Prismatic Burst";
            array_push(_out, _abu);
            // P3 (08-05): the signature pairing - burst as the opener.
            array_push(_out, ability_web_node("tk", "T", 3, "Resonant Opening", "First cast each combat costs 1 less AP", [], "first_free"));
            break;
        }
        case "Void Drain":
            // P3 (08-05): the drain marks what it feeds on.
            array_push(_out, ability_web_node("pk", "P", 3, "Voidbrand", "Hits inflict Vulnerable (1 turn)", [], "hit_vuln"));
            array_push(_out, ability_web_node("tk", "T", 3, "Hungering Maw", "Critical hits grant +1 class resource", [], "crit_sec:1"));
            break;
        case "Singularity":
            array_push(_out, ability_web_node("pk", "P", 3, "Event Horizon", "Its crush DETONATES statuses on enemies it hits", [], "detonate"));
            // P3 (08-05): the well feeds itself - cheaper to open.
            array_push(_out, ability_web_node("tk", "T", 3, "Accretion", "Costs 1 less Soul (3 -> 2)", ["secc"], ""));
            break;
        case "Entropy":
            array_push(_out, ability_web_node("pk", "P", 3, "Entropic Collapse", "Hits DETONATE the target's statuses", [], "detonate"));
            // P3 (08-05): everything ends - Entropy just gets there first.
            array_push(_out, ability_web_node("tk", "T", 3, "Heat Death", "+50% damage below 25% HP", [], "execute:50"));
            // Delivery mutator, weak tier (08-11): the collapse comes back around.
            // 08-11 fix: bespoke ids only REPLACE template slots (the web UI
            // draws exactly p1/p2/pk/t1/t2/tk) - an appended "mt" id was
            // silently dropped. The mutator node takes the t2 slot instead.
            array_push(_out, ability_web_node("t2", "T", 2, "Recurrence", "Its hit ECHOES on the target moments later (35% + void bonus)", [], "mut_echo:35"));
            break;
        case "Hoarfrost Lance":
            // Delivery mutator, weak tier (08-11, SYSTEMS_MUTATORS.md).
            array_push(_out, ability_web_node("pk", "P", 3, "Shatterfork", "The lance SPLITS - forking to a second enemy (50% + frost bonus)", [], "mut_split:50"));
            break;
        case "Scorch":
            array_push(_out, ability_web_node("pk", "P", 3, "Wildfire", "The flames leap - echoes 50% damage to another enemy", [], "splash:50"));
            break;
        // --- Weak-baseline self-synergy pass (task #14, M-approved 07-28: "weak
        // unupgraded is fine - its talents amplify it and make it synergize with
        // itself, and only players who experiment discover this") ---
        case "Static Arc":
            array_push(_out, ability_web_node("p2", "P", 2, "Live Wire", "Hits SHOCK the target (1 turn) - your own next Arc chains to ALL", [], "hit_shock"));
            array_push(_out, ability_web_node("pk", "P", 3, "Storm Unbound", "Its chain carries FULL damage (100% instead of 50%)", [], "chain_full"));
            array_push(_out, ability_web_node("tk", "T", 3, "Closed Circuit", "Killing blows refund 1 AP", [], "kill_ap"));
            break;
        case "Devil's Flip":
            array_push(_out, ability_web_node("pk", "P", 3, "Loaded Coin", "The streak grows +12 per win instead of +8", [], "flip_hot"));
            array_push(_out, ability_web_node("tk", "T", 3, "Devil's Insurance", "A LOSS deals you no damage (the streak still dies)", [], "flip_safe"));
            break;
        case "Glacial Ward":
            array_push(_out, ability_web_node("pk", "P", 3, "Deep Freeze", "The ward's rebuke Chills RANGED attackers too", [], "ward_reach"));
            break;
        case "Galvanize":
            array_push(_out, ability_web_node("pk", "P", 3, "Chain Reaction", "Also triggers on landing a CRIT, not just a kill", [], "galv_crit"));
            // Delivery mutator, weak tier (v2, 08-11 - M: "talents that make
            // spells bounce as well"). Shock spice makes this the meanest weak
            // bounce in the game (40 + 15 = 55%).
            array_push(_out, ability_web_node("t2", "T", 2, "Live Current", "The shock ARCS ON - a bolt leaps to a second enemy (40% + shock bonus)", [], "mut_bounce:40"));
            break;
        case "Blink":
            array_push(_out, ability_web_node("t1", "T", 1, "Afterimage Veil", "The 2nd/3rd attacks are softened 60%/35% (up from 50%/25%)", [], "blink_soft"));
            array_push(_out, ability_web_node("tk", "T", 3, "Counterphase", "When Blink fully evades an attack, your next ability costs 1 less AP", [], "blink_tempo"));
            break;
        case "Smoke Bomb":
            array_push(_out, ability_web_node("t1", "T", 1, "Acrid Haze", "The smoke also WEAKENS enemies inside it (-15% damage)", [], "smoke_weaken"));
            array_push(_out, ability_web_node("tk", "T", 3, "Choking Cloud", "Enemies caught in the smoke lose their planned move", [], "smoke_confound"));
            break;
        case "Soul Harvest":
            array_push(_out, ability_web_node("t1", "T", 1, "Reaper's Tempo", "+1 extra Soul if an enemy died this round", [], "harvest_kill"));
            array_push(_out, ability_web_node("tk", "T", 3, "Soulmend", "Also heals 3 HP per Soul it gathers", [], "soulmend"));
            break;
        case "Adrenaline Rush":
            array_push(_out, ability_web_node("t1", "T", 1, "Numbed Nerves", "The push costs 3 HP instead of 5", [], "rush_cheap"));
            array_push(_out, ability_web_node("tk", "T", 3, "Overdrive", "Once per combat, it can fire TWICE in one turn", [], "overdrive"));
            break;
        case "Second Wind":
            array_push(_out, ability_web_node("t1", "T", 1, "Clean Break", "Cleanses your TWO newest afflictions", [], "cleanse_two"));
            array_push(_out, ability_web_node("tk", "T", 3, "Adrenal Memory", "Also refunds 1 AP when cast below half HP", [], "adrenal_memory"));
            break;
        // --- Bloodwarden ---
        case "Blood Leech":
            array_push(_out, ability_web_node("pk", "P", 3, "Exsanguinate", "Heals you for 50% of damage dealt", [], "lifesteal:50"));
            // P3 (08-05): a leech that bites an artery drinks twice.
            array_push(_out, ability_web_node("tk", "T", 3, "Glutted Vein", "Critical hits grant +1 class resource", [], "crit_sec:1"));
            // Delivery mutator, weak tier (08-11): the bite keeps drinking.
            array_push(_out, ability_web_node("t2", "T", 2, "Seeping Wound", "The wound LINGERS - a 2-turn bleed at 30% of the hit (+blood bonus)", [], "mut_linger:30"));
            break;
        case "Blood Surge":
            // 07-29 M pass: the template gave it FOUR near-identical +healing
            // nodes (Deeper Roots I/II + Concentration I/II). The Twist branch
            // becomes the blood-economy line instead: cheaper casts, then
            // overheal that doesn't waste.
            array_push(_out, ability_web_node("t1", "T", 1, "Thick Blood", "Costs 1 less Blood (2 -> 1)", ["secc"], ""));
            array_push(_out, ability_web_node("t2", "T", 2, "Crimson Overflow", "Healing past full hardens into a shield", [], "overheal_shield"));
            break;
        case "Gore Strike":
            array_push(_out, ability_web_node("pk", "P", 3, "Butcher's Rhythm", "+50% damage below 25% HP", [], "execute:50"));
            // P3 (08-05): the spray was never going to stay on one target.
            array_push(_out, ability_web_node("tk", "T", 3, "Arterial Spray", "Echoes 50% of its damage to another enemy", [], "splash:50"));
            break;
        case "Iron Skin":
            // P3 (07-29): t2 was a template clone. "Sharp Edges" rides the
            // per-attack melee classification - while the skin holds, melee
            // blows that land take its reduction value back as damage.
            array_push(_out, ability_web_node("t2", "T", 2, "Sharp Edges", "While Iron Skin holds, melee blows that hit you take its reduction back", [], "sharp_edges"));
            array_push(_out, ability_web_node("tk", "T", 3, "Iron Bulwark", "Also raises a 6-point shield on cast", [], "cast_shield:6"));
            break;
        case "Soul Shield":
            // P3 (07-29): scale its Soul identity, then let the wall outlive the fight.
            array_push(_out, ability_web_node("t1", "T", 1, "Soulweave", "+4 shield per Soul held (up from +3)", [], "soul_dense"));
            array_push(_out, ability_web_node("tk", "T", 3, "Unbroken", "Shield left standing at victory carries to the next combat (max 10)", [], "unbroken"));
            break;
        case "Sanguine Pact":
            array_push(_out, ability_web_node("t1", "T", 1, "Rich Veins", "Each Blood seals into 7 shield (up from 6)", [], "pact_dense"));
            array_push(_out, ability_web_node("tk", "T", 3, "Blood Debt", "The pact ward SHATTERING deals its full value to the one who broke it", [], "blood_debt"));
            break;
        case "Warpath":
            array_push(_out, ability_web_node("t1", "T", 1, "First Blood", "The march starts a turn pre-lit (+2 on the first swing)", [], "ramp_prelit"));
            array_push(_out, ability_web_node("tk", "T", 3, "Crescendo", "The ramp climbs harder: +3 per turn instead of +2", [], "ramp_fast"));
            break;
        case "Compounding Dread":
            array_push(_out, ability_web_node("t1", "T", 1, "Old Fear", "The dread starts pre-lit - your first trap already carries the bonus", [], "ramp_prelit"));
            array_push(_out, ability_web_node("tk", "T", 3, "Crescendo", "Each trap teaches the next +6 instead of +4", [], "ramp_fast"));
            break;
        case "Undying":
            // P3 (08-05): refusal, sustained.
            array_push(_out, ability_web_node("t1", "T", 1, "Stubborn Heart", "+1 turn effect duration", ["dur"], ""));
            array_push(_out, ability_web_node("tk", "T", 3, "Blood Ward", "Also raises an 8-point shield on cast", [], "cast_shield:8"));
            break;
        case "Plague Touch":
            array_push(_out, ability_web_node("pk", "P", 3, "Pandemic", "Its plague spreads to a second enemy", [], "status_splash"));
            // P3 (08-05): pure-debuff, so no on-hit riders (standing rule) - the
            // signature deepens the rot itself. (The old "dead mortality" note is
            // stale: enemy mends now route through combat_heal_after_mortality,
            // so its anti-heal already bites healer packs.)
            array_push(_out, ability_web_node("t1", "T", 1, "Festering Grip", "+1 turn effect duration", ["dur"], ""));
            break;
        // --- Shadowstrider ---
        case "Snipe":
            array_push(_out, ability_web_node("pk", "P", 3, "Deadeye", "Critical Snipes leave the target Vulnerable (2 turns)", [], "crit_vuln:2"));
            // P3 (08-05): the sniper's creed.
            array_push(_out, ability_web_node("tk", "T", 3, "One Shot, One Kill", "+50% damage below 25% HP", [], "execute:50"));
            break;
        case "Poison Dart":
            array_push(_out, ability_web_node("pk", "P", 3, "Virulent Spread", "Its venom jumps to a second enemy", [], "status_splash"));
            // P3 (08-05): a needle placed where the armor isn't.
            array_push(_out, ability_web_node("tk", "T", 3, "Nerve Puncture", "Hits inflict Vulnerable (1 turn)", [], "hit_vuln"));
            // Delivery mutator, weak tier (08-11): venom that pools in the wound.
            array_push(_out, ability_web_node("t2", "T", 2, "Pooling Venom", "The venom LINGERS - a 2-turn poison at 30% of the hit (+poison bonus)", [], "mut_linger:30"));
            break;
        // --- Deployed-trap P5 nodes (08-11, SYSTEMS_TRAPS.md §6). Each REPLACES
        // a template slot (the web UI draws exactly six ids). Riders bake into
        // the deployed instance at set time like every other trap_* key.
        case "Bear Trap":
            array_push(_out, ability_web_node("tk", "T", 3, "Resetting Coil",
                "The FIRST spring each combat re-arms the trap instead of spending it", [], "trap_reset"));
            break;
        case "Death Snare":
            array_push(_out, ability_web_node("p2", "P", 2, "Patient Hands",
                "Its payload DOUBLES once it has waited 3+ rounds on the board", [], "trap_patient"));
            break;
        case "Tripline":
            // Replaces "Weighted Jaws +6 damage" - a near-dead node on the one
            // trap whose whole identity is dealing NO damage.
            array_push(_out, ability_web_node("p1", "P", 1, "Trapper's Bandolier",
                "You carry a THIRD trap slot", [], "trap_slots"));
            break;
        // Bear Trap / Death Snare bespoke overrides REMOVED 08-08. They described
        // the pre-rework instant-hit traps ("Its bite lays the target Vulnerable",
        // "Hits DETONATE") and they replaced pk/tk by id, so they were overwriting
        // the new deployed-trap nodes with copy that no longer matched the ability.
        // The trap branch in the generic builder owns all seven traps now.
        case "Shadow Step":
            // 08-11 FULL bespoke override (M audit): the timed-effect template
            // gave it Deeper Roots / Concentration / Lingering Grip / Endurance
            // - all DEAD nodes here (they scale effect_value/duration, which the
            // charge mechanic never reads) that READ like stacking dodge charges
            // toward infinite evasion. Every id is now overridden with a node
            // that actually does something, and none of them adds charges beyond
            // Long Stride's 4.
            array_push(_out, ability_web_node("p1", "P", 1, "Sharpened Instinct", "+10% dodge chance while its charges are active", [], "step_evade:10"));
            array_push(_out, ability_web_node("p2", "P", 2, "Coiled Step", "Also grants +1 Prep on cast", [], "cast_sec:1"));
            array_push(_out, ability_web_node("pk", "P", 3, "Slipstream", "Costs 1 less AP", ["apc"], ""));
            array_push(_out, ability_web_node("t1", "T", 1, "Long Stride", "Grants 4 dodge charges instead of 3", [], "step_charges"));
            array_push(_out, ability_web_node("tk", "T", 3, "Phantom Momentum", "Each successful Shadow Step dodge grants +1 Prep", [], "step_dodge_prep"));
            break;
        case "Frost Shot":
            array_push(_out, ability_web_node("pk", "P", 3, "Shattering Volley", "Echoes 50% of its damage to another enemy", [], "splash:50"));
            break;
        // --- General pool ---
        case "Vanish":
            array_push(_out, ability_web_node("t1", "T", 1, "Deeper Shadow", "The ambush strike hits +18 (up from +12)", [], "vanish_sharp"));
            array_push(_out, ability_web_node("pk", "P", 3, "Shadow Feint", "Also grants +1 class resource on cast", [], "cast_sec:1"));
            break;
        case "Field Dressing":
            // 07-29 M pass: the template's t1 was a Deeper Roots clone. Power
            // stays the raw-healing line; the Twist branch opens with utility -
            // go bigger heals or go cleanse.
            array_push(_out, ability_web_node("t1", "T", 1, "Mender's Rite", "Also cleanses your newest debuff", [], "self_cleanse"));
            break;
    }
    return _out;
}

// ---------------------------------------------------------------------------
// PARAMETERIZED PICKS. A stored pick id is "pk" for plain nodes or "pk@fire"
// for choice nodes (Attunement school picks) - base id before the "@", the
// chosen parameter after. All ownership/reachability compares BASE ids.
// ---------------------------------------------------------------------------
function ability_web_id_base(id) {
    var _p = string_pos("@", id);
    return (_p > 0) ? string_copy(id, 1, _p - 1) : id;
}

function ability_web_id_param(id) {
    var _p = string_pos("@", id);
    return (_p > 0) ? string_copy(id, _p + 1, string_length(id) - _p) : "";
}

function ability_web_node_by_id(ab, id) {
    var _b = ability_web_id_base(id);
    var _n = ability_web_nodes(ab);
    for (var _i = 0; _i < array_length(_n); _i++) if (_n[_i].id == _b) return _n[_i];
    return undefined;
}

function ability_web_owned(name, id) {
    var _b = ability_web_id_base(id);
    var _p = ability_web_picks(name);
    for (var _i = 0; _i < array_length(_p); _i++) if (ability_web_id_base(_p[_i]) == _b) return true;
    return false;
}

// The stored FULL pick id ("tk@fire") for a base id, "" if not picked.
function ability_web_pick_full(name, base_id) {
    var _p = ability_web_picks(name);
    for (var _i = 0; _i < array_length(_p); _i++) if (ability_web_id_base(_p[_i]) == base_id) return _p[_i];
    return "";
}

// Purchase reachability from PERMANENT picks only (run-scoped honing never
// unlocks purchases). Tier 1 is always open; the mid-tier cross-link means
// p2 opens off p1 OR t2 (and t2 off t1 OR p2); keystones need their own
// branch's mid node.
function ability_web_reachable(name, node_id) {
    // (param renamed from `id` - assigning to `id` trips GM1008, it's the
    // readonly built-in instance id)
    var _nid = ability_web_id_base(node_id);
    switch (_nid) {
        case "p1": case "t1": return true;
        case "p2": return ability_web_owned(name, "p1") || ability_web_owned(name, "t2");
        case "t2": return ability_web_owned(name, "t1") || ability_web_owned(name, "p2");
        case "pk": return ability_web_owned(name, "p2");
        case "tk": return ability_web_owned(name, "t2");
    }
    return false;
}

// Spend a pending MP on a node. "" ok / reason (shown as-is in the UI).
function ability_web_buy(name, id) {
    if (ability_web_owned(name, id))          return "Already woven.";
    if (!ability_web_reachable(name, id))     return "A prior node must be woven first.";
    if (array_length(ability_web_picks(name)) >= ability_web_cap()) return "Web cap reached (4 of 6).";
    if (ability_web_mp_pending(name) <= 0)    return "No Talent Point to spend.";
    if (!variable_global_exists("ability_web") || !is_struct(global.ability_web)) global.ability_web = {};
    if (!variable_struct_exists(global.ability_web, name)) variable_struct_set(global.ability_web, name, []);
    array_push(variable_struct_get(global.ability_web, name), id);
    return "";
}

// Apply ONE field-mod id in place to a mutable ability copy. Shared by the
// permanent web picks and the run-scoped Whetstone honing so both use the
// exact same numbers.
function ability_web_apply_mod(_c, mod_id) {
    switch (mod_id) {
        case "dmg":  _c.base_damage     += 3; break;
        case "acc":  _c.base_acc        += 5; break;
        case "crit": _c.base_crit       += 4; break;
        // FRACTION GUARD (M 07-28): some pure-effect abilities store a percent
        // FRACTION in effect_value (a -30% debuff is 0.3). A flat +2 or a ceil()
        // there turned "-30%" into "-230%"/"-100%". Fractions bump by +10
        // percentage points on "val" (legacy saves may hold such picks; the
        // template no longer emits them) and scale WITHOUT ceil, capped at 95%.
        case "val":  _c.effect_value    += (_c.effect_value > 0 && _c.effect_value < 1) ? 0.1 : 2; break;
        case "dur":  _c.effect_duration += 1; break;
        case "dur2": _c.effect_duration += 2; break;
        case "valp": _c.effect_value     = (_c.effect_value > 0 && _c.effect_value < 1)
            ? min(0.95, _c.effect_value * 1.2) : ceil(_c.effect_value * 1.2); break;
        case "valh": _c.effect_value     = (_c.effect_value > 0 && _c.effect_value < 1)
            ? min(0.95, _c.effect_value * 1.5) : ceil(_c.effect_value * 1.5); break;
        case "dmgp": _c.base_damage      = ceil(_c.base_damage * 1.15); break;
        case "apc":  _c.energy_cost      = max(1, _c.energy_cost - 1); break;
        case "secc": _c.secondary_cost   = max(1, _c.secondary_cost - 1); break;   // Thick Blood etc. (floors at 1)
        case "cdm":  _c.cd_mod           = (variable_struct_exists(_c, "cd_mod") ? _c.cd_mod : 0) - 1; break;
    }
}

// Apply one whole NODE (field mods + rider tag + school changes) to a mutable
// copy. `param` is the pick's "@" parameter ("fire" for an Attunement choice).
function ability_web_apply_node(_c, node, param) {
    if (is_undefined(node)) return;
    for (var _i = 0; _i < array_length(node.mods); _i++) ability_web_apply_mod(_c, node.mods[_i]);
    // School conversion: curated (school_to on the node) or the player's
    // Attunement choice (param). School is metadata (SYSTEMS_ELEMENT_SCHOOLS) -
    // +school% gear affixes, log colors and VFX tints all follow the field.
    if (variable_struct_exists(node, "school_to") && node.school_to != "") _c.school = node.school_to;
    if (param != "" && variable_struct_exists(node, "schools")) _c.school = param;
    if (node.rider != "") {
        if (!variable_struct_exists(_c, "web_riders")) _c.web_riders = [];
        array_push(_c.web_riders, node.rider);
    }
}

// ---------------------------------------------------------------------------
// RUN-SCOPED HONING (Whetstone shrine). Since the web rework the shrine
// grants ONE currently-reachable unowned web NODE of choice, run-scoped and
// exempt from the 4-MP spend cap (a taste of the road not taken). Storage:
// global.run_honing { ability_name : node_id }. Null-safe: absent global = no
// honing; a stale pre-web mod id simply matches no node and does nothing.
// Cleared in run_state_reset / new-game / load (scr_save). Applied by
// ability_web_resolve.
// ---------------------------------------------------------------------------
function ability_run_honing(name) {
    if (!variable_global_exists("run_honing") || !is_struct(global.run_honing)) return "";
    return variable_struct_exists(global.run_honing, name) ? variable_struct_get(global.run_honing, name) : "";
}

function ability_run_honing_set(name, node_id) {
    if (!variable_global_exists("run_honing") || !is_struct(global.run_honing)) global.run_honing = {};
    variable_struct_set(global.run_honing, name, node_id);
}

function run_honing_clear() {
    global.run_honing = {};
    global.run_whetstone_used = false;   // reset the once-per-run Whetstone gate at every run teardown
}

// Return the ability itself when untouched, or a field-adjusted shallow COPY
// when web picks OR a run-scoped honing node exist (pools stay pristine;
// dynamic descriptions read the copy). Rider keys land on _c.web_riders for
// the combat controller (see ability_web_copy_has_rider).
function ability_web_resolve(ab) {
    var _picks  = ability_web_picks(ab.name);
    var _honing = ability_run_honing(ab.name);
    if (array_length(_picks) == 0 && _honing == "") return ab;
    var _c = {};
    var _keys = variable_struct_get_names(ab);
    for (var _k = 0; _k < array_length(_keys); _k++) {
        variable_struct_set(_c, _keys[_k], variable_struct_get(ab, _keys[_k]));
    }
    for (var _i = 0; _i < array_length(_picks); _i++) {
        ability_web_apply_node(_c, ability_web_node_by_id(ab, _picks[_i]), ability_web_id_param(_picks[_i]));
    }
    if (_honing != "" && !ability_web_owned(ab.name, _honing)) {
        ability_web_apply_node(_c, ability_web_node_by_id(ab, _honing), ability_web_id_param(_honing));
    }
    return _c;
}

// True when a RESOLVED ability copy carries a web rider. Safe on pristine
// pool structs (no web_riders field = false). Rider keys may carry a numeric
// parameter after a colon ("lifesteal:25") - matching is by key.
function ability_web_copy_has_rider(ab, key) {
    if (!is_struct(ab) || !variable_struct_exists(ab, "web_riders")) return false;
    for (var _i = 0; _i < array_length(ab.web_riders); _i++) {
        var _r = ab.web_riders[_i];
        if (_r == key || string_pos(key + ":", _r) == 1) return true;
    }
    return false;
}

// The numeric parameter of a carried rider ("lifesteal:25" -> 25), or `def`.
function ability_web_rider_value(ab, key, def) {
    if (!is_struct(ab) || !variable_struct_exists(ab, "web_riders")) return def;
    for (var _i = 0; _i < array_length(ab.web_riders); _i++) {
        var _r = ab.web_riders[_i];
        if (string_pos(key + ":", _r) == 1) return real(string_copy(_r, string_length(key) + 2, string_length(_r)));
    }
    return def;
}

// Per-combat first-cast tracking for the Opening Gambit keystone (mirrors the
// Quickcast rune's caster-field pattern; lazily created, reset by each new
// combat's fresh player struct). Marked at cast COMMIT, read by
// ability_effective_cost.
function ability_web_first_cast_used(caster, name) {
    if (is_undefined(caster) || !variable_struct_exists(caster, "web_first_casts")) return false;
    return variable_struct_exists(caster.web_first_casts, name);
}

function ability_web_first_cast_mark(caster, name) {
    if (is_undefined(caster)) return;
    if (!variable_struct_exists(caster, "web_first_casts")) caster.web_first_casts = {};
    variable_struct_set(caster.web_first_casts, name, true);
}

// ---------------------------------------------------------------------------
// WEB-VIEW STAGING (M 07-27): picks are assigned TENTATIVELY in the view and
// only become permanent on SAVE & CLOSE - CLOSE/Esc discards. `staged` is the
// view's working array of node ids (lives on the game controller while the
// view is open; never saved).
// ---------------------------------------------------------------------------
function ability_web_staged_has(staged, id) {
    var _b = ability_web_id_base(id);
    for (var _i = 0; _i < array_length(staged); _i++) if (ability_web_id_base(staged[_i]) == _b) return true;
    return false;
}

// The staged FULL entry ("tk@fire") for a base id, "" if not staged.
function ability_web_staged_full(staged, base_id) {
    for (var _i = 0; _i < array_length(staged); _i++) if (ability_web_id_base(staged[_i]) == base_id) return staged[_i];
    return "";
}

function ability_web_owned_or_staged(name, id, staged) {
    return ability_web_owned(name, id) || ability_web_staged_has(staged, id);
}

// Reachability where staged nodes count as woven (same wishbone rules).
function ability_web_reachable_staged(name, node_id, staged) {
    // (param renamed from `id` - same GM1008 readonly-builtin fix as above)
    var _nid = ability_web_id_base(node_id);
    switch (_nid) {
        case "p1": case "t1": return true;
        case "p2": return ability_web_owned_or_staged(name, "p1", staged) || ability_web_owned_or_staged(name, "t2", staged);
        case "t2": return ability_web_owned_or_staged(name, "t1", staged) || ability_web_owned_or_staged(name, "p2", staged);
        case "pk": return ability_web_owned_or_staged(name, "p2", staged);
        case "tk": return ability_web_owned_or_staged(name, "t2", staged);
    }
    return false;
}

// Toggle a node in the staged set (mutates `staged` in place). CHOICE nodes
// (Attunement) cycle: first select stages school[0], selecting again advances
// to the next school, and past the last removes the stage. Unstaging a support
// node also drops any staged nodes it was holding up (fixed-point sweep).
// Returns "" ok / reason for the notification line.
function ability_web_stage_toggle(name, id, staged) {
    var _base = ability_web_id_base(id);
    if (ability_web_owned(name, _base)) return "Already woven - permanent.";
    var _node   = ability_web_node_by_id(ability_web_pristine(name), _base);
    var _choice = (!is_undefined(_node) && variable_struct_exists(_node, "schools"));
    if (ability_web_staged_has(staged, _base)) {
        var _full = ability_web_staged_full(staged, _base);
        for (var _i = array_length(staged) - 1; _i >= 0; _i--) {
            if (ability_web_id_base(staged[_i]) == _base) array_delete(staged, _i, 1);
        }
        if (_choice) {
            // Advance the school choice; only fall through to unstage past the end.
            var _cur = ability_web_id_param(_full);
            var _idx = -1;
            for (var _s = 0; _s < array_length(_node.schools); _s++) if (_node.schools[_s] == _cur) { _idx = _s; break; }
            if (_idx >= 0 && _idx < array_length(_node.schools) - 1) {
                array_push(staged, _base + "@" + _node.schools[_idx + 1]);
                return "";
            }
        }
        var _dropped = true;
        while (_dropped) {
            _dropped = false;
            for (var _j = array_length(staged) - 1; _j >= 0; _j--) {
                if (!ability_web_reachable_staged(name, staged[_j], staged)) { array_delete(staged, _j, 1); _dropped = true; break; }
            }
        }
        return "";
    }
    if (array_length(ability_web_picks(name)) + array_length(staged) >= ability_web_cap()) return "Web cap reached (" + string(ability_web_cap()) + " of 6).";
    if (ability_web_mp_pending(name) - array_length(staged) <= 0) return "No Talent Point left to assign.";
    if (!ability_web_reachable_staged(name, _base, staged)) return "A prior node must be woven first.";
    array_push(staged, _choice ? (_base + "@" + _node.schools[0]) : _base);
    return "";
}

// Make every staged node permanent, in stage order (staging already validated
// the chain, so ability_web_buy succeeds link by link).
function ability_web_commit_staged(name, staged) {
    for (var _i = 0; _i < array_length(staged); _i++) {
        var _r = ability_web_buy(name, staged[_i]);
        if (_r != "") return _r;
    }
    return "";
}

// ---------------------------------------------------------------------------
// VEX REWEAVE (respec, SYSTEMS_TALENT_WEBS.md - pulled forward from P2).
// Unweaving clears an ability's picks; earned MP derives from lifetime casts,
// so the cleared picks return as pending Talent Points with no bookkeeping.
// ---------------------------------------------------------------------------
// Every ability with at least one woven pick, alphabetical (stable between
// visits). Entries: { name, picks }.
function ability_web_respec_list() {
    var _out = [];
    if (!variable_global_exists("ability_web") || !is_struct(global.ability_web)) return _out;
    var _names = variable_struct_get_names(global.ability_web);
    for (var _i = 0; _i < array_length(_names); _i++) {
        var _p = variable_struct_get(global.ability_web, _names[_i]);
        if (is_array(_p) && array_length(_p) > 0) array_push(_out, { name: _names[_i], picks: array_length(_p) });
    }
    array_sort(_out, function(_a, _b) { return (_a.name < _b.name) ? -1 : ((_a.name > _b.name) ? 1 : 0); });
    return _out;
}

function ability_web_respec(name) {
    if (!variable_global_exists("ability_web") || !is_struct(global.ability_web)) return;
    if (variable_struct_exists(global.ability_web, name)) variable_struct_remove(global.ability_web, name);
}

// The Whetstone's offer: every REACHABLE unowned node (run-scoped, exempt
// from the 4-MP cap). Never empty - the cap leaves at least one reachable
// node unowned in every legal pick state.
function ability_web_whetstone_options(ab) {
    ab = ability_web_pristine(ab);
    var _n = ability_web_nodes(ab);
    var _out = [];
    for (var _i = 0; _i < array_length(_n); _i++) {
        if (!ability_web_owned(ab.name, _n[_i].id) && ability_web_reachable(ab.name, _n[_i].id)) {
            if (variable_struct_exists(_n[_i], "schools")) {
                // Choice node at the shrine: offer ONE deterministic school (the
                // full choice UI is the hub web view's; the stone keeps its list
                // short - max 3 base options fit the overlay).
                var _sc = _n[_i].schools[0];
                array_push(_out, {
                    id: _n[_i].id + "@" + _sc, branch: _n[_i].branch, tier: _n[_i].tier,
                    title: "Attune: " + school_label(_sc),
                    label: "Convert its school to " + school_label(_sc) + " for this run",
                    mods: [], rider: ""
                });
            } else array_push(_out, _n[_i]);
        }
    }
    return _out;
}

// =============================================================================
// BORROWED MEMORIES (expression #6, EXPRESSION_IDEAS.md). Rare event outcomes
// grant a TEMPORARY extra ability for THIS RUN ONLY, drawn from the OTHER two
// classes' pools - "a memory that isn't yours". Run-scoped like boons:
// global.run_borrowed_ability (name) + run_borrowed_class (flavor), cleared in
// end_run and on load. The combat controller appends the resolved ability after
// the normal loadout, so it gets a button/hotkey like any other.
// =============================================================================

// Pick a random borrowable ability from the two classes that are NOT class_id.
// Skips abilities that cost or generate a class secondary resource (Souls /
// Blood / Preparation) - off-class those are dead buttons.
function borrowed_memory_roll(class_id) {
    var _pools = [global.abilities_arcanist, global.abilities_bloodwarden, global.abilities_shadowstrider];
    var _names = ["Arcanist", "Bloodwarden", "Shadowstrider"];
    var _own   = clamp(class_id, 0, 2);
    var _cands = [];
    var _srcs  = [];
    for (var _c = 0; _c < 3; _c++) {
        if (_c == _own) continue;
        var _p = _pools[_c];
        for (var _i = 0; _i < array_length(_p); _i++) {
            var _ab = _p[_i];
            if (_ab.secondary_cost > 0) continue;
            if (_ab.effect_type == "resource") continue;
            // Off-class dead buttons: the SS trap ramp does nothing without traps.
            if (_ab.name == "Compounding Dread") continue;
            array_push(_cands, _ab);
            array_push(_srcs, _names[_c]);
        }
    }
    if (array_length(_cands) == 0) return undefined;
    var _k = irandom(array_length(_cands) - 1);
    return { ability: _cands[_k], from_class: _srcs[_k] };
}

// borrowed_memory_offer(n) - roll n DISTINCT borrowed-memory candidates for the
// pick-1-of-3 draft (07-16 combo batch: the StS lesson - the CHOICE is the fun).
// Returns an array of { name, from_class, hint } (hint = desc_short for the row).
function borrowed_memory_offer(n) {
    var _cid   = variable_global_exists("chosen_class") ? global.chosen_class : 0;
    var _offer = [];
    var _tries = 0;
    while (array_length(_offer) < n && _tries < 30) {
        _tries++;
        var _roll = borrowed_memory_roll(_cid);
        if (_roll == undefined) break;
        var _dup = false;
        for (var _i = 0; _i < array_length(_offer); _i++) {
            if (_offer[_i].name == _roll.ability.name) { _dup = true; break; }
        }
        if (_dup) continue;
        array_push(_offer, {
            name:       _roll.ability.name,
            from_class: _roll.from_class,
            hint:       variable_struct_exists(_roll.ability, "desc_short") ? _roll.ability.desc_short : ""
        });
    }
    return _offer;
}

// Grant a borrowed memory for this run (replaces any previous one). Returns the
// granted ability's name ("" when the roll found nothing).
function borrowed_memory_grant() {
    var _cid  = variable_global_exists("chosen_class") ? global.chosen_class : 0;
    var _roll = borrowed_memory_roll(_cid);
    if (_roll == undefined) return "";
    global.run_borrowed_ability = _roll.ability.name;
    global.run_borrowed_class   = _roll.from_class;
    return _roll.ability.name;
}

// Resolve the granted name back to its ability struct (searched across ALL class
// pools - it is by definition not in the player's own). undefined when none.
function borrowed_memory_resolve() {
    if (!variable_global_exists("run_borrowed_ability") || global.run_borrowed_ability == "") return undefined;
    var _pools = [global.abilities_arcanist, global.abilities_bloodwarden, global.abilities_shadowstrider];
    for (var _c = 0; _c < 3; _c++) {
        for (var _i = 0; _i < array_length(_pools[_c]); _i++) {
            if (_pools[_c][_i].name == global.run_borrowed_ability) return _pools[_c][_i];
        }
    }
    return undefined;
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
    // TEST LEVER (F8, gc Step): everything reads unlocked while the toggle is on.
    if (variable_global_exists("debug_unlock_all") && global.debug_unlock_all) return true;
    if (_t.unlock_type == "default") return true;
    // Duelist Arts (DESIGN_DUELIST_CHALLENGE.md): earned with tokens, never bought.
    if (_t.unlock_type == "duelist") {
        return variable_global_exists("duelist_tokens") && global.duelist_tokens >= _t.unlock_value;
    }
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
        case "Blessed Thirst": case "Salvager": case "Prospector":
            return 1;
        // Tier 3 - powerful / build-defining
        case "Focused Power": case "Chain Caster": case "Plaguebearer":
        case "Arcane Surge": case "Berserker Rage": case "Serrated Strikes":
        case "Relentless":
            return 3;
    }
    return 2;
}

// trait_unlock_cost(name) - { gold, min_rarity, item_label } for a Vex purchase.
// min_rarity: 1 uncommon+, 2 rare+, 4 legendary.
function trait_unlock_cost(trait_name) {
    // Mandate from Heaven (P4): the premium purchase - 2000g + a Legendary.
    if (trait_name == "Mandate from Heaven")
        return { gold:vex_price(cha_price(2000)), min_rarity:4, item_label:"Legendary" };
    // Gold is CHA-discounted + Vex Friend perk (the item requirement is unaffected).
    switch (trait_unlock_tier(trait_name)) {
        case 1: return { gold:vex_price(cha_price(200)), min_rarity:1, item_label:"Uncommon" };
        case 3: return { gold:vex_price(cha_price(500)), min_rarity:4, item_label:"Legendary" };
    }
    return { gold:vex_price(cha_price(350)), min_rarity:2, item_label:"Rare" };
}

// trait_vex_purchasable(class_id) - traits Vex offers for the current class: not a
// default starter, class-appropriate (universal or matching class), not yet owned.
function trait_vex_purchasable(class_id) {
    var _out = [];
    if (!variable_global_exists("traits_all")) return _out;
    for (var _i = 0; _i < array_length(global.traits_all); _i++) {
        var _t = global.traits_all[_i];
        if (_t.unlock_type == "default") continue;
        if (_t.unlock_type == "duelist") continue;   // Duelist Arts: earned, never sold
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
// Scroll offset (index of the first visible row) for the loadout ability list
// and the Vex trainer tabs. Shared by the renderer (Draw_64) and the mouse
// hit-test (Step_0) so the two always agree on which row sits at which y.
// 07-28 (M): now EDGE-RIDING - the selector moves within the visible window
// and the list shifts only when the cursor hits the top/bottom edge. The old
// stateless version pinned the cursor one row from the bottom while the rows
// slid underneath it ("scrolls 1 off the bottom then stays in that region").
// Delegates to the shared persistent ui_list_window; a single key is safe
// because every caller resets its cursor to 0 on open/tab-switch, which snaps
// the stored offset back to the top.
// ---------------------------------------------------------------------------
function loadout_list_scroll(cursor, pool_sz, max_vis) {
    return ui_list_window("loadout_shared", cursor, pool_sz, max_vis);
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
    // POTENCY V2 (SYSTEMS_POTENCY_V2.md, M-approved 07-27): EVERY unlocked trait
    // for this class is upgradable - numeric traits keep %-magnitude ranks,
    // on/off traits gain a bespoke rank knob, rank 5 is a Transcend.
    var _cid = variable_global_exists("chosen_class") ? global.chosen_class : 0;
    var _out = [];
    for (var _i = 0; _i < array_length(global.traits_all); _i++) {
        var _t = global.traits_all[_i];
        if (_t.class_req != -1 && _t.class_req != _cid) continue;
        if (!trait_is_unlocked(_t.name)) continue;
        array_push(_out, { name: _t.name, effect: _t.description });
    }
    return _out;
}

// ---------------------------------------------------------------------------
// trait_potency_info(name) - the V2 per-trait upgrade text: what ranks 1-4 turn
// (knob) and the rank-5 Transcend (tname/teffect). Drives the tab-4 rows and
// the detail popup; the EFFECTS are wired at each trait's mechanic site.
// ---------------------------------------------------------------------------
function trait_potency_info(name) {
    switch (name) {
        case "Sense":            return { knob: "+3% event-check success per rank", tname: "Omniscience",         teffect: "Sense reads the WHOLE floor: hints on every uncleared room, and treasure rooms reveal their gold." };
        case "Scavenger":        return { knob: "+10% gold-find strength per rank", tname: "Weighted Purse",      teffect: "+1% damage per 500 gold held (cap +10%)." };
        case "Thick Skin":       return { knob: "+10% max-HP strength per rank",    tname: "Stone Hide",          teffect: "Above 80% HP you take 15% less damage." };
        case "Quick Recovery":   return { knob: "+10% rest-heal strength per rank", tname: "Second Wind",         teffect: "The first rest each run also grants +5 max HP for the rest of the run." };
        case "Treasure Hunter":  return { knob: "+5% per rank: bonus item rolls a rarity tier higher", tname: "Cartographer's Cut", teffect: "The bonus treasure-room item is a pick-1-of-2." };
        case "Blessed Thirst":   return { knob: "+4% preserve chance per rank (20% to 36%)", tname: "Bottomless", teffect: "The first consumable you use each combat is always preserved." };
        case "Lucky Find":       return { knob: "+10% gold/loot-find strength per rank", tname: "Fortune's Favor", teffect: "Once per run, reroll a loot drop from the loot screen ([R])." };
        case "Battle Hardened":  return { knob: "+3 max-HP cap per rank (15 to 27)", tname: "Unbreakable",        teffect: "The cap is removed entirely." };
        case "Salvager":         return { knob: "Rank 2: keep 3 items on death; rank 4: keep 4", tname: "Nothing Wasted", teffect: "Death also keeps ALL equipped items." };
        case "Iron Will":        return { knob: "Later statuses -10% duration per rank", tname: "Unshakable",     teffect: "The ignored status kind can't be applied to you again that combat." };
        case "Expanded Arsenal": return { knob: "+2% ability damage per rank",       tname: "Deep Reserves",      teffect: "The first cast of every slotted ability each combat costs 1 less AP." };
        case "Prospector":       return { knob: "+5% per rank: the quality bump is two tiers", tname: "Motherlode", teffect: "Combat loot can never roll common." };
        case "Last Stand":       return { knob: "After it triggers: +10% damage per rank for that combat", tname: "Deathless", teffect: "Triggers once per FLOOR instead of once per run." };
        case "Focused Power":    return { knob: "+10% focus-bonus strength per rank", tname: "Annihilating Focus", teffect: "The focused strike also applies Exposed." };
        case "Chain Caster":     return { knob: "+10% splash strength per rank",     tname: "Storm Conductor",    teffect: "Splash hits can critically strike." };
        case "Plaguebearer":     return { knob: "Spread duration +12.5% per rank (full at rank 4)", tname: "Patient Zero", teffect: "When an afflicted enemy dies, its damage-over-time jumps fresh to a random living enemy." };
        case "Soul Siphon":      return { knob: "Ranks 2/4: +1 Soul at combat start", tname: "Harvest",           teffect: "Spell killing blows grant +2 Souls instead of +1." };
        case "Ley Tap":          return { knob: "+3% turn-1 spell damage per rank",  tname: "Ley Torrent",        teffect: "The bonus AP returns every 3rd turn." };
        case "Arcane Surge":     return { knob: "+10% surge strength per rank",      tname: "Overchannel",        teffect: "3-AP casts refund 1 AP when they crit." };
        case "Crimson Reserve":  return { knob: "Ranks 2/4: start with 5 / 6 Blood", tname: "Overflow",           teffect: "Blood cap +4, and up to 4 Blood carries between combats." };
        case "Vampiric Edge":    return { knob: "+10% heal strength per rank",       tname: "Exsanguinating Feast", teffect: "Its healing is doubled while below 40% HP." };
        case "Berserker Rage":   return { knob: "+10% rage strength per rank",       tname: "Blood Frenzy",       teffect: "The threshold rises to below 60% HP." };
        case "Relentless":       return { knob: "Rank 2: 1 unspent AP carries to next turn; rank 4: 2", tname: "Tireless", teffect: "Turn 1 of every combat has 5 AP." };
        case "Phantom Step":     return { knob: "+2% dodge per rank",                tname: "Afterimage",         teffect: "Once per combat, a hit that would land instead misses." };
        case "Shadow Meld":      return { knob: "Meld crits +10% crit damage per rank", tname: "One With the Dark", teffect: "Also triggers when an enemy misses you for ANY reason." };
        case "Serrated Strikes": return { knob: "+10% bleed strength per rank",      tname: "Flaying Edge",       teffect: "Bleeding enemies take +10% damage from you." };
        case "Mandate from Heaven": return { knob: "Ranks 2-4: +4% gold find per rank while a Legendary is equipped", tname: "Divine Right", teffect: "The seal holds for 3 turns instead of 2." };
    }
    return { knob: "+10% strength per rank", tname: "Transcend", teffect: "" };
}

// ---------------------------------------------------------------------------
// trait_potency_rank_cost(next_tier) - the V2 tiered mixed costs (M 07-27).
// next_tier is the rank being bought (current tier + 1, 1..5). Gold parts get
// vex_price + cha_price at the spend site; Vex Companion (affinity 3+) takes
// 1 point off the stat-sacrifice ranks.
// ---------------------------------------------------------------------------
function trait_potency_rank_cost(next_tier) {
    var _comp = affinity_at_least("vex", 3) ? 1 : 0;
    if (next_tier <= 1) return { kind: "gold",  gold: 150, dust: 5 };
    if (next_tier == 2) return { kind: "gold",  gold: 300, dust: 10 };
    if (next_tier == 3) return { kind: "stats", points: 4 - _comp };
    if (next_tier == 4) return { kind: "stats", points: 5 - _comp };
    return { kind: "item", min_rarity: 3 };
}

// Rank-1..4 knob level (0 while the trait isn't equipped - potency amplifies a
// trait, it never fires on its own). Rank 5 is the Transcend, not a 5th knob.
function trait_potency_r14(name) {
    return trait_active(name) ? min(trait_potency_tier(name), 4) : 0;
}

function trait_transcended(name) {
    return trait_active(name) && trait_potency_tier(name) >= 5;
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
    // V2: magnitude ranks are 1-4 only (+40% max); rank 5 is the Transcend.
    return 1 + 0.10 * min(trait_potency_tier(trait_name), 4);
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

// =============================================================================
// CLASS TRUNKS (P2, SYSTEMS_TALENT_WEBS.md §4 - built 08-05).
// Each class passive grows a trunk of 5 this-or-that rows gated by PERMANENT
// level (L2/5/8/11/14). Pairs are PERMANENTLY EXCLUSIVE - picking one locks the
// other; the only out is the Vex trunk respec (500g + 50 dust). There is NO
// trunk currency: reaching the gate level IS the unlock, the exclusivity IS the
// cost. Picks are meta-persistent (plain array-of-arrays, no save-format bump -
// a missing field reads as "nothing picked").
// Three table adaptations vs the §4.3 draft (dead baselines found in code,
// flagged to M 08-05): Arcanist L5a (souls already persist between rooms ->
// cap raise), Bloodwarden L5a (no blood ability costs HP anymore -> Blood cost
// -1), Shadowstrider L2b + L11 (trap_active is vestigial, traps fire on cast ->
// start-Prep / finisher / trap refund).
// =============================================================================

function trunk_gate_levels() { return [2, 5, 8, 11, 14]; }

// One node: { title, label, fx }. fx is the key the combat hooks check via
// trunk_has(fx). label is player-facing - keep it concrete (numbers included).
function trunk_node(title, label, fx) { return { title: title, label: label, fx: fx }; }

// The full trunk for a class: 5 rows, each { lvl, a, b }. Row order = gate order.
function trunk_catalog(class_id) {
    switch (class_id) {
        case 0: return [ // Arcanist - Souls
            { lvl: 2,  a: trunk_node("Soul Harvester",    "+1 extra Soul on your killing blows",                     "soul_kill_bonus"),
                       b: trunk_node("Gravebound Reserve", "Start each combat with at least 2 Souls",                "soul_start") },
            { lvl: 5,  a: trunk_node("Deep Well",         "Soul cap raised to 13",                                   "soul_cap"),
                       b: trunk_node("Soul-Lit Focus",    "+2% spell crit per Soul held",                            "soul_crit") },
            { lvl: 8,  a: trunk_node("Miser of Souls",    "Soul-spending spells cost 1 less Soul (min 1)",           "soul_discount"),
                       b: trunk_node("Overflow",          "Overkill on your kills returns +1 extra Soul",            "soul_overkill") },
            { lvl: 11, a: trunk_node("Rule of Three",     "Every 3rd spell you cast each combat deals +30% damage",  "soul_third_spell"),
                       b: trunk_node("Rending Payment",   "Soul-spending spells lay the target Vulnerable (1 turn)", "soul_vuln") },
            { lvl: 14, a: trunk_node("Inevitable Arcana", "At 5+ Souls your spells cannot miss",                     "soul_sure"),
                       b: trunk_node("Reaper's Dividend", "Spell killing blows refund 1 AP",                         "soul_kill_ap") },
        ];
        case 1: return [ // Bloodwarden - Blood
            { lvl: 2,  a: trunk_node("Cruor Feast",       "Your crits also grant +1 Blood",                          "blood_on_crit"),
                       b: trunk_node("Thickened Vitae",   "Max HP swells +2 for each Blood you hold - and falls again as you spend it", "blood_hp") },
            { lvl: 5,  a: trunk_node("Practiced Phlebotomy", "Blood-spending abilities cost 1 less Blood (min 1)",   "blood_discount"),
                       b: trunk_node("Woken Wounds",      "Start each combat with Blood equal to missing HP / 10",   "blood_start_missing") },
            { lvl: 8,  a: trunk_node("Panic Response",    "Hits that leave you below 30% HP grant +2 Blood",         "blood_low_gain"),
                       b: trunk_node("Red Recycling",     "Heal 1 HP per Blood you spend",                           "blood_spend_heal") },
            { lvl: 11, a: trunk_node("Dread Payment",     "Blood spenders Weaken the target (-20% damage, 1 turn)",  "blood_spend_weaken"),
                       b: trunk_node("Sanguine Might",    "+3% damage per Blood held",                               "blood_dmg") },
            { lvl: 14, a: trunk_node("Refuse the Grave",  "Once per combat: survive a killing blow at 1 HP (costs ALL Blood)", "blood_last_stand"),
                       b: trunk_node("Deep Veins",        "Blood cap raised to 13",                                  "blood_cap") },
        ];
        case 2: return [ // Shadowstrider - Preparation
            { lvl: 2,  a: trunk_node("Punished Whiffs",   "+1 Prep whenever an enemy misses you",                    "prep_on_miss"),
                       b: trunk_node("Always Ready",      "Start each combat with at least 2 Prep",                  "prep_start") },
            { lvl: 5,  a: trunk_node("Loaded Springs",    "Traps deal +2 damage per Prep held",                      "prep_trap_dmg"),
                       b: trunk_node("Patient Opener",    "Your first attack each combat from 2+ Prep auto-crits",   "prep_first_crit") },
            { lvl: 8,  a: trunk_node("Light Kit",         "Evasive tools (Evasive Roll, Smoke Bomb) cost 1 less Prep", "prep_tool_discount"),
                       b: trunk_node("Measured Breathing", "+2 accuracy per Prep held",                              "prep_acc") },
            { lvl: 11, a: trunk_node("Finisher's Doctrine", "Your damaging hits deal +30% to enemies below 25% HP", "prep_finisher"),
                       b: trunk_node("Sprung Steel",      "Casting a trap returns 1 Prep",                           "prep_trap_refund") },
            { lvl: 14, a: trunk_node("Coiled Patience",   "Starting a turn at max Prep grants +1 AP",                "prep_max_ap"),
                       b: trunk_node("Deep Pockets",      "Preparation cap raised to 12",                            "prep_cap") },
        ];
    }
    return [];
}

// Picks store: global.trunk_picks = 3 arrays (per class_id) of 5 ints:
// -1 unpicked / 0 = side a / 1 = side b. Shape-guarded so stale saves heal.
function trunk_picks_init() {
    if (!variable_global_exists("trunk_picks") || !is_array(global.trunk_picks)
        || array_length(global.trunk_picks) != 3) {
        global.trunk_picks = [[-1,-1,-1,-1,-1], [-1,-1,-1,-1,-1], [-1,-1,-1,-1,-1]];
        return;
    }
    for (var _c = 0; _c < 3; _c++) {
        if (!is_array(global.trunk_picks[_c]) || array_length(global.trunk_picks[_c]) != 5) {
            global.trunk_picks[_c] = [-1,-1,-1,-1,-1];
        }
    }
}

function trunk_pick_get(class_id, row) {
    trunk_picks_init();
    if (class_id < 0 || class_id > 2 || row < 0 || row > 4) return -1;
    return global.trunk_picks[class_id][row];
}

function trunk_pick_set(class_id, row, side) {
    trunk_picks_init();
    if (class_id < 0 || class_id > 2 || row < 0 || row > 4) return;
    global.trunk_picks[class_id][row] = side;
}

// A row is unlocked when the character's PERMANENT level has reached its gate.
function trunk_row_unlocked(row) {
    return player_permanent_level() >= trunk_gate_levels()[row];
}

// Unlocked-but-unpicked rows for a class - feeds the pending-pick badges.
function trunk_pending_count(class_id) {
    var _n = 0;
    for (var _r = 0; _r < 5; _r++) {
        if (trunk_row_unlocked(_r) && trunk_pick_get(class_id, _r) == -1) _n++;
    }
    return _n;
}

// True when the CURRENT class has picked a node carrying this fx key. The
// combat hooks additionally gate on player.class_id, so a borrowed-ability
// cross-class edge can never leak another class's trunk.
function trunk_has(fx) {
    var _cls = variable_global_exists("chosen_class") ? global.chosen_class : -1;
    if (_cls < 0 || _cls > 2) return false;
    var _cat = trunk_catalog(_cls);
    for (var _r = 0; _r < array_length(_cat); _r++) {
        var _p = trunk_pick_get(_cls, _r);
        if (_p == -1) continue;
        var _nd = (_p == 0) ? _cat[_r].a : _cat[_r].b;
        if (_nd.fx == fx) return true;
    }
    return false;
}

// Clear every trunk pick for a class (the Vex/Vael trunk respec, 500g + 50
// dust). Returns how many rows were cleared; the gates re-offer one at a time.
function trunk_respec(class_id) {
    trunk_picks_init();
    var _n = 0;
    for (var _r = 0; _r < 5; _r++) {
        if (global.trunk_picks[class_id][_r] != -1) { global.trunk_picks[class_id][_r] = -1; _n++; }
    }
    return _n;
}

// The Vael Reweave list including the CLASS TRUNK row (P2, 08-05): when the
// current class has trunk picks, row 0 offers the trunk respec (500g + 50
// dust - deliberately pricier, exclusive class picks should feel near-
// permanent). Ability rows follow unchanged.
function vael_reweave_rows() {
    var _rows = [];
    var _cls  = variable_global_exists("chosen_class") ? global.chosen_class : 0;
    var _tn   = 0;
    for (var _r = 0; _r < 5; _r++) if (trunk_pick_get(_cls, _r) != -1) _tn++;
    if (_tn > 0) array_push(_rows, { name: "CLASS TRUNK", picks: _tn, is_trunk: true });
    var _w = ability_web_respec_list();
    for (var _i = 0; _i < array_length(_w); _i++) {
        _w[_i].is_trunk = false;
        array_push(_rows, _w[_i]);
    }
    return _rows;
}

// Effective SECONDARY resource cost after trunk discounts. Single source -
// ability_secondary_ok, ability_spend_resources and every cost display must
// route through this so the gate, the spend and the UI can never disagree.
// Arcanist "Miser of Souls" / Bloodwarden "Practiced Phlebotomy": -1, min 1.
// Shadowstrider "Light Kit": -1 on the evasive tools only, floor 0.
function ability_secondary_cost_eff(ability, caster) {
    var _c = ability.secondary_cost;
    if (_c <= 0) return _c;
    var _cls = (caster != undefined && variable_struct_exists(caster, "class_id")) ? caster.class_id : -1;
    if (_cls == 0 && trunk_has("soul_discount"))  _c = max(1, _c - 1);
    if (_cls == 1 && trunk_has("blood_discount")) _c = max(1, _c - 1);
    if (_cls == 2 && trunk_has("prep_tool_discount")
        && (ability.name == "Evasive Roll" || ability.name == "Smoke Bomb")) {
        _c = max(0, _c - 1);
    }
    return _c;
}

// =============================================================================
// DELIVERY MUTATORS (M design-locked 08-11, SYSTEMS_MUTATORS.md). One per cast:
// legendary affix > web node > innate. Spells only (school != "") until the
// bespoke phys carriers (Ricochet Shot etc.) ship with innate tags. Static Arc
// is excluded - its native chain already owns that identity.
// =============================================================================

// Per-school spice on top of the baseline pct (M: "variety and difference
// between schools") - shock bounces harder, fire/poison linger meaner, etc.
function mutator_school_bonus(_kind, _school) {
    switch (_kind) {
        case "bounce": return (_school == "shock") ? 15 : ((_school == "arcane") ? 5 : 0);
        case "split":  return (_school == "arcane") ? 10 : ((_school == "frost") ? 5 : 0);
        case "echo":   return (_school == "void") ? 10 : ((_school == "shock") ? 5 : 0);
        case "linger": return (_school == "fire" || _school == "poison") ? 10 : ((_school == "blood") ? 5 : 0);
    }
    return 0;
}

// The 4 chase legendaries carrying the STRONG versions (worn check).
function mutator_legendary_id(_kind) {
    switch (_kind) {
        case "bounce": return "stormskip_band";
        case "split":  return "twinned_prism";
        case "echo":   return "second_toll";
        case "linger": return "smolderbrand";
    }
    return "";
}

// Innate carriers - abilities that ARE the category (v2 adds Ricochet Shot /
// Bouncing Bomb / Gout of Rot here with their pct).
function ability_innate_mutator(_name) {
    switch (_name) {
        case "Ricochet Shot": return { kind: "bounce", pct: 50 };
        case "Bouncing Bomb": return { kind: "bounce", pct: 40, hops: 2 };
        case "Gout of Rot":   return { kind: "linger", pct: 40 };
    }
    return undefined;
}

// Resolve THE one mutator for this cast, or undefined. Caller guarantees the
// hit dealt damage. Weak node pcts ride in the rider value (mut_bounce:40).
function ability_delivery_mutator(ab) {
    if (!is_struct(ab)) return undefined;
    if (ab.name == "Static Arc") return undefined;   // native chain owns it
    var _school = ability_school(ab);
    var _innate = ability_innate_mutator(ab.name);
    // Spells only, unless the ability is an innate carrier (the phys exceptions).
    if (_school == "" && _innate == undefined) return undefined;

    var _kinds = ["bounce", "split", "echo", "linger"];
    // 1. Legendary (strong) - first worn carrier wins, in the fixed order above.
    for (var _i = 0; _i < 4; _i++) {
        var _k = _kinds[_i];
        if (_school != "" && legendary_worn(mutator_legendary_id(_k))) {
            var _base = (_k == "bounce") ? 60 : ((_k == "split") ? 70 : ((_k == "echo") ? 50 : 45));
            return { kind: _k, pct: _base + mutator_school_bonus(_k, _school) };
        }
    }
    // 2. Web node (weak) - the node's rider value is the baseline pct.
    for (var _i = 0; _i < 4; _i++) {
        var _k = _kinds[_i];
        var _v = ability_web_rider_value(ab, "mut_" + _k, 0);
        if (_v > 0) return { kind: _k, pct: _v + mutator_school_bonus(_k, _school) };
    }
    // 3. Innate (the ability's own identity). hops rides through (Bouncing Bomb).
    if (_innate != undefined) {
        var _mi = { kind: _innate.kind, pct: _innate.pct + mutator_school_bonus(_innate.kind, _school) };
        if (variable_struct_exists(_innate, "hops")) _mi.hops = _innate.hops;
        return _mi;
    }
    return undefined;
}

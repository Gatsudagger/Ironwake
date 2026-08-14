// =============================================================================
// scr_enemies.gml
// Enemy data structures and the Phase 1 Ashen Vault roster for Ironwake.
//
// Usage pattern:
//   1. Call enemy_clone(template) at the start of each encounter - never pass
//      a template directly into combat, or stat mutations will persist.
//   2. Pass the cloned struct as a combatant to combat_init() in scr_combat.
//   3. The combat engine must branch on mechanic_type each turn to trigger
//      special behaviour. See per-mechanic notes below.
//
// mechanic_type reference:
//   "none"         - no special behaviour
//   "double_strike"- enemy attacks twice per action; each hit uses mechanic_value
//                    as the per-hit damage. Combat engine: fire two hit rolls.
//   "phase_shift"  - enemy becomes untargetable for mechanic_value turns every
//                    mechanic_turns turns. Combat engine: set an untargetable flag.
//   "charge"       - pairs with telegraph; enemy winds up and delivers
//                    telegraph_damage on the telegraphed turn. No extra engine
//                    logic needed beyond the telegraph path.
//   "regen"        - enemy recovers mechanic_value HP at the start of its turn
//                    every mechanic_turns turns. Combat engine: call
//                    combat_apply_damage with negative damage (heal).
//   "death_burst"  - on defeat, enemy deals mechanic_value elemental damage to
//                    the player. Combat engine: check after combat_is_defeated().
//   "fortify"      - reduces incoming damage by (1 - mechanic_value) for one turn
//                    every mechanic_turns turns. Combat engine: apply multiplier
//                    before combat_resolve_damage.
//   "retribution"  - gains mechanic_value armor for 2 turns when hit by the same
//                    damage type twice in a row. Combat engine: track last_damage_type
//                    on the enemy struct and compare each hit.
// =============================================================================

// ---------------------------------------------------------------------------
// enemy_define(...)
// Returns a fully populated enemy template struct.
// Always clone with enemy_clone() before placing into combat.
// ---------------------------------------------------------------------------
function enemy_define(
    name,
    HP,
    damage,
    armor,
    el_resist,
    dodge,
    acc,
    xp_value,
    gold_min,
    gold_max,
    telegraph_turn,
    telegraph_damage,
    telegraph_message,
    mechanic_type,
    mechanic_value,
    mechanic_turns,
    abilities = []
) {
    return {
        name:              name,

        // Combat stats
        HP:                HP,
        max_HP:            HP,
        damage:            damage,
        armor:             armor,
        el_resist:         el_resist,
        dodge:             dodge,
        acc:               acc,

        // Rewards
        xp_value:          xp_value,
        gold_min:          gold_min,
        gold_max:          gold_max,

        // Combat system flags - combat_init reads these
        is_player:         false,
        class_id:          -1,
        energy:            3,

        // Telegraph - warns the player one turn before a big attack lands
        telegraph_turn:    telegraph_turn,     // fires every N turns (0 = never)
        telegraph_damage:  telegraph_damage,
        telegraph_message: telegraph_message,

        // Special mechanic - the combat engine checks mechanic_type each turn
        mechanic_type:     mechanic_type,
        mechanic_value:    mechanic_value,
        mechanic_turns:    mechanic_turns,

        // Special abilities (Difficulty Pass) - array of enemy_ability() structs.
        // The combat engine may use one per turn instead of the basic attack.
        abilities:         abilities,
        ability_cd:        [],     // runtime per-ability cooldown counters

        // Runtime state - populated by the combat engine, empty on the template
        status_effects:    [],

        // Defeated flag - set true by the combat engine, never true on a template
        is_defeated:       false,

        // Internal tracking used by retribution mechanic
        last_damage_type:  -1,
    };
}

// ---------------------------------------------------------------------------
// enemy_ability(name, kind, chance, cooldown, value, extra)
// Builds one enemy-ability struct. kind ∈ "spell" (typed damage) / "debuff" /
// "dot" (status on player) / "control" (stun/root/silence) / "heal" (self).
// `extra` (optional struct) may set: dtype (0-3), status_kind, turns, msg,
// reach ("melee"/"ranged" - the DELIVERY of this specific attack; when empty the
// attack inherits the mob's own reach. Lets a melee boss cast a ranged nuke that
// Counterblade correctly ignores, or a caster throw a melee blow it answers).
// ---------------------------------------------------------------------------
function enemy_ability(name, kind, chance, cooldown, value, extra) {
    var _a = { name: name, kind: kind, chance: chance, cooldown: cooldown,
               value: value, dtype: 0, status_kind: "", turns: 1, msg: "", reach: "" };
    if (extra != undefined) {
        if (variable_struct_exists(extra, "dtype"))       _a.dtype = extra.dtype;
        if (variable_struct_exists(extra, "status_kind")) _a.status_kind = extra.status_kind;
        if (variable_struct_exists(extra, "turns"))       _a.turns = extra.turns;
        if (variable_struct_exists(extra, "msg"))         _a.msg = extra.msg;
        if (variable_struct_exists(extra, "reach"))       _a.reach = extra.reach;
    }
    return _a;
}

// ---------------------------------------------------------------------------
// enemy_pick_ability(actor)
// Ticks the actor's per-ability cooldowns, then returns one ready ability that
// procs this turn (random among those that pass their chance roll), or undefined
// to fall through to the basic attack. Lazily initialises ability_cd.
// ---------------------------------------------------------------------------
function enemy_pick_ability(actor, player = undefined) {
    if (!variable_struct_exists(actor, "abilities") || array_length(actor.abilities) == 0) return undefined;
    if (!variable_struct_exists(actor, "ability_cd") || array_length(actor.ability_cd) != array_length(actor.abilities)) {
        actor.ability_cd = array_create(array_length(actor.abilities), 0);
    }
    for (var _i = 0; _i < array_length(actor.ability_cd); _i++) {
        if (actor.ability_cd[_i] > 0) actor.ability_cd[_i]--;
    }
    // Awakening behavior ladder (BALANCE_NOTE C1, M-approved 07-09):
    //   A2+  enemies use their abilities MORE (+15 proc chance) - tiers stop being
    //        pure stat walls (adapted: there was no literal "warm-up round" to cut).
    //   A3+  SMART CONTROL: never waste a control ability on a player already under
    //        that control (stun/root/silence) - they act instead of re-stacking.
    //   A4+  DIVERSIFIED DEBUFFS: skip a debuff/DoT kind the player already carries -
    //        pack members spread afflictions instead of piling one.
    var _asc = variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0;
    // DUELIST T3 (08-13, M-locked): he opens EVERY duel with the Feint - he has
    // known your wrist since the second crossing. Consumed once, then normal play.
    if (variable_struct_exists(actor, "duel_open_feint") && actor.duel_open_feint) {
        actor.duel_open_feint = false;
        for (var _df_i = 0; _df_i < array_length(actor.abilities); _df_i++) {
            if (actor.abilities[_df_i].name == "Disarming Feint") {
                actor.ability_cd[_df_i] = actor.abilities[_df_i].cooldown;
                return actor.abilities[_df_i];
            }
        }
    }
    var _ready = [];
    for (var _i = 0; _i < array_length(actor.abilities); _i++) {
        if (actor.ability_cd[_i] > 0) continue;
        var _ab = actor.abilities[_i];
        // SUMMONS (08-13): never ready a summon onto a full field (4 living foes)
        // - the caller would only turn it into a wasted whiff.
        if (_ab.kind == "summon" && instance_exists(obj_combat_controller)) {
            var _sm_cs = instance_find(obj_combat_controller, 0).combat_state;
            var _sm_n  = 0;
            for (var _sm_i = 0; _sm_i < array_length(_sm_cs.combatants); _sm_i++) {
                var _sm_c = _sm_cs.combatants[_sm_i];
                if (!_sm_c.is_player && !_sm_c.is_defeated) _sm_n++;
            }
            if (_sm_n >= 4) continue;
        }
        if (player != undefined && variable_struct_exists(_ab, "status_kind") && _ab.status_kind != "") {
            var _sk = _ab.status_kind;
            var _is_control = (_sk == "stun" || _sk == "root" || _sk == "silence");
            if (_asc >= 3 && _is_control && combat_has_status(player, _sk)) continue;
            if (_asc >= 4 && !_is_control && combat_has_status(player, _sk)) continue;
            // DUELIST T1+ (08-13): he never wastes the Feint on a wrist he has
            // already turned - the A4 no-restack smarts, at ANY Awakening.
            if (variable_struct_exists(actor, "duel_tier") && actor.duel_tier >= 1
                && !_is_control && combat_has_status(player, _sk)) continue;
        }
        var _ch = variable_struct_exists(_ab, "chance") ? _ab.chance : 100;
        if (_asc >= 2) _ch += 15;
        // DUELIST T2+ (08-13): repetition is punished - if your last two casts
        // were the SAME ability, the Quickstep comes for the pattern (60%).
        if (variable_struct_exists(actor, "duel_tier") && actor.duel_tier >= 2
            && _ab.name == "Quickstep Cut" && player != undefined
            && variable_struct_exists(player, "duel_rep") && player.duel_rep) {
            _ch = max(_ch, 60);
        }
        if (irandom(99) < _ch) array_push(_ready, _i);
    }
    if (array_length(_ready) == 0) return undefined;
    var _pick = _ready[irandom(array_length(_ready) - 1)];
    actor.ability_cd[_pick] = variable_struct_exists(actor.abilities[_pick], "cooldown") ? actor.abilities[_pick].cooldown : 3;
    return actor.abilities[_pick];
}

// ---------------------------------------------------------------------------
// boss_ability_set(floor, dungeon)
// Two scaling abilities every boss gets: a typed nuke + a sparingly-used control
// slam. Floor raises magnitudes. Keeps control rare (low chance, long cooldown).
// ---------------------------------------------------------------------------
function boss_ability_set(floor, dungeon) {
    var _fl = clamp(floor, 1, 3);
    var _nuke_dmg  = [14, 20, 28][_fl - 1];
    var _dtype     = (dungeon == "tundra_tomb") ? 1 : ((dungeon == "scorched_depths") ? 1 : 2); // elemental / drain
    var _nuke_name = (dungeon == "tundra_tomb") ? "Frozen Lance" : ((dungeon == "scorched_depths") ? "Molten Barrage" : "Soul Rend");
    var _set = [
        enemy_ability(_nuke_name, "spell", 45, 2, _nuke_dmg, { dtype: _dtype, msg: "unleashes " + _nuke_name, reach: "ranged" }),
        enemy_ability("Crushing Slam", "control", 30, 4, 0, { status_kind: "stun", turns: 1, msg: "slams the ground - you are stunned" }),
    ];
    // SUMMONS (08-13, M-locked): the Bone Sovereign holds court over everything
    // that has ever died down here - and the court convenes on command.
    if (dungeon == "ashen_vault" && _fl == 2) {
        array_push(_set, enemy_ability("Raise the Court", "summon", 25, 4, 0,
            { msg: "RAISES THE COURT - the dead answer their king" }));
    }
    return _set;
}

// ---------------------------------------------------------------------------
// enemy_is_ranged(name) / enemy_is_spellcaster(name)
// Combat classification (reach + kind) used by control effects: root stops only
// melee enemies, silence stops only spellcasters, stun stops all.
// See SYSTEMS_ATTACK_CLASS.md. Boss aliases aren't listed -> default melee/attack.
// ---------------------------------------------------------------------------
function enemy_is_ranged(name) {
    switch (name) {
        case "Skeleton Archer": case "Lava Spitter": case "Frost Shard": case "Pale Archivist":
            return true;
    }
    // Spellcasters cast from beyond the snare (M 07-28 AI pass): a rooted wraith
    // losing its whole TURN - spells included - read as wrong and made Root a
    // near-universal lock (only 4 of ~25 enemies escaped it). Casters are
    // ranged-reach now: SILENCE is their counter, Root only stops the melee
    // line. The Melee/Ranged intent tag under each HP bar updates itself.
    return enemy_is_spellcaster(name);
}
function enemy_is_spellcaster(name) {
    switch (name) {
        case "Dungeon Wraith": case "Vault Wraith": case "Ash Wraith": case "Snowbound Wraith":
        case "Ice Specter":    case "Pale Archivist": case "Fire Drake":  case "Lava Spitter":
        case "Frost Shard":    case "Cinder Imp":     case "Infernal Revenant":
        case "Smoldering Revenant":
            return true;
    }
    return false;
}

// ---------------------------------------------------------------------------
// INITIATIVE V1 (08-13, M-locked): enemy_speed(name) - the turn-order speed of
// an enemy by family. Player initiative is 10 + DEX/2 (combat_init), so:
//   13  the Duelist - nothing in Ironwake draws faster
//   12  skirmishers (stalkers, crawlers, imps, specters...) - jump a slow player
//    8  the standard line - a DEX-4 player barely outdraws them
//    6  armored heavies - most players act first
//    5  bosses / Wardens - the mountain moves last
//    4  slugs - even the mountain pities them
// ---------------------------------------------------------------------------
function enemy_speed(name) {
    // Bosses + Depth Wardens first (several carry "fast" keywords in their names).
    switch (name) {
        case "Forge Tyrant":      case "Molten Revenant":      case "The Ashen Colossus":
        case "Glacial Warden":    case "Tomb Archon":          case "The Eternal Frost":
        case "Vault Sentinel":    case "Bone Sovereign":       case "Malgrath the Warden":
        case "Bone Colossus":
            return 5;
        case "The Ashen Duelist":
            return 13;
    }
    // Depth Wardens (scr_enemies warden_catalog names).
    var _wc = warden_catalog();
    for (var _wi = 0; _wi < array_length(_wc); _wi++) {
        if (_wc[_wi].name == name) return 5;
    }
    var _n = string_lower(name);
    if (string_pos("slug", _n)) return 4;
    if (string_pos("stalker", _n) || string_pos("crawler", _n) || string_pos("lurker", _n)
        || string_pos("imp", _n) || string_pos("specter", _n) || string_pos("spectre", _n)
        || string_pos("shard", _n) || string_pos("archer", _n)) return 12;
    if (string_pos("golem", _n) || string_pos("colossus", _n) || string_pos("sentinel", _n)
        || string_pos("guardian", _n) || string_pos("thrall", _n) || string_pos("beast", _n)) return 6;
    return 8;
}

// ---------------------------------------------------------------------------
// enemy_attack_school(name) - the element SCHOOL an enemy's attacks read as,
// keyed off its family name (M 08-13: "enemy attacks are the original little
// needle shot for many attacks, when they should be appropriate VFX"). Drives
// the bolt/impact art for basic ranged attacks and dtype-1 elemental casts.
// "" = physical - those KEEP the shipped needle + impact spark on purpose.
// ---------------------------------------------------------------------------
function enemy_attack_school(name) {
    var _n = string_lower(name);
    // Exact fits first, where a keyword would misfile them.
    if (_n == "ash wraith") return "fire";        // a wraith OF ash - reads fire, not ghost
    // fire family (Scorched Depths + its bosses)
    if (string_pos("cinder", _n) || string_pos("magma", _n) || string_pos("fire", _n)
     || string_pos("lava", _n)   || string_pos("smolder", _n) || string_pos("infernal", _n)
     || string_pos("molten", _n) || string_pos("forge", _n)   || string_pos("ember", _n)
     || string_pos("flame", _n)  || string_pos("scorch", _n)) return "fire";
    // frost family (Frozen Tomb + its bosses)
    if (string_pos("frost", _n)  || string_pos("glacial", _n) || string_pos("ice ", _n)
     || string_pos("snow", _n)   || string_pos("frozen", _n)  || string_pos("rime", _n)
     || string_pos("winter", _n) || _n == "ice specter") return "frost";
    // arcane scholars
    if (string_pos("archivist", _n) || string_pos("arcane", _n) || string_pos("rune", _n)) return "arcane";
    // ghosts and shades
    if (string_pos("wraith", _n) || string_pos("specter", _n) || string_pos("spectre", _n)
     || string_pos("shade", _n)  || string_pos("phantom", _n) || string_pos("gloom", _n)) return "shadow";
    // corruption
    if (string_pos("venom", _n) || string_pos("plague", _n) || string_pos("blight", _n)
     || string_pos("toxic", _n) || string_pos("rot", _n)) return "poison";
    // the deep places
    if (string_pos("void", _n) || string_pos("hollow", _n) || string_pos("abyss", _n)) return "void";
    return "";   // skeletons, golems, crawlers - honest physical
}

// Enemy sprites authored facing EAST (away from the player) - the combat draw
// mirrors these so they face the fight (M 08-13: "some enemies are facing
// backwards... like ice specter"). Extend by name as more are spotted.
function enemy_sprite_faces_east(name) {
    switch (name) {
        case "Ice Specter":
        case "Snowbound Wraith":
            return true;
    }
    return false;
}

// enemy_class_tag(c) - short "Melee/Phys" style label for an enemy's attack class
// (reach x kind), drawn under its HP bar so the player can see which control
// effects apply: ROOT blocks Melee, SILENCE blocks Spell, STUN blocks all.
// Mirrors ability_attack_class_tag's vocabulary. See SYSTEMS_ATTACK_CLASS.md.
function enemy_class_tag(c) {
    var _reach = variable_struct_exists(c, "reach") ? c.reach : "melee";
    var _kind  = variable_struct_exists(c, "kind")  ? c.kind  : "attack";
    var _rw = (_reach == "ranged") ? "Ranged" : "Melee";
    var _kw = (_kind  == "spell")  ? "Spell"  : "Phys";
    return _rw + "/" + _kw;
}

// ---------------------------------------------------------------------------
// enemy_clone(enemy_template)
// Returns a shallow copy of the template with a fresh status_effects array
// and all runtime state reset to defaults.
// Always call this before passing an enemy into combat.
// ---------------------------------------------------------------------------
function enemy_clone(enemy_template) {
    var c = {};

    // Copy every field from the template
    var keys = variable_struct_get_names(enemy_template);
    for (var i = 0; i < array_length(keys); i++) {
        var k = keys[i];
        variable_struct_set(c, k, variable_struct_get(enemy_template, k));
    }

    // Reset runtime-only fields so template state never leaks into combat
    c.HP             = enemy_template.max_HP;
    c.energy         = 3;
    c.status_effects = [];    // fresh array - never share with the template
    c.is_defeated    = false;
    c.last_damage_type = -1;
    c.ability_cd     = [];    // fresh per-combat cooldown counters

    return c;
}

// ---------------------------------------------------------------------------
// enemy_get_attack_damage(enemy, turn_number)
// Returns the damage this enemy deals on the given turn.
//
// If turn_number is a non-zero multiple of telegraph_turn, the telegraphed
// (big) attack fires and returns telegraph_damage instead of base damage.
// Returns 0 if the enemy is already defeated.
//
// Note: double_strike enemies deal mechanic_value per hit x 2 - the combat
// engine handles the two separate hit rolls; this function returns the
// per-hit value via enemy.mechanic_value for that mechanic type.
// ---------------------------------------------------------------------------
function enemy_get_attack_damage(enemy, turn_number) {
    if (enemy.is_defeated) return 0;

    // Telegraphed attack fires on its scheduled turn
    if (enemy.telegraph_turn > 0 && (turn_number mod enemy.telegraph_turn) == 0) {
        return max(1, enemy.telegraph_damage + irandom(4) - 2);
    }

    return max(1, enemy.damage + irandom(4) - 2);
}

// ---------------------------------------------------------------------------
// enemy_should_telegraph(enemy, turn_number)
// Returns true when the CURRENT turn is the turn immediately BEFORE the
// telegraphed attack, so the UI can display telegraph_message as a warning.
// Returns false if the enemy never telegraphs or is defeated.
// ---------------------------------------------------------------------------
function enemy_should_telegraph(enemy, turn_number) {
    if (enemy.is_defeated)       return false;
    if (enemy.telegraph_turn <= 0) return false;

    // The big attack fires on multiples of telegraph_turn.
    // The warning fires on the turn before: (next_telegraph - 1).
    var next_telegraph = (floor(turn_number / enemy.telegraph_turn) + 1) * enemy.telegraph_turn;
    return (turn_number == next_telegraph - 1);
}

// =============================================================================
// ENEMY INTENT (INTENT_SPEC.md). Every enemy decides its NEXT action one turn
// early - at combat start and again at the end of each of its turns - and
// stores it on `actor.intent`. The telegraph is BINDING: the combat engine
// executes the stored plan instead of re-rolling at execution time, so the
// chip the player read during their turn is always honest.
//
// intent = {
//   kind   "attack" / "spell" / "heal" / "control"   (chip icon + tint)
//   eab    the committed enemy_ability struct, or undefined = basic attack
//   label  effect word for non-damage intents ("Stun", "Mend", "Wound"...)
//   lo/hi  approximate post-mitigation damage band (equal for fixed spells)
//   x2     true when a double_strike second hit rides along
//   pulse  frames left of the "intent changed" flash (set on re-rolls)
//   heavy  true = a charged/telegraphed attack (spike swing or spell nuke); a
//          player STUN/ROOT that lands on it triggers INTERRUPT (+1 AP)
// }
// =============================================================================

// Deterministic estimate of what one enemy swing/cast would deal to the player
// AFTER the standard mitigation chain (mirrors the engine's damage path minus
// Soul Shield / Blink / Evasive Roll, which are reactive and roll-dependent).
function enemy_intent_estimate(actor, raw, dtype, player) {
    // Weaken on the enemy reduces its outgoing damage (max of stacks).
    var _wk = combat_status_max(actor, "weaken");
    if (_wk > 0) raw = max(1, round(raw * (1 - _wk)));
    var _d = combat_resolve_damage(raw, dtype, player.armor, player.el_resist);
    _d += combat_status_total(player, "vulnerable");
    _d = max(0, _d - player.damage_reduction);
    _d = max(1, _d - player.equip_armor);
    if (dtype == 0 && variable_struct_exists(player, "derived") && player.derived.phys_dmg_reduction > 0) {
        _d = max(1, ceil(_d * (1.0 - (player.derived.phys_dmg_reduction / 100.0))));
    }
    if (boon_active("warding"))         _d = max(1, round(_d * boon_incoming_mult()));
    if (pet_egg_ward_mult() != 1.0)     _d = max(1, round(_d * pet_egg_ward_mult()));
    if (curse_incoming_mult() != 1.0)   _d = max(1, round(_d * curse_incoming_mult()));
    return _d;
}

// Effect word shown on non-damage intent chips.
function enemy_intent_status_word(eab) {
    switch (eab.status_kind) {
        case "stun":       return "Stun";
        case "root":       return "Root";
        case "silence":    return "Silence";
        case "blind":      return "Blind";
        case "weaken":     return "Weaken";
        case "vulnerable": return "Expose";
        case "mortality":  return "Wither";
    }
    return (eab.kind == "dot") ? "Wound" : "Afflict";
}

// Roll and store the enemy's next action. next_round = the round the action
// will happen in (drives the telegraph-spike check for basic attacks).
// is_reroll pulses the chip so a mid-combat change is visible.
function enemy_roll_intent(actor, player, next_round, is_reroll) {
    if (actor.is_defeated) { actor.intent = undefined; return; }
    var _eab = enemy_pick_ability(actor, player);   // player passed for the C1 smart-targeting gates
    var _it  = { kind: "attack", eab: _eab, label: "", lo: 0, hi: 0,
                 x2: false, pulse: (is_reroll ? 30 : 0), heavy: false };
    if (_eab == undefined) {
        // Basic attack: damage +/- 2 swing variance; telegraph-spike aware.
        var _spike = (actor.telegraph_turn > 0 && (next_round mod actor.telegraph_turn) == 0);
        var _raw   = _spike ? actor.telegraph_damage : actor.damage;
        _it.lo = enemy_intent_estimate(actor, max(1, _raw - 2), 0, player);
        _it.hi = enemy_intent_estimate(actor, _raw + 2, 0, player);
        _it.x2 = (actor.mechanic_type == "double_strike");
        // A telegraphed spike swing is the "charged/heavy attack" Interrupt punishes.
        _it.heavy = _spike;
    } else if (_eab.kind == "spell") {
        _it.kind = "spell";
        var _est = enemy_intent_estimate(actor, _eab.value, _eab.dtype, player);
        _it.lo = _est; _it.hi = _est;
        _it.heavy = true;   // a committed enemy spell nuke is a charged action
    } else if (_eab.kind == "heal") {
        _it.kind = "heal";  _it.label = "Mend";
    } else if (_eab.kind == "summon") {
        // SUMMONS (08-13): rides the amber control chip with its own word.
        _it.kind = "control";  _it.label = "Summon";
    } else if (_eab.kind == "stance") {
        // DUELIST T2 (08-13): the Perfect Parry telegraphs as a stance chip.
        _it.kind = "control";  _it.label = "Stance";
    } else {
        // control / debuff / dot -> the chains chip (amber) with an effect word.
        _it.kind = "control";  _it.label = enemy_intent_status_word(_eab);
    }
    actor.intent = _it;
}

// Live check: would the enemy's telegraphed action be cancelled by a control
// status RIGHT NOW? Mirrors the engine's control gate exactly (stun = anything,
// root = melee foes, silence = spellcaster foes). "" = free to act.
function enemy_intent_blocked(c) {
    var _reach = variable_struct_exists(c, "reach") ? c.reach : "melee";
    var _kind  = variable_struct_exists(c, "kind")  ? c.kind  : "attack";
    if (combat_has_status(c, "stun"))                       return "stunned";
    if (combat_has_status(c, "root")    && _reach == "melee") return "rooted";
    if (combat_has_status(c, "silence") && _kind  == "spell") return "silenced";
    return "";
}

// =============================================================================
// SCHOOL WEAKNESSES (COMBAT_DEEPENING_PROPOSAL.md P2, M-approved 08-01)
// Archetype axis: undead->fire, construct/sentinel->shock, wraith/spirit->
// arcane, beast->frost - EXCEPT fire-born->frost (quench) and ice-born->fire
// (thaw), so nothing is weak to its own element. Name-keyed so enemy_clone
// copies need no new field and every pool (incl. bosses) is covered. The
// Ashen Duelist has NO weakness (pure duel) - absent = "".
// Hitting a weakness: +30% damage + 1 AP refund ONCE PER ENEMY PER COMBAT
// (hook in obj_combat_controller Step_0; glyph beside the intent-row tag).
// =============================================================================
function enemy_weak_school(name) {
    switch (name) {
        // Ashen Vault
        case "Ashen Skeleton":      return "fire";
        case "Skeleton Archer":     return "fire";
        case "Vault Crawler":       return "frost";
        case "Dungeon Wraith":      return "arcane";
        case "Bone Colossus":       return "fire";    // standard AND boss frame
        case "Stone Golem":         return "shock";
        case "Vault Guardian":      return "fire";
        case "Vault Wraith":        return "arcane";
        case "Vault Sentinel":      return "shock";
        case "Grave Stalker":       return "frost";
        case "Bone Sovereign":      return "fire";
        case "Malgrath the Warden": return "arcane";
        // Scorched Depths (fire-born -> frost)
        case "Cinder Imp":          return "frost";
        case "Magma Slug":          return "frost";
        case "Ash Wraith":          return "arcane";
        case "Lava Spitter":        return "frost";
        case "Fire Drake":          return "frost";
        case "Smoldering Revenant": return "arcane";
        case "Cinder Golem":        return "shock";
        case "Infernal Revenant":   return "arcane";
        case "Forge Tyrant":        return "shock";
        case "Molten Revenant":     return "arcane";
        case "The Ashen Colossus":  return "shock";
        // Tundra Tomb (ice-born -> fire)
        case "Ice Specter":         return "fire";
        case "Frost Shard":         return "fire";
        case "Frozen Thrall":       return "fire";
        case "Snowbound Wraith":    return "arcane";
        case "Glacial Lurker":      return "shock";
        case "Pale Archivist":      return "arcane";
        case "Glacial Beast":       return "shock";
        case "Frozen Sentinel":     return "shock";
        case "Glacial Warden":      return "fire";
        case "Tomb Archon":         return "arcane";
        case "The Eternal Frost":   return "fire";
    }
    return "";
}

// =============================================================================
// PHASE 1: ASHEN VAULT ROSTER
// Templates - always pass through enemy_clone() before combat use.
// =============================================================================

// -----------------------------------------------------------------------------
// STANDARD MOBS
// Low HP, low rewards, appear in normal encounter rooms.
// -----------------------------------------------------------------------------
global.enemies_ashen_vault_standard = [

    // 0: Ashen Skeleton
    // Straightforward melee attacker. No mechanics - good for teaching
    // the core hit/damage loop to the player.
    enemy_define(
        "Ashen Skeleton",
        /*HP*/28, /*damage*/6,
        /*armor*/2, /*el_resist*/0, /*dodge*/4, /*acc*/75,
        /*xp*/10, /*gold_min*/5, /*gold_max*/10,
        /*telegraph_turn*/0, /*telegraph_damage*/0, /*message*/"",
        /*mechanic*/"none", /*value*/0, /*turns*/0
    ),

    // 1: Vault Crawler
    // Always attacks twice. Each hit uses mechanic_value (5) as damage,
    // so total output is up to 10 per turn if both land.
    // COMBAT ENGINE: when mechanic_type == "double_strike", fire two separate
    // combat_roll_hit() calls using mechanic_value as the per-hit base damage.
    enemy_define(
        "Vault Crawler",
        /*HP*/22, /*damage*/5,
        /*armor*/0, /*el_resist*/0, /*dodge*/6, /*acc*/75,
        /*xp*/10, /*gold_min*/5, /*gold_max*/10,
        /*telegraph_turn*/0, /*telegraph_damage*/0, /*message*/"",
        /*mechanic*/"double_strike", /*value*/5, /*turns*/0
    ),

    // 2: Dungeon Wraith
    // Phases out every 3 turns (untargetable for 1 turn).
    // High dodge makes it slippery even when targetable.
    // COMBAT ENGINE: track a phase_timer on the clone; when
    // (turn_number mod mechanic_turns) == 0 set untargetable for mechanic_value turns.
    enemy_define(
        "Dungeon Wraith",
        /*HP*/20, /*damage*/8,
        /*armor*/0, /*el_resist*/4, /*dodge*/8, /*acc*/75,
        /*xp*/10, /*gold_min*/5, /*gold_max*/10,
        /*telegraph_turn*/0, /*telegraph_damage*/0, /*message*/"",
        /*mechanic*/"phase_shift", /*value*/1, /*turns*/3,
        /*abilities*/[
            enemy_ability("Soul Drain", "spell", 35, 2, 9, { dtype: 2, msg: "drains your essence" }),
            enemy_ability("Haunting Gaze", "debuff", 30, 3, 0.20, { status_kind: "blind", turns: 2, msg: "clouds your sight" }),
            enemy_ability("Spectral Mend", "heal", 30, 3, 12, { msg: "knits its tattered form back together" }),
        ]
    ),

    // 3: Skeleton Archer
    // Announces a 18-damage charged shot the turn before it fires.
    enemy_define(
        "Skeleton Archer",
        /*HP*/24, /*damage*/6,
        /*armor*/0, /*el_resist*/0, /*dodge*/4, /*acc*/75,
        /*xp*/10, /*gold_min*/5, /*gold_max*/10,
        /*telegraph_turn*/3, /*telegraph_damage*/18,
        /*message*/"is preparing a mighty blow!",
        /*mechanic*/"charge", /*value*/0, /*turns*/0
    ),

    // 4: Grave Stalker
    // High dodge skirmisher - punishes players who repeat the same damage type.
    // Forces constant ability rotation to avoid giving it armor stacks.
    enemy_define(
        "Grave Stalker",
        /*HP*/20, /*damage*/7,
        /*armor*/0, /*el_resist*/2, /*dodge*/14, /*acc*/78,
        /*xp*/10, /*gold_min*/5, /*gold_max*/10,
        /*telegraph_turn*/0, /*telegraph_damage*/0, /*message*/"",
        /*mechanic*/"retribution", /*value*/5, /*turns*/0,
        /*abilities*/[
            enemy_ability("Rending Slash", "dot", 35, 3, 4, { turns: 3, msg: "opens a deep bleeding wound" }),
        ]
    ),

    // 5: Bone Colossus
    // Slow, armored bruiser. Fortifies every 3 turns, making it briefly
    // nearly immune. Hit hard in the window between fortify cycles.
    enemy_define(
        "Bone Colossus",
        /*HP*/38, /*damage*/9,
        /*armor*/7, /*el_resist*/0, /*dodge*/0, /*acc*/68,
        /*xp*/10, /*gold_min*/5, /*gold_max*/10,
        /*telegraph_turn*/0, /*telegraph_damage*/0, /*message*/"",
        /*mechanic*/"fortify", /*value*/0.4, /*turns*/3,
        /*abilities*/[
            enemy_ability("Bone Crush", "control", 22, 4, 0, { status_kind: "stun", turns: 1, msg: "smashes you to the ground - stunned" }),
            enemy_ability("Knit Bone", "heal", 28, 4, 10, { msg: "knits its shattered bones" }),
        ]
    ),

];

// -----------------------------------------------------------------------------
// ELITE ENEMIES
// Higher HP, higher rewards, appear in elite encounter rooms.
// Each has a meaningful mechanic that forces the player to adapt strategy.
// -----------------------------------------------------------------------------
global.enemies_ashen_vault_elite = [

    // 0: Stone Golem
    // Massive armor makes physical damage mostly useless; elemental is preferred.
    // Fortifies every 4 turns (50% damage reduction for that turn), on the same
    // cycle as its telegraph attack - the player must choose to attack through
    // the fortify or hold back.
    // COMBAT ENGINE: on turns where (turn_number mod mechanic_turns) == 0, apply
    // a 0.5x multiplier to all incoming damage before combat_resolve_damage().
    enemy_define(
        "Stone Golem",
        /*HP*/80, /*damage*/14,
        /*armor*/10, /*el_resist*/2, /*dodge*/2, /*acc*/70,
        /*xp*/35, /*gold_min*/25, /*gold_max*/40,
        /*telegraph_turn*/4, /*telegraph_damage*/22,
        /*message*/"is preparing a mighty blow!",
        /*mechanic*/"fortify", /*value*/0.5, /*turns*/4
    ),

    // 1: Vault Guardian
    // Punishes players who repeat the same damage type - after two consecutive
    // hits of the same type it gains 4 armor for 2 turns (retribution).
    // Forces the player to alternate damage types or switch to drain.
    // COMBAT ENGINE: after each hit, compare the incoming damage_type to
    // enemy.last_damage_type. If equal, add mechanic_value to armor for 2 turns
    // and reset last_damage_type. Always update last_damage_type after a hit.
    enemy_define(
        "Vault Guardian",
        /*HP*/70, /*damage*/16,
        /*armor*/6, /*el_resist*/6, /*dodge*/4, /*acc*/72,
        /*xp*/35, /*gold_min*/30, /*gold_max*/45,
        /*telegraph_turn*/4, /*telegraph_damage*/24,
        /*message*/"is preparing a mighty blow!",
        /*mechanic*/"retribution", /*value*/4, /*turns*/0
    ),

];

// =============================================================================
// SCORCHED DEPTHS - fire-themed dungeon, floors 1-3
// =============================================================================
global.enemies_scorched_depths_standard = [
    enemy_define(
        /*name*/"Cinder Imp",
        /*HP*/38, /*damage*/4, /*armor*/1, /*el_resist*/3, /*dodge*/5, /*acc*/72,
        /*xp*/12, /*gold_min*/3, /*gold_max*/8,
        /*telegraph_turn*/0, /*telegraph_damage*/0,
        /*message*/"",
        /*mechanic*/"double_strike", /*value*/4, /*turns*/0
    ),
    enemy_define(
        /*name*/"Magma Slug",
        /*HP*/55, /*damage*/6, /*armor*/4, /*el_resist*/5, /*dodge*/0, /*acc*/68,
        /*xp*/15, /*gold_min*/4, /*gold_max*/9,
        /*telegraph_turn*/0, /*telegraph_damage*/0,
        /*message*/"",
        /*mechanic*/"regen", /*value*/4, /*turns*/2
    ),
    enemy_define(
        /*name*/"Ash Wraith",
        /*HP*/42, /*damage*/8, /*armor*/0, /*el_resist*/8, /*dodge*/10, /*acc*/70,
        /*xp*/14, /*gold_min*/3, /*gold_max*/8,
        /*telegraph_turn*/0, /*telegraph_damage*/0,
        /*message*/"",
        /*mechanic*/"phase_shift", /*value*/1, /*turns*/3
    ),
    enemy_define(
        /*name*/"Fire Drake",
        /*HP*/50, /*damage*/7, /*armor*/3, /*el_resist*/4, /*dodge*/3, /*acc*/74,
        /*xp*/16, /*gold_min*/5, /*gold_max*/10,
        /*telegraph_turn*/3, /*telegraph_damage*/18,
        /*message*/"is drawing in a deep breath!",
        /*mechanic*/"charge", /*value*/0, /*turns*/0,
        /*abilities*/[
            enemy_ability("Cinder Breath", "spell", 35, 2, 12, { dtype: 1, msg: "breathes a gout of flame" }),
            enemy_ability("Searing Brand", "dot", 30, 3, 5, { turns: 3, msg: "sears you with lingering fire" }),
        ]
    ),

    // Lava Spitter - high acc ranged attacker, retribution punishes repeated elements
    enemy_define(
        /*name*/"Lava Spitter",
        /*HP*/30, /*damage*/8, /*armor*/0, /*el_resist*/6, /*dodge*/2, /*acc*/84,
        /*xp*/12, /*gold_min*/4, /*gold_max*/9,
        /*telegraph_turn*/0, /*telegraph_damage*/0, /*message*/"",
        /*mechanic*/"retribution", /*value*/4, /*turns*/0
    ),

    // Smoldering Revenant - regenerates and explodes on death; punishes slow kills
    enemy_define(
        /*name*/"Smoldering Revenant",
        /*HP*/36, /*damage*/6, /*armor*/1, /*el_resist*/5, /*dodge*/4, /*acc*/72,
        /*xp*/14, /*gold_min*/5, /*gold_max*/10,
        /*telegraph_turn*/0, /*telegraph_damage*/0, /*message*/"",
        /*mechanic*/"death_burst", /*value*/10, /*turns*/0,
        /*abilities*/[
            enemy_ability("Ember Mending", "heal", 30, 3, 10, { msg: "draws on the embers and mends" }),
        ]
    ),
];

global.enemies_scorched_depths_elite = [
    enemy_define(
        /*name*/"Cinder Golem",
        /*HP*/90, /*damage*/10, /*armor*/6, /*el_resist*/5, /*dodge*/0, /*acc*/72,
        /*xp*/30, /*gold_min*/15, /*gold_max*/25,
        /*telegraph_turn*/0, /*telegraph_damage*/0,
        /*message*/"",
        /*mechanic*/"fortify", /*value*/0.5, /*turns*/4
    ),
    enemy_define(
        /*name*/"Infernal Revenant",
        /*HP*/75, /*damage*/12, /*armor*/3, /*el_resist*/8, /*dodge*/5, /*acc*/74,
        /*xp*/28, /*gold_min*/14, /*gold_max*/22,
        /*telegraph_turn*/4, /*telegraph_damage*/20,
        /*message*/"is channeling hellfire!",
        /*mechanic*/"death_burst", /*value*/12, /*turns*/0
    ),
];

// =============================================================================
// TUNDRA TOMB - ice/undead dungeon, floors 1-3
// =============================================================================
global.enemies_tundra_tomb_standard = [
    enemy_define(
        /*name*/"Frost Shard",
        /*HP*/35, /*damage*/7, /*armor*/1, /*el_resist*/6, /*dodge*/8, /*acc*/72,
        /*xp*/13, /*gold_min*/3, /*gold_max*/8,
        /*telegraph_turn*/0, /*telegraph_damage*/0,
        /*message*/"",
        /*mechanic*/"phase_shift", /*value*/1, /*turns*/3
    ),
    enemy_define(
        /*name*/"Glacial Lurker",
        /*HP*/44, /*damage*/5, /*armor*/2, /*el_resist*/4, /*dodge*/4, /*acc*/74,
        /*xp*/14, /*gold_min*/4, /*gold_max*/9,
        /*telegraph_turn*/0, /*telegraph_damage*/0,
        /*message*/"",
        /*mechanic*/"double_strike", /*value*/5, /*turns*/0
    ),
    // (Pale Archivist PROMOTED to the elite pool 08-13 - M: "isnt pale
    // archivist a boss? why is he showing up in random battles". His kit -
    // silence, heal, a SUMMON - was mini-boss weight in a standard room.)
    enemy_define(
        /*name*/"Snowbound Wraith",
        /*HP*/48, /*damage*/7, /*armor*/0, /*el_resist*/9, /*dodge*/6, /*acc*/73,
        /*xp*/15, /*gold_min*/4, /*gold_max*/9,
        /*telegraph_turn*/0, /*telegraph_damage*/0,
        /*message*/"",
        /*mechanic*/"regen", /*value*/3, /*turns*/2
    ),

    // Ice Specter - phases out AND punishes repeated damage types; very slippery
    enemy_define(
        /*name*/"Ice Specter",
        /*HP*/28, /*damage*/8, /*armor*/0, /*el_resist*/10, /*dodge*/10, /*acc*/65,
        /*xp*/14, /*gold_min*/4, /*gold_max*/9,
        /*telegraph_turn*/0, /*telegraph_damage*/0, /*message*/"",
        /*mechanic*/"phase_shift", /*value*/1, /*turns*/2,
        /*abilities*/[
            enemy_ability("Numbing Chill", "debuff", 35, 3, 0.20, { status_kind: "weaken", turns: 2, msg: "chills you to the bone - weakened" }),
        ]
    ),

    // Frozen Thrall - fortifies behind an icy shell, then telegraphs a crushing blow
    enemy_define(
        /*name*/"Frozen Thrall",
        /*HP*/40, /*damage*/7, /*armor*/5, /*el_resist*/4, /*dodge*/0, /*acc*/70,
        /*xp*/14, /*gold_min*/4, /*gold_max*/9,
        /*telegraph_turn*/4, /*telegraph_damage*/19,
        /*message*/"is rearing back for a frozen slam!",
        /*mechanic*/"fortify", /*value*/0.45, /*turns*/4
    ),
];

global.enemies_tundra_tomb_elite = [
    enemy_define(
        /*name*/"Glacial Beast",
        /*HP*/85, /*damage*/11, /*armor*/5, /*el_resist*/6, /*dodge*/2, /*acc*/76,
        /*xp*/29, /*gold_min*/15, /*gold_max*/24,
        /*telegraph_turn*/0, /*telegraph_damage*/0,
        /*message*/"",
        /*mechanic*/"fortify", /*value*/0.5, /*turns*/4
    ),
    enemy_define(
        /*name*/"Frozen Sentinel",
        /*HP*/72, /*damage*/10, /*armor*/4, /*el_resist*/7, /*dodge*/3, /*acc*/74,
        /*xp*/27, /*gold_min*/14, /*gold_max*/22,
        /*telegraph_turn*/4, /*telegraph_damage*/18,
        /*message*/"is preparing a devastating strike!",
        /*mechanic*/"retribution", /*value*/4, /*turns*/0
    ),
    // Promoted from the standard pool 08-13 (M): the librarian's kit (silence
    // + heal + Requisition summon) is mini-boss weight - he holds ELITE rooms
    // now, at elite-grade stats, and never wanders into random encounters.
    enemy_define(
        /*name*/"Pale Archivist",
        /*HP*/68, /*damage*/8, /*armor*/2, /*el_resist*/7, /*dodge*/3, /*acc*/74,
        /*xp*/28, /*gold_min*/14, /*gold_max*/23,
        /*telegraph_turn*/3, /*telegraph_damage*/18,
        /*message*/"is inscribing a death rune!",
        /*mechanic*/"charge", /*value*/0, /*turns*/0,
        /*abilities*/[
            enemy_ability("Death Rune", "control", 25, 4, 0, { status_kind: "silence", turns: 2, msg: "binds your tongue - silenced" }),
            enemy_ability("Frost Bolt", "spell", 35, 2, 12, { dtype: 1, msg: "hurls a shard of ice" }),
            enemy_ability("Restorative Glyph", "heal", 35, 3, 18, { msg: "traces a restorative glyph and mends" }),
            // SUMMONS (08-13, M-locked): the librarian requisitions a fresh entry.
            enemy_ability("Requisition", "summon", 20, 5, 0, { msg: "files a REQUISITION - the Tomb sends another" }),
        ]
    ),
];

// =============================================================================
// PER-MOB-TYPE SIZE MULTIPLIER (round 13b queue, M: "small-by-design species
// must STAY small... tweak by tweak issue for some"). Applied on top of the
// 2.5D station scale AFTER true-bounds normalization and BEFORE the 185px hard
// ceiling, so a 0.75 here really reads 25% smaller on stage. 1.0 = default.
// TUNE FREELY per M's eye - add a case per species that reads wrong in-game.
// =============================================================================
function enemy_size_mult(name) {
    switch (name) {
        // Vermin / small-by-design - the fiction says small, keep them small.
        case "Vault Crawler":  return 0.80;
        case "Cinder Imp":     return 0.72;
        case "Magma Slug":     return 0.78;
        case "Frost Shard":    return 0.68;
        case "Lava Spitter":   return 0.85;
        // Hulks lean on the station scale + 185px ceiling; no boost needed.
    }
    return 1.0;
}

// =============================================================================
// ENEMY SPRITE MAP - the single name->sprite truth, shared by the combat draw
// (west-facing frame 3) and the journal bestiary (south-facing frame 0, #8).
// Moved here from obj_combat_controller Draw_64 (2026-07-09).
// =============================================================================
function enemy_sprite_map() {
    return {
        "Ashen Skeleton":      spr_skeleton_soldier,
        "Skeleton Archer":     spr_skeleton_archer,
        "Vault Crawler":       spr_vault_crawler,
        "Dungeon Wraith":      spr_dungeon_wraith,
        "Stone Golem":         spr_stone_golem,
        "Vault Guardian":      spr_vault_guardian,
        "Vault Wraith":        spr_vault_wraith,
        "Vault Sentinel":      spr_vault_sentinel,
        "Bone Sovereign":      spr_bone_sovereign_hd,   // 08-13 M-approved HD (spectral tail); original sprite kept untouched on disk
        "Malgrath the Warden": spr_malgrath_warden,
        "Grave Stalker":        spr_grave_stalker,
        "Bone Colossus":        spr_bone_colossus,
        "Cinder Imp":           spr_cinder_imp,
        "Magma Slug":           spr_magma_slug,
        "Ash Wraith":           spr_ash_wraith,
        "Fire Drake":           spr_fire_drake,
        "Lava Spitter":         spr_lava_spitter,
        "Smoldering Revenant":  spr_smoldering_revenant,
        "Cinder Golem":         spr_cinder_golem,
        "Infernal Revenant":    spr_infernal_revenant,
        "Ice Specter":          spr_ice_specter,
        "Frost Shard":          spr_frost_shard,
        "Glacial Lurker":       spr_glacial_lurker,
        "Pale Archivist":       spr_pale_archivist,
        "Snowbound Wraith":     spr_snowbound_wraith,
        "Frozen Thrall":        spr_frozen_thrall,
        "Glacial Beast":        spr_glacial_beast,
        "Frozen Sentinel":      spr_frozen_sentinel,
        // Boss sprites (07-14): all six bosses that shared another enemy's model
        // now have their own art (PixelLab, style-matched to each dungeon family).
        "Glacial Warden":       spr_glacial_warden,
        "Tomb Archon":          spr_tomb_archon,
        "The Eternal Frost":    spr_eternal_frost,
        "Forge Tyrant":         spr_forge_tyrant,
        "Molten Revenant":      spr_molten_revenant,
        "The Ashen Colossus":   spr_ashen_colossus,
        // THE ASHEN DUELIST (08-08 fix): he is cloned from an elite and then
        // RENAMED, and this map is keyed by name - so the lookup missed and he
        // fought as an empty space (M screenshot). Tier-0 art landed 08-09; the
        // higher tiers resolve through duelist_sprite_for(). Spec in
        // DESIGN_DUELIST_CHALLENGE.md.
        "The Ashen Duelist":    spr_ashen_duelist,
        // DEPTH WARDENS (08-13): STAND-IN models from the existing roster until
        // a warden art run happens - an unmapped name draws NOTHING in combat,
        // and invisible bosses are worse than borrowed clothes.
        "The First Door":         spr_vault_sentinel,
        "Sister Fathom":          spr_snowbound_wraith,
        "The Tally":              spr_pale_archivist,
        "Hollowlight":            spr_ash_wraith,
        "The Weight of Ironwake": spr_bone_colossus,
        "The Long Arithmetic":    spr_tomb_archon,
        "Nothing In Particular":  spr_grave_stalker,
        "The Understudy":         spr_vault_guardian,
        "The Hollow Crown":       spr_bone_sovereign,
        "The Bottom":             spr_stone_golem,
    };
}

// Sprite for a duel encounter, tiered by how many duels the player has already
// fought (global.duelist_encounters, the ledger that never resets). The Duelist
// grows +10% per prior duel forever, so he should LOOK like he has been winning.
// Falls back down the tiers - and finally to the base map entry - so the feature
// works before the art for the higher tiers exists.
function duelist_sprite_for(_wins) {
    var _tier = (_wins >= 9) ? 3 : ((_wins >= 5) ? 2 : ((_wins >= 2) ? 1 : 0));
    for (var _t = _tier; _t >= 1; _t--) {
        var _a = asset_get_index("spr_ashen_duelist_t" + string(_t));
        if (_a >= 0) return _a;
    }
    var _b = asset_get_index("spr_ashen_duelist");
    if (_b >= 0) return _b;
    return -1;   // caller falls back to enemy_sprite_map()
}

// =============================================================================
// BESTIARY (Journal tab, 2026-07-04) - brief authored lore per species, grouped
// by dungeon family. Display-only: names match the combat sprite map / enemy
// templates so the reader recognises what it just fought.
// =============================================================================
function bestiary_catalog() {
    return [
        // --- Ashen Vault -----------------------------------------------------
        { name:"Ashen Skeleton",      family:"Ashen Vault",    kind:"Standard", lore:"Vault soldiers who burned at their posts and kept standing. The ash fused to their bones like a second armor; they still march the old patrol routes, saluting doors that no longer exist." },
        { name:"Skeleton Archer",     family:"Ashen Vault",    kind:"Standard", lore:"Their eyes went first, so they listen. An arrow loosed by a skeleton archer follows breath, heartbeat, the creak of leather - closing your mouth will not save you." },
        { name:"Vault Crawler",       family:"Ashen Vault",    kind:"Standard", lore:"Something between a spider and a bad memory. Crawlers nest in the spaces behind the walls and drink the marrow of whatever the Vault kills - patient, plentiful, always hungry." },
        { name:"Dungeon Wraith",      family:"Ashen Vault",    kind:"Standard", lore:"The Vault's grief given a shape. Wraiths drift the corridors repeating the last hour of their lives; interrupt the performance and they remember, briefly and violently, that you are alive and they are not." },
        { name:"Stone Golem",         family:"Ashen Vault",    kind:"Elite",    lore:"Cut from the Vault's own foundation stones and wound with binding-runes. A golem does not hate you. It has simply been told, in a language older than mercy, that nothing leaves." },
        { name:"Vault Guardian",      family:"Ashen Vault",    kind:"Elite",    lore:"The Vault's last professional soldiers, oath-bound past death. Their shields still carry the sigil of a kingdom no map remembers - they defend its treasury all the same." },
        { name:"Vault Wraith",        family:"Ashen Vault",    kind:"Elite",    lore:"Older and colder than the common wraith - a keeper of the Vault's inner doors. It knew the treasury's inventory by heart, and it counts you now among the items to be shelved." },
        { name:"Vault Sentinel",      family:"Ashen Vault",    kind:"Elite",    lore:"Watchtowers on legs, forged to sound an alarm no one is left to answer. A sentinel's gaze sweeps the dark on a fixed rhythm learned over centuries; the rhythm is a lie it hopes you'll trust." },
        { name:"Grave Stalker",       family:"Ashen Vault",    kind:"Elite",    lore:"It learned to hunt by watching adventurers die: where they look, when they rest, what they reach for last. The stalker is the Vault's memory of every mistake ever made inside it." },
        { name:"Bone Sovereign",      family:"Ashen Vault",    kind:"Boss",     lore:"The king the Vault was built to keep - or to keep in. The Sovereign wears a crown of fused vertebrae and holds court over everything that has ever died down here, which is everything." },
        { name:"Malgrath the Warden", family:"Ashen Vault",    kind:"Boss",     lore:"The Vault's first and last jailer. Malgrath swore no prisoner would leave and, when the end came, applied the oath to himself. He is not angry that you came. He is pleased the count is going up." },
        { name:"Bone Colossus",       family:"Ashen Vault",    kind:"Boss",     lore:"When the Vault's dead grew too many to walk singly, they walked together. The Colossus is a congregation - hundreds of skeletons in one towering consensus, disagreeing only about which hand should crush you." },
        // --- Scorched Depths -------------------------------------------------
        { name:"Cinder Imp",          family:"Scorched Depths", kind:"Standard", lore:"Sparks that got ideas. Imps pour out of the deep vents in giggling swarms, setting fires they are too small to survive - martyrs to arson, endlessly replaced." },
        { name:"Magma Slug",          family:"Scorched Depths", kind:"Standard", lore:"It eats stone and leaves roads of glass. Miners once followed slug-trails to rich veins; the slugs, in time, learned to follow the miners." },
        { name:"Ash Wraith",          family:"Scorched Depths", kind:"Standard", lore:"When the Depths burned, some souls rose with the smoke and never came down. An ash wraith is a held breath of the great fire - disturb it and it exhales." },
        { name:"Lava Spitter",        family:"Scorched Depths", kind:"Standard", lore:"A squat, gulping thing that sips from magma pools and holds the mouthful for hours. It has one trick and one virtue: it never misses twice at the same target." },
        { name:"Fire Drake",          family:"Scorched Depths", kind:"Elite",    lore:"Too young to be called dragons, too proud to be called anything else. Drakes claim a gallery of the Depths each and pay for the territory in cinders." },
        { name:"Smoldering Revenant", family:"Scorched Depths", kind:"Elite",    lore:"A knight who walked into the fire to retrieve something - no account agrees on what - and walked out changed. It is still searching. It has decided you might be carrying it." },
        { name:"Cinder Golem",        family:"Scorched Depths", kind:"Elite",    lore:"Built by the forge-priests to tend flames no living hand could. The priests are gone; the tending continues. You are, as far as the golem is concerned, unscheduled fuel." },
        { name:"Infernal Revenant",   family:"Scorched Depths", kind:"Elite",    lore:"The smoldering ones that stopped smoldering and started burning. An infernal revenant no longer remembers what it lost in the fire - only that someone must owe it." },
        { name:"Forge Tyrant",        family:"Scorched Depths", kind:"Boss",     lore:"Master of the great forge at the world's waist. Every weapon in the Depths bears his mark, and he considers every one of them - including the one on your belt - a loan." },
        { name:"Molten Revenant",     family:"Scorched Depths", kind:"Boss",     lore:"The first soul the great fire took, and the one it kept closest. The Molten Revenant is grief hot enough to pour - the Depths' own heart, walking." },
        { name:"The Ashen Colossus",  family:"Scorched Depths", kind:"Boss",     lore:"They say the Depths burned because something enormous lay down to sleep in them. The Colossus is what wakes when the deepest floors go quiet - so the deepest floors are never quiet." },
        // --- Tundra Tomb -----------------------------------------------------
        { name:"Ice Specter",         family:"Tundra Tomb",    kind:"Standard", lore:"Cold that learned to want. Specters drift the tomb-halls tracing frost-flowers on the sarcophagi, and unravel with a shriek anything warm enough to remind them." },
        { name:"Frost Shard",         family:"Tundra Tomb",    kind:"Standard", lore:"Fragments of the Tomb's shattered ward-glacier, still obeying the last order the wards were given: sharpen, and hold. They travel in glittering, humming clusters." },
        { name:"Frozen Thrall",       family:"Tundra Tomb",    kind:"Standard", lore:"Grave-servants sealed in with their masters, preserved mid-errand by the cold. A thrall will finish its final task - carrying, digging, killing - the moment anyone wakes it." },
        { name:"Snowbound Wraith",    family:"Tundra Tomb",    kind:"Standard", lore:"Pilgrims who died within sight of the Tomb's doors and were never let in. They press against the living like a draft under a door - desperate, envious, cold beyond argument." },
        { name:"Glacial Lurker",      family:"Tundra Tomb",    kind:"Elite",    lore:"It swims through packed ice the way eels swim through water. You will hear the creak of its passage in the walls a full room before it decides which floor to come up through." },
        { name:"Pale Archivist",      family:"Tundra Tomb",    kind:"Elite",    lore:"The Tomb's librarian, cataloguing the dead in ledgers of frost. It finds the living genuinely upsetting - entries that keep editing themselves - and moves swiftly to correct the record." },
        { name:"Glacial Beast",       family:"Tundra Tomb",    kind:"Elite",    lore:"Something the builders walled in rather than fought. Centuries of cold slowed its heart to one beat an hour; every intruder since has been an alarm clock." },
        { name:"Frozen Sentinel",     family:"Tundra Tomb",    kind:"Elite",    lore:"Armored watchmen grown into the ice they stood in. Only the eyes still move - until you are close enough to matter." },
        { name:"Glacial Warden",      family:"Tundra Tomb",    kind:"Boss",     lore:"Keeper of the Tomb's sealed vaults, crowned in hoarfrost. The Warden's rounds have not varied in a thousand years; you are the first thing worth changing them for." },
        { name:"Tomb Archon",         family:"Tundra Tomb",    kind:"Boss",     lore:"The Tomb was built to honor the Archon; the cold was its idea. It presides from a throne of black ice, judging the frozen dead - and finds most of them, and all of the living, wanting." },
        { name:"The Eternal Frost",   family:"Tundra Tomb",    kind:"Boss",     lore:"Not a creature so much as the Tomb's winter given a will. Where it walks, torches gutter and time itself slows to a crawl. The dead call it mercy. The living rarely get to call it anything." },
        // --- 08-06: THE DEPTH WARDENS (DESIGN_WORLD_EXPANSION_0806.md §4) ------
        // Descent-only bosses on a five-floor cadence. Each attacks a HABIT
        // rather than a stat - endless scaling eventually beats raw numbers, so
        // the fights have to test something else.
        { name:"The First Door",         family:"The Descent", kind:"Boss", lore:"Every descent begins by opening something that was closed. The First Door is what closing meant, before anyone thought to build a hinge for it. It opens for you. That is the whole of the threat." },
        { name:"Sister Fathom",          family:"The Descent", kind:"Boss", lore:"She measures. Depth, pressure, the reach of a swing - all of it, constantly, and she keeps the numbers. Hit her hard enough and she simply records the figure and gives it back to herself." },
        { name:"The Tally",              family:"The Descent", kind:"Boss", lore:"It has been counting since before the Vault was sealed and has never once lost its place. Repeat yourself in front of it and you will find the count was of you." },
        { name:"Hollowlight",            family:"The Descent", kind:"Boss", lore:"A lantern with nothing holding it. The light it sheds is the exact colour of relief, and everything it falls on gets worse. Mercy, run backwards." },
        { name:"The Weight of Ironwake", family:"The Descent", kind:"Boss", lore:"Everything the town has ever put down here, still being carried. It is not angry and it is not hunting. It is simply extremely heavy, and it is between you and the way down." },
        { name:"The Long Arithmetic",    family:"The Descent", kind:"Boss", lore:"Somewhere below the last floor, the sums stop balancing. This is what does the reconciling. It will not let you deal more than you can survive, because that is not how the books work." },
        { name:"Nothing In Particular",  family:"The Descent", kind:"Boss", lore:"There is no entry for this one. Survivors describe a fight and cannot say against what. The dogs it leaves behind are real enough, and they heel." },
        { name:"The Understudy",         family:"The Descent", kind:"Boss", lore:"It has watched every descent ever made and has been practising. It knows your build. It is wearing your affixes. It has been waiting a long time for the part." },
        { name:"The Hollow Crown",       family:"The Descent", kind:"Boss", lore:"A circlet the size of a gate, above a throne with nothing on it. The king it belonged to is a thousand years gone and it is still ruling, and the fight gets quieter the longer it goes on." },
        { name:"The Bottom",             family:"The Descent", kind:"Boss", lore:"The floor under the floors. Everything that fell is here, arranged, and it has had a very long time to decide what it thinks of the falling." },
    ];
}

// =============================================================================
// DEPTH WARDENS - data layer (08-06). DESIGN_WORLD_EXPANSION_0806.md §4.
//
// ⚠ NOT YET WIRED TO SPAWNING. This is the catalog + lookups only. The Descent's
// floor-boss selection lives outside obj_floor_controller and was not traced in
// this pass; wiring a half-understood generation path risks breaking run
// generation, which is a far worse failure than "the Wardens aren't in yet".
// The remaining step is: at Descent floor-boss selection, when
// warden_for_floor(N) returns non-empty, spawn that Warden instead of the
// theme's normal floor boss.
// =============================================================================

// Wardens replace the recycled theme boss on every 5th Descent floor. Past 50
// they cycle, so the ladder never runs out.
function warden_catalog() {
    return [
        { floor: 5,  name:"The First Door",         scion:"doorling",     hook:"Opens with a shield equal to the floors you have cleared." },
        { floor:10,  name:"Sister Fathom",          scion:"fathom_squid", hook:"Heals for any damage you deal above 30 in one hit." },
        { floor:15,  name:"The Tally",              scion:"tallykeep",    hook:"Gains a permanent stack each time you use the same ability twice." },
        { floor:20,  name:"Hollowlight",            scion:"lantern_wyrm", hook:"Your healing is inverted for the first 2 turns." },
        { floor:25,  name:"The Weight of Ironwake", scion:"deepclaw",     hook:"Three phases; drops a guaranteed Depthforged legendary." },
        { floor:30,  name:"The Long Arithmetic",    scion:"sum_moth",     hook:"Damage you deal is capped at your current HP." },
        { floor:35,  name:"Nothing In Particular",  scion:"null_hound",   hook:"Untargetable every other turn." },
        { floor:40,  name:"The Understudy",         scion:"mimicling",    hook:"Copies your equipped weapon's affixes." },
        { floor:45,  name:"The Hollow Crown",       scion:"griefwisp",    hook:"Silences one random ability each turn." },
        { floor:50,  name:"The Bottom",             scion:"",             hook:"The intended end of the ladder; unique title + splash." },
    ];
}

// The Warden owed by a Descent floor, or "" when this floor keeps its theme
// boss. Past floor 50 the ladder cycles through the same ten.
function warden_for_floor(fl) {
    if (fl <= 0 || (fl mod 5) != 0) return "";
    var _c = warden_catalog();
    var _n = array_length(_c);
    var _slot = (fl / 5);                       // 1-based: floor 5 -> 1
    var _idx  = ((_slot - 1) mod _n);
    return _c[_idx].name;
}

// The scion a Warden drops ("" if it has none - The Bottom is a milestone, not
// a parent). Kept separate from pet_boss_signature_species() so the Descent
// path never has to guess a floor key.
function warden_scion(warden_name) {
    var _c = warden_catalog();
    for (var _i = 0; _i < array_length(_c); _i++)
        if (_c[_i].name == warden_name) return _c[_i].scion;
    return "";
}

// Flat 4% per DESIGN §2.1. Wardens recur forever on the cadence, so this is a
// fishing expedition at whatever depth the player can actually survive.
function warden_scion_drop_chance() { return 4; }

// =============================================================================
// scr_ui.gml
// Combat HUD drawing functions for Ironwake.
// Room dimensions: 1280 × 720.
//
// All functions are pure draw calls — they read state but never mutate it.
// Call every function from a Draw event (or a dedicated Draw GUI event).
//
// Draw call order in ui_draw_combat_hud():
//   1. Turn queue          — top-center
//   2. Player HP bar       — top-left
//   3. Energy pips         — below HP bar
//   4. Secondary resource  — below energy pips
//   5. Level + XP bar      — below secondary resource
//   6. Player buff icons   — below XP bar
//   7. Ability buttons     — bottom-center
//   8. Combat log          — bottom-left
//   9. Telegraph warning   — overlaid at top (only when active)
//  Enemy debuff icons are drawn in Draw_64.gml below each enemy HP bar.
// =============================================================================

// ---------------------------------------------------------------------------
// ui_item_stat_str(item)
// Builds a compact stat string from an item's primary stat + affixes array.
// E.g.  "+4 STR   +2 CON  +5% Crit"
// ---------------------------------------------------------------------------
function ui_item_stat_str(item) {
    // Weapons lead with their flat reach-gated damage ("+N dmg"); any +stat the weapon
    // also carries (global, as before) follows it. Non-weapons just show their stat.
    var _s = "";
    if (variable_struct_exists(item, "weapon_damage") && item.weapon_damage > 0) {
        _s = "+" + string(item.weapon_damage) + " dmg";
        // Tag the weapon's hand requirement so the offhand trade-off is visible.
        _s += (variable_struct_exists(item, "two_handed") && item.two_handed) ? "  (2H)" : "  (1H)";
    }
    if (variable_struct_exists(item, "stat_value") && variable_struct_exists(item, "stat_name") && item.stat_value != 0) {
        _s += (_s == "" ? "" : "   ") + "+" + string(item.stat_value) + " " + item.stat_name;
    }
    if (variable_struct_exists(item, "affixes")) {
        var _aff = item.affixes;
        var _alen = array_length(_aff);
        for (var _i = 0; _i < _alen; _i++) {
            var _af = _aff[_i];
            var _asn = _af.stat_name;
            if (_asn == "bonus_max_hp") {
                _s += "   +" + string(_af.stat_value) + " HP";
            } else if (_asn == "crit_flat") {
                _s += "   +" + string(_af.stat_value) + "% Crit";
            } else if (_asn == "dodge_flat") {
                _s += "   +" + string(_af.stat_value) + " Dodge";
            } else if (_asn == "gold_find") {
                _s += "   +" + string(_af.stat_value) + "% Gold";
            } else {
                _s += "   +" + string(_af.stat_value) + " " + _asn;
            }
        }
    }
    return _s;
}

// ---------------------------------------------------------------------------
// ui_str_hash(s) — small deterministic string hash (djb-ish, 31-mult). Used to
// give Rare+ swords a STABLE per-item-identity icon (same base name → same icon).
// ---------------------------------------------------------------------------
function ui_str_hash(s) {
    var _h = 0;
    for (var _i = 1; _i <= string_length(s); _i++) {
        _h = ((_h * 31) + ord(string_char_at(s, _i))) & 0x7fffffff;
    }
    return _h;
}

// ---------------------------------------------------------------------------
// ui_weapon_icon_sprite(item)
// Returns the asset index of the correct weapon icon based on name keywords.
// Keyword map: wand/focus/scepter→wand, bow→bow, sickle→sickle, spear/reach→spear.
// Everything else is treated as a sword (also the default). Rare+ swords (rarity
// >= 2) get a theme- and rarity-specific icon via ui_sword_icon_rare; Common/
// Uncommon swords keep the single plain spr_icon_weapon_sword.
// ---------------------------------------------------------------------------
function ui_weapon_icon_sprite(item) {
    var _n = string_lower(item.name);
    if (string_pos("wand",   _n) > 0 || string_pos("focus", _n) > 0 || string_pos("scepter", _n) > 0) return spr_icon_weapon_wand;
    if (string_pos("bow",    _n) > 0)                                  return spr_icon_weapon_bow;
    if (string_pos("sickle", _n) > 0)                                  return spr_icon_weapon_sickle;
    if (string_pos("spear",  _n) > 0 || string_pos("reach", _n) > 0)   return spr_icon_weapon_spear;

    var _rar = variable_struct_exists(item, "rarity") ? item.rarity : 0;
    if (_rar >= 2) return ui_sword_icon_rare(item, _n, _rar);
    return spr_icon_weapon_sword;
}

// ---------------------------------------------------------------------------
// ui_sword_icon_rare(item, _n, _rar)
// Picks an individual sword icon for a Rare+ sword. Theme comes from the base
// name (the elemental identity — affixes are stat words, not elements) with the
// full affixed name adding tints (Ghost→void, Gilded→radiant, Arcane/Runed→arcane).
// Within a theme, rarity selects the lower (Rare) or upper (Epic+) half of the
// theme's icon list — fancier art at higher rarity — and a base-name hash picks
// within that half so each distinct sword always shows the same icon.
// ---------------------------------------------------------------------------
function ui_sword_icon_rare(item, _n, _rar) {
    var _base = string_lower(item_base_name(item));
    var _bucket;
    if      (string_pos("ash",    _base) > 0 || string_pos("ember", _n) > 0 || string_pos("flame", _n) > 0
          || string_pos("scorch", _n) > 0    || string_pos("sear",  _n) > 0 || string_pos("magma", _n) > 0
          || string_pos("cinder", _n) > 0    || string_pos("fire",  _n) > 0)
        _bucket = [spr_icon_sword_fire_a, spr_icon_sword_fire_b, spr_icon_sword_fire_c];
    else if (string_pos("frost", _n) > 0 || string_pos("froze", _n) > 0 || string_pos("ice",   _n) > 0
          || string_pos("glaci", _n) > 0 || string_pos("rime",  _n) > 0 || string_pos("chill", _n) > 0)
        _bucket = [spr_icon_sword_frost_a, spr_icon_sword_frost_b];
    else if (string_pos("ghost",  _n) > 0 || string_pos("void",  _n) > 0 || string_pos("shadow", _n) > 0
          || string_pos("wraith", _n) > 0 || string_pos("abyss", _n) > 0)
        _bucket = [spr_icon_sword_void_a, spr_icon_sword_void_b];
    else if (string_pos("vampir",  _n) > 0 || string_pos("blood", _n) > 0 || string_pos("sanguine", _n) > 0
          || string_pos("crimson", _n) > 0 || string_pos("gore",  _n) > 0 || string_pos("ruin",     _n) > 0)
        _bucket = [spr_icon_sword_blood_a, spr_icon_sword_blood_b];
    else if (string_pos("gild", _n) > 0 || string_pos("lucky",  _n) > 0 || string_pos("radian", _n) > 0
          || string_pos("holy", _n) > 0 || string_pos("divine", _n) > 0 || string_pos("sacred", _n) > 0)
        _bucket = [spr_icon_sword_radiant_a, spr_icon_sword_radiant_b];
    else if (string_pos("arcane", _n) > 0 || string_pos("rune", _n) > 0 || string_pos("storm", _n) > 0)
        _bucket = [spr_icon_sword_arcane_a, spr_icon_sword_arcane_b];
    else
        _bucket = [spr_icon_sword_steel_a, spr_icon_sword_steel_b, spr_icon_sword_steel_c, spr_icon_sword_steel_d];

    var _len  = array_length(_bucket);
    var _half = max(1, _len div 2);
    var _start, _size;
    if (_rar >= 3) { _start = _half; _size = _len - _half; }   // Epic+ → upper (fancier) half
    else           { _start = 0;     _size = _half;        }   // Rare  → lower half
    return _bucket[_start + (ui_str_hash(_base) mod _size)];
}

// ---------------------------------------------------------------------------
// ui_offhand_icon_sprite(item)
// Off-hand subtype by name keyword (mirrors the weapon resolver) so off-hands
// no longer all read as one shield. Shields/bucklers/bulwarks use sliced
// medieval art; caster off-hands (totem/orb/stone/focus) use distinct arcane
// tome art. Falls back to the generic spr_icon_offhand for unmatched names.
// ---------------------------------------------------------------------------
function ui_offhand_icon_sprite(item) {
    var _n = string_lower(item.name);
    if (string_pos("buckler",   _n) > 0)                                  return spr_icon_offhand_buckler;
    if (string_pos("bulwark",   _n) > 0 || string_pos("ironhide", _n) > 0) return spr_icon_offhand_bulwark;
    if (string_pos("shield",    _n) > 0 || string_pos("aegis",    _n) > 0) return spr_icon_offhand_shield;
    if (string_pos("totem",     _n) > 0 || string_pos("idol",     _n) > 0) return spr_icon_offhand_totem;
    if (string_pos("orb",       _n) > 0 || string_pos("sphere",   _n) > 0) return spr_icon_offhand_orb;
    if (string_pos("soulstone", _n) > 0 || string_pos("fragment", _n) > 0 || string_pos("stone", _n) > 0) return spr_icon_offhand_stone;
    if (string_pos("focus",     _n) > 0 || string_pos("runic",    _n) > 0
        || string_pos("tome",   _n) > 0 || string_pos("book",     _n) > 0 || string_pos("grimoire", _n) > 0) return spr_icon_offhand_focus;
    return spr_icon_offhand;
}

// ---------------------------------------------------------------------------
// ui_ring_icon_sprite(item) / ui_amulet_icon_sprite(item)
// Per-identity jewelry icons by name keyword (themed art from the accessories
// pack). Keyword order matters where a name contains several keywords (e.g.
// "Wraithbone Signet" -> wraith, "Soul-Linked Talisman" -> soul). Fall back to
// the generic ring/amulet sprite for unmatched names.
// ---------------------------------------------------------------------------
function ui_ring_icon_sprite(item) {
    var _n = string_lower(item.name);
    if (string_pos("void",   _n) > 0)                                    return spr_icon_ring_void;
    if (string_pos("blood",  _n) > 0 || string_pos("pact",      _n) > 0) return spr_icon_ring_blood;
    if (string_pos("ember",  _n) > 0)                                    return spr_icon_ring_ember;
    if (string_pos("wraith", _n) > 0)                                    return spr_icon_ring_wraith;
    if (string_pos("bone",   _n) > 0)                                    return spr_icon_ring_bone;
    if (string_pos("signet", _n) > 0 || string_pos("copper",    _n) > 0) return spr_icon_ring_signet;
    if (string_pos("band",   _n) > 0 || string_pos("tarnished", _n) > 0) return spr_icon_ring_band;
    return spr_icon_ring;
}

function ui_amulet_icon_sprite(item) {
    var _n = string_lower(item.name);
    if (string_pos("eye",       _n) > 0)                                  return spr_icon_amulet_eye;
    if (string_pos("soul",      _n) > 0)                                  return spr_icon_amulet_soul;
    if (string_pos("medallion", _n) > 0)                                  return spr_icon_amulet_medallion;
    if (string_pos("sentry",    _n) > 0 || string_pos("pendant",  _n) > 0) return spr_icon_amulet_sentry;
    if (string_pos("chain",     _n) > 0 || string_pos("silver",   _n) > 0) return spr_icon_amulet_chain;
    if (string_pos("bone",      _n) > 0 || string_pos("talisman", _n) > 0) return spr_icon_amulet_bone;
    if (string_pos("dusty",     _n) > 0)                                  return spr_icon_amulet_dusty;
    return spr_icon_amulet;
}

// ---------------------------------------------------------------------------
// awakening_label() — formatted "Awakening A2 — Brutal" string for the current
// run difficulty (global.selected_ascendance). Mirrors the hub's tier names so
// the combat and dungeon screens can show the awakening tier as a reference.
// ---------------------------------------------------------------------------
function awakening_label() {
    var _asc = variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0;
    var _names = ["Normal", "Hardened", "Brutal", "Relentless", "Nightmare", "Infernal"];
    _asc = clamp(_asc, 0, array_length(_names) - 1);
    return "Awakening A" + string(_asc) + " — " + _names[_asc];
}

// ---------------------------------------------------------------------------
// ui_draw_item_icon(x, y, sz, item)
// Draws a pixel art icon for the item, scaled to sz×sz.
// Legendary items are detected via unique_effect; weapons use name-keyword
// subtype detection. Falls back to colored box + abbreviation if the sprite
// has not yet been imported into the project.
// ---------------------------------------------------------------------------
function ui_draw_item_icon(x, y, sz, item) {
    var _slot = variable_struct_exists(item, "slot") ? item.slot : "";
    var _rar  = variable_struct_exists(item, "rarity") ? item.rarity : 0;
    var _rcol = item_rarity_color(_rar);

    // Resolve icon sprite — -1 means "not found, use fallback"
    var _spr = -1;

    // Legendary items identified by unique_effect field
    if (variable_struct_exists(item, "unique_effect")) {
        switch (item.unique_effect) {
            case "gatewarden_brand":  _spr = spr_icon_legendary_gatewarden_brand;  break;
            case "heartstone_aegis":  _spr = spr_icon_legendary_heartstone_aegis;  break;
            case "crown_hollow_king": _spr = spr_icon_legendary_crown_hollow_king; break;
            case "thief_of_hours":    _spr = spr_icon_legendary_thief_of_hours;    break;
        }
    }

    // Equipment slots (weapons dispatch to subtype helper)
    if (_spr == -1) {
        switch (_slot) {
            case "weapon":        _spr = ui_weapon_icon_sprite(item);  break;
            case "ranged_weapon": _spr = ui_weapon_icon_sprite(item);  break;
            case "offhand": _spr = ui_offhand_icon_sprite(item); break;
            case "helm":    _spr = spr_icon_helm;                break;
            case "chest":   _spr = spr_icon_chest;               break;
            case "gloves":  _spr = spr_icon_gloves;              break;
            case "boots":   _spr = spr_icon_boots;               break;
            case "amulet":  _spr = ui_amulet_icon_sprite(item);  break;
            case "ring":    _spr = ui_ring_icon_sprite(item);    break;
        }
    }

    // Force full opacity — icons are never meant to inherit a caller's dimmed alpha
    draw_set_alpha(1.0);

    // Dark panel background + rarity border
    draw_set_color(make_color_rgb(12, 14, 22));
    draw_rectangle(x, y, x + sz, y + sz, false);
    draw_set_color(_rcol);
    draw_rectangle(x, y, x + sz, y + sz, true);

    if (_spr != -1 && sprite_exists(_spr)) {
        // 2px inset keeps the rarity border visible around the icon
        draw_sprite_stretched(_spr, 0, x + 2, y + 2, sz - 4, sz - 4);
    } else {
        // Fallback: slot-colored fill + 3-letter abbreviation
        var _bg;
        switch (_slot) {
            case "weapon":        _bg = make_color_rgb(80, 38, 38); break;
            case "ranged_weapon": _bg = make_color_rgb(80, 56, 30); break;
            case "offhand": _bg = make_color_rgb(32, 55, 80); break;
            case "helm":    _bg = make_color_rgb(48, 48, 72); break;
            case "chest":   _bg = make_color_rgb(36, 58, 44); break;
            case "gloves":  _bg = make_color_rgb(62, 50, 32); break;
            case "boots":   _bg = make_color_rgb(44, 38, 62); break;
            case "amulet":  _bg = make_color_rgb(66, 38, 66); break;
            case "ring":    _bg = make_color_rgb(70, 58, 22); break;
            default:        _bg = make_color_rgb(36, 38, 52); break;
        }
        var _abbrev;
        switch (_slot) {
            case "weapon":        _abbrev = "MEL"; break;
            case "ranged_weapon": _abbrev = "RWP"; break;
            case "offhand": _abbrev = "OFF"; break;
            case "helm":    _abbrev = "HLM"; break;
            case "chest":   _abbrev = "CHT"; break;
            case "gloves":  _abbrev = "GLV"; break;
            case "boots":   _abbrev = "BTS"; break;
            case "amulet":  _abbrev = "AMU"; break;
            case "ring":    _abbrev = "RNG"; break;
            default:        _abbrev = "???"; break;
        }
        draw_set_color(_bg);
        draw_rectangle(x + 1, y + 1, x + sz - 1, y + sz - 1, false);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_set_color(make_color_rgb(195, 200, 220));
        draw_text_transformed(x + sz / 2, y + sz / 2, _abbrev, 0.68, 0.68, 0);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
    }
}

// ---------------------------------------------------------------------------
// ui_consumable_icon_sprite(cname)
// Returns the asset index of a consumable's icon by exact name, or -1 if none.
// Exact-match (not substring) is required: "Greater Healing Salve" contains
// "Healing Salve" and would otherwise collide.
// ---------------------------------------------------------------------------
function ui_consumable_icon_sprite(cname) {
    switch (cname) {
        case "Healing Salve":         return spr_icon_consumable_healing_salve;
        case "Antidote":              return spr_icon_consumable_antidote;
        case "Energy Tonic":          return spr_icon_consumable_energy_tonic;
        case "Smelling Salts":        return spr_icon_consumable_smelling_salts;
        case "Greater Healing Salve": return spr_icon_consumable_greater_healing_salve;
        case "Purification Draught":  return spr_icon_consumable_purification_draught;
        case "Adrenaline Vial":       return spr_icon_consumable_adrenaline_vial;
        case "Warden's Tonic":        return spr_icon_consumable_wardens_tonic;
    }
    return -1;
}

// ---------------------------------------------------------------------------
// ui_draw_consumable_icon(x, y, sz, item)
// Cyan-bordered icon badge for a consumable, mirroring ui_draw_item_icon's look
// for gear. Draws the consumable's sprite if one exists, else just the panel.
// Used by shops and the loot screen so consumables show icons like gear does.
// ---------------------------------------------------------------------------
function ui_draw_consumable_icon(x, y, sz, item) {
    var _cname = variable_struct_exists(item, "name") ? item.name : "";
    var _spr   = ui_consumable_icon_sprite(_cname);
    draw_set_alpha(1.0);
    draw_set_color(make_color_rgb(12, 14, 22));
    draw_rectangle(x, y, x + sz, y + sz, false);
    draw_set_color(make_color_rgb(80, 200, 200));
    draw_rectangle(x, y, x + sz, y + sz, true);
    if (_spr != -1 && sprite_exists(_spr)) {
        draw_sprite_stretched(_spr, 0, x + 2, y + 2, sz - 4, sz - 4);
    }
}

// ---------------------------------------------------------------------------
// ui_ability_icon_sprite(ability)
// Resolves the 64x64 icon sprite for an ability by name (Pass 2 icon initiative).
// Returns -1 when no icon is mapped so callers fall back to text-only buttons.
// All 49 Phase 1 abilities are mapped; add a case here when a new ability ships.
// ---------------------------------------------------------------------------
function ui_ability_icon_sprite(ability) {
    var _name = (is_struct(ability) && variable_struct_exists(ability, "name")) ? ability.name : ability;
    switch (_name) {
        // --- Arcanist ---
        case "Soulfire":         return spr_ability_soulfire;
        case "Void Drain":       return spr_ability_void_drain;
        case "Arcane Burst":     return spr_ability_arcane_burst;
        case "Soul Harvest":     return spr_ability_soul_harvest;
        case "Blink":            return spr_ability_blink;
        case "Curse":            return spr_ability_curse;
        case "Soul Shield":      return spr_ability_soul_shield;
        case "Entropy":          return spr_ability_entropy;
        case "Rift":             return spr_ability_rift;
        case "Soulbind":         return spr_ability_soulbind;
        // --- Bloodwarden ---
        case "Blood Leech":      return spr_ability_blood_leech;
        case "Iron Skin":        return spr_ability_iron_skin;
        case "Gore Strike":      return spr_ability_gore_strike;
        case "Blood Surge":      return spr_ability_blood_surge;
        case "Marrow Crush":     return spr_ability_marrow_crush;
        case "Vital Theft":      return spr_ability_vital_theft;
        case "Bloodthorn Aura":  return spr_ability_bloodthorn_aura;
        case "Undying":          return spr_ability_undying;
        case "Plague Touch":     return spr_ability_plague_touch;
        case "Bloodfeast":       return spr_ability_bloodfeast;
        // --- Shadowstrider ---
        case "Snipe":            return spr_ability_snipe;
        case "Bear Trap":        return spr_ability_bear_trap;
        case "Shadow Step":      return spr_ability_shadow_step;
        case "Poison Dart":      return spr_ability_poison_dart;
        case "Smoke Bomb":       return spr_ability_smoke_bomb;
        case "Crippling Shot":   return spr_ability_crippling_shot;
        case "Spike Trap":       return spr_ability_spike_trap;
        case "Marked for Death": return spr_ability_marked_for_death;
        case "Evasive Roll":     return spr_ability_evasive_roll;
        case "Death Snare":      return spr_ability_death_snare;
        // --- General ---
        case "Strike":           return spr_ability_strike;
        case "Field Dressing":   return spr_ability_field_dressing;
        case "Second Wind":      return spr_ability_second_wind;
        case "Adrenaline Rush":  return spr_ability_adrenaline_rush;
        case "Mana Sever":       return spr_ability_mana_sever;
        case "Arcane Echo":      return spr_ability_arcane_echo;
        case "Singularity":      return spr_ability_singularity;
        case "Sanguine Pact":    return spr_ability_sanguine_pact;
        case "Bonebreaker":      return spr_ability_bonebreaker;
        case "Crimson Apex":     return spr_ability_crimson_apex;
        case "Flurry":           return spr_ability_flurry;
        case "Vanish":           return spr_ability_vanish;
        case "Killing Spree":    return spr_ability_killing_spree;
        case "Scorch":           return spr_ability_scorch;
        case "Soul Nova":        return spr_ability_soul_nova;
        case "Cleave":           return spr_ability_cleave;
        case "Rupture":          return spr_ability_rupture;
        case "Throat Slit":      return spr_ability_throat_slit;
        case "Assassinate":      return spr_ability_assassinate;
    }
    return -1;
}

// ---------------------------------------------------------------------------
// ui_draw_ability_icon(x, y, sz, ability)
// Draws an ability's icon in a square badge at (x,y). Falls back to a plain
// dark panel when the ability has no mapped sprite, so callers never crash on
// an unmapped ability. No border is drawn here — callers own their framing.
// ---------------------------------------------------------------------------
function ui_draw_ability_icon(x, y, sz, ability) {
    var _spr = ui_ability_icon_sprite(ability);
    if (_spr != -1 && sprite_exists(_spr)) {
        // Uses the caller's current draw alpha so dimmed buttons dim the icon too.
        draw_sprite_stretched(_spr, 0, x, y, sz, sz);
    }
}

// ---------------------------------------------------------------------------
// item_splash_sprite(base_name)
// Returns the codex splash-art sprite for a base item, or -1 if none exists yet.
// Art is generated in batches (PixelLab) and wired here as each sprite lands;
// until then the codex detail pane falls back to the scaled item icon. Add a
// case per generated sprite: case "Iron Sword": return spr_item_art_iron_sword;
// ---------------------------------------------------------------------------
function item_splash_sprite(base_name) {
    switch (base_name) {
        // --- Legendaries ---
        case "Gatewarden's Brand":      return spr_item_art_gatewarden_brand;
        case "Heartstone Aegis":        return spr_item_art_heartstone_aegis;
        case "Crown of the Hollow King": return spr_item_art_crown_hollow_king;
        case "Thief of Hours":          return spr_item_art_thief_of_hours;
        // --- Common ---
        case "Ashen Blade": return spr_item_art_ashen_blade;
        case "Worn Shortbow": return spr_item_art_worn_shortbow;
        case "Cracked Focus": return spr_item_art_cracked_focus;
        case "Cracked Shield": return spr_item_art_cracked_shield;
        case "Ash Totem": return spr_item_art_ash_totem;
        case "Soulstone Fragment": return spr_item_art_soulstone_fragment;
        case "Ashen Hood": return spr_item_art_ashen_hood;
        case "Bone Cap": return spr_item_art_bone_cap;
        case "Tarnished Visor": return spr_item_art_tarnished_visor;
        case "Tattered Robes": return spr_item_art_tattered_robes;
        case "Rusted Chainshirt": return spr_item_art_rusted_chainshirt;
        case "Shadowcloth Tunic": return spr_item_art_shadowcloth_tunic;
        case "Worn Gauntlets": return spr_item_art_worn_gauntlets;
        case "Nimble Wraps": return spr_item_art_nimble_wraps;
        case "Sage's Gloves": return spr_item_art_sages_gloves;
        case "Worn Treads": return spr_item_art_worn_treads;
        case "Ironshod Boots": return spr_item_art_ironshod_boots;
        case "Dustwalker Wraps": return spr_item_art_dustwalker_wraps;
        case "Dusty Amulet": return spr_item_art_dusty_amulet;
        case "Bone Talisman": return spr_item_art_bone_talisman;
        case "Silver Chain": return spr_item_art_silver_chain;
        case "Bone Ring": return spr_item_art_bone_ring;
        case "Copper Signet": return spr_item_art_copper_signet;
        case "Tarnished Band": return spr_item_art_tarnished_band;
        // --- Uncommon ---
        case "Gravelstone Sword": return spr_item_art_gravelstone_sword;
        case "Vaultstone Wand": return spr_item_art_vaultstone_wand;
        case "Shadow Sickle": return spr_item_art_shadow_sickle;
        case "Warden's Buckler": return spr_item_art_wardens_buckler;
        case "Runic Focus": return spr_item_art_runic_focus;
        case "Watcher's Cowl": return spr_item_art_watchers_cowl;
        case "Iron Skullcap": return spr_item_art_iron_skullcap;
        case "Shadowthread Vest": return spr_item_art_shadowthread_vest;
        case "Ashwarden Coat": return spr_item_art_ashwarden_coat;
        case "Irongrip Gauntlets": return spr_item_art_irongrip_gauntlets;
        case "Fleethand Wraps": return spr_item_art_fleethand_wraps;
        case "Vaultstrider Boots": return spr_item_art_vaultstrider_boots;
        case "Stoneguard Greaves": return spr_item_art_stoneguard_greaves;
        case "Sentry's Pendant": return spr_item_art_sentrys_pendant;
        case "Soul-Linked Talisman": return spr_item_art_soul_linked_talisman;
        case "Ember Ring": return spr_item_art_ember_ring;
        case "Voidtouched Ring": return spr_item_art_voidtouched_ring;
        // --- Rare ---
        case "Ashkeeper Blade": return spr_item_art_ashkeeper_blade;
        case "Void Scepter": return spr_item_art_void_scepter;
        case "Serpent's Reach": return spr_item_art_serpents_reach;
        case "Soulbound Orb": return spr_item_art_soulbound_orb;
        case "Ironhide Bulwark": return spr_item_art_ironhide_bulwark;
        case "Forsaken Circlet": return spr_item_art_forsaken_circlet;
        case "Thornwarden Helm": return spr_item_art_thornwarden_helm;
        case "Voidskin Coat": return spr_item_art_voidskin_coat;
        case "Ironveil Plate": return spr_item_art_ironveil_plate;
        case "Crushers": return spr_item_art_crushers;
        case "Whispergloves": return spr_item_art_whispergloves;
        case "Shadowstep Boots": return spr_item_art_shadowstep_boots;
        case "Colossus Stompers": return spr_item_art_colossus_stompers;
        case "Medallion of Endurance": return spr_item_art_medallion_of_endurance;
        case "Warden's Eye": return spr_item_art_wardens_eye;
        case "Wraithbone Signet": return spr_item_art_wraithbone_signet;
        case "Bloodpact Ring": return spr_item_art_bloodpact_ring;
    }
    return -1;
}

// ---------------------------------------------------------------------------
// ui_room_icon_sprite(room_type)
// Returns the asset index of a floor-map room-type icon, or -1 if none exists
// for that type. Supply/armory/reliquary have art; the old trap icon is reused
// for event rooms (the trap room was folded into the event system).
// ---------------------------------------------------------------------------
function ui_room_icon_sprite(room_type) {
    switch (room_type) {
        case "treasure_heal":  return spr_icon_room_supply;
        case "treasure_vault": return spr_icon_room_armory;
        case "treasure_rare":  return spr_icon_room_reliquary;
        case "event":          return spr_icon_room_trap;
    }
    return -1;
}

// ---------------------------------------------------------------------------
// ui_input_blocked()
// Returns true when any full-screen overlay managed by obj_game_controller is
// open. Call as the very first line of room-controller Step events so their
// regular input does not bleed through while overlays are active.
// gc Step is intentionally excluded — it must keep running to handle overlays.
// ---------------------------------------------------------------------------
function ui_input_blocked() {
    if (tutorial_is_active()) return true;  // onboarding coach-mark is modal
    if (!instance_exists(obj_game_controller)) return false;
    var _gc = instance_find(obj_game_controller, 0);
    if (_gc.menu_open)       return true;   // character menu (I)
    if (_gc.stash_mode_open) return true;   // stash screen (T)
    if (_gc.shop_open != -1) return true;   // Petra / Dorn shops
    if (variable_instance_exists(_gc, "trainer_open") && _gc.trainer_open) return true;   // Vex the Trainer
    if (variable_instance_exists(_gc, "maren_open")   && _gc.maren_open)   return true;   // Maren the Runesmith
    if (variable_instance_exists(_gc, "sable_open")   && _gc.sable_open)   return true;   // Sable the Alchemist
    if (variable_instance_exists(_gc, "vael_open")    && _gc.vael_open)    return true;   // Vael the Aesthete
    if (variable_instance_exists(_gc, "level_alloc_open") && _gc.level_alloc_open) return true;
    if (variable_instance_exists(_gc, "loadout_open")     && _gc.loadout_open)     return true;
    return false;
}

// ---------------------------------------------------------------------------
// dungeon_bg_sprite(surface)
// Returns the sprite index for the current dungeon's themed background on a
// given surface, or -1 if that art hasn't been imported yet.
//   surface "combat"   -> spr_combatbg_<tag>_<floor>  (per-floor; floor 1-3 =
//                          the progression layer, so the arena escalates).
//   surface "floormap" -> spr_floormap_<tag>          (one per dungeon).
// <tag> is ashen | scorched | tundra. Uses asset_get_index (string lookup) so it
// compiles cleanly before the assets exist. NOTE: once imported, these string-only
// sprite refs MUST be added to global.__sprite_includes or the compiler strips them.
// ---------------------------------------------------------------------------
function dungeon_bg_sprite(surface) {
    var _d = variable_global_exists("selected_dungeon") ? global.selected_dungeon : "ashen_vault";
    var _tag = "ashen";
    if      (_d == "scorched_depths") _tag = "scorched";
    else if (_d == "tundra_tomb")     _tag = "tundra";

    var _name;
    if (surface == "combat") {
        var _fl = variable_global_exists("current_floor") ? global.current_floor : 1;
        _fl = clamp(_fl, 1, 3);
        _name = "spr_combatbg_" + _tag + "_" + string(_fl);
    } else {
        _name = "spr_floormap_" + _tag;
    }
    return asset_get_index(_name);
}

// ---------------------------------------------------------------------------
// dungeon_bg_draw(surface, scrim_alpha)
// Draws the themed dungeon background stretched to the 1280x720 GUI, with a dark
// scrim on top so overlaid UI (text, HP bars, node graph, sprites) stays legible
// regardless of the art's brightness. Returns false (drawing nothing) when the art
// isn't imported yet, so callers fall back to their flat fill — a safe no-op until
// the MidJourney backgrounds land. See [[project]] SYSTEMS / MISC_TASKS §5.
// ---------------------------------------------------------------------------
function dungeon_bg_draw(surface, scrim_alpha) {
    var _spr = dungeon_bg_sprite(surface);
    if (_spr == -1 || !sprite_exists(_spr)) return false;
    draw_set_color(c_white);
    draw_set_alpha(1.0);
    draw_sprite_stretched(_spr, 0, 0, 0, 1280, 720);
    draw_set_color(c_black);
    draw_set_alpha(scrim_alpha);
    draw_rectangle(0, 0, 1280, 720, false);
    draw_set_alpha(1.0);
    draw_set_color(c_white);
    return true;
}

// ---------------------------------------------------------------------------
// ui_draw_gothic_frame(x1, y1, x2, y2, band)
// Draws an ornate gothic 9-slice border (spr_ui_frame: carved stone + gold
// filigree) SURROUNDING the rect (x1,y1)-(x2,y2) — the band extends OUTWARD so
// the rect itself is the clear inner opening and panel content is never covered.
// The four corner ornaments draw undistorted; the edges stretch between them; the
// center (the inner opening) is skipped. Implemented manually with
// draw_sprite_part_ext so it needs no GameMaker nineSlice config.
//   band = drawn border thickness in px (default 26). Source ornate band is 42px;
//   corners scale band/42 so the filigree stays crisp at any panel size.
// For full-screen overlays pass a slightly inset rect (e.g. 28,28,1252,692) so the
// outward band stays on-screen. Call AFTER the panel's fill + content.
// ---------------------------------------------------------------------------
function ui_draw_gothic_frame(x1, y1, x2, y2, band = 26, _alpha = 1.0) {
    var _s  = spr_ui_frame;
    if (!sprite_exists(_s)) return;
    var _sw = sprite_get_width(_s);    // 192
    var _sb = 42;                      // source border (ornate band incl. corners)
    var _pw = x2 - x1;
    var _ph = y2 - y1;
    if (_pw < 8 || _ph < 8) return;

    var _cs  = band / _sb;             // corner scale (keeps filigree crisp)
    var _se  = _sw - _sb * 2;          // source edge length (between corners) = 108
    var _exs = _pw / _se;              // top/bottom edge x-stretch (spans the opening)
    var _eys = _ph / _se;              // left/right edge y-stretch

    draw_set_color(c_white);
    draw_set_alpha(_alpha);

    // --- Corners (undistorted, scaled by _cs), sitting just OUTSIDE each corner ---
    draw_sprite_part_ext(_s, 0, 0,          0,          _sb, _sb, x1 - band, y1 - band, _cs, _cs, c_white, _alpha); // TL
    draw_sprite_part_ext(_s, 0, _sw - _sb,  0,          _sb, _sb, x2,        y1 - band, _cs, _cs, c_white, _alpha); // TR
    draw_sprite_part_ext(_s, 0, 0,          _sw - _sb,  _sb, _sb, x1 - band, y2,        _cs, _cs, c_white, _alpha); // BL
    draw_sprite_part_ext(_s, 0, _sw - _sb,  _sw - _sb,  _sb, _sb, x2,        y2,        _cs, _cs, c_white, _alpha); // BR

    // --- Edges (stretched along each side of the opening) ---
    draw_sprite_part_ext(_s, 0, _sb,        0,          _se, _sb, x1,        y1 - band, _exs, _cs, c_white, _alpha); // top
    draw_sprite_part_ext(_s, 0, _sb,        _sw - _sb,  _se, _sb, x1,        y2,        _exs, _cs, c_white, _alpha); // bottom
    draw_sprite_part_ext(_s, 0, 0,          _sb,        _sb, _se, x1 - band, y1,        _cs, _eys, c_white, _alpha); // left
    draw_sprite_part_ext(_s, 0, _sw - _sb,  _sb,        _sb, _se, x2,        y1,        _cs, _eys, c_white, _alpha); // right
    draw_set_alpha(1.0);
}

// ---------------------------------------------------------------------------
// ui_list_window_first(cursor, count, max_vis)
// Returns the index of the first row to draw for a scrolling list so that the
// cursor always stays on screen. Centers the cursor within the visible window
// (stateless), clamped to valid bounds. Draw + mouse hit-testing must both use
// this so a windowed list stays click-accurate.
// ---------------------------------------------------------------------------
function ui_list_window_first(cursor, count, max_vis) {
    if (count <= max_vis) return 0;
    return clamp(cursor - floor(max_vis / 2), 0, count - max_vis);
}

// ---------------------------------------------------------------------------
// status_icon_color(name, effect_type)
// Returns a color for a given status effect name, falling back to effect_type.
// ---------------------------------------------------------------------------
function status_icon_color(sname, etype) {
    switch (sname) {
        case "Gore Strike":      return make_color_rgb(200,  50,  50);  // bleed
        case "Poison Dart":      return make_color_rgb( 80, 190,  60);  // poison
        case "Curse":            return make_color_rgb(160,  50, 210);  // curse
        case "Marrow Crush":     return make_color_rgb(210, 130,  40);  // weaken
        case "Smoke Bomb":       return make_color_rgb(150, 150, 155);  // blind
        case "Crippling Shot":   return make_color_rgb(210, 110,  40);  // cripple
        case "Plague Touch":     return make_color_rgb( 90, 200, 110);  // plague
        case "Marked for Death": return make_color_rgb(220, 200,  40);  // marked
    }
    if (etype == "dot")    return make_color_rgb(210, 120,  40);
    if (etype == "debuff") return make_color_rgb(170,  70,  70);
    return make_color_rgb(120, 120, 130);
}

// ---------------------------------------------------------------------------
// status_icon_label(name, effect_type)
// Returns a 2–3 char abbreviation for a status effect.
// ---------------------------------------------------------------------------
function status_icon_label(sname, etype) {
    switch (sname) {
        case "Gore Strike":      return "BLD";
        case "Poison Dart":      return "PSN";
        case "Curse":            return "CRS";
        case "Marrow Crush":     return "WKN";
        case "Smoke Bomb":       return "SMK";
        case "Crippling Shot":   return "CRP";
        case "Plague Touch":     return "PLG";
        case "Marked for Death": return "MFD";
    }
    if (etype == "dot")    return "DoT";
    if (etype == "debuff") return "DEB";
    return "?";
}

// ---------------------------------------------------------------------------
// status_icon_style(se) — KIND-BASED badge style for an applied status struct.
// Resolves {label, color} from the status `kind` (combat_status_kind_of) so EVERY
// status tags consistently (BLND/WKN/VUL/STUN/ROOT/SIL + PSN/BLEED/BRN/DOT),
// with the DoT sub-type chosen by name keyword. Falls back to the legacy
// name-keyed label/color for anything without a typed kind.
// ---------------------------------------------------------------------------
function status_icon_style(se) {
    var _kind = combat_status_kind_of(se);
    var _name = string_lower(variable_struct_exists(se, "name") ? se.name : "");
    switch (_kind) {
        case "dot":
            if (string_pos("bleed", _name) || string_pos("gore", _name) || string_pos("rend", _name) || string_pos("hemor", _name))
                return { label: "BLEED", color: make_color_rgb(175,  35,  35) };
            if (string_pos("burn", _name) || string_pos("cinder", _name) || string_pos("scorch", _name) || string_pos("flame", _name) || string_pos("ignit", _name) || string_pos("ember", _name))
                return { label: "BRN",   color: make_color_rgb(225, 130,  40) };
            if (string_pos("poison", _name) || string_pos("venom", _name) || string_pos("plague", _name) || string_pos("toxic", _name))
                return { label: "PSN",   color: make_color_rgb( 90, 200,  90) };
            return { label: "DOT",   color: make_color_rgb(210, 160,  60) };
        case "vulnerable": return { label: "VUL",  color: make_color_rgb(185,  65, 120) };
        case "weaken":     return { label: "WKN",  color: make_color_rgb(175, 110,  55) };
        case "blind":      return { label: "BLND", color: make_color_rgb(120, 125, 145) };
        case "mortality":  return { label: "MORT", color: make_color_rgb(120, 175,  90) };
        case "stun":       return { label: "STUN", color: make_color_rgb(228, 200,  60) };
        case "root":       return { label: "ROOT", color: make_color_rgb( 55, 160, 150) };
        case "silence":    return { label: "SIL",  color: make_color_rgb(125,  90, 205) };
    }
    return {
        label: status_icon_label(se.name, se.effect_type),
        color: status_icon_color(se.name, se.effect_type)
    };
}

// ---------------------------------------------------------------------------
// status_icons_from(status_effects) — build a [{label,color,duration}] icon list
// from a combatant's status_effects[], using kind-based styling. Shared by both
// the enemy bar row and the player buff row.
// ---------------------------------------------------------------------------
function status_icons_from(status_effects) {
    var _icons = [];
    for (var _i = 0; _i < array_length(status_effects); _i++) {
        var _se = status_effects[_i];
        var _st = status_icon_style(_se);
        array_push(_icons, {
            label:    _st.label,
            color:    _st.color,
            duration: variable_struct_exists(_se, "duration") ? _se.duration : 0
        });
    }
    return _icons;
}

// ---------------------------------------------------------------------------
// status_fx_sprite_for(se) — maps a status to its looping VFX sprite (or -1).
// kind/name → spr_fx_*; resolved by string so a missing sprite simply no-ops
// (the sprites are registered in global.__sprite_includes to survive the build).
// ---------------------------------------------------------------------------
function status_fx_sprite_for(se) {
    var _kind = combat_status_kind_of(se);
    var _name = string_lower(variable_struct_exists(se, "name") ? se.name : "");
    var _key  = "";
    switch (_kind) {
        case "dot":
            if (string_pos("bleed", _name) || string_pos("gore", _name) || string_pos("rend", _name) || string_pos("hemor", _name))
                _key = "spr_fx_bleed";
            else if (string_pos("burn", _name) || string_pos("cinder", _name) || string_pos("scorch", _name) || string_pos("flame", _name) || string_pos("ignit", _name) || string_pos("ember", _name))
                _key = "spr_fx_burn";
            else
                _key = "spr_fx_poison";   // poison / plague / venom / generic dot
            break;
        case "blind":     _key = "spr_fx_blind";  break;
        case "stun":      _key = "spr_fx_stun";   break;
        case "weaken": case "vulnerable": case "mortality": case "root": case "silence":
            _key = "spr_fx_weaken"; break;
    }
    if (_key == "") return -1;
    return asset_get_index(_key);
}

// item_slot_label(slot) — display name for an equipment slot key (weapon→"Weapon").
function item_slot_label(slot) {
    switch (slot) {
        case "weapon":        return "Melee Weapon";
        case "ranged_weapon": return "Ranged Weapon";
        case "offhand": return "Offhand";
        case "helm":    return "Helm";
        case "chest":   return "Chest";
        case "gloves":  return "Gloves";
        case "boots":   return "Boots";
        case "amulet":  return "Amulet";
        case "ring":    return "Ring";
    }
    return (is_string(slot) && slot != "") ? string_upper(string_copy(slot, 1, 1)) + string_copy(slot, 2, string_length(slot) - 1) : "Gear";
}

// status_effect_plain_text(se) — short plain-language description of what a status
// does, for the menu "Boons & Effects" panel (e.g. "12 dmg/turn", "-accuracy").
function status_effect_plain_text(se) {
    var _kind = combat_status_kind_of(se);
    var _val  = variable_struct_exists(se, "effect_value") ? se.effect_value : 0;
    switch (_kind) {
        case "dot":        return string(_val) + " dmg/turn";
        case "blind":      return "reduced accuracy";
        case "weaken":     return "weaker attacks";
        case "vulnerable": return "+" + string(_val) + " dmg taken";
        case "mortality":  return "reduced healing";
        case "stun":       return "cannot act";
        case "root":       return "cannot melee";
        case "silence":    return "cannot cast";
    }
    return (se.effect_type == "dot") ? (string(_val) + " dmg/turn") : "debuff";
}

// combatant_has_status_kind(c, kind) — true if any active status on c is of `kind`.
function combatant_has_status_kind(c, kind) {
    if (!variable_struct_exists(c, "status_effects")) return false;
    for (var _i = 0; _i < array_length(c.status_effects); _i++)
        if (combat_status_kind_of(c.status_effects[_i]) == kind) return true;
    return false;
}

// status_fx_anchor(se) — where on the combatant the fx sits: 0 head, 1 center, 2 feet.
function status_fx_anchor(se) {
    var _kind = combat_status_kind_of(se);
    if (_kind == "blind" || _kind == "stun") return 0;   // around the head
    var _name = string_lower(variable_struct_exists(se, "name") ? se.name : "");
    if (_kind == "dot" && (string_pos("burn", _name) || string_pos("cinder", _name) || string_pos("scorch", _name) || string_pos("flame", _name) || string_pos("ignit", _name) || string_pos("ember", _name)))
        return 2;   // flames at the feet
    return 1;       // gas / blood / aura at the body
}

// ---------------------------------------------------------------------------
// ui_draw_status_fx(cx, top_y, draw_h, status_effects) — overlay looping VFX
// sprites for every active status on a combatant, drawn over the sprite.
// cx = horizontal centre; top_y = sprite top; draw_h = displayed sprite height.
// De-dupes by sprite so stacked statuses of one type show a single effect.
// ---------------------------------------------------------------------------
function ui_draw_status_fx(cx, top_y, draw_h, status_effects) {
    var _drawn = [];
    var _fx_h  = draw_h * 0.55;
    // The poison cloud art fills its whole 64x64 canvas edge-to-edge, so at the
    // shared 55%-of-height size it blanketed the enemy. Shrink + fade ONLY the
    // poison sprite so the model stays visible; all other FX keep their size.
    var _spr_poison = asset_get_index("spr_fx_poison");
    draw_set_alpha(0.85);
    for (var _i = 0; _i < array_length(status_effects); _i++) {
        var _se  = status_effects[_i];
        var _spr = status_fx_sprite_for(_se);
        if (_spr == -1) continue;
        var _dup = false;
        for (var _d = 0; _d < array_length(_drawn); _d++) if (_drawn[_d] == _spr) { _dup = true; break; }
        if (_dup) continue;
        array_push(_drawn, _spr);

        var _is_poison = (_spr == _spr_poison);
        var _size_mult = _is_poison ? 0.62 : 1.0;   // ~34% of enemy height instead of 55%
        var _fx_alpha  = _is_poison ? 0.65 : 1.0;   // let the enemy show through the gas

        var _anchor = status_fx_anchor(_se);
        var _ay = top_y + draw_h * (_anchor == 0 ? 0.16 : (_anchor == 2 ? 0.82 : 0.50));
        var _sc = (_fx_h / max(1, sprite_get_height(_spr))) * _size_mult;
        var _fn = max(1, sprite_get_number(_spr));
        var _fr = (current_time div 110) mod _fn;
        draw_sprite_ext(_spr, _fr,
            cx - (sprite_get_width(_spr)  * _sc) * 0.5,
            _ay - (sprite_get_height(_spr) * _sc) * 0.5,
            _sc, _sc, 0, c_white, _fx_alpha);
    }
    draw_set_alpha(1.0);
}

// ---------------------------------------------------------------------------
// ui_draw_status_icon_row(x, y, icon_list)
// Draws a horizontal row of small badge-style status icons.
// icon_list: array of { label, color, duration }
// Each badge is 26×16px with a 2px gap; duration shown in small text below.
// ---------------------------------------------------------------------------
function ui_draw_status_icon_row(x, y, icon_list) {
    var _iw  = 26;
    var _ih  = 16;
    var _gap = 3;
    var _ix  = x;
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    for (var _i = 0; _i < array_length(icon_list); _i++) {
        var _ic = icon_list[_i];
        // filled badge
        draw_set_alpha(0.88);
        draw_set_color(_ic.color);
        draw_roundrect(_ix, y, _ix + _iw, y + _ih, false);
        // subtle dark border
        draw_set_alpha(1.0);
        draw_set_color(make_color_rgb(10, 10, 18));
        draw_roundrect(_ix, y, _ix + _iw, y + _ih, true);
        // label text
        draw_set_color(c_white);
        draw_text_transformed(_ix + _iw * 0.5, y + _ih * 0.5, _ic.label, 0.72, 0.72, 0);
        // duration counter below badge
        if (_ic.duration > 0) {
            draw_set_color(make_color_rgb(220, 215, 180));
            draw_text_transformed(_ix + _iw * 0.5, y + _ih + 7, string(_ic.duration), 0.68, 0.68, 0);
        }
        _ix += _iw + _gap;
    }
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
}

// ---------------------------------------------------------------------------
// ui_draw_enemy_status_icons(x, y, status_effects)
// Draws status icons for an enemy's status_effects array inline with their bar.
// Placed to the right of the HP bar; call from Draw_64 during the bar loop.
// ---------------------------------------------------------------------------
function ui_draw_enemy_status_icons(x, y, status_effects) {
    if (array_length(status_effects) == 0) exit;
    ui_draw_status_icon_row(x, y, status_icons_from(status_effects));
}

// ---------------------------------------------------------------------------
// ui_draw_item_tooltip(ttx, tty, item, compared_item)
// Draws a floating tooltip near the cursor for an equipment or consumable item.
// compared_item: currently equipped item in that slot (for Replaces line), or undefined.
// ---------------------------------------------------------------------------
function ui_draw_item_tooltip(ttx, tty, item, compared_item) {
    var _pad  = 10;
    var _lh   = 20;
    // Width is now adaptive: it grows to fit the longest line up to a cap, and any
    // line wider than the inner text area wraps to multiple lines (draw_text_ext).
    var _tw_min = 300;
    var _tw_max = 470;

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);

    var _has_rarity = variable_struct_exists(item, "rarity");
    var _rcol  = _has_rarity ? item_rarity_color(item.rarity) : make_color_rgb(80, 210, 210);
    var _rname = _has_rarity ? item_rarity_name(item.rarity)  : "";

    var _flavor = "";
    if      (variable_struct_exists(item, "effect_desc") && item.effect_desc != "")
        _flavor = item.effect_desc;
    else if (variable_struct_exists(item, "description"))
        _flavor = item.description;

    var _has_unique  = variable_struct_exists(item, "unique_desc")  && item.unique_desc  != "";
    var _has_compare = (compared_item != undefined);
    var _has_flavor  = (_flavor != "");

    // Build the row list. kind: "text" (txt+col, optional right-aligned tag) or "divider".
    var _rows = [];
    array_push(_rows, { kind: "text", txt: item.name, col: _rcol, tag: _rname, tagcol: make_color_rgb(130, 140, 165) });
    array_push(_rows, { kind: "text", txt: variable_struct_exists(item, "slot") ? string_upper(item.slot) : " ",
                        col: make_color_rgb(100, 110, 140), tag: "", tagcol: c_white });
    array_push(_rows, { kind: "text", txt: ui_item_stat_str(item), col: c_white, tag: "", tagcol: c_white });
    if (_has_unique) array_push(_rows, { kind: "text", txt: item.unique_desc, col: make_color_rgb(255, 200, 50), tag: "", tagcol: c_white });
    if (_has_flavor) {
        array_push(_rows, { kind: "divider" });
        array_push(_rows, { kind: "text", txt: _flavor, col: make_color_rgb(110, 120, 145), tag: "", tagcol: c_white });
    }
    if (_has_compare) {
        array_push(_rows, { kind: "divider" });
        array_push(_rows, { kind: "text", txt: "Replaces: " + compared_item.name, col: make_color_rgb(150, 160, 180), tag: "", tagcol: c_white });
        array_push(_rows, { kind: "text", txt: ui_item_stat_str(compared_item), col: make_color_rgb(110, 120, 140), tag: "", tagcol: c_white });
    }

    // Pass 1 — pick the panel width from the widest single-line content (name line
    // also reserves room for the right-aligned rarity tag), clamped to [min, max].
    var _maxw = _tw_min - _pad * 2;
    for (var _ri = 0; _ri < array_length(_rows); _ri++) {
        var _row = _rows[_ri];
        if (_row.kind != "text" || _row.txt == "") continue;
        var _w = string_width(_row.txt);
        if (_row.tag != "") _w += string_width(_row.tag) + 24;
        _maxw = max(_maxw, _w);
    }
    var _tw = clamp(_maxw + _pad * 2, _tw_min, _tw_max);
    var _ww = _tw - _pad * 2;   // inner wrap width

    // Pass 2 — measure height with wrapping applied.
    var _th = _pad * 2;
    for (var _ri = 0; _ri < array_length(_rows); _ri++) {
        var _row = _rows[_ri];
        if (_row.kind == "divider") { _th += 12; continue; }
        _th += (_row.txt == "") ? _lh : string_height_ext(_row.txt, _lh, _ww);
    }

    // Screen-clamp
    if (ttx + _tw > 1270) ttx -= _tw + 24;
    if (ttx < 4)          ttx  = 4;
    if (tty + _th > 710)  tty  = 710 - _th;
    if (tty < 4)          tty  = 4;

    // Panel background
    draw_set_alpha(0.95);
    draw_set_color(make_color_rgb(12, 14, 26));
    draw_rectangle(ttx, tty, ttx + _tw, tty + _th, false);
    draw_set_alpha(1.0);
    draw_set_color(_rcol);
    draw_rectangle(ttx, tty, ttx + _tw, tty + _th, true);
    draw_rectangle(ttx, tty, ttx + _tw, tty + 3, false);

    // Pass 3 — render rows (wrapped via draw_text_ext).
    var _cx = ttx + _pad;
    var _cy = tty + _pad;
    for (var _ri = 0; _ri < array_length(_rows); _ri++) {
        var _row = _rows[_ri];
        if (_row.kind == "divider") {
            draw_set_color(make_color_rgb(50, 55, 80));
            draw_line(_cx, _cy + 6, ttx + _tw - _pad, _cy + 6);
            _cy += 12;
            continue;
        }
        draw_set_color(_row.col);
        draw_text_ext(_cx, _cy, _row.txt, _lh, _ww);
        if (_row.tag != "") {
            draw_set_halign(fa_right);
            draw_set_color(_row.tagcol);
            draw_text(ttx + _tw - _pad, _cy, _row.tag);
            draw_set_halign(fa_left);
        }
        _cy += (_row.txt == "") ? _lh : string_height_ext(_row.txt, _lh, _ww);
    }

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
}

// ---------------------------------------------------------------------------
// ui_draw_hp_bar(x, y, width, height, current_hp, max_hp, label)
// Draws a filled HP bar with a label and "current / max" readout.
// Color zones: green ≥50%, yellow 25–50%, red <25%.
// ---------------------------------------------------------------------------
function ui_draw_hp_bar(x, y, width, height, current_hp, max_hp, label) {
    var ratio = (max_hp > 0) ? clamp(current_hp / max_hp, 0, 1) : 0;

    // Background track
    draw_set_color(c_dkgray);
    draw_rectangle(x, y, x + width, y + height, false);

    // Fill color based on HP ratio
    var fill_color;
    if (ratio >= 0.5) {
        fill_color = c_green;
    } else if (ratio >= 0.25) {
        fill_color = c_yellow;
    } else {
        fill_color = c_red;
    }

    var fill_width = floor(width * ratio);
    if (fill_width > 0) {
        draw_set_color(fill_color);
        draw_rectangle(x, y, x + fill_width, y + height, false);
    }

    // Thin border over the bar
    draw_set_color(c_black);
    draw_rectangle(x, y, x + width, y + height, true);

    // Label (left-aligned, vertically centered on the bar)
    draw_set_halign(fa_left);
    draw_set_valign(fa_middle);
    draw_set_color(c_white);
    draw_text(x + 4, y + height / 2, label);

    // HP readout right-aligned
    draw_set_halign(fa_right);
    draw_text(x + width - 4, y + height / 2, string(current_hp) + " / " + string(max_hp));

    // Reset alignment to safe defaults
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}

// ---------------------------------------------------------------------------
// ui_draw_energy_pips(x, y, current_energy, max_energy)
// Draws energy as a row of small squares.
// Lit pips: bright yellow. Empty pips: dark gray.
// Each pip is 16×16 with a 4px gap between them.
// ---------------------------------------------------------------------------
function ui_draw_energy_pips(x, y, current_energy, max_energy) {
    var pip_size = 16;
    var pip_gap  = 4;

    // Burst AP (from Energy Tonic / Adrenaline Vial / Ley Battery) can push current
    // above the normal cap — draw extra pips so the surplus is visible, tinted orange.
    var pip_count = max(max_energy, current_energy);

    for (var i = 0; i < pip_count; i++) {
        var px = x + i * (pip_size + pip_gap);

        // Fill: lit pips are yellow, burst pips (beyond max) orange, empty dark gray.
        if (i < current_energy) {
            draw_set_color((i >= max_energy) ? make_color_rgb(245, 160, 40) : c_yellow);
        } else {
            draw_set_color(c_dkgray);
        }
        draw_rectangle(px, y, px + pip_size, y + pip_size, false);

        // Border
        draw_set_color(c_black);
        draw_rectangle(px, y, px + pip_size, y + pip_size, true);
    }

    // Label to the right of the pips
    draw_set_color(c_white);
    draw_set_halign(fa_left);
    draw_set_valign(fa_middle);
    var label_x = x + pip_count * (pip_size + pip_gap) + 4;
    draw_text(label_x, y + pip_size / 2, "AP");
    draw_set_valign(fa_top);
}

// ---------------------------------------------------------------------------
// ui_draw_secondary_resource(x, y, current, maximum, resource_name, color)
// Draws a slim labeled bar for Souls / Blood / Preparation.
// The bar fill uses the passed color; background is dark gray.
// ---------------------------------------------------------------------------
function ui_draw_secondary_resource(x, y, current, maximum, resource_name, color) {
    var width  = 250;
    var height = 16;
    var ratio  = (maximum > 0) ? clamp(current / maximum, 0, 1) : 0;

    // Background
    draw_set_color(c_dkgray);
    draw_rectangle(x, y, x + width, y + height, false);

    // Fill
    var fill_width = floor(width * ratio);
    if (fill_width > 0) {
        draw_set_color(color);
        draw_rectangle(x, y, x + fill_width, y + height, false);
    }

    // Border
    draw_set_color(c_black);
    draw_rectangle(x, y, x + width, y + height, true);

    // Resource name and value
    draw_set_color(c_white);
    draw_set_halign(fa_left);
    draw_set_valign(fa_middle);
    draw_text(x + 4, y + height / 2, resource_name);

    draw_set_halign(fa_right);
    draw_text(x + width - 4, y + height / 2, string(current) + " / " + string(maximum));

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}

// ---------------------------------------------------------------------------
// ui_draw_turn_queue(x, y, combat_state)
// Draws the initiative order as a horizontal row of name boxes.
// Active combatant: bright white border. Player boxes: teal. Enemy: orange.
// Names are truncated to 8 characters to fit the box.
// ---------------------------------------------------------------------------
function ui_draw_turn_queue(x, y, combat_state) {
    var box_width  = 80;
    var box_height = 32;
    var box_gap    = 6;

    var count = array_length(combat_state.combatants);

    for (var i = 0; i < count; i++) {
        var c  = combat_state.combatants[i];
        var bx = x + i * (box_width + box_gap);

        // Skip defeated combatants — show a dim slot instead
        if (c.is_defeated) {
            draw_set_alpha(0.3);
        }

        // Box fill — teal for player, orange for enemies
        if (c.is_player) {
            draw_set_color(c_teal);
        } else {
            draw_set_color(c_orange);
        }
        draw_rectangle(bx, y, bx + box_width, y + box_height, false);

        // Border — bright white for the active combatant, black otherwise
        if (i == combat_state.turn_index) {
            draw_set_color(c_white);
        } else {
            draw_set_color(c_black);
        }
        draw_rectangle(bx, y, bx + box_width, y + box_height, true);

        // Name — truncate to 8 chars
        var display_name = string_copy(c.name, 1, 8);
        draw_set_color(c_white);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_text(bx + box_width / 2, y + box_height / 2, display_name);

        draw_set_alpha(1.0);
    }

    // Reset alignment
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}

// ---------------------------------------------------------------------------
// ui_draw_ability_buttons(x, y, ability_array, selected_index, caster)
// Draws a row of ability buttons showing name and energy cost.
// Uncastable abilities are dimmed. Selected ability has a white border.
// Each button: 160×50 with 8px gap.
// ---------------------------------------------------------------------------
function ui_draw_ability_buttons(x, y, ability_array, selected_index, caster) {
    var btn_width  = 160;
    var btn_height = 50;
    var btn_gap    = 8;

    var count = array_length(ability_array);

    for (var i = 0; i < count; i++) {
        var ab = ability_array[i];
        var bx = x + i * (btn_width + btn_gap);
        var castable = ability_can_cast(ab, caster);

        // Per-ability cooldown (Blink / Shadow Step). On cooldown == not usable.
        var _cd = (variable_struct_exists(caster, "ability_cd") && i < array_length(caster.ability_cd))
                  ? caster.ability_cd[i] : 0;

        // Dim uncastable or cooling-down buttons
        if (!castable || _cd > 0) {
            draw_set_alpha(0.45);
        }

        // Button background — dark fill
        draw_set_color(make_color_rgb(40, 40, 55));
        draw_rectangle(bx, y, bx + btn_width, y + btn_height, false);

        // Border — white for selected, gray otherwise
        if (i == selected_index) {
            draw_set_color(c_white);
        } else {
            draw_set_color(c_gray);
        }
        draw_rectangle(bx, y, bx + btn_width, y + btn_height, true);

        // Ability icon — 40×40 badge on the left (inherits the dim alpha above)
        var _icon_sz = 40;
        ui_draw_ability_icon(bx + 5, y + 5, _icon_sz, ab);

        // Ability name (centered in the area right of the icon, upper half).
        // Wraps onto two lines and scales down to fit so long names (e.g.
        // "Adrenaline Rush") stay whole and inside the button.
        var _name_left = bx + 5 + _icon_sz + 3;
        var _name_w    = (bx + btn_width) - _name_left - 4;
        draw_set_color(c_white);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        ui_draw_label_fit(_name_left + (bx + btn_width - _name_left) / 2, y + 17, ab.name, _name_w, 30);

        // Cooldown badge — overrides the AP pips while the ability is recharging.
        if (_cd > 0) {
            draw_set_color(make_color_rgb(120, 160, 255));
            draw_text(bx + btn_width / 2, y + btn_height - 12, "CD " + string(_cd));
            draw_set_alpha(1.0);
            continue;
        }

        // Energy cost pips in bottom half — small 8×8 squares
        var pip_size = 8;
        var pip_gap  = 3;
        var pip_total_width = ab.energy_cost * (pip_size + pip_gap) - pip_gap;
        var pip_start_x = bx + (btn_width - pip_total_width) / 2;
        var pip_y       = y + btn_height - 14;

        for (var p = 0; p < ab.energy_cost; p++) {
            var px = pip_start_x + p * (pip_size + pip_gap);
            // Lit if the caster has enough energy to cover pips up to this one
            if (p < caster.energy) {
                draw_set_color(c_yellow);
            } else {
                draw_set_color(c_dkgray);
            }
            draw_rectangle(px, pip_y, px + pip_size, pip_y + pip_size, false);
        }

        draw_set_alpha(1.0);
    }

    // Reset alignment
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}

// ---------------------------------------------------------------------------
// ui_draw_telegraph_warning(enemy_name, message)
// Draws a red banner sized to its text and centered at y=600 — NOT full screen
// width, so it clears the combat log at the bottom-left.
// Only called when enemy_should_telegraph() returns true for any enemy.
// ---------------------------------------------------------------------------
function ui_draw_telegraph_warning(enemy_name, message) {
    var room_w      = 1280;
    var banner_h    = 36;
    var banner_y    = 600;

    var warning_text = enemy_name + " " + message;

    // Size the banner to the text (centered) instead of spanning the whole screen.
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    var _pad_x = 28;
    var _bw    = string_width(warning_text) + _pad_x * 2;
    var _bx1   = room_w / 2 - _bw / 2;
    var _bx2   = room_w / 2 + _bw / 2;
    var mid_y  = banner_y + banner_h / 2;

    // Semi-transparent dark red backing
    draw_set_alpha(0.88);
    draw_set_color(make_color_rgb(160, 20, 20));
    draw_rectangle(_bx1, banner_y, _bx2, banner_y + banner_h, false);

    // Solid red border
    draw_set_alpha(1.0);
    draw_set_color(c_red);
    draw_rectangle(_bx1, banner_y, _bx2, banner_y + banner_h, true);

    // Warning text — fake bold via a 1px dark-red shadow under white.
    draw_set_color(make_color_rgb(80, 0, 0));
    draw_text(room_w / 2 + 1, mid_y + 1, warning_text);
    draw_set_color(c_white);
    draw_text(room_w / 2, mid_y, warning_text);

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
}

// ---------------------------------------------------------------------------
// ui_draw_combat_log(x, y, width, height, log_array)
// Fills the panel from bottom up, most recent entry at the bottom.
// Each entry reserves height proportional to its estimated wrapped line count
// so wrapped text never overlaps the entry below it.
// Stops drawing when the next entry would reach the top padding boundary.
// ---------------------------------------------------------------------------
function ui_draw_combat_log(x, y, width, height, log_array) {
    var line_h  = 19;
    var padding = 8;

    // Background panel
    draw_set_alpha(0.7);
    draw_set_color(make_color_rgb(15, 15, 25));
    draw_rectangle(x, y, x + width, y + height, false);
    draw_set_alpha(1.0);
    draw_set_color(c_gray);
    draw_rectangle(x, y, x + width, y + height, true);

    var log_count = array_length(log_array);
    if (log_count == 0) return;

    var max_width = width - (padding * 2) - 14;   // leave room for a scrollbar gutter
    // One compact line per entry (truncated, never wrapped) so many fit; this lets
    // the player see far more history at once and pairs with mouse-wheel scrollback.
    var _visible_rows = floor((height - padding * 2) / line_h);

    // Scrollback offset (0 = pinned to newest). Read from the combat controller so
    // the mouse wheel — handled in obj_combat_controller Step — can drive it.
    var _scroll = 0;
    if (instance_exists(obj_combat_controller)) {
        var _cc = instance_find(obj_combat_controller, 0);
        if (variable_instance_exists(_cc, "combat_log_scroll")) {
            var _max_scroll = max(0, log_count - _visible_rows);
            _scroll = clamp(_cc.combat_log_scroll, 0, _max_scroll);
            _cc.combat_log_scroll = _scroll;   // keep it bounded as the log grows
        }
    }

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);

    // Newest at the bottom. Index of the bottom-most visible entry, offset by scroll.
    var _bottom_idx = log_count - 1 - _scroll;
    for (var _row = 0; _row < _visible_rows; _row++) {
        var _idx = _bottom_idx - _row;
        if (_idx < 0) break;
        var _ly = y + height - padding - line_h - _row * line_h;

        // Fade by age relative to the newest visible line
        draw_set_alpha(lerp(1.0, 0.45, min(_row / 8.0, 1.0)));
        draw_set_color(c_white);
        draw_text(x + padding, _ly, ui_truncate(log_array[_idx], max_width));
    }
    draw_set_alpha(1.0);

    // Scroll indicators + a simple scrollbar when there's history to scroll
    if (log_count > _visible_rows) {
        draw_set_halign(fa_right);
        draw_set_color(make_color_rgb(120, 140, 170));
        if (_scroll > 0)                                 draw_text(x + width - 6, y + 2, "▲ older");
        if (_scroll < log_count - _visible_rows)         draw_text(x + width - 6, y + height - 18, "▼ newer");
        draw_set_halign(fa_left);

        // Scrollbar track + thumb on the right gutter
        var _bar_x = x + width - 6;
        draw_set_color(make_color_rgb(40, 45, 60));
        draw_line_width(_bar_x, y + 2, _bar_x, y + height - 2, 3);
        var _track_h = height - 4;
        var _thumb_h = max(12, _track_h * (_visible_rows / log_count));
        // _scroll 0 = bottom; map to a thumb position (bottom = newest)
        var _frac    = (log_count - _visible_rows) > 0 ? (_scroll / (log_count - _visible_rows)) : 0;
        var _thumb_y = (y + height - 2 - _thumb_h) - _frac * (_track_h - _thumb_h);
        draw_set_color(make_color_rgb(110, 130, 160));
        draw_line_width(_bar_x, _thumb_y, _bar_x, _thumb_y + _thumb_h, 3);
    }
}

// ---------------------------------------------------------------------------
// ui_draw_ability_tooltip(x, anchor_bottom, ability, caster)
// Draws a tooltip panel for the currently selected ability (name, costs,
// damage, effect, accuracy). Width is fixed (320); HEIGHT is measured from the
// content and the panel is anchored by its BOTTOM at anchor_bottom, growing
// UPWARD. This guarantees long wrapped descriptions never spill below the panel
// onto the ability button row. The tooltip is on the GUI layer (drawn over the
// enemy sprites), so growing up simply covers empty arena space.
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// ui_truncate(str, max_w)
// Returns str clipped (with an ellipsis) to fit within max_w pixels at the
// current draw font. Keeps single-line labels from overflowing their box.
// ---------------------------------------------------------------------------
function ui_truncate(str, max_w) {
    if (string_width(str) <= max_w) return str;
    var _s = str;
    while (string_length(_s) > 1 && string_width(_s + "…") > max_w) {
        _s = string_copy(_s, 1, string_length(_s) - 1);
    }
    return _s + "…";
}

// ---------------------------------------------------------------------------
// ui_draw_label_fit(cx, cy, str, box_w, box_h)
// Draws a label centered on (cx, cy) that always fits inside box_w × box_h: first
// tries one line at native scale; if too wide it wraps onto two balanced lines
// (split on the space nearest the middle) and uniformly scales them down to fit
// both the width and height. A single long word with no space is just scaled.
// Caller should set halign=center / valign=middle first (draw_text_transformed
// honours them). Used for ability button labels so long names like
// "Adrenaline Rush" stay readable and inside the button.
// ---------------------------------------------------------------------------
function ui_draw_label_fit(cx, cy, str, box_w, box_h) {
    var _w  = string_width(str);
    var _lh = string_height(str);

    // One line at native scale.
    if (_w <= box_w && _lh <= box_h) {
        draw_text(cx, cy, str);
        return;
    }

    // Find the space nearest the middle to split into two balanced lines.
    var _len   = string_length(str);
    var _best  = -1;
    var _bestd = _len;
    for (var _i = 1; _i <= _len; _i++) {
        if (string_char_at(str, _i) == " ") {
            var _d = abs(_i - _len / 2);
            if (_d < _bestd) { _bestd = _d; _best = _i; }
        }
    }

    // No space — single long word: scale the one line to fit.
    if (_best <= 0) {
        var _s1 = min(box_w / max(1, _w), box_h / max(1, _lh), 1);
        draw_text_transformed(cx, cy, str, _s1, _s1, 0);
        return;
    }

    // Two lines, scaled to fit width and the (two-line) height.
    var _line1 = string_copy(str, 1, _best - 1);
    var _line2 = string_copy(str, _best + 1, _len - _best);
    var _w2 = max(string_width(_line1), string_width(_line2));
    var _h2 = _lh * 2;
    var _s  = min(box_w / max(1, _w2), box_h / max(1, _h2), 1);
    var _half = (_lh * _s) / 2;
    draw_text_transformed(cx, cy - _half, _line1, _s, _s, 0);
    draw_text_transformed(cx, cy + _half, _line2, _s, _s, 0);
}

// ---------------------------------------------------------------------------
// ui_draw_sprite_cover(spr, subimg, x, y, w, h, alpha)
// Draws a sprite to exactly fill the (x,y,w,h) box WITHOUT distorting it:
// scales uniformly to cover the box and crops the centered overflow (CSS
// "object-fit: cover"). Use for portraits/art instead of draw_sprite_stretched,
// which squashes the image to the box aspect ratio.
// ---------------------------------------------------------------------------
function ui_draw_sprite_cover(spr, subimg, x, y, w, h, alpha) {
    if (!sprite_exists(spr)) return;
    var _sw = sprite_get_width(spr);
    var _sh = sprite_get_height(spr);
    if (_sw <= 0 || _sh <= 0) return;
    var _scale = max(w / _sw, h / _sh);       // cover: largest scale that fills the box
    var _src_w = min(_sw, w / _scale);         // source sub-rect that maps onto the box
    var _src_h = min(_sh, h / _scale);
    var _src_l = (_sw - _src_w) * 0.5;         // centered crop
    var _src_t = (_sh - _src_h) * 0.5;
    // draw_sprite_part_ext positions by the part's top-left and ignores origin.
    draw_sprite_part_ext(spr, subimg, _src_l, _src_t, _src_w, _src_h, x, y, _scale, _scale, c_white, alpha);
}

function ui_draw_ability_tooltip(x, anchor_bottom, ability, caster) {
    var panel_w   = 320;
    var padding   = 14;
    var line_h    = 22;
    var _ew       = panel_w - padding * 2;

    // --- Pre-compute the variable-content lines so the panel can be sized to fit
    //     exactly and anchored by its bottom edge (see header). Mirror these flags
    //     in the height sum and the body draw so all three stay consistent. ---
    var _ac_lbl  = ability_attack_class_label(ability_attack_class(ability));
    var _is_aoe  = variable_struct_exists(ability, "is_aoe") && ability.is_aoe;
    var _has_dmg = variable_struct_exists(ability, "base_damage") && ability.base_damage > 0;

    var effect_str = ability_effect_full(ability);
    var _ac_tag = ability_attack_class_tag(ability);
    if (_ac_tag != "") effect_str = (effect_str != "") ? (effect_str + " " + _ac_tag) : _ac_tag;
    var _has_effect = (effect_str != "");
    var _effect_h   = _has_effect ? (string_height_ext(effect_str, line_h, _ew) + 4) : 0;

    // Sum heights in the SAME order the body draws them.
    var panel_h = padding;                 // top pad
    panel_h += line_h + 4;                  // name
    panel_h += line_h;                      // AP / resource cost
    if (_ac_lbl != "") panel_h += line_h;   // attack-class label
    if (_is_aoe)       panel_h += line_h;   // AoE indicator
    panel_h += line_h / 2;                  // blank gap
    if (_has_dmg)      panel_h += line_h;   // damage
    panel_h += _effect_h;                   // effect description (wrapped)
    panel_h += line_h;                      // accuracy / always-hits
    panel_h += padding;                     // bottom pad

    var _py   = anchor_bottom - panel_h;    // bottom-anchored: grows upward
    var cur_y = _py + padding;

    // --- Panel background and border ---
    draw_set_alpha(0.92);
    draw_set_color(make_color_rgb(20, 25, 40));
    draw_rectangle(x, _py, x + panel_w, _py + panel_h, false);
    draw_set_alpha(1.0);
    draw_set_color(make_color_rgb(80, 120, 160));
    draw_rectangle(x, _py, x + panel_w, _py + panel_h, true);
    ui_draw_gothic_frame(x, _py, x + panel_w, _py + panel_h);   // ornate gothic border

    var tx = x + padding;

    // --- Ability icon in the top-right corner of the panel ---
    draw_set_alpha(1.0);
    ui_draw_ability_icon(x + panel_w - padding - 36, _py + padding, 36, ability);

    // --- Line 1: Ability name (fake bold) ---
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_color(make_color_rgb(40, 50, 70));
    draw_text(tx + 1, cur_y + 1, ability.name);
    draw_set_color(c_white);
    draw_text(tx, cur_y, ability.name);
    cur_y += line_h + 4;

    // --- Line 2: AP cost + secondary resource cost ---
    var cost_str = "AP: " + string(ability.energy_cost);
    if (variable_struct_exists(ability, "secondary_cost") && ability.secondary_cost > 0) {
        var sec_label = "Resource";
        if (variable_struct_exists(caster, "souls")) {
            sec_label = "Souls";
        } else if (variable_struct_exists(caster, "blood")) {
            sec_label = "Blood";
        } else if (variable_struct_exists(caster, "preparation")) {
            sec_label = "Prep";
        }
        cost_str += " | " + sec_label + ": " + string(ability.secondary_cost);
    }
    draw_set_color(c_yellow);
    draw_text(tx, cur_y, cost_str);
    cur_y += line_h;

    // --- Attack class (melee/ranged x attack/spell) — drives root/silence ---
    if (_ac_lbl != "") {
        draw_set_color(make_color_rgb(150, 175, 210));
        draw_text(tx, cur_y, _ac_lbl);
        cur_y += line_h;
    }

    // --- AoE targeting indicator ---
    if (_is_aoe) {
        if (trait_active("Focused Power")) {
            draw_set_color(make_color_rgb(255, 150, 60));
            draw_text(tx, cur_y, "Targets: SELECTED (Focused Power +50%)");
        } else {
            draw_set_color(make_color_rgb(255, 120, 120));
            draw_text(tx, cur_y, "Targets: ALL enemies");
        }
        cur_y += line_h;
    }

    // --- Line 3: Blank gap ---
    cur_y += line_h / 2;

    // --- Line 4: Damage ---
    if (_has_dmg) {
        var dmg_type_str = "physical";
        if (variable_struct_exists(ability, "damage_type")) {
            if (ability.damage_type == 1) {
                dmg_type_str = "elemental";
            } else if (ability.damage_type == 3) {
                dmg_type_str = "blood";
            } else if (ability.damage_type == 2) {
                dmg_type_str = "drain";
            }
        }
        draw_set_color(c_white);
        draw_text(tx, cur_y, "Damage: " + string(ability.base_damage) + " (" + dmg_type_str + ")");
        cur_y += line_h;
    }

    // --- Line 5: Effect description ---
    // Generated from the ability's live fields (ability_effect_full, computed at the
    // top with the attack-class tag appended), so the text auto-updates with
    // progression instead of being hand-written per ability.
    if (_has_effect) {
        draw_set_color(c_white);
        draw_text_ext(tx, cur_y, effect_str, line_h, _ew);
        cur_y += string_height_ext(effect_str, line_h, _ew) + 4;
    }

    // --- Line 6: Guaranteed hit indicator ---
    if (variable_struct_exists(ability, "guaranteed_hit") && ability.guaranteed_hit) {
        draw_set_color(c_lime);
        draw_text(tx, cur_y, "Always hits");
        cur_y += line_h;

    // --- Line 7: Accuracy (only when not guaranteed) ---
    } else {
        var dex    = variable_struct_exists(caster.stats, "DEX") ? caster.stats.DEX : 0;
        var acc    = clamp(ability.base_acc + dex * 3, 0, 95);
        draw_set_color(c_ltgray);
        draw_text(tx, cur_y, "Accuracy: " + string(acc) + "%");
    }

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
}

// ---------------------------------------------------------------------------
// ui_draw_combat_hud(combat_state, player, ability_array, selected_ability_index, log_array)
// Master draw function — calls all component functions at their correct positions.
//
// Layout (1280×720):
//   Top-left       Player HP bar         (20,  20) w250 h24
//   Below HP       Energy pips           (20,  56)
//   Below energy   Secondary resource    (20,  90) w250 h16
//   Top-center     Turn queue            (400, 10)
//   Bottom-center  Ability buttons       (160, 640)
//   Bottom-left    Combat log            (20,  200) w440 h280
//   Lower-right    Ability tooltip       x940 w320, bottom-anchored y630 (auto-h)
//   Top overlay    Telegraph warning     (full-width, only when active)
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// ui_boon_style(id) — visual style for a boon id: short abbreviation + badge
// color. Single source shared by the combat strip and (names only) the menu.
// Falls back to a neutral badge for unknown ids so new boons still render.
// ---------------------------------------------------------------------------
function ui_boon_style(id) {
    switch (id) {
        case "bloodlust":   return { abbr:"DMG",   col:make_color_rgb(200,  70,  60) };
        case "ironhide":    return { abbr:"HP+",   col:make_color_rgb(110, 130, 160) };
        case "duelist":     return { abbr:"CRIT",  col:make_color_rgb(220, 180,  70) };
        case "vampirism":   return { abbr:"LIFE",  col:make_color_rgb(180,  50,  90) };
        case "warding":     return { abbr:"WARD",  col:make_color_rgb( 80, 140, 200) };
        case "greed":       return { abbr:"GOLD",  col:make_color_rgb(210, 180,  60) };
        case "runic":       return { abbr:"DUST",  col:make_color_rgb(150, 110, 200) };
        case "executioner": return { abbr:"EXEC",  col:make_color_rgb(180,  60,  50) };
        case "aegis":       return { abbr:"AEGIS", col:make_color_rgb( 90, 170, 180) };
        case "glasscannon": return { abbr:"GLASS", col:make_color_rgb(220, 110,  70) };
        default:            return { abbr:"BOON",  col:make_color_rgb(150, 150, 170) };
    }
}

// ---------------------------------------------------------------------------
// ui_draw_active_boons(x, y) — vertical "BOONS" strip for the combat HUD.
// Boons are run-scoped (no per-turn duration) so this is a static legend:
// an abbr-badge + the boon's name per active boon. No-op when none active.
// ---------------------------------------------------------------------------
function ui_draw_active_boons(x, y) {
    if (!variable_global_exists("run_boons")) return;
    var _n = array_length(global.run_boons);
    if (_n == 0) return;

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
    draw_set_color(make_color_rgb(150, 140, 110));
    draw_text_transformed(x, y, "BOONS", 0.72, 0.72, 0);

    var _ry = y + 16;
    for (var _i = 0; _i < _n; _i++) {
        var _b = boon_get(global.run_boons[_i]);
        if (_b == undefined) continue;
        var _st = ui_boon_style(global.run_boons[_i]);

        // colored badge with short code
        draw_set_alpha(0.9);
        draw_set_color(_st.col);
        draw_roundrect(x, _ry, x + 40, _ry + 14, false);
        draw_set_alpha(1.0);
        draw_set_color(make_color_rgb(10, 10, 18));
        draw_roundrect(x, _ry, x + 40, _ry + 14, true);
        draw_set_color(c_white);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_text_transformed(x + 20, _ry + 7, _st.abbr, 0.6, 0.6, 0);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);

        // boon name to the right of the badge
        draw_set_color(make_color_rgb(200, 205, 215));
        draw_text_transformed(x + 46, _ry + 1, _b.name, 0.72, 0.72, 0);

        _ry += 18;
    }

    draw_set_alpha(1.0);
    draw_set_color(c_white);
}

// ---------------------------------------------------------------------------
// ui_curse_style(id) — short badge code + color for an active curse.
// Falls back to a neutral red badge for unknown ids.
// ---------------------------------------------------------------------------
function ui_curse_style(id) {
    switch (id) {
        case "frail":      return { abbr:"FRAIL", col:make_color_rgb(150, 110, 120) };
        case "famine":     return { abbr:"FMNE",  col:make_color_rgb(160, 130,  90) };
        case "exposed":    return { abbr:"EXPO",  col:make_color_rgb(200,  90,  80) };
        case "bloodprice": return { abbr:"BLD",   col:make_color_rgb(180,  40,  60) };
        case "savagery":   return { abbr:"SVG",   col:make_color_rgb(190,  70,  60) };
        case "withered":   return { abbr:"WTHR",  col:make_color_rgb(120, 130, 110) };
        case "doom":       return { abbr:"DOOM",  col:make_color_rgb(150,  50,  60) };
        case "damnation":  return { abbr:"DMN",   col:make_color_rgb(170,  50,  70) };
        case "ruin":       return { abbr:"RUIN",  col:make_color_rgb(140,  60,  70) };
        case "devilspact": return { abbr:"PACT",  col:make_color_rgb(190,  40,  50) };
        default:           return { abbr:"CURSE", col:make_color_rgb(170,  70,  80) };
    }
}

// ---------------------------------------------------------------------------
// ui_draw_active_curses(x, y) — vertical "CURSES" strip for the combat HUD.
// Mirrors ui_draw_active_boons (static legend; curses are run-scoped). No-op
// when none active. Returns the next free y so callers can stack panels.
// ---------------------------------------------------------------------------
function ui_draw_active_curses(x, y) {
    if (!variable_global_exists("run_curses")) return y;
    var _n = array_length(global.run_curses);
    if (_n == 0) return y;

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
    draw_set_color(make_color_rgb(170, 90, 90));
    draw_text_transformed(x, y, "CURSES", 0.72, 0.72, 0);

    var _ry = y + 16;
    for (var _i = 0; _i < _n; _i++) {
        var _c = curse_get(global.run_curses[_i]);
        if (_c == undefined) continue;
        var _st = ui_curse_style(global.run_curses[_i]);

        draw_set_alpha(0.9);
        draw_set_color(_st.col);
        draw_roundrect(x, _ry, x + 40, _ry + 14, false);
        draw_set_alpha(1.0);
        draw_set_color(make_color_rgb(10, 10, 18));
        draw_roundrect(x, _ry, x + 40, _ry + 14, true);
        draw_set_color(c_white);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_text_transformed(x + 20, _ry + 7, _st.abbr, 0.6, 0.6, 0);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);

        draw_set_color(make_color_rgb(215, 180, 185));
        draw_text_transformed(x + 46, _ry + 1, _c.name, 0.72, 0.72, 0);

        _ry += 18;
    }

    draw_set_alpha(1.0);
    draw_set_color(c_white);
    return _ry + 6;
}

// ---------------------------------------------------------------------------
// ui_draw_settings_overlay() — audio settings panel (Music + SFX sliders).
// Reads global.music_volume / global.sfx_volume / global.settings_cursor (see
// the audio_settings_* helpers in scr_stats). Called from the title + hub when
// global.settings_open. Draw-only; input is handled by audio_settings_handle_input.
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// ui_draw_pause_menu() — Resume / Settings / Quit to Title overlay. Drawn by each
// room controller (the persistent game_controller's Draw GUI doesn't fire). When
// the Settings sub-screen is open it is drawn instead (by ui_draw_settings_overlay).
// Geometry MUST match pause_menu_step()'s mouse hit-testing in scr_stats.
// ---------------------------------------------------------------------------
function ui_draw_pause_menu() {
    if (!variable_global_exists("pause_open") || !global.pause_open) return;
    // While Settings is open over the pause menu, let the settings overlay own the screen.
    if (variable_global_exists("settings_open") && global.settings_open) return;

    // Dim
    draw_set_alpha(0.72);
    draw_set_color(make_color_rgb(6, 8, 14));
    draw_rectangle(0, 0, 1280, 720, false);
    draw_set_alpha(1.0);

    // Panel
    var _pw = 360, _ph = 300, _px = 640 - _pw / 2, _py = 210;
    draw_set_color(make_color_rgb(20, 22, 34));
    draw_rectangle(_px, _py, _px + _pw, _py + _ph, false);
    draw_set_color(make_color_rgb(90, 110, 160));
    draw_rectangle(_px, _py, _px + _pw, _py + _ph, true);

    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_color(c_white);
    draw_text_transformed(640, _py + 22, "Paused", 1.4, 1.4, 0);

    var _labels  = ["Resume", "Settings", "Quit to Title"];
    var _cur     = global.pause_cursor;
    var _row_h   = 56, _first_y = 312, _bx0 = 490, _bx1 = 790;
    for (var _r = 0; _r < 3; _r++) {
        var _ry = _first_y + _r * _row_h;
        var _on = (_r == _cur);
        draw_set_color(_on ? make_color_rgb(45, 55, 86) : make_color_rgb(26, 28, 40));
        draw_rectangle(_bx0, _ry, _bx1, _ry + 44, false);
        draw_set_color(_on ? make_color_rgb(120, 160, 230) : make_color_rgb(60, 66, 90));
        draw_rectangle(_bx0, _ry, _bx1, _ry + 44, true);
        draw_set_color(_on ? c_white : make_color_rgb(180, 188, 205));
        draw_text(640, _ry + 12, _labels[_r]);
    }

    // Controls legend — auto-scaled to fit inside the panel's inner width so it can
    // never spill past the side borders (panel is only _pw wide). Centered at x640,
    // and kept above the panel's bottom edge (_py + _ph).
    var _legend    = "W/S: Navigate    Enter: Select    Esc: Resume";
    var _legend_pad = 24;
    var _legend_sc  = min(1.0, (_pw - _legend_pad) / max(1, string_width(_legend)));
    var _legend_y   = _py + _ph - 26;
    draw_set_color(make_color_rgb(110, 118, 140));
    draw_text_transformed(640, _legend_y, _legend, _legend_sc, _legend_sc, 0);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
}

// ---------------------------------------------------------------------------
// ui_draw_tutorial_tip() — contextual onboarding coach-mark (see
// SYSTEMS_ONBOARDING.md). Draws a dimmed backdrop + a gothic-framed tip box for
// global.tutorial_active. Body is width-constrained (draw_text_ext) so it can't
// overflow the box; box height adapts to the body. No-op when no tip is active.
// Call LAST in a surface's Draw so it sits on top; input handled by tutorial_dismiss.
// ---------------------------------------------------------------------------
function ui_draw_tutorial_tip() {
    if (!tutorial_is_active()) return;
    var _t = tutorial_get(global.tutorial_active);
    if (_t == undefined) { global.tutorial_active = ""; return; }

    // Dim the screen behind the tip.
    draw_set_alpha(0.78);
    draw_set_color(make_color_rgb(6, 8, 14));
    draw_rectangle(0, 0, 1280, 720, false);
    draw_set_alpha(1.0);

    var _bw   = 660;
    var _wrap = _bw - 80;            // body wrap width (inside L/R padding)

    draw_set_halign(fa_center);
    draw_set_valign(fa_top);

    // Size the box to the wrapped body so long tips never overflow.
    var _body_h = string_height_ext(_t.body, 22, _wrap);
    var _bh = 72 + _body_h + 52;     // title band + body + footer band
    var _bx = 640 - _bw / 2;
    var _by = 360 - _bh / 2;

    // Panel
    draw_set_color(make_color_rgb(18, 20, 30));
    draw_rectangle(_bx, _by, _bx + _bw, _by + _bh, false);

    // Title
    draw_set_color(make_color_rgb(228, 200, 130));
    draw_text_transformed(640, _by + 22, _t.title, 1.25, 1.25, 0);

    // Divider under the title
    draw_set_color(make_color_rgb(70, 64, 48));
    draw_line(_bx + 30, _by + 60, _bx + _bw - 30, _by + 60);

    // Body — wrapped + centered inside the box
    draw_set_color(make_color_rgb(205, 210, 222));
    draw_text_ext(640, _by + 74, _t.body, 22, _wrap);

    // Footer hint
    draw_set_color(make_color_rgb(120, 128, 150));
    draw_text(640, _by + _bh - 30, "Press any key or click to continue");

    // Ornate gothic rim (surrounds the box outward; box is centered with screen room).
    ui_draw_gothic_frame(_bx, _by, _bx + _bw, _by + _bh, 20);

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
}

function ui_draw_settings_overlay() {
    audio_settings_init();
    video_settings_init();

    // Dim the screen behind the panel
    draw_set_alpha(0.78);
    draw_set_color(make_color_rgb(6, 8, 14));
    draw_rectangle(0, 0, 1280, 720, false);
    draw_set_alpha(1.0);

    // Panel (tall enough for: Music, SFX, Fullscreen, Tutorial Tips, Reset Tutorial)
    var _pw = 560, _ph = 452;
    var _px = 640 - _pw / 2;
    var _py = 360 - _ph / 2;
    draw_set_color(make_color_rgb(18, 22, 36));
    draw_rectangle(_px, _py, _px + _pw, _py + _ph, false);
    draw_set_color(make_color_rgb(80, 140, 220));
    draw_rectangle(_px, _py, _px + _pw, _py + _ph, true);

    // Title
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_color(c_white);
    draw_text_transformed(640, _py + 26, "SETTINGS", 1.4, 1.4, 0);

    var _row_y  = _py + 100;
    var _row_h  = 72;
    var _bar_x  = _px + 200;
    var _bar_w  = 280;
    var _bar_h  = 18;

    // --- Two slider rows: Music, SFX ---
    var _labels = ["Music", "Sound Effects"];
    var _vols   = [global.music_volume, global.sfx_volume];

    for (var _i = 0; _i < 2; _i++) {
        var _ry  = _row_y + _i * _row_h;
        var _sel = (global.settings_cursor == _i);

        // Selection highlight
        if (_sel) {
            draw_set_alpha(0.20);
            draw_set_color(make_color_rgb(80, 140, 220));
            draw_rectangle(_px + 20, _ry - 14, _px + _pw - 20, _ry + 30, false);
            draw_set_alpha(1.0);
        }

        // Label
        draw_set_halign(fa_left);
        draw_set_valign(fa_middle);
        draw_set_color(_sel ? c_white : make_color_rgb(170, 180, 200));
        draw_text(_px + 40, _ry + 8, (_sel ? "> " : "  ") + _labels[_i]);

        // Slider track
        var _by = _ry + 2;
        draw_set_color(make_color_rgb(35, 42, 60));
        draw_rectangle(_bar_x, _by, _bar_x + _bar_w, _by + _bar_h, false);
        // Slider fill
        var _fill = floor(_bar_w * clamp(_vols[_i], 0, 1));
        draw_set_color(_sel ? make_color_rgb(90, 170, 235) : make_color_rgb(60, 110, 150));
        if (_fill > 0) draw_rectangle(_bar_x, _by, _bar_x + _fill, _by + _bar_h, false);
        // Track border
        draw_set_color(make_color_rgb(70, 85, 110));
        draw_rectangle(_bar_x, _by, _bar_x + _bar_w, _by + _bar_h, true);

        // Percentage
        draw_set_halign(fa_left);
        draw_set_color(c_white);
        draw_text(_bar_x + _bar_w + 16, _by + _bar_h / 2, string(round(_vols[_i] * 100)) + "%");
    }

    // --- Third row: Fullscreen toggle ---
    var _fry = _row_y + 2 * _row_h;
    var _fsel = (global.settings_cursor == 2);
    if (_fsel) {
        draw_set_alpha(0.20);
        draw_set_color(make_color_rgb(80, 140, 220));
        draw_rectangle(_px + 20, _fry - 14, _px + _pw - 20, _fry + 30, false);
        draw_set_alpha(1.0);
    }
    draw_set_halign(fa_left);
    draw_set_valign(fa_middle);
    draw_set_color(_fsel ? c_white : make_color_rgb(170, 180, 200));
    draw_text(_px + 40, _fry + 8, (_fsel ? "> " : "  ") + "Fullscreen");

    // On/Off pill
    var _on   = global.fullscreen;
    var _pill_x = _bar_x;
    var _pill_y = _fry + 2;
    var _pill_w = 92;
    var _pill_h = _bar_h + 4;
    draw_set_color(_on ? make_color_rgb(50, 130, 90) : make_color_rgb(45, 50, 66));
    draw_rectangle(_pill_x, _pill_y, _pill_x + _pill_w, _pill_y + _pill_h, false);
    draw_set_color(_fsel ? make_color_rgb(120, 190, 255) : make_color_rgb(70, 85, 110));
    draw_rectangle(_pill_x, _pill_y, _pill_x + _pill_w, _pill_y + _pill_h, true);
    draw_set_halign(fa_center);
    draw_set_color(c_white);
    draw_text(_pill_x + _pill_w / 2, _pill_y + _pill_h / 2, _on ? "ON" : "OFF");
    draw_set_halign(fa_left);
    draw_set_color(make_color_rgb(140, 150, 170));
    draw_text(_pill_x + _pill_w + 16, _pill_y + _pill_h / 2, "(F11)");

    // --- Fourth row: Tutorial Tips on/off toggle ---
    var _tut_on = (!variable_global_exists("tutorial_enabled")) || global.tutorial_enabled;
    var _try    = _fry + 56;
    var _tsel   = (global.settings_cursor == 3);
    if (_tsel) {
        draw_set_alpha(0.20);
        draw_set_color(make_color_rgb(80, 140, 220));
        draw_rectangle(_px + 20, _try - 14, _px + _pw - 20, _try + 30, false);
        draw_set_alpha(1.0);
    }
    draw_set_halign(fa_left);
    draw_set_valign(fa_middle);
    draw_set_color(_tsel ? c_white : make_color_rgb(170, 180, 200));
    draw_text(_px + 40, _try + 8, (_tsel ? "> " : "  ") + "Tutorial Tips");

    var _tpx = _bar_x;
    var _tpy = _try + 2;
    var _tpw = 92;
    var _tph = _bar_h + 4;
    draw_set_color(_tut_on ? make_color_rgb(50, 130, 90) : make_color_rgb(45, 50, 66));
    draw_rectangle(_tpx, _tpy, _tpx + _tpw, _tpy + _tph, false);
    draw_set_color(_tsel ? make_color_rgb(120, 190, 255) : make_color_rgb(70, 85, 110));
    draw_rectangle(_tpx, _tpy, _tpx + _tpw, _tpy + _tph, true);
    draw_set_halign(fa_center);
    draw_set_color(c_white);
    draw_text(_tpx + _tpw / 2, _tpy + _tph / 2, _tut_on ? "ON" : "OFF");

    // --- Fifth row: Reset Tutorial (re-show every tip) ---
    var _rry  = _try + 48;
    var _rsel = (global.settings_cursor == 4);
    if (_rsel) {
        draw_set_alpha(0.20);
        draw_set_color(make_color_rgb(80, 140, 220));
        draw_rectangle(_px + 20, _rry - 14, _px + _pw - 20, _rry + 30, false);
        draw_set_alpha(1.0);
    }
    draw_set_halign(fa_left);
    draw_set_valign(fa_middle);
    draw_set_color(_rsel ? c_white : make_color_rgb(170, 180, 200));
    draw_text(_px + 40, _rry + 8, (_rsel ? "> " : "  ") + "Reset Tutorial");
    draw_set_color(make_color_rgb(140, 150, 170));
    draw_text(_bar_x, _rry + 8, "[ Enter ] Re-show all tips");

    // Reset confirmation flash
    if (variable_global_exists("settings_reset_flash") && global.settings_reset_flash > 0) {
        draw_set_halign(fa_center);
        draw_set_color(make_color_rgb(120, 200, 140));
        draw_text(640, _py + _ph - 52, "Tutorial reset — tips will show again.");
    }

    // Footer hint
    draw_set_halign(fa_center);
    draw_set_color(make_color_rgb(150, 160, 185));
    draw_text(640, _py + _ph - 28, "W/S: Select    A/D or ←/→: Adjust / Toggle / Enter    Esc/O: Close");

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
}

function ui_draw_combat_hud(combat_state, player, ability_array, selected_ability_index, log_array) {

    // --- Turn queue (top-center) ---
    ui_draw_turn_queue(400, 10, combat_state);

    // --- Player HP bar (top-left) ---
    ui_draw_hp_bar(20, 20, 250, 24, player.HP, player.max_HP, "HP");

    // --- Energy pips (below HP bar) ---
    ui_draw_energy_pips(20, 56, player.energy, 3);

    // --- Secondary resource bar (below energy pips) ---
    // Determine which resource this class uses and pick a matching color
    var res_name  = "";
    var res_cur   = 0;
    var res_max   = 0;
    var res_color = c_white;

    if (variable_struct_exists(player, "souls")) {
        res_name  = "Souls";
        res_cur   = player.souls;
        res_max   = player.souls_max;
        res_color = c_purple;
    } else if (variable_struct_exists(player, "blood")) {
        res_name  = "Blood";
        res_cur   = player.blood;
        res_max   = player.blood_max;
        res_color = c_red;
    } else if (variable_struct_exists(player, "preparation")) {
        res_name  = "Preparation";
        res_cur   = player.preparation;
        res_max   = player.preparation_max;
        res_color = c_aqua;
    }

    if (res_name != "") {
        ui_draw_secondary_resource(20, 90, res_cur, res_max, res_name, res_color);
    }

    // --- Run level and XP bar (below secondary resource) ---
    // "Lv X" label at y=115; XP bar at y=140 to clear the label's descenders.
    if (variable_global_exists("run_level")) {
        draw_set_color(c_white);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        draw_text(20, 115, "Lv " + string(global.run_level));

        var _xb  = 20;
        var _xbw = 250;
        var _xbh = 8;
        var _xby = 140;

        if (global.run_level < 15 && variable_global_exists("run_xp")) {
            var _xp_lo    = xp_threshold(global.run_level);
            var _xp_hi    = xp_threshold(global.run_level + 1);
            var _xp_ratio = (_xp_hi > _xp_lo)
                            ? clamp((global.run_xp - _xp_lo) / (_xp_hi - _xp_lo), 0, 1)
                            : 1;
            draw_set_color(make_color_rgb(35, 45, 55));
            draw_rectangle(_xb, _xby, _xb + _xbw, _xby + _xbh, false);
            draw_set_color(make_color_rgb(60, 180, 200));
            var _xfill = floor(_xbw * _xp_ratio);
            if (_xfill > 0) draw_rectangle(_xb, _xby, _xb + _xfill, _xby + _xbh, false);
            draw_set_color(make_color_rgb(50, 70, 80));
            draw_rectangle(_xb, _xby, _xb + _xbw, _xby + _xbh, true);
        } else if (global.run_level >= 15) {
            // Full golden bar at max level — no text overlap
            draw_set_color(make_color_rgb(160, 125, 25));
            draw_rectangle(_xb, _xby, _xb + _xbw, _xby + _xbh, false);
            draw_set_color(make_color_rgb(80, 70, 90));
            draw_rectangle(_xb, _xby, _xb + _xbw, _xby + _xbh, true);
            draw_set_halign(fa_center);
            draw_set_color(make_color_rgb(255, 200, 50));
            draw_text_transformed(_xb + _xbw * 0.5, _xby + _xbh * 0.5 + 1, "MAX", 0.75, 0.75, 0);
            draw_set_halign(fa_left);
        }
    }

    // --- Active player buff icons (below XP bar) ---
    var _pbuffs = [];
    if (variable_struct_exists(player, "iron_skin_duration") && player.iron_skin_duration > 0) {
        array_push(_pbuffs, {
            label:    "IS",
            color:    make_color_rgb(80, 140, 220),
            duration: player.iron_skin_duration
        });
    }
    if (variable_struct_exists(player, "bloodthorn_active") && player.bloodthorn_active) {
        array_push(_pbuffs, {
            label:    "BT",
            color:    make_color_rgb(190, 55, 55),
            duration: player.bloodthorn_duration
        });
    }
    if (variable_struct_exists(player, "is_untargetable") && player.is_untargetable) {
        array_push(_pbuffs, {
            label:    "BLK",
            color:    make_color_rgb(70, 75, 210),
            duration: player.untargetable_turns
        });
    }
    if (variable_struct_exists(player, "shadow_step_active") && player.shadow_step_active) {
        array_push(_pbuffs, {
            label:    "SS",
            color:    make_color_rgb(45, 155, 65),
            duration: 1
        });
    }
    // Typed debuffs/statuses applied to the player (poison, Sight Clouded/blind,
    // weaken, stun, …) live in player.status_effects[] — surface them here too so
    // the player can actually see what's afflicting them and for how long.
    if (variable_struct_exists(player, "status_effects")) {
        var _pstat = status_icons_from(player.status_effects);
        for (var _psi = 0; _psi < array_length(_pstat); _psi++) array_push(_pbuffs, _pstat[_psi]);
    }
    if (array_length(_pbuffs) > 0) {
        ui_draw_status_icon_row(20, 148, _pbuffs);
    }

    // --- Active run boons + curses (left column, below the per-combat buff row) ---
    // Boons occupy a header (16px) + 18px per entry; stack curses just beneath them.
    ui_draw_active_boons(20, 185);
    var _boon_n = variable_global_exists("run_boons") ? array_length(global.run_boons) : 0;
    var _curse_y = 185 + ((_boon_n > 0) ? (16 + 18 * _boon_n + 8) : 0);
    ui_draw_active_curses(20, _curse_y);

    // --- Ability buttons (bottom-center) ---
    ui_draw_ability_buttons(160, 660, ability_array, selected_ability_index, player);

    // --- Combat log (bottom strip — freed left zone for character sprites) ---
    ui_draw_combat_log(20, 490, 780, 140, log_array);

    // --- Ability tooltip (lower-right) ---
    // Bottom-anchored at y630 (a 30px gap above the ability button row + C/Items
    // button, both at y660+) and sized to its content, growing UPWARD. This keeps
    // the wrapped effect text well clear of the Poison Dart (x832-992) button, no
    // matter how long the description. Left edge x940 (width 320 => right edge
    // x1260), right of the combat log (x<=800).
    var _sel_ab = ability_array[selected_ability_index];
    ui_draw_ability_tooltip(940, 630, _sel_ab, player);

    // NOTE: Target selection indicator (">") is drawn in Draw_64.gml alongside
    // the enemy HP bars — it needs selected_target from obj_combat_controller
    // directly and cannot be drawn here without passing it as a parameter.

    // --- Telegraph warning (top overlay — check all enemies) ---
    // Uses the combat engine's turn counter stored in combat_state.round as
    // a proxy for turn_number. Replace with your actual per-enemy turn counter
    // if you track those separately.
    var combatant_count = array_length(combat_state.combatants);
    for (var i = 0; i < combatant_count; i++) {
        var c = combat_state.combatants[i];
        if (!c.is_player && enemy_should_telegraph(c, combat_state.round)) {
            ui_draw_telegraph_warning(c.name, c.telegraph_message);
            break; // Only one warning banner at a time
        }
    }
}

// ---------------------------------------------------------------------------
// ui_draw_ability_detail(ab)
// Full-screen "press Tab for the breakdown" popup for one ability — the elaborate
// view so the dense screens don't have to cram the text. Shows icon, attack class,
// AP + secondary-resource cost, cooldown, the full generated mechanics, the status-
// reaction table (for detonators), and flavor. Drawn on the GUI layer over whatever
// screen opened it; the caller gates input while it's up. See SYSTEMS_VIABILITY_PASS.md.
// ---------------------------------------------------------------------------
function ui_draw_ability_detail(ab) {
    if (!is_struct(ab)) return;

    // Dim the whole screen.
    draw_set_alpha(0.80); draw_set_color(c_black);
    draw_rectangle(0, 0, 1280, 720, false);
    draw_set_alpha(1.0);

    var _x1 = 260, _y1 = 96, _x2 = 1020, _y2 = 624;
    draw_set_color(make_color_rgb(16, 17, 26));
    draw_rectangle(_x1, _y1, _x2, _y2, false);
    ui_draw_gothic_frame(_x1, _y1, _x2, _y2, 24);

    var _pad = 30;
    var _lx  = _x1 + _pad;
    var _rx  = _x2 - _pad;
    var _y   = _y1 + _pad;

    // --- Header: icon + name ---
    ui_draw_ability_icon(_lx, _y, 64, ab);
    var _tx = _lx + 64 + 18;
    draw_set_halign(fa_left); draw_set_valign(fa_top);
    draw_set_color(c_white);
    draw_text_transformed(_tx, _y + 2, ab.name, 1.6, 1.6, 0);

    // Cost / class line.
    var _ap  = variable_struct_exists(ab, "energy_cost") ? ab.energy_cost : 0;
    var _sec = variable_struct_exists(ab, "secondary_cost") ? ab.secondary_cost : 0;
    var _cls = variable_global_exists("chosen_class") ? global.chosen_class : 0;
    var _resname = (_cls == 0) ? "Souls" : ((_cls == 1) ? "Blood" : "Preparation");
    var _costline = string(_ap) + " AP";
    if (_sec > 0) _costline += "   +" + string(_sec) + " " + _resname;
    var _cd = ability_cooldown(ab);
    if (_cd > 0) _costline += "   •   " + string(_cd) + "-turn cooldown";
    draw_set_color(make_color_rgb(228, 190, 90));
    draw_text(_tx, _y + 40, _costline);
    draw_set_color(make_color_rgb(150, 160, 190));
    draw_text(_tx, _y + 62, ability_attack_class_tag(ab));

    _y += 96;
    draw_set_color(make_color_rgb(60, 64, 90));
    draw_line(_lx, _y, _rx, _y);
    _y += 16;

    // --- Mechanics (the canonical generated description) ---
    draw_set_color(make_color_rgb(120, 200, 140));
    draw_text(_lx, _y, "MECHANICS");
    _y += 24;
    draw_set_color(make_color_rgb(210, 214, 230));
    var _mech = ability_describe(ab);
    draw_text_ext(_lx, _y, _mech, 22, _rx - _lx);
    _y += string_height_ext(_mech, 22, _rx - _lx) + 18;

    // --- Status reactions table (detonators only) ---
    if (ability_is_detonator(ab)) {
        draw_set_color(make_color_rgb(190, 160, 240));
        draw_text(_lx, _y, "STATUS REACTIONS  (this ability detonates a status on the target)");
        _y += 24;
        var _reacts = [
            "Exposed (Vulnerable) — +12 damage (mark persists)",
            "Root / Frost — +30% damage, shatters",
            "Stun — guaranteed critical hit",
            "Weaken — +15% damage",
            "Blind — cannot miss",
            "Poison — applies Mortality (-40% healing, 4 turns)",
            "Bleed — bursts every remaining bleed tick",
            "Void DoT — heals you for 30% of the damage dealt",
        ];
        draw_set_color(make_color_rgb(200, 204, 220));
        for (var _ri = 0; _ri < array_length(_reacts); _ri++) {
            draw_text(_lx + 8, _y, "•  " + _reacts[_ri]);
            _y += 22;
        }
        _y += 8;
    }

    // --- Flavor (legacy authored line, if any) ---
    if (variable_struct_exists(ab, "desc_full") && ab.desc_full != "") {
        draw_set_color(make_color_rgb(140, 146, 170));
        draw_text_ext(_lx, _y, ab.desc_full, 22, _rx - _lx);
    }

    // --- Footer ---
    draw_set_halign(fa_center);
    draw_set_color(make_color_rgb(150, 160, 190));
    draw_text((_x1 + _x2) / 2, _y2 - 26, "[Tab] or [Esc] — Close");
    draw_set_halign(fa_left); draw_set_valign(fa_top);
    draw_set_color(c_white);
}

// ---------------------------------------------------------------------------
// ui_draw_trait_detail(tr)
// Full-screen Tab breakdown for a TRAIT (mirrors ui_draw_ability_detail). Traits
// are simpler — name + full description + class requirement.
// ---------------------------------------------------------------------------
function ui_draw_trait_detail(tr) {
    if (!is_struct(tr)) return;
    draw_set_alpha(0.80); draw_set_color(c_black);
    draw_rectangle(0, 0, 1280, 720, false);
    draw_set_alpha(1.0);

    var _x1 = 300, _y1 = 160, _x2 = 980, _y2 = 540;
    draw_set_color(make_color_rgb(16, 17, 26));
    draw_rectangle(_x1, _y1, _x2, _y2, false);
    ui_draw_gothic_frame(_x1, _y1, _x2, _y2, 24);

    var _pad = 30, _lx = _x1 + _pad, _rx = _x2 - _pad, _y = _y1 + _pad;
    draw_set_halign(fa_left); draw_set_valign(fa_top);
    draw_set_color(c_white);
    draw_text_transformed(_lx, _y, tr.name, 1.6, 1.6, 0);
    _y += 44;
    draw_set_color(make_color_rgb(190, 160, 240));
    var _cr = variable_struct_exists(tr, "class_req") ? tr.class_req : -1;
    var _crn = (_cr == 0) ? "Arcanist only" : ((_cr == 1) ? "Bloodwarden only" : ((_cr == 2) ? "Shadowstrider only" : "Any class"));
    draw_text(_lx, _y, "TRAIT  •  " + _crn);
    _y += 30;
    draw_set_color(make_color_rgb(60, 64, 90));
    draw_line(_lx, _y, _rx, _y);
    _y += 16;
    draw_set_color(make_color_rgb(210, 214, 230));
    if (variable_struct_exists(tr, "description")) draw_text_ext(_lx, _y, tr.description, 24, _rx - _lx);

    draw_set_halign(fa_center);
    draw_set_color(make_color_rgb(150, 160, 190));
    draw_text((_x1 + _x2) / 2, _y2 - 26, "[Tab] or [Esc] — Close");
    draw_set_halign(fa_left); draw_set_valign(fa_top);
    draw_set_color(c_white);
}

// ---------------------------------------------------------------------------
// ui_compendium_sections()
// Data for the Compendium / Help tab. Each section is { title, entries[] },
// each entry is { term, text }. Data-driven so new mechanics are a quick add —
// append a section here and it shows up in the menu automatically.
// ---------------------------------------------------------------------------
function ui_compendium_sections() {
    return [
        {
            title: "Damage Types",
            entries: [
                { term: "Physical",     text: "Weapon-based damage, reduced by the target's Armor. The default for most strikes and shots." },
                { term: "Elemental",    text: "Fire, frost and shock magic. Resisted by elemental wards rather than Armor." },
                { term: "Drain (Void)", text: "Siphons life or resources from the target and bypasses Armor entirely." },
                { term: "Blood",        text: "Not a separate rule — the Bloodwarden's self-fueled flavor of Drain. It bypasses Armor like Drain, but many blood abilities cost some of your own HP to cast." },
            ],
        },
        {
            title: "Attack Classes",
            entries: [
                { term: "Melee Attack", text: "A physical strike at close range. Stopped by ROOT and by STUN." },
                { term: "Ranged Attack",text: "A physical shot from a distance. Stopped by STUN, but ROOT does not affect it." },
                { term: "Melee Spell",  text: "A spell cast at close range. Stopped by ROOT, SILENCE and STUN." },
                { term: "Ranged Spell", text: "A spell cast from a distance. Stopped by SILENCE and STUN, but not ROOT." },
            ],
        },
        {
            title: "Status Effects",
            entries: [
                { term: "Damage over Time", text: "The target loses HP at the start of each of its turns for a set number of turns." },
                { term: "Vulnerable",       text: "The target takes increased damage from all sources while it lasts." },
                { term: "Weaken",           text: "The target deals reduced damage while it lasts." },
                { term: "Blind",            text: "Accuracy is greatly reduced — most attacks miss until it wears off." },
                { term: "Mortality",        text: "Reduces the healing the target receives. Useful against enemies that mend themselves." },
                { term: "Stun",             text: "The target skips its entire next turn — blocks every kind of action." },
                { term: "Root",             text: "Blocks MELEE actions (attacks and spells). Ranged actions still work." },
                { term: "Silence",          text: "Blocks SPELLS (melee and ranged). Weapon attacks still work." },
            ],
        },
        {
            title: "Status Reactions",
            entries: [
                { term: "Detonators",   text: "Snipe, Assassinate, Arcane Burst and Soul Nova are DETONATORS — when they hit a target carrying a status, they trigger a reaction based on that status (and usually consume it). Set up the status, then detonate." },
                { term: "Poison",       text: "Detonating poison applies Mortality: the target's healing is cut for 4 turns. Utility, not burst — answers self-healing foes." },
                { term: "Bleed",        text: "Detonating bleed bursts every remaining bleed tick at once for bonus damage." },
                { term: "Root / Frost", text: "Detonating a rooted (or frozen) target shatters it for +30% damage." },
                { term: "Vulnerable",   text: "Detonating an Exposed (Vulnerable) target adds a flat damage bonus. The mark is NOT consumed — it's a multi-hit window." },
                { term: "Stun",         text: "Detonating a stunned target is a guaranteed critical hit." },
                { term: "Weaken",       text: "Detonating a weakened target deals +15% damage." },
                { term: "Blind",        text: "Detonating a blinded target cannot miss." },
                { term: "Void",         text: "Detonating a void damage-over-time heals you for 30% of the damage dealt." },
            ],
        },
        {
            title: "AP / Turn Economy",
            entries: [
                { term: "Action Points (AP)", text: "You have 3 AP each turn. Abilities and items spend AP; bigger abilities cost more." },
                { term: "Using Items",        text: "A consumable costs 1 AP on your turn. On an enemy's turn you may use 1 item free, once per enemy turn." },
                { term: "Ending Your Turn",   text: "Unspent AP is lost. AP refills back to 3 at the start of your next turn." },
            ],
        },
        {
            title: "Hit & Crit",
            entries: [
                { term: "Accuracy",        text: "First the attacker rolls to connect (its Accuracy, capped 5-99%). A failure is a MISS. Blind lowers Accuracy sharply." },
                { term: "Dodge",           text: "If an attack connects, the defender rolls their Dodge % to evade it — that's a DODGE (shown separately from a miss). High DEX raises Dodge, with diminishing returns." },
                { term: "Guaranteed Hit",  text: "Some abilities always land — they ignore accuracy, Dodge and Blind entirely." },
                { term: "Critical Hits",   text: "A successful crit deals bonus damage. Certain abilities crit more often or for more." },
            ],
        },
        {
            title: "Progression",
            entries: [
                { term: "Ascendance",  text: "Meta-progression earned across runs. Spend it to permanently strengthen your character between dives." },
                { term: "Run Leveling",text: "Within a run you gain XP from kills, leveling up and growing stronger for that dive only." },
                { term: "Traits",      text: "Passive perks trained at Vex. They cost gold plus a rarity-matched item and slot into your build." },
            ],
        },
        {
            title: "Item Rarities",
            entries: [
                { term: "Common",    text: "Plain gear with minimal or no affixes. The baseline drop." },
                { term: "Uncommon",  text: "A small affix or two — a modest step up from Common." },
                { term: "Rare",      text: "Several affixes; a meaningful upgrade worth equipping." },
                { term: "Epic",      text: "Strong, multi-affix gear that can anchor a build." },
                { term: "Legendary", text: "Hand-crafted uniques with build-defining powers. The rarest drops." },
            ],
        },
    ];
}

// ---------------------------------------------------------------------------
// ui_draw_character_menu()
// Draws the full-screen character menu overlay.
// Called by each room controller's Draw GUI so it renders regardless of which
// room is active (obj_game_controller's own Draw GUI is unreliable when the
// object is persistent and sprite-less).
// ---------------------------------------------------------------------------
function ui_draw_character_menu() {
    if (!instance_exists(obj_game_controller)) return;
    var _gc = instance_find(obj_game_controller, 0);
    if (!_gc.menu_open) return;
    var menu_tab = _gc.menu_tab;
    var items_used_this_turn = _gc.items_used_this_turn;

    var tab_names = ["Stats", "Equipment", "Abilities", "Consumables", "Compendium"];

    draw_set_alpha(1.0);
    draw_set_color(c_white);

    // Full screen dark overlay
    draw_set_alpha(1.0);
    draw_set_color(make_color_rgb(8, 10, 18));
    draw_rectangle(0, 0, 1280, 720, false);
    draw_set_alpha(1.0);

    // Tab bar at top — 5 tabs, centered (matches click zones in obj_game_controller Step)
    var _tab_w = 168;
    var _tab_h = 44;
    var _tab_y = 20;
    for (var _t = 0; _t < 5; _t++) {
        var _tx = 204 + _t * (_tab_w + 8);
        if (_t == menu_tab) {
            draw_set_color(make_color_rgb(30, 50, 90));
            draw_rectangle(_tx, _tab_y, _tx + _tab_w, _tab_y + _tab_h, false);
            draw_set_color(make_color_rgb(80, 140, 220));
            draw_rectangle(_tx, _tab_y, _tx + _tab_w, _tab_y + _tab_h, true);
        } else {
            draw_set_color(make_color_rgb(20, 25, 40));
            draw_rectangle(_tx, _tab_y, _tx + _tab_w, _tab_y + _tab_h, false);
            draw_set_color(make_color_rgb(50, 60, 80));
            draw_rectangle(_tx, _tab_y, _tx + _tab_w, _tab_y + _tab_h, true);
        }
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_set_color((_t == menu_tab) ? c_white : make_color_rgb(140, 150, 170));
        draw_text(_tx + _tab_w / 2, _tab_y + _tab_h / 2, tab_names[_t]);
    }
    draw_set_valign(fa_top);
    draw_set_halign(fa_left);

    // Get player reference if in combat
    var _player    = undefined;
    var _in_combat = instance_exists(obj_combat_controller);
    if (_in_combat) {
        var _ctrl = instance_find(obj_combat_controller, 0);
        _player = _ctrl.player;
    }

    // Out-of-combat fallback — build a read-only view from globals so Stats and
    // Abilities tabs are populated when the menu is opened in the hub or floor map.
    // Always copies chosen_stats and applies equipment bonuses — never mutates the global.
    if (_player == undefined && variable_global_exists("chosen_stats") && !is_undefined(global.chosen_stats)) {
        var _base        = global.chosen_stats;
        var _stats_view  = {
            class_id:    _base.class_id,
            class_name:  _base.class_name,
            STR:         _base.STR,
            DEX:         _base.DEX,
            CON:         _base.CON,
            INT:         _base.INT,
            WIS:         _base.WIS,
            CHA:         _base.CHA,
            free_points: _base.free_points,
        };
        var _sv_bonus = apply_equipment_stats(_stats_view);
        // Add run stat bonuses from XP leveling
        if (variable_global_exists("run_stat_bonuses")) {
            _stats_view.STR += global.run_stat_bonuses.STR;
            _stats_view.DEX += global.run_stat_bonuses.DEX;
            _stats_view.CON += global.run_stat_bonuses.CON;
            _stats_view.INT += global.run_stat_bonuses.INT;
            _stats_view.WIS += global.run_stat_bonuses.WIS;
            _stats_view.CHA += global.run_stat_bonuses.CHA;
        }
        // Add permanent meta-progression bonuses
        if (variable_global_exists("perm_str_bonus")) {
            _stats_view.STR += global.perm_str_bonus;
            _stats_view.DEX += global.perm_dex_bonus;
            _stats_view.CON += global.perm_con_bonus;
            _stats_view.INT += global.perm_int_bonus;
            _stats_view.WIS += global.perm_wis_bonus;
            _stats_view.CHA += global.perm_cha_bonus;
        }
        var _derived_view = stats_derive(_stats_view);
        var _sv_max_hp = _derived_view.HP + _sv_bonus.bonus_max_hp;
        _player = {
            class_id:  global.chosen_class,
            stats:     _stats_view,
            HP:        (variable_global_exists("run_current_hp") && global.run_current_hp > 0)
                           ? global.run_current_hp
                           : _sv_max_hp,
            max_HP:    _sv_max_hp,
            abilities: abilities_get_loadout(global.chosen_class),
            dodge:     _derived_view.DODGE + _sv_bonus.dodge_flat,
        };
    }

    var _content_y = 90;
    var _pad       = 40;

    // ---- STATS TAB ----
    if (menu_tab == 0) {
        if (_player != undefined) {
            var _stats       = _player.stats;
            var _derived     = stats_derive(_stats);
            var _class_names = ["Arcanist", "Bloodwarden", "Shadowstrider"];
            var _class_id    = clamp(_player.stats.class_id, 0, 2);
            var _dc = make_color_rgb(120, 140, 170);
            var _hc = make_color_rgb(80, 110, 160);

            // Flat crit % added to EVERY school in actual combat: equipment crit_flat
            // ("of Ruin" affix / Keen runes → player.stats.crit_bonus) plus the Duelist
            // boon. stats_derive only returns the stat-scaled portion, so the panel used
            // to under-report the real crit rate — fold the flat bonus in here.
            var _crit_flat = 0;
            if (_in_combat && variable_struct_exists(_player.stats, "crit_bonus")) {
                _crit_flat = _player.stats.crit_bonus;
            } else {
                _crit_flat = apply_equipment_stats({}).crit_flat;
            }
            _crit_flat += boon_value("duelist");

            // ---- Header: class + level + HP ----
            draw_set_color(make_color_rgb(80, 160, 220));
            draw_text_transformed(_pad, _content_y, _class_names[_class_id], 1.5, 1.5, 0);
            // Current run level, beside the class title
            if (variable_global_exists("run_level")) {
                draw_set_color(make_color_rgb(210, 200, 120));
                draw_text(_pad + 300, _content_y + 6, "Level " + string(global.run_level));
            }
            draw_set_color(c_white);
            draw_text(_pad, _content_y + 44, "HP: " + string(_player.HP) + " / " + string(_player.max_HP));

            // ---- Stat grid (two compact columns) ----
            var _stat_keys = ["STR", "DEX", "CON", "INT", "WIS", "CHA"];
            for (var _s = 0; _s < 6; _s++) {
                var _sx  = _pad + floor(_s / 3) * 190;     // 0=STR/DEX/CON, 1=INT/WIS/CHA
                var _sy  = _content_y + 84 + (_s mod 3) * 32;
                draw_set_color(make_color_rgb(140, 160, 200));
                draw_text(_sx, _sy, _stat_keys[_s] + ":");
                draw_set_color(c_white);
                draw_text(_sx + 56, _sy, string(variable_struct_get(_stats, _stat_keys[_s])));
            }

            // ---- Offense ----
            draw_set_color(_hc);
            draw_text(_pad, _content_y + 196, "── Offense ──────────────");
            // Damage bonuses (left sub-column)
            draw_set_color(_dc);
            draw_text(_pad, _content_y + 222, "Phys abilities (STR):  +" + string(_derived.phys_dmg_bonus));
            draw_text(_pad, _content_y + 246, "Elem abilities (INT):  +" + string(_derived.elem_dmg_bonus));
            draw_text(_pad, _content_y + 270, "DoT / effects  (WIS):  +" + string(_derived.dot_dmg_bonus));
            draw_text(_pad, _content_y + 294, "All abilities  (CHA):  +" + string(_derived.cha_dmg_bonus));
            // Reach-gated weapon damage totals — flat dmg added to melee vs ranged abilities
            // only (SYSTEMS_WEAPON_ROLES.md §B). Read from apply_equipment_stats's per-reach
            // accumulators so this matches the cast resolver and the equip tab's per-weapon "+N dmg".
            var _wpn_bonus = apply_equipment_stats({});
            draw_text(_pad, _content_y + 318, "Melee Weapon dmg:   +" + string(_wpn_bonus.melee_dmg_bonus));
            draw_text(_pad, _content_y + 342, "Ranged Weapon dmg:  +" + string(_wpn_bonus.ranged_dmg_bonus));
            // Crit chances (right sub-column) — now include the flat gear/Duelist bonus
            var _crit_x = _pad + 320;
            draw_set_color(_dc);
            draw_text(_crit_x, _content_y + 222, "Crit — Power  (STR):  " + string(round(_derived.STR_crit_chance + _crit_flat)) + "%");
            draw_text(_crit_x, _content_y + 246, "Crit — Precis (DEX):  " + string(round(_derived.DEX_crit_chance + _crit_flat)) + "%");
            draw_text(_crit_x, _content_y + 270, "Crit — Arcane (INT):  " + string(round(_derived.INT_crit_chance + _crit_flat)) + "%");
            draw_text(_crit_x, _content_y + 294, "Crit — Effect (WIS):  " + string(round(_derived.WIS_crit_chance + _crit_flat)) + "%");
            draw_set_color(make_color_rgb(95, 105, 125));
            draw_text(_crit_x, _content_y + 320, "+ each ability's own base crit");
            draw_text(_crit_x, _content_y + 338, "(includes gear & Duelist bonuses)");

            // ---- Defense ----
            draw_set_color(_hc);
            draw_text(_pad, _content_y + 384, "── Defense ──────────────");
            draw_set_color(_dc);
            draw_text(_pad, _content_y + 410, "Dodge:           " + string(_derived.DODGE) + "%");
            draw_text(_pad, _content_y + 434, "Phys reduction:  " + string(_derived.phys_dmg_reduction) + "%");
            draw_text(_pad, _content_y + 458, "Base HP:         " + string(_derived.HP) + "  (+" + string(apply_equipment_stats({}).bonus_max_hp) + " gear)");
            // Accuracy — a flat bonus to each ability's to-hit, before the foe's dodge.
            draw_set_color(make_color_rgb(150, 180, 210));
            draw_text(_crit_x, _content_y + 410, "Accuracy:  +" + string(_derived.ACC_modifier) + "% to hit");
            draw_set_color(make_color_rgb(95, 105, 125));
            draw_text(_crit_x, _content_y + 432, "Flat % added on top of each ability's");
            draw_text(_crit_x, _content_y + 450, "own hit chance (e.g. 85% + this, cap 99%).");
            draw_text(_crit_x, _content_y + 468, "Then the foe's Dodge rolls. Blind lowers it.");

            // ---- Footer ----
            draw_set_color(c_yellow);
            draw_text(_pad, _content_y + 540, "Gold: " + string(global.gold) + "g");
            draw_set_color(make_color_rgb(140, 160, 200));
            draw_text(_pad, _content_y + 564, "Run " + string(global.run_count + 1) + "  ·  Floor " + string(global.current_floor));

            // =====================================================================
            // RIGHT COLUMN — portrait card + combat readiness + boons / effects
            // =====================================================================
            var _cardx1 = 820, _cardx2 = 1200;
            var _cardy1 = _content_y, _cardy2 = _content_y + 240;

            // Card frame
            draw_set_color(make_color_rgb(18, 24, 38));
            draw_rectangle(_cardx1, _cardy1, _cardx2, _cardy2, false);
            draw_set_color(make_color_rgb(70, 90, 130));
            draw_rectangle(_cardx1, _cardy1, _cardx2, _cardy2, true);
            ui_draw_gothic_frame(_cardx1, _cardy1, _cardx2, _cardy2, 20);   // ornate portrait frame

            // South-facing player sprite (frame 0 = south in the 8-dir layout). Sprites
            // are top-left origin and vary in canvas size, so normalise to a target
            // height and centre inside the card.
            var _pspr = player_combat_sprite(_class_id);
            if (_pspr != -1 && sprite_exists(_pspr)) {
                var _psh = max(1, sprite_get_height(_pspr));
                var _psw = max(1, sprite_get_width(_pspr));
                var _pscale = 190 / _psh;
                var _pcx = (_cardx1 + _cardx2) / 2;
                var _pcy = (_cardy1 + _cardy2) / 2;
                draw_sprite_ext(_pspr, 0,
                    _pcx - (_psw * _pscale) / 2,
                    _pcy - (_psh * _pscale) / 2,
                    _pscale, _pscale, 0, c_white, 1.0);
            }

            // Skin / gender caption under the card
            var _skin_name = "Default look";
            if (variable_global_exists("player_skin") && global.player_skin != "default") {
                var _skd = vael_skin_get(global.player_skin);
                if (_skd != undefined) _skin_name = _skd.name;
            }
            var _gender_txt = (variable_global_exists("player_gender") && global.player_gender == "f") ? "Female" : "Male";
            draw_set_halign(fa_center);
            draw_set_color(make_color_rgb(190, 200, 220));
            draw_text((_cardx1 + _cardx2) / 2, _cardy2 + 24, _skin_name + "  ·  " + _gender_txt);
            draw_set_halign(fa_left);

            // ---- Combat readiness summary ----
            var _rx = _cardx1;
            draw_set_color(_hc);
            draw_text(_rx, _content_y + 282, "── Combat Readiness ─────");
            // Primary crit school by class: Arcanist=Arcane, Bloodwarden=Power, Strider=Precision
            var _prim_lbls = ["Arcane (INT)", "Power (STR)", "Precision (DEX)"];
            var _prim_vals = [_derived.INT_crit_chance, _derived.STR_crit_chance, _derived.DEX_crit_chance];
            draw_set_color(c_white);
            draw_text(_rx, _content_y + 308, "HP:        " + string(_player.HP) + " / " + string(_player.max_HP));
            draw_text(_rx, _content_y + 330, "Dodge:     " + string(_derived.DODGE) + "%");
            draw_text(_rx, _content_y + 352, "Accuracy:  +" + string(_derived.ACC_modifier) + "% to hit");
            draw_text(_rx, _content_y + 374, "Main crit: " + string(round(_prim_vals[_class_id] + _crit_flat)) + "%  (" + _prim_lbls[_class_id] + ")");

            // ---- Boons & Effects (right column, below readiness) ----
            draw_set_color(_hc);
            draw_text(_rx, _content_y + 414, "── Boons & Effects ──────");
            var _by    = _content_y + 440;
            var _any   = false;
            var _rows  = 0;
            var _rowmx = 6;   // vertical room cap for this column

            if (variable_global_exists("run_boons") && array_length(global.run_boons) > 0) {
                var _bn = array_length(global.run_boons);
                for (var _bi = 0; _bi < _bn && _rows < _rowmx; _bi++) {
                    var _bb = boon_get(global.run_boons[_bi]);
                    if (_bb == undefined) continue;
                    draw_set_color(make_color_rgb(190, 180, 140));
                    draw_text(_rx, _by, "+ " + _bb.name);
                    draw_set_color(make_color_rgb(120, 130, 110));
                    draw_text(_rx + 16, _by + 16, ui_truncate(_bb.desc, 360));
                    _by += 38; _rows++; _any = true;
                }
            }
            // Active run curses (devil's bargain) — red, with penalty text.
            if (variable_global_exists("run_curses") && array_length(global.run_curses) > 0) {
                var _cn = array_length(global.run_curses);
                for (var _ci = 0; _ci < _cn && _rows < _rowmx; _ci++) {
                    var _cc = curse_get(global.run_curses[_ci]);
                    if (_cc == undefined) continue;
                    draw_set_color(make_color_rgb(210, 120, 120));
                    draw_text(_rx, _by, "! " + _cc.name);
                    draw_set_color(make_color_rgb(150, 110, 110));
                    draw_text(_rx + 16, _by + 16, ui_truncate(_cc.desc, 360));
                    _by += 38; _rows++; _any = true;
                }
            }
            // Active combat statuses on the player (only present during combat).
            if (variable_struct_exists(_player, "status_effects")) {
                var _se_list = _player.status_effects;
                for (var _ssi = 0; _ssi < array_length(_se_list) && _rows < _rowmx; _ssi++) {
                    var _ss   = _se_list[_ssi];
                    var _sst  = status_icon_style(_ss);
                    var _sdur = variable_struct_exists(_ss, "duration") ? _ss.duration : 0;
                    draw_set_color(_sst.color);
                    draw_text(_rx, _by, "- " + _ss.name + " (" + _sst.label + ")");
                    draw_set_color(make_color_rgb(150, 140, 120));
                    draw_text(_rx + 16, _by + 16, ui_truncate(status_effect_plain_text(_ss) + "  ·  " + string(_sdur) + " turn" + (_sdur == 1 ? "" : "s") + " left", 360));
                    _by += 38; _rows++; _any = true;
                }
            }
            if (!_any) {
                draw_set_color(_dc);
                draw_text(_rx, _by, "None active.");
                draw_set_color(make_color_rgb(95, 105, 125));
                draw_text(_rx + 16, _by + 16, "Boons last all run; statuses a few turns.");
            }
        } else {
            draw_set_color(make_color_rgb(120, 130, 150));
            draw_text(_pad, _content_y + 20, "No active character — start a run to view stats.");
        }
    }

    // ---- EQUIPMENT TAB ----
    if (menu_tab == 1) {
        var _slot_names = ["Melee Weapon", "Offhand", "Helm", "Chest", "Gloves", "Boots", "Amulet", "Ring", "Ranged Weapon"];
        var _slot_keys  = ["weapon", "offhand", "helm", "chest", "gloves", "boots", "amulet", "ring", "ranged_weapon"];
        var _sel_slot   = _gc.equip_slot_selected;

        // Equip confirmation notification (fades over 150 frames, fully opaque first 120)
        if (variable_instance_exists(_gc, "equip_notif_timer") && _gc.equip_notif_timer > 0) {
            var _nf = clamp(_gc.equip_notif_timer / 30.0, 0, 1.0);
            draw_set_alpha(_nf);
            draw_set_halign(fa_center);
            draw_set_color(make_color_rgb(100, 220, 130));
            draw_text(640, 70, _gc.equip_notif_msg);
            draw_set_halign(fa_left);
            draw_set_alpha(1.0);
        }

        // Stash / Pack counts in top-right
        var _stash_count = variable_global_exists("equipment_stash") ? array_length(global.equipment_stash) : 0;
        var _pack_count  = variable_global_exists("carried_items")   ? array_length(global.carried_items)   : 0;
        var _equip_in_hub = (room == rm_hub || room == rm_character_select);
        draw_set_halign(fa_right);
        draw_set_color(make_color_rgb(120, 130, 150));
        // Stash is only reachable in the hub; during a run show the pack only.
        if (_equip_in_hub) {
            draw_text(1240, _content_y, "Stash: " + string(_stash_count) + "   Pack: " + string(_pack_count));
        } else {
            draw_text(1240, _content_y, "Pack: " + string(_pack_count) + "  (stash left in town)");
        }
        draw_set_halign(fa_left);

        // 9 equipment slots — 2 columns of up to 5 rows (col = slot div 5).
        var _offhand_locked = two_handed_equipped();   // 2H weapon locks the offhand slot (1)
        for (var _sl = 0; _sl < 9; _sl++) {
            var _slx    = _pad + floor(_sl / 5) * 580;
            var _sly    = _content_y + 24 + (_sl mod 5) * 108;
            var _is_sel = (_sl == _sel_slot);
            // The offhand slot fades out while a two-handed weapon is equipped.
            var _slot_locked = (_sl == 1 && _offhand_locked);
            if (_slot_locked) draw_set_alpha(0.4);

            // Slot background — highlight selected row
            if (_is_sel) {
                draw_set_color(make_color_rgb(30, 50, 80));
            } else {
                draw_set_color(make_color_rgb(20, 25, 40));
            }
            draw_rectangle(_slx, _sly, _slx + 520, _sly + 96, false);
            draw_set_color(_is_sel ? make_color_rgb(80, 140, 220) : make_color_rgb(50, 60, 80));
            draw_rectangle(_slx, _sly, _slx + 520, _sly + 96, true);

            var _equipped = undefined;
            if (variable_global_exists("inventory") && array_length(global.inventory) > _sl) {
                _equipped = global.inventory[_sl];
            }
            draw_set_color(_is_sel ? c_white : make_color_rgb(100, 110, 130));
            draw_text(_slx + 10, _sly + 8, _slot_names[_sl]);

            if (_equipped != undefined) {
                var _rcol = item_rarity_color(_equipped.rarity);
                // Rarity tag — moved up to the slot-label line (its left side is empty)
                // so it never collides with a long item name on the row below.
                draw_set_halign(fa_right);
                draw_set_color(_rcol);
                draw_text(_slx + 510, _sly + 8, item_rarity_name(_equipped.rarity));
                draw_set_halign(fa_left);
                // Icon badge — pushed below the slot-name label so they don't overlap.
                ui_draw_item_icon(_slx + 8, _sly + 32, 40, _equipped);
                // Text column is clipped to the slot box (56..506 = 450px wide).
                var _txt_w = 450;
                // Name
                draw_set_color(_rcol);
                draw_text(_slx + 56, _sly + 30, ui_truncate(_equipped.name, _txt_w));
                // Stat string
                draw_set_color(c_white);
                draw_text(_slx + 56, _sly + 52, ui_truncate(ui_item_stat_str(_equipped), _txt_w));
                // Flavor text or unique effect
                if (variable_struct_exists(_equipped, "unique_desc") && _equipped.unique_desc != "") {
                    draw_set_color(make_color_rgb(255, 200, 50));
                    draw_text(_slx + 56, _sly + 74, ui_truncate(_equipped.unique_desc, _txt_w));
                } else if (_equipped.effect_desc != "") {
                    draw_set_color(make_color_rgb(100, 110, 135));
                    draw_text(_slx + 56, _sly + 74, ui_truncate(_equipped.effect_desc, _txt_w));
                }
            } else if (_slot_locked) {
                draw_set_color(make_color_rgb(150, 130, 90));
                draw_text(_slx + 10, _sly + 45, "Two-handed: offhand locked");
            } else {
                draw_set_color(make_color_rgb(60, 65, 80));
                draw_text(_slx + 10, _sly + 45, "— Empty —");
            }
            if (_slot_locked) draw_set_alpha(1.0);
        }

        // Bottom instruction line
        draw_set_halign(fa_center);
        draw_set_color(make_color_rgb(80, 90, 110));
        if (_gc.equip_picker_open) {
            draw_text(640, 690, "W/S: Navigate   Enter: Equip   Esc: Cancel");
        } else {
            draw_text(640, 690, "W/S: Navigate   Enter: Equip   U: Unequip");
        }
        draw_set_halign(fa_left);

        // --- EQUIP PICKER OVERLAY ---
        if (_gc.equip_picker_open) {
            var _slot_name = _slot_keys[_sel_slot];

            // Build filtered list (same order as Step)
            var _picker_items = [];
            var _picker_src   = [];
            // Stash is hub-only: during a run only the pack is shown (must match Step).
            var _picker_in_hub = (room == rm_hub || room == rm_character_select);
            if (_picker_in_hub && variable_global_exists("equipment_stash")) {
                for (var _pi = 0; _pi < array_length(global.equipment_stash); _pi++) {
                    if (global.equipment_stash[_pi].slot == _slot_name) {
                        array_push(_picker_items, global.equipment_stash[_pi]);
                        array_push(_picker_src, 0);   // 0 = stash
                    }
                }
            }
            if (variable_global_exists("carried_items")) {
                for (var _pi = 0; _pi < array_length(global.carried_items); _pi++) {
                    if (global.carried_items[_pi].slot == _slot_name) {
                        array_push(_picker_items, global.carried_items[_pi]);
                        array_push(_picker_src, 1);   // 1 = pack
                    }
                }
            }

            // Picker panel
            var _px      = 240;
            var _py      = 120;
            var _pw      = 800;
            var _row_h   = 72;
            var _visible = array_length(_picker_items);
            var _ph      = max(100, _visible * _row_h + 32);

            draw_set_alpha(0.97);
            draw_set_color(make_color_rgb(12, 15, 28));
            draw_rectangle(_px, _py, _px + _pw, _py + _ph, false);
            draw_set_alpha(1.0);
            draw_set_color(make_color_rgb(80, 140, 220));
            draw_rectangle(_px, _py, _px + _pw, _py + _ph, true);

            draw_set_halign(fa_center);
            draw_set_color(c_white);
            draw_text(_px + _pw / 2, _py + 8, "Choose " + _slot_names[_sel_slot]);
            draw_set_halign(fa_left);

            // Class restriction warning / equip_msg
            if (variable_instance_exists(_gc, "equip_msg") && _gc.equip_msg != "") {
                draw_set_halign(fa_center);
                draw_set_color(make_color_rgb(255, 120, 60));
                draw_text(_px + _pw / 2, _py + _ph + 6, _gc.equip_msg);
                draw_set_halign(fa_left);
            }

            if (_visible == 0) {
                draw_set_color(make_color_rgb(100, 110, 130));
                draw_text(_px + 20, _py + 40, _picker_in_hub
                    ? "No matching items in stash or pack."
                    : "No matching items in your pack.");
            } else {
                var _pc = variable_global_exists("chosen_class") ? global.chosen_class : -1;
                for (var _ri = 0; _ri < _visible; _ri++) {
                    var _it     = _picker_items[_ri];
                    var _ry     = _py + 32 + _ri * _row_h;
                    var _is_sel = (_ri == _gc.equip_picker_index);
                    var _src    = _picker_src[_ri];
                    var _it_cr  = variable_struct_exists(_it, "class_req") ? _it.class_req : -1;
                    var _locked = (_it_cr != -1 && _it_cr != _pc);

                    draw_set_alpha((_is_sel && !_locked) ? 0.9 : (_locked ? 0.28 : 0.45));
                    draw_set_color(_is_sel ? make_color_rgb(30, 50, 90) : make_color_rgb(18, 22, 38));
                    draw_rectangle(_px + 4, _ry, _px + _pw - 4, _ry + _row_h - 4, false);
                    draw_set_alpha(1.0);

                    var _rcol = _locked ? make_color_rgb(80, 80, 90) : item_rarity_color(_it.rarity);
                    // Icon badge — drawn for locked items too so class-only gear still shows its art
                    ui_draw_item_icon(_px + 14, _ry + 6, 32, _it);
                    var _itx = _px + 52;
                    // Name
                    draw_set_color(_rcol);
                    draw_text(_itx, _ry + 8, _it.name);
                    // Stat string
                    draw_set_color(_locked ? make_color_rgb(70, 70, 80) : c_white);
                    draw_text(_itx, _ry + 30, ui_item_stat_str(_it));
                    // Unique or flavor
                    if (!_locked && variable_struct_exists(_it, "unique_desc") && _it.unique_desc != "") {
                        draw_set_color(make_color_rgb(255, 200, 50));
                        draw_text(_itx, _ry + 50, _it.unique_desc);
                    } else if (!_locked && _it.effect_desc != "") {
                        draw_set_color(make_color_rgb(95, 105, 130));
                        draw_text(_itx, _ry + 50, _it.effect_desc);
                    }

                    // Source tag, rarity, class restriction
                    draw_set_halign(fa_right);
                    if (_locked) {
                        var _cr_names = ["Arcanist", "Bloodwarden", "Shadowstrider"];
                        draw_set_color(make_color_rgb(180, 80, 80));
                        draw_text(_px + _pw - 14, _ry + 8, "[" + _cr_names[_it_cr] + " only]");
                    } else {
                        draw_set_color((_src == 0) ? make_color_rgb(120, 200, 120) : make_color_rgb(200, 180, 100));
                        draw_text(_px + _pw - 14, _ry + 8, (_src == 0) ? "[Stash]" : "[Pack]");
                        draw_set_color(_rcol);
                        draw_text(_px + _pw - 14, _ry + 34, item_rarity_name(_it.rarity));
                    }
                    draw_set_halign(fa_left);
                }

                // Hover tooltip for item in picker
                var _hmx = device_mouse_x_to_gui(0);
                var _hmy = device_mouse_y_to_gui(0);
                if (_hmx >= _px + 4 && _hmx < _px + _pw - 4) {
                    for (var _tt_ri = 0; _tt_ri < _visible; _tt_ri++) {
                        var _tt_ry = _py + 32 + _tt_ri * _row_h;
                        if (_hmy >= _tt_ry && _hmy < _tt_ry + _row_h - 4) {
                            var _cur_eq = (variable_global_exists("inventory")
                                && array_length(global.inventory) > _sel_slot)
                                ? global.inventory[_sel_slot] : undefined;
                            ui_draw_item_tooltip(_hmx + 12, _hmy - 30, _picker_items[_tt_ri], _cur_eq);
                            break;
                        }
                    }
                }
            }
        }
    }

    // ---- ABILITIES TAB ----
    if (menu_tab == 2) {
        if (_player != undefined) {
            for (var _ab = 0; _ab < array_length(_player.abilities); _ab++) {
                var _a  = _player.abilities[_ab];
                var _ay = _content_y + _ab * 130;

                draw_set_color(make_color_rgb(20, 28, 48));
                draw_rectangle(_pad, _ay, 1240, _ay + 110, false);
                draw_set_color(make_color_rgb(60, 80, 120));
                draw_rectangle(_pad, _ay, 1240, _ay + 110, true);

                draw_set_color(c_white);
                draw_text(_pad + 14, _ay + 10, _a.name);
                draw_set_color(c_yellow);
                draw_text(_pad + 14, _ay + 38, "AP: " + string(_a.energy_cost));

                if (_a.base_damage > 0) {
                    draw_set_color(make_color_rgb(220, 100, 80));
                    var _dtype = ["physical", "elemental", "drain", "blood"];
                    var _dt_idx = clamp(_a.damage_type, 0, array_length(_dtype) - 1);
                    draw_text(_pad + 140, _ay + 38,
                        "Damage: " + string(_a.base_damage) + " (" + _dtype[_dt_idx] + ")");
                }

                draw_set_color(make_color_rgb(160, 170, 200));
                draw_text(_pad + 14, _ay + 66, _a.effect_type + " — " + string(_a.effect_value));

                if (_a.guaranteed_hit) {
                    draw_set_color(make_color_rgb(100, 180, 100));
                    draw_text(_pad + 500, _ay + 38, "Always hits");
                }
            }
        }
    }

    // ---- CONSUMABLES TAB ----
    if (menu_tab == 3) {
        var _cons_count     = array_length(global.consumable_inventory);
        var _sub_open       = _gc.consumable_submenu_open;
        var _sub_cur        = _gc.consumable_submenu_cursor;

        // Determine per-turn item limit state
        var _limit_reached = false;
        var _no_ap         = false;
        if (_in_combat) {
            var _ctrl_lim = instance_find(obj_combat_controller, 0);
            if (!_ctrl_lim.player_turn && items_used_this_turn >= 1) {
                _limit_reached = true;
            }
            if (_ctrl_lim.player_turn && _ctrl_lim.player.energy < 1) {
                _no_ap         = true;
                _limit_reached = true;
            }
        }

        if (_cons_count == 0) {
            draw_set_color(make_color_rgb(100, 110, 130));
            draw_text(_pad, _content_y + 20, "No consumables in inventory.");
        } else {
            // Status header (combat only)
            if (_in_combat) {
                var _ctrl_hdr = instance_find(obj_combat_controller, 0);
                if (_no_ap) {
                    draw_set_color(c_red);
                    draw_text(_pad, _content_y, "Not enough AP — items cost 1 AP to use.");
                } else if (!_ctrl_hdr.player_turn) {
                    if (_limit_reached) {
                        draw_set_color(c_red);
                        draw_text(_pad, _content_y, "Item use limit reached for this enemy turn.");
                    } else {
                        draw_set_color(c_yellow);
                        draw_text(_pad, _content_y, "Enemy turn — 1 item use remaining.");
                    }
                }
            }

            // Windowed list — keep the cursor on screen when there are many items.
            // Mouse hit-testing in obj_game_controller Step uses the same window math.
            var _cons_max_vis = 7;
            var _cons_first   = ui_list_window_first(_sub_cur, _cons_count, _cons_max_vis);
            var _cons_last    = min(_cons_count, _cons_first + _cons_max_vis);

            // "more above / below" hints
            draw_set_halign(fa_center);
            if (_cons_first > 0) {
                draw_set_color(make_color_rgb(120, 200, 200));
                draw_text(470, _content_y + 26, "▲ " + string(_cons_first) + " more");
            }
            if (_cons_last < _cons_count) {
                draw_set_color(make_color_rgb(120, 200, 200));
                draw_text(470, _content_y + 40 + _cons_max_vis * 80 - 12, "▼ " + string(_cons_count - _cons_last) + " more");
            }
            draw_set_halign(fa_left);

            for (var _ci = _cons_first; _ci < _cons_last; _ci++) {
                var _c      = global.consumable_inventory[_ci];
                var _cy2    = _content_y + 40 + (_ci - _cons_first) * 80;
                var _is_cur = (_sub_open && _ci == _sub_cur);

                // Background — highlighted when this row is the cursor
                if (_is_cur) {
                    draw_set_color(make_color_rgb(30, 80, 80));
                } else {
                    draw_set_color(make_color_rgb(20, 30, 48));
                }
                draw_rectangle(_pad, _cy2, 900, _cy2 + 65, false);

                // Border
                if (_is_cur && !_limit_reached) {
                    draw_set_color(make_color_rgb(80, 220, 220));
                } else if (_is_cur && _limit_reached) {
                    draw_set_color(make_color_rgb(180, 60, 60));
                } else if (_sub_open) {
                    draw_set_color(make_color_rgb(30, 90, 90));
                } else {
                    draw_set_color(make_color_rgb(40, 140, 140));
                }
                draw_rectangle(_pad, _cy2, 900, _cy2 + 65, true);

                // Icon (left side) — shifts the text right only when art exists
                var _csp     = ui_consumable_icon_sprite(_c.name);
                var _c_dim   = (_sub_open && !_is_cur);
                var _has_csp = (_csp != -1 && sprite_exists(_csp));
                var _ctext_x = _has_csp ? _pad + 64 : _pad + 12;
                if (_has_csp) {
                    draw_set_alpha(_c_dim ? 0.4 : 1.0);
                    draw_sprite_stretched(_csp, 0, _pad + 8, _cy2 + 8, 48, 48);
                    draw_set_alpha(1.0);
                }

                // Name
                if (_sub_open && !_is_cur) {
                    draw_set_color(make_color_rgb(50, 130, 130));
                } else if (_is_cur && _limit_reached) {
                    draw_set_color(make_color_rgb(200, 100, 100));
                } else if (_is_cur) {
                    draw_set_color(make_color_rgb(120, 255, 255));
                } else {
                    draw_set_color(make_color_rgb(80, 220, 220));
                }
                draw_text(_ctext_x, _cy2 + 8, _c.name);

                // Description
                if (_sub_open && !_is_cur) {
                    draw_set_color(make_color_rgb(70, 80, 95));
                } else {
                    draw_set_color(c_white);
                }
                draw_text(_ctext_x, _cy2 + 36, _c.description);

                // Gold value
                draw_set_halign(fa_right);
                if (_sub_open && !_is_cur) {
                    draw_set_color(make_color_rgb(80, 90, 60));
                } else {
                    draw_set_color(c_yellow);
                }
                draw_text(890, _cy2 + 8, string(_c.gold_value) + "g value");
                draw_set_halign(fa_left);
            }
        }
    }

    // ---- COMPENDIUM (HELP) TAB ----
    if (menu_tab == 4) {
        var _comp_secs = ui_compendium_sections();
        var _comp_sel  = clamp(_gc.compendium_section, 0, array_length(_comp_secs) - 1);

        // Left list — section titles
        for (var _cs = 0; _cs < array_length(_comp_secs); _cs++) {
            var _csy    = _content_y + _cs * 46;
            var _cs_on  = (_cs == _comp_sel);
            draw_set_color(_cs_on ? make_color_rgb(30, 50, 90) : make_color_rgb(18, 24, 40));
            draw_rectangle(40, _csy, 300, _csy + 40, false);
            draw_set_color(_cs_on ? make_color_rgb(80, 140, 220) : make_color_rgb(45, 55, 75));
            draw_rectangle(40, _csy, 300, _csy + 40, true);
            draw_set_color(_cs_on ? c_white : make_color_rgb(150, 160, 180));
            draw_set_valign(fa_middle);
            draw_text(54, _csy + 20, _comp_secs[_cs].title);
            draw_set_valign(fa_top);
        }

        // Right detail pane — entries of the selected section
        var _det_x  = 330;
        var _det_w  = 1240 - _det_x;   // wrap width for entry text
        draw_set_color(make_color_rgb(80, 160, 220));
        draw_text_transformed(_det_x, _content_y - 4, _comp_secs[_comp_sel].title, 1.4, 1.4, 0);

        var _ey      = _content_y + 44;
        var _entries = _comp_secs[_comp_sel].entries;
        for (var _ce = 0; _ce < array_length(_entries); _ce++) {
            var _ent = _entries[_ce];
            // Term (bold-ish accent line)
            draw_set_color(make_color_rgb(220, 200, 120));
            draw_text(_det_x, _ey, _ent.term);
            _ey += 24;
            // Wrapped description
            draw_set_color(make_color_rgb(200, 208, 224));
            draw_text_ext(_det_x + 4, _ey, _ent.text, 22, _det_w - 4);
            _ey += string_height_ext(_ent.text, 22, _det_w - 4) + 12;
        }
    }

    // Bottom instructions
    if (menu_tab != 1 && menu_tab != 3 && menu_tab != 4) {
        draw_set_halign(fa_center);
        draw_set_color(make_color_rgb(80, 90, 110));
        draw_text(640, 690, "Q/E: Switch Tab   I / Esc: Close");
        draw_set_halign(fa_left);
    }
    if (menu_tab == 4) {
        draw_set_halign(fa_center);
        draw_set_color(make_color_rgb(80, 90, 110));
        draw_text(640, 690, "W/S: Browse Sections   Q/E: Switch Tab   I / Esc: Close");
        draw_set_halign(fa_left);
    }
    if (menu_tab == 3) {
        draw_set_halign(fa_center);
        if (_gc.consumable_submenu_open && array_length(global.consumable_inventory) > 0) {
            if (_no_ap) {
                draw_set_color(make_color_rgb(200, 80, 80));
                draw_text(640, 690, "W/S: Navigate   Need 1 AP to use   Esc: Cancel");
            } else if (_limit_reached) {
                draw_set_color(make_color_rgb(200, 80, 80));
                draw_text(640, 690, "W/S: Navigate   1 per turn limit   Esc: Cancel");
            } else {
                draw_set_color(make_color_rgb(80, 90, 110));
                draw_text(640, 690, "W/S: Navigate   Enter: Use [-1 AP]   Esc: Cancel");
            }
        } else {
            draw_set_color(make_color_rgb(100, 200, 100));
            draw_text(640, 690, "Enter: Browse Items   Q/E: Switch Tab   I: Close");
        }
        draw_set_halign(fa_left);
    }
}

// ---------------------------------------------------------------------------
// ui_draw_shop_screen()
// Full-screen overlay for Petra's Supplies (shop_open==0) or Dorn's Forge
// (shop_open==1). Draws all purchasable rows, gold balance, and a notification
// line. Called by obj_hub_controller Draw_64 after the stash screen call.
// ---------------------------------------------------------------------------
function ui_draw_shop_screen() {
    if (!instance_exists(obj_game_controller)) return;
    var _gc  = instance_find(obj_game_controller, 0);
    if (_gc.shop_open == -1) return;

    var _is_petra = (_gc.shop_open == 0);
    var _accent   = _is_petra ? make_color_rgb(60, 190, 190) : make_color_rgb(210, 130, 40);
    var _title    = _is_petra ? "PETRA'S SUPPLIES" : "DORN'S FORGE";

    // Full-screen dark cover
    draw_set_alpha(0.96);
    draw_set_color(make_color_rgb(8, 10, 18));
    draw_rectangle(0, 0, 1280, 720, false);
    draw_set_alpha(1.0);

    // Title
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_color(_accent);
    draw_text_transformed(640, 24, _title, 1.5, 1.5, 0);   // y24 keeps the title inside the rim opening

    // Gold (top-right) — pulled in from x1260 to clear the right rim band
    draw_set_halign(fa_right);
    draw_set_color(c_yellow);
    draw_text(1250, 24, "Gold: " + string(global.gold) + "g");

    // --- BUY / SELL tab bar ---
    var _tab_y = 58;
    var _tab_h = 26;

    // BUY tab (left of center)
    var _buy_on = (_gc.shop_tab == 0);
    draw_set_color(_buy_on ? make_color_rgb(16, 32, 22) : make_color_rgb(12, 14, 20));
    draw_rectangle(400, _tab_y, 625, _tab_y + _tab_h, false);
    draw_set_color(_buy_on ? _accent : make_color_rgb(30, 42, 50));
    draw_rectangle(400, _tab_y, 625, _tab_y + _tab_h, true);
    draw_set_halign(fa_center);
    draw_set_color(_buy_on ? _accent : make_color_rgb(70, 88, 100));
    draw_text(512, _tab_y + 6, "BUY");

    // SELL tab (right of center)
    var _sell_on = (_gc.shop_tab == 1);
    draw_set_color(_sell_on ? make_color_rgb(32, 24, 10) : make_color_rgb(12, 14, 20));
    draw_rectangle(655, _tab_y, 880, _tab_y + _tab_h, false);
    draw_set_color(_sell_on ? make_color_rgb(220, 155, 45) : make_color_rgb(30, 42, 50));
    draw_rectangle(655, _tab_y, 880, _tab_y + _tab_h, true);
    draw_set_color(_sell_on ? make_color_rgb(220, 155, 45) : make_color_rgb(70, 88, 100));
    draw_text(767, _tab_y + 6, "SELL");

    // Q/E hint between tabs
    draw_set_color(make_color_rgb(50, 60, 80));
    draw_text(640, _tab_y + 6, "Q/E");
    draw_set_halign(fa_left);

    // Notification line (shifted below tab bar)
    if (_gc.shop_notification != "") {
        draw_set_halign(fa_center);
        var _is_sold_notif = (string_pos("Sold for", _gc.shop_notification) > 0);
        var _is_bad_notif  = (string_pos("Not enough", _gc.shop_notification) > 0);
        var _notif_col;
        if (_is_bad_notif) {
            _notif_col = c_red;
        } else if (_is_sold_notif) {
            _notif_col = c_yellow;
        } else {
            _notif_col = make_color_rgb(100, 220, 120);
        }
        draw_set_color(_notif_col);
        draw_text(640, 92, _gc.shop_notification);
        draw_set_halign(fa_left);
    }

    // Ornate gothic rim around the whole overlay. Drawn here (common to both Buy/Sell
    // branches) — the band sits OUTSIDE the content opening (20,20)-(1260,700), so the
    // list rows (x100..1180, y126+) never touch it. Title/gold raised to y24, hints to y684.
    ui_draw_gothic_frame(20, 20, 1260, 700, 20);

    var _rx0  = 100;
    var _rw   = 1080;
    var _rh   = 78;    // tall enough for 3 lines (stats + unique desc / class tag)
    var _rgap = 6;
    var _ry0  = 126;   // shifted down from 112 to make room for tab bar

    // =========================================================================
    // SELL TAB
    // =========================================================================
    if (_gc.shop_tab == 1) {

        // Build the sell list: stash equipment → stash consumables → carried equipment → carried consumables.
        // global.inventory[] (equipped slots) is excluded entirely.
        var _sl_items = [];
        var _sl_src   = [];
        var _sl_tags  = [];

        for (var _i = 0; _i < array_length(global.equipment_stash); _i++) {
            array_push(_sl_items, global.equipment_stash[_i]);
            array_push(_sl_src,   0);
            array_push(_sl_tags,  "[STASH]");
        }
        for (var _i = 0; _i < array_length(global.consumable_stash); _i++) {
            array_push(_sl_items, global.consumable_stash[_i]);
            array_push(_sl_src,   1);
            array_push(_sl_tags,  "[STASH]");
        }
        for (var _i = 0; _i < array_length(global.carried_items); _i++) {
            array_push(_sl_items, global.carried_items[_i]);
            array_push(_sl_src,   2);
            array_push(_sl_tags,  "[CARRIED]");
        }
        for (var _i = 0; _i < array_length(global.consumable_inventory); _i++) {
            array_push(_sl_items, global.consumable_inventory[_i]);
            array_push(_sl_src,   3);
            array_push(_sl_tags,  "[CARRIED]");
        }
        var _sl_count = array_length(_sl_items);

        if (_sl_count == 0) {
            draw_set_halign(fa_center);
            draw_set_color(make_color_rgb(90, 100, 120));
            draw_text(640, 320, "Nothing to sell.");
            draw_set_halign(fa_left);
        } else {
            var _sell_idx    = clamp(_gc.sell_index, 0, _sl_count - 1);
            var _sell_scroll = clamp(_gc.sell_scroll, 0, max(0, _sl_count - 7));
            var _visible_end = min(_sell_scroll + 7, _sl_count);

            for (var _ri = _sell_scroll; _ri < _visible_end; _ri++) {
                var _ry    = _ry0 + (_ri - _sell_scroll) * (_rh + _rgap);
                var _it    = _sl_items[_ri];
                var _is_sel = (_ri == _sell_idx);

                // Compute sell price
                var _gv = 0;
                if (variable_struct_exists(_it, "gold_value")) {
                    _gv = _it.gold_value;
                }
                if (_gv == 0 && variable_struct_exists(_it, "rarity")) {
                    if (_it.rarity == 0)      _gv = 15;
                    else if (_it.rarity == 1) _gv = 32;
                    else if (_it.rarity == 2) _gv = 82;
                    else if (_it.rarity == 3) _gv = 200;
                    else                      _gv = 400;
                }
                var _sprice = max(1, floor(_gv * 0.4));

                // Name color: rarity color for equipment, cyan for consumables
                var _name_col;
                if (variable_struct_exists(_it, "rarity")) {
                    _name_col = item_rarity_color(_it.rarity);
                } else {
                    _name_col = make_color_rgb(80, 210, 210);
                }

                // Row background
                draw_set_alpha(_is_sel ? 1.0 : 0.55);
                draw_set_color(_is_sel ? make_color_rgb(30, 26, 10) : make_color_rgb(14, 18, 28));
                draw_rectangle(_rx0, _ry, _rx0 + _rw, _ry + _rh, false);
                draw_set_alpha(1.0);
                draw_set_color(_is_sel ? make_color_rgb(200, 155, 40) : make_color_rgb(55, 50, 25));
                draw_rectangle(_rx0, _ry, _rx0 + _rw, _ry + _rh, true);

                // Icon badge — gear icon for equipment, consumable badge otherwise
                var _sell_is_equip = variable_struct_exists(_it, "slot");
                var _sell_tx = _rx0 + 16;
                if (_sell_is_equip) {
                    ui_draw_item_icon(_rx0 + 10, _ry + 8, 32, _it);
                    _sell_tx = _rx0 + 50;
                } else {
                    ui_draw_consumable_icon(_rx0 + 10, _ry + 8, 32, _it);
                    _sell_tx = _rx0 + 50;
                }
                // Name
                draw_set_color(_name_col);
                draw_text(_sell_tx, _ry + 8, _it.name);
                // Stats or consumable description
                if (_sell_is_equip) {
                    draw_set_color(c_white);
                    draw_text(_sell_tx, _ry + 30, ui_item_stat_str(_it));
                    if (variable_struct_exists(_it, "unique_desc") && _it.unique_desc != "") {
                        draw_set_color(make_color_rgb(200, 160, 40));
                        draw_text(_sell_tx, _ry + 50, _it.unique_desc);
                    } else if (_it.effect_desc != "") {
                        draw_set_color(make_color_rgb(95, 105, 130));
                        draw_text(_sell_tx, _ry + 50, _it.effect_desc);
                    }
                } else {
                    var _cdesc = variable_struct_exists(_it, "description") ? _it.description : "";
                    draw_set_color(make_color_rgb(130, 140, 155));
                    draw_text(_sell_tx, _ry + 30, _cdesc);
                }
                // Right side: source tag + sell price + class restriction if any
                draw_set_halign(fa_right);
                draw_set_color(make_color_rgb(155, 165, 180));
                draw_text(_rx0 + _rw - 16, _ry + 8, _sl_tags[_ri]);
                draw_set_color(c_yellow);
                draw_text(_rx0 + _rw - 16, _ry + 30, string(_sprice) + "g");
                if (variable_struct_exists(_it, "class_req") && _it.class_req != -1) {
                    var _cr_labels = ["Arcanist", "Bloodwarden", "Shadowstrider"];
                    draw_set_color(make_color_rgb(160, 110, 60));
                    draw_text(_rx0 + _rw - 16, _ry + 50, "[" + _cr_labels[_it.class_req] + "]");
                }
                draw_set_halign(fa_left);
            }

            // Scroll indicator
            if (_sl_count > 7) {
                draw_set_halign(fa_center);
                draw_set_color(make_color_rgb(80, 90, 110));
                draw_text(640, _ry0 + 7 * (_rh + _rgap) + 4, "W/S to scroll  (" + string(_sl_count) + " items)");
                draw_set_halign(fa_left);
            }
        }

        // Confirm bar for rare+ items (amber highlight)
        if (_gc.sell_confirm_name != "") {
            var _cf_y = 636;
            draw_set_color(make_color_rgb(50, 30, 8));
            draw_rectangle(100, _cf_y, 1180, _cf_y + 46, false);
            draw_set_color(make_color_rgb(220, 145, 40));
            draw_rectangle(100, _cf_y, 1180, _cf_y + 46, true);
            draw_set_halign(fa_center);
            draw_set_color(c_white);
            draw_text(640, _cf_y + 12, _gc.shop_notification + "   [SPACE] Confirm   [ESC] Cancel");
            draw_set_halign(fa_left);
        }

        // Sell tab footer — swaps to confirm hint when rare+ item confirmation is pending
        draw_set_halign(fa_center);
        draw_set_color(make_color_rgb(75, 85, 105));
        if (_gc.sell_confirm_name != "") {
            draw_text(640, 684, "SPACE to confirm   ESC to cancel");
        } else {
            draw_text(640, 684, "W/S: Navigate   Q/E: Buy/Sell   Enter: Sell   Esc: Close");
        }
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        draw_set_alpha(1.0);
        return;
    }

    // =========================================================================
    // BUY TAB — unchanged buy content
    // =========================================================================

    // -------------------------------------------------------------------------
    // PETRA — 4 standard consumables always, plus optional limited special
    // -------------------------------------------------------------------------
    if (_is_petra) {
        var _has_spec  = (global.petra_stock_special != undefined && global.petra_special_qty > 0);
        var _row_count = 4 + (_has_spec ? 1 : 0);

        for (var _ri = 0; _ri < _row_count; _ri++) {
            var _ry      = _ry0 + _ri * (_rh + _rgap);
            var _is_sel  = (_ri == _gc.shop_index);
            var _is_spec = (_ri == 4);

            var _it;
            var _price;
            if (_is_spec) {
                _it    = global.petra_stock_special;
                _price = cha_price(floor(_it.gold_value * 2));
            } else {
                _it    = global.consumables_standard[_ri];
                _price = cha_price(floor(_it.gold_value * 1.5));
            }

            draw_set_alpha(_is_sel ? 1.0 : 0.55);
            draw_set_color(_is_sel ? make_color_rgb(16, 42, 50) : make_color_rgb(14, 18, 28));
            draw_rectangle(_rx0, _ry, _rx0 + _rw, _ry + _rh, false);
            draw_set_alpha(1.0);
            draw_set_color(_is_sel ? make_color_rgb(55, 170, 170) : make_color_rgb(38, 75, 85));
            draw_rectangle(_rx0, _ry, _rx0 + _rw, _ry + _rh, true);

            // Icon badge
            ui_draw_consumable_icon(_rx0 + 10, _ry + 10, 40, _it);

            // Name
            draw_set_color(make_color_rgb(80, 210, 210));
            draw_text(_rx0 + 60, _ry + 10, _it.name);

            // Description
            draw_set_color(make_color_rgb(130, 160, 170));
            draw_text(_rx0 + 60, _ry + 38, _it.description);

            // Limited tag
            if (_is_spec) {
                draw_set_color(make_color_rgb(255, 155, 30));
                draw_set_halign(fa_right);
                draw_text(_rx0 + _rw - 150, _ry + 10, "[LIMITED — " + string(global.petra_special_qty) + " left]");
                draw_set_halign(fa_left);
            }

            // Price (right-aligned)
            var _can_afford = (global.gold >= _price);
            draw_set_color(_can_afford ? c_yellow : make_color_rgb(180, 80, 80));
            draw_set_halign(fa_right);
            draw_text(_rx0 + _rw - 16, _ry + 38, string(_price) + "g");
            draw_set_halign(fa_left);
        }

    // -------------------------------------------------------------------------
    // DORN — rotating gear list; sold entries appear greyed with SOLD tag
    // -------------------------------------------------------------------------
    } else {
        var _dorn_count = array_length(global.dorn_stock);

        for (var _ri = 0; _ri < _dorn_count; _ri++) {
            var _ry      = _ry0 + _ri * (_rh + _rgap);
            var _entry   = global.dorn_stock[_ri];
            var _is_sold = _entry.sold;
            var _is_sel  = (!_is_sold && _ri == _gc.shop_index);

            draw_set_alpha(_is_sold ? 0.28 : (_is_sel ? 1.0 : 0.55));
            draw_set_color(_is_sel ? make_color_rgb(38, 28, 10) : make_color_rgb(14, 18, 28));
            draw_rectangle(_rx0, _ry, _rx0 + _rw, _ry + _rh, false);
            draw_set_alpha(1.0);
            draw_set_color(_is_sold ? make_color_rgb(45, 45, 45)
                         : (_is_sel ? make_color_rgb(195, 135, 38) : make_color_rgb(75, 58, 28)));
            draw_rectangle(_rx0, _ry, _rx0 + _rw, _ry + _rh, true);

            if (_is_sold) {
                draw_set_color(make_color_rgb(65, 65, 65));
                draw_text(_rx0 + 16, _ry + 10, _entry.item.name);
                draw_set_halign(fa_right);
                draw_set_color(make_color_rgb(75, 75, 75));
                draw_text(_rx0 + _rw - 16, _ry + 28, "SOLD");
                draw_set_halign(fa_left);
            } else {
                var _rcol = item_rarity_color(_entry.item.rarity);
                // Icon badge
                ui_draw_item_icon(_rx0 + 10, _ry + 8, 32, _entry.item);
                // Name + rarity right-aligned
                draw_set_color(_rcol);
                draw_text(_rx0 + 50, _ry + 8, _entry.item.name);
                draw_set_halign(fa_right);
                draw_text(_rx0 + _rw - 16, _ry + 8, "[" + item_rarity_name(_entry.item.rarity) + "]");
                draw_set_halign(fa_left);
                // Stat string
                draw_set_color(c_white);
                draw_text(_rx0 + 50, _ry + 30, ui_item_stat_str(_entry.item));
                // Flavor or unique below stats
                if (variable_struct_exists(_entry.item, "unique_desc") && _entry.item.unique_desc != "") {
                    draw_set_color(make_color_rgb(255, 200, 50));
                    draw_text(_rx0 + 50, _ry + 50, _entry.item.unique_desc);
                } else if (_entry.item.effect_desc != "") {
                    draw_set_color(make_color_rgb(95, 105, 130));
                    draw_text(_rx0 + 50, _ry + 50, _entry.item.effect_desc);
                }
                // Slot label right-aligned (so buyers know wep/arm/boot at a glance)
                if (variable_struct_exists(_entry.item, "slot")) {
                    draw_set_halign(fa_right);
                    draw_set_color(make_color_rgb(120, 135, 160));
                    draw_text(_rx0 + _rw - 16, _ry + 50, item_slot_label(_entry.item.slot));
                    draw_set_halign(fa_left);
                }
                // Price right-aligned (CHA-discounted)
                var _eprice     = cha_price(_entry.price);
                var _can_afford = (global.gold >= _eprice);
                draw_set_color(_can_afford ? c_yellow : make_color_rgb(180, 80, 80));
                draw_set_halign(fa_right);
                draw_text(_rx0 + _rw - 16, _ry + 30, string(_eprice) + "g");
                draw_set_halign(fa_left);
            }
        }
    }

    // Buy tab footer (raised from 695 to clear the bottom rim band)
    draw_set_halign(fa_center);
    draw_set_color(make_color_rgb(75, 85, 105));
    draw_text(640, 684, "W/S: Navigate   Q/E: Buy/Sell   Enter: Buy   Esc: Close     Purchases go to your stash.");
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
}

// ---------------------------------------------------------------------------
// ui_draw_stash_screen()
// Two-column stash management overlay drawn in the hub.
// Left column: items taken on the run (at risk). Right: safe stash.
// Called by obj_hub_controller Draw_64 after the history overlay.
// ---------------------------------------------------------------------------
function ui_draw_stash_screen() {
    if (!instance_exists(obj_game_controller)) return;
    var _gc = instance_find(obj_game_controller, 0);
    if (!_gc.stash_mode_open) return;

    // Full-screen opaque cover
    draw_set_alpha(1.0);
    draw_set_color(make_color_rgb(8, 10, 18));
    draw_rectangle(0, 0, 1280, 720, false);

    // Title
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_color(c_white);
    draw_text_transformed(640, 24, "ITEM STASH", 1.3, 1.3, 0);   // y24 keeps the title inside the rim opening

    // Subtitle warning
    draw_set_color(make_color_rgb(180, 150, 80));
    draw_text(640, 54, "Equipped gear is always safe.   Carried items are lost on death (1 random salvage).");
    draw_set_halign(fa_left);

    var _ly      = 82;
    var _col_w   = 570;
    var _row_h   = 50;
    var _max_bot = 680;

    // Build left list: carried equipment then consumable_inventory
    var _left_items = [];
    var _left_types = [];  // 0 = equipment, 1 = consumable
    for (var _i = 0; _i < array_length(global.carried_items); _i++) {
        array_push(_left_items, global.carried_items[_i]);
        array_push(_left_types, 0);
    }
    for (var _i = 0; _i < array_length(global.consumable_inventory); _i++) {
        array_push(_left_items, global.consumable_inventory[_i]);
        array_push(_left_types, 1);
    }

    // Build right list: equipment_stash then consumable_stash
    var _right_items = [];
    var _right_types = [];
    for (var _i = 0; _i < array_length(global.equipment_stash); _i++) {
        array_push(_right_items, global.equipment_stash[_i]);
        array_push(_right_types, 0);
    }
    for (var _i = 0; _i < array_length(global.consumable_stash); _i++) {
        array_push(_right_items, global.consumable_stash[_i]);
        array_push(_right_types, 1);
    }

    var _left_active  = (_gc.stash_mode_side == 0);
    var _right_active = (_gc.stash_mode_side == 1);

    // ---- LEFT COLUMN ----
    var _lx = 30;
    draw_set_color(_left_active ? make_color_rgb(80, 160, 220) : make_color_rgb(45, 55, 75));
    draw_rectangle(_lx, _ly, _lx + _col_w, _max_bot, true);

    draw_set_color(make_color_rgb(200, 100, 80));
    draw_text(_lx + 10, _ly + 6, "TAKING ON RUN  (at risk)");

    var _item_y = _ly + 30;
    for (var _i = 0; _i < array_length(_left_items); _i++) {
        if (_item_y + _row_h > _max_bot) break;
        var _it     = _left_items[_i];
        var _is_sel = (_left_active && _gc.stash_mode_index == _i);

        draw_set_alpha(_is_sel ? 0.9 : 0.5);
        draw_set_color(_is_sel ? make_color_rgb(30, 50, 80) : make_color_rgb(18, 22, 38));
        draw_rectangle(_lx + 4, _item_y, _lx + _col_w - 4, _item_y + _row_h - 2, false);
        draw_set_alpha(1.0);

        var _col = (_left_types[_i] == 1) ? make_color_rgb(80, 220, 220) : item_rarity_color(_it.rarity);
        if (_left_types[_i] == 0) ui_draw_item_icon(_lx + 8, _item_y + 5, 20, _it);
        else                      ui_draw_consumable_icon(_lx + 8, _item_y + 5, 20, _it);
        var _stl_tx = _lx + 34;
        draw_set_color(_col);
        draw_text(_stl_tx, _item_y + 5, _it.name);
        draw_set_color(make_color_rgb(140, 150, 170));
        draw_text(_stl_tx, _item_y + 26, (_left_types[_i] == 1) ? _it.description : ui_item_stat_str(_it));

        _item_y += _row_h;
    }
    if (array_length(_left_items) == 0) {
        draw_set_color(make_color_rgb(70, 80, 100));
        draw_text(_lx + 12, _ly + 38, "Nothing in pack.");
    }

    // ---- RIGHT COLUMN ----
    var _rx = 680;
    draw_set_color(_right_active ? make_color_rgb(80, 160, 220) : make_color_rgb(45, 55, 75));
    draw_rectangle(_rx, _ly, _rx + _col_w, _max_bot, true);

    draw_set_color(make_color_rgb(100, 200, 100));
    draw_text(_rx + 10, _ly + 6, "STASH  (safe)");

    _item_y = _ly + 30;
    for (var _i = 0; _i < array_length(_right_items); _i++) {
        if (_item_y + _row_h > _max_bot) break;
        var _it     = _right_items[_i];
        var _is_sel = (_right_active && _gc.stash_mode_index == _i);

        draw_set_alpha(_is_sel ? 0.9 : 0.5);
        draw_set_color(_is_sel ? make_color_rgb(30, 50, 80) : make_color_rgb(18, 22, 38));
        draw_rectangle(_rx + 4, _item_y, _rx + _col_w - 4, _item_y + _row_h - 2, false);
        draw_set_alpha(1.0);

        var _col = (_right_types[_i] == 1) ? make_color_rgb(80, 220, 220) : item_rarity_color(_it.rarity);
        if (_right_types[_i] == 0) ui_draw_item_icon(_rx + 8, _item_y + 5, 20, _it);
        else                       ui_draw_consumable_icon(_rx + 8, _item_y + 5, 20, _it);
        var _str_tx = _rx + 34;
        draw_set_color(_col);
        draw_text(_str_tx, _item_y + 5, _it.name);
        draw_set_color(make_color_rgb(140, 150, 170));
        draw_text(_str_tx, _item_y + 26, (_right_types[_i] == 1) ? _it.description : ui_item_stat_str(_it));

        _item_y += _row_h;
    }
    if (array_length(_right_items) == 0) {
        draw_set_color(make_color_rgb(70, 80, 100));
        draw_text(_rx + 12, _ly + 38, "Nothing in stash.");
    }

    // Footer (raised from 698 to clear the bottom rim band)
    draw_set_halign(fa_center);
    draw_set_color(c_gray);
    draw_text(640, 684, "Q/E: Switch Side   W/S: Navigate   Enter: Move Item   Esc: Close");
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);

    // Ornate gothic rim around the whole overlay. Columns (x70..640 / 680..1250) and the
    // y82..680 lists sit inside the opening (20,20)-(1260,700); the tooltip draws on top after.
    ui_draw_gothic_frame(20, 20, 1260, 700, 20);

    // Hover tooltip — scan both columns for the moused-over item
    var _hmx_st = device_mouse_x_to_gui(0);
    var _hmy_st = device_mouse_y_to_gui(0);
    var _st_hover = undefined;
    var _hy_l = _ly + 30;
    for (var _sthi = 0; _sthi < array_length(_left_items) && _st_hover == undefined; _sthi++) {
        if (_hy_l + _row_h > _max_bot) break;
        if (_hmx_st >= _lx + 4 && _hmx_st < _lx + _col_w - 4
                && _hmy_st >= _hy_l && _hmy_st < _hy_l + _row_h - 2) {
            _st_hover = _left_items[_sthi];
        }
        _hy_l += _row_h;
    }
    if (_st_hover == undefined) {
        var _hy_r = _ly + 30;
        for (var _sthi = 0; _sthi < array_length(_right_items); _sthi++) {
            if (_hy_r + _row_h > _max_bot) break;
            if (_hmx_st >= _rx + 4 && _hmx_st < _rx + _col_w - 4
                    && _hmy_st >= _hy_r && _hmy_st < _hy_r + _row_h - 2) {
                _st_hover = _right_items[_sthi];
                break;
            }
            _hy_r += _row_h;
        }
    }
    if (_st_hover != undefined) {
        ui_draw_item_tooltip(_hmx_st + 14, _hmy_st - 20, _st_hover, undefined);
        // Alt+click on an equipment item opens the comparison panel
        if (mouse_check_button_pressed(mb_left) && keyboard_check(vk_alt)
                && variable_struct_exists(_st_hover, "slot")) {
            _gc.comparison_item     = _st_hover;
            _gc.comparison_equipped = undefined;
            if (variable_global_exists("inventory")) {
                var _cmp_si = equip_slot_index(_st_hover.slot);
                if (_cmp_si >= 0 && _cmp_si < array_length(global.inventory)) {
                    _gc.comparison_equipped = global.inventory[_cmp_si];
                }
            }
            _gc.comparison_open = true;
        }
    }

    draw_set_alpha(1.0);
}


// ---------------------------------------------------------------------------
// _cmp_stat_name(st)  — readable display name for an affix stat_type string
// ---------------------------------------------------------------------------
function _cmp_stat_name(st) {
    switch (st) {
        case "STR":       return "Strength";
        case "DEX":       return "Dexterity";
        case "CON":       return "Constitution";
        case "INT":       return "Intelligence";
        case "WIS":       return "Wisdom";
        case "CHA":       return "Charisma";
        case "armor":     return "Armor";
        case "el_resist": return "Elem. Resist";
        case "crit":      return "Crit Chance";
        case "dodge":     return "Dodge";
        case "max_hp":    return "Max HP";
        case "gold_find": return "Gold Find";
        default:          return st;
    }
}


// ---------------------------------------------------------------------------
// ui_draw_comparison_panel(new_item, equipped_item)
// Stat-delta comparison overlay centered on screen.
// equipped_item may be undefined (slot is empty).
// ---------------------------------------------------------------------------
function ui_draw_comparison_panel(new_item, equipped_item) {
    // Collect stat totals from each item's affixes
    var _sn = {};
    var _se = {};
    if (variable_struct_exists(new_item, "affixes")) {
        for (var _i = 0; _i < array_length(new_item.affixes); _i++) {
            var _a = new_item.affixes[_i];
            if (!variable_struct_exists(_sn, _a.stat_type)) _sn[$ _a.stat_type] = 0;
            _sn[$ _a.stat_type] += _a.stat_value;
        }
    }
    if (equipped_item != undefined && variable_struct_exists(equipped_item, "affixes")) {
        for (var _i = 0; _i < array_length(equipped_item.affixes); _i++) {
            var _a = equipped_item.affixes[_i];
            if (!variable_struct_exists(_se, _a.stat_type)) _se[$ _a.stat_type] = 0;
            _se[$ _a.stat_type] += _a.stat_value;
        }
    }

    // Union of all stat keys from both items
    var _keys = [];
    var _kn = variable_struct_get_names(_sn);
    for (var _i = 0; _i < array_length(_kn); _i++) array_push(_keys, _kn[_i]);
    var _ke = variable_struct_get_names(_se);
    for (var _i = 0; _i < array_length(_ke); _i++) {
        var _dup = false;
        for (var _j = 0; _j < array_length(_keys); _j++) {
            if (_keys[_j] == _ke[_i]) { _dup = true; break; }
        }
        if (!_dup) array_push(_keys, _ke[_i]);
    }

    // Panel sizing — grows with row count
    var _row_h  = 28;
    var _hdr_h  = 78;
    var _ftr_h  = 26;
    var _nrows  = max(array_length(_keys), 1);
    var _pw     = 500;
    var _ph     = _hdr_h + _nrows * _row_h + _ftr_h;
    var _px     = 640 - _pw / 2;
    var _py     = 360 - _ph / 2;
    var _mid    = _px + _pw / 2;
    var _cl     = _px + 10;
    var _cr     = _mid + 10;

    // Background and border
    draw_set_alpha(0.96);
    draw_set_color(make_color_rgb(10, 12, 22));
    draw_rectangle(_px, _py, _px + _pw, _py + _ph, false);
    draw_set_alpha(1.0);
    draw_set_color(make_color_rgb(90, 90, 140));
    draw_rectangle(_px, _py, _px + _pw, _py + _ph, true);

    // Title bar
    draw_set_color(make_color_rgb(55, 60, 95));
    draw_rectangle(_px, _py, _px + _pw, _py + 22, false);
    draw_set_color(c_white);
    draw_set_halign(fa_center);
    draw_text(640, _py + 4, "ITEM COMPARISON");

    // New item header (left half)
    var _nc = variable_struct_exists(new_item, "rarity") ? item_rarity_color(new_item.rarity) : c_white;
    draw_set_halign(fa_left);
    draw_set_color(_nc);
    draw_text(_cl, _py + 26, new_item.name);
    draw_set_color(make_color_rgb(105, 115, 140));
    draw_text(_cl, _py + 44, string_upper(new_item.slot));
    draw_set_color(make_color_rgb(70, 190, 70));
    draw_text(_cl, _py + 60, "[New]");

    // Equipped item header (right half)
    if (equipped_item != undefined) {
        var _ec = variable_struct_exists(equipped_item, "rarity") ? item_rarity_color(equipped_item.rarity) : c_white;
        draw_set_color(_ec);
        draw_text(_cr, _py + 26, equipped_item.name);
        draw_set_color(make_color_rgb(105, 115, 140));
        draw_text(_cr, _py + 44, string_upper(equipped_item.slot));
        draw_set_color(make_color_rgb(200, 180, 60));
        draw_text(_cr, _py + 60, "[Equipped]");
    } else {
        draw_set_color(make_color_rgb(95, 95, 105));
        draw_text(_cr, _py + 26, "Nothing Equipped");
        draw_set_color(make_color_rgb(65, 65, 75));
        draw_text(_cr, _py + 44, string_upper(new_item.slot) + " slot empty");
    }

    // Divider lines
    draw_set_color(make_color_rgb(55, 60, 95));
    draw_line(_px + 6, _py + _hdr_h - 4, _px + _pw - 6, _py + _hdr_h - 4);
    draw_line(_mid,    _py + _hdr_h,      _mid,           _py + _ph - _ftr_h);

    // Stat rows
    if (array_length(_keys) == 0) {
        draw_set_color(make_color_rgb(95, 95, 115));
        draw_set_halign(fa_center);
        draw_text(640, _py + _hdr_h + 8, "No stat affixes");
    }
    for (var _i = 0; _i < array_length(_keys); _i++) {
        var _sk    = _keys[_i];
        var _ry    = _py + _hdr_h + _i * _row_h;
        var _nv    = variable_struct_exists(_sn, _sk) ? _sn[$ _sk] : 0;
        var _ev    = variable_struct_exists(_se, _sk) ? _se[$ _sk] : 0;
        var _delta = _nv - _ev;

        // Stat name
        draw_set_color(make_color_rgb(170, 175, 200));
        draw_set_halign(fa_left);
        draw_text(_cl, _ry + 6, _cmp_stat_name(_sk));

        // New item value (right edge of left half)
        draw_set_color(c_white);
        draw_set_halign(fa_right);
        draw_text(_mid - 8, _ry + 6, (_nv > 0 ? "+" : "") + string(_nv));

        // Equipped value (left edge of right half)
        if (equipped_item != undefined) {
            draw_set_color(make_color_rgb(150, 150, 160));
            draw_set_halign(fa_left);
            draw_text(_cr, _ry + 6, (_ev > 0 ? "+" : "") + string(_ev));
        }

        // Delta (far right, color-coded)
        if (_delta != 0) {
            var _dcol = (_delta > 0) ? make_color_rgb(80, 230, 80) : make_color_rgb(230, 80, 80);
            var _darr = (_delta > 0) ? " ^" : " v";
            draw_set_color(_dcol);
            draw_set_halign(fa_right);
            draw_text(_px + _pw - 8, _ry + 6,
                ((_delta > 0) ? "+" : "") + string(_delta) + _darr);
        } else {
            draw_set_color(make_color_rgb(120, 120, 135));
            draw_set_halign(fa_right);
            draw_text(_px + _pw - 8, _ry + 6, "=");
        }
    }

    // Footer close hint
    draw_set_halign(fa_center);
    draw_set_color(make_color_rgb(95, 95, 115));
    draw_text(640, _py + _ph - 20, "Alt+Click or ESC to close");

    draw_set_halign(fa_left);
    draw_set_alpha(1.0);
}


// ---------------------------------------------------------------------------
// ui_draw_trainer_screen()
// Full-screen overlay for Vex the Trainer (trainer_open). Four sections:
//   tab 0 Stats — 200g + a Rare+ item per +1 permanent stat
//   tab 1 Trait Slots — 800g / 2000g for +1 / +2 active-trait slots
//   tab 2 Abilities — 500g to unlock a non-starter ability into the loadout pool
//   tab 3 Potency — sacrifice 5 permanent stat points for +10% trait strength
// Drawn by obj_hub_controller Draw_64 after ui_draw_shop_screen().
// ---------------------------------------------------------------------------
function ui_draw_trainer_screen() {
    if (!instance_exists(obj_game_controller)) return;
    var _gc = instance_find(obj_game_controller, 0);
    if (!variable_instance_exists(_gc, "trainer_open") || !_gc.trainer_open) return;

    var _accent   = make_color_rgb(160, 115, 225);   // Vex violet
    var _class_id = variable_global_exists("chosen_class") ? global.chosen_class : 0;
    var _class_names = ["Arcanist", "Bloodwarden", "Shadowstrider"];

    // Full-screen dark cover
    draw_set_alpha(0.97);
    draw_set_color(make_color_rgb(8, 8, 16));
    draw_rectangle(0, 0, 1280, 720, false);
    draw_set_alpha(1.0);

    // Title + gold
    draw_set_valign(fa_top);
    draw_set_halign(fa_center);
    draw_set_color(_accent);
    draw_text_transformed(640, 24, "VEX THE TRAINER", 1.5, 1.5, 0);   // y24 keeps the title inside the rim opening
    draw_set_halign(fa_right);
    draw_set_color(c_yellow);
    draw_text(1250, 24, "Gold: " + string(global.gold) + "g");        // pulled in from x1260 to clear the right band

    // --- Tab bar (5 tabs) ---
    var _tab_labels = ["STATS", "TRAIT SLOTS", "ABILITIES", "TRAITS", "POTENCY"];
    for (var _t = 0; _t < 5; _t++) {
        var _tx  = 45 + _t * 240;
        var _on  = (_gc.trainer_tab == _t);
        draw_set_color(_on ? make_color_rgb(28, 18, 48) : make_color_rgb(12, 13, 20));
        draw_rectangle(_tx, 64, _tx + 230, 96, false);
        draw_set_color(_on ? _accent : make_color_rgb(40, 40, 60));
        draw_rectangle(_tx, 64, _tx + 230, 96, true);
        draw_set_halign(fa_center);
        draw_set_color(_on ? c_white : make_color_rgb(95, 95, 125));
        draw_text(_tx + 115, 72, _tab_labels[_t]);
    }

    // --- Notification line ---
    if (_gc.trainer_notification != "") {
        draw_set_halign(fa_center);
        var _is_warn = (string_pos("Beware", _gc.trainer_notification) > 0);
        var _is_bad  = (string_pos("Not enough", _gc.trainer_notification) > 0
                     || string_pos("Need", _gc.trainer_notification) > 0
                     || string_pos("need a", _gc.trainer_notification) > 0);
        draw_set_color(_is_warn ? make_color_rgb(255, 90, 90)
                     : (_is_bad ? make_color_rgb(230, 130, 70)
                                : make_color_rgb(120, 220, 140)));
        draw_text(640, 112, _gc.trainer_notification);
    }

    var _rx0 = 120;
    var _rx1 = 1160;
    var _ry0 = 150;
    var _rh  = 58;
    var _rgap = 6;

    draw_set_halign(fa_left);

    // =====================================================================
    // TAB 0: PERMANENT STAT UPGRADES
    // =====================================================================
    if (_gc.trainer_tab == 0) {
        var _stat_keys  = ["perm_str_bonus","perm_dex_bonus","perm_con_bonus","perm_int_bonus","perm_wis_bonus","perm_cha_bonus"];
        var _stat_names = ["STR","DEX","CON","INT","WIS","CHA"];
        for (var _i = 0; _i < 6; _i++) {
            var _ry  = _ry0 + _i * (_rh + _rgap);
            var _sel = (_gc.trainer_cursor == _i);
            var _cur = variable_global_exists(_stat_keys[_i]) ? variable_global_get(_stat_keys[_i]) : 0;

            draw_set_color(_sel ? make_color_rgb(26, 18, 44) : make_color_rgb(14, 15, 24));
            draw_rectangle(_rx0, _ry, _rx1, _ry + _rh, false);
            draw_set_color(_sel ? _accent : make_color_rgb(38, 40, 60));
            draw_rectangle(_rx0, _ry, _rx1, _ry + _rh, true);

            draw_set_color(_sel ? c_white : make_color_rgb(180, 185, 210));
            draw_text(_rx0 + 16, _ry + 6, _stat_names[_i] + "   (current permanent bonus: +" + string(_cur) + ")");
            draw_set_color(make_color_rgb(120, 125, 150));
            draw_text(_rx0 + 16, _ry + 30, "Raise this stat permanently by +1.");

            draw_set_halign(fa_right);
            draw_set_color(c_yellow);
            draw_text(_rx1 - 16, _ry + 6, string(cha_price(200)) + "g  +  1 Rare+ item");
            draw_set_halign(fa_left);
        }

        // Trade-item readout
        var _trade = trainer_find_rare_item();
        draw_set_halign(fa_center);
        if (_trade != undefined) {
            draw_set_color(make_color_rgb(120, 200, 140));
            draw_text(640, 560, "Trade item ready: " + _trade.item.name + "  (" + item_rarity_name(_trade.rarity) + ")  —  the lowest-value Rare+ item is used.");
        } else {
            draw_set_color(make_color_rgb(210, 120, 70));
            draw_text(640, 560, "No Rare or better item in your stash/pack to trade.");
        }
        draw_set_halign(fa_left);
    }

    // =====================================================================
    // TAB 1: TRAIT SLOT EXPANSION
    // =====================================================================
    else if (_gc.trainer_tab == 1) {
        var _bts   = variable_global_exists("bonus_trait_slots") ? global.bonus_trait_slots : 0;
        var _total = 2 + _bts;

        // Single action row (kept at the standard first-row position so the mouse
        // hit-test in obj_game_controller Step matches).
        var _ry  = _ry0;
        var _maxed = (_bts >= 2);
        var _cost  = cha_price((_bts == 0) ? 800 : 2000);

        draw_set_color(_maxed ? make_color_rgb(16, 18, 26) : make_color_rgb(26, 18, 44));
        draw_rectangle(_rx0, _ry, _rx1, _ry + _rh, false);
        draw_set_color(_maxed ? make_color_rgb(40, 42, 58) : _accent);
        draw_rectangle(_rx0, _ry, _rx1, _ry + _rh, true);

        if (_maxed) {
            draw_set_color(make_color_rgb(110, 200, 130));
            draw_text(_rx0 + 16, _ry + 18, "All trait slots purchased — you have the maximum of 4.");
        } else {
            draw_set_color(c_white);
            draw_text(_rx0 + 16, _ry + 6, "Unlock trait slot #" + string(_total + 1));
            draw_set_color(make_color_rgb(120, 125, 150));
            draw_text(_rx0 + 16, _ry + 30, "Permanently raises your base active-trait slots to " + string(_total + 1) + ".");
            draw_set_halign(fa_right);
            draw_set_color(c_yellow);
            draw_text(_rx1 - 16, _ry + 18, string(_cost) + "g");
            draw_set_halign(fa_left);
        }

        // Info block (below the row — text only, no hit-test)
        draw_set_halign(fa_center);
        draw_set_color(make_color_rgb(190, 160, 240));
        draw_text(640, 280, "Active Trait Slots:  " + string(_total) + "   (base 2  +  " + string(_bts) + " purchased)");
        draw_set_color(make_color_rgb(120, 125, 150));
        draw_text(640, 312, "Buy extra slots to equip more traits at once. Maximum +2 (4 total).");
        draw_set_color(make_color_rgb(90, 95, 120));
        draw_text(640, 336, "Stacks on top of Crown of the Hollow King while it is equipped.");
        draw_set_halign(fa_left);
    }

    // =====================================================================
    // TAB 2: ABILITY UNLOCKS
    // =====================================================================
    else if (_gc.trainer_tab == 2) {
        draw_set_halign(fa_center);
        draw_set_color(make_color_rgb(140, 145, 175));
        draw_text(640, 124, "Class: " + _class_names[clamp(_class_id, 0, 2)] + "   —   unlocked abilities can be slotted in your loadout.");
        draw_set_halign(fa_left);

        var _locked = class_vex_purchasable(_class_id);
        if (array_length(_locked) == 0) {
            draw_set_halign(fa_center);
            draw_set_color(make_color_rgb(110, 200, 130));
            draw_text(640, 330, "Every purchasable ability for this class is unlocked.");
            draw_set_color(make_color_rgb(110, 115, 145));
            draw_text(640, 360, "Some abilities unlock through progression instead — see your loadout.");
            draw_set_halign(fa_left);
        } else {
            // Taller rows than the other tabs so the full ability description fits
            // on two wrapped lines without spilling outside the row.
            var _ab_rh      = 78;
            var _ab_max_vis = 6;
            var _ab_scroll  = loadout_list_scroll(_gc.trainer_cursor, array_length(_locked), _ab_max_vis);
            for (var _i = _ab_scroll; _i < min(array_length(_locked), _ab_scroll + _ab_max_vis); _i++) {
                var _ab   = _locked[_i];
                var _ry   = _ry0 + (_i - _ab_scroll) * (_ab_rh + _rgap);
                var _sel  = (_gc.trainer_cursor == _i);
                var _cost = ability_unlock_cost(_ab.name);

                draw_set_color(_sel ? make_color_rgb(26, 18, 44) : make_color_rgb(14, 15, 24));
                draw_rectangle(_rx0, _ry, _rx1, _ry + _ab_rh, false);
                draw_set_color(_sel ? _accent : make_color_rgb(38, 40, 60));
                draw_rectangle(_rx0, _ry, _rx1, _ry + _ab_rh, true);

                // Ability icon — 56×56 badge on the left of the row
                draw_set_alpha(1.0);
                ui_draw_ability_icon(_rx0 + 11, _ry + 11, 56, _ab);
                var _ab_textx = _rx0 + 11 + 56 + 12;

                draw_set_color(_sel ? c_white : make_color_rgb(180, 185, 210));
                draw_text(_ab_textx, _ry + 8, _ab.name);
                // Canonical full description (damage clause + every effect) plus the
                // melee/ranged attack-class tag — the complete explanation, wrapped.
                var _ab_desc = ability_describe(_ab);
                var _ab_tag  = ability_attack_class_tag(_ab);
                if (_ab_tag != "") _ab_desc = (_ab_desc != "") ? (_ab_desc + "  " + _ab_tag) : _ab_tag;
                draw_set_color(make_color_rgb(135, 142, 170));
                draw_text_ext(_ab_textx, _ry + 32, _ab_desc, 19, (_rx1 - 16) - _ab_textx);

                draw_set_halign(fa_right);
                draw_set_color(c_yellow);
                draw_text(_rx1 - 16, _ry + 8, "[" + string(_ab.energy_cost) + " AP]   " + string(_cost) + "g");
                draw_set_halign(fa_left);
            }
            if (_ab_scroll > 0) {
                draw_set_halign(fa_center); draw_set_color(_accent);
                draw_text(640, _ry0 - 16, "▲ more above");
            }
            if (_ab_scroll + _ab_max_vis < array_length(_locked)) {
                draw_set_halign(fa_center); draw_set_color(_accent);
                draw_text(640, _ry0 + _ab_max_vis * (_ab_rh + _rgap) - 2, "▼ more below");
            }
            draw_set_halign(fa_left);
        }
    }

    // =====================================================================
    // TAB 3: TRAIT UNLOCKS (gold + a rarity-matched item)
    // =====================================================================
    else if (_gc.trainer_tab == 3) {
        draw_set_halign(fa_center);
        draw_set_color(make_color_rgb(140, 145, 175));
        draw_text(640, 124, "Class: " + _class_names[clamp(_class_id, 0, 2)]
            + "   —   unlocked traits can be equipped at the Dungeon Gate.");
        draw_set_halign(fa_left);

        var _tr_locked = trait_vex_purchasable(_class_id);
        if (array_length(_tr_locked) == 0) {
            draw_set_halign(fa_center);
            draw_set_color(make_color_rgb(110, 200, 130));
            draw_text(640, 330, "Every trait available to this class is unlocked.");
            draw_set_halign(fa_left);
        } else {
            // Window to 7 rows (not 8) so the bottom trade-item readout at y=626
            // never overlaps the last row. Must match the Step hit-test window.
            var _tr_max_vis = 7;
            var _tr_scroll  = loadout_list_scroll(_gc.trainer_cursor, array_length(_tr_locked), _tr_max_vis);
            for (var _i = _tr_scroll; _i < min(array_length(_tr_locked), _tr_scroll + _tr_max_vis); _i++) {
                var _tt    = _tr_locked[_i];
                var _ry    = _ry0 + (_i - _tr_scroll) * (_rh + _rgap);
                var _sel   = (_gc.trainer_cursor == _i);
                var _tcost = trait_unlock_cost(_tt.name);
                var _afford = (global.gold >= _tcost.gold) && trainer_has_item(_tcost.min_rarity);

                draw_set_color(_sel ? make_color_rgb(26, 18, 44) : make_color_rgb(14, 15, 24));
                draw_rectangle(_rx0, _ry, _rx1, _ry + _rh, false);
                draw_set_color(_sel ? _accent : make_color_rgb(38, 40, 60));
                draw_rectangle(_rx0, _ry, _rx1, _ry + _rh, true);

                draw_set_color(_sel ? c_white : make_color_rgb(180, 185, 210));
                draw_text(_rx0 + 16, _ry + 6, _tt.name
                    + (_tt.class_req != -1 ? "   (" + _class_names[clamp(_tt.class_req, 0, 2)] + ")" : ""));
                draw_set_color(make_color_rgb(120, 125, 150));
                draw_text(_rx0 + 16, _ry + 30, _tt.description);

                draw_set_halign(fa_right);
                draw_set_color(_afford ? c_yellow : make_color_rgb(150, 90, 90));
                draw_text(_rx1 - 16, _ry + 6, string(_tcost.gold) + "g");
                draw_set_color(_afford ? make_color_rgb(180, 160, 230) : make_color_rgb(150, 90, 90));
                draw_text(_rx1 - 16, _ry + 30, "+ 1 " + _tcost.item_label + " item");
                draw_set_halign(fa_left);
            }
            if (_tr_scroll > 0) {
                draw_set_halign(fa_center); draw_set_color(_accent);
                draw_text(640, _ry0 - 16, "▲ more above");
            }
            if (_tr_scroll + _tr_max_vis < array_length(_tr_locked)) {
                draw_set_halign(fa_center); draw_set_color(_accent);
                draw_text(640, _ry0 + _tr_max_vis * (_rh + _rgap) - 2, "▼ more below");
            }
            draw_set_halign(fa_left);
        }

        // Trade-item readout (mirrors the Stats tab)
        var _tr_sel_cost = (array_length(_tr_locked) > 0)
            ? trait_unlock_cost(_tr_locked[clamp(_gc.trainer_cursor, 0, array_length(_tr_locked) - 1)].name)
            : { gold:0, min_rarity:2, item_label:"Rare" };
        var _tr_trade = trainer_find_item(_tr_sel_cost.min_rarity);
        draw_set_halign(fa_center);
        if (_tr_trade != undefined) {
            draw_set_color(make_color_rgb(120, 200, 140));
            draw_text(640, 626, "Trade item ready: " + _tr_trade.item.name + "  ("
                + item_rarity_name(_tr_trade.rarity) + ")  —  lowest-value " + _tr_sel_cost.item_label + "+ item is used.");
        } else {
            draw_set_color(make_color_rgb(210, 120, 70));
            draw_text(640, 626, "No " + _tr_sel_cost.item_label + " or better item in your stash/pack for this trait.");
        }
        draw_set_halign(fa_left);
    }

    // =====================================================================
    // TAB 4: TRAIT POTENCY (stat sacrifice)
    // =====================================================================
    else if (_gc.trainer_tab == 4) {
        var _ups = trait_upgradable_list();
        for (var _i = 0; _i < array_length(_ups); _i++) {
            var _up   = _ups[_i];
            var _ry   = _ry0 + _i * (_rh + _rgap);
            var _sel  = (_gc.trainer_cursor == _i);
            var _tier = trait_potency_tier(_up.name);

            draw_set_color(_sel ? make_color_rgb(26, 18, 44) : make_color_rgb(14, 15, 24));
            draw_rectangle(_rx0, _ry, _rx1, _ry + _rh, false);
            draw_set_color(_sel ? _accent : make_color_rgb(38, 40, 60));
            draw_rectangle(_rx0, _ry, _rx1, _ry + _rh, true);

            draw_set_color(_sel ? c_white : make_color_rgb(180, 185, 210));
            draw_text(_rx0 + 16, _ry + 6, _up.name);
            draw_set_color(make_color_rgb(120, 125, 150));
            draw_text(_rx0 + 16, _ry + 30, _up.effect + "   —   Tier " + string(_tier) + " / 5   (+" + string(_tier * 10) + "% now)");

            // Tier pips
            for (var _p = 0; _p < 5; _p++) {
                var _px2 = _rx0 + 540 + _p * 18;
                draw_set_color(_p < _tier ? _accent : make_color_rgb(45, 47, 66));
                draw_rectangle(_px2, _ry + 8, _px2 + 13, _ry + 22, false);
            }

            draw_set_halign(fa_right);
            if (_tier >= 5) {
                draw_set_color(make_color_rgb(110, 200, 130));
                draw_text(_rx1 - 16, _ry + 6, "MAX  (+50%)");
            } else {
                draw_set_color(c_yellow);
                draw_text(_rx1 - 16, _ry + 6, "Sacrifice 5 (any stat)");
                draw_set_color(make_color_rgb(120, 125, 150));
                draw_text(_rx1 - 16, _ry + 30, "Enter: choose a stat to spend");
            }
            draw_set_halign(fa_left);
        }

        // Confirmation bar (non-refundable sacrifice)
        if (_gc.trainer_confirm) {
            draw_set_color(make_color_rgb(50, 12, 12));
            draw_rectangle(_rx0, 658, _rx1, 694, false);
            draw_set_color(make_color_rgb(200, 60, 60));
            draw_rectangle(_rx0, 658, _rx1, 694, true);
            draw_set_halign(fa_center);
            draw_set_color(make_color_rgb(255, 110, 110));
            draw_text(640, 668, "Beware, what you are about to do can not be undone.   [ Space ] Confirm     [ Esc ] Cancel");
            draw_set_halign(fa_left);
        }
    }

    // --- Controls hint (raised from 702 to clear the bottom rim band) ---
    draw_set_halign(fa_center);
    draw_set_color(make_color_rgb(70, 75, 100));
    draw_text(640, 684, "W/S: Navigate    Q/E: Section    Enter: Buy / Select    Tab: Examine    Esc: Close");
    draw_set_halign(fa_left);

    // Ornate gothic rim around the whole overlay (matches the other NPC shops).
    ui_draw_gothic_frame(20, 20, 1260, 700, 20);

    // --- Tab detail popup over the Abilities (2) / Traits (3) sections ---
    if (variable_instance_exists(_gc, "vex_detail_open") && _gc.vex_detail_open) {
        if (_gc.trainer_tab == 2) {
            var _vd_ap = class_vex_purchasable(_class_id);
            if (_gc.trainer_cursor < array_length(_vd_ap)) ui_draw_ability_detail(_vd_ap[_gc.trainer_cursor]);
        } else if (_gc.trainer_tab == 3) {
            var _vd_tp = trait_vex_purchasable(_class_id);
            if (_gc.trainer_cursor < array_length(_vd_tp)) ui_draw_trait_detail(_vd_tp[_gc.trainer_cursor]);
        }
    }

    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
}

// ---------------------------------------------------------------------------
// ui_draw_trainer_statpick()
// Vex tab-4 popup: choose a stat to sacrifice 5 permanent points from for a trait
// potency upgrade. Lists all 6 stats with available points (base allocation +
// bought bonus). Geometry MUST match the hit-testing in obj_game_controller/
// Step_0 (_sp_px 440, _sp_pw 400, _sp_y0 250, _sp_rh 40). No-op when not open.
// ---------------------------------------------------------------------------
function ui_draw_trainer_statpick() {
    if (!instance_exists(obj_game_controller)) return;
    var _gc = instance_find(obj_game_controller, 0);
    if (!variable_instance_exists(_gc, "trainer_statpick_open") || !_gc.trainer_statpick_open) return;

    var _stats = ["STR", "DEX", "CON", "INT", "WIS", "CHA"];
    var _alloc = (variable_instance_exists(_gc, "trainer_statpick_alloc")
                  && array_length(_gc.trainer_statpick_alloc) == 6)
                 ? _gc.trainer_statpick_alloc : [0, 0, 0, 0, 0, 0];
    var _total = 0;
    for (var _t = 0; _t < 6; _t++) _total += _alloc[_t];

    // Geometry MUST match the hit-testing in obj_game_controller/Step_0.
    var _px = 420, _pw = 440, _py = 170, _ph = 440, _y0 = 250, _rh = 40;
    var _minus_x = _px + _pw - 96;
    var _plus_x  = _px + _pw - 48;

    // Dim + panel
    draw_set_alpha(0.6); draw_set_color(c_black);
    draw_rectangle(0, 0, display_get_gui_width(), display_get_gui_height(), false);
    draw_set_alpha(0.97); draw_set_color(make_color_rgb(22, 20, 34));
    draw_rectangle(_px, _py, _px + _pw, _py + _ph, false);
    draw_set_alpha(1.0); draw_set_color(make_color_rgb(150, 140, 180));
    draw_rectangle(_px, _py, _px + _pw, _py + _ph, true);

    // Header — wrapped so long trait names never overflow the panel.
    var _hw = _pw - 32;
    draw_set_halign(fa_center); draw_set_valign(fa_top);
    draw_set_color(make_color_rgb(255, 225, 150));
    draw_text_ext(_px + _pw / 2, _py + 12, "Raise " + _gc.trainer_statpick_trait + " potency", 22, _hw);
    draw_set_color(c_ltgray);
    draw_text_ext(_px + _pw / 2, _py + 44, "Spend 5 points total — use − / + on any stats", 20, _hw);
    draw_set_halign(fa_left);

    // Stat rows: name · (have N) · [-] alloc [+]
    for (var _i = 0; _i < 6; _i++) {
        var _ry    = _y0 + _i * _rh;
        var _have  = stat_available_points(_stats[_i]);
        var _a     = _alloc[_i];
        var _sel   = (_gc.trainer_statpick_cursor == _i);
        var _can_inc = (_total < 5 && _a < _have);

        if (_sel) {
            draw_set_alpha(0.30); draw_set_color(make_color_rgb(120, 100, 160));
            draw_rectangle(_px + 16, _ry, _px + _pw - 16, _ry + _rh - 4, false);
            draw_set_alpha(1.0);
            draw_set_color(make_color_rgb(170, 150, 210));
            draw_rectangle(_px + 16, _ry, _px + _pw - 16, _ry + _rh - 4, true);
        }

        // Stat name + how many points are available to spend.
        draw_set_halign(fa_left); draw_set_valign(fa_top);
        draw_set_color((_have > 0) ? c_white : make_color_rgb(120, 90, 90));
        draw_text(_px + 28, _ry + 8, _stats[_i]);
        draw_set_color(make_color_rgb(120, 125, 150));
        draw_text(_px + 96, _ry + 8, "have " + string(_have));

        // [-] button (dim when nothing allocated).
        draw_set_color(_a > 0 ? make_color_rgb(200, 120, 120) : make_color_rgb(70, 60, 70));
        draw_rectangle(_minus_x, _ry + 6, _minus_x + 32, _ry + _rh - 10, true);
        draw_set_halign(fa_center);
        draw_text(_minus_x + 16, _ry + 8, "−");

        // Allocated amount.
        draw_set_color(_a > 0 ? c_yellow : make_color_rgb(120, 120, 140));
        draw_text((_minus_x + 32 + _plus_x) / 2, _ry + 8, string(_a));

        // [+] button (dim when capped by availability or the 5-point total).
        draw_set_color(_can_inc ? make_color_rgb(130, 200, 140) : make_color_rgb(60, 70, 60));
        draw_rectangle(_plus_x, _ry + 6, _plus_x + 32, _ry + _rh - 10, true);
        draw_text(_plus_x + 16, _ry + 8, "+");
        draw_set_halign(fa_left);
    }

    // Running total.
    draw_set_halign(fa_center);
    draw_set_color(_total == 5 ? make_color_rgb(120, 210, 130) : c_yellow);
    draw_text(_px + _pw / 2, _y0 + 6 * _rh + 6, "Total: " + string(_total) + " / 5");
    draw_set_halign(fa_left);

    // Footer / confirm
    if (variable_instance_exists(_gc, "trainer_statpick_confirm") && _gc.trainer_statpick_confirm) {
        draw_set_alpha(0.95); draw_set_color(make_color_rgb(120, 40, 40));
        draw_rectangle(_px + 16, _py + _ph - 70, _px + _pw - 16, _py + _ph - 36, false);
        draw_set_alpha(1.0);
        draw_set_halign(fa_center); draw_set_color(c_white);
        draw_text_ext(_px + _pw / 2, _py + _ph - 64, "Sacrifice these 5 points permanently? Cannot be undone.", 18, _pw - 40);
        draw_set_color(c_ltgray);
        draw_text(_px + _pw / 2, _py + _ph - 24, "Enter: confirm     Esc: back");
    } else {
        draw_set_halign(fa_center); draw_set_color(c_ltgray);
        draw_text_ext(_px + _pw / 2, _py + _ph - 30, "W/S: Stat    A/D or −/+: Adjust    Enter: Confirm    Esc: Cancel", 16, _pw - 32);
    }

    draw_set_halign(fa_left); draw_set_valign(fa_top);
    draw_set_color(c_white); draw_set_alpha(1.0);
}

// Draws one Maren list-row background (row index _i) and returns the text baseline y.
function ui_maren_row(_i, _selected, _base_y = 190) {
    var _ry = _base_y + _i * 48;
    draw_set_color(_selected ? make_color_rgb(45, 38, 66) : make_color_rgb(20, 18, 30));
    draw_rectangle(200, _ry, 1080, _ry + 44, false);
    draw_set_color(_selected ? make_color_rgb(150, 110, 220) : make_color_rgb(45, 42, 62));
    draw_rectangle(200, _ry, 1080, _ry + 44, true);
    return _ry + 10;
}

// ---------------------------------------------------------------------------
// ui_draw_maren_screen()
// Maren the Runesmith — rune socketing overlay (Phase 1: Socket gear + Runes).
// Layout constants MUST match the Maren input block in obj_game_controller Step.
// ---------------------------------------------------------------------------
function ui_draw_maren_screen() {
    if (!instance_exists(obj_game_controller)) return;
    var _gc = instance_find(obj_game_controller, 0);
    if (!variable_instance_exists(_gc, "maren_open") || !_gc.maren_open) return;

    // Full-screen overlay
    draw_set_alpha(1.0);
    draw_set_color(make_color_rgb(10, 8, 16));
    draw_rectangle(0, 0, 1280, 720, false);

    // Title + dust
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_color(make_color_rgb(180, 150, 230));
    draw_text_transformed(640, 24, "Maren the Runesmith", 1.4, 1.4, 0);
    draw_set_halign(fa_right);
    draw_set_color(make_color_rgb(200, 180, 130));
    var _dust = variable_global_exists("rune_dust") ? global.rune_dust : 0;
    draw_text(1240, 32, "Rune Dust: " + string(_dust));
    // Player gold, under the dust readout
    draw_set_color(c_yellow);
    draw_text(1240, 56, "Gold: " + string(global.gold) + "g");
    draw_set_halign(fa_left);

    // Tab bar (4 tabs) — x=245+t*200, y=70, w=190, h=40
    var _tab_labels = ["Socket Gear", "Aspects", "Forge", "Runes"];
    for (var _t = 0; _t < 4; _t++) {
        var _tx  = 245 + _t * 200;
        var _on  = (_gc.maren_tab == _t);
        draw_set_color(_on ? make_color_rgb(45, 35, 70) : make_color_rgb(22, 20, 34));
        draw_rectangle(_tx, 70, _tx + 190, 110, false);
        draw_set_color(_on ? make_color_rgb(150, 110, 220) : make_color_rgb(55, 50, 75));
        draw_rectangle(_tx, 70, _tx + 190, 110, true);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_set_color(_on ? c_white : make_color_rgb(150, 150, 170));
        draw_text(_tx + 95, 90, _tab_labels[_t]);
    }
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);

    var _row_y0 = 190;
    var _list_x = 200;
    var _list_x2 = 1080;
    var _cursor = _gc.maren_cursor;

    if (_gc.maren_tab == 0) {
        // -------- SOCKET GEAR TAB --------
        var _slots = maren_socketable_slots();

        if (_gc.maren_phase == 0) {
            // Breadcrumb
            draw_set_color(make_color_rgb(140, 130, 165));
            draw_text(_list_x, 150, "Choose a piece of gear to socket:");

            if (array_length(_slots) == 0) {
                draw_set_color(make_color_rgb(120, 115, 140));
                draw_text(_list_x, _row_y0 + 8, "No socketed gear equipped. Uncommon+ items have sockets — equip some first.");
            }
            for (var _i = 0; _i < array_length(_slots); _i++) {
                var _it = global.inventory[_slots[_i]];
                item_ensure_sockets(_it);
                var _ty = ui_maren_row(_i, _i == _cursor);
                draw_set_color(item_rarity_color(_it.rarity));
                draw_text(_list_x + 16, _ty, _it.name);
                draw_set_halign(fa_right);
                draw_set_color(make_color_rgb(170, 160, 190));
                draw_text(_list_x2 - 16, _ty,
                    string(array_length(_it.runes)) + " / " + string(_it.socket_count) + " sockets filled");
                draw_set_halign(fa_left);
            }
        } else if (_gc.maren_phase == 1) {
            var _it = global.inventory[_gc.maren_item_sel];
            item_ensure_sockets(_it);
            draw_set_color(make_color_rgb(140, 130, 165));
            draw_text(_list_x, 150, "Sockets on ");
            draw_set_color(item_rarity_color(_it.rarity));
            draw_text(_list_x + 90, 150, _it.name);
            draw_set_color(make_color_rgb(110, 105, 130));
            draw_text(_list_x, 168, "Enter a filled socket to remove its rune, or an empty socket to add one.");

            var _filled = array_length(_it.runes);
            for (var _s = 0; _s < _it.socket_count; _s++) {
                var _ty2 = ui_maren_row(_s, _s == _cursor);
                if (_s < _filled) {
                    draw_set_color(make_color_rgb(150, 200, 255));
                    draw_text(_list_x + 16, _ty2, rune_describe(_it.runes[_s]));
                    draw_set_halign(fa_right);
                    draw_set_color(make_color_rgb(150, 110, 110));
                    draw_text(_list_x2 - 16, _ty2, "Enter: remove");
                    draw_set_halign(fa_left);
                } else {
                    draw_set_color(make_color_rgb(110, 110, 130));
                    draw_text(_list_x + 16, _ty2, "[ Empty Socket ]");
                    draw_set_halign(fa_right);
                    draw_set_color(make_color_rgb(120, 160, 120));
                    draw_text(_list_x2 - 16, _ty2, "Enter: add rune");
                    draw_set_halign(fa_left);
                }
            }
        } else {
            // phase 2 — choose a gear rune to socket
            var _gear = rune_inventory_indices("gear");
            draw_set_color(make_color_rgb(140, 130, 165));
            draw_text(_list_x, 150, "Choose a gear rune to socket:");
            if (array_length(_gear) == 0) {
                draw_set_color(make_color_rgb(120, 115, 140));
                draw_text(_list_x, _row_y0 + 8, "No gear runes in inventory.");
            }
            for (var _g = 0; _g < array_length(_gear); _g++) {
                var _rn = global.rune_inventory[_gear[_g]];
                var _ty3 = ui_maren_row(_g, _g == _cursor);
                draw_set_color(make_color_rgb(150, 200, 255));
                draw_text(_list_x + 16, _ty3, rune_describe(_rn));
            }
        }
    } else if (_gc.maren_tab == 1) {
        // -------- ASPECTS TAB (character Aspect slots) --------
        var _slots_n = variable_global_exists("aspect_slots") ? global.aspect_slots : 2;
        var _socked  = variable_global_exists("aspect_runes") ? global.aspect_runes : [];
        var _cap     = aspect_slot_cap();

        if (_gc.maren_phase == 0) {
            draw_set_color(make_color_rgb(140, 130, 165));
            draw_text(_list_x, 150, "Aspect slots (" + string(array_length(_socked)) + " / " + string(_slots_n) + " filled). Buff action categories in combat.");
            draw_text(_list_x, 168, "Enter a filled slot to remove its rune, an empty slot to add one.");

            // One row per unlocked slot, then an optional unlock row.
            for (var _s = 0; _s < _slots_n; _s++) {
                var _tya = ui_maren_row(_s, _s == _cursor);
                if (_s < array_length(_socked)) {
                    draw_set_color(make_color_rgb(230, 200, 120));
                    draw_text(_list_x + 16, _tya, rune_describe(_socked[_s]));
                    draw_set_halign(fa_right);
                    draw_set_color(make_color_rgb(150, 110, 110));
                    draw_text(_list_x2 - 16, _tya, "Enter: remove");
                    draw_set_halign(fa_left);
                } else {
                    draw_set_color(make_color_rgb(110, 110, 130));
                    draw_text(_list_x + 16, _tya, "[ Empty Aspect Slot ]");
                    draw_set_halign(fa_right);
                    draw_set_color(make_color_rgb(120, 160, 120));
                    draw_text(_list_x2 - 16, _tya, "Enter: add aspect rune");
                    draw_set_halign(fa_left);
                }
            }
            // Unlock-next-slot row
            if (_slots_n < _cap) {
                var _cost = aspect_slot_unlock_cost();
                var _tyu = ui_maren_row(_slots_n, _slots_n == _cursor);
                var _afford = (global.gold >= _cost.gold)
                              && variable_global_exists("rune_dust") && global.rune_dust >= _cost.dust;
                draw_set_color(_afford ? make_color_rgb(150, 220, 150) : make_color_rgb(150, 120, 120));
                draw_text(_list_x + 16, _tyu, "[ Unlock +1 Aspect Slot ]");
                draw_set_halign(fa_right);
                draw_set_color(make_color_rgb(200, 180, 130));
                draw_text(_list_x2 - 16, _tyu, string(_cost.gold) + "g  +  " + string(_cost.dust) + " Dust");
                draw_set_halign(fa_left);
            }
        } else {
            // phase 1 — choose an aspect rune to socket
            var _asp = rune_inventory_indices("aspect");
            draw_set_color(make_color_rgb(140, 130, 165));
            draw_text(_list_x, 150, "Choose an aspect rune to socket:");
            if (array_length(_asp) == 0) {
                draw_set_color(make_color_rgb(120, 115, 140));
                draw_text(_list_x, _row_y0 + 8, "No aspect runes in inventory.");
            }
            for (var _a = 0; _a < array_length(_asp); _a++) {
                var _rna = global.rune_inventory[_asp[_a]];
                var _tya2 = ui_maren_row(_a, _a == _cursor);
                draw_set_color(make_color_rgb(230, 200, 120));
                draw_text(_list_x + 16, _tya2, rune_describe(_rna));
            }
        }
    } else if (_gc.maren_tab == 2) {
        // -------- FORGE TAB (Combine / Split / Craft Flagship) --------
        if (_gc.maren_phase == 0) {
            draw_set_color(make_color_rgb(140, 130, 165));
            draw_text(_list_x, 150, "Maren's Forge — reshape your runes.");
            var _menu = ["Combine   (3 identical  →  1 next tier)",
                         "Split   (1 rune  →  one tier lower  +  dust)",
                         "Craft Flagship   (forge a rare Quickcast / Echo)"];
            for (var _fm = 0; _fm < 3; _fm++) {
                var _tyf = ui_maren_row(_fm, _fm == _cursor);
                draw_set_color(make_color_rgb(210, 190, 240));
                draw_text(_list_x + 16, _tyf, _menu[_fm]);
            }
        } else if (_gc.maren_phase == 1) {
            // Combine: 3-of-a-kind groups
            var _groups = rune_combine_groups();
            draw_set_color(make_color_rgb(140, 130, 165));
            draw_text(_list_x, 150, "Combine — choose a set of three to fuse:");
            if (array_length(_groups) == 0) {
                draw_set_color(make_color_rgb(120, 115, 140));
                draw_text(_list_x, _row_y0 + 8, "No 3-of-a-kind runes (same type AND tier) available.");
            }
            for (var _gi = 0; _gi < array_length(_groups); _gi++) {
                var _grp  = _groups[_gi];
                var _ccst = rune_combine_cost(_grp.tier);
                var _tyc  = ui_maren_row(_gi, _gi == _cursor);
                var _caff = (global.gold >= _ccst.gold) && (_dust >= _ccst.dust);
                draw_set_color(_caff ? make_color_rgb(150, 200, 255) : make_color_rgb(120, 110, 130));
                draw_text(_list_x + 16, _tyc,
                    "3x " + _grp.name + " " + rune_tier_roman(_grp.tier)
                    + "  ->  " + _grp.name + " " + rune_tier_roman(_grp.tier + 1)
                    + "   (have " + string(_grp.count) + ")");
                draw_set_halign(fa_right);
                draw_set_color(make_color_rgb(200, 180, 130));
                draw_text(_list_x2 - 16, _tyc, string(_ccst.gold) + "g  +  " + string(_ccst.dust) + " Dust");
                draw_set_halign(fa_left);
            }
        } else if (_gc.maren_phase == 2) {
            // Split: any owned rune
            draw_set_color(make_color_rgb(140, 130, 165));
            draw_text(_list_x, 150, "Split — choose a rune to break down (" + string(rune_split_cost().gold) + "g):");
            if (array_length(global.rune_inventory) == 0) {
                draw_set_color(make_color_rgb(120, 115, 140));
                draw_text(_list_x, _row_y0 + 8, "No runes to split.");
            }
            for (var _si = 0; _si < array_length(global.rune_inventory); _si++) {
                var _sr  = global.rune_inventory[_si];
                var _tys = ui_maren_row(_si, _si == _cursor);
                draw_set_color(make_color_rgb(150, 200, 255));
                draw_text(_list_x + 16, _tys, rune_describe(_sr));
                draw_set_halign(fa_right);
                draw_set_color(make_color_rgb(200, 180, 130));
                var _db = rune_split_dust(_sr.tier);
                var _yield = (_sr.tier > 1)
                    ? (_sr.name + " " + rune_tier_roman(_sr.tier - 1) + "  +  " + string(_db) + " Dust")
                    : (string(_db) + " Dust");
                draw_text(_list_x2 - 16, _tys, "->  " + _yield);
                draw_set_halign(fa_left);
            }
        } else {
            // Craft Flagship
            var _flags = rune_flagship_ids();
            var _fc    = flagship_craft_cost();
            draw_set_color(make_color_rgb(140, 130, 165));
            draw_text(_list_x, 150, "Craft Flagship — forge a tier III rune (" + string(_fc.gold) + "g  +  " + string(_fc.dust) + " Dust):");
            var _faff = (global.gold >= _fc.gold) && (_dust >= _fc.dust);
            for (var _fi = 0; _fi < array_length(_flags); _fi++) {
                var _fdef = rune_get(_flags[_fi]);
                var _tyfl = ui_maren_row(_fi, _fi == _cursor);
                draw_set_color(_faff ? make_color_rgb(230, 200, 120) : make_color_rgb(120, 110, 130));
                draw_text(_list_x + 16, _tyfl, _fdef.name + " III — " + _fdef.blurb);
            }
        }
    } else {
        // -------- RUNES TAB (read-only owned list) --------
        draw_set_color(make_color_rgb(140, 130, 165));
        draw_text(_list_x, 150, "Runes owned (" + string(array_length(global.rune_inventory)) + "):");
        if (array_length(global.rune_inventory) == 0) {
            draw_set_color(make_color_rgb(120, 115, 140));
            draw_text(_list_x, _row_y0 + 8, "No runes yet. Elites and bosses drop them.");
        }
        for (var _r = 0; _r < array_length(global.rune_inventory); _r++) {
            var _rn2  = global.rune_inventory[_r];
            var _def2 = rune_get(_rn2.id);
            var _aspect = (_def2 != undefined && _def2.domain == "aspect");
            var _ty4 = ui_maren_row(_r, _r == _cursor);
            draw_set_color(_aspect ? make_color_rgb(230, 200, 120) : make_color_rgb(150, 200, 255));
            draw_text(_list_x + 16, _ty4, rune_describe(_rn2));
            draw_set_halign(fa_right);
            draw_set_color(make_color_rgb(130, 125, 150));
            draw_text(_list_x2 - 16, _ty4, _aspect ? "Aspect" : "Gear");
            draw_set_halign(fa_left);
        }
    }

    // Notification line
    if (_gc.maren_notification != "") {
        draw_set_halign(fa_center);
        draw_set_color(make_color_rgb(220, 200, 150));
        draw_text(640, 666, _gc.maren_notification);
        draw_set_halign(fa_left);
    }

    // Controls hint (raised from 702 to clear the bottom rim band)
    draw_set_halign(fa_center);
    draw_set_color(make_color_rgb(70, 70, 95));
    draw_text(640, 684, "W/S: Navigate    Q/E: Tab    Enter: Select    Esc: Back / Close");
    draw_set_halign(fa_left);

    // Ornate gothic rim around the whole overlay. Opening (20,20)-(1260,700) keeps the
    // band fully on-screen while containing the title (y24), currency (x1240), tabs and
    // content. Drawn last so it sits on top.
    ui_draw_gothic_frame(20, 20, 1260, 700, 20);

    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
}

// ---------------------------------------------------------------------------
// ui_draw_sable_screen()
// Sable the Alchemist — Salvage / Brew / Upgrade overlay. Reuses ui_maren_row
// for row geometry. Layout constants MUST match the Sable input block in
// obj_game_controller Step. (Tabs at x=345+t*200, mirroring Maren's 3-tab bar.)
// ---------------------------------------------------------------------------
function ui_draw_sable_screen() {
    if (!instance_exists(obj_game_controller)) return;
    var _gc = instance_find(obj_game_controller, 0);
    if (!variable_instance_exists(_gc, "sable_open") || !_gc.sable_open) return;

    draw_set_alpha(1.0);
    draw_set_color(make_color_rgb(10, 14, 12));
    draw_rectangle(0, 0, 1280, 720, false);

    // Title + dust
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_color(make_color_rgb(150, 210, 170));
    draw_text_transformed(640, 24, "Sable the Alchemist", 1.4, 1.4, 0);
    draw_set_halign(fa_right);
    draw_set_color(make_color_rgb(200, 180, 130));
    var _dust = variable_global_exists("rune_dust") ? global.rune_dust : 0;
    draw_text(1240, 32, "Rune Dust: " + string(_dust) + "    Gold: " + string(global.gold));
    draw_set_halign(fa_left);

    // Tab bar (4 tabs) — x=345+t*200, y=70, w=190
    var _tab_labels = ["Salvage", "Brew", "Upgrade", "Rebirth"];
    for (var _t = 0; _t < 4; _t++) {
        var _tx = 345 + _t * 200;
        var _on = (_gc.sable_tab == _t);
        draw_set_color(_on ? make_color_rgb(30, 50, 38) : make_color_rgb(20, 28, 24));
        draw_rectangle(_tx, 70, _tx + 190, 110, false);
        draw_set_color(_on ? make_color_rgb(110, 200, 140) : make_color_rgb(50, 70, 58));
        draw_rectangle(_tx, 70, _tx + 190, 110, true);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_set_color(_on ? c_white : make_color_rgb(150, 160, 150));
        draw_text(_tx + 95, 90, _tab_labels[_t]);
    }
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);

    var _row_y0 = 190;
    var _list_x = 200;
    var _list_x2 = 1080;
    var _cursor = _gc.sable_cursor;

    if (_gc.sable_tab == 0) {
        // -------- SALVAGE TAB --------
        if (_gc.sable_phase == 0) {
            draw_set_color(make_color_rgb(140, 160, 145));
            draw_text(_list_x, 150, "Salvage unwanted loot into rune dust:");
            var _menu = ["Salvage Gear   (unequipped pack + stash)",
                         "Salvage Runes   (unsocketed — fully scrapped)"];
            for (var _sm = 0; _sm < 2; _sm++) {
                var _tys = ui_maren_row(_sm, _sm == _cursor);
                draw_set_color(make_color_rgb(190, 220, 195));
                draw_text(_list_x + 16, _tys, _menu[_sm]);
            }
        } else if (_gc.sable_phase == 1) {
            // Gear list
            var _gear = sable_salvageable_gear();
            draw_set_color(make_color_rgb(140, 160, 145));
            draw_text(_list_x, 150, "Choose gear to salvage (Common 1 / Uncommon 2 / Rare 5 / Epic 10 / Legendary 20):");
            if (array_length(_gear) == 0) {
                draw_set_color(make_color_rgb(120, 130, 122));
                draw_text(_list_x, _row_y0 + 8, "No unequipped gear to salvage.");
            }
            for (var _gi = 0; _gi < array_length(_gear); _gi++) {
                var _it  = _gear[_gi].item;
                var _tyg = ui_maren_row(_gi, _gi == _cursor);
                draw_set_color(item_rarity_color(_it.rarity));
                draw_text(_list_x + 16, _tyg, _it.name + "  (" + item_rarity_name(_it.rarity) + ")");
                draw_set_halign(fa_right);
                draw_set_color(make_color_rgb(200, 180, 130));
                draw_text(_list_x2 - 16, _tyg, "+" + string(sable_salvage_gear_dust(_it.rarity)) + " Dust  [" + _gear[_gi].source + "]");
                draw_set_halign(fa_left);
            }
        } else {
            // Rune list
            draw_set_color(make_color_rgb(140, 160, 145));
            draw_text(_list_x, 150, "Choose a rune to scrap for dust (I 6 / II 16 / III 40):");
            var _rinv = variable_global_exists("rune_inventory") ? global.rune_inventory : [];
            if (array_length(_rinv) == 0) {
                draw_set_color(make_color_rgb(120, 130, 122));
                draw_text(_list_x, _row_y0 + 8, "No unsocketed runes to scrap.");
            }
            for (var _ri = 0; _ri < array_length(_rinv); _ri++) {
                var _rn  = _rinv[_ri];
                var _tyr = ui_maren_row(_ri, _ri == _cursor);
                var _def = rune_get(_rn.id);
                var _asp = (_def != undefined && _def.domain == "aspect");
                draw_set_color(_asp ? make_color_rgb(230, 200, 120) : make_color_rgb(150, 200, 255));
                draw_text(_list_x + 16, _tyr, rune_describe(_rn));
                draw_set_halign(fa_right);
                draw_set_color(make_color_rgb(200, 180, 130));
                draw_text(_list_x2 - 16, _tyr, "+" + string(sable_salvage_rune_dust(_rn.tier)) + " Dust");
                draw_set_halign(fa_left);
            }
        }
    } else if (_gc.sable_tab == 1) {
        // -------- BREW TAB --------
        var _brew = sable_brew_catalog();
        var _slots_used = variable_global_exists("consumable_inventory") ? array_length(global.consumable_inventory) : 0;
        draw_set_color(make_color_rgb(140, 160, 145));
        draw_text(_list_x, 150, "Brew a potion  (you hold " + string(_slots_used) + " consumables):");
        for (var _bi = 0; _bi < array_length(_brew); _bi++) {
            var _b   = _brew[_bi];
            var _tyb = ui_maren_row(_bi, _bi == _cursor);
            var _aff = (global.gold >= _b.gold) && (_dust >= _b.dust);
            draw_set_color(_aff ? make_color_rgb(190, 220, 195) : make_color_rgb(120, 130, 122));
            draw_text(_list_x + 16, _tyb, _b.name + "  —  " + _b.desc);
            draw_set_halign(fa_right);
            draw_set_color(make_color_rgb(200, 180, 130));
            draw_text(_list_x2 - 16, _tyb, string(_b.gold) + "g  +  " + string(_b.dust) + " Dust");
            draw_set_halign(fa_left);
        }
    } else if (_gc.sable_tab == 2) {
        // -------- UPGRADE TAB --------
        var _groups = sable_upgrade_groups();
        var _ucost = sable_upgrade_cost();
        draw_set_color(make_color_rgb(140, 160, 145));
        draw_text(_list_x, 150, "Fuse 3 identical potions into their improved form (" + string(_ucost.gold) + "g + " + string(_ucost.dust) + " Dust):");
        if (array_length(_groups) == 0) {
            draw_set_color(make_color_rgb(120, 130, 122));
            draw_text(_list_x, _row_y0 + 8, "No potion held 3+ times with an upgrade. (Standard potions only.)");
        }
        for (var _ui = 0; _ui < array_length(_groups); _ui++) {
            var _g   = _groups[_ui];
            var _tyu = ui_maren_row(_ui, _ui == _cursor);
            var _uaff = (global.gold >= _ucost.gold) && (_dust >= _ucost.dust);
            draw_set_color(_uaff ? make_color_rgb(190, 220, 195) : make_color_rgb(120, 130, 122));
            draw_text(_list_x + 16, _tyu, "3x " + _g.from + "  ->  " + _g.to + "   (have " + string(_g.count) + ")");
        }
    } else {
        // -------- REBIRTH TAB --------
        var _reb = item_picker_candidates_class_specific();
        draw_set_color(make_color_rgb(140, 160, 145));
        draw_text(_list_x, 150, "Alchemical Rebirth — reforge a class-locked item into a different class's item:");
        // Cost reference
        draw_set_color(make_color_rgb(120, 140, 128));
        draw_text(_list_x, 176, "Cost by rarity: Uncommon 3 Dust + 120g    Rare 6 Dust + 250g    Epic 10 Dust + 500g");
        draw_text(_list_x, 200, "Sacrifices the chosen item; result is a random different-class item of the same slot & rarity.");

        // Rebirth has a 3-line blurb (y150/176/200); push its row below it so the box
        // doesn't land on the cost/sacrifice lines (the other tabs use the default 190).
        var _tyr0 = ui_maren_row(0, 0 == _cursor, 226);
        if (array_length(_reb) == 0) {
            draw_set_color(make_color_rgb(120, 130, 122));
            draw_text(_list_x + 16, _tyr0, "No class-specific gear (Uncommon+) in your stash or pack.");
        } else {
            draw_set_color(make_color_rgb(190, 220, 195));
            draw_text(_list_x + 16, _tyr0, "Reforge a class item...   (" + string(array_length(_reb)) + " eligible)   [Enter]");
        }
    }

    // Notification
    if (_gc.sable_notification != "") {
        draw_set_halign(fa_center);
        draw_set_color(make_color_rgb(180, 220, 160));
        draw_text(640, 666, _gc.sable_notification);
        draw_set_halign(fa_left);
    }

    // Controls hint (raised from 702 to clear the bottom rim band)
    draw_set_halign(fa_center);
    draw_set_color(make_color_rgb(70, 95, 78));
    draw_text(640, 684, "W/S: Navigate    Q/E: Tab    Enter: Select    Esc: Back / Close");
    draw_set_halign(fa_left);

    // Ornate gothic rim around the whole overlay (see Maren screen for geometry notes).
    ui_draw_gothic_frame(20, 20, 1260, 700, 20);

    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
}

// ---------------------------------------------------------------------------
// ui_draw_vael_screen()
// Vael the Aesthete — transmog/skin selection overlay. Single list of skins with
// a live preview of the highlighted skin. Reuses ui_maren_row for row geometry.
// Layout constants MUST match the Vael input block in obj_game_controller Step.
// ---------------------------------------------------------------------------
function ui_draw_vael_screen() {
    if (!instance_exists(obj_game_controller)) return;
    var _gc = instance_find(obj_game_controller, 0);
    if (!variable_instance_exists(_gc, "vael_open") || !_gc.vael_open) return;

    draw_set_alpha(1.0);
    draw_set_color(make_color_rgb(16, 12, 18));
    draw_rectangle(0, 0, 1280, 720, false);

    // Title + gold
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_color(make_color_rgb(210, 170, 230));
    draw_text_transformed(640, 24, "Vael the Aesthete", 1.4, 1.4, 0);
    draw_set_halign(fa_right);
    draw_set_color(make_color_rgb(230, 210, 150));
    draw_text(1240, 32, "Gold: " + string(global.gold));
    draw_set_halign(fa_left);

    // --- Tabs: Skins | Portrait (geometry MUST match the Vael input block) ---
    var _vtab = variable_instance_exists(_gc, "vael_tab") ? _gc.vael_tab : 0;
    var _vtab_names = ["Skins", "Portrait"];
    for (var _vt = 0; _vt < 2; _vt++) {
        var _vtx   = 560 + _vt * 160;
        var _vt_on = (_vt == _vtab);
        draw_set_color(_vt_on ? make_color_rgb(60, 46, 86) : make_color_rgb(26, 22, 34));
        draw_rectangle(_vtx - 72, 58, _vtx + 72, 90, false);
        draw_set_color(_vt_on ? make_color_rgb(160, 120, 230) : make_color_rgb(60, 54, 78));
        draw_rectangle(_vtx - 72, 58, _vtx + 72, 90, true);
        draw_set_halign(fa_center);
        draw_set_color(_vt_on ? c_white : make_color_rgb(150, 140, 165));
        draw_text(_vtx, 66, _vtab_names[_vt]);
        draw_set_halign(fa_left);
    }

    // The Portrait tab is self-contained — draw it and return early, so the skins
    // list + detail panel below only run for tab 0.
    if (_vtab == 1) {
        ui_draw_vael_portrait_tab(_gc);
        return;
    }

    draw_set_color(make_color_rgb(160, 140, 175));
    draw_text(200, 110, "Transmog — change your combat look. Owned skins switch freely; locked skins need a milestone.");

    var _catalog = vael_skin_catalog();
    var _count   = array_length(_catalog);
    var _cursor  = clamp(_gc.vael_cursor, 0, _count - 1);
    var _active  = variable_global_exists("player_skin") ? global.player_skin : "default";

    // Windowed list (left column, x200..800). Scroll derivation MUST match the Vael
    // input block in obj_game_controller Step (vael_list_scroll).
    var _vis    = 11;
    var _scroll = vael_list_scroll(_cursor, _count, _vis);
    var _list_y = 150;
    var _row_h  = 48;

    for (var _v = 0; _v < _vis; _v++) {
        var _i = _scroll + _v;
        if (_i >= _count) break;
        var _sk = _catalog[_i];
        var _ry = _list_y + _v * _row_h;
        var _is_cur   = (_i == _cursor);
        var _owned    = vael_skin_owned(_sk.id);
        var _equipped = (_sk.id == _active);
        var _unlocked = vael_skin_unlocked(_sk);

        // Row frame
        draw_set_color(_is_cur ? make_color_rgb(45, 38, 66) : make_color_rgb(20, 18, 30));
        draw_rectangle(200, _ry, 800, _ry + 44, false);
        draw_set_color(_is_cur ? make_color_rgb(150, 110, 220) : make_color_rgb(45, 42, 62));
        draw_rectangle(200, _ry, 800, _ry + 44, true);
        var _ty = _ry + 10;

        // Mini swatch (guard missing art → small placeholder dot) — normalised to a
        // ~34px icon centred in the row's swatch box, accounting for top-left origin.
        if (_sk.sprite != undefined && _sk.sprite != -1 && sprite_exists(_sk.sprite)) {
            var _sw_sc = 34 / max(1, sprite_get_height(_sk.sprite));
            var _sw_w  = sprite_get_width(_sk.sprite)  * _sw_sc;
            var _sw_h  = sprite_get_height(_sk.sprite) * _sw_sc;
            draw_sprite_ext(_sk.sprite, player_sprite_frame(_sk.sprite), 230 - _sw_w / 2, (_ry + 22) - _sw_h / 2, _sw_sc, _sw_sc, 0, c_white, _unlocked ? 1 : 0.4);
        } else if (_sk.sprite != undefined) {
            draw_set_color(make_color_rgb(40, 38, 55));
            draw_rectangle(216, _ry + 8, 244, _ry + 36, false);
        }

        // Name (+ gender marker), greyed if locked
        var _name_col = _equipped ? make_color_rgb(180, 240, 180)
                      : (_unlocked ? (_owned ? make_color_rgb(210, 200, 220) : make_color_rgb(195, 185, 205))
                                   : make_color_rgb(120, 112, 132));
        draw_set_color(_name_col);
        var _gtag = (variable_struct_exists(_sk, "gender") && _sk.gender == "f") ? " (F)"
                  : ((variable_struct_exists(_sk, "gender") && _sk.gender == "m") ? "" : "");
        draw_text(258, _ty, _sk.name + _gtag);

        // Right-side short status
        draw_set_halign(fa_right);
        if (_equipped) {
            draw_set_color(make_color_rgb(150, 230, 150)); draw_text(790, _ty, "EQUIPPED");
        } else if (_owned) {
            draw_set_color(make_color_rgb(160, 200, 240)); draw_text(790, _ty, "OWNED");
        } else if (!_unlocked) {
            draw_set_color(make_color_rgb(150, 110, 120)); draw_text(790, _ty, "LOCKED");
        } else {
            draw_set_color((global.gold >= _sk.gold) ? make_color_rgb(230, 210, 150) : make_color_rgb(170, 120, 120));
            draw_text(790, _ty, string(_sk.gold) + "g");
        }
        draw_set_halign(fa_left);
    }

    // Scroll indicator
    if (_count > _vis) {
        draw_set_halign(fa_center);
        draw_set_color(make_color_rgb(110, 95, 130));
        draw_text(500, _list_y + _vis * _row_h + 2,
            string(_scroll + 1) + "-" + string(min(_scroll + _vis, _count)) + " of " + string(_count) + "   (W/S)");
        draw_set_halign(fa_left);
    }

    // ----- Detail / preview panel (right, x840..1250) -----
    var _sel = _catalog[_cursor];
    var _sel_unlocked = vael_skin_unlocked(_sel);
    draw_set_color(make_color_rgb(18, 14, 22));
    draw_rectangle(840, 150, 1250, 620, false);
    draw_set_color(make_color_rgb(70, 55, 90));
    draw_rectangle(840, 150, 1250, 620, true);

    // Resolve preview sprite (default look is gender-aware; missing art = placeholder)
    var _prev_spr = _sel.sprite;
    var _prev_missing = false;
    if (_prev_spr == undefined) {
        var _cid = variable_global_exists("chosen_class") ? clamp(global.chosen_class, 0, 2) : 0;
        var _gen = variable_global_exists("player_gender") ? global.player_gender : "m";
        var _cls_m = [spr_arcanist, spr_bloodwarden, spr_shadowstrider];
        _prev_spr = _cls_m[_cid];
        if (_gen == "f") {
            var _ff = asset_get_index(["spr_arcanist_f", "spr_bloodwarden_f", "spr_shadowstrider_f"][_cid]);
            if (_ff != -1 && sprite_exists(_ff)) _prev_spr = _ff;
        }
    } else if (_prev_spr == -1 || !sprite_exists(_prev_spr)) {
        _prev_missing = true;
    }

    if (!_prev_missing) {
        // Centre + size-normalise: these sprites have a top-left origin and varied
        // canvas sizes (92–108px), so scale to a target height and offset by half.
        var _pv_cx = 1045, _pv_cy = 350;
        var _pv_sc = 210 / max(1, sprite_get_height(_prev_spr));
        var _pv_w  = sprite_get_width(_prev_spr)  * _pv_sc;
        var _pv_h  = sprite_get_height(_prev_spr) * _pv_sc;
        draw_sprite_ext(_prev_spr, player_sprite_frame(_prev_spr), _pv_cx - _pv_w / 2, _pv_cy - _pv_h / 2, _pv_sc, _pv_sc, 0, c_white, _sel_unlocked ? 1 : 0.45);
    } else {
        draw_set_halign(fa_center);
        draw_set_color(make_color_rgb(90, 80, 105));
        draw_text(1045, 350, "(art pending)");
        draw_set_halign(fa_left);
    }

    // Name + gender
    draw_set_halign(fa_center);
    draw_set_color(make_color_rgb(225, 205, 235));
    draw_text_transformed(1045, 470, _sel.name, 1.1, 1.1, 0);
    draw_set_halign(fa_left);

    // Description
    draw_set_color(make_color_rgb(150, 140, 165));
    draw_text_ext(862, 502, _sel.desc, 22, 366);

    // Status / requirement line
    draw_set_halign(fa_center);
    if (_sel.id == _active) {
        draw_set_color(make_color_rgb(150, 230, 150)); draw_text(1045, 588, "Equipped");
    } else if (vael_skin_owned(_sel.id)) {
        draw_set_color(make_color_rgb(160, 200, 240)); draw_text(1045, 588, "Owned — Enter to wear");
    } else if (!_sel_unlocked) {
        draw_set_color(make_color_rgb(220, 130, 130)); draw_text(1045, 588, "Locked — " + vael_skin_req_text(_sel));
    } else {
        draw_set_color((global.gold >= _sel.gold) ? make_color_rgb(230, 210, 150) : make_color_rgb(190, 130, 130));
        draw_text(1045, 588, string(_sel.gold) + "g — Enter to buy");
    }
    draw_set_halign(fa_left);

    // Notification
    if (_gc.vael_notification != "") {
        draw_set_halign(fa_center);
        draw_set_color(make_color_rgb(220, 190, 230));
        draw_text(640, 666, _gc.vael_notification);
        draw_set_halign(fa_left);
    }

    // Controls hint (raised from 702 to clear the bottom rim band)
    draw_set_halign(fa_center);
    draw_set_color(make_color_rgb(90, 75, 100));
    draw_text(640, 684, "W/S: Navigate    Enter: Buy / Wear    Q/E: Switch tab    Esc: Close");
    draw_set_halign(fa_left);

    // Ornate gothic rim around the whole overlay (see Maren screen for geometry notes).
    // The skin detail panel (x840..1250) sits inside the opening; the rim band is outside.
    ui_draw_gothic_frame(20, 20, 1260, 700, 20);

    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
}

// ---------------------------------------------------------------------------
// ui_draw_vael_portrait_tab(gc)
// Portrait tab of the Vael overlay — a carousel over global.portrait_sprites.
// Changing to a NEW portrait costs 100g (charged in the Vael input block in
// obj_game_controller Step). Title/gold/tabs are already drawn by the caller.
// ---------------------------------------------------------------------------
function ui_draw_vael_portrait_tab(_gc) {
    var _ports  = global.portrait_sprites;
    var _pcount = array_length(_ports);
    if (_pcount <= 0) return;
    var _cur    = clamp(_gc.vael_portrait_cursor, 0, _pcount - 1);
    var _active = clamp(variable_global_exists("chosen_portrait") ? global.chosen_portrait : 0, 0, _pcount - 1);

    draw_set_color(make_color_rgb(160, 140, 175));
    draw_set_halign(fa_center);
    draw_text(640, 110, "Choose a new portrait. Switching to a different one costs 100g.");

    // Center portrait (large)
    var _main_w = 300, _main_h = 300;
    var _main_x = 640 - _main_w / 2;
    var _main_y = 168;
    draw_set_color(make_color_rgb(18, 14, 22));
    draw_rectangle(_main_x - 4, _main_y - 4, _main_x + _main_w + 4, _main_y + _main_h + 4, false);
    draw_sprite_stretched(_ports[_cur], 0, _main_x, _main_y, _main_w, _main_h);
    draw_set_color((_cur == _active) ? make_color_rgb(150, 230, 150) : make_color_rgb(160, 120, 230));
    draw_rectangle(_main_x - 4, _main_y - 4, _main_x + _main_w + 4, _main_y + _main_h + 4, true);
    ui_draw_gothic_frame(_main_x - 4, _main_y - 4, _main_x + _main_w + 4, _main_y + _main_h + 4, 22);   // ornate portrait frame

    // Side thumbnails (prev / next), dimmed
    if (_pcount > 1) {
        var _thumb_w = 120, _thumb_h = 120, _thumb_y = _main_y + 90;
        var _prev = (_cur - 1 + _pcount) mod _pcount;
        var _next = (_cur + 1) mod _pcount;
        draw_sprite_stretched_ext(_ports[_prev], 0, _main_x - _thumb_w - 28, _thumb_y, _thumb_w, _thumb_h, c_white, 0.5);
        draw_sprite_stretched_ext(_ports[_next], 0, _main_x + _main_w + 28, _thumb_y, _thumb_w, _thumb_h, c_white, 0.5);
    }

    // Counter
    draw_set_color(make_color_rgb(180, 165, 195));
    draw_text(640, _main_y + _main_h + 16, string(_cur + 1) + " / " + string(_pcount));

    // Status / confirm line
    if (_cur == _active) {
        draw_set_color(make_color_rgb(150, 230, 150));
        draw_text(640, _main_y + _main_h + 46, "Your current portrait");
    } else if (global.gold >= 100) {
        draw_set_color(make_color_rgb(230, 210, 150));
        draw_text(640, _main_y + _main_h + 46, "100g  —  Enter to set as your portrait");
    } else {
        draw_set_color(make_color_rgb(190, 130, 130));
        draw_text(640, _main_y + _main_h + 46, "Not enough gold (need 100g)");
    }

    // Notification
    if (_gc.vael_notification != "") {
        draw_set_color(make_color_rgb(220, 190, 230));
        draw_text(640, 666, _gc.vael_notification);
    }

    // Controls (raised from 702 to clear the bottom rim band)
    draw_set_color(make_color_rgb(90, 75, 100));
    draw_text(640, 684, "A/D: Browse    Q/E: Switch tab    Enter: Set (100g)    Esc: Close");
    draw_set_halign(fa_left);

    // Ornate gothic rim around the whole overlay (matches the skins tab + Maren/Sable).
    ui_draw_gothic_frame(20, 20, 1260, 700, 20);

    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
}

// Stateless scroll window for the Vael skin list — shared by draw + input so the
// visible rows and mouse hit-testing always agree.
function vael_list_scroll(_cursor, _count, _vis) {
    if (_count <= _vis) return 0;
    return clamp(_cursor - floor(_vis / 2), 0, _count - _vis);
}

// ---------------------------------------------------------------------------
// ui_draw_item_picker()
// The shared "choose an item to sacrifice + confirm" modal (see
// SYSTEMS_ITEM_PICKER.md). Layers over whatever screen opened it; geometry MUST
// match item_picker_step() hit-testing in scr_stats. No-op when not open.
// ---------------------------------------------------------------------------
function ui_draw_item_picker() {
    if (!variable_global_exists("item_picker") || !global.item_picker.open) return;
    var _p = global.item_picker;
    var _n = array_length(_p.candidates);

    // Geometry — MUST stay in sync with item_picker_step() hit-testing (scr_stats).
    var _px = 220, _py = 110, _pw = 840, _ph = 500;
    // Left list column.
    var _lx0 = _px + 16;            // row highlight left edge
    var _lx1 = _px + 404;           // row highlight right edge
    var _ly0 = _py + 86;            // first row top
    var _rh  = 38;                  // row pitch
    // Right detail pane.
    var _dvx = _px + 416;           // divider x
    var _dx  = _px + 432;           // detail content left
    var _dr  = _px + _pw - 20;      // detail content right
    // Confirm/footer band.
    var _cby0 = _py + _ph - 76, _cby1 = _py + _ph - 40;

    // Dim the whole screen, then the panel.
    draw_set_alpha(0.6); draw_set_color(c_black);
    draw_rectangle(0, 0, display_get_gui_width(), display_get_gui_height(), false);
    draw_set_alpha(0.97); draw_set_color(make_color_rgb(22, 22, 34));
    draw_rectangle(_px, _py, _px + _pw, _py + _ph, false);
    draw_set_alpha(1.0); draw_set_color(make_color_rgb(150, 150, 180));
    draw_rectangle(_px, _py, _px + _pw, _py + _ph, true);

    // Header
    draw_set_halign(fa_center); draw_set_valign(fa_top);
    draw_set_color(make_color_rgb(255, 225, 150));
    draw_text(_px + _pw / 2, _py + 14, item_picker_prompt());
    draw_set_color(c_ltgray);
    draw_text(_px + _pw / 2, _py + 42, "(only items you didn't pick are safe — nothing is lost until you confirm)");
    draw_set_halign(fa_left);

    if (_n == 0) {
        draw_set_halign(fa_center); draw_set_color(make_color_rgb(220, 120, 120));
        draw_text(_px + _pw / 2, _py + _ph / 2, "No qualifying item to give up.");
        draw_set_color(c_ltgray);
        draw_text(_px + _pw / 2, _py + _ph - 30, "Esc / Right-click: back");
        draw_set_halign(fa_left); draw_set_valign(fa_top);
        return;
    }

    // Vertical divider between list and detail pane.
    draw_set_color(make_color_rgb(60, 64, 86));
    draw_line(_dvx, _py + 76, _dvx, _cby0 - 8);

    // --- Left: windowed list of 8 rows (icon + name + value) -----------------
    var _vis = min(8, _n);
    for (var _r = 0; _r < _vis; _r++) {
        var _idx = _p.scroll + _r;
        if (_idx >= _n) break;
        var _c  = _p.candidates[_idx];
        var _ry = _ly0 + _r * _rh;
        if (_idx == _p.cursor) {
            draw_set_alpha(0.30); draw_set_color(make_color_rgb(90, 110, 160));
            draw_rectangle(_lx0, _ry, _lx1, _ry + 34, false);
            draw_set_alpha(1.0);
            draw_set_color(make_color_rgb(120, 150, 210));
            draw_rectangle(_lx0, _ry, _lx1, _ry + 34, true);
        }
        // Small inline icon.
        if (is_struct(_c.item)) ui_draw_item_icon(_lx0 + 4, _ry + 3, 28, _c.item);
        draw_set_halign(fa_left); draw_set_valign(fa_top);
        draw_set_color(item_rarity_color(_c.rarity));
        draw_text(_lx0 + 40, _ry + 8, _c.label);
        draw_set_halign(fa_right); draw_set_color(c_ltgray);
        draw_text(_lx1 - 8, _ry + 8, string(_c.value) + "g");
        draw_set_halign(fa_left);
    }
    // Scroll hints
    if (_p.scroll > 0) {
        draw_set_halign(fa_center); draw_set_color(make_color_rgb(120, 140, 170));
        draw_text((_lx0 + _lx1) / 2, _ly0 - 18, "▲ more");
    }
    if (_p.scroll + _vis < _n) {
        draw_set_halign(fa_center); draw_set_color(make_color_rgb(120, 140, 170));
        draw_text((_lx0 + _lx1) / 2, _ly0 + _vis * _rh + 2, "▼ more");
    }
    draw_set_halign(fa_left);

    // --- Right: detail pane for the selected item ----------------------------
    var _cur = _p.candidates[_p.cursor];
    var _it  = _cur.item;
    if (is_struct(_it)) {
        var _rar  = variable_struct_exists(_it, "rarity") ? _it.rarity : 0;
        var _rcol = item_rarity_color(_rar);
        var _dy   = _py + 86;

        // Big icon + name/rarity/slot header.
        ui_draw_item_icon(_dx, _dy, 64, _it);
        draw_set_halign(fa_left); draw_set_valign(fa_top);
        draw_set_color(_rcol);
        draw_text_ext(_dx + 76, _dy + 2, _it.name, 20, _dr - (_dx + 76));
        draw_set_color(make_color_rgb(150, 160, 185));
        draw_text(_dx + 76, _dy + 26, item_rarity_name(_rar));
        if (variable_struct_exists(_it, "slot")) {
            draw_set_color(make_color_rgb(110, 120, 150));
            draw_text(_dx + 76, _dy + 46, string_upper(_it.slot));
        }

        var _cy = _dy + 78;
        draw_set_color(make_color_rgb(50, 55, 80));
        draw_line(_dx, _cy, _dr, _cy);
        _cy += 8;

        // Full stat string (primary + affixes), wrapped.
        var _statstr = ui_item_stat_str(_it);
        draw_set_color(c_white);
        draw_text_ext(_dx, _cy, _statstr, 20, _dr - _dx);
        _cy += string_height_ext(_statstr, 20, _dr - _dx) + 6;

        // Unique effect.
        if (variable_struct_exists(_it, "unique_desc") && _it.unique_desc != "") {
            draw_set_color(make_color_rgb(255, 200, 50));
            draw_text_ext(_dx, _cy, _it.unique_desc, 20, _dr - _dx);
            _cy += string_height_ext(_it.unique_desc, 20, _dr - _dx) + 6;
        }

        // Flavor / description.
        var _flavor = "";
        if      (variable_struct_exists(_it, "effect_desc") && _it.effect_desc != "")
            _flavor = _it.effect_desc;
        else if (variable_struct_exists(_it, "description"))
            _flavor = _it.description;
        if (_flavor != "") {
            draw_set_color(make_color_rgb(110, 120, 145));
            draw_text_ext(_dx, _cy, _flavor, 20, _dr - _dx);
        }
        draw_set_valign(fa_top);
    }

    // --- Footer / confirm bar ------------------------------------------------
    if (_p.confirm) {
        draw_set_alpha(0.95); draw_set_color(make_color_rgb(120, 40, 40));
        draw_rectangle(_px + 20, _cby0, _px + _pw - 20, _cby1, false);
        draw_set_alpha(1.0);
        draw_set_halign(fa_center); draw_set_valign(fa_top); draw_set_color(c_white);
        draw_text(_px + _pw / 2, _cby0 + 9,
            item_picker_verb() + " " + _cur.label + "? This cannot be undone.");
        draw_set_color(c_ltgray);
        draw_text(_px + _pw / 2, _py + _ph - 24, "Enter: confirm     Esc: back");
    } else {
        draw_set_halign(fa_center); draw_set_color(c_ltgray);
        draw_text(_px + _pw / 2, _py + _ph - 24, "W/S: Select     Enter: choose     Esc: cancel");
    }

    draw_set_halign(fa_left); draw_set_valign(fa_top);
    draw_set_color(c_white); draw_set_alpha(1.0);
}

// =============================================================================
// GUI CANVAS CONSTANTS (SYSTEMS_RESOLUTION.md) - native 1920x1080 GUI layer.
// Drawn 1:1 to a 1080p display (clean 1.5x over the old 1280x720). Use these in
// place of bare 1920/1080/960/540 literals as each screen is rescaled, so a future
// resolution change is one edit here. Macros are global regardless of which script
// declares them; they live in the UI module since they're UI-canvas constants.
// =============================================================================
#macro GUI_W  1920
#macro GUI_H  1080
#macro GUI_CX (GUI_W / 2)   // 960 - horizontal center
#macro GUI_CY (GUI_H / 2)   // 540 - vertical center

// =============================================================================
// draw_text_outline(x, y, str, [outline_col], [fill_col])
// Draws str with a solid black (or given) outline so light hint/footer text and
// lore flavor stay legible over busy backgrounds. Uses the CURRENT draw color as
// the fill unless fill_col is supplied, and respects the current font / halign /
// valign / alpha. Leaves the draw color set to the fill afterwards.
// =============================================================================
function draw_text_outline(x, y, str, outline_col = c_black, fill_col = undefined) {
    var _fill = is_undefined(fill_col) ? draw_get_color() : fill_col;
    draw_set_color(outline_col);
    draw_text(x - 1, y - 1, str);
    draw_text(x,     y - 1, str);
    draw_text(x + 1, y - 1, str);
    draw_text(x - 1, y,     str);
    draw_text(x + 1, y,     str);
    draw_text(x - 1, y + 1, str);
    draw_text(x,     y + 1, str);
    draw_text(x + 1, y + 1, str);
    draw_set_color(_fill);
    draw_text(x, y, str);
}

// draw_text_ext_outline(x, y, str, sep, w, [outline_col], [fill_col])
// Wrapped (draw_text_ext) variant of draw_text_outline - for multi-line flavor /
// lore text that needs both word-wrap and a legibility outline (e.g. the camp line).
function draw_text_ext_outline(x, y, str, sep, w, outline_col = c_black, fill_col = undefined) {
    var _fill = is_undefined(fill_col) ? draw_get_color() : fill_col;
    draw_set_color(outline_col);
    draw_text_ext(x - 1, y - 1, str, sep, w);
    draw_text_ext(x,     y - 1, str, sep, w);
    draw_text_ext(x + 1, y - 1, str, sep, w);
    draw_text_ext(x - 1, y,     str, sep, w);
    draw_text_ext(x + 1, y,     str, sep, w);
    draw_text_ext(x - 1, y + 1, str, sep, w);
    draw_text_ext(x,     y + 1, str, sep, w);
    draw_text_ext(x + 1, y + 1, str, sep, w);
    draw_set_color(_fill);
    draw_text_ext(x, y, str, sep, w);
}

// =============================================================================
// scr_ui.gml
// Combat HUD drawing functions for Ironwake.
// Room dimensions: 1920 x 1080 (GUI layer).
//
// All functions are pure draw calls - they read state but never mutate it.
// Call every function from a Draw event (or a dedicated Draw GUI event).
//
// Draw call order in ui_draw_combat_hud():
//   1. Turn queue          - top-center
//   2. Player HP bar       - top-left
//   3. Energy pips         - below HP bar
//   4. Secondary resource  - below energy pips
//   5. Level + XP bar      - below secondary resource
//   6. Player buff icons   - below XP bar
//   7. Ability buttons     - bottom-center
//   8. Combat log          - bottom-left
//   9. Telegraph warning   - overlaid at top (only when active)
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
        // Tag the weapon's reach (Melee/Ranged - which abilities its damage feeds)
        // and hand requirement so the role and the offhand trade-off are both visible.
        var _reach_word = (variable_struct_exists(item, "slot") && item.slot == "ranged_weapon") ? "Ranged" : "Melee";
        var _hand_word  = (variable_struct_exists(item, "two_handed") && item.two_handed) ? "2H" : "1H";
        _s += "  (" + _reach_word + ", " + _hand_word + ")";
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
            } else if (string_copy(_asn, 1, 7) == "school_") {
                // "+X <school> damage" gear affix (SYSTEMS_ELEMENT_SCHOOLS.md §C).
                var _sch_name = string_copy(_asn, 8, string_length(_asn) - 7);
                _s += "   +" + string(_af.stat_value) + " " + school_label(_sch_name) + " dmg";
            } else {
                _s += "   +" + string(_af.stat_value) + " " + _asn;
            }
        }
    }
    // Elemental affix (small elemental damage + a setup status). (§C)
    if (variable_struct_exists(item, "elem_affix") && item.elem_affix != undefined) {
        _s += (_s == "" ? "" : "   ") + elem_affix_describe(item.elem_affix);
    }
    return _s;
}

// ---------------------------------------------------------------------------
// ui_draw_stat_line_fit(x, y, txt, max_w)
// Draws a pre-built stat string on ONE line, shrinking it uniformly only when it's
// wider than max_w, so a busy many-affix item can't overrun a row's right-hand
// column (loot screen, equip picker). Caller sets font/colour/halign first.
// ---------------------------------------------------------------------------
function ui_draw_stat_line_fit(x, y, txt, max_w) {
    var _w = string_width(txt);
    if (_w > max_w && _w > 0) {
        var _sc = max_w / _w;
        draw_text_transformed(x, y, txt, _sc, _sc, 0);
    } else {
        draw_text(x, y, txt);
    }
}

// ---------------------------------------------------------------------------
// ui_str_hash(s) - small deterministic string hash (djb-ish, 31-mult). Used to
// give Rare+ swords a STABLE per-item-identity icon (same base name -> same icon).
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
// Keyword map: wand/focus/scepter->wand, bow->bow, sickle->sickle, spear/reach->spear.
// Everything else is treated as a sword (also the default). Rare+ swords (rarity
// >= 2) get a theme- and rarity-specific icon via ui_sword_icon_rare; Common/
// Uncommon swords keep the single plain spr_icon_weapon_sword.
// ---------------------------------------------------------------------------
function ui_weapon_icon_sprite(item) {
    var _n = string_lower(item.name);
    // Caster weapons (incl. staff/rod) use the wand icon. Without staff/rod here a
    // "Stormcaller Staff" fell through to the sword bucket and showed a sword icon
    // (looked like a melee sword even though it's a ranged caster weapon). Matches
    // weapon_required_stat's caster keyword list.
    // Each family has 3 icon variants (base / _b / _c) so weapons of the same type
    // don't all look identical. ui_weapon_icon_variant hashes the base name to pick
    // one deterministically (a given weapon always shows the same icon).
    if (string_pos("wand",   _n) > 0 || string_pos("focus", _n) > 0 || string_pos("scepter", _n) > 0
        || string_pos("staff", _n) > 0 || string_pos("rod", _n) > 0)
        return ui_weapon_icon_variant(item, [spr_icon_weapon_wand, spr_icon_weapon_wand_b, spr_icon_weapon_wand_c,
                                             spr_icon_weapon_wand_d, spr_icon_weapon_wand_e]);
    if (string_pos("bow",    _n) > 0)
        return ui_weapon_icon_variant(item, [spr_icon_weapon_bow, spr_icon_weapon_bow_b, spr_icon_weapon_bow_c,
                                             spr_icon_weapon_bow_d, spr_icon_weapon_bow_e]);
    if (string_pos("sickle", _n) > 0)
        return ui_weapon_icon_variant(item, [spr_icon_weapon_sickle, spr_icon_weapon_sickle_b,
                                             spr_icon_weapon_sickle_c, spr_icon_weapon_sickle_d]);
    if (string_pos("spear",  _n) > 0 || string_pos("reach", _n) > 0)
        return ui_weapon_icon_variant(item, [spr_icon_weapon_spear, spr_icon_weapon_spear_b, spr_icon_weapon_spear_c,
                                             spr_icon_weapon_spear_d, spr_icon_weapon_spear_e]);

    var _rar = variable_struct_exists(item, "rarity") ? item.rarity : 0;
    if (_rar >= 2) return ui_sword_icon_rare(item, _n, _rar);
    // Common/Uncommon swords pick from the plain steel variants.
    return ui_weapon_icon_variant(item, [spr_icon_weapon_sword, spr_icon_weapon_sword_b, spr_icon_weapon_sword_c,
                                         spr_icon_weapon_sword_d, spr_icon_weapon_sword_e]);
}

// ui_weapon_icon_variant(item, bucket) - deterministically pick one icon from a
// family's variant list using a hash of the base name, so the same weapon always
// shows the same icon while different weapons of the family spread across variants.
function ui_weapon_icon_variant(item, bucket) {
    var _len = array_length(bucket);
    if (_len <= 1) return bucket[0];
    var _base = string_lower(item_base_name(item));
    return bucket[ui_str_hash(_base) mod _len];
}

// ---------------------------------------------------------------------------
// ui_sword_icon_rare(item, _n, _rar)
// Picks an individual sword icon for a Rare+ sword. Theme comes from the base
// name (the elemental identity - affixes are stat words, not elements) with the
// full affixed name adding tints (Ghost->void, Gilded->radiant, Arcane/Runed->arcane).
// Within a theme, rarity selects the lower (Rare) or upper (Epic+) half of the
// theme's icon list - fancier art at higher rarity - and a base-name hash picks
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
    if (_rar >= 3) { _start = _half; _size = _len - _half; }   // Epic+ -> upper (fancier) half
    else           { _start = 0;     _size = _half;        }   // Rare  -> lower half
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
// ui_chest_icon_sprite(item)
// Chest subtype by name keyword so chests don't all read as one sprite (mirrors the
// off-hand/weapon resolvers). Resolves themed sprites BY STRING (asset_get_index) so
// it compiles + runs even before the art is imported - until those sprites exist it
// falls back to the single spr_icon_chest (current look), then upgrades automatically
// once the chest-icon art pass adds spr_icon_chest_{robe,plate,leather,void}.
// ---------------------------------------------------------------------------
function ui_chest_icon_sprite(item) {
    var _n = string_lower(item.name);
    var _key = "";
    if      (string_pos("void", _n) > 0 || string_pos("shadowthread", _n) > 0 || string_pos("shadowcloth", _n) > 0)
        _key = "spr_icon_chest_void";
    else if (string_pos("robe", _n) > 0 || string_pos("vestment", _n) > 0 || string_pos("mantle", _n) > 0
          || string_pos("spellweave", _n) > 0 || string_pos("acolyte", _n) > 0)
        _key = "spr_icon_chest_robe";
    else if (string_pos("plate", _n) > 0 || string_pos("cuirass", _n) > 0 || string_pos("chain", _n) > 0
          || string_pos("brigandine", _n) > 0 || string_pos("ironveil", _n) > 0 || string_pos("aegis", _n) > 0)
        _key = "spr_icon_chest_plate";
    else if (string_pos("coat", _n) > 0 || string_pos("vest", _n) > 0 || string_pos("tunic", _n) > 0
          || string_pos("wrap", _n) > 0 || string_pos("robes", _n) > 0)
        _key = "spr_icon_chest_leather";
    if (_key != "") {
        var _s = asset_get_index(_key);
        if (_s != -1 && sprite_exists(_s)) return _s;
    }
    return spr_icon_chest;   // graceful fallback until themed chest art is imported
}

// ---------------------------------------------------------------------------
// ui_helm_icon_sprite / ui_gloves_icon_sprite / ui_boots_icon_sprite
// Armor-piece subtype icons by name keyword (mirror the chest/off-hand resolvers).
// Themed sprites are resolved BY STRING so they compile + run before the art is
// imported, falling back to the single base sprite until then; once the icon art
// pass adds them, variety appears automatically. Keyword order = priority.
// ---------------------------------------------------------------------------
function ui_helm_icon_sprite(item) {
    var _n = string_lower(item.name);
    var _key = "";
    if      (string_pos("hood", _n) > 0 || string_pos("cowl", _n) > 0 || string_pos("hat", _n) > 0)
        _key = "spr_icon_helm_hood";
    else if (string_pos("circlet", _n) > 0 || string_pos("crown", _n) > 0 || string_pos("diadem", _n) > 0
          || string_pos("tiara", _n) > 0 || string_pos("coronet", _n) > 0)
        _key = "spr_icon_helm_circlet";
    else  // cap / skullcap / visor / helm / helmet / casque / circlet handled above
        _key = "spr_icon_helm_plate";
    var _s = asset_get_index(_key);
    if (_s != -1 && sprite_exists(_s)) return _s;
    return spr_icon_helm;
}

function ui_gloves_icon_sprite(item) {
    var _n = string_lower(item.name);
    var _key = "";
    if      (string_pos("sage", _n) > 0 || string_pos("rune", _n) > 0 || string_pos("arcane", _n) > 0
          || string_pos("mage", _n) > 0 || string_pos("spell", _n) > 0)
        _key = "spr_icon_gloves_arcane";
    else if (string_pos("wrap", _n) > 0 || string_pos("nimble", _n) > 0 || string_pos("whisper", _n) > 0
          || string_pos("fleet", _n) > 0 || string_pos("silk", _n) > 0)
        _key = "spr_icon_gloves_cloth";
    else  // gauntlet / irongrip / crusher / iron / steel / plated default to heavy
        _key = "spr_icon_gloves_plate";
    var _s = asset_get_index(_key);
    if (_s != -1 && sprite_exists(_s)) return _s;
    return spr_icon_gloves;
}

function ui_boots_icon_sprite(item) {
    var _n = string_lower(item.name);
    var _key = "";
    if      (string_pos("greave", _n) > 0 || string_pos("stomper", _n) > 0 || string_pos("ironshod", _n) > 0
          || string_pos("stoneguard", _n) > 0 || string_pos("colossus", _n) > 0 || string_pos("plate", _n) > 0
          || string_pos("stone", _n) > 0)
        _key = "spr_icon_boots_plate";
    else if (string_pos("wrap", _n) > 0 || string_pos("dustwalker", _n) > 0 || string_pos("sandal", _n) > 0
          || string_pos("cloth", _n) > 0 || string_pos("silk", _n) > 0)
        _key = "spr_icon_boots_cloth";
    else  // boots / treads / strider / step / leather default to leather
        _key = "spr_icon_boots_leather";
    var _s = asset_get_index(_key);
    if (_s != -1 && sprite_exists(_s)) return _s;
    return spr_icon_boots;
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
// awakening_label() - formatted "Awakening A2 - Brutal" string for the current
// run difficulty (global.selected_ascendance). Mirrors the hub's tier names so
// the combat and dungeon screens can show the awakening tier as a reference.
// ---------------------------------------------------------------------------
function awakening_label() {
    var _asc = variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0;
    var _names = ["Normal", "Hardened", "Brutal", "Relentless", "Nightmare", "Infernal"];
    _asc = clamp(_asc, 0, array_length(_names) - 1);
    return "Awakening A" + string(_asc) + " - " + _names[_asc];
}

// ---------------------------------------------------------------------------
// ui_draw_item_icon(x, y, sz, item)
// Draws a pixel art icon for the item, scaled to szxsz.
// Legendary items are detected via unique_effect; weapons use name-keyword
// subtype detection. Falls back to colored box + abbreviation if the sprite
// has not yet been imported into the project.
// ---------------------------------------------------------------------------
function ui_draw_item_icon(x, y, sz, item) {
    var _slot = variable_struct_exists(item, "slot") ? item.slot : "";
    var _rar  = variable_struct_exists(item, "rarity") ? item.rarity : 0;
    var _rcol = item_rarity_color(_rar);

    // Resolve icon sprite - -1 means "not found, use fallback"
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
            case "helm":    _spr = ui_helm_icon_sprite(item);    break;
            case "chest":   _spr = ui_chest_icon_sprite(item);   break;
            case "gloves":  _spr = ui_gloves_icon_sprite(item);  break;
            case "boots":   _spr = ui_boots_icon_sprite(item);   break;
            case "amulet":  _spr = ui_amulet_icon_sprite(item);  break;
            case "ring":    _spr = ui_ring_icon_sprite(item);    break;
        }
    }

    // Force full opacity - icons are never meant to inherit a caller's dimmed alpha
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
// an unmapped ability. No border is drawn here - callers own their framing.
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
// gc Step is intentionally excluded - it must keep running to handle overlays.
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
// isn't imported yet, so callers fall back to their flat fill - a safe no-op until
// the MidJourney backgrounds land. See [[project]] SYSTEMS / MISC_TASKS §5.
// ---------------------------------------------------------------------------
function dungeon_bg_draw(surface, scrim_alpha) {
    var _spr = dungeon_bg_sprite(surface);
    if (_spr == -1 || !sprite_exists(_spr)) return false;
    draw_set_color(c_white);
    draw_set_alpha(1.0);
    draw_sprite_stretched(_spr, 0, 0, 0, GUI_W, GUI_H);
    draw_set_color(c_black);
    draw_set_alpha(scrim_alpha);
    draw_rectangle(0, 0, GUI_W, GUI_H, false);
    draw_set_alpha(1.0);
    draw_set_color(c_white);
    return true;
}

// ---------------------------------------------------------------------------
// ui_draw_gothic_frame(x1, y1, x2, y2, band)
// Draws an ornate gothic 9-slice border (spr_ui_frame: carved stone + gold
// filigree) SURROUNDING the rect (x1,y1)-(x2,y2) - the band extends OUTWARD so
// the rect itself is the clear inner opening and panel content is never covered.
// The four corner ornaments draw undistorted; the edges stretch between them; the
// center (the inner opening) is skipped. Implemented manually with
// draw_sprite_part_ext so it needs no GameMaker nineSlice config.
//   band = drawn border thickness in px (default 26). Source ornate band is 42px;
//   corners scale band/42 so the filigree stays crisp at any panel size.
// For full-screen overlays pass a slightly inset rect (e.g. 30,30,1890,1050) so the
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
// Returns a 2-3 char abbreviation for a status effect.
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
// status_icon_style(se) - KIND-BASED badge style for an applied status struct.
// Resolves {label, color} from the status `kind` (combat_status_kind_of) so EVERY
// status tags consistently (BLND/WKN/VUL/STUN/ROOT/SIL + PSN/BLEED/BRN/DOT),
// with the DoT sub-type chosen by name keyword. Falls back to the legacy
// name-keyed label/color for anything without a typed kind.
// ---------------------------------------------------------------------------
function status_icon_style(se) {
    var _kind = combat_status_kind_of(se);
    var _name = string_lower(variable_struct_exists(se, "name") ? se.name : "");
    // Elemental weapon-affix statuses get a distinct badge keyed off their element
    // even though they piggyback existing kinds (frost=weaken, shock=vulnerable). (§C)
    var _elem = (is_struct(se) && variable_struct_exists(se, "element")) ? se.element : "";
    switch (_elem) {
        case "burn":  return { label: "BRN",  color: make_color_rgb(225, 130,  40) };
        case "frost": return { label: "FRST", color: make_color_rgb( 90, 180, 230) };
        case "shock": return { label: "SHK",  color: make_color_rgb(230, 210,  70) };
    }
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
        // Scorch's mark: every hit on the target deals bonus TRUE FIRE damage. Distinct
        // from VUL (which is typeless) - its own badge so the player reads it as fire.
        case "firemark":   return { label: "Fire+", color: make_color_rgb(225, 130,  40) };
        case "weaken":     return { label: "WKN",  color: make_color_rgb(175, 110,  55) };
        case "blind":      return { label: "BLND", color: make_color_rgb(120, 125, 145) };
        case "mortality":  return { label: "MORT", color: make_color_rgb(120, 175,  90) };
        case "stun":       return { label: "STUN", color: make_color_rgb(228, 200,  60) };
        case "root":       return { label: "ROOT", color: make_color_rgb( 55, 160, 150) };
        case "silence":    return { label: "SIL",  color: make_color_rgb(125,  90, 205) };
        case "regen":      return { label: "HEAL", color: make_color_rgb( 90, 200, 120) };
    }
    return {
        label: status_icon_label(se.name, se.effect_type),
        color: status_icon_color(se.name, se.effect_type)
    };
}

// ---------------------------------------------------------------------------
// status_icons_from(status_effects) - build a [{label,color,duration}] icon list
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
            duration: variable_struct_exists(_se, "duration") ? _se.duration : 0,
            se:       _se   // source status, so the icon row can hover-explain it
        });
    }
    return _icons;
}

// ---------------------------------------------------------------------------
// status_fx_sprite_for(se) - maps a status to its looping VFX sprite (or -1).
// kind/name -> spr_fx_*; resolved by string so a missing sprite simply no-ops
// (the sprites are registered in global.__sprite_includes to survive the build).
// ---------------------------------------------------------------------------
function status_fx_sprite_for(se) {
    var _kind = combat_status_kind_of(se);
    var _name = string_lower(variable_struct_exists(se, "name") ? se.name : "");
    // Elemental affix statuses use a dedicated aura; until dedicated frost/shock art
    // exists, fall back to the weaken/stun auras so there's still a visible mark. (§C)
    var _elem = (is_struct(se) && variable_struct_exists(se, "element")) ? se.element : "";
    if (_elem == "burn")  return asset_get_index("spr_fx_burn");
    if (_elem == "frost") { var _ff = asset_get_index("spr_fx_frost"); return (_ff >= 0) ? _ff : asset_get_index("spr_fx_weaken"); }
    if (_elem == "shock") { var _fs = asset_get_index("spr_fx_shock"); return (_fs >= 0) ? _fs : asset_get_index("spr_fx_stun"); }
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

// item_slot_label(slot) - display name for an equipment slot key (weapon->"Weapon").
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

// status_effect_plain_text(se) - short plain-language description of what a status
// does, for the menu "Boons & Effects" panel (e.g. "12 dmg/turn", "-accuracy").
function status_effect_plain_text(se) {
    var _kind = combat_status_kind_of(se);
    var _val  = variable_struct_exists(se, "effect_value") ? se.effect_value : 0;
    var _elem = (is_struct(se) && variable_struct_exists(se, "element")) ? se.element : "";
    if (_elem == "burn")  return string(_val) + " fire dmg/turn";
    if (_elem == "frost") return "chilled (-" + string(round(_val * 100)) + "% enemy dmg)";
    if (_elem == "shock") return "shocked (+" + string(_val) + " dmg taken)";
    switch (_kind) {
        case "dot":        return string(_val) + " dmg/turn";
        case "blind":      return "reduced accuracy";
        case "weaken":     return "weaker attacks";
        case "vulnerable": return "+" + string(_val) + " dmg taken";
        case "firemark":   return "+" + string(_val) + " fire dmg/hit";
        case "mortality":  return "reduced healing";
        case "stun":       return "cannot act";
        case "root":       return "cannot melee";
        case "silence":    return "cannot cast";
        case "regen":      return "+" + string(_val) + " HP/turn";
    }
    return (se.effect_type == "dot") ? (string(_val) + " dmg/turn") : "debuff";
}

// combatant_has_status_kind(c, kind) - true if any active status on c is of `kind`.
function combatant_has_status_kind(c, kind) {
    if (!variable_struct_exists(c, "status_effects")) return false;
    for (var _i = 0; _i < array_length(c.status_effects); _i++)
        if (combat_status_kind_of(c.status_effects[_i]) == kind) return true;
    return false;
}

// status_fx_anchor(se) - where on the combatant the fx sits: 0 head, 1 center, 2 feet.
function status_fx_anchor(se) {
    var _kind = combat_status_kind_of(se);
    if (_kind == "blind" || _kind == "stun") return 0;   // around the head
    var _name = string_lower(variable_struct_exists(se, "name") ? se.name : "");
    if (_kind == "dot" && (string_pos("burn", _name) || string_pos("cinder", _name) || string_pos("scorch", _name) || string_pos("flame", _name) || string_pos("ignit", _name) || string_pos("ember", _name)))
        return 2;   // flames at the feet
    return 1;       // gas / blood / aura at the body
}

// ---------------------------------------------------------------------------
// ui_draw_status_fx(cx, top_y, draw_h, status_effects) - overlay looping VFX
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
// Each badge is 48x24px with a 5px gap; duration shown in small text below.
// (48 wide fits 4-char labels like "STUN"/"WEAK" at fnt_ui_small without clipping.)
// ---------------------------------------------------------------------------
function ui_draw_status_icon_row(x, y, icon_list) {
    var _iw  = 48;
    var _ih  = 24;
    var _gap = 5;
    var _ix  = x;
    // Mouse (GUI space) for hover-to-explain. The hovered status is stashed in a
    // global and drawn as a tooltip later by obj_combat_controller (so it lands on
    // top of every bar/row). Reset each combat Draw frame.
    var _mx = device_mouse_x_to_gui(0);
    var _my = device_mouse_y_to_gui(0);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_set_font(fnt_ui_small);
    for (var _i = 0; _i < array_length(icon_list); _i++) {
        var _ic = icon_list[_i];
        // Hover hit-test (badge rect). Only entries carrying their source `se` are
        // explainable (ad-hoc buff badges without one are skipped).
        if (variable_struct_exists(_ic, "se")
            && _mx >= _ix && _mx < _ix + _iw && _my >= y && _my < y + _ih) {
            global.combat_status_tip = { se: _ic.se, x: _mx, y: _my };
        }
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
        draw_text(_ix + _iw * 0.5, y + _ih * 0.5, _ic.label);
        // duration counter below badge
        if (_ic.duration > 0) {
            draw_set_color(make_color_rgb(220, 215, 180));
            draw_text(_ix + _iw * 0.5, y + _ih + 11, string(_ic.duration));
        }
        _ix += _iw + _gap;
    }
    draw_set_font(-1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
}

// ---------------------------------------------------------------------------
// status_detonation_text(se) - the detonation reaction a status enables when a
// detonator (Snipe/Assassinate/Arcane Burst/Soul Nova) hits a foe carrying it.
// "" if the status doesn't detonate. Mirrors combat_detonator_pick + the reaction
// values in obj_combat_controller/Step_0. See SYSTEMS_VIABILITY_PASS.md.
// ---------------------------------------------------------------------------
function status_detonation_text(se) {
    if (!is_struct(se)) return "";
    var _k  = variable_struct_exists(se, "kind") ? se.kind
            : (variable_struct_exists(se, "effect_type") ? se.effect_type : "");
    var _el = combat_status_element(se);   // explicit element, else inferred (dot -> bleed)
    if (_k == "stun")                            return "Detonate: guaranteed critical hit.";
    if (_el == "frost")                          return "Detonate: +30% damage (shatters).";
    if (_k == "root")                            return "Detonate: +30% damage (shatters).";
    if (_el == "burn")                           return "Detonate: +40% crit chance.";
    if (_el == "shock")                          return "Detonate: arcs ~33% damage to other foes (or +25% crit if alone).";
    if (_k == "vulnerable" || _k == "firemark")  return "Detonate: +12 bonus damage.";
    if (_k == "dot" && _el == "bleed")           return "Detonate: bursts all remaining bleed ticks (+5 each).";
    if (_k == "dot" && _el == "poison")          return "Detonate: applies Mortality (-40% healing, 4 turns).";
    if (_k == "dot" && _el == "void")            return "Detonate: heals you 30% of the damage dealt.";
    if (_k == "weaken")                          return "Detonate: +15% damage.";
    if (_k == "blind")                           return "Detonate: cannot miss.";
    return "";
}

// status_tooltip_desc(se) - one-line "what it does" explanation incl. turns left.
function status_tooltip_desc(se) {
    var _k    = variable_struct_exists(se, "kind") ? se.kind
              : (variable_struct_exists(se, "effect_type") ? se.effect_type : "");
    var _val  = variable_struct_exists(se, "effect_value") ? se.effect_value : 0;
    var _dur  = variable_struct_exists(se, "duration") ? se.duration : 0;

    // A badge can carry its own one-line explanation (player buffs like Iron Skin /
    // Blink / Vanish that live on the player struct, not in status_effects[], so they
    // have no typed `kind` to switch on). It supplies its own duration noun too
    // ("charge" for stacked-evasion buffs, "turn" otherwise).
    if (variable_struct_exists(se, "desc")) {
        var _noun = variable_struct_exists(se, "dur_noun") ? se.dur_noun : "turn";
        var _suf  = (_dur > 0) ? ("  (" + string(_dur) + " " + _noun + (_dur == 1 ? "" : "s") + " left)") : "";
        return se.desc + _suf;
    }

    var _el   = combat_status_element(se);
    var _rawel = (is_struct(se) && variable_struct_exists(se, "element")) ? se.element : "";
    var _turns = (_dur > 0) ? ("  (" + string(_dur) + " turn" + (_dur == 1 ? "" : "s") + " left)") : "";
    var _base;
    if (_rawel == "frost")      _base = "Chilled: deals " + string(round(_val * 100)) + "% less damage.";
    else if (_rawel == "shock") _base = "Shocked: takes +" + string(_val) + " damage per hit.";
    else switch (_k) {
        case "dot":        _base = "Damage over time: " + string(_val) + " " + (_el != "" ? _el + " " : "") + "damage each turn."; break;
        case "vulnerable": _base = "Exposed: takes +" + string(_val) + " damage per hit."; break;
        case "firemark":   _base = "Seared: every hit on it deals +" + string(_val) + " fire damage."; break;
        case "weaken":     _base = "Weakened: deals " + string(round(_val * 100)) + "% less damage."; break;
        case "blind":      _base = "Blinded: -" + string(round(_val * 100)) + "% accuracy."; break;
        case "mortality":  _base = "Mortality: healing received reduced " + string(round(_val * 100)) + "%."; break;
        case "stun":       _base = "Stunned: cannot act."; break;
        case "root":       _base = "Rooted: melee can't reach (ranged still acts)."; break;
        case "silence":    _base = "Silenced: cannot cast spells."; break;
        case "regen":      _base = "Regenerating: restores " + string(_val) + " HP each turn."; break;
        default:           _base = "Active effect."; break;
    }
    return _base + _turns;
}

// ---------------------------------------------------------------------------
// ui_draw_status_tooltip(mx, my, se) - floating popup explaining a status icon:
// name, what it does (+turns left), and its detonation reaction (if any). Mirrors
// the gear tooltip; self-sizes and clamps to the screen.
// ---------------------------------------------------------------------------
function ui_draw_status_tooltip(mx, my, se) {
    if (!is_struct(se)) return;
    draw_set_halign(fa_left); draw_set_valign(fa_top);
    draw_set_font(fnt_ui_small);

    var _pad = 15, _lh = 27, _w = 540, _iw = _w - _pad * 2;
    // Header/accent colour: a badge may supply its own (player buffs); otherwise derive
    // it from the typed status style. (Avoids running status_icon_style on a buff struct
    // that has no `kind`/`effect_type`.)
    var _st_color = variable_struct_exists(se, "color") ? se.color : status_icon_style(se).color;
    var _name = variable_struct_exists(se, "name") ? se.name : "Status";
    var _desc = status_tooltip_desc(se);
    var _det  = status_detonation_text(se);

    // Height = pad + name line + desc(wrapped) + optional detonation(wrapped) + pad.
    var _h = _pad * 2 + _lh;
    _h += string_height_ext(_desc, _lh, _iw);
    if (_det != "") _h += string_height_ext(_det, _lh, _iw) + 6;

    var _x = mx + 24, _y = my + 18;
    if (_x + _w > 1905) _x = mx - _w - 18;
    if (_x < 6) _x = 6;
    if (_y + _h > 1065) _y = 1065 - _h;
    if (_y < 6) _y = 6;

    draw_set_alpha(0.96);
    draw_set_color(make_color_rgb(12, 14, 26));
    draw_rectangle(_x, _y, _x + _w, _y + _h, false);
    draw_set_alpha(1.0);
    draw_set_color(_st_color);
    draw_rectangle(_x, _y, _x + _w, _y + _h, true);
    draw_rectangle(_x, _y, _x + _w, _y + 4, false);   // accent strip

    var _cx = _x + _pad, _cy = _y + _pad;
    draw_set_color(_st_color);
    draw_text(_cx, _cy, _name);
    _cy += _lh;
    draw_set_color(make_color_rgb(215, 218, 230));
    draw_text_ext(_cx, _cy, _desc, _lh, _iw);
    _cy += string_height_ext(_desc, _lh, _iw);
    if (_det != "") {
        _cy += 6;
        draw_set_color(make_color_rgb(255, 205, 90));
        draw_text_ext(_cx, _cy, _det, _lh, _iw);
    }

    draw_set_font(-1);
    draw_set_halign(fa_left); draw_set_valign(fa_top);
    draw_set_alpha(1.0);
}

// ---------------------------------------------------------------------------
// ui_draw_enemy_inspect_tooltip(mx, my, enemy)
// Hover panel for an enemy: its attack class (reach x kind) and which control
// effects stop it - Root halts melee, Silence stops spells, Stun stops anything.
// Lets the player tell BEFORE acting whether e.g. a Bear Trap (root) will work on
// a foe (ranged foes ignore root by design). See SYSTEMS_ATTACK_CLASS.md.
// ---------------------------------------------------------------------------
function ui_draw_enemy_inspect_tooltip(mx, my, enemy) {
    if (!is_struct(enemy)) return;
    draw_set_halign(fa_left); draw_set_valign(fa_top);
    draw_set_font(fnt_ui_small);

    var _reach     = variable_struct_exists(enemy, "reach") ? enemy.reach : "melee";
    var _kind      = variable_struct_exists(enemy, "kind")  ? enemy.kind  : "attack";
    var _is_ranged = (_reach == "ranged");
    var _is_spell  = (_kind  == "spell");
    var _name      = variable_struct_exists(enemy, "name") ? enemy.name : "Enemy";
    var _class_str = (_is_ranged ? "Ranged" : "Melee") + " - " + (_is_spell ? "Spell" : "Phys");

    var _green = make_color_rgb(120, 210, 120);
    var _muted = make_color_rgb(180, 110, 110);
    var _root_ok = !_is_ranged;
    var _sil_ok  = _is_spell;
    var _lines = [
        { t: "Root:     " + (_root_ok ? "stops it" : "no effect (ranged)"), c: _root_ok ? _green : _muted },
        { t: "Silence:  " + (_sil_ok  ? "stops it" : "no effect (phys)"),   c: _sil_ok  ? _green : _muted },
        { t: "Stun:     stops it",                                          c: _green },
    ];

    var _pad = 15, _lh = 27, _w = 420;
    var _h = _pad * 2 + _lh * (2 + array_length(_lines)) + 6;   // name + class + control lines + gap

    var _x = mx + 24, _y = my + 18;
    if (_x + _w > 1905) _x = mx - _w - 18;   // enemies sit top-right; flip left near the edge
    if (_x < 6) _x = 6;
    if (_y + _h > 1065) _y = 1065 - _h;
    if (_y < 6) _y = 6;

    var _accent = _is_ranged ? make_color_rgb(220, 170, 80) : make_color_rgb(150, 165, 195);
    draw_set_alpha(0.96);
    draw_set_color(make_color_rgb(12, 14, 26));
    draw_rectangle(_x, _y, _x + _w, _y + _h, false);
    draw_set_alpha(1.0);
    draw_set_color(_accent);
    draw_rectangle(_x, _y, _x + _w, _y + _h, true);
    draw_rectangle(_x, _y, _x + _w, _y + 4, false);   // accent strip

    var _cx = _x + _pad, _cy = _y + _pad;
    draw_set_color(c_white);
    draw_text(_cx, _cy, _name);
    _cy += _lh;
    draw_set_color(_accent);
    draw_text(_cx, _cy, _class_str);
    _cy += _lh + 6;
    for (var _li = 0; _li < array_length(_lines); _li++) {
        draw_set_color(_lines[_li].c);
        draw_text(_cx, _cy, _lines[_li].t);
        _cy += _lh;
    }

    draw_set_font(-1);
    draw_set_halign(fa_left); draw_set_valign(fa_top);
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
    var _pad  = 15;
    var _lh   = 27;
    // Width is now adaptive: it grows to fit the longest line up to a cap, and any
    // line wider than the inner text area wraps to multiple lines (draw_text_ext).
    var _tw_min = 450;
    var _tw_max = 705;

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_font(fnt_ui_small);

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
    // Class restriction (gold = your class can use it, red = locked to another class).
    var _it_cr = variable_struct_exists(item, "class_req") ? item.class_req : -1;
    if (_it_cr != -1) {
        var _cr_names = ["Arcanist", "Bloodwarden", "Shadowstrider"];
        var _cr_name  = (_it_cr >= 0 && _it_cr <= 2) ? _cr_names[_it_cr] : "Unknown";
        var _my_cl    = variable_global_exists("chosen_class") ? global.chosen_class : -1;
        var _cr_col   = (_it_cr == _my_cl) ? make_color_rgb(210, 175, 90) : make_color_rgb(225, 80, 80);
        array_push(_rows, { kind: "text", txt: _cr_name + " only", col: _cr_col, tag: "", tagcol: c_white });
    }
    array_push(_rows, { kind: "text", txt: ui_item_stat_str(item), col: c_white, tag: "", tagcol: c_white });
    // Gear stat requirement (SYSTEMS_WEAPON_ROLES.md §D3): red if the wearer doesn't
    // meet it (equipping is hard-blocked), dim green if satisfied.
    var _req = item_stat_requirement(item);
    if (_req.value > 0 && _req.stat != "") {
        var _req_met = (player_base_stat(_req.stat) >= _req.value);
        var _req_col = _req_met ? make_color_rgb(110, 170, 110) : make_color_rgb(225, 80, 80);
        array_push(_rows, { kind: "text", txt: "Requires " + string(_req.value) + " " + _req.stat, col: _req_col, tag: "", tagcol: c_white });
    }
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

    // Pass 1 - pick the panel width from the widest single-line content (name line
    // also reserves room for the right-aligned rarity tag), clamped to [min, max].
    var _maxw = _tw_min - _pad * 2;
    for (var _ri = 0; _ri < array_length(_rows); _ri++) {
        var _row = _rows[_ri];
        if (_row.kind != "text" || _row.txt == "") continue;
        var _w = string_width(_row.txt);
        if (_row.tag != "") _w += string_width(_row.tag) + 36;
        _maxw = max(_maxw, _w);
    }
    var _tw = clamp(_maxw + _pad * 2, _tw_min, _tw_max);
    var _ww = _tw - _pad * 2;   // inner wrap width

    // Pass 2 - measure height with wrapping applied.
    var _th = _pad * 2;
    for (var _ri = 0; _ri < array_length(_rows); _ri++) {
        var _row = _rows[_ri];
        if (_row.kind == "divider") { _th += 18; continue; }
        _th += (_row.txt == "") ? _lh : string_height_ext(_row.txt, _lh, _ww);
    }

    // Screen-clamp
    if (ttx + _tw > 1905) ttx -= _tw + 36;
    if (ttx < 6)          ttx  = 6;
    if (tty + _th > 1065) tty  = 1065 - _th;
    if (tty < 6)          tty  = 6;

    // Panel background
    draw_set_alpha(0.95);
    draw_set_color(make_color_rgb(12, 14, 26));
    draw_rectangle(ttx, tty, ttx + _tw, tty + _th, false);
    draw_set_alpha(1.0);
    draw_set_color(_rcol);
    draw_rectangle(ttx, tty, ttx + _tw, tty + _th, true);
    draw_rectangle(ttx, tty, ttx + _tw, tty + 4, false);

    // Pass 3 - render rows (wrapped via draw_text_ext).
    var _cx = ttx + _pad;
    var _cy = tty + _pad;
    for (var _ri = 0; _ri < array_length(_rows); _ri++) {
        var _row = _rows[_ri];
        if (_row.kind == "divider") {
            draw_set_color(make_color_rgb(50, 55, 80));
            draw_line(_cx, _cy + 9, ttx + _tw - _pad, _cy + 9);
            _cy += 18;
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
    draw_set_font(-1);
}

// ---------------------------------------------------------------------------
// ui_draw_hp_bar(x, y, width, height, current_hp, max_hp, label)
// Draws a filled HP bar with a label and "current / max" readout.
// Color zones: green >=50%, yellow 25-50%, red <25%.
// ---------------------------------------------------------------------------
function ui_draw_hp_bar(x, y, width, height, current_hp, max_hp, label, ornate = false) {
    var ratio = (max_hp > 0) ? clamp(current_hp / max_hp, 0, 1) : 0;

    // Ornate gothic trim (enemy bars): a bronze frame with darker inset + small
    // corner ticks, drawn just OUTSIDE the bar so it reads as a forged metal plate.
    if (ornate) {
        draw_set_color(make_color_rgb(58, 44, 24));
        draw_rectangle(x - 4, y - 4, x + width + 4, y + height + 4, true);
        draw_set_color(make_color_rgb(150, 120, 62));
        draw_rectangle(x - 3, y - 3, x + width + 3, y + height + 3, true);
        draw_set_color(make_color_rgb(205, 170, 95));   // corner ticks
        var _ck = 8;
        draw_line(x - 3, y - 3, x - 3 + _ck, y - 3);  draw_line(x - 3, y - 3, x - 3, y - 3 + _ck);
        draw_line(x + width + 3, y - 3, x + width + 3 - _ck, y - 3);  draw_line(x + width + 3, y - 3, x + width + 3, y - 3 + _ck);
        draw_line(x - 3, y + height + 3, x - 3 + _ck, y + height + 3);  draw_line(x - 3, y + height + 3, x - 3, y + height + 3 - _ck);
        draw_line(x + width + 3, y + height + 3, x + width + 3 - _ck, y + height + 3);  draw_line(x + width + 3, y + height + 3, x + width + 3, y + height + 3 - _ck);
    }

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

    // HP readout (right-aligned). Measured first so the label can be truncated to
    // whatever space is left, instead of running into the numbers (font-agnostic).
    draw_set_font(fnt_ui);
    var _hp_str = string(current_hp) + " / " + string(max_hp);
    var _label_max = width - 12 - string_width(_hp_str) - 12;   // l-pad + readout + gap

    // Label (left-aligned, vertically centered on the bar), truncated to fit. Black
    // outline so the white name + HP readout stay legible over the yellow/green/red
    // fill (white-on-yellow was nearly unreadable at mid HP).
    draw_set_halign(fa_left);
    draw_set_valign(fa_middle);
    draw_set_color(c_white);
    draw_text_outline(x + 6, y + height / 2, ui_truncate(label, max(20, _label_max)));

    draw_set_halign(fa_right);
    draw_text_outline(x + width - 6, y + height / 2, _hp_str);

    // Reset alignment to safe defaults
    draw_set_font(-1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}

// ---------------------------------------------------------------------------
// ui_draw_energy_pips(x, y, current_energy, max_energy)
// Draws energy as a row of small squares.
// Lit pips: bright yellow. Empty pips: dark gray.
// Each pip is 24x24 with a 6px gap between them.
// ---------------------------------------------------------------------------
function ui_draw_energy_pips(x, y, current_energy, max_energy) {
    var pip_size = 24;
    var pip_gap  = 6;

    // Burst AP (from Energy Tonic / Adrenaline Vial / Ley Battery) can push current
    // above the normal cap - draw extra pips so the surplus is visible, tinted orange.
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
    draw_set_font(fnt_ui_small);
    draw_set_color(c_white);
    draw_set_halign(fa_left);
    draw_set_valign(fa_middle);
    var label_x = x + pip_count * (pip_size + pip_gap) + 6;
    draw_text(label_x, y + pip_size / 2, "AP");
    draw_set_font(-1);
    draw_set_valign(fa_top);
}

// ---------------------------------------------------------------------------
// ui_draw_secondary_resource(x, y, current, maximum, resource_name, color)
// Draws a slim labeled bar for Souls / Blood / Preparation.
// The bar fill uses the passed color; background is dark gray.
// ---------------------------------------------------------------------------
function ui_draw_secondary_resource(x, y, current, maximum, resource_name, color) {
    var width  = 375;
    var height = 24;
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

    // Resource name and value. Value measured first so the name truncates to the
    // remaining space instead of colliding it (font-agnostic).
    draw_set_font(fnt_ui_small);
    draw_set_color(c_white);
    draw_set_valign(fa_middle);
    var _val_str = string(current) + " / " + string(maximum);
    var _name_max = width - 12 - string_width(_val_str) - 12;

    draw_set_halign(fa_left);
    draw_text(x + 6, y + height / 2, ui_truncate(resource_name, max(20, _name_max)));

    draw_set_halign(fa_right);
    draw_text(x + width - 6, y + height / 2, _val_str);

    draw_set_font(-1);
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
    var box_width  = 120;
    var box_height = 48;
    var box_gap    = 9;

    var count = array_length(combat_state.combatants);

    for (var i = 0; i < count; i++) {
        var c  = combat_state.combatants[i];
        var bx = x + i * (box_width + box_gap);

        // Skip defeated combatants - show a dim slot instead
        if (c.is_defeated) {
            draw_set_alpha(0.3);
        }

        // Box fill - teal for player, orange for enemies
        if (c.is_player) {
            draw_set_color(c_teal);
        } else {
            draw_set_color(c_orange);
        }
        draw_rectangle(bx, y, bx + box_width, y + box_height, false);

        // Border - bright white for the active combatant, black otherwise
        if (i == combat_state.turn_index) {
            draw_set_color(c_white);
        } else {
            draw_set_color(c_black);
        }
        draw_rectangle(bx, y, bx + box_width, y + box_height, true);

        // Name - truncate to the box PIXEL width (font-agnostic; old 8-char cap
        // overflowed with wider fonts). Small font so more of the name fits.
        draw_set_font(fnt_ui_small);
        var display_name = ui_truncate(c.name, box_width - 12);
        draw_set_color(c_white);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_text(bx + box_width / 2, y + box_height / 2, display_name);

        draw_set_alpha(1.0);
    }

    // Reset alignment
    draw_set_font(-1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}

// ---------------------------------------------------------------------------
// ui_draw_ground_shadow(cx, baseline_y, sprite_display_width)
// Soft elliptical drop-shadow under a combat battler so the sprite reads against
// busy dungeon backgrounds. cx = horizontal centre, baseline_y = the sprite's feet
// (its bottom edge), width scales to the sprite. Three stacked ellipses (wide soft
// halo -> mid -> dense core) fake a soft edge and stay visible on dark floors. Call
// BEFORE the sprite so it sits beneath it.
// ---------------------------------------------------------------------------
function ui_draw_ground_shadow(cx, baseline_y, sprite_display_width) {
    var _w  = sprite_display_width * 0.46;   // tighter than before (was 0.66) - smaller pool
    var _h  = _w * 0.26;                      // squashed: ground perspective
    var _cy = baseline_y - _h * 0.5;          // sit just above the passed feet baseline
    var _prev_a = draw_get_alpha();
    draw_set_color(c_black);
    // Three stacked ellipses (soft halo -> mid -> dense core). Sized down so the
    // contact shadow hugs the feet instead of spreading into a big pool, while the
    // graded alphas keep it readable on dark arena floors.
    draw_set_alpha(0.30);
    draw_ellipse(cx - _w * 0.62, _cy - _h * 0.62, cx + _w * 0.62, _cy + _h * 0.62, false);
    draw_set_alpha(0.48);
    draw_ellipse(cx - _w * 0.44, _cy - _h * 0.44, cx + _w * 0.44, _cy + _h * 0.44, false);
    draw_set_alpha(0.66);
    draw_ellipse(cx - _w * 0.28, _cy - _h * 0.28, cx + _w * 0.28, _cy + _h * 0.28, false);
    draw_set_alpha(_prev_a);
    draw_set_color(c_white);
}

// ---------------------------------------------------------------------------
// ui_draw_ability_buttons(x, y, ability_array, selected_index, caster)
// Draws a row of ability buttons showing name and energy cost.
// Uncastable abilities are dimmed. The selected ability gets a bold, bright gold
// ring (over its role-coloured border) so it's unmistakable while scrolling.
// Each button: 240x75 with 12px gap.
// ---------------------------------------------------------------------------
function ui_draw_ability_buttons(x, y, ability_array, selected_index, caster) {
    var btn_width  = 240;
    var btn_height = 75;
    var btn_gap    = 12;

    var count = array_length(ability_array);

    draw_set_font(fnt_ui_small);
    for (var i = 0; i < count; i++) {
        var ab = ability_array[i];
        var bx = x + i * (btn_width + btn_gap);
        // Same-category synergy discount (SYSTEMS_ABILITY_SYNERGY.md): the displayed AP
        // and the affordability gate both use the effective (discounted) cost, so a
        // button the discount makes castable lights up. Secondary resource checked apart.
        var _eff_cost  = ability_effective_cost(ab, caster);
        var _discounted = (_eff_cost < ab.energy_cost);
        var castable    = (caster.energy >= _eff_cost) && ability_secondary_ok(ab, caster);

        // Per-ability cooldown (Blink / Shadow Step). On cooldown == not usable.
        var _cd = (variable_struct_exists(caster, "ability_cd") && i < array_length(caster.ability_cd))
                  ? caster.ability_cd[i] : 0;

        // Dim uncastable or cooling-down buttons
        if (!castable || _cd > 0) {
            draw_set_alpha(0.45);
        }

        // Button background - dark fill
        draw_set_color(make_color_rgb(40, 40, 55));
        draw_rectangle(bx, y, bx + btn_width, y + btn_height, false);

        // Role-category border on EVERY button (offense red / defense blue / support
        // green / control purple) for at-a-glance role reading (SYSTEMS_ABILITY_SYNERGY.md).
        // Drawn 3px thick (stacked inward outlines) so the role colour is noticeable in
        // combat and stays readable next to the gold selection ring below.
        draw_set_color(ability_category_color(ability_category(ab)));
        for (var _b = 0; _b < 3; _b++) {
            draw_rectangle(bx + _b, y + _b, bx + btn_width - _b, y + btn_height - _b, true);
        }

        // Selected ability: a bold, bright gold ring drawn OUTSIDE the role border so
        // the active choice is unmistakable even between same-coloured neighbours (the
        // old 1px white border was ambiguous while scrolling). Full alpha so it stays
        // bright even when the ability is dimmed for being uncastable; thickened by
        // stacking outlines that expand outward (buttons have a 12px gap, no overlap).
        if (i == selected_index) {
            var _prev_sel_a = draw_get_alpha();
            draw_set_alpha(1.0);
            draw_set_color(make_color_rgb(255, 224, 120));
            for (var _t = 1; _t <= 3; _t++) {
                draw_rectangle(bx - _t, y - _t, bx + btn_width + _t, y + btn_height + _t, true);
            }
            draw_set_alpha(_prev_sel_a);
        }

        // Ability icon - 60x60 badge on the left (inherits the dim alpha above)
        var _icon_sz = 60;
        ui_draw_ability_icon(bx + 8, y + 8, _icon_sz, ab);

        // Ability name (centered in the area right of the icon, upper half).
        // Wraps onto two lines and scales down to fit so long names (e.g.
        // "Adrenaline Rush") stay whole and inside the button.
        var _name_left = bx + 8 + _icon_sz + 5;
        var _name_w    = (bx + btn_width) - _name_left - 6;
        draw_set_color(c_white);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        ui_draw_label_fit(_name_left + (bx + btn_width - _name_left) / 2, y + 26, ab.name, _name_w, 45);

        // Cooldown badge - overrides the AP pips while the ability is recharging.
        if (_cd > 0) {
            draw_set_color(make_color_rgb(120, 160, 255));
            draw_text(bx + btn_width / 2, y + btn_height - 18, "CD " + string(_cd));
            draw_set_alpha(1.0);
            continue;
        }

        // Energy cost pips in bottom half - small 12x12 squares. Count is the EFFECTIVE
        // (synergy-discounted) cost; lit pips turn green when discounted so the saving
        // pops, yellow otherwise (SYSTEMS_ABILITY_SYNERGY.md).
        var pip_size = 12;
        var pip_gap  = 5;
        var pip_count = _eff_cost;   // already floored at 1 for non-free; 0 stays 0 (free)
        var pip_total_width = pip_count * (pip_size + pip_gap) - pip_gap;
        var pip_start_x = bx + (btn_width - pip_total_width) / 2;
        var pip_y       = y + btn_height - 21;
        var _lit_color  = _discounted ? make_color_rgb(120, 230, 140) : c_yellow;

        for (var p = 0; p < pip_count; p++) {
            var px = pip_start_x + p * (pip_size + pip_gap);
            // Lit if the caster has enough energy to cover pips up to this one
            if (p < caster.energy) {
                draw_set_color(_lit_color);
            } else {
                draw_set_color(c_dkgray);
            }
            draw_rectangle(px, pip_y, px + pip_size, pip_y + pip_size, false);
        }

        draw_set_alpha(1.0);
    }

    // Reset alignment
    draw_set_font(-1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
}

// ---------------------------------------------------------------------------
// ui_draw_telegraph_warning(enemy_name, message)
// Draws a red banner sized to its text and centered at y=900 - NOT full screen
// width, so it clears the combat log at the bottom-left.
// Only called when enemy_should_telegraph() returns true for any enemy.
// ---------------------------------------------------------------------------
function ui_draw_telegraph_warning(enemy_name, message) {
    var room_w      = GUI_W;
    var banner_h    = 54;
    var banner_y    = 900;

    // Fall back to a generic wind-up warning when an enemy has no authored message
    // (most bosses set telegraph_turn/damage but inherit an empty message from their
    // base clone, so the banner used to show just the name).
    var _msg = (is_string(message) && message != "")
             ? message : "is charging a devastating attack!";
    var warning_text = enemy_name + " " + _msg;

    // Size the banner to the text (centered) instead of spanning the whole screen.
    draw_set_font(fnt_ui);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    var _pad_x = 42;
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

    // Warning text - fake bold via a 1px dark-red shadow under white.
    draw_set_color(make_color_rgb(80, 0, 0));
    draw_text(room_w / 2 + 2, mid_y + 2, warning_text);
    draw_set_color(c_white);
    draw_text(room_w / 2, mid_y, warning_text);

    draw_set_font(-1);
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
// ---------------------------------------------------------------------------
// ui_draw_log_line(x, y, str, max_w)
// Draws one combat-log line word-by-word, tinting the operative words so key
// events pop: CRIT (gold), MISS / DODGE (cool gray-blue / cyan), and the eight
// element schools (school_color). A number immediately tied to one of those
// events inherits its color too. Everything else stays the caller's color.
// Truncates with "..." at max_w. Caller sets font + alpha first.
// ---------------------------------------------------------------------------
function ui_draw_log_line(x, y, str, max_w) {
    var _COL_BASE  = make_color_rgb(225, 225, 230);
    var _COL_CRIT  = make_color_rgb(255, 205,  70);
    var _COL_MISS  = make_color_rgb(150, 165, 195);
    var _COL_DODGE = make_color_rgb( 95, 210, 220);
    var _COL_GOLD  = make_color_rgb(240, 200,  70);
    var _COL_DUST  = make_color_rgb( 90, 195, 185);

    var _words = string_split_words_log(str);
    var _n = array_length(_words);
    var _cx = x;
    var _space_w = string_width(" ");

    // Pre-scan: pick the color a number in this line should take, even when the
    // keyword comes AFTER the number (the log writes "... for 42 damage (CRIT!)").
    // Priority: crit > school > gold. Gold also covers loot/economy lines.
    var _num_col   = -1;
    var _gold_line = false;
    for (var _ps = 0; _ps < _n; _ps++) {
        var _pc = string_lower(string_trim_punct_log(_words[_ps]));
        if (_pc == "crit" || _pc == "critical" || _pc == "crits") { _num_col = _COL_CRIT; }
        if (_num_col != _COL_CRIT && (_pc == "fire" || _pc == "frost" || _pc == "shock" || _pc == "arcane"
            || _pc == "blood" || _pc == "void" || _pc == "shadow" || _pc == "poison")) {
            if (_num_col == -1) _num_col = school_color(_pc);
        }
        if (_pc == "gold" || log_word_is_goldnum(_pc)) _gold_line = true;
    }
    if (_num_col == -1 && _gold_line) _num_col = _COL_GOLD;

    for (var _i = 0; _i < _n; _i++) {
        var _w    = _words[_i];
        var _core = string_lower(string_trim_punct_log(_w));
        var _col  = _COL_BASE;
        var _is_num = (_core != "" && string_digits(_core) == _core);

        if (_core == "crit" || _core == "critical" || _core == "crits") {
            _col = _COL_CRIT;
        } else if (_core == "miss" || _core == "missed" || _core == "misses" || _core == "missing") {
            _col = _COL_MISS;
        } else if (_core == "dodge" || _core == "dodged" || _core == "dodges") {
            _col = _COL_DODGE;
        } else if (_core == "fire" || _core == "frost" || _core == "shock" || _core == "arcane"
                || _core == "blood" || _core == "void" || _core == "shadow" || _core == "poison") {
            _col = school_color(_core);
        } else if (_core == "gold" || log_word_is_goldnum(_core)) {
            _col = _COL_GOLD;
        } else if (_core == "dust" || _core == "rune") {
            _col = _COL_DUST;
        } else if (_core == "common")      { _col = make_color_rgb(165, 170, 180);
        } else if (_core == "uncommon")    { _col = make_color_rgb(100, 205, 100);
        } else if (_core == "rare")        { _col = make_color_rgb( 90, 155, 235);
        } else if (_core == "epic")        { _col = make_color_rgb(190, 110, 235);
        } else if (_core == "legendary")   { _col = make_color_rgb(235, 150,  60);
        } else if (_core == "consumable")  { _col = make_color_rgb( 90, 210, 210);
        } else if (_is_num && _num_col != -1) {
            _col = _num_col;
        }

        // Word + trailing space; stop with an ellipsis if we'd overflow.
        var _seg_w = string_width(_w);
        if (_cx + _seg_w > x + max_w) {
            draw_set_color(_COL_BASE);
            draw_text(_cx, y, "...");
            return;
        }
        draw_set_color(_col);
        draw_text(_cx, y, _w);
        _cx += _seg_w + _space_w;
    }
}

// log_word_is_goldnum(core) - true for a "12g" style gold amount (digits + a
// trailing 'g'), so the combat log can tint gold drops in gold.
function log_word_is_goldnum(_core) {
    var _len = string_length(_core);
    if (_len < 2) return false;
    if (string_char_at(_core, _len) != "g") return false;
    var _digits = string_copy(_core, 1, _len - 1);
    return (string_digits(_digits) == _digits);
}

// Split a log line on spaces (helper kept local so the renderer stays self-
// contained). Returns an array of words with empties dropped.
function string_split_words_log(_s) {
    var _out = [];
    var _cur = "";
    for (var _i = 1; _i <= string_length(_s); _i++) {
        var _c = string_char_at(_s, _i);
        if (_c == " ") {
            if (_cur != "") { array_push(_out, _cur); _cur = ""; }
        } else {
            _cur += _c;
        }
    }
    if (_cur != "") array_push(_out, _cur);
    return _out;
}

// Strip leading/trailing punctuation from a word so keyword matching is clean
// ("(CRIT!)" -> "crit!" stays, but "42," -> "42"). Keeps inner characters.
function string_trim_punct_log(_w) {
    var _p = "(),.:;'\"+-[]!?";
    var _s = _w;
    while (string_length(_s) > 0 && string_pos(string_char_at(_s, 1), _p) > 0)
        _s = string_delete(_s, 1, 1);
    while (string_length(_s) > 0 && string_pos(string_char_at(_s, string_length(_s)), _p) > 0)
        _s = string_delete(_s, string_length(_s), 1);
    return _s;
}

function ui_draw_combat_log(x, y, width, height, log_array) {
    var line_h  = 29;
    var padding = 12;

    // Background panel
    draw_set_alpha(0.7);
    draw_set_color(make_color_rgb(15, 15, 25));
    draw_rectangle(x, y, x + width, y + height, false);
    draw_set_alpha(1.0);
    draw_set_color(c_gray);
    draw_rectangle(x, y, x + width, y + height, true);

    var log_count = array_length(log_array);
    if (log_count == 0) return;

    draw_set_font(fnt_ui_small);
    var max_width = width - (padding * 2) - 21;   // leave room for a scrollbar gutter
    // One compact line per entry (truncated, never wrapped) so many fit; this lets
    // the player see far more history at once and pairs with mouse-wheel scrollback.
    var _visible_rows = floor((height - padding * 2) / line_h);

    // Scrollback offset (0 = pinned to newest). Read from the combat controller so
    // the mouse wheel - handled in obj_combat_controller Step - can drive it.
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
        // Keyword/number color coding (crit/miss/dodge/schools); truncates internally.
        ui_draw_log_line(x + padding, _ly, log_array[_idx], max_width);
    }
    draw_set_alpha(1.0);

    // Scroll indicators + a simple scrollbar when there's history to scroll
    if (log_count > _visible_rows) {
        draw_set_halign(fa_right);
        draw_set_color(make_color_rgb(120, 140, 170));
        if (_scroll > 0)                                 draw_text(x + width - 9, y + 3, "^ older");
        if (_scroll < log_count - _visible_rows)         draw_text(x + width - 9, y + height - 27, "v newer");
        draw_set_halign(fa_left);

        // Scrollbar track + thumb on the right gutter
        var _bar_x = x + width - 9;
        draw_set_color(make_color_rgb(40, 45, 60));
        draw_line_width(_bar_x, y + 3, _bar_x, y + height - 3, 5);
        var _track_h = height - 6;
        var _thumb_h = max(18, _track_h * (_visible_rows / log_count));
        // _scroll 0 = bottom; map to a thumb position (bottom = newest)
        var _frac    = (log_count - _visible_rows) > 0 ? (_scroll / (log_count - _visible_rows)) : 0;
        var _thumb_y = (y + height - 3 - _thumb_h) - _frac * (_track_h - _thumb_h);
        draw_set_color(make_color_rgb(110, 130, 160));
        draw_line_width(_bar_x, _thumb_y, _bar_x, _thumb_y + _thumb_h, 5);
    }
    draw_set_font(-1);
}

// ---------------------------------------------------------------------------
// ui_draw_ability_tooltip(x, anchor_bottom, ability, caster)
// Draws a tooltip panel for the currently selected ability (name, costs,
// damage, effect, accuracy). Width is fixed (480); HEIGHT is measured from the
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
    while (string_length(_s) > 1 && string_width(_s + "...") > max_w) {
        _s = string_copy(_s, 1, string_length(_s) - 1);
    }
    return _s + "...";
}

// ---------------------------------------------------------------------------
// ui_draw_label_fit(cx, cy, str, box_w, box_h)
// Draws a label centered on (cx, cy) that always fits inside box_w x box_h: first
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

    // No space - single long word: scale the one line to fit.
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
    var panel_w   = 480;
    var padding   = 21;
    var line_h    = 33;
    var _ew       = panel_w - padding * 2;

    // Body font drives string_height_ext sizing below; the name line overrides to
    // fnt_ui then restores. line_h (33) exceeds both fonts' line heights so the
    // measured/ drawn heights stay consistent.
    draw_set_font(fnt_ui_small);

    // --- Pre-compute the variable-content lines so the panel can be sized to fit
    //     exactly and anchored by its bottom edge (see header). Mirror these flags
    //     in the height sum and the body draw so all three stay consistent. ---
    var _ac_lbl  = ability_attack_class_label(ability_attack_class(ability));
    // Element school prefix (SYSTEMS_ELEMENT_SCHOOLS.md §E): "Fire - Ranged Spell".
    var _sch_lbl = school_label(ability_school(ability));
    var _class_line = (_sch_lbl != "" && _ac_lbl != "") ? (_sch_lbl + " - " + _ac_lbl)
                    : (_sch_lbl != "" ? _sch_lbl : _ac_lbl);
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
    if (_class_line != "") panel_h += line_h;  // school - attack-class label
    if (_is_aoe)       panel_h += line_h;   // AoE indicator
    panel_h += line_h / 2;                  // blank gap
    if (_has_dmg)      panel_h += line_h;   // damage
    panel_h += _effect_h;                   // effect description (wrapped)
    panel_h += line_h;                      // accuracy / always-hits
    panel_h += line_h;                      // [V] details hint
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
    ui_draw_ability_icon(x + panel_w - padding - 54, _py + padding, 54, ability);

    // --- Line 1: Ability name (fake bold) ---
    draw_set_font(fnt_ui);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_color(make_color_rgb(40, 50, 70));
    draw_text(tx + 2, cur_y + 2, ability.name);
    draw_set_color(c_white);
    draw_text(tx, cur_y, ability.name);
    draw_set_font(fnt_ui_small);
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

    // --- School - Attack class (melee/ranged x attack/spell) - drives root/silence ---
    if (_class_line != "") {
        draw_set_color(make_color_rgb(150, 175, 210));
        draw_text(tx, cur_y, _class_line);
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

    // --- Line 7: Hit chance (only when not guaranteed) ---
    } else {
        // Stage 1 = accuracy to connect, EXACTLY as combat_roll_hit receives it (scr_combat):
        // ability base accuracy + the caster's curved ACC_modifier (caster.acc), minus blind,
        // plus ranged-rune accuracy; clamped 5..99. The OLD display used a linear DEX*3 that
        // massively overstated it (e.g. 95% shown vs ~82% real for a low-DEX caster).
        var _acc_bonus = variable_struct_exists(caster, "acc") ? caster.acc : 0;
        var _blind_pen = round(combat_status_max(caster, "blind") * 100);
        var _stage1 = clamp(ability.base_acc + _acc_bonus - _blind_pen + rune_aspect_ranged_acc(ability), 5, 99);
        // Stage 2 = the target then rolls its DODGE to evade a connecting hit, so the REAL
        // chance to land vs the selected enemy is stage1 * (1 - dodge). Look up that enemy's
        // dodge from the combat controller (this tooltip is combat-only).
        var _tgt_dodge = 0;
        if (instance_exists(obj_combat_controller)) {
            var _cc_tip = instance_find(obj_combat_controller, 0);
            if (variable_instance_exists(_cc_tip, "selected_target") && variable_instance_exists(_cc_tip, "combat_state")) {
                var _li_t  = 0;
                var _cbt_t = _cc_tip.combat_state.combatants;
                for (var _ti = 0; _ti < array_length(_cbt_t); _ti++) {
                    var _tc = _cbt_t[_ti];
                    if (_tc.is_player || _tc.is_defeated) continue;
                    if (_li_t == _cc_tip.selected_target) { _tgt_dodge = clamp(_tc.dodge, 0, 90); break; }
                    _li_t++;
                }
            }
        }
        var _net = round(_stage1 * (1 - _tgt_dodge / 100));
        draw_set_color(c_ltgray);
        if (_tgt_dodge > 0) {
            draw_text(tx, cur_y, "Hit: " + string(_net) + "%  (Acc " + string(_stage1) + "% - Dodge " + string(_tgt_dodge) + "%)");
        } else {
            draw_text(tx, cur_y, "Hit: " + string(_stage1) + "%");
        }
    }
    cur_y += line_h;

    // --- Footer hint: V opens the full ability breakdown (mirrors the Tab popup on
    //     the loadout / Vex screens; Tab is the target-cycle key in combat). ---
    draw_set_color(make_color_rgb(150, 160, 190));
    draw_text(tx, cur_y, "[V] Ability details");

    draw_set_font(-1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
}

// ---------------------------------------------------------------------------
// ui_draw_combat_hud(combat_state, player, ability_array, selected_ability_index, log_array)
// Master draw function - calls all component functions at their correct positions.
//
// Layout (native 1920x1080; combat fonts fnt_ui / fnt_ui_small / fnt_ui_title):
//   Top-left       Player HP bar         (30,  30) w375 h36
//   Below HP       Energy pips           (20,  56)
//   Below energy   Secondary resource    (20,  90) w250 h16
//   Top-center     Turn queue            (400, 10)
//   Bottom-center  Ability buttons       (160, 640)
//   Bottom-left    Combat log            (20,  200) w440 h280
//   Lower-right    Ability tooltip       x940 w320, bottom-anchored y630 (auto-h)
//   Top overlay    Telegraph warning     (full-width, only when active)
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// ui_boon_style(id) - visual style for a boon id: short abbreviation + badge
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
// ui_draw_active_boons(x, y) - vertical "BOONS" strip for the combat HUD.
// Boons are run-scoped (no per-turn duration) so this is a static legend:
// an abbr-badge + the boon's name per active boon. No-op when none active.
// ---------------------------------------------------------------------------
function ui_draw_active_boons(x, y) {
    if (!variable_global_exists("run_boons")) return;
    var _n = array_length(global.run_boons);
    if (_n == 0) return;

    draw_set_font(fnt_ui_small);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
    draw_set_color(make_color_rgb(150, 140, 110));
    draw_text(x, y, "BOONS");

    var _ry = y + 24;
    for (var _i = 0; _i < _n; _i++) {
        var _b = boon_get(global.run_boons[_i]);
        if (_b == undefined) continue;
        var _st = ui_boon_style(global.run_boons[_i]);

        // colored badge with short code
        draw_set_alpha(0.9);
        draw_set_color(_st.col);
        draw_roundrect(x, _ry, x + 60, _ry + 21, false);
        draw_set_alpha(1.0);
        draw_set_color(make_color_rgb(10, 10, 18));
        draw_roundrect(x, _ry, x + 60, _ry + 21, true);
        draw_set_color(c_white);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_text(x + 30, _ry + 11, _st.abbr);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);

        // boon name to the right of the badge
        draw_set_color(make_color_rgb(200, 205, 215));
        draw_text(x + 69, _ry + 2, _b.name);

        _ry += 27;
    }

    draw_set_font(-1);
    draw_set_alpha(1.0);
    draw_set_color(c_white);
}

// ---------------------------------------------------------------------------
// ui_curse_style(id) - short badge code + color for an active curse.
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
// ui_draw_active_curses(x, y) - vertical "CURSES" strip for the combat HUD.
// Mirrors ui_draw_active_boons (static legend; curses are run-scoped). No-op
// when none active. Returns the next free y so callers can stack panels.
// ---------------------------------------------------------------------------
function ui_draw_active_curses(x, y) {
    if (!variable_global_exists("run_curses")) return y;
    var _n = array_length(global.run_curses);
    if (_n == 0) return y;

    draw_set_font(fnt_ui_small);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
    draw_set_color(make_color_rgb(170, 90, 90));
    draw_text(x, y, "CURSES");

    var _ry = y + 24;
    for (var _i = 0; _i < _n; _i++) {
        var _c = curse_get(global.run_curses[_i]);
        if (_c == undefined) continue;
        var _st = ui_curse_style(global.run_curses[_i]);

        draw_set_alpha(0.9);
        draw_set_color(_st.col);
        draw_roundrect(x, _ry, x + 60, _ry + 21, false);
        draw_set_alpha(1.0);
        draw_set_color(make_color_rgb(10, 10, 18));
        draw_roundrect(x, _ry, x + 60, _ry + 21, true);
        draw_set_color(c_white);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_text(x + 30, _ry + 11, _st.abbr);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);

        draw_set_color(make_color_rgb(215, 180, 185));
        draw_text(x + 69, _ry + 2, _c.name);

        _ry += 27;
    }

    draw_set_font(-1);
    draw_set_alpha(1.0);
    draw_set_color(c_white);
    return _ry + 9;
}

// ---------------------------------------------------------------------------
// ui_draw_settings_overlay() - audio settings panel (Music + SFX sliders).
// Reads global.music_volume / global.sfx_volume / global.settings_cursor (see
// the audio_settings_* helpers in scr_stats). Called from the title + hub when
// global.settings_open. Draw-only; input is handled by audio_settings_handle_input.
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// ui_draw_pause_menu() - Resume / Settings / Quit to Title overlay. Drawn by each
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
    draw_rectangle(0, 0, GUI_W, GUI_H, false);
    draw_set_alpha(1.0);

    // Panel
    var _pw = 540, _ph = 450, _px = GUI_CX - _pw / 2, _py = 315;
    draw_set_color(make_color_rgb(20, 22, 34));
    draw_rectangle(_px, _py, _px + _pw, _py + _ph, false);
    draw_set_color(make_color_rgb(90, 110, 160));
    draw_rectangle(_px, _py, _px + _pw, _py + _ph, true);

    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_font(fnt_ui_title);
    draw_set_color(c_white);
    draw_text(GUI_CX, _py + 33, "Paused");

    var _labels  = ["Resume", "Settings", "Quit to Title"];
    var _cur     = global.pause_cursor;
    var _row_h   = 84, _first_y = 468, _bx0 = 735, _bx1 = 1185;
    draw_set_font(fnt_ui);
    for (var _r = 0; _r < 3; _r++) {
        var _ry = _first_y + _r * _row_h;
        var _on = (_r == _cur);
        draw_set_color(_on ? make_color_rgb(45, 55, 86) : make_color_rgb(26, 28, 40));
        draw_rectangle(_bx0, _ry, _bx1, _ry + 66, false);
        draw_set_color(_on ? make_color_rgb(120, 160, 230) : make_color_rgb(60, 66, 90));
        draw_rectangle(_bx0, _ry, _bx1, _ry + 66, true);
        draw_set_color(_on ? c_white : make_color_rgb(180, 188, 205));
        draw_text(GUI_CX, _ry + 18, _labels[_r]);
    }

    // Controls legend - auto-scaled to fit inside the panel's inner width so it can
    // never spill past the side borders (panel is only _pw wide). Centered at GUI_CX,
    // and kept above the panel's bottom edge (_py + _ph). Shrink-to-fit is dynamic.
    var _legend    = "W/S: Navigate    Enter: Select    Esc: Resume";
    var _legend_pad = 36;
    draw_set_font(fnt_ui_small);
    var _legend_sc  = min(1.0, (_pw - _legend_pad) / max(1, string_width(_legend)));
    var _legend_y   = _py + _ph - 39;
    draw_set_color(make_color_rgb(110, 118, 140));
    draw_text_transformed(GUI_CX, _legend_y, _legend, _legend_sc, _legend_sc, 0);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
    draw_set_font(-1);
}

// ---------------------------------------------------------------------------
// ui_draw_tutorial_tip() - contextual onboarding coach-mark (see
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
    draw_rectangle(0, 0, GUI_W, GUI_H, false);
    draw_set_alpha(1.0);

    var _bw   = 990;
    var _wrap = _bw - 120;           // body wrap width (inside L/R padding)

    draw_set_halign(fa_center);
    draw_set_valign(fa_top);

    // Size the box to the wrapped body so long tips never overflow.
    draw_set_font(fnt_ui);
    var _body_h = string_height_ext(_t.body, -1, _wrap);
    var _bh = 108 + _body_h + 78;    // title band + body + footer band
    var _bx = GUI_CX - _bw / 2;
    var _by = GUI_CY - _bh / 2;

    // Panel
    draw_set_color(make_color_rgb(18, 20, 30));
    draw_rectangle(_bx, _by, _bx + _bw, _by + _bh, false);

    // Title
    draw_set_font(fnt_ui_title);
    draw_set_color(make_color_rgb(228, 200, 130));
    draw_text(GUI_CX, _by + 33, _t.title);

    // Divider under the title
    draw_set_color(make_color_rgb(70, 64, 48));
    draw_line(_bx + 45, _by + 90, _bx + _bw - 45, _by + 90);

    // Body - wrapped + centered inside the box
    draw_set_font(fnt_ui);
    draw_set_color(make_color_rgb(205, 210, 222));
    draw_text_ext(GUI_CX, _by + 111, _t.body, -1, _wrap);

    // Footer hint
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(120, 128, 150));
    draw_text(GUI_CX, _by + _bh - 45, "Press any key or click to continue");

    // Ornate gothic rim (surrounds the box outward; box is centered with screen room).
    draw_set_font(-1);
    ui_draw_gothic_frame(_bx, _by, _bx + _bw, _by + _bh, 30);

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
    draw_rectangle(0, 0, GUI_W, GUI_H, false);
    draw_set_alpha(1.0);

    // Panel (tall enough for: Music, SFX, Fullscreen, Tutorial Tips, Reset Tutorial)
    var _pw = 840, _ph = 678;
    var _px = GUI_CX - _pw / 2;
    var _py = GUI_CY - _ph / 2;
    draw_set_color(make_color_rgb(18, 22, 36));
    draw_rectangle(_px, _py, _px + _pw, _py + _ph, false);
    draw_set_color(make_color_rgb(80, 140, 220));
    draw_rectangle(_px, _py, _px + _pw, _py + _ph, true);

    // Title
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_font(fnt_ui_title);
    draw_set_color(c_white);
    draw_text(GUI_CX, _py + 39, "SETTINGS");

    var _row_y  = _py + 150;
    var _row_h  = 108;
    var _bar_x  = _px + 300;
    var _bar_w  = 420;
    var _bar_h  = 27;

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
            draw_rectangle(_px + 30, _ry - 21, _px + _pw - 30, _ry + 45, false);
            draw_set_alpha(1.0);
        }

        // Label
        draw_set_halign(fa_left);
        draw_set_valign(fa_middle);
        draw_set_font(fnt_ui);
        draw_set_color(_sel ? c_white : make_color_rgb(170, 180, 200));
        draw_text(_px + 60, _ry + 12, (_sel ? "> " : "  ") + _labels[_i]);

        // Slider track
        var _by = _ry + 3;
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
        draw_text(_bar_x + _bar_w + 24, _by + _bar_h / 2, string(round(_vols[_i] * 100)) + "%");
    }

    // --- Third row: Fullscreen toggle ---
    var _fry = _row_y + 2 * _row_h;
    var _fsel = (global.settings_cursor == 2);
    if (_fsel) {
        draw_set_alpha(0.20);
        draw_set_color(make_color_rgb(80, 140, 220));
        draw_rectangle(_px + 30, _fry - 21, _px + _pw - 30, _fry + 45, false);
        draw_set_alpha(1.0);
    }
    draw_set_halign(fa_left);
    draw_set_valign(fa_middle);
    draw_set_font(fnt_ui);
    draw_set_color(_fsel ? c_white : make_color_rgb(170, 180, 200));
    draw_text(_px + 60, _fry + 12, (_fsel ? "> " : "  ") + "Fullscreen");

    // On/Off pill
    var _on   = global.fullscreen;
    var _pill_x = _bar_x;
    var _pill_y = _fry + 3;
    var _pill_w = 138;
    var _pill_h = _bar_h + 6;
    draw_set_color(_on ? make_color_rgb(50, 130, 90) : make_color_rgb(45, 50, 66));
    draw_rectangle(_pill_x, _pill_y, _pill_x + _pill_w, _pill_y + _pill_h, false);
    draw_set_color(_fsel ? make_color_rgb(120, 190, 255) : make_color_rgb(70, 85, 110));
    draw_rectangle(_pill_x, _pill_y, _pill_x + _pill_w, _pill_y + _pill_h, true);
    draw_set_halign(fa_center);
    draw_set_color(c_white);
    draw_text(_pill_x + _pill_w / 2, _pill_y + _pill_h / 2, _on ? "ON" : "OFF");
    draw_set_halign(fa_left);
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(140, 150, 170));
    draw_text(_pill_x + _pill_w + 24, _pill_y + _pill_h / 2, "(F11)");

    // --- Fourth row: Tutorial Tips on/off toggle ---
    var _tut_on = (!variable_global_exists("tutorial_enabled")) || global.tutorial_enabled;
    var _try    = _fry + 84;
    var _tsel   = (global.settings_cursor == 3);
    if (_tsel) {
        draw_set_alpha(0.20);
        draw_set_color(make_color_rgb(80, 140, 220));
        draw_rectangle(_px + 30, _try - 21, _px + _pw - 30, _try + 45, false);
        draw_set_alpha(1.0);
    }
    draw_set_halign(fa_left);
    draw_set_valign(fa_middle);
    draw_set_font(fnt_ui);
    draw_set_color(_tsel ? c_white : make_color_rgb(170, 180, 200));
    draw_text(_px + 60, _try + 12, (_tsel ? "> " : "  ") + "Tutorial Tips");

    var _tpx = _bar_x;
    var _tpy = _try + 3;
    var _tpw = 138;
    var _tph = _bar_h + 6;
    draw_set_color(_tut_on ? make_color_rgb(50, 130, 90) : make_color_rgb(45, 50, 66));
    draw_rectangle(_tpx, _tpy, _tpx + _tpw, _tpy + _tph, false);
    draw_set_color(_tsel ? make_color_rgb(120, 190, 255) : make_color_rgb(70, 85, 110));
    draw_rectangle(_tpx, _tpy, _tpx + _tpw, _tpy + _tph, true);
    draw_set_halign(fa_center);
    draw_set_color(c_white);
    draw_text(_tpx + _tpw / 2, _tpy + _tph / 2, _tut_on ? "ON" : "OFF");

    // --- Fifth row: Reset Tutorial (re-show every tip) ---
    var _rry  = _try + 72;
    var _rsel = (global.settings_cursor == 4);
    if (_rsel) {
        draw_set_alpha(0.20);
        draw_set_color(make_color_rgb(80, 140, 220));
        draw_rectangle(_px + 30, _rry - 21, _px + _pw - 30, _rry + 45, false);
        draw_set_alpha(1.0);
    }
    draw_set_halign(fa_left);
    draw_set_valign(fa_middle);
    draw_set_font(fnt_ui);
    draw_set_color(_rsel ? c_white : make_color_rgb(170, 180, 200));
    draw_text(_px + 60, _rry + 12, (_rsel ? "> " : "  ") + "Reset Tutorial");
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(140, 150, 170));
    draw_text(_bar_x, _rry + 12, "[ Enter ] Re-show all tips");

    // Reset confirmation flash
    if (variable_global_exists("settings_reset_flash") && global.settings_reset_flash > 0) {
        draw_set_halign(fa_center);
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(120, 200, 140));
        draw_text(GUI_CX, _py + _ph - 78, "Tutorial reset - tips will show again.");
    }

    // Footer hint
    draw_set_halign(fa_center);
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(150, 160, 185));
    draw_text_outline(GUI_CX, _py + _ph - 42, "W/S: Select    A/D or <-/->: Adjust / Toggle / Enter    Esc/O: Close");

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
    draw_set_font(-1);
}

// ui_draw_combat_overlay(...) - the hit-preview band + combat log. Split out of
// the HUD so the combat controller can draw it AFTER the battler sprites, keeping
// combat text on top of the sprites/shadows (text always has visual priority).
function ui_draw_combat_overlay(combat_state, player, ability_array, selected_ability_index, log_array) {
    // --- Ability hit preview (flashing, in the open band above the combat log) ---
    if (instance_exists(obj_combat_controller)) {
        var _cc_pv = instance_find(obj_combat_controller, 0);
        if (_cc_pv.player_turn && !_cc_pv.combat_over && !_cc_pv.show_loot_screen) {
            var _pv_ab    = ability_array[selected_ability_index];
            var _pv_live  = combat_living_enemies(combat_state);
            if (is_struct(_pv_ab) && array_length(_pv_live) > 0) {
                var _pv_mx  = device_mouse_x_to_gui(0);
                var _pv_my  = device_mouse_y_to_gui(0);
                var _pv_idx = clamp(_cc_pv.selected_target, 0, array_length(_pv_live) - 1);
                for (var _pvi = 0; _pvi < array_length(_pv_live); _pvi++) {
                    var _bx = (_pvi mod 2 == 0) ? 990 : 1485;
                    var _by = 96 + (_pvi div 2) * 78;
                    if (_pv_mx >= _bx && _pv_mx < _bx + 400 && _pv_my >= _by && _pv_my < _by + 42) {
                        _pv_idx = _pvi;
                        break;
                    }
                }
                var _pv_tgt = _pv_live[_pv_idx];
                var _pv_est = combat_estimate_hit(_pv_ab, player, _pv_tgt);

                var _pv_main = "";
                if (_pv_est >= 0) {
                    _pv_main = _pv_ab.name + "  will hit  " + _pv_tgt.name + "  for ~" + string(_pv_est) + " dmg";
                } else {
                    _pv_main = _pv_ab.name + "  ->  " + _pv_tgt.name;
                }

                var _flash = 0.6 + 0.4 * (0.5 + 0.5 * sin(current_time / 220));
                draw_set_halign(fa_left);
                draw_set_valign(fa_bottom);
                draw_set_alpha(_flash);
                draw_set_font(fnt_ui);
                draw_set_color(make_color_rgb(255, 226, 120));
                draw_text_outline(36, 726, _pv_main);

                var _pv_eff = variable_struct_exists(_pv_ab, "desc_short") ? _pv_ab.desc_short : "";
                if (_pv_eff != "") {
                    draw_set_alpha(min(1.0, _flash + 0.15));
                    draw_set_font(fnt_ui_small);
                    draw_set_color(make_color_rgb(180, 210, 230));
                    draw_text_outline(36, 700, "Effect:  " + _pv_eff);
                }
                draw_set_alpha(1.0);
                draw_set_valign(fa_top);
            }
        }
    }

    // --- Combat log (bottom strip) ---
    ui_draw_combat_log(30, 735, 1170, 210, log_array);
}

function ui_draw_combat_hud(combat_state, player, ability_array, selected_ability_index, log_array, draw_log = true) {

    // --- Turn queue (top-center) ---
    ui_draw_turn_queue(600, 15, combat_state);

    // --- Player HP bar (top-left) ---
    ui_draw_hp_bar(30, 30, 375, 36, player.HP, player.max_HP, "HP");

    // --- Energy pips (below HP bar) ---
    ui_draw_energy_pips(30, 84, player.energy, 3);

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
        ui_draw_secondary_resource(30, 135, res_cur, res_max, res_name, res_color);
    }

    // --- Run level and XP bar (below secondary resource) ---
    // "Lv X" label at y=173; XP bar at y=210 to clear the label's descenders.
    if (variable_global_exists("run_level")) {
        draw_set_font(fnt_ui);
        draw_set_color(c_white);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        draw_text(30, 173, "Lv " + string(global.run_level));

        var _xb  = 30;
        var _xbw = 375;
        var _xbh = 12;
        var _xby = 210;

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
            // Full golden bar at max level - no text overlap
            draw_set_color(make_color_rgb(160, 125, 25));
            draw_rectangle(_xb, _xby, _xb + _xbw, _xby + _xbh, false);
            draw_set_color(make_color_rgb(80, 70, 90));
            draw_rectangle(_xb, _xby, _xb + _xbw, _xby + _xbh, true);
            draw_set_halign(fa_center);
            draw_set_font(fnt_ui_small);
            draw_set_color(make_color_rgb(255, 200, 50));
            draw_text(_xb + _xbw * 0.5, _xby + _xbh * 0.5 + 2, "MAX");
            draw_set_halign(fa_left);
        }
        draw_set_font(-1);
    }

    // --- Active player buff icons (below XP bar) ---
    // Each carries an `se` descriptor (name + one-line desc + duration noun + colour) so
    // it hover-explains itself like the typed debuff badges do. These buffs live on the
    // player struct (not status_effects[]), so they have no typed `kind` - the desc is
    // authored here. (Task: every status has a mouse-over explanation.)
    var _pbuffs = [];
    if (variable_struct_exists(player, "iron_skin_duration") && player.iron_skin_duration > 0) {
        var _is_col = make_color_rgb(80, 140, 220);
        array_push(_pbuffs, {
            label:    "IS",
            color:    _is_col,
            duration: player.iron_skin_duration,
            se: { name: "Iron Skin", color: _is_col, duration: player.iron_skin_duration, dur_noun: "turn",
                  desc: "Iron Skin: reduces the damage you take from each incoming hit while active." }
        });
    }
    if (variable_struct_exists(player, "bloodthorn_active") && player.bloodthorn_active) {
        var _bt_col = make_color_rgb(190, 55, 55);
        var _bt_val = variable_struct_exists(player, "bloodthorn_value") ? player.bloodthorn_value : 0;
        array_push(_pbuffs, {
            label:    "BT",
            color:    _bt_col,
            duration: player.bloodthorn_duration,
            se: { name: "Bloodthorn Aura", color: _bt_col, duration: player.bloodthorn_duration, dur_noun: "turn",
                  desc: "Bloodthorn Aura: reflects " + string(_bt_val) + " damage back at any enemy that strikes you." }
        });
    }
    if (variable_struct_exists(player, "blink_charges") && player.blink_charges > 0) {
        var _blk_col = make_color_rgb(70, 75, 210);
        array_push(_pbuffs, {
            label:    "BLK",
            color:    _blk_col,
            duration: player.blink_charges,
            se: { name: "Blink", color: _blk_col, duration: player.blink_charges, dur_noun: "charge",
                  desc: "Blink: staged evasion of your next incoming attacks - the first is fully dodged, then half damage, then quarter as the charges drop." }
        });
    }
    if (variable_struct_exists(player, "is_untargetable") && player.is_untargetable) {
        var _van_col = make_color_rgb(120, 70, 200);
        array_push(_pbuffs, {
            label:    "VAN",
            color:    _van_col,
            duration: player.untargetable_turns,
            se: { name: "Vanish", color: _van_col, duration: player.untargetable_turns, dur_noun: "charge",
                  desc: "Vanished: a chance to completely avoid each incoming attack (scales with Wisdom); your next strike also deals bonus damage." }
        });
    }
    if (variable_struct_exists(player, "shadow_step_charges") && player.shadow_step_charges > 0) {
        var _ss_col = make_color_rgb(45, 155, 65);
        array_push(_pbuffs, {
            label:    "SS",
            color:    _ss_col,
            duration: player.shadow_step_charges,
            se: { name: "Shadow Step", color: _ss_col, duration: player.shadow_step_charges, dur_noun: "charge",
                  desc: "Shadow Step: a chance to dodge each of your next incoming attacks." }
        });
    }
    // Typed debuffs/statuses applied to the player (poison, Sight Clouded/blind,
    // weaken, stun, ...) live in player.status_effects[] - surface them here too so
    // the player can actually see what's afflicting them and for how long.
    if (variable_struct_exists(player, "status_effects")) {
        var _pstat = status_icons_from(player.status_effects);
        for (var _psi = 0; _psi < array_length(_pstat); _psi++) array_push(_pbuffs, _pstat[_psi]);
    }
    if (array_length(_pbuffs) > 0) {
        ui_draw_status_icon_row(30, 222, _pbuffs);
    }

    // --- Active run boons + curses (left column, below the per-combat buff row) ---
    // Boons occupy a header (24px) + 27px per entry; stack curses just beneath them.
    ui_draw_active_boons(30, 278);
    var _boon_n = variable_global_exists("run_boons") ? array_length(global.run_boons) : 0;
    var _curse_y = 278 + ((_boon_n > 0) ? (24 + 27 * _boon_n + 12) : 0);
    ui_draw_active_curses(30, _curse_y);

    // --- Ability buttons (bottom-center) ---
    ui_draw_ability_buttons(240, 990, ability_array, selected_ability_index, player);

    // --- Hit preview + combat log ---
    // Deferred to draw AFTER the battler sprites (so combat text always sits on top
    // of the sprites/shadows) when the caller passes draw_log=false; otherwise drawn
    // inline here. See ui_draw_combat_overlay.
    if (draw_log) {
        ui_draw_combat_overlay(combat_state, player, ability_array, selected_ability_index, log_array);
    }

    // --- Ability tooltip (lower-right) ---
    // Bottom-anchored at y945 (a 45px gap above the ability button row + C/Items
    // button, both at y990+) and sized to its content, growing UPWARD. This keeps
    // the wrapped effect text well clear of the Poison Dart (x1248-1488) button, no
    // matter how long the description. Left edge x1410 (width 480 => right edge
    // x1890), right of the combat log (x<=1200).
    var _sel_ab = ability_array[selected_ability_index];
    ui_draw_ability_tooltip(1410, 945, _sel_ab, player);

    // NOTE: Target selection indicator (">") is drawn in Draw_64.gml alongside
    // the enemy HP bars - it needs selected_target from obj_combat_controller
    // directly and cannot be drawn here without passing it as a parameter.

    // --- Telegraph warning (top overlay - check all enemies) ---
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
// Full-screen "press Tab for the breakdown" popup for one ability - the elaborate
// view so the dense screens don't have to cram the text. Shows icon, attack class,
// AP + secondary-resource cost, cooldown, the full generated mechanics, the status-
// reaction table (for detonators), and flavor. Drawn on the GUI layer over whatever
// screen opened it; the caller gates input while it's up. See SYSTEMS_VIABILITY_PASS.md.
// ---------------------------------------------------------------------------
function ui_draw_ability_detail(ab, close_key_label = "Tab") {
    if (!is_struct(ab)) return;

    // Dim the whole screen.
    draw_set_alpha(0.80); draw_set_color(c_black);
    draw_rectangle(0, 0, GUI_W, GUI_H, false);
    draw_set_alpha(1.0);

    var _x1 = 390, _y1 = 144, _x2 = 1530, _y2 = 936;
    draw_set_color(make_color_rgb(16, 17, 26));
    draw_rectangle(_x1, _y1, _x2, _y2, false);
    ui_draw_gothic_frame(_x1, _y1, _x2, _y2, 36);

    var _pad = 45;
    var _lx  = _x1 + _pad;
    var _rx  = _x2 - _pad;
    var _y   = _y1 + _pad;

    // --- Header: icon + name ---
    ui_draw_ability_icon(_lx, _y, 96, ab);
    var _tx = _lx + 96 + 27;
    draw_set_halign(fa_left); draw_set_valign(fa_top);
    draw_set_font(fnt_ui_title);
    draw_set_color(c_white);
    draw_text(_tx, _y + 3, ab.name);
    var _name_w = string_width(ab.name);

    // Role-category chip, drawn just to the RIGHT of the name so it auto-positions to
    // the name's length and can never overlap it (offense red / defense blue / support
    // green / control purple). string_width measures the drawn name; the chip pins back
    // to the right margin only if a very long name would push it off-panel.
    var _detail_cat  = ability_category(ab);
    var _detail_clbl = ability_category_label(_detail_cat);
    draw_set_font(fnt_ui);
    var _chip_x = _tx + _name_w + 27;
    var _chip_w = string_width(_detail_clbl);
    if (_chip_x + _chip_w > _rx) _chip_x = _rx - _chip_w;   // fallback: pin to right margin
    draw_set_color(ability_category_color(_detail_cat));
    draw_text(_chip_x, _y + 12, _detail_clbl);

    // Cost / class line.
    var _ap  = variable_struct_exists(ab, "energy_cost") ? ab.energy_cost : 0;
    var _sec = variable_struct_exists(ab, "secondary_cost") ? ab.secondary_cost : 0;
    var _cls = variable_global_exists("chosen_class") ? global.chosen_class : 0;
    var _resname = (_cls == 0) ? "Souls" : ((_cls == 1) ? "Blood" : "Preparation");
    var _costline = string(_ap) + " AP";
    if (_sec > 0) _costline += "   +" + string(_sec) + " " + _resname;
    var _cd = ability_cooldown(ab);
    if (_cd > 0) _costline += "   *   " + string(_cd) + "-turn cooldown";
    draw_set_font(fnt_ui);
    draw_set_color(make_color_rgb(228, 190, 90));
    draw_text(_tx, _y + 60, _costline);
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(150, 160, 190));
    // School prefix (SYSTEMS_ELEMENT_SCHOOLS.md §E), e.g. "Fire  (ranged/spell)".
    var _detail_school = school_label(ability_school(ab));
    var _detail_class  = ability_attack_class_tag(ab);
    if (_detail_school != "") _detail_class = _detail_school + " school  " + _detail_class;
    draw_text(_tx, _y + 93, _detail_class);

    _y += 144;
    draw_set_color(make_color_rgb(60, 64, 90));
    draw_line(_lx, _y, _rx, _y);
    _y += 24;

    // --- Mechanics (the canonical generated description) ---
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(120, 200, 140));
    draw_text(_lx, _y, "MECHANICS");
    _y += 36;
    draw_set_font(fnt_ui);
    draw_set_color(make_color_rgb(210, 214, 230));
    var _mech = ability_describe(ab);
    draw_text_ext(_lx, _y, _mech, -1, _rx - _lx);
    _y += string_height_ext(_mech, -1, _rx - _lx) + 27;

    // --- Role & same-category synergy (SYSTEMS_ABILITY_SYNERGY.md) ---
    var _cat_lbl = ability_category_label(_detail_cat);
    draw_set_font(fnt_ui_small);
    draw_set_color(ability_category_color(_detail_cat));
    draw_text(_lx, _y, _cat_lbl + " - same-role synergy");
    _y += 36;
    draw_set_font(fnt_ui);
    draw_set_color(make_color_rgb(200, 204, 220));
    var _syn_text = "After you cast another " + _cat_lbl + " ability this turn, this one "
                  + "costs 1 less AP (minimum 1). Chaining same-role abilities makes minor "
                  + "buffs and supports worth casting together.";
    draw_text_ext(_lx, _y, _syn_text, -1, _rx - _lx);
    _y += string_height_ext(_syn_text, -1, _rx - _lx) + 27;

    // --- Status reactions table (detonators only) ---
    if (ability_is_detonator(ab)) {
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(190, 160, 240));
        draw_text(_lx, _y, "STATUS REACTIONS  (this ability detonates a status on the target)");
        _y += 36;
        var _reacts = [
            "Exposed (Vulnerable) - +12 damage (mark persists)",
            "Root / Frost - +30% damage, shatters",
            "Stun - guaranteed critical hit",
            "Weaken - +15% damage",
            "Blind - cannot miss",
            "Poison - applies Mortality (-40% healing, 4 turns)",
            "Bleed - bursts every remaining bleed tick",
            "Void DoT - heals you for 30% of the damage dealt",
        ];
        draw_set_color(make_color_rgb(200, 204, 220));
        for (var _ri = 0; _ri < array_length(_reacts); _ri++) {
            draw_text(_lx + 12, _y, "*  " + _reacts[_ri]);
            _y += 33;
        }
        _y += 12;
    }

    // --- Flavor (legacy authored line, if any) ---
    if (variable_struct_exists(ab, "desc_full") && ab.desc_full != "") {
        draw_set_font(fnt_ui);
        draw_set_color(make_color_rgb(140, 146, 170));
        draw_text_ext(_lx, _y, ab.desc_full, -1, _rx - _lx);
    }

    // --- Footer ---
    draw_set_halign(fa_center);
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(150, 160, 190));
    draw_text_outline((_x1 + _x2) / 2, _y2 - 39, "[" + close_key_label + "] or [Esc] - Close");
    draw_set_halign(fa_left); draw_set_valign(fa_top);
    draw_set_color(c_white);
    draw_set_font(-1);
}

// ---------------------------------------------------------------------------
// ui_draw_trait_detail(tr)
// Full-screen Tab breakdown for a TRAIT (mirrors ui_draw_ability_detail). Traits
// are simpler - name + full description + class requirement.
// ---------------------------------------------------------------------------
function ui_draw_trait_detail(tr) {
    if (!is_struct(tr)) return;
    draw_set_alpha(0.80); draw_set_color(c_black);
    draw_rectangle(0, 0, GUI_W, GUI_H, false);
    draw_set_alpha(1.0);

    var _x1 = 450, _y1 = 240, _x2 = 1470, _y2 = 810;
    draw_set_color(make_color_rgb(16, 17, 26));
    draw_rectangle(_x1, _y1, _x2, _y2, false);
    ui_draw_gothic_frame(_x1, _y1, _x2, _y2, 36);

    var _pad = 45, _lx = _x1 + _pad, _rx = _x2 - _pad, _y = _y1 + _pad;
    draw_set_halign(fa_left); draw_set_valign(fa_top);
    draw_set_font(fnt_ui_title);
    draw_set_color(c_white);
    draw_text(_lx, _y, tr.name);
    _y += 66;
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(190, 160, 240));
    var _cr = variable_struct_exists(tr, "class_req") ? tr.class_req : -1;
    var _crn = (_cr == 0) ? "Arcanist only" : ((_cr == 1) ? "Bloodwarden only" : ((_cr == 2) ? "Shadowstrider only" : "Any class"));
    draw_text(_lx, _y, "TRAIT  *  " + _crn);
    _y += 45;
    draw_set_color(make_color_rgb(60, 64, 90));
    draw_line(_lx, _y, _rx, _y);
    _y += 24;
    draw_set_font(fnt_ui);
    draw_set_color(make_color_rgb(210, 214, 230));
    if (variable_struct_exists(tr, "description")) draw_text_ext(_lx, _y, tr.description, -1, _rx - _lx);

    draw_set_halign(fa_center);
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(150, 160, 190));
    draw_text_outline((_x1 + _x2) / 2, _y2 - 39, "[Tab] or [Esc] - Close");
    draw_set_halign(fa_left); draw_set_valign(fa_top);
    draw_set_color(c_white);
    draw_set_font(-1);
}

// ---------------------------------------------------------------------------
// ui_compendium_sections()
// Data for the Compendium / Help tab. Each section is { title, entries[] },
// each entry is { term, text }. Data-driven so new mechanics are a quick add -
// append a section here and it shows up in the menu automatically.
// ---------------------------------------------------------------------------
function ui_compendium_sections() {
    return [
        {
            title: "Damage Types",
            entries: [
                { term: "How types work", text: "The Damage TYPE decides how a hit is mitigated. There are four: Physical, Elemental, Void, and Blood. Each maps to a default school (see Damage Schools) but the TYPE is what Armor / wards check." },
                { term: "Physical",     text: "Weapon-based damage, reduced by the target's Armor. The default for most strikes and shots." },
                { term: "Elemental",    text: "Reduced by the target's Elemental Resistance (wards) instead of Armor. Covers the Fire, Frost, Shock and Arcane schools." },
                { term: "Void",         text: "Its own type (the Void school). Bypasses ALL mitigation - neither Armor nor wards reduce it. Void/drain hits often siphon life or resources from the target." },
                { term: "Blood",        text: "Its own type (the Blood school). Bypasses Armor (and isn't stopped by wards either). Many blood abilities are self-fuelled - they cost some of your own HP or Blood to cast." },
                { term: "Poison & DoTs", text: "Poison and other damage-over-time ticks land UNMITIGATED regardless of the type that applied them - Armor and wards don't reduce DoT ticks." },
            ],
        },
        {
            title: "Damage Schools",
            entries: [
                { term: "What schools are", text: "A school is the FLAVOR of an ability's damage (its build identity), layered on top of the Damage Type. The Damage Type still decides mitigation - a Fire spell is still Elemental for Armor/wards. The eight schools: Fire, Frost, Shock, Arcane, Blood, Void, Shadow, Poison." },
                { term: "School-damage gear", text: "Some gear grants \"+X <school> damage\" - a flat bonus added to every damaging ability of that school. It's always FLAT (never a percentage), so schools point your build in a direction without exploding your damage. A piece can carry more than one school, and they stack." },
                { term: "Schools vs. Types",  text: "Damage TYPE (Physical / Elemental / Void / Blood) = how the hit is mitigated. SCHOOL (Fire / Frost / Shock / Arcane / Blood / Void / Shadow / Poison) = what flavor it is and which \"+X school damage\" gear buffs it. A school bonus is mitigated by the ability's own Type - e.g. a Poison-school bonus on a physical dart is reduced by Armor, while a poison DoT it leaves is unmitigated." },
                { term: "Frost & Shock",      text: "These schools have few dedicated abilities yet - for now they come mostly from Frostbound / Storm-touched weapons, which apply the matching status. More school content arrives over time." },
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
                { term: "Blind",            text: "Accuracy is greatly reduced - most attacks miss until it wears off." },
                { term: "Mortality",        text: "Reduces the healing the target receives. Useful against enemies that mend themselves." },
                { term: "Stun",             text: "The target skips its entire next turn - blocks every kind of action." },
                { term: "Root",             text: "Blocks MELEE actions (attacks and spells). Ranged actions still work." },
                { term: "Silence",          text: "Blocks SPELLS (melee and ranged). Weapon attacks still work." },
                { term: "Burn",             text: "A small fire damage-over-time. Applied by Flaming weapons; feeds the burn reaction." },
                { term: "Frost",            text: "Chills the target so its attacks hit softer. Applied by Frostbound weapons; feeds the frost shatter." },
                { term: "Shock",            text: "Leaves the target shocked, taking extra damage per hit. Applied by Storm-touched weapons; feeds the shock arc." },
            ],
        },
        {
            title: "Status Reactions",
            entries: [
                { term: "Detonators",   text: "Snipe, Assassinate, Arcane Burst and Soul Nova are DETONATORS - when they hit a target carrying a status, they trigger a reaction based on that status (and usually consume it). Set up the status, then detonate. Elemental weapons (Flaming/Frostbound/Storm-touched) are an easy way to apply burn/frost/shock for these." },
                { term: "Poison",       text: "Detonating poison applies Mortality: the target's healing is cut for 4 turns. Utility, not burst - answers self-healing foes." },
                { term: "Bleed",        text: "Detonating bleed bursts every remaining bleed tick at once for bonus damage." },
                { term: "Burn",         text: "Detonating a burning target strikes with +40% critical chance." },
                { term: "Root / Frost", text: "Detonating a rooted (or frozen) target shatters it for +30% damage." },
                { term: "Shock",        text: "Detonating shock arcs about a third of the hit to every other enemy. Against a lone foe it instead lands a +25% crit empowered strike." },
                { term: "Vulnerable",   text: "Detonating an Exposed (Vulnerable) target adds a flat damage bonus. The mark is NOT consumed - it's a multi-hit window." },
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
            title: "Ability Synergy",
            entries: [
                { term: "Role Categories", text: "Every ability has a role: OFFENSE (deal damage), DEFENSE (protect yourself), SUPPORT (heal / buff / resource) or CONTROL (debuff / crowd-control). Buttons and ability rows are colour-coded - offense red, defense blue, support green, control purple." },
                { term: "Same-Role Discount", text: "After you cast an ability of a role this turn, every LATER ability of the SAME role costs 1 less AP (minimum 1). The first of each role pays full price; the discount resets at the start of your next turn." },
                { term: "Why it matters", text: "Stacking same-role abilities is cheaper, so minor buffs become worth casting together - e.g. Bloodthorn Aura (2 AP) then Iron Skin (2-1 = 1 AP) is 3 AP for both, not 4. On the combat bar a discounted ability shows GREEN AP pips at its reduced cost." },
                { term: "What's discounted", text: "Only AP is reduced - secondary resources (Souls / Blood / Preparation) always cost full. Free (0-AP) abilities stay free. The discount stacks with other AP reductions like Quickcast." },
            ],
        },
        {
            title: "Hit & Crit",
            entries: [
                { term: "Accuracy",        text: "First the attacker rolls to connect (its Accuracy, capped 5-99%). A failure is a MISS. Blind lowers Accuracy sharply." },
                { term: "Dodge",           text: "If an attack connects, the defender rolls their Dodge % to evade it - that's a DODGE (shown separately from a miss). High DEX raises Dodge, with diminishing returns." },
                { term: "Guaranteed Hit",  text: "Some abilities always land - they ignore accuracy, Dodge and Blind entirely." },
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
                { term: "Uncommon",  text: "A small affix or two - a modest step up from Common." },
                { term: "Rare",      text: "Several affixes; a meaningful upgrade worth equipping." },
                { term: "Epic",      text: "Strong, multi-affix gear that can anchor a build." },
                { term: "Legendary", text: "Hand-crafted uniques with build-defining powers. The rarest drops." },
                { term: "Requirements", text: "Rare and better weapons and heavy armor demand a minimum stat (STR/DEX/INT/CON) to wield - a greatsword needs STR, a bow needs DEX, a focus needs INT. If you don't meet it, the item can't be equipped; the requirement shows in red on its tooltip." },
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
    draw_rectangle(0, 0, GUI_W, GUI_H, false);
    draw_set_alpha(1.0);

    // Ornate gothic rim around the whole menu (matches the NPC shop overlays). Drawn
    // before the tab bar so the tabs sit cleanly on top of the top band.
    ui_draw_gothic_frame(30, 30, 1890, 1050, 30);

    // Tab bar at top - 5 tabs, centered (matches click zones in obj_game_controller Step)
    var _tab_w = 252;
    var _tab_h = 66;
    var _tab_y = 30;
    draw_set_font(fnt_ui);
    for (var _t = 0; _t < 5; _t++) {
        var _tx = 306 + _t * (_tab_w + 12);
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
    draw_set_font(-1);

    // Get player reference if in combat
    var _player    = undefined;
    var _in_combat = instance_exists(obj_combat_controller);
    if (_in_combat) {
        var _ctrl = instance_find(obj_combat_controller, 0);
        _player = _ctrl.player;
    }

    // Out-of-combat fallback - build a read-only view from globals so Stats and
    // Abilities tabs are populated when the menu is opened in the hub or floor map.
    // Always copies chosen_stats and applies equipment bonuses - never mutates the global.
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
        // Use the shared out-of-combat max so the Stats tab matches the floor HUD
        // and the in-fight bar (includes Thick Skin's static +10% and boon/curse mults).
        var _sv_max_hp = out_of_combat_max_hp();
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

    var _content_y = 135;
    var _pad       = 60;

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
            // ("of Ruin" affix / Keen runes -> player.stats.crit_bonus) plus the Duelist
            // boon. stats_derive only returns the stat-scaled portion, so the panel used
            // to under-report the real crit rate - fold the flat bonus in here.
            var _crit_flat = 0;
            if (_in_combat && variable_struct_exists(_player.stats, "crit_bonus")) {
                _crit_flat = _player.stats.crit_bonus;
            } else {
                _crit_flat = apply_equipment_stats({}).crit_flat;
            }
            _crit_flat += boon_value("duelist");

            // ---- Header: class + level + HP ----
            draw_set_font(fnt_ui_title);
            draw_set_color(make_color_rgb(80, 160, 220));
            var _class_str = _class_names[_class_id];
            draw_text(_pad, _content_y, _class_str);
            // Measure the class name in its (title) font so the level text can sit just
            // right of it instead of at a fixed x - a long name (Shadowstrider) in the
            // large title font used to run past the fixed offset and overlap "Level X".
            var _class_w = string_width(_class_str);
            // Character level = PERMANENT (meta) level (1 + perm points earned), which
            // persists in the hub - the old display showed run_level, which resets to 1
            // each run so the hub read "Level 1" forever. During an actual fight, also
            // show the per-dive level so in-run progression stays visible.
            draw_set_font(fnt_ui);
            draw_set_color(make_color_rgb(210, 200, 120));
            var _lvl_txt = "Level " + string(player_permanent_level());
            // In a run (on a floor or fighting), append the per-dive level so in-run
            // progression stays visible; the hub has no run, so it shows only the
            // permanent level.
            var _in_run = _in_combat || instance_exists(obj_floor_controller);
            if (_in_run && variable_global_exists("run_level")) {
                _lvl_txt += "   (Dive Lv " + string(global.run_level) + ")";
            }
            // Auto-position: just past the class name (+40 gap), but never left of the
            // original 450 offset so short names keep the familiar layout.
            var _lvl_x = _pad + max(450, _class_w + 40);
            draw_text(_lvl_x, _content_y + 9, _lvl_txt);
            draw_set_color(c_white);
            draw_text(_pad, _content_y + 66, "HP: " + string(_player.HP) + " / " + string(_player.max_HP));

            // ---- Stat grid (two compact columns) ----
            // The shown value is the TOTAL (base + gear). Hovering a stat pops a small
            // box splitting it into Base vs Gear, because equip requirements test BASE
            // only - so a stat reading 17 (12 of it from gear) can still fail a 12 req.
            draw_set_font(fnt_ui_small);
            var _stat_keys = ["STR", "DEX", "CON", "INT", "WIS", "CHA"];
            var _smx = device_mouse_x_to_gui(0);
            var _smy = device_mouse_y_to_gui(0);
            var _hover_stat = -1;
            for (var _s = 0; _s < 6; _s++) {
                var _sx  = _pad + floor(_s / 3) * 285;     // 0=STR/DEX/CON, 1=INT/WIS/CHA
                var _sy  = _content_y + 126 + (_s mod 3) * 48;
                var _is_hov = (_smx >= _sx && _smx <= _sx + 255 && _smy >= _sy && _smy <= _sy + 42);
                if (_is_hov) _hover_stat = _s;
                draw_set_color(_is_hov ? make_color_rgb(200, 215, 245) : make_color_rgb(140, 160, 200));
                draw_text(_sx, _sy, _stat_keys[_s] + ":");
                draw_set_color(c_white);
                draw_text(_sx + 84, _sy, string(variable_struct_get(_stats, _stat_keys[_s])));
            }
            // Base-vs-gear popup for the hovered stat (drawn after the grid so it sits on top).
            if (_hover_stat >= 0) {
                var _hs_key   = _stat_keys[_hover_stat];
                var _hs_total = variable_struct_get(_stats, _hs_key);
                var _hs_base  = player_base_stat(_hs_key);
                var _hs_gear  = _hs_total - _hs_base;
                var _hs_line2 = (_hs_gear != 0)
                              ? ((_hs_gear > 0 ? "Gear: +" : "Gear: ") + string(_hs_gear)) : "";
                var _hs_note  = "Equip requirements use Base.";
                var _hs_w = max(string_width(_hs_note), string_width(_hs_key + ": " + string(_hs_total))) + 36;
                var _hs_h = (_hs_line2 != "") ? 138 : 108;
                var _hs_x = _smx + 24;
                var _hs_y = _smy + 12;
                if (_hs_x + _hs_w > GUI_W) _hs_x = GUI_W - _hs_w - 6;
                draw_set_alpha(0.95);
                draw_set_color(make_color_rgb(18, 20, 32));
                draw_rectangle(_hs_x, _hs_y, _hs_x + _hs_w, _hs_y + _hs_h, false);
                draw_set_alpha(1.0);
                draw_set_color(make_color_rgb(120, 140, 190));
                draw_rectangle(_hs_x, _hs_y, _hs_x + _hs_w, _hs_y + _hs_h, true);
                var _hs_ty = _hs_y + 12;
                draw_set_color(c_white);
                draw_text(_hs_x + 18, _hs_ty, _hs_key + ": " + string(_hs_total));
                _hs_ty += 30;
                draw_set_color(make_color_rgb(180, 200, 235));
                draw_text(_hs_x + 18, _hs_ty, "Base: " + string(_hs_base));
                _hs_ty += 27;
                if (_hs_line2 != "") {
                    draw_set_color(make_color_rgb(150, 210, 160));
                    draw_text(_hs_x + 18, _hs_ty, _hs_line2);
                    _hs_ty += 27;
                }
                draw_set_color(make_color_rgb(140, 145, 165));
                draw_text(_hs_x + 18, _hs_ty, _hs_note);
                draw_set_font(fnt_ui_small);
            }

            // ---- Offense ----
            draw_set_font(fnt_ui);
            draw_set_color(_hc);
            draw_text(_pad, _content_y + 294, "-- Offense --------------");
            // Damage bonuses (left sub-column)
            draw_set_font(fnt_ui_small);
            draw_set_color(_dc);
            draw_text(_pad, _content_y + 333, "Phys abilities (STR):  +" + string(_derived.phys_dmg_bonus));
            draw_text(_pad, _content_y + 369, "Elem abilities (INT):  +" + string(_derived.elem_dmg_bonus));
            draw_text(_pad, _content_y + 405, "DoT / effects  (WIS):  +" + string(_derived.dot_dmg_bonus));
            draw_text(_pad, _content_y + 441, "All abilities  (CHA):  +" + string(_derived.cha_dmg_bonus));
            // Reach-gated weapon damage totals - flat dmg added to melee vs ranged abilities
            // only (SYSTEMS_WEAPON_ROLES.md §B). Read from apply_equipment_stats's per-reach
            // accumulators so this matches the cast resolver and the equip tab's per-weapon "+N dmg".
            var _wpn_bonus = apply_equipment_stats({});
            draw_text(_pad, _content_y + 477, "Melee Weapon dmg:   +" + string(_wpn_bonus.melee_dmg_bonus));
            draw_text(_pad, _content_y + 513, "Ranged Weapon dmg:  +" + string(_wpn_bonus.ranged_dmg_bonus));
            // Crit chances (right sub-column) - now include the flat gear/Duelist bonus
            var _crit_x = _pad + 480;
            draw_set_color(_dc);
            draw_text(_crit_x, _content_y + 333, "Crit - Power  (STR):  " + string(round(_derived.STR_crit_chance + _crit_flat)) + "%");
            draw_text(_crit_x, _content_y + 369, "Crit - Precis (DEX):  " + string(round(_derived.DEX_crit_chance + _crit_flat)) + "%");
            draw_text(_crit_x, _content_y + 405, "Crit - Arcane (INT):  " + string(round(_derived.INT_crit_chance + _crit_flat)) + "%");
            draw_text(_crit_x, _content_y + 441, "Crit - Effect (WIS):  " + string(round(_derived.WIS_crit_chance + _crit_flat)) + "%");
            draw_set_color(make_color_rgb(95, 105, 125));
            draw_text(_crit_x, _content_y + 480, "+ each ability's own base crit");
            draw_text(_crit_x, _content_y + 507, "(includes gear & Duelist bonuses)");

            // ---- Defense ----
            draw_set_font(fnt_ui);
            draw_set_color(_hc);
            draw_text(_pad, _content_y + 576, "-- Defense --------------");
            draw_set_font(fnt_ui_small);
            draw_set_color(_dc);
            draw_text(_pad, _content_y + 615, "Dodge:           " + string(_derived.DODGE) + "%");
            draw_text(_pad, _content_y + 651, "Phys reduction:  " + string(_derived.phys_dmg_reduction) + "%");
            draw_text(_pad, _content_y + 687, "Base HP:         " + string(_derived.HP) + "  (+" + string(apply_equipment_stats({}).bonus_max_hp) + " gear)");
            // Accuracy - a flat bonus to each ability's to-hit, before the foe's dodge.
            draw_set_color(make_color_rgb(150, 180, 210));
            draw_text(_crit_x, _content_y + 615, "Accuracy:  +" + string(_derived.ACC_modifier) + "% to hit");
            draw_set_color(make_color_rgb(95, 105, 125));
            draw_text(_crit_x, _content_y + 648, "Flat % added on top of each ability's");
            draw_text(_crit_x, _content_y + 675, "own hit chance (e.g. 85% + this, cap 99%).");
            draw_text(_crit_x, _content_y + 702, "Then the foe's Dodge rolls. Blind lowers it.");

            // ---- Footer ----
            draw_set_font(fnt_ui);
            draw_set_color(c_yellow);
            draw_text(_pad, _content_y + 810, "Gold: " + string(global.gold) + "g");
            draw_set_font(fnt_ui_small);
            draw_set_color(make_color_rgb(140, 160, 200));
            draw_text(_pad, _content_y + 846, "Run " + string(global.run_count + 1) + "  -  Floor " + string(global.current_floor));

            // =====================================================================
            // RIGHT COLUMN - portrait card + combat readiness + boons / effects
            // =====================================================================
            var _cardx1 = 1230, _cardx2 = 1800;
            var _cardy1 = _content_y, _cardy2 = _content_y + 360;

            // Card frame
            draw_set_color(make_color_rgb(18, 24, 38));
            draw_rectangle(_cardx1, _cardy1, _cardx2, _cardy2, false);
            draw_set_color(make_color_rgb(70, 90, 130));
            draw_rectangle(_cardx1, _cardy1, _cardx2, _cardy2, true);
            ui_draw_gothic_frame(_cardx1, _cardy1, _cardx2, _cardy2, 30);   // ornate portrait frame

            // South-facing player sprite (frame 0 = south in the 8-dir layout). Sprites
            // are top-left origin and vary in canvas size, so normalise to a target
            // height and centre inside the card.
            var _pspr = player_combat_sprite(_class_id);
            if (_pspr != -1 && sprite_exists(_pspr)) {
                var _psh = max(1, sprite_get_height(_pspr));
                var _psw = max(1, sprite_get_width(_pspr));
                var _pscale = 285 / _psh;
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
            draw_set_font(fnt_ui_small);
            draw_set_color(make_color_rgb(190, 200, 220));
            draw_text((_cardx1 + _cardx2) / 2, _cardy2 + 36, _skin_name + "  -  " + _gender_txt);
            draw_set_halign(fa_left);

            // ---- Combat readiness summary ----
            var _rx = _cardx1;
            draw_set_font(fnt_ui);
            draw_set_color(_hc);
            draw_text(_rx, _content_y + 423, "-- Combat Readiness -----");
            // Primary crit school by class: Arcanist=Arcane, Bloodwarden=Power, Strider=Precision
            var _prim_lbls = ["Arcane (INT)", "Power (STR)", "Precision (DEX)"];
            var _prim_vals = [_derived.INT_crit_chance, _derived.STR_crit_chance, _derived.DEX_crit_chance];
            draw_set_font(fnt_ui_small);
            draw_set_color(c_white);
            draw_text(_rx, _content_y + 462, "HP:        " + string(_player.HP) + " / " + string(_player.max_HP));
            draw_text(_rx, _content_y + 495, "Dodge:     " + string(_derived.DODGE) + "%");
            draw_text(_rx, _content_y + 528, "Accuracy:  +" + string(_derived.ACC_modifier) + "% to hit");
            draw_text(_rx, _content_y + 561, "Main crit: " + string(round(_prim_vals[_class_id] + _crit_flat)) + "%  (" + _prim_lbls[_class_id] + ")");

            // ---- Boons & Effects (right column, below readiness) ----
            draw_set_font(fnt_ui);
            draw_set_color(_hc);
            draw_text(_rx, _content_y + 621, "-- Boons & Effects ------");
            draw_set_font(fnt_ui_small);
            var _by    = _content_y + 660;
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
                    draw_text(_rx + 24, _by + 24, ui_truncate(_bb.desc, 540));
                    _by += 57; _rows++; _any = true;
                }
            }
            // Active run curses (devil's bargain) - red, with penalty text.
            if (variable_global_exists("run_curses") && array_length(global.run_curses) > 0) {
                var _cn = array_length(global.run_curses);
                for (var _ci = 0; _ci < _cn && _rows < _rowmx; _ci++) {
                    var _cc = curse_get(global.run_curses[_ci]);
                    if (_cc == undefined) continue;
                    draw_set_color(make_color_rgb(210, 120, 120));
                    draw_text(_rx, _by, "! " + _cc.name);
                    draw_set_color(make_color_rgb(150, 110, 110));
                    draw_text(_rx + 24, _by + 24, ui_truncate(_cc.desc, 540));
                    _by += 57; _rows++; _any = true;
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
                    draw_text(_rx + 24, _by + 24, ui_truncate(status_effect_plain_text(_ss) + "  -  " + string(_sdur) + " turn" + (_sdur == 1 ? "" : "s") + " left", 540));
                    _by += 57; _rows++; _any = true;
                }
            }
            if (!_any) {
                draw_set_color(_dc);
                draw_text(_rx, _by, "None active.");
                draw_set_color(make_color_rgb(95, 105, 125));
                draw_text(_rx + 24, _by + 24, "Boons last all run; statuses a few turns.");
            }
        } else {
            draw_set_font(fnt_ui);
            draw_set_color(make_color_rgb(120, 130, 150));
            draw_text(_pad, _content_y + 30, "No active character - start a run to view stats.");
        }
    }

    // ---- EQUIPMENT TAB ----
    // Restructured: a large detail/preview panel on the LEFT (big icon + full stats
    // of the selected slot) and a single-column slot LIST on the right. Ring 2 sits
    // directly under Ring 1 (equip_display_order). Both panels wear a gothic frame.
    if (menu_tab == 1) {
        var _slot_names = ["Melee Weapon", "Offhand", "Helm", "Chest", "Gloves", "Boots", "Amulet", "Ring 1", "Ranged Weapon", "Ring 2"];
        var _sel_pos    = clamp(_gc.equip_slot_selected, 0, EQUIP_SLOT_COUNT - 1);
        var _sel_inv    = equip_display_to_inv(_sel_pos);

        // Equip confirmation notification (fades over 150 frames, fully opaque first 120)
        if (variable_instance_exists(_gc, "equip_notif_timer") && _gc.equip_notif_timer > 0) {
            var _nf = clamp(_gc.equip_notif_timer / 30.0, 0, 1.0);
            draw_set_alpha(_nf);
            draw_set_halign(fa_center);
            draw_set_font(fnt_ui);
            draw_set_color(make_color_rgb(100, 220, 130));
            draw_text(960, 110, _gc.equip_notif_msg);
            draw_set_halign(fa_left);
            draw_set_alpha(1.0);
        }

        // Stash / Pack counts in top-right
        var _stash_count = variable_global_exists("equipment_stash") ? array_length(global.equipment_stash) : 0;
        var _pack_count  = variable_global_exists("carried_items")   ? array_length(global.carried_items)   : 0;
        var _equip_in_hub = (room == rm_hub || room == rm_character_select);
        draw_set_halign(fa_right);
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(120, 130, 150));
        if (_equip_in_hub) {
            draw_text(1850, 120, "Stash: " + string(_stash_count) + "   Pack: " + string(_pack_count));
        } else {
            draw_text(1850, 120, "Pack: " + string(_pack_count) + "  (stash left in town)");
        }
        draw_set_halign(fa_left);

        var _offhand_locked = two_handed_equipped();   // 2H weapon locks the offhand slot

        // ===== LEFT DETAIL / PREVIEW PANEL =====
        var _dp_x1 = 70, _dp_y1 = 150, _dp_x2 = 700, _dp_y2 = 1012;
        draw_set_color(make_color_rgb(14, 17, 28));
        draw_rectangle(_dp_x1, _dp_y1, _dp_x2, _dp_y2, false);
        ui_draw_gothic_frame(_dp_x1, _dp_y1, _dp_x2, _dp_y2, 26);

        var _dp_cx   = (_dp_x1 + _dp_x2) / 2;
        var _sel_item = (variable_global_exists("inventory") && array_length(global.inventory) > _sel_inv)
                        ? global.inventory[_sel_inv] : undefined;

        // Slot title
        draw_set_halign(fa_center);
        draw_set_font(fnt_ui);
        draw_set_color(make_color_rgb(200, 180, 120));
        draw_text(_dp_cx, _dp_y1 + 26, _slot_names[_sel_inv]);

        // Large icon (or empty plate)
        var _big = 300;
        var _big_x = _dp_cx - _big / 2;
        var _big_y = _dp_y1 + 80;
        if (_sel_item != undefined) {
            ui_draw_item_icon(_big_x, _big_y, _big, _sel_item);
        } else {
            draw_set_color(make_color_rgb(12, 14, 22));
            draw_rectangle(_big_x, _big_y, _big_x + _big, _big_y + _big, false);
            draw_set_color(make_color_rgb(50, 56, 74));
            draw_rectangle(_big_x, _big_y, _big_x + _big, _big_y + _big, true);
            draw_set_valign(fa_middle);
            draw_set_color(make_color_rgb(70, 76, 96));
            draw_text(_dp_cx, _big_y + _big / 2, (_sel_inv == 1 && _offhand_locked) ? "LOCKED" : "EMPTY");
            draw_set_valign(fa_top);
        }

        // Detail text under the icon
        var _info_y = _big_y + _big + 28;
        var _info_w = (_dp_x2 - _dp_x1) - 56;
        if (_sel_item != undefined) {
            var _rcol = item_rarity_color(_sel_item.rarity);
            draw_set_halign(fa_center);
            draw_set_font(fnt_ui);
            draw_set_color(_rcol);
            draw_text_ext(_dp_cx, _info_y, _sel_item.name, 34, _info_w);
            _info_y += max(40, string_height_ext(_sel_item.name, 34, _info_w)) + 8;

            draw_set_font(fnt_ui_small);
            draw_set_color(make_color_rgb(170, 150, 90));
            draw_text(_dp_cx, _info_y, item_rarity_name(_sel_item.rarity) + "  |  " + item_slot_label(_sel_item.slot));
            _info_y += 40;

            // Full stat string (wrapped, left-aligned within the panel)
            draw_set_halign(fa_left);
            draw_set_color(c_white);
            var _stat_str = ui_item_stat_str(_sel_item);
            draw_text_ext(_dp_x1 + 28, _info_y, _stat_str, 32, _info_w);
            _info_y += string_height_ext(_stat_str, 32, _info_w) + 10;

            // Requirement (green if met, red if not)
            var _req = item_stat_requirement(_sel_item);
            if (_req.value > 0 && _req.stat != "") {
                draw_set_color((player_base_stat(_req.stat) >= _req.value)
                    ? make_color_rgb(110, 190, 110) : make_color_rgb(230, 90, 90));
                draw_text(_dp_x1 + 28, _info_y, "Requires " + _req.stat + " " + string(_req.value));
                _info_y += 34;
            }

            // Unique effect or flavor
            if (variable_struct_exists(_sel_item, "unique_desc") && _sel_item.unique_desc != "") {
                draw_set_color(make_color_rgb(255, 200, 50));
                draw_text_ext(_dp_x1 + 28, _info_y + 4, _sel_item.unique_desc, 30, _info_w);
            } else if (variable_struct_exists(_sel_item, "effect_desc") && _sel_item.effect_desc != "") {
                draw_set_color(make_color_rgb(140, 150, 175));
                draw_text_ext(_dp_x1 + 28, _info_y + 4, _sel_item.effect_desc, 30, _info_w);
            }
        }
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);

        // ===== RIGHT SLOT LIST (single column) =====
        var _ls_x1 = 740, _ls_x2 = 1850, _ls_y1 = 150, _ls_y2 = 1012;
        draw_set_color(make_color_rgb(14, 17, 28));
        draw_rectangle(_ls_x1, _ls_y1, _ls_x2, _ls_y2, false);
        ui_draw_gothic_frame(_ls_x1, _ls_y1, _ls_x2, _ls_y2, 26);

        var _row_pad = 16;
        var _row_h   = (( _ls_y2 - _ls_y1) - _row_pad * 2) / EQUIP_SLOT_COUNT;
        for (var _r = 0; _r < EQUIP_SLOT_COUNT; _r++) {
            var _inv = equip_display_to_inv(_r);
            var _ry  = _ls_y1 + _row_pad + _r * _row_h;
            var _is_sel = (_r == _sel_pos);
            var _slot_locked = (_inv == 1 && _offhand_locked);
            if (_slot_locked) draw_set_alpha(0.4);

            // Row background + selection accent
            draw_set_color(_is_sel ? make_color_rgb(34, 54, 86) : make_color_rgb(18, 22, 36));
            draw_rectangle(_ls_x1 + 18, _ry + 3, _ls_x2 - 18, _ry + _row_h - 5, false);
            if (_is_sel) {
                draw_set_color(make_color_rgb(150, 120, 60));
                draw_rectangle(_ls_x1 + 18, _ry + 3, _ls_x2 - 18, _ry + _row_h - 5, true);
                // gold accent bar on the left edge
                draw_set_color(make_color_rgb(210, 175, 90));
                draw_rectangle(_ls_x1 + 18, _ry + 3, _ls_x1 + 24, _ry + _row_h - 5, false);
            }

            var _equipped = (variable_global_exists("inventory") && array_length(global.inventory) > _inv)
                            ? global.inventory[_inv] : undefined;

            // Icon badge
            var _icon_sz = _row_h - 22;
            if (_equipped != undefined) ui_draw_item_icon(_ls_x1 + 34, _ry + 8, _icon_sz, _equipped);

            // Slot name (small, top) + item name (rarity color, below)
            var _tx = _ls_x1 + 34 + _icon_sz + 22;
            draw_set_font(fnt_ui_small);
            draw_set_color(_is_sel ? make_color_rgb(210, 190, 130) : make_color_rgb(120, 130, 150));
            draw_text(_tx, _ry + 10, _slot_names[_inv]);

            draw_set_font(fnt_ui);
            if (_equipped != undefined) {
                draw_set_color(item_rarity_color(_equipped.rarity));
                draw_text(_tx, _ry + 38, ui_truncate(_equipped.name, _ls_x2 - _tx - 230));
                draw_set_halign(fa_right);
                draw_set_font(fnt_ui_small);
                draw_set_color(item_rarity_color(_equipped.rarity));
                draw_text(_ls_x2 - 34, _ry + 14, item_rarity_name(_equipped.rarity));
                draw_set_color(make_color_rgb(150, 160, 180));
                draw_text(_ls_x2 - 34, _ry + 44, ui_truncate(ui_item_stat_str(_equipped), 360));
                draw_set_halign(fa_left);
            } else {
                draw_set_color(_slot_locked ? make_color_rgb(150, 130, 90) : make_color_rgb(70, 76, 96));
                draw_text(_tx, _ry + 38, _slot_locked ? "Two-handed: offhand locked" : "- Empty -");
            }

            if (_slot_locked) draw_set_alpha(1.0);
        }

        // Bottom instruction line
        draw_set_halign(fa_center);
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(80, 90, 110));
        if (_gc.equip_picker_open) {
            draw_text_outline(960, 1035, "W/S: Navigate   Enter: Equip   Esc: Cancel");
        } else {
            draw_text_outline(960, 1035, "W/S: Navigate   Enter: Equip   U: Unequip");
        }
        draw_set_halign(fa_left);

        // --- EQUIP PICKER OVERLAY ---
        if (_gc.equip_picker_open) {
            // Filter by the item-TYPE the position accepts (Ring 2 -> "ring"), so rings
            // list for either ring position. Must match the Step picker.
            var _slot_name = equip_position_item_slot(_sel_inv);

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
            var _px      = 360;
            var _py      = 180;
            var _pw      = 1200;
            var _row_h   = 108;
            var _visible = array_length(_picker_items);

            // The currently-equipped item lives in global.inventory (not in the
            // pack/stash lists above), so it never appears as a selectable row. Show
            // it as a dimmed, non-selectable "[Equipped]" row at the TOP so the player
            // always sees the FULL count for the slot - otherwise a duplicate of the
            // worn item (same name/stats sitting in the pack) reads as if the item
            // vanished. Selectable rows shift down one row while this is present.
            var _equipped_here = (variable_global_exists("inventory")
                && array_length(global.inventory) > _sel_inv)
                ? global.inventory[_sel_inv] : undefined;
            var _eq_extra = (_equipped_here != undefined) ? 1 : 0;
            var _list_y0  = _py + 48 + _eq_extra * _row_h;   // top of the selectable list
            var _ph       = max(150, (_visible + _eq_extra) * _row_h + 48);

            draw_set_alpha(0.97);
            draw_set_color(make_color_rgb(12, 15, 28));
            draw_rectangle(_px, _py, _px + _pw, _py + _ph, false);
            draw_set_alpha(1.0);
            draw_set_color(make_color_rgb(80, 140, 220));
            draw_rectangle(_px, _py, _px + _pw, _py + _ph, true);

            draw_set_halign(fa_center);
            draw_set_font(fnt_ui);
            draw_set_color(c_white);
            draw_text(_px + _pw / 2, _py + 12, "Choose " + _slot_names[_sel_inv]);
            draw_set_halign(fa_left);

            // Class restriction warning / equip_msg
            if (variable_instance_exists(_gc, "equip_msg") && _gc.equip_msg != "") {
                draw_set_halign(fa_center);
                draw_set_font(fnt_ui_small);
                draw_set_color(make_color_rgb(255, 120, 60));
                draw_text(_px + _pw / 2, _py + _ph + 9, _gc.equip_msg);
                draw_set_halign(fa_left);
            }

            // Dimmed, non-selectable row for the item currently worn in this slot.
            if (_eq_extra) {
                var _eq_ry = _py + 48;
                draw_set_alpha(0.4);
                draw_set_color(make_color_rgb(16, 20, 34));
                draw_rectangle(_px + 6, _eq_ry, _px + _pw - 6, _eq_ry + _row_h - 6, false);
                draw_set_alpha(1.0);
                var _eqcol = item_rarity_color(_equipped_here.rarity);
                ui_draw_item_icon(_px + 21, _eq_ry + 9, 48, _equipped_here);
                var _eqx = _px + 78;
                draw_set_font(fnt_ui);
                draw_set_color(merge_color(_eqcol, make_color_rgb(40, 44, 54), 0.45));
                draw_text(_eqx, _eq_ry + 12, _equipped_here.name);
                draw_set_font(fnt_ui_small);
                draw_set_color(make_color_rgb(120, 128, 145));
                ui_draw_stat_line_fit(_eqx, _eq_ry + 45, ui_item_stat_str(_equipped_here), (_px + _pw - 200) - _eqx);
                draw_set_halign(fa_right);
                draw_set_color(make_color_rgb(120, 160, 210));
                draw_text(_px + _pw - 21, _eq_ry + 12, "[Equipped]");
                draw_set_halign(fa_left);
                // Thin divider between the worn item and the swap choices below.
                draw_set_color(make_color_rgb(50, 60, 84));
                draw_line(_px + 18, _eq_ry + _row_h - 3, _px + _pw - 18, _eq_ry + _row_h - 3);
            }

            if (_visible == 0) {
                draw_set_font(fnt_ui);
                draw_set_color(make_color_rgb(100, 110, 130));
                draw_text(_px + 30, _list_y0 + 12, _picker_in_hub
                    ? "No matching items in stash or pack."
                    : "No matching items in your pack.");
            } else {
                var _pc = variable_global_exists("chosen_class") ? global.chosen_class : -1;
                for (var _ri = 0; _ri < _visible; _ri++) {
                    var _it     = _picker_items[_ri];
                    var _ry     = _list_y0 + _ri * _row_h;
                    var _is_sel = (_ri == _gc.equip_picker_index);
                    var _src    = _picker_src[_ri];
                    var _it_cr  = variable_struct_exists(_it, "class_req") ? _it.class_req : -1;
                    var _locked = (_it_cr != -1 && _it_cr != _pc);

                    draw_set_alpha((_is_sel && !_locked) ? 0.9 : (_locked ? 0.28 : 0.45));
                    draw_set_color(_is_sel ? make_color_rgb(30, 50, 90) : make_color_rgb(18, 22, 38));
                    draw_rectangle(_px + 6, _ry, _px + _pw - 6, _ry + _row_h - 6, false);
                    draw_set_alpha(1.0);

                    var _rcol = _locked ? make_color_rgb(80, 80, 90) : item_rarity_color(_it.rarity);
                    // Icon badge - drawn for locked items too so class-only gear still shows its art
                    ui_draw_item_icon(_px + 21, _ry + 9, 48, _it);
                    var _itx = _px + 78;
                    // Name
                    draw_set_font(fnt_ui);
                    draw_set_color(_rcol);
                    draw_text(_itx, _ry + 12, _it.name);
                    // Stat string
                    draw_set_font(fnt_ui_small);
                    draw_set_color(_locked ? make_color_rgb(70, 70, 80) : c_white);
                    ui_draw_stat_line_fit(_itx, _ry + 45, ui_item_stat_str(_it), (_px + _pw - 200) - _itx);
                    // Unique or flavor
                    if (!_locked && variable_struct_exists(_it, "unique_desc") && _it.unique_desc != "") {
                        draw_set_color(make_color_rgb(255, 200, 50));
                        draw_text(_itx, _ry + 75, _it.unique_desc);
                    } else if (!_locked && _it.effect_desc != "") {
                        draw_set_color(make_color_rgb(95, 105, 130));
                        draw_text(_itx, _ry + 75, _it.effect_desc);
                    }

                    // Source tag, rarity, class restriction
                    draw_set_halign(fa_right);
                    if (_locked) {
                        var _cr_names = ["Arcanist", "Bloodwarden", "Shadowstrider"];
                        draw_set_color(make_color_rgb(180, 80, 80));
                        draw_text(_px + _pw - 21, _ry + 12, "[" + _cr_names[_it_cr] + " only]");
                    } else {
                        draw_set_color((_src == 0) ? make_color_rgb(120, 200, 120) : make_color_rgb(200, 180, 100));
                        draw_text(_px + _pw - 21, _ry + 12, (_src == 0) ? "[Stash]" : "[Pack]");
                        draw_set_color(_rcol);
                        draw_text(_px + _pw - 21, _ry + 51, item_rarity_name(_it.rarity));
                        // Stat requirement - red when the current class can't meet it (equipping
                        // is hard-blocked). Visible in the list, not just the hover tooltip.
                        var _ereq = item_stat_requirement(_it);
                        if (_ereq.value > 0 && _ereq.stat != "") {
                            draw_set_color((player_base_stat(_ereq.stat) >= _ereq.value)
                                ? make_color_rgb(110, 170, 110) : make_color_rgb(225, 80, 80));
                            draw_text(_px + _pw - 21, _ry + 78, "Req " + string(_ereq.value) + " " + _ereq.stat);
                        }
                    }
                    draw_set_halign(fa_left);
                }

                // Hover tooltip for item in picker
                var _hmx = device_mouse_x_to_gui(0);
                var _hmy = device_mouse_y_to_gui(0);
                if (_hmx >= _px + 6 && _hmx < _px + _pw - 6) {
                    for (var _tt_ri = 0; _tt_ri < _visible; _tt_ri++) {
                        var _tt_ry = _list_y0 + _tt_ri * _row_h;
                        if (_hmy >= _tt_ry && _hmy < _tt_ry + _row_h - 6) {
                            var _cur_eq = (variable_global_exists("inventory")
                                && array_length(global.inventory) > _sel_inv)
                                ? global.inventory[_sel_inv] : undefined;
                            ui_draw_item_tooltip(_hmx + 18, _hmy - 45, _picker_items[_tt_ri], _cur_eq);
                            break;
                        }
                    }
                }
            }
        }
    }

    // ---- ABILITIES TAB ----
    // Two-pane: a selectable list of the loadout on the LEFT, a full breakdown of
    // the highlighted ability on the RIGHT (mechanics, cost, school, and the CURRENT
    // damage it lands for with your equipped gear). Both panels gothic-framed.
    if (menu_tab == 2 && _player != undefined && array_length(_player.abilities) > 0) {
        var _abs  = _player.abilities;
        var _acnt = array_length(_abs);
        var _acur = clamp(_gc.ability_view_cursor, 0, _acnt - 1);

        // ===== LEFT: ability list =====
        var _al_x1 = 70, _al_x2 = 700, _al_y1 = 150, _al_y2 = 1012;
        draw_set_color(make_color_rgb(14, 17, 28));
        draw_rectangle(_al_x1, _al_y1, _al_x2, _al_y2, false);
        ui_draw_gothic_frame(_al_x1, _al_y1, _al_x2, _al_y2, 26);

        var _alr_pad = 16;
        var _alr_h   = min(108, ((_al_y2 - _al_y1) - _alr_pad * 2) / _acnt);
        for (var _ab = 0; _ab < _acnt; _ab++) {
            var _a  = _abs[_ab];
            var _ay = _al_y1 + _alr_pad + _ab * _alr_h;
            var _asel = (_ab == _acur);

            draw_set_color(_asel ? make_color_rgb(34, 54, 86) : make_color_rgb(18, 22, 36));
            draw_rectangle(_al_x1 + 16, _ay + 3, _al_x2 - 16, _ay + _alr_h - 5, false);
            if (_asel) {
                draw_set_color(make_color_rgb(210, 175, 90));
                draw_rectangle(_al_x1 + 16, _ay + 3, _al_x1 + 22, _ay + _alr_h - 5, false);
            }

            var _aic = _alr_h - 24;
            ui_draw_ability_icon(_al_x1 + 30, _ay + 10, _aic, _a);

            draw_set_font(fnt_ui);
            draw_set_color(_asel ? c_white : make_color_rgb(170, 180, 200));
            draw_text(_al_x1 + 30 + _aic + 16, _ay + 12, ui_truncate(_a.name, _al_x2 - (_al_x1 + 30 + _aic + 16) - 16));
            draw_set_font(fnt_ui_small);
            draw_set_color(make_color_rgb(228, 190, 90));
            draw_text(_al_x1 + 30 + _aic + 16, _ay + 48, string(_a.energy_cost) + " AP");
        }

        // ===== RIGHT: breakdown of the selected ability =====
        var _ad = _abs[_acur];
        var _bd_x1 = 740, _bd_x2 = 1850, _bd_y1 = 150, _bd_y2 = 1012;
        draw_set_color(make_color_rgb(16, 18, 28));
        draw_rectangle(_bd_x1, _bd_y1, _bd_x2, _bd_y2, false);
        ui_draw_gothic_frame(_bd_x1, _bd_y1, _bd_x2, _bd_y2, 26);

        var _bpad = 40;
        var _blx  = _bd_x1 + _bpad;
        var _brx  = _bd_x2 - _bpad;
        var _by   = _bd_y1 + _bpad;

        // Header: icon + name + role chip
        ui_draw_ability_icon(_blx, _by, 96, _ad);
        var _btx = _blx + 96 + 24;
        draw_set_halign(fa_left); draw_set_valign(fa_top);
        draw_set_font(fnt_ui_title);
        draw_set_color(c_white);
        draw_text(_btx, _by + 3, _ad.name);
        var _cat = ability_category(_ad);
        draw_set_font(fnt_ui);
        draw_set_color(ability_category_color(_cat));
        draw_text(_btx, _by + 60, ability_category_label(_cat));

        // Cost / cooldown line
        var _ap2  = variable_struct_exists(_ad, "energy_cost") ? _ad.energy_cost : 0;
        var _sec2 = variable_struct_exists(_ad, "secondary_cost") ? _ad.secondary_cost : 0;
        var _cls2 = variable_global_exists("chosen_class") ? global.chosen_class : 0;
        var _resn = (_cls2 == 0) ? "Souls" : ((_cls2 == 1) ? "Blood" : "Preparation");
        var _cl2  = string(_ap2) + " AP";
        if (_sec2 > 0) _cl2 += "   +" + string(_sec2) + " " + _resn;
        var _cd2 = ability_cooldown(_ad);
        if (_cd2 > 0) _cl2 += "   *   " + string(_cd2) + "-turn cooldown";
        draw_set_halign(fa_right);
        draw_set_font(fnt_ui);
        draw_set_color(make_color_rgb(228, 190, 90));
        draw_text(_brx, _by + 6, _cl2);
        draw_set_halign(fa_left);

        _by += 120;
        // School / attack-class line
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(150, 160, 190));
        var _sch = school_label(ability_school(_ad));
        var _acl = ability_attack_class_tag(_ad);
        if (_sch != "") {
            draw_set_color(school_color(ability_school(_ad)));
            _acl = _sch + " school  -  " + _acl;
        }
        draw_text(_blx, _by, _acl);
        _by += 38;

        // CURRENT DAMAGE WITH EQUIPMENT (estimate against an unmitigated target)
        var _dmg_derived = _in_combat ? _player.derived : out_of_combat_dmg_derived();
        var _est = combat_estimate_hit(_ad, { derived: _dmg_derived }, {});
        if (_est >= 0) {
            draw_set_font(fnt_ui);
            draw_set_color(make_color_rgb(235, 120, 90));
            draw_text(_blx, _by, "Current hit (with gear):  ~" + string(_est)
                + "    [base " + string(_ad.base_damage) + "]");
            _by += 44;
        } else if (variable_struct_exists(_ad, "effect_value") && _ad.effect_value != 0) {
            draw_set_font(fnt_ui);
            draw_set_color(make_color_rgb(120, 200, 160));
            draw_text(_blx, _by, _ad.effect_type + ":  " + string(_ad.effect_value));
            _by += 44;
        }

        draw_set_color(make_color_rgb(60, 64, 90));
        draw_line(_blx, _by, _brx, _by);
        _by += 22;

        // Mechanics
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(120, 200, 140));
        draw_text(_blx, _by, "MECHANICS");
        _by += 34;
        draw_set_font(fnt_ui);
        draw_set_color(make_color_rgb(210, 214, 230));
        var _mech2 = ability_describe(_ad);
        draw_text_ext(_blx, _by, _mech2, -1, _brx - _blx);
        _by += string_height_ext(_mech2, -1, _brx - _blx) + 28;

        // Flavor / full description
        if (variable_struct_exists(_ad, "desc_full") && _ad.desc_full != "") {
            draw_set_font(fnt_ui);
            draw_set_color(make_color_rgb(140, 146, 170));
            draw_text_ext(_blx, _by, _ad.desc_full, -1, _brx - _blx);
        }

        draw_set_halign(fa_left);
        draw_set_valign(fa_top);

        // Hint
        draw_set_halign(fa_center);
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(80, 90, 110));
        draw_text_outline(960, 1035, "W/S: Browse abilities");
        draw_set_halign(fa_left);
    } else if (menu_tab == 2) {
        draw_set_font(fnt_ui);
        draw_set_color(make_color_rgb(120, 130, 150));
        draw_text(_pad, _content_y + 30, "No abilities to show - start a run to view your loadout.");
    }

    // ---- CONSUMABLES TAB ----
    if (menu_tab == 3) {
        // Grouped view: identical consumables collapse to one "Name xN" row (the real
        // array still holds every entry). Step's nav/use map back through it.
        var _cgroups        = consumables_grouped();
        var _cons_count     = array_length(_cgroups);
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

        // Pack carry-cap readout (top-right of the tab) so the 10-slot limit and
        // any Pack Rat bonus are always visible.
        var _pack_n   = variable_global_exists("consumable_inventory") ? array_length(global.consumable_inventory) : 0;
        var _pack_cap = consumable_carry_cap();
        draw_set_font(fnt_ui_small);
        draw_set_halign(fa_right);
        draw_set_color((_pack_n >= _pack_cap) ? make_color_rgb(225, 120, 90) : make_color_rgb(150, 200, 200));
        draw_text(1335, _content_y, "Pack  " + string(_pack_n) + " / " + string(_pack_cap));
        draw_set_halign(fa_left);

        if (_cons_count == 0) {
            draw_set_font(fnt_ui);
            draw_set_color(make_color_rgb(100, 110, 130));
            draw_text(_pad, _content_y + 30, "No consumables in inventory.");
        } else {
            // Status header (combat only)
            if (_in_combat) {
                var _ctrl_hdr = instance_find(obj_combat_controller, 0);
                draw_set_font(fnt_ui);
                if (_no_ap) {
                    draw_set_color(c_red);
                    draw_text(_pad, _content_y, "Not enough AP - items cost 1 AP to use.");
                } else if (!_ctrl_hdr.player_turn) {
                    if (_limit_reached) {
                        draw_set_color(c_red);
                        draw_text(_pad, _content_y, "Item use limit reached for this enemy turn.");
                    } else {
                        draw_set_color(c_yellow);
                        draw_text(_pad, _content_y, "Enemy turn - 1 item use remaining.");
                    }
                }
            }

            // Windowed list - keep the cursor on screen when there are many items.
            // Mouse hit-testing in obj_game_controller Step uses the same window math.
            var _cons_max_vis = 7;
            var _cons_first   = ui_list_window_first(_sub_cur, _cons_count, _cons_max_vis);
            var _cons_last    = min(_cons_count, _cons_first + _cons_max_vis);

            // "more above / below" hints
            draw_set_halign(fa_center);
            draw_set_font(fnt_ui_small);
            if (_cons_first > 0) {
                draw_set_color(make_color_rgb(120, 200, 200));
                draw_text(705, _content_y + 39, "^ " + string(_cons_first) + " more");
            }
            if (_cons_last < _cons_count) {
                draw_set_color(make_color_rgb(120, 200, 200));
                draw_text(705, _content_y + 60 + _cons_max_vis * 120 - 18, "v " + string(_cons_count - _cons_last) + " more");
            }
            draw_set_halign(fa_left);

            for (var _ci = _cons_first; _ci < _cons_last; _ci++) {
                var _c      = _cgroups[_ci].item;
                var _clabel = consumable_group_label(_cgroups[_ci]);
                var _cy2    = _content_y + 60 + (_ci - _cons_first) * 120;
                var _is_cur = (_sub_open && _ci == _sub_cur);

                // Background - highlighted when this row is the cursor
                if (_is_cur) {
                    draw_set_color(make_color_rgb(30, 80, 80));
                } else {
                    draw_set_color(make_color_rgb(20, 30, 48));
                }
                draw_rectangle(_pad, _cy2, 1350, _cy2 + 98, false);

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
                draw_rectangle(_pad, _cy2, 1350, _cy2 + 98, true);

                // Icon (left side) - shifts the text right only when art exists
                var _csp     = ui_consumable_icon_sprite(_c.name);
                var _c_dim   = (_sub_open && !_is_cur);
                var _has_csp = (_csp != -1 && sprite_exists(_csp));
                var _ctext_x = _has_csp ? _pad + 96 : _pad + 18;
                if (_has_csp) {
                    draw_set_alpha(_c_dim ? 0.4 : 1.0);
                    draw_sprite_stretched(_csp, 0, _pad + 12, _cy2 + 12, 72, 72);
                    draw_set_alpha(1.0);
                }

                // Name
                draw_set_font(fnt_ui);
                if (_sub_open && !_is_cur) {
                    draw_set_color(make_color_rgb(50, 130, 130));
                } else if (_is_cur && _limit_reached) {
                    draw_set_color(make_color_rgb(200, 100, 100));
                } else if (_is_cur) {
                    draw_set_color(make_color_rgb(120, 255, 255));
                } else {
                    draw_set_color(make_color_rgb(80, 220, 220));
                }
                draw_text(_ctext_x, _cy2 + 12, _clabel);

                // Description
                draw_set_font(fnt_ui_small);
                if (_sub_open && !_is_cur) {
                    draw_set_color(make_color_rgb(70, 80, 95));
                } else {
                    draw_set_color(c_white);
                }
                draw_text(_ctext_x, _cy2 + 54, _c.description);

                // Gold value
                draw_set_halign(fa_right);
                if (_sub_open && !_is_cur) {
                    draw_set_color(make_color_rgb(80, 90, 60));
                } else {
                    draw_set_color(c_yellow);
                }
                draw_text(1335, _cy2 + 12, string(_c.gold_value) + "g value");
                draw_set_halign(fa_left);
            }
        }
    }

    // ---- COMPENDIUM (HELP) TAB ----
    if (menu_tab == 4) {
        var _comp_secs = ui_compendium_sections();
        var _comp_sel  = clamp(_gc.compendium_section, 0, array_length(_comp_secs) - 1);

        // Left list - section titles
        draw_set_font(fnt_ui);
        for (var _cs = 0; _cs < array_length(_comp_secs); _cs++) {
            var _csy    = _content_y + _cs * 69;
            var _cs_on  = (_cs == _comp_sel);
            draw_set_color(_cs_on ? make_color_rgb(30, 50, 90) : make_color_rgb(18, 24, 40));
            draw_rectangle(60, _csy, 450, _csy + 60, false);
            draw_set_color(_cs_on ? make_color_rgb(80, 140, 220) : make_color_rgb(45, 55, 75));
            draw_rectangle(60, _csy, 450, _csy + 60, true);
            draw_set_color(_cs_on ? c_white : make_color_rgb(150, 160, 180));
            draw_set_valign(fa_middle);
            draw_text(81, _csy + 30, _comp_secs[_cs].title);
            draw_set_valign(fa_top);
        }

        // Right detail pane - entries of the selected section
        var _det_x  = 495;
        var _det_w  = 1860 - _det_x;   // wrap width for entry text
        draw_set_font(fnt_ui_title);
        draw_set_color(make_color_rgb(80, 160, 220));
        draw_text(_det_x, _content_y - 6, _comp_secs[_comp_sel].title);

        var _ey      = _content_y + 66;
        var _entries = _comp_secs[_comp_sel].entries;
        for (var _ce = 0; _ce < array_length(_entries); _ce++) {
            var _ent = _entries[_ce];
            // Term (bold-ish accent line)
            draw_set_font(fnt_ui);
            draw_set_color(make_color_rgb(220, 200, 120));
            draw_text(_det_x, _ey, _ent.term);
            _ey += 36;
            // Wrapped description
            draw_set_font(fnt_ui_small);
            draw_set_color(make_color_rgb(200, 208, 224));
            draw_text_ext(_det_x + 6, _ey, _ent.text, -1, _det_w - 6);
            _ey += string_height_ext(_ent.text, -1, _det_w - 6) + 18;
        }
    }

    // Bottom instructions
    if (menu_tab != 1 && menu_tab != 3 && menu_tab != 4) {
        draw_set_halign(fa_center);
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(80, 90, 110));
        draw_text_outline(960, 1035, "Q/E: Switch Tab   I / Esc: Close");
        draw_set_halign(fa_left);
    }
    draw_set_font(-1);
    if (menu_tab == 4) {
        draw_set_halign(fa_center);
        draw_set_color(make_color_rgb(80, 90, 110));
        draw_text_outline(640, 690, "W/S: Browse Sections   Q/E: Switch Tab   I / Esc: Close");
        draw_set_halign(fa_left);
    }
    if (menu_tab == 3) {
        draw_set_halign(fa_center);
        if (_gc.consumable_submenu_open && array_length(global.consumable_inventory) > 0) {
            if (_no_ap) {
                draw_set_color(make_color_rgb(200, 80, 80));
                draw_text_outline(640, 690, "W/S: Navigate   Need 1 AP to use   Esc: Cancel");
            } else if (_limit_reached) {
                draw_set_color(make_color_rgb(200, 80, 80));
                draw_text_outline(640, 690, "W/S: Navigate   1 per turn limit   Esc: Cancel");
            } else {
                draw_set_color(make_color_rgb(80, 90, 110));
                draw_text_outline(640, 690, "W/S: Navigate   Enter: Use [-1 AP]   Esc: Cancel");
            }
        } else {
            draw_set_color(make_color_rgb(100, 200, 100));
            draw_text_outline(640, 690, "Enter: Browse Items   Q/E: Switch Tab   I: Close");
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
    draw_rectangle(0, 0, GUI_W, GUI_H, false);
    draw_set_alpha(1.0);

    // Title
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_font(fnt_ui_title);
    draw_set_color(_accent);
    draw_text(960, 36, _title);   // y36 keeps the title inside the rim opening

    // Gold (top-right) - pulled in from x1875 to clear the right rim band
    draw_set_halign(fa_right);
    draw_set_font(fnt_ui);
    draw_set_color(c_yellow);
    draw_text(1875, 36, "Gold: " + string(global.gold) + "g");

    // --- BUY / SELL tab bar ---
    var _tab_y = 87;
    var _tab_h = 39;

    // BUY tab (left of center)
    var _buy_on = (_gc.shop_tab == 0);
    draw_set_color(_buy_on ? make_color_rgb(16, 32, 22) : make_color_rgb(12, 14, 20));
    draw_rectangle(600, _tab_y, 938, _tab_y + _tab_h, false);
    draw_set_color(_buy_on ? _accent : make_color_rgb(30, 42, 50));
    draw_rectangle(600, _tab_y, 938, _tab_y + _tab_h, true);
    draw_set_halign(fa_center);
    draw_set_font(fnt_ui);
    draw_set_color(_buy_on ? _accent : make_color_rgb(70, 88, 100));
    draw_text(769, _tab_y + 9, "BUY");

    // SELL tab (right of center)
    var _sell_on = (_gc.shop_tab == 1);
    draw_set_color(_sell_on ? make_color_rgb(32, 24, 10) : make_color_rgb(12, 14, 20));
    draw_rectangle(983, _tab_y, 1320, _tab_y + _tab_h, false);
    draw_set_color(_sell_on ? make_color_rgb(220, 155, 45) : make_color_rgb(30, 42, 50));
    draw_rectangle(983, _tab_y, 1320, _tab_y + _tab_h, true);
    draw_set_color(_sell_on ? make_color_rgb(220, 155, 45) : make_color_rgb(70, 88, 100));
    draw_text(1151, _tab_y + 9, "SELL");

    // Q/E hint between tabs
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(50, 60, 80));
    draw_text_outline(960, _tab_y + 12, "Q/E");
    draw_set_halign(fa_left);

    // Notification line (shifted below tab bar)
    if (_gc.shop_notification != "") {
        draw_set_halign(fa_center);
        draw_set_font(fnt_ui);
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
        draw_text(960, 138, _gc.shop_notification);
        draw_set_halign(fa_left);
    }

    // Ornate gothic rim around the whole overlay. Drawn here (common to both Buy/Sell
    // branches) - the band sits OUTSIDE the content opening (30,30)-(1890,1050), so the
    // list rows (x150..1770, y189+) never touch it. Title/gold raised to y36, hints to y1026.
    ui_draw_gothic_frame(30, 30, 1890, 1050, 30);

    var _rx0  = 150;
    var _rw   = 1620;
    var _rh   = 117;   // tall enough for 3 lines (stats + unique desc / class tag)
    var _rgap = 9;
    var _ry0  = 189;   // shifted down to make room for tab bar

    // =========================================================================
    // SELL TAB
    // =========================================================================
    if (_gc.shop_tab == 1) {

        // Build the sell list: stash equipment -> stash consumables -> carried equipment -> carried consumables.
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
            draw_set_font(fnt_ui);
            draw_set_color(make_color_rgb(90, 100, 120));
            draw_text(960, 480, "Nothing to sell.");
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

                // Icon badge - gear icon for equipment, consumable badge otherwise
                var _sell_is_equip = variable_struct_exists(_it, "slot");
                var _sell_tx = _rx0 + 24;
                if (_sell_is_equip) {
                    ui_draw_item_icon(_rx0 + 15, _ry + 12, 48, _it);
                    _sell_tx = _rx0 + 75;
                } else {
                    ui_draw_consumable_icon(_rx0 + 15, _ry + 12, 48, _it);
                    _sell_tx = _rx0 + 75;
                }
                // Name
                draw_set_font(fnt_ui);
                draw_set_color(_name_col);
                draw_text(_sell_tx, _ry + 12, _it.name);
                // Stats or consumable description
                draw_set_font(fnt_ui_small);
                if (_sell_is_equip) {
                    draw_set_color(c_white);
                    draw_text(_sell_tx, _ry + 45, ui_item_stat_str(_it));
                    if (variable_struct_exists(_it, "unique_desc") && _it.unique_desc != "") {
                        draw_set_color(make_color_rgb(200, 160, 40));
                        draw_text(_sell_tx, _ry + 75, _it.unique_desc);
                    } else if (_it.effect_desc != "") {
                        draw_set_color(make_color_rgb(95, 105, 130));
                        draw_text(_sell_tx, _ry + 75, _it.effect_desc);
                    }
                } else {
                    var _cdesc = variable_struct_exists(_it, "description") ? _it.description : "";
                    draw_set_color(make_color_rgb(130, 140, 155));
                    draw_text(_sell_tx, _ry + 45, _cdesc);
                }
                // Right side: source tag + sell price + class restriction if any
                draw_set_halign(fa_right);
                draw_set_color(make_color_rgb(155, 165, 180));
                draw_text(_rx0 + _rw - 24, _ry + 12, _sl_tags[_ri]);
                draw_set_color(c_yellow);
                draw_text(_rx0 + _rw - 24, _ry + 45, string(_sprice) + "g");
                if (variable_struct_exists(_it, "class_req") && _it.class_req != -1) {
                    var _cr_labels = ["Arcanist", "Bloodwarden", "Shadowstrider"];
                    draw_set_color(make_color_rgb(160, 110, 60));
                    draw_text(_rx0 + _rw - 24, _ry + 75, "[" + _cr_labels[_it.class_req] + "]");
                }
                draw_set_halign(fa_left);
            }

            // Scroll indicator
            if (_sl_count > 7) {
                draw_set_halign(fa_center);
                draw_set_font(fnt_ui_small);
                draw_set_color(make_color_rgb(80, 90, 110));
                draw_text_outline(960, _ry0 + 7 * (_rh + _rgap) + 6, "W/S to scroll  (" + string(_sl_count) + " items)");
                draw_set_halign(fa_left);
            }
        }

        // Confirm bar for rare+ items (amber highlight)
        if (_gc.sell_confirm_name != "") {
            var _cf_y = 954;
            draw_set_color(make_color_rgb(50, 30, 8));
            draw_rectangle(150, _cf_y, 1770, _cf_y + 69, false);
            draw_set_color(make_color_rgb(220, 145, 40));
            draw_rectangle(150, _cf_y, 1770, _cf_y + 69, true);
            draw_set_halign(fa_center);
            draw_set_font(fnt_ui_small);
            draw_set_color(c_white);
            draw_text(960, _cf_y + 18, _gc.shop_notification + "   [SPACE] Confirm   [ESC] Cancel");
            draw_set_halign(fa_left);
        }

        // Sell tab footer - swaps to confirm hint when rare+ item confirmation is pending
        draw_set_halign(fa_center);
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(75, 85, 105));
        if (_gc.sell_confirm_name != "") {
            draw_text(960, 1026, "SPACE to confirm   ESC to cancel");
        } else {
            draw_text_outline(960, 1026, "W/S: Navigate   Q/E: Buy/Sell   Enter: Sell   Esc: Close");
        }
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        draw_set_alpha(1.0);
        return;
    }

    // =========================================================================
    // BUY TAB - unchanged buy content
    // =========================================================================

    // -------------------------------------------------------------------------
    // PETRA - 4 standard consumables always, plus optional limited special
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
            ui_draw_consumable_icon(_rx0 + 15, _ry + 15, 60, _it);

            // Name
            draw_set_font(fnt_ui);
            draw_set_color(make_color_rgb(80, 210, 210));
            draw_text(_rx0 + 90, _ry + 15, _it.name);

            // Description
            draw_set_font(fnt_ui_small);
            draw_set_color(make_color_rgb(130, 160, 170));
            draw_text(_rx0 + 90, _ry + 57, _it.description);

            // Limited tag
            if (_is_spec) {
                draw_set_color(make_color_rgb(255, 155, 30));
                draw_set_halign(fa_right);
                draw_text(_rx0 + _rw - 225, _ry + 15, "[LIMITED - " + string(global.petra_special_qty) + " left]");
                draw_set_halign(fa_left);
            }

            // Price (right-aligned)
            var _can_afford = (global.gold >= _price);
            draw_set_font(fnt_ui);
            draw_set_color(_can_afford ? c_yellow : make_color_rgb(180, 80, 80));
            draw_set_halign(fa_right);
            draw_text(_rx0 + _rw - 24, _ry + 57, string(_price) + "g");
            draw_set_halign(fa_left);
        }

    // -------------------------------------------------------------------------
    // DORN - rotating gear list; sold entries appear greyed with SOLD tag
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
                draw_set_font(fnt_ui);
                draw_set_color(make_color_rgb(65, 65, 65));
                draw_text(_rx0 + 24, _ry + 15, _entry.item.name);
                draw_set_halign(fa_right);
                draw_set_font(fnt_ui_small);
                draw_set_color(make_color_rgb(75, 75, 75));
                draw_text(_rx0 + _rw - 24, _ry + 42, "SOLD");
                draw_set_halign(fa_left);
            } else {
                var _rcol = item_rarity_color(_entry.item.rarity);
                // Icon badge
                ui_draw_item_icon(_rx0 + 15, _ry + 12, 48, _entry.item);
                // Name + rarity right-aligned
                draw_set_font(fnt_ui);
                draw_set_color(_rcol);
                draw_text(_rx0 + 75, _ry + 12, _entry.item.name);
                draw_set_halign(fa_right);
                draw_set_font(fnt_ui_small);
                draw_text(_rx0 + _rw - 24, _ry + 12, "[" + item_rarity_name(_entry.item.rarity) + "]");
                draw_set_halign(fa_left);
                // Stat string
                draw_set_color(c_white);
                var _dstat = ui_item_stat_str(_entry.item);
                draw_text(_rx0 + 75, _ry + 45, _dstat);
                // Stat requirement appended, red if the current class can't meet it (hard-blocked).
                var _dreq = item_stat_requirement(_entry.item);
                if (_dreq.value > 0 && _dreq.stat != "") {
                    draw_set_color((player_base_stat(_dreq.stat) >= _dreq.value)
                        ? make_color_rgb(110, 170, 110) : make_color_rgb(225, 80, 80));
                    draw_text(_rx0 + 75 + string_width(_dstat) + 27, _ry + 45, "Req " + string(_dreq.value) + " " + _dreq.stat);
                }
                // Flavor or unique below stats
                if (variable_struct_exists(_entry.item, "unique_desc") && _entry.item.unique_desc != "") {
                    draw_set_color(make_color_rgb(255, 200, 50));
                    draw_text(_rx0 + 75, _ry + 75, _entry.item.unique_desc);
                } else if (_entry.item.effect_desc != "") {
                    draw_set_color(make_color_rgb(95, 105, 130));
                    draw_text(_rx0 + 75, _ry + 75, _entry.item.effect_desc);
                }
                // Slot label right-aligned (so buyers know wep/arm/boot at a glance)
                if (variable_struct_exists(_entry.item, "slot")) {
                    draw_set_halign(fa_right);
                    draw_set_color(make_color_rgb(120, 135, 160));
                    draw_text(_rx0 + _rw - 24, _ry + 75, item_slot_label(_entry.item.slot));
                    draw_set_halign(fa_left);
                }
                // Price right-aligned (CHA-discounted)
                var _eprice     = cha_price(_entry.price);
                var _can_afford = (global.gold >= _eprice);
                draw_set_font(fnt_ui);
                draw_set_color(_can_afford ? c_yellow : make_color_rgb(180, 80, 80));
                draw_set_halign(fa_right);
                draw_text(_rx0 + _rw - 24, _ry + 45, string(_eprice) + "g");
                draw_set_halign(fa_left);
            }
        }
    }

    // Buy tab footer (raised to clear the bottom rim band)
    draw_set_halign(fa_center);
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(75, 85, 105));
    draw_text_outline(960, 1026, "W/S: Navigate   Q/E: Buy/Sell   Enter: Buy   Esc: Close     Purchases go to your stash.");
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
    draw_set_font(-1);
}

// ---------------------------------------------------------------------------
// ui_draw_consumable_overflow()
// Modal shown mid-run when the pack is full and another consumable is picked
// up. Resolves global.consumable_overflow one item at a time (see
// consumable_overflow_step). Drawn over both the combat and floor screens.
// ---------------------------------------------------------------------------
function ui_draw_consumable_overflow() {
    if (!consumable_overflow_pending()) return;
    if (!variable_global_exists("consumable_overflow_cursor")) global.consumable_overflow_cursor = 0;

    // Dim the whole screen
    draw_set_alpha(0.72);
    draw_set_color(make_color_rgb(6, 8, 14));
    draw_rectangle(0, 0, GUI_W, GUI_H, false);
    draw_set_alpha(1.0);

    var _new    = global.consumable_overflow[0];
    var _groups = consumables_grouped();
    var _options = array_length(_groups) + 1;
    var _cur    = clamp(global.consumable_overflow_cursor, 0, _options - 1);

    var _pw = 760;
    var _ph = 600;
    var _px = (GUI_W - _pw) / 2;
    var _py = (GUI_H - _ph) / 2;

    // Panel
    draw_set_color(make_color_rgb(18, 20, 32));
    draw_rectangle(_px, _py, _px + _pw, _py + _ph, false);
    draw_set_color(make_color_rgb(200, 110, 80));
    draw_rectangle(_px, _py, _px + _pw, _py + _ph, true);

    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_font(fnt_ui_title);
    draw_set_color(make_color_rgb(230, 130, 90));
    draw_text(_px + _pw / 2, _py + 18, "PACK FULL  (" + string(consumable_carry_cap()) + "/"
        + string(consumable_carry_cap()) + ")");

    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(200, 210, 225));
    draw_text(_px + _pw / 2, _py + 70, "Picked up  " + _new.name + ".  Discard one to make room, or leave it.");

    var _pending_extra = array_length(global.consumable_overflow) - 1;
    if (_pending_extra > 0) {
        draw_set_color(make_color_rgb(150, 160, 180));
        draw_text(_px + _pw / 2, _py + 96, "(" + string(_pending_extra) + " more waiting)");
    }

    draw_set_halign(fa_left);
    draw_set_font(fnt_ui);
    var _row_h = 46;
    var _list_x = _px + 50;
    var _list_y = _py + 140;

    for (var _i = 0; _i < _options; _i++) {
        var _is_sel = (_i == _cur);
        var _ry = _list_y + _i * _row_h;
        if (_ry + _row_h - 6 > _py + _ph - 70) break;   // don't spill past the footer

        if (_is_sel) {
            draw_set_alpha(0.9);
            draw_set_color(make_color_rgb(60, 40, 30));
            draw_rectangle(_list_x - 14, _ry - 4, _px + _pw - 50, _ry + _row_h - 10, false);
            draw_set_alpha(1.0);
        }

        if (_i < array_length(_groups)) {
            draw_set_color(_is_sel ? make_color_rgb(120, 230, 230) : make_color_rgb(80, 200, 200));
            draw_text(_list_x, _ry, "Discard:  " + consumable_group_label(_groups[_i]));
        } else {
            draw_set_color(_is_sel ? make_color_rgb(230, 160, 120) : make_color_rgb(180, 130, 100));
            draw_text(_list_x, _ry, "Leave " + _new.name + " behind");
        }
    }

    draw_set_halign(fa_center);
    draw_set_font(fnt_ui_small);
    draw_set_color(c_gray);
    draw_text(_px + _pw / 2, _py + _ph - 40, "W/S: Navigate    Enter: Confirm");

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_font(-1);
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
    draw_rectangle(0, 0, GUI_W, GUI_H, false);

    // Title
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_font(fnt_ui_title);
    draw_set_color(c_white);
    draw_text(960, 30, "ITEM STASH");   // y30 keeps the title inside the rim opening

    // Subtitle warning (pushed clear of the large title font's descenders so they
    // no longer collide just under the title)
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(180, 150, 80));
    draw_text(960, 102, "Equipped gear is always safe.   Carried items are lost on death (1 random salvage).");
    draw_set_halign(fa_left);

    var _ly      = 140;
    var _col_w   = 855;
    var _row_h   = 75;
    var _max_bot = 1020;
    var _list_top = _ly + 45;
    var _rows_visible = max(1, floor((_max_bot - _list_top) / _row_h));

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
    var _lx = 45;
    draw_set_color(_left_active ? make_color_rgb(80, 160, 220) : make_color_rgb(45, 55, 75));
    draw_rectangle(_lx, _ly, _lx + _col_w, _max_bot, true);

    draw_set_font(fnt_ui);
    draw_set_color(make_color_rgb(200, 100, 80));
    draw_text(_lx + 15, _ly + 9, "TAKING ON RUN  (at risk)");

    // Scroll window: keep the selection in view (the list follows the cursor
    // instead of the cursor scrolling off-screen). Only the active side tracks
    // the cursor; the inactive side shows from the top.
    var _left_n      = array_length(_left_items);
    var _left_scroll = 0;
    if (_left_active) {
        _left_scroll = clamp(_gc.stash_mode_index - floor(_rows_visible / 2),
                             0, max(0, _left_n - _rows_visible));
    }

    var _item_y = _list_top;
    for (var _i = _left_scroll; _i < _left_n; _i++) {
        if (_item_y + _row_h > _max_bot) break;
        var _it     = _left_items[_i];
        var _is_sel = (_left_active && _gc.stash_mode_index == _i);

        draw_set_alpha(_is_sel ? 0.9 : 0.5);
        draw_set_color(_is_sel ? make_color_rgb(30, 50, 80) : make_color_rgb(18, 22, 38));
        draw_rectangle(_lx + 6, _item_y, _lx + _col_w - 6, _item_y + _row_h - 3, false);
        draw_set_alpha(1.0);

        var _col = (_left_types[_i] == 1) ? make_color_rgb(80, 220, 220) : item_rarity_color(_it.rarity);
        if (_left_types[_i] == 0) ui_draw_item_icon(_lx + 12, _item_y + 8, 30, _it);
        else                      ui_draw_consumable_icon(_lx + 12, _item_y + 8, 30, _it);
        var _stl_tx = _lx + 51;
        draw_set_font(fnt_ui);
        draw_set_color(_col);
        draw_text(_stl_tx, _item_y + 8, _it.name);
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(140, 150, 170));
        draw_text(_stl_tx, _item_y + 39, (_left_types[_i] == 1) ? _it.description : ui_item_stat_str(_it));

        _item_y += _row_h;
    }
    // More-above / more-below hints
    if (_left_scroll > 0) {
        draw_set_font(fnt_ui_small);
        draw_set_halign(fa_right);
        draw_set_color(make_color_rgb(150, 170, 200));
        draw_text(_lx + _col_w - 14, _list_top - 26, "^ more");
        draw_set_halign(fa_left);
    }
    if (_left_scroll + _rows_visible < _left_n) {
        draw_set_font(fnt_ui_small);
        draw_set_halign(fa_right);
        draw_set_color(make_color_rgb(150, 170, 200));
        draw_text(_lx + _col_w - 14, _max_bot + 2, "v more");
        draw_set_halign(fa_left);
    }
    if (array_length(_left_items) == 0) {
        draw_set_font(fnt_ui);
        draw_set_color(make_color_rgb(70, 80, 100));
        draw_text(_lx + 18, _ly + 57, "Nothing in pack.");
    }

    // ---- RIGHT COLUMN ----
    var _rx = 1020;
    draw_set_color(_right_active ? make_color_rgb(80, 160, 220) : make_color_rgb(45, 55, 75));
    draw_rectangle(_rx, _ly, _rx + _col_w, _max_bot, true);

    draw_set_font(fnt_ui);
    draw_set_color(make_color_rgb(100, 200, 100));
    draw_text(_rx + 15, _ly + 9, "STASH  (safe)");

    var _right_n      = array_length(_right_items);
    var _right_scroll = 0;
    if (_right_active) {
        _right_scroll = clamp(_gc.stash_mode_index - floor(_rows_visible / 2),
                              0, max(0, _right_n - _rows_visible));
    }

    _item_y = _list_top;
    for (var _i = _right_scroll; _i < _right_n; _i++) {
        if (_item_y + _row_h > _max_bot) break;
        var _it     = _right_items[_i];
        var _is_sel = (_right_active && _gc.stash_mode_index == _i);

        draw_set_alpha(_is_sel ? 0.9 : 0.5);
        draw_set_color(_is_sel ? make_color_rgb(30, 50, 80) : make_color_rgb(18, 22, 38));
        draw_rectangle(_rx + 6, _item_y, _rx + _col_w - 6, _item_y + _row_h - 3, false);
        draw_set_alpha(1.0);

        var _col = (_right_types[_i] == 1) ? make_color_rgb(80, 220, 220) : item_rarity_color(_it.rarity);
        if (_right_types[_i] == 0) ui_draw_item_icon(_rx + 12, _item_y + 8, 30, _it);
        else                       ui_draw_consumable_icon(_rx + 12, _item_y + 8, 30, _it);
        var _str_tx = _rx + 51;
        draw_set_font(fnt_ui);
        draw_set_color(_col);
        draw_text(_str_tx, _item_y + 8, _it.name);
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(140, 150, 170));
        draw_text(_str_tx, _item_y + 39, (_right_types[_i] == 1) ? _it.description : ui_item_stat_str(_it));

        _item_y += _row_h;
    }
    if (_right_scroll > 0) {
        draw_set_font(fnt_ui_small);
        draw_set_halign(fa_right);
        draw_set_color(make_color_rgb(150, 170, 200));
        draw_text(_rx + _col_w - 14, _list_top - 26, "^ more");
        draw_set_halign(fa_left);
    }
    if (_right_scroll + _rows_visible < _right_n) {
        draw_set_font(fnt_ui_small);
        draw_set_halign(fa_right);
        draw_set_color(make_color_rgb(150, 170, 200));
        draw_text(_rx + _col_w - 14, _max_bot + 2, "v more");
        draw_set_halign(fa_left);
    }
    if (array_length(_right_items) == 0) {
        draw_set_font(fnt_ui);
        draw_set_color(make_color_rgb(70, 80, 100));
        draw_text(_rx + 18, _ly + 57, "Nothing in stash.");
    }

    // Footer (raised to clear the bottom rim band)
    draw_set_halign(fa_center);
    draw_set_font(fnt_ui_small);
    draw_set_color(c_gray);
    draw_text_outline(960, 1026, "Q/E: Switch Side   W/S: Navigate   Enter: Move Item   Esc: Close");
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);

    // Ornate gothic rim around the whole overlay. Columns (x105..960 / 1020..1875) and the
    // y123..1020 lists sit inside the opening (30,30)-(1890,1050); the tooltip draws on top after.
    ui_draw_gothic_frame(30, 30, 1890, 1050, 30);

    // Hover tooltip - scan both columns for the moused-over item
    var _hmx_st = device_mouse_x_to_gui(0);
    var _hmy_st = device_mouse_y_to_gui(0);
    var _st_hover = undefined;
    var _hy_l = _ly + 45;
    for (var _sthi = 0; _sthi < array_length(_left_items) && _st_hover == undefined; _sthi++) {
        if (_hy_l + _row_h > _max_bot) break;
        if (_hmx_st >= _lx + 6 && _hmx_st < _lx + _col_w - 6
                && _hmy_st >= _hy_l && _hmy_st < _hy_l + _row_h - 3) {
            _st_hover = _left_items[_sthi];
        }
        _hy_l += _row_h;
    }
    if (_st_hover == undefined) {
        var _hy_r = _ly + 45;
        for (var _sthi = 0; _sthi < array_length(_right_items); _sthi++) {
            if (_hy_r + _row_h > _max_bot) break;
            if (_hmx_st >= _rx + 6 && _hmx_st < _rx + _col_w - 6
                    && _hmy_st >= _hy_r && _hmy_st < _hy_r + _row_h - 3) {
                _st_hover = _right_items[_sthi];
                break;
            }
            _hy_r += _row_h;
        }
    }
    if (_st_hover != undefined) {
        ui_draw_item_tooltip(_hmx_st + 21, _hmy_st - 30, _st_hover, undefined);
        // Alt+click on an equipment item opens the comparison panel
        if (mouse_check_button_pressed(mb_left) && keyboard_check(vk_alt)
                && variable_struct_exists(_st_hover, "slot")) {
            _gc.comparison_item     = _st_hover;
            _gc.comparison_equipped = undefined;
            if (variable_global_exists("inventory")) {
                var _cmp_si = comparison_target_index(_st_hover);   // ring-aware target
                if (_cmp_si >= 0 && _cmp_si < array_length(global.inventory)) {
                    _gc.comparison_equipped = global.inventory[_cmp_si];
                }
            }
            _gc.comparison_open = true;
        }
    }

    draw_set_alpha(1.0);
    draw_set_font(-1);
}


// ---------------------------------------------------------------------------
// _cmp_stat_name(st)  - readable display name for an affix stat_type string
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

    // Panel sizing - grows with row count
    var _row_h  = 42;
    var _hdr_h  = 117;
    var _ftr_h  = 39;
    var _nrows  = max(array_length(_keys), 1);
    var _pw     = 750;
    var _ph     = _hdr_h + _nrows * _row_h + _ftr_h;
    var _px     = GUI_CX - _pw / 2;
    var _py     = GUI_CY - _ph / 2;
    var _mid    = _px + _pw / 2;
    var _cl     = _px + 15;
    var _cr     = _mid + 15;

    // Background and border
    draw_set_alpha(0.96);
    draw_set_color(make_color_rgb(10, 12, 22));
    draw_rectangle(_px, _py, _px + _pw, _py + _ph, false);
    draw_set_alpha(1.0);
    draw_set_color(make_color_rgb(90, 90, 140));
    draw_rectangle(_px, _py, _px + _pw, _py + _ph, true);

    // Title bar
    draw_set_color(make_color_rgb(55, 60, 95));
    draw_rectangle(_px, _py, _px + _pw, _py + 33, false);
    draw_set_font(fnt_ui);
    draw_set_color(c_white);
    draw_set_halign(fa_center);
    draw_text(GUI_CX, _py + 6, "ITEM COMPARISON");

    // New item header (left half)
    var _nc = variable_struct_exists(new_item, "rarity") ? item_rarity_color(new_item.rarity) : c_white;
    draw_set_halign(fa_left);
    draw_set_color(_nc);
    draw_text(_cl, _py + 39, new_item.name);
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(105, 115, 140));
    draw_text(_cl, _py + 66, string_upper(new_item.slot));
    draw_set_color(make_color_rgb(70, 190, 70));
    draw_text(_cl, _py + 90, "[New]");

    // Equipped item header (right half)
    if (equipped_item != undefined) {
        var _ec = variable_struct_exists(equipped_item, "rarity") ? item_rarity_color(equipped_item.rarity) : c_white;
        draw_set_font(fnt_ui);
        draw_set_color(_ec);
        draw_text(_cr, _py + 39, equipped_item.name);
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(105, 115, 140));
        draw_text(_cr, _py + 66, string_upper(equipped_item.slot));
        draw_set_color(make_color_rgb(200, 180, 60));
        draw_text(_cr, _py + 90, "[Equipped]");
    } else {
        draw_set_font(fnt_ui);
        draw_set_color(make_color_rgb(95, 95, 105));
        draw_text(_cr, _py + 39, "Nothing Equipped");
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(65, 65, 75));
        draw_text(_cr, _py + 66, string_upper(new_item.slot) + " slot empty");
    }

    // Divider lines
    draw_set_color(make_color_rgb(55, 60, 95));
    draw_line(_px + 9, _py + _hdr_h - 6, _px + _pw - 9, _py + _hdr_h - 6);
    draw_line(_mid,    _py + _hdr_h,      _mid,           _py + _ph - _ftr_h);

    // Stat rows
    draw_set_font(fnt_ui_small);
    if (array_length(_keys) == 0) {
        draw_set_color(make_color_rgb(95, 95, 115));
        draw_set_halign(fa_center);
        draw_text(GUI_CX, _py + _hdr_h + 12, "No stat affixes");
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
        draw_text(_cl, _ry + 9, _cmp_stat_name(_sk));

        // New item value (right edge of left half)
        draw_set_color(c_white);
        draw_set_halign(fa_right);
        draw_text(_mid - 12, _ry + 9, (_nv > 0 ? "+" : "") + string(_nv));

        // Equipped value (left edge of right half)
        if (equipped_item != undefined) {
            draw_set_color(make_color_rgb(150, 150, 160));
            draw_set_halign(fa_left);
            draw_text(_cr, _ry + 9, (_ev > 0 ? "+" : "") + string(_ev));
        }

        // Delta (far right, color-coded)
        if (_delta != 0) {
            var _dcol = (_delta > 0) ? make_color_rgb(80, 230, 80) : make_color_rgb(230, 80, 80);
            var _darr = (_delta > 0) ? " ^" : " v";
            draw_set_color(_dcol);
            draw_set_halign(fa_right);
            draw_text(_px + _pw - 12, _ry + 9,
                ((_delta > 0) ? "+" : "") + string(_delta) + _darr);
        } else {
            draw_set_color(make_color_rgb(120, 120, 135));
            draw_set_halign(fa_right);
            draw_text(_px + _pw - 12, _ry + 9, "=");
        }
    }

    // Footer close hint
    draw_set_halign(fa_center);
    draw_set_color(make_color_rgb(95, 95, 115));
    draw_text(GUI_CX, _py + _ph - 30, "Alt+Click or ESC to close");

    draw_set_halign(fa_left);
    draw_set_alpha(1.0);
    draw_set_font(-1);
}


// ---------------------------------------------------------------------------
// ui_draw_trainer_screen()
// Full-screen overlay for Vex the Trainer (trainer_open). Four sections:
//   tab 0 Stats - 200g + a Rare+ item per +1 permanent stat
//   tab 1 Trait Slots - 800g / 2000g for +1 / +2 active-trait slots
//   tab 2 Abilities - 500g to unlock a non-starter ability into the loadout pool
//   tab 3 Potency - sacrifice 5 permanent stat points for +10% trait strength
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
    draw_rectangle(0, 0, GUI_W, GUI_H, false);
    draw_set_alpha(1.0);

    // Title + gold
    draw_set_valign(fa_top);
    draw_set_halign(fa_center);
    draw_set_font(fnt_ui_title);
    draw_set_color(_accent);
    draw_text(960, 36, "VEX THE TRAINER");   // y36 keeps the title inside the rim opening
    draw_set_halign(fa_right);
    draw_set_font(fnt_ui);
    draw_set_color(c_yellow);
    draw_text(1875, 36, "Gold: " + string(global.gold) + "g");        // pulled in to clear the right band

    // --- Tab bar (5 tabs) ---
    var _tab_labels = ["STATS", "TRAIT SLOTS", "ABILITIES", "TRAITS", "POTENCY"];
    draw_set_font(fnt_ui);
    for (var _t = 0; _t < 5; _t++) {
        var _tx  = 68 + _t * 360;
        var _on  = (_gc.trainer_tab == _t);
        draw_set_color(_on ? make_color_rgb(28, 18, 48) : make_color_rgb(12, 13, 20));
        draw_rectangle(_tx, 96, _tx + 345, 144, false);
        draw_set_color(_on ? _accent : make_color_rgb(40, 40, 60));
        draw_rectangle(_tx, 96, _tx + 345, 144, true);
        draw_set_halign(fa_center);
        draw_set_color(_on ? c_white : make_color_rgb(95, 95, 125));
        draw_text(_tx + 173, 108, _tab_labels[_t]);
    }

    // --- Notification line ---
    if (_gc.trainer_notification != "") {
        draw_set_halign(fa_center);
        draw_set_font(fnt_ui);
        var _is_warn = (string_pos("Beware", _gc.trainer_notification) > 0);
        var _is_bad  = (string_pos("Not enough", _gc.trainer_notification) > 0
                     || string_pos("Need", _gc.trainer_notification) > 0
                     || string_pos("need a", _gc.trainer_notification) > 0);
        draw_set_color(_is_warn ? make_color_rgb(255, 90, 90)
                     : (_is_bad ? make_color_rgb(230, 130, 70)
                                : make_color_rgb(120, 220, 140)));
        draw_text(960, 168, _gc.trainer_notification);
    }

    var _rx0 = 180;
    var _rx1 = 1740;
    var _ry0 = 225;
    var _rh  = 87;
    var _rgap = 9;

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

            draw_set_font(fnt_ui);
            draw_set_color(_sel ? c_white : make_color_rgb(180, 185, 210));
            draw_text(_rx0 + 24, _ry + 9, _stat_names[_i] + "   (current permanent bonus: +" + string(_cur) + ")");
            draw_set_font(fnt_ui_small);
            draw_set_color(make_color_rgb(120, 125, 150));
            draw_text(_rx0 + 24, _ry + 45, "Raise this stat permanently by +1.");

            draw_set_halign(fa_right);
            draw_set_font(fnt_ui);
            draw_set_color(c_yellow);
            draw_text(_rx1 - 24, _ry + 9, string(cha_price(200)) + "g  +  1 Rare+ item");
            draw_set_halign(fa_left);
        }

        // Trade-item readout
        var _trade = trainer_find_rare_item();
        draw_set_halign(fa_center);
        draw_set_font(fnt_ui_small);
        if (_trade != undefined) {
            draw_set_color(make_color_rgb(120, 200, 140));
            draw_text(960, 840, "Trade item ready: " + _trade.item.name + "  (" + item_rarity_name(_trade.rarity) + ")  -  the lowest-value Rare+ item is used.");
        } else {
            draw_set_color(make_color_rgb(210, 120, 70));
            draw_text(960, 840, "No Rare or better item in your stash/pack to trade.");
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
            draw_set_font(fnt_ui);
            draw_set_color(make_color_rgb(110, 200, 130));
            draw_text(_rx0 + 24, _ry + 27, "All trait slots purchased - you have the maximum of 4.");
        } else {
            draw_set_font(fnt_ui);
            draw_set_color(c_white);
            draw_text(_rx0 + 24, _ry + 9, "Unlock trait slot #" + string(_total + 1));
            draw_set_font(fnt_ui_small);
            draw_set_color(make_color_rgb(120, 125, 150));
            draw_text(_rx0 + 24, _ry + 45, "Permanently raises your base active-trait slots to " + string(_total + 1) + ".");
            draw_set_halign(fa_right);
            draw_set_font(fnt_ui);
            draw_set_color(c_yellow);
            draw_text(_rx1 - 24, _ry + 27, string(_cost) + "g");
            draw_set_halign(fa_left);
        }

        // Info block (below the row - text only, no hit-test)
        draw_set_halign(fa_center);
        draw_set_font(fnt_ui);
        draw_set_color(make_color_rgb(190, 160, 240));
        draw_text(960, 420, "Active Trait Slots:  " + string(_total) + "   (base 2  +  " + string(_bts) + " purchased)");
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(120, 125, 150));
        draw_text(960, 468, "Buy extra slots to equip more traits at once. Maximum +2 (4 total).");
        draw_set_color(make_color_rgb(90, 95, 120));
        draw_text(960, 504, "Stacks on top of Crown of the Hollow King while it is equipped.");
        draw_set_halign(fa_left);
    }

    // =====================================================================
    // TAB 2: ABILITY UNLOCKS
    // =====================================================================
    else if (_gc.trainer_tab == 2) {
        draw_set_halign(fa_center);
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(140, 145, 175));
        draw_text(960, 186, "Class: " + _class_names[clamp(_class_id, 0, 2)] + "   -   unlocked abilities can be slotted in your loadout.");
        draw_set_halign(fa_left);

        var _locked = class_vex_purchasable(_class_id);
        if (array_length(_locked) == 0) {
            draw_set_halign(fa_center);
            draw_set_font(fnt_ui);
            draw_set_color(make_color_rgb(110, 200, 130));
            draw_text(960, 495, "Every purchasable ability for this class is unlocked.");
            draw_set_font(fnt_ui_small);
            draw_set_color(make_color_rgb(110, 115, 145));
            draw_text(960, 540, "Some abilities unlock through progression instead - see your loadout.");
            draw_set_halign(fa_left);
        } else {
            // Taller rows than the other tabs so the full ability description fits
            // on two wrapped lines without spilling outside the row.
            var _ab_rh      = 117;
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

                // Role-category accent bar on the left edge (SYSTEMS_ABILITY_SYNERGY.md).
                draw_set_color(ability_category_color(ability_category(_ab)));
                draw_rectangle(_rx0, _ry, _rx0 + 6, _ry + _ab_rh, false);

                // Ability icon - 84x84 badge on the left of the row
                draw_set_alpha(1.0);
                ui_draw_ability_icon(_rx0 + 17, _ry + 17, 84, _ab);
                var _ab_textx = _rx0 + 17 + 84 + 18;

                draw_set_font(fnt_ui);
                draw_set_color(_sel ? c_white : make_color_rgb(180, 185, 210));
                draw_text(_ab_textx, _ry + 12, _ab.name);
                // Canonical full description (damage clause + every effect) plus the
                // melee/ranged attack-class tag - the complete explanation, wrapped.
                var _ab_desc = ability_describe(_ab);
                var _ab_tag  = ability_attack_class_tag(_ab);
                if (_ab_tag != "") _ab_desc = (_ab_desc != "") ? (_ab_desc + "  " + _ab_tag) : _ab_tag;
                draw_set_font(fnt_ui_small);
                draw_set_color(make_color_rgb(135, 142, 170));
                draw_text_ext(_ab_textx, _ry + 48, _ab_desc, -1, (_rx1 - 24) - _ab_textx);

                draw_set_halign(fa_right);
                draw_set_font(fnt_ui);
                draw_set_color(c_yellow);
                draw_text(_rx1 - 24, _ry + 12, "[" + string(_ab.energy_cost) + " AP]   " + string(_cost) + "g");
                draw_set_halign(fa_left);
            }
            draw_set_font(fnt_ui_small);
            if (_ab_scroll > 0) {
                draw_set_halign(fa_center); draw_set_color(_accent);
                draw_text(960, _ry0 - 24, "^ more above");
            }
            if (_ab_scroll + _ab_max_vis < array_length(_locked)) {
                draw_set_halign(fa_center); draw_set_color(_accent);
                draw_text(960, _ry0 + _ab_max_vis * (_ab_rh + _rgap) - 3, "v more below");
            }
            draw_set_halign(fa_left);
        }
    }

    // =====================================================================
    // TAB 3: TRAIT UNLOCKS (gold + a rarity-matched item)
    // =====================================================================
    else if (_gc.trainer_tab == 3) {
        draw_set_halign(fa_center);
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(140, 145, 175));
        draw_text(960, 186, "Class: " + _class_names[clamp(_class_id, 0, 2)]
            + "   -   unlocked traits can be equipped at the Dungeon Gate.");
        draw_set_halign(fa_left);

        var _tr_locked = trait_vex_purchasable(_class_id);
        if (array_length(_tr_locked) == 0) {
            draw_set_halign(fa_center);
            draw_set_font(fnt_ui);
            draw_set_color(make_color_rgb(110, 200, 130));
            draw_text(960, 495, "Every trait available to this class is unlocked.");
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

                draw_set_font(fnt_ui);
                draw_set_color(_sel ? c_white : make_color_rgb(180, 185, 210));
                draw_text(_rx0 + 24, _ry + 9, _tt.name
                    + (_tt.class_req != -1 ? "   (" + _class_names[clamp(_tt.class_req, 0, 2)] + ")" : ""));
                draw_set_font(fnt_ui_small);
                draw_set_color(make_color_rgb(120, 125, 150));
                draw_text(_rx0 + 24, _ry + 45, _tt.description);

                draw_set_halign(fa_right);
                draw_set_font(fnt_ui);
                draw_set_color(_afford ? c_yellow : make_color_rgb(150, 90, 90));
                draw_text(_rx1 - 24, _ry + 9, string(_tcost.gold) + "g");
                draw_set_font(fnt_ui_small);
                draw_set_color(_afford ? make_color_rgb(180, 160, 230) : make_color_rgb(150, 90, 90));
                draw_text(_rx1 - 24, _ry + 45, "+ 1 " + _tcost.item_label + " item");
                draw_set_halign(fa_left);
            }
            draw_set_font(fnt_ui_small);
            if (_tr_scroll > 0) {
                draw_set_halign(fa_center); draw_set_color(_accent);
                draw_text(960, _ry0 - 24, "^ more above");
            }
            if (_tr_scroll + _tr_max_vis < array_length(_tr_locked)) {
                draw_set_halign(fa_center); draw_set_color(_accent);
                draw_text(960, _ry0 + _tr_max_vis * (_rh + _rgap) - 3, "v more below");
            }
            draw_set_halign(fa_left);
        }

        // Trade-item readout (mirrors the Stats tab)
        var _tr_sel_cost = (array_length(_tr_locked) > 0)
            ? trait_unlock_cost(_tr_locked[clamp(_gc.trainer_cursor, 0, array_length(_tr_locked) - 1)].name)
            : { gold:0, min_rarity:2, item_label:"Rare" };
        var _tr_trade = trainer_find_item(_tr_sel_cost.min_rarity);
        draw_set_halign(fa_center);
        draw_set_font(fnt_ui_small);
        if (_tr_trade != undefined) {
            draw_set_color(make_color_rgb(120, 200, 140));
            draw_text(960, 939, "Trade item ready: " + _tr_trade.item.name + "  ("
                + item_rarity_name(_tr_trade.rarity) + ")  -  lowest-value " + _tr_sel_cost.item_label + "+ item is used.");
        } else {
            draw_set_color(make_color_rgb(210, 120, 70));
            draw_text(960, 939, "No " + _tr_sel_cost.item_label + " or better item in your stash/pack for this trait.");
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

            draw_set_font(fnt_ui);
            draw_set_color(_sel ? c_white : make_color_rgb(180, 185, 210));
            draw_text(_rx0 + 24, _ry + 9, _up.name);
            draw_set_font(fnt_ui_small);
            draw_set_color(make_color_rgb(120, 125, 150));
            draw_text(_rx0 + 24, _ry + 45, _up.effect + "   -   Tier " + string(_tier) + " / 5   (+" + string(_tier * 10) + "% now)");

            // Tier pips
            for (var _p = 0; _p < 5; _p++) {
                var _px2 = _rx0 + 810 + _p * 27;
                draw_set_color(_p < _tier ? _accent : make_color_rgb(45, 47, 66));
                draw_rectangle(_px2, _ry + 12, _px2 + 20, _ry + 33, false);
            }

            draw_set_halign(fa_right);
            if (_tier >= 5) {
                draw_set_font(fnt_ui);
                draw_set_color(make_color_rgb(110, 200, 130));
                draw_text(_rx1 - 24, _ry + 9, "MAX  (+50%)");
            } else {
                draw_set_font(fnt_ui);
                draw_set_color(c_yellow);
                draw_text(_rx1 - 24, _ry + 9, "Sacrifice 5 (any stat)");
                draw_set_font(fnt_ui_small);
                draw_set_color(make_color_rgb(120, 125, 150));
                draw_text(_rx1 - 24, _ry + 45, "Enter: choose a stat to spend");
            }
            draw_set_halign(fa_left);
        }

        // Confirmation bar (non-refundable sacrifice)
        if (_gc.trainer_confirm) {
            draw_set_color(make_color_rgb(50, 12, 12));
            draw_rectangle(_rx0, 987, _rx1, 1041, false);
            draw_set_color(make_color_rgb(200, 60, 60));
            draw_rectangle(_rx0, 987, _rx1, 1041, true);
            draw_set_halign(fa_center);
            draw_set_font(fnt_ui_small);
            draw_set_color(make_color_rgb(255, 110, 110));
            draw_text_outline(960, 1002, "Beware, what you are about to do can not be undone.   [ Space ] Confirm     [ Esc ] Cancel");
            draw_set_halign(fa_left);
        }
    }

    // --- Controls hint (raised to clear the bottom rim band) ---
    draw_set_halign(fa_center);
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(70, 75, 100));
    draw_text_outline(960, 1026, "W/S: Navigate    Q/E: Section    Enter: Buy / Select    Tab: Examine    Esc: Close");
    draw_set_halign(fa_left);

    // Ornate gothic rim around the whole overlay (matches the other NPC shops).
    ui_draw_gothic_frame(30, 30, 1890, 1050, 30);

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
    draw_set_font(-1);
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
    var _px = 630, _pw = 660, _py = 255, _ph = 660, _y0 = 375, _rh = 60;
    var _minus_x = _px + _pw - 144;
    var _plus_x  = _px + _pw - 72;

    // Dim + panel
    draw_set_alpha(0.6); draw_set_color(c_black);
    draw_rectangle(0, 0, display_get_gui_width(), display_get_gui_height(), false);
    draw_set_alpha(0.97); draw_set_color(make_color_rgb(22, 20, 34));
    draw_rectangle(_px, _py, _px + _pw, _py + _ph, false);
    draw_set_alpha(1.0); draw_set_color(make_color_rgb(150, 140, 180));
    draw_rectangle(_px, _py, _px + _pw, _py + _ph, true);

    // Header - wrapped so long trait names never overflow the panel.
    var _hw = _pw - 48;
    draw_set_halign(fa_center); draw_set_valign(fa_top);
    draw_set_font(fnt_ui);
    draw_set_color(make_color_rgb(255, 225, 150));
    draw_text_ext(_px + _pw / 2, _py + 18, "Raise " + _gc.trainer_statpick_trait + " potency", -1, _hw);
    draw_set_font(fnt_ui_small);
    draw_set_color(c_ltgray);
    draw_text_ext(_px + _pw / 2, _py + 66, "Spend 5 points total - use - / + on any stats", -1, _hw);
    draw_set_halign(fa_left);

    // Stat rows: name - (have N) - [-] alloc [+]
    for (var _i = 0; _i < 6; _i++) {
        var _ry    = _y0 + _i * _rh;
        var _have  = stat_available_points(_stats[_i]);
        var _a     = _alloc[_i];
        var _sel   = (_gc.trainer_statpick_cursor == _i);
        var _can_inc = (_total < 5 && _a < _have);

        if (_sel) {
            draw_set_alpha(0.30); draw_set_color(make_color_rgb(120, 100, 160));
            draw_rectangle(_px + 24, _ry, _px + _pw - 24, _ry + _rh - 6, false);
            draw_set_alpha(1.0);
            draw_set_color(make_color_rgb(170, 150, 210));
            draw_rectangle(_px + 24, _ry, _px + _pw - 24, _ry + _rh - 6, true);
        }

        // Stat name + how many points are available to spend.
        draw_set_halign(fa_left); draw_set_valign(fa_top);
        draw_set_font(fnt_ui);
        draw_set_color((_have > 0) ? c_white : make_color_rgb(120, 90, 90));
        draw_text(_px + 42, _ry + 12, _stats[_i]);
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(120, 125, 150));
        draw_text(_px + 144, _ry + 12, "have " + string(_have));

        // [-] button (dim when nothing allocated).
        draw_set_color(_a > 0 ? make_color_rgb(200, 120, 120) : make_color_rgb(70, 60, 70));
        draw_rectangle(_minus_x, _ry + 9, _minus_x + 48, _ry + _rh - 15, true);
        draw_set_halign(fa_center);
        draw_set_font(fnt_ui);
        draw_text(_minus_x + 24, _ry + 12, "-");

        // Allocated amount.
        draw_set_color(_a > 0 ? c_yellow : make_color_rgb(120, 120, 140));
        draw_text((_minus_x + 48 + _plus_x) / 2, _ry + 12, string(_a));

        // [+] button (dim when capped by availability or the 5-point total).
        draw_set_color(_can_inc ? make_color_rgb(130, 200, 140) : make_color_rgb(60, 70, 60));
        draw_rectangle(_plus_x, _ry + 9, _plus_x + 48, _ry + _rh - 15, true);
        draw_text(_plus_x + 24, _ry + 12, "+");
        draw_set_halign(fa_left);
    }

    // Running total.
    draw_set_halign(fa_center);
    draw_set_font(fnt_ui);
    draw_set_color(_total == 5 ? make_color_rgb(120, 210, 130) : c_yellow);
    draw_text(_px + _pw / 2, _y0 + 6 * _rh + 9, "Total: " + string(_total) + " / 5");
    draw_set_halign(fa_left);

    // Footer / confirm
    if (variable_instance_exists(_gc, "trainer_statpick_confirm") && _gc.trainer_statpick_confirm) {
        draw_set_alpha(0.95); draw_set_color(make_color_rgb(120, 40, 40));
        draw_rectangle(_px + 24, _py + _ph - 105, _px + _pw - 24, _py + _ph - 54, false);
        draw_set_alpha(1.0);
        draw_set_halign(fa_center);
        draw_set_font(fnt_ui_small); draw_set_color(c_white);
        draw_text_ext(_px + _pw / 2, _py + _ph - 96, "Sacrifice these 5 points permanently? Cannot be undone.", -1, _pw - 60);
        draw_set_color(c_ltgray);
        draw_text_outline(_px + _pw / 2, _py + _ph - 36, "Enter: confirm     Esc: back");
    } else {
        draw_set_halign(fa_center);
        draw_set_font(fnt_ui_small); draw_set_color(c_ltgray);
        draw_text_ext(_px + _pw / 2, _py + _ph - 45, "W/S: Stat    A/D or -/+: Adjust    Enter: Confirm    Esc: Cancel", -1, _pw - 48);
    }

    draw_set_halign(fa_left); draw_set_valign(fa_top);
    draw_set_color(c_white); draw_set_alpha(1.0);
    draw_set_font(-1);
}

// Draws one Maren list-row background (row index _i) and returns the text baseline y.
function ui_maren_row(_i, _selected, _base_y = 285) {
    var _ry = _base_y + _i * 72;
    draw_set_color(_selected ? make_color_rgb(45, 38, 66) : make_color_rgb(20, 18, 30));
    draw_rectangle(300, _ry, 1620, _ry + 66, false);
    draw_set_color(_selected ? make_color_rgb(150, 110, 220) : make_color_rgb(45, 42, 62));
    draw_rectangle(300, _ry, 1620, _ry + 66, true);
    return _ry + 15;
}

// ---------------------------------------------------------------------------
// ui_draw_maren_screen()
// Maren the Runesmith - rune socketing overlay (Phase 1: Socket gear + Runes).
// Layout constants MUST match the Maren input block in obj_game_controller Step.
// ---------------------------------------------------------------------------
function ui_draw_maren_screen() {
    if (!instance_exists(obj_game_controller)) return;
    var _gc = instance_find(obj_game_controller, 0);
    if (!variable_instance_exists(_gc, "maren_open") || !_gc.maren_open) return;

    // Full-screen overlay
    draw_set_alpha(1.0);
    draw_set_color(make_color_rgb(10, 8, 16));
    draw_rectangle(0, 0, GUI_W, GUI_H, false);

    // Title + dust
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_font(fnt_ui_title);
    draw_set_color(make_color_rgb(180, 150, 230));
    draw_text(960, 36, "Maren the Runesmith");
    draw_set_halign(fa_right);
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(200, 180, 130));
    var _dust = variable_global_exists("rune_dust") ? global.rune_dust : 0;
    draw_text(1860, 48, "Rune Dust: " + string(_dust));
    // Player gold, under the dust readout
    draw_set_color(c_yellow);
    draw_text(1860, 84, "Gold: " + string(global.gold) + "g");
    draw_set_halign(fa_left);

    // Tab bar (4 tabs) - x=368+t*300, y=105, w=285, h=60
    var _tab_labels = ["Socket Gear", "Aspects", "Forge", "Runes"];
    draw_set_font(fnt_ui);
    for (var _t = 0; _t < 4; _t++) {
        var _tx  = 368 + _t * 300;
        var _on  = (_gc.maren_tab == _t);
        draw_set_color(_on ? make_color_rgb(45, 35, 70) : make_color_rgb(22, 20, 34));
        draw_rectangle(_tx, 105, _tx + 285, 165, false);
        draw_set_color(_on ? make_color_rgb(150, 110, 220) : make_color_rgb(55, 50, 75));
        draw_rectangle(_tx, 105, _tx + 285, 165, true);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_set_color(_on ? c_white : make_color_rgb(150, 150, 170));
        draw_text(_tx + 143, 135, _tab_labels[_t]);
    }
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_font(fnt_ui);

    var _row_y0 = 285;
    var _list_x = 300;
    var _list_x2 = 1620;
    var _cursor = _gc.maren_cursor;

    if (_gc.maren_tab == 0) {
        // -------- SOCKET GEAR TAB --------
        var _slots = maren_socketable_slots();

        if (_gc.maren_phase == 0) {
            // Breadcrumb
            draw_set_color(make_color_rgb(140, 130, 165));
            draw_text(_list_x, 225, "Choose a piece of gear to socket:");

            if (array_length(_slots) == 0) {
                draw_set_color(make_color_rgb(120, 115, 140));
                draw_text(_list_x, _row_y0 + 12, "No socketed gear equipped. Uncommon+ items have sockets - equip some first.");
            }
            for (var _i = 0; _i < array_length(_slots); _i++) {
                var _it = global.inventory[_slots[_i]];
                item_ensure_sockets(_it);
                var _ty = ui_maren_row(_i, _i == _cursor);
                draw_set_color(item_rarity_color(_it.rarity));
                draw_text(_list_x + 24, _ty, _it.name);
                // Socket count drawn left-of-centre (not far-right) so it stays clear of
                // the gear-breakdown panel that overlaps the right side of the rows.
                draw_set_color(make_color_rgb(170, 160, 190));
                draw_text(_list_x + 620, _ty,
                    string(array_length(_it.runes)) + " / " + string(_it.socket_count) + " sockets filled");
            }
            // Full gear breakdown for the highlighted piece (same panel the inventory
            // uses) so you can judge an item's stats before deciding to socket it.
            if (array_length(_slots) > 0) {
                var _sel_i  = clamp(_cursor, 0, array_length(_slots) - 1);
                var _sel_it = global.inventory[_slots[_sel_i]];
                ui_draw_item_tooltip(1190, 255, _sel_it, undefined);
            }
        } else if (_gc.maren_phase == 1) {
            var _it = global.inventory[_gc.maren_item_sel];
            item_ensure_sockets(_it);
            draw_set_color(make_color_rgb(140, 130, 165));
            draw_text(_list_x, 225, "Sockets on ");
            draw_set_color(item_rarity_color(_it.rarity));
            draw_text(_list_x + 135, 225, _it.name);
            draw_set_color(make_color_rgb(110, 105, 130));
            draw_text(_list_x, 252, "Enter a filled socket to remove its rune, or an empty socket to add one.");

            var _filled = array_length(_it.runes);
            for (var _s = 0; _s < _it.socket_count; _s++) {
                var _ty2 = ui_maren_row(_s, _s == _cursor);
                if (_s < _filled) {
                    draw_set_color(make_color_rgb(150, 200, 255));
                    draw_text(_list_x + 24, _ty2, rune_describe(_it.runes[_s]));
                    draw_set_halign(fa_right);
                    draw_set_color(make_color_rgb(150, 110, 110));
                    draw_text(_list_x2 - 24, _ty2, "Enter: remove");
                    draw_set_halign(fa_left);
                } else {
                    draw_set_color(make_color_rgb(110, 110, 130));
                    draw_text(_list_x + 24, _ty2, "[ Empty Socket ]");
                    draw_set_halign(fa_right);
                    draw_set_color(make_color_rgb(120, 160, 120));
                    draw_text(_list_x2 - 24, _ty2, "Enter: add rune");
                    draw_set_halign(fa_left);
                }
            }
        } else {
            // phase 2 - choose a gear rune to socket
            var _gear = rune_inventory_indices("gear");
            draw_set_color(make_color_rgb(140, 130, 165));
            draw_text(_list_x, 225, "Choose a gear rune to socket:");
            if (array_length(_gear) == 0) {
                draw_set_color(make_color_rgb(120, 115, 140));
                draw_text(_list_x, _row_y0 + 12, "No gear runes in inventory.");
            }
            for (var _g = 0; _g < array_length(_gear); _g++) {
                var _rn = global.rune_inventory[_gear[_g]];
                var _ty3 = ui_maren_row(_g, _g == _cursor);
                draw_set_color(make_color_rgb(150, 200, 255));
                draw_text(_list_x + 24, _ty3, rune_describe(_rn));
            }
        }
    } else if (_gc.maren_tab == 1) {
        // -------- ASPECTS TAB (character Aspect slots) --------
        var _slots_n = variable_global_exists("aspect_slots") ? global.aspect_slots : 2;
        var _socked  = variable_global_exists("aspect_runes") ? global.aspect_runes : [];
        var _cap     = aspect_slot_cap();

        if (_gc.maren_phase == 0) {
            draw_set_color(make_color_rgb(140, 130, 165));
            draw_text(_list_x, 225, "Aspect slots (" + string(array_length(_socked)) + " / " + string(_slots_n) + " filled). Buff action categories in combat.");
            draw_text(_list_x, 252, "Enter a filled slot to remove its rune, an empty slot to add one.");

            // One row per unlocked slot, then an optional unlock row.
            for (var _s = 0; _s < _slots_n; _s++) {
                var _tya = ui_maren_row(_s, _s == _cursor);
                if (_s < array_length(_socked)) {
                    draw_set_color(make_color_rgb(230, 200, 120));
                    draw_text(_list_x + 24, _tya, rune_describe(_socked[_s]));
                    draw_set_halign(fa_right);
                    draw_set_color(make_color_rgb(150, 110, 110));
                    draw_text(_list_x2 - 24, _tya, "Enter: remove");
                    draw_set_halign(fa_left);
                } else {
                    draw_set_color(make_color_rgb(110, 110, 130));
                    draw_text(_list_x + 24, _tya, "[ Empty Aspect Slot ]");
                    draw_set_halign(fa_right);
                    draw_set_color(make_color_rgb(120, 160, 120));
                    draw_text(_list_x2 - 24, _tya, "Enter: add aspect rune");
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
                draw_text(_list_x + 24, _tyu, "[ Unlock +1 Aspect Slot ]");
                draw_set_halign(fa_right);
                draw_set_color(make_color_rgb(200, 180, 130));
                draw_text(_list_x2 - 24, _tyu, string(_cost.gold) + "g  +  " + string(_cost.dust) + " Dust");
                draw_set_halign(fa_left);
            }
        } else {
            // phase 1 - choose an aspect rune to socket
            var _asp = rune_inventory_indices("aspect");
            draw_set_color(make_color_rgb(140, 130, 165));
            draw_text(_list_x, 225, "Choose an aspect rune to socket:");
            if (array_length(_asp) == 0) {
                draw_set_color(make_color_rgb(120, 115, 140));
                draw_text(_list_x, _row_y0 + 12, "No aspect runes in inventory.");
            }
            for (var _a = 0; _a < array_length(_asp); _a++) {
                var _rna = global.rune_inventory[_asp[_a]];
                var _tya2 = ui_maren_row(_a, _a == _cursor);
                draw_set_color(make_color_rgb(230, 200, 120));
                draw_text(_list_x + 24, _tya2, rune_describe(_rna));
            }
        }
    } else if (_gc.maren_tab == 2) {
        // -------- FORGE TAB (Combine / Split / Craft Flagship) --------
        if (_gc.maren_phase == 0) {
            draw_set_color(make_color_rgb(140, 130, 165));
            draw_text(_list_x, 225, "Maren's Forge - reshape your runes.");
            var _menu = ["Combine   (3 identical  ->  1 next tier)",
                         "Split   (1 rune  ->  one tier lower  +  dust)",
                         "Craft Flagship   (forge a rare Quickcast / Echo)"];
            for (var _fm = 0; _fm < 3; _fm++) {
                var _tyf = ui_maren_row(_fm, _fm == _cursor);
                draw_set_color(make_color_rgb(210, 190, 240));
                draw_text(_list_x + 24, _tyf, _menu[_fm]);
            }
        } else if (_gc.maren_phase == 1) {
            // Combine: 3-of-a-kind groups
            var _groups = rune_combine_groups();
            draw_set_color(make_color_rgb(140, 130, 165));
            draw_text(_list_x, 225, "Combine - choose a set of three to fuse:");
            if (array_length(_groups) == 0) {
                draw_set_color(make_color_rgb(120, 115, 140));
                draw_text(_list_x, _row_y0 + 12, "No 3-of-a-kind runes (same type AND tier) available.");
            }
            for (var _gi = 0; _gi < array_length(_groups); _gi++) {
                var _grp  = _groups[_gi];
                var _ccst = rune_combine_cost(_grp.tier);
                var _tyc  = ui_maren_row(_gi, _gi == _cursor);
                var _caff = (global.gold >= _ccst.gold) && (_dust >= _ccst.dust);
                draw_set_color(_caff ? make_color_rgb(150, 200, 255) : make_color_rgb(120, 110, 130));
                draw_text(_list_x + 24, _tyc,
                    "3x " + _grp.name + " " + rune_tier_roman(_grp.tier)
                    + "  ->  " + _grp.name + " " + rune_tier_roman(_grp.tier + 1)
                    + "   (have " + string(_grp.count) + ")");
                draw_set_halign(fa_right);
                draw_set_color(make_color_rgb(200, 180, 130));
                draw_text(_list_x2 - 24, _tyc, string(_ccst.gold) + "g  +  " + string(_ccst.dust) + " Dust");
                draw_set_halign(fa_left);
            }
        } else if (_gc.maren_phase == 2) {
            // Split: any owned rune
            draw_set_color(make_color_rgb(140, 130, 165));
            draw_text(_list_x, 225, "Split - choose a rune to break down (" + string(rune_split_cost().gold) + "g):");
            if (array_length(global.rune_inventory) == 0) {
                draw_set_color(make_color_rgb(120, 115, 140));
                draw_text(_list_x, _row_y0 + 12, "No runes to split.");
            }
            for (var _si = 0; _si < array_length(global.rune_inventory); _si++) {
                var _sr  = global.rune_inventory[_si];
                var _tys = ui_maren_row(_si, _si == _cursor);
                draw_set_color(make_color_rgb(150, 200, 255));
                draw_text(_list_x + 24, _tys, rune_describe(_sr));
                draw_set_halign(fa_right);
                draw_set_color(make_color_rgb(200, 180, 130));
                var _db = rune_split_dust(_sr.tier);
                var _yield = (_sr.tier > 1)
                    ? (_sr.name + " " + rune_tier_roman(_sr.tier - 1) + "  +  " + string(_db) + " Dust")
                    : (string(_db) + " Dust");
                draw_text(_list_x2 - 24, _tys, "->  " + _yield);
                draw_set_halign(fa_left);
            }
        } else {
            // Craft Flagship
            var _flags = rune_flagship_ids();
            var _fc    = flagship_craft_cost();
            draw_set_color(make_color_rgb(140, 130, 165));
            draw_text(_list_x, 225, "Craft Flagship - forge a tier III rune (" + string(_fc.gold) + "g  +  " + string(_fc.dust) + " Dust):");
            var _faff = (global.gold >= _fc.gold) && (_dust >= _fc.dust);
            for (var _fi = 0; _fi < array_length(_flags); _fi++) {
                var _fdef = rune_get(_flags[_fi]);
                var _tyfl = ui_maren_row(_fi, _fi == _cursor);
                draw_set_color(_faff ? make_color_rgb(230, 200, 120) : make_color_rgb(120, 110, 130));
                draw_text(_list_x + 24, _tyfl, _fdef.name + " III - " + _fdef.blurb);
            }
        }
    } else {
        // -------- RUNES TAB (read-only owned list) --------
        draw_set_color(make_color_rgb(140, 130, 165));
        draw_text(_list_x, 225, "Runes owned (" + string(array_length(global.rune_inventory)) + "):");
        if (array_length(global.rune_inventory) == 0) {
            draw_set_color(make_color_rgb(120, 115, 140));
            draw_text(_list_x, _row_y0 + 12, "No runes yet. Elites and bosses drop them.");
        }
        for (var _r = 0; _r < array_length(global.rune_inventory); _r++) {
            var _rn2  = global.rune_inventory[_r];
            var _def2 = rune_get(_rn2.id);
            var _aspect = (_def2 != undefined && _def2.domain == "aspect");
            var _ty4 = ui_maren_row(_r, _r == _cursor);
            draw_set_color(_aspect ? make_color_rgb(230, 200, 120) : make_color_rgb(150, 200, 255));
            draw_text(_list_x + 24, _ty4, rune_describe(_rn2));
            draw_set_halign(fa_right);
            draw_set_color(make_color_rgb(130, 125, 150));
            draw_text(_list_x2 - 24, _ty4, _aspect ? "Aspect" : "Gear");
            draw_set_halign(fa_left);
        }
    }

    // Notification line
    if (_gc.maren_notification != "") {
        draw_set_halign(fa_center);
        draw_set_font(fnt_ui);
        draw_set_color(make_color_rgb(220, 200, 150));
        draw_text(960, 999, _gc.maren_notification);
        draw_set_halign(fa_left);
    }

    // Controls hint (raised to clear the bottom rim band)
    draw_set_halign(fa_center);
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(70, 70, 95));
    draw_text_outline(960, 1026, "W/S: Navigate    Q/E: Tab    Enter: Select    Esc: Back / Close");
    draw_set_halign(fa_left);

    // Ornate gothic rim around the whole overlay. Opening (30,30)-(1890,1050) keeps the
    // band fully on-screen while containing the title, currency, tabs and content. Drawn
    // last so it sits on top.
    ui_draw_gothic_frame(30, 30, 1890, 1050, 30);

    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
    draw_set_font(-1);
}

// ---------------------------------------------------------------------------
// ui_draw_sable_screen()
// Sable the Alchemist - Salvage / Brew / Upgrade overlay. Reuses ui_maren_row
// for row geometry. Layout constants MUST match the Sable input block in
// obj_game_controller Step. (Tabs at x=345+t*200, mirroring Maren's 3-tab bar.)
// ---------------------------------------------------------------------------
function ui_draw_sable_screen() {
    if (!instance_exists(obj_game_controller)) return;
    var _gc = instance_find(obj_game_controller, 0);
    if (!variable_instance_exists(_gc, "sable_open") || !_gc.sable_open) return;

    draw_set_alpha(1.0);
    draw_set_color(make_color_rgb(10, 14, 12));
    draw_rectangle(0, 0, GUI_W, GUI_H, false);

    // Title + dust
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_font(fnt_ui_title);
    draw_set_color(make_color_rgb(150, 210, 170));
    draw_text(960, 36, "Sable the Alchemist");
    draw_set_halign(fa_right);
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(200, 180, 130));
    var _dust = variable_global_exists("rune_dust") ? global.rune_dust : 0;
    draw_text(1860, 48, "Rune Dust: " + string(_dust) + "    Gold: " + string(global.gold));
    draw_set_halign(fa_left);

    // Tab bar (4 tabs) - x=518+t*300, y=105, w=285
    var _tab_labels = ["Salvage", "Brew", "Upgrade", "Rebirth"];
    draw_set_font(fnt_ui);
    for (var _t = 0; _t < 4; _t++) {
        var _tx = 518 + _t * 300;
        var _on = (_gc.sable_tab == _t);
        draw_set_color(_on ? make_color_rgb(30, 50, 38) : make_color_rgb(20, 28, 24));
        draw_rectangle(_tx, 105, _tx + 285, 165, false);
        draw_set_color(_on ? make_color_rgb(110, 200, 140) : make_color_rgb(50, 70, 58));
        draw_rectangle(_tx, 105, _tx + 285, 165, true);
        draw_set_halign(fa_center);
        draw_set_valign(fa_middle);
        draw_set_color(_on ? c_white : make_color_rgb(150, 160, 150));
        draw_text(_tx + 143, 135, _tab_labels[_t]);
    }
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_font(fnt_ui);

    var _row_y0 = 285;
    var _list_x = 300;
    var _list_x2 = 1620;
    var _cursor = _gc.sable_cursor;

    if (_gc.sable_tab == 0) {
        // -------- SALVAGE TAB --------
        if (_gc.sable_phase == 0) {
            draw_set_color(make_color_rgb(140, 160, 145));
            draw_text(_list_x, 225, "Salvage unwanted loot into rune dust:");
            var _menu = ["Salvage Gear   (unequipped pack + stash)",
                         "Salvage Runes   (unsocketed - fully scrapped)"];
            for (var _sm = 0; _sm < 2; _sm++) {
                var _tys = ui_maren_row(_sm, _sm == _cursor);
                draw_set_color(make_color_rgb(190, 220, 195));
                draw_text(_list_x + 24, _tys, _menu[_sm]);
            }
        } else if (_gc.sable_phase == 1) {
            // Gear list
            var _gear = sable_salvageable_gear();
            draw_set_color(make_color_rgb(140, 160, 145));
            draw_text(_list_x, 225, "Choose gear to salvage (Common 1 / Uncommon 2 / Rare 5 / Epic 10 / Legendary 20):");
            if (array_length(_gear) == 0) {
                draw_set_color(make_color_rgb(120, 130, 122));
                draw_text(_list_x, _row_y0 + 12, "No unequipped gear to salvage.");
            }
            for (var _gi = 0; _gi < array_length(_gear); _gi++) {
                var _it  = _gear[_gi].item;
                var _tyg = ui_maren_row(_gi, _gi == _cursor);
                draw_set_color(item_rarity_color(_it.rarity));
                draw_text(_list_x + 24, _tyg, _it.name + "  (" + item_rarity_name(_it.rarity) + ")");
                draw_set_halign(fa_right);
                draw_set_color(make_color_rgb(200, 180, 130));
                draw_text(_list_x2 - 24, _tyg, "+" + string(sable_salvage_gear_dust(_it.rarity)) + " Dust  [" + _gear[_gi].source + "]");
                draw_set_halign(fa_left);
            }
        } else {
            // Rune list
            draw_set_color(make_color_rgb(140, 160, 145));
            draw_text(_list_x, 225, "Choose a rune to scrap for dust (I 6 / II 16 / III 40):");
            var _rinv = variable_global_exists("rune_inventory") ? global.rune_inventory : [];
            if (array_length(_rinv) == 0) {
                draw_set_color(make_color_rgb(120, 130, 122));
                draw_text(_list_x, _row_y0 + 12, "No unsocketed runes to scrap.");
            }
            for (var _ri = 0; _ri < array_length(_rinv); _ri++) {
                var _rn  = _rinv[_ri];
                var _tyr = ui_maren_row(_ri, _ri == _cursor);
                var _def = rune_get(_rn.id);
                var _asp = (_def != undefined && _def.domain == "aspect");
                draw_set_color(_asp ? make_color_rgb(230, 200, 120) : make_color_rgb(150, 200, 255));
                draw_text(_list_x + 24, _tyr, rune_describe(_rn));
                draw_set_halign(fa_right);
                draw_set_color(make_color_rgb(200, 180, 130));
                draw_text(_list_x2 - 24, _tyr, "+" + string(sable_salvage_rune_dust(_rn.tier)) + " Dust");
                draw_set_halign(fa_left);
            }
        }
    } else if (_gc.sable_tab == 1) {
        // -------- BREW TAB --------
        var _brew = sable_brew_catalog();
        var _slots_used = variable_global_exists("consumable_inventory") ? array_length(global.consumable_inventory) : 0;
        draw_set_color(make_color_rgb(140, 160, 145));
        draw_text(_list_x, 225, "Brew a potion  (you hold " + string(_slots_used) + " consumables):");
        for (var _bi = 0; _bi < array_length(_brew); _bi++) {
            var _b   = _brew[_bi];
            var _tyb = ui_maren_row(_bi, _bi == _cursor);
            var _aff = (global.gold >= _b.gold) && (_dust >= _b.dust);
            draw_set_color(_aff ? make_color_rgb(190, 220, 195) : make_color_rgb(120, 130, 122));
            draw_text(_list_x + 24, _tyb, _b.name + "  -  " + _b.desc);
            draw_set_halign(fa_right);
            draw_set_color(make_color_rgb(200, 180, 130));
            draw_text(_list_x2 - 24, _tyb, string(_b.gold) + "g  +  " + string(_b.dust) + " Dust");
            draw_set_halign(fa_left);
        }
    } else if (_gc.sable_tab == 2) {
        // -------- UPGRADE TAB --------
        var _groups = sable_upgrade_groups();
        var _ucost = sable_upgrade_cost();
        draw_set_color(make_color_rgb(140, 160, 145));
        draw_text(_list_x, 225, "Fuse 3 identical potions into their improved form (" + string(_ucost.gold) + "g + " + string(_ucost.dust) + " Dust):");
        if (array_length(_groups) == 0) {
            draw_set_color(make_color_rgb(120, 130, 122));
            draw_text(_list_x, _row_y0 + 12, "No potion held 3+ times with an upgrade. (Standard potions only.)");
        }
        for (var _ui = 0; _ui < array_length(_groups); _ui++) {
            var _g   = _groups[_ui];
            var _tyu = ui_maren_row(_ui, _ui == _cursor);
            var _uaff = (global.gold >= _ucost.gold) && (_dust >= _ucost.dust);
            draw_set_color(_uaff ? make_color_rgb(190, 220, 195) : make_color_rgb(120, 130, 122));
            draw_text(_list_x + 24, _tyu, "3x " + _g.from + "  ->  " + _g.to + "   (have " + string(_g.count) + ")");
        }
    } else {
        // -------- REBIRTH TAB --------
        var _reb = item_picker_candidates_class_specific();
        draw_set_color(make_color_rgb(140, 160, 145));
        draw_text(_list_x, 225, "Alchemical Rebirth - reforge a class-locked item into a different class's item:");
        // Cost reference
        draw_set_color(make_color_rgb(120, 140, 128));
        draw_text(_list_x, 264, "Cost by rarity: Uncommon 3 Dust + 120g    Rare 6 Dust + 250g    Epic 10 Dust + 500g");
        draw_text(_list_x, 300, "Sacrifices the chosen item; result is a random different-class item of the same slot & rarity.");

        // Rebirth has a 3-line blurb (y225/264/300); push its row below it so the box
        // doesn't land on the cost/sacrifice lines (the other tabs use the default 285).
        var _tyr0 = ui_maren_row(0, 0 == _cursor, 339);
        if (array_length(_reb) == 0) {
            draw_set_color(make_color_rgb(120, 130, 122));
            draw_text(_list_x + 24, _tyr0, "No class-specific gear (Uncommon+) in your stash or pack.");
        } else {
            draw_set_color(make_color_rgb(190, 220, 195));
            draw_text(_list_x + 24, _tyr0, "Reforge a class item...   (" + string(array_length(_reb)) + " eligible)   [Enter]");
        }
    }

    // Notification
    if (_gc.sable_notification != "") {
        draw_set_halign(fa_center);
        draw_set_font(fnt_ui);
        draw_set_color(make_color_rgb(180, 220, 160));
        draw_text(960, 999, _gc.sable_notification);
        draw_set_halign(fa_left);
    }

    // Controls hint (raised to clear the bottom rim band)
    draw_set_halign(fa_center);
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(70, 95, 78));
    draw_text_outline(960, 1026, "W/S: Navigate    Q/E: Tab    Enter: Select    Esc: Back / Close");
    draw_set_halign(fa_left);

    // Ornate gothic rim around the whole overlay (see Maren screen for geometry notes).
    ui_draw_gothic_frame(30, 30, 1890, 1050, 30);

    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
    draw_set_font(-1);
}

// ---------------------------------------------------------------------------
// ui_draw_vael_screen()
// Vael the Aesthete - transmog/skin selection overlay. Single list of skins with
// a live preview of the highlighted skin. Reuses ui_maren_row for row geometry.
// Layout constants MUST match the Vael input block in obj_game_controller Step.
// ---------------------------------------------------------------------------
function ui_draw_vael_screen() {
    if (!instance_exists(obj_game_controller)) return;
    var _gc = instance_find(obj_game_controller, 0);
    if (!variable_instance_exists(_gc, "vael_open") || !_gc.vael_open) return;

    draw_set_alpha(1.0);
    draw_set_color(make_color_rgb(16, 12, 18));
    draw_rectangle(0, 0, GUI_W, GUI_H, false);

    // Title + gold
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_font(fnt_ui_title);
    draw_set_color(make_color_rgb(210, 170, 230));
    draw_text(960, 36, "Vael the Aesthete");
    draw_set_halign(fa_right);
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(230, 210, 150));
    draw_text(1860, 48, "Gold: " + string(global.gold));
    draw_set_halign(fa_left);

    // --- Tabs: Skins | Portrait (geometry MUST match the Vael input block) ---
    var _vtab = variable_instance_exists(_gc, "vael_tab") ? _gc.vael_tab : 0;
    var _vtab_names = ["Skins", "Portrait"];
    draw_set_font(fnt_ui);
    for (var _vt = 0; _vt < 2; _vt++) {
        var _vtx   = 840 + _vt * 240;
        var _vt_on = (_vt == _vtab);
        draw_set_color(_vt_on ? make_color_rgb(60, 46, 86) : make_color_rgb(26, 22, 34));
        draw_rectangle(_vtx - 108, 87, _vtx + 108, 135, false);
        draw_set_color(_vt_on ? make_color_rgb(160, 120, 230) : make_color_rgb(60, 54, 78));
        draw_rectangle(_vtx - 108, 87, _vtx + 108, 135, true);
        draw_set_halign(fa_center);
        draw_set_color(_vt_on ? c_white : make_color_rgb(150, 140, 165));
        draw_text(_vtx, 99, _vtab_names[_vt]);
        draw_set_halign(fa_left);
    }

    // The Portrait tab is self-contained - draw it and return early, so the skins
    // list + detail panel below only run for tab 0.
    if (_vtab == 1) {
        ui_draw_vael_portrait_tab(_gc);
        return;
    }

    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(160, 140, 175));
    draw_text(300, 165, "Transmog - change your combat look. Owned skins switch freely; locked skins need a milestone.");

    var _catalog = vael_skin_catalog();
    var _count   = array_length(_catalog);
    var _cursor  = clamp(_gc.vael_cursor, 0, _count - 1);
    var _active  = variable_global_exists("player_skin") ? global.player_skin : "default";

    // Windowed list (left column, x200..800). Scroll derivation MUST match the Vael
    // input block in obj_game_controller Step (vael_list_scroll).
    var _vis    = 11;
    var _scroll = vael_list_scroll(_cursor, _count, _vis);
    var _list_y = 225;
    var _row_h  = 72;

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
        draw_rectangle(300, _ry, 1200, _ry + 66, false);
        draw_set_color(_is_cur ? make_color_rgb(150, 110, 220) : make_color_rgb(45, 42, 62));
        draw_rectangle(300, _ry, 1200, _ry + 66, true);
        var _ty = _ry + 15;

        // Mini swatch (guard missing art -> small placeholder dot) - normalised to a
        // ~51px icon centred in the row's swatch box, accounting for top-left origin.
        if (_sk.sprite != undefined && _sk.sprite != -1 && sprite_exists(_sk.sprite)) {
            var _sw_sc = 51 / max(1, sprite_get_height(_sk.sprite));
            var _sw_w  = sprite_get_width(_sk.sprite)  * _sw_sc;
            var _sw_h  = sprite_get_height(_sk.sprite) * _sw_sc;
            draw_sprite_ext(_sk.sprite, player_sprite_frame(_sk.sprite), 345 - _sw_w / 2, (_ry + 33) - _sw_h / 2, _sw_sc, _sw_sc, 0, c_white, _unlocked ? 1 : 0.4);
        } else if (_sk.sprite != undefined) {
            draw_set_color(make_color_rgb(40, 38, 55));
            draw_rectangle(324, _ry + 12, 366, _ry + 54, false);
        }

        // Name (+ gender marker), greyed if locked
        var _name_col = _equipped ? make_color_rgb(180, 240, 180)
                      : (_unlocked ? (_owned ? make_color_rgb(210, 200, 220) : make_color_rgb(195, 185, 205))
                                   : make_color_rgb(120, 112, 132));
        draw_set_font(fnt_ui);
        draw_set_color(_name_col);
        var _gtag = (variable_struct_exists(_sk, "gender") && _sk.gender == "f") ? " (F)"
                  : ((variable_struct_exists(_sk, "gender") && _sk.gender == "m") ? "" : "");
        draw_text(387, _ty, _sk.name + _gtag);

        // Right-side short status
        draw_set_halign(fa_right);
        draw_set_font(fnt_ui_small);
        if (_equipped) {
            draw_set_color(make_color_rgb(150, 230, 150)); draw_text(1185, _ty, "EQUIPPED");
        } else if (_owned) {
            draw_set_color(make_color_rgb(160, 200, 240)); draw_text(1185, _ty, "OWNED");
        } else if (!_unlocked) {
            draw_set_color(make_color_rgb(150, 110, 120)); draw_text(1185, _ty, "LOCKED");
        } else {
            draw_set_color((global.gold >= _sk.gold) ? make_color_rgb(230, 210, 150) : make_color_rgb(170, 120, 120));
            draw_text(1185, _ty, string(_sk.gold) + "g");
        }
        draw_set_halign(fa_left);
    }

    // Scroll indicator
    if (_count > _vis) {
        draw_set_halign(fa_center);
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(110, 95, 130));
        draw_text(750, _list_y + _vis * _row_h + 3,
            string(_scroll + 1) + "-" + string(min(_scroll + _vis, _count)) + " of " + string(_count) + "   (W/S)");
        draw_set_halign(fa_left);
    }

    // ----- Detail / preview panel (right, x1260..1875) -----
    var _sel = _catalog[_cursor];
    var _sel_unlocked = vael_skin_unlocked(_sel);
    draw_set_color(make_color_rgb(18, 14, 22));
    draw_rectangle(1260, 225, 1875, 930, false);
    draw_set_color(make_color_rgb(70, 55, 90));
    draw_rectangle(1260, 225, 1875, 930, true);

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
        // canvas sizes (92-108px), so scale to a target height and offset by half.
        var _pv_cx = 1568, _pv_cy = 525;
        var _pv_sc = 315 / max(1, sprite_get_height(_prev_spr));
        var _pv_w  = sprite_get_width(_prev_spr)  * _pv_sc;
        var _pv_h  = sprite_get_height(_prev_spr) * _pv_sc;
        draw_sprite_ext(_prev_spr, player_sprite_frame(_prev_spr), _pv_cx - _pv_w / 2, _pv_cy - _pv_h / 2, _pv_sc, _pv_sc, 0, c_white, _sel_unlocked ? 1 : 0.45);
    } else {
        draw_set_halign(fa_center);
        draw_set_font(fnt_ui);
        draw_set_color(make_color_rgb(90, 80, 105));
        draw_text(1568, 525, "(art pending)");
        draw_set_halign(fa_left);
    }

    // Name + gender
    draw_set_halign(fa_center);
    draw_set_font(fnt_ui);
    draw_set_color(make_color_rgb(225, 205, 235));
    draw_text(1568, 705, _sel.name);
    draw_set_halign(fa_left);

    // Description
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(150, 140, 165));
    draw_text_ext(1293, 753, _sel.desc, -1, 549);

    // Status / requirement line
    draw_set_halign(fa_center);
    draw_set_font(fnt_ui);
    if (_sel.id == _active) {
        draw_set_color(make_color_rgb(150, 230, 150)); draw_text(1568, 882, "Equipped");
    } else if (vael_skin_owned(_sel.id)) {
        draw_set_color(make_color_rgb(160, 200, 240)); draw_text(1568, 882, "Owned - Enter to wear");
    } else if (!_sel_unlocked) {
        draw_set_color(make_color_rgb(220, 130, 130)); draw_text(1568, 882, "Locked - " + vael_skin_req_text(_sel));
    } else {
        draw_set_color((global.gold >= _sel.gold) ? make_color_rgb(230, 210, 150) : make_color_rgb(190, 130, 130));
        draw_text(1568, 882, string(_sel.gold) + "g - Enter to buy");
    }
    draw_set_halign(fa_left);

    // Notification
    if (_gc.vael_notification != "") {
        draw_set_halign(fa_center);
        draw_set_font(fnt_ui);
        draw_set_color(make_color_rgb(220, 190, 230));
        draw_text(960, 999, _gc.vael_notification);
        draw_set_halign(fa_left);
    }

    // Controls hint (raised to clear the bottom rim band)
    draw_set_halign(fa_center);
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(90, 75, 100));
    draw_text_outline(960, 1026, "W/S: Navigate    Enter: Buy / Wear    Q/E: Switch tab    Esc: Close");
    draw_set_halign(fa_left);

    // Ornate gothic rim around the whole overlay (see Maren screen for geometry notes).
    // The skin detail panel (x1260..1875) sits inside the opening; the rim band is outside.
    ui_draw_gothic_frame(30, 30, 1890, 1050, 30);

    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
    draw_set_font(-1);
}

// ---------------------------------------------------------------------------
// ui_draw_vael_portrait_tab(gc)
// Portrait tab of the Vael overlay - a carousel over global.portrait_sprites.
// Changing to a NEW portrait costs 100g (charged in the Vael input block in
// obj_game_controller Step). Title/gold/tabs are already drawn by the caller.
// ---------------------------------------------------------------------------
function ui_draw_vael_portrait_tab(_gc) {
    var _ports  = global.portrait_sprites;
    var _pcount = array_length(_ports);
    if (_pcount <= 0) return;
    var _cur    = clamp(_gc.vael_portrait_cursor, 0, _pcount - 1);
    var _active = clamp(variable_global_exists("chosen_portrait") ? global.chosen_portrait : 0, 0, _pcount - 1);

    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(160, 140, 175));
    draw_set_halign(fa_center);
    draw_text(960, 165, "Choose a new portrait. Switching to a different one costs 100g.");

    // Center portrait (large)
    var _main_w = 450, _main_h = 450;
    var _main_x = GUI_CX - _main_w / 2;
    var _main_y = 252;
    draw_set_color(make_color_rgb(18, 14, 22));
    draw_rectangle(_main_x - 6, _main_y - 6, _main_x + _main_w + 6, _main_y + _main_h + 6, false);
    draw_sprite_stretched(_ports[_cur], 0, _main_x, _main_y, _main_w, _main_h);
    draw_set_color((_cur == _active) ? make_color_rgb(150, 230, 150) : make_color_rgb(160, 120, 230));
    draw_rectangle(_main_x - 6, _main_y - 6, _main_x + _main_w + 6, _main_y + _main_h + 6, true);
    ui_draw_gothic_frame(_main_x - 6, _main_y - 6, _main_x + _main_w + 6, _main_y + _main_h + 6, 33);   // ornate portrait frame

    // Side thumbnails (prev / next), dimmed
    if (_pcount > 1) {
        var _thumb_w = 180, _thumb_h = 180, _thumb_y = _main_y + 135;
        var _prev = (_cur - 1 + _pcount) mod _pcount;
        var _next = (_cur + 1) mod _pcount;
        draw_sprite_stretched_ext(_ports[_prev], 0, _main_x - _thumb_w - 42, _thumb_y, _thumb_w, _thumb_h, c_white, 0.5);
        draw_sprite_stretched_ext(_ports[_next], 0, _main_x + _main_w + 42, _thumb_y, _thumb_w, _thumb_h, c_white, 0.5);
    }

    // Counter
    draw_set_font(fnt_ui);
    draw_set_color(make_color_rgb(180, 165, 195));
    draw_text(960, _main_y + _main_h + 24, string(_cur + 1) + " / " + string(_pcount));

    // Status / confirm line
    if (_cur == _active) {
        draw_set_color(make_color_rgb(150, 230, 150));
        draw_text(960, _main_y + _main_h + 69, "Your current portrait");
    } else if (global.gold >= 100) {
        draw_set_color(make_color_rgb(230, 210, 150));
        draw_text(960, _main_y + _main_h + 69, "100g  -  Enter to set as your portrait");
    } else {
        draw_set_color(make_color_rgb(190, 130, 130));
        draw_text(960, _main_y + _main_h + 69, "Not enough gold (need 100g)");
    }

    // Notification
    if (_gc.vael_notification != "") {
        draw_set_font(fnt_ui);
        draw_set_color(make_color_rgb(220, 190, 230));
        draw_text(960, 999, _gc.vael_notification);
    }

    // Controls (raised to clear the bottom rim band)
    draw_set_font(fnt_ui_small);
    draw_set_color(make_color_rgb(90, 75, 100));
    draw_text_outline(960, 1026, "A/D: Browse    Q/E: Switch tab    Enter: Set (100g)    Esc: Close");
    draw_set_halign(fa_left);

    // Ornate gothic rim around the whole overlay (matches the skins tab + Maren/Sable).
    ui_draw_gothic_frame(30, 30, 1890, 1050, 30);

    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
    draw_set_font(-1);
}

// Stateless scroll window for the Vael skin list - shared by draw + input so the
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

    // Geometry - MUST stay in sync with item_picker_step() hit-testing (scr_stats).
    var _px = 330, _py = 165, _pw = 1260, _ph = 750;
    // Left list column.
    var _lx0 = _px + 24;            // row highlight left edge
    var _lx1 = _px + 606;           // row highlight right edge
    var _ly0 = _py + 129;           // first row top
    var _rh  = 57;                  // row pitch
    // Right detail pane.
    var _dvx = _px + 624;           // divider x
    var _dx  = _px + 648;           // detail content left
    var _dr  = _px + _pw - 30;      // detail content right
    // Confirm/footer band.
    var _cby0 = _py + _ph - 114, _cby1 = _py + _ph - 60;

    // Dim the whole screen, then the panel.
    draw_set_alpha(0.6); draw_set_color(c_black);
    draw_rectangle(0, 0, display_get_gui_width(), display_get_gui_height(), false);
    draw_set_alpha(0.97); draw_set_color(make_color_rgb(22, 22, 34));
    draw_rectangle(_px, _py, _px + _pw, _py + _ph, false);
    draw_set_alpha(1.0); draw_set_color(make_color_rgb(150, 150, 180));
    draw_rectangle(_px, _py, _px + _pw, _py + _ph, true);

    // Header
    draw_set_halign(fa_center); draw_set_valign(fa_top);
    draw_set_font(fnt_ui);
    draw_set_color(make_color_rgb(255, 225, 150));
    draw_text(_px + _pw / 2, _py + 21, item_picker_prompt());
    draw_set_font(fnt_ui_small);
    draw_set_color(c_ltgray);
    draw_text(_px + _pw / 2, _py + 63, "(only items you didn't pick are safe - nothing is lost until you confirm)");
    draw_set_halign(fa_left);

    if (_n == 0) {
        draw_set_halign(fa_center);
        draw_set_font(fnt_ui);
        draw_set_color(make_color_rgb(220, 120, 120));
        draw_text(_px + _pw / 2, _py + _ph / 2, "No qualifying item to give up.");
        draw_set_font(fnt_ui_small);
        draw_set_color(c_ltgray);
        draw_text_outline(_px + _pw / 2, _py + _ph - 45, "Esc / Right-click: back");
        draw_set_halign(fa_left); draw_set_valign(fa_top);
        draw_set_font(-1);
        return;
    }

    // Vertical divider between list and detail pane.
    draw_set_color(make_color_rgb(60, 64, 86));
    draw_line(_dvx, _py + 114, _dvx, _cby0 - 12);

    // --- Left: windowed list of 8 rows (icon + name + value) -----------------
    draw_set_font(fnt_ui_small);
    var _vis = min(8, _n);
    for (var _r = 0; _r < _vis; _r++) {
        var _idx = _p.scroll + _r;
        if (_idx >= _n) break;
        var _c  = _p.candidates[_idx];
        var _ry = _ly0 + _r * _rh;
        if (_idx == _p.cursor) {
            draw_set_alpha(0.30); draw_set_color(make_color_rgb(90, 110, 160));
            draw_rectangle(_lx0, _ry, _lx1, _ry + 51, false);
            draw_set_alpha(1.0);
            draw_set_color(make_color_rgb(120, 150, 210));
            draw_rectangle(_lx0, _ry, _lx1, _ry + 51, true);
        }
        // Small inline icon.
        if (is_struct(_c.item)) ui_draw_item_icon(_lx0 + 6, _ry + 5, 42, _c.item);
        draw_set_halign(fa_left); draw_set_valign(fa_top);
        draw_set_color(item_rarity_color(_c.rarity));
        draw_text(_lx0 + 60, _ry + 12, _c.label);
        draw_set_halign(fa_right); draw_set_color(c_ltgray);
        draw_text(_lx1 - 12, _ry + 12, string(_c.value) + "g");
        draw_set_halign(fa_left);
    }
    // Scroll hints
    if (_p.scroll > 0) {
        draw_set_halign(fa_center); draw_set_color(make_color_rgb(120, 140, 170));
        draw_text((_lx0 + _lx1) / 2, _ly0 - 27, "^ more");
    }
    if (_p.scroll + _vis < _n) {
        draw_set_halign(fa_center); draw_set_color(make_color_rgb(120, 140, 170));
        draw_text((_lx0 + _lx1) / 2, _ly0 + _vis * _rh + 3, "v more");
    }
    draw_set_halign(fa_left);

    // --- Right: detail pane for the selected item ----------------------------
    var _cur = _p.candidates[_p.cursor];
    var _it  = _cur.item;
    if (is_struct(_it)) {
        var _rar  = variable_struct_exists(_it, "rarity") ? _it.rarity : 0;
        var _rcol = item_rarity_color(_rar);
        var _dy   = _py + 129;

        // Big icon + name/rarity/slot header.
        ui_draw_item_icon(_dx, _dy, 96, _it);
        draw_set_halign(fa_left); draw_set_valign(fa_top);
        draw_set_font(fnt_ui);
        draw_set_color(_rcol);
        draw_text_ext(_dx + 114, _dy + 3, _it.name, -1, _dr - (_dx + 114));
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(150, 160, 185));
        draw_text(_dx + 114, _dy + 39, item_rarity_name(_rar));
        if (variable_struct_exists(_it, "slot")) {
            draw_set_color(make_color_rgb(110, 120, 150));
            draw_text(_dx + 114, _dy + 69, string_upper(_it.slot));
        }
        // Class restriction (gold = usable by your class, red = locked to another).
        var _pk_cr = variable_struct_exists(_it, "class_req") ? _it.class_req : -1;
        if (_pk_cr != -1) {
            var _pk_names = ["Arcanist", "Bloodwarden", "Shadowstrider"];
            var _pk_name  = (_pk_cr >= 0 && _pk_cr <= 2) ? _pk_names[_pk_cr] : "Unknown";
            var _pk_my    = variable_global_exists("chosen_class") ? global.chosen_class : -1;
            draw_set_color((_pk_cr == _pk_my) ? make_color_rgb(210, 175, 90) : make_color_rgb(225, 80, 80));
            draw_text(_dx + 114, _dy + 96, _pk_name + " only");
        }

        var _cy = _dy + 117;
        draw_set_color(make_color_rgb(50, 55, 80));
        draw_line(_dx, _cy, _dr, _cy);
        _cy += 12;

        // Full stat string (primary + affixes), wrapped.
        draw_set_font(fnt_ui_small);
        var _statstr = ui_item_stat_str(_it);
        draw_set_color(c_white);
        draw_text_ext(_dx, _cy, _statstr, -1, _dr - _dx);
        _cy += string_height_ext(_statstr, -1, _dr - _dx) + 9;

        // Stat requirement (red if the would-be wearer can't meet it). Shown here so the
        // equip gate is visible in the picker, not only on the loadout hover-tooltip.
        var _preq = item_stat_requirement(_it);
        if (_preq.value > 0 && _preq.stat != "") {
            var _reqstr = "Requires " + string(_preq.value) + " " + _preq.stat;
            draw_set_color((player_base_stat(_preq.stat) >= _preq.value)
                ? make_color_rgb(110, 170, 110) : make_color_rgb(225, 80, 80));
            draw_text_ext(_dx, _cy, _reqstr, -1, _dr - _dx);
            _cy += string_height_ext(_reqstr, -1, _dr - _dx) + 9;
        }

        // Unique effect.
        if (variable_struct_exists(_it, "unique_desc") && _it.unique_desc != "") {
            draw_set_color(make_color_rgb(255, 200, 50));
            draw_text_ext(_dx, _cy, _it.unique_desc, -1, _dr - _dx);
            _cy += string_height_ext(_it.unique_desc, -1, _dr - _dx) + 9;
        }

        // Flavor / description.
        var _flavor = "";
        if      (variable_struct_exists(_it, "effect_desc") && _it.effect_desc != "")
            _flavor = _it.effect_desc;
        else if (variable_struct_exists(_it, "description"))
            _flavor = _it.description;
        if (_flavor != "") {
            draw_set_color(make_color_rgb(110, 120, 145));
            draw_text_ext(_dx, _cy, _flavor, -1, _dr - _dx);
        }
        draw_set_valign(fa_top);
    }

    // --- Footer / confirm bar ------------------------------------------------
    if (_p.confirm) {
        draw_set_alpha(0.95); draw_set_color(make_color_rgb(120, 40, 40));
        draw_rectangle(_px + 30, _cby0, _px + _pw - 30, _cby1, false);
        draw_set_alpha(1.0);
        draw_set_halign(fa_center); draw_set_valign(fa_top);
        draw_set_font(fnt_ui_small); draw_set_color(c_white);
        draw_text(_px + _pw / 2, _cby0 + 14,
            item_picker_verb() + " " + _cur.label + "? This cannot be undone.");
        draw_set_color(c_ltgray);
        draw_text_outline(_px + _pw / 2, _py + _ph - 36, "Enter: confirm     Esc: back");
    } else {
        draw_set_halign(fa_center);
        draw_set_font(fnt_ui_small); draw_set_color(c_ltgray);
        draw_text_outline(_px + _pw / 2, _py + _ph - 36, "W/S: Select     Enter: choose     Esc: cancel");
    }

    draw_set_halign(fa_left); draw_set_valign(fa_top);
    draw_set_color(c_white); draw_set_alpha(1.0);
    draw_set_font(-1);
}

// =============================================================================
// obj_combat_controller - Draw GUI event
// Runs every frame after Step. Draws all combat visuals in order:
//   background -> enemy HP bars -> HUD -> result overlay -> restart input
// =============================================================================


// -----------------------------------------------------------------------------
// 1. BACKGROUND
// Themed per-floor combat arena if imported (lighter scrim - keeps the arena
// readable behind the enemy cluster); otherwise a flat dark fill so nothing from
// the room layer bleeds through the GUI.
// -----------------------------------------------------------------------------
if (!dungeon_bg_draw("combat", 0.30)) {
    draw_set_color(make_color_rgb(18, 18, 28));
    draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
}
// 2.5D volumetric props, FAR pass (round 6): wall sconces, back pillars,
// mid-depth dressing - drawn on the planes, behind every actor.
ui_draw_25d_props(0);

// Reset the hover-status tooltip each frame; the status icon rows (enemy bars +
// player buff row, drawn below) set it when the mouse is over a badge, and it's
// drawn after those rows so the popup lands on top. (Task: hover-explain debuffs.)
global.combat_status_tip = undefined;


// -----------------------------------------------------------------------------
// 2. ENEMY HP BARS (right side, stacked vertically)
// Defeated enemies are skipped so bars collapse upward as enemies fall.
// -----------------------------------------------------------------------------
// Enemy HP bars laid out in a 2-COLUMN grid (was a single 4-tall stack that
// collided with the enemy sprites). Fill left->right, top->bottom: each pair of
// foes starts a new row, so 4 enemies form a 2x2 block instead of one deep column.
var _bar_width   = 400;
var _bar_height  = 42;
// Columns spread wider apart so the LEFT-of-bar target reticle for the right
// column sits in a clear gutter instead of clipping the end of the left bar.
var _bar_col_x   = [990, 1485];   // the two column origins (x)
var _bar_row_y0  = 96;
var _bar_row_gap = 132;          // bar + status-icon row + intent chip per grid row
                                 // (was 108: a row's debuff badges + duration text ran
                                 // into the NEXT row's intent chip when stacked)

var _living_idx = 0;
var _count = array_length(combat_state.combatants);

// 2.5D round 9 (M: "enemy name plate and hp bar should correspond to its
// position - confusing when the forward mob is the farther away nameplate"):
// grid SLOTS are assigned by each foe's on-stage x-order (leftmost sprite ->
// leftmost plate, reading left-to-right like the line-up) instead of turn
// order. The bar keeps its living index (selection, taps, statuses ride along)
// - only which grid cell it draws in changes. Flat mode: turn order, shipped.
var _slot_of = [0, 1, 2, 3, 4, 5];
if (combat_25d()) {
    var _liv_sl  = combat_living_enemies(combat_state);
    var _n_liv   = array_length(_liv_sl);
    var _sl_cx   = array_create(_n_liv, 0);
    for (var _si = 0; _si < _n_liv; _si++) {
        var _slc = _liv_sl[_si];
        _sl_cx[_si] = variable_struct_exists(_slc, "stage_station")
                    ? _slc.stage_station.cx
                    : combat_enemy_slot_pos(_si).cx;
    }
    for (var _si = 0; _si < _n_liv; _si++) {
        var _rank = 0;
        for (var _sj = 0; _sj < _n_liv; _sj++) {
            if (_sl_cx[_sj] < _sl_cx[_si]
                || (_sl_cx[_sj] == _sl_cx[_si] && _sj < _si)) _rank++;
        }
        if (_si < array_length(_slot_of)) _slot_of[_si] = _rank;
    }
}

// Inspect-on-hover: the enemy under the cursor (its HP bar OR its sprite) gets an
// inspect tooltip drawn after the HUD. Capture the cursor + target here; the bar
// loop and the sprite loop below both test against it. (Task: enemy class clarity.)
var _mx_gui = device_mouse_x_to_gui(0);
var _my_gui = device_mouse_y_to_gui(0);
var _inspect_target = undefined;

for (var _i = 0; _i < _count; _i++) {
    var _c = combat_state.combatants[_i];
    if (_c.is_player)   continue;
    if (_c.is_defeated) continue;

    var _bar_slot = (_living_idx < array_length(_slot_of)) ? _slot_of[_living_idx] : _living_idx;
    var _bar_x = _bar_col_x[_bar_slot mod 2];
    var _bar_y = _bar_row_y0 + (_bar_slot div 2) * _bar_row_gap;

    if (_living_idx == selected_target) {
        // Small target reticle just LEFT of the bar - the SAME marker shown under the
        // selected foe's sprite (just smaller), so the highlighted name/HP bar and the
        // sprite read as one selection. The old ">" glyph was big and bled into the
        // adjacent column's bar; this is sized + centred to sit in the gutter cleanly.
        var _mk_sz = 32;   // doubled from 16 so the bar marker reads clearly
        var _mk_sc = (_mk_sz / max(1, sprite_get_width(spr_target_cursor)))
                   * (1 + 0.06 * sin(current_time / 180));   // same breathing pulse
        // Pushed a little further left so the larger marker still clears the bar.
        draw_sprite_ext(spr_target_cursor, 0, _bar_x - 22, _bar_y + _bar_height / 2,
                        _mk_sc, _mk_sc, current_time * 0.05, c_white, 0.95);
    }

    // Conveyance (08-04): the bar shows EASED HP - it drains toward the real
    // value over a few frames, and a projectile in flight holds the drain
    // (hp_hold, set at cast) so the bar moves when the bolt lands.
    ui_draw_hp_bar(_bar_x, _bar_y, _bar_width, _bar_height,
                   combat_hp_vis(_c), _c.max_HP, _c.name, true);

    // Intent chip (INTENT_SPEC.md): the foe's telegraphed next action, drawn as a
    // compact plate above the bar (clears the ornate frame at y-4). Greys out with
    // a strike-through while a control status cancels the telegraphed move.
    ui_draw_intent_chip(_bar_x, _bar_y - 10, _c);

    // Attack-class tag (reach/kind), right-aligned under the bar so the player can
    // see which control applies: ROOT blocks Melee, SILENCE blocks Spell, STUN all.
    // Ranged foes are tinted amber as a "root won't stop this" cue.
    var _ec_ranged = (variable_struct_exists(_c, "reach") && _c.reach == "ranged");
    draw_set_font(fnt_ui_small);
    draw_set_halign(fa_right);
    draw_set_valign(fa_top);
    draw_set_color(_ec_ranged ? make_color_rgb(220, 170, 80) : make_color_rgb(140, 155, 185));
    draw_text(_bar_x + _bar_width, _bar_y + _bar_height + 9, enemy_class_tag(_c));
    draw_set_halign(fa_left);
    draw_set_font(-1);

    // The HP bar (+ its class-tag line) is an inspect surface - hovering it opens
    // the inspect tooltip after the HUD draws.
    if (_mx_gui >= _bar_x && _mx_gui <= _bar_x + _bar_width
        && _my_gui >= _bar_y && _my_gui <= _bar_y + _bar_height + 30) {
        _inspect_target = _c;
    }

    // Status icons below the HP bar for this enemy. Combo legibility (07-16):
    // the status the SELECTED ability would detonate pulses, and an enemy under
    // 2+ distinct statuses gets the gold OVERWHELMED (+15% taken) badge.
    if (variable_struct_exists(_c, "status_effects") && array_length(_c.status_effects) > 0) {
        var _row_react_se = undefined;
        if (player_turn && selected_ability < array_length(player.abilities)
            && is_struct(player.abilities[selected_ability])) {
            var _row_rp = combat_reaction_preview(player.abilities[selected_ability], player, _c);
            if (_row_rp.idx >= 0 && _row_rp.idx < array_length(_c.status_effects)) {
                _row_react_se = _c.status_effects[_row_rp.idx];
            }
        }
        ui_draw_enemy_status_icons(_bar_x, _bar_y + _bar_height + 6, _c.status_effects,
            _row_react_se, combatant_distinct_status_kinds(_c) >= 2);
    }

    _living_idx++;
}


// -----------------------------------------------------------------------------
// 3. COMBAT HUD
// Draws player HP, AP pips, secondary resource, turn queue, ability
// buttons, combat log, and any active telegraph warning.
// -----------------------------------------------------------------------------
// draw_log=false defers the hit-preview + combat log to ui_draw_combat_overlay
// (called after the battler sprites) so combat text always sits on top of them.
ui_draw_combat_hud(combat_state, player, player.abilities, selected_ability, combat_log, false);

// Awakening tier reference - small label top-right, above the enemy HP bars.
var _awk_asc = variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0;
draw_set_font(fnt_ui_small);
draw_set_halign(fa_right);
draw_set_valign(fa_top);
draw_set_color(_awk_asc > 0 ? make_color_rgb(225, 150, 70) : make_color_rgb(120, 130, 150));
// Touch: the X chip owns the top-right corner - the label slides left of it.
draw_text((input_device() == 2) ? 1785 : 1905, 12, awakening_label());
draw_set_font(-1);
draw_set_halign(fa_left);


// -----------------------------------------------------------------------------
// 3b. CHARACTER SPRITES + COMBAT VFX
// Handles: attack slide lunge, hit flash (additive blend), screen shake,
// and floating damage/heal number popups.
// -----------------------------------------------------------------------------

// Screen shake: randomise offset while timer counts down
if (screen_shake_timer > 0) {
    screen_shake_timer--;
    screen_shake_x = irandom_range(-5, 5);
    screen_shake_y = irandom_range(-3, 3);
} else {
    screen_shake_x = 0;
    screen_shake_y = 0;
}

// Attack slide: compute lunge fraction (0 -> peak -> 0) over 20 frames
var _anim_progress = 0;
if (attack_anim_timer > 0) {
    attack_anim_timer--;
    _anim_progress = (20 - attack_anim_timer) / 20.0;
}
var _lunge_peak = (_anim_progress < 0.5)
    ? (_anim_progress * 2.0)
    : ((1.0 - _anim_progress) * 2.0);
var _lunge_frac = _lunge_peak * 0.4;   // lunge 40% of the way toward target

// Player sprite (Vael skin override applied via player_combat_sprite).
// Frame index is sprite-aware: 8-dir = east/frame 1, single side-view skin = frame 0.
var _pspr = player_combat_sprite(clamp(player.stats.class_id, 0, 2));
var _pfr  = player_sprite_frame(_pspr);

// 2.5D round 5 (M shot: "player sprite still has a huge shadow and is now
// behind the combat log"). Root cause: skin canvases are mostly empty margin,
// so canvas-height scaling drew a SMALL visible knight with a canvas-sized
// shadow, and his canvas feet sank under the log panel. 2.5D now scales by
// the VISIBLE model (bbox) and pins the visible FEET just above the log
// (y726). Flat mode: shipped anchors + canvas scaling, untouched.
var _p25 = combat_25d();
// Round 6: bbox scaling proved UNRELIABLE (stray canvas pixels stretched the
// bbox - the knight shrank and floated, M shot). Back to the shipped canvas
// convention: 385px display height, feet at the canvas 0.94 ground line the
// whole game already anchors shadows to, pinned just above the log (y726).
// Round 8 (M): the player's spot varies a step per stage layout, so the
// hero pair doesn't stand identically every fight.
var _lay25 = variable_instance_exists(id, "stage_layout") ? stage_layout : 0;
// Round 11 (M: "the shadows are miles away from the sprites... fix these
// immediately"): ALL 2.5D player metrics now come from sprite_true_bounds -
// MEASURED opaque pixels, not .yy bbox metadata. The metadata lies two ways
// (full-image bbox modes = canvas anchoring in disguise; stray faint pixels =
// phantom feet below the model) and every anchoring bug shipped through one
// of them. The VISIBLE model stands ~360px, feet exactly on the y726 line.
// Round 12 (M: "the original player and pet location were better... remap the
// player sprite to smaller so it looks good"): back to the SHIPPED size
// convention (345px canvas height - the art was authored for it) at the
// shipped x330. Only two 2.5D differences survive: the visible feet anchor to
// the y726 ground line, and the shadow clips to measured pixels.
var _ptb25 = _p25 ? sprite_true_bounds(_pspr) : undefined;
var _pscale_25 = _p25 ? (345 / max(1, sprite_get_height(_pspr))) : 1;
var _pbx = 330;
var _pby = _p25 ? (726 - (_ptb25.b + 1) * _pscale_25) : 465;
var _px_draw = _pbx + screen_shake_x;
var _py_draw = _pby + screen_shake_y;
// Round 12 (M: "abilities VFX are not even over them - they should be BOUND
// to player sprite location"): stamp the player's live visual centre every
// frame; combat_player_vfx_anchor reads THIS, so VFX can never drift from
// the sprite again no matter how the staging moves.
if (_p25) {
    global.player_stage_cx = _pbx + (_ptb25.l + _ptb25.r + 1) * 0.5 * _pscale_25;
    global.player_stage_cy = _pby + (_ptb25.t + _ptb25.h * 0.5) * _pscale_25;
}
if (attack_anim_is_player && _anim_progress > 0) {
    _px_draw = lerp(_pbx, attack_anim_dst_x, _lunge_frac) + screen_shake_x;
    _py_draw = lerp(_pby, attack_anim_dst_y, _lunge_frac) + screen_shake_y;
}
// Per-sprite damage shake: jolt the player sprite while its hit flash is active,
// plus a constant nervous shiver while stunned/paralyzed.
if (player.hit_flash > 0) { _px_draw += irandom_range(-8, 8); _py_draw += irandom_range(-5, 5); }
if (combatant_has_status_kind(player, "stun")) _px_draw += irandom_range(-3, 3);
// Conveyance (08-04): dodge SIDESTEP (away from the enemy line - fast out, ease
// back) and the smaller hit-RECOIL knock. Countdowns live on the combatant
// struct (hit_flash idiom, set in Step) and tick here where they're consumed.
if (variable_struct_exists(player, "dodge_anim") && player.dodge_anim > 0) {
    _px_draw -= combat_slide_px(player.dodge_anim, 14, 26);
    player.dodge_anim--;
}
if (variable_struct_exists(player, "hit_recoil") && player.hit_recoil > 0) {
    _px_draw -= combat_slide_px(player.hit_recoil, 10, 9);
    player.hit_recoil--;
}
// Normalise display size: larger canvases (skins, female class sprites) scale down
// to the same ~345px display height (native 1080p; was 230px at 720p).
// 2.5D: scaled by the VISIBLE model instead (see round-5 note above) so every
// skin's knight stands ~330px tall regardless of canvas padding.
var _pscale = combat_25d() ? _pscale_25 : (345 / max(1, sprite_get_height(_pspr)));

// --- Active pet companion (Pets Phase 3: combat presence) --------------------
// Drawn BEFORE the player's shadow + sprite (M 07-27 screenshot: a giant corrupt
// bug drew OVER the player - the pet is the depth row BEHIND them, so it must
// render first and let the player overlap it). The equipped pet stands beside
// the player, facing east toward the enemies, idling via its looping directional
// sprite. All archetypes are PRESENT (sells the "it's with you" lore); only
// Combatant pets act on their own turn. Display height grows with Stage.
var _pet_co = global.duel_active ? undefined : pet_active();   // duel: the companion waits outside the hall
if (_pet_co != undefined && !_pet_co.is_egg) {
    var _petspr = pet_sprite(_pet_co, "e");
    if (_petspr >= 0) {
        var _pet_disp_h = [120, 145, 170, 200, 230];   // display height by Stage 0-4
        var _peth_t = _pet_disp_h[clamp(_pet_co.stage, 0, 4)];
        // 2.5D round 8 (M: "player and pet are in the same line... offset them
        // ...sizes should scale with position and be dynamic"): the pet stands
        // a FULL depth row up the diagonal - feet 110-150px above the player's
        // - shrunk to ~60% for the distance, both varying per stage layout so
        // no two fights stage the pair identically. Flat mode: shipped anchor.
        // Round 12 (M: "the original player and pet location were better" /
        // "the pet looks SO TINY"): back to the shipped arrangement - the pet
        // stands BESIDE the player at ~90% of its flat display size (the whole
        // forced-perspective discount it gets). Right of the player = always
        // clear of the POTENTIAL DAMAGE box (x30-320).
        if (combat_25d()) _peth_t *= 0.90;
        // Player feet (origin top-left): centre-x + a step to the right, ground-line y.
        // Anchored to the player's RESTING position (base + screen shake), NOT the
        // animated _px_draw/_py_draw - otherwise the pet visibly rides along on the
        // player's attack lunge and hit-jitter despite not acting (it has its own
        // pet_lunge_t0-driven lunge below for when it actually strikes).
        var _petx = _pbx + screen_shake_x
                  + (combat_25d()
                      ? (sprite_get_width(_pspr) * _pscale * 0.5 + 130)
                      : (sprite_get_width(_pspr) * _pscale * 0.5 + 120));
        // Ground line clamped ABOVE the combat log (log top y735, drawn after sprites):
        // at the player's true footing (y~789) the pet's lower half vanished behind the
        // log panel. Standing it slightly higher reads as a depth row behind the player.
        // 2.5D: the diagonal's back step - feet 110-150px above the player's
        // 726, drifting per layout for variance.
        var _pety = combat_25d()
            ? (706 + screen_shake_y)
            : min(465 + screen_shake_y + sprite_get_height(_pspr) * _pscale * 0.94, 726);
        // #16: fit + anchor by the VISIBLE creature (sprite bbox), not the padded
        // canvas - bonehound/hollow pup stood at half the intended display height.
        // _petx/_pety stay the FEET point (shadow); _pdx/_pdy are the draw anchor.
        // M 07-16: cap visible WIDTH too - fitting by height alone blew short, wide
        // sprites up huge (the luna moth caterpillar drew near knight-sized).
        var _pcfit  = pet_sprite_fit(_petspr, _petx, _pety, _peth_t, _peth_t * 1.35);
        var _petsc  = _pcfit.scale;
        var _pdx    = _pcfit.x;
        var _pdy    = _pcfit.y;
        var _pet_vis_w = (sprite_get_bbox_right(_petspr) - sprite_get_bbox_left(_petspr) + 1) * _petsc;

        // Procedural attack lunge: on a Combatant strike (global.pet_lunge_t0), the pet
        // surges toward the enemies (right) and snaps back over ~260ms, with a squash-
        // stretch and a white impact flash at the apex. Purely code-driven (no attack art).
        // Facing (M 07-29): everyone holds the east combat facing EXCEPT a
        // Guardian tending the hero (mender/cleanser stance) - it turns to face
        // them. Mirrored around the visible-center anchor so the flip doesn't
        // shift the creature sideways (draw x holds the sprite ORIGIN, so the
        // mirrored origin is reflected across the feet anchor _petx).
        var _face_sign = 1;
        if (_pet_co.archetype == PET_ARCH_GUARDIAN) {
            var _gstance = pet_stance(_pet_co);
            if (_gstance == "mender" || _gstance == "cleanser") {
                _face_sign = -1;
                _pdx = 2 * _petx - _pdx;
            }
        }

        var _lunge_dx = 0, _sx = _petsc, _flash = 0;
        var _lt0 = variable_global_exists("pet_lunge_t0") ? global.pet_lunge_t0 : -100000;
        var _lprog = (current_time - _lt0) / 260;
        if (_lprog >= 0 && _lprog <= 1) {
            var _arc  = sin(_lprog * pi);          // 0 -> 1 -> 0
            _lunge_dx = _arc * 96;                  // toward the enemy line
            _sx       = _petsc * (1 + 0.18 * _arc); // stretch forward as it lunges
            if (_lprog > 0.34 && _lprog < 0.60) _flash = 0.55;   // impact
        }

        ui_draw_cast_shadow(_petx, _pety, _pet_vis_w * 0.8, -1);   // 2.5D: cast back-left
        draw_sprite_ext(_petspr, pet_anim_frame(_petspr), _pdx + _lunge_dx, _pdy, _face_sign * _sx, _petsc, 0, c_white, 1.0);
        // Awakened FX v2 (08-13, M direction): hologram echo + periodic pulse
        // ring + rising aura motes - the Stage-4 form is SOLD by the effect,
        // so it has to actually read (the old 20%-alpha halo did not).
        ui_draw_pet_awakened_fx(_pet_co, _petspr, pet_anim_frame(_petspr),
            _pdx + _lunge_dx, _pdy, _face_sign * _sx, _petsc,
            _petx + _lunge_dx, _pety - _peth_t * 0.5);
        // Corruption dressing (07-09 art track): pushing = violet flicker,
        // fulfilled = dark aura + orbiting motes. Same transform as the base draw.
        ui_draw_pet_corruption_fx(_pet_co, _petspr, pet_anim_frame(_petspr),
            _pdx + _lunge_dx, _pdy, _face_sign * _sx, _petsc, _petx + _lunge_dx, _pety - _peth_t * 0.5);
        // Additive white flash on the sprite at the strike apex.
        if (_flash > 0) {
            gpu_set_blendmode(bm_add);
            draw_sprite_ext(_petspr, pet_anim_frame(_petspr), _pdx + _lunge_dx, _pdy, _face_sign * _sx, _petsc, 0, c_white, _flash);
            gpu_set_blendmode(bm_normal);
        }
        // Guard/HP chip MOVED (M 07-09): the over-head text was awkward and hard to
        // read. The pet's HP bar + guard state now draw in the upper-left HUD under
        // the player's level block (ui_draw_combat_hud).
    }
}

// Ground shadow beneath the player so the sprite reads against busy backgrounds.
// Sized by the VISIBLE model (sprite bbox), not the padded canvas - the canvas
// width made the player's shadow read LARGER than a giant pet's (M 07-27
// screenshot), because skin canvases are mostly empty margin. Baseline at ~0.94
// of the canvas height so it sits at the model's feet.
var _p_vis_l = sprite_get_bbox_left(_pspr) * _pscale;
var _p_vis_w = (sprite_get_bbox_right(_pspr) - sprite_get_bbox_left(_pspr) + 1) * _pscale;
if (combat_25d()) {
    // Round 11: shadow centred on the MEASURED model at its measured feet -
    // metadata-free, so it cannot detach from the sprite again.
    ui_draw_cast_shadow(_px_draw + (_ptb25.l + _ptb25.r + 1) * 0.5 * _pscale,
                        _py_draw + (_ptb25.b + 1) * _pscale,
                        _ptb25.w * _pscale * 0.9, -1);
} else {
    ui_draw_cast_shadow(_px_draw + _p_vis_l + _p_vis_w * 0.5,
                        _py_draw + sprite_get_height(_pspr) * _pscale * 0.94,
                        _p_vis_w * 0.9, -1);
}
draw_sprite_ext(_pspr, _pfr, _px_draw, _py_draw, _pscale, _pscale, 0, c_white, 1.0);
if (player.hit_flash > 0) {
    player.hit_flash--;
    gpu_set_blendmode(bm_add);
    draw_sprite_ext(_pspr, _pfr, _px_draw, _py_draw, _pscale, _pscale, 0, c_white, (player.hit_flash / 15.0) * 0.8);
    gpu_set_blendmode(bm_normal);
}
// --- Cast windup FX (07-09 art track, code-first) ---
// SPELL casts flare the caster in the school's color and shed rising school-tinted
// motes for ~26 frames. Purely code-drawn (stateless motes derived from the timer),
// no cast-frame art needed; melee attacks keep the slide lunge instead.
if (cast_fx_timer > 0) {
    cast_fx_timer--;
    var _cfa = cast_fx_timer / 26.0;   // 1 at cast -> 0
    gpu_set_blendmode(bm_add);
    draw_sprite_ext(_pspr, _pfr, _px_draw, _py_draw, _pscale, _pscale, 0, cast_fx_color, 0.45 * _cfa);
    var _cf_cx = _px_draw + sprite_get_width(_pspr) * _pscale * 0.5;
    var _cf_fy = _py_draw + sprite_get_height(_pspr) * _pscale * 0.90;
    for (var _cfi = 0; _cfi < 10; _cfi++) {
        var _cfp = (_cfi * 137.5) mod 97;                          // per-mote phase scramble
        var _cfx = _cf_cx + (((_cfp * 3.7) mod 120) - 60);
        var _cfy = _cf_fy - (1 - _cfa) * (140 + (_cfp mod 90)) - (_cfp mod 40);
        draw_set_alpha(0.5 * _cfa);
        draw_set_color(merge_color(cast_fx_color, c_white, 0.35));
        draw_rectangle(_cfx - 2, _cfy - 5, _cfx + 2, _cfy + 5, false);
    }
    draw_set_alpha(1.0);
    gpu_set_blendmode(bm_normal);
}

// IRON SKIN cast overlay (M 08-13: "should be an envelopment of bone or armor
// briefly, not this digital blue blurr"): the player sprite re-drawn as a cold
// iron shell, with angular plate shards CONVERGING into the body as the armor
// assembles. Replaces the generic shield burst for this cast (Step zeroes it).
if (ironskin_fx_timer > 0) {
    ironskin_fx_timer--;
    var _ik_t  = 1 - ironskin_fx_timer / 34.0;           // 0 -> 1 over life
    var _ik_a  = (ironskin_fx_timer > 24) ? 1.0 : (ironskin_fx_timer / 24.0);
    var _ik_cx = _px_draw + sprite_get_width(_pspr)  * _pscale * 0.5;
    var _ik_cy = _py_draw + sprite_get_height(_pspr) * _pscale * 0.5;
    gpu_set_blendmode(bm_add);
    // The shell: iron-tinted body glow, strongest at cast, then settling.
    draw_sprite_ext(_pspr, _pfr, _px_draw, _py_draw, _pscale, _pscale, 0,
                    make_color_rgb(196, 198, 208), 0.55 * _ik_a);
    // Plate shards sliding in from a surrounding ring - armor being fitted.
    for (var _iki = 0; _iki < 8; _iki++) {
        var _ik_ang = _iki * 45 + 22;
        var _ik_d   = lerp(190, 46, min(1, _ik_t * 1.6));
        var _ik_x   = _ik_cx + lengthdir_x(_ik_d, _ik_ang);
        var _ik_y   = _ik_cy + lengthdir_y(_ik_d * 0.75, _ik_ang);
        var _ik_s   = 13;
        draw_set_alpha(0.7 * _ik_a);
        draw_set_color(make_color_rgb(150, 152, 165));
        draw_rectangle(_ik_x - _ik_s, _ik_y - _ik_s * 0.55, _ik_x + _ik_s, _ik_y + _ik_s * 0.55, false);
        draw_set_color(make_color_rgb(228, 230, 238));
        draw_rectangle(_ik_x - _ik_s, _ik_y - _ik_s * 0.55, _ik_x + _ik_s, _ik_y + _ik_s * 0.55, true);
    }
    draw_set_alpha(1.0);
    gpu_set_blendmode(bm_normal);
}

// (Pet companion block MOVED above the player draw - M 07-27 screenshot: it
// rendered over the player. The pet is the depth row behind them.)
// Looping status VFX (poison gas, flames, blind mist, ...) over the player sprite.
if (variable_struct_exists(player, "status_effects")) {
    ui_draw_status_fx(_px_draw + sprite_get_width(_pspr) * _pscale * 0.5, _py_draw,
                      sprite_get_height(_pspr) * _pscale, player.status_effects);
}

// GLYPH FX (08-13): gold rune rings traced at a target's feet by enemy support
// casts (Restorative Glyph). Drawn here - UNDER the enemy sprites, like the
// target reticle - so the glyph reads as inscribed on the floor. The paired
// mend burst arrives via a delayed vfx_bursts entry when the trace completes.
var _kept_glyphs = [];
for (var _gfi = 0; _gfi < array_length(glyph_fx); _gfi++) {
    var _gf = glyph_fx[_gfi];
    _gf.t++;
    if (_gf.t < _gf.dur) {
        var _gf_p  = _gf.t / _gf.dur;
        var _gf_a  = (_gf_p < 0.75) ? min(1, _gf_p * 4) : ((1 - _gf_p) / 0.25);
        var _gf_px = (90 + 45 * _gf_p) / max(1, sprite_get_width(spr_target_cursor));
        gpu_set_blendmode(bm_add);
        // Flattened onto the floor plane, swirling as it is "traced".
        draw_sprite_ext(spr_target_cursor, 0, _gf.x + screen_shake_x, _gf.y + screen_shake_y,
                        _gf_px * 2.1, _gf_px * 0.85, current_time * 0.08, _gf.col, 0.85 * _gf_a);
        gpu_set_blendmode(bm_normal);
        array_push(_kept_glyphs, _gf);
    }
}
glyph_fx = _kept_glyphs;

// DEPLOYED TRAPS, on the ground between the player and the enemy line (08-08 v2).
// Drawn here - after the player/pet, before the enemies - so a trap sits IN the
// scene at the right depth instead of on top of the HUD like the first pass did.
ui_draw_trap_field(player, combat_state);

// THE STANDING SUMMON (class pass, M 08-13): the Arcanist's construct holds the
// lane just ahead of the player. PLACEHOLDER RENDER (procedural pedestal + a
// breathing elemental orb in its school color) until bespoke props are
// M-approved art - same degrade-gracefully idiom as the trap jaw glyph.
if (variable_struct_exists(player, "summon") && is_struct(player.summon)) {
    var _smp   = player.summon;
    // 2.5D: mid-lane between the pet's diagonal and the trap stations.
    // Round 9: pulled left of the near enemy stations (now x620-810).
    var _smp_x = combat_25d() ? 560 : 630;
    var _smp_y = combat_25d() ? 700 : 615;
    var _smp_c = (_smp.kind == "golem") ? make_color_rgb(235, 120, 40)
               : ((_smp.kind == "husk") ? make_color_rgb(235, 215, 80) : make_color_rgb(160, 140, 230));
    var _smp_p = 0.5 + 0.5 * sin(current_time / 320);
    ui_draw_cast_shadow(_smp_x, _smp_y + 6, 110, -1);
    // Pedestal: squat stone block.
    draw_set_color(make_color_rgb(52, 50, 60));
    draw_rectangle(_smp_x - 26, _smp_y - 18, _smp_x + 26, _smp_y + 4, false);
    draw_set_color(make_color_rgb(24, 24, 30));
    draw_rectangle(_smp_x - 26, _smp_y - 18, _smp_x + 26, _smp_y + 4, true);
    // The construct's heart: additive breathing orb, school-tinted.
    gpu_set_blendmode(bm_add);
    draw_set_alpha(0.30 + 0.25 * _smp_p);
    draw_set_color(_smp_c);
    draw_circle(_smp_x, _smp_y - 52, 34 + 5 * _smp_p, false);
    draw_set_alpha(0.85);
    draw_circle(_smp_x, _smp_y - 52, 16 + 3 * _smp_p, false);
    gpu_set_blendmode(bm_normal);
    draw_set_alpha(1.0);
    // Hits-left pips under the pedestal (what it can still eat).
    for (var _smp_i = 0; _smp_i < _smp.hits; _smp_i++) {
        draw_set_color(_smp_c);
        draw_rectangle(_smp_x - 12 + _smp_i * 16, _smp_y + 10, _smp_x - 2 + _smp_i * 16, _smp_y + 18, false);
    }
    draw_set_color(c_white);
}

// Enemy sprites - the name->sprite map now lives in scr_enemies (enemy_sprite_map)
// so the journal BESTIARY can draw the same creatures south-facing (#8).
var _espr_map = enemy_sprite_map();
// THE ASHEN DUELIST (08-09): he is the one foe whose MODEL changes with progress,
// so his map entry is overridden once here rather than at each of the three
// lookup sites below (inspect hit-box, death-linger ghost, standing draw) - all
// three read _espr_map, so they stay in lockstep for free.
if (variable_struct_exists(_espr_map, "The Ashen Duelist")) {
    var _dl_tier_spr = duelist_sprite_for(variable_global_exists("duelist_encounters")
                                          ? global.duelist_encounters : 0);
    if (_dl_tier_spr >= 0) variable_struct_set(_espr_map, "The Ashen Duelist", _dl_tier_spr);
}
var _espr_x0  = 1665;
var _espr_y0  = 225;
var _espr_dx  = -174;   // strong horizontal spread so foes read as a row, not a column
var _espr_dy  = 36;     // gentle slope (was 70 - enemies marched too far down the screen)
var _espr_zig = 36;     // alternating up/down nudge so the cluster isn't a straight diagonal line
var _espr_idx = 0;

var _ecnt = array_length(combat_state.combatants);
for (var _ei = 0; _ei < _ecnt; _ei++) {
    var _ec = combat_state.combatants[_ei];
    if (_ec.is_player) continue;
    if (_ec.is_defeated) {
        // Death linger + fade (M 08-04): the fallen stay visible briefly - and
        // if a projectile is still flying at them, until it LANDS. They draw at
        // their last standing position (stamped below) WITHOUT consuming a row
        // slot, so the living compact around them and targeting stays honest.
        if (!variable_struct_exists(_ec, "death_linger")) _ec.death_linger = 20;   // lazy init catches every kill path
        if (_ec.death_linger > 0 && variable_struct_exists(_ec, "last_ex")
            && variable_struct_exists(_espr_map, _ec.name)) {
            var _dl_spr = variable_struct_get(_espr_map, _ec.name);
            var _dl_frm = (sprite_get_number(_dl_spr) > 1) ? 3 : 0;
            var _dl_a   = min(1.0, _ec.death_linger / 20.0);
            // Depth scale stamped at death (faux-2.5D); pre-lever kills read 3x.
            var _dl_es  = variable_struct_exists(_ec, "last_esc") ? _ec.last_esc : 3;
            draw_set_alpha(_dl_a);
            draw_sprite_ext(_dl_spr, _dl_frm, _ec.last_ex + screen_shake_x, _ec.last_ey + screen_shake_y, _dl_es, _dl_es, 0, c_white, _dl_a);
            // Late-arriving hit flash (the killing bolt landing) reads on the ghost.
            if (variable_struct_exists(_ec, "hit_flash") && _ec.hit_flash > 0) {
                _ec.hit_flash--;
                gpu_set_blendmode(bm_add);
                draw_sprite_ext(_dl_spr, _dl_frm, _ec.last_ex, _ec.last_ey, _dl_es, _dl_es, 0, c_white, _dl_a * 0.8);
                gpu_set_blendmode(bm_normal);
            }
            draw_set_alpha(1.0);
            _ec.death_linger--;
        }
        continue;
    }

    // 2.5D round 7: stations FREEZE per enemy (M: "they trade places when you
    // kill some") - each foe copies its station on first sight and keeps it
    // for the whole fight, so deaths never reflow the survivors. The BOSS
    // claims a bespoke center-stage station standing clear above the log
    // (M: "some bosses lose their visual appeal" buried behind it).
    if (combat_25d() && !variable_struct_exists(_ec, "stage_station")) {
        if (variable_instance_exists(id, "summon_is_boss_fight") && summon_is_boss_fight
            && variable_instance_exists(id, "stage_boss_placed") && !stage_boss_placed) {
            stage_boss_placed = true;
            // Round 13: boss 2.25 (M: still too big at 2.55).
            _ec.stage_station = { x: 1170, y: 655 - 97 * 2.25, scale: 2.25, feet: 655,
                                  cx: 1170 + 48.5 * 2.25, cy: 655 - 48.5 * 2.25 };
        } else {
            // Round 13d (M shot "cramped": mobs stacking on each other):
            // newcomers (mid-fight summons) took an INDEX-based station that
            // could match one already FROZEN by a living foe - two enemies on
            // one spot. Walk to the first station nobody holds.
            var _st_new = combat_enemy_slot_pos(_espr_idx);
            var _st_try = 0;
            while (_st_try < 5) {
                var _st_clash = false;
                for (var _oi = 0; _oi < array_length(combat_state.combatants); _oi++) {
                    var _oc = combat_state.combatants[_oi];
                    if (_oc == _ec || _oc.is_player || _oc.is_defeated) continue;
                    if (variable_struct_exists(_oc, "stage_station")
                        && abs(_oc.stage_station.x - _st_new.x) < 60
                        && abs(_oc.stage_station.feet - _st_new.feet) < 40) { _st_clash = true; break; }
                }
                if (!_st_clash) break;
                _st_try++;
                _st_new = combat_enemy_slot_pos(_espr_idx + _st_try);
            }
            _ec.stage_station = _st_new;
        }
    }
    var _esp = (combat_25d() && variable_struct_exists(_ec, "stage_station"))
             ? _ec.stage_station : combat_enemy_slot_pos(_espr_idx);
    var _ex  = _esp.x;
    var _ey  = _esp.y;
    var _es  = _esp.scale;
    // Round 6 (M shot: the 192px-canvas Archivist drew ~720px tall and buried
    // the ability tooltip): station scales assume the 97px canvas - normalize
    // big-canvas sprites so every foe displays at the station's INTENDED
    // height, feet still landing exactly on the station's ground line.
    if (combat_25d() && variable_struct_exists(_espr_map, _ec.name)) {
        var _nspr = variable_struct_get(_espr_map, _ec.name);
        // Round 11 (M: "shadows are miles away... fix immediately"): scale AND
        // anchor from sprite_true_bounds (measured opaque pixels), not canvas
        // or .yy bbox - the station scale now means the same VISIBLE height
        // for every sprite, and feet land exactly on the station ground line.
        var _ntb = sprite_true_bounds(_nspr);
        _es *= 97 / max(1, _ntb.h);
        // Round 13b (M: "lowest mob can still be too large depending on the
        // sprite"): HARD SIZE CEILING - no enemy ever draws taller than 185px
        // visible, whatever its station scale says. Per-MOB-TYPE size intent
        // (small-by-design species staying small) is the tweak-by-tweak pass.
        _es = min(_es, 185 / max(1, _ntb.h));
        _ey  = _esp.feet - (_ntb.b + 1) * _es;
    }

    // Inspect hit-box from the RESTING sprite position (before lunge/shake jitter is
    // applied below) so hovering the creature itself also opens the inspect tooltip,
    // and the hot-zone doesn't jump around while it animates.
    if (variable_struct_exists(_espr_map, _ec.name)) {
        var _isp   = variable_struct_get(_espr_map, _ec.name);
        var _isp_w = sprite_get_width(_isp)  * _es;
        var _isp_h = sprite_get_height(_isp) * _es;
        if (_mx_gui >= _ex && _mx_gui <= _ex + _isp_w
            && _my_gui >= _ey && _my_gui <= _ey + _isp_h) {
            _inspect_target = _ec;
        }
        // Touch (M 07-08 device test): tapping the enemy MODEL retargets, not
        // just its HP bar - same living-enemy index the bar tap in Step sets.
        // Fires on tap-RELEASE (gesture) so a drag over the cluster can't retarget.
        if (input_device() == 2
            && touch_tap_in(_ex - 15, _ey - 15, _ex + _isp_w + 15, _ey + _isp_h + 15)) {
            selected_target = _espr_idx;
        }
    }

    // Attack slide for the enemy that is currently attacking
    if (!attack_anim_is_player && attack_anim_enemy_idx == _espr_idx && _anim_progress > 0) {
        _ex = lerp(attack_anim_src_x, attack_anim_dst_x, _lunge_frac) + screen_shake_x;
        _ey = lerp(attack_anim_src_y, attack_anim_dst_y, _lunge_frac) + screen_shake_y;
    } else {
        _ex += screen_shake_x;
        _ey += screen_shake_y;
    }

    // Per-sprite damage shake + stun shiver (mirrors the player sprite treatment).
    if (variable_struct_exists(_ec, "hit_flash") && _ec.hit_flash > 0) { _ex += irandom_range(-8, 8); _ey += irandom_range(-5, 5); }
    if (combatant_has_status_kind(_ec, "stun")) _ex += irandom_range(-3, 3);
    // Conveyance (08-04): dodge sidestep + hit recoil, away from the player (+x).
    if (variable_struct_exists(_ec, "dodge_anim") && _ec.dodge_anim > 0) {
        _ex += combat_slide_px(_ec.dodge_anim, 14, 26);
        _ec.dodge_anim--;
    }
    if (variable_struct_exists(_ec, "hit_recoil") && _ec.hit_recoil > 0) {
        _ex += combat_slide_px(_ec.hit_recoil, 10, 9);
        _ec.hit_recoil--;
    }
    // Stamp the standing position for the death-linger ghost (shake excluded -
    // the ghost draw re-applies live shake itself). Depth scale rides along so
    // the ghost stays the size it died at (faux-2.5D).
    _ec.last_ex  = _ex - screen_shake_x;
    _ec.last_ey  = _ey - screen_shake_y;
    _ec.last_esc = _es;
    // Visual CENTER stamp (2.5D v3): burst/impact VFX target this instead of
    // the old hardcoded +145, so hits land on the sprite at every depth scale.
    // Round 11: measured centre, MIRROR-AWARE - east-authored sprites draw
    // flipped about the canvas, so their visible centre reflects too (this is
    // exactly the case that put the Bone Colossus' shadow ~70px off).
    _ec.last_ecx = _ec.last_ex + 48.5 * _es;
    _ec.last_ecy = _ec.last_ey + 48.5 * _es;
    if (combat_25d() && variable_struct_exists(_espr_map, _ec.name)) {
        var _ctb = sprite_true_bounds(variable_struct_get(_espr_map, _ec.name));
        var _cw25 = sprite_get_width(variable_struct_get(_espr_map, _ec.name));
        var _ccxu = (_ctb.l + _ctb.r + 1) * 0.5;
        _ec.last_ecx = _ec.last_ex + (enemy_sprite_faces_east(_ec.name) ? (_cw25 - _ccxu) : _ccxu) * _es;
        _ec.last_ecy = _ec.last_ey + (_ctb.t + _ctb.h * 0.5) * _es;
    }

    if (variable_struct_exists(_espr_map, _ec.name)) {
        var _espr = variable_struct_get(_espr_map, _ec.name);
        var _espr_frame = (sprite_get_number(_espr) > 1) ? 3 : 0;

        // Ground shadow beneath the enemy (under both the reticle and the sprite) so
        // foes read against busy backgrounds.
        // Baseline raised to ~0.94 of the sprite height so the shadow hugs the
        // enemy's feet; width scales with the model so big foes cast bigger shadows.
        if (combat_25d()) {
            // Round 11: shadow centred on the MEASURED model (mirror-aware -
            // the Bone Colossus shadow sat ~70px off because the flip was
            // ignored), sized by measured width, at the measured feet line.
            var _stb  = sprite_true_bounds(_espr);
            var _scxu = (_stb.l + _stb.r + 1) * 0.5;
            var _scx  = _ex + (enemy_sprite_faces_east(_ec.name) ? (sprite_get_width(_espr) - _scxu) : _scxu) * _es;
            ui_draw_cast_shadow(_scx, _ey + (_stb.b + 1) * _es, _stb.w * _es, 1);
        } else {
            ui_draw_cast_shadow(_ex + sprite_get_width(_espr)  * _es * 0.5,
                                _ey + sprite_get_height(_espr) * _es * 0.94,
                                sprite_get_width(_espr) * _es, 1);
        }

        // Selected-target reticle: a slowly-swirling arcane rune at the foe's feet,
        // drawn UNDER the sprite so it reads as a ground marker. Lets you map the
        // highlighted name/HP bar to the correct sprite while tabbing targets.
        if (_espr_idx == selected_target) {
            var _cur_cx = _ex + sprite_get_width(_espr)  * _es * 0.5;
            var _cur_cy = _ey + sprite_get_height(_espr) * _es;          // at the feet
            if (combat_25d()) {
                // Round 11: reticle under the MEASURED feet (mirror-aware).
                var _rtb  = sprite_true_bounds(_espr);
                var _rcxu = (_rtb.l + _rtb.r + 1) * 0.5;
                _cur_cx = _ex + (enemy_sprite_faces_east(_ec.name) ? (sprite_get_width(_espr) - _rcxu) : _rcxu) * _es;
                _cur_cy = _ey + (_rtb.b + 1) * _es;
            }
            // Shrunk 30% from the old *0.4 factor (0.4 -> 0.28) so the ground rune sits tighter under the foe.
            var _cur_sc = max(0.18, (sprite_get_width(_espr) * _es) / sprite_get_width(spr_target_cursor)) * 0.28;
            _cur_sc    *= 1 + 0.06 * sin(current_time / 180);            // gentle breathing pulse
            var _cur_rot = current_time * 0.05;                          // continuous swirl
            draw_sprite_ext(spr_target_cursor, 0, _cur_cx, _cur_cy,
                            _cur_sc, _cur_sc, _cur_rot, c_white, 0.9);
        }

        // Round 7 (M: "some enemies are facing backwards... like ice specter"):
        // east-authored sprites are mirrored about their own width so they face
        // the player. Add names to enemy_sprite_faces_east as spotted.
        var _efx = _ex;
        var _efs = _es;
        if (enemy_sprite_faces_east(_ec.name)) {
            _efx = _ex + sprite_get_width(_espr) * _es;
            _efs = -_es;
        }
        draw_sprite_ext(_espr, _espr_frame, _efx, _ey, _efs, _es, 0, c_white, 1.0);
        if (variable_struct_exists(_ec, "hit_flash") && _ec.hit_flash > 0) {
            _ec.hit_flash--;
            gpu_set_blendmode(bm_add);
            draw_sprite_ext(_espr, _espr_frame, _efx, _ey, _efs, _es, 0, c_white, (_ec.hit_flash / 15.0) * 0.8);
            gpu_set_blendmode(bm_normal);
        }
        // Looping status VFX over this enemy.
        if (variable_struct_exists(_ec, "status_effects")) {
            ui_draw_status_fx(_ex + sprite_get_width(_espr) * _es * 0.5, _ey,
                              sprite_get_height(_espr) * _es, _ec.status_effects);
        }
    }
    _espr_idx++;
}

// 2.5D volumetric props, NEAR pass (round 6): the foreground corner piece,
// drawn OVER the actors - a repoussoir frame that puts something between the
// camera and the fight, the strongest cheap depth cue in the reference.
ui_draw_25d_props(1);

// -----------------------------------------------------------------------------
// Conveyance (08-04): beam lances + traveling projectiles.
// -----------------------------------------------------------------------------
// Beams: an instant tapering lance source->target, gone in ~12 frames. The
// impact burst + popups were queued instantly at cast (beam mechanics don't defer).
var _kept_beams = [];
for (var _bmi = 0; _bmi < array_length(combat_beams); _bmi++) {
    var _bm = combat_beams[_bmi];
    _bm.t++;
    if (_bm.t <= _bm.dur) {
        var _bm_a = 1.0 - (_bm.t / _bm.dur);
        gpu_set_blendmode(bm_add);
        draw_set_alpha(0.85 * _bm_a);
        draw_line_width_color(_bm.sx + screen_shake_x, _bm.sy + screen_shake_y,
                              _bm.tx + screen_shake_x, _bm.ty + screen_shake_y, 10, _bm.col, _bm.col);
        draw_set_alpha(0.55 * _bm_a);
        draw_line_width_color(_bm.sx + screen_shake_x, _bm.sy - 3 + screen_shake_y,
                              _bm.tx + screen_shake_x, _bm.ty - 3 + screen_shake_y, 3, c_white, _bm.col);
        // Laser art overlay (08-11): the unTied beam segment tiled along the
        // lance over the additive core line. Guarded: pre-08-11 pushes and
        // tinted schools carry spr -1 (or no field) and keep the plain line.
        if (variable_struct_exists(_bm, "spr") && _bm.spr != -1) {
            var _bm_dir  = point_direction(_bm.sx, _bm.sy, _bm.tx, _bm.ty);
            var _bm_len  = point_distance(_bm.sx, _bm.sy, _bm.tx, _bm.ty);
            var _bm_cnt  = sprite_get_number(_bm.spr);
            var _bm_frm  = (_bm_cnt > 1) ? (_bm.t mod _bm_cnt) : 0;
            draw_set_alpha(0.9 * _bm_a);
            for (var _bd = 20; _bd < _bm_len - 10; _bd += 30) {
                draw_sprite_ext(_bm.spr, _bm_frm,
                    _bm.sx + lengthdir_x(_bd, _bm_dir) + screen_shake_x,
                    _bm.sy + lengthdir_y(_bd, _bm_dir) + screen_shake_y,
                    1.5, 1.5, _bm_dir, c_white, 1.0);
            }
        }
        gpu_set_blendmode(bm_normal);
        draw_set_alpha(1.0);
        array_push(_kept_beams, _bm);
    }
}
combat_beams = _kept_beams;

// Projectiles: fly caster->target over ~15 frames (slight arc, rotated to face
// travel; AoE bolts launch staggered via delay). The deferred hit presentation
// (flash, recoil, shake, impact burst) fires HERE at arrival - the matching
// damage popups and HP-drain hold were queued with the same delay at cast.
var _kept_proj = [];
for (var _pji = 0; _pji < array_length(combat_projectiles); _pji++) {
    var _pj = combat_projectiles[_pji];
    if (_pj.delay > 0) { _pj.delay--; array_push(_kept_proj, _pj); continue; }
    _pj.t++;
    var _pj_f = _pj.t / _pj.dur;
    if (_pj_f >= 1) {
        // Arrival: impact burst + the deferred hit feedback. Pacing scale
        // (08-13) rides the projectile so finisher bursts land big.
        array_push(vfx_bursts, { spr: _pj.impact_spr, x: _pj.bx, y: _pj.by,
            timer: _pj.ticks, timer_max: _pj.ticks, school: _pj.school,
            scale: variable_struct_exists(_pj, "scale") ? _pj.scale : 1 });
        if (_pj.tgt != undefined) { _pj.tgt.hit_flash = 15; _pj.tgt.hit_recoil = 10; }
        screen_shake_timer = max(screen_shake_timer, _pj.shake);
    } else {
        var _pj_x   = lerp(_pj.sx, _pj.tx, _pj_f) + screen_shake_x;
        var _pj_y   = lerp(_pj.sy, _pj.ty, _pj_f) - sin(_pj_f * pi) * 34 + screen_shake_y;
        var _pj_dir = point_direction(_pj.sx, _pj.sy, _pj.tx, _pj.ty);
        gpu_set_blendmode(bm_add);
        if (_pj.spr == -1) {
            if (variable_struct_exists(_pj, "aname") && _pj.aname == "Snipe") {
                // SNIPE (M 08-13: "a more powerful arrow shot, not the generic
                // dart"): a full fletched arrow - trailing speed lines, long
                // shaft, bright broadhead, red vanes.
                var _sn_dx = lengthdir_x(1, _pj_dir), _sn_dy = lengthdir_y(1, _pj_dir);
                var _sn_px = -_sn_dy, _sn_py = _sn_dx;
                draw_set_alpha(0.35);
                draw_line_width_color(_pj_x - _sn_dx * 150, _pj_y - _sn_dy * 150 - 4,
                                      _pj_x - _sn_dx * 58,  _pj_y - _sn_dy * 58  - 4, 2, c_gray, c_white);
                draw_line_width_color(_pj_x - _sn_dx * 130, _pj_y - _sn_dy * 130 + 5,
                                      _pj_x - _sn_dx * 50,  _pj_y - _sn_dy * 50  + 5, 2, c_gray, c_white);
                draw_set_alpha(0.95);
                draw_line_width_color(_pj_x - _sn_dx * 66, _pj_y - _sn_dy * 66, _pj_x, _pj_y, 4,
                                      make_color_rgb(150, 120, 80), make_color_rgb(220, 205, 170));
                draw_set_alpha(1.0);
                draw_set_color(make_color_rgb(240, 240, 255));
                draw_triangle(_pj_x + _sn_dx * 16, _pj_y + _sn_dy * 16,
                              _pj_x + _sn_px * 7,  _pj_y + _sn_py * 7,
                              _pj_x - _sn_px * 7,  _pj_y - _sn_py * 7, false);
                draw_set_color(make_color_rgb(200, 90, 80));
                draw_triangle(_pj_x - _sn_dx * 66 + _sn_px * 8, _pj_y - _sn_dy * 66 + _sn_py * 8,
                              _pj_x - _sn_dx * 66 - _sn_px * 8, _pj_y - _sn_dy * 66 - _sn_py * 8,
                              _pj_x - _sn_dx * 48, _pj_y - _sn_dy * 48, false);
                draw_set_color(c_white);
            } else {
                // Physical bolt: code-drawn streak (arrow/knife read), no sprite needed.
                var _pj_lx = lengthdir_x(38, _pj_dir);
                var _pj_ly = lengthdir_y(38, _pj_dir);
                draw_set_alpha(0.9);
                draw_line_width_color(_pj_x - _pj_lx, _pj_y - _pj_ly, _pj_x, _pj_y, 5, c_gray, c_white);
            }
        } else {
            var _pj_spr = school_vfx_sprite(_pj.spr, _pj.school);
            var _pj_cnt = sprite_get_number(_pj_spr);
            // Dedicated flight bolts (08-11) loop their WHOLE animation; burst
            // art doubling as a bolt cycles only the EARLY (ignition/bright)
            // frames - its late frames are dissipating smoke and read as the
            // wrong element (M 08-04: "scorch looks like a blue ball").
            var _pj_cyc = vfx_is_flight_bolt(_pj_spr) ? _pj_cnt : min(6, _pj_cnt);
            var _pj_frm = (_pj_cyc > 1) ? (_pj.t mod _pj_cyc) : 0;
            var _pj_sc  = 96 / max(1, sprite_get_width(_pj_spr));
            draw_set_alpha(0.95);
            draw_sprite_ext(_pj_spr, _pj_frm, _pj_x, _pj_y, _pj_sc, _pj_sc, _pj_dir,
                school_vfx_blend(_pj.school), 1.0);
        }
        gpu_set_blendmode(bm_normal);
        draw_set_alpha(1.0);
        array_push(_kept_proj, _pj);
    }
}
combat_projectiles = _kept_proj;

// VFX impact sprite: plays its frames, fades out and shrinks over its lifetime with
// additive blend. The sub-image is driven by the countdown so multi-frame Gigapack
// effects animate; single-frame sprites (spr_fx_impact) just hold frame 0. Scale is
// normalised by source width so 64px and 128px effects read at a consistent on-screen
// size.
if (vfx_timer > 0) {
    vfx_timer--;
    // Spell tint (Vael): an equipped palette swaps to the grayscale twin so the
    // blend color actually reads (multiplying into the authored yellow art barely
    // shifted it); default tint keeps the authored sprite as-is.
    var _vfx_draw   = school_vfx_sprite(vfx_spr, vfx_school);
    var _vfx_max    = (vfx_timer_max > 0) ? vfx_timer_max : 20;
    var _vfx_prog   = clamp((_vfx_max - vfx_timer) / _vfx_max, 0, 1);   // 0 -> 1 over life
    var _vfx_count  = sprite_get_number(_vfx_draw);
    var _vfx_frame  = clamp(floor(_vfx_prog * _vfx_count), 0, _vfx_count - 1);
    var _vfx_alpha  = min(1.0, vfx_timer / 10.0);
    var _vfx_target = lerp(248, 173, _vfx_prog) * vfx_scale_mult;       // on-screen px, shrinks; pacing scales finishers up
    var _vfx_scale  = _vfx_target / max(1, sprite_get_width(_vfx_draw));
    gpu_set_blendmode(bm_add);
    draw_set_alpha(_vfx_alpha);
    // Round 14 (M: Arcane Burst played bottom-right of the mob): these
    // sprites draw from their TOP-LEFT, but 2.5D feeds CENTER coords -
    // offset back by half the drawn size so the burst centres on the hit.
    var _vfx_co = combat_25d() ? _vfx_target * 0.5 : 0;
    draw_sprite_ext(_vfx_draw, _vfx_frame, vfx_x - _vfx_co + screen_shake_x, vfx_y - _vfx_co + screen_shake_y, _vfx_scale, _vfx_scale, 0, school_vfx_blend(vfx_school), 1.0);
    gpu_set_blendmode(bm_normal);
    draw_set_alpha(1.0);
}

// Multi-slot impact bursts (conveyance 08-04): projectile arrivals push here so
// staggered AoE impacts all play out instead of last-wins on the single slot
// above. Identical treatment to the single-slot draw.
var _kept_bursts = [];
for (var _vbi = 0; _vbi < array_length(vfx_bursts); _vbi++) {
    var _vb = vfx_bursts[_vbi];
    // Delayed bursts (08-13 glyph pairing): hold until the countdown expires,
    // then play normally - same idiom as projectile/popup delays.
    if (variable_struct_exists(_vb, "delay") && _vb.delay > 0) {
        _vb.delay--;
        array_push(_kept_bursts, _vb);
        continue;
    }
    _vb.timer--;
    if (_vb.timer > 0) {
        var _vb_draw  = school_vfx_sprite(_vb.spr, _vb.school);
        var _vb_max   = (_vb.timer_max > 0) ? _vb.timer_max : 20;
        var _vb_prog  = clamp((_vb_max - _vb.timer) / _vb_max, 0, 1);
        var _vb_cnt   = sprite_get_number(_vb_draw);
        var _vb_frm   = clamp(floor(_vb_prog * _vb_cnt), 0, _vb_cnt - 1);
        var _vb_alpha = min(1.0, _vb.timer / 10.0);
        var _vb_tgtpx = lerp(248, 173, _vb_prog)
                      * (variable_struct_exists(_vb, "scale") ? _vb.scale : 1);
        var _vb_sc    = _vb_tgtpx / max(1, sprite_get_width(_vb_draw));
        gpu_set_blendmode(bm_add);
        draw_set_alpha(_vb_alpha);
        var _vb_co = combat_25d() ? _vb_tgtpx * 0.5 : 0;   // round 14: centre on the hit
        draw_sprite_ext(_vb_draw, _vb_frm, _vb.x - _vb_co + screen_shake_x, _vb.y - _vb_co + screen_shake_y,
            _vb_sc, _vb_sc, 0,
            variable_struct_exists(_vb, "col") ? _vb.col : school_vfx_blend(_vb.school), 1.0);
        gpu_set_blendmode(bm_normal);
        draw_set_alpha(1.0);
        array_push(_kept_bursts, _vb);
    }
}
vfx_bursts = _kept_bursts;

// Floating damage / heal numbers
draw_set_font(fnt_ui);
draw_set_halign(fa_center);
draw_set_valign(fa_middle);
var _kept_popups = [];
for (var _di = 0; _di < array_length(damage_popups); _di++) {
    var _dp = damage_popups[_di];
    // 2.5D one-shot remap: (475,545) is the flat-mode "over the player" popup
    // anchor every player-hit site in Step pushes - shift it to the live 2.5D
    // torso HERE (one point) instead of touching a dozen call sites. The flag
    // stops it re-mapping as the popup drifts upward.
    if (combat_25d() && !variable_struct_exists(_dp, "p25_mapped")) {
        _dp.p25_mapped = true;
        if (_dp.x == 475 && _dp.y == 545) {
            var _pa25 = combat_player_vfx_anchor(player);
            _dp.x = _pa25.x + 110;
            _dp.y = _pa25.y + 70;
        }
    }
    // Staggered popups (e.g. multiple poison stacks ticking the same frame) hold
    // a countdown so they appear one after another instead of overlapping exactly.
    if (variable_struct_exists(_dp, "delay") && _dp.delay > 0) {
        _dp.delay--;
        // Combo-sequence tick (07-16): a popup carrying an sfx plays it the frame
        // its delay expires - the rising reveal ladder under SHATTER!/HEXED x2!.
        if (_dp.delay == 0 && variable_struct_exists(_dp, "sfx") && _dp.sfx != -1) {
            var _dp_si = audio_play_sound(_dp.sfx, 1, false);
            if (variable_struct_exists(_dp, "pitch")) audio_sound_pitch(_dp_si, _dp.pitch);
        }
        array_push(_kept_popups, _dp);
        continue;
    }
    _dp.timer--;
    _dp.y -= 1.0;
    if (_dp.timer > 0) {
        // Splash-text popups (combo sequence) draw their `text`; damage/heal
        // popups keep drawing the number.
        var _dp_str = variable_struct_exists(_dp, "text") ? _dp.text : string(_dp.value);
        var _dp_alpha = min(1.0, _dp.timer / 18.0);
        var _dp_scale = lerp(1.0, 1.5, clamp(_dp.timer / 50.0, 0, 1));
        draw_set_alpha(_dp_alpha);
        draw_set_color(c_black);
        draw_text_transformed(_dp.x + 2, _dp.y + 2, _dp_str, _dp_scale, _dp_scale, 0);
        draw_set_color(_dp.col);
        draw_text_transformed(_dp.x, _dp.y, _dp_str, _dp_scale, _dp_scale, 0);
        draw_set_alpha(1.0);
        array_push(_kept_popups, _dp);
    }
}
damage_popups = _kept_popups;
draw_set_font(-1);
draw_set_halign(fa_left);
draw_set_valign(fa_top);

// Combat text overlay (hit preview + combat log) - drawn AFTER the battler sprites
// and their shadows so combat text always has visual priority over them.
ui_draw_combat_overlay(combat_state, player, player.abilities, selected_ability, combat_log);

// Hover-explain tooltip for a status badge (set by ui_draw_status_icon_row above).
// Drawn here so it sits over the bars/HUD; later full-screen overlays (consumable
// menu, ability detail, loot, pause) draw afterwards and naturally occlude it.
if (global.combat_status_tip != undefined) {
    ui_draw_status_tooltip(global.combat_status_tip.x, global.combat_status_tip.y,
                           global.combat_status_tip.se);
}

// Enemy inspect tooltip - attack class + which controls stop the hovered foe. Drawn
// last (over bars/HUD) but suppressed while a status-badge tooltip is up, so the two
// hover popups don't overlap.
if (_inspect_target != undefined && global.combat_status_tip == undefined) {
    ui_draw_enemy_inspect_tooltip(_mx_gui, _my_gui, _inspect_target);
}

// -----------------------------------------------------------------------------
// 3a. AP SYSTEM OVERLAYS (player turn only)
// Drawn after the HUD so they appear on top of ability buttons.
// Button positions must match ui_draw_ability_buttons: x=240, y=990, 240x75, gap=12.
// -----------------------------------------------------------------------------
if (player_turn && !combat_over) {
    // Geometry from the shared source so the USED overlay lands on the real button
    // rects (touch widens the row - combat_ability_geom).
    var _abg_used = combat_ability_geom(array_length(player.abilities));
    var _btn_w   = _abg_used.w;
    var _btn_h   = _abg_used.h;
    var _btn_gap = _abg_used.gap;
    var _btn_x0  = _abg_used.x0;
    var _btn_y   = _abg_used.y;

    for (var _bi = 0; _bi < array_length(player.abilities); _bi++) {
        var _ab   = player.abilities[_bi];
        var _used = false;
        for (var _ui = 0; _ui < array_length(abilities_used_this_turn); _ui++) {
            if (abilities_used_this_turn[_ui] == _ab.name) { _used = true; break; }
        }
        if (_used) {
            var _bx = _btn_x0 + _bi * (_btn_w + _btn_gap);
            draw_set_alpha(0.62);
            draw_set_color(make_color_rgb(20, 15, 25));
            draw_rectangle(_bx, _btn_y, _bx + _btn_w, _btn_y + _btn_h, false);
            draw_set_alpha(1.0);
            draw_set_font(fnt_ui);
            draw_set_color(make_color_rgb(175, 85, 85));
            draw_set_halign(fa_center);
            draw_set_valign(fa_middle);
            draw_text(_bx + _btn_w / 2, _btn_y + _btn_h / 2, "USED");
            draw_set_font(-1);
            draw_set_halign(fa_left);
            draw_set_valign(fa_top);
        }
    }

    // End Turn prompt - brighter when out of AP to make it more visible
    var _ap_col;
    if (player.energy <= 0) {
        _ap_col = make_color_rgb(235, 195, 60);
    } else {
        _ap_col = make_color_rgb(130, 150, 115);
    }
    draw_set_font(fnt_ui);
    draw_set_halign(fa_center);
    // Touch (8c): the End Turn line becomes a real button - framed so it reads
    // as tappable; a tap fires a simulated T through the unchanged handler.
    if (input_device() == 2) {
        // Lifted 68px (M 07-18: "its almost overlapping with abilities"). It was
        // 924..984 while the TOUCH ability row is y=984 h=87 (combat_ability_geom)
        // - they shared an edge exactly, so a slightly high thumb on the leftmost
        // ability hit End Turn instead. 856..916 leaves a real 68px dead band.
        draw_set_color(make_color_rgb(20, 24, 36));
        draw_rectangle(750, 856, 1170, 916, false);
        // D-pad focus (07-24): gold double border while END TURN is the d-pad's
        // target (end_turn_focus, Step) so confirm-to-end-turn reads as armed.
        draw_set_color(end_turn_focus ? make_color_rgb(255, 224, 120) : _ap_col);
        draw_rectangle(750, 856, 1170, 916, true);
        if (end_turn_focus) draw_rectangle(753, 859, 1167, 913, true);
        draw_text(960, 872, "END TURN   " + string(player.energy) + " AP remaining");
        if (touch_tapped(750, 856, 1170, 916)) touch_press(ord("T"));
        // Companion GUARD toggle (07-24 audit: the G call-off verb had no touch
        // path). Same gate as the Step handler, so the button only exists when a
        // guarded-stance Warrior companion is actually intercepting. Sits left of
        // END TURN, clear of the d-pad gutter (its footprint is masked anyway).
        var _gd_pet = global.duel_active ? undefined : pet_active();   // duel: no companion, no GUARD button
        if (_gd_pet != undefined && !_gd_pet.is_egg && _gd_pet.stage >= PET_STAGE_YOUNGADULT
            && _gd_pet.archetype == PET_ARCH_COMBATANT && pet_stance(_gd_pet) == "guarded") {
            var _gd_off = pet_guard_off(_gd_pet);
            draw_set_color(make_color_rgb(20, 24, 36));
            draw_rectangle(490, 856, 730, 916, false);
            draw_set_color(_gd_off ? make_color_rgb(150, 120, 70) : make_color_rgb(120, 150, 190));
            draw_rectangle(490, 856, 730, 916, true);
            draw_set_font(fnt_ui_small);
            draw_set_color(_gd_off ? make_color_rgb(215, 180, 120) : make_color_rgb(190, 210, 235));
            draw_text(610, 872, _gd_off ? "GUARD: OFF" : "GUARD: ON");
            draw_set_font(fnt_ui);
            if (touch_tapped(490, 856, 730, 916)) touch_press(ord("G"));
        }
    } else {
        // M 08-08: this was bare text over the dungeon art and went nearly
        // invisible on busy backgrounds (Ashen Vault floor 3). Faded is fine while
        // you still have AP, but never ILLEGIBLE - so it gets a measured backdrop,
        // and at 0 AP the whole thing pulses so "you are done, end the turn" can't
        // be missed against any background.
        var _et_txt = ((input_device() == 1) ? "RT: End Turn   " : "T: End Turn   ")
                    + string(player.energy) + " AP remaining";
        var _et_w   = string_width(_et_txt) + 44;
        var _et_x0  = 960 - _et_w / 2, _et_x1 = 960 + _et_w / 2;
        var _et_out = (player.energy <= 0);
        // 0 AP: a slow bright pulse. Above 0 it sits still and quiet.
        var _et_pulse = _et_out ? (0.55 + 0.45 * (0.5 + 0.5 * sin(current_time / 260))) : 1.0;

        // Band slimmed 56 -> 36 tall (M 08-11 screenshot: the old y936-992 box
        // overlapped BOTH neighbours - the combat log ends y945 and the touch
        // ability row starts y984). y946-982 sits exactly in the corridor.
        draw_set_alpha(_et_out ? 0.88 : 0.62);
        draw_set_color(make_color_rgb(10, 11, 17));
        draw_rectangle(_et_x0, 946, _et_x1, 982, false);
        draw_set_alpha(1.0);

        if (end_turn_focus) {
            draw_set_color(make_color_rgb(255, 224, 120));
            draw_rectangle(700, 946, 1220, 982, true);
        } else if (_et_out) {
            draw_set_alpha(_et_pulse);
            draw_set_color(_ap_col);
            draw_rectangle(_et_x0, 946, _et_x1, 982, true);
            draw_set_alpha(1.0);
        }

        draw_set_alpha(_et_pulse);
        draw_set_color(end_turn_focus ? make_color_rgb(255, 224, 120) : _ap_col);
        draw_text(960, 950, _et_txt);
        draw_set_alpha(1.0);
    }
    draw_set_font(-1);
    draw_set_halign(fa_left);
}


// Stash is hub-only - button not shown during combat.

// --- ITEMS button (bottom-right, always visible during player turn) ---
if (player_turn && !combat_over) {
    // Small framed button, far bottom-right so it clears the ability tooltip
    // (x1260-1740). Toggles the quick menu; bound to the C key (Step_0 reads ord("C")).
    // Coords must stay in sync with the click hit-test in Step_0.
    // Geometry from the shared source (combat_items_button_geom) so the draw and
    // the Step_0 hit-test can't drift - on touch it relocates to the gutter.
    var _ibg = combat_items_button_geom();
    var _ibx = _ibg.x1;
    var _iby = _ibg.y1;
    var _ibw = _ibg.w;
    var _ibh = _ibg.h;
    var _cx  = _ibx + _ibw / 2;
    var _has_consumables = variable_global_exists("consumable_inventory")
                           && array_length(global.consumable_inventory) > 0;

    // Per-state colors + subtitle.
    var _fill   = make_color_rgb(28, 28, 38);
    var _border = make_color_rgb(45, 48, 65);
    var _tcol   = make_color_rgb(55, 60, 82);
    var _scol   = make_color_rgb(45, 50, 68);
    var _sub    = "none";
    if (_has_consumables) {
        _fill   = consumable_quick_open ? make_color_rgb(28, 55, 40) : make_color_rgb(18, 40, 28);
        _border = consumable_quick_open ? make_color_rgb(60, 190, 110) : make_color_rgb(35, 130, 70);
        _tcol   = c_white;
        _scol   = make_color_rgb(100, 200, 140);
        _sub    = "x" + string(array_length(global.consumable_inventory)) + " held";
    }

    draw_set_alpha(1.0);
    // Fill
    draw_set_color(_fill);
    draw_rectangle(_ibx, _iby, _ibx + _ibw, _iby + _ibh, false);
    // Framed double border (dark outer edge + brighter inner edge) so it reads as a button.
    draw_set_color(make_color_rgb(10, 12, 18));
    draw_rectangle(_ibx, _iby, _ibx + _ibw, _iby + _ibh, true);
    draw_set_color(_border);
    draw_rectangle(_ibx + 2, _iby + 2, _ibx + _ibw - 2, _iby + _ibh - 2, true);

    // Labels - real fonts at native size (fit comfortably in the button).
    draw_set_font(fnt_ui_small);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    // Touch has no keyboard, so naming the C key there is noise (M 07-18: "it
    // says C in mobile and it should say keyboard controls"). Inner ternary is
    // parenthesised - GML/Android rejects an unbracketed nested ternary.
    var _title = (input_device() == 1) ? "[ LT ] ITEMS"
               : ((input_device() == 2) ? "ITEMS" : "[ C ] ITEMS");
    draw_set_color(_tcol);
    draw_text(_cx, _iby + _ibh / 2 - 12, _title);
    draw_set_color(_scol);
    draw_text(_cx, _iby + _ibh / 2 + 12, _sub);
    draw_set_font(-1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);

    // --- Consumable quick-use popup ---
    // Opens even with an empty run buffer (shows "No consumables held.") so the
    // [C] button never silently no-ops. Stash consumables stay hub-only.
    if (consumable_quick_open) {
        // Grouped view: identical consumables collapse to one "Name xN" row (the real
        // array still holds N entries). Step uses the same grouping for nav + use.
        var _qgroups = consumables_grouped();
        var _qcount  = array_length(_qgroups);
        // Windowed list - cap visible rows and scroll around the cursor so the
        // selection is always on screen. Step's mouse hit-test uses the same math.
        var _q_max_vis = 6;
        var _q_vis     = min(_qcount, _q_max_vis);
        var _q_first   = ui_list_window("combat_quick", consumable_quick_cursor, _qcount, _q_max_vis);
        var _q_last    = min(_qcount, _q_first + _q_max_vis);
        var _pw     = 750;
        var _ph     = 84 + _q_vis * 108 + 66;
        var _px     = 960 - _pw / 2;
        var _py     = max(120, 990 - _ph - 21);

        // Background
        draw_set_alpha(0.97);
        draw_set_color(make_color_rgb(12, 16, 28));
        draw_rectangle(_px, _py, _px + _pw, _py + _ph, false);
        draw_set_alpha(1.0);
        draw_set_color(make_color_rgb(55, 170, 100));
        draw_rectangle(_px, _py, _px + _pw, _py + _ph, true);

        // Header
        draw_set_font(fnt_ui);
        draw_set_halign(fa_center);
        draw_set_color(c_white);
        var _qhdr = (_qcount > 0) ? "USE CONSUMABLE  (1 AP)" : "CONSUMABLES";
        if (_qcount > _q_max_vis) _qhdr += "   (" + string(consumable_quick_cursor + 1) + "/" + string(_qcount) + ")";
        draw_text(_px + _pw / 2, _py + 21, _qhdr);
        // Scroll hints
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(120, 210, 160));
        if (_q_first > 0)        ui_draw_scroll_more(_px + _pw / 2, _py + 54, true, "more");
        if (_q_last < _qcount)   ui_draw_scroll_more(_px + _pw / 2, _py + _ph - 66, false, "more");

        // Empty-state message (run buffer holds no consumables this run).
        if (_qcount == 0) {
            draw_set_font(fnt_ui);
            draw_set_halign(fa_center);
            draw_set_color(make_color_rgb(150, 165, 185));
            draw_text(_px + _pw / 2, _py + _ph / 2 - 6, "No consumables held.");
        }

        // Item rows
        for (var _qi = _q_first; _qi < _q_last; _qi++) {
            var _qitem  = _qgroups[_qi].item;
            var _qlabel = consumable_group_label(_qgroups[_qi]);
            var _qry    = _py + 75 + (_qi - _q_first) * 108;
            var _is_cur  = (_qi == consumable_quick_cursor);
            // ARMED row (touch confirm gate): pressed once, awaiting the second
            // press. It has to look unmistakably different from merely selected,
            // or the two-step reads as "my tap did nothing".
            var _is_armed = (consumable_confirm_idx == _qi);

            draw_set_alpha(_is_cur ? 1.0 : 0.65);
            draw_set_color(_is_armed ? make_color_rgb(62, 48, 16)
                                     : (_is_cur ? make_color_rgb(22, 55, 35) : make_color_rgb(14, 18, 30)));
            draw_rectangle(_px + 15, _qry, _px + _pw - 15, _qry + 93, false);
            draw_set_alpha(1.0);
            draw_set_color(_is_armed ? make_color_rgb(245, 195, 80)
                                     : (_is_cur ? make_color_rgb(60, 200, 110) : make_color_rgb(35, 80, 52)));
            draw_rectangle(_px + 15, _qry, _px + _pw - 15, _qry + 93, true);
            if (_is_armed) {   // second, inset ring - reads as "armed", not just hovered
                draw_rectangle(_px + 18, _qry + 3, _px + _pw - 18, _qry + 90, true);
            }

            // Icon badge on the left (visual liveliness - matches the gear/shop look).
            var _qisz = 68;
            ui_draw_consumable_icon(_px + 30, _qry + 13, _qisz, _qitem);
            var _qtx = _px + 30 + _qisz + 16;

            draw_set_halign(fa_left);
            draw_set_font(fnt_ui);
            draw_set_color(_is_cur ? c_white : make_color_rgb(160, 175, 195));
            draw_text(_qtx, _qry + 12, _qlabel);
            draw_set_font(fnt_ui_small);
            if (_is_armed) {
                draw_set_color(make_color_rgb(245, 205, 120));
                draw_text(_qtx, _qry + 48, "Tap again to use   -   tap elsewhere to cancel");
            } else {
                draw_set_color(_is_cur ? make_color_rgb(120, 210, 160) : make_color_rgb(80, 110, 95));
                draw_text(_qtx, _qry + 48, ui_sentence(_qitem.description));
            }
        }

        // Footer hint - touch names taps, not keys it doesn't have.
        var _qfoot;
        if (_qcount == 0) {
            _qfoot = (input_device() == 2) ? "Tap outside to close" : "C/Esc: Close";
        } else if (input_device() == 2) {
            _qfoot = "Tap an item, then tap again to confirm";
        } else {
            _qfoot = "W/S: Navigate   Enter/Click: Use   C/Esc: Close";
        }
        ui_draw_key_legend(_px + _pw / 2, _py + _ph - 42, _qfoot);
        draw_set_font(-1);
        draw_set_halign(fa_left);
        draw_set_alpha(1.0);
    }
}


// -----------------------------------------------------------------------------
// 3b. LEVEL-UP ALLOCATION OVERLAY
// Drawn after combat victory when the player has unspent stat points.
// Provisional flow: Space selects a stat, Enter commits it permanently.
// -----------------------------------------------------------------------------
if (instance_exists(obj_game_controller)) {
    var _gc_alloc_draw = instance_find(obj_game_controller, 0);
    if (_gc_alloc_draw.level_alloc_open) {

        draw_set_alpha(0.94);
        draw_set_color(make_color_rgb(8, 10, 18));
        draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
        draw_set_alpha(1.0);

        var _pend_idx   = _gc_alloc_draw.level_alloc_pending_stat;   // -1 = none
        var _has_pend   = (_pend_idx >= 0);

        draw_set_halign(fa_center);
        draw_set_font(fnt_ui_title);
        draw_set_color(c_lime);
        draw_text(960, 90, "LEVEL UP  -  Level " + string(global.run_level));

        draw_set_font(fnt_ui);
        draw_set_color(c_yellow);
        var _pts_str;
        if (global.pending_stat_points == 1) {
            _pts_str = "1 point";
        } else {
            _pts_str = string(global.pending_stat_points) + " points";
        }
        if (input_device() == 2) {
            draw_text_outline(960, 158, "Allocate " + _pts_str + "   (tap a stat, then CONFIRM)");
        } else if (_has_pend) {
            draw_text(960, 158, "Allocate " + _pts_str + "   (Enter: change choice   Space: confirm)");
        } else {
            draw_text_outline(960, 158, "Allocate " + _pts_str + "   (W/S: Navigate   Enter: choose stat)");
        }

        draw_set_halign(fa_left);

        var _alloc_stat_names = ["STR", "DEX", "CON", "INT", "WIS", "CHA"];
        var _alloc_stat_descs = ["Strength", "Dexterity", "Constitution", "Intelligence", "Wisdom", "Charisma"];
        var _alloc_stat_hints = [
            "Boosts physical ability dmg  *  Phys dmg reduction  *  Power crit +1.5% (x1.6 dmg)",
            "+3 accuracy  *  +2 dodge  *  Precision crit +2% (x1.35 dmg)",
            "+3 max HP per point",
            "Boosts elemental ability dmg  *  Arcane crit +1% (x1.25 dmg)",
            "Boosts DoT / status effect dmg  *  Effect crit +1.5% (extends statuses)",
            "Boosts ALL ability damage  *  +1% gold find/pt  *  cheaper NPC prices (1.5%/pt, max 30%)"
        ];

        // Layout: wider boxes with the hint wrapped INSIDE the box, and a uniform
        // box height derived from the tallest wrapped hint so no text ever spills
        // past the border. The value sits on the label row, top-right.
        var _bx_l    = 435;
        var _bx_r    = 1485;
        var _bx_padx = 33;
        var _hint_lh = 29;
        var _hint_w  = (_bx_r - _bx_l) - _bx_padx * 2;

        // Hint font drives both the measured box height and the drawn hints below.
        draw_set_font(fnt_ui_small);
        var _max_hint_h = 0;
        for (var _hi = 0; _hi < 6; _hi++) {
            _max_hint_h = max(_max_hint_h, string_height_ext(_alloc_stat_hints[_hi], _hint_lh, _hint_w));
        }
        var _bx_h     = 39 + _max_hint_h + 18;   // label row + wrapped hint + padding
        var _row_step = _bx_h + 15;
        var _alloc_y0 = 210;

        for (var _si = 0; _si < 6; _si++) {
            var _sy      = _alloc_y0 + _si * _row_step;
            var _is_sel  = (_si == _gc_alloc_draw.level_alloc_index);
            var _is_pend = (_si == _pend_idx);
            var _cur_val = variable_struct_get(player.stats, _alloc_stat_names[_si]);

            // Background
            var _bg_col;
            if (_is_pend)      _bg_col = make_color_rgb(48, 32, 8);
            else if (_is_sel)  _bg_col = make_color_rgb(30, 50, 90);
            else               _bg_col = make_color_rgb(18, 22, 38);
            draw_set_alpha((_is_sel || _is_pend) ? 1.0 : 0.6);
            draw_set_color(_bg_col);
            draw_rectangle(_bx_l, _sy, _bx_r, _sy + _bx_h, false);
            draw_set_alpha(1.0);

            // Border - amber for pending, blue for selected cursor, gray otherwise
            var _bd_col;
            if (_is_pend)      _bd_col = make_color_rgb(220, 145, 35);
            else if (_is_sel)  _bd_col = make_color_rgb(80, 140, 220);
            else               _bd_col = make_color_rgb(45, 55, 75);
            draw_set_color(_bd_col);
            draw_rectangle(_bx_l, _sy, _bx_r, _sy + _bx_h, true);

            // Stat label
            var _lbl_col;
            if (_is_pend)      _lbl_col = make_color_rgb(235, 165, 50);
            else if (_is_sel)  _lbl_col = c_white;
            else               _lbl_col = make_color_rgb(140, 150, 170);
            draw_set_font(fnt_ui);
            draw_set_color(_lbl_col);
            draw_text(_bx_l + _bx_padx, _sy + 9, _alloc_stat_descs[_si] + "  (" + _alloc_stat_names[_si] + ")");

            // Value - right-aligned on the label row; "X -> X+1" when pending
            draw_set_halign(fa_right);
            if (_is_pend) {
                draw_set_color(make_color_rgb(235, 165, 50));
                draw_text(_bx_r - _bx_padx, _sy + 9, string(_cur_val) + "  ->  " + string(_cur_val + 1));
            } else {
                draw_set_color(_lbl_col);
                draw_text(_bx_r - _bx_padx, _sy + 9, string(_cur_val));
            }
            draw_set_halign(fa_left);

            // Wrapped hint on the line(s) below the label
            var _hint_col = (_is_sel || _is_pend) ? make_color_rgb(170, 188, 215) : make_color_rgb(95, 105, 128);
            draw_set_font(fnt_ui_small);
            draw_set_color(_hint_col);
            draw_text_ext(_bx_l + _bx_padx, _sy + 42, _alloc_stat_hints[_si], _hint_lh, _hint_w);
        }

        // Touch (8d, M 07-08 softlock): tap a stat row to choose it (sets the
        // cursor + fires the same Enter path), CONFIRM button commits (Space).
        var _alloc_footer_y = _alloc_y0 + 6 * _row_step + 12;
        if (input_device() == 2) {
            if (mouse_check_button_pressed(mb_left)) {
                var _amx = device_mouse_x_to_gui(0);
                var _amy = device_mouse_y_to_gui(0);
                if (_amx >= _bx_l && _amx <= _bx_r && _amy >= _alloc_y0 && _amy < _alloc_y0 + 6 * _row_step) {
                    var _ati = (_amy - _alloc_y0) div _row_step;
                    if (_ati >= 0 && _ati < 6 && (_amy - _alloc_y0) - _ati * _row_step <= _bx_h) {
                        _gc_alloc_draw.level_alloc_index = _ati;
                        touch_press(vk_enter);
                    }
                }
            }
            if (_has_pend) {
                var _cbx1 = 960 - 195, _cby1 = _alloc_footer_y - 6;
                var _cbx2 = 960 + 195, _cby2 = _cby1 + 63;
                draw_set_color(make_color_rgb(22, 42, 20));
                draw_rectangle(_cbx1, _cby1, _cbx2, _cby2, false);
                draw_set_color(c_lime);
                draw_rectangle(_cbx1, _cby1, _cbx2, _cby2, true);
                draw_set_font(fnt_ui);
                draw_set_halign(fa_center); draw_set_valign(fa_middle);
                draw_set_color(c_white);
                draw_text(960, (_cby1 + _cby2) / 2, "CONFIRM");
                draw_set_valign(fa_top);
                if (touch_tapped(_cbx1, _cby1, _cbx2, _cby2)) touch_press(vk_space);
            }
        }
        draw_set_font(fnt_ui_small);
        draw_set_halign(fa_center);
        draw_set_color(make_color_rgb(80, 90, 110));
        if (input_device() != 2) {
            if (_has_pend) {
                ui_draw_key_legend(960, _alloc_footer_y, "W/S: Navigate   Enter: Change selection   Space: Confirm");
            } else {
                ui_draw_key_legend(960, _alloc_footer_y, "W/S: Navigate   Enter: Choose stat");
            }
        }
        draw_set_font(-1);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);
        draw_set_alpha(1.0);

        ui_draw_character_menu();
        // Early exit skips ui_draw_touch_back at the bottom of this Draw, so pump
        // the simulated-key releaser here or touch keys stay held for the whole
        // overlay - the SECOND row tap then fires no Enter edge and the alloc
        // goes deaf (M 07-08: "stayed on the stat screen ... never proceeded").
        touch_sim_pump();
        exit;
    }
}


// -----------------------------------------------------------------------------
// 4. LOOT SCREEN OVERLAY - shown after combat when items dropped this room
// -----------------------------------------------------------------------------
if (show_loot_screen) {

    // Full-screen dark cover
    draw_set_alpha(0.92);
    draw_set_color(make_color_rgb(10, 12, 22));
    draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
    draw_set_alpha(1.0);

    // Title
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_set_font(fnt_ui_title);
    draw_set_color(c_yellow);
    draw_text(960, 90, "LOOT FOUND");

    draw_set_font(fnt_ui);
    draw_set_color(make_color_rgb(160, 160, 180));
    draw_text(960, 173, "Items collected this room:");

    // Item rows (staggered reveal: Step advances loot_reveal_shown + plays the
    // tick/stinger; rows past it stay hidden until their beat lands)
    var _item_n  = array_length(global.run_items_found);
    var _lt_count = _item_n + array_length(loot_special_rows);   // (not `_count` - already declared earlier this event, GM2044)
    var _visible = min(8, _lt_count);
    _visible = min(_visible, loot_reveal_shown);

    for (var _i = 0; _i < _visible; _i++) {
        var _idx = _i + loot_screen_scroll;
        if (_idx >= _lt_count) break;
        var _iy   = 240 + _i * 98;

        // SPECIAL rows (M 07-28 spectacle): pet eggs, the Banshee Bottle, and
        // signature trinkets drawn gold-framed after the item rows.
        if (_idx >= _item_n) {
            var _sp = loot_special_rows[_idx - _item_n];
            draw_set_alpha(0.6);
            draw_set_color(make_color_rgb(40, 32, 12));
            draw_rectangle(360, _iy - 8, 1560, _iy + 75, false);
            draw_set_alpha(1.0);
            draw_set_color(make_color_rgb(210, 175, 90));
            draw_rectangle(360, _iy - 8, 1560, _iy + 75, true);
            var _sp_spr = -1;
            if (_sp.kind == "pet")          _sp_spr = pet_sprite(_sp.pet);
            else if (_sp.kind == "banshee") _sp_spr = asset_get_index("spr_icon_banshee_bottle");
            else if (_sp.kind == "trinket") _sp_spr = asset_get_index("spr_icon_trinket_" + _sp.id);
            if (_sp_spr >= 0) {
                // Origin-aware centering into the 66px icon box (pet art is
                // often feet-anchored, so place by top-left + origin offset).
                var _sp_w  = sprite_get_width(_sp_spr);
                var _sp_h  = sprite_get_height(_sp_spr);
                var _sp_sc = 66 / max(1, max(_sp_w, _sp_h));
                draw_sprite_ext(_sp_spr, pet_anim_frame(_sp_spr),
                    372 + (66 - _sp_w * _sp_sc) / 2 + sprite_get_xoffset(_sp_spr) * _sp_sc,
                    _iy  + (66 - _sp_h * _sp_sc) / 2 + sprite_get_yoffset(_sp_spr) * _sp_sc,
                    _sp_sc, _sp_sc, 0, c_white, 1);
            }
            draw_set_font(fnt_ui);
            draw_set_halign(fa_left);
            draw_set_color(make_color_rgb(255, 220, 130));
            draw_text(456, _iy + 8, _sp.label);
            draw_set_font(fnt_ui_small);
            draw_set_color(make_color_rgb(205, 198, 170));
            draw_text(456, _iy + 42, _sp.sub);
            draw_set_halign(fa_right);
            draw_set_color(make_color_rgb(235, 200, 110));
            draw_text(1530, _iy + 8, _sp.tag);
            draw_set_halign(fa_left);
            continue;
        }
        var _item = global.run_items_found[_idx];

        // Row background
        draw_set_alpha(0.5);
        draw_set_color(make_color_rgb(20, 25, 45));
        draw_rectangle(360, _iy - 8, 1560, _iy + 75, false);
        draw_set_alpha(1.0);

        var _is_consumable = variable_struct_exists(_item, "item_category")
                             && _item.item_category == "consumable";

        if (_is_consumable) {
            ui_draw_consumable_icon(372, _iy, 66, _item);
            draw_set_font(fnt_ui);
            draw_set_color(ui_consumable_name_color(_item));   // Genie Lamp reads legendary gold
            draw_set_halign(fa_left);
            draw_text(456, _iy + 8, _item.name);
            draw_set_font(fnt_ui_small);
            draw_set_color(make_color_rgb(140, 200, 200));
            draw_text(456, _iy + 42, ui_sentence(_item.description));
            draw_set_halign(fa_right);
            draw_set_color(make_color_rgb(80, 200, 200));
            draw_text(1530, _iy + 8, "[CONSUMABLE]");
        } else {
            var _rarity_col = item_rarity_color(_item.rarity);
            ui_draw_item_icon(372, _iy, 66, _item);
            draw_set_font(fnt_ui);
            draw_set_color(_rarity_col);
            draw_set_halign(fa_left);
            draw_text(456, _iy + 3, _item.name);
            // Class restriction tag after the name (gold = your class, red = locked).
            // Standardized with the loadout tooltip / Dorn shop so it shows everywhere.
            var _loot_cr = variable_struct_exists(_item, "class_req") ? _item.class_req : -1;
            if (_loot_cr != -1) {
                var _loot_cr_names = ["Arcanist", "Bloodwarden", "Shadowstrider"];
                var _loot_my_cl    = variable_global_exists("chosen_class") ? global.chosen_class : -1;
                // Measure the name in fnt_ui (its draw font) BEFORE the switch to
                // fnt_ui_small, or the tag lands mid-name on long items.
                var _loot_name_w = string_width(_item.name);
                draw_set_font(fnt_ui_small);
                draw_set_color((_loot_cr == _loot_my_cl) ? make_color_rgb(210, 175, 90) : make_color_rgb(225, 80, 80));
                draw_text(456 + _loot_name_w + 18, _iy + 9,
                    "[" + _loot_cr_names[clamp(_loot_cr, 0, 2)] + " only]");
                draw_set_font(fnt_ui);
            }
            // Stat line (e.g. "+4 STR, +12 HP") so found gear is readable at a glance.
            // Scale it down to ONE line within the left content area so a many-affix
            // item can't overrun the right-hand rarity/slot/req column.
            draw_set_font(fnt_ui_small);
            draw_set_color(c_white);
            draw_set_halign(fa_left);
            ui_draw_stat_line_fit(456, _iy + 33, ui_item_stat_str(_item), 1230 - 456);
            draw_set_color(make_color_rgb(160, 165, 185));
            draw_text(456, _iy + 60, _item.effect_desc);
            // Right column (right-aligned): rarity, slot, and stat requirement - kept
            // separate from the stat line so they never overlap. Requirement is red
            // when the current class can't meet it (equipping is hard-blocked).
            draw_set_halign(fa_right);
            draw_set_color(_rarity_col);
            draw_text(1530, _iy + 6, "[" + item_rarity_name(_item.rarity) + "]");
            draw_set_color(make_color_rgb(140, 140, 100));
            draw_text(1530, _iy + 33, "Slot: " + item_slot_label(_item.slot));
            var _lreq = item_stat_requirement(_item);
            if (_lreq.value > 0 && _lreq.stat != "") {
                draw_set_color((player_base_stat(_lreq.stat) >= _lreq.value)
                    ? make_color_rgb(110, 170, 110) : make_color_rgb(225, 80, 80));
                draw_text(1530, _iy + 58, "Req " + string(_lreq.value) + " " + _lreq.stat);
            }
        }
    }

    // Fortune's Favor chip (POTENCY V2, Lucky Find T5): once-per-run reroll of
    // the top listed equipment drop. Rect (1560,96)-(1870,168) MUST match the
    // Step_0 hit-test. Greyed once spent or when the top row is a consumable.
    if (trait_transcended("Lucky Find")) {
        var _ffd_used = variable_global_exists("fortune_favor_used") && global.fortune_favor_used;
        var _ffd_idx  = clamp(loot_screen_scroll, 0, max(0, _item_n - 1));
        var _ffd_top  = (_item_n > 0 && loot_screen_scroll < _item_n) ? global.run_items_found[_ffd_idx] : undefined;
        var _ffd_eq   = is_struct(_ffd_top) && variable_struct_exists(_ffd_top, "rarity")
            && !(variable_struct_exists(_ffd_top, "item_category") && _ffd_top.item_category == "consumable");
        var _ffd_on   = !_ffd_used && _ffd_eq;
        draw_set_color(_ffd_on ? make_color_rgb(40, 34, 14) : make_color_rgb(18, 19, 26));
        draw_rectangle(1560, 96, 1870, 168, false);
        draw_set_color(_ffd_on ? make_color_rgb(210, 175, 90) : make_color_rgb(50, 52, 66));
        draw_rectangle(1560, 96, 1870, 168, true);
        draw_set_halign(fa_center);
        draw_set_font(fnt_ui_small);
        draw_set_color(_ffd_on ? make_color_rgb(235, 210, 140) : make_color_rgb(100, 104, 118));
        draw_text(1715, 104, "FORTUNE'S FAVOR" + ((input_device() == 2) ? "" : "  [V]"));
        draw_text(1715, 134, _ffd_used ? "spent this run"
            : (_ffd_eq ? "reroll the top item" : "scroll to an equipment find"));
        draw_set_halign(fa_left);
    }

    // Scroll hint (only when list overflows)
    draw_set_halign(fa_center);
    draw_set_font(fnt_ui_small);
    if (_lt_count > 8 && input_device() != 2) {   // touch: drag-to-scroll, no keyboard hint
        draw_set_color(make_color_rgb(120, 130, 150));
        draw_text_outline(960, 953, "W/S to scroll");
    }

    draw_set_font(fnt_ui);
    draw_set_color(c_white);
    draw_text(960, 990, (input_device() == 2) ? "Tap to continue" : "Enter / R to continue");

    draw_set_font(-1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1.0);
    ui_draw_character_menu();
    touch_sim_pump();   // early exit skips the bottom-of-Draw pump (see alloc note)
    exit;
}


// -----------------------------------------------------------------------------
// 4b. CONSUMABLE OVERFLOW PROMPT - pack-full pickups awaiting a discard choice.
// Only shown once the fight is won (no living enemies), matching the Step gate
// in the victory path - so it never interrupts an ongoing battle.
// -----------------------------------------------------------------------------
// The DRAW gate must match the Step victory chain (level-up -> loot -> overflow),
// or the modal appears out of order. It used to fire the instant the last enemy
// died, so the discard prompt flashed up, got buried under the level-up and loot
// screens, then reappeared afterwards - M 07-18: "clunky and unpolished". Waiting
// for both screens gives M's preferred option: the pack-full prompts run as one
// uninterrupted block AFTER the other post-combat screens.
var _ovf_alloc_open = false;
if (instance_exists(obj_game_controller)) {
    _ovf_alloc_open = instance_find(obj_game_controller, 0).level_alloc_open;
}
if (!combat_over && consumable_overflow_pending()
    && !_ovf_alloc_open && !show_loot_screen
    && array_length(combat_living_enemies(combat_state)) == 0) {
    ui_draw_consumable_overflow();
    touch_sim_pump();   // early exit skips the bottom-of-Draw pump (see alloc note)
    exit;
}


// DUEL PAR CHIP (DESIGN_DUELIST_CHALLENGE.md): visible from round 1 - par,
// current round, and the grade the clock currently reads (gold/steel/bronze
// tint). Top-center strip, measured width, clear of the side HUDs and the log.
if (global.duel_active && !combat_over) {
    var _dp_par = variable_global_exists("duel_par") ? global.duel_par : 6;
    var _dp_rnd = combat_state.round;
    var _dp_txt = "DUEL  -  PAR " + string(_dp_par) + " TURNS  -  ROUND " + string(_dp_rnd);
    var _dp_col = (_dp_rnd <= _dp_par) ? make_color_rgb(235, 200, 110)
                : ((_dp_rnd <= _dp_par + 2) ? make_color_rgb(200, 205, 215) : make_color_rgb(205, 140, 100));
    draw_set_font(fnt_ui_small);
    var _dp_w  = string_width(_dp_txt) + 44;
    var _dp_x0 = GUI_CX - _dp_w * 0.5, _dp_y0 = 8, _dp_x1 = GUI_CX + _dp_w * 0.5, _dp_y1 = 48;
    draw_set_alpha(0.85);
    draw_set_color(make_color_rgb(26, 20, 14));
    draw_rectangle(_dp_x0, _dp_y0, _dp_x1, _dp_y1, false);
    draw_set_alpha(1.0);
    draw_set_color(_dp_col);
    draw_rectangle(_dp_x0, _dp_y0, _dp_x1, _dp_y1, true);
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    draw_text(GUI_CX, _dp_y0 + 10, _dp_txt);
    draw_set_halign(fa_left);
    draw_set_font(-1);
}

// -----------------------------------------------------------------------------
// 5. COMBAT RESULT OVERLAY
// Drawn on top of everything when combat is resolved.
// -----------------------------------------------------------------------------
if (combat_over) {

    // Stop battle music and start result music - fires exactly once
    if (!combat_music_stopped) {
        combat_music_stopped = true;
        audio_stop_sound(_3_critical_LOOP);
        audio_stop_sound(_14_BOSS_y_LOOP);
        if (combat_result == -1) {
            audio_play_sound(_15_game_over_INITIAL, 1, true);
        }
        if (combat_result == 1
            && variable_global_exists("current_floor") && global.current_floor >= 3
            && variable_global_exists("just_cleared_boss") && global.just_cleared_boss) {
            audio_play_sound(MusicBox1, 1, true);
        }
    }

    // Semi-transparent black vignette over the full screen
    draw_set_alpha(0.65);
    draw_set_color(c_black);
    draw_rectangle(GUI_XL, 0, GUI_XR, GUI_H, false);
    draw_set_alpha(1.0);

    // Centre-screen text
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);

    var _cx = 960;
    var _cy = 480;

    draw_set_font(fnt_ui_title);
    if (combat_result == 1) {
        // Victory - drop shadow + main, drawn with the native title font
        draw_set_color(make_color_rgb(0, 60, 0));
        draw_text(_cx + 5, _cy + 5, "VICTORY");
        draw_set_color(c_green);
        draw_text(_cx, _cy, "VICTORY");

    } else if (combat_result == -1) {
        // Defeat
        draw_set_color(make_color_rgb(80, 0, 0));
        draw_text(_cx + 5, _cy + 5, "DEFEATED");
        draw_set_color(c_red);
        draw_text(_cx, _cy, "DEFEATED");

    } else if (combat_result == 2) {
        // Duel mercy (DESIGN_DUELIST_CHALLENGE.md): a loss, never a death.
        draw_set_color(make_color_rgb(70, 45, 20));
        draw_text(_cx + 5, _cy + 5, "THE DUEL ENDS");
        draw_set_color(make_color_rgb(230, 170, 110));
        draw_text(_cx, _cy, "THE DUEL ENDS");
    }

    // Run summary
    draw_set_font(fnt_ui);
    draw_set_halign(fa_center);
    var _summary_y = _cy + 75;

    // Duel epilogue lines - the grade on a win, his mercy on a loss.
    if (combat_result == 2) {
        draw_set_color(make_color_rgb(215, 190, 160));
        draw_text(_cx, _summary_y, "His blade stopped a hair short. He binds your wounds himself.");
        _summary_y += 42;
        draw_set_color(make_color_rgb(180, 160, 140));
        draw_text(_cx, _summary_y, "\"Keep the arm. Come back when it's faster.\"  -  your run continues.");
        _summary_y += 54;
    } else if (combat_result == 1 && duel_grade != "") {
        var _dg_col = (duel_grade == "GOLD") ? make_color_rgb(235, 200, 110)
                    : ((duel_grade == "SILVER") ? make_color_rgb(200, 205, 215) : make_color_rgb(205, 140, 100));
        draw_set_color(_dg_col);
        draw_text(_cx, _summary_y, duel_grade + " DUEL  -  won in " + string(duel_grade_round)
            + " of PAR " + string(variable_global_exists("duel_par") ? global.duel_par : 6) + " turns");
        _summary_y += 42;
    }

    // Epithet (expression #5): the fallen/triumphant get their title read out.
    var _res_ep = player_epithet_text();
    if (_res_ep != "") {
        var _res_classes = ["Arcanist", "Bloodwarden", "Shadowstrider"];
        var _res_cid = variable_global_exists("chosen_class") ? clamp(global.chosen_class, 0, 2) : 0;
        draw_set_color(make_color_rgb(200, 170, 230));
        draw_text(_cx, _summary_y, _res_classes[_res_cid] + ", " + _res_ep);
        _summary_y += 42;
    }

    // IRONMAN settlement (SYSTEMS_RUN_RESUME.md): on defeat end_run(-1) already
    // ran at the death frame - current_run_* are zeroed and run_count bumped -
    // so the screen reads the last_run_* snapshot end_run left behind.
    var _res_gold  = global.current_run_gold;
    var _res_kills = global.current_run_kills;
    var _res_kept  = floor(global.current_run_gold * 0.25);
    var _res_runno = global.run_count + 1;
    if (combat_result == -1 && defeat_settled) {
        _res_gold  = global.last_run_gold;
        _res_kills = global.last_run_kills;
        _res_kept  = global.last_run_mercy_gold;
        _res_runno = global.run_count;
    }

    draw_set_color(c_yellow);
    var _gold_suffix = "";
    if (combat_result == -1) {
        _gold_suffix = "  |  Kept: " + string(_res_kept) + "g";
    }
    draw_text(_cx, _summary_y,
        "Gold earned: " + string(_res_gold) + "g" + _gold_suffix);
    _summary_y += 42;

    draw_set_color(c_white);
    draw_text(_cx, _summary_y, "Enemies defeated: " + string(_res_kills));
    _summary_y += 42;

    if (combat_result == -1) {
        draw_set_color(make_color_rgb(180, 150, 80));
        draw_text(_cx, _summary_y, "Salvaged: " + string(_res_kept) + "g kept");
        _summary_y += 42;
        if (variable_global_exists("last_run_mercy_item") && global.last_run_mercy_item != "") {
            draw_text(_cx, _summary_y, "Salvaged item: " + global.last_run_mercy_item);
            _summary_y += 42;
        }
        // THE IRON VOW (SYSTEMS_IRON_VOW.md): say what this death cost.
        if (variable_global_exists("vow_mode") && global.vow_mode > 0) {
            if (vow_fallen) {
                draw_set_color(make_color_rgb(220, 90, 80));
                draw_text(_cx, _summary_y, (global.vow_mode == 2) ? "THE VOW WAS ABSOLUTE." : "THE IRON VOW IS BROKEN.");
                _summary_y += 42;
                draw_text(_cx, _summary_y, "This story ends here. Only a gravestone remains.");
            } else {
                draw_set_color(make_color_rgb(220, 150, 90));
                draw_text(_cx, _summary_y, "The Vow holds - " + string(global.vow_lives_left)
                    + ((global.vow_lives_left == 1) ? " life remains." : " lives remain."));
            }
            _summary_y += 42;
        }
    }

    draw_text(_cx, _summary_y, "Run " + string(_res_runno));
    _summary_y += 54;

    // Continue / return prompt - hidden when extract popup is open
    if (!boss_extract_open) {
        draw_set_color(c_white);
        if (combat_result == 1 || combat_result == 2) {
            draw_text(_cx, _summary_y, "Press R to continue");
        } else if (vow_fallen) {
            draw_text_outline(_cx, _summary_y, "Press R to let the story end");
        } else {
            draw_text_outline(_cx, _summary_y, "Press R to return to camp");
        }
    }

    // Reset alignment
    draw_set_font(-1);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);

    // -------------------------------------------------------------------------
    // 5a. BOSS EXTRACT POPUP - shown after defeating a floor boss (floor < 3)
    // Player chooses: E = extract to camp, Enter/Space = descend to next floor.
    // -------------------------------------------------------------------------
    if (boss_extract_open) {
        // Backdrop
        draw_set_alpha(0.88);
        draw_set_color(make_color_rgb(8, 10, 20));
        draw_rectangle(360, 360, 1560, 735, false);
        draw_set_alpha(1.0);
        draw_set_color(make_color_rgb(60, 80, 140));
        draw_rectangle(360, 360, 1560, 735, true);

        var _bx_descent = variable_global_exists("descent_active") && global.descent_active;
        draw_set_halign(fa_center);
        draw_set_valign(fa_top);
        draw_set_font(fnt_ui_title);
        draw_set_color(_bx_descent ? make_color_rgb(235, 200, 110) : c_white);
        draw_text(_cx, 396, _bx_descent
            ? ("THE DESCENT  -  FLOOR " + string(global.current_floor) + " CLEARED")
            : ("FLOOR " + string(global.current_floor) + " CLEARED"));
        draw_set_font(fnt_ui);
        draw_set_color(make_color_rgb(160, 175, 210));
        draw_text(_cx, 459, _bx_descent ? "Bank your haul, or dare the deeper dark?" : "What will you do?");

        // Extract button
        draw_set_color(make_color_rgb(16, 36, 16));
        draw_rectangle(402, 510, 930, 623, false);
        draw_set_color(make_color_rgb(50, 160, 70));
        draw_rectangle(402, 510, 930, 623, true);
        draw_set_font(fnt_ui);
        draw_set_color(c_white);
        draw_text_outline(666, 533, _bx_descent ? "[ E ]  Retreat  -  Bank It All" : "[ E ]  Extract to Camp");
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(140, 210, 140));
        draw_text(666, 579, _bx_descent
            ? ("Everything found is kept  *  Floor " + string(global.current_floor) + " recorded")
            : "Keep all rewards  *  Safe");

        // Continue button
        draw_set_color(make_color_rgb(30, 22, 10));
        draw_rectangle(990, 510, 1518, 623, false);
        draw_set_color(make_color_rgb(180, 130, 40));
        draw_rectangle(990, 510, 1518, 623, true);
        draw_set_font(fnt_ui);
        draw_set_color(c_white);
        draw_text(1254, 533, "[ Enter ]  Descend Deeper");
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(220, 190, 120));
        draw_text(1254, 579, _bx_descent
            ? ("Floor " + string(global.current_floor + 1) + "  *  a random dungeon stirs  *  death drops the unbanked")
            : ("Floor " + string(global.current_floor + 1) + "  *  Harder enemies"));

        // #3: armed button gets a bright double border + an explicit confirm line.
        if (boss_extract_arm == "extract") {
            draw_set_color(make_color_rgb(140, 255, 160));
            draw_rectangle(400, 508, 932, 625, true);
            draw_rectangle(398, 506, 934, 627, true);
        } else if (boss_extract_arm == "continue") {
            draw_set_color(make_color_rgb(255, 210, 110));
            draw_rectangle(988, 508, 1520, 625, true);
            draw_rectangle(986, 506, 1522, 627, true);
        }
        if (boss_extract_arm != "") {
            draw_set_font(fnt_ui_small);
            draw_set_color(c_white);
            draw_text_outline(_cx, 645, (boss_extract_arm == "extract")
                ? "Extract to camp?  Press E / click again to confirm."
                : "Descend to floor " + string(global.current_floor + 1) + "?  Press Enter / click again to confirm.");
        } else {
            draw_set_color(make_color_rgb(70, 80, 110));
            draw_text_outline(_cx, 645, (input_device() == 1)
                ? "RT: Extract     A: Continue to next floor"
                : "E: Extract     Enter / Space: Continue to next floor");
        }

        draw_set_font(-1);
        draw_set_halign(fa_left);
        draw_set_valign(fa_top);

        // Mouse hover highlights
        var _bmx = device_mouse_x_to_gui(0);
        var _bmy = device_mouse_y_to_gui(0);
        var _hover_extract  = (_bmx >= 402 && _bmx < 930  && _bmy >= 510 && _bmy < 623);
        var _hover_continue = (_bmx >= 990 && _bmx < 1518 && _bmy >= 510 && _bmy < 623);
        if (_hover_extract) {
            draw_set_alpha(0.18);
            draw_set_color(c_white);
            draw_rectangle(402, 510, 930, 623, false);
            draw_set_alpha(1.0);
        }
        if (_hover_continue) {
            draw_set_alpha(0.18);
            draw_set_color(c_white);
            draw_rectangle(990, 510, 1518, 623, false);
            draw_set_alpha(1.0);
        }

        // Input: Extract (#3 arm-then-confirm: first press arms, second commits)
        var _do_extract = input_hotkey("E")
            || (mouse_check_button_pressed(mb_left) && _hover_extract);
        if (_do_extract) {
            if (boss_extract_arm != "extract") {
                boss_extract_arm = "extract";
            } else {
                boss_extract_arm = "";
                audio_stop_sound(MusicBox1);
                end_run(0);
                global.current_floor       = 1;
                global.floor_rooms_cleared = [];
                global.floor_map_floor     = -1;
                room_goto(rm_hub);
                exit;
            }
        }

        // Input: Continue (#3 arm-then-confirm)
        var _do_continue = input_confirm() || input_confirm_alt()
            || (mouse_check_button_pressed(mb_left) && _hover_continue);
        if (_do_continue) {
            if (boss_extract_arm != "continue") {
                boss_extract_arm = "continue";
            } else {
                boss_extract_arm  = "";
                boss_extract_open = false;
                audio_stop_sound(MusicBox1);
                // Floor advance (incl. THE DESCENT theme/Awakening roll) lives in
                // run_floor_advance (scr_save) - shared with the floor-map resume
                // popup so the two paths can never drift. (SYSTEMS_RUN_RESUME.md)
                run_floor_advance();
                exit;
            }
        }

        touch_sim_pump();   // early exit skips the bottom-of-Draw pump (see alloc note)
        exit; // block normal R-key handler while popup is open
    }

    // -------------------------------------------------------------------------
    // 5b. RESULT INPUT
    // Only checked when the result screen is visible so R is free during combat.
    // Victory returns to the floor map and marks the room cleared.
    // Defeat calls end_run(-1) to claw back run gold and returns to the hub.
    // -------------------------------------------------------------------------
    if (input_hotkey("R") || input_confirm() || input_confirm_alt() || mouse_check_button_pressed(mb_left)) {
        if (combat_result == 1 || combat_result == 2) {
            // Duel over (win or mercy) - stand the rival down before returning.
            // Result 2 already restored HP to room entry in the Step mercy block.
            global.duel_active = false;
            // Save HP and secondary resources to carry into the next room
            global.run_current_hp = player.HP;
            if (variable_struct_exists(player, "souls"))       global.run_souls       = player.souls;
            if (variable_struct_exists(player, "blood"))       global.run_blood       = player.blood;
            if (variable_struct_exists(player, "preparation")) global.run_preparation = player.preparation;

            global.just_cleared_room = true;

            if (variable_global_exists("just_cleared_boss") && global.just_cleared_boss) {
                // SHARED floor-clear hook: credit this cleared floor (at the run's
                // Awakening) toward time-gated systems (Petra orders; Phase 2 pets).
                // Fires before the extract/continue/victory branch so the credit banks
                // regardless of what the player does next.
                floor_clear_credit(variable_global_exists("selected_ascendance") ? global.selected_ascendance : 0);
                // Egg / trinket / banshee rolls moved to the VICTORY FRAME in
                // Step (M 07-28) so they list on the loot screen as SPECIAL
                // rows - same deterministic stream, granted before this branch.
                // THE DESCENT never full-clears - every floor boss opens the
                // retreat/descend choice instead (SYSTEMS_ENDLESS.md §3).
                var _in_descent = variable_global_exists("descent_active") && global.descent_active;
                if (global.current_floor >= 3 && !_in_descent) {
                    // Banshee already granted at the victory frame; end_run(1)
                    // sweeps it into Maren's queue - a full clear IS the
                    // successful extraction. (BANSHEE_BOTTLE_SPEC.md)
                    // Full dungeon clear - end run as victory
                    global.just_cleared_boss = false;
                    global.floor_rooms_cleared = [];
                    audio_stop_sound(MusicBox1);
                    end_run(1);
                    room_goto(rm_hub);
                    exit;
                } else {
                    // Floor boss cleared - open extract choice popup, don't advance yet.
                    // IRONMAN resume (SYSTEMS_RUN_RESUME.md): bank the boss-granted
                    // persistents (pet egg, Petra floor credit) NOW, then checkpoint
                    // with extract_pending so a crash at this popup re-offers the
                    // same choice on the floor map instead of re-fighting the boss
                    // (a free re-fight would re-roll the egg and the loot).
                    save_game();
                    global.run_extract_pending = true;
                    run_checkpoint_write(undefined);
                    boss_extract_open = true;
                    boss_extract_arm  = "";   // #3: nothing armed yet
                    exit;
                }
            }

            room_goto(rm_dungeon_floor);
        } else {
            audio_stop_sound(_15_game_over_INITIAL);
            // IRONMAN settlement: end_run(-1) already ran at the death frame
            // (Step). Guarded, not removed, in case a future defeat path skips it.
            if (!defeat_settled) end_run(-1);
            // THE IRON VOW: a fallen character has no hub to return to - the
            // save is already gone. Back to the title (the slot now shows the
            // gravestone). Mirrors pause_quit_to_title's teardown.
            if (vow_fallen) {
                run_state_reset();
                audio_stop_all();
                room_goto(rm_title);
            } else {
                room_goto(rm_hub);
            }
        }
    }
}

// Combat owns fonts; shared menu/overlay draws below are still default-font
// (Phase 3) - make sure none of them inherit a combat font.
draw_set_font(-1);
ui_draw_stash_screen();
ui_draw_character_menu();

// Comparison panel - drawn above all overlays
if (instance_exists(obj_game_controller)) {
    var _gc_cmp2 = instance_find(obj_game_controller, 0);
    if (_gc_cmp2.comparison_open && _gc_cmp2.comparison_item != undefined) {
        ui_draw_comparison_panel(_gc_cmp2.comparison_item, _gc_cmp2.comparison_equipped);
    }
}

// Ability detail breakdown (V) - full-screen popup over the combat HUD, mirroring
// the Tab popup on the loadout / Vex screens. Close hint reads [V] since Tab is the
// target-cycle key in combat. Drawn under the pause menu so Esc->pause still wins
// if both somehow coexist (they don't - the Esc guard closes this first).
if (player_turn && !combat_over && ability_detail_open) {
    var _ad_idx = clamp(selected_ability, 0, array_length(player.abilities) - 1);
    ui_draw_ability_detail(player.abilities[_ad_idx], (input_device() == 1) ? "R3" : ((input_device() == 2) ? "Back" : "V"), ability_detail_scroll);
}

// P-key companion inspect (M 07-08) - the full pet profile as an overlay.
if (instance_exists(obj_game_controller)) {
    var _gc_pi = instance_find(obj_game_controller, 0);
    if (variable_instance_exists(_gc_pi, "pet_inspect_open") && _gc_pi.pet_inspect_open
        && pet_active() != undefined) {
        ui_draw_pet_detail(pet_active());
        draw_set_halign(fa_center);
        draw_set_font(fnt_ui_small);
        draw_set_color(make_color_rgb(140, 150, 175));
        ui_draw_key_legend(GUI_CX, 1044, "P / Esc: Close");
        draw_set_halign(fa_left);
        draw_set_font(-1);
    }
}

// Pause / Esc menu + its Settings sub-screen (combat doesn't otherwise host the
// settings overlay) - topmost.
if (variable_global_exists("settings_open") && global.settings_open) ui_draw_settings_overlay();
ui_draw_pause_menu();

// Onboarding coach-mark - drawn last so it sits on top of the combat scene.
ui_draw_tutorial_tip();

// Trait unlock toast (08-04): was hub-only, so traits unlocked mid-combat
// expired unseen (timer 120 < any fight). Shared ui_draw_toast, band y21-90
// (clears the enemy-bar grid at y96).
if (instance_exists(obj_game_controller)) {
    var _gc_tn = instance_find(obj_game_controller, 0);
    if (_gc_tn.trait_notif_timer > 0 && _gc_tn.trait_notif_msg != "") {
        ui_draw_toast(_gc_tn.trait_notif_msg, GUI_CX, 21,
                      min(1.0, _gc_tn.trait_notif_timer / 30.0), c_white);
    }
}

// Touch (8c): universal Back chip + simulated-key pump - always LAST (topmost).
// Combat keeps the top corner (y24): the enemy-bar grid starts at y96, so the
// default y108 would land on it; the awakening label moves left on touch instead.
// _force_x: while an overlay owned by THIS controller is up, Esc closes that
// overlay rather than opening the pause menu - so the chip must read as an X,
// not the three-bar menu glyph (M 07-18, inspecting an ability in combat).
ui_draw_touch_back(24, ability_detail_open || consumable_quick_open);
ui_draw_touch_gamepad();   // on-screen d-pad in the left gutter (M 07-17)

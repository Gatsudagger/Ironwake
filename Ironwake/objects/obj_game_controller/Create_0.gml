// Singleton guard - only one game controller may exist at a time
if (instance_number(obj_game_controller) > 1) {
    instance_destroy();
    exit;
}

// -1 = no slot chosen yet (title screen hasn't selected one); set by the slot picker.
// load_game() and save_game() both no-op when this is -1.
global.save_slot = -1;

depth = -99999; // draw GUI on top of all room controllers

// Native 1920x1080 GUI canvas (clean 1.5x over the old 1280x720; SYSTEMS_RESOLUTION.md).
// The GUI layer is the real drawing surface; in fullscreen GameMaker maps it 1:1 to a
// 1080p display, so there's no upscale blur.
display_set_gui_size(GUI_W, GUI_H);

// Window sizing (auto-fit: native 1920x1080, clamped down only on sub-1080p displays,
// centered) AND the saved fullscreen preference are both handled by video_apply().
video_apply();

// Wide-aspect geometry (8b): fit the GUI band to the actual window shape - on a
// 16:9 PC window this is a no-op; wider (Android phones, ultrawide fullscreen)
// centers the 1920x1080 band with art-filled gutters. Step re-applies whenever
// the window shape changes (F11 fullscreen, F7 aspect lever, browser resize).
gui_geometry_apply();
geom_last_w = window_get_width();
geom_last_h = window_get_height();

// -----------------------------------------------------------------------------
// SPRITE INCLUDE GUARD
// The female class sprites and all Vael skins are referenced ONLY via
// asset_get_index("name") (a string the compiler can't see as a reference), so
// GameMaker excludes them from the build and asset_get_index() returns -1 at
// runtime even though they exist in the project. Referencing them here by their
// bare asset identifiers - stored in a global so the assignment is never
// dead-code-eliminated - forces the compiler to include them in the build.
// (If a sprite is ever renamed/removed, update this list to match.)
global.__sprite_includes = [
    // 08-15 rune recolors: rune_icon_sprite resolves these by STRING
    // ("spr_icon_rune_" + id) so direct refs are required or they strip.
    spr_icon_rune_rime, spr_icon_rune_tempest, spr_icon_rune_aether,
    spr_icon_rune_abyss, spr_icon_rune_umbra, spr_icon_rune_venom,
    spr_icon_rune_avatar,
    // Font-size variants (08-14): ui_font resolves them by NAME
    // (asset_get_index) so the .gml compiled before the import - these direct
    // refs stop the compiler stripping them. Fonts in a sprite list is fine:
    // this array exists only to hold references.
    fnt_ui_lg, fnt_ui_sm, fnt_ui_small_lg, fnt_ui_small_sm,
    // 2.5D painted plane pilot (08-13): string-looked-up in dungeon_bg_draw.
    spr_wall25_ashen_1, spr_floor25_ashen_1,
    spr_wall25_ashen_2, spr_floor25_ashen_2, spr_wall25_ashen_3, spr_floor25_ashen_3, spr_wall25_scorched_1, spr_floor25_scorched_1, spr_wall25_scorched_2, spr_floor25_scorched_2, spr_wall25_scorched_3, spr_floor25_scorched_3, spr_wall25_tundra_1, spr_floor25_tundra_1, spr_wall25_tundra_2, spr_floor25_tundra_2, spr_wall25_tundra_3, spr_floor25_tundra_3, spr_bone_sovereign_hd,
    // RPG-origin staging stills (08-11): string-ref only via origin_still()
    // (asset_get_index("spr_origin_" + id)) - listed or the compiler strips them.
    spr_origin_merchant,    spr_origin_forester,    spr_origin_deserter,
    spr_origin_gravekeeper, spr_origin_survivor,    spr_origin_orphan,
    spr_origin_scholar,     spr_origin_shrinesworn, spr_origin_campaigner,
    spr_origin_banshee,     spr_origin_whisperer,   spr_origin_debtor,
    // Devil Wine icon: referenced only by string in ui_consumable_icon_sprite
    // (asset_get_index), so it must be listed or the compiler strips it.
    spr_icon_consumable_devil_wine,
    // Genie Lamp icon: same string-ref pattern as Devil Wine above.
    spr_icon_consumable_genie_lamp,
    // Chaotic Brew icon (07-28): same string-ref pattern.
    spr_icon_consumable_chaotic_brew,
    // Quintessence icon (07-28 M pick): string-ref from the Sable cauldron row.
    spr_icon_consumable_quintessence,
    // Cursed Rebirth ceremony scene (08-04 M pick A): string-ref from the hub
    // ritual overlay (asset_get_index with pre-import fallback).
    spr_scene_cursed_ritual,
    // Mutator-carrier ability icons (08-12 batch, M approved): string-ref from
    // ability_icon_sprite (asset_get_index with bespoke fallbacks).
    spr_ability_ricochet_shot, spr_ability_bouncing_bomb, spr_ability_gout_of_rot,
    // Ashen Duelist progressive tiers (08-12 spectral-fencer redesign):
    // duelist_sprite_for() resolves these by STRING - listed or stripped.
    spr_ashen_duelist_t1, spr_ashen_duelist_t2, spr_ashen_duelist_t3,
    // Icon-collision pass (07-29 round 3, M approved all 36): banded sets for
    // the six families that shared one sprite each + jewelry keyword splits +
    // 6th wand/sword variants. Same string-ref pattern as the batch below.
    spr_icon_helm_plate_c,   spr_icon_helm_plate_c2,  spr_icon_helm_plate_u,
    spr_icon_helm_plate_r,   spr_icon_helm_plate_e,   spr_icon_helm_plate_l,
    spr_icon_gloves_plate_c, spr_icon_gloves_plate_u, spr_icon_gloves_plate_r,
    spr_icon_gloves_plate_e, spr_icon_gloves_plate_l,
    spr_icon_gloves_cloth_c, spr_icon_gloves_cloth_u, spr_icon_gloves_cloth_r,
    spr_icon_gloves_cloth_e, spr_icon_gloves_cloth_l,
    spr_icon_boots_plate_c,  spr_icon_boots_plate_u,  spr_icon_boots_plate_r,
    spr_icon_boots_plate_e,  spr_icon_boots_plate_l,
    spr_icon_boots_leather_c, spr_icon_boots_leather_u, spr_icon_boots_leather_r,
    spr_icon_boots_leather_e, spr_icon_boots_leather_l,
    spr_icon_chest_void_c,   spr_icon_chest_void_u,   spr_icon_chest_void_r,
    spr_icon_chest_void_e,   spr_icon_chest_void_l,
    spr_icon_amulet_emberheart, spr_icon_ring_venom,  spr_icon_ring_pact,
    spr_icon_weapon_sword_f, spr_icon_weapon_wand_f,
    // Rarity-banded armor variant icons (07-29 loot-variance pass, M: "use them
    // ALL"): resolved by string in ui_armor_icon_variant (scr_ui), bands c/u/r/e/l.
    spr_icon_chest_robe_c,  spr_icon_chest_robe_c2, spr_icon_chest_robe_c3,
    spr_icon_chest_robe_u,  spr_icon_chest_robe_u2, spr_icon_chest_robe_u3,
    spr_icon_chest_robe_r,  spr_icon_chest_robe_r2, spr_icon_chest_robe_r3,
    spr_icon_chest_robe_r4, spr_icon_chest_robe_e,  spr_icon_chest_robe_e2,
    spr_icon_chest_robe_e3, spr_icon_chest_robe_l,  spr_icon_chest_robe_l2,
    spr_icon_chest_plate_c,  spr_icon_chest_plate_c2, spr_icon_chest_plate_c3,
    spr_icon_chest_plate_c4, spr_icon_chest_plate_u,  spr_icon_chest_plate_u2,
    spr_icon_chest_plate_u3, spr_icon_chest_plate_r,  spr_icon_chest_plate_r2,
    spr_icon_chest_plate_r3, spr_icon_chest_plate_e,  spr_icon_chest_plate_e2,
    spr_icon_chest_plate_e3, spr_icon_chest_plate_l,  spr_icon_chest_plate_l2,
    spr_icon_chest_plate_l3,
    spr_icon_chest_leather_c,  spr_icon_chest_leather_c2, spr_icon_chest_leather_c3,
    spr_icon_chest_leather_c4, spr_icon_chest_leather_u,  spr_icon_chest_leather_u2,
    spr_icon_chest_leather_u3, spr_icon_chest_leather_u4, spr_icon_chest_leather_r,
    spr_icon_chest_leather_r2, spr_icon_chest_leather_r3, spr_icon_chest_leather_e,
    spr_icon_chest_leather_e2, spr_icon_chest_leather_e3, spr_icon_chest_leather_l,
    spr_icon_chest_leather_l2,
    spr_icon_helm_hood_c,  spr_icon_helm_hood_c2, spr_icon_helm_hood_c3,
    spr_icon_helm_hood_c4, spr_icon_helm_hood_u,  spr_icon_helm_hood_u2,
    spr_icon_helm_hood_u3, spr_icon_helm_hood_u4, spr_icon_helm_hood_r,
    spr_icon_helm_hood_r2, spr_icon_helm_hood_r3, spr_icon_helm_hood_e,
    spr_icon_helm_hood_e2, spr_icon_helm_hood_e3, spr_icon_helm_hood_l,
    spr_icon_helm_hood_l2,
    // Lesser Aegis Draught icon (07-28): same string-ref pattern.
    spr_icon_consumable_lesser_aegis,
    // Sable Brew-tab cauldron centrepiece: resolved by string in ui_draw_sable_screen
    // (asset_get_index guard so the tab worked pre-import), so it must be listed.
    spr_sable_cauldron,
    // Unique-item icon pass (2026-07-06): trinket icons resolve by string from the
    // gift-picker pane, and the 5 named-weapon overrides resolve by string in
    // ui_draw_item_icon - all must be listed or the compiler strips them.
    spr_icon_trinket_appraisal_lens,
    spr_icon_trinket_champion_wraps,
    spr_icon_trinket_duskweave_bolt,
    spr_icon_trinket_egg_shard,
    spr_icon_trinket_grimoire_page,
    spr_icon_trinket_meteoric_ingot,
    spr_icon_trinket_singing_rune,
    spr_icon_unique_crystal_wand,
    spr_icon_unique_runed_scepter,
    spr_icon_unique_stormcaller_staff,
    spr_icon_unique_vaultwood_bow,
    spr_icon_unique_void_scepter,
    // Pet sprites are referenced only by string (pet_sprite -> asset_get_index), so they
    // must be listed here or the compiler strips them. (Pets Phase 2 art backlog.)
    spr_pet_cryptling_baby,
    spr_pet_cryptling_adult,
    spr_pet_wisplet_baby,      spr_pet_wisplet_adult,
    spr_pet_carrion_moth_baby, spr_pet_carrion_moth_adult,
    spr_pet_gravewing_baby,    spr_pet_gravewing_adult,
    spr_pet_hollow_pup_baby,   spr_pet_hollow_pup_adult,
    spr_pet_bonehound_baby,
    spr_pet_bonehound_adult,
    spr_pet_graveling_baby,
    spr_pet_graveling_adult,
    spr_pet_ashling_baby,
    spr_pet_ashling_adult,
    // Animated directional idle sprites (south/east) - referenced by string in pet_sprite.
    spr_pet_cryptling_baby_s,  spr_pet_cryptling_baby_e,
    spr_pet_cryptling_adult_s, spr_pet_cryptling_adult_e,
    spr_pet_graveling_baby_s,  spr_pet_graveling_baby_e,
    spr_pet_graveling_adult_s, spr_pet_graveling_adult_e,
    spr_pet_ashling_baby_s,    spr_pet_ashling_baby_e,
    spr_pet_ashling_adult_s,   spr_pet_ashling_adult_e,
    spr_pet_bonehound_baby_s,  spr_pet_bonehound_baby_e,
    spr_pet_bonehound_adult_s, spr_pet_bonehound_adult_e,
    // Redesigned creature species - 3 stages (baby/youngadult/adult) x south/east animated idle.
    spr_pet_luna_moth_baby_s,     spr_pet_luna_moth_baby_e,
    spr_pet_luna_moth_youngadult_s, spr_pet_luna_moth_youngadult_e,
    spr_pet_luna_moth_adult_s,    spr_pet_luna_moth_adult_e,
    spr_pet_gloomtoad_baby_s,     spr_pet_gloomtoad_baby_e,
    spr_pet_gloomtoad_youngadult_s, spr_pet_gloomtoad_youngadult_e,
    spr_pet_gloomtoad_adult_s,    spr_pet_gloomtoad_adult_e,
    spr_pet_wyrmling_baby_s,      spr_pet_wyrmling_baby_e,
    spr_pet_wyrmling_youngadult_s, spr_pet_wyrmling_youngadult_e,
    spr_pet_wyrmling_adult_s,     spr_pet_wyrmling_adult_e,
    spr_pet_nightowl_baby_s,      spr_pet_nightowl_baby_e,
    spr_pet_nightowl_youngadult_s, spr_pet_nightowl_youngadult_e,
    spr_pet_nightowl_adult_s,     spr_pet_nightowl_adult_e,
    spr_pet_bone_stag_baby_s,     spr_pet_bone_stag_baby_e,
    spr_pet_bone_stag_youngadult_s, spr_pet_bone_stag_youngadult_e,
    spr_pet_bone_stag_adult_s,    spr_pet_bone_stag_adult_e,
    spr_pet_saber_hound_baby_s,   spr_pet_saber_hound_baby_e,
    spr_pet_saber_hound_youngadult_s, spr_pet_saber_hound_youngadult_e,
    spr_pet_saber_hound_adult_s,  spr_pet_saber_hound_adult_e,
    // Themed hatch eggs - static shell (roster/station) + 9-frame hatch anim (cutscene).
    spr_pet_egg_gilded,  spr_pet_egg_gilded_hatch,
    spr_pet_egg_fortune, spr_pet_egg_fortune_hatch,
    spr_pet_egg_savage,  spr_pet_egg_savage_hatch,
    spr_pet_egg_tender,  spr_pet_egg_tender_hatch,
    // Expansion eggs (Pets §3): vital/ley/scholar/dust/warding/keen.
    spr_pet_egg_vital,   spr_pet_egg_vital_hatch,
    spr_pet_egg_ley,     spr_pet_egg_ley_hatch,
    spr_pet_egg_scholar, spr_pet_egg_scholar_hatch,
    spr_pet_egg_dust,    spr_pet_egg_dust_hatch,
    spr_pet_egg_keen,    spr_pet_egg_keen_hatch,
    spr_pet_egg_warding, spr_pet_egg_warding_hatch,
    // Pet feed item icons (Petra shop + Bairc feed menu). Resolved by spr_pet_feed_<id>.
    spr_pet_feed_scraps, spr_pet_feed_forage, spr_pet_feed_prime,
    spr_pet_feed_mending_mash, spr_pet_feed_purgeroot, spr_pet_feed_hearty_roast,
    // Treats (bond-only, M approved 07-09).
    spr_pet_feed_treat_honey, spr_pet_feed_treat_marrow,
    // Species-preferred feed icons (ids pref_<species>, all 17 species).
    spr_pet_feed_pref_luna_moth,   spr_pet_feed_pref_bone_stag,    spr_pet_feed_pref_saber_hound,
    spr_pet_feed_pref_gloomtoad,   spr_pet_feed_pref_wyrmling,     spr_pet_feed_pref_nightowl,
    spr_pet_feed_pref_bonehound,   spr_pet_feed_pref_hollow_pup,   spr_pet_feed_pref_vaultling,
    spr_pet_feed_pref_marrow_adder, spr_pet_feed_pref_gaolwyrm,    spr_pet_feed_pref_cinder_newt,
    spr_pet_feed_pref_magma_leech, spr_pet_feed_pref_golemite,     spr_pet_feed_pref_rimefox,
    spr_pet_feed_pref_crypt_bat,   spr_pet_feed_pref_hoarfrost_drake,
    // Boss-signature species (Ashen Vault trio) - 3 stages x south/east animated idle.
    spr_pet_vaultling_baby_s,        spr_pet_vaultling_baby_e,
    spr_pet_vaultling_youngadult_s,  spr_pet_vaultling_youngadult_e,
    spr_pet_vaultling_adult_s,       spr_pet_vaultling_adult_e,
    spr_pet_marrow_adder_baby_s,     spr_pet_marrow_adder_baby_e,
    spr_pet_marrow_adder_youngadult_s, spr_pet_marrow_adder_youngadult_e,
    spr_pet_marrow_adder_adult_s,    spr_pet_marrow_adder_adult_e,
    spr_pet_gaolwyrm_baby_s,         spr_pet_gaolwyrm_baby_e,
    spr_pet_gaolwyrm_youngadult_s,   spr_pet_gaolwyrm_youngadult_e,
    spr_pet_gaolwyrm_adult_s,        spr_pet_gaolwyrm_adult_e,
    // Boss-signature species (Scorched Depths trio) - 3 stages x south/east animated idle.
    spr_pet_cinder_newt_baby_s,      spr_pet_cinder_newt_baby_e,
    spr_pet_cinder_newt_youngadult_s, spr_pet_cinder_newt_youngadult_e,
    spr_pet_cinder_newt_adult_s,     spr_pet_cinder_newt_adult_e,
    spr_pet_magma_leech_baby_s,      spr_pet_magma_leech_baby_e,
    spr_pet_magma_leech_youngadult_s, spr_pet_magma_leech_youngadult_e,
    spr_pet_magma_leech_adult_s,     spr_pet_magma_leech_adult_e,
    spr_pet_golemite_baby_s,         spr_pet_golemite_baby_e,
    spr_pet_golemite_youngadult_s,   spr_pet_golemite_youngadult_e,
    spr_pet_golemite_adult_s,        spr_pet_golemite_adult_e,
    // Boss-signature species (Tundra Tomb, batch 3) - rimefox imported 2026-07-04.
    spr_pet_rimefox_baby_s,          spr_pet_rimefox_baby_e,
    spr_pet_rimefox_youngadult_s,    spr_pet_rimefox_youngadult_e,
    spr_pet_rimefox_adult_s,         spr_pet_rimefox_adult_e,
    // Creatures expansion batch 1 (08-01) - crypt_bat/hoarfrost_drake boss-signature
    // + duskraven/voidkit standard, 3 stages x south/east animated idle.
    spr_pet_crypt_bat_baby_s,        spr_pet_crypt_bat_baby_e,
    spr_pet_crypt_bat_youngadult_s,  spr_pet_crypt_bat_youngadult_e,
    spr_pet_crypt_bat_adult_s,       spr_pet_crypt_bat_adult_e,
    spr_pet_hoarfrost_drake_baby_s,  spr_pet_hoarfrost_drake_baby_e,
    spr_pet_hoarfrost_drake_youngadult_s, spr_pet_hoarfrost_drake_youngadult_e,
    spr_pet_hoarfrost_drake_adult_s, spr_pet_hoarfrost_drake_adult_e,
    spr_pet_duskraven_baby_s,        spr_pet_duskraven_baby_e,
    spr_pet_duskraven_youngadult_s,  spr_pet_duskraven_youngadult_e,
    spr_pet_duskraven_adult_s,       spr_pet_duskraven_adult_e,
    spr_pet_voidkit_baby_s,          spr_pet_voidkit_baby_e,
    spr_pet_voidkit_youngadult_s,    spr_pet_voidkit_youngadult_e,
    spr_pet_voidkit_adult_s,         spr_pet_voidkit_adult_e,
    // Creatures expansion batch 2 (08-02) - the remaining 6 generic species,
    // 3 stages x south/east animated idle. Same string-ref pattern.
    spr_pet_pale_widow_baby_s,       spr_pet_pale_widow_baby_e,
    spr_pet_pale_widow_youngadult_s, spr_pet_pale_widow_youngadult_e,
    spr_pet_pale_widow_adult_s,      spr_pet_pale_widow_adult_e,
    spr_pet_shellback_baby_s,        spr_pet_shellback_baby_e,
    spr_pet_shellback_youngadult_s,  spr_pet_shellback_youngadult_e,
    spr_pet_shellback_adult_s,       spr_pet_shellback_adult_e,
    spr_pet_thorn_boar_baby_s,       spr_pet_thorn_boar_baby_e,
    spr_pet_thorn_boar_youngadult_s, spr_pet_thorn_boar_youngadult_e,
    spr_pet_thorn_boar_adult_s,      spr_pet_thorn_boar_adult_e,
    spr_pet_glimmer_slime_baby_s,    spr_pet_glimmer_slime_baby_e,
    spr_pet_glimmer_slime_youngadult_s, spr_pet_glimmer_slime_youngadult_e,
    spr_pet_glimmer_slime_adult_s,   spr_pet_glimmer_slime_adult_e,
    spr_pet_sporeling_baby_s,        spr_pet_sporeling_baby_e,
    spr_pet_sporeling_youngadult_s,  spr_pet_sporeling_youngadult_e,
    spr_pet_sporeling_adult_s,       spr_pet_sporeling_adult_e,
    spr_pet_ironshell_beetle_baby_s, spr_pet_ironshell_beetle_baby_e,
    spr_pet_ironshell_beetle_youngadult_s, spr_pet_ironshell_beetle_youngadult_e,
    spr_pet_ironshell_beetle_adult_s, spr_pet_ironshell_beetle_adult_e,
    // World expansion batch (08-06/08): 20 new species x 3 stages x south/east.
    // String-ref only (pet_sprite -> asset_get_index), so they MUST be listed here
    // or the compiler strips all 120 as unused assets.
    spr_pet_sluice_otter_baby_s, spr_pet_sluice_otter_baby_e,
    spr_pet_sluice_otter_youngadult_s, spr_pet_sluice_otter_youngadult_e,
    spr_pet_sluice_otter_adult_s, spr_pet_sluice_otter_adult_e,
    spr_pet_ashjaw_lynx_baby_s, spr_pet_ashjaw_lynx_baby_e,
    spr_pet_ashjaw_lynx_youngadult_s, spr_pet_ashjaw_lynx_youngadult_e,
    spr_pet_ashjaw_lynx_adult_s, spr_pet_ashjaw_lynx_adult_e,
    spr_pet_deepclaw_baby_s, spr_pet_deepclaw_baby_e,
    spr_pet_deepclaw_youngadult_s, spr_pet_deepclaw_youngadult_e,
    spr_pet_deepclaw_adult_s, spr_pet_deepclaw_adult_e,
    spr_pet_fathom_squid_baby_s, spr_pet_fathom_squid_baby_e,
    spr_pet_fathom_squid_youngadult_s, spr_pet_fathom_squid_youngadult_e,
    spr_pet_fathom_squid_adult_s, spr_pet_fathom_squid_adult_e,
    spr_pet_frostmarten_baby_s, spr_pet_frostmarten_baby_e,
    spr_pet_frostmarten_youngadult_s, spr_pet_frostmarten_youngadult_e,
    spr_pet_frostmarten_adult_s, spr_pet_frostmarten_adult_e,
    spr_pet_graftling_baby_s, spr_pet_graftling_baby_e,
    spr_pet_graftling_youngadult_s, spr_pet_graftling_youngadult_e,
    spr_pet_graftling_adult_s, spr_pet_graftling_adult_e,
    spr_pet_gravefox_baby_s, spr_pet_gravefox_baby_e,
    spr_pet_gravefox_youngadult_s, spr_pet_gravefox_youngadult_e,
    spr_pet_gravefox_adult_s, spr_pet_gravefox_adult_e,
    spr_pet_griefwisp_baby_s, spr_pet_griefwisp_baby_e,
    spr_pet_griefwisp_youngadult_s, spr_pet_griefwisp_youngadult_e,
    spr_pet_griefwisp_adult_s, spr_pet_griefwisp_adult_e,
    spr_pet_icewing_skua_baby_s, spr_pet_icewing_skua_baby_e,
    spr_pet_icewing_skua_youngadult_s, spr_pet_icewing_skua_youngadult_e,
    spr_pet_icewing_skua_adult_s, spr_pet_icewing_skua_adult_e,
    spr_pet_lantern_wyrm_baby_s, spr_pet_lantern_wyrm_baby_e,
    spr_pet_lantern_wyrm_youngadult_s, spr_pet_lantern_wyrm_youngadult_e,
    spr_pet_lantern_wyrm_adult_s, spr_pet_lantern_wyrm_adult_e,
    spr_pet_lockjaw_turtle_baby_s, spr_pet_lockjaw_turtle_baby_e,
    spr_pet_lockjaw_turtle_youngadult_s, spr_pet_lockjaw_turtle_youngadult_e,
    spr_pet_lockjaw_turtle_adult_s, spr_pet_lockjaw_turtle_adult_e,
    spr_pet_null_hound_baby_s, spr_pet_null_hound_baby_e,
    spr_pet_null_hound_youngadult_s, spr_pet_null_hound_youngadult_e,
    spr_pet_null_hound_adult_s, spr_pet_null_hound_adult_e,
    spr_pet_permafrost_toad_baby_s, spr_pet_permafrost_toad_baby_e,
    spr_pet_permafrost_toad_youngadult_s, spr_pet_permafrost_toad_youngadult_e,
    spr_pet_permafrost_toad_adult_s, spr_pet_permafrost_toad_adult_e,
    spr_pet_pyre_bison_baby_s, spr_pet_pyre_bison_baby_e,
    spr_pet_pyre_bison_youngadult_s, spr_pet_pyre_bison_youngadult_e,
    spr_pet_pyre_bison_adult_s, spr_pet_pyre_bison_adult_e,
    spr_pet_snowmaw_baby_s, spr_pet_snowmaw_baby_e,
    spr_pet_snowmaw_youngadult_s, spr_pet_snowmaw_youngadult_e,
    spr_pet_snowmaw_adult_s, spr_pet_snowmaw_adult_e,
    spr_pet_stormkirin_baby_s, spr_pet_stormkirin_baby_e,
    spr_pet_stormkirin_youngadult_s, spr_pet_stormkirin_youngadult_e,
    spr_pet_stormkirin_adult_s, spr_pet_stormkirin_adult_e,
    spr_pet_thornlet_baby_s, spr_pet_thornlet_baby_e,
    spr_pet_thornlet_youngadult_s, spr_pet_thornlet_youngadult_e,
    spr_pet_thornlet_adult_s, spr_pet_thornlet_adult_e,
    spr_pet_whispervine_baby_s, spr_pet_whispervine_baby_e,
    spr_pet_whispervine_youngadult_s, spr_pet_whispervine_youngadult_e,
    spr_pet_whispervine_adult_s, spr_pet_whispervine_adult_e,
    spr_pet_wispfox_baby_s, spr_pet_wispfox_baby_e,
    spr_pet_wispfox_youngadult_s, spr_pet_wispfox_youngadult_e,
    spr_pet_wispfox_adult_s, spr_pet_wispfox_adult_e,
    spr_pet_witchwood_fawn_baby_s, spr_pet_witchwood_fawn_baby_e,
    spr_pet_witchwood_fawn_youngadult_s, spr_pet_witchwood_fawn_youngadult_e,
    spr_pet_witchwood_fawn_adult_s, spr_pet_witchwood_fawn_adult_e,
    // Keeper species brought to 3-stage animated (new directional/young-adult sprites).
    spr_pet_bonehound_youngadult_s, spr_pet_bonehound_youngadult_e,
    spr_pet_hollow_pup_baby_s,       spr_pet_hollow_pup_baby_e,
    spr_pet_hollow_pup_youngadult_s, spr_pet_hollow_pup_youngadult_e,
    spr_pet_hollow_pup_adult_s,      spr_pet_hollow_pup_adult_e,
    // Bairc hub sprite (now animated) + portrait - referenced by string via asset_get_index.
    spr_npc_bairc_idle, spr_npc_bairc_action, spr_npc_bairc_portrait,
    spr_tavern_board,   // Tavern Requests panel art (asset_get_index string ref, Phase 4b)
    spr_hub_background,
    spr_title_background,
    spr_title_foreground,
    spr_ui_frame,
    spr_combatbg_ashen_1,
    spr_combatbg_ashen_2,
    spr_combatbg_ashen_3,
    spr_floormap_ashen,
    spr_combatbg_tundra_1,
    spr_combatbg_tundra_2,
    spr_combatbg_tundra_3,
    spr_floormap_tundra,
    spr_combatbg_scorched_1,
    spr_combatbg_scorched_2,
    spr_combatbg_scorched_3,
    spr_floormap_scorched,
    spr_fx_poison,
    spr_fx_burn,
    spr_fx_bleed,
    spr_fx_blind,
    spr_fx_stun,
    spr_fx_weaken,
    spr_fx_impact,
    spr_arcanist_f,
    spr_bloodwarden_f,
    spr_shadowstrider_f,
    spr_skin_ashen,
    spr_skin_bloodsworn,
    spr_skin_bonechoir,
    spr_skin_cinderclad,
    spr_skin_cryptlight,
    spr_skin_dawnbreak,
    spr_skin_doomherald,
    spr_skin_duskhide,
    spr_skin_ember,
    spr_skin_frostbit,
    spr_skin_goldwrought,
    spr_skin_gravewalker,
    spr_skin_hearth,
    spr_skin_ironscale,
    spr_skin_mirewalker,
    spr_skin_pilgrim,
    spr_skin_sanguine,
    spr_skin_sovereign,
    spr_skin_stormcall,
    spr_skin_tide,
    spr_skin_veilbind,
    spr_skin_voidtouch,
    spr_skin_wanderer,
    // Rune gem icons - resolved via rune_icon_sprite("spr_icon_rune_<id>") strings,
    // so they need a hard reference here or the compiler strips them from the build.
    spr_icon_rune_vitality,
    spr_icon_rune_might,
    spr_icon_rune_finesse,
    spr_icon_rune_fortitude,
    spr_icon_rune_insight,
    spr_icon_rune_keen,
    spr_icon_rune_warding,
    spr_icon_rune_evasion,
    spr_icon_rune_ember,
    spr_icon_rune_serration,
    spr_icon_rune_hemorrhage,
    spr_icon_rune_hunter,
    spr_icon_rune_bulwark,
    spr_icon_rune_leech,
    spr_icon_rune_surge,
    spr_icon_rune_anchor,
    spr_icon_rune_quickcast,
    spr_icon_rune_echo,
    // Cascade/Bastion flagship gems (2026-07-10 D SS4 round) - same string-ref path.
    spr_icon_rune_cascade,
    spr_icon_rune_bastion,
    // NPC actor sprites (idle + action) - drawn via asset_get_index("spr_npc_<id>_..")
    // strings, so they need a hard reference here or the compiler strips them.
    spr_npc_dorn_idle,   spr_npc_dorn_action,
    spr_npc_sable_idle,  spr_npc_sable_action,
    spr_npc_maren_idle,  spr_npc_maren_action,
    spr_npc_vex_idle,    spr_npc_vex_action,
    spr_npc_petra_idle,  spr_npc_petra_action,
    spr_npc_vael_idle,   spr_npc_vael_action,
    spr_heart_fx,
    // Themed armor icons - resolved via asset_get_index("spr_icon_<slot>_<type>")
    // strings in ui_*_icon_sprite(), so they need hard refs here or the compiler
    // strips them and every chest/helm/glove/boot falls back to its base icon.
    spr_icon_chest_leather, spr_icon_chest_plate, spr_icon_chest_robe, spr_icon_chest_void,
    spr_icon_helm_hood,     spr_icon_helm_circlet, spr_icon_helm_plate,
    spr_icon_gloves_arcane, spr_icon_gloves_cloth, spr_icon_gloves_plate,
    spr_icon_boots_plate,   spr_icon_boots_cloth,  spr_icon_boots_leather,
    // FF-style enemy model VARIANTS (08-16) - enemy_sprite_variants() resolves the
    // _ff2/_ff3 alternates via asset_get_index strings; hard refs keep them alive.
    spr_skeleton_archer_ff2,  spr_skeleton_archer_ff3,
    spr_skeleton_soldier_ff2, spr_skeleton_soldier_ff3,
    spr_vault_crawler_ff2,    spr_vault_crawler_ff3,
    spr_dungeon_wraith_ff2,   spr_dungeon_wraith_ff3,
    spr_stone_golem_ff2,      spr_stone_golem_ff3,
    spr_vault_guardian_ff2,   spr_vault_guardian_ff3,
];

// =============================================================================
// obj_game_controller - Create event
// This object is persistent (survives all room transitions) and is the single
// source of truth for all meta-progression data that carries between runs.
// It should exist in the first room and never be destroyed.
// =============================================================================


// -----------------------------------------------------------------------------
// 1. ECONOMY
// Cumulative gold across all runs. add_gold() keeps current_run_gold in sync.
// -----------------------------------------------------------------------------
global.gold = 0;
global.player_name = "Hero";

// Player HP and secondary resources carried between combat rooms within a run.
// All reset to 0 at game start and by end_run() so each new run starts fresh.
global.run_current_hp    = 0;
global.run_souls         = 0;
global.run_blood         = 0;
global.run_preparation   = 0;
global.just_cleared_boss = false;
global.current_floor     = 1;
global.floor_rooms_cleared = [];


// -----------------------------------------------------------------------------
// 2. RUN STATISTICS
// Lifetime counters updated at the end of each run via end_run().
// -----------------------------------------------------------------------------
global.run_count   = 0;   // total attempts started
global.best_floor  = 0;   // deepest floor reached across all runs
global.total_kills = 0;   // cumulative enemy kills across all runs


// -----------------------------------------------------------------------------
// 3. PERMANENT STAT BONUSES
// Earned through leveling and the Vex system. Applied to the player struct
// in obj_combat_controller's Create event on top of the chosen class base.
// -----------------------------------------------------------------------------
global.perm_str_bonus = 0;
global.perm_dex_bonus = 0;
global.perm_con_bonus = 0;
global.perm_int_bonus = 0;
global.perm_wis_bonus = 0;
global.perm_cha_bonus = 0;


// -----------------------------------------------------------------------------
// 4. LAST RUN RESULTS
// Written by end_run() so the hub and result screens can display a post-run
// summary without querying the live run state.
// -----------------------------------------------------------------------------
global.last_run_gold        = 0;   // gold earned during the most recent run
global.last_run_kills       = 0;   // kills during the most recent run
global.last_run_result      = 0;   // 0 = no run yet, 1 = victory, -1 = defeat
global.last_run_mercy_gold  = 0;
global.last_run_perm_points = 0;   // perm points earned in the most recent run (0 = none)   // gold kept on defeat (25% mercy)


// -----------------------------------------------------------------------------
// 5. CURRENT RUN TRACKING
// Reset to 0 at the start of each run (inside end_run). Read by the HUD and
// written by add_gold() and combat kill resolution.
// -----------------------------------------------------------------------------
global.current_run_gold  = 0;
global.current_run_kills = 0;
if (!variable_global_exists("run_boons")) global.run_boons = [];   // active boons this run (Shrine tribute)
if (!variable_global_exists("run_curses")) global.run_curses = []; // active curses this run (devil's bargain)
// The Ashen Duelist (DESIGN_DUELIST_CHALLENGE.md): lifetime rival ledger (saved)
// + run-scoped duel state.
if (!variable_global_exists("duelist_encounters"))   global.duelist_encounters   = 0;
if (!variable_global_exists("duelist_tokens"))       global.duelist_tokens       = 0;
if (!variable_global_exists("duel_offered_this_run")) global.duel_offered_this_run = false;
if (!variable_global_exists("duel_launch"))          global.duel_launch          = false;
if (!variable_global_exists("duel_active"))          global.duel_active          = false;
if (!variable_global_exists("run_borrowed_ability")) global.run_borrowed_ability = "";   // Borrowed Memory (expression #6)
if (!variable_global_exists("run_borrowed_class"))   global.run_borrowed_class   = "";
if (!variable_global_exists("run_honing"))           global.run_honing           = {};   // Whetstone run-scoped honing (07-17; stores web node ids since the talent-web rework)
if (!variable_global_exists("ability_web"))          global.ability_web          = {};   // talent-web picks { name: [node_ids] } (SAVE v4)
// Sable exotic find-buff potions (last until 2 bosses slain; see scr_stats potion_* fns).
if (!variable_global_exists("gold_potion_bosses")) global.gold_potion_bosses = 0;
if (!variable_global_exists("gold_potion_mult"))   global.gold_potion_mult   = 0;
if (!variable_global_exists("loot_potion_bosses")) global.loot_potion_bosses = 0;
if (!variable_global_exists("loot_potion_pts"))    global.loot_potion_pts    = 0;

// NPC affinity (thin track - Phase 0.5). Meta-persistent per-NPC score->tier; loaded
// from save when a slot loads. Guarded so a re-create never wipes it. See scr_stats.
if (!variable_global_exists("npc_affinity")) global.npc_affinity = affinity_fresh();

// Petra Treasure Trader order (Phase 1). Cross-run persistent; undefined = no order.
// Saved per slot; NOT reset in end_run (it earns out by clearing floors). See scr_stats.
if (!variable_global_exists("petra_order"))  global.petra_order  = undefined;
if (!variable_global_exists("petra_orders")) global.petra_orders = [];
// Per-run station-rank charges (M-locked 08-15, reset in end_run).
if (!variable_global_exists("deep_socket_used"))   global.deep_socket_used   = false;
if (!variable_global_exists("vael_portrait_free")) global.vael_portrait_free = false;
// Vex "Drill Regimen" (rank 2): first purchase each VISIT is 25% off.
if (!variable_global_exists("vex_visit_first"))    global.vex_visit_first    = false;

// BAIRC'S GARDEN scene state (M design-locked 08-15): a full-screen wandering-
// camera overlay entered from Bairc's station. Session state lives here;
// garden_decor/garden_cairn/forage ledger persist via scr_save.
garden_open       = false;
garden_cam_x      = 0;      // camera left edge, 0..garden_world_w()-1920
garden_fade       = 0;      // fade-in frames remaining
garden_notice     = "";     // toast line (drawn via ui_draw_toast)
garden_notice_t   = 0;      // toast frames remaining
garden_shop_open  = false;  // ornament shop overlay
garden_shop_cur   = 0;
garden_place_pick = "";     // ornament id awaiting a plot choice
garden_fx         = [];     // transient reactions: { kind, x, y, t0 }
garden_crumb_t    = -10000; // last pond crumb (koi converge window)
garden_crumb_x    = 0;
garden_drag_mx    = -1;     // last mouse x while drag-panning (-1 = not dragging)

// Pets (Phase 2). Cross-run persistent roster + active companion index + uid counter.
// Saved per slot; NOT reset in end_run (pets are raised ACROSS runs). See scr_stats /
// PETS_DESIGN.md. active_pet = index into pet_roster, or -1 for none.
if (!variable_global_exists("pet_roster"))  global.pet_roster  = [];
if (!variable_global_exists("active_pet"))  global.active_pet  = -1;
if (!variable_global_exists("pet_next_id")) global.pet_next_id = 1;
// One-shot "you found an egg" message, set on a boss-egg drop and shown next hub visit.
if (!variable_global_exists("pet_find_notice")) global.pet_find_notice = "";
// Creatures/eggs found during the CURRENT run (labels only; cleared in end_run) - shown
// as a display-only strip in the equipment Found column so pet loot is observable in-run.
if (!variable_global_exists("run_found_pets")) global.run_found_pets = [];
// Whether this character has received its one free starter pet yet (so Bairc is reachable).
if (!variable_global_exists("pet_starter_given")) global.pet_starter_given = false;
// Feed pouch: owned pet-feed items bought from Petra (struct keyed by feed id -> count).
if (!variable_global_exists("pet_feed_pouch") || !is_struct(global.pet_feed_pouch)) global.pet_feed_pouch = {};
// Combat pet-attack lunge clock (current_time of the last Combatant strike; drives the
// procedural lunge in obj_combat_controller Draw_64). Far-past default = no lunge showing.
if (!variable_global_exists("pet_lunge_t0")) global.pet_lunge_t0 = -100000;

// Onboarding coach-marks (see SYSTEMS_ONBOARDING.md). tutorial_seen = per-tip flags,
// tutorial_enabled = the Settings toggle, tutorial_active = the tip showing now ("").
if (!variable_global_exists("tutorial_seen"))    global.tutorial_seen    = {};
if (!variable_global_exists("tutorial_enabled")) global.tutorial_enabled = true;
global.tutorial_active          = "";
global.tutorial_dismiss_pending = false;   // 1-frame deferred clear (race-free dismiss)


// -----------------------------------------------------------------------------
// 6. LOOT TABLES
// Equipment pools used by roll_equipment() in scr_stats.
// Rarity: 0=common, 1=uncommon, 2=rare.
// create_item(name, slot, rarity, stat_name, stat_value, effect_desc, gold_value)
//
// Valid slot strings (must match equip_slot_index() in scr_stats exactly):
//   "weapon"  "offhand"  "helm"  "chest"  "gloves"  "boots"  "amulet"  "ring"
// -----------------------------------------------------------------------------
// Weapons with class restrictions are built via create_weapon() (defined in scr_stats).
// class_req: -1 = any, 0 = Arcanist, 1 = Bloodwarden, 2 = Shadowstrider.

// --- COMMON WEAPONS (class_req set post-creation) ---
var _cw_ashen        = create_item("Ashen Blade",    "weapon", 0, "STR", 2, "",                        15);
var _cw_shortbow     = create_item("Worn Shortbow",  "ranged_weapon", 0, "DEX", 2, "",                  14);
var _cw_cracked_wand = create_item("Cracked Focus",  "ranged_weapon", 0, "INT", 2, "still channels power", 13);
_cw_ashen.class_req = -1;  _cw_shortbow.class_req = -1;  _cw_cracked_wand.class_req = 0;
// Class-weapon ability affixes - being class-locked grants a combat bonus (read in obj_combat_controller/Create_0).
_cw_cracked_wand.unique_effect = "class_first_spell_ap";
_cw_cracked_wand.unique_desc   = "First spell each combat costs 1 less AP";

// --- UNCOMMON WEAPONS ---
var _uw_gravel  = create_item("Gravelstone Sword", "weapon", 1, "STR", 4, "dense and brutal",              35);
var _uw_wand    = create_item("Vaultstone Wand",   "ranged_weapon", 1, "INT", 4, "inscribed with vault runes", 38);
var _uw_sickle  = create_item("Shadow Sickle",     "weapon", 1, "DEX", 4, "curved blade of the striders",  36);
_uw_gravel.class_req = 1;  _uw_wand.class_req = 0;  _uw_sickle.class_req = 2;
_uw_gravel.unique_effect = "class_lifesteal";    _uw_gravel.unique_desc = "Heal 10% of the melee damage you deal";
_uw_wand.unique_effect   = "class_spell_dmg";    _uw_wand.unique_desc   = "Spells deal +12% damage";
_uw_sickle.unique_effect = "class_crit";         _uw_sickle.unique_desc = "+8% critical hit chance";

// --- RARE WEAPONS ---
var _rw_ash    = create_item("Ashkeeper Blade",  "weapon", 2, "STR", 6, "forged in ashwalker tradition",  80);
var _rw_vsept  = create_item("Void Scepter",     "ranged_weapon", 2, "INT", 6, "channels the void",       85);
var _rw_serp   = create_item("Serpent's Reach",  "weapon", 2, "DEX", 6, "flexible blade of the deep",    82);
_rw_ash.class_req = 1;  _rw_vsept.class_req = 0;  _rw_serp.class_req = 2;
_rw_ash.unique_effect   = "class_start_shield";  _rw_ash.unique_desc   = "Start each combat with a 12 HP shield";
_rw_vsept.unique_effect = "class_spell_crit_ap"; _rw_vsept.unique_desc = "Spell critical hits restore 1 AP";
_rw_serp.unique_effect  = "class_kill_ap";       _rw_serp.unique_desc  = "Killing an enemy restores 1 AP";
// Explicit req_stat overrides: these names resolve to the WRONG stat under
// weapon_required_stat ("blade"->DEX, "Serpent's Reach"->STR default), which would
// gate each weapon behind a stat its own class doesn't build. Pin to the real stat.
_rw_ash.req_stat  = "STR"; _rw_ash.req_value  = req_stat_curve(2);   // Bloodwarden STR blade
_rw_serp.req_stat = "DEX"; _rw_serp.req_value = req_stat_curve(2);   // Shadowstrider DEX reach

// --- TWO-HANDED WEAPONS (SYSTEMS_WEAPON_ROLES.md §D) ---
// 2H weapons lock the offhand slot, so they carry a bigger weapon_damage budget
// (~+80% over the 1H base for their rarity) plus a secondary affix as payoff.
// class_req -1: 2H weapons are NOT class-locked (no unique_effect). The 2H tag,
// stat bonus, and Rare+ stat requirement steer them without a hard lock.
var _2hw_greatsword = create_item("Ruinous Greatsword", "weapon", 1, "STR", 4, "takes both hands to swing", 44);
_2hw_greatsword.two_handed = true;  _2hw_greatsword.class_req = -1;  _2hw_greatsword.weapon_damage = 9;
_2hw_greatsword.affixes = [{ suffix: "of the Bear", prefix: "Hardy", stat_name: "CON", stat_value: 3 }];

var _2hw_longbow = create_item("Vault Longbow", "ranged_weapon", 1, "DEX", 4, "a tall war-bow drawn two-handed", 46);
_2hw_longbow.two_handed = true;  _2hw_longbow.class_req = -1;  _2hw_longbow.weapon_damage = 9;
_2hw_longbow.affixes = [{ suffix: "of Ruin", prefix: "Keen", stat_name: "crit_flat", stat_value: 5 }];

var _2hw_staff = create_item("Stormcaller Staff", "ranged_weapon", 2, "INT", 6, "a great runed staff held in both hands", 96);
_2hw_staff.two_handed = true;  _2hw_staff.class_req = -1;  _2hw_staff.weapon_damage = 13;
_2hw_staff.caster_2h = true;   // staff: allows a non-shield offhand (focus/tome), forbids a melee weapon (Task 10)
_2hw_staff.affixes = [{ suffix: "of Clarity", prefix: "Wise", stat_name: "WIS", stat_value: 4 }];

// --- ELEMENTAL WEAPONS (SYSTEMS_WEAPON_ROLES.md §C) ---
// Hand-authored examples of the elemental affix so a player reliably sees the
// burn/frost/shock setup->detonation loop (drops also roll it on ~40% of weapons).
// The affix renames the item (Flaming / Frostbound / Storm-touched) and adds a
// small elemental hit + a short setup status, reach-gated by the weapon's slot.
var _ew_flaming = create_item("Iron Brand", "weapon", 1, "STR", 3, "a soldier's blade", 40);
apply_elemental_affix_to_item(_ew_flaming, make_elem_affix("burn", 1));

var _ew_frost = create_item("Hunter's Bow", "ranged_weapon", 1, "DEX", 3, "a steady recurve bow", 42);
apply_elemental_affix_to_item(_ew_frost, make_elem_affix("frost", 1));

var _ew_storm = create_item("Runed Scepter", "ranged_weapon", 2, "INT", 5, "crowned with a storm-glass shard", 88);
apply_elemental_affix_to_item(_ew_storm, make_elem_affix("shock", 2));

// --- DEFENSIVE OFFHANDS (SYSTEMS_WEAPON_ROLES.md §D2) ---
// Shield-type offhands carry real DEFENSIVE value (armor / dodge / max HP) so
// giving up the offhand for a 2H weapon's bigger damage is a genuine trade.
var _off_cracked_shield = create_item("Cracked Shield", "offhand", 0, "CON", 2, "splintered but still turns a blow", 12);
_off_cracked_shield.affixes = [{ suffix: "of Warding", prefix: "Sturdy", stat_name: "armor", stat_value: 2 }];

var _off_buckler = create_item("Warden's Buckler", "offhand", 1, "CON", 4, "light enough to parry with", 30);
_off_buckler.affixes = [
    { suffix: "of Warding", prefix: "Sturdy", stat_name: "armor",      stat_value: 3 },
    { suffix: "of Deflection", prefix: "Nimble", stat_name: "dodge_flat", stat_value: 2 },
];

var _off_bulwark = create_item("Ironhide Bulwark", "offhand", 2, "CON", 6, "processed vault-metal", 80);
_off_bulwark.affixes = [{ suffix: "of the Mountain", prefix: "Ironhide", stat_name: "armor", stat_value: 5 }];

var _off_soul_orb = create_item("Soulbound Orb", "offhand", 2, "INT", 6, "wards the bearer's life", 85);
_off_soul_orb.affixes = [{ suffix: "of Vitality", prefix: "Soulbound", stat_name: "bonus_max_hp", stat_value: 10 }];

// --- PRE-DECLARED MULTI-STAT ITEMS (intrinsic secondary stats as affixes) ---
var _ember_ring = create_item("Ember Ring", "ring", 1, "STR", 2, "glows with a warm inner heat", 26);
_ember_ring.affixes = [{ suffix: "of Insight", prefix: "Arcane", stat_name: "INT", stat_value: 2 }];

var _forsaken_circlet = create_item("Forsaken Circlet", "helm", 2, "INT", 5, "worn by a mage of the fallen court", 82);
_forsaken_circlet.affixes = [{ suffix: "of Clarity", prefix: "Wise", stat_name: "WIS", stat_value: 3 }];

// --- DEMO SCHOOL-DAMAGE JEWELRY (SYSTEMS_ELEMENT_SCHOOLS.md §C, Phase 1) ---
// Hand-authored "+X <school> damage" pieces so the flat school-damage axis is
// reachable before rolled affixes exist (Phase 2). The school_<name> affix adds a
// flat bonus to every damaging ability of that school (mitigated by the ability's
// own type). Magnitudes by affix tier: uncommon +1, rare +2-4 (cap 4), epic +5-6.
var _sch_ember = create_item("Emberheart Talisman", "amulet", 2, "INT", 5, "a warm coal that never cools", 76);
_sch_ember.affixes = [{ suffix: "of Flames", prefix: "Smoldering", stat_name: "school_fire", stat_value: 4 }];

var _sch_blood = create_item("Bloodsoaked Band", "ring", 1, "CON", 3, "darkened with old stains", 28);
_sch_blood.affixes = [{ suffix: "of the Leech", prefix: "Sanguine", stat_name: "school_blood", stat_value: 1 }];

var _sch_venom = create_item("Venomous Signet", "ring", 1, "DEX", 3, "the crest weeps a green bead", 28);
_sch_venom.affixes = [{ suffix: "of Venom", prefix: "Toxic", stat_name: "school_poison", stat_value: 1 }];

global.loot_table_common = [
    // Weapons. Generic (class_req -1) bases fill every archetype so each class
    // finds an equippable, stat-appropriate weapon. Names resolve to the right
    // stat under weapon_required_stat (spear/saber/pike->STR, sickle->DEX, wand->INT).
    _cw_ashen,
    _cw_shortbow,
    _cw_cracked_wand,
    create_item("Chipped Spear", "weapon",        0, "STR", 2, "a notched footman's spear",      14),
    create_item("Rusty Sickle",  "weapon",        0, "DEX", 2, "a farmer's tool gone to rust",   13),
    create_item("Bent Wand",     "ranged_weapon", 0, "INT", 2, "warped but it still channels",   13),
    // Offhand
    _off_cracked_shield,
    create_item("Ash Totem",          "offhand", 0, "WIS", 1, "carved wood talisman",      9),
    create_item("Soulstone Fragment", "offhand", 0, "INT", 1, "chip of raw soulstone",      9),
    // Helm
    create_item("Ashen Hood",         "helm",    0, "DEX", 1, "protects from vault dust",   9),
    create_item("Bone Cap",           "helm",    0, "CON", 1, "crude skull-shaped guard",   8),
    create_item("Tarnished Visor",    "helm",    0, "STR", 1, "bent but still sturdy",      8),
    // Chest - spread across stats so every class finds usable chests (was CON/DEX only).
    create_item("Tattered Robes",     "chest",   0, "CON", 1, "",                          10),
    create_item("Rusted Chainshirt",  "chest",   0, "CON", 2, "rough but solid",            11),
    create_item("Shadowcloth Tunic",  "chest",   0, "DEX", 1, "woven shadow-thread",         9),
    create_item("Spellweave Robe",    "chest",   0, "INT", 1, "rune-stitched cloth",         9),
    create_item("Acolyte Vestment",   "chest",   0, "WIS", 1, "simple temple garb",          9),
    create_item("Padded Brigandine",  "chest",   0, "STR", 1, "quilted and studded",        10),
    // Gloves
    create_item("Worn Gauntlets",     "gloves",  0, "STR", 1, "old iron, liner rotted",     8),
    create_item("Nimble Wraps",       "gloves",  0, "DEX", 1, "tight cloth for grip",       8),
    create_item("Sage's Gloves",      "gloves",  0, "INT", 1, "finger-cut for rune work",   7),
    // Boots
    create_item("Worn Treads",        "boots",   0, "DEX", 1, "good for running",            7),
    create_item("Ironshod Boots",     "boots",   0, "CON", 1, "iron toe-caps",               8),
    create_item("Dustwalker Wraps",   "boots",   0, "WIS", 1, "padded foot-wrappings",       7),
    // Amulet
    create_item("Dusty Amulet",       "amulet",  0, "WIS", 1, "",                            8),
    create_item("Bone Talisman",      "amulet",  0, "CON", 1, "carved from femur bone",      8),
    create_item("Silver Chain",       "amulet",  0, "CHA", 1, "tarnished but charming",      7),
    // Ring
    create_item("Bone Ring",          "ring",    0, "INT", 1, "",                            8),
    create_item("Copper Signet",      "ring",    0, "STR", 1, "crest of no house",           7),
    create_item("Tarnished Band",     "ring",    0, "DEX", 1, "worn smooth",                  7),
];

global.loot_table_uncommon = [
    // Weapons. Class-locked (unique_effect) + generic (class_req -1) bases.
    _uw_gravel,
    _uw_wand,
    _uw_sickle,
    _2hw_greatsword,
    _2hw_longbow,
    _ew_flaming,
    _ew_frost,
    create_item("Iron Saber",     "weapon",        1, "STR", 4, "a heavy cavalry saber",          34),
    create_item("Soldier's Pike", "weapon",        1, "STR", 4, "a long infantry pike",           34),
    create_item("Recurve Bow",    "ranged_weapon", 1, "DEX", 4, "a hunter's recurve",             36),
    create_item("Oak Staff",      "ranged_weapon", 1, "INT", 4, "a channeling staff of seasoned oak", 36),
    create_item("Brass Scepter",  "ranged_weapon", 1, "INT", 4, "a tarnished ceremonial scepter", 35),
    // Offhand
    _off_buckler,
    create_item("Runic Focus",         "offhand", 1, "INT", 3, "inscribed with focusing runes", 32),
    // Helm
    create_item("Watcher's Cowl",      "helm",    1, "INT", 3, "hood of a Vault Watcher",       28),
    create_item("Iron Skullcap",       "helm",    1, "CON", 3, "riveted steel, dented solid",   26),
    // Chest
    create_item("Shadowthread Vest",   "chest",   1, "DEX", 3, "",                              32),
    create_item("Ashwarden Coat",      "chest",   1, "CON", 3, "ash-fiber reinforced leather",  28),
    create_item("Mage's Robe",         "chest",   1, "INT", 3, "woven for spell-focus",         30),
    create_item("Druidic Wrap",        "chest",   1, "WIS", 3, "bound with living vine",         29),
    create_item("Soldier's Cuirass",   "chest",   1, "STR", 3, "battered campaign plate",        30),
    // Gloves
    create_item("Irongrip Gauntlets",  "gloves",  1, "STR", 3, "weighted knuckles",             26),
    create_item("Fleethand Wraps",     "gloves",  1, "DEX", 3, "moves with the wearer",         28),
    // Boots
    create_item("Vaultstrider Boots",  "boots",   1, "DEX", 3, "built for confined spaces",     27),
    create_item("Stoneguard Greaves",  "boots",   1, "CON", 3, "leg plates absorb each blow",   26),
    // Amulet
    create_item("Sentry's Pendant",    "amulet",  1, "WIS", 3, "",                              28),
    create_item("Soul-Linked Talisman","amulet",  1, "INT", 3, "arcane resonance",              30),
    // Ring
    _ember_ring,
    create_item("Voidtouched Ring",    "ring",    1, "INT", 3, "hums with void energy",         28),
    _sch_blood,   // +1 Blood school damage (demo)
    _sch_venom,   // +1 Poison school damage (demo)
];

global.loot_table_rare = [
    // Weapons. Class-locked (unique_effect) + generic (class_req -1) bases.
    // Generic rare names resolve to the matching stat so the Rare+ stat gate
    // (req_stat_curve = 12) steers each one to the right class.
    _rw_ash,
    _rw_vsept,
    _rw_serp,
    _2hw_staff,
    _ew_storm,
    create_item("Tempered Saber",  "weapon",        2, "STR", 6, "folded steel, keen and balanced",      78),
    create_item("Warden's Spear",  "weapon",        2, "STR", 6, "the long spear of a vault warden",      78),
    create_item("Reaper's Sickle", "weapon",        2, "DEX", 6, "a wicked curved harvesting hook",       78),
    create_item("Vaultwood Bow",   "ranged_weapon", 2, "DEX", 6, "cut from rare vault-grown wood",        80),
    create_item("Crystal Wand",    "ranged_weapon", 2, "INT", 6, "a focusing wand tipped with raw crystal", 80),
    create_item("Runed Staff",     "ranged_weapon", 2, "INT", 6, "etched with channeling runes",          80),
    // Offhand
    _off_soul_orb,
    _off_bulwark,
    // Helm
    _forsaken_circlet,
    create_item("Thornwarden Helm",    "helm",    2, "STR", 5, "war-crest of a fallen guardian", 75),
    // Chest
    create_item("Voidskin Coat",       "chest",   2, "INT", 5, "stitched from void-touched hide; it drinks the light", 75),
    create_item("Ironveil Plate",      "chest",   2, "CON", 7, "",                              90),
    create_item("Archmage Vestment",   "chest",   2, "INT", 5, "humming with ley-energy",       80),
    create_item("Oracle Mantle",       "chest",   2, "WIS", 5, "embroidered with seer-sigils",  78),
    create_item("Warplate Cuirass",    "chest",   2, "STR", 7, "forged for front-line wardens",  90),
    // Gloves
    create_item("Crushers",            "gloves",  2, "STR", 5, "massive war-gauntlets",         72),
    create_item("Whispergloves",       "gloves",  2, "DEX", 5, "make no sound at all",          75),
    // Boots
    create_item("Shadowstep Boots",    "boots",   2, "DEX", 5, "move between shadows",          74),
    create_item("Colossus Stompers",   "boots",   2, "CON", 6, "each step shakes the floor",    78),
    // Amulet
    create_item("Enduring Medallion",   "amulet",2, "CON", 5, "endures where others break",    72),
    create_item("Warden's Eye",        "amulet",  2, "WIS", 5, "see threats before they strike", 75),
    _sch_ember,   // +4 Fire school damage (demo)
    // Ring
    create_item("Wraithbone Signet",   "ring",    2, "WIS", 5, "",                              70),
    create_item("Bloodpact Ring",      "ring",    2, "STR", 5, "sealed in blood",               72),
];

// --- LEGENDARY LOOT TABLE - boss-drop only (5% weight) ---
// Each legendary has fixed affixes and a unique effect hook (unique_effect string).
// unique_desc is the in-game text shown in gold; unique_effect is the code identifier.
var _leg_brand = create_item("Gatewarden's Brand", "weapon", 4, "STR", 5,
    "carried by those who sealed the vault gates", 400);
_leg_brand.class_req    = -1;
_leg_brand.affixes      = [{ suffix: "of Grit", prefix: "Sturdy", stat_name: "CON", stat_value: 2 }];
_leg_brand.unique_effect = "gatewarden_brand";
_leg_brand.unique_desc   = "First ability each combat costs 0 AP";
_leg_brand.lore = "Forged for the wardens who chained the vault shut from the inside, knowing they would never leave. Its edge still remembers the weight of the gate - and swings as if no burden could ever slow the first blow.";

var _leg_aegis = create_item("Heartstone Aegis", "chest", 4, "CON", 6,
    "warm to the touch, even in the coldest vault", 400);
_leg_aegis.class_req    = -1;
_leg_aegis.affixes      = [{ suffix: "of Clarity", prefix: "Wise", stat_name: "WIS", stat_value: 2 }];
_leg_aegis.unique_effect = "heartstone_aegis";
_leg_aegis.unique_desc   = "Heal 6 HP whenever an enemy dies";
_leg_aegis.lore = "A shard of the vault's buried heart, still beating long after the body around it failed. Those who wear it feel a borrowed warmth with every enemy that falls - the stone feeding on endings to keep its bearer from one.";

var _leg_crown = create_item("Crown of the Hollow King", "helm", 4, "INT", 4,
    "the king who vanished is still being waited for", 400);
_leg_crown.class_req    = -1;
_leg_crown.affixes      = [{ suffix: "of Clarity", prefix: "Wise", stat_name: "WIS", stat_value: 3 }];
_leg_crown.unique_effect = "crown_hollow_king";
_leg_crown.unique_desc   = "+1 trait slot while equipped (3 total)";
_leg_crown.lore = "The Hollow King walked into the deepest vault and never came out; his court still sets a throne for his return. To wear his crown is to carry a little of that endless waiting - and the wider, sharper mind of someone who has stopped expecting an answer.";

var _leg_thief = create_item("Thief of Hours", "ring", 4, "DEX", 6,
    "inscribed with the last seconds of a dying mage", 400);
_leg_thief.class_req    = -1;
_leg_thief.affixes      = [{ suffix: "of Clarity", prefix: "Wise", stat_name: "WIS", stat_value: 2 }];
_leg_thief.unique_effect = "thief_of_hours";
_leg_thief.unique_desc   = "Gain +1 AP on the first turn of every combat";
_leg_thief.lore = "A dying mage spent her final spell not to survive, but to keep the last seconds of her life - and bound them into this ring. Whoever wears it begins each fight already a heartbeat ahead, spending borrowed time she will never get back.";

// --- 07-28 EXPANSION (M approved all 10; "same Crown 3x" variety report) ------
// Every unique effect rides an existing mechanic; wiring lives at the same
// sites as the original four (flag scan in obj_combat_controller Create_0).
var _leg_rebuke = create_item("Duelist's Rebuke", "gloves", 4, "DEX", 4,
    "the answer arrives before the question ends", 400);
_leg_rebuke.class_req     = -1;
_leg_rebuke.affixes       = [{ suffix: "of Ruin", prefix: "Runed", stat_name: "crit_flat", stat_value: 4 }];
_leg_rebuke.unique_effect = "duelists_rebuke";
_leg_rebuke.unique_desc   = "After you dodge, your next ability deals +50% damage";
_leg_rebuke.lore = "Stitched for a duelist who never blocked - only stepped aside and made the miss cost everything. The leather still remembers the rhythm: their blade passes, yours answers.";

var _leg_treads = create_item("Gravewalker Treads", "boots", 4, "CON", 4,
    "they have walked out of places nothing walks out of", 400);
_leg_treads.class_req     = -1;
_leg_treads.affixes       = [{ suffix: "of Vitality", prefix: "Vital", stat_name: "bonus_max_hp", stat_value: 12 }];
_leg_treads.unique_effect = "gravewalker_treads";
_leg_treads.unique_desc   = "Once per run, survive a killing blow at 1 HP";
_leg_treads.lore = "Their first owner was buried in them. Their second owner found them on his own feet, standing outside the grave, with no memory of digging. They know one trick, and it only works once - but once is the whole difference.";

var _leg_chalice = create_item("Sanguine Chalice", "amulet", 4, "CON", 6,
    "it does not spill; it keeps", 400);
_leg_chalice.class_req     = -1;
_leg_chalice.affixes       = [{ suffix: "of Might", prefix: "Iron", stat_name: "STR", stat_value: 2 }];
_leg_chalice.unique_effect = "sanguine_chalice";
_leg_chalice.unique_desc   = "Overkill damage on killing blows heals you (up to 20)";
_leg_chalice.lore = "A chalice worn as a pendant, mouth upturned. Whatever violence exceeds what the dying could hold, the cup catches - and offers back to the hand that swung.";

var _leg_loop = create_item("Stormcaller's Loop", "ring", 4, "INT", 6,
    "lightning never asks for one target", 400);
_leg_loop.class_req     = -1;
_leg_loop.affixes       = [];   // same-stat affix folded into base (M rule 07-09: never "+4 INT +2 INT")
_leg_loop.unique_effect = "stormcallers_loop";
_leg_loop.unique_desc   = "Single-target spells echo 25% of their damage to another enemy";
_leg_loop.lore = "Forged in a storm that struck the same tower nine times, as if correcting itself. Spells cast through it arrive the same way - mostly where they were sent, and a little where they wanted to go.";

var _leg_miser = create_item("Miser's Blade", "weapon", 4, "STR", 5,
    "it cuts deeper for the rich", 400);
_leg_miser.class_req     = -1;
_leg_miser.affixes       = [{ suffix: "of Greed", prefix: "Lucky", stat_name: "gold_find", stat_value: 6 }];
_leg_miser.unique_effect = "misers_blade";
_leg_miser.unique_desc   = "+1 damage per 125 gold held (max +10)";
_leg_miser.lore = "A merchant-prince had it forged with a hollow hilt to hide his fortune. The blade learned to love the weight - the fuller the purse behind the swing, the hungrier the edge in front of it.";

// 07-30: reslotted offhand -> helm (M: a veil belongs on the head; offhand
// never read right). veil_slot_fixup() migrates the stale slot in old saves.
var _leg_veil = create_item("Veil of the Patient Dark", "helm", 4, "WIS", 4,
    "the dark does not hide you; it simply goes first", 400);
_leg_veil.class_req     = -1;
_leg_veil.affixes       = [{ suffix: "of Shadows", prefix: "Ghost", stat_name: "dodge_flat", stat_value: 5 }];
_leg_veil.unique_effect = "veil_patient_dark";
_leg_veil.unique_desc   = "Enter every combat concealed - the first enemy attack on you misses";
_leg_veil.lore = "Cut from a shadow that outlived the thing that cast it. Drawn across the brow, it drapes its bearer in the moment before being noticed - and holds that moment open exactly once per fight.";

var _leg_longshot = create_item("Longshot's Memory", "ranged_weapon", 4, "DEX", 6,
    "it has already made this shot", 400);
_leg_longshot.class_req     = -1;
_leg_longshot.affixes       = [];   // same-stat affix folded into base
_leg_longshot.unique_effect = "longshots_memory";
_leg_longshot.unique_desc   = "Your first hit each combat is a guaranteed critical";
_leg_longshot.lore = "Its maker fired one perfect shot and spent thirty years failing to repeat it - so she built the memory into the weapon instead. Every fight, it gets to be that morning again. Once.";

var _leg_line = create_item("Aegis of the Unbroken Line", "chest", 4, "CON", 6,
    "the line held; the line holds", 400);
_leg_line.class_req     = -1;
_leg_line.affixes       = [];   // same-stat affix folded into base
_leg_line.unique_effect = "aegis_unbroken_line";
_leg_line.unique_desc   = "End your turn with AP unspent: each grants 3 shield instead of 2, and the cap is doubled";
_leg_line.lore = "Worn by the last soldier of a shield-wall that never broke - it simply, eventually, had one man left. Patience sits differently on those shoulders: every held breath becomes wall.";

var _leg_signet = create_item("Hollow King's Signet", "ring", 4, "CHA", 6,
    "his credit, at least, survived him", 400);
_leg_signet.class_req     = -1;
_leg_signet.affixes       = [];   // same-stat affix folded into base
_leg_signet.unique_effect = "hollow_kings_signet";
_leg_signet.unique_desc   = "All vendor prices reduced 15%";
_leg_signet.lore = "The Hollow King's seal still closes deals in Ironwake - merchants honor it without quite knowing why, the way one honors a debt to someone who might yet walk back in. Pairs uneasily well with his crown.";

var _leg_censer = create_item("Ember Saint's Censer", "amulet", 4, "INT", 6,
    "what it blesses, burns longer", 400);
_leg_censer.class_req     = -1;
_leg_censer.affixes       = [];   // same-stat affix folded into base
_leg_censer.unique_effect = "ember_saints_censer";
_leg_censer.unique_desc   = "Your damage-over-time effects tick +2 harder";
_leg_censer.lore = "Swung by a saint who preached that no fire should be lit halfway. The incense never quite burns out, and neither does anything its bearer sets alight - poison, flame or wound, all of it lingers meaner.";

// --- Second wave (M approved 5 more, same day) --------------------------------
var _leg_shard = create_item("Oathbreaker's Shard", "weapon", 4, "STR", 4,
    "every ending it delivers, it keeps a piece of", 400);
_leg_shard.class_req     = -1;
_leg_shard.affixes       = [{ suffix: "of Grit", prefix: "Sturdy", stat_name: "CON", stat_value: 2 }];
_leg_shard.unique_effect = "oathbreakers_shard";
_leg_shard.unique_desc   = "Killing blows grant +1 max HP for the rest of the run (max +20)";
_leg_shard.lore = "A fragment of a sword that broke swearing the wrong oath. It has been trying to become whole ever since - and it has decided your body will do. Every life it ends, it invests.";

var _leg_lantern = create_item("Lantern of the Last Door", "offhand", 4, "WIS", 6,
    "it lights the option you almost missed", 400);
_leg_lantern.class_req     = -1;
_leg_lantern.affixes       = [];   // same-stat affix folded into base
_leg_lantern.unique_effect = "lantern_last_door";
_leg_lantern.unique_desc   = "The Whetstone offers a second honing each run";
_leg_lantern.lore = "Carried by a scholar who mapped the vaults by what everyone else walked past. Held near the Whetstone, its light finds one more edge in the stone - the sharpening the dark kept for itself.";

var _leg_diadem = create_item("Crownfire Diadem", "helm", 4, "INT", 7,
    "no fire should be spent halfway", 400);
_leg_diadem.class_req     = -1;
_leg_diadem.affixes       = [];   // same-stat affix folded into base
_leg_diadem.unique_effect = "crownfire_diadem";
_leg_diadem.unique_desc   = "OVERCHARGE deals +4 damage per point drained (instead of +2)";
_leg_diadem.lore = "Beaten from the crown of a king who ruled by burning everything he had, every time. Worn now, it teaches the same arithmetic to your reserve: hold nothing back, and the holding-nothing hits harder.";

var _leg_beggar = create_item("Beggar's Fortune", "amulet", 4, "CHA", 4,
    "wealth finds it; merchants smell it", 400);
_leg_beggar.class_req     = -1;
_leg_beggar.affixes       = [{ suffix: "of Greed", prefix: "Lucky", stat_name: "gold_find", stat_value: 6 }];
_leg_beggar.unique_effect = "beggars_fortune";
_leg_beggar.unique_desc   = "Found gold +25%, but every shop charges you +10%";
_leg_beggar.lore = "A beggar wore it and died the richest man in Ironwake - because he never once got to spend at a fair price. Coins leap to the wearer's hand, and every merchant in town somehow knows it.";

var _leg_reliq = create_item("Kindled Reliquary", "ring", 4, "WIS", 4,
    "the fire inside never fully goes out", 400);
_leg_reliq.class_req     = -1;
_leg_reliq.affixes       = [{ suffix: "of Vitality", prefix: "Vital", stat_name: "bonus_max_hp", stat_value: 8 }];
_leg_reliq.unique_effect = "kindled_reliquary";
_leg_reliq.unique_desc   = "Start every combat with +2 of your class resource";
_leg_reliq.lore = "A reliquary ring holding an ember of something that refuses naming. Between fights it smolders; when blades come out, its warmth is already banked in your chest - a head start the dark never accounts for.";

// --- Delivery-mutator wave (M design-locked 08-11, SYSTEMS_MUTATORS.md):
// the STRONG tier of the four mutators, one chase item each. Any qualifying
// SPELL the wearer casts carries the effect (one mutator per cast). ---
var _leg_skip = create_item("Stormskip Band", "ring", 4, "INT", 5,
    "lightning never could sit still", 400);
_leg_skip.class_req     = -1;
_leg_skip.affixes       = [];
_leg_skip.unique_effect = "stormskip_band";
_leg_skip.unique_desc   = "Your damaging spells BOUNCE - arcing on to one other enemy at 60% damage (shock arcs harder)";
_leg_skip.lore = "A band hammered from a bell tower's lightning rod. Whatever the wearer hurls refuses to stop at the first thing it hits - the storm always wants one more.";

var _leg_prism = create_item("Prism of the Twinned Flame", "offhand", 4, "INT", 6,
    "one light in, two fires out", 400);
_leg_prism.class_req     = -1;
_leg_prism.affixes       = [];
_leg_prism.unique_effect = "twinned_prism";
_leg_prism.unique_desc   = "Your damaging spells SPLIT - forking to a second enemy at 70% damage (arcane forks harder)";
_leg_prism.lore = "Ground by a glasswright who swore no flame should die single. Held to the light it shows two of everything - held to a spell, it makes the lie true.";

var _leg_toll = create_item("Bell of the Second Toll", "amulet", 4, "WIS", 5,
    "everything it rings, rings twice", 400);
_leg_toll.class_req     = -1;
_leg_toll.affixes       = [];
_leg_toll.unique_effect = "second_toll";
_leg_toll.unique_desc   = "Your damaging spells ECHO - striking their target again moments later at 50% damage (void echoes harder)";
_leg_toll.lore = "Cut from a funeral bell that would not stop sounding. Its second toll always comes - a breath late, a little softer, and no less final.";

var _leg_smolder = create_item("Smolderbrand Mantle", "chest", 4, "CON", 6,
    "what it touches, keeps burning", 400);
_leg_smolder.class_req     = -1;
_leg_smolder.affixes       = [];
_leg_smolder.unique_effect = "smolderbrand";
_leg_smolder.unique_desc   = "Your damaging spells LINGER - leaving a 2-turn burn at 45% of the hit per turn (fire and poison linger harder)";
_leg_smolder.lore = "A mantle pulled from a pyre that had opinions. Its wearer's magic learns the same stubbornness: no wound is finished the moment it is made.";

global.loot_table_legendary = [ _leg_brand, _leg_aegis, _leg_crown, _leg_thief,
    _leg_rebuke, _leg_treads, _leg_chalice, _leg_loop, _leg_miser,
    _leg_veil, _leg_longshot, _leg_line, _leg_signet, _leg_censer,
    _leg_shard, _leg_lantern, _leg_diadem, _leg_beggar, _leg_reliq,
    _leg_skip, _leg_prism, _leg_toll, _leg_smolder ];

// --- AFFIX POOL - 10 affixes, rolled at drop time for uncommon+ items ---
// u_val/r_val/e_val = stat bonus at uncommon / rare / epic rarity.
// Special stat_names: bonus_max_hp (flat HP), crit_flat (%crit), dodge_flat (flat dodge),
//                     gold_find (% bonus, display only - hook in add_gold for future use).
global.affix_pool = [
    { suffix: "of Might",    prefix: "Iron",    stat_name: "STR",          u_val: 1, r_val: 2, e_val: 3 },
    { suffix: "of Grace",    prefix: "Swift",   stat_name: "DEX",          u_val: 1, r_val: 2, e_val: 3 },
    { suffix: "of Grit",     prefix: "Sturdy",  stat_name: "CON",          u_val: 1, r_val: 2, e_val: 3 },
    { suffix: "of Insight",  prefix: "Arcane",  stat_name: "INT",          u_val: 1, r_val: 2, e_val: 3 },
    { suffix: "of Clarity",  prefix: "Lucid",   stat_name: "WIS",          u_val: 1, r_val: 2, e_val: 3 },
    { suffix: "of Charm",    prefix: "Gilded",  stat_name: "CHA",          u_val: 1, r_val: 2, e_val: 3 },
    { suffix: "of Vitality", prefix: "Vital",   stat_name: "bonus_max_hp", u_val: 5, r_val: 10, e_val: 15 },
    { suffix: "of Ruin",     prefix: "Runed",   stat_name: "crit_flat",    u_val: 3, r_val: 5,  e_val: 8  },
    { suffix: "of Shadows",  prefix: "Ghost",   stat_name: "dodge_flat",   u_val: 3, r_val: 5,  e_val: 8  },
    { suffix: "of Greed",    prefix: "Lucky",   stat_name: "gold_find",    u_val: 3, r_val: 5,  e_val: 8  },
    // Typed crit (07-31, M): narrower than "of Ruin" so they roll higher.
    // Spell crit feeds INT/WIS (Arcane/Effect) rolls only; phys crit STR/DEX.
    { suffix: "of Hexruin",  prefix: "Hexed",   stat_name: "crit_spell",   u_val: 4, r_val: 7,  e_val: 11 },
    { suffix: "of Bloodshed", prefix: "Honed",  stat_name: "crit_phys",    u_val: 4, r_val: 7,  e_val: 11 },
];

// School-damage affix pool (SYSTEMS_ELEMENT_SCHOOLS.md §F1, Phase 2).
// Flat "+X <school> damage" affixes that roll ONLY on caster slots
// (amulet / ring / focus-type offhand) via roll_affixes(). Magnitude is set by
// the per-tier rule in school_affix_value() (uncommon +1, rare +2-4, epic +5-6),
// NOT fixed u/r/e values, so these entries carry only naming + the school key.
// stat_name "school_<name>" is routed into school_dmg by _equip_apply_stat.
// Caster-flavored prefix/suffix, kept distinct from the weapon elemental affixes.
global.school_affix_pool = [
    { school: "fire",   stat_name: "school_fire",   prefix: "Smoldering",   suffix: "of Flames"      },
    { school: "frost",  stat_name: "school_frost",  prefix: "Rimebound",    suffix: "of Rime"        },
    { school: "shock",  stat_name: "school_shock",  prefix: "Voltaic",      suffix: "of Thunder"     },
    { school: "arcane", stat_name: "school_arcane", prefix: "Eldritch",     suffix: "of Mysteries"   },
    { school: "poison", stat_name: "school_poison", prefix: "Toxic",        suffix: "of Venom"       },
    { school: "void",   stat_name: "school_void",   prefix: "Voidtouched",  suffix: "of the Void"    },
    { school: "shadow", stat_name: "school_shadow", prefix: "Umbral",       suffix: "of Shadow"      },
    { school: "blood",  stat_name: "school_blood",  prefix: "Sanguine",     suffix: "of Bloodletting"},
];

// -----------------------------------------------------------------------------
// ITEM NAME FUSION (see ITEM_NAMING_FUSION.md).
// When a weapon's elemental rider lands on an item that ALREADY ends in a stat
// affix's "of {noun}", we fuse the two into ONE lore phrase instead of the
// awkward double "of X of Y" (e.g. "Blade of Charm of Frost" -> "Blade of
// Frostbound Charm"). Resolution (item_fused_elem_suffix): bespoke pair override
// first, else composed "of {name_combine_adj[element]} {statNoun}".
//
// name_combine_adj: the adjective each weapon element lends to the fused phrase.
// Falls back to the element's display prefix if an element is missing here.
global.name_combine_adj = {
    frost: "Frostbound",     // reads great as-is
    burn:  "Emberwreathed",  // cooler than the plain display prefix "Flaming"
    shock: "Stormbound",     // drops the awkward mid-name hyphen of "Storm-touched"
};

// name_bespoke_pairs: hand-authored phrases for specific element x stat combos,
// overriding the composed default. Grow this freely - any pair NOT listed still
// auto-fuses cleanly, so there is never an awkward name. Keys: elem = weapon
// element ("burn"/"frost"/"shock"); stat = the stat affix's stat_name.
global.name_bespoke_pairs = [
    { elem: "frost", stat: "CHA",       phrase: "of Winterheart"    },
    { elem: "burn",  stat: "CHA",       phrase: "of the Ember Muse"  },
    { elem: "shock", stat: "INT",       phrase: "of the Tempest Mind"},
    { elem: "frost", stat: "crit_flat", phrase: "of Shatterfrost"    },
    { elem: "burn",  stat: "STR",       phrase: "of the Forgeborn"   },
];


// -----------------------------------------------------------------------------
// 7. CONSUMABLES
// Pools used by handle_enemy_drops(); player inventory resets each run.
// -----------------------------------------------------------------------------
global.consumables_standard = [
    create_consumable("Healing Salve",    "heal",           25, "Restore 25 HP",                    20),
    create_consumable("Antidote",         "cleanse_dot",     0, "Clear all active DoT effects",      18),
    create_consumable("Energy Tonic",     "energy",          1, "Gain +1 AP this turn (free to use)", 15),
    create_consumable("Smelling Salts",   "cleanse_debuff",  0, "Remove one active debuff",          16),
];

global.consumables_elite = [
    create_consumable("Greater Healing Salve", "heal",        50, "Restore 50 HP",                          45),
    create_consumable("Purification Draught",  "cleanse_all",  0, "Clear all negative effects",             50),
    create_consumable("Adrenaline Vial",        "energy",       3, "Gain +3 AP this turn (free to use)",     55),
    create_consumable("Warden's Tonic",         "heal_dot",     8, "Restore 8 HP per turn for 3 turns",      48),
];

// Master (3rd) tier - the targets of Sable's elite->master upgrade rung. Names + stats
// match the matching brew-catalog potions (so the icons already resolve). Only the
// effects with a meaningful step up have a master rung (heal, heal-over-time).
global.consumables_master = [
    create_consumable("Master Healing Draught", "heal",     90, "Restore 90 HP",                       70),
    create_consumable("Phoenix Tonic",          "heal_dot", 15, "Restore 15 HP per turn for 3 turns",  60),
];

// Per-run consumable inventory (uncapped; lists scroll) and item drop log
global.consumable_inventory = [];
global.run_items_found      = [];

// Equipment slots - 10 entries, one per slot (undefined = empty)
// Index 8 = Ranged Weapon (appended; SYSTEMS_WEAPON_ROLES.md §A).
// Index 9 = Ring 2 (second ring position; accepts "ring" items).
global.inventory = array_create(EQUIP_SLOT_COUNT, undefined);

// Item codex - records base names of every equipment item ever found or bought
global.items_discovered = [];

// Item storage
global.equipment_stash    = [];   // safe hub storage - never lost on death
global.carried_items      = [];   // unequipped equipment in pack during a run - at risk on death
global.consumable_stash   = [];   // consumables stored safely in the hub
global.secure_slots       = 0;    // future trait: guaranteed-safe carried item count
global.secured_items      = [];   // indices into carried_items marked safe (unused while secure_slots==0)
global.last_run_mercy_item = "";  // name of the one item salvaged on defeat (shown on result screen)


// -----------------------------------------------------------------------------
// 7. RUN HISTORY
// Append-only array of run record structs written by end_run().
// Displayed on the hub history screen (H key).
// -----------------------------------------------------------------------------
global.run_history = [];


// -----------------------------------------------------------------------------
// 8. HUB PROGRESSION
// Incremented on each successful dungeon clear. Used by hub objects to gate
// upgrades, unlock NPCs, and advance the overworld narrative.
// -----------------------------------------------------------------------------
global.hub_unlocks = 0;

// Cleared state for each room on the current floor - persists across the
// combat room transition so the floor map is not reset on return.
global.floor_rooms_cleared = [];


// add_gold() and end_run() live in scripts/scr_stats/scr_stats.gml so they
// are available globally without depending on this object's scope.


// -----------------------------------------------------------------------------
// 9. CHARACTER MENU STATE
// Owned here so the menu works across all rooms without a separate object.
// -----------------------------------------------------------------------------
menu_open            = false;
menu_tab             = 0;
tab_names            = ["Stats", "Equipment", "Abilities", "Consumables"];   // Compendium -> Journal (2026-07-04)
items_used_this_turn = 0;

// Compendium (Help) tab state - index of the selected section in the left list
compendium_section   = 0;

// Abilities tab state - index of the selected ability (left list -> right breakdown)
ability_view_cursor  = 0;

// Abilities tab sub-pages (08-08, M: "abilities - class trunk - talents that can
// be scrolled between with A and D, just like inventory equipment"). One cursor,
// one binding: A/D walk the three pages, no per-page hotkeys.
//   0 = ABILITIES (loadout + breakdown)   1 = CLASS TRUNK   2 = TALENTS
#macro ABILITY_PAGE_COUNT 3
ability_page = 0;

// Class trunk page state. The 10 nodes are walked as ONE cursor in reading order
// (row 0 left, row 0 right, row 1 left, ...) with W/S, so left/right stays free
// for page switching. trunk_cursor/trunk_side are derived from it for the draw.
// arm = the two-step confirm on a permanent exclusive pick.
trunk_cursor    = 0;
trunk_side      = 0;
trunk_arm       = false;

// Talents page state: which ability's web summary is expanded.
talent_cursor   = 0;

// Equipment tab state
equip_slot_selected = 0;
equip_picker_open   = false;
equip_picker_index  = 0;
equip_picker_scroll = 0;    // picker scroll offset (edge-triggered window)
equip_msg           = "";   // class-restriction warning shown in the picker
equip_notif_msg     = "";   // brief "Equipped X" confirmation
equip_notif_timer   = 0;    // counts down from 150; fades in last 30 frames
// Right-hand "found items" (pack) column on the Equipment tab.
equip_found_focus   = false;  // is the found-items column focused (vs the slot list)?
equip_found_cursor  = 0;
equip_found_sort    = 0;      // 0 = by rarity, 1 = by type/slot

comparison_open     = false;
comparison_item     = undefined;
comparison_equipped = undefined;

// Consumable tab submenu state
consumable_submenu_open   = false;
consumable_submenu_cursor = 0;

// Hub stash screen state
stash_mode_open  = false;   // full stash deposit/withdraw screen
stash_mode_side  = 0;       // 0 = carried column, 1 = stash column
stash_mode_index = 0;
stash_scroll     = 0;       // active column scroll offset (edge-triggered window)
stash_mode_tab   = 0;       // 0 = equipment, 1 = consumables (Q/E)


// -----------------------------------------------------------------------------
// 10. XP / LEVELING
// -----------------------------------------------------------------------------
global.run_xp              = 0;
global.run_level           = 1;
global.pending_stat_points = 0;
global.run_stat_bonuses    = { STR: 0, DEX: 0, CON: 0, INT: 0, WIS: 0, CHA: 0 };

// Permanent allocation points (accumulate across runs, spent in hub)
global.pending_perm_points = 0;

// Post-combat stat allocation overlay (used by obj_combat_controller Draw/Step)
level_alloc_open         = false;
level_alloc_index        = 0;
level_alloc_pending_stat = -1;  // -1 = nothing chosen yet; 0-5 = provisional stat index

// Hub permanent stat allocation overlay
perm_alloc_open    = false;
perm_alloc_confirm = -1;   // armed row awaiting a second confirm (-1 = none) - permanent points deserve one
perm_alloc_index = 0;


// -----------------------------------------------------------------------------
// 11. SHOP STATE
// -1 = closed, 0 = Petra's Supplies, 1 = Dorn's Forge
// -----------------------------------------------------------------------------
global.petra_stock_special = undefined;   // elite consumable on special offer, or undefined
global.petra_special_qty   = 0;
global.dorn_stock          = [];          // array of { item, price, sold }

// Vex the Trainer overlay state (full-screen, opened from the hub NPC list)
trainer_open         = false;
trainer_tab          = 0;     // 0 = Stats, 1 = Trait Slots, 2 = Abilities, 3 = Potency
trainer_cursor       = 0;     // selected row within the active tab
trainer_confirm      = false; // true while a non-refundable sacrifice awaits Space
trainer_notification = "";

// Shared item-sacrifice picker (Vex stat/trait trade + Shrine tribute). One modal,
// initialized once; see SYSTEMS_ITEM_PICKER.md. Captures input while open so the
// underlying screen is frozen and nothing is consumed without select + confirm.
if (!variable_global_exists("item_picker")) global.item_picker = {
    open:             false,
    purpose:          "",   // "vex_trait" | "vex_stat" | "shrine_boon"
    context:          {},   // purpose-specific payload (gold/effect_id/stat_key/boon_id...)
    candidates:       [],   // [{ source, idx, item, label, rarity, value }]  source 0=stash 1=pack
    cursor:           0,
    scroll:           0,
    confirm:          false,// an item is selected, awaiting yes/no
    resolved_purpose: "",   // one-shot: set on commit so the owning controller does aftermath
    result_msg:       ""    // notification text produced by the resolve
};

// Cursed-rebirth reagent stage (M 08-05): multi-select "what exactly burns"
// modal, opened by the cursed_rebirth resolve. undefined = closed.
if (!variable_global_exists("reagent_picker")) global.reagent_picker = undefined;

// Sable salvage confirm gate (keeps Sable's own dust-preview list; just arms a yes/no).
sable_confirm = false;

shop_open         = -1;
shop_index        = 0;
shop_notification = "";
shop_tab          = 0;    // 0 = BUY tab, 1 = SELL tab, 2 = TRADE (Petra) / REFORGE (Dorn)
sell_index        = 0;    // sell-list cursor row
sell_scroll       = 0;    // sell-list scroll offset (top visible row)
buy_scroll        = 0;    // Petra BUY-list scroll offset (edge-triggered window)
sell_confirm_name = "";   // non-empty = rare item awaiting Space confirmation
reforge_index     = 0;    // REFORGE tab (Dorn, shop_tab == 2): gear-list cursor row
reforge_scroll    = 0;    // REFORGE tab: gear-list scroll offset

// Petra Treasure Trader tab (shop_tab == 2; Petra only). See PETRA_TT_PHASE1_SPEC.md.
petra_trade_cursor       = 0;     // stash-list row cursor
petra_trade_scroll       = 0;     // stash-list window scroll offset
petra_trade_selected     = [];    // chosen stash indices (up to 3, all same tier)
petra_trade_lever        = false; // Lever A (dust roll-bias) toggled on
petra_trade_confirm      = false; // a placement is awaiting the no-takeback confirm
petra_trade_notification = "";

// Initial stock - loot tables are defined above, so this is safe to call here
restock_shops();


// -----------------------------------------------------------------------------
// 12. ABILITY LOADOUT STATE
// global.player_loadout persists between runs; loadout_* are session state.
// -----------------------------------------------------------------------------
if (!variable_global_exists("player_loadout")) {
    global.player_loadout = ["", "", "", "", ""];
}

loadout_open       = false;
ability_detail_open = false;   // Tab detail popup over the loadout ability list
ability_detail_scroll = 0;     // vertical scroll offset (px) for the Tab ability-detail popup body
global.ui_ability_detail_max_scroll = 0;  // published by ui_draw_ability_detail each frame; input clamps to it
global.combat_log_breakdowns = true;       // hover a damage log line for a DnD-style math breakdown (Task 1; flip false to disable)
vex_detail_open     = false;   // Tab detail popup over the Vex ability/trait list
vex_detail_scroll   = 0;       // its W/S + wheel scroll offset (08-13 scroll audit)
loadout_cursor     = 0;
loadout_scroll     = 0;    // stateful list window top (edge-scrolling; self-corrects from cursor)
loadout_selected   = [];   // up to 4 ability name strings being built this session
loadout_full_timer = 0;    // countdown for "Loadout full" / "Slots full" flash (frames)
loadout_locked_timer = 0;  // countdown for "ability is locked - unlock at Vex" flash (frames)
loadout_gold_timer = 0;    // #6: countdown for the "can't afford trait respec" flash (frames)
loadout_gold_msg   = "";   // #6: the shortfall text shown while loadout_gold_timer > 0
loadout_confirmed  = false;
loadout_tab        = 0;    // 0 = Abilities tab, 1 = Traits tab
traits_cursor      = 0;
traits_selected    = [];   // up to 2 trait name strings being built this session


// -----------------------------------------------------------------------------
// 13. TRAIT SYSTEM STATE
// global.player_traits: up to 2 active trait names ("" = empty slot).
// global.traits_unlocked: which traits have been earned through progression.
// The three default universals (Sense, Scavenger, Thick Skin) start unlocked.
// -----------------------------------------------------------------------------
if (!variable_global_exists("player_traits")) {
    global.player_traits = ["", ""];
}
if (!variable_global_exists("traits_unlocked")) {
    global.traits_unlocked = {
        sense:            true,
        scavenger:        true,
        thick_skin:       true,
        lucky_find:       false,
        lucky_find_gold:  false,
        salvager:         false,
        soul_siphon:      false,
        crimson_reserve:  false,
        phantom_step:     false,
        // New traits - unlocked through progression
        quick_recovery:   false,
        treasure_hunter:  false,
        battle_hardened:  false,
        iron_will:        false,
        ley_tap:          false,
        arcane_surge:     false,
        vampiric_edge:    false,
        berserker_rage:   false,
        shadow_meld:       false,
        serrated_strikes:  false,
        expanded_arsenal:  false,
        prospector:        false,
        last_stand:        false,
        focused_power:     false,
        chain_caster:      false,
        plaguebearer:      false,
        relentless:        false,
    };
}
// Backfill newer trait keys onto save files that predate them.
var _tu_defaults = ["prospector", "last_stand", "focused_power", "chain_caster", "plaguebearer", "relentless"];
for (var _tui = 0; _tui < array_length(_tu_defaults); _tui++) {
    if (!variable_struct_exists(global.traits_unlocked, _tu_defaults[_tui])) {
        variable_struct_set(global.traits_unlocked, _tu_defaults[_tui], false);
    }
}

// Trait unlock notification - drawn as a toast banner in hub/floor draw events.
// Set trait_notif_msg and trait_notif_timer = 180 wherever a trait unlocks.
trait_notif_msg   = "";
trait_notif_timer = 0;

// -----------------------------------------------------------------------------
// 13b-RUNES. RUNE SYSTEM STATE (Maren the Runesmith) - see SYSTEMS_RUNES.md
// rune_inventory: unsocketed runes the player owns ({id,name,domain,tier} structs)
// rune_dust:      shared crafting reagent (Maren combines / Sable salvages)
// aspect_slots:   unlocked character Aspect-rune slots (start 2, cap 4)
// aspect_runes:   socketed Aspect runes (length <= aspect_slots)
// Socketed GEAR runes ride on each item struct (item.runes / item.socket_count).
// -----------------------------------------------------------------------------
if (!variable_global_exists("rune_inventory")) global.rune_inventory = [];
if (!variable_global_exists("rune_dust"))      global.rune_dust      = 0;
if (!variable_global_exists("aspect_slots"))   global.aspect_slots   = 2;
if (!variable_global_exists("aspect_runes"))   global.aspect_runes   = [];

// Maren the Runesmith screen state
maren_open         = false;
maren_tab          = 0;    // 0 Socket Gear, 1 Aspects, 2 Forge, 3 Runes, 4 Spirits
maren_cursor       = 0;    // row cursor in the active list
maren_phase        = 0;    // Socket tab: 0 choose item, 1 choose socket, 2 choose rune
maren_item_sel     = -1;   // chosen equipped-item slot index (0-7) in Socket tab
maren_notification = "";
maren_scroll       = 0;    // first visible row index (list windowing for long rune lists)
// Confirm modal: undefined = none, else { action, message, warn, cost } describing a
// pending gold-costing or destructive action awaiting Enter (confirm) / Esc (cancel).
maren_confirm      = undefined;

// Banshee release ceremony (Spirits tab, BANSHEE_BOTTLE_SPEC.md): a lore popup
// over Maren's station - bottle opens, banshee rises, melodic scream - then the
// reward text (unlocked track / dust bounty). Timer drives the animation frames.
banshee_release_open   = false;
banshee_release_timer  = 0;
banshee_release_result = undefined;   // { kind:"track", track } or { kind:"dust", amount }
banshee_scream_played  = false;

// Sable the Alchemist screen state (tabs: 0 Salvage, 1 Brew, 2 Upgrade)
sable_open         = false;
sable_tab          = 0;
sable_cursor       = 0;
sable_phase        = 0;    // Salvage tab: 0 menu, 1 gear list, 2 rune list
sable_notification = "";

// Bairc the Creature Keeper - pet stable / hatchery screen (Phase 2). Opens only once
// the player owns a pet (bairc_active()); dormant before that. See PETS_DESIGN.md.
bairc_open         = false;
bairc_cursor       = 0;
bairc_feed_page    = 0;        // feed-pouch page (6 hotkey rows per page, [A]/[D] flip)
bairc_notification = "";
bairc_detail_open  = false;   // Tab pet-kit detail popup over the station
companion_detail_open = false; // Tab pet-kit detail popup over the Gate Companion tab
bairc_naming       = false;    // text-entry modal for naming/renaming the selected pet
bairc_intro_open       = false;  // first-talk dialogue popup (before the station opens)
bairc_intro_armed      = false;  // ignores the interact keypress that opened it (1-frame arm)
bairc_capstone_open    = false;  // capstone PICK modal (raised Adult choosing its Stage-3 gift)
bairc_capstone_sel     = 0;      // highlighted capstone card (0/1)
bairc_capstone_confirm = false;  // two-step lock: Yes/No confirm after choosing
bairc_capstone_mode    = "cap";  // "cap" = Stage-3 capstone | "splash" = Awakened Stage-4 splash (same modal, different pool)
bairc_release_confirm  = false;  // "Donate" modal: entrust the highlighted creature to Bairc's garden
bairc_lore_open        = false;  // one-time lore-fragment dialogue (bond milestones / first donation, §10)
bairc_lore_armed       = false;  // same 1-frame arm as the intro so the opening keypress can't skip it
bairc_pad_menu_open    = false;  // gamepad action submenu (chunk 7b): A on a roster row lists the
bairc_pad_menu_cursor  = 0;      //   creature's actions (Set Active/Hatch, Feed..., Gift, Name, ...);
bairc_pad_menu_level   = 0;      //   0 = action list, 1 = feed list. Keyboard keeps the direct letters.

// --- JOURNAL (Phase 4a): J-key overlay, hub + floor map. Two tabs (Relationships /
// Quests), master-detail. VIEW/TRACK ONLY (Phase 4b UX) - quest actions live at the
// Tavern Requests board. See PHASE4A_SPEC.md / PHASE4B_SPEC.md. ---
journal_open    = false;
journal_tab     = 0;    // 0 = Relationships, 1 = Quests

// --- ITEM CODEX gallery (moved off obj_hub_controller 07-28 so it opens
// mid-run too - M: hardcore can't detour to camp to read it). Opened from the
// Journal's Item Codex tab; ui_draw_item_codex draws it at hub AND floor. ---
codex_open        = false;
codex_scroll      = 0;
codex_cursor      = -1;
codex_detail_item = undefined;
// P companion-inspect overlay (floor + combat; M 07-08). Freezes all room
// controllers via ui_input_blocked while open.
pet_inspect_open = false;
journal_cursor  = 0;    // Relationships: met-NPC row | Quests: flattened grouped row

// --- TAVERN REQUESTS board (Phase 4b UX): hub NPC-list row 8. Quests are read,
// accepted and turned in here (diegetic; the Journal only tracks). ---
tavern_board_open   = false;
tavern_board_cursor = 0;
tavern_board_note   = "";   // one-line feedback under the list (accepted / turned in / reasons)

// --- GIFT RESULT POPUP (Phase 4b UX): set by gift_give (global.gift_popup struct),
// dismissed on any confirm key; shows reaction, bond delta, tier + progress bar. ---
global.gift_popup = undefined;

// Full-screen hatch cutscene (shake -> crack -> reveal). Launched from the Bairc
// Enter-on-egg action; drawn over the Bairc screen by hatch_cutscene_draw().
hatch_active  = false;
hatch_pet     = undefined;
hatch_phase   = 0;      // 0 shake, 1 crack, 2 reveal
hatch_t       = 0;      // frame counter within the current phase
hatch_frame   = 0;      // current crack-animation frame (phase 1)
hatch_done    = false;  // pet_hatch() already applied (guards double-hatch)

// Vael the Aesthete - transmog/skins (player_skin = active skin id)
if (!variable_global_exists("player_skin"))    global.player_skin    = "default";
if (!variable_global_exists("unlocked_skins")) global.unlocked_skins = [];

// Cosmetic gender axis ("m"/"f") - chosen at character creation, combat sprite only.
if (!variable_global_exists("player_gender"))  global.player_gender  = "m";
vael_open            = false;
vael_cursor          = 0;
vael_notification    = "";
vael_tab             = 0;   // 0 = Skins (transmog), 1 = Portrait (100g portrait change), 2 = Tints (spell palettes)
vael_portrait_cursor = 0;   // browse index into global.portrait_sprites on the Portrait tab
vael_tint_cursor     = 0;   // row index into vael_tint_catalog() on the Tints tab

// Talent-web view (SYSTEMS_TALENT_WEBS.md; opened with M on the loadout Abilities tab)
web_view_open    = false;
talent_tour_step = -1;   // talent-web guided tour (08-04): -1 = off; arms on first web open
web_view_ability = "";   // ability NAME whose web is on screen
web_view_cursor  = 0;    // 0-5 = node order [p1,p2,pk,t1,t2,tk], 6 = SAVE & CLOSE, 7 = CLOSE
web_view_staged  = [];   // node ids assigned this session - permanent only on SAVE & CLOSE

// Knucklebones (expression #1; opened with K at the Tavern Requests board)
kb_open = false;
kb      = undefined;   // live game struct (kb_new_game)
// High Table tournament (dice v2): undefined = not running; else
// { stage: 0..2, opponents: [id,id,id] }. Not persisted - quitting forfeits.
kb_tourney = undefined;

// -----------------------------------------------------------------------------
// 13b. VEX THE TRAINER - permanent upgrades bought with gold (+items for stats)
// bonus_trait_slots: extra active-trait slots purchased (base 2, +4 max -> 6 total; M 07-16).
// unlocked_abilities: names of non-starter abilities purchased into the loadout pool.
// trait_potency: struct keyed by trait name -> potency tier (0-5); each tier adds
//                +10% to that trait's magnitude, paid for by permanently sacrificing
//                5 points of the trait's associated permanent stat.
// -----------------------------------------------------------------------------
if (!variable_global_exists("bonus_trait_slots")) global.bonus_trait_slots = 0;
if (!variable_global_exists("unlocked_abilities")) global.unlocked_abilities = [];
if (!variable_global_exists("trait_potency"))      global.trait_potency      = {};

// Persistent Battle Hardened HP bonus (accumulates across runs)
if (!variable_global_exists("perm_hp_battle_hardened")) global.perm_hp_battle_hardened = 0;
// Total boss kills across all runs (for trait/ability unlock gating)
if (!variable_global_exists("total_boss_kills")) global.total_boss_kills = 0;
// Highest character level ever reached in a run (persistent; gates char_level abilities)
if (!variable_global_exists("highest_run_level")) global.highest_run_level = 1;
// Last Stand trait: consumed once per run, reset at run start (end_run)
if (!variable_global_exists("last_stand_used")) global.last_stand_used = false;
// Player portrait selection (index into portrait_sprites array)
if (!variable_global_exists("chosen_portrait")) global.chosen_portrait = 0;

// Pause / Esc menu state (Resume / Settings / Quit to Title)
if (!variable_global_exists("pause_open"))   global.pause_open   = false;
if (!variable_global_exists("pause_cursor")) global.pause_cursor = 0;
// Set true at the top of this controller's Step whenever a gc-managed overlay/modal
// is open, so the hub's pause-menu trigger (a separate object that may step before us)
// won't also open the pause menu on the SAME Esc press that just closed the overlay.
if (!variable_global_exists("ui_overlay_latch")) global.ui_overlay_latch = false;
// Character-creation / hub portrait pool. The 60 class-themed portraits below
// (imported at 512x512) replace the old generic spr_portrait_01..11 placeholders,
// which still exist as resources but are no longer offered. One flat A/D cycle,
// grouped class -> gender (Arcanist M/F, Bloodwarden M/F, Shadowstrider M/F) with
// the named alt portraits (Deathweaver / Plaguehunter) at the end of each class.
global.portrait_sprites = [
    spr_portrait_arc_m1, spr_portrait_arc_m2, spr_portrait_arc_m3,
    spr_portrait_arc_m4, spr_portrait_arc_m5, spr_portrait_arc_m6,
    spr_portrait_arc_m7, spr_portrait_arc_m8, spr_portrait_arc_m9,
    spr_portrait_arc_f1, spr_portrait_arc_f2, spr_portrait_arc_f3,
    spr_portrait_arc_f4, spr_portrait_arc_f5, spr_portrait_arc_f6,
    spr_portrait_arc_f7, spr_portrait_arc_f8, spr_portrait_arc_deathweaver,
    spr_portrait_blood_m1, spr_portrait_blood_m2, spr_portrait_blood_m3,
    spr_portrait_blood_m4, spr_portrait_blood_m5, spr_portrait_blood_m6,
    spr_portrait_blood_m7, spr_portrait_blood_m8, spr_portrait_blood_m9,
    spr_portrait_blood_m10, spr_portrait_blood_m11, spr_portrait_blood_m12,
    spr_portrait_blood_f1, spr_portrait_blood_f2, spr_portrait_blood_f3,
    spr_portrait_blood_f4, spr_portrait_blood_f5, spr_portrait_blood_f6,
    spr_portrait_blood_f7, spr_portrait_blood_f8, spr_portrait_blood_f9,
    spr_portrait_blood_f10, spr_portrait_blood_f11, spr_portrait_blood_f12,
    spr_portrait_blood_f13, spr_portrait_shadow_m1, spr_portrait_shadow_m2,
    spr_portrait_shadow_m3, spr_portrait_shadow_m4, spr_portrait_shadow_m5,
    spr_portrait_shadow_m6, spr_portrait_shadow_m7, spr_portrait_shadow_m8,
    spr_portrait_shadow_m9, spr_portrait_shadow_f1, spr_portrait_shadow_f2,
    spr_portrait_shadow_f3, spr_portrait_shadow_f4, spr_portrait_shadow_f5,
    spr_portrait_shadow_f6, spr_portrait_shadow_f7, spr_portrait_shadow_plaguehunter,
];

// Load persisted meta-progression only if a slot was selected before this room was entered.
// For new games the slot is set but load_game() is skipped - defaults from above apply.
if (global.save_slot >= 0) load_game();


// -----------------------------------------------------------------------------
// 14. DUNGEON SELECTION
// Persisted per-dungeon ascendance unlock level and clear count.
// -----------------------------------------------------------------------------
if (!variable_global_exists("selected_dungeon")) {
    global.selected_dungeon = "ashen_vault";
}
if (!variable_global_exists("selected_ascendance")) {
    global.selected_ascendance = 0;
}
if (!variable_global_exists("dungeon_ascendance_unlocked")) {
    global.dungeon_ascendance_unlocked = {
        ashen_vault:     0,
        scorched_depths: 0,
        tundra_tomb:     0,
    };
}
if (!variable_global_exists("dungeon_clears")) {
    global.dungeon_clears = {
        ashen_vault:     0,
        scorched_depths: 0,
        tundra_tomb:     0,
    };
}
if (!variable_global_exists("dungeon_clears_total")) global.dungeon_clears_total = 0;

dungeon_select_open   = false;
dungeon_select_cursor = 0;   // 0 = ashen_vault, 1 = scorched_depths, 2 = tundra_tomb
dungeon_select_asc    = 0;

// CURSED REBIRTH ritual (07-31): -1 = idle; >=0 counts frames of the dark
// ceremony overlay (gc Step advances it, hub Draw renders it, reveal pops at
// the end). Item/prev carried through to the forge-result popup.
cursed_ritual_t    = -1;
cursed_ritual_item = undefined;
cursed_ritual_prev = undefined;
// Forge-result reveal popup (07-31, shared by every craft) - closed state.
if (!variable_global_exists("forge_result")) global.forge_result = undefined;

// STATS-PAGE GUIDED TOUR (07-31, M: first-open walkthrough with Next/Skip).
// -1 = inactive; 0..5 = current step. Armed the first time the I-menu opens on
// the Stats tab; persistence rides tutorial_seen ("stats_tour"), so Settings'
// "Reset tutorial" re-arms it.
stats_tour_step = -1;

// NPC STATION GUIDED TOURS (M-locked 08-15): the stats-tour treatment for every
// camp keeper's screen. -1 = inactive; 0..N-1 = current step of npc_tour_npc's
// list (npc_tour_steps in scr_ui). Armed once per NPC on first open;
// persistence rides tutorial_seen ("tour_<npc>"), so "Reset tutorial" re-arms.
npc_tour_step = -1;
npc_tour_npc  = "";

// STEAM ACHIEVEMENTS (08-04): lifetime counter struct + periodic sync clock.
// No-ops entirely until GMEXT-Steamworks is installed (see scr_stats).
ach_counters_init();
ach_sync_clock = 0;

# Sound sources (T19.1 placeholder assets)

All files: 16-bit PCM mono WAV, 22050 Hz, 0.3–6 s. Downloaded recordings were
converted (mono mixdown, resample, trim/tile, fades) with numpy/soundfile;
everything else comes from the deterministic `generate_placeholders.py` in this
directory (seeded per file name — re-running reproduces byte-identical output).

## Downloaded (5)

| file | origin | license |
|---|---|---|
| phenomenon_weeping_sky.wav | "Rain (loopable)" by Alexander Ehlers, https://opengameart.org/content/rain-loopable (loop 1, first 6 s) | CC0 |
| phenomenon_landslide.wav | "75 CC0 breaking / falling / hit sfx" by rubberduck, https://opengameart.org/content/75-cc0-breaking-falling-hit-sfx (bfh1_rock_falling_01–09 overlap-mixed) | CC0 |
| phenomenon_coming_herd.wav | "Horse gallop on different surfaces" (ground track), https://opengameart.org/content/horse-gallop-on-different-surfaces — derived from "Single Horse Galopp" by D4XX, https://freesound.org/people/D4XX/sounds/564628/ (CC0) | pack CC-BY 4.0; underlying sample CC0 |
| phenomenon_thing_in_dark.wav | "CC0 Deep Monster Roar" by trazzz123, https://opengameart.org/content/cc0-deep-monster-roar (first 5.8 s) | CC0 |
| phenomenon_birds_silent.wav | "Bird chirping sounds" by syncopika, https://opengameart.org/content/bird-chirping-sounds (2.2 s of song, then abrupt cut to near-silence) | CC0 |

## Synthesized (48) — all "synthesized (generate_placeholders.py)"

phenomenon_still_air, phenomenon_long_dark, phenomenon_ground_remembers,
phenomenon_standing_stones, phenomenon_the_swallowing, phenomenon_the_quickening,
phenomenon_the_blight, phenomenon_wrongness_blood, phenomenon_shared_dream,
phenomenon_day_twice;
consequence_unease, consequence_flood, consequence_dam_flood, consequence_famine,
consequence_migration, consequence_quake, consequence_cursed_place,
consequence_soil_exhaustion, consequence_scapegoat_schism, consequence_medicine,
consequence_predator_follows, consequence_hunt_heroism, consequence_rite_crystallizes,
consequence_schism_seed, consequence_mass_conversion, consequence_heresy_schism;
event_born, event_died, event_stage_changed, event_knowledge_lost,
event_belief_formed, event_main_settlement_changed, event_world_ended,
event_settlement_founded, event_discovery, event_fracture, event_war,
event_schism (the last two added at T22.3);
ambience_season_0, ambience_season_1, ambience_season_2, ambience_season_3,
ambience_wrongness, ambience_ward;
ui_click, ui_back, ui_save, ui_refused.

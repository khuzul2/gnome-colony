# 🎮 PLAYTEST GATE G — "Does the terrain read richer, and still Ravenna?"

**The Gaea terrain track (Phases G0–G4) is code-complete and headless-green** — full suite
passing, lint clean, `phase-G0/G1/G2/G3-complete` tagged and `phase-G4-complete` tagged. The
automated half is done. This gate is the one thing tests can't judge: **does the ground now
look like believable, detailed country — and does it still read as Ravenna mosaic?** That's
your call on a real GPU build.

## What changed (G0–G4)

Terrain **generation** moved to the vendored **Gaea** framework (pure GDScript, deterministic,
Rng-independent). The **Ravenna mosaic render is unchanged** — Gaea supplies *geometry only*;
the low-res palette-LUT + tessera/grout post-process still paints everything.

1. **Detailed sub-basin relief (G1–G2).** `WorldView` now bakes a Gaea-detailed height field
   (`idw_base + attenuated FBM noise`) instead of the flat inverse-distance field. Between
   basins the ground rolls with real sub-basin relief; **basin centers stay anchored** to their
   authored elevation (so picking/nav/settlements still land where they should).
2. **Biome-varied palette bands (G3.1).** Each region's biome tints its elevation bands —
   **forest** skews the uplands greener, **ridge** ochre/gold, **marsh** wet-verdigris, meadow
   is the neutral base — every colour still one of the 16 Ravenna tesserae.
3. **Coherent water (G3.2).** Low ground below the sea-level clamp reads as the flat lapis
   water plane, so valleys between basins form water, not noisy mud.
4. **Proven reproducible, cheap, and diverse (G4).** Same seed ⇒ byte-identical terrain; the
   Gaea generator draws **zero** from the sim's Rng (the sim is unperturbed); the one-time
   re-bake runs ~32 ms (well under budget); every distinct seed is a distinct map, and each new
   game with a blank seed rolls a fresh one.

## How to look

`git pull` (or use your local tree), launch, **New Game**, and look at the ground:

- **Believable rolling country?** Do valleys, ridges, and rises read as real terrain between
  the basins — or still flat/blocky? Try a few seeds (each is a different map now).
- **Detail catches the gold key light?** The oblique gold key light should rake across the new
  relief; slopes should shade dimensionally (R5's slope-shade over the finer geometry).
- **Still Ravenna?** Does it still read as **mosaic tesserae** (palette + grout), not a smooth
  modern heightmap? The detail must live *inside* the mosaic look, not fight it.
- **Water read?** Do low areas form coherent **lapis water**, or noisy speckle at the shoreline?
- **Biomes read?** Do forest/ridge/marsh basins feel tinted differently (greener / ochre / wet)
  while staying on-palette?
- **Picking still true?** Click-cast on a basin — does the act land where you clicked? Do
  settlements/puppets sit **on** the new ground (not floating or sunk)?
- **No artifacts?** Watch for shimmer, z-fighting, flat dead spots, or a framerate dip at the
  play zooms.

## Known, deliberate scoping (decide if it matters)

- **Every Gaea constant is tunable in one edit** — detail octaves/frequency/amplitude
  (`DETAIL_OCTAVES 4`, `DETAIL_FREQ_PER_KM 0.08`, `DETAIL_AMPLITUDE_T 0.35`), bake grid
  (`GRID 64`), anchor radius (`ANCHOR_RADIUS_KM 3.0`), and the biome band tables all live in
  `presentation/terrain/terrain_field.gd` + `presentation/world_view.gd`. Flag anything that
  reads too bumpy/too smooth/too tinted/too flat and it's a one-line `[gaea §…]` change.
- **Biome tinting is per-nearest-basin (Voronoi)** — hard biome boundaries at the basin
  midlines, softened by the mosaic quantization. If you'd rather biomes blend, that's a small
  change.
- **Nav routes the smooth basin shape, not the fine detail** — the navmesh bakes clean over the
  Gaea geometry (G2.3's ledge-span filter); the detail is a visual skin. Movement (a library
  today) is unaffected.

## To proceed

Record **GO** (+ any `[gaea §…]` tuning asks — all constants are tunable) and the Gaea terrain
track is done. A **NO-GO** with specifics (too bumpy, water speckles, biomes too strong, a flat
spot at seed X, framerate) is just as useful — I'll turn each into a `[gaea §…]` tuning task.

*(Note: `phase-G4-complete` is tagged — the automated suite is green — but the Gaea track isn't
"done" until this playtest confirms the terrain reads richer AND still Ravenna.)*

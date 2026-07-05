# Gnome Colony — Gaea Procedural Terrain Spec (presentation source of truth)

*Authored 2026-07-06. **READ-ONLY once authored**, like `redesign-ravenna.md`. This is the single
source of every **new** number the Gaea terrain effort introduces. It is **presentation-only** — it
adds terrain-generation/render constants and reads the sim's `RegionGraph` **read-only**; it never
touches `sim/` and introduces **no** algo/§17 numbers. Every value here is a **presentation/structural
number** — same status as `WorldView.GRID`/`EXTENT_KM`, the T13.1 world-gen scaffolding, and every
`[rav §R-art]` render constant — and all are **STARTING values, tunable at 🎮 Playtest Gate G**. Cite
as `[gaea §X]`. If it is silent, write `STUCK.md` — do not invent. The plan that consumes this doc is
`docs/terrain-gaea-plan.md`.*

**Why this exists.** Terrain *generation* moves to the **Gaea** framework (pure-GDScript, vendored),
so the ground reads as detailed, believable rolling country instead of a coarse inverse-distance-
weighted (IDW) field. Two decisions frame the whole effort (user-confirmed 2026-07-05): the **Ravenna
mosaic render is kept** — Gaea supplies **geometry only**, and the existing low-res palette-LUT +
tessera/grout post-process still paints it; and **Terrain3D is dropped** — a compiled GDExtension is a
poor fit for this 100%-headless, offline, Godot-4.7 project, and a 28 km world seen through a 512×288
mosaic viewport gains little from its clipmap LOD. The change is **surgical**: only `WorldView`'s
large-scale height source is replaced; `height_at`/`walkable_faces`/`terrain_color`/`sync`+`version`
and all of R5's relief work are preserved.

---

## §gaea-invariants — the rules every terrain task obeys

1. **Presentation-only.** `sim/` stays untouched; `RegionGraph` remains the sim's world authority.
   Gaea, its addon, and all terrain code live under `presentation/` (and `addons/gaea/`). The purity
   test (`test_world_view`/`test_gnome_puppet` recursion over `res://sim`) still governs.
2. **Basins stay authoritative for the sim's world shape.** The Gaea field is **anchored** (see
   `§gaea-anchor`) so a basin center still reads that region's `RegionGraph` elevation and the hi/lo
   ordering across basins is monotonic. Gaea adds detail **between and around** basins; it never
   overrides which basin is highest, or picking would land on the wrong place.
3. **Terrain randomness NEVER touches the `Rng` singleton** (see `§gaea-det`). Terrain is a skin; it
   must draw **zero** values from the global `Rng` stream, or it would desync the sim and break every
   byte-identical sim-hash test.
4. **The `WorldView` contract is preserved, not rewritten.** `height_at(Vector2) → float`,
   `walkable_faces`, `terrain_color(t)`, and `sync()` + `version` re-bake keep their signatures and
   semantics. Only the raw large-scale height field changes.
5. **Composes with the Gate-A legibility work (R5).** `RELIEF_KM` amplitude, `SEA_LEVEL_T` water
   clamp, `SLOPE_SHADE`, hard palette-band terraces, oblique camera, and pixel-snap all remain in
   force and apply **on top of** the richer Gaea field. Terrain tasks change `_raw_height`, not
   `_relief_t`/`_relief_y`/`terrain_color`.
6. **Numbers are presentation/structural, not §17.** No value here modulates a gameplay term; none can
   conflict with `evolution-algorithm.md`.

---

## §gaea-gen — the generation contract & constants

`TerrainField.generate(graph, seed)` produces a queryable height field the `WorldView` bake samples in
place of the raw IDW loop. The **large-scale shape** is the existing IDW-over-basins field (preserves
basin authority + monotonic ordering); **Gaea multi-octave fractal noise** adds sub-basin **detail**
on top, blended per `§gaea-anchor`.

**Constants** (STARTING values; tunable at Gate G):

| const | value | meaning |
|---|---|---|
| `DETAIL_OCTAVES` | `4` | fractal octaves of Gaea detail noise |
| `DETAIL_FREQ_PER_KM` | `0.08` | base spatial frequency of the detail noise across the `2·EXTENT_KM` (28 km) plane |
| `DETAIL_AMPLITUDE_T` | `0.35` | detail height as a fraction of the normalized relief span (added to the IDW base, in normalized-`t` space, before R5's `RELIEF_KM` amplification) |
| `GRID` | `64` | `WorldView` bake tessellation (supersedes the old `24`); fine enough to show the detail. **Must keep `NavWorld` `CELL_SIZE`/`CELL_HEIGHT` dividing the resulting face size** or the voxelizer silently rejects polygons |
| `BAKE_BUDGET_MS` | `50` | one-time re-bake budget on a `version` bump (seed/reshape) — **not** a per-tick cost, so it does not touch `test_scale`'s per-tick budget |

**Biome band bias** (Gaea layer richness; `§gaea-gen`, on-palette). The region `biome` (`RegionGraph`:
`meadow`/`forest`/`ridge`/`marsh`) biases `WorldView.terrain_color`'s band selection — **composed
with, not replacing,** the elevation banding — so the same elevation reads greener under `forest`,
ochre/gold under `ridge`, etc. The output **must remain one of the 16 `Palette.COLORS`** (mosaic
discipline; the `test_render_pipeline` >95%-on-palette guarantee holds). Water bodies: Gaea detail that
dips below R5's `SEA_LEVEL_T` reads as the flat lapis water plane (R5.1's clamp), so low ground between
basins forms coherent water rather than noisy mud.

---

## §gaea-anchor — the basin-anchoring rule

The field composes a **base** and a **detail** term:

```
raw_height(p) = idw_base(p)  +  attenuation(p) · gaea_detail(p)
```

- `idw_base(p)` — the existing inverse-distance-weighted basin elevation (unchanged authority).
- `gaea_detail(p)` — the Gaea fractal noise, scaled to `DETAIL_AMPLITUDE_T` of the relief span.
- `attenuation(p)` — `0` at a basin center, ramping to `1` beyond `ANCHOR_RADIUS_KM` of the **nearest**
  basin center (smooth ramp), so open ground gets full detail while basin centers keep their authored
  elevation.

**Constants** (STARTING values; tunable at Gate G):

| const | value | meaning |
|---|---|---|
| `ANCHOR_RADIUS_KM` | `3.0` | radius around a basin center within which detail is attenuated toward 0 |
| `ANCHOR_TOL` | `0.05` | max normalized-height error allowed at a basin center (the anchoring test's bound) — a center must read its region elevation within this |

**Guarantee.** For every region, `|normalized_height(center) − normalized_region_elevation| ≤
ANCHOR_TOL`, and for any two regions the higher region's sampled center height is `≥` the lower's
(monotonic ordering — picking correctness). Between basins, a sampled height must differ from the
pure-IDW baseline by a detail-present margin (relief is real, not flat).

---

## §gaea-det — determinism & seed derivation

**The crux invariant.** Terrain is deterministic from the world seed and **independent of the sim's
`Rng` stream**:

- Gaea's generator is seeded from **`WorldConfig.seed`** (the same seed the sim's `RegionGraph` uses),
  via Gaea's own `seed` field — **never** the `Rng` singleton, and never `Time`/`Math.randomize`.
- Therefore identical `seed` + config ⇒ **identical** terrain, and a full terrain generation draws
  **zero** values from `Rng` — `Rng.get_state()` is byte-equal before vs after `generate(...)`. This
  is what keeps every byte-identical sim-hash test (`test_determinism`, the T15.4 render-density
  invariance) passing now that the render layer owns a noise generator.
- The seed is **persisted** in `WorldView` so a phenomenon `reshape` (which bumps `version`) re-bakes
  reproducibly from the same seed.

**Seed source rule:** if a task needs a per-feature sub-seed (e.g. detail vs biome layers), derive it
**deterministically from `WorldConfig.seed`** (a fixed offset or hash), never from `Rng` or wall-clock.

**Map diversity (the flip side).** Because terrain is a strong function of the seed, **distinct seeds
⇒ distinct maps** — both the `RegionGraph` basin layout and the Gaea detail differ. Every new game with
a **blank** seed gets a fresh random seed (the wizard rolls one; `RandomNumberGenerator` is randomized
at boot), so every new game is a different map. A **typed** seed is intentionally reproducible
(shareable seeds). This is pinned as a tested invariant by plan task G4.4.

---

## Appendix — constant summary (all tunable at Gate G)

| const | value | § |
|---|---|---|
| `DETAIL_OCTAVES` | 4 | gen |
| `DETAIL_FREQ_PER_KM` | 0.08 | gen |
| `DETAIL_AMPLITUDE_T` | 0.35 | gen |
| `GRID` (supersedes `WorldView` 24) | 64 | gen |
| `BAKE_BUDGET_MS` | 50 | gen |
| `ANCHOR_RADIUS_KM` | 3.0 | anchor |
| `ANCHOR_TOL` | 0.05 | anchor |
| seed source | `WorldConfig.seed` → Gaea gen seed, never `Rng` | det |
| biome band bias | forest→greener, ridge→ochre/gold (on-palette) | gen |

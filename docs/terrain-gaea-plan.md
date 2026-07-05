# Redesign Plan — Gaea Procedural Terrain (richer geometry under the Ravenna mosaic)

*Loop-ready, test-gated. Companion to `docs/implementation-plan.md` (§0 there still applies verbatim),
`docs/redesign-plan-ravenna.md` + `docs/redesign-plan-legibility.md` (the R-series this follows),
`PROGRESS.md` (the live ledger), and the new authoritative spec `docs/terrain-gaea.md` (`[gaea §X]`,
authored by task **G0.1**). Authored 2026-07-05 from the user request "move terrain generation to a
procedural terrain framework." Cite the spec as `[gaea §X]`; if it is silent, write `STUCK.md` — do
not invent.*

---

## Decision record (why this plan is Gaea-only, mosaic-preserving)

The request named **Terrain3D + Gaea**. After mapping the codebase against the project's hard
invariants, two decisions were taken (user-confirmed 2026-07-05):

1. **Keep the Ravenna mosaic; the terrain framework supplies geometry only.** The mosaic render
   (`docs/redesign-ravenna.md`, read-only — low-res `SubViewport` + palette-LUT + tessera/grout
   post-process) is a **frozen source-of-truth** that just passed Gate-A remediation (R5–R8). A new
   terrain system changes the **geometry under** the shader, never the shader. Lowest art risk; no
   new render spec, no re-litigating the palette.
2. **Gaea only; Terrain3D dropped.** Terrain3D is a compiled **C++ GDExtension**. This project is
   **100 % headless-test-gated** (`godot --headless`) and its build environment has **no network
   access** (GitHub blocked — see CLAUDE.md). Vendoring per-platform Terrain3D binaries for the
   bleeding-edge **Godot 4.7**, and proving its clipmap/height-query path works **headless** so the
   `height_at`/nav/picking tests can run, is a large risk for a **28 km abstract-basin world rendered
   through a 512×288 mosaic viewport** — a regime where Terrain3D's clipmap LOD buys little. **Gaea is
   pure GDScript**: no binary, no headless-init risk, fully unit-testable. It delivers the entire
   *visible* win (detailed, believable terrain) at a fraction of the risk. Terrain3D can be revisited
   later behind its own feasibility spike if huge-terrain LOD is ever needed.

**What "move terrain generation to Gaea" therefore means here:** replace `WorldView`'s internal
large-scale height source (today: inverse-distance-weighted region elevation) with a **Gaea-generated,
basin-anchored, deterministic heightfield**, keeping every downstream contract intact.

---

## Invariants (unchanged — these govern every G task)

- **Presentation-only.** `sim/` stays **untouched**; `RegionGraph` remains the sim's world authority.
  The purity test (`test_gnome_puppet`/`test_world_view` recursion over `res://sim`) still governs.
  Gaea, its addon, and all terrain code live under `presentation/` (and `addons/gaea/`).
- **Terrain randomness NEVER touches the `Rng` singleton.** The sim's determinism contract is "a full
  run reproduces from seed + config + acts + attention." Terrain is a **skin** and must draw **zero**
  values from the global `Rng` stream, or it would desync the sim and break every byte-identical
  sim-hash test (`test_determinism`, T15.4 render-density invariance). Gaea is seeded from
  **`WorldConfig.seed`** via its **own** noise generator. This is a hard, tested invariant (G1.1).
- **The `WorldView` contract is preserved, not rewritten.** `height_at(Vector2) → float`,
  `walkable_faces`, `terrain_color(t)`, `sync()` + `version` re-bake — all keep their signatures and
  semantics so `NavWorld`, `RunView` place-positions, click-picking, and puppet placement are
  unchanged. The swap is **surgical**: only the raw large-scale height field changes.
- **Basins stay authoritative for the sim's world shape.** The Gaea field is **anchored** so that at a
  basin center the height still reads that region's `RegionGraph` elevation (within tolerance) and the
  hi/lo ordering across basins is monotonic — otherwise picking would land on the wrong place and the
  nav/height tests would break. Gaea adds **detail between and around** basins; it never overrides
  which basin is highest.
- **Composes with the Gate-A legibility work (R5).** `RELIEF_KM` amplitude, `SEA_LEVEL_T` water
  clamp, `SLOPE_SHADE`, hard palette-band terraces, oblique camera, and pixel-snap all remain in
  force and apply **on top of** the richer Gaea field. G tasks change `_raw_height`, not `_relief_t`/
  `_relief_y`/`terrain_color`.
- **Numbers are presentation/structural, not `§17` gameplay numbers.** Every Gaea constant (octaves,
  frequency, detail amplitude, grid resolution, anchor radius) is a **render** number — same status as
  `WorldView.GRID`/`EXTENT_KM`, the T13.1 world-gen scaffolding, and every `[rav §R-art]` constant.
  They introduce **no** algo/§17 values and cannot conflict with the evolution-algorithm spec. All are
  **STARTING values tunable at 🎮 Playtest Gate G.**

**Dependency graph.** `R5–R8 committed → G0 → G1 → {🎮 Gate A2 GO} → G2 → G3 → G4 → 🎮 Gate G`.
**G0–G1 start when the legibility loop's code (R5–R8) is committed** — i.e. when that loop is *done*
(it halts at 🎮 Gate A2 awaiting a human). G0 (spec + Gaea vendoring) and G1 (the isolated
`TerrainField` module) touch only new files and depend on **neither** the R5 code nor the human gate,
so they run while Gate A2 is being judged. **G2 onward additionally requires 🎮 Gate A2 to record GO**
— WorldView integration composes with R5's validated camera/relief, so it must not build on a
legibility base the human hasn't signed off. Task IDs use the **G-prefix**. Godot **4.7**, GDScript,
GUT, `./lint.sh` — identical to every other phase.

---

## Phase G0 — Spec, vendoring & headless smoke — deps: R5–R8 committed (legibility loop done)

**Goal:** the numeric/structural source of truth exists, the Gaea addon is vendored and loads
**headless**, and the plugin is enabled — before a line of terrain code is written.
**Phase-Exit Test:** `test_terrain_spec_present.gd` (spec anchors present) **and**
`test_gaea_available.gd` (Gaea's generator class/resources instantiate headless) green; full suite
green; lint clean; tag `phase-G0-complete`.

- **G0.1 — Author `docs/terrain-gaea.md` (read-only spec).** deps: —. files: `docs/terrain-gaea.md`,
  `test/test_terrain_spec_present.gd`. do: write the single source of truth for this effort, anchors
  **`§gaea-gen`** (the generation contract + constants), **`§gaea-anchor`** (basin-anchoring rule),
  **`§gaea-det`** (determinism + seed derivation), **`§gaea-invariants`** (restate the invariants
  above). Fix STARTING values for every constant the plan references (see the **Constant summary**
  below); mark all "tunable at Gate G." State explicitly they are **presentation/structural numbers**,
  not §17. **Read-only once authored** (like `redesign-ravenna.md`). tests: assert the file exists and
  contains each anchor id (mirror `test_rav_spec_present.gd`). done: doc committed; no code touched.
- **G0.2 — Vendor the Gaea addon (human-in-the-loop) + headless load.** deps: G0.1. files:
  `addons/gaea/**`, `addons/gaea/SOURCES.md`, `project.godot` (enable plugin),
  `test/test_gaea_available.gd`. do: vendor Gaea **pinned to a specific release compatible with Godot
  4.7** into `addons/gaea/` (pure GDScript — **no binary**), record origin + version + license in
  `SOURCES.md` (precedent: GUT + `assets/sounds/SOURCES.md`), enable the plugin in `project.godot`,
  exclude `addons/gaea/` from `./lint.sh`/`.gdlintrc` exactly as `addons/gut/` is excluded. **NETWORK
  NOTE:** GitHub is blocked in the build environment — if the loop cannot fetch Gaea, write
  `STUCK.md` naming the exact files/version needed and **HALT** for a human to drop the vendored addon
  in (do not attempt to re-download). tests: `test_gaea_available.gd` instantiates Gaea's
  height/noise generator class and produces a value **headless** (proves it initializes with no
  display/GPU). done: plugin enabled; addon lints-excluded; smoke green.
- **Phase-Exit G0:** both G0 tests green; full suite unchanged; lint clean → tag `phase-G0-complete`.

---

## Phase G1 — Deterministic, basin-anchored heightfield (presentation, headless) — deps: G0

**Goal:** a pure presentation module produces a **detailed** height field that (a) reproduces exactly
from `WorldConfig.seed`, (b) draws **zero** values from the `Rng` singleton, and (c) is **anchored** so
basin centers keep their `RegionGraph` elevation. This is the whole risk surface, isolated and
headless-tested **before** it touches `WorldView`.
**Phase-Exit Test:** `test_terrain_field.gd` — same seed ⇒ identical field; `Rng` state is byte-equal
across a full generation (terrain is Rng-independent); basin-center heights match their region
elevations within tolerance and preserve hi/lo ordering; between-basin samples show real variance
(detail is present, not flat).

- **G1.1 — `TerrainField` generator seeded from config, `Rng`-independent.** deps: G0. files:
  `presentation/terrain/terrain_field.gd`. do: wrap Gaea's noise/heightmap generator in a module with
  `generate(graph: RegionGraph, seed: int)` returning a queryable field (`detail_at(Vector2) → float`
  in `[0,1]`-ish, and/or a sampled grid). Seed Gaea's generator from `seed` via the derivation fixed
  in `[gaea §gaea-det]` — **never** `Rng`. Octaves/frequency/amplitude per `[gaea §gaea-gen]`. tests:
  two `generate(...)` with the same seed produce identical samples; different seeds differ;
  **`Rng.get_state()` is identical before vs after** a generation (the Rng-independence tripwire, the
  crux of the determinism invariant). done: module pure of any `Rng`/`Time` call.
- **G1.2 — Basin-anchored composition.** deps: G1.1. files: `presentation/terrain/terrain_field.gd`.
  do: compose the **base** large-scale height (the existing IDW-over-basins field — preserves sim
  authority + monotonic basin ordering) with the **Gaea detail** noise, attenuating detail within
  `[gaea §gaea-anchor]` `ANCHOR_RADIUS_KM` of each basin center so `height_at(basin_center) ≈ region
  elevation` still holds while open ground between basins gets full relief. do NOT introduce a second
  authority — basins win at their centers, Gaea fills the gaps. tests: basin-center sampled height is
  within `ANCHOR_TOL` of the region's normalized elevation; the highest/lowest basins keep their order
  (picking correctness); a mid-span between-basin sample differs from a pure-IDW baseline by ≥ a
  detail-present threshold (relief is real). done: anchoring documented in-file with the `[gaea §…]`
  cites.
- **Phase-Exit G1:** `test_terrain_field.gd` green (determinism + Rng-independence + anchoring +
  detail-present); suite green; lint clean → tag `phase-G1-complete`.

---

## Phase G2 — `WorldView` integration (swap the source, keep the contract) — deps: G1, R5, 🎮 Gate A2 (GO)

**Goal:** `WorldView` renders the Gaea field with **every existing test green** — `height_at`,
`walkable_faces`, terrace bands, relief normalization, `version` re-bake, nav routing, and picking all
behave as before, now over richer geometry. This is a **surgical swap of `_raw_height`**, nothing else.
**Phase-Exit Test:** the pre-existing `test_world_view.gd`, `test_dimensional_terrain.gd`,
`test_nav_world.gd`, `test_movement.gd`, `test_phase13_exit.gd`, and `test_run_view.gd` all pass
unchanged in intent, plus the new detail assertions below.

- **G2.1 — Route `WorldView._raw_height` through `TerrainField`.** deps: G1, R5, 🎮 Gate A2 (GO). files:
  `presentation/world_view.gd`. do: build a `TerrainField` in `sync()` (add a `seed` — sourced from
  `WorldConfig.seed`, persisted so reshape re-bakes reproduce), and have `_raw_height(point)` sample
  the anchored field instead of the raw IDW loop. **Keep** `_relief_t`/`_relief_y`/`height_at`/
  `terrain_color`/`sync`+`version` exactly as R5 left them — relief amplitude, sea-level clamp, and
  terraces all still apply on top. tests: `test_world_view` + `test_dimensional_terrain` +
  `test_puppet_tint` regressions green; add a leg asserting the baked mesh now has real sub-basin
  height variance (Gaea detail present) while `height_at(basin_center)` still agrees with the mesh.
  done: `sync` signature change (if any) noted in `PROGRESS.md` public-API notes; `RunView` wiring
  updated to pass the seed.
- **G2.2 — Finer mesh grid + nav/pick consistency.** deps: G2.1. files: `presentation/world_view.gd`,
  `presentation/nav_world.gd` (only if cell math needs it). do: raise the bake `GRID` per
  `[gaea §gaea-gen]` so the detail is actually tessellated (today 24×24 is too coarse to show noise);
  keep `walkable_faces` in sync and ensure `NavWorld`'s `CELL_SIZE`/`CELL_HEIGHT` still divide the new
  face sizes (the voxelizer silently rejects mismatched cells — see `nav_world.gd` comments). tests:
  `test_nav_world` + `test_movement` + `test_phase13_exit` green (a route is still found across the
  richer mesh; buried-road refusal unchanged); `walkable_faces.size()` scales with the finer grid.
  done: grid/cell relationship documented in-file.
- **Phase-Exit G2:** every terrain/nav/picking test green over the Gaea geometry; `height_at` agrees
  with the mesh; suite green; lint clean → tag `phase-G2-complete`.

---

## Phase G3 — Biome & water detail under the mosaic (richness, still on-palette) — deps: G2

**Goal:** exploit Gaea's layer stack for **biome-varied** and **water** detail that reads through the
mosaic while staying **100 % on the 16-colour palette** (the `test_render_pipeline` guarantee).
Optional-richness phase: it makes the world look authored, not just bumpy.
**Phase-Exit Test:** `test_terrain_biomes.gd` — biome influence shifts the palette band deterministically
per region; every sampled terrain color is one of the 16 `Palette.COLORS`; sub-`SEA_LEVEL_T` regions
render the flat lapis water plane; `test_render_pipeline` on-palette ratio stays > 95 %.

- **G3.1 — Biome-varied palette bands.** deps: G2. files: `presentation/world_view.gd`,
  `presentation/terrain/terrain_field.gd`. do: let the region `biome` (`RegionGraph`: meadow/forest/
  ridge/marsh) bias `terrain_color`'s band selection per `[gaea §gaea-gen]` (e.g. forest skews greener,
  ridge skews ochre/gold) — composed with, not replacing, the elevation banding; output must remain a
  `Palette.COLORS` entry (mosaic discipline). tests: same region+seed ⇒ same band; forest vs ridge at
  equal elevation pick different (but on-palette) colors; all sampled colors ∈ palette. done: biome
  bias documented as a presentation number.
- **G3.2 — Water bodies compose with the R5 sea clamp.** deps: G3.1. files:
  `presentation/world_view.gd`. do: ensure Gaea detail that dips below `SEA_LEVEL_T` reads as the flat
  lapis water plane (R5.1's clamp), so low ground between basins forms coherent water, not noisy mud.
  tests: a below-sea sample clamps to the water `y` and lapis color; `test_render_pipeline` +
  `test_dimensional_terrain` regressions green. done: —.
- **Phase-Exit G3:** `test_terrain_biomes.gd` green; render-pipeline on-palette ratio holds; suite
  green; lint clean → tag `phase-G3-complete`.

---

## Phase G4 — Determinism, perf, end-to-end & the playtest gate — deps: G3

**Goal:** prove the migration is **reproducible**, **cheap**, and **whole**, then hand the visual
judgment to a human.
**Phase-Exit Test:** `test_terrain_gaea_end_to_end.gd` green + the determinism/perf legs below + suite
green; then 🎮 **Gate G** halts for human GO.

- **G4.1 — Determinism envelope.** deps: G3. files: `test/test_terrain_determinism.gd` (or extend
  `test_determinism.gd`). do: assert (a) identical `seed`+config ⇒ identical baked terrain (hash the
  sampled height+color grid); (b) the **sim save-envelope hash is byte-identical with vs without the
  Gaea path** for a fixed scripted run — terrain never perturbs the sim (re-proves the T15.4 render-
  density invariance now that render owns a noise generator). tests: as described. done: any tolerance
  documented.
- **G4.4 — Map-diversity guarantee (every new game a different map).** deps: G4.1. files:
  `test/test_map_diversity.gd`. do: pin the user requirement as a **tested invariant**, not an implicit
  engine default. Assert the map is an injective-enough function of the seed across **both** halves:
  over a sample of distinct seeds, (a) the `RegionGraph` basin layouts differ (centers/elevations/
  biomes not all equal — the sim's world shape), and (b) the `TerrainField`/baked-terrain samples
  differ (the Gaea detail) — so no two distinct seeds collide on the same map. Then guard the
  **blank-seed path**: assert the wizard's blank-seed roll is **entropy-derived** (a blank
  `WorldConfig.seed` resolves to a random value, NOT a fixed constant) so successive new games get
  distinct seeds. **Boot-randomization note (verified on Godot 4.7):** `RandomNumberGenerator.new()`
  auto-randomizes its seed, so `Rng` is random at boot and blank seeds differ per launch **today** —
  this test makes that a guarantee a future boot-seed change or engine default cannot silently break.
  Do NOT relax T15.2's "blank seed rolled through `Rng`, reproducible under a seeded `Rng` in tests"
  contract — the diversity test seeds distinct values and compares maps; it does not require wall-clock
  entropy inside the sim (the seed is a recorded input, per §0.2). tests: as described. done: a
  one-line note that typed (non-blank) seeds are intentionally reproducible (shareable seeds).
- **G4.2 — Bake perf tripwire.** deps: G3. files: `test/test_terrain_perf.gd`. do: measure the
  **one-time re-bake** cost on a `version` bump at the plan's `GRID`; assert it under
  `[gaea §gaea-gen]` `BAKE_BUDGET_MS`. Note that terrain bakes only on seed/reshape, **not per tick**,
  so it does not touch `test_scale`'s per-tick budget; use the same "raw number printed + hardware-
  calibrated tripwire" pattern as `test_scale.gd` (the container runs ~2× the reference desktop —
  documented ruling, Phase-Exit 11). tests: bake time printed + bounded. done: calibration note in the
  test.
- **G4.3 — End-to-end integration.** deps: G4.1, G4.2. files:
  `test/integration/test_terrain_gaea_end_to_end.gd`. do: `WorldBootstrap` → `RegionGraph` →
  `TerrainField` → `WorldView` bake → `NavWorld` route → click-pick → cast round-trips; a phenomenon
  `reshape` bumps `version` and re-bakes deterministically; puppets place on the new ground. tests: the
  full chain in one scene (mirror `test_phase13_exit`/`test_render_pipeline` composition). done: —.
- **🎮 PLAYTEST GATE G — "Does the terrain read richer, and still Ravenna?"** deps: G4.1–G4.4. do:
  write `AWAIT_PLAYTEST.md` (evaluate: terrain reads as believable rolling country with valleys/water,
  detail catches the gold key light, tesserae still mosaic, basins/settlements still land where picking
  says, no shimmer/flat spots, framerate acceptable), commit, and **HALT**. A human records GO here (+
  any `[gaea §…]` tuning asks — all constants are tunable) before this effort is considered done.
- **Phase-Exit G4:** end-to-end + determinism + perf + map-diversity green; suite green; lint clean →
  tag `phase-G4-complete`; `AWAIT_PLAYTEST.md` written; **HALT**.

---

## Constant summary (G0.1 fixes these in `docs/terrain-gaea.md`; STARTING values, tunable at Gate G)

*All presentation/structural — same status as `WorldView.GRID`/`EXTENT_KM` and `[rav §R-art]`. Values
below are the plan's **proposal**; G0.1 ratifies them in the spec, or writes `STUCK.md` if a value
cannot be reasonably fixed.*

| const | proposed start | anchor | note |
|---|---|---|---|
| `DETAIL_OCTAVES` | 4 | `§gaea-gen` | fractal octaves of Gaea detail noise |
| `DETAIL_FREQ_PER_KM` | ~0.08 | `§gaea-gen` | base spatial frequency of detail across the 28 km plane |
| `DETAIL_AMPLITUDE_T` | 0.35 | `§gaea-gen` | detail height as a fraction of the normalized relief span |
| `ANCHOR_RADIUS_KM` | 3.0 | `§gaea-anchor` | radius around a basin center where detail is attenuated to 0 |
| `ANCHOR_TOL` | 0.05 | `§gaea-anchor` | max normalized-height error allowed at a basin center |
| `GRID` (supersede `WorldView` 24) | 64 | `§gaea-gen` | bake tessellation — fine enough to show detail; must keep nav cells dividing |
| `BAKE_BUDGET_MS` | 50 | `§gaea-gen` | one-time re-bake budget on a `version` bump (not per-tick) |
| seed derivation | `WorldConfig.seed` → Gaea gen seed | `§gaea-det` | never the `Rng` singleton |
| biome band bias | forest→greener, ridge→ochre/gold (on-palette) | `§gaea-gen` | composed with elevation banding |

---

## Notes for the loop

- **Start G0 when R5–R8 are committed (the legibility loop is done); hold G2 for 🎮 Gate A2 GO.**
  G0–G1 (spec, Gaea vendoring, isolated `TerrainField`) touch only new files and are safe to author
  while the human judges Gate A2 — if Gate A2 returns NO-GO and R5–R8 are reworked, G0–G1 are
  unaffected (they don't depend on R5). G2 composes with R5's validated camera/relief (oblique camera,
  `RELIEF_KM`, `SEA_LEVEL_T`, slope-shade, 512×288), so it waits for GO.
- **If Gaea cannot be vendored offline (G0.2), that is a `STUCK.md` + HALT, not a workaround.** A human
  drops the pinned addon in; the loop never re-downloads (network blocked, CLAUDE.md).
- **The one seam that carries all the risk is `TerrainField` (G1).** It is isolated and headless-tested
  before it touches `WorldView`, so a Gaea surprise surfaces in G1, not in a broken integration.
- **`sim/` is never edited in this plan.** If any G task feels like it needs to, that is a design
  error — write `STUCK.md`.

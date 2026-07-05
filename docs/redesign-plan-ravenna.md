# Redesign Plan — "Ravenna": late-antique people, mosaic render, living settlements

*Loop-ready, test-gated. Companion to `docs/implementation-plan.md` (same operating
contract, §0 there still applies), `PROGRESS.md` (phases 0–23, the live task ledger), and
`docs/evolution-algorithm.md` (still the numeric source of truth). This redesign **adds** a new
authoritative spec, `docs/redesign-ravenna.md` (authored in Phase R0), and **extends** algo
§14/§17 — it never silently invents a number.*

**Rebased on `main` @ Phase 23 (2026-07-05).** The earlier draft of this plan was written against
a stale checkout where `main.tscn` was empty and the assembly was "deliberately thin." That is no
longer true — see the review below.

---

## Review: this plan vs. `main` as actually built

I re-read `main` (167 commits, phases 0–23). The game is now **fully assembled and playable**:
`presentation/shell/game_shell.gd` boots `main.tscn` → MainMenu → `GameRun` → **`RunView`**
(`presentation/shell/run_view.gd`), which lights the world (a `DirectionalLight3D` sun + ambient
`WorldEnvironment`), skins the region graph (`WorldView`), pools puppets, drives a 3-zoom
`CameraRig`, walks puppets along a baked `NavWorld`, feeds the Eye's attention, and routes the
influence panel's arm→paint→cast gesture with keyboard/mouse input (Phase 23). There is a live
**multi-settlement civilization tier** at runtime (`GameRun.settlements`, `sid → Settlement`) with
war/schism (Phase 21) and a `frontier: N settlements · souls · seat` readout.

**What that changes for the three workstreams:**

| Workstream | Original assumption (stale) | Reality on `main` | Verdict |
|---|---|---|---|
| **A · people, not gnomes** | ~185 "gnome" refs, 41 files | **212 refs**; now also all of `presentation/shell/*` (`run_view.gd`, `game_run.gd`), `Colony.gnomes`, `GnomePuppet` picking. | **Still needed, larger.** Rename map expanded (Appendix B). |
| **B · mosaic render** | Build a render scene from scratch (`main.tscn` empty) | **Scene exists** (`RunView`), lit for plain daylight (`SKY_COLOR` blue, `AMBIENT_COLOR` grey, a sun). No `SubViewport`, no shader, no palette — confirmed absent. | **Re-scoped.** Don't build a scene — **insert a pixel `SubViewport` + mosaic shader into `RunView`** and **replace its lighting**. The old "assemble the game" task is dropped (done). |
| **C · living settlements** | Settlement is pure stats; add tiers/buildings; no live civ data | Still pure stats — **`Settlement` has no `structures`/`tier`** (confirmed). But there's now a live `GameRun.settlements` + `sid_places` map, and **`sim/systems/terrain.gd`** already derives lived tags (`farmland` when agriculture known, `built_up` when construction known, `crowded`, `drought`). | **Still needed; better anchored.** Build tiers/buildings on the aggregate; **integrate with `terrain.gd`** (don't duplicate); settlement visuals read the live `run.settlements`/`sid_places`. |

**Two new systems to respect (don't fight them):**
- **`sim/systems/terrain.gd`** — "living terrain": rewrites the home place's affordance tags from
  colony state each day. Farms/dwellings in workstream C should be *consistent* with `farmland`/
  `built_up`, and R4's visuals may read these tags as a coarse fallback where a settlement has no
  structure detail yet.
- **`sim/systems/natural_events.gd`** — opt-in (`WorldConfig.environmental_events`) scheduler that
  fires catalog phenomena unbidden. Consequence: development pressure in C can arise from *nature*,
  not only the player — the construction driver already handles this correctly because it reads
  world/need state, not "who cast it." Note it; change nothing.

**Corrections applied below:** removed the "assembly is thin / build main.tscn" task; moved the
pixel-stage insertion into `RunView` (with the picking-coordinate caveat it introduces); expanded
the rename map to cover `shell/` and `Colony.gnomes`; anchored C's visuals to `run.settlements`;
added `terrain.gd` integration to C. Task IDs stay **R-prefixed** (no collision with `T0..T23`).

---

## 0. How to consume this plan (delta over implementation-plan.md §0)

Everything in `docs/implementation-plan.md §0` holds: **one task per iteration**, **tests first**,
the **Definition of Done**, **phase gates**, **git discipline**, **STUCK.md** on ambiguity,
**numbers only from spec**. Two additions:

1. **New source of truth.** Phase R0 creates `docs/redesign-ravenna.md` (read-only thereafter) with
   every *new* number — palette hexes, shader constants, the rename map, and the settlement-
   development formulas (§R-set, extending algo §14). After R0, cite it as `[rav §X]`. If it's
   silent, write `STUCK.md` — do not invent.
2. **Invariants unchanged.** `sim/` stays plain data + logic with zero `Node`/scene/render refs.
   Workstream B is **presentation-only**. Workstream C is **sim logic**, never referencing
   presentation. Player influence on development stays **indirect** (design §1.3): no build button,
   no "designate a spot" — inputs remain seed, `WorldConfig`, influence acts, and attention.

Append the R-plan to `PROGRESS.md` (Phase R0.2) after its live phases 0–23, and work the first
unchecked task whose deps are checked.

---

## Phase R0 — The redesign spec (numeric source of truth)

**Goal:** one read-only doc holds every new constant.
**Phase-Exit Test:** `test_rav_spec_present.gd` asserts `docs/redesign-ravenna.md` exists and
contains anchors `§R-art §R-name §R-set §R-build §R-infl`; the palette table parses to exactly the
16 hex entries in Appendix A.

- **R0.1 — Author `docs/redesign-ravenna.md`.** files: `docs/redesign-ravenna.md`. do: transcribe
  Appendices A–D of this plan into numbered read-only sections. tests: `test_rav_spec_present.gd`.
- **R0.2 — Append the R-plan to `PROGRESS.md`.** files: `PROGRESS.md`. do: add all R-tasks as
  unchecked checkboxes with deps, after the live phase-23 block. tests: none (doc); DoD = committed.

---

## Phase R1 — People, not gnomes (rename + late-antique mood)

**Goal:** every "gnome" identifier becomes "person"/"people"; founding, names, and copy read
late-antique; the full existing suite (all phases 0–23) stays green.
**Phase-Exit Test:** `test_no_gnome_identifiers.gd` greps `sim/` + `presentation/` + `test/`
(excluding `addons/`) and asserts **zero** case-insensitive `gnome`; full suite green; lint clean.

- **R1.1 — Mechanical rename (suite-gated refactor, not TDD).** files: all of `sim/`,
  `presentation/` (**including `presentation/shell/*`**), `test/`. do: rename per `[rav §R-name]`
  (Appendix B): `GnomeData→PersonData`, `gnome_data.gd→person_data.gd`,
  `GnomePuppet→PersonPuppet`, `gnome_puppet.gd→person_puppet.gd`, signal `gnome_died→person_died`,
  serializer `gnome_to_dict/from_dict→person_to_dict/from_dict` and the `"gnomes"` colony key →
  `"people"`, **`Colony.gnomes→Colony.people`** (touches `run_view.gd`, `game_run.gd`), all local
  vars/comments/`.uid` filenames and every `class_name`/`preload`/`load`. **Exception to
  tests-first:** the gate is *the existing suite staying green* — a pure refactor moves no test
  red; if one goes red, the rename is wrong. tests: existing suite unchanged passes; add
  `test_no_gnome_identifiers.gd` and `test_person_serialize_roundtrip.gd`. done: `event_bus.gd`
  emits `person_died`; suite green; lint clean.
- **R1.2 — Late-antique name bank.** files: `sim/systems/naming.gd` (new, sim-pure),
  `sim/world_config.gd`, `sim/person_data.gd` (add `display_name`). do: a seeded generator from the
  banks in `[rav §R-name]`; assign at birth via `Rng`; names are data no system reads. tests: same
  seed → same names; distinct within a band; **determinism preserved** — sequence the name draw
  *after* every `Rng` draw the `test_determinism` envelope hashes, or exclude `display_name` from
  the hash, and note which in PROGRESS.
- **R1.3 — Late-antique vocabulary pass (presentation strings only).** files: `presentation/ui/*`,
  `presentation/shell/run_view.gd` (HUD copy), founding presets, place-name bank. do: title
  *"The Unseen Hand"*; keep stage labels (Infant…Elder); settlement names from the late-antique
  place bank `[rav §R-name]`; keep "the unseen will" theology copy (already fits). tests:
  `test_ui_copy.gd` — no "gnome" in any UI/HUD string; stage labels resolve.

*Rename notes:* no shipped saves exist beyond in-process round-trips, so changing serialized keys is
safe (tests serialize→deserialize in memory). The one real hazard is `test_determinism`'s golden
envelope — handle per R1.2.

---

## Phase R2 — Ravenna mosaic render (wrap the existing RunView; pixelate + palette + tesserae)

**Goal:** the existing playable 3D scene renders as animated pixel-art in the Galla Placidia
palette — deep lapis grounds, gold tesserae, luminous figures on dark, meander/wave borders — by
inserting a low-res pixel stage and mosaic post-process **into `RunView`** and replacing its
daylight lighting. **Presentation-only; must not edit `sim/`.**
**Phase-Exit Test:** `test_render_pipeline.gd` (headless-safe) asserts the `SubViewport` target is
at the configured internal resolution, the palette LUT has 16 entries, and the mosaic shader
compiles; a golden-image test of a fixed 2-settlement scene asserts >95% of sampled pixels fall on
the palette (quantization proven) **and** that a screen click still resolves to the correct basin
through the viewport (picking survives the reparent).

- **R2.1 — Palette module.** files: `presentation/render/palette.gd`, `presentation/render/palette_lut.png`
  (16×1). do: the 16 Ravenna colors from `[rav §R-art]` as `Color` constants + a 1-D LUT texture.
  tests: `test_palette.gd` — 16 entries, hexes match spec, LUT pixels equal the constants.
- **R2.2 — Pixel stage inside RunView (the reparent).** files: `presentation/render/pixel_stage.gd`,
  edit `presentation/shell/run_view.gd`. do: introduce a `SubViewport` at internal res
  (`[rav §R-art]`: 384×216) with nearest-neighbor filter, and **reparent RunView's 3D subtree**
  (sun, `WorldEnvironment`, `world_view`, `nav`, `camera`, `pool`, `_highlight`) under it; present
  it upscaled integer-multiple in a full-rect `TextureRect`. **Critical:** RunView's picking
  (`_ground_point`/`_pick`/`_hover` use `camera.project_ray_origin/normal(screen_pos)`) must be fed
  **viewport-local** coordinates, not window coordinates — add a screen→SubViewport transform (or
  route input through the SubViewport) and pixel-snap the camera each frame so the mosaic doesn't
  shimmer on pan. tests: viewport size correct; upscale integer; a <1-internal-pixel pan yields an
  identical framebuffer hash (snap proven); a known screen point maps to the expected basin.
- **R2.3 — Mosaic post-process shader.** files: `presentation/render/mosaic.gdshader`. do: a screen
  shader on the `TextureRect` that (1) **palette-maps** to the nearest LUT color (optional 4×4
  ordered dither toward the 2 nearest, `[rav §R-art]`), (2) overlays a **tessera grid** — dark
  grout lines on an N-pixel lattice with per-cell value jitter (hash by cell) so flats read as laid
  stone, (3) a **gold-leaf accent** lifting luminance on the blessed/high-devotion mask (R2.6).
  tests: compiles; solid input quantizes to the expected entry; grout lands on the lattice.
- **R2.4 — Late-antique lighting & mood (replace RunView's).** files: edit
  `presentation/shell/run_view.gd` `_build_environment` (or a `stage_lighting.gd` it calls). do:
  swap the daylight setup — `SKY_COLOR`/`AMBIENT_COLOR`/sun — for the `[rav §R-art]` values: one
  low warm gold key light, deep-blue ambient/bg, strong figure rim (luminous-on-dark), mild bloom
  on gold, crushed blacks. tests: environment/light resource values equal spec (headless: assert
  resources, not a render).
- **R2.5 — Material reskin (terrain, water, people).** files: `presentation/world_view.gd`,
  `presentation/person_puppet.gd` (renamed in R1). do: terrain material in palette bands by
  elevation/biome (sage/ochre/gold, lapis water); the puppet mesh becomes a robed-figure silhouette
  (swap `CapsuleMesh` per `[rav §R-art]`); remap the existing fear→red / faith→gold tint (reuse
  `get_feeling`, no new sim read) onto palette entries. tests: `test_puppet_tint.gd` — tints resolve
  to palette colors; dead→hidden holds; stage-scale unchanged.
- **R2.6 — Mosaic motif borders & belief masks.** files: `presentation/render/motifs.gd`. do: draw
  the reference vocabulary — **meander (Greek key)**, **wave-scroll**, **rosette/star roundels**,
  **Chi-Rho monogram** — as decal/quads around sacred/blessed places and settlement edges; feed a
  blessed/high-devotion screen mask to R2.3's gold pass so revered ground shines; render
  `cursed`/`blessed` place-tags as red-tessera / gold-tessera borders. tests: `test_motifs.gd` —
  blessed emits gold border + mask pixels; cursed red; neither when untagged.

🎮 **PLAYTEST GATE A — "Does it read as Ravenna?"** `AWAIT_PLAYTEST.md`: judge palette fidelity,
tesserae/grout feel, figure-on-dark luminosity, motifs vs. the reference images. Halt for GO.

---

## Phase R3 — Living settlements (sim: autonomous building & development)

**Goal:** settlements autonomously build farms/housing/religious/civic structures, grow through
**hamlet → village → town → city**, and regress under hardship — aggregate flows on the existing
statistical tier, driven by the same pressures the player (or nature) shapes, **consistent with
`terrain.gd`'s lived tags**. **Sim-only — no presentation refs.**
**Phase-Exit Test:** `test_settlement_development.gd` — a seeded settlement given sustained surplus
+ agriculture/construction grows its structure stock, crosses village→town→city in `[rav §R-set]`
order (one `settlement_tier_changed` per crossing), then a famine strips buildings and drops tier.

- **R3.1 — Structures on the aggregate.** files: `sim/settlement.gd`, `sim/serializer.gd`. do: add
  `structures := {}` (building-id → fractional count) + a derived `tier` accessor per
  `[rav §R-build]`; round-trip them in settlement serialization. tests: defaults empty; `tier()`
  hamlet when tiny; round-trip includes structures + tier.
- **R3.2 — Tier thresholds.** files: `sim/systems/settlement_sim.gd`. do: `tier_of(s, colony)` from
  population **and** gating structure/tech per `[rav §R-set]`; emit `settlement_tier_changed` (new
  EventBus signal) on change, with hysteresis. tests: exact crossings up/down; one event per
  crossing; no flicker at the boundary.
- **R3.3 — Autonomous construction flow.** files: `sim/systems/construction.gd` (new). do:
  `construction_season_tick(colony, s, pressures, surplus)` — build labor from surplus adults
  `[rav §R-set]`; choose the next structure by a priority reading the same signals the player
  shapes (crowding→dwelling, hunger/water→farm/well, fear→wall, faith→shrine/temple,
  surplus+writing/trade→granary/market) per `[rav §R-infl]`; accumulate progress; on completion
  increment and emit `structure_built`. All weights/costs in `[rav §R-set]`. tests (seeded): each
  pressure builds its structure first; nothing without labor/tech; determinism.
- **R3.4 — Structure effects feed existing flows (no double-count).** files:
  `sim/systems/tech_effects.gd` (extend), `settlement_sim.gd`. do: structures **modulate** existing
  terms per `[rav §R-build]` — farms→effective agriculture in `K`/`food_factor`; granary→famine
  buffer; dwellings→a housing cap co-limiting `crowding`; well→drought mortality; temple→lower
  terror-unrest growth; wall→`war_strength`; market→trade mood/spread. Where a building expresses an
  existing §14 level (farm↔agriculture, wall/temple↔construction) it modulates that term, not a
  parallel one. tests: each effect in isolation; no double-count vs existing multipliers.
- **R3.5 — Regression & abandonment.** files: `construction.gd`, `settlement_sim.gd`. do: under-
  labored structures decay per `[rav §R-set]` (floored at 0); tier can drop; a dark age can lose the
  workshop (ties to §7 per-settlement extinction). tests: depopulating sheds buildings + drops tier;
  dark age removes workshop; recovery rebuilds.
- **R3.6 — Player-influence → development wiring.** files: `sim/systems/construction.gd`. do: make
  the priority read (a) `need_pressures` phenomena already set (drought→hunger/water→farms/wells),
  (b) belief/devotion scalars (fear-omens→walls/temples; a wonder/blessed tag→a shrine *there*),
  (c) place-tags (blessed attracts, cursed→abandonment) per `[rav §R-infl]`. **No new command
  channel** (design §1.3, algo §16 loop 4); note that `natural_events` pressures flow through the
  same path. tests (seeded): a `landslide` (fear + ore) shifts toward walls + workshop; a
  `weeping_sky` ending drought shifts toward farms; a blessed tag seeds a shrine — assert priorities
  move, not that the player placed anything.

---

## Phase R4 — Settlement visuals (presentation, plugged into RunView)

**Goal:** settlements appear on stage as mosaic-styled clusters whose composition and scale reflect
the sim's structure stock and tier, growing building-by-building as the sim builds them — added as a
child of the **existing** `RunView`, reading the live `run.settlements` + `sid_places` it already
computes. **Presentation-only — reads the sim, never writes.** *(No "assemble the scene" task — the
shell already exists; this only adds a `SettlementView` node and wires two signals.)*
**Phase-Exit Test:** `test_settlement_view.gd` — driving a scripted sim village→city spawns/upgrades
the correct props (village = huts + field + shrine; town = +granary/+workshop/+temple/partial wall;
city = dense dwellings, basilica-temple w/ Chi-Rho, market, full wall), props appear on
`structure_built`, and the civ-map medallion matches the tier.

- **R4.1 — Building prop library.** files: `presentation/settlement/props.gd`,
  `presentation/settlement/*.tscn`. do: simple low-poly meshes per `[rav §R-build]` id (gabled
  dwelling, field patch, granary, colonnaded workshop, shrine aedicula, basilica/temple with a
  Chi-Rho gable, cistern/well, wall segment, market stoa), styled to read as mosaic architecture
  through the R2 post-process. tests: every id has a prop scene; loads headless.
- **R4.2 — Settlement renderer.** files: `presentation/settlement/settlement_view.gd`, edit
  `run_view.gd` to add it as a child. do: for each `Settlement` in `run.settlements`, place props at
  `place_positions[sid_places[sid]]` (RunView already maps these), scattered golden-angle-by-sid
  (sim has no per-building coords → stable presentation function of sid + structure index), count/
  kind from `structures`, density stepping by tier; may fall back to `terrain.gd`'s `farmland`/
  `built_up` tags where a basin has no structure detail. tests: prop count tracks structure count;
  placement deterministic per sid; empty/dead settlement renders nothing.
- **R4.3 — Growth & tier feedback.** files: `settlement_view.gd`. do: on `structure_built` a prop
  scales/fades in; on `settlement_tier_changed` a civ-map medallion updates (rosette=village,
  star-roundel=town, Chi-Rho medallion=city) and a mosaic band tightens around the settlement; add a
  line to the RunView HUD/chronicle when a settlement changes tier. tests: event→prop appears;
  tier event→medallion swap.
- **R4.4 — Chronicle & aftermath vocabulary.** files: `presentation/ui/chronicle.gd`, aftermath. do:
  settlement history reads as civic development ("Classe grew from village to town in year 40; the
  temple rose after the Long Dark"); aftermath surfaces *"what they built, and why"*, tying
  construction to your acts (the `[rav §R-infl]` loop, legible in hindsight — design §2.7). tests:
  chronicle mentions a tier change + a build attributed to a phenomenon; no "gnome" copy.

🎮 **PLAYTEST GATE B — "Does development read and feel earned?"** `AWAIT_PLAYTEST.md`: judge whether
settlements visibly grow, whether acts *legibly* steer what gets built (walls after fear, temples
after devotion, farms after drought), and whether village→town→city feels like a payoff. Halt for GO.

---

## Phase R5 — Integration, determinism, polish

**Goal:** the redesign holds under the existing invariants at scale.
**Phase-Exit Test:** all named integration tests green, plus the two new ones.

- **R5.1 — `test_ravenna_end_to_end.gd`.** A seeded multi-settlement run: drought→farms/wells,
  landslide→fear→walls + revealed-ore workshop, sustained devotion→temple, growth village→town→city,
  then a Long Dark→regression — asserting the A+B+C chain, sim-side only.
- **R5.2 — `test_determinism` (redesign envelope).** Re-hash seed + config + acts + attention with
  structures/tiers/names in state; confirm reproducibility (or update the golden with a documented
  PROGRESS note).
- **R5.3 — Perf re-check.** Re-run the §14 budget (`test_scale`) with the construction flows added
  (per-season aggregate — cheap); confirm the tick budget holds; note headroom in PROGRESS per the
  DONE.md handover.
- **R5.4 — Lint, tag, handover.** `./lint.sh` clean; tag `phase-R5-complete`; write
  `DONE-ravenna.md` (what changed, open playtest questions).

---

## Appendix A — `[rav §R-art]` render constants

**Palette — 16 tesserae colors** (Galla Placidia range). *Starting values, tuned at Gate A.*

| # | name | hex | use |
|---|------|-----|-----|
| 0 | night-lapis | `#0d1b3e` | vault ground / deepest shadow |
| 1 | deep-lapis | `#14285a` | sky / water body |
| 2 | mid-blue | `#245a8c` | water highlight / mid ground |
| 3 | verdigris | `#2f6d5f` | foliage shadow / border scroll |
| 4 | sage-green | `#5a8f6b` | grass / field |
| 5 | pale-green | `#9dc08b` | lit grass / young crop |
| 6 | gold-deep | `#a97b18` | gold-leaf shadow |
| 7 | gold | `#d6a53a` | gold tesserae / halo / roof |
| 8 | gold-lit | `#f2d488` | gold highlight / shine |
| 9 | ochre | `#b07636` | earth / warm stone |
| 10 | terracotta | `#a2432c` | roof-tile / cursed border |
| 11 | oxblood | `#5e1f1c` | deep red accent / blood-omen |
| 12 | cream | `#e8ddc4` | robe base / marble |
| 13 | bone-white | `#f5efe0` | robe highlight / star |
| 14 | slate-grey | `#3a4152` | grout mid / cool stone |
| 15 | near-black | `#080a12` | grout / outline |

**Stage/shader:** internal res `384×216` (integer upscale); `grout_px 4`, `grout_color #080a12`,
grout alpha `0.35`, per-cell value jitter `±0.06`; ordered dither `4×4` toward the 2 nearest,
strength `0.5`; gold-leaf luminance lift `+0.25` on the blessed mask. **Lighting (replaces RunView's
`SKY_COLOR`/`AMBIENT_COLOR`/sun):** key light gold `#f2d488`, energy `1.3`, elevation `28°`; ambient
bg `#0d1b3e`, ambient energy `0.35`; figure rim `#f2d488` `0.4`; bloom threshold `0.85` (gold only);
black crush `0.04`.

## Appendix B — `[rav §R-name]` rename map & name banks

**Identifiers:** `GnomeData→PersonData`, `GnomePuppet→PersonPuppet`; files
`gnome_data.gd→person_data.gd`, `gnome_puppet.gd→person_puppet.gd`; signal
`gnome_died→person_died`; serializer `gnome_to_dict/from_dict→person_to_dict/from_dict`; colony
field `gnomes→people` + serialized key `"gnomes"→"people"` (touches `presentation/shell/run_view.gd`
& `game_run.gd`, which read `colony.gnomes`); all local vars/comments/`.uid`. Working title
*"The Unseen Hand"*.

**Person names** (late-Roman / early-Byzantine, mixed): *Galla, Placidia, Honoria, Valentinian,
Constantius, Aetius, Theodora, Justin, Valens, Severa, Cassia, Flavia, Marcian, Pulcheria, Leo,
Verina, Anicius, Serena, Boethius, Cassiodorus, Sidonius, Ambrosia, Felix, Aurelia, Priscus…*
**Places:** *Classe, Caesarea, Ariminum, Faventia, Portus, Urbicus, Salustra, Theodericum…*

## Appendix C — `[rav §R-set]` settlement development (extends algo §14)

**Tiers** (population **and** structure gates; hysteresis ±10% pop):
- **Hamlet:** default / pop < 12.
- **Village:** pop ≥ 12 **and** farm ≥ 1.
- **Town:** pop ≥ 60 **and** construction_level ≥ 1 **and** granary ≥ 1.
- **City:** pop ≥ 250 **and** temple ≥ 1 **and** wall ≥ 1.

**Build labor/season:** `labor = max(0, adults − 0.33·pop) · 0.5` (surplus beyond the §17
maintenance load). **Cost (labor-seasons):** dwelling 1 · farm 1.5 · well 1.5 · granary 3 ·
workshop 4 · shrine 2 · wall 5 · market 4 · temple 8. Accumulate `build_progress += labor`; spend on
the top-priority buildable; on `progress ≥ cost` increment, subtract, emit `structure_built`.

**Priority** (max over buildable = tech-met & under cap): dwelling `= crowding`; farm
`= hunger_pressure + 0.3`; well `= water_pressure`; granary `= surplus·(town+)`; workshop
`= has_ore + curiosity`; shrine `= faith·(1 − has_shrine)`; temple `= faith·devotion_tier·(village+)`;
wall `= fear + war_threat`; market `= surplus·(writing∨trade)`. Caps scale with tier (dwellings
`≈ pop/4`).

**Decay:** each season `count −= 0.05·max(0, 1 − labor/upkeep)` per structure, floored at 0; tier
re-derived (can drop). Dark age can zero the workshop.

## Appendix D — `[rav §R-build]` building effects (modulate existing flows, no double-count)

| building | prereq | effect (into existing sim) |
|---|---|---|
| dwelling | — | housing cap `+4 pop`; `crowding = pop / min(K, housing_cap)` |
| farm | agriculture | `+0.15` effective agriculture in `K`/`food_factor` (capped ≈ the §14 `0.5·ag` term, not additive) — keep consistent with `terrain.gd` `farmland` |
| well/cistern | — | drought/water mortality `−20%` while active |
| granary | agriculture | famine deaths `−30%` |
| workshop | smithing/stoneworking | craft research pressure `×1.2`; enables metallurgy uptake |
| shrine | — | belief-crystallization duration `−1 season` |
| temple | construction + devotion tier ≥ III | terror-unrest growth `×0.8`; devotion mass `×1.05` here |
| wall | construction | `war_strength ×(1 + 0.25·wall_count)`, cap ×2 — keep consistent with `terrain.gd` `built_up` |
| market | writing ∨ trade route | trade mood-lift `×1.5`; knowledge-spread `+1 partner` |

All multipliers are starting points, tuned at the gates; R3.4's isolation tests guard against
double-counting with the existing §14 tech terms.

---

## Dependency graph

`R0 → R1 → {R2, R3}` (render and settlement-sim independent after the rename) `→ R4` (needs R2's
pixel stage + R3's structures) `→ R5`. Gate A after R2, Gate B after R4. ~22 atomic tasks across 6
phases; each one green commit, tests-first (except the R1.1 suite-gated refactor), numbers only from
`docs/redesign-ravenna.md`.

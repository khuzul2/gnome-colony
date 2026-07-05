# Redesign Plan — "Ravenna": mosaic render + living settlements (late-antique Christian-like gnomes)

*Loop-ready, test-gated. Companion to `docs/implementation-plan.md` (same operating contract, §0
there still applies), `PROGRESS.md` (phases 0–23, the live task ledger), and
`docs/evolution-algorithm.md` (still the numeric source of truth). This redesign **adds** a new
authoritative spec, `docs/redesign-ravenna.md` (authored in Phase R0), and **extends** algo
§14/§17 — it never silently invents a number.*

**Setting & mood (per user, 2026-07-05):** an **alternate late-antique / early-medieval Earth**
inhabited by gnomes, orcs, goblins, and other fantastic creatures. *This game is about the
**gnomes*** — late-antique gnomes with a **Christian-like** faith. So: **keep gnomes and the name
"Gnome Colony"** (no rename to "people"), but render and flavor them in the **Ravenna Christian
mosaic register** — gold-ground tesserae, halos, the sacred monogram (a Chi-Rho-like mark), basilica
architecture — reframed as the gnomes' *own* religion of the unseen will, not literal Christianity.
The other creatures are the world's context (fodder for the existing Beasts/monsters and
frontier-threat flavor); they are **out of task scope** here — the redesign is render + settlements.
The game's existing emergent theology, prophets, schisms and heresies map cleanly onto this register
(Ravenna itself was split Arian vs. Orthodox), so this is a **visual + light-copy reskin, not a
mechanics change**.

**Two workstreams:**

- **A — Ravenna mosaic render.** Keep the existing 3D scene; layer a low-res pixelation +
  palette-mapping + mosaic post-process on top, in the Galla Placidia palette (deep lapis grounds,
  gold tesserae, luminous figures on dark, meander/wave/rosette borders, halos, the sacred
  monogram). The gnomes stay gnomes — *rendered as late-antique Christian mosaic*.
- **B — Living settlements.** Autonomous farms/housing/religious/civic buildings (basilicas,
  shrines, walls); **hamlet → village → town → city**; player actions steer development *indirectly*
  (design §1.3). Includes the sim mechanics and the settlement visuals.

**Rebased on `main` @ Phase 23 (2026-07-05).**

---

## Review: this plan vs. `main` as actually built

`main` (167 commits, phases 0–23) is now a **fully assembled, playable game**:
`presentation/shell/game_shell.gd` boots `main.tscn` → MainMenu → `GameRun` → **`RunView`**
(`presentation/shell/run_view.gd`), which lights the world (a `DirectionalLight3D` sun + ambient
`WorldEnvironment`), skins the region graph (`WorldView`), pools puppets, drives a 3-zoom
`CameraRig`, walks puppets along a baked `NavWorld`, feeds the Eye's attention, and routes the
influence panel's arm→paint→cast with keyboard/mouse (Phase 23). There is a live **multi-settlement
civilization tier** (`GameRun.settlements`, `sid → Settlement`) with war/schism (Phase 21) and a
`frontier: N settlements · souls · seat` readout.

Grep-confirmed absences (the work this plan covers):
- **No pixel-art / palette / shader / mosaic** anywhere — plain daylit 3D.
- **No settlement buildings or tiers** — `Settlement` has zero `structures`/`tier`.

**What that changes for each workstream:**

| Workstream | Original assumption (stale) | Reality on `main` | Verdict |
|---|---|---|---|
| **A · mosaic render** | Build a render scene from scratch (`main.tscn` empty) | **Scene exists** (`RunView`), lit for plain daylight. No `SubViewport`/shader/palette. | **Re-scoped:** don't build a scene — **insert a pixel `SubViewport` + mosaic shader into `RunView`** and **replace its lighting**. |
| **B · living settlements** | Settlement pure stats; no live civ data | Still pure stats (no `structures`/`tier`), but there's now a live `GameRun.settlements` + `sid_places`, and **`sim/systems/terrain.gd`** derives lived tags (`farmland`/`built_up`/`crowded`/`drought`). | **Still needed; better anchored** — read `run.settlements`; **integrate with `terrain.gd`** rather than duplicate. |
| ~~C · people, not gnomes~~ | ~~rename~~ | — | **Dropped by request** — gnomes and "Gnome Colony" stay; the late-antique **Christian-like** mood is delivered as art + light copy (workstream A), not a rename. |

**Two new systems to respect (don't fight them):**
- **`sim/systems/terrain.gd`** — "living terrain": rewrites the home place's affordance tags from
  colony state daily. Farms/dwellings in B should be *consistent* with `farmland`/`built_up`; B's
  visuals may read these tags as a coarse fallback where a settlement lacks structure detail.
- **`sim/systems/natural_events.gd`** — opt-in (`WorldConfig.environmental_events`) scheduler firing
  catalog phenomena unbidden. Development pressure in B can therefore come from *nature*, not only
  the player — the construction driver handles this correctly because it reads world/need state, not
  "who cast it." Note it; change nothing.

Task IDs are **R-prefixed** (no collision with the live `T0..T23`).

---

## 0. How to consume this plan (delta over implementation-plan.md §0)

Everything in `docs/implementation-plan.md §0` holds: **one task per iteration**, **tests first**,
the **Definition of Done**, **phase gates**, **git discipline**, **STUCK.md** on ambiguity,
**numbers only from spec**. Two additions:

1. **New source of truth.** Phase R0 creates `docs/redesign-ravenna.md` (read-only thereafter) with
   every *new* number — palette hexes, shader constants, and the settlement-development formulas
   (§R-set, extending algo §14). After R0, cite it as `[rav §X]`. If it's silent, write `STUCK.md`.
2. **Invariants unchanged.** `sim/` stays plain data + logic with zero `Node`/scene/render refs.
   Workstream A is **presentation-only**. Workstream B's *mechanics* are **sim logic**, never
   referencing presentation; its *visuals* are presentation-only. Player influence on development
   stays **indirect** (design §1.3): no build button, no "designate a spot" — inputs remain seed,
   `WorldConfig`, influence acts, and attention.

Append the R-plan to `PROGRESS.md` (R0.2) after the live phase-23 block; work the first unchecked
task whose deps are checked.

---

## Phase R0 — The redesign spec (numeric source of truth)

**Goal:** one read-only doc holds every new constant.
**Phase-Exit Test:** `test_rav_spec_present.gd` asserts `docs/redesign-ravenna.md` exists and
contains anchors `§R-art §R-set §R-build §R-infl`; the palette table parses to exactly the 16 hex
entries in Appendix A.

- **R0.1 — Author `docs/redesign-ravenna.md`.** files: `docs/redesign-ravenna.md`. do: transcribe
  Appendices A–D of this plan into numbered read-only sections (`§R-art` palette + shader/lighting;
  `§R-set` tiers + construction; `§R-build` building effects; `§R-infl` influence→development
  routing). tests: `test_rav_spec_present.gd`.
- **R0.2 — Append the R-plan to `PROGRESS.md`.** files: `PROGRESS.md`. do: add all R-tasks as
  unchecked checkboxes with deps, after the live phase-23 block. tests: none (doc); DoD = committed.

---

## Phase R1 — Ravenna mosaic render (wrap the existing RunView; pixelate + palette + tesserae)

**Goal:** the existing playable 3D scene renders as animated pixel-art in the Galla Placidia
palette — deep lapis grounds, gold tesserae, gnomes glowing against dark, meander/wave borders — by
inserting a low-res pixel stage and mosaic post-process **into `RunView`** and replacing its
daylight lighting. Gnomes stay gnomes; only their *rendering* becomes mosaic. **Presentation-only;
must not edit `sim/`.**
**Phase-Exit Test:** `test_render_pipeline.gd` (headless-safe) asserts the `SubViewport` target is
at the configured internal resolution, the palette LUT has 16 entries, and the mosaic shader
compiles; a golden-image test of a fixed 2-settlement scene asserts >95% of sampled pixels fall on
the palette (quantization proven) **and** that a screen click still resolves to the correct basin
through the viewport (picking survives the reparent).

- **R1.1 — Palette module.** files: `presentation/render/palette.gd`,
  `presentation/render/palette_lut.png` (16×1). do: the 16 Ravenna colors from `[rav §R-art]` as
  `Color` constants + a 1-D LUT texture. tests: `test_palette.gd` — 16 entries, hexes match spec,
  LUT pixels equal the constants.
- **R1.2 — Pixel stage inside RunView (the reparent).** files: `presentation/render/pixel_stage.gd`,
  edit `presentation/shell/run_view.gd`. do: introduce a `SubViewport` at internal res
  (`[rav §R-art]`: 384×216) with nearest-neighbor filter, and **reparent RunView's 3D subtree**
  (sun, `WorldEnvironment`, `world_view`, `nav`, `camera`, `pool`, `_highlight`) under it; present it
  upscaled integer-multiple in a full-rect `TextureRect`. **Critical:** RunView's picking
  (`_ground_point`/`_pick`/`_hover` use `camera.project_ray_origin/normal(screen_pos)`) must be fed
  **viewport-local** coordinates, not window coordinates — add a screen→SubViewport transform (or
  route input through the SubViewport) and pixel-snap the camera each frame so the mosaic doesn't
  shimmer on pan. tests: viewport size correct; upscale integer; a <1-internal-pixel pan yields an
  identical framebuffer hash (snap proven); a known screen point maps to the expected basin.
- **R1.3 — Mosaic post-process shader.** files: `presentation/render/mosaic.gdshader`. do: a screen
  shader on the `TextureRect` that (1) **palette-maps** to the nearest LUT color (optional 4×4
  ordered dither toward the 2 nearest, `[rav §R-art]`), (2) overlays a **tessera grid** — dark grout
  lines on an N-pixel lattice with per-cell value jitter (hash by cell) so flats read as laid stone,
  (3) a **gold-leaf accent** lifting luminance on the blessed/high-devotion mask (R1.6). tests:
  compiles; solid input quantizes to the expected entry; grout lands on the lattice.
- **R1.4 — Ravenna lighting & mood (replace RunView's).** files: edit
  `presentation/shell/run_view.gd` `_build_environment` (or a `stage_lighting.gd` it calls). do:
  swap the daylight setup — `SKY_COLOR`/`AMBIENT_COLOR`/sun — for the `[rav §R-art]` values: one low
  warm gold key light, deep-blue ambient/bg, strong figure rim (luminous-on-dark), mild bloom on
  gold, crushed blacks. tests: environment/light resource values equal spec (headless: assert
  resources, not a render).
- **R1.5 — Material reskin + halos (terrain, water, gnomes).** files: `presentation/world_view.gd`,
  `presentation/gnome_puppet.gd`. do: terrain material in palette bands by elevation/biome
  (sage/ochre/gold, lapis water); keep the **gnome** puppet mesh/silhouette (do not turn them into
  anything else) and remap the existing fear→red / faith→gold tint (reuse `get_feeling`, no new sim
  read) onto palette entries so gnomes read as glowing tesserae figures. **Halo (the Ravenna
  touch):** a gold nimbus quad behind a gnome whose sim state already marks it holy — prophet
  (`prophet` set) or high `notability` — reusing data presentation already reads, no new sim
  channel. tests: `test_puppet_tint.gd` — tints resolve to palette colors; dead→hidden holds;
  stage-scale unchanged; a prophet/high-notability gnome shows a halo, an ordinary one does not.
- **R1.6 — Mosaic motifs, Christian-like iconography & belief masks.** files:
  `presentation/render/motifs.gd`. do: draw the Ravenna vocabulary — **meander (Greek key)**,
  **wave-scroll**, **rosette/star roundels**, the **star-field ground**, and the **sacred monogram**
  (a **Chi-Rho-like mark** that is *the gnomes' own* monogram of the unseen will — late-antique
  Christian in style, diegetically their faith) — as decal/quads around sacred/blessed places and
  settlement edges; feed a blessed/high-devotion screen mask to R1.3's gold pass so revered ground
  shines; render `cursed`/`blessed` place-tags as red-tessera / gold-tessera borders. tests:
  `test_motifs.gd` — a blessed place emits the gold monogram border + mask pixels; cursed red;
  neither when untagged.

🎮 **PLAYTEST GATE A — "Does it read as Ravenna?"** `AWAIT_PLAYTEST.md`: judge palette fidelity,
tesserae/grout feel, gnomes-on-dark luminosity, and motifs vs. the reference images. Halt for GO.

---

## Phase R2 — Living settlements (sim: autonomous building & development)

**Goal:** settlements autonomously build farms/housing/religious/civic structures, grow through
**hamlet → village → town → city**, and regress under hardship — aggregate flows on the existing
statistical tier, driven by the same pressures the player (or nature) shapes, **consistent with
`terrain.gd`'s lived tags**. **Sim-only — no presentation refs.**
**Phase-Exit Test:** `test_settlement_development.gd` — a seeded settlement given sustained surplus
+ agriculture/construction grows its structure stock, crosses village→town→city in `[rav §R-set]`
order (one `settlement_tier_changed` per crossing), then a famine strips buildings and drops tier.

- **R2.1 — Structures on the aggregate.** files: `sim/settlement.gd`, `sim/serializer.gd`. do: add
  `structures := {}` (building-id → fractional count) + a derived `tier` accessor per `[rav §R-build]`;
  round-trip them in settlement serialization. tests: defaults empty; `tier()` hamlet when tiny;
  round-trip includes structures + tier.
- **R2.2 — Tier thresholds.** files: `sim/systems/settlement_sim.gd`. do: `tier_of(s, colony)` from
  population **and** gating structure/tech per `[rav §R-set]`; emit `settlement_tier_changed` (new
  EventBus signal) on change, with hysteresis. tests: exact crossings up/down; one event per
  crossing; no flicker at the boundary.
- **R2.3 — Autonomous construction flow.** files: `sim/systems/construction.gd` (new). do:
  `construction_season_tick(colony, s, pressures, surplus)` — build labor from surplus adults
  `[rav §R-set]`; choose the next structure by a priority reading the same signals the player shapes
  (crowding→dwelling, hunger/water→farm/well, fear→wall, faith→shrine/temple,
  surplus+writing/trade→granary/market) per `[rav §R-infl]`; accumulate progress; on completion
  increment and emit `structure_built`. Weights/costs in `[rav §R-set]`. tests (seeded): each
  pressure builds its structure first; nothing without labor/tech; determinism.
- **R2.4 — Structure effects feed existing flows (no double-count).** files:
  `sim/systems/tech_effects.gd` (extend), `settlement_sim.gd`. do: structures **modulate** existing
  terms per `[rav §R-build]` — farms→effective agriculture in `K`/`food_factor`; granary→famine
  buffer; dwellings→a housing cap co-limiting `crowding`; well→drought mortality; temple→lower
  terror-unrest growth; wall→`war_strength`; market→trade mood/spread. Where a building expresses an
  existing §14 level (farm↔agriculture, wall/temple↔construction) it modulates that term, not a
  parallel one. tests: each effect in isolation; no double-count vs existing multipliers.
- **R2.5 — Regression & abandonment.** files: `construction.gd`, `settlement_sim.gd`. do:
  under-labored structures decay per `[rav §R-set]` (floored at 0); tier can drop; a dark age can
  lose the workshop (ties to §7 per-settlement extinction). tests: depopulating sheds buildings +
  drops tier; dark age removes workshop; recovery rebuilds.
- **R2.6 — Player-influence → development wiring.** files: `sim/systems/construction.gd`. do: make
  the priority read (a) `need_pressures` phenomena already set (drought→hunger/water→farms/wells),
  (b) belief/devotion scalars (fear-omens→walls/temples; a wonder/blessed tag→a shrine *there*),
  (c) place-tags (blessed attracts, cursed→abandonment) per `[rav §R-infl]`. **No new command
  channel** (design §1.3, algo §16 loop 4); note `natural_events` pressures flow through the same
  path. tests (seeded): a `landslide` (fear + ore) shifts toward walls + workshop; a `weeping_sky`
  ending drought shifts toward farms; a blessed tag seeds a shrine — assert priorities move, not that
  the player placed anything.

---

## Phase R3 — Settlement visuals (presentation, plugged into RunView)

**Goal:** settlements appear on stage as mosaic-styled clusters whose composition and scale reflect
the sim's structure stock and tier, growing building-by-building as the sim builds them — added as a
child of the **existing** `RunView`, reading the live `run.settlements` + `sid_places` it already
computes, rendered through R1's mosaic pipeline. **Presentation-only — reads the sim, never writes.**
**Phase-Exit Test:** `test_settlement_view.gd` — driving a scripted sim village→city spawns/upgrades
the correct props (village = huts + field + shrine; town = +granary/+workshop/+basilica/partial
wall; city = dense dwellings, basilica with the monogram gable, market, full wall), props appear on
`structure_built`, and the civ-map medallion matches the tier.

- **R3.1 — Building prop library.** files: `presentation/settlement/props.gd`,
  `presentation/settlement/*.tscn`. do: simple low-poly meshes per `[rav §R-build]` id (gabled
  dwelling, field patch, granary, colonnaded workshop, shrine aedicula, **basilica** — the temple,
  a late-antique gabled hall bearing the sacred monogram on its pediment — cistern/well, wall
  segment, market stoa), styled to read as Christian-mosaic architecture through the R1
  post-process. tests: every id has a prop scene; loads headless.
- **R3.2 — Settlement renderer.** files: `presentation/settlement/settlement_view.gd`, edit
  `run_view.gd` to add it as a child. do: for each `Settlement` in `run.settlements`, place props at
  `place_positions[sid_places[sid]]` (RunView already maps these), scattered golden-angle-by-sid
  (sim has no per-building coords → stable presentation function of sid + structure index), count/
  kind from `structures`, density stepping by tier; may fall back to `terrain.gd`'s `farmland`/
  `built_up` tags where a basin has no structure detail. tests: prop count tracks structure count;
  placement deterministic per sid; empty/dead settlement renders nothing.
- **R3.3 — Growth & tier feedback.** files: `settlement_view.gd`. do: on `structure_built` a prop
  scales/fades in; on `settlement_tier_changed` a civ-map medallion updates (rosette=village,
  star-roundel=town, **monogram-medallion**=city — the Chi-Rho-like sacred mark for the seat of a
  basilica) and a mosaic band tightens around the settlement; add a line to the RunView HUD/chronicle
  when a settlement changes tier. tests: event→prop appears; tier event→medallion swap.
- **R3.4 — Chronicle & aftermath vocabulary.** files: `presentation/ui/chronicle.gd`, aftermath. do:
  settlement history reads as civic development ("the hollow grew from village to town in year 40;
  the temple rose after the Long Dark"); aftermath surfaces *"what they built, and why"*, tying
  construction to your acts (the `[rav §R-infl]` loop, legible in hindsight — design §2.7). tests:
  chronicle mentions a tier change + a build attributed to a phenomenon.

🎮 **PLAYTEST GATE B — "Does development read and feel earned?"** `AWAIT_PLAYTEST.md`: judge whether
settlements visibly grow, whether acts *legibly* steer what gets built (walls after fear, temples
after devotion, farms after drought), and whether village→town→city feels like a payoff. Halt for GO.

---

## Phase R4 — Integration, determinism, polish

**Goal:** the redesign holds under the existing invariants at scale.
**Phase-Exit Test:** all named integration tests green, plus the two new ones.

- **R4.1 — `test_ravenna_end_to_end.gd`.** A seeded multi-settlement run: drought→farms/wells,
  landslide→fear→walls + revealed-ore workshop, sustained devotion→temple, growth village→town→city,
  then a Long Dark→regression — asserting the settlement chain, sim-side only.
- **R4.2 — `test_determinism` (redesign envelope).** Re-hash seed + config + acts + attention with
  structures/tiers in state; confirm reproducibility (or update the golden with a documented PROGRESS
  note). *(No name/rename state is added, so the envelope only grows by the settlement fields.)*
- **R4.3 — Perf re-check.** Re-run the §14 budget (`test_scale`) with the construction flows added
  (per-season aggregate — cheap); confirm the tick budget holds; note headroom in PROGRESS per the
  DONE.md handover.
- **R4.4 — Lint, tag, handover.** `./lint.sh` clean; tag `phase-R4-complete`; write
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
| 12 | cream | `#e8ddc4` | robe/marble base |
| 13 | bone-white | `#f5efe0` | highlight / star |
| 14 | slate-grey | `#3a4152` | grout mid / cool stone |
| 15 | near-black | `#080a12` | grout / outline |

**Stage/shader:** internal res `384×216` (integer upscale); `grout_px 4`, `grout_color #080a12`,
grout alpha `0.35`, per-cell value jitter `±0.06`; ordered dither `4×4` toward the 2 nearest,
strength `0.5`; gold-leaf luminance lift `+0.25` on the blessed mask. **Lighting (replaces RunView's
`SKY_COLOR`/`AMBIENT_COLOR`/sun):** key light gold `#f2d488`, energy `1.3`, elevation `28°`; ambient
bg `#0d1b3e`, ambient energy `0.35`; figure rim `#f2d488` `0.4`; bloom threshold `0.85` (gold only);
black crush `0.04`.

**Mood & iconography (late-antique Christian-like — the gnomes' own faith):** the register is the
Ravenna Christian mosaic. Iconography set: **sacred monogram** — a Chi-Rho-like mark, the gnomes'
symbol of the unseen will (on the blessed border, the basilica pediment, the city medallion);
**halo/nimbus** — gold `#d6a53a`→`#f2d488` disc, outer radius ≈ 0.6× puppet height, behind any gnome
that is a prophet or `notability ≥ 0.6`; **star-field ground** — bone-white `#f5efe0` stars scattered
on night-lapis for sacred vaults/roundels; **orant/frontal** figure staging for the haloed.
Borders: meander (Greek key), wave-scroll, rosette. Architecture register: basilica, aediculae,
colonnade, gabled pediment. Diegesis: this is the gnomes' religion (emergent theology of the player),
rendered Christian-like — *not* a claim of literal Christianity; the game's schisms/heresies read as
the era's own creed disputes (Arian vs. Orthodox is the natural analog).

## Appendix B — `[rav §R-set]` settlement development (extends algo §14)

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

## Appendix C — `[rav §R-build]` building effects (modulate existing flows, no double-count)

| building | prereq | effect (into existing sim) |
|---|---|---|
| dwelling | — | housing cap `+4 pop`; `crowding = pop / min(K, housing_cap)` |
| farm | agriculture | `+0.15` effective agriculture in `K`/`food_factor` (capped ≈ the §14 `0.5·ag` term, not additive) — consistent with `terrain.gd` `farmland` |
| well/cistern | — | drought/water mortality `−20%` while active |
| granary | agriculture | famine deaths `−30%` |
| workshop | smithing/stoneworking | craft research pressure `×1.2`; enables metallurgy uptake |
| shrine | — | belief-crystallization duration `−1 season` |
| basilica (temple) | construction + devotion tier ≥ III | terror-unrest growth `×0.8`; devotion mass `×1.05` here; the seat's Christian-like faith house |
| wall | construction | `war_strength ×(1 + 0.25·wall_count)`, cap ×2 — consistent with `terrain.gd` `built_up` |
| market | writing ∨ trade route | trade mood-lift `×1.5`; knowledge-spread `+1 partner` |

All multipliers are starting points, tuned at the gates; R2.4's isolation tests guard against
double-counting with the existing §14 tech terms.

## Appendix D — `[rav §R-infl]` influence → development routing (indirect only)

The construction priority (Appendix B) is fed **only** by signals the player already shapes through
the world — never a build command. Mapping:

| player/nature signal (existing) | reads as | steers toward |
|---|---|---|
| drought phenomena / low larder → hunger & water need-pressure | scarcity | **farm, well/cistern** |
| landslide/quake/beast → fear scalar + `war_threat` | threat | **wall**, and (revealed ore) **workshop** |
| devotion depth + faith scalar | reverence | **shrine → temple** |
| bountiful harvest / good seasons → surplus | plenty | **granary, market**, growth toward the next tier |
| a wonder or a `blessed` place-tag on a site | sanctified ground | **shrine at that place** |
| famine / `cursed` tag / war depopulation | ruin | **abandonment & regression** (Appendix B decay) |

The rule (design §1.3): you author the *cause* (a drought, an omen, a devotion), never the *effect*
(the farm, the wall, the temple). Development is the gnomes' response, legible only in hindsight
(design §2.7). `natural_events` (if enabled) enters the same table as another author of causes.

---

## Dependency graph

`R0 → {R1, R2}` (render and settlement-sim independent) `→ R3` (needs R1's pixel stage + R2's
structures) `→ R4`. Gate A after R1, Gate B after R3. ~20 atomic tasks across 5 phases; each one
green commit, tests-first, numbers only from `docs/redesign-ravenna.md`. **No rename** — gnomes and
"Gnome Colony" unchanged; the late-antique **Christian-like** register is a visual + light-copy
reskin over the existing (already schism-and-prophet-driven) theology, not a mechanics change.

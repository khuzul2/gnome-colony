# DONE — Gnome Colony, build complete and PLAYABLE

Every `T<id>` in docs/implementation-plan.md is checked, every Phase-Exit
test and all seven named integration tests (`test_milestone1`,
`test_iron_irony`, `test_scale`, `test_determinism`, `test_epochal`,
`test_invariants`, `test_diversity_balance`) are green, and lint is clean.

**Final state (2026-07-04, Phase 18):** 112 test scripts · 625 tests · 3172 asserts ·
lint clean · phases 0–18 tagged (`phase-0-complete` … `phase-18-complete`,
local tags — tag pushes are rejected by branch-scoped rights).

## Post-plan additions (user-requested, 2026-07-03/04)

- **Natural environmental events (opt-in):** `WorldConfig.environmental_events`
  + per-event `event_frequencies` (off/rare/occasional/frequent), a New Game
  world option. `sim/systems/natural_events.gd` rolls each scheduled catalog
  phenomenon daily through the full influence pipeline at neutral magnitude.
  Default OFF — the sole-authorship experience and every replay are untouched.
- **Main settlement & succession:** `Colony.main_settlement`; migration pull
  (`Civilization.MAIN_PULL`) + emigration retention (`SettlementSim.
  MAIN_RETENTION`) bias growth toward the seat; on its death
  `Civilization.update_main_settlement` anoints the largest survivor and emits
  `EventBus.main_settlement_changed`. (Live consumer arrives with any future
  civ-tier orchestration; biases engage wherever the seat is set.)
- **Phase 18 — every disclosed gap closed (2026-07-04):** living terrain
  (drought/farmland/built_up/crowded derive daily from real state; wilds from
  world-gen — every affordance-gated act landable), the LIVE civilization
  tier (§14 emigration + fracture splinters open frontier basins that live
  aggregate seasons, trade, succeed the main settlement, and carry the world
  on), full wizard + settings chrome through the whitelisted setters, and a
  monotonic save-ordering tiebreaker.
- **Phase 17 — the final assembly (handover note 3, delivered):** the game is
  now one executable flow. `presentation/shell/` holds WorldBootstrap
  (seed → fixture-exact playable world), GameRun (the proven epochal/slice
  daily composition + tier-gated casting + save/resume with the RNG stream),
  GameShell on `main.tscn` (all eight setup-§6 menu entries live), and RunView
  (world skin, crowd-capped puppets, dwell → Eye → LOD, arm-and-paint casting,
  §7.4 autosaves). `test_phase17_exit.gd` walks boot → menu → quick-start →
  season → cast → save → Continue → extinction → kept Chronicle, and proves
  two identically scripted shell runs byte-identical.

## Sound & music (Phases 19-20, 2026-07-04)

- assets/sounds/: 51 named WAVs covering every phenomenon, consequence,
  life event, ambience bed, and UI click (5 sourced CC0/CC-BY, 46
  deterministic synth drafts; SOURCES.md records licenses; regenerate via
  generate_placeholders.py). SoundDirector plays them EventBus-only —
  §2.7c's no-stinger rule is a test.
- assets/music/: 10 empty .mp3 placeholders, each with a Suno.ai
  dungeon-synth brief (.md). Compose, drop the files in, delete
  assets/music/.gdignore — MusicDirector already resolves every state
  (seasons, rite, both hymns, menu, lament, founding) and skips empty
  placeholders silently.

## What was built

- **The sim (`sim/`, plain data + logic):** gnome agents (§1 state, traits,
  needs, feelings), utility-AI decisions, life cycle & Gompertz mortality,
  skills/teaching/knowledge-extinction/writing, partnerships, genetics
  with mutation & outliers, plasticity, culture & belief objects
  (crystallization, taboos, rites, theology), the influence system (15-act
  §18 catalog, cascades, tail-risk, wards, culture-resolved social
  outcomes), devotion (attribution seed, ratcheting tier ladder,
  social-mass magnitude, terror tax + §17 unrest birth damp), prophets
  (seeding, arcs, rivals, spam brake), tech & magic co-evolution (the
  answered god), the hierarchical LOD ladder (quickened / individual /
  statistical / folded + promotion/demotion), settlements & the
  civilization tier (trade, schism, war, world-end latch), region-graph
  world-gen, full save serialization with RNG-stream continuation,
  Tuning.resolve (every setup option → parameters), telemetry.
- **Determinism:** all randomness through the `Rng` singleton; a full run
  reproduces from seed + config + recorded acts + recorded attention
  (test_determinism hashes the whole envelope).
- **Presentation (`presentation/`, reads the sim, never writes):**
  heightmap skin, puppet pool, navmesh routing that honors sim-buried
  paths, three-zoom camera, the Eye-of-God attention recorder, influence
  panel (tier-gated, target-kind painting), aftermath/hindsight panel,
  heatmaps, the faint codex (no numbers, ever), diegetic ambience, main
  menu, New-Game wizard (§1 presets verbatim), save store & load menu,
  settings (machine-only; sim-hash proven unchanged), chronicle & stores.

## Handover notes (for the human)

1. **Strict performance budget** — the 12 ms/tick @10k budget was verified
   on this container only against the calibrated 24 ms tripwire (human
   ruling 2026-07-03). On reference hardware, set `test/integration/
   test_scale.gd`'s headroom to 1.0 and re-run before shipping.
2. **Fun was never hands-on evaluated** — all three playtest gates were
   waived by instruction (the last with "GO let's go on until the end").
   The core-feel questions in the old FUN CHECK 3 brief (cadence,
   attributability, agency, tyrant/shepherd feel) remain open for your
   own play sessions; core-feel rework is expected, not exceptional.
3. **Final assembly — DELIVERED (Phase 17, 2026-07-04).** The shell binds
   menu → wizard → world → HUD → panels → chronicle; `godot` runs the game.
   Still-thin edges, all disclosed in PROGRESS: wizard pages 2–4 and the
   settings screen remain logic-first (chrome-light, as T15.2/T15.4
   shipped); life-terrain affordances (farmland/built_up/crowded/drought/
   wilds) were never world-authored, so acts gated on them fizzle exactly
   as in every tested composition; the civ/aggregate tier stays
   library+test-composed (no live multi-basin loop was ever specified);
   NavWorld stays a library (the sim authored no movement to route).
   Perf note: on the Phase-17 session's cloud container, test_scale's
   24 ms tripwire is marginal for the PRE-Phase-17 baseline too
   (23.76–24.40 ms measured) — the point-1 reference-hardware re-check
   below covers it.
4. **Known open minors** (all reviewer-noted, non-blocking, in PROGRESS
   Notes): wizard setters silently no-op on typo'd keys; §17's
   "productivity" half of the unrest damp is wired to births and the
   aggregate birth flow only (no separate productivity consumer exists
   yet at either grain); §7.3 controller rebinding is keys-only.
5. **Snapshot rollbacks** — this container was twice restored from stale
   snapshots mid-build; the remote branch was always the source of truth.
   If it happens again: `git restore .`, fetch, `merge --ff-only`,
   re-create local tags from the Phase-Exit commits, re-import.

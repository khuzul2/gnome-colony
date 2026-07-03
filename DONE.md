# DONE — Gnome Colony, one-shot build complete

Every `T<id>` in docs/implementation-plan.md is checked, every Phase-Exit
test and all seven named integration tests (`test_milestone1`,
`test_iron_irony`, `test_scale`, `test_determinism`, `test_epochal`,
`test_invariants`, `test_diversity_balance`) are green, and lint is clean.

**Final state (2026-07-03):** 100 test scripts · 524 tests · 2732 asserts ·
lint clean · phases 0–16 tagged (`phase-0-complete` … `phase-16-complete`,
local tags — tag pushes are rejected by branch-scoped rights).

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
3. **Final assembly** — systems are built and tested individually and in
   integration harnesses; the single orchestrated game scene that binds
   menu → wizard → world → HUD → panels into one executable flow is
   deliberately thin (the playtest slice is the closest thing). That
   glue is presentation-only work with no new sim surface.
4. **Known open minors** (all reviewer-noted, non-blocking, in PROGRESS
   Notes): wizard setters silently no-op on typo'd keys; §17's
   "productivity" half of the unrest damp is wired to births and the
   aggregate birth flow only (no separate productivity consumer exists
   yet at either grain); §7.3 controller rebinding is keys-only.
5. **Snapshot rollbacks** — this container was twice restored from stale
   snapshots mid-build; the remote branch was always the source of truth.
   If it happens again: `git restore .`, fetch, `merge --ff-only`,
   re-create local tags from the Phase-Exit commits, re-import.

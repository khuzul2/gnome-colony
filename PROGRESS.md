# PROGRESS — Gnome Colony task ledger

Generated from docs/implementation-plan.md Appendix A. The loop agent checks items off
only when their Definition of Done is met (tests green, lint clean, committed).
Tasks are listed in plan order; do the FIRST unchecked task whose deps are checked.
🎮 lines are HUMAN playtest gates: write AWAIT_PLAYTEST.md, commit, and STOP until a
human records GO here.

## Phase 0 — Scaffold & test harness
- [x] T0.1 Project skeleton — project.godot (main scene presentation/main.tscn), dir tree, test_smoke.gd; boot exit 0
- [x] T0.2 Install GUT + test command — plugin enabled in project.godot, commands documented in README_DEV.md (GUT pre-vendored; upstream gut_loader.gd:35 prints a benign SCRIPT ERROR, doesn't affect results)
- [x] T0.3 Lint/format gate — .gdlintrc (defaults + addons/.godot excluded), ./lint.sh gate; CLAUDE.md lint command now ./lint.sh
- [x] T0.4 `Rng` singleton — sim/rng.gd autoload (extends Node is the Godot autoload requirement, mandated by the plan; no scene state); mixed-API replay, gauss mean, bounds, chance extremes proven in test_rng.gd
- [x] T0.5 `WorldConfig` resource — sim/world_config.gd (RefCounted, all setup §3–§5 defaults + quicken_budget 300); normalize() clamps/validates. seed & colony_name are wizard-filled placeholders.
- [x] Phase-Exit 0: test_smoke.gd passes headless; Rng reproduces a fixed sequence from a seed → tagged phase-0-complete (14/14 tests, 428 asserts, lint clean, verified from a wiped .godot/ cache)

## Phase 1 — Core data model & time
- [x] T1.1 Enums & constants — Enums class (LifeStage + trait/need/belief-axis catalogs). KNOWLEDGE_CATEGORIES ids "craft/tech/magic" are a naming choice for §7's prose, not spec-literal strings.
- [x] T1.2 `GnomeData` — full §1 state + clamp helpers; add_knowledge() enforces set semantics. MEMORY_CAP=16 is a structural constant (spec says only "small"), not a gameplay number.
- [x] T1.3 `Colony` registry — id map, next_id, living(), remove. Delivered full §5 vitals (not just a stub) + spawn()/population() helpers; public API: spawn/add/remove/living/population/vitals.
- [x] T1.4 `TimeService` — 1 tick = 1 day per algo §17 (plan's "ticks/day=4" is a pre-review fossil; §17 wins). Reminder for T6.2: propagation runs DAILY (design-review R3-H1), not every 4 ticks.
- [x] T1.5 Serialization round-trip — Serializer static to_dict/from_dict for GnomeData/Colony/WorldConfig, deep-copied (no aliasing). Full save-game serializer deferred to T12.1 as planned.
- [x] Phase-Exit 1: colony of 4, 100 ticks, calendar exact, state intact (test/integration/test_phase1_exit.gd) → tagged phase-1-complete. NOTE: canonical test command now includes -ginclude_subdirs (integration tests live in test/integration/).

## Phase 2 — Life cycle
- [x] T2.1 `EventBus` — autoload with the 6 core signals; world_ended deferred to T11.4 as planned.
- [x] T2.2 Aging & stage transitions — Aging.stage_for_age + tick; exact §17 bands; emits stage_changed.
- [x] T2.3 Mortality — Gompertz + hardship + accident, per-component rolls give cause attribution; hard cap 115. PUBLIC API: GnomeData.hardship_rate added (T3.5 writes it); Serializer updated accordingly.
- [x] T2.4 Birth scaffold — Birth.spawn_infant placeholder (sex via Rng, born event); inheritance/fertility deferred to Phase 5.
- [x] Phase-Exit 2: seeded 50-year elder-cohort run; lifespans in §4 bounds (mean ∈ [85,100], cap 115); one gnome_died per gnome → tagged phase-2-complete

## Phase 3 — Needs & utility decision
- [x] T3.1 Needs decay — §17 rates + stage mods; safety recovers −0.06/day toward 0.
- [x] T3.2 Action catalog — 7 §6 actions, exact relief vectors + stage/ctx gates; "create" = §6's create/explore row.
- [x] T3.3 Utility scoring — need²·relief with side costs subtracting; work trait_mod 0.7+0.6·industrious; culture/belief mods are ctx hooks (T6.4 wires them); jitter U(0,0.05) via Rng. SIGN CONVENTION: catalog deltas are signed (negative reduces a need); Utility scores with −delta; Act (T3.4) must apply raw deltas via adjust_need.
- [x] T3.4 Decide & act loop — Decide.choose (max utility, idle fallback), Act.apply (signed deltas; eat draws MEAL_UNITS=1.0 — implementation unit). ResourceNode (§15) pulled forward, constructor-parameterized, no invented defaults.
- [x] T3.5 Hardship link — sustained ≥0.9 hunger/safety >5 days ⇒ hardship_rate 0.15/day. Tracking placed in needs.gd (owns need updates) rather than the plan's "edit mortality.gd" — Mortality already consumes hardship_rate. PUBLIC API: GnomeData.hardship_days added; serializer covers it.
- [ ] T3.6 Projects (multi-tick goals)
- [ ] Phase-Exit 3: hungry colony with a food source recovers over seeded ticks, no scripting → tag phase-3-complete

## Phase 4 — Skills, knowledge, teaching, extinction
- [ ] T4.1 Proficiency & practice
- [ ] T4.2 Teaching transfer
- [ ] T4.3 Decay & un-teachable
- [ ] T4.4 Extinction (per-settlement)
- [ ] T4.5 Writing durability
- [ ] Phase-Exit 4: sole holder dies untaught ⇒ extinction event; with writing ⇒ no extinction → tag phase-4-complete

## Phase 5 — Relationships, reproduction, genetics (= prototype Milestone 1)
- [ ] T5.1 Relationship edges
- [ ] T5.2 Partnership
- [ ] T5.3 Fertility & births
- [ ] T5.4 Genetic inheritance
- [ ] T5.5 Trait plasticity
- [ ] T5.7 Outlier births (divergence engine)
- [ ] T5.6 Milestone integration test (test_milestone1.gd)
- [ ] Phase-Exit 5 (Milestone 1): 4-gnome colony, default WorldConfig, ≥5 generations across 20 seeded runs, dying out ≤40% → tag phase-5-complete

## Phase 6 — Culture & belief (hybrid)
- [ ] T6.1 Scalar substrate
- [ ] T6.2 Batched propagation
- [ ] T6.3 Crystallization
- [ ] T6.4 Behavioral effects
- [ ] T6.5 Drift & subcultures
- [ ] Phase-Exit 6: seeded scenario crystallizes a place-taboo; utility for acting there drops → tag phase-6-complete

## Phase 7 — Influence system: phenomena & appraisal (= prototype Milestone 2)
- [ ] T7.1 Phenomenon schema
- [ ] T7.2 Phenomenon runner + stimulus
- [ ] T7.3 The `landslide`
- [ ] T7.4 Appraisal
- [ ] T7.5 Tail-risk & chaining
- [ ] T7.7 Phenomenon valence + toolbox balance
- [ ] T7.8 Seed catalog loader (15 phenomena, [algo §18])
- [ ] T7.9 Culture-resolved social + boon taint
- [ ] T7.6 Iron-irony integration (test_iron_irony.gd)
- [ ] Phase-Exit 7 (Milestone 2 + iron-irony): landslide kills, exposes iron, cursed tag crystallizes, survivors avoid the iron tile → tag phase-7-complete

## Phase 8 — Devotion & social mass
- [ ] T8.1 Devotion compute
- [ ] T8.2 Tier unlocks (per-capita, ratcheting)
- [ ] T8.3 Social-mass magnitude + valence potency
- [ ] T8.4 Terror instability + secularization
- [ ] T8.5 Attribution seed (bootstrap)
- [ ] T8.6 Notability growth
- [ ] Phase-Exit 8: belief raises D; tier unlocks at threshold; magnitude grows sub-linearly with D → tag phase-8-complete

## 🎮 PLAYTEST GATE 1 — Vertical Slice & Fun Check (HUMAN go/no-go — HALT)
- [ ] Throwaway minimal interactive view built (top-down render + 2–3 phenomena buttons + mood/belief readout)
- [ ] Human GO recorded here

## Phase 9 — Prophets
- [ ] T9.1 Prophet entity & seeding
- [ ] T9.2 Charisma, reach, amplification
- [ ] T9.3 Life-arc & corruption
- [ ] T9.4 Rivals & schism
- [ ] Phase-Exit 9: prophet catches only when ripe; rivals ⇒ schism; spam ⇒ fractured faith → tag phase-9-complete

## Phase 10 — Technology & magic discovery
- [ ] T10.1 Knowledge graph & prereqs
- [ ] T10.2 Discovery process
- [ ] T10.3 Tech effects
- [ ] T10.4 Magic understanding ladder
- [ ] Phase-Exit 10: prereqs gate discovery; pressure raises rate; magic thresholds unlock prediction then wards; warded tile reduces intensity → tag phase-10-complete

## 🎮 FUN CHECK 2 — Emergence: culture, prophets, tech & god-vs-mages (HUMAN — HALT)
- [ ] Human GO recorded here

## Phase 11 — Hierarchical simulation (scale)
- [ ] T11.1 LOD manager
- [ ] T11.2 Settlement tier
- [ ] T11.3 Promotion fidelity
- [ ] T11.6 Emergent leadership
- [ ] T11.4 Civilization tier
- [ ] T11.5 Scale/perf test (test_scale.gd, ⚙️ budget in plan §Phase 11)
- [ ] Phase-Exit 11: 10,000-pop world advances a year within perf budget; aggregates match individual control within tolerance → tag phase-11-complete

## Phase 12 — Persistence & determinism
- [ ] T12.1 Full serializer
- [ ] T12.2 Determinism harness (input-scoped) (test_determinism.gd)
- [ ] T12.3 `WorldConfig` ingestion
- [ ] Phase-Exit 12: identical run-hash twice from seed+config+recorded acts+attention; save→load→continue equals uninterrupted → tag phase-12-complete

## Phase 13 — Presentation: world, puppets, camera
- [ ] T13.1 Region-graph → heightmap skin
- [ ] T13.2 `GnomePuppet`
- [ ] T13.3 NavMesh for LOD-0
- [ ] T13.4 Camera & three-zoom lens
- [ ] T13.5 Attention input (the Eye, dwell-based)
- [ ] Phase-Exit 13: puppets reflect GnomeData; heightmap matches region-graph; camera zooms civ→settlement→individual; navmesh path found → tag phase-13-complete

## Phase 14 — Influence UI & feedback layer
- [ ] T14.1 Phenomenon controls (7 categories, tier-gated, act targeting)
- [ ] T14.2 Feedback/hindsight
- [ ] T14.3 Heatmaps + faint codex
- [ ] T14.4 Diegetic ambience & act feedback
- [ ] Phase-Exit 14: category controls appear/lock by devotion tier; aftermath panel reflects outcomes → tag phase-14-complete

## 🎮 FUN CHECK 3 — The real playable build & engagement (HUMAN — HALT)
- [ ] Human GO recorded here

## Phase 15 — Menus & setup
- [ ] T15.1 Main menu
- [ ] T15.2 New Game wizard
- [ ] T15.3 Load Game
- [ ] T15.4 Settings (global)
- [ ] T15.5 Chronicle & world's end
- [ ] Phase-Exit 15: wizard emits correct WorldConfig; Load lists saves; Settings persist and never alter sim → tag phase-15-complete

## 🎮 PLAYTEST 4 — Onboarding & full flow (HUMAN go/no-go — HALT)
- [ ] Human GO recorded here

## Phase 16 — Integration, balance & polish
- [ ] T16.1 Epochal smoke run (test_epochal.gd)
- [ ] T16.2 Tuning-invariant tests (test_invariants.gd)
- [ ] T16.5 Diversity & balance invariants (test_diversity_balance.gd)
- [ ] T16.3 Telemetry hooks
- [ ] T16.4 Final pass (DONE.md, project-complete sigil)
- [ ] Phase-Exit 16: long seeded run 4 gnomes → multi-settlement civilization, no crash/runaway, invariants pass → tag phase-16-complete

## Notes
(The agent appends one-line notes here when checking tasks off, and records any public-API changes other tasks depend on.)
- Setup: GUT v9.5.0 pre-vendored at addons/gut/ during repo bootstrap (GitHub archive downloads are blocked in the build environment; raw file fetch was used). T0.2 should wire/verify it, not fetch it.

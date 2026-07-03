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
- [x] T3.6 Projects — persist unless a need ≥0.9 (reuses HARDSHIP_THRESHOLD); completion applies §6 create relief. PUBLIC API: Decide.choose can now return "project:<kind>"; GnomeData.project added; serializer covers it.
- [x] Phase-Exit 3: hungry colony + food node self-recovers via Needs→Decide→Act (mean hunger 0.8 → <0.3 in 14 days, no deaths) → tagged phase-3-complete

## Phase 4 — Skills, knowledge, teaching, extinction
- [x] T4.1 Proficiency & practice — asymptotic practice gain; knowledge id tracks the 0.2 teachability line both directions (reviewer made me strip teach/decay back out to T4.2/T4.3 — good catch).
- [x] T4.2 Teaching transfer — 0.03·(t−l)·q·dt; id at 0.2, chain teaches onward. teacher_quality q: spec leaves undefined → explicit param default 1.0. The t≤l no-op guard is an interpretive addition (the raw §17 formula would DECREASE a better learner) — teaching only pulls up.
- [x] T4.3 Decay & un-teachable — unused −0.002/day (used_skills exempt); below 0.2 forfeits the id; practice re-earns it.
- [x] T4.4 Extinction (per-settlement) — Knowledge.sync/check_extinction; regional loss with knowledge_lost events. PUBLIC API: Colony.settlement_knowledge + durable_records added (serializer covers them). No orchestrator yet — systems still composed by tests, per phase design.
- [x] T4.5 Writing durability — snapshot_records where "writing" is known; durable ids extinction-proof; study_record re-teaches from the page at the practice rate (spec defines no separate record rate — interpretive choice).
- [x] Phase-Exit 4: sole holder dies untaught ⇒ extinction; taught apprentice or writing prevents it; craft restorable from record → tagged phase-4-complete

## Phase 5 — Relationships, reproduction, genetics (= prototype Milestone 1)
- [x] T5.1 Relationship edges — 0.05·sign·compat symmetric step, idle decay 0.001/day. compat = 1 − mean|Δtrait| (interpretive; spec says only "rises with similarity").
- [x] T5.2 Partnership — mutual mate ≥0.6, Adults, unpartnered; culture-permitted hook (Callable, default allow) for T6 norms; deterministic sorted matching.
- [x] T5.3 Fertility & births — 0.15·food·(1−crowding)/season per fertile pair; bearer = sex 0 aged 20–50 (arbitrary tag, documented); kin edges start at 0 weight (no spec value). PUBLIC API: GnomeData.generation added; Birth.spawn_infant takes optional parents.
- [x] T5.4 Genetic inheritance — per-trait blend + N(0,0.05), 2% extra N(0,0.2) (per-trait reading of §8, reviewer-confirmed); skills never inherited.
- [x] T5.5 Trait plasticity — Culture stub: young drift 0.02·(env−trait)/day, linear taper 14→20 (interpretive curve), constitutional traits exempt. PUBLIC API: GnomeData.constitutional_traits added (T5.7 populates; serializer covers).
- [x] T5.7 Outlier births — p=0.01/birth, uniform type pick (interpretive); mutant traits out-of-band (edge ± U(0.1,0.5), interpretive magnitude), raw-written and inherited unclamped w/ marker; touched prophet_affinity=1. PUBLIC API: GnomeData.outlier_type + prophet_affinity added (serializer covers).
- [x] T5.6 Milestone integration test — 17/20 seeded runs reach gen 5 (bar: ≥12); chronicle logs births/deaths. PUBLIC API: SimRunner added (headless orchestrator; company picks implement §8 assortative mating); Social.form_partnerships now frees widowed slots (interpretive — dead partners can't hold one; test_partnership updated with real-spouse premise + widowhood test). NOTE: the milestone test adds ~5 min to every full-suite run.
- [x] Phase-Exit 5 (Milestone 1): 4-gnome colony, default WorldConfig — 17/20 seeded runs reached gen 5 (failures 3/20 ≤ 40%) → tagged phase-5-complete

## Phase 6 — Culture & belief (hybrid)
- [x] T6.1 Scalar substrate — appraise (intensity·susceptibility − habituation, never inverted), habituation +0.15/−0.02/day, relaxation −0.03/day. susceptibility 0.5+0.5·trait (interpretive; fear→timid faith→devout awe→curious reverence→devout). PUBLIC API: GnomeData.habituation added (serializer covers).
- [x] T6.2 Batched propagation — 0.04·tie·gap daily (R3-H1: NOT every 4 ticks), fear ×1.5, two-pass batched (one edge/day max), dead excluded.
- [x] T6.3 Crystallization — min holders max(5, ceil(3%·pop)) (rounding interpretive), ≥0.7 sustained a season (dip resets), strength = mean feeling × holder fraction. REVIEW FIX: §9 triggers overlap and ALL fire (taboo←fear/reverence, rite←awe/faith, place_reverence←reverence, theology←faith); taboo avoidance bites via the object (cursed tags reserved for Phase-7 phenomena chains); blessed tag = mean feeling. PUBLIC API: Colony.beliefs/place_tags/belief_tracker (serializer covers); BeliefObject factory.
- [x] T6.4 Behavioral effects — Belief.place_mod: taboo objects & cursed tags ×(1−0.5·s), blessed ×(1+0.8·s), multiplying; linear maps hit §6's [0.5,1.8] endpoints (interpretive). Wired into Utility via ctx belief_mods.
- [x] T6.5 Drift & subcultures — 3% transmission mutation (variant bump); greedy per-GNOME clustering at distance ≥0.5 (spec names threshold, not algorithm; §14 schism will need settlement-level clustering ON TOP — not done yet).
- [x] Phase-Exit 6: sustained VARIED dread crystallizes a ridge taboo (single shocks fade by design — vary or escalate); work-at-ridge utility drops → tagged phase-6-complete

## Phase 7 — Influence system: phenomena & appraisal (= prototype Milestone 2)
- [x] T7.1 Phenomenon schema — validate() with all §11 fields; social number-or-"=culture"; taint benevolent-only; target kinds = §11 ∪ §18 (adds "region" — §18's long_dark needs it).
- [x] T7.2 Phenomenon runner + stimulus — Influence.cast (handler registry, one stimulus per cast; magnitude/potency stubs 1.0 until T8.3). PUBLIC API: WorldState added (minimal sites/hidden/paths container; region-graph comes with Phase 11/13).
- [x] T7.3 The `landslide` — buries site, reveals ore, blocks "<site>_path", casualties at |effects.population|·intensity per present gnome (interpretive lethality dial). PUBLIC API: GnomeData.location added (serializer covers).
- [x] T7.4 Appraisal — witnesses (at place) write fear to place AND phenomenon type (one habituation bump/event — Belief.appraise gained bump_habituation param, back-compatible); safety spike intensity·(0.3+timid) (prototype formula); curious>0.6 bank discovery memories.
- [x] T7.5 Tail-risk & chaining — cast_with_cascade: BFS chain_hooks at the parent's place; 0.03 tail roll per act emits "tail:<id>"; MAX_CASCADE=8 structural guard (non-spec, documented).
- [x] T7.7 Valence + toolbox balance — valence was in the T7.1 schema; balance_report enforces kind+cruel face per stocked category and all-valences overall (presence, not parity — §18 tilts 4/7/4). The plan's "docs/ content" edit doesn't apply (docs are read-only; content lands as data in T7.8).
- [x] T7.8 Seed catalog loader — all 15 §18 entries as data (4/7/4, 2 clean/2 tainted); CONSEQUENCES markers for abstract chain targets; affordance gating enforced in Influence.cast (WorldState.affordances added). Interpretive: ground_remembers m=+0.2 (of "+0.2/−0.1"), day_twice tail=2×0.03 ("elevated"), touched-births echo left to Phase 9 (no spec prob).
- [x] T7.9 Culture-resolved social + boon taint — resolve_social: swing(=intensity)·(cohesion − fear_level − fracture), interpretive closed forms documented; stimuli carry taint markers; consequence chain targets surface as traceable stimuli. T7.8 review fixes folded in (omen_charge hook removed, cascade honors gating).
- [x] T7.6 Iron-irony integration — full pipeline seeded: kills, iron exposed, witnesses frightened, §18 cursed-place chain tags the ridge, survivors' work-there utility drops. Consequence markers can now carry handlers (cursed_place writes the tag at parent intensity).
- [x] Phase-Exit 7 (Milestone 2 + iron-irony): test_iron_irony.gd walks the whole cause→tragedy→belief→ironic-obstacle loop → tagged phase-7-complete

## Phase 8 — Devotion & social mass
- [x] T8.1 Devotion compute — D=Σ faith toward "unseen_will", d̄=D/pop, flavor_balance=mean(awe−fear).
- [x] T8.2 Tier unlocks — d̄_peak ratchet, §17 thresholds, pop floors (gen≥5 alternative for VI); ladder never skips a gated rung. PUBLIC API: Colony.devotion_peak + unlocked_tier (serializer covers).
- [x] T8.3 Magnitude + valence potency — 1+0.9·log10(1+M), δ=0.4; Influence.cast_act wires both (Phase-7 stubs retired).
- [x] T8.4 Terror instability + secularization — unrest tax 0.02·|flavor|·log10(1+M)/day; INTERPRETIVE: tax and relief are mutually exclusive (relief only in quiet time — reproduces §17's 30–40-day fracture sanity figure; additive reading would miss it); fracture at 0.8; schism +0.01·unrest/season; secularization −0.0005·science/day on faith. PUBLIC API: Colony.unrest (serializer covers). Also pinned T8.2's no-skip ladder with a hermit test.
- [x] T8.5 Attribution seed — faith += 0.25·clamp(0.3+0.7·devout−0.8·magic)·drama per witness; flavor rides valence (malevolent→fear else awe, interpretive).
- [x] T8.6 Notability growth — award/tick/on_mastery + §14 leader_score; §17 decay −0.001/day; INTERPRETIVE award weights (§14 names deeds, not sizes): DEED 0.3, MASTERY 0.3 (once per craft, credit serialized), PROPHET_LEADER 0.4 — sized so prophet+deed crosses the 0.6 LOD line. leader_score = 0.5·not + 0.3·ambitious + 0.2·relevant (oratory/leadership, else best skill). PUBLIC API: GnomeData.mastered_skills (serializer covers); SimRunner daily order gains Notability.tick. Mastery is LIVE-wired at the skills choke point (every proficiency write checks the 0.9 crossing — reviewer catch, follow-up commit); DEFERRED: phenomenon-survival/Elder/many-children/prophet-leader awards are wired by their owning systems (T9.x prophets, T11.x settlements).
- [x] Phase-Exit 8: dramatic casts → attribution → D rises each event; Tier II opens exactly at the first d̄ ≥ 0.15 crossing; equal D slices (0/10/20/30) buy strictly shrinking intensity steps (log10 sub-linearity) → tagged phase-8-complete (282 tests, lint clean)

## 🎮 PLAYTEST GATE 1 — Vertical Slice & Fun Check (HUMAN go/no-go — HALT)
- [x] Throwaway minimal interactive view built (top-down render + 2–3 phenomena buttons + mood/belief readout) — presentation/playtest/playtest_slice.tscn; slice-only glue documented in-file (day-trip staging writes GnomeData.location pending Phase 11/13 movement; daily Belief/Devotion composition mirrors integration tests pending the Phase 11–12 orchestrator). Only still_air is live at boot (Tier I); standing_stones/landslide open when d̄_peak crosses 0.15 — the unlock loop IS the demo.
- [x] Human GO recorded here — 2026-07-02, user: "GO (faith based, can't test but we can change later)". Provisional GO: the fun check was waived, not passed — revisit the core feel at 🎮 FUN CHECK 2 with extra scrutiny.

## Phase 9 — Prophets
- [x] T9.1 Prophet entity & seeding — try_seed on Omen ⑤/Vision ⑥ stimuli; ripeness = local mean(|awe−fear| toward YOU) ≥ 0.5 (§17). INTERPRETIVE (documented in prophet.gd): charge measured toward the unseen will; adults/elders only; vessel = max(prophet_affinity + devout), existing prophets passed over; message {subject: trigger, flavor: mercy|wrath} from flock charge + vessel nurturing−aggressive; catching awards PROPHET_LEADER (closes a T8.6 deferred hook). PUBLIC API: GnomeData.prophet dict (serializer covers); Influence.cast stimuli now carry "category".
- [x] T9.2 Charisma, reach, amplification — charisma N(0.6,0.2) clamped, rolled at catch (§17); reach = BFS over POSITIVE living edges, depth = round(charisma·5); preach writes faith+flavor at 0.12·charisma/day; forced crystallization mirrors T6.3's holder floor & strength but skips the season timer — mints theology(YOU) with flavor + prophet_id, one creed per prophet. INTERPRETIVE (spec gives shapes, not sizes; documented in prophet.gd): depth cap 5, preach rate 3× §9 propagation ("fast"), enemies don't carry the gospel.
- [x] T9.3 Life-arc & corruption — influence = charisma·arc(age); corruption 0.10/life (§17) rolled ONCE at catch, doomed prophets flip mercy→madness (preached as fear) at a fated hour; Prophet.tick composes corruption check + daily preaching. INTERPRETIVE (§12 names shapes, not timings; documented in prophet.gd): arc rise 1 y from floor 0.3 → peak 10 y → fade 15 y → floor 0.3 remnant; doom hour U(1,20) years into the career.
- [x] T9.4 Rivals & schism — check_schism: due when ≥2 LIVING prophets' creeds stand at strength ≥ 0.3 (trigger only; the split lands with T11.4, mirroring T8.4's fracture_due); Prophet.tick spam brake: each voice beyond the first taxes unrest 0.01/day and erodes shared faith 0.005/day. INTERPRETIVE (§12 names dynamics, no numbers; documented in prophet.gd): 0.3 strength line (50/50 split at the 0.7 crystallization line ≈ 0.35), spam rates. Rivalry is by AUTHOR, not flavor (§12 says "rival prophets", not rival flavors — two mercy creeds from two living vessels still compete; T11.4 consumes factions as-is). Also folded in: GnomeData prophet-dict doc line mentions doom_at (T9.3 reviewer minor). NOTE: Prophet.tick is not yet wired into SimRunner — prophet primitives compose in tests/slice until the orchestrator integration (Phases 11–12), same as Belief/Devotion ticks (reviewer note).
- [x] Phase-Exit 9: full pipeline — omen casts charge the flock until the same omen that fell flat catches a vessel past the 0.5 line; two congregations crystallize rival creeds ⇒ schism due; 4 spam prophets erode faith + breed unrest vs an orthodox control → tagged phase-9-complete (318 tests, lint clean). Test premise: a prophet believes their own creed (their faith counts among holders).

## Phase 10 — Technology & magic discovery
- [x] T10.1 Knowledge graph & prereqs — TechGraph: 10-id starter catalog, prereqs_met/candidates; techs are ordinary knowledge ids (Phase-4 lifecycle: teach/decay/extinction/records apply unchanged; "writing" is the same id T4.5 already consumes). §7 fixes the rule + the smithing←fire+stoneworking edge; §13 fixes the six tech ids. INTERPRETIVE (documented in tech_graph.gd): all other edges (irrigation←agriculture, writing←agriculture, metallurgy←smithing, construction←stoneworking, medicine←writing, sail←construction) follow design §4's necessity hints. Effects data lands in T10.3.
- [x] T10.2 Discovery process — pressure = need·(0.3+cur̄)·surplus·(1+ln minds)·institution; p_discover/season = clamp01(0.01·pressure) (§17); season_tick rolls every TechGraph candidate; discovery lands as HELD knowledge (gnome add_knowledge + settlement record → full Phase-4 lifecycle). need_pressures & institution_factors are per-id INPUT dicts (environment/player phenomena author necessity — absent id = 0 need / 1.0 institution). INTERPRETIVE (documented in research.gd): natural log; minds = settlement's living adults+elders; discoverer = most curious capable mind (deterministic, tie by id).
- [x] T10.3 Tech effects — TechEffects: §17-exact K = base_K·Σrichness·(1+0.5·ag+0.3·constr) and war_strength = pop·(1+metal)·(0.5+lead); writing durability already shipped (T4.5, not re-implemented). INTERPRETIVE magnitudes (§13 names effects, not sizes; documented in tech_effects.gd): medicine −40% mortality/hardship, agriculture +30% fertility, metallurgy +30% work, construction +30% safety recovery; level() binary per settlement until T11.2 aggregates. PUBLIC API: Mortality.tick(+medicine_mult=1.0), Birth.season_tick(+fertility_mult=1.0) — defaults keep pre-tech behavior. DEFERRED consumers: work efficiency/shelter→T11.2 flows, war_strength→T11.4, sail/settlement unlocks→T11.x.
- [x] T10.4 Magic understanding ladder — mu += 0.0008·(0.3+cur̄)·exposure·science/day (§17), clamped; stages at §17 thresholds (0.3/0.5/0.7/0.85); prediction damp ×(1−0.6·mu) from 0.5; wards at resistance stage; can_defy → devout heretics reachable (faith untouched). INTERPRETIVE (documented in magic.gd): "Omen & Wonder" = §18 categories ⑤+⑦; ward strength ramps linearly 0.85→1.0 ↦ 0→0.7 ("up to 0.7"); mage BEHAVIOR (minor phenomena) beyond scope — stage gate only. PUBLIC API: Colony.magic_understanding (serializer covers), WorldState.wards, Influence.cast applies ward to intensity (tails too — same tile, same ward; reviewer catch), appraise_witnesses(+belief_impact_mult=1.0). DEFERRED: exposure/science inputs + Devotion.attribute's magic param get their live source at orchestrator wiring (T11.x/12); mage phenomena at T14/16.
- [x] Phase-Exit 10: drought can't teach irrigation before agriculture (gating), then necessity finds both in order; mu climbs superstition → prediction (omen impact drops, ward attempt fizzles) → resistance (first ward rises; warded cast lands at exactly ×(1−ward) vs open ground) → tagged phase-10-complete (351 tests, lint clean)

## 🎮 FUN CHECK 2 — Emergence: culture, prophets, tech & god-vs-mages (HUMAN — HALT)
- [x] Slice extended with Phase 9–10 systems — ungated omen button (documented playtest bypass: 6-gnome bands can't reach Tier IV), prophet seeding/preaching/corruption live, seasonal research (flat frontier need — slice glue), magic accrual + auto-ward at resistance, HUD reads prophets/creeds/schism/tech/mu/outliers.
- [x] Human GO recorded here — 2026-07-03, user: "GO ahead! (I again can't test but I'll test everything later in terms of gameplay)". Second waived gate: NO hands-on fun evidence exists yet — FUN CHECK 3 (the real playable build) is the first true fun evaluation; core-feel rework stays fully open there.

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

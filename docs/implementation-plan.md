# Gnome Colony — Implementation Plan (loop-ready, test-gated)

*Companion to: the design doc, evolution-algorithm spec (the math — the **single source of truth** for all formulas/values), setup-and-menus spec, prototype spec. This plan sequences the build into **phases → atomic tasks**, each with **tests written first**. It is designed to be executed by an autonomous agent loop (see the loop how-to doc), one task per iteration.*

---

## 0. How to consume this plan (the contract for the agent)

> **Read this section every iteration.** It is the operating contract.

1. **One task per iteration.** Find the **first unchecked task** in `PROGRESS.md` whose dependencies are all checked. Do **only that task**. Do not start a second.
2. **Test-Driven, always.** For the task: (a) write the listed tests **first**, (b) run them and watch them **fail**, (c) implement the minimum to make them **pass**, (d) run the **whole** suite to ensure no regressions.
3. **Definition of Done (DoD)** for every task: all listed tests pass **AND** the full suite is green **AND** `gdlint`/`gdformat` are clean **AND** the change is committed with message `T<id>: <summary>` **AND** the task is checked off in `PROGRESS.md` with a one-line note.
4. **Phase gate.** Do not start a new phase until that phase's **Phase-Exit Test** is green and committed.
   - **Playtest gates** (marked 🎮 between phases) are **human** go/no-go checks of *fun and emergence* — which automated tests CANNOT judge. The agent loop must **halt** at each (write `AWAIT_PLAYTEST.md` and stop) until a human records a GO. Green tests ≠ good game.
5. **If blocked** (a test can't be made to pass, a dependency is wrong, an ambiguity): first `git restore .` to discard your broken uncommitted edits (return to the last green commit), then write `STUCK.md` describing exactly what's blocking and what you tried, commit it, and **stop** (emit the STUCK sigil). Do not hack around the spec or delete failing tests to go green.
6. **Git discipline (mandatory).** One task = one **green** commit `T<id>: <summary>`; stage only that task's files; tag each phase gate `phase-<n>-complete`. Undo *committed* mistakes with `git revert` (never rewrite history, never force-push, never branch — keep it linear). Discard *uncommitted* mistakes with `git restore .` and retry. Read `git log --oneline` at iteration start to corroborate `PROGRESS.md`. (Full rules: CLAUDE.md / loop how-to §6.)
7. **Source of truth.** All numeric parameters, ranges, and formulas come from the **evolution-algorithm spec**, referenced as `[algo §X]`. Never invent a formula; if the spec is silent, write `STUCK.md`.
8. **Never violate the invariants** in §0.2.

### 0.1 Tooling & commands (set up in Phase 0; identical every run)
- Engine: **Godot 4.7** headless (`godot` on PATH). Language: **GDScript**.
- Unit tests: **GUT** (Godot Unit Test) in `res://test/`. Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit -gexit_on_success`. Green = exit 0.
- Lint/format: **gdtoolkit** (`pip install gdtoolkit`): `gdformat .` and `gdlint .` must be clean.
- Determinism: a single seeded RNG singleton (`Rng`); **all** randomness flows through it. Tests seed it and assert reproducible results.

### 0.2 Invariants (NEVER break — also in CLAUDE.md)
- **Sim inputs are defined & narrow:** `res://sim/` is plain data + logic with **zero** references to `Node`, scenes, or rendering. The sim's *only* inputs are seed, `WorldConfig`, player **influence acts**, and the player's focused-region **attention** (the Eye of God, design §2.4) — all via defined input channels. Graphics/audio/resolution/input devices never touch the sim.
- **Determinism (scoped):** all randomness flows through the `Rng` singleton (no `randi()/randf()`/`Time` in logic), so individual systems are reproducible under fixed inputs — the basis of the test suite. A **full run** is reproducible only from *seed + `WorldConfig` + recorded acts + recorded attention* (the Eye of God makes attention an input). There is **no single fixed world per seed** — and that's intended.
- **No silent scope changes:** don't refactor unrelated files, don't change public APIs other tasks depend on without updating `PROGRESS.md` notes, don't edit the read-only spec docs.
- **Small units:** functions do one thing; prefer pure functions in the sim core.
- **Tests are the gate:** never weaken or delete a test to pass. A red test means the code is wrong, not the test.

### 0.3 Task template (how each task below is written)
```
T<phase>.<n> — <title>
  deps: [T..]
  files: <paths to create/edit>
  do: <what to implement, with [algo §X] refs>
  tests (write first): <concrete assertions, in res://test/...>
  done: <extra acceptance criteria beyond DoD, if any>
```

---

## Phase 0 — Scaffold & test harness
**Goal:** an empty Godot project that runs headless, with GUT, lint, the `Rng` singleton, and CI all green. **Phase-Exit Test:** `test_smoke.gd` passes headless and `Rng` reproduces a fixed sequence from a seed.

- **T0.1 — Project skeleton.** files: `project.godot`, dir tree `sim/`, `sim/systems/`, `presentation/`, `test/`, `docs/` (copy the 4 specs here, read-only). do: minimal Godot 4.7 project that opens headless. tests: `test_smoke.gd` asserts `1+1==2` and that the project boots. done: `godot --headless --quit` exits 0.
- **T0.2 — Install GUT + test command.** files: `addons/gut/...`, `test/test_smoke.gd`. do: add GUT; document the run command in `README_DEV.md`. tests: smoke test discovered & run by GUT. done: GUT command exits 0.
- **T0.3 — Lint/format gate.** files: `.gdlintrc` (defaults). do: ensure `gdformat .`/`gdlint .` run clean on skeleton. done: both clean.
- **T0.4 — `Rng` singleton (seeded determinism).** files: `sim/rng.gd` (autoload). do: wrap `RandomNumberGenerator`; expose `seed_with(int)`, `randf()`, `randf_range`, `randi_range`, `gauss(mu,sd)`, `chance(p)`. tests: `test_rng.gd` — seeding with the same value yields identical sequences; different seeds differ; `gauss` mean≈mu over 10k draws. done: determinism proven.
- **T0.5 — `WorldConfig` resource.** files: `sim/world_config.gd`. do: a plain object holding seed + all tuning/world/founding fields with the defaults from the setup-and-menus spec. tests: construction with defaults; field ranges respected. 

## Phase 1 — Core data model & time
**Goal:** `GnomeData`, `Colony`, `TimeService`, enums exist and round-trip. **Phase-Exit Test:** build a `Colony` of 4, advance 100 ticks, assert time/calendar correct and state intact.

- **T1.1 — Enums & constants.** files: `sim/enums.gd`. do: `LifeStage`, trait keys, need keys, belief axes, knowledge categories [algo §1–§2,§9]. tests: enum values stable.
- **T1.2 — `GnomeData`.** files: `sim/gnome_data.gd`. do: full state & ranges [algo §1]; clamp helpers. tests: defaults in range; clamp works; id assignment.
- **T1.3 — `Colony` registry.** files: `sim/colony.gd`. do: id→gnome map, `next_id`, `living()`, aggregate vitals stubs [algo §5]. tests: add/remove; `living()` filters dead.
- **T1.4 — `TimeService`.** files: `sim/time_service.gd`. do: ticks/day=4, days/season=24, seasons/year=4; `advance(dt)`, day/season/year accessors, pause/speed [algo §0]. tests: tick→day→season→year rollover exact; speed scaling.
- **T1.5 — Serialization round-trip (data only).** files: `sim/serializer.gd`. do: `to_dict/from_dict` for `GnomeData`,`Colony`,`WorldConfig`. tests: round-trip equality on a populated colony.

## Phase 2 — Life cycle
**Goal:** gnomes age, change stage, and die (age + hardship); events fire. **Phase-Exit Test:** seeded 50-year run; lifespans fall within `[algo §4]` bounds and every death emits one event.

- **T2.1 — `EventBus`.** files: `sim/event_bus.gd` (autoload, signal-based). do: signals `born, gnome_died, stage_changed, knowledge_lost, belief_formed, phenomenon`. tests: emit/receive; payload shape.
- **T2.2 — Aging & stage transitions.** files: `sim/systems/aging.gd`. do: age by dt; stage bands [algo §4]; emit `stage_changed`. tests: exact band thresholds; event on crossing.
- **T2.3 — Mortality.** files: `sim/systems/mortality.gd`. do: Gompertz age curve + hardship + accident [algo §4]. tests (seeded): negligible deaths pre-Elder; rising after; hardship raises rate; emits `gnome_died`.
- **T2.4 — Birth scaffold.** files: `sim/systems/birth.gd` (placeholder spawn; full logic in Phase 5). do: spawn an Infant into colony, emit `born`. tests: born event; infant in range.

## Phase 3 — Needs & utility decision
**Goal:** gnomes self-direct via needs + utility. **Phase-Exit Test:** a hungry colony with a food source recovers (mean hunger falls) over seeded ticks with no scripting.

- **T3.1 — Needs decay.** files: `sim/systems/needs.gd`. do: per-need decay × stage mod [algo §3]; clamp. tests: decay rates; stage modifiers; clamp at 1.
- **T3.2 — Action catalog.** files: `sim/actions.gd`. do: action defs with `relief` vectors + stage gates [algo §6]. tests: catalog completeness; gate correctness.
- **T3.3 — Utility scoring.** files: `sim/systems/utility.gd`. do: `score(a)=Σ need²·relief·mods + jitter` [algo §6]. tests: hunger=1 ⇒ `eat` wins; need² weighting (urgent dominates); jitter bounded; deterministic under seed.
- **T3.4 — Decide & act loop.** files: `sim/systems/decide.gd`, `sim/systems/act.gd`. do: pick max action; apply relief; side-effects. tests: chosen action applied; needs move correctly.
- **T3.5 — Hardship link.** files: edit `mortality.gd`. do: sustained hunger/safety≥0.9 → mortality bonus [algo §3–§4]. tests: starvation eventually kills (seeded).
- **T3.6 — Projects (multi-tick goals).** files: `sim/systems/projects.gd`. do: a chosen long-horizon goal (explore/build/master) persists across ticks until done/abandoned, not re-decided each tick [algo §6]. tests: a started project persists and completes; isn't dropped while a transient need spikes mildly.

## Phase 4 — Skills, knowledge, teaching, extinction
**Goal:** knowledge (incl. tech/magic later) is taught, decays, and can go extinct; writing makes it durable. **Phase-Exit Test:** seeded scenario where the sole holder of a skill dies untaught ⇒ extinction event; with writing present ⇒ no extinction.

- **T4.1 — Proficiency & practice.** files: `sim/systems/skills.gd`. do: practice asymptote [algo §7]. tests: gain curve approaches 1; rate matches.
- **T4.2 — Teaching transfer.** do: learner←teacher convergence; gains id at prof≥0.2 [algo §7]. tests: convergence; id acquired; teachable onward.
- **T4.3 — Decay & un-teachable.** do: unused decay; drop below 0.2 loses teachability [algo §7]. tests: decay; threshold behavior.
- **T4.4 — Extinction (per-settlement).** files: `sim/systems/knowledge.gd`. do: when no living holder ≥0.2 **in a settlement** ⇒ remove id *there*, emit `knowledge_lost` [algo §7]. (Early phases have one settlement, so equivalent; Phase 11 generalizes to regional dark ages + re-spread.) tests: last-holder death ⇒ extinction event; writing exempts (T4.5).
- **T4.5 — Writing durability.** do: `writing` snapshots ids to durable records, exempt from extinction [algo §7]. tests: with writing, no extinction on holder death; re-teachable from record.

## Phase 5 — Relationships, reproduction, genetics  *(= prototype Milestone 1)*
**Goal:** bonds, partnerships, births, inheritance → self-perpetuating generations. **Phase-Exit Test (Milestone 1):** a 4-gnome colony under **default** `WorldConfig` survives **≥5 generations** across **20 seeded runs** without dying out >40% of the time, with a readable generational text log.

- **T5.1 — Relationship edges.** files: `sim/systems/social.gd`. do: typed weights, interaction updates, decay, compat from trait similarity [algo §8]. tests: weight dynamics; compat.
- **T5.2 — Partnership.** do: mutual mate-weight≥0.6 + culturally permitted ⇒ pair [algo §8]. tests: pairing gate.
- **T5.3 — Fertility & births.** files: edit `birth.gd`. do: per-season birth chance × food × (1−crowding) [algo §8]. tests (seeded): birth rate in expected band; gated by food/crowding.
- **T5.4 — Genetic inheritance.** do: child trait = blend + N(0,0.05), rare large mutation [algo §8]; skills NOT inherited. tests: child within mutation band of parent mean; skills start empty; rare-large frequency.
- **T5.5 — Trait plasticity.** files: edit `aging.gd`/new `culture.gd` stub. do: young drift toward caregiver/culture means [algo §2]. tests: child trait moves toward env mean while young, ~stops at Adult.
- **T5.7 — Outlier births (divergence engine).** files: `sim/systems/outliers.gd`. do: per birth, `p_outlier` chance to roll a Genius/Touched/Mutant/etc. with out-of-band (mutants: heritable) traits [algo §8]. tests (seeded): outliers occur at expected rate; mutant trait can exceed [0,1] band and is heritable; touched have high prophet-ripeness.
- **T5.6 — Milestone integration test.** files: `test/integration/test_milestone1.gd`. do: the Phase-Exit Test above; emit a generational summary. done: passes the survival bar.

## Phase 6 — Culture & belief (hybrid)
**Goal:** scalar feelings propagate and crystallize into named beliefs that bite behavior. **Phase-Exit Test:** seeded scenario crystallizes a place-`taboo`; gnomes' utility for acting there drops (avoidance).

- **T6.1 — Scalar substrate.** files: `sim/systems/belief.gd`. do: per-(subject,axis) feelings, appraisal write + habituation + decay [algo §9]. tests: write/decay; susceptibility by trait.
- **T6.2 — Batched propagation.** do: each tick (daily), edge transfer; fear ×1.5 [algo §9]. tests: convergence; fear faster.
- **T6.3 — Crystallization.** files: `sim/belief_object.gd`. do: threshold+holders+duration ⇒ spawn taboo/rite/place-reverence/theology; strength formula [algo §9]; emit `belief_formed`. tests: crystallize at threshold; not below; strength.
- **T6.4 — Behavioral effects.** do: taboo/place-tag → `belief_mod` penalty in utility; blessed → bonus [algo §6,§9]. tests: cursed tile lowers act score; blessed raises.
- **T6.5 — Drift & subcultures.** do: transmission mutation; belief-vector clustering ≥0.5 ⇒ subculture [algo §9]. tests: drift occurs; cluster split detected.

## Phase 7 — Influence system: phenomena & appraisal  *(= prototype Milestone 2)*
**Goal:** one phenomenon flows through the full pipeline. **Phase-Exit Test (Milestone 2 + iron-irony):** a seeded `landslide` kills some, exposes `iron`, frightens witnesses; a `cursed` tag crystallizes; surviving gnomes then **avoid** the iron tile.

- **T7.1 — Phenomenon schema.** files: `sim/phenomenon.gd`. do: data shape (category, valence, taint, **target**, base_intensity, event_drama, tier, effects axes, affordance_req, chain_hooks, tail_risk) [algo §11]. tests: schema validation; `social` accepts a number **or** `=culture`; `target` validates against the allowed kinds.
- **T7.2 — Phenomenon runner + stimulus.** files: `sim/systems/influence.gd`. do: apply world-state mutation + emit `phenomenon` stimulus; magnitude×social-mass stub (1.0 until Phase 8) [algo §11]. tests: world mutated; stimulus emitted.
- **T7.3 — The `landslide`.** files: `sim/phenomena/landslide.gd`. do: deplete site, expose `iron`, casualties, bury path [algo §11,§3.4 design]. tests: kills (seeded), reveals iron, blocks path.
- **T7.4 — Appraisal.** do: per witness, write feelings via trait susceptibility; curious→discovery memory, timid→fear [algo §11]. tests: curious vs timid diverge on same event.
- **T7.5 — Tail-risk & chaining.** do: 0.03 tail-risk roll; chain_hook rolls [algo §11]. tests (seeded): tail fires at expected frequency over N; chain triggers child phenomenon.
- **T7.7 — Phenomenon valence + toolbox balance.** files: edit `sim/phenomenon.gd`, `docs/` content. do: add a `valence` field (benevolent/malevolent/neutral); ensure the authored phenomenon set is balanced across valences within each category and overall [algo §11, design §3.1]. tests: schema carries valence; a content test asserts the per-category and overall valence counts are within balance tolerance.
- **T7.8 — Seed catalog loader.** files: `sim/phenomena/catalog/*.tres` (or data), `sim/systems/influence.gd`. do: load the **15 seed phenomena** [algo §18] as data; wire affordance gating + chain_hooks. tests: all 15 load & validate; valence spread matches (4 ben / 7 mal / 4 neutral); each affordance/chain resolves; each entry's `target` matches §18's index.
- **T7.9 — Culture-resolved social + boon taint.** files: `sim/systems/influence.gd`. do: `social: =culture` ⇒ `social_effect = swing·(cohesion − fear − fracture)`; `taint` flags tainted-boon side-effects/chains [algo §11,§18]. tests: same disaster bonds a cohesive colony and fractures a divided one; a tainted boon fires its uncanny cost while a clean one doesn't.
- **T7.6 — Iron-irony integration.** files: `test/integration/test_iron_irony.gd`. do: the Phase-Exit Test. done: avoidance demonstrated.

## Phase 8 — Devotion & social mass
**Goal:** devotion drives unlocks and magnitude. **Phase-Exit Test:** rising belief raises `D`; a tier unlocks at its threshold; the same phenomenon's magnitude grows sub-linearly with `D`.
- **T8.1 — Devotion compute.** files: `sim/systems/devotion.gd`. do: `D=Σ faith`, flavor=mean(awe−fear) [algo §10]. tests: grows with belief+pop; flavor sign.
- **T8.2 — Tier unlocks (per-capita, ratcheting).** do: category availability gates on **peak per-capita devotion `d̄_peak`** + population/era floors; once unlocked, stays [algo §10]. tests: unlock at exact `d̄` thresholds; a population spike that lowers current `d̄` does **not** re-lock; floors enforced.
- **T8.3 — Social-mass magnitude + valence potency.** do: `magnitude=base·(1+k·log10(1+M))·valence_potency`, with malevolent ×(1+δ), benevolent ×(1−δ) [algo §10–§11]; wire into influence runner. tests: monotonic, sub-linear in M; a malevolent act nets more effect than an equivalent benevolent one (the temptation).
- **T8.4 — Terror instability + secularization.** do: terror-flavor → unrest + faster heresy/schism hooks; love-faith stable/compounding; mild devotion drift vs science [algo §10]. tests: terror raises unrest & instability (not power); love-devotion is more stable; secular drift small.
- **T8.5 — Attribution seed (bootstrap).** files: `sim/systems/devotion.gd`. do: dramatic/inexplicable events write small belief toward "an unseen will" scaled by drama and inversely by magic-understanding [algo §9]. tests: from zero belief, a cataclysm raises `D`; high magic-understanding suppresses it.
- **T8.6 — Notability growth.** files: `sim/systems/notability.gd`. do: notability rises from deeds/survival/mastery/eldership/many-descendants/prophet-leader status; slow decay [algo §14]. tests: a deed raises notability; it decays over time; drives LOD promotion + leader_score.

## 🎮 PLAYTEST GATE 1 — Vertical Slice & Fun Check  *(human go/no-go — HALT here)*
**Stop. Build a throwaway, minimal interactive view** (a simple top-down render of the colony + buttons to trigger the 2–3 unlocked phenomena + a mood/belief readout) — *not* the real presentation layer (Phases 13–15), just enough to **play**. Then a human plays and judges what tests can't:
- Is the core fantasy fun: nudge → watch the colony respond → a belief forms → consequences ripple?
- Can you *feel and attribute* your influence, or does it feel like watching an aquarium?
- Do emergent beliefs read as *meaningful*, or as noise?
**GO** → the loop is fun; proceed to Phase 9. **NO-GO** → stop and rework the core feel before building more systems. (This is the cheapest moment to learn the game isn't fun — validates review A2/B3.)

## Phase 9 — Prophets
**Goal:** seeded-via-omen, uncontrollable, schism-capable. **Phase-Exit Test:** a prophet only catches when conditions are ripe; rival prophets produce a schism; spamming fractures faith.
- **T9.1 — Prophet entity & seeding.** files: `sim/systems/prophet.gd`. do: flag a gnome via omen; ripeness gate (local |awe−fear|≥0.5) [algo §12]. tests: catches only when ripe.
- **T9.2 — Charisma, reach, amplification.** do: hidden charisma; BFS reach ∝ charisma; forced crystallization of message [algo §12]. tests: reach scales; mass crystallization.
- **T9.3 — Life-arc & corruption.** do: rise/peak/decline; corruption roll flips message [algo §12]. tests (seeded): arc shape; flip frequency.
- **T9.4 — Rivals & schism.** do: competing messages ⇒ schism; spam ⇒ fracture/unrest [algo §12]. tests: schism on two strong rivals; spam fractures.

## Phase 10 — Technology & magic discovery
**Goal:** autonomous research; magic = studying you. **Phase-Exit Test:** prereqs gate discovery; environmental pressure raises discovery rate; reaching the magic thresholds unlocks prediction then wards; a warded tile reduces incoming phenomenon intensity.
- **T10.1 — Knowledge graph & prereqs.** files: `sim/tech_graph.gd`. do: ids with prereqs; tech-as-knowledge (reuse Phase 4) [algo §7,§13]. tests: prereq gating.
- **T10.2 — Discovery process.** files: `sim/systems/research.gd`. do: pressure() and per-season p_discover [algo §13]. tests (seeded): pressure raises rate; population/surplus factors.
- **T10.3 — Tech effects.** do: apply parameter deltas/unlocks (agriculture, writing, metallurgy, medicine, construction, sail) [algo §13]. tests: each effect applied (e.g., agriculture raises K; medicine lowers mortality `a`).
- **T10.4 — Magic understanding ladder.** do: `magic_understanding` accrual; thresholds → prediction (omen/wonder impact ×(1−0.6·mu)), harnessing (mages), resistance (wards), heretics [algo §13]. tests: thresholds unlock stages; prediction reduces omen impact; ward reduces intensity; devout-heretic state reachable.

## 🎮 FUN CHECK 2 — Emergence: culture, prophets, tech & the god-vs-mages arc  *(human go/no-go — HALT)*
Extend the slice with the now-built belief/devotion/prophet/tech/outlier systems and play several generations. Judge: do **prophets** create memorable swings? Does the **theology-about-you** feel like a relationship? Is the **magic→prediction→wards** co-evolution compelling? Do **outliers** (geniuses/touched/mutants) produce interesting divergence rather than chaos? Is the **shepherd vs tyrant** choice live and balanced? **GO/NO-GO**, then tune before scaling.

## Phase 11 — Hierarchical simulation (scale)
**Goal:** individual↔settlement↔civilization tiers reach tens of thousands. **Phase-Exit Test:** a 10,000-population world advances a year within the ⚙️ perf budget below; settlement-aggregate population matches an equivalent individually-simulated control within tolerance.
> **Perf budget ⚙️ (mid-tier desktop reference):** avg sim tick ≤ **10 ms @ pop 5k** · ≤ **16 ms @ pop 20k** (≤ 300 quickened) · 1× render ≥ 60 fps at Kingdom scale · save ≤ 2 s / load ≤ 5 s · sim-side RAM ≤ ~2 GB @ 20k. If missed: profile, then port hot paths (design §2.2) — never silently lower the bar. [algo §14]
- **T11.1 — LOD manager.** files: `sim/systems/lod.gd`. do: promote/demote by **attention**/notability/budget [algo §14] (attention supplied as a scripted input headless — dwell/hysteresis applied upstream, design §2.4). tests: promotion/demotion thresholds; LOD-0 cap.
- **T11.2 — Settlement tier.** files: `sim/settlement.gd`, `sim/systems/settlement_sim.gd`. do: aggregate vitals + flow equations (births/deaths/migration/research/culture); **per-settlement knowledge** with regional extinction & re-spread via trade/migration; `K` formula [algo §14, §7]. tests: flows conserve population vs individual control (tolerance); crowding from K; a craft lost in one settlement survives in another and can re-spread.
- **T11.3 — Promotion fidelity.** do: materialize/dematerialize individuals consistently (no state loss) [algo §14]. tests: promote→demote round-trip preserves aggregate.
- **T11.6 — Emergent leadership.** files: `sim/systems/leadership.gd`. do: each settlement's leader = highest `leader_score`; `leadership_quality` feeds coordination/institutions/migration/war [algo §14]. tests: leader is the top-scorer; quality affects war_strength.
- **T11.4 — Civilization tier.** files: `sim/systems/civilization.gd`. do: migration to best basin, trade, schism, war triggers/outcomes [algo §14]. tests: migration choice; trade spreads knowledge; schism at belief-distance; war at threshold; war is a mortality+belief event.
- **T11.5 — Scale/perf test.** files: `test/integration/test_scale.gd`. do: the Phase-Exit perf+consistency test. done: within budget.

## Phase 12 — Persistence & determinism
**Goal:** full save/load + reproducibility. **Phase-Exit Test:** same seed+config+**recorded inputs (acts + attention)** produce identical run-hash twice; save→load→continue equals an uninterrupted run under the same recorded inputs.
- **T12.1 — Full serializer.** do: Colony + belief/culture graph + world region-graph + config + RNG state [algo §8 spec, setup spec]. tests: round-trip equality on a rich late-game state.
- **T12.2 — Determinism harness (input-scoped).** files: `test/integration/test_determinism.gd`. do: with a **fixed recorded input + attention script**, hash key state after N ticks; assert identical across two runs [design §2.4]. tests: stable hash under fixed inputs; flags stray non-`Rng` randomness. (Run-level reproducibility is *not* claimed from seed alone — only from seed + recorded acts + attention.)
- **T12.3 — `WorldConfig` ingestion.** do: world-gen + sim honor every option/preset [setup spec §3–§5]. tests: presets produce expected param sets.

## Phase 13 — Presentation: world, puppets, camera
**Goal:** the sim becomes visible without the sim knowing. **Phase-Exit Test (manual+auto):** puppets reflect `GnomeData`; heightmap matches region-graph; camera zooms civ→settlement→individual; navmesh path found.
- **T13.1 — Region-graph → heightmap skin.** files: `presentation/world_view.gd`. do: bake mesh from region-graph; re-bake on reshape [design §2.7b]. tests: mesh reflects graph; reshape updates.
- **T13.2 — `GnomePuppet`.** files: `presentation/gnome_puppet.gd`. do: a scene that reads a `GnomeData` and renders/animates; pooling. tests: puppet mirrors data; pool reuse; **no sim file imports presentation** (assert via lint/grep test).
- **T13.3 — NavMesh for LOD-0.** do: bake navmesh; `NavigationAgent3D` for materialized gnomes. tests: path exists between two points; blocked by buried path.
- **T13.4 — Camera & three-zoom lens.** files: `presentation/camera_rig.gd`. do: civilization→settlement→individual zoom [design §1.7c]. tests: zoom-level transitions.
- **T13.5 — Attention input (the Eye, dwell-based).** files: `presentation/attention.gd`. do: derive attention from the camera per the dwell rules (dwell ≥ 2 s ⚙️; radius by zoom; release-hysteresis ~10 s ⚙️; never at civilization zoom); route it as the sim's attention input; record sparse `[t, region, radius]` segments [design §2.4]. tests: pan-past never promotes; dwell promotes; release after hysteresis; civilization zoom never promotes; a recorded attention stream replays identically.

## Phase 14 — Influence UI & feedback layer
**Goal:** the player can act and read consequences. **Phase-Exit Test:** category controls appear/lock by devotion tier; an aftermath panel reflects a phenomenon's outcomes.
- **T14.1 — Phenomenon controls (7 categories, tier-gated).** files: `presentation/ui/influence_panel.gd`. do: buttons per category, gated by **`d̄_peak`** tier; **act targeting** — paint the point/area/settlement/region-edge/individual per the phenomenon's `target` field [design §3.1, algo §10–§11]. tests: gating matches thresholds; each target kind routes the correct selection to the runner.
- **T14.2 — Feedback/hindsight.** files: `presentation/ui/aftermath.gd`. do: affected-area highlight, "what they now believe / who they think you are", cascade timeline [design §2.7]. tests: panel reflects emitted events.
- **T14.3 — Heatmaps + faint codex.** do: mood/belief heatmaps; codex of faint impressions [design §3.8]. tests: heatmap reads substrate; codex accrues impressions only (no exact data).
- **T14.4 — Diegetic ambience & act feedback.** files: `presentation/audio/ambience.gd`. do: ambience layers read world/sim state (weather, season, local mood; silence as an instrument); act feedback is **strictly diegetic** — no UI stingers or confirmation sounds [design §2.7c]. tests: ambience params track state; casting an act triggers no UI-layer audio.

## 🎮 FUN CHECK 3 — The real playable build & engagement  *(human go/no-go — HALT)*
With real presentation + influence UI + feedback layer, address review **B3 directly**: a steady cadence of *meaningful decisions* (not long passive fast-forwards)? Are consequences **attributable** via the feedback/aftermath layer? Does the player feel like an agent, not a spectator? Are both tyrant and shepherd playstyles engaging? **GO** → polish/menus; **NO-GO** → fix the feedback loop and cadence first.

## Phase 15 — Menus & setup
**Goal:** front end complete. **Phase-Exit Test:** New Game wizard emits a correct `WorldConfig`; Load lists saves; Settings persist and never alter sim.
- **T15.1 — Main menu.** files: `presentation/ui/main_menu.gd` [setup §6]. tests: entries; Continue hidden when no save.
- **T15.2 — New Game wizard.** files: `presentation/ui/new_game/*` [setup §1–§5]. do: presets + sliders + world + founding → `WorldConfig`. tests: each preset/slider maps to the spec'd params; Quick Start path.
- **T15.3 — Load Game.** files: `presentation/ui/load_menu.gd` [setup §6.1]. tests: lists saves with metadata; load restores.
- **T15.4 — Settings (global).** files: `presentation/ui/settings/*`, `user://settings.cfg` [setup §7]. do: graphics (incl. **Render Crowd Density**), audio, controls, accessibility. tests: persist to cfg; **graphics settings change only what's drawn, not the sim** (assert the sim hash is unchanged across two Render-Crowd-Density values, with attention fixed). Note: the sim-affecting *quicken budget* lives in `WorldConfig`, not here.
- **T15.5 — Chronicle & world's end.** files: `presentation/ui/chronicle.gd`. do: on `world_ended` (total extinction — algo §14), hold on the empty world a beat, then the **Chronicle** screen generated from run telemetry (generations, settlements, faiths, prophets, wars, discoveries, how it ended); main-menu **Chronicles** list; export [design §1.9, setup §6, T16.3]. tests: extinction emits `world_ended`; chronicle contains the required fields; menu lists past chronicles.

## 🎮 PLAYTEST 4 — Onboarding & full flow  *(human go/no-go)*
New-game wizard, presets, and a new player's first ~30 minutes. Judge: is it **learnable** without a manual? Do the presets deliver distinct, good experiences? Does the difficulty curve (devotion ramp, first crisis) land? **GO** → final integration & balance (Phase 16).

## Phase 16 — Integration, balance & polish
**Goal:** a full epochal run holds together and respects the tuning invariants. **Phase-Exit Test:** a long seeded run from 4 gnomes reaches a multi-settlement civilization without crash or unbounded runaway, and the invariant tests pass.
- **T16.1 — Epochal smoke run.** files: `test/integration/test_epochal.gd`. do: fast-forward a default game across many generations; assert no crash, population bounded, tech advances. 
- **T16.2 — Tuning-invariant tests.** files: `test/integration/test_invariants.gd`. do: early game recoverable from one bad season; no loop runs away unbounded in a session; extinction frequency within band [algo §16]. 
- **T16.5 — Diversity & balance invariants.** files: `test/integration/test_diversity_balance.gd`. do: (a) **diversity floor** — population trait variance must not collapse below a floor over N generations [algo §2,§8]; (b) **playstyle balance** — scripted tyrant vs shepherd runs should both stay viable with the intended *trade-off*: the tyrant shows **higher per-act effect but higher instability** (unrest/heresy/schism/collapse), the shepherd **lower instability and higher *sustained* devotion** — neither strictly dominating [algo §10–§11, design §3.1]. tests: variance floor holds; tyrant has higher instability AND higher per-act potency; shepherd has higher sustained devotion & stability; both survive.
- **T16.3 — Telemetry hooks.** do: optional run-summary export (generations, peak pop, techs, schisms, wars) for balancing. tests: summary fields present.
- **T16.4 — Final pass.** do: full suite green, lint clean, `PROGRESS.md` all checked, `DONE.md` written. done: emit the project-complete sigil.

---

## Appendix A — `PROGRESS.md` seed (the agent maintains this)
Generate `PROGRESS.md` as a checklist mirroring every `T<id>` above, in order, each line `- [ ] T<id> <title>`, grouped by phase, with a "Phase-Exit" checkbox per phase. The agent checks items off only when their DoD is met.

## Appendix B — Ordering rule
Phases are strictly ordered 0→16. **Phases 0–7 are headless** (no rendering) and contain the riskiest logic — get them rock-solid first. Presentation (13–15) depends only on the sim's public read API, never the reverse. If a presentation task tempts you to add a method to the sim, that method belongs to a sim task — record it and add it there.

## Appendix C — Definition of "one-shot complete"
The project is complete when: every `T<id>` is checked, every Phase-Exit Test and all integration tests (`test_milestone1`, `test_iron_irony`, `test_scale`, `test_determinism`, `test_epochal`, `test_invariants`, `test_diversity_balance`) are green, lint is clean, and `DONE.md` summarizes the build. Only then emit the completion sigil.

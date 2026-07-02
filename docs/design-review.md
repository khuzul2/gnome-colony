# Gnome Colony — Design Review v1 (issues & proposed adjustments)

> **RESOLUTION (applied, two rounds):** all findings below were decided and folded into the specs — design → **v1.3**, algorithm → **v1.2**, plus setup/prototype/plan/how-to.
>
> *Round 2* additionally fixed seams the round-1 edits opened and rebalanced tyranny: **devotion decoupling fully propagated** (depth/per-capita *unlocks*, ratcheting on peak so growth never strips powers; total weight scales *magnitude*); an **attribution seed** so belief-in-you bootstraps from zero (scaled inversely to magic-literacy); **notability growth** defined (it drives LOD + leadership); **outlier traits exempt from plasticity** so divergence isn't washed out; need-decay retuned for the 1-tick/day grain; and the **tyranny rebalance** — *bad tools now net **more** effect per use (valence potency, +δ)* as the temptation, balanced by terror-faith's **instability** (unrest/heresy/schism/collapse), while good tools are gentler but build **stable, compounding** devotion. Evil is tempting, not dominant; good is viable, not under-armed. *Round 3* was a **numbers pass**: a coherence check through the actual loops caught four values that didn't survive the arithmetic — the **attribution seed** would saturate faith from one act (added `α=0.25`), **feeling decay** was unbounded (made proportional + concrete habituation), **fertility** was ~8× too high (0.4→0.15/season), and **unrest had no quantified effects** (now productivity/schism/fracture). All knobs are pinned in **algorithm §17** with documented derived sanity figures. Key calls: **A1** — *embraced*, not avoided: the "Eye of God" (focusing on an area quickens those gnomes and **changes their fate by design**); determinism is now scoped to the RNG + recorded session, not "one world per seed." **A2** — four 🎮 human playtest/fun gates inserted in the plan. **B1** — diversity preserved via **outlier gnomes** (geniuses/touched/mutants) + assortative mating + biome attractors + a diversity-floor test. **B2** — balanced via even good/evil/neutral *availability* plus a deliberate asymmetry: malevolent acts hit harder (potency +δ) but terror-faith is unstable; good is gentler but sustainable. **C/D** — calendar, devotion-tier metric, per-settlement extinction, leadership, and gaps all fixed. This document is retained as the record of *why*.

---

*A deliberately critical pass over the six spec docs (design v1.1, evolution-algorithm, setup-and-menus, prototype, implementation-plan, loop-howto). Goal: surface real problems and propose fixes. Issues are ordered by how much they matter, tagged 🔴 critical / 🟠 high / 🟡 calibration / ⚪ gap. Each lists the problem, why it matters, a proposed adjustment, and which docs change.*

**Overall:** the design is coherent and unusually complete, but two things genuinely threaten it — a determinism/architecture contradiction, and the absence of any early "is it actually fun?" gate in a very large, bottom-up build. Most other issues are side-effects of the late **200+ → tens-of-thousands** scale jump (it broke several numbers that were calibrated for hundreds) and are fixable with re-calibration. Nothing here is fatal; several are important.

---

## A. Critical

### A1 🔴 Camera-driven LOD promotion breaks determinism *and* the sim/presentation split
**Problem.** Design §2.4 and algorithm §14 both say individuals "**promote** to LOD-0 (full appraisal & utility) **when the player zooms in**" and abstract gnomes "materialize only when looked at." But LOD-0 (full per-gnome sim) and LOD-2 (statistical batch) will **not** produce identical outcomes. So *where the player points the camera changes the simulation's trajectory*. That violates two things we locked elsewhere: the **sim/presentation separation** invariant (presentation must never affect sim) and **seeded determinism** ("same seed + config ⇒ identical run", relied on by plan T12.2, T15.4, and the setup doc's claim that *Simulation Detail changes only what's drawn, never the outcome*). As written, the spec contradicts itself.

**Why it matters.** Determinism is the backbone of the whole test strategy (the implementation plan leans on it for nearly every assertion) and of shareable seeds. Silently coupling sim fidelity to the camera makes runs unreproducible and bugs un-isolable — exactly what an autonomous build loop cannot afford.

**Proposed adjustment.** Split the two concepts cleanly:
- **Simulation LOD** (what is computed) is driven by **in-world notability + a fixed deterministic budget**, *never* by the camera. A gnome is promoted to full individual sim only on a deterministic trigger (becomes a prophet/leader, notability ≥ threshold, part of a tracked lineage), independent of where you look.
- **Render LOD** (what is drawn) is camera-driven and **presentation-only**. Zooming into a statistical settlement instantiates **read-only visual puppets sampled from the already-running aggregate state**; their rendered micro-behaviour never feeds back into the aggregate. You *watch* what the sim chose to detail; you don't *cause* it to detail by looking.
- Consequence to accept: you can't force a random villager into full fidelity just by staring at them. That's a fair price for reproducibility.
**Affects:** design §2.4, algo §14; align setup §7.1 wording; the determinism invariant in plan/CLAUDE.md is now actually honoured.

### A2 🔴 No "is it fun?" gate; tests verify mechanics, not emergence; scope is enormous for a one-shot loop
**Problem.** The plan builds bottom-up across 17 phases; the first *playable* artifact appears only around Phase 13+. Milestone 1 is a text log; Milestone 2 is one landslide. Meanwhile the game's entire value is **emergent qualities** (interesting cultures, stories, the god-vs-mages arc) that **automated tests cannot capture** — you can test "teaching raises proficiency", you cannot test "the emergent religion was compelling." So "all tests green" ≠ "good game," yet the loop treats green tests as success.

**Why it matters.** You could spend the whole build grinding 17 phases of correct mechanics and only discover at the end that the core fantasy isn't fun to play, or that emergence produces grey mush (see B1). That's the most expensive possible way to find out.

**Proposed adjustment.**
- Insert an explicit **Vertical Slice milestone right after the headless sim (≈ end of Phase 7→8)**: a *minimal but actually playable* build — small colony, ~3 phenomena, basic belief + devotion, a rough visualization — whose sole purpose is a **human playtest of the core fantasy** before Phases 9–16 are built. Add a hard **go / no-go "fun gate"** there.
- State plainly in the plan & how-to that the test suite guarantees *correctness, not fun or emergence*, and require **human playtest sign-off** at the slice and after each major emergent system (belief, prophets, tech/magic).
- Consider making the **first shippable target smaller** (e.g., "Kingdom" scale, a subset of phenomena) and treating tens-of-thousands / the full civilization tier as a **later expansion**, not v1.
**Affects:** implementation plan (new milestone + gate + scope note), loop-howto (expectations), design (status/scope).

---

## B. High-impact design / balance

### B1 🟠 Blending inheritance + plasticity-toward-the-mean will erode the diversity the game is built on
**Problem.** Trait inheritance is `child = average(parents) + N(0, 0.05)` [algo §8] and plasticity drifts the young **toward the environment/culture mean** [algo §2]. Both are **mean-reverting**. Classic blending inheritance (the pre-Mendelian problem) plus small mutation plus pull-to-the-mean tends to **collapse trait variance** over generations — everyone converges to ~0.5. But the design *sells* divergent temperaments and distinct subcultures.

**Why it matters.** If variance washes out, subcultures become cosmetic, "evolving temperament" flattens, and the emergent-society promise quietly dies a few generations in.

**Proposed adjustment.** Add counter-forces and a guard:
- Lean on **assortative mating** (compat already rises with trait similarity — strengthen it; like pairs with like, preserving clusters).
- Make **biome biases persistent attractors** (an ongoing pull per region), not one-time nudges — geography then *maintains* divergence against blending.
- Increase effective mutation (slightly higher sd and/or a higher rare-large-mutation rate), and reduce plasticity strength.
- Optionally model each trait as **a couple of discrete alleles + a continuous modifier** to avoid pure-blend washout.
- Add a **diversity-floor invariant test** (population trait variance must not fall below a floor over N generations) — make erosion a *failing test*, not a silent drift.
**Affects:** algo §2, §8; plan (new invariant test in Phase 16/T16.2).

### B2 🟠 Tyranny is probably the dominant strategy; the "shepherd vs tyrant" choice may collapse
**Problem.** Devotion is morally neutral and is the power currency; **terror-devotion is far cheaper to generate** than love (disasters reliably manufacture fear; cultivating genuine faith needs careful boons + answered prayers + good timing). The only brake is `unrest += 0.02·(−flavor_balance)·M` [algo §10]. If that brake is weak relative to the power gained, the optimal play is "terrorize for fast devotion → fast power," and the benevolent path is strictly dominated.

**Why it matters.** It guts the headline moral-choice richness ("what god you become is their story") into "tyranny is just better."

**Proposed adjustment.** Make terror a genuine long-run liability so benevolence is competitive:
- Terror should **accelerate heretic/resistance/magic-defiance emergence** and **raise schism & collapse probability** (tie §13 resistance and §14 schism/war strongly to sustained terror).
- Terror-devotion should **decay faster and cap lower** than love-devotion; love compounds into stability and a **higher ceiling**.
- Target balance: *tyranny = fast but fragile and self-limiting; shepherd = slower but stable with a higher long-run ceiling.* Neither strictly dominates.
- Add a **balance test** comparing two scripted playstyles' long-run trajectories (power, stability, survival).
**Affects:** algo §10, §13, §14; plan (balance test).

### B3 🟠 Engagement risk: indirect control + long, hard-to-attribute feedback = "spectator, not player"
**Problem.** Every loop is: nudge → wait (often many fast-forwarded minutes) → an emergent, *delayed*, hard-to-attribute consequence. With 15–30-min lifespans and generational payoffs, the causal thread from "I caused a drought" to "they founded a drought-cult and invented irrigation" can be very long and faint. This is the classic god-game/ant-farm engagement trap we flagged at the very start, and the mechanics don't obviously solve it.

**Why it matters.** If the player can't *feel* their agency and *attribute* outcomes, the game is something you watch, not play — the difference between a toy and a game.

**Proposed adjustment** (design direction, not a single number):
- Guarantee every act an **immediate, legible local reaction** (visible fear/awe/scramble), even when the deep effects are delayed.
- Make the **aftermath/feedback layer draw the causal chain explicitly** (act → appraisal → behaviour → belief), with a timeline, so consequences are *attributable*.
- Give a **steady cadence of meaningful decisions** — surface emergent crises and prophet/omen beats that *invite* action — so play isn't long passive fast-forwards punctuated by rare clicks.
- Add a **"notable events" feed** that pulls the eye to consequences worth reacting to.
**Affects:** design §2.7/§3.8 (feedback layer emphasis), plan Phase 14 (make this a first-class requirement, with the vertical-slice playtest validating it).

---

## C. Calibration & consistency (fixable numbers)

### C1 🟡 The calendar contradicts itself across docs, and the real-time target doesn't math out
**Problem (confirmed).** Prototype spec: `days_per_year = 24` (× 4 ticks/day = **96 ticks/year**). Algorithm §0: `1 year = 96 days = **384 ticks/year**`. That's a **4× contradiction**. Worse, algo §0 says "~6–7 ticks/sec at 1× ⇒ a 90-yr life in 15–30 min", but 90 yr × 384 ticks = 34,560 ticks ÷ 6.5 ≈ **88 minutes**, not 15–30. (The 15–30 figure only works with the prototype's 96 ticks/year: 8,640 ÷ 6.5 ≈ 22 min.) The seasons addition silently broke the timing.

**Proposed adjustment.** Pick one calendar and make the timing consistent. Recommended: **keep seasons** (you need them for weather/festivals) but make the routine sim **coarser** — e.g., **1 tick/day** for the abstract/most-gnome simulation (LOD-0 may sub-step for smooth animation only). Then 90 yr × 96 days = 8,640 ticks/life; at ~6–7 ticks/sec ⇒ ~22 min ✓. Update prototype `ticks_per_day` and algo §0 to match; restate the ticks/sec ↔ lifespan relationship as a single worked example.
**Affects:** algo §0, prototype spec §TimeService.

### C2 🟡 Devotion tiers and social-mass were calibrated for hundreds; at thousands they saturate, and one metric does two jobs
**Problem (confirmed).** `D = Σ faith`. A modest town of ~3,000 gnomes at mean faith 0.5 gives `D ≈ 1,500` — already past the **top tier (1,200)**. So the entire "earn your powers" arc is exhausted in the **first village**, long before the epochal scale the design now targets. Also `M = D` means the *same* number gates unlocks **and** scales magnitude, so they can't be tuned independently and both saturate together. And the magnitude curve `1 + 0.6·log10(1+M)` only spans ~**1.3× (tiny) to ~3.6× (M=20,000)** across the whole game — quite flat for a "society-altering" promise.

**Proposed adjustment.** Decouple the metrics:
- **Gate tiers on a progression metric that scales with the whole arc** — peak *per-capita* devotion, or civilization milestones (generations / population brackets / tech era) — not raw Σfaith. Re-pace thresholds across the real population range.
- Keep Σfaith (or a function of it) as **raw power/magnitude**, but separate from the unlock schedule, and re-shape the magnitude curve (higher `k`, or tiered) so escalation is *felt* — remembering most of the "society-altering" comes from the effect reaching a large population, which should be made legible.
**Affects:** algo §10; setup §3.4 (Divinity slider now maps to the new metric); design §3.1b.

### C3 🟡 Extinction is "colony-wide", but the world is multi-settlement — so dark ages can't happen at scale
**Problem (confirmed).** Knowledge is "lost **colony-wide** when no living gnome holds it" [algo §7]. But the world is a multi-settlement civilization. At tens of thousands, *every* holder dying is essentially impossible short of total collapse — so the marketed "golden ages and dark ages" become an **early/small-colony-only** phenomenon, absent exactly where the epic is supposed to live.

**Proposed adjustment.** Make knowledge loss **per-settlement / per-subculture**: a craft can die in one city while surviving in another, and trade/teaching/migration can re-spread it (or fail to). Full extinction then requires losing it *everywhere*. This makes regional dark ages and renaissances real at scale and **ties knowledge to geography**, reinforcing subcultures.
**Affects:** algo §7, §14 (settlement-tier knowledge); design §1.7/§2.6 wording.

### C4 🟡 Greedy utility AI is myopic; "emergent institutions" are actually authored instincts
**Problem.** Decisions are pure greedy need-satisfaction [algo §6] — reactive, no horizon. Rich, surprising, multi-step behaviour (the Dwarf-Fortress-story quality the vision promises) doesn't reliably fall out of greedy utility. And "fully emergent institutions" rest on **hand-authored instinct behaviours** ("teach nearby young", "gather where others gather") — which is fine, but it's *scripted scaffolding*, not pure emergence, and the docs imply more magic than the mechanic delivers.

**Proposed adjustment.** Add a light **multi-tick "project/goal" action layer** for long-horizon behaviours (build, explore, pursue a craft) so behaviour isn't purely myopic; keep greedy utility for needs. And **state honestly** that institutions emerge from authored instincts + the pattern detector — set expectations so playtest disappointment ("it's not as emergent as promised") doesn't blindside you.
**Affects:** algo §6 (+ a "projects" note), design §1.5/§2.5 framing.

---

## D. Specification gaps (under-defined; will block the build loop)

### D1 ⚪ Leadership/governance is referenced but never modeled
`war_strength = population × metallurgy × **leadership**` [algo §14], and the design mentions councils, leaders, prophets-as-leaders — but there is **no leadership stat** in the gnome model (§1) and **no leader-emergence mechanic** anywhere. The build loop will hit this and stall.
**Fix:** add a minimal **emergent-leadership** mechanic (high-notability + ambitious/charismatic traits → settlement leader; leadership quality feeds coordination, war_strength, institution formation), *or* drop "leadership" from war_strength. Recommended: the light emergent model, since governance is part of the vision.

### D2 ⚪ Other under-specified pieces to close before/within the relevant phase
- **Carrying capacity `K = f(resources, tech)`** — give a concrete formula (drives crowding, fertility, migration; currently a black box).
- **Trade/economy** — "trade spreads knowledge and raises mood" but there's no model of *what* is produced/traded or how surplus/deficit is computed.
- **Settlement-tier belief vs individual-tier belief** — individual belief uses a social graph + holder counts; abstract settlements have neither. The aggregate belief model and the individual one must be **defined to reconcile on promotion/demotion** (this is the same family as A1).
- **Mixed timescales** — settlement flows run "per season", individual sim "per tick"; specify how they compose (and what happens to a settlement's per-season cadence when you zoom in and it materializes individuals).
- **Minor:** `mood = 1 − mean(active_needs)` ("active_needs" undefined); the `safety` need's decay/spike semantics are muddled; the faint **codex** is barely mechanized.
- **Determinism is conditional on input:** "same seed ⇒ same run" only holds *given the same player-input sequence*; the determinism test (T12.2) must **replay recorded inputs**, and the docs should say so.

---

## E. What's solid (so the review is fair)
The sim/presentation split (once A1 is fixed) is the right backbone; treating tech/magic/skills as one knowledge system is elegant and gives dark-ages-for-free (once C3 localizes it); the hybrid belief model is a genuinely good scale-vs-legibility answer; the influence→appraisal→behaviour→belief pipeline is clean; the magic-as-studying-the-god co-evolution is a standout idea; and the test-gated, atomic-commit build contract is exactly how you'd want a loop to run. The bones are good.

---

## F. Recommended actions (priority order)
1. **Fix A1** (split simulation-LOD from render-LOD) — it's a contradiction at the heart of the architecture; do it before any code.
2. **Adopt A2** (vertical-slice + fun gate + honest scope) — restructure the plan so you learn if it's fun *early*, and shrink the v1 target.
3. **Address B1 & B2** (diversity floor; tyranny balance) — these decide whether the emergent and moral promises actually hold; bake in guard tests.
4. **Re-calibrate C1–C3** (calendar/timing; devotion-tier-vs-scale & metric split; per-settlement extinction) — mechanical fixes, mostly number changes.
5. **Close D1–D2 gaps** before the phases that need them, or the loop stalls.
6. **Keep B3 in view** through the vertical slice — let the playtest judge engagement, then adjust the feedback layer.

> If you want, I can fold the accepted fixes back into the specs — most are local edits, with A1, A2, and the C-series being the substantive ones (design → v1.2, algorithm → v1.1, plan updated with the vertical-slice gate).

---
---

# Review v3 — full-project review: clarity · coherence · blind spots *(fresh pass over all seven docs, post-v1.3/v1.4)*

> **Verdicts up front.** **Intent & gameplay clarity: strong** — the pitch, core loop, defining promise ("you set the stimulus; psychology is the transfer function"), and the worked landslide example communicate the game unambiguously; four clarity gaps found, all additive. **Coherence: sound skeleton, six concrete seams** — all small, all fossils of earlier edit rounds (calendar, scale, tier-metric, register). **Blind spots: six**, of which **two are load-bearing (★)** — the Eye of God's `attention` input is never actually defined, and the world never acts on its own, which quietly falsifies the locked "always ambiguous" register.

> **RESOLUTION (v3 — decided & applied):** design → **v1.4**, algorithm → **v1.5**, plan/setup/how-to updated. Designer's calls on the three forks: **B1 → dwell-only Eye** (no pins — "to hold a soul in the light, you must keep looking"); **B2 → reversed into a lock:** a **Still World** — the world rolls *no* ambient events; sole authorship is the point (ambiguity is *diegetic* — the gnomes can never be sure; the skeptic is rationally justified, factually wrong, and can never know it); **B3 → run ends in a Chronicle** (no re-founding; the world outlives them only for a breath). All C/H items and B4–B6 applied as proposed.

## Lens 1 — Clarity of intent, gameplay, and the doc set

**R3-C1 · The locked tone lives in the wrong document — and older tone statements contradict it.** The register chosen in the phenomena cycle (**eerie-uncanny · always ambiguous · unflinching**) exists only in algorithm §18. The *design* doc still carries the older tone: locked-list says "**bittersweet** tone", §1.8 says "*never as grimdark misery*", §3.4 closes "lands squarely in the bittersweet register", and the setup presets sell **other registers** ("cozy", "bittersweet→brutal, DF-register"). A newcomer (or the build loop, or future content authoring) cannot tell which mood is law.
**Fix:** add **design §1.8b "Tone & register (locked)"** as the tone's home: eerie-uncanny primary; the **ambiguity rule as a content-authoring rule** (*every phenomenon must carry a plausible mundane reading* — this is why belief stays contested); unflinching (real plague and famine — it should ache, never wallow); *bittersweet* retained as the intended **aftertaste** (loss with meaning) inside that register. Update locked-list wording, §1.8 bullet, §3.4 line; reword setup preset "Feel" column to harshness-*within*-the-register (the register itself is never a slider) and §3.2's "Bittersweet default" line.

**R3-C2 · The opening pitch still says "hundreds".** Design intro: "a society of **hundreds** of autonomous gnomes"; §1.1: "grow a society **into the hundreds**" — fossils from before the epochal-scale lock (tens of thousands). The very first paragraph undersells the locked scope.
**Fix:** both lines → founders to a **civilization of tens of thousands**.

**R3-C3 · No reading order or authority rule for the seven-doc set.** Only the plan (§0.7) states that the algorithm doc is numeric truth. Nothing tells a fresh reader/agent the reading order, or what wins when prose and §17 disagree; and companion headers pin stale versions ("design doc (v1.1)") that guarantee future drift.
**Fix:** a short **"How to read this set"** block in the design header: reading order (design → algorithm → plan → setup/prototype → how-to), authority (**algorithm §17 is the single numeric truth**; design = intent; plan = process; on numeric edits, change §17 *and* the prose together), and unversion the cross-references in setup/plan headers.

**R3-C4 · The first thirty minutes are unspecified.** The docs define the systems but never the intended *opening beat* — what a new player actually experiences from tick 0. That's the thing Playtest Gate 1 must judge and Gate 4 onboards, and it currently has no target to compare against.
**Fix:** a short **design §1.2b "The opening minutes"** sketch: an unexplained arrival (no origin story — fits the register), Tier-I acts only, the first winter / first ambient event as antagonist, the first attribution moment targeted around season 2–3, the first crystallized belief as the de-facto tutorial beat.

## Lens 2 — Coherence seams (all confirmed against current text)

**R3-H1 · Propagation still runs on the dead calendar.** Algo §9: "Propagation (batched, **every 4 ticks**)"; §17 table repeats "(×4 ticks)"; plan T6.2 repeats it. Under the old 4-tick day that meant *daily*; after the 1-tick=1-day fix it silently means **every 4 days** — a 4× slowdown of belief spread nobody chose.
**Fix:** propagation runs **every tick (= daily)**, coefficient unchanged; update all three sites.

**R3-H2 · A five-category fossil in prophet seeding.** Design §3.9: omens/manifestations "**(cat. 3 & 5)**" — indices from the *old five-category* toolbox. In the locked seven: **cat 5 & 6**.

**R3-H3 · The canonical first act isn't in the catalog.** The `landslide` is the design's worked example (§3.4), the prototype's Milestone 2, the plan's Phase-7 exit test — and is *absent* from §18's fourteen (T7.8 loads "the 14"). The build loop would have to invent its data.
**Fix (no renaming churn):** add **#15 "The Sliding Earth"** (`landslide`) — ② Earth & Stone · malevolent · int 0.6 / drama 0.6 · *"the hillside lets go all at once, and the scar it leaves is full of glinting ore"* · mundane: "heavy rains, loose slope" · effects `{m −0.3, p −0.3, d +0.4 (exposes a lode), b +0.5, s =culture}` · affordance: slope · chains → dam_flood @0.15, → cursed-place @0.20 — noted as *the canonical first act*. Update §18 counts (15; **4 ben / 7 mal / 4 neutral**) and T7.8.

**R3-H4 · Phase 12's exit test contradicts its own tasks.** Phase-12 goal line: "same **seed+config** produces identical run-hash twice" — the pre-Eye determinism claim that T12.2 and invariant §0.2 explicitly retired.
**Fix:** exit test = identical hash from **seed + config + recorded acts + recorded attention**; save→load→continue equality under the same recorded inputs.

**R3-H5 · Two unlock/attention stragglers in the plan.** T14.1 gates the influence UI "by **`D` tier**" (old raw-total metric; must be **`d̄_peak`** tiers). T11.1 promotes "by **camera**/notability" with a "camera radius mocked headless" — should be **attention** (the defined input), mocked as an *attention script* (as T12.2 already phrases it).

**R3-H6 · Micro-polish.** Setup/plan headers cite "design doc (v1.1)" (→ unversion, per R3-C3); design §2.8 item 10 says "save/**seeded-determinism**" (→ "save/replay (seed+inputs)"); plan Appendix C omits `test_diversity_balance` from the integration list; design §2.9 Q7 (LOD-2 appraisal fidelity) is *answerable from §2.6* — the scalar substrate is population-wide by design → resolve as "full statistical belief participation; discrete objects sampled on promotion"; Parts are ordered 1 → 3 → 2 (intentional emphasis — add a half-line saying so in the header note).

## Lens 3 — Underdefined things & blind spots

**R3-B1 ★ `attention` is a defined sim input that is never defined.** It's load-bearing (drives quickening, divergence, replay, tests) yet no doc says what counts as "the focused region": Does panning past a city quicken it? What radius? When does the Eye *leave*? Without dwell/hysteresis rules, fast camera sweeps would strobe hundreds of gnomes through promote/demote (churning fates and the budget), and T12.2's "attention script" has no format.
**Proposed definition (recommended: the hybrid):** attention derives from the camera by **dwell** — the camera's focal region counts as *under the Eye* only after lingering **≥ ~2 s** ⚙️; radius scales with zoom (individual zoom ≈ a small circle; settlement zoom ≈ the settlement; **civilization zoom never quickens** — too coarse to single anyone out); demotion after **~10 s** of the Eye elsewhere ⚙️ (hysteresis — no strobing); *panning past never quickens*. Plus an optional **Pin** (hold ≤ 1–2 regions ⚙️ under the Eye while looking elsewhere, within the quicken budget) for deliberate play. Attention is recorded as sparse `[t, region, radius]` segments (the replay/test format). Touches: design §2.4 (define; and LOD-0's "camera-local" → "attention-local"), algo §14/§17 (constants), plan T13.5 (new: derive/route/record attention) + T11.1 wording. *(Alternatives if preferred: pure dwell, no pin; or a fully explicit Gaze reticle and the camera never quickens.)*

**R3-B2 ★ The world never acts on its own — which breaks the register and empties idle time.** Every notable event is player-authored: skeptic gnomes are *objectively wrong*, the theology's "Existence" question ("or is it all impersonal nature?") has a secretly trivial answer, §16's "necessity-driven research" has a single author (you), and a player who watches without acting sees a world where nothing ever happens. For a game whose soul is *ambiguity*, nature must be a real alternative hypothesis.
**Proposed: ambient events.** The world rolls phenomena from a **mundane subset** of the same catalog (Elements / Earth / Life / Beasts entries only — **Omens, Visions, and Wonders remain uniquely yours**, so the impossible stays divine), tagged `source: world`, biome/season-weighted, rare (⚙️ ~0.05–0.1 minor per settlement-season; a major every ~1–2 decades), running through the *identical* pipeline — including the **attribution seed**, so gnomes may credit or blame *you* for storms you never sent (false theology; the register's favorite food). One accounting rule: `flavor_balance` counts **attributed** acts (what they *believe* you did), not ground truth — nature can make you a monster you never chose to be. Founding slider **"World Temper"** (Sleeping / Normal / Restless). Touches: algo §11+§15+§16+§17, design §1.11/§2.7/§3.7 one-liners, setup §3/§4 slider, plan (small Phase-7/16 tasks + invariant "an idle run still produces events/stories").

**R3-B3 · The end of a run is undefined.** Per-settlement collapse exists, but *total extinction* has no defined outcome — no "game over", no epilogue, nothing. (Relatedly, the run's story is never artifacted; T16.3 telemetry exists but reaches no player surface.)
**Proposed: the world outlives them.** On extinction the sim simply keeps running, empty — a god of empty places, shrines wearing down (register-perfect). From there: **(i)** a new founder band may eventually wander in from beyond the region (seed-driven re-migration, ⚙️ probability/era-scaled), and/or **(ii)** the player may close the run into a **Chronicle** — an auto-generated history (generations, faiths, prophets, wars, how it ended; exportable; built on T16.3) that becomes the run's artifact. Recommended: both, player's choice at the moment of silence. Touches: design §1.9, algo §14/§17 one-liners, setup §6 (Chronicle alongside Codex), plan (small Phase 15/16 tasks).

**R3-B4 · Acts have no targeting model.** The schema has no `target` field; §3.3 implies "place" but nothing says what an act *selects* (a point? an area? a settlement? one gnome?), and Phase 14 has no targeting interaction task. First UI work would stall or improvise.
**Fix:** schema field `target ∈ {point, area(r), settlement, region, individual, world}` with per-entry values in §18 (Elements → area; Earth → point/area; Life → area; Beasts → region-edge; Omens → settlement-sky; Shared Dream → settlement; Day-Twice → settlement/region; *individual* reserved for cat-6 visions); one design §3.1 line on the interaction ("choose the act, paint the where, release — no preview, no undo, per §3.8 mystery"); extend T7.1/T7.8 and T14.1 accordingly.

**R3-B5 · No audio direction, in a register that is substantially *made of sound*.** "The Still Air" is literally an audio phenomenon (silence, no birdsong); the docs' only audio words are volume sliders and "audio never touches the sim."
**Fix (short §2.7c, presentation-only):** **silence as the primary instrument** (the uncanny arrives by *subtraction* — birdsong stops, wind dies); **diegetic-only feedback for acts** (no UI stingers or confirmation fanfare — the world just changes; preserves ambiguity and complicity); familiar sounds made slightly *wrong* for tainted/uncanny moments; **music is emergent, not a score** — the colony's own songs/hymns appear as its culture and faith crystallize (a rite gets a melody; a terror-faith's hymns are thin and urgent). Plus a small plan task (Phase 14/15 ambience+diegetic-cue stub).

**R3-B6 · The performance budget is referenced but never set.** Phase-11's exit test says "within **a set time budget**" — which no document sets; T11.5 is therefore unwritable, and "tens of thousands in GDScript" is the plan's biggest technical bet with no yardstick.
**Fix (⚙️ starting targets, mid-tier desktop reference):** average **sim tick ≤ 10 ms at pop 5,000** and **≤ 16 ms at pop 20,000** with ≤ 300 quickened; render ≥ 60 fps at Kingdom scale at 1×; save ≤ 2 s, load ≤ 5 s; sim-side memory ≤ ~2 GB at 20k. Written into plan Phase-11/T11.5 (and echoed in algo §14) so the loop can write a real perf test — with the §2.2 escape hatch (port hot paths to C#/GDExtension) as the stated mitigation if targets fail.

## What's solid (for fairness)
The narrow-inputs sim boundary (seed + config + acts + attention) is clean and consistently stated everywhere *except* the two stragglers above; the devotion decoupling + ratchet reads correctly in all docs; §17/§18 give the loop a single numeric truth and real content; the plan's contract, gates, and TDD discipline are exactly loop-shaped; the setup doc's per-game vs global separation is airtight; and the influence pipeline + §16 loop map remain the best-articulated parts of the design.

## Disposition
R3-C1–C4, H1–H6, B4–B6 have single sensible fixes → apply directly. **B1 (Eye model), B2 (ambient default), B3 (extinction handling)** are taste calls → decided by the designer, then applied in the same pass.

# Gnome Colony — Colony Evolution Algorithm: Parameters & Mechanics (v1.5 — project review v3 applied)

*Companion to the design doc and prototype spec. This is the simulation bible: the state, value ranges, formulas, and — most importantly — the **influence relationships** that make the colony evolve. It is written to be coded from.*

> **Read every number as a tunable starting point.** These defaults are chosen to be internally consistent and to produce the intended *feel*; real balance comes from playtesting. Where a value is a knob with strong effects, it's flagged ⚙️. All stochastic draws go through the single **seeded RNG**, so individual systems are reproducible under fixed inputs (essential for tests). **Run-level reproducibility is *not* from the seed alone:** the **Eye of God** (design §2.4) makes the player's *focus* a sim input — watched gnomes are simulated at higher fidelity/variance than the statistical model — so a full run reproduces only from *seed + recorded acts + recorded attention*. Determinism is a unit-test/replay tool, not a guarantee of one fixed world per seed.

## 0. Conventions

- **Normalized scalars** are in `[0,1]` unless stated. Needs, traits, skills, feelings, devotion-per-gnome, proficiencies — all `[0,1]`.
- **Time** is measured in **ticks** (the sim's atomic step). Real units: **`1 tick = 1 day`**, `1 season = 24 days`, `1 year = 4 seasons = 96 days = 96 ticks`. ⚙️ (One decision/day for the simulation; LOD-0 puppets sub-step within a day for smooth animation — presentation only.)
- **`dt`** in formulas = 1 tick unless noted. Rates are per-tick unless suffixed `/day` or `/year`.
- **Speed:** a 90-year life ≈ **8,640 ticks** (90 × 96). At **1×** the renderer advances ~**6–7 ticks/sec**, so a life plays in ~**20–22 min** (the design's 15–30 min band; nudge ticks/sec to taste). Fast-forward multiplies ticks/sec (sim is frame-rate-independent).
- **clamp(x)** ≡ clamp to `[0,1]`. **N(μ,σ)** ≡ Gaussian draw. **U(a,b)** ≡ uniform.

---

## 1. The gnome agent — full state & ranges

| Field | Type / range | Notes |
|---|---|---|
| `age` | float years, 0–~110 | drives life-stage & mortality (§4) |
| `stage` | enum | Infant/Child/Adolescent/Adult/Elder/Dead (§4) |
| `sex` | {0,1} | reproduction only |
| `needs` | map → `[0,1]` | 0 = satisfied, 1 = desperate (§3) |
| `traits` | map → `[0,1]` | personality; partly heritable (§2) |
| `skills` | map name→`[0,1]` | proficiency; decays unused (§7) |
| `knowledge` | set of ids | things this gnome can **teach** (crafts, tech, magic) (§7) |
| `feelings` | map subject→`[0,1]` per axis | fear/awe/faith toward places, phenomena, you (§9) |
| `relationships` | map other_id→{type,`[-1,1]`} | social graph edge weights (§8) |
| `memory` | small ring buffer | notable witnessed events; colors appraisal |
| `notability` | `[0,1]` | promotion priority for LOD (§14); leaders/prophets high |
| `partner_id`, `home_settlement` | id / id | |

---

## 2. Traits (personality)

Catalog (starting set — extend freely): **industrious, curious, timid, social, devout, aggressive, nurturing, ambitious**. Each `[0,1]`, default population mean ≈ 0.5, sd ≈ 0.15.

**Effect:** traits reweight decisions (§6), appraisal (§11), mate choice (§8), and discovery (§13). Examples: `industrious`↑ → work utility ×(0.7+0.6·industrious); `curious`↑ → investigates novelty, boosts discovery; `timid`↑ → amplifies fear appraisal; `devout`↑ → faith feelings rise faster.

**Plasticity (nature + nurture):** a child's traits drift toward its caregivers' and its culture's values during Infant/Child stages:
`trait += plasticity · (env_mean − trait) · dt`, `plasticity ≈ 0.02/day` while young → ~0 by Adult. ⚙️ This is how culture shapes temperament across generations. **Constitutional traits — those from an outlier birth (genius/touched/mutant, §8) — are exempt from plasticity** (they don't wash back toward the mean), so the divergence engine isn't quietly cancelled by homogenizing upbringing.

**Inheritance:** see §8.

---

## 3. Needs

| Need | base decay /day | stage modifiers | satisfied by |
|---|---|---|---|
| `hunger` | 0.12 | Infant/Child rely on a caregiver | eat |
| `rest` | 0.10 | — | rest/sleep |
| `social` | 0.08 | Adolescent ×1.3 | socialize |
| `safety` | spiked up by threats/phenomena, then decays −0.06/day toward 0 | timid ×(1+timid) | absence of threat; shelter |
| `purpose` | 0.06 | Adult/Elder ×1.3 | work, learn, teach, create |

*(Rates are tuned for the **1 tick/day** grain ⚙️: hunger reaches the 0.9 hardship line in ~7–8 days, so food/rest pressure is felt within a week and a famine kills within a fortnight — meaningful at the daily decision step.)*

**Update:** `need = clamp(need + decay·stage_mod·dt − relief_applied)`.
**Relief:** an action applies `relief[need]` (see §6 catalog), e.g. eating sets hunger ≈ 0.
**Hardship & death:** if any of {hunger, safety} stays ≥ `0.9` for > `5 days`, daily mortality gains `+0.15/day` (§4). Sustained unmet `purpose` doesn't kill but lowers mood and raises emigration desire.

---

## 4. Life cycle & mortality

**Stage age-bands** (years, ⚙️): Infant 0–3 · Child 3–14 · Adolescent 14–20 · Adult 20–65 · Elder 65+. Transition emits an event (§16 bus).

**Target lifespan:** ≈ `N(90, 12)`, hard cap ~115. Tuned with §0 speed so a life ≈ 15–30 real min at 1×.

**Mortality (per day):**
`p_death = age_curve(age) + hardship + accident`
- `age_curve` ≈ Gompertz: `a·exp(b·(age−65))`, with `a≈0.00005`, `b≈0.085` → negligible until Elder, then climbs. ⚙️
- `hardship` from §3.
- `accident` baseline `0.00002/day`, raised locally by hazards/your phenomena.

Lifespan-extending tech (medicine, §13) lowers `a` and `hardship` impact.

---

## 5. Time, mood & aggregate vitals

A gnome's **mood** `[0,1]` = `1 − mean(needs)` over the five primary needs {hunger, rest, social, purpose, safety}, adjusted by recent events (a death nearby −, a birth/feast +). Mood feeds emigration desire, devotion flavor (§10), and unrest (§14).

Colony/settlement **vitals** (tracked at all tiers): population by stage, mean traits, skill/tech distribution, mean mood, belief aggregates, resource stocks. These ARE the settlement-tier state (§14).

---

## 6. Decision-making (Utility AI)

Each decision tick a gnome scores its stage-available actions and picks the max (with jitter):

```
score(a) = Σ_need [ need^2 · relief(a,need) ] · trait_mod(a) · culture_mod(a) · belief_mod(a)
           + U(0, 0.05)                       # jitter for variety
```
- `need^2` makes urgent needs dominate (Sims-style).
- `trait_mod`, `culture_mod`, `belief_mod` ∈ ~`[0.5,1.8]`. `belief_mod` is where a **cursed** place-tag drops the score of acting there (avoidance) and a **blessed** tag raises it.

**Action catalog (starter)** — `relief` vectors (per use):

| action | hunger | rest | social | purpose | stage gate |
|---|---|---|---|---|---|
| eat | −0.9 | | | | all (Infant via caregiver) |
| rest | | −0.9 | | | all |
| socialize | | | −0.7 | −0.1 | Child+ |
| work | | +0.05 | | −0.6 | Adolescent+ |
| learn | | | −0.05 | −0.4 | Child+ (needs teacher/source) |
| teach | | | −0.2 | −0.5 | Adult/Elder (needs knowledge) |
| create/explore | | | | −0.6 | Adult (curious↑) |

(negative relief = reduces that need; small positives = side costs.)

---

## 7. Skills, knowledge, technology & magic (one system)

Skills, crafts, **technologies, and magical insights are all "knowledge-objects"** with the same lifecycle.

- **Proficiency** `[0,1]` per gnome per skill.
- **Practice gain:** `prof += 0.01·(1−prof)·dt` while working that skill (asymptotic). ⚙️
- **Teaching transfer:** `learner.prof += 0.03·(teacher.prof − learner.prof)·teacher_quality·dt`; learner gains the knowledge-id once `prof ≥ 0.2` (can now teach it onward).
- **Decay:** unused `prof −= 0.002/day`; an id becomes un-teachable below `0.2`.
- **Extinction (per-settlement):** when **no living gnome in a settlement** holds an id at `prof ≥ 0.2`, that settlement **loses** it → a **regional dark age**, while another settlement may still hold it. Trade, teaching, and migration can **re-spread** it (or fail to). *Full* extinction = lost in every settlement. **Writing** (a tech) snapshots ids into durable records, exempting them from loss. This makes dark ages *regional and recoverable*, and ties knowledge to geography (reinforcing subcultures) — and keeps dark ages possible even at civilization scale.

**Knowledge prerequisites:** each id lists prereq ids (e.g. `smithing` needs `fire`,`stoneworking`). Discovery (§13) can't fire until prereqs are held somewhere in the settlement.

---

## 8. Relationships, mating & genetic inheritance

**Edges** `[-1,1]` by type {kin, friend, rival, mate}. Interactions adjust weight: `w += 0.05·sign·compat`, where `compat` rises with trait similarity (and culture-defined norms). Idle decay `−0.001/day` toward 0.

**Partnership:** two unpartnered Adults with mutual `mate`-weight ≥ `0.6` and culturally permitted (§9 norms) pair up.

**Fertility:** partnered, both Adult (20–50 for bearer), `food_factor` ok → per-season birth chance ≈ `0.15·food_factor·(1−crowding)` ⚙️ (≈ 0.5 births/yr per fertile pair at low crowding — *gradual* growth you can watch). Population's real ceiling is **carrying capacity `K`** (§14), which **tech raises** (agriculture/construction), so growth approaches K and only the **pop floors** for Tiers IV–VI (50 / 200 / 1000) gate the late toolbox — i.e. you must grow a *civilization*, which means developing the tech to feed one.

**Inheritance (per trait):**
`child.trait = clamp( 0.5·(p1+p2) + N(0, 0.05) )`  → blend + **mutation sd 0.05** ⚙️.
Rare large mutation: 2% chance `+N(0,0.2)`. Skills are **not** inherited (must be taught — this is why teaching/culture matters).

**Culture-shaped norms (emergent):** the belief system (§9) can spawn norm belief-objects that gate `compat`/partnership — e.g. a taboo lowering cross-subculture `compat` by `0.5`, or status-pairing favoring high-`notability` matches.

**Outliers — the divergence engine (counters blending homogenization).** Plain blending + small mutation is mean-reverting and would flatten the population toward 0.5 over generations. Three forces resist that — **assortative mating** (compat rises with similarity → like pairs with like, preserving clusters), **persistent biome attractors** (§15, an ongoing per-region pull, not a one-time nudge), and most importantly **outlier births**:

| Outlier (per birth, `p_outlier ≈ 0.01` ⚙️, then pick type) | What's special | Effect |
|---|---|---|
| **Genius** | one+ traits/skill-rates far above band (curiosity/learning) | leaps tech & craft; powerful teacher |
| **Touched** (mentally atypical) | erratic appraisal; very high prophet-ripeness | visionary *or* madman; volatile belief swings; prime prophet seed |
| **Mutant** (physical) | trait values **outside `[0,1]`-band**, partly **heritable** | founds strange lineages; revered or shunned (belief hook); reinjects extreme genes |
| **Long-lived / Giant / Barren / …** | extensible | rare flavour + edge-case pressure |

Outliers carry values *beyond* the normal band and (for mutants) **heritable** ones, so they periodically reinject extreme genes into a flattening pool and create exceptional individuals who reshape culture, tech, and belief. A **diversity-floor invariant** (trait variance must not collapse, §16) makes erosion a failing test, not a silent drift.

---

## 9. Culture & belief (hybrid model)

**Layer A — scalar substrate (every gnome, cheap).** Per (subject, axis) feeling `[0,1]`, axes = {fear, awe, faith, reverence}. Subjects = places, phenomenon-types, other groups, and **you**.
- **Appraisal write (on witnessing a stimulus, §11):** `feeling += intensity · susceptibility(traits, current_theology) − habituation` toward the relevant **phenomenon-type** and **place**. **Habituation** is a per-(gnome, phenomenon-type) counter: `+0.15` each repeat, decaying `−0.02/day` ⚙️ — so spamming the *same* act stops landing (you must vary or escalate). **Feelings relax proportionally toward baseline: `feeling += −0.03·(feeling − baseline)·dt` ⚙️** (half-life ≈ 23 days), giving devotion a *bounded equilibrium* — sustained, **varied** presence is what holds high faith, not click-frequency.
- **Attribution seed (how belief-in-*you* bootstraps from zero):** a dramatic or inexplicable event *also* writes a small awe/fear toward **"an unseen will"** (you): `you_feeling += α · attribution · event_drama`, with **`α ≈ 0.25` ⚙️ (the ramp dial — without it a single cataclysm would saturate faith)** and `attribution = clamp(0.3 + 0.7·devout − 0.8·magic_understanding)`. So a lone dramatic act adds ~`0.08` faith (not `0.33`); a few acts across a season, against proportional decay, climb the early tiers — you *earn* it. So even with no prior theology, a primitive colony readily reads a cataclysm as *willed* and starts to invent you; an enlightened, magic-literate colony attributes far less (it folds into secularization, §10/§13). Without this, total devotion could never leave 0 and no tier would ever unlock.
- **Propagation (daily — batched each tick):** along social edges, `nbr.feeling += 0.04·tie·(src.feeling − nbr.feeling)`. Fear propagates ×1.5 (fear is loud). ⚙️

**Layer B — crystallized belief-objects.** When a feeling about a subject is held by ≥ `min_holders` (default 5 or 3% of settlement) at strength ≥ `0.7` for ≥ `1 season`, it **crystallizes** into a named object:

| Belief-object | trigger | effect |
|---|---|---|
| **Taboo** (place/act) | fear/reverence ≥ 0.7 | `belief_mod` penalty on that act/place (avoidance) |
| **Rite/festival** | awe/faith ≥ 0.7 | periodic gathering; raises social + mood + devotion |
| **Place-reverence** | reverence ≥ 0.7 | writes `blessed`/`cursed` tag onto the world tile |
| **Theology-about-you** | faith ≥ threshold | sets the colony's image of you (§10), **feeds back into appraisal susceptibility** |

- **Strength** = backing feeling × holder fraction. **Drift:** on each transmission, 3% chance the object mutates (a rite's details shift, a taboo's scope widens) → traditions diverge.
- **Subcultures:** cluster settlements/lineages by belief-vector distance; distance ≥ `0.5` = a distinct subculture (and candidate for schism, §14).

---

## 10. Devotion & social mass

**Per-gnome devotion** = its `faith`-in-you feeling `[0,1]`, with a **flavor** = sign of (awe−fear): love-devotion vs terror-devotion. **Both count equally toward unlocking**, but the flavors *behave* differently (terror = more potent per act yet unstable; love = gentler yet stable — see the flavor consequences below).

**Colony devotion** `D = Σ gnome.faith` (so it grows with both belief *and* population). Track also `flavor_balance` = mean(awe−fear).

**Toolbox unlocking — gated on *per-capita* devotion, not raw total.** (Raw `D=Σfaith` was the old gate; at thousands of gnomes it blew past every threshold in the first village. Fixed: unlock on how *deeply* they believe.) Use `d̄ = D / population` ∈ `[0,1]`, with a soft population/era floor on the top tiers so a tiny fanatic cult can't wield Wonders at gen 1. Defaults ⚙️:
| Tier | unlock at `d̄ ≥` | + floor | categories |
|---|---|---|---|
| I | start | — | The Elements (gentle subset) |
| II | 0.15 | — | Elements (full), Earth & Stone |
| III | 0.30 | — | Life & Growth, Beasts |
| IV | 0.45 | pop ≥ 50 | Omens & Signs |
| V | 0.60 | pop ≥ 200 | Visions & Dreams |
| VI | 0.78 | pop ≥ 1000 or gen ≥ 5 | Wonders & the Uncanny |

Unlocks **ratchet on *peak* `d̄`** (track `d̄_peak`): once a tier is earned it stays unlocked, so a baby boom — which dilutes mean faith because newborns start near 0 — never strips a power you already had. This makes "earning your powers" an arc that scales across the *whole* game, independent of population, while the floors keep the grandest powers a milestone.

**Social mass** `M = D` (= total devotional weight ≈ devotion × population). Decoupled from the unlock gate, it now governs **magnitude only**:
`magnitude = base · (1 + k·log10(1 + M))`, `k ≈ 0.9` ⚙️ (raised so escalation is *felt*). A lone camp: ~base. A vast devout civilization: several× base. Most of the "society-altering" force also comes from the effect's **reach** scaling with population (made legible in the aftermath UI), not the multiplier alone — never literally unbounded.

**Flavor consequences — the tyranny/shepherd balance (devotion is *valence-neutral in what it unlocks*, but the two flavors behave very differently):**
- **Terror-faith is fast but volatile and instability-taxed.** Fear is easy to manufacture (drama → fear → devotion), so a tyrant's `D` can spike *quickly* — and terror tools hit *harder* (valence potency, §11). But negative `flavor_balance` levies a continuous **instability tax**: `unrest += 0.02·max(0,−flavor_balance)·logM`, plus **faster heretic/magic-resistance emergence** (§13), higher **schism** risk (§14), and a real **collapse** tail. Terror-devotion is also volatile (it can crater when a tyrant-god's grip slips). Power is *not* reduced — the price is paid in **stability**.
  - **Unrest effects (quantified, so the balance is real & testable) ⚙️:** unrest scales `−0.3·unrest` onto settlement **productivity & birth-rate**; adds **schism probability** `+0.01·unrest/season`; and at **`unrest ≥ 0.8`** triggers a **fracture/revolt** event (mass emigration, a leader's fall, or a splinter settlement — a hard cap on how large a terror-state can grow). Relief: benevolent acts, met needs, and quiet time lower unrest `−0.01/day`.
- **Love-faith is slower but stable, compounding, and resilient.** It carries no instability tax, doesn't crater, and accumulates steadily into a flourishing, schism-resistant society — so over time a benevolent civilization reaches **high *sustained* devotion** (and thus high magnitude) the tyrant can rarely hold.
- **Net (the balanced temptation):** *tyranny = burst power + harder-hitting tools, ridden on fragility and revolt; shepherd = gentler tools + slower ramp, but sustainable, stable, and high-ceiling.* The extra potency of cruelty (§11) is deliberately balanced against its instability, so evil is **tempting but not dominant**, and good is **viable, not under-armed**.

**Secularization (mild):** `D` drifts `−0.0005·science_level/day` ⚙️ — advanced colonies believe a little less, never catastrophically (faith & science coexist).

---

## 11. Influence system — phenomena & appraisal

**Phenomenon schema** (data-driven; one per lever):
```
id, category(1-7), valence(benevolent|malevolent|neutral), taint(clean|tainted, benevolent only), target(point|area|settlement|region-edge|individual), base_intensity, event_drama, tier(devotion gate),
effects: { material, population, discovery, belief, social }   # axis weights; social may be '=culture' (resolved at runtime)
affordance_req: e.g. needs slope / water / forest
chain_hooks: [ {phenom, prob} ]      # e.g. landslide→dam_flood @0.15
tail_risk: prob 0.03 of a random outsized effect            # universal
```
- **Resolved intensity** = `base_intensity · magnitude(M) · valence_potency` (§10), then distributed over affected tiles/gnomes.
- **Valence potency (locked — the temptation that balances evil's instability):** `valence_potency = 1+δ` for **malevolent** acts, `1−δ` for **benevolent**, `1` for neutral, `δ ≈ 0.4` ⚙️. *Cruelty lands harder than kindness.* So bad behaviour is genuinely **more powerful per use** — the reward — while carrying the instability cost of terror-faith (§10). Good acts are gentler per use but build stable, compounding devotion (§10). This pairing (stronger-but-destabilizing evil vs gentler-but-sustainable good) is what keeps the moral choice live.
- **Appraisal:** for each affected/witnessing gnome, write feelings (§9) via `susceptibility(traits, theology)`. The same event ⇒ different deltas per gnome (curious → discovery memory; timid → fear).
- **Chaining:** roll each `chain_hook`; on hit, queue the chained phenomenon (cascades). **Tail-risk:** `0.03` per act ⚙️ to spawn an unscripted consequence; its size also scales with `M` (big myth ⇒ big accidents).
- **No cost** to trigger; the only governors are trade-offs, tail-risk, and devotion-flavor unrest (§10).
- **Valence balance (content rule):** keep a roughly **even count of benevolent / malevolent / neutral** phenomena *within each category and overall*, so the shepherd is never starved of options. Balance then comes from two paired asymmetries — **malevolent acts are more *potent*** (valence potency, above) but **terror-faith is more *unstable*** (§10) — making evil tempting but not dominant. (Availability is balanced; power and risk are deliberately *not* symmetric.)
- **Culture-resolved social outcome:** a phenomenon may set `social: =culture` (crises usually do) instead of a fixed value. At runtime `social_effect = swing·(cohesion − fear_level − fracture)`, where `cohesion` rises with mean social/nurturing traits + shared belief (low subculture distance) and `fracture` rises with rival subcultures. So the *same* disaster **bonds** a tight people and **shatters** a divided one (seeding schism, §14) — the reaction is theirs, not yours.
- **Boon taint:** benevolent phenomena carry `taint`. *Clean* boons are pure relief (reinforce love-faith); *tainted* boons help now but carry an uncanny cost or chain (a flood-after, malformed growth, a watching herd) — in an uncanny world not every gift is safe.
- **Targeting:** `target` declares what an act selects — material acts paint a **point/area**; beasts enter at a **region-edge**; omens hang over a **settlement**; Visions (cat 6) may address an **individual**. The interaction is *choose the act, paint the where, release* — no preview, no undo (design §3.1/§3.8). Per-entry values: §18.
- **Sole authorship (locked — design §1.8b):** the world rolls **no ambient phenomena.** Background *pressures* exist (seasons, scarcity, aging, `accident_base` §4) but every **event** has you as its author. Gnome skepticism is diegetic — each act carries a mundane reading — and is never vindicated; the attribution seed (§9) therefore only ever fires on *your* acts.

---

## 12. Prophets

A prophet is a flagged gnome (seeded via an Omen/Vision; only **catches** where ripe: local `mean(|awe−fear|) ≥ 0.5`).

| Param | range/default | role |
|---|---|---|
| `charisma` | hidden, `N(0.6,0.2)` | amplification of their message |
| `message` | emergent | derived from theology + triggering event + traits |
| `life_arc` | rise→peak→decline over their life | influence = `charisma · arc(age)` |
| `corruption_roll` | 0.10 over lifetime ⚙️ | mercy→madness flip (e.g. demands sacrifice) |
| `reach` | social-graph BFS, depth ∝ charisma | who they convert |

**Effect:** a prophet **forces crystallization** (§9) of their message across `reach`, fast. Rival prophets create competing belief-objects → **schism** if both strong. Spamming prophets → fractured faith, unrest. You steer them **only** by omens that confirm/contradict the message (raising/lowering its spread).

---

## 13. Technology & magic discovery (autonomous research)

**Research happens at the settlement tier** as a stochastic process; the player never picks targets.

**Discovery pressure for a candidate id X (prereqs met):**
```
pressure(X) = need_pressure(X)        # environment & YOUR phenomena (drought→irrigation…)
            · (0.3 + curiosity_mean)
            · surplus_factor          # food/leisure above subsistence
            · (1 + log(minds))        # population of capable adults
            · institution_factor      # a school/guild for X's field (emergent)
p_discover(X)/season = clamp01( base_rate · pressure(X) )   # base_rate ≈ 0.01 ⚙️
```
On discovery, X becomes a knowledge-object (held by its discoverers; now teachable, losable, §7).

**Effect of a tech** = a set of **parameter deltas / unlocks**, e.g.:
| Tech | effect |
|---|---|
| agriculture | +carrying capacity, +birth rate, enables settlements |
| writing | knowledge ids become extinction-proof (durable records) |
| metallurgy | +work efficiency, weapons (war strength), trade goods |
| medicine | lowers mortality `a` & hardship |
| construction | enables towns→cities, +shelter (safety) |
| sail | cross water → reach new basins (expansion) |

**The MAGIC branch — studying you.** A settlement accrues `magic_understanding` `[0,1]`:
`magic_understanding += 0.0008·(0.3+curiosity_mean)·exposure_to_your_phenomena·science_level/day`. ⚙️
Thresholds unlock an escalating, **locked full co-evolution**:
| Stage | at `mu ≥` | consequence |
|---|---|---|
| Superstition | 0.0 | events read as raw omen/wrath |
| Proto-science of the divine | 0.3 | they detect *patterns* in your acts; appraisal less fearful, more analytic |
| **Prediction** | 0.5 | they forecast omens/eclipses → **your Omen & Wonder belief-impact ×(1−0.6·mu)** (an expected portent doesn't awe) |
| **Harnessing** | 0.7 | **mages** emerge: gnomes who produce *minor* phenomena themselves (small rain, ward-lights) |
| **Resistance** | 0.85 | **wards**: warded tiles reduce incoming phenomenon intensity by up to `0.7`; **heretics** can defy you while (mildly secular) others still believe |

Because secularization is only **mild** (§10), you can face **devout heretics** — high faith *and* high resistance. Your acts never stop working, but over an enlightened civilization they are **answered**, not absolute.

---

## 14. Hierarchical simulation parameters

**Promotion / demotion (individual fidelity):**
- LOD-0/1 if **under the Eye of God** (the *dwelled* gaze-region — dwell ≥ ~2 s ⚙️, radius by zoom, release-hysteresis ~10 s ⚙️, never at civilization zoom; design §2.4) OR `notability ≥ 0.6` (leaders, prophets, tracked lineage). The *quicken budget* (max concurrent LOD-0, ~`300` ⚙️) is a **gameplay constant in `WorldConfig`** (same across machines for fairness), not a graphics setting.
- Otherwise LOD-2 (local statistical) or, beyond a settlement's `individual_budget` (~`500`), folded into **settlement-tier statistics**. Promote when the Eye falls or on a notability spike; demote when attention leaves. **Promotion intentionally diverges** from the statistical path (the Eye of God *changes fate*); on demotion the gnome's richer state is folded back into the settlement aggregates.
- **Notability growth (so the metric that drives LOD *and* leadership isn't static):** `notability` rises from notable deeds — surviving/causing a major phenomenon, mastering a craft (skill ≥ 0.9), reaching Elder, parenting many surviving children, or becoming a prophet/leader — and **decays slowly** (`−0.001/day` ⚙️) otherwise, so the famous fade as new figures rise.

**Settlement tier (aggregate flows, per season):**
```
births  = fertility_rate · adults · food_factor · (1 − crowding)
deaths  = Σ mortality(stage)·N_stage  + hardship_deaths
migration_out = emigration_pressure(crowding, mood, your_phenomena)
research = §13 over the settlement's knowledge set
culture/belief = aggregate scalar update + occasional crystallization
```
Carrying capacity `K = base_K · Σ(resource_richness) · (1 + 0.5·agriculture_level + 0.3·construction_level)`; `crowding = pop/K` ⚙️.
- **Knowledge is per-settlement** (§7): each settlement holds its own id-set & tech/magic levels; trade/teaching/migration move ids between settlements; loss is regional.
- **Belief reconciliation:** the settlement tier carries belief as **aggregate scalars + crystallized objects** (§9); promoting an individual *samples* feelings from those aggregates, demoting folds them back. Minor divergence is acceptable — and, under the Eye of God, intended.

**Civilization tier (rich, emergent):**
- **Migration:** `migration_out` flows to the best-scoring reachable basin (resources, low crowding, kin ties, shared faith).
- **Trade:** between settlements with complementary surplus/deficit; raises both moods & spreads knowledge/belief.
- **Schism:** when an intra-civilization belief-vector distance ≥ `0.5` and a rival theology has crystallized → split into factions.
- **Leadership (emergent — closes the gap that `leadership` was referenced but never defined):** each settlement's **leader** is its highest `leader_score = 0.5·notability + 0.3·ambitious + 0.2·relevant_skill` (where `relevant_skill` = an oratory/leadership skill, or the gnome's best skill if none); `leadership_quality` ∈ `[0,1]` = that score, feeding coordination, institution-formation, migration cohesion, and war. No leader is appointed by you.
- **War:** triggered when `rivalry + resource_pressure + religious_distance ≥ war_threshold (≈1.5)` ⚙️; outcome from relative `war_strength = population · (1 + metallurgy_level) · (0.5 + leadership_quality)`. A major mortality & belief event (and a frequent product of *your* famines and *their* prophets).
- **World's end:** when every settlement's population reaches 0, emit `world_ended` — the run closes into the **Chronicle** (design §1.9); no re-founding.
- **Perf budget ⚙️ (mid-tier desktop reference — the yardstick for plan T11.5):** avg sim tick ≤ **10 ms at pop 5k**, ≤ **16 ms at pop 20k** with ≤ 300 quickened; save ≤ 2 s, load ≤ 5 s; sim-side RAM ≤ ~2 GB at 20k.

---

## 15. World & regions

**Resource node:** `{type, capacity C, current c, regrowth r/day, richness}`. Harvest draws `c`; `c += r` up to `C`. Hidden nodes (ore) are revealed by phenomena (§11) / exploration.

**Region:** a basin with biome, resource set, hazard **affordances** (slope→landslide, fault→quake, floodplain→flood, forest→fire), barriers (ridges/rivers) defining isolation, and a **fog** state (revealed by exploration).

**Biome → culture bias** (seeds divergence, ⚙️ small but compounding):
| Biome | trait nudge | craft/tech affinity |
|---|---|---|
| Mountain | +hardiness, +timid | stoneworking, metallurgy |
| Forest | +curious, +nurturing | foraging, woodcraft, herbalism |
| River/plain | +social, +ambitious | agriculture, trade, sailing |
| Highland/steppe | +aggressive | herding, war-craft |

These nudge trait plasticity (§2) and `need_pressure` for discovery (§13), so geography quietly authors distinct peoples.

---

## 16. The influence web & feedback loops *(the "how things affect each other")*

**Top-level dependency chain:**
`YOU → world/stimuli → appraisal(traits,theology) → feelings → behavior(utility) → outcomes (births/deaths/discovery/migration/belief) → culture, devotion, tech, settlements → theology & capability → (loops back to how YOU are perceived and answered).`

**Key feedback loops (the engine of emergence):**

1. **Power spiral (+).** Intervene → devotion ↑ → toolbox unlocks + social mass ↑ → bigger effects (and bigger misfires) → more dramatic interventions. *Balanced by loop 2.*
2. **Tyranny brake (−).** Disasters → fear-devotion → unrest & schism → instability/collapse. Over-meddling self-punishes. (Restraint = strategy.)
3. **Knowledge ratchet (+) vs. fragility (−).** More minds + surplus → faster discovery → population/tech ↑ → more minds. But holder-death → extinction → regression, until **writing** converts the ratchet to permanent.
4. **Necessity-driven research.** *Your* phenomena set `need_pressure`, steering *what* they discover (drought→irrigation, beasts→weapons) — indirect tech direction.
5. **Enlightenment answers the god (−on your absolutism).** Exposure to your acts + curiosity → `magic_understanding` → prediction/wards/resistance → your effects get blunted and your omens demystified (mildly lowering devotion). Late-game becomes dialogue.
6. **Geographic divergence → schism → war.** Biomes nudge traits/culture; isolation amplifies; belief-distance crystallizes subcultures → schism → (with resource pressure) war.
7. **Prophet swing.** Ripe emotional charge + a seeded omen → prophet forces mass crystallization → can flip theology fast (mercy or madness), reshaping every downstream loop.

**Stability invariants to preserve while tuning ⚙️:**
- Early game must be *recoverable* (a small colony can climb out of one bad season).
- No single loop should runaway unbounded within a normal session (log-scaled social mass, mutation caps, mild secularization).
- Extinction must be *rare enough to hurt, common enough to matter*.
- Devotion growth and toolbox tiers should pace roughly to generational milestones, not minutes.

---

*Coding order mirrors the prototype spec: implement §1–§8 headless first (a colony that lives, learns, and dies), then §9–§10 (culture/belief/devotion), then §11–§12 (influence/prophets), then §13 (tech/magic), and finally §14 (tiers) to reach scale.*

---

## 17. Tuning constants — consolidated baseline ⚙️

*One place to adjust the whole sim. Every value is a **starting point chosen to be mutually consistent** (verified by the derived figures at the end); real balance comes from the 🎮 playtest gates. `[0,1]` unless a unit is given. Rates are per **day** (= per tick).*

**Time & lifecycle**
| Const | Value | Effect |
|---|---|---|
| tick | 1 day | atomic step; 24 d/season, 96 d/year |
| `life_mean` / `sd` / cap | N(90,12) yr / 115 | ≈ 8,640 ticks → ~22 min at 1× (6–7 ticks/s) |
| stage bands (yr) | Infant 0–3 · Child 3–14 · Adol 14–20 · Adult 20–65 · Elder 65+ | role/fertility gates |
| Gompertz `a`,`b` | 0.00005, 0.085 /day | negligible pre-Elder, climbs after 65 |
| `accident_base` | 0.00002 /day | raised locally by hazards/your acts |

**Needs (decay /day; relief resets to ~0)**
| hunger | rest | social | purpose | safety recover | hardship→death |
|---|---|---|---|---|---|
| 0.12 | 0.10 | 0.08 | 0.06 | −0.06/day | hunger/safety ≥0.9 for >5 d → +0.15/day mortality |

*Maintenance demand ≈ (0.12+0.10+0.08)/0.9 ≈ **0.33 actions/day**, leaving ~⅔ of a gnome's days for work/teaching/culture.*

**Traits & inheritance**
| pop mean/sd | plasticity (young) | inherit | mutation sd | rare-large | `p_outlier` |
|---|---|---|---|---|---|
| 0.5 / 0.15 | 0.02/day→0 by Adult (outlier traits **exempt**) | 0.5·(p1+p2)+N(0,σ) | 0.05 | 2% → +N(0,0.2) | 0.01 /birth |

**Skills**
| practice | teach transfer | teachable | decay | extinction |
|---|---|---|---|---|
| `+0.01·(1−p)/day` | `+0.03·(t−l)·q/day` | p ≥ 0.2 | `−0.002/day` | per-settlement when no holder ≥0.2 (writing exempts) |

*Self-taught to 0.2 ≈ 22 d; to mastery 0.9 ≈ 2.4 yr of focused practice; teaching ~3× faster.*

**Relationships & reproduction**
| edge step | idle decay | partner threshold | fertility/season | compat |
|---|---|---|---|---|
| `0.05·sign·compat` | `−0.001/day` | mutual mate ≥ 0.6 | `0.15·food·(1−crowding)` | rises with trait similarity (assortative) |

**Culture & belief**
| feeling decay | propagation (daily) | fear mult | habituation | crystallize |
|---|---|---|---|---|
| `−0.03·(f−base)/day` (½-life ~23 d) | `+0.04·tie·Δ` | ×1.5 | `+0.15`/repeat, `−0.02/day` | ≥5 or 3% holders @ ≥0.7 for ≥1 season |
| **attribution seed** | `you_feeling += α·attribution·event_drama` | `α = 0.25` | `attribution = clamp(0.3+0.7·devout−0.8·magic)` | bootstraps belief-in-you from 0 |

**Devotion & social mass**
| `D` | `d̄` gate (ratchet on peak) + floor | magnitude | secularization |
|---|---|---|---|
| `Σ faith` | II .15 · III .30 · IV .45 (pop≥50) · V .60 (≥200) · VI .78 (≥1000/gen≥5) | `base·(1+0.9·log10(1+M))·valence_potency` | `−0.0005·science/day` |
| **terror tax** | `unrest += 0.02·max(0,−flavor_balance)·log10 M /day` | **unrest effects** | `−0.3·unrest` on productivity/births; schism `+0.01·unrest/season`; fracture at unrest ≥ 0.8; relief `−0.01/day` |

**Phenomena**
| valence potency δ | tail-risk | chain | 
|---|---|---|
| malevolent ×(1+δ), benevolent ×(1−δ), `δ=0.4` | 0.03/act (size scales with M) | per-hook prob (e.g. landslide→flood 0.15) |

**Prophets · tech · magic**
| prophet catches | charisma | corruption | discover/season | magic understanding |
|---|---|---|---|---|
| local mean(|awe−fear|) ≥ 0.5 | N(0.6,0.2) | 0.10/life | `clamp(0.01·pressure)` | `+0.0008·(0.3+cur)·exposure·science/day` |
| magic stages: | Superstition 0 · Proto-science 0.3 · Prediction 0.5 (omen/wonder impact ×(1−0.6·mu)) · Harnessing 0.7 (mages) · Resistance/wards higher | | | |

**Scale & world**
| LOD-0 promote | quicken budget | settlement budget | notability decay | `K` | war |
|---|---|---|---|---|---|
| Eye (dwell 2 s / release 10 s) OR notability ≥0.6 | ~300 | ~500 | `−0.001/day` | `base_K·Σrichness·(1+0.5·ag+0.3·constr)` | trigger ≥1.5; `pop·(1+metal)·(0.5+lead)` |

### Derived sanity figures (the coherence check, documented)
- **Life** = 8,640 ticks ≈ 22 min @1×; fast-forward scales linearly. ✓
- **Devotion ramp:** a dramatic act ≈ **+0.08 faith**/witness; with ½-life ~23 d, an *active, varied* god holds `d̄ ≈ 0.3–0.6` (early tiers earned over a season or two); Tiers IV–VI then gated by **population** (tech-grown `K`), so godhood tracks civilization-building. ✓
- **Demographics:** ~0.5 births/yr per fertile pair → gradual growth that **approaches `K`** (not instant); reaching pop 1000 (Tier VI) requires agriculture/construction to raise `K` — i.e. ~centuries of in-game development. ✓
- **Magnitude** spans ~×1.3 (4-gnome camp) → ~×4.6 (20k civ); a malevolent act in that civ ≈ ×6.4 — bounded. "Society-altering" comes from magnitude **×reach**. ✓
- **Tyranny vs shepherd:** malevolent acts hit **×1.4** and fear-devotion ramps fast, but strong terror drives `unrest` to the **0.8 fracture line in ~30–40 days** unless relieved — capping a terror-state's size; a shepherd's gentler acts on a **stable, larger** civilization reach higher **sustained** magnitude. The trade-off is real and falls out of these numbers (guarded by test T16.5). ✓
- **Magic co-evolution** emerges ~40–50 yr into sustained exposure *after* the colony has science — so the arc survive→grow→tech→study-you→predict→harness→resist is correctly ordered. ✓

---

## 18. Seed phenomena catalog — *"the uncanny register"* ⚙️

*The first 15 phenomena, in the chosen mood: **eerie, always ambiguous, unflinching.** Every act has a **mundane reading** the gnomes can hide behind, so belief in you stays contested (and a magic-literate colony rationalizes you away — §13). `event_drama` is kept moderate: dread does the work, not spectacle. This is a **seed set, meant to be extended** freely; it loads as data in Phase 7. Schema per §11; tiers per §10; effects ≈ `[−1,1]`; `s: =culture` = culture-resolved social (§11). Valence spread: **4 benevolent (2 clean / 2 tainted) · 7 malevolent · 4 neutral** — a dark tilt to match the register. **Targets** (§11): point → `ground_remembers`, `standing_stones`, `the_swallowing`, `landslide` · area → `still_air`, `weeping_sky`, `the_quickening`, `the_blight` · region → `long_dark` · region-edge → `coming_herd`, `thing_in_dark` · settlement → `wrongness_blood`, `birds_silent`, `shared_dream`, `day_twice`.*

### ① The Elements
- **The Still Air** `still_air` — neutral · Tier I · int 0.3 / drama 0.3
  *The wind dies for days; a gentle warmth, but total silence — no birdsong.* — mundane: "a calm spell."
  effects `{m +0.2, p +0.1, d 0, b +0.3, s +0.1}` · affordance: any (stronger in harsh weather) · chain → unease @0.05
- **The Weeping Sky** `weeping_sky` — benevolent · *tainted* · Tier I · int 0.4 / drama 0.4
  *Soft rain ends a drought, falling in a too-perfect ring and tasting of iron.* — mundane: "weather turned."
  effects `{m +0.4, p +0.3, d +0.1, b +0.4, s +0.1}` · affordance: active drought / low water · chain → flood @0.10
- **The Long Dark** `long_dark` — malevolent · Tier II · int 0.6 / drama 0.5
  *The sun dims behind a haze for weeks; the cold creeps in and the harvest fails.* — mundane: "volcanic haze, a bad year."
  effects `{m −0.5, p −0.4, d +0.3, b +0.5, s =culture}` · affordance: any (worse pre-harvest / cold biomes) · chains → famine @0.20, → migration @0.15

### ② Earth & Stone
- **The Ground Remembers** `ground_remembers` — neutral · Tier II · int 0.4 / drama 0.5
  *A brief tremor cracks a wall and uncovers something — an ore seam, a spring, a buried bone.* — mundane: "the earth settles."
  effects `{m +0.2 / −0.1, p 0, d +0.4, b +0.4, s 0}` · affordance: any · chain → quake @0.10 *(sometimes the earth doesn't stop)*
- **The Standing Stones** `standing_stones` — benevolent · *clean* · Tier II · int 0.4 / drama 0.5
  *Sheltering rock no one remembers stands at the field's edge by morning.* — mundane: "we never noticed it."
  effects `{m +0.3, p +0.2, d +0.1, b +0.4, s +0.1}` · affordance: any (more valued when exposed/threatened) · chain none
- **The Swallowing** `the_swallowing` — malevolent · Tier II · int 0.6 / drama 0.6
  *The soil gives way and takes a store-hut, a field, sometimes someone.* — mundane: "the ground was soft."
  effects `{m −0.5, p −0.2, d +0.1, b +0.5, s =culture}` · affordance: built-up tiles · chain → cursed-place @0.20 *(the spot turns taboo in memory)*
- **The Sliding Earth** `landslide` — malevolent · Tier II · int 0.6 / drama 0.6
  *The hillside lets go all at once; the scar it leaves glints with ore.* — mundane: "heavy rains, a loose slope."
  effects `{m −0.3, p −0.3, d +0.4 (exposes a lode), b +0.5, s =culture}` · affordance: slope · chains → dam_flood @0.15, → cursed-place @0.20 · **the canonical first act** (design §3.4 worked example; prototype Milestone 2; Phase-7 exit test)

### ③ Life & Growth
- **The Quickening** `the_quickening` — benevolent · *tainted* · Tier III · int 0.5 / drama 0.4
  *The fields surge; fruit ripens overnight, a little malformed, but it feeds them.* — mundane: "a good year."
  effects `{m +0.5, p +0.4, d +0.1, b +0.4, s +0.1}` · affordance: farmland / growing season · chain → soil-exhaustion @0.10 *(the surge takes its due)*
- **The Blight** `the_blight` — malevolent · Tier III · int 0.6 / drama 0.5
  *Crops blacken, stores rot, the herd wastes.* — mundane: "crop disease."
  effects `{m −0.6, p −0.3, d +0.3, b +0.5, s =culture}` · affordance: farmland / stored food · chain → famine @0.20
- **The Wrongness in the Blood** `wrongness_blood` — malevolent · Tier III · int 0.6 / drama 0.6
  *A sickness no one can name moves through the gnomes; it takes the old and the small.* — mundane: "a fever passed through."
  effects `{p −0.6, m −0.1, d +0.4, b +0.6, s =culture (strong swing)}` · affordance: crowding ≥ threshold · chains → scapegoat/schism @0.15, → medicine @0.10 · *at high M → civilization-scarring pandemic*

### ④ Beasts & Creatures
- **The Coming of the Herd** `coming_herd` — benevolent · *clean* · Tier III · int 0.4 / drama 0.4
  *Animals arrive unafraid and watchful — food, beasts of burden, or an omen.* — mundane: "migration season."
  effects `{m +0.4, p +0.2, d +0.2, b +0.4, s +0.1}` · affordance: near wilds · chain → predator-follows @0.10 *(what trails the herd)*
- **The Thing in the Dark** `thing_in_dark` — malevolent · Tier III · int 0.5 / drama 0.6
  *Something stalks the treeline and takes the unwary; the tracks are wrong.* — mundane: "a wolf, a bear."
  effects `{p −0.3, m −0.1, d +0.2, b +0.5, s =culture}` · affordance: near wilds / at night · chain → hunt-heroism @0.15 *(whoever slays it gains notability → leader/prophet seed)*

### ⑤ Omens & Signs
- **The Hour the Birds Fell Silent** `birds_silent` — neutral · Tier IV · int 0.3 / drama 0.5
  *A sign with no substance — a bruised sky, a two-headed calf, a star where none was.* — mundane: "an ill-omened day."
  effects `{m 0, p 0, d +0.1, b +0.6 (read as warning OR blessing per current theology), s =culture}` · affordance: any — **pure belief lever, no material cost** · chain → raises local |awe−fear| (**seeds prophets**, §12)

### ⑥ Visions & Dreams
- **The Shared Dream** `shared_dream` — neutral · Tier V · int 0.5 / drama 0.6
  *The whole settlement dreams one dream in a night and wakes knowing the same word.* — mundane: "a strange night."
  effects `{m 0, p 0, d +0.2 (a dream can reveal a technique), b +0.6, s =culture}` · affordance: any · chains → rite-crystallizes @0.20 (cohesive) | → schism-seed @0.15 (divided)

### ⑦ Wonders & the Uncanny
- **The Day That Came Twice** `day_twice` — malevolent (awe/dread) · Tier VI · int 0.9 / drama 1.0
  *The day happens again — the same dawn, the same words, the same death — and only some notice. It does not prove you; it breaks minds and hardens deniers.* — mundane: collapses, yet yields **madness and denial**, not proof.
  effects `{m 0, p −0.2 (panic/madness), d +0.1 (some shatter, a few leap), b +0.9, s =culture (the strongest swing)}` · affordance: Tier VI, rare · chains → mass-conversion @0.25 (faithful) | → heresy/schism @0.25 (divided) | → touched-births echo next generation · **elevated tail-risk** *(reality-breaking on a civilization is catastrophic or transcendent)*

> **How it plugs in:** each entry's `event_drama` drives the attribution seed (§9) — moderate here, so primitive colonies invent you and magic-literate ones explain you away; `base_intensity·magnitude(M)·valence_potency` (§11) sets the resolved force; crises carry `s: =culture` so the *people* decide whether catastrophe bonds or breaks them; and tail-risk scales with social mass, so the same act is a footnote in a hamlet and a cataclysm in a civilization. Extend this set per category as new tiers and tech open up.

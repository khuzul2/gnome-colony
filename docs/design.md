# Gnome Colony — Design v1.4 (project review v3 applied)

*A 3D evolving sandbox where you play a **mysterious, near-omnipotent but blind force** tending a society that can grow from a handful of founders to tens of thousands of autonomous gnomes. You never command them. You experiment on the **world** — weather, earth, omen — discovering your own powers by trying them, never quite safe from your own consequences. Each gesture ripples through the gnomes' bodies, minds, and culture, and is woven into an emergent story about **what kind of god you are** — a story you only half-author.*

Engine target: **Godot 4.7** (stable, June 2026), Jolt physics, stylized low-poly.

> **Locked so far:** **Force-of-nature** control (pure indirect, no command channel) · **Epochal scale** — start **3–5 gnomes**, grow to **tens of thousands** across emergent **cities & settlements** · deepest **evolving** axis (**cultural transmission**) · **fully emergent institutions** · lens is **aggregate-primary with frequent individual zoom** · an **eerie-uncanny, always-ambiguous, unflinching register** (bittersweet as aftertaste — 1.8b) · **emergent theology** (they may invent you; what god you become is their story) · **near-free intervention** governed *diegetically* by always-on trade-offs, tail-risk cascades, and over-meddling trauma · **mysterious outcomes** discovered by experimentation · a **devotion-gated, expanding toolbox** (tiny core → wide categorized arsenal) · **universal tail-risk** (every act can misfire) · prophets **seeded via omens**, free but always risky · **hybrid belief model** (scalar substrate that crystallizes into named beliefs) · **valence-neutral devotion** (love *or* terror) whose *depth* (per-capita) **unlocks** the toolbox and whose *total weight* (social mass) **scales the magnitude** of every effect and misfire — with **terror-faith more potent but unstable, love-faith gentler but sustainable** (the balanced temptation) · **lifespan ~15–30 min at 1×** on a 96-day seasonal calendar (fast-forwardable) · **mid-fidelity, culture-shaped relationships** · **light founding** (scenario + broad leanings) · **the Eye of God** (focusing on an area quickens those gnomes to full fidelity and *changes their fate by design* — 2.4) · **outlier gnomes** (geniuses, the touched, mutants) injected as engines of divergence (1.7) · a **morally-balanced toolbox** (good/neutral/evil in proportion, 3.1) · **emergent leadership** (1.5) · **a still world** — no dramatic event has any author but you (1.8b) · the Eye is **dwell-based** (2.4) · at total extinction the run **ends in a Chronicle** (1.9).
>
> The centerpiece of this version is **Part 3 — The Influence System**, per your steer. Open forks are marked **→** and gathered at the end of each part.
>
> **Companion specs:** `gnome-colony-prototype-spec` (first buildable milestone) · `gnome-colony-evolution-algorithm` (all parameters & mechanics; **§17 = consolidated tuning baseline**) · `gnome-colony-setup-and-menus` (new-game options, tuning sheet, main menus & settings) · `gnome-colony-implementation-plan` (phase→task→test build plan for an agent loop) · `gnome-colony-loop-howto` (Claude Code multi-agent loop setup).
>
> **How to read this set:** this doc (intent) → evolution-algorithm (mechanics — **§17 is the single numeric truth**; if prose and §17 disagree, §17 wins, and numeric edits must change both together) → implementation-plan (process) → setup & prototype → loop-howto. *(Parts below run 1 → 3 → 2 deliberately: the gameplay, then the influence system it exists for, then the architecture underneath.)*
>
> **Design status (v1.4 — DESIGN-COMPLETE; project review v3 applied):** both additions are now fully resolved. **Epochal scale** (3–5 → tens of thousands across emergent cities & settlements) rides a hierarchical individual→settlement→civilization simulation (2.4), with a **rich emergent civilization tier** (trade, schism, war). **Autonomous technology & magic** (1.11) lets the colony research on its own, lose knowledge to dark ages, and ultimately **reverse-engineer and resist you** while still worshipping you. Only implementation-time technical calls remain (2.9). Ready to build.

---

## Part 1 — Gameplay

### 1.1 The vision: a blind god, slowly invented

You begin with 3–5 founder gnomes and may grow a society into a civilization of tens of thousands. You cannot tell anyone what to do — you act *on the world*: rain, shifting ground, a strange light across the sky. You don't fully know what your powers will do until you try them, and you're never quite safe from their consequences. The gnomes experience your acts as nature and portent; their **autonomous psychology and culture** turn them into behavior, story, and — over generations — a **theology about you**. What kind of god you are is something *they* decide from the pattern of your deeds, and that verdict then colours how they read everything you do next.

Closest in spirit to **From Dust × Reus × Dwarf Fortress**, with **Frostpunk's** moral weight on every decision. Not *one life* (The Sims) — *a civilization's body and soul, and its gods*.

The defining promise:

> **You set the stimulus; gnome psychology is the transfer function; culture is the output.** You can cause a landslide. You cannot make them mine the iron it reveals, mourn the dead, or fear the mountain — that is theirs.

### 1.2 The core loop

1. **Read the colony** as trends and pressures (aggregate lens): population, mood, what knowledge is fragile, what they currently believe, where stress is building. Zoom into individual gnomes whenever a story catches your eye.
2. **Weigh a fraught decision** — every intervention is a gamble across multiple axes (Part 3.2). *Drought to drive them toward the river? A landslide for iron, knowing it will kill and frighten?*
3. **Act on the world** — trigger a phenomenon or apply a slow pressure.
4. **Run time** (fast-forward) and watch the appraisal → behavior → belief chain unfold.
5. **React** to the aftermath and the new situation your act created (often ironic — see 3.4).

The satisfaction is complicity: *you* caused the miracle and the tragedy, and you live with both.

### 1.2b The opening minutes (the intended first session)

Minute 0: **an arrival, unexplained** — a handful of gnomes step out of the treeline into the starting basin. No origin story is given, to them or to you; they simply begin. Minutes 1–10: you mostly **watch** — needs, small choices, first bonds — while trying your two or three **Tier-I acts** (a soft rain, a still day) and learning that effects are *read*, not commanded. By the first season's end, a **first hardship** (seasonal scarcity, or your own first drought) makes the loop legible: pressure → behavior → story. Across seasons 2–3 comes the first act dramatic enough to be *noticed as willed* — the **first attribution** ("an unseen will") — and soon after, the **first crystallized belief** (a revered spring, a feared ridge): the de-facto tutorial payoff. By the first winter a colony that believes *something* about the world you've been shaping, and Tier II within reach. This beat is what Playtest Gate 1 judges and Gate 4 onboards.

### 1.3 The player's role — force of nature (locked)

You act only through the world and its portents. You have **no command channel** at all — not even "designate a spot." Institutions, jobs, and gatherings are entirely emergent (1.5). Your toolkit is Part 3.1; the rule that makes it honest:

> Every lever changes **the world or its omens** — terrain, resources, hazards, weather, signs. None ever changes a gnome's decision directly. Psychology and culture are sovereign.

### 1.4 The gnome life cycle

The spine. Each stage gates behavior and is a vulnerability surface for your phenomena:

| Stage | What's happening |
|---|---|
| **Infant** | Dependent; first bonds; most fragile to hardship. |
| **Child** | Plays, explores, **absorbs culture & belief**; affinities surface. |
| **Adolescent** | Learns crafts from elders; identity & standing form; first romances. |
| **Adult** | Works, courts, partners, raises children, **teaches**, may lead or interpret omens. |
| **Elder** | Prime **knowledge & belief transmitter**; productivity falls, prestige can rise. |
| **Death** | Age/accident/illness/your phenomena; triggers grief, inheritance, **possible permanent loss of what they alone knew or believed**. |

### 1.5 Emergent institutions (locked: fully emergent)

No "build school" button — not even an indirect one. Gnomes carry small instincts: *teach the young near me*, *gather where others gather*, *return to places tied to strong memories*. A "school," a "shrine," a "workshop quarter" is a **pattern the simulation detects**, never an object you place. You influence whether such patterns can form only by shaping conditions (keep elders alive, make a place safe and central, let a belief take root). This is the hardest system in the game and the most rewarding when it works (Part 2.5, Open Q's). **Leadership emerges the same way:** ambitious, charismatic, high-standing gnomes become the de-facto leaders of a settlement, and leadership quality feeds coordination, institution-formation, and a settlement's strength in war (algorithm §14) — no leaders are ever appointed by you.

### 1.6 What's inside a gnome

- **Needs** — hunger, rest, social, safety, and **purpose/fulfillment** (work, learning, teaching carry emotional weight).
- **Traits / personality** — bias appraisal and choice (a brave gnome investigates a landslide; a timid one flees and spreads fear). Partly inherited, partly shaped by upbringing & culture.
- **Skills & knowledge** — grown by being taught; the unit of cultural transmission; can go extinct.
- **Beliefs** — what this gnome holds true: taboos, omens' meanings, reverence or dread of places, and possibly of *you* (3.3). A first-class consequence channel.
- **Relationships** — the graph that knowledge and belief flow along. **Mid fidelity (locked):** bonds form from proximity + shared experience + trait compatibility → partnership → children; no dating-sim minigame, but rich enough for lineages, rivalries, and grief. **Mating norms are culture-shaped** — emergent taboos or status rules (cross-sect unions shunned, prestige pairings) fall out of the belief system almost for free.
- **Memory** — notable events it witnessed, coloring future appraisal and the stories it tells.

### 1.7 The "evolving" axis — all three layers (locked)

Four stacking layers: per-gnome growth · **genetic inheritance** (traits + mutation under the selection pressure *you* apply via the environment) · **cultural transmission** (knowledge *and belief* spreading and outliving individuals) · **material/technological progress** (the colony autonomously discovers technology and unravels magic — 1.11).

**Outlier gnomes — the engine of divergence (locked).** Plain blending inheritance would slowly homogenize the gnomes toward an average. To keep populations *interesting and divergent*, rare **outliers** are born: **geniuses** (who leap tech and craft forward), the **touched** (mentally atypical — visionaries and madmen, prime prophet material), **mutants** (heavy physical/heritable mutation — founders of strange new lineages, often revered or shunned), and other extremes (the unnaturally long-lived, the giant, the barren). They carry trait values *outside* the normal band, some heritable, and they reshape culture, tech, and belief around them. Outliers are how a flat gene pool keeps throwing up the exceptional — and a steady source of zoom-in stories (algorithm §8).

Headline phenomena: cultural drift, knowledge **and tech** extinction (now **per-settlement** — a craft can die in one city while another keeps it, so dark ages are *regional* and recoverable via trade/migration), regional subcultures, golden ages and dark ages, emergent belief systems that reinterpret your every act, and — at the far end — a civilization that begins to **understand and even wield the forces you act through.**

### 1.8 Scale, time, tone

- **A vast dynamic range — 3–5 → tens of thousands.** You begin with a tiny band you know by name and may, over many generations, tend a **civilization** of tens of thousands spread across **cities and adjacent settlements**. Cities are *emergent* (like institutions): hamlets thicken into villages, towns, cities; new settlements are founded as population and your pressures push gnomes over the passes into fresh basins. At the top, individuals necessarily blur into demographics — which is exactly why fate-scale indirect control fits, and why the lens runs **civilization → settlement → individual** (1.7c).
- **Time** decoupled from FPS: pause / 1× / fast-forward (generational payoff needs heavy fast-forward). **A life ≈ 15–30 min at 1× (locked)** — short enough to *watch* culture drift across generations, long enough to zoom into one gnome and care. Runs on a **seasonal calendar** so weather levers and emergent festivals have rhythm.
- **Tone:** the locked register lives in **1.8b** — eerie-uncanny, always ambiguous, unflinching; the bittersweet ache is its aftertaste.

### 1.8b Tone & register (locked)

**Primary register: eerie & uncanny.** The world is beautiful the way a too-quiet forest is beautiful; wonder and dread share a border.

- **Always ambiguous (a content-authoring rule):** every phenomenon must ship with a **plausible mundane reading** — "heavy rains, a loose slope," "a fever passed through" (see the catalog, algorithm §18). The gnomes can never be *sure*; belief in you stays forever contested, which keeps theology alive (3.7) and lets the magic-literate explain you away (1.11).
- **A still world (locked — sole authorship):** nature supplies *pressures* — seasons, scarcity, aging, accident — but **never events**. Nothing dramatic happens unless you do it. The ambiguity above is therefore *theirs, not yours*: the skeptic gnome is rationally justified and factually wrong, and can never know it. Every tragedy and every miracle in their history is yours — total complicity is the point.
- **Unflinching:** plague, famine, and grief are real, on-screen consequences, never sanitized — but the camera aches, it doesn't wallow: dread over gore, loss over spectacle.
- **Bittersweet is the aftertaste, not the register:** loss lands *with meaning* — a craft dies with its last elder; the taboo now starving them was born of mourning *you* caused.

### 1.7c The lens — civilization → settlement → individual

At epochal scale the player reads the world at three zooms: a **civilization map** (settlements, migration, the spread of culture/tech/faith, demographic & mood heatmaps) → a **settlement view** (a city's population, institutions, tech, beliefs, leaders) → an **individual** (one gnome's life, when a story pulls you in). Aggregate-primary, with the intimate zoom always one click away — the same lens that makes indirect control legible across four gnomes or forty thousand.

### 1.9 Goals & failure

Open sandbox, no win screen; set your own ambitions (a 10th generation, a great craft, a faith, surviving a cataclysm). **Failure is real:** the colony can dwindle, starve, or suffer cultural collapse. Emergent crises act as self-generated objectives — at small scale a famine, a feud, a dying craft; at civilization scale **holy wars between cities, schisms, a mage-led revolt against you, or the collapse of an over-extended empire.**

**The end (locked):** should the last gnome die, the run **closes**. The camera holds on the empty world for a breath — hearths cooling, shrines to you still standing — then the **Chronicle**: an auto-generated history of everything they were (generations, settlements, faiths and their prophets, wars, discoveries, and how it ended), exportable and kept in the main menu (setup §6). No new band arrives; what is gone is gone. (Built from the telemetry the sim already keeps — plan T16.3.)

**Founding (locked):** light setup — pick a **scenario / seed** and a couple of **broad leanings** (hardy mountain folk vs. curious wanderers); the rest is random. Distinct each game, a little authorship, but you still *discover* who they become.

### 1.10 Open questions (Part 1)

*All resolved.* Lifespan, relationship fidelity, and founding are locked above; world generation is locked in 2.7b.

---

### 1.11 The colony evolves itself — technology & magic (locked)

The colony **researches autonomously**. Consistent with everything else, you never pick what they study — you shape the *pressures* that make discoveries likely. Technology and magic are both treated as **knowledge** (2.6): held by gnomes, taught along the social graph, inheritable across generations, and — crucially — **losable**. A craft or a science can go **extinct** in a plague or a dark age, then be painfully rediscovered. **Writing** is the pivotal discovery that makes knowledge durable (records survive the deaths of those who knew), bending the whole game away from fragility.

**What drives a discovery:**

- **Necessity** — and *you* are the great author of necessity. Drought pushes irrigation and wells; a flood-prone basin pushes levees and boats; a beast-plagued frontier pushes weapons and walls; cold pushes fire-craft and shelter. Your phenomena are the colony's research agenda, indirectly.
- **Curiosity** (a trait), **surplus & leisure** (a thriving colony has time to wonder), **prerequisites** (fire and stone before smithing), **population** (more minds, faster), and **emergent institutions** (a school or guild accelerates a field).

**Discoveries reshape society** — each rewrites the simulation's parameters and unlocks new behaviors and structures: agriculture → settlements and population booms; writing → durable knowledge and law; metallurgy → tools, weapons, trade goods; medicine → longer lives; construction → towns and cities; sail → crossing water to new basins. The material layer of the "evolving" axis.

**Two branches:**

- **Technology** — mastery of the *mundane* world. Straightforward, cumulative, world-shaping.
- **Magic — the colony studying *you*.** This is the special one. A curious, advanced colony slowly **reverse-engineers the forces you act through**, co-evolving along a path: raw **superstition** ("the god is angry") → a **proto-science of the divine** (patterns: landslides cluster on the eastern fault; the god's wrath follows *this*) → **prediction** (astronomers foretell the eclipse you meant as an omen — and your omens lose their power over an enlightened people) → **harnessing** (ritual that *works*; shamans and mages who produce minor phenomena; wards that blunt your acts) → **resistance** (sacred ground and heretics that defy you). The created reaching toward the power of the creator — potentially the richest late-game in the design.

**Full co-evolution (locked):** the path runs all the way to **channelling, warding, and resisting** — a civilization of mages who can challenge their god. The twist is that this is driven by *capability*, not apostasy: material and scientific progress erodes devotion only **mildly** (faith and science largely coexist), so you can face **devout heretics** — gnomes who worship you utterly and still raise wards against your floods. Your absolute power isn't undone by their enlightenment, but it stops being *unanswerable*. A late-game civilization is something you tend in dialogue with, not simply over.

**All locked:** magic reaches **full co-evolution** (channel / ward / resist); secularization is **mild** (devout mages are possible); technologies and knowledge **can be lost** (dark ages) until **writing** makes them durable.

## Part 3 — The Influence System  *(the core, per your steer)*

> The pipeline in one line: **Phenomenon → (world change + stimulus) → per-gnome appraisal → behavior → storytelling → culture & belief → new situation.** You only ever touch the first step.

### 3.1 The toolbox — a devotion-gated, expanding arsenal (locked)

You start with a **tiny core** (a handful of gentle, legible acts — e.g. rain, a warm season, a single small omen) so a new player learns the cause→appraisal→belief loop without drowning. The toolbox then **widens as your myth grows** (see *Devotion*, 3.1b): the more — and the more *dramatically* — the colony believes in you, the more of the arsenal unlocks. A purple moon or a rain of blood is not something a colony that barely believes can even perceive as *yours*; you earn the right to wield it.

**Seven categories (locked)**, each carrying both a *kind* and a *cruel* face (nothing is a pure-good button), ascending roughly in the devotion order they unlock:

1. **The Elements** — rain, storm, hail, drought, heat, cold, fog, seasons; flood, spring, river-shift, freeze, deluge, dry-up. Sky & water; broad material/comfort pressure. *Earliest.*
2. **Earth & Stone** — landslide, quake, sinkhole, eruption, erosion; reveal or bury ore. Sudden, terrain-reshaping, resource-revealing.
3. **Life & Growth** — fertility, bloom, bountiful harvest, fertile soil, a sacred grove… and blight, rot, famine. The biosphere & agriculture lever.
4. **Beasts & Creatures** — a migrating herd, a summoned guardian, a monster from the deep, a vermin swarm, a sacred animal. Gift or terror; totem-fuel; a hunt; a plague vector.
5. **Omens & Signs** — eclipses, auroras, comets, a raven's deed, stars aligning. **Change meaning, not matter.** Seed and steer prophets (3.9). *Mid.*
6. **Visions & Dreams** — dreams, nightmares, prophecies, callings, inspiration, madness, an apparition to one chosen gnome. Acts directly on minds; anoints or breaks individuals. *High.*
7. **Wonders & the Uncanny** — a purple moon, rain of blood, weeping ground, a pillar of light, a miracle. Reality breached; massive belief impact; the powers only a true god commands. *Highest.*

Categories 1–4 act on the material world, 5–7 on the world of belief; devotion both unlocks the higher tiers and amplifies every effect (3.1b).

**Casting (locked):** choose the act, paint *the where*, release. Each phenomenon declares its **target kind** (algorithm §11/§18) — a point, an area, a settlement, a region-edge (where beasts enter), or, for Visions only, a **single gnome**. No preview, no undo (3.8).

**Moral balance of the arsenal (locked).** Every category offers acts of three valences — **benevolent** (bountiful harvest, healing spring, mild season, guardian beast, a protective wonder), **malevolent** (drought, blight, monster, plague, rain of blood), and **neutral/ambiguous** (a revealed lode, a migrating herd, an eclipse, a vision). Two things keep the moral choice live: (1) **balanced availability** — an even spread of valences in every category, so a shepherd-god is never starved of powerful tools; and (2) **a deliberate asymmetry of power vs risk** — **malevolent acts hit *harder* per use** (the temptation), but terror-faith is *unstable* (unrest, heresy, schism, collapse), while **benevolent acts are gentler** but build *stable, compounding* devotion (3.1b). So cruelty is genuinely tempting, never strictly optimal; kindness is slower, never under-armed.

### 3.1b Devotion — your growing myth (locked: the progression spine)

**Devotion** = how many gnomes believe a will is behind events, and how strongly. It is your **progression currency**, and it gates the toolbox.

- **It bootstraps and grows** by **intervention**: dramatic, inexplicable acts get attributed to *an unseen will* (you) — readily in a primitive colony, less so once it grows magic-literate (the *attribution seed*, algorithm §9). Answered prayers, well-timed boons, and awe-inspiring omens then deepen belief fast.
- **It is valence-neutral in what it unlocks, but the two flavors behave differently (locked):** a colony can be devout out of **love** *or* **terror**, and either unlocks the same tiers. But **terror-faith is fast, more potent per act (algorithm §11), yet volatile and instability-taxed** (unrest, heresy, schism, collapse), while **love-faith is slower and gentler but stable, compounding, and resilient**. This decouples **power from wellbeing** — a tyrant-god seizes burst power atop a miserable, fragile society; a shepherd-god grows a flourishing, sustainable one. Both are valid; each trades off. This *is* "what god you become is their story," made mechanical.
- **It does two things, by *two different measures* (locked):** the **depth** of belief (per-capita devotion) **unlocks** the toolbox by tier — and unlocking **ratchets** (a baby boom dilutes average faith but never strips a power you earned) — while the **total weight** of belief (social mass) **scales the magnitude** of every effect. Depth gates *what* you can do; mass gates *how hard* it lands.
- **Social mass = total devotional weight (locked).** This multiplier scales *both* your intended effects *and* your tail-risk misfires. Low mass: gentle acts, footnote accidents (two gnomes brawl, nobody cares). High mass: the *same* act lands like a cataclysm, and a stray misfire becomes an **unintended riot or an ecstatic mass-celebration that reshapes society overnight.** Power and danger rise together — late-game is a high-wire act. The difficulty curve is *emergent*, not scripted.
- **The tension with the governor (3.6):** intervening raises devotion (more reach) but risks breeding **fear-devotion** and trauma, and raises social mass (so every future act/accident is more dangerous). You are always trading wellbeing and stability for power.

### 3.2 The consequence axes (every act is a vector across these)

No lever is pure-good. A phenomenon spreads, **mostly indirectly**, across:

1. **Material** — resources revealed/buried/destroyed; terrain & navmesh reshaped; shelter gained or lost.
2. **Population** — deaths, injuries, displacement; or, later, a fertile season's births.
3. **Discovery & knowledge** — a chance to learn something new (iron!), or knowledge lost when a holder dies.
4. **Belief & psychology** — fear, awe, fatalism, courage, superstition; new taboos, omens, reverence or dread — **emergent, not a slider you set**.
5. **Social structure** — status shifts, factions, migration, isolation, the rise of an interpreter/leader.

Design rule: **you author the cause, never the effect.** A landslide *exposes* iron; it does not grant it. Discovery, mourning, and fear are the gnomes' to produce.

### 3.3 The influence → behavior pipeline (the mechanism you asked to shape)

1. **Phenomenon** — you act. It mutates **world state** (terrain/resources/hazards) and/or emits a **stimulus** (witnessable event with type, place, intensity).
2. **Appraisal** — each affected/witnessing gnome reads the stimulus *through its traits + current beliefs + culture + its theology about you* (3.7), producing emotional and belief deltas and a memory. The same landslide reads as *opportunity* to a curious miner, *the god's wrath* to a people who already decided you're cruel, *a trial* to a people who decided you're testing them. **This per-gnome interpretation, fed by who they think you are, is the soul of the system.**
3. **Behavior** — those deltas reweight the gnome's **utility scoring** (Part 2), so different actions win. Fear becomes avoidance of a place; awe becomes pilgrimage; hunger from drought becomes migration.
4. **Storytelling & propagation** — gnomes carry interpretations and pass them along the social graph (the same machinery as knowledge). A frightened witness seeds a fearful story; it spreads, mutates, and may **crystallize into shared culture** — a taboo, a ritual, a revered or cursed place.
5. **New situation** — the aggregate of behaviors and the new culture is a changed colony, which is your next canvas (3.4).

You set step 1. Steps 2–5 are sovereign. That separation *is* the design.

### 3.4 Worked example — the landslide (your example, fully traced)

You drop a **landslide** on the eastern ridge.

- **Material:** rock face opens, **exposing an iron seam**; a path is buried.
- **Population:** three gnomes caught; **two die, one is injured.**
- **Appraisal split:** a *curious* miner-type eyes the strange new ore; *timid* and *grieving* gnomes read it as the mountain's wrath.
- **Behavior & propagation:** the fearful stories spread faster (fear is loud). A **taboo against the eastern ridge** crystallizes — and now **gnomes avoid the very iron you exposed.** Superstition rises colony-wide; the dead gain reverence.
- **The new situation (the gameplay):** to unlock the iron you created, you must now *shift belief* — a fair season and a good omen (aurora) over the ridge to recolor it from cursed to blessed, or simply wait for a braver generation. Your intervention created its own follow-on puzzle.

That **cause → tragedy → belief → ironic obstacle → new intervention** loop is the game in miniature — and it lands in the intended register: uncanny, ambiguous, and it aches.

*And on a slim roll (3.9):* the slide doesn't stop — it dams the stream, the valley floods over a season, and the colony you were enriching must flee. You meant to give them iron.

### 3.5 Design principles

- **No pure-good lever.** Even rain risks flood, rot, or complacency. If a lever has no downside, cut or weaken it.
- **Indirect, not scripted.** Effects are possibilities the gnomes realize, not grants.
- **Mystery by design.** You are *not* shown odds or predicted outcomes. You learn what a phenomenon tends to do by *trying it* and watching (3.8) — mastery is hard-won intuition, never certainty.
- **Every act can misfire, and misfires scale (universal tail-risk).** *Any* intervention, however gentle, carries a slim chance of a weird, unintended consequence or cascade (3.9) — and its size grows with your **social mass** (3.1b). You are never fully safe from your own hand, and the bigger your myth, the less safe you are.
- **Belief is a first-class outcome,** as important as resources — and it can fight you (the taboo above).
- **Restraint is enforced from within,** not by a meter (3.6).
- **Legible in hindsight.** You can't predict, but you must always be able to *trace* what happened afterward — the feedback layer (2.7) is what makes mysterious, cascading outcomes feel fair instead of arbitrary.

### 3.6 The governor — why you don't just spam miracles (locked: diegetic)

There is **no mana bar and no cooldown.** Intervention is near-free *to trigger* — but never free in consequence. Three forces hold your hand:

1. **Always a trade-off (3.2).** Every act spends something real — lives, trust, stability, a craft — even when it also gives.
2. **A sky that never rests breeds a fearful people.** Frequent disasters pile grief and dread onto the colony, and through the theology system (3.7) they invent a **wrathful, capricious god**. The result is a traumatized, superstitious, paralyzed culture — a colony that's genuinely worse to tend. Over-meddling punishes *itself*, in the gnomes' own minds.
3. **Tail risk (3.9).** *Every* act — even a blessing — carries a slim chance of a weird, outsized consequence you didn't intend. The more you act, the more often you roll those dice.

And yet intervention is also how **devotion** (3.1b) grows and your toolbox widens — so every act pulls you between *reach* and *wellbeing*. Restraint is a *strategy the systems reward*, never a rule the UI imposes — exactly your steer.

### 3.7 Emergent theology — being invented (locked)

The colony slowly builds a **belief-object about you**, assembled from the *pattern* of your deeds as they appraised them. It has emergent dimensions, e.g.:

- **Existence** — do they even believe a will is behind events, or is it all impersonal nature? (May never crystallize; may split believers from skeptics. *And in truth every dramatic event **is** yours — 1.8b: the skeptic is rationally justified, factually wrong, and can never know it.*)
- **Character** — benevolent / wrathful / capricious / testing / indifferent, inferred from *when and how* you act (rescuing them in famine vs. striking them down).
- **Response** — do they appease (rituals, offerings, sacrifice), petition (build shrines, send up signs *to* you), defy, or ignore?

Two loops make this the spine of the game:

- **Feedback into appraisal (3.3):** their current theology recolours how they read your *next* act. Your reputation is the lens on your future.
- **A two-way channel (locked):** their petitions — shrines, offerings, signs sent up in a drought — never compel you, but the feedback layer lets you *perceive* them, and "answering" one is simply choosing to act in response (rain after a rain-prayer). *They* draw the line from prayer to rain; you never command. Answer and you author a faith; ignore and you author an absence. This wordless dialogue is the main way you steer your own theology.

Subcultures can invent **different gods of the same events** → schisms, heresies, rival rites. This is some of the richest emergent narrative in the design.

### 3.8 Mystery & discovery (locked: discover by trying)

You are a natural philosopher of your own powers. The UI shows **no predicted effects or odds**. You try a phenomenon, witness what it does *here, now, to these gnomes*, and build a *feel* for it over time. **No precise almanac** — instead the game keeps only **faint, qualitative impressions** ("the earth sometimes hides metal"; "storms here have frightened them before"), nudges and half-memories that aid intuition without ever dispelling the mystery. Mastery stays a hunch, never a formula.

### 3.9 Cascades & prophets — the dominoes (locked)

Two mechanisms deliver "a slim chance of highly unexpected consequences."

**Physical chains** — phenomena can trigger phenomena (landslide → dam → flood; drought → tinder → wildfire; flood → blight → fever). Mostly small, occasionally runaway.

**Prophets — your most powerful, least controllable lever.** A prophet is a special gnome who can swing a whole culture. The crucial rule: **you can seed one, but you cannot control it.**

- **Seeding (free, via omens):** you nudge a prophet into being through **omens / manifestations** (cat. 5 & 6) — a calling, a mark, a portent at a birth. You choose roughly *when*, never *who*, *what they'll preach*, or *how they'll end*; the message emerges from the colony's theology, the triggering event, and the prophet's hidden traits. Seeding costs no resource, but — like every act — carries the **universal tail-risk**, and only *catches* where conditions are emotionally ripe.
- **An unpredictable life-arc:** a prophet rises, peaks, and declines *over their whole life*, and the player can't see their strength or read their future — only watch the effects unfold and react. A prophet born into a terrified, wrathful-god colony might, in their early years, **turn the fear around** and remake the god as merciful… then, on a slim roll, **go mad** and demand self-sacrifice, persecution, zealotry. You don't get to stop them.
- **Indirect steering (influence, not control):** you bend a prophet only through the world — **omens that confirm or contradict their message.** Send a good omen and you validate the prophet preaching mercy; send a disaster and you undercut them (or, cruelly, *prove* the doom-prophet right).
- **Rival prophets & schism:** seed a second prophet to counter a maddened first, and you get **competing cults, heresies, and — if it escalates — religious civil strife.** Timed well, a single prophet reshapes society; **spammed, prophets shatter the faith into warring sects.** Same diegetic governor: overuse is its own catastrophe.

Prophets are the richest source of zoom-in stories and the highest-variance tool in the game — a desperate, double-edged way to repair (or doom) a theology you bent out of shape.

### 3.10 Open questions (Part 3)

*All resolved.* The toolbox is the seven granular categories above (3.1).

---

## Part 2 — Architecture

### 2.1 The principle (mandatory at this scale)

> **Separate simulation from presentation.** The colony's truth is a plain-data, headless-capable **simulation core**; 3D gnomes are puppets that read from it. Required for fast-forward, save/load, testing, and reaching civilization scale (tens of thousands).

### 2.2 Engine & language

Godot 4.7, Forward+, Jolt, low-poly. **GDScript** for logic and iteration; isolate hot paths (abstract population tick, culture/belief propagation, appraisal batches) behind clean interfaces so they can move to **C#/GDExtension** after profiling. (Open Q.)

### 2.3 Layered architecture

```
┌───────────────────────────────────────────────┐
│ PRESENTATION                                   │
│  • GnomePuppets (visible/LOD-0 only)           │
│  • Aggregate & belief UI: mood/knowledge/belief │
│    maps, lineage, AFTERMATH & "what they now    │
│    believe" feedback                            │
│  • Camera + INFLUENCE controls (phenomena)      │
└───────────────────────────────────────────────┘
            ▲ reads        │ phenomena (world-only)
            │              ▼
┌───────────────────────────────────────────────┐
│ SIMULATION CORE (plain data, headless)         │
│  • Colony registry (all GnomeData)             │
│  • INFLUENCE→BEHAVIOR PIPELINE:                 │
│      Phenomenon → world change + Stimulus →     │
│      Appraisal(traits,beliefs) → utility shift →│
│      behavior → interpretation propagation      │
│  • CULTURE & BELIEF system (knowledge + belief  │
│    graph; teaching, drift, loss, taboos)        │
│  • AI: life-stage FSM → utility scorer → tasks  │
│  • Systems: needs, social, reproduction, aging  │
│  • LOD MANAGER (full vs abstract gnomes)        │
│  • TimeService · EventBus · Cascade engine     │
└───────────────────────────────────────────────┘
            ▲              ▼
┌───────────────────────────────────────────────┐
│ WORLD / SPATIAL                                │
│  • Terrain, navmesh, resources, hazards;       │
│    place-tags carry emergent belief (cursed/    │
│    blessed) that bias gnome utility             │
└───────────────────────────────────────────────┘
                     │
               ┌───────────┐
               │ SAVE/LOAD │ Colony + Culture/Belief + World
               └───────────┘
```

### 2.4 Hierarchical, multi-scale simulation (what makes tens of thousands possible)

You cannot run AI for tens of thousands of agents. The only way to the target scale is to **simulate at the coarsest level that preserves the story**, promoting detail only where attention or notability demands. Four nested tiers:

- **Individual — LOD-0 (full):** a *bounded cast* — **attention-local** gnomes (those under the Eye, 2.4) plus notable figures (leaders, prophets, the lineage you're following) — with real navmesh pathing, full appraisal & utility, animation.
- **Individual — LOD-1 (cheap):** nearby off-screen gnomes — simplified decisions, coarse movement.
- **Individual — LOD-2 (abstract):** local-but-unwatched gnomes — needs, work, teaching, reproduction, **and appraisal** advanced **statistically in batches**, no scene node; materialize into puppets only when looked at.
- **Settlement tier (statistical):** once a place holds more gnomes than is worth simulating singly, it becomes an **aggregate entity** — population by life-stage, trait & skill distributions, culture/belief/theology aggregates, **tech level**, economy, mood. Births, deaths, migration, teaching, and discovery run as **flows and statistics**, not per-agent. Individuals **promote** to LOD-0/1 when the **Eye of God** falls on them or when one becomes notable (a prophet emerges), and **demote** back to statistics when attention moves on.
- **Civilization tier (rich, emergent):** the network of settlements — migration, **trade**, and the spread of culture/tech/religion across basins, with genuine inter-settlement politics: kinship, rivalry, **religious schism**, and **war**. All emergent from the same systems (a famine you cause, a heresy a prophet spreads), never scripted or player-commanded.

A gnome is "real" exactly when it needs to be; the rest of the tens of thousands live as honest statistics. This tiering is the backbone that lets the same game span a 4-gnome camp and a multi-city civilization.

**The Eye of God (an intentional mechanic, not a bug).** Full per-gnome simulation and the statistical settlement model do *not* produce identical outcomes — full sim is richer and higher-variance. So **where you look changes what happens**: the focus of divine attention *quickens* gnomes into vivid, particular, fate-bearing lives, while the unwatched smooth back into statistics. We embrace this. Your gaze is itself a kind of influence — lingering on a struggling soul can change their fate (for better or worse). The cost is that the simulation is **not reproducible from the seed alone** — it depends on the seed *plus* the recorded sequence of your acts *and* your attention. **Determinism is therefore scoped to the RNG** (so individual systems stay testable with fixed inputs) and to *replaying a recorded session*, not to "seed ⇒ one fixed world." `attention` (the focused region) is a **defined input to the sim**, alongside influence acts — the only channel by which presentation touches the sim; rendering quality, resolution, and audio never do.

**What counts as attention (locked: dwell).** The Eye follows your *gaze*, not your motion. A region comes under the Eye only when the camera **lingers** — dwell **≥ ~2 s** ⚙️ — at individual or settlement zoom (at **civilization zoom nothing quickens**; you are too far up to single anyone out). The Eye's **radius scales with zoom**: a small circle around an individual, the whole settlement at settlement zoom. When your gaze moves on, the quickened **linger ~10 s** ⚙️ before folding back into statistics (hysteresis — a passing pan never strobes fates). **Panning past never quickens; there are no pins** — to hold a soul in the light, you must keep looking. Attention is recorded as sparse `[t, region, radius]` segments — the format tests and replays consume.

### 2.5 The AI stack & emergent institutions

Per gnome: **life-stage FSM** gates behavior → **Utility AI** scores actions by need-satisfaction weighted by traits, life-stage, **culture, and beliefs** (with slight randomness) → **action execution + navigation**. Institutions are **emergent patterns**: gnomes run instincts (teach-nearby-young, gather-where-others-gather, revisit-strong-memory-places); a background **pattern detector** labels recurring clusters as schools/shrines/quarters for UI and for feedback — it never places them. This is the riskiest system; prototype it early and instrument heavily.

### 2.6 Culture & belief system (first-class)

Knowledge **and beliefs** are data with holders and strength, propagating along the social graph in **batched** updates. **Hybrid belief model (locked):** every gnome carries cheap **scalar feelings** (fear / awe / faith, per subject) that run for the whole population (up to tens of thousands); when a scalar crosses a threshold — or a prophet names it — it **crystallizes into a discrete, named belief-object** (a taboo, a rite, a place-reverence, a theology) that only a relevant subset carries. Cheap background everywhere, legible foreground where it matters. Events generate **interpretations** (colored by witness traits/beliefs) that spread, **drift/mutate**, and **crystallize** into cultural objects: skills, taboos, omen-meanings, place-reverence (a belief-tag on a world location that biases utility there), and the **theology-about-you** (a colony/subculture-level belief that *feeds back into appraisal*, 3.7). Empty holder set → **extinction** (of a craft, a *technology*, or a magical insight → dark ages, until **writing** makes knowledge durable). Graph clustering → **subcultures** (and rival theologies). The same machinery carries **technologies and magic-understanding** as knowledge-objects with prerequisites; the **settlement tier** tracks an aggregate **tech/magic level** so research scales without per-gnome bookkeeping. This subsystem produces most of the emergent stories, so build it carefully.

### 2.7 Influence, feedback, time, events, save

- **Phenomenon module** (player-pressure): triggers write **only to world state + stimuli**, never to decisions. No budget/cooldown — the governor is diegetic (3.6). Each phenomenon definition declares its possible effects across the five axes + its **chain hooks** and **tail-risk** rolls.
- **Cascade engine:** resolves phenomenon→phenomenon chains and slim **tail-risk** rolls. **Prophets** are special agents with a hidden charisma stat, an emergent message, a **life-arc** (rise/peak/decline) and a **corruption roll** (mercy→madness); they amplify a belief across the culture graph, can found rival cults, and are steered only indirectly by confirming/contradicting **omens**. The player can *seed* a prophet (a lever) but not author them. All rolls use the **seeded RNG** for reproducible debugging/replays.
- **Discovery/codex store** (optional, 3.10): accumulates observed phenomenon outcomes for the player.
- **Feedback layer (critical):** because outcomes are indirect *and* mysterious, the player must be able to **trace cause→effect in hindsight** — aftermath summaries, affected-area highlights, "what they now believe / who they think you are" readouts, cascade timelines, and zoom-in story beats.
- **TimeService:** fixed game-time ticks, **time-sliced & staggered** AI; bounded per-frame work regardless of population.
- **EventBus:** `born`, `gnome_died`, `knowledge_lost`, `belief_formed`, `phenomenon`, `world_ended` — systems react independently; emergent chains are easy to wire.
- **Save:** explicit serializer over plain data (Colony + culture/belief graph + world + which gnomes are currently quickened). **Seeded RNG → yes** (individual systems reproducible with fixed inputs); full-run reproducibility additionally needs the **recorded act + attention history** (the Eye of God makes focus an input). A save must capture quickened-entity state, not just the substrate.

### 2.7b World & generation (locked: procedural, multi-basin, region-graph)

- **Shape & extent:** an **expandable multi-basin region** — a home valley plus neighbouring basins walled off by ridges and rivers. The colony *explores and spreads* across it over generations; geographic isolation is the engine that lets **subcultures diverge** (a valley cut off by a flood you caused grows its own dialect of the faith). As population swells, **cities emerge** in the richest basins and the colony becomes a **multi-city civilization** spread across the region.
- **Generation:** **procedural with constraints** — a guaranteed-survivable starting basin, varied terrain/resources/hazards beyond it, from a **shareable seed**. (The seed reproduces the *world's starting state and statistical substrate*; the lived history then diverges with your play and your gaze — see the Eye of God, 2.4.)
- **Representation (architecturally consistent):** the *simulation's* world is a cheap **region-graph** — regions → sites (food, water, wood, stone, hidden ore) → hazard **affordances** (slopes for slides, fault lines for quakes, floodplains, burnable forest) → belief-tags (cursed/blessed/sacred). The 3D **heightmap is a skin** baked from that graph, not the source of truth. This keeps reshaping cheap (a landslide edits the graph; the mesh re-bakes) and matches the sim/presentation split (2.1).
- **Affordance rule:** phenomena need terrain to act on — you can't slide a hill that isn't there or flood without water. The generated world is, in effect, the menu of *where* your levers can bite.
- **Gradual discovery (locked):** the region is unknown beyond the colony's reach and **reveals as gnomes explore** (fog). Migration into a new basin is itself an event — and a fresh canvas of resources, hazards, and the unknown.
- **Biome shapes culture (locked):** each region's terrain breeds **distinct traits, crafts, and subcultures** — mountain folk and river folk diverge in temperament and creed. Geography is the seedbed of cultural divergence, which the multi-basin layout then isolates and amplifies.

### 2.7c Audio direction (presentation-only, locked intent)

- **Silence is the primary instrument.** The uncanny arrives by *subtraction* — birdsong stops, wind dies, a room of gnomes goes quiet. (The Still Air is, in effect, an audio phenomenon.)
- **Diegetic-only feedback for acts:** no UI stingers, no confirmation fanfare. You release a drought and the world simply… dries. Preserves ambiguity and complicity.
- **Familiar, slightly wrong** for tainted and uncanny beats — a lullaby a quarter-tone off; rain that sounds almost like whispering.
- **Music is emergent, not a score:** the colony's own songs appear as culture crystallizes — work chants, rites gaining melodies, a terror-faith's hymns thin and urgent. The soundtrack is *their culture, audible*.
- Strictly presentation: audio reads the sim, never touches it (2.1).

### 2.8 Build order (prototype-first, scale-aware)

1. Headless sim spine: GnomeData, Colony, TimeService, aging, birth, death — text log of a colony living and dying.
2. Needs + utility loop in text (self-direction).
3. **LOD + abstract population** early — prove the abstract tiers run cheap as numbers (this is the road to scale).
4. 3D puppets + navmesh for LOD-0 (heightmap baked from the region-graph).
5. Reproduction + inheritance → generational turnover.
6. **Influence pipeline:** one phenomenon (landslide), appraisal, behavior shift, place-belief tag.
7. **Culture & belief:** teaching, interpretation spread, taboos, extinction.
8. **Theology-about-you** + appraisal feedback loop; **cascade engine** + tail-risk; **prophets**.
9. Emergent-institution pattern detector.
10. Feedback/hindsight UI, discovery codex, save/replay (seed + recorded inputs).
11. **Settlement & civilization tiers** — aggregate simulation, emergent cities, migration & spread; scale toward tens of thousands.

### 2.9 Open questions (Part 2)

6. **When to port hot paths to C#/GDExtension** (→ after profiling).
7. **LOD-2 appraisal fidelity** — **resolved:** full statistical belief participation (the scalar substrate is population-wide by design, 2.6); discrete belief-objects are sampled on promotion.
8. **LOD-2 belief reconciliation** — how finely should aggregate belief round-trip through promote/demote before divergence is noticeable? (soft; the Eye of God makes minor divergence acceptable by design.)

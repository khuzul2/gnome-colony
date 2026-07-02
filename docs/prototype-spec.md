# Gnome Colony — First Prototype Spec

*Companion to the design doc. Scope: the smallest thing that proves the spine. **No 3D, no influence system, no theology** — a headless simulation that you watch as a text log. Get this breathing first; everything in the design doc layers onto it.*

Engine: **Godot 4.7**, **GDScript**, run **headless** (`godot --headless --script sim_main.gd`). Plain-data simulation core, exactly as the design doc's 2.1 demands — no scene nodes yet.

---

## Milestone 1 — "A colony lives and dies" (the foundation)

### Goal & success criteria

Run the sim headless and watch a text log like:

```
Year 1  · pop 4   · born: Pib(F)
Year 6  · Pib → Child
Year 14 · Pib → Adolescent · learning Foraging from Mara
Year 19 · Bond formed: Pib & Tomm
Year 22 · Pib → Adult
Year 24 · born: Wren(F) to Pib & Tomm
Year 58 · Mara died (old age) · Foraging knowledge now held by 2
Year 71 · Pib died (old age) · colony remembers her
Year 95 · pop 11 · 3 generations
...
Year 140 · COLONY ENDED (no surviving gnomes)
```

**Success = the colony self-perpetuates for multiple generations with no scripting** — gnomes choose their own actions, pair up, reproduce, pass skills down, and die, purely from needs + utility. If a starving colony recovers by gnomes choosing to forage, the spine works.

### Data model (the whole prototype)

```gdscript
enum LifeStage { INFANT, CHILD, ADOLESCENT, ADULT, ELDER, DEAD }

# Traits as a small float map [0..1]; start with just a few that bias decisions.
# e.g. {"industrious":0.7, "curious":0.4, "timid":0.2, "social":0.6}

class GnomeData:
    var id: int
    var name: String
    var sex: int                      # 0/1, only matters for reproduction
    var age_days: float = 0.0
    var stage: int = LifeStage.INFANT
    var alive: bool = true

    var needs := {                    # 0 = satisfied, 1 = desperate
        "hunger": 0.0, "rest": 0.0, "social": 0.0, "purpose": 0.0,
    }
    var traits := {}                  # float map, inherited + mutated
    var skills := {}                  # name -> proficiency [0..1]
    var knowledge := []               # skill names this gnome can TEACH
    var relationships := {}           # other_id -> {"type": str, "weight": float}
    var partner_id: int = -1

    var current_action: String = "idle"
    var location_id: int = 0          # which site they're at (abstract; no navmesh yet)
```

```gdscript
class Colony:
    var gnomes := {}                  # id -> GnomeData
    var next_id := 0
    var sites := []                   # abstract resource sites (Milestone 1: just food)
    func living() -> Array: return gnomes.values().filter(func(g): return g.alive)
```

### TimeService

```gdscript
class TimeService:
    var ticks_per_day := 1            # 1 sim decision/day (reconciled with algorithm spec v1.1)
    var days_per_year := 96           # 4 seasons × 24 days; 90-yr life ≈ 8,640 ticks ≈ ~20 min at 1×
    var day := 0
    var speed := 1.0                  # pause=0, normal=1, fast=large
    # one tick = advance time, then run systems in order (below)
```

A full life ≈ ~90 "years" (≈ 8,640 ticks at 1 tick/day × 96 days/year), tuned so that **at 1× a life runs ~20 min** (the design's 15–30 min band) and fast-forward blows through generations.

### Systems, run in this order each tick

1. **Aging** — `age_days += dt`; on crossing a threshold, transition stage and log it. Death check: probability rising sharply in ELDER, plus hardship deaths (hunger need pinned at 1.0 too long).
2. **Needs decay** — each need drifts up; INFANT/CHILD decay differently (dependents need a caregiver to satisfy hunger).
3. **Decide (utility AI)** — for each living gnome, score candidate actions and pick the best (see below).
4. **Act** — resolve the chosen action's effects (eat lowers hunger; rest lowers rest; socialize lowers social and adjusts a relationship; teach/learn moves a skill; work raises purpose).
5. **Social/reproduction** — adults with a strong mutual bond may form a partnership; partnered adults may produce an INFANT (inheritance below).
6. **Death resolution** — mark dead, emit `gnome_died`, handle knowledge loss (if a skill's teachable-holder count hits 0, log **extinction**).

### The utility loop (the heart of Milestone 1)

```gdscript
func decide(g: GnomeData, colony) -> String:
    var best_action := "idle"
    var best_score := -INF
    for action in available_actions(g):          # gated by life stage
        var s := score(g, action, colony)
        if s > best_score:
            best_score = s; best_action = action
    return best_action

func score(g, action, colony) -> float:
    # Each action advertises which needs it satisfies and by how much.
    # Score = sum over needs of (need_level^2 * action_relief[need])
    # weighted by traits, then + small random jitter for variety.
    ...
```

Squaring the need level makes urgent needs dominate (classic Sims-style utility). Trait weights make an `industrious` gnome value `work`, a `social` gnome value `socialize`. That's enough for believable self-direction.

### Candidate actions by stage (Milestone 1 set)

- **INFANT/CHILD:** seek_caregiver, play, learn (passively absorb from nearby adults)
- **ADOLESCENT/ADULT/ELDER:** eat, rest, socialize, work, teach (if has knowledge), learn (if a teacher is near)
- ELder: bias toward **teach** (this is how knowledge survives them)

### Reproduction & inheritance (simple, but real)

*(Milestone 1 keeps this minimal; culture-shaped mating norms are a later layer.)*

Child traits = per-trait average of parents ± small mutation (clamp 0..1). New trait values occasionally drift, so the colony's temperament evolves across generations under whatever pressure the world applies — the seed of the "evolving" axis, with zero extra systems.

### World (deliberately minimal)

A handful of abstract **sites** with a food value that depletes and regrows. **No navmesh, no pathfinding, no 3D.** "Going" to a site is instantaneous or a 1-tick delay. Scarcity emerges if population outpaces regrowth → gnomes that value foraging survive → soft selection pressure. That's the whole world for now.

### Determinism

Seed one RNG and route *all* randomness through it. You will be chasing emergent bugs ("why did this colony die out?"), and a reproducible seed is the difference between a fixable bug and a ghost.

---

## Milestone 2 — "One act, one consequence" (first influence)

Once Milestone 1 self-perpetuates, add the **smallest slice of the influence pipeline**: a single phenomenon and an appraisal.

- **Phenomenon: `landslide(site_id)`** — writes to world state (deplete/destroy the site, expose a new `iron` resource) and emits a **stimulus** `{type:"landslide", place:site_id, intensity}`.
- **Appraisal** — each gnome at/near the site reacts through its traits:

```gdscript
func appraise(g, stimulus):
    if stimulus.type == "landslide":
        var fear = clamp(stimulus.intensity * (0.3 + g.traits.get("timid",0.0)), 0, 1)
        g.needs["safety"] = max(g.needs.get("safety",0.0), fear)   # add safety need
        if g.traits.get("curious",0.0) > 0.6:
            remember(g, "saw_strange_ore_at", stimulus.place)      # opportunity reading
        else:
            add_place_belief(stimulus.place, "feared", fear)        # writes a world tag
```

- **Behavior shift** — a `feared` place-tag adds a utility penalty to actions at that site, so frightened gnomes avoid it (and thus avoid the iron) — reproducing the **ironic loop** from the design doc, in code, with one phenomenon.

That single vertical slice validates the entire `phenomenon → world+stimulus → appraisal → behavior` chain. Everything else in Part 3 (propagation into shared culture, theology, prophets, cascades) is *more of this same shape* and comes much later.

---

## Project layout

```
res://
  sim/
    gnome_data.gd
    colony.gd
    time_service.gd
    systems/        # aging.gd, needs.gd, decide.gd, act.gd, social.gd, death.gd
    utility.gd
    rng.gd          # single seeded RandomNumberGenerator
  sim_main.gd       # headless entry: build colony, loop ticks, print log
```

Keep the whole sim free of any Node/scene reference. When you later add 3D, a `GnomePuppet` scene will *read* `GnomeData` — the sim won't know the puppet exists.

---

## Explicitly NOT in the prototype (scope discipline)

3D, navmesh, art, UI, the influence economy beyond one landslide, culture propagation, theology, prophets, cascades, LOD/abstract simulation, save/load. All are designed for in the doc; none belong in the first build. **Prove the living-dying-self-directing spine first** — it's the riskiest assumption, and everything else is incremental once it holds.

---

*Suggested first coding session: Milestone 1 systems 1–4 (aging, needs, decide, act) with 4 lightly-seeded founders (a scenario + broad trait leanings) and a single food site — just get them eating, resting, aging, and dying on their own. Add reproduction + teaching next session.*

# 🎮 PLAYTEST GATE B — "Does development read, and feel earned?"

**Phase R3 (settlement visuals) is code-complete and headless-green — full suite 845/845, lint clean.**
Gate A2 gave you *legibility* (you can see gnomes, settlements, halos; acts explain themselves). Gate B
asks the next question: now that colonies visibly **build**, does their growth read as civic development,
and does it feel like **your** acts earned it? **Automated tests can't judge "earned" or "reads as a
payoff" — that's your call on the real GPU build.**

## How to look
`git pull` (or use your local tree), launch, **New Game**, and let a colony run **many seasons** — R3 is
about the slow build-out, so give it time. Watch a settlement on the map (click a **roster row** to focus
it). Then steer it: cast **weeping sky** over a **drought** basin (should push farms/wells), lean on a
place with **fear/omens** (should push walls), and sustain **devotion** (should push a shrine, then a
**basilica** once devotion tier ≥ III). When a colony finally ends, read the **Chronicle** screen.

## What's new in R3 — judge each

**1. Settlements are literally built, in the mosaic style (R3.1–R3.2).** Each live colony now grows a
**cluster of building props** reflecting its actual structure stock — gabled **dwellings**, furrowed
**fields**, **wells**, **granaries**, colonnaded **workshops**, a shrine **aedicula**, a **basilica**
bearing the sacred monogram on its pediment, **wall** segments, a market **stoa**. They scatter on the
local relief (golden-angle packing — stable, no randomness) and rebuild only when the stock actually
changes. *Do the buildings read as a settlement? Right size/density on the terrain at the play zooms?*

**2. Growth you can watch, and a tier you can read at a glance (R3.3).** A newly-raised structure **grows
in** over ~0.6 s rather than popping full-size, so you catch development *as it happens*. Each settlement
wears a floating **tier medallion** — **rosette** = village ❀, **star** = town ✦, **monogram** = city ☩
(a hamlet wears none) — that swaps the instant the tier turns. *Do you notice buildings rising? Does
village→town→city feel like a visible payoff on the map?*

**3. The chronicle reads as civic development, and the aftermath says *why* (R3.4).** The end-of-run
**Chronicle** now summarizes **what they built** (a tally by kind) and the **peak tier** they reached —
history as development, not just a death toll. The per-cast **Aftermath** (hindsight) attributes a
structure raised in a cast's wake to the **phenomenon that drove it** — *"they raised a farm — after the
drought"* — making the influence loop (your act → their response) legible after the fact. *When you cast,
then see what gets built, does the cause→effect land? Does the Chronicle read like a civilization's story?*

## The core question (the [rav §R-infl] loop)
Development is **never** a build command — the gnomes build in response to the world you shape: drought →
farms/wells, revealed ore → workshop, a blessed place → a shrine there, fear/omens → walls, sustained
devotion → a basilica. **Does steering *feel* like steering?** Cast an act, wait a few seasons, and see if
the buildings that rise are legibly *your* doing — or if it feels arbitrary. That's the heart of Gate B.

## Known, deliberate scoping (decide if it matters)
- **Numbers are all tunable in one edit** — grow-in duration, medallion height/glyphs, prop scatter
  density/step, building costs/priorities/caps live in `Construction` (`sim`) and `SettlementView`
  (`presentation`). Flag anything that reads too fast/slow/dense/sparse and it's a one-line change.
- **Attribution is root-cause, per cast** — the aftermath credits a build to the *first* phenomenon of
  the cast, not a late cascade domino. If you'd rather it name the nearest cause, that's a small tweak.
- **No prose "Year N · a basilica rose" line in the live feed** — the live chronicle feed (R6.4, owned by
  the parallel HUD work) already streams `structure_built`/tier beats; R3.4 added the *end-of-run* civic
  summary + the *hindsight* attribution rather than duplicating the live line. Flag if you want the live
  feed's building lines reworded.
- A follow-up **AftermathPanel `_exit_tree` disconnect** (subscription hygiene, not user-visible) is
  spawned as a separate task.

## To proceed
Record **GO** (+ any tuning asks) and the loop continues to **Phase R4** (integration, determinism, perf,
`test_ravenna_end_to_end` — the drought→farms / fear→walls / devotion→basilica / growth / dark-age
regression chain, sim-side). A **NO-GO** with specifics is just as useful — I'll turn it into tasks the
same way Gate A's became R5–R8.

*(Note: `phase-R3-complete` is tagged only after your GO — the suite is green, but R3 isn't "done" until
the playtest confirms development reads and feels earned.)*

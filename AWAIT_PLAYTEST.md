# 🎮 AWAIT PLAYTEST — Gate 1: Vertical Slice & Fun Check

**Status: HALTED for human go/no-go.** Phases 0–8 are complete (tags
`phase-0-complete` … `phase-8-complete`, local), 287 tests green, lint
clean. Per the plan, the loop does not proceed to Phase 9 (Prophets)
until a human plays the slice and records **GO** in PROGRESS.md.

## How to play

```
godot res://presentation/playtest/playtest_slice.tscn
```

(Needs a display; the slice also boots headless for CI but there is
nothing to judge that way.) It is a THROWAWAY view — dots and buttons,
not the Phase 13–15 presentation layer.

- Left panel: date, mood/hunger/safety/unrest, devotion D · per-head ·
  tier, faith flavor (love vs terror), crystallized beliefs, place tags,
  an acts-and-signs feed, and the chronicle tail.
- Buttons: `still_air` (Tier I, neutral) at the hollow,
  `standing_stones` (Tier II, benevolent) at the hollow, `landslide`
  (Tier II, malevolent) at the eastern ridge. **Only still_air is live
  at boot** — earning Tier II by repeated witnessed acts IS the demo of
  the unlock loop (d̄_peak ≥ 0.15 opens the other two).
- Speed buttons: pause / 1 / 7 / 30 days per second. A third of the
  adults day-trip to the ridge on rotation, so ridge acts have real
  witnesses (and real landslide casualties).
- Dots: red rises with fear, warm gold with faith; a red ring around a
  site = cursed tag, gold ring = blessed.

## What to evaluate (tests cannot judge this)

1. **Core fantasy:** nudge → watch the colony respond → a belief forms →
   consequences ripple. Try: spam still_air until Tier II unlocks, then
   drop a landslide on the ridge while day-trippers are there. Do the
   deaths, the fear, the possible `cursed` tag, and the later avoidance
   *feel* causal and yours?
2. **Attribution:** can you feel and attribute your influence, or is it
   an aquarium? (The mundane-explanation design means some acts SHOULD
   read ambiguous — but "ambiguous" and "invisible" are different
   failures.)
3. **Meaning:** do emergent beliefs (taboos, rites, place tags in the
   readout) read as *meaningful stories*, or as noise?
4. Watch the terror path: does leaning malevolent visibly raise unrest
   (the tyranny brake), and does love-faith feel like the stabler road?

## Recording the verdict

- **GO** → tick "Human GO recorded here" under PLAYTEST GATE 1 in
  PROGRESS.md (add a note on what felt right/wrong), delete this file,
  and the loop resumes at Phase 9 (T9.1 Prophet entity & seeding).
- **NO-GO** → leave the checkbox, note what failed the fun check in
  PROGRESS.md, and the next iteration reworks the core feel before any
  new systems are built (this is the cheapest moment to learn that —
  plan's validation of review A2/B3).

## Known slice limitations (by design, not bugs)

- Only `still_air` castable at boot (see above — the unlock ladder is
  the point).
- Gnome "movement" is a display-side day-trip rotation; real movement,
  settlements, and the Eye of God arrive in Phases 11/13.
- Belief/devotion daily ticks are composed by the slice the same way
  the integration tests do it; the real orchestrator is Phase 11–12.
- Prophets, tech/magic, migration, war: not built yet (Phases 9–11).

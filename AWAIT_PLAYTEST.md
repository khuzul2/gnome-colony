# 🎮 AWAIT PLAYTEST — Fun Check 2: Emergence & the god-vs-mages arc

**Status: HALTED for human go/no-go.** Phases 0–10 are complete (tags
`phase-0-complete` … `phase-10-complete`, local), 353 tests green, lint
clean. Per the plan, the loop does not proceed to Phase 11 (Hierarchical
simulation / scale) until a human plays and records **GO** in
PROGRESS.md.

⚠️ **Note:** Gate 1 was waived ("GO (faith based)"), so this is the
first time a human actually plays the game. Judge the *Gate-1 basics*
(can you feel and attribute your influence at all?) **as well as** the
Fun-Check-2 questions below.

## How to play

```
godot res://presentation/playtest/playtest_slice.tscn
```

Same throwaway slice as Gate 1, extended with the Phase 9–10 systems:

- **Buttons:** `still_air` (Tier I) · `standing_stones` (Tier II) ·
  `landslide` (Tier II, at the ridge) · **`birds_silent` (omen —
  UNGATED for this playtest**, since a 6-gnome band can never reach the
  Tier-IV pop floor; the real game gates it).
- **Prophet loop:** charge the flock with witnessed acts until their
  |awe−fear| is high, then drop the omen — someone catches, starts
  preaching daily (HUD shows creed flavor, voice strength, CORRUPTED
  flag, and a SCHISM warning when two strong creeds coexist). ~10% of
  prophets go mad mid-career.
- **Tech & magic:** research runs every season (💡 lines in the feed);
  the more you act, the faster `magic` climbs — at 0.5 (prediction)
  your omens visibly lose belief-impact, at 0.85 (resistance) a 🛡 ward
  rises over the hollow and your acts land at ~30% strength there.
- **Outliers:** births occasionally produce geniuses/touched/mutants
  (HUD `outliers:` line); the touched are prime prophet vessels.
- Speeds up to 30 d/s — a generation passes in about a minute.

## What to evaluate (the plan's Fun-Check-2 questions)

1. Do **prophets** create memorable swings — does a mad prophet or a
   schism feel like an *event*?
2. Does the **theology-about-you** feel like a relationship (they
   remember, interpret, answer), or like sliders?
3. Is the **magic → prediction → wards** co-evolution compelling — do
   you *feel* your power being answered, and does that provoke you?
4. Do **outliers** produce interesting divergence rather than noise?
5. Is the **shepherd vs tyrant** choice live and balanced — is terror
   genuinely tempting AND genuinely costly (unrest, fracture)?
6. (Carried over from waived Gate 1) Basics: nudge → response → belief
   → consequence — causal, attributable, fun?

## Recording the verdict

- **GO** → tick "Human GO recorded here" under FUN CHECK 2 in
  PROGRESS.md (with notes), delete this file; the loop resumes at
  Phase 11 (T11.1 LOD manager — the scale phase).
- **NO-GO** → leave the box, note what failed; the next iterations tune
  the core feel before any scaling work ("tune before scaling").

## Known slice limitations (by design)

- The omen button is playtest-ungated (documented above); everything
  else respects the tier ladder.
- Research need-pressure is a flat 1.0 on the discoverable frontier
  (slice glue) — real per-need pressures (drought→irrigation) arrive
  with the environment tier (T11.x).
- One settlement, two sites, day-trip staging; movement/settlements/
  war/migration are Phase 11.
- Tech effects (medicine, fertility…) are computed but not yet fed back
  into the slice's runner loop — they wire in with the Phase 11–12
  orchestrator.

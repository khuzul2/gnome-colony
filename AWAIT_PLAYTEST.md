# 🎮 PLAYTEST GATE A2 — "Now can you read it, and does it read as 3-D Ravenna?"

**The R5–R8 Gate-A remediation is code-complete, tagged, and headless-green (full suite 800/800, lint
clean).** This gate re-judges the 2026-07-05 **Gate-A NO-GO** — palette/mood were approved then, but
gnomes/settlements/halos weren't perceivable, the HUD/menu were unreadable, acts gave no feedback, and
the terrain read as a flat sheet of oversized tesserae. All of that is now addressed. **Automated tests
can't judge whether it *looks* right or *feels* right — that's your call, on the real GPU build.**

## How to look
`git pull` (or use your local tree), launch, **New Game** (note the menu is redesigned), let a colony run
a few seasons, **pan/zoom** around and **change zoom levels** (WASD + E/Q/wheel), click a **roster row**
to jump to a settlement, and cast a few acts — `still air`, then `weeping sky` (watch it get refused with
a reason), then hover **long dark** to see why it's locked.

## What changed since Gate A — judge each

**1. Terrain reads as literal 3-D, in the mosaic style (R5).** The heightfield existed but was flat
(elevations ~0.1% of the map width) and the camera looked near-straight-down. Now: relief amplified to a
2.6 km envelope with a flat water plane, the camera tilted **oblique** (so hills read in profile),
**slope-shaded** tesserae, and **finer** cells (512×288, grout 3 — the "tesserae too large" fix). *Does
the ground read as rolling 3-D relief now? Tesserae the right size at the three zooms?*

**2. You can see gnomes, settlements, halos (R6 — the blockers).** A **camera-framing bug** was found and
fixed (the oblique tilt had pushed the watched basin off the bottom of the frame — gnomes were literally
out of view). Figures are now scaled to read at the play zooms; a **settlement roster** (top-left) lists
every colony (name · tier · pop · seat monogram, click to focus); **floating name-plates** mark each
basin on the map; a **life pulse** shows births/deaths; a **chronicle feed** streams the story beats.
*Can you see gnomes and settlements now? Do prophets/notables wear a legible gold halo? Does the HUD tell
you what/where/doing/improving?*

**3. Acts explain themselves (R7).** Each act shows its **precondition** ("weeping sky — needs drought")
and mutes when unmet; **locked acts name the tier to reach** ("🔒 Tier II — deepen devotion"); a
**refused cast says why** (banner + refused sound) instead of the silent no-op; a **landed act flashes a
medallion** on the map; a **faint ring** shows where the Eye is quickening souls. *Is it now clear what
each act needs, why one's locked, and what happened when you cast?*

**4. Menu clean + camera smooth (R8).** The New-Game **overlap is gone** (root cause: the wizard was a
zero-size control whose cards overflowed the buttons) and the menu/wizard wear the **Ravenna skin**
(night-lapis, cream/gold, monogram, meander). The **camera eases** on pan instead of snapping. *Is the
menu clean and readable now? Does pan/zoom feel good?*

## Known, deliberate deferrals (decide if they matter)
- **Wizard two-pane** (preset-list left / detail right): deferred — it would rewrite the wizard's
  heavily test-pinned 5-page structure. The overlap + skin are fixed; the literal two-pane is a polish.
- **Zoom-transition easing:** pan eases, but the discrete zoom *level* change is still instant (easing the
  height/pitch fought the camera tests). Flag if the zoom jump bothers you.
- **Full-screen gold-leaf `bless_mask`** (from Gate A) still deferred; blessed shine comes from the
  medallion geometry + bloom.
- A pre-existing **wizard-remint node leak** is spawned as a separate follow-up task (not user-visible).

## To proceed
Record **GO** (+ any tuning asks — **every `[leg §X]` number is a starting value, tunable in one edit**:
relief height, camera pitch, tessera size, puppet scale, HUD thresholds, pan smoothing, palette). Then the
loop continues to **R3 (settlement visuals — mosaic building props)**. A **NO-GO** with specifics is just
as useful — I'll turn it into tasks the same way Gate A's became R5–R8.

*(Reference: the Galla Placidia Mausoleum mosaics — gold-ground figures, star-field vault, meander/wave
borders. Settlement basilicas + city medallions arrive in R3.)*

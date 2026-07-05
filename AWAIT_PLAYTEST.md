# 🎮 PLAYTEST GATE A — "Does it read as Ravenna?"

**Phase R1 (Ravenna mosaic render) is complete and headless-green (709/709).** But automated
tests cannot judge whether it *looks* like a Galla Placidia mosaic — that is your call. The render
is GPU-only (headless uses a dummy rasterizer with no pixel readback), so **this gate needs a human
running the real build.**

## How to look

Launch the game (main menu → New Game), let a colony run a few seasons, pan/zoom around, and cast a
couple of acts (e.g. `still_air`, then something that blesses or curses a place).

## What to judge

1. **Palette & mood** — deep lapis grounds, gold tesserae, warm gold key light, figures glowing
   against the dark? Or muddy / too bright / not mosaic-like? (Palette is `docs/redesign-ravenna.md`
   §R-art — 16 colors; all tunable.)
2. **Tesserae feel** — does the grout lattice + per-cell jitter read as *laid stone*, or as generic
   pixelation / noise? Is `grout_px = 4` the right tile size at the three zooms?
3. **Figures on dark** — do gnomes read as luminous mosaic figures? Do **prophets / notable gnomes**
   wear a legible **gold halo**? Are the Ravenna **tints** (gold with faith, oxblood-red with dread)
   readable at a glance?
4. **Iconography** — over a **blessed** place, does the **gold sacred medallion** (the Chi-Rho-like
   monogram — the gnomes' own mark of the unseen will) read? Over a **cursed** place, the red ring?
5. **Christian-like register** — does the whole thing evoke late-antique Christian mosaic, or does it
   miss? (Basilicas and city medallions arrive in R3 — settlement visuals — so judge only figures +
   ground + belief markers here.)
6. **Legibility not lost** — can you still see what's happening (pan/zoom/pick/cast all work)? The
   HUD overlays the mosaic at full resolution by design.

## Known, deliberate deferrals (not bugs — decide if they matter)

- **Camera pixel-snap** deferred (would fight the tested pan precision); you may see slight shimmer
  when panning. If it bothers you, flag it and I'll do a dedicated snap pass.
- **Full-screen gold-leaf `bless_mask`** deferred; the blessed shine currently comes from the gold
  medallion geometry + bloom, not a screen-space mask. Flag if you want the whole blessed *ground*
  to shine.
- Internal resolution is `384×216`; raise/lower in §R-art if you want chunkier or finer tesserae.

## To proceed

Record **GO** (and any tuning asks — palette tweaks, grout size, halo size, monogram shape) and I'll
apply them, then continue to **R3 (settlement visuals)**. Meanwhile I am proceeding with **R2
(living settlements — pure sim logic)**, which is independent of this visual gate.

*(Reference: the Galla Placidia Mausoleum mosaics you shared — star-field vault, gold-ground
figures, meander/wave borders, the deer-at-spring lunette.)*

---

# ⛔ PLAYTEST VERDICT — 2026-07-05 — **NO-GO**

Human (alessandro) ran the real GPU build. **Palette & mood are approved.** But the build is
**blocked on legibility**: the player cannot see gnomes, settlements, halos, or iconography, cannot
read the HUD, and cannot follow the colony's evolution — so **the actual subject of the gate
(figures / halos / iconography) cannot be judged at all.** Do not proceed to R3 on visuals until the
legibility items below are addressed. Turn this into planned, TDD'd tasks per the plan workflow.

## Gate 6-point results (human)
1. **Palette & mood** — ✅ good, right direction. **Keep.**
2. **Tesserae feel** — ✅ texture good, BUT **tesserae are too large**; and they should read with
   depth/elevation (see terrain direction below), not as a flat sheet.
3. **Figures / halos** — ❌ *cannot even tell there are gnomes or settlements*; no halo visible.
4. **Iconography** — ❌ unjudgeable (only tesserae visible).
5. **Christian-like register** — ➖ ok for now.
6. **Legibility** — ❌ "it's a mess." This is the blocker.

## Issues to turn into tasks (severity ordered)

- **[BLOCKER] Figures/settlements/halos invisible.** Player can't perceive gnomes, where colonies
  are, or that anything is alive. The gate's core deliverable (luminous mosaic figures + gold halo on
  prophets/`notability ≥ 0.6` per §R-art) is not landing. Investigate whether it's scale (puppets too
  small at default zoom), draw order (mosaic covering puppets), or a render regression. This must be
  fixed for the gate to be judgeable.

- **[BLOCKER] HUD is unreadable.** Player cannot tell: which tools/acts are available vs locked, how
  many settlements exist and where, where gnomes are and whether they're doing anything, or how the
  colony is evolving over time. Needs a legibility-first HUD pass (settlement roster + locations,
  gnome/activity indication, act availability affordances, a readable running chronicle). Should adopt
  the Ravenna palette.

- **[HIGH] Main-menu UX is broken.** New Game menu has **overlapping labels** and messy navigation
  (see screenshot 1). Redesign the main/new-game menu: clean navigation, no overlaps, styled to the
  Ravenna aesthetic + palette.

- **[HIGH] Act feedback is absent (mechanics are NOT broken — do not "fix" the sim).** Confirmed
  working-as-designed:
  - `still_air` — precondition `any`, applies fine; **only feedback is a sound.**
  - `weeping_sky` — precondition is **`drought`** (`sim/phenomena/catalog.gd`); with no drought it is
    correctly a **no-op**, but the UI let the player select it and gave **no rejection feedback**.
  - `long_dark` — it's **tier 2**; player `magic 0.000` so it's correctly **locked/disabled**, but
    nothing tells the player *why* or *how to unlock*.
  Fix is presentation-only: show preconditions, show why an act is locked and its unlock path,
  reject-with-feedback when a precondition isn't met, and give **on-map + chronicle feedback** when an
  act resolves.

- **[MED] Pan/zoom feels clunky.** Do the feel pass (and reconsider the deferred camera pixel-snap).

## Terrain direction — DECISION from human (needs spec authority before building)
Human wants **literal 3D terrain with real elevation, rendered *through* the mosaic style** — i.e.
keep the tesserae/grout/palette shader look, but apply it to actual 3D height geometry, not a flat
plane. **This supersedes the flat-plane assumption in `redesign-ravenna.md §R-art`.**

⚠️ `redesign-ravenna.md` is READ-ONLY once authored and currently specifies a flat `384×216` internal
plane; it defines **no** elevation/geometry/camera-projection numbers. Per the hard invariants, the
loop must **not invent** these. Before implementing 3D terrain, a human must author the numeric
spec (heightmap source & scale, projection/camera, how the mosaic shader maps onto 3D surfaces, LOD /
tesserae size vs. distance so cells stop reading "too large") — otherwise write `STUCK.md`. Also fold
in **"tesserae too large"** here.

## Human's chosen process
Recorded as **NO-GO for the loop** — loop turns this into planned, tested tasks. No source-of-truth
docs edited by this session.

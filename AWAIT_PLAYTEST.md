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

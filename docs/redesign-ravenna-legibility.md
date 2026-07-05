# Gnome Colony — Ravenna Legibility & Dimensional-Terrain Spec (presentation source of truth)

*Authored 2026-07-05 from **Playtest Gate A — NO-GO** (`AWAIT_PLAYTEST.md`). **READ-ONLY once
authored**, like `redesign-ravenna.md`. This is the single source of every **new** number the
Gate-A remediation introduces. It is **presentation-only** — it adds render/HUD/menu/feel constants
and reads sim state read-only; it never touches `sim/` and introduces **no** algo/§17 numbers.
Where a value here restates or **supersedes** a `redesign-ravenna.md §R-art` render constant it says
so explicitly (that doc stays frozen; the implementing task updates the code constant and cites
this doc). Cite as `[leg §X]`. If it is silent, write `STUCK.md` — do not invent. The plan that
consumes this doc is `docs/redesign-plan-legibility.md`.*

**Why this exists.** Gate A approved the **palette and mood** but was a **NO-GO on legibility**: the
player could not see gnomes, settlements, halos, or iconography; the HUD and main menu were
unreadable; acts gave no feedback; and the terrain read as a flat sheet of oversized tesserae rather
than dimensional ground. None of the six gate criteria past palette could be judged. This spec fixes
**legibility first**, then re-judges at **Gate A2**, before settlement visuals (Phase R3) proceed.

**All numbers below are STARTING values, tuned at Playtest Gate A2.** They are presentation choices,
not spec-derived — same status as every other in-file "presentation number" in this project.

---

## §L-relief — Dimensional mosaic terrain (make the existing heightfield read as 3D)

**Grounding (do not rebuild).** `presentation/world_view.gd` already bakes a real 3-D heightfield
mesh (`WorldView._bake`, IDW over `RegionGraph` elevations, `GRID 24`, `EXTENT_KM 14`). The relief
is invisible for two measurable reasons, both fixable without new geometry:
1. **Vertical amplitude is ~nil.** Region elevations run `≈ 1 + 2·hazard` (`RegionGraph`, T13.1) —
   roughly `1..3` world units — spread across a `2·EXTENT_KM = 28 km` plane. Relief is ≈0.1 % of
   width, so the mesh is effectively flat.
2. **The camera looks straight down.** `CameraRig.PITCHES_DEG` is `−90/−60/−35` at
   CIVILIZATION/SETTLEMENT/INDIVIDUAL; the default SETTLEMENT view (`−60°`) reads near-top-down, so
   what little relief exists is not seen in profile.

**Fix = exaggerate + tilt + shade. Literal 3-D, mosaic-styled — not flat tiles.**

**Vertical relief (amplitude).** Normalize baked height to a **target relief**, decoupled from the
raw elevation magnitude, so terrain is legibly hilly at every seed:
`y = RELIEF_KM · (elevation − min_e) / span` (replacing the raw `height_at` used as `y` in the bake;
`height_at`/picking keep using the same normalized field so they still agree).
- `RELIEF_KM = 2.6` (peak-to-trough vertical span in km; ≈ `9 %` of the 28 km plane — reads as rolling
  country, not a wall).
- `SEA_LEVEL_T = 0.15` — normalized heights below this are **water**: clamp their `y` up to the
  sea plane and color lapis, so a flat water body contrasts against land relief.

**Camera (oblique so relief reads in profile).** Supersede `CameraRig.PITCHES_DEG` / `HEIGHTS`:
| zoom | pitch° (was) | pitch° (new) | height (was) | height (new) |
|---|---|---|---|---|
| CIVILIZATION | −90 | **−72** | 120 | **135** |
| SETTLEMENT | −60 | **−45** | 35 | **42** |
| INDIVIDUAL | −35 | **−28** | 8 | **9** |
Rationale: even the map zoom tilts slightly so terraced relief is visible; the two play zooms sit
oblique. Heights nudge up to keep the same ground framing under the shallower pitch. Keep the rig's
existing clamps and `zoom_changed` behavior.

**Height-shading (dimensional, still mosaic).** Relief must be lit and terraced, not just tall:
- **Slope-shade:** darken a tessera by up to `SLOPE_SHADE = 0.28 ·` the face's slope (0 = flat,
  1 = vertical), applied in the terrain material / mosaic pass on the palette-mapped color toward its
  darker neighbor — the tesserae equivalent of an ambient-occlusion crease. Steep faces read darker,
  flats brighter.
- **Terrace bands:** the existing elevation→palette bands (`WorldView.terrain_color`) become **contour
  terraces** once relief is amplified — keep the hard band edges (no smoothing) so each elevation
  step reads as a laid course of stone. This is the intended "mosaic relief" look; no new number.
- The gold key light (`[rav §R-art]`, `28°` elevation) now rakes the amplified relief, so hillsides
  catch gold and valleys fall to lapis — the Ravenna chiaroscuro, for free, once amplitude exists.

**Tessera scale (fix "tesserae too large").** Supersede two `[rav §R-art]` render constants so cells
read as laid stone over relief, not chunky flat tiles:
- Internal render resolution `384×216` → **`512×288`** (still 16:9, nearest upscale unchanged) — more
  cells across the view ⇒ finer tesserae.
- `grout_px 4` → **`3`** (lattice pitch in internal pixels).
- Keep `[rav §R-art]` grout color/alpha, per-cell jitter, dither, gold-leaf lift as authored.
- **Pixel-snap the camera** (the R1.2 deferral): quantize the presented stage by snapping the camera
  target to whole internal-pixels each frame so the grout lattice does not shimmer on pan/zoom. Feel
  constants in `[leg §L-ui]`.

---

## §L-hud — A HUD you can read (what the player must always be able to see)

The Gate-A HUD is a raw top-left text dump that overlaps the world and answers none of "what do I
have, where is it, what is it doing, and is it getting better?" Replace with **anchored, non-
overlapping panels** in the Ravenna palette (`[rav §R-art]`: night-lapis grounds, cream body text,
gold headers/`gold-lit` on hover; **min font 14 px**; every panel has an 8 px margin and never
overlaps the world-pick area or another panel). The HUD reads sim state **read-only** — it never
computes or writes sim state (a disagreeing HUD would lie; read the same folds the sim exposes).

**Data contract — the HUD must surface, at all times:**

1. **Settlement roster** (top-left panel). One row per `run.settlements`: name · **tier**
   (hamlet/village/town/city) · **population** · a **seat mark** (the sacred monogram) on the main
   settlement. Row count cap `ROSTER_ROWS = 8`, overflow "+N more". Clicking/hovering a row focuses
   the camera on that settlement's place (uses `sid_places` / `place_positions` RunView already maps).
2. **Settlement locators** (on the world, through the mosaic stage). A small gold **name-plate + tier
   glyph** floating above each settlement's place so the player can find colonies on the map. Fades
   with camera distance; never covers the pick target.
3. **Population & life pulse** (roster header or a compact strip). Total living souls · **quickened
   count** (materialized under the Eye) · births/deaths this season (Δ arrows). So the player sees the
   colony is *alive and changing*.
4. **Gnome legibility** (BLOCKER — figures were invisible). Guarantee puppets are visible at the two
   play zooms: minimum on-screen puppet size `PUPPET_MIN_PX = 6` internal-pixels (scale puppets up if
   the zoom would shrink them below this), drawn **after / over** the terrain in the stage (fix any
   draw-order/occlusion from the R1.2 reparent), on the luminous-on-dark rim. Haloed gnomes
   (prophet / `notability ≥ 0.6`, `[rav §R-art]`) must read at a glance.
5. **Act availability** (influence panel, see `[leg §L-acts]`). Every stocked act shows its state:
   **available** / **locked** (with reason) / **needs-condition** (with which).
6. **Chronicle feed** (bottom-left scrolling panel). The last `CHRONICLE_LINES = 8` diegetic events
   in arrival order — births/deaths, `structure_built`, `settlement_tier_changed`, discoveries,
   landed phenomena, prophets, wars — so the player can *follow the evolution of the colony*. Newest
   at the bottom; older lines fade. This is the existing telemetry/chronicle stream, surfaced live.

**Do NOT** add a build button, a "select gnome to command" verb, or any direct control — influence
stays indirect (design §1.3). The HUD **reveals**, it never **commands**.

---

## §L-acts — Acts you can understand (affordance & feedback)

Gate A: "still air only plays a sound; weeping sky does nothing; long dark is disabled and I don't
know why." All three are **correct sim behavior** — the gap is entirely presentation. Fix by making
preconditions, gates, and outcomes **legible**. Presentation reads the catalog + colony read-only.

1. **Precondition display.** On hover/arm, each act shows its **precondition** from the catalog
   (`sim/phenomena/catalog.gd`, the `affordance` field — e.g. `weeping_sky` needs `drought`) and
   whether it is currently **met** at the paint target. An act whose precondition is unmet paints in a
   **muted** state with the reason ("needs: drought").
2. **Lock reason & unlock path.** A locked act (tier / magic gated — e.g. `long_dark` is tier 2 and
   the colony is at magic 0) shows **why** it is locked and **what raises the gate** ("Tier II — deepen
   devotion"). No numbers/odds surfaced (design §3.8 keeps the codex faint) — qualitative only.
3. **Reject-with-feedback.** A cast refused (precondition unmet, wrong target kind, warded) shows a
   brief on-screen line at the cursor for `REJECT_MSG_SECONDS = 2.0` **and** plays the existing
   `refused` UI sound (Phase 19). Today a refused cast is silent — that is the bug.
4. **On-map cast marker.** A **landed** act paints a transient mosaic marker at each affected place
   (reuse `Motifs`: gold monogram for benevolent, oxblood ring for malevolent, neutral tessera
   pulse) for `CAST_MARKER_SECONDS = 4.0`, plus a **chronicle line** ("A calm settled over
   Alderbrook"). Diegetic discipline holds (T14.4): the marker/line fire off the **landed
   `EventBus.phenomenon`**, never as an arm/press confirmation stinger.
5. **Attention/Eye affordance.** A faint indicator of where the Eye is currently attending (the
   dwell→quicken region) so the player understands why some places have visible gnomes and others do
   not.

---

## §L-ui — Menu polish & camera feel

**Main menu & New-Game wizard** (Gate A: overlapping labels, unreadable navigation — screenshot 1).
Rebuild the layout (logic/entries unchanged — `MainMenu`, `NewGameWizard` keep their signals/API):
- **Single responsibility per region, no overlap.** Menu is a centered vertical column; the New-Game
  wizard is a **two-pane** layout — preset list (left) and detail/summary (right) in **separate,
  non-overlapping containers** with `≥ 16 px` gutter (Gate A showed "Quick Start" overprinting the
  "Balanced Saga" heading — the panes were stacked at the same origin).
- **Ravenna skin.** Night-lapis (`#0d1b3e`) ground, cream (`#e8ddc4`) body, gold (`#d6a53a`) headings
  and selected/hover state to `gold-lit` (`#f2d488`); a meander (Greek-key) rule under the title;
  the sacred monogram as the menu emblem. Min font 16 px for menu items. Reuse `[rav §R-art]` colors.
- **Keyboard + mouse navigation** both work; the focused item is unmistakably highlighted.

**Camera feel** (Gate A: "panning and zooming feels very clunky"). Presentation constants:
- `PAN_SPEED_KMPS = 9.0` at SETTLEMENT, scaled by zoom height (faster when higher). Diagonal pan
  normalized (already fixed T23; keep).
- **Smoothing:** the rig eases toward a target rather than snapping — exponential smoothing
  `PAN_SMOOTH = 12.0` (per-second rate, framerate-independent: `pos = lerp(pos, target, 1 −
  exp(−PAN_SMOOTH·dt))`). Zoom transitions ease over `ZOOM_EASE_SECONDS = 0.18` between the discrete
  levels (the three levels stay discrete; only the visual move eases).
- **Pixel-snap** (`[leg §L-relief]`): after easing, snap the presented camera to whole internal-pixel
  units so the mosaic grout does not crawl. Snap must not fight the pick math — pick uses the
  pre-snap camera transform (document the split, as R1.2 anticipated).
- Edge-scroll / rotate / sensitivity settings that are currently inert (Phase-23 deferral) stay out
  of scope here unless a task names them.

---

## Appendix — constant summary (all tunable at Gate A2)

| const | value | §  |
|---|---|---|
| `RELIEF_KM` | 2.6 | relief |
| `SEA_LEVEL_T` | 0.15 | relief |
| camera pitch° civ/set/ind | −72 / −45 / −28 | relief |
| camera height civ/set/ind | 135 / 42 / 9 | relief |
| `SLOPE_SHADE` | 0.28 | relief |
| internal res (supersedes §R-art 384×216) | 512×288 | relief |
| `grout_px` (supersedes §R-art 4) | 3 | relief |
| `ROSTER_ROWS` | 8 | hud |
| `PUPPET_MIN_PX` | 6 | hud |
| `CHRONICLE_LINES` | 8 | hud |
| min HUD font | 14 px | hud |
| `REJECT_MSG_SECONDS` | 2.0 | acts |
| `CAST_MARKER_SECONDS` | 4.0 | acts |
| menu emblem / skin | Ravenna palette + monogram | ui |
| `PAN_SPEED_KMPS` | 9.0 | ui |
| `PAN_SMOOTH` | 12.0 /s | ui |
| `ZOOM_EASE_SECONDS` | 0.18 | ui |

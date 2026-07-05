# Redesign Plan — "Ravenna" Gate-A remediation: dimensional terrain + legibility

*Loop-ready, test-gated. Companion to `docs/implementation-plan.md` (§0 there still applies),
`docs/redesign-plan-ravenna.md` (the R0–R4 plan this extends), `PROGRESS.md` (the live ledger), and
the new authoritative spec `docs/redesign-ravenna-legibility.md` (`[leg §X]`). Authored 2026-07-05
from **Playtest Gate A — NO-GO**.*

**Why.** Gate A approved palette + mood but was a **NO-GO on legibility**: gnomes, settlements,
halos and iconography were not perceivable; the HUD and main menu were unreadable; acts gave no
feedback; and the terrain read as a flat sheet of oversized tesserae. None of the gate's remaining
criteria could be judged. These phases fix that, **presentation-only**, then re-judge at **Gate A2**.
**Phase R3 (settlement visuals) does not start until Gate A2 records GO** — building props on an
unreadable stage would be wasted.

**Invariants (unchanged).** All work here is **presentation-only**: `sim/` stays untouched (the
purity test in `test_gnome_puppet`/`test_world_view` still governs); the HUD reads sim state
read-only; influence stays **indirect** (design §1.3 — no build button, no unit command); numbers
come only from `[leg §X]` (or documented in-file as presentation numbers, per project precedent).
Task IDs continue the **R-prefix**: **R5–R8**. They sit **before R3** by dependency and by the
Gate-A2 halt.

**Dependency graph.** `R1 (done) → {R5, R6, R7, R8}` (the four remediation phases are independent of
each other) `→ 🎮 Gate A2 → R3 → R4`. R2 (done) supplies the settlement/tier data R6's roster reads.

---

## Phase R5 — Dimensional mosaic terrain (make the heightfield read as literal 3-D)

**Goal:** the ground reads as **real, rolling 3-D terrain in the mosaic style** — hills, valleys,
water bodies, terraced courses of tesserae catching the gold key light — not a flat sheet of
oversized tiles. Achieved by **amplifying the existing `WorldView` heightfield, tilting the camera
oblique, shading slopes, and refining tessera scale** per `[leg §L-relief]`. **No new geometry
system; do not rebuild WorldView. Presentation-only.**
**Phase-Exit Test:** `test_dimensional_terrain.gd` (headless-safe) — the baked mesh's vertical span
equals `RELIEF_KM` within tolerance over a fixed seed (relief is real, not ~0); `WorldView.height_at`
and the bake agree (picking still lands); `CameraRig` pitches/heights equal the `[leg §L-relief]`
values; the pixel stage is `512×288` and `Mosaic.grout_px == 3`; camera pixel-snap yields an
identical framebuffer hash under a <1-internal-pixel pan (the R1.2 shimmer deferral, now closed).

- **R5.1 — Amplified relief in the bake.** files: `presentation/world_view.gd`. do: normalize baked
  vertex height to `RELIEF_KM · (elevation − min_e)/span` and clamp sub-`SEA_LEVEL_T` heights to a
  water plane `[leg §L-relief]`; keep `height_at`/normals/`walkable_faces` consistent so picking and
  nav still agree. tests: `test_dimensional_terrain.gd` relief-span + height_at-agreement legs;
  `test_world_view` regression green (terrace bands unchanged).
- **R5.2 — Oblique camera & pixel-snap.** files: `presentation/camera_rig.gd`,
  `presentation/render/pixel_stage.gd` (or `run_view.gd`). do: supersede `PITCHES_DEG`/`HEIGHTS` with
  the `[leg §L-relief]` table; add camera pixel-snap on the presented stage (pick uses the pre-snap
  transform — document the split). tests: pitch/height values; snap framebuffer-hash invariance under
  sub-pixel pan; a known screen point still maps to the expected basin (pick survives snap).
- **R5.3 — Slope-shade & finer tesserae.** files: `presentation/render/mosaic.gd`/`mosaic.gdshader`,
  `presentation/world_view.gd` (material). do: internal res `512×288`, `grout_px 3`
  (supersede `[rav §R-art]`, cite `[leg §L-relief]`); add the `SLOPE_SHADE` slope-darkening term so
  relief reads dimensional; keep hard palette-band terraces. tests: `test_mosaic_shader` /
  `test_pixel_stage` updated to the new res/grout; slope-shade darkens a steep sample vs a flat one
  (CPU mirror, since headless has no pixel readback).

---

## Phase R6 — Legibility: figures, settlements & a HUD you can read (the BLOCKERS)

**Goal:** the player can **see gnomes and settlements, tell how many colonies exist and where, watch
them do something, and follow the colony's evolution** — the two Gate-A blockers. Anchored, non-
overlapping Ravenna-palette HUD panels + on-world locators + guaranteed-visible puppets/halos, per
`[leg §L-hud]`. **Presentation-only, reads sim read-only.**
**Phase-Exit Test:** `test_hud_legibility.gd` — a driven 2-settlement run: the roster lists both with
name/tier/pop/seat-mark; each has an on-world locator at its `sid_places` position; the chronicle
feed shows the last N events in arrival order and updates on a new `structure_built`; a puppet at the
INDIVIDUAL/SETTLEMENT zoom resolves to `≥ PUPPET_MIN_PX` and is drawn over the terrain; a
prophet/high-notability gnome shows a halo, an ordinary one does not.

- **R6.1 — Puppet & halo visibility fix (BLOCKER).** files: `presentation/gnome_puppet.gd`,
  `presentation/puppet_pool.gd`, `presentation/shell/run_view.gd`. do: diagnose why figures are
  invisible post-R1.2 reparent (scale vs zoom, draw order/occlusion behind terrain, or a regression);
  enforce `PUPPET_MIN_PX` minimum on-screen size and correct draw order/rim so gnomes read as
  luminous mosaic figures and halos are legible `[leg §L-hud]`. tests: on-screen size floor; drawn
  over terrain; halo shows only for holy; `test_puppet_tint` regression green.
- **R6.2 — Settlement roster panel.** files: `presentation/ui/hud/settlement_roster.gd` (new),
  `run_view.gd`. do: a top-left panel, one row per `run.settlements` (name · tier · pop · seat
  monogram), `ROSTER_ROWS` cap + "+N more", row focus→camera; Ravenna skin, no overlap
  `[leg §L-hud]`. tests: rows track settlements; tier/pop read the fold verbatim; seat mark on
  `main_settlement`; row-click focuses.
- **R6.3 — On-world settlement locators + life pulse.** files:
  `presentation/ui/hud/locators.gd` (new) or `run_view.gd`. do: floating gold name-plate + tier glyph
  above each settlement place (distance-fade, never over the pick target); a compact pop / quickened /
  births-deaths-Δ strip `[leg §L-hud]`. tests: a locator per settlement at its place position; pulse
  reads living/quickened counts.
- **R6.4 — Live chronicle feed.** files: `presentation/ui/hud/chronicle_feed.gd` (new), `run_view.gd`.
  do: a bottom-left scrolling panel of the last `CHRONICLE_LINES` diegetic events (EventBus /
  telemetry stream — births/deaths, `structure_built`, `settlement_tier_changed`, discovery, landed
  phenomena, prophet, war), newest-bottom, older fading `[leg §L-hud]`. tests: feed appends on a real
  event; caps at N; order is arrival order.

---

## Phase R7 — Acts you can understand (affordance & feedback)

**Goal:** the player understands **what each act needs, why a locked act is locked and how to unlock
it, whether a cast landed or was refused, and what it did** — closing the Gate-A "still air only
plays a sound / weeping sky does nothing / long dark disabled and I don't know why" gap. The sim
mechanics are correct and **must not change**; this is all presentation, reading the catalog + colony
read-only, per `[leg §L-acts]`.
**Phase-Exit Test:** `test_act_legibility.gd` — with a seeded colony: `weeping_sky` shows its
`drought` precondition and paints muted where no drought is active; casting it there is refused with
an on-screen line **and** the `refused` sound; `long_dark` shows "Tier II — deepen devotion" while
gated; a **landed** `still_air` paints an on-map marker and appends a chronicle line, while an
**armed but unpressed** act paints nothing and makes no sound (diegetic discipline, T14.4).

- **R7.1 — Precondition & lock display.** files: `presentation/ui/influence_panel.gd` (extend). do:
  each act surfaces its catalog `affordance` precondition and met/unmet at the paint target, and a
  gated act shows the tier/magic lock **reason + unlock path** (qualitative, no numbers — design
  §3.8) `[leg §L-acts]`. tests: precondition string present; unmet→muted; gated→reason shown; reading
  `unlocked_tier`/catalog only (never re-deriving the ladder).
- **R7.2 — Reject-with-feedback.** files: `run_view.gd`, `influence_panel.gd`. do: a refused cast
  (precondition unmet / wrong kind / warded) shows a cursor line for `REJECT_MSG_SECONDS` and plays
  the existing `refused` UI sound `[leg §L-acts]`. tests: a refused paint emits the message + the
  refused-sound call; a valid paint does not.
- **R7.3 — On-map cast marker + chronicle line.** files: `run_view.gd` (reuse `Motifs`),
  `chronicle_feed.gd`. do: on a **landed** `EventBus.phenomenon`, paint a transient marker at each
  affected place (gold monogram / oxblood ring / neutral pulse) for `CAST_MARKER_SECONDS` and append
  a chronicle line; strictly off the landed event, never arm/press `[leg §L-acts]` (T14.4). tests:
  landed phenomenon→marker+line; armed-but-unpressed→nothing (the T14.4 silence invariant, re-proven).
- **R7.4 — Eye/attention affordance.** files: `run_view.gd`. do: a faint indicator of the currently
  attended region (dwell→quicken) so the player understands where gnomes are quickened `[leg §L-acts]`.
  tests: indicator tracks `run.attention_places`; clears when the gaze releases.

---

## Phase R8 — Menu & camera feel

**Goal:** the main menu and New-Game wizard are **clean, non-overlapping, and skinned to Ravenna**,
and **pan/zoom feels smooth** — closing Gate-A "the menu UI/UX is horrendous, with overlaps" and
"panning and zooming feels very clunky." Logic/entries unchanged (`MainMenu`/`NewGameWizard` keep
their API/signals); this is layout + skin + camera-feel, per `[leg §L-ui]`. **Presentation-only.**
**Phase-Exit Test:** `test_menu_and_feel.gd` — the New-Game wizard's preset list and detail panes
occupy **non-overlapping** rects (the Gate-A overlap bug, asserted on the control rects); menu items
use the Ravenna palette constants; and the camera rig eases toward its pan target
(framerate-independent smoothing) and pixel-snaps, with pick still resolving to the correct basin.

- **R8.1 — Main-menu & wizard layout + skin.** files: `presentation/ui/main_menu.gd`,
  `presentation/ui/new_game/*.gd` (+ any `.tscn`). do: centered single-column menu; **two-pane**
  non-overlapping wizard (preset list | detail/summary, `≥16 px` gutter); Ravenna skin (night-lapis
  ground, cream body, gold/gold-lit headings + hover), meander rule, monogram emblem, min fonts
  `[leg §L-ui]`. tests: pane rects disjoint; palette colors applied; both keyboard & mouse focus a
  highlighted item; `MainMenu`/`NewGameWizard` signals unchanged (regressions green).
- **R8.2 — Camera-feel smoothing.** files: `presentation/shell/run_view.gd`,
  `presentation/camera_rig.gd`. do: exponential, framerate-independent pan smoothing (`PAN_SMOOTH`),
  zoom-transition ease (`ZOOM_EASE_SECONDS`), `PAN_SPEED_KMPS` scaled by zoom height; compose with
  R5.2's pixel-snap; pick uses the pre-snap transform `[leg §L-ui]`. tests: a held pan converges to
  target under two different `dt`s to the same place (framerate-independent); pick still lands after
  snap; discrete zoom levels preserved.

---

## 🎮 PLAYTEST GATE A2 — "Now can you read it, and does the terrain read as 3-D?"

After R5–R8: write `AWAIT_PLAYTEST.md` and **HALT for human GO**. Re-judge the Gate-A six points
plus the remediation: **(1)** terrain reads as dimensional 3-D mosaic (relief, water, terraces),
tesserae sized right; **(2)** gnomes, settlements, halos and iconography are legible; **(3)** the HUD
answers what/where/doing/improving; **(4)** acts explain themselves (preconditions, locks, reject
feedback, landed markers); **(5)** menu is clean and Ravenna-skinned; **(6)** pan/zoom feels good.
Record GO (+ tuning asks — all `[leg §X]` numbers are tunable) before **R3** begins.

---

## Phase ordering note for the loop

R5–R8 are listed in `PROGRESS.md` **before** the R3 block and have all deps checked (R1, R2 done),
so the loop's "first unchecked task whose deps are checked" picks them ahead of R3. **R3 gains an
explicit dependency on Gate A2** so settlement visuals never begin on an unread stage. Work R5–R8 in
any dependency-valid order; each is one green commit, tests-first, numbers only from
`docs/redesign-ravenna-legibility.md`.

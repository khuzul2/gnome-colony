# STUCK — G0.2 needs a human to vendor the Gaea addon (planned handoff, not a failure)

**Date:** 2026-07-06
**Task:** G0.2 — Vendor the Gaea addon (`docs/terrain-gaea-plan.md`, Phase G0).
**Status:** BLOCKED on a human action that was designed into the plan. The loop halts here per
`docs/terrain-gaea-plan.md` (G0.2: *"if the loop cannot fetch Gaea, write STUCK.md naming the exact
files/version needed and HALT for a human to drop the vendored addon in"*).

## What's blocking

G0.2 requires the **Gaea** procedural-generation addon to exist under `addons/gaea/`. Vendoring it
means fetching it from GitHub, and **this environment has no network access** — CLAUDE.md is explicit:
*"network access to GitHub is blocked in this environment; never try to re-download it."* So per
instruction I did **not** attempt any download. A human must drop the addon in.

## What I did / confirmed

- G0.1 is committed and green (`1a5b3f4` — the spec `docs/terrain-gaea.md` + `test_terrain_spec_present.gd`, 3/3).
- Confirmed `addons/gaea/` does **not** exist yet (only `addons/gut/` is present).
- Confirmed lint will accept the vendored addon automatically: `.gdlintrc` excludes the whole
  `addons/` tree, and `gdformat` only targets `sim/ test/ presentation/` — so no lint-exclusion edit
  is needed (unlike the note in the plan, `addons/gut/`-style exclusion already covers `addons/gaea/`).
- Working tree is otherwise clean (only pre-existing `.import` noise, untouched).

## What a human needs to do (the irreducible part)

1. **Download Gaea** from its source repo: **https://github.com/BenjaTK/Gaea** (MIT-licensed,
   pure GDScript — no compiled binary).
2. **Pick a release compatible with Godot 4.7.** I cannot verify version compatibility offline —
   check the release's `addons/gaea/plugin.cfg` / release notes. If no tagged release lists 4.7, use
   the latest release (or `main`) that loads cleanly under 4.7. **Note the exact version/commit you
   used** — I need it for `SOURCES.md`.
3. **Place it at `addons/gaea/`** so that `addons/gaea/plugin.cfg` exists (mirror the layout of
   `addons/gut/`). Copy only the addon's `addons/gaea/**` subtree — not the repo's demo/docs.

That's all the human part. **Leave the rest to the loop** (see below) — or, if you prefer to do it
yourself, also: add `addons/gaea/SOURCES.md` (origin URL + exact version/commit + MIT license, like
`assets/sounds/SOURCES.md`) and enable the plugin in `project.godot` under `[editor_plugins]`.

## How to resume (what the loop will finish)

Once `addons/gaea/` is in place, tell me **"Gaea is vendored (version X)"** and I will complete G0.2
under the loop contract:
- write `test/test_gaea_available.gd` (TDD) — asserts Gaea's noise/height-generator class instantiates
  and produces a value **headless** (proves it initializes with no display/GPU);
- add `addons/gaea/SOURCES.md` (origin + the version you name + MIT) if you didn't;
- enable the plugin in `project.godot`;
- run the full suite + `./lint.sh`, invoke the tester + reviewer subagents;
- commit `G0.2: ...`, check it off in `PROGRESS.md`, then run Phase-Exit G0 and tag `phase-G0-complete`.

## Why the whole rest of the G-series is also waiting on humans

- **G1** (the `TerrainField` module) depends on G0.2 — it needs Gaea present. So it cannot start until
  the addon is vendored.
- **G2+** additionally requires **🎮 Gate A2 to record GO** — a human playtest of the just-finished
  R5–R8 legibility build (`AWAIT_PLAYTEST.md` is written and waiting). Until you play it and record GO
  on the Gate A2 line in `PROGRESS.md`, WorldView integration stays blocked by design.

So two human actions unblock the terrain effort: **(a)** vendor Gaea (this file), and **(b)** clear
Gate A2. Both can happen in either order. I have stopped the hourly watch — polling is pointless while
the blockers are human. Ping me when either is ready.

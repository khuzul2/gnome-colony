# Gnome Colony — developer notes

Godot 4.7 · GDScript · headless-testable simulation core.
Read `CLAUDE.md` and `docs/implementation-plan.md` §0 before touching anything.

## Prerequisites
- `godot` 4.7 on PATH (headless-capable Linux binary is fine)
- `gdtoolkit` (`pip install gdtoolkit`) for `gdformat` / `gdlint`
- GUT v9.5.0 is **vendored** at `addons/gut/` — do not re-download it
  (GitHub archive downloads are blocked in the build environment).

## First run after a fresh checkout
```
godot --headless --import
```
(imports GUT class_names into the gitignored `.godot/` cache; required once,
and again whenever `.godot/` is deleted)

## Run the game
```
godot
```
The main scene (`presentation/main.tscn`) boots the **GameShell**
(`presentation/shell/`): main menu → New Game wizard (presets, Quick
Start, optional per-event natural-event frequencies) → the live run —
world view, influence panel with arm-and-paint targeting, aftermath
page, speed controls, save/menu — and, when the last gnome falls, the
Chronicle. Saves land in `user://saves`, ended-run chronicles in
`user://chronicles`, machine settings in `user://settings.cfg`
(presentation-only, never the sim). `game.bat` remains the Windows
debug launcher. The whole flow is covered headless by
`test_game_shell.gd`, `test_run_view.gd`, and
`test/integration/test_phase17_exit.gd` — CI never needs a display.

### Controls (in a run)
- **WASD** pan the camera (rebindable in Settings → Controls).
- **E / Q** or the **mouse wheel** zoom the three-lens (civilization →
  settlement → individual).
- Click an act in the influence panel to **arm** it, then **left-click
  the world** to cast it there (a ring shows where it will land). The
  panel's buttons consume their own clicks; clicks on open ground pick.
- Dwell the camera on a basin (~2 s) to let the Eye **quicken** its
  folk into watchable individuals.

### Manual render/play check (Phase-Exit 23 — needs a display, only a human can sign)
The input/render layer (lighting, camera control, mouse-picking) is
unit-tested headless, but "does it actually look right and feel right"
needs eyes on a windowed build. Run `godot` (not `--headless`) and
confirm:
1. The 3D world is **lit and visible** (heightmap + gnome puppets), not
   a black void behind the HUD.
2. **WASD pans** and **E/Q/wheel zoom**; the camera keeps clearance over
   hills.
3. Arming an act and **left-clicking the ground casts it there** — the
   aftermath page and chronicle name that basin; a **hover ring** tracks
   the cursor while armed.
4. Menus, save/Continue, Settings, Codex, Chronicles all respond.

Record the result (GO / issues) — this is the last check standing
between "green tests" and "playable".

## Run the test suite
```
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit -gexit_on_success
```
Exit code 0 = green.

## Lint / format (project code only — the vendored addon is deliberately
## excluded; the lint gate config formalizing this is T0.3)
```
gdformat sim/ test/ presentation/
gdlint sim/ test/ presentation/
```
Use `gdformat --check` in CI/gates to avoid rewriting files.

## The build loop
`./ralph.sh [max_iterations]` — see `docs/loop-howto.md`. One task per
iteration from `PROGRESS.md`, TDD, tester+reviewer gates, one green commit.

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

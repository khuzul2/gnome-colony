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

## Run the test suite
```
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit -gexit_on_success
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

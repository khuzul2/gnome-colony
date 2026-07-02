# Project: Gnome Colony (Godot 4.7, GDScript)

## Sources of truth (read-only — never edit)
- docs/implementation-plan.md  ← the plan & task contract (read §0 every time)
- docs/evolution-algorithm.md  ← ALL numbers & formulas. Never invent one.
- docs/design.md, docs/setup-and-menus.md
- (context: docs/prototype-spec.md, docs/design-review.md, docs/loop-howto.md)

## How to work (every iteration)
1. Read docs/implementation-plan.md §0 and PROGRESS.md.
2. Do the FIRST unchecked task whose deps are all checked. ONE task only.
3. TDD: write the listed tests first, see them fail, implement, make them pass.
4. Run the FULL suite + lint. Then invoke the `tester` and `reviewer` subagents.
5. Commit `T<id>: <summary>`, check the task off in PROGRESS.md.

## Hard invariants (NEVER break)
- sim/ is plain data+logic: NO Node/scene/render refs. The sim's ONLY inputs are seed, WorldConfig, player influence acts, and focused-region attention (the Eye of God). Graphics/audio/resolution never touch the sim.
- ALL randomness goes through the `Rng` singleton (no randi()/randf()/Time in logic) so systems are reproducible under fixed inputs. A FULL run reproduces only from seed+config+recorded acts+recorded attention (attention is an input by design) — there is no single fixed world per seed.
- Numbers come ONLY from the evolution-algorithm spec — §17 is the single numeric truth (if prose and §17 disagree, §17 wins). Never invent a value; if the spec is silent, write STUCK.md.
- Never weaken or delete a test to go green. A red test means the CODE is wrong.
- No scope creep: don't touch unrelated files or change a public API another task needs without noting it in PROGRESS.md.

## Commands
- First run after a fresh checkout (or whenever .godot/ is missing): godot --headless --import   (imports GUT class_names; the .godot/ cache is gitignored)
- Tests: godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit -gexit_on_success
- Lint: gdformat . && gdlint .
- (The GUT addon is already vendored at addons/gut/, v9.5.0 — network access to GitHub is blocked in this environment; never try to re-download it.)

## When blocked
First restore the tree to the last good commit (`git restore .` to discard your broken, uncommitted edits), THEN write STUCK.md (what's blocking, what you tried) and commit it, STOP. Leave the repo clean so a human sees a clean diff. Do not hack around the spec.

## Playtest gates
At a 🎮 gate in the plan, do NOT proceed: write AWAIT_PLAYTEST.md noting what to evaluate, commit, and STOP. A human records GO before the loop continues. Automated tests cannot judge fun/emergence.

## Git discipline (every iteration)
- One task = ONE commit. Never bundle tasks; never commit red tests, dirty lint, or half-done work.
- Stage intentionally: run `git status`; commit only this task's files; do NOT sweep unrelated changes. (`.gitignore` keeps Godot's `.godot/` cache and logs out.)
- Commit message: `T<id>: <summary>` (optionally a body listing the tests added).
- After a Phase-Exit test passes: `git tag phase-<n>-complete`.
- Rolling back:
  - Botched UNCOMMITTED work → `git restore .` (or `git reset --hard HEAD`) back to the last good commit, then retry. Every commit is a known-green boundary, so this is always safe.
  - A COMMITTED change later proves wrong → `git revert <hash>` (a new undo commit). NEVER rewrite history.
  - A previously-green test suddenly fails → `git log --oneline -n 10` and `git diff` to find the cause; revert the culprit commit, or write STUCK.md if unsure.
- NEVER: `git reset --hard` on pushed commits, `git commit --amend`/`rebase` on shared history, `git push --force`, or deleting history. Do not create branches (commit linearly).
- At iteration start, read `git log --oneline` to corroborate PROGRESS.md before choosing a task.

## Definition of done
Listed tests pass AND full suite green AND lint clean AND committed AND PROGRESS.md updated.

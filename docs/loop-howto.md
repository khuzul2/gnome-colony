# How-To: Run Claude Code in a Multi-Agent Loop to Build This Project

*A practical setup for pointing Claude Code at the implementation plan and letting it grind the project out autonomously, with a loop for persistence and subagents for review/testing. Verify product specifics against the official docs — Claude Code changes fast: https://code.claude.com/docs and https://docs.claude.com/en/docs/claude-code/overview .*

---

## 0. Set realistic expectations first

"One-shot the full project" is the aspiration; the reality is **persistent iteration**. The loop won't flawlessly emit a finished game in one pass. What it *does* well: chip away at a well-specified, **test-gated** plan, one atomic task per iteration, recovering from its own mistakes because **tests reject bad work** and each iteration starts with a **fresh context window** (avoiding the "context rot" that derails long single sessions). Your job is to give it (1) a precise plan, (2) hard guardrails, (3) a green/red test signal, and (4) a sandbox — then supervise, review commits, and tune the prompts when it drifts. Treat it as an overnight junior team you review each morning, not a vending machine.

---

## 1. Prerequisites

- **Claude Code** installed: `npm install -g @anthropic-ai/claude-code` (needs a current Node LTS; confirm version in the docs). Authenticate with your Anthropic plan/API key.
- **Godot 4.7** with the binary named `godot` on your `PATH` (the agent runs it headless for tests).
- **GUT** (Godot Unit Test) addon — the plan's test runner.
- **gdtoolkit**: `pip install gdtoolkit` (provides `gdformat`/`gdlint`).
- **git** (the loop commits every iteration; git history is the agent's long-term memory and your undo button).
- A **disposable sandbox**: a VM, container, or at minimum a dedicated **git worktree** on a throwaway branch (full git setup in §6).

---

## 2. Repository layout

```
gnome-colony/
  .gitignore                 # Godot 4 cache + agent logs (see §6)
  project.godot
  docs/                      # the 4 specs, READ-ONLY (source of truth)
    design.md  evolution-algorithm.md  setup-and-menus.md  implementation-plan.md
  CLAUDE.md                  # persistent project rules (auto-loaded every session)
  PROMPT.md                  # the per-iteration instruction the loop pipes in
  PROGRESS.md                # the task ledger (the agent's on-disk state)
  ralph.sh                   # the loop script
  .claude/
    settings.json            # permissions / config
    agents/
      tester.md
      reviewer.md
      coder.md                # optional
      planner.md              # optional
  sim/  presentation/  test/  addons/gut/   # created by the build itself
```

Put the four specs in `docs/` and tell the agent (in CLAUDE.md) they are **read-only truth**. `PROGRESS.md` is generated from the plan's Appendix A on the first iteration.

---

## 3. The four control files

### 3.1 `CLAUDE.md` — persistent rules (loaded automatically every session)
Keep it short and absolute; this is the guardrail that survives every context reset.

```markdown
# Project: Gnome Colony (Godot 4.7, GDScript)

## Sources of truth (read-only — never edit)
- docs/implementation-plan.md  ← the plan & task contract (read §0 every time)
- docs/evolution-algorithm.md  ← ALL numbers & formulas. Never invent one.
- docs/design.md, docs/setup-and-menus.md

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
- Tests: godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit -gexit_on_success
- Lint: gdformat . && gdlint .

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
```

### 3.2 `PROMPT.md` — the per-iteration instruction (the loop pipes this into a fresh agent)
Because each iteration is a clean context, this must fully re-orient the agent.

```markdown
You are building the Gnome Colony game. Your context is fresh — rely on the files, not memory.

1. Read CLAUDE.md, docs/implementation-plan.md (esp. §0), and PROGRESS.md.
2. If PROGRESS.md does not exist, create it from the plan's Appendix A, commit, and stop.
3. Select the FIRST unchecked task whose dependencies are checked. Work ONLY that task.
4. Follow TDD and the Definition of Done in CLAUDE.md. Use [algo §X] for all numbers.
5. Before committing: run the full test suite and lint, then use the `tester` subagent to
   confirm green and the `reviewer` subagent to check the diff against the invariants.
   - If tester fails: fix and re-run (do not commit red).
   - If reviewer flags a blocker: fix it.
6. Commit, update PROGRESS.md, and STOP this iteration.

Output rules:
- If you completed a task this iteration, end with: <promise>TASK-DONE T<id></promise>
- If ALL tasks are checked and every integration test is green, end with: <promise>PROJECT-COMPLETE</promise>
- If blocked, after writing STUCK.md, end with: <promise>STUCK</promise>
```

### 3.3 `PROGRESS.md` — generated from the plan; the agent checks tasks off as it goes. (See plan Appendix A.)

---

## 4. The loop

### 4.1 Option A — the bash loop (recommended for a big build: true fresh context each iteration)
`ralph.sh`:
```bash
#!/usr/bin/env bash
set -uo pipefail
# Run from inside the build worktree (see §6). Assumes git is initialized & committed.
export GIT_AUTHOR_NAME="ralph-loop" GIT_AUTHOR_EMAIL="ralph@local"   # so git log clearly marks loop commits
MAX=${1:-300}                       # iteration cap (safety)
for ((i=1; i<=MAX; i++)); do
  echo "===== iteration $i/$MAX  $(date) =====" | tee -a ralph.log
  OUT=$(cat PROMPT.md | claude -p \
        --dangerously-skip-permissions \   # ONLY inside a sandbox/VM/worktree (see §6–§7)
        --model opusplan \                 # Opus plans, Sonnet executes — good cost/quality
        2>&1 | tee -a ralph.log)
  echo "$OUT" | grep -q "<promise>PROJECT-COMPLETE</promise>" && { echo "DONE"; break; }
  [ -f STUCK.md ] && { echo "STUCK — human needed (see STUCK.md)"; break; }
done
```
- `-p` = headless mode (read prompt from stdin, act, exit). Without bypassing permissions the loop would halt on the first file write, so you either skip permissions **inside a sandbox** or restrict tools instead: replace the skip flag with `--allowedTools "Read,Write,Edit,Bash,Grep,Glob"` (plus the delegation tool so subagents work — confirm its exact name in the docs).
- Each iteration is a **new process with a clean window**; state persists via the codebase, `PROGRESS.md`, and git. This is the core benefit over one long session.

### 4.2 Option B — supported built-ins (try these first; they survive version updates)
Inside an interactive `claude` session:
- **`/goal <condition>`** — keep working across turns until a verifiable condition holds, e.g. `/goal every Phase-Exit test in test/integration passes and lint is clean`.
- **`/loop`** — re-run a prompt on an interval until you press Esc.
- **`/batch`** — spread one large change across multiple parallel worktree agents.
- The official **`ralph-wiggum` plugin** packages the loop, but note it runs **inside one session and relies on auto-compaction**, which is lossy and can drop your spec mid-run — the bash loop's per-iteration reset avoids that. Use the plugin for convenience, the bash loop for long unattended builds.

---

## 5. Subagents (the "team")

Subagents are Markdown files with YAML frontmatter in `.claude/agents/` (project) or `~/.claude/agents/` (user). The frontmatter sets `name`, `description` (the trigger for auto-delegation — make it explicit), `tools` (restrict them!), and `model`; the body is the system prompt. Manage them with `/agents` (edits there apply immediately; edits to the files on disk need a session restart). Each runs in its **own context window** and returns a single summary — great for keeping the main thread lean. Caveat: subagent-heavy runs can use **~7× the tokens**, so use a *few focused* ones (verification), not a swarm.

### 5.1 `tester` (runs the suite, returns pass/fail)
```markdown
---
name: tester
description: MUST BE USED before any commit. Runs the full GUT suite and lint, returns pass/fail with the exact failing assertions. Does not edit code.
tools: Read, Bash, Grep
model: sonnet
---
You are the test runner. Steps:
1. Run: godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit -gexit_on_success
2. Run: gdformat --check . && gdlint .
Report: PASS or FAIL. On FAIL, list each failing test name and its assertion message, and the lint errors. Never modify files. Return a concise report only.
```

### 5.2 `reviewer` (read-only diff review against the invariants)
```markdown
---
name: reviewer
description: MUST BE USED before any commit. Reviews the working diff for invariant violations and bugs. Read-only — never edits.
tools: Read, Grep, Glob, Bash
model: sonnet
---
You are a strict code reviewer for a Godot/GDScript project. Review `git diff` against CLAUDE.md invariants:
- Does any file under sim/ reference Node/scene/render/input? (forbidden)
- Does any logic use randi()/randf()/Time instead of the Rng singleton? (forbidden)
- Were any tests weakened/deleted to pass? (forbidden)
- Scope creep, broken public APIs, missing [algo §X] adherence?
Return issues by severity (BLOCKER / MAJOR / MINOR) with file:line and a one-line fix each. If clean, say "No blockers."
```

### 5.3 Optional `coder` / `planner` / `architect`
The main per-iteration agent usually writes the code directly (cheaper than delegating). Add a `coder` subagent only if you want implementation isolated from orchestration, or a `planner`/`architect` to validate a task's design before coding (mirrors the pm-spec → architect-review → implementer-tester pipeline pattern). Keep tools minimal and descriptions explicit.

### 5.4 How they compose each iteration
The bash loop spawns the **main agent** (orchestrator/coder). Per `PROMPT.md`, after implementing a task it **delegates to `tester`** (gate: must be green) and **`reviewer`** (gate: no blockers) before committing. So one iteration = pick task → TDD → implement → tester → reviewer → commit → update ledger → exit. Optionally run a **two-phase** setup: a separate read-only loop with a `PROMPT_GAPS.md` that only does gap analysis and updates `PROGRESS.md` (no code), alternated with the build loop.

---

## 6. Git: setup, commits & rollbacks

Git is the loop's memory and your undo button. Set it up before the first run.

### 6.1 One-time setup (human)
```bash
git init
git config user.name  "Your Name"
git config user.email "you@example.com"
```
Create **`.gitignore`** (Godot 4 regenerates a cache you must NOT commit; keep `project.godot`, `*.gd`, `*.tscn`, `*.tres`, and `*.import` files tracked):
```gitignore
# Godot 4 editor/import cache (regenerated)
.godot/
# Exported builds
/build/
/export/
*.pck
*.exe
*.zip
# OS / editor junk
.DS_Store
*~
# Agent loop log (regenerated; keep out of history)
ralph.log
```
Make the **baseline commit** — the clean floor you can always return to — before starting the loop:
```bash
git add .gitignore project.godot docs/ CLAUDE.md PROMPT.md .claude/ ralph.sh
git commit -m "Baseline: specs, control files, scaffold"
```

### 6.2 Isolate the loop on its own branch / worktree
Never run the autonomous loop on your main checkout. Use a **git worktree** on a throwaway branch so the churn is isolated and pairs with the sandbox (§7):
```bash
git worktree add ../gnome-colony-build agent/build   # new branch in a separate dir
cd ../gnome-colony-build
./ralph.sh 50                                         # the loop runs here
```
Review the branch, then merge approved work back:
```bash
git -C /path/to/main merge agent/build      # after you've reviewed it
```

### 6.3 Remote & protection (optional but recommended)
Push the agent branch to a remote for backup/visibility, but **protect `main`** (branch-protection rules) so the loop can never push to it; bring work in via reviewed PRs only:
```bash
git remote add origin <url>
git push -u origin agent/build              # never push the loop to protected main
```

### 6.4 How the agent must use git (enforced via CLAUDE.md §"Git discipline")
- **Atomic, green commits:** one task = one commit, `T<id>: <summary>`, only when tests + lint pass. Never bundle tasks or commit broken/half work.
- **Intentional staging:** check `git status`; commit only the task's files; don't sweep unrelated changes (`.gitignore` handles the cache).
- **Phase tags:** after each Phase-Exit test, `git tag phase-<n>-complete` — clean rollback points and progress markers.
- **Rollback rules the agent follows:** discard botched *uncommitted* work with `git restore .` and retry (every commit is a green boundary); undo a *committed* mistake with `git revert <hash>` (never rewrite history); on a fresh failure in previously-green tests, inspect recent commits and revert the culprit or write `STUCK.md`.
- **Forbidden:** `git reset --hard` on pushed commits, `amend`/`rebase` of shared history, `push --force`, deleting history, creating branches. History stays linear and append-only.
- **On STUCK:** restore to last-good first, then commit `STUCK.md`, so you inherit a clean repo.

### 6.5 Human recovery toolkit
The linear, one-commit-per-task history makes recovery easy:
```bash
git log --oneline                # what the loop did, task by task
git show <hash>                  # inspect one iteration's diff
git revert <hash>                # safely undo a bad committed task
git bisect start / good / bad    # find which commit introduced a regression
git reset --hard phase-2-complete   # on the AGENT branch only: roll a whole bad phase back to a tag
```
Because each iteration is a small, tested, isolated commit, a bad step is cheap to find and undo — which is what lets you trust an unsupervised loop.

## 7. Safety & permissions (sandboxing)

- **Sandbox the whole thing.** `--dangerously-skip-permissions` lets the agent run shell commands and write files unattended — only ever do that in a **disposable VM/container** or a **dedicated git worktree on a throwaway branch**, never your main checkout. Tighter alternative: drop the skip flag and use `--allowedTools` to whitelist only what's needed.
- **Commit every iteration, isolate on a worktree, review before merge** — full git setup, agent commit/rollback rules, and the recovery toolkit are in **§6**.
- **Bound it:** the `MAX` iteration cap, plus watch the cost (each iteration is a full agent run; subagents multiply tokens). Start with a small cap and increase once it's behaving.
- **Background subagents auto-deny** any tool call that would need permission — so a background helper must have all needed tools whitelisted and clear stop conditions, or it silently stalls.
- **Branch protection / review:** never let the loop push to a protected branch; review diffs before merging to main.

---

## 8. Running & operating it

1. **Bootstrap once, supervised.** Run `claude` interactively, ask it (using Plan mode) to scaffold Phase 0 and generate `PROGRESS.md`; review the result by hand. This catches setup mistakes before you go unattended.
2. **Kick off the loop:** `chmod +x ralph.sh && ./ralph.sh 50` (start with a 50-iteration cap).
3. **Monitor:** `tail -f ralph.log` and, in another shell, `watch git log --oneline`. Sanity-check that tests are actually running and tasks are being checked off in order.
4. **On `STUCK`:** read `STUCK.md`, resolve the ambiguity (often a spec gap or a tooling issue), update `CLAUDE.md`/`PROMPT.md` or the plan, delete `STUCK.md`, and resume.
5. **When it drifts** (skips tests, over-scopes, ignores invariants): the fix is almost always **tightening `PROMPT.md`/`CLAUDE.md`**, not babysitting — add the missing rule, reset, continue.
6. **Checkpoints:** after each phase gate, run the suite yourself and skim a few commits before letting it proceed.

---

## 9. Common pitfalls

- **Marking tasks done without real verification.** Mitigations are layered: TDD in the plan, the `tester` gate, the `reviewer` gate, and a periodic human spot-check via `git show`.
- **Context rot in a single long session.** That's exactly what the per-iteration reset (bash loop) prevents; prefer it over the in-session plugin for big builds.
- **Token blow-up from too many subagents.** Keep to `tester` + `reviewer` (+ maybe one more). Route them to Sonnet/Haiku, reserve Opus for planning.
- **Non-determinism sneaking in.** The `reviewer` checks for stray randomness; the determinism integration test (plan T12.2) is the backstop.
- **Editing subagent files mid-session and seeing no effect.** File edits need a session restart; use `/agents` for live edits.
- **Letting it run unwatched at scale.** Don't start more (background) agents than you can review; keep the iteration cap conservative until trust is earned.

---

## 10. Minimal start checklist
1. Install Claude Code, Godot 4.7 (`godot` on PATH), GUT, gdtoolkit, git. 2. Create the repo layout (§2) with the four specs in `docs/`. 3. Write `CLAUDE.md`, `PROMPT.md`, `.claude/agents/tester.md`, `.claude/agents/reviewer.md`, `ralph.sh`. 4. **`git init`, add `.gitignore`, make the baseline commit (§6.1).** 5. **Create the build worktree on `agent/build` (§6.2)** — your sandbox. 6. Bootstrap Phase 0 supervised there. 7. `./ralph.sh 50`; watch `ralph.log` and `git log --oneline`; intervene on `STUCK`. 8. Review with `git show`/`git revert`, tag phase gates, merge approved work to `main`. 9. Tune prompts when it drifts; raise the cap as trust grows.

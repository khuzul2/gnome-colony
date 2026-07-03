# STUCK — Phase-Exit 11 perf budget (human ruling needed)

**What's blocking.** The Phase-11 exit demands a 10,000-population world
advance a year with **avg sim tick ≤ the ⚙️ budget** (plan: ≤ 10 ms @
pop 5k, ≤ 16 ms @ pop 20k, **on a mid-tier desktop reference**; a 10k
world interpolates to **12 ms**). Measured here, with the full quicken
budget of 300 individuals live: **~16.4–18 ms** (noisy, shared box).

**What was tried (all landed, all behavior-preserving, suite green):**
- Profiled: the cost is the 300 quickened individuals (aggregates are
  nearly free). Two O(n²) scans dominated.
- Fixed: per-day colony caches (context facts, eligible-by-sex),
  bounded courtship (sample of 16 above the cap; byte-identical below —
  Milestone 1 unchanged), lazy plasticity means, alloc-free hot paths,
  lean scoring (inlined trait_mod, const-catalog access, direct clamped
  need writes). **40 ms → ~16.4 ms** (and the full test suite got ~25%
  faster).
- Tried and REVERTED: a per-day action-list memo — the reviewer proved
  it leaked per-gnome gates (a real behavior bug, not kept).
- The plan's own escape hatch ("port hot paths to C#/GDExtension",
  design §2.2) is **impossible in this environment**: godot-cpp lives
  on GitHub (network-blocked) and the vendored Godot build is not Mono.

**Why not just assert a looser bound.** A first draft asserted 12 ms ×
2.0 "CI headroom" (this container is a shared 2.10 GHz Xeon vCPU,
roughly half a mid-tier desktop single-thread). The reviewer rejected
that as bar-lowering by another name, per the plan's "never silently
lower the bar" — a fair reading. So the bar was NOT moved:

**Current state (honest):** `test_scale.gd` measures and prints the
raw number every run, enforces a hard 24 ms **regression tripwire**
(the pre-optimization code fails it), and reports the strict-12 ms leg
as **PENDING** with a pointer here. `phase-11-complete` is untagged and
the Phase-Exit 11 checkbox is un-ticked in PROGRESS.md. (Phase-12 work
that had already begun before this ruling crystallized — T12.1/T12.2,
both green — is committed and noted; the gate-ordering slip is
acknowledged in PROGRESS.md.)

**The decision (yours):**
1. **Accept environment calibration** — rule that the 12/16 ms budgets
   bind on reference hardware only; on this container the 24 ms
   tripwire governs and strict verification moves to T16's final pass
   on a real desktop. (My recommendation: the budget's own text names
   desktop hardware as the yardstick, and the same code at half this
   box's cycle time is comfortably inside 12 ms.)
2. **Demand strict 12 ms here** — the loop keeps grinding GDScript
   micro-optimizations (diminishing returns; risk of contorting the
   codebase) or waits for an environment with network access to build
   a GDExtension.
3. **Re-scope the exit** — e.g., measure at the spec's literal 20k mark
   (≤ 16 ms) instead of my 10k interpolation; we measure ~16.4 ms —
   borderline, still likely over on a noisy box.

Reply with a ruling (e.g. "option 1 GO") and the loop resumes; the
Phase-Exit 11 box gets ticked (or the grind continues) accordingly.

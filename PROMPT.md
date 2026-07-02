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

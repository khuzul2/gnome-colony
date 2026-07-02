#!/usr/bin/env bash
set -uo pipefail
# The build loop (see docs/loop-howto.md §4). Run from inside the build checkout.
# Each iteration spawns a FRESH claude process (clean context); state persists via
# the codebase, PROGRESS.md, and git. Only run with skip-permissions inside a
# sandbox/VM/worktree (docs/loop-howto.md §6–§7).
#
# Usage: ./ralph.sh [max_iterations]   (default 50)
#   MODEL=opusplan ./ralph.sh 50       to override the model.

export GIT_AUTHOR_NAME="ralph-loop" GIT_AUTHOR_EMAIL="ralph@local"
MAX=${1:-50}
MODEL=${MODEL:-opusplan}

for ((i = 1; i <= MAX; i++)); do
  echo "===== iteration $i/$MAX  $(date) =====" | tee -a ralph.log
  OUT=$(claude -p \
    --dangerously-skip-permissions \
    --model "$MODEL" \
    <PROMPT.md 2>&1 | tee -a ralph.log)

  if echo "$OUT" | grep -q "<promise>PROJECT-COMPLETE</promise>"; then
    echo "DONE — project complete" | tee -a ralph.log
    break
  fi
  if [ -f STUCK.md ]; then
    echo "STUCK — human needed (see STUCK.md)" | tee -a ralph.log
    break
  fi
  if [ -f AWAIT_PLAYTEST.md ]; then
    echo "PLAYTEST GATE — human go/no-go needed (see AWAIT_PLAYTEST.md)" | tee -a ralph.log
    break
  fi
done

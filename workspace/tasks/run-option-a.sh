#!/usr/bin/env bash
# Runs the remaining (task, skill) pairs of data-collection scope A one after
# another (never in parallel - every pair toggles the same machine settings).
# Scope A = 2 skills x 4 tasks (one per task type). The pilot pair
# bugfix-01 + caveman is run separately first.
#
# Repos are run from BENCH_DIR, a clone OUTSIDE the project folder: Claude Code
# loads every parent CLAUDE.md, and the project CLAUDE.md contains task answers
# (found 2026-10-11 - all runs inside the project tree saw it).
BENCH_DIR="${BENCH_DIR:-$HOME/bench}"
set -u
WS="$(cd "$(dirname "$0")/.." && pwd)"
cd "$WS"
VERIF="$WS/skills/verification-before-completion"

PAIRS=(
  "bugfix-01 caveman command /caveman full"
  "bugfix-01 verification-before-completion file $VERIF"
  "refactor-01 caveman command /caveman full"
  "refactor-01 verification-before-completion file $VERIF"
  "feature-01 caveman command /caveman full"
  "feature-01 verification-before-completion file $VERIF"
  "explain-01 caveman command /caveman full"
  "explain-01 verification-before-completion file $VERIF"
)

for p in "${PAIRS[@]}"; do
  read -r task skill stype sarg <<<"$p"
  T="tasks/$task"
  log="results/run-$task-$skill.log"
  echo "=== $(date '+%H:%M:%S') start $task + $skill" | tee -a results/option-a-progress.log
  bash tasks/run-skill-batch.sh "$BENCH_DIR/$(cat "$T/repo.txt")" "$(cat "$T/base.tag")" \
    "$T/prompt.txt" "$task" "$skill" "$stype" "$sarg" > "$log" 2>&1
  echo "=== $(date '+%H:%M:%S') done  $task + $skill exit=$?" | tee -a results/option-a-progress.log
done

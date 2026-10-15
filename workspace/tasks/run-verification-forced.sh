#!/usr/bin/env bash
# Runs verification-before-completion with FORCED invocation (skill_type
# file-command) on the 4 scope-A tasks, one pair after another (never in
# parallel - every pair toggles the same machine settings).
#
# Repos are run from BENCH_DIR (default $HOME/bench), clones OUTSIDE this
# repository - see README "Why the sample repos must live outside".
set -u
WS="$(cd "$(dirname "$0")/.." && pwd)"
cd "$WS"
REPO_ROOT="${BENCH_DIR:-$HOME/bench}"
VERIF="$WS/skills/verification-before-completion"

for task in bugfix-01 refactor-01 feature-01 explain-01; do
  T="tasks/$task"
  echo "=== $(date '+%H:%M:%S') start $task + verification-forced" | tee -a results/verification-forced-progress.log
  bash tasks/run-skill-batch.sh "$REPO_ROOT/$(cat "$T/repo.txt")" "$(cat "$T/base.tag")" \
    "$T/prompt.txt" "$task" verification-forced file-command "$VERIF" \
    > "results/run-$task-verification-forced.log" 2>&1
  echo "=== $(date '+%H:%M:%S') done  $task exit=$?" | tee -a results/verification-forced-progress.log
done

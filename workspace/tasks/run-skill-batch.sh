#!/usr/bin/env bash
# generic headless off-vs-1-skill batch runner (replaces run-batch.sh's
# hardcoded 3-way off/token/accuracy cycle).
#
# Design: every candidate skill, whatever it claims to optimize, is tested
# the same way — off vs that skill, n=3 reps, alternating. Every run (off or
# skill) gets BOTH token/cost (from the session log, automatic) AND accuracy
# (from RUBRIC-กลาง.md's blind grading form) measured — there is no such
# thing as a "token-only" or "accuracy-only" run. "token"/"accuracy" are not
# metric names here, they're just what a given skill happens to claim to
# improve; the measurement pipeline is identical for every skill.
#
# To test N skills on a task: run this script N times (once per skill), not
# once with an N-way interleaved cycle — keeps each skill's comparison
# self-contained and lets you add a skill later without re-running anything.
#
# Usage:
#   bash run-skill-batch.sh <repo_path> <base_tag> <prompt_file> <task_id> \
#        <skill_name> <skill_type:file|command> <skill_arg> [results_root]
#
# Output: <results_root>/<task_id>-<skill_name>/run-<N>/ — auto-numbered, so
# re-running the same (task, skill) pair (e.g. after a methodology fix) never
# collides with or overwrites a previous run's output. Contains runs.csv,
# runs-tokens.csv, report.md, report-KEY.md, report-scored.md (AI-graded, blind,
# 3-pass majority vote — see grade_runs.py), diffs/. results_root defaults to
# <workspace>/results.
#
# skill_type=file:    skill_arg = path to the skill's source folder (the
#                      standard Agent Skills mechanism — copied into
#                      <repo>/.claude/skills/<basename>/ before each skill
#                      run, removed right after, before the diff is captured)
# skill_type=command: skill_arg = priming command text, e.g. "/caveman full"
#                      (sent as turn 1 in a fresh session; the task prompt is
#                      sent as turn 2 via --resume — for plugins like Caveman
#                      that toggle via slash command instead of a skill file)
# skill_type=combo:   skill_arg = path to a directory containing MULTIPLE
#                      skill source folders (one level, each with its own
#                      SKILL.md) — every one of them is copied into
#                      <repo>/.claude/skills/ at once for the "skill"
#                      condition (exploratory "รวมมิตร" pilot: stack every
#                      candidate skill instead of isolating one). Also layers
#                      in the two skills that don't fit the plain file/command
#                      shape:
#                        - Caveman, primed the same way as skill_type=command
#                          (turn 1 = "/caveman full", turn 2 = the real
#                          prompt via --resume)
#                        - claude-token-efficient's compressed CLAUDE.md
#                          profile, dropped as <repo>/CLAUDE.md for the
#                          duration of the run (none of the 3 sample repos
#                          track a root CLAUDE.md, so this is always a clean
#                          add/remove, never a real overwrite)
#                      Expects <dirname skill_arg>/claude-token-efficient-profile/CLAUDE.compressed.md
#                      to exist alongside skill_arg (see workspace/skills/).
#                      Same cleanup discipline as file/command: everything
#                      injected is removed BEFORE capture_diff, so none of it
#                      leaks into the graded diff.
#
#                      off stays 1-turn even when skill_type=command — this
#                      matches real off usage (a real off user never sends a
#                      priming message). An earlier version made off ALSO
#                      2-turn (neutral no-op turn 1) to "match" the skill
#                      condition's turn count, on the theory that the extra
#                      turn's cache-write cost was an unfair structural
#                      artifact. Reverted: that neutral turn has no
#                      real-world counterpart, so it just inflated off's
#                      reported cost with a fictional cost real off users
#                      never pay — and empirically it barely closed the gap
#                      anyway (cache_w1h ~4-7x higher on skill runs either
#                      way, because the skill's activation reply is
#                      non-deterministic/stylized and rarely cache-hits,
#                      while the neutral turn's bland reply mostly did). The
#                      extra activation-turn cost on the skill side is real:
#                      whenever a fresh session invokes a command-type skill,
#                      that tax is genuinely paid — it just amortizes away
#                      across multiple tasks in one long session, which this
#                      harness's one-task-per-fresh-session design doesn't
#                      capture. Note that as a limitation when reporting,
#                      don't try to engineer it out of the off side.
#
# Examples:
#   bash run-skill-batch.sh "$REPO" bugfix-01-base "$TASKDIR/prompt.txt" \
#     bugfix-01 verification-before-completion file \
#     "$WORKSPACE_ROOT/skills/verification-before-completion"
#
#   bash run-skill-batch.sh "$REPO" bugfix-01-base "$TASKDIR/prompt.txt" \
#     bugfix-01 caveman command "/caveman full"
#
# Uses --permission-mode acceptEdits — REPO must be a disposable sample
# project reset via git every run. Do not point this at a real repo.
set -euo pipefail

REPO="$1"; TAG="$2"; PROMPT_FILE="$3"; TASK_ID="$4"
SKILL_NAME="$5"; SKILL_TYPE="$6"; SKILL_ARG="$7"

# Output layout: <results_root>/<task_id>-<skill_name>/run-<N>/ — everything
# for one batch invocation (csv, tokens csv, both reports, diffs/) lives
# together in its own numbered folder, so re-running the same (task, skill)
# pair (e.g. after a methodology fix) never overwrites or scatters previous
# output — it just gets the next N. <results_root> defaults to
# <workspace>/results ($8 overrides it; this script lives at
# <workspace>/tasks/run-skill-batch.sh, so workspace root is its parent's
# parent).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$WORKSPACE_ROOT/.." && pwd)"
RESULTS_ROOT="${8:-$WORKSPACE_ROOT/results}"

# Prefer the project-local copy (ships with this folder on any machine);
# fall back to the global one for machines that still only have it there.
ENV_TOGGLE_DIR="$PROJECT_ROOT/.claude/skills/env-toggle"
[ -d "$ENV_TOGGLE_DIR" ] || ENV_TOGGLE_DIR="$HOME/.claude/skills/env-toggle"
PAIR_DIR="$RESULTS_ROOT/${TASK_ID}-${SKILL_NAME}"
mkdir -p "$PAIR_DIR"

# Resolve to absolute paths up front — reset_repo() below does a bare `cd
# "$REPO"` (not in a subshell, so it persists across the whole script). A
# relative $REPO would resolve against a different cwd on every subsequent
# call once that first cd has moved the script's own directory, e.g. trying
# to cd into "<repo>/workspace/sample-project" on the second run.
REPO="$(cd "$REPO" && pwd)"
PAIR_DIR="$(cd "$PAIR_DIR" && pwd)"

N=1
while [ -d "$PAIR_DIR/run-$N" ]; do N=$((N+1)); done
RUN_DIR="$PAIR_DIR/run-$N"
DIFF_DIR="$RUN_DIR/diffs"
mkdir -p "$DIFF_DIR"
OUT_CSV="$RUN_DIR/runs.csv"

PROMPT="$(cat "$PROMPT_FILE")"
# Pin the exact model ID (never an alias like "sonnet", which silently moves to
# the newest release). Without --model, claude uses the machine's /model default,
# which may not be Sonnet at all. Override with MODEL only on purpose.
MODEL="${MODEL:-claude-sonnet-5-5}"
# Keep the CLI version fixed for the whole data-collection window.
export DISABLE_AUTOUPDATER=1
CLAUDE_FLAGS=(--model "$MODEL" --effort medium --permission-mode acceptEdits --add-dir "$REPO" --output-format json)

# Record what this batch actually ran with, for reproducibility.
{
  echo "started_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "model=$MODEL"
  echo "claude_cli=$(claude --version 2>/dev/null)"
  echo "task_id=$TASK_ID"
  echo "skill_name=$SKILL_NAME"
  echo "skill_type=$SKILL_TYPE"
  echo "skill_arg=$SKILL_ARG"
  echo "base_tag=$TAG"
  echo "base_tag_commit=$(git -C "$REPO" rev-parse "$TAG^{commit}" 2>/dev/null)"
} > "$RUN_DIR/run-meta.txt"

if [ "$SKILL_TYPE" != "file" ] && [ "$SKILL_TYPE" != "command" ] && [ "$SKILL_TYPE" != "combo" ] && [ "$SKILL_TYPE" != "file-command" ]; then
  echo "skill_type must be 'file', 'command', 'combo', or 'file-command', got: $SKILL_TYPE" >&2
  exit 1
fi

reset_repo() {
  cd "$REPO"
  git checkout . >/dev/null 2>&1 || true
  # git checkout only reverts TRACKED changes — a run that creates a new
  # file (any additive/feature task) leaves it as an untracked file that
  # neither `git checkout .` nor `git checkout "$TAG"` removes, so it would
  # otherwise leak into every subsequent run in the batch (confirmed: this
  # is what happened to feature-02's combo-all pilot before this fix —
  # UpcomingBookingsReportService.cs from the first skill run survived to
  # contaminate every later off/skill run in that same batch). `git clean
  # -fd` (no -x) removes it while respecting .gitignore, so build output
  # (node_modules/, bin/, obj/, dist/) is left alone.
  git clean -fd >/dev/null 2>&1
  rm -rf .claude/skills
  rm -f CLAUDE.md
  git checkout "$TAG" >/dev/null 2>&1
}

get_session_id() {
  python3 -c "import json,sys; print(json.loads(sys.stdin.read())['session_id'])"
}

# Snapshots the agent's uncommitted changes for later blind grading — must run
# AFTER the claude call but BEFORE reset_repo() wipes the tree on the next run.
capture_diff() {
  local run_code="$1"
  (
    cd "$REPO" || exit 1
    git add -A
    git diff --cached > "$DIFF_DIR/${run_code}.diff"
    git reset >/dev/null
  )
}

# Saves the assistant's final-turn text (e.g. explain-01's answer, where the
# diff is always empty by design — "do not change any files"). Finds the
# session log by session_id (unique across all project dirs, so no need to
# replicate Claude Code's path->slug scheme), then keeps only text blocks
# after the LAST genuine user turn (a "user" entry whose content is not a
# tool_result list) — this drops any command-priming turn's ack (e.g.
# Caveman's turn 1) and keeps just the reply to $PROMPT.
capture_response() {
  local run_code="$1" sid="$2"
  local jsonl
  jsonl=$(ls "$HOME"/.claude/projects/*/"${sid}".jsonl 2>/dev/null | head -1)
  local out_file="$DIFF_DIR/${run_code}.response.txt"
  if [ -z "$jsonl" ]; then
    echo "WARNING: session log not found for $sid ($run_code)" >&2
    : > "$out_file"
    return
  fi
  python3 - "$jsonl" "$out_file" <<'PY'
import json, sys
in_path, out_path = sys.argv[1], sys.argv[2]
buf = []
with open(in_path, encoding='utf-8') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            o = json.loads(line)
        except Exception:
            continue
        t = o.get('type')
        if t == 'user':
            content = o.get('message', {}).get('content')
            is_tool_result = isinstance(content, list) and any(
                isinstance(c, dict) and c.get('type') == 'tool_result' for c in content
            )
            if not is_tool_result:
                buf = []
        elif t == 'assistant':
            content = o.get('message', {}).get('content', [])
            if isinstance(content, list):
                for c in content:
                    if isinstance(c, dict) and c.get('type') == 'text':
                        buf.append(c['text'])
with open(out_path, 'w', encoding='utf-8') as f:
    f.write('\n\n'.join(buf))
PY
}

run_off() {
  local run_code="$1"
  reset_repo
  local sid
  sid=$(cd "$REPO" && claude -p "$PROMPT" "${CLAUDE_FLAGS[@]}" | get_session_id)
  capture_diff "$run_code"
  capture_response "$run_code" "$sid"
  echo "$sid"
}

run_skill() {
  local run_code="$1"
  reset_repo
  local sid

  if [ "$SKILL_TYPE" = "file" ]; then
    local skill_dir_name
    skill_dir_name="$(basename "$SKILL_ARG")"
    mkdir -p "$REPO/.claude/skills/$skill_dir_name"
    cp -r "$SKILL_ARG"/* "$REPO/.claude/skills/$skill_dir_name/"
    sid=$(cd "$REPO" && claude -p "$PROMPT" "${CLAUDE_FLAGS[@]}" | get_session_id)
    # remove BEFORE capture_diff — it's our test harness, not the agent's work
    rm -rf "$REPO/.claude/skills/$skill_dir_name"
  elif [ "$SKILL_TYPE" = "file-command" ]; then
    # Forced invocation: install the skill file AND invoke it explicitly as a
    # slash command with the task prompt as its arguments, in a single turn.
    # Added 2026-10-11 after verification-before-completion was never
    # auto-invoked by the model in 12 file-type runs.
    local skill_dir_name
    skill_dir_name="$(basename "$SKILL_ARG")"
    mkdir -p "$REPO/.claude/skills/$skill_dir_name"
    cp -r "$SKILL_ARG"/* "$REPO/.claude/skills/$skill_dir_name/"
    sid=$(cd "$REPO" && MSYS_NO_PATHCONV=1 claude -p "/$skill_dir_name $PROMPT" "${CLAUDE_FLAGS[@]}" | get_session_id)
    rm -rf "$REPO/.claude/skills/$skill_dir_name"
  elif [ "$SKILL_TYPE" = "combo" ]; then
    mkdir -p "$REPO/.claude/skills"
    for d in "$SKILL_ARG"/*/; do
      cp -r "$d" "$REPO/.claude/skills/$(basename "$d")"
    done
    local profile="$(dirname "$SKILL_ARG")/claude-token-efficient-profile/CLAUDE.compressed.md"
    [ -f "$profile" ] && cp "$profile" "$REPO/CLAUDE.md"
    # Caveman priming, same 2-turn shape as skill_type=command.
    sid=$(cd "$REPO" && MSYS_NO_PATHCONV=1 claude -p "/caveman full" "${CLAUDE_FLAGS[@]}" | get_session_id)
    (cd "$REPO" && claude -p "$PROMPT" --resume "$sid" "${CLAUDE_FLAGS[@]}") >/dev/null
    # remove everything injected BEFORE capture_diff — harness, not the agent's work
    rm -rf "$REPO/.claude/skills"
    rm -f "$REPO/CLAUDE.md"
    rm -f "$HOME/.claude/.caveman-active"
  else
    # command type. MSYS_NO_PATHCONV=1 required — Git Bash mangles a leading
    # "/xxx" into a Windows path, silently breaking the slash command.
    # Confirmed via testing on Caveman (/caveman full).
    sid=$(cd "$REPO" && MSYS_NO_PATHCONV=1 claude -p "$SKILL_ARG" "${CLAUDE_FLAGS[@]}" | get_session_id)
    (cd "$REPO" && claude -p "$PROMPT" --resume "$sid" "${CLAUDE_FLAGS[@]}") >/dev/null
    # deterministic reset — don't rely on the model to say "stop". Harmless
    # no-op for command-type skills other than Caveman.
    rm -f "$HOME/.claude/.caveman-active"
  fi

  capture_diff "$run_code"
  capture_response "$run_code" "$sid"
  echo "$sid"
}

echo "Backing up + applying controlled-run machine settings..."
bash "$ENV_TOGGLE_DIR/scripts/off.sh"

echo "run_code,task_id,skill_name,condition,order,session_id" > "$OUT_CSV"

echo "Burn-in (discarded)..."
run_off   burnin-off             >/dev/null
run_skill "burnin-${SKILL_NAME}" >/dev/null

order=1
for i in 1 2 3; do
  echo "Cycle $i/3: off..."
  sid=$(run_off "off$i")
  echo "off$i,$TASK_ID,$SKILL_NAME,off,$order,$sid" >> "$OUT_CSV"
  order=$((order+1))

  echo "Cycle $i/3: $SKILL_NAME..."
  sid=$(run_skill "${SKILL_NAME}${i}")
  echo "${SKILL_NAME}${i},$TASK_ID,$SKILL_NAME,skill,$order,$sid" >> "$OUT_CSV"
  order=$((order+1))
done

reset_repo
echo "Restoring machine settings..."
bash "$ENV_TOGGLE_DIR/scripts/restore.sh"

echo "Done. 6 real runs (+2 burn-in) → $RUN_DIR"
cat "$OUT_CSV"

TOKENS_CSV="${OUT_CSV%.csv}-tokens.csv"
echo "Extracting token/cost per run..."
python3 "$SCRIPT_DIR/extract_tokens.py" "$OUT_CSV" "$TOKENS_CSV"
cat "$TOKENS_CSV"

echo "Building blind grading report..."
python3 "$SCRIPT_DIR/generate_report.py" "$OUT_CSV" "$TOKENS_CSV" "$DIFF_DIR" "$TASK_ID" "$SKILL_NAME" "$(dirname "$OUT_CSV")"

echo "AI grading (blind, 3-pass majority vote)..."
python3 "$SCRIPT_DIR/grade_runs.py" "$(dirname "$OUT_CSV")/report.md" "$TASK_ID" "$(dirname "$OUT_CSV")"

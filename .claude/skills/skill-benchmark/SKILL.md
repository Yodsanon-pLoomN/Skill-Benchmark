---
name: skill-benchmark
description: Use when running an off-vs-skill benchmark (token/cost + accuracy) for a candidate Claude Code skill against a task in a disposable sample repo. Wraps `workspace/tasks/run-skill-batch.sh` — env prep, burn-in, 3x alternating off/skill runs, diff capture, token/cost extraction, blind AI grading (checklist, 3-pass majority vote) and machine restore. Trigger phrases like "รัน skill X บน task Y", "ทดสอบ skill กับ task", "เก็บข้อมูล off vs skill", "benchmark skill".
---

# Skill benchmark (off vs 1 skill)

Runs one (task, skill) pair: 2 burn-in runs (discarded) + 6 measured runs
alternating off/skill (n = 3 each). Every run is measured for tokens/cost
(from the session log) and graded blind against the task's `checklist.md`.
This skill is only the trigger — `workspace/tasks/run-skill-batch.sh` does the work.

All paths below are relative to the repository root (the folder containing
this `.claude/`).

## Before running — check, do not assume

1. Run from **Git Bash** on Windows (not WSL `bash.exe`, not PowerShell).
2. Sample repos exist outside this repository at `${BENCH_DIR:-$HOME/bench}`
   (`scripts/setup-sample-repos.sh` creates them). Never use a repo inside
   this repository — parent `CLAUDE.md` / `.claude/skills` would leak into the
   agent under test.
3. Dependencies installed in the target repo: `node_modules` (and `.env` for
   `sample-project`), or `dotnet restore` for `sample-project-reports-api`.
   If missing, stop and tell the user.
4. For `file` / `file-command` / `combo`: the skill folder exists under
   `workspace/skills/<name>/` with a `SKILL.md`.
   For `command`: the plugin is installed (e.g. Caveman: `/plugin install caveman@caveman`).
5. Ask the user to confirm before starting: it costs real money/usage, takes
   30-60 min, runs `git reset --hard` / `git clean -fd` in the sample repo,
   and `env-toggle` temporarily edits `~/.claude/settings.json`, `~/.claude.json`
   and moves `~/.claude/CLAUDE.md`.

## How to run

From `workspace/`:

```bash
T=tasks/<task_id>
bash tasks/run-skill-batch.sh "$HOME/bench/$(cat $T/repo.txt)" "$(cat $T/base.tag)" \
  $T/prompt.txt <task_id> <skill_name> <skill_type> <skill_arg>
```

| skill_type | skill_arg | Meaning |
|---|---|---|
| `file` | `skills/<name>` | skill copied into the repo; the model decides whether to use it |
| `file-command` | `skills/<name>` | copied in and invoked explicitly as `/<name> <prompt>` |
| `command` | e.g. `"/caveman full"` | sent as turn 1, task prompt as turn 2 (`--resume`) |
| `combo` | folder of several skill folders | all copied in at once |

Examples:

```bash
bash tasks/run-skill-batch.sh "$HOME/bench/$(cat $T/repo.txt)" "$(cat $T/base.tag)" $T/prompt.txt bugfix-01 caveman command "/caveman full"
bash tasks/run-skill-batch.sh "$HOME/bench/$(cat $T/repo.txt)" "$(cat $T/base.tag)" $T/prompt.txt bugfix-01 verification-before-completion file skills/verification-before-completion
bash tasks/run-skill-batch.sh "$HOME/bench/$(cat $T/repo.txt)" "$(cat $T/base.tag)" $T/prompt.txt bugfix-01 verification-forced file-command skills/verification-before-completion
```

**A batch takes longer than the 10-minute Bash tool limit.** Run it with
`run_in_background: true`, redirect output to a log
(`> results/run-<task>-<skill>.log 2>&1`), and wait for the completion
notification instead of polling in a tight loop. Never start two batches at
once — every batch toggles the same machine settings.

If a batch dies midway, restore the machine:
`bash .claude/skills/env-toggle/scripts/restore.sh`

## Output

`workspace/results/<task_id>-<skill_name>/run-<N>/` (N auto-increments, nothing is overwritten):

| File | Content |
|---|---|
| `run-meta.txt` | model, CLI version, skill, base tag + commit, start time |
| `runs.csv` | run order, condition, session ID |
| `runs-tokens.csv` | tokens, cost (USD), cold-equivalent cost, cache hit ratio |
| `diffs/` | code diff + final response text of every run |
| `report.md` / `report-KEY.md` | blind report (labels A-F) and its key |
| `report-scored.md` | checklist verdicts, score %, PASS (>= 80%) / FAIL |

After it finishes, report to the user: median output tokens and cost per
condition (from `runs-tokens.csv`) and PASS count per condition (from
`report-scored.md` + `report-KEY.md`). Optionally build an Excel summary:

```bash
python tasks/summarize_results.py summary.xlsx results/<task_id>-<skill_name>/run-<N>
```

Decision rule (n = 3): a difference is real only when the off and skill
min-max ranges do not overlap; otherwise report it as inconclusive.

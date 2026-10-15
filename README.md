# claude-skill-benchmark

A headless benchmark harness that measures how a Claude Code **skill / plugin** changes
**token usage, cost and result accuracy** on realistic software-engineering tasks.

Each experiment compares one skill against a no-skill baseline (`off` vs `skill`) on the same
task, from the same git tag, with the same model. Tokens and cost come straight from Claude
Code's session logs. Accuracy is graded blind by an AI grader against a task-specific yes/no
checklist.

The harness does not depend on any particular skill. Any skill can be plugged in: a skill
folder (`SKILL.md`), a slash command, or several skills at once.

> Built as a university co-op project (Computer Science, Khon Kaen University, 2026).
> Thai summary: [ภาษาไทย](#ภาษาไทย)

## What is in this repository

```
.claude/skills/
  skill-benchmark/        Claude Code skill describing how to run the benchmark
  env-toggle/             scripts that switch global confounders off/on around a batch
workspace/tasks/
  run-skill-batch.sh      main runner: one (task, skill) pair = 2 burn-in + 6 measured runs
  extract_tokens.py       reads session logs -> tokens, cost, cache hit ratio
  generate_report.py      collects diffs and answers into a blind report (labels A-F)
  grade_runs.py           AI grader: 3 independent passes, majority vote per checklist item
  summarize_results.py    builds an Excel workbook (medians, min-max, decision rule, charts)
  run-option-a.sh         example: 4 tasks x 2 skills, run one pair after another
  run-verification-forced.sh  example: forced skill invocation (skill_type file-command)
  RUBRIC-กลาง.md          rules for writing checklists and grading
  <task-id>/              12 tasks: prompt.txt, NOTES.md, checklist.md, base.tag, repo.txt
sample-repos/             3 sample projects as git bundles (with all task tags)
results-2026-10/          raw results of the 12 pairs reported in the study
scripts/setup-sample-repos.sh
```

### Sample projects

All code is fictional, written only for this benchmark (a meeting-room booking domain).

| Bundle | Stack | Tags |
|---|---|---|
| `sample-project` | Node.js, TypeScript, Hapi.js, Prisma (SQLite), Vitest | `base-clean`, `bugfix-01/02/03-base`, `refactor-01/02-base`, `explain-02-base` |
| `sample-project-reports-api` | ASP.NET Core 8, EF Core (SQLite) | `feature-01-base` |
| `sample-project-webapp` | Angular 18 | `explain-01-base`, `refactor-03-base` |

### Tasks

12 tasks in 4 types, 3 per type: `bugfix`, `refactor`, `feature`, `explain`. Each task folder contains:

- `prompt.txt`: the exact prompt given to the agent.
- `base.tag`: the git tag the repo is reset to before every run.
- `repo.txt`: which sample repo to use.
- `NOTES.md`: the defect or intended change and worked examples. **It contains the answers, so the agent must never see it.**
- `checklist.md`: 8-13 yes/no questions used by the grader.

## How one batch works

`run-skill-batch.sh` runs one (task, skill) pair:

1. `env-toggle off`: backs up and disables global confounders (hooks, other plugins, global
   `CLAUDE.md`, MCP servers), pins effort to medium.
2. Burn-in: 1 `off` run + 1 `skill` run that are not counted (they warm the prompt cache).
3. 6 measured runs, alternating `off`, `skill`, `off`, `skill`, ... (n = 3 per condition).
   Before each run the repo is reset with `git reset --hard <base_tag> && git clean -fd`.
   After each run the diff is captured.
4. `env-toggle restore`.
5. `extract_tokens.py`: input, output, cache read/write tokens, cost and cold-equivalent cost per run.
6. `generate_report.py`: shuffles runs into a blind report (labels A-F). The key is kept separately.
7. `grade_runs.py`: `claude -p` grades every run against `checklist.md`, 3 independent passes,
   majority vote per item. A run passes at 80% or more.

Every run is `claude -p --model claude-sonnet-5-5 --effort medium --output-format json`.
The model ID is pinned (not an alias) and `DISABLE_AUTOUPDATER=1` is set. Each batch writes
`run-meta.txt` with the model, CLI version, skill and base commit.

### Skill types

| `skill_type` | `skill_arg` | Mechanism |
|---|---|---|
| `file` | path to a skill folder | copied into `<repo>/.claude/skills/` for skill runs; the model decides whether to invoke it |
| `command` | e.g. `/caveman full` | sent as turn 1, task prompt sent as turn 2 via `--resume` |
| `file-command` | path to a skill folder | copied in **and** invoked explicitly as `/<skill> <prompt>` (forced invocation) |
| `combo` | folder containing several skill folders | all copied in at once |

## Requirements

- [Claude Code](https://docs.claude.com/en/docs/claude-code) CLI, logged in. **Runs cost real money or subscription usage.**
- Bash. On Windows use Git Bash (the scripts set `MSYS_NO_PATHCONV=1` where needed).
- Python 3 and `openpyxl` (`pip install openpyxl`, only needed for `summarize_results.py`).
- Node.js 20+ and the .NET 8 SDK for the sample repos.
- The skills you want to test, for example:
  - Caveman: install the plugin from <https://github.com/JuliusBrussee/caveman>.
  - verification-before-completion: copy `skills/verification-before-completion/` from
    <https://github.com/obra/superpowers> into `workspace/skills/verification-before-completion/`.
    `workspace/skills/` is git-ignored because the skills belong to their authors.

## Setup

```bash
git clone <this repo> claude-skill-benchmark
cd claude-skill-benchmark
BENCH_DIR="$HOME/bench" bash scripts/setup-sample-repos.sh
# then install dependencies as printed by the script (npm ci / dotnet restore)
```

### Why the sample repos must live outside this repository

Claude Code loads `CLAUDE.md` files and `.claude/skills/` from **every parent directory** of
the working directory. If the sample repos sit inside this repository, the agent under test
can see the harness skills, and possibly any notes containing task answers. That contaminates
both conditions. In our own study this happened once and the whole batch had to be discarded.
Always clone the sample repos to a separate folder (`BENCH_DIR`, default `$HOME/bench`).
Also make sure no `CLAUDE.md` exists in any parent of `BENCH_DIR`.

## Usage

Run commands from `workspace/`:

```bash
cd workspace
T=tasks/bugfix-01

# a slash-command plugin
bash tasks/run-skill-batch.sh "$HOME/bench/$(cat $T/repo.txt)" "$(cat $T/base.tag)" \
  $T/prompt.txt bugfix-01 caveman command "/caveman full"

# a skill folder, model decides whether to use it
bash tasks/run-skill-batch.sh "$HOME/bench/$(cat $T/repo.txt)" "$(cat $T/base.tag)" \
  $T/prompt.txt bugfix-01 verification-before-completion file skills/verification-before-completion

# the same skill, forced
bash tasks/run-skill-batch.sh "$HOME/bench/$(cat $T/repo.txt)" "$(cat $T/base.tag)" \
  $T/prompt.txt bugfix-01 verification-forced file-command skills/verification-before-completion
```

Results go to `workspace/results/<task>-<skill>/run-<N>/`. The run number increments, so
nothing is ever overwritten:

| File | Content |
|---|---|
| `runs.csv` | run order, condition, session ID |
| `runs-tokens.csv` | tokens, cost (USD), cold-equivalent cost, cache hit ratio per run |
| `diffs/` | the code change of every run |
| `report.md` / `report-KEY.md` | blind report and its label key |
| `report-scored.md` | checklist verdicts and score per run |
| `run-meta.txt` | model, CLI version, skill, base commit, start time |

Never run two batches in parallel. Every batch toggles the same machine-wide settings.

Summarize finished pairs into an Excel workbook:

```bash
python tasks/summarize_results.py summary.xlsx results/bugfix-01-caveman/run-1 results/refactor-01-caveman/run-1
```

The decision rule is deliberately conservative for n = 3. A difference counts only when the
min-max ranges of `off` and `skill` do not overlap. Otherwise the result is "inconclusive".

### Pricing

`extract_tokens.py` uses Claude Sonnet 5.5 prices: $2 / MTok input, $10 / MTok output.
Cache reads are billed at 0.1x input, 5-minute cache writes at 1.25x and 1-hour cache writes
at 2x. Edit `PRICE_IN` / `PRICE_OUT` for another model.

## ⚠️ env-toggle changes your global Claude Code setup

`.claude/skills/env-toggle/scripts/off.sh` edits files in your home directory. It backs them
up first and `restore.sh` puts them back. It:

- removes `PreToolUse` / `PostToolUse` hooks and sets `effortLevel` to `medium` in `~/.claude/settings.json`;
- disables every plugin except Caveman;
- moves `~/.claude/CLAUDE.md` aside;
- removes `mcpServers` from `~/.claude.json`;
- writes Caveman's config at `~/AppData/Roaming/caveman/config.json` (a Windows path) so `off` sessions really start without Caveman.

It was written for one Windows machine. **Read both scripts and adapt them before your first
run.** If a batch is interrupted, run `restore.sh` manually.

## Results of the study (`results-2026-10/`)

12 pairs: 4 tasks (`bugfix-01`, `refactor-01`, `feature-01`, `explain-01`) x 3 conditions.
Each value is the median of 3 runs, `off -> skill`.

| Pair | Output tokens | Cost (USD) | Runs passed |
|---|---|---|---|
| bugfix-01 Caveman | 1,478 -> 1,363 | 0.0842 -> 0.1257 | 6/6 |
| refactor-01 Caveman | 1,934 -> 1,644 | 0.0837 -> 0.1177 | 6/6 |
| feature-01 Caveman | 2,542 -> 2,430 | 0.0812 -> 0.1354 | 6/6 |
| explain-01 Caveman | 2,658 -> 2,509 | 0.0481 -> 0.1101 | 2/6 |
| bugfix-01 verification (model decides) | 1,466 -> 1,503 | 0.0993 -> 0.0964 | 6/6 |
| refactor-01 verification (model decides) | 2,008 -> 1,591 | 0.1051 -> 0.0738 | 6/6 |
| feature-01 verification (model decides) | 4,245 -> 2,683 | 0.1555 -> 0.1106 | 6/6 |
| explain-01 verification (model decides) | 2,998 -> 3,209 | 0.0621 -> 0.0777 | 6/6 |
| bugfix-01 verification (forced) | 1,475 -> 1,448 | 0.0944 -> 0.0990 | 6/6 |
| refactor-01 verification (forced) | 1,970 -> 2,311 | 0.0944 -> 0.1374 | 6/6 |
| feature-01 verification (forced) | 4,374 -> 5,787 | 0.1503 -> 0.2031 | 6/6 |
| explain-01 verification (forced) | 2,884 -> 4,090 | 0.0618 -> 0.0828 | 6/6 |

Main observations:

- **Caveman** lowered output tokens in all 4 tasks, by up to about 15%. Cost was higher in all
  4 tasks. Activating the plugin adds instructions to the context, which costs about
  13,000-15,000 extra cache-write tokens per session. With only one task per session, that
  overhead outweighs the output savings. A rough break-even is about 20-50 tasks per session.
- **verification-before-completion** with `file` was never actually invoked by the model
  (0 of 12 skill runs). Differences in that condition are run-to-run variance, not the skill.
  When forced (`file-command`), it raised cost (for example `feature-01` +35%). Accuracy did
  not change, because the baseline already passed every checklist.
- The `explain-01` Caveman pair had 2 failed runs in **each** condition, so the failures are
  not attributable to Caveman.

The `base_tag_commit` values in `run-meta.txt` refer to the original private repositories.
The published bundles were rebuilt with clean history, so the commit hashes differ. The file
trees at each tag are identical, except for wording in `docs/README.md` of `sample-project-reports-api`.

## Limitations

- n = 3 per condition, one model (Claude Sonnet 5.5, medium effort), 4 of the 12 tasks run.
- One task per fresh session. Results do not cover long sessions where cache overhead is amortized.
- The grader is also an LLM. 3-pass majority voting reduces, but does not remove, grader noise.
- The sample projects are small. Real codebases have much larger contexts.

## License

[MIT](LICENSE). Third-party skills (Caveman, superpowers) are **not** included and keep
their own licenses.

---

## ภาษาไทย

ชุดเครื่องมือทดสอบแบบ headless วัดผลของ skill/plugin ของ Claude Code ต่อปริมาณ Token, ต้นทุน และความถูกต้องของผลงาน
เทียบกับการไม่ใช้ skill (off กับ skill) บนงาน 4 ประเภท (bugfix, refactor, feature, explain) ในโปรเจกต์ตัวอย่างที่เขียนขึ้นใหม่ทั้งหมด

ผลงานของโครงงานคือ 3 ส่วน:

1. โปรเจกต์ตัวอย่างเพื่อการทดสอบ 3 repo
2. ชุดงานทดสอบ 12 งานพร้อม checklist ให้คะแนน
3. ชุดเครื่องมือรันและวัดผลอัตโนมัติ

ส่วน skill ที่นำมาทดสอบ (Caveman, verification-before-completion) เป็นของผู้พัฒนาอื่น ใช้ทดสอบ skill ตัวไหนก็ได้

ข้อควรระวัง:

- ต้อง clone โปรเจกต์ตัวอย่างไว้นอกโฟลเดอร์นี้ (ใช้ `scripts/setup-sample-repos.sh`)
- อ่าน `env-toggle` ก่อนรัน เพราะสคริปต์นี้แก้การตั้งค่า Claude Code ทั้งเครื่อง
- การรันเสียค่าใช้จ่ายจริง

ส่วนนี้จัดทำในรายวิชาสหกิจศึกษา สาขาวิทยาการคอมพิวเตอร์ วิทยาลัยการคอมพิวเตอร์ มหาวิทยาลัยขอนแก่น ปีการศึกษา 2569

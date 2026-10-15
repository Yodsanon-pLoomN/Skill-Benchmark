#!/usr/bin/env python3
"""Builds two markdown files from a completed run-skill-batch.sh pair, written
into that run's own <out_dir> (already scoped to <task>-<skill>/run-<N>/, so
filenames here stay unprefixed):

  report.md       — BLIND grading input. Run order is shuffled and labeled
                     Run A/B/C... with no off/skill condition shown, per
                     RUBRIC-กลาง.md's blind-grading rule. Each run's diff (or
                     response text, for read-only tasks) is embedded. Consumed
                     next by grade_runs.py (AI grading, no human scoring step
                     — see report-scored.md), not filled in by hand.
  report-KEY.md    — the label->condition/session_id/token/cost mapping. Do
                     not open until grade_runs.py has produced report-scored.md.

Usage: generate_report.py <base_csv> <tokens_csv> <diff_dir> <task_id> <skill_name> <out_dir>
"""
import csv, os, random, sys

GRADING_NOTE = (
    "> ตรวจโดย `grade_runs.py` อัตโนมัติ (blind, 3 pass อิสระ, majority vote, "
    "เกณฑ์ผ่าน >=80% ของ checklist) — checklist จริงเจาะจงต่อ task อยู่ที่ "
    "`workspace/tasks/<task_id>/checklist.md` กติกากลางดู `RUBRIC-กลาง.md` "
    "ไม่มี rubric 0-4 ฝังในไฟล์นี้อีกต่อไป\n"
)

LABELS = [chr(ord("A") + i) for i in range(26)]


def read_csv(path):
    with open(path, encoding="utf-8") as f:
        return list(csv.DictReader(f))


def read_text(path):
    if not os.path.isfile(path):
        return ""
    with open(path, encoding="utf-8") as f:
        return f.read()


def main():
    base_csv, tokens_csv, diff_dir, task_id, skill_name, out_dir = sys.argv[1:7]
    base_rows = read_csv(base_csv)
    token_rows = {r["run_code"]: r for r in read_csv(tokens_csv)} if os.path.isfile(tokens_csv) else {}

    order = list(range(len(base_rows)))
    random.shuffle(order)

    report_path = os.path.join(out_dir, "report.md")
    key_path = os.path.join(out_dir, "report-KEY.md")

    report_lines = []
    key_lines = []

    report_lines.append(f"# Blind grading input — {task_id} / {skill_name}\n")
    report_lines.append(
        "⚠️ Run labels below are shuffled and do NOT reveal which condition "
        "(off vs skill) produced each one — graded by content only, per the "
        f"blind-grading rule. Key file: `{os.path.basename(key_path)}` "
        "(do not open until grade_runs.py has produced report-scored.md).\n"
    )
    report_lines.append(GRADING_NOTE)
    report_lines.append("---\n")

    key_lines.append(f"# KEY — {task_id} / {skill_name}\n")
    key_lines.append("| Run | run_code | condition | order | session_id | input | output | cache_read | cache_w1h | cost_usd | cost_cold_usd | cache_hit |")
    key_lines.append("|---|---|---|---|---|---|---|---|---|---|---|---|")

    for label, idx in zip(LABELS, order):
        row = base_rows[idx]
        run_code = row["run_code"]
        diff_text = read_text(os.path.join(diff_dir, f"{run_code}.diff")).strip()
        resp_text = read_text(os.path.join(diff_dir, f"{run_code}.response.txt")).strip()

        report_lines.append(f"## Run {label}\n")
        if diff_text:
            report_lines.append("```diff")
            report_lines.append(diff_text)
            report_lines.append("```\n")
        if resp_text:
            report_lines.append("**Response text:**\n")
            report_lines.append(resp_text + "\n")
        if not diff_text and not resp_text:
            report_lines.append("_(no diff, no response captured — flag for investigation)_\n")
        report_lines.append("---\n")

        tr = token_rows.get(run_code, {})
        key_lines.append(
            f"| {label} | {run_code} | {row.get('condition','')} | {row.get('order','')} | "
            f"{row.get('session_id','')} | {tr.get('input','')} | {tr.get('output','')} | "
            f"{tr.get('cache_read','')} | {tr.get('cache_w1h','')} | {tr.get('cost_usd','')} | "
            f"{tr.get('cost_cold_usd','')} | {tr.get('cache_hit','')} |"
        )

    os.makedirs(out_dir, exist_ok=True)
    with open(report_path, "w", encoding="utf-8") as f:
        f.write("\n".join(report_lines))
    with open(key_path, "w", encoding="utf-8") as f:
        f.write("\n".join(key_lines))

    print(f"wrote {report_path}")
    print(f"wrote {key_path}")


if __name__ == "__main__":
    main()

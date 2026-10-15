#!/usr/bin/env python3
"""Blind AI grading of a run-skill-batch.sh pair's report.md, replacing the
old manual "human opens report.md and fills in a score table" step.

For each Run label in report.md (already shuffled + condition-stripped by
generate_report.py), loads that task's checklist.md, issues THREE independent
`claude -p` grading calls (pass 1-3 — no pass sees another pass's answers, no
--add-dir/--permission-mode acceptEdits since the grader only reads text, no
session capture/reuse since each call is single-turn and disposable), takes
the majority vote (2-of-3) per checklist item, rolls up to a run verdict at
the >=80% threshold, and writes report-scored.md next to report.md.

Three passes (not two) per the literature-backed minimum viable reliability
protocol — see RUBRIC-กลาง.md "กติกาการตรวจ (blind + ตรวจซ้ำ 3 รอบ)" for the
citations (Rating Roulette, arXiv:2510.27106; Reliability without Validity,
arXiv:2606.19544) and rationale (temperature left at CLI default, not forced
to 0 — Rating Roulette found forcing determinism *hurts* human alignment).

Usage: grade_runs.py <report_md_path> <task_id> <out_dir>
"""
import json, os, re, subprocess, sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PASS_THRESHOLD = 0.80
NUM_PASSES = 3

RUN_HEADER_RE = re.compile(r"^## Run ([A-Z])\s*$", re.MULTILINE)
DIFF_BLOCK_RE = re.compile(r"```diff\n(.*?)\n```", re.DOTALL)
RESPONSE_RE = re.compile(r"\*\*Response text:\*\*\n\n(.*?)(?:\n---\n|\Z)", re.DOTALL)
CHECKLIST_ITEM_RE = re.compile(r"^\s*(\d+)\.\s+(.+)$", re.MULTILINE)
ANSWER_LINE_RE = re.compile(r"item[_\s]*(\d+)\s*[:\-]\s*(pass|fail)", re.IGNORECASE)


def load_checklist(task_id):
    path = os.path.join(SCRIPT_DIR, task_id, "checklist.md")
    if not os.path.isfile(path):
        print(f"ERROR: no checklist.md for task '{task_id}' at {path}", file=sys.stderr)
        sys.exit(1)
    with open(path, encoding="utf-8") as f:
        text = f.read()
    items = {}
    for m in CHECKLIST_ITEM_RE.finditer(text):
        items[int(m.group(1))] = m.group(2).strip()
    if not items:
        print(f"ERROR: checklist.md for '{task_id}' has no numbered items", file=sys.stderr)
        sys.exit(1)
    return items


def parse_report(report_path):
    with open(report_path, encoding="utf-8") as f:
        text = f.read()
    headers = list(RUN_HEADER_RE.finditer(text))
    runs = {}
    for i, h in enumerate(headers):
        label = h.group(1)
        start = h.end()
        end = headers[i + 1].start() if i + 1 < len(headers) else len(text)
        block = text[start:end]
        # stop at the score-sheet section if generate_report.py hasn't been
        # updated yet to drop it (task 4.1) — keep this parser tolerant either way
        block = block.split("## Score sheet")[0]
        diff_m = DIFF_BLOCK_RE.search(block)
        resp_m = RESPONSE_RE.search(block)
        runs[label] = {
            "diff": diff_m.group(1) if diff_m else None,
            "response": resp_m.group(1).strip() if resp_m else None,
        }
    return runs


def build_prompt(checklist, content_diff, content_response):
    lines = []
    lines.append(
        "คุณเป็นผู้ตรวจงาน (grader) กำลังตรวจผลงานหนึ่ง run จากการทดลองเปรียบเทียบ "
        "เครื่องมือเสริมของ Claude Code ห้ามใช้เครื่องมือใด ๆ (ไม่มีให้ใช้อยู่แล้ว) "
        "ตอบจากเนื้อหาที่ให้มาด้านล่างเท่านั้น ห้ามอนุมานว่าใครทำหรือเครื่องมือไหนทำ "
        "ไม่มี test suite ให้รัน ห้ามตัดสินว่าไม่ผ่านเพียงเพราะไม่มีผลรัน test"
    )
    lines.append("")
    lines.append("## เนื้อหาที่ต้องตรวจ")
    lines.append("")
    if content_diff:
        lines.append("```diff")
        lines.append(content_diff)
        lines.append("```")
    if content_response:
        lines.append("**คำอธิบายที่ส่งมา:**")
        lines.append(content_response)
    if not content_diff and not content_response:
        lines.append("(ไม่มี diff และไม่มีคำอธิบาย — ตอบ fail ทุกข้อ)")
    lines.append("")
    lines.append("## Checklist — ตอบ pass หรือ fail ทีละข้อ")
    lines.append("")
    for item_id in sorted(checklist):
        lines.append(f"{item_id}. {checklist[item_id]}")
    lines.append("")
    lines.append(
        "ตอบเป็นบรรทัด รูปแบบ `item_<เลขข้อ>: pass` หรือ `item_<เลขข้อ>: fail` "
        "ให้ครบทุกข้อ บรรทัดละ 1 ข้อ ไม่ต้องอธิบายเพิ่ม ไม่ต้องมีข้อความอื่นนอกจากบรรทัดคำตอบ"
    )
    return "\n".join(lines)


GRADER_MODEL = os.environ.get("GRADER_MODEL", "claude-sonnet-5-5")


def call_grader(prompt):
    proc = subprocess.run(
        ["claude", "-p", prompt, "--model", GRADER_MODEL, "--effort", "medium", "--output-format", "json"],
        capture_output=True, text=True, encoding="utf-8",
    )
    if proc.returncode != 0:
        print(f"WARNING: grading call failed (exit {proc.returncode}): {proc.stderr[:500]}", file=sys.stderr)
        return {}
    try:
        result_text = json.loads(proc.stdout)["result"]
    except Exception as e:
        print(f"WARNING: could not parse grader output: {e}", file=sys.stderr)
        return {}
    answers = {}
    for m in ANSWER_LINE_RE.finditer(result_text):
        answers[int(m.group(1))] = m.group(2).lower()
    return answers


def grade_run(checklist, content_diff, content_response):
    prompt = build_prompt(checklist, content_diff, content_response)
    passes = [call_grader(prompt) for _ in range(NUM_PASSES)]

    final = {}
    votes = {}
    for item_id in sorted(checklist):
        answers = [p.get(item_id, "fail") for p in passes]  # missing answer -> fail, conservative
        pass_votes = answers.count("pass")
        final[item_id] = "pass" if pass_votes >= 2 else "fail"
        votes[item_id] = answers

    pass_count = sum(1 for v in final.values() if v == "pass")
    total = len(final)
    pct = pass_count / total if total else 0.0
    verdict = "pass" if pct >= PASS_THRESHOLD else "fail"
    return final, votes, pct, verdict


def write_report(out_path, task_id, checklist, results):
    lines = [f"# Scored report — {task_id}\n"]
    lines.append(
        f"AI-graded, blind to condition, {NUM_PASSES} independent passes per run, "
        f"majority vote per item, run verdict = pass if >= {PASS_THRESHOLD*100:.0f}% items pass.\n"
    )
    for label, (final, votes, pct, verdict) in results.items():
        lines.append(f"## Run {label} — {verdict.upper()} ({pct*100:.1f}% passed)\n")
        lines.append("| item | text | pass1 | pass2 | pass3 | final | split |")
        lines.append("|---|---|---|---|---|---|---|")
        for item_id in sorted(checklist):
            v = votes[item_id]
            split = "" if len(set(v)) == 1 else "⚠️ non-unanimous"
            lines.append(
                f"| {item_id} | {checklist[item_id]} | {v[0]} | {v[1]} | {v[2]} | "
                f"{final[item_id]} | {split} |"
            )
        lines.append("")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"wrote {out_path}")


def main():
    report_path, task_id, out_dir = sys.argv[1:4]
    checklist = load_checklist(task_id)
    runs = parse_report(report_path)

    results = {}
    for label, content in runs.items():
        if not content["diff"] and not content["response"]:
            print(f"WARNING: Run {label} has no diff/response — grading as all-fail", file=sys.stderr)
        results[label] = grade_run(checklist, content["diff"], content["response"])

    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "report-scored.md")
    write_report(out_path, task_id, checklist, results)


if __name__ == "__main__":
    main()

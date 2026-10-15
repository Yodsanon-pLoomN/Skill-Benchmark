#!/usr/bin/env python3
"""Reads a run-skill-batch.sh output CSV (run_code,task_id,skill_name,condition,
order,session_id), pulls token usage from each session's JSONL log (deduped by
message.id — the same message can appear more than once in a log), and writes
a new CSV with per-run token counts + cost (Claude Sonnet 5.5 rates: 2/10 USD per 1M in/out,
cache_read at 0.1x, cache_write_1h at 2.0x — see
03_Proposal/วิธีการวัด-Token-และต้นทุน.md ข้อ 3).

Usage: extract_tokens.py <in_csv> <out_csv>
"""
import json, sys, csv, glob, os

HOME = os.path.expanduser("~")


def find_jsonl(sid):
    matches = glob.glob(os.path.join(HOME, ".claude", "projects", "*", f"{sid}.jsonl"))
    return matches[0] if matches else None


def sum_usage(jsonl_path):
    seen = set()
    totals = dict(input_tokens=0, output_tokens=0, cache_read=0, cache_w5=0, cache_w1h=0)
    with open(jsonl_path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                o = json.loads(line)
            except Exception:
                continue
            if o.get("type") != "assistant":
                continue
            msg = o.get("message", {})
            mid = msg.get("id")
            if mid is None or mid in seen:
                continue
            seen.add(mid)
            usage = msg.get("usage", {})
            totals["input_tokens"] += usage.get("input_tokens", 0)
            totals["output_tokens"] += usage.get("output_tokens", 0)
            totals["cache_read"] += usage.get("cache_read_input_tokens", 0)
            cc = usage.get("cache_creation", {}) or {}
            totals["cache_w5"] += cc.get("ephemeral_5m_input_tokens", 0)
            totals["cache_w1h"] += cc.get("ephemeral_1h_input_tokens", 0)
    return totals


# Claude Sonnet 5.5 list prices, USD per 1M tokens (checked 2026-10-10).
# Update together with the model pinned in run-skill-batch.sh.
PRICE_IN = 2.00
PRICE_OUT = 10.00


def cost(t):
    input_c = t["input_tokens"] * PRICE_IN
    read_c = t["cache_read"] * PRICE_IN * 0.10
    w5_c = t["cache_w5"] * PRICE_IN * 1.25
    w1h_c = t["cache_w1h"] * PRICE_IN * 2.00
    out_c = t["output_tokens"] * PRICE_OUT
    cost_usd = (input_c + read_c + w5_c + w1h_c + out_c) / 1_000_000
    cold = ((t["input_tokens"] + t["cache_read"] + t["cache_w5"] + t["cache_w1h"]) * PRICE_IN
            + t["output_tokens"] * PRICE_OUT) / 1_000_000
    denom = t["input_tokens"] + t["cache_read"] + t["cache_w5"] + t["cache_w1h"]
    hit = t["cache_read"] / denom if denom else 0.0
    return cost_usd, cold, hit


def main():
    in_csv, out_csv = sys.argv[1], sys.argv[2]
    rows = []
    with open(in_csv, encoding="utf-8") as f:
        for row in csv.DictReader(f):
            sid = row["session_id"]
            jsonl = find_jsonl(sid)
            if not jsonl:
                row.update(input=0, output=0, cache_read=0, cache_w5=0, cache_w1h=0,
                           cost_usd=0, cost_cold_usd=0, cache_hit=0, note="session log not found")
                rows.append(row)
                continue
            t = sum_usage(jsonl)
            cost_usd, cold, hit = cost(t)
            row.update(
                input=t["input_tokens"], output=t["output_tokens"],
                cache_read=t["cache_read"], cache_w5=t["cache_w5"], cache_w1h=t["cache_w1h"],
                cost_usd=f"{cost_usd:.6f}", cost_cold_usd=f"{cold:.6f}",
                cache_hit=f"{hit:.4f}", note="",
            )
            rows.append(row)

    fieldnames = ["run_code", "task_id", "skill_name", "condition", "order", "session_id",
                  "input", "output", "cache_read", "cache_w5", "cache_w1h",
                  "cost_usd", "cost_cold_usd", "cache_hit", "note"]
    with open(out_csv, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for row in rows:
            w.writerow({k: row.get(k, "") for k in fieldnames})
    print(f"wrote {out_csv}")


if __name__ == "__main__":
    main()

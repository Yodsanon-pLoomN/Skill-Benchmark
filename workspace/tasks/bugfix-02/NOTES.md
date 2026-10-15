# bugfix-02 — internal notes (do NOT ship to graders)

Domain: meeting room booking, Node API (`sample-project`). Fabricated; unrelated to any production system.
Repo: `sample-project` · base tag: `bugfix-02-base` (branched from `base-clean`,
independent of `bugfix-01-base`/`bugfix-03-base` — different rules, different files).

## Planted defects

| # | File | Defect | Detectable by |
|---|---|---|---|
| A | `src/domain/booking.ts` `assertValidRange()` | `durationMs >= MAX` instead of `>` — rejects a legal exactly-8-hour booking | reading `docs/DOMAIN.md` rule 4 ("may not exceed 8 hours" — 8h itself is fine) |
| B | `src/domain/booking.ts` `assertNotInPast()` | compares `range.endsAt < now` instead of `range.startsAt < now` — a booking whose start is already in the past but whose end is still in the future is wrongly accepted | reading `docs/DOMAIN.md` rule 5 ("must not start in the past") and noticing the function checks the wrong field of `range` |

## Why this design

- **Same "two defects, different rules" shape as bugfix-01**, but exercises
  rules 4 and 5 instead of rules 1 and 2, so this task and bugfix-01 don't
  reward the same single insight twice.
- **Both defects are boundary/off-by-one slips**, same family of mistake as
  bugfix-01's `<=`/`>=` bug, but on different boundaries (a duration cap and
  a "which field do I compare" mixup) — keeps the task set's recurring
  half-open/boundary theme (see explain-01, explain-02) without literally
  repeating bugfix-01's defect.
- **Report 2 is worded around a realistic race (slow form submission)**
  rather than "I typed the wrong year", specifically so a fix that only
  rejects when *both* `startsAt` and `endsAt` are in the past (the naive
  read of "should reject a booking in the past") still fails to reproduce
  the report — the report only makes sense if `endsAt` is in the future,
  which is exactly what triggers defect B.

## ด้านที่ 1-2 (ความถูกต้อง/ความครบถ้วน) worked examples

ใช้เกณฑ์ "Planted defects" ด้านบนตรงๆ: แก้ครบ 2 defect = เต็มด้าน 1-2, แก้ได้ 1 ใน 2 = กลาง, ไม่แก้เลย/แก้ผิดจุด = ต่ำ

## ด้านที่ 3 — คุณภาพของโค้ด: worked examples

- **4** — แก้แค่ 2 บรรทัดตรงจุด (`>=`→`>` ใน `assertValidRange`, `range.endsAt`→`range.startsAt` ใน `assertNotInPast`) ไม่แตะไฟล์อื่น สไตล์เข้ากับโค้ดเดิม
- **3** — แก้ถูกจุดเดียวกัน แต่มีจุดติเล็กน้อย (เช่น เปลี่ยนชื่อ parameter, comment เกินจำเป็น)
- **2** — ใช้งานได้แต่แก้เกินจำเป็น เช่น เขียนฟังก์ชันใหม่ทั้งอันแทนการแก้ comparison เดิม
- **1** — ต้องรื้อแก้เยอะก่อน merge ได้
- **0** — ไม่ควร merge (เช่น diff ทำให้ compile/lint พัง)

## Trap that distinguishes 4 from 3

Over-fixing report 2 by requiring `startsAt < now && endsAt < now` (i.e. rejecting
only bookings entirely in the past) resolves the report symptom too
narrowly and leaves a booking that starts one second ago and ends far in
the future still accepted — that still violates rule 5's plain reading
("must not start in the past") and should not score full marks on ด้านที่ 1.

## Known limitation (same as bugfix-01)

`tests/booking.test.ts` already has tests named "accepts an 8 hour booking"
and "rejects a start time in the past" that fail against this base tag
(confirmed: 2/13 tests fail, `npm test` run against `bugfix-02-base`) — if
`npm test` is runnable in the sandbox, both defects are locatable without
reading `docs/DOMAIN.md` at all. Same mitigation as bugfix-01 §"Known
limitation": treat a same-run 4/4 on ด้านที่ 1-2 for both conditions as the
"task too easy" ceiling-effect scenario if it happens during pilot.

## Expected size

Minimal correct diff: two one-character-ish changes (`>=`→`>`, `endsAt`→`startsAt`)
in the same file, no new imports.

# bugfix-01 — internal notes (do NOT ship to graders)

Domain: meeting room booking, Node API (`sample-project`). Fabricated; unrelated to any production system.
Repo: `sample-project` · base tag: `bugfix-01-base`.

## Planted defects

| # | File | Defect | Detectable by |
|---|---|---|---|
| A | `src/domain/booking.ts` `overlaps()` | `<=` / `>=` instead of `<` / `>` — rejects back-to-back bookings | reading `docs/DOMAIN.md` overlap table |
| B | `src/repositories/bookingRepository.ts` `findBookingsForDay()` | no `status` filter — `CANCELLED` bookings block the slot | reading `docs/DOMAIN.md` rule 2 |

## Why this design

- **Two defects, not one.** A single-line fix would be found by every
  configuration and produce no differentiation. Two defects in different layers
  reward thoroughness, which is what the tools under test claim to improve.
- **Defect B needs the schema.** Finding it requires noticing `status` exists
  and that the query ignores it — i.e. reading beyond the file the first
  report points at. This is where context-management tooling should show up.
- **The spec is a file in the repo.** `docs/DOMAIN.md` makes both defects
  objectively wrong rather than a matter of taste, so the rubric can be scored
  consistently by different people.
- **Report 2 is worded so it cannot be dismissed as a data problem.** The
  admin explicitly says the booking shows as cancelled.

## ⚠️ Known limitation vs. the original bugfix-01 design (added when sample-project was rebuilt)

Task 1.6 of the rebuild (see `openspec/changes/rebuild-sample-project-tasks/tasks.md`)
required a smoke test suite that verifies all 6 `docs/DOMAIN.md` rules on the
golden state. That suite (`tests/booking.test.ts`, `tests/bookingService.integration.test.ts`)
now exists and its test names directly name the back-to-back and
cancelled-booking behaviours — i.e. if an agent can run `npm test` inside the
sandbox, the failing test names point almost directly at both defects. The
original design assumed no test coverage reached the bugs ("the bugs live
exactly where tests/ does not reach").

This does **not** bias the off/on comparison (both conditions have equal
access to the same test suite), but it does raise the floor score for both
conditions and may reduce the task's ability to show a difference (ceiling
effect). Mitigation: check for this specifically during the group-7 pilot —
if both skill-off and skill-on pilot runs score 4/4 immediately by running
`npm test`, treat this as the "task too easy" scenario the methodology doc
already anticipates (§6.5) and either (a) confirm the experimental sandbox
for this task genuinely has no pre-installed `node_modules`/npm cache (forces
static reading only, restoring original difficulty), or (b) accept the
result and note the limitation in the report.

## ด้านที่ 1-2 (ความถูกต้อง/ความครบถ้วน) worked examples

ใช้เกณฑ์ "Planted defects" ด้านบนตรงๆ: แก้ครบ 2 defect = เต็มด้าน 1-2, แก้ได้ 1 ใน 2 = กลาง, ไม่แก้เลย/แก้ผิดจุด = ต่ำ (ดู "Trap that distinguishes 4 from 3" ด้านล่างประกอบ)

## ด้านที่ 3 — คุณภาพของโค้ด: worked examples

- **4** — แก้แค่ 2 บรรทัดตรงจุด (`overlaps()` เปลี่ยน `<=`/`>=`→`<`/`>`, เพิ่ม `status: BookingStatus.CONFIRMED` ใน where clause ที่มีอยู่แล้ว) สไตล์เข้ากับโค้ดเดิมเป๊ะ ไม่แตะไฟล์อื่น
- **3** — แก้ถูกจุดเดียวกัน แต่มีจุดติเล็กน้อย เช่น ใส่คอมเมนต์อธิบายสิ่งที่ชัดอยู่แล้วในโค้ด, สไตล์ quote/format ไม่ตรงกับไฟล์เดิม
- **2** — ใช้งานได้แต่แตะโค้ดเกินจำเป็น (เช่น rename ตัวแปรในไฟล์เดียวกันระหว่างแก้ไปด้วย) หรือเพิ่มความซับซ้อนที่ไม่จำเป็น (เช่น เขียน helper function ใหม่สำหรับ comparison ง่ายๆ แค่จุดเดียว)
- **1** — ต้องรื้อแก้เยอะก่อน merge ได้ (เช่น logic ถูกแต่เขียนซ้ำซ้อน/อ่านยากผิดปกติ)
- **0** — ไม่ควร merge (เช่น diff ทำให้ lint/compile error, โค้ดยุ่งเหยิงเกินไป)

## Trap that distinguishes 4 from 3

Filtering `status` in every repository query also hides cancelled bookings from
`GET /bookings?userId=...`. Rules 2 and 6 in `docs/DOMAIN.md` require cancelled
bookings to remain visible and cancellable. A submission that over-applies the
filter resolves both reports but regresses something else.

## Expected size

Minimal correct diff: two lines in two files (no import needed — both
functions already live in files that already exist).

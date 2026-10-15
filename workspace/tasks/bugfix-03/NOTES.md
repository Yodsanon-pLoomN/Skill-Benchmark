# bugfix-03 — internal notes (do NOT ship to graders)

Domain: meeting room booking, Node API (`sample-project`). Fabricated; unrelated to any production system.
Repo: `sample-project` · base tag: `bugfix-03-base` (branched from `base-clean`,
independent of `bugfix-01-base`/`bugfix-02-base` — different rules, different function).

## Planted defects

| # | File | Defect | Detectable by |
|---|---|---|---|
| A | `src/services/bookingService.ts` `createBooking()` | the `if (!room.isActive) throw new RoomInactiveError(...)` guard has been removed entirely — inactive rooms silently accept new bookings | reading `docs/DOMAIN.md` rule 3 and noticing `createBooking` fetches `room.isActive` (via `findRoomById`) but never checks it |
| B | `src/services/bookingService.ts` `cancelBooking()` | the rule-6 no-op guard now `throw`s `BookingNotFoundError` instead of returning the existing (already-cancelled) booking | reading `docs/DOMAIN.md` rule 6 ("Cancelling an already-cancelled booking is a no-op, not an error") |

## Why this design

- **Two defects in the same file, different functions** — a different shape
  from bugfix-01 (different files) and bugfix-02 (same function pair, same
  file) — on purpose, so the task set isn't teaching agents to always look
  in exactly two specific files.
- **Defect A is an omission, not a wrong operator** — closer to bugfix-01's
  defect B (missing filter) than defect A (wrong operator), rewarding
  "is every branch of the domain doc actually enforced" rather than
  "is every comparison operator correct."
- **Defect B inverts the domain's own explicit exception.** `docs/DOMAIN.md`
  rule 6 is unusual among the six rules in that it explicitly names the
  *wrong* behaviour ("not an error") — this defect is the wrong behaviour
  verbatim, testing whether the rule was actually read rather than
  pattern-matched against "cancelling should probably work."

## ด้านที่ 1-2 (ความถูกต้อง/ความครบถ้วน) worked examples

ใช้เกณฑ์ "Planted defects" ด้านบนตรงๆ: แก้ครบ 2 defect = เต็มด้าน 1-2, แก้ได้ 1 ใน 2 = กลาง, ไม่แก้เลย/แก้ผิดจุด = ต่ำ

## ด้านที่ 3 — คุณภาพของโค้ด: worked examples

- **4** — Defect A: เพิ่มกลับ `if (!room.isActive) throw new RoomInactiveError(input.roomId);` (import `RoomInactiveError` กลับเข้า `domain/errors.js` ด้วยถ้าถูกลบไปตอนนี้) ตำแหน่งเดียวกับที่เคยอยู่ก่อนบั๊ก. Defect B: เปลี่ยน `throw` กลับเป็น `return existing;` — ไม่แตะไฟล์อื่น
- **3** — แก้ถูกจุดเดียวกัน แต่มีจุดติเล็กน้อย (เช่น ลืม import `RoomInactiveError` ทำให้ compile error ก็จะร่วงไปด้าน 0 แทน — ถ้า import ครบแต่สไตล์ผิดเล็กน้อยเช่น error message เปลี่ยนไปจากเดิม ให้ 3)
- **2** — ใช้งานได้แต่แก้เกินจำเป็น เช่น ย้าย isActive check ไปไว้ที่ repository layer แทนที่จะคืนกลับที่เดิมใน service
- **1** — ต้องรื้อแก้เยอะก่อน merge ได้
- **0** — ไม่ควร merge (เช่น diff ทำให้ compile พัง เพราะลืม import ที่ต้องใช้)

## Trap that distinguishes 4 from 3

Fixing defect A by adding the `isActive` check in a *new* place (e.g. a
fresh guard clause in the API handler, `src/api/handlers/bookings.ts`,
instead of restoring it inside `bookingService.createBooking`) works
behaviourally for `POST /bookings` but leaves the service function itself
still willing to accept bookings against inactive rooms if called from
anywhere else (there's no other caller today, but the rule belongs to the
domain layer, not the transport layer, per how every other rule in this
file is enforced) — a plausible ด้านที่ 3 deduction, not a ด้านที่ 1 failure.

## Known limitation (same as bugfix-01/bugfix-02)

`tests/bookingService.integration.test.ts` already has tests named "rule 3:
rejects a booking in a room where isActive is false" and "rule 6: cancelling
an already-cancelled booking is a no-op, not an error" that fail against
this base tag (confirmed: 2/13 tests fail, `npm test` run against
`bugfix-03-base`). Same mitigation as bugfix-01's note applies if `npm test`
is runnable in the sandbox.

## Expected size

Minimal correct diff: one added line (`createBooking`) + one changed line
(`cancelBooking`, `throw` → `return existing`), no new imports beyond
restoring `RoomInactiveError` to the existing import block from
`../domain/errors.js` if it was removed along with the check.

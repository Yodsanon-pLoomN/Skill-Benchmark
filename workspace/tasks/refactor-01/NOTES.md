# refactor-01 — internal notes (do NOT ship to graders)

Domain: meeting room booking, Node API (`sample-project`). Fabricated.
Repo: `sample-project` · base tag: `refactor-01-base` (branched from `base-clean`,
diverges from `bugfix-01-base` — no bugs here, only duplication).

## What was actually duplicated

`src/services/bookingService.ts`:

- `createBooking` scans `findBookingsForDay(...)` and calls `overlaps(existing, range)`
  in a `.some(...)` to decide whether to throw `SlotUnavailableError`.
- `checkAvailability` independently scans the same `findBookingsForDay(...)` result
  with the same `.some(existing => overlaps(existing, dayWindow))` shape, as a
  "fast path" short-circuit before the interval-sweep algorithm that computes
  free slots.

Both are the *same* overlap-scan idea (all bookings that day, check `overlaps`
against a target range) applied to two different target ranges (`range` vs.
`dayWindow`), written independently instead of sharing one helper.

## What "correct" looks like

A minimal correct refactor extracts something like:

```ts
async function anyOverlap(roomId: string, dateStr: string, target: TimeRange): Promise<boolean> {
  const sameDay = await findBookingsForDay(roomId, dateStr);
  return sameDay.some((existing) => overlaps(existing, target));
}
```

...and has both `createBooking` and `checkAvailability` call it instead of
each writing their own `.some(...)` scan. The exact function name/signature
is not prescribed — judge on outcome, not naming.

## Two independent judgment points (per benchmark-tasks spec)

1. **Was the duplication actually removed?** Two independent copies of the
   scan logic → one. Renaming variables without removing the second copy
   does not count.
2. **Is behaviour still correct on both call sites?** Run through
   `docs/DOMAIN.md`'s overlap consequences table and rules 1–2 mentally (or
   via `tests/`) for both `createBooking` and `checkAvailability` — a
   refactor that accidentally changes `checkAvailability`'s fast-path
   condition (e.g. flips a boolean, or applies the new shared function to
   the wrong range) breaks (2) while still "succeeding" at (1).

## ด้านที่ 1-2 (ความถูกต้อง/ความครบถ้วน) worked examples

- **4** — Single shared function/helper used by both `createBooking` and
  `checkAvailability`; both endpoints still behave exactly per
  `docs/DOMAIN.md` (verified by running the existing test suite or by
  tracing the logic).
- **3** — Duplication genuinely removed and behaviour correct — this task's
  ceiling is usually a ด้าน 3 (quality) blemish rather than a 1-2 issue, see below.
- **2** — Removed the duplication in one of the two places but not the
  other (e.g. refactored `createBooking` to use a shared helper but left
  `checkAvailability`'s inline copy untouched, or vice versa).
- **1** — Attempted an extraction but broke behaviour in at least one call
  site (e.g. `checkAvailability`'s fast path now returns the wrong thing
  for an empty day, or `createBooking` stops rejecting genuine overlaps).
- **0** — No meaningful change, or the diff doesn't compile, or duplication
  is still present in both places unchanged.

## ด้านที่ 3 — คุณภาพของโค้ด: worked examples

- **4** — helper วางในตำแหน่งที่สมเหตุผล (เช่นอยู่ใกล้ `domain/booking.ts` หรือใน `bookingService.ts` เอง) ตั้งชื่อสื่อความหมาย ตรงสไตล์ naming ที่ใช้อยู่แล้วในไฟล์ (`camelCase`, async/await) ไม่แตะไฟล์อื่นที่ไม่เกี่ยว
- **3** — extraction ถูกต้อง แต่วางตำแหน่งแปลก (เช่น สร้างไฟล์ util ใหม่แยกต่างหากทั้งที่โปรเจกต์ไม่มี pattern แบบนั้น) หรือตั้งชื่อไม่ตรงธรรมเนียมโค้ดเดิม
- **2** — extraction ทำงานได้แต่ยุ่งยากเกินจำเป็น (เช่น เพิ่ม parameter ที่ไม่ต้องใช้, สร้าง abstraction ซ้อน abstraction)
- **1** — ต้องรื้อแก้เยอะก่อน merge ได้ แม้ behavior จะถูก (โครงสร้างสับสน อ่านยากผิดปกติ)
- **0** — ไม่ควร merge

## Why this design

- **Two call sites, not one.** A single call site would make "extract a
  function" trivial and undiscriminating. Two independent copies force a
  real judgment call about what the shared abstraction should look like.
- **No behavioural bug to find** — this isolates "safe restructuring"
  as a skill, distinct from bugfix-01 (finding wrong logic) and explain-01
  (reading comprehension). Together the four tasks cover: find-and-fix,
  read-and-explain, add-new-behaviour (feature-01), and restructure-without-
  breaking (this task).
- **The duplication is plausible, not contrived.** Framed in the prompt as
  organic drift ("written separately... drifted into two independent
  copies"), matching how this kind of duplication actually appears in real
  codebases (copy-paste under time pressure), per design.md's risk
  mitigation for this task.

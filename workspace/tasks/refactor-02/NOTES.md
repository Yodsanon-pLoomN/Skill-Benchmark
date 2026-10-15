# refactor-02 — internal notes (do NOT ship to graders)

Domain: meeting room booking, Node API (`sample-project`). Fabricated.
Repo: `sample-project` · base tag: `refactor-02-base` = an alias for
`base-clean` (no separate commit needed — this duplication already exists
organically in the clean base state, unlike refactor-01's which was
deliberately constructed).

## What is actually duplicated

`src/lib/time.ts`:
```ts
export function startOfUtcDay(dateStr: string): Date {
  return new Date(`${dateStr}T00:00:00.000Z`);
}
export function endOfUtcDay(dateStr: string): Date {
  return new Date(`${dateStr}T23:59:59.999Z`);
}
```

`src/repositories/bookingRepository.ts` imports and uses both. But
`src/services/bookingService.ts`'s `checkAvailability` independently writes:
```ts
const dayStart = new Date(`${dateStr}T00:00:00.000Z`);
const dayEnd = new Date(`${dateStr}T23:59:59.999Z`);
```
— the exact same two instants, computed with the exact same string
templates, without importing or calling `startOfUtcDay`/`endOfUtcDay`.

## What "correct" looks like

```ts
import { startOfUtcDay, endOfUtcDay } from "../lib/time.js";
// ...
const dayStart = startOfUtcDay(dateStr);
const dayEnd = endOfUtcDay(dateStr);
```

Exact variable names are not prescribed — judge on outcome (helper reused,
inline duplicate gone), not naming.

## Two independent judgment points (per benchmark-tasks spec)

1. **Was the duplication actually removed?** The inline `new Date(...)`
   template in `checkAvailability` must be replaced by calls to the
   existing helpers, not merely left alongside them.
2. **Is behaviour still correct?** `startOfUtcDay`/`endOfUtcDay` produce
   *exactly* the same instants as the inline code (`T00:00:00.000Z` /
   `T23:59:59.999Z`) — a correct refactor changes nothing observable. A
   subtle way to get this wrong: importing `endOfUtcDay` but computing "end
   of day" as "start of *next* day" instead (a common alternate definition)
   would shift `dayEnd` by 1ms and change the free-interval sweep's final
   pushed interval at the day boundary.

## ด้านที่ 1-2 (ความถูกต้อง/ความครบถ้วน) worked examples

- **4** — `checkAvailability` calls `startOfUtcDay(dateStr)` /
  `endOfUtcDay(dateStr)` instead of inlining; `GET /rooms/:id/availability`
  behaves identically for every case in `docs/DOMAIN.md`.
- **3** — Duplication removed and behaviour correct — this task's ceiling is
  usually a ด้าน 3 blemish (see below), not a 1-2 issue.
- **2** — Imports the helpers but only replaces one of the two lines (e.g.
  uses `startOfUtcDay` but still inlines `dayEnd`).
- **1** — Attempted the change but broke behaviour (e.g. off-by-one from
  swapping to a "start of next day" definition of `endOfUtcDay`, see above).
- **0** — No meaningful change, diff doesn't compile, or the inline
  duplicate is still present unchanged.

## ด้านที่ 3 — คุณภาพของโค้ด: worked examples

- **4** — import เพิ่มบรรทัดเดียวจาก `../lib/time.js` ตรงกับ import style ที่ `bookingRepository.ts` ใช้อยู่แล้ว ไม่แตะไฟล์อื่น
- **3** — ถูกต้อง แต่มีจุดติเล็กน้อย เช่น import แบบ `import * as time from "../lib/time.js"` ทั้งที่ไฟล์อื่นในโปรเจกต์ import แบบ named เสมอ
- **2** — ทำงานได้แต่ซับซ้อนเกินจำเป็น เช่น สร้าง wrapper function ใหม่ห่อ `startOfUtcDay`/`endOfUtcDay` อีกชั้นโดยไม่จำเป็น
- **1** — ต้องรื้อแก้เยอะก่อน merge ได้
- **0** — ไม่ควร merge

## Why this design

- **Organic duplication, not constructed.** Unlike refactor-01 (duplication
  deliberately added on top of `base-clean` for that task), this
  duplication is already present in the repo's clean state — a more
  realistic "small drift nobody noticed" scenario, and it means this task's
  base tag needed no new commit.
- **Deliberately smaller in scope than refactor-01.** Two lines, one helper
  module, one call site to fix — this is the "spot the small missed reuse"
  end of the refactor-task difficulty range, complementing refactor-01's
  larger two-endpoint duplication and refactor-03's UI-layer duplication.
- **Same rule-1/2 domain, no planted bug** — like refactor-01, this isolates
  "safe restructuring" as a skill distinct from bugfix-0x (finding wrong
  logic).

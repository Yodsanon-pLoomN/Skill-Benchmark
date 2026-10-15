# refactor-03 — internal notes (do NOT ship to graders)

Domain: meeting room booking frontend, Angular app (`sample-project-webapp`). Fabricated.
Repo: `sample-project-webapp` · base tag: `refactor-03-base` (branched from
`explain-01-base`'s underlying commit, diverges from `explain-01-base` by
adding a `lastUpdatedAt` field + a duplicated formatter — explain-01 itself
is untouched, still points at the original commit with no duplication).

## What was actually duplicated

`room-availability.component.ts`:
```ts
formatSlot(interval: FreeInterval): string {
  const start = new Date(interval.startsAt);
  const end = new Date(interval.endsAt);
  const fmt = (d: Date) => d.toISOString().slice(11, 16);
  return `${fmt(start)}–${fmt(end)} UTC`;
}

formatTimestamp(d: Date): string {
  return d.toISOString().slice(11, 16) + ' UTC';
}
```
Both independently do `d.toISOString().slice(11, 16)` to turn a `Date` into
an "HH:mm" string, then both append `" UTC"`. `formatSlot` uses it twice (via
its local `fmt` closure) to build a range; `formatTimestamp` uses the
equivalent logic once, standalone, for the "Last updated at HH:mm UTC" line
under the slot list (wired up in the template via
`*ngIf="lastUpdatedAt"` → `{{ formatTimestamp(lastUpdatedAt) }}`, set in
`loadAvailability()`'s success callback as `this.lastUpdatedAt = new Date()`).

## What "correct" looks like

Extract the core `(d: Date) => string` HH:mm-in-UTC formatter once — e.g.:
```ts
private static hhmmUtc(d: Date): string {
  return d.toISOString().slice(11, 16);
}
```
...and have both `formatSlot` (for its two endpoints) and `formatTimestamp`
call it, rather than each computing `.toISOString().slice(11, 16)`
independently. `formatSlot` still assembles its own `"HH:mm–HH:mm UTC"`
range string around two calls; `formatTimestamp` still appends its own
`" UTC"` suffix around one call — only the HH:mm-slicing core is shared, not
the surrounding string shape (the two callers legitimately format
differently: a range vs. a single instant). Exact name/placement (private
method, standalone function, class field) is not prescribed.

## Two independent judgment points (per benchmark-tasks spec)

1. **Was the duplication actually removed?** Two independent
   `.toISOString().slice(11, 16)` occurrences → one shared implementation
   called from both `formatSlot` and `formatTimestamp`.
2. **Does the displayed output stay byte-identical?** Both the free-slots
   list text and the "Last updated at HH:mm UTC" line must render exactly
   as before — a refactor that, say, unifies the two into one function that
   always appends `"–"` (assuming a range) would break `formatTimestamp`'s
   single-instant call site.

## ด้านที่ 1-2 (ความถูกต้อง/ความครบถ้วน) worked examples

- **4** — Single shared HH:mm-in-UTC formatter used by both `formatSlot` and
  `formatTimestamp`; both the slot list and the "Last updated at ..." line
  render identically to before.
- **3** — Duplication genuinely removed and output unchanged — ceiling here
  is usually a ด้าน 3 blemish, not a 1-2 issue.
- **2** — Shared the formatter for one call site but not the other (e.g.
  `formatSlot` refactored to use a shared helper, `formatTimestamp` left
  with its own independent `.slice(11, 16)`, or vice versa).
- **1** — Attempted an extraction but changed on-screen output (e.g. the
  slot list now shows a stray extra `" UTC"`, or the last-updated line loses
  its `" UTC"` suffix).
- **0** — No meaningful change, diff doesn't compile / `ng build` fails, or
  duplication is still present in both places unchanged.

## ด้านที่ 3 — คุณภาพของโค้ด: worked examples

- **4** — helper วางในตำแหน่งที่สมเหตุผล (เช่น private method ในคลาสเดียวกัน หรือฟังก์ชันแยกในไฟล์เดียวกัน) ตั้งชื่อสื่อความหมาย ตรงสไตล์ TypeScript/Angular ที่ไฟล์ใช้อยู่แล้ว ไม่แตะ template หรือไฟล์อื่นเกินจำเป็น
- **3** — extraction ถูกต้อง แต่วางตำแหน่งแปลก (เช่น สร้างไฟล์ util แยกใหม่ทั้งที่โปรเจกต์เล็กมากไม่มี pattern นั้น) หรือตั้งชื่อไม่ตรงธรรมเนียม
- **2** — ทำงานได้แต่ซับซ้อนเกินจำเป็น (เช่น เพิ่ม pipe ใหม่ทั้งอันสำหรับ logic บรรทัดเดียว)
- **1** — ต้องรื้อแก้เยอะก่อน merge ได้
- **0** — ไม่ควร merge

## Why this design

- **Frontend-layer counterpart to refactor-01/02**, which are both in the
  Node API — this exercises the same "spot and merge duplication" skill on
  Angular/TypeScript instead, matching how explain-01/02/03 spread across
  layers too.
- **Constructed, not organic** (like refactor-01) — `lastUpdatedAt` and
  `formatTimestamp` were added specifically for this task, framed as a
  plausible small feature (a freshness indicator) whose author reasonably
  reached for a quick copy-paste instead of reusing `formatSlot`'s existing
  formatter.
- **Deliberately not full-string duplication** — `formatSlot` and
  `formatTimestamp` produce differently-shaped output (a range vs. a single
  instant), so the "correct" refactor requires noticing which *part* is
  actually shared (the HH:mm slice) versus which part legitimately differs
  per caller (the surrounding string assembly) — a sharper judgment call
  than refactor-01/02's fully-identical duplicates.

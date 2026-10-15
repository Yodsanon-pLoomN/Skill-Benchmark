# explain-02 — internal notes (do NOT ship to graders)

Domain: meeting room booking, Node API (`sample-project`). Fabricated.
Repo: `sample-project` · base tag: `explain-02-base` = an alias for
`base-clean` (read-only task, needs the correct/undefective code — must not
point at any `bugfix-0x-base` tag).

**Backend counterpart to explain-01** (which covered the same half-open
theme on the Angular frontend's *display* code). This task moves one layer
down, into the actual algorithm that computes availability server-side —
`checkAvailability`'s interval-sweep loop — which explain-01 explicitly
said it does *not* re-implement client-side.

## Reference answers

**1. What `findBookingsForDay` fetches**
`bookingRepository.findBookingsForDay(roomId, dateStr)` queries
`prisma.booking.findMany` with `where: { roomId, status: "CONFIRMED",
startsAt: { lte: endOfUtcDay(dateStr) }, endsAt: { gte: startOfUtcDay(dateStr) } }`.
Two things worth naming explicitly: it filters to `status: "CONFIRMED"`
only — `CANCELLED` bookings are excluded at the query level, per
`docs/DOMAIN.md` rule 2 ("must be ignored by every availability and
conflict check") — and the date filter is an *overlap* test against the
day window (`startsAt <= dayEnd && endsAt >= dayStart`), not an
"is this booking entirely inside this day" test, so it correctly includes
a booking that started the previous day and spills into this one, or one
that starts this day and spills into the next.

**2. Trace for two overlapping CONFIRMED bookings, 09:00–10:00 and 09:30–11:00**
Sorted by `startsAt`: `b1 = [09:00,10:00)`, `b2 = [09:30,11:00)`.
`cursor` starts at `dayStart` (00:00).

| step | booking | `startsAt > cursor`? | push to `free`? | `endsAt > cursor`? | new `cursor` |
|---|---|---|---|---|---|
| 1 | b1 [09:00,10:00) | 09:00 > 00:00 → yes | `{00:00–09:00}` | 10:00 > 00:00 → yes | 10:00 |
| 2 | b2 [09:30,11:00) | 09:30 > 10:00 → **no** | *(nothing)* | 11:00 > 10:00 → yes | 11:00 |
| end | — | 11:00 < dayEnd → yes | `{11:00–dayEnd}` | — | — |

Final `free = [{00:00–09:00}, {11:00–dayEnd}]`. The key point: at step 2,
`b2`'s `startsAt` (09:30) is *not* greater than the already-advanced
`cursor` (10:00), so the loop correctly does **not** push a bogus free gap
between the two overlapping bookings — the `startsAt > cursor` check is
precisely what lets the sweep treat two overlapping bookings as one
continuous occupied span, without needing any separate merge step.

**3. `>=` instead of `>` on `booking.startsAt > cursor`**
Take two legally **back-to-back** CONFIRMED bookings: `b1 = [09:00,10:00)`,
`b2 = [10:00,11:00)` (per `docs/DOMAIN.md`, these do not overlap — the
first releases 10:00 exactly as the second claims it). Trace with the
mutation:
- Step 1 (`b1`): pushes `{00:00–09:00}`, `cursor → 10:00`.
- Step 2 (`b2`): `startsAt (10:00) >= cursor (10:00)` → **true** with the
  mutation (would be `false` with the correct `>`) → pushes
  `{cursor: 10:00, startsAt: 10:00}` — a **zero-length "free" interval at
  10:00–10:00**, right at the exact boundary between two adjacent
  bookings, where the room is in fact never free at all.

A correct answer should land on: the bug only shows up for back-to-back
bookings specifically (the one boundary case the half-open interval rule
exists to handle), and it manifests as a spurious zero-duration entry in
the response rather than a crash — a client (like `sample-project-webapp`'s
`RoomAvailabilityComponent`, see explain-01) would render a slot that looks
like "10:00–10:00 UTC", which is nonsensical but wouldn't throw.

*(Internal only — do not put this in the grader-facing prompt: the mirror
question about `booking.endsAt > cursor` was deliberately dropped from
`prompt.txt`. That guard's `>` vs `>=` choice has no observable effect —
the assignment `cursor = booking.endsAt` is idempotent when `endsAt`
already equals `cursor`, so relaxing it to `>=` only re-triggers a
no-op assignment in the equal case, never a different value. Don't award
or dock credit if an answer speculates about it; there is nothing there to
find, and a strong answer correctly explains why not, but that is above
what the task asks for.)*

## ด้านที่ 1-2 (ความถูกต้อง/ความครบถ้วน) worked examples

- **4** — All three answered correctly: names the `CONFIRMED` filter and
  the overlap-style date-window query for Q1; correctly traces `cursor`
  through both steps and states the final two free intervals for Q2
  (`{00:00–09:00}`, `{11:00–dayEnd}}`); gives the back-to-back
  zero-length-interval example (or an equivalent correct concrete case) for
  Q3.
- **3** — All three answered and broadly correct, but one is thin — e.g.
  traces Q2 correctly but doesn't explain *why* step 2 doesn't push a free
  gap (just states the mechanical result), or gets Q3's concrete example
  right but doesn't identify the zero-length-interval consequence.
- **2** — One question unanswered or a material error — e.g. claims
  `findBookingsForDay` excludes bookings that only partially overlap the
  day, or gets the Q2 trace's final free intervals wrong.
- **1** — Mostly restates the code line-by-line without tracing concrete
  values, or two questions unanswered.
- **0** — Wrong, empty, or edited files despite "do not change any files".

## ด้านที่ 3 — คุณภาพของคำอธิบาย: worked examples

(เช่นเดียวกับ explain-01 — rubric กลางตีความด้าน 3 เป็น "คุณภาพของคำอธิบาย" สำหรับ task นี้)

- **4** — ตอบเป็นระเบียบตามลำดับ 3 คำถาม, Q2 มีตารางหรือ step-by-step ชัดเจนตามค่า `cursor` จริง ไม่ใช่แค่บรรยายกว้างๆ, ใช้ศัพท์ทางเทคนิคถูกต้องสม่ำเสมอ
- **3** — เนื้อหาถูกและชัดเจน แต่มีจุดอ่านสะดุดเล็กน้อย เช่น trace ของ Q2 ข้ามขั้นตอนกลางไปตอบผลลัพธ์สุดท้ายเลย
- **2** — เนื้อหาถูกแต่จัดระเบียบไม่ดี ต้องอ่านหลายรอบถึงจะปะติดปะต่อได้
- **1** — คำตอบถูกฝังอยู่ในข้อความยาวเยิ่นเย้อ หรือสั้นห้วนเกินจนไม่ชัดว่าหมายถึงอะไร
- **0** — ไม่มีคำอธิบายให้ประเมินคุณภาพ

## Why this design

- **Same three-question shape as explain-01** (responsibility/flow split,
  step-by-step trace, half-open boundary consequence), applied one layer
  down — backend algorithm instead of frontend data flow — so the two
  explain tasks test comprehension of different code without testing
  different *skills*.
- **Q2 forces a concrete numeric trace, not a paraphrase.** Two overlapping
  (not just back-to-back) bookings are used specifically because the naive
  "each booking creates a gap before it" mental model breaks here — a
  correct answer has to notice `cursor` already having moved past `b2`'s
  `startsAt` and explain why no gap is pushed, not just describe the loop
  in the abstract.
- **Q3 is deliberately scoped to only the provably-broken mutation**
  (`startsAt > cursor` → `>=`) rather than asking about both `if`
  conditions — the second one's `>` vs `>=` is a genuine no-op (see
  internal note above), and asking about it would have no correct "what
  goes wrong" answer, which would make the question ungradable.

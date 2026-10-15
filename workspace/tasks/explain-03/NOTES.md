# explain-03 — internal notes (do NOT ship to graders)

Domain: meeting room booking, C# reports API (`sample-project-reports-api`). Fabricated.
Repo: `sample-project-reports-api` · base tag: `feature-01-base` (reused —
read-only task, code is already correct at this tag, nothing to fix).

**Third leg of the explain set**: explain-01 = Angular frontend data flow,
explain-02 = Node backend sweep algorithm, explain-03 = C# EF Core
aggregation. Same three-question shape (structure/flow, step-by-step trace,
a specific "what if" consequence), spread across all three repos in the
task set so the read-and-explain skill is tested against three different
languages/frameworks rather than three variations on one codebase.

## Reference answers

**1. `GetRoomUsageAsync()` step by step**
`_db.Rooms.Include(r => r.Bookings).ToListAsync()` fetches every `Room` row
and eagerly loads each room's related `Booking` rows in the same query (EF
Core `Include` = SQL join, avoiding N+1 queries — one query per room
otherwise, since `Booking` isn't loaded by default with a plain
`_db.Rooms.ToListAsync()`). Without `Include`, `room.Bookings` on each
fetched `Room` would be an **empty, uninitialized collection** (EF Core
does not lazy-load by default in this project — no proxies configured),
so `confirmed` would always be empty and every room would incorrectly
report 0 bookings and 0 hours regardless of actual data. After fetching,
`.Select(room => ...)` computes a `RoomUsageSummary` per room in memory
(`confirmed.Count`, `confirmed.Sum(...)`), then `.OrderByDescending(s =>
s.TotalBookedHours)` sorts the whole in-memory list before returning it.

**2. Why filter to `Status == "CONFIRMED"`**
`CANCELLED` bookings still exist as rows (nothing deletes them — mirrors
the Node API's rule 2, which says cancelled bookings "release their slot"
but the record itself persists) but must not count toward usage — a
cancelled booking never happened as far as room occupancy is concerned. For
room "Beta" specifically: its only seeded booking (`seed-3`) is
`CANCELLED`. Without the filter, `GetRoomUsageAsync()` would report Beta as
having 1 "confirmed" booking and 2 booked hours — a room that, per the
domain rules, was actually never occupied at all.

**3. What `GetRoomUsageAsync()` returns for "Beta" today**
`room.Bookings` for Beta is `[seed-3]`, but `seed-3.Status == "CANCELLED"`,
so `confirmed = room.Bookings.Where(b => b.Status == "CONFIRMED").ToList()`
is an **empty list** — `confirmed.Count == 0`. The next line,
`confirmed.Sum(b => (b.EndsAt - b.StartsAt).TotalHours)`, is called on that
empty list. **This does not throw**: `Enumerable.Sum()` is defined to
return `0` for an empty sequence (unlike `.Max()`/`.Average()`/`.First()`,
which do throw `InvalidOperationException` on an empty sequence — a
different LINQ method would misbehave here, but `Sum` is safe). So the
method returns a normal `RoomUsageSummary("room-b", "Beta", 0, 0.0)` row,
included in the final sorted list like any other room — no exception, no
null, no missing row.

*(Internal only: this task is deliberately paired with `feature-03`, which
asks the agent to *add* a `.Max()`-based "longest booking" field to this
same aggregation — where the identical empty-`confirmed`-list scenario for
Beta *does* throw if unguarded. A correct answer to Q3 here should not
claim Beta's request fails; if an answer says it throws, that's a concrete,
gradable error, not a stylistic quibble.)*

## ด้านที่ 1-2 (ความถูกต้อง/ความครบถ้วน) worked examples

- **4** — All three answered correctly: explains `Include` and what its
  absence would do (empty `Bookings`, not an error) for Q1; correctly ties
  the `CONFIRMED` filter to cancelled-but-persisted bookings and names
  Beta's would-be-wrong numbers for Q2; correctly concludes Beta returns a
  normal zero-valued row (not a throw) for Q3, with the `Sum`-on-empty
  reasoning stated.
- **3** — All three answered and broadly correct, but one is thin — e.g.
  correctly says `Include` is needed but doesn't explain what breaks
  without it, or gets Q3's "no throw" conclusion right without explaining
  *why* (`Sum` vs. other LINQ aggregates on empty sequences).
- **2** — One question unanswered or a material error — most likely
  wrongly claiming Q3 throws or returns null.
- **1** — Mostly restates the code (paraphrases each line) without
  explaining what it does or why, or two questions unanswered.
- **0** — Wrong, empty, or edited files despite "do not change any files".

## ด้านที่ 3 — คุณภาพของคำอธิบาย: worked examples

(เช่นเดียวกับ explain-01/explain-02 — ด้าน 3 ตีความเป็น "คุณภาพของคำอธิบาย")

- **4** — ตอบเรียงตามลำดับ 3 คำถาม ระบุชัดเจนว่า Q3 "ไม่ throw" ตั้งแต่ต้นคำตอบ (ไม่ทิ้งให้ผู้อ่านต้องลุ้น) ใช้ศัพท์ถูกต้อง (`Include`, `LINQ`, `Sum` vs `Max`) สม่ำเสมอ
- **3** — เนื้อหาถูกและชัดเจน แต่มีจุดอ่านสะดุดเล็กน้อย เช่น ข้อสรุปของ Q3 ("ไม่ throw") อยู่กลางย่อหน้ายาวแทนที่จะขึ้นต้นให้ชัด
- **2** — เนื้อหาถูกแต่จัดระเบียบไม่ดี ต้องอ่านหลายรอบถึงจะปะติดปะต่อได้
- **1** — คำตอบถูกฝังอยู่ในข้อความยาวเยิ่นเย้อ หรือสั้นห้วนเกินจนไม่ชัดว่าหมายถึงอะไร
- **0** — ไม่มีคำอธิบายให้ประเมินคุณภาพ

## Why this design

- **Third repo, third language** for the explain task family — C#/EF Core
  instead of TypeScript/RxJS (explain-01) or TypeScript/Prisma (explain-02)
  — tests whether comprehension transfers across stacks, matching this
  project's stated axis (tool-assisted comprehension, not language-specific
  familiarity).
- **Q3's answer is the safe counterpart to feature-03's trap.** feature-03
  asks the agent to *write* a `.Max()`-based field and rewards noticing the
  empty-sequence throw; explain-03 asks the agent to *read* existing
  `.Sum()`-based code and correctly conclude nothing throws. Together they
  test both directions of the same LINQ-aggregate-on-empty-collection
  knowledge, which is easy to get backwards (assuming all LINQ aggregates
  either "always throw" or "always default to zero" on empty input, when
  the truth depends on which method).
- **Uses the already-shipped seed data** (`room-b`/`seed-3`) rather than a
  new fixture, same economy as `feature-03`/`refactor-02`.

# feature-03 — internal notes (do NOT ship to graders)

Domain: meeting room booking, C# reports API (`sample-project-reports-api`). Fabricated.
Repo: `sample-project-reports-api` · base tag: `feature-01-base` (same base
as feature-01/feature-02, reused as-is — no `room-usage/{roomId}` endpoint
exists yet).

This repo does not have its own `docs/DOMAIN.md` — all rules needed for this
endpoint are given directly in `prompt.txt`.

## Reference implementation

```csharp
public record RoomUsageDetail(string RoomId, string RoomName, int ConfirmedBookingCount, double TotalBookedHours, double LongestBookingHours);

[HttpGet("room-usage/{roomId}")]
public async Task<ActionResult<RoomUsageDetail>> GetRoomUsageDetail(string roomId)
{
    var room = await _db.Rooms.Include(r => r.Bookings).FirstOrDefaultAsync(r => r.Id == roomId);
    if (room is null) return NotFound();

    var confirmed = room.Bookings.Where(b => b.Status == "CONFIRMED").ToList();
    var totalHours = confirmed.Sum(b => (b.EndsAt - b.StartsAt).TotalHours);
    var longestHours = confirmed.Count > 0
        ? confirmed.Max(b => (b.EndsAt - b.StartsAt).TotalHours)
        : 0;

    return Ok(new RoomUsageDetail(room.Id, room.Name, confirmed.Count, totalHours, longestHours));
}
```

(Exact record/method names not prescribed.)

## The trap: `.Max()` on an empty sequence throws in .NET

`Enumerable.Max()` (and `.Average()`, `.Min()`, `.First()`) throw
`InvalidOperationException: Sequence contains no elements` when called on
an empty sequence — unlike `.Sum()`, which safely returns `0` for an empty
sequence. This is a well-known but easy-to-forget .NET/LINQ gotcha, and
it's exactly the shape of bug prompt point 4 is designed to surface: a
naive `confirmed.Max(b => ...)` with no guard will 500 instead of returning
`LongestBookingHours = 0` the moment it hits a room with confirmed bookings
== 0.

**The seed data already contains this case for free**: room `room-b`
("Beta", see `Data/DbInitializer.cs`) has exactly one booking, `seed-3`,
and it is `CANCELLED` — so `room-b` has zero `CONFIRMED` bookings in the
seed data as shipped. `GET /reports/room-usage/room-b` is the direct,
already-available check for whether this defect class was avoided.

## Two independent judgment points (per benchmark-tasks spec)

1. **404 for a nonexistent room id** (e.g. `GET /reports/room-usage/does-not-exist`)
   — a missing `FirstOrDefaultAsync`/null-check, or using `.First(...)`
   instead of `.FirstOrDefault(...)`, would 500 instead of 404.
2. **Zero-`CONFIRMED`-bookings room does not throw** (see trap above,
   directly checkable against `room-b`) — this is the sharper of the two
   points; rooms with confirmed bookings are the "obvious" path every
   implementation gets right on the first try.

## ด้านที่ 1-2 (ความถูกต้อง/ความครบถ้วน) worked examples

- **4** — 404 for a missing room; correct count/total/longest for a room
  with confirmed bookings; `room-b` (zero confirmed) returns 200 with all
  three numeric fields at 0, no exception.
- **3** — All four prompt points correct — ceiling here is usually a ด้านที่
  3 blemish (e.g. 404 returned with a body shape inconsistent with the rest
  of the API) rather than a 1-2 issue.
- **2** — Works for the common case (room with confirmed bookings) and gets
  one of the two judgment points right but not the other — most often: 404
  handled, but `room-b` (or any zero-confirmed room) throws a 500 from an
  unguarded `.Max()`/`.Average()`.
- **1** — Endpoint added but core aggregation wrong (e.g. counts/sums
  include `CANCELLED` bookings, violating prompt point 3).
- **0** — No endpoint added, wrong route, or the project doesn't build.

## ด้านที่ 3 — คุณภาพของโค้ด: worked examples

- **4** — ตรงตาม convention ของ `ReportsController`/`RoomUsageReportService` เดิม (record type, `Include(r => r.Bookings)` แบบเดียวกับ `GetRoomUsageAsync` เดิม, async/await) ไม่แตะ endpoint อื่น
- **3** — ทำงานถูก แต่มีจุดติเล็กน้อย เช่น เขียน guard ป้องกัน `.Max()` บนลิสต์ว่างด้วย try/catch แทนการเช็ค `.Count > 0` ก่อน (ทำงานได้แต่ไม่ใช่สไตล์ที่ใช้อยู่ในไฟล์นี้)
- **2** — ทำงานได้แต่ซับซ้อนเกินจำเป็น (เช่น query ฐานข้อมูลแยก 3 รอบสำหรับ count/sum/max แทนที่จะดึง `Bookings` มาครั้งเดียวแล้ว filter ใน memory เหมือน endpoint เดิม)
- **1** — ต้องรื้อแก้เยอะก่อน merge ได้
- **0** — ไม่ควร merge

## Why this design

- **Same repo/domain as feature-01/feature-02, third independent endpoint**
  — deliberately keeps testing "add new behaviour correctly" rather than
  reusing feature-01's overlap-check trap or feature-02's time-window trap;
  this task's trap is C#/.NET-specific (empty-sequence LINQ aggregates)
  rather than domain-rule-specific, adding a different failure mode to the
  set.
- **Zero-confirmed-bookings edge case is already in the shipped seed data**
  (`room-b`/`seed-3`) rather than needing a new tag or seed change — same
  "reuse what's already there" economy as `refactor-02`.
- **Symmetric with feature-02's seed-data trap**: feature-02's trap
  (`seed-3` cancelled at the same timestamp as `seed-1` confirmed) tests the
  *status filter*; this task's trap (`room-b` having zero confirmed
  bookings after that same filter is applied) tests what happens *after*
  the filter, on the resulting empty collection — two adjacent but distinct
  failure points in the same aggregation pipeline shape.

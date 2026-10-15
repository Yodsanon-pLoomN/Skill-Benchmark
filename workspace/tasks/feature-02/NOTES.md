# feature-02 — internal notes (do NOT ship to graders)

Domain: meeting room booking, C# reports API (`sample-project-reports-api`). Fabricated.
Repo: `sample-project-reports-api` · base tag: `feature-01-base` (same base
as feature-01, reused as-is — no `upcoming-bookings` endpoint exists yet,
independent addition, no new tag needed).

This repo does not have its own `docs/DOMAIN.md` (see `docs/README.md`) —
all rules needed for this endpoint are given directly in `prompt.txt`.

## Reference implementation

```csharp
public record UpcomingBooking(string RoomId, string RoomName, string UserId, DateTime StartsAt, DateTime EndsAt);

[HttpGet("upcoming-bookings")]
public async Task<ActionResult<List<UpcomingBooking>>> GetUpcomingBookings(
    [FromQuery] int withinHours = 24,
    [FromQuery] DateTime? asOf = null)
{
    var now = asOf ?? DateTime.UtcNow;
    var windowEnd = now.AddHours(withinHours);

    var bookings = await _db.Bookings
        .Include(b => b.Room)
        .Where(b => b.Status == "CONFIRMED" && b.StartsAt >= now && b.StartsAt < windowEnd)
        .OrderBy(b => b.StartsAt)
        .Select(b => new UpcomingBooking(b.RoomId, b.Room!.Name, b.UserId, b.StartsAt, b.EndsAt))
        .ToListAsync();

    return Ok(bookings);
}
```

(Exact record/method names not prescribed — judge on whether the four
behaviour points are enforced, not on matching this code. Placing this on
the existing `RoomUsageReportService`/`ReportsController` vs. a new
service/controller is a style choice, not a correctness one.)

## Concrete check against seed data (`Data/DbInitializer.cs`)

`asOf=2031-01-01T08:00:00Z&withinHours=2`:
- `seed-1` (room-a "Alpha", CONFIRMED, starts `2031-01-01T09:00:00Z`) →
  inside `[08:00, 10:00)` → **must appear**.
- `seed-3` (room-b "Beta", **CANCELLED**, starts `2031-01-01T09:00:00Z`) →
  same window, but cancelled → **must not appear**. This is the built-in
  trap for judgment point 1 (seed data has a cancelled booking at the exact
  same time as a confirmed one, in a different room, specifically so
  "forgot the status filter" produces a visibly wrong extra row rather than
  silently passing).
- `seed-2` (room-a, CONFIRMED, starts `2031-01-02T13:00:00Z`) → over a day
  away → **must not appear**.

## Two independent judgment points (per benchmark-tasks spec)

1. **`Status == "CONFIRMED"` filter.** Common mistake: omitting it (matches
   `seed-3` above), or filtering client-side after materializing the whole
   table (works but wasteful — a ด้านที่ 3 concern, not ด้านที่ 1).
2. **Window boundary uses `StartsAt`, not `EndsAt`, and is half-open on both
   ends (`>= asOf`, `< windowEnd`).** Common mistakes: comparing `EndsAt`
   instead of `StartsAt` (would wrongly include/exclude ongoing bookings —
   see prompt point 3), or using `<=` for `windowEnd` (would include a
   booking starting exactly at the edge of the window, off by the
   half-open convention this whole task set uses elsewhere).

## ด้านที่ 1-2 (ความถูกต้อง/ความครบถ้วน) worked examples

- **4** — All four behaviour points correct, verified against the seed-data
  scenario above (seed-1 appears, seed-3 does not, seed-2 does not at
  `withinHours=2`); only the new endpoint added.
- **3** — All four correct — ceiling here is usually a ด้านที่ 3 blemish
  (e.g. wrong status code on an edge case) rather than a 1-2 issue.
- **2** — Endpoint works and gets 2 of the 4 behaviour points right (most
  commonly: sorting + `asOf` default right, status filter or window
  boundary wrong).
- **1** — Endpoint added but doesn't actually filter/window correctly (e.g.
  returns every CONFIRMED booking regardless of time, or every booking
  regardless of status).
- **0** — No endpoint added, wrong route/method, or the project doesn't
  build.

## ด้านที่ 3 — คุณภาพของโค้ด: worked examples

- **4** — ตรงตาม convention ของ repo (controller action ใน `ReportsController` เดิม หรือ service method ใน `RoomUsageReportService` เดิม, `[FromQuery]` ตาม pattern ของ .NET, `async`/`await`, EF Core query แปลเป็น SQL ได้ทั้งอัน ไม่ materialize ทั้งตารางมาก่อนกรอง) ไม่แตะโค้ดอื่น
- **3** — ทำงานถูก แต่มีจุดติเล็กน้อย เช่น ดึงข้อมูลทั้งหมดมา filter ใน memory (`.ToListAsync()` ก่อน `.Where(...)`) แทนที่จะให้ EF Core แปล query
- **2** — ทำงานได้แต่ซับซ้อนเกินจำเป็น (เช่น เพิ่ม repository layer ใหม่ทั้งชั้นสำหรับ endpoint เดียว)
- **1** — ต้องรื้อแก้เยอะก่อน merge ได้
- **0** — ไม่ควร merge

## Why this design

- **Independent from feature-01** (extend-booking) and from feature-03
  (per-room usage detail) — a report/read endpoint rather than a mutation,
  covering the "aggregate across rooms" shape neither of the other two
  feature tasks exercises.
- **`asOf` parameter is a deliberate testability device**, not part of a
  real product spec — it lets the "next N hours" logic be checked
  deterministically against the fixed seed data instead of needing the
  grader/agent to know the real wall-clock time, mirroring how the seed
  data's 2031 dates were chosen for the same reason in `feature-01`.
- **Two judgment points, same "≥2 independent checks" shape as the other
  three feature/bugfix tasks** in this set, so grading stays comparable
  across tasks.

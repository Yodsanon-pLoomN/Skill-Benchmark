# Blind grading input — feature-01 / caveman

⚠️ Run labels below are shuffled and do NOT reveal which condition (off vs skill) produced each one — graded by content only, per the blind-grading rule. Key file: `report-KEY.md` (do not open until grade_runs.py has produced report-scored.md).

> ตรวจโดย `grade_runs.py` อัตโนมัติ (blind, 3 pass อิสระ, majority vote, เกณฑ์ผ่าน >=80% ของ checklist) — checklist จริงเจาะจงต่อ task อยู่ที่ `workspace/tasks/<task_id>/checklist.md` กติกากลางดู `RUBRIC-กลาง.md` ไม่มี rubric 0-4 ฝังในไฟล์นี้อีกต่อไป

---

## Run A

```diff
diff --git a/Controllers/BookingsController.cs b/Controllers/BookingsController.cs
new file mode 100644
index 0000000..8afc633
--- /dev/null
+++ b/Controllers/BookingsController.cs
@@ -0,0 +1,58 @@
+using Microsoft.AspNetCore.Mvc;
+using Microsoft.EntityFrameworkCore;
+using ReportsApi.Data;
+using ReportsApi.Models;
+
+namespace ReportsApi.Controllers;
+
+public record ExtendBookingRequest(DateTimeOffset? NewEndsAt);
+
+[ApiController]
+[Route("bookings")]
+public class BookingsController : ControllerBase
+{
+    private static readonly TimeSpan MaxDuration = TimeSpan.FromHours(8);
+
+    private readonly ReportsDbContext _db;
+
+    public BookingsController(ReportsDbContext db)
+    {
+        _db = db;
+    }
+
+    [HttpPatch("{id}/extend")]
+    public async Task<ActionResult<Booking>> Extend(string id, [FromBody] ExtendBookingRequest request)
+    {
+        if (request?.NewEndsAt is null)
+            return BadRequest(new { error = "newEndsAt is required (ISO 8601 timestamp)." });
+
+        var newEndsAt = DateTime.SpecifyKind(request.NewEndsAt.Value.UtcDateTime, DateTimeKind.Utc);
+
+        var booking = await _db.Bookings.FirstOrDefaultAsync(b => b.Id == id);
+        if (booking is null)
+            return NotFound(new { error = $"Booking '{id}' not found." });
+
+        if (booking.Status != "CONFIRMED")
+            return Conflict(new { error = "Only CONFIRMED bookings can be extended." });
+
+        if (newEndsAt <= booking.EndsAt)
+            return BadRequest(new { error = "newEndsAt must be strictly after the current EndsAt." });
+
+        if (newEndsAt - booking.StartsAt > MaxDuration)
+            return BadRequest(new { error = "Total booking duration must not exceed 8 hours." });
+
+        // Filter by time in memory: SQLite stores DateTime as text, so keep comparisons in .NET.
+        var others = await _db.Bookings
+            .Where(b => b.RoomId == booking.RoomId && b.Id != booking.Id && b.Status == "CONFIRMED")
+            .ToListAsync();
+
+        var conflict = others.Any(b => booking.StartsAt < b.EndsAt && newEndsAt > b.StartsAt);
+        if (conflict)
+            return Conflict(new { error = "Extended range overlaps another CONFIRMED booking in this room." });
+
+        booking.EndsAt = newEndsAt;
+        await _db.SaveChangesAsync();
+
+        return Ok(booking);
+    }
+}
```

**Response text:**

UTC stored. Write controller.

Build not run: the sandbox needs approval for `dotnet build`, and I didn't get it. The code is written but has not been compiled or tested.

I added `Controllers/BookingsController.cs` with `PATCH /bookings/{id}/extend`. Body is `{ "newEndsAt": "<ISO 8601>" }`. The timestamp is converted to UTC, since the existing data is stored as UTC.

| Case | Response |
|---|---|
| `newEndsAt` missing or not a valid timestamp | 400 |
| Booking not found | 404 |
| Status is not `CONFIRMED` (e.g. cancelled) | 409 |
| `newEndsAt` is not strictly after the current `EndsAt` | 400 |
| Total duration from `StartsAt` to `newEndsAt` exceeds 8 hours | 400 |
| Overlaps another `CONFIRMED` booking in the same room | 409 |
| Success | 200 with the updated booking, `EndsAt` saved |

- **Overlap check:** it uses `booking.StartsAt < b.EndsAt && newEndsAt > b.StartsAt` and excludes the booking itself. A booking ending exactly when another starts is not a conflict.
- **In-memory filtering:** the time comparison runs in .NET, not in the SQLite query, because SQLite stores `DateTime` as text. It loads the room's `CONFIRMED` bookings first, which is fine at this scale.
- **Status codes:** the spec only said "4xx", so 400 vs 409 is my choice. Say if you want different codes.

Run `dotnet build` to confirm it compiles.

---

## Run B

```diff
diff --git a/Controllers/BookingsController.cs b/Controllers/BookingsController.cs
new file mode 100644
index 0000000..e0dbdaa
--- /dev/null
+++ b/Controllers/BookingsController.cs
@@ -0,0 +1,65 @@
+using Microsoft.AspNetCore.Mvc;
+using Microsoft.EntityFrameworkCore;
+using ReportsApi.Data;
+using ReportsApi.Models;
+
+namespace ReportsApi.Controllers;
+
+public record ExtendBookingRequest(DateTimeOffset? NewEndsAt);
+
+[ApiController]
+[Route("bookings")]
+public class BookingsController : ControllerBase
+{
+    private static readonly TimeSpan MaxDuration = TimeSpan.FromHours(8);
+
+    private readonly ReportsDbContext _db;
+
+    public BookingsController(ReportsDbContext db)
+    {
+        _db = db;
+    }
+
+    [HttpPatch("{id}/extend")]
+    public async Task<ActionResult<Booking>> Extend(string id, [FromBody] ExtendBookingRequest request)
+    {
+        if (request.NewEndsAt is null)
+            return BadRequest(new { error = "newEndsAt is required and must be an ISO 8601 timestamp." });
+
+        var booking = await _db.Bookings.FirstOrDefaultAsync(b => b.Id == id);
+        if (booking is null)
+            return NotFound(new { error = "Booking not found." });
+
+        if (booking.Status != "CONFIRMED")
+            return Conflict(new { error = "Only CONFIRMED bookings can be extended." });
+
+        // SQLite returns DateTimes with Kind=Unspecified; values are stored as UTC.
+        var startsAt = DateTime.SpecifyKind(booking.StartsAt, DateTimeKind.Utc);
+        var endsAt = DateTime.SpecifyKind(booking.EndsAt, DateTimeKind.Utc);
+        var newEndsAt = request.NewEndsAt.Value.UtcDateTime;
+
+        if (newEndsAt <= endsAt)
+            return BadRequest(new { error = "newEndsAt must be after the current EndsAt." });
+
+        if (newEndsAt - startsAt > MaxDuration)
+            return BadRequest(new { error = "Total booking duration must not exceed 8 hours." });
+
+        // Filter by room/status in SQL, compare times in memory to avoid
+        // provider-specific DateTime translation differences.
+        var others = await _db.Bookings
+            .AsNoTracking()
+            .Where(b => b.RoomId == booking.RoomId && b.Id != booking.Id && b.Status == "CONFIRMED")
+            .ToListAsync();
+
+        var overlaps = others.Any(b =>
+            startsAt < DateTime.SpecifyKind(b.EndsAt, DateTimeKind.Utc) &&
+            newEndsAt > DateTime.SpecifyKind(b.StartsAt, DateTimeKind.Utc));
+        if (overlaps)
+            return Conflict(new { error = "The extended range overlaps another CONFIRMED booking in this room." });
+
+        booking.EndsAt = newEndsAt;
+        await _db.SaveChangesAsync();
+
+        return Ok(booking);
+    }
+}
```

**Response text:**

Build check is waiting on approval; I'll retry it as a single plain command.

I added `PATCH /bookings/{id}/extend` in `Controllers/BookingsController.cs`, but I haven't compiled or run it. Every `dotnet build` attempt needed an approval I didn't get. Please run `dotnet build` yourself before relying on it.

Here is how each case is handled:

| Case | Response |
|---|---|
| `newEndsAt` missing or not a valid ISO 8601 timestamp | 400 |
| Booking id not found | 404 |
| Booking is not `CONFIRMED` (e.g. cancelled) | 409 |
| `newEndsAt` is not strictly after the current `EndsAt` | 400 |
| Total duration from `StartsAt` to `newEndsAt` is over 8 hours | 400 |
| Extended range overlaps another `CONFIRMED` booking in the same room | 409 |
| Success | 200 with the updated booking, new `EndsAt` saved |

The overlap check uses `StartsAt < other.EndsAt && newEndsAt > other.StartsAt`, so a booking that ends exactly when another starts is not an overlap. It skips the booking being extended and ignores cancelled bookings.

- **UTC handling:** all times are treated as UTC, because SQLite hands back `DateTime` values with an unspecified kind. A `newEndsAt` with an offset is converted to UTC first.
- **Overlap comparison:** I load the room's other confirmed bookings and compare the times in C#, rather than translating the comparison to SQL. That keeps it independent of how SQLite stores dates, but it reads every confirmed booking in the room.

I haven't added tests.

---

## Run C

```diff
diff --git a/Controllers/BookingsController.cs b/Controllers/BookingsController.cs
new file mode 100644
index 0000000..a0390b8
--- /dev/null
+++ b/Controllers/BookingsController.cs
@@ -0,0 +1,66 @@
+using System.Globalization;
+using Microsoft.AspNetCore.Mvc;
+using Microsoft.EntityFrameworkCore;
+using ReportsApi.Data;
+using ReportsApi.Models;
+
+namespace ReportsApi.Controllers;
+
+public record ExtendBookingRequest(string? NewEndsAt);
+
+[ApiController]
+[Route("bookings")]
+public class BookingsController : ControllerBase
+{
+    private static readonly TimeSpan MaxDuration = TimeSpan.FromHours(8);
+
+    private readonly ReportsDbContext _db;
+
+    public BookingsController(ReportsDbContext db)
+    {
+        _db = db;
+    }
+
+    [HttpPatch("{id}/extend")]
+    public async Task<ActionResult<Booking>> Extend(string id, [FromBody] ExtendBookingRequest request)
+    {
+        if (!DateTime.TryParse(request.NewEndsAt, CultureInfo.InvariantCulture,
+                DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal, out var newEndsAt))
+        {
+            return BadRequest(new { error = "newEndsAt must be a valid ISO 8601 timestamp." });
+        }
+
+        var booking = await _db.Bookings.FirstOrDefaultAsync(b => b.Id == id);
+        if (booking is null)
+            return NotFound(new { error = "Booking not found." });
+
+        if (booking.Status != "CONFIRMED")
+            return Conflict(new { error = "Only CONFIRMED bookings can be extended." });
+
+        // Timestamps are stored as UTC; SQLite returns them with Kind=Unspecified,
+        // so compare raw ticks rather than relying on Kind.
+        var startsAt = booking.StartsAt.Ticks;
+        var currentEndsAt = booking.EndsAt.Ticks;
+
+        if (newEndsAt.Ticks <= currentEndsAt)
+            return BadRequest(new { error = "newEndsAt must be after the booking's current end." });
+
+        if (newEndsAt.Ticks - startsAt > MaxDuration.Ticks)
+            return BadRequest(new { error = "Total booking duration must not exceed 8 hours." });
+
+        // Compared in memory: SQLite stores DateTime as text, so avoid relying on
+        // server-side text comparison of timestamps.
+        var others = await _db.Bookings
+            .Where(b => b.RoomId == booking.RoomId && b.Id != booking.Id && b.Status == "CONFIRMED")
+            .ToListAsync();
+
+        var conflict = others.Any(o => startsAt < o.EndsAt.Ticks && newEndsAt.Ticks > o.StartsAt.Ticks);
+        if (conflict)
+            return Conflict(new { error = "Extended range overlaps another confirmed booking in this room." });
+
+        booking.EndsAt = DateTime.SpecifyKind(newEndsAt, DateTimeKind.Utc);
+        await _db.SaveChangesAsync();
+
+        return Ok(booking);
+    }
+}
```

**Response text:**

Building to check the new controller compiles.

I added `PATCH /bookings/{id}/extend` in `Controllers/BookingsController.cs`, but I haven't compiled or run it. Both `dotnet build` attempts were blocked by a permission prompt, and this session can't answer one. Please run `dotnet build` yourself before relying on it.

Error responses:

| Case | Response |
|---|---|
| `newEndsAt` missing or not a valid timestamp | 400 |
| Booking id not found | 404 |
| Booking not `CONFIRMED` | 409 |
| `newEndsAt` not strictly after the current `EndsAt` | 400 |
| Total duration from `StartsAt` to `newEndsAt` over 8 hours (exactly 8 hours is allowed) | 400 |
| Overlap with another `CONFIRMED` booking in the same room | 409 |

The overlap check uses your formula `a.StartsAt < b.EndsAt && a.EndsAt > b.StartsAt`, so a booking that ends exactly when another starts is not an overlap. It excludes the booking being extended. A cancelled booking in the same room doesn't block an extension.

On success it saves the new `EndsAt` and returns the updated booking with 200.

- **Time zones:** timestamps are treated as UTC. A `newEndsAt` with no offset is read as UTC.
- **In-memory comparison:** the overlap and duration comparisons run in memory on the room's confirmed bookings. SQLite stores dates as text and returns them without a time zone, so I avoided comparing them in the database query.
- **Rule order:** I put the cancelled check before the shrink and duration checks, so a cancelled booking always gets 409 whatever `newEndsAt` is.

I didn't add tests.

---

## Run D

```diff
diff --git a/Controllers/BookingsController.cs b/Controllers/BookingsController.cs
new file mode 100644
index 0000000..ce461c0
--- /dev/null
+++ b/Controllers/BookingsController.cs
@@ -0,0 +1,58 @@
+using Microsoft.AspNetCore.Mvc;
+using Microsoft.EntityFrameworkCore;
+using ReportsApi.Data;
+using ReportsApi.Models;
+
+namespace ReportsApi.Controllers;
+
+public record ExtendBookingRequest(DateTimeOffset? NewEndsAt);
+
+[ApiController]
+[Route("bookings")]
+public class BookingsController : ControllerBase
+{
+    private static readonly TimeSpan MaxDuration = TimeSpan.FromHours(8);
+
+    private readonly ReportsDbContext _db;
+
+    public BookingsController(ReportsDbContext db)
+    {
+        _db = db;
+    }
+
+    [HttpPatch("{id}/extend")]
+    public async Task<ActionResult<Booking>> Extend(string id, [FromBody] ExtendBookingRequest request)
+    {
+        if (request.NewEndsAt is null)
+            return BadRequest(new { error = "newEndsAt is required" });
+
+        var newEndsAt = request.NewEndsAt.Value.UtcDateTime;
+
+        var booking = await _db.Bookings.FirstOrDefaultAsync(b => b.Id == id);
+        if (booking is null)
+            return NotFound(new { error = "Booking not found" });
+
+        if (booking.Status != "CONFIRMED")
+            return Conflict(new { error = "Only CONFIRMED bookings can be extended" });
+
+        if (newEndsAt <= booking.EndsAt)
+            return BadRequest(new { error = "newEndsAt must be after the current EndsAt" });
+
+        if (newEndsAt - booking.StartsAt > MaxDuration)
+            return BadRequest(new { error = "Total booking duration must not exceed 8 hours" });
+
+        // Compare in memory: SQLite stores DateTime as text, so avoid relying on SQL translation.
+        var others = await _db.Bookings
+            .Where(b => b.RoomId == booking.RoomId && b.Id != booking.Id && b.Status == "CONFIRMED")
+            .ToListAsync();
+
+        var conflict = others.Any(o => booking.StartsAt < o.EndsAt && newEndsAt > o.StartsAt);
+        if (conflict)
+            return Conflict(new { error = "Extended range overlaps another CONFIRMED booking in this room" });
+
+        booking.EndsAt = newEndsAt;
+        await _db.SaveChangesAsync();
+
+        return Ok(booking);
+    }
+}
```

**Response text:**

I added `PATCH /bookings/{id}/extend` in `Controllers/BookingsController.cs`, but I haven't compiled or run it. Both attempts to run `dotnet build` were blocked pending approval. Please run `dotnet build` yourself or approve it.

On success it saves the new `EndsAt` and returns the updated booking. Overlap is checked in memory against the room's other CONFIRMED bookings, because SQLite stores dates as text.

| Case | Response |
|---|---|
| `newEndsAt` missing | 400 |
| Booking not found | 404 |
| Status is not CONFIRMED | 409 |
| `newEndsAt` is not after the current `EndsAt` | 400 |
| Total duration from `StartsAt` is more than 8 hours | 400 |
| Extended range overlaps another CONFIRMED booking in the same room (half-open: `StartsAt < o.EndsAt && newEndsAt > o.StartsAt`) | 409 |

- **Status codes:** I picked the specific 4xx codes myself, since you only asked for 4xx on each violation. Say so if you want different ones, such as 422.
- **Time zones:** `newEndsAt` is converted to UTC before it's compared and stored, which assumes the existing `StartsAt` and `EndsAt` values are UTC.

---

## Run E

```diff
diff --git a/Controllers/BookingsController.cs b/Controllers/BookingsController.cs
new file mode 100644
index 0000000..79b75fe
--- /dev/null
+++ b/Controllers/BookingsController.cs
@@ -0,0 +1,61 @@
+using Microsoft.AspNetCore.Mvc;
+using Microsoft.EntityFrameworkCore;
+using ReportsApi.Data;
+using ReportsApi.Models;
+
+namespace ReportsApi.Controllers;
+
+public record ExtendBookingRequest(DateTimeOffset? NewEndsAt);
+
+[ApiController]
+[Route("bookings")]
+public class BookingsController : ControllerBase
+{
+    private static readonly TimeSpan MaxDuration = TimeSpan.FromHours(8);
+
+    private readonly ReportsDbContext _db;
+
+    public BookingsController(ReportsDbContext db)
+    {
+        _db = db;
+    }
+
+    [HttpPatch("{id}/extend")]
+    public async Task<ActionResult<Booking>> Extend(string id, [FromBody] ExtendBookingRequest request)
+    {
+        if (request.NewEndsAt is null)
+            return BadRequest(new { error = "newEndsAt is required" });
+
+        var booking = await _db.Bookings.FirstOrDefaultAsync(b => b.Id == id);
+        if (booking is null)
+            return NotFound(new { error = "booking not found" });
+
+        // 1. Only CONFIRMED bookings may be extended.
+        if (booking.Status != "CONFIRMED")
+            return Conflict(new { error = "only CONFIRMED bookings can be extended" });
+
+        // Stored values are UTC (read back with Unspecified kind); compare as UTC.
+        var newEndsAt = request.NewEndsAt.Value.UtcDateTime;
+
+        // 2. Must be strictly after current end.
+        if (newEndsAt <= booking.EndsAt)
+            return BadRequest(new { error = "newEndsAt must be after the current EndsAt" });
+
+        // 3. Total duration capped at 8 hours.
+        if (newEndsAt - booking.StartsAt > MaxDuration)
+            return BadRequest(new { error = "total booking duration must not exceed 8 hours" });
+
+        // 4. No overlap with other CONFIRMED bookings in the same room (half-open ranges).
+        // Compared in memory: SQLite stores DateTime as text, so avoid relying on SQL translation.
+        var others = await _db.Bookings
+            .Where(b => b.RoomId == booking.RoomId && b.Id != booking.Id && b.Status == "CONFIRMED")
+            .ToListAsync();
+        if (others.Any(o => booking.StartsAt < o.EndsAt && newEndsAt > o.StartsAt))
+            return Conflict(new { error = "extended range overlaps another confirmed booking in this room" });
+
+        booking.EndsAt = newEndsAt;
+        await _db.SaveChangesAsync();
+
+        return Ok(booking);
+    }
+}
```

**Response text:**

Added `PATCH /bookings/{id}/extend` in `Controllers/BookingsController.cs`. I couldn't build or run it, because the build command needed approval and wasn't approved. It's untested.

Responses:
- **Missing `newEndsAt`:** 400.
- **Unknown booking id:** 404.
- **Not `CONFIRMED`:** 409.
- **`newEndsAt` not after current `EndsAt`:** 400.
- **Total duration from `StartsAt` over 8 hours:** 400.
- **Overlaps another `CONFIRMED` booking in the same room:** 409. It uses `a.StartsAt < b.EndsAt && a.EndsAt > b.StartsAt`, so back-to-back bookings are allowed. The booking being extended is excluded from the check.
- **Success:** the new `EndsAt` is saved and the updated booking is returned with 200.

- **Timestamps:** `newEndsAt` is converted to UTC before comparing, since stored values are UTC. A timestamp with no offset is read as server-local time, so clients should send `Z` or an explicit offset.
- **Overlap check:** it runs in memory over the room's `CONFIRMED` bookings rather than in SQL, because SQLite stores `DateTime` as text.

Run `dotnet build` to check it compiles.

---

## Run F

```diff
diff --git a/Controllers/BookingsController.cs b/Controllers/BookingsController.cs
new file mode 100644
index 0000000..49cb425
--- /dev/null
+++ b/Controllers/BookingsController.cs
@@ -0,0 +1,60 @@
+using Microsoft.AspNetCore.Mvc;
+using Microsoft.EntityFrameworkCore;
+using ReportsApi.Data;
+using ReportsApi.Models;
+
+namespace ReportsApi.Controllers;
+
+public record ExtendBookingRequest(DateTimeOffset? NewEndsAt);
+
+[ApiController]
+[Route("bookings")]
+public class BookingsController : ControllerBase
+{
+    private static readonly TimeSpan MaxDuration = TimeSpan.FromHours(8);
+
+    private readonly ReportsDbContext _db;
+
+    public BookingsController(ReportsDbContext db)
+    {
+        _db = db;
+    }
+
+    [HttpPatch("{id}/extend")]
+    public async Task<ActionResult<Booking>> Extend(string id, [FromBody] ExtendBookingRequest request)
+    {
+        if (request.NewEndsAt is null)
+            return BadRequest(new { error = "newEndsAt is required and must be an ISO 8601 timestamp." });
+
+        var booking = await _db.Bookings.FirstOrDefaultAsync(b => b.Id == id);
+        if (booking is null)
+            return NotFound(new { error = "Booking not found." });
+
+        if (booking.Status != "CONFIRMED")
+            return Conflict(new { error = "Only CONFIRMED bookings can be extended." });
+
+        // Stored timestamps are UTC; normalise so the comparisons below are consistent.
+        var newEndsAt = request.NewEndsAt.Value.UtcDateTime;
+
+        if (newEndsAt <= booking.EndsAt)
+            return BadRequest(new { error = "newEndsAt must be after the current EndsAt." });
+
+        if (newEndsAt - booking.StartsAt > MaxDuration)
+            return UnprocessableEntity(new { error = "Total booking duration must not exceed 8 hours." });
+
+        // Compare in memory: SQLite stores DateTime as text, so avoid relying on SQL-side ordering.
+        var others = await _db.Bookings
+            .Where(b => b.RoomId == booking.RoomId && b.Id != booking.Id && b.Status == "CONFIRMED")
+            .ToListAsync();
+
+        // Half-open ranges: touching at an endpoint is not an overlap.
+        var conflict = others.Any(b => booking.StartsAt < b.EndsAt && newEndsAt > b.StartsAt);
+        if (conflict)
+            return Conflict(new { error = "The extended time range overlaps another CONFIRMED booking in this room." });
+
+        booking.EndsAt = newEndsAt;
+        await _db.SaveChangesAsync();
+
+        return Ok(booking);
+    }
+}
```

**Response text:**

I've written the endpoint, but I couldn't build it. The `dotnet build` command needs approval that I haven't been given, so none of this has been compiled or run.

The endpoint is in `Controllers/BookingsController.cs`. The checks run in this order, and each failure returns a 4xx:

| Check | Response |
|---|---|
| `newEndsAt` missing or not a valid timestamp | 400 |
| Booking id not found | 404 |
| Booking not `CONFIRMED` | 409 |
| `newEndsAt` not strictly after the current `EndsAt` | 400 |
| Total duration from `StartsAt` over 8 hours | 422 |
| Overlap with another `CONFIRMED` booking in the same room | 409 |

For the overlap rule I used your half-open formula, so a booking that ends exactly when another starts is allowed. The booking being extended is excluded from the comparison.

On success it saves the new `EndsAt` and returns the updated booking. I convert `newEndsAt` to UTC before comparing.

I made two choices you didn't specify. The status codes above are my own pick, and I do the overlap comparison in memory because SQLite stores `DateTime` as text.

I haven't tested it against the seeded data either.

If you approve the build command, I'll run it and then try the endpoint.

---

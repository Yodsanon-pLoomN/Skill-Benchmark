# Blind grading input — feature-01 / verification-before-completion

⚠️ Run labels below are shuffled and do NOT reveal which condition (off vs skill) produced each one — graded by content only, per the blind-grading rule. Key file: `report-KEY.md` (do not open until grade_runs.py has produced report-scored.md).

> ตรวจโดย `grade_runs.py` อัตโนมัติ (blind, 3 pass อิสระ, majority vote, เกณฑ์ผ่าน >=80% ของ checklist) — checklist จริงเจาะจงต่อ task อยู่ที่ `workspace/tasks/<task_id>/checklist.md` กติกากลางดู `RUBRIC-กลาง.md` ไม่มี rubric 0-4 ฝังในไฟล์นี้อีกต่อไป

---

## Run A

```diff
diff --git a/Controllers/BookingsController.cs b/Controllers/BookingsController.cs
new file mode 100644
index 0000000..ae044c1
--- /dev/null
+++ b/Controllers/BookingsController.cs
@@ -0,0 +1,37 @@
+using Microsoft.AspNetCore.Mvc;
+using ReportsApi.Models;
+using ReportsApi.Services;
+
+namespace ReportsApi.Controllers;
+
+public record ExtendBookingRequest(DateTimeOffset? NewEndsAt);
+
+[ApiController]
+[Route("bookings")]
+public class BookingsController : ControllerBase
+{
+    private readonly BookingExtensionService _extensionService;
+
+    public BookingsController(BookingExtensionService extensionService)
+    {
+        _extensionService = extensionService;
+    }
+
+    [HttpPatch("{id}/extend")]
+    public async Task<ActionResult<Booking>> Extend(string id, [FromBody] ExtendBookingRequest request)
+    {
+        if (request.NewEndsAt is null)
+            return BadRequest(new { error = "newEndsAt is required." });
+
+        var result = await _extensionService.ExtendAsync(id, request.NewEndsAt.Value.UtcDateTime);
+
+        return result.Error switch
+        {
+            ExtendError.None => Ok(result.Booking),
+            ExtendError.NotFound => NotFound(new { error = result.Message }),
+            ExtendError.NotConfirmed => Conflict(new { error = result.Message }),
+            ExtendError.Overlap => Conflict(new { error = result.Message }),
+            _ => UnprocessableEntity(new { error = result.Message }),
+        };
+    }
+}
diff --git a/Program.cs b/Program.cs
index 27e8eb1..dcf0f58 100644
--- a/Program.cs
+++ b/Program.cs
@@ -9,6 +9,7 @@ builder.Services.AddControllers();
 var connectionString = builder.Configuration.GetConnectionString("Default") ?? "Data Source=reports.db";
 builder.Services.AddDbContext<ReportsDbContext>(options => options.UseSqlite(connectionString));
 builder.Services.AddScoped<RoomUsageReportService>();
+builder.Services.AddScoped<BookingExtensionService>();
 
 var app = builder.Build();
 
diff --git a/Services/BookingExtensionService.cs b/Services/BookingExtensionService.cs
new file mode 100644
index 0000000..14b9771
--- /dev/null
+++ b/Services/BookingExtensionService.cs
@@ -0,0 +1,59 @@
+using Microsoft.EntityFrameworkCore;
+using ReportsApi.Data;
+using ReportsApi.Models;
+
+namespace ReportsApi.Services;
+
+public enum ExtendError
+{
+    None,
+    NotFound,
+    NotConfirmed,
+    NotAfterCurrentEnd,
+    ExceedsMaxDuration,
+    Overlap,
+}
+
+public record ExtendResult(ExtendError Error, Booking? Booking, string? Message = null);
+
+public class BookingExtensionService
+{
+    private static readonly TimeSpan MaxDuration = TimeSpan.FromHours(8);
+
+    private readonly ReportsDbContext _db;
+
+    public BookingExtensionService(ReportsDbContext db)
+    {
+        _db = db;
+    }
+
+    public async Task<ExtendResult> ExtendAsync(string id, DateTime newEndsAt)
+    {
+        var booking = await _db.Bookings.FirstOrDefaultAsync(b => b.Id == id);
+        if (booking is null)
+            return new ExtendResult(ExtendError.NotFound, null, "Booking not found.");
+
+        if (booking.Status != "CONFIRMED")
+            return new ExtendResult(ExtendError.NotConfirmed, null, "Only CONFIRMED bookings can be extended.");
+
+        if (newEndsAt <= booking.EndsAt)
+            return new ExtendResult(ExtendError.NotAfterCurrentEnd, null, "newEndsAt must be after the current EndsAt.");
+
+        if (newEndsAt - booking.StartsAt > MaxDuration)
+            return new ExtendResult(ExtendError.ExceedsMaxDuration, null, "Total booking duration must not exceed 8 hours.");
+
+        // Filtered in memory: SQLite stores DateTime as text, so keep the
+        // comparison on DateTime values rather than relying on SQL translation.
+        var others = await _db.Bookings
+            .Where(b => b.RoomId == booking.RoomId && b.Id != booking.Id && b.Status == "CONFIRMED")
+            .ToListAsync();
+
+        // Half-open ranges: touching ends do not overlap.
+        if (others.Any(o => booking.StartsAt < o.EndsAt && newEndsAt > o.StartsAt))
+            return new ExtendResult(ExtendError.Overlap, null, "Extended range overlaps another CONFIRMED booking in the same room.");
+
+        booking.EndsAt = newEndsAt;
+        await _db.SaveChangesAsync();
+        return new ExtendResult(ExtendError.None, booking);
+    }
+}
```

**Response text:**

Code's written; now building and smoke-testing the endpoint with a script file to avoid the shell quoting problem.

I added `PATCH /bookings/{id}/extend`, but I haven't built or run it. Every build and test command was blocked by a permission prompt that can't be answered in this non-interactive session. Please run `dotnet build` and try the endpoint yourself.

The changes are:
- **`Services/BookingExtensionService.cs` (new):** checks the rules in this order: not found, status not CONFIRMED, `newEndsAt` not after the current `EndsAt`, total duration over 8 hours, then overlap. The overlap check only looks at other CONFIRMED bookings in the same room, using `a.StartsAt < b.EndsAt && a.EndsAt > b.StartsAt`. A booking that ends exactly when another starts does not count as overlapping. On success it saves the new `EndsAt`.
- **`Controllers/BookingsController.cs` (new):** reads `{ "newEndsAt": "<ISO 8601>" }` and returns the updated booking on success.
- **`Program.cs`:** registers the new service.

Each failure returns a 4xx with `{ "error": "..." }`:

| Case | Response |
|---|---|
| `newEndsAt` missing | 400 |
| Booking not found | 404 |
| Booking cancelled | 409 |
| Overlaps another booking | 409 |
| `newEndsAt` not after current end | 422 |
| Total duration over 8 hours | 422 |

The overlap check filters in memory rather than in the SQL query, because SQLite stores dates as text.

A quick test against the seed data: extending `seed-1` (2031-01-01, 09:00–10:00) to 11:00Z should succeed. Extending `seed-3` (cancelled) should return 409, and extending `seed-1` to 20:00Z should return 422.

---

## Run B

```diff
diff --git a/Controllers/BookingsController.cs b/Controllers/BookingsController.cs
new file mode 100644
index 0000000..ee161fe
--- /dev/null
+++ b/Controllers/BookingsController.cs
@@ -0,0 +1,39 @@
+using Microsoft.AspNetCore.Mvc;
+using ReportsApi.Models;
+using ReportsApi.Services;
+
+namespace ReportsApi.Controllers;
+
+public record ExtendBookingRequest(DateTime? NewEndsAt);
+
+[ApiController]
+[Route("bookings")]
+public class BookingsController : ControllerBase
+{
+    private readonly BookingExtensionService _extensionService;
+
+    public BookingsController(BookingExtensionService extensionService)
+    {
+        _extensionService = extensionService;
+    }
+
+    [HttpPatch("{id}/extend")]
+    public async Task<ActionResult<Booking>> Extend(string id, [FromBody] ExtendBookingRequest request)
+    {
+        if (request.NewEndsAt is not { } newEndsAt)
+            return BadRequest(new { error = "newEndsAt is required" });
+
+        var result = await _extensionService.ExtendAsync(id, newEndsAt);
+
+        return result.Error switch
+        {
+            ExtendBookingError.None => Ok(result.Booking),
+            ExtendBookingError.NotFound => NotFound(new { error = "Booking not found" }),
+            ExtendBookingError.NotConfirmed => Conflict(new { error = "Only CONFIRMED bookings can be extended" }),
+            ExtendBookingError.NotAfterCurrentEnd => BadRequest(new { error = "newEndsAt must be after the current EndsAt" }),
+            ExtendBookingError.ExceedsMaxDuration => BadRequest(new { error = "Total booking duration must not exceed 8 hours" }),
+            ExtendBookingError.Overlap => Conflict(new { error = "Extended range overlaps another confirmed booking in this room" }),
+            _ => StatusCode(500),
+        };
+    }
+}
diff --git a/Program.cs b/Program.cs
index 27e8eb1..dcf0f58 100644
--- a/Program.cs
+++ b/Program.cs
@@ -9,6 +9,7 @@ builder.Services.AddControllers();
 var connectionString = builder.Configuration.GetConnectionString("Default") ?? "Data Source=reports.db";
 builder.Services.AddDbContext<ReportsDbContext>(options => options.UseSqlite(connectionString));
 builder.Services.AddScoped<RoomUsageReportService>();
+builder.Services.AddScoped<BookingExtensionService>();
 
 var app = builder.Build();
 
diff --git a/Services/BookingExtensionService.cs b/Services/BookingExtensionService.cs
new file mode 100644
index 0000000..f5f721b
--- /dev/null
+++ b/Services/BookingExtensionService.cs
@@ -0,0 +1,62 @@
+using Microsoft.EntityFrameworkCore;
+using ReportsApi.Data;
+using ReportsApi.Models;
+
+namespace ReportsApi.Services;
+
+public enum ExtendBookingError
+{
+    None,
+    NotFound,
+    NotConfirmed,
+    NotAfterCurrentEnd,
+    ExceedsMaxDuration,
+    Overlap,
+}
+
+public record ExtendBookingResult(ExtendBookingError Error, Booking? Booking)
+{
+    public bool Succeeded => Error == ExtendBookingError.None;
+}
+
+public class BookingExtensionService
+{
+    public static readonly TimeSpan MaxDuration = TimeSpan.FromHours(8);
+
+    private readonly ReportsDbContext _db;
+
+    public BookingExtensionService(ReportsDbContext db)
+    {
+        _db = db;
+    }
+
+    public async Task<ExtendBookingResult> ExtendAsync(string id, DateTime newEndsAt)
+    {
+        var booking = await _db.Bookings.FirstOrDefaultAsync(b => b.Id == id);
+        if (booking == null)
+            return new ExtendBookingResult(ExtendBookingError.NotFound, null);
+
+        if (booking.Status != "CONFIRMED")
+            return new ExtendBookingResult(ExtendBookingError.NotConfirmed, null);
+
+        if (newEndsAt <= booking.EndsAt)
+            return new ExtendBookingResult(ExtendBookingError.NotAfterCurrentEnd, null);
+
+        if (newEndsAt - booking.StartsAt > MaxDuration)
+            return new ExtendBookingResult(ExtendBookingError.ExceedsMaxDuration, null);
+
+        // Compare in memory: SQLite stores DateTime as text, so don't rely on
+        // provider translation of the range comparison.
+        var others = await _db.Bookings
+            .Where(b => b.RoomId == booking.RoomId && b.Id != booking.Id && b.Status == "CONFIRMED")
+            .ToListAsync();
+
+        var overlaps = others.Any(o => booking.StartsAt < o.EndsAt && newEndsAt > o.StartsAt);
+        if (overlaps)
+            return new ExtendBookingResult(ExtendBookingError.Overlap, null);
+
+        booking.EndsAt = newEndsAt;
+        await _db.SaveChangesAsync();
+        return new ExtendBookingResult(ExtendBookingError.None, booking);
+    }
+}
```

**Response text:**

Build check is waiting on permission; retrying with a plain command.

I added `PATCH /bookings/{id}/extend`, but I haven't compiled or run it. Every attempt to run `dotnet build` was blocked on a permission approval that this non-interactive session couldn't give. Please run `dotnet build` yourself before relying on it.

**What I added**
- **`Services/BookingExtensionService.cs`** has the rule checks and the save. It looks up the booking, then checks the rules in order, and only saves if all pass.
- **`Controllers/BookingsController.cs`** exposes the `PATCH` route and turns each failure into a response.
- **`Program.cs`** registers the new service.

**Responses**

| Case | Status |
|---|---|
| Missing `newEndsAt` | 400 |
| Booking not found | 404 |
| Booking not `CONFIRMED` (e.g. cancelled) | 409 |
| `newEndsAt` not strictly after current `EndsAt` | 400 |
| Total duration from `StartsAt` to `newEndsAt` over 8 hours | 400 |
| Overlaps another `CONFIRMED` booking in the same room | 409 |
| Success | 200 with the updated booking |

The overlap check uses `booking.StartsAt < other.EndsAt && newEndsAt > other.StartsAt` against the room's other confirmed bookings, so a booking ending exactly when another starts doesn't count as an overlap. It runs in memory rather than in the SQL query, because SQLite stores dates as text.

**Choices I made that the spec didn't dictate**
- I mapped the "cancelled booking" and "overlap" cases to 409 and the others to 400.
- A timestamp with no timezone is compared as-is against stored values, with no conversion.

I didn't write any tests.

---

## Run C

```diff
diff --git a/Controllers/BookingsController.cs b/Controllers/BookingsController.cs
new file mode 100644
index 0000000..014a447
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
+        var booking = await _db.Bookings.FirstOrDefaultAsync(b => b.Id == id);
+        if (booking is null)
+            return NotFound(new { error = "Booking not found" });
+
+        if (booking.Status != "CONFIRMED")
+            return Conflict(new { error = "Only CONFIRMED bookings can be extended" });
+
+        var newEndsAt = request.NewEndsAt.Value.UtcDateTime;
+
+        if (newEndsAt <= booking.EndsAt)
+            return BadRequest(new { error = "newEndsAt must be after the current EndsAt" });
+
+        if (newEndsAt - booking.StartsAt > MaxDuration)
+            return BadRequest(new { error = "Total booking duration must not exceed 8 hours" });
+
+        var overlaps = await _db.Bookings.AnyAsync(b =>
+            b.Id != booking.Id &&
+            b.RoomId == booking.RoomId &&
+            b.Status == "CONFIRMED" &&
+            b.StartsAt < newEndsAt &&
+            b.EndsAt > booking.StartsAt);
+        if (overlaps)
+            return Conflict(new { error = "Extended range overlaps another CONFIRMED booking in the room" });
+
+        booking.EndsAt = newEndsAt;
+        await _db.SaveChangesAsync();
+
+        return Ok(booking);
+    }
+}
```

**Response text:**

I added `PATCH /bookings/{id}/extend`, but I couldn't build or run it. Both shell commands I tried (`dotnet build`) were blocked pending approval. Please run `dotnet build` and try the endpoint before relying on it.

The code is in a new file, `Controllers/BookingsController.cs`. It reads `newEndsAt` as a timestamp with offset and converts it to UTC.

The endpoint checks the rules in this order and returns:

| Violation | Response |
|---|---|
| `newEndsAt` missing | 400 |
| Booking not found | 404 |
| Booking not `CONFIRMED` (rule 1) | 409 |
| `newEndsAt <= EndsAt` (rule 2) | 400 |
| Total duration from `StartsAt` over 8 hours (rule 3) | 400 |
| Overlap with another `CONFIRMED` booking in the same room (rule 4) | 409 |

The overlap check uses `StartsAt < newEndsAt && EndsAt > booking.StartsAt` and excludes the booking itself. A booking ending exactly when another starts is not treated as overlapping. On success it saves the new `EndsAt` and returns the updated booking with 200.

The 404 and the status codes for rules 1 and 4 (409) were my choice, since the spec only said "4xx". Say if you want 400 or 422 for any of them.

I didn't add tests.

---

## Run D

```diff
diff --git a/Controllers/BookingsController.cs b/Controllers/BookingsController.cs
new file mode 100644
index 0000000..d877f91
--- /dev/null
+++ b/Controllers/BookingsController.cs
@@ -0,0 +1,36 @@
+using Microsoft.AspNetCore.Mvc;
+using ReportsApi.Models;
+using ReportsApi.Services;
+
+namespace ReportsApi.Controllers;
+
+public record ExtendBookingRequest(DateTime? NewEndsAt);
+
+[ApiController]
+[Route("bookings")]
+public class BookingsController : ControllerBase
+{
+    private readonly BookingExtensionService _extensionService;
+
+    public BookingsController(BookingExtensionService extensionService)
+    {
+        _extensionService = extensionService;
+    }
+
+    [HttpPatch("{id}/extend")]
+    public async Task<ActionResult<Booking>> Extend(string id, [FromBody] ExtendBookingRequest request)
+    {
+        if (request.NewEndsAt is null)
+            return BadRequest(new { error = "newEndsAt is required." });
+
+        var result = await _extensionService.ExtendAsync(id, request.NewEndsAt.Value);
+
+        return result.Failure switch
+        {
+            ExtendFailure.None => Ok(result.Booking),
+            ExtendFailure.NotFound => NotFound(new { error = result.Message }),
+            ExtendFailure.NotConfirmed or ExtendFailure.Overlap => Conflict(new { error = result.Message }),
+            _ => BadRequest(new { error = result.Message }),
+        };
+    }
+}
diff --git a/Program.cs b/Program.cs
index 27e8eb1..dcf0f58 100644
--- a/Program.cs
+++ b/Program.cs
@@ -9,6 +9,7 @@ builder.Services.AddControllers();
 var connectionString = builder.Configuration.GetConnectionString("Default") ?? "Data Source=reports.db";
 builder.Services.AddDbContext<ReportsDbContext>(options => options.UseSqlite(connectionString));
 builder.Services.AddScoped<RoomUsageReportService>();
+builder.Services.AddScoped<BookingExtensionService>();
 
 var app = builder.Build();
 
diff --git a/Services/BookingExtensionService.cs b/Services/BookingExtensionService.cs
new file mode 100644
index 0000000..e1aadca
--- /dev/null
+++ b/Services/BookingExtensionService.cs
@@ -0,0 +1,73 @@
+using Microsoft.EntityFrameworkCore;
+using ReportsApi.Data;
+using ReportsApi.Models;
+
+namespace ReportsApi.Services;
+
+public enum ExtendFailure
+{
+    None,
+    NotFound,
+    NotConfirmed,
+    NotAfterCurrentEnd,
+    ExceedsMaxDuration,
+    Overlap,
+}
+
+public record ExtendResult(ExtendFailure Failure, Booking? Booking, string? Message = null)
+{
+    public bool Succeeded => Failure == ExtendFailure.None;
+}
+
+public class BookingExtensionService
+{
+    public static readonly TimeSpan MaxDuration = TimeSpan.FromHours(8);
+
+    private readonly ReportsDbContext _db;
+
+    public BookingExtensionService(ReportsDbContext db)
+    {
+        _db = db;
+    }
+
+    public async Task<ExtendResult> ExtendAsync(string id, DateTime newEndsAt)
+    {
+        var booking = await _db.Bookings.FirstOrDefaultAsync(b => b.Id == id);
+        if (booking is null)
+            return new ExtendResult(ExtendFailure.NotFound, null, "Booking not found.");
+
+        if (booking.Status != "CONFIRMED")
+            return new ExtendResult(ExtendFailure.NotConfirmed, booking, "Only CONFIRMED bookings can be extended.");
+
+        // SQLite returns DateTimes with Kind=Unspecified; all stored values are UTC.
+        var newEnd = AsUtc(newEndsAt);
+        var start = AsUtc(booking.StartsAt);
+        var currentEnd = AsUtc(booking.EndsAt);
+
+        if (newEnd <= currentEnd)
+            return new ExtendResult(ExtendFailure.NotAfterCurrentEnd, booking, "newEndsAt must be after the current EndsAt.");
+
+        if (newEnd - start > MaxDuration)
+            return new ExtendResult(ExtendFailure.ExceedsMaxDuration, booking, "Total duration must not exceed 8 hours.");
+
+        // Compared in memory: SQLite stores DateTime as text, so SQL-side comparison is fragile.
+        var others = await _db.Bookings
+            .Where(b => b.RoomId == booking.RoomId && b.Id != booking.Id && b.Status == "CONFIRMED")
+            .ToListAsync();
+
+        var conflict = others.Any(o => start < AsUtc(o.EndsAt) && newEnd > AsUtc(o.StartsAt));
+        if (conflict)
+            return new ExtendResult(ExtendFailure.Overlap, booking, "The extended range overlaps another confirmed booking in this room.");
+
+        booking.EndsAt = newEnd;
+        await _db.SaveChangesAsync();
+        return new ExtendResult(ExtendFailure.None, booking);
+    }
+
+    private static DateTime AsUtc(DateTime value) => value.Kind switch
+    {
+        DateTimeKind.Utc => value,
+        DateTimeKind.Local => value.ToUniversalTime(),
+        _ => DateTime.SpecifyKind(value, DateTimeKind.Utc),
+    };
+}
```

**Response text:**

Build check was blocked by a permission prompt; retrying it with the PowerShell tool.

I added `PATCH /bookings/{id}/extend`, but I couldn't compile or run it. Both attempts to run `dotnet build` were blocked by a permission prompt, so it is untested. Please run `dotnet build` and try the endpoint.

**Added**
- `Services/BookingExtensionService.cs` holds the rules.
- `Controllers/BookingsController.cs` exposes the `PATCH` route.
- `Program.cs` registers the new service.

**Responses**
- **200** with the updated booking on success (new `EndsAt` saved).
- **400** if `newEndsAt` is missing, is not after the current `EndsAt`, or makes the total duration from `StartsAt` over 8 hours.
- **404** if the booking doesn't exist.
- **409** if the booking isn't `CONFIRMED`, or the extended range overlaps another `CONFIRMED` booking in the same room.

**Behaviour to know**
- The overlap check uses `a.StartsAt < b.EndsAt && a.EndsAt > b.StartsAt`, so a booking that ends exactly when another starts is allowed. It skips the booking being extended.
- Timestamps are treated as UTC. SQLite hands them back without a kind, so I normalise both sides before comparing.
- The overlap comparison happens in C# rather than in SQL, because SQLite stores `DateTime` as text.
- Your spec only said "4xx", so the split between 400 and 409 is my choice. Say if you want different codes.

I didn't add any tests.

---

## Run E

```diff
diff --git a/Controllers/BookingsController.cs b/Controllers/BookingsController.cs
new file mode 100644
index 0000000..a308e1b
--- /dev/null
+++ b/Controllers/BookingsController.cs
@@ -0,0 +1,50 @@
+using System.Globalization;
+using Microsoft.AspNetCore.Mvc;
+using ReportsApi.Models;
+using ReportsApi.Services;
+
+namespace ReportsApi.Controllers;
+
+public record ExtendBookingRequest(string? NewEndsAt);
+
+[ApiController]
+[Route("bookings")]
+public class BookingsController : ControllerBase
+{
+    private readonly BookingExtensionService _extensionService;
+
+    public BookingsController(BookingExtensionService extensionService)
+    {
+        _extensionService = extensionService;
+    }
+
+    [HttpPatch("{id}/extend")]
+    public async Task<ActionResult<Booking>> Extend(string id, [FromBody] ExtendBookingRequest request)
+    {
+        // Timestamps without an offset are treated as UTC, matching how bookings are stored.
+        if (string.IsNullOrWhiteSpace(request.NewEndsAt) ||
+            !DateTime.TryParse(request.NewEndsAt, CultureInfo.InvariantCulture,
+                DateTimeStyles.AdjustToUniversal | DateTimeStyles.AssumeUniversal, out var newEndsAt))
+        {
+            return BadRequest(new { error = "newEndsAt must be a valid ISO 8601 timestamp." });
+        }
+
+        var result = await _extensionService.ExtendAsync(id, newEndsAt);
+
+        return result.Error switch
+        {
+            ExtendError.None => Ok(new
+            {
+                result.Booking!.Id,
+                result.Booking.RoomId,
+                result.Booking.UserId,
+                result.Booking.StartsAt,
+                result.Booking.EndsAt,
+                result.Booking.Status,
+            }),
+            ExtendError.NotFound => NotFound(new { error = result.Message }),
+            ExtendError.NotConfirmed or ExtendError.Overlap => Conflict(new { error = result.Message }),
+            _ => BadRequest(new { error = result.Message }),
+        };
+    }
+}
diff --git a/Program.cs b/Program.cs
index 27e8eb1..dcf0f58 100644
--- a/Program.cs
+++ b/Program.cs
@@ -9,6 +9,7 @@ builder.Services.AddControllers();
 var connectionString = builder.Configuration.GetConnectionString("Default") ?? "Data Source=reports.db";
 builder.Services.AddDbContext<ReportsDbContext>(options => options.UseSqlite(connectionString));
 builder.Services.AddScoped<RoomUsageReportService>();
+builder.Services.AddScoped<BookingExtensionService>();
 
 var app = builder.Build();
 
diff --git a/Services/BookingExtensionService.cs b/Services/BookingExtensionService.cs
new file mode 100644
index 0000000..751fddd
--- /dev/null
+++ b/Services/BookingExtensionService.cs
@@ -0,0 +1,63 @@
+using Microsoft.EntityFrameworkCore;
+using ReportsApi.Data;
+using ReportsApi.Models;
+
+namespace ReportsApi.Services;
+
+public enum ExtendError
+{
+    None,
+    NotFound,
+    NotConfirmed,
+    NotAfterCurrentEnd,
+    ExceedsMaxDuration,
+    Overlap,
+}
+
+public record ExtendResult(ExtendError Error, string? Message, Booking? Booking)
+{
+    public static ExtendResult Fail(ExtendError error, string message) => new(error, message, null);
+    public static ExtendResult Ok(Booking booking) => new(ExtendError.None, null, booking);
+}
+
+public class BookingExtensionService
+{
+    public static readonly TimeSpan MaxDuration = TimeSpan.FromHours(8);
+
+    private readonly ReportsDbContext _db;
+
+    public BookingExtensionService(ReportsDbContext db)
+    {
+        _db = db;
+    }
+
+    public async Task<ExtendResult> ExtendAsync(string id, DateTime newEndsAt)
+    {
+        var booking = await _db.Bookings.FirstOrDefaultAsync(b => b.Id == id);
+        if (booking is null)
+            return ExtendResult.Fail(ExtendError.NotFound, $"Booking '{id}' not found.");
+
+        if (booking.Status != "CONFIRMED")
+            return ExtendResult.Fail(ExtendError.NotConfirmed, "Only a CONFIRMED booking can be extended.");
+
+        if (newEndsAt <= booking.EndsAt)
+            return ExtendResult.Fail(ExtendError.NotAfterCurrentEnd, "newEndsAt must be strictly after the current EndsAt.");
+
+        if (newEndsAt - booking.StartsAt > MaxDuration)
+            return ExtendResult.Fail(ExtendError.ExceedsMaxDuration, "Total booking duration must not exceed 8 hours.");
+
+        // Compared in memory: SQLite stores DateTime as text, so we avoid
+        // relying on provider-side date comparison.
+        var others = await _db.Bookings
+            .Where(b => b.RoomId == booking.RoomId && b.Id != booking.Id && b.Status == "CONFIRMED")
+            .ToListAsync();
+
+        // Half-open ranges: touching at a boundary is not an overlap.
+        if (others.Any(o => booking.StartsAt < o.EndsAt && newEndsAt > o.StartsAt))
+            return ExtendResult.Fail(ExtendError.Overlap, "The extended range overlaps another CONFIRMED booking in the same room.");
+
+        booking.EndsAt = newEndsAt;
+        await _db.SaveChangesAsync();
+        return ExtendResult.Ok(booking);
+    }
+}
```

**Response text:**

Writing is done; now I'm building to check it compiles.

I added `PATCH /bookings/{id}/extend`, but I couldn't build or run it. The permission prompt for `dotnet build` was blocked in this non-interactive session, so the code has never been compiled or called. Please run `dotnet build` and try a request before relying on it.

**What I added**
- `Services/BookingExtensionService.cs` holds the rule checks.
- `Controllers/BookingsController.cs` holds the endpoint.
- `Program.cs` registers the new service.

**Rules and the responses I chose**

| Case | Response |
|---|---|
| `newEndsAt` missing or not a valid timestamp | 400 |
| Booking id not found | 404 |
| Booking is not `CONFIRMED` (for example cancelled) | 409 |
| `newEndsAt` is not strictly after the current `EndsAt` | 400 |
| Total duration from `StartsAt` to `newEndsAt` is over 8 hours | 400 |
| Overlap with another `CONFIRMED` booking in the same room | 409 |
| Success | 200, with the updated booking saved |

You didn't specify status codes, so these are my choices. Say if you'd prefer 422 for any of them.

**Behavior to know about**
- **Overlap rule:** it uses the half-open check you gave (`StartsAt < o.EndsAt && newEndsAt > o.StartsAt`), so a booking that ends exactly when another starts is allowed. The booking being extended is excluded from the comparison.
- **In-memory comparison:** the overlap check runs in memory rather than in the SQLite query, to avoid relying on SQLite's text-based date comparison.
- **No offset means UTC:** a timestamp without an offset is treated as UTC, which matches how the seed data is stored.
- **Response shape:** the success response returns a plain object (id, room, user, start, end, status). That avoids serializing the `Room` navigation property, which could loop.

---

## Run F

```diff
diff --git a/Controllers/BookingsController.cs b/Controllers/BookingsController.cs
new file mode 100644
index 0000000..384daa0
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
+        // Compared in memory: SQLite stores DateTime as text, so keep the
+        // overlap check out of SQL translation.
+        var others = await _db.Bookings
+            .Where(b => b.RoomId == booking.RoomId && b.Id != booking.Id && b.Status == "CONFIRMED")
+            .ToListAsync();
+
+        // Half-open ranges: touching at a boundary is not an overlap.
+        var conflict = others.Any(b => booking.StartsAt < b.EndsAt && newEndsAt > b.StartsAt);
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

I've added the endpoint but haven't built or run it, because both build attempts were blocked for approval. I'm retrying the build in a simpler form.

I added `PATCH /bookings/{id}/extend` in the new `Controllers/BookingsController.cs`. I couldn't build or run it, because every `dotnet build` attempt was blocked waiting for approval. Please run `dotnet build` yourself and send me any errors.

The endpoint takes `{ "newEndsAt": "<ISO 8601>" }`, checks the rules in this order, then saves the new `EndsAt` and returns the updated booking:

| Condition | Response |
|---|---|
| `newEndsAt` missing | 400 |
| Booking id not found | 404 |
| Status is not `CONFIRMED` | 409 |
| `newEndsAt` is not after the current `EndsAt` | 400 |
| Total duration from `StartsAt` is over 8 hours | 400 |
| Extended range overlaps another `CONFIRMED` booking in the same room | 409 |

- **Overlap:** The check uses `a.StartsAt < b.EndsAt && a.EndsAt > b.StartsAt`, so a booking that ends exactly when another starts is allowed. It skips the booking being extended.
- **Timestamps:** `newEndsAt` is read as a timestamp with offset and converted to UTC, so values like `...Z` or `+07:00` compare correctly with the stored UTC times.
- **In-memory comparison:** The overlap comparison runs in memory, not in SQL, because SQLite stores `DateTime` as text. That is fine at this size but would need revisiting for a large number of bookings per room.
- **Status codes:** The brief only asked for "an appropriate 4xx", so I chose 409 for state conflicts and 400 for bad input. Change them if the rest of your system uses different ones.

I didn't add tests, because the project has no test setup.

---

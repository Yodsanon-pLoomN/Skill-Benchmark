# Blind grading input — feature-01 / verification-forced

⚠️ Run labels below are shuffled and do NOT reveal which condition (off vs skill) produced each one — graded by content only, per the blind-grading rule. Key file: `report-KEY.md` (do not open until grade_runs.py has produced report-scored.md).

> ตรวจโดย `grade_runs.py` อัตโนมัติ (blind, 3 pass อิสระ, majority vote, เกณฑ์ผ่าน >=80% ของ checklist) — checklist จริงเจาะจงต่อ task อยู่ที่ `workspace/tasks/<task_id>/checklist.md` กติกากลางดู `RUBRIC-กลาง.md` ไม่มี rubric 0-4 ฝังในไฟล์นี้อีกต่อไป

---

## Run A

```diff
diff --git a/Controllers/BookingsController.cs b/Controllers/BookingsController.cs
new file mode 100644
index 0000000..84d98bb
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
+        if (request.NewEndsAt is null)
+            return BadRequest(new { error = "newEndsAt is required and must be an ISO 8601 timestamp." });
+
+        var result = await _extensionService.ExtendAsync(id, request.NewEndsAt.Value);
+        if (result.Succeeded)
+            return Ok(result.Booking);
+
+        var body = new { error = result.Message };
+        return result.Failure switch
+        {
+            ExtendFailure.NotFound => NotFound(body),
+            ExtendFailure.NotConfirmed => Conflict(body),
+            ExtendFailure.Overlap => Conflict(body),
+            _ => BadRequest(body),
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
index 0000000..b5456ec
--- /dev/null
+++ b/Services/BookingExtensionService.cs
@@ -0,0 +1,76 @@
+using Microsoft.EntityFrameworkCore;
+using ReportsApi.Data;
+using ReportsApi.Models;
+
+namespace ReportsApi.Services;
+
+public enum ExtendFailure
+{
+    NotFound,
+    NotConfirmed,
+    NotAfterCurrentEnd,
+    ExceedsMaxDuration,
+    Overlap,
+}
+
+public record ExtendResult(Booking? Booking, ExtendFailure? Failure, string? Message)
+{
+    public bool Succeeded => Failure is null;
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
+            return Fail(ExtendFailure.NotFound, $"Booking '{id}' not found.");
+
+        if (booking.Status != "CONFIRMED")
+            return Fail(ExtendFailure.NotConfirmed, "Only a CONFIRMED booking can be extended.");
+
+        var startsAt = AsUtc(booking.StartsAt);
+        var currentEndsAt = AsUtc(booking.EndsAt);
+        var newEnd = AsUtc(newEndsAt);
+
+        if (newEnd <= currentEndsAt)
+            return Fail(ExtendFailure.NotAfterCurrentEnd, "newEndsAt must be strictly after the booking's current EndsAt.");
+
+        if (newEnd - startsAt > MaxDuration)
+            return Fail(ExtendFailure.ExceedsMaxDuration, "Total booking duration must not exceed 8 hours.");
+
+        // Compare in memory: SQLite stores DateTime as text, so normalising kinds here
+        // avoids depending on provider-specific translation of DateTime comparisons.
+        var others = await _db.Bookings
+            .Where(b => b.RoomId == booking.RoomId && b.Id != booking.Id && b.Status == "CONFIRMED")
+            .ToListAsync();
+
+        // Half-open ranges: a.StartsAt < b.EndsAt && a.EndsAt > b.StartsAt
+        var conflict = others.Any(o => startsAt < AsUtc(o.EndsAt) && newEnd > AsUtc(o.StartsAt));
+        if (conflict)
+            return Fail(ExtendFailure.Overlap, "The extended range overlaps another CONFIRMED booking in the same room.");
+
+        booking.EndsAt = newEnd;
+        await _db.SaveChangesAsync();
+        return new ExtendResult(booking, null, null);
+    }
+
+    // SQLite round-trips DateTime as Kind=Unspecified; the data is UTC by convention.
+    private static DateTime AsUtc(DateTime value) => value.Kind switch
+    {
+        DateTimeKind.Utc => value,
+        DateTimeKind.Local => value.ToUniversalTime(),
+        _ => DateTime.SpecifyKind(value, DateTimeKind.Utc),
+    };
+
+    private static ExtendResult Fail(ExtendFailure failure, string message) => new(null, failure, message);
+}
```

**Response text:**

I've added the endpoint and I'm now building and testing it. The first test command was rejected by the shell, so I'll run it again in simpler steps.

I couldn't build or run the endpoint. Both the Bash and PowerShell tools asked for approval on `dotnet build`, and there's no one here to approve it. The code is written but has not been compiled or tested.

**What I added** (in `workspace/sample-project-reports-api`):
- `Controllers/BookingsController.cs` adds `PATCH /bookings/{id}/extend`. It takes `{ "newEndsAt": ... }` and returns the updated booking on success.
- `Services/BookingExtensionService.cs` holds the four rules.
- `Program.cs` registers the new service.

**Error responses:**

| Case | Status |
|---|---|
| Booking id not found | 404 |
| Booking is not `CONFIRMED` (rule 1) | 409 |
| Extended range overlaps another confirmed booking in the room (rule 4) | 409 |
| `newEndsAt` missing or not an ISO timestamp | 400 |
| `newEndsAt` not strictly after the current `EndsAt` (rule 2) | 400 |
| Total duration from `StartsAt` over 8 hours (rule 3) | 400 |

Each error returns `{ "error": "<message>" }`.

**Behaviour to know about:**
- The overlap check uses `a.StartsAt < b.EndsAt && a.EndsAt > b.StartsAt`, so a booking that ends exactly when another starts does not conflict. It skips the booking itself and cancelled bookings.
- SQLite hands dates back with an unspecified kind, so I treat every date as UTC before comparing. The comparison runs in memory rather than in SQL.
- Exactly 8 hours is allowed. Anything longer is rejected.

To check it, run `dotnet build`, start the app, and send `PATCH` requests against the seed data. For example, `seed-1` runs 09:00–10:00 on 2031-01-01. Extending it to 11:30 should succeed, and extending it past 17:00 should return 400. `seed-3` is cancelled, so it should return 409. I haven't added automated tests, since the project has no test project.

---

## Run B

```diff
diff --git a/Controllers/BookingsController.cs b/Controllers/BookingsController.cs
new file mode 100644
index 0000000..5d3539d
--- /dev/null
+++ b/Controllers/BookingsController.cs
@@ -0,0 +1,41 @@
+using Microsoft.AspNetCore.Mvc;
+using ReportsApi.Models;
+using ReportsApi.Services;
+
+namespace ReportsApi.Controllers;
+
+public class ExtendBookingRequest
+{
+    public DateTime? NewEndsAt { get; set; }
+}
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
+            return BadRequest(new { error = "newEndsAt is required and must be an ISO 8601 timestamp." });
+
+        var result = await _extensionService.ExtendAsync(id, request.NewEndsAt.Value);
+        if (result.Succeeded)
+            return Ok(result.Booking);
+
+        var body = new { error = result.Message };
+        return result.Failure switch
+        {
+            ExtendFailure.NotFound => NotFound(body),
+            ExtendFailure.NotConfirmed or ExtendFailure.Overlap => Conflict(body),
+            _ => UnprocessableEntity(body),
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
index 0000000..0ebd3cd
--- /dev/null
+++ b/Services/BookingExtensionService.cs
@@ -0,0 +1,74 @@
+using Microsoft.EntityFrameworkCore;
+using ReportsApi.Data;
+using ReportsApi.Models;
+
+namespace ReportsApi.Services;
+
+public enum ExtendFailure
+{
+    NotFound,
+    NotConfirmed,
+    NotAfterCurrentEnd,
+    TooLong,
+    Overlap,
+}
+
+public record ExtendResult(Booking? Booking, ExtendFailure? Failure, string? Message)
+{
+    public bool Succeeded => Failure is null;
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
+            return Fail(ExtendFailure.NotFound, $"Booking '{id}' was not found.");
+
+        if (booking.Status != "CONFIRMED")
+            return Fail(ExtendFailure.NotConfirmed, "Only a CONFIRMED booking can be extended.");
+
+        var newEnd = AsUtc(newEndsAt);
+        var start = AsUtc(booking.StartsAt);
+
+        if (newEnd <= AsUtc(booking.EndsAt))
+            return Fail(ExtendFailure.NotAfterCurrentEnd, "newEndsAt must be strictly after the booking's current EndsAt.");
+
+        if (newEnd - start > MaxDuration)
+            return Fail(ExtendFailure.TooLong, "Total booking duration must not exceed 8 hours.");
+
+        // Compared in memory: SQLite stores DateTime as text, so avoid relying
+        // on server-side string comparison of timestamps.
+        var others = await _db.Bookings
+            .Where(b => b.RoomId == booking.RoomId && b.Id != booking.Id && b.Status == "CONFIRMED")
+            .ToListAsync();
+
+        // Half-open ranges: a.Start < b.End && a.End > b.Start.
+        if (others.Any(o => start < AsUtc(o.EndsAt) && newEnd > AsUtc(o.StartsAt)))
+            return Fail(ExtendFailure.Overlap, "The extended booking overlaps another CONFIRMED booking in the same room.");
+
+        booking.EndsAt = newEnd;
+        await _db.SaveChangesAsync();
+        return new ExtendResult(booking, null, null);
+    }
+
+    private static ExtendResult Fail(ExtendFailure failure, string message) => new(null, failure, message);
+
+    // Stored values come back from SQLite with Kind=Unspecified; treat them as UTC.
+    private static DateTime AsUtc(DateTime value) => value.Kind switch
+    {
+        DateTimeKind.Utc => value,
+        DateTimeKind.Local => value.ToUniversalTime(),
+        _ => DateTime.SpecifyKind(value, DateTimeKind.Utc),
+    };
+}
```

**Response text:**

I'll start by looking at the project structure.

Now I'll build and exercise every rule against the running app.

I couldn't verify this. The code is written, but I never got a build or a test run, so I can't say it works.

Every attempt to run `dotnet build` was blocked. Some calls were rejected by the command checker. The plain `dotnet build` calls need approval, and this session is non-interactive, so I can't get it. Nothing has been compiled or run.

## What I wrote (unverified)
- **`Controllers/BookingsController.cs`** (new): `PATCH /bookings/{id}/extend` with body `{ "newEndsAt": ... }`.
- **`Services/BookingExtensionService.cs`** (new): applies the four rules and saves the new `EndsAt`.
- **`Program.cs`**: registers `BookingExtensionService`.

## Error responses
| Case | Status |
|---|---|
| `newEndsAt` missing or not a valid timestamp | 400 |
| Booking not found | 404 |
| Booking is not `CONFIRMED` (rule 1) | 409 |
| Overlaps another `CONFIRMED` booking in the same room (rule 4) | 409 |
| `newEndsAt` not strictly after the current `EndsAt` (rule 2) | 422 |
| Total duration from `StartsAt` over 8 hours (rule 3) | 422 |

On success it returns 200 with the updated booking.

Two choices of mine you may want changed:
- **Timestamps:** all timestamps are treated as UTC. SQLite hands stored values back with an unspecified kind.
- **Overlap check:** it runs in memory and uses `a.Start < b.End && a.End > b.Start`, so a booking ending exactly when another starts is allowed. I did that to avoid comparing timestamps as text in SQLite.

## What's still needed
1. Run `dotnet build`. If it passes, start the app and send a request for each case in the table.
2. Seed data won't cover the overlap case. The nearest `CONFIRMED` bookings in the same room are on different days, and reaching them breaks the 8-hour limit first. You'd need to insert a test booking close to one of the seeded ones.

If you approve `dotnet build` and `dotnet run`, I'll do both checks and report the actual output.

---

## Run C

```diff
diff --git a/Controllers/BookingsController.cs b/Controllers/BookingsController.cs
new file mode 100644
index 0000000..3794328
--- /dev/null
+++ b/Controllers/BookingsController.cs
@@ -0,0 +1,40 @@
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
+            return Problem(statusCode: StatusCodes.Status400BadRequest, detail: "newEndsAt is required.");
+
+        var result = await _extensionService.ExtendAsync(id, request.NewEndsAt.Value.UtcDateTime);
+
+        if (result.Succeeded)
+            return Ok(result.Booking);
+
+        var status = result.Error switch
+        {
+            ExtendError.NotFound => StatusCodes.Status404NotFound,
+            ExtendError.NotConfirmed => StatusCodes.Status409Conflict,
+            ExtendError.Overlap => StatusCodes.Status409Conflict,
+            _ => StatusCodes.Status400BadRequest,
+        };
+        return Problem(statusCode: status, detail: result.Message);
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
index 0000000..eda8d24
--- /dev/null
+++ b/Services/BookingExtensionService.cs
@@ -0,0 +1,60 @@
+using Microsoft.EntityFrameworkCore;
+using ReportsApi.Data;
+using ReportsApi.Models;
+
+namespace ReportsApi.Services;
+
+public enum ExtendError
+{
+    NotFound,
+    NotConfirmed,
+    NotAfterCurrentEnd,
+    ExceedsMaxDuration,
+    Overlap,
+}
+
+public record ExtendResult(Booking? Booking, ExtendError? Error, string? Message)
+{
+    public bool Succeeded => Error is null;
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
+            return new ExtendResult(null, ExtendError.NotFound, $"Booking '{id}' not found.");
+
+        if (booking.Status != "CONFIRMED")
+            return new ExtendResult(null, ExtendError.NotConfirmed, "Only a CONFIRMED booking can be extended.");
+
+        if (newEndsAt <= booking.EndsAt)
+            return new ExtendResult(null, ExtendError.NotAfterCurrentEnd, "newEndsAt must be strictly after the current EndsAt.");
+
+        if (newEndsAt - booking.StartsAt > MaxDuration)
+            return new ExtendResult(null, ExtendError.ExceedsMaxDuration, "Total booking duration must not exceed 8 hours.");
+
+        // Half-open ranges: a.StartsAt < b.EndsAt && a.EndsAt > b.StartsAt.
+        // Compared in memory so the check doesn't depend on SQLite's text date translation.
+        var others = await _db.Bookings
+            .Where(b => b.RoomId == booking.RoomId && b.Id != booking.Id && b.Status == "CONFIRMED")
+            .ToListAsync();
+
+        if (others.Any(o => booking.StartsAt < o.EndsAt && newEndsAt > o.StartsAt))
+            return new ExtendResult(null, ExtendError.Overlap, "The extended range overlaps another CONFIRMED booking in the same room.");
+
+        booking.EndsAt = newEndsAt;
+        await _db.SaveChangesAsync();
+        return new ExtendResult(booking, null, null);
+    }
+}
```

**Response text:**

I'll start by looking at the project structure.

Writing the endpoint is done; now building it to verify. The last command was blocked, so I'm retrying it in simpler pieces.

The endpoint is written but **not built or tested**. This environment refused every `dotnet` command (`dotnet build` and `dotnet --version`) because they need approval, and the session can't prompt for it. I haven't confirmed that the code compiles, and I haven't run any requests against it.

**What I added**
- `Services/BookingExtensionService.cs` holds the rule checks and the save.
- `Controllers/BookingsController.cs` exposes `PATCH /bookings/{id}/extend` with body `{ "newEndsAt": "..." }`.
- `Program.cs` registers the new service.

**How each rule is handled**

| Case | Response |
|---|---|
| Booking id doesn't exist | 404 |
| Booking isn't `CONFIRMED` (rule 1) | 409 |
| `newEndsAt` missing | 400 |
| `newEndsAt` is not strictly after the current `EndsAt` (rule 2) | 400 |
| Total time from `StartsAt` to `newEndsAt` is over 8 hours (rule 3) | 400 |
| Extended range overlaps another `CONFIRMED` booking in the same room (rule 4) | 409 |
| Success | 200 with the updated booking, and `EndsAt` is saved |

The overlap check uses `StartsAt < o.EndsAt && newEndsAt > o.StartsAt`, so a booking that ends exactly when another starts is allowed. The 8-hour check allows exactly 8 hours. The overlap check ignores the booking being extended and ignores cancelled bookings.

**To verify, run these yourself or approve `dotnet` for this session:**
1. `dotnet build` should exit 0.
2. Start the app, then send PATCH requests for each row in the table. The seed data has only two confirmed bookings, a day apart, so testing the overlap rule means adding a booking right after `seed-1` or `seed-2` in the same room, using a throwaway database.
3. Extending the cancelled booking in room Beta isn't possible by id: it's `seed-3`, which should return 409.

I haven't committed anything.

---

## Run D

```diff
diff --git a/Controllers/BookingsController.cs b/Controllers/BookingsController.cs
new file mode 100644
index 0000000..e59a6fa
--- /dev/null
+++ b/Controllers/BookingsController.cs
@@ -0,0 +1,45 @@
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
+            return BadRequest(new { error = "newEndsAt is required" });
+
+        // Stored values are UTC; a timestamp without offset is treated as UTC.
+        var newEndsAt = request.NewEndsAt.Value;
+        newEndsAt = newEndsAt.Kind == DateTimeKind.Unspecified
+            ? DateTime.SpecifyKind(newEndsAt, DateTimeKind.Utc)
+            : newEndsAt.ToUniversalTime();
+
+        var result = await _extensionService.ExtendAsync(id, newEndsAt);
+
+        return result.Failure switch
+        {
+            ExtendFailure.None => Ok(result.Booking),
+            ExtendFailure.NotFound => NotFound(new { error = "Booking not found" }),
+            ExtendFailure.NotConfirmed => Conflict(new { error = "Only CONFIRMED bookings can be extended" }),
+            ExtendFailure.NotAfterCurrentEnd => BadRequest(new { error = "newEndsAt must be after the current EndsAt" }),
+            ExtendFailure.ExceedsMaxDuration => BadRequest(new { error = "Total booking duration must not exceed 8 hours" }),
+            ExtendFailure.Overlap => Conflict(new { error = "Extended range overlaps another CONFIRMED booking in the same room" }),
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
index 0000000..d71c1cb
--- /dev/null
+++ b/Services/BookingExtensionService.cs
@@ -0,0 +1,56 @@
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
+public record ExtendResult(ExtendFailure Failure, Booking? Booking)
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
+        if (booking is null) return new ExtendResult(ExtendFailure.NotFound, null);
+
+        if (booking.Status != "CONFIRMED") return new ExtendResult(ExtendFailure.NotConfirmed, booking);
+
+        if (newEndsAt <= booking.EndsAt) return new ExtendResult(ExtendFailure.NotAfterCurrentEnd, booking);
+
+        if (newEndsAt - booking.StartsAt > MaxDuration) return new ExtendResult(ExtendFailure.ExceedsMaxDuration, booking);
+
+        // Compared in memory: SQLite stores DateTime as text, so we don't rely on
+        // provider-side translation of the range comparison.
+        var others = await _db.Bookings
+            .Where(b => b.RoomId == booking.RoomId && b.Id != booking.Id && b.Status == "CONFIRMED")
+            .ToListAsync();
+        var overlaps = others.Any(o => booking.StartsAt < o.EndsAt && newEndsAt > o.StartsAt);
+        if (overlaps) return new ExtendResult(ExtendFailure.Overlap, booking);
+
+        booking.EndsAt = newEndsAt;
+        await _db.SaveChangesAsync();
+        return new ExtendResult(ExtendFailure.None, booking);
+    }
+}
```

**Response text:**

Writing the code is done. I'm now building the project and testing the endpoint, after a shell-syntax error on my first attempt.

I couldn't build or run the endpoint. The shell blocked both `dotnet build` attempts, one through Bash and one through PowerShell, with "requires approval" errors. Nothing I wrote has been compiled or tested.

**What I added** (in `sample-project-reports-api`):
- `Services/BookingExtensionService.cs` holds the rules and the save. The checks run in this order:
  1. The booking must exist, otherwise 404.
  2. `Status` must be `CONFIRMED`, otherwise 409.
  3. `newEndsAt` must be strictly after the current `EndsAt`, otherwise 400.
  4. `newEndsAt` minus `StartsAt` must be at most 8 hours, otherwise 400.
  5. The extended range must not overlap another `CONFIRMED` booking in the same room, otherwise 409. This uses `StartsAt < other.EndsAt && newEndsAt > other.StartsAt`, so back-to-back bookings are allowed. The booking being extended is excluded from the check.
  6. On success it saves the new `EndsAt` and returns the updated booking with 200.
- `Controllers/BookingsController.cs` exposes `PATCH /bookings/{id}/extend`. A missing `newEndsAt` returns 400, and a timestamp with no offset is treated as UTC to match the stored data.
- `Program.cs` registers the new service.

I run the overlap comparison in memory, not in the SQL query, because SQLite stores `DateTime` as text.

To check it, run `dotnet build`, then start the app and send a few PATCH requests against the seed data. Booking `seed-1` is on 2031-01-01, 09:00–10:00 in `room-a`, and `seed-3` is cancelled. If you approve the shell commands, I can run these checks myself.

---

## Run E

```diff
diff --git a/Controllers/BookingsController.cs b/Controllers/BookingsController.cs
new file mode 100644
index 0000000..d8900e5
--- /dev/null
+++ b/Controllers/BookingsController.cs
@@ -0,0 +1,36 @@
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
+            return BadRequest(new { error = "newEndsAt is required (ISO 8601 timestamp)." });
+
+        var result = await _extensionService.ExtendAsync(id, request.NewEndsAt.Value.UtcDateTime);
+
+        return result.Error switch
+        {
+            null => Ok(result.Booking),
+            ExtendError.NotFound => NotFound(new { error = result.Message }),
+            ExtendError.NotConfirmed or ExtendError.Overlap => Conflict(new { error = result.Message }),
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
index 0000000..8e010a0
--- /dev/null
+++ b/Services/BookingExtensionService.cs
@@ -0,0 +1,57 @@
+using Microsoft.EntityFrameworkCore;
+using ReportsApi.Data;
+using ReportsApi.Models;
+
+namespace ReportsApi.Services;
+
+public enum ExtendError
+{
+    NotFound,
+    NotConfirmed,
+    NotAfterCurrentEnd,
+    ExceedsMaxDuration,
+    Overlap,
+}
+
+public record ExtendResult(Booking? Booking, ExtendError? Error, string? Message);
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
+    // newEndsAt must already be UTC; stored timestamps are UTC (SQLite returns them as Kind=Unspecified).
+    public async Task<ExtendResult> ExtendAsync(string id, DateTime newEndsAt)
+    {
+        var booking = await _db.Bookings.FirstOrDefaultAsync(b => b.Id == id);
+        if (booking is null)
+            return new ExtendResult(null, ExtendError.NotFound, $"Booking '{id}' not found.");
+
+        if (booking.Status != "CONFIRMED")
+            return new ExtendResult(null, ExtendError.NotConfirmed, "Only CONFIRMED bookings can be extended.");
+
+        if (newEndsAt <= booking.EndsAt)
+            return new ExtendResult(null, ExtendError.NotAfterCurrentEnd, "newEndsAt must be after the booking's current EndsAt.");
+
+        if (newEndsAt - booking.StartsAt > MaxDuration)
+            return new ExtendResult(null, ExtendError.ExceedsMaxDuration, "Total booking duration must not exceed 8 hours.");
+
+        // Half-open ranges: a.StartsAt < b.EndsAt && a.EndsAt > b.StartsAt.
+        // Compared in memory so we don't depend on SQLite's DateTime text comparison.
+        var others = await _db.Bookings
+            .Where(b => b.RoomId == booking.RoomId && b.Id != booking.Id && b.Status == "CONFIRMED")
+            .ToListAsync();
+        if (others.Any(o => booking.StartsAt < o.EndsAt && newEndsAt > o.StartsAt))
+            return new ExtendResult(null, ExtendError.Overlap, "The extended range overlaps another CONFIRMED booking in this room.");
+
+        booking.EndsAt = newEndsAt;
+        await _db.SaveChangesAsync();
+        return new ExtendResult(booking, null, null);
+    }
+}
```

**Response text:**

I've written the endpoint and am now building and smoke-testing it. The last command was blocked, so I'll split it up.

I couldn't build or run the endpoint. Both `dotnet build` attempts were blocked for approval, so the code is written but has never been compiled or run.

I added `PATCH /bookings/{id}/extend`, which takes `{ "newEndsAt": "<ISO 8601>" }` as specified:

- **Files:** I added `Services/BookingExtensionService.cs` and `Controllers/BookingsController.cs`, and registered the service in `Program.cs`.
- **Overlap check:** it loads the room's other CONFIRMED bookings and compares them in memory, using `StartsAt < o.EndsAt && newEnd > o.StartsAt`. That keeps it half-open and avoids relying on how SQLite compares date text.
- **Time zones:** the incoming time is converted to UTC. Stored times are treated as UTC, which matches the seed data.
- **On success:** it saves the new `EndsAt` and returns the updated booking with 200.

These are the error responses I chose. The spec only asked for "an appropriate 4xx", so say if you want different codes:

| Violation | Response |
|---|---|
| Missing `newEndsAt` | 400 |
| Booking not found | 404 |
| Booking is not CONFIRMED | 409 |
| Overlaps another CONFIRMED booking | 409 |
| `newEndsAt` not after the current `EndsAt` | 422 |
| Total duration over 8 hours | 422 |

To check it, run `dotnet build`, start the app, and `PATCH` against the seed data:

- `seed-1` runs 09:00–10:00 on 2031-01-01. Extending it to 11:00 should return 200, and extending it to 19:00 should return 422.
- `seed-3` is cancelled, so extending it should return 409.

I haven't added any automated tests.

---

## Run F

```diff
diff --git a/Controllers/BookingsController.cs b/Controllers/BookingsController.cs
new file mode 100644
index 0000000..c470779
--- /dev/null
+++ b/Controllers/BookingsController.cs
@@ -0,0 +1,39 @@
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
+            return BadRequest(new { error = "newEndsAt is required (ISO 8601 timestamp)." });
+
+        var outcome = await _extensionService.ExtendAsync(id, request.NewEndsAt.Value.UtcDateTime);
+
+        return outcome.Result switch
+        {
+            ExtendResult.Success => Ok(outcome.Booking),
+            ExtendResult.NotFound => NotFound(new { error = "Booking not found." }),
+            ExtendResult.NotConfirmed => Conflict(new { error = "Only CONFIRMED bookings can be extended." }),
+            ExtendResult.NotAfterCurrentEnd => BadRequest(new { error = "newEndsAt must be after the booking's current EndsAt." }),
+            ExtendResult.ExceedsMaxDuration => BadRequest(new { error = "Total booking duration must not exceed 8 hours." }),
+            ExtendResult.Overlap => Conflict(new { error = "Extended range overlaps another CONFIRMED booking in the same room." }),
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
index 0000000..a3444cb
--- /dev/null
+++ b/Services/BookingExtensionService.cs
@@ -0,0 +1,66 @@
+using Microsoft.EntityFrameworkCore;
+using ReportsApi.Data;
+using ReportsApi.Models;
+
+namespace ReportsApi.Services;
+
+public enum ExtendResult
+{
+    Success,
+    NotFound,
+    NotConfirmed,
+    NotAfterCurrentEnd,
+    ExceedsMaxDuration,
+    Overlap,
+}
+
+public record ExtendOutcome(ExtendResult Result, Booking? Booking = null);
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
+    public async Task<ExtendOutcome> ExtendAsync(string id, DateTime newEndsAt)
+    {
+        var booking = await _db.Bookings.FirstOrDefaultAsync(b => b.Id == id);
+        if (booking is null) return new ExtendOutcome(ExtendResult.NotFound);
+
+        if (booking.Status != "CONFIRMED") return new ExtendOutcome(ExtendResult.NotConfirmed);
+
+        // SQLite returns Unspecified-kind values; everything is stored as UTC.
+        var startsAt = AsUtc(booking.StartsAt);
+        var endsAt = AsUtc(booking.EndsAt);
+        newEndsAt = AsUtc(newEndsAt);
+
+        if (newEndsAt <= endsAt) return new ExtendOutcome(ExtendResult.NotAfterCurrentEnd);
+
+        if (newEndsAt - startsAt > MaxDuration) return new ExtendOutcome(ExtendResult.ExceedsMaxDuration);
+
+        // Compared in memory: SQLite stores DateTime as text, so keep the
+        // half-open overlap check out of SQL translation.
+        var others = await _db.Bookings
+            .Where(b => b.RoomId == booking.RoomId && b.Id != booking.Id && b.Status == "CONFIRMED")
+            .ToListAsync();
+
+        var overlaps = others.Any(o => startsAt < AsUtc(o.EndsAt) && newEndsAt > AsUtc(o.StartsAt));
+        if (overlaps) return new ExtendOutcome(ExtendResult.Overlap);
+
+        booking.EndsAt = newEndsAt;
+        await _db.SaveChangesAsync();
+        return new ExtendOutcome(ExtendResult.Success, booking);
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

I'll start by looking at the project structure.

Building the project now to check the new endpoint compiles.

I couldn't verify the endpoint. Every `dotnet build` attempt was blocked pending approval, which this session can't give, so nothing has been compiled or run.

I wrote `PATCH /bookings/{id}/extend` as three changes:
- **`Services/BookingExtensionService.cs` (new):** holds the four rules, checked in this order.
  - A booking that isn't CONFIRMED is rejected.
  - `newEndsAt` must be after the current `EndsAt`.
  - The total duration from the original `StartsAt` can't exceed 8 hours.
  - The new range can't overlap another CONFIRMED booking in the same room. The check is `StartsAt < o.EndsAt && newEnd > o.StartsAt`, so touching ranges don't overlap.
  - On success it saves the new `EndsAt` and returns the booking.
- **`Controllers/BookingsController.cs` (new):** reads `{ "newEndsAt": ... }` and maps each outcome to a response.
  - A missing `newEndsAt`, a `newEndsAt` not after the current end, or a total over 8 hours returns 400.
  - A cancelled booking or an overlap returns 409.
  - An unknown booking id returns 404.
  - Success returns 200 with the updated booking.
- **`Program.cs`:** registers `BookingExtensionService`.

Timestamps are converted to UTC before comparing. I do the overlap comparison in memory rather than in SQL, because SQLite stores dates as text.

What's left to check:
1. Run `dotnet build` and confirm it exits 0.
2. Start the app and send one request per rule. The seed data has no two bookings in the same room close together, so the overlap and touching-boundary cases need an extra booking inserted first.

Approve `dotnet build` and `dotnet run` and I'll do both. You can also run them yourself and send me the output.

---

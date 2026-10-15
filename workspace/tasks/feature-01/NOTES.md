# feature-01 — internal notes (do NOT ship to graders)

Domain: meeting room booking, C# reports API (`sample-project-reports-api`). Fabricated.
Repo: `sample-project-reports-api` · base tag: `feature-01-base` (no `extend`
endpoint yet — that's what this task asks the agent to add).

This repo does not have its own `docs/DOMAIN.md` (see its `docs/README.md` —
the Node API is the single source of truth for the domain). All the rules
needed for this one endpoint are given directly in `prompt.txt` so the task
is self-contained within this repo.

## Reference implementation

```csharp
public record ExtendBookingRequest(DateTime NewEndsAt);

[HttpPatch("/bookings/{id}/extend")]
public async Task<ActionResult<Booking>> Extend(string id, [FromBody] ExtendBookingRequest request)
{
    var booking = await _db.Bookings.FindAsync(id);
    if (booking is null) return NotFound();

    if (booking.Status != "CONFIRMED")
        return Conflict("Only CONFIRMED bookings can be extended.");

    if (request.NewEndsAt <= booking.EndsAt)
        return BadRequest("newEndsAt must be strictly after the current endsAt.");

    var totalDuration = request.NewEndsAt - booking.StartsAt;
    if (totalDuration > TimeSpan.FromHours(8))
        return Conflict("Booking may not exceed 8 hours total.");

    var overlaps = await _db.Bookings
        .Where(b => b.RoomId == booking.RoomId && b.Id != booking.Id && b.Status == "CONFIRMED")
        .AnyAsync(b => booking.StartsAt < b.EndsAt && request.NewEndsAt > b.StartsAt);
    if (overlaps)
        return Conflict("Extended range overlaps another CONFIRMED booking.");

    booking.EndsAt = request.NewEndsAt;
    await _db.SaveChangesAsync();
    return Ok(booking);
}
```

(Exact status codes/method names are not prescribed — judge on whether the
four rules are actually enforced, not on matching this code.)

## Two independent judgment points (per benchmark-tasks spec)

1. **Overlap check against other CONFIRMED bookings** — must use the
   half-open formula (`a.StartsAt < b.EndsAt && a.EndsAt > b.StartsAt`)
   applied to `(booking.StartsAt, newEndsAt)` against every *other*
   CONFIRMED booking in the same room. Common mistakes: comparing against
   the booking's *own* old range (always "overlaps" itself, silently
   blocking every extension), or using `<=`/`>=` (rejects legal back-to-back
   extensions).
2. **8-hour total duration cap** — must be computed from the *original*
   `StartsAt`, not from `EndsAt - newEndsAt` or some other partial span.

Status/CANCELLED check (rule 1) and `newEndsAt` monotonicity (rule 2) are
easier to get right and mainly separate a 0 from a 1–2, not a 3 from a 4.

## ด้านที่ 1-2 (ความถูกต้อง/ความครบถ้วน) worked examples

- **4** — All four rules enforced correctly; only the new endpoint added, no
  unrelated files touched.
- **3** — All four rules correct — this task's ceiling is usually a ด้าน 3
  (quality) blemish rather than a 1-2 issue, e.g. wrong HTTP status code for
  a rejected case (behaviourally still rejects, just with the wrong status).
- **2** — Gets the endpoint working and enforces 2 of the 4 rules correctly
  (most commonly: status + monotonicity right, overlap or duration wrong).
- **1** — Adds an endpoint that doesn't actually enforce the rules (e.g.
  always accepts), or enforces overlap against the booking's own old range
  (self-conflict bug — new defect of similar severity to what it's supposed
  to prevent).
- **0** — No endpoint added, wrong route/method, or the project doesn't
  build.

## ด้านที่ 3 — คุณภาพของโค้ด: worked examples

- **4** — ตรงตาม convention ของ ASP.NET Core ที่ repo ใช้อยู่แล้ว (controller action, `[FromBody]`, async/await ตลอด, DI ผ่าน constructor เหมือน `ReportsController` เดิม) ไม่แตะ controller/service อื่น
- **3** — ทำงานถูก แต่มีจุดติเล็กน้อย เช่น เลือก HTTP status code ไม่สอดคล้องกับที่ endpoint อื่นในไฟล์เดียวกันใช้ หรือไม่มี comment อธิบาย constraint ที่ endpoint อื่นมี
- **2** — ทำงานได้แต่ซับซ้อนเกินจำเป็น (เช่น เพิ่ม service layer ใหม่ทั้งชั้นสำหรับ endpoint เดียว ทั้งที่ repo ปัจจุบันเรียก DbContext ตรงจาก controller) หรือแตะ controller อื่นที่ไม่เกี่ยว
- **1** — ต้องรื้อแก้เยอะก่อน merge ได้ (เช่น business logic ปนอยู่ใน controller แบบไม่มีโครงสร้าง ไม่มี error handling ที่สอดคล้องกับส่วนอื่น)
- **0** — ไม่ควร merge

## Why this design

- **Two independent rule-checks (overlap + duration), same shape as
  bugfix-01/refactor-01's "≥2 judgment points" requirement.**
- **Self-contained rules in the prompt** — this repo intentionally doesn't
  carry its own copy of `docs/DOMAIN.md` (avoiding duplicated business logic
  across services per the `sample-project` spec's "Domain independence"
  requirement), so the prompt itself must state exactly what's needed.
- **Additive task (no existing code to break)** — this is the one task in
  the set that tests "build something new correctly" rather than "find/fix/
  restructure existing code", covering the `feature` category from the
  project's scope.

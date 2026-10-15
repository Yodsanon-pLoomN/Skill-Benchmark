# Blind grading input — refactor-01 / caveman

⚠️ Run labels below are shuffled and do NOT reveal which condition (off vs skill) produced each one — graded by content only, per the blind-grading rule. Key file: `report-KEY.md` (do not open until grade_runs.py has produced report-scored.md).

> ตรวจโดย `grade_runs.py` อัตโนมัติ (blind, 3 pass อิสระ, majority vote, เกณฑ์ผ่าน >=80% ของ checklist) — checklist จริงเจาะจงต่อ task อยู่ที่ `workspace/tasks/<task_id>/checklist.md` กติกากลางดู `RUBRIC-กลาง.md` ไม่มี rubric 0-4 ฝังในไฟล์นี้อีกต่อไป

---

## Run A

```diff
diff --git a/src/services/bookingService.ts b/src/services/bookingService.ts
index 6ebd8d6..100747c 100644
--- a/src/services/bookingService.ts
+++ b/src/services/bookingService.ts
@@ -18,6 +18,11 @@ function dateStrOf(date: Date): string {
   return date.toISOString().slice(0, 10);
 }
 
+/** Whether any of the given (CONFIRMED) bookings overlaps the candidate range. */
+function overlapsAnyBooking(confirmed: Booking[], range: TimeRange): boolean {
+  return confirmed.some((existing) => overlaps(existing, range));
+}
+
 export async function createBooking(input: {
   roomId: string;
   userId: string;
@@ -32,10 +37,8 @@ export async function createBooking(input: {
   assertValidRange(range);
   assertNotInPast(range);
 
-  // Conflict check: any CONFIRMED booking that day overlapping the requested range.
   const sameDay = await findBookingsForDay(input.roomId, dateStrOf(range.startsAt));
-  const hasConflict = sameDay.some((existing) => overlaps(existing, range));
-  if (hasConflict) {
+  if (overlapsAnyBooking(sameDay, range)) {
     throw new SlotUnavailableError();
   }
 
@@ -69,12 +72,10 @@ export async function checkAvailability(roomId: string, dateStr: string): Promis
     (a, b) => a.startsAt.getTime() - b.startsAt.getTime(),
   );
 
-  // Fast path: if nothing that day overlaps the full-day window at all, the
-  // room is free all day and we can skip the interval sweep below. (Copied
-  // from the conflict check in createBooking rather than reused from there.)
+  // Fast path: if nothing overlaps the full-day window, the room is free all
+  // day and we can skip the interval sweep below.
   const dayWindow: TimeRange = { startsAt: dayStart, endsAt: dayEnd };
-  const hasAnyBookingThatDay = bookings.some((existing) => overlaps(existing, dayWindow));
-  if (!hasAnyBookingThatDay) {
+  if (!overlapsAnyBooking(bookings, dayWindow)) {
     return [dayWindow];
   }
```

**Response text:**

I replaced the two copies of the overlap scan with one shared helper, but I couldn't run the type-check or the tests. Both `npx tsc --noEmit` and `npm test` were blocked waiting for approval, so the change is unverified.

The helper is `overlapsAnyBooking(confirmed, range)` in `src/services/bookingService.ts`. Both `createBooking` and the fast path in `checkAvailability` now call it. It uses the existing `overlaps()` from the domain module, which matches the half-open interval rule in docs/DOMAIN.md.

Behaviour should be unchanged, for these reasons:
- **Booking creation:** it still fetches the day's bookings and throws `SlotUnavailableError` on any overlap.
- **Availability:** the fast path still returns the whole day as free when nothing overlaps the full-day window, and falls through to the interval sweep otherwise.
- **Cancelled bookings:** they are still ignored, because `findBookingsForDay` only returns `CONFIRMED` rows.

Please run `npx tsc --noEmit` and `npm test` yourself, or approve them and I'll run them.

---

## Run B

```diff
diff --git a/src/services/bookingService.ts b/src/services/bookingService.ts
index 6ebd8d6..54eff87 100644
--- a/src/services/bookingService.ts
+++ b/src/services/bookingService.ts
@@ -18,6 +18,11 @@ function dateStrOf(date: Date): string {
   return date.toISOString().slice(0, 10);
 }
 
+/** Shared overlap scan: does any of the (CONFIRMED) bookings overlap the range? */
+function anyOverlap(bookings: TimeRange[], range: TimeRange): boolean {
+  return bookings.some((existing) => overlaps(existing, range));
+}
+
 export async function createBooking(input: {
   roomId: string;
   userId: string;
@@ -34,8 +39,7 @@ export async function createBooking(input: {
 
   // Conflict check: any CONFIRMED booking that day overlapping the requested range.
   const sameDay = await findBookingsForDay(input.roomId, dateStrOf(range.startsAt));
-  const hasConflict = sameDay.some((existing) => overlaps(existing, range));
-  if (hasConflict) {
+  if (anyOverlap(sameDay, range)) {
     throw new SlotUnavailableError();
   }
 
@@ -69,12 +73,10 @@ export async function checkAvailability(roomId: string, dateStr: string): Promis
     (a, b) => a.startsAt.getTime() - b.startsAt.getTime(),
   );
 
-  // Fast path: if nothing that day overlaps the full-day window at all, the
-  // room is free all day and we can skip the interval sweep below. (Copied
-  // from the conflict check in createBooking rather than reused from there.)
+  // Fast path: if nothing overlaps the full-day window, the room is free all
+  // day and we can skip the interval sweep below.
   const dayWindow: TimeRange = { startsAt: dayStart, endsAt: dayEnd };
-  const hasAnyBookingThatDay = bookings.some((existing) => overlaps(existing, dayWindow));
-  if (!hasAnyBookingThatDay) {
+  if (!anyOverlap(bookings, dayWindow)) {
     return [dayWindow];
   }
```

**Response text:**

Overlap scan now lives in one helper, `anyOverlap(bookings, range)`, in `src/services/bookingService.ts`. `createBooking` and the `checkAvailability` fast path both call it. I couldn't type-check or run tests: the `tsc --noEmit` call was blocked pending approval, so none of this has been compiled.

- **Behaviour:** Both callers use the same `overlaps()` check from the domain module, which matches the half-open rule in `docs/DOMAIN.md`. Cancelled bookings (rule 2) were already filtered out in the repository query (`status: "CONFIRMED"` in `findBookingsForDay`), and I left that alone. The fast-path comment is reworded.
- **Not unified:** The sweep that builds the free intervals is separate logic and stays as it was.

---

## Run C

```diff
diff --git a/src/services/bookingService.ts b/src/services/bookingService.ts
index 6ebd8d6..e9f9a7f 100644
--- a/src/services/bookingService.ts
+++ b/src/services/bookingService.ts
@@ -18,6 +18,11 @@ function dateStrOf(date: Date): string {
   return date.toISOString().slice(0, 10);
 }
 
+/** Shared overlap scan: does `range` overlap any of the given (CONFIRMED) bookings? */
+function overlapsAny(bookings: TimeRange[], range: TimeRange): boolean {
+  return bookings.some((existing) => overlaps(existing, range));
+}
+
 export async function createBooking(input: {
   roomId: string;
   userId: string;
@@ -34,8 +39,7 @@ export async function createBooking(input: {
 
   // Conflict check: any CONFIRMED booking that day overlapping the requested range.
   const sameDay = await findBookingsForDay(input.roomId, dateStrOf(range.startsAt));
-  const hasConflict = sameDay.some((existing) => overlaps(existing, range));
-  if (hasConflict) {
+  if (overlapsAny(sameDay, range)) {
     throw new SlotUnavailableError();
   }
 
@@ -70,11 +74,9 @@ export async function checkAvailability(roomId: string, dateStr: string): Promis
   );
 
   // Fast path: if nothing that day overlaps the full-day window at all, the
-  // room is free all day and we can skip the interval sweep below. (Copied
-  // from the conflict check in createBooking rather than reused from there.)
+  // room is free all day and we can skip the interval sweep below.
   const dayWindow: TimeRange = { startsAt: dayStart, endsAt: dayEnd };
-  const hasAnyBookingThatDay = bookings.some((existing) => overlaps(existing, dayWindow));
-  if (!hasAnyBookingThatDay) {
+  if (!overlapsAny(bookings, dayWindow)) {
     return [dayWindow];
   }
```

**Response text:**

The overlap logic is now one shared helper, but I couldn't run the tests or the type-check. Every attempt to run `npm test` or `npx tsc --noEmit` was blocked waiting for permission approval, and this session can't grant it.

**What changed** (all in `src/services/bookingService.ts`):
- I added a private helper, `overlapsAny(bookings, range)`, which wraps the existing domain `overlaps` function.
- `createBooking` now calls it for the same-day conflict check.
- `checkAvailability` now calls it for the "free all day" fast path, and I removed the comment saying that code was copied from `createBooking`.

**Why behaviour should be the same:**
- The inputs and the overlap function are unchanged, so both endpoints return what they did before.
- Both callers still get their bookings from `findBookingsForDay`, which only returns CONFIRMED ones, so cancelled bookings still never conflict.
- Back-to-back bookings still don't overlap, because the half-open rule lives in `overlaps` and I didn't touch it.

**To check:** run `npm test` and `npx tsc --noEmit` yourself, or approve them and I'll run them.

---

## Run D

```diff
diff --git a/src/services/bookingService.ts b/src/services/bookingService.ts
index 6ebd8d6..7c90af5 100644
--- a/src/services/bookingService.ts
+++ b/src/services/bookingService.ts
@@ -18,6 +18,11 @@ function dateStrOf(date: Date): string {
   return date.toISOString().slice(0, 10);
 }
 
+/** True if any of the given (CONFIRMED) bookings overlaps the range. */
+function hasOverlap(bookings: Booking[], range: TimeRange): boolean {
+  return bookings.some((existing) => overlaps(existing, range));
+}
+
 export async function createBooking(input: {
   roomId: string;
   userId: string;
@@ -34,8 +39,7 @@ export async function createBooking(input: {
 
   // Conflict check: any CONFIRMED booking that day overlapping the requested range.
   const sameDay = await findBookingsForDay(input.roomId, dateStrOf(range.startsAt));
-  const hasConflict = sameDay.some((existing) => overlaps(existing, range));
-  if (hasConflict) {
+  if (hasOverlap(sameDay, range)) {
     throw new SlotUnavailableError();
   }
 
@@ -70,11 +74,9 @@ export async function checkAvailability(roomId: string, dateStr: string): Promis
   );
 
   // Fast path: if nothing that day overlaps the full-day window at all, the
-  // room is free all day and we can skip the interval sweep below. (Copied
-  // from the conflict check in createBooking rather than reused from there.)
+  // room is free all day and we can skip the interval sweep below.
   const dayWindow: TimeRange = { startsAt: dayStart, endsAt: dayEnd };
-  const hasAnyBookingThatDay = bookings.some((existing) => overlaps(existing, dayWindow));
-  if (!hasAnyBookingThatDay) {
+  if (!hasOverlap(bookings, dayWindow)) {
     return [dayWindow];
   }
```

**Response text:**

Edits done, but I couldn't run typecheck or tests. Both commands were blocked pending approval.

In `src/services/bookingService.ts`:
- Added one helper, `hasOverlap(bookings, range)`. It wraps `overlaps` from `domain/booking.ts`, the half-open rule from DOMAIN.md.
- `createBooking` now calls `hasOverlap(sameDay, range)`.
- The `checkAvailability` fast path now calls `hasOverlap(bookings, dayWindow)`. I also removed the "copied from createBooking" comment.

Behaviour is unchanged. The comparison is still `overlaps`, so back-to-back bookings stay legal. `findBookingsForDay` still filters to `CONFIRMED`, so cancelled bookings are still ignored.

Run `npx tsc --noEmit` and `npm test` to confirm.

---

## Run E

```diff
diff --git a/src/services/bookingService.ts b/src/services/bookingService.ts
index 6ebd8d6..12bcadf 100644
--- a/src/services/bookingService.ts
+++ b/src/services/bookingService.ts
@@ -18,6 +18,11 @@ function dateStrOf(date: Date): string {
   return date.toISOString().slice(0, 10);
 }
 
+/** True if any of the given (already CONFIRMED-only) bookings overlaps the range. */
+function hasOverlap(bookings: Booking[], range: TimeRange): boolean {
+  return bookings.some((existing) => overlaps(existing, range));
+}
+
 export async function createBooking(input: {
   roomId: string;
   userId: string;
@@ -32,10 +37,8 @@ export async function createBooking(input: {
   assertValidRange(range);
   assertNotInPast(range);
 
-  // Conflict check: any CONFIRMED booking that day overlapping the requested range.
   const sameDay = await findBookingsForDay(input.roomId, dateStrOf(range.startsAt));
-  const hasConflict = sameDay.some((existing) => overlaps(existing, range));
-  if (hasConflict) {
+  if (hasOverlap(sameDay, range)) {
     throw new SlotUnavailableError();
   }
 
@@ -69,12 +72,9 @@ export async function checkAvailability(roomId: string, dateStr: string): Promis
     (a, b) => a.startsAt.getTime() - b.startsAt.getTime(),
   );
 
-  // Fast path: if nothing that day overlaps the full-day window at all, the
-  // room is free all day and we can skip the interval sweep below. (Copied
-  // from the conflict check in createBooking rather than reused from there.)
+  // Fast path: nothing overlaps the full-day window, so room is free all day.
   const dayWindow: TimeRange = { startsAt: dayStart, endsAt: dayEnd };
-  const hasAnyBookingThatDay = bookings.some((existing) => overlaps(existing, dayWindow));
-  if (!hasAnyBookingThatDay) {
+  if (!hasOverlap(bookings, dayWindow)) {
     return [dayWindow];
   }
```

**Response text:**

Repo filters CONFIRMED. Extract shared helper.

Refactor done in `src/services/bookingService.ts`. I haven't run the type check or tests. The shell command to run them needed approval and didn't run.

- **Change:** the overlap scan now lives in one helper, `hasOverlap(bookings, range)`. `createBooking` and the full-day fast path in `checkAvailability` both call it.
- **Behaviour:** unchanged. Both copies already used `overlaps()` from `domain/booking.js`. `findBookingsForDay` already returns only CONFIRMED bookings, so cancelled ones never reach the helper (rule 2).

Run `npx tsc --noEmit` and `npm test` to confirm.

---

## Run F

```diff
diff --git a/src/services/bookingService.ts b/src/services/bookingService.ts
index 6ebd8d6..42be9b1 100644
--- a/src/services/bookingService.ts
+++ b/src/services/bookingService.ts
@@ -18,6 +18,11 @@ function dateStrOf(date: Date): string {
   return date.toISOString().slice(0, 10);
 }
 
+/** Shared overlap scan: does any of the (CONFIRMED) bookings overlap `range`? */
+function overlapsAny(bookings: Booking[], range: TimeRange): boolean {
+  return bookings.some((existing) => overlaps(existing, range));
+}
+
 export async function createBooking(input: {
   roomId: string;
   userId: string;
@@ -34,8 +39,7 @@ export async function createBooking(input: {
 
   // Conflict check: any CONFIRMED booking that day overlapping the requested range.
   const sameDay = await findBookingsForDay(input.roomId, dateStrOf(range.startsAt));
-  const hasConflict = sameDay.some((existing) => overlaps(existing, range));
-  if (hasConflict) {
+  if (overlapsAny(sameDay, range)) {
     throw new SlotUnavailableError();
   }
 
@@ -70,11 +74,9 @@ export async function checkAvailability(roomId: string, dateStr: string): Promis
   );
 
   // Fast path: if nothing that day overlaps the full-day window at all, the
-  // room is free all day and we can skip the interval sweep below. (Copied
-  // from the conflict check in createBooking rather than reused from there.)
+  // room is free all day and we can skip the interval sweep below.
   const dayWindow: TimeRange = { startsAt: dayStart, endsAt: dayEnd };
-  const hasAnyBookingThatDay = bookings.some((existing) => overlaps(existing, dayWindow));
-  if (!hasAnyBookingThatDay) {
+  if (!overlapsAny(bookings, dayWindow)) {
     return [dayWindow];
   }
```

**Response text:**

I've made the refactor, but I haven't verified it. The test and typecheck commands were blocked waiting for permission approval, so neither has run.

I'm trying `npx tsc --noEmit` on its own next.

I refactored the overlap scan into one shared helper, but I couldn't run the typecheck or tests. Every `tsc` and `npm test` call was blocked pending permission approval, and this session can't grant it.

In `src/services/bookingService.ts` I added a private helper, `overlapsAny(bookings, range)`, which wraps `bookings.some(b => overlaps(b, range))`. Both places now call it:
- **`createBooking`:** it calls the helper against that day's bookings and throws `SlotUnavailableError` on a conflict, as before.
- **`checkAvailability`:** the fast-path check calls the same helper against the full-day window. I also removed the comment saying the logic was copied.

Behaviour should be identical. The helper uses the same `overlaps` function (the half-open check from DOMAIN.md), and the same `findBookingsForDay` query still supplies the bookings. That query filters to `CONFIRMED` only, so cancelled bookings are still ignored. I didn't touch the free-interval sweep or any other code.

Please run `npx tsc --noEmit` and `npm test` yourself, or approve those commands and I'll run them.

---

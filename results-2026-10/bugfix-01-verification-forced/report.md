# Blind grading input — bugfix-01 / verification-forced

⚠️ Run labels below are shuffled and do NOT reveal which condition (off vs skill) produced each one — graded by content only, per the blind-grading rule. Key file: `report-KEY.md` (do not open until grade_runs.py has produced report-scored.md).

> ตรวจโดย `grade_runs.py` อัตโนมัติ (blind, 3 pass อิสระ, majority vote, เกณฑ์ผ่าน >=80% ของ checklist) — checklist จริงเจาะจงต่อ task อยู่ที่ `workspace/tasks/<task_id>/checklist.md` กติกากลางดู `RUBRIC-กลาง.md` ไม่มี rubric 0-4 ฝังในไฟล์นี้อีกต่อไป

---

## Run A

```diff
diff --git a/src/domain/booking.ts b/src/domain/booking.ts
index 3d430a9..ac07724 100644
--- a/src/domain/booking.ts
+++ b/src/domain/booking.ts
@@ -9,7 +9,7 @@ const MAX_DURATION_HOURS = 8;
  * starting at 11:00 do not overlap.
  */
 export function overlaps(a: TimeRange, b: TimeRange): boolean {
-  return a.startsAt <= b.endsAt && a.endsAt >= b.startsAt;
+  return a.startsAt < b.endsAt && a.endsAt > b.startsAt;
 }
 
 export function assertValidRange(range: TimeRange): void {
diff --git a/src/repositories/bookingRepository.ts b/src/repositories/bookingRepository.ts
index 178bb19..d69de50 100644
--- a/src/repositories/bookingRepository.ts
+++ b/src/repositories/bookingRepository.ts
@@ -23,6 +23,7 @@ export async function findBookingsForDay(roomId: string, dateStr: string): Promi
   const rows = await prisma.booking.findMany({
     where: {
       roomId,
+      status: "CONFIRMED",
       startsAt: { lte: endOfUtcDay(dateStr) },
       endsAt: { gte: startOfUtcDay(dateStr) },
     },
```

**Response text:**

Let me use the Edit tool instead.

I fixed both bugs, and `npm test` now passes 13/13 (before the fix, 3 of those 13 failed). I couldn't run the `tsc --noEmit` type-check because the command needed approval and wasn't run.

**Report 1: back-to-back bookings rejected.** In `src/domain/booking.ts`, `overlaps()` used `<=` and `>=`, so ranges that only touch at 11:00 counted as overlapping. DOMAIN.md defines the interval as half-open, so I changed it to strict `<` and `>`.

**Report 2: cancelled booking still blocks the slot.** `findBookingsForDay` in `src/repositories/bookingRepository.ts` didn't filter by status, so cancelled bookings were treated as conflicts. Its own doc comment said they were excluded. I added `status: "CONFIRMED"` to the query. This also stops cancelled bookings from showing up as busy in the availability endpoint.

I didn't write new tests for the two exact scenarios in the reports (11:00 back-to-back, and rebooking a cancelled 2pm slot). I only reran the existing suite, so I haven't confirmed those two cases directly beyond the existing tests going green.

The changes are uncommitted in the working tree.

---

## Run B

```diff
diff --git a/src/domain/booking.ts b/src/domain/booking.ts
index 3d430a9..ac07724 100644
--- a/src/domain/booking.ts
+++ b/src/domain/booking.ts
@@ -9,7 +9,7 @@ const MAX_DURATION_HOURS = 8;
  * starting at 11:00 do not overlap.
  */
 export function overlaps(a: TimeRange, b: TimeRange): boolean {
-  return a.startsAt <= b.endsAt && a.endsAt >= b.startsAt;
+  return a.startsAt < b.endsAt && a.endsAt > b.startsAt;
 }
 
 export function assertValidRange(range: TimeRange): void {
diff --git a/src/repositories/bookingRepository.ts b/src/repositories/bookingRepository.ts
index 178bb19..d69de50 100644
--- a/src/repositories/bookingRepository.ts
+++ b/src/repositories/bookingRepository.ts
@@ -23,6 +23,7 @@ export async function findBookingsForDay(roomId: string, dateStr: string): Promi
   const rows = await prisma.booking.findMany({
     where: {
       roomId,
+      status: "CONFIRMED",
       startsAt: { lte: endOfUtcDay(dateStr) },
       endsAt: { gte: startOfUtcDay(dateStr) },
     },
```

**Response text:**

Using Edit instead.

I found two bugs in the booking service and fixed both. After the changes, `npm test` shows 13 of 13 tests passing.

1. **Report 1 (11:00 back-to-back bookings rejected):** `overlaps()` in `src/domain/booking.ts` used `<=` and `>=`, so bookings that only touch at an endpoint counted as overlapping. `docs/DOMAIN.md` says the interval is half-open, so I changed it to strict `<` and `>`.
2. **Report 2 (cancelled 2pm booking still blocks the slot):** `findBookingsForDay` in `src/repositories/bookingRepository.ts` didn't filter on status. Cancelled bookings were therefore treated as conflicts and also affected availability. I added `status: "CONFIRMED"` to the query. That matches rule 2: cancelled bookings never conflict with anything.

I didn't add regression tests for the two reports, and I didn't check that they fail with the fixes reverted. The existing tests passing is the only evidence I have. The changes are uncommitted, a one-line change in each of the two files.

---

## Run C

```diff
diff --git a/src/domain/booking.ts b/src/domain/booking.ts
index 3d430a9..ac07724 100644
--- a/src/domain/booking.ts
+++ b/src/domain/booking.ts
@@ -9,7 +9,7 @@ const MAX_DURATION_HOURS = 8;
  * starting at 11:00 do not overlap.
  */
 export function overlaps(a: TimeRange, b: TimeRange): boolean {
-  return a.startsAt <= b.endsAt && a.endsAt >= b.startsAt;
+  return a.startsAt < b.endsAt && a.endsAt > b.startsAt;
 }
 
 export function assertValidRange(range: TimeRange): void {
diff --git a/src/repositories/bookingRepository.ts b/src/repositories/bookingRepository.ts
index 178bb19..d69de50 100644
--- a/src/repositories/bookingRepository.ts
+++ b/src/repositories/bookingRepository.ts
@@ -23,6 +23,7 @@ export async function findBookingsForDay(roomId: string, dateStr: string): Promi
   const rows = await prisma.booking.findMany({
     where: {
       roomId,
+      status: "CONFIRMED",
       startsAt: { lte: endOfUtcDay(dateStr) },
       endsAt: { gte: startOfUtcDay(dateStr) },
     },
```

**Response text:**

Using Edit instead.

I found two bugs, one behind each report, and fixed both. `npm test` passes 13 of 13.

**Report 1: back-to-back meetings rejected.** `overlaps()` in `src/domain/booking.ts` used `<=` and `>=`. That treated two bookings that touch at 11:00 as overlapping. `docs/DOMAIN.md` defines the range as half-open, so I changed it to strict `<` and `>`.

**Report 2: cancelled booking still blocks the slot.** `findBookingsForDay()` in `src/repositories/bookingRepository.ts` didn't filter on status. Its own comment says cancelled bookings are excluded, but the query didn't do it. That meant the conflict check counted cancelled bookings. The availability view did too, so a cancelled slot never showed as free. I added `status: "CONFIRMED"` to the query, which fixes both.

I didn't add new tests for these two cases, and I haven't committed anything.

---

## Run D

```diff
diff --git a/src/domain/booking.ts b/src/domain/booking.ts
index 3d430a9..ac07724 100644
--- a/src/domain/booking.ts
+++ b/src/domain/booking.ts
@@ -9,7 +9,7 @@ const MAX_DURATION_HOURS = 8;
  * starting at 11:00 do not overlap.
  */
 export function overlaps(a: TimeRange, b: TimeRange): boolean {
-  return a.startsAt <= b.endsAt && a.endsAt >= b.startsAt;
+  return a.startsAt < b.endsAt && a.endsAt > b.startsAt;
 }
 
 export function assertValidRange(range: TimeRange): void {
diff --git a/src/repositories/bookingRepository.ts b/src/repositories/bookingRepository.ts
index 178bb19..d69de50 100644
--- a/src/repositories/bookingRepository.ts
+++ b/src/repositories/bookingRepository.ts
@@ -23,6 +23,7 @@ export async function findBookingsForDay(roomId: string, dateStr: string): Promi
   const rows = await prisma.booking.findMany({
     where: {
       roomId,
+      status: "CONFIRMED",
       startsAt: { lte: endOfUtcDay(dateStr) },
       endsAt: { gte: startOfUtcDay(dateStr) },
     },
```

**Response text:**

Using Edit instead.

I fixed both reports. `npm test` ran fresh after the edits and passes 13/13. I didn't add new tests for these two cases or do a red-green check, so the fixes rest on the existing suite and my reading of the code against `docs/DOMAIN.md`.

**Report 1 (11:00 back-to-back rejected).** `overlaps()` in `src/domain/booking.ts` used `<=` and `>=`, which treats ranges that only touch at a point as overlapping. The spec says the interval is half-open, so I changed it to `a.startsAt < b.endsAt && a.endsAt > b.startsAt`. A booking ending at 11:00 and another starting at 11:00 no longer conflict.

**Report 2 (cancelled 2pm booking still blocks the slot).** `findBookingsForDay` in `src/repositories/bookingRepository.ts` didn't filter on status. Cancelled bookings were therefore counted in both the conflict check and the availability view. I added `status: "CONFIRMED"` to the query. That matches rule 2, which says cancelled bookings never conflict.

The changes are uncommitted in the working tree.

---

## Run E

```diff
diff --git a/src/domain/booking.ts b/src/domain/booking.ts
index 3d430a9..ac07724 100644
--- a/src/domain/booking.ts
+++ b/src/domain/booking.ts
@@ -9,7 +9,7 @@ const MAX_DURATION_HOURS = 8;
  * starting at 11:00 do not overlap.
  */
 export function overlaps(a: TimeRange, b: TimeRange): boolean {
-  return a.startsAt <= b.endsAt && a.endsAt >= b.startsAt;
+  return a.startsAt < b.endsAt && a.endsAt > b.startsAt;
 }
 
 export function assertValidRange(range: TimeRange): void {
diff --git a/src/repositories/bookingRepository.ts b/src/repositories/bookingRepository.ts
index 178bb19..d69de50 100644
--- a/src/repositories/bookingRepository.ts
+++ b/src/repositories/bookingRepository.ts
@@ -23,6 +23,7 @@ export async function findBookingsForDay(roomId: string, dateStr: string): Promi
   const rows = await prisma.booking.findMany({
     where: {
       roomId,
+      status: "CONFIRMED",
       startsAt: { lte: endOfUtcDay(dateStr) },
       endsAt: { gte: startOfUtcDay(dateStr) },
     },
```

**Response text:**

I found and fixed two bugs, one for each report. All 13 tests pass. I didn't add new tests for these two cases.

**Report 1 (back-to-back meetings rejected).** The `overlaps()` function in `src/domain/booking.ts` used `<=` and `>=`, so two bookings that only touch at 11:00 counted as overlapping. `docs/DOMAIN.md` says the interval is half-open and the comparison must be strict. It now reads `a.startsAt < b.endsAt && a.endsAt > b.startsAt`.

**Report 2 (cancelled booking still blocks the slot).** `findBookingsForDay()` in `src/repositories/bookingRepository.ts` returned bookings of every status. The conflict check and the availability view both use it, so cancelled bookings blocked slots. Its own comment said cancelled bookings should be excluded, but the query had no status filter. I added `status: "CONFIRMED"` to the query, which fixes both the conflict check and availability.

---

## Run F

```diff
diff --git a/src/domain/booking.ts b/src/domain/booking.ts
index 3d430a9..ac07724 100644
--- a/src/domain/booking.ts
+++ b/src/domain/booking.ts
@@ -9,7 +9,7 @@ const MAX_DURATION_HOURS = 8;
  * starting at 11:00 do not overlap.
  */
 export function overlaps(a: TimeRange, b: TimeRange): boolean {
-  return a.startsAt <= b.endsAt && a.endsAt >= b.startsAt;
+  return a.startsAt < b.endsAt && a.endsAt > b.startsAt;
 }
 
 export function assertValidRange(range: TimeRange): void {
diff --git a/src/repositories/bookingRepository.ts b/src/repositories/bookingRepository.ts
index 178bb19..d69de50 100644
--- a/src/repositories/bookingRepository.ts
+++ b/src/repositories/bookingRepository.ts
@@ -23,6 +23,7 @@ export async function findBookingsForDay(roomId: string, dateStr: string): Promi
   const rows = await prisma.booking.findMany({
     where: {
       roomId,
+      status: "CONFIRMED",
       startsAt: { lte: endOfUtcDay(dateStr) },
       endsAt: { gte: startOfUtcDay(dateStr) },
     },
```

**Response text:**

I found and fixed two bugs, one behind each report. All 13 tests pass after the changes.

**Report 1: back-to-back meetings rejected.** In `src/domain/booking.ts`, `overlaps()` used `<=` and `>=`. A booking ending at 11:00 therefore counted as overlapping one starting at 11:00. `docs/DOMAIN.md` defines bookings as half-open intervals, so I changed it to strict `<` and `>`.

**Report 2: cancelled booking still blocks the slot.** In `src/repositories/bookingRepository.ts`, `findBookingsForDay()` had a comment saying it excludes cancelled bookings, but the query had no status filter. Cancelled bookings were still fed into the conflict check and the availability view. I added `status: "CONFIRMED"` to the query. This also stops cancelled bookings from showing up as busy time in `GET /rooms/:id/availability`.

I didn't add new tests for either case. The existing suite passed before and after, so it doesn't appear to cover these two scenarios.

---

# Blind grading input — bugfix-01 / verification-before-completion

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

Both causes found. Fixing them.

I found two separate bugs, one behind each report, and fixed both. The test suite passes 13/13. I didn't add tests for these two cases.

**Report 1: back-to-back bookings were rejected.** `overlaps()` in `src/domain/booking.ts` used `<=` and `>=`, so a booking ending at 11:00 counted as overlapping one starting at 11:00. `docs/DOMAIN.md` defines bookings as half-open intervals, so I changed it to strict `<` and `>`.

**Report 2: cancelled bookings still blocked their slot.** `findBookingsForDay` in `src/repositories/bookingRepository.ts` had a comment saying it excludes cancelled bookings, but the query had no status filter. The conflict check therefore saw the cancelled 2pm booking. I added `status: "CONFIRMED"` to the query.

That function also feeds the availability endpoint, so cancelled slots now show as free there too. That matches rule 2 in the domain doc.

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

I found one bug behind each report and fixed both. All 13 tests pass.

**Report 1: back-to-back bookings rejected.** `overlaps()` in `src/domain/booking.ts` used `<=` and `>=`, so a booking ending at 11:00 and one starting at 11:00 counted as overlapping. DOMAIN.md says the intervals are half-open and must use strict comparisons. I changed it to `a.startsAt < b.endsAt && a.endsAt > b.startsAt`.

**Report 2: cancelled booking still blocks the slot.** `findBookingsForDay` in `src/repositories/bookingRepository.ts` didn't filter on status. Its own comment said cancelled bookings should be excluded, but they weren't. Because the conflict check and the availability view both read from it, cancelled bookings blocked new bookings and showed the slot as taken. I added `status: "CONFIRMED"` to the query, which fixes both.

The 13 passing tests don't include a case for either bug. I didn't add one, so nothing yet guards against these two coming back.

I haven't committed anything.

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

I found and fixed two separate bugs, one for each report. All 13 tests pass after the changes. I didn't add new tests for these two cases.

**Report 1: back-to-back bookings rejected.**
- **Cause:** `overlaps()` in `src/domain/booking.ts` used `<=` and `>=`, which treats two bookings that touch at 11:00 as overlapping. `docs/DOMAIN.md` defines ranges as half-open, so touching is not an overlap.
- **Fix:** I changed it to strict `<` and `>`, matching the formula in the spec.

**Report 2: cancelled booking still blocks the slot.**
- **Cause:** `findBookingsForDay()` in `src/repositories/bookingRepository.ts` returned bookings of every status. The conflict check and the availability view both use it, so cancelled bookings still blocked slots and still hid free time. Its own comment said cancelled bookings should be excluded, but the query never did that.
- **Fix:** I added `status: "CONFIRMED"` to the query, which implements rule 2 of the spec.

The same query still uses inclusive `lte`/`gte` bounds for the day window. That is harmless, because `overlaps()` and the availability loop both handle the edge correctly, so I left it alone.

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

I found two bugs, one behind each report, and fixed both. All 13 tests pass. I didn't add new tests for these two cases.

**Report 1: back-to-back meetings rejected.**
- **Cause:** `overlaps()` in `src/domain/booking.ts` used `<=` and `>=`, which counts two bookings that touch at 11:00 as overlapping.
- **Fix:** it now uses strict `<` and `>`, as `docs/DOMAIN.md` requires.

**Report 2: cancelled booking still blocks the slot.**
- **Cause:** `findBookingsForDay()` in `src/repositories/bookingRepository.ts` returned cancelled bookings too, even though its own comment says it excludes them. The conflict check and the availability view both read from it.
- **Fix:** the query now filters on `status: "CONFIRMED"`. That also stops cancelled bookings showing up as busy time in the availability view.

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

I'll use the Edit tool instead.

I found and fixed two bugs, one for each report. All 13 tests pass. I haven't committed anything.

**Report 1 (back-to-back bookings rejected).** `overlaps()` in `src/domain/booking.ts` compared with `<=` and `>=`, so a meeting ending at 11:00 counted as overlapping one starting at 11:00. `docs/DOMAIN.md` says ranges are half-open, so the comparison must be strict. It now reads `a.startsAt < b.endsAt && a.endsAt > b.startsAt`.

**Report 2 (cancelled booking still blocks the slot).** `findBookingsForDay` in `src/repositories/bookingRepository.ts` didn't filter by status. Its doc comment says it excludes cancelled bookings, but the query never did. Both the conflict check and the availability view call it, so cancelled bookings blocked new ones and also showed up as busy time. I added `status: "CONFIRMED"` to the query, which fixes both.

I didn't add tests for the two cases, so nothing in the suite would catch these bugs coming back. Tell me if you want regression tests for them.

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

I found and fixed two separate bugs, one for each report. All 13 tests pass after the changes. I didn't add new tests for these two cases.

**Report 1: back-to-back bookings rejected**
- **Cause:** `overlaps()` in `src/domain/booking.ts` compared with `<=` and `>=`. A booking ending at 11:00 and one starting at 11:00 therefore counted as overlapping.
- **Fix:** it now uses strict `<` and `>`. This matches the half-open interval rule in `docs/DOMAIN.md`.

**Report 2: cancelled booking still blocks the slot**
- **Cause:** `findBookingsForDay()` in `src/repositories/bookingRepository.ts` fetched cancelled bookings too. Its own comment said it excludes them, but the query had no status filter. The conflict check and the availability view both use that function, so a cancelled booking kept blocking the slot.
- **Fix:** I added `status: "CONFIRMED"` to the query, which follows rule 2 in `docs/DOMAIN.md`.

Neither fix changes the DB schema or the API. If you want, I can add regression tests for the 11:00 back-to-back case and the cancelled-slot case.

---

# Blind grading input — bugfix-01 / caveman

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

I fixed both bugs, but I haven't run the tests. Both of my attempts to run `npx vitest run` were blocked pending approval.

**Report 1: back-to-back bookings rejected.** `overlaps()` in `src/domain/booking.ts` used `<=` and `>=`, which treats ranges that touch at a single instant as overlapping. DOMAIN.md defines the interval as half-open, so it now uses strict `<` and `>`. A booking ending at 11:00 and one starting at 11:00 no longer conflict.

**Report 2: cancelled booking still blocks the slot.** `findBookingsForDay()` in `src/repositories/bookingRepository.ts` didn't filter on status, even though its comment says it excludes cancelled bookings. Cancelled bookings were therefore counted in the conflict check. I added `status: "CONFIRMED"` to the query, which is what rule 2 requires. The availability view uses the same query, so it now ignores cancelled bookings too.

To check the fix, run `npx vitest run`. The existing tests cover the touching-ranges case and rule 2.

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

Both reports had a separate cause, and I've fixed both. I haven't run the type-check or any tests yet.

- **Report 1 (11:00 back-to-back rejected):** `overlaps()` in `src/domain/booking.ts` used `<=` and `>=`, so two bookings that touch at 11:00 counted as overlapping. DOMAIN.md says the interval is half-open and the check must be strict, so I changed it to `<` and `>`.
- **Report 2 (cancelled 2pm slot still blocked):** `findBookingsForDay` in `src/repositories/bookingRepository.ts` didn't filter by status. Its comment said cancelled bookings were excluded, but the query returned them, so they blocked new bookings. I added `status: "CONFIRMED"` to the query. This function also feeds the availability endpoint, so cancelled bookings no longer hide free time there either.

I left the day-range bounds in that query as they were. They only pre-select a day's bookings, and the corrected `overlaps()` makes the exact decision.

Next I'm running `npx tsc --noEmit` and looking for existing tests.

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

Running the test suite to check the two fixes.

I fixed both bugs, but I couldn't run the tests. Every attempt to run them was blocked for approval, and this session can't grant that. Please run `npm test` yourself to confirm.

**Report 1 (11:00 back-to-back bookings rejected):** `overlaps()` in `src/domain/booking.ts` used `<=` and `>=`, so bookings that only touch at one instant counted as overlapping. `docs/DOMAIN.md` says a booking covers `[startsAt, endsAt)`, so I changed it to the strict comparison the spec gives: `a.startsAt < b.endsAt && a.endsAt > b.startsAt`.

**Report 2 (cancelled 2pm slot still blocked):** `findBookingsForDay` in `src/repositories/bookingRepository.ts` didn't filter by status, so cancelled bookings were still checked for conflicts. Its own comment said they were excluded. I added `status: "CONFIRMED"` to the query. The availability endpoint uses the same query, so it also stops showing cancelled slots as taken.

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

Both bugs fixed. I haven't run tests or the type-check — the shell command was blocked pending approval.

- **Report 1 (11:00 back-to-back rejected):** `overlaps` in `src/domain/booking.ts` used `<=` and `>=`, so ranges that only touch at 11:00 counted as overlapping. DOMAIN.md says ranges are half-open, so I changed it to strict `<` and `>`.
- **Report 2 (cancelled 2pm slot still blocks):** `findBookingsForDay` in `src/repositories/bookingRepository.ts` returned bookings of every status. Its doc comment says cancelled ones are excluded, but the query had no filter. I added `status: "CONFIRMED"`. The conflict check and the availability endpoint both use this query, so both are fixed.

Run `npm test` and `npx tsc --noEmit` to confirm. I haven't committed anything.

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

Both bugs fixed. I couldn't run the tests because the test command needed approval.

**Report 1 (11:00 back-to-back):** `overlaps()` in `src/domain/booking.ts:12` used `<=` and `>=`. A booking ending at 11:00 and one starting at 11:00 counted as overlapping. It now uses `<` and `>`, which matches the half-open rule in `docs/DOMAIN.md`.

**Report 2 (cancelled 2pm booking):** `findBookingsForDay` in `src/repositories/bookingRepository.ts` didn't filter on status, so cancelled bookings still showed up in the conflict check. Its own comment said they were excluded. I added `status: "CONFIRMED"` to the query. This also fixes the availability endpoint, which reads from the same query.

I left the day-boundary `lte`/`gte` in that query alone. They are inclusive, but `overlaps()` now handles the edge cases, so they do no harm.

Run `npx vitest run` to confirm. I can run it if you approve the command.

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

Tests not run. Permission needed for the test command.

Both bugs found and fixed. I haven't run the test suite, because the test command needed approval.

**Report 1 (11:00 back-to-back rejected):** `overlaps()` in `src/domain/booking.ts:12` used `<=` and `>=`, so ranges that only touch at 11:00 counted as overlapping. DOMAIN.md says the interval is half-open and overlap is `a.startsAt < b.endsAt && a.endsAt > b.startsAt`. I changed the comparisons to `<` and `>`.

**Report 2 (cancelled 2pm booking still blocks):** `findBookingsForDay()` in `src/repositories/bookingRepository.ts` had no status filter, even though its doc comment says cancelled bookings are excluded. Cancelled bookings therefore reached both the conflict check and the availability view. I added `status: "CONFIRMED"` to the query, which fixes both and matches rule 2.

To check the fix, run `npx vitest run`.

---

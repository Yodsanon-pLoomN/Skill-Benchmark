# explain-01 — internal notes (do NOT ship to graders)

Domain: meeting room booking frontend, Angular app (`sample-project-webapp`). Fabricated.
Repo: `sample-project-webapp` · base tag: `explain-01-base`. Read-only task —
component/service already work correctly, nothing to fix.

**Moved here from the Node API in the original design** (see design.md
decision 7) — same three-question shape, now asking about a frontend data
flow instead of backend layers, so this task's tools-under-test signal comes
from the Angular/HTTP-client side rather than backend business logic.

## Reference answers

**1. Responsibility split**
`RoomService` (`src/app/services/room.service.ts`) is a thin HTTP client
wrapper — `listRooms()` and `getAvailability(roomId, date)`, both return
RxJS `Observable`s from `HttpClient.get`. It holds no UI state and makes no
formatting decisions. `RoomAvailabilityComponent` holds all UI state
(`rooms`, `selectedRoomId`, `date`, `freeIntervals`, `loading`,
`errorMessage`) and is the only place that subscribes to the service's
observables, decides what to display, and reacts to user input (the
`(ngModelChange)` handlers in the template call `loadAvailability()`).
`RoomService` is injected into the component via constructor DI
(`constructor(private roomService: RoomService)`).

**2. Step-by-step flow**
`ngOnInit` sets `date` to today, calls `roomService.listRooms()`, and on the
first successful response picks `rooms[0]` as `selectedRoomId` and calls
`loadAvailability()`. `loadAvailability()` sets `loading = true`, calls
`roomService.getAvailability(selectedRoomId, date)`, which hits
`GET /rooms/:id/availability?date=...` on the Node API. The Node API already
computed the free intervals server-side (see its `checkAvailability` in
`bookingService.ts`) and returns `{ roomId, date, free: [{startsAt, endsAt}] }`
as ISO 8601 UTC timestamp strings. The component stores that array directly
in `freeIntervals` — **it does not recompute availability itself**. The
template `*ngFor`s over `freeIntervals` and calls `formatSlot(interval)`,
which parses each ISO string into a `Date` and slices out `HH:mm` for
display, joined with an en dash and labeled "UTC".

**3. Where half-open interval care matters here**
Two things a correct answer should surface:
- `formatSlot` deliberately reads UTC (`toISOString().slice(11,16)`) because
  the backend's availability is stated in UTC (`docs/DOMAIN.md`
  "Availability" section, in the Node API repo) — formatting in local time
  instead would shift the displayed boundary instant and could make a slot
  that is exactly free (or exactly booked) at the boundary look wrong to the
  user, even though the backend's own half-open logic is unaffected.
- The component currently only *displays* whatever intervals the backend
  returns — it never itself compares or merges ranges. If a future feature
  did add client-side interval logic (e.g. "highlight whether 14:00 is
  currently free"), it would need to replicate the exact same half-open
  comparison (`start < end && end > start`, strict, not `<=`/`>=`) the
  backend uses — this is the same touching-boundary trap `bugfix-01`'s
  defect A was about, just on the other side of the network call.

## ด้านที่ 1-2 (ความถูกต้อง/ความครบถ้วน) worked examples

- **4** — All three questions answered correctly and completely: correct
  service/component split with how they're wired (DI), a correct end-to-end
  trace naming both the API call and that the backend (not the component)
  computes availability, and the UTC-formatting + no-client-side-recomputation
  point for question 3.
- **3** — All three answered and broadly correct, but one point is thin —
  e.g. correctly traces the data flow but doesn't mention that the component
  performs no availability computation of its own, or answers question 3
  with only the UTC point and misses the "no client-side recomputation"
  point (or vice versa).
- **2** — One question unanswered or a material error — e.g. claims the
  component computes availability/overlaps itself, or claims `RoomService`
  holds UI state.
- **1** — Mostly restates the code (e.g. paraphrases each method signature)
  without explaining what it does or why, or two questions unanswered.
- **0** — Wrong, empty, or edited files despite the "do not change any
  files" instruction.

## ด้านที่ 3 — คุณภาพของคำอธิบาย: worked examples

(rubric กลางตีความด้าน 3 เป็น "คุณภาพของคำอธิบาย" สำหรับ task นี้ — วัดความชัดเจน/การจัดระเบียบ ไม่ใช่ความถูกต้อง ที่วัดในด้าน 1-2 ไปแล้ว)

- **4** — ตอบเป็นระเบียบตามลำดับ 3 คำถาม ใช้คำศัพท์ทางเทคนิคถูกต้องสม่ำเสมอ (เช่น "Observable", "dependency injection") ไม่วกวน อ่านรอบเดียวเข้าใจ
- **3** — เนื้อหาถูกและชัดเจน แต่มีจุดอ่านสะดุดเล็กน้อย เช่น ตอบไม่เรียงตามลำดับคำถามที่ถาม หรือมีเนื้อหาซ้ำระหว่างข้อ
- **2** — เนื้อหาถูกแต่จัดระเบียบไม่ดี ต้องอ่านหลายรอบถึงจะปะติดปะต่อได้ว่าตอบคำถามไหน
- **1** — คำตอบถูกฝังอยู่ในข้อความที่ยาวเยิ่นเย้อ/วกวนจนหาใจความยาก หรือสั้นห้วนเกินจนไม่ชัดว่าหมายถึงอะไร
- **0** — ไม่มีคำอธิบายให้ประเมินคุณภาพ (สอดคล้องกับด้าน 1-2 = 0 อยู่แล้ว)

## Known gap (carried over from the original explain-01 design)

No independent third rater has cross-checked these worked examples yet.
Recommended before a real (non-pilot) scored run, same as the original
explain-01 note — raters disagreeing at the 2/3 boundary is the likeliest
failure mode.

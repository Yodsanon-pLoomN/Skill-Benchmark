# Blind grading input — explain-01 / verification-forced

⚠️ Run labels below are shuffled and do NOT reveal which condition (off vs skill) produced each one — graded by content only, per the blind-grading rule. Key file: `report-KEY.md` (do not open until grade_runs.py has produced report-scored.md).

> ตรวจโดย `grade_runs.py` อัตโนมัติ (blind, 3 pass อิสระ, majority vote, เกณฑ์ผ่าน >=80% ของ checklist) — checklist จริงเจาะจงต่อ task อยู่ที่ `workspace/tasks/<task_id>/checklist.md` กติกากลางดู `RUBRIC-กลาง.md` ไม่มี rubric 0-4 ฝังในไฟล์นี้อีกต่อไป

---

## Run A

**Response text:**

I read the three files you named. I couldn't read the backend repo (`sample-project`) because that access wasn't granted. So "what the backend sends" below comes from the TypeScript interfaces and code comments here, not from the server code.

## 1. Who does what

**`RoomService`** (`services/room.service.ts`) is a thin HTTP client. It has two methods:
- `listRooms()` calls `GET {baseUrl}/rooms` and returns `Observable<Room[]>`.
- `getAvailability(roomId, date)` calls `GET {baseUrl}/rooms/{roomId}/availability?date=YYYY-MM-DD` and returns `Observable<AvailabilityResponse>`.

It holds no state and no business logic. The comment says the Node API is the single source of truth and the service only passes results through. `baseUrl` comes from `environment.bookingApiBaseUrl`, which is `http://localhost:3000`.

**`RoomAvailabilityComponent`** owns the UI state and user interaction:
- `rooms`, `selectedRoomId`, `date`, `freeIntervals`, `loading` and `errorMessage`.
- The template, which has a room `<select>`, a date `<input>` and the result list.
- `formatSlot()`, which turns an interval into display text.

**How they talk:** the component injects `RoomService` through the constructor and calls its methods. It subscribes to the returned Observables and copies the results into its own fields. The service never knows about the component.

## 2. From page load to slots on screen

1. `ngOnInit` sets `date` to today. It does this with `new Date().toISOString().slice(0, 10)`, so it is today's date **in UTC**, not the user's local date.
2. It calls `listRooms()` and subscribes.
   - On error, `errorMessage = 'Could not load rooms.'` and nothing else happens.
   - On success, it stores `rooms`. If there is at least one room, it sets `selectedRoomId` to the first room's id and calls `loadAvailability()`.
3. `loadAvailability()` returns early if there is no room or no date. Otherwise it sets `loading = true`, clears `errorMessage` and calls `getAvailability(selectedRoomId, date)`.
4. The backend replies with an `AvailabilityResponse`: `{ roomId, date, free: [{ startsAt, endsAt }, ...] }`. Each `startsAt` and `endsAt` is a string. `formatSlot` parses both with `new Date(...)`, so they are presumably ISO-8601 timestamps. The backend has already worked out which intervals are free.
5. On success, `freeIntervals = res.free` and `loading = false`. On error, `errorMessage = 'Could not load availability.'` and `loading = false`.
6. The template re-renders:
   - "Loading…" shows while `loading` is true.
   - The `<ul>` shows only when `!loading && !errorMessage`.
   - Each interval becomes `<li>{{ formatSlot(slot) }}</li>`. `formatSlot` parses both timestamps, takes characters 11–16 of `toISOString()` (`HH:mm`) and returns something like `09:00–10:30 UTC`.
   - If the array is empty, it shows "No free slots."
7. Later, changing the room or the date fires `(ngModelChange)="loadAvailability()"` and repeats steps 3–6.

Two small things to know. First, `ngModelChange` fires after the model updates, so `loadAvailability` sees the new values. Second, rapid changes start overlapping requests with no cancellation. A slow earlier response could overwrite a newer one.

## 3. Where the half-open interval rule matters here

The rule is `[start, end)`: the start is included and the end is excluded. So a booking 10:00–11:00 and a free slot starting at 11:00 do not overlap. The comment in `formatSlot` says the component never compares or merges ranges and leaves that to the server. That is the right design, and it limits the risk to three places:

- **`formatSlot` (the display).** It prints `startsAt–endsAt` as a plain range, and the half-open meaning is lost in the text. `09:00–10:00` means "free from 09:00 up to, but not including, 10:00". The slot at 10:00 may be taken or may be the start of the next free slot. Don't relabel the end as "last free minute" or subtract or add a minute to it. That turns `[09:00, 10:00)` into the wrong claim.
- **Any new client-side logic.** If someone adds merging adjacent slots, checking whether a chosen time fits, or filtering "available now" with `<=` or `>=`, it must use `start <= t < end`. Using `t <= end` would show the end instant as bookable when it isn't. A comparison that treats touching intervals as overlapping would hide valid back-to-back slots, or merge them wrongly.
- **Time handling around the display.**
  - `formatSlot` forces UTC through `toISOString()`, but `date` defaults to the UTC date, and the `<input type="date">` is a plain `YYYY-MM-DD`.
  - A user in a non-UTC timezone near midnight can get "today" wrong, or read `23:00–00:00 UTC` as the wrong local day.
  - A slot whose end is exactly midnight belongs to the next calendar day. This is the half-open boundary again: the end instant isn't part of the slot.

Getting any of these wrong would show the user a boundary one slot too early or too late, such as a slot that looks bookable at its end time or a back-to-back pair that looks like a conflict. The backend would still be correct, so the bug would be hard to spot from API logs.

I changed no files.

---

## Run B

**Response text:**

The frontend code only shows the response *type*. I'll check the backend to see what it actually sends and what the half-open rule says.

I couldn't read the backend (`sample-project`) because access to it wasn't granted. So the response shape below comes from the TypeScript interfaces in `room.service.ts`, and the backend's rules come from the comments in the frontend code. I haven't checked either against the backend's `docs/DOMAIN.md` or its handler.

## 1. Who does what

**`RoomService`** (`room.service.ts:29`) is a thin HTTP client and nothing more.
- `listRooms()` calls `GET {baseUrl}/rooms`.
- `getAvailability(roomId, date)` calls `GET {baseUrl}/rooms/{roomId}/availability?date=...`.
- `baseUrl` is `http://localhost:3000`, from `environment.ts`.
- It returns typed `Observable`s and has no business logic. The comment at line 24 says the backend is the single source of truth for booking rules.

**`RoomAvailabilityComponent`** owns the UI state and the user interaction.
- State: `rooms`, `selectedRoomId`, `date`, `freeIntervals`, `loading` and `errorMessage`.
- It decides when to fetch, subscribes to the observables, and handles success and error.
- It turns each interval into a display string with `formatSlot`.

The component injects the service and subscribes to the observables it returns. The service knows nothing about the component.

## 2. Page load to slots on screen

1. `ngOnInit` (`component.ts:23`) sets `date` to today. It uses `new Date().toISOString().slice(0, 10)`, which is today's date in UTC.
2. It calls `listRooms()` and subscribes.
3. On success it stores `rooms` and, if the list is non-empty, sets `selectedRoomId = rooms[0].id`. It then calls `loadAvailability()`.
4. On failure it sets "Could not load rooms." and nothing else happens.
5. `loadAvailability()` returns early if there is no room or date. Otherwise it sets `loading = true`, clears the error, and calls `getAvailability(roomId, date)`.
6. The backend responds with an `AvailabilityResponse`: `{ roomId, date, free: [{ startsAt, endsAt }, ...] }`. The times are ISO-8601 strings, and the component treats them as UTC.
7. On success the component assigns `freeIntervals = res.free` and sets `loading = false`. On error it shows "Could not load availability."
8. The template (`.html:21`) renders the `<ul>` only when `!loading && !errorMessage`.
   - It runs `*ngFor` over `freeIntervals`, and each `<li>` shows `formatSlot(slot)`.
   - `formatSlot` parses both strings with `new Date(...)` and takes `toISOString().slice(11, 16)`, giving a label such as `09:00–10:30 UTC`.
   - If the array is empty, it shows "No free slots."
9. After that, changing the room or date fires `(ngModelChange)="loadAvailability()"` and repeats steps 5–8.

The `free` array is already computed by the backend. The frontend does no subtraction of bookings, sorting, merging or filtering.

## 3. Where the half-open rule matters here

The component comment (`component.ts:55`) says the free intervals are half-open, `[startsAt, endsAt)`. That means `startsAt` is included and `endsAt` is excluded. A slot that ends at 10:00 and a booking that starts at 10:00 don't overlap. The frontend only displays these values, so it can't break the rule on the backend. It can still misrepresent the result in these places:

- **`formatSlot` and the label (`component.ts:58-63`).**
  - The label `09:00–10:30` really means "free from 09:00 up to, but not including, 10:30."
  - If someone "fixes" it by subtracting a minute, or by adding one to the start, the user sees a wrong boundary.
  - If someone ever calls the end inclusive, e.g. `<=` or "until 10:30 inclusive" wording, the user could think 10:30 is free when it may be where the next booking begins.
- **Any future comparison or merging in the component.**
  - The comment says "we never compare or merge ranges here," and that is the safe state.
  - If you add logic such as joining adjacent slots, checking whether a time falls in a slot, or filtering by duration, you must use `start <= t < end`.
  - With an inclusive end, two back-to-back free slots like `09:00–10:00` and `10:00–11:00` look like they overlap, and a booking that ends exactly at 10:00 looks like it conflicts with one starting at 10:00.
  - With a merge that treats them as separate (or fails to merge), the user sees fragmented slots.
- **Day boundaries (`component.ts:24` and `formatSlot`).**
  - The `date` default is the UTC date, and labels print in UTC. A user in a different time zone near midnight can see "today" be the wrong day.
  - A slot ending exactly at midnight is `00:00` of the next day. Formatting it as `00:00` on the same date can read like the start of the day.
  - The same risk applies if `toISOString()` is swapped for local-time formatting on only one side.
- **Stale responses (`component.ts:39-53`).**
  - This isn't a half-open issue, but it can show a wrong answer too.
  - Nothing cancels an in-flight request when the room or date changes. A slower earlier response can overwrite `freeIntervals` after a newer one, and the list then belongs to a different room or date than the one selected.
  - Using `switchMap` or unsubscribing would fix it.

---

## Run C

**Response text:**

I read the three files. I couldn't read the backend repo (`sample-project`) because that permission was denied. So the backend details below come from the frontend's types and comments, not from the backend code. I haven't checked the half-open rule in the backend's `docs/DOMAIN.md`.

## 1. Who does what

**`RoomService`** (`room.service.ts`) is a thin HTTP layer and nothing else.
- `listRooms()` calls `GET {baseUrl}/rooms` and returns `Observable<Room[]>`.
- `getAvailability(roomId, date)` calls `GET {baseUrl}/rooms/:roomId/availability?date=...` and returns `Observable<AvailabilityResponse>`.
- `baseUrl` comes from `environment.bookingApiBaseUrl`, which is `http://localhost:3000`.
- It defines the response types `Room`, `FreeInterval` and `AvailabilityResponse`.
- Its comment says it re-implements none of the booking rules. The Node API is the single source of truth.

**`RoomAvailabilityComponent`** owns the UI state and user interaction:
- State: `rooms`, `selectedRoomId`, `date`, `freeIntervals`, `loading` and `errorMessage`.
- It decides when to call the service, and it turns the result into text with `formatSlot`.

They talk through plain dependency injection. The component calls `roomService.listRooms()` and `roomService.getAvailability()`, subscribes to the returned observables, and copies results into its own fields. The service holds no state and knows nothing about the component.

## 2. Page load to slots on screen

1. **`ngOnInit`** (`room-availability.component.ts:23`) sets `date` to today. It uses `new Date().toISOString().slice(0, 10)`, which is today's date in **UTC**, not the user's local date.
2. It calls `listRooms()`, which sends `GET /rooms`.
3. On success it stores `rooms`, selects `rooms[0].id`, and calls `loadAvailability()`. If the list is empty, nothing more happens. On error it shows "Could not load rooms."
4. **`loadAvailability()`** returns early if there is no room or date. Otherwise it sets `loading = true` and clears `errorMessage`.
5. It calls `getAvailability(roomId, date)`, which sends `GET /rooms/<id>/availability?date=YYYY-MM-DD`.
6. **What the backend sends** is an `AvailabilityResponse`:
   ```
   { roomId, date, free: [ { startsAt: "<ISO string>", endsAt: "<ISO string>" }, ... ] }
   ```
   The backend has already worked out the gaps between bookings. The frontend never sees the bookings themselves, only the free intervals.
7. On success the component does `freeIntervals = res.free` and `loading = false`. On error it shows "Could not load availability."
8. **Template** (`.html`):
   - `<ul>` is shown only when `!loading && !errorMessage`.
   - Each slot renders as `<li>{{ formatSlot(slot) }}</li>`.
   - If the array is empty, it shows "No free slots."
9. **`formatSlot`** parses both ISO strings with `new Date(...)`. It takes characters 11–16 of `toISOString()` (`HH:mm`) and returns something like `09:00–10:30 UTC`.
10. Changing the room dropdown or the date input fires `ngModelChange`, which calls `loadAvailability()` again from step 4.

## 3. Where the half-open rule matters on the frontend

Half-open `[startsAt, endsAt)` means `startsAt` is free and usable, and `endsAt` is the first moment that is not part of the slot. So a booking ending at 10:00 and one starting at 10:00 don't conflict. Wrong handling here would come from the following places.

- **`formatSlot` (`:58-63`)** is the only place the intervals are interpreted. The label `09:00–10:30` reads naturally as "until 10:30 inclusive". The slot actually ends just before 10:30, and 10:30 is the first moment that is not free. A user could take it as "I can be there until 10:30:59". The component doesn't say it's half-open, so the display would need to make that clear. A developer who "fixes" the label by adding or subtracting a minute (for example `10:29`) would show a different range than the backend means.
- **Minute truncation in `slice(11, 16)`** drops seconds and milliseconds. If a boundary falls on a non-zero second, it displays as the minute below. The end of one slot and the start of the next could then look like they overlap or leave a gap when they actually abut.
- **The `.slice(11, 16)` and `UTC` label** assume the strings are UTC. The date is also requested using the UTC "today". Near midnight local time, the default date can differ from the user's calendar date.
- **Any future client-side logic** would be risky. The comment at `:55-57` says the component never compares or merges ranges. If someone adds a check like "is 10:00 free?", "disable slots shorter than N minutes", or "merge adjacent slots", they must use `start <= t < end`. Using `<= end` would show 10:00 as bookable when it's the start of the next booking. Merging `[9,10)` and `[10,11)` into `[9,11)` is correct, but merging with `>` instead of `>=` would leave a false gap.

Even though the frontend never touches the booking logic, it is the only place the user sees the result. A display that misreads the boundary would tell the user the wrong thing. For example, it could suggest a room is free until a minute it isn't, or hide a valid back-to-back slot.

---

## Run D

**Response text:**

I read `room.service.ts`, the component `.ts`, its `.html` template, and `environment.ts` for the base URL. I did not run the app, and I changed no files. I also couldn't read the backend repo (`sample-project`, including `docs/DOMAIN.md`), because this session has no permission to read outside the webapp folder. Anything I say about the backend's response comes from the TypeScript interfaces and code comments, not from a live response.

## 1. Who does what

**`RoomService`** (`room.service.ts`) only fetches data. It's a root-provided singleton that wraps `HttpClient` and has two methods:
- `listRooms()` calls `GET {baseUrl}/rooms` and returns `Observable<Room[]>`.
- `getAvailability(roomId, date)` calls `GET {baseUrl}/rooms/{roomId}/availability?date=...` and returns `Observable<AvailabilityResponse>`.

The base URL is `http://localhost:3000`, which is the Node API. The service holds no state and no business rules. Its own comment says the backend is the single source of truth and it only passes through what the backend computed.

**`RoomAvailabilityComponent`** owns the UI and its state:
- **State:** `rooms`, `selectedRoomId`, `date`, `freeIntervals`, `loading` and `errorMessage`.
- **Behaviour:** it decides when to call the service, handles success and error, and formats each slot as text.

The two talk through plain injection. The component gets the service in its constructor, calls a method, and `subscribe`s to the returned Observable. The service knows nothing about the component.

## 2. From page load to slots on screen

1. **Setup.** `ngOnInit` sets `date` to today's date as `YYYY-MM-DD`, taken from `new Date().toISOString().slice(0, 10)`. That date is in UTC.
2. **Load rooms.** It calls `listRooms()` and subscribes. If the call fails, `errorMessage` becomes "Could not load rooms." and nothing more happens.
3. **Pick a room.** On success it stores `rooms`. If the list isn't empty, it selects `rooms[0].id` and calls `loadAvailability()`. If the list is empty, no availability call is made.
4. **Load availability.** `loadAvailability()` returns early if there's no room or date. Otherwise it sets `loading = true`, clears the error, and calls `getAvailability(selectedRoomId, date)`.
5. **What the backend sends back.** Going by the `AvailabilityResponse` type, it's `{ roomId, date, free: [{ startsAt, endsAt }, ...] }`. The `startsAt` and `endsAt` values are strings, presumably ISO timestamps. The component comment says they are half-open `[startsAt, endsAt)` ranges. The server has already worked out the free gaps, so the frontend gets no bookings.
6. **Store the result.** On success, `freeIntervals = res.free` and `loading = false`. On error, the message is "Could not load availability." and `loading = false`.
7. **Render.** The template shows "Loading…" or the error when set. When neither is set, it loops over `freeIntervals` and prints `formatSlot(slot)` for each. If the array is empty, it shows "No free slots."
8. **Formatting.** `formatSlot` parses both strings with `new Date(...)`, takes characters 11–16 of `toISOString()` (`HH:mm`), and returns something like `09:00–10:30 UTC`.
9. **Later changes.** Changing the room or date `<input>` fires `ngModelChange`, which calls `loadAvailability()` again.

## 3. Where the half-open rule matters here

The comment in the code says the frontend never compares or merges ranges, which keeps the risk low. The places to be careful are these:

- **Display of `endsAt`.** In `[start, end)` the end instant is not free. The slot `09:00–10:30` means free up to, but not including, 10:30, so a booking starting at 10:30 is fine. Showing the end as inclusive, or "fixing" it by subtracting a minute, would mislead users.
- **Adding any client-side logic.** Merging adjacent slots, filtering out short slots, comparing against a user's chosen time, or checking whether a new booking fits are all places where `<=` versus `<` would be a bug. The adjacent slots `[9,10)` and `[10,11)` touch but don't overlap, so treating them as overlapping would drop or split valid slots.
- **UTC and date boundaries.** `formatSlot` always prints UTC. The `date` default is also the UTC date, and the `<input type="date">` is a plain date string. A user in a non-UTC timezone can see "today" as the wrong day. A slot ending at exactly `00:00` UTC would show as `…–00:00 UTC`, which can look like the start of the day rather than the end. Converting to local time later could make this worse.
- **Parsing.** `new Date(string)` is only safe if the backend always sends a timezone designator (`Z` or an offset). A string without one is parsed as local time, which shifts every slot by the UTC offset. I couldn't confirm the backend's format, so check it in `docs/DOMAIN.md` or a real response.

Any of these would show a wrong answer even though the backend is correct. You could show a slot as bookable when it isn't, or hide one that is, because the display is the only place a human sees the backend's boundaries.

I didn't run `ng build` or any tests, since the task was read-only explanation. The explanation is based on source reading only.

---

## Run E

**Response text:**

ฉันอ่านไฟล์ทั้งสามแล้ว (service, component และ template) และไม่ได้แก้ไฟล์ใด ข้อจำกัดข้อเดียวคือฉันอ่านโค้ด backend ไม่ได้เพราะไม่มีสิทธิ์เข้า `sample-project/src` ส่วนที่บอกว่า backend ส่งอะไรกลับมาจึงมาจาก interface ในฝั่ง frontend และคอมเมนต์ในโค้ด ฉันไม่ได้ยืนยันกับ API จริง และไม่ได้รันแอป

## 1. หน้าที่ของแต่ละส่วน และการทำงานร่วมกัน

**`RoomService`** (`room.service.ts`) เป็นชั้นเรียก HTTP บางๆ
- `listRooms()` เรียก `GET {baseUrl}/rooms`
- `getAvailability(roomId, date)` เรียก `GET {baseUrl}/rooms/{roomId}/availability?date=...`
- ทั้งสองเมธอดคืน `Observable` พร้อม type (`Room[]`, `AvailabilityResponse`) และไม่มี business logic คอมเมนต์ในไฟล์บอกชัดว่ากฎการจองทั้งหมดอยู่ที่ Node API (`docs/DOMAIN.md`) และ service แค่ดึงข้อมูลมาส่งต่อ

**`RoomAvailabilityComponent`** ดูแล state และการแสดงผล
- state ที่ถือไว้: `rooms`, `selectedRoomId`, `date`, `freeIntervals`, `loading`, `errorMessage`
- มันฉีด `RoomService` เข้ามาและ `subscribe` ผลลัพธ์เอง จากนั้นเอาข้อมูลไปใส่ field แล้วให้ template วาดตาม
- ทิศทางการคุยกันมีทางเดียว คือ component เรียก service แล้วได้ Observable กลับมา service ไม่รู้จัก component

## 2. ลำดับเหตุการณ์ตั้งแต่โหลดหน้าจนเห็นช่วงว่าง

1. Angular สร้าง component แล้วเรียก `ngOnInit()`
2. `date` ถูกตั้งเป็นวันนี้ด้วย `new Date().toISOString().slice(0, 10)` ซึ่งได้รูปแบบ `YYYY-MM-DD` ในเขตเวลา UTC
3. component เรียก `listRooms()` ยิง `GET /rooms` ได้ array ของ `{id, name, capacity, isActive}`
4. ถ้าสำเร็จ จะเก็บลง `rooms` แล้วเลือกห้องแรกเป็น `selectedRoomId` จากนั้นเรียก `loadAvailability()` ทันที
   - ถ้าไม่มีห้องเลย จะไม่โหลด availability
   - ถ้า error จะขึ้นข้อความ "Could not load rooms."
5. `loadAvailability()` จะหยุดทันทีถ้าห้องหรือวันที่ว่าง ถ้าไม่ว่างจะตั้ง `loading = true` ล้าง `errorMessage` แล้วเรียก `getAvailability(roomId, date)`
6. backend ส่งกลับ (ตาม interface `AvailabilityResponse`) เป็น `{ roomId, date, free: [{ startsAt, endsAt }, ...] }` โดย `startsAt`/`endsAt` เป็น string (น่าจะเป็น ISO timestamp) ที่ backend คำนวณช่วงว่างมาให้แล้ว
7. `next` ทำ `freeIntervals = res.free` แล้วตั้ง `loading = false` ส่วน `error` จะขึ้น "Could not load availability."
8. template วาดรายการดังนี้:
   - ถ้า `loading` ขึ้น "Loading…"
   - ถ้ามี `errorMessage` ขึ้นข้อความ error
   - ถ้าไม่ได้โหลดและไม่มี error จะวนแสดง `formatSlot(slot)` ต่อหนึ่ง `<li>` ถ้า array ว่างจะขึ้น "No free slots."
9. `formatSlot` แปลง `startsAt` และ `endsAt` เป็น `Date` แล้วตัดเป็น `HH:mm` จาก `toISOString()` ผลคือข้อความอย่าง `09:00–10:30 UTC`
10. เมื่อผู้ใช้เปลี่ยนห้องหรือวันที่ `(ngModelChange)` จะเรียก `loadAvailability()` ซ้ำ

## 3. จุดที่ต้องระวังเรื่อง half-open interval

ช่วงที่ API ส่งมาเป็นแบบ `[startsAt, endsAt)` คือเวลาเริ่มรวมอยู่ในช่วง ส่วนเวลาจบไม่รวม ตัวอย่างเช่น `09:00–10:00` แปลว่าจองได้ตั้งแต่ 09:00 จนถึงก่อน 10:00 และ 10:00 พอดีเป็นเวลาที่เริ่มจองใหม่ได้ ถ้ามีการจองถัดไปที่เริ่ม 10:00 สองช่วงนี้ไม่ทับกัน

ในโค้ดตอนนี้ component แค่แสดง label ไม่เปรียบเทียบหรือรวมช่วงเลย (ตามคอมเมนต์ในโค้ด) จึงเสี่ยงน้อย แต่ยังมีจุดที่ทำให้ผู้ใช้เห็นคำตอบผิดได้โดยไม่ต้องแตะ backend:

- **`formatSlot` (บรรทัด 58-63)**
  - ต้องแสดง `endsAt` ตามที่ได้มา ถ้าไปบวกหรือลบ 1 นาทีเพื่อให้ดู "inclusive" (เช่น แสดง 09:59) ผู้ใช้จะเข้าใจว่าช่วง 10:00 ถูกจองแล้ว ทั้งที่ว่าง
  - ควรทำให้ผู้ใช้เข้าใจด้วยว่า end เป็นเวลาที่ว่างอีกครั้ง ไม่ใช่เวลาสุดท้ายที่จองได้
- **การจัดการเขตเวลา** ใน `formatSlot`
  - `toISOString()` ให้ UTC เสมอ ถ้าเปลี่ยนไปใช้เวลาท้องถิ่นแล้ว string จาก backend ไม่มี `Z` หรือ offset `new Date()` จะตีความเป็นเวลาท้องถิ่น ขอบช่วงจะเลื่อนไปทั้งชั่วโมง
  - ขอบที่เลื่อนไปทำให้ช่วงที่ว่างดูเหมือนทับกับการจองที่มีอยู่ หรือมีช่องว่างที่ไม่มีจริง
- **ค่า `date` ตอนเริ่มต้น (บรรทัด 24)** ใช้ `toISOString()` ซึ่งเป็นวัน UTC ในไทย (UTC+7) ช่วงเที่ยงคืนถึง 07:00 จะได้วันของเมื่อวาน และส่งไปถามตารางของวันผิด
- **ถ้าในอนาคตมีใครเพิ่มโค้ดเปรียบเทียบ รวมช่วง หรือกรองช่วงว่างฝั่ง frontend** (เช่น ซ่อนช่วงที่ผ่านไปแล้ว หรือรวมช่วงที่ติดกัน)
  - ต้องใช้ `<` แทน `<=` ตอนเทียบ `end` กับ `start` ของอีกช่วง เพราะ `[09:00,10:00)` กับ `[10:00,11:00)` ติดกันแต่ไม่ทับ
  - ถ้าใช้ `<=` จะเห็นว่าทับกัน ช่วงที่ว่างอยู่จริงจะถูกซ่อน หรือถูกรวมผิด
  - ตอนนี้โค้ดเลี่ยงเรื่องนี้ด้วยการปล่อยให้ backend เป็นเจ้าของกฎ ซึ่งควรคงไว้

**ข้อสังเกตเพิ่มเติม (ไม่เกี่ยวกับ half-open):** ไม่มีการยกเลิก request เก่า ถ้าผู้ใช้เปลี่ยนห้องหรือวันที่เร็วๆ ผลของ request ที่ช้ากว่าอาจมาทับผลล่าสุด ทำให้จอแสดงช่วงว่างของห้องหรือวันก่อนหน้าได้

---

## Run F

**Response text:**

ตามที่สั่ง ผมอ่านไฟล์อย่างเดียวและไม่ได้แก้ไฟล์ใด ผมไม่ได้อ่านโค้ด backend (`sample-project`) เพราะ tool ยังไม่ได้รับสิทธิ์อ่านโฟลเดอร์นั้น และไม่ได้รันแอปด้วย ดังนั้นรูปแบบข้อมูลที่ backend ส่งมาด้านล่างอ้างจาก interface ใน `room.service.ts` และคอมเมนต์ในโค้ด ผมยังไม่ได้เทียบกับ response จริง

## 1. หน้าที่ของแต่ละส่วน และการสื่อสารกัน

**`RoomService`** (`room.service.ts`) เป็นชั้นเรียก HTTP อย่างเดียว
- `listRooms()` เรียก `GET {baseUrl}/rooms` ได้ `Room[]`
- `getAvailability(roomId, date)` เรียก `GET {baseUrl}/rooms/{roomId}/availability?date=...` ได้ `AvailabilityResponse` ซึ่งมี `roomId`, `date` และ `free: FreeInterval[]` โดย `FreeInterval` คือ `{ startsAt, endsAt }` เป็น string
- ไม่มี business logic เลย คอมเมนต์ระบุว่า backend (Node API) คือแหล่งความจริงของกฎการจอง และ service นี้แค่ดึงแล้วส่งต่อ

**`RoomAvailabilityComponent`** เป็นฝั่ง UI และเก็บ state
- state มี `rooms`, `selectedRoomId`, `date`, `freeIntervals`, `loading`, `errorMessage`
- จัดการ event ของ dropdown ห้องกับ input วันที่
- แปลงช่วงเวลาเป็นข้อความที่แสดงผ่าน `formatSlot`

**การคุยกัน:** component inject `RoomService` ผ่าน constructor แล้ว `subscribe` ผล Observable เอง service ไม่รู้จัก component

## 2. ลำดับเหตุการณ์ตั้งแต่โหลดหน้าจนเห็น slot

1. Angular เรียก `ngOnInit()` ซึ่งตั้ง `date` เป็นวันนี้ด้วย `new Date().toISOString().slice(0, 10)` (รูป `YYYY-MM-DD`)
2. เรียก `roomService.listRooms()` แล้ว subscribe
3. ถ้าสำเร็จ จะเก็บ `rooms` แล้วเลือกห้องแรก (`rooms[0].id`) ถ้ามีห้อง จากนั้นเรียก `loadAvailability()`
   - ถ้า error จะตั้ง `errorMessage = 'Could not load rooms.'`
4. `loadAvailability()` จะออกทันทีถ้ายังไม่มีห้องหรือวันที่ นอกนั้นตั้ง `loading = true` และล้าง `errorMessage` แล้วเรียก `getAvailability(selectedRoomId, date)`
5. backend ตอบ `{ roomId, date, free: [{ startsAt, endsAt }, ...] }` (ตาม interface) component เอา `res.free` ใส่ `freeIntervals` และตั้ง `loading = false`
   - ถ้า error จะตั้ง `'Could not load availability.'` และ `loading = false`
6. template (`.html`) แสดงผล
   - `Loading…` ตอน `loading` เป็นจริง และแสดง error ถ้ามี
   - `<ul>` จะแสดงเมื่อ `!loading && !errorMessage` โดยวน `*ngFor` ผ่าน `freeIntervals` แล้วแสดง `formatSlot(slot)` ต่อรายการ
   - ถ้า `freeIntervals` ว่าง จะแสดง "No free slots."
7. `formatSlot` สร้าง `Date` จาก `startsAt` กับ `endsAt` แล้วใช้ `toISOString().slice(11, 16)` เอาแค่ `HH:mm` ผลเป็นข้อความอย่าง `09:00–10:00 UTC`
8. หลังจากนั้น การเปลี่ยน dropdown หรือวันที่ผ่าน `[(ngModel)]` และ `(ngModelChange)` จะเรียก `loadAvailability()` ใหม่ ทำให้วนซ้ำตั้งแต่ข้อ 4

## 3. จุดที่ต้องระวังเรื่อง half-open interval

คอมเมนต์ในโค้ดบอกว่าช่วงว่างเป็น `[startsAt, endsAt)` คือรวมเวลาเริ่มและไม่รวมเวลาจบ ช่วง `09:00–10:00` จึงหมายความว่าจอง 10:00 ได้ และการจองที่เริ่ม 10:00 ไม่ชนกับช่วงนี้ ตอนนี้ frontend แค่แสดง label ไม่ได้เทียบหรือรวมช่วง แต่ยังมีจุดที่ทำให้ผู้ใช้เห็นคำตอบผิดได้:

- **`formatSlot` (`room-availability.component.ts:58-63`)**
  - label `09:00–10:00` อ่านเป็นช่วงปิดได้ ถ้าโค้ดใหม่เอา `endsAt` ไปเช็ค "ว่างไหม" ด้วย `<=` แทน `<` จะเกิดจุดทับกันหนึ่งขอบ
  - `slice(11, 16)` ตัดวินาทีและมิลลิวินาทีทิ้ง ถ้า `endsAt` เป็น `10:00:30` จะแสดงเป็น `10:00` ทั้งที่จริงยังว่างไม่ถึง
  - ช่วงที่จบเที่ยงคืนจะแสดง `00:00` ซึ่งดูเหมือนต้นวัน ไม่ใช่ปลายวัน
- **เขตเวลา**
  - `new Date(...)` ตามด้วย `toISOString()` จะแปลงเป็น UTC เสมอ ถ้า backend ส่ง string ที่ไม่มี `Z` หรือ offset ระบบจะตีความเป็นเวลาท้องถิ่น แล้วเวลาที่แสดงจะเลื่อนไปเท่า offset
  - เวลาที่แสดงเป็น UTC ผู้ใช้ในไทย (UTC+7) ต้องบวกเองในใจ
- **`ngOnInit` (บรรทัด 24)** ใช้ `toISOString()` หาวันนี้ ซึ่งเป็นวันที่แบบ UTC ช่วง 00:00–07:00 เวลาไทย ค่าเริ่มต้นจะเป็น "เมื่อวาน" ทำให้ผู้ใช้ดูข้อมูลผิดวัน
- **โค้ดที่จะเพิ่มในอนาคต** เช่น เรียงหรือรวมช่วงติดกัน, ปุ่ม "จองช่วงนี้", หรือเช็ค slot ฝั่ง client ถ้าใช้ `<=` กับ `endsAt` หรือรวมช่วง `09:00–10:00` กับ `10:00–11:00` แบบนับขอบซ้ำ จะแสดงว่าชนทั้งที่จริงไม่ชน หรือในทางกลับกัน คอมเมนต์ในโค้ดตั้งใจให้ logic นี้อยู่ฝั่ง server ถ้าจำเป็นต้องมีฝั่ง client ให้ใช้ `start < otherEnd && otherStart < end` และอย่าใช้ `<=`

ข้อสังเกตเพิ่ม (ไม่เกี่ยวกับ half-open): `loadAvailability()` ไม่ยกเลิก request ที่ยังค้างอยู่ ถ้าผู้ใช้เปลี่ยนห้องหรือวันที่เร็วๆ response เก่าที่มาช้ากว่าอาจเขียนทับ `freeIntervals` ของคำขอล่าสุด

---

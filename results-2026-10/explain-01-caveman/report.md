# Blind grading input — explain-01 / caveman

⚠️ Run labels below are shuffled and do NOT reveal which condition (off vs skill) produced each one — graded by content only, per the blind-grading rule. Key file: `report-KEY.md` (do not open until grade_runs.py has produced report-scored.md).

> ตรวจโดย `grade_runs.py` อัตโนมัติ (blind, 3 pass อิสระ, majority vote, เกณฑ์ผ่าน >=80% ของ checklist) — checklist จริงเจาะจงต่อ task อยู่ที่ `workspace/tasks/<task_id>/checklist.md` กติกากลางดู `RUBRIC-กลาง.md` ไม่มี rubric 0-4 ฝังในไฟล์นี้อีกต่อไป

---

## Run A

**Response text:**

## 1. Who does what

**`RoomService`** (`room.service.ts`) is a thin HTTP layer.
- `listRooms()` calls `GET {baseUrl}/rooms` and returns `Observable<Room[]>`.
- `getAvailability(roomId, date)` calls `GET {baseUrl}/rooms/:id/availability?date=…` and returns `Observable<AvailabilityResponse>`.
- It has no booking logic. Its own comment says the Node API is the single source of truth. It only fetches, types and passes data through.
- `baseUrl` comes from `environment.bookingApiBaseUrl`.

**`RoomAvailabilityComponent`** owns UI state and presentation:
- State: `rooms`, `selectedRoomId`, `date`, `freeIntervals`, `loading`, `errorMessage`.
- It reacts to user input, calls the service, handles errors and loading, and formats slots for display (`formatSlot`).

**How they talk:** the component injects the service and `subscribe`s to its observables. The service never touches component state. The component never builds URLs.

## 2. Page load to slots on screen

1. `ngOnInit` sets `date` to today: `new Date().toISOString().slice(0,10)`. This is the **UTC** date, not the local date.
2. It calls `listRooms()`. On error, `errorMessage = 'Could not load rooms.'`.
3. On success it stores `rooms`. If there is at least one, it selects `rooms[0].id` and calls `loadAvailability()`.
4. `loadAvailability()` returns early if there is no room or date. Otherwise it sets `loading = true` and clears the error. Then it calls `getAvailability(selectedRoomId, date)`.
5. The backend returns `AvailabilityResponse`: `{ roomId, date, free: [{ startsAt, endsAt }, …] }`. Both timestamps are strings, presumably ISO 8601.
   - This shape comes from the TS interfaces only. This repo has no `docs/DOMAIN.md` and no backend code, so I haven't verified what the server really sends.
   - `free` is already computed by the backend: it is the gaps between bookings. The frontend does no subtraction.
6. On success, `freeIntervals = res.free` and `loading = false`. On error, the message is `'Could not load availability.'` and `loading = false`.
7. The template renders `<ul>` only when `!loading && !errorMessage`.
   - Each interval becomes `<li>{{ formatSlot(slot) }}</li>`.
   - `formatSlot` runs `new Date(...)` on each timestamp, then `toISOString().slice(11,16)`, giving something like `09:00–10:30 UTC`.
   - If the array is empty, it shows "No free slots."
8. Changing the room `<select>` or the date `<input>` fires `(ngModelChange)="loadAvailability()"`, which repeats steps 4–7.

Side effects to know about:
- There is no request cancellation. If the user switches rooms quickly, an older response can arrive after a newer one and overwrite `freeIntervals` with the wrong room's data (`switchMap` would fix this).
- `(ngModelChange)` on `[(ngModel)]` has an ordering subtlety. Angular's own handler for the two-way binding is registered first, so the model is usually updated before `loadAvailability()` runs. It works, but it is fragile.

## 3. Where the half-open `[start, end)` rule matters here

Half-open means `startsAt` is inclusive and `endsAt` is exclusive. A slot `09:00–10:00` is free at 09:00 but not at 10:00. A booking `10:00–11:00` is back-to-back with it, not overlapping. The code's own comment says the frontend never compares or merges ranges. So the risk sits in the few places that touch the values:

- **`formatSlot`** (`room-availability.component.ts:58`).
  - It displays `endsAt` as if the room were usable *through* that minute. Users may read `09:00–10:00` as "free until 10:00 inclusive". That is only a wording issue, but a label like "ends 10:00" could be misread as "10:00 is free".
  - If someone "fixes" the display by subtracting a minute (`09:59`), or adds `+1`, the label becomes wrong against the backend's semantics.
- **Any future code that compares or merges intervals** (adjacent-slot merging, "is this time free?" checks, disabling the booking button). Adjacent slots like `09:00–10:00` and `10:00–11:00` touch without overlapping.
  - Using `<=` instead of `<` on `endsAt` would wrongly flag them as conflicting.
  - Using `>=` where `>` is needed would wrongly treat the end instant as free.
  - This is exactly the logic the comment says to keep server-side. Keep it there.
- **Day boundaries and the date param** (`ngOnInit`, line 24, and `getAvailability`'s `date` param).
  - The default date is the UTC date. Near midnight, a user in a non-UTC timezone sees the wrong "today". For example, a user in UTC+7 at 06:00 local sees yesterday's date.
  - A slot ending exactly at `24:00` (next day `00:00`) is valid under half-open rules. If the frontend ever filters slots by local date, that slot can wrongly spill into or be dropped from the next day.
- **Timezone formatting.** `toISOString()` forces UTC and the label says "UTC", so display is consistent. Switching to local formatting (`toLocaleTimeString`) changes what users see relative to the backend's day boundaries. Keep the date param and display in the same timezone.
- **Sending a selected slot back as a booking.** Not implemented yet, but a future booking call must send `startsAt` and `endsAt` as given. Don't round, shift or "inclusive-ify" the end.

**Rule of thumb:** treat `endsAt` as an opaque exclusive bound. Display it, pass it back untouched, and let the backend decide overlap.

---

## Run B

**Response text:**

I read the three files you named. The backend isn't in this repo, and the code comments point to a `docs/DOMAIN.md` that I couldn't find or read. So what I say about the backend comes from the TypeScript types and comments in these files. I haven't seen the API itself.

## 1. Who does what

**`RoomService`** (`services/room.service.ts`) is a thin HTTP client. It has no state and no logic.
- `listRooms()` calls `GET {baseUrl}/rooms` and returns `Observable<Room[]>`.
- `getAvailability(roomId, date)` calls `GET {baseUrl}/rooms/:id/availability?date=…` and returns `Observable<AvailabilityResponse>`.
- It also declares the types for the API's JSON: `Room`, `FreeInterval` and `AvailabilityResponse`.
- Its header comment says the Node API is the single source of truth for booking rules. The service only fetches and passes data through.

**`RoomAvailabilityComponent`** owns the UI state: `rooms`, `selectedRoomId`, `date`, `freeIntervals`, `loading` and `errorMessage`. It does three things:
- It calls the service and subscribes.
- It stores the results in those fields.
- It formats each slot for display in `formatSlot`.

The two talk through constructor injection. The service is `providedIn: 'root'` and the component receives it in its constructor. The component calls service methods and subscribes to the returned Observables. The service never calls back into the component.

## 2. Page load to slots on screen

1. Angular creates the component and runs `ngOnInit`. It sets `date` to today as `YYYY-MM-DD`, taken from `toISOString()`, so it is today's date in UTC.
2. `ngOnInit` calls `listRooms()` and subscribes. On error it sets "Could not load rooms." and nothing else happens.
3. On success it stores `rooms`. If there is at least one room, it selects `rooms[0].id` and calls `loadAvailability()`.
4. `loadAvailability()` returns early if there is no room or no date. Otherwise it sets `loading = true`, clears the error, and calls `getAvailability(roomId, date)`.
5. The backend responds with `{ roomId, date, free: [{ startsAt, endsAt }, …] }`. The timestamps are strings, and `formatSlot` parses them as ISO timestamps.
6. On success the component sets `freeIntervals = res.free` and `loading = false`. On error it sets "Could not load availability." and `loading = false`.
7. In the template, the `<ul>` only renders when `!loading && !errorMessage`. It loops over `freeIntervals` and shows `formatSlot(slot)` for each one. If the list is empty it shows "No free slots."
8. `formatSlot` runs `new Date(...)` on both timestamps, then `toISOString().slice(11,16)`. This gives `HH:mm`, so a slot reads like `09:00–10:30 UTC`.
9. Later, changing the room `<select>` or the date `<input>` fires `(ngModelChange)`, which calls `loadAvailability()` again.

The component does no computation of its own. Whatever free intervals the server returns are what the user sees, formatted as UTC text.

## 3. Where the half-open rule matters here

The comment at `room-availability.component.ts:55-57` says intervals are `[startsAt, endsAt)`. That means the start is included and the end is excluded. A slot ending at 10:00 and another starting at 10:00 do not overlap, and `endsAt` is the first moment that is not free.

Today the frontend only labels the intervals, so it is safe. Three places could go wrong if someone adds logic:

- **`formatSlot` (line 58).** The label `09:00–10:30` really means "free from 09:00 up to, but not including, 10:30". Don't "fix" it by subtracting a minute, or by rendering it as an inclusive end such as `10:29` or "until 10:30 inclusive". Either one makes the user think the 10:30 slot is free or booked when it isn't.
- **Any comparison or merge added in the component.** Examples are "is the 10:00 slot free?", merging adjacent slots, or checking whether a requested booking fits. Using `<=` instead of `<` on `endsAt`, or treating touching intervals as overlapping, gives wrong answers. The component currently avoids this on purpose, and the comment says that logic stays server-side.
- **Date and timezone handling (lines 24 and 61).** `date` comes from UTC (`toISOString`), and `formatSlot` prints UTC. Users in other timezones can see "today" as a different day than their own. Slots near midnight can also look like they belong to the wrong date. Both are separate from the half-open rule, but they sit on the same interval boundaries. If the display is later switched to local time, the exclusive end can fall on the next day, such as `00:00` of the following date.

So even with the backend untouched, changing how boundaries are rendered, compared or merged in this component can show the user a wrong "free" or "booked" answer. The safe approach is to keep passing the server's intervals through unchanged, and put any new interval logic on the backend.

I changed no files.

---

## Run C

**Response text:**

I read the service, the component and its template. I didn't find the backend's `docs/DOMAIN.md` in this repo, so what I say about the backend's response comes from the TypeScript interfaces and code comments, not from the backend itself.

## 1. Who does what

**`RoomService`** (`services/room.service.ts`) is a thin HTTP client.
- It has two calls: `listRooms()` (`GET {baseUrl}/rooms`) and `getAvailability(roomId, date)` (`GET {baseUrl}/rooms/:id/availability?date=…`).
- It returns typed `Observable`s (`Room[]`, `AvailabilityResponse`).
- It does no booking logic. Its header comment says the Node API is the single source of truth and the service only fetches and passes data through.

**`RoomAvailabilityComponent`** owns the UI state: `rooms`, `selectedRoomId`, `date`, `freeIntervals`, `loading` and `errorMessage`.
- It decides when to call the service.
- It turns the response into display text with `formatSlot`.
- The template renders that state.

The component injects the service and subscribes to its observables. There is no shared state or store.

## 2. Page load to slots on screen

1. `ngOnInit` sets `date` to today with `new Date().toISOString().slice(0, 10)`, which is the **UTC** date.
2. It calls `listRooms()`. On error it shows "Could not load rooms."
3. On success it stores the rooms and selects `rooms[0]`. If there are no rooms, nothing else happens and the list stays empty.
4. It calls `loadAvailability()`. That returns early if the room or date is empty, then sets `loading = true` and clears the error.
5. `getAvailability` fetches `/rooms/<id>/availability?date=YYYY-MM-DD`.
6. The backend returns an `AvailabilityResponse`: `{ roomId, date, free: [{ startsAt, endsAt }, …] }`. The times are strings, presumably ISO-8601 timestamps, since `formatSlot` passes them to `new Date()`. The `free` array is already computed by the backend.
7. On success the component sets `freeIntervals = res.free` and `loading = false`. On error it shows "Could not load availability."
8. The template shows "Loading…" or the error message if either is set. Otherwise it renders one `<li>` per interval through `formatSlot`, or "No free slots." if the array is empty.
9. `formatSlot` parses both strings with `new Date`, takes `toISOString().slice(11, 16)` (the `HH:mm` part) and renders `09:00–10:30 UTC`.

Changing the room or date in the template fires `(ngModelChange)="loadAvailability()"`, which repeats steps 4–9.

## 3. Where the half-open rule matters here

The comment at `room-availability.component.ts:55` says free intervals are half-open `[startsAt, endsAt)`. That means `startsAt` is free, and `endsAt` is the first instant that is not part of the slot. A slot `09:00–10:00` can be followed by another starting at `10:00`.

The component currently only formats the intervals and never compares them, so nothing is wrong today. These are the places to be careful:

- **`formatSlot` (line 58).** The label `09:00–10:00` is accurate under the half-open rule: the room is free until 10:00, and a booking can start at 10:00. If you ever add copy such as "free through 10:00", or an inclusive end like 09:59, the user gets the wrong picture.
- **Midnight.** A slot ending at the end of the day has an `endsAt` of 00:00 on the next day. `slice(11, 16)` shows it as `22:00–00:00`, and the date is lost. Anyone who compares the displayed start and end strings will think the end is before the start.
- **Any new comparison, merge or filter.** The backend's `[9,10)` and `[10,11)` touch but don't overlap. Using `<=` where the rule needs `<` (or the reverse) would:
  - fail to merge adjacent slots,
  - hide a slot that starts exactly "now",
  - or report a conflict that doesn't exist.
- **Durations.** Compute `end - start` and don't add 1. A slot of 09:00–10:00 is 60 minutes, not 61.
- **Client-side booking checks.** Don't re-check `start < slotEnd && end > slotStart` in the browser. The comment says that logic should stay server-side, so let the backend decide.

Two related issues that could also show a wrong answer, with no backend change:

- **Timezone.** `date` defaults to the UTC date, and times are displayed in UTC. Near midnight a local user may see "today" as yesterday or tomorrow. Slot boundaries also won't match local wall-clock times.
- **Overlapping requests.** Changing the room or date quickly fires several requests, and nothing cancels the earlier ones. A slow earlier response can overwrite a later one, so slots for room A can show under room B. Using `switchMap` or ignoring stale responses would fix it.

`new Date(x).toISOString()` throws a `RangeError` if the backend ever sends an unparseable timestamp, and nothing here catches it.

I didn't change any files.

---

## Run D

**Response text:**

I read the three files you named. `docs/DOMAIN.md` is mentioned in a comment in `room.service.ts`, but it isn't in this repo. I haven't seen the backend, so what the API sends back comes from the TypeScript interfaces and the code that consumes them. I haven't confirmed it against the real server.

## 1. Who does what

**`RoomService`** (`services/room.service.ts`) is a thin HTTP wrapper. It has two methods:
- `listRooms()` sends `GET {bookingApiBaseUrl}/rooms` and returns `Observable<Room[]>`.
- `getAvailability(roomId, date)` sends `GET .../rooms/{roomId}/availability?date=...` and returns `Observable<AvailabilityResponse>`.

It also declares the response types (`Room`, `FreeInterval`, `AvailabilityResponse`). It holds no booking logic. The comment at the top says the Node API is the single source of truth.

**`RoomAvailabilityComponent`** owns the UI state: `rooms`, `selectedRoomId`, `date`, `freeIntervals`, `loading` and `errorMessage`. It decides when to call the service, handles success and failure, and formats each slot for display.

**How they talk:** the component injects the service and subscribes to the Observables it returns. The service never knows about the component. Data flows one way, from the HTTP response through `next` or `error` into the component's fields. The template then renders those fields.

## 2. Page load to slots on screen

1. Angular creates the component and runs `ngOnInit`.
2. `date` is set to today's date as `YYYY-MM-DD`, from `new Date().toISOString().slice(0, 10)`.
3. `listRooms()` fires `GET /rooms`. The backend returns an array of `{id, name, capacity, isActive}`.
4. In the `next` handler, `rooms` is stored. If the list isn't empty, `selectedRoomId` is set to the first room's `id` and `loadAvailability()` runs. On error, the message is "Could not load rooms."
5. `loadAvailability()` returns early if there's no room or date. Otherwise it sets `loading = true`, clears `errorMessage`, and calls `getAvailability(roomId, date)`.
6. The backend responds with `{ roomId, date, free: [{ startsAt, endsAt }, ...] }`. The timestamps are strings, presumably ISO 8601. Each `free` entry is a half-open range `[startsAt, endsAt)`.
7. The component does `freeIntervals = res.free` and `loading = false`. It does no filtering, sorting or merging.
8. The template shows `<ul>` only when `!loading && !errorMessage`. It loops over `freeIntervals` and renders `formatSlot(slot)` for each one. If the array is empty, it shows "No free slots."
9. `formatSlot` runs `new Date()` on each string, takes `toISOString().slice(11, 16)` (the `HH:mm` part) and returns something like `09:00–10:30 UTC`.

Changing the room dropdown or the date input calls `loadAvailability()` again through `(ngModelChange)`. This repeats steps 5 to 9.

## 3. Where the half-open rule matters here

The frontend doesn't implement the rule, but it can still show the wrong answer in these places:

- **`formatSlot` label (`room-availability.component.ts:58-63`).** A slot `[09:00, 10:00)` renders as `09:00–10:00`. That reads like an inclusive range. The end is exclusive: the room is free from 09:00 up to, but not including, 10:00. A booking starting at 10:00 is legal and doesn't conflict. If you reword or restyle the label, don't imply that 10:00 is inside the free slot.
- **Adjacent slots.** Two intervals like `[09:00, 10:00)` and `[10:00, 11:00)` touch but don't overlap. The component deliberately doesn't merge them, as its comment says. If you add merging, use `<=` (not `<`) when joining on `end == start`, or the slots won't merge.
- **Any future comparison or duration logic.** Examples are "does this slot fit a 60-minute meeting" or "is this time free". Using `<=` instead of `<` on the end boundary produces an off-by-one error. A slot of exactly 60 minutes fits, and a time equal to `endsAt` is not free.
- **Day boundaries.** A slot ending at midnight shows as `00:00`, which looks like the start of the day, not the end of it. The exclusive end makes this more confusing.
- **Timezone conversion.** `formatSlot` always prints UTC, so the boundaries match what the backend sent. If you switch to local time, boundaries shift and the half-open edges can land on a different calendar day. If the backend ever sends timestamps without a `Z` or offset, `new Date()` reads them as local time and `toISOString()` shifts them, so the printed boundary is wrong.
- **The `date` value.** The default comes from `toISOString()`, so it's the UTC date, not the user's local date. Near midnight, a user can see "today" as the wrong day. Whether that is correct depends on how the backend defines a day, which I can't see from here.

## Other things to know

- There's no cancellation of in-flight requests. If a user switches rooms quickly, a slow earlier response can overwrite a newer one. `switchMap` would fix that.
- On an availability error, `freeIntervals` keeps its old value. The `<ul>` is hidden because `errorMessage` is set, so users won't see stale data today. A later change to the template could expose it.

I didn't change any files.

---

## Run E

**Response text:**

## 1. Who does what

**`RoomService`** (`room.service.ts`) is a thin HTTP wrapper and has no logic.
- `listRooms()` calls `GET {baseUrl}/rooms` and returns `Observable<Room[]>`.
- `getAvailability(roomId, date)` calls `GET {baseUrl}/rooms/:id/availability?date=…` and returns `Observable<AvailabilityResponse>`.
- It defines the response types: `Room`, `FreeInterval {startsAt, endsAt}` and `AvailabilityResponse {roomId, date, free[]}`.
- `baseUrl` comes from `environment.bookingApiBaseUrl`.
- The comment says the Node API is the single source of truth. The service re-implements no booking rules.

**`RoomAvailabilityComponent`** owns UI state and presentation.
- State: `rooms`, `selectedRoomId`, `date`, `freeIntervals`, `loading` and `errorMessage`.
- It decides when to fetch, handles errors and loading flags, and formats each slot as text.

**How they talk:** the component injects the service and subscribes to its observables. Data flows one way, from service to component state to template. The service knows nothing about the component.

## 2. Page load to slots on screen

1. The component is created and `ngOnInit` runs.
2. `date` is set to today: `new Date().toISOString().slice(0,10)`. This is today's **UTC** date, not the local date.
3. `listRooms()` fires `GET /rooms`.
4. On success:
   - `rooms` is stored.
   - If the list is non-empty, `selectedRoomId = rooms[0].id` and `loadAvailability()` is called.
   - On error, `errorMessage = 'Could not load rooms.'`.
5. `loadAvailability()` returns early if the room or date is empty. Otherwise it sets `loading = true`, clears the error, and calls `GET /rooms/{id}/availability?date=YYYY-MM-DD`.
6. The backend returns `{ roomId, date, free: [{startsAt, endsAt}, …] }`. `startsAt` and `endsAt` are strings, presumably ISO timestamps. I'm inferring this from the TS types and `new Date(...)` parsing. I haven't looked at the backend.
7. On success, `freeIntervals = res.free` and `loading = false`. On error, `errorMessage = 'Could not load availability.'` and `loading = false`.
8. The template shows `<ul>` only when `!loading && !errorMessage`. Each slot renders `formatSlot(slot)`:
   - It parses both strings with `new Date(...)`.
   - It takes `toISOString().slice(11,16)`, which gives `HH:mm` in UTC.
   - The result looks like `09:00–10:30 UTC`.
   - If the array is empty, it shows "No free slots."
9. After load, changing the room `<select>` or the date `<input>` triggers `(ngModelChange)="loadAvailability()"`, which repeats steps 5–8.

There's a gotcha in step 9. The two `ngModelChange` handlers can fire before `[(ngModel)]` has written the new value into the field. In practice, two-way binding sets the field first, so this usually works. Also, rapid changes issue overlapping requests with no cancellation, so a slow earlier response can overwrite a newer one.

## 3. Where the half-open `[start, end)` rule matters

Half-open means a slot that ends at 10:00 and one that starts at 10:00 don't overlap. The end instant is **exclusive**. The component never compares or merges intervals, so it's safe today. The risk is in the display and in any future logic.

- **`formatSlot` (`.ts:58-63`)** prints `endsAt` as a plain end time. Under `[start, end)`, `09:00–10:00` means free up to but not including 10:00. A user could read "10:00" as bookable, but a booking starting at 10:00 is a different slot. The label is fine only if users understand the end is exclusive. If you change the wording to something like "until 10:00 inclusive" or add 1 minute, you show wrong data.
- **Truncating to `HH:mm` (`.ts:61`)** drops seconds and milliseconds. If a boundary has seconds, such as `10:00:30`, the label rounds it down and can display a slot that looks like it ends earlier or abuts the next one. Adjacent slots could look overlapping or gapped when they aren't.
- **Hardcoded UTC (`.ts:24, 61`)** shifts which day "today" is, and shifts both ends of every slot. Near midnight, a slot that is `[23:00, 00:00)` has an `endsAt` on the next calendar day. The label shows `23:00–00:00`, which reads as a wrong or zero-length range. The default date can also be yesterday or tomorrow for local users.
- **Future code that adds client-side logic** is the biggest trap. Examples are merging adjacent slots, hiding slots shorter than N minutes, checking whether a chosen time fits, or computing duration. These must treat `end` as exclusive. With `<=` instead of `<`, or with `end - 1`, you'd show a slot as free when it isn't, or hide a valid one. The existing comment says this logic stays server-side. Keep it there, or reuse the backend's rule rather than reinventing it.

Even though the backend does the math, the frontend can still show a wrong answer, because it controls how the boundaries are rendered, which timezone is applied, and how precisely the times are shown.

I changed no files.

---

## Run F

**Response text:**

## 1. Who does what

**RoomService** (`room.service.ts`) is a thin HTTP wrapper.
- `listRooms()` calls `GET {base}/rooms`.
- `getAvailability(roomId, date)` calls `GET {base}/rooms/:id/availability?date=...`.
- The base URL is `http://localhost:3000`, from `environment.ts`.
- It holds no business logic. Its comment says the Node API is the single source of truth and that `docs/DOMAIN.md` rules are not re-implemented here.
- It returns typed `Observable`s and nothing else.

**RoomAvailabilityComponent** owns UI state and display.
- State: `rooms`, `selectedRoomId`, `date`, `freeIntervals`, `loading`, `errorMessage`.
- It subscribes to the service, handles errors, and formats slots into text.
- The template binds the room `<select>` and the date `<input>` with `ngModel`. Both call `loadAvailability()` on change.

The link between them is constructor injection (`RoomService` is `providedIn: 'root'`). The component calls the service methods and subscribes. The service never knows about the component.

## 2. Page load to slots on screen

1. The component is created and `ngOnInit` runs.
2. `date` is set to today: `new Date().toISOString().slice(0,10)`. That is today's **UTC** date, not the local date.
3. `listRooms()` sends `GET /rooms`. The backend returns `Room[]`, each with `{id, name, capacity, isActive}`.
4. On success, `rooms` is filled and the template renders the `<option>`s.
5. If the list is non-empty, `selectedRoomId = rooms[0].id` and `loadAvailability()` runs.
   - On error, the page shows "Could not load rooms."
   - If the list is empty, nothing more happens.
6. `loadAvailability()` sets `loading = true` and clears `errorMessage`.
7. It sends `GET /rooms/{id}/availability?date=YYYY-MM-DD`.
8. The backend returns `{ roomId, date, free: [{startsAt, endsAt}, ...] }`.
   - The timestamps are strings, apparently ISO-8601.
   - That shape comes from the TypeScript interface only. The backend isn't in this repo, so I couldn't check it.
9. On success, `freeIntervals = res.free` and `loading = false`. On error, the message is "Could not load availability."
10. The template shows the `<ul>` only when `!loading && !errorMessage`.
    - It renders one `<li>` per slot via `formatSlot()`.
    - `formatSlot()` parses both timestamps with `new Date()`, takes `toISOString().slice(11,16)`, and returns e.g. `09:00–10:30 UTC`.
    - If the array is empty, it shows "No free slots."
11. Changing the room or date repeats from step 6.

## 3. Where half-open intervals bite

The backend treats intervals as half-open `[startsAt, endsAt)`. The start is included and the end is excluded. A booking that ends at 10:00 and one that starts at 10:00 do not conflict, so a free slot ending at 10:00 means 10:00 itself is **not** free.

The frontend currently only formats, so it is safe today. Be careful at these spots:

- **`formatSlot` (`ts:58-63`).** It shows `09:00–10:00`. A reader may take that as "free through 10:00 inclusive". If someone "fixes" the end by subtracting a minute, or adds `<=` logic, the display lies.
- **Slicing to `HH:mm`.** `slice(11,16)` truncates seconds and milliseconds. An end of `10:00:30` would display as `10:00`, which hides the true boundary. It also assumes the strings are UTC `Z` timestamps. A non-UTC offset would be silently shifted by `toISOString()`.
- **Adding client-side logic later.** Examples are merging adjacent slots, checking whether a user's chosen time fits a slot, disabling a booking button, and counting slots or durations. Use `start <= t && t < end`, never `<=` on the end. Merging should treat `a.endsAt === b.startsAt` as contiguous, not overlapping. The code comment says this logic stays server-side, and that is the right default.
- **Date boundary (`ts:24` and the `date` param).** `date` defaults to the UTC day. A user in a UTC+7 timezone sees "today" as yesterday for part of the day. A slot ending exactly at midnight UTC (`24:00` of day N, which is `00:00` of day N+1) displays as `00:00 UTC` and looks like it is before its own start. The bug is in the display, and the backend answer is still correct.

Wrong output here would not corrupt a booking. The backend still validates. But the user could see an off-by-one boundary, or a slot that looks bookable when it isn't (or the reverse), and then get a confusing rejection.

I changed no files.

---

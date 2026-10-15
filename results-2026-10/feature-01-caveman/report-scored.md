# Scored report — feature-01

AI-graded, blind to condition, 3 independent passes per run, majority vote per item, run verdict = pass if >= 80% items pass.

## Run A — PASS (91.7% passed)

| item | text | pass1 | pass2 | pass3 | final | split |
|---|---|---|---|---|---|---|
| 1 | เพิ่ม endpoint `PATCH /bookings/{id}/extend` ใหม่ในโปรเจกต์ | pass | pass | pass | pass |  |
| 2 | endpoint ปฏิเสธการขยายเวลาเมื่อ booking มี Status ไม่ใช่ CONFIRMED (เช่น CANCELLED) | pass | pass | pass | pass |  |
| 3 | endpoint ปฏิเสธเมื่อ `newEndsAt` ไม่ได้อยู่หลัง `EndsAt` เดิมอย่างเคร่งครัด (เช่น เท่ากับหรือมาก่อน `EndsAt` เดิม) | pass | pass | pass | pass |  |
| 4 | endpoint คำนวณระยะเวลารวมจาก `StartsAt` เดิมถึง `newEndsAt` ใหม่ (ไม่ใช่จาก `EndsAt` เดิม) แล้วปฏิเสธถ้าเกิน 8 ชั่วโมง | pass | pass | pass | pass |  |
| 5 | endpoint เช็ค overlap ของช่วงเวลาที่ขยายแล้วกับ booking อื่นที่ CONFIRMED ในห้องเดียวกัน โดยไม่รวม booking ของตัวมันเอง (ไม่เกิด self-conflict กับช่วงเวลาเดิมของตัวเอง) | pass | pass | pass | pass |  |
| 6 | การเช็ค overlap ใช้สูตร half-open (`a.StartsAt < b.EndsAt && a.EndsAt > b.StartsAt`) ไม่ใช้ `<=`/`>=` ที่จะทำให้การขยายแบบต่อเนื่องพอดี (back-to-back) ถูกปฏิเสธผิดพลาด | pass | pass | pass | pass |  |
| 7 | เมื่อสำเร็จ endpoint บันทึก `EndsAt` ใหม่ลงฐานข้อมูลจริง และคืนค่า booking ที่อัปเดตแล้ว | pass | pass | pass | pass |  |
| 8 | endpoint คืนค่า error response แบบ 4xx เมื่อกฎข้อใดข้อหนึ่งใน 4 ข้อข้างต้นถูกละเมิด | pass | pass | pass | pass |  |
| 9 | โค้ดที่เพิ่มตรงตาม convention ของ ASP.NET Core ที่ repo ใช้อยู่แล้ว (controller action, `[FromBody]`, async/await ตลอด) | pass | pass | pass | pass |  |
| 10 | diff ไม่แตะ controller หรือ service อื่นที่ไม่เกี่ยวข้องกับ endpoint นี้ | pass | pass | pass | pass |  |
| 11 | ไม่มีการสร้าง service layer ใหม่ทั้งชั้นสำหรับ endpoint เดียวนี้ ทั้งที่ repo ปัจจุบันเรียก DbContext ตรงจาก controller | pass | pass | pass | pass |  |
| 12 | โปรเจกต์ build ผ่านหลังเพิ่มโค้ด | fail | fail | fail | fail |  |

## Run B — PASS (91.7% passed)

| item | text | pass1 | pass2 | pass3 | final | split |
|---|---|---|---|---|---|---|
| 1 | เพิ่ม endpoint `PATCH /bookings/{id}/extend` ใหม่ในโปรเจกต์ | pass | pass | pass | pass |  |
| 2 | endpoint ปฏิเสธการขยายเวลาเมื่อ booking มี Status ไม่ใช่ CONFIRMED (เช่น CANCELLED) | pass | pass | pass | pass |  |
| 3 | endpoint ปฏิเสธเมื่อ `newEndsAt` ไม่ได้อยู่หลัง `EndsAt` เดิมอย่างเคร่งครัด (เช่น เท่ากับหรือมาก่อน `EndsAt` เดิม) | pass | pass | pass | pass |  |
| 4 | endpoint คำนวณระยะเวลารวมจาก `StartsAt` เดิมถึง `newEndsAt` ใหม่ (ไม่ใช่จาก `EndsAt` เดิม) แล้วปฏิเสธถ้าเกิน 8 ชั่วโมง | pass | pass | pass | pass |  |
| 5 | endpoint เช็ค overlap ของช่วงเวลาที่ขยายแล้วกับ booking อื่นที่ CONFIRMED ในห้องเดียวกัน โดยไม่รวม booking ของตัวมันเอง (ไม่เกิด self-conflict กับช่วงเวลาเดิมของตัวเอง) | pass | pass | pass | pass |  |
| 6 | การเช็ค overlap ใช้สูตร half-open (`a.StartsAt < b.EndsAt && a.EndsAt > b.StartsAt`) ไม่ใช้ `<=`/`>=` ที่จะทำให้การขยายแบบต่อเนื่องพอดี (back-to-back) ถูกปฏิเสธผิดพลาด | pass | pass | pass | pass |  |
| 7 | เมื่อสำเร็จ endpoint บันทึก `EndsAt` ใหม่ลงฐานข้อมูลจริง และคืนค่า booking ที่อัปเดตแล้ว | pass | pass | pass | pass |  |
| 8 | endpoint คืนค่า error response แบบ 4xx เมื่อกฎข้อใดข้อหนึ่งใน 4 ข้อข้างต้นถูกละเมิด | pass | pass | pass | pass |  |
| 9 | โค้ดที่เพิ่มตรงตาม convention ของ ASP.NET Core ที่ repo ใช้อยู่แล้ว (controller action, `[FromBody]`, async/await ตลอด) | pass | pass | pass | pass |  |
| 10 | diff ไม่แตะ controller หรือ service อื่นที่ไม่เกี่ยวข้องกับ endpoint นี้ | pass | pass | pass | pass |  |
| 11 | ไม่มีการสร้าง service layer ใหม่ทั้งชั้นสำหรับ endpoint เดียวนี้ ทั้งที่ repo ปัจจุบันเรียก DbContext ตรงจาก controller | pass | pass | pass | pass |  |
| 12 | โปรเจกต์ build ผ่านหลังเพิ่มโค้ด | fail | fail | fail | fail |  |

## Run C — PASS (100.0% passed)

| item | text | pass1 | pass2 | pass3 | final | split |
|---|---|---|---|---|---|---|
| 1 | เพิ่ม endpoint `PATCH /bookings/{id}/extend` ใหม่ในโปรเจกต์ | pass | pass | pass | pass |  |
| 2 | endpoint ปฏิเสธการขยายเวลาเมื่อ booking มี Status ไม่ใช่ CONFIRMED (เช่น CANCELLED) | pass | pass | pass | pass |  |
| 3 | endpoint ปฏิเสธเมื่อ `newEndsAt` ไม่ได้อยู่หลัง `EndsAt` เดิมอย่างเคร่งครัด (เช่น เท่ากับหรือมาก่อน `EndsAt` เดิม) | pass | pass | pass | pass |  |
| 4 | endpoint คำนวณระยะเวลารวมจาก `StartsAt` เดิมถึง `newEndsAt` ใหม่ (ไม่ใช่จาก `EndsAt` เดิม) แล้วปฏิเสธถ้าเกิน 8 ชั่วโมง | pass | pass | pass | pass |  |
| 5 | endpoint เช็ค overlap ของช่วงเวลาที่ขยายแล้วกับ booking อื่นที่ CONFIRMED ในห้องเดียวกัน โดยไม่รวม booking ของตัวมันเอง (ไม่เกิด self-conflict กับช่วงเวลาเดิมของตัวเอง) | pass | pass | pass | pass |  |
| 6 | การเช็ค overlap ใช้สูตร half-open (`a.StartsAt < b.EndsAt && a.EndsAt > b.StartsAt`) ไม่ใช้ `<=`/`>=` ที่จะทำให้การขยายแบบต่อเนื่องพอดี (back-to-back) ถูกปฏิเสธผิดพลาด | pass | pass | pass | pass |  |
| 7 | เมื่อสำเร็จ endpoint บันทึก `EndsAt` ใหม่ลงฐานข้อมูลจริง และคืนค่า booking ที่อัปเดตแล้ว | pass | pass | pass | pass |  |
| 8 | endpoint คืนค่า error response แบบ 4xx เมื่อกฎข้อใดข้อหนึ่งใน 4 ข้อข้างต้นถูกละเมิด | pass | pass | pass | pass |  |
| 9 | โค้ดที่เพิ่มตรงตาม convention ของ ASP.NET Core ที่ repo ใช้อยู่แล้ว (controller action, `[FromBody]`, async/await ตลอด) | pass | pass | pass | pass |  |
| 10 | diff ไม่แตะ controller หรือ service อื่นที่ไม่เกี่ยวข้องกับ endpoint นี้ | pass | pass | pass | pass |  |
| 11 | ไม่มีการสร้าง service layer ใหม่ทั้งชั้นสำหรับ endpoint เดียวนี้ ทั้งที่ repo ปัจจุบันเรียก DbContext ตรงจาก controller | pass | pass | pass | pass |  |
| 12 | โปรเจกต์ build ผ่านหลังเพิ่มโค้ด | pass | pass | pass | pass |  |

## Run D — PASS (91.7% passed)

| item | text | pass1 | pass2 | pass3 | final | split |
|---|---|---|---|---|---|---|
| 1 | เพิ่ม endpoint `PATCH /bookings/{id}/extend` ใหม่ในโปรเจกต์ | pass | pass | pass | pass |  |
| 2 | endpoint ปฏิเสธการขยายเวลาเมื่อ booking มี Status ไม่ใช่ CONFIRMED (เช่น CANCELLED) | pass | pass | pass | pass |  |
| 3 | endpoint ปฏิเสธเมื่อ `newEndsAt` ไม่ได้อยู่หลัง `EndsAt` เดิมอย่างเคร่งครัด (เช่น เท่ากับหรือมาก่อน `EndsAt` เดิม) | pass | pass | pass | pass |  |
| 4 | endpoint คำนวณระยะเวลารวมจาก `StartsAt` เดิมถึง `newEndsAt` ใหม่ (ไม่ใช่จาก `EndsAt` เดิม) แล้วปฏิเสธถ้าเกิน 8 ชั่วโมง | pass | pass | pass | pass |  |
| 5 | endpoint เช็ค overlap ของช่วงเวลาที่ขยายแล้วกับ booking อื่นที่ CONFIRMED ในห้องเดียวกัน โดยไม่รวม booking ของตัวมันเอง (ไม่เกิด self-conflict กับช่วงเวลาเดิมของตัวเอง) | pass | pass | pass | pass |  |
| 6 | การเช็ค overlap ใช้สูตร half-open (`a.StartsAt < b.EndsAt && a.EndsAt > b.StartsAt`) ไม่ใช้ `<=`/`>=` ที่จะทำให้การขยายแบบต่อเนื่องพอดี (back-to-back) ถูกปฏิเสธผิดพลาด | pass | pass | pass | pass |  |
| 7 | เมื่อสำเร็จ endpoint บันทึก `EndsAt` ใหม่ลงฐานข้อมูลจริง และคืนค่า booking ที่อัปเดตแล้ว | pass | pass | pass | pass |  |
| 8 | endpoint คืนค่า error response แบบ 4xx เมื่อกฎข้อใดข้อหนึ่งใน 4 ข้อข้างต้นถูกละเมิด | pass | pass | pass | pass |  |
| 9 | โค้ดที่เพิ่มตรงตาม convention ของ ASP.NET Core ที่ repo ใช้อยู่แล้ว (controller action, `[FromBody]`, async/await ตลอด) | pass | pass | pass | pass |  |
| 10 | diff ไม่แตะ controller หรือ service อื่นที่ไม่เกี่ยวข้องกับ endpoint นี้ | pass | pass | pass | pass |  |
| 11 | ไม่มีการสร้าง service layer ใหม่ทั้งชั้นสำหรับ endpoint เดียวนี้ ทั้งที่ repo ปัจจุบันเรียก DbContext ตรงจาก controller | pass | pass | pass | pass |  |
| 12 | โปรเจกต์ build ผ่านหลังเพิ่มโค้ด | pass | fail | fail | fail | ⚠️ non-unanimous |

## Run E — PASS (91.7% passed)

| item | text | pass1 | pass2 | pass3 | final | split |
|---|---|---|---|---|---|---|
| 1 | เพิ่ม endpoint `PATCH /bookings/{id}/extend` ใหม่ในโปรเจกต์ | pass | pass | pass | pass |  |
| 2 | endpoint ปฏิเสธการขยายเวลาเมื่อ booking มี Status ไม่ใช่ CONFIRMED (เช่น CANCELLED) | pass | pass | pass | pass |  |
| 3 | endpoint ปฏิเสธเมื่อ `newEndsAt` ไม่ได้อยู่หลัง `EndsAt` เดิมอย่างเคร่งครัด (เช่น เท่ากับหรือมาก่อน `EndsAt` เดิม) | pass | pass | pass | pass |  |
| 4 | endpoint คำนวณระยะเวลารวมจาก `StartsAt` เดิมถึง `newEndsAt` ใหม่ (ไม่ใช่จาก `EndsAt` เดิม) แล้วปฏิเสธถ้าเกิน 8 ชั่วโมง | pass | pass | pass | pass |  |
| 5 | endpoint เช็ค overlap ของช่วงเวลาที่ขยายแล้วกับ booking อื่นที่ CONFIRMED ในห้องเดียวกัน โดยไม่รวม booking ของตัวมันเอง (ไม่เกิด self-conflict กับช่วงเวลาเดิมของตัวเอง) | pass | pass | pass | pass |  |
| 6 | การเช็ค overlap ใช้สูตร half-open (`a.StartsAt < b.EndsAt && a.EndsAt > b.StartsAt`) ไม่ใช้ `<=`/`>=` ที่จะทำให้การขยายแบบต่อเนื่องพอดี (back-to-back) ถูกปฏิเสธผิดพลาด | pass | pass | pass | pass |  |
| 7 | เมื่อสำเร็จ endpoint บันทึก `EndsAt` ใหม่ลงฐานข้อมูลจริง และคืนค่า booking ที่อัปเดตแล้ว | pass | pass | pass | pass |  |
| 8 | endpoint คืนค่า error response แบบ 4xx เมื่อกฎข้อใดข้อหนึ่งใน 4 ข้อข้างต้นถูกละเมิด | pass | pass | pass | pass |  |
| 9 | โค้ดที่เพิ่มตรงตาม convention ของ ASP.NET Core ที่ repo ใช้อยู่แล้ว (controller action, `[FromBody]`, async/await ตลอด) | pass | pass | pass | pass |  |
| 10 | diff ไม่แตะ controller หรือ service อื่นที่ไม่เกี่ยวข้องกับ endpoint นี้ | pass | pass | pass | pass |  |
| 11 | ไม่มีการสร้าง service layer ใหม่ทั้งชั้นสำหรับ endpoint เดียวนี้ ทั้งที่ repo ปัจจุบันเรียก DbContext ตรงจาก controller | pass | pass | pass | pass |  |
| 12 | โปรเจกต์ build ผ่านหลังเพิ่มโค้ด | fail | fail | fail | fail |  |

## Run F — PASS (91.7% passed)

| item | text | pass1 | pass2 | pass3 | final | split |
|---|---|---|---|---|---|---|
| 1 | เพิ่ม endpoint `PATCH /bookings/{id}/extend` ใหม่ในโปรเจกต์ | pass | pass | pass | pass |  |
| 2 | endpoint ปฏิเสธการขยายเวลาเมื่อ booking มี Status ไม่ใช่ CONFIRMED (เช่น CANCELLED) | pass | pass | pass | pass |  |
| 3 | endpoint ปฏิเสธเมื่อ `newEndsAt` ไม่ได้อยู่หลัง `EndsAt` เดิมอย่างเคร่งครัด (เช่น เท่ากับหรือมาก่อน `EndsAt` เดิม) | pass | pass | pass | pass |  |
| 4 | endpoint คำนวณระยะเวลารวมจาก `StartsAt` เดิมถึง `newEndsAt` ใหม่ (ไม่ใช่จาก `EndsAt` เดิม) แล้วปฏิเสธถ้าเกิน 8 ชั่วโมง | pass | pass | pass | pass |  |
| 5 | endpoint เช็ค overlap ของช่วงเวลาที่ขยายแล้วกับ booking อื่นที่ CONFIRMED ในห้องเดียวกัน โดยไม่รวม booking ของตัวมันเอง (ไม่เกิด self-conflict กับช่วงเวลาเดิมของตัวเอง) | pass | pass | pass | pass |  |
| 6 | การเช็ค overlap ใช้สูตร half-open (`a.StartsAt < b.EndsAt && a.EndsAt > b.StartsAt`) ไม่ใช้ `<=`/`>=` ที่จะทำให้การขยายแบบต่อเนื่องพอดี (back-to-back) ถูกปฏิเสธผิดพลาด | pass | pass | pass | pass |  |
| 7 | เมื่อสำเร็จ endpoint บันทึก `EndsAt` ใหม่ลงฐานข้อมูลจริง และคืนค่า booking ที่อัปเดตแล้ว | pass | pass | pass | pass |  |
| 8 | endpoint คืนค่า error response แบบ 4xx เมื่อกฎข้อใดข้อหนึ่งใน 4 ข้อข้างต้นถูกละเมิด | pass | pass | pass | pass |  |
| 9 | โค้ดที่เพิ่มตรงตาม convention ของ ASP.NET Core ที่ repo ใช้อยู่แล้ว (controller action, `[FromBody]`, async/await ตลอด) | pass | pass | pass | pass |  |
| 10 | diff ไม่แตะ controller หรือ service อื่นที่ไม่เกี่ยวข้องกับ endpoint นี้ | pass | pass | pass | pass |  |
| 11 | ไม่มีการสร้าง service layer ใหม่ทั้งชั้นสำหรับ endpoint เดียวนี้ ทั้งที่ repo ปัจจุบันเรียก DbContext ตรงจาก controller | pass | pass | pass | pass |  |
| 12 | โปรเจกต์ build ผ่านหลังเพิ่มโค้ด | fail | fail | fail | fail |  |

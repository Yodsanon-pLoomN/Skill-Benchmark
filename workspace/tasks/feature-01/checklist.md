# Checklist — feature-01

## ความถูกต้อง/ความครบถ้วน

1. เพิ่ม endpoint `PATCH /bookings/{id}/extend` ใหม่ในโปรเจกต์
2. endpoint ปฏิเสธการขยายเวลาเมื่อ booking มี Status ไม่ใช่ CONFIRMED (เช่น CANCELLED)
3. endpoint ปฏิเสธเมื่อ `newEndsAt` ไม่ได้อยู่หลัง `EndsAt` เดิมอย่างเคร่งครัด (เช่น เท่ากับหรือมาก่อน `EndsAt` เดิม)
4. endpoint คำนวณระยะเวลารวมจาก `StartsAt` เดิมถึง `newEndsAt` ใหม่ (ไม่ใช่จาก `EndsAt` เดิม) แล้วปฏิเสธถ้าเกิน 8 ชั่วโมง
5. endpoint เช็ค overlap ของช่วงเวลาที่ขยายแล้วกับ booking อื่นที่ CONFIRMED ในห้องเดียวกัน โดยไม่รวม booking ของตัวมันเอง (ไม่เกิด self-conflict กับช่วงเวลาเดิมของตัวเอง)
6. การเช็ค overlap ใช้สูตร half-open (`a.StartsAt < b.EndsAt && a.EndsAt > b.StartsAt`) ไม่ใช้ `<=`/`>=` ที่จะทำให้การขยายแบบต่อเนื่องพอดี (back-to-back) ถูกปฏิเสธผิดพลาด
7. เมื่อสำเร็จ endpoint บันทึก `EndsAt` ใหม่ลงฐานข้อมูลจริง และคืนค่า booking ที่อัปเดตแล้ว
8. endpoint คืนค่า error response แบบ 4xx เมื่อกฎข้อใดข้อหนึ่งใน 4 ข้อข้างต้นถูกละเมิด

## คุณภาพ

9. โค้ดที่เพิ่มตรงตาม convention ของ ASP.NET Core ที่ repo ใช้อยู่แล้ว (controller action, `[FromBody]`, async/await ตลอด)
10. diff ไม่แตะ controller หรือ service อื่นที่ไม่เกี่ยวข้องกับ endpoint นี้
11. ไม่มีการสร้าง service layer ใหม่ทั้งชั้นสำหรับ endpoint เดียวนี้ ทั้งที่ repo ปัจจุบันเรียก DbContext ตรงจาก controller
12. โปรเจกต์ build ผ่านหลังเพิ่มโค้ด

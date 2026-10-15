# Checklist — feature-03

## ความถูกต้อง/ความครบถ้วน

1. เพิ่ม endpoint `GET /reports/room-usage/{roomId}` ใหม่
2. endpoint คืนค่า 404 เมื่อไม่พบห้องที่มี `roomId` นั้นอยู่จริง
3. endpoint คืนค่า id, name, จำนวน booking CONFIRMED, total booked hours และ longest booking hours (ชั่วโมง) ของห้องนั้น
4. booking ที่ CANCELLED ไม่ถูกนับรวมในทั้งจำนวน, total hours หรือ longest booking hours
5. เมื่อเรียกกับห้องที่มี booking CONFIRMED เป็นศูนย์ (เช่น room-b/"Beta") endpoint คืนค่า response ปกติ (200) ที่มีค่า count/total/longest เป็น 0 ทั้งหมด ไม่ throw exception หรือ error 500

## คุณภาพ

6. โค้ดตรงตาม convention ของ `ReportsController`/`RoomUsageReportService` เดิม (record type, `Include(r => r.Bookings)` แบบเดียวกับ endpoint เดิม, async/await)
7. โค้ดป้องกัน `.Max()` บนลิสต์ว่างด้วยการเช็คเงื่อนไข (เช่น `.Count > 0`) ก่อนเรียก ไม่ใช่ด้วย try/catch
8. โค้ดดึงข้อมูล Bookings มาครั้งเดียวแล้ว filter ใน memory เหมือน endpoint เดิม ไม่ query ฐานข้อมูลแยกหลายรอบสำหรับ count/sum/max
9. diff ไม่แตะ endpoint อื่นที่ไม่เกี่ยวข้อง
10. โปรเจกต์ build ผ่านหลังเพิ่มโค้ด

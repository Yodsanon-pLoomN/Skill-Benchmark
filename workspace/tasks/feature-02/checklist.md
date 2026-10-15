# Checklist — feature-02

## ความถูกต้อง/ความครบถ้วน

1. เพิ่ม endpoint `GET /reports/upcoming-bookings` ใหม่ พร้อมรับ query parameter `withinHours` และ `asOf` (optional)
2. endpoint กรองเฉพาะ booking ที่ Status เป็น CONFIRMED เท่านั้น (booking ที่ CANCELLED ไม่ปรากฏในผลลัพธ์เลย)
3. เมื่อไม่ส่ง `asOf` มา endpoint ใช้เวลาปัจจุบัน (UTC) เป็นค่าเริ่มต้นแทน
4. เมื่อส่ง `asOf` มา endpoint ใช้ค่านั้นเป็นเวลาอ้างอิงแทนเวลาปัจจุบันจริง
5. endpoint กรองด้วยขอบเขต `StartsAt` ของ booking ให้อยู่ในช่วง `[asOf, asOf+withinHours)` แบบ half-open (รวมขอบล่าง ไม่รวมขอบบน) ไม่ใช่การเปรียบเทียบด้วย `EndsAt`
6. booking ที่เริ่มไปแล้วก่อน `asOf` (แม้ `EndsAt` ยังไม่ถึง/ยังดำเนินอยู่) ไม่ถูกนับว่า upcoming
7. `withinHours` มีค่า default เป็น 24 เมื่อไม่ได้ระบุ
8. ผลลัพธ์เรียงลำดับตาม `StartsAt` จากน้อยไปมาก
9. แต่ละรายการผลลัพธ์มีข้อมูล room id, room name, user id, `StartsAt` และ `EndsAt` ครบ

## คุณภาพ

10. โค้ดตรงตาม convention ของ repo (controller action หรือ service method เดิม, `[FromQuery]`, async/await)
11. query ใช้ EF Core แปลเป็น SQL (filter ผ่าน `.Where` ก่อน) แทนที่จะดึงข้อมูลทั้งหมดมา filter ใน memory
12. diff ไม่แตะโค้ดอื่นที่ไม่เกี่ยวข้อง
13. โปรเจกต์ build ผ่านหลังเพิ่มโค้ด

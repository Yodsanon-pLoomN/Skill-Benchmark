# Checklist — bugfix-03

## ความถูกต้อง/ความครบถ้วน

1. diff เพิ่มการเช็ค `room.isActive` กลับเข้าไปใน `createBooking()` ของ `src/services/bookingService.ts` (โยน error เช่น `RoomInactiveError` เมื่อห้องไม่ active)
2. diff แก้ไข `cancelBooking()` ใน `src/services/bookingService.ts` ให้ return booking เดิม (ที่ถูกยกเลิกไปแล้ว) แทนการ throw error เมื่อยกเลิกซ้ำ
3. การเช็ค `isActive` ถูกเพิ่มกลับเข้าไปใน `bookingService` (service/domain layer) ไม่ใช่แค่เพิ่มใน API handler/controller เท่านั้น
4. ถ้า diff เพิ่ม import `RoomInactiveError` กลับมา (เพราะถูกลบไปพร้อมบั๊ก) import นั้นถูกต้องและไม่ทำให้ compile error
5. หลังแก้ไข การพยายามจองห้องที่ `isActive=false` ถูกปฏิเสธ
6. หลังแก้ไข การยกเลิก booking ที่ถูกยกเลิกไปแล้ว ไม่โยน error (เป็น no-op ตามเดิม)

## คุณภาพ

7. diff แก้เฉพาะจุดที่จำเป็น (1 บรรทัดเพิ่ม + 1 บรรทัดแก้) ไม่แตะไฟล์อื่นที่ไม่เกี่ยวข้อง
8. ไม่มีการย้าย `isActive` check ไปไว้ที่ repository layer แทนที่จะอยู่ใน service เหมือนเดิม
9. ข้อความ error ที่ throw ตรงกับของเดิม (ไม่เปลี่ยนข้อความโดยไม่จำเป็น)
10. diff ไม่ทำให้โปรเจกต์ compile พัง

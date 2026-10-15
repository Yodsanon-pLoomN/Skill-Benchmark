# Checklist — refactor-01

## ความถูกต้อง/ความครบถ้วน

1. diff extract โค้ดสแกน overlap (`findBookingsForDay` + `.some(existing => overlaps(...))`) ออกมาเป็นฟังก์ชัน/helper เดียวที่ใช้ร่วมกัน
2. ทั้ง `createBooking` และ `checkAvailability` เรียกใช้ฟังก์ชัน/helper ที่แชร์ร่วมกันนั้น (ไม่ใช่แค่จุดใดจุดหนึ่ง)
3. `createBooking` ยังคงโยน `SlotUnavailableError` เมื่อพบ overlap เหมือนเดิม (พฤติกรรมไม่เปลี่ยน)
4. `checkAvailability` ยังคงมี fast-path short-circuit ก่อน interval-sweep เหมือนเดิม โดยพฤติกรรมไม่เปลี่ยนไปจากเดิม
5. โค้ดเดิมที่ซ้ำกัน (การสแกน `.some(existing => overlaps(...))` แยกกัน 2 จุด) ไม่มีเหลืออยู่แล้วหลังแก้ (ถูกลบออกจริง ไม่ใช่แค่เพิ่ม helper มาซ้อนโดยไม่ลบของเดิม)

## คุณภาพ

6. helper ที่สร้างใหม่วางอยู่ในตำแหน่งที่สมเหตุผล (เช่นใกล้ `domain/booking.ts` หรือใน `bookingService.ts` เอง) ไม่ได้สร้างไฟล์ util แยกใหม่ที่ไม่เข้าธรรมเนียมโปรเจกต์
7. ชื่อฟังก์ชัน/ตัวแปรที่สร้างใหม่สื่อความหมายและตรงสไตล์ naming เดิมของไฟล์ (camelCase, async/await)
8. diff ไม่แตะไฟล์อื่นที่ไม่เกี่ยวข้องกับการ refactor นี้
9. helper ที่สร้างไม่มี parameter หรือ abstraction ที่ไม่จำเป็นเกินตัว
10. diff ไม่ทำให้โปรเจกต์ compile หรือ lint พัง

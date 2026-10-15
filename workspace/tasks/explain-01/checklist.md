# Checklist — explain-01

## ความถูกต้อง/ความครบถ้วน

1. คำตอบระบุว่า `RoomService` เป็นเพียง thin HTTP client wrapper (มีเมธอด `listRooms`/`getAvailability` ที่คืนค่า Observable) ไม่ถือ UI state และไม่ตัดสินใจเรื่องการจัดรูปแบบการแสดงผล
2. คำตอบระบุว่า `RoomAvailabilityComponent` เป็นตัวเก็บ UI state ทั้งหมด (เช่น `rooms`, `selectedRoomId`, `date`, `freeIntervals`, `loading`) และเป็นจุดเดียวที่ subscribe ต่อ Observable ของ service
3. คำตอบอธิบายว่า `RoomService` ถูก inject เข้า component ผ่าน constructor (dependency injection)
4. คำตอบ trace ลำดับการทำงานตั้งแต่ `ngOnInit` จนถึงการแสดงผล โดยระบุว่ามีการเรียก `GET /rooms/:id/availability` ไปที่ Node API
5. คำตอบระบุชัดเจนว่า backend (ไม่ใช่ component) เป็นผู้คำนวณ free interval แล้วส่งกลับมา component ไม่ได้คำนวณ availability เอง
6. คำตอบอธิบายว่า `formatSlot` แสดงเวลาแบบ UTC (ไม่ใช่ local time) เพราะ backend ส่งค่ามาเป็น UTC และการแสดงเป็น local time อาจทำให้ขอบเขตของช่วงเวลาที่แสดงผลผิดไปจากความจริง
7. คำตอบระบุว่า component ปัจจุบันไม่มีการคำนวณ/เปรียบเทียบช่วงเวลาเอง เป็นเพียงการแสดงผลข้อมูลที่ backend ส่งมา (และถ้าต้องทำในอนาคตต้องใช้ half-open comparison แบบเดียวกับ backend)

## คุณภาพ

8. คำตอบเรียงลำดับตามคำถามทั้ง 3 ข้อที่ถามในโจทย์ ไม่วกวนข้ามหัวข้อ
9. คำตอบใช้ศัพท์ทางเทคนิคถูกต้องสม่ำเสมอ (เช่น Observable, dependency injection)
10. ไฟล์ในโปรเจกต์ไม่ถูกแก้ไข/สร้างใหม่ (ตรงตามคำสั่ง "do not change any files" ในโจทย์)

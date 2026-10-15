# Checklist — refactor-03

## ความถูกต้อง/ความครบถ้วน

1. diff extract โค้ด `d.toISOString().slice(11, 16)` (แปลง `Date` เป็น HH:mm) ออกมาเป็นฟังก์ชัน/method เดียวที่ใช้ร่วมกัน
2. ทั้ง `formatSlot` และ `formatTimestamp` เรียกใช้ฟังก์ชัน/method ที่แชร์ร่วมกันนั้นแทนการคำนวณ `.slice(11, 16)` แยกกันเอง
3. `formatSlot` ยังคง assemble ข้อความช่วงเวลารูปแบบ "HH:mm–HH:mm UTC" เหมือนเดิม (ต่อ en dash และคำว่า UTC เอง รอบ core formatter)
4. `formatTimestamp` ยังคงต่อคำว่า " UTC" ต่อท้ายเวลาเดี่ยวเหมือนเดิม (ไม่ได้กลายเป็นรูปแบบช่วงเวลา)
5. ข้อความที่แสดงบนหน้าจอ (รายการ free slot และบรรทัด "Last updated at HH:mm UTC") เหมือนเดิมทุกตัวอักษรก่อนและหลัง refactor

## คุณภาพ

6. helper ที่สร้างใหม่วางในตำแหน่งที่สมเหตุผล (เช่น private method ในคลาสเดียวกัน) ไม่ได้สร้างไฟล์ util แยกใหม่ทั้งที่โปรเจกต์เล็กไม่มี pattern นี้
7. diff ไม่แตะ template (`.html`) หรือไฟล์อื่นเกินความจำเป็น
8. ไม่มีการเพิ่ม Angular pipe ใหม่ทั้งอันสำหรับ logic บรรทัดเดียวนี้
9. diff ไม่ทำให้ `ng build` พัง

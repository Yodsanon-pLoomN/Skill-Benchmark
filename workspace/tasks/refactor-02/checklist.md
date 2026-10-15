# Checklist — refactor-02

## ความถูกต้อง/ความครบถ้วน

1. diff แก้ `checkAvailability` ใน `src/services/bookingService.ts` ให้เรียกใช้ `startOfUtcDay(dateStr)` แทนการเขียน `new Date(\`${dateStr}T00:00:00.000Z\`)` เอง
2. diff แก้ `checkAvailability` ให้เรียกใช้ `endOfUtcDay(dateStr)` แทนการเขียน `new Date(\`${dateStr}T23:59:59.999Z\`)` เอง
3. ค่า `dayStart`/`dayEnd` ที่ได้จากการเรียก helper ตรงกับที่ inline code เดิมให้พอดี (`T00:00:00.000Z` / `T23:59:59.999Z` ไม่ใช่ "ต้นวันถัดไป" หรือค่าอื่นที่คลาดเคลื่อน)
4. diff import `startOfUtcDay`/`endOfUtcDay` จาก `../lib/time.js` (หรือ path ที่ถูกต้องของไฟล์นั้น)
5. ไม่มีโค้ด inline (`new Date` แบบ template string สำหรับ start/end of day) หลงเหลืออยู่ใน `checkAvailability` หลังแก้ไข

## คุณภาพ

6. import ใช้ named import ตรงกับสไตล์ที่ `bookingRepository.ts` ใช้อยู่แล้ว (ไม่ใช้ `import * as time`)
7. diff ไม่แตะไฟล์อื่นนอกจาก `src/services/bookingService.ts`
8. ไม่มีการสร้าง wrapper function ใหม่ห่อ `startOfUtcDay`/`endOfUtcDay` อีกชั้นโดยไม่จำเป็น
9. diff ไม่ทำให้โปรเจกต์ compile หรือ lint พัง

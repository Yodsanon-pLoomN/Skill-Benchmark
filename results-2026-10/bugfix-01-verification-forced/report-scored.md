# Scored report — bugfix-01

AI-graded, blind to condition, 3 independent passes per run, majority vote per item, run verdict = pass if >= 80% items pass.

## Run A — PASS (100.0% passed)

| item | text | pass1 | pass2 | pass3 | final | split |
|---|---|---|---|---|---|---|
| 1 | diff แก้ไข `overlaps()` ใน `src/domain/booking.ts` ให้ใช้ตัวเปรียบเทียบเข้มงวด (`<` และ `>`) แทน `<=` และ `>=` สำหรับเช็คว่าสองช่วงเวลาทับกันหรือไม่ | pass | pass | pass | pass |  |
| 2 | diff แก้ไข `findBookingsForDay()` ใน `src/repositories/bookingRepository.ts` ให้กรองเฉพาะ booking ที่ยังไม่ถูกยกเลิก (ไม่ใช่ `CANCELLED`) ก่อนนำไปเช็คว่าห้องว่างหรือไม่ | pass | pass | pass | pass |  |
| 3 | หลังแก้ไข การจองแบบต่อเนื่องพอดี (back-to-back — จองหนึ่งจบตอนที่อีกจองเริ่มพอดี) ไม่ถูกปฏิเสธอีกต่อไป | pass | pass | pass | pass |  |
| 4 | หลังแก้ไข booking ที่ถูกยกเลิก (`CANCELLED`) ไม่ทำให้ช่วงเวลานั้นถูกมองว่าไม่ว่าง | pass | pass | pass | pass |  |
| 5 | diff ไม่ทำให้ booking ที่ถูกยกเลิก (`CANCELLED`) หายไปจาก endpoint ที่ดึงรายการ booking ของผู้ใช้ (`GET /bookings?userId=...`) หรือทำให้ยกเลิก booking ที่ถูกยกเลิกไปแล้วซ้ำไม่ได้ (ไม่ over-filter ด้วย status ในทุก query) | pass | pass | pass | pass |  |
| 6 | diff แก้เฉพาะจุดที่จำเป็น (การเปลี่ยน operator ใน `overlaps()` และเพิ่มเงื่อนไข status ใน `findBookingsForDay()`) ไม่แตะไฟล์อื่นที่ไม่เกี่ยวข้อง | pass | pass | pass | pass |  |
| 7 | โค้ดที่แก้ไม่มีการ rename ตัวแปร/ฟังก์ชันอื่นที่ไม่เกี่ยวกับการแก้บั๊กปนมาด้วย | pass | pass | pass | pass |  |
| 8 | โค้ดที่แก้ไม่มีการเพิ่ม helper function ใหม่สำหรับการเปรียบเทียบง่ายๆ ที่ไม่จำเป็น | pass | pass | pass | pass |  |
| 9 | diff ไม่ทำให้โปรเจกต์ compile หรือ lint พัง | pass | pass | pass | pass |  |
| 10 | สไตล์โค้ดที่แก้ (การเว้นวรรค, quote, comment) ตรงกับสไตล์เดิมของไฟล์ | pass | pass | pass | pass |  |

## Run B — PASS (100.0% passed)

| item | text | pass1 | pass2 | pass3 | final | split |
|---|---|---|---|---|---|---|
| 1 | diff แก้ไข `overlaps()` ใน `src/domain/booking.ts` ให้ใช้ตัวเปรียบเทียบเข้มงวด (`<` และ `>`) แทน `<=` และ `>=` สำหรับเช็คว่าสองช่วงเวลาทับกันหรือไม่ | pass | pass | pass | pass |  |
| 2 | diff แก้ไข `findBookingsForDay()` ใน `src/repositories/bookingRepository.ts` ให้กรองเฉพาะ booking ที่ยังไม่ถูกยกเลิก (ไม่ใช่ `CANCELLED`) ก่อนนำไปเช็คว่าห้องว่างหรือไม่ | pass | pass | pass | pass |  |
| 3 | หลังแก้ไข การจองแบบต่อเนื่องพอดี (back-to-back — จองหนึ่งจบตอนที่อีกจองเริ่มพอดี) ไม่ถูกปฏิเสธอีกต่อไป | pass | pass | pass | pass |  |
| 4 | หลังแก้ไข booking ที่ถูกยกเลิก (`CANCELLED`) ไม่ทำให้ช่วงเวลานั้นถูกมองว่าไม่ว่าง | pass | pass | pass | pass |  |
| 5 | diff ไม่ทำให้ booking ที่ถูกยกเลิก (`CANCELLED`) หายไปจาก endpoint ที่ดึงรายการ booking ของผู้ใช้ (`GET /bookings?userId=...`) หรือทำให้ยกเลิก booking ที่ถูกยกเลิกไปแล้วซ้ำไม่ได้ (ไม่ over-filter ด้วย status ในทุก query) | pass | pass | pass | pass |  |
| 6 | diff แก้เฉพาะจุดที่จำเป็น (การเปลี่ยน operator ใน `overlaps()` และเพิ่มเงื่อนไข status ใน `findBookingsForDay()`) ไม่แตะไฟล์อื่นที่ไม่เกี่ยวข้อง | pass | pass | pass | pass |  |
| 7 | โค้ดที่แก้ไม่มีการ rename ตัวแปร/ฟังก์ชันอื่นที่ไม่เกี่ยวกับการแก้บั๊กปนมาด้วย | pass | pass | pass | pass |  |
| 8 | โค้ดที่แก้ไม่มีการเพิ่ม helper function ใหม่สำหรับการเปรียบเทียบง่ายๆ ที่ไม่จำเป็น | pass | pass | pass | pass |  |
| 9 | diff ไม่ทำให้โปรเจกต์ compile หรือ lint พัง | pass | pass | pass | pass |  |
| 10 | สไตล์โค้ดที่แก้ (การเว้นวรรค, quote, comment) ตรงกับสไตล์เดิมของไฟล์ | pass | pass | pass | pass |  |

## Run C — PASS (100.0% passed)

| item | text | pass1 | pass2 | pass3 | final | split |
|---|---|---|---|---|---|---|
| 1 | diff แก้ไข `overlaps()` ใน `src/domain/booking.ts` ให้ใช้ตัวเปรียบเทียบเข้มงวด (`<` และ `>`) แทน `<=` และ `>=` สำหรับเช็คว่าสองช่วงเวลาทับกันหรือไม่ | pass | pass | pass | pass |  |
| 2 | diff แก้ไข `findBookingsForDay()` ใน `src/repositories/bookingRepository.ts` ให้กรองเฉพาะ booking ที่ยังไม่ถูกยกเลิก (ไม่ใช่ `CANCELLED`) ก่อนนำไปเช็คว่าห้องว่างหรือไม่ | pass | pass | pass | pass |  |
| 3 | หลังแก้ไข การจองแบบต่อเนื่องพอดี (back-to-back — จองหนึ่งจบตอนที่อีกจองเริ่มพอดี) ไม่ถูกปฏิเสธอีกต่อไป | pass | pass | pass | pass |  |
| 4 | หลังแก้ไข booking ที่ถูกยกเลิก (`CANCELLED`) ไม่ทำให้ช่วงเวลานั้นถูกมองว่าไม่ว่าง | pass | pass | pass | pass |  |
| 5 | diff ไม่ทำให้ booking ที่ถูกยกเลิก (`CANCELLED`) หายไปจาก endpoint ที่ดึงรายการ booking ของผู้ใช้ (`GET /bookings?userId=...`) หรือทำให้ยกเลิก booking ที่ถูกยกเลิกไปแล้วซ้ำไม่ได้ (ไม่ over-filter ด้วย status ในทุก query) | pass | pass | pass | pass |  |
| 6 | diff แก้เฉพาะจุดที่จำเป็น (การเปลี่ยน operator ใน `overlaps()` และเพิ่มเงื่อนไข status ใน `findBookingsForDay()`) ไม่แตะไฟล์อื่นที่ไม่เกี่ยวข้อง | pass | pass | pass | pass |  |
| 7 | โค้ดที่แก้ไม่มีการ rename ตัวแปร/ฟังก์ชันอื่นที่ไม่เกี่ยวกับการแก้บั๊กปนมาด้วย | pass | pass | pass | pass |  |
| 8 | โค้ดที่แก้ไม่มีการเพิ่ม helper function ใหม่สำหรับการเปรียบเทียบง่ายๆ ที่ไม่จำเป็น | pass | pass | pass | pass |  |
| 9 | diff ไม่ทำให้โปรเจกต์ compile หรือ lint พัง | pass | pass | pass | pass |  |
| 10 | สไตล์โค้ดที่แก้ (การเว้นวรรค, quote, comment) ตรงกับสไตล์เดิมของไฟล์ | pass | pass | pass | pass |  |

## Run D — PASS (90.0% passed)

| item | text | pass1 | pass2 | pass3 | final | split |
|---|---|---|---|---|---|---|
| 1 | diff แก้ไข `overlaps()` ใน `src/domain/booking.ts` ให้ใช้ตัวเปรียบเทียบเข้มงวด (`<` และ `>`) แทน `<=` และ `>=` สำหรับเช็คว่าสองช่วงเวลาทับกันหรือไม่ | pass | pass | pass | pass |  |
| 2 | diff แก้ไข `findBookingsForDay()` ใน `src/repositories/bookingRepository.ts` ให้กรองเฉพาะ booking ที่ยังไม่ถูกยกเลิก (ไม่ใช่ `CANCELLED`) ก่อนนำไปเช็คว่าห้องว่างหรือไม่ | pass | pass | pass | pass |  |
| 3 | หลังแก้ไข การจองแบบต่อเนื่องพอดี (back-to-back — จองหนึ่งจบตอนที่อีกจองเริ่มพอดี) ไม่ถูกปฏิเสธอีกต่อไป | pass | pass | pass | pass |  |
| 4 | หลังแก้ไข booking ที่ถูกยกเลิก (`CANCELLED`) ไม่ทำให้ช่วงเวลานั้นถูกมองว่าไม่ว่าง | pass | pass | pass | pass |  |
| 5 | diff ไม่ทำให้ booking ที่ถูกยกเลิก (`CANCELLED`) หายไปจาก endpoint ที่ดึงรายการ booking ของผู้ใช้ (`GET /bookings?userId=...`) หรือทำให้ยกเลิก booking ที่ถูกยกเลิกไปแล้วซ้ำไม่ได้ (ไม่ over-filter ด้วย status ในทุก query) | fail | fail | fail | fail |  |
| 6 | diff แก้เฉพาะจุดที่จำเป็น (การเปลี่ยน operator ใน `overlaps()` และเพิ่มเงื่อนไข status ใน `findBookingsForDay()`) ไม่แตะไฟล์อื่นที่ไม่เกี่ยวข้อง | pass | pass | pass | pass |  |
| 7 | โค้ดที่แก้ไม่มีการ rename ตัวแปร/ฟังก์ชันอื่นที่ไม่เกี่ยวกับการแก้บั๊กปนมาด้วย | pass | pass | pass | pass |  |
| 8 | โค้ดที่แก้ไม่มีการเพิ่ม helper function ใหม่สำหรับการเปรียบเทียบง่ายๆ ที่ไม่จำเป็น | pass | pass | pass | pass |  |
| 9 | diff ไม่ทำให้โปรเจกต์ compile หรือ lint พัง | pass | pass | pass | pass |  |
| 10 | สไตล์โค้ดที่แก้ (การเว้นวรรค, quote, comment) ตรงกับสไตล์เดิมของไฟล์ | pass | pass | pass | pass |  |

## Run E — PASS (90.0% passed)

| item | text | pass1 | pass2 | pass3 | final | split |
|---|---|---|---|---|---|---|
| 1 | diff แก้ไข `overlaps()` ใน `src/domain/booking.ts` ให้ใช้ตัวเปรียบเทียบเข้มงวด (`<` และ `>`) แทน `<=` และ `>=` สำหรับเช็คว่าสองช่วงเวลาทับกันหรือไม่ | pass | pass | pass | pass |  |
| 2 | diff แก้ไข `findBookingsForDay()` ใน `src/repositories/bookingRepository.ts` ให้กรองเฉพาะ booking ที่ยังไม่ถูกยกเลิก (ไม่ใช่ `CANCELLED`) ก่อนนำไปเช็คว่าห้องว่างหรือไม่ | pass | pass | pass | pass |  |
| 3 | หลังแก้ไข การจองแบบต่อเนื่องพอดี (back-to-back — จองหนึ่งจบตอนที่อีกจองเริ่มพอดี) ไม่ถูกปฏิเสธอีกต่อไป | pass | pass | pass | pass |  |
| 4 | หลังแก้ไข booking ที่ถูกยกเลิก (`CANCELLED`) ไม่ทำให้ช่วงเวลานั้นถูกมองว่าไม่ว่าง | pass | pass | pass | pass |  |
| 5 | diff ไม่ทำให้ booking ที่ถูกยกเลิก (`CANCELLED`) หายไปจาก endpoint ที่ดึงรายการ booking ของผู้ใช้ (`GET /bookings?userId=...`) หรือทำให้ยกเลิก booking ที่ถูกยกเลิกไปแล้วซ้ำไม่ได้ (ไม่ over-filter ด้วย status ในทุก query) | fail | fail | fail | fail |  |
| 6 | diff แก้เฉพาะจุดที่จำเป็น (การเปลี่ยน operator ใน `overlaps()` และเพิ่มเงื่อนไข status ใน `findBookingsForDay()`) ไม่แตะไฟล์อื่นที่ไม่เกี่ยวข้อง | pass | pass | pass | pass |  |
| 7 | โค้ดที่แก้ไม่มีการ rename ตัวแปร/ฟังก์ชันอื่นที่ไม่เกี่ยวกับการแก้บั๊กปนมาด้วย | pass | pass | pass | pass |  |
| 8 | โค้ดที่แก้ไม่มีการเพิ่ม helper function ใหม่สำหรับการเปรียบเทียบง่ายๆ ที่ไม่จำเป็น | pass | pass | pass | pass |  |
| 9 | diff ไม่ทำให้โปรเจกต์ compile หรือ lint พัง | pass | pass | pass | pass |  |
| 10 | สไตล์โค้ดที่แก้ (การเว้นวรรค, quote, comment) ตรงกับสไตล์เดิมของไฟล์ | pass | pass | pass | pass |  |

## Run F — PASS (100.0% passed)

| item | text | pass1 | pass2 | pass3 | final | split |
|---|---|---|---|---|---|---|
| 1 | diff แก้ไข `overlaps()` ใน `src/domain/booking.ts` ให้ใช้ตัวเปรียบเทียบเข้มงวด (`<` และ `>`) แทน `<=` และ `>=` สำหรับเช็คว่าสองช่วงเวลาทับกันหรือไม่ | pass | pass | pass | pass |  |
| 2 | diff แก้ไข `findBookingsForDay()` ใน `src/repositories/bookingRepository.ts` ให้กรองเฉพาะ booking ที่ยังไม่ถูกยกเลิก (ไม่ใช่ `CANCELLED`) ก่อนนำไปเช็คว่าห้องว่างหรือไม่ | pass | pass | pass | pass |  |
| 3 | หลังแก้ไข การจองแบบต่อเนื่องพอดี (back-to-back — จองหนึ่งจบตอนที่อีกจองเริ่มพอดี) ไม่ถูกปฏิเสธอีกต่อไป | pass | pass | pass | pass |  |
| 4 | หลังแก้ไข booking ที่ถูกยกเลิก (`CANCELLED`) ไม่ทำให้ช่วงเวลานั้นถูกมองว่าไม่ว่าง | pass | pass | pass | pass |  |
| 5 | diff ไม่ทำให้ booking ที่ถูกยกเลิก (`CANCELLED`) หายไปจาก endpoint ที่ดึงรายการ booking ของผู้ใช้ (`GET /bookings?userId=...`) หรือทำให้ยกเลิก booking ที่ถูกยกเลิกไปแล้วซ้ำไม่ได้ (ไม่ over-filter ด้วย status ในทุก query) | pass | pass | pass | pass |  |
| 6 | diff แก้เฉพาะจุดที่จำเป็น (การเปลี่ยน operator ใน `overlaps()` และเพิ่มเงื่อนไข status ใน `findBookingsForDay()`) ไม่แตะไฟล์อื่นที่ไม่เกี่ยวข้อง | pass | pass | pass | pass |  |
| 7 | โค้ดที่แก้ไม่มีการ rename ตัวแปร/ฟังก์ชันอื่นที่ไม่เกี่ยวกับการแก้บั๊กปนมาด้วย | pass | pass | pass | pass |  |
| 8 | โค้ดที่แก้ไม่มีการเพิ่ม helper function ใหม่สำหรับการเปรียบเทียบง่ายๆ ที่ไม่จำเป็น | pass | pass | pass | pass |  |
| 9 | diff ไม่ทำให้โปรเจกต์ compile หรือ lint พัง | pass | pass | pass | pass |  |
| 10 | สไตล์โค้ดที่แก้ (การเว้นวรรค, quote, comment) ตรงกับสไตล์เดิมของไฟล์ | pass | pass | pass | pass |  |

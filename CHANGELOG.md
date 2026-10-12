# Changelog

## [Unreleased]

### Added
- ปุ่ม "สร้าง LayOut": สร้าง/ต่อท้าย `OPP-… Master Layout.layout` จาก template CIxCM ข้างไฟล์ `.skp`, กรอก ProjectName / ClientName / ProjectNumber จาก Odoo (ค้นด้วยเลข OPP ใน path) และใส่ model ปัจจุบันแทน viewport ตามชื่อ scene มาตรฐาน (`<หน้า>` หรือ `<หน้า>-1` / `<หน้า>-01` เรียงบน→ล่าง แล้วซ้าย→ขวา)
- กรอก auto-text DrawnBy (ชื่อ user Odoo ที่ login ที่ Hub) และ ClientAddress (ที่อยู่ลูกค้าจาก Odoo `contact_address` ไม่รวมบรรทัดชื่อบริษัท) — อ่านไม่ได้จะเตือนแต่ยังสร้างไฟล์
- Master Layout: 1 ไฟล์ต่อโครงการ `OPP-… Master Layout.layout` — model แรกสร้างจาก template, model ถัดไปในโฟลเดอร์เดียวกันเพิ่มหน้า model (`<model> - <หน้า>`) ต่อท้าย พร้อม copy ข้อความ / เส้น / วงกลม / group จาก template และซ่อน/แสดง layer เหมือนหน้าต้นฉบับ
- Title ของหน้า model บรรทัด 2: ชื่อ scene ใต้ `<PageName>` และลำดับ A, B … ใต้ `<PageNumber>`
- ต้องใช้ SKP CM Extensions Hub 0.5.0 ขึ้นไป (login Odoo ที่ Hub)

# Changelog

## [Unreleased]

### Added
- ปุ่ม "สร้าง LayOut": สร้าง `.layout` จาก template CIxCM ข้างไฟล์ `.skp`, กรอก ProjectName / ClientName / ProjectNumber จาก Odoo (ค้นด้วยเลข OPP ใน path) และใส่ model ปัจจุบันแทน viewport ตามชื่อ scene มาตรฐาน (`<หน้า>` หรือ `<หน้า>-1` / `<หน้า>-01` เรียงบน→ล่าง แล้วซ้าย→ขวา)
- ต้องใช้ SKP CM Extensions Hub 0.5.0 ขึ้นไป (login Odoo ที่ Hub)

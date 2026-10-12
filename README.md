# SKP CM Layout Generator

สร้างไฟล์ LayOut ของโครงการจาก SketchUp ด้วยปุ่มเดียว (SketchUp 2024+)

1. Login Odoo ที่ **SKP CM Extensions Hub** (0.5.0+)
2. เปิด `.skp` ที่อยู่ในโฟลเดอร์โครงการ `OPP-xxxxxxxxxxx` แล้ว save
3. กด **สร้าง LayOut** → ได้ `<ชื่อ skp>.layout` ในโฟลเดอร์เดียวกัน

## ชื่อ scene มาตรฐาน

| หน้าใน LayOut | viewport | scene ใน SketchUp |
| --- | --- | --- |
| หน้าที่มี viewport เดียว | 1 | ชื่อหน้า เช่น `Overall` |
| หน้าที่มีหลาย viewport | เรียงซ้าย→ขวา, บน→ล่าง | `<ชื่อหน้า>-<ลำดับ>` เช่น `A-1`, `A-2` |

ไม่พบ scene → ใช้ "Last saved SketchUp View" และแจ้งเตือน

## Development

- Test: `for t in tests/tc_*.rb; do ruby "$t"; done`
- Build: `./build.sh` (ต้องมี `skp_cm_layout_generator/templates/CIxCM.layout` — ไฟล์นี้ไม่อยู่ใน git)

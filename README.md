# SKP CM Layout Generator

สร้างไฟล์ LayOut ของโครงการจาก SketchUp ด้วยปุ่มเดียว (SketchUp 2024+)

1. Login Odoo ที่ **SKP CM Extensions Hub** (0.5.0+)
2. เปิด `.skp` ที่อยู่ในโฟลเดอร์โครงการ `OPP-xxxxxxxxxxx` แล้ว save
3. กด **สร้าง LayOut** → ได้ `OPP-xxxxxxxxxxx Master Layout.layout` ในโฟลเดอร์เดียวกัน (หน้า model ชื่อ `<ชื่อ skp> - <หน้า>`)
4. เปิด `.skp` อีก model ในโฟลเดอร์เดียวกันแล้วกดอีกครั้ง → เพิ่มหน้าของ model นั้นต่อท้ายไฟล์เดิม (auto-text ไม่เปลี่ยน; กดซ้ำกับ model เดิมจะไม่เพิ่ม — ใช้ Update Model Reference ใน LayOut)

## ชื่อ scene มาตรฐาน

| หน้าใน LayOut | viewport | scene ใน SketchUp |
| --- | --- | --- |
| หน้าที่มี viewport เดียว | 1 | ชื่อหน้า เช่น `Overall` |
| หน้าที่มีหลาย viewport | เรียงบน→ล่าง; อันที่สูงซ้อนกัน (แถวเดียวกัน) เรียงซ้าย→ขวา | `<ชื่อหน้า>-<ลำดับ>` เช่น `A-1` หรือ `A-01` |

ไม่พบ scene → ใช้ "Last saved SketchUp View" และแจ้งเตือน

## Development

- Test: `for t in tests/tc_*.rb; do ruby "$t"; done`
- Build: `./build.sh` (รวม template `skp_cm_layout_generator/templates/CIxCM.layout`; ไฟล์ backup `*~*` ของ LayOut ไม่ถูกรวม)

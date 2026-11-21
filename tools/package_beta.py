#!/usr/bin/env python3
"""Build an immutable, versioned archive under releases/X.Y.Z/.

The archive always contains the stable garrysmod/addons/wotw_mod/ install
folder so successive versions replace each other instead of loading twice.
Bump VERSION before publishing a new build; never overwrite old releases.
"""
import re
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parent.parent
version = (ROOT / 'VERSION').read_text().strip()
if not re.fullmatch(r'\d+\.\d+\.\d+', version):
    raise SystemExit('VERSION must use X.Y.Z, e.g. 1.0.0')
output = ROOT / 'releases' / version / f'wotw_mod_{version}.zip'
output.parent.mkdir(parents=True, exist_ok=True)
files = [ROOT / name for name in (
    'README.md', 'VERSION', 'addon.json', 'tripods_the_tripods_1984.glb',
    '1953_tripod.glb', 'martian_spider.glb',
)]
for directory in ('lua', 'materials', 'tools', 'generated/source_models'):
    files.extend(p for p in (ROOT / directory).rglob('*')
                 if p.is_file() and '__pycache__' not in p.parts and p.suffix != '.pyc')
if not (ROOT / 'generated/source_models/tripod_red.qc').exists():
    raise SystemExit('First run python3 tools/build_models.py')
if not (ROOT / 'lua/wotw_new_geometry.lua').exists():
    raise SystemExit('First run python3 tools/build_new_models.py')
with ZipFile(output, 'w', ZIP_DEFLATED, compresslevel=6) as archive:
    archive.writestr('ИНСТРУКЦИЯ_ПО_УСТАНОВКЕ.txt', f'''wotw mod {version} — четыре NPC с GLB-моделями и процедурной анимацией.

Распакуй папку wotw_mod из архива в garrysmod/addons/ и перезапусти GMod.
При обновлении замени прежнюю папку wotw_mod. НЕ устанавливай две версии сразу!
Удалите старый аддон wow_tripods, если он сохранился с прежних бета-версий.
Sandbox -> Entities -> wotw mod. Если NPC стоят: nav_generate в консоли.
Модели рисуются клиентом; бинарных .mdl в комплекте нет.
DrGBase необязательна: она добавляет отдельные версии двух треног.
Подробности: wotw_mod/README.md.
''')
    for p in sorted(files):
        archive.write(p, 'wotw_mod/' + str(p.relative_to(ROOT)))
print(f'{output.relative_to(ROOT)}: {output.stat().st_size:,} bytes, {len(files) + 1} files')

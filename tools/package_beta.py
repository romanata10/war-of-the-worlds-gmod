#!/usr/bin/env python3
"""Package the playable Lua beta and model source files in one addon folder."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

root = Path(__file__).resolve().parent.parent
output = root / 'wow_tripods_beta.zip'
files = [root / 'README.md', root / 'tripods_the_tripods_1984.glb']
for directory in ('lua', 'materials', 'tools', 'generated/source_models'):
    files.extend(p for p in (root / directory).rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.suffix != '.pyc')
if not (root / 'generated/source_models/tripod_red.qc').exists():
    raise SystemExit('First run python3 tools/build_models.py')
with ZipFile(output, 'w', ZIP_DEFLATED, compresslevel=6) as archive:
    archive.writestr('ИНСТРУКЦИЯ_ПО_УСТАНОВКЕ.txt', """БЕТА: две треноги с ИИ, исходной геометрией GLB и анимацией ног.

Распакуй папку wow_tripods из архива в garrysmod/addons/ и перезапусти GMod.
Sandbox -> Entities -> War of the Worlds · The Tripods.
Для маршрутов NPC: nav_generate в консоли администратора, если нет navmesh.
Модели показаны процедурным рендером, .mdl пока нет. Файлы сборки .mdl
включены в wow_tripods/generated/source_models/; их компиляция необязательна.
DrGBase необязательна: с ней появляются отдельные DrGBase-варианты треног.
Подробности и ограничения: wow_tripods/README.md.
""")
    for p in sorted(files):
        archive.write(p, 'wow_tripods/' + str(p.relative_to(root)))
print(f'{output.name}: {output.stat().st_size:,} bytes, {len(files) + 1} files')

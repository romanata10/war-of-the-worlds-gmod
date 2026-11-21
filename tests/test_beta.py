"""Fast offline packaging and geometry checks; game engine still needs in-game testing."""
import base64
import re
import struct
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VERSION = (ROOT / 'VERSION').read_text().strip()
ARCHIVE = ROOT / 'releases' / VERSION / f'wotw_mod_{VERSION}.zip'


class BetaChecks(unittest.TestCase):
    def test_original_glb_split_is_not_reversed(self):
        with zipfile.ZipFile(ARCHIVE) as archive:
            red = archive.read('wotw_mod/generated/source_models/tripod_red.qc').decode()
            white = archive.read('wotw_mod/generated/source_models/tripod_white.qc').decode()
        self.assertIn('"tripod_1.smd"', red)
        self.assertIn('"tripod_0.smd"', white)
        index = (ROOT / 'lua/wow_tripods_geometry.lua').read_text()
        self.assertIn('red = {', index)
        self.assertIn('white = {', index)
        self.assertIn('white_0_0.lua', index)
        self.assertIn('red_0_0.lua', index)

    def test_runtime_meshes_complete(self):
        index = (ROOT / 'lua/wow_tripods_geometry.lua').read_text()
        totals = {'red': 0, 'white': 0}
        references = re.findall(r'include\("wow_tripods_mesh/([^\"]+)"\)', index)
        self.assertEqual(set(references), {p.name for pattern in ('red_*.lua', 'white_*.lua') for p in (ROOT / 'lua/wow_tripods_mesh').glob(pattern)})
        for name in references:
            text = (ROOT / 'lua/wow_tripods_mesh' / name).read_text()
            match = re.fullmatch(r'return \{(\d+), (\d+), "([A-Za-z0-9+/=]+)"\}\n', text)
            self.assertIsNotNone(match, name)
            bone, count, payload = match.groups()
            self.assertLessEqual(int(bone), 3)
            self.assertEqual(len(base64.b64decode(payload)), int(count)*30)
            totals[name.split('_')[0]] += int(count)
        self.assertEqual(totals, {'red': 36925, 'white': 30726})
        material = (ROOT / 'materials/models/wow_tripods/runtime.vmt').read_text()
        self.assertNotIn('"$translucent"', material)
        self.assertNotIn('"$vertexalpha"', material)

    def test_downloadable_addon(self):
        with zipfile.ZipFile(ARCHIVE) as z:
            self.assertIsNone(z.testzip())
            names = set(z.namelist())
            self.assertIn('wotw_mod/addon.json', names)
            self.assertEqual(z.read('wotw_mod/VERSION').decode().strip(), VERSION)
            self.assertIn('wotw_mod/lua/entities/wow_tripod_1953/init.lua', names)
            self.assertIn('wotw_mod/lua/entities/wow_tripod_spider/init.lua', names)
            self.assertIn('wotw_mod/lua/wow_tripods_mesh/red_0_0.lua', names)
            self.assertIn('wotw_mod/lua/wotw_new_geometry.lua', names)
            self.assertIn('wotw_mod/lua/wow_tripods_mesh/1953_0_0.lua', names)
            self.assertIn('wotw_mod/lua/wow_tripods_mesh/spider_0_0.lua', names)
            self.assertIn('wotw_mod/1953_tripod.glb', names)
            self.assertIn('wotw_mod/martian_spider.glb', names)

    def test_new_npcs_icons_and_imperfect_aim(self):
        classes = ('pendragon', 'walker', 'bbc2019', 'asylum2')
        with zipfile.ZipFile(ARCHIVE) as archive:
            names = set(archive.namelist())
            for name in classes:
                class_name = 'wow_tripod_' + name
                for component in ('shared.lua', 'init.lua', 'cl_init.lua'):
                    self.assertIn(f'wotw_mod/lua/entities/{class_name}/{component}', names)
                icon = f'materials/entities/{class_name}.png'
                self.assertIn('wotw_mod/'+icon, names)
                data = archive.read('wotw_mod/'+icon)
                self.assertEqual(data[:8], b'\x89PNG\r\n\x1a\n')
                self.assertEqual(struct.unpack('>II', data[16:24]), (256, 256))
            self.assertEqual(archive.read('wotw_mod/VERSION').decode().strip(), '1.1.0')
        ray = (ROOT / 'lua/autorun/server/wow_tripods_attacks.lua').read_text()
        self.assertIn('function WOWTripods.HeatRay(', ray)
        self.assertIn('math.Rand(-spread, spread)', ray)
        self.assertIn('util.TraceLine({start = origin, endpos = origin + direction*', ray)
        self.assertIn('tr.Entity:TakeDamageInfo(damage)', ray)
        self.assertNotIn('target:TakeDamageInfo(damage)\n    return true', ray)

    def test_new_models(self):
        index = (ROOT / 'lua/wotw_new_geometry.lua').read_text()
        totals = {'1953': 0, 'spider': 0}
        used = set()
        for name in re.findall(r'include\("wow_tripods_mesh/([^\"]+)"\)', index):
            text = (ROOT / 'lua/wow_tripods_mesh' / name).read_text()
            m = re.fullmatch(r'return \{(\d+), (\d+), "([A-Za-z0-9+/=]+)"\}\n', text)
            self.assertIsNotNone(m, name)
            group, triangles, encoded = m.groups()
            self.assertLessEqual(int(group), 4 if name.startswith('spider_') else 3)
            self.assertEqual(len(base64.b64decode(encoded)), int(triangles)*30)
            kind = 'spider' if name.startswith('spider_') else '1953'
            totals[kind] += int(triangles)
            used.add(name)
        self.assertEqual(used, {p.name for p in (ROOT / 'lua/wow_tripods_mesh').glob('*.lua') if p.name.startswith(('1953_', 'spider_'))})
        self.assertEqual(totals, {'1953': 8582, 'spider': 69888})


if __name__ == '__main__':
    unittest.main()

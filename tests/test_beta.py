"""Fast offline packaging and geometry checks; game engine still needs in-game testing."""
import base64
import re
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class BetaChecks(unittest.TestCase):
    def test_original_glb_split_is_not_reversed(self):
        red = (ROOT / 'generated/source_models/tripod_red.qc').read_text()
        white = (ROOT / 'generated/source_models/tripod_white.qc').read_text()
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
        self.assertEqual(set(references), {p.name for p in (ROOT / 'lua/wow_tripods_mesh').glob('*.lua')})
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
        with zipfile.ZipFile(ROOT / 'wotw_mod_beta.zip') as z:
            self.assertIsNone(z.testzip())
            names = set(z.namelist())
            self.assertIn('wotw_mod/addon.json', names)
            self.assertIn('wotw_mod/lua/entities/wow_tripod_1953/init.lua', names)
            self.assertIn('wotw_mod/lua/entities/wow_tripod_spider/init.lua', names)
            self.assertIn('wotw_mod/lua/wow_tripods_mesh/red_0_0.lua', names)


if __name__ == '__main__':
    unittest.main()

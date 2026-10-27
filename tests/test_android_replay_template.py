"""Verify prepared templates preserve stock code/resources and Godot-compatible XML."""
from pathlib import Path
import struct
import sys
import unittest
import zipfile
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import build_android_replay_template as manifest

class AndroidReplayTemplateTests(unittest.TestCase):
    def test_manifest_pool_is_utf16_and_round_trips_unicode(self):
        values=['manifest','回放😀','org.multicolorarena.replay.ReplayOpenActivity','x'*33000]
        pool=manifest.string_pool(values)
        self.assertEqual(struct.unpack_from('<I',pool,16)[0]&256,0)
        self.assertEqual(manifest.read_strings(pool),values)

    def test_prepared_templates_preserve_stock_entries_and_indices(self):
        for mode in ('debug','release'):
            with self.subTest(mode=mode):
                stock=ROOT/'.godot-toolchain/editor/editor_data/export_templates/4.7.2.stable'/f'android_{mode}.apk'
                custom=ROOT/'.godot-toolchain/android_replay'/stock.name
                if not stock.exists() or not custom.exists():self.skipTest('Prepare local Android templates first')
                with zipfile.ZipFile(stock) as a,zipfile.ZipFile(custom) as b:
                    old=list(manifest.chunks(a.read('AndroidManifest.xml')))
                    new=list(manifest.chunks(b.read('AndroidManifest.xml')))
                    pool=next(data for typ,data in new if typ==1)
                    self.assertEqual(struct.unpack_from('<I',pool,16)[0]&256,0)
                    oldstrings=manifest.read_strings(next(d for t,d in old if t==1))
                    newstrings=manifest.read_strings(pool)
                    self.assertEqual(newstrings[:len(oldstrings)],oldstrings)
                    self.assertIn('org.multicolorarena.replay.ReplayOpenActivity',newstrings)
                    oldresources=next(d for t,d in old if t==0x180)[8:]
                    newresources=next(d for t,d in new if t==0x180)[8:]
                    self.assertEqual(newresources[:len(oldresources)],oldresources)
                    nodes=iter([d for t,d in new if t not in(1,0x180)])
                    for node in [d for t,d in old if t not in(1,0x180)]:
                        self.assertTrue(any(candidate==node for candidate in nodes))
                    olddex={p for p in a.namelist() if p.endswith('.dex')}
                    newdex={p for p in b.namelist() if p.endswith('.dex')}
                    self.assertEqual(len(newdex-olddex),1)
                    for name in a.namelist():
                        if name=='AndroidManifest.xml' or name.startswith('META-INF/'):continue
                        self.assertEqual(a.getinfo(name).CRC,b.getinfo(name).CRC,name)

if __name__=='__main__':unittest.main()

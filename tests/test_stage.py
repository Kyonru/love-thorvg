"""Package current build output rather than older staged test binaries."""
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('stage', ROOT / 'scripts/stage.py')
stage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stage)

class StageTests(unittest.TestCase):
    def test_selects_build_output_and_rejects_nested_copy(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            build = base / 'build'
            nested = build / 'love-font-test/love_thorvg/native'
            nested.mkdir(parents=True)
            _, _, library = stage.target()
            (nested / library).write_bytes(b'old staged binary')
            current = build / library
            current.write_bytes(b'current build')
            subprocess.run([sys.executable, str(ROOT / 'scripts/stage.py'), str(build), str(base / 'dist')], check=True)
            archive, = (base / 'dist').glob('*.zip')
            with zipfile.ZipFile(archive) as bundle:
                matches = [n for n in bundle.namelist() if n.endswith('/' + library)]
                self.assertEqual(len(matches), 1)
                self.assertEqual(bundle.read(matches[0]), b'current build')
            current.unlink()
            result = subprocess.run([sys.executable, str(ROOT / 'scripts/stage.py'), str(build), str(base / 'bad')], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((base / 'bad').exists())

if __name__ == '__main__':
    unittest.main()

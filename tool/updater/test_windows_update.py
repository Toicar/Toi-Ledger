"""Exercise the Windows updater against disposable files only."""
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import zipfile


@unittest.skipUnless(os.name == 'nt', 'Windows PowerShell is required')
class WindowsUpdaterTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='ledger-updater-test-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.install = self.root / 'app'
        (self.install / 'data').mkdir(parents=True)
        (self.install / 'my_ledger.exe').write_bytes(b'old executable')
        (self.install / 'data' / 'app.so').write_bytes(b'old application')
        self.archive = self.root / 'update.zip'
        self.script = Path(__file__).with_name('Install-Update.ps1').resolve()

    def run_update(self, files):
        with zipfile.ZipFile(self.archive, 'w') as archive:
            for name, content in files.items():
                archive.writestr(name, content)
        digest = hashlib.sha256(self.archive.read_bytes()).hexdigest()
        def quoted(value):
            return "'" + str(value).replace("'", "''") + "'"
        command = (
            'function Start-Process { param($FilePath,$WorkingDirectory) }; '
            f'& {quoted(self.script)} -Archive {quoted(self.archive)} '
            f'-ExpectedSha256 {quoted(digest)} -InstallDirectory {quoted(self.install)} '
            '-AppPid 2147483647 -NonInteractive'
        )
        return subprocess.run(['powershell.exe', '-NoProfile', '-NonInteractive', '-Command', command],
                              capture_output=True, text=True, timeout=30)

    def test_install_replaces_program_files(self):
        result = self.run_update({'my_ledger.exe': b'new executable', 'data/app.so': b'new application'})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.install / 'my_ledger.exe').read_bytes(), b'new executable')
        self.assertEqual((self.install / 'data' / 'app.so').read_bytes(), b'new application')

    def test_rejects_path_traversal_before_replacement(self):
        result = self.run_update({'my_ledger.exe': b'new executable', 'data/app.so': b'new application', '../escape.txt': b'bad'})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Unsafe update path', result.stderr)
        self.assertFalse((self.root / 'escape.txt').exists())
        self.assertEqual((self.install / 'my_ledger.exe').read_bytes(), b'old executable')
        self.assertEqual((self.install / 'data' / 'app.so').read_bytes(), b'old application')

    def test_rolls_back_when_destination_conflicts(self):
        (self.install / 'native_assets.json').mkdir()
        result = self.run_update({'my_ledger.exe': b'new executable', 'data/app.so': b'new application', 'native_assets.json': b'conflict'})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('conflicts with an existing directory', result.stderr)
        self.assertIn('Files attempted: 2', result.stderr)
        self.assertEqual((self.install / 'my_ledger.exe').read_bytes(), b'old executable')
        self.assertEqual((self.install / 'data' / 'app.so').read_bytes(), b'old application')


if __name__ == '__main__':
    unittest.main()

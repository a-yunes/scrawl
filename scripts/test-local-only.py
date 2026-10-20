#!/usr/bin/env python3
"""Check the exclusion guard against isolated restoration and policy-drift fixtures."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parent.parent

class LocalOnlyGuardTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='scrawl-policy-test-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        for name in ['AGENTS.md', 'EXCLUSIONS.md', 'scripts/check-local-only.py',
                     'scripts/package-app.sh', 'scripts/Scrawl.entitlements',
                     'helper/Info.plist', 'helper/Settings.swift']:
            destination = self.root / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(REPO / name, destination)
        (self.root / 'src').mkdir()

    def run_guard(self):
        return subprocess.run([sys.executable, str(self.root / 'scripts/check-local-only.py')],
                              capture_output=True, text=True, timeout=10)

    def test_local_fixture_and_inert_legacy_metadata_are_allowed(self):
        (self.root / 'src/model.rs').write_text('struct Destination { session: String }\n')
        result = self.run_guard()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_excluded_products_cannot_return_in_a_merge(self):
        for restored, reported in [
            ('site/public/appcast.xml', 'site/'),
            ('video/src/main.rs', 'video/'),
            ('src/win/new_capture.rs', 'src/win/'),
            ('src/routing/new_sender.rs', 'src/routing/'),
            ('src/delivery.rs', 'src/delivery.rs'),
            ('src/page.rs', 'src/page.rs'),
            ('src/settings_window.rs', 'src/settings_window.rs'),
            ('Sources/ScrawlKit/Recorder.swift', 'Sources/ScrawlKit/'),
            ('Package.swift', 'Package.swift'),
            ('scripts/install-app-remote.sh', 'scripts/install-app-remote.sh'),
        ]:
            with self.subTest(restored=restored):
                path = self.root / restored
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('// restored upstream file\n')
                result = self.run_guard()
                self.assertEqual(result.returncode, 1)
                self.assertIn(reported + ': removed integration restored', result.stderr)
                path.unlink()
                parent = path.parent
                while parent != self.root and not any(parent.iterdir()):
                    parent.rmdir()
                    parent = parent.parent

    def test_newly_named_socket_implementation_is_rejected(self):
        (self.root / 'src/new_feature.rs').write_text('use std::net::TcpListener;\n')
        result = self.run_guard()
        self.assertEqual(result.returncode, 1)
        self.assertIn('new_feature.rs:1: forbidden network integration', result.stderr)

    def test_agent_instructions_must_link_the_policy(self):
        (self.root / 'AGENTS.md').write_text('# Instructions without the fork policy\n')
        result = self.run_guard()
        self.assertEqual(result.returncode, 1)
        self.assertIn('AGENTS.md must reference', result.stderr)

if __name__ == '__main__':
    unittest.main()

#!/usr/bin/env python3
"""Regression guard for the fork's deliberately removed network integrations."""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parent.parent
forbidden = re.compile(r'\b(?:TcpListener|TcpStream|UdpSocket|URLSession|NWConnection)\b|\b(?:sparkle|routing|hex)::|Command::new\("(?:ssh|curl|wget)"\)')
failures = []
policy = root / 'EXCLUSIONS.md'
if not policy.is_file() or '[EXCLUSIONS.md](EXCLUSIONS.md)' not in (root / 'AGENTS.md').read_text():
    failures.append('AGENTS.md must reference the canonical EXCLUSIONS.md policy')
for directory, suffix in [('src', '.rs'), ('helper', '.swift')]:
    for path in (root / directory).rglob('*' + suffix):
        for number, line in enumerate(path.read_text().splitlines(), 1):
            if line.lstrip().startswith(('//', '*')):
                continue
            if forbidden.search(line):
                failures.append(f'{path.relative_to(root)}:{number}: forbidden network integration')
for name in [
    'src/web.rs', 'src/sdk.js', 'src/page.rs', 'src/routing.rs', 'src/routing/',
    'src/delivery.rs', 'src/hex.rs', 'src/sparkle.rs', 'src/phone.rs',
    'helper/Mirror.swift', 'site/', 'video/', 'Sources/ScrawlKit/',
    'Tests/ScrawlKitTests/', 'Package.swift', 'src/win/', 'src/ui/windows.rs',
    'src/capture/windows.rs', 'src/settings_window.rs', 'src/onboarding_window.rs',
    'scripts/scrawl-serve.plist', 'scripts/install-app-remote.sh',
    'scripts/setup-sparkle.sh', '.github/workflows/release-windows.yml',
]:
    if (root / name).exists():
        failures.append(f'{name}: removed integration restored')
for name in ['scripts/package-app.sh', 'scripts/Scrawl.entitlements', 'helper/Info.plist']:
    text = (root / name).read_text()
    for forbidden_key in ['SUFeedURL', 'SUPublicEDKey', 'NSCameraUsageDescription', 'NSAppleEventsUsageDescription', 'com.apple.security.device.camera', 'com.apple.security.automation.apple-events']:
        if forbidden_key in text:
            failures.append(f'{name}: unexpected permission or updater setting {forbidden_key}')
settings = (root / 'helper/Settings.swift').read_text()
permission_defaults = re.search(r'var permissions: \[SettingsPermission\] = \[([^\]]+)\]', settings)
if not permission_defaults or '"camera"' in permission_defaults[1]:
    failures.append('helper/Settings.swift: unexpected default permission rows')
if failures:
    print('\n'.join(failures), file=sys.stderr)
    sys.exit(1)
print('PASS: local-only source and packaging boundaries')

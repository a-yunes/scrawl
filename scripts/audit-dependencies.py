#!/usr/bin/env python3
"""Query OSV for the public registry versions in Cargo.lock. No source or user data is sent."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import re
import urllib.request

parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, default=Path('target/dependency-audit.json'))
args = parser.parse_args()
root = Path(__file__).resolve().parent.parent
packages = []
local = []
for block in (root / 'Cargo.lock').read_text().split('[[package]]')[1:]:
    name = re.search(r'^name = "([^"]+)"', block, re.M).group(1)
    version = re.search(r'^version = "([^"]+)"', block, re.M).group(1)
    if 'source = "registry+' in block:
        packages.append({'package': {'name': name, 'ecosystem': 'crates.io'}, 'version': version})
    else:
        local.append({'name': name, 'version': version})

results = []
for start in range(0, len(packages), 100):
    batch = packages[start:start + 100]
    request = urllib.request.Request('https://api.osv.dev/v1/querybatch',
        data=json.dumps({'queries': batch}).encode(), headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(request, timeout=45) as response:
        answer = json.load(response)['results']
    if len(answer) != len(batch) or any(item.get('next_page_token') for item in answer):
        raise RuntimeError('OSV returned incomplete results; no clean result can be claimed')
    results.extend({'query': package, 'result': result} for package, result in zip(batch, answer))
ids = sorted({item['id'] for result in results for item in result['result'].get('vulns', [])})
def get(advisory):
    with urllib.request.urlopen('https://api.osv.dev/v1/vulns/' + advisory, timeout=45) as response:
        return json.load(response)
with ThreadPoolExecutor(max_workers=4) as pool:
    advisories = list(pool.map(get, ids))
security = [entry for entry in advisories if not all(
    affected.get('database_specific', {}).get('informational') for affected in entry['affected'])]
report = {
    'method': 'OSV version matching, not reachability or malware analysis',
    'registry_package_versions': len(packages),
    'local_packages_not_registry_scanned': local,
    'local_grid_backport': 'vendor/grid/BACKPORT.md; version-only scanning is not validation of this patch',
    'security_advisory_ids': [entry['id'] for entry in security],
    'matches': [result for result in results if result['result'].get('vulns')],
    'advisories': advisories,
}
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(report, indent=2) + '\n')
print(f"Registry versions: {len(packages)}; security advisories: {len(security)}; informational notices: {len(advisories)-len(security)}")
print(f"Local packages: {local}. Grid backport requires its release-mode regression check.")
raise SystemExit(bool(security))

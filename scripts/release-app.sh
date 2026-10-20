#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/scripts/package-app.sh"
shasum -a 256 "$ROOT/dist/Scrawl-Local.zip"

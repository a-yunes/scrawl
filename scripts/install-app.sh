#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/scripts/package-app.sh"
DEST="${SCRAWL_APP_DIR:-$HOME/Applications/Scrawl Local.app}"
if [[ -e "$DEST" ]]; then
  echo "Refusing to overwrite $DEST. Move the existing app aside before installing." >&2
  exit 1
fi
mkdir -p "$(dirname "$DEST")"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/scrawl-local-install.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
/usr/bin/ditto -x -k "$ROOT/dist/Scrawl-Local.zip" "$STAGING"
/usr/bin/ditto "$STAGING/Scrawl Local.app" "$DEST"
codesign --verify --deep --strict "$DEST"
printf 'Installed %s. Open it manually when ready.\n' "$DEST"

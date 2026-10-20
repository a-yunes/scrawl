#!/usr/bin/env bash
set -euo pipefail
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
PROFILE="${SCRAWL_BUILD_PROFILE:-release}"
case "$PROFILE" in
  release) taskpolicy -c utility cargo build --release --locked --offline -j 3 ;;
  debug) taskpolicy -c utility cargo build --locked --offline -j 3 ;;
  *) echo 'SCRAWL_BUILD_PROFILE must be release or debug' >&2; exit 1 ;;
esac

STAGING="$(mktemp -d "${TMPDIR:-/tmp}/scrawl-local-package.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/Scrawl Local.app"
mkdir -p "$ROOT/dist"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "target/$PROFILE/scrawl" "target/$PROFILE/scrawl-helper" "$APP/Contents/MacOS/"
cp assets/Scrawl.icns "$APP/Contents/Resources/Scrawl.icns"
VERSION="$(sed -n 's/^version = "\(.*\)"/\1/p' Cargo.toml | head -1)"
APP_VERSION="${VERSION%%-*}"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>scrawl</string>
<key>CFBundleIconFile</key><string>Scrawl</string>
<key>CFBundleIdentifier</key><string>dev.ayunes.scrawl.local</string>
<key>CFBundleName</key><string>Scrawl Local</string>
<key>CFBundleDisplayName</key><string>Scrawl Local</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>${APP_VERSION}</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSScreenCaptureUsageDescription</key><string>Capture the screen you choose into local recording files.</string>
<key>NSMicrophoneUsageDescription</key><string>Record your narration for on-device transcription.</string>
<key>NSSpeechRecognitionUsageDescription</key><string>Transcribe your narration on this Mac.</string>
</dict></plist>
PLIST

IDENTITY="${SCRAWL_SIGN_ID:--}"
SIGN=(codesign --force --options runtime --sign "$IDENTITY")
if [[ "$IDENTITY" != "-" ]]; then SIGN+=(--timestamp); fi
"${SIGN[@]}" --identifier dev.ayunes.scrawl.local.helper --entitlements scripts/Scrawl.entitlements "$APP/Contents/MacOS/scrawl-helper"
"${SIGN[@]}" --identifier dev.ayunes.scrawl.local --entitlements scripts/Scrawl.entitlements "$APP"
codesign --verify --deep --strict "$APP"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP" "$ROOT/dist/Scrawl-Local.zip"
printf '%s\n' "$ROOT/dist/Scrawl-Local.zip"

# Local-only hardening

Base: upstream commit `5a55a8649a2f053bac5a44145d81e1e079ea3228`.

## Removed capabilities

The desktop app and CLI no longer contain the ScrawlKit HTTP ingest server,
loopback browser registration/context SDK, browser AppleScript URL lookup,
OpenCode discovery/delivery/retries, SSH bundle synchronization, phone pairing,
USB recording, Hex HTTP transcription, or Sparkle updater. The optional autocrop
HTTP playground server is also removed; static local export remains.

The website and its npm dependency tree, promotional video generator, iOS SDK,
and Windows build/distribution code are removed from this macOS fork. They are
not needed for its capture and manual-paste workflow.

Local legacy bundle decoding remains for review, extraction and reprocessing.
Fields naming an old destination are inert metadata; no delivery implementation
remains. Historical upstream docs may describe the original implementation.
README.md and this document define the fork's supported behavior.

## Data and permissions

The app has a separate bundle identity and default capture/configuration paths.
It sets umask 077 before starting workers. Its helper inherits the mask.
Diagnostics require SCRAWL_DIAGNOSTICS=1 and remove complete URL tokens, including
query strings, fragments, user information and custom schemes. Diagnostics can
still contain non-URL sensitive text and should only be enabled temporarily.

The phone SDK's repeated full-URL logging disappears with SDK removal. Camera and
Apple Events declarations/entitlements are removed from the package. Screen and
microphone content is intentionally recorded without semantic secret redaction.
No secure-erasure claim is made: normal retention still uses Trash.

Upstream update feeds, public keys and Sparkle binaries are absent. The packaging
scripts cannot silently replace the fork with an upstream app. New local builds
must be installed explicitly. Ad-hoc signing is the default; no upstream signing
identity, notarization key, upload command or developer-specific cache is used.

## Dependencies

- rustls is updated from 0.23.45 to 0.23.46, fixing the four matched RustSec
  advisories RUSTSEC-2026-0346 through RUSTSEC-2026-0349.
- Website-only Vitest and Tinypool advisories no longer apply to this checkout
  because the website and its dependency manifests are removed.
- GPUI 0.2.2 pins Taffy 0.9.0, which requires grid 0.18.0. The local grid patch
  checks dimension and allocation arithmetic before changing state. See
  [the backport record](vendor/grid/BACKPORT.md). Release-mode regression tests
  cover both row/column expansion and both storage orders.
- Maintenance notices in GPUI's transitive dependency tree are not proof of an
  exploitable vulnerability and are not suppressed or described as fixed.
- A version advisory scan is not a complete audit of dependency source, build
  scripts, or native libraries. The app's removal of direct network integrations
  does not mean that macOS services or every linked library has been audited.

## Verification

The source boundary check rejects the removed integration files, direct socket
and URLSession APIs, SSH/curl subprocesses, updater settings and unused camera /
Apple Events permissions. It is a regression guard, not a malware detector.
CLI tests verify that removed commands and flags are rejected. Privacy tests
verify URL removal. Existing capture, rendering, export, settings and local
bundle tests remain applicable. Build/test outcomes are reported with the fork
handoff; do not infer a live recording or production signing check from unit tests.

### Verified on 2026-10-20

On Apple silicon macOS 27 with Rust 1.99.1 and Xcode's Metal toolchain:

- Application suite: 257 passed, 0 failed, 1 existing performance benchmark ignored.
- Grid release-mode suite: 210 passed. The added overflow regression fails on
  unpatched registry grid 0.18.0 and passes on the checked-arithmetic backport.
- Packaged CLI: generated bundle and manifest, rejected removed commands,
  owner-only file modes, synthetic video export and frame decoding passed.
  The exported fixture was 640 x 360, 30 fps, 9.8 seconds, without audio.
- Ad-hoc signatures passed strict verification after extracting the zip and
  again after running the fixture checks.
- Settings render inspection confirmed no automatic delivery, Hex, Camera or
  updater controls, including the helper's initial state.
- OSV: 675 registry package versions, zero security-advisory matches and ten
  informational maintenance notices. The local grid backport is accounted for
  separately and is not a registry-scanned fixed release.

No real desktop/microphone recording, real clipboard paste, live transcription,
macOS 26 device acceptance or Apple notarization was performed. The supplied
package uses the optimized debug profile. Compiler/dependency warnings remain,
including upstream deprecated Swift APIs and Rust future-compatibility notices.

To repeat the synthetic export check with a fresh video path:

```sh
xcrun swiftc -swift-version 5 scripts/make-smoke-movie.swift -o target/make-smoke-movie
target/make-smoke-movie target/smoke-movie.mp4
python3 scripts/smoke-local.py --binary target/debug/scrawl --movie target/smoke-movie.mp4
```

### GitHub CI permissions

The available GitHub OAuth credential does not have `workflow` scope. The verified
macOS CI definition is supplied as the inactive `ci/check.yml` template. This fork
has no active Actions workflow. The local build, test and packaged-artifact checks
above were executed directly. To enable CI later, authorize workflow editing and
place the template at `.github/workflows/check.yml`.

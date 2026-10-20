# Scrawl Local: exclusions and deviations from upstream

This is the policy for syncing with official
[kitlangton/scrawl](https://github.com/kitlangton/scrawl). Read it with
[AGENTS.md](AGENTS.md) before merging or cherry-picking. These boundaries apply
to behavior, including renamed or newly implemented versions of removed
features. Changing them requires an explicit user request.

## Supported workflow

Keep local macOS screen/window/area recording, annotation, on-device Apple Speech,
review, local frame extraction/export, and explicit manual clipboard copy/paste.
Pasting must not press Send or submit an agent prompt automatically. Preserve
useful upstream fixes to these features.

## Excluded capabilities

| Capability | Fork policy and representative removed paths |
| --- | --- |
| Automatic agent delivery | No OpenCode discovery, routing, queued sends, retries, or equivalent integrations with other agents. Keep `src/routing.rs`, `src/routing/`, and `src/delivery.rs` removed. |
| Remote synchronization | No SSH delivery, remote commands, remote installation helpers, or credential discovery for those features. Keep `scripts/install-app-remote.sh` removed. |
| HTTP services | No phone ingest, background listener, pairing endpoint or development HTTP playground. Keep `src/web.rs`, `src/phone.rs`, and `scripts/scrawl-serve.plist` removed. Static local playground export is allowed. |
| Browser integration | No browser URL lookup through AppleScript, registration heartbeat, browser SDK or page-context collection. Keep `src/sdk.js` and `src/page.rs` removed. |
| Phone/iOS capture | No device discovery, USB capture/mirror, phone uploads or ScrawlKit SDK. Keep `helper/Mirror.swift`, `Sources/ScrawlKit/`, `Tests/ScrawlKitTests/`, and `Package.swift` removed. |
| Hex transcription | No Hex discovery, polling, HTTP client, model settings, or associated CLI/UI controls. Keep `src/hex.rs` removed. |
| Upstream updater | No Sparkle framework, update checks, feed, signing key or updater UI. Keep `src/sparkle.rs`, `scripts/setup-sparkle.sh`, and `site/public/appcast.xml` removed. Install new fork builds explicitly. |
| Unneeded platform/site products | macOS only. Keep `site/`, `video/`, `src/win/`, `src/ui/windows.rs`, `src/capture/windows.rs`, the Windows settings/onboarding windows, and the Windows release workflow removed. |
| Additional permissions/telemetry | Do not restore Camera, Apple Events, Input Monitoring requests, usage analytics or automatic diagnostic uploads. Required permissions remain Screen Recording, Microphone and Accessibility. |

The removed `serve`, `send`, `route`, `link`, `hex`, `devices`, phone recording
flags and HTTP playground flags must remain rejected by the CLI. Do not restore
them as disabled-by-default controls or dormant configuration switches.

## Intentional deviations to preserve

| Area | Required fork behavior |
| --- | --- |
| Identity | `Scrawl Local`, bundle ID `dev.ayunes.scrawl.local`, helper ID `dev.ayunes.scrawl.local.helper`. Never adopt upstream's identity during a version bump. |
| Data separation | Captures: `~/Library/Application Support/scrawl-local/captures/`. Config: `~/.config/scrawl-local/`. Optional logs: `~/Library/Logs/Scrawl Local/`. No automatic migration of upstream config or delivery queues. |
| File privacy | Preserve umask 077 in app/helper, owner-only capture files/directories, and `privacy::copy_private` protections for copied media. |
| Welcome motion | Keep the glow static and animate only the cached icon with a Core Animation transform. Preserve reduced-motion, occlusion, hiding and teardown behavior. Do not restore a per-frame SwiftUI clock for this decorative movement. |
| Diagnostics | Off by default. `SCRAWL_DIAGNOSTICS=1` is opt-in; redact complete URL tokens before output. No unconditional logging of captured metadata. |
| Dependencies | Preserve fixed Rustls and the checked-arithmetic Grid backport. Do not downgrade security fixes to match an upstream lockfile. Remove the backport only when a compatible fixed upstream dependency replaces it and its regression passes. |
| Packaging | Sign/archive in temporary storage outside synced Documents. Produce a local zip without installing, launching or publishing. Never use upstream signing/notarization credentials. Ad-hoc signing is the default; the owner may explicitly configure their own signing identity. |
| Version | Track the upstream release with the `-local.1` suffix, incrementing local revisions as needed. Keep package and lockfile versions consistent. |

## Deliberate exceptions and limits

- Existing local bundles, including legacy device bundles and inert destination
  metadata, remain readable for review/reprocessing. This is not a reason to
  restore delivery, device capture or network code.
- macOS may download Apple Speech assets. Explicit source-link clicks and manual
  paste are user-directed actions. This is not a claim that every linked library
  or OS service is network-free.
- Pixels and narration are not automatically scrubbed for secrets. Retention is
  configurable and uses Trash, not secure erasure.
- `ci/check.yml` is inactive because the publishing credential lacks workflow
  scope. This is an operational limitation, not a ban on CI. Activate the hardened
  template only with appropriate authorization; do not restore upstream release
  or deployment workflows as a workaround.
- Keep maintenance notices and validation limits visible. A source guard or
  advisory scan is not a complete malware audit.

## Upstream sync procedure

1. Fetch both remotes, check local changes, and inspect all commits since the last
   upstream baseline. Review new files and dependencies as well as modifications.
2. Merge compatible changes and record the upstream parent in history. Resolve
   modify/delete conflicts in excluded paths by keeping them deleted. Review
   conflicts individually instead of replacing fork files wholesale with upstream.
3. Keep exclusions out of manifests, build scripts, packaging, UI defaults,
   settings handlers and CLI parsing, not only out of startup code. Historical
   upstream docs do not override this policy.
4. Run `python3 scripts/check-local-only.py`, the build/application tests in
   AGENTS.md, `scripts/test-grid-backport.sh`, and the built CLI smoke check.
   Review the diff against this list. Refresh dependency audits if the dependency
   graph changes. Use generated fixtures rather than personal captures.
5. Update the sync record and report accepted changes, deliberate exclusions,
   verification and remaining limits. Preserve earlier verification as history.

## Sync record

| Date | Upstream baseline | Result |
| --- | --- | --- |
| 2026-10-20 | `5a55a8649a2f053bac5a44145d81e1e079ea3228` | Initial local-only fork, `0.3.7-local.1`; hardening commit `5d7c003`. |
| 2026-10-20 | `c69dffc645fe75e2220e637916ec172805397dab` (release 0.3.8) | Merge release history and bump to `0.3.8-local.1`. Keep appcast deleted. No upstream application implementation or dependency-version changes in this interval. |
| 2026-10-20 | `b93e1db6bbe373d8ea02c4bf44678100bbc30db5` | Follow-up merge of the recording pill Esc-hint removal that landed during validation; version `0.3.8-local.2`. Fork exclusions unchanged. |

See [HARDENING.md](HARDENING.md) for the audit, backport rationale and historical
verification. The source guard is a regression aid. This policy is authoritative
when an upstream change uses a different name or architecture.

### Validation of the 0.3.8 sync

- 257 application tests passed; one existing performance benchmark ignored.
- 210 Grid release-mode tests and four exclusion-guard tests passed.
- The rebuilt `0.3.8-local.1` package passed generated-bundle/file-permission
  checks, removed-command rejection, synthetic video export/frame decoding, and
  strict signature verification before and after the smoke check.
- Application implementation and registry dependency versions are unchanged from
  the hardened fork, so this sync did not repeat the earlier advisory lookup.
- No installation, live desktop/microphone recording or clipboard paste was done.
  The local build remains ad-hoc signed, not Apple-notarized; CI remains inactive.

### Validation of the b93e1db follow-up

- All 257 application tests passed again, with the same benchmark ignored.
- The changed Metal shader compiled; its uniform field order matches Rust and
  no Esc-hint fields remain. Live pill hover behavior was not exercised.
- Exclusion checks remained green. Dependency versions and the Grid patch did
  not change, so the preceding Grid and policy-regression results still apply.
- The `0.3.8-local.2` package passed generated-bundle/file-permission checks,
  removed-command rejection, synthetic video export/frame decoding and strict
  signature verification. No real recording, clipboard paste or installation.

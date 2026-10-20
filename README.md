# Scrawl Local

A macOS-only fork of [kitlangton/scrawl](https://github.com/kitlangton/scrawl) for
local screen recording, annotation, on-device transcription and manual paste.

Press Option-Shift-S to record, speak and draw with Shift, then press the shortcut
again to finish. Review the capture and use Option-Shift-V to paste it into the
application you choose. Scrawl Local does not send prompts to agents.

## Privacy boundaries

- No phone capture or upload server, browser SDK, browser URL lookup, automatic
  agent routing, SSH synchronization, Hex integration, or automatic updater.
- Only Screen Recording, Microphone and Accessibility are required. Camera and
  Apple Events permissions are not requested by the packaged app.
- Apple Speech runs on-device. macOS may download its speech model when missing.
- New files are owner-only (0600), and new directories are owner-only (0700).
- Diagnostic logging is off. To diagnose a problem, explicitly launch with
  `SCRAWL_DIAGNOSTICS=1`. Diagnostic URLs are removed before logging. Other
  diagnostic text can still include window titles or local paths.
- Captures contain the screen pixels and narration you recorded. This is not
  automatic secret detection. Review before pasting into a chat or sharing files.
- Clipboard contents can be read by other applications. Your chosen recipient's
  privacy policy applies after you paste.

The bundle ID is `dev.ayunes.scrawl.local`, distinct from upstream. Storage is:

- `~/Library/Application Support/scrawl-local/captures/`
- `~/.config/scrawl-local/config.json`
- `~/Library/Logs/Scrawl Local/` (only with diagnostics enabled)

The fork does not import upstream configuration or delivery queues. Retention is
configurable in Settings > Storage. By default, heavy media goes to Trash after
7 days and whole bundles after 30 days. Trash, backups and copies may retain data;
this is not secure erasure. Pinned or actively used captures are kept.

## Build and package

Requires an Apple silicon Mac, macOS 26+, full Xcode with the Metal compiler,
and Rust 1.99.1 through rustup (pinned in rust-toolchain.toml). Put
`~/.cargo/bin` ahead of Homebrew in PATH so Cargo and rustc use the same toolchain. Initial dependency fetches require internet access.

```sh
xcodebuild -downloadComponent MetalToolchain
cargo fetch --locked
python3 scripts/check-local-only.py
taskpolicy -c utility cargo build --locked --offline -j 3
taskpolicy -c utility cargo test --locked --offline -j 3 -- --test-threads=2
./scripts/test-grid-backport.sh
./scripts/package-app.sh
```

Packaging signs in a temporary folder and creates `dist/Scrawl-Local.zip` without
installing or launching it. Staging outside synced folders avoids file-provider
metadata invalidating the signature.
For a debug package, use `SCRAWL_BUILD_PROFILE=debug ./scripts/package-app.sh`.
`./scripts/install-app.sh` installs a new copy under `~/Applications` and refuses
to overwrite an existing app. `./scripts/release-app.sh` produces a local zip;
it never publishes or checks an upstream update feed.

Signing defaults to ad-hoc signing. Set `SCRAWL_SIGN_ID` to your own Developer ID
identity if needed. An ad-hoc package is not Apple-notarized and is not intended
as a generally distributable trusted download.

## Local CLI

```sh
scrawl app
scrawl record --duration 5
scrawl preview latest
scrawl inspect latest
scrawl copy latest
scrawl zoom latest --at 0:12
scrawl frames latest --from 0:02 --to 0:06
scrawl export latest --out capture.mp4
scrawl clean --dry-run
scrawl pin latest
scrawl skill
```

`copy` writes the summary to the clipboard. The GUI paste action inserts the
contact sheet and summary into the selected application without pressing Send.
The removed `send`, `serve`, `link`, `route`, `hex`, `devices`, and phone recording
commands are rejected, including when an old configuration is supplied.

Existing local capture bundles remain readable, including legacy device bundles.
See [HARDENING.md](HARDENING.md) for the source changes, dependency backport and
verification limits. The upstream MIT license and third-party licenses remain.

The optional GitHub Actions definition is supplied as `ci/check.yml`. It is an
inactive template because the publishing credential lacks workflow-editing scope.
Local validation commands above remain available without GitHub Actions.

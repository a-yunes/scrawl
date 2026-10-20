# Scrawl Local

This is a macOS-only local capture fork. Read README.md and HARDENING.md before
changing its scope. Do not restore phone, browser SDK, HTTP server, automatic
agent delivery, SSH synchronization, Hex or upstream updater behavior.

- Keep screen capture, on-device Apple Speech, annotation, local review/export
  and explicit manual paste functional.
- No automatic sends and no background listeners. New network capabilities
  require a user-requested scope change.
- Keep captures/configuration separate from upstream Scrawl. Do not inspect a
  user's real captures or reset their privacy permissions to test this code.
- Test against generated fixtures. Do not record the real desktop or microphone
  without an explicit request to do so.
- Never auto-install, auto-launch, publish releases, or use upstream signing keys.
  Packaging a local build is separate from installing it.
- Build/test with current stable Rust and full Xcode/Metal:
  `taskpolicy -c utility cargo build --locked --offline -j 3`
  `taskpolicy -c utility cargo test --locked --offline -j 3 -- --test-threads=2`
- Run `python3 scripts/check-local-only.py` and the grid release-mode overflow
  regression after changes to the privacy boundary or dependencies.
- Preserve the grid backport record until the pinned layout dependency can be
  upgraded to an upstream fixed version. Do not hide maintenance advisories.
- Do not use em dashes in newly authored documentation or user-facing text.

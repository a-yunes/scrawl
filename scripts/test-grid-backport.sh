#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/target"
# Compile the actual patched library with release optimizations and overflow checks off.
# These default-feature unit tests need no registry dependencies or benchmark tooling.
rustc --edition=2018 --test -O --cfg 'feature="std"' "$ROOT/vendor/grid/src/lib.rs" -o "$ROOT/target/grid-backport-tests"
"$ROOT/target/grid-backport-tests"

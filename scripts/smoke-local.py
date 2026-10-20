#!/usr/bin/env python3
"""Exercise a built CLI with generated data, without recording or touching the clipboard."""
import argparse
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument("--binary", type=Path, required=True)
parser.add_argument("--movie", type=Path, help="Optional synthetic video for export verification")
args = parser.parse_args()
binary = args.binary.resolve()
os.umask(0o077)

with tempfile.TemporaryDirectory(prefix="scrawl-local-smoke-") as temporary:
    root = Path(temporary)
    env = {key: value for key, value in os.environ.items() if not key.startswith("SCRAWL_")}
    env["SCRAWL_CONFIG"] = str(root / "config.json")
    env["SCRAWL_CAPTURES_DIR"] = str(root / "captures")

    def run(*arguments, success=True):
        result = subprocess.run([str(binary), *map(str, arguments)], env=env,
                                capture_output=True, text=True, timeout=120)
        if success:
            assert result.returncode == 0, result.stderr
        else:
            assert result.returncode == 2, (arguments, result.returncode, result.stderr)
        return result.stdout

    print(run("--version").strip())
    help_text = run("--help")
    assert "kitlangton/scrawl" not in help_text
    for arguments in [
        ("serve",), ("send", "latest"), ("route", "--url", "http://localhost:3000"),
        ("link", "--scheme", "test"), ("hex", "status"), ("devices",),
        ("app", "--iphone"), ("copy", "latest", "--session", "ses_test"),
    ]:
        run(*arguments, success=False)
    bundle = root / "fixture.scrawl"
    summary = run("demo", "--out", bundle)
    manifest = json.loads((bundle / "scrawl.json").read_text())
    assert manifest["keyframes"] and "[scrawl " in summary
    assert "[scrawl " in run("inspect", bundle)
    for path in [bundle, *bundle.rglob("*")]:
        assert stat.S_IMODE(path.stat().st_mode) == (0o700 if path.is_dir() else 0o600), path
    assert (bundle / "contact-sheet.png").read_bytes().startswith(b"\x89PNG\r\n\x1a\n")
    assert not (root / "config.json").exists(), "read-only CLI created configuration"

    if args.movie:
        shutil.copyfile(args.movie, bundle / "recording.mp4")
        manifest["video"] = "recording.mp4"
        (bundle / "scrawl.json").write_text(json.dumps(manifest))
        export = root / "export.mp4"
        run("export", bundle, "--out", export, "--size", "640", "--fps", "30")
        assert export.stat().st_size > 1000
        assert stat.S_IMODE(export.stat().st_mode) == 0o600
        helper = binary.with_name("scrawl-helper")
        probe = subprocess.run([str(helper), "probe", str(export)], env=env,
                               capture_output=True, text=True, timeout=30, check=True)
        metadata = json.loads(probe.stdout)
        print("Export metadata:", json.dumps(metadata))
        run("frames", bundle, "--from", "0:01", "--to", "0:02", "--fps", "2")
        assert list((bundle / "zoom").rglob("*.png"))
        print("PASS: synthetic video export and frame decoding")

    print("PASS: packaged CLI, removed commands, generated bundle, manifest and private file modes")

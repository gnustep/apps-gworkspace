"""Check automatic request deduplication and caching in an isolated directory."""
import os
from pathlib import Path
import shlex
import subprocess
import tempfile

source = Path(__file__).resolve().parent.parent

def flags(option):
    return shlex.split(subprocess.check_output(["gnustep-config", option], text=True))

with tempfile.TemporaryDirectory(prefix="automatic-thumbnails-") as temporary:
    root = Path(temporary)
    compiler = os.environ.get("CC") or subprocess.check_output(
        ["gnustep-config", "--variable=CC"], text=True).strip()
    subprocess.run(shlex.split(compiler) + flags("--objc-flags") + [
        "-I" + str(source), str(source / "Tests/Automatic.m"),
        str(source / "GWThumbnailer.m"), "-o", str(root / "test")]
        + flags("--gui-libs"), cwd=root, check=True)
    subprocess.run([str(root / "test"), str(root)], check=True, timeout=30)

"""Exercise real artwork extraction plus optional-helper failure handling."""
import os
from pathlib import Path
import shlex
import subprocess
import tempfile

source = Path(__file__).resolve().parent.parent


def run(args, **kwargs):
    subprocess.run([str(arg) for arg in args], check=True, **kwargs)


def flags(option):
    return shlex.split(subprocess.check_output(
        ["gnustep-config", option], text=True))


with tempfile.TemporaryDirectory(prefix="movie-thumbnailer-test-") as temporary:
    root = Path(temporary)
    runner = root / "test"
    compiler = os.environ.get("CC") or subprocess.check_output(
        ["gnustep-config", "--variable=CC"], text=True).strip()
    run(shlex.split(compiler) + flags("--objc-flags") + [
        "-I" + str(source), "-I" + str(source.parent),
        source / "Tests/Test.m", source / "MovieThumbnailer.m",
        "-o", runner] + flags("--gui-libs"), cwd=root)
    ffmpeg = ["ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error", "-y"]
    run(ffmpeg + ["-f", "lavfi", "-i", "color=c=green:s=160x90:d=1",
                  "-c:v", "mpeg4", root / "plain.mp4"])
    run(ffmpeg + ["-f", "lavfi", "-i", "color=c=red:s=80x120",
                  "-frames:v", "1", "-threads", "1", root / "cover.jpg"])
    run(ffmpeg + ["-i", root / "plain.mp4", "-i", root / "cover.jpg",
                  "-map", "0:v", "-map", "1:v", "-c", "copy",
                  "-disposition:v:1", "attached_pic",
                  root / "cover ' $(touch UNEXPECTED) ;.MP4"])
    run(ffmpeg + ["-i", root / "plain.mp4", "-c", "copy",
                  "-attach", root / "cover.jpg", "-metadata:s:t", "mimetype=image/jpeg",
                  "-metadata:s:t", "filename=cover.jpg", root / "cover.mkv"])
    (root / "directory.mp4").mkdir()
    (root / "broken.mp4").write_text("not a movie")
    for name, body in {
        "fail": "exit 1",
        "empty": "exit 0",
        "invalid": 'printf invalid > "$4"',
        "hang": "exec /bin/sleep 60",
    }.items():
        helper = root / name
        helper.write_text("#!/bin/sh\n" + body + "\n")
        helper.chmod(0o700)
    run([runner, root], cwd=root, timeout=40)

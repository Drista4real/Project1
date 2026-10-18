"""Download the pinned Model 3 release without installing export dependencies."""

import argparse
import hashlib
import json
import shutil
import subprocess
import tempfile
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODEL_DIR = ROOT / "weights/onnx/phowhisper-tiny"
REPOSITORY = "Drista4real/Project1"
RELEASE_TAG = "model3-phowhisper-tiny-int8-v1"
ARTIFACTS = ("encoder.int8.onnx", "decoder.int8.onnx", "tokens.txt")


def verify_artifacts(directory: Path, manifest: dict) -> None:
    """Verify against the manifest committed with this checkout."""
    for name in ARTIFACTS:
        path = directory / name
        expected = manifest["artifacts"][name]
        if path.stat().st_size != expected["bytes"]:
            raise ValueError(f"Size mismatch: {name}")
        with path.open("rb") as stream:
            checksum = hashlib.file_digest(stream, "sha256").hexdigest()
        if checksum != expected["sha256"]:
            raise ValueError(f"SHA256 mismatch: {name}")


def download_model(output_dir: Path, *, github_cli: bool = False) -> None:
    manifest_path = MODEL_DIR / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    try:
        verify_artifacts(output_dir, manifest)
    except (OSError, ValueError):
        pass
    else:
        print(f"Model already verified: {output_dir}")
        return

    # Stage on the destination filesystem; verify every file before replacing any.
    output_dir.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(
        prefix=".asr-download-", dir=output_dir.parent
    ) as temporary:
        staging = Path(temporary)
        if github_cli:
            if shutil.which("gh") is None:
                raise RuntimeError("Install GitHub CLI and run: gh auth login")
            command = [
                "gh",
                "release",
                "download",
                RELEASE_TAG,
                "--repo",
                REPOSITORY,
                "--dir",
                str(staging),
            ]
            for name in ARTIFACTS:
                command.extend(["--pattern", name])
            subprocess.run(command, check=True)
        else:
            for name in ARTIFACTS:
                print(f"Downloading {name}...", flush=True)
                url = (
                    f"https://github.com/{REPOSITORY}/releases/download/"
                    f"{RELEASE_TAG}/{name}"
                )
                request = urllib.request.Request(
                    url, headers={"User-Agent": "Project1-Model3-Setup"}
                )
                with urllib.request.urlopen(request, timeout=120) as response:
                    with (staging / name).open("wb") as destination:
                        shutil.copyfileobj(response, destination)
        verify_artifacts(staging, manifest)
        output_dir.mkdir(parents=True, exist_ok=True)
        for name in ARTIFACTS:
            (staging / name).replace(output_dir / name)
        if output_dir.resolve() != MODEL_DIR.resolve():
            shutil.copyfile(manifest_path, output_dir / "manifest.json")
    print(f"Model downloaded and SHA256 verified: {output_dir}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=MODEL_DIR)
    parser.add_argument(
        "--github-cli",
        action="store_true",
        help="Use gh auth for a private repository instead of public HTTPS.",
    )
    args = parser.parse_args()
    try:
        download_model(args.output_dir, github_cli=args.github_cli)
    except (
        OSError,
        ValueError,
        RuntimeError,
        urllib.error.URLError,
        subprocess.CalledProcessError,
    ) as error:
        parser.exit(
            1,
            f"Model setup failed: {error}\n"
            f"Confirm release {RELEASE_TAG} exists. For a private repo, run "
            "gh auth login, then retry with --github-cli.\n",
        )


if __name__ == "__main__":
    main()

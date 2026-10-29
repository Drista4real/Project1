"""Publish verified local Model 3 files as a versioned GitHub Release."""

import json
import shutil
import subprocess
import tempfile
from pathlib import Path

from download_asr_model import (
    ARTIFACTS,
    MODEL_DIR,
    RELEASE_TAG,
    REPOSITORY,
    ROOT,
    verify_artifacts,
)


def main() -> None:
    if shutil.which("gh") is None:
        raise SystemExit("Install GitHub CLI and run: gh auth login")
    manifest = json.loads((MODEL_DIR / "manifest.json").read_text(encoding="utf-8"))
    verify_artifacts(MODEL_DIR, manifest)
    subprocess.run(["gh", "auth", "status"], check=True)
    commit = subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
    ).strip()
    notes = (
        "PhoWhisper-tiny Vietnamese offline speech model for Project1 (Model 3).\n\n"
        f"Source: {manifest['source']} @ {manifest['source_revision']}\n"
        f"Exporter: k2-fsa/sherpa-onnx @ {manifest['exporter_revision']}\n"
        f"Quantization: {manifest['quantization']}\n\n"
        "Assets: encoder.int8.onnx, decoder.int8.onnx, tokens.txt, manifest.json.\n"
        "Manual setup (works with existing repository checkouts): download all four "
        "assets into weights/onnx/phowhisper-tiny/, including manifest.json. "
        "Keep the four files together as one version.\n"
        "For the Python speech runtime: python -m pip install -r "
        "backend/requirements-asr.txt\n\n"
        "With the new setup scripts available in your checkout:\n"
        "Download with: python backend/scripts/download_asr_model.py\n"
        "For private repositories add --github-cli after gh auth login.\n"
        "The downloader verifies SHA256 and sizes against the tracked manifest.\n"
        "For Flutter, also run: python frontend/scripts/prepare_voice_assets.py\n"
    )
    with tempfile.TemporaryDirectory(prefix="project1-asr-release-") as temporary:
        notes_path = Path(temporary) / "notes.md"
        notes_path.write_text(notes, encoding="utf-8")
        # Upload to a draft so incomplete uploads never appear as a ready release.
        # Existing tags/releases fail rather than replacing immutable model assets.
        subprocess.run(
            [
                "gh",
                "release",
                "create",
                RELEASE_TAG,
                "--repo",
                REPOSITORY,
                "--target",
                commit,
                "--title",
                "Model 3: PhoWhisper-tiny INT8 v1",
                "--notes-file",
                str(notes_path),
                "--draft",
                *[str(MODEL_DIR / name) for name in (*ARTIFACTS, "manifest.json")],
            ],
            check=True,
        )
    subprocess.run(
        [
            "gh",
            "release",
            "edit",
            RELEASE_TAG,
            "--repo",
            REPOSITORY,
            "--draft=false",
            "--latest=false",
        ],
        check=True,
    )
    print(f"Published https://github.com/{REPOSITORY}/releases/tag/{RELEASE_TAG}")


if __name__ == "__main__":
    main()

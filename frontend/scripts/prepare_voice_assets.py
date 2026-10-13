"""Validate genuine PhoWhisper exports and bundle them for Flutter offline ASR."""

import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "weights/onnx/phowhisper-tiny"
DESTINATION = ROOT / "frontend/assets/models/phowhisper-tiny"


def main() -> None:
    """Check every artifact before copying any model into the Flutter bundle."""
    manifest = json.loads((SOURCE / "manifest.json").read_text(encoding="utf-8"))
    if manifest["source"] != "vinai/PhoWhisper-tiny":
        raise ValueError("Expected a genuine PhoWhisper-tiny export")
    names = ("encoder.int8.onnx", "decoder.int8.onnx", "tokens.txt")
    for name in names:
        path = SOURCE / name
        info = manifest["artifacts"][name]
        with path.open("rb") as stream:
            checksum = hashlib.file_digest(stream, "sha256").hexdigest()
        if path.stat().st_size != info["bytes"] or checksum != info["sha256"]:
            raise ValueError(f"Artifact verification failed: {name}")
    DESTINATION.mkdir(parents=True, exist_ok=True)
    for name in (*names, "manifest.json"):
        shutil.copyfile(SOURCE / name, DESTINATION / name)
    print("Verified and bundled PhoWhisper-tiny INT8 for Android offline speech.")


if __name__ == "__main__":
    main()

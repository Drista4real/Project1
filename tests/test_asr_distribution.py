"""Model distribution checks without network access or real model dependencies."""

import hashlib
import importlib.util
import io
import json
import subprocess
import sys
from pathlib import Path
from unittest.mock import patch

import pytest

SCRIPT = Path(__file__).resolve().parents[1] / "backend/scripts/download_asr_model.py"
SPEC = importlib.util.spec_from_file_location("asr_download", SCRIPT)
downloader = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(downloader)


@pytest.fixture
def model(tmp_path, monkeypatch):
    source = tmp_path / "source"
    source.mkdir()
    contents = {name: name.encode() for name in downloader.ARTIFACTS}
    manifest = {
        "artifacts": {
            name: {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
            for name, data in contents.items()
        }
    }
    (source / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    monkeypatch.setattr(downloader, "MODEL_DIR", source)
    return contents, manifest


def test_download_installs_verified_artifacts_and_reuses_them(tmp_path, model):
    contents, manifest = model
    target = tmp_path / "installed"

    def response(request, timeout):
        return io.BytesIO(contents[request.full_url.rsplit("/", 1)[1]])

    with patch.object(
        downloader.urllib.request, "urlopen", side_effect=response
    ) as get:
        downloader.download_model(target)
        downloader.verify_artifacts(target, manifest)
        assert json.loads((target / "manifest.json").read_text()) == manifest
        downloader.download_model(target)
        assert get.call_count == 3


@pytest.mark.parametrize("failure", ["corruption", "interruption"])
def test_failed_download_preserves_existing_files(tmp_path, model, failure):
    contents, _ = model
    target = tmp_path / "installed"
    target.mkdir()
    for name in contents:
        (target / name).write_bytes(b"previous")

    def response(request, timeout):
        name = request.full_url.rsplit("/", 1)[1]
        if name == "decoder.int8.onnx":
            if failure == "interruption":
                raise OSError("connection interrupted")
            return io.BytesIO(b"x" * len(contents[name]))
        return io.BytesIO(contents[name])

    with (
        patch.object(downloader.urllib.request, "urlopen", side_effect=response),
        pytest.raises((OSError, ValueError)),
    ):
        downloader.download_model(target)
    assert all((target / name).read_bytes() == b"previous" for name in contents)
    assert not list(tmp_path.glob(".asr-download-*"))


def test_private_repo_uses_cli_and_verifies_download(tmp_path, model):
    contents, manifest = model
    target = tmp_path / "installed"

    def cli(command, check):
        staging = Path(command[command.index("--dir") + 1])
        for name, data in contents.items():
            (staging / name).write_bytes(data)
        assert command[:3] == ["gh", "release", "download"]
        assert downloader.RELEASE_TAG in command
        assert downloader.REPOSITORY in command

    with (
        patch.object(downloader.shutil, "which", return_value="gh"),
        patch.object(downloader.subprocess, "run", side_effect=cli),
        patch.object(downloader.urllib.request, "urlopen") as get,
    ):
        downloader.download_model(target, github_cli=True)
        get.assert_not_called()
    downloader.verify_artifacts(target, manifest)


@pytest.mark.parametrize("upload_fails", [False, True])
def test_release_publishes_only_after_upload(
    tmp_path, model, monkeypatch, upload_fails
):
    contents, _ = model
    source = downloader.MODEL_DIR
    for name, data in contents.items():
        (source / name).write_bytes(data)
    manifest = json.loads((source / "manifest.json").read_text())
    manifest.update(
        source="vinai/PhoWhisper-tiny",
        source_revision="revision",
        exporter_revision="exporter",
        quantization="INT8",
    )
    (source / "manifest.json").write_text(json.dumps(manifest))
    monkeypatch.setitem(sys.modules, "download_asr_model", downloader)
    spec = importlib.util.spec_from_file_location(
        "asr_publish", SCRIPT.with_name("publish_asr_model.py")
    )
    publisher = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(publisher)
    commands = []

    def run(command, check):
        commands.append(command)
        if command[1:3] == ["release", "create"]:
            assert "--draft" in command
            assert all(str(source / name) in command for name in contents)
            notes = Path(command[command.index("--notes-file") + 1])
            assert "PhoWhisper" in notes.read_text()
            if upload_fails:
                raise subprocess.CalledProcessError(1, command)

    with (
        patch.object(publisher.shutil, "which", return_value="gh"),
        patch.object(publisher.subprocess, "check_output", return_value="commit\n"),
        patch.object(publisher.subprocess, "run", side_effect=run),
    ):
        if upload_fails:
            with pytest.raises(subprocess.CalledProcessError):
                publisher.main()
        else:
            publisher.main()
    published = any(cmd[1:3] == ["release", "edit"] for cmd in commands)
    assert published is not upload_fails

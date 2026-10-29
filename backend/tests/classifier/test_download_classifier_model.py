"""Setup honors training metadata and verifies the cache without network access."""

from pathlib import Path
from unittest.mock import Mock

import numpy as np
import pytest

from app.infrastructure.ai.classifier import phobert_embedder
from app.infrastructure.ai.classifier.config import ClassifierConfig
from scripts.download_classifier_model import prepare_model


@pytest.mark.parametrize("offline_only", [False, True])
def test_setup_honors_revision_and_verifies_offline(
    tmp_path, monkeypatch, offline_only
):
    config = ClassifierConfig(revision="frozen-training-commit")
    path = tmp_path / "classifier_config.json"
    config.save(path)
    original = path.read_bytes()
    cache = tmp_path / "custom-cache"
    embedder = Mock(config=config)
    embedder.embed.return_value = np.zeros(768, dtype=np.float32)
    factory = Mock(return_value=embedder)
    monkeypatch.setattr(phobert_embedder, "PhoBERTEmbedder", factory)

    assert prepare_model(path, cache, local_files_only=offline_only) == config.revision
    assert [call.kwargs for call in factory.call_args_list] == [
        {"config": config, "cache_dir": cache, "local_files_only": offline_only},
        {"config": config, "cache_dir": cache, "local_files_only": True},
    ]
    embedder.embed.assert_called_once()
    assert path.read_bytes() == original


def test_invalid_config_fails_before_loading_or_downloading(tmp_path, monkeypatch):
    path = tmp_path / "invalid.json"
    path.write_text('{"model_name": "wrong-model"}', encoding="utf-8")
    factory = Mock()
    monkeypatch.setattr(phobert_embedder, "PhoBERTEmbedder", factory)
    with pytest.raises(ValueError, match="Cannot load classifier configuration"):
        prepare_model(path, tmp_path / "cache")
    factory.assert_not_called()


def test_offline_reload_failure_is_not_reported_as_success(tmp_path, monkeypatch):
    config = ClassifierConfig()
    path: Path = tmp_path / "config.json"
    config.save(path)
    factory = Mock(
        side_effect=[Mock(config=config), RuntimeError("cache not usable offline")]
    )
    monkeypatch.setattr(phobert_embedder, "PhoBERTEmbedder", factory)
    with pytest.raises(RuntimeError, match="cache not usable offline"):
        prepare_model(path, tmp_path / "cache")

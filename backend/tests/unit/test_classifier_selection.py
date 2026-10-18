"""Verify backend selection and graceful failure without loading real weights."""

import sys
from types import SimpleNamespace
from unittest.mock import Mock

import pytest

from app.infrastructure.ai import transaction_parser as parser


@pytest.fixture(autouse=True)
def clear_classifier_cache():
    """Isolate the process-wide classifier cache between selection checks."""
    parser._load_local_classifier.cache_clear()
    yield
    parser._load_local_classifier.cache_clear()


def test_lora_selection_is_offline_and_reused(monkeypatch, tmp_path):
    """Requests reuse one adapter with the configured device and paths."""
    settings = SimpleNamespace(
        classifier_backend="lora",
        classifier_device="cpu",
        classifier_lora_dir=tmp_path / "adapter",
        classifier_lora_cache_dir=tmp_path / "cache",
    )
    loader = Mock(return_value=object())
    monkeypatch.setattr(parser, "get_settings", lambda: settings)
    monkeypatch.setitem(
        sys.modules,
        "app.infrastructure.ai.classifier.lora",
        SimpleNamespace(LoRAClassifier=loader),
    )
    assert parser.local_classifier() is parser.local_classifier()
    loader.assert_called_once_with(
        settings.classifier_lora_dir,
        device="cpu",
        cache_dir=settings.classifier_lora_cache_dir,
        local_files_only=True,
    )


def test_lightgbm_can_still_be_selected(monkeypatch):
    """Switching back selects the original classifier without loading LoRA."""
    loader = Mock(return_value=object())
    monkeypatch.setattr(
        parser, "get_settings", lambda: SimpleNamespace(classifier_backend="lightgbm")
    )
    monkeypatch.setitem(
        sys.modules,
        "app.infrastructure.ai.classifier.lgbm_inference",
        SimpleNamespace(LightGBMTransactionClassifier=loader),
    )
    assert parser.local_classifier() is loader.return_value
    loader.assert_called_once_with()


def test_missing_lora_retains_review_fallback(monkeypatch, tmp_path, caplog):
    """A missing cache does not break transaction parsing or substitute a model."""
    settings = SimpleNamespace(
        classifier_backend="lora",
        classifier_device="cpu",
        classifier_lora_dir=tmp_path,
        classifier_lora_cache_dir=tmp_path,
    )
    monkeypatch.setattr(parser, "get_settings", lambda: settings)
    monkeypatch.setitem(
        sys.modules,
        "app.infrastructure.ai.classifier.lora",
        SimpleNamespace(LoRAClassifier=Mock(side_effect=OSError("missing cache"))),
    )
    assert parser.local_classifier() is None
    assert "lora unavailable" in caplog.text

"""Classifier contract tests use real LightGBM and deterministic encoder doubles."""

import csv
import pickle
import random
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock

import numpy as np
import pytest
import torch
from lightgbm import LGBMClassifier
from sklearn.preprocessing import LabelEncoder

from app.infrastructure.ai.classifier import phobert_embedder as embedding_module
from app.infrastructure.ai.classifier.config import CATEGORIES, ClassifierConfig
from app.infrastructure.ai.classifier.lgbm_inference import (
    LightGBMTransactionClassifier,
)
from app.infrastructure.ai.classifier.phobert_embedder import PhoBERTEmbedder
from scripts import train_classifier
from scripts.dataset_pipeline import Source, prepare_dataset, verify_bundle


@pytest.fixture
def artifacts(tmp_path: Path) -> tuple[Path, Mock]:
    """Fit a genuine six-class classifier and write its portable artifacts."""
    encoder = LabelEncoder().fit(list(CATEGORIES))
    features = np.zeros((120, 768), dtype=np.float32)
    labels = np.repeat(np.arange(6), 20)
    features[:, 0] = labels
    model = LGBMClassifier(
        n_estimators=5,
        objective="multiclass",
        min_child_samples=1,
        n_jobs=1,
        verbosity=-1,
    ).fit(features, labels)
    for name, artifact in (
        ("lgbm_classifier.pkl", model),
        ("label_encoder.pkl", encoder),
    ):
        with (tmp_path / name).open("wb") as stream:
            pickle.dump(artifact, stream)
    config = ClassifierConfig()
    config.save(tmp_path / "classifier_config.json")
    embedder = Mock(spec=PhoBERTEmbedder)
    embedder.config = config
    embedder.embed.return_value = np.zeros(768, dtype=np.float32)
    return tmp_path / "lgbm_classifier.pkl", embedder


@pytest.mark.parametrize(
    ("probability", "source"),
    [(0.799999, "CLOUD_FALLBACK"), (0.8, "LOCAL"), (0.95, "LOCAL")],
)
def test_routing_and_domain_adapter(
    artifacts: tuple[Path, Mock],
    probability: float,
    source: str,
) -> None:
    """Check the inclusive boundary, decoded label, and existing classify contract."""
    path, embedder = artifacts
    classifier = LightGBMTransactionClassifier(path, embedder)
    values = np.full((1, 6), (1 - probability) / 5)
    values[0, 3] = probability
    classifier.model.predict_proba = Mock(return_value=values)
    label, confidence, route = classifier.predict("ăn trưa")
    assert label == classifier.label_encoder.inverse_transform([3])[0]
    assert confidence == probability
    assert route == source
    result = classifier.classify("ăn trưa")
    assert (result.label, result.confidence) == (label, probability)


@pytest.mark.parametrize(
    "bad", [np.full((1, 6), np.nan), np.ones((1, 6)), np.ones((1, 5))]
)
def test_invalid_probabilities(artifacts: tuple[Path, Mock], bad: np.ndarray) -> None:
    """Invalid output must fail instead of selecting a misleading category."""
    path, embedder = artifacts
    classifier = LightGBMTransactionClassifier(path, embedder)
    classifier.model.predict_proba = Mock(return_value=bad)
    with pytest.raises(RuntimeError, match="invalid category probabilities"):
        classifier.predict("ăn trưa")


def test_missing_artifact(tmp_path: Path) -> None:
    """Missing weights fail before attempting to load PhoBERT."""
    with pytest.raises(FileNotFoundError, match="Run training"):
        LightGBMTransactionClassifier(tmp_path / "absent.pkl")


def test_incompatible_metadata(artifacts: tuple[Path, Mock]) -> None:
    """A different segmentation or sequence length cannot be silently accepted."""
    path, embedder = artifacts
    embedder.config = ClassifierConfig(max_length=128)
    with pytest.raises(ValueError, match="differs from training"):
        LightGBMTransactionClassifier(path, embedder)


def test_legacy_bundle_checks_features(artifacts: tuple[Path, Mock]) -> None:
    """Allow resolved revisions for legacy bundles but reject feature drift."""
    path, embedder = artifacts
    path.with_name("classifier_config.json").unlink()
    embedder.config = ClassifierConfig(revision="cached-commit")
    classifier = LightGBMTransactionClassifier(path, embedder)
    assert classifier.predict("ăn trưa")[0] in CATEGORIES
    embedder.config = ClassifierConfig(max_length=128)
    with pytest.raises(ValueError, match="differs from training"):
        LightGBMTransactionClassifier(path, embedder)


def test_corrupt_artifact(artifacts: tuple[Path, Mock]) -> None:
    """A corrupted checkpoint yields an error naming the artifact."""
    path, embedder = artifacts
    path.write_bytes(b"invalid pickle")
    with pytest.raises(RuntimeError, match="Cannot load classifier artifact"):
        LightGBMTransactionClassifier(path, embedder)


def test_invalid_label_mapping(artifacts: tuple[Path, Mock]) -> None:
    """Reject reordered label metadata that would misdecode model class IDs."""
    path, embedder = artifacts
    encoder = LabelEncoder().fit(list(CATEGORIES))
    encoder.classes_ = encoder.classes_[::-1]
    with path.with_name("label_encoder.pkl").open("wb") as stream:
        pickle.dump(encoder, stream)
    with pytest.raises(ValueError, match="six transaction categories"):
        LightGBMTransactionClassifier(path, embedder)


def test_cls_cpu_no_grad_and_segmentation(monkeypatch: pytest.MonkeyPatch) -> None:
    """Validate first-token pooling, CPU tensors, normalization, and batch shape."""
    segmenter = Mock(
        side_effect=lambda text, format: text.replace("ăn uống", "ăn_uống")
    )
    monkeypatch.setattr(embedding_module, "word_tokenize", segmenter)
    embedder = PhoBERTEmbedder.__new__(PhoBERTEmbedder)
    embedder.config = ClassifierConfig()
    embedder.tokenizer = Mock(
        return_value={"input_ids": torch.ones((1, 3), dtype=torch.long)}
    )

    def forward(**inputs: torch.Tensor) -> SimpleNamespace:
        """Make other token positions distinct from CLS to detect wrong pooling."""
        assert not torch.is_grad_enabled()
        assert inputs["input_ids"].device.type == "cpu"
        hidden = torch.ones((1, 3, 768))
        hidden[:, 0] = 7
        return SimpleNamespace(last_hidden_state=hidden)

    embedder.model = Mock(side_effect=forward)
    vector = embedder.embed("  ĂN  UỐNG\n hôm nay ")
    segmenter.assert_called_once_with("ăn uống hôm nay", format="text")
    assert embedder.tokenizer.call_args.args[0] == ["ăn_uống hôm nay"]
    assert vector.shape == (768,)
    assert vector.dtype == np.float32
    assert np.all(vector == 7)


@pytest.mark.parametrize("text", ["", " \n "])
def test_empty_text(text: str) -> None:
    """Blank descriptions fail before tokenization or model work."""
    with pytest.raises(ValueError, match="must not be empty"):
        embedding_module.preprocess_text(text)


def test_offline_loading_does_not_download(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    """A missing offline cache must never retry with network enabled."""
    loader = Mock(side_effect=OSError("no cache"))
    monkeypatch.setattr(embedding_module.AutoTokenizer, "from_pretrained", loader)
    with pytest.raises(RuntimeError, match="Populate the cache"):
        PhoBERTEmbedder(cache_dir=tmp_path, local_files_only=True)
    assert loader.call_count == 1
    assert loader.call_args.kwargs["local_files_only"] is True


def test_training_roundtrip(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    """Exercise CSV split, real fitting, artifacts, metadata, and loaded prediction."""
    data = tmp_path / "data_transactions.csv"
    with data.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(["text", "category"])
        for index, category in enumerate(CATEGORIES):
            for sample in range(30):
                writer.writerow([f"giao dịch {index} lần {sample}", category])
    embedder = Mock(spec=PhoBERTEmbedder)
    embedder.config = ClassifierConfig()

    def batch(texts: list[str], *, batch_size: int) -> np.ndarray:
        """Build class-specific features without downloading model weights."""
        vectors = np.zeros((len(texts), 768), dtype=np.float32)
        vectors[:, 0] = [int(text.split()[2]) for text in texts]
        return vectors

    embedder.embed_batch.side_effect = batch
    embedder.embed.return_value = np.zeros(768, dtype=np.float32)
    monkeypatch.setattr(
        train_classifier, "PhoBERTEmbedder", Mock(return_value=embedder)
    )
    output = tmp_path / "weights"
    train_classifier.train(data, output, batch_size=8)
    assert {p.name for p in output.iterdir()} == {
        "lgbm_classifier.pkl",
        "label_encoder.pkl",
        "classifier_config.json",
    }
    report = capsys.readouterr().out
    assert "Macro F1-Score:" in report
    assert "Local handling rate" in report
    assert "CPU latency" in report
    classifier = LightGBMTransactionClassifier(output / "lgbm_classifier.pkl", embedder)
    assert classifier.predict("giao dịch")[0] in CATEGORIES
    assert len(embedder.embed_batch.call_args_list[0].args[0]) == 144
    assert len(embedder.embed_batch.call_args_list[1].args[0]) == 36


def test_invalid_dataset(tmp_path: Path) -> None:
    """Reject the legacy schema and unsupported labels without model loading."""
    path = tmp_path / "invalid.csv"
    path.write_text("text,label\nĂn trưa,food\n", encoding="utf-8")
    with pytest.raises(ValueError, match="text,category"):
        train_classifier.load_dataset(path)
    path.write_text("text,category\nĂn trưa,food\n", encoding="utf-8")
    with pytest.raises(ValueError, match="row 2"):
        train_classifier.load_dataset(path)


def test_training_preserves_verified_splits(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    """Prepared training never re-splits or fits validation/test examples."""
    data = tmp_path / "source.csv"
    rng = random.Random(42)
    with data.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(["text", "category"])
        for category in CATEGORIES:
            for _ in range(15):
                writer.writerow(
                    [
                        "".join(rng.choices("abcdefghijklmnopqrstuvwxyz", k=20)),
                        category,
                    ]
                )
    dataset_dir = tmp_path / "dataset"
    taxonomy = (
        Path(__file__).resolve().parents[3] / "data/taxonomy/expense_categories.v1.json"
    )
    prepare_dataset(
        [Source(data, "fixture", "synthetic", "test fixture")],
        taxonomy,
        dataset_dir,
        ambiguity_policy="quarantine",
    )
    splits = verify_bundle(dataset_dir)
    embedder = Mock(spec=PhoBERTEmbedder)
    embedder.config = ClassifierConfig()
    embedder.embed_batch.side_effect = lambda texts, **kwargs: np.zeros(
        (len(texts), 768), dtype=np.float32
    )
    embedder.embed.return_value = np.zeros(768, dtype=np.float32)
    monkeypatch.setattr(
        train_classifier, "PhoBERTEmbedder", Mock(return_value=embedder)
    )
    random_split = Mock(side_effect=AssertionError("Prepared data cannot be re-split"))
    monkeypatch.setattr(train_classifier, "train_test_split", random_split)
    output = tmp_path / "trained"
    train_classifier.train(data, output, dataset_dir=dataset_dir)
    calls = embedder.embed_batch.call_args_list
    assert calls[0].args[0] == [row["text"] for row in splits["train"]]
    assert calls[1].args[0] == [row["text"] for row in splits["test"]]
    assert calls[2].args[0] == [row["text"] for row in splits["validation"]]
    assert (output / "training_data_manifest.json").read_bytes() == (
        dataset_dir / "manifest.json"
    ).read_bytes()
    random_split.assert_not_called()

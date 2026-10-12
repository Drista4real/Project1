"""Shared, versioned feature settings for training and inference."""

import json
from dataclasses import asdict, dataclass
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[5]
CHECKPOINT_DIR = PROJECT_ROOT / "weights/checkpoints"
MODEL_CACHE_DIR = PROJECT_ROOT / "weights/cache/phobert"
CATEGORIES = ("Ăn uống", "Đi lại", "Mua sắm", "Hóa đơn/Nhà ở", "Y tế", "Khác")
CONFIDENCE_THRESHOLD = 0.8


@dataclass(frozen=True)
class ClassifierConfig:
    """Persist settings that affect the 768-dimensional CLS features."""

    schema_version: int = 1
    model_name: str = "vinai/phobert-base"
    revision: str = "main"
    max_length: int = 256
    embedding_dim: int = 768
    pooling: str = "cls"
    preprocessing: str = "lower_whitespace_underthesea_text_v1"
    confidence_threshold: float = CONFIDENCE_THRESHOLD

    def __post_init__(self) -> None:
        """Reject incompatible metadata before loading weights."""
        if (
            self.schema_version != 1
            or self.model_name != "vinai/phobert-base"
            or not isinstance(self.revision, str)
            or not self.revision
            or type(self.max_length) is not int
            or not 2 <= self.max_length <= 256
            or self.embedding_dim != 768
            or self.pooling != "cls"
            or self.preprocessing != "lower_whitespace_underthesea_text_v1"
            or self.confidence_threshold != CONFIDENCE_THRESHOLD
        ):
            raise ValueError("Unsupported classifier feature configuration")

    @classmethod
    def load(cls, path: Path) -> "ClassifierConfig":
        """Read JSON metadata with contextual errors."""
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
            if not isinstance(payload, dict):
                raise ValueError("Configuration must be a JSON object")
            return cls(**payload)
        except (OSError, ValueError, TypeError) as exc:
            raise ValueError(f"Cannot load classifier configuration: {path}") from exc

    def save(self, path: Path) -> None:
        """Write portable metadata alongside the trained artifacts."""
        path.write_text(
            json.dumps(asdict(self), ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

"""Prepare genuine VinAI PhoWhisper-tiny INT8 models for offline sherpa-onnx."""

import argparse
import hashlib
import importlib.util
import json
import os
import re
import shutil
import sys
import urllib.request
from pathlib import Path
from typing import Any
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
EXPORTER_REVISION = "7be9a38e275ece9ee9a9277cc78295f2cbfd6673"
EXPORTER_SHA256 = "5e0ddabfac8330ee9aecaba4c1b4286d1cd9f88df4cd30e54706b011bf976e45"
EXPORTER_URL = f"https://raw.githubusercontent.com/k2-fsa/sherpa-onnx/{EXPORTER_REVISION}/scripts/whisper/export-onnx.py"


def map_weight_name(name: str) -> str | None:
    """Map Hugging Face Whisper tensor names to the OpenAI architecture."""
    if name == "proj_out.weight":
        return None  # Tied to the decoder token embedding; checked separately.
    name = name.removeprefix("model.")
    name = re.sub(r"\.layers\.(\d+)\.", r".blocks.\1.", name)
    for old, new in (
        ("self_attn_layer_norm", "attn_ln"),
        ("encoder_attn_layer_norm", "cross_attn_ln"),
        ("self_attn", "attn"),
        ("encoder_attn", "cross_attn"),
        ("q_proj", "query"),
        ("k_proj", "key"),
        ("v_proj", "value"),
        ("out_proj", "out"),
        ("fc1", "mlp.0"),
        ("fc2", "mlp.2"),
        ("final_layer_norm", "mlp_ln"),
        ("encoder.layer_norm", "encoder.ln_post"),
        ("decoder.layer_norm", "decoder.ln"),
        ("embed_positions.weight", "positional_embedding"),
        ("embed_tokens", "token_embedding"),
    ):
        name = name.replace(old, new)
    return name


def prepare(output_dir: Path, cache_dir: Path) -> None:
    """Download official weights, strictly remap, export/quantize, and install files."""
    import onnx
    import torch
    import whisper
    from transformers import WhisperForConditionalGeneration
    from whisper.model import ModelDimensions, disable_sdpa

    cache_dir.mkdir(parents=True, exist_ok=True)
    exporter_path = cache_dir / "export-onnx.py"
    if not exporter_path.exists():
        with urllib.request.urlopen(EXPORTER_URL, timeout=60) as response:
            exporter_path.write_bytes(response.read())
    if hashlib.sha256(exporter_path.read_bytes()).hexdigest() != EXPORTER_SHA256:
        raise ValueError(
            "Official exporter checksum does not match its pinned revision"
        )
    print("Loading official vinai/PhoWhisper-tiny weights", flush=True)
    torch.set_num_threads(1)
    original = (
        WhisperForConditionalGeneration.from_pretrained(
            "vinai/PhoWhisper-tiny",
            cache_dir=str(cache_dir / "huggingface"),
        )
        .cpu()
        .float()
        .eval()
    )
    config = original.config
    dims = ModelDimensions(
        n_mels=config.num_mel_bins,
        n_audio_ctx=config.max_source_positions,
        n_audio_state=config.d_model,
        n_audio_head=config.encoder_attention_heads,
        n_audio_layer=config.encoder_layers,
        n_vocab=config.vocab_size,
        n_text_ctx=config.max_target_positions,
        n_text_state=config.d_model,
        n_text_head=config.decoder_attention_heads,
        n_text_layer=config.decoder_layers,
    )
    state = original.state_dict()
    if not torch.equal(
        state["proj_out.weight"], state["model.decoder.embed_tokens.weight"]
    ):
        raise ValueError("Output projection and token embeddings must be tied")
    mapped = {
        converted: tensor
        for name, tensor in state.items()
        if (converted := map_weight_name(name)) is not None
    }
    model = whisper.Whisper(dims).cpu().eval()
    model.load_state_dict(mapped, strict=True)
    revision = getattr(config, "_commit_hash", None)
    revision_file = cache_dir / "huggingface/models--vinai--PhoWhisper-tiny/refs/main"
    if revision is None and revision_file.is_file():
        revision = revision_file.read_text(encoding="utf-8").strip()
    del original, state, mapped
    spec = importlib.util.spec_from_file_location(
        "sherpa_whisper_export", exporter_path
    )
    if spec is None or spec.loader is None:
        raise RuntimeError("Cannot import verified exporter")
    exporter = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(exporter)
    original_export = torch.onnx.export

    def legacy_export(*args: Any, **kwargs: Any) -> Any:
        """Keep the pinned sherpa exporter on Torch's compatible tracing backend."""
        kwargs["dynamo"] = False
        return original_export(*args, **kwargs)

    build_dir = cache_dir / "build"
    build_dir.mkdir(exist_ok=True)
    previous_dir = Path.cwd()
    try:
        os.chdir(build_dir)
        with (
            patch.object(exporter, "load_model", return_value=model),
            patch.object(sys, "argv", ["export-onnx.py", "--model", "tiny"]),
            patch.object(torch.onnx, "export", side_effect=legacy_export),
            disable_sdpa(),
            torch.no_grad(),
        ):
            exporter.main()
    finally:
        os.chdir(previous_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    artifact_names = {
        "tiny-encoder.int8.onnx": "encoder.int8.onnx",
        "tiny-decoder.int8.onnx": "decoder.int8.onnx",
        "tiny-tokens.txt": "tokens.txt",
    }
    manifest: dict[str, Any] = {
        "source": "vinai/PhoWhisper-tiny",
        "source_revision": revision,
        "exporter_revision": EXPORTER_REVISION,
        "exporter_sha256": EXPORTER_SHA256,
        "quantization": "dynamic INT8 MatMul",
        "artifacts": {},
    }
    for source_name, target_name in artifact_names.items():
        source = build_dir / source_name
        if source.suffix == ".onnx":
            graph = onnx.load(str(source))
            onnx.checker.check_model(graph)
            if not any(node.op_type == "MatMulInteger" for node in graph.graph.node):
                raise ValueError(f"{source_name} has no INT8 quantized MatMul nodes")
        target = output_dir / target_name
        temporary = target.with_suffix(target.suffix + ".tmp")
        shutil.copyfile(source, temporary)
        temporary.replace(target)
        manifest["artifacts"][target_name] = {
            "bytes": target.stat().st_size,
            "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
        }
    (output_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Installed genuine PhoWhisper-tiny INT8 in {output_dir}", flush=True)


def main() -> None:
    """Prepare offline artifacts; downloading happens only in this setup script."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-dir", type=Path, default=ROOT / "weights/onnx/phowhisper-tiny"
    )
    parser.add_argument(
        "--cache-dir", type=Path, default=ROOT / "weights/cache/asr-export"
    )
    args = parser.parse_args()
    prepare(args.output_dir.resolve(), args.cache_dir.resolve())


if __name__ == "__main__":
    main()

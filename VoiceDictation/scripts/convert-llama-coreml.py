#!/usr/bin/env python3
"""
Convert meta-llama/Llama-3.2-1B-Instruct from Hugging Face to CoreML .mlpackage.

Usage:
    pip install -r requirements-convert.txt
    python convert-llama-coreml.py [--output-dir OUTPUT_DIR]

The converted model is saved to:
    ~/Library/Application Support/VoiceDictation/models/llama-3.2-1b.mlpackage
"""

import argparse
import os
import sys
from pathlib import Path

import coremltools as ct
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

MODEL_ID = "meta-llama/Llama-3.2-1B-Instruct"
DEFAULT_OUTPUT_DIR = os.path.expanduser(
    "~/Library/Application Support/VoiceDictation/models"
)
OUTPUT_FILENAME = "llama-3.2-1b.mlpackage"
MAX_SEQ_LENGTH = 2048


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def download_model(model_id: str):
    """Download the model and tokenizer from Hugging Face."""
    print(f"[1/4] Downloading {model_id} from Hugging Face...")
    tokenizer = AutoTokenizer.from_pretrained(model_id)
    model = AutoModelForCausalLM.from_pretrained(
        model_id,
        torch_dtype=torch.float32,
        trust_remote_code=False,
    )
    model.eval()
    print(f"       Model downloaded: {sum(p.numel() for p in model.parameters()):,} parameters")
    return model, tokenizer


def trace_model(model, tokenizer):
    """Trace the model with example inputs for CoreML conversion."""
    print("[2/4] Tracing model with example inputs...")
    # Create dummy inputs matching the model's expected input shape
    dummy_input_ids = torch.randint(
        0, tokenizer.vocab_size, (1, MAX_SEQ_LENGTH), dtype=torch.int32
    )
    dummy_attention_mask = torch.ones(1, MAX_SEQ_LENGTH, dtype=torch.int32)

    traced_model = torch.jit.trace(
        model,
        (dummy_input_ids.long(), dummy_attention_mask.long()),
        strict=False,
    )
    print("       Tracing complete.")
    return traced_model


def convert_to_coreml(traced_model, tokenizer):
    """Convert the traced PyTorch model to CoreML format."""
    print("[3/4] Converting to CoreML .mlpackage...")

    input_ids_shape = ct.Shape(
        shape=(1, ct.RangeDim(lower_bound=1, upper_bound=MAX_SEQ_LENGTH, default=128))
    )
    attention_mask_shape = ct.Shape(
        shape=(1, ct.RangeDim(lower_bound=1, upper_bound=MAX_SEQ_LENGTH, default=128))
    )

    mlmodel = ct.convert(
        traced_model,
        inputs=[
            ct.TensorType(name="input_ids", shape=input_ids_shape, dtype=int),
            ct.TensorType(name="attention_mask", shape=attention_mask_shape, dtype=int),
        ],
        convert_to="mlprogram",
        compute_precision=ct.precision.FLOAT16,
        minimum_deployment_target=ct.target.macOS14,
    )

    # Add metadata
    mlmodel.author = "VoiceDictation"
    mlmodel.short_description = (
        f"Llama-3.2-1B-Instruct converted for on-device transcript cleanup. "
        f"Max sequence length: {MAX_SEQ_LENGTH}."
    )
    mlmodel.version = "1.0"

    print("       CoreML conversion complete.")
    return mlmodel


def save_model(mlmodel, output_dir: str):
    """Save the CoreML model to the output directory."""
    output_path = os.path.join(output_dir, OUTPUT_FILENAME)

    print(f"[4/4] Saving to {output_path} ...")
    os.makedirs(output_dir, exist_ok=True)
    mlmodel.save(output_path)

    # Print size
    size_bytes = sum(
        f.stat().st_size
        for f in Path(output_path).rglob("*")
        if f.is_file()
    )
    size_mb = size_bytes / (1024 * 1024)
    print(f"       Saved ({size_mb:.1f} MB)")
    return output_path


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Convert Llama-3.2-1B-Instruct to CoreML .mlpackage"
    )
    parser.add_argument(
        "--output-dir",
        default=DEFAULT_OUTPUT_DIR,
        help=f"Directory to save the .mlpackage (default: {DEFAULT_OUTPUT_DIR})",
    )
    parser.add_argument(
        "--model-id",
        default=MODEL_ID,
        help=f"Hugging Face model ID (default: {MODEL_ID})",
    )
    args = parser.parse_args()

    print("=" * 60)
    print("  Llama 3.2 1B -> CoreML Conversion")
    print("=" * 60)
    print()

    # Step 1: Download
    model, tokenizer = download_model(args.model_id)

    # Step 2: Trace
    traced_model = trace_model(model, tokenizer)

    # Step 3: Convert
    mlmodel = convert_to_coreml(traced_model, tokenizer)

    # Step 4: Save
    output_path = save_model(mlmodel, args.output_dir)

    print()
    print("=" * 60)
    print(f"  Done! Model saved to:")
    print(f"  {output_path}")
    print("=" * 60)


if __name__ == "__main__":
    main()

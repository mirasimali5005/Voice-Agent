#!/usr/bin/env python3
"""
Download a small LLM in MLX format for on-device text cleanup.

MLX models run natively on Apple Silicon with Metal GPU acceleration —
no CoreML conversion needed, no compatibility issues.

Default model: Qwen/Qwen2.5-1.5B-Instruct (ungated, no login required)

Usage:
    pip install -r requirements-convert.txt
    python convert-llama-coreml.py [--model-id MODEL_ID]
"""

import argparse
import os
import subprocess
import sys
from pathlib import Path


MODEL_ID = "mlx-community/Qwen2.5-1.5B-Instruct-4bit"  # Pre-quantized, ~1GB, ungated
DEFAULT_OUTPUT_DIR = os.path.expanduser(
    "~/Library/Application Support/VoiceDictation/models"
)
OUTPUT_DIRNAME = "cleanup-llm-mlx"


def check_dependencies():
    """Ensure mlx-lm is installed."""
    try:
        import mlx_lm  # noqa: F401
        print("[OK] mlx-lm is installed")
    except ImportError:
        print("[!] Installing mlx-lm...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "mlx-lm"])
        print("[OK] mlx-lm installed")


def download_model(model_id: str, output_dir: str) -> str:
    """Download the MLX model from Hugging Face."""
    from huggingface_hub import snapshot_download

    output_path = os.path.join(output_dir, OUTPUT_DIRNAME)
    os.makedirs(output_dir, exist_ok=True)

    print(f"[1/2] Downloading {model_id} from Hugging Face...")
    print(f"      Destination: {output_path}")

    snapshot_download(
        repo_id=model_id,
        local_dir=output_path,
        local_dir_use_symlinks=False,
    )

    print(f"[OK] Model downloaded to: {output_path}")
    return output_path


def verify_model(output_path: str):
    """Verify the model can load and generate text."""
    print(f"\n[2/2] Verifying model...")

    try:
        from mlx_lm import load, generate

        model, tokenizer = load(output_path)

        test_prompt = "Clean up this transcript: gonna set up a meeting tmrw"
        messages = [
            {"role": "system", "content": "You are a text cleanup assistant. Fix grammar and remove filler words. Return only the cleaned text."},
            {"role": "user", "content": test_prompt},
        ]

        prompt = tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
        result = generate(model, tokenizer, prompt=prompt, max_tokens=50)

        print(f"      Input:  '{test_prompt}'")
        print(f"      Output: '{result.strip()}'")
        print(f"[OK] Model works!")
        return True
    except Exception as e:
        print(f"[!] Verification failed: {e}")
        print(f"    The model was downloaded but couldn't generate text.")
        print(f"    This might still work — the Swift app will try to use it.")
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Download an MLX model for on-device text cleanup"
    )
    parser.add_argument(
        "--output-dir",
        default=DEFAULT_OUTPUT_DIR,
        help=f"Directory to save the model (default: {DEFAULT_OUTPUT_DIR})",
    )
    parser.add_argument(
        "--model-id",
        default=MODEL_ID,
        help=f"Hugging Face model ID (default: {MODEL_ID})",
    )
    args = parser.parse_args()

    print("=" * 60)
    print(f"  Voice Agent — Download Cleanup LLM")
    print(f"  Model: {args.model_id}")
    print("=" * 60)
    print()

    # Check deps
    check_dependencies()
    print()

    # Download
    output_path = download_model(args.model_id, args.output_dir)
    print()

    # Verify
    verify_model(output_path)

    print()
    print("=" * 60)
    print(f"  Done! Model saved to:")
    print(f"  {output_path}")
    print()
    print(f"  The Voice Agent app will automatically detect and use this model.")
    print(f"  No LM Studio needed!")
    print("=" * 60)


if __name__ == "__main__":
    main()

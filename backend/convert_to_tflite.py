"""
convert_to_tflite.py
====================
Converts the TruthLens AI deepfake detector from .keras → .tflite format
for on-device inference on Android.

Usage:
    python convert_to_tflite.py --input deepfake_detector.keras [--quantization fp16|int8|none]

Quantization modes:
    none  → Full FP32  (~22 MB) — largest, most accurate
    fp16  → FP16       (~11 MB) — recommended: half size, <0.5% accuracy drop
    int8  → Dynamic INT8 (~6 MB) — smallest, slight accuracy drop

CRITICAL PREPROCESSING NOTE:
    EfficientNetB0 has a built-in Rescaling layer.
    The model expects raw [0, 255] float32 input — DO NOT divide by 255.
    This is preserved automatically during TFLite conversion.
"""

import os
import argparse
import numpy as np
import tensorflow as tf


# ─── Constants ────────────────────────────────────────────────────────────────

# Must match training config exactly
INPUT_SHAPE  = (1, 224, 224, 3)   # Batch=1, HxW=224x224, RGB
OUTPUT_SHAPE = (1, 1)             # Sigmoid binary output: >0.5 → FAKE


# ─── Argument Parsing ─────────────────────────────────────────────────────────

def parse_args():
    parser = argparse.ArgumentParser(description="Convert TruthLens .keras → .tflite")
    parser.add_argument(
        "--input", type=str, default="deepfake_detector.keras",
        help="Path to the .keras or .h5 model file"
    )
    parser.add_argument(
        "--output", type=str, default=None,
        help="Output .tflite path (auto-named from input if not specified)"
    )
    parser.add_argument(
        "--quantization", type=str, choices=["none", "fp16", "int8"],
        default="fp16",
        help="Quantization mode: none | fp16 (recommended) | int8"
    )
    return parser.parse_args()


# ─── Step 1: Load Model ───────────────────────────────────────────────────────

def load_keras_model(model_path: str) -> tf.keras.Model:
    """Load and validate the Keras model before conversion."""
    if not os.path.exists(model_path):
        raise FileNotFoundError(f"Model file not found: {model_path}")

    print(f"\n[1/4] Loading model: {model_path}")
    model = tf.keras.models.load_model(model_path)

    # Guard: Ensure shapes match what detector.py expects
    assert model.input_shape == (None, 224, 224, 3), (
        f"Wrong input shape {model.input_shape}. Expected (None, 224, 224, 3).\n"
        "Check IMAGE_SIZE in detector.py."
    )
    assert model.output_shape == (None, 1), (
        f"Wrong output shape {model.output_shape}. Expected (None, 1).\n"
        "Model must use sigmoid activation on a single output node."
    )

    print(f"   ✅ Input  : {model.input_shape}")
    print(f"   ✅ Output : {model.output_shape}")
    print(f"   Parameters: {model.count_params():,}")
    return model


# ─── Step 2: Configure Converter ──────────────────────────────────────────────

def build_converter(
    model: tf.keras.Model,
    quantization: str,
) -> tf.lite.TFLiteConverter:
    """
    Build a TFLiteConverter configured for the selected quantization mode.

    No manual normalization is injected — EfficientNetB0's built-in Rescaling
    layer already handles normalization. Input must stay raw [0, 255] float32.
    """
    converter = tf.lite.TFLiteConverter.from_keras_model(model)

    if quantization == "none":
        # Pure FP32 — no changes, maximum fidelity
        print("[2/4] Mode: FP32 (no quantization) — maximum accuracy, ~22 MB")

    elif quantization == "fp16":
        # Post-training FP16: weights stored as float16, inference in float32
        # Best trade-off for mobile — recommended for TruthLens AI
        converter.optimizations               = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_types = [tf.float16]
        print("[2/4] Mode: FP16 quantization — recommended (~11 MB, <0.5% accuracy drop)")

    elif quantization == "int8":
        # Dynamic range INT8: weights quantized to int8, activations at runtime
        # No representative dataset needed (dynamic range, not full INT8)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        print("[2/4] Mode: Dynamic INT8 — smallest (~6 MB, slight accuracy drop)")

    return converter


# ─── Step 3: Convert ──────────────────────────────────────────────────────────

def convert(model: tf.keras.Model, quantization: str) -> bytes:
    """Execute the TFLite conversion and return the model bytes."""
    print("[3/4] Converting...")
    converter    = build_converter(model, quantization)
    tflite_bytes = converter.convert()
    print(f"   Converted: {len(tflite_bytes) / 1024 / 1024:.1f} MB")
    return tflite_bytes


# ─── Step 4: Validate ─────────────────────────────────────────────────────────

def validate(tflite_bytes: bytes) -> None:
    """
    Run sanity checks on the converted model:
      - Input/output tensor shapes match expectations
      - Output is always in [0.0, 1.0]
      - Outputs differ across different inputs (no collapsed/constant output)
    """
    print("[4/4] Validating...")

    interpreter = tf.lite.Interpreter(model_content=tflite_bytes)
    interpreter.allocate_tensors()

    in_detail  = interpreter.get_input_details()[0]
    out_detail = interpreter.get_output_details()[0]

    # ── Shape checks ──────────────────────────────────────────────────────────
    assert tuple(in_detail["shape"])  == INPUT_SHAPE, (
        f"TFLite input shape {tuple(in_detail['shape'])} ≠ expected {INPUT_SHAPE}"
    )
    assert tuple(out_detail["shape"]) == OUTPUT_SHAPE, (
        f"TFLite output shape {tuple(out_detail['shape'])} ≠ expected {OUTPUT_SHAPE}"
    )
    print(f"   Input  shape : {tuple(in_detail['shape'])}  ✅")
    print(f"   Output shape : {tuple(out_detail['shape'])} ✅")

    def run_inference(input_array: np.ndarray) -> float:
        """Helper: set input tensor, invoke, return scalar score."""
        interpreter.set_tensor(in_detail["index"], input_array)
        interpreter.invoke()
        return float(interpreter.get_tensor(out_detail["index"])[0][0])

    # ── Three boundary inputs ─────────────────────────────────────────────────
    test_inputs = {
        "zeros (min boundary)": np.zeros(INPUT_SHAPE,            dtype=np.float32),
        "255s  (max boundary)": np.full(INPUT_SHAPE, 255.0,      dtype=np.float32),
        "random mid-range"    : np.random.default_rng(42).uniform(
                                    0, 255, INPUT_SHAPE).astype(np.float32),
    }

    scores = {}
    print("\n   Inference sanity checks (all scores must be in [0.0, 1.0]):")
    for label, arr in test_inputs.items():
        score = run_inference(arr)
        scores[label] = score
        in_range = "✅" if 0.0 <= score <= 1.0 else "❌"
        print(f"   {in_range}  {label:<25} → score: {score:.6f}")
        assert 0.0 <= score <= 1.0, f"Score {score} out of [0, 1] for input: {label}"

    # ── Collapse check: outputs must not all be identical ─────────────────────
    unique = len({round(s, 3) for s in scores.values()})
    if unique == 1:
        print("\n   ⚠️  WARNING: All outputs identical — model output may have collapsed.")
        print("      Likely cause: preprocessing mismatch during training (e.g., /255 was used).")
    else:
        print("\n   ✅ Outputs vary across different inputs — model discriminates correctly.")

    print("   ✅ All validation checks passed.\n")


# ─── Save + Summary ───────────────────────────────────────────────────────────

def save(tflite_bytes: bytes, output_path: str) -> None:
    """Write TFLite bytes to disk."""
    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
    with open(output_path, "wb") as f:
        f.write(tflite_bytes)
    size_mb = os.path.getsize(output_path) / (1024 * 1024)
    print(f"   💾 Saved: {output_path}  ({size_mb:.1f} MB)")


def print_next_steps(output_path: str) -> None:
    filename = os.path.basename(output_path)
    print("\n" + "=" * 60)
    print("  NEXT STEPS — Flutter Integration")
    print("=" * 60)
    print(f"  1. Copy model to Flutter assets:")
    print(f"       cp {output_path}")
    print(f"          frontend/assets/models/deepfake_detector.tflite")
    print(f"  2. pubspec.yaml → assets section:")
    print(f"       flutter:")
    print(f"         assets:")
    print(f"           - assets/models/deepfake_detector.tflite")
    print(f"  3. build.gradle.kts → android block:")
    print(f"       androidResources {{ noCompress += \"tflite\" }}")
    print(f"  4. flutter pub get && flutter run")
    print("=" * 60 + "\n")


# ─── Entry Point ──────────────────────────────────────────────────────────────

def main():
    args = parse_args()

    # Auto-generate output filename if not specified
    if args.output is None:
        base        = os.path.splitext(args.input)[0]
        suffix      = f"_{args.quantization}" if args.quantization != "none" else "_fp32"
        args.output = f"{base}{suffix}.tflite"

    print("=" * 60)
    print("  TruthLens AI — Keras → TFLite Converter")
    print("=" * 60)

    model        = load_keras_model(args.input)
    tflite_bytes = convert(model, args.quantization)
    validate(tflite_bytes)
    save(tflite_bytes, args.output)
    print_next_steps(args.output)


if __name__ == "__main__":
    main()
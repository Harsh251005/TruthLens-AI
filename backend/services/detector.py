# services/detector.py
# ============================================================
# Deepfake detection service — uses TFLite runtime instead of
# full TensorFlow to keep memory usage within Render's free tier.
#
# On first startup, downloads the .tflite model from Hugging Face
# and caches it locally. Subsequent restarts reuse the cached file.
# ============================================================

import os
import numpy as np
import cv2
from PIL import Image
import io
import tflite_runtime.interpreter as tflite
from huggingface_hub import hf_hub_download

from services.exif_service import analyze_exif
from services.llm_service  import generate_explanation


# ─── Constants ────────────────────────────────────────────────────────────────

IMAGE_SIZE     = (224, 224)   # Must match training config exactly
FAKE_THRESHOLD = 0.5          # Raw score > 0.5 → FAKE
MODEL_FILENAME = "deepfake_detector_fp16.tflite"
LOCAL_MODEL_PATH = "deepfake_detector_fp16.tflite"


# ─── Model Download ───────────────────────────────────────────────────────────

def _download_model() -> str:
    """
    Download .tflite model from Hugging Face if not already cached locally.
    Returns the local path to the model file.
    """
    # Use cached file if it already exists (avoids re-downloading on restart)
    if os.path.exists(LOCAL_MODEL_PATH):
        print(f"Model already cached at: {LOCAL_MODEL_PATH}")
        return LOCAL_MODEL_PATH

    hf_token = os.getenv("HF_TOKEN")
    hf_repo  = os.getenv("HF_MODEL_REPO")

    if not hf_token or not hf_repo:
        raise EnvironmentError(
            "HF_TOKEN and HF_MODEL_REPO environment variables must be set."
        )

    print(f"Downloading model from Hugging Face: {hf_repo}")
    path = hf_hub_download(
        repo_id=hf_repo,
        filename=MODEL_FILENAME,
        token=hf_token,
        local_dir=".",        # Download to current working directory
    )
    print(f"Model downloaded to: {path}")
    return path


# ─── Model Loading ────────────────────────────────────────────────────────────

print("Initializing deepfake detection model...")
_model_path = _download_model()

# Load TFLite interpreter (lightweight — no full TensorFlow needed)
_interpreter = tflite.Interpreter(model_path=_model_path)
_interpreter.allocate_tensors()

_input_details  = _interpreter.get_input_details()
_output_details = _interpreter.get_output_details()

print(f"Input  shape: {_input_details[0]['shape']}")
print(f"Output shape: {_output_details[0]['shape']}")


# ─── Face Detection ───────────────────────────────────────────────────────────

_face_cascade = cv2.CascadeClassifier(
    cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
)

def detect_face(image_bytes: bytes) -> bool:
    """Returns True if at least one human face is detected in the image."""
    np_arr = np.frombuffer(image_bytes, np.uint8)
    img    = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
    if img is None:
        return False
    gray  = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    faces = _face_cascade.detectMultiScale(
        gray, scaleFactor=1.1, minNeighbors=5, minSize=(30, 30)
    )
    return len(faces) > 0


# ─── Preprocessing ────────────────────────────────────────────────────────────

def preprocess_image(image_bytes: bytes) -> np.ndarray:
    """
    Resize image to 224x224 and return raw float32 pixel values.

    CRITICAL: No /255 normalization.
    EfficientNetB0 has built-in Rescaling — expects raw [0, 255] input.
    Dividing by 255 causes the model to always predict REAL.
    """
    img       = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    img       = img.resize(IMAGE_SIZE)
    img_array = np.array(img, dtype=np.float32)        # Raw [0, 255] — NO /255
    img_array = np.expand_dims(img_array, axis=0)      # (1, 224, 224, 3)
    return img_array


# ─── Inference ────────────────────────────────────────────────────────────────

def _run_inference(img_array: np.ndarray) -> float:
    """Run TFLite inference and return raw sigmoid score."""
    _interpreter.set_tensor(_input_details[0]["index"], img_array)
    _interpreter.invoke()
    return float(_interpreter.get_tensor(_output_details[0]["index"])[0][0])


# ─── Main Predict ─────────────────────────────────────────────────────────────

def predict(image_bytes: bytes) -> dict:
    """
    Full deepfake detection pipeline:
      1. Face check
      2. TFLite inference
      3. EXIF analysis
      4. LLM explanation
    """
    # ── Step 1: Face check ────────────────────────────────────────────────────
    if not detect_face(image_bytes):
        raise ValueError("No human face detected. Please upload a clear face photo.")

    # ── Step 2: Model inference ───────────────────────────────────────────────
    img_array = preprocess_image(image_bytes)
    raw_score = _run_inference(img_array)

    is_fake    = raw_score > FAKE_THRESHOLD
    verdict    = "FAKE" if is_fake else "REAL"
    confidence = round(raw_score * 100 if is_fake else (1 - raw_score) * 100, 2)

    # ── Step 3: EXIF analysis ─────────────────────────────────────────────────
    try:
        exif_result = analyze_exif(image_bytes)
    except Exception:
        exif_result = {
            "raw_fields":      {},
            "suspicion_flags": ["EXIF analysis unavailable"],
            "risk_level":      "UNKNOWN",
            "summary":         "EXIF analysis could not be completed.",
            "has_exif":        False,
        }

    # ── Step 4: LLM explanation ───────────────────────────────────────────────
    try:
        explanation = generate_explanation(
            verdict=verdict, confidence=confidence, raw_score=raw_score,
            suspicious_regions=[], exif_summary=exif_result["summary"],
            exif_flags=exif_result["suspicion_flags"],
            exif_risk=exif_result["risk_level"],
        )
    except Exception:
        explanation = (
            f"This image has been classified as {verdict} "
            f"with {confidence}% confidence."
        )

    # ── Step 5: Tips ──────────────────────────────────────────────────────────
    if is_fake:
        message = f"This image appears to be AI-generated. Model is {confidence}% confident."
        tips = [
            "Look for unnatural blurring around face edges",
            "Check for inconsistent lighting or shadows",
            "Look for asymmetry in facial features",
            "Examine the hair and teeth for artifacts",
            "Be cautious sharing or trusting this image",
        ]
    else:
        message = f"This image appears authentic. Model is {confidence}% confident."
        tips = [
            "Natural skin texture and pores are visible",
            "Lighting and shadows appear consistent",
            "Facial features appear symmetrical and natural",
            "No visible artifacts or blurring detected",
            "Always verify from original trusted sources",
        ]

    return {
        "verdict":       verdict,
        "confidence":    confidence,
        "raw_score":     round(raw_score, 4),
        "message":       message,
        "tips":          tips,
        "explanation":   explanation,
        "exif_analysis": exif_result,
    }

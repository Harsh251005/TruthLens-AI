# services/detector.py
# ============================================================
# Main deepfake detection orchestrator.
# Coordinates all analysis services:
#   1. Face detection  (OpenCV)
#   2. Model inference (EfficientNetB0)
#   3. EXIF analysis   (exif_service)
#   4. LLM explanation (llm_service)
# ============================================================

import os
import numpy as np
import tensorflow as tf
import cv2
from PIL import Image
import io

from services.exif_service import analyze_exif
from services.llm_service  import generate_explanation

# ── Load Model Once at Startup ────────────────────────────────────
print("🔄 Loading deepfake detection model...")

if os.path.exists("deepfake_detector.keras"):
    model = tf.keras.models.load_model("deepfake_detector.keras")
    print("✅ Loaded deepfake_detector.keras")
elif os.path.exists("deepfake_detector_best.h5"):
    model = tf.keras.models.load_model("deepfake_detector_best.h5")
    print("✅ Loaded deepfake_detector_best.h5")
else:
    raise FileNotFoundError(
        "❌ No model file found. Add deepfake_detector.keras to backend/"
    )

print(f"   Input shape:  {model.input_shape}")
print(f"   Output shape: {model.output_shape}")

# ── Load Face Detector ────────────────────────────────────────────
print("🔄 Loading face detector...")
face_cascade = cv2.CascadeClassifier(
    cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
)
print("✅ Face detector loaded")

# ── Constants ─────────────────────────────────────────────────────
IMAGE_SIZE     = (224, 224)  # Must match training size exactly
FAKE_THRESHOLD = 0.5         # Score above this → FAKE


def detect_face(image_bytes: bytes) -> bool:
    """
    Checks if the image contains at least one human face.
    Returns True if a face is found, False otherwise.
    """
    np_arr = np.frombuffer(image_bytes, np.uint8)
    img    = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)

    if img is None:
        return False

    gray  = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    faces = face_cascade.detectMultiScale(
        gray,
        scaleFactor  = 1.1,
        minNeighbors = 5,
        minSize      = (30, 30),
    )
    return len(faces) > 0


def preprocess_image(image_bytes: bytes) -> np.ndarray:
    """
    Converts raw image bytes into a model-ready numpy array.

    ⚠️  IMPORTANT — No /255 normalization here.
    EfficientNetB0 has a built-in Rescaling layer that expects
    raw pixel values in [0, 255]. Dividing by 255 first would
    produce [0, 0.004] range causing the model to always predict REAL.
    This must exactly match what ImageDataGenerator did during training
    (no rescale parameter was set there either).
    """
    img       = Image.open(io.BytesIO(image_bytes)).convert("RGB")  # Ensure RGB, not BGR
    img       = img.resize(IMAGE_SIZE)                               # Resize to 224x224
    img_array = np.array(img, dtype=np.float32)                     # Raw [0, 255] — NO /255
    img_array = np.expand_dims(img_array, axis=0)                   # Add batch dim → (1, 224, 224, 3)
    return img_array


def predict(image_bytes: bytes) -> dict:
    """
    Full detection pipeline:
      1. Face validation
      2. Model inference
      3. EXIF metadata analysis
      4. LLM explanation generation
      5. Return rich result dict
    """

    # ── Step 1: Validate face presence ───────────────────────────
    if not detect_face(image_bytes):
        raise ValueError(
            "No human face detected. Please upload a clear face photo."
        )

    # ── Step 2: Model inference ───────────────────────────────────
    img_array = preprocess_image(image_bytes)
    output    = model.predict(img_array, verbose=0)
    raw_score = float(output[0][0])

    is_fake    = raw_score > FAKE_THRESHOLD
    verdict    = "FAKE" if is_fake else "REAL"
    confidence = round(
        raw_score * 100 if is_fake else (1 - raw_score) * 100, 2
    )

    # ── Step 3: EXIF analysis ─────────────────────────────────────
    print("🔄 Analyzing EXIF metadata...")
    try:
        exif_result = analyze_exif(image_bytes)
        print(f"✅ EXIF risk level: {exif_result['risk_level']}")
    except Exception as e:
        print(f"⚠️  EXIF analysis failed: {e}")
        exif_result = {
            "raw_fields":      {},
            "suspicion_flags": ["EXIF analysis unavailable"],
            "risk_level":      "UNKNOWN",
            "summary":         "EXIF analysis could not be completed.",
            "has_exif":        False,
        }

    # ── Step 4: LLM explanation ───────────────────────────────────
    print("🔄 Generating LLM explanation...")
    try:
        explanation = generate_explanation(
            verdict            = verdict,
            confidence         = confidence,
            raw_score          = raw_score,
            suspicious_regions = [],
            exif_summary       = exif_result["summary"],
            exif_flags         = exif_result["suspicion_flags"],
            exif_risk          = exif_result["risk_level"],
        )
        print("✅ Explanation generated")
    except Exception as e:
        print(f"⚠️  LLM explanation failed: {e}")
        explanation = (
            f"This image has been classified as {verdict} "
            f"with {confidence}% confidence."
        )

    # ── Step 5: Build tips list ───────────────────────────────────
    if is_fake:
        message = (
            f"This image appears to be AI-generated or manipulated. "
            f"Our model is {confidence}% confident this is a deepfake."
        )
        tips = [
            "Look for unnatural blurring around face edges",
            "Check for inconsistent lighting or shadows",
            "Look for asymmetry in facial features",
            "Examine the hair and teeth for artifacts",
            "Be cautious sharing or trusting this image",
        ]
    else:
        message = (
            f"This image appears to be authentic. "
            f"Our model is {confidence}% confident this is a real face."
        )
        tips = [
            "Natural skin texture and pores are visible",
            "Lighting and shadows appear consistent",
            "Facial features appear symmetrical and natural",
            "No visible artifacts or blurring detected",
            "Always verify from original trusted sources",
        ]

    # ── Step 6: Return full result ────────────────────────────────
    return {
        "verdict":       verdict,
        "confidence":    confidence,
        "raw_score":     round(raw_score, 4),
        "message":       message,
        "tips":          tips,
        "explanation":   explanation,
        "exif_analysis": exif_result,
    }
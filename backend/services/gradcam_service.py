# services/gradcam_service.py
# ============================================================
# Generates Grad-CAM heatmap overlays showing which facial
# regions Axiom focused on when making its decision.
#
# Uses lazy-loaded Keras model — only loaded when requested.
# Normal scans continue using the lightweight TFLite model.
# ============================================================

import numpy as np
import cv2
import tensorflow as tf
from PIL import Image
import io
import base64
import os
import psutil

# ── Constants ──────────────────────────────────────────────────────
IMAGE_SIZE       = (224, 224)
KERAS_MODEL_PATH = "deepfake_detector.keras"

# ── Lazy-loaded Keras model ────────────────────────────────────────
# Not loaded at startup — only when Grad-CAM is first requested
# This keeps normal scan memory footprint small on Render free tier
_keras_model = None


def _get_keras_model():
    global _keras_model
    if _keras_model is None:
        # ── Download from Hugging Face if not cached ───────────
        if not os.path.exists(KERAS_MODEL_PATH):
            from huggingface_hub import hf_hub_download
            print("Downloading Keras model for Grad-CAM...")
            hf_hub_download(
                repo_id   = os.getenv("HF_MODEL_REPO"),
                filename  = "deepfake_detector.keras",
                token     = os.getenv("HF_TOKEN"),
                local_dir = ".",
            )
            print("✅ Keras model downloaded.")

        print("Loading Keras model for Grad-CAM...")
        _keras_model = tf.keras.models.load_model(KERAS_MODEL_PATH)
        print("✅ Keras model loaded for Grad-CAM.")
    return _keras_model


def generate_gradcam(image_bytes: bytes) -> str:
    """
    Generates a Grad-CAM heatmap for the given face image.

    Steps:
      1. Preprocess image to 224x224
      2. Find last convolutional layer in EfficientNetB0
      3. Compute gradients of fake score w.r.t. that layer
      4. Weight feature maps by gradient importance
      5. Resize heatmap to original image dimensions
      6. Overlay on original image with jet colormap
      7. Return as base64-encoded PNG string

    Returns:
        Base64-encoded PNG string of heatmap overlay
    """

    available_mb = psutil.virtual_memory().available / 1024 / 1024
    if available_mb < 300:
        raise MemoryError(
            "Not enough memory available for Grad-CAM on free tier."
        )

    model = _get_keras_model()

    # ── Step 1: Preprocess ─────────────────────────────────────────
    img_pil     = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    orig_w, orig_h = img_pil.size
    img_resized = img_pil.resize(IMAGE_SIZE)
    img_array   = np.array(img_resized, dtype=np.float32)
    img_batch   = np.expand_dims(img_array, axis=0)   # (1, 224, 224, 3)

    # ── Step 2: Find last conv layer inside EfficientNetB0 ─────────
    # EfficientNetB0 is a sub-model sitting at model.layers[1]
    # We need the last layer that outputs a 4D tensor (batch, h, w, c)
    efficientnet = None
    for layer in model.layers:
        if isinstance(layer, tf.keras.Model):
            efficientnet = layer
            break

    if efficientnet is None:
        raise ValueError(
            "Could not find EfficientNetB0 sub-model inside Keras model."
        )

    last_conv_layer_name = None
    for layer in reversed(efficientnet.layers):
        if len(layer.output_shape) == 4:
            last_conv_layer_name = layer.name
            break

    if last_conv_layer_name is None:
        raise ValueError(
            "Could not find a convolutional layer for Grad-CAM."
        )

    # ── Step 3: Build Grad-CAM model ───────────────────────────────
    # Outputs: [last conv layer activations, final sigmoid prediction]
    grad_model = tf.keras.Model(
        inputs  = model.inputs,
        outputs = [
            efficientnet.get_layer(last_conv_layer_name).output,
            model.output,
        ]
    )

    # ── Step 4: Compute gradients ──────────────────────────────────
    with tf.GradientTape() as tape:
        conv_outputs, predictions = grad_model(img_batch)
        # Gradient of the fake class score w.r.t conv feature maps
        fake_score = predictions[:, 0]

    grads = tape.gradient(fake_score, conv_outputs)

    # ── Step 5: Pool + weight feature maps ────────────────────────
    # Average gradient importance across spatial dimensions
    pooled_grads = tf.reduce_mean(grads, axis=(0, 1, 2))

    # Weight each feature map channel by its gradient importance
    conv_outputs = conv_outputs[0]   # Remove batch dimension
    heatmap      = conv_outputs @ pooled_grads[..., tf.newaxis]
    heatmap      = tf.squeeze(heatmap)

    # ReLU — only keep positive activations (regions that push toward FAKE)
    heatmap = tf.maximum(heatmap, 0)

    # Normalize to [0, 1]
    max_val = tf.math.reduce_max(heatmap)
    if max_val > 0:
        heatmap = heatmap / max_val
    heatmap = heatmap.numpy()

    # ── Step 6: Resize to original image dimensions ────────────────
    heatmap_resized = cv2.resize(heatmap, (orig_w, orig_h))

    # ── Step 7: Apply jet colormap ─────────────────────────────────
    # Blue  = low activation (Axiom didn't focus here)
    # Green = medium activation
    # Red   = high activation (Axiom focused here most)
    heatmap_uint8   = np.uint8(255 * heatmap_resized)
    heatmap_colored = cv2.applyColorMap(heatmap_uint8, cv2.COLORMAP_JET)
    heatmap_colored = cv2.cvtColor(heatmap_colored, cv2.COLOR_BGR2RGB)

    # ── Step 8: Overlay on original image ──────────────────────────
    # 55% original + 45% heatmap — keeps face visible under overlay
    orig_array = np.array(img_pil)
    overlay    = cv2.addWeighted(
        orig_array,      0.55,
        heatmap_colored, 0.45,
        0
    )

    # ── Step 9: Encode as base64 PNG ───────────────────────────────
    result_pil = Image.fromarray(overlay)
    buffer     = io.BytesIO()
    result_pil.save(buffer, format="PNG")
    buffer.seek(0)
    return base64.b64encode(buffer.read()).decode("utf-8")
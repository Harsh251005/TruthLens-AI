# services/llm_service.py
# ============================================================
# Generates a human-like explanation of deepfake detection
# results using Groq API (Llama 3.3 70B).
#
# Groq is used because:
#   - Generous free tier with no credit card required
#   - Very fast inference (tokens/sec much higher than others)
#   - Llama 3.3 70B produces natural, varied explanations
# ============================================================

import os
from groq import Groq
from dotenv import load_dotenv

load_dotenv()

# ── Initialize Groq client ────────────────────────────────────────
GROQ_API_KEY = os.getenv("GROQ_API_KEY")

if GROQ_API_KEY:
    client = Groq(api_key=GROQ_API_KEY)
    print("✅ Groq client initialized")
else:
    client = None
    print("⚠️  GROQ_API_KEY not set — LLM explanations will use fallback")

# ── Model to use ──────────────────────────────────────────────────
GROQ_MODEL = "llama-3.3-70b-versatile"


def generate_explanation(
    verdict: str,
    confidence: float,
    raw_score: float,
    suspicious_regions: list[str],
    exif_summary: str,
    exif_flags: list[str],
    exif_risk: str,
) -> str:
    """
    Generates a natural language explanation of the deepfake analysis.

    Args:
        verdict:            'REAL' or 'FAKE'
        confidence:         Confidence percentage e.g. 94.5
        raw_score:          Raw model output 0.0 to 1.0
        suspicious_regions: Facial regions flagged by visual analysis
        exif_summary:       One-paragraph EXIF analysis summary
        exif_flags:         List of suspicious EXIF findings
        exif_risk:          'LOW', 'MEDIUM', or 'HIGH'

    Returns:
        A human-readable explanation string (2-3 paragraphs)
    """

    if not client:
        return _fallback_explanation(verdict, confidence)

    try:
        prompt = _build_prompt(
            verdict, confidence, raw_score,
            suspicious_regions, exif_summary,
            exif_flags, exif_risk
        )

        # Call Groq API with Llama 3.3 70B
        response = client.chat.completions.create(
            model    = GROQ_MODEL,
            messages = [
                {
                    "role":    "system",
                    "content": (
                        "You are TruthLens AI, an expert deepfake detection "
                        "assistant. You explain complex AI analysis results in "
                        "simple, friendly, and informative language. You always "
                        "vary your explanations based on the specific data "
                        "provided — never give generic responses."
                    ),
                },
                {
                    "role":    "user",
                    "content": prompt,
                },
            ],
            temperature = 0.7,   # Higher = more varied responses
            max_tokens  = 350,   # Enough for 2-3 solid paragraphs
        )

        return response.choices[0].message.content.strip()

    except Exception as e:
        print(f"⚠️  Groq API error: {e}")
        return _fallback_explanation(verdict, confidence)


def _build_prompt(
    verdict: str,
    confidence: float,
    raw_score: float,
    suspicious_regions: list[str],
    exif_summary: str,
    exif_flags: list[str],
    exif_risk: str,
) -> str:
    """
    Builds a detailed prompt with all detection signals so the
    LLM can generate a specific, varied explanation each time.
    """

    regions_str    = ", ".join(suspicious_regions) if suspicious_regions \
                     else "no specific regions isolated"
    exif_flags_str = "; ".join(exif_flags) if exif_flags else "none"

    # Translate raw score to a descriptive signal strength
    if raw_score > 0.90:
        signal = "extremely strong — the model is nearly certain"
    elif raw_score > 0.75:
        signal = "strong — the model detected clear manipulation patterns"
    elif raw_score > 0.55:
        signal = "moderate — some suspicious patterns were detected"
    elif raw_score > 0.45:
        signal = "borderline — the image is in an uncertain zone"
    elif raw_score > 0.25:
        signal = "weak — image appears mostly authentic"
    else:
        signal = "very weak — the model sees strong signs of authenticity"

    return f"""Analyze these deepfake detection results and write a specific, 
personalized explanation for this exact image. Do NOT give a generic response.

=== DETECTION DATA ===
Verdict:         {verdict}
Confidence:      {confidence}%
Raw model score: {raw_score:.4f} (0.0=definitely real, 1.0=definitely fake)
Signal strength: {signal}
Suspicious facial regions: {regions_str}

=== EXIF METADATA ===
{exif_summary}
Suspicious flags: {exif_flags_str}
EXIF risk level:  {exif_risk}

=== WRITING INSTRUCTIONS ===
- Write exactly 2-3 short paragraphs in flowing prose (NO bullet points)
- Paragraph 1: State the verdict clearly, mention the exact confidence score
  and what the signal strength means for THIS specific image
- Paragraph 2: Explain the specific EXIF findings for THIS image and what
  they suggest about its origin
- Paragraph 3: Give practical advice tailored to this specific result
- Use simple language — no technical jargon, no model names
- Be specific to the data above — vary your language based on the numbers
- Keep total response under 200 words
- Sound like a knowledgeable friend, not a robot

Write the explanation now:"""


def _fallback_explanation(verdict: str, confidence: float) -> str:
    """
    Rule-based fallback when Groq API is unavailable.
    Uses confidence ranges to vary the response.
    """
    if verdict == "FAKE":
        if confidence > 90:
            return (
                f"This image shows very strong signs of being AI-generated or "
                f"digitally manipulated. With {confidence:.1f}% confidence, our "
                f"model detected clear patterns that are characteristic of deepfake "
                f"technology. We strongly recommend not sharing or trusting this image "
                f"without independent verification from a trusted source."
            )
        else:
            return (
                f"This image appears to have been manipulated or AI-generated, "
                f"with {confidence:.1f}% confidence. While the signal is not "
                f"overwhelming, there are enough suspicious patterns to warrant "
                f"caution. Consider verifying this image through other means before "
                f"sharing or acting on it."
            )
    else:
        if confidence > 90:
            return (
                f"This image appears to be authentic with high confidence "
                f"({confidence:.1f}%). Our model found strong indicators of a "
                f"genuine photograph with no significant signs of AI manipulation. "
                f"That said, no detection system is perfect — always use multiple "
                f"verification methods for critical decisions."
            )
        else:
            return (
                f"This image appears to be real, with {confidence:.1f}% confidence. "
                f"While our model leans toward authenticity, the confidence level "
                f"suggests some uncertainty. We recommend treating this result as "
                f"one data point and verifying through additional means if the "
                f"image is important."
            )
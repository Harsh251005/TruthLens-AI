# services/llm_service.py

import os
from groq import Groq
from dotenv import load_dotenv

load_dotenv()

GROQ_API_KEY = os.getenv("GROQ_API_KEY")

if GROQ_API_KEY:
    client = Groq(api_key=GROQ_API_KEY)
    print("✅ Groq client initialized")
else:
    client = None
    print("⚠️  GROQ_API_KEY not set — LLM explanations will use fallback")

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

    if not client:
        return _fallback_explanation(verdict, confidence)

    try:
        prompt = _build_prompt(
            verdict, confidence, raw_score,
            exif_flags, exif_risk
        )

        response = client.chat.completions.create(
            model    = GROQ_MODEL,
            messages = [
                {
                    "role":    "system",
                    "content": (
                        "You are a digital forensics expert who has spent years "
                        "analysing manipulated images. You speak directly, plainly "
                        "and honestly — like you're telling a friend what you found. "
                        "You never use corporate language, bullet points, or "
                        "structured formatting. You never say 'I' or refer to "
                        "yourself. You never mention model names or technical "
                        "systems. You just describe what the image shows and "
                        "what it means. Keep it under 3 sentences. Sound human."
                    ),
                },
                {
                    "role":    "user",
                    "content": prompt,
                },
            ],
            temperature = 0.4,
            max_tokens  = 180,
        )

        return response.choices[0].message.content.strip()

    except Exception as e:
        print(f"⚠️  Groq API error: {e}")
        return _fallback_explanation(verdict, confidence)


def _build_prompt(
    verdict: str,
    confidence: float,
    raw_score: float,
    exif_flags: list[str],
    exif_risk: str,
) -> str:

    # Translate raw score into plain language signal
    if raw_score > 0.92:
        signal = "almost certainly manipulated"
    elif raw_score > 0.78:
        signal = "clearly shows signs of manipulation"
    elif raw_score > 0.62:
        signal = "has some suspicious patterns worth noting"
    elif raw_score > 0.50:
        signal = "is borderline — slightly leans toward being fake"
    elif raw_score > 0.35:
        signal = "is borderline — slightly leans toward being real"
    elif raw_score > 0.18:
        signal = "looks mostly authentic"
    else:
        signal = "looks very authentic with no obvious manipulation signs"

    # Build EXIF context naturally
    exif_context = ""
    if exif_flags and exif_risk in ("HIGH", "MEDIUM"):
        exif_context = (
            f"The metadata also raised some flags: "
            f"{'; '.join(exif_flags[:2])}."
        )
    elif exif_risk == "LOW":
        exif_context = "The metadata looks consistent with a genuine photo."

    return (
        f"This face photo {signal}. "
        f"The confidence is {confidence:.1f}%. "
        f"{exif_context} "
        f"In 2-3 short plain sentences, tell the user what this means "
        f"and what they should do — no formatting, no lists, just talk."
    )


def _fallback_explanation(verdict: str, confidence: float) -> str:
    """
    Fallback when Groq is unavailable.
    Written to sound natural, not templated.
    """
    if verdict == "FAKE":
        if confidence > 90:
            return (
                f"This one is almost certainly not a real photo — the patterns "
                f"here are very consistent with AI-generated faces. "
                f"At {confidence:.0f}% confidence, treat this image with serious "
                f"scepticism and don't share it as if it were real."
            )
        elif confidence > 70:
            return (
                f"There are clear signs this image has been manipulated or "
                f"generated, with {confidence:.0f}% confidence. "
                f"It's worth verifying the source before trusting or sharing it."
            )
        else:
            return (
                f"Something about this image doesn't quite add up, though the "
                f"signal isn't strong enough to be certain. "
                f"Treat it with caution and verify the source if it matters."
            )
    else:
        if confidence > 90:
            return (
                f"This looks like a genuine photo — nothing here suggests "
                f"manipulation at {confidence:.0f}% confidence. "
                f"That said, no analysis is perfect, so use your own judgement too."
            )
        elif confidence > 70:
            return (
                f"This image appears real, with {confidence:.0f}% confidence. "
                f"There are no strong red flags, though the reading isn't "
                f"completely decisive."
            )
        else:
            return (
                f"This image leans toward being authentic but the confidence "
                f"is low enough that you shouldn't rely solely on this result. "
                f"Worth a second look if the image is important."
            )

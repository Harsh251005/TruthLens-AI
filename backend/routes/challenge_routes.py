# routes/challenge_routes.py
# ============================================================
# Challenge Mode endpoints:
#   GET /api/challenge/round  → returns 10 random images
#                               (mix of real + fake) for one
#                               game session
# ============================================================

import os
import random
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from typing import List
from middleware.auth_middleware import get_current_user

router = APIRouter()

# ── Paths to challenge image folders ─────────────────────────────
BASE_DIR   = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REAL_DIR   = os.path.join(BASE_DIR, "static", "challenge", "real")
FAKE_DIR   = os.path.join(BASE_DIR, "static", "challenge", "fake")

# Supported image extensions
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp"}

# Number of images per game round
ROUND_SIZE = 10


# ── Response schema ───────────────────────────────────────────────
class ChallengeImage(BaseModel):
    """Single challenge image — answer hidden until user guesses."""
    index:    int     # Position in the round (0-9)
    url:      str     # Full URL to fetch the image
    answer:   str     # 'REAL' or 'FAKE' — revealed after guess


class ChallengeRoundResponse(BaseModel):
    """10 shuffled images for one game round."""
    images:      List[ChallengeImage]
    total:       int   # Always 10
    real_count:  int   # How many are real in this round
    fake_count:  int   # How many are fake in this round


# ── Helper: scan folder for images ───────────────────────────────
def _get_images(folder: str) -> List[str]:
    """Returns list of filenames in a folder that are images."""
    if not os.path.exists(folder):
        return []
    return [
        f for f in os.listdir(folder)
        if os.path.splitext(f)[1].lower() in IMAGE_EXTS
    ]


# ── GET /api/challenge/round ──────────────────────────────────────
@router.get("/round", response_model=ChallengeRoundResponse)
def get_challenge_round(
    request: Request,
    user_id: int = Depends(get_current_user),
):
    """
    Returns 10 randomly selected images for a challenge round.
    Split is roughly 50/50 real/fake but randomised each time.
    The answer field is included so Flutter can check guesses
    locally — no second API call needed per guess.
    """
    from fastapi import Request

    real_files = _get_images(REAL_DIR)
    fake_files = _get_images(FAKE_DIR)

    if len(real_files) < 5 or len(fake_files) < 5:
        raise HTTPException(
            status_code=503,
            detail="Not enough challenge images available. "
                   "Please add images to static/challenge/real and fake folders."
        )

    # Pick random split: either 5/5 or 4/6 or 6/4
    real_count = random.randint(4, 6)
    fake_count = ROUND_SIZE - real_count

    # Cap to available images
    real_count = min(real_count, len(real_files))
    fake_count = min(fake_count, len(fake_files))

    selected_real = random.sample(real_files, real_count)
    selected_fake = random.sample(fake_files, fake_count)

    # Build base URL from the incoming request so it works on
    # any host (local dev or Render)
    base_url = str(request.base_url).rstrip("/")

    # Combine and shuffle
    images = []
    for filename in selected_real:
        images.append({
            "url":    f"{base_url}/static/challenge/real/{filename}",
            "answer": "REAL",
        })
    for filename in selected_fake:
        images.append({
            "url":    f"{base_url}/static/challenge/fake/{filename}",
            "answer": "FAKE",
        })

    random.shuffle(images)

    return ChallengeRoundResponse(
        images=[
            ChallengeImage(index=i, url=img["url"], answer=img["answer"])
            for i, img in enumerate(images)
        ],
        total=len(images),
        real_count=real_count,
        fake_count=fake_count,
    )
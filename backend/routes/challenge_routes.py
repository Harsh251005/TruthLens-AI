# routes/challenge_routes.py
# ============================================================
# Challenge Mode endpoints:
#   GET  /api/challenge/round        → 10 random images
#   POST /api/challenge/score        → save score after round
#   GET  /api/challenge/leaderboard  → top 20 + user rank + personal best
# ============================================================

import os
import random
from fastapi import APIRouter, Depends, HTTPException, Request
from typing import List
from pydantic import BaseModel
from middleware.auth_middleware import get_current_user
from models.schemas import (
    SaveScoreRequest, LeaderboardResponse,
    LeaderboardEntry, PersonalBest,
)
from config.database import get_db_connection

router = APIRouter()

# ── Paths ─────────────────────────────────────────────────────────
BASE_DIR   = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REAL_DIR   = os.path.join(BASE_DIR, "static", "challenge", "real")
FAKE_DIR   = os.path.join(BASE_DIR, "static", "challenge", "fake")
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp"}
ROUND_SIZE = 10


# ── Local schemas ─────────────────────────────────────────────────
class ChallengeImage(BaseModel):
    index:  int
    url:    str
    answer: str

class ChallengeRoundResponse(BaseModel):
    images:     List[ChallengeImage]
    total:      int
    real_count: int
    fake_count: int


# ── Helper ────────────────────────────────────────────────────────
def _get_images(folder: str) -> List[str]:
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
    """Returns 10 randomly selected images for a challenge round."""
    real_files = _get_images(REAL_DIR)
    fake_files = _get_images(FAKE_DIR)

    if len(real_files) < 5 or len(fake_files) < 5:
        raise HTTPException(
            status_code=503,
            detail="Not enough challenge images available."
        )

    real_count = random.randint(4, 6)
    fake_count = ROUND_SIZE - real_count
    real_count = min(real_count, len(real_files))
    fake_count = min(fake_count, len(fake_files))

    selected_real = random.sample(real_files, real_count)
    selected_fake = random.sample(fake_files, fake_count)

    base_url = str(request.base_url).rstrip("/")

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
        total      = len(images),
        real_count = real_count,
        fake_count = fake_count,
    )


# ── POST /api/challenge/score ─────────────────────────────────────
@router.post("/score")
def save_score(
    data:    SaveScoreRequest,
    user_id: int = Depends(get_current_user),
):
    """
    Saves score only if it beats the user's existing best.
    Each user has at most one row in challenge_scores.
    """
    conn   = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        # Check existing best score
        cursor.execute(
            "SELECT id, score FROM challenge_scores "
            "WHERE user_id = %s ORDER BY score DESC LIMIT 1",
            (user_id,)
        )
        existing = cursor.fetchone()

        if existing is None:
            # First score ever — insert
            cursor.execute(
                """INSERT INTO challenge_scores
                   (user_id, score, total, accuracy, max_combo, grade)
                   VALUES (%s, %s, %s, %s, %s, %s)""",
                (user_id, data.score, data.total,
                 data.accuracy, data.max_combo, data.grade)
            )
            conn.commit()
            return {"message": "Score saved", "is_best": True}

        elif data.score > existing["score"]:
            # New best — update existing row
            cursor.execute(
                """UPDATE challenge_scores
                   SET score = %s, total = %s, accuracy = %s,
                       max_combo = %s, grade = %s,
                       played_at = CURRENT_TIMESTAMP
                   WHERE id = %s""",
                (data.score, data.total, data.accuracy,
                 data.max_combo, data.grade, existing["id"])
            )
            conn.commit()
            return {"message": "New best score saved!", "is_best": True}

        else:
            # Not a new best — don't save
            return {"message": "Score not a new best", "is_best": False}

    except Exception as e:
        conn.rollback()
        raise HTTPException(
            status_code=500, detail=f"Server error: {str(e)}")
    finally:
        cursor.close()
        conn.close()


# ── GET /api/challenge/leaderboard ───────────────────────────────
@router.get("/leaderboard", response_model=LeaderboardResponse)
def get_leaderboard(
    user_id: int = Depends(get_current_user),
    period:  str = "all-time",
):
    """
    Returns:
      - Top 20 players by best score
      - Current user's rank (even if outside top 20)
      - Current user's personal best
    Period: 'alltime' or 'weekly' (last 7 days)
    """
    conn   = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        # ── Date filter for weekly ────────────────────────────
        date_filter = ""
        if period == "weekly":
            date_filter = "AND cs.played_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)"

        # ── Top 20 — best score per user ──────────────────────
        # AFTER — one row per user, picks their best score row:
        cursor.execute(f"""
            SELECT
                u.id            AS user_id,
                u.name          AS name,
                u.avatar_type   AS avatar_type,
                u.avatar_data   AS avatar_data,
                cs.score        AS score,
                cs.total        AS total,
                cs.accuracy     AS accuracy,
                cs.max_combo    AS max_combo,
                cs.grade        AS grade,
                cs.played_at    AS played_at
            FROM challenge_scores cs
            JOIN users u ON cs.user_id = u.id
            WHERE cs.id = (
                SELECT id FROM challenge_scores cs2
                WHERE cs2.user_id = u.id
                {date_filter.replace('cs.', 'cs2.')}
                ORDER BY score DESC LIMIT 1
            )
            ORDER BY cs.score DESC, cs.accuracy DESC
            LIMIT 20
        """)
        top_rows = cursor.fetchall()

        entries       = []
        user_in_top20 = False

        for rank, row in enumerate(top_rows, start=1):
            if row["user_id"] == user_id:
                user_in_top20 = True
            entries.append(LeaderboardEntry(
                rank        = rank,
                user_id     = row["user_id"],
                name        = row["name"],
                avatar_type = row.get("avatar_type", "initial"),
                avatar_data = row.get("avatar_data"),
                score       = row["score"],
                total       = row["total"],
                accuracy    = round(float(row["accuracy"]), 1),
                max_combo   = row["max_combo"],
                grade       = row["grade"],
                played_at   = str(row["played_at"]),
            ))

        # ── User's overall rank ───────────────────────────────
        user_rank = None
        if user_in_top20:
            user_rank = next(
                (e.rank for e in entries if e.user_id == user_id),
                None
            )
        else:
            cursor.execute(f"""
                SELECT COUNT(DISTINCT inner_cs.user_id) + 1 AS user_rank
                FROM challenge_scores inner_cs
                WHERE inner_cs.score > (
                    SELECT COALESCE(MAX(cs3.score), 0)
                    FROM challenge_scores cs3
                    WHERE cs3.user_id = %s
                ) {date_filter.replace('cs.', 'inner_cs.')}
            """, (user_id,))
            rank_row = cursor.fetchone()
            if rank_row:
                user_rank = rank_row["user_rank"]

        # ── Personal best ─────────────────────────────────────
        cursor.execute(f"""
            SELECT score, total, accuracy, max_combo, grade, played_at
            FROM challenge_scores
            WHERE user_id = %s
            {date_filter.replace('cs.', '')}
            ORDER BY score DESC, accuracy DESC
            LIMIT 1
        """, (user_id,))
        pb_row = cursor.fetchone()

        personal_best = None
        if pb_row:
            personal_best = PersonalBest(
                score     = pb_row["score"],
                total     = pb_row["total"],
                accuracy  = round(float(pb_row["accuracy"]), 1),
                max_combo = pb_row["max_combo"],
                grade     = pb_row["grade"],
                played_at = str(pb_row["played_at"]),
            )

        # ── Total unique players ──────────────────────────────
        cursor.execute("""
            SELECT COUNT(DISTINCT user_id) AS total_players
            FROM challenge_scores
        """)
        total_row     = cursor.fetchone()
        total_players = total_row["total_players"] if total_row else 0

        return LeaderboardResponse(
            entries       = entries,
            user_rank     = user_rank,
            personal_best = personal_best,
            total_players = total_players,
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")
    finally:
        cursor.close()
        conn.close()
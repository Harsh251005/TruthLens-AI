# routes/badges_routes.py
# ============================================================
# Badge endpoints:
#   GET /api/badges/   → returns all badges (earned + locked)
#                        with progress for the logged-in user
# ============================================================

from fastapi import APIRouter, Depends, HTTPException
from middleware.auth_middleware import get_current_user
from models.schemas import BadgesResponse, BadgeItem
from config.database import get_db_connection

router = APIRouter()


# ── Badge catalogue ───────────────────────────────────────────────
# Single source of truth for all badges.
# 'progress' and 'earned' are computed at runtime from DB data.
BADGE_CATALOGUE = [
    # ── Scan milestone badges ─────────────────────────────────────
    {
        "id":          "first_step",
        "name":        "First Step",
        "description": "Complete your very first scan",
        "emoji":       "🔍",
        "category":    "scans",
        "target":      1,
    },
    {
        "id":          "rookie",
        "name":        "Rookie",
        "description": "Complete 10 scans",
        "emoji":       "🎯",
        "category":    "scans",
        "target":      10,
    },
    {
        "id":          "detective",
        "name":        "Detective",
        "description": "Complete 25 scans",
        "emoji":       "🕵️",
        "category":    "scans",
        "target":      25,
    },
    {
        "id":          "expert",
        "name":        "Expert",
        "description": "Complete 50 scans",
        "emoji":       "⭐",
        "category":    "scans",
        "target":      50,
    },
    {
        "id":          "master",
        "name":        "Master",
        "description": "Complete 100 scans",
        "emoji":       "🏆",
        "category":    "scans",
        "target":      100,
    },
    # ── Fake hunter badges ────────────────────────────────────────
    {
        "id":          "fake_hunter",
        "name":        "Fake Hunter",
        "description": "Catch 5 deepfakes",
        "emoji":       "🎭",
        "category":    "fakes",
        "target":      5,
    },
    {
        "id":          "deepfake_buster",
        "name":        "Deepfake Buster",
        "description": "Catch 20 deepfakes",
        "emoji":       "💥",
        "category":    "fakes",
        "target":      20,
    },
    {
        "id":          "truth_seeker",
        "name":        "Truth Seeker",
        "description": "Verify 10 authentic images",
        "emoji":       "✅",
        "category":    "real",
        "target":      10,
    },
    # ── Streak badges ─────────────────────────────────────────────
    {
        "id":          "on_fire",
        "name":        "On Fire",
        "description": "Scan for 3 consecutive days",
        "emoji":       "🔥",
        "category":    "streak",
        "target":      3,
    },
    {
        "id":          "unstoppable",
        "name":        "Unstoppable",
        "description": "Scan for 7 consecutive days",
        "emoji":       "⚡",
        "category":    "streak",
        "target":      7,
    },
    {
        "id":          "dedicated",
        "name":        "Dedicated",
        "description": "Scan for 14 consecutive days",
        "emoji":       "💎",
        "category":    "streak",
        "target":      14,
    },
    {
        "id":          "legend",
        "name":        "Legend",
        "description": "Scan for 30 consecutive days",
        "emoji":       "👑",
        "category":    "streak",
        "target":      30,
    },
]


# ── GET /api/badges/ ──────────────────────────────────────────────
@router.get("/", response_model=BadgesResponse)
def get_badges(user_id: int = Depends(get_current_user)):

    conn   = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        # ── Fetch user stats ──────────────────────────────────
        cursor.execute(
            """SELECT
                current_streak,
                longest_streak,
                (SELECT COUNT(*) FROM scans WHERE user_id = %s)
                    AS total_scans,
                (SELECT COUNT(*) FROM scans
                    WHERE user_id = %s AND verdict = 'FAKE')
                    AS total_fake,
                (SELECT COUNT(*) FROM scans
                    WHERE user_id = %s AND verdict = 'REAL')
                    AS total_real
               FROM users WHERE id = %s""",
            (user_id, user_id, user_id, user_id)
        )
        row = cursor.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="User not found")

        total_scans     = int(row["total_scans"]     or 0)
        total_fake      = int(row["total_fake"]      or 0)
        total_real      = int(row["total_real"]      or 0)
        current_streak  = int(row["current_streak"]  or 0)
        longest_streak  = int(row["longest_streak"]  or 0)

        # ── Fetch permanently earned badges ───────────────────
        cursor.execute(
            "SELECT badge_id FROM earned_badges WHERE user_id = %s",
            (user_id,)
        )
        permanently_earned = {r["badge_id"] for r in cursor.fetchall()}

        # ── Compute badges + persist newly earned ones ────────
        badges       = []
        new_earnings = []

        for b in BADGE_CATALOGUE:
            category = b["category"]
            target   = b["target"]

            if category == "scans":
                progress = total_scans
            elif category == "fakes":
                progress = total_fake
            elif category == "real":
                progress = total_real
            elif category == "streak":
                # Use longest_streak so badge stays earned after reset
                progress = longest_streak
            else:
                progress = 0

            is_earned = progress >= target or b["id"] in permanently_earned

            # Track newly earned badges to persist
            if is_earned and b["id"] not in permanently_earned:
                new_earnings.append(b["id"])

            badges.append(BadgeItem(
                id          = b["id"],
                name        = b["name"],
                description = b["description"],
                emoji       = b["emoji"],
                earned      = is_earned,
                # Show current_streak for progress bar on streak badges
                progress    = min(
                    current_streak if category == "streak" else progress,
                    target
                ),
                target      = target,
                category    = category,
            ))

        # ── Persist any newly earned badges ───────────────────
        for badge_id in new_earnings:
            try:
                cursor.execute(
                    """INSERT IGNORE INTO earned_badges (user_id, badge_id)
                       VALUES (%s, %s)""",
                    (user_id, badge_id)
                )
            except Exception:
                pass
        conn.commit()

        earned_count = sum(1 for b in badges if b.earned)

        return BadgesResponse(
            badges         = badges,
            earned_count   = earned_count,
            total_count    = len(badges),
            current_streak = current_streak,
            longest_streak = longest_streak,
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")
    finally:
        cursor.close()
        conn.close()
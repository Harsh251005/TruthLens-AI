from fastapi import APIRouter, UploadFile, File, Depends, HTTPException
from middleware.auth_middleware import get_current_user
from models.schemas import (
    DetectionResult, ScanHistoryResponse,
    ScanHistoryItem, StatsResponse
)
from config.database import get_db_connection
from services.detector import predict
from datetime import datetime, timedelta
from models.schemas import AnalyticsResponse, DailyActivity

router = APIRouter()

ALLOWED_TYPES = {"image/jpeg", "image/png", "image/jpg", "image/webp"}


# ── Detect ────────────────────────────────────────────────────────
@router.post("/", response_model=DetectionResult)
async def detect(
    file: UploadFile = File(...),
    user_id: int = Depends(get_current_user),
):
    """
    Accepts an image, runs full deepfake analysis pipeline.
    Also updates the user's scan streak after every successful scan.
    """

    # Validate file type
    if file.content_type not in ALLOWED_TYPES:
        raise HTTPException(status_code=400,
            detail="Invalid file type. Please upload a JPEG or PNG image.")

    image_bytes = await file.read()

    # Validate file size (max 10MB)
    if len(image_bytes) > 10 * 1024 * 1024:
        raise HTTPException(status_code=400,
            detail="Image too large. Please upload an image under 10MB.")

    try:
        # ── Run detection pipeline ────────────────────────────
        result = predict(image_bytes)

        conn   = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        try:
            # ── Save scan to DB ───────────────────────────────
            cursor.execute(
                """INSERT INTO scans
                   (user_id, image_name, verdict, confidence, raw_score)
                   VALUES (%s, %s, %s, %s, %s)""",
                (
                    user_id,
                    file.filename or "uploaded_image",
                    result["verdict"],
                    result["confidence"],
                    result["raw_score"],
                )
            )

            # ── Update streak ─────────────────────────────────
            # Fetch current streak data for this user
            cursor.execute(
                "SELECT current_streak, last_scan_date FROM users WHERE id = %s",
                (user_id,)
            )
            user_row   = cursor.fetchone()
            today      = datetime.utcnow().date()
            last_date  = user_row["last_scan_date"]   # date or None
            streak     = user_row["current_streak"]   # int

            if last_date is None:
                # First scan ever — start streak at 1
                new_streak = 1
            elif last_date == today:
                # Already scanned today — streak unchanged
                new_streak = streak
                # CORRECT:
            elif last_date == today - timedelta(days=1):
                # Scanned yesterday — extend streak
                new_streak = streak + 1
            else:
                # Gap of more than 1 day — reset streak
                new_streak = 1

            # Persist updated streak
            cursor.execute(
                """UPDATE users
                   SET current_streak  = %s,
                       last_scan_date  = %s,
                       longest_streak  = GREATEST(longest_streak, %s)
                   WHERE id = %s""",
                (new_streak, today, new_streak, user_id)
            )

            conn.commit()

        except Exception as db_err:
            conn.rollback()
            raise db_err
        finally:
            cursor.close()
            conn.close()

        return DetectionResult(**result)

    except ValueError as e:
        # No face detected
        raise HTTPException(status_code=422, detail=str(e))

    except HTTPException:
        raise

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Detection error: {str(e)}")

# ── Scan History ──────────────────────────────────────────────────
@router.get("/history", response_model=ScanHistoryResponse)
def get_history(
    user_id: int = Depends(get_current_user),
    limit: int = 20,
):
    """Returns the logged-in user's past scan history, most recent first."""
    conn   = get_db_connection()
    # Use DictCursor — mysql-connector uses dictionary=True
    cursor = conn.cursor(dictionary=True)

    try:
        cursor.execute(
            """SELECT id, image_name, verdict, confidence, scanned_at
               FROM scans WHERE user_id = %s
               ORDER BY scanned_at DESC LIMIT %s""",
            (user_id, limit)
        )
        rows  = cursor.fetchall()
        scans = [
            ScanHistoryItem(
                id         = row["id"],
                image_name = row["image_name"],
                verdict    = row["verdict"],
                confidence = row["confidence"],
                scanned_at = str(row["scanned_at"]),
            )
            for row in rows
        ]
        return ScanHistoryResponse(message="History fetched successfully", scans=scans)

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")
    finally:
        cursor.close()
        conn.close()


# ── Delete Single Scan ────────────────────────────────────────────
@router.delete("/history/{scan_id}", status_code=200)
def delete_single_scan(
    scan_id: int,
    user_id: int = Depends(get_current_user),
):
    """Deletes a single scan. Only deletes if it belongs to the logged-in user."""
    conn   = get_db_connection()
    cursor = conn.cursor()
    try:
        # Verify ownership before deleting
        cursor.execute(
            "SELECT id FROM scans WHERE id = %s AND user_id = %s",
            (scan_id, user_id)
        )
        if not cursor.fetchone():
            raise HTTPException(status_code=404,
                detail="Scan not found or access denied.")

        cursor.execute("DELETE FROM scans WHERE id = %s", (scan_id,))
        conn.commit()
        return {"message": "Scan deleted successfully"}

    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")
    finally:
        cursor.close()
        conn.close()


# ── Delete All History ────────────────────────────────────────────
@router.delete("/history", status_code=200)
def delete_history(user_id: int = Depends(get_current_user)):
    """Deletes all scan history for the logged-in user."""
    conn   = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "DELETE FROM scans WHERE user_id = %s", (user_id,)
        )
        deleted_count = cursor.rowcount
        conn.commit()
        return {"message": f"Deleted {deleted_count} scan(s) successfully"}

    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")
    finally:
        cursor.close()
        conn.close()


# ── Statistics ────────────────────────────────────────────────────
@router.get("/stats", response_model=StatsResponse)
def get_stats(user_id: int = Depends(get_current_user)):
    """Returns scan statistics for the logged-in user."""
    conn   = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        cursor.execute(
            """SELECT
                COUNT(*)                                         AS total_scans,
                SUM(CASE WHEN verdict='REAL' THEN 1 ELSE 0 END) AS total_real,
                SUM(CASE WHEN verdict='FAKE' THEN 1 ELSE 0 END) AS total_fake,
                MAX(scanned_at)                                  AS last_scanned
               FROM scans WHERE user_id = %s""",
            (user_id,)
        )
        row = cursor.fetchone()

        return StatsResponse(
            total_scans  = row["total_scans"]  or 0,
            total_real   = row["total_real"]   or 0,
            total_fake   = row["total_fake"]   or 0,
            last_scanned = str(row["last_scanned"]) if row["last_scanned"] else None,
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")
    finally:
        cursor.close()
        conn.close()

# ── Analytics ─────────────────────────────────────────────────────
# Add this import at the top of detect_routes.py if not present:
# from datetime import datetime, timedelta
# from models.schemas import AnalyticsResponse, DailyActivity

@router.get("/analytics", response_model=AnalyticsResponse)
def get_analytics(user_id: int = Depends(get_current_user)):
    """
    Returns rich analytics data for the dashboard screen.
    Computes everything from the existing scans table — no new DB columns.
    """

    conn   = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        # ── Core counts ───────────────────────────────────────────
        cursor.execute(
            """SELECT
                COUNT(*)                                          AS total_scans,
                SUM(CASE WHEN verdict='REAL' THEN 1 ELSE 0 END)  AS total_real,
                SUM(CASE WHEN verdict='FAKE' THEN 1 ELSE 0 END)  AS total_fake,
                AVG(CASE WHEN verdict='REAL' THEN confidence END) AS avg_conf_real,
                AVG(CASE WHEN verdict='FAKE' THEN confidence END) AS avg_conf_fake,
                MAX(scanned_at)                                   AS last_scanned
               FROM scans WHERE user_id = %s""",
            (user_id,)
        )
        core = cursor.fetchone()

        total_scans         = core["total_scans"]  or 0
        total_real          = core["total_real"]   or 0
        total_fake          = core["total_fake"]   or 0
        avg_confidence_real = round(float(core["avg_conf_real"] or 0), 1)
        avg_confidence_fake = round(float(core["avg_conf_fake"] or 0), 1)
        last_scanned        = str(core["last_scanned"]) if core["last_scanned"] else None

        # ── Weekly activity — last 7 days ─────────────────────────
        # Build a list of the last 7 dates so we always return 7 bars
        today      = datetime.utcnow().date()
        day_labels = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun']
        week_dates = [(today - timedelta(days=i)) for i in range(6, -1, -1)]

        cursor.execute(
            """SELECT
                DATE(scanned_at)                                      AS scan_date,
                COUNT(*)                                              AS total,
                SUM(CASE WHEN verdict='REAL' THEN 1 ELSE 0 END)       AS real_count,
                SUM(CASE WHEN verdict='FAKE' THEN 1 ELSE 0 END)       AS fake_count
               FROM scans
               WHERE user_id = %s AND scanned_at >= %s
               GROUP BY DATE(scanned_at)""",
            (user_id, week_dates[0])
        )
        raw_week = {row["scan_date"]: row for row in cursor.fetchall()}

        daily_activity = []
        for d in week_dates:
            row = raw_week.get(d)
            daily_activity.append(DailyActivity(
                date       = day_labels[d.weekday()],
                total      = int(row["total"])      if row else 0,
                real_count = int(row["real_count"]) if row else 0,
                fake_count = int(row["fake_count"]) if row else 0,
            ))

        # ── Last 10 verdict trend ─────────────────────────────────
        cursor.execute(
            """SELECT verdict FROM scans
               WHERE user_id = %s
               ORDER BY scanned_at DESC LIMIT 10""",
            (user_id,)
        )
        # Reverse so oldest→newest (left→right on screen)
        verdict_trend = [r["verdict"] for r in cursor.fetchall()][::-1]

        # ── Personalized insight ──────────────────────────────────
        # A short motivating message based on the user's actual data
        if total_scans == 0:
            insight = "Run your first scan to start building your analytics!"
        elif total_fake == 0:
            insight = f"You've scanned {total_scans} image(s) — all authentic so far. Stay vigilant!"
        elif total_fake >= 10:
            insight = f"Impressive! You've caught {total_fake} deepfakes. You're a pro detector! 🎯"
        elif total_scans >= 20:
            fake_pct = round((total_fake / total_scans) * 100)
            insight  = f"{fake_pct}% of images you scanned were deepfakes. The internet needs you! 🛡️"
        elif len(verdict_trend) >= 3 and all(v == 'FAKE' for v in verdict_trend[-3:]):
            insight = "Last 3 scans were all deepfakes — stay alert out there! 🚨"
        elif len(verdict_trend) >= 3 and all(v == 'REAL' for v in verdict_trend[-3:]):
            insight = "Last 3 scans were all authentic. Your sources look trustworthy! ✅"
        else:
            insight = f"You've caught {total_fake} deepfake(s) out of {total_scans} scan(s). Keep going! 💪"

        return AnalyticsResponse(
            total_scans         = total_scans,
            total_real          = total_real,
            total_fake          = total_fake,
            avg_confidence_real = avg_confidence_real,
            avg_confidence_fake = avg_confidence_fake,
            daily_activity      = daily_activity,
            verdict_trend       = verdict_trend,
            insight             = insight,
            last_scanned        = last_scanned,
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")
    finally:
        cursor.close()
        conn.close()

# routes/detect_routes.py
# ============================================================
# Deepfake detection endpoints:
#   POST /api/detect/         → scan image, returns rich result
#   GET  /api/detect/history  → past scans (protected)
#   GET  /api/detect/stats    → scan statistics (protected)
#   DELETE /api/detect/history/{id} → delete single scan
#   DELETE /api/detect/history      → delete all scans
# ============================================================

from fastapi import APIRouter, UploadFile, File, Depends, HTTPException
from middleware.auth_middleware import get_current_user
from models.schemas import (
    DetectionResult, ScanHistoryResponse,
    ScanHistoryItem, StatsResponse
)
from config.database import get_db_connection
from services.detector import predict

router = APIRouter()

ALLOWED_TYPES = {"image/jpeg", "image/png", "image/jpg", "image/webp"}


# ── Detect ────────────────────────────────────────────────────────
@router.post("/", response_model=DetectionResult)
async def detect(
    file: UploadFile = File(...),
    user_id: int = Depends(get_current_user),
):
    """
    Accepts an image, runs full deepfake analysis pipeline:
    model inference + GradCAM + EXIF + LLM explanation.
    Saves result to DB and returns rich response.
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
        # Run full detection pipeline
        result = predict(image_bytes)

        # Save core result to DB (we don't store heatmap/exif in DB)
        conn   = get_db_connection()
        cursor = conn.cursor()
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
        conn.commit()
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
# routes/account_routes.py
# ============================================================
# Account management endpoints:
#   DELETE /api/account/delete  → permanently delete account
#   POST   /api/account/reset   → reset all data, keep account
# ============================================================

from fastapi import APIRouter, Depends, HTTPException
from middleware.auth_middleware import get_current_user
from models.schemas import DeleteAccountRequest, ResetAccountResponse
from config.database import get_db_connection
from utils.security import verify_password

router = APIRouter()


# ── DELETE /api/account/delete ────────────────────────────────────
@router.delete("/delete")
def delete_account(
    data:    DeleteAccountRequest,
    user_id: int = Depends(get_current_user),
):
    """
    Permanently deletes the user's account and ALL related data:
      - scans
      - reset_tokens
      - challenge_scores
      - users row itself
    Requires password confirmation before deleting.
    """
    conn   = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        # 1. Fetch user + verify password
        cursor.execute(
            "SELECT id, password FROM users WHERE id = %s",
            (user_id,)
        )
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        if not verify_password(data.password, user["password"]):
            raise HTTPException(
                status_code=401,
                detail="Incorrect password. Please try again."
            )

        # 2. Delete all related data in correct order
        #    (foreign key constraints require child rows deleted first)

        # Delete challenge scores
        cursor.execute(
            "DELETE FROM challenge_scores WHERE user_id = %s",
            (user_id,)
        )

        cursor.execute(
            "DELETE FROM earned_badges WHERE user_id = %s",
            (user_id,)
        )

        # Delete scan history
        cursor.execute(
            "DELETE FROM scans WHERE user_id = %s",
            (user_id,)
        )

        # Delete reset tokens
        cursor.execute(
            "DELETE FROM reset_tokens WHERE user_id = %s",
            (user_id,)
        )

        # 3. Delete the user account itself
        cursor.execute(
            "DELETE FROM users WHERE id = %s",
            (user_id,)
        )

        conn.commit()

        return {"message": "Account permanently deleted."}

    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")
    finally:
        cursor.close()
        conn.close()


# ── POST /api/account/reset ───────────────────────────────────────
@router.post("/reset", response_model=ResetAccountResponse)
def reset_account(user_id: int = Depends(get_current_user)):
    """
    Resets everything in the account except the account itself:
      - Deletes all scans
      - Deletes all challenge scores
      - Resets streak to 0 + last_scan_date to NULL
      - Resets avatar to initial
      - Deletes unused reset tokens
    Keeps: name, email, password, is_verified
    No password required — just confirmation dialog in app.
    """
    conn   = get_db_connection()
    cursor = conn.cursor()

    try:
        # 1. Delete all scans
        cursor.execute(
            "DELETE FROM scans WHERE user_id = %s",
            (user_id,)
        )

        # 2. Delete all challenge scores
        cursor.execute(
            "DELETE FROM challenge_scores WHERE user_id = %s",
            (user_id,)
        )

        cursor.execute(
            "DELETE FROM earned_badges WHERE user_id = %s",
            (user_id,)
        )

        # 3. Delete unused reset tokens
        cursor.execute(
            "DELETE FROM reset_tokens WHERE user_id = %s AND used = FALSE",
            (user_id,)
        )

        # 4. Reset user fields:
        #    - streak back to 0
        #    - last_scan_date back to NULL
        #    - avatar back to initial
        cursor.execute(
            """UPDATE users SET
               current_streak  = 0,
               longest_streak  = 0,
               last_scan_date  = NULL,
               avatar_type     = 'initial',
               avatar_data     = NULL
               WHERE id = %s""",
            (user_id,)
        )

        conn.commit()

        return ResetAccountResponse(
            message="Account reset successfully. All data has been cleared."
        )

    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")
    finally:
        cursor.close()
        conn.close()
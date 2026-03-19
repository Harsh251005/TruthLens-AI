# routes/password_routes.py
# ============================================================
# Forgot password endpoints:
#   POST /api/password/forgot  → sends 6-digit code to email
#   POST /api/password/reset   → verifies code & updates password
# ============================================================

import random
import string
from datetime import datetime, timedelta
from fastapi import APIRouter, HTTPException
from models.schemas import (
    ForgotPasswordRequest, ForgotPasswordResponse,
    ResetPasswordRequest, ResetPasswordResponse
)
from config.database import get_db_connection
from config.email import send_reset_email
from utils.security import hash_password, verify_password

router = APIRouter()


def generate_reset_code() -> str:
    """Generates a random 6-digit numeric code."""
    return ''.join(random.choices(string.digits, k=6))


# ── Forgot Password ───────────────────────────────────────────────
@router.post("/forgot", response_model=ForgotPasswordResponse)
async def forgot_password(data: ForgotPasswordRequest):
    """
    1. Check if email exists in database
    2. Generate a 6-digit reset code
    3. Store code in reset_tokens table with 15 min expiry
    4. Send code to user's email
    """
    conn   = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        # 1. Check if email exists
        cursor.execute(
            "SELECT id FROM users WHERE email = %s",
            (data.email.lower().strip(),)
        )
        user = cursor.fetchone()

        # Return clear error if email not found
        if not user:
            raise HTTPException(
                status_code=404,
                detail="No account found with this email address. Please check and try again."
            )

        # 2. Generate 6-digit code
        code = generate_reset_code()

        # 3. Delete any existing tokens for this user
        cursor.execute(
            "DELETE FROM reset_tokens WHERE user_id = %s",
            (user["id"],)
        )

        # 4. Store new token with 15 minute expiry — commit immediately
        expires_at = datetime.utcnow() + timedelta(minutes=15)
        cursor.execute(
            "INSERT INTO reset_tokens (user_id, token, expires_at) VALUES (%s, %s, %s)",
            (user["id"], code, expires_at)
        )
        conn.commit()  # Commit token BEFORE sending email

        # 5. Send email — handle failure gracefully without rolling back token
        try:
            await send_reset_email(data.email.lower().strip(), code)
        except Exception as email_error:
            # Log email error but don't fail — token is already saved
            print(f"⚠️ Email send failed for {data.email}: {email_error}")
            raise HTTPException(
                status_code=500,
                detail="Failed to send reset email. Please check your email address and try again."
            )

        return ForgotPasswordResponse(
            message="If this email is registered, a reset code has been sent."
        )

    except HTTPException:
        raise

    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")

    finally:
        cursor.close()
        conn.close()


# ── Reset Password ────────────────────────────────────────────────
@router.post("/reset", response_model=ResetPasswordResponse)
def reset_password(data: ResetPasswordRequest):
    """
    1. Find the reset token for this email
    2. Check code matches and hasn't expired
    3. Update password with new hash
    4. Verify the update actually worked
    5. Mark token as used
    """
    conn   = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        # 1. Find user by email
        cursor.execute(
            "SELECT id, password FROM users WHERE email = %s",
            (data.email.lower().strip(),)
        )
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=400, detail="Invalid request")

        # 2. Find valid unused token
        cursor.execute(
            """SELECT id FROM reset_tokens
               WHERE user_id = %s
               AND token = %s
               AND used = FALSE
               AND expires_at > UTC_TIMESTAMP()""",  # Use DB time to avoid timezone mismatch
            (user["id"], data.code)
        )
        token_record = cursor.fetchone()

        if not token_record:
            raise HTTPException(
                status_code=400,
                detail="Invalid or expired reset code. Please request a new one."
            )

        # 3. Reject if new password is the same as the current one.
        # verify_password compares the plaintext against the stored bcrypt hash.
        # This must happen BEFORE hashing the new password.
        if verify_password(data.new_password, user["password"]):
            raise HTTPException(
                status_code=400,
                detail="New password must be different from your current password."
            )

        # 4. Hash the new password
        hashed = hash_password(data.new_password)

        # 5. Update password in users table
        cursor.execute(
            "UPDATE users SET password = %s WHERE id = %s",
            (hashed, user["id"])
        )

        # Verify the update actually affected a row
        if cursor.rowcount == 0:
            raise HTTPException(
                status_code=500,
                detail="Failed to update password. Please try again."
            )

        # 6. Mark token as used so it can't be reused
        cursor.execute(
            "UPDATE reset_tokens SET used = TRUE WHERE id = %s",
            (token_record["id"],)
        )

        # Commit both updates together
        conn.commit()

        print(f"✅ Password reset successful for user_id={user['id']}")

        return ResetPasswordResponse(message="Password reset successfully")

    except HTTPException:
        raise

    except Exception as e:
        conn.rollback()
        print(f"❌ Password reset error: {e}")
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")

    finally:
        cursor.close()
        conn.close()
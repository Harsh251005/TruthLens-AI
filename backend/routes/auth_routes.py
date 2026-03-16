# routes/auth_routes.py
# ============================================================
# Auth API endpoints:
#   POST /api/auth/signup  → Register new user + send OTP
#   POST /api/auth/login   → Authenticate + check verification
#   POST /api/auth/verify  → Verify email with OTP
#   POST /api/auth/resend  → Resend verification OTP
# ============================================================

import random
import string
from datetime import datetime, timedelta
from fastapi import APIRouter, HTTPException
from models.schemas import (
    SignupRequest, LoginRequest,
    SignupResponse, LoginResponse, UserOut,
    VerifyEmailRequest, VerifyEmailResponse,
    ResendVerificationRequest, ResendVerificationResponse,
)
from config.database import get_db_connection
from config.email import send_verification_email
from utils.security import hash_password, verify_password, create_access_token

router = APIRouter()


# ── Helper ────────────────────────────────────────────────────────
def generate_otp() -> str:
    """Generates a random 6-digit numeric OTP."""
    return ''.join(random.choices(string.digits, k=6))


# ── Signup ────────────────────────────────────────────────────────
@router.post("/signup", response_model=SignupResponse)
async def signup(data: SignupRequest):
    """
    Registers a new user.
    1. Check email isn't already taken
    2. Hash the password
    3. Insert into MySQL (is_verified = FALSE)
    4. Generate + store OTP in reset_tokens table
    5. Send OTP to email
    6. Return user info + JWT token
       (token works but app shows verify screen first)
    """
    conn   = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        # 1. Check if email already exists
        cursor.execute(
            "SELECT id, is_verified FROM users WHERE email = %s",
            (data.email.lower().strip(),)
        )
        existing = cursor.fetchone()
        if existing:
            # If user exists but is unverified, let them resend OTP
            if not existing["is_verified"]:
                raise HTTPException(
                    status_code=409,
                    detail="Email already registered but not verified. "
                           "Please verify your email or use resend OTP."
                )
            raise HTTPException(
                status_code=409,
                detail="Email is already registered"
            )

        # 2. Hash password
        hashed = hash_password(data.password)

        # 3. Insert new user — is_verified defaults to FALSE
        cursor.execute(
            "INSERT INTO users (name, email, password) VALUES (%s, %s, %s)",
            (data.name.strip(), data.email.lower().strip(), hashed)
        )
        conn.commit()
        new_user_id = cursor.lastrowid

        # 4. Generate OTP and store in reset_tokens table
        # We reuse reset_tokens for verification OTPs too —
        # same structure, no new table needed.
        otp        = generate_otp()
        expires_at = datetime.utcnow() + timedelta(minutes=15)

        # Clear any old tokens for this user first
        cursor.execute(
            "DELETE FROM reset_tokens WHERE user_id = %s",
            (new_user_id,)
        )
        cursor.execute(
            "INSERT INTO reset_tokens (user_id, token, expires_at) "
            "VALUES (%s, %s, %s)",
            (new_user_id, otp, expires_at)
        )
        conn.commit()

        # 5. Send OTP email
        try:
            await send_verification_email(data.email.lower().strip(), otp)
        except Exception as email_err:
            print(f"⚠️ Verification email failed: {email_err}")
            raise HTTPException(
                status_code=500,
                detail="Account created but failed to send verification email. "
                       "Please use resend OTP."
            )

        # 6. Return token — app will show verify screen
        token = create_access_token(new_user_id)

        return SignupResponse(
            message="Account created. Please verify your email.",
            user=UserOut(
                id=new_user_id,
                name=data.name.strip(),
                email=data.email.lower().strip(),
                token=token,
                is_verified=False,
            )
        )

    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")
    finally:
        cursor.close()
        conn.close()


# ── Login ─────────────────────────────────────────────────────────
@router.post("/login", response_model=LoginResponse)
def login(data: LoginRequest):
    """
    Authenticates an existing user.
    1. Find user by email
    2. Verify password
    3. Check is_verified — if false, return 403 with flag
    4. Return user info + JWT token
    """
    conn   = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        # 1. Look up user by email
        cursor.execute(
            "SELECT id, name, email, password, is_verified, "
            "avatar_type, avatar_data FROM users WHERE email = %s",
            (data.email.lower().strip(),)
        )
        user = cursor.fetchone()

        if not user:
            raise HTTPException(
                status_code=401,
                detail="Invalid email or password"
            )

        # 2. Verify password
        if not verify_password(data.password, user["password"]):
            raise HTTPException(
                status_code=401,
                detail="Invalid email or password"
            )

        # 3. Check verification status
        # Return 403 with a specific detail so Flutter knows to show
        # the verification screen rather than a generic error
        if not user["is_verified"]:
            token = create_access_token(user["id"])
            raise HTTPException(
                status_code=403,
                detail="email_not_verified",
                headers={"X-User-Token": token, "X-User-Email": user["email"]}
            )

        # 4. Generate JWT token
        token = create_access_token(user["id"])

        return LoginResponse(
            message="Login successful",
            user=UserOut(
                id=user["id"],
                name=user["name"],
                email=user["email"],
                token=token,
                is_verified=True,
                avatar_type=user.get("avatar_type", "initial"),
                avatar_data=user.get("avatar_data"),
            )
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")
    finally:
        cursor.close()
        conn.close()


# ── Verify Email ──────────────────────────────────────────────────
@router.post("/verify", response_model=VerifyEmailResponse)
def verify_email(data: VerifyEmailRequest):
    """
    Verifies a user's email using the 6-digit OTP.
    1. Find user by email
    2. Check OTP matches + not expired
    3. Mark user as verified
    4. Mark token as used
    5. Return JWT token so user lands on home screen
    """
    conn   = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        # 1. Find user
        cursor.execute(
            "SELECT id, name, email, avatar_type, avatar_data "
            "FROM users WHERE email = %s",
            (data.email.lower().strip(),)
        )
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=400, detail="Invalid request")

        # 2. Check OTP
        cursor.execute(
            """SELECT id FROM reset_tokens
               WHERE user_id = %s
               AND token = %s
               AND used = FALSE
               AND expires_at > UTC_TIMESTAMP()""",
            (user["id"], data.code)
        )
        token_record = cursor.fetchone()
        if not token_record:
            raise HTTPException(
                status_code=400,
                detail="Invalid or expired code. Please request a new one."
            )

        # 3. Mark user as verified
        cursor.execute(
            "UPDATE users SET is_verified = TRUE WHERE id = %s",
            (user["id"],)
        )

        # 4. Mark token as used
        cursor.execute(
            "UPDATE reset_tokens SET used = TRUE WHERE id = %s",
            (token_record["id"],)
        )
        conn.commit()

        # 5. Return token — user goes straight to home screen
        token = create_access_token(user["id"])

        return VerifyEmailResponse(
            message="Email verified successfully! Welcome to TruthLens AI.",
            token=token,
            user=UserOut(
                id=user["id"],
                name=user["name"],
                email=user["email"],
                token=token,
                is_verified=True,
                avatar_type=user.get("avatar_type", "initial"),
                avatar_data=user.get("avatar_data"),
            )
        )

    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")
    finally:
        cursor.close()
        conn.close()


# ── Resend OTP ────────────────────────────────────────────────────
@router.post("/resend", response_model=ResendVerificationResponse)
async def resend_otp(data: ResendVerificationRequest):
    """
    Resends a fresh OTP to the user's email.
    Works for both new signups and unverified logins.
    """
    conn   = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        # Find user
        cursor.execute(
            "SELECT id, is_verified FROM users WHERE email = %s",
            (data.email.lower().strip(),)
        )
        user = cursor.fetchone()

        # Don't reveal if email exists or not
        if not user:
            return ResendVerificationResponse(
                message="If this email is registered, a new code has been sent."
            )

        # Already verified — no need to resend
        if user["is_verified"]:
            raise HTTPException(
                status_code=400,
                detail="This email is already verified."
            )

        # Generate new OTP
        otp        = generate_otp()
        expires_at = datetime.utcnow() + timedelta(minutes=15)

        # Replace old tokens
        cursor.execute(
            "DELETE FROM reset_tokens WHERE user_id = %s",
            (user["id"],)
        )
        cursor.execute(
            "INSERT INTO reset_tokens (user_id, token, expires_at) "
            "VALUES (%s, %s, %s)",
            (user["id"], otp, expires_at)
        )
        conn.commit()

        # Send email
        try:
            await send_verification_email(data.email.lower().strip(), otp)
        except Exception as e:
            print(f"⚠️ Resend OTP email failed: {e}")
            raise HTTPException(
                status_code=500,
                detail="Failed to send OTP. Please try again."
            )

        return ResendVerificationResponse(
            message="A new verification code has been sent to your email."
        )

    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")
    finally:
        cursor.close()
        conn.close()
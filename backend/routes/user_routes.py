# routes/user_routes.py
# ============================================================
# Protected user routes — require a valid JWT token.
#
# Endpoints:
#   GET  /api/users/me         → fetch current user profile + avatar
#   PUT  /api/users/update     → update name and/or password
#   PUT  /api/users/avatar     → NEW: update user avatar
#
# AVATAR CHANGES (Step 3):
#   • /me now returns avatar_type + avatar_data fields
#   • New PUT /avatar endpoint saves avatar to DB
# ============================================================

import base64
from fastapi import APIRouter, Depends, HTTPException
from middleware.auth_middleware import get_current_user_from_db, get_current_user
from models.schemas import (
    UpdateProfileRequest, UpdateProfileResponse,
    UpdateAvatarRequest, UpdateAvatarResponse,
    UserOut,
)
from config.database import get_db_connection
from utils.security import verify_password, hash_password

router = APIRouter()


# ── Get Current User ──────────────────────────────────────────────
@router.get("/me")
def get_me(current_user: dict = Depends(get_current_user_from_db)):
    """
    Protected route — returns the logged-in user's full profile,
    including avatar_type and avatar_data.
    Requires: Authorization: Bearer <token> header.
    """
    return {
        "message": "Profile fetched successfully",
        "user": {
            "id":          current_user["id"],
            "name":        current_user["name"],
            "email":       current_user["email"],
            "created_at":  str(current_user["created_at"]),
            # Avatar fields — will be None/initial for users who haven't set one
            "avatar_type": current_user.get("avatar_type", "initial"),
            "avatar_data": current_user.get("avatar_data"),
        }
    }


# ── Update Profile ────────────────────────────────────────────────
@router.put("/update", response_model=UpdateProfileResponse)
def update_profile(
    data: UpdateProfileRequest,
    user_id: int = Depends(get_current_user),
):
    """
    Protected route — updates name and/or password.
    Does NOT touch avatar — use PUT /avatar for that.
    """
    conn   = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        # Fetch current user from DB
        cursor.execute(
            "SELECT id, name, email, password, avatar_type, avatar_data "
            "FROM users WHERE id = %s",
            (user_id,)
        )
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        # ── Handle password change ─────────────────────────────
        if data.new_password:
            if not data.current_password:
                raise HTTPException(
                    status_code=400,
                    detail="Current password is required to set a new password"
                )
            if not verify_password(data.current_password, user["password"]):
                raise HTTPException(
                    status_code=401,
                    detail="Current password is incorrect"
                )

        # ── Build dynamic UPDATE query ─────────────────────────
        updates = []
        values  = []

        if data.name:
            updates.append("name = %s")
            values.append(data.name.strip())

        if data.new_password:
            updates.append("password = %s")
            values.append(hash_password(data.new_password))

        if not updates:
            raise HTTPException(status_code=400, detail="No fields provided to update")

        values.append(user_id)
        cursor.execute(
            f"UPDATE users SET {', '.join(updates)} WHERE id = %s",
            values
        )
        conn.commit()

        updated_name = data.name.strip() if data.name else user["name"]

        return UpdateProfileResponse(
            message="Profile updated successfully",
            user=UserOut(
                id=user_id,
                name=updated_name,
                email=user["email"],
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


# ── Update Avatar — NEW ───────────────────────────────────────────
@router.put("/avatar", response_model=UpdateAvatarResponse)
def update_avatar(
    data: UpdateAvatarRequest,
    user_id: int = Depends(get_current_user),
):
    """
    Protected route — saves the user's chosen avatar to the DB.

    Request body:
      {
        "avatar_type": "initial" | "predefined" | "custom",
        "avatar_data": null | "<avatar_id>" | "<base64_jpeg_string>"
      }

    Validation rules:
      • 'initial'    → avatar_data must be null (resets to letter avatar)
      • 'predefined' → avatar_data must be a non-empty string (the avatar ID)
      • 'custom'     → avatar_data must be a valid base64 string
                       and must not exceed 5MB decoded
    """
    conn   = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        # ── Validate based on avatar_type ──────────────────────
        avatar_type = data.avatar_type
        avatar_data = data.avatar_data

        if avatar_type == "initial":
            # Reset to default — clear any stored avatar data
            avatar_data = None

        elif avatar_type == "predefined":
            # Must have an avatar ID string
            if not avatar_data or not avatar_data.strip():
                raise HTTPException(
                    status_code=400,
                    detail="avatar_data (avatar ID) is required for predefined avatars"
                )
            avatar_data = avatar_data.strip()

        elif avatar_type == "custom":
            # Must have base64 data and must decode successfully
            if not avatar_data:
                raise HTTPException(
                    status_code=400,
                    detail="avatar_data (base64 image) is required for custom avatars"
                )
            try:
                decoded = base64.b64decode(avatar_data)
            except Exception:
                raise HTTPException(
                    status_code=400,
                    detail="avatar_data is not valid base64"
                )
            # Enforce 5MB limit for decoded image size
            max_bytes = 5 * 1024 * 1024
            if len(decoded) > max_bytes:
                raise HTTPException(
                    status_code=400,
                    detail="Image too large. Maximum allowed size is 5MB."
                )

        # ── Save to DB ─────────────────────────────────────────
        cursor.execute(
            "UPDATE users SET avatar_type = %s, avatar_data = %s WHERE id = %s",
            (avatar_type, avatar_data, user_id)
        )
        conn.commit()

        return UpdateAvatarResponse(
            message="Avatar updated successfully",
            avatar_type=avatar_type,
            avatar_data=avatar_data,
        )

    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")
    finally:
        cursor.close()
        conn.close()
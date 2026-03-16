# routes/user_routes.py
# ============================================================
# Protected user routes — require a valid JWT token.
#
# Endpoints:
#   GET  /api/users/me         → fetch current user profile + avatar
#   PUT  /api/users/update     → update name and/or password
#   PUT  /api/users/avatar     → update user avatar
#
# FIX (persistence bug):
#   /me now uses get_current_user (JWT → user_id only) and does
#   its OWN explicit SELECT that includes avatar_type + avatar_data.
#   Previously it used get_current_user_from_db whose SELECT was
#   written before avatar columns existed — so it never returned them,
#   causing the app to overwrite SharedPreferences with null avatar
#   on every profile fetch (i.e. every app launch).
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
def get_me(user_id: int = Depends(get_current_user)):
    """
    Protected route — returns the logged-in user's full profile,
    including avatar_type and avatar_data.

    Uses get_current_user (JWT → user_id) then does its own SELECT
    so it always includes all columns — including newly added ones
    like avatar_type and avatar_data.
    """
    conn   = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        # Explicit SELECT — always includes avatar columns
        cursor.execute(
            "SELECT id, name, email, created_at, avatar_type, avatar_data "
            "FROM users WHERE id = %s",
            (user_id,)
        )
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        return {
            "message": "Profile fetched successfully",
            "user": {
                "id":          user["id"],
                "name":        user["name"],
                "email":       user["email"],
                "created_at":  str(user["created_at"]),
                "avatar_type": user.get("avatar_type", "initial"),
                "avatar_data": user.get("avatar_data"),   # None if not set
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")
    finally:
        cursor.close()
        conn.close()


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
            raise HTTPException(
                status_code=400,
                detail="No fields provided to update"
            )

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


# ── Update Avatar ─────────────────────────────────────────────────
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
        "avatar_data": null | "<avatar_id>"
      }
    """
    conn   = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        avatar_type = data.avatar_type
        avatar_data = data.avatar_data

        if avatar_type == "initial":
            # Reset — clear stored avatar data
            avatar_data = None

        elif avatar_type == "predefined":
            # Must have an avatar ID string
            if not avatar_data or not avatar_data.strip():
                raise HTTPException(
                    status_code=400,
                    detail="avatar_data (avatar ID) is required for predefined avatars"
                )
            avatar_data = avatar_data.strip()

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
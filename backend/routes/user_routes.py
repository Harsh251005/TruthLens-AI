# routes/user_routes.py
# ============================================================
# Protected user routes — require a valid JWT token.
# GET /api/users/me      → fetch current user profile
# PUT /api/users/update  → update name and/or password
# ============================================================

from fastapi import APIRouter, Depends, HTTPException
from middleware.auth_middleware import get_current_user_from_db, get_current_user
from models.schemas import UpdateProfileRequest, UpdateProfileResponse, UserOut
from config.database import get_db_connection
from utils.security import verify_password, hash_password

router = APIRouter()


# ── Get Current User ──────────────────────────────────────────────
@router.get("/me")
def get_me(current_user: dict = Depends(get_current_user_from_db)):
    """
    Protected route — returns the logged-in user's profile.
    Requires: Authorization: Bearer <token> header.
    """
    return {
        "message": "Profile fetched successfully",
        "user": {
            "id":         current_user["id"],
            "name":       current_user["name"],
            "email":      current_user["email"],
            "created_at": str(current_user["created_at"]),
        }
    }


# ── Update Profile ────────────────────────────────────────────────
@router.put("/update", response_model=UpdateProfileResponse)
def update_profile(
    data: UpdateProfileRequest,
    user_id: int = Depends(get_current_user),  # Get user_id from token
):
    """
    Protected route — updates name and/or password.
    - Name update: just send new name
    - Password update: send current_password + new_password
    - Both: send all three fields
    """
    conn   = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        # Fetch current user from DB
        cursor.execute(
            "SELECT id, name, email, password FROM users WHERE id = %s",
            (user_id,)
        )
        user = cursor.fetchone()
        if not user:
            raise HTTPException(status_code=404, detail="User not found")

        # ── Handle password change ─────────────────────────────
        if data.new_password:
            # current_password is required when changing password
            if not data.current_password:
                raise HTTPException(
                    status_code=400,
                    detail="Current password is required to set a new password"
                )
            # Verify current password matches stored hash
            if not verify_password(data.current_password, user["password"]):
                raise HTTPException(
                    status_code=401,
                    detail="Current password is incorrect"
                )

        # ── Build dynamic UPDATE query ─────────────────────────
        # Only update fields that were actually provided
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

        # Execute the update
        values.append(user_id)  # For WHERE clause
        cursor.execute(
            f"UPDATE users SET {', '.join(updates)} WHERE id = %s",
            values
        )
        conn.commit()

        # Return updated user info
        updated_name = data.name.strip() if data.name else user["name"]

        return UpdateProfileResponse(
            message="Profile updated successfully",
            user=UserOut(
                id=user_id,
                name=updated_name,
                email=user["email"],
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
# middleware/auth_middleware.py
# ============================================================
# Reusable FastAPI dependency that protects routes.
# Add `user_id: int = Depends(get_current_user)` to any
# route function to make it require a valid JWT token.
# ============================================================

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from utils.security import verify_token
from config.database import get_db_connection

# HTTPBearer automatically reads the Authorization: Bearer <token> header
bearer_scheme = HTTPBearer()


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme)
) -> int:
    """
    FastAPI dependency — extracts and validates the JWT token.
    Returns the user_id if token is valid.
    Raises 401 if token is missing, invalid, or expired.
    """
    token = credentials.credentials  # Extract raw token from header

    user_id = verify_token(token)
    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token. Please login again.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return user_id  # Pass user_id to the protected route


def get_current_user_from_db(
    user_id: int = Depends(get_current_user)
) -> dict:
    """
    Extended dependency — also fetches full user record from MySQL.
    Use this when the route needs user details (name, email, etc.)
    """
    conn   = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        cursor.execute(
            "SELECT id, name, email, created_at FROM users WHERE id = %s",
            (user_id,)
        )
        user = cursor.fetchone()

        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )

        return user

    finally:
        cursor.close()
        conn.close()
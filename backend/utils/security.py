# utils/security.py
# ============================================================
# Three responsibilities:
#   1. Password hashing & verification using bcrypt
#   2. JWT token generation
#   3. JWT token verification (NEW)
# ============================================================

from passlib.context import CryptContext
from jose import jwt, JWTError
from datetime import datetime, timedelta
from dotenv import load_dotenv
import os

load_dotenv()

# ── Password Hashing ─────────────────────────────────────────────
pwd_context = CryptContext(
    schemes=["bcrypt"],
    deprecated="auto",
    bcrypt__truncate_error=False
)

def hash_password(plain_password: str) -> str:
    """Converts plain text password into a bcrypt hash."""
    return pwd_context.hash(plain_password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Returns True if plain_password matches the stored hash."""
    return pwd_context.verify(plain_password, hashed_password)


# ── JWT Token ────────────────────────────────────────────────────
JWT_SECRET       = os.getenv("JWT_SECRET", "fallback_secret")
JWT_EXPIRE_HOURS = int(os.getenv("JWT_EXPIRE_HOURS", 168))
ALGORITHM        = "HS256"

def create_access_token(user_id: int) -> str:
    """
    Generates a signed JWT token containing the user's ID.
    Flutter stores this and sends it with future requests.
    """
    payload = {
        "sub": str(user_id),
        "exp": datetime.utcnow() + timedelta(hours=JWT_EXPIRE_HOURS)
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=ALGORITHM)


def verify_token(token: str) -> int | None:
    """
    Decodes and validates a JWT token.
    Returns the user_id (int) if valid, None if invalid or expired.
    """
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
        if user_id is None:
            return None
        return int(user_id)  # Convert back from string to int
    except JWTError:
        # Token is invalid, tampered with, or expired
        return None
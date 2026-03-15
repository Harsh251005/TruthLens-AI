# routes/auth_routes.py
# ============================================================
# Auth API endpoints:
#   POST /api/auth/signup  → Register a new user
#   POST /api/auth/login   → Authenticate existing user
# ============================================================

from fastapi import APIRouter, HTTPException
from models.schemas import SignupRequest, LoginRequest, SignupResponse, LoginResponse, UserOut
from config.database import get_db_connection
from utils.security import hash_password, verify_password, create_access_token

router = APIRouter()


# ── Signup ────────────────────────────────────────────────────────
@router.post("/signup", response_model=SignupResponse)
def signup(data: SignupRequest):
    """
    Registers a new user.
    1. Check email isn't already taken
    2. Hash the password
    3. Insert into MySQL
    4. Return user info + JWT token
    """
    conn   = get_db_connection()
    cursor = conn.cursor(dictionary=True)  # dictionary=True returns rows as dicts

    try:
        # 1. Check if email already exists
        cursor.execute("SELECT id FROM users WHERE email = %s", (data.email,))
        if cursor.fetchone():
            raise HTTPException(status_code=409, detail="Email is already registered")

        # 2. Hash password before storing
        hashed = hash_password(data.password)

        # 3. Insert new user into MySQL
        cursor.execute(
            "INSERT INTO users (name, email, password) VALUES (%s, %s, %s)",
            (data.name.strip(), data.email.lower().strip(), hashed)
        )
        conn.commit()  # Save changes to database

        new_user_id = cursor.lastrowid  # Get the auto-generated ID

        # 4. Generate JWT token for the new user
        token = create_access_token(new_user_id)

        return SignupResponse(
            message="Account created successfully",
            user=UserOut(
                id=new_user_id,
                name=data.name.strip(),
                email=data.email.lower().strip(),
                token=token
            )
        )

    except HTTPException:
        raise  # Re-raise HTTP exceptions as-is

    except Exception as e:
        conn.rollback()  # Undo any partial changes on error
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")

    finally:
        cursor.close()
        conn.close()  # Returns connection back to pool


# ── Login ─────────────────────────────────────────────────────────
@router.post("/login", response_model=LoginResponse)
def login(data: LoginRequest):
    """
    Authenticates an existing user.
    1. Find user by email
    2. Verify password against stored hash
    3. Return user info + JWT token
    """
    conn   = get_db_connection()
    cursor = conn.cursor(dictionary=True)

    try:
        # 1. Look up user by email
        cursor.execute(
            "SELECT id, name, email, password FROM users WHERE email = %s",
            (data.email.lower().strip(),)
        )
        user = cursor.fetchone()

        # Use a generic error message — don't reveal which field is wrong
        if not user:
            raise HTTPException(status_code=401, detail="Invalid email or password")

        # 2. Verify password against stored bcrypt hash
        if not verify_password(data.password, user["password"]):
            raise HTTPException(status_code=401, detail="Invalid email or password")

        # 3. Generate JWT token
        token = create_access_token(user["id"])

        return LoginResponse(
            message="Login successful",
            user=UserOut(
                id=user["id"],
                name=user["name"],
                email=user["email"],
                token=token
            )
        )

    except HTTPException:
        raise

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")

    finally:
        cursor.close()
        conn.close()
# models/schemas.py
# ============================================================
# Pydantic schemas — defines the shape of all request/response
# bodies exchanged between Flutter and FastAPI.
#
# AVATAR CHANGES (Step 2):
#   • UserOut      — now includes avatar_type + avatar_data
#   • UpdateAvatarRequest  — new: payload to set avatar
#   • UpdateAvatarResponse — new: returned after avatar update
# ============================================================

from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List


# ── Signup ────────────────────────────────────────────────────────

class SignupRequest(BaseModel):
    name:     str = Field(..., min_length=2, max_length=20)
    email:    EmailStr
    # Whitelist: only letters, digits, and # $ @ permitted.
    # Blocks injection payloads (e.g. <script>alert(1)</script>)
    # even if a client bypasses Flutter validation entirely.
    password: str = Field(..., min_length=6, pattern=r'^[a-zA-Z0-9#$@]+$')

class SignupResponse(BaseModel):
    message: str
    user:    "UserOut"


# ── Login ─────────────────────────────────────────────────────────

class LoginRequest(BaseModel):
    email:    EmailStr
    password: str = Field(..., min_length=1)

class LoginResponse(BaseModel):
    message: str
    user:    "UserOut"


# ── Update Profile ────────────────────────────────────────────────

class UpdateProfileRequest(BaseModel):
    name:             Optional[str] = Field(None, min_length=2, max_length=20)
    current_password: Optional[str] = None
    # Same whitelist — changing password via profile must follow the same rule
    new_password:     Optional[str] = Field(None, min_length=6, pattern=r'^[a-zA-Z0-9#$@]+$')

class UpdateProfileResponse(BaseModel):
    message: str
    user:    "UserOut"


# ── Avatar ────────────────────────────────────────────────────────
# NEW: Used by PUT /api/users/avatar

class UpdateAvatarRequest(BaseModel):
    """
    Payload to update a user's avatar.

    avatar_type options:
      'initial'    → reset to default letter avatar (avatar_data = None)
      'predefined' → one of the built-in emoji avatars; avatar_data = avatar ID
                     e.g. "fox", "panda", "robot" (see avatar_constants.dart)
      'custom'     → photo from device; avatar_data = base64-encoded JPEG string
    """
    avatar_type: str = Field(..., pattern="^(initial|predefined|custom)$")
    avatar_data: Optional[str] = None   # None for 'initial', ID or base64 for others

class UpdateAvatarResponse(BaseModel):
    message:     str
    avatar_type: str
    avatar_data: Optional[str] = None


# ── Forgot Password ───────────────────────────────────────────────

class ForgotPasswordRequest(BaseModel):
    email: EmailStr

class ForgotPasswordResponse(BaseModel):
    message: str

class ResetPasswordRequest(BaseModel):
    email:        EmailStr
    code:         str = Field(..., min_length=6, max_length=6)
    # Same whitelist as signup — a password reset must not open a new injection vector
    new_password: str = Field(..., min_length=6, pattern=r'^[a-zA-Z0-9#$@]+$')

class ResetPasswordResponse(BaseModel):
    message: str


# ── Deepfake Detection ────────────────────────────────────────────

class ExifAnalysis(BaseModel):
    """EXIF metadata analysis results."""
    raw_fields:      dict
    suspicion_flags: List[str]
    risk_level:      str
    summary:         str
    has_exif:        bool

class DetectionResult(BaseModel):
    """Returned after scanning an image — full rich result."""
    verdict:       str
    confidence:    float
    raw_score:     float
    message:       str
    tips:          List[str]
    explanation:   str
    exif_analysis: ExifAnalysis

class ScanHistoryItem(BaseModel):
    """Single item in scan history."""
    id:          int
    image_name:  str
    verdict:     str
    confidence:  float
    scanned_at:  str

class ScanHistoryResponse(BaseModel):
    """List of past scans."""
    message: str
    scans:   List[ScanHistoryItem]


# ── Shared ────────────────────────────────────────────────────────

class UserOut(BaseModel):
    id:          int
    name:        str
    email:       str
    token:       Optional[str] = None
    avatar_type: Optional[str] = "initial"
    avatar_data: Optional[str] = None
    is_verified: Optional[bool] = True   # ← ADD THIS


# ── Statistics ────────────────────────────────────────────────────

class StatsResponse(BaseModel):
    """User scan statistics for home screen dashboard."""
    total_scans:  int
    total_real:   int
    total_fake:   int
    last_scanned: Optional[str] = None

# ── Analytics ─────────────────────────────────────────────────────

class DailyActivity(BaseModel):
    """Scan counts for a single day — used in weekly bar chart."""
    date:       str   # 'Mon', 'Tue' etc
    total:      int
    real_count: int
    fake_count: int

class AnalyticsResponse(BaseModel):
    """Rich analytics data for the dashboard screen."""
    # Core counts
    total_scans:         int
    total_real:          int
    total_fake:          int
    # Confidence averages
    avg_confidence_real: float
    avg_confidence_fake: float
    # Weekly activity — always 7 items (Mon→Sun)
    daily_activity:      List[DailyActivity]
    # Last 10 verdicts as strings e.g. ['REAL','FAKE','REAL',...]
    verdict_trend:       List[str]
    # Personalized insight string generated on backend
    insight:             str
    last_scanned:        Optional[str] = None

# ── Badges ────────────────────────────────────────────────────────
# ADD these classes at the bottom of schemas.py

class BadgeItem(BaseModel):
    """A single badge — earned or locked."""
    id:          str            # Unique badge ID e.g. 'rookie'
    name:        str            # Display name e.g. 'Rookie'
    description: str            # How to earn it
    emoji:       str            # Visual icon
    earned:      bool           # Whether the user has unlocked it
    progress:    int            # Current progress value
    target:      int            # Value needed to unlock
    category:    str            # 'scans' | 'fakes' | 'streak'

class BadgesResponse(BaseModel):
    """Full badges response."""
    badges:         List[BadgeItem]
    earned_count:   int
    total_count:    int
    current_streak: int
    longest_streak: int         # For future use

# ── Challenge / Leaderboard ───────────────────────────────────────

class SaveScoreRequest(BaseModel):
    score:     int
    total:     int
    accuracy:  float
    max_combo: int
    grade:     str = Field(..., min_length=1, max_length=2)

class LeaderboardEntry(BaseModel):
    rank:       int
    user_id:    int
    name:       str
    avatar_type: str
    avatar_data: Optional[str] = None
    score:      int
    total:      int
    accuracy:   float
    max_combo:  int
    grade:      str
    played_at:  str

class PersonalBest(BaseModel):
    score:     int
    total:     int
    accuracy:  float
    max_combo: int
    grade:     str
    played_at: str

class LeaderboardResponse(BaseModel):
    entries:       List[LeaderboardEntry]
    user_rank:     Optional[int] = None
    personal_best: Optional[PersonalBest] = None
    total_players: int

# ── Email Verification ────────────────────────────────────────────

class VerifyEmailRequest(BaseModel):
    email: EmailStr
    code:  str = Field(..., min_length=6, max_length=6)

class VerifyEmailResponse(BaseModel):
    message: str
    token:   str        # JWT token — user lands on home screen after verify
    user:    "UserOut"

class ResendVerificationRequest(BaseModel):
    email: EmailStr

class ResendVerificationResponse(BaseModel):
    message: str

# ── Account Management ────────────────────────────────────────────

class DeleteAccountRequest(BaseModel):
    password: str = Field(..., min_length=1)

class ResetAccountResponse(BaseModel):
    message: str
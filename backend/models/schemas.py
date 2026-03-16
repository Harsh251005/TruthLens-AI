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
    name:     str = Field(..., min_length=2, max_length=100)
    email:    EmailStr
    password: str = Field(..., min_length=6)

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
    name:             Optional[str] = Field(None, min_length=2, max_length=100)
    current_password: Optional[str] = None
    new_password:     Optional[str] = Field(None, min_length=6)

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
    new_password: str = Field(..., min_length=6)

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
    """
    Safe user object returned to the client — never includes password.

    Avatar fields:
      avatar_type — 'initial' | 'predefined' | 'custom'
      avatar_data — predefined ID string OR base64 JPEG for custom photos.
                    None when avatar_type == 'initial'.
    """
    id:          int
    name:        str
    email:       str
    token:       Optional[str] = None

    # Avatar fields — optional so old login tokens stay compatible
    avatar_type: Optional[str] = "initial"
    avatar_data: Optional[str] = None


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
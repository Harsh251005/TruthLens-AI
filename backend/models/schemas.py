# models/schemas.py
# ============================================================
# Pydantic schemas define the shape of data for:
#   - Request bodies  (what Flutter sends to us)
#   - Response bodies (what we send back to Flutter)
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
    raw_fields:      dict        # Human-readable EXIF fields
    suspicion_flags: List[str]   # List of suspicious findings
    risk_level:      str         # 'LOW', 'MEDIUM', 'HIGH', or 'UNKNOWN'
    summary:         str         # One-line summary
    has_exif:        bool        # Whether EXIF data was found

class DetectionResult(BaseModel):
    """Returned after scanning an image — full rich result."""
    verdict:            str           # 'REAL' or 'FAKE'
    confidence:         float         # Confidence percentage e.g. 94.5
    raw_score:          float         # Raw model output 0-1
    message:            str           # Short verdict message
    tips:               List[str]     # Quick tips for the user
    explanation:        str           # LLM-generated human explanation
    exif_analysis:      ExifAnalysis  # Full EXIF metadata analysis

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
    """Safe user object — never includes password."""
    id:    int
    name:  str
    email: str
    token: Optional[str] = None


# ── Statistics (NEW) ──────────────────────────────────────────────

class StatsResponse(BaseModel):
    """User scan statistics for home screen dashboard."""
    total_scans:  int
    total_real:   int
    total_fake:   int
    last_scanned: Optional[str] = None  # Date of most recent scan
# main.py
# ============================================================
# FastAPI application entry point.
# Run the server with:
#   uvicorn main:app --reload --host 0.0.0.0 --port 8000
# ============================================================

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
import os
from routes.badges_routes import router as badges_router

# Load .env before anything else
load_dotenv()

# ── App Instance ─────────────────────────────────────────────────
app = FastAPI(
    title="TruthLens AI API",
    description="Deepfake detection backend for TruthLens AI Flutter app",
    version="1.0.0",
)

# ── CORS Middleware ───────────────────────────────────────────────
# Allows the Flutter app (and Swagger UI) to call this API.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routes ────────────────────────────────────────────────────────
from routes import auth_routes, user_routes, password_routes, detect_routes  # noqa: E402
app.include_router(auth_routes.router, prefix="/api/auth",     tags=["Auth"])
app.include_router(user_routes.router, prefix="/api/users",    tags=["Users"])
app.include_router(password_routes.router, prefix="/api/password", tags=["Password"])
app.include_router(detect_routes.router, prefix="/api/detect", tags=["Detection"])
app.include_router(badges_router, prefix="/api/badges", tags=["badges"])


# ── Health Check ─────────────────────────────────────────────────
@app.get("/", tags=["Health"])
def root():
    """Quick health check — confirms the server is running."""
    return {"status": "ok", "message": "TruthLens AI API is running 🚀"}


# ── Dev Server ────────────────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=os.getenv("APP_HOST", "0.0.0.0"),
        port=int(os.getenv("APP_PORT", 8000)),
        reload=True,
    )
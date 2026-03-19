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
from routes.account_routes import router as account_router
from routes.news_routes import router as news_router          # ← NEW
from fastapi.staticfiles import StaticFiles
import pathlib

load_dotenv()

# ── App Instance ──────────────────────────────────────────────
app = FastAPI(
    title="TruthLens AI API",
    description="Deepfake detection backend for TruthLens AI Flutter app",
    version="1.0.0",
)

app.mount(
    "/static",
    StaticFiles(directory=pathlib.Path(__file__).parent / "static"),
    name="static",
)

# ── CORS Middleware ───────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routes ────────────────────────────────────────────────────
from routes import auth_routes, user_routes, password_routes, detect_routes
from routes.challenge_routes import router as challenge_router

app.include_router(auth_routes.router,    prefix="/api/auth",      tags=["Auth"])
app.include_router(user_routes.router,    prefix="/api/users",     tags=["Users"])
app.include_router(password_routes.router,prefix="/api/password",  tags=["Password"])
app.include_router(detect_routes.router,  prefix="/api/detect",    tags=["Detection"])
app.include_router(badges_router,         prefix="/api/badges",    tags=["Badges"])
app.include_router(challenge_router,      prefix="/api/challenge", tags=["Challenge"])
app.include_router(account_router,        prefix="/api/account",   tags=["Account"])
app.include_router(news_router,           prefix="/api/news",      tags=["News"])  # ← NEW

# ── Health Check ──────────────────────────────────────────────
@app.get("/", tags=["Health"])
def root():
    return {"status": "ok", "message": "TruthLens AI API is running 🚀"}

# ── Dev Server ────────────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=os.getenv("APP_HOST", "0.0.0.0"),
        port=int(os.getenv("APP_PORT", 8000)),
        reload=True,
    )
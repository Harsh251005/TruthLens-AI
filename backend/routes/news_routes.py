# routes/news_routes.py
# ============================================================
# News endpoints:
#   GET /api/news/         → returns shared cached news feed
#   POST /api/news/refresh → force-refreshes cache (admin use)
#
# All users receive the same cached response — no per-user
# API calls. Cache is refreshed server-side once every 23h.
# ============================================================

from fastapi import APIRouter, Query
from services.news_service import get_cached_news

router = APIRouter()


# ── GET /api/news/ ────────────────────────────────────────────
@router.get("/")
def get_news():
    """
    Returns the server-side cached multi-category news feed.
    Served identically to all users — one cache for everyone.

    Response shape:
    {
      "fetched_at": "2026-03-19T10:00:00+00:00",
      "is_fallback": false,
      "categories": [
        {
          "id": "deepfake",
          "label": "Deepfakes",
          "color_hex": "#EF4444",
          "articles": [
            {
              "title": "...",
              "description": "...",
              "source": "BBC",
              "url": "https://...",
              "image_url": "https://...",
              "published_at": "2026-03-19T08:00:00Z"
            }
          ]
        },
        ...
      ]
    }
    """
    return get_cached_news(force_refresh=False)


# ── POST /api/news/refresh ─────────────────────────────────────
@router.post("/refresh")
def refresh_news():
    """
    Force-refreshes the news cache regardless of TTL.
    Intended for admin/cron use — not called by Flutter clients.
    Returns the fresh cache after fetching.
    """
    result = get_cached_news(force_refresh=True)
    return {
        "message":    "Cache refreshed successfully",
        "fetched_at": result.get("fetched_at"),
        "article_count": sum(
            len(c["articles"]) for c in result.get("categories", [])
        ),
    }
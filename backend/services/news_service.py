# services/news_service.py
# ============================================================
# Multi-category news fetcher with server-side shared cache.
#
# DESIGN:
#   - Fetches news in 9 categories using ~90 of the 100 daily
#     NewsAPI requests (10 per category).
#   - Results are cached server-side in a JSON file, shared
#     across ALL users — one fetch serves everyone.
#   - Cache refreshes once every 23 hours (safely within the
#     NewsAPI daily reset window of 24h).
#   - Flutter clients call GET /api/news/ and receive the
#     cached results instantly — no per-user API calls.
#
# REQUEST BUDGET (100/day limit):
#   9 categories × 10 articles = 90 requests used
#   10 requests kept as buffer for retries/errors
# ============================================================

import os
import json
import time
import requests
from datetime import datetime, timezone
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

NEWS_API_KEY   = os.getenv("NEWS_API_KEY")
NEWS_API_BASE  = "https://newsapi.org/v2/everything"

# ── Cache config ──────────────────────────────────────────────
# Stored as a flat JSON file on the server — zero DB overhead.
# All users read the same file.
CACHE_FILE     = Path(__file__).parent.parent / "static" / "news_cache.json"
CACHE_TTL_SECS = 23 * 60 * 60  # 23 hours — refresh once per day

# ── Category definitions ──────────────────────────────────────
# Each entry uses 10 requests (pageSize=10, 1 API call each).
# Total: 9 categories × 1 call × 10 articles = 90 requests/day.
#
# 'query'    — NewsAPI `q` parameter (supports AND/OR/NOT)
# 'label'    — Display name shown in the Flutter UI
# 'color_hex'— Accent color for the category chip in Flutter
NEWS_CATEGORIES = [
    {
        "id":        "deepfake",
        "label":     "Deepfakes",
        "query":     "deepfake OR \"deep fake\" OR \"face swap\"",
        "color_hex": "#EF4444",  # Red
    },
    {
        "id":        "ai_fraud",
        "label":     "AI Fraud",
        "query":     "\"AI fraud\" OR \"voice clone\" OR \"synthetic media fraud\"",
        "color_hex": "#F59E0B",  # Amber
    },
    {
        "id":        "cybersecurity",
        "label":     "Cybersecurity",
        "query":     "cybersecurity AND (\"artificial intelligence\" OR \"AI attack\" OR \"AI threat\")",
        "color_hex": "#4F8EF7",  # Blue
    },
    {
        "id":        "ai_ethics",
        "label":     "AI Ethics",
        "query":     "\"AI ethics\" OR \"algorithmic bias\" OR \"responsible AI\"",
        "color_hex": "#A855F7",  # Purple
    },
    {
        "id":        "misinformation",
        "label":     "Misinformation",
        "query":     "misinformation AND (\"artificial intelligence\" OR \"AI-generated\")",
        "color_hex": "#EC4899",  # Pink
    },
    {
        "id":        "ai_regulation",
        "label":     "AI Regulation",
        "query":     "\"AI regulation\" OR \"AI law\" OR \"AI Act\" OR \"AI legislation\"",
        "color_hex": "#10B981",  # Green
    },
    {
        "id":        "detection_tech",
        "label":     "Detection Tech",
        "query":     "\"deepfake detection\" OR \"AI detection\" OR \"media authentication\"",
        "color_hex": "#06B6D4",  # Cyan
    },
    {
        "id":        "privacy",
        "label":     "Privacy & Surveillance",
        "query":     "\"facial recognition\" OR \"AI surveillance\" OR \"biometric privacy\"",
        "color_hex": "#64748B",  # Slate
    },
    {
        "id":        "generative_ai",
        "label":     "Generative AI",
        "query":     "\"generative AI\" AND (misuse OR risk OR harm OR abuse OR safety)",
        "color_hex": "#F97316",  # Orange
    },
]


# ── Main public function ──────────────────────────────────────

def get_cached_news(force_refresh: bool = False) -> dict:
    """
    Returns the shared news cache. Refreshes if:
      - Cache file doesn't exist
      - Cache is older than CACHE_TTL_SECS
      - force_refresh is True

    Called by the /api/news/ route for ALL users.
    Returns: { "categories": [...], "fetched_at": "ISO timestamp" }
    """
    if not force_refresh and _is_cache_valid():
        return _load_cache()

    print("🔄 News cache expired or missing — refreshing...")
    fresh = _fetch_all_categories()

    if fresh["categories"]:
        _save_cache(fresh)
        print(f"✅ News cache refreshed: {sum(len(c['articles']) for c in fresh['categories'])} articles across {len(fresh['categories'])} categories")
        return fresh

    # If fetch failed entirely, return stale cache rather than empty
    stale = _load_cache()
    if stale:
        print("⚠️  Fetch failed — serving stale cache")
        return stale

    # Last resort: empty structure
    return {"categories": [], "fetched_at": None, "is_fallback": True}


# ── Cache helpers ─────────────────────────────────────────────

def _is_cache_valid() -> bool:
    """True if cache file exists and is younger than CACHE_TTL_SECS."""
    if not CACHE_FILE.exists():
        return False
    age = time.time() - CACHE_FILE.stat().st_mtime
    return age < CACHE_TTL_SECS


def _load_cache() -> dict:
    """Load and return the cache file. Returns {} on error."""
    try:
        with open(CACHE_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        print(f"⚠️  Failed to load news cache: {e}")
        return {}


def _save_cache(data: dict) -> None:
    """Write data to the cache file. Creates parent dirs if needed."""
    try:
        CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(CACHE_FILE, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
    except Exception as e:
        print(f"⚠️  Failed to save news cache: {e}")


# ── NewsAPI fetcher ───────────────────────────────────────────

def _fetch_all_categories() -> dict:
    """
    Fires one NewsAPI request per category (9 total = 90 requests).
    Returns structured data ready to cache and serve.
    """
    if not NEWS_API_KEY:
        print("⚠️  NEWS_API_KEY not set — cannot fetch news")
        return {"categories": [], "fetched_at": None}

    results     = []
    request_count = 0

    for cat in NEWS_CATEGORIES:
        articles = _fetch_category(cat)
        request_count += 1

        if articles:
            results.append({
                "id":        cat["id"],
                "label":     cat["label"],
                "color_hex": cat["color_hex"],
                "articles":  articles,
            })

        # Small delay between requests to be respectful to NewsAPI
        time.sleep(0.3)

    print(f"📡 NewsAPI: used {request_count} requests this refresh")

    return {
        "categories":  results,
        "fetched_at":  datetime.now(timezone.utc).isoformat(),
        "is_fallback": False,
    }


def _fetch_category(cat: dict) -> list[dict]:
    """
    Fetch up to 10 articles for one category from NewsAPI /everything.
    Returns a list of clean article dicts, or [] on error.
    """
    try:
        response = requests.get(
            NEWS_API_BASE,
            params={
                "apiKey":   NEWS_API_KEY,
                "q":        cat["query"],
                "language": "en",
                "sortBy":   "publishedAt",   # Freshest first
                "pageSize": 10,
            },
            timeout=10,
        )

        if response.status_code != 200:
            print(f"⚠️  NewsAPI error for '{cat['id']}': HTTP {response.status_code}")
            return []

        data     = response.json()
        raw_list = data.get("articles", [])

        # Clean and filter articles
        cleaned = []
        for a in raw_list:
            title = a.get("title", "") or ""
            desc  = a.get("description", "") or ""
            url   = a.get("url", "") or ""

            # Skip removed/empty articles
            if title == "[Removed]" or not url or not title:
                continue

            cleaned.append({
                "title":        title,
                "description":  desc or "No description available.",
                "source":       (a.get("source") or {}).get("name", "Unknown"),
                "url":          url,
                "image_url":    a.get("urlToImage"),
                "published_at": a.get("publishedAt", ""),
            })

        return cleaned

    except Exception as e:
        print(f"⚠️  Exception fetching '{cat['id']}': {e}")
        return []
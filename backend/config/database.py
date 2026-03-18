# config/database.py
# ============================================================
# Manages the MySQL connection pool.
# All other modules import `get_db_connection()` from here.
# ============================================================

from mysql.connector import pooling
from dotenv import load_dotenv
import os

# Load environment variables from .env file
load_dotenv()

# ── Connection Pool Configuration ────────────────────────────────
# A pool keeps several connections open and reuses them,
# which is faster than opening a new connection per request.
db_config = {
    "host":     os.getenv("DB_HOST", "localhost"),
    "port":     int(os.getenv("DB_PORT", 3306)),
    "user":     os.getenv("DB_USER", "root"),
    "password": os.getenv("DB_PASSWORD", ""),
    "database": os.getenv("DB_NAME", "auth_db"),
}

# Create the pool once when the module is first imported
try:
    connection_pool = pooling.MySQLConnectionPool(
        pool_name="auth_pool",
        pool_size=5,          # Max 5 simultaneous connections
        **db_config
    )
    print("✅  MySQL connection pool created successfully")
except Exception as e:
    print(f"❌  Failed to create MySQL pool: {e}")
    raise


def get_db_connection():
    """
    Returns a connection from the pool.
    Always call connection.close() after use — it returns
    the connection to the pool (doesn't actually close it).
    """
    return connection_pool.get_connection()
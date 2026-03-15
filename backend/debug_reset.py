# debug_reset.py
# Run this in your backend directory to diagnose the reset flow

from config.database import get_db_connection
from datetime import datetime

conn   = get_db_connection()
cursor = conn.cursor(dictionary=True)

# ── Change this to the email you are testing with ─────────────────
email = "dharnidharkaharsh@gmail.com"
# ─────────────────────────────────────────────────────────────────

email = email.lower().strip()

# Step 1 — Check if user exists
cursor.execute("SELECT id, email FROM users WHERE email = %s", (email,))
user = cursor.fetchone()
print("1. User found:", user)

if user:
    # Step 2 — Check existing tokens
    cursor.execute("SELECT * FROM reset_tokens WHERE user_id = %s", (user["id"],))
    tokens = cursor.fetchall()
    print("2. Existing tokens:", tokens)

    # Step 3 — Check DB time vs Python time
    cursor.execute("SELECT UTC_TIMESTAMP() as db_time")
    db_time = cursor.fetchone()
    print("3. DB UTC time:     ", db_time["db_time"])
    print("4. Python UTC time: ", datetime.utcnow())
else:
    print("❌ User not found in database for email:", email)

cursor.close()
conn.close()
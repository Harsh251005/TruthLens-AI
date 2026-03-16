# config/email.py
# ============================================================
# Email configuration using fastapi-mail.
# Uses Gmail SMTP to send password reset codes.
# ============================================================

from fastapi_mail import FastMail, MessageSchema, ConnectionConfig, MessageType
from dotenv import load_dotenv
import os

load_dotenv()

# ── Gmail SMTP Configuration ──────────────────────────────────────
conf = ConnectionConfig(
    MAIL_USERNAME=os.getenv("MAIL_USERNAME"),
    MAIL_PASSWORD=os.getenv("MAIL_PASSWORD"),
    MAIL_FROM=os.getenv("MAIL_USERNAME"),
    MAIL_PORT=465,                              # Changed from 587 — Render blocks 587
    MAIL_SERVER="smtp.gmail.com",
    MAIL_STARTTLS=False,                        # Disabled — not used with SSL
    MAIL_SSL_TLS=True,                          # Enabled — port 465 uses SSL
    USE_CREDENTIALS=True,
)

# FastMail instance — used to send emails
fast_mail = FastMail(conf)


async def send_reset_email(email: str, code: str):
    """
    Sends a password reset code to the user's email.
    The code expires in 15 minutes.
    """
    message = MessageSchema(
        subject="Password Reset Code — TruthLens AI",
        recipients=[email],
        body=f"""
        <html>
        <body style="font-family: Arial, sans-serif; padding: 20px;">
            <h2 style="color: #2D6CDF;">Password Reset Request</h2>
            <p>You requested to reset your password. Use the code below:</p>
            <div style="
                background: #F5F7FB;
                border-radius: 12px;
                padding: 20px;
                text-align: center;
                margin: 20px 0;
            ">
                <h1 style="
                    color: #2D6CDF;
                    font-size: 40px;
                    letter-spacing: 8px;
                    margin: 0;
                ">{code}</h1>
            </div>
            <p>This code expires in <strong>15 minutes</strong>.</p>
            <p>If you didn't request this, ignore this email.</p>
            <hr style="border: none; border-top: 1px solid #E5E7EB;">
            <p style="color: #6B7280; font-size: 12px;">TruthLens AI</p>
        </body>
        </html>
        """,
        subtype=MessageType.html,
    )

    await fast_mail.send_message(message)
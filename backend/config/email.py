# config/email.py
# ============================================================
# Email configuration using Resend API.
# Switched from Gmail SMTP (blocked by Render free tier)
# to Resend which sends over HTTPS — works on all platforms.
# ============================================================

import os
import resend
from dotenv import load_dotenv

load_dotenv()

# ── Resend Configuration ──────────────────────────────────────────
resend.api_key = os.getenv("RESEND_API_KEY")

# Sender address — must use Resend's default domain until you
# verify your own domain in the Resend dashboard
MAIL_FROM = "TruthLens AI <noreply@truthlensai.in>"


async def send_reset_email(email: str, code: str):
    """
    Sends a password reset code to the user's email via Resend API.
    The code expires in 15 minutes.
    """
    params = {
        "from":    MAIL_FROM,
        "to":      [email],
        "subject": "Password Reset Code — TruthLens AI",
        "html":    f"""
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
    }

    resend.Emails.send(params)
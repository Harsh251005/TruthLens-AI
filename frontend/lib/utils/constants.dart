// lib/utils/constants.dart
// ============================================================
// App-wide constants — API URLs, timeout, validation rules.
// Change baseUrl here when deploying to production.
// ============================================================

class AppConstants {
  // ── API Base URL ─────────────────────────────────────────────
  static const String baseUrl = 'https://truthlens-backend-44mg.onrender.com';

  // ── Auth Endpoints ────────────────────────────────────────────
  static const String loginEndpoint          = '$baseUrl/api/auth/login';
  static const String signupEndpoint         = '$baseUrl/api/auth/signup';
  static const String profileEndpoint        = '$baseUrl/api/users/me';
  static const String updateEndpoint         = '$baseUrl/api/users/update';
  static const String updateProfileEndpoint  = '$baseUrl/api/users/update';
  static const String verifyEmailEndpoint    = '$baseUrl/api/auth/verify';
  static const String resendOtpEndpoint      = '$baseUrl/api/auth/resend';
  static const String deleteAccountEndpoint  = '$baseUrl/api/account/delete';
  static const String resetAccountEndpoint   = '$baseUrl/api/account/reset';

  // ── Avatar Endpoint ───────────────────────────────────────────
  static const String updateAvatarEndpoint   = '$baseUrl/api/users/avatar';

  // ── Challenge / Leaderboard Endpoints ────────────────────────
  static const String challengeEndpoint      = '$baseUrl/api/challenge/round';
  static const String saveScoreEndpoint      = '$baseUrl/api/challenge/score';
  static const String leaderboardEndpoint    = '$baseUrl/api/challenge/leaderboard';

  // ── Password Endpoints ────────────────────────────────────────
  static const String forgotEndpoint         = '$baseUrl/api/password/forgot';
  static const String resetEndpoint          = '$baseUrl/api/password/reset';
  static const String forgotPasswordEndpoint = '$baseUrl/api/password/forgot';
  static const String resetPasswordEndpoint  = '$baseUrl/api/password/reset';

  // ── Detection Endpoints ───────────────────────────────────────
  static const String detectEndpoint         = '$baseUrl/api/detect/';
  static const String historyEndpoint        = '$baseUrl/api/detect/history';
  static const String statsEndpoint          = '$baseUrl/api/detect/stats';
  static const String analyticsEndpoint      = '$baseUrl/api/detect/analytics';
  static const String badgesEndpoint         = '$baseUrl/api/badges/';

  /// Builds delete URL for a single scan by ID
  static String deleteScanEndpoint(int scanId) =>
      '$baseUrl/api/detect/history/$scanId';

  // ── News Endpoint ─────────────────────────────────────────────
  // Points to our own backend which serves the shared server-side
  // cache — no direct NewsAPI calls from Flutter anymore.
  // REMOVED: newsApiKey and newsApiEndpoint (direct NewsAPI calls)
  static const String newsEndpoint = '$baseUrl/api/news/';

  // ── API Keys (from --dart-define-from-file=env.json) ─────────
  // env.json is gitignored; see env.example.json. With no OpenAI
  // key, scans use the built-in explanation text.
  static const String openAiApiKey = String.fromEnvironment('OPENAI_API_KEY');
  static const String openAiModel  = String.fromEnvironment(
      'OPENAI_MODEL', defaultValue: 'gpt-4.1-mini');
  static const String newsApiKey   = String.fromEnvironment('NEWS_API_KEY');

  // ── Timeouts ──────────────────────────────────────────────────
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration emailTimeout   = Duration(seconds: 60);

  // ── Validation ────────────────────────────────────────────────
  static const int minPasswordLength = 6;
  static const int maxNameLength     = 20;
}
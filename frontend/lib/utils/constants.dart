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
  static const String verifyEmailEndpoint = '$baseUrl/api/auth/verify';
  static const String resendOtpEndpoint   = '$baseUrl/api/auth/resend';
  static const String deleteAccountEndpoint = '$baseUrl/api/account/delete';
  static const String resetAccountEndpoint  = '$baseUrl/api/account/reset';

  // ── Avatar Endpoint ───────────────────────────────────────────
  // NEW: PUT /api/users/avatar — saves chosen avatar to DB
  static const String updateAvatarEndpoint   = '$baseUrl/api/users/avatar';

  static const String challengeEndpoint = '$baseUrl/api/challenge/round';
  static const String saveScoreEndpoint    = '$baseUrl/api/challenge/score';
  static const String leaderboardEndpoint  = '$baseUrl/api/challenge/leaderboard';

  // ── Password Endpoints ────────────────────────────────────────
  static const String forgotEndpoint         = '$baseUrl/api/password/forgot';
  static const String resetEndpoint          = '$baseUrl/api/password/reset';
  static const String forgotPasswordEndpoint = '$baseUrl/api/password/forgot';
  static const String resetPasswordEndpoint  = '$baseUrl/api/password/reset';

  // ── Detection Endpoints ───────────────────────────────────────
  static const String detectEndpoint  = '$baseUrl/api/detect/';
  static const String historyEndpoint = '$baseUrl/api/detect/history';
  static const String statsEndpoint   = '$baseUrl/api/detect/stats';
  static const String analyticsEndpoint = '$baseUrl/api/detect/analytics';
  static const String badgesEndpoint = '$baseUrl/api/badges/';

  /// Builds delete URL for a single scan by ID
  static String deleteScanEndpoint(int scanId) =>
      '$baseUrl/api/detect/history/$scanId';

  // ── Timeouts ──────────────────────────────────────────────────
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration emailTimeout   = Duration(seconds: 60);

  // ── Validation ────────────────────────────────────────────────
  static const int minPasswordLength = 6;
  static const int maxNameLength     = 100;

  // ── NewsAPI ───────────────────────────────────────────────────────
  static const String newsApiKey      = '007e398a4c0b4630b6bbd24bfddb21d1';
  static const String newsApiEndpoint =
      'https://newsapi.org/v2/everything?'
      'q=deepfake+OR+"deep+fake"+OR+"synthetic+media"'
      '&language=en'
      '&sortBy=publishedAt'
      '&pageSize=20'
      '&apiKey=${newsApiKey}';
}
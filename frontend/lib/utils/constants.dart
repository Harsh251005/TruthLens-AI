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

  // ── Avatar Endpoint ───────────────────────────────────────────
  // NEW: PUT /api/users/avatar — saves chosen avatar to DB
  static const String updateAvatarEndpoint   = '$baseUrl/api/users/avatar';

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
}
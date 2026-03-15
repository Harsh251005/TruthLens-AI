// lib/utils/constants.dart
// ============================================================
// App-wide constants — API URLs, timeout, validation rules.
// Change baseUrl here when deploying to production.
// ============================================================

class AppConstants {
  // ── API Base URL ─────────────────────────────────────────────
  // Update this if your IP changes (run ipconfig to check)
  static const String baseUrl = 'http://192.168.1.39:8000/api';

  // ── Auth Endpoints ────────────────────────────────────────────
  static const String loginEndpoint          = '$baseUrl/auth/login';
  static const String signupEndpoint         = '$baseUrl/auth/signup';
  static const String profileEndpoint        = '$baseUrl/users/me';
  static const String updateEndpoint         = '$baseUrl/users/update';
  static const String updateProfileEndpoint  = '$baseUrl/users/update';

  // ── Password Endpoints ────────────────────────────────────────
  static const String forgotEndpoint         = '$baseUrl/password/forgot';
  static const String resetEndpoint          = '$baseUrl/password/reset';
  static const String forgotPasswordEndpoint = '$baseUrl/password/forgot';
  static const String resetPasswordEndpoint  = '$baseUrl/password/reset';

  // ── Detection Endpoints ───────────────────────────────────────
  static const String detectEndpoint  = '$baseUrl/detect/';
  static const String historyEndpoint = '$baseUrl/detect/history';
  static const String statsEndpoint   = '$baseUrl/detect/stats';

  /// Builds delete URL for a single scan by ID
  static String deleteScanEndpoint(int scanId) =>
      '$baseUrl/detect/history/$scanId';

  // ── Timeouts ──────────────────────────────────────────────────
  static const Duration requestTimeout = Duration(seconds: 30);

  // ── Validation ────────────────────────────────────────────────
  static const int minPasswordLength = 6;
  static const int maxNameLength     = 100;
}
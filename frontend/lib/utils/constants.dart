// lib/utils/constants.dart
// ============================================================
// App-wide constants — API keys, timeouts, validation rules.
// There is no backend: data lives in Firebase, detection runs
// on the device.
// ============================================================

class AppConstants {
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
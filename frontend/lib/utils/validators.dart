// utils/validators.dart
// ============================================================
// Centralised form validation functions.
// Returns null on success, error string on failure.
// ============================================================

import 'constants.dart';

class Validators {
  Validators._(); // Prevent instantiation — static only class

  /// Validates email format
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w\-.]+@[\w\-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  /// Validates password length
  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < AppConstants.minPasswordLength) {
      return 'Password must be at least ${AppConstants.minPasswordLength} characters';
    }
    return null;
  }

  /// Validates user display name
  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) return 'Name is required';
    if (value.trim().length > AppConstants.maxNameLength) {
      return 'Name must be under ${AppConstants.maxNameLength} characters';
    }
    return null;
  }

  /// Validates confirm password matches original
  static String? confirmPassword(String? confirmValue, String original) {
    if (confirmValue == null || confirmValue.isEmpty) {
      return 'Please confirm your password';
    }
    if (confirmValue != original) return 'Passwords do not match';
    return null;
  }
}
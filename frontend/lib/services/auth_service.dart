// services/auth_service.dart
// ============================================================
// Handles all HTTP communication with the FastAPI backend.
// Saves user session locally after successful auth.
// Sends JWT token in headers for protected routes.
// ============================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../utils/constants.dart';
import 'storage_service.dart';

class AuthResult {
  final bool success;
  final String message;
  final UserModel? user;

  const AuthResult({
    required this.success,
    required this.message,
    this.user,
  });
}

class AuthService {
  // ── Standard headers for public routes ───────────────────────
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept':       'application/json',
  };

  /// Builds headers with JWT token for protected routes
  static Map<String, String> _authHeaders(String token) => {
    'Content-Type':  'application/json',
    'Accept':        'application/json',
    'Authorization': 'Bearer $token',
  };

  // ── Login ─────────────────────────────────────────────────────
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
        Uri.parse(AppConstants.loginEndpoint),
        headers: _headers,
        body: jsonEncode({'email': email, 'password': password}),
      )
          .timeout(AppConstants.requestTimeout);

      final result = _handleResponse(response);
      if (result.success && result.user != null) {
        await StorageService.saveUser(result.user!);
      }
      return result;
    } catch (e) {
      return AuthResult(success: false, message: _friendlyError(e));
    }
  }

  // ── Signup ────────────────────────────────────────────────────
  Future<AuthResult> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
        Uri.parse(AppConstants.signupEndpoint),
        headers: _headers,
        body: jsonEncode({
          'name':     name,
          'email':    email,
          'password': password,
        }),
      )
          .timeout(AppConstants.requestTimeout);

      final result = _handleResponse(response);
      if (result.success && result.user != null) {
        await StorageService.saveUser(result.user!);
      }
      return result;
    } catch (e) {
      return AuthResult(success: false, message: _friendlyError(e));
    }
  }

  // ── Get Profile (Protected) ───────────────────────────────────
  Future<AuthResult> getProfile() async {
    try {
      final savedUser = await StorageService.getSavedUser();
      if (savedUser == null) {
        return const AuthResult(success: false, message: 'Not logged in');
      }

      final response = await http
          .get(
        Uri.parse(AppConstants.profileEndpoint),
        headers: _authHeaders(savedUser.token),
      )
          .timeout(AppConstants.requestTimeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final user = UserModel.fromJson(body['user'] as Map<String, dynamic>);
        return AuthResult(success: true, message: 'Success', user: user);
      } else if (response.statusCode == 401) {
        await StorageService.clearUser();
        return const AuthResult(
          success: false,
          message: 'Session expired. Please login again.',
        );
      } else {
        return const AuthResult(
          success: false,
          message: 'Failed to fetch profile',
        );
      }
    } catch (e) {
      return AuthResult(success: false, message: _friendlyError(e));
    }
  }

  // ── Update Profile (Protected) ────────────────────────────────
  Future<AuthResult> updateProfile({
    String? name,
    String? currentPassword,
    String? newPassword,
  }) async {
    try {
      final savedUser = await StorageService.getSavedUser();
      if (savedUser == null) {
        return const AuthResult(success: false, message: 'Not logged in');
      }

      final Map<String, dynamic> body = {};
      if (name != null && name.isNotEmpty) body['name'] = name;
      if (currentPassword != null) body['current_password'] = currentPassword;
      if (newPassword != null) body['new_password'] = newPassword;

      final response = await http
          .put(
        Uri.parse(AppConstants.updateProfileEndpoint),
        headers: _authHeaders(savedUser.token),
        body: jsonEncode(body),
      )
          .timeout(AppConstants.requestTimeout);

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
        final updatedUser = UserModel.fromJson(
          responseBody['user'] as Map<String, dynamic>,
        );

        if (name != null) {
          await StorageService.saveUser(UserModel(
            id:    savedUser.id,
            name:  updatedUser.name,
            email: savedUser.email,
            token: savedUser.token,
          ));
        }

        return AuthResult(
          success: true,
          message: responseBody['message'] as String? ?? 'Updated successfully',
          user: updatedUser,
        );
      } else {
        final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
        return AuthResult(
          success: false,
          message: responseBody['detail'] as String? ?? 'Update failed',
        );
      }
    } catch (e) {
      return AuthResult(success: false, message: _friendlyError(e));
    }
  }

  // ── Forgot Password ───────────────────────────────────────────
  /// Sends a 6-digit reset code to the user's email
  Future<AuthResult> forgotPassword({required String email}) async {
    try {
      final response = await http
          .post(
        Uri.parse(AppConstants.forgotPasswordEndpoint),
        headers: _headers,
        body: jsonEncode({'email': email}),
      )
          .timeout(AppConstants.requestTimeout);

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return AuthResult(
          success: true,
          message: body['message'] as String? ?? 'Reset code sent',
        );
      } else {
        // Read 'detail' field for error responses (FastAPI standard)
        return AuthResult(
          success: false,
          message: body['detail'] as String? ?? 'Something went wrong',
        );
      }
    } catch (e) {
      return AuthResult(success: false, message: _friendlyError(e));
    }
  }

  // ── Reset Password ────────────────────────────────────────────
  /// Verifies the 6-digit code and sets a new password
  Future<AuthResult> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final response = await http
          .post(
        Uri.parse(AppConstants.resetPasswordEndpoint),
        headers: _headers,
        body: jsonEncode({
          'email':        email,
          'code':         code,
          'new_password': newPassword,
        }),
      )
          .timeout(AppConstants.requestTimeout);

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return AuthResult(
          success: true,
          message: body['message'] as String? ?? 'Password reset successfully',
        );
      } else {
        return AuthResult(
          success: false,
          message: body['detail'] as String? ?? 'Reset failed',
        );
      }
    } catch (e) {
      return AuthResult(success: false, message: _friendlyError(e));
    }
  }

  // ── Helpers ───────────────────────────────────────────────────

  AuthResult _handleResponse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 || response.statusCode == 201) {
      final user = UserModel.fromJson(body['user'] as Map<String, dynamic>);
      return AuthResult(
        success: true,
        message: body['message'] as String? ?? 'Success',
        user: user,
      );
    } else {
      return AuthResult(
        success: false,
        message: body['detail'] as String? ?? 'Something went wrong',
      );
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return 'Cannot reach server. Check your connection.';
    } else if (msg.contains('TimeoutException')) {
      return 'Request timed out. Please try again.';
    }
    return 'An unexpected error occurred. Please try again.';
  }
}
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../utils/constants.dart';
import 'storage_service.dart';

class AuthResult {
  final bool      success;
  final String    message;
  final UserModel? user;

  const AuthResult({
    required this.success,
    required this.message,
    this.user,
  });
}

class AuthService {

  // ── Headers ───────────────────────────────────────────────────
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Accept':       'application/json',
  };

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
      final response = await http.post(
        Uri.parse(AppConstants.loginEndpoint),
        headers: _headers,
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(AppConstants.requestTimeout);

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final user = UserModel.fromJson(body['user'] as Map<String, dynamic>);
        await StorageService.saveUser(user);
        return AuthResult(success: true, message: 'Login successful', user: user);
      } else if (response.statusCode == 403 &&
          body['detail'] == 'email_not_verified') {
        // Return special message so Flutter navigates to verify screen
        // Extract token + email from headers
        final token = response.headers['x-user-token'] ?? '';
        final userEmail = response.headers['x-user-email'] ?? email;
        return AuthResult(
          success:  false,
          message:  'email_not_verified',
          user:     UserModel(
            id:         0,
            name:       '',
            email:      userEmail,
            token:      token,
            isVerified: false,
          ),
        );
      } else {
        return AuthResult(
          success: false,
          message: body['detail'] as String? ?? 'Login failed',
        );
      }
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
      final response = await http.post(
        Uri.parse(AppConstants.signupEndpoint),
        headers: _headers,
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      ).timeout(AppConstants.requestTimeout);

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final userJson = Map<String, dynamic>.from(
            body['user'] as Map<String, dynamic>);

        // Backend doesn't return is_verified on signup — default to false
        userJson.putIfAbsent('is_verified', () => false);

        final user = UserModel.fromJson(userJson);

        // ── CRITICAL: Do NOT save to SharedPreferences here ──────
        // Saving an unverified user would let the app auto-login on
        // restart, completely bypassing email verification.
        // StorageService.saveUser() is called ONLY in verifyEmail()
        // after the OTP is confirmed — that is the single source of truth.
        // ─────────────────────────────────────────────────────────

        return AuthResult(
          success: true,
          message: body['message'] as String? ?? 'Account created',
          user:    user,
        );
      } else {
        return AuthResult(
          success: false,
          message: body['detail'] as String? ?? 'Signup failed',
        );
      }
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

      final response = await http.get(
        Uri.parse(AppConstants.profileEndpoint),
        headers: _authHeaders(savedUser.token),
      ).timeout(AppConstants.requestTimeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        // Merge token from savedUser — /me doesn't return a token
        final userJson = Map<String, dynamic>.from(
            body['user'] as Map<String, dynamic>)
          ..['token'] = savedUser.token;
        final user = UserModel.fromJson(userJson);

        // Persist the freshly fetched avatar so home screen can read it
        await StorageService.saveUser(user);
        return AuthResult(success: true, message: 'Success', user: user);

      } else if (response.statusCode == 401) {
        await StorageService.clearUser();
        return const AuthResult(
          success: false,
          message: 'Session expired. Please login again.',
        );
      } else {
        return const AuthResult(success: false, message: 'Failed to fetch profile');
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

      final response = await http.put(
        Uri.parse(AppConstants.updateProfileEndpoint),
        headers: _authHeaders(savedUser.token),
        body: jsonEncode(body),
      ).timeout(AppConstants.requestTimeout);

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
        final updatedUser  = UserModel.fromJson(
          responseBody['user'] as Map<String, dynamic>,
        );

        if (name != null) {
          // Persist updated name while keeping everything else (incl. avatar)
          await StorageService.saveUser(savedUser.copyWith(name: name));
        }

        return AuthResult(
          success: true,
          message: responseBody['message'] as String? ?? 'Updated successfully',
          user:    updatedUser,
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


  // ── Update Avatar (Protected) — NEW ──────────────────────────
  /// Sends the chosen avatar to the backend and updates local storage.
  ///
  /// [avatarType] — 'initial' | 'predefined' | 'custom'
  /// [avatarData] — null for 'initial', avatar ID for 'predefined',
  ///                base64 JPEG string for 'custom'
  Future<AuthResult> updateAvatar({
    required String avatarType,
    String?         avatarData,
  }) async {
    try {
      final savedUser = await StorageService.getSavedUser();
      if (savedUser == null) {
        return const AuthResult(success: false, message: 'Not logged in');
      }

      final response = await http.put(
        Uri.parse(AppConstants.updateAvatarEndpoint),
        headers: _authHeaders(savedUser.token),
        body: jsonEncode({
          'avatar_type': avatarType,
          'avatar_data': avatarData,
        }),
      ).timeout(AppConstants.requestTimeout);

      if (response.statusCode == 200) {
        // Persist new avatar locally so every screen sees it instantly
        await StorageService.updateAvatar(
          avatarType: avatarType,
          avatarData: avatarData,
        );
        return const AuthResult(
          success: true,
          message: 'Avatar updated successfully',
        );
      } else {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return AuthResult(
          success: false,
          message: body['detail'] as String? ?? 'Failed to update avatar',
        );
      }
    } catch (e) {
      return AuthResult(success: false, message: _friendlyError(e));
    }
  }


  // ── Forgot Password ───────────────────────────────────────────
  Future<AuthResult> forgotPassword({required String email}) async {
    try {
      final response = await http.post(
        Uri.parse(AppConstants.forgotPasswordEndpoint),
        headers: _headers,
        body: jsonEncode({'email': email}),
      ).timeout(AppConstants.emailTimeout);

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return AuthResult(
          success: true,
          message: body['message'] as String? ?? 'Reset code sent',
        );
      } else {
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
  Future<AuthResult> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(AppConstants.resetPasswordEndpoint),
        headers: _headers,
        body: jsonEncode({
          'email':        email,
          'code':         code,
          'new_password': newPassword,
        }),
      ).timeout(AppConstants.requestTimeout);

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
        user:    user,
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

  Future<AuthResult> verifyEmail({
    required String email,
    required String code,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(AppConstants.verifyEmailEndpoint),
        headers: _headers,
        body: jsonEncode({'email': email, 'code': code}),
      ).timeout(AppConstants.requestTimeout);

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final user = UserModel.fromJson(
            body['user'] as Map<String, dynamic>);
        await StorageService.saveUser(user);
        return AuthResult(
          success: true,
          message: body['message'] as String? ?? 'Email verified',
          user:    user,
        );
      } else {
        return AuthResult(
          success: false,
          message: body['detail'] as String? ?? 'Verification failed',
        );
      }
    } catch (e) {
      return AuthResult(success: false, message: _friendlyError(e));
    }
  }

  Future<AuthResult> resendOtp({required String email}) async {
    try {
      final response = await http.post(
        Uri.parse(AppConstants.resendOtpEndpoint),
        headers: _headers,
        body: jsonEncode({'email': email}),
      ).timeout(AppConstants.requestTimeout);

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return AuthResult(
          success: true,
          message: body['message'] as String? ?? 'OTP sent',
        );
      } else {
        return AuthResult(
          success: false,
          message: body['detail'] as String? ?? 'Failed to resend OTP',
        );
      }
    } catch (e) {
      return AuthResult(success: false, message: _friendlyError(e));
    }
  }

  // ── Delete Account ────────────────────────────────────────────
  Future<AuthResult> deleteAccount({required String password}) async {
    try {
      final savedUser = await StorageService.getSavedUser();
      if (savedUser == null) {
        return const AuthResult(success: false, message: 'Not logged in');
      }

      final response = await http.delete(
        Uri.parse(AppConstants.deleteAccountEndpoint),
        headers: _authHeaders(savedUser.token),
        body:    jsonEncode({'password': password}),
      ).timeout(AppConstants.requestTimeout);

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        await StorageService.clearUser();
        return AuthResult(
          success: true,
          message: body['message'] as String? ?? 'Account deleted',
        );
      } else {
        return AuthResult(
          success: false,
          message: body['detail'] as String? ?? 'Failed to delete account',
        );
      }
    } catch (e) {
      return AuthResult(success: false, message: _friendlyError(e));
    }
  }


// ── Reset Account ─────────────────────────────────────────────
  Future<AuthResult> resetAccount() async {
    try {
      final savedUser = await StorageService.getSavedUser();
      if (savedUser == null) {
        return const AuthResult(success: false, message: 'Not logged in');
      }

      final response = await http.post(
        Uri.parse(AppConstants.resetAccountEndpoint),
        headers: _authHeaders(savedUser.token),
      ).timeout(AppConstants.requestTimeout);

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        // Clear avatar locally since it was reset on backend
        await StorageService.updateAvatar(
          avatarType: 'initial',
          avatarData: null,
        );
        return AuthResult(
          success: true,
          message: body['message'] as String? ?? 'Account reset',
        );
      } else {
        return AuthResult(
          success: false,
          message: body['detail'] as String? ?? 'Failed to reset account',
        );
      }
    } catch (e) {
      return AuthResult(success: false, message: _friendlyError(e));
    }
  }
}
// services/auth_service.dart
// ============================================================
// Accounts on Firebase Auth + profile in Firestore (users/{uid}).
// Replaces the old /api/auth, /api/users, /api/password and
// /api/account endpoints. Email verification and password reset
// use Firebase's emailed links instead of 6-digit codes.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import 'firebase_refs.dart';
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

  FirebaseAuth get _auth => FirebaseRefs.auth;


  // ── Login ─────────────────────────────────────────────────────
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email, password: password,
      );
      final fbUser = cred.user!;
      await fbUser.reload();

      if (!(_auth.currentUser?.emailVerified ?? false)) {
        // Stay signed in so the verify screen can resend the link
        // and re-check status. Flutter navigates to verify screen.
        return AuthResult(
          success: false,
          message: 'email_not_verified',
          user:    UserModel(
            id:         fbUser.uid,
            name:       fbUser.displayName ?? '',
            email:      fbUser.email ?? email,
            token:      '',
            isVerified: false,
          ),
        );
      }

      final user = await _loadUser(fbUser);
      await StorageService.saveUser(user);
      return AuthResult(success: true, message: 'Login successful', user: user);
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
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password,
      );
      final fbUser = cred.user!;
      await fbUser.updateDisplayName(name);

      await FirebaseRefs.userDoc(fbUser.uid).set({
        'name':           name,
        'email':          email,
        'created_at':     FieldValue.serverTimestamp(),
        'avatar_type':    'initial',
        'avatar_data':    null,
        'current_streak': 0,
        'longest_streak': 0,
        'last_scan_date': null,
      });

      await fbUser.sendEmailVerification();

      // ── CRITICAL: Do NOT save to SharedPreferences here ──────
      // Saving an unverified user would let the app auto-login on
      // restart, completely bypassing email verification.
      // StorageService.saveUser() is called ONLY in verifyEmail()
      // after the email link is confirmed.
      // ─────────────────────────────────────────────────────────

      return AuthResult(
        success: true,
        message: 'Account created. Please verify your email.',
        user:    UserModel(
          id:         fbUser.uid,
          name:       name,
          email:      email,
          token:      '',
          isVerified: false,
        ),
      );
    } catch (e) {
      return AuthResult(success: false, message: _friendlyError(e));
    }
  }


  // ── Get Profile (Protected) ───────────────────────────────────
  Future<AuthResult> getProfile() async {
    try {
      final fbUser = _auth.currentUser;
      if (fbUser == null) {
        await StorageService.clearUser();
        return const AuthResult(
          success: false,
          message: 'Session expired. Please login again.',
        );
      }

      final user = await _loadUser(fbUser);
      // Persist the freshly fetched avatar so home screen can read it
      await StorageService.saveUser(user);
      return AuthResult(success: true, message: 'Success', user: user);
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
      final fbUser    = _auth.currentUser;
      final savedUser = await StorageService.getSavedUser();
      if (fbUser == null || savedUser == null) {
        return const AuthResult(success: false, message: 'Not logged in');
      }

      final hasName     = name != null && name.trim().isNotEmpty;
      final hasPassword = newPassword != null && newPassword.isNotEmpty;
      if (!hasName && !hasPassword) {
        return const AuthResult(
            success: false, message: 'No fields provided to update');
      }

      // ── Handle password change ─────────────────────────────
      if (hasPassword) {
        if (currentPassword == null || currentPassword.isEmpty) {
          return const AuthResult(
            success: false,
            message: 'Current password is required to set a new password',
          );
        }
        if (!await _reauthenticate(fbUser, currentPassword)) {
          return const AuthResult(
              success: false, message: 'Current password is incorrect');
        }
        if (newPassword == currentPassword) {
          return const AuthResult(
            success: false,
            message: 'New password must be different from your current password.',
          );
        }
        await fbUser.updatePassword(newPassword);
      }

      if (hasName) {
        final trimmed = name.trim();
        await FirebaseRefs.userDoc(fbUser.uid).update({'name': trimmed});
        await _syncLeaderboard(fbUser.uid, {'name': trimmed});
        await fbUser.updateDisplayName(trimmed);
        // Persist updated name while keeping everything else (incl. avatar)
        await StorageService.saveUser(savedUser.copyWith(name: trimmed));
      }

      return AuthResult(
        success: true,
        message: 'Profile updated successfully',
        user:    hasName ? savedUser.copyWith(name: name.trim()) : savedUser,
      );
    } catch (e) {
      return AuthResult(success: false, message: _friendlyError(e));
    }
  }


  // ── Update Avatar (Protected) ─────────────────────────────────
  /// Saves the chosen avatar to Firestore and updates local storage.
  ///
  /// [avatarType] — 'initial' | 'predefined' | 'custom'
  /// [avatarData] — null for 'initial', avatar ID for 'predefined',
  ///                base64 JPEG string for 'custom'
  Future<AuthResult> updateAvatar({
    required String avatarType,
    String?         avatarData,
  }) async {
    try {
      final uid = FirebaseRefs.uid;
      if (uid == null) {
        return const AuthResult(success: false, message: 'Not logged in');
      }

      final avatar = {'avatar_type': avatarType, 'avatar_data': avatarData};
      await FirebaseRefs.userDoc(uid).update(avatar);
      await _syncLeaderboard(uid, avatar);

      // Persist new avatar locally so every screen sees it instantly
      await StorageService.updateAvatar(
        avatarType: avatarType,
        avatarData: avatarData,
      );
      return const AuthResult(
        success: true,
        message: 'Avatar updated successfully',
      );
    } catch (e) {
      return AuthResult(success: false, message: _friendlyError(e));
    }
  }


  // ── Forgot Password ───────────────────────────────────────────
  /// Firebase emails a reset link; the user sets the new password
  /// on Firebase's page, then logs in again.
  Future<AuthResult> forgotPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return const AuthResult(
        success: true,
        message: 'Reset link sent. Check your email.',
      );
    } catch (e) {
      return AuthResult(success: false, message: _friendlyError(e));
    }
  }


  // ── Verify Email ──────────────────────────────────────────────
  /// Checks whether the user has tapped the emailed link.
  Future<AuthResult> verifyEmail() async {
    try {
      final fbUser = _auth.currentUser;
      if (fbUser == null) {
        return const AuthResult(
          success: false,
          message: 'Session expired. Please login again.',
        );
      }

      await fbUser.reload();
      final refreshed = _auth.currentUser!;
      if (!refreshed.emailVerified) {
        return const AuthResult(
          success: false,
          message: 'Not verified yet. Tap the link in the email, then try again.',
        );
      }

      final user = await _loadUser(refreshed);
      await StorageService.saveUser(user);
      return AuthResult(success: true, message: 'Email verified', user: user);
    } catch (e) {
      return AuthResult(success: false, message: _friendlyError(e));
    }
  }

  Future<AuthResult> resendVerification() async {
    try {
      final fbUser = _auth.currentUser;
      if (fbUser == null) {
        return const AuthResult(
          success: false,
          message: 'Session expired. Please login again.',
        );
      }
      await fbUser.sendEmailVerification();
      return const AuthResult(success: true, message: 'Verification link sent');
    } catch (e) {
      return AuthResult(success: false, message: _friendlyError(e));
    }
  }


  // ── Delete Account ────────────────────────────────────────────
  Future<AuthResult> deleteAccount({required String password}) async {
    try {
      final fbUser = _auth.currentUser;
      if (fbUser == null) {
        return const AuthResult(success: false, message: 'Not logged in');
      }

      if (!await _reauthenticate(fbUser, password)) {
        return const AuthResult(success: false, message: 'Incorrect password');
      }
      await _deleteUserData(fbUser.uid);
      await FirebaseRefs.userDoc(fbUser.uid).delete();
      await fbUser.delete();

      await StorageService.clearUser();
      return const AuthResult(success: true, message: 'Account deleted');
    } catch (e) {
      return AuthResult(success: false, message: _friendlyError(e));
    }
  }


  // ── Reset Account ─────────────────────────────────────────────
  /// Clears scans, challenge scores, badges, streaks and avatar.
  /// Keeps: name, email, password, verification.
  Future<AuthResult> resetAccount() async {
    try {
      final uid = FirebaseRefs.uid;
      if (uid == null) {
        return const AuthResult(success: false, message: 'Not logged in');
      }

      await _deleteUserData(uid);
      await FirebaseRefs.userDoc(uid).update({
        'current_streak': 0,
        'longest_streak': 0,
        'last_scan_date': null,
        'avatar_type':    'initial',
        'avatar_data':    null,
      });

      await StorageService.updateAvatar(
        avatarType: 'initial',
        avatarData: null,
      );
      return const AuthResult(
        success: true,
        message: 'Account reset successfully. All data has been cleared.',
      );
    } catch (e) {
      return AuthResult(success: false, message: _friendlyError(e));
    }
  }


  // ── Helpers ───────────────────────────────────────────────────
  Future<UserModel> _loadUser(User fbUser) async {
    final snap = await FirebaseRefs.userDoc(fbUser.uid).get();
    final data = snap.data() ?? {};
    return UserModel(
      id:         fbUser.uid,
      name:       (data['name'] as String?) ?? fbUser.displayName ?? '',
      email:      fbUser.email ?? (data['email'] as String? ?? ''),
      token:      '',
      avatarType: (data['avatar_type'] as String?) ?? 'initial',
      avatarData: data['avatar_data'] as String?,
      isVerified: fbUser.emailVerified,
    );
  }

  /// False when the password is wrong; other failures still throw.
  Future<bool> _reauthenticate(User fbUser, String password) async {
    try {
      await fbUser.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: fbUser.email!, password: password),
      );
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-credential' || e.code == 'wrong-password') {
        return false;
      }
      rethrow;
    }
  }

  Future<void> _deleteUserData(String uid) async {
    await FirebaseRefs.deleteAll(FirebaseRefs.scans(uid));
    await FirebaseRefs.deleteAll(FirebaseRefs.earnedBadges(uid));
    await FirebaseRefs.challengeScores.doc(uid).delete();
  }

  /// Keeps the copy of name/avatar on the leaderboard in sync.
  /// No-op when the user hasn't played a challenge yet.
  Future<void> _syncLeaderboard(String uid, Map<String, dynamic> fields) async {
    final ref = FirebaseRefs.challengeScores.doc(uid);
    if ((await ref.get()).exists) await ref.update(fields);
  }

  String _friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return 'Incorrect email or password';
        case 'email-already-in-use':
          return 'An account with this email already exists';
        case 'invalid-email':
          return 'Please enter a valid email address';
        case 'weak-password':
          return 'Password is too weak';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a minute and try again.';
        case 'network-request-failed':
          return 'No internet connection. Check your connection.';
        case 'requires-recent-login':
          return 'Please login again and retry.';
      }
      return e.message ?? 'Something went wrong';
    }
    if (e is FirebaseException && e.code == 'unavailable') {
      return 'No internet connection. Check your connection.';
    }
    return 'An unexpected error occurred. Please try again.';
  }
}

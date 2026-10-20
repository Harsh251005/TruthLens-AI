// screens/email_verification_screen.dart
// ============================================================
// CHANGES FROM ORIGINAL:
//   1. Added import for TutorialService + TutorialScreen
//   2. _handleVerify() success block now calls
//      _navigateAfterVerify() instead of directly pushing Home
//   3. _navigateAfterVerify() uses isNewSignup() — NOT
//      hasSeenIntro() — to correctly detect fresh signups
//      even on devices where a previous account already
//      completed the tutorial.
//
// Firebase: verification is an emailed link, not a 6-digit
// code. "I've verified" re-checks the account's status.
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/tutorial_service.dart';        // ← NEW
import '../utils/app_theme.dart';
import '../models/user_model.dart';
import 'home_screen.dart';
import 'tutorial_screen.dart';                     // ← NEW

class EmailVerificationScreen extends StatefulWidget {
  final String    email;
  final UserModel user;
  const EmailVerificationScreen({
    super.key, required this.email, required this.user,
  });
  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends State<EmailVerificationScreen> {

  final _authService     = AuthService();
  final _tutorialService = TutorialService();      // ← NEW

  bool    _isVerifying  = false;
  bool    _isResending  = false;
  String? _errorMessage;
  String? _successMessage;
  int     _resendCooldown = 0;
  Timer?  _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 30);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) t.cancel();
      });
    });
  }

  // ── NEW: Correct tutorial routing after email verification ─
  //
  // Uses isNewSignup() — set by signup_screen on fresh accounts.
  // This correctly shows tutorial even on devices where an older
  // account already completed it (hasSeenIntro() would be true).
  //
  // For re-verification of existing accounts (e.g. login with
  // unverified email), isNewSignup() is false → goes to Home.
  Future<void> _navigateAfterVerify(UserModel user) async {
    final isNew = await _tutorialService.isNewSignup(); // ← KEY FIX
    if (!mounted) return;

    final destination = isNew
        ? TutorialScreen(user: user)   // new signup → show tutorial
        : HomeScreen(user: user);      // re-verification → skip tutorial

    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder:        (_, _, _) => destination,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
          (route) => false,
    );
  }

  Future<void> _handleVerify() async {
    setState(() { _isVerifying = true; _errorMessage = null; });
    HapticFeedback.lightImpact();

    final result = await _authService.verifyEmail();

    if (!mounted) return;

    if (result.success && result.user != null) {
      HapticFeedback.heavyImpact();
      // ── CHANGED: was pushAndRemoveUntil(HomeScreen) directly
      await _navigateAfterVerify(result.user!);
    } else {
      HapticFeedback.mediumImpact();
      setState(() {
        _isVerifying  = false;
        _errorMessage = result.message;
      });
    }
  }

  // ── Everything below is 100% UNCHANGED ───────────────────

  Future<void> _handleResend() async {
    if (_resendCooldown > 0) return;
    setState(() {
      _isResending    = true;
      _errorMessage   = null;
      _successMessage = null;
    });
    final result = await _authService.resendVerification();
    if (!mounted) return;
    setState(() {
      _isResending = false;
      if (result.success) {
        _successMessage = 'A new link has been sent to your email.';
        _startCooldown();
      } else {
        _errorMessage = result.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(children: [
        Container(
          width:  double.infinity,
          height: 220,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F1629), Color(0xFF0A0E1A)],
              begin:  Alignment.topCenter,
              end:    Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color:  AppTheme.primary.withValues(alpha: 0.12),
                    shape:  BoxShape.circle,
                    border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color:      AppTheme.primary.withValues(alpha: 0.2),
                        blurRadius: 24, spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.mark_email_unread_outlined,
                      color: AppTheme.primary, size: 34),
                ),
                const SizedBox(height: 14),
                const Text('Check your inbox',
                    style: TextStyle(fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                const Text('Verification link sent',
                    style: TextStyle(fontSize: 13,
                        color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppTheme.paddingL, 0,
              AppTheme.paddingL,
              MediaQuery.of(context).padding.bottom + AppTheme.paddingL,
            ),
            child: Transform.translate(
              offset: const Offset(0, -20),
              child: Container(
                padding: const EdgeInsets.all(AppTheme.paddingL),
                decoration: BoxDecoration(
                  color:        AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusL),
                  border: Border.all(color: AppTheme.surfaceBorder),
                  boxShadow: [
                    BoxShadow(
                      color:      Colors.black.withValues(alpha: 0.25),
                      blurRadius: 20, spreadRadius: 2,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(children: [
                  Container(
                    width:   double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:        AppTheme.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.email_outlined,
                            color: AppTheme.primary, size: 14),
                        const SizedBox(width: 6),
                        Text(widget.email,
                            style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Open the email we sent and tap the verification link. '
                    "Then come back and tap I've verified.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14,
                        color: AppTheme.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  if (_errorMessage != null) ...[
                    _buildBanner(_errorMessage!, isError: true),
                    const SizedBox(height: 14),
                  ],
                  if (_successMessage != null) ...[
                    _buildBanner(_successMessage!, isError: false),
                    const SizedBox(height: 14),
                  ],
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton(
                      onPressed: _isVerifying ? null : _handleVerify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(AppTheme.radiusM)),
                        elevation: 0,
                      ),
                      child: _isVerifying
                          ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                          : const Text("I've verified",
                          style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Didn't receive it? ",
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 14)),
                      _isResending
                          ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(
                              color: AppTheme.primary, strokeWidth: 2))
                          : GestureDetector(
                        onTap: _resendCooldown > 0
                            ? null : _handleResend,
                        child: Text(
                          _resendCooldown > 0
                              ? 'Resend in ${_resendCooldown}s'
                              : 'Resend link',
                          style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: _resendCooldown > 0
                                ? AppTheme.textSecondary
                                : AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:        AppTheme.surface2,
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                      border: Border.all(color: AppTheme.surfaceBorder),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline,
                          color: AppTheme.textSecondary, size: 14),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Check spam if not received. The link opens in your browser.',
                          style: TextStyle(fontSize: 12,
                              color: AppTheme.textSecondary, height: 1.4),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildBanner(String message, {required bool isError}) {
    final color = isError ? AppTheme.error : AppTheme.success;
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(AppTheme.paddingM),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
            color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message,
            style: TextStyle(color: color, fontSize: 13))),
      ]),
    );
  }
}
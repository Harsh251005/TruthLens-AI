// screens/email_verification_screen.dart
// ============================================================
// Email verification screen — shown after signup or when an
// unverified user tries to log in.
// User enters the 6-digit OTP sent to their email.
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../utils/app_theme.dart';
import '../models/user_model.dart';
import 'home_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String    email;
  final UserModel user;   // Passed from signup/login

  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.user,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends State<EmailVerificationScreen> {

  // ── OTP input controllers (one per digit) ─────────────────────
  final List<TextEditingController> _controllers =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
  List.generate(6, (_) => FocusNode());

  // ── Services ──────────────────────────────────────────────────
  final _authService = AuthService();

  // ── State ─────────────────────────────────────────────────────
  bool    _isVerifying  = false;
  bool    _isResending  = false;
  String? _errorMessage;
  String? _successMessage;

  // ── Resend cooldown timer ─────────────────────────────────────
  int    _resendCooldown = 0;  // Seconds remaining
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    // Start cooldown immediately so user can't spam resend
    _startCooldown();
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes)  f.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  // ── Cooldown timer (30 seconds between resends) ───────────────
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

  // ── Get full OTP string ───────────────────────────────────────
  String get _otp =>
      _controllers.map((c) => c.text).join();

  // ── Handle digit input ────────────────────────────────────────
  void _onDigitChanged(int index, String value) {
    if (value.length == 1) {
      // Move focus to next field
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        // Last digit entered — auto submit
        _focusNodes[index].unfocus();
        if (_otp.length == 6) _handleVerify();
      }
    } else if (value.isEmpty && index > 0) {
      // Backspace — move focus to previous field
      _focusNodes[index - 1].requestFocus();
    }
    setState(() => _errorMessage = null);
  }

  // ── Verify OTP ────────────────────────────────────────────────
  Future<void> _handleVerify() async {
    if (_otp.length < 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits');
      return;
    }

    setState(() {
      _isVerifying  = true;
      _errorMessage = null;
    });

    HapticFeedback.lightImpact();

    final result = await _authService.verifyEmail(
      email: widget.email,
      code:  _otp,
    );

    if (!mounted) return;

    if (result.success && result.user != null) {
      HapticFeedback.heavyImpact();
      // Navigate to home screen
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              HomeScreen(user: result.user!),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
            (route) => false,
      );
    } else {
      HapticFeedback.mediumImpact();
      setState(() {
        _isVerifying  = false;
        _errorMessage = result.message;
        // Clear OTP fields on error
        for (final c in _controllers) c.clear();
        _focusNodes[0].requestFocus();
      });
    }
  }

  // ── Resend OTP ────────────────────────────────────────────────
  Future<void> _handleResend() async {
    if (_resendCooldown > 0) return;

    setState(() {
      _isResending    = true;
      _errorMessage   = null;
      _successMessage = null;
    });

    final result = await _authService.resendOtp(email: widget.email);

    if (!mounted) return;

    setState(() {
      _isResending = false;
      if (result.success) {
        _successMessage = 'A new code has been sent to your email.';
        // Clear fields for new code
        for (final c in _controllers) c.clear();
        _focusNodes[0].requestFocus();
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
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        automaticallyImplyLeading: false,
        title: const Text('Verify Email',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.paddingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),

              // ── Icon ──────────────────────────────────────────
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color:  AppTheme.primary.withOpacity(0.1),
                  shape:  BoxShape.circle,
                  border: Border.all(
                      color: AppTheme.primary.withOpacity(0.3)),
                ),
                child: const Icon(Icons.mark_email_unread_outlined,
                    color: AppTheme.primary, size: 38),
              ),

              const SizedBox(height: 24),

              // ── Title ─────────────────────────────────────────
              const Text('Check your inbox',
                  style: TextStyle(fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),

              const SizedBox(height: 10),

              // ── Subtitle ──────────────────────────────────────
              Text(
                'We sent a 6-digit verification code to\n${widget.email}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14,
                    color: AppTheme.textSecondary, height: 1.6),
              ),

              const SizedBox(height: 36),

              // ── OTP input boxes ───────────────────────────────
              // REPLACE the Row with this
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (i) {
                  return Expanded(
                    child: Container(
                      height: 56,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color:        AppTheme.surface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                        border: Border.all(
                          color: _focusNodes[i].hasFocus
                              ? AppTheme.primary
                              : _errorMessage != null
                              ? AppTheme.error
                              : AppTheme.surfaceBorder,
                          width: _focusNodes[i].hasFocus ? 2 : 1,
                        ),
                      ),
                      child: TextField(
                        controller:   _controllers[i],
                        focusNode:    _focusNodes[i],
                        textAlign:    TextAlign.center,
                        textAlignVertical: TextAlignVertical.center,
                        keyboardType: TextInputType.number,
                        maxLength:    1,
                        cursorColor:  AppTheme.primary,
                        style: const TextStyle(
                          fontSize:   24,
                          fontWeight: FontWeight.w800,
                          color:      Colors.white,    // ← hardcoded white, not AppTheme
                          height:     1,
                        ),
                        decoration: const InputDecoration(
                          counterText:     '',
                          border:          InputBorder.none,
                          enabledBorder:   InputBorder.none,
                          focusedBorder:   InputBorder.none,
                          filled:          false,      // ← no fill at all
                          contentPadding:  EdgeInsets.zero,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (v) => _onDigitChanged(i, v),
                        onTap:     () => setState(() {}),
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 24),

              // ── Error banner ──────────────────────────────────
              if (_errorMessage != null) ...[
                Container(
                  width:   double.infinity,
                  padding: const EdgeInsets.all(AppTheme.paddingM),
                  decoration: BoxDecoration(
                    color:        AppTheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    border: Border.all(
                        color: AppTheme.error.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                        color: AppTheme.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMessage!,
                        style: const TextStyle(
                            color: AppTheme.error, fontSize: 13))),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              // ── Success banner ────────────────────────────────
              if (_successMessage != null) ...[
                Container(
                  width:   double.infinity,
                  padding: const EdgeInsets.all(AppTheme.paddingM),
                  decoration: BoxDecoration(
                    color:        AppTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    border: Border.all(
                        color: AppTheme.success.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.check_circle_outline,
                        color: AppTheme.success, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_successMessage!,
                        style: const TextStyle(
                            color: AppTheme.success, fontSize: 13))),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              // ── Verify button ─────────────────────────────────
              SizedBox(
                width:  double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _handleVerify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(AppTheme.radiusM)),
                  ),
                  child: _isVerifying
                      ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : const Text('Verify Email',
                      style: TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ),
              ),

              const SizedBox(height: 20),

              // ── Resend row ────────────────────────────────────
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text("Didn't receive the code? ",
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 14)),
                _isResending
                    ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(
                        color: AppTheme.primary, strokeWidth: 2))
                    : GestureDetector(
                  onTap: _resendCooldown > 0 ? null : _handleResend,
                  child: Text(
                    _resendCooldown > 0
                        ? 'Resend in ${_resendCooldown}s'
                        : 'Resend',
                    style: TextStyle(
                      fontSize:   14,
                      fontWeight: FontWeight.w700,
                      color:      _resendCooldown > 0
                          ? AppTheme.textSecondary
                          : AppTheme.primary,
                    ),
                  ),
                ),
              ]),

              const SizedBox(height: 32),

              // ── Wrong email note ──────────────────────────────
              Container(
                padding: const EdgeInsets.all(AppTheme.paddingM),
                decoration: BoxDecoration(
                  color:        AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline,
                      color: AppTheme.textSecondary, size: 16),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Make sure to check your spam folder. '
                          'The code expires in 15 minutes.',
                      style: TextStyle(fontSize: 12,
                          color: AppTheme.textSecondary, height: 1.4),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// screens/email_verification_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import '../models/user_model.dart';
import 'home_screen.dart';

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

  final List<TextEditingController> _controllers =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
  List.generate(6, (_) => FocusNode());
  final _authService = AuthService();

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
    // Rebuild when focus changes so border updates
    for (final f in _focusNodes) {
      f.addListener(() { if (mounted) setState(() {}); });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
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

  String get _otp => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length == 1) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        if (_otp.length == 6) _handleVerify();
      }
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() => _errorMessage = null);
  }

  Future<void> _handleVerify() async {
    if (_otp.length < 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits');
      return;
    }
    setState(() { _isVerifying = true; _errorMessage = null; });
    HapticFeedback.lightImpact();
    final result = await _authService.verifyEmail(
      email: widget.email, code: _otp,
    );
    if (!mounted) return;
    if (result.success && result.user != null) {
      HapticFeedback.heavyImpact();
      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder:        (_, _, _) => HomeScreen(user: result.user!),
          transitionsBuilder: (_, animation, _, child) =>
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
        for (final c in _controllers) c.clear();
        _focusNodes[0].requestFocus();
      });
    }
  }

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
      body: Column(children: [
        // ── Hero ──────────────────────────────────────────────
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
                const Text('Verification code sent',
                    style: TextStyle(fontSize: 13,
                        color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ),

        // ── Body ──────────────────────────────────────────────
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

                  // Email display
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

                  // Section label
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('ENTER 6-DIGIT CODE',
                        style: TextStyle(fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary,
                            letterSpacing: 1.0)),
                  ),

                  const SizedBox(height: 12),

                  // OTP boxes
                  Row(
                    children: List.generate(6, (i) {
                      final hasFocus = _focusNodes[i].hasFocus;
                      final hasValue = _controllers[i].text.isNotEmpty;
                      return Expanded(
                        child: Container(
                          height: 56,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: hasFocus
                                ? AppTheme.primary.withValues(alpha: 0.08)
                                : AppTheme.surface2,
                            borderRadius:
                            BorderRadius.circular(AppTheme.radiusM),
                            border: Border.all(
                              color: _errorMessage != null
                                  ? AppTheme.error
                                  : hasFocus
                                  ? AppTheme.primary
                                  : hasValue
                                  ? AppTheme.primary.withValues(alpha: 0.4)
                                  : AppTheme.surfaceBorder,
                              width: hasFocus ? 2 : 1,
                            ),
                          ),
                          child: TextField(
                            controller:        _controllers[i],
                            focusNode:         _focusNodes[i],
                            textAlign:         TextAlign.center,
                            textAlignVertical: TextAlignVertical.center,
                            keyboardType:      TextInputType.number,
                            maxLength:         1,
                            cursorColor:       AppTheme.primary,
                            style: const TextStyle(
                              fontSize:   22,
                              fontWeight: FontWeight.w800,
                              color:      Colors.white,
                              height:     1,
                            ),
                            decoration: const InputDecoration(
                              counterText:    '',
                              border:         InputBorder.none,
                              enabledBorder:  InputBorder.none,
                              focusedBorder:  InputBorder.none,
                              filled:         false,
                              contentPadding: EdgeInsets.zero,
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

                  const SizedBox(height: 20),

                  // Banners
                  if (_errorMessage != null) ...[
                    _buildBanner(_errorMessage!, isError: true),
                    const SizedBox(height: 14),
                  ],
                  if (_successMessage != null) ...[
                    _buildBanner(_successMessage!, isError: false),
                    const SizedBox(height: 14),
                  ],

                  // Verify button
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
                          : const Text('Verify Email',
                          style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Resend
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
                              : 'Resend code',
                          style: TextStyle(
                            fontSize:   14,
                            fontWeight: FontWeight.w700,
                            color:      _resendCooldown > 0
                                ? AppTheme.textSecondary
                                : AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Tip
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
                          'Check spam if not received. Code expires in 15 minutes.',
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
        Icon(isError
            ? Icons.error_outline : Icons.check_circle_outline,
            color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message,
            style: TextStyle(color: color, fontSize: 13))),
      ]),
    );
  }
}
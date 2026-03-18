// screens/reset_password_screen.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey                   = GlobalKey<FormState>();
  final _codeController            = TextEditingController();
  final _newPasswordController     = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService               = AuthService();
  bool    _isLoading    = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final result = await _authService.resetPassword(
      email:       widget.email,
      code:        _codeController.text.trim(),
      newPassword: _newPasswordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.success) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusL)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color:  AppTheme.success.withValues(alpha: 0.1),
                  shape:  BoxShape.circle,
                  border: Border.all(
                      color: AppTheme.success.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.check_circle_outline,
                    color: AppTheme.success, size: 36),
              ),
              const SizedBox(height: 16),
              const Text('Password Reset!',
                  style: TextStyle(fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              const Text(
                'Your password has been reset successfully. Please log in with your new password.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14,
                    color: AppTheme.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Go to Login',
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushAndRemoveUntil(
                    PageRouteBuilder(
                      pageBuilder:        (_, _, _) => const LoginScreen(),
                      transitionsBuilder: (_, animation, _, child) =>
                          FadeTransition(opacity: animation, child: child),
                      transitionDuration: const Duration(milliseconds: 400),
                    ),
                        (route) => false,
                  );
                },
              ),
            ],
          ),
        ),
      );
    } else {
      setState(() => _errorMessage = result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Reset Password',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppTheme.paddingL, AppTheme.paddingL,
            AppTheme.paddingL,
            MediaQuery.of(context).padding.bottom + AppTheme.paddingL,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Email info banner ──────────────────────────────
              Container(
                width:   double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:        AppTheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.mark_email_read_outlined,
                      color: AppTheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary,
                            height: 1.4),
                        children: [
                          const TextSpan(text: 'Code sent to '),
                          TextSpan(
                            text: widget.email,
                            style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 20),

              // ── Form ───────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(AppTheme.paddingL),
                decoration: BoxDecoration(
                  color:        AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusL),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(children: [
                    CustomTextField(
                      label:           'Reset Code',
                      hint:            'Enter 6-digit code',
                      controller:      _codeController,
                      icon:            Icons.pin_outlined,
                      keyboardType:    TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return 'Reset code is required';
                        if (v.length != 6)
                          return 'Code must be exactly 6 digits';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Divider with label
                    Row(children: [
                      const Expanded(
                          child: Divider(color: AppTheme.surfaceBorder)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text('New Password',
                            style: TextStyle(fontSize: 11,
                                color: AppTheme.textSecondary
                                    .withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600)),
                      ),
                      const Expanded(
                          child: Divider(color: AppTheme.surfaceBorder)),
                    ]),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label:      'New Password',
                      hint:       'Enter new password',
                      controller: _newPasswordController,
                      icon:       Icons.lock_outline,
                      isPassword: true,
                      validator:  Validators.password,
                    ),
                    const SizedBox(height: 14),
                    CustomTextField(
                      label:      'Confirm Password',
                      hint:       'Repeat new password',
                      controller: _confirmPasswordController,
                      icon:       Icons.lock_outline,
                      isPassword: true,
                      validator: (v) => Validators.confirmPassword(
                          v, _newPasswordController.text),
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 20),
                    if (_errorMessage != null) ...[
                      Container(
                        width:   double.infinity,
                        padding: const EdgeInsets.all(AppTheme.paddingM),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.08),
                          borderRadius:
                          BorderRadius.circular(AppTheme.radiusS),
                          border: Border.all(
                              color: AppTheme.error.withValues(alpha: 0.3)),
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
                      const SizedBox(height: 12),
                    ],
                    PrimaryButton(
                      label:     'Reset Password',
                      onPressed: _handleReset,
                      isLoading: _isLoading,
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
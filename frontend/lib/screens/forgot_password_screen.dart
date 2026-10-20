// screens/forgot_password_screen.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey         = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _authService     = AuthService();
  bool    _isLoading    = false;
  String? _errorMessage;

  @override
  void dispose() { _emailController.dispose(); super.dispose(); }

  Future<void> _handleSubmit() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final result = await _authService.forgotPassword(
        email: _emailController.text.trim());
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result.success) {
      // Firebase emails a reset link; the new password is set there.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Reset link sent to ${_emailController.text.trim()}. '
            'Check your email, then log in with the new password.'),
      ));
      Navigator.of(context).pop();
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
        title: const Text('Forgot Password',
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
              // ── Hero banner ────────────────────────────────────
              Container(
                width:   double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F1629), Color(0xFF0A0E1A)],
                    begin:  Alignment.topLeft,
                    end:    Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusL),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color:  AppTheme.primary.withValues(alpha: 0.12),
                      shape:  BoxShape.circle,
                      border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.mail_outline_rounded,
                        color: AppTheme.primary, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Reset Password',
                            style: TextStyle(fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary)),
                        const SizedBox(height: 4),
                        Text("We'll email you a link to reset your password.",
                            style: TextStyle(fontSize: 13,
                                color: AppTheme.textSecondary.withValues(
                                    alpha: 0.8),
                                height: 1.4)),
                      ],
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 24),

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
                      label:           'Email Address',
                      hint:            'Enter your registered email',
                      controller:      _emailController,
                      icon:            Icons.email_outlined,
                      keyboardType:    TextInputType.emailAddress,
                      validator:       Validators.email,
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 20),
                    if (_errorMessage != null) ...[
                      _buildErrorBanner(),
                      const SizedBox(height: 14),
                    ],
                    PrimaryButton(
                      label:     'Send Reset Link',
                      onPressed: _handleSubmit,
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

  Widget _buildErrorBanner() {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(AppTheme.paddingM),
      decoration: BoxDecoration(
        color:        AppTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(_errorMessage!,
            style: const TextStyle(color: AppTheme.error, fontSize: 13))),
      ]),
    );
  }
}
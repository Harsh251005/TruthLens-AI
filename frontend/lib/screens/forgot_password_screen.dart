// screens/forgot_password_screen.dart
// ============================================================
// Forgot password screen — dark themed.
// ============================================================

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import 'reset_password_screen.dart';

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
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            ResetPasswordScreen(email: _emailController.text.trim()),
      ));
    } else {
      setState(() => _errorMessage = result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildHeader(),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(AppTheme.paddingL),
                decoration: AppTheme.cardDecoration(),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      CustomTextField(
                        label: 'Email', hint: 'Enter your registered email',
                        controller: _emailController,
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.email,
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: 20),
                      if (_errorMessage != null) ...[
                        _buildErrorBanner(),
                        const SizedBox(height: 12),
                      ],
                      PrimaryButton(
                        label: 'Send Reset Code',
                        onPressed: _handleSubmit,
                        isLoading: _isLoading,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
          ),
          child: const Icon(Icons.mail_outline_rounded,
              color: AppTheme.primary, size: 28),
        ),
        const SizedBox(height: 20),
        const Text('Forgot Password?',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary, letterSpacing: -0.5)),
        const SizedBox(height: 6),
        const Text("Enter your email and we'll send you\na 6-digit reset code.",
            style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.paddingM),
      decoration: BoxDecoration(
        color: AppTheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(color: AppTheme.error.withOpacity(0.3)),
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
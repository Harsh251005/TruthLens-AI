// screens/signup_screen.dart
// ============================================================
// Signup screen — dark themed, professional design.
// ============================================================

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import 'home_screen.dart';
import 'email_verification_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey                   = GlobalKey<FormState>();
  final _nameController            = TextEditingController();
  final _emailController           = TextEditingController();
  final _passwordController        = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService               = AuthService();

  bool    _isLoading    = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final result = await _authService.signup(
        name:     _nameController.text.trim(),
        email:    _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result.success && result.user != null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => EmailVerificationScreen(
              email: _emailController.text.trim(),
              user:  result.user!,
            ),
          ),
              (route) => false,
        );
      } else {
        setState(() => _errorMessage = result.message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading    = false;
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
      print('Signup exception: $e');
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
              _buildHeader(),
              const SizedBox(height: 28),
              _buildForm(),
              const SizedBox(height: 24),
              _buildLoginRedirect(),
              const SizedBox(height: 32),
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
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: AppTheme.accentGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.person_add_rounded,
              color: Colors.white, size: 28),
        ),

        const SizedBox(height: 24),

        const Text(
          'Create account',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'Join TruthLens AI today',
          style: TextStyle(fontSize: 15, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: AppTheme.cardDecoration(),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            CustomTextField(
              label:     'Full Name',
              hint:      'John Doe',
              controller: _nameController,
              icon:      Icons.person_outline,
              validator: Validators.name,
            ),

            const SizedBox(height: 16),

            CustomTextField(
              label:        'Email',
              hint:         'you@example.com',
              controller:   _emailController,
              icon:         Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator:    Validators.email,
            ),

            const SizedBox(height: 16),

            CustomTextField(
              label:      'Password',
              hint:       'Create a password',
              controller: _passwordController,
              icon:       Icons.lock_outline,
              isPassword: true,
              validator:  Validators.password,
            ),

            const SizedBox(height: 16),

            CustomTextField(
              label:      'Confirm Password',
              hint:       'Repeat your password',
              controller: _confirmPasswordController,
              icon:       Icons.lock_outline,
              isPassword: true,
              validator: (value) => Validators.confirmPassword(
                value, _passwordController.text,
              ),
              textInputAction: TextInputAction.done,
            ),

            const SizedBox(height: 20),

            if (_errorMessage != null) ...[
              _buildErrorBanner(),
              const SizedBox(height: 12),
            ],

            PrimaryButton(
              label:     'Create Account',
              onPressed: _handleSignup,
              isLoading: _isLoading,
            ),

            const SizedBox(height: 16),

            const Text(
              'By creating an account you agree to our\nTerms of Service and Privacy Policy.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
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
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_errorMessage!,
                style: const TextStyle(color: AppTheme.error, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginRedirect() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Already have an account? ',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Text(
            'Sign in',
            style: TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
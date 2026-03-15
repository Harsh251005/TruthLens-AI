// screens/login_screen.dart
// ============================================================
// Login screen — dark themed, professional design.
// ============================================================

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import 'signup_screen.dart';
import 'home_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey            = GlobalKey<FormState>();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService        = AuthService();

  bool    _isLoading    = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final result = await _authService.login(
      email:    _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => HomeScreen(user: result.user!),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.paddingL,
            vertical: AppTheme.paddingXL,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              _buildHeader(),
              const SizedBox(height: 40),
              _buildForm(),
              const SizedBox(height: 32),
              _buildSignupRedirect(),
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
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.remove_red_eye_rounded,
              color: Colors.white, size: 28),
        ),

        const SizedBox(height: 24),

        const Text(
          'Welcome back',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'Sign in to continue',
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
              label:        'Email',
              hint:         'you@example.com',
              controller:   _emailController,
              icon:         Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator:    Validators.email,
            ),

            const SizedBox(height: 16),

            CustomTextField(
              label:           'Password',
              hint:            'Enter your password',
              controller:      _passwordController,
              icon:            Icons.lock_outline,
              isPassword:      true,
              validator:       Validators.password,
              textInputAction: TextInputAction.done,
            ),

            const SizedBox(height: 8),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const ForgotPasswordScreen()),
                ),
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(color: AppTheme.primary, fontSize: 13),
                ),
              ),
            ),

            if (_errorMessage != null) ...[
              _buildErrorBanner(),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 8),

            PrimaryButton(
              label:     'Sign In',
              onPressed: _handleLogin,
              isLoading: _isLoading,
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

  Widget _buildSignupRedirect() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Don't have an account? ",
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SignupScreen()),
          ),
          child: const Text(
            'Sign up',
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
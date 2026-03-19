// screens/login_screen.dart
// ============================================================
// CHANGES FROM ORIGINAL:
//   1. Added import for TutorialService
//   2. Added import for TutorialScreen
//   3. In _handleLogin() success block — replaced direct
//      HomeScreen push with _navigateAfterLogin() which checks
//      if the user has seen the tutorial first.
//
// Everything else is UNCHANGED.
// ============================================================

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/tutorial_service.dart';        // ← NEW
import '../utils/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import 'signup_screen.dart';
import 'home_screen.dart';
import 'forgot_password_screen.dart';
import 'email_verification_screen.dart';
import 'tutorial_screen.dart';                     // ← NEW

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
  final _tutorialService    = TutorialService();   // ← NEW
  bool    _isLoading    = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── NEW: Decides where to go after a successful login ─────
  // If the user hasn't seen the tutorial intro yet → TutorialScreen
  // Otherwise → HomeScreen (same behaviour as before)
  Future<void> _navigateAfterLogin(user) async {
    final hasSeenIntro = await _tutorialService.hasSeenIntro();

    if (!mounted) return;

    final destination = hasSeenIntro
        ? HomeScreen(user: user)
        : TutorialScreen(user: user); // TutorialScreen navigates to Home when done

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => destination,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
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

    if (result.success && result.user != null) {
      // ── CHANGED: was Navigator.pushReplacement(HomeScreen) ──
      // Now routes through tutorial check first
      await _navigateAfterLogin(result.user!);

    } else if (result.message == 'email_not_verified' && result.user != null) {
      // UNCHANGED
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(
            email: result.user!.email, user: result.user!,
          ),
        ),
      );
    } else {
      // UNCHANGED
      setState(() => _errorMessage = result.message);
    }
  }

  // ── Everything below this line is 100% UNCHANGED ──────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(children: [
        _buildHero(),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppTheme.paddingL, 0,
              AppTheme.paddingL,
              MediaQuery.of(context).padding.bottom + AppTheme.paddingL,
            ),
            child: Column(children: [
              _buildFormCard(),
              const SizedBox(height: 20),
              _buildSignupRedirect(),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildHero() {
    return Container(
      width:  double.infinity,
      height: 260,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F1E3D), Color(0xFF0A0E1A)],
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
                gradient: AppTheme.primaryGradient,
                shape:    BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:      AppTheme.primary.withValues(alpha: 0.4),
                    blurRadius: 28, spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.remove_red_eye_rounded,
                  color: Colors.white, size: 34),
            ),
            const SizedBox(height: 16),
            RichText(
              text: const TextSpan(children: [
                TextSpan(text: 'Truth',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
                TextSpan(text: 'Lens',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                        color: AppTheme.primary)),
                TextSpan(text: ' AI',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                        color: AppTheme.accent)),
              ]),
            ),
            const SizedBox(height: 6),
            const Text('Welcome back',
                style: TextStyle(fontSize: 14,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.3)),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Transform.translate(
      offset: const Offset(0, -24),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.paddingL),
        decoration: BoxDecoration(
          color:        AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(color: AppTheme.surfaceBorder),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withValues(alpha: 0.3),
              blurRadius: 24, spreadRadius: 2,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(children: [
            Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.login_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sign In',
                      style: TextStyle(fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary)),
                  Text('to your account',
                      style: TextStyle(fontSize: 12,
                          color: AppTheme.textSecondary)),
                ],
              ),
            ]),
            const SizedBox(height: 20),
            const Divider(color: AppTheme.surfaceBorder),
            const SizedBox(height: 20),
            CustomTextField(
              label:        'Email',
              hint:         'you@example.com',
              controller:   _emailController,
              icon:         Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator:    Validators.email,
            ),
            const SizedBox(height: 14),
            CustomTextField(
              label:           'Password',
              hint:            'Enter your password',
              controller:      _passwordController,
              icon:            Icons.lock_outline,
              isPassword:      true,
              validator:       Validators.password,
              textInputAction: TextInputAction.done,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const ForgotPasswordScreen()),
                ),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 4)),
                child: const Text('Forgot Password?',
                    style: TextStyle(color: AppTheme.primary,
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
            if (_errorMessage != null) ...[
              _buildErrorBanner(),
              const SizedBox(height: 12),
            ],
            PrimaryButton(
              label:     'Sign In',
              onPressed: _handleLogin,
              isLoading: _isLoading,
            ),
          ]),
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
          child: const Text('Sign up',
              style: TextStyle(color: AppTheme.primary,
                  fontWeight: FontWeight.w700, fontSize: 14)),
        ),
      ],
    );
  }
}
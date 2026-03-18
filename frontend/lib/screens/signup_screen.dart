// screens/signup_screen.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';
import 'email_verification_screen.dart';
import 'login_screen.dart';

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
              email: _emailController.text.trim(), user: result.user!,
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      // AFTER:
      body: SingleChildScrollView(
        child: Column(children: [
          _buildHero(),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppTheme.paddingL, 16,
              AppTheme.paddingL,
              MediaQuery.of(context).padding.bottom + AppTheme.paddingL,
            ),
            child: Column(children: [
              _buildFormCard(),
              const SizedBox(height: 16),
              _buildLoginRedirect(),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      width:  double.infinity,
      height: 180,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1500), Color(0xFF0A0E1A)],
          begin:  Alignment.topCenter,
          end:    Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    gradient: AppTheme.accentGradient,
                    shape:    BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:      AppTheme.accent.withValues(alpha: 0.4),
                        blurRadius: 24, spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.person_add_rounded,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(height: 14),
                RichText(
                  text: const TextSpan(children: [
                    TextSpan(text: 'Truth',
                        style: TextStyle(fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary)),
                    TextSpan(text: 'Lens',
                        style: TextStyle(fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary)),
                    TextSpan(text: ' AI',
                        style: TextStyle(fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.accent)),
                  ]),
                ),
                const SizedBox(height: 4),
                const Text('Create your account',
                    style: TextStyle(fontSize: 13,
                        color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
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
            // Card header
            Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_add_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sign Up',
                      style: TextStyle(fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary)),
                  Text('join the community',
                      style: TextStyle(fontSize: 12,
                          color: AppTheme.textSecondary)),
                ],
              ),
            ]),
            const SizedBox(height: 20),
            const Divider(color: AppTheme.surfaceBorder),
            const SizedBox(height: 20),
            CustomTextField(
              label:     'Full Name',
              hint:      'John Doe',
              controller: _nameController,
              icon:      Icons.person_outline,
              validator: Validators.name,
            ),
            const SizedBox(height: 14),
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
              label:      'Password',
              hint:       'Create a strong password',
              controller: _passwordController,
              icon:       Icons.lock_outline,
              isPassword: true,
              validator:  Validators.password,
            ),
            const SizedBox(height: 14),
            CustomTextField(
              label:      'Confirm Password',
              hint:       'Repeat your password',
              controller: _confirmPasswordController,
              icon:       Icons.lock_outline,
              isPassword: true,
              validator:  (value) => Validators.confirmPassword(
                  value, _passwordController.text),
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
            const SizedBox(height: 14),
            const Text(
              'By creating an account you agree to our\nTerms of Service and Privacy Policy.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11,
                  color: AppTheme.textSecondary, height: 1.5),
            ),
          ]),
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

  Widget _buildLoginRedirect() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Already have an account? ',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        GestureDetector(
          onTap: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          ),
          child: const Text('Sign in',
              style: TextStyle(color: AppTheme.primary,
                  fontWeight: FontWeight.w700, fontSize: 14)),
        ),
      ],
    );
  }
}
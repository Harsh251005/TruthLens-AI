// screens/splash_screen.dart
// ============================================================
// Branded splash screen shown on app launch.
// Checks: onboarding seen? → logged in? → redirect.
// ============================================================

import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../utils/app_theme.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startSequence();
  }

  void _setupAnimations() {
    _controller = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller,
          curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller,
          curve: const Interval(0.0, 0.6, curve: Curves.elasticOut)),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.5), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut)));
  }

  Future<void> _startSequence() async {
    _controller.forward();
    await Future.delayed(const Duration(milliseconds: 2500));

    // Check onboarding and session
    final seenOnboarding = await StorageService.hasSeenOnboarding();
    final savedUser      = await StorageService.getSavedUser();

    if (!mounted) return;

    Widget nextScreen;
    if (!seenOnboarding) {
      // First launch → show onboarding
      nextScreen = const OnboardingScreen();
    } else if (savedUser != null) {
      // Logged in → go to home
      nextScreen = HomeScreen(user: savedUser);
    } else {
      // Not logged in → go to login
      nextScreen = const LoginScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => nextScreen,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0E1A), Color(0xFF0F1629)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (_, child) => FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(scale: _scaleAnim, child: child),
                ),
                child: _buildLogo(),
              ),
              const SizedBox(height: 24),
              AnimatedBuilder(
                animation: _controller,
                builder: (_, child) => FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(position: _slideAnim, child: child),
                ),
                child: const Text(
                  'Deepfake Detection Powered by Axiom',
                  style: TextStyle(fontSize: 14,
                      color: AppTheme.textSecondary, letterSpacing: 0.5),
                ),
              ),
              const SizedBox(height: 80),
              FadeTransition(
                opacity: _fadeAnim,
                child: SizedBox(
                  width: 32, height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primary.withValues(alpha: 0.7)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.primaryGradient,
            boxShadow: [
              BoxShadow(color: AppTheme.primary.withValues(alpha: 0.4),
                  blurRadius: 32, spreadRadius: 4),
            ],
          ),
          child: const Icon(Icons.remove_red_eye_rounded,
              color: Colors.white, size: 48),
        ),
        const SizedBox(height: 20),
        RichText(
          text: const TextSpan(children: [
            TextSpan(text: 'Truth', style: TextStyle(fontSize: 36,
                fontWeight: FontWeight.w800, color: AppTheme.textPrimary,
                letterSpacing: -0.5)),
            TextSpan(text: 'Lens', style: TextStyle(fontSize: 36,
                fontWeight: FontWeight.w800, color: AppTheme.primary,
                letterSpacing: -0.5)),
            TextSpan(text: ' AI', style: TextStyle(fontSize: 36,
                fontWeight: FontWeight.w800, color: AppTheme.accent,
                letterSpacing: -0.5)),
          ]),
        ),
      ],
    );
  }
}
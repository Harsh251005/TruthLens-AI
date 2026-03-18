// screens/onboarding_screen.dart
// ============================================================
// Onboarding — shown only on first app launch.
// 3 slides explaining what TruthLens AI does.
// Marks onboarding seen, then navigates to login.
// ============================================================

import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../utils/app_theme.dart';
import 'signup_screen.dart';
import '../services/notification_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // ── Onboarding slides data ────────────────────────────────────
  final List<_OnboardingSlide> _slides = const [
    _OnboardingSlide(
      icon:     Icons.remove_red_eye_rounded,
      color:    AppTheme.primary,
      title:    'Welcome to TruthLens AI',
      subtitle: 'The smartest way to detect deepfakes and AI-generated images in seconds.',
      gradient: LinearGradient(
        colors: [Color(0xFF1A2744), Color(0xFF0A0E1A)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
    _OnboardingSlide(
      icon:     Icons.document_scanner_rounded,
      color:    AppTheme.accent,
      title:    'Upload Any Face Photo',
      subtitle: 'Simply pick a photo from your gallery or take one with your camera. Our AI does the rest.',
      gradient: LinearGradient(
        colors: [Color(0xFF2B1F0A), Color(0xFF0A0E1A)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
    _OnboardingSlide(
      icon:     Icons.verified_rounded,
      color:    AppTheme.success,
      title:    'Instant AI Verdict',
      subtitle: 'Get a real-time verdict with confidence score, detailed analysis, and the ability to share results.',
      gradient: LinearGradient(
        colors: [Color(0xFF0D2B1F), Color(0xFF0A0E1A)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
  ];

  // ── Navigation ────────────────────────────────────────────────
  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve:    Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  // AFTER:
  Future<void> _finishOnboarding() async {
    await StorageService.setOnboardingSeen();

    // Request notification permission on first launch
    // Android 13+ requires explicit permission — this shows the system dialog
    await NotificationService().requestPermission();

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const SignupScreen(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // ── Page view ────────────────────────────────────────
          PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: _slides.length,
            itemBuilder: (_, i) => _buildSlide(_slides[i]),
          ),

          // ── Bottom controls ───────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _buildBottomControls(),
          ),

          // ── Skip button ───────────────────────────────────────
          Positioned(
            top: 52, right: 24,
            child: _currentPage < _slides.length - 1
                ? TextButton(
              onPressed: _finishOnboarding,
              child: const Text('Skip',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 14)),
            )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ── Slide Builder ─────────────────────────────────────────────
  Widget _buildSlide(_OnboardingSlide slide) {
    return Container(
      decoration: BoxDecoration(gradient: slide.gradient),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingXL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),

              // Icon with glow
              Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  color: slide.color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: slide.color.withValues(alpha: 0.3), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: slide.color.withValues(alpha: 0.2),
                      blurRadius: 40, spreadRadius: 8,
                    ),
                  ],
                ),
                child: Icon(slide.icon, color: slide.color, size: 56),
              ),

              const SizedBox(height: 48),

              // Title
              Text(
                slide.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 16),

              // Subtitle
              Text(
                slide.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 160), // Space for bottom controls
            ],
          ),
        ),
      ),
    );
  }

  // ── Bottom Controls ───────────────────────────────────────────
  Widget _buildBottomControls() {
    final isLast = _currentPage == _slides.length - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.paddingL, AppTheme.paddingL,
          AppTheme.paddingL, 48),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
          colors: [Colors.transparent, AppTheme.background.withValues(alpha: 0.95)],
        ),
      ),
      child: Column(
        children: [
          // Page indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_slides.length, (i) => _buildDot(i)),
          ),

          const SizedBox(height: 32),

          // Next / Get Started button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: _slides[_currentPage].color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM)),
                elevation: 0,
              ),
              child: Text(
                isLast ? 'Get Started' : 'Next',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Page Dot Indicator ────────────────────────────────────────
  Widget _buildDot(int index) {
    final isActive = index == _currentPage;
    final color    = _slides[_currentPage].color;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width:  isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color:        isActive ? color : AppTheme.surfaceBorder,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// ── Onboarding Slide Model ────────────────────────────────────────
class _OnboardingSlide {
  final IconData      icon;
  final Color         color;
  final String        title;
  final String        subtitle;
  final LinearGradient gradient;

  const _OnboardingSlide({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.gradient,
  });
}
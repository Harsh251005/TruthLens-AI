// screens/tutorial_screen.dart
// ============================================================
// CHANGES FROM ORIGINAL:
//   1. Accepts required `user` UserModel param
//   2. _onGetStarted() pushes HomeScreen(user: widget.user)
//      instead of a named route
//   3. FIXED: typo 'TutorialScreen' → 'TutorialScreen'
//      (this was causing a compile error → broken nav stack)
// ============================================================

import 'package:flutter/material.dart';
import '../models/tutorial_slide_model.dart';
import '../models/user_model.dart';
import '../services/tutorial_service.dart';
import '../utils/app_theme.dart';
import 'home_screen.dart';

class TutorialScreen extends StatefulWidget {
  final UserModel user;

  const TutorialScreen({super.key, required this.user}); // ← FIXED typo

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen>
    with TickerProviderStateMixin {
  final PageController  _pageController = PageController();
  final TutorialService _service        = TutorialService();

  int _currentPage = 0;

  late AnimationController _entryController;
  late Animation<double>   _entryAnim;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _entryAnim = CurvedAnimation(
      parent: _entryController,
      curve:  Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < kTutorialSlides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve:    Curves.easeInOutCubic,
      );
    } else {
      _onGetStarted();
    }
  }

  void _skipAll() => _onGetStarted();

  Future<void> _onGetStarted() async {
    await _service.markIntroSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => HomeScreen(user: widget.user),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: FadeTransition(
        opacity: _entryAnim,
        child: Stack(
          children: [
            _BackgroundMesh(pageIndex: _currentPage),
            PageView.builder(
              controller:    _pageController,
              itemCount:     kTutorialSlides.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder:   (context, index) => _SlideContent(
                slide:    kTutorialSlides[index],
                isActive: index == _currentPage,
              ),
            ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _BottomControls(
                currentPage: _currentPage,
                totalPages:  kTutorialSlides.length,
                onNext:      _nextPage,
                onSkip:      _skipAll,
                accentColor: kTutorialSlides[_currentPage].accentColor,
              ),
            ),
            Positioned(
              top:   MediaQuery.of(context).padding.top + 16,
              right: AppTheme.paddingL,
              child: _currentPage < kTutorialSlides.length - 1
                  ? TextButton(
                onPressed: _skipAll,
                child: const Text('Skip',
                    style: TextStyle(
                      color:      AppTheme.textSecondary,
                      fontSize:   14,
                      fontWeight: FontWeight.w500,
                    )),
              )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Slide Content ─────────────────────────────────────────────

class _SlideContent extends StatelessWidget {
  final TutorialSlideModel slide;
  final bool               isActive;
  const _SlideContent({required this.slide, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingXL),
      child: Column(
        children: [
          SizedBox(height: size.height * 0.12),
          AnimatedScale(
            scale:    isActive ? 1.0 : 0.85,
            duration: const Duration(milliseconds: 400),
            curve:    Curves.easeOutBack,
            child:    _IconIllustration(slide: slide),
          ),
          SizedBox(height: size.height * 0.06),
          AnimatedOpacity(
            opacity:  isActive ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 350),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color:        slide.accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border:       Border.all(color: slide.accentColor.withValues(alpha: 0.4)),
              ),
              child: Text(slide.tag,
                  style: TextStyle(
                    color: slide.accentColor, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 2.0,
                  )),
            ),
          ),
          const SizedBox(height: 20),
          AnimatedSlide(
            offset:   isActive ? Offset.zero : const Offset(0, 0.1),
            duration: const Duration(milliseconds: 400),
            curve:    Curves.easeOut,
            child: Text(slide.headline,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 26,
                  fontWeight: FontWeight.w800, height: 1.25,
                  letterSpacing: -0.5,
                )),
          ),
          const SizedBox(height: 14),
          AnimatedSlide(
            offset:   isActive ? Offset.zero : const Offset(0, 0.1),
            duration: const Duration(milliseconds: 500),
            curve:    Curves.easeOut,
            child: Text(slide.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 15, height: 1.6,
                )),
          ),
        ],
      ),
    );
  }
}

// ── Icon Illustration ─────────────────────────────────────────

class _IconIllustration extends StatelessWidget {
  final TutorialSlideModel slide;
  const _IconIllustration({required this.slide});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200, height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 200, height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                slide.accentColor.withValues(alpha: 0.18), Colors.transparent,
              ]),
            ),
          ),
          Container(
            width: 150, height: 150,
            decoration: BoxDecoration(
              shape:    BoxShape.circle,
              color:    AppTheme.surface2,
              border:   Border.all(
                  color: slide.accentColor.withValues(alpha: 0.25), width: 1.5),
              boxShadow: [
                BoxShadow(color: slide.accentColor.withValues(alpha: 0.2),
                    blurRadius: 32, spreadRadius: 4),
              ],
            ),
          ),
          Icon(slide.icon, size: 68, color: slide.accentColor),
        ],
      ),
    );
  }
}

// ── Bottom Controls ───────────────────────────────────────────

class _BottomControls extends StatelessWidget {
  final int          currentPage;
  final int          totalPages;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final Color        accentColor;

  const _BottomControls({
    required this.currentPage, required this.totalPages,
    required this.onNext,      required this.onSkip,
    required this.accentColor,
  });

  bool get _isLast => currentPage == totalPages - 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left:   AppTheme.paddingXL, right: AppTheme.paddingXL,
        bottom: MediaQuery.of(context).padding.bottom + 32,
        top:    AppTheme.paddingL,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [AppTheme.background.withValues(alpha: 0.0), AppTheme.background],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DotIndicators(current: currentPage, total: totalPages, color: accentColor),
          const SizedBox(height: 28),
          GestureDetector(
            onTap: onNext,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity, height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor, accentColor.withValues(alpha: 0.75)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                boxShadow: [
                  BoxShadow(color: accentColor.withValues(alpha: 0.35),
                      blurRadius: 20, offset: const Offset(0, 6)),
                ],
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_isLast ? 'Get Started' : 'Continue',
                        style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800,
                          fontSize: 16, letterSpacing: 0.3,
                        )),
                    const SizedBox(width: 8),
                    Icon(
                      _isLast ? Icons.rocket_launch_rounded
                          : Icons.arrow_forward_rounded,
                      color: Colors.white, size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dot Indicators ────────────────────────────────────────────

class _DotIndicators extends StatelessWidget {
  final int current, total;
  final Color color;
  const _DotIndicators({
    required this.current, required this.total, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve:    Curves.easeOutCubic,
          margin:   const EdgeInsets.symmetric(horizontal: 4),
          width:    isActive ? 28.0 : 8.0,
          height:   8.0,
          decoration: BoxDecoration(
            color:        isActive ? color : AppTheme.surfaceBorder,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ── Animated Background Mesh ──────────────────────────────────

class _BackgroundMesh extends StatelessWidget {
  final int pageIndex;
  const _BackgroundMesh({required this.pageIndex});

  @override
  Widget build(BuildContext context) {
    final color = kTutorialSlides[pageIndex].accentColor;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve:    Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.5, -0.8),
          radius: 1.2,
          colors: [color.withValues(alpha: 0.08), AppTheme.background],
        ),
      ),
    );
  }
}
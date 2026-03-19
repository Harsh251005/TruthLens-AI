// widgets/tutorial/tutorial_coach_overlay.dart
// ============================================================
// Full-screen overlay that dims everything EXCEPT the target
// widget (spotlight effect). Shows a tooltip card with title,
// description, step counter, and Next/Done button.
// Supports animated transitions between steps.
// ============================================================

import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../utils/tutorial_controller.dart';

// ── Entry Point ───────────────────────────────────────────────

/// Push the coach overlay as a transparent route so the real
/// screen stays visible beneath the dim layer.
Future<void> showTutorialCoachOverlay({
  required BuildContext context,
  required List<CoachStep> steps,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false, // Keep underlying screen visible
      barrierDismissible: false,
      pageBuilder: (_, __, ___) => _CoachOverlayPage(steps: steps),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

// ── Main Overlay Page ─────────────────────────────────────────

class _CoachOverlayPage extends StatefulWidget {
  final List<CoachStep> steps;
  const _CoachOverlayPage({required this.steps});

  @override
  State<_CoachOverlayPage> createState() => _CoachOverlayPageState();
}

class _CoachOverlayPageState extends State<_CoachOverlayPage>
    with TickerProviderStateMixin {
  int _currentStep = 0;

  // Animation controllers
  late AnimationController _pulseController;   // Spotlight ring pulse
  late AnimationController _fadeController;    // Step-to-step fade
  late Animation<double>   _pulseAnim;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();

    // Pulsing ring around the spotlight
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Fade between steps
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────

  /// Get the screen-space Rect of the current step's target widget.
  Rect? _getTargetRect() {
    final key = widget.steps[_currentStep].targetKey;
    final ctx = key.currentContext;
    if (ctx == null) return null;

    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;

    final offset = box.localToGlobal(Offset.zero);
    return offset & box.size; // Rect from offset + size
  }

  /// Advance to the next step with a fade transition.
  Future<void> _nextStep() async {
    await _fadeController.reverse(); // Fade out current tooltip

    setState(() {
      _currentStep++;
    });

    await _fadeController.forward(); // Fade in next tooltip
  }

  /// Dismiss the overlay when all steps are done.
  void _finish() {
    Navigator.of(context).pop();
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final step   = widget.steps[_currentStep];
    final rect   = _getTargetRect();
    final size   = MediaQuery.of(context).size;
    final isLast = _currentStep == widget.steps.length - 1;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // ── Dim Layer with Spotlight Cutout ──────────────
          if (rect != null)
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => CustomPaint(
                size: size,
                painter: _SpotlightPainter(
                  targetRect: rect,
                  pulseValue:  _pulseAnim.value,
                ),
              ),
            )
          else
          // Fallback: full dim if widget not found
            Container(color: Colors.black.withOpacity(0.75)),

          // ── Tooltip Card ──────────────────────────────────
          FadeTransition(
            opacity: _fadeAnim,
            child: _TooltipCard(
              step:        step,
              currentStep: _currentStep,
              totalSteps:  widget.steps.length,
              targetRect:  rect,
              screenSize:  size,
              isLast:      isLast,
              onNext:      _nextStep,
              onSkip:      _finish,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Spotlight Painter ─────────────────────────────────────────

/// CustomPainter that fills the screen with a semi-transparent dark
/// overlay, then punches a circular hole over the target widget.
/// An animated ring pulses around the hole for visual attention.
class _SpotlightPainter extends CustomPainter {
  final Rect   targetRect;
  final double pulseValue; // 0.0 → 1.0 for pulsing ring

  static const double _padding      = 20.0; // Extra space around widget
  static const double _maxRingExtra = 12.0; // Max ring expansion

  _SpotlightPainter({required this.targetRect, required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = targetRect.center;
    // Radius = half the diagonal of the target + padding
    final radius = (targetRect.longestSide / 2) + _padding;

    // ── Dim overlay ──────────────────────────────────────
    final dimPaint = Paint()..color = Colors.black.withOpacity(0.78);

    // Draw dim layer with an inverted circular clip (hole in the middle)
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, dimPaint);

    // Cut out the spotlight circle
    final holePaint = Paint()..blendMode = BlendMode.clear;
    canvas.drawCircle(center, radius, holePaint);
    canvas.restore();

    // ── Pulsing ring ─────────────────────────────────────
    final ringRadius = radius + (_maxRingExtra * pulseValue);
    final ringPaint  = Paint()
      ..color  = AppTheme.primary.withOpacity(0.5 * (1 - pulseValue))
      ..style  = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, ringRadius, ringPaint);

    // ── Inner border ring ─────────────────────────────────
    final borderPaint = Paint()
      ..color  = AppTheme.primary.withOpacity(0.8)
      ..style  = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius + 2, borderPaint);
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.pulseValue != pulseValue || old.targetRect != targetRect;
}

// ── Tooltip Card ──────────────────────────────────────────────

/// Positioned card that appears above or below the spotlight circle.
/// Contains step counter, title, description, Skip and Next/Done buttons.
class _TooltipCard extends StatelessWidget {
  final CoachStep    step;
  final int          currentStep;
  final int          totalSteps;
  final Rect?        targetRect;
  final Size         screenSize;
  final bool         isLast;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _TooltipCard({
    required this.step,
    required this.currentStep,
    required this.totalSteps,
    required this.targetRect,
    required this.screenSize,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    const cardWidth   = 300.0;
    const cardPadding = 20.0;

    // ── Vertical position logic ───────────────────────────
    double cardTop;
    if (targetRect == null) {
      cardTop = screenSize.height * 0.5 - 100;
    } else {
      final center  = targetRect!.center;
      final radius  = (targetRect!.longestSide / 2) + 20;

      if (step.position == TooltipPosition.above) {
        // Place card above the spotlight
        cardTop = center.dy - radius - 180;
      } else {
        // Place card below the spotlight
        cardTop = center.dy + radius + 24;
      }

      // Clamp to screen bounds
      cardTop = cardTop.clamp(
        MediaQuery.of(context).padding.top + 16,
        screenSize.height - 220,
      );
    }

    // ── Horizontal centering ──────────────────────────────
    final cardLeft = (screenSize.width - cardWidth) / 2;

    return Positioned(
      top:  cardTop,
      left: cardLeft,
      width: cardWidth,
      child: _buildCard(context, cardPadding),
    );
  }

  Widget _buildCard(BuildContext context, double padding) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(color: AppTheme.primary.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.18),
            blurRadius: 28,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Step counter pill
          _StepPill(current: currentStep + 1, total: totalSteps),
          const SizedBox(height: 12),

          // Title
          Text(
            step.title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            step.description,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),

          // Buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Skip button
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                ),
                child: const Text('Skip', style: TextStyle(fontSize: 13)),
              ),

              // Next / Done button
              GestureDetector(
                onTap: isLast ? onSkip : onNext,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isLast ? 'Done' : 'Next',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      if (!isLast) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 15),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Step Counter Pill ─────────────────────────────────────────

class _StepPill extends StatelessWidget {
  final int current;
  final int total;
  const _StepPill({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
          ),
          child: Text(
            'Step $current of $total',
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const Spacer(),
        // Dot indicators
        Row(
          children: List.generate(total, (i) => _dot(i < current)),
        ),
      ],
    );
  }

  Widget _dot(bool filled) => Container(
    width: 6, height: 6,
    margin: const EdgeInsets.only(left: 4),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: filled ? AppTheme.primary : AppTheme.surfaceBorder,
    ),
  );
}
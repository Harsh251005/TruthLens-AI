// widgets/scanning_overlay.dart
// ============================================================
// Animated scanning overlay shown while AI is processing.
// Shows a moving scan line over the image with pulsing effect.
// ============================================================

import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class ScanningOverlay extends StatefulWidget {
  const ScanningOverlay({super.key});

  @override
  State<ScanningOverlay> createState() => _ScanningOverlayState();
}

class _ScanningOverlayState extends State<ScanningOverlay>
    with TickerProviderStateMixin {

  // ── Scan line animation — moves top to bottom repeatedly ──────
  late AnimationController _scanController;
  late Animation<double>   _scanAnim;

  // ── Pulse animation — fades in and out ────────────────────────
  late AnimationController _pulseController;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();

    // Scan line — moves up and down continuously
    _scanController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _scanAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );

    // Pulse — fades in and out continuously
    _pulseController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scanController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_scanAnim, _pulseAnim]),
      builder: (_, _) {
        return Stack(
          children: [
            // ── Dark overlay on image ──────────────────────────
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),

            // ── Corner brackets ────────────────────────────────
            ..._buildCornerBrackets(),

            // ── Moving scan line ───────────────────────────────
            Positioned(
              top: _scanAnim.value *
                  (MediaQuery.of(context).size.width - 48 - 24),
              left:  12,
              right: 12,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppTheme.primary.withValues(alpha: 0.8),
                      AppTheme.primary,
                      AppTheme.primary.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.6),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),

            // ── Pulsing center text ────────────────────────────
            Center(
              child: Opacity(
                opacity: _pulseAnim.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.background.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.primary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('Analysing...',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Corner bracket decorations ────────────────────────────────
  List<Widget> _buildCornerBrackets() {
    const size    = 24.0;
    const width   = 3.0;
    final color   = AppTheme.primary;
    const padding = 12.0;

    return [
      // Top left
      Positioned(top: padding, left: padding,
          child: _bracket(size, width, color, top: true, left: true)),
      // Top right
      Positioned(top: padding, right: padding,
          child: _bracket(size, width, color, top: true, left: false)),
      // Bottom left
      Positioned(bottom: padding, left: padding,
          child: _bracket(size, width, color, top: false, left: true)),
      // Bottom right
      Positioned(bottom: padding, right: padding,
          child: _bracket(size, width, color, top: false, left: false)),
    ];
  }

  Widget _bracket(double size, double width, Color color,
      {required bool top, required bool left}) {
    return SizedBox(
      width: size, height: size,
      child: CustomPaint(
        painter: _BracketPainter(
            color: color, width: width, top: top, left: left),
      ),
    );
  }
}

// ── Bracket Painter ───────────────────────────────────────────────
class _BracketPainter extends CustomPainter {
  final Color  color;
  final double width;
  final bool   top;
  final bool   left;

  _BracketPainter({
    required this.color,
    required this.width,
    required this.top,
    required this.left,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = color
      ..strokeWidth = width
      ..strokeCap   = StrokeCap.round
      ..style       = PaintingStyle.stroke;

    final x = left ? 0.0 : size.width;
    final y = top  ? 0.0 : size.height;
    final xEnd = left ? size.width : 0.0;
    final yEnd = top  ? size.height : 0.0;

    // Horizontal arm
    canvas.drawLine(Offset(x, y), Offset(xEnd, y), paint);
    // Vertical arm
    canvas.drawLine(Offset(x, y), Offset(x, yEnd), paint);
  }

  @override
  bool shouldRepaint(_BracketPainter old) => old.color != color;
}
// screens/result_screen.dart
// ============================================================
// CHANGES FROM ORIGINAL:
//   1. Removed screenshot package import and ScreenshotController
//   2. Removed Screenshot widget wrapper around _buildShareCard
//   3. _handleShare() rewritten — shares text summary instead
//      of a captured image (screenshot package was removed)
//   4. Everything else — UI, animations, cards — UNCHANGED
// ============================================================

import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../services/detection_service.dart';
import '../utils/app_theme.dart';

class ResultScreen extends StatefulWidget {
  final DetectionResult result;
  final String          imagePath;

  const ResultScreen({
    super.key,
    required this.result,
    required this.imagePath,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {

  // ── Animation controllers ──────────────────────────────────
  late AnimationController _controller;
  late Animation<double>   _fadeAnim;
  late Animation<double>   _scaleAnim;
  late Animation<double>   _progressAnim;

  bool _isSharing = false;

  // Key attached to the off-screen share card RepaintBoundary.
  // Used to capture the widget as a PNG image for sharing.
  final GlobalKey _shareCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _controller.forward();
    _triggerHaptic();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerHaptic() {
    if (widget.result.isFake) {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 200),
          HapticFeedback.heavyImpact);
    } else {
      HapticFeedback.lightImpact();
    }
  }

  void _setupAnimations() {
    _controller = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve:  const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _scaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve:  const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    _progressAnim = Tween<double>(
      begin: 0.0,
      end:   widget.result.confidence / 100,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve:  const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  // ── Share handler ──────────────────────────────────────────
  // Captures the off-screen branded share card via RepaintBoundary,
  // saves it as a temp PNG, then shares image + short caption.
  Future<void> _handleShare() async {
    setState(() => _isSharing = true);
    try {
      // Step 1: Find the RenderRepaintBoundary from the key
      final boundary = _shareCardKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Share card not rendered');

      // Step 2: Capture to image (3x pixel ratio for crisp output)
      final image     = await boundary.toImage(pixelRatio: 3.0);
      final byteData  = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes  = byteData!.buffer.asUint8List();

      // Step 3: Write to temp file
      final tempDir  = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/truthlens_result.png');
      await tempFile.writeAsBytes(pngBytes);

      // Step 4: Share image + caption
      final caption =
          '🔍 Scanned with TruthLens AI\n'
          '${widget.result.isFake ? "⚠️ DEEPFAKE DETECTED" : "✅ AUTHENTIC IMAGE"} '
          '— ${widget.result.confidence.toStringAsFixed(1)}% confidence\n'
          '#TruthLensAI #DeepfakeDetection';

      await Share.shareXFiles(
        [XFile(tempFile.path, mimeType: 'image/png')],
        text: caption,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:         Text('Failed to share. Please try again.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final verdictColor =
    widget.result.isFake ? AppTheme.error : AppTheme.success;
    final verdictIcon  = widget.result.isFake
        ? Icons.dangerous_rounded
        : Icons.verified_rounded;
    final verdictLabel =
    widget.result.isFake ? 'DEEPFAKE DETECTED' : 'AUTHENTIC IMAGE';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title:           const Text('Analysis Result'),
        backgroundColor: AppTheme.surface,
        leading: IconButton(
          icon:      const Icon(Icons.arrow_back_ios_new,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: _isSharing
                ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.primary))
                : const Icon(Icons.share_rounded, color: AppTheme.primary),
            onPressed: _isSharing ? null : _handleShare,
            tooltip:   'Share Result',
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Off-screen branded share card ─────────────────
          // Positioned outside visible area so it renders but
          // is never shown to the user. RepaintBoundary captures
          // it as a PNG when the share button is tapped.
          Positioned(
            left: -2000,
            top:  0,
            child: RepaintBoundary(
              key: _shareCardKey,
              child: _buildBrandedShareCard(),
            ),
          ),

          // ── Main scrollable content ────────────────────────
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.paddingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // ── Result card ─────────────────────────────────
                // Screenshot wrapper removed — card UI unchanged
                _buildShareCard(verdictColor, verdictIcon, verdictLabel),

                const SizedBox(height: 16),

                // ── AI Explanation card ──────────────────────────
                FadeTransition(
                  opacity: _fadeAnim,
                  child:   _buildExplanationCard(),
                ),

                const SizedBox(height: 16),

                // ── EXIF Analysis card ───────────────────────────
                FadeTransition(
                  opacity: _fadeAnim,
                  child:   _buildExifCard(),
                ),

                const SizedBox(height: 16),

                // ── Tips card ────────────────────────────────────
                FadeTransition(
                  opacity: _fadeAnim,
                  child:   _buildTipsCard(verdictColor),
                ),

                const SizedBox(height: 24),

                // ── Action buttons ───────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSharing ? null : _handleShare,
                        icon:      const Icon(Icons.share_rounded, size: 18),
                        label:     const Text('Share Result',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side:    const BorderSide(color: AppTheme.primary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape:   RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(AppTheme.radiusM)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon:      const Icon(Icons.refresh_rounded, size: 18),
                        label:     const Text('Scan Again',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(AppTheme.radiusM)),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Result Card (UNCHANGED) ────────────────────────────────
  Widget _buildShareCard(Color color, IconData icon, String label) {
    return Container(
      decoration: BoxDecoration(
        color:        AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border:       Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.15),
              blurRadius: 24, spreadRadius: 2),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top gradient header ──────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.result.isFake
                    ? [const Color(0xFF2B0D0D), const Color(0xFF1a0808)]
                    : [const Color(0xFF0D2B1F), const Color(0xFF081a10)],
                begin: Alignment.topLeft,
                end:   Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft:  Radius.circular(AppTheme.radiusL - 1),
                topRight: Radius.circular(AppTheme.radiusL - 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Branding row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RichText(
                      text: const TextSpan(children: [
                        TextSpan(text: 'Truth',
                            style: TextStyle(fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary)),
                        TextSpan(text: 'Lens',
                            style: TextStyle(fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary)),
                        TextSpan(text: ' AI',
                            style: TextStyle(fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.accent)),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color:        color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: color.withValues(alpha: 0.3)),
                      ),
                      child: const Text('Deepfake Detection',
                          style: TextStyle(fontSize: 10,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Verdict icon + label
                Row(
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color:  color.withValues(alpha: 0.15),
                        shape:  BoxShape.circle,
                        border: Border.all(
                            color: color.withValues(alpha: 0.4), width: 2),
                      ),
                      child: Icon(icon, color: color, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              style: TextStyle(fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: color, letterSpacing: 0.5)),
                          const SizedBox(height: 2),
                          const Text('AI-powered analysis result',
                              style: TextStyle(fontSize: 11,
                                  color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Animated confidence number
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AnimatedBuilder(
                      animation: _progressAnim,
                      builder:   (_, _) => Text(
                        '${(_progressAnim.value * 100).toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 52,
                            fontWeight: FontWeight.w900,
                            color: color, height: 1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('confidence',
                          style: TextStyle(fontSize: 14,
                              color: color.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Animated confidence bar
                AnimatedBuilder(
                  animation: _progressAnim,
                  builder:   (_, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value:           _progressAnim.value,
                      backgroundColor: color.withValues(alpha: 0.12),
                      valueColor:      AlwaysStoppedAnimation<Color>(color),
                      minHeight:       8,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Scanned image ────────────────────────────────
          ClipRRect(
            child: Stack(
              children: [
                Image.file(
                  File(widget.imagePath),
                  height: 200,
                  width:  double.infinity,
                  fit:    BoxFit.cover,
                ),
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin:  Alignment.topCenter,
                        end:    Alignment.bottomCenter,
                        colors: [
                          widget.result.isFake
                              ? const Color(0xFF1a0808)
                              : const Color(0xFF081a10),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin:  Alignment.topCenter,
                        end:    Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppTheme.surface.withValues(alpha: 0.95),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color:        color.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Text(widget.result.verdict,
                            style: const TextStyle(color: Colors.white,
                                fontSize: 13, fontWeight: FontWeight.w800,
                                letterSpacing: 0.5)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Footer stats ─────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
                vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: const BorderRadius.only(
                bottomLeft:  Radius.circular(AppTheme.radiusL - 1),
                bottomRight: Radius.circular(AppTheme.radiusL - 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFooterStat(
                  label: 'Raw Score',
                  value: widget.result.rawScore.toStringAsFixed(4),
                  color: color,
                ),
                Container(width: 1, height: 28,
                    color: AppTheme.surfaceBorder),
                _buildFooterStat(
                  label: 'EXIF Fields',
                  // Show how many metadata fields were found — factual, not a risk label
                  value: widget.result.exifAnalysis.hasExif
                      ? '${widget.result.exifAnalysis.rawFields.length} found'
                      : 'None',
                  color: AppTheme.textSecondary,
                ),
                Container(width: 1, height: 28,
                    color: AppTheme.surfaceBorder),
                _buildFooterStat(
                  label: 'Analysed by',
                  value: 'Axiom v1.0',
                  color: AppTheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterStat({
    required String label,
    required String value,
    required Color  color,
  }) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 10,
                color: AppTheme.textSecondary)),
      ],
    );
  }

  // ── AI Explanation Card (UNCHANGED) ───────────────────────
  Widget _buildExplanationCard() {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color:        AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: AppTheme.primary, size: 16),
              ),
              const SizedBox(width: 10),
              const Text('AI EXPLANATION',
                  style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                      letterSpacing: 1.0)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.result.explanation,
            style: const TextStyle(fontSize: 14,
                color: AppTheme.textPrimary, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildExifCard() {
    final exif = widget.result.exifAnalysis;

    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header — no risk badge, neutral icon ──────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color:        AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.data_object_rounded,
                    color: AppTheme.primary, size: 16),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('EXIF METADATA',
                    style: TextStyle(fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                        letterSpacing: 1.0)),
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (exif.hasExif && exif.rawFields.isNotEmpty) ...[
            ...exif.rawFields.entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(entry.key,
                        style: const TextStyle(fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500)),
                  ),
                  Expanded(
                    child: Text(entry.value.toString(),
                        style: const TextStyle(fontSize: 12,
                            color: AppTheme.textPrimary)),
                  ),
                ],
              ),
            )),
            const Divider(color: AppTheme.surfaceBorder, height: 20),
          ],

          // Suspicion flags shown as neutral observations, not risk labels
          if (exif.suspicionFlags.isNotEmpty) ...[
            const Text('OBSERVATIONS',
                style: TextStyle(fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.8)),
            const SizedBox(height: 8),
            ...exif.suspicionFlags.map((flag) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Neutral info icon — these are observations, not verdicts
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(flag,
                        style: const TextStyle(fontSize: 12,
                            color: AppTheme.textSecondary, height: 1.4)),
                  ),
                ],
              ),
            )),
          ],

          if (!exif.hasExif) ...[
            Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    exif.summary,
                    style: const TextStyle(fontSize: 12,
                        color: AppTheme.textSecondary, height: 1.4),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Tips Card (UNCHANGED) ──────────────────────────────────
  Widget _buildTipsCard(Color color) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color:        color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.lightbulb_outline_rounded,
                    color: color, size: 16),
              ),
              const SizedBox(width: 10),
              const Text('WHAT TO LOOK FOR',
                  style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                      letterSpacing: 1.0)),
            ],
          ),
          const SizedBox(height: 12),
          ...widget.result.tips.map(
                (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 6, height: 6,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(tip,
                        style: const TextStyle(fontSize: 14,
                            color: AppTheme.textPrimary, height: 1.5)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  // ── Branded Share Card ─────────────────────────────────────
  // Rendered off-screen and captured as PNG via RepaintBoundary.
  // Fixed 400×500 ensures consistent output on all devices.
  Widget _buildBrandedShareCard() {
    final isFake       = widget.result.isFake;
    final verdictColor = isFake ? AppTheme.error : AppTheme.success;
    final verdictLabel = isFake ? 'DEEPFAKE' : 'AUTHENTIC';
    final verdictIcon  = isFake
        ? Icons.dangerous_rounded
        : Icons.verified_rounded;

    // Show a couple of key EXIF fields in the card footer if available
    final exif        = widget.result.exifAnalysis;
    final cameraModel = exif.rawFields['Camera Model'] as String?;
    final dateTaken   = exif.rawFields['Date Taken']   as String?;

    return SizedBox(
      width: 400, height: 460,
      child: Container(
        decoration: BoxDecoration(
          color:        const Color(0xFF0A0E1A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: verdictColor.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Stack(
          children: [

            // ── Scan-line texture overlay ─────────────────────
            Positioned.fill(
              child: CustomPaint(painter: _ScanLinePainter()),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Logo row + verdict tag ────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RichText(
                        text: const TextSpan(children: [
                          TextSpan(text: 'Truth',
                              style: TextStyle(fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFF9FAFB))),
                          TextSpan(text: 'Lens',
                              style: TextStyle(fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF4F8EF7))),
                          TextSpan(text: ' AI',
                              style: TextStyle(fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFF5A623))),
                        ]),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: verdictColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: verdictColor.withValues(alpha: 0.3)),
                        ),
                        child: Text('Deepfake Detection',
                            style: TextStyle(fontSize: 10,
                                color: verdictColor,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Scanned image with verdict overlay ────────
                  // This is the key visual — shows the actual face
                  // that was scanned so recipients know what was checked.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        Image.file(
                          File(widget.imagePath),
                          width:  double.infinity,
                          height: 220,
                          fit:    BoxFit.cover,
                        ),

                        // Dark gradient at bottom of image
                        Positioned(
                          bottom: 0, left: 0, right: 0,
                          child: Container(
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin:  Alignment.topCenter,
                                end:    Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  const Color(0xFF0A0E1A)
                                      .withValues(alpha: 0.95),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Verdict badge pinned bottom-left on the image
                        Positioned(
                          bottom: 12, left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: verdictColor.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(verdictIcon,
                                    color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Text(verdictLabel,
                                    style: const TextStyle(
                                        color:      Colors.white,
                                        fontSize:   14,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.5)),
                              ],
                            ),
                          ),
                        ),

                        // Confidence pinned bottom-right on the image
                        Positioned(
                          bottom: 12, right: 12,
                          child: Text(
                            '${widget.result.confidence.toStringAsFixed(1)}%',
                            style: TextStyle(
                                fontSize:   22,
                                fontWeight: FontWeight.w900,
                                color:      verdictColor,
                                height:     1),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Confidence bar ────────────────────────────
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value:           widget.result.confidence / 100,
                      backgroundColor: verdictColor.withValues(alpha: 0.12),
                      valueColor:      AlwaysStoppedAnimation<Color>(
                          verdictColor),
                      minHeight:       6,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Thin divider ──────────────────────────────
                  Container(height: 1, color: const Color(0xFF1F2937)),
                  const SizedBox(height: 12),

                  // ── EXIF snippet + Axiom badge ────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (cameraModel != null)
                              _shareMetaRow(
                                  Icons.camera_alt_outlined, cameraModel),
                            if (dateTaken != null)
                              _shareMetaRow(
                                  Icons.calendar_today_outlined, dateTaken),
                            if (cameraModel == null && dateTaken == null)
                              _shareMetaRow(Icons.info_outline,
                                  'No camera metadata'),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F8EF7)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF4F8EF7)
                                  .withValues(alpha: 0.25)),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text('Axiom v1.0',
                                style: TextStyle(fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF4F8EF7))),
                            Text('Powered by',
                                style: TextStyle(fontSize: 9,
                                    color: Color(0xFF9CA3AF))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Small metadata row inside share card ───────────────────
  Widget _shareMetaRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(icon, size: 11, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11,
                  color: Color(0xFF9CA3AF))),
        ),
      ]),
    );
  }
}


// ── Scan-line texture painter ─────────────────────────────────
// Draws subtle horizontal lines over the share card background
// to give it a "tech screen" aesthetic.
class _ScanLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 1;

    // Draw a horizontal line every 6px across the full card height
    for (double y = 0; y < size.height; y += 6) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_ScanLinePainter oldDelegate) => false;
}
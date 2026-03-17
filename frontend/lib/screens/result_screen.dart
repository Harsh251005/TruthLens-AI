  // screens/result_screen.dart
  // ============================================================
  // Rich result screen showing:
  //   - Verdict badge + confidence bar
  //   - AI-generated explanation (Gemini LLM)
  //   - EXIF metadata analysis
  //   - Detection tips
  //   - Share card with branding
  // ============================================================

  import 'dart:io';
  // import 'dart:typed_data';
  import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';
  import 'package:screenshot/screenshot.dart';
  import 'package:share_plus/share_plus.dart';
  import 'package:path_provider/path_provider.dart';
  import '../services/detection_service.dart';
  import '../utils/app_theme.dart';

  class ResultScreen extends StatefulWidget {
    final DetectionResult result;
    final String imagePath;

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

    // ── Animation controllers ─────────────────────────────────────
    late AnimationController _controller;
    late Animation<double>   _fadeAnim;
    late Animation<double>   _scaleAnim;
    late Animation<double>   _progressAnim;

    // ── Screenshot controller for sharing ─────────────────────────
    final _screenshotController = ScreenshotController();
    bool _isSharing = false;

    @override
    void initState() {
      super.initState();
      _setupAnimations();
      _controller.forward();
      _triggerHaptic();
    }

    /// Haptic feedback — heavy double tap for fake, light for real
    void _triggerHaptic() {
      if (widget.result.isFake) {
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 200), () {
          HapticFeedback.heavyImpact();
        });
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

    @override
    void dispose() {
      _controller.dispose();
      super.dispose();
    }

    // ── Share handler ─────────────────────────────────────────────
    Future<void> _handleShare() async {
      setState(() => _isSharing = true);
      try {
        final Uint8List? imageBytes = await _screenshotController.capture(
          pixelRatio: 3.0,
        );
        if (imageBytes == null) return;

        final tempDir = await getTemporaryDirectory();
        final file    = await File('${tempDir.path}/truthlens_result.png')
            .writeAsBytes(imageBytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'I just scanned this image with TruthLens AI!\n'
              'Verdict: ${widget.result.verdict} '
              '(${widget.result.confidence.toStringAsFixed(1)}% confidence)\n'
              '#TruthLensAI #DeepfakeDetection',
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
      final verdictColor = widget.result.isFake
          ? AppTheme.error : AppTheme.success;
      final verdictIcon  = widget.result.isFake
          ? Icons.dangerous_rounded : Icons.verified_rounded;
      final verdictLabel = widget.result.isFake
          ? 'DEEPFAKE DETECTED' : 'AUTHENTIC IMAGE';

      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Analysis Result'),
          backgroundColor: AppTheme.surface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
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
              tooltip: 'Share Result',
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.paddingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // ── Share card (captured for sharing) ─────────────
              Screenshot(
                controller: _screenshotController,
                child: _buildShareCard(
                    verdictColor, verdictIcon, verdictLabel),
              ),

              const SizedBox(height: 16),

              // ── AI Explanation card ────────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: _buildExplanationCard(),
              ),

              const SizedBox(height: 16),

              // ── EXIF Analysis card ─────────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: _buildExifCard(),
              ),

              const SizedBox(height: 16),

              // ── Tips card ──────────────────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: _buildTipsCard(verdictColor),
              ),

              const SizedBox(height: 24),

              // ── Action buttons ─────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSharing ? null : _handleShare,
                      icon:  const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Share Result',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(AppTheme.radiusM)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon:  const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Scan Again',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
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
      );
    }

    // ── Share Card ────────────────────────────────────────────────
    /// Captured as screenshot for sharing. Shows image + verdict.
    // ================================================================
// ONLY CHANGE in result_screen.dart:
// Replace the entire _buildShareCard() method with this one.
// Everything else stays exactly the same.
// ================================================================

    // ── Share Card ────────────────────────────────────────────────
    // Captured as a screenshot and shared. Designed to look great
    // on WhatsApp, Instagram, Twitter etc.
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

            // ── Top gradient header ────────────────────────────
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

                  // App branding row
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
                          border:       Border.all(
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
                  Row(children: [
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
                  ]),

                  const SizedBox(height: 20),

                  // Big confidence number
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AnimatedBuilder(
                        animation: _progressAnim,
                        builder: (_, _) => Text(
                          '${(_progressAnim.value * 100).toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 52,
                              fontWeight: FontWeight.w900,
                              color: color, height: 1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'confidence',
                          style: TextStyle(fontSize: 14,
                              color: color.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Animated confidence bar
                  AnimatedBuilder(
                    animation: _progressAnim,
                    builder: (_, _) => ClipRRect(
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

            // ── Scanned image ──────────────────────────────────
            ClipRRect(
              child: Stack(
                children: [
                  Image.file(
                    File(widget.imagePath),
                    height: 200,
                    width:  double.infinity,
                    fit:    BoxFit.cover,
                  ),
                  // Top fade into the header
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end:   Alignment.bottomCenter,
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
                  // Bottom fade into the footer
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end:   Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            AppTheme.surface.withValues(alpha: 0.95),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Verdict stamp over image
                  Positioned(
                    bottom: 12, right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color:        color.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(icon, color: Colors.white, size: 14),
                        const SizedBox(width: 6),
                        Text(widget.result.verdict,
                            style: const TextStyle(
                                color:      Colors.white,
                                fontSize:   13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),

            // ── Footer stats row ───────────────────────────────
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
                  // Raw score
                  _buildFooterStat(
                    label: 'Raw Score',
                    value: widget.result.rawScore.toStringAsFixed(4),
                    color: color,
                  ),
                  // Divider
                  Container(width: 1, height: 28,
                      color: AppTheme.surfaceBorder),
                  // EXIF risk
                  _buildFooterStat(
                    label: 'EXIF Risk',
                    value: widget.result.exifAnalysis.riskLevel,
                    color: _getRiskColor(
                        widget.result.exifAnalysis.riskLevel),
                  ),
                  // Divider
                  Container(width: 1, height: 28,
                      color: AppTheme.surfaceBorder),
                  // Scanned with
                  _buildFooterStat(
                    label: 'Scanned with',
                    value: 'TruthLens AI',
                    color: AppTheme.primary,
                  ),
                ],
              ),
            ),

          ],
        ),
      );
    }

    // Small helper for footer stat columns
    Widget _buildFooterStat({
      required String label,
      required String value,
      required Color  color,
    }) {
      return Column(children: [
        Text(value, style: TextStyle(fontSize: 13,
            fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(
            fontSize: 10, color: AppTheme.textSecondary)),
      ]);
    }

    // ── AI Explanation Card ───────────────────────────────────────
    /// Shows the Gemini-generated human-readable explanation.
    Widget _buildExplanationCard() {
      return Container(
        width:   double.infinity,
        padding: const EdgeInsets.all(AppTheme.paddingL),
        decoration: AppTheme.cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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
                    style: TextStyle(
                        fontSize:    11,
                        fontWeight:  FontWeight.w700,
                        color:       AppTheme.textSecondary,
                        letterSpacing: 1.0)),
              ],
            ),
            const SizedBox(height: 12),
            // Explanation text from Gemini
            Text(
              widget.result.explanation,
              style: const TextStyle(
                  fontSize: 14,
                  color:    AppTheme.textPrimary,
                  height:   1.6),
            ),
          ],
        ),
      );
    }

    // ── EXIF Analysis Card ────────────────────────────────────────
    /// Shows EXIF metadata findings and risk level.
    Widget _buildExifCard() {
      final exif      = widget.result.exifAnalysis;
      final riskColor = _getRiskColor(exif.riskLevel);

      return Container(
        width:   double.infinity,
        padding: const EdgeInsets.all(AppTheme.paddingL),
        decoration: AppTheme.cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Header with risk badge ──────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color:        riskColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.data_object_rounded,
                      color: riskColor, size: 16),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('EXIF METADATA ANALYSIS',
                      style: TextStyle(
                          fontSize:    11,
                          fontWeight:  FontWeight.w700,
                          color:       AppTheme.textSecondary,
                          letterSpacing: 1.0)),
                ),
                // Risk level badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:        riskColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: riskColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '${exif.riskLevel} RISK',
                    style: TextStyle(
                        fontSize:   10,
                        fontWeight: FontWeight.w700,
                        color:      riskColor,
                        letterSpacing: 0.5),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── EXIF fields (if available) ──────────────────────
            if (exif.hasExif && exif.rawFields.isNotEmpty) ...[
              ...exif.rawFields.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(entry.key,
                          style: const TextStyle(
                              fontSize:   12,
                              color:      AppTheme.textSecondary,
                              fontWeight: FontWeight.w500)),
                    ),
                    Expanded(
                      child: Text(
                        entry.value.toString(),
                        style: const TextStyle(
                            fontSize: 12,
                            color:    AppTheme.textPrimary),
                      ),
                    ),
                  ],
                ),
              )),
              const Divider(color: AppTheme.surfaceBorder, height: 20),
            ],

            // ── Suspicion flags ─────────────────────────────────
            if (exif.suspicionFlags.isNotEmpty) ...[
              const Text('FINDINGS',
                  style: TextStyle(
                      fontSize:    10,
                      fontWeight:  FontWeight.w700,
                      color:       AppTheme.textSecondary,
                      letterSpacing: 0.8)),
              const SizedBox(height: 8),
              ...exif.suspicionFlags.map((flag) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 14, color: riskColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(flag,
                          style: TextStyle(
                              fontSize: 12,
                              color:    riskColor,
                              height:   1.4)),
                    ),
                  ],
                ),
              )),
            ],

            // ── No EXIF / unavailable message ───────────────────
            if (!exif.hasExif)
              Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: riskColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(exif.summary,
                        style: TextStyle(
                            fontSize: 12,
                            color:    riskColor,
                            height:   1.4)),
                  ),
                ],
              ),
          ],
        ),
      );
    }

    // ── Tips Card ─────────────────────────────────────────────────
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
                    style: TextStyle(
                        fontSize:    11,
                        fontWeight:  FontWeight.w700,
                        color:       AppTheme.textSecondary,
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
                          style: const TextStyle(
                              fontSize: 14,
                              color:    AppTheme.textPrimary,
                              height:   1.5)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    Color _getRiskColor(String riskLevel) {
      switch (riskLevel) {
        case 'HIGH':   return AppTheme.error;
        case 'MEDIUM': return AppTheme.accent;
        case 'LOW':    return AppTheme.success;
        default:       return AppTheme.textSecondary;
      }
    }
  }
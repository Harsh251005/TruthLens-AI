// screens/about_screen.dart
// ============================================================
// About screen — explains how TruthLens AI works,
// the technology behind it, and tips for best results.
// ============================================================

import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('About TruthLens AI'),
        backgroundColor: AppTheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // ── App identity card ──────────────────────────────
            _buildIdentityCard(),
            const SizedBox(height: 24),

            // ── How it works ───────────────────────────────────
            _buildSectionTitle('How It Works'),
            const SizedBox(height: 14),
            _buildHowItWorks(),
            const SizedBox(height: 24),

            // ── Technology ─────────────────────────────────────
            _buildSectionTitle('The Technology'),
            const SizedBox(height: 14),
            _buildTechnology(),
            const SizedBox(height: 24),

            // ── Tips for best results ──────────────────────────
            _buildSectionTitle('Tips for Best Results'),
            const SizedBox(height: 14),
            _buildTips(),
            const SizedBox(height: 24),

            // ── Limitations ────────────────────────────────────
            _buildSectionTitle('Limitations'),
            const SizedBox(height: 14),
            _buildLimitations(),
            const SizedBox(height: 24),

            // ── Version info ───────────────────────────────────
            _buildVersionCard(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── App Identity Card ─────────────────────────────────────────
  Widget _buildIdentityCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.paddingXL),
      decoration: AppTheme.glowDecoration(AppTheme.primary),
      child: Column(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.3),
                blurRadius: 24, spreadRadius: 4,
              )],
            ),
            child: const Icon(Icons.remove_red_eye_rounded,
                color: Colors.white, size: 40),
          ),
          const SizedBox(height: 16),
          RichText(
            text: const TextSpan(children: [
              TextSpan(text: 'Truth', style: TextStyle(fontSize: 28,
                  fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              TextSpan(text: 'Lens', style: TextStyle(fontSize: 28,
                  fontWeight: FontWeight.w800, color: AppTheme.primary)),
              TextSpan(text: ' AI', style: TextStyle(fontSize: 28,
                  fontWeight: FontWeight.w800, color: AppTheme.accent)),
            ]),
          ),
          const SizedBox(height: 8),
          const Text(
            'Deepfake Detection Powered by AI',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── Section Title ─────────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary));
  }

  // ── How It Works ──────────────────────────────────────────────
  Widget _buildHowItWorks() {
    final steps = [
      (Icons.upload_rounded, AppTheme.primary, '1. Upload Image',
      'Select a clear front-facing photo from your gallery or take one with your camera. Supports JPEG and PNG formats up to 10MB.'),
      (Icons.face_rounded, AppTheme.accent, '2. Face Verification',
      'Our system first verifies that the image contains a human face. Non-face images are rejected to ensure accurate analysis.'),
      (Icons.psychology_rounded, AppTheme.primary, '3. AI Analysis',
      'The image is processed by our EfficientNetB0 deep learning model, which analyses facial patterns, textures, and artifacts.'),
      (Icons.verified_rounded, AppTheme.success, '4. Verdict',
      'You receive a Real or Fake verdict with a confidence score showing how certain the AI is about its decision.'),
    ];

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        children: steps.asMap().entries.map((entry) {
          final i    = entry.key;
          final step = entry.value;
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: step.$2.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    child: Icon(step.$1, color: step.$2, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(step.$3, style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                      const SizedBox(height: 4),
                      Text(step.$4, style: const TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary,
                          height: 1.5)),
                    ],
                  )),
                ],
              ),
              if (i < steps.length - 1) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 22, top: 8, bottom: 8),
                  child: Container(width: 1, height: 20,
                      color: AppTheme.surfaceBorder),
                ),
              ],
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── Technology ────────────────────────────────────────────────
  Widget _buildTechnology() {
    final techs = [
      // AFTER:
      (Icons.memory_rounded, AppTheme.primary, 'Axiom v1.0 (EfficientNetB0)',
      'Axiom is TruthLens AI\'s proprietary detection model, fine-tuned for deepfake detection. Trained on 140K+ real and synthetic face images.'),
      (Icons.face_retouching_natural_rounded, AppTheme.accent, 'OpenCV Face Detection',
      'Haar Cascade classifier ensures only valid face images are analysed.'),
      (Icons.cloud_rounded,         AppTheme.success, 'FastAPI Backend',
      'High-performance Python backend with JWT authentication and MySQL storage.'),
      (Icons.lock_rounded,          AppTheme.primary, 'Secure & Private',
      'Your images are processed in real-time and never stored on our servers.'),
    ];

    return Column(
      children: techs.map((tech) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(AppTheme.paddingL),
        decoration: AppTheme.cardDecoration(
            borderColor: tech.$2.withValues(alpha: 0.2)),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: tech.$2.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              child: Icon(tech.$1, color: tech.$2, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tech.$3, style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text(tech.$4, style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
              ],
            )),
          ],
        ),
      )).toList(),
    );
  }

  // ── Tips ──────────────────────────────────────────────────────
  Widget _buildTips() {
    final tips = [
      'Use clear, well-lit front-facing photos',
      'Avoid heavily filtered or edited images',
      'Higher resolution images give better results',
      'Single face images work best',
      'Avoid images with extreme angles or occlusions',
    ];

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: AppTheme.cardDecoration(
          borderColor: AppTheme.success.withValues(alpha: 0.2)),
      child: Column(
        children: tips.map((tip) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle_outline,
                  color: AppTheme.success, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(tip, style: const TextStyle(
                  fontSize: 14, color: AppTheme.textPrimary, height: 1.4))),
            ],
          ),
        )).toList(),
      ),
    );
  }

  // ── Limitations ───────────────────────────────────────────────
  Widget _buildLimitations() {
    final limitations = [
      'May not detect all types of deepfakes',
      'Accuracy may vary with heavily compressed images',
      'Not a substitute for professional forensic analysis',
      'Results should be used as guidance, not absolute truth',
    ];

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: AppTheme.cardDecoration(
          borderColor: AppTheme.error.withValues(alpha: 0.2)),
      child: Column(
        children: limitations.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline,
                  color: AppTheme.error, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(item, style: const TextStyle(
                  fontSize: 14, color: AppTheme.textPrimary, height: 1.4))),
            ],
          ),
        )).toList(),
      ),
    );
  }

  // ── Version Card ──────────────────────────────────────────────
  Widget _buildVersionCard() {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        children: [
          RichText(
            text: const TextSpan(children: [
              TextSpan(text: 'Truth',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              TextSpan(text: 'Lens',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                      color: AppTheme.primary)),
              TextSpan(text: ' AI',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                      color: AppTheme.accent)),
            ]),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:        AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.2)),
            ),
            child: const Text('Powered by Axiom v1.0',
                style: TextStyle(fontSize: 12, color: AppTheme.primary,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          const Text('Version 1.0.0',
              style: TextStyle(fontSize: 13,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 2),
          const Text('Flutter  •  FastAPI  •  EfficientNetB0',
              style: TextStyle(fontSize: 12,
                  color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
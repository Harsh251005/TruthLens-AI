// screens/scan_screen.dart
// ============================================================
// Scan screen — dark themed, professional design.
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/hybrid_detection_service.dart';
import '../utils/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/scanning_overlay.dart';
import 'result_screen.dart';
import '../services/detection_service.dart';
import 'batch_scan_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  File?   _selectedImage;
  bool    _isScanning   = false;
  String? _errorMessage;

  final _imagePicker            = ImagePicker();
  final _hybridDetectionService = HybridDetectionService();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source:       source,
        imageQuality: 85,
        maxWidth:     1024,
      );
      if (picked != null) {
        setState(() {
          _selectedImage = File(picked.path);
          _errorMessage  = null;
        });
      }
    } catch (e) {
      setState(() =>
      _errorMessage = 'Failed to pick image. Please try again.');
    }
  }

  Future<void> _handleScan() async {
    if (_selectedImage == null) {
      setState(() => _errorMessage = 'Please select an image first.');
      return;
    }
    setState(() { _isScanning = true; _errorMessage = null; });

    final response =
    await _hybridDetectionService.detect(_selectedImage!);

    if (!mounted) return;
    setState(() => _isScanning = false);

    if (response.success && response.result != null) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => ResultScreen(
            result:    response.result!,
            imagePath: _selectedImage!.path,
          ),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
      // Check badge progress after successful scan
      DetectionService().checkBadgeProgress();
    } else {
      setState(() => _errorMessage = response.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Scan Image'),
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
          children: [
            const SizedBox(height: 8),
            _buildInfoBanner(),
            const SizedBox(height: 20),
            _buildImagePreview(),
            const SizedBox(height: 20),
            _buildPickButtons(),
            const SizedBox(height: 20),
            if (_errorMessage != null) ...[
              _buildErrorBanner(),
              const SizedBox(height: 16),
            ],
            PrimaryButton(
              label:     _isScanning ? 'Analysing...' : 'Analyse Image',
              onPressed: _selectedImage != null && !_isScanning
                  ? _handleScan
                  : null,
              isLoading: _isScanning,
            ),
            if (_isScanning) ...[
              const SizedBox(height: 12),
              const Text(
                'Running AI analysis, this may take a few seconds...',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingM),
      decoration: BoxDecoration(
        color:        AppTheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
      ),
      child: const Row(children: [
        Icon(Icons.tips_and_updates_outlined,
            color: AppTheme.primary, size: 18),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'For best results, upload a clear front-facing photo.',
            style: TextStyle(color: AppTheme.primary,
                fontSize: 13, height: 1.4),
          ),
        ),
      ]),
    );
  }

  Widget _buildImagePreview() {
    return GestureDetector(
      onTap: () => _pickImage(ImageSource.gallery),
      child: Container(
        width:  double.infinity,
        height: 260,
        decoration: BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(
            color: _selectedImage != null
                ? AppTheme.primary
                : AppTheme.surfaceBorder,
            width: _selectedImage != null ? 2 : 1,
          ),
        ),
        child: _selectedImage != null
            ? ClipRRect(
          borderRadius:
          BorderRadius.circular(AppTheme.radiusL - 2),
          child: Stack(children: [
            Image.file(_selectedImage!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity),
            if (_isScanning) const ScanningOverlay(),
          ]),
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color:  AppTheme.primary.withOpacity(0.1),
                shape:  BoxShape.circle,
              ),
              child: const Icon(
                  Icons.add_photo_alternate_outlined,
                  color: AppTheme.primary, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('Tap to select image',
                style: TextStyle(color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('JPEG or PNG, max 10MB',
                style: TextStyle(color: AppTheme.textSecondary,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildPickButtons() {
    return Column(
      children: [
        // ── Row 1: Gallery + Camera ────────────────────────────
        Row(children: [
          Expanded(child: _buildPickButton(
            icon:   Icons.photo_library_outlined,
            label:  'Gallery',
            source: ImageSource.gallery,
          )),
          const SizedBox(width: 12),
          Expanded(child: _buildPickButton(
            icon:   Icons.camera_alt_outlined,
            label:  'Camera',
            source: ImageSource.camera,
          )),
        ]),

        const SizedBox(height: 12),

        // ── Batch Scan button ──────────────────────────────────
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => const BatchScanScreen()),
          ),
          child: Container(
            width:   double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.accent.withOpacity(0.15),
                  AppTheme.accent.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(
                  color: AppTheme.accent.withOpacity(0.4)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_library_rounded,
                    color: AppTheme.accent, size: 20),
                SizedBox(width: 10),
                Text('Batch Scan Multiple Images',
                    style: TextStyle(color: AppTheme.accent,
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPickButton({
    required IconData   icon,
    required String     label,
    required ImageSource source,
  }) {
    return GestureDetector(
      onTap: () => _pickImage(source),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color:        AppTheme.surface2,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border:       Border.all(color: AppTheme.surfaceBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.primary, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(
                color:      AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize:   14)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(AppTheme.paddingM),
      decoration: BoxDecoration(
        color:        AppTheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(color: AppTheme.error.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(_errorMessage!,
            style: const TextStyle(
                color: AppTheme.error, fontSize: 13))),
      ]),
    );
  }
}
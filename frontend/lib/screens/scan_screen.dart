// screens/scan_screen.dart
// ============================================================
// Scan screen — redesigned with Axiom branding.
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/app_theme.dart';
import '../widgets/scanning_overlay.dart';
import 'result_screen.dart';
import '../services/detection_service.dart';
import 'batch_scan_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {

  File?   _selectedImage;
  bool    _isScanning   = false;
  String? _errorMessage;

  final _imagePicker            = ImagePicker();
  final _detectionService = DetectionService();

  // ── Scanning progress animation ───────────────────────────────
  late AnimationController _scanAnim;
  late Animation<double>   _scanProgress;

  @override
  void initState() {
    super.initState();
    _scanAnim = AnimationController(
      vsync:    this,
      duration: const Duration(seconds: 3),
    );
    _scanProgress = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(
        parent: _scanAnim, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _scanAnim.dispose();
    super.dispose();
  }

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
    _scanAnim.repeat();

    final response = await _detectionService.detectImage(_selectedImage!);

    _scanAnim.stop();
    _scanAnim.reset();

    if (!mounted) return;
    setState(() => _isScanning = false);

    if (response.success && response.result != null) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => ResultScreen(
            result:    response.result!,
            imagePath: _selectedImage!.path,
          ),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
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
        backgroundColor: AppTheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(children: [
          const Text('Scan Image',
              style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color:        AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.25)),
            ),
            child: const Text('Axiom',
                style: TextStyle(fontSize: 10,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3)),
          ),
        ]),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppTheme.paddingL, AppTheme.paddingL,
          AppTheme.paddingL,
          MediaQuery.of(context).padding.bottom + AppTheme.paddingL,
        ),
        child: Column(children: [
          _buildImagePreview(),
          const SizedBox(height: 16),
          _buildPickButtons(),
          const SizedBox(height: 16),
          if (_errorMessage != null) ...[
            _buildErrorBanner(),
            const SizedBox(height: 16),
          ],
          _buildScanButton(),
          if (_isScanning) ...[
            const SizedBox(height: 20),
            _buildScanningStatus(),
          ],
          const SizedBox(height: 16),
          _buildTipCard(),
        ]),
      ),
    );
  }


  // ── Image preview area ────────────────────────────────────────
  Widget _buildImagePreview() {
    return GestureDetector(
      onTap: _isScanning ? null : () => _pickImage(ImageSource.gallery),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width:  double.infinity,
        height: 280,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(
            color: _selectedImage != null
                ? (_isScanning
                ? AppTheme.primary
                : AppTheme.primary.withValues(alpha: 0.6))
                : AppTheme.surfaceBorder,
            width: _selectedImage != null ? 2 : 1,
          ),
          boxShadow: _selectedImage != null ? [
            BoxShadow(
              color:      AppTheme.primary.withValues(alpha: 0.08),
              blurRadius: 20, spreadRadius: 2,
            ),
          ] : null,
        ),
        child: _selectedImage != null
            ? ClipRRect(
          borderRadius:
          BorderRadius.circular(AppTheme.radiusL - 2),
          child: Stack(children: [
            Image.file(_selectedImage!,
                fit:    BoxFit.cover,
                width:  double.infinity,
                height: double.infinity),
            if (_isScanning) const ScanningOverlay(),
            // Image selected indicator
            if (!_isScanning)
              Positioned(
                top: 10, right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: AppTheme.success, size: 14),
                      SizedBox(width: 5),
                      Text('Image selected',
                          style: TextStyle(color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            // Tap to change
            if (!_isScanning)
              Positioned(
                bottom: 10, right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_horiz_rounded,
                          color: Colors.white70, size: 14),
                      SizedBox(width: 5),
                      Text('Tap to change',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ),
          ]),
        )
            : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color:  AppTheme.primary.withValues(alpha: 0.08),
                shape:  BoxShape.circle,
                border: Border.all(
                    color: AppTheme.primary.withValues(
                        alpha: 0.2)),
              ),
              child: const Icon(Icons.add_photo_alternate_outlined,
                  color: AppTheme.primary, size: 34),
            ),
            const SizedBox(height: 16),
            const Text('Select a face photo',
                style: TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 6),
            const Text('Tap here or use the buttons below',
                style: TextStyle(fontSize: 13,
                    color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBorder.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('JPEG or PNG  •  Max 10MB',
                  style: TextStyle(fontSize: 10,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.3)),
            ),
          ],
        ),
      ),
    );
  }


  // ── Pick buttons row ──────────────────────────────────────────
  Widget _buildPickButtons() {
    return Row(children: [
      Expanded(child: _buildPickButton(
        icon:   Icons.photo_library_outlined,
        label:  'Gallery',
        source: ImageSource.gallery,
      )),
      const SizedBox(width: 10),
      Expanded(child: _buildPickButton(
        icon:   Icons.camera_alt_outlined,
        label:  'Camera',
        source: ImageSource.camera,
      )),
      const SizedBox(width: 10),
      // Batch scan button
      Expanded(
        child: GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => const BatchScanScreen()),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color:        AppTheme.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(
                  color: AppTheme.accent.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.photo_library_rounded,
                    color: AppTheme.accent, size: 20),
                const SizedBox(height: 4),
                Text('Batch',
                    style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildPickButton({
    required IconData    icon,
    required String      label,
    required ImageSource source,
  }) {
    return GestureDetector(
      onTap: _isScanning ? null : () => _pickImage(source),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color:        AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(color: AppTheme.surfaceBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.primary, size: 20),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }


  // ── Scan button ───────────────────────────────────────────────
  Widget _buildScanButton() {
    final canScan = _selectedImage != null && !_isScanning;
    return SizedBox(
      width: double.infinity, height: 54,
      child: ElevatedButton(
        onPressed: canScan ? _handleScan : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canScan ? AppTheme.primary : AppTheme.surface,
          foregroundColor: canScan ? Colors.white : AppTheme.textSecondary,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusM)),
          elevation: 0,
        ),
        child: _isScanning
            ? const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white)),
            SizedBox(width: 12),
            Text('Axiom is analysing...',
                style: TextStyle(fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ],
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_rounded, size: 20),
            const SizedBox(width: 8),
            const Text('Analyse with Axiom',
                style: TextStyle(fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }


  // ── Scanning status card ──────────────────────────────────────
  Widget _buildScanningStatus() {
    final steps = [
      'Detecting face in image...',
      'Running Axiom analysis...',
      'Checking EXIF metadata...',
      'Generating AI explanation...',
    ];

    return AnimatedBuilder(
      animation: _scanProgress,
      builder: (_, _) {
        final stepIndex =
        (_scanProgress.value * steps.length).floor().clamp(
            0, steps.length - 1);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:        AppTheme.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Row(children: [
              SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(steps[stepIndex],
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                backgroundColor:
                AppTheme.primary.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.primary),
                minHeight: 4,
              ),
            ),
          ]),
        );
      },
    );
  }


  // ── Tip card at bottom ────────────────────────────────────────
  Widget _buildTipCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: const Row(children: [
        Icon(Icons.tips_and_updates_outlined,
            color: AppTheme.accent, size: 18),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Best results: clear front-facing face, good lighting, no heavy filters.',
            style: TextStyle(color: AppTheme.textSecondary,
                fontSize: 12, height: 1.5),
          ),
        ),
      ]),
    );
  }


  // ── Error banner ──────────────────────────────────────────────
  Widget _buildErrorBanner() {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(AppTheme.paddingM),
      decoration: BoxDecoration(
        color:        AppTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(
            color: AppTheme.error.withValues(alpha: 0.3)),
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
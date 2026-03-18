// screens/batch_scan_screen.dart
// ============================================================
// Batch Scan — select multiple images from gallery, scan all
// using the hybrid detection service. Shows live progress
// per image. Continues in background if user minimises app.
// Fires a notification when all scans are complete.
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/notification_service.dart';
import '../utils/app_theme.dart';
import '../services/detection_service.dart';
import '../screens/result_screen.dart';

// ── Per-image scan state ──────────────────────────────────────────
enum ImageScanState { pending, scanning, done, error }

class BatchImageItem {
  final File           file;
  ImageScanState       state;
  String?              verdict;     // 'REAL' or 'FAKE'
  double?              confidence;
  String?              errorMessage;
  DetectionResult?       result;       // ← full result stored here

  BatchImageItem({required this.file})
      : state = ImageScanState.pending;
}


class BatchScanScreen extends StatefulWidget {
  const BatchScanScreen({super.key});

  @override
  State<BatchScanScreen> createState() => _BatchScanScreenState();
}

class _BatchScanScreenState extends State<BatchScanScreen>
    with WidgetsBindingObserver {

  final _imagePicker      = ImagePicker();
  final _detectionService = DetectionService();
  final _notifService     = NotificationService();

  // ── State ─────────────────────────────────────────────────────
  List<BatchImageItem> _items        = [];
  bool                 _isScanning   = false;
  bool                 _isCancelled  = false;
  int                  _currentIndex = 0;

  // Track if app went to background mid-scan
  bool _isInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _isInBackground = true;
    } else if (state == AppLifecycleState.resumed) {
      _isInBackground = false;
    }
  }


  // ── Pick multiple images ──────────────────────────────────────
  Future<void> _pickImages() async {
    try {
      final picked = await _imagePicker.pickMultiImage(
        imageQuality: 85,
        maxWidth:     1024,
      );
      if (picked.isEmpty) return;

      final newFiles    = picked.map((x) => File(x.path)).toList();
      final existingPaths = _items.map((i) => i.file.path).toSet();

      // Only add images that aren't already in the grid
      final uniqueNew = newFiles
          .where((f) => !existingPaths.contains(f.path))
          .map((f) => BatchImageItem(file: f))
          .toList();

      setState(() => _items = [..._items, ...uniqueNew]);

    } catch (e) {
      _showSnack('Failed to pick images. Please try again.', isError: true);
    }
  }


  // ── Start scanning all images ─────────────────────────────────
  Future<void> _startScan() async {
    if (_items.isEmpty || _isScanning) return;

    setState(() {
      _isScanning   = true;
      _isCancelled  = false;
      _currentIndex = 0;
      // Reset all items to pending
      for (final item in _items) {
        item.state      = ImageScanState.pending;
        item.verdict    = null;
        item.confidence = null;
        item.errorMessage = null;
      }
    });

    HapticFeedback.mediumImpact();

    // Scan one by one
    for (int i = 0; i < _items.length; i++) {
      if (_isCancelled) break;

      setState(() {
        _currentIndex    = i;
        _items[i].state  = ImageScanState.scanning;
      });

      try {
        final response = await _detectionService.detectImage(_items[i].file);

        if (!mounted) return;
        if (_isCancelled) break;

        setState(() {
          // AFTER:
          if (response.success && response.result != null) {
            _items[i].state      = ImageScanState.done;
            _items[i].verdict    = response.result!.verdict;
            _items[i].confidence = response.result!.confidence;
            _items[i].result     = response.result;
          } else {
            _items[i].state        = ImageScanState.error;
            _items[i].errorMessage = response.message;
          }
        });

      } catch (e) {
        if (!mounted) return;
        setState(() {
          _items[i].state        = ImageScanState.error;
          _items[i].errorMessage = 'Scan failed';
        });
      }
    }

    if (!mounted) return;

    setState(() => _isScanning = false);

    // ── Fire completion notification ──────────────────────────
    if (!_isCancelled) {
      final done       = _items.where((i) => i.state == ImageScanState.done).toList();
      final realCount  = done.where((i) => i.verdict == 'REAL').length;
      final fakeCount  = done.where((i) => i.verdict == 'FAKE').length;

      // Always notify — especially useful if app was backgrounded
      await _notifService.showBatchCompleteNotification(
        total:      done.length,
        realCount:  realCount,
        fakeCount:  fakeCount,
      );

      HapticFeedback.heavyImpact();

      // If app is in foreground, also show a snack_bar
      if (!_isInBackground && mounted) {
        _showSnack(
          'Done! $realCount Authentic, $fakeCount Deepfake found.',
          isError: fakeCount > 0,
        );
      }
    }
  }


  // ── Cancel ongoing scan ───────────────────────────────────────
  void _cancelScan() {
    setState(() {
      _isCancelled = true;
      _isScanning  = false;
      // Mark remaining pending items as cancelled
      for (final item in _items) {
        if (item.state == ImageScanState.pending ||
            item.state == ImageScanState.scanning) {
          item.state = ImageScanState.pending;
        }
      }
    });
    _showSnack('Scan cancelled.', isError: false);
  }


  // ── Clear all ─────────────────────────────────────────────────
  void _clearAll() {
    if (_isScanning) _cancelScan();
    setState(() {
      _items        = [];
      _currentIndex = 0;
    });
  }


  // ── Snack helper ──────────────────────────────────────────────
  void _showSnack(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(message),
      backgroundColor: isError ? AppTheme.error : AppTheme.success,
    ));
  }


  // ── Computed stats ────────────────────────────────────────────
  int get _doneCount  =>
      _items.where((i) => i.state == ImageScanState.done).length;
  int get _realCount  =>
      _items.where((i) => i.verdict == 'REAL').length;
  int get _fakeCount  =>
      _items.where((i) => i.verdict == 'FAKE').length;
  int get _errorCount =>
      _items.where((i) => i.state == ImageScanState.error).length;


  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('Batch Scan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () {
            if (_isScanning) {
              _showCancelConfirmDialog();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          if (_items.isNotEmpty && !_isScanning)
            TextButton(
              onPressed: _clearAll,
              child: const Text('Clear',
                  style: TextStyle(color: AppTheme.error,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: Column(children: [

        // ── Progress bar ────────────────────────────────────────
        if (_isScanning) _buildProgressBar(),

        // ── Main content ────────────────────────────────────────
        Expanded(
          child: _items.isEmpty
              ? _buildEmptyState()
              : _buildImageGrid(),
        ),

        // ── Bottom action bar ───────────────────────────────────
        _buildBottomBar(),
      ]),
    );
  }


  // ── Progress bar ──────────────────────────────────────────────
  Widget _buildProgressBar() {
    final progress = _items.isEmpty
        ? 0.0
        : _doneCount / _items.length;

    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Scanning $_doneCount / ${_items.length}',
                style: const TextStyle(fontSize: 13,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600)),
            Text('${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 13,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value:           progress,
            backgroundColor: AppTheme.surfaceBorder,
            valueColor:      const AlwaysStoppedAnimation<Color>(
                AppTheme.primary),
            minHeight:       6,
          ),
        ),
      ]),
    );
  }


  // ── Empty state ───────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color:  AppTheme.primary.withValues(alpha: 0.1),
              shape:  BoxShape.circle,
            ),
            child: const Icon(Icons.photo_library_outlined,
                color: AppTheme.primary, size: 40),
          ),
          const SizedBox(height: 20),
          const Text('No images selected',
              style: TextStyle(fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text(
            'Tap "Select Images" to pick\nmultiple photos at once',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14,
                color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(
              color:        AppTheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.15)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline,
                  color: AppTheme.primary, size: 14),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You can minimise the app while scanning — '
                      'we\'ll notify you when done.',
                  style: TextStyle(fontSize: 12,
                      color: AppTheme.primary, height: 1.4),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }


  // ── Image grid ────────────────────────────────────────────────
  Widget _buildImageGrid() {
    return Column(children: [
      // Stats bar (shown after at least one scan completes)
      if (_doneCount > 0) _buildStatsBar(),

      // Grid
      Expanded(
        child: GridView.builder(
          padding: const EdgeInsets.all(AppTheme.paddingL),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:   3,
            crossAxisSpacing: 8,
            mainAxisSpacing:  8,
            childAspectRatio: 0.8,
          ),
          itemCount: _items.length,
          itemBuilder: (_, i) => _buildImageTile(_items[i], i),
        ),
      ),
    ]);
  }


  // ── Stats bar ─────────────────────────────────────────────────
  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: 10, horizontal: AppTheme.paddingL),
      color: AppTheme.surface,
      child: Row(children: [
        _buildStatChip('${_items.length}', 'Total',
            AppTheme.primary),
        const SizedBox(width: 8),
        _buildStatChip('$_realCount', 'Authentic',
            AppTheme.success),
        const SizedBox(width: 8),
        _buildStatChip('$_fakeCount', 'Deepfake',
            AppTheme.error),
        if (_errorCount > 0) ...[
          const SizedBox(width: 8),
          _buildStatChip('$_errorCount', 'Error',
              AppTheme.textSecondary),
        ],
      ]),
    );
  }

  Widget _buildStatChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border:       Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: TextStyle(fontSize: 13,
            fontWeight: FontWeight.w800, color: color)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11,
            color: color.withValues(alpha: 0.8))),
      ]),
    );
  }


  // ── Single image tile ─────────────────────────────────────────
  // ── Single image tile ─────────────────────────────────────────
  Widget _buildImageTile(BatchImageItem item, int index) {
    final isCurrentlyScan = _isScanning &&
        item.state == ImageScanState.scanning;

    Color?  borderColor;
    Widget? badge;

    switch (item.state) {
      case ImageScanState.done:
        final isFake = item.verdict == 'FAKE';
        borderColor  = isFake ? AppTheme.error : AppTheme.success;
        badge        = _buildVerdictBadge(item);
        break;
      case ImageScanState.scanning:
        borderColor = AppTheme.primary;
        break;
      case ImageScanState.error:
        borderColor = AppTheme.textSecondary;
        badge       = _buildErrorBadge();
        break;
      default:
        borderColor = AppTheme.surfaceBorder;
    }

    return GestureDetector(
      onTap: () {
        // Only open detail view if scan is done and result exists
        if (item.state == ImageScanState.done && item.result != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ResultScreen(
                result: item.result!,
                imagePath: item.file.path,
              ),
            ),
          );
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Image
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(
                color: borderColor,
                width: isCurrentlyScan ? 2 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusM - 1),
              child: Image.file(
                item.file,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),

          // Scanning spinner overlay
          if (isCurrentlyScan)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primary,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),

          // Verdict badge
          if (badge != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: badge,
            ),

          // Index number
          Positioned(
            top: 4,
            left: 4,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),

          // Tap hint info icon
          if (item.state == ImageScanState.done)
            Positioned(
              top: 4, right: 4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color:  Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white,
                  size:  10,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Verdict badge on image ────────────────────────────────────
  Widget _buildVerdictBadge(BatchImageItem item) {
    final isFake = item.verdict == 'FAKE';
    final color  = isFake ? AppTheme.error : AppTheme.success;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: const BorderRadius.only(
          bottomLeft:  Radius.circular(AppTheme.radiusM - 1),
          bottomRight: Radius.circular(AppTheme.radiusM - 1),
        ),
      ),
      child: Column(children: [
        Text(item.verdict ?? '',
            style: const TextStyle(color: Colors.white,
                fontSize: 10, fontWeight: FontWeight.w900,
                letterSpacing: 0.5)),
        Text('${item.confidence?.toStringAsFixed(0)}%',
            style: const TextStyle(color: Colors.white70,
                fontSize: 9)),
      ]),
    );
  }

  Widget _buildErrorBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: const BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(AppTheme.radiusM - 1),
          bottomRight: Radius.circular(AppTheme.radiusM - 1),
        ),
      ),
      child: const Center(
        child: Text('ERROR',
            style: TextStyle(color: Colors.white70,
                fontSize: 9, fontWeight: FontWeight.w700)),
      ),
    );
  }


  // ── Bottom action bar ─────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.surfaceBorder)),
      ),
      child: Row(children: [

        // Select images button
        if (!_isScanning) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _pickImages,
              icon:  const Icon(Icons.photo_library_outlined, size: 18),
              label: Text(_items.isEmpty
                  ? 'Select Images'
                  : 'Add More Images',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side:    const BorderSide(color: AppTheme.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape:   RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM)),
              ),
            ),
          ),

          if (_items.isNotEmpty) ...[
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _startScan,
                icon:  const Icon(Icons.document_scanner_rounded,
                    size: 18),
                label: Text('Scan All (${_items.length})',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape:   RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(AppTheme.radiusM)),
                ),
              ),
            ),
          ],
        ],

        // Cancel button (shown while scanning)
        if (_isScanning)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _cancelScan,
              icon:  const Icon(Icons.stop_rounded, size: 18),
              label: const Text('Cancel Scan',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.error,
                side:    BorderSide(
                    color: AppTheme.error.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape:   RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM)),
              ),
            ),
          ),
      ]),
    );
  }


  // ── Cancel confirmation dialog ────────────────────────────────
  Future<void> _showCancelConfirmDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusL)),
        title: const Text('Cancel Scan?',
            style: TextStyle(color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700)),
        content: const Text(
          'Scanning is in progress. Are you sure you want to leave?',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusS)),
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _cancelScan();
      Navigator.of(context).pop();
    }
  }
}
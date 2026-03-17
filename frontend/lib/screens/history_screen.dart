// screens/history_screen.dart
// ============================================================
// History screen — tap to view scan details,
// swipe to delete a single scan, clear all option.
// ============================================================

import 'package:flutter/material.dart';
import '../services/detection_service.dart';
import '../utils/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _detectionService = DetectionService();
  List<ScanHistoryItem> _scans = [];
  bool _isLoading    = true;
  bool _showSwipeHint = true; // Shown once, dismissed after first swipe

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // ── Load history asynchronously ───────────────────────────────
  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final scans = await _detectionService.getHistory();
    if (!mounted) return;
    setState(() { _scans = scans; _isLoading = false; });
  }

  // ── Delete single scan ────────────────────────────────────────
  Future<void> _deleteScan(ScanHistoryItem scan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusL)),
        title: const Text('Delete Scan',
            style: TextStyle(color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700)),
        content: Text(
          'Delete scan for "${scan.imageName}"?',
          style: const TextStyle(
              color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _detectionService.deleteScan(scan.id);
      if (!mounted) return;
      if (success) {
        setState(() => _scans.removeWhere((s) => s.id == scan.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scan deleted'),
              backgroundColor: AppTheme.success),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete scan'),
              backgroundColor: AppTheme.error),
        );
      }
    }
  }

  // ── Delete all scans ──────────────────────────────────────────
  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusL)),
        title: const Text('Clear All History',
            style: TextStyle(color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700)),
        content: const Text(
          'Are you sure you want to delete all scan history? This cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel',
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
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _detectionService.deleteHistory();
      if (!mounted) return;
      if (success) {
        setState(() => _scans = []);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scan history cleared'),
              backgroundColor: AppTheme.success),
        );
      }
    }
  }

  // ── View scan details ─────────────────────────────────────────
  void _viewDetails(ScanHistoryItem scan) {
    showModalBottomSheet(
      context:           context,
      backgroundColor:   Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ScanDetailSheet(scan: scan),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Scan History'),
        backgroundColor: AppTheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primary),
            onPressed: _loadHistory,
          ),
          if (_scans.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.error),
              tooltip: 'Clear All',
              onPressed: _confirmDeleteAll,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
          child: CircularProgressIndicator(color: AppTheme.primary))
          : _scans.isEmpty
          ? _buildEmptyState()
          : _buildList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.history_rounded,
                color: AppTheme.primary, size: 40),
          ),
          const SizedBox(height: 20),
          const Text('No scans yet', style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text(
            'Your scan history will appear here\nafter your first analysis.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14,
                color: AppTheme.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _loadHistory,
      color: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(AppTheme.paddingL),
        children: [
          // ── Swipe hint banner — shown until dismissed ─────────
          if (_showSwipeHint) _buildSwipeHint(),
          if (_showSwipeHint) const SizedBox(height: 12),

          // ── Scan cards ────────────────────────────────────────
          ...List.generate(_scans.length, (i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildSwipeableCard(_scans[i]),
          )),
        ],
      ),
    );
  }

  // ── Swipe hint banner ─────────────────────────────────────────
  Widget _buildSwipeHint() {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.paddingM, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.swipe_left_rounded,
              color: AppTheme.primary, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Swipe left on a scan to delete it',
              style: TextStyle(color: AppTheme.primary,
                  fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _showSwipeHint = false),
            child: const Icon(Icons.close_rounded,
                color: AppTheme.primary, size: 18),
          ),
        ],
      ),
    );
  }

  // ── Swipeable card — swipe left to delete ─────────────────────
  Widget _buildSwipeableCard(ScanHistoryItem scan) {
    return Dismissible(
      key: Key('scan_${scan.id}'),
      direction: DismissDirection.endToStart,
      // Red delete background revealed on swipe
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppTheme.paddingL),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_rounded, color: AppTheme.error, size: 26),
            SizedBox(height: 4),
            Text('Delete', style: TextStyle(
                color: AppTheme.error, fontSize: 12,
                fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      // Confirm before dismissing
      confirmDismiss: (_) async {
        setState(() => _showSwipeHint = false); // Hide hint after first swipe
        await _deleteScan(scan);
        return false; // We handle removal manually in _deleteScan
      },
      child: _buildCard(scan),
    );
  }

  Widget _buildCard(ScanHistoryItem scan) {
    final color = scan.isFake ? AppTheme.error : AppTheme.success;
    final icon  = scan.isFake
        ? Icons.dangerous_rounded : Icons.verified_rounded;

    return GestureDetector(
      onTap: () => _viewDetails(scan),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.paddingL),
        decoration: AppTheme.cardDecoration(
            borderColor: color.withValues(alpha: 0.2)),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(scan.imageName, style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary, fontSize: 14),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(_formatDate(scan.scannedAt), style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
              ],
            )),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(scan.verdict, style: TextStyle(
                      color: color, fontWeight: FontWeight.w700,
                      fontSize: 11, letterSpacing: 0.5)),
                ),
                const SizedBox(height: 4),
                Text('${scan.confidence.toStringAsFixed(1)}%',
                    style: const TextStyle(color: AppTheme.textSecondary,
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right,
                color: AppTheme.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date   = DateTime.parse(dateStr);
      final months = ['Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
      final hour   = date.hour > 12
          ? date.hour - 12 : date.hour == 0 ? 12 : date.hour;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';
      return '${months[date.month - 1]} ${date.day}, ${date.year}  '
          '$hour:$minute $period';
    } catch (_) { return dateStr; }
  }
}

// ── Scan Detail Bottom Sheet ──────────────────────────────────────
class _ScanDetailSheet extends StatelessWidget {
  final ScanHistoryItem scan;
  const _ScanDetailSheet({required this.scan});

  @override
  Widget build(BuildContext context) {
    final color = scan.isFake ? AppTheme.error : AppTheme.success;
    final icon  = scan.isFake
        ? Icons.dangerous_rounded : Icons.verified_rounded;
    final label = scan.isFake ? 'DEEPFAKE DETECTED' : 'AUTHENTIC IMAGE';

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.only(
          topLeft:  Radius.circular(AppTheme.radiusXL),
          topRight: Radius.circular(AppTheme.radiusXL),
        ),
      ),
      padding: const EdgeInsets.all(AppTheme.paddingL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.surfaceBorder,
                  borderRadius: BorderRadius.circular(2))),

          const SizedBox(height: 24),

          // Verdict
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.paddingL),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 16,
                      fontWeight: FontWeight.w800, color: color,
                      letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text('${scan.confidence.toStringAsFixed(1)}% confidence',
                      style: const TextStyle(fontSize: 13,
                          color: AppTheme.textSecondary)),
                ],
              )),
            ]),
          ),

          const SizedBox(height: 20),

          // Details grid
          _buildDetailRow(
              Icons.image_outlined, 'Image', scan.imageName),
          const SizedBox(height: 12),
          _buildDetailRow(
              Icons.speed_rounded, 'Confidence',
              '${scan.confidence.toStringAsFixed(2)}%'),
          const SizedBox(height: 12),
          _buildDetailRow(
              Icons.calendar_today_outlined, 'Scanned',
              _formatDate(scan.scannedAt)),

          const SizedBox(height: 24),

          // Confidence bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Confidence Score', style: TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600)),
                  Text('${scan.confidence.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 13,
                          color: color, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value:           scan.confidence / 100,
                  backgroundColor: color.withValues(alpha: 0.15),
                  valueColor:      AlwaysStoppedAnimation<Color>(color),
                  minHeight:       8,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Close button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.surface2,
                foregroundColor: AppTheme.textPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM)),
              ),
              child: const Text('Close',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
        ),
        child: Icon(icon, color: AppTheme.textSecondary, size: 18),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11,
            color: AppTheme.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 14,
            color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    ]);
  }

  String _formatDate(String dateStr) {
    try {
      final date   = DateTime.parse(dateStr);
      final months = ['Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
      final hour   = date.hour > 12
          ? date.hour - 12 : date.hour == 0 ? 12 : date.hour;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';
      return '${months[date.month - 1]} ${date.day}, ${date.year}  '
          '$hour:$minute $period';
    } catch (_) { return dateStr; }
  }
}
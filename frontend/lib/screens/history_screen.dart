// screens/history_screen.dart
// ============================================================
// History screen — redesigned with summary stats header,
// better cards, and VeriNet branding in detail sheet.
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
  List<ScanHistoryItem> _scans      = [];
  bool                  _isLoading  = true;
  String                _filterVerdict = 'ALL'; // ALL | REAL | FAKE

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final scans = await _detectionService.getHistory();
    if (!mounted) return;
    setState(() { _scans = scans; _isLoading = false; });
  }

  // ── Filtered list ─────────────────────────────────────────────
  List<ScanHistoryItem> get _filtered {
    if (_filterVerdict == 'ALL') return _scans;
    return _scans.where((s) => s.verdict == _filterVerdict).toList();
  }

  // ── Delete single ─────────────────────────────────────────────
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
        content: Text('Delete scan for "${scan.imageName}"?',
            style: const TextStyle(color: AppTheme.textSecondary,
                height: 1.5)),
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
      }
    }
  }

  // ── Delete all ────────────────────────────────────────────────
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
          'This will permanently delete all scan history.',
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
          const SnackBar(content: Text('History cleared'),
              backgroundColor: AppTheme.success),
        );
      }
    }
  }

  // ── View detail ───────────────────────────────────────────────
  void _viewDetails(ScanHistoryItem scan) {
    showModalBottomSheet(
      context:            context,
      backgroundColor:    Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ScanDetailSheet(scan: scan),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Scan History',
            style: TextStyle(fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        backgroundColor: AppTheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppTheme.primary, size: 22),
            onPressed: _loadHistory,
          ),
          if (_scans.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppTheme.error, size: 22),
              onPressed: _confirmDeleteAll,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(
          color: AppTheme.primary))
          : _scans.isEmpty
          ? _buildEmptyState()
          : _buildBody(),
    );
  }


  // ── Body with stats + filter + list ──────────────────────────
  Widget _buildBody() {
    final total = _scans.length;
    final real  = _scans.where((s) => s.verdict == 'REAL').length;
    final fake  = _scans.where((s) => s.verdict == 'FAKE').length;

    return Column(children: [

      // ── Summary stats bar ──────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        color: AppTheme.surface,
        child: Row(children: [
          _buildSummaryChip('Total', '$total',
              AppTheme.primary, true),
          const SizedBox(width: 8),
          _buildSummaryChip('Authentic', '$real',
              AppTheme.success, false),
          const SizedBox(width: 8),
          _buildSummaryChip('Deepfakes', '$fake',
              AppTheme.error, false),
          const Spacer(),
          // Accuracy badge
          if (total > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color:        AppTheme.surface2,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.surfaceBorder),
              ),
              child: Text(
                '${((real / total) * 100).toStringAsFixed(0)}% real',
                style: const TextStyle(fontSize: 11,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600),
              ),
            ),
        ]),
      ),

      // ── Filter chips ───────────────────────────────────────
      Container(
        color: AppTheme.surface,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(children: [
          _buildFilterChip('ALL'),
          const SizedBox(width: 8),
          _buildFilterChip('REAL'),
          const SizedBox(width: 8),
          _buildFilterChip('FAKE'),
        ]),
      ),

      const Divider(color: AppTheme.surfaceBorder, height: 1),

      // ── Scan list ──────────────────────────────────────────
      Expanded(
        child: RefreshIndicator(
          onRefresh: _loadHistory,
          color:           AppTheme.primary,
          backgroundColor: AppTheme.surface,
          child: _filtered.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.filter_list_rounded,
                    color: AppTheme.textSecondary.withValues(
                        alpha: 0.4), size: 48),
                const SizedBox(height: 12),
                Text('No ${_filterVerdict.toLowerCase()} scans',
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          )
              : ListView.separated(
            padding: const EdgeInsets.all(AppTheme.paddingL),
            itemCount: _filtered.length,
            separatorBuilder: (_, _) =>
            const SizedBox(height: 10),
            itemBuilder: (_, i) =>
                _buildSwipeableCard(_filtered[i]),
          ),
        ),
      ),
    ]);
  }

  Widget _buildSummaryChip(
      String label, String value, Color color, bool isTotal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(fontSize: isTotal ? 20 : 18,
                fontWeight: FontWeight.w800,
                color: color, height: 1)),
        Text(label,
            style: const TextStyle(fontSize: 10,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildFilterChip(String verdict) {
    final isSelected = _filterVerdict == verdict;
    Color chipColor;
    switch (verdict) {
      case 'REAL': chipColor = AppTheme.success; break;
      case 'FAKE': chipColor = AppTheme.error;   break;
      default:     chipColor = AppTheme.primary;
    }

    return GestureDetector(
      onTap: () => setState(() => _filterVerdict = verdict),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color:        isSelected
              ? chipColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? chipColor.withValues(alpha: 0.5)
                : AppTheme.surfaceBorder,
          ),
        ),
        child: Text(verdict,
            style: TextStyle(
                fontSize:   12,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? chipColor : AppTheme.textSecondary)),
      ),
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
              color:  AppTheme.primary.withValues(alpha: 0.08),
              shape:  BoxShape.circle,
              border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.history_rounded,
                color: AppTheme.primary, size: 38),
          ),
          const SizedBox(height: 20),
          const Text('No scans yet',
              style: TextStyle(fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text(
            'Your VeriNet scan history will\nappear here after your first analysis.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14,
                color: AppTheme.textSecondary, height: 1.6),
          ),
        ],
      ),
    );
  }


  // ── Swipeable card ────────────────────────────────────────────
  Widget _buildSwipeableCard(ScanHistoryItem scan) {
    return Dismissible(
      key:       Key('scan_${scan.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding:   const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color:        AppTheme.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(
              color: AppTheme.error.withValues(alpha: 0.3)),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_rounded, color: AppTheme.error, size: 24),
            SizedBox(height: 3),
            Text('Delete', style: TextStyle(color: AppTheme.error,
                fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        await _deleteScan(scan);
        return false;
      },
      child: _buildCard(scan),
    );
  }


  // ── Scan card ─────────────────────────────────────────────────
  Widget _buildCard(ScanHistoryItem scan) {
    final isFake = scan.verdict == 'FAKE';
    final color  = isFake ? AppTheme.error : AppTheme.success;
    final icon   = isFake
        ? Icons.dangerous_rounded : Icons.verified_rounded;

    return GestureDetector(
      onTap: () => _viewDetails(scan),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(
              color: color.withValues(alpha: 0.15)),
        ),
        child: Row(children: [

          // ── Verdict icon ──────────────────────────────────
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color:        color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),

          const SizedBox(width: 12),

          // ── Image name + date ─────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(scan.imageName,
                    style: const TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.access_time_rounded,
                      color: AppTheme.textSecondary, size: 11),
                  const SizedBox(width: 4),
                  Text(_formatDate(scan.scannedAt),
                      style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11)),
                ]),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // ── Verdict + confidence ──────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color:        color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: color.withValues(alpha: 0.25)),
                ),
                child: Text(scan.verdict,
                    style: TextStyle(color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 10, letterSpacing: 0.5)),
              ),
              const SizedBox(height: 5),
              Text('${scan.confidence.toStringAsFixed(1)}%',
                  style: TextStyle(color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ],
          ),

          const SizedBox(width: 4),
          const Icon(Icons.chevron_right,
              color: AppTheme.textSecondary, size: 18),
        ]),
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
      final min    = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';
      return '${months[date.month - 1]} ${date.day}, ${date.year}  '
          '$hour:$min $period';
    } catch (_) { return dateStr; }
  }
}


// ── Scan detail bottom sheet ──────────────────────────────────────
class _ScanDetailSheet extends StatelessWidget {
  final ScanHistoryItem scan;
  const _ScanDetailSheet({required this.scan});

  @override
  Widget build(BuildContext context) {
    final isFake = scan.isFake;
    final color  = isFake ? AppTheme.error : AppTheme.success;
    final icon   = isFake
        ? Icons.dangerous_rounded : Icons.verified_rounded;
    final label  = isFake ? 'DEEPFAKE DETECTED' : 'AUTHENTIC IMAGE';

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20, 16, 20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // ── Handle ────────────────────────────────────────
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color:        AppTheme.surfaceBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 20),

          // ── VeriNet header ─────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Scan Details',
                  style: TextStyle(fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color:        AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                child: const Text('Axiom v1.0',
                    style: TextStyle(fontSize: 10,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Verdict card ───────────────────────────────────
          Container(
            width:   double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:        color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
              border: Border.all(
                  color: color.withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color:  color.withValues(alpha: 0.12),
                  shape:  BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: color, letterSpacing: 0.3)),
                    const SizedBox(height: 2),
                    Text(
                      '${scan.confidence.toStringAsFixed(1)}% confidence',
                      style: const TextStyle(fontSize: 13,
                          color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ]),
          ),

          const SizedBox(height: 16),

          // ── Confidence bar ─────────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Confidence Score',
                      style: TextStyle(fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w600)),
                  Text('${scan.confidence.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 13,
                          color: color,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value:           scan.confidence / 100,
                  backgroundColor: color.withValues(alpha: 0.12),
                  valueColor:
                  AlwaysStoppedAnimation<Color>(color),
                  minHeight: 8,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Meta info rows ─────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color:        AppTheme.surface2,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(color: AppTheme.surfaceBorder),
            ),
            child: Column(children: [
              _buildMetaRow(Icons.image_outlined,
                  'File', scan.imageName, true),
              _buildMetaRow(Icons.calendar_today_outlined,
                  'Scanned', _formatDate(scan.scannedAt), false),
            ]),
          ),

          const SizedBox(height: 20),

          // ── Close button ───────────────────────────────────
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(AppTheme.radiusM)),
              ),
              child: const Text('Close',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(IconData icon, String label, String value,
      bool isFirst) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border: isFirst ? null : const Border(
          top: BorderSide(color: AppTheme.surfaceBorder),
        ),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color:        AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon,
              color: AppTheme.textSecondary, size: 16),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500)),
              const SizedBox(height: 1),
              SizedBox(
                width: 220,
                child: Text(value,
                    style: const TextStyle(fontSize: 13,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
      ]),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date   = DateTime.parse(dateStr);
      final months = ['Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
      final hour   = date.hour > 12
          ? date.hour - 12 : date.hour == 0 ? 12 : date.hour;
      final min    = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';
      return '${months[date.month - 1]} ${date.day}, ${date.year}  '
          '$hour:$min $period';
    } catch (_) { return dateStr; }
  }
}
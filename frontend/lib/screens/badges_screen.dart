// screens/badges_screen.dart
// ============================================================
// Badges & Streaks screen — shows earned/locked badges
// grouped by category with progress bars.
// ============================================================

import 'package:flutter/material.dart';
import '../services/detection_service.dart';
import '../utils/app_theme.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen>
    with SingleTickerProviderStateMixin {

  final _detectionService = DetectionService();
  BadgesData? _data;
  bool _isLoading = true;

  late AnimationController _animController;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(
        parent: _animController, curve: Curves.easeOut);
    _loadData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _detectionService.getBadges();
    if (!mounted) return;
    setState(() { _data = data; _isLoading = false; });
    _animController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('Badges & Streaks',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon:    const Icon(Icons.refresh, color: AppTheme.primary),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
          child: CircularProgressIndicator(color: AppTheme.primary))
          : _data == null
          ? _buildErrorState()
          : FadeTransition(
        opacity: _fadeAnim,
        child: _buildContent(),
      ),
    );
  }


  // ── Error state ───────────────────────────────────────────────
  Widget _buildErrorState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.wifi_off, color: AppTheme.textSecondary, size: 48),
        const SizedBox(height: 16),
        const Text('Could not load badges',
            style: TextStyle(color: AppTheme.textPrimary,
                fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextButton(onPressed: _loadData,
            child: const Text('Try Again',
                style: TextStyle(color: AppTheme.primary))),
      ]),
    );
  }


  // ── Main content ──────────────────────────────────────────────
  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh:       _loadData,
      color:           AppTheme.primary,
      backgroundColor: AppTheme.surface,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            _buildStreakHero(),
            const SizedBox(height: 24),
            _buildProgressSummary(),
            const SizedBox(height: 28),
            _buildSection(
              title:  'SCAN MILESTONES',
              icon:   Icons.document_scanner_rounded,
              color:  AppTheme.primary,
              badges: _data!.scanBadges,
            ),
            const SizedBox(height: 24),
            _buildSection(
              title:  'DETECTION BADGES',
              icon:   Icons.shield_rounded,
              color:  AppTheme.accent,
              badges: _data!.fakeBadges,
            ),
            const SizedBox(height: 24),
            _buildSection(
              title:  'STREAK BADGES',
              icon:   Icons.local_fire_department_rounded,
              color:  AppTheme.error,
              badges: _data!.streakBadges,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }


  // ── Streak hero card ──────────────────────────────────────────
  Widget _buildStreakHero() {
    final streak = _data!.currentStreak;
    final isOnStreak = streak > 0;

    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOnStreak
              ? [const Color(0xFF2B1500), const Color(0xFF1A0D00)]
              : [const Color(0xFF1A1A2E), const Color(0xFF0F0F1A)],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(
          color: isOnStreak
              ? AppTheme.accent.withValues(alpha: 0.4)
              : AppTheme.surfaceBorder,
        ),
        boxShadow: isOnStreak ? [
          BoxShadow(color: AppTheme.accent.withValues(alpha: 0.15),
              blurRadius: 20, spreadRadius: 2),
        ] : [],
      ),
      child: Row(children: [
        // Flame icon with glow
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color:  isOnStreak
                ? AppTheme.accent.withValues(alpha: 0.15)
                : AppTheme.surface2,
            shape:  BoxShape.circle,
            border: Border.all(
              color: isOnStreak
                  ? AppTheme.accent.withValues(alpha: 0.4)
                  : AppTheme.surfaceBorder,
            ),
            boxShadow: isOnStreak ? [
              BoxShadow(color: AppTheme.accent.withValues(alpha: 0.3),
                  blurRadius: 16, spreadRadius: 2),
            ] : [],
          ),
          child: Center(
            child: Text(
              isOnStreak ? '🔥' : '💤',
              style: const TextStyle(fontSize: 28),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isOnStreak
                    ? '$streak Day${streak == 1 ? '' : 's'} Streak!'
                    : 'No Active Streak',
                style: TextStyle(
                  fontSize:   22,
                  fontWeight: FontWeight.w900,
                  color:      isOnStreak ? AppTheme.accent : AppTheme.textSecondary,
                  height:     1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isOnStreak
                    ? 'Keep scanning daily to maintain your streak!'
                    : 'Scan today to start a new streak!',
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
              ),
              if (_data!.longestStreak > 0) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.emoji_events_outlined,
                      color: AppTheme.textSecondary, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    'Best streak: ${_data!.longestStreak} day${_data!.longestStreak == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 12,
                        color: AppTheme.textSecondary),
                  ),
                ]),
              ],
              if (isOnStreak) ...[
                const SizedBox(height: 10),
                // Mini streak progress to next badge
                _buildStreakProgress(streak),
              ],
            ],
          ),
        ),
      ]),
    );
  }

  // Shows progress to next streak badge
  Widget _buildStreakProgress(int streak) {
    final targets  = [3, 7, 14, 30];
    final next     = targets.firstWhere((t) => t > streak, orElse: () => 30);
    final prev     = targets.lastWhere((t) => t <= streak, orElse: () => 0);
    final progress = prev == next
        ? 1.0
        : (streak - prev) / (next - prev);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Next badge at $next days',
            style: const TextStyle(fontSize: 11,
                color: AppTheme.textSecondary)),
        Text('$streak / $next',
            style: const TextStyle(fontSize: 11,
                color: AppTheme.accent, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value:           progress,
          backgroundColor: AppTheme.accent.withValues(alpha: 0.12),
          valueColor:      const AlwaysStoppedAnimation<Color>(AppTheme.accent),
          minHeight:       5,
        ),
      ),
    ]);
  }


  // ── Progress summary ──────────────────────────────────────────
  Widget _buildProgressSummary() {
    final earned = _data!.earnedCount;
    final total  = _data!.totalCount;
    final pct    = total > 0 ? earned / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: BoxDecoration(
        color:        AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border:       Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('OVERALL PROGRESS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary, letterSpacing: 1.0)),
            RichText(text: TextSpan(children: [
              TextSpan(text: '$earned',
                  style: const TextStyle(fontSize: 18,
                      fontWeight: FontWeight.w900, color: AppTheme.primary)),
              TextSpan(text: ' / $total badges',
                  style: const TextStyle(fontSize: 13,
                      color: AppTheme.textSecondary)),
            ])),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value:           pct,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
            valueColor:      const AlwaysStoppedAnimation<Color>(AppTheme.primary),
            minHeight:       10,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          earned == total
              ? '🎉 All badges earned! You\'re a legend!'
              : '${(pct * 100).toStringAsFixed(0)}% complete — keep going!',
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ]),
    );
  }


  // ── Badge section ─────────────────────────────────────────────
  Widget _buildSection({
    required String         title,
    required IconData       icon,
    required Color          color,
    required List<BadgeItem> badges,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 11,
              fontWeight: FontWeight.w700, color: color,
              letterSpacing: 1.0)),
          const SizedBox(width: 8),
          Text(
            '(${badges.where((b) => b.earned).length}/${badges.length})',
            style: const TextStyle(fontSize: 11,
                color: AppTheme.textSecondary),
          ),
        ]),
        const SizedBox(height: 12),
        // Badge cards
        ...badges.map((badge) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child:   _buildBadgeCard(badge),
        )),
      ],
    );
  }


  // ── Single badge card ─────────────────────────────────────────
  Widget _buildBadgeCard(BadgeItem badge) {
    final color = badge.earned ? _categoryColor(badge.category) : AppTheme.textSecondary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding:  const EdgeInsets.all(AppTheme.paddingL),
      decoration: BoxDecoration(
        color: badge.earned
            ? color.withValues(alpha: 0.06)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: badge.earned
              ? color.withValues(alpha: 0.3)
              : AppTheme.surfaceBorder,
        ),
      ),
      child: Row(children: [
        // Emoji in a circle
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color:  badge.earned
                ? color.withValues(alpha: 0.12)
                : AppTheme.surface2,
            shape:  BoxShape.circle,
            border: Border.all(
              color: badge.earned
                  ? color.withValues(alpha: 0.3)
                  : AppTheme.surfaceBorder,
            ),
          ),
          child: Center(
            child: badge.earned
                ? Text(badge.emoji,
                style: const TextStyle(fontSize: 26))
                : const Icon(Icons.lock_outline,
                color: AppTheme.textSecondary, size: 22),
          ),
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name + earned checkmark
              Row(children: [
                Text(badge.name, style: TextStyle(
                    fontSize:   15,
                    fontWeight: FontWeight.w700,
                    color:      badge.earned
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary)),
                if (badge.earned) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.check_circle_rounded,
                      color: color, size: 16),
                ],
              ]),

              const SizedBox(height: 3),

              // Description
              Text(badge.description, style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary, height: 1.3)),

              const SizedBox(height: 8),

              // Progress bar + count
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value:           badge.progressFraction,
                      backgroundColor: color.withValues(alpha: 0.4),
                      valueColor:      AlwaysStoppedAnimation<Color>(
                          badge.earned ? color : AppTheme.textSecondary.withValues(alpha: 0.3)),
                      minHeight:       5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  badge.earned
                      ? 'Earned!'
                      : '${badge.progress} / ${badge.target}',
                  style: TextStyle(
                      fontSize:   11,
                      color:      badge.earned ? color : AppTheme.textSecondary,
                      fontWeight: FontWeight.w600),
                ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }


  // ── Category → colour mapping ─────────────────────────────────
  Color _categoryColor(String category) {
    switch (category) {
      case 'scans':  return AppTheme.primary;
      case 'fakes':  return AppTheme.error;
      case 'real':   return AppTheme.success;
      case 'streak': return AppTheme.accent;
      default:       return AppTheme.primary;
    }
  }
}
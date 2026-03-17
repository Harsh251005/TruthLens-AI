// screens/leaderboard_screen.dart
// ============================================================
// Community Leaderboard — shows top 20 players by best score
// with All Time / This Week tabs, user's own rank highlighted,
// and personal best card.
// ============================================================

import 'package:flutter/material.dart';
import '../services/detection_service.dart';
import '../utils/app_theme.dart';
import '../widgets/avatar_widget.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {

  final _detectionService = DetectionService();
  late TabController _tabController;

  LeaderboardData? _allTimeData;
  LeaderboardData? _weeklyData;
  bool _isLoadingAllTime = true;
  bool _isLoadingWeekly  = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // Load weekly data lazily on first tab switch
      if (_tabController.index == 1 && _weeklyData == null) {
        _loadWeekly();
      }
    });
    _loadAllTime();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllTime() async {
    setState(() => _isLoadingAllTime = true);
    final data = await _detectionService.getLeaderboard(period: 'all_time');
    if (!mounted) return;
    setState(() { _allTimeData = data; _isLoadingAllTime = false; });
  }

  Future<void> _loadWeekly() async {
    setState(() => _isLoadingWeekly = true);
    final data = await _detectionService.getLeaderboard(period: 'weekly');
    if (!mounted) return;
    setState(() { _weeklyData = data; _isLoadingWeekly = false; });
  }

  Future<void> _refresh() async {
    if (_tabController.index == 0) {
      await _loadAllTime();
    } else {
      await _loadWeekly();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('Leaderboard',
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
            onPressed: _refresh,
          ),
        ],
        bottom: TabBar(
          controller:           _tabController,
          indicatorColor:       AppTheme.primary,
          indicatorWeight:      2,
          labelColor:           AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'All Time'),
            Tab(text: 'This Week'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTab(_allTimeData, _isLoadingAllTime, _loadAllTime),
          _buildTab(_weeklyData,  _isLoadingWeekly,  _loadWeekly),
        ],
      ),
    );
  }


  // ── Tab content ───────────────────────────────────────────────
  Widget _buildTab(
      LeaderboardData? data,
      bool             isLoading,
      VoidCallback     onRefresh,
      ) {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (data == null) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off,
              color: AppTheme.textSecondary, size: 48),
          const SizedBox(height: 16),
          const Text('Could not load leaderboard',
              style: TextStyle(color: AppTheme.textPrimary,
                  fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextButton(onPressed: onRefresh,
              child: const Text('Try Again',
                  style: TextStyle(color: AppTheme.primary))),
        ],
      ));
    }

    return RefreshIndicator(
      onRefresh:       () async => onRefresh(),
      color:           AppTheme.primary,
      backgroundColor: AppTheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(AppTheme.paddingL),
        children: [
          const SizedBox(height: 4),

          // ── Personal best card ──────────────────────────
          if (data.personalBest != null) ...[
            _buildPersonalBestCard(data),
            const SizedBox(height: 16),
          ],

          // ── User rank banner ────────────────────────────
          if (data.userRank != null) ...[
            _buildRankBanner(data),
            const SizedBox(height: 16),
          ],

          // ── Top 3 podium ────────────────────────────────
          if (data.entries.length >= 3) ...[
            _buildPodium(data.entries),
            const SizedBox(height: 20),
          ],

          // ── Section label ───────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('RANKINGS',
                  style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                      letterSpacing: 1.0)),
              Text('${data.totalPlayers} players',
                  style: const TextStyle(fontSize: 12,
                      color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),

          // ── Full list (skip top 3 shown in podium) ──────
          ...data.entries.map((entry) =>
              _buildEntryRow(entry)),

          // ── Empty state ─────────────────────────────────
          if (data.entries.isEmpty)
            _buildEmptyState(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }


  // ── Personal best card ────────────────────────────────────────
  Widget _buildPersonalBestCard(LeaderboardData data) {
    final pb    = data.personalBest!;
    final grade = pb.grade;
    final color = _gradeColor(grade);

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.15),
            AppTheme.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        // Grade circle
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            shape:  BoxShape.circle,
            color:  color.withValues(alpha: 0.15),
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Text(grade, style: TextStyle(fontSize: 22,
                fontWeight: FontWeight.w900, color: color)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('YOUR PERSONAL BEST',
                  style: TextStyle(fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.8)),
              const SizedBox(height: 4),
              Row(children: [
                Text('${pb.score}/${pb.total}',
                    style: const TextStyle(fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary)),
                const SizedBox(width: 10),
                Text('${pb.accuracy.toStringAsFixed(0)}% accuracy',
                    style: const TextStyle(fontSize: 13,
                        color: AppTheme.textSecondary)),
              ]),
              const SizedBox(height: 2),
              Text('Max combo: ${pb.maxCombo} 🔥',
                  style: const TextStyle(fontSize: 12,
                      color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ]),
    );
  }


  // ── Rank banner ───────────────────────────────────────────────
  Widget _buildRankBanner(LeaderboardData data) {
    final rank = data.userRank!;
    final color = rank <= 3
        ? const Color(0xFFFFD700)
        : rank <= 10
        ? AppTheme.primary
        : AppTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: 12, horizontal: AppTheme.paddingL),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border:       Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(Icons.emoji_events_rounded, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            rank <= 3
                ? 'You\'re in the top 3! 🎉'
                : rank <= 10
                ? 'You\'re in the top 10! Keep going!'
                : 'You\'re ranked #$rank globally',
            style: TextStyle(color: color,
                fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color:        color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('#$rank',
              style: TextStyle(color: color,
                  fontSize: 14, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }


  // ── Top 3 podium ──────────────────────────────────────────────
  Widget _buildPodium(List<LeaderboardEntry> entries) {
    final first  = entries[0];
    final second = entries.length > 1 ? entries[1] : null;
    final third  = entries.length > 2 ? entries[2] : null;

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2744), Color(0xFF0F1629)],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd place
          if (second != null)
            _buildPodiumItem(second, 2,
                const Color(0xFFC0C0C0), 70),
          // 1st place (taller)
          _buildPodiumItem(first, 1,
              const Color(0xFFFFD700), 90),
          // 3rd place
          if (third != null)
            _buildPodiumItem(third, 3,
                const Color(0xFFCD7F32), 55),
        ],
      ),
    );
  }

  Widget _buildPodiumItem(
      LeaderboardEntry entry, int rank, Color color, double height) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar
        AvatarWidget(
          avatarType: entry.avatarType,
          avatarData: entry.avatarData,
          name:       entry.name,
          size:       rank == 1 ? 52 : 42,
          showRing:   false,
        ),
        const SizedBox(height: 6),
        // Name
        SizedBox(
          width: 80,
          child: Text(
            entry.name.split(' ')[0],  // First name only
            textAlign: TextAlign.center,
            maxLines:  1,
            overflow:  TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12,
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600),
          ),
        ),
        // Score
        Text('${entry.score}/${entry.total}',
            style: TextStyle(fontSize: 11,
                color: color, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        // Podium block
        Container(
          width:  70,
          height: height,
          decoration: BoxDecoration(
            color:        color.withValues(alpha: 0.15),
            borderRadius: const BorderRadius.only(
              topLeft:  Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Center(
            child: Text(
              rank == 1 ? '👑' : rank == 2 ? '🥈' : '🥉',
              style: const TextStyle(fontSize: 22),
            ),
          ),
        ),
      ],
    );
  }


  // ── Entry row ─────────────────────────────────────────────────
  Widget _buildEntryRow(LeaderboardEntry entry) {
    final isTopThree = entry.rank <= 3;
    final rankColor  = entry.rank == 1
        ? const Color(0xFFFFD700)
        : entry.rank == 2
        ? const Color(0xFFC0C0C0)
        : entry.rank == 3
        ? const Color(0xFFCD7F32)
        : AppTheme.textSecondary;

    return Container(
      margin:  const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.paddingL, vertical: 12),
      decoration: BoxDecoration(
        color: isTopThree
            ? rankColor.withValues(alpha: 0.05)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: isTopThree
              ? rankColor.withValues(alpha: 0.2)
              : AppTheme.surfaceBorder,
        ),
      ),
      child: Row(children: [
        // Rank
        SizedBox(
          width: 32,
          child: Text('#${entry.rank}',
              style: TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: rankColor)),
        ),

        // Avatar
        AvatarWidget(
          avatarType: entry.avatarType,
          avatarData: entry.avatarData,
          name:       entry.name,
          size:       36,
          showRing:   false,
        ),
        const SizedBox(width: 12),

        // Name + grade
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              Text('Combo: ${entry.maxCombo} 🔥',
                  style: const TextStyle(fontSize: 11,
                      color: AppTheme.textSecondary)),
            ],
          ),
        ),

        // Score + grade
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${entry.score}/${entry.total}',
                style: TextStyle(fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _gradeColor(entry.grade))),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _gradeColor(entry.grade).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(entry.grade,
                  style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _gradeColor(entry.grade))),
            ),
          ],
        ),
      ]),
    );
  }


  // ── Empty state ───────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(children: [
          const Icon(Icons.leaderboard_outlined,
              color: AppTheme.textSecondary, size: 48),
          const SizedBox(height: 16),
          const Text('No scores yet',
              style: TextStyle(fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text('Be the first to play Challenge Mode!',
              style: TextStyle(fontSize: 13,
                  color: AppTheme.textSecondary)),
        ]),
      ),
    );
  }


  // ── Grade → colour ────────────────────────────────────────────
  Color _gradeColor(String grade) {
    switch (grade) {
      case 'S':  return const Color(0xFFFFD700);
      case 'A':  return AppTheme.success;
      case 'B':  return AppTheme.primary;
      case 'C':  return AppTheme.accent;
      default:   return AppTheme.error;
    }
  }
}
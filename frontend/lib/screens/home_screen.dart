// screens/home_screen.dart
// ============================================================
// Home/Dashboard — redesigned for professional look.
// VeriNet branding added to scan card.
// ============================================================

import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/detection_service.dart';
import '../utils/app_theme.dart';
import 'profile_screen.dart';
import 'scan_screen.dart';
import 'history_screen.dart';
import 'about_screen.dart';
import '../services/storage_service.dart';
import 'analytics_screen.dart';
import 'challenge_screen.dart';
import 'awareness_screen.dart';
import 'leaderboard_screen.dart';
import 'deepfake_news_screen.dart';
import 'batch_scan_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserModel user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {

  final _detectionService = DetectionService();
  ScanStats? _stats;
  bool       _isLoadingStats = true;
  late String _displayName;

  // ── Subtle pulse animation for the scan button ────────────────
  late AnimationController _pulseController;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _displayName = widget.user.name;
    _loadStats();

    _pulseController = AnimationController(
      vsync:    this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final stats = await _detectionService.getStats();
    if (!mounted) return;
    setState(() { _stats = stats; _isLoadingStats = false; });
  }

  Future<void> _refreshUser() async {
    final savedUser = await StorageService.getSavedUser();
    if (!mounted || savedUser == null) return;
    setState(() => _displayName = savedUser.name);
  }

  // ── Time-based greeting ───────────────────────────────────────
  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: NestedScrollView(
        headerSliverBuilder: (_, _) => [_buildSliverAppBar()],
        body: RefreshIndicator(
          onRefresh: _loadStats,
          color:           AppTheme.primary,
          backgroundColor: AppTheme.surface,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              AppTheme.paddingL, AppTheme.paddingL,
              AppTheme.paddingL,
              MediaQuery.of(context).padding.bottom + AppTheme.paddingL,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeBanner(),
                const SizedBox(height: 24),
                _buildStatsSection(),
                const SizedBox(height: 24),
                _buildScanCard(context),
                const SizedBox(height: 24),
                _buildQuickActionsSection(context),
                const SizedBox(height: 24),
                _buildHowItWorks(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }


  // ── Sliver app bar ────────────────────────────────────────────
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned:          true,
      floating:        true,
      backgroundColor: AppTheme.surface,
      automaticallyImplyLeading: false,
      title: RichText(
        text: const TextSpan(children: [
          TextSpan(text: 'Truth',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary)),
          TextSpan(text: 'Lens',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                  color: AppTheme.primary)),
          TextSpan(text: ' AI',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                  color: AppTheme.accent)),
        ]),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline,
              color: AppTheme.textSecondary, size: 22),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AboutScreen()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: IconButton(
            icon: const Icon(Icons.person_outline,
                color: AppTheme.primary, size: 22),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
              if (mounted) _refreshUser();
            },
          ),
        ),
      ],
    );
  }


  // ── Welcome banner ────────────────────────────────────────────
  Widget _buildWelcomeBanner() {
    final firstName = _displayName.split(' ').first;
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2744), Color(0xFF0F1629)],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$_greeting,',
                  style: const TextStyle(fontSize: 13,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(firstName,
                  style: const TextStyle(fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.3)),
              const SizedBox(height: 6),
              Row(children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color:  AppTheme.success,
                    shape:  BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: AppTheme.success.withValues(alpha: 0.6),
                          blurRadius: 4, spreadRadius: 1),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Text('VeriNet v1.0 is ready',
                    style: TextStyle(fontSize: 12,
                        color: AppTheme.textSecondary)),
              ]),
            ],
          ),
        ),
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            shape:    BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color:      AppTheme.primary.withValues(alpha: 0.3),
                blurRadius: 16, spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.shield_outlined,
              color: Colors.white, size: 26),
        ),
      ]),
    );
  }


  // ── Stats section ─────────────────────────────────────────────
  Widget _buildStatsSection() {
    final total = _stats?.totalScans ?? 0;
    final real  = _stats?.totalReal  ?? 0;
    final fake  = _stats?.totalFake  ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Your Activity',
                style: TextStyle(fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const AnalyticsScreen()),
              ),
              child: Row(children: [
                const Text('View analytics',
                    style: TextStyle(fontSize: 12,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: AppTheme.primary, size: 11),
              ]),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // ── Big total card ─────────────────────────────────────
        Container(
          width:   double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A2744), Color(0xFF0F1A35)],
              begin:  Alignment.topLeft,
              end:    Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
            border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color:      AppTheme.primary.withValues(alpha: 0.08),
                blurRadius: 20, spreadRadius: 2,
              ),
            ],
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TOTAL SCANS',
                      style: TextStyle(fontSize: 11,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0)),
                  const SizedBox(height: 8),
                  _isLoadingStats
                      ? const SizedBox(width: 28, height: 28,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primary))
                      : Text('$total',
                      style: const TextStyle(fontSize: 52,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary,
                          height: 1,
                          letterSpacing: -2)),
                  const SizedBox(height: 4),
                  Text(
                    total == 0
                        ? 'No scans yet — start below!'
                        : 'image${total == 1 ? '' : 's'} analysed by VeriNet',
                    style: const TextStyle(fontSize: 13,
                        color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color:  AppTheme.primary.withValues(alpha: 0.12),
                shape:  BoxShape.circle,
                border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.25)),
              ),
              child: const Icon(Icons.document_scanner_rounded,
                  color: AppTheme.primary, size: 30),
            ),
          ]),
        ),

        const SizedBox(height: 10),

        // ── Real vs Fake mini cards ────────────────────────────
        Row(children: [
          Expanded(child: _buildMiniStatCard(
            label:    'Authentic',
            value:    '$real',
            subtitle: total > 0
                ? '${((real / total) * 100).toStringAsFixed(0)}% of scans'
                : '—',
            icon:     Icons.verified_rounded,
            color:    AppTheme.success,
            bgColor:  const Color(0xFF0D2B1F),
          )),
          const SizedBox(width: 10),
          Expanded(child: _buildMiniStatCard(
            label:    'Deepfakes',
            value:    '$fake',
            subtitle: total > 0
                ? '${((fake / total) * 100).toStringAsFixed(0)}% of scans'
                : '—',
            icon:     Icons.dangerous_rounded,
            color:    AppTheme.error,
            bgColor:  const Color(0xFF2B0D0D),
          )),
        ]),
      ],
    );
  }

  Widget _buildMiniStatCard({
    required String   label,
    required String   value,
    required String   subtitle,
    required IconData icon,
    required Color    color,
    required Color    bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label.toUpperCase(),
                  style: TextStyle(fontSize: 10,
                      color: color.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
              Icon(icon, color: color, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          _isLoadingStats
              ? SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: color))
              : Text(value,
              style: TextStyle(fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: color, height: 1,
                  letterSpacing: -1)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(fontSize: 11,
                  color: AppTheme.textSecondary)),
        ],
      ),
    );
  }


  // ── Scan card with VeriNet branding ───────────────────────────
  Widget _buildScanCard(BuildContext context) {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F1E3D), Color(0xFF0A1628)],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color:      AppTheme.primary.withValues(alpha: 0.12),
            blurRadius: 32, spreadRadius: 4,
          ),
        ],
      ),
      child: Column(children: [

        // ── VeriNet badge ─────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color:        AppTheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                color: AppTheme.success,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: AppTheme.success.withValues(alpha: 0.6),
                      blurRadius: 4),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Text('Powered by VeriNet v1.0',
                style: TextStyle(fontSize: 11,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3)),
          ]),
        ),

        const SizedBox(height: 20),

        // ── Animated scanner icon ─────────────────────────────
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, child) => Transform.scale(
            scale: _pulseAnim.value,
            child: child,
          ),
          child: Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape:    BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:      AppTheme.primary.withValues(alpha: 0.4),
                  blurRadius: 28, spreadRadius: 6,
                ),
              ],
            ),
            child: const Icon(Icons.document_scanner_rounded,
                color: Colors.white, size: 38),
          ),
        ),

        const SizedBox(height: 20),

        const Text('Deepfake Detector',
            style: TextStyle(fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3)),

        const SizedBox(height: 8),

        const Text(
          'Upload any face photo and VeriNet will\ninstantly detect if it\'s real or AI-generated.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13,
              color: AppTheme.textSecondary, height: 1.6),
        ),

        const SizedBox(height: 24),

        // ── Primary scan button ────────────────────────────────
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton.icon(
            onPressed: () async {
              await Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (_, _, _) => const ScanScreen(),
                  transitionsBuilder: (_, animation, _, child) =>
                      SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(1, 0), end: Offset.zero,
                        ).animate(CurvedAnimation(
                            parent: animation, curve: Curves.easeOut)),
                        child: child,
                      ),
                  transitionDuration: const Duration(milliseconds: 300),
                ),
              );
              _loadStats();
            },
            icon:  const Icon(Icons.search_rounded, size: 20),
            label: const Text('Start Scanning',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(AppTheme.radiusM)),
              elevation: 0,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ── Batch scan secondary button ────────────────────────
        SizedBox(
          width: double.infinity, height: 44,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const BatchScanScreen()),
            ),
            icon:  const Icon(Icons.photo_library_rounded, size: 18),
            label: const Text('Batch Scan',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accent,
              side: BorderSide(
                  color: AppTheme.accent.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(AppTheme.radiusM)),
            ),
          ),
        ),
      ]),
    );
  }


  // ── Quick actions ─────────────────────────────────────────────
  Widget _buildQuickActionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Explore',
            style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 14),

        // Row 1
        Row(children: [
          Expanded(child: _buildActionTile(
            icon:     Icons.history_rounded,
            label:    'Scan History',
            subtitle: 'Past results',
            color:    AppTheme.accent,
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const HistoryScreen())),
          )),
          const SizedBox(width: 12),
          Expanded(child: _buildActionTile(
            icon:     Icons.bar_chart_rounded,
            label:    'Analytics',
            subtitle: 'Your insights',
            color:    AppTheme.primary,
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const AnalyticsScreen())),
          )),
        ]),

        const SizedBox(height: 12),

        // Row 2
        Row(children: [
          Expanded(child: _buildActionTile(
            icon:     Icons.psychology_rounded,
            label:    'Challenge',
            subtitle: 'Spot the fake!',
            color:    AppTheme.error,
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const ChallengeScreen())),
          )),
          const SizedBox(width: 12),
          Expanded(child: _buildActionTile(
            icon:     Icons.leaderboard_rounded,
            label:    'Leaderboard',
            subtitle: 'Top players',
            color:    const Color(0xFFFFD700),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const LeaderboardScreen())),
          )),
        ]),

        const SizedBox(height: 12),

        // Row 3
        Row(children: [
          Expanded(child: _buildActionTile(
            icon:     Icons.school_rounded,
            label:    'Awareness Hub',
            subtitle: 'Learn about deepfakes',
            color:    const Color(0xFF26A69A),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const AwarenessScreen())),
          )),
          const SizedBox(width: 12),
          Expanded(child: _buildActionTile(
            icon:     Icons.newspaper_rounded,
            label:    'News Tracker',
            subtitle: 'Latest deepfake news',
            color:    const Color(0xFF1565C0),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const DeepfakeNewsScreen())),
          )),
        ]),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData     icon,
    required String       label,
    required String       subtitle,
    required Color        color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(
              color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color:        color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(label,
                style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(fontSize: 11,
                    color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }


  // ── How it works ──────────────────────────────────────────────
  Widget _buildHowItWorks() {
    final steps = [
      (Icons.upload_rounded,     AppTheme.primary, '01',
      'Upload', 'Select a clear front-facing photo'),
      (Icons.memory_rounded,     AppTheme.accent,  '02',
      'VeriNet Analyses', 'AI scans for deepfake artifacts'),
      (Icons.verified_rounded,   AppTheme.success, '03',
      'Get Verdict', 'Confidence score + full breakdown'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('How It Works',
            style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color:        AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
            border: Border.all(color: AppTheme.surfaceBorder),
          ),
          child: Column(
            children: steps.asMap().entries.map((entry) {
              final i    = entry.key;
              final step = entry.value;
              return Column(children: [
                Row(children: [
                  // Step number circle
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: step.$2.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: step.$2.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(step.$1, color: step.$2, size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(step.$3,
                              style: TextStyle(fontSize: 10,
                                  color: step.$2,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5)),
                          const SizedBox(width: 8),
                          Text(step.$4,
                              style: const TextStyle(fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary)),
                        ]),
                        const SizedBox(height: 2),
                        Text(step.$5,
                            style: const TextStyle(fontSize: 12,
                                color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                ]),
                if (i < steps.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 21, top: 10, bottom: 10),
                    child: Row(children: [
                      Container(width: 2, height: 24,
                          color: AppTheme.surfaceBorder),
                    ]),
                  ),
              ]);
            }).toList(),
          ),
        ),
      ],
    );
  }
}
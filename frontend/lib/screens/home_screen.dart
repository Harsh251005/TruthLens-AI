// screens/home_screen.dart
// ============================================================
// Home/Dashboard — shows scan stats, scan button, quick actions.
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

class HomeScreen extends StatefulWidget {
  final UserModel user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _detectionService = DetectionService();
  ScanStats? _stats;
  bool _isLoadingStats = true;
  late String _displayName;

  @override
  void initState() {
    super.initState();
    _displayName = widget.user.name;
    _loadStats();
  }

  // ── Load stats asynchronously ─────────────────────────────────
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: RichText(
          text: const TextSpan(children: [
            TextSpan(text: 'Truth', style: TextStyle(fontSize: 20,
                fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            TextSpan(text: 'Lens', style: TextStyle(fontSize: 20,
                fontWeight: FontWeight.w800, color: AppTheme.primary)),
            TextSpan(text: ' AI', style: TextStyle(fontSize: 20,
                fontWeight: FontWeight.w800, color: AppTheme.accent)),
          ]),
        ),
        backgroundColor: AppTheme.surface,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: AppTheme.textSecondary),
            tooltip: 'About',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
          // In appBar actions:
          IconButton(
            icon: const Icon(Icons.person_outline, color: AppTheme.primary),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
              // Reload user data when returning from profile
              if (mounted) _refreshUser();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        color: AppTheme.primary,
        backgroundColor: AppTheme.surface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppTheme.paddingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              _buildWelcomeBanner(),
              const SizedBox(height: 20),
              _buildStatsRow(),
              const SizedBox(height: 24),
              _buildScanCard(context),
              const SizedBox(height: 24),
              _buildQuickActions(context),
              const SizedBox(height: 24),
              _buildHowItWorks(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Welcome Banner ─────────────────────────────────────────────
  Widget _buildWelcomeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2744), Color(0xFF0F1629)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hello, $_displayName 👋',
                    style: const TextStyle(fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                const Text('Ready to detect deepfakes?',
                    style: TextStyle(fontSize: 13,
                        color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
            ),
            child: const Icon(Icons.shield_outlined,
                color: AppTheme.primary, size: 24),
          ),
        ],
      ),
    );
  }

  // ── Stats Section ──────────────────────────────────────────────
  Widget _buildStatsRow() {
    final total = _stats?.totalScans ?? 0;
    final real  = _stats?.totalReal  ?? 0;
    final fake  = _stats?.totalFake  ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Your Activity',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 14),

        // ── Big total scans card ──────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppTheme.paddingL),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A2744), Color(0xFF0F1A35)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
            border: Border.all(color: AppTheme.primary.withOpacity(0.25)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.1),
                blurRadius: 20, spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Scans',
                        style: TextStyle(fontSize: 13,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    _isLoadingStats
                        ? const SizedBox(width: 24, height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.primary))
                        : Text('$total',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary,
                          height: 1,
                        )),
                    const SizedBox(height: 6),
                    const Text('images analysed',
                        style: TextStyle(fontSize: 13,
                            color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppTheme.primary.withOpacity(0.3)),
                ),
                child: const Icon(Icons.document_scanner_rounded,
                    color: AppTheme.primary, size: 30),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── Real vs Fake row ──────────────────────────────────
        Row(
          children: [
            Expanded(child: _buildMiniStatCard(
              label:    'Authentic',
              value:    '$real',
              subtitle: total > 0
                  ? '${((real / total) * 100).toStringAsFixed(0)}% of total'
                  : '0% of total',
              icon:  Icons.verified_rounded,
              color: AppTheme.success,
              gradient: const LinearGradient(
                colors: [Color(0xFF0D2B1F), Color(0xFF0A1F16)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildMiniStatCard(
              label:    'Deepfakes',
              value:    '$fake',
              subtitle: total > 0
                  ? '${((fake / total) * 100).toStringAsFixed(0)}% of total'
                  : '0% of total',
              icon:  Icons.dangerous_rounded,
              color: AppTheme.error,
              gradient: const LinearGradient(
                colors: [Color(0xFF2B0D0D), Color(0xFF1F0A0A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniStatCard({
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required LinearGradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(color: color.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 16, spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(
                  fontSize: 13, color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w600, letterSpacing: 0.3)),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 10),
          _isLoadingStats
              ? SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: color))
              : Text(value, style: TextStyle(
              fontSize: 36, fontWeight: FontWeight.w900,
              color: color, height: 1)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(
              fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  // ── Scan Card ──────────────────────────────────────────────────
  Widget _buildScanCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.paddingXL),
      decoration: AppTheme.glowDecoration(AppTheme.primary),
      child: Column(
        children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                color: AppTheme.primary.withOpacity(0.3),
                blurRadius: 24, spreadRadius: 4,
              )],
            ),
            child: const Icon(Icons.document_scanner_rounded,
                color: Colors.white, size: 42),
          ),
          const SizedBox(height: 20),
          const Text('Deepfake Detector',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary, letterSpacing: -0.3)),
          const SizedBox(height: 8),
          const Text(
            'Upload any face photo to instantly\ndetect if it\'s real or AI-generated',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const ScanScreen(),
                    transitionsBuilder: (_, animation, __, child) =>
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
                // Refresh stats after returning from scan
                _loadStats();
              },
              icon: const Icon(Icons.search_rounded, size: 20),
              label: const Text('Start Scanning',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusM)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick Actions ──────────────────────────────────────────────
  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _buildActionTile(
              icon: Icons.history_rounded, label: 'Scan History',
              subtitle: 'Past results', color: AppTheme.accent,
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HistoryScreen())),
            )),
            const SizedBox(width: 12),
            // In _buildQuickActions:
            Expanded(child: _buildActionTile(
              icon: Icons.person_outline, label: 'My Profile',
              subtitle: 'Edit account', color: AppTheme.success,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
                if (mounted) _refreshUser();
              },
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon, required String label,
    required String subtitle, required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.paddingL),
        decoration: AppTheme.cardDecoration(borderColor: color.withOpacity(0.2)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusS),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontSize: 14,
                fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  // ── How It Works ───────────────────────────────────────────────
  Widget _buildHowItWorks() {
    final steps = [
      (Icons.upload_rounded,     AppTheme.primary, 'Upload',
      'Select a face photo from gallery or camera'),
      (Icons.psychology_rounded, AppTheme.accent,  'Analyse',
      'AI model scans for deepfake artifacts'),
      (Icons.verified_rounded,   AppTheme.success, 'Result',
      'Get verdict with confidence score & details'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('How It Works',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(AppTheme.paddingL),
          decoration: AppTheme.cardDecoration(),
          child: Column(
            children: steps.asMap().entries.map((entry) {
              final i = entry.key; final step = entry.value;
              return Column(children: [
                Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: step.$2.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                    child: Icon(step.$1, color: step.$2, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(step.$3, style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary, fontSize: 14)),
                      Text(step.$4, style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13)),
                    ],
                  )),
                ]),
                if (i < steps.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 22, top: 8, bottom: 8),
                    child: Container(width: 1, height: 20,
                        color: AppTheme.surfaceBorder),
                  ),
              ]);
            }).toList(),
          ),
        ),
      ],
    );
  }
}
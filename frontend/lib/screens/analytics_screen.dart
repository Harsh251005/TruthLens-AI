// screens/analytics_screen.dart
// ============================================================
// Personal Analytics Dashboard — gives users a meaningful sense
// of their scanning activity, progress and achievements.
// ============================================================

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../services/detection_service.dart';
import '../utils/app_theme.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {

  final _detectionService = DetectionService();
  AnalyticsData? _data;
  bool _isLoading = true;

  // For subtle entrance animations
  late AnimationController _animController;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController, curve: Curves.easeOut,
    );
    _loadData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _detectionService.getAnalytics();
    if (!mounted) return;
    setState(() { _data = data; _isLoading = false; });
    _animController.forward(from: 0); // Trigger entrance animation
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Row(children: [
          const Text('My Analytics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color:        AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.2)),
            ),
            child: const Text('VeriNet',
                style: TextStyle(fontSize: 10, color: AppTheme.primary,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon:    const Icon(Icons.refresh, color: AppTheme.primary),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _data == null
          ? _buildErrorState()
          : _data!.totalScans == 0
          ? _buildEmptyState()
          : _buildDashboard(),
    );
  }


  // ── Error state ───────────────────────────────────────────────
  Widget _buildErrorState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.wifi_off, color: AppTheme.textSecondary, size: 48),
        const SizedBox(height: 16),
        const Text('Could not load analytics',
            style: TextStyle(color: AppTheme.textPrimary,
                fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextButton(onPressed: _loadData,
            child: const Text('Try Again',
                style: TextStyle(color: AppTheme.primary))),
      ]),
    );
  }


  // ── Empty state ───────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle),
          child: const Icon(Icons.bar_chart_rounded,
              color: AppTheme.primary, size: 40),
        ),
        const SizedBox(height: 20),
        const Text('No data yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        const Text('Run your first scan to see\nyour analytics here!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary,
                height: 1.5)),
      ]),
    );
  }


  // ── Main dashboard ────────────────────────────────────────────
  Widget _buildDashboard() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: RefreshIndicator(
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
              _buildInsightBanner(),
              const SizedBox(height: 20),
              _buildHeroStats(),
              const SizedBox(height: 24),
              _buildSectionTitle('Weekly Activity'),
              const SizedBox(height: 12),
              _buildWeeklyBarChart(),
              const SizedBox(height: 24),
              _buildSectionTitle('Real vs Fake Breakdown'),
              const SizedBox(height: 12),
              _buildDonutRow(),
              const SizedBox(height: 24),
              _buildSectionTitle('Average Confidence'),
              const SizedBox(height: 12),
              _buildConfidenceCards(),
              const SizedBox(height: 24),
              _buildSectionTitle('Last 10 Scans Trend'),
              const SizedBox(height: 12),
              _buildTrendDots(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }


  // ── Insight banner ────────────────────────────────────────────
  Widget _buildInsightBanner() {
    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2744), Color(0xFF0F1629)],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color:  AppTheme.primary.withValues(alpha: 0.15),
            shape:  BoxShape.circle,
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
          ),
          child: const Icon(Icons.lightbulb_outline,
              color: AppTheme.primary, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            _data!.insight,
            style: const TextStyle(
              fontSize:   14,
              color:      AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
              height:     1.5,
            ),
          ),
        ),
      ]),
    );
  }


  // ── Hero stats row ────────────────────────────────────────────
  Widget _buildHeroStats() {
    return Row(children: [
      Expanded(child: _buildHeroCard(
        value:    '${_data!.totalScans}',
        label:    'Total Scans',
        icon:     Icons.document_scanner_rounded,
        color:    AppTheme.primary,
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2744), Color(0xFF0F1A35)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      )),
      const SizedBox(width: 12),
      Expanded(child: _buildHeroCard(
        value:    '${_data!.totalFake}',
        label:    'Deepfakes Caught',
        icon:     Icons.dangerous_rounded,
        color:    AppTheme.error,
        gradient: const LinearGradient(
          colors: [Color(0xFF2B0D0D), Color(0xFF1F0A0A)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      )),
      const SizedBox(width: 12),
      Expanded(child: _buildHeroCard(
        value:    '${_data!.realPercentage.toStringAsFixed(0)}%',
        label:    'Authentic Rate',
        icon:     Icons.verified_rounded,
        color:    AppTheme.success,
        gradient: const LinearGradient(
          colors: [Color(0xFF0D2B1F), Color(0xFF0A1F16)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      )),
    ]);
  }

  Widget _buildHeroCard({
    required String         value,
    required String         label,
    required IconData       icon,
    required Color          color,
    required LinearGradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        gradient:     gradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 22,
            fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10,
                color: AppTheme.textSecondary, height: 1.3)),
      ]),
    );
  }


  // ── Weekly bar chart ──────────────────────────────────────────
  Widget _buildWeeklyBarChart() {
    final data   = _data!.dailyActivity;
    final maxVal = data.map((d) => d.total).fold(0, (a, b) => a > b ? a : b);

    return Container(
      height:  200,
      padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
      decoration: BoxDecoration(
        color:        AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border:       Border.all(color: AppTheme.surfaceBorder),
      ),
      child: maxVal == 0
      // No activity this week
          ? const Center(child: Text('No scans this week',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)))
          : BarChart(
        BarChartData(
          alignment:        BarChartAlignment.spaceAround,
          maxY:             maxVal.toDouble() + 1,
          barTouchData:     BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppTheme.surface,
              getTooltipItem:  (group, _, rod, _) {
                final d = data[group.x];
                return BarTooltipItem(
                  '${d.date}\n',
                  const TextStyle(color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700, fontSize: 12),
                  children: [
                    TextSpan(text: '${d.total} scan(s)',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11)),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (val, _) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(data[val.toInt()].date,
                      style: const TextStyle(
                          color:    AppTheme.textSecondary,
                          fontSize: 11)),
                ),
              ),
            ),
            leftTitles:   AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:    AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:  AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData:   FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups:  data.asMap().entries.map((entry) {
            final i = entry.key;
            final d = entry.value;
            // Today is the last bar — highlight it
            final isToday  = i == 6;
            final barColor = isToday ? AppTheme.primary : AppTheme.primary.withValues(alpha: 0.45);

            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY:           d.total.toDouble(),
                color:         barColor,
                width:         22,
                borderRadius:  const BorderRadius.vertical(
                    top: Radius.circular(6)),
                // Stack real (green) on top of fake (red)
                rodStackItems: d.total > 0 ? [
                  BarChartRodStackItem(0, d.fakeCount.toDouble(),
                      AppTheme.error.withValues(alpha: 0.7)),
                  BarChartRodStackItem(d.fakeCount.toDouble(),
                      d.total.toDouble(),
                      AppTheme.success.withValues(alpha: 0.7)),
                ] : [],
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }


  // ── Donut chart row ───────────────────────────────────────────
  Widget _buildDonutRow() {
    final real = _data!.totalReal.toDouble();
    final fake = _data!.totalFake.toDouble();

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: BoxDecoration(
        color:        AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border:       Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Row(children: [
        // Donut
        SizedBox(
          width:  130, height: 130,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 38,
              sections: [
                PieChartSectionData(
                  value:          real,
                  color:          AppTheme.success,
                  radius:         26,
                  showTitle:      false,
                ),
                PieChartSectionData(
                  value:          fake,
                  color:          AppTheme.error,
                  radius:         26,
                  showTitle:      false,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        // Legend
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLegendItem(
                color:   AppTheme.success,
                label:   'Authentic',
                count:   _data!.totalReal,
                percent: _data!.realPercentage,
              ),
              const SizedBox(height: 16),
              _buildLegendItem(
                color:   AppTheme.error,
                label:   'Deepfake',
                count:   _data!.totalFake,
                percent: _data!.fakePercentage,
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildLegendItem({
    required Color  color,
    required String label,
    required int    count,
    required double percent,
  }) {
    return Row(children: [
      Container(width: 12, height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      // Expanded absorbs all remaining space — no Spacer needed
      Expanded(
        child: Text(label, style: const TextStyle(
            color: AppTheme.textPrimary, fontSize: 14,
            fontWeight: FontWeight.w600)),
      ),
      Text('$count', style: TextStyle(
          color: color, fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(width: 4),
      Text('(${percent.toStringAsFixed(0)}%)',
          style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 12)),
    ]);
  }


  // ── Confidence cards ──────────────────────────────────────────
  Widget _buildConfidenceCards() {
    return Row(children: [
      Expanded(child: _buildConfCard(
        label:      'Avg. Authentic\nConfidence',
        value:      _data!.avgConfidenceReal,
        color:      AppTheme.success,
        icon:       Icons.verified_rounded,
      )),
      const SizedBox(width: 12),
      Expanded(child: _buildConfCard(
        label:      'Avg. Deepfake\nConfidence',
        value:      _data!.avgConfidenceFake,
        color:      AppTheme.error,
        icon:       Icons.dangerous_rounded,
      )),
    ]);
  }

  Widget _buildConfCard({
    required String  label,
    required double  value,
    required Color   color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: BoxDecoration(
        color:        AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border:       Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 10),
        Text('${value.toStringAsFixed(1)}%',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
                color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12,
            color: AppTheme.textSecondary, height: 1.4)),
        const SizedBox(height: 10),
        // Confidence bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value:           value / 100,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor:      AlwaysStoppedAnimation<Color>(color),
            minHeight:       6,
          ),
        ),
      ]),
    );
  }


  // ── Last 10 trend dots ────────────────────────────────────────
  Widget _buildTrendDots() {
    final trend = _data!.verdictTrend;

    if (trend.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.paddingL),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(color: AppTheme.surfaceBorder),
        ),
        child: const Center(
          child: Text('Not enough scans yet',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingL),
      decoration: BoxDecoration(
        color:        AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border:       Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Dot row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: trend.asMap().entries.map((e) {
              final isFake  = e.value == 'FAKE';
              final color   = isFake ? AppTheme.error : AppTheme.success;
              final isLast  = e.key == trend.length - 1;
              return Row(children: [
                if (e.key > 0)
                  Container(width: 16, height: 2,
                      color: AppTheme.surfaceBorder),
                Container(
                  width:  isLast ? 18 : 14,
                  height: isLast ? 18 : 14,
                  decoration: BoxDecoration(
                    color:  color,
                    shape:  BoxShape.circle,
                    boxShadow: isLast ? [
                      BoxShadow(color: color.withValues(alpha: 0.5),
                          blurRadius: 8, spreadRadius: 2),
                    ] : [],
                  ),
                  child: isLast
                      ? const Icon(Icons.circle, color: Colors.white, size: 8)
                      : null,
                ),
              ]);
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        // Legend
        Row(children: [
          Container(width: 10, height: 10,
              decoration: const BoxDecoration(
                  color: AppTheme.success, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          const Text('Authentic', style: TextStyle(
              color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(width: 16),
          Container(width: 10, height: 10,
              decoration: const BoxDecoration(
                  color: AppTheme.error, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          const Text('Deepfake', style: TextStyle(
              color: AppTheme.textSecondary, fontSize: 12)),
          const Spacer(),
          const Text('old → new', // Shortened to prevent overflow
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
        ]),
      ]),
    );
  }


  // ── Section title ─────────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Text(title.toUpperCase(),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary, letterSpacing: 1.0));
  }
}
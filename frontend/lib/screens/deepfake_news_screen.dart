// screens/deepfake_news_screen.dart
// ============================================================
// FIXED:
//   Bug 1 — forceRefresh set _isLoading = true which replaced
//            the whole screen with a spinner and disposed the
//            TabController, causing a permanently stuck state.
//   Bug 2 — _applyCategories() disposed the TabController
//            while TabBarView was still referencing it.
//
// Fix: separate _isRefreshing flag for background refreshes.
//   - First load (_categories empty) → shows full loading screen
//   - Refresh (pull-to-refresh or button) → keeps existing
//     content visible, shows a top banner while loading,
//     updates in place when done. TabController is only
//     recreated if category count changes.
// ============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';

// ── Models ────────────────────────────────────────────────────

class NewsArticle {
  final String  title;
  final String  description;
  final String  source;
  final String  url;
  final String? imageUrl;
  final String  publishedAt;

  const NewsArticle({
    required this.title,
    required this.description,
    required this.source,
    required this.url,
    this.imageUrl,
    required this.publishedAt,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> j) => NewsArticle(
    title:       j['title']        as String? ?? 'No title',
    description: j['description']  as String? ?? '',
    source:      j['source']       as String? ?? 'Unknown',
    url:         j['url']          as String? ?? '',
    imageUrl:    j['image_url']    as String?,
    publishedAt: j['published_at'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'title':        title,
    'description':  description,
    'source':       source,
    'url':          url,
    'image_url':    imageUrl,
    'published_at': publishedAt,
  };
}

class NewsCategory {
  final String            id;
  final String            label;
  final Color             color;
  final List<NewsArticle> articles;

  const NewsCategory({
    required this.id,
    required this.label,
    required this.color,
    required this.articles,
  });

  factory NewsCategory.fromJson(Map<String, dynamic> j) {
    final hex   = (j['color_hex'] as String? ?? '#4F8EF7').replaceAll('#', '');
    final color = Color(int.parse('FF$hex', radix: 16));
    return NewsCategory(
      id:       j['id']    as String? ?? '',
      label:    j['label'] as String? ?? '',
      color:    color,
      articles: (j['articles'] as List? ?? [])
          .map((a) => NewsArticle.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ── Screen ────────────────────────────────────────────────────

class DeepfakeNewsScreen extends StatefulWidget {
  const DeepfakeNewsScreen({super.key});

  @override
  State<DeepfakeNewsScreen> createState() => _DeepfakeNewsScreenState();
}

class _DeepfakeNewsScreenState extends State<DeepfakeNewsScreen>
    with SingleTickerProviderStateMixin {

  List<NewsCategory> _categories   = [];
  bool               _isLoading    = true;   // First load only
  bool               _isRefreshing = false;  // Background refresh only — FIX
  bool               _isStaleCache = false;
  String?            _fetchedAt;

  TabController? _tabController;

  static const String _cacheKey      = 'news_multi_cache_v2';
  static const String _cacheTimeKey  = 'news_multi_cache_time_v2';
  static const int    _cacheTtlHours = 24;

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  // ── Data loading ───────────────────────────────────────────

  Future<void> _loadNews({bool forceRefresh = false}) async {
    // ── FIX: distinguish first load vs background refresh ────
    // First load (_categories empty) → full screen spinner
    // Refresh → keep existing UI, show top banner only
    if (_categories.isEmpty) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isRefreshing = true);  // ← keeps content visible
    }

    // Try client-side cache first (skip on forceRefresh)
    if (!forceRefresh) {
      final cached = await _loadClientCache();
      if (cached != null) {
        _applyCategories(
          cached['categories'] as List<NewsCategory>,
          cached['fetched_at'] as String?,
          stale: false,
        );
        return;
      }
    }

    // Fetch from backend
    try {
      final response = await http.get(
        Uri.parse(AppConstants.newsEndpoint),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final cats = (body['categories'] as List? ?? [])
            .map((c) => NewsCategory.fromJson(c as Map<String, dynamic>))
            .where((c) => c.articles.isNotEmpty)
            .toList();

        if (cats.isNotEmpty) {
          await _saveClientCache(cats, body['fetched_at'] as String?);
          _applyCategories(cats, body['fetched_at'] as String?, stale: false);
          return;
        }
      }
    } catch (e) {
      debugPrint('News fetch error: $e');
    }

    // Backend failed → try stale client cache
    final stale = await _loadClientCache(ignoreExpiry: true);
    if (stale != null) {
      _applyCategories(
        stale['categories'] as List<NewsCategory>,
        stale['fetched_at'] as String?,
        stale: true,
      );
      return;
    }

    // Nothing available — clear loading flags and show empty state
    if (mounted) {
      setState(() {
        _isLoading    = false;
        _isRefreshing = false;
      });
    }
  }

  void _applyCategories(
      List<NewsCategory> cats,
      String? fetchedAt, {
        required bool stale,
      }) {
    if (!mounted) return;

    // ── FIX: only recreate TabController if category count changes ──
    // Previously disposed on every refresh — caused stuck TabBarView.
    if (_tabController == null || _tabController!.length != cats.length) {
      _tabController?.dispose();
      _tabController = TabController(length: cats.length, vsync: this);
    }

    setState(() {
      _categories   = cats;
      _fetchedAt    = fetchedAt;
      _isStaleCache = stale;
      _isLoading    = false;    // Clear full-screen spinner
      _isRefreshing = false;    // Clear background refresh banner
    });
  }

  // ── Client cache ───────────────────────────────────────────

  Future<Map<String, dynamic>?> _loadClientCache({
    bool ignoreExpiry = false,
  }) async {
    try {
      final prefs   = await SharedPreferences.getInstance();
      final timeStr = prefs.getString(_cacheTimeKey);
      final dataStr = prefs.getString(_cacheKey);
      if (timeStr == null || dataStr == null) return null;

      if (!ignoreExpiry) {
        final age = DateTime.now().difference(DateTime.parse(timeStr)).inHours;
        if (age >= _cacheTtlHours) return null;
      }

      final raw  = jsonDecode(dataStr) as Map<String, dynamic>;
      final cats = (raw['categories'] as List)
          .map((c) => NewsCategory.fromJson(c as Map<String, dynamic>))
          .toList();
      return {'categories': cats, 'fetched_at': raw['fetched_at']};
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveClientCache(
      List<NewsCategory> cats,
      String? fetchedAt,
      ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data  = jsonEncode({
        'fetched_at': fetchedAt,
        'categories': cats.map((c) => {
          'id':        c.id,
          'label':     c.label,
          'color_hex': '#${c.color.value.toRadixString(16).substring(2).toUpperCase()}',
          'articles':  c.articles.map((a) => a.toJson()).toList(),
        }).toList(),
      });
      await prefs.setString(_cacheKey,     data);
      await prefs.setString(_cacheTimeKey, DateTime.now().toIso8601String());
    } catch (_) {}
  }

  // ── Helpers ────────────────────────────────────────────────

  Future<void> _openArticle(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:         Text('Could not open article'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  String _formatDate(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      const m = ['Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${m[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {
      return dateStr.split('T').first;
    }
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('News Tracker',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // ── FIX: show small spinner in AppBar during refresh ──
          // instead of replacing entire screen content
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(
                    color: AppTheme.primary, strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon:      const Icon(Icons.refresh, color: AppTheme.primary),
              onPressed: () => _loadNews(forceRefresh: true),
            ),
        ],
        bottom: _isLoading || _categories.isEmpty
            ? null
            : PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: _buildTabBar(),
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _categories.isEmpty
          ? _buildEmptyState()
          : _buildTabContent(),
    );
  }

  // ── Tab bar ────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: AppTheme.surface,
      child: TabBar(
        controller:     _tabController,
        isScrollable:   true,
        tabAlignment:   TabAlignment.start,
        indicatorColor: Colors.transparent,
        dividerColor:   AppTheme.surfaceBorder,
        labelPadding:   const EdgeInsets.symmetric(horizontal: 6),
        padding:        const EdgeInsets.fromLTRB(12, 6, 12, 8),
        tabs: _categories.map((cat) => _CategoryTab(cat: cat)).toList(),
      ),
    );
  }

  // ── Tab content ────────────────────────────────────────────

  Widget _buildTabContent() {
    return Column(
      children: [
        _buildStatusBanner(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children:   _categories
                .map((cat) => _buildArticleList(cat))
                .toList(),
          ),
        ),
      ],
    );
  }

  // ── Status banner ──────────────────────────────────────────

  Widget _buildStatusBanner() {
    final totalArticles = _categories.fold(0, (s, c) => s + c.articles.length);
    final color = _isStaleCache ? AppTheme.accent : AppTheme.primary;
    final icon  = _isStaleCache
        ? Icons.bookmark_outlined
        : Icons.rss_feed_rounded;
    final label = _isStaleCache
        ? 'Showing cached articles. Pull down to refresh.'
        : '$totalArticles articles across ${_categories.length} categories • Tap to read';

    return Container(
      margin:  const EdgeInsets.fromLTRB(
          AppTheme.paddingL, AppTheme.paddingM, AppTheme.paddingL, 0),
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.paddingM, vertical: 10),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border:       Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: TextStyle(color: color, fontSize: 12, height: 1.4)),
        ),
      ]),
    );
  }

  // ── Article list ───────────────────────────────────────────

  Widget _buildArticleList(NewsCategory cat) {
    return RefreshIndicator(
      onRefresh:       () => _loadNews(forceRefresh: true),
      color:           AppTheme.primary,
      backgroundColor: AppTheme.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppTheme.paddingL, AppTheme.paddingM, AppTheme.paddingL, 32),
        children: [
          ...cat.articles.map((a) => _ArticleCard(
            article:     a,
            accentColor: cat.color,
            onTap:       () => _openArticle(a.url),
            formatDate:  _formatDate,
          )),
          _buildDisclaimer(),
        ],
      ),
    );
  }

  // ── Loading state ──────────────────────────────────────────

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppTheme.primary),
          SizedBox(height: 16),
          Text('Loading news feed...',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, color: AppTheme.textSecondary, size: 48),
          const SizedBox(height: 16),
          const Text('Could not load news',
              style: TextStyle(color: AppTheme.textPrimary,
                  fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _loadNews(forceRefresh: true),
            child: const Text('Try Again',
                style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  // ── Disclaimer ─────────────────────────────────────────────

  Widget _buildDisclaimer() {
    return Container(
      margin:  const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(AppTheme.paddingM),
      decoration: BoxDecoration(
        color:        AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border:       Border.all(color: AppTheme.surfaceBorder),
      ),
      child: const Row(children: [
        Icon(Icons.info_outline, color: AppTheme.textSecondary, size: 14),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Articles sourced from verified publishers via NewsAPI. '
                'TruthLens AI does not endorse third-party content.',
            style: TextStyle(fontSize: 11,
                color: AppTheme.textSecondary, height: 1.4),
          ),
        ),
      ]),
    );
  }
}

// ── Category Tab ──────────────────────────────────────────────

class _CategoryTab extends StatelessWidget {
  final NewsCategory cat;
  const _CategoryTab({required this.cat});

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 32,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color:        cat.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border:       Border.all(color: cat.color.withValues(alpha: 0.35)),
        ),
        child: Text(
          cat.label,
          style: TextStyle(
            color:      cat.color,
            fontSize:   12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── Article Card ──────────────────────────────────────────────

class _ArticleCard extends StatelessWidget {
  final NewsArticle              article;
  final Color                    accentColor;
  final VoidCallback             onTap;
  final String Function(String)  formatDate;

  const _ArticleCard({
    required this.article,
    required this.accentColor,
    required this.onTap,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin:     const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color:        AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border:       Border.all(color: AppTheme.surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.imageUrl != null && article.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft:  Radius.circular(AppTheme.radiusL - 1),
                  topRight: Radius.circular(AppTheme.radiusL - 1),
                ),
                child: Image.network(
                  article.imageUrl!,
                  height: 155, width: double.infinity,
                  fit:    BoxFit.cover,
                  errorBuilder:   (_, _, _) => const SizedBox.shrink(),
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 155, color: AppTheme.surface2,
                      child: const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.primary, strokeWidth: 2),
                      ),
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(AppTheme.paddingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color:        accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(article.source,
                            style: TextStyle(fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: accentColor)),
                      ),
                      Text(formatDate(article.publishedAt),
                          style: const TextStyle(fontSize: 11,
                              color: AppTheme.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(article.title,
                      style: const TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary, height: 1.4)),
                  const SizedBox(height: 8),
                  Text(article.description,
                      maxLines: 3, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13,
                          color: AppTheme.textSecondary, height: 1.5)),
                  const SizedBox(height: 12),
                  Row(children: [
                    const Spacer(),
                    Text('Read full article',
                        style: TextStyle(fontSize: 12,
                            color: accentColor,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded,
                        color: accentColor, size: 12),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// screens/deepfake_news_screen.dart
// ============================================================
// Deepfake News Tracker — live feed of verified deepfake-related
// news from NewsAPI. Filtered strictly to deepfake content.
// Falls back to curated cases if API returns insufficient results.
// ============================================================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── News Article Model ────────────────────────────────────────────
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

  factory NewsArticle.fromJson(Map<String, dynamic> json) => NewsArticle(
    title:       json['title']       as String? ?? 'No title',
    description: json['description'] as String? ?? 'No description available.',
    source:      (json['source'] as Map<String, dynamic>)['name']
    as String? ?? 'Unknown Source',
    url:         json['url']         as String? ?? '',
    imageUrl:    json['urlToImage']  as String?,
    publishedAt: json['publishedAt'] as String? ?? '',
  );
}

// ── Fallback curated articles (shown if API fails) ────────────────
const List<Map<String, String>> _fallbackArticles = [
  {
    'title':       '\$25 Million Lost in Deepfake Video Call Scam',
    'description': 'A Hong Kong finance worker was tricked into paying \$25 million after fraudsters used deepfake technology to impersonate the company\'s CFO in a video call.',
    'source':      'Reuters',
    'url':         'https://www.reuters.com',
    'publishedAt': '2024-02-05',
  },
  {
    'title':       'Taylor Swift Deepfake Images Spark Outrage',
    'description': 'Explicit AI-generated images of Taylor Swift spread across social media, viewed over 47 million times before removal, reigniting calls for deepfake legislation.',
    'source':      'The Verge',
    'url':         'https://www.theverge.com',
    'publishedAt': '2024-01-26',
  },
  {
    'title':       'Biden Deepfake Robocalls Target New Hampshire Voters',
    'description': 'AI-generated robocalls impersonating President Biden were sent to thousands of New Hampshire voters ahead of the primary, urging them not to vote.',
    'source':      'AP News',
    'url':         'https://apnews.com',
    'publishedAt': '2024-01-22',
  },
  {
    'title':       'EU AI Act Mandates Deepfake Labelling',
    'description': 'The European Union\'s landmark AI Act, passed in 2024, requires all AI-generated content including deepfakes to be clearly and visibly labelled.',
    'source':      'European Parliament',
    'url':         'https://www.europarl.europa.eu',
    'publishedAt': '2024-03-13',
  },
  {
    'title':       'Rishi Sunak Deepfake Audio Used in Facebook Investment Scam',
    'description': 'A deepfake audio recording of UK Prime Minister Rishi Sunak was used in fraudulent Facebook advertisements promoting fake investment schemes.',
    'source':      'The Guardian',
    'url':         'https://www.theguardian.com',
    'publishedAt': '2023-10-08',
  },
];


class DeepfakeNewsScreen extends StatefulWidget {
  const DeepfakeNewsScreen({super.key});

  @override
  State<DeepfakeNewsScreen> createState() => _DeepfakeNewsScreenState();
}

class _DeepfakeNewsScreenState extends State<DeepfakeNewsScreen> {

  List<NewsArticle> _articles    = [];
  bool              _isLoading   = true;
  bool              _isUsingFallback = false;
  String?           _errorMessage;

  // Keywords that must appear in title or description
  static const List<String> _requiredKeywords = [
    'deepfake', 'deep fake', 'synthetic media',
    'ai-generated', 'face swap', 'voice clone',
    'artificial intelligence fraud', 'ai fraud',
  ];

  @override
  void initState() {
    super.initState();
    _loadNews();
  }


  // ── Fetch news from NewsAPI ───────────────────────────────────
  Future<void> _loadNews({bool forceRefresh = false}) async {
    setState(() {
      _isLoading       = true;
      _errorMessage    = null;
      _isUsingFallback = false;
    });

    try {
      final prefs       = await SharedPreferences.getInstance();
      final lastFetched = prefs.getString('news_last_fetched');
      final cachedNews  = prefs.getString('news_cached');

      // Use cache if fetched within last 6 hours and not force refreshing
      if (!forceRefresh && lastFetched != null && cachedNews != null) {
        final lastTime = DateTime.parse(lastFetched);
        final diff     = DateTime.now().difference(lastTime).inHours;
        if (diff < 6) {
          final decoded = jsonDecode(cachedNews) as List;
          final articles = decoded
              .map((e) => NewsArticle.fromJson(e as Map<String, dynamic>))
              .toList();
          if (articles.isNotEmpty) {
            setState(() { _articles = articles; _isLoading = false; });
            return;
          }
        }
      }

      // Fetch fresh news
      final response = await http.get(
        Uri.parse(AppConstants.newsApiEndpoint),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body    = jsonDecode(response.body) as Map<String, dynamic>;
        final rawList = body['articles'] as List? ?? [];

        final filtered = rawList
            .map((e) => NewsArticle.fromJson(e as Map<String, dynamic>))
            .where((a) => _isRelevant(a))
            .where((a) => a.title != '[Removed]')
            .where((a) => a.url.isNotEmpty)
            .toList();

        if (filtered.length >= 3) {
          // Cache the results
          await prefs.setString('news_last_fetched',
              DateTime.now().toIso8601String());
          await prefs.setString('news_cached',
              jsonEncode(filtered.map((a) => {
                'title':       a.title,
                'description': a.description,
                'source':      {'name': a.source},
                'url':         a.url,
                'urlToImage':  a.imageUrl,
                'publishedAt': a.publishedAt,
              }).toList()));

          setState(() { _articles = filtered; _isLoading = false; });
        } else {
          _useFallback();
        }
      } else {
        _useFallback();
      }
    } catch (_) {
      _useFallback();
    }
  }


  // ── Check if article is truly deepfake-related ────────────────
  bool _isRelevant(NewsArticle article) {
    final text = '${article.title} ${article.description}'.toLowerCase();
    return _requiredKeywords.any((kw) => text.contains(kw));
  }


  // ── Use curated fallback articles ────────────────────────────
  void _useFallback() {
    setState(() {
      _articles = _fallbackArticles.map((f) => NewsArticle(
        title:       f['title']!,
        description: f['description']!,
        source:      f['source']!,
        url:         f['url']!,
        publishedAt: f['publishedAt']!,
      )).toList();
      _isLoading        = false;
      _isUsingFallback  = true;
    });
  }


  // ── Open article in browser ───────────────────────────────────
  Future<void> _openArticle(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:         Text('Could not open article'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }


  // ── Format date ───────────────────────────────────────────────
  String _formatDate(String dateStr) {
    try {
      final date   = DateTime.parse(dateStr);
      final months = ['Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return dateStr.split('T')[0];
    }
  }


  // ═══════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text('Deepfake News',
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
            onPressed: () => _loadNews(forceRefresh: true),
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : RefreshIndicator(
        onRefresh:       _loadNews,
        color:           AppTheme.primary,
        backgroundColor: AppTheme.surface,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.paddingL),
          children: [
            const SizedBox(height: 4),

            // ── Source banner ──────────────────────────
            _buildSourceBanner(),
            const SizedBox(height: 16),

            // ── Article cards ──────────────────────────
            ..._articles.map((a) => _buildArticleCard(a)),

            const SizedBox(height: 16),

            // ── Disclaimer ─────────────────────────────
            _buildDisclaimer(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }


  // ── Loading state ─────────────────────────────────────────────
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.primary),
          const SizedBox(height: 16),
          const Text('Fetching latest deepfake news...',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }


  // ── Source banner ─────────────────────────────────────────────
  Widget _buildSourceBanner() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingM),
      decoration: BoxDecoration(
        color: _isUsingFallback
            ? AppTheme.accent.withValues(alpha: 0.08)
            : AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: _isUsingFallback
              ? AppTheme.accent.withValues(alpha: 0.2)
              : AppTheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(children: [
        Icon(
          _isUsingFallback
              ? Icons.bookmark_outlined
              : Icons.rss_feed_rounded,
          color: _isUsingFallback ? AppTheme.accent : AppTheme.primary,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _isUsingFallback
                ? 'Showing curated verified cases. Pull to refresh for live news.'
                : 'Live news • ${_articles.length} articles • Tap to read full story',
            style: TextStyle(
              color: _isUsingFallback ? AppTheme.accent : AppTheme.primary,
              fontSize: 12, height: 1.4,
            ),
          ),
        ),
      ]),
    );
  }


  // ── Article card ──────────────────────────────────────────────
  Widget _buildArticleCard(NewsArticle article) {
    return GestureDetector(
      onTap: () => _openArticle(article.url),
      child: Container(
        margin:   const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color:        AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border:       Border.all(color: AppTheme.surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Thumbnail if available ─────────────────────
            if (article.imageUrl != null &&
                article.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft:  Radius.circular(AppTheme.radiusL - 1),
                  topRight: Radius.circular(AppTheme.radiusL - 1),
                ),
                child: Image.network(
                  article.imageUrl!,
                  height:     160,
                  width:      double.infinity,
                  fit:        BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 160,
                      color:  AppTheme.surface2,
                      child: const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.primary, strokeWidth: 2),
                      ),
                    );
                  },
                ),
              ),

            // ── Content ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(AppTheme.paddingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Source + date row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color:        AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(article.source,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary)),
                      ),
                      Text(_formatDate(article.publishedAt),
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary)),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Title
                  Text(article.title,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          height: 1.4)),

                  const SizedBox(height: 8),

                  // Description
                  Text(article.description,
                      maxLines:  3,
                      overflow:  TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.5)),

                  const SizedBox(height: 12),

                  // Read more row
                  Row(children: [
                    const Spacer(),
                    const Text('Read full article',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        color: AppTheme.primary, size: 12),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  // ── Disclaimer ────────────────────────────────────────────────
  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingM),
      decoration: BoxDecoration(
        color:        AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border:       Border.all(color: AppTheme.surfaceBorder),
      ),
      child: const Row(children: [
        Icon(Icons.info_outline,
            color: AppTheme.textSecondary, size: 16),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'News articles are sourced from verified publishers via NewsAPI. '
                'TruthLens AI does not endorse any third-party content.',
            style: TextStyle(fontSize: 11,
                color: AppTheme.textSecondary, height: 1.4),
          ),
        ),
      ]),
    );
  }
}
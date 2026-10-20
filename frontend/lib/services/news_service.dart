// services/news_service.dart
// ============================================================
// Multi-category news straight from NewsAPI — port of
// backend/services/news_service.py. One request per category
// (9 per refresh); the news screen caches results for 24h so a
// phone normally refreshes once a day.
//
// NewsAPI's free plan allows 100 requests/day per key, shared by
// every install that uses the same key.
// ============================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class NewsService {

  static const _base = 'https://newsapi.org/v2/everything';

  // 'query' — NewsAPI `q` parameter (supports AND/OR/NOT)
  static const List<Map<String, String>> _categories = [
    {'id': 'deepfake', 'label': 'Deepfakes', 'color_hex': '#EF4444',
     'query': 'deepfake OR "deep fake" OR "face swap"'},
    {'id': 'ai_fraud', 'label': 'AI Fraud', 'color_hex': '#F59E0B',
     'query': '"AI fraud" OR "voice clone" OR "synthetic media fraud"'},
    {'id': 'cybersecurity', 'label': 'Cybersecurity', 'color_hex': '#4F8EF7',
     'query': 'cybersecurity AND ("artificial intelligence" OR "AI attack" OR "AI threat")'},
    {'id': 'ai_ethics', 'label': 'AI Ethics', 'color_hex': '#A855F7',
     'query': '"AI ethics" OR "algorithmic bias" OR "responsible AI"'},
    {'id': 'misinformation', 'label': 'Misinformation', 'color_hex': '#EC4899',
     'query': 'misinformation AND ("artificial intelligence" OR "AI-generated")'},
    {'id': 'ai_regulation', 'label': 'AI Regulation', 'color_hex': '#10B981',
     'query': '"AI regulation" OR "AI law" OR "AI Act" OR "AI legislation"'},
    {'id': 'detection_tech', 'label': 'Detection Tech', 'color_hex': '#06B6D4',
     'query': '"deepfake detection" OR "AI detection" OR "media authentication"'},
    {'id': 'privacy', 'label': 'Privacy & Surveillance', 'color_hex': '#64748B',
     'query': '"facial recognition" OR "AI surveillance" OR "biometric privacy"'},
    {'id': 'generative_ai', 'label': 'Generative AI', 'color_hex': '#F97316',
     'query': '"generative AI" AND (misuse OR risk OR harm OR abuse OR safety)'},
  ];

  /// Returns {categories, fetched_at, is_fallback} — the shape
  /// GET /api/news/ used to return. Empty categories on failure.
  static Future<Map<String, dynamic>> fetchAll() async {
    if (AppConstants.newsApiKey.isEmpty) {
      return {'categories': [], 'fetched_at': null, 'is_fallback': true};
    }

    final results = await Future.wait(_categories.map((cat) async {
      final articles = await _fetchCategory(cat['query']!);
      if (articles.isEmpty) return null;
      return {
        'id':        cat['id'],
        'label':     cat['label'],
        'color_hex': cat['color_hex'],
        'articles':  articles,
      };
    }));

    return {
      'categories':  results.whereType<Map<String, dynamic>>().toList(),
      'fetched_at':  DateTime.now().toUtc().toIso8601String(),
      'is_fallback': false,
    };
  }

  /// Up to 10 cleaned articles for one query, or [] on error.
  static Future<List<Map<String, dynamic>>> _fetchCategory(String query) async {
    try {
      final uri = Uri.parse(_base).replace(queryParameters: {
        'q':        query,
        'language': 'en',
        'sortBy':   'publishedAt',   // Freshest first
        'pageSize': '10',
      });
      final response = await http.get(
        uri,
        headers: {'X-Api-Key': AppConstants.newsApiKey},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];

      final raw = (jsonDecode(response.body)['articles'] as List?) ?? [];
      final cleaned = <Map<String, dynamic>>[];
      for (final a in raw.cast<Map<String, dynamic>>()) {
        final title = (a['title'] as String?) ?? '';
        final desc  = (a['description'] as String?) ?? '';
        final url   = (a['url'] as String?) ?? '';
        // Skip removed/empty articles
        if (title == '[Removed]' || url.isEmpty || title.isEmpty) continue;
        cleaned.add({
          'title':        title,
          'description':  desc.isEmpty ? 'No description available.' : desc,
          'source':       (a['source'] as Map?)?['name'] ?? 'Unknown',
          'url':          url,
          'image_url':    a['urlToImage'],
          'published_at': a['publishedAt'] ?? '',
        });
      }
      return cleaned;
    } catch (_) {
      return [];
    }
  }
}

// services/explanation_service.dart
// ============================================================
// Plain-language verdict explanation — port of
// backend/services/llm_service.py, now calling OpenAI from the
// device. Key comes from --dart-define-from-file=env.json; with
// no key or any API error the built-in fallback text is used.
// ============================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class ExplanationService {

  static const _systemPrompt =
      'You are a digital forensics expert who has spent years '
      'analysing manipulated images. You speak directly, plainly '
      "and honestly — like you're telling a friend what you found. "
      'You never use corporate language, bullet points, or '
      "structured formatting. You never say 'I' or refer to "
      'yourself. You never mention model names or technical '
      'systems. You just describe what the image shows and '
      'what it means. Keep it under 3 sentences. Sound human.';

  static Future<String> generate({
    required String       verdict,
    required double       confidence,
    required double       rawScore,
    required List<String> exifFlags,
    required String       exifRisk,
  }) async {
    if (AppConstants.openAiApiKey.isEmpty) {
      return fallback(verdict, confidence);
    }
    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer ${AppConstants.openAiApiKey}',
        },
        body: jsonEncode({
          'model':       AppConstants.openAiModel,
          'temperature': 0.4,
          'max_tokens':  180,
          'messages': [
            {'role': 'system', 'content': _systemPrompt},
            {
              'role':    'user',
              'content': _buildPrompt(confidence, rawScore, exifFlags, exifRisk),
            },
          ],
        }),
      ).timeout(AppConstants.requestTimeout);

      if (response.statusCode != 200) return fallback(verdict, confidence);
      final body    = jsonDecode(response.body) as Map<String, dynamic>;
      final content = body['choices'][0]['message']['content'] as String;
      return content.trim();
    } catch (_) {
      return fallback(verdict, confidence);
    }
  }

  static String _buildPrompt(
    double       confidence,
    double       rawScore,
    List<String> exifFlags,
    String       exifRisk,
  ) {
    final String signal;
    if (rawScore > 0.92) {
      signal = 'almost certainly manipulated';
    } else if (rawScore > 0.78) {
      signal = 'clearly shows signs of manipulation';
    } else if (rawScore > 0.62) {
      signal = 'has some suspicious patterns';
    } else if (rawScore > 0.50) {
      signal = 'is borderline — slightly leans toward being fake';
    } else if (rawScore > 0.35) {
      signal = 'is borderline — slightly leans toward being real';
    } else if (rawScore > 0.18) {
      signal = 'looks mostly authentic';
    } else {
      signal = 'looks very authentic';
    }

    // Only mention EXIF if it's genuinely HIGH risk —
    // never mention missing EXIF, that's normal for most images
    final exifContext = exifRisk == 'HIGH' && exifFlags.isNotEmpty
        ? 'The metadata also raised a flag: ${exifFlags.first}. '
        : '';

    return 'This face photo $signal. '
        'Confidence is ${confidence.toStringAsFixed(1)}%. '
        '$exifContext'
        'In 2-3 short plain sentences, explain what this means '
        'for this specific confidence level. '
        'Focus on what the visual analysis found — never mention '
        'missing metadata, camera info, or GPS data. '
        'Sound like a person, not a report.';
  }

  /// Used when OpenAI is unavailable. Written to sound natural.
  static String fallback(String verdict, double confidence) {
    final pct = confidence.toStringAsFixed(0);
    if (verdict == 'FAKE') {
      if (confidence > 90) {
        return 'This one is almost certainly not a real photo — the patterns '
            'here are very consistent with AI-generated faces. '
            'At $pct% confidence, treat this image with serious '
            "scepticism and don't share it as if it were real.";
      } else if (confidence > 70) {
        return 'There are clear signs this image has been manipulated or '
            'generated, with $pct% confidence. '
            "It's worth verifying the source before trusting or sharing it.";
      }
      return "Something about this image doesn't quite add up, though the "
          "signal isn't strong enough to be certain. "
          'Treat it with caution and verify the source if it matters.';
    }
    if (confidence > 90) {
      return 'This looks like a genuine photo — nothing here suggests '
          'manipulation at $pct% confidence. '
          'That said, no analysis is perfect, so use your own judgement too.';
    } else if (confidence > 70) {
      return 'This image appears real, with $pct% confidence. '
          "There are no strong red flags, though the reading isn't "
          'completely decisive.';
    }
    return 'This image leans toward being authentic but the confidence '
        "is low enough that you shouldn't rely solely on this result. "
        'Worth a second look if the image is important.';
  }
}

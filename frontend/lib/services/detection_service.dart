// services/detection_service.dart
// ============================================================
// Handles all deepfake detection API calls:
//   - Uploading image for detection
//   - Fetching scan history
//   - Deleting scans
//   - Fetching stats
//   - Fetching analytics
//   - Fetching badges
//   - Saving challenge scores
//   - Fetching leaderboard
//   - Checking badge progress for notifications
// ============================================================

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../utils/constants.dart';
import '../services/storage_service.dart';
import 'notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';


// ── EXIF Analysis Model ───────────────────────────────────────────
class ExifAnalysis {
  final Map<String, dynamic> rawFields;
  final List<String>         suspicionFlags;
  final String               riskLevel;
  final String               summary;
  final bool                 hasExif;

  const ExifAnalysis({
    required this.rawFields,
    required this.suspicionFlags,
    required this.riskLevel,
    required this.summary,
    required this.hasExif,
  });

  factory ExifAnalysis.fromJson(Map<String, dynamic> json) => ExifAnalysis(
    rawFields:      Map<String, dynamic>.from(json['raw_fields'] as Map),
    suspicionFlags: List<String>.from(json['suspicion_flags'] as List),
    riskLevel:      json['risk_level'] as String,
    summary:        json['summary']    as String,
    hasExif:        json['has_exif']   as bool,
  );
}


// ── Detection Result Model ────────────────────────────────────────
class DetectionResult {
  final String       verdict;
  final double       confidence;
  final double       rawScore;
  final String       message;
  final List<String> tips;
  final String       explanation;
  final ExifAnalysis exifAnalysis;

  const DetectionResult({
    required this.verdict,
    required this.confidence,
    required this.rawScore,
    required this.message,
    required this.tips,
    required this.explanation,
    required this.exifAnalysis,
  });

  factory DetectionResult.fromJson(Map<String, dynamic> json) =>
      DetectionResult(
        verdict:      json['verdict']     as String,
        confidence:   (json['confidence'] as num).toDouble(),
        rawScore:     (json['raw_score']  as num).toDouble(),
        message:      json['message']     as String,
        tips:         List<String>.from(json['tips'] as List),
        explanation:  json['explanation'] as String,
        exifAnalysis: ExifAnalysis.fromJson(
            json['exif_analysis'] as Map<String, dynamic>),
      );

  bool get isFake => verdict == 'FAKE';
}


// ── Scan History Item Model ───────────────────────────────────────
class ScanHistoryItem {
  final int    id;
  final String imageName;
  final String verdict;
  final double confidence;
  final String scannedAt;

  const ScanHistoryItem({
    required this.id,
    required this.imageName,
    required this.verdict,
    required this.confidence,
    required this.scannedAt,
  });

  factory ScanHistoryItem.fromJson(Map<String, dynamic> json) =>
      ScanHistoryItem(
        id:         json['id']          as int,
        imageName:  json['image_name']  as String,
        verdict:    json['verdict']     as String,
        confidence: (json['confidence'] as num).toDouble(),
        scannedAt:  json['scanned_at']  as String,
      );

  bool get isFake => verdict == 'FAKE';
}


// ── Detection Response Wrapper ────────────────────────────────────
class DetectionResponse {
  final bool            success;
  final String          message;
  final DetectionResult? result;

  const DetectionResponse({
    required this.success,
    required this.message,
    this.result,
  });
}


// ── Scan Stats Model ──────────────────────────────────────────────
class ScanStats {
  final int     totalScans;
  final int     totalReal;
  final int     totalFake;
  final String? lastScanned;

  const ScanStats({
    required this.totalScans,
    required this.totalReal,
    required this.totalFake,
    this.lastScanned,
  });

  factory ScanStats.fromJson(Map<String, dynamic> json) => ScanStats(
    totalScans:  json['total_scans']  as int,
    totalReal:   json['total_real']   as int,
    totalFake:   json['total_fake']   as int,
    lastScanned: json['last_scanned'] as String?,
  );

  double get fakePercent =>
      totalScans == 0 ? 0 : (totalFake / totalScans) * 100;
}


// ── Daily Activity Model ──────────────────────────────────────────
class DailyActivity {
  final String date;
  final int    total;
  final int    realCount;
  final int    fakeCount;

  const DailyActivity({
    required this.date,
    required this.total,
    required this.realCount,
    required this.fakeCount,
  });

  factory DailyActivity.fromJson(Map<String, dynamic> json) => DailyActivity(
    date:      json['date']       as String,
    total:     json['total']      as int,
    realCount: json['real_count'] as int,
    fakeCount: json['fake_count'] as int,
  );
}


// ── Analytics Data Model ──────────────────────────────────────────
class AnalyticsData {
  final int                totalScans;
  final int                totalReal;
  final int                totalFake;
  final double             avgConfidenceReal;
  final double             avgConfidenceFake;
  final List<DailyActivity> dailyActivity;
  final List<String>       verdictTrend;
  final String             insight;
  final String?            lastScanned;

  const AnalyticsData({
    required this.totalScans,
    required this.totalReal,
    required this.totalFake,
    required this.avgConfidenceReal,
    required this.avgConfidenceFake,
    required this.dailyActivity,
    required this.verdictTrend,
    required this.insight,
    this.lastScanned,
  });

  factory AnalyticsData.fromJson(Map<String, dynamic> json) => AnalyticsData(
    totalScans:        json['total_scans']          as int,
    totalReal:         json['total_real']           as int,
    totalFake:         json['total_fake']           as int,
    avgConfidenceReal: (json['avg_confidence_real'] as num).toDouble(),
    avgConfidenceFake: (json['avg_confidence_fake'] as num).toDouble(),
    dailyActivity: (json['daily_activity'] as List)
        .map((e) => DailyActivity.fromJson(e as Map<String, dynamic>))
        .toList(),
    verdictTrend: (json['verdict_trend'] as List)
        .map((e) => e as String)
        .toList(),
    insight:     json['insight']      as String,
    lastScanned: json['last_scanned'] as String?,
  );

  double get fakePercentage =>
      totalScans > 0 ? (totalFake / totalScans) * 100 : 0;
  double get realPercentage =>
      totalScans > 0 ? (totalReal / totalScans) * 100 : 0;
}


// ── Badge Item Model ──────────────────────────────────────────────
class BadgeItem {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final bool   earned;
  final int    progress;
  final int    target;
  final String category;

  const BadgeItem({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.earned,
    required this.progress,
    required this.target,
    required this.category,
  });

  factory BadgeItem.fromJson(Map<String, dynamic> json) => BadgeItem(
    id:          json['id']          as String,
    name:        json['name']        as String,
    description: json['description'] as String,
    emoji:       json['emoji']       as String,
    earned:      json['earned']      as bool,
    progress:    json['progress']    as int,
    target:      json['target']      as int,
    category:    json['category']    as String,
  );

  double get progressFraction =>
      target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0;
}


// ── Badges Data Model ─────────────────────────────────────────────
class BadgesData {
  final List<BadgeItem> badges;
  final int             earnedCount;
  final int             totalCount;
  final int             currentStreak;
  final int             longestStreak;

  const BadgesData({
    required this.badges,
    required this.earnedCount,
    required this.totalCount,
    required this.currentStreak,
    required this.longestStreak,
  });

  factory BadgesData.fromJson(Map<String, dynamic> json) => BadgesData(
    badges: (json['badges'] as List)
        .map((e) => BadgeItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    earnedCount:   json['earned_count']   as int,
    totalCount:    json['total_count']    as int,
    currentStreak: json['current_streak'] as int,
    longestStreak: json['longest_streak'] as int,
  );

  List<BadgeItem> get scanBadges =>
      badges.where((b) => b.category == 'scans').toList();
  List<BadgeItem> get fakeBadges =>
      badges.where((b) => b.category == 'fakes' || b.category == 'real').toList();
  List<BadgeItem> get streakBadges =>
      badges.where((b) => b.category == 'streak').toList();
}


// ── Leaderboard Entry Model ───────────────────────────────────────
class LeaderboardEntry {
  final int     rank;
  final int     userId;
  final String  name;
  final String  avatarType;
  final String? avatarData;
  final int     score;
  final int     total;
  final double  accuracy;
  final int     maxCombo;
  final String  grade;
  final String  playedAt;

  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.name,
    required this.avatarType,
    this.avatarData,
    required this.score,
    required this.total,
    required this.accuracy,
    required this.maxCombo,
    required this.grade,
    required this.playedAt,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        rank:       json['rank']        as int,
        userId:     json['user_id']     as int,
        name:       json['name']        as String,
        avatarType: json['avatar_type'] as String? ?? 'initial',
        avatarData: json['avatar_data'] as String?,
        score:      json['score']       as int,
        total:      json['total']       as int,
        accuracy:   (json['accuracy']   as num).toDouble(),
        maxCombo:   json['max_combo']   as int,
        grade:      json['grade']       as String,
        playedAt:   json['played_at']   as String,
      );
}


// ── Personal Best Model ───────────────────────────────────────────
class PersonalBest {
  final int    score;
  final int    total;
  final double accuracy;
  final int    maxCombo;
  final String grade;
  final String playedAt;

  const PersonalBest({
    required this.score,
    required this.total,
    required this.accuracy,
    required this.maxCombo,
    required this.grade,
    required this.playedAt,
  });

  factory PersonalBest.fromJson(Map<String, dynamic> json) => PersonalBest(
    score:    json['score']     as int,
    total:    json['total']     as int,
    accuracy: (json['accuracy'] as num).toDouble(),
    maxCombo: json['max_combo'] as int,
    grade:    json['grade']     as String,
    playedAt: json['played_at'] as String,
  );
}


// ── Leaderboard Data Model ────────────────────────────────────────
class LeaderboardData {
  final List<LeaderboardEntry> entries;
  final int?                   userRank;
  final PersonalBest?          personalBest;
  final int                    totalPlayers;

  const LeaderboardData({
    required this.entries,
    this.userRank,
    this.personalBest,
    required this.totalPlayers,
  });

  factory LeaderboardData.fromJson(Map<String, dynamic> json) =>
      LeaderboardData(
        entries: (json['entries'] as List)
            .map((e) => LeaderboardEntry.fromJson(
            e as Map<String, dynamic>))
            .toList(),
        userRank: json['user_rank'] as int?,
        personalBest: json['personal_best'] != null
            ? PersonalBest.fromJson(
            json['personal_best'] as Map<String, dynamic>)
            : null,
        totalPlayers: json['total_players'] as int,
      );
}


// ── Detection Service ─────────────────────────────────────────────
class DetectionService {

  // ── Detect Image ──────────────────────────────────────────────
  Future<DetectionResponse> detectImage(File imageFile) async {
    try {
      final savedUser = await StorageService.getSavedUser();
      if (savedUser == null) {
        return const DetectionResponse(
            success: false, message: 'Not logged in');
      }

      final ext      = imageFile.path.split('.').last.toLowerCase();
      final mimeType = _getMimeType(ext);

      final request = http.MultipartRequest(
          'POST', Uri.parse(AppConstants.detectEndpoint));
      request.headers['Authorization'] = 'Bearer ${savedUser.token}';
      request.files.add(await http.MultipartFile.fromPath(
        'file', imageFile.path,
        contentType: MediaType('image', mimeType),
      ));

      final streamedResponse =
      await request.send().timeout(AppConstants.requestTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      final body     = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return DetectionResponse(
          success: true,
          message: 'Detection successful',
          result:  DetectionResult.fromJson(body),
        );
      } else if (response.statusCode == 422) {
        return DetectionResponse(
          success: false,
          message: body['detail'] as String? ?? 'No human face detected.',
        );
      } else {
        return DetectionResponse(
          success: false,
          message: body['detail'] as String? ?? 'Detection failed',
        );
      }
    } catch (e) {
      return DetectionResponse(success: false, message: _friendlyError(e));
    }
  }


  // ── Scan History ──────────────────────────────────────────────
  Future<List<ScanHistoryItem>> getHistory() async {
    try {
      final savedUser = await StorageService.getSavedUser();
      if (savedUser == null) return [];

      final response = await http.get(
        Uri.parse(AppConstants.historyEndpoint),
        headers: {
          'Authorization': 'Bearer ${savedUser.token}',
          'Accept':        'application/json',
        },
      ).timeout(AppConstants.requestTimeout);

      if (response.statusCode == 200) {
        final body  = jsonDecode(response.body) as Map<String, dynamic>;
        final scans = body['scans'] as List;
        return scans
            .map((s) => ScanHistoryItem.fromJson(s as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }


  // ── Delete Single Scan ────────────────────────────────────────
  Future<bool> deleteScan(int scanId) async {
    try {
      final savedUser = await StorageService.getSavedUser();
      if (savedUser == null) return false;

      final response = await http.delete(
        Uri.parse(AppConstants.deleteScanEndpoint(scanId)),
        headers: {
          'Authorization': 'Bearer ${savedUser.token}',
          'Accept':        'application/json',
        },
      ).timeout(AppConstants.requestTimeout);

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }


  // ── Delete All History ────────────────────────────────────────
  Future<bool> deleteHistory() async {
    try {
      final savedUser = await StorageService.getSavedUser();
      if (savedUser == null) return false;

      final response = await http.delete(
        Uri.parse(AppConstants.historyEndpoint),
        headers: {
          'Authorization': 'Bearer ${savedUser.token}',
          'Accept':        'application/json',
        },
      ).timeout(AppConstants.requestTimeout);

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }


  // ── Stats ─────────────────────────────────────────────────────
  Future<ScanStats?> getStats() async {
    try {
      final savedUser = await StorageService.getSavedUser();
      if (savedUser == null) return null;

      final response = await http.get(
        Uri.parse(AppConstants.statsEndpoint),
        headers: {
          'Authorization': 'Bearer ${savedUser.token}',
          'Accept':        'application/json',
        },
      ).timeout(AppConstants.requestTimeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return ScanStats.fromJson(body);
      }
      return null;
    } catch (_) {
      return null;
    }
  }


  // ── Analytics ─────────────────────────────────────────────────
  Future<AnalyticsData?> getAnalytics() async {
    try {
      final savedUser = await StorageService.getSavedUser();
      if (savedUser == null) return null;

      final response = await http.get(
        Uri.parse(AppConstants.analyticsEndpoint),
        headers: {
          'Authorization': 'Bearer ${savedUser.token}',
          'Accept':        'application/json',
        },
      ).timeout(AppConstants.requestTimeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return AnalyticsData.fromJson(body);
      }
      return null;
    } catch (_) {
      return null;
    }
  }


  // ── Badges ────────────────────────────────────────────────────
  Future<BadgesData?> getBadges() async {
    try {
      final savedUser = await StorageService.getSavedUser();
      if (savedUser == null) return null;

      final response = await http.get(
        Uri.parse(AppConstants.badgesEndpoint),
        headers: {
          'Authorization': 'Bearer ${savedUser.token}',
          'Accept':        'application/json',
        },
      ).timeout(AppConstants.requestTimeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return BadgesData.fromJson(body);
      }
      return null;
    } catch (_) {
      return null;
    }
  }


  // ── Save Challenge Score ──────────────────────────────────────
  Future<bool> saveScore({
    required int    score,
    required int    total,
    required double accuracy,
    required int    maxCombo,
    required String grade,
  }) async {
    try {
      final savedUser = await StorageService.getSavedUser();
      if (savedUser == null) return false;

      final response = await http.post(
        Uri.parse(AppConstants.saveScoreEndpoint),
        headers: {
          'Authorization': 'Bearer ${savedUser.token}',
          'Content-Type':  'application/json',
          'Accept':        'application/json',
        },
        body: jsonEncode({
          'score':     score,
          'total':     total,
          'accuracy':  accuracy,
          'max_combo': maxCombo,
          'grade':     grade,
        }),
      ).timeout(AppConstants.requestTimeout);

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }


  // ── Get Leaderboard ───────────────────────────────────────────
  Future<LeaderboardData?> getLeaderboard({
    String period = 'alltime',
  }) async {
    try {
      final savedUser = await StorageService.getSavedUser();
      if (savedUser == null) return null;

      final response = await http.get(
        Uri.parse('${AppConstants.leaderboardEndpoint}?period=$period'),
        headers: {
          'Authorization': 'Bearer ${savedUser.token}',
          'Accept':        'application/json',
        },
      ).timeout(AppConstants.requestTimeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return LeaderboardData.fromJson(body);
      }
      return null;
    } catch (_) {
      return null;
    }
  }


  // ── Notify only when a badge is NEWLY earned ─────────────
// Uses SharedPreferences to track which badges have already
// been notified — ensures each badge notification fires once.
  Future<void> checkBadgeProgress() async {
    try {
      final data = await getBadges();
      if (data == null) return;

      final prefs       = await SharedPreferences.getInstance();
      const notifiedKey = 'notified_badges'; // comma-separated list of badge IDs

      // Get previously notified badge IDs
      final notified = (prefs.getString(notifiedKey) ?? '').split(',').toSet();

      for (final badge in data.badges) {
        // Only notify if:
        // 1. Badge is earned
        // 2. We haven't notified for this badge before
        if (badge.earned && !notified.contains(badge.id)) {
          await NotificationService().showBadgeProgressNotification(
            badgeName:  badge.name,
            badgeEmoji: badge.emoji,
            stepsLeft:  0,
          );

          // Mark as notified so it never fires again
          notified.add(badge.id);
          await prefs.setString(notifiedKey, notified.join(','));
          break; // One notification per scan max
        }
      }
    } catch (_) {}
  }


  // ── Helpers ───────────────────────────────────────────────────
  String _getMimeType(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg': return 'jpeg';
      case 'png':  return 'png';
      case 'webp': return 'webp';
      default:     return 'jpeg';
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('SocketException') ||
        msg.contains('Connection refused')) {
      return 'Cannot reach server. Check your connection.';
    } else if (msg.contains('TimeoutException')) {
      return 'Detection timed out. Please try again.';
    }
    return 'An unexpected error occurred. Please try again.';
  }
}
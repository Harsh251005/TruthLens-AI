// services/detection_service.dart
// ============================================================
// Scans, history, stats, analytics, badges and leaderboard.
// Detection runs on the device (detector_service.dart); data
// lives in Firestore (firebase_refs.dart). Logic ported from
// backend/routes/{detect,badges,challenge}_routes.py — results
// are built in the old JSON shape and parsed by the models below.
// ============================================================

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'detector_service.dart';
import 'firebase_refs.dart';
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
  final String id;
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
        id:         json['id']          as String,
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
  final String  userId;
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
        userId:     json['user_id']     as String,
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


// ── Badge catalogue ───────────────────────────────────────────────
// Single source of truth for all badges.
// 'progress' and 'earned' are computed at runtime from scan data.
const List<Map<String, dynamic>> _badgeCatalogue = [
  // ── Scan milestone badges ─────────────────────────────────────
  {'id': 'first_step', 'name': 'First Step', 'description': 'Complete your very first scan', 'emoji': '🔍', 'category': 'scans', 'target': 1},
  {'id': 'rookie',     'name': 'Rookie',     'description': 'Complete 10 scans',             'emoji': '🎯', 'category': 'scans', 'target': 10},
  {'id': 'detective',  'name': 'Detective',  'description': 'Complete 25 scans',             'emoji': '🕵️', 'category': 'scans', 'target': 25},
  {'id': 'expert',     'name': 'Expert',     'description': 'Complete 50 scans',             'emoji': '⭐', 'category': 'scans', 'target': 50},
  {'id': 'master',     'name': 'Master',     'description': 'Complete 100 scans',            'emoji': '🏆', 'category': 'scans', 'target': 100},
  // ── Fake hunter badges ────────────────────────────────────────
  {'id': 'fake_hunter',     'name': 'Fake Hunter',     'description': 'Catch 5 deepfakes',          'emoji': '🎭', 'category': 'fakes', 'target': 5},
  {'id': 'deepfake_buster', 'name': 'Deepfake Buster', 'description': 'Catch 20 deepfakes',         'emoji': '💥', 'category': 'fakes', 'target': 20},
  {'id': 'truth_seeker',    'name': 'Truth Seeker',    'description': 'Verify 10 authentic images', 'emoji': '✅', 'category': 'real',  'target': 10},
  // ── Streak badges ─────────────────────────────────────────────
  {'id': 'on_fire',     'name': 'On Fire',     'description': 'Scan for 3 consecutive days',  'emoji': '🔥', 'category': 'streak', 'target': 3},
  {'id': 'unstoppable', 'name': 'Unstoppable', 'description': 'Scan for 7 consecutive days',  'emoji': '⚡', 'category': 'streak', 'target': 7},
  {'id': 'dedicated',   'name': 'Dedicated',   'description': 'Scan for 14 consecutive days', 'emoji': '💎', 'category': 'streak', 'target': 14},
  {'id': 'legend',      'name': 'Legend',      'description': 'Scan for 30 consecutive days', 'emoji': '👑', 'category': 'streak', 'target': 30},
];


// ── Detection Service ─────────────────────────────────────────────
class DetectionService {

  // ── Detect Image ──────────────────────────────────────────────
  Future<DetectionResponse> detectImage(File imageFile) async {
    try {
      final uid = FirebaseRefs.uid;
      if (uid == null) {
        return const DetectionResponse(
            success: false, message: 'Not logged in');
      }

      // ── Run detection pipeline ────────────────────────────
      final json   = await DetectorService.predict(imageFile);
      final result = DetectionResult.fromJson(json);

      // ── Save scan + update streak ─────────────────────────
      // Offline, Firestore queues the writes and these futures wait
      // for the server, so cap the wait — the result shows either way.
      await _saveScan(uid, imageFile, result)
          .timeout(const Duration(seconds: 5), onTimeout: () {});

      return DetectionResponse(
        success: true,
        message: 'Detection successful',
        result:  result,
      );
    } on NoFaceException catch (e) {
      return DetectionResponse(success: false, message: e.message);
    } on ModelMissingException {
      return const DetectionResponse(
        success: false,
        message: 'Detection model is missing from this build.',
      );
    } catch (e) {
      return DetectionResponse(success: false, message: _friendlyError(e));
    }
  }

  Future<void> _saveScan(String uid, File file, DetectionResult r) async {
    try {
      // Writes are not awaited: they apply to the local cache at once
      // and sync when online (an awaited write waits for the server).
      FirebaseRefs.scans(uid).add({
        'image_name': file.uri.pathSegments.isNotEmpty
            ? file.uri.pathSegments.last
            : 'uploaded_image',
        'verdict':    r.verdict,
        'confidence': r.confidence,
        'raw_score':  r.rawScore,
        'scanned_at': Timestamp.now(),
      });

      final userRef = FirebaseRefs.userDoc(uid);
      final user    = (await userRef.get()).data() ?? {};
      final today   = _dateKey(DateTime.now());
      final yesterday =
          _dateKey(DateTime.now().subtract(const Duration(days: 1)));
      final lastDate = user['last_scan_date'] as String?;
      final streak   = (user['current_streak'] as int?) ?? 0;
      final longest  = (user['longest_streak'] as int?) ?? 0;

      final int newStreak;
      if (lastDate == null) {
        newStreak = 1;                 // First scan ever
      } else if (lastDate == today) {
        newStreak = streak;            // Already scanned today
      } else if (lastDate == yesterday) {
        newStreak = streak + 1;        // Scanned yesterday — extend
      } else {
        newStreak = 1;                 // Gap — reset
      }

      userRef.update({
        'current_streak': newStreak,
        'last_scan_date': today,
        'longest_streak': newStreak > longest ? newStreak : longest,
      });
    } catch (_) {}
  }


  // ── Scan History ──────────────────────────────────────────────
  Future<List<ScanHistoryItem>> getHistory({int limit = 20}) async {
    try {
      final uid = FirebaseRefs.uid;
      if (uid == null) return [];

      final snap = await FirebaseRefs.scans(uid)
          .orderBy('scanned_at', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((d) {
        final data = d.data();
        return ScanHistoryItem.fromJson({
          'id':         d.id,
          'image_name': data['image_name'],
          'verdict':    data['verdict'],
          'confidence': data['confidence'],
          'scanned_at': _timestampString(data['scanned_at']),
        });
      }).toList();
    } catch (_) {
      return [];
    }
  }


  // ── Delete Single Scan ────────────────────────────────────────
  Future<bool> deleteScan(String scanId) async {
    try {
      final uid = FirebaseRefs.uid;
      if (uid == null) return false;
      await FirebaseRefs.scans(uid).doc(scanId).delete();
      return true;
    } catch (_) {
      return false;
    }
  }


  // ── Delete All History ────────────────────────────────────────
  Future<bool> deleteHistory() async {
    try {
      final uid = FirebaseRefs.uid;
      if (uid == null) return false;
      await FirebaseRefs.deleteAll(FirebaseRefs.scans(uid));
      return true;
    } catch (_) {
      return false;
    }
  }


  // ── Stats ─────────────────────────────────────────────────────
  Future<ScanStats?> getStats() async {
    try {
      final scans = await _allScans();
      if (scans == null) return null;
      return ScanStats.fromJson({
        'total_scans':  scans.length,
        'total_real':   scans.where((s) => s['verdict'] == 'REAL').length,
        'total_fake':   scans.where((s) => s['verdict'] == 'FAKE').length,
        'last_scanned': scans.isEmpty
            ? null
            : _timestampString(scans.first['scanned_at']),
      });
    } catch (_) {
      return null;
    }
  }


  // ── Analytics ─────────────────────────────────────────────────
  Future<AnalyticsData?> getAnalytics() async {
    try {
      final scans = await _allScans();   // newest first
      if (scans == null) return null;

      // ── Core counts ───────────────────────────────────────────
      final real = scans.where((s) => s['verdict'] == 'REAL').toList();
      final fake = scans.where((s) => s['verdict'] == 'FAKE').toList();
      final totalScans = scans.length;
      final totalReal  = real.length;
      final totalFake  = fake.length;

      double avg(List<Map<String, dynamic>> list) => list.isEmpty
          ? 0
          : ((list.fold<double>(0,
                      (total, s) => total + (s['confidence'] as num).toDouble()) /
                  list.length) * 10).round() / 10;

      // ── Weekly activity — last 7 days, always 7 bars ──────────
      const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dailyActivity = List.generate(7, (i) {
        final day = today.subtract(Duration(days: 6 - i));
        final onDay = scans.where((s) {
          final t = (s['scanned_at'] as Timestamp).toDate();
          return t.year == day.year && t.month == day.month && t.day == day.day;
        }).toList();
        return {
          'date':       dayLabels[day.weekday - 1],
          'total':      onDay.length,
          'real_count': onDay.where((s) => s['verdict'] == 'REAL').length,
          'fake_count': onDay.where((s) => s['verdict'] == 'FAKE').length,
        };
      });

      // ── Last 10 verdict trend, oldest → newest ────────────────
      final verdictTrend = scans
          .take(10)
          .map((s) => s['verdict'] as String)
          .toList()
          .reversed
          .toList();

      // ── Personalized insight ──────────────────────────────────
      final String insight;
      final last3 = verdictTrend.length >= 3
          ? verdictTrend.sublist(verdictTrend.length - 3)
          : const <String>[];
      if (totalScans == 0) {
        insight = 'Run your first scan to start building your analytics!';
      } else if (totalFake == 0) {
        insight = "You've scanned $totalScans image(s) — all authentic so far. Stay vigilant!";
      } else if (totalFake >= 10) {
        insight = "Impressive! You've caught $totalFake deepfakes. You're a pro detector! 🎯";
      } else if (totalScans >= 20) {
        final pct = (totalFake / totalScans * 100).round();
        insight = '$pct% of images you scanned were deepfakes. The internet needs you! 🛡️';
      } else if (last3.isNotEmpty && last3.every((v) => v == 'FAKE')) {
        insight = 'Last 3 scans were all deepfakes — stay alert out there! 🚨';
      } else if (last3.isNotEmpty && last3.every((v) => v == 'REAL')) {
        insight = 'Last 3 scans were all authentic. Your sources look trustworthy! ✅';
      } else {
        insight = "You've caught $totalFake deepfake(s) out of $totalScans scan(s). Keep going! 💪";
      }

      return AnalyticsData.fromJson({
        'total_scans':         totalScans,
        'total_real':          totalReal,
        'total_fake':          totalFake,
        'avg_confidence_real': avg(real),
        'avg_confidence_fake': avg(fake),
        'daily_activity':      dailyActivity,
        'verdict_trend':       verdictTrend,
        'insight':             insight,
        'last_scanned': scans.isEmpty
            ? null
            : _timestampString(scans.first['scanned_at']),
      });
    } catch (_) {
      return null;
    }
  }


  // ── Badges ────────────────────────────────────────────────────
  Future<BadgesData?> getBadges() async {
    try {
      final uid   = FirebaseRefs.uid;
      final scans = await _allScans();
      if (uid == null || scans == null) return null;

      final user          = (await FirebaseRefs.userDoc(uid).get()).data() ?? {};
      final currentStreak = (user['current_streak'] as int?) ?? 0;
      final longestStreak = (user['longest_streak'] as int?) ?? 0;
      final totalScans    = scans.length;
      final totalFake     = scans.where((s) => s['verdict'] == 'FAKE').length;
      final totalReal     = scans.where((s) => s['verdict'] == 'REAL').length;

      // ── Permanently earned badges ─────────────────────────
      final earnedSnap = await FirebaseRefs.earnedBadges(uid).get();
      final permanentlyEarned = earnedSnap.docs.map((d) => d.id).toSet();

      final badges      = <Map<String, dynamic>>[];
      final newEarnings = <String>[];
      for (final b in _badgeCatalogue) {
        final category = b['category'] as String;
        final target   = b['target'] as int;
        final progress = switch (category) {
          'scans'  => totalScans,
          'fakes'  => totalFake,
          'real'   => totalReal,
          // Use longest_streak so badge stays earned after a reset
          'streak' => longestStreak,
          _        => 0,
        };
        final isEarned = progress >= target || permanentlyEarned.contains(b['id']);
        if (isEarned && !permanentlyEarned.contains(b['id'])) {
          newEarnings.add(b['id'] as String);
        }
        // Show current_streak on the progress bar for streak badges
        final shown = category == 'streak' ? currentStreak : progress;
        badges.add({
          ...b,
          'earned':   isEarned,
          'progress': shown < target ? shown : target,
        });
      }

      // ── Persist newly earned badges ───────────────────────
      if (newEarnings.isNotEmpty) {
        final batch = FirebaseRefs.db.batch();
        for (final id in newEarnings) {
          batch.set(FirebaseRefs.earnedBadges(uid).doc(id),
              {'earned_at': FieldValue.serverTimestamp()});
        }
        await batch.commit();
      }

      return BadgesData.fromJson({
        'badges':         badges,
        'earned_count':   badges.where((b) => b['earned'] == true).length,
        'total_count':    badges.length,
        'current_streak': currentStreak,
        'longest_streak': longestStreak,
      });
    } catch (_) {
      return null;
    }
  }

  // ── Save Challenge Score ──────────────────────────────────────
  /// Saves only if it beats the user's existing best.
  /// Each user has one doc: challenge_scores/{uid}.
  Future<bool> saveScore({
    required int    score,
    required int    total,
    required double accuracy,
    required int    maxCombo,
    required String grade,
  }) async {
    try {
      final uid = FirebaseRefs.uid;
      if (uid == null) return false;

      final ref      = FirebaseRefs.challengeScores.doc(uid);
      final existing = await ref.get();
      final best     = existing.data()?['score'] as int?;
      if (best != null && score <= best) return true;  // Not a new best

      // Name + avatar are copied in so the leaderboard is one read
      final user = (await FirebaseRefs.userDoc(uid).get()).data() ?? {};
      await ref.set({
        'user_id':     uid,
        'name':        user['name'] ?? '',
        'avatar_type': user['avatar_type'] ?? 'initial',
        'avatar_data': user['avatar_data'],
        'score':       score,
        'total':       total,
        'accuracy':    accuracy,
        'max_combo':   maxCombo,
        'grade':       grade,
        'played_at':   Timestamp.now(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }


  // ── Get Leaderboard ───────────────────────────────────────────
  /// Top 20 by best score, the user's rank and personal best.
  /// [period] — 'weekly' (last 7 days) or anything else for all-time.
  Future<LeaderboardData?> getLeaderboard({
    String period = 'all-time',
  }) async {
    try {
      final uid = FirebaseRefs.uid;
      if (uid == null) return null;

      // One doc per player, so reading all of them stays small
      final snap = await FirebaseRefs.challengeScores.get();
      final totalPlayers = snap.docs.length;

      var rows = snap.docs.map((d) => d.data()).toList();
      if (period == 'weekly') {
        final cutoff = DateTime.now().subtract(const Duration(days: 7));
        rows = rows
            .where((r) => (r['played_at'] as Timestamp).toDate().isAfter(cutoff))
            .toList();
      }
      rows.sort((a, b) {
        final byScore = (b['score'] as int).compareTo(a['score'] as int);
        if (byScore != 0) return byScore;
        return (b['accuracy'] as num).compareTo(a['accuracy'] as num);
      });

      Map<String, dynamic> scoreJson(Map<String, dynamic> r) => {
        'score':     r['score'],
        'total':     r['total'],
        'accuracy':  ((r['accuracy'] as num).toDouble() * 10).round() / 10,
        'max_combo': r['max_combo'],
        'grade':     r['grade'],
        'played_at': _timestampString(r['played_at']),
      };

      final entries = <Map<String, dynamic>>[];
      for (var i = 0; i < rows.length && i < 20; i++) {
        final r = rows[i];
        entries.add({
          'rank':        i + 1,
          'user_id':     r['user_id'],
          'name':        r['name'],
          'avatar_type': r['avatar_type'],
          'avatar_data': r['avatar_data'],
          ...scoreJson(r),
        });
      }

      // ── User's rank + personal best ───────────────────────
      final mineIndex = rows.indexWhere((r) => r['user_id'] == uid);
      final mine      = mineIndex >= 0 ? rows[mineIndex] : null;
      final int? userRank;
      if (mine == null) {
        userRank = null;
      } else if (mineIndex < 20) {
        userRank = mineIndex + 1;      // Same order as the top-20 list
      } else {
        // Players with a strictly higher score, plus one
        userRank = rows.where((r) => (r['score'] as int) > (mine['score'] as int)).length + 1;
      }

      return LeaderboardData.fromJson({
        'entries':       entries,
        'user_rank':     userRank,
        'personal_best': mine == null ? null : scoreJson(mine),
        'total_players': totalPlayers,
      });
    } catch (_) {
      return null;
    }
  }


  // ── Notify only when a badge is NEWLY earned ─────────────
// Uses SharedPreferences to track which badges have already
// been notified — ensures each badge notification fires once.
  // ── Notify only when a badge is NEWLY earned ──────────────────
// Uses SharedPreferences to track which badges have already
// been notified — ensures each badge notification fires once.
  Future<void> checkBadgeProgress() async {
    try {
      final data = await getBadges();
      if (data == null) return;

      final prefs       = await SharedPreferences.getInstance();
      const notifiedKey = 'notified_badges';
      const seededKey   = 'badges_seeded';   // ← tracks if we've done first-run seed

      // ── First run seed ─────────────────────────────────────────
      // On first run, silently mark ALL currently earned badges as
      // already notified — prevents firing for pre-existing badges
      final hasSeeded = prefs.getBool(seededKey) ?? false;
      if (!hasSeeded) {
        final alreadyEarned = data.badges
            .where((b) => b.earned)
            .map((b) => b.id)
            .toSet();

        // Save all currently earned badges as already notified
        await prefs.setString(notifiedKey, alreadyEarned.join(','));

        // Mark seeding as done — this block never runs again
        await prefs.setBool(seededKey, true);
        return;   // Don't show any notification on this first check
      }

      // ── Normal flow — only runs after first-run seed ───────────
      // Get previously notified badge IDs
      final notified =
      (prefs.getString(notifiedKey) ?? '').split(',').toSet();

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
          break;   // One notification per scan max
        }
      }
    } catch (_) {}
  }


  // ── Helpers ───────────────────────────────────────────────────
  /// Every scan of the signed-in user, newest first.
  Future<List<Map<String, dynamic>>?> _allScans() async {
    final uid = FirebaseRefs.uid;
    if (uid == null) return null;
    final snap = await FirebaseRefs.scans(uid)
        .orderBy('scanned_at', descending: true)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  /// Local date as "2026-10-20" — the streak's day key.
  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// "2026-10-20 14:05:09" in local time, the format screens parse.
  static String _timestampString(Object? value) {
    if (value is! Timestamp) return '';
    final d = value.toDate();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${_dateKey(d)} ${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  String _friendlyError(Object e) {
    if (e is FormatException) return e.message;
    return 'An unexpected error occurred. Please try again.';
  }
}

// services/detection_service.dart
// ============================================================
// Handles all deepfake detection API calls:
//   - Uploading image for detection
//   - Fetching scan history
//   - Deleting scans
//   - Fetching stats
// ============================================================

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../utils/constants.dart';
import '../services/storage_service.dart';


// ── EXIF Analysis Model ───────────────────────────────────────────
class ExifAnalysis {
  final Map<String, dynamic> rawFields;
  final List<String> suspicionFlags;
  final String riskLevel;
  final String summary;
  final bool hasExif;

  const ExifAnalysis({
    required this.rawFields,
    required this.suspicionFlags,
    required this.riskLevel,
    required this.summary,
    required this.hasExif,
  });

  factory ExifAnalysis.fromJson(Map<String, dynamic> json) {
    return ExifAnalysis(
      rawFields:      Map<String, dynamic>.from(json['raw_fields'] as Map),
      suspicionFlags: List<String>.from(json['suspicion_flags'] as List),
      riskLevel:      json['risk_level'] as String,
      summary:        json['summary']    as String,
      hasExif:        json['has_exif']   as bool,
    );
  }
}


// ── Detection Result Model ────────────────────────────────────────
class DetectionResult {
  final String verdict;
  final double confidence;
  final double rawScore;
  final String message;
  final List<String> tips;
  final String explanation;    // LLM-generated human explanation
  final ExifAnalysis exifAnalysis;  // EXIF metadata analysis

  const DetectionResult({
    required this.verdict,
    required this.confidence,
    required this.rawScore,
    required this.message,
    required this.tips,
    required this.explanation,
    required this.exifAnalysis,
  });

  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    return DetectionResult(
      verdict:      json['verdict']     as String,
      confidence:   (json['confidence'] as num).toDouble(),
      rawScore:     (json['raw_score']  as num).toDouble(),
      message:      json['message']     as String,
      tips:         List<String>.from(json['tips'] as List),
      explanation:  json['explanation'] as String,
      exifAnalysis: ExifAnalysis.fromJson(
          json['exif_analysis'] as Map<String, dynamic>),
    );
  }

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

  factory ScanHistoryItem.fromJson(Map<String, dynamic> json) {
    return ScanHistoryItem(
      id:         json['id']         as int,
      imageName:  json['image_name'] as String,
      verdict:    json['verdict']    as String,
      confidence: (json['confidence'] as num).toDouble(),
      scannedAt:  json['scanned_at'] as String,
    );
  }

  bool get isFake => verdict == 'FAKE';
}


// ── Detection Response Wrapper ────────────────────────────────────
class DetectionResponse {
  final bool success;
  final String message;
  final DetectionResult? result;

  const DetectionResponse({
    required this.success,
    required this.message,
    this.result,
  });
}


// ── Scan Stats Model ──────────────────────────────────────────────
class ScanStats {
  final int    totalScans;
  final int    totalReal;
  final int    totalFake;
  final String? lastScanned;

  const ScanStats({
    required this.totalScans,
    required this.totalReal,
    required this.totalFake,
    this.lastScanned,
  });

  factory ScanStats.fromJson(Map<String, dynamic> json) {
    return ScanStats(
      totalScans:  json['total_scans'] as int,
      totalReal:   json['total_real']  as int,
      totalFake:   json['total_fake']  as int,
      lastScanned: json['last_scanned'] as String?,
    );
  }

  /// Percentage of fake scans
  double get fakePercent =>
      totalScans == 0 ? 0 : (totalFake / totalScans) * 100;
}


// ── Detection Service ─────────────────────────────────────────────
class DetectionService {

  // ── Detect Image ──────────────────────────────────────────────
  /// Uploads image to backend and returns full rich detection result.
  Future<DetectionResponse> detectImage(File imageFile) async {
    try {
      final savedUser = await StorageService.getSavedUser();
      if (savedUser == null) {
        return const DetectionResponse(
          success: false,
          message: 'Not logged in',
        );
      }

      // Determine MIME type from file extension
      final ext      = imageFile.path.split('.').last.toLowerCase();
      final mimeType = _getMimeType(ext);

      // Create multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(AppConstants.detectEndpoint),
      );

      // Add authorization header
      request.headers['Authorization'] = 'Bearer ${savedUser.token}';

      // Attach image with explicit MIME type
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          contentType: MediaType('image', mimeType),
        ),
      );

      // Send with timeout
      final streamedResponse = await request
          .send()
          .timeout(AppConstants.requestTimeout);

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
      return DetectionResponse(
        success: false,
        message: _friendlyError(e),
      );
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
    } catch (e) {
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
    } catch (e) {
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
    } catch (e) {
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
    } catch (e) {
      return null;
    }
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
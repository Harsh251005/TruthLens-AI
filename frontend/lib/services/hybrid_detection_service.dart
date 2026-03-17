import 'dart:io';
import 'package:flutter/foundation.dart';
import 'detection_service.dart';
import 'local_detection_service.dart';

class HybridDetectionService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  HybridDetectionService._internal();
  static final HybridDetectionService _instance = HybridDetectionService._internal();
  factory HybridDetectionService() => _instance;

  final DetectionService      _serverService = DetectionService();
  final LocalDetectionService _localService  = LocalDetectionService();

  /// Scan an image — server first, on-device fallback.
  ///
  /// Server path:  full result with EXIF + LLM explanation
  /// Fallback path: on-device TFLite with unavailable EXIF notice
  Future<DetectionResponse> detect(File imageFile) async {
    // ── Attempt 1: Server ──────────────────────────────────────────────────
    debugPrint('[Hybrid] Trying server-based detection...');
    final serverResponse = await _serverService.detectImage(imageFile);

    // Server succeeded — return full result with EXIF
    if (serverResponse.success) {
      debugPrint('[Hybrid] Server detection succeeded.');
      return serverResponse;
    }

    // Server returned a user-facing error (e.g. no face detected, bad image)
    // Do NOT fall back — this is a content error, not a network error
    if (_isContentError(serverResponse.message)) {
      debugPrint('[Hybrid] Server returned content error — not falling back.');
      return serverResponse;
    }

    // ── Attempt 2: On-device fallback ──────────────────────────────────────
    debugPrint('[Hybrid] Server unreachable — falling back to on-device.');
    final localResponse = await _localService.detect(imageFile);

    // Add a notice to the message so the user knows which mode was used
    if (localResponse.success) {
      return DetectionResponse(
        success: true,
        message: 'Scanned on-device (server unreachable)',
        result:  localResponse.result,
      );
    }

    // Both failed — return the local error message (more specific)
    return localResponse;
  }

  /// Returns true if the error is about the image content (face, format)
  /// rather than a network/server failure.
  bool _isContentError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('no human face') ||
        lower.contains('no face')          ||
        lower.contains('face detected')    ||
        lower.contains('invalid image')    ||
        lower.contains('not logged in');
  }
}
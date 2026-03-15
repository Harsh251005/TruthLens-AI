/// local_detection_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'detection_service.dart';
import 'on_device_face_detector.dart';
import 'tflite_model_service.dart';

// Thrown for user-facing errors (no face, unreadable image)
class DetectionException implements Exception {
  final String message;
  const DetectionException(this.message);
  @override
  String toString() => message;
}

class LocalDetectionService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  LocalDetectionService._internal();
  static final LocalDetectionService _instance = LocalDetectionService._internal();
  factory LocalDetectionService() => _instance;

  final TfliteModelService   _modelService = TfliteModelService();
  final OnDeviceFaceDetector _faceDetector = OnDeviceFaceDetector();

  // Call once in main() before runApp()
  Future<void> initialize() async {
    debugPrint('[LocalDetection] Initializing...');
    await _modelService.initialize();
    debugPrint('[LocalDetection] Ready.');
  }

  // Returns same DetectionResponse as DetectionService — fully interchangeable
  Future<DetectionResponse> detect(File imageFile) async {
    try {
      final Uint8List imageBytes = await _loadImageBytes(imageFile);
      await _requireFace(imageBytes);
      final double rawScore = await _modelService.runInference(imageBytes);
      return DetectionResponse(
        success: true,
        message: 'Detection successful (on-device)',
        result:  _buildResult(rawScore),
      );
    } on DetectionException catch (e) {
      return DetectionResponse(success: false, message: e.message);
    } catch (e) {
      return DetectionResponse(
        success: false,
        message: 'On-device detection failed. Please try again.',
      );
    }
  }

  Future<Uint8List> _loadImageBytes(File imageFile) async {
    try {
      return await imageFile.readAsBytes();
    } catch (_) {
      throw const DetectionException(
        'Could not read the selected image. Please try a different file.',
      );
    }
  }

  Future<void> _requireFace(Uint8List imageBytes) async {
    bool hasFace;
    try {
      hasFace = await _faceDetector.containsFace(imageBytes);
    } catch (e) {
      debugPrint('[LocalDetection] Face detection error, proceeding: $e');
      return;
    }
    if (!hasFace) {
      throw const DetectionException(
        'No human face detected. Please upload a clear face photo.',
      );
    }
  }

  DetectionResult _buildResult(double rawScore) {
    final bool   isFake     = rawScore > TfliteModelService.fakeThreshold;
    final String verdict    = isFake ? 'FAKE' : 'REAL';
    final double confidence = double.parse(
      (isFake ? rawScore * 100 : (1.0 - rawScore) * 100).toStringAsFixed(2),
    );
    return DetectionResult(
      verdict:     verdict,
      confidence:  confidence,
      rawScore:    double.parse(rawScore.toStringAsFixed(4)),
      message:     isFake
          ? 'This image appears to be AI-generated. Model is $confidence% confident.'
          : 'This image appears authentic. Model is $confidence% confident.',
      tips:        isFake ? _fakeTips : _realTips,
      explanation: _buildExplanation(verdict, confidence, rawScore),
      // EXIF is server-only — graceful unavailable notice shown in UI
      exifAnalysis: const ExifAnalysis(
        rawFields:      {},
        suspicionFlags: ['EXIF analysis is only available with server scanning.'],
        riskLevel:      'UNKNOWN',
        summary:        'EXIF analysis unavailable in on-device mode.',
        hasExif:        false,
      ),
    );
  }

  String _buildExplanation(String verdict, double confidence, double rawScore) {
    final String level = confidence >= 90 ? 'very high'
        : confidence >= 75 ? 'high'
        : confidence >= 60 ? 'moderate' : 'low';
    if (verdict == 'FAKE') {
      return 'The on-device AI model analyzed facial features and texture patterns '
          'and determined this image is likely AI-generated. Confidence: $level '
          '($confidence%, raw score: ${rawScore.toStringAsFixed(4)}).';
    }
    return 'The on-device AI model analyzed facial features and texture patterns '
        'and determined this image is likely authentic. Confidence: $level '
        '($confidence%, raw score: ${rawScore.toStringAsFixed(4)}).';
  }

  static const List<String> _fakeTips = [
    'Look for unnatural blurring around face edges',
    'Check for inconsistent lighting or shadows',
    'Look for asymmetry in facial features',
    'Examine the hair and teeth for artifacts',
    'Be cautious sharing or trusting this image',
  ];

  static const List<String> _realTips = [
    'Natural skin texture and pores are visible',
    'Lighting and shadows appear consistent',
    'Facial features appear symmetrical and natural',
    'No visible artifacts or blurring detected',
    'Always verify from original trusted sources',
  ];

  Future<void> dispose() async {
    _modelService.dispose();
    await _faceDetector.dispose();
  }
}
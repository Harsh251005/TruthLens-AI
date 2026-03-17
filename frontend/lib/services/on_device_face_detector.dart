import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';

class OnDeviceFaceDetector {
  // ── Singleton ──────────────────────────────────────────────────────────────

  OnDeviceFaceDetector._internal();
  static final OnDeviceFaceDetector _instance = OnDeviceFaceDetector._internal();
  factory OnDeviceFaceDetector() => _instance;

  // ── ML Kit Face Detector ───────────────────────────────────────────────────

  /// Fast mode is sufficient — we only need to know if a face exists,
  /// not landmarks or classifications.
  late final FaceDetector _detector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableContours:   false, // Not needed for presence check
      enableLandmarks:  false,
      enableClassification: false,
    ),
  );

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns true if at least one human face is detected in the image.
  ///
  /// [imageBytes] — raw bytes of the image (JPEG or PNG).
  ///
  /// ML Kit works with file-based InputImage. We write the bytes to a temp
  /// file, run detection, then delete the temp file.
  ///
  /// Throws [FaceDetectionException] if detection fails unexpectedly.
  Future<bool> containsFace(Uint8List imageBytes) async {
    File? tempFile;
    try {
      // ── Write bytes to temp file (ML Kit requires file path) ────────────
      tempFile = await _writeTempFile(imageBytes);

      // ── Build ML Kit InputImage from file ────────────────────────────────
      final inputImage = InputImage.fromFile(tempFile);

      // ── Run face detection ────────────────────────────────────────────────
      final faces = await _detector.processImage(inputImage);

      debugPrint('[FaceDetector] Faces detected: ${faces.length}');
      return faces.isNotEmpty;

    } catch (e, stack) {
      debugPrint('[FaceDetector] Error during face detection: $e\n$stack');
      // Re-throw as a typed exception so callers can handle it specifically
      throw FaceDetectionException(
        'Face detection failed: ${e.toString()}',
        originalError: e,
      );
    } finally {
      // Always clean up the temp file, even on error
      await _deleteTempFile(tempFile);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Write image bytes to a uniquely named temp file.
  Future<File> _writeTempFile(Uint8List imageBytes) async {
    final tempDir  = await getTemporaryDirectory();
    final filename = 'tl_face_check_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final tempFile = File('${tempDir.path}/$filename');
    await tempFile.writeAsBytes(imageBytes, flush: true);
    return tempFile;
  }

  /// Delete a temp file silently.
  Future<void> _deleteTempFile(File? file) async {
    try {
      if (file != null && await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore cleanup errors — they don't affect the detection result
    }
  }

  // ── Cleanup ────────────────────────────────────────────────────────────────

  /// Release ML Kit detector resources.
  Future<void> dispose() async {
    await _detector.close();
    debugPrint('[FaceDetector] Detector closed.');
  }
}

// ─── Custom Exception ─────────────────────────────────────────────────────────

/// Thrown when face detection encounters an unexpected error.
/// Distinct from a "no face found" result (which returns false, not an exception).
class FaceDetectionException implements Exception {
  final String message;
  final Object? originalError;

  const FaceDetectionException(this.message, {this.originalError});

  @override
  String toString() => 'FaceDetectionException: $message';
}
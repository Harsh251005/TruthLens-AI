// services/detector_service.dart
// ============================================================
// On-device port of backend/services/detector.py.
//   1. Face check   (ML Kit, replaces OpenCV Haar cascade)
//   2. TFLite inference
//   3. EXIF analysis
//   4. Explanation  (OpenAI, with built-in fallback)
//
// The model file is NOT in git (see .gitignore). Place
// deepfake_detector_fp16.tflite in frontend/assets/models/
// before building.
// ============================================================

import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'exif_service.dart';
import 'explanation_service.dart';

/// Thrown when no face is found — screens show [message] as-is.
class NoFaceException implements Exception {
  final String message;
  const NoFaceException(this.message);
}

/// Thrown when the model asset is missing from the build.
class ModelMissingException implements Exception {
  const ModelMissingException();
}

class DetectorService {

  // ── Constants ─────────────────────────────────────────────────
  static const _imageSize     = 224;   // Must match training config exactly
  static const _fakeThreshold = 0.5;   // Raw score > 0.5 → FAKE
  static const _modelAsset    = 'assets/models/deepfake_detector_fp16.tflite';

  static Interpreter?        _interpreter;
  static IsolateInterpreter? _isolate;

  /// Loads the model once; later calls reuse it.
  static Future<IsolateInterpreter> _model() async {
    if (_isolate != null) return _isolate!;
    try {
      _interpreter = await Interpreter.fromAsset(_modelAsset);
    } catch (_) {
      throw const ModelMissingException();
    }
    // Run inference off the UI thread so the scan animation stays smooth
    _isolate = await IsolateInterpreter.create(address: _interpreter!.address);
    return _isolate!;
  }

  // ── Face Detection ────────────────────────────────────────────
  static Future<bool> _hasFace(File file) async {
    final detector = FaceDetector(
      options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
    );
    try {
      final faces = await detector.processImage(InputImage.fromFilePath(file.path));
      return faces.isNotEmpty;
    } finally {
      await detector.close();
    }
  }

  // ── Preprocessing ─────────────────────────────────────────────
  /// Resize to 224x224 and return raw float32 RGB pixel values.
  ///
  /// CRITICAL: No /255 normalization.
  /// EfficientNetB0 has built-in Rescaling — expects raw [0, 255] input.
  /// Dividing by 255 causes the model to always predict REAL.
  static List<List<List<List<double>>>> _preprocess(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Could not read this image.');
    }
    // Pillow's resize() defaults to bicubic
    final resized = img.copyResize(
      decoded,
      width:         _imageSize,
      height:        _imageSize,
      interpolation: img.Interpolation.cubic,
    );
    return [
      List.generate(_imageSize, (y) =>
        List.generate(_imageSize, (x) {
          final p = resized.getPixel(x, y);
          return [p.r.toDouble(), p.g.toDouble(), p.b.toDouble()];
        }),
      ),
    ];
  }

  // ── Main Predict ──────────────────────────────────────────────
  /// Returns the same JSON shape the backend's predict() returned.
  static Future<Map<String, dynamic>> predict(File file) async {
    // ── Step 1: Face check ──────────────────────────────────────
    if (!await _hasFace(file)) {
      throw const NoFaceException(
          'No human face detected. Please upload a clear face photo.');
    }

    // ── Step 2: Model inference ─────────────────────────────────
    final bytes  = await file.readAsBytes();
    final model  = await _model();
    final input  = _preprocess(bytes);
    final output = [
      [0.0],
    ];
    await model.run(input, output);
    final rawScore = output[0][0];

    final isFake     = rawScore > _fakeThreshold;
    final verdict    = isFake ? 'FAKE' : 'REAL';
    final confidence = _round2(isFake ? rawScore * 100 : (1 - rawScore) * 100);

    // ── Step 3: EXIF analysis ───────────────────────────────────
    final exif = await ExifService.analyze(bytes);

    // ── Step 4: Explanation ─────────────────────────────────────
    final explanation = await ExplanationService.generate(
      verdict:    verdict,
      confidence: confidence,
      rawScore:   rawScore,
      exifFlags:  List<String>.from(exif['suspicion_flags'] as List),
      exifRisk:   exif['risk_level'] as String,
    );

    // ── Step 5: Tips ────────────────────────────────────────────
    final String       message;
    final List<String> tips;
    if (isFake) {
      message = 'This image appears to be AI-generated. Model is $confidence% confident.';
      tips = const [
        'Look for unnatural blurring around face edges',
        'Check for inconsistent lighting or shadows',
        'Look for asymmetry in facial features',
        'Examine the hair and teeth for artifacts',
        'Be cautious sharing or trusting this image',
      ];
    } else {
      message = 'This image appears authentic. Model is $confidence% confident.';
      tips = const [
        'Natural skin texture and pores are visible',
        'Lighting and shadows appear consistent',
        'Facial features appear symmetrical and natural',
        'No visible artifacts or blurring detected',
        'Always verify from original trusted sources',
      ];
    }

    return {
      'verdict':       verdict,
      'confidence':    confidence,
      'raw_score':     (rawScore * 10000).round() / 10000,
      'message':       message,
      'tips':          tips,
      'explanation':   explanation,
      'exif_analysis': exif,
    };
  }

  static double _round2(double v) => (v * 100).round() / 100;
}

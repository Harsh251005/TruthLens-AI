import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class TfliteModelService {
  // ── Singleton ──────────────────────────────────────────────────────────────

  TfliteModelService._internal();
  static final TfliteModelService _instance = TfliteModelService._internal();
  factory TfliteModelService() => _instance;

  // ── Constants ──────────────────────────────────────────────────────────────

  /// Asset path — must match pubspec.yaml flutter.assets entry
  static const String _modelAssetPath = 'assets/models/deepfake_detector.tflite';

  /// Must match training config: cfg.IMG_SIZE = 224
  static const int _inputSize = 224;

  /// FAKE threshold: raw_score > 0.5 → FAKE (matches detector.py)
  static const double fakeThreshold = 0.5;

  // ── State ──────────────────────────────────────────────────────────────────

  Interpreter? _interpreter;
  bool get isLoaded => _interpreter != null;

  // ── Initialization ─────────────────────────────────────────────────────────

  /// Load the TFLite model from assets. Call once at app startup (e.g., in main).
  /// Subsequent calls are no-ops if already loaded.
  Future<void> initialize() async {
    if (_interpreter != null) return; // Already loaded

    debugPrint('[TFLite] Loading model from assets: $_modelAssetPath');

    final options = InterpreterOptions()
      ..threads = 2; // Use 2 threads for inference on device

    _interpreter = await Interpreter.fromAsset(
      _modelAssetPath,
      options: options,
    );

    // Validate shapes at startup to catch asset/model mismatches early
    _validateInterpreterShapes();

    debugPrint('[TFLite] Model loaded successfully.');
  }

  /// Verify input/output tensor shapes match what the model was trained with.
  void _validateInterpreterShapes() {
    final inputShape  = _interpreter!.getInputTensor(0).shape;
    final outputShape = _interpreter!.getOutputTensor(0).shape;

    debugPrint('[TFLite] Input  tensor shape : $inputShape');
    debugPrint('[TFLite] Output tensor shape : $outputShape');

    // Expected: [1, 224, 224, 3]
    assert(
    inputShape.length == 4 &&
        inputShape[1] == _inputSize &&
        inputShape[2] == _inputSize &&
        inputShape[3] == 3,
    '[TFLite] Unexpected input shape $inputShape. Expected [1, $_inputSize, $_inputSize, 3].',
    );

    // Expected: [1, 1]
    assert(
    outputShape.length == 2 && outputShape[1] == 1,
    '[TFLite] Unexpected output shape $outputShape. Expected [1, 1].',
    );
  }

  // ── Preprocessing ──────────────────────────────────────────────────────────

  /// Resize image to 224×224 and extract pixel values as Float32.
  ///
  /// CRITICAL: Returns raw [0, 255] values — NOT divided by 255.
  /// EfficientNetB0's internal Rescaling layer handles normalization.
  ///
  /// Returns a flat Float32List of length 1 × 224 × 224 × 3 = 150,528 values,
  /// arranged as [batch][height][width][channel] in row-major order.
  Float32List _preprocessImage(img.Image image) {
    // Step 1: Resize to model input size
    final resized = img.copyResize(
      image,
      width:  _inputSize,
      height: _inputSize,
      interpolation: img.Interpolation.linear, // Matches PIL's default
    );

    // Step 2: Allocate flat buffer — shape (1, 224, 224, 3)
    final buffer = Float32List(_inputSize * _inputSize * 3);
    int offset = 0;

    // Step 3: Extract RGB channels in row-major order
    // CRITICAL: Use .toDouble() only — NO /255.0 normalization
    for (int y = 0; y < _inputSize; y++) {
      for (int x = 0; x < _inputSize; x++) {
        final pixel = resized.getPixel(x, y);

        // Raw [0, 255] float32 — matches preprocess_image() in detector.py
        buffer[offset++] = pixel.r.toDouble(); // Red
        buffer[offset++] = pixel.g.toDouble(); // Green
        buffer[offset++] = pixel.b.toDouble(); // Blue
      }
    }

    return buffer;
  }

  // ── Inference ──────────────────────────────────────────────────────────────

  /// Run deepfake detection on a decoded image.
  ///
  /// Returns the raw sigmoid score in [0.0, 1.0]:
  ///   - score > 0.5  → FAKE
  ///   - score ≤ 0.5  → REAL
  ///
  /// Throws [StateError] if the model has not been initialized.
  /// Throws [ArgumentError] if the image cannot be decoded.
  Future<double> runInference(Uint8List imageBytes) async {
    if (_interpreter == null) {
      throw StateError(
        '[TFLite] Model not initialized. Call initialize() before runInference().',
      );
    }

    // ── Decode image ────────────────────────────────────────────────────────
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      throw ArgumentError('[TFLite] Failed to decode image bytes.');
    }

    // Convert to RGB (drop alpha channel if present, e.g. PNG)
    final rgbImage = image.numChannels == 3 ? image : img.copyResize(
      img.Image.from(image),
      width: image.width,
      height: image.height,
    );

    // ── Preprocess ──────────────────────────────────────────────────────────
    final inputBuffer = _preprocessImage(rgbImage);

    // Reshape into [1, 224, 224, 3] as a nested List (required by tflite_flutter)
    // The outer structure is: List<List<List<List<double>>>>
    final input = _bufferToNestedList(inputBuffer);

    // ── Output buffer ────────────────────────────────────────────────────────
    // Shape [1, 1] — one batch, one sigmoid output
    final output = List.generate(1, (_) => List.filled(1, 0.0));

    // ── Run model ────────────────────────────────────────────────────────────
    _interpreter!.run(input, output);

    final rawScore = output[0][0];
    debugPrint('[TFLite] Raw sigmoid score: ${rawScore.toStringAsFixed(6)}');

    return rawScore;
  }

  List<List<List<List<double>>>> _bufferToNestedList(Float32List buffer) {
    const h = _inputSize;
    const w = _inputSize;
    const c = 3;

    return List.generate(
      1,
          (_) => List.generate(
        h,
            (y) => List.generate(
          w,
              (x) => List.generate(
            c,
                (ch) => buffer[(y * w + x) * c + ch].toDouble(),
          ),
        ),
      ),
    );
  }

  // ── Cleanup ────────────────────────────────────────────────────────────────

  /// Release interpreter resources. Call when the app is closing.
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    debugPrint('[TFLite] Interpreter disposed.');
  }
}
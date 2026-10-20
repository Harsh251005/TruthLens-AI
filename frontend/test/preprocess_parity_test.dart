// Compares on-device preprocessing with the backend's Pillow output.
//
// Run: PARITY_DIR=<dir> flutter test test/preprocess_parity_test.dart
// <dir> holds imgs.txt (space-separated image paths) and py_out/<name>.f32
// written by Pillow's Image.open(...).convert("RGB").resize((224, 224)).
// Use images without an EXIF rotation tag: the app turns those upright,
// the backend did not. Skipped when PARITY_DIR is unset.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/detector_service.dart';

void main() {
  final dir = Platform.environment['PARITY_DIR'];

  testWidgets('preprocessing matches Pillow', (tester) async {
    await tester.runAsync(() async {
      final paths = File('$dir/imgs.txt').readAsStringSync().trim().split(RegExp(r'\s+'));
      for (final path in paths) {
        final name     = path.split('/').last;
        final expected = File('$dir/py_out/$name.f32').readAsBytesSync().buffer.asFloat32List();
        final actual   = await DetectorService.preprocessPixels(File(path).readAsBytesSync());

        var maxDiff = 0.0;
        for (var i = 0; i < expected.length; i++) {
          final d = (expected[i] - actual[i]).abs();
          if (d > maxDiff) maxDiff = d;
        }
        // ignore: avoid_print
        print('$name  max diff ${maxDiff.toStringAsFixed(1)}');
        expect(maxDiff, 0, reason: name);
      }
    });
  }, skip: dir == null);
}

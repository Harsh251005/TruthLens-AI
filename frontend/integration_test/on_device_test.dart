// On-device checks for the detection pipeline (needs a phone or emulator):
//   flutter test integration_test/on_device_test.dart -d <device>
//
// 1. JPEG decoding + resize on the device reproduce the backend's Pillow
//    tensors exactly (checksums from Pillow 12.1.1, the backend's version).
// 2. The ML Kit face check finds a face in a real challenge photo and
//    rejects an image without one.
// 3. With no model bundled, a face photo reaches the model step and fails
//    with ModelMissingException; with the model, it returns a verdict.

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/detector_service.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

// image → (sum of values, sum of value × (index % 997)) of Pillow's
// Image.open(...).convert("RGB").resize((224, 224)) as float32.
const _pillowChecksums = <String, (int, int)>{
  'assets/challenge/real/64145.jpg': (18452937, 9208685257),
  'assets/challenge/real/64150.jpg': (17005874, 8463447589),
  'assets/challenge/real/64158.jpg': (14079832, 7019552045),
  'assets/challenge/real/64165.jpg': (26015524, 12933784365),
  'assets/challenge/real/64167.jpg': (8495819, 4237415697),
  'assets/challenge/fake/WTH2AAK5MN.jpg': (18663474, 9249324027),
  'assets/challenge/fake/WTHF12NGVA.jpg': (9885518, 4923849758),
  'assets/challenge/fake/WTHX12BZ0I.jpg': (16268274, 8089923580),
  'assets/challenge/fake/WTK4BE0ZRN.jpg': (21254112, 10586295975),
  'assets/challenge/fake/WTRBY98FUH.jpg': (15026693, 7500339173),
};

Future<File> _assetToFile(String asset) async {
  final data = await rootBundle.load(asset);
  final dir  = await getTemporaryDirectory();
  final file = File('${dir.path}/${asset.split('/').last}');
  await file.writeAsBytes(data.buffer.asUint8List());
  return file;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('preprocessing matches Pillow on the device', (tester) async {
    expect(_pillowChecksums, isNotEmpty);
    for (final entry in _pillowChecksums.entries) {
      final bytes = (await rootBundle.load(entry.key)).buffer.asUint8List();
      final px    = await DetectorService.preprocessPixels(bytes);
      var sum = 0, weighted = 0;
      for (var i = 0; i < px.length; i++) {
        final v = px[i].toInt();
        sum      += v;
        weighted += v * (i % 997);
      }
      expect((sum, weighted), entry.value, reason: entry.key);
    }
  });

  testWidgets('face photo passes the face check', (tester) async {
    final file = await _assetToFile(_pillowChecksums.keys.first);
    try {
      final result = await DetectorService.predict(file);
      expect(result['verdict'], anyOf('REAL', 'FAKE'));   // model bundled
    } on ModelMissingException {
      // Face found; only the model file is missing from this build.
    }
  });

  testWidgets('image without a face is rejected', (tester) async {
    final file = await _assetToFile('assets/images/app_icon.png');
    await expectLater(
      DetectorService.predict(file),
      throwsA(isA<NoFaceException>()),
    );
  });
}

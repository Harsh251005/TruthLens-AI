// services/exif_service.dart
// ============================================================
// On-device port of backend/services/exif_service.py.
// Extracts readable EXIF fields and flags suspicious patterns.
//
// AI-generated images typically:
//   - Have no EXIF data at all
//   - Show software like Stable Diffusion, DALL-E, Midjourney
//   - Have mismatched creation/modification timestamps
//   - Lack GPS or camera hardware info
// ============================================================

import 'dart:typed_data';
import 'package:exif/exif.dart';
import 'package:image/image.dart' as img;

class ExifService {

  // ── Known AI generation / editing software signatures ──────────
  static const _aiSoftwareSignatures = [
    'stable diffusion', 'midjourney', 'dall-e', 'dalle',
    'firefly', 'generative', 'ai generated', 'deepfake',
    'faceswap', 'reface', 'facefusion', 'simswap',
    'adobe photoshop', 'meitu', 'facetune', 'lightroom',
    'snapseed', 'vsco', 'afterlight',
  ];

  // ── EXIF fields to skip — binary/unintelligible for users ──────
  static const _skipTags = {
    'MakerNote', 'UserComment', 'PrintImageMatching',
    'JPEGThumbnail', 'ThumbnailImage', 'ComponentsConfiguration',
    'FileSource', 'SceneType', 'CFAPattern', 'DeviceSettingDescription',
    'ExifOffset', 'GPSInfo', 'ExifInteroperabilityOffset',
  };

  // ── Field label mapping ─────────────────────────────────────────
  static const _labelMap = {
    'Make':             'Camera Make',
    'Model':            'Camera Model',
    'LensModel':        'Lens Model',
    'Software':         'Software',
    'DateTime':         'Date Modified',
    'DateTimeOriginal': 'Date Taken',
    'ImageWidth':       'Width',
    'ImageLength':      'Height',
    'ExifImageWidth':   'Width',
    'ExifImageLength':  'Height',
    'ExposureTime':     'Exposure Time',
    'FNumber':          'F-Number',
    'ISOSpeedRatings':  'ISO Speed',
    'Flash':            'Flash',
    'FocalLength':      'Focal Length',
    'WhiteBalance':     'White Balance',
    'Artist':           'Artist',
    'Copyright':        'Copyright',
  };

  /// Returns the same shape the backend returned:
  /// raw_fields, suspicion_flags, risk_level, summary, has_exif.
  static Future<Map<String, dynamic>> analyze(Uint8List bytes) async {
    try {
      final exif = await _extractAllExif(bytes);

      if (exif.isEmpty) {
        // PNG or RGBA = almost certainly a screenshot or web image.
        // These never have EXIF — treat differently from a stripped JPEG.
        if (_isLikelyScreenshot(bytes)) {
          return {
            'raw_fields':      <String, dynamic>{},
            'suspicion_flags': <String>[],
            'risk_level':      'LOW',
            'summary': 'This appears to be a screenshot or web image. '
                "These don't contain camera metadata, which is completely normal. "
                'EXIF analysis is not applicable here.',
            'has_exif': false,
          };
        }
        // JPEG with no EXIF — more genuinely worth flagging
        return {
          'raw_fields':      <String, dynamic>{},
          'suspicion_flags': <String>[
            'No camera metadata found — unusual for a real JPEG photo',
          ],
          'risk_level': 'MEDIUM',
          'summary': 'This JPEG has no camera metadata, which is unusual for a '
              'photo taken on a phone or camera. It may have been '
              'downloaded, heavily edited, or AI-generated.',
          'has_exif': false,
        };
      }

      final flags = <String>[];

      // ── 1. Software check ───────────────────────────────────────
      final software = exif['Software'] ?? '';
      if (software.isNotEmpty) {
        final lower = software.toLowerCase();
        if (_aiSoftwareSignatures.any(lower.contains)) {
          flags.add("Processed with '$software' — known AI/editing tool");
        }
      }

      // ── 2. Camera hardware check ────────────────────────────────
      if ((exif['Camera Make'] ?? '').isEmpty &&
          (exif['Camera Model'] ?? '').isEmpty) {
        flags.add('No camera make/model — real photos usually have this');
      }

      // ── 3. Timestamp inconsistency check ────────────────────────
      final taken    = _parseExifDate(exif['Date Taken']);
      final modified = _parseExifDate(exif['Date Modified']);
      if (taken != null && modified != null &&
          modified.difference(taken).inSeconds.abs() > 86400) {
        flags.add('Timestamps inconsistent — modified long after capture');
      }

      final risk = _calculateRisk(flags);
      return {
        'raw_fields':      exif,
        'suspicion_flags': flags,
        'risk_level':      risk,
        'summary':         _buildSummary(exif, flags, risk),
        'has_exif':        true,
      };
    } catch (e) {
      return {
        'raw_fields':      <String, dynamic>{},
        'suspicion_flags': <String>['Could not read EXIF data: $e'],
        'risk_level':      'UNKNOWN',
        'summary':         'EXIF analysis could not be completed.',
        'has_exif':        false,
      };
    }
  }

  // ── Extraction ──────────────────────────────────────────────────
  static Future<Map<String, String>> _extractAllExif(Uint8List bytes) async {
    final tags   = await readExifFromBytes(bytes, details: false);
    final result = <String, String>{};
    final gps    = <String, IfdTag>{};

    for (final entry in tags.entries) {
      // Keys look like "Image Make", "EXIF FNumber", "GPS GPSLatitude"
      final space = entry.key.indexOf(' ');
      if (space < 0) continue;
      final group = entry.key.substring(0, space);
      final name  = entry.key.substring(space + 1);

      if (group == 'GPS') {
        gps[name] = entry.value;
        continue;
      }
      if (group != 'Image' && group != 'EXIF') continue;
      if (_skipTags.contains(name)) continue;

      final value = _formatValue(name, entry.value);
      if (value == null) continue;
      result[_labelMap[name] ?? name] = value;
    }

    result.addAll(_parseGps(gps));
    return result;
  }

  static String? _formatValue(String name, IfdTag tag) {
    String value = tag.printable.trim();
    try {
      final values = tag.values;
      switch (name) {
        case 'Flash':
          value = values.firstAsInt() & 1 == 1 ? 'Used' : 'Not used';
        case 'WhiteBalance':
          value = values.firstAsInt() == 0 ? 'Auto' : 'Manual';
        case 'ExposureTime':
          if (values is IfdRatios && values.ratios.isNotEmpty) {
            final r = values.ratios.first;
            if (r.numerator != 0) {
              value = r.numerator == 1
                  ? '1/${r.denominator ~/ r.numerator}s'
                  : '${r.numerator}/${r.denominator}s';
            }
          }
        case 'FNumber':
        case 'ApertureValue':
          final d = _ratioToDouble(values);
          if (d != null) value = 'f/${d.toStringAsFixed(1)}';
        case 'FocalLength':
          final d = _ratioToDouble(values);
          if (d != null) value = '${d.toStringAsFixed(1)} mm';
        case 'XResolution':
        case 'YResolution':
          final d = _ratioToDouble(values);
          if (d != null) value = '${d.toInt()} dpi';
      }
    } catch (_) {
      // Keep the printable value if formatting fails
    }
    // Skip empty, zero and binary-looking values
    if (value.isEmpty || value == '0' || value.startsWith('[')) return null;
    return value;
  }

  static double? _ratioToDouble(IfdValues values) {
    if (values is! IfdRatios || values.ratios.isEmpty) return null;
    final r = values.ratios.first;
    return r.denominator == 0 ? null : r.numerator / r.denominator;
  }

  // ── GPS ─────────────────────────────────────────────────────────
  static Map<String, String> _parseGps(Map<String, IfdTag> gps) {
    final fields = <String, String>{};
    if (gps.isEmpty) return fields;
    try {
      final lat = _dmsToDecimal(gps['GPSLatitude']);
      if (lat != null) {
        final south = gps['GPSLatitudeRef']?.printable.trim() == 'S';
        fields['GPS Latitude'] = '${(south ? -lat : lat).toStringAsFixed(6)}°';
      }
      final lon = _dmsToDecimal(gps['GPSLongitude']);
      if (lon != null) {
        final west = gps['GPSLongitudeRef']?.printable.trim() == 'W';
        fields['GPS Longitude'] = '${(west ? -lon : lon).toStringAsFixed(6)}°';
      }
      final altTag = gps['GPSAltitude'];
      if (altTag != null) {
        final alt = _ratioToDouble(altTag.values);
        if (alt != null) fields['GPS Altitude'] = '${alt.toStringAsFixed(1)} m';
      }
      final ts = gps['GPSTimeStamp']?.values;
      if (ts is IfdRatios && ts.ratios.length == 3) {
        String two(Ratio r) =>
            (r.denominator == 0 ? 0 : r.numerator ~/ r.denominator)
                .toString().padLeft(2, '0');
        fields['GPS Timestamp'] =
            '${two(ts.ratios[0])}:${two(ts.ratios[1])}:${two(ts.ratios[2])} UTC';
      }
      final date = gps['GPSDate']?.printable.trim();
      if (date != null && date.isNotEmpty) fields['GPS Date'] = date;

      if (fields.isNotEmpty) fields['GPS'] = 'Present';
    } catch (_) {
      fields['GPS'] = 'Present (could not parse)';
    }
    return fields;
  }

  static double? _dmsToDecimal(IfdTag? tag) {
    final values = tag?.values;
    if (values is! IfdRatios || values.ratios.length != 3) return null;
    double f(Ratio r) => r.denominator == 0 ? 0 : r.numerator / r.denominator;
    return f(values.ratios[0]) + f(values.ratios[1]) / 60 + f(values.ratios[2]) / 3600;
  }

  // ── Helpers ─────────────────────────────────────────────────────
  static bool _isLikelyScreenshot(Uint8List bytes) {
    // PNG signature: 89 50 4E 47
    if (bytes.length > 4 &&
        bytes[0] == 0x89 && bytes[1] == 0x50 &&
        bytes[2] == 0x4E && bytes[3] == 0x47) {
      return true;
    }
    final decoded = img.decodeImage(bytes);
    return decoded != null && decoded.numChannels == 4;
  }

  /// EXIF dates look like "2024:03:19 10:00:00".
  static DateTime? _parseExifDate(String? value) {
    if (value == null || value.length < 19) return null;
    final iso = '${value.substring(0, 10).replaceAll(':', '-')}'
        'T${value.substring(11, 19)}';
    return DateTime.tryParse(iso);
  }

  /// Critical keywords must match the flag strings generated above.
  static String _calculateRisk(List<String> flags) {
    const critical = [
      'software', 'edited', 'ai', 'deepfake',
      'manipulated', 'inconsistent', 'mismatch',
      'camera',   // catches "No camera make/model"
      'unusual',  // catches "unusual for a real JPEG"
    ];
    final criticalCount = flags
        .where((f) => critical.any(f.toLowerCase().contains))
        .length;
    if (criticalCount >= 2) return 'HIGH';
    if (criticalCount == 1) return 'MEDIUM';
    if (flags.length >= 3) return 'MEDIUM';
    return 'LOW';
  }

  static String _buildSummary(
      Map<String, String> exif, List<String> flags, String risk) {
    final parts  = <String>[];
    final camera = (exif['Camera Make'] ?? '').isNotEmpty
        ? exif['Camera Make']!
        : (exif['Camera Model'] ?? '');
    if (camera.isNotEmpty) parts.add('captured with $camera');
    final software = exif['Software'] ?? '';
    if (software.isNotEmpty) parts.add('processed using $software');
    final date = exif['Date Taken'] ?? '';
    if (date.isNotEmpty) parts.add('taken on $date');

    var base = parts.isNotEmpty
        ? 'Image ${parts.join(', ')}.'
        : 'No significant metadata found.';
    if (flags.isNotEmpty) base += ' Flags: ${flags.take(2).join('; ')}.';
    return '$base EXIF risk: $risk.';
  }
}

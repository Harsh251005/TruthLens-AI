// services/pil_resize.dart
// ============================================================
// Pillow-compatible bicubic resize for 8-bit RGB pixels.
//
// The model was trained and served on Pillow's Image.resize(),
// which antialiases when downscaling (the filter widens by the
// scale factor). package:image's cubic resize does not, so large
// phone photos reached the model visibly different. This is a
// port of Pillow's Resample.c: same filter, same coefficient
// fixed-point maths, horizontal pass then vertical pass.
// ============================================================

import 'dart:math' as math;
import 'dart:typed_data';

class PilResize {
  static const _support       = 2.0;   // bicubic filter support
  static const _a             = -0.5;  // Pillow's bicubic constant
  static const _precisionBits = 32 - 8 - 2;

  static double _bicubic(double x) {
    if (x < 0) x = -x;
    if (x < 1) return ((_a + 2) * x - (_a + 3)) * x * x + 1;
    if (x < 2) return (((x - 5) * x + 8) * x - 4) * _a;
    return 0;
  }

  /// Resizes [rgb] (row-major, 3 bytes per pixel) from
  /// [inW]x[inH] to [outW]x[outH], exactly like Pillow BICUBIC.
  static Uint8List resizeRgb(
      Uint8List rgb, int inW, int inH, int outW, int outH) {
    final horizontal = _resample(rgb, inW, inH, outW, horizontal: true);
    return _resample(horizontal, outW, inH, outH, horizontal: false);
  }

  /// One separable pass along x ([horizontal]) or y.
  static Uint8List _resample(Uint8List src, int w, int h, int outSize,
      {required bool horizontal}) {
    final inSize = horizontal ? w : h;
    if (inSize == outSize) return src;

    final c = _coefficients(inSize, outSize);
    final outW = horizontal ? outSize : w;
    final outH = horizontal ? h : outSize;
    final dst  = Uint8List(outW * outH * 3);
    const half = 1 << (_precisionBits - 1);

    for (var y = 0; y < outH; y++) {
      for (var x = 0; x < outW; x++) {
        final o     = horizontal ? x : y;
        final start = c.bounds[o * 2];
        final count = c.bounds[o * 2 + 1];
        final kBase = o * c.kSize;
        var r = half, g = half, b = half;
        for (var i = 0; i < count; i++) {
          final k = c.k[kBase + i];
          final s = horizontal
              ? (y * w + start + i) * 3
              : ((start + i) * w + x) * 3;
          r += src[s] * k;
          g += src[s + 1] * k;
          b += src[s + 2] * k;
        }
        final d = (y * outW + x) * 3;
        dst[d]     = _clip8(r);
        dst[d + 1] = _clip8(g);
        dst[d + 2] = _clip8(b);
      }
    }
    return dst;
  }

  static int _clip8(int v) {
    final shifted = v >> _precisionBits;
    return shifted < 0 ? 0 : (shifted > 255 ? 255 : shifted);
  }

  /// Per-output-pixel source window and fixed-point weights
  /// (Pillow's precompute_coeffs + normalize_coeffs_8bpc).
  static _Coefficients _coefficients(int inSize, int outSize) {
    final scale       = inSize / outSize;
    final filterScale = math.max(scale, 1.0);
    final support     = _support * filterScale;
    final kSize       = support.ceil() * 2 + 1;
    final bounds      = Int32List(outSize * 2);
    final k           = Int32List(outSize * kSize);
    final weights     = List<double>.filled(kSize, 0);
    final ss          = 1.0 / filterScale;

    for (var xx = 0; xx < outSize; xx++) {
      final center = (xx + 0.5) * scale;
      var xmin = (center - support + 0.5).truncate();
      if (xmin < 0) xmin = 0;
      var xmax = (center + support + 0.5).truncate();
      if (xmax > inSize) xmax = inSize;
      xmax -= xmin;

      var ww = 0.0;
      for (var x = 0; x < xmax; x++) {
        final w = _bicubic((x + xmin - center + 0.5) * ss);
        weights[x] = w;
        ww += w;
      }
      for (var x = 0; x < xmax; x++) {
        final w = ww != 0 ? weights[x] / ww : weights[x];
        // Round half away from zero, as Pillow does
        k[xx * kSize + x] =
            (w * (1 << _precisionBits) + (w < 0 ? -0.5 : 0.5)).truncate();
      }
      bounds[xx * 2]     = xmin;
      bounds[xx * 2 + 1] = xmax;
    }
    return _Coefficients(bounds, k, kSize);
  }
}

class _Coefficients {
  final Int32List bounds;  // (start, count) per output pixel
  final Int32List k;       // fixed-point weights, kSize per output pixel
  final int       kSize;
  const _Coefficients(this.bounds, this.k, this.kSize);
}

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:image/image.dart' as img;

import '../models/scan_filter.dart';

/// Pure-Dart image processing: perspective crop/deskew, filters and a basic
/// edge hint for the crop screen.
///
/// Deliberately avoids any native/FFI computer-vision dependency (e.g.
/// OpenCV bindings) so the app builds on a stock Flutter toolchain with no
/// extra native setup, on every supported platform and Flutter version.
/// The tradeoff is a simpler, axis-aligned edge *suggestion* rather than a
/// full contour-based detector — see [suggestCorners]. A real CV-backed
/// detector (e.g. the `opencv_dart` package) is a natural follow-up; swap it
/// in behind [suggestCorners] without touching call sites.
class ImageProcessing {
  const ImageProcessing._();

  /// Decodes [bytes] and returns its (width, height), or null if the bytes
  /// aren't a decodable image.
  static (int, int)? dimensionsOf(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image == null) return null;
    return (image.width, image.height);
  }

  /// Four axis-aligned corners inset from the full image bounds, used as a
  /// safe default before any edge detection runs (or if it finds nothing
  /// confident).
  static List<Offset> defaultCorners(int width, int height) {
    final insetX = width * 0.04;
    final insetY = height * 0.04;
    return [
      Offset(insetX, insetY),
      Offset(width - insetX, insetY),
      Offset(width - insetX, height - insetY),
      Offset(insetX, height - insetY),
    ];
  }

  /// Best-effort page-boundary suggestion.
  ///
  /// Scans a handful of rows/columns near each side of the image for the
  /// first strong brightness gradient, and takes the median crossing per
  /// side. This finds a tighter axis-aligned crop than [defaultCorners] when
  /// the page contrasts with its background, but — unlike full contour
  /// detection — it will not correct skew/perspective by itself. The crop
  /// screen always lets the user drag each corner afterward.
  static List<Offset> suggestCorners(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return const [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(0, 1)];
    }
    final gray = img.grayscale(decoded);
    final w = gray.width;
    final h = gray.height;

    double luminanceAt(int x, int y) => gray.getPixel(x, y).luminance.toDouble();

    const gradientThreshold = 22.0;
    const sampleCount = 7;

    double? scanFromLeft(int y, int maxX) {
      for (var x = 2; x < maxX; x++) {
        final grad = (luminanceAt(x + 1, y) - luminanceAt(x - 1, y)).abs();
        if (grad > gradientThreshold) return x.toDouble();
      }
      return null;
    }

    double? scanFromRight(int y, int minX) {
      for (var x = w - 3; x > minX; x--) {
        final grad = (luminanceAt(x + 1, y) - luminanceAt(x - 1, y)).abs();
        if (grad > gradientThreshold) return x.toDouble();
      }
      return null;
    }

    double? scanFromTop(int x, int maxY) {
      for (var y = 2; y < maxY; y++) {
        final grad = (luminanceAt(x, y + 1) - luminanceAt(x, y - 1)).abs();
        if (grad > gradientThreshold) return y.toDouble();
      }
      return null;
    }

    double? scanFromBottom(int x, int minY) {
      for (var y = h - 3; y > minY; y--) {
        final grad = (luminanceAt(x, y + 1) - luminanceAt(x, y - 1)).abs();
        if (grad > gradientThreshold) return y.toDouble();
      }
      return null;
    }

    final left = <double>[];
    final right = <double>[];
    for (var i = 1; i <= sampleCount; i++) {
      final y = (h * i / (sampleCount + 1)).round().clamp(0, h - 1);
      final l = scanFromLeft(y, (w * 0.4).round());
      if (l != null) left.add(l);
      final r = scanFromRight(y, (w * 0.6).round());
      if (r != null) right.add(r);
    }

    final top = <double>[];
    final bottom = <double>[];
    for (var i = 1; i <= sampleCount; i++) {
      final x = (w * i / (sampleCount + 1)).round().clamp(0, w - 1);
      final t = scanFromTop(x, (h * 0.4).round());
      if (t != null) top.add(t);
      final b = scanFromBottom(x, (h * 0.6).round());
      if (b != null) bottom.add(b);
    }

    final fallback = defaultCorners(w, h);
    final leftX = _median(left) ?? fallback[0].dx;
    final rightX = _median(right) ?? fallback[1].dx;
    final topY = _median(top) ?? fallback[0].dy;
    final bottomY = _median(bottom) ?? fallback[2].dy;

    // Guard against a degenerate/inverted box (e.g. a near-uniform scene).
    if (rightX - leftX < w * 0.3 || bottomY - topY < h * 0.3) {
      return fallback;
    }

    return [
      Offset(leftX, topY),
      Offset(rightX, topY),
      Offset(rightX, bottomY),
      Offset(leftX, bottomY),
    ];
  }

  static double? _median(List<double> values) {
    if (values.isEmpty) return null;
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  /// Crops and flattens the quadrilateral described by [corners] (in source
  /// pixel coordinates, ordered top-left, top-right, bottom-right,
  /// bottom-left) into an upright rectangular image, encoded as JPEG.
  ///
  /// This performs the same job as OpenCV's `getPerspectiveTransform` +
  /// `warpPerspective`: solve the 8 coefficients of the projective mapping
  /// from output-rectangle coordinates back to the source quad, then
  /// bilinear-sample the source for every output pixel.
  static Uint8List warpPerspective(Uint8List sourceBytes, List<Offset> corners) {
    assert(corners.length == 4);
    final source = img.decodeImage(sourceBytes);
    if (source == null) {
      throw ArgumentError('warpPerspective: could not decode source image');
    }

    final tl = corners[0], tr = corners[1], br = corners[2], bl = corners[3];
    final outWidth = math.max(_dist(tl, tr), _dist(bl, br)).round().clamp(1, 1 << 20);
    final outHeight = math.max(_dist(tl, bl), _dist(tr, br)).round().clamp(1, 1 << 20);

    final coeffs = _destToSourceCoefficients(
      corners,
      outWidth.toDouble(),
      outHeight.toDouble(),
    );
    final a = coeffs[0], b = coeffs[1], c = coeffs[2], d = coeffs[3];
    final e = coeffs[4], f = coeffs[5], g = coeffs[6], hh = coeffs[7];

    final out = img.Image(width: outWidth, height: outHeight, numChannels: 3);

    for (var yDst = 0; yDst < outHeight; yDst++) {
      for (var xDst = 0; xDst < outWidth; xDst++) {
        final denom = g * xDst + hh * yDst + 1.0;
        final xSrc = (a * xDst + b * yDst + c) / denom;
        final ySrc = (d * xDst + e * yDst + f) / denom;
        final sample = _bilinearSample(source, xSrc, ySrc);
        out.setPixelRgb(xDst, yDst, sample[0], sample[1], sample[2]);
      }
    }

    return img.encodeJpg(out, quality: 92);
  }

  static double _dist(Offset a, Offset b) => (a - b).distance;

  /// Solves the projective transform mapping destination-rectangle
  /// `(0,0)-(w,0)-(w,h)-(0,h)` to the arbitrary quad [corners], returning
  /// `[a,b,c,d,e,f,g,h]` such that for every destination point:
  ///   xSrc = (a*xDst + b*yDst + c) / (g*xDst + h*yDst + 1)
  ///   ySrc = (d*xDst + e*yDst + f) / (g*xDst + h*yDst + 1)
  static List<double> _destToSourceCoefficients(
    List<Offset> corners,
    double w,
    double h,
  ) {
    final dst = [Offset(0, 0), Offset(w, 0), Offset(w, h), Offset(0, h)];
    // 8x8 system: rows 0,2,4,6 solve for a,b,c,g,h via the x-equations;
    // rows 1,3,5,7 for d,e,f,g,h via the y-equations. Built jointly because
    // g,h are shared between both.
    final matrix = List.generate(8, (_) => List<double>.filled(8, 0));
    final rhs = List<double>.filled(8, 0);

    for (var i = 0; i < 4; i++) {
      final xd = dst[i].dx, yd = dst[i].dy;
      final xs = corners[i].dx, ys = corners[i].dy;

      final rowX = i * 2;
      matrix[rowX][0] = xd;
      matrix[rowX][1] = yd;
      matrix[rowX][2] = 1;
      matrix[rowX][6] = -xd * xs;
      matrix[rowX][7] = -yd * xs;
      rhs[rowX] = xs;

      final rowY = i * 2 + 1;
      matrix[rowY][3] = xd;
      matrix[rowY][4] = yd;
      matrix[rowY][5] = 1;
      matrix[rowY][6] = -xd * ys;
      matrix[rowY][7] = -yd * ys;
      rhs[rowY] = ys;
    }

    return _solveLinearSystem(matrix, rhs);
  }

  /// Gaussian elimination with partial pivoting for a small dense system.
  static List<double> _solveLinearSystem(List<List<double>> a, List<double> b) {
    final n = b.length;
    final m = List.generate(n, (i) => [...a[i], b[i]]);

    for (var col = 0; col < n; col++) {
      var pivot = col;
      for (var row = col + 1; row < n; row++) {
        if (m[row][col].abs() > m[pivot][col].abs()) pivot = row;
      }
      final tmp = m[col];
      m[col] = m[pivot];
      m[pivot] = tmp;

      final pivotVal = m[col][col];
      if (pivotVal.abs() < 1e-12) continue; // degenerate; leave as 0
      for (var row = 0; row < n; row++) {
        if (row == col) continue;
        final factor = m[row][col] / pivotVal;
        if (factor == 0) continue;
        for (var k = col; k <= n; k++) {
          m[row][k] -= factor * m[col][k];
        }
      }
    }

    return List.generate(n, (i) {
      final pivotVal = m[i][i];
      return pivotVal.abs() < 1e-12 ? 0.0 : m[i][n] / pivotVal;
    });
  }

  static List<int> _bilinearSample(img.Image source, double x, double y) {
    final maxX = source.width - 1;
    final maxY = source.height - 1;
    final cx = x.clamp(0, maxX.toDouble());
    final cy = y.clamp(0, maxY.toDouble());

    final x0 = cx.floor().clamp(0, maxX);
    final y0 = cy.floor().clamp(0, maxY);
    final x1 = (x0 + 1).clamp(0, maxX);
    final y1 = (y0 + 1).clamp(0, maxY);
    final fx = cx - x0;
    final fy = cy - y0;

    final p00 = source.getPixel(x0, y0);
    final p10 = source.getPixel(x1, y0);
    final p01 = source.getPixel(x0, y1);
    final p11 = source.getPixel(x1, y1);

    int lerpChannel(num a, num b, num c, num d) {
      final top = a * (1 - fx) + b * fx;
      final bottom = c * (1 - fx) + d * fx;
      return (top * (1 - fy) + bottom * fy).round().clamp(0, 255);
    }

    return [
      lerpChannel(p00.r, p10.r, p01.r, p11.r),
      lerpChannel(p00.g, p10.g, p01.g, p11.g),
      lerpChannel(p00.b, p10.b, p01.b, p11.b),
    ];
  }

  /// Applies [filter] to a decoded page image and re-encodes it as JPEG.
  static Uint8List applyFilter(Uint8List bytes, ScanFilter filter) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw ArgumentError('applyFilter: could not decode image');
    }

    switch (filter) {
      case ScanFilter.original:
        return img.encodeJpg(decoded, quality: 92);
      case ScanFilter.grayscale:
        return img.encodeJpg(img.grayscale(decoded), quality: 92);
      case ScanFilter.enhanced:
        final enhanced = img.adjustColor(
          img.grayscale(img.Image.from(decoded)),
          contrast: 1.35,
          brightness: 1.08,
          gamma: 1.05,
        );
        return img.encodeJpg(enhanced, quality: 92);
      case ScanFilter.blackAndWhite:
        return img.encodeJpg(_binarize(decoded), quality: 92);
    }
  }

  /// A simple Otsu-threshold binarization: good enough for text documents
  /// without pulling in a dedicated adaptive-threshold implementation.
  static img.Image _binarize(img.Image source) {
    final gray = img.grayscale(img.Image.from(source));
    final histogram = List<int>.filled(256, 0);
    final totalPixels = gray.width * gray.height;

    for (final pixel in gray) {
      histogram[pixel.luminance.round().clamp(0, 255)]++;
    }

    var sumAll = 0.0;
    for (var i = 0; i < 256; i++) {
      sumAll += i * histogram[i];
    }

    var sumBackground = 0.0;
    var weightBackground = 0;
    var bestThreshold = 127;
    var bestVariance = -1.0;

    for (var t = 0; t < 256; t++) {
      weightBackground += histogram[t];
      if (weightBackground == 0) continue;
      final weightForeground = totalPixels - weightBackground;
      if (weightForeground == 0) break;

      sumBackground += t * histogram[t];
      final meanBackground = sumBackground / weightBackground;
      final meanForeground = (sumAll - sumBackground) / weightForeground;

      final betweenVariance = weightBackground *
          weightForeground *
          math.pow(meanBackground - meanForeground, 2);
      if (betweenVariance > bestVariance) {
        bestVariance = betweenVariance.toDouble();
        bestThreshold = t;
      }
    }

    final out = img.Image(width: gray.width, height: gray.height, numChannels: 3);
    for (var y = 0; y < gray.height; y++) {
      for (var x = 0; x < gray.width; x++) {
        final value = gray.getPixel(x, y).luminance > bestThreshold ? 255 : 0;
        out.setPixelRgb(x, y, value, value, value);
      }
    }
    return out;
  }
}

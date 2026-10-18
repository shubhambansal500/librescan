import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:librescan/models/scan_filter.dart';
import 'package:librescan/services/image_processing.dart';

/// Builds a simple synthetic "document" test image: a light background with
/// a darker inset rectangle, so edge-detection and warp logic have
/// something non-uniform to work with.
Uint8List _buildTestImage({int width = 200, int height = 280}) {
  final image = img.Image(width: width, height: height, numChannels: 3);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(x, y, 245, 245, 245);
    }
  }
  final left = (width * 0.1).round();
  final right = (width * 0.9).round();
  final top = (height * 0.1).round();
  final bottom = (height * 0.9).round();
  for (var y = top; y < bottom; y++) {
    for (var x = left; x < right; x++) {
      image.setPixelRgb(x, y, 20, 20, 20);
    }
  }
  return img.encodeJpg(image, quality: 95);
}

void main() {
  group('ImageProcessing.dimensionsOf', () {
    test('reads width/height back from encoded bytes', () {
      final bytes = _buildTestImage(width: 200, height: 280);
      final dims = ImageProcessing.dimensionsOf(bytes);
      expect(dims, isNotNull);
      expect(dims!.$1, 200);
      expect(dims.$2, 280);
    });
  });

  group('ImageProcessing.defaultCorners', () {
    test('returns an inset rectangle within bounds, ordered TL,TR,BR,BL', () {
      final corners = ImageProcessing.defaultCorners(100, 200);
      expect(corners, hasLength(4));
      for (final c in corners) {
        expect(c.dx, inInclusiveRange(0, 100));
        expect(c.dy, inInclusiveRange(0, 200));
      }
      expect(corners[0].dx, lessThan(corners[1].dx)); // TL left of TR
      expect(corners[0].dy, lessThan(corners[3].dy)); // TL above BL
    });
  });

  group('ImageProcessing.suggestCorners', () {
    test('finds a tighter-than-default box around the dark rectangle', () {
      final bytes = _buildTestImage(width: 200, height: 280);
      final corners = ImageProcessing.suggestCorners(bytes);
      expect(corners, hasLength(4));
      final width = corners[1].dx - corners[0].dx;
      final height = corners[3].dy - corners[0].dy;
      // The dark rectangle spans ~80% of each dimension; the detector
      // should land closer to that than to the full-frame fallback.
      expect(width, lessThan(200 * 0.95));
      expect(height, lessThan(280 * 0.95));
      expect(width, greaterThan(200 * 0.5));
      expect(height, greaterThan(280 * 0.5));
    });

    test('falls back sanely on a uniform image with no edges', () {
      final blank = img.Image(width: 100, height: 140, numChannels: 3);
      for (var y = 0; y < 140; y++) {
        for (var x = 0; x < 100; x++) {
          blank.setPixelRgb(x, y, 200, 200, 200);
        }
      }
      final bytes = img.encodeJpg(blank, quality: 90);
      final corners = ImageProcessing.suggestCorners(bytes);
      expect(corners, hasLength(4));
      for (final c in corners) {
        expect(c.dx, inInclusiveRange(0, 100));
        expect(c.dy, inInclusiveRange(0, 140));
      }
    });
  });

  group('ImageProcessing.warpPerspective', () {
    test('an identity (axis-aligned, full-frame) warp preserves size and content', () {
      final bytes = _buildTestImage(width: 200, height: 280);
      final corners = [
        const Offset(0, 0),
        const Offset(199, 0),
        const Offset(199, 279),
        const Offset(0, 279),
      ];
      final warped = ImageProcessing.warpPerspective(bytes, corners);
      final decoded = img.decodeImage(warped);
      expect(decoded, isNotNull);
      expect(decoded!.width, closeTo(200, 2));
      expect(decoded.height, closeTo(280, 2));

      // Center pixel should still fall inside the dark rectangle.
      final center = decoded.getPixel(decoded.width ~/ 2, decoded.height ~/ 2);
      expect(center.luminance, lessThan(80));
    });

    test('cropping to just the inner dark rectangle yields a mostly-dark image', () {
      final bytes = _buildTestImage(width: 200, height: 280);
      final corners = [
        const Offset(20, 28),
        const Offset(180, 28),
        const Offset(180, 252),
        const Offset(20, 252),
      ];
      final warped = ImageProcessing.warpPerspective(bytes, corners);
      final decoded = img.decodeImage(warped)!;
      final center = decoded.getPixel(decoded.width ~/ 2, decoded.height ~/ 2);
      expect(center.luminance, lessThan(40));
    });
  });

  group('ImageProcessing.applyFilter', () {
    test('every filter produces a decodable image of the same dimensions', () {
      final bytes = _buildTestImage(width: 120, height: 160);
      for (final filter in ScanFilter.values) {
        final out = ImageProcessing.applyFilter(bytes, filter);
        final decoded = img.decodeImage(out);
        expect(decoded, isNotNull, reason: 'filter $filter produced undecodable bytes');
        expect(decoded!.width, 120);
        expect(decoded.height, 160);
      }
    });

    test('blackAndWhite output is strictly binary (0 or 255 per channel)', () {
      final bytes = _buildTestImage(width: 120, height: 160);
      final out = ImageProcessing.applyFilter(bytes, ScanFilter.blackAndWhite);
      final decoded = img.decodeImage(out)!;
      final sampled = decoded.getPixel(5, 5);
      expect(sampled.r, anyOf(0, 255));
      expect(sampled.g, anyOf(0, 255));
      expect(sampled.b, anyOf(0, 255));
    });
  });
}

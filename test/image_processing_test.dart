import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:foodsnap/core/image/meal_image.dart';

/// Builds a synthetic landscape JPEG (2000×1000) in-memory.
Uint8List _testJpeg(int w, int h) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(200, 120, 60));
  return Uint8List.fromList(img.encodeJpg(image));
}

/// High-entropy noise JPEG: stresses the encoder (large output at q80).
Uint8List _noiseJpeg(int w, int h) {
  final image = img.Image(width: w, height: h);
  var seed = 12345;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      image.setPixel(
        x,
        y,
        img.ColorRgb8(seed & 0xff, (seed >> 8) & 0xff, (seed >> 16) & 0xff),
      );
    }
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 95));
}

void main() {
  group('processMealImage (TECH_SPEC §9.1)', () {
    test('resizes to 1280 / 360 long edge JPEGs', () async {
      final processed = await processMealImage(_testJpeg(2000, 1000));
      final photo = img.decodeImage(processed.photo)!;
      final thumb = img.decodeImage(processed.thumb)!;
      expect(photo.width, 1280);
      expect(photo.height, 640);
      expect(thumb.width, 360);
      expect(thumb.height, 180);
    });

    test('output is JPEG (magic bytes)', () async {
      final processed = await processMealImage(_testJpeg(800, 600));
      for (final bytes in [processed.photo, processed.thumb]) {
        expect(bytes[0], 0xFF);
        expect(bytes[1], 0xD8);
      }
    });

    test('never upscales small images', () async {
      final processed = await processMealImage(_testJpeg(400, 300));
      final photo = img.decodeImage(processed.photo)!;
      expect(photo.width, 400);
      expect(photo.height, 300);
    });

    test('throws on undecodable bytes', () {
      expect(
        processMealImage(Uint8List.fromList([0, 1, 2, 3])),
        throwsA(isA<FormatException>()),
      );
    });

    test('noisy photo steps down until under the Firestore cap', () async {
      final processed = await processMealImage(_noiseJpeg(2000, 1500));
      expect(processed.photo.lengthInBytes, lessThanOrEqualTo(maxPhotoBytes));
      // Still a valid, viewable JPEG.
      final photo = img.decodeImage(processed.photo)!;
      expect(photo.width, lessThanOrEqualTo(1280));
      expect(processed.photo[0], 0xFF);
      expect(processed.photo[1], 0xD8);
    });
  });
}

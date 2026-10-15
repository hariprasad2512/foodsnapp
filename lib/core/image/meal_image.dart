import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Image pipeline per TECH_SPEC §9.1 + §12: never upload the raw camera
/// image. Decode, fix orientation, resize to 1280 px long edge JPEG q80
/// (photo) and 360 px JPEG q75 (thumb). Re-encoding strips EXIF GPS.
/// Runs in an isolate via [compute] so the UI never janks.
///
/// Spark storage (TECH_SPEC §17): renditions are stored as Firestore byte
/// Blobs (1 MiB per-doc cap), so the photo additionally steps down quality
/// until it fits [maxPhotoBytes] (default 700 KB, under the rules cap).
class ProcessedMealImage {
  final Uint8List photo;
  final Uint8List thumb;
  const ProcessedMealImage({required this.photo, required this.thumb});
}

/// Firestore per-document cap is 1 MiB; the rules cap for the photo asset
/// is 800 KB — the pipeline targets 700 KB to leave headroom.
const maxPhotoBytes = 700 * 1024;

Future<ProcessedMealImage> processMealImage(Uint8List rawBytes) =>
    compute(_processInBackground, rawBytes);

ProcessedMealImage _processInBackground(Uint8List rawBytes) {
  final decoded = img.decodeImage(rawBytes);
  if (decoded == null) {
    throw const FormatException('Could not decode image');
  }
  final oriented = img.bakeOrientation(decoded);
  return ProcessedMealImage(
    photo: _encodeUnderCap(oriented),
    thumb: _encode(oriented, 360, quality: 75),
  );
}

/// Encodes at 1280 px q80, stepping down until the output fits
/// [maxPhotoBytes]: q80 → q70 → q60 → 960 px q70 → 960 px q60.
Uint8List _encodeUnderCap(img.Image src) {
  const attempts = [
    (1280, 80),
    (1280, 70),
    (1280, 60),
    (960, 70),
    (960, 60),
  ];
  var encoded = Uint8List(0);
  for (final (edge, quality) in attempts) {
    encoded = _encode(src, edge, quality: quality);
    if (encoded.lengthInBytes <= maxPhotoBytes) return encoded;
  }
  return encoded; // best effort; rules reject the write if still over cap
}

Uint8List _encode(img.Image src, int longEdge, {required int quality}) {
  final longest = src.width >= src.height ? src.width : src.height;
  final img.Image sized;
  if (longest <= longEdge) {
    sized = src; // never upscale small images
  } else {
    final scale = longEdge / longest;
    sized = img.copyResize(
      src,
      width: (src.width * scale).round(),
      height: (src.height * scale).round(),
    );
  }
  return Uint8List.fromList(img.encodeJpg(sized, quality: quality));
}

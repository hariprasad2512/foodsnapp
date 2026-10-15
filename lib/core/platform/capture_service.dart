import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Capture helpers (TECH_SPEC §9.1, UI spec S05).
///
/// Single implementation for Android + web: `camera` (live preview) and
/// `image_picker` both compile on both platforms, so no conditional import
/// is needed — nothing here touches `dart:io`. The web S05 variant skips
/// the live viewfinder and uses [takePhoto] (browser camera) instead.
class CaptureService {
  CaptureService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  /// Gallery pick (S05 gallery button), Android + web.
  Future<Uint8List?> pickFromGallery() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    return file?.readAsBytes();
  }

  /// Browser-native camera (web S05 variant).
  Future<Uint8List?> takePhoto() async {
    final file = await _picker.pickImage(source: ImageSource.camera);
    return file?.readAsBytes();
  }
}

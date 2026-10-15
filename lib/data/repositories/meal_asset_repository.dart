import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Meal image bytes (TECH_SPEC §17, Spark storage). Each meal has two asset
/// docs — `relationships/{relId}/meals/{mealId}/assets/photo` (1280 px) and
/// `.../assets/thumb` (360 px) — each `{data: bytes}`. Kept out of the meal
/// doc so list queries (timeline, history) never drag full-res bytes; the
/// same member/client rules guard them (firestore.rules).
///
/// Reads are cached in memory per session; eviction is left to process death
/// (trial-scale image counts fit comfortably).
class MealAssetRepository {
  MealAssetRepository(this._db);
  final FirebaseFirestore _db;

  static const photoId = 'photo';
  static const thumbId = 'thumb';

  final Map<String, Uint8List> _cache = {};

  String _key(String relId, String mealId, String assetId) =>
      '$relId/$mealId/$assetId';

  DocumentReference<Map<String, dynamic>> _doc(
    String relId,
    String mealId,
    String assetId,
  ) =>
      _db
          .collection('relationships')
          .doc(relId)
          .collection('meals')
          .doc(mealId)
          .collection('assets')
          .doc(assetId);

  Future<Uint8List?> fetchAsset(
    String relId,
    String mealId,
    String assetId,
  ) async {
    final key = _key(relId, mealId, assetId);
    final cached = _cache[key];
    if (cached != null) return cached;
    final snap = await _doc(relId, mealId, assetId).get();
    final data = snap.data()?['data'];
    if (data is! Blob) return null;
    final bytes = data.bytes;
    _cache[key] = bytes;
    return bytes;
  }

  Future<Uint8List?> fetchThumb(String relId, String mealId) =>
      fetchAsset(relId, mealId, thumbId);

  Future<Uint8List?> fetchPhoto(String relId, String mealId) =>
      fetchAsset(relId, mealId, photoId);
}

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/meal.dart';
import 'meal_asset_repository.dart';

/// Meal writes for the client (TECH_SPEC §9.1 + §17). The doc id is
/// generated locally first; `createdAt` is always the server timestamp
/// (rules require `createdAt == request.time`). The photo/thumb bytes go
/// to the `assets` subcollection in the SAME batch, so a meal never exists
/// without its images (and vice versa).
class MealRepository {
  MealRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _meals(String relId) =>
      _db.collection('relationships').doc(relId).collection('meals');

  /// Generates a client-side doc id for the asset paths.
  String newMealId(String relId) => _meals(relId).doc().id;

  Future<void> createMealWithAssets({
    required String relId,
    required String mealId,
    required String clientId,
    required String mealTag,
    String? note,
    required Blob photo,
    required Blob thumb,
    required String localDate,
    required String localTime,
  }) async {
    final meal = Meal(
      id: mealId,
      clientId: clientId,
      mealTag: mealTag,
      note: note,
      localDate: localDate,
      localTime: localTime,
    );
    final mealRef = _meals(relId).doc(mealId);
    final batch = _db.batch();
    batch.set(mealRef, meal.toMap());
    batch.set(
      mealRef
          .collection('assets')
          .doc(MealAssetRepository.photoId),
      {'data': photo},
    );
    batch.set(
      mealRef
          .collection('assets')
          .doc(MealAssetRepository.thumbId),
      {'data': thumb},
    );
    await batch.commit();
  }
}

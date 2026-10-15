import 'package:cloud_firestore/cloud_firestore.dart';

// Full shape per TECH_SPEC §5 (relationships/{relId}/meals/{mealId}).
// Spark storage (§17): the photo/thumb JPEG bytes live in the
// `assets/{photo,thumb}` subcollection (see MealAssetRepository), so the
// meal doc itself is metadata only. `calories` is reserved for v2.

class Meal {
  final String id;
  final String clientId;
  final String mealTag; // breakfast | lunch | snack | dinner
  final String? note; // ≤ 200 chars
  final DateTime? createdAt; // server time
  final String localDate; // yyyy-MM-dd in client local time
  final String localTime; // HH:mm
  final String? reaction; // dietician-only, one of the allowed set
  final String? dieticianComment; // ≤ 300 chars

  const Meal({
    required this.id,
    required this.clientId,
    required this.mealTag,
    this.note,
    this.createdAt,
    required this.localDate,
    required this.localTime,
    this.reaction,
    this.dieticianComment,
  });

  static DateTime? _date(dynamic v) => v is Timestamp ? v.toDate() : null;

  factory Meal.fromMap(String id, Map<String, dynamic> map) => Meal(
        id: id,
        clientId: map['clientId'] as String? ?? '',
        mealTag: map['mealTag'] as String? ?? 'snack',
        note: map['note'] as String?,
        createdAt: _date(map['createdAt']),
        localDate: map['localDate'] as String? ?? '',
        localTime: map['localTime'] as String? ?? '',
        reaction: map['reaction'] as String?,
        dieticianComment: map['dieticianComment'] as String?,
      );

  /// Keys must match firestore.rules exactly (meal create allow-list).
  Map<String, dynamic> toMap() => {
        'clientId': clientId,
        'mealTag': mealTag,
        'note': note,
        'createdAt': createdAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(createdAt!),
        'localDate': localDate,
        'localTime': localTime,
        'reaction': reaction,
        'dieticianComment': dieticianComment,
        'calories': null,
        'caloriesSource': null,
      };
}

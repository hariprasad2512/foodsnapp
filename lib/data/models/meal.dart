// Placeholder — full fields per TECH_SPEC §5 land in M4 (capture).
// `calories` is reserved for v2 and always null in v1.

class Meal {
  final String id;
  final String clientId;
  final String mealTag; // breakfast | lunch | snack | dinner
  final String? note;
  final String? photoUrl;
  final String? thumbUrl;
  final String localDate; // yyyy-MM-dd in client local time
  final String localTime; // HH:mm

  const Meal({
    required this.id,
    required this.clientId,
    required this.mealTag,
    this.note,
    this.photoUrl,
    this.thumbUrl,
    required this.localDate,
    required this.localTime,
  });

  factory Meal.fromMap(String id, Map<String, dynamic> map) => Meal(
        id: id,
        clientId: map['clientId'] as String? ?? '',
        mealTag: map['mealTag'] as String? ?? 'snack',
        note: map['note'] as String?,
        photoUrl: map['photoUrl'] as String?,
        thumbUrl: map['thumbUrl'] as String?,
        localDate: map['localDate'] as String? ?? '',
        localTime: map['localTime'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'clientId': clientId,
        'mealTag': mealTag,
        'note': note,
        'photoUrl': photoUrl,
        'thumbUrl': thumbUrl,
        'localDate': localDate,
        'localTime': localTime,
        'calories': null,
        'caloriesSource': null,
      };
}

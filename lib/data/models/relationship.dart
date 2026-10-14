import 'package:cloud_firestore/cloud_firestore.dart';

// Full shape per TECH_SPEC §5. Counters/streaks are function-owned;
// the client only ever resets its own unread counter to 0 (rules, M1).

class Relationship {
  final String id;
  final String dieticianId;
  final String clientId;
  final String dieticianName;
  final String clientName;
  final String status;
  final DateTime? createdAt;
  final DateTime? lastMealAt;
  final String? lastMealTag;
  final String? lastMealLocalDate;
  final int streakCount;
  final int unreadForDietician;
  final int unreadForClient;
  final DateTime? lastActivityAt;
  final String? inviteCode; // Spark pairing receipt (TECH_SPEC §17)

  const Relationship({
    required this.id,
    required this.dieticianId,
    required this.clientId,
    this.dieticianName = '',
    this.clientName = '',
    this.status = 'active',
    this.createdAt,
    this.lastMealAt,
    this.lastMealTag,
    this.lastMealLocalDate,
    this.streakCount = 0,
    this.unreadForDietician = 0,
    this.unreadForClient = 0,
    this.lastActivityAt,
    this.inviteCode,
  });

  static DateTime? _date(dynamic v) => v is Timestamp ? v.toDate() : null;

  factory Relationship.fromMap(String id, Map<String, dynamic> map) =>
      Relationship(
        id: id,
        dieticianId: map['dieticianId'] as String? ?? '',
        clientId: map['clientId'] as String? ?? '',
        dieticianName: map['dieticianName'] as String? ?? '',
        clientName: map['clientName'] as String? ?? '',
        status: map['status'] as String? ?? 'active',
        createdAt: _date(map['createdAt']),
        lastMealAt: _date(map['lastMealAt']),
        lastMealTag: map['lastMealTag'] as String?,
        lastMealLocalDate: map['lastMealLocalDate'] as String?,
        streakCount: (map['streakCount'] as num?)?.toInt() ?? 0,
        unreadForDietician:
            (map['unreadForDietician'] as num?)?.toInt() ?? 0,
        unreadForClient: (map['unreadForClient'] as num?)?.toInt() ?? 0,
        lastActivityAt: _date(map['lastActivityAt']),
        inviteCode: map['inviteCode'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'dieticianId': dieticianId,
        'clientId': clientId,
        'dieticianName': dieticianName,
        'clientName': clientName,
        'status': status,
      };
}

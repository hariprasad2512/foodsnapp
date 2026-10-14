import 'package:cloud_firestore/cloud_firestore.dart';

// Full shape per TECH_SPEC §5 (doc id = 6-char code).

class Invite {
  final String code;
  final String dieticianId;
  final String dieticianName;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final String? usedBy;
  final DateTime? usedAt;
  final bool revoked;

  const Invite({
    required this.code,
    required this.dieticianId,
    this.dieticianName = '',
    this.createdAt,
    this.expiresAt,
    this.usedBy,
    this.usedAt,
    this.revoked = false,
  });

  static DateTime? _date(dynamic v) =>
      v is Timestamp ? v.toDate() : null;

  factory Invite.fromMap(String code, Map<String, dynamic> map) => Invite(
        code: code,
        dieticianId: map['dieticianId'] as String? ?? '',
        dieticianName: map['dieticianName'] as String? ?? '',
        createdAt: _date(map['createdAt']),
        expiresAt: _date(map['expiresAt']),
        usedBy: map['usedBy'] as String?,
        usedAt: _date(map['usedAt']),
        revoked: map['revoked'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'dieticianId': dieticianId,
        'dieticianName': dieticianName,
        'createdAt': createdAt,
        'expiresAt': expiresAt,
        'usedBy': usedBy,
        'usedAt': usedAt,
        'revoked': revoked,
      };
}

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/relationship.dart';

/// Relationship reads. Writes happen only in Cloud Functions (M1 rules
/// deny direct create/delete; updates limited to own unread reset).
class RelationshipRepository {
  RelationshipRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _rels =>
      _db.collection('relationships');

  /// The client's single active relationship (TECH_SPEC §8).
  Stream<Relationship?> watchActiveForClient(String uid) => _rels
      .where('clientId', isEqualTo: uid)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty
          ? null
          : Relationship.fromMap(s.docs.first.id, s.docs.first.data()));

  /// All clients of a dietician (unsorted — no composite index in M3;
  /// sorted client-side in clientsProvider; M9 adds the index + sorting).
  Stream<List<Relationship>> watchClientsForDietician(String dieticianId) =>
      _rels
          .where('dieticianId', isEqualTo: dieticianId)
          .snapshots()
          .map((s) =>
              s.docs.map((d) => Relationship.fromMap(d.id, d.data())).toList());
}

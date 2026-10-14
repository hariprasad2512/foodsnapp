import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/relationship.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/relationship_repository.dart';

final relationshipRepositoryProvider = Provider<RelationshipRepository>(
  (ref) => RelationshipRepository(FirebaseFirestore.instance),
);

/// Null while signed out; null for a client with no relationship (→ /join).
/// M3 wires the real query: relationships where clientId == uid, limit 1.
final activeRelationshipProvider = StreamProvider<Relationship?>((ref) {
  final auth = ref.watch(authStateProvider);
  final user = auth.hasValue ? auth.value : null;
  if (user == null) return Stream.value(null);
  return ref
      .watch(relationshipRepositoryProvider)
      .watchActiveForClient(user.uid);
});

/// Dietician's client list (S10; full polish in M9).
final clientsProvider = StreamProvider<List<Relationship>>((ref) {
  final auth = ref.watch(authStateProvider);
  final user = auth.hasValue ? auth.value : null;
  if (user == null) return Stream.value(const <Relationship>[]);
  return ref
      .watch(relationshipRepositoryProvider)
      .watchClientsForDietician(user.uid)
      .map((list) {
    final sorted = [...list];
    sorted.sort((a, b) {
      final at = a.lastActivityAt;
      final bt = b.lastActivityAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
    return sorted;
  });
});

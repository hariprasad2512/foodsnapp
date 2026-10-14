import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/invite_code.dart';
import '../models/invite.dart';

/// Maps a redeem failure slug to the exact S03 strings (UI spec §11).
String redeemErrorMessage(String slug) {
  switch (slug) {
    case 'not-found':
      return 'Code not found';
    case 'expired':
      return 'Code expired — ask your dietician for a new one';
    case 'already-used':
      return 'Code already used';
    case 'already-connected':
      return "You're already connected";
    default:
      return 'Something went wrong. Try again.';
  }
}

/// Invite lifecycle for the dietician (create/list/revoke, §9.2) plus the
/// client-side redeem transaction.
///
/// Spark-only pairing (TECH_SPEC §17): no Cloud Functions on Spark, so the
/// client claims the invite and creates its deterministic relationship doc
/// (`rel_{uid}`) in one Firestore transaction. The rules validate the invite
/// (exists, unrevoked, unexpired, unused) and the relationship shape, and the
/// deterministic id makes a second relationship impossible. Residual risk vs
/// the function design: two clients redeeming the same code in the same
/// instant could both pass validation (last writer wins `usedBy`) —
/// acceptable for a private trial, revisited if Blaze ever lands.
class InviteRepository {
  InviteRepository(this._db, this._auth);
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _invites =>
      _db.collection('invites');

  /// Creates a fresh invite; retries on code collision.
  Future<Invite> createInvite({
    required String dieticianId,
    required String dieticianName,
  }) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = generateInviteCode();
      final ref = _invites.doc(code);
      if ((await ref.get()).exists) continue;
      final now = DateTime.now();
      await ref.set({
        'dieticianId': dieticianId,
        'dieticianName': dieticianName,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(now.add(const Duration(hours: 48))),
        'usedBy': null,
        'usedAt': null,
        'revoked': false,
      });
      final snap = await ref.get();
      return Invite.fromMap(code, snap.data() ?? const {});
    }
    throw StateError('Could not generate a unique invite code');
  }

  Stream<List<Invite>> watchMyInvites(String dieticianId) => _invites
      .where('dieticianId', isEqualTo: dieticianId)
      .snapshots()
      .map((s) => s.docs.map((d) => Invite.fromMap(d.id, d.data())).toList());

  Future<void> revokeInvite(String code) =>
      _invites.doc(code).update({'revoked': true});

  /// Redeems [code] for the signed-in client. Returns the new relId.
  /// Throws [RedeemFailure] carrying the slug on known failures.
  Future<String> redeemInvite(String code) async {
    final clean = code.trim().toUpperCase();
    if (!isValidInviteCode(clean)) throw RedeemFailure('not-found');
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw RedeemFailure('unknown');
    final relId = 'rel_$uid';
    try {
      await _db.runTransaction((tx) async {
        final inviteRef = _invites.doc(clean);
        final inviteSnap = await tx.get(inviteRef);
        if (!inviteSnap.exists) throw RedeemFailure('not-found');
        final data = inviteSnap.data()!;
        if (data['revoked'] == true) throw RedeemFailure('expired');
        if (data['usedBy'] != null) throw RedeemFailure('already-used');
        final expiresAt = data['expiresAt'] as Timestamp?;
        if (expiresAt == null ||
            expiresAt.toDate().isBefore(DateTime.now())) {
          throw RedeemFailure('expired');
        }
        final relRef = _db.collection('relationships').doc(relId);
        if ((await tx.get(relRef)).exists) {
          throw RedeemFailure('already-connected');
        }
        final userSnap =
            await tx.get(_db.collection('users').doc(uid));
        final userData = userSnap.data();
        if (userData?['role'] != 'client') {
          throw RedeemFailure('unknown');
        }
        final now = FieldValue.serverTimestamp();
        tx.update(inviteRef, {
          'usedBy': uid,
          'usedAt': now,
        });
        tx.set(relRef, {
          'dieticianId': data['dieticianId'],
          'clientId': uid,
          'dieticianName': data['dieticianName'],
          'clientName': userData!['displayName'],
          'status': 'active',
          'createdAt': now,
          'lastMealAt': null,
          'lastMealTag': null,
          'lastMealLocalDate': null,
          'streakCount': 0,
          'unreadForDietician': 0,
          'unreadForClient': 0,
          'lastActivityAt': now,
          'inviteCode': clean,
        });
      });
      return relId;
    } on RedeemFailure {
      rethrow;
    } on FirebaseException {
      // Rules denial (e.g. lost a race) surfaces here.
      throw RedeemFailure('unknown');
    }
  }
}

/// Failure slug from redeem (see redeemErrorMessage).
class RedeemFailure implements Exception {
  RedeemFailure(this.slug);
  final String slug;
}

final inviteRepositoryProvider = Provider<InviteRepository>(
  (ref) => InviteRepository(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
  ),
);

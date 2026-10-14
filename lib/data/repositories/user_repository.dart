import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../data/models/app_user.dart';
import 'auth_repository.dart';

/// Reads/writes the `users/{uid}` profile doc (TECH_SPEC §5).
/// Creation keys must stay within the rules allowlist
/// (role, displayName, email, timezone, createdAt).
class UserRepository {
  UserRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  Stream<AppUser?> watchProfile(String uid) =>
      _users.doc(uid).snapshots().map(
            (snap) => snap.exists && snap.data() != null
                ? AppUser.fromMap(snap.id, snap.data()!)
                : null,
          );

  Future<void> createProfile({
    required String uid,
    required String role,
    required String displayName,
    required String email,
  }) async {
    String timezone = 'Asia/Kolkata';
    try {
      timezone = (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      // Emulator/unsupported platform — fall back to the default.
    }
    await _users.doc(uid).set({
      'role': role,
      'displayName': displayName,
      'email': email,
      'timezone': timezone,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(FirebaseFirestore.instance),
);

/// Null = signed out, or signed in without a profile doc (→ /role).
final profileProvider = StreamProvider<AppUser?>((ref) {
  final auth = ref.watch(authStateProvider);
  final user = auth.hasValue ? auth.value : null;
  if (user == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watchProfile(user.uid);
});

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// FirebaseAuth failure → UI-spec exact strings where defined (S01 §11),
/// friendly fallbacks otherwise.
String authErrorMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'wrong-password':
    case 'invalid-credential':
    case 'user-not-found':
      return 'Wrong email or password';
    case 'network-request-failed':
      return 'No internet connection';
    case 'email-already-in-use':
      return 'This email is already registered. Try signing in.';
    case 'invalid-email':
      return 'Enter a valid email address.';
    case 'weak-password':
      return 'Password must be at least 6 characters.';
    default:
      return 'Something went wrong. Try again.';
  }
}

/// Thin wrapper over FirebaseAuth. No Firestore here (see UserRepository).
class AuthRepository {
  AuthRepository(this._auth);
  final FirebaseAuth _auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<void> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> signUpWithEmail(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  /// Google on Android + web. Note: Android release builds need the SHA-1
  /// registered in the Firebase console or this throws (M2 report).
  Future<void> signInWithGoogle() async {
    await GoogleSignIn.instance.initialize();
    final account = await GoogleSignIn.instance.authenticate();
    final googleAuth = account.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    await _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(FirebaseAuth.instance),
);

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

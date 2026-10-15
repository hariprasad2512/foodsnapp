import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// FirebaseAuth failure → UI-spec exact strings where defined (S01 §11),
/// friendly fallbacks otherwise. Unknown codes are logged in debug builds
/// so web/popup failures stay diagnosable.
String authErrorMessage(FirebaseAuthException e) {
  if (kDebugMode) {
    debugPrint('FoodSnap auth failure: ${e.code} ${e.message}');
  }
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
    case 'too-many-requests':
      return 'Too many attempts. Try again in a few minutes.';
    case 'operation-not-allowed':
      return "This sign-in method isn't enabled. Use another one.";
    case 'unauthorized-domain':
      return "This site isn't authorized for sign-in. Try the app instead.";
    case 'popup-blocked':
      return 'The sign-in popup was blocked. Allow popups and try again.';
    default:
      return 'Something went wrong. Try again.';
  }
}

/// True for user-dismissed sign-in UI on any platform (Android account
/// chooser or web popup) — the screen just resets, no error text.
bool isSignInDismissal(Object e) =>
    (e is GoogleSignInException &&
        e.code == GoogleSignInExceptionCode.canceled) ||
    (e is FirebaseAuthException && e.code == 'popup-closed-by-user');

/// Thin wrapper over FirebaseAuth. No Firestore here (see UserRepository).
class AuthRepository {
  AuthRepository(this._auth);
  final FirebaseAuth _auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<void> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> signUpWithEmail(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  /// Google on Android (plugin) + web (popup). The plugin path needs
  /// native config (google-services.json + SHA-1) and has no OAuth client
  /// on web, so web uses the Firebase popup flow instead — no client-ID
  /// plumbing required. Note: Android release builds need the SHA-1
  /// registered in the Firebase console or this throws (M2 report).
  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      await _auth.signInWithPopup(GoogleAuthProvider());
      return;
    }
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

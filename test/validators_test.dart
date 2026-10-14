import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foodsnap/data/repositories/auth_repository.dart';
import 'package:foodsnap/features/auth/validators.dart';

void main() {
  group('isValidDisplayName (S02: 2–40 chars)', () {
    test('accepts 2–40 chars', () {
      expect(isValidDisplayName('Al'), isTrue);
      expect(isValidDisplayName('Alice'), isTrue);
      expect(isValidDisplayName('x' * 40), isTrue);
    });
    test('rejects blank, 1 char, over 40', () {
      expect(isValidDisplayName(''), isFalse);
      expect(isValidDisplayName('  '), isFalse);
      expect(isValidDisplayName('A'), isFalse);
      expect(isValidDisplayName('x' * 41), isFalse);
    });
  });

  group('looksLikeEmail', () {
    test('basic sanity only; Firebase owns the real check', () {
      expect(looksLikeEmail('a@b.com'), isTrue);
      expect(looksLikeEmail('nope'), isFalse);
      expect(looksLikeEmail('a@b'), isFalse);
    });
  });

  group('authErrorMessage (S01 microcopy)', () {
    FirebaseAuthException err(String code) =>
        FirebaseAuthException(code: code);
    test('exact UI-spec strings', () {
      expect(authErrorMessage(err('wrong-password')), 'Wrong email or password');
      expect(authErrorMessage(err('invalid-credential')), 'Wrong email or password');
      expect(authErrorMessage(err('user-not-found')), 'Wrong email or password');
      expect(authErrorMessage(err('network-request-failed')), 'No internet connection');
    });
    test('fallbacks', () {
      expect(authErrorMessage(err('email-already-in-use')), isNotEmpty);
      expect(authErrorMessage(err('bogus-code')), 'Something went wrong. Try again.');
    });
  });
}

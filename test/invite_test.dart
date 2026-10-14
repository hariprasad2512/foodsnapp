import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:foodsnap/core/utils/invite_code.dart';
import 'package:foodsnap/data/repositories/invite_repository.dart';

void main() {
  group('generateInviteCode (TECH_SPEC §5)', () {
    test('6 chars from the allowed alphabet only', () {
      final seen = <String>{};
      for (var i = 0; i < 200; i++) {
        final code = generateInviteCode();
        expect(code.length, 6);
        expect(RegExp(r'^[A-HJ-NP-Z2-9]{6}$').hasMatch(code), isTrue,
            reason: 'bad code: $code');
        seen.add(code);
      }
      // No I, O, 0, 1 anywhere across 200 samples.
      expect(seen.join().contains(RegExp('[IO01]')), isFalse);
      // Randomness sanity: 200 draws should not collapse to a few values.
      expect(seen.length, greaterThan(150));
    });

    test('seeded random is deterministic', () {
      expect(generateInviteCode(random: Random(42)),
          generateInviteCode(random: Random(42)));
    });
  });

  group('isValidInviteCode', () {
    test('accepts valid, trims + uppercases', () {
      expect(isValidInviteCode('ABCDEF'), isTrue);
      expect(isValidInviteCode('abcdef'), isTrue);
      expect(isValidInviteCode('  ABCDEF  '), isTrue);
    });
    test('rejects bad input', () {
      expect(isValidInviteCode('ABCDE'), isFalse);
      expect(isValidInviteCode('ABCDEFG'), isFalse);
      expect(isValidInviteCode('ABCDE1'), isFalse); // 1 excluded
      expect(isValidInviteCode('ABIDEF'), isFalse); // I excluded
      expect(isValidInviteCode('ABODEF'), isFalse); // O excluded
      expect(isValidInviteCode('AB0DEF'), isFalse); // 0 excluded
      expect(isValidInviteCode(''), isFalse);
    });
  });

  group('redeemErrorMessage (S03 microcopy)', () {
    test('exact UI-spec strings', () {
      expect(redeemErrorMessage('not-found'), 'Code not found');
      expect(redeemErrorMessage('expired'),
          'Code expired — ask your dietician for a new one');
      expect(redeemErrorMessage('already-used'), 'Code already used');
      expect(
          redeemErrorMessage('already-connected'), "You're already connected");
      expect(redeemErrorMessage('bogus'),
          'Something went wrong. Try again.');
    });
  });
}

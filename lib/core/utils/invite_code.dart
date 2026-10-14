import 'dart:math';

/// Invite code helpers. Source of truth: TECH_SPEC §5.
/// 6-char code from ABCDEFGHJKLMNPQRSTUVWXYZ23456789 (no I, O, 0, 1).
const String inviteAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

final _codeChars = inviteAlphabet.split('');

/// Generates a random 6-char invite code. [random] is injectable for tests.
String generateInviteCode({Random? random}) {
  final rng = random ?? Random.secure();
  return List.generate(6, (_) => _codeChars[rng.nextInt(_codeChars.length)])
      .join();
}

/// Strict check mirroring the function's format gate.
bool isValidInviteCode(String value) =>
    RegExp(r'^[A-HJ-NP-Z2-9]{6}$').hasMatch(value.toUpperCase().trim());

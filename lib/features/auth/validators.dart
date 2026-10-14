// Pure validation helpers for the auth flow (unit-tested).

/// Display name rule from UI spec S02: required, 2–40 chars.
bool isValidDisplayName(String value) {
  final trimmed = value.trim();
  return trimmed.length >= 2 && trimmed.length <= 40;
}

/// Minimal email sanity check for enabling the submit button.
/// Firebase returns the exact error strings on submit.
bool looksLikeEmail(String value) {
  final trimmed = value.trim();
  if (!trimmed.contains('@')) return false;
  final parts = trimmed.split('@');
  return parts.length == 2 && parts[0].isNotEmpty && parts[1].contains('.');
}

/// Meal tag helpers. Source of truth: UI spec S06 table + TECH_SPEC §9.1.
///
/// 05:00–10:59 breakfast, 11:00–14:59 lunch, 15:00–18:59 snack,
/// 19:00–22:59 dinner, 23:00–04:59 snack.
String tagForTime(DateTime local) {
  final h = local.hour;
  if (h >= 5 && h < 11) return 'breakfast';
  if (h >= 11 && h < 15) return 'lunch';
  if (h >= 15 && h < 19) return 'snack';
  if (h >= 19 && h < 23) return 'dinner';
  return 'snack'; // 23:00–04:59
}

/// `yyyy-MM-dd` in the device's local time. Used for grouping + streaks.
String localDateString(DateTime local) {
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '${local.year}-$m-$d';
}

/// `HH:mm` in the device's local time.
String localTimeString(DateTime local) {
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

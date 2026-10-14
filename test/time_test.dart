import 'package:flutter_test/flutter_test.dart';

import 'package:foodsnap/core/utils/time.dart';

void main() {
  group('tagForTime (UI spec S06)', () {
    test('morning maps to breakfast', () {
      expect(tagForTime(DateTime(2026, 1, 1, 5)), 'breakfast');
      expect(tagForTime(DateTime(2026, 1, 1, 10, 59)), 'breakfast');
    });
    test('midday maps to lunch', () {
      expect(tagForTime(DateTime(2026, 1, 1, 11)), 'lunch');
      expect(tagForTime(DateTime(2026, 1, 1, 14, 59)), 'lunch');
    });
    test('afternoon maps to snack', () {
      expect(tagForTime(DateTime(2026, 1, 1, 15)), 'snack');
      expect(tagForTime(DateTime(2026, 1, 1, 18, 59)), 'snack');
    });
    test('evening maps to dinner', () {
      expect(tagForTime(DateTime(2026, 1, 1, 19)), 'dinner');
      expect(tagForTime(DateTime(2026, 1, 1, 22, 59)), 'dinner');
    });
    test('late night maps to snack', () {
      expect(tagForTime(DateTime(2026, 1, 1, 23)), 'snack');
      expect(tagForTime(DateTime(2026, 1, 1, 4, 59)), 'snack');
    });
  });

  group('local date/time strings', () {
    test('pads correctly', () {
      expect(localDateString(DateTime(2026, 3, 5)), '2026-03-05');
      expect(localTimeString(DateTime(2026, 3, 5, 9, 7)), '09:07');
    });
  });
}

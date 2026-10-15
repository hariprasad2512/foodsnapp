import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foodsnap/data/repositories/auth_repository.dart';
import 'package:foodsnap/features/camera/meal_tag_chip.dart';
import 'package:foodsnap/features/camera/preview_screen.dart';

/// 1×1 transparent PNG — stands in for captured bytes (S06 shows them with
/// Image.memory; decoding runs async and never blocks the assertions).
Uint8List get _pngBytes => base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );

/// S06 reads the active relationship; stub auth out so no Firebase is hit.
Widget _scoped(Widget child) => ProviderScope(
      overrides: [
        authStateProvider.overrideWith(
          (ref) => Stream<User?>.value(null),
        ),
      ],
      child: MaterialApp(home: child),
    );

void main() {
  group('MealTagChip (UI spec §7)', () {
    testWidgets('tap selects the chip', (tester) async {
      var selected = 'lunch';
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => MealTagChip(
              tag: 'dinner',
              selected: selected == 'dinner',
              onTap: () => setState(() => selected = 'dinner'),
            ),
          ),
        ),
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is MealTagChip && w.tag == 'dinner' && !w.selected,
        ),
        findsOneWidget,
      );
      await tester.tap(find.byType(MealTagChip));
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (w) => w is MealTagChip && w.tag == 'dinner' && w.selected,
        ),
        findsOneWidget,
      );
    });
  });

  group('S06 default tag (UI spec S06 table)', () {
    testWidgets('morning preselects Breakfast', (tester) async {
      await tester.pumpWidget(
        _scoped(
          PreviewScreen(
            imageBytes: _pngBytes,
            now: DateTime(2026, 1, 1, 8, 30),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) => w is MealTagChip && w.tag == 'breakfast' && w.selected,
        ),
        findsOneWidget,
      );
    });

    testWidgets('evening preselects Dinner', (tester) async {
      await tester.pumpWidget(
        _scoped(
          PreviewScreen(
            imageBytes: _pngBytes,
            now: DateTime(2026, 1, 1, 20, 15),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) => w is MealTagChip && w.tag == 'dinner' && w.selected,
        ),
        findsOneWidget,
      );
    });
  });
}

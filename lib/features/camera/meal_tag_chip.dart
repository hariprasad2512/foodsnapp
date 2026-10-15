import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// Tag metadata: label + dot color (UI spec §5). Never rely on color alone —
/// the text label is always shown (UI spec §10).
const mealTags = ['breakfast', 'lunch', 'snack', 'dinner'];

String mealTagLabel(String tag) => switch (tag) {
      'breakfast' => 'Breakfast',
      'lunch' => 'Lunch',
      'snack' => 'Snack',
      'dinner' => 'Dinner',
      _ => tag,
    };

Color mealTagColor(String tag) => switch (tag) {
      'breakfast' => AppTokens.breakfast,
      'lunch' => AppTokens.lunch,
      'snack' => AppTokens.snack,
      'dinner' => AppTokens.dinner,
      _ => AppTokens.snack,
    };

/// Pill chip with tag color dot + label (UI spec §7). Selected state =
/// filled with tag color at 15% opacity and a 1.5 dp outline.
class MealTagChip extends StatelessWidget {
  final String tag;
  final bool selected;
  final VoidCallback onTap;

  const MealTagChip({
    super.key,
    required this.tag,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = mealTagColor(tag);
    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        selected: selected,
        button: true,
        label: mealTagLabel(tag),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.15) : Colors.white10,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? color : Colors.white24,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                mealTagLabel(tag),
                style: AppTokens.label.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

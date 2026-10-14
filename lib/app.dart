import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'router.dart';

/// Root widget. M0 only: MaterialApp.router + light/dark themes from tokens.
/// On web width > 480px the app centers in a 480px column (UI spec §5).
class FoodSnapApp extends ConsumerWidget {
  const FoodSnapApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'FoodSnapp',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}

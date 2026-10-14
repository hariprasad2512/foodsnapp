import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository.dart';

/// M3 placeholder for S13: just sign-out (needed to switch test accounts).
/// Full settings UI lands in M5.
class SettingsStubScreen extends ConsumerWidget {
  const SettingsStubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: TextButton(
          onPressed: () => ref.read(authRepositoryProvider).signOut(),
          child: const Text('Sign out'),
        ),
      ),
    );
  }
}

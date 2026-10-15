import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/user_repository.dart';

/// S13 — Settings (minimal, UI spec). Display name, email, role (all
/// read-only), a notification status row, Sign out, app version.
/// No account deletion UI in v1.
///
/// Spark note (TECH_SPEC §17): push is descoped without Blaze, so the
/// notification row is status text instead of a toggle. TODO(Blaze).
class SettingsStubScreen extends ConsumerWidget {
  const SettingsStubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final auth = ref.watch(authStateProvider);
    final user = auth.hasValue ? auth.value : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Something went wrong: $e')),
        data: (prof) => ListView(
          children: [
            _Row(
              label: 'Name',
              value: prof?.displayName ?? '—',
            ),
            _Row(
              label: 'Email',
              value: user?.email ?? prof?.email ?? '—',
            ),
            _Row(
              label: 'Role',
              value: prof?.role ?? '—',
            ),
            const _Row(
              label: 'Notifications',
              value: "Not available in this trial build",
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton(
                onPressed: () =>
                    ref.read(authRepositoryProvider).signOut(),
                child: const Text('Sign out'),
              ),
            ),
            const SizedBox(height: 16),
            const Center(child: _VersionRow()),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      subtitle: Text(value),
    );
  }
}

class _VersionRow extends StatelessWidget {
  const _VersionRow();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) => Text(
        snap.hasData ? 'FoodSnapp ${snap.data!.version}' : 'FoodSnapp',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

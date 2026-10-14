import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/user_repository.dart';
import 'validators.dart';

/// S02 — Role & name. Source of truth: UI spec §6 S02.
/// Writes the profile doc once; role is immutable afterwards.
class RoleScreen extends ConsumerStatefulWidget {
  const RoleScreen({super.key});

  @override
  ConsumerState<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends ConsumerState<RoleScreen> {
  final _name = TextEditingController();
  String? _role; // 'client' | 'dietician'
  bool _busy = false;
  String? _error;
  bool _prefilled = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final auth = ref.read(authStateProvider);
    final user = auth.hasValue ? auth.value : null;
    if (user == null || _role == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(userRepositoryProvider).createProfile(
            uid: user.uid,
            role: _role!,
            displayName: _name.text.trim(),
            email: user.email ?? '',
          );
      // Router redirect handles the rest.
    } catch (_) {
      setState(() => _error = 'No internet connection');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Prefill name from Google account on first build.
    if (!_prefilled) {
      _prefilled = true;
      final auth = ref.read(authStateProvider);
      final displayName = auth.hasValue ? auth.value?.displayName : null;
      if (displayName != null && displayName.isNotEmpty) {
        _name.text = displayName;
      }
    }
    final canContinue =
        _role != null && isValidDisplayName(_name.text) && !_busy;
    return Scaffold(
      appBar: AppBar(title: const Text('Who are you?')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                enabled: !_busy,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'Your name',
                  border: OutlineInputBorder(),
                  helperText: "You can't change this later.",
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                title: "I'm logging my meals",
                subtitle: 'Client',
                selected: _role == 'client',
                onTap: _busy ? null : () => setState(() => _role = 'client'),
              ),
              const SizedBox(height: 12),
              _RoleCard(
                title: "I'm a dietician",
                subtitle: 'Dietician',
                selected: _role == 'dietician',
                onTap:
                    _busy ? null : () => setState(() => _role = 'dietician'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const Spacer(),
              FilledButton(
                onPressed: canContinue ? _continue : null,
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).dividerColor,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

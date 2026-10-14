import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/invite.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/invite_repository.dart';
import '../../data/repositories/user_repository.dart';

/// S11 — Invite sheet (dietician). Source of truth: UI spec §6 S11.
/// Opening the sheet creates a fresh invite. Shows active invites with
/// a Revoke action underneath.
class InviteSheet extends ConsumerStatefulWidget {
  const InviteSheet({super.key});

  @override
  ConsumerState<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<InviteSheet> {
  Future<Invite>? _fresh;

  Future<Invite> _create(String dieticianName) async {
    final auth = ref.read(authStateProvider);
    final user = auth.hasValue ? auth.value : null;
    if (user == null) throw StateError('signed out');
    return ref.read(inviteRepositoryProvider).createInvite(
          dieticianId: user.uid,
          dieticianName: dieticianName,
        );
  }

  @override
  Widget build(BuildContext context) {
    // Start creating once the profile (with the dietician's name) is in.
    final profile = ref.watch(profileProvider);
    final name =
        profile.hasValue ? profile.value?.displayName : null;
    if (_fresh == null && (name ?? '').isNotEmpty) {
      _fresh = _create(name!);
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Invite a client',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            FutureBuilder<Invite>(
              future: _fresh,
              builder: (context, snap) {
                if (_fresh == null ||
                    snap.connectionState != ConnectionState.done) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                if (snap.hasError || !snap.hasData) {
                  return const Text(
                      'Could not create a code. Check your connection and reopen.');
                }
                final invite = snap.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      onTap: () => Clipboard.setData(
                          ClipboardData(text: invite.code)),
                      child: Center(
                        child: Text(
                          invite.code,
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(letterSpacing: 8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Valid for 48 hours · one use',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Clipboard.setData(
                                ClipboardData(text: invite.code)),
                            child: const Text('Copy code'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => SharePlus.instance.share(
                              ShareParams(
                                text:
                                    'Join me on FoodSnapp. Install the app and use code ${invite.code}.',
                              ),
                            ),
                            child: const Text('Share'),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Text('Active invites',
                style: Theme.of(context).textTheme.titleSmall),
            const _ActiveInvites(),
          ],
        ),
      ),
    );
  }
}

class _ActiveInvites extends ConsumerWidget {
  const _ActiveInvites();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final user = auth.hasValue ? auth.value : null;
    if (user == null) return const SizedBox.shrink();
    final invites = ref
        .watch(inviteRepositoryProvider)
        .watchMyInvites(user.uid);
    return StreamBuilder<List<Invite>>(
      stream: invites,
      builder: (context, snap) {
        final all = snap.data ?? const <Invite>[];
        final now = DateTime.now();
        final active = all
            .where((i) =>
                !i.revoked &&
                i.usedBy == null &&
                (i.expiresAt == null || i.expiresAt!.isAfter(now)))
            .toList();
        if (active.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No active invites.'),
          );
        }
        return Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: active.length,
            itemBuilder: (context, i) {
              final invite = active[i];
              final hoursLeft = invite.expiresAt
                  ?.difference(now)
                  .inHours
                  .clamp(0, 48);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(invite.code),
                subtitle: hoursLeft == null
                    ? null
                    : Text('Expires in $hoursLeft h'),
                trailing: TextButton(
                  onPressed: () => ref
                      .read(inviteRepositoryProvider)
                      .revokeInvite(invite.code),
                  child: const Text('Revoke'),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

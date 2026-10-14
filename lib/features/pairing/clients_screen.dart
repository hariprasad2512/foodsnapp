import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'relationship_providers.dart';
import 'invite_sheet.dart';

/// S10 — Clients list, M3 minimal: empty state + bare rows.
/// Full polish (badges, sorting, "No log today", streaks) lands in M9.
class ClientsScreen extends ConsumerWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clients = ref.watch(clientsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.account_circle),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showInviteSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add client'),
      ),
      body: clients.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Something went wrong: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No clients yet. Tap Add client to invite your first one.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final rel = list[i];
              return ListTile(
                leading: CircleAvatar(
                  child: Text(
                    rel.clientName.isEmpty
                        ? '?'
                        : rel.clientName[0].toUpperCase(),
                  ),
                ),
                title: Text(rel.clientName.isEmpty ? 'Client' : rel.clientName),
                onTap: () => context.push('/clients/${rel.id}'),
              );
            },
          );
        },
      ),
    );
  }
}

/// Opens the S11 invite sheet. Exported for reuse.
void showInviteSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const InviteSheet(),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'data/repositories/auth_repository.dart';
import 'data/repositories/user_repository.dart';
import 'features/auth/role_screen.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/pairing/clients_screen.dart';
import 'features/pairing/join_screen.dart';
import 'features/pairing/relationship_providers.dart';
import 'features/settings/settings_screen.dart';

/// go_router with the TECH_SPEC §8 redirect order:
/// 1. no user → /signin · 2. no profile → /role · 3. client without
/// relationship → /join · 4. client → /home · 5. dietician → /clients.
///
/// Full route set per §8; non-M3 routes are stubs until their milestone.
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);
  final profile = ref.watch(profileProvider);
  final rel = ref.watch(activeRelationshipProvider);

  return GoRouter(
    initialLocation: '/signin',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (auth.isLoading || profile.isLoading || rel.isLoading) return null;

      final user = auth.hasValue ? auth.value : null;
      if (user == null) {
        return loc == '/signin' ? null : '/signin';
      }
      final prof = profile.hasValue ? profile.value : null;
      if (prof == null) {
        return loc == '/role' ? null : '/role';
      }
      if (prof.role == 'dietician') {
        if (loc == '/clients' ||
            loc.startsWith('/clients/') ||
            loc == '/settings') {
          return null;
        }
        return '/clients';
      }
      // Client.
      final relationship = rel.hasValue ? rel.value : null;
      if (relationship == null) {
        if (loc == '/join' || loc == '/settings') return null;
        return '/join';
      }
      if (loc == '/home' ||
          loc.startsWith('/meal/') ||
          loc == '/settings') {
        return null;
      }
      return '/home';
    },
    routes: [
      GoRoute(
        path: '/signin',
        builder: (c, s) => const SignInScreen(),
      ),
      GoRoute(
        path: '/role',
        builder: (c, s) => const RoleScreen(),
      ),
      GoRoute(
        path: '/join',
        builder: (c, s) => const JoinScreen(),
      ),
      GoRoute(
          path: '/home', builder: (c, s) => const _Stub('S04/S05 Home — M4')),
      GoRoute(
        path: '/meal/:relId/:mealId',
        builder: (c, s) => const _Stub('S09 Meal detail — M7'),
      ),
      GoRoute(
        path: '/clients',
        builder: (c, s) => const ClientsScreen(),
        routes: [
          GoRoute(
            path: ':relId',
            builder: (c, s) => const _Stub('S12 Client detail — M6'),
            routes: [
              GoRoute(
                path: 'meal/:mealId',
                builder: (c, s) => const _Stub('S09 Meal detail — M7'),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (c, s) => const SettingsStubScreen(),
      ),
    ],
  );
});

class _Stub extends StatelessWidget {
  final String label;
  const _Stub(this.label);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FoodSnapp · M3')),
      body: Center(child: Text(label)),
    );
  }
}

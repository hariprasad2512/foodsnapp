import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';

/// M2 entrypoint: Firebase init (options from `flutterfire configure`),
/// then the app. Auth + Firestore run against the real project;
/// emulators can be pointed at with --dart-define later if needed.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: FoodSnapApp()));
}

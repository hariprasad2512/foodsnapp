/// Platform shims. Real implementations land in M4/M5 behind conditional
/// imports so Android + web both compile (see TECH_SPEC §10).
///
/// Usage: `import 'platform.dart';` — the correct file is picked at compile
/// time via `platform_stub.dart` default.
library;

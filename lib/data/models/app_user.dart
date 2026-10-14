// TODO(spec): full models land with their milestones. v1 field lists are in
// TECH_SPEC §5. Models are plain Dart classes with fromMap/toMap, no codegen.

class AppUser {
  final String uid;
  final String role; // "client" | "dietician" — immutable after creation
  final String displayName;
  final String email;
  final String timezone;
  final DateTime? createdAt;

  const AppUser({
    required this.uid,
    required this.role,
    required this.displayName,
    required this.email,
    required this.timezone,
    this.createdAt,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) => AppUser(
        uid: uid,
        role: map['role'] as String,
        displayName: map['displayName'] as String? ?? '',
        email: map['email'] as String? ?? '',
        timezone: map['timezone'] as String? ?? 'Asia/Kolkata',
      );

  Map<String, dynamic> toMap() => {
        'role': role,
        'displayName': displayName,
        'email': email,
        'timezone': timezone,
      };
}

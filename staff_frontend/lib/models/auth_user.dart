class AuthUser {
  final int userId;
  final String username;
  final String role; // primary role
  final List<String> roles; // effective roles (primary + additional)
  final int tenantId;
  final bool mustChangePassword;

  const AuthUser({
    required this.userId,
    required this.username,
    required this.role,
    required this.roles,
    required this.tenantId,
    this.mustChangePassword = false,
  });

  AuthUser copyWith({bool? mustChangePassword}) => AuthUser(
        userId: userId,
        username: username,
        role: role,
        roles: roles,
        tenantId: tenantId,
        mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      );

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final role = json['role'] as String;
    final roles = ((json['roles'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    return AuthUser(
      userId: json['user_id'] as int,
      username: json['username'] as String,
      role: role,
      roles: roles.isEmpty ? [role] : roles,
      tenantId: json['tenant_id'] as int,
      mustChangePassword: (json['must_change_password'] as bool?) ?? false,
    );
  }

  bool hasRole(String r) => roles.contains(r);

  /// Effective roles, primary first (never empty).
  List<String> get effectiveRoles => roles.isEmpty ? [role] : roles;
}

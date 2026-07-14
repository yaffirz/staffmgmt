class AuthUser {
  final int userId;
  final String username;
  final String role;
  final int tenantId;

  const AuthUser({
    required this.userId,
    required this.username,
    required this.role,
    required this.tenantId,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      userId: json['user_id'] as int,
      username: json['username'] as String,
      role: json['role'] as String,
      tenantId: json['tenant_id'] as int,
    );
  }
}

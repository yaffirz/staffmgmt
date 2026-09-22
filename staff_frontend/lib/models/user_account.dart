class UserAccount {
  final int userId;
  final String username;
  final String? email;
  final String role; // primary role
  final List<String> roles; // effective roles (primary + additional)
  final List<String> additionalRoles;
  final List<int> brandIds;
  final List<String> brandNames;
  final int? storeId; // Store / Foodmall
  final String? storeName;
  final bool mustChangePassword;
  final bool suspended;
  final bool emailOptIn;

  const UserAccount({
    required this.userId,
    required this.username,
    required this.email,
    required this.role,
    this.roles = const [],
    this.additionalRoles = const [],
    this.brandIds = const [],
    this.brandNames = const [],
    this.storeId,
    this.storeName,
    this.mustChangePassword = false,
    this.suspended = false,
    this.emailOptIn = true,
  });

  factory UserAccount.fromJson(Map<String, dynamic> j) {
    final role = j['role'] as String;
    final roles = ((j['roles'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    return UserAccount(
      userId: j['user_id'] as int,
      username: j['username'] as String,
      email: j['email'] as String?,
      role: role,
      roles: roles.isEmpty ? [role] : roles,
      additionalRoles: ((j['additional_roles'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      brandIds: ((j['brand_ids'] as List?) ?? const [])
          .map((e) => e as int)
          .toList(),
      brandNames: ((j['brand_names'] as List?) ?? const [])
          .map((e) => e as String)
          .toList(),
      storeId: j['store_id'] as int?,
      storeName: j['store_name'] as String?,
      mustChangePassword: (j['must_change_password'] as bool?) ?? false,
      suspended: (j['suspended'] as bool?) ?? false,
      emailOptIn: (j['email_opt_in'] as bool?) ?? true,
    );
  }
}

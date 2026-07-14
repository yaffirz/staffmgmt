class UserAccount {
  final int userId;
  final String username;
  final String? email;
  final String role;
  final List<int> brandIds;
  final List<String> brandNames;

  const UserAccount({
    required this.userId,
    required this.username,
    required this.email,
    required this.role,
    this.brandIds = const [],
    this.brandNames = const [],
  });

  factory UserAccount.fromJson(Map<String, dynamic> j) => UserAccount(
        userId: j['user_id'] as int,
        username: j['username'] as String,
        email: j['email'] as String?,
        role: j['role'] as String,
        brandIds: ((j['brand_ids'] as List?) ?? const [])
            .map((e) => e as int)
            .toList(),
        brandNames: ((j['brand_names'] as List?) ?? const [])
            .map((e) => e as String)
            .toList(),
      );
}

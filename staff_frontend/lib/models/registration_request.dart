/// A self-service sign-up awaiting admin review, from `GET /api/v1/registrations`.
class RegistrationRequest {
  final int id;
  final String username;
  final String email;
  final String status; // pending_email | pending_approval | approved | rejected
  final bool emailVerified;
  final String? note;
  final String? confirmPath; // relative confirm link (while email isn't live)
  final String createdAt;

  const RegistrationRequest({
    required this.id,
    required this.username,
    required this.email,
    required this.status,
    required this.emailVerified,
    this.note,
    this.confirmPath,
    required this.createdAt,
  });

  bool get isPending =>
      status == 'pending_email' || status == 'pending_approval';

  factory RegistrationRequest.fromJson(Map<String, dynamic> j) =>
      RegistrationRequest(
        id: j['id'] as int,
        username: j['username'] as String,
        email: j['email'] as String,
        status: j['status'] as String,
        emailVerified: (j['email_verified'] as bool?) ?? false,
        note: j['note'] as String?,
        confirmPath: j['confirm_path'] as String?,
        createdAt: (j['created_at'] ?? '').toString(),
      );
}

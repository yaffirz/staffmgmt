/// Public maintenance state, from `GET /api/v1/maintenance/status`.
class MaintenanceStatus {
  final bool active;
  final String message;
  final DateTime? until; // parsed from an ISO-8601 string, or null

  const MaintenanceStatus({
    required this.active,
    this.message = '',
    this.until,
  });

  static const inactive = MaintenanceStatus(active: false);

  factory MaintenanceStatus.fromJson(Map<String, dynamic> j) {
    final rawUntil = j['until'] as String?;
    return MaintenanceStatus(
      active: (j['active'] as bool?) ?? false,
      message: (j['message'] as String?) ?? '',
      until: (rawUntil == null || rawUntil.isEmpty)
          ? null
          : DateTime.tryParse(rawUntil),
    );
  }
}

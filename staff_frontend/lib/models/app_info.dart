/// Whether the Android app is available to download, from `GET /api/v1/app/info`.
class AppInfo {
  final bool enabled;
  final bool available;
  final String? filename;
  final int sizeBytes;
  final DateTime? updatedAt;

  const AppInfo({
    required this.enabled,
    required this.available,
    this.filename,
    this.sizeBytes = 0,
    this.updatedAt,
  });

  static const none = AppInfo(enabled: false, available: false);

  String get sizeLabel {
    if (sizeBytes <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB'];
    double s = sizeBytes.toDouble();
    int i = 0;
    while (s >= 1024 && i < units.length - 1) {
      s /= 1024;
      i++;
    }
    return '${s.toStringAsFixed(s < 10 && i > 0 ? 1 : 0)} ${units[i]}';
  }

  String? get updatedLabel {
    if (updatedAt == null) return null;
    final d = updatedAt!.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.month)}/${two(d.day)}/${d.year}';
  }

  factory AppInfo.fromJson(Map<String, dynamic> j) => AppInfo(
        enabled: (j['enabled'] as bool?) ?? false,
        available: (j['available'] as bool?) ?? false,
        filename: j['filename'] as String?,
        sizeBytes: (j['size_bytes'] as int?) ?? 0,
        updatedAt: (j['updated_at'] as String?) != null
            ? DateTime.tryParse(j['updated_at'] as String)
            : null,
      );
}

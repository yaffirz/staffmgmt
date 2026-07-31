/// A database backup row, from the backups endpoints.
class BackupItem {
  final int id;
  final String filename;
  final String status; // running | completed | failed
  final String kind; // manual | scheduled
  final int sizeBytes;
  final int? createdBy;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final String? error;

  const BackupItem({
    required this.id,
    required this.filename,
    required this.status,
    required this.kind,
    required this.sizeBytes,
    required this.createdBy,
    required this.startedAt,
    required this.finishedAt,
    required this.error,
  });

  bool get isRunning => status == 'running';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  Duration? get duration =>
      finishedAt == null ? null : finishedAt!.difference(startedAt);

  String get sizeLabel {
    if (sizeBytes <= 0) return '—';
    const units = ['B', 'KB', 'MB', 'GB'];
    double s = sizeBytes.toDouble();
    int i = 0;
    while (s >= 1024 && i < units.length - 1) {
      s /= 1024;
      i++;
    }
    return '${s.toStringAsFixed(s < 10 && i > 0 ? 1 : 0)} ${units[i]}';
  }

  String get startedLabel {
    final d = startedAt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.month)}/${two(d.day)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  factory BackupItem.fromJson(Map<String, dynamic> j) => BackupItem(
        id: j['id'] as int,
        filename: j['filename'] as String,
        status: j['status'] as String,
        kind: (j['kind'] as String?) ?? 'manual',
        sizeBytes: (j['size_bytes'] as int?) ?? 0,
        createdBy: j['created_by'] as int?,
        startedAt: DateTime.parse(j['started_at'] as String),
        finishedAt: (j['finished_at'] as String?) != null
            ? DateTime.parse(j['finished_at'] as String)
            : null,
        error: j['error'] as String?,
      );
}

class BackupSchedule {
  final String schedule; // off | daily | weekly
  final String time; // HH:MM
  final int retention;

  const BackupSchedule({
    required this.schedule,
    required this.time,
    required this.retention,
  });

  factory BackupSchedule.fromJson(Map<String, dynamic> j) => BackupSchedule(
        schedule: (j['schedule'] as String?) ?? 'off',
        time: (j['time'] as String?) ?? '02:00',
        retention: (j['retention'] as int?) ?? 10,
      );
}

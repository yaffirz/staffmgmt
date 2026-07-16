class AuditLogEntry {
  final int auditId;
  final int userId;
  final String userName;
  final String action; // INSERT | UPDATE | DELETE
  final String affectedTable;
  final String recordId;
  final Map<String, dynamic>? oldValue;
  final Map<String, dynamic>? newValue;
  final DateTime timestamp;
  final String summary;

  const AuditLogEntry({
    required this.auditId,
    required this.userId,
    required this.userName,
    required this.action,
    required this.affectedTable,
    required this.recordId,
    required this.oldValue,
    required this.newValue,
    required this.timestamp,
    required this.summary,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> j) => AuditLogEntry(
        auditId: j['audit_id'] as int,
        userId: j['user_id'] as int,
        userName: (j['user_name'] as String?) ?? 'Unknown',
        action: j['action'] as String,
        affectedTable: j['affected_table'] as String,
        recordId: j['record_id'] as String,
        oldValue: (j['old_value'] as Map?)?.cast<String, dynamic>(),
        newValue: (j['new_value'] as Map?)?.cast<String, dynamic>(),
        timestamp: DateTime.parse(j['timestamp'] as String),
        summary: (j['summary'] as String?) ?? j['action'] as String,
      );

  String get whenDisplay {
    final d = timestamp.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.month)}/${two(d.day)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}

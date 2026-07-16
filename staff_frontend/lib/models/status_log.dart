class StatusLogEntry {
  final int logId;
  final int employeeId;
  final String employeeName;
  final String actionType;
  final Map<String, dynamic> details;
  final String processedByName;
  final DateTime timestamp;
  final String summary;

  const StatusLogEntry({
    required this.logId,
    required this.employeeId,
    required this.employeeName,
    required this.actionType,
    required this.details,
    required this.processedByName,
    required this.timestamp,
    required this.summary,
  });

  factory StatusLogEntry.fromJson(Map<String, dynamic> j) => StatusLogEntry(
        logId: j['log_id'] as int,
        employeeId: j['employee_id'] as int,
        employeeName: (j['employee_name'] as String?) ?? 'Staff',
        actionType: j['action_type'] as String,
        details: (j['details'] as Map?)?.cast<String, dynamic>() ?? const {},
        processedByName: (j['processed_by_name'] as String?) ?? 'Unknown',
        timestamp: DateTime.parse(j['timestamp'] as String),
        summary: (j['summary'] as String?) ?? j['action_type'] as String,
      );

  String get dateDisplay {
    final d = timestamp.toLocal();
    return '${d.month.toString().padLeft(2, '0')}/'
        '${d.day.toString().padLeft(2, '0')}/${d.year}';
  }
}

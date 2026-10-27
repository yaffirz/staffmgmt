// Clock-in system models.

class ClockConfig {
  final bool enabled;
  final bool devMode;
  const ClockConfig({required this.enabled, required this.devMode});

  factory ClockConfig.fromJson(Map<String, dynamic> j) => ClockConfig(
        enabled: (j['enabled'] as bool?) ?? false,
        devMode: (j['dev_mode'] as bool?) ?? false,
      );
}

/// An employee's current clock state (who they are + whether a punch would
/// clock them in or out).
class ClockStatus {
  final int employeeId;
  final String employeeName;
  final String payrollId;
  final String? brandName;
  final String? storeName;
  final String? lastEventType; // 'in' | 'out' | null
  final DateTime? lastEventAt;
  final String nextEventType; // 'in' | 'out'

  const ClockStatus({
    required this.employeeId,
    required this.employeeName,
    required this.payrollId,
    this.brandName,
    this.storeName,
    this.lastEventType,
    this.lastEventAt,
    required this.nextEventType,
  });

  bool get isClockedIn => lastEventType == 'in';

  factory ClockStatus.fromJson(Map<String, dynamic> j) => ClockStatus(
        employeeId: j['employee_id'] as int,
        employeeName: j['employee_name'] as String,
        payrollId: j['payroll_id'] as String,
        brandName: j['brand_name'] as String?,
        storeName: j['store_name'] as String?,
        lastEventType: j['last_event_type'] as String?,
        lastEventAt: j['last_event_at'] == null
            ? null
            : DateTime.tryParse(j['last_event_at'].toString()),
        nextEventType: (j['next_event_type'] as String?) ?? 'in',
      );
}

class ClockEvent {
  final int clockEventId;
  final int employeeId;
  final String employeeName;
  final String eventType; // 'in' | 'out'
  final DateTime occurredAt;
  final String source; // 'kiosk' | 'manager' | 'dev'
  final String? note;

  const ClockEvent({
    required this.clockEventId,
    required this.employeeId,
    required this.employeeName,
    required this.eventType,
    required this.occurredAt,
    required this.source,
    this.note,
  });

  factory ClockEvent.fromJson(Map<String, dynamic> j) => ClockEvent(
        clockEventId: j['clock_event_id'] as int,
        employeeId: j['employee_id'] as int,
        employeeName: j['employee_name'] as String,
        eventType: j['event_type'] as String,
        occurredAt: DateTime.parse(j['occurred_at'] as String),
        source: (j['source'] as String?) ?? 'kiosk',
        note: j['note'] as String?,
      );
}

/// Result of a punch: the recorded event + the employee's resulting status.
class PunchResult {
  final ClockEvent event;
  final ClockStatus status;
  const PunchResult({required this.event, required this.status});

  factory PunchResult.fromJson(Map<String, dynamic> j) => PunchResult(
        event: ClockEvent.fromJson(j['event'] as Map<String, dynamic>),
        status: ClockStatus.fromJson(j['status'] as Map<String, dynamic>),
      );
}

class Fingerprint {
  final int fingerprintId;
  final int employeeId;
  final String fingerLabel;
  final bool enrolled;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Fingerprint({
    required this.fingerprintId,
    required this.employeeId,
    required this.fingerLabel,
    required this.enrolled,
    this.createdAt,
    this.updatedAt,
  });

  factory Fingerprint.fromJson(Map<String, dynamic> j) => Fingerprint(
        fingerprintId: j['fingerprint_id'] as int,
        employeeId: j['employee_id'] as int,
        fingerLabel: j['finger_label'] as String,
        enrolled: (j['enrolled'] as bool?) ?? true,
        createdAt: j['created_at'] == null
            ? null
            : DateTime.tryParse(j['created_at'].toString()),
        updatedAt: j['updated_at'] == null
            ? null
            : DateTime.tryParse(j['updated_at'].toString()),
      );
}

/// Result of testing a scan against an employee's enrolled fingerprints.
class FingerprintMatch {
  final bool match;
  final double score;
  final double threshold;
  final String? fingerLabel; // the enrolled finger that matched
  final int enrolledSamples;

  const FingerprintMatch({
    required this.match,
    required this.score,
    required this.threshold,
    this.fingerLabel,
    required this.enrolledSamples,
  });

  factory FingerprintMatch.fromJson(Map<String, dynamic> j) => FingerprintMatch(
        match: (j['match'] as bool?) ?? false,
        score: (j['score'] as num?)?.toDouble() ?? -1,
        threshold: (j['threshold'] as num?)?.toDouble() ?? 40,
        fingerLabel: j['finger_label'] as String?,
        enrolledSamples: (j['enrolled_samples'] as int?) ?? 0,
      );
}

/// Fingers offered in the enrol UI (must match the backend FINGER_LABELS).
const List<String> kFingerLabels = [
  'left-thumb',
  'left-index',
  'left-middle',
  'left-ring',
  'left-little',
  'right-thumb',
  'right-index',
  'right-middle',
  'right-ring',
  'right-little',
];

String fingerLabelPretty(String key) => key
    .split('-')
    .map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
    .join(' ');

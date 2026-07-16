/// A single inbox notification. Rendering is derived from [type] + [payload];
/// the backend keeps payload as a loose JSON object so new trigger types don't
/// require a client change to at least display sensibly.
class AppNotification {
  final int id;
  final String type;
  final Map<String, dynamic> payload;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.payload,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['notification_id'] as int,
        type: j['type'] as String,
        payload: (j['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
        isRead: (j['is_read'] as bool?) ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  String? _s(String key) {
    final v = payload[key];
    return v?.toString();
  }

  int? _i(String key) {
    final v = payload[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// The store this notification points at (for the deep-link drilldown), or
  /// null if the type has no store target.
  int? get targetStoreId {
    switch (type) {
      case 'STAFF_MOVED':
        return _i('to_store_id');
      case 'STAFF_REQUESTED':
        return _i('requested_store_id');
      default:
        return null;
    }
  }

  String? get targetStoreName {
    switch (type) {
      case 'STAFF_MOVED':
        return _s('to_store_name');
      case 'STAFF_REQUESTED':
        return _s('requested_store_name');
      default:
        return null;
    }
  }

  /// The employee to highlight in the drilldown.
  int? get targetEmployeeId => _i('employee_id');

  /// Short headline for the notification tile.
  String get title {
    switch (type) {
      case 'STAFF_MOVED':
        return 'Staff moved';
      case 'STAFF_REQUESTED':
        return 'Staff requested';
      case 'STAFF_PROMOTED':
        return 'Staff promoted';
      case 'STAFF_DEMOTED':
        return 'Staff role changed';
      case 'STAFF_TERMINATED':
        return 'Staff terminated';
      case 'STAFF_REACTIVATED':
        return 'Staff reactivated';
      default:
        return _prettifyType();
    }
  }

  /// Human-readable body line.
  String get body {
    switch (type) {
      case 'STAFF_MOVED':
        final who = _s('employee_name') ?? 'A staff member';
        final store = _s('to_store_name') ?? 'another store';
        final by = _s('by_username');
        return by == null
            ? '$who moved to $store.'
            : '$who moved to $store by $by.';
      case 'STAFF_REQUESTED':
        final who = _s('employee_name') ?? 'a staff member';
        final store = _s('requested_store_name') ?? 'a store';
        final by = _s('by_username') ?? 'An area manager';
        return '$by requested $who for $store.';
      case 'STAFF_PROMOTED':
      case 'STAFF_DEMOTED':
        final who = _s('employee_name') ?? 'A staff member';
        final pos = _s('to_position_title');
        final by = _s('by_username') ?? 'HR';
        final verb = type == 'STAFF_PROMOTED' ? 'promoted' : 'moved';
        return pos == null
            ? '$who $verb by $by.'
            : '$who $verb to $pos by $by.';
      case 'STAFF_TERMINATED':
        final who = _s('employee_name') ?? 'A staff member';
        final by = _s('by_username') ?? 'HR';
        return '$who terminated by $by.';
      case 'STAFF_REACTIVATED':
        final who = _s('employee_name') ?? 'A staff member';
        final by = _s('by_username') ?? 'HR';
        return '$who reactivated by $by.';
      default:
        return payload.isEmpty ? '' : payload.toString();
    }
  }

  /// True for notifications that should open the employee's staff page (rather
  /// than a store drilldown).
  bool get opensStaffPage =>
      type == 'STAFF_PROMOTED' ||
      type == 'STAFF_DEMOTED' ||
      type == 'STAFF_TERMINATED' ||
      type == 'STAFF_REACTIVATED';

  String _prettifyType() {
    return type
        .split('_')
        .map((w) => w.isEmpty ? w : w[0] + w.substring(1).toLowerCase())
        .join(' ');
  }

  /// Compact relative age, e.g. "just now", "5m", "3h", "2d".
  String get ageDisplay {
    final diff = DateTime.now().difference(createdAt.toLocal());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

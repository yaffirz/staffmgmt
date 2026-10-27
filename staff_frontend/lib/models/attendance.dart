// Attendance register models (weekly, per store).

class AttendanceStore {
  final int storeId;
  final String storeName;
  const AttendanceStore({required this.storeId, required this.storeName});

  factory AttendanceStore.fromJson(Map<String, dynamic> j) => AttendanceStore(
        storeId: j['store_id'] as int,
        storeName: j['store_name'] as String,
      );
}

class AttendanceDay {
  final String date; // YYYY-MM-DD
  final String weekday;
  final String? roster;
  final String? inTime;
  final String? outTime;
  final String? hours;

  const AttendanceDay({
    required this.date,
    required this.weekday,
    this.roster,
    this.inTime,
    this.outTime,
    this.hours,
  });

  factory AttendanceDay.fromJson(Map<String, dynamic> j) => AttendanceDay(
        date: j['date'] as String,
        weekday: j['weekday'] as String,
        roster: j['roster'] as String?,
        inTime: j['in_time'] as String?,
        outTime: j['out_time'] as String?,
        hours: j['hours'] as String?,
      );

  /// MM/DD day-of-month for the compact Date column.
  String get dayNum {
    final parts = date.split('-');
    return parts.length == 3 ? parts[2] : date;
  }
}

class AttendanceRow {
  final int employeeId;
  final String employeeName;
  final String payrollId;
  final List<AttendanceDay> days;
  final String totalHours;

  const AttendanceRow({
    required this.employeeId,
    required this.employeeName,
    required this.payrollId,
    required this.days,
    required this.totalHours,
  });

  factory AttendanceRow.fromJson(Map<String, dynamic> j) => AttendanceRow(
        employeeId: j['employee_id'] as int,
        employeeName: j['employee_name'] as String,
        payrollId: j['payroll_id'] as String,
        days: ((j['days'] as List?) ?? const [])
            .map((e) => AttendanceDay.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalHours: j['total_hours'] as String? ?? '0:00',
      );
}

class AttendanceRegister {
  final int storeId;
  final String storeName;
  final String weekStart;
  final String weekEnd;
  final List<AttendanceRow> employees;

  const AttendanceRegister({
    required this.storeId,
    required this.storeName,
    required this.weekStart,
    required this.weekEnd,
    required this.employees,
  });

  factory AttendanceRegister.fromJson(Map<String, dynamic> j) => AttendanceRegister(
        storeId: j['store_id'] as int,
        storeName: j['store_name'] as String,
        weekStart: j['week_start'] as String,
        weekEnd: j['week_end'] as String,
        employees: ((j['employees'] as List?) ?? const [])
            .map((e) => AttendanceRow.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

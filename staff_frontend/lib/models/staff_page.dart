class StaffPageEmployee {
  final int employeeId;
  final String employeeName;
  final String payrollId;
  final int? positionId;
  final String? positionTitle;
  final String? storeName;
  final int? brandId;
  final String? brandName;
  final String employmentStatus;

  const StaffPageEmployee({
    required this.employeeId,
    required this.employeeName,
    required this.payrollId,
    required this.positionId,
    required this.positionTitle,
    required this.storeName,
    required this.brandId,
    required this.brandName,
    required this.employmentStatus,
  });

  bool get isTerminated => employmentStatus == 'terminated';

  factory StaffPageEmployee.fromJson(Map<String, dynamic> j) => StaffPageEmployee(
        employeeId: j['employee_id'] as int,
        employeeName: j['employee_name'] as String,
        payrollId: j['payroll_id'] as String,
        positionId: j['position_id'] as int?,
        positionTitle: j['position_title'] as String?,
        storeName: j['store_name'] as String?,
        brandId: j['brand_id'] as int?,
        brandName: j['brand_name'] as String?,
        employmentStatus: (j['employment_status'] as String?) ?? 'active',
      );
}

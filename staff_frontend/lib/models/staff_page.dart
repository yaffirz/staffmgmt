class StaffPageEmployee {
  final int employeeId;
  final String employeeName;
  final String payrollId;
  final String? positionTitle;
  final String? storeName;
  final int? brandId;
  final String? brandName;

  const StaffPageEmployee({
    required this.employeeId,
    required this.employeeName,
    required this.payrollId,
    required this.positionTitle,
    required this.storeName,
    required this.brandId,
    required this.brandName,
  });

  factory StaffPageEmployee.fromJson(Map<String, dynamic> j) => StaffPageEmployee(
        employeeId: j['employee_id'] as int,
        employeeName: j['employee_name'] as String,
        payrollId: j['payroll_id'] as String,
        positionTitle: j['position_title'] as String?,
        storeName: j['store_name'] as String?,
        brandId: j['brand_id'] as int?,
        brandName: j['brand_name'] as String?,
      );
}

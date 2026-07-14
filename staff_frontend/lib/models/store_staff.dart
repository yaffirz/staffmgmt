class StoreStaffMember {
  final int employeeId;
  final String employeeName;
  final String payrollId;
  final String? positionTitle;
  final bool alsoCovers;

  const StoreStaffMember({
    required this.employeeId,
    required this.employeeName,
    required this.payrollId,
    required this.positionTitle,
    required this.alsoCovers,
  });

  factory StoreStaffMember.fromJson(Map<String, dynamic> j) => StoreStaffMember(
        employeeId: j['employee_id'] as int,
        employeeName: j['employee_name'] as String,
        payrollId: j['payroll_id'] as String,
        positionTitle: j['position_title'] as String?,
        alsoCovers: (j['also_covers'] as bool?) ?? false,
      );
}

class StoreStaff {
  final int storeId;
  final String storeName;
  final int brandId;
  final String brandName;
  final List<StoreStaffMember> staff;

  const StoreStaff({
    required this.storeId,
    required this.storeName,
    required this.brandId,
    required this.brandName,
    required this.staff,
  });

  factory StoreStaff.fromJson(Map<String, dynamic> j) => StoreStaff(
        storeId: j['store_id'] as int,
        storeName: j['store_name'] as String,
        brandId: j['brand_id'] as int,
        brandName: j['brand_name'] as String,
        staff: ((j['staff'] as List?) ?? const [])
            .map((e) => StoreStaffMember.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}

// External platforms + Area Manager dashboard models.

class Platform {
  final int platformId;
  final String name;
  final String? color; // hex, optional
  const Platform({required this.platformId, required this.name, this.color});

  factory Platform.fromJson(Map<String, dynamic> j) => Platform(
        platformId: j['platform_id'] as int,
        name: j['name'] as String,
        color: j['color'] as String?,
      );
}

/// A platform tag on an employee (platform + optional per-employee note).
class EmpPlatform {
  final int platformId;
  final String name;
  final String? color;
  final String? note;
  const EmpPlatform(
      {required this.platformId, required this.name, this.color, this.note});

  factory EmpPlatform.fromJson(Map<String, dynamic> j) => EmpPlatform(
        platformId: j['platform_id'] as int,
        name: j['name'] as String,
        color: j['color'] as String?,
        note: j['note'] as String?,
      );
}

class DashStaff {
  final int employeeId;
  final String employeeName;
  final String payrollId;
  final String? positionTitle;
  final List<EmpPlatform> platforms;
  const DashStaff({
    required this.employeeId,
    required this.employeeName,
    required this.payrollId,
    this.positionTitle,
    this.platforms = const [],
  });

  factory DashStaff.fromJson(Map<String, dynamic> j) => DashStaff(
        employeeId: j['employee_id'] as int,
        employeeName: j['employee_name'] as String,
        payrollId: j['payroll_id'] as String,
        positionTitle: j['position_title'] as String?,
        platforms: ((j['platforms'] as List?) ?? const [])
            .map((e) => EmpPlatform.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class DashStore {
  final int storeId;
  final String storeName;
  final List<DashStaff> staff;
  const DashStore(
      {required this.storeId, required this.storeName, this.staff = const []});

  factory DashStore.fromJson(Map<String, dynamic> j) => DashStore(
        storeId: j['store_id'] as int,
        storeName: j['store_name'] as String,
        staff: ((j['staff'] as List?) ?? const [])
            .map((e) => DashStaff.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class DashBrand {
  final int brandId;
  final String brandName;
  const DashBrand({required this.brandId, required this.brandName});

  factory DashBrand.fromJson(Map<String, dynamic> j) => DashBrand(
        brandId: j['brand_id'] as int,
        brandName: j['brand_name'] as String,
      );
}

class AreaDashboard {
  final List<DashBrand> brands;
  final int? brandId;
  final String? brandName;
  final List<DashStore> stores;
  final List<Platform> platformCatalog;
  final bool canEdit;
  const AreaDashboard({
    this.brands = const [],
    this.brandId,
    this.brandName,
    this.stores = const [],
    this.platformCatalog = const [],
    this.canEdit = false,
  });

  factory AreaDashboard.fromJson(Map<String, dynamic> j) => AreaDashboard(
        brands: ((j['brands'] as List?) ?? const [])
            .map((e) => DashBrand.fromJson(e as Map<String, dynamic>))
            .toList(),
        brandId: j['brand_id'] as int?,
        brandName: j['brand_name'] as String?,
        stores: ((j['stores'] as List?) ?? const [])
            .map((e) => DashStore.fromJson(e as Map<String, dynamic>))
            .toList(),
        platformCatalog: ((j['platform_catalog'] as List?) ?? const [])
            .map((e) => Platform.fromJson(e as Map<String, dynamic>))
            .toList(),
        canEdit: (j['can_edit'] as bool?) ?? false,
      );

  int get totalStaff => stores.fold(0, (sum, s) => sum + s.staff.length);
}

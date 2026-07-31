/// Restricted staff entry shown to Store/Foodmall accounts — name only.
class StoreStaffLite {
  final int employeeId;
  final String name;
  const StoreStaffLite({required this.employeeId, required this.name});

  factory StoreStaffLite.fromJson(Map<String, dynamic> j) => StoreStaffLite(
        employeeId: j['employee_id'] as int,
        name: j['name'] as String,
      );
}

class StoreBrandGroup {
  final int brandId;
  final String brandName;
  final List<StoreStaffLite> staff;
  const StoreBrandGroup({
    required this.brandId,
    required this.brandName,
    required this.staff,
  });

  factory StoreBrandGroup.fromJson(Map<String, dynamic> j) => StoreBrandGroup(
        brandId: j['brand_id'] as int,
        brandName: (j['brand_name'] as String?) ?? '',
        staff: ((j['staff'] as List?) ?? const [])
            .map((e) => StoreStaffLite.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}

/// A Store/Foodmall account's own store, with staff grouped by brand.
class StoreSummary {
  final int storeId;
  final String storeName;
  final bool isFoodmall;
  final List<StoreBrandGroup> groups;
  const StoreSummary({
    required this.storeId,
    required this.storeName,
    required this.isFoodmall,
    required this.groups,
  });

  int get totalStaff =>
      groups.fold(0, (sum, g) => sum + g.staff.length);

  factory StoreSummary.fromJson(Map<String, dynamic> j) => StoreSummary(
        storeId: j['store_id'] as int,
        storeName: j['store_name'] as String,
        isFoodmall: (j['is_foodmall'] as bool?) ?? false,
        groups: ((j['groups'] as List?) ?? const [])
            .map((e) => StoreBrandGroup.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}

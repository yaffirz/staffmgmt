class ClusterStaffMember {
  final int employeeId;
  final String employeeName;
  final String? positionTitle;
  // True when here via an additional-store link (primary elsewhere) — NOT movable
  // from this store.
  final bool alsoCovers;

  const ClusterStaffMember({
    required this.employeeId,
    required this.employeeName,
    required this.positionTitle,
    required this.alsoCovers,
  });

  factory ClusterStaffMember.fromJson(Map<String, dynamic> j) =>
      ClusterStaffMember(
        employeeId: j['employee_id'] as int,
        employeeName: j['employee_name'] as String,
        positionTitle: j['position_title'] as String?,
        alsoCovers: (j['also_covers'] as bool?) ?? false,
      );
}

class ClusterStore {
  final int storeId;
  final String storeName;
  final int brandId;
  final String brandName;
  final List<ClusterStaffMember> staff;

  const ClusterStore({
    required this.storeId,
    required this.storeName,
    required this.brandId,
    required this.brandName,
    required this.staff,
  });

  factory ClusterStore.fromJson(Map<String, dynamic> j) => ClusterStore(
        storeId: j['store_id'] as int,
        storeName: j['store_name'] as String,
        brandId: j['brand_id'] as int,
        brandName: j['brand_name'] as String,
        staff: ((j['staff'] as List?) ?? const [])
            .map((e) => ClusterStaffMember.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );

  /// Staff whose primary store is here (the only ones movable from this store).
  List<ClusterStaffMember> get movable =>
      staff.where((s) => !s.alsoCovers).toList(growable: false);
}

// Cluster-administration models: who manages which stores/brands.

class ClusterBrandLite {
  final int brandId;
  final String brandName;
  const ClusterBrandLite({required this.brandId, required this.brandName});

  factory ClusterBrandLite.fromJson(Map<String, dynamic> j) => ClusterBrandLite(
        brandId: j['brand_id'] as int,
        brandName: j['brand_name'] as String,
      );
}

class ClusterStoreLite {
  final int storeId;
  final String storeName;
  final int? brandId;
  final String brandName;
  /// Every brand the store serves (primary + foodmall extras). A foodmall is
  /// listed under each of these in the picker. Falls back to [brandName].
  final List<String> brandNames;
  const ClusterStoreLite({
    required this.storeId,
    required this.storeName,
    this.brandId,
    this.brandName = '',
    this.brandNames = const [],
  });

  factory ClusterStoreLite.fromJson(Map<String, dynamic> j) {
    final primary = (j['brand_name'] as String?) ?? '';
    final served = ((j['brand_names'] as List?) ?? const [])
        .map((e) => e as String)
        .where((e) => e.isNotEmpty)
        .toList();
    return ClusterStoreLite(
      storeId: j['store_id'] as int,
      storeName: j['store_name'] as String,
      brandId: j['brand_id'] as int?,
      brandName: primary,
      brandNames: served.isNotEmpty ? served : (primary.isEmpty ? const [] : [primary]),
    );
  }
}

class AreaManagerRow {
  final int userId;
  final String username;
  final int managerId;
  final List<int> storeIds;
  const AreaManagerRow({
    required this.userId,
    required this.username,
    required this.managerId,
    this.storeIds = const [],
  });

  factory AreaManagerRow.fromJson(Map<String, dynamic> j) => AreaManagerRow(
        userId: j['user_id'] as int,
        username: j['username'] as String,
        managerId: j['manager_id'] as int,
        storeIds: ((j['store_ids'] as List?) ?? const [])
            .map((e) => e as int)
            .toList(),
      );
}

class OpsManagerRow {
  final int userId;
  final String username;
  final List<int> brandIds;
  const OpsManagerRow({
    required this.userId,
    required this.username,
    this.brandIds = const [],
  });

  factory OpsManagerRow.fromJson(Map<String, dynamic> j) => OpsManagerRow(
        userId: j['user_id'] as int,
        username: j['username'] as String,
        brandIds: ((j['brand_ids'] as List?) ?? const [])
            .map((e) => e as int)
            .toList(),
      );
}

class ClustersOverview {
  final List<ClusterBrandLite> brands;
  final List<ClusterStoreLite> stores;
  final List<AreaManagerRow> areaManagers;
  final List<OpsManagerRow> opsManagers;
  const ClustersOverview({
    this.brands = const [],
    this.stores = const [],
    this.areaManagers = const [],
    this.opsManagers = const [],
  });

  factory ClustersOverview.fromJson(Map<String, dynamic> j) => ClustersOverview(
        brands: ((j['brands'] as List?) ?? const [])
            .map((e) => ClusterBrandLite.fromJson(e as Map<String, dynamic>))
            .toList(),
        stores: ((j['stores'] as List?) ?? const [])
            .map((e) => ClusterStoreLite.fromJson(e as Map<String, dynamic>))
            .toList(),
        areaManagers: ((j['area_managers'] as List?) ?? const [])
            .map((e) => AreaManagerRow.fromJson(e as Map<String, dynamic>))
            .toList(),
        opsManagers: ((j['ops_managers'] as List?) ?? const [])
            .map((e) => OpsManagerRow.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

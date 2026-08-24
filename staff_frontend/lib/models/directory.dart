class Brand {
  final int id;
  final String name;
  const Brand({required this.id, required this.name});

  factory Brand.fromJson(Map<String, dynamic> j) =>
      Brand(id: j['brand_id'] as int, name: j['brand_name'] as String);
}

class Store {
  final int id;
  final int brandId;
  final String name;
  final bool isFoodmall;
  final List<int> extraBrandIds;
  const Store({
    required this.id,
    required this.brandId,
    required this.name,
    this.isFoodmall = false,
    this.extraBrandIds = const [],
  });

  factory Store.fromJson(Map<String, dynamic> j) => Store(
        id: j['store_id'] as int,
        brandId: j['brand_id'] as int,
        name: j['store_name'] as String,
        isFoodmall: (j['is_foodmall'] as bool?) ?? false,
        extraBrandIds: ((j['extra_brand_ids'] as List?) ?? const [])
            .map((e) => e as int)
            .toList(growable: false),
      );

  /// Whether this store belongs to [brandId] — its primary brand, or one of the
  /// extra brands it carries as a foodmall.
  bool servesBrand(int brandId) =>
      this.brandId == brandId || extraBrandIds.contains(brandId);
}

class Position {
  final int id;

  /// null = a universal role (available to all brands minus [disabledBrandIds]).
  final int? brandId;
  final String title;
  final bool universal;
  final List<int> disabledBrandIds;
  const Position({
    required this.id,
    required this.brandId,
    required this.title,
    this.universal = false,
    this.disabledBrandIds = const [],
  });

  factory Position.fromJson(Map<String, dynamic> j) => Position(
        id: j['position_id'] as int,
        brandId: j['brand_id'] as int?,
        title: j['position_title'] as String,
        universal: (j['universal'] as bool?) ?? false,
        disabledBrandIds: ((j['disabled_brand_ids'] as List?) ?? const [])
            .map((e) => e as int)
            .toList(growable: false),
      );

  /// Whether this role can be used by [brandId] (its own brand, or a universal
  /// role not opted out for that brand).
  bool availableForBrand(int brandId) =>
      this.brandId == brandId ||
      (universal && !disabledBrandIds.contains(brandId));
}

class Country {
  final int id;
  final String name;
  const Country({required this.id, required this.name});

  factory Country.fromJson(Map<String, dynamic> j) =>
      Country(id: j['country_id'] as int, name: j['country_name'] as String);
}

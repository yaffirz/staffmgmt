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
  const Store({required this.id, required this.brandId, required this.name});

  factory Store.fromJson(Map<String, dynamic> j) => Store(
        id: j['store_id'] as int,
        brandId: j['brand_id'] as int,
        name: j['store_name'] as String,
      );
}

class Position {
  final int id;
  final int brandId;
  final String title;
  const Position({required this.id, required this.brandId, required this.title});

  factory Position.fromJson(Map<String, dynamic> j) => Position(
        id: j['position_id'] as int,
        brandId: j['brand_id'] as int,
        title: j['position_title'] as String,
      );
}

class Country {
  final int id;
  final String name;
  const Country({required this.id, required this.name});

  factory Country.fromJson(Map<String, dynamic> j) =>
      Country(id: j['country_id'] as int, name: j['country_name'] as String);
}

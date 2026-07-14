class StaffSearchResult {
  final int employeeId;
  final String employeeName;
  final List<String> brandNames;
  final List<String> storeNames;

  const StaffSearchResult({
    required this.employeeId,
    required this.employeeName,
    required this.brandNames,
    required this.storeNames,
  });

  factory StaffSearchResult.fromJson(Map<String, dynamic> j) => StaffSearchResult(
        employeeId: j['employee_id'] as int,
        employeeName: j['employee_name'] as String,
        brandNames: ((j['brand_names'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
        storeNames: ((j['store_names'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
      );

  String get brandsDisplay => brandNames.isEmpty ? '—' : brandNames.join(', ');
  String get storesDisplay => storeNames.isEmpty ? '—' : storeNames.join(', ');
}

/// A brand with its non-Oracle flag, for the Non-Oracle Employees marking UI.
class NonOracleBrand {
  final int brandId;
  final String brandName;
  final bool nonOracle;

  const NonOracleBrand({
    required this.brandId,
    required this.brandName,
    required this.nonOracle,
  });

  factory NonOracleBrand.fromJson(Map<String, dynamic> j) => NonOracleBrand(
        brandId: j['brand_id'] as int,
        brandName: j['brand_name'] as String,
        nonOracle: (j['non_oracle'] as bool?) ?? false,
      );

  NonOracleBrand copyWith({bool? nonOracle}) => NonOracleBrand(
        brandId: brandId,
        brandName: brandName,
        nonOracle: nonOracle ?? this.nonOracle,
      );
}

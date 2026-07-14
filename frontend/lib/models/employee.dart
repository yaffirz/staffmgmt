class Employee {
  final int employeeId;
  final String payrollId;
  final String employeeName;
  final DateTime dateOfBirth;
  final String? phoneNumber;
  final String? email;
  final double? payrate;
  final String? payCurrency;
  final String? magCode;
  final int? primaryStoreId;
  final int? positionId;
  final int? countryId;
  final bool reviewed;
  final String? storeName;
  final String? brandName;
  final String? positionTitle;
  final String? countryName;
  final List<String> additionalStores;
  final List<int> additionalStoreIds;

  const Employee({
    required this.employeeId,
    required this.payrollId,
    required this.employeeName,
    required this.dateOfBirth,
    required this.phoneNumber,
    required this.email,
    required this.payrate,
    required this.payCurrency,
    required this.magCode,
    required this.primaryStoreId,
    required this.positionId,
    required this.countryId,
    required this.reviewed,
    required this.storeName,
    required this.brandName,
    required this.positionTitle,
    required this.countryName,
    this.additionalStores = const [],
    this.additionalStoreIds = const [],
  });

  factory Employee.fromJson(Map<String, dynamic> j) => Employee(
        employeeId: j['employee_id'] as int,
        payrollId: j['payroll_id'] as String,
        employeeName: j['employee_name'] as String,
        dateOfBirth: DateTime.parse(j['date_of_birth'] as String),
        phoneNumber: j['phone_number'] as String?,
        email: j['email'] as String?,
        payrate: (j['payrate'] as num?)?.toDouble(),
        payCurrency: j['pay_currency'] as String?,
        magCode: j['mag_code'] as String?,
        primaryStoreId: j['primary_store_id'] as int?,
        positionId: j['position_id'] as int?,
        countryId: j['country_id'] as int?,
        reviewed: (j['reviewed'] as bool?) ?? false,
        storeName: j['store_name'] as String?,
        brandName: j['brand_name'] as String?,
        positionTitle: j['position_title'] as String?,
        countryName: j['country_name'] as String?,
        additionalStores: (j['additional_stores'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        additionalStoreIds: (j['additional_store_ids'] as List?)
                ?.map((e) => e as int)
                .toList() ??
            const [],
      );

  String get additionalStoresDisplay =>
      additionalStores.isEmpty ? '—' : additionalStores.join(', ');

  /// DOB shown US-style MM/DD/YYYY across the app.
  String get dobDisplay =>
      '${dateOfBirth.month.toString().padLeft(2, '0')}/'
      '${dateOfBirth.day.toString().padLeft(2, '0')}/'
      '${dateOfBirth.year}';

  String get payrateDisplay {
    if (payrate == null) return '—';
    final amount = payrate!.toStringAsFixed(2);
    return (payCurrency == null || payCurrency!.isEmpty)
        ? amount
        : '$amount $payCurrency';
  }
}

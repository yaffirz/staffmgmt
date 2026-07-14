import '../models/bulk_result.dart';
import '../models/directory.dart';
import '../models/employee.dart';
import '../models/form_field_config.dart';
import 'api_client.dart';

/// Calls for staff/org data. Thin wrapper over ApiClient that maps JSON to models.
class StaffService {
  final ApiClient _api;
  StaffService(this._api);

  Future<List<Brand>> brands() async {
    final data = await _api.get('/api/v1/brands') as List;
    return data
        .map((e) => Brand.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<Store>> stores() async {
    final data = await _api.get('/api/v1/stores') as List;
    return data
        .map((e) => Store.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<Position>> positions() async {
    final data = await _api.get('/api/v1/positions') as List;
    return data
        .map((e) => Position.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<Country>> countries() async {
    final data = await _api.get('/api/v1/countries') as List;
    return data
        .map((e) => Country.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Brand> createBrand(String name) async {
    final data = await _api.post('/api/v1/brands', {'brand_name': name})
        as Map<String, dynamic>;
    return Brand.fromJson(data);
  }

  Future<Store> createStore(int brandId, String name) async {
    final data = await _api.post(
      '/api/v1/stores',
      {'brand_id': brandId, 'store_name': name},
    ) as Map<String, dynamic>;
    return Store.fromJson(data);
  }

  Future<Position> createPosition(int brandId, String title) async {
    final data = await _api.post(
      '/api/v1/positions',
      {'brand_id': brandId, 'position_title': title},
    ) as Map<String, dynamic>;
    return Position.fromJson(data);
  }

  Future<Brand> updateBrand(int id, String name) async {
    final data = await _api.patch('/api/v1/brands/$id', {'brand_name': name})
        as Map<String, dynamic>;
    return Brand.fromJson(data);
  }

  Future<Store> updateStore(int id, int brandId, String name) async {
    final data = await _api.patch(
      '/api/v1/stores/$id',
      {'brand_id': brandId, 'store_name': name},
    ) as Map<String, dynamic>;
    return Store.fromJson(data);
  }

  Future<Position> updatePosition(int id, int brandId, String title) async {
    final data = await _api.patch(
      '/api/v1/positions/$id',
      {'brand_id': brandId, 'position_title': title},
    ) as Map<String, dynamic>;
    return Position.fromJson(data);
  }

  Future<BulkResult> bulkBrands(String csv) async {
    final data = await _api.postCsv('/api/v1/brands/bulk', csv)
        as Map<String, dynamic>;
    return BulkResult.fromJson(data);
  }

  Future<BulkResult> bulkStores(String csv) async {
    final data = await _api.postCsv('/api/v1/stores/bulk', csv)
        as Map<String, dynamic>;
    return BulkResult.fromJson(data);
  }

  Future<BulkResult> bulkPositions(String csv) async {
    final data = await _api.postCsv('/api/v1/positions/bulk', csv)
        as Map<String, dynamic>;
    return BulkResult.fromJson(data);
  }

  /// Creates a new hire. Throws ApiException (e.g. 409 on duplicate payroll_id).
  Future<void> createEmployee(Map<String, dynamic> payload) async {
    await _api.post('/api/v1/employees', payload);
  }

  /// Updates an existing employee (same validation as create).
  Future<void> updateEmployee(int id, Map<String, dynamic> payload) async {
    await _api.put('/api/v1/employees/$id', payload);
  }

  /// Deletes an employee (Admin / Super Admin only).
  Future<void> deleteEmployee(int id) async {
    await _api.delete('/api/v1/employees/$id');
  }

  Future<List<Employee>> listEmployees() async {
    final data = await _api.get('/api/v1/employees') as List;
    return data
        .map((e) => Employee.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<Employee> setReviewed(int employeeId, bool reviewed) async {
    final data = await _api.patch(
      '/api/v1/employees/$employeeId/reviewed',
      {'reviewed': reviewed},
    ) as Map<String, dynamic>;
    return Employee.fromJson(data);
  }

  /// Suggested next MAG card number (auto-increments from 70000000).
  Future<String?> nextMagCode() async {
    final data =
        await _api.get('/api/v1/employees/next-mag') as Map<String, dynamic>;
    return data['mag_code'] as String?;
  }

  /// Update an employee's MAG card (Admin / Super Admin only).
  Future<Employee> updateMagCode(int employeeId, String? magCode) async {
    final data = await _api.patch(
      '/api/v1/employees/$employeeId/mag-code',
      {'mag_code': magCode},
    ) as Map<String, dynamic>;
    return Employee.fromJson(data);
  }

  Future<List<FormFieldConfig>> formConfig(String formKey) async {
    final data = await _api.get('/api/v1/form-config/$formKey') as List;
    return data
        .map((e) => FormFieldConfig.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Update enabled/required for a form's fields (Admin / Super Admin only).
  Future<List<FormFieldConfig>> updateFormConfig(
    String formKey,
    List<FormFieldConfig> fields,
  ) async {
    final payload = {
      'fields': fields
          .map((f) => {
                'field_key': f.fieldKey,
                'enabled': f.enabled,
                'required': f.required,
              })
          .toList(),
    };
    final data =
        await _api.patch('/api/v1/form-config/$formKey', payload) as List;
    return data
        .map((e) => FormFieldConfig.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}

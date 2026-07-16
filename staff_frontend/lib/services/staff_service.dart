import '../models/app_notification.dart';
import '../models/audit_log.dart';
import '../models/bulk_result.dart';
import '../models/cluster.dart';
import '../models/directory.dart';
import '../models/employee.dart';
import '../models/form_field_config.dart';
import '../models/staff_note.dart';
import '../models/staff_page.dart';
import '../models/staff_search_result.dart';
import '../models/status_log.dart';
import '../models/store_staff.dart';
import '../models/user_account.dart';
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

  Future<void> deleteBrand(int id) async {
    await _api.delete('/api/v1/brands/$id');
  }

  Future<void> deleteStore(int id) async {
    await _api.delete('/api/v1/stores/$id');
  }

  Future<void> deletePosition(int id) async {
    await _api.delete('/api/v1/positions/$id');
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

  Future<BulkResult> bulkEmployees(String csv) async {
    final data = await _api.postCsv('/api/v1/employees/bulk', csv)
        as Map<String, dynamic>;
    return BulkResult.fromJson(data);
  }

  // ---- Users -------------------------------------------------------------

  Future<List<UserAccount>> users() async {
    final data = await _api.get('/api/v1/users') as List;
    return data
        .map((e) => UserAccount.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<UserAccount> createUser(
    String username,
    String email,
    String password,
    String role, {
    List<int>? brandIds,
    List<String>? additionalRoles,
  }) async {
    final body = <String, dynamic>{
      'username': username,
      'email': email,
      'password': password,
      'role': role,
    };
    if (brandIds != null) body['brand_ids'] = brandIds;
    if (additionalRoles != null) body['additional_roles'] = additionalRoles;
    final data =
        await _api.post('/api/v1/users', body) as Map<String, dynamic>;
    return UserAccount.fromJson(data);
  }

  Future<UserAccount> updateUser(
    int userId, {
    String? username,
    String? email,
    String? role,
    String? password,
    List<int>? brandIds,
    List<String>? additionalRoles,
  }) async {
    final body = <String, dynamic>{};
    if (username != null) body['username'] = username;
    if (email != null) body['email'] = email;
    if (role != null) body['role'] = role;
    if (password != null) body['password'] = password;
    if (brandIds != null) body['brand_ids'] = brandIds;
    if (additionalRoles != null) body['additional_roles'] = additionalRoles;
    final data =
        await _api.patch('/api/v1/users/$userId', body) as Map<String, dynamic>;
    return UserAccount.fromJson(data);
  }

  Future<void> deleteUser(int userId) async {
    await _api.delete('/api/v1/users/$userId');
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

  // ---- Notifications -----------------------------------------------------

  Future<List<AppNotification>> notifications({bool unreadOnly = false}) async {
    final path = unreadOnly
        ? '/api/v1/notifications?unread_only=true'
        : '/api/v1/notifications';
    final data = await _api.get(path) as List;
    return data
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<int> unreadNotificationCount() async {
    final data = await _api.get('/api/v1/notifications/unread-count')
        as Map<String, dynamic>;
    return (data['count'] as int?) ?? 0;
  }

  Future<void> markNotificationRead(int id) async {
    await _api.post('/api/v1/notifications/$id/read', const {});
  }

  Future<void> markAllNotificationsRead() async {
    await _api.post('/api/v1/notifications/read-all', const {});
  }

  /// Staff currently at a store (primary + additional coverage).
  Future<StoreStaff> staffAtStore(int storeId) async {
    final data = await _api.get('/api/v1/stores/$storeId/staff')
        as Map<String, dynamic>;
    return StoreStaff.fromJson(data);
  }

  // ---- Area Manager cluster (Phase 2b) -----------------------------------

  /// The calling Area Manager's cluster: stores in their brands + staff.
  Future<List<ClusterStore>> cluster() async {
    final data = await _api.get('/api/v1/cluster') as Map<String, dynamic>;
    return ((data['stores'] as List?) ?? const [])
        .map((e) => ClusterStore.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Move a staffer's primary store to another store in the AM's cluster.
  Future<void> moveStaff(int employeeId, int toStoreId) async {
    await _api.post(
      '/api/v1/cluster/employees/$employeeId/move',
      {'to_store_id': toStoreId},
    );
  }

  /// Search all staff by name (to request one into a store). Capped server-side.
  Future<List<StaffSearchResult>> searchStaff(String name) async {
    final data = await _api
        .get('/api/v1/cluster/employees/search?name=${Uri.encodeQueryComponent(name)}')
        as List;
    return data
        .map((e) => StaffSearchResult.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Queue a request to assign a staffer to one of the AM's stores.
  Future<void> requestStaff(int employeeId, int storeId) async {
    await _api.post(
      '/api/v1/cluster/employees/$employeeId/request-assignment',
      {'store_id': storeId},
    );
  }

  /// Assign a cluster staffer to an additional store (accumulative).
  Future<void> assignStore(int employeeId, int storeId) async {
    await _api.post(
      '/api/v1/cluster/employees/$employeeId/assign-store',
      {'store_id': storeId},
    );
  }

  // ---- App settings (admin toggles) --------------------------------------

  Future<String> getSetting(String key) async {
    final data = await _api.get('/api/v1/settings/$key') as Map<String, dynamic>;
    return (data['value'] as String?) ?? '';
  }

  Future<String> updateSetting(String key, String value) async {
    final data = await _api.patch('/api/v1/settings/$key', {'value': value})
        as Map<String, dynamic>;
    return (data['value'] as String?) ?? '';
  }

  // ---- Individual staff page + notes -------------------------------------

  Future<StaffPageEmployee> staffPage(int employeeId) async {
    final data =
        await _api.get('/api/v1/staff/$employeeId') as Map<String, dynamic>;
    return StaffPageEmployee.fromJson(data);
  }

  Future<List<StaffNote>> staffNotes(int employeeId) async {
    final data = await _api.get('/api/v1/staff/$employeeId/notes') as List;
    return data
        .map((e) => StaffNote.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Every note visible to the caller across all staff (the "all notes" feed).
  Future<List<StaffNote>> allStaffNotes() async {
    final data = await _api.get('/api/v1/staff/notes/all') as List;
    return data
        .map((e) => StaffNote.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<StaffNote> createNote(
    int employeeId, {
    required String text,
    List<String> roles = const [],
    List<int> brandIds = const [],
  }) async {
    final data = await _api.post(
      '/api/v1/staff/$employeeId/notes',
      {
        'note_text': text,
        'visibility_roles': roles,
        'visibility_brand_ids': brandIds,
      },
    ) as Map<String, dynamic>;
    return StaffNote.fromJson(data);
  }

  Future<void> deleteNote(int noteId) async {
    await _api.delete('/api/v1/staff/notes/$noteId');
  }

  // ---- Status changes (Phase 3) ------------------------------------------

  /// Promote / demote / terminate / reactivate a staff member.
  Future<void> changeStatus(
    int employeeId, {
    required String actionType,
    int? toPositionId,
    String? reason,
  }) async {
    final body = <String, dynamic>{'action_type': actionType};
    if (toPositionId != null) body['to_position_id'] = toPositionId;
    if (reason != null && reason.trim().isNotEmpty) body['reason'] = reason.trim();
    await _api.post('/api/v1/staff/$employeeId/status', body);
  }

  Future<List<StatusLogEntry>> statusLog(int employeeId) async {
    final data = await _api.get('/api/v1/staff/$employeeId/status-log') as List;
    return data
        .map((e) => StatusLogEntry.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<StatusLogEntry>> statusFeed() async {
    final data = await _api.get('/api/v1/staff/status/feed') as List;
    return data
        .map((e) => StatusLogEntry.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  // ---- Admin mini-console (audit logs) -----------------------------------

  Future<List<AuditLogEntry>> auditLogs({String? table}) async {
    final path = table == null
        ? '/api/v1/audit-logs'
        : '/api/v1/audit-logs?table=${Uri.encodeQueryComponent(table)}';
    final data = await _api.get(path) as List;
    return data
        .map((e) => AuditLogEntry.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// The current user's own brands (Area Managers) — defaults the brand picker.
  Future<List<Brand>> myBrands() async {
    final data = await _api.get('/api/v1/auth/me/brands') as List;
    return data
        .map((e) => Brand.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
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

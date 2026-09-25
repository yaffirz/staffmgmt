import '../models/app_notification.dart';
import '../models/app_info.dart';
import '../models/audit_log.dart';
import '../models/backup_item.dart';
import '../models/bulk_result.dart';
import '../models/cluster.dart';
import '../models/directory.dart';
import '../models/employee.dart';
import '../models/form_field_config.dart';
import '../models/maintenance_status.dart';
import '../models/marketing_content.dart';
import '../models/registration_request.dart';
import '../models/staff_note.dart';
import '../models/store_summary.dart';
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

  Future<Country> createCountry(String name) async {
    final data = await _api.post('/api/v1/countries', {'country_name': name})
        as Map<String, dynamic>;
    return Country.fromJson(data);
  }

  Future<Country> updateCountry(int id, String name) async {
    final data = await _api
        .patch('/api/v1/countries/$id', {'country_name': name})
        as Map<String, dynamic>;
    return Country.fromJson(data);
  }

  Future<void> deleteCountry(int id) async {
    await _api.delete('/api/v1/countries/$id');
  }

  Future<Brand> createBrand(String name) async {
    final data = await _api.post('/api/v1/brands', {'brand_name': name})
        as Map<String, dynamic>;
    return Brand.fromJson(data);
  }

  Future<Store> createStore(
    int brandId,
    String name, {
    bool isFoodmall = false,
    List<int> extraBrandIds = const [],
  }) async {
    final data = await _api.post(
      '/api/v1/stores',
      {
        'brand_id': brandId,
        'store_name': name,
        'is_foodmall': isFoodmall,
        'extra_brand_ids': extraBrandIds,
      },
    ) as Map<String, dynamic>;
    return Store.fromJson(data);
  }

  Future<Position> createPosition(
    int? brandId,
    String title, {
    List<int> disabledBrandIds = const [],
  }) async {
    final data = await _api.post(
      '/api/v1/positions',
      {
        'brand_id': brandId,
        'position_title': title,
        'disabled_brand_ids': disabledBrandIds,
      },
    ) as Map<String, dynamic>;
    return Position.fromJson(data);
  }

  Future<Brand> updateBrand(int id, String name) async {
    final data = await _api.patch('/api/v1/brands/$id', {'brand_name': name})
        as Map<String, dynamic>;
    return Brand.fromJson(data);
  }

  Future<Store> updateStore(
    int id,
    int brandId,
    String name, {
    bool isFoodmall = false,
    List<int> extraBrandIds = const [],
  }) async {
    final data = await _api.patch(
      '/api/v1/stores/$id',
      {
        'brand_id': brandId,
        'store_name': name,
        'is_foodmall': isFoodmall,
        'extra_brand_ids': extraBrandIds,
      },
    ) as Map<String, dynamic>;
    return Store.fromJson(data);
  }

  Future<Position> updatePosition(
    int id,
    int? brandId,
    String title, {
    List<int> disabledBrandIds = const [],
  }) async {
    final data = await _api.patch(
      '/api/v1/positions/$id',
      {
        'brand_id': brandId,
        'position_title': title,
        'disabled_brand_ids': disabledBrandIds,
      },
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
    int? storeId,
    List<String>? additionalRoles,
    bool mustChangePassword = false,
    bool suspended = false,
    bool emailOptIn = true,
  }) async {
    final body = <String, dynamic>{
      'username': username,
      'email': email,
      'password': password,
      'role': role,
      'must_change_password': mustChangePassword,
      'suspended': suspended,
      'email_opt_in': emailOptIn,
    };
    if (brandIds != null) body['brand_ids'] = brandIds;
    if (storeId != null) body['store_id'] = storeId;
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
    int? storeId,
    List<String>? additionalRoles,
    bool? mustChangePassword,
    bool? suspended,
    bool? emailOptIn,
  }) async {
    final body = <String, dynamic>{};
    if (username != null) body['username'] = username;
    if (email != null) body['email'] = email;
    if (role != null) body['role'] = role;
    if (password != null) body['password'] = password;
    if (brandIds != null) body['brand_ids'] = brandIds;
    if (storeId != null) body['store_id'] = storeId;
    if (additionalRoles != null) body['additional_roles'] = additionalRoles;
    if (mustChangePassword != null) {
      body['must_change_password'] = mustChangePassword;
    }
    if (suspended != null) body['suspended'] = suspended;
    if (emailOptIn != null) body['email_opt_in'] = emailOptIn;
    final data =
        await _api.patch('/api/v1/users/$userId', body) as Map<String, dynamic>;
    return UserAccount.fromJson(data);
  }

  // ---- Password reset (unauthenticated) ----------------------------------

  /// Request a reset link. Always succeeds (neutral) — never reveals whether the
  /// account exists.
  Future<void> forgotPassword(String identifier) async {
    await _api.post('/api/v1/auth/forgot-password', {'identifier': identifier},
        auth: false);
  }

  Future<bool> validateResetToken(String token) async {
    final data = await _api.get(
      '/api/v1/auth/reset-password/validate?token=${Uri.encodeQueryComponent(token)}',
      auth: false,
    ) as Map<String, dynamic>;
    return (data['valid'] as bool?) ?? false;
  }

  /// Complete a reset with a token from the emailed link. Throws ApiException
  /// (400 invalid/expired, 422 too short).
  Future<void> resetPassword(String token, String newPassword) async {
    await _api.post(
      '/api/v1/auth/reset-password',
      {'token': token, 'new_password': newPassword},
      auth: false,
    );
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

  /// Admin/IT: flag which cells need review (empty list clears the flag).
  Future<Employee> setReviewFlag(int employeeId, List<String> fields) async {
    final data = await _api.patch(
      '/api/v1/employees/$employeeId/review-flag',
      {'fields': fields},
    ) as Map<String, dynamic>;
    return Employee.fromJson(data);
  }

  /// Suggested next MAG card number (auto-increments from 70000000).
  Future<String?> nextMagCode() async {
    final data =
        await _api.get('/api/v1/employees/next-mag') as Map<String, dynamic>;
    return data['mag_code'] as String?;
  }

  /// Feature flags for the new-hire wizard (readable by write roles).
  Future<Map<String, bool>> employeeFormFlags() async {
    final data =
        await _api.get('/api/v1/employees/form-flags') as Map<String, dynamic>;
    return data.map((k, v) => MapEntry(k, v == true));
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

  // ---- Registration (public + admin approval) ----------------------------

  /// Public: is self-registration currently enabled?
  Future<bool> registrationEnabled() async {
    try {
      final data = await _api.get('/api/v1/register/enabled', auth: false)
          as Map<String, dynamic>;
      return (data['enabled'] as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Public: submit a sign-up. Returns the neutral status message.
  Future<String> register({
    required String username,
    required String email,
    required String password,
    String? note,
  }) async {
    final body = <String, dynamic>{
      'username': username,
      'email': email,
      'password': password,
    };
    if (note != null && note.trim().isNotEmpty) body['note'] = note.trim();
    final data =
        await _api.post('/api/v1/register', body, auth: false)
            as Map<String, dynamic>;
    return (data['message'] as String?) ?? 'Registration submitted.';
  }

  /// Admin: pending/processed sign-ups.
  Future<List<RegistrationRequest>> registrations() async {
    final data = await _api.get('/api/v1/registrations') as List;
    return data
        .map((e) => RegistrationRequest.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Admin: approve a sign-up, creating the account with an assigned role.
  Future<void> approveRegistration(
    int id, {
    required String role,
    int? storeId,
    List<int>? brandIds,
  }) async {
    final body = <String, dynamic>{'role': role};
    if (storeId != null) body['store_id'] = storeId;
    if (brandIds != null) body['brand_ids'] = brandIds;
    await _api.post('/api/v1/registrations/$id/approve', body);
  }

  /// Admin: reject a sign-up.
  Future<void> rejectRegistration(int id) async {
    await _api.post('/api/v1/registrations/$id/reject', const {});
  }

  /// Admin helper (while email sending is stubbed): hit a request's confirm link
  /// to mark its email confirmed. `path` is the relative confirm_path.
  Future<void> confirmRegistrationEmail(String path) async {
    await _api.get(path, auth: false);
  }

  // ---- Store / Foodmall portal (restricted) ------------------------------

  /// The calling Store/Foodmall account's own store + staff grouped by brand.
  Future<StoreSummary> storeSummary() async {
    final data = await _api.get('/api/v1/store/summary') as Map<String, dynamic>;
    return StoreSummary.fromJson(data);
  }

  /// Search staff by name (name only) to request into this store.
  Future<List<StoreStaffLite>> storeSearchStaff(String name) async {
    final data = await _api.get(
      '/api/v1/store/employees/search?name=${Uri.encodeQueryComponent(name)}',
    ) as List;
    return data
        .map((e) => StoreStaffLite.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Request a staffer be added to this store (notifies Admins).
  Future<void> storeRequestStaff(int employeeId) async {
    await _api.post('/api/v1/store/request-staff', {'employee_id': employeeId});
  }

  // ---- Maintenance mode --------------------------------------------------

  /// Public maintenance state (no auth needed — used before/after login).
  Future<MaintenanceStatus> maintenanceStatus() async {
    final data = await _api.get('/api/v1/maintenance/status', auth: false)
        as Map<String, dynamic>;
    return MaintenanceStatus.fromJson(data);
  }

  /// Public login-screen marketing block (no auth needed — shown before login).
  Future<MarketingContent> marketingContent() async {
    final data =
        await _api.get('/api/v1/marketing', auth: false) as Map<String, dynamic>;
    return MarketingContent.fromJson(data);
  }

  // ---- Announcements -----------------------------------------------------

  /// Broadcast an announcement to everyone (Super Admin only).
  /// [delivery] is 'bell' (inbox only) or 'popup' (one-time dialog + inbox).
  Future<void> createAnnouncement({
    required String title,
    required String body,
    required String delivery,
  }) async {
    await _api.post('/api/v1/announcements', {
      'title': title,
      'body': body,
      'delivery': delivery,
    });
  }

  /// Unread popup announcements for the current user (shown as one-time dialogs).
  Future<List<AppNotification>> popupAnnouncements() async {
    final data = await _api.get('/api/v1/announcements/popup') as List;
    return data
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
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

  // ---- Email server settings (Super Admin) -------------------------------

  Future<Map<String, dynamic>> getEmailConfig() async {
    return await _api.get('/api/v1/email/config') as Map<String, dynamic>;
  }

  /// Only the provided fields are changed. Omit `email_password` (or pass an
  /// empty string) to keep the stored one.
  Future<Map<String, dynamic>> updateEmailConfig(
      Map<String, dynamic> changes) async {
    return await _api.put('/api/v1/email/config', changes)
        as Map<String, dynamic>;
  }

  /// Returns (ok, detail) — ok=false carries the SMTP error to show the admin.
  Future<(bool, String)> sendTestEmail(String to) async {
    final data =
        await _api.post('/api/v1/email/test', {'to': to}) as Map<String, dynamic>;
    return ((data['ok'] as bool?) ?? false, (data['detail'] as String?) ?? '');
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

  // ---- Android app download (any signed-in user) -------------------------

  Future<AppInfo> appInfo() async {
    final data = await _api.get('/api/v1/app/info') as Map<String, dynamic>;
    return AppInfo.fromJson(data);
  }

  Future<List<int>> downloadApk() async {
    return _api.getBytes('/api/v1/app/download');
  }

  // ---- Backups (Super Admin) ---------------------------------------------

  Future<List<BackupItem>> backups() async {
    final data = await _api.get('/api/v1/backups') as List;
    return data
        .map((e) => BackupItem.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<BackupItem> startBackup() async {
    final data = await _api.post('/api/v1/backups', const {})
        as Map<String, dynamic>;
    return BackupItem.fromJson(data);
  }

  Future<BackupItem> backupStatus(int id) async {
    final data = await _api.get('/api/v1/backups/$id') as Map<String, dynamic>;
    return BackupItem.fromJson(data);
  }

  Future<void> deleteBackup(int id) async {
    await _api.delete('/api/v1/backups/$id');
  }

  Future<List<int>> downloadBackup(int id) async {
    return _api.getBytes('/api/v1/backups/$id/download');
  }

  Future<BackupSchedule> backupSchedule() async {
    final data =
        await _api.get('/api/v1/backups/schedule') as Map<String, dynamic>;
    return BackupSchedule.fromJson(data);
  }

  Future<BackupSchedule> setBackupSchedule(
      String schedule, String time, int retention) async {
    final data = await _api.put('/api/v1/backups/schedule', {
      'schedule': schedule,
      'time': time,
      'retention': retention,
    }) as Map<String, dynamic>;
    return BackupSchedule.fromJson(data);
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

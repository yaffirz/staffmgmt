import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/employee.dart';
import '../services/staff_service.dart';
import '../state/auth_provider.dart';
import '../widgets/app_scaffold.dart';
import 'new_hire_wizard_screen.dart';
import 'bulk_upload_screen.dart';
import 'employee_detail_screen.dart';

class EmployeesListScreen extends StatefulWidget {
  const EmployeesListScreen({super.key});

  @override
  State<EmployeesListScreen> createState() => _EmployeesListScreenState();
}

class _EmployeesListScreenState extends State<EmployeesListScreen> {
  final _searchCtrl = TextEditingController();
  final List<Employee> _all = [];
  _EmployeeDataSource? _source;

  bool _loading = true;
  String? _error;
  int _rowsPerPage = 15;
  bool _canEditMag = false;

  @override
  void initState() {
    super.initState();
    final role = context.read<AuthProvider>().user?.role;
    _canEditMag = role == 'Super Admin' || role == 'Admin';
    _source = _EmployeeDataSource(
      onToggle: _toggleReviewed,
      canEditMag: _canEditMag,
      onEditMag: _editMag,
      onEdit: _editEmployee,
      onDelete: _deleteEmployee,
      canDelete: _canEditMag,
      onOpenNotes: _openNotes,
    );
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _source?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await context.read<StaffService>().listEmployees();
      if (!mounted) return;
      _all
        ..clear()
        ..addAll(list);
      _source!.setEmployees(_all);
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load employees. Check the server connection.';
        _loading = false;
      });
    }
  }

  Future<void> _toggleReviewed(Employee e, bool value) async {
    try {
      final updated =
          await context.read<StaffService>().setReviewed(e.employeeId, value);
      final i = _all.indexWhere((x) => x.employeeId == e.employeeId);
      if (i != -1) _all[i] = updated;
      _source!.setEmployees(_all);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update. Please try again.')),
      );
    }
  }

  Future<void> _editMag(Employee e) async {
    final ctrl = TextEditingController(text: e.magCode ?? '');
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit MAG card'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'MAG card',
            hintText: '70000000',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return; // cancelled
    try {
      final updated = await context
          .read<StaffService>()
          .updateMagCode(e.employeeId, result.isEmpty ? null : result);
      final i = _all.indexWhere((x) => x.employeeId == e.employeeId);
      if (i != -1) _all[i] = updated;
      _source!.setEmployees(_all);
      if (mounted) setState(() {});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update MAG card.')),
      );
    }
  }

  Future<void> _editEmployee(Employee e) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NewHireWizardScreen(editing: e),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _deleteEmployee(Employee e) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete employee?'),
        content: Text(
          'This permanently removes ${e.employeeName} (${e.payrollId}) and '
          'their notes and history. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB3261E)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await context.read<StaffService>().deleteEmployee(e.employeeId);
      _all.removeWhere((x) => x.employeeId == e.employeeId);
      _source!.setEmployees(_all);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${e.employeeName} deleted')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete. Please try again.')),
      );
    }
  }

  Future<void> _addEmployee() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NewHireWizardScreen()),
    );
    _load();
  }

  void _openNotes(Employee e) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmployeeDetailScreen(
          employeeId: e.employeeId,
          employeeName: e.employeeName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('All employees'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
          IconButton(
            tooltip: 'Add employee',
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: _addEmployee,
          ),
          IconButton(
            tooltip: 'Bulk add employees',
            icon: const Icon(Icons.upload_file),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const BulkUploadScreen(kind: BulkKind.employees),
                ),
              );
              _load();
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Material(
            // Explicit surface + no tint so the M3 primary elevation overlay
            // (the "blue-ish" cast) doesn't get applied.
            color: isDark ? cs.surfaceContainerHigh : Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            borderRadius: BorderRadius.circular(14),
            child: Theme(
              // PaginatedDataTable builds its own inner Card; clear its tint too.
              data: Theme.of(context).copyWith(
                cardColor: isDark ? cs.surfaceContainerHigh : Colors.white,
                cardTheme: const CardThemeData(
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                ),
              ),
              child: PaginatedDataTable(
                header: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search name, payroll, store, position, email…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              _source!.setQuery('');
                              setState(() {});
                            },
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (v) {
                    _source!.setQuery(v);
                    setState(() {});
                  },
                ),
                rowsPerPage: _rowsPerPage,
                availableRowsPerPage: const [15, 30, 50],
                onRowsPerPageChanged: (v) =>
                    setState(() => _rowsPerPage = v ?? 15),
                showCheckboxColumn: false,
                columnSpacing: 28,
                columns: [
                  const DataColumn(label: Text('Reviewed')),
                  const DataColumn(label: Text('Name')),
                  const DataColumn(label: Text('Payroll ID')),
                  const DataColumn(label: Text('Brand')),
                  const DataColumn(label: Text('Store')),
                  const DataColumn(label: Text('Position')),
                  const DataColumn(label: Text('DOB')),
                  const DataColumn(label: Text('Email')),
                  const DataColumn(label: Text('Phone')),
                  const DataColumn(label: Text('Pay rate')),
                  const DataColumn(label: Text('MAG card')),
                  const DataColumn(label: Text('Country')),
                  if (_source!.showAdditional)
                    const DataColumn(label: Text('Additional stores')),
                  const DataColumn(label: Text('Actions')),
                ],
                source: _source!,
              ),
            ),
          ),
    );
  }
}

class _EmployeeDataSource extends DataTableSource {
  _EmployeeDataSource({
    required this.onToggle,
    required this.onEditMag,
    required this.canEditMag,
    required this.onEdit,
    required this.onDelete,
    required this.canDelete,
    required this.onOpenNotes,
  });

  final Future<void> Function(Employee e, bool value) onToggle;
  final void Function(Employee e) onEditMag;
  final bool canEditMag;
  final void Function(Employee e) onEdit;
  final void Function(Employee e) onDelete;
  final bool canDelete;
  final void Function(Employee e) onOpenNotes;

  bool showAdditional = false;

  List<Employee> _all = [];
  List<Employee> _filtered = [];
  String _query = '';
  final Set<int> _busy = {};

  void setEmployees(List<Employee> list) {
    _all = List.of(list);
    showAdditional = _all.any((e) => e.additionalStores.isNotEmpty);
    _applyFilter();
  }

  void setQuery(String q) {
    _query = q.trim().toLowerCase();
    _applyFilter();
  }

  void _applyFilter() {
    if (_query.isEmpty) {
      _filtered = List.of(_all);
    } else {
      _filtered = _all.where((e) => _haystack(e).contains(_query)).toList();
    }
    notifyListeners();
  }

  String _haystack(Employee e) => [
        e.employeeName,
        e.payrollId,
        e.brandName ?? '',
        e.storeName ?? '',
        e.positionTitle ?? '',
        e.dobDisplay,
        e.email ?? '',
        e.phoneNumber ?? '',
        e.payrateDisplay,
        e.magCode ?? '',
        e.countryName ?? '',
      ].join(' ').toLowerCase();

  Future<void> _toggle(Employee e) async {
    _busy.add(e.employeeId);
    notifyListeners();
    await onToggle(e, !e.reviewed);
    _busy.remove(e.employeeId);
    notifyListeners();
  }

  DataCell _text(String? value) =>
      DataCell(SelectableText(value == null || value.isEmpty ? '—' : value));

  DataCell _magCell(Employee e) {
    if (!canEditMag) return _text(e.magCode);
    final shown = (e.magCode == null || e.magCode!.isEmpty) ? '—' : e.magCode!;
    return DataCell(
      InkWell(
        onTap: () => onEditMag(e),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(shown),
              const SizedBox(width: 6),
              const Icon(Icons.edit, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  @override
  DataRow getRow(int index) {
    final e = _filtered[index];
    final busy = _busy.contains(e.employeeId);

    final cells = <DataCell>[
      DataCell(
        IconButton(
          tooltip: e.reviewed ? 'Reviewed' : 'Mark as reviewed',
          onPressed: busy ? null : () => _toggle(e),
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : Icon(
                  e.reviewed
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: e.reviewed ? const Color(0xFF2E7D43) : Colors.grey,
                ),
        ),
      ),
      _text(e.employeeName),
      _text(e.payrollId),
      _text(e.brandName),
      _text(e.storeName),
      _text(e.positionTitle),
      _text(e.dobDisplay),
      _text(e.email),
      _text(e.phoneNumber),
      _text(e.payrateDisplay),
      _magCell(e),
      _text(e.countryName),
      if (showAdditional) _text(e.additionalStoresDisplay),
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Notes',
            icon: const Icon(Icons.sticky_note_2_outlined, size: 18),
            onPressed: () => onOpenNotes(e),
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () => onEdit(e),
          ),
          if (canDelete)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline, size: 18),
              color: const Color(0xFFB3261E),
              onPressed: () => onDelete(e),
            ),
        ],
      )),
    ];

    return DataRow(
      color: e.reviewed
          ? const WidgetStatePropertyAll(Color(0x1F4CAF50))
          : null,
      cells: cells,
    );
  }

  @override
  int get rowCount => _filtered.length;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => 0;
}

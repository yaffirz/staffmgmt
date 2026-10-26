import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/employee.dart';
import '../models/non_oracle_brand.dart';
import '../services/api_client.dart';
import '../services/staff_service.dart';
import '../widgets/app_scaffold.dart';

/// Non-Oracle Employees (Admin → "Non-Oracle Employees").
///
/// IT / Admins mark which brands are NOT on Oracle; every employee of a
/// non-Oracle brand appears in the list, and individuals can be moved in or out
/// regardless of their brand. This roster is the basis for the planned
/// fingerprint clock-in system.
class NonOracleScreen extends StatefulWidget {
  const NonOracleScreen({super.key});

  @override
  State<NonOracleScreen> createState() => _NonOracleScreenState();
}

class _NonOracleScreenState extends State<NonOracleScreen> {
  List<NonOracleBrand> _brands = [];
  List<Employee> _employees = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Set<int> get _nonOracleBrandIds =>
      {for (final b in _brands) if (b.nonOracle) b.brandId};

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = context.read<StaffService>();
      final results =
          await Future.wait([svc.nonOracleBrands(), svc.nonOracleEmployees()]);
      if (!mounted) return;
      setState(() {
        _brands = results[0] as List<NonOracleBrand>;
        _employees = results[1] as List<Employee>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load Non-Oracle data.';
        _loading = false;
      });
    }
  }

  List<Employee> get _filtered {
    if (_query.isEmpty) return _employees;
    final q = _query.toLowerCase();
    return _employees.where((e) {
      return [
        e.employeeName,
        e.payrollId,
        e.brandName ?? '',
        e.storeName ?? '',
        e.positionTitle ?? '',
        e.phoneNumber ?? '',
        e.email ?? '',
      ].join(' ').toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _toggleBrand(NonOracleBrand b, bool value) async {
    try {
      await context.read<StaffService>().setBrandNonOracle(b.brandId, value);
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update the brand.')));
    }
  }

  Future<void> _setOverride(Employee e, bool? override) async {
    try {
      await context.read<StaffService>().setEmployeeNonOracle(e.employeeId, override);
      await _load();
    } on ApiException catch (ex) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ex.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update the employee.')));
    }
  }

  Future<void> _openAddEmployees() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => _AddEmployeesDialog(
        memberIds: {for (final e in _employees) e.employeeId},
      ),
    );
    if (added == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: AppScaffold(
        appBar: AppBar(
          title: const Text('Non-Oracle Employees'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : _load,
            ),
            const SizedBox(width: 6),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: 'Employees (${_employees.length})'),
              Tab(text: 'Brands (${_nonOracleBrandIds.length})'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _errorBody()
                : TabBarView(
                    children: [_employeesTab(), _brandsTab()],
                  ),
      ),
    );
  }

  Widget _errorBody() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );

  Widget _employeesTab() {
    final cs = Theme.of(context).colorScheme;
    final filtered = _filtered;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search name, payroll, store, position…',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _openAddEmployees,
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Add employees'),
              ),
            ],
          ),
        ),
        if (_employees.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No non-Oracle employees yet.\nMark a brand as non-Oracle on '
                  'the Brands tab, or add employees manually.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: PaginatedDataTable(
                  header: Text('${filtered.length} employee(s)',
                      style: const TextStyle(fontSize: 14)),
                  rowsPerPage: 25,
                  availableRowsPerPage: const [25, 50, 100],
                  columns: const [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Payroll ID')),
                    DataColumn(label: Text('Brand')),
                    DataColumn(label: Text('Store')),
                    DataColumn(label: Text('Position')),
                    DataColumn(label: Text('Phone')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('In list via')),
                    DataColumn(label: Text('')),
                  ],
                  source: _NonOracleSource(
                    filtered,
                    cs,
                    onSetOverride: _setOverride,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _brandsTab() {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Mark the brands that are NOT on Oracle. Every employee of a '
            'non-Oracle brand is added to the list automatically.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
        ),
        for (final b in _brands)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: SwitchListTile(
              value: b.nonOracle,
              onChanged: (v) => _toggleBrand(b, v),
              title: Text(b.brandName),
              subtitle: Text(b.nonOracle ? 'Non-Oracle' : 'On Oracle',
                  style: TextStyle(
                      color: b.nonOracle ? const Color(0xFFB26A00) : cs.onSurfaceVariant,
                      fontSize: 12.5)),
              secondary: Icon(
                b.nonOracle ? Icons.cloud_off_outlined : Icons.cloud_outlined,
                color: b.nonOracle ? const Color(0xFFB26A00) : cs.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _NonOracleSource extends DataTableSource {
  final List<Employee> rows;
  final ColorScheme cs;
  final Future<void> Function(Employee, bool?) onSetOverride;

  _NonOracleSource(this.rows, this.cs, {required this.onSetOverride});

  @override
  DataRow? getRow(int index) {
    if (index >= rows.length) return null;
    final e = rows[index];
    final movedIn = e.nonOracleOverride == true;
    return DataRow(cells: [
      DataCell(Text(e.employeeName,
          style: const TextStyle(fontWeight: FontWeight.w600))),
      DataCell(Text(e.payrollId)),
      DataCell(Text(e.brandName ?? '—')),
      DataCell(Text(e.storeName ?? '—')),
      DataCell(Text(e.positionTitle ?? '—')),
      DataCell(Text(e.phoneNumber ?? '—')),
      DataCell(Text(e.email ?? '—')),
      DataCell(_sourceChip(movedIn)),
      DataCell(PopupMenuButton<String>(
        tooltip: 'More',
        icon: const Icon(Icons.more_vert, size: 20),
        onSelected: (v) {
          switch (v) {
            case 'remove':
              onSetOverride(e, false); // force out of the list
              break;
            case 'reset':
              onSetOverride(e, null); // follow the brand again
              break;
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(
              value: 'remove', child: Text('Remove from list')),
          if (e.nonOracleOverride != null)
            const PopupMenuItem(
                value: 'reset', child: Text('Reset to brand default')),
        ],
      )),
    ]);
  }

  Widget _sourceChip(bool movedIn) {
    final color = movedIn ? const Color(0xFF1565C0) : const Color(0xFFB26A00);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(movedIn ? 'Moved in' : 'Brand',
          style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => rows.length;
  @override
  int get selectedRowCount => 0;
}

/// Picker to manually move employees into the non-Oracle list (sets override
/// true). Lists employees not already members, with search.
class _AddEmployeesDialog extends StatefulWidget {
  final Set<int> memberIds;
  const _AddEmployeesDialog({required this.memberIds});

  @override
  State<_AddEmployeesDialog> createState() => _AddEmployeesDialogState();
}

class _AddEmployeesDialogState extends State<_AddEmployeesDialog> {
  List<Employee> _all = [];
  final Set<int> _justAdded = {};
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await context.read<StaffService>().listEmployees();
      if (!mounted) return;
      setState(() {
        _all = all;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load employees.';
        _loading = false;
      });
    }
  }

  List<Employee> get _candidates {
    final q = _query.toLowerCase();
    return _all.where((e) {
      if (widget.memberIds.contains(e.employeeId)) return false;
      if (q.isEmpty) return true;
      return [e.employeeName, e.payrollId, e.brandName ?? '', e.storeName ?? '']
          .join(' ')
          .toLowerCase()
          .contains(q);
    }).toList();
  }

  Future<void> _add(Employee e) async {
    setState(() => _justAdded.add(e.employeeId));
    try {
      await context.read<StaffService>().setEmployeeNonOracle(e.employeeId, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _justAdded.remove(e.employeeId));
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add that employee.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final candidates = _candidates;
    return AlertDialog(
      title: const Text('Add employees to the list'),
      content: SizedBox(
        width: 460,
        height: 460,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : Column(
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          isDense: true,
                          prefixIcon: const Icon(Icons.search),
                          hintText: 'Search name, payroll, store…',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onChanged: (v) => setState(() => _query = v.trim()),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: candidates.isEmpty
                            ? Center(
                                child: Text('No matching employees.',
                                    style: TextStyle(
                                        color: cs.onSurfaceVariant)))
                            : ListView.builder(
                                itemCount: candidates.length,
                                itemBuilder: (_, i) {
                                  final e = candidates[i];
                                  final added =
                                      _justAdded.contains(e.employeeId);
                                  return ListTile(
                                    dense: true,
                                    title: Text(e.employeeName),
                                    subtitle: Text([
                                      e.payrollId,
                                      if ((e.brandName ?? '').isNotEmpty)
                                        e.brandName!,
                                      if ((e.storeName ?? '').isNotEmpty)
                                        e.storeName!,
                                    ].join(' · ')),
                                    trailing: added
                                        ? const Icon(Icons.check_circle,
                                            color: Color(0xFF2E7D43))
                                        : TextButton(
                                            onPressed: () => _add(e),
                                            child: const Text('Add'),
                                          ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _justAdded.isNotEmpty),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/store_staff.dart';
import '../services/staff_service.dart';
import '../widgets/app_scaffold.dart';
import 'employee_detail_screen.dart';

/// Shows the staff currently at a store. Reached by deep-link from a
/// notification (e.g. "staff moved here"), which passes [highlightEmployeeId]
/// so the relevant person is called out.
class StoreDrilldownScreen extends StatefulWidget {
  final int storeId;
  final String? storeName;
  final int? highlightEmployeeId;

  const StoreDrilldownScreen({
    super.key,
    required this.storeId,
    this.storeName,
    this.highlightEmployeeId,
  });

  @override
  State<StoreDrilldownScreen> createState() => _StoreDrilldownScreenState();
}

class _StoreDrilldownScreenState extends State<StoreDrilldownScreen> {
  late Future<StoreStaff> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<StoreStaff> _load() =>
      context.read<StaffService>().staffAtStore(widget.storeId);

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: Text(widget.storeName ?? 'Store'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: FutureBuilder<StoreStaff>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load this store.'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _reload, child: const Text('Retry')),
                ],
              ),
            );
          }
          return _body(context, snap.data!);
        },
      ),
    );
  }

  Widget _body(BuildContext context, StoreStaff data) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.storeName,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                '${data.brandName}  ·  ${data.staff.length} staff',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              if (data.staff.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text('No staff assigned to this store yet.',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  ),
                )
              else
                Material(
                  // Explicit surface + no tint, matching the employees table, so
                  // the M3 elevation overlay doesn't tint the card.
                  color: isDark ? cs.surfaceContainerHigh : Colors.white,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  borderRadius: BorderRadius.circular(14),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 28,
                      showCheckboxColumn: false,
                      columns: const [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Position')),
                        DataColumn(label: Text('Payroll ID')),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: [for (final m in data.staff) _row(context, m, cs)],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  DataRow _row(BuildContext context, StoreStaffMember m, ColorScheme cs) {
    final highlighted = m.employeeId == widget.highlightEmployeeId;
    final tags = <Widget>[
      if (highlighted)
        _chip(context, 'Recently added', cs.primary, onColor: cs.onPrimary),
      if (m.alsoCovers)
        _chip(context, 'Also covers', cs.secondaryContainer,
            onColor: cs.onSecondaryContainer),
    ];
    return DataRow(
      color:
          highlighted ? WidgetStatePropertyAll(cs.primaryContainer) : null,
      onSelectChanged: (_) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EmployeeDetailScreen(
            employeeId: m.employeeId,
            employeeName: m.employeeName,
          ),
        ),
      ),
      cells: [
        DataCell(SelectableText(
          m.employeeName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        )),
        DataCell(SelectableText(m.positionTitle ?? '—')),
        DataCell(SelectableText(m.payrollId)),
        DataCell(
          tags.isEmpty
              ? const Text('—')
              : Wrap(spacing: 6, children: tags),
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, String label, Color bg,
      {required Color onColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: onColor),
      ),
    );
  }
}

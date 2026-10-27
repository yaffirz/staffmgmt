import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/attendance.dart';
import '../services/api_client.dart';
import '../services/staff_service.dart';
import '../widgets/app_scaffold.dart';
import 'attendance_pdf.dart';

/// Weekly attendance register per store — formatted like the paper register:
/// each employee's Monday–Sunday with Roster (scheduled) · IN · OUT · Hours.
class AttendanceRegisterScreen extends StatefulWidget {
  const AttendanceRegisterScreen({super.key});

  @override
  State<AttendanceRegisterScreen> createState() =>
      _AttendanceRegisterScreenState();
}

class _AttendanceRegisterScreenState extends State<AttendanceRegisterScreen> {
  List<AttendanceStore> _stores = [];
  int? _storeId;
  late DateTime _monday;
  AttendanceRegister? _register;
  bool _loading = true;
  bool _loadingRegister = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1)); // Monday
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stores = await context.read<StaffService>().attendanceStores();
      if (!mounted) return;
      setState(() {
        _stores = stores;
        _storeId = stores.isNotEmpty ? stores.first.storeId : null;
        _loading = false;
      });
      if (_storeId != null) _loadRegister();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load stores.';
        _loading = false;
      });
    }
  }

  String get _weekStartIso =>
      '${_monday.year}-${_monday.month.toString().padLeft(2, '0')}-${_monday.day.toString().padLeft(2, '0')}';

  Future<void> _loadRegister() async {
    if (_storeId == null) return;
    setState(() {
      _loadingRegister = true;
      _error = null;
    });
    try {
      final reg = await context
          .read<StaffService>()
          .attendanceRegister(_storeId!, _weekStartIso);
      if (!mounted) return;
      setState(() {
        _register = reg;
        _loadingRegister = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load the register.';
        _loadingRegister = false;
      });
    }
  }

  void _shiftWeek(int deltaWeeks) {
    setState(() => _monday = _monday.add(Duration(days: 7 * deltaWeeks)));
    _loadRegister();
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  String _weekLabel() {
    final end = _monday.add(const Duration(days: 6));
    final s = '${_months[_monday.month - 1]} ${_monday.day}';
    final e = '${_months[end.month - 1]} ${end.day}, ${end.year}';
    return '$s – $e';
  }

  Future<void> _editRoster(AttendanceRow row, AttendanceDay day) async {
    final ctrl = TextEditingController(text: day.roster ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${row.employeeName} · ${day.weekday}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Roster',
            hintText: 'e.g. 7-3pm, OFF, VACATION',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (value == null || !mounted) return;
    try {
      await context.read<StaffService>().setShift(row.employeeId, day.date, value);
      await _loadRegister();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _print() async {
    final reg = _register;
    if (reg == null) return;
    try {
      await printAttendanceRegister(reg, _weekLabel());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the print view.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Attendance Register'),
        actions: [
          IconButton(
            tooltip: 'Print / PDF',
            icon: const Icon(Icons.print_outlined),
            onPressed: _register == null ? null : _print,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadingRegister ? null : _loadRegister,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _stores.isEmpty
              ? Center(child: Text(_error ?? 'No stores available.'))
              : Column(
                  children: [
                    _controls(),
                    const Divider(height: 1),
                    Expanded(child: _body()),
                  ],
                ),
    );
  }

  Widget _controls() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 280,
            child: DropdownButtonFormField<int>(
              initialValue: _storeId,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Store',
                border: OutlineInputBorder(),
              ),
              items: _stores
                  .map((s) => DropdownMenuItem(
                        value: s.storeId,
                        child: Text(s.storeName,
                            overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) {
                setState(() => _storeId = v);
                _loadRegister();
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Previous week',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _shiftWeek(-1),
                ),
                Text(_weekLabel(),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                IconButton(
                  tooltip: 'Next week',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _shiftWeek(1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loadingRegister) {
      return const Center(child: CircularProgressIndicator());
    }
    final reg = _register;
    if (reg == null) {
      return Center(child: Text(_error ?? 'Pick a store.'));
    }
    if (reg.employees.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            'No clock-in staff at ${reg.storeName}.\nStaff appear here once their '
            'brand is Non-Oracle and their primary store is this one.',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${reg.storeName}  ·  ${_weekLabel()}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [for (final e in reg.employees) _employeeBlock(e)],
          ),
        ],
      ),
    );
  }

  Widget _employeeBlock(AttendanceRow row) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 430,
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(row.employeeName,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                Text('Payroll ${row.payrollId}',
                    style:
                        TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          _headerRow(cs),
          for (final d in row.days) _dayRow(cs, row, d),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Total hours:  ',
                    style: TextStyle(color: cs.onSurfaceVariant)),
                Text(row.totalHours,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Column widths: Day, Date, Roster, IN, OUT, Hours.
  static const _cw = <int, TableColumnWidth>{
    0: FixedColumnWidth(74),
    1: FixedColumnWidth(34),
    2: FlexColumnWidth(1),
    3: FixedColumnWidth(74),
    4: FixedColumnWidth(74),
    5: FixedColumnWidth(48),
  };

  Widget _headerRow(ColorScheme cs) {
    TableCell h(String t, {TextAlign align = TextAlign.left}) => TableCell(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Text(t,
                textAlign: align,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant)),
          ),
        );
    return Table(
      columnWidths: _cw,
      border: TableBorder(
          bottom: BorderSide(color: cs.outlineVariant),
          top: BorderSide(color: cs.outlineVariant)),
      children: [
        TableRow(children: [
          h('Day'),
          h('Dt'),
          h('Roster'),
          h('In'),
          h('Out'),
          h('Hrs', align: TextAlign.right),
        ]),
      ],
    );
  }

  Widget _dayRow(ColorScheme cs, AttendanceRow row, AttendanceDay d) {
    final off = (d.roster ?? '').toUpperCase().contains('OFF') ||
        (d.roster ?? '').toUpperCase().contains('VAC');
    TableCell cell(Widget child, {int pad = 6}) => TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: pad.toDouble(), vertical: 7),
            child: child,
          ),
        );
    Widget txt(String? t, {TextAlign align = TextAlign.left, Color? color}) =>
        Text(t == null || t.isEmpty ? '—' : t,
            textAlign: align,
            style: TextStyle(
                fontSize: 12.5,
                color: color ??
                    (t == null || t.isEmpty ? cs.onSurfaceVariant : cs.onSurface)));
    return Table(
      columnWidths: _cw,
      border: TableBorder(
          horizontalInside: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
      children: [
        TableRow(children: [
          cell(txt(d.weekday)),
          cell(txt(d.dayNum, align: TextAlign.center)),
          cell(
            InkWell(
              onTap: () => _editRoster(row, d),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  (d.roster == null || d.roster!.isEmpty) ? 'tap to set' : d.roster!,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: off ? FontWeight.w700 : FontWeight.w500,
                    fontStyle: (d.roster == null || d.roster!.isEmpty)
                        ? FontStyle.italic
                        : FontStyle.normal,
                    color: off
                        ? const Color(0xFFB26A00)
                        : (d.roster == null || d.roster!.isEmpty)
                            ? cs.primary
                            : cs.onSurface,
                  ),
                ),
              ),
            ),
            pad: 2,
          ),
          cell(txt(d.inTime, color: const Color(0xFF2E7D43))),
          cell(txt(d.outTime, color: const Color(0xFFB26A00))),
          cell(txt(d.hours, align: TextAlign.right)),
        ]),
      ],
    );
  }
}

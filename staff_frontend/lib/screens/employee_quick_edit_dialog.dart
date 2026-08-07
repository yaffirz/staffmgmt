import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/directory.dart';
import '../models/employee.dart';
import '../services/api_client.dart';
import '../services/staff_service.dart';

/// Opens a compact popup to edit an employee's core details inline. Returns
/// true if changes were saved (so the caller can refresh).
Future<bool?> showEmployeeQuickEdit(BuildContext context, Employee employee) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _EmployeeQuickEditDialog(employee: employee),
  );
}

class _EmployeeQuickEditDialog extends StatefulWidget {
  final Employee employee;
  const _EmployeeQuickEditDialog({required this.employee});

  @override
  State<_EmployeeQuickEditDialog> createState() =>
      _EmployeeQuickEditDialogState();
}

class _EmployeeQuickEditDialogState extends State<_EmployeeQuickEditDialog> {
  final _nameCtrl = TextEditingController();
  final _payrollCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _payrateCtrl = TextEditingController();
  final _magCtrl = TextEditingController();

  late DateTime _dob;
  int? _brandId;
  int? _storeId;
  int? _positionId;
  int? _countryId;
  String? _currency;

  List<Brand> _brands = [];
  List<Store> _stores = [];
  List<Position> _positions = [];
  List<Country> _countries = [];

  bool _loading = true;
  bool _saving = false;
  String? _error;

  static const _currencies = ['TTD', 'USD', 'JAM', 'XCD'];

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _nameCtrl.text = e.employeeName;
    _payrollCtrl.text = e.payrollId;
    _emailCtrl.text = e.email ?? '';
    _phoneCtrl.text = e.phoneNumber ?? '';
    _payrateCtrl.text = e.payrate?.toStringAsFixed(2) ?? '';
    _magCtrl.text = e.magCode ?? '';
    _dob = e.dateOfBirth;
    _storeId = e.primaryStoreId;
    _positionId = e.positionId;
    _countryId = e.countryId;
    _currency = (e.payCurrency == null || e.payCurrency!.isEmpty)
        ? null
        : e.payCurrency;
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _payrollCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _payrateCtrl.dispose();
    _magCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final svc = context.read<StaffService>();
      final results = await Future.wait([
        svc.brands(),
        svc.stores(),
        svc.positions(),
        svc.countries(),
      ]);
      if (!mounted) return;
      setState(() {
        _brands = results[0] as List<Brand>;
        _stores = results[1] as List<Store>;
        _positions = results[2] as List<Position>;
        _countries = results[3] as List<Country>;
        // Derive the current brand from the primary store.
        for (final s in _stores) {
          if (s.id == _storeId) _brandId = s.brandId;
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load options.';
        _loading = false;
      });
    }
  }

  /// Stores for the chosen brand, always including the currently-selected one
  /// (guards Flutter's "dropdown value not in items" assertion for edge data).
  List<Store> get _storesForBrand {
    final list =
        _brandId == null ? <Store>[] : _stores.where((s) => s.brandId == _brandId).toList();
    if (_storeId != null && !list.any((s) => s.id == _storeId)) {
      final cur = _stores.where((s) => s.id == _storeId);
      if (cur.isNotEmpty) list.add(cur.first);
    }
    return list;
  }

  List<Position> get _positionsForBrand {
    final list = _brandId == null
        ? <Position>[]
        : _positions.where((p) => p.availableForBrand(_brandId!)).toList();
    if (_positionId != null && !list.any((p) => p.id == _positionId)) {
      final cur = _positions.where((p) => p.id == _positionId);
      if (cur.isNotEmpty) list.add(cur.first);
    }
    return list;
  }

  String _wireDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String get _dobDisplay =>
      '${_dob.month.toString().padLeft(2, '0')}/'
      '${_dob.day.toString().padLeft(2, '0')}/${_dob.year}';

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob,
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final payroll = _payrollCtrl.text.trim();
    if (name.isEmpty || payroll.isEmpty) {
      setState(() => _error = 'Name and Payroll ID are required.');
      return;
    }
    if (_storeId == null || _positionId == null) {
      setState(() => _error = 'Store and Position are required.');
      return;
    }
    double? payrate;
    final rateText = _payrateCtrl.text.trim();
    if (rateText.isNotEmpty) {
      payrate = double.tryParse(rateText);
      if (payrate == null || payrate < 0) {
        setState(() => _error = 'Pay rate must be a positive number.');
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final payload = <String, dynamic>{
      'payroll_id': payroll,
      'employee_name': name,
      'date_of_birth': _wireDate(_dob),
      'primary_store_id': _storeId,
      'position_id': _positionId,
      'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      'payrate': payrate,
      'pay_currency': _currency,
      'phone_number':
          _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      'mag_code': _magCtrl.text.trim().isEmpty ? null : _magCtrl.text.trim(),
      'country_id': _countryId,
      // Preserve the employee's existing additional stores.
      'additional_store_ids': widget.employee.additionalStoreIds,
    };
    try {
      await context
          .read<StaffService>()
          .updateEmployee(widget.employee.employeeId, payload);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save changes.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyItems = <String>{
      ..._currencies,
      if (_currency != null) _currency!,
    }.toList();

    return AlertDialog(
      title: Text('Edit ${widget.employee.employeeName}'),
      content: SizedBox(
        width: 460,
        child: _loading
            ? const SizedBox(
                height: 120, child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _field(_nameCtrl, 'Full name'),
                    _field(_payrollCtrl, 'Payroll ID'),
                    // DOB
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: _pickDob,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date of birth',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          child: Text(_dobDisplay),
                        ),
                      ),
                    ),
                    _dropdown<int>(
                      'Brand',
                      _brandId,
                      _brands.map((b) => DropdownMenuItem(
                          value: b.id, child: Text(b.name))),
                      (v) => setState(() {
                        _brandId = v;
                        _storeId = null;
                        _positionId = null;
                      }),
                    ),
                    _dropdown<int>(
                      'Store',
                      _storeId,
                      _storesForBrand.map((s) => DropdownMenuItem(
                          value: s.id, child: Text(s.name))),
                      (v) => setState(() => _storeId = v),
                    ),
                    _dropdown<int>(
                      'Position',
                      _positionId,
                      _positionsForBrand.map((p) => DropdownMenuItem(
                          value: p.id, child: Text(p.title))),
                      (v) => setState(() => _positionId = v),
                    ),
                    _field(_emailCtrl, 'Email',
                        keyboard: TextInputType.emailAddress),
                    _field(_phoneCtrl, 'Phone number',
                        keyboard: TextInputType.phone),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _field(_payrateCtrl, 'Pay rate',
                              keyboard: TextInputType.number),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _dropdown<String>(
                            'Currency',
                            _currency,
                            currencyItems.map((c) =>
                                DropdownMenuItem(value: c, child: Text(c))),
                            (v) => setState(() => _currency = v),
                          ),
                        ),
                      ],
                    ),
                    _dropdown<int>(
                      'Country',
                      _countryId,
                      _countries.map((c) => DropdownMenuItem(
                          value: c.id, child: Text(c.name))),
                      (v) => setState(() => _countryId = v),
                    ),
                    _field(_magCtrl, 'MAG card'),
                    if (_error != null) ...[
                      const SizedBox(height: 4),
                      Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 13)),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving || _loading ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _dropdown<T>(
    String label,
    T? value,
    Iterable<DropdownMenuItem<T>> items,
    ValueChanged<T?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        items: items.toList(),
        onChanged: onChanged,
      ),
    );
  }
}

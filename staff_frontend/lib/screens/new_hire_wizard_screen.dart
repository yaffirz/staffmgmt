import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/directory.dart';
import '../models/employee.dart';
import '../models/form_field_config.dart';
import '../services/api_client.dart';
import '../services/staff_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';

class NewHireWizardScreen extends StatefulWidget {
  /// When provided, the wizard edits this employee instead of creating one.
  final Employee? editing;
  const NewHireWizardScreen({super.key, this.editing});

  @override
  State<NewHireWizardScreen> createState() => _NewHireWizardScreenState();
}

class _NewHireWizardScreenState extends State<NewHireWizardScreen> {
  static const _steps = ['Identity', 'Role & store', 'Contact & pay'];

  final _payrollCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _payrateCtrl = TextEditingController();
  final _magCtrl = TextEditingController();

  final _formKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];

  DateTime? _dob;
  bool _dobError = false;
  int? _brandId;
  int? _positionId;
  int? _storeId;
  int? _countryId;
  String? _currency = 'TTD'; // required; sensible default for Trinidad
  final List<int> _additionalStoreIds = []; // optional
  bool _additionalError = false;

  static const _currencies = ['JAM', 'XCD', 'TTD', 'USD'];

  List<Brand> _brands = [];
  List<Store> _stores = [];
  List<Position> _positions = [];
  List<Country> _countries = [];

  // Form field config (keyed by field_key). Drives which fields show and
  // which are required. Falls back to sensible defaults if unavailable.
  Map<String, FormFieldConfig> _config = {};
  static const _fallbackRequired = {'email', 'payrate', 'pay_currency'};

  bool _shown(String key) => _config[key]?.enabled ?? true;
  bool _req(String key) =>
      _config[key]?.required ?? _fallbackRequired.contains(key);
  String _star(String key) => _req(key) ? ' *' : '';

  bool _loading = true;
  String? _loadError;
  bool _submitting = false;
  String? _submitError;
  int _step = 0;
  int _resetTick = 0; // bumped to force position/store dropdowns to rebuild clean

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _payrollCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _payrateCtrl.dispose();
    _magCtrl.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.editing != null;

  void _prefillFrom(Employee e) {
    _payrollCtrl.text = e.payrollId;
    _nameCtrl.text = e.employeeName;
    _dob = e.dateOfBirth;
    _storeId = e.primaryStoreId;
    _positionId = e.positionId;
    for (final s in _stores) {
      if (s.id == e.primaryStoreId) {
        _brandId = s.brandId;
        break;
      }
    }
    _countryId = e.countryId;
    _currency = e.payCurrency ?? 'TTD';
    _emailCtrl.text = e.email ?? '';
    _payrateCtrl.text =
        e.payrate != null ? e.payrate!.toStringAsFixed(2) : '';
    _phoneCtrl.text = e.phoneNumber ?? '';
    _magCtrl.text = e.magCode ?? '';
    _additionalStoreIds
      ..clear()
      ..addAll(e.additionalStoreIds);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final svc = context.read<StaffService>();
      final results = await Future.wait([
        svc.brands(),
        svc.stores(),
        svc.positions(),
        svc.countries(),
        svc.formConfig('employee'),
      ]);
      if (!mounted) return;
      setState(() {
        _brands = results[0] as List<Brand>;
        _stores = results[1] as List<Store>;
        _positions = results[2] as List<Position>;
        _countries = results[3] as List<Country>;
        _config = {
          for (final c in results[4] as List<FormFieldConfig>) c.fieldKey: c
        };
        if (_isEditing) {
          _prefillFrom(widget.editing!);
        } else {
          // Sensible defaults.
          if (_brands.length == 1) _brandId = _brands.first.id;
          final tt = _countries.where((c) => c.name == 'Trinidad');
          if (tt.isNotEmpty) {
            _countryId = tt.first.id;
          } else if (_countries.isNotEmpty) {
            _countryId = _countries.first.id;
          }
        }
        _loading = false;
      });
      // Auto-fill MAG card with the next suggested number (new hires only).
      if (!_isEditing) {
        try {
          final mag = await svc.nextMagCode();
          if (mounted && mag != null && _magCtrl.text.trim().isEmpty) {
            _magCtrl.text = mag;
          }
        } catch (_) {
          // Non-fatal: leave MAG blank if the suggestion can't be fetched.
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load form data. Check the server connection.';
        _loading = false;
      });
    }
  }

  List<Store> get _storesForBrand =>
      _brandId == null ? [] : _stores.where((s) => s.brandId == _brandId).toList();

  List<Position> get _positionsForBrand => _brandId == null
      ? []
      : _positions.where((p) => p.brandId == _brandId).toList();

  String _fmtDisplay(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';

  String _fmtIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(1940),
      lastDate: now,
      helpText: 'Select date of birth',
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _dobError = false;
      });
    }
  }

  void _next() {
    final form = _formKeys[_step].currentState;
    final ok = form == null || form.validate();
    // Step 0 also requires a date of birth.
    if (_step == 0 && _dob == null) {
      setState(() => _dobError = true);
      return;
    }
    // Step 1: additional stores may be required by config (not a FormField).
    if (_step == 1 &&
        _shown('additional_store_ids') &&
        _req('additional_store_ids') &&
        _additionalStoreIds.isEmpty) {
      setState(() => _additionalError = true);
      if (!ok) return;
      return;
    }
    if (!ok) return;
    setState(() => _step += 1);
  }

  void _back() {
    if (_step == 0) {
      Navigator.of(context).pop();
    } else {
      setState(() => _step -= 1);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKeys[2].currentState!.validate()) return;

    final payload = <String, dynamic>{
      'payroll_id': _payrollCtrl.text.trim(),
      'employee_name': _nameCtrl.text.trim(),
      'date_of_birth': _fmtIso(_dob!),
      'primary_store_id': _storeId,
      'position_id': _positionId,
    };
    if (_shown('email') && _emailCtrl.text.trim().isNotEmpty) {
      payload['email'] = _emailCtrl.text.trim();
    }
    if (_shown('payrate') && _payrateCtrl.text.trim().isNotEmpty) {
      payload['payrate'] = double.parse(_payrateCtrl.text.trim());
    }
    if (_shown('pay_currency') && _currency != null) {
      payload['pay_currency'] = _currency;
    }
    if (_shown('phone_number') && _phoneCtrl.text.trim().isNotEmpty) {
      payload['phone_number'] = _phoneCtrl.text.trim();
    }
    if (_shown('mag_code') && _magCtrl.text.trim().isNotEmpty) {
      payload['mag_code'] = _magCtrl.text.trim();
    }
    if (_shown('country_id') && _countryId != null) {
      payload['country_id'] = _countryId;
    }
    if (_shown('additional_store_ids') && _additionalStoreIds.isNotEmpty) {
      payload['additional_store_ids'] = List<int>.from(_additionalStoreIds);
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final svc = context.read<StaffService>();
      if (_isEditing) {
        await svc.updateEmployee(widget.editing!.employeeId, payload);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employee updated')),
        );
        Navigator.of(context).pop(true);
        return;
      }
      await svc.createEmployee(payload);
      if (!mounted) return;
      _showSuccess(payload['payroll_id'] as String);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = e.message;
        // A duplicate payroll_id lives on step 0 — send them back to fix it.
        if (e.statusCode == 409) _step = 0;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = 'Could not reach the server. Please try again.';
      });
    }
  }

  void _showSuccess(String payroll) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('New hire added'),
        content: Text('Employee $payroll has been created.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetForm();
            },
            child: const Text('Add another'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    _payrollCtrl.clear();
    _nameCtrl.clear();
    _phoneCtrl.clear();
    _emailCtrl.clear();
    _payrateCtrl.clear();
    _magCtrl.clear();
    // Re-suggest the next MAG number for the following hire.
    () async {
      try {
        final mag = await context.read<StaffService>().nextMagCode();
        if (mounted && mag != null && _magCtrl.text.trim().isEmpty) {
          _magCtrl.text = mag;
        }
      } catch (_) {}
    }();
    setState(() {
      _dob = null;
      _dobError = false;
      _positionId = null;
      _storeId = null;
      _additionalStoreIds.clear();
      _submitting = false;
      _submitError = null;
      _step = 0;
      _resetTick += 1;
      // keep _brandId and _countryId as convenient defaults for the next hire
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit employee' : 'New hire')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _LoadError(message: _loadError!, onRetry: _load)
              : _buildWizard(context),
    );
  }

  Widget _buildWizard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLast = _step == _steps.length - 1;

    return Column(
      children: [
        _StepHeader(steps: _steps, current: _step),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_step == 0) _identityStep(),
                    if (_step == 1) _roleStoreStep(cs),
                    if (_step == 2) _contactPayStep(),
                    if (_submitError != null) ...[
                      const SizedBox(height: 16),
                      _ErrorBanner(message: _submitError!),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        _BottomBar(
          isFirst: _step == 0,
          isLast: isLast,
          submitting: _submitting,
          submitLabel: _isEditing ? 'Save' : 'Add employee',
          onBack: _back,
          onNext: _next,
          onSubmit: _submit,
        ),
      ],
    );
  }

  // ---- Steps -------------------------------------------------------------

  Widget _identityStep() {
    return Form(
      key: _formKeys[0],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _payrollCtrl,
            decoration: const InputDecoration(labelText: 'Payroll ID *'),
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Payroll ID is required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Full name *'),
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: 16),
          _DateField(
            label: 'Date of birth *',
            value: _dob == null ? null : _fmtDisplay(_dob!),
            error: _dobError ? 'Date of birth is required' : null,
            onTap: _pickDob,
          ),
        ],
      ),
    );
  }

  Widget _roleStoreStep(ColorScheme cs) {
    return Form(
      key: _formKeys[1],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<int>(
            initialValue: _brandId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Brand *'),
            items: _brands
                .map((b) =>
                    DropdownMenuItem(value: b.id, child: Text(b.name)))
                .toList(),
            validator: (v) => v == null ? 'Brand is required' : null,
            onChanged: (v) => setState(() {
              _brandId = v;
              _positionId = null;
              _storeId = null;
              _additionalStoreIds.clear();
            }),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            key: ValueKey('position-$_brandId-$_resetTick'),
            initialValue: _positionId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Position *',
              helperText: _brandId == null ? 'Choose a brand first' : null,
            ),
            items: _positionsForBrand
                .map((p) =>
                    DropdownMenuItem(value: p.id, child: Text(p.title)))
                .toList(),
            validator: (v) => v == null ? 'Position is required' : null,
            onChanged: _brandId == null
                ? null
                : (v) => setState(() => _positionId = v),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            key: ValueKey('store-$_brandId-$_resetTick'),
            initialValue: _storeId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Primary store *',
              helperText: _brandId == null ? 'Choose a brand first' : null,
            ),
            items: _storesForBrand
                .map((s) =>
                    DropdownMenuItem(value: s.id, child: Text(s.name)))
                .toList(),
            validator: (v) => v == null ? 'Primary store is required' : null,
            onChanged: _brandId == null
                ? null
                : (v) => setState(() {
                      _storeId = v;
                      _additionalStoreIds.remove(v);
                    }),
          ),
          if (_shown('additional_store_ids')) ...[
            const SizedBox(height: 16),
            _AdditionalStores(
              stores: _storesForBrand,
              primaryStoreId: _storeId,
              selectedIds: _additionalStoreIds,
              enabled: _brandId != null,
              required: _req('additional_store_ids'),
              errorText: (_additionalError && _additionalStoreIds.isEmpty)
                  ? 'At least one additional store is required'
                  : null,
              onAddMany: (ids) => setState(() {
                _additionalStoreIds.addAll(ids);
                _additionalError = false;
              }),
              onRemove: (id) => setState(() => _additionalStoreIds.remove(id)),
            ),
          ],
          if (_shown('country_id')) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _countryId,
              isExpanded: true,
              decoration: InputDecoration(labelText: 'Country${_star('country_id')}'),
              items: _countries
                  .map((c) =>
                      DropdownMenuItem(value: c.id, child: Text(c.name)))
                  .toList(),
              validator: _req('country_id')
                  ? (v) => v == null ? 'Country is required' : null
                  : null,
              onChanged: (v) => setState(() => _countryId = v),
            ),
          ],
        ],
      ),
    );
  }

  Widget _payRow() {
    final showRate = _shown('payrate');
    final showCur = _shown('pay_currency');
    final rate = TextFormField(
      controller: _payrateCtrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Pay rate${_star('payrate')}',
        hintText: '0.00',
      ),
      validator: (v) {
        final t = v?.trim() ?? '';
        if (t.isEmpty) return _req('payrate') ? 'Pay rate is required' : null;
        final n = double.tryParse(t);
        if (n == null) return 'Enter a number';
        if (n < 0) return 'Cannot be negative';
        return null;
      },
    );
    final cur = DropdownButtonFormField<String>(
      initialValue: _currency,
      isExpanded: true,
      decoration: InputDecoration(labelText: 'Currency${_star('pay_currency')}'),
      items: _currencies
          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
          .toList(),
      validator:
          _req('pay_currency') ? (v) => v == null ? 'Required' : null : null,
      onChanged: (v) => setState(() => _currency = v),
    );
    if (showRate && showCur) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: rate),
          const SizedBox(width: 12),
          SizedBox(width: 120, child: cur),
        ],
      );
    }
    return showRate ? rate : cur;
  }

  Widget _contactPayStep() {
    return Form(
      key: _formKeys[2],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_shown('phone_number')) ...[
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                  labelText: 'Phone number${_star('phone_number')}'),
              validator: _req('phone_number')
                  ? (v) => (v == null || v.trim().isEmpty)
                      ? 'Phone is required'
                      : null
                  : null,
            ),
            const SizedBox(height: 16),
          ],
          if (_shown('email')) ...[
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: 'Email${_star('email')}'),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return _req('email') ? 'Email is required' : null;
                final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t);
                return ok ? null : 'Enter a valid email address';
              },
            ),
            const SizedBox(height: 16),
          ],
          if (_shown('payrate') || _shown('pay_currency')) ...[
            _payRow(),
            const SizedBox(height: 16),
          ],
          if (_shown('mag_code')) ...[
            TextFormField(
              controller: _magCtrl,
              decoration:
                  InputDecoration(labelText: 'MAG code${_star('mag_code')}'),
              validator: _req('mag_code')
                  ? (v) => (v == null || v.trim().isEmpty)
                      ? 'MAG card is required'
                      : null
                  : null,
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 24),
          _ReviewCard(
            name: _nameCtrl.text.trim(),
            payroll: _payrollCtrl.text.trim(),
            dob: _dob == null ? '—' : _fmtDisplay(_dob!),
            position: _nameForId(
                _positionsForBrand.map((p) => MapEntry(p.id, p.title)),
                _positionId),
            store: _nameForId(
                _storesForBrand.map((s) => MapEntry(s.id, s.name)), _storeId),
            country: _nameForId(
                _countries.map((c) => MapEntry(c.id, c.name)), _countryId),
          ),
        ],
      ),
    );
  }

  String _nameForId(Iterable<MapEntry<int, String>> entries, int? id) {
    if (id == null) return '—';
    for (final e in entries) {
      if (e.key == id) return e.value;
    }
    return '—';
  }
}

// ---- Small presentational pieces -----------------------------------------

class _StepHeader extends StatelessWidget {
  final List<String> steps;
  final int current;
  const _StepHeader({required this.steps, required this.current});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Row(
            children: [
              for (int i = 0; i < steps.length; i++) ...[
                _Dot(index: i, current: current),
                const SizedBox(width: 8),
                Text(
                  steps[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        i == current ? FontWeight.w700 : FontWeight.w500,
                    color: i <= current ? cs.onSurface : cs.onSurfaceVariant,
                  ),
                ),
                if (i < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 1.5,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      color: cs.outlineVariant,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final int index;
  final int current;
  const _Dot({required this.index, required this.current});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final done = index < current;
    final active = index == current;
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: (done || active) ? AppColors.ink : Colors.transparent,
        border: Border.all(
          color: (done || active) ? AppColors.ink : cs.outlineVariant,
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: done
          ? const Icon(Icons.check, size: 15, color: Colors.white)
          : Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : cs.onSurfaceVariant,
              ),
            ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String? value;
  final String? error;
  final VoidCallback onTap;
  const _DateField({
    required this.label,
    required this.value,
    required this.error,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: error,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          value ?? 'MM/DD/YYYY',
          style: TextStyle(
            color: value == null
                ? Theme.of(context).hintColor
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final String name;
  final String payroll;
  final String dob;
  final String position;
  final String store;
  final String country;
  const _ReviewCard({
    required this.name,
    required this.payroll,
    required this.dob,
    required this.position,
    required this.store,
    required this.country,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 90,
                child: Text(k,
                    style: TextStyle(
                        fontSize: 13, color: cs.onSurfaceVariant)),
              ),
              Expanded(
                child: Text(v.isEmpty ? '—' : v,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          row('Name', name),
          row('Payroll ID', payroll),
          row('Born', dob),
          row('Position', position),
          row('Store', store),
          row('Country', country),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final bool isFirst;
  final bool isLast;
  final bool submitting;
  final String submitLabel;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSubmit;
  const _BottomBar({
    required this.isFirst,
    required this.isLast,
    required this.submitting,
    required this.submitLabel,
    required this.onBack,
    required this.onNext,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: submitting ? null : onBack,
                child: Text(isFirst ? 'Cancel' : 'Back'),
              ),
              FilledButton(
                onPressed: submitting ? null : (isLast ? onSubmit : onNext),
                child: submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Text(isLast ? submitLabel : 'Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEDED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE7B4B4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18, color: Color(0xFFB23B3B)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF8E2F2F), fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdditionalStores extends StatelessWidget {
  final List<Store> stores;
  final int? primaryStoreId;
  final List<int> selectedIds;
  final bool enabled;
  final bool required;
  final String? errorText;
  final void Function(List<int> ids) onAddMany;
  final void Function(int id) onRemove;
  const _AdditionalStores({
    required this.stores,
    required this.primaryStoreId,
    required this.selectedIds,
    required this.enabled,
    required this.onAddMany,
    required this.onRemove,
    this.required = false,
    this.errorText,
  });

  String _nameOf(int id) {
    for (final s in stores) {
      if (s.id == id) return s.name;
    }
    return 'Store $id';
  }

  Future<void> _pick(BuildContext context) async {
    final available = stores
        .where((s) => s.id != primaryStoreId && !selectedIds.contains(s.id))
        .toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No more stores available for this brand')),
      );
      return;
    }
    final chosen = <int>{};
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Add additional stores'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: available
                  .map((s) => CheckboxListTile(
                        dense: true,
                        value: chosen.contains(s.id),
                        title: Text(s.name),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (v) => setLocal(() {
                          if (v == true) {
                            chosen.add(s.id);
                          } else {
                            chosen.remove(s.id);
                          }
                        }),
                      ))
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && chosen.isNotEmpty) {
      onAddMany(chosen.toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Additional stores${required ? ' *' : ' (optional)'}',
            style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        if (selectedIds.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: selectedIds
                .map((id) => Chip(
                      label: Text(_nameOf(id)),
                      onDeleted: () => onRemove(id),
                    ))
                .toList(),
          ),
        if (selectedIds.isNotEmpty) const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: enabled ? () => _pick(context) : null,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add additional store'),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(errorText!,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error)),
          ),
      ],
    );
  }
}

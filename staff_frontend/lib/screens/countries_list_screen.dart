import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/directory.dart';
import '../services/api_client.dart';
import '../services/staff_service.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';

/// Manage the global country list used by the staff (new-hire) form's Country
/// field. Add/edit/delete are Admin / Super Admin only; every role that fills
/// in the staff form can pick from the resulting list.
class CountriesListScreen extends StatefulWidget {
  const CountriesListScreen({super.key});

  @override
  State<CountriesListScreen> createState() => _CountriesListScreenState();
}

class _CountriesListScreenState extends State<CountriesListScreen> {
  List<Country> _countries = [];
  bool _loading = true;
  String? _error;
  bool _canEdit = false;
  bool _selecting = false;
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    final role = context.read<AuthProvider>().user?.role;
    _canEdit = role == 'Super Admin' || role == 'Admin';
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await context.read<StaffService>().countries();
      if (!mounted) return;
      setState(() {
        _countries = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load countries.';
        _loading = false;
      });
    }
  }

  Future<void> _addCountry() async {
    final ctrl = TextEditingController();
    String? errorText;
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Future<void> submit() async {
            final name = ctrl.text.trim();
            if (name.isEmpty) {
              setLocal(() => errorText = 'Name is required');
              return;
            }
            try {
              await ctx.read<StaffService>().createCountry(name);
              if (ctx.mounted) Navigator.pop(ctx, true);
            } on ApiException catch (e) {
              setLocal(() => errorText = e.message);
            } catch (_) {
              setLocal(() => errorText = 'Could not add country.');
            }
          }

          return AlertDialog(
            title: const Text('Add country'),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Country name',
                errorText: errorText,
              ),
              onSubmitted: (_) => submit(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(onPressed: submit, child: const Text('Add')),
            ],
          );
        },
      ),
    );
    if (created == true) _load();
  }

  Future<void> _editCountry(Country country) async {
    final ctrl = TextEditingController(text: country.name);
    String? errorText;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Future<void> submit() async {
            final name = ctrl.text.trim();
            if (name.isEmpty) {
              setLocal(() => errorText = 'Name is required');
              return;
            }
            try {
              await ctx.read<StaffService>().updateCountry(country.id, name);
              if (ctx.mounted) Navigator.pop(ctx, true);
            } on ApiException catch (e) {
              setLocal(() => errorText = e.message);
            } catch (_) {
              setLocal(() => errorText = 'Could not save country.');
            }
          }

          return AlertDialog(
            title: const Text('Edit country'),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Country name',
                errorText: errorText,
              ),
              onSubmitted: (_) => submit(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(onPressed: submit, child: const Text('Save')),
            ],
          );
        },
      ),
    );
    if (saved == true) _load();
  }

  String _nameById(int id) {
    for (final c in _countries) {
      if (c.id == id) return c.name;
    }
    return 'Country $id';
  }

  void _exitSelect() => setState(() {
        _selecting = false;
        _selected.clear();
      });

  Future<void> _deleteSelected() async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${ids.length} country(ies)?'),
        content: const Text(
            'Countries referenced by an employee cannot be deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
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

    final svc = context.read<StaffService>();
    int ok = 0;
    final failures = <String>[];
    for (final id in ids) {
      try {
        await svc.deleteCountry(id);
        ok++;
      } on ApiException catch (e) {
        failures.add('${_nameById(id)}: ${e.message}');
      } catch (_) {
        failures.add('${_nameById(id)}: could not delete');
      }
    }
    _exitSelect();
    await _load();
    if (!mounted) return;
    if (failures.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted $ok country(ies)')),
      );
    } else {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Deleted $ok • ${failures.length} blocked'),
          content: SingleChildScrollView(
            child: Text(failures.join('\n\n')),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK')),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selecting) {
      return AppScaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _exitSelect,
          ),
          title: Text('${_selected.length} selected'),
          actions: [
            IconButton(
              tooltip: 'Delete selected',
              icon: const Icon(Icons.delete_outline),
              onPressed: _selected.isEmpty ? null : _deleteSelected,
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: _buildBody(),
      );
    }
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Countries'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
          if (_canEdit)
            IconButton(
              tooltip: 'Add country',
              icon: const Icon(Icons.add),
              onPressed: _addCountry,
            ),
          if (_canEdit && _countries.isNotEmpty)
            IconButton(
              tooltip: 'Select to delete',
              icon: const Icon(Icons.checklist),
              onPressed: () => setState(() => _selecting = true),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_countries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No countries yet.'),
            if (_canEdit) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _addCountry,
                icon: const Icon(Icons.add),
                label: const Text('Add country'),
              ),
            ],
          ],
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _countries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final c = _countries[i];
          final selected = _selected.contains(c.id);
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Material(
                color: selected
                    ? const Color(0x1F4CAF50)
                    : (isDark ? cs.surfaceContainerHigh : Colors.white),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: !_canEdit
                      ? null
                      : (_selecting
                          ? () => setState(() {
                                if (selected) {
                                  _selected.remove(c.id);
                                } else {
                                  _selected.add(c.id);
                                }
                              })
                          : () => _editCountry(c)),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isDark ? cs.outlineVariant : AppColors.line),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 16),
                    child: Row(
                      children: [
                        if (_selecting) ...[
                          Icon(
                            selected
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            color: selected ? cs.primary : cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                        ],
                        Icon(Icons.public_outlined, color: cs.primary),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            c.name,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                        ),
                        if (_canEdit && !_selecting)
                          Icon(Icons.edit,
                              size: 16, color: cs.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

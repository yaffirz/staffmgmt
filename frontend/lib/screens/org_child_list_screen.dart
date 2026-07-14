import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/directory.dart';
import '../services/api_client.dart';
import '../services/staff_service.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import 'bulk_upload_screen.dart';

enum OrgChildKind { store, position }

class _Child {
  final int id;
  final int brandId;
  final String label;
  const _Child(this.id, this.brandId, this.label);
}

/// Lists stores or positions (both are just a label tied to a brand).
class OrgChildListScreen extends StatefulWidget {
  final OrgChildKind kind;
  const OrgChildListScreen({super.key, required this.kind});

  @override
  State<OrgChildListScreen> createState() => _OrgChildListScreenState();
}

class _OrgChildListScreenState extends State<OrgChildListScreen> {
  List<Brand> _brands = [];
  List<_Child> _items = [];
  bool _loading = true;
  String? _error;
  int? _filterBrandId; // null = all
  bool _canEdit = false;

  bool get _isStore => widget.kind == OrgChildKind.store;
  String get _titlePlural => _isStore ? 'Stores' : 'Positions';
  String get _titleSingular => _isStore ? 'store' : 'position';
  String get _fieldLabel => _isStore ? 'Store name' : 'Position title';
  IconData get _icon =>
      _isStore ? Icons.store_outlined : Icons.badge_outlined;

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
      final svc = context.read<StaffService>();
      final brands = await svc.brands();
      final List<_Child> items;
      if (_isStore) {
        items = (await svc.stores())
            .map((s) => _Child(s.id, s.brandId, s.name))
            .toList();
      } else {
        items = (await svc.positions())
            .map((p) => _Child(p.id, p.brandId, p.title))
            .toList();
      }
      if (!mounted) return;
      setState(() {
        _brands = brands;
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load $_titlePlural.';
        _loading = false;
      });
    }
  }

  String _brandName(int id) {
    for (final b in _brands) {
      if (b.id == id) return b.name;
    }
    return 'Brand $id';
  }

  Future<void> _add() async {
    if (_brands.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a brand first.')),
      );
      return;
    }
    final ctrl = TextEditingController();
    int? brandId = _filterBrandId ?? _brands.first.id;
    String? errorText;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Future<void> submit() async {
            final name = ctrl.text.trim();
            if (brandId == null) {
              setLocal(() => errorText = 'Choose a brand');
              return;
            }
            if (name.isEmpty) {
              setLocal(() => errorText = '$_fieldLabel is required');
              return;
            }
            try {
              final svc = ctx.read<StaffService>();
              if (_isStore) {
                await svc.createStore(brandId!, name);
              } else {
                await svc.createPosition(brandId!, name);
              }
              if (ctx.mounted) Navigator.pop(ctx, true);
            } on ApiException catch (e) {
              setLocal(() => errorText = e.message);
            } catch (_) {
              setLocal(() => errorText = 'Could not add $_titleSingular.');
            }
          }

          return AlertDialog(
            title: Text('Add $_titleSingular'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: brandId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Brand'),
                  items: _brands
                      .map((b) =>
                          DropdownMenuItem(value: b.id, child: Text(b.name)))
                      .toList(),
                  onChanged: (v) => setLocal(() => brandId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: _fieldLabel,
                    errorText: errorText,
                  ),
                  onSubmitted: (_) => submit(),
                ),
              ],
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

  Future<void> _edit(_Child item) async {
    final ctrl = TextEditingController(text: item.label);
    int? brandId = item.brandId;
    String? errorText;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Future<void> submit() async {
            final name = ctrl.text.trim();
            if (brandId == null) {
              setLocal(() => errorText = 'Choose a brand');
              return;
            }
            if (name.isEmpty) {
              setLocal(() => errorText = '$_fieldLabel is required');
              return;
            }
            try {
              final svc = ctx.read<StaffService>();
              if (_isStore) {
                await svc.updateStore(item.id, brandId!, name);
              } else {
                await svc.updatePosition(item.id, brandId!, name);
              }
              if (ctx.mounted) Navigator.pop(ctx, true);
            } on ApiException catch (e) {
              setLocal(() => errorText = e.message);
            } catch (_) {
              setLocal(() => errorText = 'Could not save $_titleSingular.');
            }
          }

          return AlertDialog(
            title: Text('Edit $_titleSingular'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: brandId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Brand'),
                  items: _brands
                      .map((b) =>
                          DropdownMenuItem(value: b.id, child: Text(b.name)))
                      .toList(),
                  onChanged: (v) => setLocal(() => brandId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: _fieldLabel,
                    errorText: errorText,
                  ),
                  onSubmitted: (_) => submit(),
                ),
              ],
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: Text(_titlePlural),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
          IconButton(
            tooltip: 'Add $_titleSingular',
            icon: const Icon(Icons.add),
            onPressed: _add,
          ),
          if (_canEdit)
            IconButton(
              tooltip: 'Bulk add $_titlePlural',
              icon: const Icon(Icons.upload_file),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BulkUploadScreen(
                      kind: _isStore
                          ? BulkKind.stores
                          : BulkKind.positions,
                    ),
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

    final filtered = _filterBrandId == null
        ? _items
        : _items.where((c) => c.brandId == _filterBrandId).toList();

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Brand filter
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: DropdownButtonFormField<int?>(
                initialValue: _filterBrandId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Filter by brand',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<int?>(
                      value: null, child: Text('All brands')),
                  ..._brands.map((b) =>
                      DropdownMenuItem<int?>(value: b.id, child: Text(b.name))),
                ],
                onChanged: (v) => setState(() => _filterBrandId = v),
              ),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('No $_titlePlural yet.'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _add,
                        icon: const Icon(Icons.add),
                        label: Text('Add $_titleSingular'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final c = filtered[i];
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: Material(
                            color: isDark
                                ? cs.surfaceContainerHigh
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _canEdit ? () => _edit(c) : null,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: isDark
                                          ? cs.outlineVariant
                                          : AppColors.line),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 14),
                                child: Row(
                                  children: [
                                    Icon(_icon, color: cs.primary),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        c.label,
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    Text(
                                      _brandName(c.brandId),
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          color: cs.onSurfaceVariant),
                                    ),
                                    if (_canEdit) ...[
                                      const SizedBox(width: 12),
                                      Icon(Icons.edit,
                                          size: 16,
                                          color: cs.onSurfaceVariant),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

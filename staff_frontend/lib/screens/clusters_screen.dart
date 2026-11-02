import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cluster_admin.dart';
import '../services/staff_service.dart';
import '../widgets/app_scaffold.dart';

/// Cluster administration (Admin / IT / HR): assign each Area Manager the
/// specific stores in their cluster, and each Ops Manager the brands they own.
///
///   Ops Manager (brands) > Area Manager (stores) > store managers > staff
class ClustersScreen extends StatefulWidget {
  const ClustersScreen({super.key});

  @override
  State<ClustersScreen> createState() => _ClustersScreenState();
}

class _ClustersScreenState extends State<ClustersScreen> {
  ClustersOverview? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = context.read<StaffService>();
      final data = await svc.clustersOverview();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: AppScaffold(
        appBar: AppBar(
          title: const Text('Clusters'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Area Managers'),
              Tab(text: 'Ops Managers'),
            ],
          ),
        ),
        body: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load clusters.\n$_error',
              textAlign: TextAlign.center),
        ),
      );
    }
    final d = _data!;
    return TabBarView(
      children: [
        _AreaManagerList(data: d, onChanged: _applyAm),
        _OpsManagerList(data: d, onChanged: _applyOps),
      ],
    );
  }

  void _applyAm(AreaManagerRow row) {
    final d = _data!;
    setState(() {
      _data = ClustersOverview(
        brands: d.brands,
        stores: d.stores,
        areaManagers: [
          for (final r in d.areaManagers)
            if (r.userId == row.userId) row else r
        ],
        opsManagers: d.opsManagers,
      );
    });
  }

  void _applyOps(OpsManagerRow row) {
    final d = _data!;
    setState(() {
      _data = ClustersOverview(
        brands: d.brands,
        stores: d.stores,
        areaManagers: d.areaManagers,
        opsManagers: [
          for (final r in d.opsManagers)
            if (r.userId == row.userId) row else r
        ],
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Area Managers tab
// ---------------------------------------------------------------------------
class _AreaManagerList extends StatelessWidget {
  final ClustersOverview data;
  final ValueChanged<AreaManagerRow> onChanged;
  const _AreaManagerList({required this.data, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (data.areaManagers.isEmpty) {
      return const _Empty(
        icon: Icons.person_search_outlined,
        text: 'No Area Managers yet.\nCreate one in Users & Roles first.',
      );
    }
    final storeName = {for (final s in data.stores) s.storeId: s.storeName};
    final storeBrand = {for (final s in data.stores) s.storeId: s.brandName};
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final am in data.areaManagers)
          _ManagerCard(
            title: am.username,
            summary: _amSummary(am, storeBrand),
            detail: am.storeIds.isEmpty
                ? 'No stores assigned'
                : am.storeIds
                    .map((id) => storeName[id] ?? '#$id')
                    .toList()
                    .join(', '),
            onEdit: () => _editStores(context, am),
          ),
      ],
    );
  }

  String _amSummary(AreaManagerRow am, Map<int, String> storeBrand) {
    final n = am.storeIds.length;
    if (n == 0) return 'No cluster set';
    final brands = <String>{
      for (final id in am.storeIds)
        if ((storeBrand[id] ?? '').isNotEmpty) storeBrand[id]!
    };
    final brandPart = brands.isEmpty ? '' : ' · ${brands.join(', ')}';
    return '$n store${n == 1 ? '' : 's'}$brandPart';
  }

  Future<void> _editStores(BuildContext context, AreaManagerRow am) async {
    final result = await showDialog<List<int>>(
      context: context,
      builder: (_) => _StorePickerDialog(
        title: '${am.username} · cluster',
        stores: data.stores,
        selected: am.storeIds.toSet(),
      ),
    );
    if (result == null) return;
    final svc = context.read<StaffService>();
    try {
      final row = await svc.setAreaManagerStores(am.userId, result);
      onChanged(row);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${am.username}: cluster updated.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Ops Managers tab
// ---------------------------------------------------------------------------
class _OpsManagerList extends StatelessWidget {
  final ClustersOverview data;
  final ValueChanged<OpsManagerRow> onChanged;
  const _OpsManagerList({required this.data, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (data.opsManagers.isEmpty) {
      return const _Empty(
        icon: Icons.supervisor_account_outlined,
        text: 'No Ops Managers yet.\nCreate one in Users & Roles first.',
      );
    }
    final brandName = {for (final b in data.brands) b.brandId: b.brandName};
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final ops in data.opsManagers)
          _ManagerCard(
            title: ops.username,
            summary: ops.brandIds.isEmpty
                ? 'No brands set'
                : '${ops.brandIds.length} brand'
                    '${ops.brandIds.length == 1 ? '' : 's'}',
            detail: ops.brandIds.isEmpty
                ? 'No brands assigned'
                : ops.brandIds
                    .map((id) => brandName[id] ?? '#$id')
                    .toList()
                    .join(', '),
            onEdit: () => _editBrands(context, ops),
          ),
      ],
    );
  }

  Future<void> _editBrands(BuildContext context, OpsManagerRow ops) async {
    final result = await showDialog<List<int>>(
      context: context,
      builder: (_) => _BrandPickerDialog(
        title: '${ops.username} · brands',
        brands: data.brands,
        selected: ops.brandIds.toSet(),
      ),
    );
    if (result == null) return;
    final svc = context.read<StaffService>();
    try {
      final row = await svc.setOpsManagerBrands(ops.userId, result);
      onChanged(row);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ops.username}: brands updated.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------
class _ManagerCard extends StatelessWidget {
  final String title;
  final String summary;
  final String detail;
  final VoidCallback onEdit;
  const _ManagerCard({
    required this.title,
    required this.summary,
    required this.detail,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(summary,
                      style: TextStyle(
                          color: cs.primary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(detail,
                      style: TextStyle(
                          fontSize: 12.5, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Empty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// Store picker grouped by brand, with a live search and per-brand select-all.
class _StorePickerDialog extends StatefulWidget {
  final String title;
  final List<ClusterStoreLite> stores;
  final Set<int> selected;
  const _StorePickerDialog({
    required this.title,
    required this.stores,
    required this.selected,
  });

  @override
  State<_StorePickerDialog> createState() => _StorePickerDialogState();
}

class _StorePickerDialogState extends State<_StorePickerDialog> {
  late Set<int> _sel;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _sel = {...widget.selected};
  }

  @override
  Widget build(BuildContext context) {
    // Group stores by brand name.
    final q = _query.trim().toLowerCase();
    final byBrand = <String, List<ClusterStoreLite>>{};
    for (final s in widget.stores) {
      if (q.isNotEmpty && !s.storeName.toLowerCase().contains(q)) continue;
      byBrand.putIfAbsent(s.brandName.isEmpty ? '—' : s.brandName, () => []).add(s);
    }
    final brandNames = byBrand.keys.toList()..sort();

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 460,
        height: 460,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Filter stores…',
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('${_sel.length} selected',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            const Divider(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final bn in brandNames) ...[
                    _brandHeader(bn, byBrand[bn]!),
                    for (final s in byBrand[bn]!)
                      CheckboxListTile(
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _sel.contains(s.storeId),
                        title: Text(s.storeName),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _sel.add(s.storeId);
                          } else {
                            _sel.remove(s.storeId);
                          }
                        }),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _sel.toList()),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _brandHeader(String brand, List<ClusterStoreLite> stores) {
    final ids = stores.map((s) => s.storeId).toSet();
    final allOn = ids.every(_sel.contains);
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(brand,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          TextButton(
            onPressed: () => setState(() {
              if (allOn) {
                _sel.removeAll(ids);
              } else {
                _sel.addAll(ids);
              }
            }),
            child: Text(allOn ? 'Clear' : 'All'),
          ),
        ],
      ),
    );
  }
}

/// Brand picker (checkboxes) for Ops Managers.
class _BrandPickerDialog extends StatefulWidget {
  final String title;
  final List<ClusterBrandLite> brands;
  final Set<int> selected;
  const _BrandPickerDialog({
    required this.title,
    required this.brands,
    required this.selected,
  });

  @override
  State<_BrandPickerDialog> createState() => _BrandPickerDialogState();
}

class _BrandPickerDialogState extends State<_BrandPickerDialog> {
  late Set<int> _sel;

  @override
  void initState() {
    super.initState();
    _sel = {...widget.selected};
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        height: 420,
        child: ListView(
          children: [
            for (final b in widget.brands)
              CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: _sel.contains(b.brandId),
                title: Text(b.brandName),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _sel.add(b.brandId);
                  } else {
                    _sel.remove(b.brandId);
                  }
                }),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _sel.toList()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

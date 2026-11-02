import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/platform.dart';
import '../services/api_client.dart';
import '../services/staff_service.dart';
import '../widgets/app_scaffold.dart';

/// Area Manager dashboard: a brand's stores -> staff -> positions, plus the
/// external-platform tags each staffer has access to (Taqtics, Oracle, …).
class AreaDashboardScreen extends StatefulWidget {
  const AreaDashboardScreen({super.key});

  @override
  State<AreaDashboardScreen> createState() => _AreaDashboardScreenState();
}

class _AreaDashboardScreenState extends State<AreaDashboardScreen> {
  AreaDashboard? _dash;
  int? _brandId;
  int? _areaManagerId; // admin: viewing AS this Area Manager
  bool _loading = true;
  String? _error;
  String _query = '';

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
      final dash = await context
          .read<StaffService>()
          .areaDashboard(brandId: _brandId, areaManagerId: _areaManagerId);
      if (!mounted) return;
      setState(() {
        _dash = dash;
        _brandId = dash.brandId;
        _areaManagerId = dash.areaManagerId;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load the dashboard.';
        _loading = false;
      });
    }
  }

  static Color? _hex(String? s) {
    if (s == null) return null;
    var h = s.replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(v);
  }

  Future<void> _manageCatalog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _PlatformCatalogDialog(),
    );
    if (mounted) _load(); // reflect catalog changes
  }

  Future<void> _moveUnemployed(DashStaff staff) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to unemployed?'),
        content: Text(
            '${staff.employeeName} will be moved to the unemployed group and '
            'removed from active rosters. This can be reversed from Status '
            'Changes (reactivate).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Move to unemployed'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await context.read<StaffService>().moveEmployeeUnemployed(staff.employeeId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${staff.employeeName} moved to unemployed.')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _editPlatforms(DashStaff staff) async {
    final dash = _dash;
    if (dash == null) return;
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _AssignPlatformsDialog(
        staff: staff,
        catalog: dash.platformCatalog,
      ),
    );
    if (changed == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Area Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Manage platforms',
            icon: const Icon(Icons.apps_outlined),
            onPressed: _loading ? null : _manageCatalog,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorBody()
              : _body(),
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

  Widget _body() {
    final dash = _dash!;
    final cs = Theme.of(context).colorScheme;
    // When there are no brands AND no admin AM picker to switch with, show the
    // bare message (an AM/Ops Manager with nothing assigned).
    if (dash.brands.isEmpty && dash.areaManagers.isEmpty) {
      return const Center(child: Text('No brands are assigned to your area.'));
    }
    return Column(
      children: [
        _controls(cs, dash),
        const Divider(height: 1),
        Expanded(child: _content(cs, dash)),
      ],
    );
  }

  Widget _content(ColorScheme cs, AreaDashboard dash) {
    if (dash.brands.isEmpty) {
      // Admin viewing an AM (or "All") with nothing to show — keep the controls
      // above so they can switch back.
      final msg = dash.areaManagerId != null
          ? 'This area manager has no stores assigned yet.'
          : 'No brands to show.';
      return Center(
          child: Text(msg, style: TextStyle(color: cs.onSurfaceVariant)));
    }
    if (dash.stores.isEmpty) {
      return Center(
          child: Text('No stores in ${dash.brandName ?? 'this brand'}.',
              style: TextStyle(color: cs.onSurfaceVariant)));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [for (final s in dash.stores) _storeSection(cs, s)],
    );
  }

  Widget _controls(ColorScheme cs, AreaDashboard dash) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<int>(
              initialValue: dash.brandId,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Brand',
                border: OutlineInputBorder(),
              ),
              items: dash.brands
                  .map((b) => DropdownMenuItem(
                        value: b.brandId,
                        child:
                            Text(b.brandName, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: (v) {
                setState(() => _brandId = v);
                _load();
              },
            ),
          ),
          // Admin-only: view the dashboard as a specific Area Manager (scoped to
          // their cluster). Empty list for AM/Ops Managers, so it hides itself.
          if (dash.areaManagers.isNotEmpty)
            SizedBox(
              width: 240,
              child: DropdownButtonFormField<int?>(
                initialValue: _areaManagerId,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'View as area manager',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All area managers'),
                  ),
                  for (final am in dash.areaManagers)
                    DropdownMenuItem<int?>(
                      value: am.userId,
                      child: Text(am.username, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) {
                  setState(() {
                    _areaManagerId = v;
                    _brandId = null; // let the AM's own brand default
                  });
                  _load();
                },
              ),
            ),
          _stat(cs, Icons.store_mall_directory_outlined, '${dash.stores.length}',
              'stores'),
          _stat(cs, Icons.groups_outlined, '${dash.totalStaff}', 'staff'),
          _stat(cs, Icons.apps_outlined, '${dash.platformCatalog.length}',
              'platforms'),
          SizedBox(
            width: 220,
            child: TextField(
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                hintText: 'Filter staff…',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(ColorScheme cs, IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Text(value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _storeSection(ColorScheme cs, DashStore store) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final staff = _query.isEmpty
        ? store.staff
        : store.staff
            .where((s) =>
                '${s.employeeName} ${s.payrollId} ${s.positionTitle ?? ''}'
                    .toLowerCase()
                    .contains(_query))
            .toList();
    if (_query.isNotEmpty && staff.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(Icons.storefront_outlined, size: 20, color: cs.primary),
                const SizedBox(width: 10),
                Text(store.storeName,
                    style: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('${staff.length} staff',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          if (staff.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text('No active staff.',
                  style: TextStyle(color: cs.onSurfaceVariant)),
            )
          else
            for (var i = 0; i < staff.length; i++) ...[
              if (i > 0) Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),
              _staffRow(cs, staff[i]),
            ],
        ],
      ),
    );
  }

  Widget _staffRow(ColorScheme cs, DashStaff s) {
    return InkWell(
      onTap: () => _editPlatforms(s),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(s.employeeName,
                            style: const TextStyle(
                                fontSize: 14.5, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      Text(s.positionTitle ?? '—',
                          style:
                              TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
                    ],
                  ),
                  if (s.platforms.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [for (final p in s.platforms) _platformChip(cs, p)],
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit platform access',
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () => _editPlatforms(s),
            ),
            if (_dash?.canUnemploy ?? false)
              PopupMenuButton<String>(
                tooltip: 'More actions',
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (v) {
                  if (v == 'unemployed') _moveUnemployed(s);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'unemployed',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.person_off_outlined),
                      title: Text('Move to unemployed'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _platformChip(ColorScheme cs, EmpPlatform p) {
    final color = _hex(p.color) ?? cs.primary;
    return Tooltip(
      message: p.note == null || p.note!.isEmpty ? p.name : '${p.name} · ${p.note}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(p.name,
                style: TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

/// Assign/unassign platforms to one employee (+ optional note each).
class _AssignPlatformsDialog extends StatefulWidget {
  final DashStaff staff;
  final List<Platform> catalog;
  const _AssignPlatformsDialog({required this.staff, required this.catalog});

  @override
  State<_AssignPlatformsDialog> createState() => _AssignPlatformsDialogState();
}

class _AssignPlatformsDialogState extends State<_AssignPlatformsDialog> {
  late Map<int, bool> _checked;
  late Map<int, TextEditingController> _notes;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final current = {for (final p in widget.staff.platforms) p.platformId: p};
    _checked = {for (final p in widget.catalog) p.platformId: current.containsKey(p.platformId)};
    _notes = {
      for (final p in widget.catalog)
        p.platformId: TextEditingController(text: current[p.platformId]?.note ?? '')
    };
  }

  @override
  void dispose() {
    for (final c in _notes.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final items = <Map<String, dynamic>>[];
    for (final p in widget.catalog) {
      if (_checked[p.platformId] == true) {
        final note = _notes[p.platformId]!.text.trim();
        items.add({'platform_id': p.platformId, if (note.isNotEmpty) 'note': note});
      }
    }
    try {
      await context
          .read<StaffService>()
          .setEmployeePlatforms(widget.staff.employeeId, items);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save platform access.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Platform access — ${widget.staff.employeeName}'),
      content: SizedBox(
        width: 420,
        child: widget.catalog.isEmpty
            ? const Text(
                'No platforms defined yet. Use "Manage platforms" first.')
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final p in widget.catalog)
                      Column(
                        children: [
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: _checked[p.platformId] ?? false,
                            onChanged: (v) => setState(
                                () => _checked[p.platformId] = v ?? false),
                            title: Text(p.name),
                          ),
                          if (_checked[p.platformId] == true)
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 32, bottom: 6, right: 4),
                              child: TextField(
                                controller: _notes[p.platformId],
                                style: const TextStyle(fontSize: 13),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  hintText: 'Note (username / access level)…',
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: (_busy || widget.catalog.isEmpty) ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}

/// Add / remove platforms in the catalog.
class _PlatformCatalogDialog extends StatefulWidget {
  const _PlatformCatalogDialog();

  @override
  State<_PlatformCatalogDialog> createState() => _PlatformCatalogDialogState();
}

class _PlatformCatalogDialogState extends State<_PlatformCatalogDialog> {
  List<Platform> _list = [];
  bool _loading = true;
  bool _busy = false;
  final _nameCtrl = TextEditingController();
  Color _color = const Color(0xFF1565C0);

  static const _palette = [
    Color(0xFF1565C0), Color(0xFF7B1FA2), Color(0xFF2E7D43),
    Color(0xFFB26A00), Color(0xFFB3261E), Color(0xFF00838F),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final l = await context.read<StaffService>().platforms();
      if (!mounted) return;
      setState(() {
        _list = l;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    try {
      final hex = '#${_color.toARGB32().toRadixString(16).substring(2)}';
      await context.read<StaffService>().createPlatform(name, color: hex);
      _nameCtrl.clear();
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(Platform p) async {
    setState(() => _busy = true);
    try {
      await context.read<StaffService>().deletePlatform(p.platformId);
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('External platforms'),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const SizedBox(
                height: 100, child: Center(child: CircularProgressIndicator()))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_list.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No platforms yet. Add one below.'),
                    )
                  else
                    ..._list.map((p) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: _AreaDashboardScreenState._hex(p.color) ??
                                  Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          title: Text(p.name),
                          trailing: IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: _busy ? null : () => _remove(p),
                          ),
                        )),
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            isDense: true,
                            labelText: 'New platform',
                            hintText: 'e.g. Taqtics',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      for (final c in _palette)
                        GestureDetector(
                          onTap: () => setState(() => _color = c),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _color == c
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      IconButton(
                        tooltip: 'Add',
                        icon: const Icon(Icons.add_circle),
                        onPressed: _busy ? null : _add,
                      ),
                    ],
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close')),
      ],
    );
  }
}

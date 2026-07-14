import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cluster.dart';
import '../models/staff_search_result.dart';
import '../services/api_client.dart';
import '../services/staff_service.dart';
import '../widgets/app_scaffold.dart';
import 'employee_detail_screen.dart';

/// Area Manager "My Cluster": stores in the AM's brands, each with its staff,
/// plus Move (change a staffer's primary store) and Request (pull someone in).
class MyClusterScreen extends StatefulWidget {
  const MyClusterScreen({super.key});

  @override
  State<MyClusterScreen> createState() => _MyClusterScreenState();
}

class _MyClusterScreenState extends State<MyClusterScreen> {
  bool _loading = true;
  String? _error;
  List<ClusterStore> _stores = [];

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
      final stores = await context.read<StaffService>().cluster();
      if (!mounted) return;
      setState(() {
        _stores = stores;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your cluster. Check the server connection.';
        _loading = false;
      });
    }
  }

  Future<void> _openMove(ClusterStore store) async {
    if (store.movable.isEmpty) {
      _snack('No staff based at ${store.storeName} to move. '
          '(Only staff whose primary store is here can be moved.)');
      return;
    }
    final others = _stores.where((s) => s.storeId != store.storeId).toList();
    if (others.isEmpty) {
      _snack('There is no other store in your cluster to move staff to.');
      return;
    }
    final moved = await showDialog<bool>(
      context: context,
      builder: (_) => _MoveDialog(store: store, destinations: others),
    );
    if (moved == true) {
      _snack('Staff moved.');
      _load();
    }
  }

  Future<void> _openRequest(ClusterStore store) async {
    final requested = await showDialog<bool>(
      context: context,
      builder: (_) => _RequestDialog(store: store),
    );
    if (requested == true) {
      _snack('Request submitted to the admins.');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('My Cluster'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
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
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_stores.isEmpty) {
      final cs = Theme.of(context).colorScheme;
      return Center(
        child: Text('No stores are assigned to your cluster yet.',
            style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final s in _stores) _storeCard(s)],
          ),
        ),
      ),
    );
  }

  Widget _storeCard(ClusterStore store) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(store.storeName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      Text('${store.brandName}  ·  ${store.staff.length} staff',
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Move staff',
                  icon: const Icon(Icons.swap_horiz),
                  onPressed: () => _openMove(store),
                ),
                IconButton(
                  tooltip: 'Request staff',
                  icon: const Icon(Icons.person_add_alt_1),
                  onPressed: () => _openRequest(store),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (store.staff.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No staff at this store.',
                  style: TextStyle(color: cs.onSurfaceVariant)),
            )
          else
            for (final m in store.staff) _staffRow(m, cs),
        ],
      ),
    );
  }

  Widget _staffRow(ClusterStaffMember m, ColorScheme cs) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EmployeeDetailScreen(
            employeeId: m.employeeId,
            employeeName: m.employeeName,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: m.employeeName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(
                    text: '   ${m.positionTitle ?? 'Staff'}',
                    style: TextStyle(
                        fontSize: 13, color: cs.onSurfaceVariant)),
              ]),
            ),
          ),
          if (m.alsoCovers)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Also covers',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cs.onSecondaryContainer)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Move a staffer's primary store to another store in the cluster.
class _MoveDialog extends StatefulWidget {
  final ClusterStore store;
  final List<ClusterStore> destinations;
  const _MoveDialog({required this.store, required this.destinations});

  @override
  State<_MoveDialog> createState() => _MoveDialogState();
}

class _MoveDialogState extends State<_MoveDialog> {
  int? _employeeId;
  int? _toStoreId;
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    if (_employeeId == null || _toStoreId == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<StaffService>().moveStaff(_employeeId!, _toStoreId!);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _submitting = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not move staff. Please try again.';
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final movable = widget.store.movable;
    return AlertDialog(
      title: Text('Move staff from ${widget.store.storeName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<int>(
            initialValue: _employeeId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Staff member'),
            items: [
              for (final m in movable)
                DropdownMenuItem(
                  value: m.employeeId,
                  child: Text('${m.employeeName} · ${m.positionTitle ?? 'Staff'}',
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _submitting
                ? null
                : (v) => setState(() => _employeeId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _toStoreId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Move to store'),
            items: [
              for (final s in widget.destinations)
                DropdownMenuItem(
                  value: s.storeId,
                  child: Text('${s.storeName} · ${s.brandName}',
                      overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged:
                _submitting ? null : (v) => setState(() => _toStoreId = v),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (_submitting || _employeeId == null || _toStoreId == null)
              ? null
              : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2))
              : const Text('Move'),
        ),
      ],
    );
  }
}

/// Search all staff by name and request one into this store.
class _RequestDialog extends StatefulWidget {
  final ClusterStore store;
  const _RequestDialog({required this.store});

  @override
  State<_RequestDialog> createState() => _RequestDialogState();
}

class _RequestDialogState extends State<_RequestDialog> {
  final _nameCtrl = TextEditingController();
  bool _searching = false;
  bool _searched = false;
  String? _error;
  List<StaffSearchResult> _results = [];
  int? _submittingId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _nameCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final res = await context.read<StaffService>().searchStaff(q);
      if (!mounted) return;
      setState(() {
        _results = res;
        _searched = true;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Search failed. Please try again.';
        _searching = false;
      });
    }
  }

  Future<void> _request(StaffSearchResult r) async {
    setState(() => _submittingId = r.employeeId);
    try {
      await context
          .read<StaffService>()
          .requestStaff(r.employeeId, widget.store.storeId);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not submit the request. Please try again.';
          _submittingId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text('Request staff for ${widget.store.storeName}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      hintText: 'Search staff by name',
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _searching ? null : _search,
                  child: _searching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2))
                      : const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: TextStyle(color: cs.error)),
              ),
            if (_searched && _results.isEmpty && !_searching)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('No staff found by that name.',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ),
            if (_results.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final r in _results) _resultTile(r, cs),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _resultTile(StaffSearchResult r, ColorScheme cs) {
    final busy = _submittingId == r.employeeId;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(r.employeeName),
      subtitle: Text('${r.brandsDisplay}  ·  ${r.storesDisplay}',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      trailing: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2))
          : OutlinedButton(
              onPressed: _submittingId != null ? null : () => _request(r),
              child: const Text('Request'),
            ),
    );
  }
}

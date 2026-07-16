import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/cluster.dart';
import '../services/api_client.dart';
import '../services/staff_service.dart';
import '../widgets/app_scaffold.dart';

/// Area Manager "Cross-store Assignments": add an existing cluster staffer to
/// another store in the cluster (their primary store is unchanged; stores
/// accumulate). Notifies IT.
class CrossStoreScreen extends StatefulWidget {
  const CrossStoreScreen({super.key});

  @override
  State<CrossStoreScreen> createState() => _CrossStoreScreenState();
}

class _Staffer {
  final int id;
  final String name;
  final String? position;
  final Set<int> storeIds = {};
  _Staffer(this.id, this.name, this.position);
}

class _CrossStoreScreenState extends State<CrossStoreScreen> {
  bool _loading = true;
  String? _error;
  List<ClusterStore> _stores = [];
  Map<int, _Staffer> _staffers = {};
  int? _staffId;
  int? _storeId;
  bool _submitting = false;

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
      final staffers = <int, _Staffer>{};
      for (final s in stores) {
        for (final m in s.staff) {
          staffers
              .putIfAbsent(
                  m.employeeId, () => _Staffer(m.employeeId, m.employeeName, m.positionTitle))
              .storeIds
              .add(s.storeId);
        }
      }
      if (!mounted) return;
      setState(() {
        _stores = stores;
        _staffers = staffers;
        // Keep the selected staff if still present; always reset the target.
        if (_staffId != null && !staffers.containsKey(_staffId)) _staffId = null;
        _storeId = null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your cluster.';
        _loading = false;
      });
    }
  }

  String _storeName(int id) =>
      _stores.firstWhere((s) => s.storeId == id,
          orElse: () => const ClusterStore(
              storeId: 0,
              storeName: 'Store',
              brandId: 0,
              brandName: '',
              staff: [])).storeName;

  List<ClusterStore> _assignableStores() {
    final staffer = _staffId == null ? null : _staffers[_staffId];
    if (staffer == null) return const [];
    return _stores
        .where((s) => !staffer.storeIds.contains(s.storeId))
        .toList();
  }

  Future<void> _assign() async {
    if (_staffId == null || _storeId == null) return;
    setState(() => _submitting = true);
    try {
      await context.read<StaffService>().assignStore(_staffId!, _storeId!);
      if (!mounted) return;
      final storeName = _storeName(_storeId!);
      final name = _staffers[_staffId]?.name ?? 'Staff';
      _snack('$name assigned to $storeName.');
      await _load(); // refresh their store set
      if (mounted) setState(() => _submitting = false);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _snack(e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        _snack('Could not assign. Please try again.');
      }
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
        title: const Text('Cross-store Assignments'),
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
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_staffers.isEmpty) {
      return Center(
        child: Text('No staff in your cluster yet.',
            style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }

    final staffers = _staffers.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final staffer = _staffId == null ? null : _staffers[_staffId];
    final assignable = _assignableStores();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? cs.surfaceContainerHigh : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Assign a staff member to another store in your cluster. '
                  'Their primary store stays the same.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _staffId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Staff member'),
                  items: [
                    for (final s in staffers)
                      DropdownMenuItem(
                        value: s.id,
                        child: Text(
                          '${s.name}${s.position != null ? ' · ${s.position}' : ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() {
                            _staffId = v;
                            _storeId = null;
                          }),
                ),
                if (staffer != null) ...[
                  const SizedBox(height: 12),
                  Text('Currently at: '
                      '${staffer.storeIds.map(_storeName).join(', ')}',
                      style:
                          TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  if (assignable.isEmpty)
                    Text('Already assigned to every store in your cluster.',
                        style: TextStyle(color: cs.onSurfaceVariant))
                  else
                    DropdownButtonFormField<int>(
                      initialValue: _storeId,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'Assign to store'),
                      items: [
                        for (final s in assignable)
                          DropdownMenuItem(
                            value: s.storeId,
                            child: Text('${s.storeName} · ${s.brandName}',
                                overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _storeId = v),
                    ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed:
                          (_submitting || _staffId == null || _storeId == null)
                              ? null
                              : _assign,
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.2))
                          : const Text('Assign'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

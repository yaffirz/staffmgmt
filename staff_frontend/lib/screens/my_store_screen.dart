import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/store_summary.dart';
import '../services/staff_service.dart';
import '../widgets/app_scaffold.dart';

/// The Store/Foodmall portal: the account's own store, staff grouped by brand
/// (name only), plus a "Request staff" action. Used for both roles — a foodmall
/// simply shows more than one brand group.
class MyStoreScreen extends StatefulWidget {
  const MyStoreScreen({super.key});

  @override
  State<MyStoreScreen> createState() => _MyStoreScreenState();
}

class _MyStoreScreenState extends State<MyStoreScreen> {
  bool _loading = true;
  String? _error;
  StoreSummary? _summary;

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
      final s = await context.read<StaffService>().storeSummary();
      if (!mounted) return;
      setState(() {
        _summary = s;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your store.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    final title = s == null ? 'My Store' : (s.isFoodmall ? 'My Foodmall' : 'My Store');
    return AppScaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (s != null)
            TextButton.icon(
              onPressed: _openRequest,
              icon: const Icon(Icons.person_add_alt_1,
                  size: 18, color: Colors.white),
              label: const Text('Request staff',
                  style: TextStyle(color: Colors.white)),
            ),
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
    final s = _summary!;
    final cs = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(s.storeName,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  '${s.totalStaff} staff'
                  '${s.isFoodmall ? ' · foodmall (${s.groups.length} brands)' : ''}',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                if (s.totalStaff == 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text('No staff at this store yet.',
                          style: TextStyle(color: cs.onSurfaceVariant)),
                    ),
                  )
                else
                  for (final g in s.groups) _brandGroup(g, cs),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _brandGroup(StoreBrandGroup g, ColorScheme cs) {
    // Hide empty groups on a foodmall so only active brands show.
    if (g.staff.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Row(
            children: [
              Icon(Icons.storefront_outlined, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(g.brandName,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: cs.onSurface)),
              const SizedBox(width: 8),
              Text('${g.staff.length}',
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? cs.surfaceContainerHigh : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            children: [
              for (var i = 0; i < g.staff.length; i++) ...[
                if (i > 0) Divider(height: 1, color: cs.outlineVariant),
                ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: cs.primary.withValues(alpha: 0.12),
                    child: Text(
                      g.staff[i].name.isNotEmpty
                          ? g.staff[i].name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          color: cs.primary, fontWeight: FontWeight.w700),
                    ),
                  ),
                  title: Text(g.staff[i].name),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _openRequest() async {
    final requested = await showDialog<bool>(
      context: context,
      builder: (_) => const _RequestStaffDialog(),
    );
    if (requested == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Request sent — an admin will review it.')),
      );
    }
  }
}

/// Name search → tap a result to request that staffer into this store.
class _RequestStaffDialog extends StatefulWidget {
  const _RequestStaffDialog();

  @override
  State<_RequestStaffDialog> createState() => _RequestStaffDialogState();
}

class _RequestStaffDialogState extends State<_RequestStaffDialog> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  bool _searching = false;
  int? _submittingId;
  List<StoreStaffLite> _results = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(v));
  }

  Future<void> _search(String v) async {
    final q = v.trim();
    if (q.isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final r = await context.read<StaffService>().storeSearchStaff(q);
      if (!mounted) return;
      setState(() {
        _results = r;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  Future<void> _request(StoreStaffLite s) async {
    setState(() => _submittingId = s.employeeId);
    try {
      await context.read<StaffService>().storeRequestStaff(s.employeeId);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submittingId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send the request.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Request staff'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Search by name',
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : const Icon(Icons.search),
              ),
              onChanged: _onChanged,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 260,
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        _ctrl.text.trim().isEmpty
                            ? 'Type a name to search.'
                            : 'No matches.',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final s = _results[i];
                        final busy = _submittingId == s.employeeId;
                        return ListTile(
                          dense: true,
                          title: Text(s.name),
                          trailing: busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : const Icon(Icons.add_circle_outline),
                          onTap: _submittingId == null
                              ? () => _request(s)
                              : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

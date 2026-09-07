import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/employee.dart';
import '../models/status_log.dart';
import '../services/staff_service.dart';
import '../state/auth_provider.dart';
import '../widgets/app_scaffold.dart';
import 'employee_detail_screen.dart';

/// "Status Changes" feed: recent promote/demote/terminate/transfer events across
/// all staff, newest first. Each row links to that staffer's page.
class StatusFeedScreen extends StatefulWidget {
  const StatusFeedScreen({super.key});

  @override
  State<StatusFeedScreen> createState() => _StatusFeedScreenState();
}

class _StatusFeedScreenState extends State<StatusFeedScreen> {
  bool _loading = true;
  String? _error;
  List<StatusLogEntry> _entries = [];
  bool _canChange = false;
  List<Employee>? _staffCache; // lazily loaded for the search picker

  @override
  void initState() {
    super.initState();
    final me = context.read<AuthProvider>().user;
    _canChange = me != null &&
        (me.hasRole('Super Admin') ||
            me.hasRole('Admin') ||
            me.hasRole('HR'));
    _load();
  }

  /// One of PROMOTION/DEMOTION/TERMINATION/REACTIVATION → search a staffer, then
  /// open their profile with that action pre-armed. Feed refreshes on return.
  Future<void> _startAction(String action) async {
    final emp = await _pickEmployee(action);
    if (emp == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmployeeDetailScreen(
          employeeId: emp.employeeId,
          employeeName: emp.employeeName,
          initialAction: action,
        ),
      ),
    );
    if (mounted) _load();
  }

  /// Modal staff search (name), used by the quick-action buttons.
  Future<Employee?> _pickEmployee(String action) async {
    final title = switch (action) {
      'PROMOTION' => 'Promote — find staff',
      'DEMOTION' => 'Demote — find staff',
      'TERMINATION' => 'Terminate — find staff',
      'REACTIVATION' => 'Reactivate — find staff',
      _ => 'Find staff',
    };
    return showDialog<Employee>(
      context: context,
      builder: (ctx) => _StaffSearchDialog(
        title: title,
        preloaded: _staffCache,
        onLoaded: (list) => _staffCache = list,
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await context.read<StaffService>().statusFeed();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load status changes.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Status Changes'),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_canChange) _actionBar(cs),
              if (_entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Center(
                    child: Text('No status changes yet.',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  ),
                )
              else
                for (final e in _entries) _entryCard(e, cs),
            ],
          ),
        ),
      ),
    );
  }

  /// Quick-action buttons: search a staffer, then open their profile with the
  /// chosen action pre-armed.
  Widget _actionBar(ColorScheme cs) {
    Widget btn(String action, IconData icon, String label, Color color) {
      return OutlinedButton.icon(
        onPressed: () => _startAction(action),
        icon: Icon(icon, size: 18, color: color),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.onSurface,
          side: BorderSide(color: cs.outlineVariant),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Record a status change',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              btn('PROMOTION', Icons.arrow_upward, 'Promote',
                  const Color(0xFF2E7D43)),
              btn('DEMOTION', Icons.arrow_downward, 'Demote',
                  const Color(0xFFB26A00)),
              btn('TERMINATION', Icons.person_off, 'Terminate',
                  const Color(0xFFB3261E)),
              btn('REACTIVATION', Icons.restart_alt, 'Reactivate',
                  const Color(0xFF1565C0)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _entryCard(StatusLogEntry e, ColorScheme cs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EmployeeDetailScreen(
            employeeId: e.employeeId,
            employeeName: e.employeeName,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? cs.surfaceContainerHigh : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            _actionChip(e.actionType, cs),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.employeeName,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${e.summary}  ·  ${e.processedByName}  ·  ${e.dateDisplay}',
                      style:
                          TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _actionChip(String action, ColorScheme cs) {
    Color bg;
    Color fg;
    IconData icon;
    switch (action) {
      case 'PROMOTION':
        bg = const Color(0xFFDFF3E4);
        fg = const Color(0xFF2E7D43);
        icon = Icons.arrow_upward;
        break;
      case 'DEMOTION':
        bg = const Color(0xFFFDECEC);
        fg = const Color(0xFFB26A00);
        icon = Icons.arrow_downward;
        break;
      case 'TERMINATION':
        bg = const Color(0xFFFDE7E7);
        fg = const Color(0xFFB3261E);
        icon = Icons.person_off_outlined;
        break;
      case 'REACTIVATION':
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1565C0);
        icon = Icons.restart_alt;
        break;
      default: // TRANSFER etc.
        bg = cs.surfaceContainerHighest;
        fg = cs.onSurfaceVariant;
        icon = Icons.swap_horiz;
    }
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, size: 18, color: fg),
    );
  }
}

/// Name-search picker over all staff. Loads once (cached by the caller) and
/// filters client-side; returns the chosen [Employee] via Navigator.pop.
class _StaffSearchDialog extends StatefulWidget {
  final String title;
  final List<Employee>? preloaded;
  final ValueChanged<List<Employee>> onLoaded;
  const _StaffSearchDialog({
    required this.title,
    required this.preloaded,
    required this.onLoaded,
  });

  @override
  State<_StaffSearchDialog> createState() => _StaffSearchDialogState();
}

class _StaffSearchDialogState extends State<_StaffSearchDialog> {
  final TextEditingController _ctrl = TextEditingController();
  List<Employee>? _all;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _all = widget.preloaded;
    if (_all == null) _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await context.read<StaffService>().listEmployees();
      list.sort((a, b) => a.employeeName
          .toLowerCase()
          .compareTo(b.employeeName.toLowerCase()));
      if (!mounted) return;
      widget.onLoaded(list);
      setState(() => _all = list);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load staff.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final all = _all;
    final q = _query.trim().toLowerCase();
    final filtered = all == null
        ? const <Employee>[]
        : (q.isEmpty
            ? all
            : all
                .where((e) => e.employeeName.toLowerCase().contains(q))
                .toList());

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        height: 460,
        child: Column(
          children: [
            TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Search by name',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _error != null
                  ? Center(child: Text(_error!))
                  : all == null
                      ? const Center(child: CircularProgressIndicator())
                      : filtered.isEmpty
                          ? Center(
                              child: Text(
                                q.isEmpty
                                    ? 'No staff found.'
                                    : 'No matches for "$q".',
                                style:
                                    TextStyle(color: cs.onSurfaceVariant),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final e = filtered[i];
                                final sub = [
                                  if ((e.positionTitle ?? '').isNotEmpty)
                                    e.positionTitle!,
                                  if ((e.brandName ?? '').isNotEmpty)
                                    e.brandName!,
                                  if ((e.storeName ?? '').isNotEmpty)
                                    e.storeName!,
                                ].join('  ·  ');
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: cs.primary
                                        .withOpacity(0.12),
                                    child: Icon(Icons.person,
                                        size: 18, color: cs.primary),
                                  ),
                                  title: Text(e.employeeName),
                                  subtitle:
                                      sub.isEmpty ? null : Text(sub),
                                  onTap: () =>
                                      Navigator.pop(context, e),
                                );
                              },
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
      ],
    );
  }
}

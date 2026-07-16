import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/audit_log.dart';
import '../services/staff_service.dart';
import '../widgets/app_scaffold.dart';

/// Admin mini-console: a read view over audit_logs (standing rule #3).
class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  bool _loading = true;
  String? _error;
  List<AuditLogEntry> _entries = [];
  String? _table; // active table filter

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
      final entries = await context.read<StaffService>().auditLogs(table: _table);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load the audit log.';
        _loading = false;
      });
    }
  }

  void _setFilter(String? table) {
    setState(() => _table = table);
    _load();
  }

  void _showDetails(AuditLogEntry e) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(e.summary),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${e.action} · ${e.affectedTable} #${e.recordId}',
                    style: TextStyle(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                Text('By ${e.userName} · ${e.whenDisplay}',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                if (e.oldValue != null) ...[
                  const SizedBox(height: 12),
                  const Text('Before',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  SelectableText(e.oldValue.toString()),
                ],
                if (e.newValue != null) ...[
                  const SizedBox(height: 12),
                  const Text('After',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  SelectableText(e.newValue.toString()),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Audit Logs'),
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

  static const _filters = <String, String?>{
    'All': null,
    'Employees': 'employees',
    'Notes': 'staff_notes',
    'Notifications': 'notifications',
    'Users': 'users',
    'Settings': 'app_settings',
  };

  Widget _buildBody() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              for (final entry in _filters.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.key),
                    selected: _table == entry.value,
                    onSelected: (_) => _setFilter(entry.value),
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: _list(cs)),
      ],
    );
  }

  Widget _list(ColorScheme cs) {
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
    if (_entries.isEmpty) {
      return Center(
        child: Text('No audit entries.',
            style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final e in _entries) _row(e, cs)],
          ),
        ),
      ),
    );
  }

  Widget _row(AuditLogEntry e, ColorScheme cs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => _showDetails(e),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? cs.surfaceContainerHigh : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            _actionBadge(e.action),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.summary,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('${e.userName}  ·  ${e.whenDisplay}',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _actionBadge(String action) {
    Color bg;
    Color fg;
    switch (action) {
      case 'INSERT':
        bg = const Color(0xFFDFF3E4);
        fg = const Color(0xFF2E7D43);
        break;
      case 'DELETE':
        bg = const Color(0xFFFDE7E7);
        fg = const Color(0xFFB3261E);
        break;
      default: // UPDATE
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1565C0);
    }
    final label = {'INSERT': 'NEW', 'UPDATE': 'UPD', 'DELETE': 'DEL'}[action] ??
        action;
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

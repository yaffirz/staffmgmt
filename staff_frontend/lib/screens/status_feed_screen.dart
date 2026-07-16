import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/status_log.dart';
import '../services/staff_service.dart';
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
    if (_entries.isEmpty) {
      return Center(
        child: Text('No status changes yet.',
            style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final e in _entries) _entryCard(e, cs)],
          ),
        ),
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/clock.dart';
import '../services/api_client.dart';
import '../services/staff_service.dart';
import '../widgets/app_scaffold.dart';

/// Manager-assisted clock-in: a store/area manager (or admin) clocks staff in or
/// out on their behalf when they can't scan, plus a recent-events view.
class ClockManagerScreen extends StatefulWidget {
  const ClockManagerScreen({super.key});

  @override
  State<ClockManagerScreen> createState() => _ClockManagerScreenState();
}

class _ClockManagerScreenState extends State<ClockManagerScreen> {
  List<ClockStatus> _roster = [];
  List<ClockEvent> _events = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  final Set<int> _busyIds = {};

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
      final results = await Future.wait([svc.clockMyRoster(), svc.clockEvents()]);
      if (!mounted) return;
      setState(() {
        _roster = results[0] as List<ClockStatus>;
        _events = results[1] as List<ClockEvent>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load the clock-in roster.';
        _loading = false;
      });
    }
  }

  Future<void> _punch(ClockStatus s) async {
    setState(() => _busyIds.add(s.employeeId));
    try {
      final res = await context
          .read<StaffService>()
          .clockManagerPunch(s.employeeId, eventType: s.nextEventType);
      if (!mounted) return;
      final verb = res.event.eventType == 'in' ? 'in' : 'out';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${res.status.employeeName} clocked $verb at ${_time(res.event.occurredAt)}')));
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not record the punch.')));
    } finally {
      if (mounted) setState(() => _busyIds.remove(s.employeeId));
    }
  }

  String _time(DateTime dt) {
    final l = dt.toLocal();
    final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
    final m = l.minute.toString().padLeft(2, '0');
    final ap = l.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ap';
  }

  String _dateTime(DateTime dt) {
    final l = dt.toLocal();
    return '${l.month.toString().padLeft(2, '0')}/${l.day.toString().padLeft(2, '0')} '
        '${_time(dt)}';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: AppScaffold(
        appBar: AppBar(
          title: const Text('Clock In Staff'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : _load,
            ),
            const SizedBox(width: 6),
          ],
          bottom: const TabBar(
            tabs: [Tab(text: 'Clock in / out'), Tab(text: 'Recent')],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _errorBody()
                : TabBarView(children: [_rosterTab(), _eventsTab()]),
      ),
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

  Widget _rosterTab() {
    final cs = Theme.of(context).colorScheme;
    final items = _roster.where((s) {
      if (_query.isEmpty) return true;
      return '${s.employeeName} ${s.payrollId} ${s.storeName ?? ''}'
          .toLowerCase()
          .contains(_query);
    }).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search staff…',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        if (_roster.isEmpty)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  'No clock-in staff in your scope yet.\nStaff appear here once '
                  'their brand is marked Non-Oracle.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _rosterCard(cs, items[i]),
            ),
          ),
      ],
    );
  }

  Widget _rosterCard(ColorScheme cs, ClockStatus s) {
    final goingIn = s.nextEventType == 'in';
    final color = goingIn ? const Color(0xFF2E7D43) : const Color(0xFFB26A00);
    final busy = _busyIds.contains(s.employeeId);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.employeeName,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text([
                  s.payrollId,
                  if ((s.storeName ?? '').isNotEmpty) s.storeName!,
                ].join(' · '),
                    style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(
                  s.isClockedIn
                      ? 'In since ${s.lastEventAt != null ? _time(s.lastEventAt!) : '—'}'
                      : (s.lastEventType == null
                          ? 'Not clocked in'
                          : 'Clocked out'),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: s.isClockedIn
                          ? const Color(0xFF2E7D43)
                          : cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: color),
            onPressed: busy ? null : () => _punch(s),
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Icon(goingIn ? Icons.login : Icons.logout, size: 18),
            label: Text(goingIn ? 'Clock in' : 'Clock out'),
          ),
        ],
      ),
    );
  }

  Widget _eventsTab() {
    final cs = Theme.of(context).colorScheme;
    if (_events.isEmpty) {
      return Center(
        child: Text('No clock events yet.',
            style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _events.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final e = _events[i];
        final inEvent = e.eventType == 'in';
        final color =
            inEvent ? const Color(0xFF2E7D43) : const Color(0xFFB26A00);
        return ListTile(
          dense: true,
          leading: Icon(inEvent ? Icons.login : Icons.logout, color: color),
          title: Text(e.employeeName),
          subtitle: Text('${inEvent ? 'Clocked in' : 'Clocked out'} · '
              '${_sourceLabel(e.source)}${e.note != null && e.note!.isNotEmpty ? ' · ${e.note}' : ''}'),
          trailing: Text(_dateTime(e.occurredAt),
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        );
      },
    );
  }

  String _sourceLabel(String s) {
    switch (s) {
      case 'kiosk':
        return 'kiosk scan';
      case 'manager':
        return 'by manager';
      case 'dev':
        return 'simulated';
      default:
        return s;
    }
  }
}

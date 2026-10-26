import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/clock.dart';
import '../services/api_client.dart';
import '../services/staff_service.dart';

/// Kiosk clock-in station (no login). Identity comes from a fingerprint scan;
/// in dev mode an operator may pick an employee to simulate a scan. Reached
/// from the login screen's "Clock-in station" link.
class ClockKioskScreen extends StatefulWidget {
  const ClockKioskScreen({super.key});

  @override
  State<ClockKioskScreen> createState() => _ClockKioskScreenState();
}

class _ClockKioskScreenState extends State<ClockKioskScreen> {
  ClockConfig? _config;
  bool _loading = true;
  String? _loadError;

  // Simulate-scan picker (dev mode).
  List<Map<String, dynamic>> _roster = [];
  String _query = '';

  // Current selection + flow state.
  ClockStatus? _status;
  bool _busy = false;
  String? _error;
  PunchResult? _confirmed; // shows a confirmation then auto-resets
  Timer? _resetTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final svc = context.read<StaffService>();
      final cfg = await svc.clockConfig();
      List<Map<String, dynamic>> roster = const [];
      if (cfg.enabled && cfg.devMode) {
        roster = await svc.clockRoster();
      }
      if (!mounted) return;
      setState(() {
        _config = cfg;
        _roster = roster;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not reach the clock-in service.';
        _loading = false;
      });
    }
  }

  Future<void> _identify(int employeeId) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final status =
          await context.read<StaffService>().clockIdentify(employeeId: employeeId);
      if (!mounted) return;
      setState(() => _status = status);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not read that scan.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _punch() async {
    final s = _status;
    if (s == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Dev kiosk punches by employee id; the real SDK path would pass a template.
      final res = await context
          .read<StaffService>()
          .clockPunch(employeeId: s.employeeId);
      if (!mounted) return;
      setState(() {
        _confirmed = res;
        _status = null;
      });
      _resetTimer?.cancel();
      _resetTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _confirmed = null);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not record the punch.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reset() {
    _resetTimer?.cancel();
    setState(() {
      _status = null;
      _confirmed = null;
      _error = null;
      _query = '';
    });
  }

  String _time(DateTime dt) {
    final l = dt.toLocal();
    final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
    final m = l.minute.toString().padLeft(2, '0');
    final ap = l.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ap';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Clock-in Station'),
        leading: IconButton(
          tooltip: 'Exit',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _body(cs),
          ),
        ),
      ),
    );
  }

  Widget _body(ColorScheme cs) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return _centered(Icons.wifi_off, _loadError!, retry: true);
    }
    if (_config == null || !_config!.enabled) {
      return _centered(Icons.schedule, 'Clock-in is currently unavailable.');
    }
    if (_confirmed != null) return _confirmation(cs, _confirmed!);
    if (_status != null) return _punchCard(cs, _status!);
    return _scanPrompt(cs);
  }

  Widget _centered(IconData icon, String text, {bool retry = false}) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: cs.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
          if (retry) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }

  Widget _scanPrompt(ColorScheme cs) {
    final dev = _config!.devMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Icon(Icons.fingerprint, size: 96, color: cs.primary),
        const SizedBox(height: 12),
        const Text('Place your finger on the reader',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('to clock in or out',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant)),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
        ],
        if (dev) ...[
          const SizedBox(height: 24),
          const Divider(),
          Row(
            children: [
              Icon(Icons.science_outlined, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text('Simulate a scan (dev mode)',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(
              isDense: true,
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search staff…',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 240,
            child: _rosterList(cs),
          ),
        ],
      ],
    );
  }

  Widget _rosterList(ColorScheme cs) {
    final items = _roster.where((e) {
      if (_query.isEmpty) return true;
      return '${e['employee_name']} ${e['payroll_id']} ${e['store_name'] ?? ''}'
          .toLowerCase()
          .contains(_query);
    }).toList();
    if (_roster.isEmpty) {
      return Center(
        child: Text('No one is on the clock-in roster yet.',
            style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }
    if (items.isEmpty) {
      return Center(
          child: Text('No matches.', style: TextStyle(color: cs.onSurfaceVariant)));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final e = items[i];
        return ListTile(
          dense: true,
          leading: const Icon(Icons.person_outline),
          title: Text(e['employee_name'] as String),
          subtitle: Text([
            e['payroll_id'],
            if ((e['store_name'] ?? '').toString().isNotEmpty) e['store_name'],
          ].join(' · ')),
          onTap: _busy ? null : () => _identify(e['employee_id'] as int),
        );
      },
    );
  }

  Widget _punchCard(ColorScheme cs, ClockStatus s) {
    final goingIn = s.nextEventType == 'in';
    final color = goingIn ? const Color(0xFF2E7D43) : const Color(0xFFB26A00);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              Text(s.employeeName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text([
                if ((s.brandName ?? '').isNotEmpty) s.brandName!,
                if ((s.storeName ?? '').isNotEmpty) s.storeName!,
              ].join('  ·  '),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant)),
              const SizedBox(height: 10),
              Text(
                s.isClockedIn
                    ? 'Currently clocked IN'
                    : (s.lastEventType == null
                        ? 'Not clocked in yet'
                        : 'Currently clocked OUT'),
                style: TextStyle(fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 72,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: color,
              textStyle:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            onPressed: _busy ? null : _punch,
            icon: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : Icon(goingIn ? Icons.login : Icons.logout, size: 28),
            label: Text(goingIn ? 'CLOCK IN' : 'CLOCK OUT'),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 12),
        TextButton(onPressed: _busy ? null : _reset, child: const Text('Cancel')),
      ],
    );
  }

  Widget _confirmation(ColorScheme cs, PunchResult r) {
    final goingIn = r.event.eventType == 'in';
    final color = goingIn ? const Color(0xFF2E7D43) : const Color(0xFFB26A00);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 84, color: color),
          const SizedBox(height: 16),
          Text(r.status.employeeName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            goingIn ? 'Clocked IN' : 'Clocked OUT',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: 4),
          Text('at ${_time(r.event.occurredAt)}',
              style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 24),
          FilledButton(onPressed: _reset, child: const Text('Done')),
        ],
      ),
    );
  }
}

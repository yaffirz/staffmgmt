import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/audit_log.dart';
import '../services/staff_service.dart';
import '../widgets/app_scaffold.dart';

/// Read-only, terminal-styled live feed of platform activity (the audit log).
/// It only DISPLAYS — there is no command input.
class AdminConsoleScreen extends StatefulWidget {
  const AdminConsoleScreen({super.key});

  @override
  State<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends State<AdminConsoleScreen> {
  static const _bg = Color(0xFF0B1412);
  static const _dim = Color(0xFF5E726F);
  static const _amber = Color(0xFFE9A23B);

  List<AuditLogEntry> _entries = [];
  bool _loading = true;
  bool _live = true;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_live) _load();
    });
  }

  Future<void> _load() async {
    try {
      final e = await context.read<StaffService>().auditLogs();
      if (!mounted) return;
      setState(() {
        _entries = e;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load activity.';
        _loading = false;
      });
    }
  }

  Color _actionColor(String a) => switch (a) {
        'INSERT' => const Color(0xFF57D98A),
        'DELETE' => const Color(0xFFFF6B6B),
        _ => const Color(0xFF5AB2FF),
      };

  String _t(DateTime ts) {
    final d = ts.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Activity Console'),
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => _live = !_live),
            icon: Icon(_live ? Icons.pause_circle_outline : Icons.play_circle_outline,
                size: 18, color: Colors.white),
            label: Text(_live ? 'Live' : 'Paused',
                style: const TextStyle(color: Colors.white)),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF20302D)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                child: Row(
                  children: [
                    Icon(Icons.circle,
                        size: 9, color: _live ? const Color(0xFF57D98A) : _dim),
                    const SizedBox(width: 8),
                    Text(_live ? 'live · platform activity' : 'paused',
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            color: Color(0xFF8FA6A3),
                            fontSize: 12.5)),
                    const Spacer(),
                    Text('${_entries.length} events',
                        style: const TextStyle(
                            fontFamily: 'monospace', color: _dim, fontSize: 12)),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFF20302D)),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: Color(0xFFFF6B6B))),
      );
    }
    if (_entries.isEmpty) {
      return const Center(
        child: Text('No activity yet.',
            style: TextStyle(fontFamily: 'monospace', color: _dim)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      itemCount: _entries.length,
      itemBuilder: (_, i) => _line(_entries[i]),
    );
  }

  Widget _line(AuditLogEntry e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: SelectableText.rich(
        TextSpan(
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.35),
          children: [
            TextSpan(text: '${_t(e.timestamp)}  ', style: const TextStyle(color: _dim)),
            TextSpan(text: e.userName, style: const TextStyle(color: _amber)),
            const TextSpan(text: '  '),
            TextSpan(
                text: e.action.padRight(6),
                style: TextStyle(
                    color: _actionColor(e.action), fontWeight: FontWeight.bold)),
            TextSpan(
                text: ' ${e.affectedTable}#${e.recordId}',
                style: const TextStyle(color: Color(0xFF8FA6A3))),
            TextSpan(
                text: '  ${e.summary}',
                style: const TextStyle(color: Color(0xFFD7E3E1))),
          ],
        ),
      ),
    );
  }
}

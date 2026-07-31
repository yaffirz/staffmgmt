import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/backup_item.dart';
import '../services/file_download.dart';
import '../services/staff_service.dart';
import '../widgets/app_scaffold.dart';

/// Super-Admin backup manager: run a backup now (with a live progress/elapsed
/// indicator), download/delete existing dumps, and set a daily/weekly schedule.
class AdminBackupsScreen extends StatefulWidget {
  const AdminBackupsScreen({super.key});

  @override
  State<AdminBackupsScreen> createState() => _AdminBackupsScreenState();
}

class _AdminBackupsScreenState extends State<AdminBackupsScreen> {
  bool _loading = true;
  String? _error;
  List<BackupItem> _items = [];

  // running-backup state
  int? _runningId;
  DateTime? _runStart;
  bool _starting = false;
  Timer? _poll;
  Timer? _tick;

  // schedule form
  String _sched = 'off';
  final TextEditingController _timeCtrl = TextEditingController(text: '02:00');
  int _retention = 10;
  bool _savingSchedule = false;

  static const _schedLabels = {'off': 'Off', 'daily': 'Daily', 'weekly': 'Weekly'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    _timeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final svc = context.read<StaffService>();
      final results = await Future.wait([svc.backups(), svc.backupSchedule()]);
      if (!mounted) return;
      final sched = results[1] as BackupSchedule;
      setState(() {
        _items = results[0] as List<BackupItem>;
        _sched = sched.schedule;
        _timeCtrl.text = sched.time;
        _retention = sched.retention;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load backups.';
        _loading = false;
      });
    }
  }

  Future<void> _backupNow() async {
    if (_starting || _runningId != null) return;
    setState(() => _starting = true);
    try {
      final b = await context.read<StaffService>().startBackup();
      if (!mounted) return;
      setState(() {
        _runningId = b.id;
        _runStart = DateTime.now();
        _starting = false;
      });
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
      _poll = Timer.periodic(const Duration(milliseconds: 1500), (_) => _pollStatus());
      _load();
    } catch (_) {
      if (!mounted) return;
      setState(() => _starting = false);
      _snack('Could not start the backup.');
    }
  }

  Future<void> _pollStatus() async {
    final id = _runningId;
    if (id == null) return;
    try {
      final b = await context.read<StaffService>().backupStatus(id);
      if (!mounted) return;
      if (!b.isRunning) {
        _poll?.cancel();
        _tick?.cancel();
        setState(() {
          _runningId = null;
          _runStart = null;
        });
        _snack(b.isCompleted
            ? 'Backup complete (${b.sizeLabel}).'
            : 'Backup failed.');
        _load();
      }
    } catch (_) {/* keep polling */}
  }

  Future<void> _download(BackupItem b) async {
    try {
      final bytes = await context.read<StaffService>().downloadBackup(b.id);
      downloadBytes(b.filename, bytes);
    } catch (_) {
      _snack('Could not download the backup.');
    }
  }

  Future<void> _delete(BackupItem b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete backup?'),
        content: Text(b.filename),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB3261E)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await context.read<StaffService>().deleteBackup(b.id);
      _load();
    } catch (_) {
      _snack('Could not delete.');
    }
  }

  Future<void> _saveSchedule() async {
    setState(() => _savingSchedule = true);
    try {
      final s = await context
          .read<StaffService>()
          .setBackupSchedule(_sched, _timeCtrl.text.trim(), _retention);
      if (!mounted) return;
      setState(() {
        _sched = s.schedule;
        _timeCtrl.text = s.time;
        _retention = s.retention;
        _savingSchedule = false;
      });
      _snack('Backup schedule saved.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingSchedule = false);
      _snack('Could not save the schedule.');
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Backups'),
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
              _actionRow(cs),
              if (_runningId != null) ...[
                const SizedBox(height: 14),
                _progressCard(cs),
              ],
              const SizedBox(height: 22),
              _scheduleCard(cs),
              const SizedBox(height: 22),
              Text('Backups', style: _h(context)),
              const SizedBox(height: 8),
              if (_items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No backups yet.',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  ),
                )
              else
                for (final b in _items) _backupRow(b, cs),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.lock_outline, size: 15, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'A backup contains all data, including password hashes. '
                      'Keep downloaded files private.',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle? _h(BuildContext c) =>
      Theme.of(c).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);

  Widget _actionRow(ColorScheme cs) {
    final busy = _runningId != null || _starting;
    return Row(
      children: [
        Expanded(
          child: Text('Run a backup of the database now, or schedule automatic ones.',
              style: TextStyle(color: cs.onSurfaceVariant)),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: busy ? null : _backupNow,
          icon: const Icon(Icons.backup_outlined, size: 18),
          label: Text(busy ? 'Backing up…' : 'Back up now'),
        ),
      ],
    );
  }

  Widget _progressCard(ColorScheme cs) {
    final secs = _runStart == null
        ? 0
        : DateTime.now().difference(_runStart!).inSeconds;
    return _card(
      cs,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 10),
              Text('Backing up the database…',
                  style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface)),
              const Spacer(),
              Text('${secs}s',
                  style: TextStyle(
                      fontFeatures: const [],
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: const LinearProgressIndicator(minHeight: 8),
          ),
        ],
      ),
    );
  }

  Widget _scheduleCard(ColorScheme cs) {
    return _card(
      cs,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Automatic backups', style: _h(context)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _sched,
                  decoration: const InputDecoration(
                      labelText: 'Frequency', border: OutlineInputBorder()),
                  items: [
                    for (final e in _schedLabels.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _sched = v ?? 'off'),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _timeCtrl,
                  enabled: _sched != 'off',
                  decoration: const InputDecoration(
                      labelText: 'Time (24h)',
                      hintText: '02:00',
                      border: OutlineInputBorder()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text('Keep the most recent $_retention backups',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ),
              IconButton(
                onPressed: _retention > 1
                    ? () => setState(() => _retention--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$_retention',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              IconButton(
                onPressed: _retention < 100
                    ? () => setState(() => _retention++)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _savingSchedule ? null : _saveSchedule,
              child: _savingSchedule
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save schedule'),
            ),
          ),
          if (_sched != 'off')
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _sched == 'weekly'
                    ? 'Runs every Monday at ${_timeCtrl.text} (server time).'
                    : 'Runs every day at ${_timeCtrl.text} (server time).',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  Widget _backupRow(BackupItem b, ColorScheme cs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget statusChip;
    if (b.isRunning) {
      statusChip = _chip('running', const Color(0xFF1565C0));
    } else if (b.isFailed) {
      statusChip = _chip('failed', const Color(0xFFB3261E));
    } else {
      final dur = b.duration;
      statusChip = Text(
        '${b.sizeLabel}${dur != null ? ' · ${dur.inSeconds}s' : ''}',
        style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            b.kind == 'scheduled' ? Icons.schedule : Icons.backup_outlined,
            size: 20,
            color: cs.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.filename,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13.5)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(b.kind, style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
                    const SizedBox(width: 8),
                    Text('· ${b.startedLabel}',
                        style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
          statusChip,
          if (b.isCompleted && downloadSupported)
            IconButton(
              tooltip: 'Download',
              icon: const Icon(Icons.download_outlined, size: 20),
              onPressed: () => _download(b),
            ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: b.isRunning ? null : () => _delete(b),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
      );

  Widget _card(ColorScheme cs, Widget child) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: child,
    );
  }
}

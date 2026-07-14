import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/staff_service.dart';
import '../widgets/app_scaffold.dart';

/// Admin / Super Admin settings — feature toggles backed by app_settings.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _moveKey = 'area_managers_can_move';
  static const _notesKey = 'staff_notes_enabled';

  bool _loading = true;
  String? _error;
  bool _canMove = true;
  bool _notesEnabled = true;
  bool _saving = false;

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
      final results =
          await Future.wait([svc.getSetting(_moveKey), svc.getSetting(_notesKey)]);
      if (!mounted) return;
      setState(() {
        _canMove = results[0].toLowerCase() == 'true';
        _notesEnabled = results[1].toLowerCase() == 'true';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load settings.';
        _loading = false;
      });
    }
  }

  Future<void> _setCanMove(bool value) async {
    setState(() {
      _canMove = value; // optimistic
      _saving = true;
    });
    try {
      final saved = await context
          .read<StaffService>()
          .updateSetting(_moveKey, value ? 'true' : 'false');
      if (!mounted) return;
      setState(() {
        _canMove = saved.toLowerCase() == 'true';
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_canMove
              ? 'Area Managers can now move staff.'
              : 'Area Managers can no longer move staff.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _canMove = !value; // revert
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update the setting.')),
      );
    }
  }

  Future<void> _setNotesEnabled(bool value) async {
    setState(() {
      _notesEnabled = value; // optimistic
      _saving = true;
    });
    try {
      final saved = await context
          .read<StaffService>()
          .updateSetting(_notesKey, value ? 'true' : 'false');
      if (!mounted) return;
      setState(() {
        _notesEnabled = saved.toLowerCase() == 'true';
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_notesEnabled
              ? 'Staff notes are enabled.'
              : 'Staff notes are disabled.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notesEnabled = !value; // revert
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update the setting.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: const Text('Settings')),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Area Manager permissions',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? cs.surfaceContainerHigh : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: SwitchListTile(
                  title: const Text('Area Managers can move staff'),
                  subtitle: const Text(
                      'When off, Area Managers cannot change a staffer\'s '
                      'primary store from My Cluster.'),
                  value: _canMove,
                  onChanged: _saving ? null : _setCanMove,
                ),
              ),
              const SizedBox(height: 24),
              Text('Staff notes',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? cs.surfaceContainerHigh : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: SwitchListTile(
                  title: const Text('Staff notes enabled'),
                  subtitle: const Text(
                      'When off, no one can add or edit notes on staff. '
                      'Existing notes stay viewable.'),
                  value: _notesEnabled,
                  onChanged: _saving ? null : _setNotesEnabled,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

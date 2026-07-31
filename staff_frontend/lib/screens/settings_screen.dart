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
  static const _maintKey = 'maintenance_mode';
  static const _maintMsgKey = 'maintenance_message';
  static const _maintUntilKey = 'maintenance_until';
  static const _mktEnabledKey = 'marketing_enabled';
  static const _mktTypeKey = 'marketing_type';
  static const _mktTitleKey = 'marketing_title';
  static const _mktContentKey = 'marketing_content';
  static const _registrationKey = 'registration_enabled';

  // Marketing content types (value -> label).
  static const _mktTypes = <String, String>{
    'text': 'Text',
    'image': 'Image (URL)',
    'embed': 'Video / embed (URL)',
  };

  // Duration options for the maintenance window (label -> minutes; null = none).
  static const _durationOptions = <String, int?>{
    'No end time': null,
    '15 minutes': 15,
    '30 minutes': 30,
    '1 hour': 60,
    '2 hours': 120,
    '4 hours': 240,
  };

  bool _loading = true;
  String? _error;
  bool _canMove = true;
  bool _notesEnabled = true;
  bool _saving = false;

  // Maintenance state.
  bool _maintenanceOn = false;
  DateTime? _maintenanceUntil; // saved absolute end time
  String _selectedDuration = 'No end time';
  final TextEditingController _msgController = TextEditingController();
  bool _savingWindow = false;

  // Marketing block state.
  bool _marketingOn = false;
  String _marketingType = 'text';
  final TextEditingController _mktTitleController = TextEditingController();
  final TextEditingController _mktContentController = TextEditingController();
  bool _savingMarketing = false;

  // Registration.
  bool _registrationOn = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _msgController.dispose();
    _mktTitleController.dispose();
    _mktContentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = context.read<StaffService>();
      final results = await Future.wait([
        svc.getSetting(_moveKey),
        svc.getSetting(_notesKey),
        svc.getSetting(_maintKey),
        svc.getSetting(_maintMsgKey),
        svc.getSetting(_maintUntilKey),
        svc.getSetting(_mktEnabledKey),
        svc.getSetting(_mktTypeKey),
        svc.getSetting(_mktTitleKey),
        svc.getSetting(_mktContentKey),
        svc.getSetting(_registrationKey),
      ]);
      if (!mounted) return;
      final untilRaw = results[4];
      final mktType = results[6].toLowerCase();
      setState(() {
        _canMove = results[0].toLowerCase() == 'true';
        _notesEnabled = results[1].toLowerCase() == 'true';
        _maintenanceOn = results[2].toLowerCase() == 'true';
        _msgController.text = results[3];
        _maintenanceUntil =
            untilRaw.isEmpty ? null : DateTime.tryParse(untilRaw);
        _marketingOn = results[5].toLowerCase() == 'true';
        _marketingType = _mktTypes.containsKey(mktType) ? mktType : 'text';
        _mktTitleController.text = results[7];
        _mktContentController.text = results[8];
        _registrationOn = results[9].toLowerCase() == 'true';
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

  Future<void> _setBoolSetting(
    String key,
    bool value,
    void Function(bool) apply,
    String Function(bool) message,
  ) async {
    setState(() {
      apply(value); // optimistic
      _saving = true;
    });
    try {
      final saved = await context
          .read<StaffService>()
          .updateSetting(key, value ? 'true' : 'false');
      if (!mounted) return;
      final on = saved.toLowerCase() == 'true';
      setState(() {
        apply(on);
        _saving = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message(on))));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        apply(!value); // revert
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update the setting.')),
      );
    }
  }

  Future<void> _setCanMove(bool value) => _setBoolSetting(
        _moveKey,
        value,
        (v) => _canMove = v,
        (on) => on
            ? 'Area Managers can now move staff.'
            : 'Area Managers can no longer move staff.',
      );

  Future<void> _setNotesEnabled(bool value) => _setBoolSetting(
        _notesKey,
        value,
        (v) => _notesEnabled = v,
        (on) => on ? 'Staff notes are enabled.' : 'Staff notes are disabled.',
      );

  Future<void> _setMaintenance(bool value) => _setBoolSetting(
        _maintKey,
        value,
        (v) => _maintenanceOn = v,
        (on) => on
            ? 'Maintenance mode is ON — field users are now blocked.'
            : 'Maintenance mode is OFF.',
      );

  /// Save the custom message + the maintenance window end time (derived from the
  /// chosen duration, starting now).
  Future<void> _saveWindow() async {
    setState(() => _savingWindow = true);
    final minutes = _durationOptions[_selectedDuration];
    final until = minutes == null
        ? ''
        : DateTime.now().toUtc().add(Duration(minutes: minutes)).toIso8601String();
    try {
      final svc = context.read<StaffService>();
      await svc.updateSetting(_maintMsgKey, _msgController.text.trim());
      final savedUntil = await svc.updateSetting(_maintUntilKey, until);
      if (!mounted) return;
      setState(() {
        _maintenanceUntil =
            savedUntil.isEmpty ? null : DateTime.tryParse(savedUntil);
        _selectedDuration = 'No end time'; // reset the relative picker
        _savingWindow = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maintenance message & window saved.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingWindow = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the maintenance window.')),
      );
    }
  }

  Future<void> _setRegistration(bool value) => _setBoolSetting(
        _registrationKey,
        value,
        (v) => _registrationOn = v,
        (on) => on
            ? 'Self-registration is ON — the login screen shows "Create account".'
            : 'Self-registration is OFF.',
      );

  Future<void> _setMarketing(bool value) => _setBoolSetting(
        _mktEnabledKey,
        value,
        (v) => _marketingOn = v,
        (on) => on
            ? 'Marketing block is ON — shown on the login screen.'
            : 'Marketing block is OFF.',
      );

  /// Save the marketing type, title and content together.
  Future<void> _saveMarketing() async {
    setState(() => _savingMarketing = true);
    try {
      final svc = context.read<StaffService>();
      await svc.updateSetting(_mktTypeKey, _marketingType);
      await svc.updateSetting(_mktTitleKey, _mktTitleController.text.trim());
      await svc.updateSetting(_mktContentKey, _mktContentController.text.trim());
      if (!mounted) return;
      setState(() => _savingMarketing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marketing block saved.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingMarketing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the marketing block.')),
      );
    }
  }

  static String _fmt(DateTime dt) {
    final l = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.month)}/${two(l.day)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionTitle('Area Manager permissions'),
              const SizedBox(height: 12),
              _card(SwitchListTile(
                title: const Text('Area Managers can move staff'),
                subtitle: const Text(
                    'When off, Area Managers cannot change a staffer\'s '
                    'primary store from My Cluster.'),
                value: _canMove,
                onChanged: _saving ? null : _setCanMove,
              )),
              const SizedBox(height: 24),
              _sectionTitle('Staff notes'),
              const SizedBox(height: 12),
              _card(SwitchListTile(
                title: const Text('Staff notes enabled'),
                subtitle: const Text(
                    'When off, no one can add or edit notes on staff. '
                    'Existing notes stay viewable.'),
                value: _notesEnabled,
                onChanged: _saving ? null : _setNotesEnabled,
              )),
              const SizedBox(height: 24),
              _sectionTitle('Maintenance mode'),
              const SizedBox(height: 12),
              _maintenanceCard(),
              const SizedBox(height: 24),
              _sectionTitle('Login marketing block'),
              const SizedBox(height: 12),
              _marketingCard(),
              const SizedBox(height: 24),
              _sectionTitle('Account registration'),
              const SizedBox(height: 12),
              _card(SwitchListTile(
                title: const Text('Allow self-registration'),
                subtitle: const Text(
                    'Shows a "Create account" link on login. New sign-ups '
                    'confirm their email, then need admin approval in '
                    'Registrations. (Email sending is not yet configured.)'),
                value: _registrationOn,
                onChanged: _saving ? null : _setRegistration,
              )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      );

  Widget _card(Widget child) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: child,
    );
  }

  Widget _marketingCard() {
    final cs = Theme.of(context).colorScheme;
    final isText = _marketingType == 'text';
    final contentLabel = switch (_marketingType) {
      'image' => 'Image URL',
      'embed' => 'Video / embed URL',
      _ => 'Text to show',
    };
    final contentHint = switch (_marketingType) {
      'image' => 'https://…/banner.png',
      'embed' => 'https://www.youtube.com/embed/VIDEO_ID',
      _ => 'e.g. New staff perks program launching next month!',
    };
    return _card(Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            title: const Text('Show marketing block on login'),
            subtitle: const Text(
                'A customizable promo area on the login screen (desktop & '
                'mobile). Supports text, an image, or a video/embed.'),
            value: _marketingOn,
            onChanged: _saving ? null : _setMarketing,
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: DropdownButtonFormField<String>(
              initialValue: _marketingType,
              decoration: const InputDecoration(
                labelText: 'Content type',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final e in _mktTypes.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) =>
                  setState(() => _marketingType = v ?? 'text'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _mktTitleController,
              decoration: const InputDecoration(
                labelText: 'Heading (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _mktContentController,
              maxLines: isText ? 4 : 1,
              keyboardType:
                  isText ? TextInputType.multiline : TextInputType.url,
              decoration: InputDecoration(
                labelText: contentLabel,
                hintText: contentHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _savingMarketing ? null : _saveMarketing,
                child: _savingMarketing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Image/embed use a URL you host elsewhere (a direct image link, or '
              'a YouTube/Vimeo embed URL). On the mobile app, videos show as a '
              'tappable link. Turn the switch on to display it.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    ));
  }

  Widget _maintenanceCard() {
    final cs = Theme.of(context).colorScheme;
    return _card(Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            title: const Text('Maintenance mode'),
            subtitle: const Text(
                'When on, HR and Area Managers see a maintenance page. '
                'Super Admin, Admin and IT keep full access.'),
            value: _maintenanceOn,
            onChanged: _saving ? null : _setMaintenance,
          ),
          if (_maintenanceOn && _maintenanceUntil != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text('Window ends: ${_fmt(_maintenanceUntil!)}',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _msgController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Message shown to users (optional)',
                hintText: 'e.g. Upgrading the roster system — back by 3pm.',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedDuration,
                    decoration: const InputDecoration(
                      labelText: 'Duration from now',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final label in _durationOptions.keys)
                        DropdownMenuItem(value: label, child: Text(label)),
                    ],
                    onChanged: (v) =>
                        setState(() => _selectedDuration = v ?? 'No end time'),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _savingWindow ? null : _saveWindow,
                  child: _savingWindow
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Saving a duration sets the countdown shown on the maintenance '
              'page (starting now). Choose “No end time” to hide the countdown.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    ));
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/staff_service.dart';
import '../widgets/app_scaffold.dart';

/// Super-Admin screen to configure the outgoing email (SMTP) server, toggle
/// sending on/off, and send a test email. Backed by the `email_*` app settings.
class EmailSettingsScreen extends StatefulWidget {
  const EmailSettingsScreen({super.key});

  @override
  State<EmailSettingsScreen> createState() => _EmailSettingsScreenState();
}

class _EmailSettingsScreenState extends State<EmailSettingsScreen> {
  bool _loading = true;
  String? _error;
  bool _saving = false;

  bool _enabled = false;
  bool _useSsl = true; // true = SSL (465), false = STARTTLS (587)
  bool _passwordSet = false;

  final _hostCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '465');
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _fromCtrl = TextEditingController();
  final _fromNameCtrl = TextEditingController();
  final _baseUrlCtrl = TextEditingController();
  final _testCtrl = TextEditingController();

  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _fromCtrl.dispose();
    _fromNameCtrl.dispose();
    _baseUrlCtrl.dispose();
    _testCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cfg = await context.read<StaffService>().getEmailConfig();
      if (!mounted) return;
      setState(() {
        _enabled = (cfg['email_enabled'] as bool?) ?? false;
        _useSsl = (cfg['email_use_ssl'] as bool?) ?? true;
        _passwordSet = (cfg['password_set'] as bool?) ?? false;
        _hostCtrl.text = (cfg['email_smtp_host'] as String?) ?? '';
        _portCtrl.text = ((cfg['email_smtp_port'] as num?)?.toString()) ?? '465';
        _userCtrl.text = (cfg['email_username'] as String?) ?? '';
        _fromCtrl.text = (cfg['email_from'] as String?) ?? '';
        _fromNameCtrl.text = (cfg['email_from_name'] as String?) ?? 'Staff Portal';
        _baseUrlCtrl.text = (cfg['app_base_url'] as String?) ?? '';
        _passCtrl.clear();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load email settings.';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final port = int.tryParse(_portCtrl.text.trim());
    if (port == null || port <= 0) {
      _snack('Enter a valid port (e.g. 465 or 587).');
      return;
    }
    setState(() => _saving = true);
    final changes = <String, dynamic>{
      'email_enabled': _enabled,
      'email_smtp_host': _hostCtrl.text.trim(),
      'email_smtp_port': port,
      'email_use_ssl': _useSsl,
      'email_username': _userCtrl.text.trim(),
      'email_from': _fromCtrl.text.trim(),
      'email_from_name': _fromNameCtrl.text.trim(),
      'app_base_url': _baseUrlCtrl.text.trim(),
    };
    // Only send the password when the admin typed a new one.
    if (_passCtrl.text.isNotEmpty) {
      changes['email_password'] = _passCtrl.text;
    }
    try {
      final cfg = await context.read<StaffService>().updateEmailConfig(changes);
      if (!mounted) return;
      setState(() {
        _passwordSet = (cfg['password_set'] as bool?) ?? _passwordSet;
        _passCtrl.clear();
        _saving = false;
      });
      _snack('Email settings saved.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Could not save email settings.');
    }
  }

  Future<void> _sendTest() async {
    final to = _testCtrl.text.trim();
    if (to.isEmpty || !to.contains('@')) {
      _snack('Enter a recipient email address.');
      return;
    }
    setState(() => _testing = true);
    try {
      final (ok, detail) = await context.read<StaffService>().sendTestEmail(to);
      if (!mounted) return;
      setState(() => _testing = false);
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(ok ? Icons.check_circle : Icons.error_outline,
              color: ok ? const Color(0xFF2E7D43) : const Color(0xFFB3261E),
              size: 32),
          title: Text(ok ? 'Test email sent' : 'Test failed'),
          content: Text(detail),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _testing = false);
      _snack('Could not send test email.');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: const Text('Email')),
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
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _card(
                cs,
                title: 'Sending',
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Email sending enabled'),
                    subtitle: const Text(
                        'When off, the app never sends mail (links are logged '
                        'only). Turn on after a test succeeds.'),
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _card(
                cs,
                title: 'SMTP server',
                children: [
                  TextField(
                    controller: _hostCtrl,
                    decoration: const InputDecoration(
                      labelText: 'SMTP host',
                      hintText: 'smtp.bizmail.yahoo.com',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _portCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Port'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<bool>(
                          initialValue: _useSsl,
                          isExpanded: true,
                          decoration:
                              const InputDecoration(labelText: 'Security'),
                          items: const [
                            DropdownMenuItem(
                                value: true, child: Text('SSL (port 465)')),
                            DropdownMenuItem(
                                value: false,
                                child: Text('STARTTLS (port 587)')),
                          ],
                          onChanged: (v) => setState(() {
                            _useSsl = v ?? true;
                            // Nudge the port to the usual default for the mode
                            // if it still holds the other mode's default.
                            if (_useSsl && _portCtrl.text.trim() == '587') {
                              _portCtrl.text = '465';
                            } else if (!_useSsl &&
                                _portCtrl.text.trim() == '465') {
                              _portCtrl.text = '587';
                            }
                          }),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _card(
                cs,
                title: 'Credentials & sender',
                children: [
                  TextField(
                    controller: _userCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      hintText: 'noreply@yourcompany.com',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password / app password',
                      hintText: _passwordSet
                          ? 'Saved — leave blank to keep'
                          : 'Not set',
                      helperText:
                          'Yahoo / Turbify: use an app-specific password.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _fromCtrl,
                    decoration: const InputDecoration(
                      labelText: 'From address',
                      hintText: 'noreply@yourcompany.com',
                      helperText: 'Must be a real mailbox on your domain.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _fromNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'From name',
                      hintText: 'Staff Portal',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _baseUrlCtrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Public site URL (for links in emails)',
                      hintText: 'https://gbgstaff.atmix.io',
                      helperText:
                          'Used to build password-reset links. Leave blank to '
                          'derive from the request.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: const Text('Save settings'),
                ),
              ),
              const SizedBox(height: 16),
              _card(
                cs,
                title: 'Send a test email',
                children: [
                  const Text(
                      'Sends using the settings above (Save first). Works even '
                      'while sending is off, so you can verify before going live.',
                      style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _testCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Send to',
                            hintText: 'you@example.com',
                          ),
                          onSubmitted: (_) => _testing ? null : _sendTest(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.tonalIcon(
                        onPressed: _testing ? null : _sendTest,
                        icon: _testing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send_outlined),
                        label: const Text('Send'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Turbify (Yahoo business mail): host smtp.bizmail.yahoo.com, '
                'port 465 (SSL). Confirm the exact host/port in your Turbify '
                'control panel.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(ColorScheme cs,
      {required String title, required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

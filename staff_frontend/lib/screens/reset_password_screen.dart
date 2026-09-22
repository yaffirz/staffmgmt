import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/staff_service.dart';
import '../widgets/app_scaffold.dart';

/// Reached via a timed link from a reset email (`/?reset_token=…`). Validates the
/// token, then lets the user set a new password. Not part of the signed-in app —
/// the token is the only thing that authorises this one action.
class ResetPasswordScreen extends StatefulWidget {
  final String token;

  /// Called when the user is done (success or gives up) so the app can drop the
  /// token and return to the login screen.
  final VoidCallback onDone;

  const ResetPasswordScreen(
      {super.key, required this.token, required this.onDone});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _checking = true;
  bool _valid = false;
  bool _busy = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _validate();
  }

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _validate() async {
    try {
      final ok =
          await context.read<StaffService>().validateResetToken(widget.token);
      if (!mounted) return;
      setState(() {
        _valid = ok;
        _checking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _valid = false;
        _checking = false;
      });
    }
  }

  Future<void> _submit() async {
    final p = _passCtrl.text;
    final c = _confirmCtrl.text;
    if (p.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (p != c) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<StaffService>().resetPassword(widget.token, p);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _done = true;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not reset your password. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Set a new password'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_checking) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_done) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.check_circle_outline, size: 44, color: cs.primary),
          const SizedBox(height: 16),
          const Text('Password updated',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('You can now sign in with your new password.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 24),
          FilledButton(onPressed: widget.onDone, child: const Text('Sign in')),
        ],
      );
    }
    if (!_valid) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.link_off, size: 44, color: cs.error),
          const SizedBox(height: 16),
          const Text('Link expired or invalid',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'This reset link is no longer valid. Request a new one from the '
            'sign-in screen.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FilledButton(
              onPressed: widget.onDone, child: const Text('Back to sign in')),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Set a new password',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        TextField(
          controller: _passCtrl,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: 'New password',
            helperText: 'At least 6 characters',
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmCtrl,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _busy ? null : _submit(),
          decoration: const InputDecoration(labelText: 'Confirm new password'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: cs.error, fontSize: 13)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: Colors.white))
              : const Text('Reset password'),
        ),
        const SizedBox(height: 8),
        TextButton(
            onPressed: widget.onDone, child: const Text('Back to sign in')),
      ],
    );
  }
}

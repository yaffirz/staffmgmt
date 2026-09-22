import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/staff_service.dart';
import '../widgets/app_scaffold.dart';

/// "Forgot password" — the user enters their username or email and we email a
/// timed reset link (if the account exists and receives email). The response is
/// always neutral so it never reveals which accounts exist.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final id = _ctrl.text.trim();
    if (id.isEmpty) return;
    setState(() => _busy = true);
    try {
      await context.read<StaffService>().forgotPassword(id);
    } catch (_) {
      // Neutral either way — never leak whether the account/email exists.
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _sent = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppScaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _sent
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.mark_email_read_outlined,
                          size: 44, color: cs.primary),
                      const SizedBox(height: 16),
                      const Text('Check your email',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(
                        'If an account with that username or email exists and '
                        'has email enabled, a password-reset link is on its way. '
                        'The link expires in 60 minutes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('Back to sign in'),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Reset your password',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(
                        'Enter your username or email. We\'ll send a reset link '
                        'to the email on file.',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _ctrl,
                        autofocus: true,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _busy ? null : _submit(),
                        decoration: const InputDecoration(
                            labelText: 'Username or email'),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.4, color: Colors.white))
                            : const Text('Send reset link'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('Back to sign in'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

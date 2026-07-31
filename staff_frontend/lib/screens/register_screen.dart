import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/staff_service.dart';
import '../widgets/app_logo.dart';
import '../widgets/app_scaffold.dart';

/// Public self-service sign-up. Submits a registration request; the account only
/// becomes real after email confirmation + admin approval.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  final _note = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;
  String? _done;

  @override
  void dispose() {
    _user.dispose();
    _email.dispose();
    _pass.dispose();
    _confirm.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final msg = await context.read<StaffService>().register(
            username: _user.text.trim(),
            email: _email.text.trim(),
            password: _pass.text,
            note: _note.text,
          );
      if (!mounted) return;
      setState(() {
        _done = msg;
        _busy = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not submit. Check your connection and try again.';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: const Text('Create an account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _done != null ? _success() : _form(),
          ),
        ),
      ),
    );
  }

  Widget _success() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24),
        Icon(Icons.mark_email_read_outlined, size: 56, color: cs.primary),
        const SizedBox(height: 16),
        Text('Almost there',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(_done!, textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.5)),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back to sign in'),
        ),
      ],
    );
  }

  Widget _form() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          const Center(child: AppLogo(size: 40)),
          const SizedBox(height: 20),
          Text('Create an account',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Submit your details. You will confirm your email, then an '
            'administrator reviews and activates your account.',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _user,
            decoration: const InputDecoration(labelText: 'Username'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter a username' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: (v) => (v == null ||
                    !v.contains('@') ||
                    !v.contains('.'))
                ? 'Enter a valid email'
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _pass,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Password',
              helperText: 'At least 6 characters',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) =>
                (v == null || v.length < 6) ? 'At least 6 characters' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirm,
            obscureText: _obscure,
            decoration: const InputDecoration(labelText: 'Confirm password'),
            validator: (v) => (v != _pass.text) ? 'Passwords do not match' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _note,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Note for the admin (optional)',
              hintText: 'e.g. I manage the Chaguanas store',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error, fontSize: 13.5)),
          ],
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white))
                : const Text('Submit'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to sign in'),
          ),
        ],
      ),
    );
  }
}

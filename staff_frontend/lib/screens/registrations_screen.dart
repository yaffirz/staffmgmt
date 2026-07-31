import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/directory.dart';
import '../models/registration_request.dart';
import '../services/api_client.dart';
import '../services/staff_service.dart';
import '../widgets/app_scaffold.dart';

const _approvalRoles = [
  'HR',
  'Area Manager',
  'IT',
  'Store',
  'Foodmall',
  'Admin',
  'Super Admin',
];

/// Admin queue for self-service sign-ups: confirm email (while sending is
/// stubbed), approve with an assigned role, or reject.
class RegistrationsScreen extends StatefulWidget {
  const RegistrationsScreen({super.key});

  @override
  State<RegistrationsScreen> createState() => _RegistrationsScreenState();
}

class _RegistrationsScreenState extends State<RegistrationsScreen> {
  bool _loading = true;
  String? _error;
  List<RegistrationRequest> _items = [];
  List<Store> _stores = [];
  List<Brand> _brands = [];

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
      final results = await Future.wait(
          [svc.registrations(), svc.stores(), svc.brands()]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<RegistrationRequest>;
        _stores = results[1] as List<Store>;
        _brands = results[2] as List<Brand>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load registrations.';
        _loading = false;
      });
    }
  }

  Future<void> _confirmEmail(RegistrationRequest r) async {
    if (r.confirmPath == null) return;
    try {
      await context.read<StaffService>().confirmRegistrationEmail(r.confirmPath!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email marked confirmed.')),
      );
      _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not confirm the email.')),
      );
    }
  }

  Future<void> _reject(RegistrationRequest r) async {
    try {
      await context.read<StaffService>().rejectRegistration(r.id);
      if (!mounted) return;
      _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not reject.')),
      );
    }
  }

  Future<void> _approve(RegistrationRequest r) async {
    String role = 'HR';
    int? storeId;
    final Set<int> brandIds = {};
    String? errorText;
    bool isStoreRole(String x) => x == 'Store' || x == 'Foodmall';

    final done = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Future<void> submit() async {
            if (isStoreRole(role) && storeId == null) {
              setLocal(() => errorText = 'Choose a store');
              return;
            }
            try {
              await ctx.read<StaffService>().approveRegistration(
                    r.id,
                    role: role,
                    storeId: isStoreRole(role) ? storeId : null,
                    brandIds: role == 'Area Manager' ? brandIds.toList() : null,
                  );
              if (ctx.mounted) Navigator.pop(ctx, true);
            } on ApiException catch (e) {
              setLocal(() => errorText = e.message);
            } catch (_) {
              setLocal(() => errorText = 'Could not approve.');
            }
          }

          final foodmallOnly = role == 'Foodmall';
          final storeOpts = foodmallOnly
              ? _stores.where((s) => s.isFoodmall).toList()
              : _stores;

          return AlertDialog(
            title: Text('Approve ${r.username}'),
            content: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(r.email,
                        style: TextStyle(
                            color:
                                Theme.of(ctx).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'Assign role'),
                      items: _approvalRoles
                          .map((x) =>
                              DropdownMenuItem(value: x, child: Text(x)))
                          .toList(),
                      onChanged: (v) => setLocal(() {
                        role = v ?? role;
                        if (role == 'Foodmall' &&
                            storeId != null &&
                            !_stores.any(
                                (s) => s.id == storeId && s.isFoodmall)) {
                          storeId = null;
                        }
                      }),
                    ),
                    if (isStoreRole(role)) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        key: ValueKey('reg-store-$role'),
                        initialValue:
                            storeOpts.any((s) => s.id == storeId) ? storeId : null,
                        isExpanded: true,
                        decoration: InputDecoration(
                            labelText:
                                foodmallOnly ? 'Foodmall store' : 'Store'),
                        items: storeOpts
                            .map((s) => DropdownMenuItem(
                                value: s.id,
                                child: Text(s.name,
                                    overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (v) => setLocal(() => storeId = v),
                      ),
                    ],
                    if (role == 'Area Manager') ...[
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Brands covered',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final b in _brands)
                            FilterChip(
                              label: Text(b.name),
                              selected: brandIds.contains(b.id),
                              onSelected: (on) => setLocal(() {
                                if (on) {
                                  brandIds.add(b.id);
                                } else {
                                  brandIds.remove(b.id);
                                }
                              }),
                            ),
                        ],
                      ),
                    ],
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Text(errorText!,
                          style: TextStyle(
                              color: Theme.of(ctx).colorScheme.error,
                              fontSize: 13)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(onPressed: submit, child: const Text('Approve')),
            ],
          );
        },
      ),
    );
    if (done == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created.')),
        );
      }
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Registrations'),
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
    if (_items.isEmpty) {
      return Center(
        child: Text('No registrations yet.',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final r in _items) _card(r)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(RegistrationRequest r) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canApprove = r.status == 'pending_approval';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.username,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(r.email,
                        style: TextStyle(
                            fontSize: 12.5, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              _statusChip(r, cs),
            ],
          ),
          if (r.note != null && r.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('“${r.note!.trim()}”',
                style: TextStyle(
                    fontStyle: FontStyle.italic, color: cs.onSurfaceVariant)),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                r.emailVerified ? Icons.check_circle : Icons.mark_email_unread,
                size: 15,
                color: r.emailVerified ? const Color(0xFF2E7D43) : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(r.emailVerified ? 'Email confirmed' : 'Email not confirmed',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
          if (r.isPending) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!r.emailVerified && r.confirmPath != null)
                  OutlinedButton.icon(
                    onPressed: () => _confirmEmail(r),
                    icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                    label: const Text('Confirm email'),
                  ),
                FilledButton.icon(
                  onPressed: canApprove ? () => _approve(r) : null,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Approve'),
                ),
                TextButton.icon(
                  onPressed: () => _reject(r),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Reject'),
                ),
              ],
            ),
            if (!canApprove)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Email must be confirmed before approval.',
                    style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
              ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(RegistrationRequest r, ColorScheme cs) {
    final (label, color) = switch (r.status) {
      'pending_email' => ('Awaiting email', const Color(0xFF8A6D3B)),
      'pending_approval' => ('Awaiting approval', const Color(0xFF1565C0)),
      'approved' => ('Approved', const Color(0xFF2E7D43)),
      'rejected' => ('Rejected', const Color(0xFFB3261E)),
      _ => (r.status, cs.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }
}

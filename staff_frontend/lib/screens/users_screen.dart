import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/directory.dart';
import '../models/user_account.dart';
import '../services/api_client.dart';
import '../services/staff_service.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';

const _roles = ['Super Admin', 'Admin', 'HR', 'Area Manager'];

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<UserAccount> _users = [];
  List<Brand> _brands = [];
  bool _loading = true;
  String? _error;
  int? _myId;

  @override
  void initState() {
    super.initState();
    _myId = context.read<AuthProvider>().user?.userId;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = context.read<StaffService>();
      final results = await Future.wait([svc.users(), svc.brands()]);
      if (!mounted) return;
      setState(() {
        _users = results[0] as List<UserAccount>;
        _brands = results[1] as List<Brand>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load users.';
        _loading = false;
      });
    }
  }

  String _brandName(int id) {
    for (final b in _brands) {
      if (b.id == id) return b.name;
    }
    return 'Brand $id';
  }

  Future<List<int>?> _pickBrands(List<int> current) async {
    final selected = {...current};
    return showDialog<List<int>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Brands covered'),
          content: SizedBox(
            width: 360,
            child: _brands.isEmpty
                ? const Text('No brands exist yet.')
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _brands.map((b) {
                        final on = selected.contains(b.id);
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: on,
                          title: Text(b.name),
                          onChanged: (v) => setLocal(() {
                            if (v == true) {
                              selected.add(b.id);
                            } else {
                              selected.remove(b.id);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, selected.toList()),
                child: const Text('Done')),
          ],
        ),
      ),
    );
  }

  Future<void> _openForm({UserAccount? editing}) async {
    final isEdit = editing != null;
    final isSelf = isEdit && editing.userId == _myId;
    final userCtrl = TextEditingController(text: editing?.username ?? '');
    final emailCtrl = TextEditingController(text: editing?.email ?? '');
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String role = editing?.role ?? 'Area Manager';
    List<int> brandIds = [...(editing?.brandIds ?? const [])];
    String? errorText;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Future<void> submit() async {
            final u = userCtrl.text.trim();
            final em = emailCtrl.text.trim();
            final p = passCtrl.text;
            final cp = confirmCtrl.text;

            if (u.isEmpty) {
              setLocal(() => errorText = 'Username is required');
              return;
            }
            if (!em.contains('@') || !em.contains('.')) {
              setLocal(() => errorText = 'A valid email is required');
              return;
            }
            // Password rules: required on create, optional on edit.
            if (!isEdit || p.isNotEmpty) {
              if (p.length < 6) {
                setLocal(() => errorText = 'Password must be 6+ characters');
                return;
              }
              if (p != cp) {
                setLocal(() => errorText = 'Passwords do not match');
                return;
              }
            }
            try {
              final svc = ctx.read<StaffService>();
              if (isEdit) {
                await svc.updateUser(
                  editing.userId,
                  username: u != editing.username ? u : null,
                  email: em != editing.email ? em : null,
                  role: (!isSelf && role != editing.role) ? role : null,
                  password: p.isNotEmpty ? p : null,
                  brandIds: role == 'Area Manager' ? brandIds : null,
                );
              } else {
                await svc.createUser(
                  u,
                  em,
                  p,
                  role,
                  brandIds: role == 'Area Manager' ? brandIds : null,
                );
              }
              if (ctx.mounted) Navigator.pop(ctx, true);
            } on ApiException catch (e) {
              setLocal(() => errorText = e.message);
            } catch (_) {
              setLocal(() => errorText = 'Could not save user.');
            }
          }

          return AlertDialog(
            title: Text(isEdit ? editing.username : 'Add user'),
            content: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: userCtrl,
                      decoration: const InputDecoration(labelText: 'Username'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: isEdit ? 'Reset password' : 'Password',
                        helperText: isEdit
                            ? 'Leave blank to keep current'
                            : 'At least 6 characters',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                          labelText: 'Confirm password'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Role',
                        helperText: isSelf
                            ? 'You cannot change your own role'
                            : null,
                      ),
                      items: _roles
                          .map((r) =>
                              DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: isSelf
                          ? null
                          : (v) => setLocal(() => role = v ?? role),
                    ),
                    if (role == 'Area Manager') ...[
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Brands covered',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                      ),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await _pickBrands(brandIds);
                          if (picked != null) {
                            setLocal(() => brandIds = picked);
                          }
                        },
                        icon: const Icon(Icons.storefront_outlined, size: 18),
                        label: Text(brandIds.isEmpty
                            ? 'Select brands'
                            : '${brandIds.length} brand(s) selected'),
                      ),
                      if (brandIds.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: brandIds
                              .map((id) => Chip(
                                    label: Text(_brandName(id),
                                        style: const TextStyle(fontSize: 12)),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ))
                              .toList(),
                        ),
                      ],
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
                child: const Text('Cancel'),
              ),
              FilledButton(
                  onPressed: submit,
                  child: Text(isEdit ? 'Save' : 'Create')),
            ],
          );
        },
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _deleteUser(UserAccount u) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${u.username}?'),
        content: const Text(
            'This removes the login account. Any brand assignments are '
            'cleared. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB3261E)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await context.read<StaffService>().deleteUser(u.userId);
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete user.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Users & Roles'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
          IconButton(
            tooltip: 'Add user',
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: () => _openForm(),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _buildBody(),
    );
  }

  Color _roleColor(String role, ColorScheme cs) {
    switch (role) {
      case 'Super Admin':
        return const Color(0xFF6A1B9A);
      case 'Admin':
        return const Color(0xFF1565C0);
      case 'HR':
        return const Color(0xFF2E7D43);
      case 'Area Manager':
        return const Color(0xFFB26A00);
      default:
        return cs.onSurfaceVariant;
    }
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

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          for (final r in _roles)
            ..._sectionFor(r),
        ],
      ),
    );
  }

  List<Widget> _sectionFor(String role) {
    final inRole = _users.where((u) => u.role == role).toList();
    if (inRole.isEmpty) return const [];
    final cs = Theme.of(context).colorScheme;
    final rc = _roleColor(role, cs);
    return [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: rc, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  '$role  (${inRole.length})',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
      ...inRole.map(_userCard),
      const SizedBox(height: 8),
    ];
  }

  Widget _userCard(UserAccount u) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelf = u.userId == _myId;
    final rc = _roleColor(u.role, cs);
    final isAm = u.role == 'Area Manager';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: isDark ? cs.surfaceContainerHigh : Colors.white,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openForm(editing: u),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isDark ? cs.outlineVariant : AppColors.line),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(Icons.account_circle_outlined,
                          color: cs.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  u.username,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isSelf) ...[
                                const SizedBox(width: 8),
                                Text('(you)',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurfaceVariant)),
                              ],
                            ],
                          ),
                          if (u.email != null && u.email!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(u.email!,
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: cs.onSurfaceVariant)),
                          ],
                          if (isAm) ...[
                            const SizedBox(height: 6),
                            u.brandNames.isEmpty
                                ? Text('No brands assigned',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: cs.error))
                                : Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: u.brandNames
                                        .map((n) => Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                color: cs.surfaceContainerHighest,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(n,
                                                  style: const TextStyle(
                                                      fontSize: 11.5)),
                                            ))
                                        .toList(),
                                  ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: rc.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(u.role,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: rc)),
                    ),
                    if (!isSelf) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Delete',
                        icon: Icon(Icons.delete_outline,
                            size: 20, color: cs.onSurfaceVariant),
                        onPressed: () => _deleteUser(u),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

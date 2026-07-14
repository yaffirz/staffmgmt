import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/directory.dart';
import '../models/staff_note.dart';
import '../models/staff_page.dart';
import '../services/api_client.dart';
import '../services/staff_service.dart';
import '../widgets/app_scaffold.dart';

/// Individual staff page: header details + notes with per-note visibility.
class EmployeeDetailScreen extends StatefulWidget {
  final int employeeId;
  final String? employeeName;

  const EmployeeDetailScreen({
    super.key,
    required this.employeeId,
    this.employeeName,
  });

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  bool _loading = true;
  String? _error;
  StaffPageEmployee? _employee;
  List<StaffNote> _notes = [];
  List<Brand> _allBrands = [];
  Set<int> _myBrandIds = {};

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
    final svc = context.read<StaffService>();
    try {
      final results = await Future.wait([
        svc.staffPage(widget.employeeId),
        svc.staffNotes(widget.employeeId),
        svc.brands(),
        svc.myBrands(),
      ]);
      if (!mounted) return;
      setState(() {
        _employee = results[0] as StaffPageEmployee;
        _notes = results[1] as List<StaffNote>;
        _allBrands = results[2] as List<Brand>;
        _myBrandIds = (results[3] as List<Brand>).map((b) => b.id).toSet();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load this staff member.';
        _loading = false;
      });
    }
  }

  Future<void> _reloadNotes() async {
    try {
      final notes = await context.read<StaffService>().staffNotes(widget.employeeId);
      if (mounted) setState(() => _notes = notes);
    } catch (_) {/* keep current */}
  }

  Future<void> _addNote() async {
    final result = await showDialog<_NoteDraft>(
      context: context,
      builder: (_) => _AddNoteDialog(
        allBrands: _allBrands,
        defaultBrandIds: _myBrandIds,
      ),
    );
    if (result == null) return;
    try {
      await context.read<StaffService>().createNote(
            widget.employeeId,
            text: result.text,
            roles: result.roles,
            brandIds: result.brandIds,
          );
      _snack('Note added.');
      _reloadNotes();
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Could not add the note.');
    }
  }

  Future<void> _deleteNote(StaffNote n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete note?'),
        content: const Text('This permanently removes the note.'),
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
    if (ok != true) return;
    try {
      await context.read<StaffService>().deleteNote(n.noteId);
      _snack('Note deleted.');
      _reloadNotes();
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Could not delete the note.');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: Text(_employee?.employeeName ?? widget.employeeName ?? 'Staff'),
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
    final e = _employee!;
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _headerCard(e, cs),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text('Notes',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _addNote,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add note'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_notes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('No notes you can see yet.',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                  ),
                )
              else
                for (final n in _notes) _noteCard(n, cs),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerCard(StaffPageEmployee e, ColorScheme cs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final line2 = [
      if (e.positionTitle != null) e.positionTitle!,
      if (e.storeName != null) e.storeName!,
      if (e.brandName != null) e.brandName!,
    ].join('  ·  ');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(e.employeeName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          SelectableText('Payroll ${e.payrollId}',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          if (line2.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(line2, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }

  Widget _noteCard(StaffNote n, ColorScheme cs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: SelectableText(n.noteText)),
              if (n.canEdit)
                IconButton(
                  tooltip: 'Delete note',
                  icon: const Icon(Icons.delete_outline, size: 18),
                  color: const Color(0xFFB3261E),
                  onPressed: () => _deleteNote(n),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              _visChip(n, cs),
              Text('${n.authorName}  ·  ${n.createdDisplay}',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _visChip(StaffNote n, ColorScheme cs) {
    final private = n.isPrivate;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: private ? cs.surfaceContainerHighest : cs.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(private ? Icons.lock_outline : Icons.visibility_outlined,
              size: 12,
              color: private ? cs.onSurfaceVariant : cs.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(n.visibilityLabel,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color:
                      private ? cs.onSurfaceVariant : cs.onSecondaryContainer)),
        ],
      ),
    );
  }
}

/// Result of the add-note dialog.
class _NoteDraft {
  final String text;
  final List<String> roles;
  final List<int> brandIds;
  const _NoteDraft(this.text, this.roles, this.brandIds);
}

enum _Audience { private, roles, brands }

/// Compose a note and choose its audience.
class _AddNoteDialog extends StatefulWidget {
  final List<Brand> allBrands;
  final Set<int> defaultBrandIds;
  const _AddNoteDialog({required this.allBrands, required this.defaultBrandIds});

  @override
  State<_AddNoteDialog> createState() => _AddNoteDialogState();
}

class _AddNoteDialogState extends State<_AddNoteDialog> {
  static const _shareableRoles = ['Area Manager', 'HR', 'Admin'];

  final _textCtrl = TextEditingController();
  _Audience _audience = _Audience.private;
  final Set<String> _roles = {};
  late Set<int> _brandIds;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Default the brand picker to the author's own brand(s).
    _brandIds = {...widget.defaultBrandIds};
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Please write a note.');
      return;
    }
    final roles = _audience == _Audience.roles ? _roles.toList() : <String>[];
    final brands = _audience == _Audience.brands ? _brandIds.toList() : <int>[];
    if (_audience == _Audience.roles && roles.isEmpty) {
      setState(() => _error = 'Pick at least one role, or choose Private.');
      return;
    }
    if (_audience == _Audience.brands && brands.isEmpty) {
      setState(() => _error = 'Pick at least one brand, or choose Private.');
      return;
    }
    Navigator.of(context).pop(_NoteDraft(text, roles, brands));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Add note'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _textCtrl,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              Text('Who can see this?',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: cs.onSurface)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Private'),
                    selected: _audience == _Audience.private,
                    onSelected: (_) =>
                        setState(() => _audience = _Audience.private),
                  ),
                  ChoiceChip(
                    label: const Text('Roles'),
                    selected: _audience == _Audience.roles,
                    onSelected: (_) =>
                        setState(() => _audience = _Audience.roles),
                  ),
                  ChoiceChip(
                    label: const Text('Brands'),
                    selected: _audience == _Audience.brands,
                    onSelected: (_) =>
                        setState(() => _audience = _Audience.brands),
                  ),
                ],
              ),
              if (_audience == _Audience.private)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Only you and a Super Admin can see this note.',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ),
              if (_audience == _Audience.roles) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final r in _shareableRoles)
                      FilterChip(
                        label: Text(r),
                        selected: _roles.contains(r),
                        onSelected: (sel) => setState(() {
                          sel ? _roles.add(r) : _roles.remove(r);
                        }),
                      ),
                  ],
                ),
              ],
              if (_audience == _Audience.brands) ...[
                const SizedBox(height: 8),
                if (widget.allBrands.isEmpty)
                  Text('No brands available.',
                      style:
                          TextStyle(fontSize: 12, color: cs.onSurfaceVariant))
                else
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final b in widget.allBrands)
                        FilterChip(
                          label: Text(b.name),
                          selected: _brandIds.contains(b.id),
                          onSelected: (sel) => setState(() {
                            sel ? _brandIds.add(b.id) : _brandIds.remove(b.id);
                          }),
                        ),
                    ],
                  ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: cs.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save note')),
      ],
    );
  }
}

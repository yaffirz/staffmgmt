import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/staff_note.dart';
import '../services/staff_service.dart';
import '../widgets/app_scaffold.dart';
import 'employee_detail_screen.dart';

/// "Staff Notes" feed: every note the current user is allowed to see, across all
/// staff, newest first. Each row links to that staffer's page.
class AllNotesScreen extends StatefulWidget {
  const AllNotesScreen({super.key});

  @override
  State<AllNotesScreen> createState() => _AllNotesScreenState();
}

class _AllNotesScreenState extends State<AllNotesScreen> {
  bool _loading = true;
  String? _error;
  List<StaffNote> _notes = [];

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
      final notes = await context.read<StaffService>().allStaffNotes();
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load notes.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Staff Notes'),
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
    if (_notes.isEmpty) {
      return Center(
        child: Text('No notes you can see yet.',
            style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [for (final n in _notes) _noteCard(n, cs)],
          ),
        ),
      ),
    );
  }

  Widget _noteCard(StaffNote n, ColorScheme cs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EmployeeDetailScreen(
            employeeId: n.employeeId,
            employeeName: n.employeeName,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
                  child: Text(n.employeeName ?? 'Staff',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
            const SizedBox(height: 4),
            Text(n.noteText),
            const SizedBox(height: 8),
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

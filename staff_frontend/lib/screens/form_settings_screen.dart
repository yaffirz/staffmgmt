import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/form_field_config.dart';
import '../services/staff_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';

/// Lists the forms that can be customised. For now: the new-hire form.
class FormSettingsScreen extends StatelessWidget {
  const FormSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppScaffold(
      appBar: AppBar(title: const Text('Form settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  color: isDark ? cs.surfaceContainerHigh : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const FormFieldsEditorScreen(
                          formKey: 'employee',
                          title: 'New hire form',
                        ),
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: isDark ? cs.outlineVariant : AppColors.line),
                      ),
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: cs.primary
                                  .withOpacity(isDark ? 0.18 : 0.08),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.person_add_alt_1_outlined,
                                color: cs.primary),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('New hire form',
                                    style: TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w600,
                                        color: cs.onSurface)),
                                const SizedBox(height: 2),
                                Text('Show/hide fields and set which are required',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: cs.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              color: cs.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Editor for a single form's field configuration.
class FormFieldsEditorScreen extends StatefulWidget {
  final String formKey;
  final String title;
  const FormFieldsEditorScreen({
    super.key,
    required this.formKey,
    required this.title,
  });

  @override
  State<FormFieldsEditorScreen> createState() => _FormFieldsEditorScreenState();
}

class _FormFieldsEditorScreenState extends State<FormFieldsEditorScreen> {
  List<FormFieldConfig> _fields = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

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
      final list =
          await context.read<StaffService>().formConfig(widget.formKey);
      if (!mounted) return;
      setState(() {
        _fields = List.of(list);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load form settings.';
        _loading = false;
      });
    }
  }

  void _setEnabled(int i, bool v) {
    setState(() {
      // Disabling a field also clears its required flag.
      _fields[i] = _fields[i].copyWith(
        enabled: v,
        required: v ? _fields[i].required : false,
      );
    });
  }

  void _setRequired(int i, bool v) {
    setState(() => _fields[i] = _fields[i].copyWith(required: v));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = await context
          .read<StaffService>()
          .updateFormConfig(widget.formKey, _fields);
      if (!mounted) return;
      setState(() {
        _fields = List.of(updated);
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Form settings saved')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Text('Save',
                        style: TextStyle(color: Colors.white)),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
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
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12, left: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Toggle whether each field appears and whether it must '
                        'be filled. Locked fields are essential and can’t be '
                        'changed.',
                        style: TextStyle(
                            fontSize: 13, color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
              // Column header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Row(
                  children: [
                    const Expanded(child: SizedBox()),
                    SizedBox(
                      width: 90,
                      child: Text('Shown',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurfaceVariant)),
                    ),
                    SizedBox(
                      width: 90,
                      child: Text('Required',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurfaceVariant)),
                    ),
                  ],
                ),
              ),
              ...List.generate(_fields.length, (i) => _row(i)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(int i) {
    final f = _fields[i];
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: isDark ? cs.outlineVariant : AppColors.line),
      ),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(f.label,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface)),
                ),
                if (f.locked) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.lock_outline,
                      size: 14, color: cs.onSurfaceVariant),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 90,
            child: Center(
              child: Switch(
                value: f.enabled,
                onChanged: f.locked ? null : (v) => _setEnabled(i, v),
              ),
            ),
          ),
          SizedBox(
            width: 90,
            child: Center(
              child: Switch(
                value: f.required,
                onChanged:
                    (f.locked || !f.enabled) ? null : (v) => _setRequired(i, v),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

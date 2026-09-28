import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/theme_provider.dart';
import '../state/view_prefs_provider.dart';
import '../widgets/app_scaffold.dart';

/// Per-user preferences, available to every signed-in user. Choices are saved on
/// this device (appearance + the employee-list layout).
class PreferencesScreen extends StatelessWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final views = context.watch<ViewPrefsProvider>();
    final cs = Theme.of(context).colorScheme;

    return AppScaffold(
      appBar: AppBar(title: const Text('Preferences')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Your preferences',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Saved on this device. Everyone can set their own.',
                    style: TextStyle(color: cs.onSurfaceVariant)),
                const SizedBox(height: 24),

                _card(
                  cs,
                  icon: Icons.brightness_6_outlined,
                  title: 'Appearance',
                  subtitle: 'Light, dark, or match your device.',
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode),
                          label: Text('Light')),
                      ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode),
                          label: Text('Dark')),
                      ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto),
                          label: Text('System')),
                    ],
                    selected: {theme.mode},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) =>
                        context.read<ThemeProvider>().setMode(s.first),
                  ),
                ),
                const SizedBox(height: 16),

                _card(
                  cs,
                  icon: Icons.dashboard_customize_outlined,
                  title: 'Employee list layout',
                  subtitle:
                      'Show staff as a data table or as cards (fits on screen).',
                  child: SegmentedButton<EmployeeListView>(
                    segments: const [
                      ButtonSegment(
                          value: EmployeeListView.table,
                          icon: Icon(Icons.table_rows),
                          label: Text('Table')),
                      ButtonSegment(
                          value: EmployeeListView.cards,
                          icon: Icon(Icons.view_agenda_outlined),
                          label: Text('Cards')),
                    ],
                    selected: {views.employeeView},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => context
                        .read<ViewPrefsProvider>()
                        .setEmployeeView(s.first),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(
    ColorScheme cs, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Builder(builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: BoxDecoration(
          color: isDark ? cs.surfaceContainerHigh : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: cs.primary),
                const SizedBox(width: 10),
                Text(title,
                    style: const TextStyle(
                        fontSize: 15.5, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 4),
            Text(subtitle,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            const SizedBox(height: 14),
            Align(alignment: Alignment.centerLeft, child: child),
          ],
        ),
      );
    });
  }
}

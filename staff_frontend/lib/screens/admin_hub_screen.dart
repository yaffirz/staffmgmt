import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_provider.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/module_card.dart';
import 'admin_backups_screen.dart';
import 'admin_console_screen.dart';
import 'announcements_screen.dart';
import 'audit_logs_screen.dart';
import 'form_settings_screen.dart';
import 'registrations_screen.dart';
import 'settings_screen.dart';
import 'users_screen.dart';

/// Admin hub: the config/admin tools gathered off the main dashboard.
/// Announcements + Backups are Super Admin only.
class AdminHubScreen extends StatelessWidget {
  const AdminHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isSuper = user?.hasRole('Super Admin') ?? false;

    final tiles = <Widget>[
      ModuleCard(
        icon: Icons.admin_panel_settings_outlined,
        title: 'Users & Roles',
        subtitle: 'App accounts and access',
        onTap: () => _go(context, const UsersScreen()),
      ),
      ModuleCard(
        icon: Icons.how_to_reg_outlined,
        title: 'Registrations',
        subtitle: 'Approve new sign-ups',
        onTap: () => _go(context, const RegistrationsScreen()),
      ),
      ModuleCard(
        icon: Icons.fact_check_outlined,
        title: 'Audit Logs',
        subtitle: 'Full change history',
        onTap: () => _go(context, const AuditLogsScreen()),
      ),
      ModuleCard(
        icon: Icons.terminal,
        title: 'Activity Console',
        subtitle: 'Live platform activity',
        onTap: () => _go(context, const AdminConsoleScreen()),
      ),
      ModuleCard(
        icon: Icons.tune,
        title: 'Form Settings',
        subtitle: 'Customise form fields',
        onTap: () => _go(context, const FormSettingsScreen()),
      ),
      ModuleCard(
        icon: Icons.settings_outlined,
        title: 'Settings',
        subtitle: 'Feature toggles',
        onTap: () => _go(context, const SettingsScreen()),
      ),
      if (isSuper)
        ModuleCard(
          icon: Icons.campaign_outlined,
          title: 'Announcements',
          subtitle: 'Broadcast to all users',
          onTap: () => _go(context, const AnnouncementsScreen()),
        ),
      if (isSuper)
        ModuleCard(
          icon: Icons.backup_outlined,
          title: 'Backups',
          subtitle: 'Back up & schedule the database',
          onTap: () => _go(context, const AdminBackupsScreen()),
        ),
    ];

    return AppScaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Administration',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Accounts, configuration, activity and backups.',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 24),
                Wrap(spacing: 16, runSpacing: 16, children: tiles),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _go(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

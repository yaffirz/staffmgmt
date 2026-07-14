import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_user.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/theme_toggle.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Staff Portal'),
        actions: [
          const ThemeToggle(),
          const SizedBox(width: 4),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${user.username}  ·  ${user.role}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _DashboardBody(user: user),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final AuthUser user;
  const _DashboardBody({required this.user});

  @override
  Widget build(BuildContext context) {
    final modules = _modulesFor(user.role);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome, ${user.username}',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Signed in as ${user.role}. The modules below are scoped to your role.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [for (final m in modules) _ModuleCard(module: m)],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Maps each role to the modules it will manage. These line up with the
  /// endpoint matrix; Steps 3 & 4 wire them to real screens.
  List<_Module> _modulesFor(String role) {
    switch (role) {
      case 'Super Admin':
      case 'Admin':
        return const [
          _Module('Employees', Icons.badge_outlined, 'Add, view and update staff'),
          _Module('Brands & Stores', Icons.storefront_outlined,
              'Organisation structure'),
          _Module('Users & Roles', Icons.admin_panel_settings_outlined,
              'App accounts and access'),
          _Module('Status Changes', Icons.swap_vert_circle_outlined,
              'Promote, demote, terminate'),
          _Module('Audit Logs', Icons.fact_check_outlined,
              'Full change history'),
          _Module('Notifications', Icons.notifications_none,
              'Area Manager alerts'),
        ];
      case 'HR':
        return const [
          _Module('New Hire', Icons.person_add_alt_1_outlined,
              'Data-entry wizard'),
          _Module('Employees', Icons.badge_outlined, 'View and update staff'),
          _Module('Status Changes', Icons.swap_vert_circle_outlined,
              'Promote, demote, terminate'),
          _Module('Staff Notes', Icons.sticky_note_2_outlined,
              'Performance logs'),
        ];
      case 'Area Manager':
        return const [
          _Module('My Cluster', Icons.hub_outlined,
              'Staff in your assigned stores'),
          _Module('Cross-store Assignments', Icons.alt_route_outlined,
              'Add staff to other stores'),
          _Module('Staff Notes', Icons.sticky_note_2_outlined,
              'Performance logs'),
        ];
      default:
        return const [
          _Module('Staff Notes', Icons.sticky_note_2_outlined,
              'Performance logs'),
        ];
    }
  }
}

class _Module {
  final String title;
  final IconData icon;
  final String subtitle;
  const _Module(this.title, this.icon, this.subtitle);
}

class _ModuleCard extends StatelessWidget {
  final _Module module;
  const _ModuleCard({required this.module});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? cs.surfaceContainerHigh : Colors.white;
    final borderColor = isDark ? cs.outlineVariant : AppColors.line;

    return SizedBox(
      width: 300,
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${module.title} — coming in a later step')),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(isDark ? 0.18 : 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(module.icon, color: cs.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        module.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        module.subtitle,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
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

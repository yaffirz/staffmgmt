import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_user.dart';
import '../state/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/notification_bell.dart';
import '../widgets/theme_toggle.dart';
import 'new_hire_wizard_screen.dart';
import 'employees_hub_screen.dart';
import 'form_settings_screen.dart';
import 'all_notes_screen.dart';
import 'brands_stores_hub_screen.dart';
import 'my_cluster_screen.dart';
import 'settings_screen.dart';
import 'status_feed_screen.dart';
import 'users_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Staff Portal'),
        actions: [
          const NotificationBell(),
          const SizedBox(width: 4),
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
    final modules = _modulesForRoles(user.effectiveRoles);

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
                'Signed in as ${user.effectiveRoles.join(', ')}. '
                'The modules below are scoped to your role.',
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

  /// Union of the modules for every role the user holds, deduped by title
  /// (first occurrence wins, keeping its destination).
  List<_Module> _modulesForRoles(List<String> roles) {
    final seen = <String>{};
    final out = <_Module>[];
    for (final role in roles) {
      for (final m in _modulesFor(role)) {
        if (seen.add(m.title)) out.add(m);
      }
    }
    return out;
  }

  /// Maps each role to the modules it will manage. These line up with the
  /// endpoint matrix; Steps 3 & 4 wire them to real screens.
  List<_Module> _modulesFor(String role) {
    switch (role) {
      case 'Super Admin':
      case 'Admin':
        return const [
          _Module('Employees', Icons.badge_outlined, 'Add, view and update staff',
              dest: _Dest.hub),
          _Module('Brands & Stores', Icons.storefront_outlined,
              'Organisation structure', dest: _Dest.brandsHub),
          _Module('Users & Roles', Icons.admin_panel_settings_outlined,
              'App accounts and access', dest: _Dest.users),
          _Module('Status Changes', Icons.swap_vert_circle_outlined,
              'Promote, demote, terminate',
              dest: _Dest.statusFeed),
          _Module('Audit Logs', Icons.fact_check_outlined,
              'Full change history'),
          _Module('Notifications', Icons.notifications_none,
              'Area Manager alerts'),
          _Module('Form Settings', Icons.tune,
              'Customise form fields',
              dest: _Dest.formSettings),
          _Module('Settings', Icons.settings_outlined,
              'Feature toggles',
              dest: _Dest.settings),
        ];
      case 'HR':
        return const [
          _Module('New Hire', Icons.person_add_alt_1_outlined,
              'Data-entry wizard',
              dest: _Dest.wizard),
          _Module('Employees', Icons.badge_outlined, 'View and update staff',
              dest: _Dest.hub),
          _Module('Status Changes', Icons.swap_vert_circle_outlined,
              'Promote, demote, terminate',
              dest: _Dest.statusFeed),
          _Module('Staff Notes', Icons.sticky_note_2_outlined,
              'Performance logs',
              dest: _Dest.allNotes),
        ];
      case 'Area Manager':
        return const [
          _Module('My Cluster', Icons.hub_outlined,
              'Staff in your assigned stores',
              dest: _Dest.myCluster),
          _Module('Cross-store Assignments', Icons.alt_route_outlined,
              'Add staff to other stores'),
          _Module('Staff Notes', Icons.sticky_note_2_outlined,
              'Performance logs',
              dest: _Dest.allNotes),
        ];
      case 'IT':
        return const [
          _Module('Employees', Icons.badge_outlined, 'View and update staff',
              dest: _Dest.hub),
          _Module('Staff Notes', Icons.sticky_note_2_outlined,
              'Provisioning & performance logs',
              dest: _Dest.allNotes),
        ];
      default:
        return const [
          _Module('Staff Notes', Icons.sticky_note_2_outlined,
              'Performance logs',
              dest: _Dest.allNotes),
        ];
    }
  }
}

enum _Dest {
  none,
  wizard,
  hub,
  formSettings,
  brandsHub,
  users,
  myCluster,
  settings,
  allNotes,
  statusFeed
}

class _Module {
  final String title;
  final IconData icon;
  final String subtitle;
  final _Dest dest;
  const _Module(this.title, this.icon, this.subtitle,
      {this.dest = _Dest.none});
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
            switch (module.dest) {
              case _Dest.wizard:
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NewHireWizardScreen(),
                  ),
                );
                break;
              case _Dest.hub:
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const EmployeesHubScreen(),
                  ),
                );
                break;
              case _Dest.formSettings:
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const FormSettingsScreen(),
                  ),
                );
                break;
              case _Dest.brandsHub:
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BrandsStoresHubScreen(),
                  ),
                );
                break;
              case _Dest.users:
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const UsersScreen(),
                  ),
                );
                break;
              case _Dest.myCluster:
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MyClusterScreen(),
                  ),
                );
                break;
              case _Dest.settings:
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
                break;
              case _Dest.allNotes:
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AllNotesScreen(),
                  ),
                );
                break;
              case _Dest.statusFeed:
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const StatusFeedScreen(),
                  ),
                );
                break;
              case _Dest.none:
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text('${module.title} — coming in a later step')),
                );
                break;
            }
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

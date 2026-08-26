import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_user.dart';
import '../state/auth_provider.dart';
import '../widgets/app_download_banner.dart';
import '../widgets/app_logo.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/module_card.dart';
import '../widgets/notification_bell.dart';
import '../widgets/theme_toggle.dart';
import 'admin_hub_screen.dart';
import 'all_notes_screen.dart';
import 'brands_stores_hub_screen.dart';
import 'cross_store_screen.dart';
import 'employees_hub_screen.dart';
import 'my_cluster_screen.dart';
import 'my_store_screen.dart';
import 'new_hire_wizard_screen.dart';
import 'status_feed_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;

    return AppScaffold(
      globalActions: false, // this bar already carries the global controls
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogo(size: 28),
            SizedBox(width: 10),
            Text('Staff Portal'),
          ],
        ),
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

void _open(BuildContext context, _Dest dest) {
  Widget? screen;
  switch (dest) {
    case _Dest.wizard:
      screen = const NewHireWizardScreen();
      break;
    case _Dest.hub:
      screen = const EmployeesHubScreen();
      break;
    case _Dest.brandsHub:
      screen = const BrandsStoresHubScreen();
      break;
    case _Dest.myCluster:
      screen = const MyClusterScreen();
      break;
    case _Dest.allNotes:
      screen = const AllNotesScreen();
      break;
    case _Dest.statusFeed:
      screen = const StatusFeedScreen();
      break;
    case _Dest.crossStore:
      screen = const CrossStoreScreen();
      break;
    case _Dest.myStore:
      screen = const MyStoreScreen();
      break;
    case _Dest.adminHub:
      screen = const AdminHubScreen();
      break;
    case _Dest.none:
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The bell (top right) now handles this.')),
      );
      return;
  }
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen!));
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
              const AppDownloadBanner(),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final m in modules)
                    ModuleCard(
                      icon: m.icon,
                      title: m.title,
                      subtitle: m.subtitle,
                      onTap: () => _open(context, m.dest),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

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

  /// Admin & Super Admin: operational tiles + the Admin hub (which holds the
  /// config/admin tools). Other roles get their own scoped set.
  static const List<_Module> _adminModules = [
    _Module('Employees', Icons.badge_outlined, 'Add, view and update staff',
        dest: _Dest.hub),
    _Module('Brands & Stores', Icons.storefront_outlined,
        'Organisation structure', dest: _Dest.brandsHub),
    _Module('Status Changes', Icons.swap_vert_circle_outlined,
        'Promote, demote, terminate', dest: _Dest.statusFeed),
    _Module('Notifications', Icons.notifications_none, 'Area Manager alerts'),
    _Module('Admin', Icons.shield_outlined,
        'Users, settings, console & backups', dest: _Dest.adminHub),
  ];

  List<_Module> _modulesFor(String role) {
    switch (role) {
      case 'Super Admin':
      case 'Admin':
        return _adminModules;
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
              'Add staff to other stores',
              dest: _Dest.crossStore),
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
      case 'Store':
        return const [
          _Module('My Store', Icons.store_outlined, 'Staff at your store',
              dest: _Dest.myStore),
        ];
      case 'Foodmall':
        return const [
          _Module('My Foodmall', Icons.storefront_outlined,
              'Staff across your foodmall brands',
              dest: _Dest.myStore),
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
  brandsHub,
  myCluster,
  allNotes,
  statusFeed,
  crossStore,
  myStore,
  adminHub,
}

class _Module {
  final String title;
  final IconData icon;
  final String subtitle;
  final _Dest dest;
  const _Module(this.title, this.icon, this.subtitle,
      {this.dest = _Dest.none});
}

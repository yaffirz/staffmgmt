import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';
import 'brands_list_screen.dart';
import 'org_child_list_screen.dart';

class BrandsStoresHubScreen extends StatelessWidget {
  const BrandsStoresHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: const Text('Brands & Stores')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HubTile(
                  icon: Icons.storefront_outlined,
                  title: 'Brands',
                  subtitle: 'The companies you operate',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BrandsListScreen()),
                  ),
                ),
                const SizedBox(height: 14),
                _HubTile(
                  icon: Icons.store_outlined,
                  title: 'Stores',
                  subtitle: 'Locations under each brand',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const OrgChildListScreen(kind: OrgChildKind.store),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _HubTile(
                  icon: Icons.badge_outlined,
                  title: 'Positions',
                  subtitle: 'Job roles under each brand',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const OrgChildListScreen(kind: OrgChildKind.position),
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

class _HubTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _HubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? cs.surfaceContainerHigh : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
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
                  color: cs.primary.withOpacity(isDark ? 0.18 : 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: cs.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 13, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

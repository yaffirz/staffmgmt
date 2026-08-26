import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_provider.dart';
import 'notification_bell.dart';
import 'theme_toggle.dart';

/// The always-available top-bar controls (notification bell, light/dark toggle,
/// log out). Shown on every signed-in page via [AppScaffold] so they aren't
/// stranded on the dashboard.
class GlobalBarActions extends StatelessWidget {
  const GlobalBarActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const NotificationBell(),
        const SizedBox(width: 4),
        const ThemeToggle(),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Log out',
          icon: const Icon(Icons.logout),
          onPressed: () => context.read<AuthProvider>().logout(),
        ),
        const SizedBox(width: 6),
      ],
    );
  }
}

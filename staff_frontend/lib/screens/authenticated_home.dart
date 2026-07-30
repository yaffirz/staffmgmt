import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_notification.dart';
import '../services/staff_service.dart';
import 'dashboard_screen.dart';

/// The authenticated landing shell. Beyond rendering the dashboard, it checks
/// once (right after login/auto-login) for any unread *popup* announcements and
/// shows them as one-time dialogs, marking each read so it never reappears.
class AuthenticatedHome extends StatefulWidget {
  const AuthenticatedHome({super.key});

  @override
  State<AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends State<AuthenticatedHome> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showPopups());
  }

  Future<void> _showPopups() async {
    if (_checked) return;
    _checked = true;
    final svc = context.read<StaffService>();
    List<AppNotification> items;
    try {
      items = await svc.popupAnnouncements();
    } catch (_) {
      return; // never let a popup fetch failure block the app
    }
    for (final n in items) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.campaign_outlined,
              color: Theme.of(ctx).colorScheme.primary),
          title: Text(n.title),
          content: Text(n.body),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
      // Dismissal == read; keeps it out of the popup queue (and the bell badge).
      try {
        await svc.markNotificationRead(n.id);
      } catch (_) {
        // Non-fatal: worst case it shows again next session.
      }
    }
  }

  @override
  Widget build(BuildContext context) => const DashboardScreen();
}

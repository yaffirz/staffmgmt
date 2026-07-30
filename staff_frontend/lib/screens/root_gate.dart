import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_user.dart';
import '../state/auth_provider.dart';
import '../state/maintenance_provider.dart';
import '../state/server_provider.dart';
import '../widgets/app_scaffold.dart';
import 'authenticated_home.dart';
import 'login_screen.dart';
import 'maintenance_screen.dart';
import 'server_setup_screen.dart';

/// Routing core. Layers, in order:
///   1. Server configured?  -> if not, show the connection screen.
///   2. Auto-login attempt   -> restore a session once the server is known.
///   3. Auth state           -> splash / login / home.
///   4. Maintenance gate     -> non-exempt roles see the maintenance page.
///
/// Back-office roles keep working during maintenance; field roles are blocked.
const _maintenanceExemptRoles = {'Super Admin', 'Admin', 'IT'};

bool _isExempt(AuthUser user) =>
    user.effectiveRoles.any(_maintenanceExemptRoles.contains);
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  bool _autoLoginStarted = false;

  @override
  Widget build(BuildContext context) {
    final server = context.watch<ServerProvider>();

    if (server.status == ServerStatus.loading) {
      return const _Splash();
    }
    if (server.status == ServerStatus.unconfigured) {
      // Reset so reconfiguring the server re-runs auto-login afterwards.
      _autoLoginStarted = false;
      return const ServerSetupScreen();
    }

    // Server is configured — kick off the one-time auto-login.
    if (!_autoLoginStarted) {
      _autoLoginStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<AuthProvider>().tryAutoLogin();
      });
    }

    final auth = context.watch<AuthProvider>();
    if (auth.status == AuthStatus.authenticated) {
      final user = auth.user;
      final maintenance = context.watch<MaintenanceProvider>();
      if (maintenance.active && user != null && !_isExempt(user)) {
        return const MaintenanceScreen();
      }
      return const AuthenticatedHome();
    }
    if (auth.status == AuthStatus.unknown) {
      return const _Splash();
    }
    return const LoginScreen();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

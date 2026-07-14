import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_provider.dart';
import '../widgets/app_scaffold.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

/// Decides which screen to show based on auth state. This is the routing core:
/// auth state is the single source of truth, so there's no way to land on a
/// dashboard without a valid session.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthProvider>().status;

    if (status == AuthStatus.authenticated) {
      return const DashboardScreen();
    }
    if (status == AuthStatus.unknown) {
      return const _Splash(); // initial auto-login check
    }
    // unauthenticated OR authenticating -> login screen (button shows spinner)
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

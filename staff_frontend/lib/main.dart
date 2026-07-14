import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/root_gate.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/server_config_store.dart';
import 'services/staff_service.dart';
import 'services/token_store.dart';
import 'state/auth_provider.dart';
import 'state/server_provider.dart';
import 'state/theme_provider.dart';
import 'theme/app_theme.dart';

void main() {
  // Compose the dependency chain once.
  // ServerConfigStore -> ApiClient (resolves base URL per request)
  // TokenStore -> ApiClient (attaches JWT)
  final tokenStore = TokenStore();
  final serverStore = ServerConfigStore();
  final apiClient = ApiClient(tokenStore, serverStore);
  final authService = AuthService(apiClient, tokenStore);
  final staffService = StaffService(apiClient);

  runApp(StaffPortalApp(
    authService: authService,
    serverStore: serverStore,
    staffService: staffService,
  ));
}

class StaffPortalApp extends StatelessWidget {
  final AuthService authService;
  final ServerConfigStore serverStore;
  final StaffService staffService;
  const StaffPortalApp({
    super.key,
    required this.authService,
    required this.serverStore,
    required this.staffService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ServerProvider(serverStore)),
        // Auto-login is triggered by RootGate once a server is configured,
        // not here — it needs the server URL to be known first.
        ChangeNotifierProvider(create: (_) => AuthProvider(authService)),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        Provider<StaffService>.value(value: staffService),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          title: 'Staff Portal',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeProvider.mode,
          home: const RootGate(),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/root_gate.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/token_store.dart';
import 'state/auth_provider.dart';
import 'state/theme_provider.dart';
import 'theme/app_theme.dart';

void main() {
  // Compose the dependency chain once: TokenStore -> ApiClient -> AuthService.
  final tokenStore = TokenStore();
  final apiClient = ApiClient(tokenStore);
  final authService = AuthService(apiClient, tokenStore);

  runApp(StaffPortalApp(authService: authService));
}

class StaffPortalApp extends StatelessWidget {
  final AuthService authService;
  const StaffPortalApp({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authService)..tryAutoLogin(),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
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

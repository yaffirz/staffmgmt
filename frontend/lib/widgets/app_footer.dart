import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/app_theme.dart';

/// The permanent credit footer. Rendered by [AppScaffold] on every page so it
/// is always visible, pinned to the bottom, on both web and mobile.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.ink,
        border: Border(top: BorderSide(color: AppColors.tealMid)),
      ),
      child: Text(
        'Created by ${AppConfig.appCreator}   •   \u00A9 $year',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12.5,
          letterSpacing: 0.3,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

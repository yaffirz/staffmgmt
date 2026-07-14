import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/theme_provider.dart';
import '../theme/app_theme.dart';

/// A switch for the app bar that flips between light and dark mode. The thumb
/// shows a sun (light) or moon (dark); colours are tuned to read on the teal bar.
class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;

    return Tooltip(
      message: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      child: Switch(
        value: isDark,
        onChanged: (v) => context.read<ThemeProvider>().setDark(v),
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.amber
              : Colors.white24,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.white30),
        thumbIcon: WidgetStateProperty.resolveWith(
          (states) => Icon(
            states.contains(WidgetState.selected)
                ? Icons.dark_mode
                : Icons.light_mode,
            color: AppColors.ink,
            size: 16,
          ),
        ),
      ),
    );
  }
}

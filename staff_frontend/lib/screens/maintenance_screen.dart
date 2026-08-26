import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_provider.dart';
import '../state/maintenance_provider.dart';
import '../widgets/app_scaffold.dart';

/// Full-screen page shown to non-exempt users while maintenance mode is on.
/// Lightweight built-in animations only (a slow-rotating gear + a pulsing halo)
/// — no external assets, to keep the web/APK payload small.
class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen>
    with TickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 6))
        ..repeat();
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat(reverse: true);
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Drives the live countdown once a second.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _spin.dispose();
    _pulse.dispose();
    _tick?.cancel();
    super.dispose();
  }

  String? _countdown(DateTime? until) {
    if (until == null) return null;
    final remaining = until.toLocal().difference(DateTime.now());
    if (remaining.isNegative) return null; // window has elapsed
    final h = remaining.inHours;
    final m = remaining.inMinutes % 60;
    final s = remaining.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maint = context.watch<MaintenanceProvider>();
    final message = maint.message.trim().isEmpty
        ? 'We’re making some improvements to the Staff Portal. '
            'Please check back shortly.'
        : maint.message.trim();
    final countdown = _countdown(maint.until);

    return AppScaffold(
      globalActions: false, // maintenance gate — keep it minimal
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Under maintenance'),
        actions: [
          TextButton.icon(
            onPressed: () => context.read<AuthProvider>().logout(),
            icon: const Icon(Icons.logout, color: Colors.white70, size: 18),
            label: const Text('Log out',
                style: TextStyle(color: Colors.white70)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AnimatedGear(spin: _spin, pulse: _pulse, color: cs.primary),
                const SizedBox(height: 32),
                Text(
                  'We’ll be right back',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15, color: cs.onSurfaceVariant, height: 1.4),
                ),
                if (countdown != null) ...[
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        Text('Estimated time remaining',
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Text(
                          countdown,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                TextButton.icon(
                  onPressed: () =>
                      context.read<MaintenanceProvider>().refresh(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Check again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedGear extends StatelessWidget {
  final AnimationController spin;
  final AnimationController pulse;
  final Color color;
  const _AnimatedGear(
      {required this.spin, required this.pulse, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing halo behind the gear.
          FadeTransition(
            opacity: Tween<double>(begin: 0.15, end: 0.4).animate(pulse),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.85, end: 1.15).animate(pulse),
              child: Container(
                width: 140,
                height: 140,
                decoration:
                    BoxDecoration(color: color.withOpacity(0.5), shape: BoxShape.circle),
              ),
            ),
          ),
          // Slowly rotating gear.
          RotationTransition(
            turns: spin,
            child: Icon(Icons.settings, size: 84, color: color),
          ),
        ],
      ),
    );
  }
}

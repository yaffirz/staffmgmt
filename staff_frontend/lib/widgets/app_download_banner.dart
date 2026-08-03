import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_info.dart';
import '../services/file_download.dart';
import '../services/staff_service.dart';
import '../theme/app_theme.dart';

/// A "Get the Android app" card for signed-in users. Renders nothing unless the
/// browser can download (web) and an APK has been published + enabled.
class AppDownloadBanner extends StatefulWidget {
  const AppDownloadBanner({super.key});

  @override
  State<AppDownloadBanner> createState() => _AppDownloadBannerState();
}

class _AppDownloadBannerState extends State<AppDownloadBanner> {
  AppInfo _info = AppInfo.none;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    if (downloadSupported) _load();
  }

  Future<void> _load() async {
    try {
      final info = await context.read<StaffService>().appInfo();
      if (mounted) setState(() => _info = info);
    } catch (_) {/* leave hidden */}
  }

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final bytes = await context.read<StaffService>().downloadApk();
      downloadBytes(_info.filename ?? 'staff-portal.apk', bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not download the app.')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!downloadSupported || !_info.available) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final meta = [
      if (_info.updatedLabel != null) 'Updated ${_info.updatedLabel}',
      if (_info.sizeLabel.isNotEmpty) _info.sizeLabel,
    ].join('  ·  ');

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? cs.surfaceContainerHigh : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? cs.outlineVariant : AppColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: isDark ? 0.18 : 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.android, color: cs.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Get the Android app',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: cs.onSurface)),
                const SizedBox(height: 2),
                Text(
                  meta.isEmpty
                      ? 'Install on your phone. Enable “install from unknown sources” if prompted.'
                      : '$meta  ·  enable “unknown sources” if prompted.',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _downloading ? null : _download,
            icon: _downloading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.download_outlined, size: 18),
            label: Text(_downloading ? 'Downloading…' : 'Download'),
          ),
        ],
      ),
    );
  }
}

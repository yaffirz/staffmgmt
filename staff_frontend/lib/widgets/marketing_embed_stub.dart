import 'package:flutter/material.dart';

/// Native (Android/iOS/desktop): no webview dependency, so show a link card with
/// the URL to open in a browser. Web plays the embed inline instead.
Widget buildMarketingEmbed(String url, {double height = 220}) {
  return Builder(
    builder: (context) {
      final cs = Theme.of(context).colorScheme;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.play_circle_outline, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text('Watch',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: cs.onSurface)),
              ],
            ),
            const SizedBox(height: 6),
            SelectableText(url,
                style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text('Open this link in your browser to view.',
                style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
          ],
        ),
      );
    },
  );
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/marketing_content.dart';
import '../state/marketing_provider.dart';
import 'marketing_embed.dart';

/// The customizable login-screen marketing block. Reads [MarketingProvider] and
/// renders text / image / embed content. [onDark] tunes colours for the teal
/// brand panel (wide layout) versus the page background (mobile). Renders
/// nothing when the block is disabled or empty.
class MarketingBlock extends StatelessWidget {
  final bool onDark;
  const MarketingBlock({super.key, required this.onDark});

  @override
  Widget build(BuildContext context) {
    final m = context.watch<MarketingProvider>().content;
    if (!m.enabled || !m.hasContent) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final titleColor = onDark ? Colors.white : cs.onSurface;
    final bodyColor =
        onDark ? Colors.white.withValues(alpha: 0.82) : cs.onSurfaceVariant;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (m.title.trim().isNotEmpty) ...[
            Text(
              m.title.trim(),
              style: TextStyle(
                  color: titleColor, fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
          ],
          _media(context, m, bodyColor),
        ],
      ),
    );
  }

  Widget _media(BuildContext context, MarketingContent m, Color bodyColor) {
    final url = m.content.trim();
    switch (m.type) {
      case 'image':
        if (url.isEmpty) return const SizedBox.shrink();
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              loadingBuilder: (c, child, prog) => prog == null
                  ? child
                  : const SizedBox(
                      height: 120,
                      child: Center(
                          child:
                              CircularProgressIndicator(strokeWidth: 2))),
            ),
          ),
        );
      case 'embed':
        if (url.isEmpty) return const SizedBox.shrink();
        return buildMarketingEmbed(url);
      case 'text':
      default:
        if (m.content.trim().isEmpty) return const SizedBox.shrink();
        return Text(
          m.content.trim(),
          style: TextStyle(color: bodyColor, fontSize: 14, height: 1.5),
        );
    }
  }
}

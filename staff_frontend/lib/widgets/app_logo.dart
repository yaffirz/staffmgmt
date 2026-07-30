import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The Staff Portal brand mark: a rounded amber badge holding a small
/// "team hierarchy" glyph — one lead node linked to two report nodes. It reads
/// as people + structure, which is what the app manages (brands → stores →
/// staff). Drawn with a [CustomPainter] so it stays crisp at any size and needs
/// no image assets (works identically on web and Android).
class AppLogo extends StatelessWidget {
  final double size;

  /// Badge (rounded-square background) colour. Defaults to the brand amber.
  final Color? badgeColor;

  /// Glyph colour. Defaults to the brand ink (teal).
  final Color? markColor;

  const AppLogo({super.key, this.size = 34, this.badgeColor, this.markColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LogoPainter(
          badge: badgeColor ?? AppColors.amber,
          mark: markColor ?? AppColors.ink,
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final Color badge;
  final Color mark;
  const _LogoPainter({required this.badge, required this.mark});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    Offset p(double x, double y) => Offset(x * s, y * s);

    // Rounded-square badge.
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, s, s),
      Radius.circular(s * 0.26),
    );
    canvas.drawRRect(badgeRect, Paint()..color = badge);

    // Node geometry (unit coordinates within the badge).
    final lead = p(0.50, 0.31);
    final left = p(0.28, 0.71);
    final right = p(0.72, 0.71);
    final leadR = s * 0.135;
    final reportR = s * 0.108;

    // Connectors first, so the opaque nodes cap their ends cleanly.
    final link = Paint()
      ..color = mark
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.052
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(lead, left, link);
    canvas.drawLine(lead, right, link);

    // Nodes: a slightly larger lead over two reports.
    final node = Paint()..color = mark;
    canvas.drawCircle(left, reportR, node);
    canvas.drawCircle(right, reportR, node);
    canvas.drawCircle(lead, leadR, node);
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.badge != badge || old.mark != mark;
}

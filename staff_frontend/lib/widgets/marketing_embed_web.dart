import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

// View factories can only be registered once per view type, so track what we've
// already registered (build can run many times).
final Set<String> _registered = <String>{};

/// Web: render an embeddable URL in an <iframe> (video, maps, any embed HTML).
Widget buildMarketingEmbed(String url, {double height = 220}) {
  final viewType = 'marketing-embed-${url.hashCode}';
  if (!_registered.contains(viewType)) {
    _registered.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      final iframe = html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..setAttribute('allowfullscreen', 'true')
        ..setAttribute(
            'allow', 'autoplay; encrypted-media; picture-in-picture');
      return iframe;
    });
  }
  return SizedBox(
    height: height,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: HtmlElementView(viewType: viewType),
    ),
  );
}

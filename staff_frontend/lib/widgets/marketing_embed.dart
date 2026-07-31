// Cross-platform entry point for the marketing embed renderer. On web it renders
// an <iframe> so videos and other embeddable media play inline; on native it
// falls back to a link card (no webview dependency). Same conditional-import
// pattern as services/bulk_io.dart.
export 'marketing_embed_stub.dart'
    if (dart.library.html) 'marketing_embed_web.dart';

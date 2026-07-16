// Cross-platform entry point for the bulk-CSV file helpers. Compiles to the web
// implementation (browser download/upload) on web, and to a no-op stub on
// native platforms — so the app builds for Android/iOS without `dart:html`.
export 'bulk_io_stub.dart' if (dart.library.html) 'bulk_io_web.dart';

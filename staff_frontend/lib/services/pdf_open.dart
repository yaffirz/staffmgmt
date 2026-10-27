// Open generated PDF bytes for viewing / printing. On web it opens the PDF in a
// new browser tab (where the user can print or save); on native it's a no-op.
// Same conditional-import pattern as services/file_download.dart — avoids the
// native `printing` plugin (which needs Windows symlink/Developer Mode).
export 'pdf_open_stub.dart' if (dart.library.html) 'pdf_open_web.dart';

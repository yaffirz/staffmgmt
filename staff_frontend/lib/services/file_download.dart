// Cross-platform file "save" entry point. On web it triggers a browser download;
// on native it's a no-op (the UI hides the download button there). Same
// conditional-import pattern as services/bulk_io.dart.
export 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart';

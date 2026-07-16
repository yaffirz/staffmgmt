// Non-web (Android/iOS/desktop) stub for the bulk-CSV file helpers. Browser
// file download/upload isn't available off the web, so these are no-ops and the
// UI hides the buttons; users paste CSV instead (or use the web app).

bool get bulkFileIoSupported => false;

void downloadCsv(String filename, String content) {
  // No-op off the web; the download button is hidden when unsupported.
}

Future<({String name, String text})?> pickCsvText() async => null;

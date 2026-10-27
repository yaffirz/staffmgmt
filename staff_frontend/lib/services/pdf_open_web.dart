import 'dart:html' as html;
import 'dart:typed_data';

bool get pdfOpenSupported => true;

/// Open the PDF in a new browser tab so the user can view, print, or save it.
void openPdf(String filename, List<int> bytes) {
  final blob = html.Blob([Uint8List.fromList(bytes)], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  // Open in a new tab; the browser's PDF viewer offers print + save-as.
  html.window.open(url, '_blank');
  // Revoke a little later so the new tab has time to load it.
  Future.delayed(const Duration(minutes: 1), () => html.Url.revokeObjectUrl(url));
}

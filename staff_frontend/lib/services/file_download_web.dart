import 'dart:html' as html;
import 'dart:typed_data';

/// Web: trigger a browser download of [bytes] as [filename].
bool get downloadSupported => true;

void downloadBytes(String filename, List<int> bytes) {
  final blob = html.Blob([Uint8List.fromList(bytes)]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none'
    ..click();
  html.Url.revokeObjectUrl(url);
}

import 'dart:convert';
import 'dart:html' as html;

/// Web implementation of the bulk-CSV file helpers (browser download + upload).
/// Selected via a conditional import from `bulk_io.dart` when compiling for web.

bool get bulkFileIoSupported => true;

void downloadCsv(String filename, String content) {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], 'text/csv');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

/// Opens the browser file picker and returns the chosen file's (name, text),
/// or null if cancelled.
Future<({String name, String text})?> pickCsvText() async {
  final input = html.FileUploadInputElement()..accept = '.csv,text/csv';
  input.click();
  await input.onChange.first;
  final files = input.files;
  if (files == null || files.isEmpty) return null;
  final file = files.first;
  final reader = html.FileReader();
  reader.readAsText(file);
  await reader.onLoad.first;
  final text = (reader.result as String?) ?? '';
  return (name: file.name, text: text.trim());
}

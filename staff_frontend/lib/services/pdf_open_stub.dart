// Native: opening a PDF in a browser tab isn't applicable (web-only feature).
bool get pdfOpenSupported => false;

void openPdf(String filename, List<int> bytes) {}

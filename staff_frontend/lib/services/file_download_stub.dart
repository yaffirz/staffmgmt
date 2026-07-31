// Native: no browser download. The UI hides the Download button when
// downloadSupported is false.
bool get downloadSupported => false;

void downloadBytes(String filename, List<int> bytes) {}

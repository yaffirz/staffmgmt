// Native: no fingerprint reader. The enrol UI falls back to a dev placeholder
// when fingerprintReaderAvailable is false.
bool get fingerprintReaderAvailable => false;

Future<List<String>> enumerateFingerprintReaders() async => const [];

Future<List<String>> captureFingerprintSamples({int timeoutMs = 20000}) async =>
    throw UnsupportedError('Fingerprint capture is only available in the web app.');

void cancelFingerprintCapture() {}

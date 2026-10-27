// Fingerprint capture via the DigitalPersona Web SDK. Web-only: the JS SDK is
// loaded by web/index.html and bridged through window.dpFingerprint
// (web/dp/dp_fingerprint.js). On native builds this is a no-op
// (fingerprintReaderAvailable == false). Same conditional-import pattern as
// services/file_download.dart.
export 'dp_fingerprint_stub.dart'
    if (dart.library.html) 'dp_fingerprint_web.dart';

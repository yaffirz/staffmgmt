import 'dart:js_interop';
import 'dart:js_interop_unsafe';

// Web implementation: calls window.dpFingerprint.* (web/dp/dp_fingerprint.js),
// which wraps the DigitalPersona Web SDK. Uses the modern dart:js_interop API.

JSObject? _api() => globalContext['dpFingerprint'] as JSObject?;

/// True when the DigitalPersona JS SDK is loaded (not whether a reader is
/// plugged in — capture will report that).
bool get fingerprintReaderAvailable {
  final api = _api();
  if (api == null) return false;
  try {
    final r = api.callMethod('isAvailable'.toJS) as JSBoolean?;
    return r?.toDart ?? false;
  } catch (_) {
    return false;
  }
}

/// Reader device ids currently connected (via the local agent).
Future<List<String>> enumerateFingerprintReaders() async {
  final api = _api();
  if (api == null) return const [];
  final res = await (api.callMethod('enumerate'.toJS) as JSPromise).toDart;
  return _stringList(res);
}

/// Capture one good scan; returns the sample(s) as base64 PNG strings. Throws a
/// clean message on timeout / reader error / no-SDK.
Future<List<String>> captureFingerprintSamples({int timeoutMs = 20000}) async {
  final api = _api();
  if (api == null) {
    throw StateError('Fingerprint reader not available');
  }
  try {
    final res = await (api.callMethod('capture'.toJS, timeoutMs.toJS) as JSPromise)
        .toDart;
    return _stringList((res as JSObject?)?['samples']);
  } catch (e) {
    throw Exception(_message(e));
  }
}

void cancelFingerprintCapture() {
  final api = _api();
  if (api != null) {
    try {
      api.callMethod('cancel'.toJS);
    } catch (_) {}
  }
}

String _message(Object e) {
  try {
    final jsObj = e as JSObject; // throws for non-JS (e.g. Dart StateError)
    final m = jsObj['message'];
    if (m != null) {
      return m.dartify()?.toString() ?? 'Fingerprint capture failed';
    }
  } catch (_) {}
  return e.toString();
}

List<String> _stringList(JSAny? jsArray) {
  final d = jsArray?.dartify();
  if (d is List) {
    return [for (final e in d) if (e != null) e.toString()];
  }
  return const [];
}

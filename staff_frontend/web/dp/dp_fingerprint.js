// Thin bridge over the DigitalPersona Web SDK so Dart (Flutter web) can capture
// fingerprints with a simple Promise API. Loaded after websdk.client.js + the
// @digitalpersona core/services/devices bundles (see index.html).
//
// Exposes window.dpFingerprint:
//   isAvailable()            -> bool: the SDK globals are present
//   enumerate()              -> Promise<string[]>: connected reader ids
//   capture(timeoutMs)       -> Promise<{format, samples}>: one good scan (PNG)
//   cancel()                 -> stops any in-progress acquisition
(function () {
  var api = {};
  var reader = null;

  function sdkReady() {
    return !!(window.WebSdk && window.dp && window.dp.devices &&
              window.dp.devices.FingerprintReader);
  }

  function getReader() {
    if (!sdkReady()) throw new Error('DigitalPersona SDK not loaded');
    if (!reader) reader = new window.dp.devices.FingerprintReader();
    return reader;
  }

  api.isAvailable = function () { return sdkReady(); };

  api.enumerate = function () {
    try { return getReader().enumerateDevices(); }
    catch (e) { return Promise.reject(e); }
  };

  // Resolves with the first good sample. Captures PNG (format 5) so the image can
  // be matched later by any engine. Rejects on timeout or reader error.
  api.capture = function (timeoutMs) {
    return new Promise(function (resolve, reject) {
      var r;
      try { r = getReader(); } catch (e) { return reject(e); }
      var PNG = window.dp.devices.SampleFormat.PngImage; // = 5
      var done = false;
      var timer = null;

      function cleanup() {
        try { r.off(); } catch (e) {}
        try { r.stopAcquisition(); } catch (e) {}
        if (timer) { clearTimeout(timer); timer = null; }
      }
      function fail(err) {
        if (done) return; done = true; cleanup();
        reject(err instanceof Error ? err : new Error(String(err)));
      }
      function ok(samples) {
        if (done) return; done = true; cleanup();
        resolve({ format: 'PngImage', samples: samples || [] });
      }

      r.on('SamplesAcquired', function (ev) {
        var samples = (ev && ev.samples) ? ev.samples : [];
        // Samples arrive as JSON strings or objects depending on format; the PNG
        // payload is a base64 string (possibly URL-safe). Normalise to strings.
        var list = [];
        try {
          for (var i = 0; i < samples.length; i++) {
            var s = samples[i];
            list.push(typeof s === 'string' ? s : (s && s.Data) ? s.Data : JSON.stringify(s));
          }
        } catch (e) { list = samples; }
        ok(list);
      });
      r.on('ErrorOccurred', function (ev) { fail(new Error('reader error: ' + JSON.stringify(ev))); });

      timer = setTimeout(function () { fail(new Error('No finger detected (timed out)')); },
                         timeoutMs || 20000);

      r.startAcquisition(PNG).catch(function (e) { fail(e); });
    });
  };

  api.cancel = function () {
    try { if (reader) { reader.off(); reader.stopAcquisition(); } } catch (e) {}
  };

  window.dpFingerprint = api;
})();

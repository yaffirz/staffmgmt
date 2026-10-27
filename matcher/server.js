// Fingerprint matcher microservice. Wraps SourceAFIS (via nodeafis) behind a
// tiny HTTP API the FastAPI backend calls. Internal-only (no host port).
//
//   POST /verify  { probe: <png b64>, candidates: [<png b64>...], threshold? }
//     -> { score, bestIndex, match, threshold }
//   POST /template { sample: <png b64> }  -> { template: <cbor b64> }  (optional)
//   GET  /health  -> "ok"
//
// DigitalPersona U.are.U 4500 scans at 500 DPI (nodeafis default). SourceAFIS
// guidance: a score of ~40 ≈ 0.01% false-match rate.
import { createServer } from 'http';
import { FingerprintImage, FingerprintTemplate, FingerprintMatcher } from 'nodeafis';
import pngjs from 'pngjs';
const { PNG } = pngjs;

const PORT = parseInt(process.env.PORT || '9000', 10);
const DPI = parseInt(process.env.FP_DPI || '500', 10);
const DEFAULT_THRESHOLD = parseFloat(process.env.FP_THRESHOLD || '40');

function toBuffer(b64) {
  // Accept standard or URL-safe base64.
  const s = String(b64 || '').replace(/-/g, '+').replace(/_/g, '/');
  return Buffer.from(s, 'base64');
}

function templateFromPng(b64) {
  // Decode the PNG with pngjs (handles palette/indexed PNGs that the DigitalPersona
  // reader emits, which nodeafis.fromPng rejects), then feed 8-bit grayscale pixels
  // to nodeafis via fromRaw (0 = black).
  const png = PNG.sync.read(toBuffer(b64));
  const { width, height, data } = png; // data is RGBA
  const gray = new Uint8Array(width * height);
  for (let i = 0, j = 0; i < gray.length; i++, j += 4) {
    gray[i] = (data[j] * 0.299 + data[j + 1] * 0.587 + data[j + 2] * 0.114) | 0;
  }
  const img = FingerprintImage.fromRaw(width, height, gray, { dpi: DPI });
  return FingerprintTemplate.fromImage(img);
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (c) => {
      size += c.length;
      if (size > 50 * 1024 * 1024) { reject(new Error('body too large')); req.destroy(); return; }
      chunks.push(c);
    });
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', reject);
  });
}

function send(res, code, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(code, { 'Content-Type': 'application/json' });
  res.end(body);
}

const server = createServer(async (req, res) => {
  try {
    if (req.method === 'GET' && req.url === '/health') {
      return send(res, 200, { ok: true });
    }
    if (req.method === 'POST' && req.url === '/verify') {
      const { probe, candidates, threshold } = JSON.parse(await readBody(req));
      if (!probe || !Array.isArray(candidates) || candidates.length === 0) {
        return send(res, 400, { error: 'probe and non-empty candidates[] required' });
      }
      const thr = typeof threshold === 'number' ? threshold : DEFAULT_THRESHOLD;
      const matcher = new FingerprintMatcher(templateFromPng(probe));
      let best = -1;
      let bestIndex = -1;
      for (let i = 0; i < candidates.length; i++) {
        try {
          const score = matcher.match(templateFromPng(candidates[i]));
          if (score > best) { best = score; bestIndex = i; }
        } catch (e) {
          // Skip a candidate that can't be decoded/extracted.
        }
      }
      return send(res, 200, {
        score: best,
        bestIndex,
        match: best >= thr,
        threshold: thr,
      });
    }
    return send(res, 404, { error: 'not found' });
  } catch (e) {
    return send(res, 400, { error: String((e && e.message) || e) });
  }
});

server.listen(PORT, () => console.log(`fp-matcher listening on :${PORT} (dpi=${DPI}, threshold=${DEFAULT_THRESHOLD})`));

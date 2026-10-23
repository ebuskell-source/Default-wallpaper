// ---- Hub sign-in (5.7.0): the checks, in plain JavaScript (no libraries), so osascript can run them -----------------
// The same rules as the Linux and Windows versions (see TLA-BootPaper sign-in in tech-documentation). A sign-in is a
// token signed by the Hub, or by Google until the Hub's page is ready. It's checked every time against keys only root
// can write; its nonce ties it to this computer and this account; it lasts validDays from when it was signed.
var SignIn = (function () {
  'use strict';
  var DEFAULTS = { required: false, provider: 'google', validDays: 30, renewDays: 7, graceDays: 3, remindDays: [7, 3] };
  var GOOGLE_ISSUERS = ['https://accounts.google.com', 'accounts.google.com'];
  var HUB_AUDIENCE = 'tla-bootpaper';
  var SHA256_INFO = [0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01, 0x05,
                     0x00, 0x04, 0x20];
  var B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';

  function b64uDec(s) {
    s = String(s);
    if (!/^[A-Za-z0-9_-]*$/.test(s) || s.length % 4 === 1) throw new Error('not base64url');
    var out = [], bits = 0, acc = 0;
    for (var i = 0; i < s.length; i++) {
      acc = (acc << 6) | B64.indexOf(s[i]); bits += 6;
      if (bits >= 8) { bits -= 8; out.push((acc >> bits) & 0xff); }
    }
    return out;
  }
  function b64uEnc(bytes) {
    var s = '', i;
    for (i = 0; i + 2 < bytes.length; i += 3) {
      var n = (bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2];
      s += B64[n >> 18] + B64[(n >> 12) & 63] + B64[(n >> 6) & 63] + B64[n & 63];
    }
    if (bytes.length - i === 1) { var a = bytes[i] << 16; s += B64[a >> 18] + B64[(a >> 12) & 63]; }
    else if (bytes.length - i === 2) { var b = (bytes[i] << 16) | (bytes[i + 1] << 8); s += B64[b >> 18] + B64[(b >> 12) & 63] + B64[(b >> 6) & 63]; }
    return s;
  }
  function utf8Enc(str) {
    var out = [];
    for (var i = 0; i < str.length; i++) {
      var c = str.codePointAt(i);
      if (c > 0xffff) i++;
      if (c < 0x80) out.push(c);
      else if (c < 0x800) out.push(0xc0 | (c >> 6), 0x80 | (c & 63));
      else if (c < 0x10000) out.push(0xe0 | (c >> 12), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63));
      else out.push(0xf0 | (c >> 18), 0x80 | ((c >> 12) & 63), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63));
    }
    return out;
  }
  function utf8Dec(bytes) {
    var s = '', i = 0;
    while (i < bytes.length) {
      var b = bytes[i++], c;
      if (b < 0x80) c = b;
      else if (b >= 0xf0) c = ((b & 7) << 18) | ((bytes[i++] & 63) << 12) | ((bytes[i++] & 63) << 6) | (bytes[i++] & 63);
      else if (b >= 0xe0) c = ((b & 15) << 12) | ((bytes[i++] & 63) << 6) | (bytes[i++] & 63);
      else c = ((b & 31) << 6) | (bytes[i++] & 63);
      s += String.fromCodePoint(c);
    }
    return s;
  }

  var K = [0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5, 0xd807aa98,
    0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6,
    0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3,
    0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e,
    0x92722c85, 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116,
    0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814,
    0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2];
  function sha256(bytes) {
    var h = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19];
    var m = bytes.slice(), len = bytes.length * 8;
    m.push(0x80);
    while (m.length % 64 !== 56) m.push(0);
    for (var s = 56; s >= 0; s -= 8) m.push(s >= 32 ? Math.floor(len / Math.pow(2, s)) & 0xff : (len >>> s) & 0xff);
    var w = new Array(64);
    for (var o = 0; o < m.length; o += 64) {
      for (var t = 0; t < 16; t++) w[t] = (m[o + 4 * t] << 24) | (m[o + 4 * t + 1] << 16) | (m[o + 4 * t + 2] << 8) | m[o + 4 * t + 3];
      for (t = 16; t < 64; t++) {
        var x = w[t - 15], y = w[t - 2];
        var s0 = ((x >>> 7) | (x << 25)) ^ ((x >>> 18) | (x << 14)) ^ (x >>> 3);
        var s1 = ((y >>> 17) | (y << 15)) ^ ((y >>> 19) | (y << 13)) ^ (y >>> 10);
        w[t] = (w[t - 16] + s0 + w[t - 7] + s1) | 0;
      }
      var a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7];
      for (t = 0; t < 64; t++) {
        var S1 = ((e >>> 6) | (e << 26)) ^ ((e >>> 11) | (e << 21)) ^ ((e >>> 25) | (e << 7));
        var t1 = (hh + S1 + ((e & f) ^ (~e & g)) + K[t] + w[t]) | 0;
        var S0 = ((a >>> 2) | (a << 30)) ^ ((a >>> 13) | (a << 19)) ^ ((a >>> 22) | (a << 10));
        var t2 = (S0 + ((a & b) ^ (a & c) ^ (b & c))) | 0;
        hh = g; g = f; f = e; e = (d + t1) | 0; d = c; c = b; b = a; a = (t1 + t2) | 0;
      }
      h[0] = (h[0] + a) | 0; h[1] = (h[1] + b) | 0; h[2] = (h[2] + c) | 0; h[3] = (h[3] + d) | 0;
      h[4] = (h[4] + e) | 0; h[5] = (h[5] + f) | 0; h[6] = (h[6] + g) | 0; h[7] = (h[7] + hh) | 0;
    }
    var out = [];
    for (var i = 0; i < 8; i++) out.push((h[i] >>> 24) & 0xff, (h[i] >>> 16) & 0xff, (h[i] >>> 8) & 0xff, h[i] & 0xff);
    return out;
  }

  function toBig(bytes) { var n = BigInt(0); for (var i = 0; i < bytes.length; i++) n = (n << BigInt(8)) | BigInt(bytes[i]); return n; }
  function bitLen(n) { return n.toString(2).length; }
  function modPow(b, e, m) {
    var r = BigInt(1); b %= m;
    while (e > BigInt(0)) { if (e & BigInt(1)) r = (r * b) % m; e >>= BigInt(1); b = (b * b) % m; }
    return r;
  }
  function rs256Valid(jwk, signingInput, sig) {
    var n, e;
    try { n = toBig(b64uDec(jwk.n)); e = toBig(b64uDec(jwk.e)); } catch (x) { return false; }
    var k = Math.ceil(bitLen(n) / 8);
    if (k < 256 || sig.length !== k || e < BigInt(3)) return false;
    var s = toBig(sig);
    if (s >= n) return false;
    var m = modPow(s, e, n).toString(16);
    while (m.length < 2 * k) m = '0' + m;
    var t = SHA256_INFO.concat(sha256(utf8Enc(signingInput)));
    var want = '0001';
    for (var i = 0; i < k - t.length - 3; i++) want += 'ff';
    want += '00';
    for (i = 0; i < t.length; i++) want += (t[i] < 16 ? '0' : '') + t[i].toString(16);
    var diff = 0;
    for (i = 0; i < want.length; i++) diff |= want.charCodeAt(i) ^ m.charCodeAt(i);
    return diff === 0;
  }

  function isInt(v) { return typeof v === 'number' && Math.floor(v) === v; }
  function str(o, k) { return o && typeof o[k] === 'string' ? o[k].trim() : ''; }
  function config(raw) {
    var c = JSON.parse(JSON.stringify(DEFAULTS));
    raw = raw && typeof raw === 'object' ? raw : {};
    var num = function (k, lo, hi) { return isInt(raw[k]) && raw[k] >= lo && raw[k] <= hi ? raw[k] : c[k]; };
    c.required = raw.required === true;
    c.provider = raw.provider === 'hub' || raw.provider === 'google' ? raw.provider : 'google';
    c.validDays = num('validDays', 1, 120);
    c.renewDays = Math.min(num('renewDays', 0, 60), c.validDays);
    c.graceDays = num('graceDays', 0, 14);
    if (Array.isArray(raw.remindDays)) {
      var seen = {};
      c.remindDays = raw.remindDays.filter(function (d) { if (!isInt(d) || d <= 0 || d > 60 || seen[d]) return false; seen[d] = 1; return true; })
                                   .sort(function (a, b) { return b - a; });
    }
    var g = raw.google && typeof raw.google === 'object' ? raw.google : {};
    var h = raw.hub && typeof raw.hub === 'object' ? raw.hub : {};
    c.google = { clientId: str(g, 'clientId'),
                 domains: Array.isArray(g.domains) ? g.domains.filter(function (d) { return typeof d === 'string' && d; })
                                                             .map(function (d) { return d.toLowerCase(); }) : [] };
    c.hub = { signInUrl: str(h, 'signInUrl'), issuer: str(h, 'issuer'), jwksUrl: str(h, 'jwksUrl') };
    return c;
  }
  function kinds(c) {
    var k = [];
    if (c.google.clientId && c.google.domains.length) k.push('google');
    if (c.hub.issuer && c.hub.jwksUrl && c.hub.signInUrl.indexOf('https://') === 0) k.push('hub');
    return k;
  }
  function required(c) { return !!(c.required && kinds(c).length); }
  function nonce(device, user, salt) {
    return b64uEnc(sha256(utf8Enc('tla-bootpaper/1\n' + device + '\n' + user + '\n' + salt)));
  }

  function check(token, c, keys, device, user, salt, now, fresh) {
    var parts = String(token).split('.'), hdr, body, sig;
    if (parts.length !== 3) return { ok: false, reason: 'invalid' };
    try { hdr = JSON.parse(utf8Dec(b64uDec(parts[0]))); body = JSON.parse(utf8Dec(b64uDec(parts[1]))); sig = b64uDec(parts[2]); }
    catch (x) { return { ok: false, reason: 'invalid' }; }
    if (!hdr || typeof hdr !== 'object' || !body || typeof body !== 'object' || hdr.alg !== 'RS256' || typeof hdr.kid !== 'string')
      return { ok: false, reason: 'invalid' };
    var ks = kinds(c), kind;
    if (GOOGLE_ISSUERS.indexOf(body.iss) >= 0 && ks.indexOf('google') >= 0) kind = 'google';
    else if (body.iss === c.hub.issuer && ks.indexOf('hub') >= 0) kind = 'hub';
    else return { ok: false, reason: 'invalid' };
    var jwk = null;
    (keys || []).forEach(function (k) { if (!jwk && k && k.kind === kind && k.kid === hdr.kid) jwk = k; });
    if (!jwk) return { ok: false, reason: 'pending' };
    if (!rs256Valid(jwk, parts[0] + '.' + parts[1], sig)) return { ok: false, reason: 'invalid' };
    if (kind === 'google') {
      if (body.aud !== c.google.clientId || body.email_verified !== true ||
          c.google.domains.indexOf(String(body.hd || '').toLowerCase()) < 0) return { ok: false, reason: 'invalid' };
    } else if (body.aud !== HUB_AUDIENCE) return { ok: false, reason: 'invalid' };
    if (typeof salt !== 'string' || !salt || body.nonce !== nonce(device, user, salt)) return { ok: false, reason: 'invalid' };
    if (!isInt(body.iat) || body.iat > now + 86400) return { ok: false, reason: 'invalid' };
    if (fresh && (Math.abs(now - body.iat) > 600 || !isInt(body.exp) || body.exp < now - 300)) return { ok: false, reason: 'stale' };
    var who = kind === 'google' ? body.email : body.username;
    return { ok: true, kind: kind, iat: body.iat, name: String(body.name || who || '').slice(0, 80), who: String(who || '').slice(0, 120) };
  }

  // {state: off|in|renew|grace|out, ...}. online(): asked only in the grace days.
  function status(c, keys, token, salt, device, user, now, online) {
    if (!required(c)) return { state: 'off' };
    if (!token) return { state: 'out', reason: 'none' };
    var r = check(token, c, keys, device, user, salt, now, false);
    if (!r.ok) return { state: 'out', reason: r.reason };
    var until = r.iat + c.validDays * 86400;
    var st = { kind: r.kind, iat: r.iat, name: r.name, who: r.who, until: until };
    if (now < until) {
      st.days = Math.ceil((until - now) / 86400);
      st.state = st.days <= c.renewDays ? 'renew' : 'in';
    } else if (now < until + c.graceDays * 86400 && online && online() === false) {
      st.state = 'grace';
      st.days = Math.ceil((until + c.graceDays * 86400 - now) / 86400);
    } else { st.state = 'out'; st.reason = 'expired'; }
    return st;
  }

  function mergeKeys(old, fetched, now, keepDays) {
    keepDays = keepDays || 60;
    var out = {}, order = [];
    var put = function (k) { var id = k.kind + '\n' + k.kid; if (!out[id]) order.push(id); out[id] = k; };
    (Array.isArray(old) ? old : []).forEach(function (k) {
      if (k && (k.kind === 'hub' || k.kind === 'google') && typeof k.kid === 'string' && isInt(k.last) && now - k.last < keepDays * 86400)
        put({ kind: k.kind, kid: k.kid, n: k.n, e: k.e, first: k.first, last: k.last });
    });
    fetched.forEach(function (f) {
      var list = f[1] && Array.isArray(f[1].keys) ? f[1].keys : [];
      list.forEach(function (j) {
        if (!j || j.kty !== 'RSA' || (j.alg && j.alg !== 'RS256') || typeof j.kid !== 'string' || typeof j.n !== 'string' || typeof j.e !== 'string') return;
        var prev = out[f[0] + '\n' + j.kid];
        put({ kind: f[0], kid: j.kid.slice(0, 200), n: j.n, e: j.e, first: prev && isInt(prev.first) ? prev.first : now, last: now });
      });
    });
    return order.map(function (id) { return out[id]; }).sort(function (a, b) { return b.last - a.last; }).slice(0, 40);
  }

  function randomToken(bytes) { return b64uEnc(bytes); }
  return { config: config, kinds: kinds, required: required, nonce: nonce, check: check, status: status,
           mergeKeys: mergeKeys, b64uEnc: b64uEnc, b64uDec: b64uDec, sha256: sha256, utf8Enc: utf8Enc, randomToken: randomToken };
})();
if (typeof module !== 'undefined') module.exports = SignIn;

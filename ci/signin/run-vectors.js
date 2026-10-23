// osascript -l JavaScript run-vectors.js <signin-core.js> <vectors.json>: the shared checks, in JavaScriptCore (as on Macs).
ObjC.import('Foundation');
function run(argv) {
  const read = p => $.NSString.stringWithContentsOfFileEncodingError(p, 4, null).js;
  eval(read(argv[0]).replace(/^if \(typeof module[^\n]*$/m, ''));
  const v = JSON.parse(read(argv[1]));
  let bad = 0; const out = [];
  if (SignIn.nonce(v.device, v.user, v.salt) !== v.nonce) { bad++; out.push('FAIL nonce'); }
  const t0 = Date.now();
  v.cases.forEach(c => {
    const cfg = SignIn.config(c.cfg !== null ? c.cfg : v.cfg);
    let got;
    if (c.fresh) { const r = SignIn.check(c.token, cfg, v.keys, v.device, v.user, v.salt, v.now, true); got = r.ok ? { ok: true } : { ok: false, reason: r.reason }; }
    else got = SignIn.status(cfg, v.keys, c.token, v.salt, v.device, v.user, v.now, () => c.online);
    const miss = Object.keys(c.expect).filter(k => got[k] !== c.expect[k]);
    if (miss.length) { bad++; out.push('FAIL ' + c.name + ' ' + JSON.stringify(c.expect) + ' ' + JSON.stringify(got)); }
  });
  out.push(v.cases.length + ' cases, ' + bad + ' failed, ' + (Date.now() - t0) + ' ms');
  return out.join('\n');
}

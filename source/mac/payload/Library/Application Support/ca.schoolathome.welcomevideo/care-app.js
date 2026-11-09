// care-app.js - TLA Care on Macs (5.0): checks what most often goes wrong on a school Mac (restarts, storage,
// internet, sound, battery, Touch ID, TLA BootPaper itself) and fixes what it can with one click.
// 5.1: opens in front of other windows; Touch ID only on Macs that have it; teachers who haven't changed the
// password their Mac came with are asked to.
//   osascript -l JavaScript care-app.js <settings.zsh> window            the TLA Care window
//   osascript -l JavaScript care-app.js <settings.zsh> nudge "<check>"   a small reminder card (top right, a minute)
// settings.zsh does the work: --care-checks (one tab-separated line per check: id, status ok|info|warn|bad, title,
// detail, action, action text), --care-fix and --care-result (fixes that need root are done by guard.zsh),
// --restart, --open <page>, --report. Prints "ok", or "error: ...".
ObjC.import('AppKit');
// (6.4.5: methods that NSView or NSWindow already has are overridden without types: Objective-C's BOOL is a char on
// Intel Macs and a bool on Apple silicon, and the wrong one stops the script, so the Mac's own types are used.)
const C = n => $.NSClassFromString(n);
const ICON = '/Library/Application Support/ca.schoolathome.welcomevideo/AppIcon.png';

let SCRIPT = '';
let quit = false;
const ui = { rows: [] };
let waits = [];          // fixes waiting for guard.zsh's answer
const running = [];      // (5.1: tasks started without waiting, kept until they finish)

function sh(args, wait) {
  const t = $.NSTask.alloc.init;
  t.launchPath = '/bin/zsh';
  t.arguments = $([SCRIPT].concat(args));
  t.standardError = $.NSFileHandle.fileHandleWithNullDevice;
  if (wait === false) {
    t.standardOutput = $.NSFileHandle.fileHandleWithNullDevice;
    t.launch;
    running.push(t);
    return '';
  }
  const pipe = $.NSPipe.pipe;
  t.standardOutput = pipe;
  t.launch;
  const data = pipe.fileHandleForReading.readDataToEndOfFile;
  t.waitUntilExit;
  return $.NSString.alloc.initWithDataEncoding(data, 4).js || '';
}

const R = (x, y, w, h) => $.NSMakeRect(x, y, w, h);
const rgb = (r, g, b, a) => $.NSColor.colorWithSRGBRedGreenBlueAlpha(r / 255, g / 255, b / 255, a === undefined ? 1 : a);
function label(text, size, opts) {
  opts = opts || {};
  const l = opts.wrap ? C('NSTextField').wrappingLabelWithString(text) : C('NSTextField').labelWithString(text);
  l.font = opts.bold ? $.NSFont.boldSystemFontOfSize(size) : $.NSFont.systemFontOfSize(size);
  if (opts.grey) l.textColor = $.NSColor.secondaryLabelColor;
  return l;
}
function place(v, x, y, w, h) { v.setFrame(R(x, y, w, h)); }
function fitHeight(l, w) { l.preferredMaxLayoutWidth = w; return Math.ceil(l.fittingSize.height); }
function pump(n) {
  const app = $.NSApplication.sharedApplication;
  for (let i = 0; i < n; i++) {
    const ev = app.nextEventMatchingMaskUntilDateInModeDequeue(0xFFFFFFFF, $.NSDate.dateWithTimeIntervalSinceNow(0.03), 'kCFRunLoopDefaultMode', true);
    if (!ev.isNil()) app.sendEvent(ev);
  }
}
// 5.1: in front, even when another app is active (macOS 14 and later can ignore activateIgnoringOtherApps, which
// left this window behind other windows).
// 7.1.5: "centred" is 1 on Apple silicon and 2 on Intel (as in lock-app.js)
function machine() {
  const t = $.NSTask.alloc.init, p = $.NSPipe.pipe;
  t.launchPath = '/usr/bin/uname'; t.arguments = $(['-m']); t.standardOutput = p; t.launch; t.waitUntilExit;
  return ($.NSString.alloc.initWithDataEncoding(p.fileHandleForReading.readDataToEndOfFile, 4).js || '').trim();
}
const CENTRE = machine() === 'arm64' ? 1 : 2;
function bringToFront(app, win) {
  win.level = 3;   // (7.0.5: floating at first, so it can't open behind the window that asked for it)
  win.makeKeyAndOrderFront(null);
  win.orderFrontRegardless;
  try { if (app.respondsToSelector('activate')) app.activate; else app.activateIgnoringOtherApps(true); }
  catch (e) { try { app.activateIgnoringOtherApps(true); } catch (e2) {} }
}
function confirm(title, text, ok) {
  const a = $.NSAlert.alloc.init;
  a.messageText = title; a.informativeText = text;
  a.addButtonWithTitle(ok); a.addButtonWithTitle('Cancel');
  $.NSApplication.sharedApplication.activateIgnoringOtherApps(true);
  return Number(a.runModal) === 1000;   // (5.3: as a number)
}
function parseCheck(line) {
  const f = line.split('\t');
  return f[0] && f[1] ? { id: f[0], status: f[1], title: f[2] || '', detail: f[3] || '', action: f[4] || '', actionText: f[5] || '' } : null;
}

ObjC.registerSubclass({
  name: 'TCFlipped', superclass: 'NSView',
  methods: { isFlipped: { implementation: function () { return true; } } },
});
ObjC.registerSubclass({
  name: 'TCTarget', superclass: 'NSObject',
  methods: {
    'action:':  { types: ['void', ['id']], implementation: function (s) { runAction(Number(s.tag)); } },
    'again:':   { types: ['void', ['id']], implementation: function (s) { showChecks(); } },
    'report:':  { types: ['void', ['id']], implementation: function (s) { sh(['--report'], false); } },
    'close:':   { types: ['void', ['id']], implementation: function (s) { quit = true; } },
    'nudgeAct:':   { types: ['void', ['id']], implementation: function (s) { nudgeAct(); } },
    'nudgeClose:': { types: ['void', ['id']], implementation: function (s) { quit = true; } },
    'windowWillClose:': { types: ['void', ['id']], implementation: function (n) { quit = true; } },
  },
});

// ---- The window ----------------------------------------------------------------------------------------------
const LOOK = { ok: [16, 124, 16, '✓'], info: [15, 108, 189, 'i'], warn: [194, 124, 14, '!'], bad: [196, 43, 28, '✕'] };
const W = 640, X0 = 28;

function build() {
  ui.target = $.TCTarget.alloc.init;
  const win = $.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer(R(0, 0, W, 300), 1 | 2 | 8, 2, false);
  win.title = 'TLA Care';
  win.releasedWhenClosed = false;
  win.delegate = ui.target;
  const doc = $.TCFlipped.alloc.initWithFrame(R(0, 0, W, 300));
  win.contentView = doc;
  ui.win = win; ui.doc = doc;
  const add = v => { doc.addSubview(v); return v; };
  const icon = C('NSImage').alloc.initWithContentsOfFile(ICON);
  ui.icon = add(C('NSImageView').alloc.initWithFrame(R(X0, 22, 44, 44)));
  if (!icon.isNil()) { ui.icon.image = icon; ui.icon.imageScaling = 3; }
  ui.title = add(label('TLA Care', 22, { bold: true }));
  ui.subtitle = add(label('Checking your Mac…', 13, { grey: true }));
  ui.summary = add($.NSBox.alloc.initWithFrame(R(0, 0, 10, 10)));
  ui.summary.boxType = 4; ui.summary.borderWidth = 1; ui.summary.cornerRadius = 6;
  ui.summaryText = add(label('', 14, { bold: true, wrap: true }));
  ui.summaryText.textColor = rgb(31, 31, 31);
  ui.rowsView = add($.TCFlipped.alloc.initWithFrame(R(0, 0, W, 10)));
  ui.report = add($.NSButton.buttonWithTitleTargetAction('Report a problem', ui.target, 'report:'));
  ui.again = add($.NSButton.buttonWithTitleTargetAction('Check again', ui.target, 'again:'));
  ui.close = add($.NSButton.buttonWithTitleTargetAction('Close', ui.target, 'close:'));
  ui.close.keyEquivalent = '\u001b';
  layout();
}

function layout() {
  let y = 22;
  place(ui.title, X0 + 58, y + 2, W - X0 * 2 - 58, 28);
  place(ui.subtitle, X0 + 58, y + 30, W - X0 * 2 - 58, 18);
  y += 62;
  const inner = W - X0 * 2;
  let hh = ui.summaryText.stringValue.js ? fitHeight(ui.summaryText, inner - 28) : 0;
  ui.summary.hidden = ui.summaryText.hidden = !hh;
  if (hh) { place(ui.summary, X0, y, inner, hh + 20); place(ui.summaryText, X0 + 14, y + 10, inner - 28, hh); y += hh + 36; }
  // The rows, in their own view.
  let ry = 0;
  ui.rows.forEach(r => {
    const tw = inner - 40 - (r.btn ? r.bw + 12 : 0);
    place(r.badge, 0, ry + 1, 26, 26); place(r.glyph, 0, ry + 5, 26, 18);
    place(r.title, 40, ry, tw, 20);
    const dh = fitHeight(r.detail, tw); place(r.detail, 40, ry + 21, tw, dh);
    if (r.btn) place(r.btn, inner - r.bw, ry - 4, r.bw, 32);
    ry += Math.max(32, 21 + dh) + 14;
  });
  place(ui.rowsView, X0, y, inner, ry); y += ry + 8;
  ui.report.sizeToFit; ui.again.sizeToFit;
  place(ui.report, X0 - 6, y, Math.max(140, ui.report.frame.size.width + 12), 32);
  place(ui.close, W - X0 - 96 + 6, y, 96, 32);
  place(ui.again, W - X0 - 96 - 8 - 130 + 6, y, 130, 32);
  y += 50;
  ui.doc.setFrame(R(0, 0, W, y));
  const f = ui.win.frame, top = f.origin.y + f.size.height;
  ui.win.setContentSize($.NSMakeSize(W, y));
  if (ui.placed) { const g = ui.win.frame; ui.win.setFrameOrigin($.NSMakePoint(g.origin.x, top - g.size.height)); }
}

function addRow(check, index) {
  const v = ui.rowsView;
  const look = LOOK[check.status] || LOOK.info;
  const badge = $.NSBox.alloc.initWithFrame(R(0, 0, 26, 26));
  badge.boxType = 4; badge.borderWidth = 0; badge.cornerRadius = 13; badge.titlePosition = 0;
  badge.fillColor = rgb(look[0], look[1], look[2]);
  const glyph = label(look[3], 13, { bold: true });
  glyph.textColor = $.NSColor.whiteColor; glyph.alignment = CENTRE;   // (centred: 1 on Apple silicon, 2 on Intel)
  const title = label(check.title, 14, { bold: true });
  const detail = label(check.detail, 13, { grey: true, wrap: true });
  [badge, glyph, title, detail].forEach(x => v.addSubview(x));
  let btn = null, bw = 0;
  if (check.action) {
    btn = $.NSButton.buttonWithTitleTargetAction(check.actionText || 'Fix it', ui.target, 'action:');
    btn.tag = index; btn.sizeToFit;
    bw = Math.max(110, btn.frame.size.width + 16);
    v.addSubview(btn);
  }
  ui.rows.push({ check: check, badge: badge, glyph: glyph, title: title, detail: detail, btn: btn, bw: bw });
}

function showChecks() {
  ui.rows.forEach(r => [r.badge, r.glyph, r.title, r.detail, r.btn].forEach(x => { if (x) x.removeFromSuperview; }));
  ui.rows = []; waits = [];
  ui.subtitle.stringValue = 'Checking your Mac…';
  ui.summaryText.stringValue = '';
  ui.again.enabled = false;
  layout(); pump(5);
  const checks = sh(['--care-checks']).split('\n').map(parseCheck).filter(c => c);
  checks.forEach((c, i) => addRow(c, i));
  const bad = checks.filter(c => c.status === 'bad').length, warn = checks.filter(c => c.status === 'warn').length;
  if (bad) {
    ui.summaryText.stringValue = bad + warn === 1 ? 'One thing needs your attention.' : (bad + warn) + ' things need your attention.';
    ui.summary.fillColor = rgb(253, 231, 233); ui.summary.borderColor = rgb(241, 187, 188);
  } else if (warn) {
    ui.summaryText.stringValue = warn === 1 ? 'One thing to look at.' : warn + ' things to look at.';
    ui.summary.fillColor = rgb(255, 244, 206); ui.summary.borderColor = rgb(242, 213, 124);
  } else {
    ui.summaryText.stringValue = 'Your Mac is in good shape. ✓';
    ui.summary.fillColor = rgb(223, 246, 221); ui.summary.borderColor = rgb(159, 216, 159);
  }
  const now = new Date();
  ui.subtitle.stringValue = 'Checked ' + now.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' });
  ui.again.enabled = true;
  layout();
}

function runAction(index) {
  const r = ui.rows[index];
  if (!r) return;
  const c = r.check;
  switch (c.action) {
    case 'restart':
      if (confirm('Restart your Mac now?', 'Save your work first: open apps will close.', 'Restart')) sh(['--restart'], false);
      return;
    case 'wifi': case 'touchid': case 'storage': case 'password': case 'connect': case 'swupdate':   // (5.1: a teacher's password; 5.2.5: Connect to TLA)
      sh(['--open', c.action], false); return;
    case 'report':
      sh(['--report'], false); return;
    case 'opencore':   // (7.0)
      openCore(r); return;
  }
  // cleanup, audio, videos: started here, finished by guard.zsh (as root) within about 20 seconds.
  const out = sh(['--care-fix', c.action]).trim().split('\t');
  if (!/^\d+$/.test(out[0] || '')) { r.detail.stringValue = 'TLA Care couldn’t start the fix. Try again, or report the problem.'; layout(); return; }
  r.btn.enabled = false; r.btn.title = 'Working…';
  r.detail.stringValue = c.action === 'cleanup' ? 'Clearing out old files. This can take a few minutes.'
    : c.action === 'audio' ? 'Restarting the sound system…' : 'Starting the download…';
  layout();
  waits.push({ row: r, action: c.action, at: out[0], freed: +(out[1] || 0), until: Date.now() + 5 * 60 * 1000 });
}

// ---- A newer macOS with OpenCore Legacy Patcher (7.0) -------------------------------------------------------------
// First which version (the recommended one first), then what works differently with it on this Mac, then it starts.
function ocAlert(title, text, buttons, accessory) {
  const a = $.NSAlert.alloc.init;
  a.messageText = title; a.informativeText = text;
  try { const i = C('NSImage').alloc.initWithContentsOfFile(ICON); if (!i.isNil()) a.icon = i; } catch (e) { }
  buttons.forEach(b => a.addButtonWithTitle(b));
  if (accessory) a.accessoryView = accessory;
  try { $.NSApplication.sharedApplication.activateIgnoringOtherApps(true); } catch (e) { }
  return Number(a.runModal) - 1000;   // (0: the first button)
}
function ocList(lines) {
  const W = 460, H = 260;
  const sv = C('NSScrollView').alloc.initWithFrame(R(0, 0, W, H));
  sv.hasVerticalScroller = true; sv.borderType = 2;
  const tv = C('NSTextView').alloc.initWithFrame(R(0, 0, W - 4, H));
  tv.editable = false; tv.selectable = true; tv.textContainerInset = $.NSMakeSize(8, 8);
  tv.font = $.NSFont.systemFontOfSize(13);
  tv.string = lines.map(l => '• ' + l).join('\n\n');
  sv.documentView = tv;
  return sv;
}
function openCore(r) {
  const info = { issues: { sequoia: [], tahoe: [] }, ver: {} };
  sh(['--opencore']).split('\n').forEach(line => {
    const f = line.split('\t');
    if (f[0] === 'model') info.name = f[2];
    else if (f[0] === 'offer') info.offer = f[1] === 'offer' ? (f[2] || '').split(' ') : [];
    else if (f[0] === 'version') info.ver[f[1]] = { name: f[2], oclp: f[3], free: f[4] };
    else if (f[0] === 'issue' && info.issues[f[1]]) info.issues[f[1]].push(f.slice(2).join('\t'));
  });
  const offer = info.offer || [];
  if (!offer.length) { r.detail.stringValue = 'A newer macOS isn’t available for this Mac.'; layout(); return; }
  const name = v => info.ver[v].name;
  const intro = 'Apple doesn’t update ' + (info.name || 'this Mac') + ' any more. OpenCore Legacy Patcher (made by Dortania, a volunteer group, not by Apple) can put a newer macOS on it.\n\n' +
    'It takes 1 to 2 hours, with several restarts, and the Mac needs its charger and ' + info.ver[offer[0]].free + ' GB free. Your files and apps stay, but save anything important to OneDrive first.';
  const choices = offer.map((v, i) => name(v) + (offer.length > 1 && i === 0 ? ' (recommended)' : offer.length > 1 ? ' (OpenCore Legacy Patcher ' + info.ver[v].oclp + ')' : ''));
  const pick = ocAlert('A newer macOS for this Mac', intro + (offer.length > 1 ? '\n\n' + name(offer[0]) + ' is recommended: OpenCore Legacy Patcher has supported it for over a year. ' + name(offer[1]) + ' needs its newest version, ' + info.ver[offer[1]].oclp + '.' : ''),
    choices.concat(['Not now']));
  const v = offer[pick];
  if (!v) return;
  const go = ocAlert('What’s different on ' + name(v) + ' with OpenCore on this Mac',
    'Compared with a Mac Apple updates itself. Read these before you start: it can’t be undone from here.',
    ['Upgrade to ' + name(v), 'Cancel'], ocList(info.issues[v]));
  if (go !== 0) return;
  const out = sh(['--care-fix', 'opencore-' + v]).trim().split('\t');
  if (!/^\d+$/.test(out[0] || '')) { r.detail.stringValue = 'TLA Care couldn’t start the upgrade. Try again, or report the problem.'; layout(); return; }
  r.btn.enabled = false; r.btn.title = 'Starting…';
  r.detail.stringValue = 'Starting the upgrade to ' + name(v) + '…';
  layout();
  waits.push({ row: r, action: 'opencore-' + v, at: out[0], freed: 0, until: Date.now() + 5 * 60 * 1000 });
}

function tick() {
  const now = Date.now();
  if (ui.nextTick && now < ui.nextTick) return;
  ui.nextTick = now + 1500;
  waits = waits.filter(w => {
    let text = sh(['--care-result', w.action, w.at]).trim();
    if (!text && now < w.until) return true;
    if (!text) text = 'It’s taking longer than usual. Check again later.';
    if (w.freed >= 50 * 1048576) text = text.replace(/\.$/, '') + ' (and ' + (w.freed / 1073741824).toFixed(1) + ' GB of your own cached files).';
    w.row.detail.stringValue = text; w.row.btn.title = 'Done';
    layout();
    return false;
  });
}

// ---- The reminder card ---------------------------------------------------------------------------------------
function nudge(check) {
  ui.target = $.TCTarget.alloc.init;
  ui.check = check;
  const NW = 380, pad = 16;
  const screen = $.NSScreen.mainScreen.visibleFrame;
  const win = $.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer(R(0, 0, NW, 200), 0, 2, false);
  win.opaque = false; win.backgroundColor = $.NSColor.clearColor; win.hasShadow = true;
  win.level = 3;                                  // (floating, above other windows)
  win.releasedWhenClosed = false;
  win.collectionBehavior = 1 | 256;               // (on every Space, and over full-screen apps too)
  const fx = C('NSVisualEffectView').alloc.initWithFrame(R(0, 0, NW, 200));
  fx.material = 6; fx.state = 1; fx.blendingMode = 0;   // (popover material, always active)
  fx.wantsLayer = true; fx.layer.cornerRadius = 12; fx.layer.masksToBounds = true;
  win.contentView = fx;
  const doc = $.TCFlipped.alloc.initWithFrame(R(0, 0, NW, 200));
  fx.addSubview(doc);
  const add = v => { doc.addSubview(v); return v; };
  const icon = C('NSImage').alloc.initWithContentsOfFile(ICON);
  const iv = add(C('NSImageView').alloc.initWithFrame(R(pad, 14, 20, 20)));
  if (!icon.isNil()) { iv.image = icon; iv.imageScaling = 3; }
  const head = add(label('TLA Care', 12, { bold: true, grey: true })); place(head, pad + 26, 16, 200, 16);
  const x = add($.NSButton.buttonWithTitleTargetAction('✕', ui.target, 'nudgeClose:'));
  x.bordered = false; x.toolTip = 'Close'; place(x, NW - pad - 22, 12, 22, 22);
  const title = add(label(check.title, 15, { bold: true, wrap: true }));
  let y = 42, hh = fitHeight(title, NW - pad * 2); place(title, pad, y, NW - pad * 2, hh); y += hh + 4;
  const text = add(label(check.detail, 13, { grey: true, wrap: true }));
  hh = fitHeight(text, NW - pad * 2); place(text, pad, y, NW - pad * 2, hh); y += hh + 14;
  const act = add($.NSButton.buttonWithTitleTargetAction(check.action === 'restart' ? 'Restart now' : 'Open TLA Care', ui.target, 'nudgeAct:'));
  act.keyEquivalent = '\r'; act.sizeToFit;
  const later = add($.NSButton.buttonWithTitleTargetAction('Later', ui.target, 'nudgeClose:'));
  later.sizeToFit;
  const aw = Math.max(110, act.frame.size.width + 12), lw = Math.max(80, later.frame.size.width + 12);
  place(act, NW - pad - aw + 6, y, aw, 32); place(later, NW - pad - aw - 4 - lw + 6, y, lw, 32);
  y += 46;
  doc.setFrame(R(0, 0, NW, y)); fx.setFrame(R(0, 0, NW, y));
  win.setContentSize($.NSMakeSize(NW, y));
  // Top right, under the menu bar (where macOS's own notifications appear).
  win.setFrameOrigin($.NSMakePoint(screen.origin.x + screen.size.width - NW - 12, screen.origin.y + screen.size.height - y - 12));
  win.orderFrontRegardless;
  ui.nudgeWin = win;
  sh(['--care-nudged', check.id + '|' + check.status], false);
}
function nudgeAct() {
  if (ui.check.action === 'restart') {
    if (!confirm('Restart your Mac now?', 'Save your work first: open apps will close.', 'Restart')) return;
    sh(['--restart'], false);
  } else {
    sh(['--care'], false);
  }
  quit = true;
}

function run(argv) {
  try {
    SCRIPT = argv[0];
    const app = $.NSApplication.sharedApplication;
    app.setActivationPolicy(1);
    app.finishLaunching;
    const test = $.NSProcessInfo.processInfo.environment.objectForKey('TB_TEST');
    if (argv[1] === 'nudge') {
      const check = parseCheck(argv[2] || '');
      if (!check) return 'error: nothing to remind about';
      nudge(check);
      if (!test.isNil()) return selfTest(app, test.js, ui.nudgeWin, 'care-nudge.png');
      const until = Date.now() + 60000;       // (goes away by itself after a minute)
      while (!quit && Date.now() < until) pump(8);
      ui.nudgeWin.orderOut(null);
      return 'ok';
    }
    build();
    ui.win.center; ui.placed = true;
    bringToFront(app, ui.win);
    pump(4);
    ui.win.level = 0;
    showChecks();
    if (!test.isNil()) return selfTest(app, test.js, ui.win, 'care-window.png');
    while (!quit) {
      const ev = app.nextEventMatchingMaskUntilDateInModeDequeue(0xFFFFFFFF, $.NSDate.dateWithTimeIntervalSinceNow(0.25), 'kCFRunLoopDefaultMode', true);
      if (!ev.isNil()) app.sendEvent(ev);
      tick();
    }
    ui.win.orderOut(null);
    return 'ok';
  } catch (e) {
    return 'error: ' + e;
  }
}

// Developer check (TB_TEST=<folder>): a picture of the window, then quits. Not used normally.
function selfTest(app, dir, win, name) {
  pump(8);
  const v = win.contentView, rep = v.bitmapImageRepForCachingDisplayInRect(v.bounds);
  v.cacheDisplayInRectToBitmapImageRep(v.bounds, rep);
  rep.representationUsingTypeProperties(4, $({})).writeToFileAtomically(dir + '/' + name, true);
  return 'ok (test)';
}

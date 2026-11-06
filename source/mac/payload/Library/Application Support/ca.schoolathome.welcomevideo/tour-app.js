// tour-app.js - "Welcome to TLA" on Macs (5.0): a short tour, after TLA Classic, the first time a prepared Mac is
// used by its new owner (see "Prepare for initial unboxing" in the app, and play-welcome-video.zsh). Anyone can take
// it again from the TLA BootPaper app ("Take the Welcome to TLA tour").
//   osascript -l JavaScript tour-app.js <settings.zsh> unbox|app
// Pages: welcome, their name for the greeting, their background, their password (teachers), Touch ID, call
// backgrounds, TLA Care, done. The name and background pages only show when people may change those settings.
// 5.1: the password page only for teachers (the "Teacher vs. Student" profile) who haven't changed it yet, the
// Touch ID page only on Macs with Touch ID that isn't set up yet, the TLA backgrounds go into Teams by themselves,
// and each button has its own action (they did nothing in 5.0). 5.2.5: full screen (over the menu bar and Dock,
// stepping back while something it opened is in front), and "Connect to TLA" on Macs Intune doesn't manage. settings.zsh does the work (--state, --save,
// --calls, --care, --tour-done). Prints "ok", or "error: ...".
// 6.0.5: the backgrounds page shows one themed section at a time, picked above the pictures: all of them at once no
// longer fit, and the last row was cut off. 6.1.0: TLA's sections, and a caption under some ("Windows default").
// 6.1.5: a page asking them to sign in with their Hub account, right after the welcome, when they haven't yet.
ObjC.import('AppKit');
// (6.4.5: methods that NSView or NSWindow already has are overridden without types: Objective-C's BOOL is a char on
// Intel Macs and a bool on Apple silicon, and the wrong one stops the script, so the Mac's own types are used.)
const C = n => $.NSClassFromString(n);
const WV_DIR = '/Library/Application Support/ca.schoolathome.welcomevideo';
const WV_APP_BIN = '/Applications/TLA BootPaper.app/Contents/MacOS/welcome-video';   // (6.4.5)
const ICON = WV_DIR + '/AppIcon.png';
const SETTINGS_URL = 'x-apple.systempreferences:com.apple.Touch-ID-Settings.extension';   // (Touch ID & Password)
const PORTAL_APP = '/Applications/Company Portal.app', PORTAL_URL = 'https://go.microsoft.com/fwlink/?linkid=853070';
const FRONT_LEVEL = 25;   // (5.2.5: just above the menu bar and the Dock)

let SCRIPT = '', MODE = 'app';
let quit = false;
let st = {};
const ui = {};
const tour = { pages: [], index: 0 };
const running = [];      // (5.1: tasks started without waiting are kept here until they finish)

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

function loadState() {
  const s = { setting: {}, backgrounds: [], features: {}, org: {}, categories: [] };
  sh(['--state', 'tour']).split('\n').forEach(line => {
    const f = line.split('\t');
    if (f[0] === 'setting') s.setting[f[1]] = f[2] || '';
    else if (f[0] === 'feature') s.features[f[1]] = f[2] === '1';
    else if (f[0] === 'org') s.org[f[1]] = f[2];
    else if (f[0] === 'bg') s.backgrounds.push({ id: f[1], name: f[2], thumb: f[4], released: f[6] !== '0', group: f[9] || 'defaults', caption: f[10] || '' });
    else if (f[0] === 'cat') s.categories.push({ id: f[1], name: f[2] });   // (6.0.5)
    else if (f[0]) s[f[0]] = f[1];
  });
  return s;
}

const R = (x, y, w, h) => $.NSMakeRect(x, y, w, h);
const rgb = (r, g, b, a) => $.NSColor.colorWithSRGBRedGreenBlueAlpha(r / 255, g / 255, b / 255, a === undefined ? 1 : a);
function label(text, size, opts) {
  opts = opts || {};
  const l = opts.wrap ? C('NSTextField').wrappingLabelWithString(text) : C('NSTextField').labelWithString(text);
  l.font = opts.bold ? $.NSFont.boldSystemFontOfSize(size) : $.NSFont.systemFontOfSize(size);
  l.textColor = opts.color || $.NSColor.whiteColor;
  return l;
}
function place(v, x, y, w, h) { v.setFrame(R(x, y, w, h)); }
function fitHeight(l, w) {   // (the wrapped text's height at that width)
  l.preferredMaxLayoutWidth = w;
  return Math.ceil(Math.max(l.fittingSize.height, l.cell.cellSizeForBounds(R(0, 0, w, 100000)).height));
}
// Opens a System Settings page, or a folder in Finder, straight from here (5.1).
function openURL(u) {
  const url = u.charAt(0) === '/' ? $.NSURL.fileURLWithPath(u) : $.NSURL.URLWithString(u);
  return !url.isNil() && !!$.NSWorkspace.sharedWorkspace.openURL(url);
}
// 5.1: in front, even when another app is active (macOS 14 and later can ignore activateIgnoringOtherApps, which
// left this window behind other windows).
function bringToFront(app, win) {
  win.makeKeyAndOrderFront(null);
  win.orderFrontRegardless;
  try { if (app.respondsToSelector('activate')) app.activate; else app.activateIgnoringOtherApps(true); }
  catch (e) { try { app.activateIgnoringOtherApps(true); } catch (e2) {} }
}
function pump(n) {
  const app = $.NSApplication.sharedApplication;
  for (let i = 0; i < n; i++) {
    const ev = app.nextEventMatchingMaskUntilDateInModeDequeue(0xFFFFFFFF, $.NSDate.dateWithTimeIntervalSinceNow(0.03), 'kCFRunLoopDefaultMode', true);
    if (!ev.isNil()) app.sendEvent(ev);
  }
}

ObjC.registerSubclass({
  name: 'TTFlipped', superclass: 'NSView',
  methods: { isFlipped: { implementation: function () { return true; } } },
});
// 5.2.5: a borderless window the size of the screen, that can still be typed into.
ObjC.registerSubclass({
  name: 'TTWindow', superclass: 'NSWindow',
  methods: {
    canBecomeKeyWindow:  { implementation: function () { return true; } },
    canBecomeMainWindow: { implementation: function () { return true; } },
  },
});
// Full screen while it's in front; behind whatever it opened (System Settings, Finder, TLA Care, Company Portal)
// until it's clicked again.
function stepAside() { if (ui.win) ui.win.level = 0; }
ObjC.registerSubclass({
  name: 'TTTarget', superclass: 'NSObject',
  methods: {
    'windowDidBecomeKey:': { types: ['void', ['id']], implementation: function (n) { ui.win.level = FRONT_LEVEL; } },
    'windowDidResignKey:': { types: ['void', ['id']], implementation: function (n) { ui.win.level = 0; } },
    'connect:': { types: ['void', ['id']], implementation: function (s) {
      stepAside();
      const app = $.NSFileManager.defaultManager.fileExistsAtPath(PORTAL_APP);
      if (!openURL(app ? PORTAL_APP : PORTAL_URL)) sh(['--open', 'connect'], false);
    } },
    'next:':  { types: ['void', ['id']], implementation: function (s) { go(1); } },
    'back:':  { types: ['void', ['id']], implementation: function (s) { go(-1); } },
    'skip:':  { types: ['void', ['id']], implementation: function (s) { finish(); } },
    'tile:':  { types: ['void', ['id']], implementation: function (s) { pickBackground(Number(s.tag)); } },
    'cat:':   { types: ['void', ['id']], implementation: function (s) { const c = tour.cats[Number(s.selectedSegment)]; if (c) { tour.cat = c.id; show(); } } },
    'touchid:':  { types: ['void', ['id']], implementation: function (s) { stepAside(); if (!openURL(SETTINGS_URL)) sh(['--open', 'touchid'], false); } },
    'password:': { types: ['void', ['id']], implementation: function (s) { stepAside(); if (!openURL(SETTINGS_URL)) sh(['--open', 'password'], false); } },
    'pictures:': { types: ['void', ['id']], implementation: function (s) { stepAside(); if (!openURL(WV_DIR + '/Calls')) sh(['--calls', 'open'], false); } },
    'teams:':    { types: ['void', ['id']], implementation: function (s) { addToTeams(); } },
    'care:':     { types: ['void', ['id']], implementation: function (s) { stepAside(); sh(['--care'], false); } },
    'signin:':   { types: ['void', ['id']], implementation: function (s) {   // (6.1.5: the app signs them in, in their browser)
      if (mustSignIn()) {   // (6.4.5: on TLA's Macs, the lock screen's sign-in, so nothing else opens meanwhile)
        const t = $.NSTask.alloc.init;
        t.launchPath = WV_APP_BIN; t.arguments = $(['--jxa', WV_DIR + '/lock-app.js', SCRIPT, 'signin']);
        t.standardOutput = $.NSFileHandle.fileHandleWithNullDevice; t.standardError = $.NSFileHandle.fileHandleWithNullDevice;
        try { t.launch; t.waitUntilExit; } catch (e) { }
        st = loadState();
        if (!mustSignIn() && st.signin !== 'out') { tour.signinNote = ''; go(1); return; }
        tour.signinNote = 'You’re not signed in yet. Click Sign in to try again.'; show(); return;
      }
      stepAside(); sh(['--signin-now'], false);
      tour.signinNote = 'Finish signing in in your browser. When it says you’re signed in, come back here and click Next.';
      show(); } },
    'windowWillClose:': { types: ['void', ['id']], implementation: function (n) { quit = true; } },
  },
});

// ---- The window ----------------------------------------------------------------------------------------------
const W = 980, H = 620, X0 = 56;      // the tour's content
let SW = W, SH = H, OX = 0, OY = 0;   // 5.2.5: the whole screen, with the content in the middle

function build() {
  ui.target = $.TTTarget.alloc.init;
  // 5.2.5: full screen, borderless, over the menu bar and the Dock.
  const sf = $.NSScreen.mainScreen.frame;
  SW = Math.round(sf.size.width); SH = Math.round(sf.size.height);
  OX = Math.max(0, Math.round((SW - W) / 2)); OY = Math.max(0, Math.round((SH - H) / 2));
  const win = $.TTWindow.alloc.initWithContentRectStyleMaskBackingDefer(sf, 0, 2, false);
  win.setFrameDisplay(sf, true);
  win.level = FRONT_LEVEL;
  win.hasShadow = false;
  win.title = 'Welcome to TLA';
  win.releasedWhenClosed = false;
  win.delegate = ui.target;
  win.appearance = $.NSAppearance.appearanceNamed('NSAppearanceNameDarkAqua');
  win.backgroundColor = rgb(11, 27, 51);
  ui.win = win;
  const root = $.TTFlipped.alloc.initWithFrame(R(0, 0, SW, SH));
  win.contentView = root;
  // The person's background, filling the screen, darker on the left where the words are.
  ui.picture = C('NSImageView').alloc.initWithFrame(R(0, 0, SW, SH));
  ui.picture.imageScaling = 1;          // (the picture is made to the card's size: see setPicture)
  root.addSubview(ui.picture);
  const shade = (x, w, a) => { const b = $.NSBox.alloc.initWithFrame(R(x, 0, w, SH)); b.boxType = 4; b.borderWidth = 0;
    b.titlePosition = 0; b.fillColor = rgb(8, 20, 38, a); root.addSubview(b); return b; };
  shade(0, SW, 0.45); shade(0, OX + 680, 0.45); shade(0, OX + 420, 0.2);
  ui.doc = $.TTFlipped.alloc.initWithFrame(R(OX, OY, W, H));
  root.addSubview(ui.doc);
  const add = v => { ui.doc.addSubview(v); return v; };
  const icon = C('NSImage').alloc.initWithContentsOfFile(ICON);
  ui.logo = add(C('NSImageView').alloc.initWithFrame(R(X0, 40, 30, 30)));
  if (!icon.isNil()) { ui.logo.image = icon; ui.logo.imageScaling = 3; }
  ui.kicker = add(label('WELCOME TO TLA', 13, { bold: true, color: rgb(242, 184, 48) }));
  place(ui.kicker, X0 + 40, 46, 300, 18);
  ui.skip = add($.NSButton.buttonWithTitleTargetAction('Skip the tour', ui.target, 'skip:'));
  ui.skip.keyEquivalent = '\u001b'; ui.skip.sizeToFit;
  place(ui.skip, W - 48 - ui.skip.frame.size.width - 12, 38, ui.skip.frame.size.width + 12, 32);
  ui.heading = add(label('', 36, { bold: true, wrap: true }));
  ui.body = add(label('', 17, { wrap: true, color: rgb(255, 255, 255, 0.9) }));
  ui.extra = add($.TTFlipped.alloc.initWithFrame(R(X0, 0, W - X0 - 48, 10)));
  ui.back = add($.NSButton.buttonWithTitleTargetAction('Back', ui.target, 'back:'));
  ui.next = add($.NSButton.buttonWithTitleTargetAction('Next', ui.target, 'next:'));
  ui.next.keyEquivalent = '\r';
  ui.dots = [];
}

function setPicture() {
  const file = st.currentfile;
  if (!file || file === ui.pictureFile) return;
  const img = C('NSImage').alloc.initWithContentsOfFile(file);
  if (img.isNil()) return;
  ui.pictureFile = file;
  // Filled: scaled to cover the screen, keeping its shape, and the middle shown.
  const iw = img.size.width, ih = img.size.height;
  if (!(iw > 0 && ih > 0)) return;
  const scale = Math.max(SW / iw, SH / ih), sw = SW / scale, sh = SH / scale;
  const out = C('NSImage').alloc.initWithSize($.NSMakeSize(SW, SH));
  out.lockFocus;
  img.drawInRectFromRectOperationFraction(R(0, 0, SW, SH), R((iw - sw) / 2, (ih - sh) / 2, sw, sh), 2, 1);
  out.unlockFocus;
  ui.picture.image = out;
}

// 6.2.5: on TLA's own Macs, signing in isn't optional: no skipping the tour until they have.
const mustSignIn = () => st.corporate === '1' && st.signin === 'out';
function pages() {
  const p = ['welcome'];
  const canChange = st.locked !== '1';
  if (st.signin === 'out') p.push('signin');   // (6.1.5)
  if (canChange) p.push('name');
  if (canChange && st.bglocked !== '1') p.push('background');
  if (st.role === 'teacher' && st.password !== 'changed') p.push('password');
  if (st.touchid === 'available') p.push('touchid');
  if (st.features.calls) p.push('calls');
  if (st.features.care) p.push('care');
  if (st.connect === 'needed') p.push('connect');   // (5.2.5)
  p.push('done');
  return p;
}

function clearExtra() {
  const subs = ui.extra.subviews;
  for (let i = subs.count - 1; i >= 0; i--) subs.objectAtIndex(i).removeFromSuperview;
  ui.nameBox = null; ui.extraNote = null;
}
function extraButton(title, action, x, y) {
  const b = $.NSButton.buttonWithTitleTargetAction(title, ui.target, action);
  b.sizeToFit;
  const w = Math.max(150, b.frame.size.width + 20);
  ui.extra.addSubview(b); place(b, x, y, w, 32);
  return w;
}

function show() {
  const page = tour.pages[tour.index];
  const name = (st.setting.PreferredName || '').trim();
  clearExtra();
  let heading = '', body = '', extraH = 0;
  const EW = W - X0 - 48;
  switch (page) {
    case 'signin':   // (6.1.5)
      if (st.signin === 'out') {
        heading = 'Sign in with your Hub account';
        body = mustSignIn()
          ? 'This Mac belongs to TLA, so sign in with the account you use for the TLA Hub before you keep going. Click Sign in: your browser opens the Hub’s sign-in page.'
          : 'Sign in once with the account you use for the TLA Hub. Until you do, your choices are greyed out and you see TLA Classic. Click Sign in: your browser opens the Hub’s sign-in page.';
        extraButton('Sign in', 'signin:', 0, 0);
        ui.extraNote = label(tour.signinNote || '', 13, { wrap: true, color: rgb(255, 255, 255, 0.85) });
        ui.extra.addSubview(ui.extraNote); place(ui.extraNote, 0, 40, 560, 36);
        extraH = 78;
      } else {
        heading = 'You’re signed in';
        body = 'Your choices are yours to make now. Let’s set them up.';
      }
      break;
    case 'welcome':
      heading = name ? 'Welcome to TLA, ' + name + '!' : 'Welcome to TLA!';
      body = 'This Mac is all set up for you. Here’s a quick look at what makes it yours. It takes about a minute.';
      break;
    case 'name': {
      heading = 'What should we call you?';
      body = 'Your intro video greets you by name, like “Good morning, Sam!” You can change it any time in TLA BootPaper.';
      const box = C('NSTextField').alloc.initWithFrame(R(0, 0, 320, 30));
      box.placeholderString = 'Your preferred name'; box.font = $.NSFont.systemFontOfSize(17);
      box.stringValue = name;
      ui.extra.addSubview(box); place(box, 0, 0, 320, 30);
      ui.nameBox = box; extraH = 34;
      break;
    }
    case 'background': {
      heading = 'Pick your background';
      body = 'It goes on your desktop and lock screen. Each one has a light and a dark look that follows your Mac, and most have their own intro video.';
      const list = st.backgrounds.filter(b => b.id !== 'surprise' && (b.released || b.id === st.org.Background));
      // 6.0.5: one themed section at a time, starting with the one their background is in.
      const cats = st.categories.concat([{ id: 'own', name: 'Your pictures' }]).filter(c => list.some(b => b.group === c.id));
      tour.cats = cats;
      if (!cats.some(c => c.id === tour.cat)) {
        const cur = list.find(b => b.id === st.current);
        tour.cat = cur && cats.some(c => c.id === cur.group) ? cur.group : (cats[0] || {}).id;
      }
      const seg = C('NSSegmentedControl').segmentedControlWithLabelsTrackingModeTargetAction($(cats.map(c => c.name)), 0, ui.target, 'cat:');
      seg.selectedSegment = Math.max(0, cats.findIndex(c => c.id === tour.cat));
      try { seg.controlSize = 3; } catch (e) { }   // (large, macOS 11 and later)
      seg.sizeToFit;
      ui.extra.addSubview(seg); place(seg, 0, 0, Math.min(EW, seg.frame.size.width), Math.max(28, seg.frame.size.height));
      const top = Math.max(28, seg.frame.size.height) + 16;
      const shown = list.filter(b => b.group === tour.cat);
      const cols = 6, tw = 134, th = 75, gap = 10;
      shown.forEach((b, i) => {
        const x = (i % cols) * (tw + gap), y = top + Math.floor(i / cols) * (th + 26 + (shown.some(s => s.caption) ? 14 : 0));
        const frame = $.NSBox.alloc.initWithFrame(R(x - 3, y - 3, tw + 6, th + 6));
        frame.boxType = 4; frame.borderWidth = 3; frame.cornerRadius = 8; frame.titlePosition = 0;
        frame.fillColor = $.NSColor.clearColor;
        frame.borderColor = b.id === st.current ? rgb(242, 184, 48) : $.NSColor.clearColor;
        ui.extra.addSubview(frame);
        const btn = $.NSButton.alloc.initWithFrame(R(x, y, tw, th));
        btn.bordered = false; btn.title = '';
        const img = C('NSImage').alloc.initWithContentsOfFile(b.thumb);
        if (!img.isNil()) btn.image = img;
        btn.imageScaling = 3; btn.wantsLayer = true; btn.layer.cornerRadius = 5; btn.layer.masksToBounds = true;
        btn.tag = st.backgrounds.indexOf(b); btn.target = ui.target; btn.action = 'tile:'; btn.toolTip = b.name;
        ui.extra.addSubview(btn);
        const l = label(b.name, 12, { color: rgb(255, 255, 255, b.id === st.current ? 1 : 0.85), bold: b.id === st.current });
        ui.extra.addSubview(l); place(l, x, y + th + 3, tw, 16);
        if (b.caption) { const c = label(b.caption, 11, { color: rgb(255, 255, 255, 0.6) }); ui.extra.addSubview(c); place(c, x, y + th + 19, tw, 15); }   // (6.1.0)
      });
      // (room for the biggest section, so the page doesn't jump between sections)
      const most = Math.max.apply(null, cats.map(c => list.filter(b => b.group === c.id).length).concat([1]));
      extraH = top + Math.min(2, Math.ceil(most / cols)) * (th + 26) + 14;
      break;
    }
    case 'password':
      heading = 'Change your password';
      body = 'As a TLA teacher, you’re required to change the password this Mac came with to a secure one that only you know: long, and not one you use anywhere else. Click Change password, then Change… next to Password.';
      extraButton('Change password', 'password:', 0, 0); extraH = 36;
      break;
    case 'touchid':
      heading = 'Unlock with your fingerprint';
      body = 'This Mac has Touch ID (the key at the top right of the keyboard). Add your fingerprint: it’s faster than typing your password, and just as safe. You can do it any time in System Settings, under Touch ID & Password.';
      extraButton('Set up Touch ID', 'touchid:', 0, 0); extraH = 36;
      break;
    case 'calls': {
      heading = 'Look great on calls';
      body = st.teams === '1'
        ? 'The TLA backgrounds go straight into Microsoft Teams: in a meeting, choose More > Video effects. For Zoom and other apps, open the pictures and add them there.'
        : 'Use the TLA backgrounds on your video calls: open the pictures, then add them in Zoom or your call app’s background settings.';
      let x = 0;
      if (st.teams === '1' && tour.teams !== 'added') x += extraButton(tour.teams ? 'Try again' : 'Add to Teams', 'teams:', 0, 0) + 10;
      extraButton('Open the pictures', 'pictures:', x, 0);
      ui.extraNote = label(tour.teamsNote || '', 13, { wrap: true, color: rgb(255, 255, 255, 0.85) });
      ui.extra.addSubview(ui.extraNote); place(ui.extraNote, 0, 40, 560, 36);
      extraH = 78;
      break;
    }
    case 'care':
      heading = 'Help is one click away';
      body = 'TLA Care keeps an eye on your Mac and fixes common problems for you: open it with Check my Mac in TLA BootPaper. Something not working? Click Report a problem: your Mac’s details go along, so the helpdesk can help faster.';
      extraButton('Check my Mac', 'care:', 0, 0); extraH = 36;
      break;
    case 'connect':
      heading = 'Connect to TLA';
      body = 'This Mac isn’t connected to TLA yet, so it’s missing what TLA sends: the TLA new tab page in Chrome and Edge, apps and updates. Click Connect to TLA, sign in to Company Portal with your TLA account and follow the steps. You’ll need this Mac’s administrator password.';
      extraButton('Connect to TLA', 'connect:', 0, 0); extraH = 36;
      break;
    case 'done':
      heading = 'You’re all set!';
      body = 'Have a great year. You’ll find all of this again in TLA BootPaper, in your Applications folder.';
      break;
  }
  ui.heading.stringValue = heading; ui.body.stringValue = body;
  // Words in the middle of the card, buttons at the bottom.
  const hh = fitHeight(ui.heading, 640) + 2, bh = fitHeight(ui.body, 540) + 6;   // (a little spare, so nothing's cut off)
  const total = hh + 12 + bh + (extraH ? 18 + extraH : 0);
  let y = Math.max(96, Math.round(96 + (H - 96 - 96 - total) / 2));
  place(ui.heading, X0, y, 640, hh); y += hh + 12;
  place(ui.body, X0, y, 540, bh); y += bh + 18;
  place(ui.extra, X0, y, EW, Math.max(extraH, 1));
  ui.extra.hidden = !extraH;
  // Buttons and dots.
  ui.next.title = page === 'done' ? 'Get started' : page === 'welcome' ? 'Let’s go' : 'Next';
  ui.next.sizeToFit; ui.back.sizeToFit;
  const nw = Math.max(120, ui.next.frame.size.width + 24), bw2 = Math.max(90, ui.back.frame.size.width + 20);
  place(ui.next, W - 48 - nw, H - 36 - 34, nw, 34);
  place(ui.back, W - 48 - nw - 10 - bw2, H - 36 - 34, bw2, 34);
  ui.back.hidden = tour.index === 0;
  ui.skip.hidden = page === 'done' || mustSignIn();
  ui.skip.enabled = !ui.skip.hidden;   // (so Esc doesn't skip it either)
  ui.dots.forEach(d => d.removeFromSuperview);
  ui.dots = tour.pages.map((p, i) => {
    const d = $.NSBox.alloc.initWithFrame(R(X0 + i * 18, H - 36 - 22, i === tour.index ? 22 : 8, 8));
    d.boxType = 4; d.borderWidth = 0; d.cornerRadius = 4; d.titlePosition = 0;
    d.fillColor = i === tour.index ? rgb(242, 184, 48) : rgb(255, 255, 255, 0.45);
    if (i > tour.index) place(d, X0 + i * 18 + 14, H - 36 - 22, 8, 8);
    ui.doc.addSubview(d);
    return d;
  });
  if (ui.nameBox) ui.win.makeFirstResponder(ui.nameBox);
  // 5.1: the TLA backgrounds go into Teams by themselves the first time this page shows (macOS may ask to allow it).
  if (page === 'calls' && st.teams === '1' && !tour.teams && !tour.test) addToTeams();
}

function saveName() {
  if (!ui.nameBox) return;
  const v = ui.nameBox.stringValue.js.replace(/\s+/g, ' ').trim().slice(0, 30);
  if (v !== (st.setting.PreferredName || '').trim()) { sh(['--save', 'PreferredName', v]); st.setting.PreferredName = v; }
}
function go(step) {
  if (tour.pages[tour.index] === 'name') saveName();
  if (tour.pages[tour.index] === 'signin') {
    st = loadState();   // (6.1.5: signed in by now, maybe)
    if (step > 0 && mustSignIn()) {   // (6.2.5)
      tour.signinNote = tour.signinNote
        ? 'You’re not signed in yet. Finish signing in in your browser, then click Next.'
        : 'Sign in first: click Sign in above.';
      show(); return;
    }
  }
  if (step > 0 && tour.index === tour.pages.length - 1) { finish(); return; }
  tour.index = Math.max(0, Math.min(tour.pages.length - 1, tour.index + step));
  show();
}
function finish() {
  if (mustSignIn()) return;   // (6.2.5)
  if (tour.pages[tour.index] === 'name') saveName();
  sh(['--tour-done']);
  quit = true;
}
function pickBackground(index) {
  const b = st.backgrounds[index];
  if (!b) return;
  sh(['--save', 'Background', b.id]);
  st = loadState(); setPicture(); show();
}
function addToTeams() {
  tour.teams = 'working';
  stepAside();   // (5.2.5: so macOS's "Allow" question can show in front)
  if (ui.extraNote) { ui.extraNote.stringValue = 'Adding them to Teams… If macOS asks, choose Allow.'; pump(4); }
  const r = sh(['--calls', 'add']).trim();
  tour.teams = /^added/.test(r) ? 'added' : 'failed';
  tour.teamsNote = /^added/.test(r) ? 'Done: they’re in Teams. In a meeting, choose More > Video effects.'
    : r === 'denied' ? 'macOS didn’t allow it. Click Try again and choose Allow, or open the pictures and add them in Teams.'
    : 'Couldn’t add them right now. You can do it later in TLA BootPaper.';
  st = loadState();
  if (tour.pages[tour.index] === 'calls') show();
}

function run(argv) {
  try {
    SCRIPT = argv[0]; MODE = argv[1] || 'app';
    st = loadState();
    if (!st.release) return 'error: no settings';
    const app = $.NSApplication.sharedApplication;
    app.setActivationPolicy(1);
    app.finishLaunching;
    build();
    tour.pages = pages();
    setPicture(); show();
    bringToFront(app, ui.win);
    const test = $.NSProcessInfo.processInfo.environment.objectForKey('TB_TEST');
    if (!test.isNil()) return selfTest(app, test.js);
    while (!quit) {
      const ev = app.nextEventMatchingMaskUntilDateInModeDequeue(0xFFFFFFFF, $.NSDate.dateWithTimeIntervalSinceNow(0.25), 'kCFRunLoopDefaultMode', true);
      if (!ev.isNil()) app.sendEvent(ev);
    }
    ui.win.orderOut(null);
    return 'ok';
  } catch (e) {
    return 'error: ' + e;
  }
}

// Developer check (TB_TEST=<folder>): a picture of each page, then quits (nothing is saved). Not used normally.
function selfTest(app, dir) {
  const shot = name => {
    pump(8);
    const v = ui.win.contentView, rep = v.bitmapImageRepForCachingDisplayInRect(v.bounds);
    v.cacheDisplayInRectToBitmapImageRep(v.bounds, rep);
    rep.representationUsingTypeProperties(4, $({})).writeToFileAtomically(dir + '/' + name, true);
  };
  tour.test = true;
  tour.pages.forEach((p, i) => {
    tour.index = i; show(); shot('tour-' + (i + 1) + '-' + p + '.png');
    if (p === 'background') (tour.cats || []).forEach(c => { tour.cat = c.id; show(); shot('tour-' + (i + 1) + '-background-' + c.id + '.png'); });   // (6.0.5)
  });
  return 'ok (test)';
}

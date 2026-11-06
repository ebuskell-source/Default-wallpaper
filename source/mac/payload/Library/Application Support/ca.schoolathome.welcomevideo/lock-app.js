// lock-app.js - TLA BootPaper (6.2.5): on TLA's own Macs (Apple School Manager), a screen that covers everything until
// the person signs in with their Hub account: when their sign-in has run out, or they've never signed in. settings.zsh
// --lock-check starts it when it's needed (the LaunchAgent ca.schoolathome.welcomevideo.lock, every minute), and
// never while the Mac is offline, when they couldn't sign in anyway. While they sign in, their web browser may come
// in front of it; anything else, it covers again. Logging out and shutting down still work.
// 6.4.5: the Hub's sign-in page opens inside the lock screen (not in their browser), so nothing else can be used
// meanwhile. "signin" starts signing in straight away (the tour's Sign in button, on TLA's Macs).
//   welcome-video --jxa lock-app.js <settings.zsh> [signin]   prints "ok" once they're signed in
ObjC.import('AppKit');
// (6.4.5: methods that NSView or NSWindow already has are overridden without types: Objective-C's BOOL is a char on
// Intel Macs and a bool on Apple silicon, and the wrong one stops the script, so the Mac's own types are used.)
ObjC.import('WebKit');
const C = n => $.NSClassFromString(n);
const WV_DIR = '/Library/Application Support/ca.schoolathome.welcomevideo';
const BROWSERS = ['com.apple.Safari', 'com.google.Chrome', 'com.microsoft.edgemac', 'org.mozilla.firefox', 'com.brave.Browser',
                  'company.thebrowser.Browser', 'com.operasoftware.Opera'];
const LOCK_LEVEL = 1000;    // (above the menu bar, the Dock and other apps' windows)
let SCRIPT = '', quit = false;
const ui = {};
// (centred: NSTextAlignmentCenter is 1 on Apple silicon, 2 on Intel)
function machine() {
  const t = $.NSTask.alloc.init, p = $.NSPipe.pipe;
  t.launchPath = '/usr/bin/uname'; t.arguments = $(['-m']); t.standardOutput = p; t.launch; t.waitUntilExit;
  return ($.NSString.alloc.initWithDataEncoding(p.fileHandleForReading.readDataToEndOfFile, 4).js || '').trim();
}
const CENTRE = machine() === 'arm64' ? 1 : 2;
const R = (x, y, w, h) => $.NSMakeRect(x, y, w, h);
const rgb = (r, g, b, a) => $.NSColor.colorWithSRGBRedGreenBlueAlpha(r / 255, g / 255, b / 255, a === undefined ? 1 : a);

function sh(args, wait) {
  const t = $.NSTask.alloc.init;
  t.launchPath = '/bin/zsh';
  t.arguments = $([SCRIPT].concat(args));
  t.standardError = $.NSFileHandle.fileHandleWithNullDevice;
  if (wait === false) { t.standardOutput = $.NSFileHandle.fileHandleWithNullDevice; t.launch; return ''; }
  const pipe = $.NSPipe.pipe;
  t.standardOutput = pipe;
  t.launch;
  const data = pipe.fileHandleForReading.readDataToEndOfFile;
  t.waitUntilExit;
  return $.NSString.alloc.initWithDataEncoding(data, 4).js || '';
}
const signinState = () => (sh(['--signin', 'status']).split('\t')[0] || '').trim();
function label(text, size, opts) {
  opts = opts || {};
  const l = C('NSTextField').wrappingLabelWithString(text);
  l.font = opts.bold ? $.NSFont.boldSystemFontOfSize(size) : $.NSFont.systemFontOfSize(size);
  l.textColor = opts.color || $.NSColor.whiteColor;
  l.alignment = CENTRE;
  return l;
}

ObjC.registerSubclass({
  name: 'TLWindow', superclass: 'NSWindow',
  methods: {
    canBecomeKeyWindow:  { implementation: function () { return true; } },
    canBecomeMainWindow: { implementation: function () { return true; } },
  },
});
ObjC.registerSubclass({
  name: 'TLTarget', superclass: 'NSObject',
  methods: {
    'signin:': { types: ['void', ['id']], implementation: function (s) { startSignin(); } },
    'logout:': { types: ['void', ['id']], implementation: function (s) {
      stepAside();
      $.NSAppleScript.alloc.initWithSource('tell application "loginwindow" to «event aevtlogo»').executeAndReturnError(null);
    } },
    'tick:': { types: ['void', ['id']], implementation: function (t) { try { tick(); } catch (e) { } } },
    'cancelSignin:': { types: ['void', ['id']], implementation: function (s) { stopSignin(''); } },
    // A link that opens a new window (some sign-in pages do): opened in the same place instead.
    'webView:createWebViewWithConfiguration:forNavigationAction:windowFeatures:': { types: ['id', ['id', 'id', 'id', 'id']],
      implementation: function (w, c, a, f) { try { if (!a.request.URL.isNil()) w.loadRequest(a.request); } catch (e) { } return null; } },
    // Quit (from logging out or shutting down) and "open it again": handled here, not by the script engine.
    'handleQuit:withReplyEvent:': { types: ['void', ['id', 'id']], implementation: function (e, r) { quit = true; stopApp(); } },
    'handleReopen:withReplyEvent:': { types: ['void', ['id', 'id']], implementation: function (e, r) { if (!ui.signing) lockDown(); } },
  },
});

function build() {
  ui.target = $.TLTarget.alloc.init;
  const sf = $.NSScreen.mainScreen.frame, SW = Math.round(sf.size.width), SH = Math.round(sf.size.height);
  const win = $.TLWindow.alloc.initWithContentRectStyleMaskBackingDefer(sf, 0, 2, false);
  win.setFrameDisplay(sf, true);
  win.hasShadow = false; win.releasedWhenClosed = false; win.title = 'TLA BootPaper';
  win.collectionBehavior = 1 | 16 | 256;   // (on every Space, staying put, over full-screen apps)
  win.appearance = $.NSAppearance.appearanceNamed('NSAppearanceNameDarkAqua');
  win.backgroundColor = rgb(11, 27, 51);
  ui.win = win;
  const root = win.contentView;
  // TLA Classic, darkened, behind the words.
  const img = C('NSImage').alloc.initWithContentsOfFile(WV_DIR + '/Backgrounds/tla-dark.jpg');
  if (!img.isNil()) {
    const iv = C('NSImageView').alloc.initWithFrame(R(0, 0, SW, SH));
    iv.image = img; iv.imageScaling = 3; iv.alphaValue = 0.35; root.addSubview(iv);
  }
  const W = Math.min(640, SW - 80), X = (SW - W) / 2;
  let y = SH / 2 + 150;   // (from the bottom: AppKit's coordinates)
  const icon = C('NSImage').alloc.initWithContentsOfFile(WV_DIR + '/AppIcon.png');
  if (!icon.isNil()) { const v = C('NSImageView').alloc.initWithFrame(R(SW / 2 - 40, y, 80, 80)); v.image = icon; v.imageScaling = 3; root.addSubview(v); }
  y -= 70;
  ui.heading = label('Sign in to keep using this Mac', 34, { bold: true });
  ui.heading.setFrame(R(X, y, W, 46)); root.addSubview(ui.heading);
  y -= 80;
  ui.body = label('', 17, { color: rgb(255, 255, 255, 0.88) });
  ui.body.setFrame(R(X, y, W, 72)); root.addSubview(ui.body);
  y -= 56;
  ui.btn = $.NSButton.buttonWithTitleTargetAction('Sign in', ui.target, 'signin:');
  ui.btn.keyEquivalent = '\r'; ui.btn.controlSize = 3; ui.btn.sizeToFit;
  try { ui.btn.bezelColor = $.NSColor.controlAccentColor; } catch (e) { }
  const bw = Math.max(200, ui.btn.frame.size.width + 40);
  ui.btn.setFrame(R(SW / 2 - bw / 2, y, bw, 40)); root.addSubview(ui.btn);
  y -= 70;
  ui.note = label('', 14, { color: rgb(255, 255, 255, 0.8) });
  ui.note.setFrame(R(X, y, W, 54)); root.addSubview(ui.note);
  ui.logout = $.NSButton.buttonWithTitleTargetAction('Log out', ui.target, 'logout:');
  ui.logout.sizeToFit;
  ui.logout.setFrame(R(SW / 2 - 60, 48, 120, 30)); root.addSubview(ui.logout);
  const help = label('Need help? Email helpdesk@schoolathome.ca', 12, { color: rgb(255, 255, 255, 0.6) });
  help.setFrame(R(X, 20, W, 20)); root.addSubview(help);
}

function lockDown() {
  const app = $.NSApplication.sharedApplication;
  ui.win.level = LOCK_LEVEL;
  ui.win.makeKeyAndOrderFront(null); ui.win.orderFrontRegardless;
  try { if (app.respondsToSelector('activate')) app.activate; else app.activateIgnoringOtherApps(true); } catch (e) { }
  // (no Dock, menu bar, app switching or Force Quit while it's up)
  try { app.presentationOptions = 2 | 8 | 32 | 64 | 256; } catch (e) { }
}
function stepAside() {
  try { $.NSApplication.sharedApplication.presentationOptions = 0; } catch (e) { }
  ui.win.level = 0;
}
function words() {
  const out = ui.signedInBefore;
  ui.body.stringValue = out
    ? 'Your Hub sign-in has run out. Sign in again with the account you use for the TLA Hub to keep using this Mac.'
    : 'Before you can use this Mac, sign in once with the account you use for the TLA Hub.';
}

// The sign-in page, in a panel over the lock screen (a Safari-like name, since some sign-in pages turn away apps).
const SAFARI = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15';
function showPage(url) {
  const root = ui.win.contentView, f = root.frame;
  const W = Math.min(560, f.size.width - 60), H = Math.min(700, f.size.height - 120);
  const X = (f.size.width - W) / 2, Y = (f.size.height - H) / 2 + 20;
  const box = $.NSBox.alloc.initWithFrame(R(X - 1, Y - 1, W + 2, H + 2));
  box.boxType = 4; box.borderWidth = 0; box.cornerRadius = 14; box.titlePosition = 0; box.fillColor = $.NSColor.whiteColor;
  root.addSubview(box);
  const cfg = $.WKWebViewConfiguration.alloc.init;
  cfg.websiteDataStore = $.WKWebsiteDataStore.nonPersistentDataStore;   // (nothing kept afterwards)
  const web = $.WKWebView.alloc.initWithFrameConfiguration(R(X, Y, W, H), cfg);
  web.customUserAgent = SAFARI; web.UIDelegate = ui.target;
  web.wantsLayer = true; web.layer.cornerRadius = 12; web.layer.masksToBounds = true;
  root.addSubview(web);
  const cancel = $.NSButton.buttonWithTitleTargetAction('Cancel', ui.target, 'cancelSignin:');
  cancel.sizeToFit; cancel.setFrame(R(f.size.width / 2 - 60, Y - 46, 120, 30)); root.addSubview(cancel);
  ui.page = [box, web, cancel];
  web.loadRequest($.NSURLRequest.requestWithURL($.NSURL.URLWithString(url)));
  ui.win.makeFirstResponder(web);
  [ui.heading, ui.body, ui.btn, ui.note, ui.logout].forEach(v => { v.hidden = true; });
}
function hidePage() {
  (ui.page || []).forEach(v => v.removeFromSuperview);
  ui.page = null;
  [ui.heading, ui.body, ui.btn, ui.note, ui.logout].forEach(v => { v.hidden = false; });
}
function startSignin() {
  if (ui.signing) return;
  const f = sh(['--signin', 'start', 'embed']).trim();
  let url = '';
  try { url = $.NSString.stringWithContentsOfFileEncodingError(f.replace(/answer$/, 'url'), 4, null).js.trim(); } catch (e) { }
  if (!f || !/^https:\/\//.test(url)) { ui.note.stringValue = 'Couldn’t start signing in. Try again in a moment.'; if (f) sh(['--signin', 'cancel', f]); return; }
  ui.signing = { file: f, until: Date.now() + 10 * 60 * 1000 };
  ui.btn.enabled = false;
  showPage(url);
}
function stopSignin(note) {
  if (ui.signing) sh(['--signin', 'cancel', ui.signing.file]);
  ui.signing = null; ui.btn.enabled = true;
  hidePage();
  if (note !== undefined) ui.note.stringValue = note;
  lockDown();
}

function tick() {
  const now = Date.now();
  if (ui.signing) {
    if ($.NSFileManager.defaultManager.fileExistsAtPath(ui.signing.file)) {
      const r = sh(['--signin', 'finish', ui.signing.file]).trim().split('\t');
      ui.signing = null; ui.btn.enabled = true; hidePage();
      if (r[0] === 'ok') { ui.note.stringValue = 'Signed in. Unlocking…'; ui.waitUntil = now + 75000; ui.nextCheck = 0; }
      else ui.note.stringValue = r[1] || 'Signing in didn’t finish. Try again.';
      lockDown();
    } else if (now > ui.signing.until) {
      stopSignin('Signing in took too long. Try again.');
    } else if (!$.NSApplication.sharedApplication.isActive) {
      lockDown();
    }
  } else if (!$.NSApplication.sharedApplication.isActive) {
    lockDown();
  }
  // Signed in (here, in the app, or from another window)? Then it's done.
  if (now >= (ui.nextCheck || 0)) {
    ui.nextCheck = now + (ui.waitUntil && now < ui.waitUntil ? 2000 : 5000);
    if (signinState() !== 'out') { quit = true; stopApp(); }
    else if (ui.waitUntil && now > ui.waitUntil) { ui.waitUntil = 0; ui.note.stringValue = 'Couldn’t finish signing in. Try again in a minute.'; }
  }
}

function stopApp() {
  const app = $.NSApplication.sharedApplication;
  if (ui.signing) { sh(['--signin', 'cancel', ui.signing.file]); ui.signing = null; }   // (signed in some other way meanwhile)
  if (ui.timer) { ui.timer.invalidate; ui.timer = null; }
  if (!app.isRunning) return;
  app.stop(null);
  const ev = $.NSEvent.otherEventWithTypeLocationModifierFlagsTimestampWindowNumberContextSubtypeData1Data2(15, $.NSMakePoint(0, 0), 0, 0, 0, null, 0, 0, 0);
  if (ev && !ev.isNil()) app.postEventAtStart(ev, true);
}

function run(argv) {
  try {
    SCRIPT = argv[0];
    if (signinState() !== 'out') return 'ok (signed in)';
    const app = $.NSApplication.sharedApplication;
    app.setActivationPolicy(1);   // (no Dock icon of its own)
    app.finishLaunching;
    const m = $.NSAppleEventManager.sharedAppleEventManager;
    build();
    m.setEventHandlerAndSelectorForEventClassAndEventID(ui.target, 'handleQuit:withReplyEvent:', 0x61657674, 0x71756974);
    m.setEventHandlerAndSelectorForEventClassAndEventID(ui.target, 'handleReopen:withReplyEvent:', 0x61657674, 0x72617070);
    ui.signedInBefore = (sh(['--signin', 'status']).split('\t')[6] || '') === 'expired';
    words();
    lockDown();
    if (argv[1] === 'signin') startSignin();
    const test = $.NSProcessInfo.processInfo.environment.objectForKey('TB_TEST');
    if (!test.isNil()) {   // (developer check: a picture of it, then it closes)
      for (let i = 0; i < 20; i++) { const ev = app.nextEventMatchingMaskUntilDateInModeDequeue(0xFFFFFFFF, $.NSDate.dateWithTimeIntervalSinceNow(0.05), 'kCFRunLoopDefaultMode', true); if (!ev.isNil()) app.sendEvent(ev); }
      const t = $.NSTask.alloc.init; t.launchPath = '/usr/sbin/screencapture'; t.arguments = $(['-x', test.js + '/lock.png']); t.launch; t.waitUntilExit;
      stepAside(); return 'ok (test)';
    }
    ui.timer = $.NSTimer.timerWithTimeIntervalTargetSelectorUserInfoRepeats(1, ui.target, 'tick:', null, true);
    $.NSRunLoop.currentRunLoop.addTimerForMode(ui.timer, 'kCFRunLoopCommonModes');
    app.run;
    stepAside();
    ui.win.orderOut(null);
    return 'ok';
  } catch (e) {
    return 'error: ' + e;
  }
}

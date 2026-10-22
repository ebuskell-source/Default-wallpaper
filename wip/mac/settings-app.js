// settings-app.js - the TLA BootPaper app window on Macs (the same layout as the Windows app).
//   osascript -l JavaScript settings-app.js <settings.zsh>
// settings.zsh does the work (it knows the organization defaults and the rules): "--state" describes what
// to show, "--save <setting> <value>", "--reset" and "--play" make changes, "--whatsnew" gives the release log.
// Changes save as soon as they're made. Prints "ok", or "error: ..." (settings.zsh then falls back to the
// simple swiftDialog window).
// 4.3: "Report a problem" (its own window: a short form, then an email to the helpdesk with this Mac's details;
// "--report" as the second argument opens just that), and release channels (Stable or Experimental, under
// "Updates"): backgrounds and videos not out on someone's channel aren't shown to them.
// 5.0: "Light or dark" (the pictures follow macOS's appearance), "Screensaver, calls and reminders" (the TLA
// screensaver, TLA backgrounds for Teams, TLA Care's reminders), "Check my Mac" (TLA Care, its own window:
// care-app.js), the Welcome to TLA tour (tour-app.js), and "Prepare for initial unboxing" (once per Mac).
// 5.1: the backgrounds and the "Which video" list are grouped: themes with an intro video for light and for dark
// mode, then themes with one intro video (every theme has a light and a dark picture). The Experimental background
// has its own group, for people on the Experimental channel only.
// 5.5.5: a new look (sections in rounded cards, switches), and the greeting can be turned off without clearing the name.
ObjC.import('AppKit');
// Some classes aren't bridged as $.Name on current macOS; looking them up by name always works.
const C = n => $.NSClassFromString(n);

let SCRIPT = '';        // settings.zsh (from the command line)
let quit = false;
let ui = {};          // controls
let st = {};          // state from settings.zsh
let handlers = {};
const running = [];     // (5.1: tasks started without waiting, kept until they finish)

// ---- talking to settings.zsh ---------------------------------------------------------------------------------
function sh(args, wait) {
  const t = $.NSTask.alloc.init;
  t.launchPath = '/bin/zsh';
  t.arguments = $([SCRIPT].concat(args));
  if (wait === false) {
    t.standardOutput = $.NSFileHandle.fileHandleWithNullDevice;
    t.standardError = $.NSFileHandle.fileHandleWithNullDevice;
    t.launch;
    running.push(t);
    return '';
  }
  const pipe = $.NSPipe.pipe;
  t.standardOutput = pipe;
  t.standardError = $.NSFileHandle.fileHandleWithNullDevice;
  t.launch;
  const data = pipe.fileHandleForReading.readDataToEndOfFile;
  t.waitUntilExit;
  return $.NSString.alloc.initWithDataEncoding(data, 4).js || '';
}

function loadState() {
  const s = { setting: {}, org: {}, backgrounds: [], videos: [], when: [], quiet: [], season: null,
              fits: [], pickfor: [], temp: null, channels: [], features: {}, lightdark: [], ss: { status: '', setup: '' } };
  sh(['--state']).split('\n').forEach(line => {
    const f = line.split('\t');
    if (f[0] === 'setting') s.setting[f[1]] = f[2] || '';
    else if (f[0] === 'feature') s.features[f[1]] = f[2] === '1';           // (5.0)
    else if (f[0] === 'lightdark') s.lightdark.push({ id: f[1], name: f[2] });
    else if (f[0] === 'ssstatus') s.ss = { status: f[1] || '', setup: f[2] || '' };
    else if (f[0] === 'season') s.season = { id: f[1], name: f[2], ends: f[3], thumb: f[4], hasfile: f[5] === '1' };
    else if (f[0] === 'fit') s.fits.push({ id: f[1], name: f[2] });
    else if (f[0] === 'pickfor') s.pickfor.push({ id: f[1], name: f[2] });
    else if (f[0] === 'temp') s.temp = { id: f[1], name: f[2], until: f[3], after: f[4] };
    else if (f[0] === 'quiet') s.quiet.push({ id: f[1], name: f[2] });
    else if (f[0] === 'org') s.org[f[1]] = f[2];
    else if (f[0] === 'bg') s.backgrounds.push({ id: f[1], name: f[2], video: f[3] === '1', thumb: f[4], hasfile: f[5] === '1', released: f[6] !== '0',
                                                 both: f[7] === '1', only: f[8] || '' });   // (5.1)
    else if (f[0] === 'video') s.videos.push({ id: f[1], name: f[2], released: f[3] !== '0', both: f[4] === '1' });
    else if (f[0] === 'chan') s.channels.push({ id: f[1], name: f[2], release: f[3] });
    else if (f[0] === 'when') s.when.push({ id: f[1], name: f[2] });
    else if (f[0]) s[f[0]] = f[1];
  });
  return s;
}

// ---- small helpers -------------------------------------------------------------------------------------------
const R = (x, y, w, h) => $.NSMakeRect(x, y, w, h);
function label(text, size, opts) {
  opts = opts || {};
  const l = opts.wrap ? C('NSTextField').wrappingLabelWithString(text) : C('NSTextField').labelWithString(text);
  l.font = opts.bold ? $.NSFont.boldSystemFontOfSize(size) : $.NSFont.systemFontOfSize(size);
  if (opts.grey) l.textColor = $.NSColor.secondaryLabelColor;
  if (opts.light) l.textColor = $.NSColor.tertiaryLabelColor;
  return l;
}
function place(view, x, y, w, h) { view.setFrame(R(x, y, w, h)); }
function fitHeight(l, w) { l.preferredMaxLayoutWidth = w; return Math.ceil(l.fittingSize.height); }
function linkButton(title, action) {
  const b = $.NSButton.buttonWithTitleTargetAction(title, ui.target, action);
  b.bordered = false;
  b.contentTintColor = $.NSColor.linkColor;     // shows as a link
  b.sizeToFit;
  return b;
}

ObjC.registerSubclass({
  name: 'TBFlipped', superclass: 'NSView',
  methods: { isFlipped: { types: ['bool', []], implementation: function () { return true; } } },
});
ObjC.registerSubclass({
  name: 'TBTarget', superclass: 'NSObject',
  methods: {
    'enabled:':  { types: ['void', ['id']], implementation: function (s) { handlers.enabled(s); } },
    'check:':    { types: ['void', ['id']], implementation: function (s) { handlers.check(s); } },
    'video:':    { types: ['void', ['id']], implementation: function (s) { handlers.video(s); } },
    'when:':     { types: ['void', ['id']], implementation: function (s) { handlers.when(s); } },
    'tile:':     { types: ['void', ['id']], implementation: function (s) { handlers.tile(s); } },
    'seasonal:': { types: ['void', ['id']], implementation: function (s) { handlers.seasonal(); } },
    'quiet:':    { types: ['void', ['id']], implementation: function (s) { handlers.quiet(s); } },
    'qtime:':    { types: ['void', ['id']], implementation: function (s) { handlers.qtime(s); } },
    'day:':      { types: ['void', ['id']], implementation: function (s) { handlers.day(s); } },
    'name:':     { types: ['void', ['id']], implementation: function (s) { handlers.name(); } },
    'saveName:': { types: ['void', ['id']], implementation: function (s) { handlers.name(true); } },
    'greeting:': { types: ['void', ['id']], implementation: function (s) { handlers.greeting(s); } },   // (5.5.5)
    'controlTextDidChange:': { types: ['void', ['id']], implementation: function (n) { handlers.nameTyped(); } },
    'reset:':    { types: ['void', ['id']], implementation: function (s) { handlers.reset(); } },
    'whatsNew:': { types: ['void', ['id']], implementation: function (s) { handlers.whatsNew(); } },
    'helpdesk:': { types: ['void', ['id']], implementation: function (s) { handlers.helpdesk(); } },
    'channel:':  { types: ['void', ['id']], implementation: function (s) { handlers.channel(s); } },
    'report:':   { types: ['void', ['id']], implementation: function (s) { openReport(); } },
    'reportTopic:':  { types: ['void', ['id']], implementation: function (s) { reportReady(); } },
    'reportSend:':   { types: ['void', ['id']], implementation: function (s) { reportSend(); } },
    'reportCopy:':   { types: ['void', ['id']], implementation: function (s) { reportCopy(); } },
    'reportCancel:': { types: ['void', ['id']], implementation: function (s) { if (ui.report) ui.report.close; } },
    'textDidChange:': { types: ['void', ['id']], implementation: function (n) { reportReady(); } },
    'play:':     { types: ['void', ['id']], implementation: function (s) { handlers.play(); } },
    'playQuiet:': { types: ['void', ['id']], implementation: function (s) { handlers.play('-', 'mute'); } },
    'preview:':  { types: ['void', ['id']], implementation: function (s) { handlers.play(st.backgrounds[Number(s.tag)].id); } },
    'previewSeason:': { types: ['void', ['id']], implementation: function (s) { handlers.play(st.season.id); } },
    'fit:':      { types: ['void', ['id']], implementation: function (s) { handlers.fit(s); } },
    'lock:':     { types: ['void', ['id']], implementation: function (s) { handlers.lock(s); } },
    'untemp:':   { types: ['void', ['id']], implementation: function (s) { handlers.untemp(); } },
    'close:':    { types: ['void', ['id']], implementation: function (s) { handlers.name(); quit = true; } },
    // 5.0
    'lightdark:':   { types: ['void', ['id']], implementation: function (s) { handlers.lightdark(s); } },
    'screensaver:': { types: ['void', ['id']], implementation: function (s) { handlers.screensaver(s); } },
    'reminders:':   { types: ['void', ['id']], implementation: function (s) { handlers.reminders(s); } },
    'callsAdd:':    { types: ['void', ['id']], implementation: function (s) { handlers.calls('add'); } },
    'callsRemove:': { types: ['void', ['id']], implementation: function (s) { handlers.calls('remove'); } },
    'callsOpen:':   { types: ['void', ['id']], implementation: function (s) { sh(['--calls', 'open'], false); } },
    'care:':        { types: ['void', ['id']], implementation: function (s) { sh(['--care'], false); } },
    'tour:':        { types: ['void', ['id']], implementation: function (s) { sh(['--tour'], false); } },
    'unbox:':       { types: ['void', ['id']], implementation: function (s) { handlers.unbox(); } },
    'connect:':     { types: ['void', ['id']], implementation: function (s) { sh(['--open', 'connect'], false); } },
    'windowDidResize:': { types: ['void', ['id']], implementation: function (n) { layout(); } },
    'windowWillClose:': { types: ['void', ['id']], implementation: function (n) {
      if (ui.window && n.object.isEqual(ui.window)) { handlers.name(); quit = true; }
      if (ui.report && n.object.isEqual(ui.report)) { ui.reportOpen = false; if (!ui.window) quit = true; } } },
  },
});

// ---- building the window ---------------------------------------------------------------------------------------
// 5.5.5: a new look, like System Settings: each section's options in a rounded card (a label on the left, its switch
// or menu on the right), section headings with a symbol, switches instead of checkboxes, and menus instead of the
// "When to play it" choices. The greeting can be turned off without clearing the name.
const rgb = (r, g, b, a) => $.NSColor.colorWithSRGBRedGreenBlueAlpha(r / 255, g / 255, b / 255, a === undefined ? 1 : a);
function box(fill, border, radius) {
  const b = $.NSBox.alloc.initWithFrame(R(0, 0, 10, 10));
  b.boxType = 4; b.titlePosition = 0; b.borderWidth = border ? 1 : 0; b.cornerRadius = radius || 10;
  b.fillColor = fill; b.borderColor = border || $.NSColor.clearColor;
  return b;
}
function symbol(name, size) {
  let img = null;
  try { img = C('NSImage').imageWithSystemSymbolNameAccessibilityDescription(name, null); } catch (e) { img = null; }
  const v = C('NSImageView').alloc.initWithFrame(R(0, 0, size, size));
  if (img && !img.isNil()) { v.image = img; v.contentTintColor = $.NSColor.controlAccentColor; v.imageScaling = 3; }
  else v.hidden = true;
  return v;
}
// An on/off switch (NSSwitch, macOS 10.15+); a checkbox where there isn't one.
function toggle(action) {
  const cls = C('NSSwitch');
  if (cls && !cls.isNil()) {
    const s = cls.alloc.initWithFrame(R(0, 0, 40, 22));
    s.target = ui.target; s.action = action;
    return s;
  }
  return $.NSButton.checkboxWithTitleTargetAction('', ui.target, action);
}

function build() {
  ui.target = $.TBTarget.alloc.init;
  const screen = $.NSScreen.mainScreen.visibleFrame;
  const w = Math.min(780, screen.size.width - 40), h = Math.min(900, screen.size.height - 40);
  const win = $.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer(R(0, 0, w, h), 1 | 2 | 4 | 8, 2, false);
  win.title = 'TLA BootPaper';
  win.releasedWhenClosed = false;
  win.contentMinSize = $.NSMakeSize(660, 420);
  win.delegate = ui.target;
  ui.window = win;
  const content = win.contentView;

  // Bottom bar (stays put; the rest scrolls)
  const bar = $.NSView.alloc.initWithFrame(R(0, 0, w, 78));
  bar.autoresizingMask = 2 | 32;
  const line = $.NSBox.alloc.initWithFrame(R(0, 77, w, 1)); line.boxType = 2; line.autoresizingMask = 2 | 8;
  bar.addSubview(line);
  ui.reset = linkButton("Use my organization's settings", 'reset:');
  ui.whatsNew = linkButton("What's new", 'whatsNew:');
  ui.version = label('Version ' + st.release, 11, { light: true });
  ui.play = $.NSButton.buttonWithTitleTargetAction('Play video now', ui.target, 'play:');
  try { ui.play.bezelColor = $.NSColor.controlAccentColor; } catch (e) { }   // (the main button, in the accent colour)
  ui.close = $.NSButton.buttonWithTitleTargetAction('Close', ui.target, 'close:');
  ui.close.keyEquivalent = '\u001b';
  // 4.2: the same, without sound (a small link under the button, so the bar stays uncluttered).
  ui.playQuiet = linkButton('Play without sound', 'playQuiet:');
  ui.playQuiet.font = $.NSFont.systemFontOfSize(11); ui.playQuiet.sizeToFit;
  ui.tourLink = linkButton('Take the Welcome to TLA tour', 'tour:');      // (5.0)
  [ui.reset, ui.whatsNew, ui.version, ui.play, ui.close, ui.playQuiet, ui.tourLink].forEach(v => bar.addSubview(v));
  content.addSubview(bar);
  ui.bar = bar;

  const scroll = C('NSScrollView').alloc.initWithFrame(R(0, 78, w, h - 78));
  scroll.hasVerticalScroller = true;
  scroll.autohidesScrollers = true;
  scroll.drawsBackground = false;
  scroll.autoresizingMask = 2 | 16;
  const doc = $.TBFlipped.alloc.initWithFrame(R(0, 0, w, 1000));
  scroll.documentView = doc;
  content.addSubview(scroll);
  ui.scroll = scroll; ui.doc = doc;

  const add = v => { doc.addSubview(v); return v; };
  // The cards go in first, so everything else is in front of them.
  const cardFill = $.NSColor.controlBackgroundColor, cardLine = $.NSColor.separatorColor;
  ui.cardVideo = add(box(cardFill, cardLine)); ui.cardBg = add(box(cardFill, cardLine));
  ui.cardExtras = add(box(cardFill, cardLine)); ui.cardUpdates = add(box(cardFill, cardLine));
  ui.seps = []; ui.sepUsed = 0;

  // Header: the app's icon, its name and what it's for.
  const icon = C('NSImage').alloc.initWithContentsOfFile('/Library/Application Support/ca.schoolathome.welcomevideo/AppIcon.png');
  ui.icon = add(C('NSImageView').alloc.initWithFrame(R(0, 0, 52, 52)));
  if (!icon.isNil()) { ui.icon.image = icon; ui.icon.imageScaling = 3; } else ui.icon.hidden = true;
  ui.title = add(label('TLA BootPaper', 24, { bold: true }));
  ui.subtitle = add(label('Choose how your welcome video plays and pick your background for the desktop and lock screen.', 13, { grey: true, wrap: true }));

  // Where to send requests, bug reports and ideas (3.3.9): always shown, near the top. Fixed light colours,
  // like the note below, so it reads the same in light and dark mode.
  ui.helpBox = add(box(rgb(231, 240, 253), rgb(176, 205, 245)));
  ui.helpTitle = add(label('Something not working?', 13, { bold: true }));
  ui.helpText = add(label("Report it here and your Mac's details go along with it. For new background requests and ideas, email:", 13, { wrap: true }));
  // 4.3: Report a problem. 5.0: and TLA Care ("Check my Mac").
  ui.reportBtn = add($.NSButton.buttonWithTitleTargetAction('Report a problem', ui.target, 'report:'));
  ui.careBtn = add($.NSButton.buttonWithTitleTargetAction('Check my Mac', ui.target, 'care:'));
  // (5.0: light buttons on the light boxes, in dark mode too)
  const aqua = $.NSAppearance.appearanceNamed('NSAppearanceNameAqua');
  ui.reportBtn.appearance = aqua; ui.careBtn.appearance = aqua;
  ui.helpTitle.textColor = ui.helpText.textColor = rgb(16, 42, 76);
  ui.helpLink = add(linkButton('helpdesk@schoolathome.ca', 'helpdesk:'));
  ui.helpLink.contentTintColor = rgb(11, 87, 208);
  ui.helpLink.font = $.NSFont.boldSystemFontOfSize(13); ui.helpLink.sizeToFit;

  // 5.2.5: Connect to TLA, on Macs Intune doesn't manage.
  ui.connBox = add(box(rgb(223, 246, 221), rgb(169, 220, 169)));
  ui.connTitle = add(label('Connect this Mac to TLA', 13, { bold: true }));
  ui.connText = add(label('This Mac isn’t connected to TLA yet, so it’s missing what TLA sends: the TLA new tab page in Chrome and Edge, apps and updates. Click Connect to TLA, sign in to Company Portal with your TLA account and follow the steps. You’ll need this Mac’s administrator password.', 13, { wrap: true }));
  ui.connTitle.textColor = ui.connText.textColor = rgb(14, 60, 14);
  ui.connBtn = add($.NSButton.buttonWithTitleTargetAction('Connect to TLA', ui.target, 'connect:'));
  ui.connBtn.appearance = aqua;

  // The organization's announcement (4.0): the lock screen message Intune sets, shown here too.
  ui.newsBox = add(box(rgb(255, 244, 206), rgb(242, 213, 124)));
  ui.newsText = add(label('', 13, { wrap: true }));
  ui.newsText.textColor = $.NSColor.blackColor;

  ui.lockBox = add(box(rgb(255, 244, 206), rgb(242, 213, 124)));
  ui.lockText = add(label("Your organization manages these settings, so they can't be changed here.", 13, { wrap: true }));
  ui.lockText.textColor = $.NSColor.blackColor;

  // ---- Welcome video
  ui.iVideo = add(symbol('play.rectangle.fill', 18));
  ui.hVideo = add(label('Welcome video', 15, { bold: true }));
  ui.lEnabled = add(label('Play the welcome video when I log in', 13));
  ui.enabled = add(toggle('enabled:'));
  ui.lWhich = add(label('Which video', 13));
  ui.video = add(C('NSPopUpButton').alloc.initWithFramePullsDown(R(0, 0, 300, 26), false));
  ui.video.target = ui.target; ui.video.action = 'video:';
  ui.video.autoenablesItems = false;    // (5.1: so the group headings in the list stay greyed out)
  ui.lWhen = add(label('When to play it', 13));
  ui.when = add(C('NSPopUpButton').alloc.initWithFramePullsDown(R(0, 0, 300, 26), false));
  st.when.forEach(c => ui.when.addItemWithTitle(c.name));
  ui.when.target = ui.target; ui.when.action = 'when:';
  ui.lSound = add(label('Play with sound', 13));
  ui.sound = add(toggle('check:'));
  ui.lSkip = add(label('Let me close it early with the Skip button or Esc', 13));
  ui.skip = add(toggle('check:'));
  // Quiet hours (4.0): no sound during the hours (and days) they set.
  ui.lQuiet = add(label('Quiet hours (for class time)', 13));
  ui.quiet = add(C('NSPopUpButton').alloc.initWithFramePullsDown(R(0, 0, 260, 26), false));
  ui.quiet.target = ui.target; ui.quiet.action = 'quiet:';
  st.quiet.forEach(q => ui.quiet.addItemWithTitle(q.name));
  ui.times = [];
  for (let m = 0; m < 1440; m += 15) ui.times.push(('0' + Math.floor(m / 60)).slice(-2) + ':' + ('0' + (m % 60)).slice(-2));
  ui.lFrom = add(label('Mute it from', 13)); ui.lTo = add(label('to', 13));
  ui.qStart = add(C('NSPopUpButton').alloc.initWithFramePullsDown(R(0, 0, 90, 26), false));
  ui.qEnd = add(C('NSPopUpButton').alloc.initWithFramePullsDown(R(0, 0, 90, 26), false));
  [ui.qStart, ui.qEnd].forEach((p, i) => { ui.times.forEach(t => p.addItemWithTitle(t)); p.target = ui.target; p.action = 'qtime:'; p.tag = i; });
  ui.days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((d, i) => {
    const b = add($.NSButton.checkboxWithTitleTargetAction(d, ui.target, 'day:')); b.tag = i; return b;
  });
  // The greeting (4.0; 5.5.5: on or off, keeping the name).
  ui.lGreet = add(label('Greet me by name when the video starts', 13));
  ui.greetOn = add(toggle('greeting:'));
  ui.lName = add(label('Your name', 13, { grey: true }));
  ui.name = add(C('NSTextField').alloc.initWithFrame(R(0, 0, 220, 24)));
  ui.name.placeholderString = 'Your preferred name';
  ui.name.target = ui.target; ui.name.action = 'name:';     // Return saves it
  ui.name.delegate = ui.target;                            // (to know when it's been changed)
  // 4.0.5: a Save button, and a line saying it's saved (it also saves when the window closes).
  ui.saveName = add($.NSButton.buttonWithTitleTargetAction('Save', ui.target, 'saveName:'));
  ui.saveName.enabled = false;
  ui.nameStatus = add(label('', 12, { wrap: true }));
  ui.nameStatus.textColor = $.NSColor.systemGreenColor;
  ui.nameHint = add(label('', 11, { light: true, wrap: true }));
  ui.last = add(label('', 12, { grey: true, wrap: true }));

  // ---- Background
  ui.iBg = add(symbol('photo.fill', 18));
  ui.hBg = add(label('Background', 15, { bold: true }));
  ui.bgNote = add(label('', 13, { grey: true, wrap: true }));
  // 4.2: how long a pick lasts (not saved), how the picture fits the screen, and the lock screen's own background.
  const popup = (items, action) => {
    const p = add(C('NSPopUpButton').alloc.initWithFramePullsDown(R(0, 0, 240, 26), false));
    items.forEach(t => p.addItemWithTitle(t));
    if (action) { p.target = ui.target; p.action = action; }
    return p;
  };
  ui.lPick = add(label('Use my pick', 13));
  ui.pick = popup(st.pickfor.map(x => x.name), null);
  ui.lFit = add(label('Fit on the screen', 13));
  ui.fit = popup(st.fits.map(x => x.name), 'fit:');
  ui.lockIds = ['same'].concat(st.backgrounds.filter(b => b.id !== 'surprise').map(b => b.id));
  ui.lLock = add(label('Lock screen', 13));
  ui.lock = popup(['Same as my desktop'].concat(st.backgrounds.filter(b => b.id !== 'surprise').map(b => b.name)), 'lock:');
  // 5.0: light or dark.
  ui.lLight = add(label('Light or dark', 13));
  ui.light = popup(st.lightdark.map(x => x.name), 'lightdark:');
  ui.tempBox = add(box(rgb(231, 240, 253), rgb(176, 205, 245)));
  ui.tempText = add(label('', 13, { wrap: true }));
  ui.tempText.textColor = rgb(16, 42, 76);
  ui.tempEnd = add(linkButton('Go back now', 'untemp:'));
  ui.tempEnd.contentTintColor = rgb(11, 87, 208);
  ui.lWith = add(label('With an intro video', 13, { bold: true }));
  // 5.1: grouped by intro videos (with light and dark mode on): a video for each look, or one for both.
  ui.lBoth = add(label('Light and dark intro videos', 13, { bold: true }));
  ui.lBothNote = add(label('Each has an intro video for light mode and one for dark mode: the one that plays matches your Mac.', 11, { light: true, wrap: true }));
  ui.lOneNote = add(label('One intro video for both light and dark mode.', 11, { light: true, wrap: true }));
  ui.lOnly = add(label('Just for Experimental', 13, { bold: true }));
  ui.lOnlyNote = add(label('For our beta testers on the Experimental channel. It plays the TLA Classic intro video.', 11, { light: true, wrap: true }));
  // The seasonal theme (4.0), while it's on: click it to go back to it after picking your own.
  ui.lSeason = add(label('Seasonal theme', 13, { bold: true }));
  ui.seasonTile = null;
  // 4.2: a play button on a background's picture previews its video, without picking the background.
  // (4.2.5: NSImage is looked up by name like the other classes (in 4.2, $.NSImage stopped the window from
  // opening on current macOS), and the dark disc is an NSBox, so no Core Graphics colours are needed.)
  const previewButton = (action, tag, name) => {
    const disc = add($.NSBox.alloc.initWithFrame(R(0, 0, 28, 28)));
    disc.boxType = 4; disc.borderWidth = 1; disc.cornerRadius = 14; disc.titlePosition = 0;
    disc.fillColor = $.NSColor.colorWithSRGBRedGreenBlueAlpha(0, 0, 0, 0.7);
    disc.borderColor = $.NSColor.colorWithSRGBRedGreenBlueAlpha(1, 1, 1, 0.9);
    const b = add($.NSButton.alloc.initWithFrame(R(0, 0, 28, 28)));
    b.bordered = false; b.title = '';
    let img = null;
    try { img = C('NSImage').imageWithSystemSymbolNameAccessibilityDescription('play.fill', 'Play'); } catch (e) { img = null; }
    if (img && !img.isNil()) { b.image = img; b.imagePosition = 1; } else { b.title = '▶'; }
    b.contentTintColor = $.NSColor.whiteColor;
    b.toolTip = 'Play the ' + name + ' video';
    b.target = ui.target; b.action = action; b.tag = tag;
    return { disc: disc, btn: b };
  };
  const tile = (thumb, action, tag, tip) => {
    const frame = add($.NSBox.alloc.initWithFrame(R(0, 0, 164, 97)));
    frame.boxType = 4; frame.titlePosition = 0; frame.borderWidth = 3; frame.cornerRadius = 10;
    frame.fillColor = $.NSColor.clearColor; frame.borderColor = $.NSColor.clearColor;
    const btn = add($.NSButton.alloc.initWithFrame(R(0, 0, 154, 87)));
    btn.bordered = false; btn.title = '';
    const img = C('NSImage').alloc.initWithContentsOfFile(thumb);
    if (!img.isNil()) btn.image = img;
    btn.imageScaling = 3;                         // fill the tile, keeping proportions
    btn.wantsLayer = true; btn.layer.cornerRadius = 7; btn.layer.masksToBounds = true;
    btn.tag = tag; btn.target = ui.target; btn.action = action;
    btn.toolTip = tip;
    return { frame: frame, btn: btn };
  };
  if (st.season) {
    const t = tile(st.season.thumb, 'seasonal:', 0, 'Until ' + st.season.ends);
    const name = add(label(st.season.name, 13));
    ui.seasonTile = { frame: t.frame, btn: t.btn, name: name, prev: st.season.hasfile ? previewButton('previewSeason:', 0, st.season.name) : null };
  }
  ui.lSoon = add(label('Intro videos coming soon', 13, { bold: true }));
  ui.lSoonNote = add(label('Until their own video is ready, these play the TLA Classic video.', 11, { light: true, wrap: true }));

  // ---- 5.0: Screensaver, calls and reminders.
  ui.iExtras = add(symbol('sparkles', 18));
  ui.hExtras = add(label('Screensaver, calls and reminders', 15, { bold: true }));
  ui.lSs = add(label('Use the TLA screensaver', 13));
  ui.ssOn = add(toggle('screensaver:'));
  ui.ssNote = add(label('', 11, { grey: true, wrap: true }));
  ui.lCalls = add(label('TLA backgrounds on your video calls', 13));
  ui.callsAdd = add($.NSButton.buttonWithTitleTargetAction('Add to Teams', ui.target, 'callsAdd:'));
  ui.callsOpen = add($.NSButton.buttonWithTitleTargetAction('Open the pictures', ui.target, 'callsOpen:'));
  ui.callsRemove = add(linkButton('Take them out of Teams', 'callsRemove:'));
  ui.callsRemove.font = $.NSFont.systemFontOfSize(12); ui.callsRemove.sizeToFit;
  ui.callsNote = add(label('', 11, { grey: true, wrap: true }));
  ui.lRem = add(label('Remind me when my Mac needs attention (TLA Care)', 13));
  ui.remOn = add(toggle('reminders:'));
  ui.remNote = add(label('At most once a day: for a restart that’s overdue, storage running out, or sound that isn’t working.', 11, { grey: true, wrap: true }));

  // ---- 4.3: release channels.
  ui.iUpdates = add(symbol('arrow.triangle.2.circlepath', 18));
  ui.hUpdates = add(label('Updates', 15, { bold: true }));
  ui.updatesNote = add(label('Choose when new backgrounds, intro videos and features reach you.', 13, { grey: true, wrap: true }));
  const chanText = { stable: ['Stable (recommended)', "New things arrive once they've been tried out."],
                     experimental: ['Experimental', 'Get new backgrounds and features first. They might still have rough edges.'] };
  ui.chans = st.channels.map((c, i) => {
    const t = chanText[c.id] || [c.name, ''];
    const r = add($.NSButton.radioButtonWithTitleTargetAction(t[0], ui.target, 'channel:'));
    r.tag = i;
    return { radio: r, note: add(label(t[1], 11, { grey: true, wrap: true })) };
  });
  ui.chanStatus = add(label('', 12, { grey: true, wrap: true }));

  // 5.0: once per Mac, for whoever sets it up.
  ui.unboxBox = add(box(rgb(243, 240, 251), rgb(209, 198, 238)));
  ui.unboxTitle = add(label('Setting this Mac up for someone?', 13, { bold: true }));
  ui.unboxText = add(label('When you’re done, click Prepare for initial unboxing. The Mac shuts down, and the next time it starts, whoever logs in gets the TLA Classic intro and the Welcome to TLA tour. This can only be done once.', 13, { wrap: true }));
  ui.unboxTitle.textColor = ui.unboxText.textColor = rgb(43, 31, 77);
  ui.unboxBtn = add($.NSButton.buttonWithTitleTargetAction('Prepare for initial unboxing', ui.target, 'unbox:'));
  ui.unboxBtn.appearance = $.NSAppearance.appearanceNamed('NSAppearanceNameAqua');

  ui.tiles = st.backgrounds.map((b, i) => {
    const t = tile(b.thumb, 'tile:', i, b.id === 'surprise' ? 'A different background every day' : b.name);
    const name = add(label(b.name, 13));
    const prev = b.hasfile && b.id !== 'surprise' ? previewButton('preview:', i, b.name) : null;
    return { frame: t.frame, btn: t.btn, name: name, bg: b, prev: prev };
  });
}

// A thin line between two rows of a card (made as needed, and kept for the next layout).
function nextSep() {
  let s = ui.seps[ui.sepUsed];
  if (!s) { s = $.NSBox.alloc.initWithFrame(R(0, 0, 10, 1)); s.boxType = 2; ui.doc.addSubview(s); ui.seps.push(s); }
  ui.sepUsed++;
  s.hidden = false;
  return s;
}

// Puts everything in place for the window's current width.
function layout() {
  if (!ui.doc) return;
  const W = ui.scroll.contentSize.width, x0 = 24, inner = W - 2 * x0;
  const px = 16, cw = inner - 2 * px;       // inside a card
  ui.sepUsed = 0;
  let y = 20, hh;
  // A section heading (with its symbol), then a card of rows.
  const heading = (icon, title) => {
    icon.hidden = icon.image.isNil();
    if (!icon.hidden) place(icon, x0 + 2, y + 2, 18, 18);
    place(title, icon.hidden ? x0 : x0 + 26, y, inner - 26, 22); y += 30;
  };
  let card = null, cardTop = 0, rows = 0;
  const begin = c => { card = c; cardTop = y; rows = 0; c.hidden = false; y += 4; };
  const end = () => { y += 4; place(card, x0, cardTop, inner, y - cardTop); y += 24; };
  // One row: a label on the left and its control (switch, menu or buttons) on the right; a note under the label.
  const row = (lbl, ctl, ctlW, note) => {
    if (rows++) { place(nextSep(), x0 + px, y, cw, 1); }
    const lw = cw - (ctl ? ctlW + 16 : 0);
    const lh = Math.max(18, fitHeight(lbl, lw));
    const nh = note ? fitHeight(note, lw) : 0;
    const h = Math.max(44, lh + (note ? nh + 4 : 0) + 22);
    const top = y + (h - lh - (note ? nh + 4 : 0)) / 2;
    place(lbl, x0 + px, top, lw, lh);
    if (note) place(note, x0 + px, top + lh + 4, lw, nh);
    if (ctl) {
      const ch = ctl.isKindOfClass(C('NSPopUpButton')) ? 26 : 22;
      place(ctl, x0 + px + cw - ctlW, y + (h - ch) / 2, ctlW, ch);
    }
    y += h;
  };

  place(ui.icon, x0, y, 52, 52);
  const tx = ui.icon.hidden ? x0 : x0 + 66;
  place(ui.title, tx, y + 2, inner - (tx - x0), 30);
  hh = fitHeight(ui.subtitle, inner - (tx - x0)); place(ui.subtitle, tx, y + 34, inner - (tx - x0), hh);
  y += Math.max(60, 36 + hh) + 16;
  // The announcement, then where to send ideas and problems (the same order as the Windows app).
  const news = !!st.announcement;
  ui.newsBox.hidden = !news; ui.newsText.hidden = !news;
  if (news) {
    ui.newsText.stringValue = 'Announcement: ' + st.announcement;
    hh = fitHeight(ui.newsText, inner - 28);
    place(ui.newsBox, x0, y, inner, hh + 22); place(ui.newsText, x0 + 14, y + 11, inner - 28, hh); y += hh + 34;
  }
  {
    // (4.3: the Report a problem button on the right)
    const showReport = st.report === '1', showCare = !!st.features.care;   // (5.0: and Check my Mac under it)
    ui.reportBtn.hidden = !showReport; ui.careBtn.hidden = !showCare;
    ui.reportBtn.sizeToFit; ui.careBtn.sizeToFit;
    const anyBtn = showReport || showCare;
    const bw = anyBtn ? Math.max(150, ui.reportBtn.frame.size.width + 16, ui.careBtn.frame.size.width + 16) : 0;
    const top = y, hx = x0 + 16, hw = inner - 32 - (anyBtn ? bw + 14 : 0);
    y += 12; place(ui.helpTitle, hx, y, hw, 18); y += 20;
    hh = fitHeight(ui.helpText, hw); place(ui.helpText, hx, y, hw, hh); y += hh + 2;
    place(ui.helpLink, hx - 2, y, ui.helpLink.frame.size.width, 20); y += 30;
    if (showReport && showCare) y = Math.max(y, top + 92);
    place(ui.helpBox, x0, top, inner, y - top - 2);
    const mid = top + (y - top - 2) / 2, bx = x0 + inner - 16 - bw;
    if (showReport && showCare) { place(ui.reportBtn, bx, mid - 36, bw, 32); place(ui.careBtn, bx, mid + 2, bw, 32); }
    else if (showReport) place(ui.reportBtn, bx, mid - 16, bw, 32);
    else if (showCare) place(ui.careBtn, bx, mid - 16, bw, 32);
    y += 16;
  }
  {   // 5.2.5: Connect to TLA
    const show = st.connect === 'needed';
    [ui.connBox, ui.connTitle, ui.connText, ui.connBtn].forEach(v => v.hidden = !show);
    if (show) {
      ui.connBtn.sizeToFit;
      const bw = Math.max(150, ui.connBtn.frame.size.width + 16), tw = inner - 32 - bw - 14;
      const top = y; let yy = top + 12;
      place(ui.connTitle, x0 + 16, yy, tw, 18); yy += 22;
      hh = fitHeight(ui.connText, tw); place(ui.connText, x0 + 16, yy, tw, hh); yy += hh + 12;
      place(ui.connBox, x0, top, inner, yy - top);
      place(ui.connBtn, x0 + inner - 16 - bw, top + (yy - top) / 2 - 16, bw, 32);
      y = yy + 16;
    }
  }
  const locked = st.locked === '1';
  ui.lockBox.hidden = !locked; ui.lockText.hidden = !locked;
  if (locked) {
    hh = fitHeight(ui.lockText, inner - 28);
    place(ui.lockBox, x0, y, inner, hh + 22); place(ui.lockText, x0 + 14, y + 11, inner - 28, hh); y += hh + 36;
  }

  // ---- Welcome video
  heading(ui.iVideo, ui.hVideo);
  begin(ui.cardVideo);
  const menuW = Math.min(300, Math.max(200, cw - 260));
  row(ui.lEnabled, ui.enabled, 40);
  row(ui.lWhich, ui.video, menuW);
  row(ui.lWhen, ui.when, menuW);
  row(ui.lSound, ui.sound, 40);
  row(ui.lSkip, ui.skip, 40);
  row(ui.lQuiet, ui.quiet, Math.min(260, menuW));
  const hoursOn = st.setting.QuietMode === 'Hours';
  [ui.lFrom, ui.lTo, ui.qStart, ui.qEnd].concat(ui.days).forEach(v => v.hidden = !hoursOn);
  if (hoursOn) {
    // (under quiet hours, without a line between: the times, then the days)
    const xi = x0 + px + 14;
    place(ui.lFrom, xi, y + 4, 92, 18); place(ui.qStart, xi + 94, y, 90, 26);
    place(ui.lTo, xi + 194, y + 4, 20, 18); place(ui.qEnd, xi + 218, y, 90, 26); y += 34;
    const perRow = Math.max(1, Math.floor((cw - 14) / 62));
    ui.days.forEach((b, i) => place(b, xi + (i % perRow) * 62, y + Math.floor(i / perRow) * 24, 60, 20));
    y += Math.ceil(7 / perRow) * 24 + 10;
  }
  const greetSwitch = !!st.features['greeting-switch'];    // (5.5.5, once it's out on their channel)
  ui.lGreet.hidden = ui.greetOn.hidden = !greetSwitch;
  if (greetSwitch) row(ui.lGreet, ui.greetOn, 40);
  else { place(nextSep(), x0 + px, y, cw, 1); }
  {   // their name: the box, Save, and what was saved
    const xi = x0 + px + (greetSwitch ? 14 : 0);
    y += greetSwitch ? 0 : 12;
    place(ui.lName, xi, y + 3, 76, 18);
    place(ui.name, xi + 80, y, 200, 24);
    place(ui.saveName, xi + 286, y - 3, 76, 30);
    const sx = xi + 372, sw = Math.max(120, x0 + px + cw - sx);
    hh = ui.nameStatus.stringValue.js ? fitHeight(ui.nameStatus, sw) : 18;
    place(ui.nameStatus, sx, y + 3, sw, hh);
    y += Math.max(32, hh + 10);
    hh = fitHeight(ui.nameHint, cw - (xi - x0 - px)); place(ui.nameHint, xi, y, cw - (xi - x0 - px), hh); y += hh + 12;
  }
  place(nextSep(), x0 + px, y, cw, 1); y += 10;
  hh = fitHeight(ui.last, cw); place(ui.last, x0 + px, y, cw, hh); y += hh + 6;
  end();

  // ---- Background
  heading(ui.iBg, ui.hBg);
  hh = fitHeight(ui.bgNote, inner); place(ui.bgNote, x0, y, inner, hh); y += hh + 12;
  begin(ui.cardBg);
  const ld = !!st.features.lightdark && st.lightdark.length > 0;   // (5.0)
  ui.lLight.hidden = ui.light.hidden = !ld;
  row(ui.lPick, ui.pick, Math.min(240, menuW));
  row(ui.lFit, ui.fit, Math.min(240, menuW));
  row(ui.lLock, ui.lock, Math.min(240, menuW));
  if (ld) row(ui.lLight, ui.light, Math.min(260, menuW));
  end();
  const temp = !!st.temp;
  ui.tempBox.hidden = ui.tempText.hidden = ui.tempEnd.hidden = !temp;
  if (temp) {
    y -= 10;
    hh = fitHeight(ui.tempText, inner - 28);
    place(ui.tempBox, x0, y, inner, hh + 44); place(ui.tempText, x0 + 14, y + 11, inner - 28, hh);
    place(ui.tempEnd, x0 + 12, y + 15 + hh, ui.tempEnd.frame.size.width, 18); y += hh + 62;
  }

  const cols = Math.max(1, Math.floor((inner + 12) / 176));
  const gap = cols > 1 ? Math.min(40, (inner - cols * 164) / (cols - 1)) : 0;
  const grid = (items, top) => {
    items.forEach((t, i) => {
      const x = x0 + (i % cols) * (164 + gap), ty = top + Math.floor(i / cols) * 132;
      place(t.frame, x, ty, 164, 97);
      place(t.btn, x + 5, ty + 5, 154, 87);
      if (t.prev) {
        place(t.prev.disc, x + 5 + 154 - 34, ty + 5 + 87 - 34, 28, 28);
        place(t.prev.btn, x + 5 + 154 - 34, ty + 5 + 87 - 34, 28, 28);
      }
      t.name.sizeToFit;                           // centred under the picture
      const nw = Math.min(164, t.name.frame.size.width);
      place(t.name, x + (164 - nw) / 2, ty + 102, nw, 20);
    });
    return top + Math.ceil(items.length / cols) * 132;
  };
  // (4.3: only what's out on their release channel, and the organization's default)
  const shownTile = t => { const b = st.backgrounds.find(x => x.id === t.bg.id); return !b || b.released || b.id === st.org.Background; };
  ui.tiles.forEach(t => {
    const hide = !shownTile(t);
    [t.frame, t.btn, t.name].concat(t.prev ? [t.prev.disc, t.prev.btn] : []).forEach(v => v.hidden = hide);
  });
  const withVideo = ui.tiles.filter(t => t.bg.video && shownTile(t)), soon = ui.tiles.filter(t => !t.bg.video && !t.bg.only && shownTile(t));
  const onlyTiles = ui.tiles.filter(t => t.bg.only && shownTile(t));        // (5.1: the Experimental background)
  const split = !!st.features.lightdark;                                   // (5.1: by intro videos for each look)
  const both = split ? withVideo.filter(t => t.bg.both) : [], one = split ? withVideo.filter(t => !t.bg.both) : withVideo;
  ui.lSeason.hidden = !ui.seasonTile;
  if (ui.seasonTile) {
    place(ui.lSeason, x0, y, inner, 18); y += 26;
    y = grid([ui.seasonTile], y);
  }
  ui.lBoth.hidden = ui.lBothNote.hidden = !both.length;
  ui.lOneNote.hidden = !split;
  if (both.length) {
    place(ui.lBoth, x0, y, inner, 18); y += 22;
    hh = fitHeight(ui.lBothNote, inner); place(ui.lBothNote, x0, y, inner, hh); y += hh + 10;
    y = grid(both, y);
  }
  ui.lWith.stringValue = split ? 'One intro video' : 'With an intro video';
  place(ui.lWith, x0, y + (both.length ? 4 : 0), inner, 18); y += (both.length ? 4 : 0) + (split ? 22 : 26);
  if (split) { hh = fitHeight(ui.lOneNote, inner); place(ui.lOneNote, x0, y, inner, hh); y += hh + 10; }
  y = grid(one, y);
  ui.lOnly.hidden = ui.lOnlyNote.hidden = !onlyTiles.length;
  if (onlyTiles.length) {
    place(ui.lOnly, x0, y + 4, inner, 18); y += 26;
    hh = fitHeight(ui.lOnlyNote, inner); place(ui.lOnlyNote, x0, y, inner, hh); y += hh + 10;
    y = grid(onlyTiles, y);
  }
  ui.lSoon.hidden = ui.lSoonNote.hidden = soon.length === 0;
  if (soon.length) {
    place(ui.lSoon, x0, y + 4, inner, 18); y += 24;
    hh = fitHeight(ui.lSoonNote, inner); place(ui.lSoonNote, x0, y, inner, hh); y += hh + 10;
    y = grid(soon, y);
  }
  y += 14;
  // Screensaver, calls and reminders (5.0)
  {
    const ss = !!st.features.screensaver, calls = !!st.features.calls, rem = !!st.features.care;
    const any = ss || calls || rem;
    [ui.iExtras, ui.hExtras, ui.cardExtras].forEach(v => v.hidden = !any);
    [ui.lSs, ui.ssOn, ui.ssNote].forEach(v => v.hidden = !ss);
    [ui.lCalls, ui.callsAdd, ui.callsOpen, ui.callsNote].forEach(v => v.hidden = !calls);
    ui.callsRemove.hidden = !calls || !(+st.calls > 0);
    [ui.lRem, ui.remOn, ui.remNote].forEach(v => v.hidden = !rem);
    if (any) {
      heading(ui.iExtras, ui.hExtras);
      begin(ui.cardExtras);
      if (ss) row(ui.lSs, ui.ssOn, 40, ui.ssNote);
      if (calls) {
        ui.callsAdd.sizeToFit; ui.callsOpen.sizeToFit;
        const w1 = Math.max(120, ui.callsAdd.frame.size.width + 12), w2 = Math.max(140, ui.callsOpen.frame.size.width + 12);
        row(ui.lCalls, null, 0, ui.callsNote);
        // (the buttons under the note, then the link to take them out)
        y -= 10;
        place(ui.callsAdd, x0 + px - 6, y, w1, 32); place(ui.callsOpen, x0 + px - 6 + w1 + 4, y, w2, 32);
        if (!ui.callsRemove.hidden) place(ui.callsRemove, x0 + px + w1 + w2 + 14, y + 7, ui.callsRemove.frame.size.width, 18);
        y += 44;
      }
      if (rem) row(ui.lRem, ui.remOn, 40, ui.remNote);
      end();
    }
  }
  // Updates (4.3)
  heading(ui.iUpdates, ui.hUpdates);
  hh = fitHeight(ui.updatesNote, inner); place(ui.updatesNote, x0, y, inner, hh); y += hh + 12;
  begin(ui.cardUpdates);
  y += 8;
  ui.chans.forEach((c, i) => {
    if (i) { place(nextSep(), x0 + px, y, cw, 1); y += 10; }
    place(c.radio, x0 + px, y, cw, 20); y += 22;
    hh = fitHeight(c.note, cw - 20); place(c.note, x0 + px + 20, y, cw - 20, hh); y += hh + 12;
  });
  place(nextSep(), x0 + px, y, cw, 1); y += 10;
  hh = fitHeight(ui.chanStatus, cw); place(ui.chanStatus, x0 + px, y, cw, hh); y += hh + 8;
  end();
  // Prepare for initial unboxing (5.0): only on a Mac that hasn't been prepared (or handed out) yet. (Whatever the
  // release channel: it's for whoever sets the Mac up.)
  {
    const show = st.unbox === 'ready';
    [ui.unboxBox, ui.unboxTitle, ui.unboxText, ui.unboxBtn].forEach(v => v.hidden = !show);
    if (show) {
      ui.unboxBtn.sizeToFit;
      const bw = Math.max(220, ui.unboxBtn.frame.size.width + 16), tw = inner - 32 - bw - 14;
      const top = y - 4; let yy = top + 12;
      place(ui.unboxTitle, x0 + 16, yy, tw, 18); yy += 22;
      hh = fitHeight(ui.unboxText, tw); place(ui.unboxText, x0 + 16, yy, tw, hh); yy += hh + 12;
      place(ui.unboxBox, x0, top, inner, yy - top);
      place(ui.unboxBtn, x0 + inner - 16 - bw, top + (yy - top) / 2 - 16, bw, 32);
      y = yy + 20;
    }
  }
  for (let i = ui.sepUsed; i < ui.seps.length; i++) ui.seps[i].hidden = true;
  ui.doc.setFrame(R(0, 0, W, y + 6));

  // Bottom bar
  const BW = ui.bar.frame.size.width;
  place(ui.close, BW - 24 - 96, 30, 96, 32);
  place(ui.play, BW - 24 - 96 - 8 - 150, 30, 150, 32);
  place(ui.reset, x0, 38, ui.reset.frame.size.width, 18);
  const wx = ui.reset.hidden ? x0 : x0 + ui.reset.frame.size.width + 18;
  place(ui.whatsNew, wx, 38, ui.whatsNew.frame.size.width, 18);
  ui.tourLink.hidden = !st.features.tour;   // (5.0)
  const tlx = wx + ui.whatsNew.frame.size.width + 18;
  ui.tourBelow = tlx + ui.tourLink.frame.size.width > BW - 24 - 96 - 8 - 150 - 12;   // (no room: on the version's line)
  if (ui.tourBelow) place(ui.tourLink, x0 + 190, 11, ui.tourLink.frame.size.width, 18);
  else place(ui.tourLink, tlx, 38, ui.tourLink.frame.size.width, 18);
  place(ui.version, x0, 12, ui.tourBelow && !ui.tourLink.hidden ? 180 : 300, 16);
  place(ui.playQuiet, BW - 24 - 96 - 8 - 150 + (150 - ui.playQuiet.frame.size.width) / 2, 10, ui.playQuiet.frame.size.width, 16);
}

// Shows the settings in effect.
function refresh() {
  const s = st.setting, locked = st.locked === '1', bgLocked = st.bglocked === '1';
  ui.enabled.state = s.Enabled === '0' ? 0 : 1;
  ui.sound.state = s.Sound === '0' ? 0 : 1;
  ui.skip.state = s.AllowSkip === '1' ? 1 : 0;
  const wi = st.when.findIndex(c => c.id === s.PlayWhen);   // (5.5.5: a menu)
  ui.when.selectItemAtIndex(wi < 0 ? 0 : wi);

  ui.video.removeAllItems;
  const seasonalOn = !!st.season && st.current === st.season.id;
  // What "match" plays (4.1: a seasonal theme's own video).
  const bgNow = st.backgrounds.find(b => b.id === st.matchvideo && b.id !== 'surprise');
  const matchName = st.season && st.matchvideo === st.season.id ? st.season.name : bgNow && bgNow.video ? bgNow.name : 'TLA Classic';
  // (4.3: only the videos out on their release channel, and the organization's default)
  const vids = st.videos.filter(v => v.released || v.id === st.org.Video);
  // 5.1: grouped (with light and dark mode on): the videos with a version for each look, then the rest.
  // ui.videoIds lines up with the list's items (null for a heading or a line).
  ui.videoIds = [];
  const addVideo = v => {
    let t = v.name;
    if (v.id === 'match') t += ' (' + matchName + ')';
    if (v.id === st.org.Video) t += ' - default';
    ui.video.addItemWithTitle(t);
    ui.videoIds.push(v.id);
  };
  const addHeading = title => {
    ui.video.menu.addItem($.NSMenuItem.separatorItem); ui.videoIds.push(null);
    const h = $.NSMenuItem.alloc.initWithTitleActionKeyEquivalent(title, null, '');
    h.enabled = false; ui.video.menu.addItem(h); ui.videoIds.push(null);
  };
  const special = vids.filter(v => v.id === 'match' || v.id === 'surprise'), rest = vids.filter(v => special.indexOf(v) < 0);
  special.forEach(addVideo);
  if (st.features.lightdark && rest.some(v => v.both)) {
    addHeading('Light and dark versions');
    rest.filter(v => v.both).forEach(addVideo);
    addHeading('One version');
    rest.filter(v => !v.both).forEach(addVideo);
  } else {
    rest.forEach(addVideo);
  }
  const vi = ui.videoIds.indexOf(s.Video);
  ui.video.selectItemAtIndex(vi < 0 ? 0 : vi);

  const on = !locked;
  [ui.enabled].forEach(c => c.enabled = on);
  const opts = on && s.Enabled !== '0';
  [ui.video, ui.when, ui.sound, ui.skip, ui.quiet, ui.qStart, ui.qEnd, ui.greetOn].concat(ui.days).forEach(c => c.enabled = opts);
  // The greeting (5.5.5): on or off; their name stays either way.
  const greetSwitch = !!st.features['greeting-switch'];
  const greetOn = !greetSwitch || s.Greeting !== '0';
  ui.greetOn.state = s.Greeting === '0' ? 0 : 1;
  ui.name.enabled = opts && greetOn;
  [ui.lName, ui.nameHint].forEach(l => l.alphaValue = greetOn ? 1 : 0.5);
  ui.nameHint.stringValue = !greetSwitch
    ? 'The video says \u201cGood morning\u201d with your name. Leave it empty and save for no greeting.'
    : st.features['greeting-styles']
    ? 'The video says \u201cGood morning\u201d with your name, in the style of its theme. Turned off, the greeting doesn\u2019t show and your name stays saved.'
    : 'The video says \u201cGood morning\u201d with your name. Turned off, the greeting doesn\u2019t show and your name stays saved.';
  const qi = st.quiet.findIndex(q => q.id === s.QuietMode);
  ui.quiet.selectItemAtIndex(qi < 0 ? 0 : qi);
  ui.qStart.selectItemWithTitle(s.QuietStart || '08:30');
  ui.qEnd.selectItemWithTitle(s.QuietEnd || '15:00');
  const days = (s.QuietDays || '').split(',');
  ui.days.forEach(b => { b.state = days.indexOf(b.title.js) >= 0 ? 1 : 0; });
  if (!ui.nameEdited) ui.name.stringValue = s.PreferredName || '';
  ui.saveName.enabled = opts && greetOn && nameInBox() !== (s.PreferredName || '');

  ui.last.stringValue = st.lastplayed ? 'Your video last played ' + st.lastplayed + '.' : "The video hasn't played for you on this Mac yet.";
  const nowBg = st.backgrounds.find(b => b.id === st.current);
  // (4.2: with a lock screen background of its own, picks change just the desktop)
  const lockOwn = (s.LockBackground || 'same') !== 'same';
  const where = lockOwn ? 'your desktop' : 'your desktop and lock screen';
  ui.bgNote.stringValue = bgLocked
    ? "A configuration profile on this Mac locks the desktop picture, so the background can't be changed here."
    : seasonalOn
    ? "It's " + (st.season.id === 'fall' ? 'fall' : st.season.name) + ' time! ' + where[0].toUpperCase() + where.slice(1) +
      (lockOwn ? ' shows the ' : ' show the ') + st.season.name + ' theme until ' + st.season.ends + '. Pick a background below to use your own instead.'
    : st.season
    ? 'Your background is used for ' + where + '. Click the ' + st.season.name + ' theme to use it until ' + st.season.ends + '.'
    : s.Background === 'surprise' && !st.temp
    ? (nowBg ? "Surprise me: today's background is " + nowBg.name + '. Tomorrow brings another.' : 'Surprise me: a different background every day.')
    : 'Your background is used for ' + where + '. Click one to use it.';
  // 4.2: the options, and a note while a pick is just for a while.
  const fi = st.fits.findIndex(f => f.id === s.WallpaperFit);
  ui.fit.selectItemAtIndex(fi < 0 ? 0 : fi);
  // (4.3: the lock screen list follows the release channel too)
  const lockBgs = st.backgrounds.filter(b => b.id !== 'surprise' && (b.released || b.id === st.org.Background));
  ui.lockIds = ['same'].concat(lockBgs.map(b => b.id));
  ui.lock.removeAllItems;
  ['Same as my desktop'].concat(lockBgs.map(b => b.name)).forEach(t => ui.lock.addItemWithTitle(t));
  const li = ui.lockIds.indexOf(s.LockBackground || 'same');
  ui.lock.selectItemAtIndex(li < 0 ? 0 : li);
  [ui.pick, ui.fit, ui.lock].forEach(c => c.enabled = on && !bgLocked);
  if (st.temp) {
    const p = d => { const a = d.split('-'); return new Date(+a[0], +a[1] - 1, +a[2]); };
    const until = p(st.temp.until), today = p(st.today);
    ui.tempText.stringValue = until <= today
      ? "You're using " + st.temp.name + ' just for today. Tomorrow it goes back to ' + st.temp.after + '.'
      : "You're using " + st.temp.name + ' until ' + until.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' }) +
        '. Then it goes back to ' + st.temp.after + '.';
  }
  if (ui.seasonTile) {
    ui.seasonTile.frame.borderColor = seasonalOn ? $.NSColor.controlAccentColor : $.NSColor.clearColor;
    ui.seasonTile.name.font = seasonalOn ? $.NSFont.boldSystemFontOfSize(13) : $.NSFont.systemFontOfSize(13);
    ui.seasonTile.btn.enabled = on && !bgLocked;
    ui.seasonTile.btn.alphaValue = on && !bgLocked ? 1 : 0.55;
  }
  ui.tiles.forEach(t => {
    const sel = t.bg.id === (st.temp ? st.temp.id : s.Background) && !seasonalOn;
    t.frame.borderColor = sel ? $.NSColor.controlAccentColor : $.NSColor.clearColor;
    t.name.font = sel ? $.NSFont.boldSystemFontOfSize(13) : $.NSFont.systemFontOfSize(13);
    t.name.stringValue = t.bg.name + (t.bg.id === st.org.Background ? ' (default)' : '');
    t.btn.enabled = on && !bgLocked;
    t.btn.alphaValue = on && !bgLocked ? 1 : 0.55;
  });
  // Release channel (4.3).
  const chan = st.channel || 'stable';
  st.channels.forEach((c, i) => { ui.chans[i].radio.state = c.id === chan ? 1 : 0; ui.chans[i].radio.enabled = on; });
  const rel = id => (st.channels.find(c => c.id === id) || {}).release || st.shown;
  const newer = (a, b) => { const p = v => v.split('.').map(Number).concat([0, 0, 0, 0]);
                            const x = p(a), y = p(b); for (let i = 0; i < 4; i++) if (x[i] !== y[i]) return x[i] > y[i]; return false; };
  ui.chanStatus.stringValue = chan === 'experimental'
    ? "You're on Experimental: version " + st.shown + '.' + (newer(rel('experimental'), rel('stable')) ? ' Stable is on version ' + rel('stable') + '.' : ' Right now it has the same as Stable.')
    : "You're on Stable: version " + st.shown + '.' + (newer(rel('experimental'), rel('stable')) ? ' Experimental has version ' + rel('experimental') + ' to try.' : '');
  const chanName = (st.channels.find(c => c.id === chan) || { name: 'Stable' }).name;
  ui.version.stringValue = 'Version ' + (st.shown || st.release) + ' \u00b7 ' + chanName;
  ui.version.sizeToFit;
  ui.reset.hidden = locked || st.custom !== '1';
  ui.play.enabled = ui.playQuiet.enabled = st.hasvideo === '1';
  // 5.0: light or dark.
  const li2 = st.lightdark.findIndex(x => x.id === (s.LightDark || 'Auto'));
  ui.light.selectItemAtIndex(li2 < 0 ? 0 : li2);
  ui.light.enabled = on && !bgLocked;
  // The screensaver: their setting, and what happened.
  const ssStatus = st.ss.status, ssSetup = st.ss.setup;
  ui.ssOn.state = s.Screensaver === '0' ? 0 : 1;
  ui.ssOn.enabled = on && ssStatus !== 'policy' && ssSetup !== 'needs-macos-26' && ssStatus !== 'working';
  ui.ssNote.stringValue =
      ssStatus === 'working' ? 'Setting it up…'
    : ssStatus === 'policy' ? 'Your organization sets this Mac’s screensaver.'
    : ssSetup === 'needs-macos-26' || ssStatus === 'needs-macos-26' ? 'The TLA screensaver needs macOS 26 or later.'
    : s.Screensaver === '0' ? 'Off: your Mac uses its own screensaver.'
    : ssStatus === 'set' ? 'When your Mac sits unused for a few minutes, the TLA video plays. Change how long it waits in System Settings > Lock Screen.'
    : ssStatus === 'theirs' ? 'You chose another screensaver in System Settings, so it stays. To use the TLA one again, turn this off and on.'
    : ssStatus === 'failed' ? 'macOS didn’t take the TLA screensaver. Turn this off and on to try again, or report the problem.'
    : /^waiting/.test(ssSetup) ? 'Getting it ready (' + ssSetup.replace(/^waiting: /, '') + '). It starts by itself.'
    : /^failed/.test(ssSetup) ? 'It couldn’t be set up (' + ssSetup.replace(/^failed: /, '') + '). Report the problem if it keeps happening.'
    : 'It starts by itself in a few minutes.';
  // Call backgrounds.
  const placed = +st.calls || 0, teams = st.teams === '1';
  ui.callsAdd.title = placed > 0 ? 'Update Teams' : 'Add to Teams';
  ui.callsAdd.enabled = teams;
  if (!ui.callsMessage) {
    ui.callsNote.stringValue = !teams
      ? 'Microsoft Teams isn’t on this Mac. For Zoom and other apps, click Open the pictures and add them in the app’s background settings.'
      : placed > 0 ? placed + ' TLA backgrounds are in Teams: in a meeting, choose More > Video effects. For Zoom and other apps, click Open the pictures.'
      : 'Puts every TLA background, light and dark, in Microsoft Teams. macOS asks you to allow it the first time. For Zoom and other apps, click Open the pictures.';
  }
  // Reminders.
  ui.remOn.state = s.CareReminders === '0' ? 0 : 1;
  ui.remOn.enabled = on;
  ui.unboxBtn.enabled = !ui.unboxWorking;
  // The tiles' pictures follow light or dark (when it changes, or the first time).
  if (ui.shownMode !== st.mode) {
    ui.shownMode = st.mode;
    const setImage = (btn, file) => { if (!file) return; const img = C('NSImage').alloc.initWithContentsOfFile(file); if (!img.isNil()) btn.image = img; };
    ui.tiles.forEach(t => { const b = st.backgrounds.find(x => x.id === t.bg.id); if (b && b.id !== 'surprise') setImage(t.btn, b.thumb); });
    if (ui.seasonTile && st.season) setImage(ui.seasonTile.btn, st.season.thumb);
  }
  layout();
}

function alertBox(title, text) {
  const a = $.NSAlert.alloc.init;
  a.messageText = title; a.informativeText = text || '';
  a.addButtonWithTitle('OK');
  a.runModal;
}

// Every second and a half while the window is open (5.0): follows a screensaver change, and the unboxing request.
function tick() {
  const now = Date.now();
  if (ui.nextTick && now < ui.nextTick) return;
  ui.nextTick = now + 1500;
  if (ui.ssPollUntil) {
    st = loadState();
    if (st.ss.status !== 'working' || now > ui.ssPollUntil) ui.ssPollUntil = 0;
    refresh();
  }
  const u = ui.unboxWorking;
  if (u) {
    const r = sh(['--care-result', 'unbox', u.at]).trim();
    if ((r && r !== 'Shutting down.') || (!r && now > u.until)) {
      ui.unboxWorking = null;
      ui.unboxBtn.title = 'Prepare for initial unboxing';
      alertBox('Prepare for initial unboxing', r || 'The Mac didn’t answer. Try again in a moment.');
      st = loadState(); refresh();
    }
  }
}

function save(key, value, wait) {
  sh(['--save', key, value], wait);
  if (wait !== false) { st = loadState(); refresh(); }
}

handlers.enabled = s => save('Enabled', s.state ? '1' : '0');
handlers.check = s => save(s.isEqual(ui.sound) ? 'Sound' : 'AllowSkip', s.state ? '1' : '0');
handlers.video = s => { const id = ui.videoIds[Number(s.indexOfSelectedItem)]; if (id) save('Video', id); };
handlers.channel = s => save('Channel', st.channels[Number(s.tag)].id);
handlers.when = p => save('PlayWhen', st.when[Number(p.indexOfSelectedItem)].id);   // (5.5.5: a menu)
handlers.greeting = c => { ui.nameStatus.stringValue = ''; save('Greeting', c.state ? '1' : '0'); };
handlers.tile = s => {
  // Show it as chosen straight away, save it (4.0.5: before anything else, and waiting for it), and let the
  // desktop change in the background (settings.zsh starts that; the newest pick wins).
  const id = st.backgrounds[Number(s.tag)].id;
  // 4.2: just for today or a week ("Use my pick"); then what was there before comes back.
  const pf = (st.pickfor[ui.pick.indexOfSelectedItem] || {}).id || 'Always';
  if (pf !== 'Always' && id !== 'surprise') {
    sh(['--pick', id, pf]);
    st = loadState(); refresh();
    return;
  }
  st.setting.Background = id; st.custom = '1'; st.ondefault = '0';
  st.current = id === 'surprise' ? '' : id;
  try { refresh(); } catch (e) { }
  sh(['--save', 'Background', id]);
  st = loadState(); refresh();
};
handlers.fit = p => save('WallpaperFit', st.fits[p.indexOfSelectedItem].id);
handlers.lock = p => save('LockBackground', ui.lockIds[p.indexOfSelectedItem]);
handlers.untemp = () => { sh(['--untemp']); st = loadState(); refresh(); };
// 5.0
handlers.lightdark = p => save('LightDark', st.lightdark[p.indexOfSelectedItem].id);
handlers.reminders = c => save('CareReminders', c.state ? '1' : '0');
handlers.screensaver = c => { save('Screensaver', c.state ? '1' : '0'); ui.ssPollUntil = Date.now() + 25000; };
handlers.calls = what => {
  ui.callsMessage = true;
  ui.callsNote.stringValue = what === 'add' ? 'Adding them…' : 'Taking them out…';
  ui.callsNote.displayIfNeeded;
  const r = sh(['--calls', what]).trim();
  ui.callsNote.stringValue = /^added/.test(r)
      ? 'Done: ' + r.split(' ')[1] + ' TLA backgrounds are in Teams. In a meeting, choose More > Video effects. (If Teams was open, quit it and open it again first.)'
    : /^removed/.test(r) ? 'Done: the TLA backgrounds are out of Teams.'
    : r === 'denied' ? 'macOS didn’t allow it. Click Add to Teams again and choose Allow, or add them in Teams yourself: click Open the pictures.'
    : r === 'no-teams' ? 'Microsoft Teams isn’t on this Mac.'
    : 'There are no TLA backgrounds to add yet.';
  st = loadState(); refresh();
};
// Prepare for initial unboxing: confirm, then guard.zsh (as root) marks the Mac and shuts it down.
handlers.unbox = () => {
  const a = $.NSAlert.alloc.init;
  a.messageText = 'Prepare this Mac for unboxing?';
  a.informativeText = 'It shuts down straight away, so save your work first. The next time it starts, whoever logs in gets the TLA Classic intro and the Welcome to TLA tour.\n\nThis can only be done once on this Mac.';
  a.addButtonWithTitle('Prepare and shut down'); a.addButtonWithTitle('Cancel');
  // (5.3: as a number, like the buttons' tags)
  if (Number(a.runModal) !== 1000) return;
  const at = sh(['--unbox']).trim();
  if (!/^\d+$/.test(at)) {
    alertBox('Prepare for initial unboxing', at === 'already' ? 'This Mac has already been prepared for unboxing.' : 'Couldn’t prepare the Mac. Try again in a moment.');
    st = loadState(); refresh(); return;
  }
  // (the guard answers within about 20 seconds)
  ui.unboxWorking = { at: at, until: Date.now() + 75000 };
  ui.unboxBtn.title = 'Shutting down…'; ui.unboxBtn.enabled = false;
};
handlers.reset = () => { sh(['--reset']); ui.nameEdited = false; st = loadState(); refresh(); };
handlers.seasonal = () => { sh(['--seasonal']); st = loadState(); refresh(); };
handlers.quiet = s => save('QuietMode', st.quiet[s.indexOfSelectedItem].id);
// (5.1: the tag as a number: macOS hands it over in a form that's never === 0, so "Quiet from" saved as "until")
handlers.qtime = s => save(Number(s.tag) === 0 ? 'QuietStart' : 'QuietEnd', ui.times[Number(s.indexOfSelectedItem)]);
handlers.day = s => save('QuietDays', ui.days.filter(b => b.state).map(b => b.title.js).join(','));
// The greeting's name (4.0.5): saved with the Save button or Return, and when the window closes.
function nameInBox() { return ui.name ? ui.name.stringValue.js.replace(/\s+/g, ' ').trim().slice(0, 30) : ''; }
handlers.nameTyped = () => {
  ui.nameEdited = true;
  ui.nameStatus.stringValue = '';
  ui.saveName.enabled = nameInBox() !== (st.setting.PreferredName || '');
};
handlers.name = clicked => {
  if (!ui.name) return;
  const v = nameInBox();
  if (v === (st.setting.PreferredName || '') && !clicked) return;
  sh(['--save', 'PreferredName', v]);
  ui.nameEdited = false;
  st = loadState();
  const saved = st.setting.PreferredName || '';
  ui.nameStatus.stringValue = saved !== v ? "Couldn't save that name. Try a shorter one."
    : v ? 'Saved \u2713  Your video will say: Good ' + partOfDay() + ', ' + v + '!' : 'Saved \u2713  No greeting.';
  ui.nameStatus.textColor = saved !== v ? $.NSColor.systemRedColor : $.NSColor.systemGreenColor;
  refresh();
};
function partOfDay() { const h = new Date().getHours(); return h < 12 ? 'morning' : h < 17 ? 'afternoon' : 'evening'; }
handlers.play = (id, mute) => { sh(['--play'].concat(id ? [id] : [], mute ? [mute] : [])); st = loadState(); refresh(); ui.window.makeKeyAndOrderFront(null); $.NSApplication.sharedApplication.activateIgnoringOtherApps(true); };

// What's new: the release log in its own window.
handlers.helpdesk = () => {
  // A new email to the helpdesk with this Mac's details filled in (4.0).
  let url = $.NSURL.URLWithString(st.helpdesk || 'mailto:helpdesk@schoolathome.ca');
  if (url.isNil()) url = $.NSURL.URLWithString('mailto:helpdesk@schoolathome.ca');
  $.NSWorkspace.sharedWorkspace.openURL(url);
};
handlers.whatsNew = () => {
  if (ui.news && !ui.news.isNil()) { ui.news.makeKeyAndOrderFront(null); return; }
  const md = sh(['--whatsnew']);
  // Plain text, then bold for the version headings and **marked** words.
  let text = '';
  const bolds = [], heads = [];
  md.split('\n').forEach(line => {
    if (line.startsWith('### ')) { const t = line.slice(4); heads.push([text.length + 1, t.length]); text += '\n' + t + '\n'; return; }
    if (!line.trim()) return;
    const isItem = line.startsWith('- ');
    text += isItem ? '  •  ' : '';
    (isItem ? line.slice(2) : line).split('**').forEach((part, i) => { if (i % 2) bolds.push([text.length, part.length]); text += part; });
    text += '\n';
  });
  const w = $.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer(R(0, 0, 620, 560), 1 | 2 | 8, 2, false);
  w.title = "What's new in TLA BootPaper";
  w.releasedWhenClosed = false;
  const sv = C('NSScrollView').alloc.initWithFrame(w.contentView.bounds);
  sv.hasVerticalScroller = true; sv.autoresizingMask = 2 | 16;
  const tv = C('NSTextView').alloc.initWithFrame(w.contentView.bounds);
  tv.editable = false; tv.textContainerInset = $.NSMakeSize(20, 16); tv.autoresizingMask = 2;
  tv.string = text.replace(/^\n/, '');
  const shift = text.startsWith('\n') ? 1 : 0;
  tv.font = $.NSFont.systemFontOfSize(13);
  bolds.forEach(r => tv.setFontRange($.NSFont.boldSystemFontOfSize(13), $.NSMakeRange(r[0] - shift, r[1])));
  heads.forEach(r => tv.setFontRange($.NSFont.boldSystemFontOfSize(16), $.NSMakeRange(r[0] - shift, r[1])));
  sv.documentView = tv;
  w.contentView.addSubview(sv);
  w.center; w.makeKeyAndOrderFront(null);
  ui.news = w;
};

// ---- Report a problem (4.3) ----------------------------------------------------------------------------------
// A short form, then a new email to the helpdesk in the person's mail app with what's wrong and this Mac's details
// (settings.zsh --details). Nothing is sent by itself: they check the email and press Send.
const HELPDESK = 'helpdesk@schoolathome.ca';
const TOPICS = ['Sound, speakers or microphone', 'Screen or display', 'Keyboard, mouse or trackpad', 'Wi-Fi or internet',
                'Battery or charging', 'Camera', 'Signing in or passwords', 'An app or website', 'Slow, freezing or crashing',
                'Printing', 'TLA BootPaper (backgrounds or intro videos)', 'Something else'];
function openReport() {
  if (ui.report && ui.reportOpen) { ui.report.makeKeyAndOrderFront(null); return; }
  if (!ui.target) ui.target = $.TBTarget.alloc.init;
  const W = 580, H = 690;
  const w = $.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer(R(0, 0, W, H), 1 | 2 | 8, 2, false);
  w.title = 'Report a problem - TLA';
  w.releasedWhenClosed = false;
  w.delegate = ui.target;
  const doc = $.TBFlipped.alloc.initWithFrame(R(0, 0, W, H));
  w.contentView = doc;
  const add = v => { doc.addSubview(v); return v; };
  const x0 = 28, inner = W - 56;
  let y = 24;
  const icon = C('NSImage').alloc.initWithContentsOfFile('/Library/Application Support/ca.schoolathome.welcomevideo/AppIcon.png');
  const hasIcon = !icon.isNil();
  if (hasIcon) { const iv = add(C('NSImageView').alloc.initWithFrame(R(x0, y, 44, 44))); iv.image = icon; iv.imageScaling = 3; }
  const title = add(label('Report a problem', 22, { bold: true }));
  place(title, hasIcon ? x0 + 58 : x0, y + 9, inner - 58, 28); y += 56;
  const sub = add(label("Tell the helpdesk what's wrong. This Mac's details are added for you, so they can find it and help faster.", 13, { grey: true, wrap: true }));
  let hh = fitHeight(sub, inner); place(sub, x0, y, inner, hh); y += hh + 16;
  place(add(label("What's it about?", 13, { grey: true })), x0, y, inner, 18); y += 22;
  const topic = add(C('NSPopUpButton').alloc.initWithFramePullsDown(R(x0 - 3, y, 340, 26), false));
  ['Choose one'].concat(TOPICS).forEach(t => topic.addItemWithTitle(t));
  topic.target = ui.target; topic.action = 'reportTopic:';
  y += 38;
  place(add(label('What happened?', 13, { grey: true })), x0, y, inner, 18); y += 22;
  const sv = add(C('NSScrollView').alloc.initWithFrame(R(x0, y, inner, 110)));
  sv.hasVerticalScroller = true; sv.borderType = 2;
  const tv = C('NSTextView').alloc.initWithFrame(R(0, 0, inner - 4, 110));
  tv.richText = false; tv.font = $.NSFont.systemFontOfSize(13); tv.textContainerInset = $.NSMakeSize(4, 5);
  tv.autoresizingMask = 2; tv.delegate = ui.target;
  sv.documentView = tv;
  y += 116;
  const hint = add(label('What were you doing, and what did you expect to happen? Any error message helps. (You can attach a screenshot to the email.)', 11, { light: true, wrap: true }));
  hh = fitHeight(hint, inner); place(hint, x0, y, inner, hh); y += hh + 14;
  place(add(label('How much is it getting in the way?', 13, { grey: true })), x0, y, inner, 18); y += 24;
  const blocking = add($.NSButton.radioButtonWithTitleTargetAction("I can't do my work", ui.target, 'reportTopic:'));
  place(blocking, x0, y, inner, 20); y += 26;
  const annoying = add($.NSButton.radioButtonWithTitleTargetAction('I can still work around it', ui.target, 'reportTopic:'));
  place(annoying, x0, y, inner, 20); y += 32;
  annoying.state = 1;
  place(add(label('Details about this Mac that will be included', 13, { grey: true })), x0, y, inner, 18); y += 22;
  const dsv = add(C('NSScrollView').alloc.initWithFrame(R(x0, y, inner, 120)));
  dsv.hasVerticalScroller = true; dsv.borderType = 2;
  const dtv = C('NSTextView').alloc.initWithFrame(R(0, 0, inner - 4, 120));
  dtv.editable = false; dtv.richText = false; dtv.font = $.NSFont.systemFontOfSize(11); dtv.textContainerInset = $.NSMakeSize(4, 5);
  dtv.autoresizingMask = 2; dtv.string = 'Collecting the details...';
  dsv.documentView = dtv;
  y += 130;
  const done = add(label('', 13, { wrap: true }));
  done.textColor = $.NSColor.systemGreenColor;
  place(done, x0, y, inner, 36); y += 44;
  const copy = add($.NSButton.buttonWithTitleTargetAction('Copy report', ui.target, 'reportCopy:'));
  const cancel = add($.NSButton.buttonWithTitleTargetAction('Cancel', ui.target, 'reportCancel:'));
  const send = add($.NSButton.buttonWithTitleTargetAction('Email the helpdesk', ui.target, 'reportSend:'));
  cancel.keyEquivalent = '\u001b';
  send.enabled = false;
  place(copy, x0 - 6, y, 130, 32);
  place(send, W - x0 - 170 + 6, y, 170, 32);
  place(cancel, W - x0 - 170 - 8 - 100 + 6, y, 100, 32);
  y += 48;
  w.setContentSize($.NSMakeSize(W, y)); doc.setFrame(R(0, 0, W, y));
  ui.report = w; ui.reportOpen = true;
  ui.rep = { topic: topic, text: tv, blocking: blocking, annoying: annoying, details: dtv, done: done, send: send, cancel: cancel };
  w.center; w.makeKeyAndOrderFront(null);
  w.makeFirstResponder(tv);
  $.NSApplication.sharedApplication.activateIgnoringOtherApps(true);
  // The details take a moment (system_profiler): read them once the window is showing.
  const app = $.NSApplication.sharedApplication;
  for (let i = 0; i < 4; i++) { const ev = app.nextEventMatchingMaskUntilDateInModeDequeue(0xFFFFFFFF, $.NSDate.dateWithTimeIntervalSinceNow(0.05), 'kCFRunLoopDefaultMode', true); if (!ev.isNil()) app.sendEvent(ev); }
  const details = sh(['--details']).trim();
  dtv.string = details || 'Computer details could not be read.';
}
function reportReady() {
  if (!ui.rep) return;
  ui.rep.send.enabled = ui.rep.topic.indexOfSelectedItem > 0 && ui.rep.text.string.js.trim() !== '';
}
function reportContent() {
  const r = ui.rep;
  const topic = TOPICS[r.topic.indexOfSelectedItem - 1] || 'Something else';
  const urgent = r.blocking.state === 1;
  const computer = (r.details.string.js.match(/^Computer: (.*)$/m) || [])[1] || '';
  const subject = (urgent ? 'URGENT - ' : '') + 'Problem report: ' + topic + (computer ? ' (' + computer + ')' : '');
  const body = "What it's about: " + topic + '\n' +
               "How much it's getting in the way: " + (urgent ? "I can't do my work" : 'I can still work around it') + '\n\n' +
               'What happened:\n' + r.text.string.js.trim() + '\n\n' +
               '-- Details about this Mac (added by TLA BootPaper) --\n' + r.details.string.js + '\n';
  return { subject: subject, body: body };
}
function copyText(text) {
  const pb = $.NSPasteboard.generalPasteboard;
  pb.clearContents;
  return pb.setStringForType($(text), $('public.utf8-plain-text'));
}
function reportSend() {
  const c = reportContent(), r = ui.rep;
  const open = u => { const url = $.NSURL.URLWithString(u); return !url.isNil() && $.NSWorkspace.sharedWorkspace.openURL(url); };
  let msg = 'Your email to the helpdesk is ready in your mail app. Check it, add a screenshot if you like, then press Send.';
  if (!open('mailto:' + HELPDESK + '?subject=' + encodeURIComponent(c.subject) + '&body=' + encodeURIComponent(c.body))) {
    // No mail app set up: Outlook on the web instead, or the clipboard.
    if (open('https://outlook.office.com/mail/deeplink/compose?to=' + encodeURIComponent(HELPDESK) + '&subject=' +
             encodeURIComponent(c.subject) + '&body=' + encodeURIComponent(c.body))) {
      msg = 'Your email to the helpdesk is ready in Outlook on the web. Check it, then press Send.';
    } else {
      copyText(c.body);
      msg = "Couldn't open an email. Your report is on the clipboard: paste it into an email to " + HELPDESK + '.';
    }
  }
  r.done.stringValue = msg;
  r.cancel.title = 'Close';
}
function reportCopy() {
  const c = reportContent();
  ui.rep.done.stringValue = copyText('To: ' + HELPDESK + '\nSubject: ' + c.subject + '\n\n' + c.body)
    ? 'Copied. Paste it into an email to ' + HELPDESK + '.' : "Couldn't copy it.";
}

function run(argv) {
  try {
    SCRIPT = argv[0];
    st = loadState();
    if (!st.release) return 'error: no settings';
    const app = $.NSApplication.sharedApplication;
    app.setActivationPolicy(1);
    app.finishLaunching;
    if (argv[1] === '--report') {   // 4.3: just the report form ("Report a problem to TLA")
      openReport();
      const test = $.NSProcessInfo.processInfo.environment.objectForKey('TB_TEST');
      if (!test.isNil()) return selfTestReport(app, test.js);
      while (!quit) {
        const ev = app.nextEventMatchingMaskUntilDateInModeDequeue(
          0xFFFFFFFF, $.NSDate.dateWithTimeIntervalSinceNow(0.25), 'kCFRunLoopDefaultMode', true);
        if (!ev.isNil()) app.sendEvent(ev);
      }
      ui.report.orderOut(null);
      return 'ok';
    }
    build(); refresh();
    ui.window.center;
    ui.window.makeKeyAndOrderFront(null);
    app.activateIgnoringOtherApps(true);
    const test = $.NSProcessInfo.processInfo.environment.objectForKey('TB_TEST');
    if (!test.isNil()) return selfTest(app, test.js);
    while (!quit) {
      const ev = app.nextEventMatchingMaskUntilDateInModeDequeue(
        0xFFFFFFFF, $.NSDate.dateWithTimeIntervalSinceNow(0.25), 'kCFRunLoopDefaultMode', true);
      if (!ev.isNil()) app.sendEvent(ev);
      tick();   // (5.0)
    }
    ui.window.orderOut(null);
    if (ui.news) ui.news.orderOut(null);
    if (ui.report) ui.report.orderOut(null);
    return 'ok';
  } catch (e) {
    return 'error: ' + e;
  }
}

// Developer check (TB_TEST=<folder>): pictures of the window in a few states, then quits. Not used normally.
function selfTest(app, dir) {
  const pump = n => { for (let i = 0; i < n; i++) { const ev = app.nextEventMatchingMaskUntilDateInModeDequeue(
    0xFFFFFFFF, $.NSDate.dateWithTimeIntervalSinceNow(0.05), 'kCFRunLoopDefaultMode', true); if (!ev.isNil()) app.sendEvent(ev); } };
  const shot = (win, name) => {
    pump(6);
    const v = win.contentView, rep = v.bitmapImageRepForCachingDisplayInRect(v.bounds);
    v.cacheDisplayInRectToBitmapImageRep(v.bounds, rep);
    rep.representationUsingTypeProperties(4, $({})).writeToFileAtomically(dir + '/' + name, true);
  };
  shot(ui.window, 'shot1-top.png');
  ui.doc.scrollPoint($.NSMakePoint(0, 100000)); shot(ui.window, 'shot2-bottom.png');
  handlers.tile({ tag: 6 }); pump(10); shot(ui.window, 'shot3-picked.png');
  ui.window.setContentSize($.NSMakeSize(680, 700)); ui.doc.scrollPoint($.NSMakePoint(0, 100000)); shot(ui.window, 'shot4-narrow.png');
  handlers.whatsNew(); shot(ui.news, 'shot5-news.png');
  // 4.3: the Updates section, then switching channel, and the report form.
  ui.window.setContentSize($.NSMakeSize(790, 900)); ui.doc.scrollPoint($.NSMakePoint(0, 100000)); shot(ui.window, 'shot6-updates.png');
  const other = st.channels.findIndex(c => c.id !== (st.channel || 'stable'));
  handlers.channel({ tag: other }); pump(4); ui.doc.scrollPoint($.NSMakePoint(0, 100000)); shot(ui.window, 'shot7-channel.png');
  const back = st.channels.findIndex(c => c.id !== (st.channel || 'stable'));
  handlers.channel({ tag: back });
  // 5.0: the Screensaver, calls and reminders section.
  ui.doc.scrollPoint($.NSMakePoint(0, Math.max(0, ui.hExtras.frame.origin.y - 20))); shot(ui.window, 'shot9-extras.png');
  // 5.5.5: the greeting turned off (the name stays), and the window in dark mode.
  ui.doc.scrollPoint($.NSMakePoint(0, Math.max(0, ui.hVideo.frame.origin.y - 20)));
  handlers.greeting({ state: 0 }); pump(4); shot(ui.window, 'shot10-greeting-off.png');
  handlers.greeting({ state: 1 }); pump(2);
  ui.window.appearance = $.NSAppearance.appearanceNamed('NSAppearanceNameDarkAqua');
  ui.doc.scrollPoint($.NSMakePoint(0, 0)); shot(ui.window, 'shot11-dark-top.png');
  ui.doc.scrollPoint($.NSMakePoint(0, Math.max(0, ui.hBg.frame.origin.y - 20))); shot(ui.window, 'shot12-dark-backgrounds.png');
  ui.window.appearance = $.NSAppearance.appearanceNamed('NSAppearanceNameAqua');
  return selfTestReport(app, dir, 'ok (test)');
}
function selfTestReport(app, dir, result) {
  const pump = n => { for (let i = 0; i < n; i++) { const ev = app.nextEventMatchingMaskUntilDateInModeDequeue(
    0xFFFFFFFF, $.NSDate.dateWithTimeIntervalSinceNow(0.05), 'kCFRunLoopDefaultMode', true); if (!ev.isNil()) app.sendEvent(ev); } };
  if (!ui.reportOpen) openReport();
  ui.rep.topic.selectItemAtIndex(1); ui.rep.text.string = 'Sound stops after a few minutes.'; reportReady();
  pump(6);
  const v = ui.report.contentView, rep = v.bitmapImageRepForCachingDisplayInRect(v.bounds);
  v.cacheDisplayInRectToBitmapImageRep(v.bounds, rep);
  rep.representationUsingTypeProperties(4, $({})).writeToFileAtomically(dir + '/shot8-report.png', true);
  const c = reportContent();
  $(c.subject + '\n' + c.body + '\nsend enabled: ' + ui.rep.send.enabled).writeToFileAtomicallyEncodingError(dir + '/report.txt', true, 4, null);
  return result || 'ok (test report)';
}

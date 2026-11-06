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
        const top = y;
        row(ui.lCalls, null, 0, ui.callsNote);
        // (the buttons under the note, then the link to take them out)
        y -= 10;
        place(ui.callsAdd, x0 + px - 6, y, w1, 32); place(ui.callsOpen, x0 + px - 6 + w1 + 4, y, w2, 32);
        if (!ui.callsRemove.hidden) place(ui.callsRemove, x0 + px + w1 + w2 + 14, y + 7, ui.callsRemove.frame.size.width, 18);
        y += 44;
        if (top === y) y += 1;
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


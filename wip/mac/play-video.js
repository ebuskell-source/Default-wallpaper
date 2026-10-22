// play-video.js - the intro video, full screen. Run with:
//   osascript -l JavaScript play-video.js <video file> <allow skip: 1|0> <longest seconds>
// Covers every screen (the video on the main one, black on the others), above the menu bar and Dock,
// keeping the video's proportions. With skip allowed there's a Skip button, and Esc works too.
// Prints "played", "skipped" or "error: ..." (the login script falls back to swiftDialog on an error).
ObjC.import('AppKit');

let done = '';

ObjC.registerSubclass({
  name: 'WVWindow', superclass: 'NSWindow',
  methods: {
    canBecomeKeyWindow:  { types: ['bool', []], implementation: function () { return true; } },
    canBecomeMainWindow: { types: ['bool', []], implementation: function () { return true; } },
  },
});
ObjC.registerSubclass({
  name: 'WVSkipTarget', superclass: 'NSObject',
  methods: { 'skip:': { types: ['void', ['id']], implementation: function (sender) { done = 'skipped'; } } },
});

function run(argv) { try { return play(argv); } catch (e) { return 'error: ' + e; } }

function play(argv) {
  const file = argv[0], allowSkip = argv[1] === '1', longest = Math.max(5, parseInt(argv[2] || '60', 10) || 60);
  const greeting = argv[3] || '';          // 4.0: 'Good morning, Sam!' over the first few seconds
  // 5.5.5: the theme's greeting style (tla-player draws it fully; this fallback just takes its first colour)
  const styleColor = ((argv[4] || '').match(/(?:^|;)c=([0-9A-Fa-f]{6})/) || [])[1] || '';
  if (!file || !$.NSFileManager.defaultManager.fileExistsAtPath(file)) return 'error: no video file';

  const app = $.NSApplication.sharedApplication;
  app.setActivationPolicy(1);      // no Dock icon
  app.finishLaunching;

  const screens = $.NSScreen.screens;
  const main = $.NSScreen.mainScreen;
  const windows = [];
  let videoWindow = null, videoView = null;
  for (let i = 0; i < screens.count; i++) {
    const screen = screens.objectAtIndex(i);
    const w = $.WVWindow.alloc.initWithContentRectStyleMaskBackingDefer(screen.frame, 0, 2, false);  // borderless, buffered
    w.setFrameDisplay(screen.frame, true);
    w.backgroundColor = $.NSColor.blackColor;
    w.opaque = true;
    w.level = 1000;                       // screen saver level: above the menu bar and Dock
    w.collectionBehavior = (1 << 0) | (1 << 4);   // every Space, stays put
    w.releasedWhenClosed = false;
    windows.push(w);
    if (screen.isEqual(main) || videoWindow === null) { videoWindow = w; }
  }
  // Cover the screens straight away (black), before the slower video set-up, so the desktop isn't seen.
  windows.forEach(w => { w.orderFrontRegardless; w.display; });
  app.activateIgnoringOtherApps(true);
  $.NSCursor.setHiddenUntilMouseMoves(true);
  const ev0 = app.nextEventMatchingMaskUntilDateInModeDequeue(   // one turn of the event loop puts them on screen
    0xFFFFFFFF, $.NSDate.dateWithTimeIntervalSinceNow(0.01), 'kCFRunLoopDefaultMode', true);
  if (!ev0.isNil()) app.sendEvent(ev0);
  videoView = videoWindow.contentView;
  videoView.wantsLayer = true;

  // $.AVPlayer isn't bridged on current macOS: load the framework and look the classes up by name.
  $.NSBundle.bundleWithPath('/System/Library/Frameworks/AVFoundation.framework').load;
  const AVPlayer = $.NSClassFromString('AVPlayer'), AVPlayerLayer = $.NSClassFromString('AVPlayerLayer');

  const player = AVPlayer.playerWithURL($.NSURL.fileURLWithPath(file));
  const layer = AVPlayerLayer.playerLayerWithPlayer(player);
  layer.videoGravity = 'AVLayerVideoGravityResizeAspect';   // whole video, black bars if the shapes differ
  layer.frame = videoView.bounds;
  layer.autoresizingMask = 2 | 16;        // width and height follow the window
  videoView.layer.addSublayer(layer);

  if (allowSkip) {
    const b = $.NSButton.alloc.initWithFrame($.NSMakeRect(0, 0, 110, 36));
    b.title = 'Skip';
    b.bezelStyle = 1;                     // rounded
    b.controlSize = 3;                    // large
    b.keyEquivalent = '\u001b';           // Esc
    b.sizeToFit;
    const bounds = videoView.bounds;
    b.setFrameOrigin($.NSMakePoint(bounds.size.width - b.frame.size.width - 40, 40));
    b.autoresizingMask = 1 | 32;          // stays bottom right
    b.target = $.WVSkipTarget.alloc.init;
    b.action = 'skip:';
    videoView.addSubview(b);
  }

  let hello = null;
  if (greeting) {
    // White, bold, with a soft shadow, centred low on the picture (clear of the logo).
    const bounds = videoView.bounds, size = Math.max(28, bounds.size.height / 19);
    hello = $.NSClassFromString('NSTextField').labelWithString(greeting);   // (looked up by name: not always bridged)
    hello.font = $.NSFont.boldSystemFontOfSize(size);
    hello.textColor = styleColor
      ? $.NSColor.colorWithSRGBRedGreenBlueAlpha(parseInt(styleColor.slice(0, 2), 16) / 255, parseInt(styleColor.slice(2, 4), 16) / 255,
                                                 parseInt(styleColor.slice(4, 6), 16) / 255, 1)
      : $.NSColor.whiteColor;
    hello.alignment = 2;                  // centred
    const shadow = $.NSClassFromString('NSShadow').alloc.init;
    shadow.shadowColor = $.NSColor.blackColor.colorWithAlphaComponent(0.85);
    shadow.shadowBlurRadius = 10;
    shadow.shadowOffset = $.NSMakeSize(0, -2);
    hello.shadow = shadow;
    hello.frame = $.NSMakeRect(40, bounds.size.height / 13, bounds.size.width - 80, size * 1.5);
    hello.autoresizingMask = 2;
    hello.wantsLayer = true;
    hello.alphaValue = 0;
    videoView.addSubview(hello);
  }

  videoWindow.makeKeyAndOrderFront(null);
  app.activateIgnoringOtherApps(true);
  player.play;

  const start = Date.now();
  let started = false, shownAt = 0;
  while (!done) {
    const ev = app.nextEventMatchingMaskUntilDateInModeDequeue(
      0xFFFFFFFF, $.NSDate.dateWithTimeIntervalSinceNow(0.03), 'kCFRunLoopDefaultMode', true);
    if (!ev.isNil()) app.sendEvent(ev);

    const item = player.currentItem;
    if (!item.isNil() && item.status === 2) { done = 'error: macOS could not play the video'; break; }
    if (player.rate > 0) { if (!started) shownAt = Date.now(); started = true; }
    else if (started) done = 'played';                       // it reached the end
    if (hello && started) {                                  // fade in, hold, fade out by 5.2 seconds
      const g = (Date.now() - shownAt) / 1000;
      hello.alphaValue = g < 0.3 ? 0 : g < 0.8 ? (g - 0.3) / 0.5 : g < 4.5 ? 1 : g < 5.2 ? 1 - (g - 4.5) / 0.7 : 0;
    }
    const seconds = (Date.now() - start) / 1000;
    if (!started && seconds > 8) done = 'error: the video did not start';
    if (seconds > longest) done = 'played';
  }

  player.pause;
  windows.forEach(w => w.orderOut(null));
  return done;
}

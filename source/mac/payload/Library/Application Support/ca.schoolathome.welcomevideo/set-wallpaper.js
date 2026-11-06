// set-wallpaper.js - run with: osascript -l JavaScript set-wallpaper.js set <image path> [Fill|Fit] [all|changed] | get
// Sets (or reads) the desktop picture on every screen for the logged-in person, using the same
// macOS call as System Settings. Needs no extra permissions.
ObjC.import('AppKit');

function run(argv) {
  const ws = $.NSWorkspace.sharedWorkspace;
  const screens = $.NSScreen.screens;
  const count = screens.count;

  // 5.0: "mode": whether macOS is showing light or dark right now. (With Appearance set to Auto, macOS 27 doesn't
  // record which it is in its settings, so the system is asked.)
  if (argv[0] === 'mode') {
    const best = $.NSApplication.sharedApplication.effectiveAppearance.bestMatchFromAppearancesWithNames(
      $(['NSAppearanceNameAqua', 'NSAppearanceNameDarkAqua']));
    return (!best.isNil() && best.js === 'NSAppearanceNameDarkAqua') ? 'dark' : 'light';
  }

  if (argv[0] === 'get') {
    const paths = [];
    for (let i = 0; i < count; i++) {
      const url = ws.desktopImageURLForScreen(screens.objectAtIndex(i));
      paths.push(url.isNil() ? '' : ObjC.unwrap(url.path));
    }
    return paths.join('\n');
  }

  if (argv[0] === 'set' && argv[1]) {
    const url = $.NSURL.fileURLWithPath(argv[1]);
    // Fill the screen, keeping the proportions (the pictures have spare room above and below for this). 4.2: or
    // "Fit": the whole picture, with black at the sides if the screen's shape is different.
    const fit = argv[2] === 'Fit';
    const values = [$.NSNumber.numberWithInt(3), $.NSNumber.numberWithBool(!fit)];
    const keys = [$.NSWorkspaceDesktopImageScalingKey, $.NSWorkspaceDesktopImageAllowClippingKey];
    if (fit && typeof $.NSWorkspaceDesktopImageFillColorKey !== 'undefined') {   // (black sides; macOS's own colour otherwise)
      values.push($.NSColor.blackColor); keys.push($.NSWorkspaceDesktopImageFillColorKey);
    }
    const options = $.NSDictionary.dictionaryWithObjectsForKeys(values, keys);
    // 5.0: "changed" sets only the screens showing another picture (no flicker on the ones already right).
    const onlyChanged = argv[3] === 'changed';
    let ok = count > 0;
    for (let i = 0; i < count; i++) {
      const screen = screens.objectAtIndex(i);
      if (onlyChanged) {
        const now = ws.desktopImageURLForScreen(screen);
        if (!now.isNil() && ObjC.unwrap(now.path) === argv[1]) continue;
      }
      if (!ws.setDesktopImageURLForScreenOptionsError(url, screen, options, null)) {
        ok = false;
      }
    }
    return ok ? 'ok' : 'failed';
  }

  return 'usage: set <image path> [Fill|Fit] [all|changed] | get';
}

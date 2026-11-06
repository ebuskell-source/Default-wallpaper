// aerial-idle.js - the screensaver in this person's wallpaper store (macOS 14 and later), for TLA BootPaper 5.0.
//   osascript -l JavaScript aerial-idle.js get                      the screensaver's provider ('' if none)
//   osascript -l JavaScript aerial-idle.js set <extension id> <configuration>
//                                                                   makes that wallpaper extension the screensaver
//   osascript -l JavaScript aerial-idle.js restore                  puts back the screensaver from before TLA BootPaper's
// "set" and "restore" print "ok" (or "error: ..."/"none"); the caller then restarts WallpaperAgent so it takes effect.
//
// macOS keeps each person's desktop picture and screensaver in
// ~/Library/Application Support/com.apple.wallpaper/Store/Index.plist, in sections: "AllSpacesAndDisplays", each
// display ("Displays"), each Space ("Spaces": its "Default" and its own "Displays"), and "SystemDefault". Each
// section can have a "Desktop" choice and an "Idle" (screensaver) choice, and a Type: "individual" (both), "idle"
// (just the screensaver), or "linked" (one choice for both). This writes the screensaver choice into every section,
// the way it looks on a Mac where Aerial's own "Set as screensaver" was used: Provider = the extension,
// Configuration = "aerial", empty option values. Desktop choices are left exactly as they are (a section that used
// one choice for both keeps it as its desktop). Before the first change it keeps a copy of the file
// (Index.plist.tla-bootpaper), for "restore".
ObjC.import('Foundation');

// (TB_STORE: another copy of the file, for testing)
const TB_STORE = $.NSProcessInfo.processInfo.environment.objectForKey('TB_STORE');
const STORE = TB_STORE.isNil() ? $.NSHomeDirectory().js + '/Library/Application Support/com.apple.wallpaper/Store/Index.plist' : TB_STORE.js;
const BACKUP = STORE + '.tla-bootpaper';

function readPlist(path) {
  const data = $.NSData.dataWithContentsOfFile(path);
  if (data.isNil()) return null;
  // Mutable containers, so the sections can be changed in place.
  const plist = $.NSPropertyListSerialization.propertyListWithDataOptionsFormatError(data, 2, null, null);
  return plist.isNil() ? null : plist;
}

function writePlist(plist, path) {
  const data = $.NSPropertyListSerialization.dataWithPropertyListFormatOptionsError(plist, 200, 0, null);   // binary
  if (data.isNil()) return false;
  return data.writeToFileAtomically(path, true);
}

const str = v => (v && !v.isNil() && v.isKindOfClass($.NSString)) ? v.js : '';
const dict = v => (v && !v.isNil() && v.isKindOfClass($.NSDictionary)) ? v : null;
function keysOf(d) { const out = [], k = d.allKeys; for (let i = 0; i < k.count; i++) out.push(k.objectAtIndex(i).js); return out; }

// The provider of a slot ({ Content: { Choices: [ { Provider } ] } }), or ''.
function providerOf(slot) {
  slot = dict(slot);
  if (!slot) return '';
  const content = dict(slot.objectForKey('Content'));
  if (!content) return '';
  const choices = content.objectForKey('Choices');
  if (!choices || choices.isNil() || !choices.isKindOfClass($.NSArray) || choices.count === 0) return '';
  const first = dict(choices.objectAtIndex(0));
  return first ? str(first.objectForKey('Provider')) : '';
}

// Every section, by path, in the order macOS looks: AllSpacesAndDisplays, the displays, the Spaces (Default, then
// their displays), SystemDefault.
function sections(plist) {
  const out = [];
  const push = (path, d) => { if (d) out.push({ path: path, d: d }); };
  push('AllSpacesAndDisplays', dict(plist.objectForKey('AllSpacesAndDisplays')));
  const displays = dict(plist.objectForKey('Displays'));
  if (displays) keysOf(displays).forEach(k => push('Displays/' + k, dict(displays.objectForKey(k))));
  const spaces = dict(plist.objectForKey('Spaces'));
  if (spaces) keysOf(spaces).forEach(k => {
    const space = dict(spaces.objectForKey(k));
    if (!space) return;
    push('Spaces/' + k + '/Default', dict(space.objectForKey('Default')));
    const sd = dict(space.objectForKey('Displays'));
    if (sd) keysOf(sd).forEach(d => push('Spaces/' + k + '/Displays/' + d, dict(sd.objectForKey(d))));
  });
  push('SystemDefault', dict(plist.objectForKey('SystemDefault')));
  return out;
}

function currentIdle(plist) {
  for (const s of sections(plist)) {
    const type = str(s.d.objectForKey('Type'));
    const p = providerOf(s.d.objectForKey(type === 'linked' ? 'Linked' : 'Idle'));
    if (p) return p;
  }
  return '';
}

function idleSlot(provider, configuration) {
  const values = $.NSPropertyListSerialization.dataWithPropertyListFormatOptionsError($({ values: {} }), 200, 0, null);
  const choice = $.NSMutableDictionary.dictionary;
  choice.setObjectForKey($(provider), 'Provider');
  choice.setObjectForKey($(configuration).dataUsingEncoding(4), 'Configuration');   // (4: UTF-8)
  choice.setObjectForKey($.NSMutableArray.array, 'Files');
  const content = $.NSMutableDictionary.dictionary;
  content.setObjectForKey($.NSMutableArray.arrayWithObject(choice), 'Choices');
  content.setObjectForKey(values, 'EncodedOptionValues');
  content.setObjectForKey($('$null'), 'Shuffle');
  const slot = $.NSMutableDictionary.dictionary;
  slot.setObjectForKey(content, 'Content');
  slot.setObjectForKey($.NSDate.date, 'LastSet');
  slot.setObjectForKey($.NSDate.date, 'LastUse');
  return slot;
}

// One section: the new screensaver choice. A section that used one choice for both ("linked") keeps that choice as
// its desktop picture. Type follows what the section then holds.
function setIdleIn(section, slot) {
  if (str(section.objectForKey('Type')) === 'linked') {
    const linked = dict(section.objectForKey('Linked'));
    section.removeObjectForKey('Linked');
    if (linked && providerOf(linked) && providerOf(linked) !== 'default' && !dict(section.objectForKey('Desktop'))) {
      section.setObjectForKey(linked, 'Desktop');
    }
  }
  section.setObjectForKey(slot, 'Idle');
  section.setObjectForKey($(dict(section.objectForKey('Desktop')) ? 'individual' : 'idle'), 'Type');
}

function run(argv) {
  try {
    const cmd = argv[0];
    if (cmd === 'get') {
      const plist = readPlist(STORE);
      return plist ? currentIdle(plist) : '';
    }
    if (cmd === 'set') {
      const provider = argv[1], configuration = argv[2] || '';
      if (!provider) return 'error: no extension';
      let plist = readPlist(STORE);
      if (!plist) plist = $.NSMutableDictionary.dictionary;
      // A copy of how it was, once (not over a copy that already has the extension in it).
      const fm = $.NSFileManager.defaultManager;
      if (fm.fileExistsAtPath(STORE) && currentIdle(plist) !== provider) {
        fm.removeItemAtPathError(BACKUP, null);
        fm.copyItemAtPathToPathError(STORE, BACKUP, null);
      }
      const slot = idleSlot(provider, configuration);
      ['AllSpacesAndDisplays', 'SystemDefault'].forEach(name => {
        if (!dict(plist.objectForKey(name))) plist.setObjectForKey($.NSMutableDictionary.dictionary, name);
      });
      sections(plist).forEach(s => setIdleIn(s.d, slot));
      if (!writePlist(plist, STORE)) return 'error: could not write ' + STORE;
      return 'ok';
    }
    if (cmd === 'restore') {
      const before = readPlist(BACKUP), plist = readPlist(STORE);
      if (!before || !plist) return 'none';
      const old = {};
      sections(before).forEach(s => { old[s.path] = s.d; });
      let changed = 0;
      sections(plist).forEach(s => {
        const b = old[s.path];
        if (!b) return;
        if (str(b.objectForKey('Type')) === 'linked') {
          // (one choice for both, as before)
          s.d.removeObjectForKey('Idle'); s.d.removeObjectForKey('Desktop');
          s.d.setObjectForKey(b.objectForKey('Linked'), 'Linked'); s.d.setObjectForKey($('linked'), 'Type');
          changed++;
        } else if (dict(b.objectForKey('Idle'))) {
          s.d.setObjectForKey(b.objectForKey('Idle'), 'Idle');
          s.d.setObjectForKey($(dict(s.d.objectForKey('Desktop')) ? 'individual' : 'idle'), 'Type');
          changed++;
        }
      });
      if (!changed) return 'none';
      if (!writePlist(plist, STORE)) return 'error: could not write ' + STORE;
      $.NSFileManager.defaultManager.removeItemAtPathError(BACKUP, null);
      return 'ok';
    }
    return 'usage: get | set <extension id> <configuration> | restore';
  } catch (e) {
    return 'error: ' + e;
  }
}

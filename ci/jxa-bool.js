ObjC.import('AppKit');
function tryIt(name, def) {
  try { ObjC.registerSubclass(Object.assign({ name: name }, def)); const o = $[name].alloc.init; return name + ': ok'; }
  catch (e) { return name + ': ' + e; }
}
function run() {
  const out = ['arch ' + $.NSRunningApplication.currentApplication.executableArchitecture];
  out.push(tryIt('V1', { superclass: 'NSView', methods: { isFlipped: { types: ['bool', []], implementation: function () { return true; } } } }));
  out.push(tryIt('V2', { superclass: 'NSView', methods: { isFlipped: { types: ['char', []], implementation: function () { return true; } } } }));
  out.push(tryIt('V3', { superclass: 'NSView', methods: { isFlipped: { implementation: function () { return true; } } } }));
  out.push(tryIt('V4', { superclass: 'NSView', methods: { isFlipped: { types: ['BOOL', []], implementation: function () { return true; } } } }));
  out.push(tryIt('V5', { superclass: 'NSView', methods: { isFlipped: { types: ['signed char', []], implementation: function () { return true; } } } }));
  out.push(tryIt('W1', { superclass: 'NSWindow', methods: { canBecomeKeyWindow: { implementation: function () { return true; } } } }));
  out.push(tryIt('D1', { superclass: 'NSObject', methods: { 'applicationShouldHandleReopen:hasVisibleWindows:': { types: ['bool', ['id', 'bool']], implementation: function () { return false; } } } }));
  out.push(tryIt('D2', { superclass: 'NSObject', methods: { 'windowWillClose:': { types: ['void', ['id']], implementation: function () { } } } }));
  try { const v = $.V3.alloc.initWithFrame($.NSMakeRect(0,0,10,10)); out.push('V3 flipped=' + v.isFlipped); } catch (e) { out.push('V3 use: ' + e); }
  return out.join('\n');
}

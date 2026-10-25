ObjC.import('AppKit');
const R = (x, y, w, h) => $.NSMakeRect(x, y, w, h);
function run(argv) {
  const out = [];
  const img = $.NSImage.alloc.initWithContentsOfFile(argv[0]);
  out.push('nil=' + img.isNil());
  const s = img.size;
  out.push('size=' + JSON.stringify(s) + ' typeof=' + typeof s + ' w=' + s.width + ' h=' + s.height);
  try {
    const W = 308, H = 174, f = Math.max(W / s.width, H / s.height), cw = W / f, ch = H / f;
    out.push('f=' + f + ' cw=' + cw + ' ch=' + ch);
    const o = $.NSImage.alloc.initWithSize($.NSMakeSize(W, H));
    out.push('o.size=' + JSON.stringify(o.size));
    o.lockFocus;
    out.push('ctx=' + $.NSGraphicsContext.currentContext.isNil());
    $.NSGraphicsContext.currentContext.imageInterpolation = 3;
    img.drawInRectFromRectOperationFraction(R(0, 0, W, H), R((s.width - cw) / 2, (s.height - ch) / 2, cw, ch), 2, 1);
    o.unlockFocus;
    const rep = $.NSBitmapImageRep.imageRepWithData(o.TIFFRepresentation);
    rep.representationUsingTypeProperties(4, $({})).writeToFileAtomically(argv[1], true);
    out.push('wrote');
  } catch (e) { out.push('error: ' + e); }
  return out.join('\n');
}

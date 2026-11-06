-- greeting.lua (5.6.0): the greeting over the start of the intro video ('Good morning, Sam!'), in the style of the
-- video's theme, for mpv. tla-bootpaper.py starts mpv with --script=greeting.lua and passes the text and the style in
-- TLA_GREETING and TLA_GREETING_STYLE. The same styles and movements as the Mac player (player.c) and the Windows one
-- (greeting.ps1): each letter is its own line of text, moved every frame. The style keys are described in player.c.

local text = os.getenv('TLA_GREETING') or ''
local spec = os.getenv('TLA_GREETING_STYLE') or ''
if text == '' then return end

-- ---- The style ------------------------------------------------------------------------------------------------
local s = { a = 'line', e = 'lin', an = 'c', f = 'sys', w = 'bold', p = '', x = 'fade', pre = '', cur = '',
            t0 = 0.3, st = 0.05, d = 0.5, dx = 0, dy = 0, sc = 1, sx = 1, sy = 1, r = 0, al = 0, bob = 0, bp = 2,
            it = 0, sz = 1, ls = 0, h = 4.5, xd = 0.7, colors = { 'FFFFFFFF' }, glow = nil, glowr = 0.2,
            shadow = '000000D9', shb = 0.18, shx = 0, shy = -0.035 }
local strings = { a = true, e = true, an = true, f = true, w = true, p = true, x = true, pre = true, cur = true }
for part in (spec .. ';'):gmatch('(.-);') do
  local k, v = part:match('^(%w+)=(.*)$')
  if k then
    if strings[k] then s[k] = v
    elseif k == 'c' then
      s.colors = {}
      for c in v:gmatch('[^,]+') do s.colors[#s.colors + 1] = c end
      if #s.colors == 0 then s.colors = { 'FFFFFFFF' } end
    elseif k == 'gl' then
      local c, rad = v:match('^([^:]+):?(.*)$'); s.glow = c; s.glowr = tonumber(rad) or 0.2; s.shadow = nil
    elseif k == 'sh' then
      local c, b, x, y = v:match('^([^:]+):?([^:]*):?([^:]*):?([^:]*)$')
      s.shadow = c; s.shb = tonumber(b) or 0; s.shx = tonumber(x) or 0; s.shy = tonumber(y) or 0
    elseif tonumber(v) then s[k] = tonumber(v) end
  end
end
if s.bp < 0.2 then s.bp = 0.2 end
if s.sz < 0.3 then s.sz = 0.3 end
if s.xd < 0.05 then s.xd = 0.05 end
if s.d < 0 then s.d = 0 end
if s.st < 0 then s.st = 0 end

-- RRGGBB[AA] -> ASS colour (&HBBGGRR&) and ASS alpha (00 = solid)
local function color(hex)
  hex = (hex or 'FFFFFF'):gsub('[^%x]', '')
  if #hex < 6 then hex = 'FFFFFF' end
  local a = #hex >= 8 and tonumber(hex:sub(7, 8), 16) or 255
  return string.format('&H%s%s%s&', hex:sub(5, 6), hex:sub(3, 4), hex:sub(1, 2)), a / 255
end
local function alpha(a) return string.format('&H%02X&', math.floor(255 * (1 - math.max(0, math.min(1, a))) + 0.5)) end

local font = ({ mono = 'Ubuntu Mono', round = 'Ubuntu', serif = 'DejaVu Serif' })[s.f] or 'Ubuntu'
local weight = ({ semibold = 600, heavy = 900, regular = 400 })[s.w] or 700

-- ---- Easing: the same formulas as the Mac player ---------------------------------------------------------------
local function ease(e, t)
  if t <= 0 then return 0 end
  if t >= 1 then return 1 end
  if e == 'out' then local u = 1 - t; return 1 - u * u * u end
  if e == 'back' then local u = t - 1; return 1 + 2.70158 * u * u * u + 1.70158 * u * u end
  if e == 'elastic' then return 2 ^ (-10 * t) * math.sin((t * 10 - 0.75) * (2 * math.pi / 3)) + 1 end
  if e == 'bounce' then
    local n1, d1 = 7.5625, 2.75
    if t < 1 / d1 then return n1 * t * t end
    if t < 2 / d1 then t = t - 1.5 / d1; return n1 * t * t + 0.75 end
    if t < 2.5 / d1 then t = t - 2.25 / d1; return n1 * t * t + 0.9375 end
    t = t - 2.625 / d1; return n1 * t * t + 0.984375
  end
  if e == 'step' then return 1 end
  return t
end
local function clamp01(v) return v < 0 and 0 or (v > 1 and 1 or v) end

-- ---- The letters (whole characters: a UTF-8 lead byte and what follows it) -------------------------------------
local full = s.pre .. text
local letters = {}
for ch in full:gmatch('[%z\1-\127\194-\244][\128-\191]*') do letters[#letters + 1] = ch end
local n = #letters
if n == 0 then return end
local function esc(t) return (t:gsub('\\', '\\\226\129\160'):gsub('{', '\\{'):gsub('}', '\\}')) end

local ov = mp.create_osd_overlay('ass-events')
local W, H, fs, lineW, lineH, cx, wd, order, stagger
local timer, startTime

-- Where each letter goes: measured by libass itself where mpv can (compute_bounds), estimated otherwise.
local function measure(t)
  ov.hidden = true; ov.compute_bounds = true
  ov.data = string.format('{\\an7\\pos(0,0)\\fn%s\\fs%d\\b%d\\i%d\\bord0\\shad0}%s', font, fs, weight, s.it >= 1 and 1 or 0, esc(t))
  local ok, r = pcall(function() return ov:update() end)
  ov.compute_bounds = false
  if ok and type(r) == 'table' and r.x1 and r.x0 then return r.x1 - r.x0, r.y1 - r.y0 end
  return nil
end
local function layout()
  W, H = mp.get_osd_size()
  if not W or W <= 0 or H <= 0 then W, H = 1920, 1080 end
  ov.res_x, ov.res_y = W, H
  fs = math.max(28, H / 19) * s.sz
  local function widths()
    local base = measure('XX')
    cx, wd = {}, {}
    local prefix, x0 = '', 0
    local total
    for i = 1, n do
      prefix = prefix .. letters[i]
      local w = base and measure('X' .. prefix .. 'X')
      local x1 = w and (w - base) or (x0 + fs * (letters[i] == ' ' and 0.28 or 0.56))
      cx[i] = (x0 + x1) / 2 + s.ls * fs * (i - 1); wd[i] = x1 - x0
      x0 = x1
    end
    total = x0 + s.ls * fs * (n - 1)
    local _, hh = measure('Xg')
    return total, hh or fs * 1.25
  end
  lineW, lineH = widths()
  if lineW > W - 80 and lineW > 0 then fs = fs * (W - 80) / lineW; lineW, lineH = widths() end
  order = {}
  for i = 1, n do order[i] = i end
  if s.a == 'rand' then
    math.randomseed(os.time())
    for i = n, 2, -1 do local j = math.random(i); order[i], order[j] = order[j], order[i] end
  end
  stagger = s.st
  if s.a ~= 'line' and n > 1 and s.t0 + (n - 1) * stagger + s.d > 2.2 then
    stagger = math.max(0.012, (2.2 - s.t0 - s.d) / (n - 1))
  end
end

-- One letter (or the whole line) at x, y (its middle, or its bottom for an=b), with its glow or shadow behind it.
local function draw(out, t, x, y, scx, scy, rot, a, col)
  if a <= 0.003 then return end
  local an = s.an == 'b' and 2 or 5
  local base = string.format('\\an%d\\fn%s\\fs%.1f\\b%d\\i%d\\fscx%.1f\\fscy%.1f\\frz%.2f', an, font, fs, weight,
                             s.it >= 1 and 1 or 0, 100 * math.max(0.001, scx), 100 * math.max(0.001, scy), rot)
  if s.glow then
    local gc, ga = color(s.glow)
    out[#out + 1] = string.format('{%s\\pos(%.1f,%.1f)\\1c%s\\3c%s\\1a%s\\3a%s\\bord%.1f\\shad0\\blur%.1f}%s', base, x, y, gc, gc,
                                  alpha(a * ga * 0.85), alpha(a * ga * 0.85), fs * 0.05, s.glowr * fs * 0.45, esc(t))
  elseif s.shadow then
    local sc_, sa = color(s.shadow)
    out[#out + 1] = string.format('{%s\\pos(%.1f,%.1f)\\1c%s\\1a%s\\bord0\\shad0\\blur%.1f}%s', base, x + s.shx * fs, y - s.shy * fs,
                                  sc_, alpha(a * sa), s.shb * fs * 0.5, esc(t))
  end
  local c, ca = color(col)
  out[#out + 1] = string.format('{%s\\pos(%.1f,%.1f)\\1c%s\\1a%s\\bord0\\shad0\\blur0}%s', base, x, y, c, alpha(a * ca), esc(t))
end

local function panel(out, a, sc_)
  if s.p ~= 'glass' and s.p ~= 'term' then return end
  local glass = s.p == 'glass'
  local pw, ph = (lineW + 1.1 * fs) * sc_, (lineH + 0.44 * fs) * sc_
  local r = glass and ph / 2 or 0.18 * fs
  local x0, y0 = W / 2 - pw / 2, H - (H / 13 + 0.25 * fs) - lineH / 2 - ph / 2
  local fill, fa = color(glass and 'FFFFFF38' or '0B0F14C8')
  local edge, ea = color(glass and 'FFFFFF8C' or '4AF62659')
  -- (a rounded rectangle, drawn with Bézier corners)
  local k = r * 0.55
  local d = string.format('m %d %d l %d %d b %d %d %d %d %d %d l %d %d b %d %d %d %d %d %d l %d %d b %d %d %d %d %d %d l %d %d b %d %d %d %d %d %d',
    r, 0, pw - r, 0, pw - r + k, 0, pw, r - k, pw, r, pw, ph - r, pw, ph - r + k, pw - r + k, ph, pw - r, ph,
    r, ph, r - k, ph, 0, ph - r + k, 0, ph - r, 0, r, 0, r - k, r - k, 0, r, 0)
  out[#out + 1] = string.format('{\\an7\\pos(%.1f,%.1f)\\p1\\1c%s\\1a%s\\3c%s\\3a%s\\bord%.1f\\shad0\\blur0.6}%s{\\p0}', x0, y0,
                                fill, alpha(a * fa), edge, alpha(a * ea), glass and 1.5 or 1, d)
end

-- Everything as it is t seconds after the video started. Returns false once it's gone.
local function frame(t)
  local q = clamp01((t - s.h) / s.xd)
  local out_, drop = 1 - q, 0
  if s.x == 'step' then out_ = (q <= 0) and 1 or ((q < 0.2 or (q >= 0.4 and q < 0.6) or q >= 0.8) and 0 or 1)
  elseif s.x == 'drop' then drop = q * q * 1.5 * fs end
  if t > s.h + s.xd + 0.05 then return false end
  local out = {}
  local cxLine = W / 2
  local baseY = H - (H / 13 + 0.25 * fs)                -- the bottom of the line
  local midY = baseY - lineH / 2
  local y0 = (s.an == 'b') and baseY or midY
  local step, lin = s.e == 'step', s.e == 'lin'
  if s.a == 'line' then
    local p0 = s.d > 0 and clamp01((t - s.t0) / s.d) or (t >= s.t0 and 1 or 0)
    local k = step and (p0 >= 1 and 1 or 0) or ease(s.e, p0)
    local fade = step and k or (lin and p0 or clamp01(p0 / 0.4))
    local a = (s.al + (1 - s.al) * fade) * out_
    local sc_ = s.sc + (1 - s.sc) * k
    local tx, ty = s.dx * fs * (1 - k), s.dy * fs * (1 - k)
    if s.bob > 0 then ty = ty + s.bob * fs * math.sin(2 * math.pi * t / s.bp) * clamp01((t - s.t0) / 0.6) end
    panel(out, a, sc_)
    draw(out, full, cxLine + tx, y0 - ty + drop, sc_ * (s.sx + (1 - s.sx) * k), sc_ * (s.sy + (1 - s.sy) * k), s.r * (1 - k), a,
         s.colors[1])
  else
    panel(out, clamp01((t - s.t0 + 0.1) / 0.35) * out_, 1)
    local shown, last = 0, 0
    for j = 1, n do
      local i = order[j]
      local start = s.t0 + (j - 1) * stagger
      local p = s.d > 0 and clamp01((t - start) / s.d) or (t >= start and 1 or 0)
      local k = step and (t >= start and 1 or 0) or ease(s.e, p)
      local a = step and k or (lin and p or clamp01(p / 0.4))
      a = s.al + (1 - s.al) * a
      if t < start then a = math.max(0, s.al) end
      if t >= start then shown = shown + 1; if i > last then last = i end end
      local sc_ = s.sc + (1 - s.sc) * k
      local tx, ty = s.dx * fs * (1 - k), s.dy * fs * (1 - k)
      if s.bob > 0 then ty = ty + s.bob * fs * math.sin(2 * math.pi * t / s.bp - (i - 1) * 0.6) * clamp01((t - start) / 0.6) end
      draw(out, letters[i], cxLine - lineW / 2 + cx[i] + tx, y0 - ty + drop, sc_ * (s.sx + (1 - s.sx) * k),
           sc_ * (s.sy + (1 - s.sy) * k), s.r * (1 - k), a * out_, s.colors[((i - 1) % #s.colors) + 1])
    end
    if s.cur ~= '' and t >= s.t0 - 0.2 then
      local typing = shown < n
      if typing or (t % 0.9) < 0.5 then
        local x = last > 0 and (cx[last] + wd[last] / 2) or 0
        draw(out, s.cur, cxLine - lineW / 2 + x + fs * 0.3, y0 + drop, 1, 1, 0, out_, s.colors[1])
      end
    end
  end
  ov.hidden = false
  ov.data = table.concat(out, '\n')
  ov:update()
  return true
end

local function begin()
  if startTime then return end
  layout()
  startTime = mp.get_time()
  timer = mp.add_periodic_timer(1 / 60, function()
    local ok, more = pcall(frame, mp.get_time() - startTime)
    if not ok or not more then
      if not ok then mp.msg.warn('greeting: ' .. tostring(more)) end
      timer:kill(); ov:remove()
    end
  end)
end
-- (when the video actually starts, like the other players)
mp.register_event('playback-restart', begin)

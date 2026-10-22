# greeting.ps1 (5.5.5)
# The greeting over the start of the intro video ('Good morning, Sam!'), in the style of the video's theme. Loaded by
# play-video.ps1 only when there's a greeting. The same styles and the same movements as the Mac player (player.c)
# and the Linux one (greeting.lua): each letter is its own TextBlock, moved every frame (CompositionTarget.Rendering).
#
# A style is "key=value;key=value" (the table: $WV.GreetingStyles in common.ps1). Anything left out keeps the classic
# look: white, a soft shadow, fading in and out.
#   a    how it comes in: line (all of it at once), seq (one letter after another), rand (letters in a random order)
#   t0   seconds after the video starts   st  seconds between letters   d  seconds each letter takes
#   e    easing: lin, out, back (overshoots), bounce, elastic, step (appears at once)
#   dx dy  where it starts from, in font sizes (dy up)   sc sx sy  starting size (all, across, up)   r  starting turn
#   al   starting opacity   an  c (turn and grow around the middle) or b (around the bottom)
#   bob  keeps bobbing by this much (font sizes)   bp  seconds per bob
#   f    font: sys, round, mono, serif   w  semibold, bold, heavy   it  1 for italic   sz  size (1 = normal)
#   c    colour(s) RRGGBB[AA], cycling through the letters   gl  glow RRGGBB[AA]:radius   sh  shadow RRGGBB[AA]:blur:dx:dy
#   p    a panel behind it: glass, term   pre  text before the greeting   cur  a blinking cursor after it
#   ls   extra space between letters   h  when it starts going (seconds)   xd  how long that takes   x  fade, step, drop
# Uses .NET calls only (no cmdlets), like the rest of the player.

function ConvertFrom-WVGreetingStyle([string]$Spec) {
    $s = @{ a = 'line'; e = 'lin'; an = 'c'; f = 'sys'; w = ''; p = ''; x = 'fade'; pre = ''; cur = ''
            t0 = 0.3; st = 0.05; d = 0.5; dx = 0.0; dy = 0.0; sc = 1.0; sx = 1.0; sy = 1.0; r = 0.0; al = 0.0
            bob = 0.0; bp = 2.0; it = 0.0; sz = 1.0; ls = 0.0; h = 4.5; xd = 0.7
            colors = @('FFFFFFFF'); glow = $null; glowr = 0.2; shadow = '000000D9'; shb = 0.18; shx = 0.0; shy = -0.035 }
    $inv = [Globalization.CultureInfo]::InvariantCulture
    foreach ($part in "$Spec".Split(';')) {
        $eq = $part.IndexOf('=')
        if ($eq -lt 1) { continue }
        $key = $part.Substring(0, $eq); $val = $part.Substring($eq + 1)
        switch -CaseSensitive ($key) {
            { $_ -in 'a', 'e', 'an', 'f', 'w', 'p', 'x', 'pre', 'cur' } { $s[$key] = $val; break }
            'c'  { $s.colors = @($val.Split(',')); break }
            'gl' { $bits = $val.Split(':'); $s.glow = $bits[0]; if ($bits.Count -gt 1) { $s.glowr = [double]::Parse($bits[1], $inv) }; $s.shadow = $null; break }
            'sh' {
                $bits = $val.Split(':'); $s.shadow = $bits[0]; $s.shb = 0.0; $s.shx = 0.0; $s.shy = 0.0
                if ($bits.Count -gt 1) { $s.shb = [double]::Parse($bits[1], $inv) }
                if ($bits.Count -gt 2) { $s.shx = [double]::Parse($bits[2], $inv) }
                if ($bits.Count -gt 3) { $s.shy = [double]::Parse($bits[3], $inv) }
                break
            }
            default { $n = 0.0; if ([double]::TryParse($val, [Globalization.NumberStyles]::Float, $inv, [ref]$n)) { $s[$key] = $n } }
        }
    }
    if ($s.bp -lt 0.2) { $s.bp = 0.2 }
    if ($s.sz -lt 0.3) { $s.sz = 0.3 }
    if ($s.xd -lt 0.05) { $s.xd = 0.05 }
    if ($s.d -lt 0) { $s.d = 0.0 }
    if ($s.st -lt 0) { $s.st = 0.0 }
    return $s
}

# RRGGBB or RRGGBBAA -> a colour (and its opacity, 0 to 1)
function ConvertFrom-WVHexColor([string]$Hex) {
    $h = ($Hex -replace '[^0-9A-Fa-f]', '')
    if ($h.Length -lt 6) { $h = 'FFFFFF' }
    $a = if ($h.Length -ge 8) { [Convert]::ToByte($h.Substring(6, 2), 16) } else { 255 }
    $c = [System.Windows.Media.Color]::FromRgb([Convert]::ToByte($h.Substring(0, 2), 16), [Convert]::ToByte($h.Substring(2, 2), 16),
                                               [Convert]::ToByte($h.Substring(4, 2), 16))
    return @{ Color = $c; Alpha = $a / 255.0 }
}

# Easing: how far along (0 to 1, past 1 while overshooting) at t (0 to 1). The same formulas as the Mac player.
function Get-WVEase([string]$E, [double]$T) {
    if ($T -le 0) { return 0.0 }
    if ($T -ge 1) { return 1.0 }
    switch ($E) {
        'out'     { $u = 1 - $T; return 1 - $u * $u * $u }
        'back'    { $u = $T - 1; return 1 + 2.70158 * $u * $u * $u + 1.70158 * $u * $u }
        'elastic' { return [Math]::Pow(2, -10 * $T) * [Math]::Sin(($T * 10 - 0.75) * (2 * [Math]::PI / 3)) + 1 }
        'bounce'  {
            $n1 = 7.5625; $d1 = 2.75
            if ($T -lt 1 / $d1) { return $n1 * $T * $T }
            if ($T -lt 2 / $d1) { $T -= 1.5 / $d1; return $n1 * $T * $T + 0.75 }
            if ($T -lt 2.5 / $d1) { $T -= 2.25 / $d1; return $n1 * $T * $T + 0.9375 }
            $T -= 2.625 / $d1; return $n1 * $T * $T + 0.984375
        }
        'step'    { return 1.0 }
    }
    return $T
}

# Builds the greeting (hidden until its frames start) and puts it in $Host_, a Grid over the video. W and H: the
# screen's size. Returns $null if it couldn't.
function New-WVGreeting($Host_, [string]$Text, [string]$Spec, [double]$W, [double]$H) {
    $s = ConvertFrom-WVGreetingStyle $Spec
    $full = "$($s.pre)$Text"
    if (-not $full) { return $null }
    $family = switch ($s.f) {
        'mono'  { 'Cascadia Mono, Consolas' }
        'round' { 'Arial Rounded MT Bold, Segoe UI' }
        'serif' { 'Georgia' }
        default { 'Segoe UI' }
    }
    # (no weight given: semibold, as the greeting was before 5.5.5)
    $weight = switch ($s.w) {
        'bold'    { [System.Windows.FontWeights]::Bold }
        'heavy'   { [System.Windows.FontWeights]::Black }
        'regular' { [System.Windows.FontWeights]::Normal }
        default   { [System.Windows.FontWeights]::SemiBold }
    }
    $fontStyle = if ($s.it -ge 1) { [System.Windows.FontStyles]::Italic } else { [System.Windows.FontStyles]::Normal }
    $font = [System.Windows.Media.FontFamily]::new($family)
    $typeface = [System.Windows.Media.Typeface]::new($font, $fontStyle, $weight, [System.Windows.FontStretches]::Normal)
    $culture = [Globalization.CultureInfo]::InvariantCulture
    $measure = {
        param([string]$t, [double]$size)
        $ft = [System.Windows.Media.FormattedText]::new($t, $culture, [System.Windows.FlowDirection]::LeftToRight, $typeface, $size,
                                                        [System.Windows.Media.Brushes]::White, 1.0)
        return $ft
    }
    # The letters (whole characters, so accents and emoji stay together)
    $letters = [System.Collections.Generic.List[string]]::new()
    $e = [Globalization.StringInfo]::GetTextElementEnumerator($full)
    while ($e.MoveNext() -and $letters.Count -lt 96) { $letters.Add([string]$e.GetTextElement()) }
    $n = $letters.Count
    if ($n -eq 0) { return $null }

    # Size: as before (a 19th of the screen's height, at least 28), smaller if the line wouldn't fit
    $fs = [Math]::Max(28, $H / 19) * $s.sz
    $total = (& $measure $full $fs).WidthIncludingTrailingWhitespace + $s.ls * $fs * ($n - 1)
    if ($total -gt $W - 80 -and $total -gt 0) { $fs *= ($W - 80) / $total }
    $line = & $measure $full $fs
    $lineH = $line.Height
    $cx = [double[]]::new($n); $wd = [double[]]::new($n)
    $prefix = ''
    $x0 = 0.0
    for ($i = 0; $i -lt $n; $i++) {
        $prefix += $letters[$i]
        $x1 = (& $measure $prefix $fs).WidthIncludingTrailingWhitespace
        $extra = $s.ls * $fs * $i
        $cx[$i] = ($x0 + $x1) / 2 + $extra; $wd[$i] = $x1 - $x0
        $x0 = $x1
    }
    $lineW = $x0 + $s.ls * $fs * ($n - 1)
    $padX = if ($s.p) { 0.55 * $fs } else { 0.0 }
    $padY = if ($s.p) { 0.22 * $fs } else { 0.0 }
    $boxW = $lineW + 2 * $padX; $boxH = $lineH + 2 * $padY
    $bottom = $s.an -eq 'b'
    $originY = if ($bottom) { 1.0 } else { 0.5 }

    # The order the letters come in
    $order = [int[]](0..($n - 1))
    if ($s.a -eq 'rand') {
        $rng = [Random]::new()
        for ($i = $n - 1; $i -gt 0; $i--) { $j = $rng.Next($i + 1); $t = $order[$i]; $order[$i] = $order[$j]; $order[$j] = $t }
    }

    # The line: a canvas the size of the text (and its panel), low on the picture, clear of the logo
    $canvas = [System.Windows.Controls.Canvas]::new()
    $canvas.Width = $boxW; $canvas.Height = $boxH
    $canvas.HorizontalAlignment = 'Center'; $canvas.VerticalAlignment = 'Bottom'
    $canvas.Margin = [System.Windows.Thickness]::new(0, 0, 0, [Math]::Max(0, $H / 13 + 0.25 * $fs - $padY))
    $canvas.RenderTransformOrigin = [System.Windows.Point]::new(0.5, $originY)
    $canvas.RenderTransform = [System.Windows.Media.MatrixTransform]::new()
    $canvas.Opacity = 0
    $canvas.IsHitTestVisible = $false
    # Glow or shadow, on the whole line (it follows each letter)
    $shadowSpec = if ($s.glow) { $s.glow } else { $s.shadow }
    if ($shadowSpec) {
        $c = ConvertFrom-WVHexColor $shadowSpec
        $fx = [System.Windows.Media.Effects.DropShadowEffect]::new()
        $fx.Color = $c.Color; $fx.Opacity = $c.Alpha
        if ($s.glow) {
            $fx.ShadowDepth = 0; $fx.BlurRadius = $s.glowr * $fs * 1.6
        } else {
            $fx.BlurRadius = $s.shb * $fs * 1.2
            $fx.ShadowDepth = [Math]::Sqrt($s.shx * $s.shx + $s.shy * $s.shy) * $fs
            $fx.Direction = [Math]::Atan2($s.shy, $s.shx) * 180 / [Math]::PI
        }
        $canvas.Effect = $fx
    }
    $panel = $null
    if ($s.p -eq 'glass' -or $s.p -eq 'term') {
        $glass = $s.p -eq 'glass'
        $panel = [System.Windows.Controls.Border]::new()
        $panel.Width = $boxW; $panel.Height = $boxH
        $panel.CornerRadius = [System.Windows.CornerRadius]::new($(if ($glass) { $boxH / 2 } else { 0.18 * $fs }))
        $bg = ConvertFrom-WVHexColor $(if ($glass) { 'FFFFFF38' } else { '0B0F14C8' })
        $line_ = ConvertFrom-WVHexColor $(if ($glass) { 'FFFFFF8C' } else { '4AF62659' })
        $panel.Background = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromArgb([byte]($bg.Alpha * 255), $bg.Color.R, $bg.Color.G, $bg.Color.B))
        $panel.BorderBrush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromArgb([byte]($line_.Alpha * 255), $line_.Color.R, $line_.Color.G, $line_.Color.B))
        $panel.BorderThickness = [System.Windows.Thickness]::new($(if ($glass) { 1.5 } else { 1 }))
        [void]$canvas.Children.Add($panel)
    }
    $blocks = [System.Windows.Controls.TextBlock[]]::new($n)
    $transforms = [System.Windows.Media.MatrixTransform[]]::new($n)
    for ($i = 0; $i -lt $n; $i++) {
        $tb = [System.Windows.Controls.TextBlock]::new()
        $tb.Text = $letters[$i]
        $tb.FontFamily = $font; $tb.FontWeight = $weight; $tb.FontStyle = $fontStyle; $tb.FontSize = $fs
        $col = ConvertFrom-WVHexColor $s.colors[$i % $s.colors.Count]
        $tb.Foreground = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromArgb([byte]($col.Alpha * 255), $col.Color.R, $col.Color.G, $col.Color.B))
        $tb.Width = $wd[$i] + 0.3 * $fs; $tb.Height = $lineH
        $tb.TextAlignment = 'Center'
        $tb.RenderTransformOrigin = [System.Windows.Point]::new(0.5, $originY)
        $transforms[$i] = [System.Windows.Media.MatrixTransform]::new()
        $tb.RenderTransform = $transforms[$i]
        $tb.Opacity = 0
        [System.Windows.Controls.Canvas]::SetLeft($tb, $padX + $cx[$i] - $tb.Width / 2)
        [System.Windows.Controls.Canvas]::SetTop($tb, $padY)
        [void]$canvas.Children.Add($tb)
        $blocks[$i] = $tb
    }
    $cursor = $null
    if ($s.cur) {
        $cursor = [System.Windows.Controls.TextBlock]::new()
        $cursor.Text = $s.cur
        $cursor.FontFamily = $font; $cursor.FontWeight = $weight; $cursor.FontSize = $fs
        $cursor.Foreground = $blocks[0].Foreground
        $cursor.Opacity = 0
        [System.Windows.Controls.Canvas]::SetTop($cursor, $padY)
        [void]$canvas.Children.Add($cursor)
    }
    [void]$Host_.Children.Add($canvas)

    # Long names: the letters come in faster, so they're all in within about two seconds
    $stagger = $s.st
    if ($s.a -ne 'line' -and $n -gt 1 -and $s.t0 + ($n - 1) * $stagger + $s.d -gt 2.2) {
        $stagger = [Math]::Max(0.012, (2.2 - $s.t0 - $s.d) / ($n - 1))
    }
    return @{ Style = $s; Canvas = $canvas; Panel = $panel; Blocks = $blocks; Transforms = $transforms; Cursor = $cursor
              Order = $order; Cx = $cx; Wd = $wd; N = $n; Fs = $fs; PadX = $padX; Stagger = $stagger; Settled = [bool[]]::new($n)
              LineMode = ($s.a -eq 'line'); Step = ($s.e -eq 'step'); Lin = ($s.e -eq 'lin'); Done = $false }
}

function Get-WVGreetingMatrix([double]$Sx, [double]$Sy, [double]$Deg, [double]$Tx, [double]$Ty) {
    # (WPF turns clockwise and counts y downwards: the style's turns and heights are the other way round)
    $rad = -$Deg * [Math]::PI / 180; $c = [Math]::Cos($rad); $sn = [Math]::Sin($rad)
    if ($Sx -lt 0.001) { $Sx = 0.001 }
    if ($Sy -lt 0.001) { $Sy = 0.001 }
    return [System.Windows.Media.Matrix]::new($Sx * $c, $Sx * $sn, -$Sy * $sn, $Sy * $c, $Tx, -$Ty)
}

# Moves everything to where it is $T seconds after the video started. Returns $false once it's gone.
function Set-WVGreetingFrame($G, [double]$T) {
    if ($G.Done) { return $false }
    $s = $G.Style; $fs = $G.Fs
    $q = [Math]::Min(1.0, [Math]::Max(0.0, ($T - $s.h) / $s.xd)); $out = 1.0; $drop = 0.0
    if ($s.x -eq 'step') { $out = if ($q -le 0) { 1.0 } elseif ($q -lt 0.2 -or ($q -ge 0.4 -and $q -lt 0.6) -or $q -ge 0.8) { 0.0 } else { 1.0 } }
    elseif ($s.x -eq 'drop') { $out = 1 - $q; $drop = $q * $q * 1.5 * $fs }
    else { $out = 1 - $q }
    if ($T -gt $s.h + $s.xd + 0.05) {
        $G.Canvas.Visibility = 'Collapsed'
        $G.Done = $true
        return $false
    }
    # The line as a whole
    $lineAlpha = 1.0; $lsx = 1.0; $lsy = 1.0; $lrot = 0.0; $ltx = 0.0; $lty = 0.0
    $p0 = if ($s.d -gt 0) { [Math]::Min(1.0, [Math]::Max(0.0, ($T - $s.t0) / $s.d)) } elseif ($T -ge $s.t0) { 1.0 } else { 0.0 }
    if ($G.LineMode) {
        $k = if ($G.Step) { if ($p0 -ge 1) { 1.0 } else { 0.0 } } else { Get-WVEase $s.e $p0 }
        $fade = if ($G.Step) { $k } elseif ($G.Lin) { $p0 } else { [Math]::Min(1.0, $p0 / 0.4) }
        $lineAlpha = $s.al + (1 - $s.al) * $fade
        $sc = $s.sc + (1 - $s.sc) * $k
        $lsx = $sc * ($s.sx + (1 - $s.sx) * $k); $lsy = $sc * ($s.sy + (1 - $s.sy) * $k)
        $lrot = $s.r * (1 - $k); $ltx = $s.dx * $fs * (1 - $k); $lty = $s.dy * $fs * (1 - $k)
        if ($s.bob -gt 0) { $lty += $s.bob * $fs * [Math]::Sin(2 * [Math]::PI * $T / $s.bp) * [Math]::Min(1.0, [Math]::Max(0.0, ($T - $s.t0) / 0.6)) }
    }
    $lty -= $drop
    $G.Canvas.Opacity = $lineAlpha * $out
    $G.Canvas.RenderTransform.Matrix = Get-WVGreetingMatrix $lsx $lsy $lrot $ltx $lty
    if ($G.Panel) {
        $G.Panel.Opacity = if ($G.LineMode) { 1.0 } else { [Math]::Min(1.0, [Math]::Max(0.0, ($T - $s.t0 + 0.1) / 0.35)) }
    }
    # Each letter
    $shown = 0
    for ($j = 0; $j -lt $G.N; $j++) {
        $i = $G.Order[$j]
        $tb = $G.Blocks[$i]
        if ($G.LineMode) { $tb.Opacity = 1.0; continue }
        $start = $s.t0 + $j * $G.Stagger
        if ($G.Settled[$i]) { $shown++; continue }   # (in place and not bobbing: nothing more to do)
        $p = if ($s.d -gt 0) { [Math]::Min(1.0, [Math]::Max(0.0, ($T - $start) / $s.d)) } elseif ($T -ge $start) { 1.0 } else { 0.0 }
        $k = if ($G.Step) { if ($T -ge $start) { 1.0 } else { 0.0 } } else { Get-WVEase $s.e $p }
        $alpha = if ($G.Step) { $k } elseif ($G.Lin) { $p } else { [Math]::Min(1.0, $p / 0.4) }
        $alpha = $s.al + (1 - $s.al) * $alpha
        if ($T -lt $start) { $alpha = [Math]::Max(0.0, $s.al) }
        $sc = $s.sc + (1 - $s.sc) * $k
        $sx = $sc * ($s.sx + (1 - $s.sx) * $k); $sy = $sc * ($s.sy + (1 - $s.sy) * $k)
        $tx = $s.dx * $fs * (1 - $k); $ty = $s.dy * $fs * (1 - $k)
        if ($s.bob -gt 0) { $ty += $s.bob * $fs * [Math]::Sin(2 * [Math]::PI * $T / $s.bp - $i * 0.6) * [Math]::Min(1.0, [Math]::Max(0.0, ($T - $start) / 0.6)) }
        $tb.Opacity = $alpha
        $G.Transforms[$i].Matrix = Get-WVGreetingMatrix $sx $sy ($s.r * (1 - $k)) $tx $ty
        if ($T -ge $start) { $shown++ }
        if ($p -ge 1 -and $T -ge $start -and $s.bob -le 0) { $G.Settled[$i] = $true }
    }
    if ($G.Cursor) {
        # After the last letter that's in (typing), blinking once they're all in
        $last = -1
        for ($i = 0; $i -lt $G.N; $i++) { if ($G.LineMode -or $T -ge $s.t0 + $i * $G.Stagger) { $last = $i } }
        $x = if ($last -ge 0) { $G.Cx[$last] + $G.Wd[$last] / 2 } else { 0.0 }
        [System.Windows.Controls.Canvas]::SetLeft($G.Cursor, $G.PadX + $x)
        $typing = (-not $G.LineMode) -and $shown -lt $G.N
        $blink = if ($typing -or ($T % 0.9) -lt 0.5) { 1.0 } else { 0.0 }
        $G.Cursor.Opacity = if ($T -ge $s.t0 - 0.2) { $blink } else { 0.0 }
    }
    return $true
}

# Starts the greeting's frames (when the video starts): every frame until it's gone, then it stops.
function Start-WVGreeting($G) {
    if (-not $G) { return }
    $script:greetState = $G
    $script:greetClock = [System.Diagnostics.Stopwatch]::StartNew()
    $script:greetHandler = [EventHandler]{
        try {
            if (-not (Set-WVGreetingFrame $script:greetState $script:greetClock.Elapsed.TotalSeconds)) {
                [System.Windows.Media.CompositionTarget]::remove_Rendering($script:greetHandler)
            }
        } catch {
            # (something unexpected: the greeting goes, the video carries on)
            try { $script:greetState.Canvas.Visibility = 'Collapsed' } catch { }
            [System.Windows.Media.CompositionTarget]::remove_Rendering($script:greetHandler)
        }
    }
    [System.Windows.Media.CompositionTarget]::add_Rendering($script:greetHandler)
}

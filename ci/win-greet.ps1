param($src, $out)
foreach ($a in 'PresentationFramework', 'PresentationCore', 'WindowsBase') { [void][Reflection.Assembly]::Load("$a, Version=4.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35") }
. "$src\common.ps1"; . "$src\greeting.ps1"
$w = [System.Windows.Window]::new(); $w.WindowStyle = 'None'; $w.Width = 1280; $w.Height = 720; $w.Left = 0; $w.Top = 0
$grid = [System.Windows.Controls.Grid]::new(); $grid.Background = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(30, 45, 70)); $w.Content = $grid
$w.Show()
function Save-Shot($name) {
    $grid.UpdateLayout()
    $r = [System.Windows.Media.Imaging.RenderTargetBitmap]::new(1280, 720, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32); $r.Render($grid)
    $enc = [System.Windows.Media.Imaging.JpegBitmapEncoder]::new(); $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($r))
    $fs = [System.IO.File]::Create("$out\$name"); $enc.Save($fs); $fs.Close()
}
foreach ($id in 'tla', 'code', 'pixel', 'blocks', 'anime', 'liquid-glass', 'space', 'ocean', 'claymation', 'rainy') {
    try {
        $grid.Children.Clear()
        $g = New-WVGreeting $grid 'Good afternoon, Sevilen!' $WV.GreetingStyles[$id] 1280 720
        foreach ($t in 0.9, 1.6, 3.0) { [void](Set-WVGreetingFrame $g $t); Save-Shot "g-$id-$t.jpg" }
        "ok $id"
    } catch { "FAIL ${id}: $($_.Exception.Message) $($_.InvocationInfo.PositionMessage)" }
}
$grid.Children.Clear(); $g = New-WVGreeting $grid 'Good afternoon, Sevilen!' $WV.GreetingStyles['ocean'] 1280 720
$sw = [Diagnostics.Stopwatch]::StartNew(); for ($i = 0; $i -lt 60; $i++) { [void](Set-WVGreetingFrame $g (0.5 + $i / 60)) }; "ocean frame: $($sw.ElapsedMilliseconds / 60) ms"
"style pixel-dark: $(Get-WVGreetingStyle 'C:\x\Videos\pixel-dark.mp4')"

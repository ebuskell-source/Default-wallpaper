# 7.3.0: the scripts parse, the kiosk sign-in browser opens and is found by its profile, and closes.
$o = "$PWD\out\kiosk"; New-Item -ItemType Directory -Force $o | Out-Null
$r = @()
Start-Process ci\test-win.exe -ArgumentList '/S' -Wait
Start-Sleep 20
$d = (Get-ChildItem "$env:ProgramData" -Directory | Where-Object Name -like 'TLA*' | Select-Object -First 1).FullName
$r += "dir: $d"
foreach ($f in 'tour.ps1','settings.ps1','signin.ps1','sync-videos.ps1','common.ps1') {
  $e = $null; [void][System.Management.Automation.Language.Parser]::ParseFile("$d\$f", [ref]$null, [ref]$e); $r += "$f parse errors: $($e.Count) $($e | ForEach-Object { $_.Message + ' @' + $_.Extent.StartLineNumber })"
}
try {
  . "$d\common.ps1"; . "$d\tour.ps1" -ErrorAction SilentlyContinue 2>$null
} catch { $r += "load: $($_.Exception.Message)" }
try {
  $k = Start-WVLockBrowser 'https://ebuskell-source.github.io/'; Start-Sleep 8
  $p = Get-WVLockBrowserPids; $r += "kiosk=$k pids=$($p.Count)"
  Add-Type -AssemblyName System.Windows.Forms,System.Drawing
  $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds; $bmp = New-Object Drawing.Bitmap $b.Width,$b.Height
  [Drawing.Graphics]::FromImage($bmp).CopyFromScreen($b.Location,[Drawing.Point]::Empty,$b.Size); $bmp.Save("$o\kiosk.png")
  Stop-WVLockBrowser; Start-Sleep 3; $r += "after stop pids=$((Get-WVLockBrowserPids).Count)"
} catch { $r += "kiosk: $($_.Exception.Message)" }
try { $n = Get-WVNetNow; $r += "netnow=$n local=$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())" } catch { $r += "netnow: $($_.Exception.Message)" }
$r | Set-Content "$o\summary.txt"

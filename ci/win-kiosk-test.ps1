# 7.4.0: scripts parse; Set-WVBCTime moves a PC on Pacific Standard Time to BC time.
$o = "$PWD\out\kiosk"; New-Item -ItemType Directory -Force $o | Out-Null
$r = @(); $d = "$PWD\ci\winsrc"
foreach ($f in 'tour.ps1','settings.ps1','signin.ps1','sync-videos.ps1','common.ps1','install-video.ps1') {
  $e = $null; [void][System.Management.Automation.Language.Parser]::ParseFile("$d\$f", [ref]$null, [ref]$e); $r += "$f parse errors: $($e.Count)"
}
. "$d\common.ps1"
tzutil /s "Pacific Standard Time"
$r += "before: $((Get-TimeZone).Id) $(Get-Date -Format 'HH:mm zzz')"
Set-WVBCTime { param($t) $script:r += "log: $t" }
$r += "after: $([System.TimeZoneInfo]::Local.Id) $(Get-Date -Format 'HH:mm zzz') utc $([DateTime]::UtcNow.ToString('HH:mm'))"
$r | Set-Content "$o\summary.txt"

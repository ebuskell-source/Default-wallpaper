# 7.5.0: scripts parse; the Sign-in Lock task registers as Parallel for the Users group; only one lock per session.
$o = "$PWD\out\kiosk"; New-Item -ItemType Directory -Force $o | Out-Null
$r = @(); $d = "$PWD\ci\winsrc"
foreach ($f in 'tour.ps1','settings.ps1','signin.ps1','sync-videos.ps1','common.ps1','install-video.ps1') {
  $e = $null; [void][System.Management.Automation.Language.Parser]::ParseFile("$d\$f", [ref]$null, [ref]$e); $r += "$f parse errors: $($e.Count) $($e | % { $_.Message })"
}
$a = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -Command Start-Sleep 600 # settings.ps1 -Lock'
$p = New-ScheduledTaskPrincipal -GroupId 'S-1-5-32-545' -RunLevel Limited
$s = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances Parallel -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName 'TB test lock' -Action $a -Trigger (New-ScheduledTaskTrigger -AtLogOn) -Principal $p -Settings $s -Force | Out-Null
$r += "task MultipleInstances: $((Get-ScheduledTask 'TB test lock').Settings.MultipleInstances)"
# The mutex block, copied out of settings.ps1, run twice at once in this session: the second must leave.
$src = Get-Content "$d\settings.ps1" -Raw
$i = $src.IndexOf('$one = [System.Threading.Mutex]'); $j = $src.IndexOf('if (-not $mine) { return }', $i)
$block = $src.Substring($i, $j - $i)
$t = "$o\m.ps1"
Set-Content $t ($block + "`nif (-not `$mine) { 'second: left'; exit }`n'first: holds it'; Start-Sleep 8")
$first = Start-Process powershell -ArgumentList "-NoProfile -File `"$t`"" -RedirectStandardOutput "$o\a.txt" -PassThru
Start-Sleep 3
$r += "second run: $(& powershell -NoProfile -File $t)"
$first.WaitForExit(); $r += "first run: $(Get-Content "$o\a.txt")"
$r | Set-Content "$o\summary.txt"

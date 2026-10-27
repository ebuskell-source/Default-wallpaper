# 6.2.5 on Windows: signing in is required on TLA's PCs (TB_TEST_CORPORATE stands in for joined to Entra ID): the tour
# (no Skip) and the lock screen (never signed in, then run out), which goes away by itself once they're signed in.
$ErrorActionPreference = 'Continue'
$out = "$PWD\out\w625"; New-Item -ItemType Directory -Force $out, "$out\tour-corp", "$out\tour-own", "$out\lock" | Out-Null
$sum = "$out\summary.txt"
function Say($t) { "$t" | Out-File $sum -Append -Encoding utf8 }
$dir = Join-Path $env:ProgramData 'WelcomeVideo'
$p = Start-Process "$PWD\ci\test-setup.exe" -ArgumentList '/S' -PassThru -Wait
Say "installer exit $($p.ExitCode), version.txt $(Get-Content "$dir\version.txt")"
$task = Get-ScheduledTask -TaskName 'TLA BootPaper Sign-in Lock' -ErrorAction SilentlyContinue
Say "task: $($task.State) principal group $($task.Principal.GroupId) trigger $($task.Triggers[0].CimClass.CimClassName) delay $($task.Triggers[0].Delay) limit $($task.Settings.ExecutionTimeLimit) multiple $($task.Settings.MultipleInstances)"
Say "task args: $($task.Actions[0].Arguments)"
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like '*-Lock*' } | ForEach-Object { Say "running from install: $($_.ProcessId)"; Stop-Process -Id $_.ProcessId -Force }
python -m pip install --quiet cryptography *> "$out\pip.txt"
python ci\signin\prep.py "$dir\SignIn" *> "$out\prep.txt"
[System.IO.File]::WriteAllText("$dir\SignIn\.checked", '')
reg add HKLM\SOFTWARE\WelcomeVideo\Channels /v stable /d 6.2.5 /f | Out-Null
reg add HKLM\SOFTWARE\WelcomeVideo\Channels /v experimental /d 6.2.5 /f | Out-Null
. "$dir\common.ps1"; . "$dir\tour.ps1"
$dev = Get-WVSignInDevice; $me = Get-WVSignInUser
function Set-Token([int]$DaysAgo) {
    $n = (& python ci\signin\mktoken.py nonce $dev $me 'c2FsdHNhbHRzYWx0c2FsdA').Trim()
    $t = (& python ci\signin\mktoken.py token hub ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $DaysAgo * 86400) $n).Trim()
    [Microsoft.Win32.Registry]::SetValue('HKEY_CURRENT_USER\Software\WelcomeVideo\SignIn', 'Token', $t)
    [Microsoft.Win32.Registry]::SetValue('HKEY_CURRENT_USER\Software\WelcomeVideo\SignIn', 'Salt', 'c2FsdHNhbHRzYWx0c2FsdA')
}
function Check($what) { $s = Get-WVSignIn -Fresh; Say "$what`: release $($WV.Release) lockdown $(Test-WVReleased 'lockdown') corporate $(Test-WVCorporate) state $($s.state) reason $($s.reason) must $(Test-WVMustSignIn) online $(Test-WVOnline) needed $(Test-WVLockNeeded)" }
function Run($what, $args2, $env1) {
    $env:TB_TEST = $env1
    $a = Start-Process powershell -ArgumentList (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', "`"$dir\settings.ps1`"") + $args2) -PassThru -RedirectStandardError "$out\$what-err.txt"
    if (-not $a.WaitForExit(300000)) { $a.Kill(); Say "$what`: timed out" } else { Say "$what exit $($a.ExitCode)" }
    $env:TB_TEST = ''
}
Add-Type -Namespace T -Name W -MemberDefinition '[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern System.IntPtr FindWindow(string c, string t); [DllImport("user32.dll")] public static extern bool IsWindowVisible(System.IntPtr h);'
function LockTitle { $h = [T.W]::FindWindow($null, 'TLA BootPaper sign-in'); if ($h -ne [IntPtr]::Zero -and [T.W]::IsWindowVisible($h)) { 1 } else { 0 } }

Check 'own PC'
$env:TB_TEST_CORPORATE = '1'
Check 'TLA PC, never signed in'
Run 'tour-corp' @('-Tour') "$out\tour-corp"
Run 'lock-test' @('-Lock') "$out\lock"; Get-Content "$out\lock\lock.txt" -ErrorAction SilentlyContinue | ForEach-Object { Say "  $_" }

Say '== the real thing'
$lock = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-WindowStyle', 'Hidden', '-File', "`"$dir\settings.ps1`"", '-Lock' -PassThru -RedirectStandardError "$out\lock-err.txt"
$t0 = [DateTime]::UtcNow; while ((LockTitle) -eq 0 -and ([DateTime]::UtcNow - $t0).TotalSeconds -lt 60) { Start-Sleep 1 }
Say "lock window: $(LockTitle) after $([int]([DateTime]::UtcNow - $t0).TotalSeconds)s"
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
function Screen($name) { try { $b = [System.Windows.Forms.SystemInformation]::VirtualScreen; $bmp = [System.Drawing.Bitmap]::new($b.Width, $b.Height); $g = [System.Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen($b.Left, $b.Top, 0, 0, $bmp.Size); $bmp.Save("$out\$name.png"); $g.Dispose(); $bmp.Dispose() } catch { Say "screen: $($_.Exception.Message)" } }
Screen 'real-1-never'
$t0 = [DateTime]::UtcNow; Set-Token 1
while ((LockTitle) -gt 0 -and ([DateTime]::UtcNow - $t0).TotalSeconds -lt 30) { Start-Sleep 1 }
Say "signed in: lock window $(LockTitle) after $([int]([DateTime]::UtcNow - $t0).TotalSeconds)s; watcher still running: $(-not $lock.HasExited)"
Check 'signed in'
Set-Token 40; Check 'run out'
$t0 = [DateTime]::UtcNow; while ((LockTitle) -eq 0 -and ([DateTime]::UtcNow - $t0).TotalSeconds -lt 90) { Start-Sleep 1 }
Say "run out: lock window $(LockTitle) after $([int]([DateTime]::UtcNow - $t0).TotalSeconds)s"
Start-Sleep 2; Screen 'real-2-ran-out'
Set-Token 1; Start-Sleep 8; Say "signed in again: lock window $(LockTitle)"
Stop-Process -Id $lock.Id -Force -ErrorAction SilentlyContinue
$env:TB_TEST_CORPORATE = ''
Remove-ItemProperty 'HKCU:\Software\WelcomeVideo\SignIn' -Name Token -ErrorAction SilentlyContinue
Check 'own PC, never signed in'
Run 'tour-own' @('-Tour') "$out\tour-own"
Get-Content "$env:LOCALAPPDATA\TLA BootPaper\app-errors.log" -ErrorAction SilentlyContinue | Out-File $sum -Append
Say '== lock.log'; Get-Content "$env:LOCALAPPDATA\TLA BootPaper\lock.log" -ErrorAction SilentlyContinue | Out-File $sum -Append
Get-ChildItem "$out\*-err.txt" | ForEach-Object { if ($_.Length) { Say "$($_.Name): $(Get-Content $_.FullName -Raw)" } }
Say 'done'

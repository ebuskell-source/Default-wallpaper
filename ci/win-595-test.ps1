# 5.9.5: Check for updates on every PC: installs TLA BootPaper 5.9.5 with its installer, asks when it's up to date,
# then makes the installed copy look like 5.8.0 so the version GitHub has (windows/latest.json) is newer, and follows
# Check for updates in the app start to finish.
$ErrorActionPreference = 'Continue'
$out = "$PWD\out\w595"; New-Item -ItemType Directory -Force $out | Out-Null
$sum = "$out\summary.txt"
function Say($t) { "$t" | Out-File $sum -Append -Encoding utf8 }
$dir = Join-Path $env:ProgramData 'WelcomeVideo'
$p = Start-Process "$PWD\ci\test-setup.exe" -ArgumentList '/S' -PassThru -Wait
Say "installer exit $($p.ExitCode)"
Say "installed: $((Select-String -Path "$dir\common.ps1" -Pattern "Release\s*=\s*'([0-9.]+)'" | Select-Object -First 1).Matches[0].Groups[1].Value)"
Get-ScheduledTask -TaskName 'TLA Care', 'TLA BootPaper Updates' -ErrorAction SilentlyContinue | ForEach-Object { Say "task $($_.TaskName): $($_.State)" }
. "$dir\common.ps1"
. "$dir\care.ps1"
try { Say "GitHub has $((Get-WVLatestUpdate).Version)" } catch { Say "latest failed: $($_.Exception.Message)" }
function Ask {
    $at = Invoke-WVCareRequest 'update'
    if (-not $at) { Say 'request failed'; return }
    $r = $null
    for ($i = 0; $i -lt 30 -and -not $r; $i++) { Start-Sleep 3; $r = Get-WVCareResult 'update' $at }
    Say "answer after about $($i * 3)s: $(if ($r) { $r.Text } else { '(none)' })"
    Say "UpdateStatus: $(Get-WVValue 'HKEY_LOCAL_MACHINE\SOFTWARE\WelcomeVideo\Care' 'UpdateStatus')"
}
Say '== Check for updates when it''s up to date'
Ask
Say '== made to look like 5.8.0'
(Get-Content "$dir\common.ps1" -Raw) -replace "Release   = '5.9.5'", "Release   = '5.8.0'" | Set-Content "$dir\common.ps1" -NoNewline -Encoding utf8
Say "installed now: $(Get-WVInstalledRelease)"
Say '== the app: Check for updates, start to finish'
$env:TB_TEST = $out; $env:TB_TEST_UPDATE = '1'
$p = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$dir\settings.ps1`"" -PassThru -RedirectStandardError "$out\settings-err.txt"
if (-not $p.WaitForExit(780000)) { $p.Kill(); Say 'settings: timed out' } else { Say "settings exit $($p.ExitCode)" }
Get-Content "$out\update-texts.txt" -ErrorAction SilentlyContinue | ForEach-Object { Say "  $_" }
Say '== after'
Say "installed: $((Select-String -Path "$dir\common.ps1" -Pattern "Release\s*=\s*'([0-9.]+)'" | Select-Object -First 1).Matches[0].Groups[1].Value)"
Say "UpdateStatus: $(Get-WVValue 'HKEY_LOCAL_MACHINE\SOFTWARE\WelcomeVideo\Care' 'UpdateStatus')"
Get-Content "$dir\updates.log" -ErrorAction SilentlyContinue | Select-Object -Last 10 | ForEach-Object { Say "  updates.log: $_" }
Get-Content "$dir\care.log" -ErrorAction SilentlyContinue | Select-Object -Last 10 | ForEach-Object { Say "  care.log: $_" }
Get-ChildItem $dir -Filter *.log | ForEach-Object { Say "  log file: $($_.Name)" }
Say 'done'

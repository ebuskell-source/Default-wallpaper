# 5.8.0: Check for updates' GitHub check, the announcement copy for PCs Intune doesn't manage, and pictures of the app.
$ErrorActionPreference = 'Continue'
$src = "$PWD\ci\winsrc"; $out = "$PWD\out\w58"; New-Item -ItemType Directory -Force $out | Out-Null
$sum = "$out\summary.txt"
function Say($t) { "$t" | Out-File $sum -Append -Encoding utf8 }
. "$src\common.ps1"
try { $l = Get-WVLatestUpdate; Say "latest: $($l.Version) $($l.Url) newer than $($WV.Release)? $((ConvertTo-WVVersion $l.Version) -gt (ConvertTo-WVVersion $WV.Release))" } catch { Say "latest failed: $($_.Exception.Message)" }
Say "managed: $(Test-WVIntuneManaged)"
Update-WVAnnouncementCopy { param($t) Say "  log: $t" }
Say "announcement shown: '$(Get-WVAnnouncement)'"
reg add HKCU\Software\WelcomeVideo /v Channel /d experimental /f | Out-Null
$env:TB_TEST = $out
$p = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$src\settings.ps1`"" -PassThru -RedirectStandardError "$out\settings-err.txt"
if (-not $p.WaitForExit(150000)) { $p.Kill(); Say 'settings: timed out' } else { Say "settings exit $($p.ExitCode)" }
Get-Content "$env:LOCALAPPDATA\TLA BootPaper\app-errors.log" -ErrorAction SilentlyContinue | Out-File $sum -Append
$t = $null; $e = $null
foreach ($f in Get-ChildItem "$src\*.ps1") { [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$t, [ref]$e); if ($e.Count) { Say "$($f.Name) parse errors: $($e.Count)" } }
Say 'done'

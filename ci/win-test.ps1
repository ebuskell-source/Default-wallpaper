$src = "$PWD\ci\winsrc"; $out = "$PWD\out\win"; New-Item -ItemType Directory -Force $out | Out-Null
reg add HKCU\Software\WelcomeVideo /v Channel /d experimental /f | Out-Null
reg add HKCU\Software\WelcomeVideo /v PreferredName /d Sevilen /f | Out-Null
$env:TB_TEST = $out
$p = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$src\settings.ps1`"" -PassThru -RedirectStandardError "$out\settings-err.txt"
if (-not $p.WaitForExit(150000)) { $p.Kill(); 'settings: timed out' | Out-File "$out\summary.txt" -Append } else { "settings exit $($p.ExitCode)" | Out-File "$out\summary.txt" -Append }
Get-Content "$env:LOCALAPPDATA\TLA BootPaper\app-errors.log" -ErrorAction SilentlyContinue | Out-File "$out\summary.txt" -Append
$env:TB_TEST = ''
$p = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PWD\ci\win-greet.ps1`"", "`"$src`"", "`"$out`"" -PassThru -RedirectStandardOutput "$out\greet.txt" -RedirectStandardError "$out\greet-err.txt"
if (-not $p.WaitForExit(150000)) { $p.Kill(); 'greet: timed out' | Out-File "$out\summary.txt" -Append }

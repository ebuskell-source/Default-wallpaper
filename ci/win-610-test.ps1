# 6.1.0 on Windows: TLA's sections and captions (the app and the tour), then Check for updates with its progress bar,
# start to finish: the installed copy is made to look like 6.0.0, so the version GitHub has is newer and gets installed.
$ErrorActionPreference = 'Continue'
$out = "$PWD\out\w610"; New-Item -ItemType Directory -Force $out, "$out\app", "$out\tour", "$out\upd" | Out-Null
$sum = "$out\summary.txt"
function Say($t) { "$t" | Out-File $sum -Append -Encoding utf8 }
$dir = Join-Path $env:ProgramData 'WelcomeVideo'
$p = Start-Process "$PWD\ci\test-setup.exe" -ArgumentList '/S' -PassThru -Wait
Say "installer exit $($p.ExitCode), version.txt $(Get-Content "$dir\version.txt")"
reg add HKCU\Software\WelcomeVideo /v Channel /d experimental /f | Out-Null
. "$dir\common.ps1"
Say "release $($WV.Release); experimental shown: $(Test-WVReleased 'experimental'); Beta Testers picture: $(Test-Path "$dir\Backgrounds\experimental-r2.jpg")"
function Run($what, $args2, $env1) {
    $env:TB_TEST = $env1
    $a = Start-Process powershell -ArgumentList (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$dir\settings.ps1`"") + $args2) -PassThru -RedirectStandardError "$out\$what-err.txt"
    if (-not $a.WaitForExit(600000)) { $a.Kill(); Say "$what`: timed out" } else { Say "$what exit $($a.ExitCode)" }
}
Run 'app' @() "$out\app"
Run 'tour' @('-Tour') "$out\tour"
Say '== Check for updates (made to look like 6.0.0)'
(Get-Content "$dir\common.ps1" -Raw) -replace "Release   = '6.1.0'", "Release   = '6.0.0'" | Set-Content "$dir\common.ps1" -NoNewline -Encoding utf8
$env:TB_TEST_UPDATE = '1'
Run 'update' @() "$out\upd"
Get-Content "$out\upd\update-texts.txt" -ErrorAction SilentlyContinue | ForEach-Object { Say "  $_" }
Get-Content "$dir\updates.log" -ErrorAction SilentlyContinue | Select-Object -Last 6 | ForEach-Object { Say "  log: $_" }
Get-Content "$env:LOCALAPPDATA\TLA BootPaper\app-errors.log" -ErrorAction SilentlyContinue | Out-File $sum -Append
Get-ChildItem "$out\*-err.txt" | ForEach-Object { if ($_.Length) { Say "$($_.Name): $(Get-Content $_.FullName -Raw)" } }
Say 'done'

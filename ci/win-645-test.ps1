# 6.4.5 on Windows: the new backgrounds (8-Bit's new pictures, Vancouver, Winter), their videos, the app and the tour.
$ErrorActionPreference = 'Continue'
$out = "$PWD\out\w645"; New-Item -ItemType Directory -Force $out, "$out\app", "$out\tour" | Out-Null
$sum = "$out\summary.txt"
function Say($t) { "$t" | Out-File $sum -Append -Encoding utf8 }
$dir = Join-Path $env:ProgramData 'WelcomeVideo'
$p = Start-Process "$PWD\ci\test-setup.exe" -ArgumentList '/S' -PassThru -Wait
Say "installer exit $($p.ExitCode), version.txt $(Get-Content "$dir\version.txt")"
reg add HKLM\SOFTWARE\WelcomeVideo\Channels /v stable /d 6.4.5 /f | Out-Null
reg add HKLM\SOFTWARE\WelcomeVideo\Channels /v experimental /d 6.4.5 /f | Out-Null
. "$dir\common.ps1"
foreach ($d in '2026-12-25', '2027-01-07', '2027-02-14', '2027-03-19', '2027-03-20') { Say "$d season: $(Get-WVSeason ([DateTime]::Parse($d)))" }
foreach ($b in 'pixel', 'vancouver', 'winter') { Say "$b`: $(Get-WVBackgroundPath $b '') | $(Get-WVBackgroundPath $b 'dark') exists $(Test-Path (Get-WVBackgroundPath $b 'dark'))" }
Say "Vancouver released $(Test-WVReleased 'vancouver'), category $(Get-WVCategory 'vancouver')"
Get-ChildItem "$dir\Backgrounds", "$dir\Wide" | Where-Object { $_.Name -match 'pixel|vancouver|winter' } | ForEach-Object { Say "  $($_.Directory.Name)\$($_.Name)" }
Say '== videos'; & powershell -NoProfile -ExecutionPolicy Bypass -File "$dir\sync-videos.ps1" *> "$out\sync.txt"
Get-ChildItem "$dir\Videos" | Where-Object { $_.Name -match 'pixel|winter' } | ForEach-Object { Say "  $($_.Name) $((Get-FileHash $_.FullName).Hash.Substring(0,12))" }
reg add HKCU\Software\WelcomeVideo /v Background /d vancouver /f | Out-Null
function Run($what, $args2, $env1) {
    $env:TB_TEST = $env1
    $a = Start-Process powershell -ArgumentList (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', "`"$dir\settings.ps1`"") + $args2) -PassThru -RedirectStandardError "$out\$what-err.txt"
    if (-not $a.WaitForExit(300000)) { $a.Kill(); Say "$what`: timed out" } else { Say "$what exit $($a.ExitCode)" }
    $env:TB_TEST = ''
}
Run 'app' @() "$out\app"
Run 'tour' @('-Tour') "$out\tour"
Get-Content "$env:LOCALAPPDATA\TLA BootPaper\app-errors.log" -ErrorAction SilentlyContinue | Out-File $sum -Append
Get-ChildItem "$out\*-err.txt" | ForEach-Object { if ($_.Length) { Say "$($_.Name): $(Get-Content $_.FullName -Raw)" } }
Say 'done'

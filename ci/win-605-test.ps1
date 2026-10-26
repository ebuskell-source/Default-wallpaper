# 6.0.5 on Windows: installs it, then pictures of the app's themed sections and the tour's background page (one
# section at a time), and checks the two new videos.
$ErrorActionPreference = 'Continue'
$out = "$PWD\out\w605"; New-Item -ItemType Directory -Force $out, "$out\app", "$out\tour" | Out-Null
$sum = "$out\summary.txt"
function Say($t) { "$t" | Out-File $sum -Append -Encoding utf8 }
$dir = Join-Path $env:ProgramData 'WelcomeVideo'
$p = Start-Process "$PWD\ci\test-setup.exe" -ArgumentList '/S' -PassThru -Wait
Say "installer exit $($p.ExitCode)"
. "$dir\common.ps1"
Say "release $($WV.Release), channels $($WV.ChannelReleases['stable']) / $($WV.ChannelReleases['experimental']), version.txt $(Get-Content "$dir\version.txt")"
Say "names: $(@($WV.Backgrounds.Values) -join ', ')"
Say "sections: $(@($WV.Categories.Keys | ForEach-Object { $cid = $_; "$($WV.Categories[$cid]) = " + (@($WV.Backgrounds.Keys | Where-Object { (Get-WVCategory $_) -eq $cid }) -join '/') }) -join '; ')"
reg add HKCU\Software\WelcomeVideo /v Channel /d experimental /f | Out-Null
reg add HKCU\Software\WelcomeVideo /v PreferredName /d Sevilen /f | Out-Null
# The videos: Code's light one and the new Anime dark one (downloaded at install; once more here in case)
$missing = Sync-WVVideos { param($t) Say "  sync: $t" }
Say "missing after sync: $($missing -join ', ')"
foreach ($v in 'code-light', 'anime-dark', 'anime', 'code') {
    $f = "$dir\Videos\$v.mp4"
    Say "$v`: $(if (Test-Path $f) { Get-WVSha256 $f } else { 'missing' }) (want $($WV.VideoHashes[$v]))"
}
foreach ($m in 'light', 'dark') { Say "code video in $m mode (when 6.0.5 is out on their channel): $($WV.Variants['code']) -> $(if ($WV.Variants['code'] -eq $m) { "code-$m.mp4" } else { 'code.mp4' })" }
# The app's sections, and the tour
$env:TB_TEST = "$out\app"
$a = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$dir\settings.ps1`"" -PassThru -RedirectStandardError "$out\app-err.txt"
if (-not $a.WaitForExit(240000)) { $a.Kill(); Say 'app: timed out' } else { Say "app exit $($a.ExitCode)" }
$env:TB_TEST = "$out\tour"
$t = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$dir\settings.ps1`"", '-Tour' -PassThru -RedirectStandardError "$out\tour-err.txt"
if (-not $t.WaitForExit(180000)) { $t.Kill(); Say 'tour: timed out' } else { Say "tour exit $($t.ExitCode)" }
Get-Content "$env:LOCALAPPDATA\TLA BootPaper\app-errors.log" -ErrorAction SilentlyContinue | Out-File $sum -Append
Get-ChildItem $out -Recurse -Filter *.png | ForEach-Object { Say "  $($_.Directory.Name)\$($_.Name)" }
Say 'done'

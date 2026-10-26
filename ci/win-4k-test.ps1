# 5.9.5: Microsoft and Liquid Glass in 4K: the files the installer puts in place, Intune's detection script, and
# the desktop picture in light and dark.
$ErrorActionPreference = 'Continue'
$out = "$PWD\out\w4k"; New-Item -ItemType Directory -Force $out | Out-Null
$sum = "$out\summary.txt"
function Say($t) { "$t" | Out-File $sum -Append -Encoding utf8 }
$dir = Join-Path $env:ProgramData 'WelcomeVideo'
$p = Start-Process "$PWD\ci\test-setup.exe" -ArgumentList '/S' -PassThru -Wait
Say "installer exit $($p.ExitCode)"
Add-Type -AssemblyName System.Drawing
Get-ChildItem "$dir\Backgrounds" -Filter '*.jpg' | Where-Object { $_.Name -match 'microsoft|liquid' } | ForEach-Object {
    $i = [System.Drawing.Image]::FromFile($_.FullName); Say "$($_.Name) $($i.Width)x$($i.Height) $([int]($_.Length / 1KB)) KB"; $i.Dispose()
}
Get-ChildItem "$dir\Wide" | Where-Object { $_.Name -match 'microsoft|liquid' } | ForEach-Object { Say "Wide\$($_.Name) $([int]($_.Length / 1KB)) KB" }
Say "detection v42: '$(& "$PWD\ci\detect-video-v42.ps1")'"
Say "version.txt: $(Get-Content "$dir\version.txt" -Raw)"
. "$dir\common.ps1"
foreach ($b in 'microsoft', 'liquid-glass') {
    foreach ($look in 'Light', 'Dark') {
        reg add HKCU\Software\WelcomeVideo /v Background /d $b /f | Out-Null
        reg add HKCU\Software\WelcomeVideo /v LightDark /d $look /f | Out-Null
        & powershell -NoProfile -ExecutionPolicy Bypass -File "$dir\apply-background.ps1" -FromApp 2>&1 | Out-Null
        Start-Sleep 3
        Say "$b $look`: shown $(Get-WVShownPath $b) | wallpaper $((Get-ItemProperty 'HKCU:\Control Panel\Desktop').Wallpaper)"
    }
}
Get-Content "$dir\backgrounds.log" -ErrorAction SilentlyContinue | Select-Object -Last 8 | ForEach-Object { Say "  log: $_" }
Say 'done'

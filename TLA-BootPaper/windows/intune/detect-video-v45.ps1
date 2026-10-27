# detect-video-v45.ps1
# Intune detection script: reports "Installed" when version 45 or newer is in place. (Newer counts too, so Intune
# never puts this version back over a newer one, for example on a computer on the Experimental channel.)
# When you change the video or settings, raise $Version here AND in install-video.ps1.

$Version    = '45'
$InstallDir = Join-Path $env:ProgramData 'WelcomeVideo'
$task       = Get-ScheduledTask -TaskName 'Welcome Video' -ErrorAction SilentlyContinue
$videoTask  = Get-ScheduledTask -TaskName 'TLA BootPaper Videos' -ErrorAction SilentlyContinue
$applyTask  = Get-ScheduledTask -TaskName 'TLA BootPaper Apply' -ErrorAction SilentlyContinue
$careTask   = Get-ScheduledTask -TaskName 'TLA Care' -ErrorAction SilentlyContinue
$themeTask  = Get-ScheduledTask -TaskName 'TLA BootPaper Theme' -ErrorAction SilentlyContinue
$updateTask = Get-ScheduledTask -TaskName 'TLA BootPaper Updates' -ErrorAction SilentlyContinue   # (5.4)
$installed  = Get-Content -LiteralPath (Join-Path $InstallDir 'version.txt') -Raw -ErrorAction SilentlyContinue
if ($installed) { $installed = $installed.Trim() }

$files = 'play-video.ps1', 'settings.ps1', 'common.ps1', 'whatsnew.ps1', 'report.ps1', 'apply-background.ps1', 'lock-backgrounds.ps1',
         'sync-videos.ps1', 'release-notes.md', 'care.ps1', 'care-system.ps1', 'session.ps1', 'tour.ps1', 'theme-check.ps1', 'update.ps1', 'greeting.ps1', 'signin.ps1',
         'Backgrounds\microsoft-r6.jpg', 'Backgrounds\microsoft-dark-r6.jpg', 'Backgrounds\thumbs\microsoft.jpg' | ForEach-Object { Join-Path $InstallDir $_ }
$shortcut = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\TLA BootPaper.lnk'
$report   = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Report a problem to TLA.lnk'
$care     = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\TLA Care.lnk'

if ($task -and $videoTask -and $applyTask -and $careTask -and $themeTask -and $updateTask -and
    $installed -match '^\d{1,6}$' -and [int]$installed -ge [int]$Version -and
    -not ($files | Where-Object { -not (Test-Path -LiteralPath $_) }) -and
    (Test-Path -LiteralPath $shortcut) -and (Test-Path -LiteralPath $report) -and (Test-Path -LiteralPath $care)) {
    Write-Output 'Installed'
}
exit 0

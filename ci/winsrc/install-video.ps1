# install-video.ps1
# Runs as SYSTEM from Intune. Downloads the intro videos and copies the player, settings app, release log and preset desktop
# backgrounds (desktop and lock screen) to C:\ProgramData\WelcomeVideo, saves the organization defaults, adds "TLA BootPaper" to
# the Start menu, and creates a scheduled task that starts the player whenever anyone signs in.
# Needs no restart: everything takes effect at each person's next sign-in.

# ---- Organization defaults (change before packaging) -------------------------------------------
# People can change these for themselves in the TLA BootPaper app, unless $UsersCanChange = 0.
$Defaults = [ordered]@{
    Enabled   = 1              # 1 = play the video, 0 = don't
    PlayWhen  = 'EverySignIn'  # EverySignIn = every sign-in
                               # OncePerDay  = first sign-in each day
                               # AfterUpdate = first sign-in after Windows installs an update
                               # FirstTime   = once per person, and again when the video changes
    Sound     = 1              # 1 = with sound, 0 = muted
    AllowSkip = 0              # 1 = Esc or a click closes it early, 0 = it can't be closed
    Background = 'microsoft'   # tla | frutiger-aero | liquid-glass | microsoft | rainy | code | bricks | blocks | space | claymation | solarpunk | anime | ocean | beach | penguins
                               # | grumpy-cat | bonjovi | raccoon (5.9.0)
                               # Everyone gets this on their desktop and lock screen at their next sign-in
                               # unless they pick another preset.
    Video     = 'match'        # match (the video that goes with their background) | tla | frutiger-aero
                               # | liquid-glass | microsoft | rainy | code | bricks | blocks | space | claymation | solarpunk | anime
                               # | frutiger-aero-v2 (the newer Frutiger Aero video) | liquid-glass-original | microsoft-original
                               # (the first versions of those two)
    WallpaperFit = 'Fill'      # Fill (fill the screen) | Fit (show the whole picture) | Span (across all screens)
    Channel   = 'stable'       # stable | experimental: when new backgrounds, videos and features reach people (4.3)
    LightDark = 'Auto'         # Auto (follow Windows' light or dark mode) | Light | Dark (5.0)
    Screensaver = 1            # 1 = the TLA screensaver for anyone without a screen saver of their own (5.0)
    CallBackgrounds = 1        # 1 = the TLA backgrounds in Microsoft Teams (5.0)
    CareReminders = 1          # 1 = TLA Care reminders, like when it's time to restart (5.0)
}
$UsersCanChange = 1            # 0 = people can see these settings in the app but not change them
$OwnPictures    = ''           # (5.9.0) their own pictures in the app: '' = on PCs that belong to the person (not joined to
                               # TLA's Microsoft Entra ID or a domain), 1 = on every PC, 0 = on none
# -------------------------------------------------------------------------------------------------

$ErrorActionPreference = 'Stop'
$InstallDir = Join-Path $env:ProgramData 'WelcomeVideo'
$TaskName   = 'Welcome Video'
$Version    = '41'   # raise this (and the one in the detection script) whenever you change the video or settings
$Shortcut   = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\TLA BootPaper.lnk'
$ReportShortcut = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Report a problem to TLA.lnk'   # (4.3)
$CareShortcut   = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\TLA Care.lnk'                  # (5.0)
# (5.0) A first install, rather than an update: decides whether "Prepare for initial unboxing" is offered.
$wasInstalled = Test-Path -LiteralPath (Join-Path $InstallDir 'version.txt')

New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null

# The scripts here run as every person who signs in, so only admins may change them.
# (SIDs: SYSTEM, Administrators, Users - these work on any Windows language.)
icacls.exe $InstallDir /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-32-545:(OI)(CI)RX' | Out-Null

# Copies a file only when it changed, retrying if it's in use (for example the app or the video is
# open while Intune updates). Only a required file that still can't be copied stops the install.
function Copy-WVFile([string]$Source, [string]$Destination, [switch]$Optional) {
    if ((Test-Path -LiteralPath $Destination) -and
        (Get-FileHash -LiteralPath $Source).Hash -eq (Get-FileHash -LiteralPath $Destination).Hash) { return }
    for ($try = 1; $try -le 6; $try++) {
        try { Copy-Item -LiteralPath $Source -Destination $Destination -Force -ErrorAction Stop; return }
        catch { if ($try -lt 6) { Start-Sleep -Seconds 5 } elseif (-not $Optional) { throw } }
    }
}

# Backgrounds first: stored flat in the package (bg-<id>.jpg, thumb-<id>.jpg).
$bgDir    = Join-Path $InstallDir 'Backgrounds'
$thumbDir = Join-Path $bgDir 'thumbs'
[void][System.IO.Directory]::CreateDirectory($thumbDir)
# (4.0: and the seasonal themes Fall, Christmas and Easter, and the "Surprise me" tile's picture.)
foreach ($id in 'microsoft', 'liquid-glass', 'penguins', 'code', 'frutiger-aero', 'solarpunk', 'rainy', 'space', 'ocean', 'beach', 'claymation', 'blocks', 'bricks', 'pixel', 'anime', 'sky-city', 'tla',
                'grumpy-cat', 'bonjovi', 'raccoon',   # (5.9.0: Animals)
                'fall', 'christmas', 'easter') {
    $r = if ($id -eq 'anime') { 'r5' } else { 'r2' }
    Copy-WVFile (Join-Path $PSScriptRoot "bg-$id.jpg")    (Join-Path $bgDir "$id-$r.jpg")
    Remove-Item -LiteralPath (Join-Path $bgDir "$id.jpg") -Force -ErrorAction SilentlyContinue   # before 3.2.3
    Copy-WVFile (Join-Path $PSScriptRoot "thumb-$id.jpg") (Join-Path $thumbDir "$id.jpg")
}
Copy-WVFile (Join-Path $PSScriptRoot 'thumb-surprise.jpg') (Join-Path $thumbDir 'surprise.jpg')
# (5.0) Light and dark: each background's picture for the other mode (bg-<id>-<mode>.jpg).
foreach ($file in Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'bg-*-*.jpg') {
    if ($file.Name -notmatch '^bg-(.+)-(light|dark)\.jpg$') { continue }
    Copy-WVFile $file.FullName (Join-Path $bgDir "$($Matches[1])-$($Matches[2]).jpg")
    Copy-WVFile (Join-Path $PSScriptRoot "thumb-$($Matches[1])-$($Matches[2]).jpg") (Join-Path $thumbDir "$($Matches[1])-$($Matches[2]).jpg")
}

foreach ($old in 'anime-r2.jpg', 'anime-r4.jpg') { Remove-Item -LiteralPath (Join-Path $bgDir $old) -Force -ErrorAction SilentlyContinue }   # before 3.3.3
# No longer used: the single welcome.mp4 (before 3.1).
Remove-Item -LiteralPath (Join-Path $InstallDir 'welcome.mp4') -Force -ErrorAction SilentlyContinue

foreach ($file in 'play-video.ps1', 'settings.ps1', 'common.ps1', 'whatsnew.ps1', 'report.ps1', 'apply-background.ps1',
                  'lock-backgrounds.ps1', 'sync-videos.ps1', 'release-notes.md',
                  'care.ps1', 'care-system.ps1', 'session.ps1', 'tour.ps1', 'theme-check.ps1', 'oem-logo.bmp',
                  'update.ps1', 'uninstall-video.ps1',     # (5.4: updating itself outside Intune, and uninstalling)
                  'greeting.ps1',                           # (5.5.5: the greeting in each theme's style)
                  'signin.ps1') {                           # (5.7.0: signing in with the Hub account)
    Copy-WVFile (Join-Path $PSScriptRoot $file) (Join-Path $InstallDir $file)
}
# The icon may be open at that moment; the old copy keeps working until the next update.
$target = Join-Path $InstallDir 'welcome-video.ico'
Copy-WVFile (Join-Path $PSScriptRoot 'welcome-video.ico') $target -Optional:(Test-Path -LiteralPath $target)

# ---- 16:9 copies of the backgrounds (5.0): the TLA screensaver and call backgrounds ---------------------------
# Wide\<name>.jpg (1920x1080, the middle of each picture) and WideThumbs\<name>.jpg (280x158, for Teams). Made here,
# not shipped, to keep the package small; only redone when the picture changes.
function New-WVWidePicture([string]$Source, [string]$Target, [int]$Width, [int]$Height) {
    Add-Type -AssemblyName System.Drawing
    $img = [System.Drawing.Image]::FromFile($Source)
    try {
        $sw = $img.Width; $sh = $img.Height
        if ($sw / $sh -gt 16 / 9) { $ch = $sh; $cw = [int]($sh * 16 / 9) } else { $cw = $sw; $ch = [int]($sw * 9 / 16) }
        $cx = [int](($sw - $cw) / 2); $cy = [int](($sh - $ch) / 2)
        $bmp = [System.Drawing.Bitmap]::new($Width, $Height)
        try {
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            try {
                $g.InterpolationMode  = 'HighQualityBicubic'
                $g.PixelOffsetMode    = 'HighQuality'
                $g.CompositingQuality = 'HighQuality'
                $attrs = [System.Drawing.Imaging.ImageAttributes]::new()
                $attrs.SetWrapMode('TileFlipXY')   # (no faint line along the edges)
                $g.DrawImage($img, [System.Drawing.Rectangle]::new(0, 0, $Width, $Height), $cx, $cy, $cw, $ch,
                             [System.Drawing.GraphicsUnit]::Pixel, $attrs)
                $attrs.Dispose()
            } finally { $g.Dispose() }
            $jpeg = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
            $params = [System.Drawing.Imaging.EncoderParameters]::new(1)
            $params.Param[0] = [System.Drawing.Imaging.EncoderParameter]::new([System.Drawing.Imaging.Encoder]::Quality, [long]88)
            $bmp.Save("$Target.tmp", $jpeg, $params)
        } finally { $bmp.Dispose() }
    } finally { $img.Dispose() }
    Move-Item -LiteralPath "$Target.tmp" -Destination $Target -Force
}
$wideDir  = Join-Path $InstallDir 'Wide'
$wideThumbs = Join-Path $InstallDir 'WideThumbs'
[void][System.IO.Directory]::CreateDirectory($wideDir)
[void][System.IO.Directory]::CreateDirectory($wideThumbs)
$wideNames = @{}
foreach ($id in 'microsoft', 'liquid-glass', 'penguins', 'code', 'frutiger-aero', 'solarpunk', 'rainy', 'space', 'ocean', 'beach', 'claymation', 'blocks', 'bricks', 'pixel', 'anime', 'sky-city', 'tla',
                'grumpy-cat', 'bonjovi', 'raccoon') {
    $r = if ($id -eq 'anime') { 'r5' } else { 'r2' }
    $sources = [ordered]@{ $id = Join-Path $bgDir "$id-$r.jpg" }
    foreach ($mode in 'light', 'dark') {
        $v = Join-Path $bgDir "$id-$mode.jpg"
        if (Test-Path -LiteralPath $v) { $sources["$id-$mode"] = $v }
    }
    foreach ($name in $sources.Keys) {
        $src = $sources[$name]
        if (-not (Test-Path -LiteralPath $src)) { continue }
        $wideNames["$name.jpg"] = $true
        $stamp = (Get-Item -LiteralPath $src).LastWriteTimeUtc
        foreach ($size in 'wide', 'thumb') {
            $target = if ($size -eq 'wide') { Join-Path $wideDir "$name.jpg" } else { Join-Path $wideThumbs "$name.jpg" }
            if ((Test-Path -LiteralPath $target) -and (Get-Item -LiteralPath $target).LastWriteTimeUtc -ge $stamp) { continue }
            try {
                if ($size -eq 'wide') { New-WVWidePicture $src $target 1920 1080 } else { New-WVWidePicture $src $target 280 158 }
            } catch { Write-Output "Couldn't make $($target): $($_.Exception.Message)" }
        }
    }
}
foreach ($dir in $wideDir, $wideThumbs) {   # (pictures no longer offered)
    foreach ($f in Get-ChildItem -LiteralPath $dir -File) { if (-not $wideNames.Contains($f.Name)) { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue } }
}

# Intro videos: downloaded (full quality, checked against their SHA-256) rather than shipped in the package.
# If that isn't possible right now (offline, site unreachable), the install still succeeds: the PC keeps any
# videos it already has, and the "TLA BootPaper Videos" task (below) keeps trying every 30 minutes.
. (Join-Path $InstallDir 'common.ps1')
foreach ($line in (Sync-WVVideos { param($t) Write-Output $t })) { }

# Organization defaults, read by the player and the app.
$deviceKey = 'HKEY_LOCAL_MACHINE\SOFTWARE\WelcomeVideo'
foreach ($name in $Defaults.Keys) {
    [Microsoft.Win32.Registry]::SetValue($deviceKey, $name, $Defaults[$name])
}
[Microsoft.Win32.Registry]::SetValue($deviceKey, 'UsersCanChange', [int]$UsersCanChange)
if ("$OwnPictures" -eq '0' -or "$OwnPictures" -eq '1') { [Microsoft.Win32.Registry]::SetValue($deviceKey, 'OwnPictures', "$OwnPictures") }
else { try { $k = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SOFTWARE\WelcomeVideo', $true); if ($k) { $k.DeleteValue('OwnPictures', $false); $k.Close() } } catch { } }

# Start menu entry for the settings app (called "Welcome Video" before 3.1).
Remove-Item -LiteralPath (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Welcome Video.lnk') -Force -ErrorAction SilentlyContinue
$shell = New-Object -ComObject WScript.Shell
$link  = $shell.CreateShortcut($Shortcut)
$link.TargetPath       = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$link.Arguments        = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$(Join-Path $InstallDir 'settings.ps1')`""
$link.WorkingDirectory = $InstallDir
$link.IconLocation     = "$(Join-Path $InstallDir 'welcome-video.ico'),0"
$link.Description      = 'Choose your TLA intro video and your desktop and lock screen background'
$link.Save()
# 4.3: "Report a problem to TLA": the report form on its own.
$link  = $shell.CreateShortcut($ReportShortcut)
$link.TargetPath       = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$link.Arguments        = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$(Join-Path $InstallDir 'settings.ps1')`" -Report"
$link.WorkingDirectory = $InstallDir
$link.IconLocation     = "$(Join-Path $InstallDir 'welcome-video.ico'),0"
$link.Description      = 'Tell the TLA helpdesk about a problem with this computer'
$link.Save()
# 5.0: "TLA Care": checks and one-click fixes.
$link  = $shell.CreateShortcut($CareShortcut)
$link.TargetPath       = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$link.Arguments        = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$(Join-Path $InstallDir 'settings.ps1')`" -Care"
$link.WorkingDirectory = $InstallDir
$link.IconLocation     = "$(Join-Path $InstallDir 'welcome-video.ico'),0"
$link.Description      = 'Check this computer and fix common problems'
$link.Save()
# The release channels (4.3), read now so the app knows them straight away.
foreach ($line in (Update-WVChannels { param($t) Write-Output $t })) { }

$playerScript = Join-Path $InstallDir 'play-video.ps1'

$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$playerScript`""

# Any user signing in. S-1-5-32-545 is the built-in Users group, so it runs as whoever signed in.
$trigger   = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -GroupId 'S-1-5-32-545' -RunLevel Limited

# -Priority 4 = normal priority, like an app the user opens. Without it, scheduled tasks run at
# priority 7: below-normal CPU AND low disk priority, which slows the player down at sign-in,
# when everything else is loading at the same time.
# 5.7.5: a day, not 30 minutes: when Windows signs in by itself and locks, the player waits for the person to unlock.
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Days 1) -MultipleInstances IgnoreNew -Priority 4

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
    -Principal $principal -Settings $settings -Force | Out-Null

# ---- Keeping the backgrounds to the presets ---------------------------------------------------------
# A second task, as SYSTEM (see lock-backgrounds.ps1), keeps each person's desktop and lock screen to their
# own preset and stops anyone choosing other pictures in Settings: at startup, at every sign-in, every
# 30 minutes, and when someone picks a background in the app. Anyone signed in may start it
# (Authenticated Users: read + run); it only ever uses the preset files.
$lockTask   = 'TLA BootPaper Backgrounds'
$lockAction = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $InstallDir 'lock-backgrounds.ps1')`""
$lockTriggers  = @((New-ScheduledTaskTrigger -AtStartup), (New-ScheduledTaskTrigger -AtLogOn),
                   (New-ScheduledTaskTrigger -Once -At ([DateTime]::Now.AddMinutes(30)) -RepetitionInterval (New-TimeSpan -Minutes 30)))
$lockPrincipal = New-ScheduledTaskPrincipal -UserId 'S-1-5-18' -LogonType ServiceAccount -RunLevel Highest
$lockSettings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -MultipleInstances Queue
Register-ScheduledTask -TaskName $lockTask -Action $lockAction -Trigger $lockTriggers `
    -Principal $lockPrincipal -Settings $lockSettings -Force | Out-Null
$service = New-Object -ComObject 'Schedule.Service'
$service.Connect()
$service.GetFolder('\').GetTask($lockTask).SetSecurityDescriptor('D:(A;;FA;;;SY)(A;;FA;;;BA)(A;;GRGX;;;AU)', 0)
# Set them now: the signed-in person's choice, or the organization default before anyone has signed in.
Start-ScheduledTask -TaskName $lockTask -ErrorAction SilentlyContinue

# ---- Downloading the intro videos (4.0.5: its own task) ------------------------------------------------
# As SYSTEM, at startup and every 30 minutes: any video that's missing or out of date (sync-videos.ps1). Kept
# apart from the backgrounds task, so a long download never holds up a background someone has just picked.
$videoTask    = 'TLA BootPaper Videos'
$videoAction  = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $InstallDir 'sync-videos.ps1')`""
$videoTriggers = @((New-ScheduledTaskTrigger -AtStartup),
                   (New-ScheduledTaskTrigger -Once -At ([DateTime]::Now.AddMinutes(30)) -RepetitionInterval (New-TimeSpan -Minutes 30)))
$videoTriggers[0].Delay = 'PT2M'               # after startup has settled
$videoSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Hours 2) -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName $videoTask -Action $videoAction -Trigger $videoTriggers `
    -Principal $lockPrincipal -Settings $videoSettings -Force | Out-Null
# (5.0: anyone may start it too, from TLA Care's "Download now")
$service.GetFolder('\').GetTask($videoTask).SetSecurityDescriptor('D:(A;;FA;;;SY)(A;;FA;;;BA)(A;;GRGX;;;AU)', 0)

# ---- Updating someone's lock screen in their session (4.1) ---------------------------------------------
# No schedule of its own: the backgrounds task starts it, in the session of the person signed in, when their
# own lock screen or desktop is out of date (a new announcement, a new season, today's "Surprise me" pick).
# It runs as them (the Users group, like the welcome video), since only they can set their own lock screen.
$applyTask      = 'TLA BootPaper Apply'
$applyAction    = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$(Join-Path $InstallDir 'apply-background.ps1')`""
$applyPrincipal = New-ScheduledTaskPrincipal -GroupId 'S-1-5-32-545' -RunLevel Limited
$applySettings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -MultipleInstances IgnoreNew -Priority 4
Register-ScheduledTask -TaskName $applyTask -Action $applyAction -Principal $applyPrincipal `
    -Settings $applySettings -Force | Out-Null

# ---- Light and dark (5.0): following each person's mode -------------------------------------------------
# As SYSTEM, every 5 minutes: only reads the registry, and starts the Backgrounds task when someone's mode changed.
$themeTask     = 'TLA BootPaper Theme'
$themeAction   = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $InstallDir 'theme-check.ps1')`""
$themeTriggers = @((New-ScheduledTaskTrigger -Once -At ([DateTime]::Now.AddMinutes(5)) -RepetitionInterval (New-TimeSpan -Minutes 5)))
$themeSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 2) -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName $themeTask -Action $themeAction -Trigger $themeTriggers `
    -Principal $lockPrincipal -Settings $themeSettings -Force | Out-Null

# ---- TLA Care (5.0) -------------------------------------------------------------------------------------
# As SYSTEM: at startup, after each sign-in, daily at lunchtime, and when TLA Care asks (anyone may start it; see
# care-system.ps1 for the short list of things it will do).
$careTask     = 'TLA Care'
$careAction   = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $InstallDir 'care-system.ps1')`""
$careTriggers = @((New-ScheduledTaskTrigger -AtStartup), (New-ScheduledTaskTrigger -AtLogOn), (New-ScheduledTaskTrigger -Daily -At '12:30'))
$careTriggers[0].Delay = 'PT1M'
$careTriggers[1].Delay = 'PT2M'
$careSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -MultipleInstances Queue
Register-ScheduledTask -TaskName $careTask -Action $careAction -Trigger $careTriggers `
    -Principal $lockPrincipal -Settings $careSettings -Force | Out-Null
$service.GetFolder('\').GetTask($careTask).SetSecurityDescriptor('D:(A;;FA;;;SY)(A;;FA;;;BA)(A;;GRGX;;;AU)', 0)

# ---- Updating itself (5.4) -------------------------------------------------------------------------------
# As SYSTEM, 10 minutes after startup and every 6 hours. Does nothing on computers Intune manages (Intune installs
# each new version there); the others run the newer TLA BootPaper installer from GitHub (see update.ps1).
$updateTask     = 'TLA BootPaper Updates'
$updateAction   = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $InstallDir 'update.ps1')`""
$updateTriggers = @((New-ScheduledTaskTrigger -AtStartup),
                    (New-ScheduledTaskTrigger -Once -At ([DateTime]::Now.AddMinutes(20)) -RepetitionInterval (New-TimeSpan -Hours 6)))
$updateTriggers[0].Delay = 'PT10M'
$updateSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName $updateTask -Action $updateAction -Trigger $updateTriggers `
    -Principal $lockPrincipal -Settings $updateSettings -Force | Out-Null

# ---- Unboxing (5.0) ---------------------------------------------------------------------------------------
# "Prepare for initial unboxing" is offered once, on computers BootPaper is installed on for the first time (a new
# or reset computer being set up for someone): the admin decides when. Computers already in use when 5.0 arrives
# get the tour by themselves instead: TLA Classic and the Welcome to TLA tour at the first sign-in after their next
# startup (as if prepared now; ArmedBy "update"), once the tour is out on that person's release channel.
$unboxKey = 'HKEY_LOCAL_MACHINE\SOFTWARE\WelcomeVideo\Unbox'
if (-not (Get-WVValue $unboxKey 'State')) {
    if ($wasInstalled) {
        [Microsoft.Win32.Registry]::SetValue($unboxKey, 'ArmedAt', [DateTime]::UtcNow.ToString('o'))
        [Microsoft.Win32.Registry]::SetValue($unboxKey, 'ArmedBy', 'update')
        [Microsoft.Win32.Registry]::SetValue($unboxKey, 'State', 'armed')
    } else {
        [Microsoft.Win32.Registry]::SetValue($unboxKey, 'State', 'ready')
    }
}

# ---- Windows' "About" page and the default account picture (5.0) -----------------------------------------
# Settings > System > About shows TLA as the support contact (email only), with the TLA logo. The default
# account picture (anyone without one of their own) is the TLA logo. What was there before is kept, so
# uninstalling puts it back.
$oemKey    = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation'
$oemBackup = 'HKEY_LOCAL_MACHINE\SOFTWARE\WelcomeVideo\OEMBackup'
try {
    if ($null -eq (Get-WVValue $oemBackup 'Saved')) {
        foreach ($name in 'Manufacturer', 'SupportURL', 'SupportPhone', 'SupportHours', 'Logo') {
            $old = Get-WVValue $oemKey $name
            [Microsoft.Win32.Registry]::SetValue($oemBackup, $name, $(if ($null -eq $old) { '<none>' } else { "$old" }))
        }
        [Microsoft.Win32.Registry]::SetValue($oemBackup, 'Saved', '1')
    }
    [Microsoft.Win32.Registry]::SetValue($oemKey, 'Manufacturer', 'Traditional Learning Academy')
    [Microsoft.Win32.Registry]::SetValue($oemKey, 'SupportURL', 'mailto:helpdesk@schoolathome.ca')
    [Microsoft.Win32.Registry]::SetValue($oemKey, 'Logo', (Join-Path $InstallDir 'oem-logo.bmp'))
    $k = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation', $true)
    if ($k) { $k.DeleteValue('SupportPhone', $false); $k.DeleteValue('SupportHours', $false); $k.Close() }   # (email only)
} catch { Write-Output "Couldn't set the support details: $($_.Exception.Message)" }
$pictures = Join-Path $env:ProgramData 'Microsoft\User Account Pictures'
$picBackup = Join-Path $InstallDir 'AccountPictureBackup'
if ((Test-Path -LiteralPath $pictures) -and -not (Test-Path -LiteralPath $picBackup)) {
    New-Item -ItemType Directory -Path $picBackup -Force | Out-Null
    foreach ($f in 'user.png', 'user.bmp', 'user-32.png', 'user-40.png', 'user-48.png', 'user-192.png') {
        $old = Join-Path $pictures $f
        if (Test-Path -LiteralPath $old) { Copy-Item -LiteralPath $old -Destination (Join-Path $picBackup $f) -Force -ErrorAction SilentlyContinue }
    }
}
if (Test-Path -LiteralPath $pictures) {
    foreach ($f in 'user.png', 'user.bmp', 'user-32.png', 'user-40.png', 'user-48.png', 'user-192.png') {
        try { Copy-WVFile (Join-Path $PSScriptRoot "account-$f") (Join-Path $pictures $f) -Optional } catch { }
    }
}
# Notes what TLA Care needs (when Intune last checked in) and sets the unboxing state's starting point.
Start-ScheduledTask -TaskName $careTask -ErrorAction SilentlyContinue

# Written last, so a half-finished install is never reported as installed.
Set-Content -LiteralPath (Join-Path $InstallDir 'version.txt') -Value $Version

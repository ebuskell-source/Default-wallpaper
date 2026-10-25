# lock-backgrounds.ps1
# Runs as SYSTEM from the "TLA BootPaper Backgrounds" scheduled task (created by install-video.ps1): at
# startup, whenever someone signs in, and when the TLA BootPaper app asks (anyone may start the task).
# Keeps everyone's desktop and lock screen to the TLA presets, each person with their own choice:
#   - "Default lock screen image" = the background of the person signed in (4.1; before, the organization
#     default), kept after they sign out, so a student's own laptop always shows their pick, and
#     "Prevent changing lock screen" on, so nobody can pick their own lock screen in Settings.
#   - For the person signed in: the "Desktop Wallpaper" policy in their own profile = their preset, and
#     "Prevent changing desktop background", so the app is the only way to change it.
#   - If the app has asked to set their lock screen (State\LockScreenRequest), "Prevent changing lock
#     screen" is lifted until it's done (at most 90 seconds), then put back.
# Only ever uses the preset files. Leaves pictures alone that Intune or another policy sets.
# (Until 4.0.5 it also downloaded the intro videos; that's now the "TLA BootPaper Videos" task, so a long
# download never holds up a background someone has just picked.)

$ErrorActionPreference = 'Stop'
. ([System.IO.Path]::Combine($PSScriptRoot, 'common.ps1'))

$log = [System.IO.Path]::Combine($WV.Dir, 'backgrounds.log')
function Write-Log([string]$Text) {
    try {
        if ([System.IO.File]::Exists($log) -and ([System.IO.FileInfo]::new($log)).Length -gt 65536) { [System.IO.File]::Delete($log) }
        [System.IO.File]::AppendAllText($log, ('{0:yyyy-MM-dd HH:mm:ss} {1}{2}' -f [DateTime]::Now, $Text, [Environment]::NewLine))
    } catch { }
}
function Set-Value($Key, $Name, $Value, $Kind = 'String') {
    if ("$(Get-WVValue $Key $Name)" -ne "$Value") {
        [Microsoft.Win32.Registry]::SetValue($Key, $Name, $Value, [Microsoft.Win32.RegistryValueKind]::$Kind)
    }
}
function Remove-Value($Key, $Name) {
    $k = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($Key.Replace('HKEY_LOCAL_MACHINE\', ''), $true)
    if ($k) { $k.DeleteValue($Name, $false); $k.Close() }
}

# ---- Before 3.2.3 the pictures were one per PC (PersonalizationCSP). Remove those, and any other ----
# PersonalizationCSP picture Intune doesn't set (3.6.5: Windows can move a 3.2.1 picture to its own folder,
# which then looked like the organization's and stopped people changing their background).
foreach ($kind in 'Desktop', 'LockScreen') {
    $path   = "$(Get-WVValue $WV.CspKey "$($kind)ImagePath")"
    $url    = "$(Get-WVValue $WV.CspKey "$($kind)ImageUrl")"
    $status = "$(Get-WVValue $WV.CspKey "$($kind)ImageStatus")"
    if (-not ($path -or $url -or $status)) { continue }
    $ours = ($path -and (Test-WVOurPicture $path)) -or ($url -and (Test-WVOurPicture $url))
    if ($ours -or -not (Test-WVCspManaged $kind)) {
        foreach ($name in "$($kind)ImagePath", "$($kind)ImageUrl", "$($kind)ImageStatus") { Remove-Value $WV.CspKey $name }
        Write-Log "Removed a leftover PC-wide $kind picture ('$path')."
    }
}

# ---- The announcement (4.0): written on a copy of every lock screen picture ---------------------------
# Backgrounds\announce\<picture>-<code>.jpg: the picture with a dark band near the bottom holding the text, inside
# the part every screen shape shows. The code changes with the text, so Windows picks up a new announcement.
# Copies of an older announcement are deleted. No announcement: no copies. (5.0: the light and dark pictures too.)
function New-AnnouncementPicture([string]$Source, [string]$Target, [string]$Text) {
    Add-Type -AssemblyName System.Drawing
    $orig = [System.Drawing.Image]::FromFile($Source)
    try { $bmp = [System.Drawing.Bitmap]::new($orig) } finally { $orig.Dispose() }
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $g.SmoothingMode     = 'AntiAlias'
        $g.TextRenderingHint = 'AntiAliasGridFit'
        $w = $bmp.Width; $h = $bmp.Height
        # The part a 16:9 screen shows (the pictures have extra room above and below; "fill" crops it).
        $safeH = [Math]::Min($h, $w * 9 / 16); $safeTop = ($h - $safeH) / 2
        $maxTextW = $w * 0.66
        $size = $safeH * 0.028
        $fmt = [System.Drawing.StringFormat]::new()
        $fmt.Alignment = 'Center'
        do {
            $font = [System.Drawing.Font]::new('Segoe UI Semibold', [float]$size, [System.Drawing.GraphicsUnit]::Pixel)
            $measured = $g.MeasureString($Text, $font, [int]$maxTextW, $fmt)
            if ($measured.Height -le $font.GetHeight($g) * 3.2 -or $size -le $safeH * 0.02) { break }
            $font.Dispose(); $size *= 0.92
        } while ($true)
        $head = [System.Drawing.Font]::new('Segoe UI Semibold', [float]($size * 0.62), [System.Drawing.GraphicsUnit]::Pixel)
        $headText = 'ANNOUNCEMENT'
        $headH = $head.GetHeight($g)
        $padX = $size * 1.0; $padY = $size * 0.5
        $boxW = [Math]::Max($measured.Width, $g.MeasureString($headText, $head).Width) + 2 * $padX
        $boxH = $headH + $size * 0.1 + $measured.Height + 2 * $padY
        $bottom = $safeTop + $safeH * 0.975
        $x = ($w - $boxW) / 2; $y = $bottom - $boxH
        $r = $size * 0.6
        $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
        $path.AddArc([float]$x, [float]$y, [float](2 * $r), [float](2 * $r), 180, 90)
        $path.AddArc([float]($x + $boxW - 2 * $r), [float]$y, [float](2 * $r), [float](2 * $r), 270, 90)
        $path.AddArc([float]($x + $boxW - 2 * $r), [float]($y + $boxH - 2 * $r), [float](2 * $r), [float](2 * $r), 0, 90)
        $path.AddArc([float]$x, [float]($y + $boxH - 2 * $r), [float](2 * $r), [float](2 * $r), 90, 90)
        $path.CloseFigure()
        $fill = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(185, 12, 18, 30))
        $g.FillPath($fill, $path)
        $gold  = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 242, 184, 48))
        $white = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
        $g.DrawString($headText, $head, $gold, [System.Drawing.RectangleF]::new([float]$x, [float]($y + $padY), [float]$boxW, [float]$headH), $fmt)
        $g.DrawString($Text, $font, $white, [System.Drawing.RectangleF]::new([float](($w - $maxTextW) / 2),
            [float]($y + $padY + $headH + $size * 0.1), [float]$maxTextW, [float]($measured.Height + 4)), $fmt)
        $fill.Dispose(); $gold.Dispose(); $white.Dispose(); $path.Dispose(); $font.Dispose(); $head.Dispose(); $fmt.Dispose()
    } finally { $g.Dispose() }
    try {
        $jpeg = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
        $params = [System.Drawing.Imaging.EncoderParameters]::new(1)
        $params.Param[0] = [System.Drawing.Imaging.EncoderParameter]::new([System.Drawing.Imaging.Encoder]::Quality, [long]90)
        $temp = "$Target.tmp"
        $bmp.Save($temp, $jpeg, $params)
        [System.IO.File]::Copy($temp, $Target, $true); [System.IO.File]::Delete($temp)
    } finally { $bmp.Dispose() }
}

function Update-AnnouncementPictures {
    $dir  = [System.IO.Path]::Combine($WV.Dir, 'Backgrounds', 'announce')
    $text = Get-WVAnnouncement
    $code = if ($text) { Get-WVAnnouncementCode $text } else { '' }
    $keep = @{}
    if ($text) {
        [void][System.IO.Directory]::CreateDirectory($dir)
        foreach ($id in @($WV.Backgrounds.Keys) + @($WV.Seasonal.Keys)) {
            foreach ($source in @((Get-WVBackgroundPath $id), (Get-WVBackgroundPath $id $WV.Variants[$id])) | Select-Object -Unique) {
                if (-not $source -or -not [System.IO.File]::Exists($source)) { continue }
                $target = [System.IO.Path]::Combine($dir, "$([System.IO.Path]::GetFileNameWithoutExtension($source))-$code.jpg")
                $keep[$target.ToLowerInvariant()] = $true
                if ([System.IO.File]::Exists($target)) { continue }
                try { New-AnnouncementPicture $source $target $text }
                catch { Write-Log "Couldn't write the announcement on '$id': $($_.Exception.Message)"; return }
            }
        }
    }
    if ([System.IO.Directory]::Exists($dir)) {
        foreach ($file in [System.IO.Directory]::GetFiles($dir)) {
            if ($keep.Contains($file.ToLowerInvariant())) { continue }
            # (5.9.0: the copy of someone's own picture with this announcement: made below, for whoever is signed in)
            if ($code -and [System.IO.Path]::GetFileName($file) -cmatch "^own-[0-9a-f]{8}-$code\.jpg$") { continue }
            try { [System.IO.File]::Delete($file) } catch { }   # an older announcement (Windows has its own copy)
        }
    }
}
try { Update-AnnouncementPictures } catch { Write-Log "Announcement: $($_.Exception.Message)" }

# ---- The whole PC: default lock screen, and nobody picks their own ----------------------------------
# 4.1: the default lock screen picture follows the person signed in (set below); with nobody signed in, it
# stays that of the last person, else the organization's default (or the seasonal theme while it's on).
# Always with the organization's announcement on it, when there is one.
$lockOurs = -not (Test-WVLockScreenLocked)
# (5.0: in the light or dark picture of the person it's for: $WV.UserKey and ThemeKey point at them.)
function Set-DefaultLockScreen([string]$Id) {
    if (-not $lockOurs) { return }
    $file = Get-WVLockScreenPath $Id
    if (-not $file -or -not [System.IO.File]::Exists($file)) { return }
    if ("$(Get-WVValue $WV.LockPolicy 'LockScreenImage')" -ne $file) { Write-Log "Default lock screen set to '$Id'$(if ($file -like '*\announce\*') { ' (with the announcement)' })." }
    Set-Value $WV.LockPolicy 'LockScreenImage' $file
    Set-Value $WV.DeviceKey 'LockScreenFor' $Id
    Set-Value $WV.DeviceKey 'LockScreenMode' (Get-WVMode)
}
if ($lockOurs) {
    $defaultId = "$(Get-WVValue $WV.DeviceKey 'LockScreenFor')"
    if (-not (Get-WVBackgroundPath $defaultId)) {
        $defaultId = Get-WVSeason
        if (-not $defaultId -or -not [System.IO.File]::Exists("$(Get-WVBackgroundPath $defaultId)")) { $defaultId = "$(Get-WVOrgSetting 'Background')" }
    }
    # Nobody signed in yet: the last person's mode (the organization's default setting otherwise).
    $lastMode = "$(Get-WVValue $WV.DeviceKey 'LockScreenMode')"
    $file = Get-WVLockScreenPath $defaultId
    if ($lastMode -eq 'light' -or $lastMode -eq 'dark') {
        $plain = Get-WVBackgroundPath $defaultId $lastMode
        $text  = Get-WVAnnouncement
        $file  = $plain
        if ($text) {
            $copy = [System.IO.Path]::Combine($WV.Dir, 'Backgrounds', 'announce',
                        "$([System.IO.Path]::GetFileNameWithoutExtension($plain))-$(Get-WVAnnouncementCode $text).jpg")
            if ([System.IO.File]::Exists($copy)) { $file = $copy }
        }
    }
    if ($file -and [System.IO.File]::Exists($file)) {
        if ("$(Get-WVValue $WV.LockPolicy 'LockScreenImage')" -ne $file) { Write-Log "Default lock screen set to '$defaultId'." }
        Set-Value $WV.LockPolicy 'LockScreenImage' $file
    }
    Set-Value $WV.LockPolicy 'NoChangingLockScreen' 1 'DWord'
} else {
    Write-Log 'Another policy sets the lock screen; leaving it.'
}

# ---- The person at the screen -------------------------------------------------------------------------
# The owner of Explorer in the console session. Right after a sign-in Explorer may not have started yet.
function Get-ConsoleUserSid {
    for ($i = 0; $i -lt 30; $i++) {
        $session = (Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).UserName
        if (-not $session -and $i -ge 5) { return $null }   # nobody is signing in (e.g. at startup)
        if ($session) {
            foreach ($p in @(Get-CimInstance Win32_Process -Filter "Name='explorer.exe'" -ErrorAction SilentlyContinue)) {
                $owner = Invoke-CimMethod -InputObject $p -MethodName GetOwner -ErrorAction SilentlyContinue
                if ($owner -and ('{0}\{1}' -f $owner.Domain, $owner.User) -eq $session) {
                    $ownerSid = Invoke-CimMethod -InputObject $p -MethodName GetOwnerSid -ErrorAction SilentlyContinue
                    if ($ownerSid -and $ownerSid.Sid) { $script:ConsoleSession = [int]$p.SessionId; return $ownerSid.Sid }
                }
            }
        }
        Start-Sleep -Seconds 2
    }
    return $null
}

$ConsoleSession = 0
$sid = Get-ConsoleUserSid
if (-not $sid) { exit 0 }

$WV.UserKey  = "HKEY_USERS\$sid\Software\WelcomeVideo"
$userState   = "HKEY_USERS\$sid\Software\WelcomeVideo\State"
$WV.StateKey = $userState                        # (where "Surprise me" keeps today's pick)
$WV.ThemeKey = "HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"   # (5.0: their light or dark mode)
$WV.SignInSid = $sid                             # (5.7.0: whether they've signed in: TLA Classic until they do)
# 5.9.0: their profile folder, where any pictures of their own are (on a PC of their own: Test-WVOwnPicturesAllowed).
$WV.OwnProfile = "$(Get-WVValue "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$sid" 'ProfileImagePath')"
if (-not $WV.OwnProfile -or -not [System.IO.Directory]::Exists($WV.OwnProfile)) { $WV.OwnProfile = '' }
$id   = Get-WVCurrentBackground                  # only ever an id from the preset (or seasonal) list, or one of their own pictures
$path = Get-WVShownPath $id                      # (5.0: the picture for their light or dark mode)
if (-not $path -or -not [System.IO.File]::Exists($path)) { Write-Log "No preset file for '$id'."; exit 1 }
$lockId   = Get-WVLockBackground                 # (4.2: the lock screen can have its own)
$lockPlain = Get-WVShownPath $lockId
# 5.9.0: one of their own pictures on the lock screen gets the announcement written on too (a copy in announce\, named
# after it, like the presets' copies above). Only their own JPEG copy, at a sensible size.
$announceText = Get-WVAnnouncement
if ((Test-WVOwnId $lockId) -and $announceText -and $lockPlain -and [System.IO.File]::Exists($lockPlain) -and
    ([System.IO.FileInfo]::new($lockPlain)).Length -lt 40MB) {
    $ownCopy = [System.IO.Path]::Combine($WV.Dir, 'Backgrounds', 'announce', "$lockId-$(Get-WVAnnouncementCode $announceText).jpg")
    if (-not [System.IO.File]::Exists($ownCopy)) {
        try {
            [void][System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($ownCopy))
            New-AnnouncementPicture $lockPlain $ownCopy $announceText
        } catch { Write-Log "Couldn't write the announcement on their own picture: $($_.Exception.Message)" }
    }
}
$lockPath = Get-WVLockScreenPath $lockId
Set-DefaultLockScreen $lockId                    # (4.1: the lock screen shows their pick)
$fit      = "$(Get-WVSetting 'WallpaperFit')"     # (4.2: fill, fit or span)

# Popularity (4.0): what this person uses, for the organization's Intune report (an Intune remediation's
# detection script reads HKLM\SOFTWARE\WelcomeVideo\Popularity). Choices only: no names.
try {
    $pop = "HKEY_LOCAL_MACHINE\SOFTWARE\WelcomeVideo\Popularity\$sid"
    $chosen = if (Test-WVOnDefaultBackground) { 'default' } else { Get-WVReportedBackground "$(Get-WVSetting 'Background')" }
    Set-Value $pop 'Background' (Get-WVReportedBackground $id)   # (5.9.0: "own" for their own pictures, never a file name)
    Set-Value $pop 'Chosen' $chosen
    Set-Value $pop 'Video' "$(Get-WVSetting 'Video')"
    Set-Value $pop 'VideoOn' "$(Get-WVSetting 'Enabled')"
    Set-Value $pop 'QuietMode' "$(Get-WVSetting 'QuietMode')"
    Set-Value $pop 'Greeting' $(if (Get-WVGreeting) { '1' } else { '0' })   # (5.6.0: off when they've turned it off)
    Set-Value $pop 'Channel' (Get-WVChannel)   # (4.3)
    Set-Value $pop 'LightDark' "$(Get-WVSetting 'LightDark')"          # (5.0)
    Set-Value $pop 'Screensaver' "$(Get-WVSetting 'Screensaver')"      # (5.0)
    Set-Value $pop 'Updated' ([DateTime]::Today.ToString('yyyy-MM-dd'))
} catch { Write-Log "Popularity: $($_.Exception.Message)" }

# Desktop: their own "Desktop Wallpaper" policy (fill the screen), and no changing it in Settings.
$system = "HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Policies\System"
$current = "$(Get-WVValue $system 'Wallpaper')"
if (-not (Test-WVOurPicture $current)) {
    Write-Log "Another policy sets the desktop for $sid; leaving it."
} else {
    if ($current -ne $path) { Write-Log "Desktop for $sid set to '$id'." }
    Set-Value $system 'Wallpaper' $path
    Set-Value $system 'WallpaperStyle' $WV.FitPolicy[$fit]   # 4 = fill, 3 = fit, 5 = span
    Set-Value "HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" 'NoChangingWallPaper' 1 'DWord'
}

# Lock screen: open it for this person's own preset only, and only while the app is setting it.
$request = "$(Get-WVValue $userState 'LockScreenRequest')"
if ($lockOurs -and $request) {
    if ($request -ne $lockPlain -and $request -ne $lockPath) {
        Write-Log "Lock screen request for $sid isn't their preset; ignored."
        Set-Value $userState 'LockScreenRequest' ''
    } else {
        Remove-Value $WV.LockPolicy 'NoChangingLockScreen'
        $deadline = [DateTime]::Now.AddSeconds(90)
        while ("$(Get-WVValue $userState 'LockScreenRequest')" -and [DateTime]::Now -lt $deadline) { Start-Sleep -Milliseconds 500 }
        Set-Value $WV.LockPolicy 'NoChangingLockScreen' 1 'DWord'
        Set-Value $userState 'LockScreenRequest' ''
        Write-Log ("Lock screen for {0} set to '{1}'{2}." -f $sid, $lockId,
            $(if ("$(Get-WVValue $userState 'AppliedLockScreen')" -eq $request) { '' } else { ' (Windows didn''t confirm it)' }))
    }
} elseif ($ConsoleSession) {
    # 4.1: their own lock screen or desktop is out of date (a new announcement, the season or today's "Surprise
    # me" pick changed, or an earlier try didn't work): put them right in their session now, rather than at
    # their next sign-in. (The "TLA BootPaper Apply" task runs apply-background.ps1 as them; at most every
    # 10 minutes, and the lock screen at most once a day per picture.)
    $today      = [DateTime]::Today.ToString('yyyy-MM-dd')
    $lockStale  = $lockOurs -and "$(Get-WVValue $userState 'AppliedLockScreen')" -ne $lockPath -and
                  "$(Get-WVValue $userState 'LockScreenAttempt')" -ne "$lockPath|$today"
    $deskStale  = (Test-WVOurPicture "$(Get-WVValue $system 'Wallpaper')") -and
                  ("$(Get-WVValue "HKEY_USERS\$sid\Control Panel\Desktop" 'WallPaper')" -ne $path -or
                   "$(Get-WVValue "HKEY_USERS\$sid\Control Panel\Desktop" 'WallpaperStyle')" -ne $WV.FitStyle[$fit])
    $lastKick   = [DateTime]::MinValue
    [void][DateTime]::TryParse("$(Get-WVValue $userState 'ApplyKick')", [Globalization.CultureInfo]::InvariantCulture, 'None', [ref]$lastKick)
    # (5.0: straight away when the picture they need is a different one since the last try, e.g. they just
    # switched between light and dark mode.)
    $kickFor    = "$path|$lockPath"
    if (($lockStale -or $deskStale) -and ([DateTime]::Now -gt $lastKick.AddMinutes(10) -or "$(Get-WVValue $userState 'ApplyKickFor')" -ne $kickFor)) {
        Set-Value $userState 'ApplyKick' ([DateTime]::Now.ToString('s'))
        Set-Value $userState 'ApplyKickFor' $kickFor
        try {
            $service = New-Object -ComObject 'Schedule.Service'
            $service.Connect()
            [void]$service.GetFolder('\').GetTask('TLA BootPaper Apply').RunEx($null, 4, $ConsoleSession, '')   # 4 = in their session
            Write-Log ("Updating {0}'s {1} in their session." -f $sid, $(if ($lockStale -and $deskStale) { 'desktop and lock screen' } elseif ($lockStale) { 'lock screen' } else { 'desktop' }))
        } catch { Write-Log "Couldn't start the TLA BootPaper Apply task: $($_.Exception.Message)" }
    }
}
exit 0

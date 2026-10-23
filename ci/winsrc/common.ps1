# common.ps1
# Settings shared by play-video.ps1 (the player), settings.ps1 (the TLA BootPaper app),
# whatsnew.ps1 (the release log) and apply-background.ps1.
#
#   Organization defaults: HKLM\SOFTWARE\WelcomeVideo        (written by install-video.ps1)
#   Each person's choices: HKCU\Software\WelcomeVideo        (written by the TLA BootPaper app)
#   What has happened:     HKCU\Software\WelcomeVideo\State  (written by the player and the app)
#
# A person's own choice wins over the organization default, unless UsersCanChange is 0.
# Uses .NET calls only (no cmdlets), so loading it doesn't slow the video down at sign-in.

$WV = @{
    Dir       = $PSScriptRoot
    Release   = '5.7.0' # this package's version (4.3: what people see also depends on their release channel)
    DeviceKey = 'HKEY_LOCAL_MACHINE\SOFTWARE\WelcomeVideo'
    UserKey   = 'HKEY_CURRENT_USER\Software\WelcomeVideo'
    StateKey  = 'HKEY_CURRENT_USER\Software\WelcomeVideo\State'
    Names     = 'Enabled', 'PlayWhen', 'Sound', 'AllowSkip', 'Background', 'Video',
                'QuietMode', 'QuietStart', 'QuietEnd', 'QuietDays', 'PreferredName',
                'WallpaperFit', 'LockBackground', 'TempBackground', 'TempUntil', 'Channel',
                'LightDark', 'Screensaver', 'CallBackgrounds', 'CareReminders', 'Greeting'   # (5.5.5: Greeting on or off)
    # Used only when neither the organization nor the person has set anything.
    Defaults  = @{ Enabled = 1; PlayWhen = 'EverySignIn'; Sound = 1; AllowSkip = 0; Background = 'microsoft'; Video = 'match'
                   QuietMode = 'Off'; QuietStart = '08:30'; QuietEnd = '15:00'; QuietDays = 'Mon,Tue,Wed,Thu,Fri'
                   PreferredName = ''; WallpaperFit = 'Fill'; LockBackground = 'same'; TempBackground = ''; TempUntil = ''
                   Channel = 'stable'; LightDark = 'Auto'; Screensaver = 1; CallBackgrounds = 1; CareReminders = 1; Greeting = 1 }
    # How the desktop picture fits the screen (4.2). Values: the "WallpaperStyle" Windows uses for each, and the
    # matching "Desktop Wallpaper" policy style.
    FitModes  = [ordered]@{
        'Fill' = 'Fill the screen'
        'Fit'  = 'Show the whole picture'
        'Span' = 'Stretch across all my screens'
    }
    FitStyle  = @{ 'Fill' = '10'; 'Fit' = '6'; 'Span' = '22' }
    FitPolicy = @{ 'Fill' = '4'; 'Fit' = '3'; 'Span' = '5' }
    # "Use my pick" (4.2): for good, or just for a while, then back to what was there before.
    PickFor   = [ordered]@{ 'Always' = 'From now on'; 'Tomorrow' = 'Just for today'; 'Week' = 'For one week' }
    # Quiet hours (4.0): the intro video plays without sound. Off unless the person turns it on.
    QuietModes = [ordered]@{
        'Off'          = "Don't mute it"
        'DoNotDisturb' = 'Mute it while Do Not Disturb is on'
        'Hours'        = 'Mute it during these hours'
    }
    Days      = 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
    NameMax   = 30
    # Seasonal themes (4.0): during its season, everyone still on the organization's default background gets
    # the seasonal one instead (desktop and lock screen). Picking a background yourself keeps yours. They have
    # no intro video of their own: the default background's video plays.
    Seasonal  = [ordered]@{ 'fall' = 'Fall'; 'christmas' = 'Christmas'; 'easter' = 'Easter' }
    SeasonEnds = @{ 'fall' = 'November 30'; 'christmas' = 'January 6'; 'easter' = 'Easter Monday' }
    # The organization's announcement (4.0), set in Intune (an imported administrative template): written on
    # every lock screen picture by lock-backgrounds.ps1, and shown at the top of the app.
    AnnouncementKey = 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\TLA\BootPaper'
    # EverySignIn = every sign-in
    # OncePerDay  = the first sign-in each day
    # AfterUpdate = the first sign-in after Windows installs an update (the Windows build number changes)
    # FirstTime   = once per person, and again when the video file changes
    PlayWhenChoices = 'EverySignIn', 'OncePerDay', 'AfterUpdate', 'FirstTime'
    # The only backgrounds people can choose (for the desktop and the lock screen). Files: Backgrounds\<id>.jpg,
    # thumbnails in Backgrounds\thumbs. The app lists the ones with no intro video (not in Videos below) in
    # their own "coming soon" section.
    Backgrounds = [ordered]@{
        'microsoft'     = 'Microsoft'
        'liquid-glass'  = 'Liquid Glass'
        'penguins'      = 'Penguins'
        'code'          = 'Code'
        'frutiger-aero' = 'Frutiger Aero'
        'solarpunk'     = 'Solarpunk'
        'rainy'         = 'Rainy'
        'space'         = 'Space'
        'ocean'         = 'Underwater'
        'beach'         = 'Beach'           # (5.4)
        'claymation'    = 'Claymation'
        'blocks'        = 'Blocks'
        'bricks'        = 'Bricks'
        'pixel'         = '8-Bit'
        'anime'         = 'Anime'
        'sky-city'      = 'Sky City'
        'tla'           = 'TLA Classic'
    }
    # The intro videos people can choose. Files: Videos\<id>.mp4. 'match' = the video that goes with
    # the person's desktop background.
    Videos = [ordered]@{
        'match'                  = 'Match my desktop background'
        'surprise'               = 'Surprise me (a different one each time)'
        'microsoft'              = 'Microsoft'
        'liquid-glass'           = 'Liquid Glass'
        'penguins'               = 'Penguins'
        'code'                   = 'Code'
        'frutiger-aero'          = 'Frutiger Aero'
        'solarpunk'              = 'Solarpunk'
        'rainy'                  = 'Rainy'
        'space'                  = 'Space'
        'ocean'                  = 'Underwater'
        'beach'                  = 'Beach'   # (5.4)
        'claymation'             = 'Claymation'
        'blocks'                 = 'Blocks'
        'bricks'                 = 'Bricks'
        'pixel'                  = '8-Bit'
        'anime'                  = 'Anime'
        'sky-city'               = 'Sky City'
        'tla'                    = 'TLA Classic'
        'frutiger-aero-v2'       = 'Frutiger Aero (newer version)'
        'liquid-glass-original'  = 'Liquid Glass (original)'
        'microsoft-original'     = 'Microsoft (original)'
    }
    # Release channels (4.3). Each release is marked Stable or Experimental. Everyone gets the same package from
    # Intune, but new backgrounds, videos and features only show for people on a channel that has their release:
    # Experimental first, Stable once it's been tried. People pick their channel in the app (organization
    # default: Stable). Since = the release that brought something; anything not listed has been out for longer.
    Channels  = [ordered]@{ 'stable' = 'Stable'; 'experimental' = 'Experimental' }
    ChannelReleases = @{ 'stable' = '5.6.0'; 'experimental' = '5.7.0' }   # as marked when this package was made (5.7.0: Experimental first)
    Since     = @{ 'sky-city' = '4.3'; 'report' = '4.3'
                   'lightdark' = '5.0'; 'screensaver' = '5.0'; 'calls' = '5.0'; 'care' = '5.0'; 'tour' = '5.0'
                   'connect' = '5.2.5'
                   'beach' = '5.4'; 'anime-dark' = '5.4'; 'pixel-dark' = '5.4.5'; 'claymation-dark' = '5.4.5'
                   'greeting-styles' = '5.5.5'; 'greeting-switch' = '5.5.5'
                   'solarpunk-dark' = '5.6.0'; 'sky-city-dark' = '5.6.0'; 'space-light' = '5.6.0'; 'ocean-dark' = '5.6.0'
                   'signin' = '5.7.0' }   # (5.4: '<id>-<mode>' = that background's second intro video)
    # Light and dark (5.0): every background has a second picture for the other mode (5.1.5: Underwater too). The
    # value is the mode of that extra picture (Backgrounds\<id>-<mode>.jpg, thumbs\<id>-<mode>.jpg); the original
    # is the other one.
    Variants  = @{
        'microsoft' = 'dark'; 'liquid-glass' = 'dark'; 'frutiger-aero' = 'dark'; 'solarpunk' = 'dark'; 'rainy' = 'dark'
        'claymation' = 'dark'; 'blocks' = 'dark'; 'bricks' = 'dark'; 'pixel' = 'dark'; 'anime' = 'dark'
        'sky-city' = 'dark'; 'tla' = 'dark'; 'penguins' = 'light'; 'code' = 'light'; 'space' = 'light'
        'ocean' = 'dark'; 'beach' = 'dark'; 'fall' = 'dark'; 'christmas' = 'dark'; 'easter' = 'dark'
    }
    LightDarkModes = [ordered]@{
        'Auto'  = 'Match my light or dark mode'
        'Light' = 'Always light'
        'Dark'  = 'Always dark'
    }
}

function Get-WVValue([string]$Key, [string]$Name) {
    try { return [Microsoft.Win32.Registry]::GetValue($Key, $Name, $null) } catch { return $null }
}

function Test-WVUsersCanChange {
    $v = Get-WVValue $WV.DeviceKey 'UsersCanChange'
    return ($null -eq $v -or "$v" -ne '0')
}

function Test-WVValid([string]$Name, $Value) {
    if ($null -eq $Value) { return $false }
    if ($Name -eq 'PlayWhen')   { return $WV.PlayWhenChoices -contains "$Value" }
    if ($Name -eq 'Background') { return $WV.Backgrounds.Contains("$Value") -or "$Value" -eq 'surprise' }
    if ($Name -eq 'Video')      { return $WV.Videos.Contains("$Value") }
    if ($Name -eq 'QuietMode')  { return $WV.QuietModes.Contains("$Value") }
    if ($Name -eq 'QuietStart' -or $Name -eq 'QuietEnd') { return "$Value" -match '^([01]\d|2[0-3]):(00|15|30|45)$' }
    if ($Name -eq 'QuietDays')  { return @("$Value".Split(',') | Where-Object { $_ -and $WV.Days -notcontains $_ }).Count -eq 0 }
    if ($Name -eq 'PreferredName') { return "$Value".Length -le $WV.NameMax -and "$Value" -notmatch '[\p{C}]' }
    if ($Name -eq 'WallpaperFit')   { return $WV.FitModes.Contains("$Value") }
    if ($Name -eq 'LockBackground') { return "$Value" -eq 'same' -or $WV.Backgrounds.Contains("$Value") }
    if ($Name -eq 'TempBackground') { return $WV.Backgrounds.Contains("$Value") }
    if ($Name -eq 'TempUntil')      { return "$Value" -match '^\d{4}-\d{2}-\d{2}$' }
    if ($Name -eq 'Channel')        { return $WV.Channels.Contains("$Value") }
    if ($Name -eq 'LightDark')      { return $WV.LightDarkModes.Contains("$Value") }
    if ($Name -eq 'Screensaver' -or $Name -eq 'CallBackgrounds' -or $Name -eq 'CareReminders' -or $Name -eq 'Greeting') { return "$Value" -eq '0' -or "$Value" -eq '1' }
    return $true
}

# The organization's value for a setting (or the built-in default).
# 4.1: Frutiger Aero's original video is "Frutiger Aero" again, so an earlier choice of the original keeps it.
function Get-WVAliased([string]$Name, $Value) {
    if ($Name -eq 'Video' -and "$Value" -eq 'frutiger-aero-original') { return 'frutiger-aero' }
    return $Value
}

function Get-WVOrgSetting([string]$Name) {
    $v = Get-WVAliased $Name (Get-WVValue $WV.DeviceKey $Name)
    if (Test-WVValid $Name $v) { return $v }
    return $WV.Defaults[$Name]
}

# The value in effect for this person. (4.3: a background or video they picked that isn't out on their
# release channel, e.g. after leaving Experimental, counts as not picked. 5.7.0: until they sign in, TLA Classic and the
# organization's settings; their release channel still counts, since that decides whether they need to.)
function Get-WVSetting([string]$Name) {
    if ($Name -ne 'Channel' -and (Test-WVSignedOut)) {
        if ($Name -eq 'Background' -or $Name -eq 'Video') { return 'tla' }
        if ($Name -eq 'LockBackground') { return 'same' }
        return Get-WVOrgSetting $Name
    }
    if (Test-WVUsersCanChange) {
        $v = Get-WVAliased $Name (Get-WVValue $WV.UserKey $Name)
        if ((Test-WVValid $Name $v) -and (Test-WVChoiceReleased $Name $v)) { return $v }
    }
    return Get-WVOrgSetting $Name
}

# ---- Release channels (4.3) --------------------------------------------------------------------------
# The newest release on each channel: from channels.json in the organization's GitHub repository (fetched by the
# "TLA BootPaper Videos" task, so a release can move from Experimental to Stable without a new package), or as
# marked in this package until that's been read.
$WV.ChannelSource = 'https://raw.githubusercontent.com/ebuskell-source/Default-wallpaper/main/TLA-BootPaper/channels.json'
$WV.ChannelKey    = 'HKEY_LOCAL_MACHINE\SOFTWARE\WelcomeVideo\Channels'

# '4.3' -> 4.3.0.0, so '4.3' and '4.3.0' compare equal and '4.2.5' comes before '4.3'. $null if it isn't a version.
function ConvertTo-WVVersion([string]$Text) {
    if ("$Text" -notmatch '^\d{1,4}(\.\d{1,4}){0,3}$') { return $null }
    $parts = @("$Text".Split('.')) + @('0', '0', '0')
    return [version]::new([int]$parts[0], [int]$parts[1], [int]$parts[2], [int]$parts[3])
}
function Test-WVVersionText([string]$Text) { return $null -ne (ConvertTo-WVVersion $Text) }

function Get-WVChannel { return "$(Get-WVSetting 'Channel')" }

# The newest release on a channel. Experimental always has at least what Stable has.
function Get-WVChannelRelease([string]$Channel) {
    if (-not $Channel) { $Channel = Get-WVChannel }
    $mark = @{}
    foreach ($ch in 'stable', 'experimental') {
        $v = "$(Get-WVValue $WV.ChannelKey $ch)"
        $mark[$ch] = if (Test-WVVersionText $v) { $v } else { $WV.ChannelReleases[$ch] }
    }
    if ($Channel -eq 'experimental' -and (ConvertTo-WVVersion $mark.experimental) -lt (ConvertTo-WVVersion $mark.stable)) { return $mark.stable }
    return $mark[$Channel]
}

# The version this person sees: their channel's release, or this package's if that's older.
function Get-WVShownRelease {
    $ch = Get-WVChannelRelease
    if ((ConvertTo-WVVersion $ch) -lt (ConvertTo-WVVersion $WV.Release)) { return $ch }
    return $WV.Release
}

# "Stable" or "Experimental" for a release, by the channel marks.
function Get-WVReleaseLabel([string]$Version) {
    if ((ConvertTo-WVVersion $Version) -le (ConvertTo-WVVersion (Get-WVChannelRelease 'stable'))) { return 'Stable' }
    return 'Experimental'
}

# True when something (a background, video or feature, by id) is out on this person's channel.
function Test-WVReleased([string]$Id) {
    if (-not $WV.Since.Contains($Id)) { return $true }
    return (ConvertTo-WVVersion $WV.Since[$Id]) -le (ConvertTo-WVVersion (Get-WVChannelRelease))
}
function Test-WVChoiceReleased([string]$Name, $Value) {
    if ($Name -eq 'Background' -or $Name -eq 'Video' -or $Name -eq 'LockBackground' -or $Name -eq 'TempBackground') {
        return Test-WVReleased "$Value"
    }
    return $true
}

# Reads channels.json (as SYSTEM, from sync-videos.ps1): {"stable": "4.3", "experimental": "4.4"}. Only version
# numbers are taken from it. Never throws.
function Update-WVChannels([scriptblock]$Log = { param($t) }) {
    try {
        try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }
        $client = [System.Net.WebClient]::new()
        try { $json = $client.DownloadString("$($WV.ChannelSource)?t=$([DateTime]::UtcNow.Ticks)") } finally { $client.Dispose() }
        $data = $json | ConvertFrom-Json
        foreach ($ch in 'stable', 'experimental') {
            $v = "$($data.$ch)".Trim()
            if (-not (Test-WVVersionText $v)) { throw "channels.json has no valid '$ch' release" }
            if ("$(Get-WVValue $WV.ChannelKey $ch)" -ne $v) {
                [Microsoft.Win32.Registry]::SetValue($WV.ChannelKey, $ch, $v)
                & $Log "Release channel ${ch}: $v"
            }
        }
    } catch { & $Log "Couldn't read the release channels: $($_.Exception.Message)" }
}

function Test-WVOn([string]$Name) { return "$(Get-WVSetting $Name)" -ne '0' }

# Windows build including the monthly update number, e.g. 26100.4061. Changes when Windows installs an update.
function Get-WVWindowsBuild {
    $cv = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    return '{0}.{1}' -f (Get-WVValue $cv 'CurrentBuild'), (Get-WVValue $cv 'UBR')
}

function Get-WVLastPlayed {
    $s = Get-WVValue $WV.StateKey 'LastPlayed'
    if (-not $s) { return $null }
    try {
        return [DateTime]::Parse($s, [Globalization.CultureInfo]::InvariantCulture,
                                 [Globalization.DateTimeStyles]::RoundtripKind).ToLocalTime()
    } catch { return $null }
}

# ---- Desktop backgrounds ---------------------------------------------------------------------
# -Mode (5.0): 'light' or 'dark' gives that mode's own picture, where the background has one.
function Get-WVBackgroundPath([string]$Id, [string]$Mode) {
    if (-not $WV.Backgrounds.Contains($Id) -and -not $WV.Seasonal.Contains($Id)) { return $null }
    if ($Mode -and $WV.Variants[$Id] -eq $Mode) {
        $variant = [System.IO.Path]::Combine($WV.Dir, 'Backgrounds', "$Id-$Mode.jpg")
        if ([System.IO.File]::Exists($variant)) { return $variant }
    }
    # "-r2": the 3.2.3 pictures, which have extra room above and below so they fill any screen shape without
    # cropping the sides. A new file name makes Windows pick up the new picture (it keeps its own copy).
    # "-r5" (3.3.3): the new 16:9 Anime picture.
    $r = if ($Id -eq 'anime') { 'r5' } else { 'r2' }
    return [System.IO.Path]::Combine($WV.Dir, 'Backgrounds', "$Id-$r.jpg")
}

function Get-WVThumbnailPath([string]$Id, [string]$Mode) {
    if ($Mode -and $WV.Variants[$Id] -eq $Mode) {
        $variant = [System.IO.Path]::Combine($WV.Dir, 'Backgrounds', 'thumbs', "$Id-$Mode.jpg")
        if ([System.IO.File]::Exists($variant)) { return $variant }
    }
    return [System.IO.Path]::Combine($WV.Dir, 'Backgrounds', 'thumbs', "$Id.jpg")
}

# ---- Light and dark (5.0) ---------------------------------------------------------------------------
# Windows' own mode (Settings > Personalization > Colors > "Choose your mode"): the Windows part of it, which the
# desktop and taskbar follow. ThemeKey is the person's own (lock-backgrounds.ps1 points it at whoever is signed in).
$WV.ThemeKey = 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
function Get-WVSystemMode {
    $v = Get-WVValue $WV.ThemeKey 'SystemUsesLightTheme'
    if ($null -eq $v) { $v = Get-WVValue $WV.ThemeKey 'AppsUseLightTheme' }
    if ("$v" -eq '0') { return 'dark' }
    return 'light'
}
# 'light' or 'dark': what this person's backgrounds show now ('' before the feature is out on their channel:
# the original pictures).
function Get-WVMode {
    if (-not (Test-WVReleased 'lightdark')) { return '' }
    switch ("$(Get-WVSetting 'LightDark')") {
        'Light' { return 'light' }
        'Dark'  { return 'dark' }
        default { return Get-WVSystemMode }
    }
}
# The picture file this person sees for a background, in their mode.
function Get-WVShownPath([string]$Id) { return Get-WVBackgroundPath $Id (Get-WVMode) }

# ---- Seasonal themes and "Surprise me" (4.0) --------------------------------------------------------
# Today's date. (WV_TODAY=yyyy-MM-dd in the environment overrides it, for testing the seasons.)
function Get-WVToday {
    $d = [DateTime]::MinValue
    if ($env:WV_TODAY -and [DateTime]::TryParseExact($env:WV_TODAY, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture,
                                                       [Globalization.DateTimeStyles]::None, [ref]$d)) { return $d.Date }
    return [DateTime]::Today
}

# Western (Gregorian) Easter Sunday: the Anonymous Gregorian algorithm.
function Get-WVEasterSunday([int]$Year) {
    $a = $Year % 19; $b = [Math]::Floor($Year / 100); $c = $Year % 100
    $d = [Math]::Floor($b / 4); $e = $b % 4
    $g = [Math]::Floor((8 * $b + 13) / 25)
    $h = (19 * $a + $b - $d - $g + 15) % 30
    $i = [Math]::Floor($c / 4); $k = $c % 4
    $l = (32 + 2 * $e + 2 * $i - $h - $k) % 7
    $m = [Math]::Floor(($a + 11 * $h + 19 * $l) / 433)
    $month = [Math]::Floor(($h + $l - 7 * $m + 90) / 25)
    return [DateTime]::new($Year, [int]$month, [int](($h + $l - 7 * $m + 33 * $month + 19) % 32))
}

# The seasonal theme in effect: Fall Sep 22 - Nov 30, Christmas Dec 1 - Jan 6, Easter from two weeks before
# Easter Sunday to Easter Monday. $null the rest of the year.
function Get-WVSeason($Day) {
    if (-not $Day) { $Day = Get-WVToday }
    if (($Day.Month -eq 9 -and $Day.Day -ge 22) -or $Day.Month -eq 10 -or $Day.Month -eq 11) { return 'fall' }
    if ($Day.Month -eq 12 -or ($Day.Month -eq 1 -and $Day.Day -le 6)) { return 'christmas' }
    $easter = Get-WVEasterSunday $Day.Year
    if ($Day -ge $easter.AddDays(-14) -and $Day -le $easter.AddDays(1)) { return 'easter' }
    return $null
}

# True for someone who hasn't picked a background themselves (or can't: the organization decides).
function Test-WVOnDefaultBackground {
    if (Test-WVSignedOut) { return $false }               # (5.7.0: TLA Classic, not the seasonal theme)
    if (-not (Test-WVUsersCanChange)) { return $true }
    $v = Get-WVValue $WV.UserKey 'Background'
    return -not ((Test-WVValid 'Background' $v) -and (Test-WVReleased "$v"))
}

# "Surprise me": a different background each day (never the same two days running), the same all day.
function Get-WVSurpriseBackground {
    $day  = (Get-WVToday).ToString('yyyy-MM-dd')
    $last = "$(Get-WVValue $WV.StateKey 'SurpriseBackground')"
    if ("$(Get-WVValue $WV.StateKey 'SurpriseDay')" -eq $day -and $WV.Backgrounds.Contains($last)) { return $last }
    $choices = @($WV.Backgrounds.Keys | Where-Object { $_ -ne $last -and (Test-WVReleased $_) })
    $pick = $choices[[System.Random]::new().Next($choices.Count)]
    try {
        [Microsoft.Win32.Registry]::SetValue($WV.StateKey, 'SurpriseDay', $day)
        [Microsoft.Win32.Registry]::SetValue($WV.StateKey, 'SurpriseBackground', $pick)
    } catch { }
    return $pick
}

# A background picked "just for today" or "for one week" (4.2), while that lasts ('' otherwise).
function Get-WVTemporaryBackground {
    if (-not (Test-WVUsersCanChange) -or (Test-WVSignedOut)) { return '' }
    $bg    = "$(Get-WVValue $WV.UserKey 'TempBackground')"
    $until = "$(Get-WVValue $WV.UserKey 'TempUntil')"
    if (-not (Test-WVValid 'TempBackground' $bg) -or -not (Test-WVValid 'TempUntil' $until) -or -not (Test-WVReleased $bg)) { return '' }
    if ($until -lt (Get-WVToday).ToString('yyyy-MM-dd')) { return '' }
    return $bg
}

# The background to show today: one picked for a while (4.2), the seasonal theme for people on the default, a
# daily pick for "Surprise me", otherwise the one chosen.
function Get-WVCurrentBackground {
    $temp = Get-WVTemporaryBackground
    if ($temp) { return $temp }
    $season = Get-WVSeason
    if ($season -and (Test-WVOnDefaultBackground)) {
        $p = Get-WVBackgroundPath $season
        if ($p -and [System.IO.File]::Exists($p)) { return $season }
    }
    $bg = "$(Get-WVSetting 'Background')"
    if ($bg -eq 'surprise') { return Get-WVSurpriseBackground }
    return $bg
}

# The lock screen's background (4.2): the desktop's, unless they picked another one for it.
function Get-WVLockBackground {
    $lock = "$(Get-WVSetting 'LockBackground')"
    if ($lock -and $lock -ne 'same') { return $lock }
    return Get-WVCurrentBackground
}

# The organization's announcement: one line, at most 300 characters ('' when there's none).
function Get-WVAnnouncement {
    $text = "$(Get-WVValue $WV.AnnouncementKey 'Announcement')"
    $text = ($text -replace '[\p{C}]+', ' ' -replace '\s+', ' ').Trim()
    if ($text.Length -gt 300) { $text = $text.Substring(0, 300).Trim() }
    return $text
}

# The lock screen picture for a background: with an announcement, the copy that has it written on
# (Backgrounds\announce\<id>-<code>.jpg, made by lock-backgrounds.ps1; the code changes with the text, so
# Windows picks up a new announcement). Until that copy exists, the plain picture.
# (5.0: in the person's light or dark mode. The copy is named after the picture: announce\<picture>-<code>.jpg.)
function Get-WVLockScreenPath([string]$Id) {
    $plain = Get-WVShownPath $Id
    $text  = Get-WVAnnouncement
    if (-not $plain -or -not $text) { return $plain }
    $file = [System.IO.Path]::Combine($WV.Dir, 'Backgrounds', 'announce',
                                      "$([System.IO.Path]::GetFileNameWithoutExtension($plain))-$(Get-WVAnnouncementCode $text).jpg")
    if ([System.IO.File]::Exists($file)) { return $file }
    return $plain
}

function Get-WVAnnouncementCode([string]$Text) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes("v1|$Text"))
        return ([System.BitConverter]::ToString($hash, 0, 4) -replace '-', '').ToLowerInvariant()
    } finally { $sha.Dispose() }
}

# ---- Quiet hours and the greeting (4.0) ----------------------------------------------------------------
# True while Windows' Do Not Disturb (Focus assist) is on, read from the same signal the notification
# center uses (WNF_SHEL_QUIETHOURS_ACTIVE_PROFILE_CHANGED: 0 = off). Only looked at when someone chose it.
function Test-WVDoNotDisturb {
    try {
        if (-not ('WelcomeVideo.Quiet' -as [type])) {
            Add-Type -Namespace WelcomeVideo -Name Quiet -MemberDefinition @'
[DllImport("ntdll.dll")]
static extern int NtQueryWnfStateData(ref ulong stateName, IntPtr typeId, IntPtr explicitScope,
                                      out uint changeStamp, byte[] buffer, ref uint bufferSize);
public static int Profile() {
    ulong name = 0x0D83063EA3BF1C75UL;   // WNF_SHEL_QUIETHOURS_ACTIVE_PROFILE_CHANGED
    byte[] buffer = new byte[4]; uint size = 4, stamp;
    int status = NtQueryWnfStateData(ref name, IntPtr.Zero, IntPtr.Zero, out stamp, buffer, ref size);
    if (status != 0 || size < 4) return -1;
    return BitConverter.ToInt32(buffer, 0);
}
'@
        }
        return ([WelcomeVideo.Quiet]::Profile() -gt 0)
    } catch { return $false }
}

# Quiet hours: mute the intro video while Do Not Disturb is on, or during the hours (and days) set.
function Test-WVQuietNow([DateTime]$Now = [DateTime]::Now) {
    $mode = "$(Get-WVSetting 'QuietMode')"
    if ($mode -eq 'DoNotDisturb') { return Test-WVDoNotDisturb }
    if ($mode -ne 'Hours') { return $false }
    $start = [TimeSpan]::Parse("$(Get-WVSetting 'QuietStart')").TotalMinutes
    $end   = [TimeSpan]::Parse("$(Get-WVSetting 'QuietEnd')").TotalMinutes
    $days  = "$(Get-WVSetting 'QuietDays')".Split(',')
    $minute = $Now.Hour * 60 + $Now.Minute
    $today     = $WV.Days[([int]$Now.DayOfWeek + 6) % 7]       # DayOfWeek: Sunday = 0
    $yesterday = $WV.Days[([int]$Now.DayOfWeek + 5) % 7]
    if ($start -le $end) { return ($days -contains $today) -and $minute -ge $start -and $minute -lt $end }
    # Overnight (e.g. 21:00 - 07:00): the evening part counts for that day, the morning part for the day before.
    if ($minute -ge $start) { return ($days -contains $today) }
    return ($minute -lt $end) -and ($days -contains $yesterday)
}

# 'Good morning, Audrey!' over the start of the video, when the person has given their name (5.5.5: and hasn't
# turned the greeting off; their name stays either way).
function Get-WVGreeting([DateTime]$Now = [DateTime]::Now) {
    if ((Test-WVReleased 'greeting-switch') -and "$(Get-WVSetting 'Greeting')" -eq '0') { return '' }
    $name = ("$(Get-WVSetting 'PreferredName')" -replace '\s+', ' ').Trim()
    if (-not $name) { return '' }
    $part = if ($Now.Hour -lt 12) { 'morning' } elseif ($Now.Hour -lt 17) { 'afternoon' } else { 'evening' }
    return "Good $part, $name!"
}

# 5.5.5: each theme's intro video greets in its own style (greeting.ps1 draws it; the keys are described there). The
# same table is in the Mac (common.zsh) and Linux (tla-bootpaper.py) versions. A video without one: the classic fade.
$WV.GreetingStyles = @{
    'tla'           = 'a=line;t0=0.3;d=0.5;e=lin'
    'microsoft'     = 'a=line;d=0.8;e=out;dy=-0.5;w=semibold'
    'liquid-glass'  = 'a=line;d=0.9;e=back;sc=0.85;p=glass;w=semibold'
    'penguins'      = 'a=seq;st=0.035;d=0.7;e=back;dx=-2.5;sh=0B2545B3:0.12:0:-0.04'
    'code'          = 'a=seq;t0=0.4;st=0.06;d=0;e=step;f=mono;c=4AF626;gl=4AF62699:0.12;p=term;pre=> ;cur=_'
    'frutiger-aero' = 'a=line;d=0.9;e=elastic;sc=0.4;f=round;gl=4FD8FF:0.25'
    'solarpunk'     = 'a=seq;st=0.045;d=0.6;e=back;sy=0;an=b;c=FFFBEA;gl=7BD389:0.22'
    'rainy'         = 'a=seq;st=0.05;d=0.65;e=bounce;dy=2.2;c=DCEBFF;sh=0A1A33B3:0.1:0:-0.04'
    'space'         = 'a=rand;st=0.05;d=1.0;e=out;sc=2.2;ls=0.1;gl=B28DFF:0.3'
    'ocean'         = 'a=seq;st=0.05;d=1.1;e=out;dy=-1.6;bob=0.06;bp=2.4;c=B8F3FF;gl=0096C8:0.22'
    'beach'         = 'a=seq;st=0.05;d=0.7;e=out;dy=-0.6;bob=0.09;bp=1.8;c=FFF1C9;sh=B4462899:0.12:0:-0.04'
    'claymation'    = 'a=seq;st=0.065;d=0.7;e=elastic;sx=1.5;sy=0.3;an=b;f=round;w=heavy;c=FFB347;sh=5A2D0C:0:0.05:-0.06'
    'blocks'        = 'a=seq;st=0.07;d=0.7;e=bounce;dy=3;w=heavy;c=FF5A5A,FFD93D,5BD66B,4DA6FF;sh=000000B3:0:0.05:-0.05'
    'bricks'        = 'a=seq;st=0.075;d=0.35;e=out;sc=2.2;an=b;w=heavy;sh=B23A1E:0:0.06:-0.06'
    'pixel'         = 'a=seq;st=0.06;d=0;e=step;f=mono;c=FFD93D;sh=000000:0:0.07:-0.07;x=step'
    'anime'         = 'a=line;t0=0.25;d=0.45;e=back;sc=2.6;r=-6;it=1;w=heavy;gl=FF5FA2:0.12'
    'sky-city'      = 'a=line;d=1.6;e=out;dy=1.2;bob=0.05;bp=3.2;gl=7EC8FFCC:0.25'
}
# The style for a video file (Videos\<id>[-dark|-light].mp4; the other versions of a video share its style).
function Get-WVGreetingStyle([string]$VideoPath) {
    if (-not (Test-WVReleased 'greeting-styles')) { return '' }
    $id = [System.IO.Path]::GetFileNameWithoutExtension($VideoPath) -replace '-(dark|light)$', '' -replace '-(v2|original)$', ''
    if ($WV.GreetingStyles.ContainsKey($id)) { return $WV.GreetingStyles[$id] }
    return ''
}

# 'Version 4.3 (Stable)', and the package's own version too when the channel holds this person back.
function Get-WVVersionSummary {
    $shown = Get-WVShownRelease
    $text  = "$shown ($($WV.Channels[(Get-WVChannel)]))"
    if ($shown -ne $WV.Release) { $text += ", $($WV.Release) installed" }
    return $text
}

# The helpdesk email, with this PC's details filled in (4.0), so reports say where they're from.
function Get-WVHelpdeskLink {
    $os = "$(Get-WVValue 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'ProductName')"
    # Windows 11 still calls itself "Windows 10" there; its build numbers start at 22000.
    if ([int]"0$(Get-WVValue 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'CurrentBuild')" -ge 22000) {
        $os = $os -replace 'Windows 10', 'Windows 11'
    }
    $bg = Get-WVCurrentBackground
    $bgName = if ($WV.Backgrounds.Contains($bg)) { $WV.Backgrounds[$bg] } elseif ($WV.Seasonal.Contains($bg)) { $WV.Seasonal[$bg] } else { $bg }
    $video = "$(Get-WVSetting 'Video')"
    $body = "`r`n`r`n`r`n-- Please keep these details: they help the helpdesk --`r`n" +
            "Computer: $env:COMPUTERNAME`r`nSystem: $os (build $(Get-WVWindowsBuild))`r`n" +
            "TLA BootPaper: $(Get-WVVersionSummary)`r`nBackground: $bgName`r`nIntro video: $($WV.Videos[$video])`r`n"
    return 'mailto:helpdesk@schoolathome.ca?subject={0}&body={1}' -f [Uri]::EscapeDataString('TLA BootPaper (Windows)'),
           [Uri]::EscapeDataString($body)
}

# ---- Keeping the backgrounds to the presets ---------------------------------------------------------
# Each person has their own desktop and lock screen picture, and can only change them in this app:
#   Desktop:     the "Desktop Wallpaper" policy in each person's own profile (HKU\<them>\...\Policies\System),
#                plus "Prevent changing desktop background". lock-backgrounds.ps1 (as SYSTEM, from the
#                "TLA BootPaper Backgrounds" task) writes these for whoever is signed in; people can't change
#                the policy themselves, and Settings shows the background as managed.
#   Lock screen: set in the person's own session (apply-background.ps1, Windows' LockScreen API), with the
#                PC-wide "Prevent changing lock screen" policy on so Settings can't change it. The SYSTEM
#                task lifts that policy for a few seconds only while the app sets the person's preset.
#                "Default lock screen image" is the organization default, shown before anyone signs in.
# Only ever the preset files. Before 3.2.3 the pictures were one per PC (PersonalizationCSP); that's removed.
$WV.CspKey      = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'
$WV.LockPolicy  = 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Personalization'
$WV.TaskName    = 'TLA BootPaper Backgrounds'

# True when the path is empty or one of the preset files (i.e. set by this app).
function Test-WVOurPicture([string]$Path) {
    if (-not $Path) { return $true }
    return $Path.StartsWith($WV.Dir.TrimEnd('\') + '\Backgrounds\', [System.StringComparison]::OrdinalIgnoreCase)
}

# True when Intune (MDM) currently sets this PersonalizationCSP picture ($Kind = Desktop or LockScreen). Windows
# keeps a record of every setting MDM has applied (the provisioning node cache). Values in PersonalizationCSP
# with no such record are leftovers (from TLA BootPaper 3.2.1/3.2.2, which wrote them directly, or an old
# policy) that nothing would ever change again. If the record can't be read, it counts as managed.
function Test-WVCspManaged([string]$Kind) {
    try {
        $root = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SOFTWARE\Microsoft\Provisioning\NodeCache\CSP')
        if (-not $root) { return $false }
        $pending = [System.Collections.Generic.Stack[Microsoft.Win32.RegistryKey]]::new()
        $pending.Push($root)
        while ($pending.Count) {
            $key = $pending.Pop()
            try {
                if ("$($key.GetValue('NodeUri'))" -like "*/Personalization/$($Kind)Image*") { return $true }
                foreach ($name in $key.GetSubKeyNames()) {
                    $sub = $key.OpenSubKey($name)
                    if ($sub) { $pending.Push($sub) }
                }
            } finally { $key.Close() }
        }
        return $false
    } catch { return $true }
}

# True when Intune sets this PC's desktop or lock screen picture through PersonalizationCSP (to another picture).
function Test-WVCspLocked([string]$Kind) {
    if ("$(Get-WVValue $WV.CspKey "$($Kind)ImageStatus")" -ne '1') { return $false }
    if (Test-WVOurPicture "$(Get-WVValue $WV.CspKey "$($Kind)ImagePath")") { return $false }
    return (Test-WVCspManaged $Kind)
}

# True when something other than this app decides the desktop picture: an Intune desktop picture
# setting, or a "Desktop Wallpaper" policy pointing at another picture.
function Test-WVBackgroundLocked {
    if (Test-WVCspLocked 'Desktop') { return $true }
    $policy = "$(Get-WVValue 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\System' 'Wallpaper')"
    if ($policy -and -not (Test-WVOurPicture $policy)) { return $true }
    return $false
}

# The same for the lock screen (Intune's lock screen setting, or a "Default lock screen image" policy
# pointing at another picture).
function Test-WVLockScreenLocked {
    if (Test-WVCspLocked 'LockScreen') { return $true }
    if (-not (Test-WVOurPicture "$(Get-WVValue $WV.LockPolicy 'LockScreenImage')")) { return $true }
    return $false
}

# Asks the SYSTEM task to update this person's background policies (and, if they asked, to open the
# lock screen for a moment). Anyone may start that task; it only reads which preset they chose.
function Start-WVDeviceBackgroundUpdate {
    try {
        $service = New-Object -ComObject 'Schedule.Service'
        $service.Connect()
        [void]$service.GetFolder('\').GetTask($WV.TaskName).Run($null)
        return $true
    } catch { return $false }
}

# True when this person's desktop or lock screen isn't showing their chosen preset (a new choice, a new
# default, new picture files, or they changed it some other way). The player then puts it back.
function Test-WVBackgroundNeeded {
    $id   = Get-WVCurrentBackground
    $want = Get-WVShownPath $id                       # (5.0: in their light or dark mode)
    if (-not $want -or -not [System.IO.File]::Exists($want)) { return $false }
    if (-not (Test-WVBackgroundLocked)) {
        if ("$(Get-WVValue 'HKEY_CURRENT_USER\Control Panel\Desktop' 'WallPaper')" -ne $want) { return $true }
        # (4.2: and how it fits the screen)
        if ("$(Get-WVValue 'HKEY_CURRENT_USER\Control Panel\Desktop' 'WallpaperStyle')" -ne $WV.FitStyle["$(Get-WVSetting 'WallpaperFit')"]) { return $true }
    }
    return (Test-WVLockScreenNeeded (Get-WVLockScreenPath (Get-WVLockBackground)))
}

# The lock screen part: Windows keeps its own copy, so this remembers what was last put there. A failed
# attempt is retried once a day, not at every sign-in.
function Test-WVLockScreenNeeded([string]$Want) {
    if (Test-WVLockScreenLocked) { return $false }
    if ("$(Get-WVValue $WV.StateKey 'AppliedLockScreen')" -eq $Want) { return $false }
    return ("$(Get-WVValue $WV.StateKey 'LockScreenAttempt')" -ne "$Want|$([DateTime]::Today.ToString('yyyy-MM-dd'))")
}

# ---- Downloading the intro videos ------------------------------------------------------------------
# (Approved design, 3.2.3.) The videos aren't in the Intune package, which keeps it small and the videos at
# full quality. Each PC downloads them from VideoSource (the organization's public GitHub repository) and
# keeps one only if its SHA-256 matches the list below, so a changed or damaged file is never used.
# Sync-WVVideos runs as SYSTEM: at install, and from its own "TLA BootPaper Videos" task (sync-videos.ps1: at
# startup and every 30 minutes) until every video is in place. (Before 4.0.5 the "TLA BootPaper Backgrounds"
# task did it, so a long download held up a background someone had just picked.)
$WV.VideoSource = 'https://raw.githubusercontent.com/ebuskell-source/Default-wallpaper/main/TLA-BootPaper/videos'
$WV.VideoHashes = [ordered]@{
    'tla'                    = '7cb60be851fbcdf6a60176a524c3dee051cca3da8295be3a49cda3927f51fa9b'
    'frutiger-aero'          = 'b01287343a0b89460dc9c4403fb10ffff79cb61c7b21b6cb03c067656c3895da'   # (4.1: the original again)
    'liquid-glass'           = 'fd3e3510cad5bfcdd5557bf1050d05b2a2d3452c7ef83ca07bc2c68138cb391f'
    'microsoft'              = 'd49eea24251e2424af6bed3ca5c33dd4abd2e184ec22aea11f837361697e30e7'
    'rainy'                  = '7ae3580eb8bb70a1a692d764bca77a5670ada051262e4b208831c277c32899a7'
    'code'                   = '0e8eea44df385807898f8b732aeb804fdd3b14c1d9d169fceebbdb0993f36b02'
    'bricks'                 = '0c19192e6e13ef23946055a4593c1abba2dde8cace81408918d5a063c2488afd'   # (4.1: V2)
    'blocks'                 = '0ce92e5a85115c42e8cd02cc994914300cd50158e66776e5035e1103cacdb7a3'
    'space'                  = '1c9f81b94905fde5dfc765ed09a59b371aef771d4b79a752258c306791ef8db5'
    'claymation'             = 'dc729567f37032a23aa71d139cb663d22b1e469cb4c66d18bf8021d4fba9f503'
    'anime'                  = 'b0fc2c29f5305fe57e3617073227a9a8137f18337d5429fa74611f61653bdcaa'
    'penguins'               = '2f6f7adbeadbe959e72218b194c0de7ca43d5596a8f67a2c76bd0743ef7434eb'
    'solarpunk'              = '725ec78d91c5935963345c60f5b703f36fe017ca40cd47d6501fa956f05d304e'
    'pixel'                  = '3feef1c0d359950e00b42b4a3db355e31b73cf457736947c0bbc286d56b45930'
    'ocean'                  = '6def8de6af1e729d56d8fa8e224d85d7a7a36993c8e772ff33fa75048020e803'
    'frutiger-aero-v2'       = 'bbce9fec534928fbae3dbe94e9f5a368f92aba439454ce8882df60fb8cf22460'   # (the 3.4.3 one)
    'liquid-glass-original'  = '5dae894482e3cd513baf6214da8a340f9da38ccb7f7589507c39b71bb26afbdf'
    'microsoft-original'     = 'b781ce6a57156694d5ec85a6dfc6e2521785a7afefcbda2e10a5b985277eb4f8'
    # The seasonal themes' own videos (4.1): played by "Match my desktop background" during the season.
    'fall'                   = '9b2828fd96159967445718a8621265781397989135b8021bfeb6c18640fd9767'
    'christmas'              = '6f22a687f31f120627804a3db693c0d6b4d7c588b66fdc3c730a1165a29718eb'
    'easter'                 = 'e68f1b26c63672fcece100904d81c5ad83250d449d45059bc361ac7101482f98'
    'sky-city'               = '7d511086c4eaf32fa392034cbe7a981a2896d2796bcad76ee246f00cd72211fc'   # (4.3)
    # Intro videos for the other mode (5.0): played instead of the background's own video while that person is in
    # that mode (5.1.5: Bricks' dark one and Penguins' light one too).
    'blocks-dark'            = 'c9c6978de5739f27592f385f893102dfa66563fffd2cb66b6015439f3b7c8ce3'
    'frutiger-aero-dark'     = '1d1e6210213e3beed4b0d07f7fa2da010d62a235b805051e18d0c5469b9dc255'
    'microsoft-dark'         = 'f30e43321a61681f3c6749a472fb96be521f99405d5dab56b1aa90003bb43ba8'
    'liquid-glass-dark'      = 'ce453b6435d599156b8316565ee45d8dde4e98358cbecf41569b686b5d98cf65'
    'bricks-dark'            = '74a54c362c24bca8240f6f323df908d79488637ea96a7b9e551b142efdc60f37'   # (5.1.5)
    'penguins-light'         = '2efbec474c16367fabd03797e101d30a87fa92d4ee5ec6a3803433add727685b'   # (5.1.5)
    'beach'                  = 'b5dc48a3c56440d755068a77f6744497f28e85d62e59be51fee6f4fa75412636'   # (5.4)
    'beach-dark'             = '431a1396dc5aecd4b1dd0c58e97b2e95adde9658c2f518ef763d5083ed60731f'   # (5.4)
    'anime-dark'             = '58248a3b40f91c7cc240b3de28c360987515880572f8231e2fc9b0304bbf4560'   # (5.4)
    'pixel-dark'             = 'b0cfb3db78ba60371f7ee92502bbb6fabc6709ff38d5b6bf562f38f59f0896ce'   # (5.4.5)
    'claymation-dark'        = '0970de40e5ff566bc0b354da8200709ae00ce3bf6b8d23dd3072eb3b675cb3bf'   # (5.4.5)
    'solarpunk-dark'         = '4c47774ee0d5957e18b69e1c227b7428ca51842943e813085eb11c29d06b5f95'   # (5.6.0)
    'sky-city-dark'          = 'ad33f57f0ecf7d13dde0366661ca143f8e0f4beb6a53cb707fe81e5ac6705eb3'   # (5.6.0)
    'space-light'            = '42b2a456b88441ebed1bb1e53b88a4944b50b600baea23ff445ee696a9fa86d8'   # (5.6.0)
    'ocean-dark'             = '04e023547a1f6ed95097235ea95158a5e803bef505b5829c1f25cbcd4873a7e7'   # (5.6.0)
}

function Get-WVSha256([string]$File) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $stream = [System.IO.File]::OpenRead($File)
    try { return ([System.BitConverter]::ToString($sha.ComputeHash($stream)) -replace '-', '').ToLowerInvariant() }
    finally { $stream.Dispose(); $sha.Dispose() }
}

# Downloads any video that's missing or out of date. Returns the ids still missing. Never throws.
# 4.0.5: a video already checked isn't hashed again unless its size or date changes (VideoChecks), and only
# one download runs at a time (the install and the task could otherwise both download).
$WV.VideoChecks = 'HKEY_LOCAL_MACHINE\SOFTWARE\WelcomeVideo\VideoChecks'
function Test-WVVideoOk([string]$Id, [string]$Target, [string]$Want) {
    if (-not [System.IO.File]::Exists($Target)) { return $false }
    $info  = [System.IO.FileInfo]::new($Target)
    $stamp = '{0}|{1}|{2}' -f $info.Length, $info.LastWriteTimeUtc.Ticks, $Want
    if ("$(Get-WVValue $WV.VideoChecks $Id)" -eq $stamp) { return $true }
    if ((Get-WVSha256 $Target) -ne $Want) { return $false }
    try { [Microsoft.Win32.Registry]::SetValue($WV.VideoChecks, $Id, $stamp) } catch { }
    return $true
}
function Sync-WVVideos([scriptblock]$Log = { param($t) }) {
    $dir = [System.IO.Path]::Combine($WV.Dir, 'Videos')
    [void][System.IO.Directory]::CreateDirectory($dir)
    $lock = [System.Threading.Mutex]::new($false, 'Global\TLABootPaperVideos')
    $mine = $false
    try { $mine = $lock.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $mine = $true }
    if (-not $mine) { $lock.Dispose(); return @() }   # already downloading
    try {
        try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }
        $missing = @()
        foreach ($id in $WV.VideoHashes.Keys) {
            $want   = $WV.VideoHashes[$id]
            $target = [System.IO.Path]::Combine($dir, "$id.mp4")
            try { if (Test-WVVideoOk $id $target $want) { continue } } catch { }
            $temp = [System.IO.Path]::Combine($dir, ".$id.download")
            try {
                $client = [System.Net.WebClient]::new()
                try { $client.DownloadFile("$($WV.VideoSource)/$id.mp4", $temp) } finally { $client.Dispose() }
                $got = Get-WVSha256 $temp
                if ($got -ne $want) { throw "the downloaded file doesn't match (SHA-256 $got)" }
                # Replace the old copy. If it's playing right now, try again next time.
                [System.IO.File]::Copy($temp, $target, $true)
                try { [void](Test-WVVideoOk $id $target $want) } catch { }
                & $Log "Downloaded the $id video."
            } catch {
                $missing += $id
                & $Log "Couldn't get the $id video yet: $($_.Exception.Message)"
            } finally {
                try { [System.IO.File]::Delete($temp) } catch { }
            }
        }
        # A video taken off the list (3.3.5: Solarpunk, being redone) is removed, so nobody keeps playing it.
        # If it's playing right now, it goes next time.
        foreach ($file in [System.IO.Directory]::GetFiles($dir, '*.mp4')) {
            $id = [System.IO.Path]::GetFileNameWithoutExtension($file)
            if ($WV.VideoHashes.Contains($id)) { continue }
            try { [System.IO.File]::Delete($file); & $Log "Removed the $id video (no longer offered)." } catch { }
        }
        return $missing
    } finally {
        $lock.ReleaseMutex(); $lock.Dispose()
    }
}

# ---- Intro videos --------------------------------------------------------------------------------
# The video file for this person (or for -Id). 'match' follows their desktop background (a seasonal theme
# has no video: the default background's plays). 'surprise' (4.0): -Pick (when it's about to play) picks a
# different one from last time; otherwise it's the last one picked.
function Get-WVVideoPath([string]$Id, [switch]$Pick) {
    if (-not $Id) { $Id = "$(Get-WVSetting 'Video')" }
    $dir = [System.IO.Path]::Combine($WV.Dir, 'Videos')
    if ($Id -eq 'surprise') {
        $last = "$(Get-WVValue $WV.StateKey 'SurpriseVideo')"
        if ($Pick) {
            $have = @($WV.Videos.Keys | Where-Object { $WV.VideoHashes.Contains($_) -and (Test-WVReleased $_) -and
                      [System.IO.File]::Exists([System.IO.Path]::Combine($dir, "$_.mp4")) })
            $choices = @($have | Where-Object { $_ -ne $last })
            if ($choices.Count -eq 0) { $choices = $have }
            $Id = if ($choices.Count) { $choices[[System.Random]::new().Next($choices.Count)] } else { 'tla' }
            try { [Microsoft.Win32.Registry]::SetValue($WV.StateKey, 'SurpriseVideo', $Id) } catch { }
        } else {
            $Id = if ($WV.VideoHashes.Contains($last)) { $last } else { 'tla' }
        }
    } elseif ($Id -eq 'match') {
        $Id = Get-WVCurrentBackground
        # A seasonal theme plays its own video (4.1), or the default background's until that's downloaded.
        if ($WV.Seasonal.Contains($Id) -and -not [System.IO.File]::Exists([System.IO.Path]::Combine($dir, "$Id.mp4"))) {
            $Id = "$(Get-WVOrgSetting 'Background')"
        }
    }
    # 5.0: in dark mode, the dark version of the video where there is one (and it's downloaded).
    # 5.4: and out on their channel (Anime's dark one starts on Experimental).
    $mode = Get-WVMode
    if ($mode -and $WV.Variants[$Id] -eq $mode -and (Test-WVReleased "$Id-$mode")) {
        $variant = [System.IO.Path]::Combine($dir, "$Id-$mode.mp4")
        if ([System.IO.File]::Exists($variant)) { return $variant }
    }
    $file = [System.IO.Path]::Combine($dir, "$Id.mp4")
    if ([System.IO.File]::Exists($file)) { return $file }
    return [System.IO.Path]::Combine($dir, 'tla.mp4')   # a background with no video of its own
}

# ---- Connect to TLA (5.2.5) ----------------------------------------------------------------------
# A computer Intune doesn't manage misses what TLA sends through it (the TLA new tab page in Chrome and Edge, apps,
# updates and settings: browsers only take a new tab page from a managed computer). TLA BootPaper offers to connect
# it: Settings > Accounts > Access work or school, signed in with the person's TLA account. Managed = it has
# Intune's device certificate (anyone can see the computer's certificates).
function Test-WVIntuneManaged {
    try {
        $store = [System.Security.Cryptography.X509Certificates.X509Store]::new('My', 'LocalMachine')
        $store.Open('ReadOnly, OpenExistingOnly')
        try { return [bool]@($store.Certificates | Where-Object { $_.Issuer -like '*Microsoft Intune MDM Device CA*' }).Count }
        finally { $store.Close() }
    } catch { return $true }   # (can't tell: don't offer it)
}
function Test-WVConnectNeeded { return (Test-WVReleased 'connect') -and -not (Test-WVIntuneManaged) }
$WV.ConnectPage = 'ms-settings:workplace'

# ---- Updating itself (5.4) ------------------------------------------------------------------------
# Intune installs each new version on the computers it manages. The others (set up with the TLA BootPaper
# installer, TLA-BootPaper-Setup-<version>.exe) check windows/latest.json in the organization's GitHub repository
# ({"version", "url", "sha256"}) and run the newer installer: see update.ps1.
$WV.UpdateSource = 'https://raw.githubusercontent.com/ebuskell-source/Default-wallpaper/main/TLA-BootPaper/windows'

# ---- Starting the other scripts, with no console window ---------------------------------------
function Start-WVScript([string]$Script, [string]$Arguments = '') {
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName  = [System.IO.Path]::Combine($env:SystemRoot, 'System32\WindowsPowerShell\v1.0\powershell.exe')
    $psi.Arguments = '-NoProfile -NonInteractive -ExecutionPolicy Bypass -STA -File "{0}" {1}' -f `
                     [System.IO.Path]::Combine($WV.Dir, $Script), $Arguments
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow  = $true
    [void][System.Diagnostics.Process]::Start($psi)
}

# 5.7.0: signing in with the Hub account (signin.ps1).
. ([System.IO.Path]::Combine($PSScriptRoot, 'signin.ps1'))

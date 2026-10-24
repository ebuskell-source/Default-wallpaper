# play-video.ps1
# Runs at every sign-in (the "Welcome Video" scheduled task, as the signed-in user). It:
#   1. puts the person's chosen desktop background back if the desktop isn't showing it,
#   2. plays their intro video (Videos\<id>.mp4) full screen, following their choices in the TLA BootPaper app (settings.ps1)
#      and the organization defaults from install-video.ps1 (see common.ps1 for how they combine),
#   3. shows the release log (whatsnew.ps1) once after each update.
#   4. (5.0) starts session.ps1 in the background: the TLA screensaver, call backgrounds and TLA Care reminders.
# The first sign-in after "Prepare for initial unboxing" (5.0) is different: TLA Classic plays, then the Welcome to
# TLA tour (tour.ps1) instead of the name question and the release log.
# -Force (the app's "Play now" button) just plays the video, skipping all of the above checks.
# 4.2: with -Force, -Preview <id> plays that video instead (the play button on a background's picture in the app),
# and -Mute plays it without sound ("Play without sound").
#
# Speed note: this script uses .NET calls ([System.IO.File]::Exists, [DateTime]::Now, ...) instead of
# cmdlets (Test-Path, Get-Date, Add-Type, New-Object, ...) on purpose. Every cmdlet module PowerShell
# has to load during sign-in adds to the time before the video appears, so keep it that way if you edit.
param([switch]$Force, [string]$Preview, [switch]$Mute)   # (not "$Video": PowerShell names ignore case, and $video is used below)

$timing = @{ ScriptStart = [DateTime]::Now }   # for the timing log written at the end

$ErrorActionPreference = 'Stop'
. ([System.IO.Path]::Combine($PSScriptRoot, 'common.ps1'))

# Everything else this sign-in (5.0): in the background, once the video is out of the way.
function Start-WVSession { if (-not $Force) { try { Start-WVScript 'session.ps1' } catch { } } }

# Unboxing (5.0): the computer was prepared (care-system.ps1) and has restarted since; this person hasn't had the tour.
$unbox = $false; $armedAt = ''
if (-not $Force) {
    $unboxKey = 'HKEY_LOCAL_MACHINE\SOFTWARE\WelcomeVideo\Unbox'
    $unboxState = "$(Get-WVValue $unboxKey 'State')"
    if ($unboxState -eq 'armed' -or $unboxState -eq 'unboxing') {
        $armedAt = "$(Get-WVValue $unboxKey 'ArmedAt')"
        # (a computer that already had BootPaper when 5.0 arrived: once the tour is out on their channel)
        $tourOut = "$(Get-WVValue $unboxKey 'ArmedBy')" -ne 'update' -or (Test-WVReleased 'tour')
        if ($armedAt -and $tourOut -and "$(Get-WVValue $WV.StateKey 'UnboxShown')" -ne $armedAt) {
            $unbox = $unboxState -eq 'unboxing'
            if (-not $unbox) {
                try {   # (only looked up in this rare case: it's a slower call)
                    $boot = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime.ToUniversalTime()
                    $when = [DateTime]::Parse($armedAt, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()
                    $unbox = $boot -gt $when
                } catch { }
            }
        }
    }
}

$VideoPath = Get-WVVideoPath
if ($Force -and $Preview -and $WV.VideoHashes.Contains($Preview)) { $VideoPath = Get-WVVideoPath $Preview }
if ($unbox) { $VideoPath = Get-WVVideoPath 'tla' }   # TLA Classic, whatever they'd picked
$haveVideo = [System.IO.File]::Exists($VideoPath)
$videoKey  = ''
if ($haveVideo) {
    # Identifies this video. A different or new video (other size or date) counts as unseen again.
    $video    = [System.IO.FileInfo]::new($VideoPath)
    $videoKey = '{0}-{1}' -f $video.Length, $video.LastWriteTimeUtc.Ticks
}

$playVideo      = $haveVideo
$showNews       = $false
$needBackground = $false

if ($Force) {
    if (-not $haveVideo) { exit 0 }
} else {
    # Note the Windows build at every sign-in, so "after an update" can tell when it changes.
    $build     = Get-WVWindowsBuild
    $lastBuild = Get-WVValue $WV.StateKey 'LastSeenBuild'
    try { [Microsoft.Win32.Registry]::SetValue($WV.StateKey, 'LastSeenBuild', $build) } catch { }

    if (-not (Test-WVOn 'Enabled')) { $playVideo = $false }
    switch ("$(Get-WVSetting 'PlayWhen')") {
        'OncePerDay' {
            $last = Get-WVLastPlayed
            if ($last -and $last.Date -eq [DateTime]::Today) { $playVideo = $false }
        }
        'AfterUpdate' {
            # No earlier build on record (first sign-in since this was set up): nothing to compare with yet.
            if (-not $lastBuild -or $lastBuild -eq $build) { $playVideo = $false }
        }
        'FirstTime' {
            if ((Get-WVValue $WV.StateKey 'LastPlayedVideo') -eq $videoKey) { $playVideo = $false }
        }
    }

    $showNews       = ("$(Get-WVValue $WV.StateKey 'SeenRelease')" -ne (Get-WVShownRelease))   # (4.3: their channel's release)
    $needBackground = Test-WVBackgroundNeeded
    if ($unbox) {
        # TLA Classic plays (whatever the other settings say), then the tour; no release log this time.
        $playVideo = $haveVideo
        $showNews  = $false
        try {
            [Microsoft.Win32.Registry]::SetValue($WV.StateKey, 'UnboxShown', $armedAt)
            [Microsoft.Win32.Registry]::SetValue($WV.StateKey, 'SeenRelease', (Get-WVShownRelease))
        } catch { }
    }
}

# "Surprise me" (4.0): pick this time's video now that it's going to play.
if ($playVideo -and -not $Preview -and -not $unbox -and "$(Get-WVSetting 'Video')" -eq 'surprise') {
    $VideoPath = Get-WVVideoPath -Pick
    $playVideo = [System.IO.File]::Exists($VideoPath)
}
# Once (4.0): after the video, ask what name to greet them by.
$askName = $playVideo -and -not $Force -and -not $unbox -and (Test-WVUsersCanChange) -and -not (Get-WVValue $WV.StateKey 'NameAsked')

# Background: set in a separate, windowless process. While the video plays, that starts once the video
# is running (so it doesn't slow the start); otherwise it starts right away.
if ($needBackground -and -not $playVideo) {
    try { Start-WVScript 'apply-background.ps1' } catch { }
}

if (-not $playVideo -and -not $showNews -and -not $unbox) { Start-WVSession; exit 0 }

$sessionId = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
function Test-InSession([string]$ProcessName) {
    foreach ($p in [System.Diagnostics.Process]::GetProcessesByName($ProcessName)) {
        if ($p.SessionId -eq $sessionId) { return $true }
    }
    return $false
}
# 5.7.5: Windows sometimes signs in by itself and locks straight away, for example to finish an update after a
# restart ("Use my sign-in info to automatically finish setting up"). The lock screen (LogonUI, which only runs in
# this session while it's locked or still signing in) then covers everything, so the video waits until the person
# unlocks the computer; the quiet hours and greeting below are worked out for then. Up to 20 hours (the "Welcome
# Video" task allows a day); still locked after that: no video this time.
$lockDeadline = [DateTime]::Now.AddHours(20)
while (-not $Force -and (Test-InSession 'LogonUI')) {
    if ([DateTime]::Now -ge $lockDeadline) { Start-WVSession; exit 0 }
    [System.Threading.Thread]::Sleep(1000)
}

$AllowSkip = $Force -or (Test-WVOn 'AllowSkip')   # "Play now" can always be closed early
$Sound     = (Test-WVOn 'Sound') -and -not $Mute
# Quiet hours (4.0): no sound while Do Not Disturb is on, or during the hours they set.
if ($Sound -and $playVideo -and (Test-WVQuietNow)) { $Sound = $false }
$Greeting  = if ($playVideo) { Get-WVGreeting } else { '' }
$GreetingStyle = ''   # (5.5.5: in the style of the video's theme, once that's out on their channel; set below)

# On someone's very first sign-in to a device, wait for the "Hi" / "getting things ready"
# screens to finish so the video isn't hidden behind them. Every other sign-in starts right away.
$deadline = [DateTime]::Now.AddMinutes(10)
while (-not $Force -and [DateTime]::Now -lt $deadline -and (Test-InSession 'FirstLogonAnim')) {
    [System.Threading.Thread]::Sleep(500)
}

foreach ($assembly in 'PresentationFramework', 'PresentationCore', 'WindowsBase') {
    [void][System.Reflection.Assembly]::Load("$assembly, Version=4.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35")
}

if ($showNews -or $askName) {
    try { . ([System.IO.Path]::Combine($PSScriptRoot, 'whatsnew.ps1')) } catch { $showNews = $false; $askName = $false }
}
if ($unbox) {
    try { . ([System.IO.Path]::Combine($PSScriptRoot, 'tour.ps1')) } catch { $unbox = $false }
}

# The Application object lets everything get out of the way if the user signs out or the PC shuts down.
# It keeps running until the video and the release log (if shown) have both closed.
$app = [System.Windows.Application]::new()
$app.ShutdownMode = 'OnExplicitShutdown'

# The Welcome to TLA tour (5.0), which shuts the player down when it closes. Returns $false if it couldn't.
function Show-Tour {
    try {
        $tour = New-WVTourWindow
        $tour.Add_Closed({ $app.Shutdown() })
        $tour.Show()
        return $true
    } catch { return $false }
}

# Opens the release log, which shuts the player down when it closes. Returns $false if it couldn't.
function Show-News {
    try {
        $news = New-WVWhatsNewWindow
        $news.Add_Closed({ $app.Shutdown() })
        $news.Show()
        return $true
    } catch { return $false }
}

# ---- Release log (or the tour) only: the video isn't playing this time -----------------------------
if (-not $playVideo) {
    if ($unbox) {
        try {
            $tour = New-WVTourWindow
            $tour.Add_Closed({ $app.Shutdown() })
            $app.Run($tour) | Out-Null
        } catch { }
        Start-WVSession
        exit 0
    }
    if (-not $showNews) { Start-WVSession; exit 0 }
    try {
        $news = New-WVWhatsNewWindow
        $news.Add_Closed({ $app.Shutdown() })
        $app.Run($news) | Out-Null
    } catch { }
    Start-WVSession
    exit 0
}

# ---- Video ---------------------------------------------------------------------------------------
# Done:    the video window may close.  Played: the video actually started.  Ending: signing out / shutting down.
$state = @{ Done = $false; Played = $false; Ending = $false }
$app.Add_SessionEnding({ $state.Done = $true; $state.Ending = $true })

$window = [System.Windows.Window]::new()
$window.WindowStyle   = 'None'
$window.ResizeMode    = 'NoResize'
$window.WindowState   = 'Maximized'
$window.Topmost       = $true
$window.ShowInTaskbar = $false
$window.Background    = [System.Windows.Media.Brushes]::Black
$window.Cursor        = [System.Windows.Input.Cursors]::None

# Setting Source here (before the window is shown) starts loading the video straight away,
# so the loading overlaps with the window being created.
$player = [System.Windows.Controls.MediaElement]::new()
$player.LoadedBehavior   = 'Manual'
$player.UnloadedBehavior = 'Stop'
$player.Stretch          = 'Uniform'
$player.IsMuted          = -not $Sound
$player.Source           = [System.Uri]::new($VideoPath)
# 5.5.5: the greeting in the style of the video's theme (greeting.ps1). Without a style, or if that can't be set up,
# the classic greeting below.
$themed = $null
if ($Greeting) {
    $GreetingStyle = Get-WVGreetingStyle $VideoPath
    if ($GreetingStyle) {
        try {
            . ([System.IO.Path]::Combine($PSScriptRoot, 'greeting.ps1'))
            $grid = [System.Windows.Controls.Grid]::new()
            [void]$grid.Children.Add($player)
            $themed = New-WVGreeting $grid $Greeting $GreetingStyle ([System.Windows.SystemParameters]::PrimaryScreenWidth) ([System.Windows.SystemParameters]::PrimaryScreenHeight)
            if ($themed) { $window.Content = $grid } else { [void]$grid.Children.Remove($player) }
        } catch {
            $themed = $null
            try { if ($grid) { $grid.Children.Clear() } } catch { }
        }
    }
}
if ($themed) {
    # (in place: the greeting starts with the video)
} elseif ($Greeting) {
    # 'Good morning, Audrey!' low on the picture (clear of the logo) for the first 4.5 seconds, then it fades.
    $grid = [System.Windows.Controls.Grid]::new()
    [void]$grid.Children.Add($player)
    $hello = [System.Windows.Controls.TextBlock]::new()
    $hello.Text                = $Greeting
    $hello.FontFamily          = [System.Windows.Media.FontFamily]::new('Segoe UI Semibold')
    $hello.FontSize            = [Math]::Max(28, [System.Windows.SystemParameters]::PrimaryScreenHeight / 19)
    $hello.Foreground          = [System.Windows.Media.Brushes]::White
    $hello.HorizontalAlignment = 'Center'
    $hello.VerticalAlignment   = 'Bottom'
    $hello.TextAlignment       = 'Center'
    $hello.TextWrapping        = 'Wrap'
    $hello.Margin              = [System.Windows.Thickness]::new(40, 0, 40, [System.Windows.SystemParameters]::PrimaryScreenHeight / 13)
    $hello.Opacity             = 0
    $shadow = [System.Windows.Media.Effects.DropShadowEffect]::new()
    $shadow.BlurRadius = 12; $shadow.ShadowDepth = 2; $shadow.Opacity = 0.85
    $hello.Effect = $shadow
    [void]$grid.Children.Add($hello)
    $window.Content = $grid
} else {
    $window.Content = $player
}

function Close-Video {
    $state.Done = $true
    $window.Close()
}

# Safety net: the window never stays open longer than the video plus 10 seconds (15 minutes max),
# so nobody can get stuck behind it.
$timer = [System.Windows.Threading.DispatcherTimer]::new()
$timer.Interval = [TimeSpan]::FromMinutes(15)
$timer.Add_Tick({ Close-Video })

$player.Add_MediaOpened({
    $timing.VideoOpened = [DateTime]::Now
    $state.Played = $true
    if ($player.NaturalDuration.HasTimeSpan) {
        $timer.Stop()
        $timer.Interval = $player.NaturalDuration.TimeSpan.Add([TimeSpan]::FromSeconds(10))
        $timer.Start()
    }
    if (-not $Force) {   # "Play now" doesn't count as having seen it
        try {
            [Microsoft.Win32.Registry]::SetValue($WV.StateKey, 'LastPlayed', [DateTime]::Now.ToString('o'))
            [Microsoft.Win32.Registry]::SetValue($WV.StateKey, 'LastPlayedVideo', $videoKey)
        } catch { }
    }
    if ($needBackground) {   # ready by the time the video ends
        try { Start-WVScript 'apply-background.ps1' } catch { }
    }
    if ($themed) {
        try { Start-WVGreeting $themed } catch { }
    } elseif ($Greeting) {
        $fadeIn = [System.Windows.Media.Animation.DoubleAnimation]::new(0, 1, [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(500)))
        $fadeIn.BeginTime = [TimeSpan]::FromMilliseconds(300)
        $hello.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $fadeIn)
        # (Script scope: event handlers each run in their own scope.)
        $script:fadeOut = [System.Windows.Threading.DispatcherTimer]::new()
        $script:fadeOut.Interval = [TimeSpan]::FromMilliseconds(4500)
        $script:fadeOut.Add_Tick({
            $script:fadeOut.Stop()
            $out = [System.Windows.Media.Animation.DoubleAnimation]::new(1, 0, [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(700)))
            $hello.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $out)
        })
        $script:fadeOut.Start()
    }
})
$player.Add_MediaEnded({ Close-Video })
$player.Add_MediaFailed({
    if ($needBackground -and -not $state.Played) { try { Start-WVScript 'apply-background.ps1' } catch { } }
    Close-Video   # bad file or missing codec: get out of the way
})

if ($AllowSkip) {
    $window.Add_KeyDown({ param($s, $e) if ($e.Key -eq 'Escape') { Close-Video } })
    $window.Add_MouseDown({ Close-Video })
}

# Block Alt+F4 and "show desktop" until the video is done.
$window.Add_Closing({ param($s, $e) if (-not $state.Done) { $e.Cancel = $true } })
$window.Add_StateChanged({
    if (-not $state.Done -and $window.WindowState -ne 'Maximized') { $window.WindowState = 'Maximized' }
})

$window.Add_Loaded({
    $window.Activate() | Out-Null
    $player.Play()
    $timer.Start()
    $timing.PlayRequested = [DateTime]::Now
})
$window.Add_ContentRendered({ $timing.CoverShown = [DateTime]::Now })
$window.Add_Closed({
    $timer.Stop()
    $player.Close()
    # Unboxing (5.0): the tour. Otherwise once (4.0): ask what name to greet them by. Then, after an update, the
    # release log. Otherwise the player is finished.
    if ($unbox -and -not $state.Ending) {
        if (Show-Tour) { return }
    }
    if ($askName -and -not $state.Ending) {
        try {
            $nameWindow = New-WVNameWindow
            $nameWindow.Add_Closed({
                $newsShown = $false
                if ($showNews -and -not $state.Ending) { $newsShown = Show-News }
                if (-not $newsShown) { $app.Shutdown() }
            })
            $nameWindow.Show()
            return
        } catch { }
    }
    $newsShown = $false
    if ($showNews -and -not $state.Ending) { $newsShown = Show-News }
    if (-not $newsShown) { $app.Shutdown() }
})

$app.Run($window) | Out-Null

if ($Force) { exit 0 }
Start-WVSession

# ---- Timing log ---------------------------------------------------------
# Written after the video, so it never slows it down. One small file per user, replaced each
# sign-in: %LOCALAPPDATA%\WelcomeVideo\last-timing.txt. Times are seconds after Explorer (the
# desktop) started; negative means before the desktop appeared. Safe to delete this block later.
try {
    $taskStarted = [System.Diagnostics.Process]::GetCurrentProcess().StartTime
    $desktop = $null
    foreach ($p in [System.Diagnostics.Process]::GetProcessesByName('explorer')) {
        try {
            if ($p.SessionId -eq $sessionId -and ($null -eq $desktop -or $p.StartTime -lt $desktop)) {
                $desktop = $p.StartTime
            }
        } catch { }
    }
    if ($null -eq $desktop) { $desktop = $taskStarted }

    $playing = $timing.PlayRequested
    if ($timing.VideoOpened -and (-not $playing -or $timing.VideoOpened -gt $playing)) { $playing = $timing.VideoOpened }

    function Format-Offset($when) {
        if (-not $when) { return '     n/a' }
        return '{0,6:+0.0;-0.0} s' -f ($when - $desktop).TotalSeconds
    }
    $lines = @(
        "Sign-in at $($desktop.ToString('yyyy-MM-dd HH:mm:ss')) - seconds after the desktop (explorer.exe) started:"
        "  PowerShell launched by the task  $(Format-Offset $taskStarted)"
        "  script started running           $(Format-Offset $timing.ScriptStart)"
        "  black cover on screen            $(Format-Offset $timing.CoverShown)"
        "  video playing                    $(Format-Offset $playing)"
    )
    $logDir = [System.IO.Path]::Combine($env:LOCALAPPDATA, 'WelcomeVideo')
    [void][System.IO.Directory]::CreateDirectory($logDir)
    [System.IO.File]::WriteAllLines([System.IO.Path]::Combine($logDir, 'last-timing.txt'), [string[]]$lines)
} catch { }

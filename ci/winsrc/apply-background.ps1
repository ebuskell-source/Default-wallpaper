# apply-background.ps1
# Runs as the signed-in person, without a window: from play-video.ps1 at sign-in (only when their desktop
# or lock screen isn't showing their preset) and from the TLA BootPaper app when they pick one (-FromApp).
# Puts their chosen preset (common.ps1 lists them) on their own desktop and their own lock screen:
#   1. asks the "TLA BootPaper Backgrounds" task (lock-backgrounds.ps1, as SYSTEM) to write their desktop
#      policy and, if the lock screen needs it, to lift "Prevent changing lock screen" for a moment,
#   2. sets the desktop once that policy points at the new picture (Windows keeps showing the policy's
#      picture otherwise),
#   3. sets the lock screen (the same call as Settings > Personalization > Lock screen) once it's allowed.
# 4.0.5: the newest request wins. Picking several backgrounds quickly starts one of these for each; they
# take turns, and any that a newer pick has replaced stop without doing anything. Each run uses the
# background saved at that moment, not the one it was started for.
# 4.2: the desktop fits the screen the way they chose (fill, fit or span), and the lock screen can have a
# background of its own. 5.0: each in the picture for their light or dark mode.
# Exit codes: 0 = done (or replaced by a newer pick), 1 = no such preset, 3 = Windows refused one of them.
param([string]$Id, [switch]$FromApp)

$ErrorActionPreference = 'Stop'
. ([System.IO.Path]::Combine($PSScriptRoot, 'common.ps1'))

function Set-State([string]$Name, [string]$Value) {
    try { [Microsoft.Win32.Registry]::SetValue($WV.StateKey, $Name, $Value) } catch { }
}

function Invoke-Apply {
    # The background to show now (the seasonal theme or today's "Surprise me" pick, when that applies).
    $id   = Get-WVCurrentBackground
    $path = Get-WVShownPath $id   # (5.0: the picture for their light or dark mode)
    if (-not $path -or -not [System.IO.File]::Exists($path)) { return 1 }
    $fit   = "$(Get-WVSetting 'WallpaperFit')"
    $style = $WV.FitStyle[$fit]
    # The lock screen (4.2: its own background, if they picked one) gets the copy with the organization's
    # announcement on it, when there is one.
    $lockId   = Get-WVLockBackground
    $lockPath = Get-WVLockScreenPath $lockId
    $failed   = $false
    # A new pick always tries the lock screen (not just once a day, like the retries at sign-in).
    $needLock = if ($FromApp) {
        -not (Test-WVLockScreenLocked) -and "$(Get-WVValue $WV.StateKey 'AppliedLockScreen')" -ne $lockPath
    } else { Test-WVLockScreenNeeded $lockPath }

    # 1. The SYSTEM task. The lock screen request tells it which picture we're about to set.
    if ($needLock) { Set-State 'LockScreenRequest' $lockPath }
    $taskStarted = Start-WVDeviceBackgroundUpdate

    # 2. Desktop. Their "Desktop Wallpaper" policy (written by the task) decides what Windows shows, so wait
    #    (up to a minute) until it points at the new picture, then set it.
    $result = 'desktop: unchanged'
    if (-not (Test-WVBackgroundLocked)) {
        $policyKey = 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Policies\System'
        $deadline  = [DateTime]::Now.AddSeconds(60)
        while ($taskStarted -and [DateTime]::Now -lt $deadline -and
               ("$(Get-WVValue $policyKey 'Wallpaper')" -ne $path -or "$(Get-WVValue $policyKey 'WallpaperStyle')" -ne $WV.FitPolicy[$fit])) {
            [System.Threading.Thread]::Sleep(250)
        }
        if ($FromApp -or "$(Get-WVValue 'HKEY_CURRENT_USER\Control Panel\Desktop' 'WallPaper')" -ne $path -or
            "$(Get-WVValue 'HKEY_CURRENT_USER\Control Panel\Desktop' 'WallpaperStyle')" -ne $style) {
            [Microsoft.Win32.Registry]::SetValue('HKEY_CURRENT_USER\Control Panel\Desktop', 'WallpaperStyle', $style)   # fill / fit / span
            [Microsoft.Win32.Registry]::SetValue('HKEY_CURRENT_USER\Control Panel\Desktop', 'TileWallpaper', '0')
            Add-Type -Namespace WelcomeVideo -Name Native -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, string pvParam, uint fWinIni);
'@
            # SPI_SETDESKWALLPAPER, saved to the profile (SPIF_UPDATEINIFILE) and announced (SPIF_SENDCHANGE).
            if ([WelcomeVideo.Native]::SystemParametersInfo(0x14, 0, $path, 0x3)) {
                Set-State 'AppliedBackground' $id
                $result = "desktop: $id ($fit)"
            } else { $failed = $true; $result = 'desktop: refused' }
            if ("$(Get-WVValue $policyKey 'Wallpaper')" -ne $path) { $result += ' (policy not updated yet)' }
        }
    } else { $result = 'desktop: set by the organization' }

    # 3. Lock screen: wait (up to 2 minutes) for the task to lift "Prevent changing lock screen", then set it.
    if ($needLock) {
        Set-State 'LockScreenAttempt' "$lockPath|$([DateTime]::Today.ToString('yyyy-MM-dd'))"
        $deadline = [DateTime]::Now.AddMinutes(2)
        while ("$(Get-WVValue $WV.LockPolicy 'NoChangingLockScreen')" -eq '1' -and [DateTime]::Now -lt $deadline) {
            [System.Threading.Thread]::Sleep(500)
        }
        try {
            [void][Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime]
            [void][Windows.System.UserProfile.LockScreen,Windows.System.UserProfile,ContentType=WindowsRuntime]
            Add-Type -AssemblyName System.Runtime.WindowsRuntime
            $asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
                $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 }
            $forOperation = ($asTask | Where-Object { $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
            $forAction    = ($asTask | Where-Object { $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction' })[0]
            $getFile = $forOperation.MakeGenericMethod([Windows.Storage.StorageFile]).Invoke(
                $null, @([Windows.Storage.StorageFile]::GetFileFromPathAsync($lockPath)))
            if (-not $getFile.Wait(30000)) { throw 'Timed out opening the picture.' }
            $setImage = $forAction.Invoke($null, @([Windows.System.UserProfile.LockScreen]::SetImageFileAsync($getFile.Result)))
            if (-not $setImage.Wait(30000)) { throw 'Timed out setting the lock screen.' }
            Set-State 'AppliedLockScreen' $lockPath
            $result += "; lock screen: $lockId"
        } catch { $failed = $true; $result += "; lock screen: failed ($($_.Exception.Message))" }
        # Tell the task we're done, so it puts "Prevent changing lock screen" back straight away.
        Set-State 'LockScreenRequest' ''
    }
    # For troubleshooting: what the last run did.
    Set-State 'LastApply' ('{0:yyyy-MM-dd HH:mm:ss} {1}' -f [DateTime]::Now, $result)
    if ($failed) { return 3 }
    return 0
}

# Newest pick wins: take a ticket, wait for our turn, and go on only if no newer pick has come in since.
$ticket = [guid]::NewGuid().ToString('N')
Set-State 'ApplyTicket' $ticket
$turn = [System.Threading.Mutex]::new($false, 'Local\TLABootPaperApply')
$mine = $false
try { $mine = $turn.WaitOne([TimeSpan]::FromMinutes(5)) } catch [System.Threading.AbandonedMutexException] { $mine = $true }
$code = 0
try {
    if ("$(Get-WVValue $WV.StateKey 'ApplyTicket')" -eq $ticket) { $code = Invoke-Apply }
} finally {
    if ($mine) { $turn.ReleaseMutex() }
    $turn.Dispose()
}
exit $code

# theme-check.ps1
# Runs as SYSTEM every 5 minutes (the "TLA BootPaper Theme" task, 5.0). Only reads the registry, so it's quick:
# when the person signed in switched between light and dark mode (or their pick or the day changed) and their
# desktop or lock screen isn't showing the right picture, it starts the "TLA BootPaper Backgrounds" task
# (lock-backgrounds.ps1), which puts it right in their session. Never starts it twice for the same thing within
# 30 minutes, so a picture Windows won't take can't keep it busy.

$ErrorActionPreference = 'Stop'
. ([System.IO.Path]::Combine($PSScriptRoot, 'common.ps1'))

# The person at the screen: the last one to sign in, if they still are (their registry is loaded).
$sid = "$(Get-WVValue 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI' 'LastLoggedOnUserSID')"
if ($sid -notmatch '^S-1-(5-21|12-1)-[\d-]+$') { exit 0 }
$hive = [Microsoft.Win32.Registry]::Users.OpenSubKey("$sid\Software")
if (-not $hive) { exit 0 }
$hive.Close()

$WV.UserKey  = "HKEY_USERS\$sid\Software\WelcomeVideo"
$WV.StateKey = "HKEY_USERS\$sid\Software\WelcomeVideo\State"
$WV.ThemeKey = "HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"

$path = Get-WVShownPath (Get-WVCurrentBackground)
if (-not $path -or -not [System.IO.File]::Exists($path)) { exit 0 }
$stale = $false
$policy = "$(Get-WVValue "HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Policies\System" 'Wallpaper')"
if ((Test-WVOurPicture $policy) -and "$(Get-WVValue "HKEY_USERS\$sid\Control Panel\Desktop" 'WallPaper')" -ne $path) { $stale = $true }
$lockPath = Get-WVLockScreenPath (Get-WVLockBackground)
if (-not $stale -and $lockPath -and -not (Test-WVLockScreenLocked)) {
    $today = [DateTime]::Today.ToString('yyyy-MM-dd')
    $stale = "$(Get-WVValue $WV.StateKey 'AppliedLockScreen')" -ne $lockPath -and
             "$(Get-WVValue $WV.StateKey 'LockScreenAttempt')" -ne "$lockPath|$today"
}
if (-not $stale) { exit 0 }

$what = "$sid|$path|$lockPath"
$last = "$(Get-WVValue $WV.DeviceKey 'ThemeCheckKick')"
$at   = [DateTime]::MinValue
[void][DateTime]::TryParse("$(Get-WVValue $WV.DeviceKey 'ThemeCheckKickAt')", [Globalization.CultureInfo]::InvariantCulture, 'None', [ref]$at)
if ($last -eq $what -and [DateTime]::Now -lt $at.AddMinutes(30)) { exit 0 }
[Microsoft.Win32.Registry]::SetValue($WV.DeviceKey, 'ThemeCheckKick', $what)
[Microsoft.Win32.Registry]::SetValue($WV.DeviceKey, 'ThemeCheckKickAt', [DateTime]::Now.ToString('s'))
[void](Start-WVDeviceBackgroundUpdate)
exit 0

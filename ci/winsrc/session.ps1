# session.ps1
# Runs as the person who signed in, without a window, started by play-video.ps1 once the intro video is done (5.0).
# Also started by the TLA BootPaper app when a setting below changes (-Only Screensaver or -Only Calls).
#   1. The TLA screensaver: Windows' own Photos screen saver, showing the TLA backgrounds (Wide\*.jpg, made by
#      install-video.ps1). Set when the person has no screen saver of their own, or turns it on in the app. Never
#      when an organization policy sets the screen saver.
#   2. TLA call backgrounds in Microsoft Teams (the new Teams): copied into Teams' own "Uploads" folder under fixed
#      names, so they show in Teams' background effects. Removed again if the person turns them off.
#   3. A TLA Care reminder, a few minutes later, if something needs doing (care.ps1).
#   5.7.0: before that, a reminder to sign in again 7 and 3 days before their sign-in runs out (or, while they're not
#   signed in, at most once a week). Its "Sign in" button opens the app and starts signing in.
param([ValidateSet('', 'Screensaver', 'Calls')][string]$Only = '')

$ErrorActionPreference = 'Stop'
. ([System.IO.Path]::Combine($PSScriptRoot, 'common.ps1'))

function Set-State([string]$Name, [string]$Value) { try { [Microsoft.Win32.Registry]::SetValue($WV.StateKey, $Name, $Value) } catch { } }
function Write-SessionLog([string]$Text) {
    try {
        $dir = [System.IO.Path]::Combine($env:LOCALAPPDATA, 'TLA BootPaper')
        [void][System.IO.Directory]::CreateDirectory($dir)
        $file = [System.IO.Path]::Combine($dir, 'session.log')
        if ([System.IO.File]::Exists($file) -and ([System.IO.FileInfo]::new($file)).Length -gt 65536) { [System.IO.File]::Delete($file) }
        [System.IO.File]::AppendAllText($file, ('{0:yyyy-MM-dd HH:mm:ss} {1}{2}' -f [DateTime]::Now, $Text, [Environment]::NewLine))
    } catch { }
}

# ---- 1. The TLA screensaver ---------------------------------------------------------------------------
$WV.WideDir = [System.IO.Path]::Combine($WV.Dir, 'Wide')

# The folder as Windows' shell names it (a PIDL), which is how the Photos screen saver stores its folder; and
# SystemParametersInfo, to tell Windows the screen saver changed.
function Initialize-WVShellApi {
    if (-not ('WelcomeVideo.Shell' -as [type])) {
        Add-Type -Namespace WelcomeVideo -Name Shell -MemberDefinition @'
[DllImport("shell32.dll", CharSet = CharSet.Unicode)]
static extern int SHParseDisplayName(string name, IntPtr bindingContext, out IntPtr pidl, uint sfgaoIn, out uint sfgaoOut);
[DllImport("shell32.dll")] static extern uint ILGetSize(IntPtr pidl);
[DllImport("ole32.dll")] static extern void CoTaskMemFree(IntPtr pv);
public static string Pidl(string path) {
    IntPtr pidl; uint attrs;
    int hr = SHParseDisplayName(path, IntPtr.Zero, out pidl, 0, out attrs);
    if (hr != 0) throw new System.ComponentModel.Win32Exception(hr);
    try {
        int size = (int)ILGetSize(pidl);
        byte[] bytes = new byte[size];
        Marshal.Copy(pidl, bytes, 0, size);
        return Convert.ToBase64String(bytes);
    } finally { CoTaskMemFree(pidl); }
}
[DllImport("user32.dll", SetLastError = true)]
public static extern bool SystemParametersInfo(uint action, uint param, IntPtr pv, uint winIni);
'@
    }
}
function Get-WVFolderPidl([string]$Path) {
    Initialize-WVShellApi
    return [WelcomeVideo.Shell]::Pidl($Path)
}

# 'set', 'off', 'policy' (the organization sets it), 'theirs' (they chose another one), 'unavailable'.
function Update-WVScreensaver {
    $desktop  = 'HKEY_CURRENT_USER\Control Panel\Desktop'
    $policy   = 'HKEY_CURRENT_USER\Software\Policies\Microsoft\Windows\Control Panel\Desktop'
    $photoKey = 'HKEY_CURRENT_USER\Software\Microsoft\Windows Photo Viewer\Slideshow\Screensaver'
    $scr      = [System.IO.Path]::Combine($env:SystemRoot, 'System32', 'PhotoScreensaver.scr')
    if ((Get-WVValue $policy 'SCRNSAVE.EXE') -or $null -ne (Get-WVValue $policy 'ScreenSaveActive')) { return 'policy' }
    Initialize-WVShellApi
    $want     = (Test-WVReleased 'screensaver') -and (Test-WVOn 'Screensaver')
    $explicit = "$(Get-WVValue $WV.UserKey 'Screensaver')" -eq '1'   # they turned it on in the app themselves
    $current  = "$(Get-WVValue $desktop 'SCRNSAVE.EXE')"
    $active   = "$(Get-WVValue $desktop 'ScreenSaveActive')" -eq '1'
    $isPhotos = $current -and [System.IO.Path]::GetFileName($current) -ieq 'PhotoScreensaver.scr'
    $setByUs  = "$(Get-WVValue $WV.StateKey 'ScreensaverSet')" -eq '1'

    if (-not $want) {
        if ($setByUs -and $isPhotos) {
            [Microsoft.Win32.Registry]::SetValue($desktop, 'SCRNSAVE.EXE', '')
            [Microsoft.Win32.Registry]::SetValue($desktop, 'ScreenSaveActive', '0')
            [void][WelcomeVideo.Shell]::SystemParametersInfo(0x0011, 0, [IntPtr]::Zero, 0x3)   # SPI_SETSCREENSAVEACTIVE off
        }
        Set-State 'ScreensaverSet' '0'
        return 'off'
    }
    # Someone else's screen saver (or they switched ours off in Windows' settings): theirs stays, unless they
    # turn the TLA screensaver on in the app.
    if (-not $explicit -and $current -and $active -and -not ($isPhotos -and $setByUs)) { Set-State 'ScreensaverSet' '0'; return 'theirs' }
    if (-not $explicit -and $setByUs -and (-not $current -or -not $active)) { return 'theirs' }
    if (-not [System.IO.File]::Exists($scr) -or -not [System.IO.Directory]::Exists($WV.WideDir)) { return 'unavailable' }

    $pidl = Get-WVFolderPidl $WV.WideDir
    [Microsoft.Win32.Registry]::SetValue($photoKey, 'EncryptedPIDL', $pidl)
    [Microsoft.Win32.Registry]::SetValue($photoKey, 'Shuffle', 1, [Microsoft.Win32.RegistryValueKind]::DWord)
    [Microsoft.Win32.Registry]::SetValue($photoKey, 'Speed', 0, [Microsoft.Win32.RegistryValueKind]::DWord)   # slow
    $changed = -not ($isPhotos -and $active)
    [Microsoft.Win32.Registry]::SetValue($desktop, 'SCRNSAVE.EXE', $scr)
    [Microsoft.Win32.Registry]::SetValue($desktop, 'ScreenSaveActive', '1')
    # After 5 minutes, unless they chose a time themselves (Windows' own default is 15).
    $timeout = 0; [void][int]::TryParse("$(Get-WVValue $desktop 'ScreenSaveTimeOut')", [ref]$timeout)
    if ($changed -and ($timeout -le 0 -or $timeout -ge 900)) {
        [Microsoft.Win32.Registry]::SetValue($desktop, 'ScreenSaveTimeOut', '300')
        [void][WelcomeVideo.Shell]::SystemParametersInfo(0x000F, 300, [IntPtr]::Zero, 0x3)   # SPI_SETSCREENSAVETIMEOUT
    }
    [void][WelcomeVideo.Shell]::SystemParametersInfo(0x0011, 1, [IntPtr]::Zero, 0x3)        # SPI_SETSCREENSAVEACTIVE on
    Set-State 'ScreensaverSet' '1'
    if ($changed) { Write-SessionLog 'TLA screensaver set.' }
    return 'set'
}

# ---- 2. TLA call backgrounds in Teams -------------------------------------------------------------------
# A fixed name for each picture (a GUID made from its name), so they're copied once and replaced, never doubled.
function Get-WVCallGuid([string]$Name) {
    $md5 = [System.Security.Cryptography.MD5]::Create()
    try { $bytes = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes("TLA BootPaper call background|$Name")) } finally { $md5.Dispose() }
    $bytes[6] = ($bytes[6] -band 0x0F) -bor 0x30   # a version 3 (name-based) GUID
    $bytes[8] = ($bytes[8] -band 0x3F) -bor 0x80
    $hex = -join ($bytes | ForEach-Object { $_.ToString('x2') })
    return '{0}-{1}-{2}-{3}-{4}' -f $hex.Substring(0, 8), $hex.Substring(8, 4), $hex.Substring(12, 4), $hex.Substring(16, 4), $hex.Substring(20, 12)
}

# The pictures this person gets: every background out on their channel, in both its light and dark picture.
function Get-WVCallPictures {
    $list = [System.Collections.Generic.List[string]]::new()
    foreach ($id in $WV.Backgrounds.Keys) {
        if (-not (Test-WVReleased $id)) { continue }
        $list.Add($id)
        if ($WV.Variants.Contains($id) -and (Test-WVReleased 'lightdark')) { $list.Add("$id-$($WV.Variants[$id])") }
    }
    return $list.ToArray()
}

# 'set', 'off', 'no-teams'.
function Update-WVCallBackgrounds {
    $teams = [System.IO.Path]::Combine($env:LOCALAPPDATA, 'Packages', 'MSTeams_8wekyb3d8bbwe')
    if (-not [System.IO.Directory]::Exists($teams)) { return 'no-teams' }
    $uploads = [System.IO.Path]::Combine($teams, 'LocalCache', 'Microsoft', 'MSTeams', 'Backgrounds', 'Uploads')
    $thumbs  = [System.IO.Path]::Combine($WV.Dir, 'WideThumbs')
    $want    = (Test-WVReleased 'calls') -and (Test-WVOn 'CallBackgrounds')
    $placed  = @("$(Get-WVValue $WV.StateKey 'CallBackgroundFiles')".Split(';') | Where-Object { $_ })
    $keep    = @{}
    if ($want) {
        [void][System.IO.Directory]::CreateDirectory($uploads)
        $added = 0
        foreach ($name in Get-WVCallPictures) {
            $src   = [System.IO.Path]::Combine($WV.WideDir, "$name.jpg")
            $thumb = [System.IO.Path]::Combine($thumbs, "$name.jpg")
            if (-not [System.IO.File]::Exists($src) -or -not [System.IO.File]::Exists($thumb)) { continue }
            $guid = Get-WVCallGuid $name
            $keep[$guid] = $true
            $dst = [System.IO.Path]::Combine($uploads, "$guid.jpg")
            try {
                if (-not [System.IO.File]::Exists($dst) -or ([System.IO.FileInfo]::new($dst)).Length -ne ([System.IO.FileInfo]::new($src)).Length) {
                    [System.IO.File]::Copy($src, $dst, $true)
                    [System.IO.File]::Copy($thumb, [System.IO.Path]::Combine($uploads, "$($guid)_thumb.jpg"), $true)
                    $added++
                }
            } catch { }
        }
        if ($added) { Write-SessionLog "Added $added TLA call backgrounds to Teams." }
    }
    # Ours that are no longer wanted (turned off, or a background taken away).
    foreach ($guid in $placed) {
        if ($keep.Contains($guid)) { continue }
        foreach ($f in "$guid.jpg", "$($guid)_thumb.jpg") {
            try { [System.IO.File]::Delete([System.IO.Path]::Combine($uploads, $f)) } catch { }
        }
    }
    Set-State 'CallBackgroundFiles' (@($keep.Keys) -join ';')
    if ($want) { return 'set' } else { return 'off' }
}

# ---- Run ------------------------------------------------------------------------------------------------
if (-not $Only) { [System.Threading.Thread]::Sleep([TimeSpan]::FromSeconds(20)) }   # (let sign-in settle first)
if ($Only -ne 'Calls') {
    try { $r = Update-WVScreensaver; Set-State 'ScreensaverStatus' $r } catch { Write-SessionLog "Screensaver: $($_.Exception.Message)" }
}
if ($Only -ne 'Screensaver') {
    try { $r = Update-WVCallBackgrounds; Set-State 'CallBackgroundStatus' $r } catch { Write-SessionLog "Call backgrounds: $($_.Exception.Message)" }
}
if ($Only) { exit 0 }

# ---- 5.7.0: signing in (again) ---------------------------------------------------------------------------
function Show-WVSignInReminder([string]$Title, [string]$Text) {
    foreach ($assembly in 'PresentationFramework', 'PresentationCore', 'WindowsBase') {
        [void][System.Reflection.Assembly]::Load("$assembly, Version=4.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35")
    }
    $w = [System.Windows.Markup.XamlReader]::Parse(@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="TLA BootPaper" Width="500" SizeToContent="Height" ResizeMode="NoResize" Topmost="True"
        WindowStartupLocation="CenterScreen" FontFamily="Segoe UI" FontSize="14" Background="White">
  <StackPanel Margin="24,20,24,18">
    <TextBlock x:Name="Heading" FontSize="18" FontWeight="SemiBold" TextWrapping="Wrap"/>
    <TextBlock x:Name="Body" TextWrapping="Wrap" Margin="0,8,0,18" Foreground="#3B3B3B"/>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
      <Button x:Name="Later" Content="Later" MinWidth="90" Padding="12,5" Margin="0,0,8,0" IsCancel="True"/>
      <Button x:Name="Go" Content="Sign in" MinWidth="90" Padding="12,5" IsDefault="True" Foreground="White"
              Background="#0F6CBD" BorderBrush="#0F6CBD"/>
    </StackPanel>
  </StackPanel>
</Window>
'@)
    $w.FindName('Heading').Text = $Title
    $w.FindName('Body').Text = $Text
    $w.FindName('Go').Add_Click({ $w.DialogResult = $true })
    return [bool]$w.ShowDialog()
}
$signinNote = $null
try { $signinNote = Get-WVSignInReminder } catch { Write-SessionLog "Sign-in reminder: $($_.Exception.Message)" }
if ($signinNote) {
    $go = $false
    try { $go = Show-WVSignInReminder $signinNote[0] $signinNote[1] } catch { Write-SessionLog "Sign-in reminder: $($_.Exception.Message)" }
    Write-SessionLog "Sign-in reminder: $($signinNote[0]) ($(if ($go) { 'signing in' } else { 'later' }))."
    if ($go) { try { Start-WVScript 'settings.ps1' '-SignIn' } catch { } }
}

# ---- 3. A TLA Care reminder, once sign-in has settled ---------------------------------------------------
if (-not (Test-WVReleased 'care') -or -not (Test-WVOn 'CareReminders')) { exit 0 }
[System.Threading.Thread]::Sleep([TimeSpan]::FromMinutes(3))
foreach ($assembly in 'PresentationFramework', 'PresentationCore', 'WindowsBase') {
    [void][System.Reflection.Assembly]::Load("$assembly, Version=4.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35")
}
. ([System.IO.Path]::Combine($PSScriptRoot, 'report.ps1'))
. ([System.IO.Path]::Combine($PSScriptRoot, 'care.ps1'))
$check = $null
try { $check = Get-WVNudge } catch { Write-SessionLog "TLA Care reminder: $($_.Exception.Message)" }
if (-not $check) { exit 0 }
Write-SessionLog "TLA Care reminder: $($check.Id) ($($check.Status))."
$app = [System.Windows.Application]::new()
$app.ShutdownMode = 'OnLastWindowClose'
$nudge = New-WVNudgeWindow $check
[void]$app.Run($nudge)
exit 0

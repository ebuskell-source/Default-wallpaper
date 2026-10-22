# care-system.ps1
# Runs as SYSTEM from the "TLA Care" scheduled task (5.0, created by install-video.ps1): at startup, a couple of
# minutes after each sign-in, every day at lunchtime, and whenever TLA Care asks (anyone signed in may start the
# task, but it only ever does one of a fixed list of things).
#   - Notes what only SYSTEM can see, for the TLA Care window: when this PC last checked in with Intune, and
#     whether the person signed in has face or fingerprint sign-in set up (HKLM\SOFTWARE\WelcomeVideo\Care).
#   - Does what the person asked for (their State\CareRequest, if made in the last 10 minutes):
#       cleanup  old temporary files (Windows', and everyone's own, more than 7 days old), old error reports and the
#                Delivery Optimization cache. Never anyone's documents, downloads or recycle bin.
#       audio    starts or restarts the sound services, looks for new hardware, restarts sound devices that report
#                a problem. No drivers are installed or removed.
#       sync     asks Intune to check in now.
#       unbox    "Prepare for initial unboxing": only while this PC has never been prepared. Marks it, then shuts
#                down. The next sign-in plays TLA Classic and the Welcome to TLA tour (play-video.ps1).
#   - By itself: the same cleanup when storage is under 10% free (at most once a day), starts the sound service if
#     it has stopped, and asks Intune to check in if it hasn't for 3 days (at most once a day).
# The answer to a request goes in Care\LastResult as "<request>|<when asked>|<what happened>".

$ErrorActionPreference = 'Stop'
. ([System.IO.Path]::Combine($PSScriptRoot, 'common.ps1'))

$CareKey  = 'HKEY_LOCAL_MACHINE\SOFTWARE\WelcomeVideo\Care'
$UnboxKey = 'HKEY_LOCAL_MACHINE\SOFTWARE\WelcomeVideo\Unbox'
$log = [System.IO.Path]::Combine($WV.Dir, 'care.log')
function Write-Log([string]$Text) {
    try {
        if ([System.IO.File]::Exists($log) -and ([System.IO.FileInfo]::new($log)).Length -gt 65536) { [System.IO.File]::Delete($log) }
        [System.IO.File]::AppendAllText($log, ('{0:yyyy-MM-dd HH:mm:ss} {1}{2}' -f [DateTime]::Now, $Text, [Environment]::NewLine))
    } catch { }
}
function Set-Value($Key, $Name, $Value) { [Microsoft.Win32.Registry]::SetValue($Key, $Name, "$Value") }
function Get-FreeSpace {
    try { return [System.IO.DriveInfo]::new("$($env:SystemDrive)".TrimEnd(':')).AvailableFreeSpace } catch { return 0L }
}
function ConvertFrom-Stamp([string]$Text) {
    $t = [DateTime]::MinValue
    if ($Text -and [DateTime]::TryParse($Text, [Globalization.CultureInfo]::InvariantCulture,
                                         [Globalization.DateTimeStyles]::RoundtripKind, [ref]$t)) { return $t.ToUniversalTime() }
    return $null
}
$bootUtc = $null
try { $bootUtc = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop).LastBootUpTime.ToUniversalTime() } catch { }

# The people signed in (their registry is loaded), and the one at the screen.
$signedIn = @()
try { $signedIn = @([Microsoft.Win32.Registry]::Users.GetSubKeyNames() | Where-Object { $_ -match '^S-1-(5-21|12-1)-[\d-]+$' }) } catch { }
$console = "$(Get-WVValue 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI' 'LastLoggedOnUserSID')"
if ($signedIn -notcontains $console) { $console = '' }

# ---- What only SYSTEM can see -------------------------------------------------------------------------
# Intune's last successful check-in ("20261014T181530Z"), from the management account's connection record.
function Get-IntuneLastSync {
    $best = $null
    try {
        $accounts = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SOFTWARE\Microsoft\Provisioning\OMADM\Accounts')
        if ($accounts) {
            foreach ($name in $accounts.GetSubKeyNames()) {
                $info = $accounts.OpenSubKey("$name\Protected\ConnInfo")
                if (-not $info) { continue }
                $raw = "$($info.GetValue('ServerLastSuccessTime'))"; $info.Close()
                $t = [DateTime]::MinValue
                if ($raw -and [DateTime]::TryParseExact($raw, "yyyyMMdd'T'HHmmss'Z'", [Globalization.CultureInfo]::InvariantCulture,
                        [Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal, [ref]$t)) {
                    if (-not $best -or $t -gt $best) { $best = $t }
                }
            }
            $accounts.Close()
        }
    } catch { }
    return $best
}
function Start-IntuneSync {
    $started = $false
    try {
        $service = New-Object -ComObject 'Schedule.Service'
        $service.Connect()
        foreach ($folder in $service.GetFolder('\Microsoft\Windows\EnterpriseMgmt').GetFolders(0)) {
            foreach ($task in $folder.GetTasks(1)) {
                if ($task.Name -eq 'PushLaunch') { [void]$task.Run($null); $started = $true }
            }
        }
    } catch { }
    return $started
}

$lastSync = Get-IntuneLastSync
if ($lastSync) { Set-Value $CareKey 'IntuneLastSync' $lastSync.ToString('o') }
foreach ($sid in $signedIn) {
    $enrolled = 0
    try { $enrolled = [int]"0$(Get-WVValue "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WinBio\AccountInfo\$sid" 'EnrolledFactors')" } catch { }
    Set-Value "$CareKey\Hello" $sid $(if ($enrolled -ne 0) { '1' } else { '0' })
}
Set-Value $CareKey 'LastRun' ([DateTime]::UtcNow.ToString('o'))

# ---- The fixes -----------------------------------------------------------------------------------------
function Remove-OldFiles([string]$Dir, [int]$Days) {
    $freed = 0L
    if (-not $Dir -or -not [System.IO.Directory]::Exists($Dir)) { return 0L }
    $cutoff = [DateTime]::Now.AddDays(-$Days)
    try {
        foreach ($file in [System.IO.Directory]::EnumerateFiles($Dir, '*', 'AllDirectories')) {
            try {
                $info = [System.IO.FileInfo]::new($file)
                if ($info.LastWriteTime -lt $cutoff -and $info.LastAccessTime -lt $cutoff) {
                    $size = $info.Length; $info.Delete(); $freed += $size
                }
            } catch { }
        }
    } catch { }
    return $freed
}
function Invoke-Cleanup {
    $before = Get-FreeSpace
    [void](Remove-OldFiles ([System.IO.Path]::Combine($env:SystemRoot, 'Temp')) 7)
    # Everyone's own temporary files (profiles on this PC).
    try {
        $list = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList')
        foreach ($name in $list.GetSubKeyNames()) {
            if ($name -notmatch '^S-1-(5-21|12-1)-[\d-]+$') { continue }
            $p = $list.OpenSubKey($name)
            $profileDir = "$($p.GetValue('ProfileImagePath'))"; $p.Close()
            if ($profileDir) { [void](Remove-OldFiles ([System.IO.Path]::Combine($profileDir, 'AppData', 'Local', 'Temp')) 7) }
        }
        $list.Close()
    } catch { }
    foreach ($dir in 'ReportArchive', 'ReportQueue') {
        [void](Remove-OldFiles ([System.IO.Path]::Combine($env:ProgramData, 'Microsoft', 'Windows', 'WER', $dir)) 3)
    }
    try { Delete-DeliveryOptimizationCache -Force -ErrorAction Stop | Out-Null } catch { Write-Log "Delivery Optimization cache: $($_.Exception.Message)" }
    $freed = [Math]::Max(0, (Get-FreeSpace) - $before)
    Write-Log ('Cleanup freed {0:0.0} GB.' -f ($freed / 1GB))
    return $freed
}
function Invoke-AudioFix {
    $done = @()
    foreach ($name in 'AudioEndpointBuilder', 'Audiosrv') {
        try {
            $svc = Get-Service -Name $name -ErrorAction Stop
            if ("$($svc.StartType)" -eq 'Disabled') { Set-Service -Name $name -StartupType Automatic }
            if ("$($svc.Status)" -ne 'Running') { Start-Service -Name $name; $done += "started $name" }
        } catch { Write-Log "Sound service $($name): $($_.Exception.Message)" }
    }
    try { & "$env:SystemRoot\System32\pnputil.exe" /scan-devices | Out-Null; $done += 'looked for new hardware' } catch { }
    # Sound devices that report a problem (but have a driver: code 28 means none, which a restart can't fix).
    try {
        $bad = @(Get-CimInstance -ClassName Win32_PnPEntity -ErrorAction Stop `
                    -Filter "(PNPClass = 'MEDIA' OR PNPClass = 'AudioEndpoint') AND ConfigManagerErrorCode <> 0 AND ConfigManagerErrorCode <> 22 AND ConfigManagerErrorCode <> 28 AND ConfigManagerErrorCode <> 45")
        foreach ($d in $bad) {
            & "$env:SystemRoot\System32\pnputil.exe" /restart-device "$($d.PNPDeviceID)" | Out-Null
            $done += "restarted $($d.Name)"
        }
        if ($bad.Count) { Restart-Service -Name 'Audiosrv' -Force -ErrorAction SilentlyContinue }
    } catch { }
    Write-Log "Sound fix: $(if ($done) { $done -join ', ' } else { 'nothing needed' })."
    return $done
}

# ---- Requests ------------------------------------------------------------------------------------------
$request = ''; $requestAt = ''
if ($console) {
    $state = "HKEY_USERS\$console\Software\WelcomeVideo\State"
    $request   = "$(Get-WVValue $state 'CareRequest')"
    $requestAt = "$(Get-WVValue $state 'CareRequestAt')"
    if ($request) {
        Set-Value $state 'CareRequest' ''   # used up, whatever happens next
        $when = ConvertFrom-Stamp $requestAt
        if ('cleanup', 'audio', 'sync', 'unbox' -notcontains $request -or -not $when -or $when -lt [DateTime]::UtcNow.AddMinutes(-10)) {
            Write-Log "Ignored request '$request'."
            $request = ''
        }
    }
}
function Set-Result([string]$Text) { Set-Value $CareKey 'LastResult' "$request|$requestAt|$Text" }

switch ($request) {
    'cleanup' {
        $freed = Invoke-Cleanup
        Set-Result $(if ($freed -ge 100MB) { 'Freed {0:0.#} GB.' -f ($freed / 1GB) } else { 'Done. There wasn''t much to clear: the rest is your own files and apps.' })
    }
    'audio' {
        $done = @(Invoke-AudioFix)
        Set-Result $(if (@($done | Where-Object { $_ -like 'started *' -or $_ -like 'restarted *' }).Count) {
                         'Done: the sound service and devices were restarted. If there''s still no sound, report the problem.' }
                     else { 'Done: the sound service is running and TLA Care looked for the speakers. If there''s still no sound, report the problem.' })
    }
    'sync' {
        Set-Result $(if (Start-IntuneSync) { 'Checking in now. New apps and settings can take a few minutes to arrive.' }
                     else { 'This computer couldn''t start a check-in. Report the problem if it keeps happening.' })
    }
    'unbox' {
        if ("$(Get-WVValue $UnboxKey 'State')" -eq 'ready') {
            Set-Value $UnboxKey 'State' 'armed'
            Set-Value $UnboxKey 'ArmedAt' ([DateTime]::UtcNow.ToString('o'))
            Set-Value $UnboxKey 'ArmedBy' $console
            Write-Log "Prepared for unboxing by $console; shutting down."
            Set-Result 'Shutting down.'
            & "$env:SystemRoot\System32\shutdown.exe" /s /t 5 /c 'TLA BootPaper is getting this computer ready for its new owner.' | Out-Null
            exit 0
        } else {
            Set-Result 'This computer has already been prepared for unboxing.'
        }
    }
}

# ---- By itself ------------------------------------------------------------------------------------------
$today = [DateTime]::Today.ToString('yyyy-MM-dd')
try {
    $drive = [System.IO.DriveInfo]::new("$($env:SystemDrive)".TrimEnd(':'))
    if ($drive.TotalSize -gt 0 -and $drive.AvailableFreeSpace / $drive.TotalSize -lt 0.10 -and
        "$(Get-WVValue $CareKey 'AutoCleanupDay')" -ne $today -and $request -ne 'cleanup') {
        Set-Value $CareKey 'AutoCleanupDay' $today
        Write-Log 'Storage under 10% free: cleaning up.'
        [void](Invoke-Cleanup)
    }
} catch { }
try {
    $svc = Get-Service -Name 'Audiosrv' -ErrorAction Stop
    if ("$($svc.Status)" -ne 'Running' -and "$($svc.StartType)" -ne 'Disabled' -and $request -ne 'audio') {
        Start-Service -Name 'Audiosrv'
        Write-Log 'The sound service had stopped; started it.'
    }
} catch { }
if ($lastSync -and $lastSync -lt [DateTime]::UtcNow.AddDays(-3) -and "$(Get-WVValue $CareKey 'AutoSyncDay')" -ne $today -and $request -ne 'sync') {
    Set-Value $CareKey 'AutoSyncDay' $today
    if (Start-IntuneSync) { Write-Log 'No Intune check-in for 3 days: asked for one.' }
}

# ---- Unboxing: from "prepared" to done ------------------------------------------------------------------
$unbox = "$(Get-WVValue $UnboxKey 'State')"
if ($unbox -eq 'armed' -or $unbox -eq 'unboxing') {
    $armedAt = "$(Get-WVValue $UnboxKey 'ArmedAt')"
    $when = ConvertFrom-Stamp $armedAt
    if ($unbox -eq 'armed' -and $when -and $bootUtc -and $bootUtc -gt $when) {
        Set-Value $UnboxKey 'State' 'unboxing'; $unbox = 'unboxing'
        Write-Log 'First startup after preparing: the Welcome to TLA tour plays at the next sign-in.'
    }
    # Done once someone has had the tour.
    foreach ($sid in $signedIn) {
        if ("$(Get-WVValue "HKEY_USERS\$sid\Software\WelcomeVideo\State" 'UnboxShown')" -eq $armedAt -and $armedAt) {
            Set-Value $UnboxKey 'State' 'done'
            Set-Value $UnboxKey 'DoneAt' ([DateTime]::UtcNow.ToString('o'))
            Write-Log "Unboxing done ($sid had the tour)."
            break
        }
    }
}
exit 0

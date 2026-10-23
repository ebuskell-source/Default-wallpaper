# care.ps1
# TLA Care (5.0): checks the things that most often go wrong on a school computer and fixes what it can, with one
# click. Opened from the TLA BootPaper app, from "TLA Care" in the Start menu (settings.ps1 -Care) and from its
# reminders. Dot-sourced after common.ps1 and report.ps1.
#
# What needs an administrator (cleaning Windows' own temporary files, restarting the sound service, checking in
# with Intune, preparing for unboxing) is done by the "TLA Care" task, which runs as SYSTEM (care-system.ps1).
# Anyone may start that task, but all it takes from them is one word from a fixed list (State\CareRequest), so it
# can't be made to do anything else. It also writes what only it can see (when the PC last checked in with
# Intune, whether face or fingerprint sign-in is set up) to HKLM\SOFTWARE\WelcomeVideo\Care for this window.

$WV.CareKey      = 'HKEY_LOCAL_MACHINE\SOFTWARE\WelcomeVideo\Care'
$WV.CareTask     = 'TLA Care'
$WV.CareRequests = 'cleanup', 'audio', 'sync', 'unbox', 'signin'   # (5.7.0: signin)

function Format-WVCareAgo([TimeSpan]$Span) {
    if ($Span.TotalMinutes -lt 2) { return 'just now' }
    if ($Span.TotalHours -lt 1)   { return '{0} minutes ago' -f [int][Math]::Floor($Span.TotalMinutes) }
    if ($Span.TotalHours -lt 24)  { $h = [int][Math]::Floor($Span.TotalHours); return "$h hour$(if ($h -ne 1) { 's' }) ago" }
    $d = [int][Math]::Floor($Span.TotalDays)
    if ($d -eq 1) { return 'yesterday' }
    return "$d days ago"
}

function ConvertFrom-WVCareTime([string]$Text) {
    $t = [DateTime]::MinValue
    if ($Text -and [DateTime]::TryParse($Text, [Globalization.CultureInfo]::InvariantCulture,
                                         [Globalization.DateTimeStyles]::RoundtripKind, [ref]$t)) { return $t.ToLocalTime() }
    return $null
}

function New-WVCareCheck([string]$Id, [string]$Title, [string]$Status, [string]$Detail, [string]$Action = '', [string]$ActionText = '') {
    return [pscustomobject]@{ Id = $Id; Title = $Title; Status = $Status; Detail = $Detail; Action = $Action; ActionText = $ActionText }
}

function Get-WVMySid {
    try { return [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value } catch { return '' }
}

# ---- The checks --------------------------------------------------------------------------------------
# Each returns one row: Status ok | info | warn | bad, or nothing when it doesn't apply to this computer.
function Get-WVRestartCheck {
    $boot = $null
    try { $boot = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop).LastBootUpTime } catch { }
    if (-not $boot) { return }
    $days = ([DateTime]::Now - $boot).TotalDays
    $pending = $false
    foreach ($k in 'SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
                   'SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
        try { $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($k); if ($key) { $pending = $true; $key.Close() } } catch { }
    }
    $ago = Format-WVCareAgo ([DateTime]::Now - $boot)
    # (With Windows' fast startup, shutting down doesn't count: only Restart starts Windows afresh.)
    if ($days -ge 14) {
        return New-WVCareCheck 'restart' 'Restart your computer' 'bad' "It hasn't restarted in $([int][Math]::Floor($days)) days. A restart keeps it fast and finishes updates. (Shutting down isn't the same: choose Restart.)" 'restart' 'Restart now'
    }
    if ($pending -and $days -ge 1) {
        return New-WVCareCheck 'restart' 'Updates are waiting for a restart' 'warn' "Restart to finish installing them. Last restart: $ago." 'restart' 'Restart now'
    }
    if ($days -ge 7) {
        return New-WVCareCheck 'restart' 'Time for a restart' 'warn' "It's been running for $([int][Math]::Floor($days)) days. A restart keeps it fast. (Shutting down isn't the same: choose Restart.)" 'restart' 'Restart now'
    }
    $text = if ($pending) { "Restarted $ago. Updates will finish at the next restart." } else { "Restarted $ago." }
    return New-WVCareCheck 'restart' 'Restart' 'ok' $text
}

function Get-WVStorageCheck {
    try { $drive = [System.IO.DriveInfo]::new("$($env:SystemDrive)".TrimEnd(':')) } catch { return }
    $free = $drive.AvailableFreeSpace / 1GB
    $total = $drive.TotalSize / 1GB
    if ($total -le 0) { return }
    $pct = 100 * $free / $total
    $text = '{0:0.#} GB free of {1:0} GB.' -f $free, $total
    if ($pct -lt 5 -or $free -lt 5) {
        return New-WVCareCheck 'storage' 'Almost out of storage' 'bad' "$text Apps and updates need room to work." 'cleanup' 'Free up space'
    }
    if ($pct -lt 10 -or $free -lt 15) {
        return New-WVCareCheck 'storage' 'Storage is getting full' 'warn' $text 'cleanup' 'Free up space'
    }
    return New-WVCareCheck 'storage' 'Storage' 'ok' $text
}

function Get-WVInternetCheck {
    $ok = $false
    try {
        $req = [System.Net.WebRequest]::Create('http://www.msftconnecttest.com/connecttest.txt')
        $req.Timeout = 4000
        $resp = $req.GetResponse()
        try {
            $reader = [System.IO.StreamReader]::new($resp.GetResponseStream())
            $ok = $reader.ReadToEnd().Trim() -eq 'Microsoft Connect Test'
            $reader.Dispose()
        } finally { $resp.Close() }
    } catch { }
    $wifi = ''
    try {
        $out = & "$env:SystemRoot\System32\netsh.exe" wlan show interfaces 2>$null
        $line = $out | Where-Object { $_ -match '^\s*SSID\s*:\s*(.+)$' } | Select-Object -First 1
        if ($line -and $line -match ':\s*(.+)$') { $wifi = $Matches[1].Trim() }
    } catch { }
    if ($ok) {
        return New-WVCareCheck 'internet' 'Internet' 'ok' $(if ($wifi) { "Connected through $wifi." } else { 'Connected.' })
    }
    $text = if ($wifi) { "Connected to $wifi, but the internet doesn't answer. If a sign-in page should appear, open a browser." }
            else { 'Not connected. Check that Wi-Fi is on and pick your network.' }
    return New-WVCareCheck 'internet' "Can't reach the internet" 'bad' $text 'wifi' 'Wi-Fi settings'
}

function Get-WVProblemDevices {
    # Devices whose driver isn't working: not ones that are just unplugged (45) or turned off on purpose (22).
    try {
        return @(Get-CimInstance -ClassName Win32_PnPEntity -ErrorAction Stop `
                    -Filter 'ConfigManagerErrorCode <> 0 AND ConfigManagerErrorCode <> 45 AND ConfigManagerErrorCode <> 22')
    } catch { return @() }
}

function Get-WVSoundCheck([object[]]$Problems) {
    $svc = $null
    try { $svc = Get-Service -Name 'Audiosrv' -ErrorAction Stop } catch { }
    $audioBad = @($Problems | Where-Object { $_ -and ("$($_.PNPClass)" -eq 'MEDIA' -or "$($_.PNPClass)" -eq 'AudioEndpoint') })
    $outputs = 0
    try {
        $outputs = @(Get-CimInstance -ClassName Win32_PnPEntity -ErrorAction Stop -Filter "PNPClass = 'AudioEndpoint' AND ConfigManagerErrorCode = 0").Count
    } catch { $outputs = -1 }
    if ($svc -and "$($svc.Status)" -ne 'Running') {
        return New-WVCareCheck 'sound' "Sound isn't working" 'bad' "Windows' sound service has stopped." 'audio' 'Fix sound'
    }
    if ($audioBad.Count) {
        $names = ($audioBad | Select-Object -First 2 | ForEach-Object { "$($_.Name)".Trim() }) -join ', '
        return New-WVCareCheck 'sound' 'Sound has a problem' 'bad' "Not working: $names." 'audio' 'Fix sound'
    }
    if ($outputs -eq 0) {
        return New-WVCareCheck 'sound' 'No speakers or headphones found' 'warn' 'Plug in headphones, or let TLA Care look for the speakers.' 'audio' 'Fix sound'
    }
    return New-WVCareCheck 'sound' 'Sound' 'ok' 'Working.'
}

function Get-WVDevicesCheck([object[]]$Problems) {
    $other = @($Problems | Where-Object { $_ -and "$($_.PNPClass)" -ne 'MEDIA' -and "$($_.PNPClass)" -ne 'AudioEndpoint' })
    if ($other.Count) {
        $names = ($other | Select-Object -First 3 | ForEach-Object { "$($_.Name)".Trim() }) -join ', '
        $what  = if ($other.Count -eq 1) { "Something isn't working" } else { "$($other.Count) things aren't working" }
        return New-WVCareCheck 'devices' $what 'warn' "$names. Tell the helpdesk: the details go with your report." 'report' 'Report it'
    }
    return New-WVCareCheck 'devices' 'Hardware' 'ok' 'Everything is working.'
}

function Get-WVBatteryCheck {
    $battery = $null
    try { $battery = @(Get-CimInstance -ClassName Win32_Battery -ErrorAction Stop)[0] } catch { }
    if (-not $battery) { return }
    $health = $null
    try {
        $full   = @(Get-CimInstance -Namespace 'root\wmi' -ClassName BatteryFullChargedCapacity -ErrorAction Stop)[0].FullChargedCapacity
        $design = @(Get-CimInstance -Namespace 'root\wmi' -ClassName BatteryStaticData -ErrorAction Stop)[0].DesignedCapacity
        if ($full -and $design) { $health = [Math]::Min(100, 100 * $full / $design) }
    } catch { }
    if ($null -ne $health -and $health -lt 50) {
        return New-WVCareCheck 'battery' 'The battery is wearing out' 'warn' ("It holds about {0:0}% of its charge when new. If it doesn't last the school day, tell the helpdesk." -f $health) 'report' 'Report it'
    }
    $text = '{0}% charged' -f $battery.EstimatedChargeRemaining
    if ($null -ne $health) { $text += ('; battery health {0:0}%.' -f $health) } else { $text += '.' }
    return New-WVCareCheck 'battery' 'Battery' 'ok' $text
}

function Get-WVManagementCheck {
    # Only for PCs Intune manages (they have its certificate).
    $managed = $false
    try {
        $store = [System.Security.Cryptography.X509Certificates.X509Store]::new('My', 'LocalMachine')
        $store.Open('ReadOnly, OpenExistingOnly')
        try { $managed = [bool]@($store.Certificates | Where-Object { $_.Issuer -like '*Microsoft Intune MDM Device CA*' }).Count }
        finally { $store.Close() }
    } catch { }
    if (-not $managed) {
        # 5.2.5: Connect to TLA, on computers Intune doesn't manage.
        if (Test-WVConnectNeeded) {
            return New-WVCareCheck 'connect' 'Connect this computer to TLA' 'info' "It's missing what TLA sends, like the TLA new tab page in Chrome and Edge, apps and updates. Sign in with your TLA account under Access work or school." 'connect' 'Connect'
        }
        return
    }
    $last = ConvertFrom-WVCareTime "$(Get-WVValue $WV.CareKey 'IntuneLastSync')"
    if (-not $last) { return }
    $ago = [DateTime]::Now - $last
    if ($ago.TotalDays -ge 7) {
        return New-WVCareCheck 'management' "Hasn't checked in with TLA" 'warn' "Last time: $(Format-WVCareAgo $ago). TLA sends apps, updates and settings when it checks in." 'sync' 'Check in now'
    }
    return New-WVCareCheck 'management' 'Connected to TLA' 'ok' "Checked in $(Format-WVCareAgo $ago)."
}

function Get-WVHelloCheck {
    $reader = $false
    try { $reader = [bool]@(Get-CimInstance -ClassName Win32_PnPEntity -ErrorAction Stop -Filter "PNPClass = 'Biometric' AND ConfigManagerErrorCode = 0").Count } catch { }
    if (-not $reader) { return }
    $sid = Get-WVMySid
    $enrolled = "$(Get-WVValue "$($WV.CareKey)\Hello" $sid)"
    if ($enrolled -eq '1') { return New-WVCareCheck 'hello' 'Face or fingerprint sign-in' 'ok' "You're set up." }
    return New-WVCareCheck 'hello' 'Sign in with your face or fingerprint' 'info' "This computer can do it, and it's faster than typing your password." 'hello' 'Set it up'
}

function Get-WVBootPaperCheck {
    $dir = [System.IO.Path]::Combine($WV.Dir, 'Videos')
    $missing = @($WV.VideoHashes.Keys | Where-Object { -not [System.IO.File]::Exists([System.IO.Path]::Combine($dir, "$_.mp4")) })
    if ($missing.Count) {
        $what = if ($missing.Count -eq 1) { '1 intro video is' } else { "$($missing.Count) intro videos are" }
        return New-WVCareCheck 'bootpaper' 'TLA BootPaper' 'info' "$what still downloading." 'videos' 'Download now'
    }
    return New-WVCareCheck 'bootpaper' 'TLA BootPaper' 'ok' 'Backgrounds and intro videos are all in place.'
}

# All the checks, in the order they show. -Quick: only the ones worth a reminder (no network test).
function Get-WVCareChecks([switch]$Quick) {
    $rows = [System.Collections.Generic.List[object]]::new()
    $problems = Get-WVProblemDevices
    foreach ($check in @(
        { Get-WVRestartCheck }, { Get-WVStorageCheck },
        $(if (-not $Quick) { { Get-WVInternetCheck } }),
        { Get-WVSoundCheck $problems },
        $(if (-not $Quick) { { Get-WVDevicesCheck $problems } }),
        { Get-WVBatteryCheck }, { Get-WVManagementCheck }, { Get-WVHelloCheck }, { Get-WVBootPaperCheck })) {
        if (-not $check) { continue }
        try { foreach ($row in @(& $check)) { if ($row) { $rows.Add($row) } } } catch { }
    }
    return $rows.ToArray()
}

# ---- Fixes ---------------------------------------------------------------------------------------------
# Asks the SYSTEM task to do one thing from the list. Returns the time asked (to match its answer), or $null.
function Invoke-WVCareRequest([string]$Action) {
    if ($WV.CareRequests -notcontains $Action) { return $null }
    $at = [DateTime]::UtcNow.ToString('o')
    try {
        [Microsoft.Win32.Registry]::SetValue($WV.StateKey, 'CareRequest', $Action)
        [Microsoft.Win32.Registry]::SetValue($WV.StateKey, 'CareRequestAt', $at)
        $service = New-Object -ComObject 'Schedule.Service'
        $service.Connect()
        [void]$service.GetFolder('\').GetTask($WV.CareTask).Run($null)
        return $at
    } catch { return $null }
}

# The SYSTEM task's answer to a request: @{ Done; Text } once it has answered, $null before.
function Get-WVCareResult([string]$Action, [string]$At) {
    $r = "$(Get-WVValue $WV.CareKey 'LastResult')"
    $parts = $r.Split([char]'|', 3)
    if ($parts.Count -lt 3 -or $parts[0] -ne $Action -or $parts[1] -ne $At) { return $null }
    return @{ Done = $true; Text = $parts[2] }
}

# Deletes the person's own temporary files that are more than two days old (anything in use is skipped).
function Clear-WVMyTempFiles {
    $freed = 0L
    $cutoff = [DateTime]::Now.AddDays(-2)
    try {
        foreach ($file in [System.IO.Directory]::EnumerateFiles([System.IO.Path]::GetTempPath(), '*', 'AllDirectories')) {
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

function Start-WVSettingsPage([string]$Uri) { try { [void][System.Diagnostics.Process]::Start($Uri) } catch { } }

# ---- The window ----------------------------------------------------------------------------------------
$careXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="TLA Care" Width="660" SizeToContent="Height" ResizeMode="CanMinimize"
        WindowStartupLocation="CenterScreen" ShowInTaskbar="True"
        FontFamily="Segoe UI" FontSize="14" Background="White" Foreground="#1F1F1F">
  <Window.Resources>
    <Style x:Key="ButtonBase" TargetType="Button">
      <Setter Property="Padding" Value="16,6"/>
      <Setter Property="MinWidth" Value="96"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="Bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="4" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Bd" Property="Opacity" Value="0.9"/></Trigger>
              <Trigger Property="IsPressed" Value="True"><Setter TargetName="Bd" Property="Opacity" Value="0.75"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter TargetName="Bd" Property="Opacity" Value="0.45"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="Primary" TargetType="Button" BasedOn="{StaticResource ButtonBase}">
      <Setter Property="Background" Value="#0F6CBD"/>
      <Setter Property="BorderBrush" Value="#0F6CBD"/>
      <Setter Property="Foreground" Value="White"/>
    </Style>
    <Style x:Key="Secondary" TargetType="Button" BasedOn="{StaticResource ButtonBase}">
      <Setter Property="Background" Value="#F5F5F5"/>
      <Setter Property="BorderBrush" Value="#C8C8C8"/>
      <Setter Property="Foreground" Value="#1F1F1F"/>
    </Style>
  </Window.Resources>

  <StackPanel Margin="28,24,28,22">
    <StackPanel Orientation="Horizontal" Margin="0,0,0,16">
      <Image x:Name="Logo" Width="44" Height="44" Margin="0,0,14,0" VerticalAlignment="Center"/>
      <StackPanel VerticalAlignment="Center">
        <TextBlock Text="TLA Care" FontSize="22" FontWeight="SemiBold"/>
        <TextBlock x:Name="Subtitle" Text="Checking your computer..." Foreground="#5F6368" Margin="0,2,0,0"/>
      </StackPanel>
    </StackPanel>

    <Border x:Name="Summary" Background="#F3F3F3" BorderBrush="#E0E0E0" BorderThickness="1" CornerRadius="6" Padding="14,10" Margin="0,0,0,14">
      <TextBlock x:Name="SummaryText" Text="One moment..." FontSize="15" FontWeight="SemiBold" TextWrapping="Wrap"/>
    </Border>

    <ScrollViewer x:Name="Scroller" MaxHeight="470" VerticalScrollBarVisibility="Auto">
      <StackPanel x:Name="Rows" Margin="0,0,4,0"/>
    </ScrollViewer>

    <Grid Margin="0,18,0,0">
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Left">
        <Button x:Name="CheckAgain" Content="Check again" Style="{StaticResource Secondary}" Margin="0,0,8,0"/>
        <Button x:Name="CareReport" Content="Report a problem" Style="{StaticResource Secondary}"/>
      </StackPanel>
      <Button x:Name="CareClose" Content="Close" Style="{StaticResource Primary}" HorizontalAlignment="Right" IsCancel="True"/>
    </Grid>
  </StackPanel>
</Window>
'@

function Get-WVLogoFrame {
    try {
        $iconBytes = [System.IO.File]::ReadAllBytes([System.IO.Path]::Combine($WV.Dir, 'welcome-video.ico'))
        $decoder = [System.Windows.Media.Imaging.BitmapDecoder]::Create([System.IO.MemoryStream]::new($iconBytes), 'None', 'OnLoad')
        $best = $null
        foreach ($frame in $decoder.Frames) { if (-not $best -or $frame.PixelWidth -gt $best.PixelWidth) { $best = $frame } }
        return $best
    } catch { return $null }
}

# Colours and symbols for each status.
$WV.CareLook = @{
    ok   = @{ Fill = '#107C10'; Glyph = [string][char]0x2713 }   # check mark
    info = @{ Fill = '#0F6CBD'; Glyph = 'i' }
    warn = @{ Fill = '#C27C0E'; Glyph = '!' }
    bad  = @{ Fill = '#C42B1C'; Glyph = [string][char]0x2715 }   # cross
}

# One row: a coloured badge, the title and detail, and the fix button.
function New-WVCareRow($Check) {
    $row = [System.Windows.Controls.Grid]::new()
    $row.Margin = '0,0,0,12'
    foreach ($w in 'Auto', '*', 'Auto') {
        $col = [System.Windows.Controls.ColumnDefinition]::new()
        $col.Width = [System.Windows.GridLengthConverter]::new().ConvertFromString($w)
        [void]$row.ColumnDefinitions.Add($col)
    }
    $look = $WV.CareLook[$Check.Status]
    $badge = [System.Windows.Controls.Border]::new()
    $badge.Width = 26; $badge.Height = 26; $badge.CornerRadius = [System.Windows.CornerRadius]::new(13)
    $badge.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString($look.Fill)
    $badge.VerticalAlignment = 'Top'; $badge.Margin = '0,1,12,0'
    $glyph = [System.Windows.Controls.TextBlock]::new()
    $glyph.Text = $look.Glyph; $glyph.Foreground = [System.Windows.Media.Brushes]::White
    $glyph.FontWeight = 'Bold'; $glyph.FontSize = 13
    $glyph.HorizontalAlignment = 'Center'; $glyph.VerticalAlignment = 'Center'
    $badge.Child = $glyph
    [System.Windows.Controls.Grid]::SetColumn($badge, 0)
    [void]$row.Children.Add($badge)

    $text = [System.Windows.Controls.StackPanel]::new()
    $title = [System.Windows.Controls.TextBlock]::new()
    $title.Text = $Check.Title; $title.FontWeight = 'SemiBold'; $title.TextWrapping = 'Wrap'
    $detail = [System.Windows.Controls.TextBlock]::new()
    $detail.Text = $Check.Detail; $detail.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#5F6368')
    $detail.TextWrapping = 'Wrap'; $detail.Margin = '0,2,0,0'
    [void]$text.Children.Add($title)
    [void]$text.Children.Add($detail)
    [System.Windows.Controls.Grid]::SetColumn($text, 1)
    [void]$row.Children.Add($text)

    if ($Check.Action) {
        $button = [System.Windows.Controls.Button]::new()
        $button.Content = $Check.ActionText
        $button.Style = $script:CareWindow.FindResource($(if ($Check.Status -eq 'ok' -or $Check.Status -eq 'info') { 'Secondary' } else { 'Primary' }))
        $button.VerticalAlignment = 'Top'; $button.Margin = '12,0,0,0'
        $button.Tag = $Check
        $button.Add_Click({ param($s, $e) Invoke-WVCareAction $s })
        [System.Windows.Controls.Grid]::SetColumn($button, 2)
        [void]$row.Children.Add($button)
    }
    $row.Tag = @{ Detail = $detail; Check = $Check }
    return $row
}

function Show-WVCareChecks {
    $win = $script:CareWindow
    $rows = $win.FindName('Rows')
    [void]$rows.Children.Clear()
    $checks = @(Get-WVCareChecks)
    foreach ($check in $checks) { [void]$rows.Children.Add((New-WVCareRow $check)) }
    $bad  = @($checks | Where-Object { $_.Status -eq 'bad' }).Count
    $warn = @($checks | Where-Object { $_.Status -eq 'warn' }).Count
    $summary = $win.FindName('Summary'); $text = $win.FindName('SummaryText')
    $brush = [System.Windows.Media.BrushConverter]::new()
    if ($bad) {
        $text.Text = if ($bad + $warn -eq 1) { 'One thing needs your attention.' } else { "$($bad + $warn) things need your attention." }
        $summary.Background = $brush.ConvertFromString('#FDE7E9'); $summary.BorderBrush = $brush.ConvertFromString('#F1BBBC')
    } elseif ($warn) {
        $text.Text = if ($warn -eq 1) { 'One thing to look at.' } else { "$warn things to look at." }
        $summary.Background = $brush.ConvertFromString('#FFF4CE'); $summary.BorderBrush = $brush.ConvertFromString('#F2D57C')
    } else {
        $text.Text = "Your computer is in good shape. $([char]0x2713)"
        $summary.Background = $brush.ConvertFromString('#DFF6DD'); $summary.BorderBrush = $brush.ConvertFromString('#9FD89F')
    }
    $win.FindName('Subtitle').Text = 'Checked {0:h:mm tt}' -f [DateTime]::Now
}

# Runs a row's fix. Fixes that need SYSTEM are asked for, then the row is updated when the answer comes.
function Invoke-WVCareAction($Button) {
    $check  = $Button.Tag
    $detail = $Button.Parent.Tag.Detail
    switch ($check.Action) {
        'restart' {
            $answer = [System.Windows.MessageBox]::Show(
                "Restart your computer now?`n`nSave your work first: open apps will close.", 'TLA Care', 'YesNo', 'Question')
            if ("$answer" -eq 'Yes') {
                try { Start-Process -FilePath "$env:SystemRoot\System32\shutdown.exe" -ArgumentList '/r', '/t', '0' -WindowStyle Hidden }
                catch { $detail.Text = "Couldn't restart: $($_.Exception.Message)" }
            }
            return
        }
        'wifi'    { Start-WVSettingsPage 'ms-settings:network-wifi'; return }
        'hello'   { Start-WVSettingsPage 'ms-settings:signinoptions'; return }
        'connect' { Start-WVSettingsPage $WV.ConnectPage; return }   # (5.2.5)
        'report'  {
            try {
                $reportWindow = New-WVReportWindow
                $reportWindow.Owner = $script:CareWindow
                $reportWindow.WindowStartupLocation = 'CenterOwner'
                [void]$reportWindow.ShowDialog()
            } catch { }
            return
        }
        'videos'  {
            try {
                $service = New-Object -ComObject 'Schedule.Service'
                $service.Connect()
                [void]$service.GetFolder('\').GetTask('TLA BootPaper Videos').Run($null)
                $detail.Text = 'Downloading now. Check again in a few minutes.'
            } catch { $detail.Text = "Couldn't start the download: $($_.Exception.Message)" }
            $Button.IsEnabled = $false
            return
        }
    }
    # cleanup, audio, sync: the SYSTEM task.
    $freed = 0L
    if ($check.Action -eq 'cleanup') { $freed = Clear-WVMyTempFiles }
    $at = Invoke-WVCareRequest $check.Action
    if (-not $at) {
        $detail.Text = "TLA Care couldn't start the fix. Try again, or report the problem."
        return
    }
    $Button.IsEnabled = $false
    $Button.Content = 'Working...'
    $detail.Text = switch ($check.Action) {
        'cleanup' { 'Clearing out old temporary files and caches. This can take a few minutes.' }
        'audio'   { 'Restarting the sound service and looking for the speakers...' }
        'sync'    { 'Checking in with TLA...' }
    }
    $timer = [System.Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromSeconds(2)
    $timer.Tag = @{ Button = $Button; Detail = $detail; Action = $check.Action; At = $at; Freed = $freed
                    Until = [DateTime]::Now.AddMinutes(10) }
    $timer.Add_Tick({
        param($s, $e)
        $wait = $s.Tag
        $result = Get-WVCareResult $wait.Action $wait.At
        if (-not $result -and [DateTime]::Now -lt $wait.Until) { return }
        $s.Stop()
        $wait.Button.Content = 'Done'
        if ($result) {
            $text = $result.Text
            if ($wait.Freed -gt 0) { $text = ('{0} (and {1:0.#} GB of your own temporary files)' -f $text.TrimEnd('.'), ($wait.Freed / 1GB)) + '.' }
            $wait.Detail.Text = $text
        } else {
            $wait.Detail.Text = "It's taking longer than usual. Check again later."
        }
    })
    $timer.Start()
}

function New-WVCareWindow {
    $win = [System.Windows.Markup.XamlReader]::Parse($careXaml)
    $script:CareWindow = $win
    $logo = Get-WVLogoFrame
    if ($logo) { $win.FindName('Logo').Source = $logo; $win.Icon = $logo }
    $win.FindName('CheckAgain').Add_Click({ param($s, $e) Show-WVCareChecks })
    $win.FindName('CareReport').Add_Click({
        param($s, $e)
        try {
            $reportWindow = New-WVReportWindow
            $reportWindow.Owner = $script:CareWindow
            $reportWindow.WindowStartupLocation = 'CenterOwner'
            [void]$reportWindow.ShowDialog()
        } catch { }
    })
    $win.FindName('CareClose').Add_Click({ param($s, $e) $script:CareWindow.Close() })
    # The checks take a few seconds (the internet test can take up to 4): run them once the window shows.
    $win.Add_ContentRendered({ param($s, $e) Show-WVCareChecks })
    return $win
}

# ---- Reminders (5.0) -----------------------------------------------------------------------------------
# A small TLA Care card in the corner after sign-in, for what's worth doing something about: a restart that's
# overdue or waiting for updates, storage running out, sound not working. At most one a day, never for the same
# thing two days running unless it got worse, and not at all if the person turned reminders off.
$nudgeXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="TLA Care" Width="400" SizeToContent="Height" WindowStyle="None" ResizeMode="NoResize"
        AllowsTransparency="True" Background="Transparent" Topmost="True" ShowInTaskbar="False" ShowActivated="False"
        FontFamily="Segoe UI" FontSize="14">
  <Border Margin="12" CornerRadius="8" Background="White" BorderBrush="#D0D0D0" BorderThickness="1" Padding="16,14">
    <Border.Effect>
      <DropShadowEffect BlurRadius="16" ShadowDepth="2" Opacity="0.28"/>
    </Border.Effect>
    <StackPanel>
      <DockPanel Margin="0,0,0,8">
        <Image x:Name="NudgeLogo" Width="22" Height="22" Margin="0,0,8,0" DockPanel.Dock="Left"/>
        <Button x:Name="NudgeClose" DockPanel.Dock="Right" Content="&#x2715;" Background="Transparent" BorderThickness="0"
                Foreground="#5F6368" Padding="6,0" Cursor="Hand" ToolTip="Close"/>
        <TextBlock Text="TLA Care" FontWeight="SemiBold" Foreground="#5F6368" VerticalAlignment="Center"/>
      </DockPanel>
      <TextBlock x:Name="NudgeTitle" FontSize="16" FontWeight="SemiBold" TextWrapping="Wrap" Foreground="#1F1F1F"/>
      <TextBlock x:Name="NudgeText" TextWrapping="Wrap" Foreground="#5F6368" Margin="0,4,0,12"/>
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
        <Button x:Name="NudgeLater" Content="Later" Padding="14,5" Margin="0,0,8,0" MinWidth="80" Cursor="Hand"/>
        <Button x:Name="NudgeAct" Padding="14,5" MinWidth="80" Background="#0F6CBD" Foreground="White" BorderBrush="#0F6CBD" Cursor="Hand"/>
      </StackPanel>
    </StackPanel>
  </Border>
</Window>
'@

# The check worth a reminder now, or $null.
function Get-WVNudge {
    if (-not (Test-WVReleased 'care') -or -not (Test-WVOn 'CareReminders')) { return $null }
    $today = [DateTime]::Today.ToString('yyyy-MM-dd')
    if ("$(Get-WVValue $WV.StateKey 'CareNudgeDay')" -eq $today) { return $null }
    $checks = @(Get-WVCareChecks -Quick | Where-Object { $_.Id -in 'restart', 'storage', 'sound' -and $_.Status -in 'warn', 'bad' })
    if (-not $checks.Count) { return $null }
    $pick = @($checks | Where-Object { $_.Status -eq 'bad' }) + @($checks | Where-Object { $_.Status -eq 'warn' }) | Select-Object -First 1
    # The same reminder as yesterday only if it's now worse (e.g. storage went from "getting full" to "almost out").
    $yesterday = [DateTime]::Today.AddDays(-1).ToString('yyyy-MM-dd')
    if ("$(Get-WVValue $WV.StateKey 'CareNudgeDay')" -eq $yesterday -and
        "$(Get-WVValue $WV.StateKey 'CareNudgeFor')" -eq "$($pick.Id)|$($pick.Status)") { return $null }
    return $pick
}

function New-WVNudgeWindow($Check) {
    $win = [System.Windows.Markup.XamlReader]::Parse($nudgeXaml)
    $script:NudgeWindow = $win
    $logo = Get-WVLogoFrame
    if ($logo) { $win.FindName('NudgeLogo').Source = $logo }
    $win.FindName('NudgeTitle').Text = $Check.Title
    $win.FindName('NudgeText').Text  = $Check.Detail
    $act = $win.FindName('NudgeAct')
    $act.Content = if ($Check.Action -eq 'restart') { 'Restart now' } else { 'Open TLA Care' }
    $act.Tag = $Check
    $act.Add_Click({
        param($s, $e)
        $check = $s.Tag
        if ($check.Action -eq 'restart') {
            $answer = [System.Windows.MessageBox]::Show(
                "Restart your computer now?`n`nSave your work first: open apps will close.", 'TLA Care', 'YesNo', 'Question')
            if ("$answer" -ne 'Yes') { return }
            try { Start-Process -FilePath "$env:SystemRoot\System32\shutdown.exe" -ArgumentList '/r', '/t', '0' -WindowStyle Hidden } catch { }
        } else {
            try { Start-WVScript 'settings.ps1' '-Care' } catch { }
        }
        $script:NudgeWindow.Close()
    })
    $win.FindName('NudgeLater').Add_Click({ param($s, $e) $script:NudgeWindow.Close() })
    $win.FindName('NudgeClose').Add_Click({ param($s, $e) $script:NudgeWindow.Close() })
    # Bottom right, above the taskbar; goes away by itself after a minute.
    $win.Add_Loaded({
        param($s, $e)
        $area = [System.Windows.SystemParameters]::WorkArea
        $s.Left = $area.Right - $s.ActualWidth - 8
        $s.Top  = $area.Bottom - $s.ActualHeight - 8
    })
    $timer = [System.Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromSeconds(60)
    $timer.Add_Tick({ param($s, $e) $s.Stop(); try { $script:NudgeWindow.Close() } catch { } })
    $timer.Start()
    try {
        [Microsoft.Win32.Registry]::SetValue($WV.StateKey, 'CareNudgeDay', [DateTime]::Today.ToString('yyyy-MM-dd'))
        [Microsoft.Win32.Registry]::SetValue($WV.StateKey, 'CareNudgeFor', "$($Check.Id)|$($Check.Status)")
    } catch { }
    return $win
}

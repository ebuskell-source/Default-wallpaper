# report.ps1
# "Report a problem" (4.3): a short form that starts an email to the helpdesk with what's wrong and this PC's
# details already filled in (model, serial number, Windows version, last restart, battery, storage, Wi-Fi,
# devices with a driver problem, and the Intune device ID), so the helpdesk can find the PC and help faster.
# Nothing is sent by itself: the person checks the email in their mail app and sends it. Opened from the
# TLA BootPaper app (settings.ps1) and from "Report a problem to TLA" in the Start menu (settings.ps1 -Report).

$WV.Helpdesk = 'helpdesk@schoolathome.ca'
$WV.ReportTopics = [ordered]@{
    'sound'    = 'Sound, speakers or microphone'
    'screen'   = 'Screen or display'
    'keyboard' = 'Keyboard, mouse or touchpad'
    'wifi'     = 'Wi-Fi or internet'
    'battery'  = 'Battery or charging'
    'camera'   = 'Camera'
    'signin'   = 'Signing in or passwords'
    'app'      = 'An app or website'
    'slow'     = 'Slow, freezing or crashing'
    'printing' = 'Printing'
    'bootpaper' = 'TLA BootPaper (backgrounds or intro videos)'
    'other'    = 'Something else'
}

# Windows' name with "11" where it applies (Windows 11 still calls itself "Windows 10" in the registry).
function Get-WVWindowsName {
    $cv = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $os = "$(Get-WVValue $cv 'ProductName')"
    if ([int]"0$(Get-WVValue $cv 'CurrentBuild')" -ge 22000) { $os = $os -replace 'Windows 10', 'Windows 11' }
    $release = "$(Get-WVValue $cv 'DisplayVersion')"
    if ($release) { $os = "$os $release" }
    return "$os (build $(Get-WVWindowsBuild))"
}

function Format-WVAgo([TimeSpan]$Span) {
    if ($Span.TotalMinutes -lt 2) { return 'just now' }
    if ($Span.TotalHours -lt 2)   { return '{0} minutes ago' -f [int][Math]::Floor($Span.TotalMinutes) }
    if ($Span.TotalDays -lt 2)    { return '{0} hours ago' -f [int][Math]::Floor($Span.TotalHours) }
    return '{0} days ago' -f [int][Math]::Floor($Span.TotalDays)
}

# What the helpdesk needs to find this PC and see what state it's in. Each part is skipped if it can't be read.
function Get-WVDeviceDetails {
    $d = [ordered]@{}
    $d['Computer'] = $env:COMPUTERNAME
    $cs = $null
    try { $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop } catch { }
    if ($cs) {
        $model = ('{0} {1}' -f "$($cs.Manufacturer)".Trim(), "$($cs.Model)".Trim()).Trim()
        if ($model) { $d['Model'] = $model }
    }
    try {
        $serial = "$((Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop).SerialNumber)".Trim()
        if ($serial) { $d['Serial number'] = $serial }
    } catch { }
    try { $d['System'] = Get-WVWindowsName } catch { }
    try {
        $boot = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop).LastBootUpTime
        if ($boot) { $d['Last restart'] = '{0:ddd MMM d, h:mm tt} ({1})' -f $boot, (Format-WVAgo ([DateTime]::Now - $boot)) }
    } catch { }
    try {
        $pending = $false
        foreach ($k in 'SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
                       'SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') {
            $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($k)
            if ($key) { $pending = $true; $key.Close() }
        }
        $d['Restart needed'] = if ($pending) { 'Yes (updates are waiting for a restart)' } else { 'No' }
    } catch { }
    if ($cs -and $cs.TotalPhysicalMemory) { $d['Memory'] = '{0} GB' -f [Math]::Round($cs.TotalPhysicalMemory / 1GB) }
    try {
        $drive = [System.IO.DriveInfo]::new("$($env:SystemDrive)".TrimEnd(':'))
        $d['Storage'] = '{0:0} GB free of {1:0} GB' -f ($drive.AvailableFreeSpace / 1GB), ($drive.TotalSize / 1GB)
    } catch { }
    try {
        $battery = @(Get-CimInstance -ClassName Win32_Battery -ErrorAction Stop)[0]
        if ($battery) {
            # BatteryStatus: 1, 4, 5 = on battery; 2, 3, 6-9, 11 = plugged in (charging or full).
            $state = if (@(2, 3, 6, 7, 8, 9, 11) -contains [int]$battery.BatteryStatus) { 'plugged in' } else { 'on battery' }
            $text = '{0}%, {1}' -f $battery.EstimatedChargeRemaining, $state
            try {
                $full   = @(Get-CimInstance -Namespace 'root\wmi' -ClassName BatteryFullChargedCapacity -ErrorAction Stop)[0].FullChargedCapacity
                $design = @(Get-CimInstance -Namespace 'root\wmi' -ClassName BatteryStaticData -ErrorAction Stop)[0].DesignedCapacity
                if ($full -and $design) { $text += '; health {0:0}% of new' -f [Math]::Min(100, 100 * $full / $design) }
            } catch { }
            $d['Battery'] = $text
        }
    } catch { }
    try {
        $out = & "$env:SystemRoot\System32\netsh.exe" wlan show interfaces 2>$null
        $ssid = ($out | Where-Object { $_ -match '^\s*SSID\s*:\s*(.+)$' } | Select-Object -First 1)
        $signal = ($out | Where-Object { $_ -match '^\s*Signal\s*:\s*(\d+)%' } | Select-Object -First 1)
        if ($ssid -and $ssid -match ':\s*(.+)$') {
            $name = $Matches[1].Trim()
            if ($signal -and $signal -match '(\d+)%') { $name = "$name (signal $($Matches[1])%)" }
            $d['Wi-Fi'] = $name
        }
    } catch { }
    try {
        # Devices whose driver isn't working (not ones that are just unplugged: code 45).
        $bad = @(Get-CimInstance -ClassName Win32_PnPEntity -Filter 'ConfigManagerErrorCode <> 0 AND ConfigManagerErrorCode <> 45' -ErrorAction Stop |
                 ForEach-Object { '{0} (code {1})' -f "$($_.Name)".Trim(), $_.ConfigManagerErrorCode } | Select-Object -First 6)
        $d['Devices with a problem'] = if ($bad.Count) { $bad -join '; ' } else { 'None' }
    } catch { }
    try {
        $store = [System.Security.Cryptography.X509Certificates.X509Store]::new('My', 'LocalMachine')
        $store.Open('ReadOnly, OpenExistingOnly')
        try {
            foreach ($cert in $store.Certificates) {
                if ($cert.Issuer -like '*Microsoft Intune MDM Device CA*' -and $cert.Subject -match 'CN=([0-9a-fA-F-]{36})') { $d['Intune device ID'] = $Matches[1] }
                if ($cert.Issuer -like '*MS-Organization-Access*' -and $cert.Subject -match 'CN=([0-9a-fA-F-]{36})') { $d['Entra device ID'] = $Matches[1] }
            }
        } finally { $store.Close() }
    } catch { }
    $d['TLA BootPaper'] = Get-WVVersionSummary
    try {
        $bg = Get-WVCurrentBackground
        $d['Background'] = if ($WV.Backgrounds.Contains($bg)) { $WV.Backgrounds[$bg] } elseif ($WV.Seasonal.Contains($bg)) { $WV.Seasonal[$bg] } else { $bg }
        $d['Intro video'] = $WV.Videos["$(Get-WVSetting 'Video')"]
    } catch { }
    $d['Reported'] = '{0:dddd, MMMM d, yyyy h:mm tt}' -f [DateTime]::Now
    return $d
}

function Format-WVDeviceDetails($Details) {
    return (@($Details.Keys | ForEach-Object { '{0}: {1}' -f $_, $Details[$_] }) -join "`r`n")
}

$reportXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Report a problem - TLA" Width="580" SizeToContent="Height" ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen" ShowInTaskbar="True"
        FontFamily="Segoe UI" FontSize="14" Background="White" Foreground="#1F1F1F">
  <Window.Resources>
    <Style x:Key="ButtonBase" TargetType="Button">
      <Setter Property="Padding" Value="18,7"/>
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
    <StackPanel Orientation="Horizontal" Margin="0,0,0,6">
      <Image x:Name="Logo" Width="44" Height="44" Margin="0,0,14,0" VerticalAlignment="Center"/>
      <TextBlock Text="Report a problem" FontSize="22" FontWeight="SemiBold" VerticalAlignment="Center"/>
    </StackPanel>
    <TextBlock TextWrapping="Wrap" Foreground="#5F6368" Margin="0,4,0,18"
               Text="Tell the helpdesk what's wrong. This computer's details are added for you, so they can find it and help faster."/>

    <TextBlock Text="What's it about?" Foreground="#5F6368" Margin="0,0,0,6"/>
    <ComboBox x:Name="Topic" Width="340" HorizontalAlignment="Left" Padding="8,5" Margin="0,0,0,14"/>

    <TextBlock Text="What happened?" Foreground="#5F6368" Margin="0,0,0,6"/>
    <TextBox x:Name="Description" Height="112" Padding="6,5" AcceptsReturn="True" TextWrapping="Wrap"
             VerticalScrollBarVisibility="Auto" MaxLength="1500"/>
    <TextBlock Text="What were you doing, and what did you expect to happen? Any error message helps. (You can attach a screenshot to the email.)"
               Foreground="#8A8A8A" FontSize="12" TextWrapping="Wrap" Margin="0,5,0,14"/>

    <TextBlock Text="How much is it getting in the way?" Foreground="#5F6368" Margin="0,0,0,6"/>
    <RadioButton x:Name="Blocking" GroupName="Impact" Content="I can't do my work" Margin="0,0,0,6"/>
    <RadioButton x:Name="Annoying" GroupName="Impact" Content="I can still work around it" IsChecked="True" Margin="0,0,0,14"/>

    <Expander x:Name="DetailsBox" Header="Details about this computer that will be included" Foreground="#5F6368">
      <TextBox x:Name="Details" Height="150" Margin="0,8,0,0" Padding="6,5" IsReadOnly="True" TextWrapping="Wrap"
               VerticalScrollBarVisibility="Auto" FontSize="12" Foreground="#1F1F1F" Background="#FAFAFA"/>
    </Expander>

    <Border x:Name="DoneBox" Visibility="Collapsed" Background="#DFF6DD" BorderBrush="#9FD89F" BorderThickness="1"
            CornerRadius="4" Padding="12,9" Margin="0,16,0,0">
      <TextBlock x:Name="DoneText" TextWrapping="Wrap" Foreground="#0E4B0E"/>
    </Border>

    <Grid Margin="0,20,0,0">
      <Button x:Name="CopyReport" Content="Copy report" Style="{StaticResource Secondary}" HorizontalAlignment="Left"/>
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
        <Button x:Name="CancelReport" Content="Cancel" Style="{StaticResource Secondary}" Margin="0,0,8,0" IsCancel="True"/>
        <Button x:Name="SendReport" Content="Email the helpdesk" Style="{StaticResource Primary}" IsEnabled="False"/>
      </StackPanel>
    </Grid>
  </StackPanel>
</Window>
'@

# The email: subject and body.
function Get-WVReport($Win) {
    $topic   = "$($Win.FindName('Topic').SelectedItem.Content)"
    $urgent  = [bool]$Win.FindName('Blocking').IsChecked
    $text    = "$($Win.FindName('Description').Text)".Trim()
    $details = "$($Win.FindName('Details').Text)"
    $subject = '{0}Problem report: {1} ({2})' -f $(if ($urgent) { 'URGENT - ' } else { '' }), $topic, $env:COMPUTERNAME
    $body = "What it's about: $topic`r`n" +
            "How much it's getting in the way: $(if ($urgent) { "I can't do my work" } else { 'I can still work around it' })`r`n`r`n" +
            "What happened:`r`n$text`r`n`r`n" +
            "-- Details about this computer (added by TLA BootPaper) --`r`n$details`r`n"
    return @{ Subject = $subject; Body = $body }
}

function New-WVReportWindow {
    $win = [System.Windows.Markup.XamlReader]::Parse($reportXaml)
    $topic = $win.FindName('Topic')
    $first = [System.Windows.Controls.ComboBoxItem]::new(); $first.Tag = ''; $first.Content = 'Choose one'
    [void]$topic.Items.Add($first)
    foreach ($id in $WV.ReportTopics.Keys) {
        $item = [System.Windows.Controls.ComboBoxItem]::new(); $item.Tag = $id; $item.Content = $WV.ReportTopics[$id]
        [void]$topic.Items.Add($item)
    }
    $topic.SelectedItem = $first
    $win.FindName('Details').Text = 'Collecting the details...'
    try {
        $iconBytes = [System.IO.File]::ReadAllBytes([System.IO.Path]::Combine($WV.Dir, 'welcome-video.ico'))
        $decoder = [System.Windows.Media.Imaging.BitmapDecoder]::Create([System.IO.MemoryStream]::new($iconBytes), 'None', 'OnLoad')
        $best = $null
        foreach ($frame in $decoder.Frames) { if (-not $best -or $frame.PixelWidth -gt $best.PixelWidth) { $best = $frame } }
        $win.FindName('Logo').Source = $best
        $win.Icon = $best
    } catch { }

    # Handlers run after this function returns: they reach the window through the control that fired.
    $ready = {
        param($s, $e)
        $w = [System.Windows.Window]::GetWindow($s)
        $w.FindName('SendReport').IsEnabled = ("$($w.FindName('Topic').SelectedItem.Tag)" -ne '') -and
                                             ("$($w.FindName('Description').Text)".Trim() -ne '')
    }
    $topic.Add_SelectionChanged($ready)
    $win.FindName('Description').Add_TextChanged($ready)

    $win.FindName('SendReport').Add_Click({
        param($s, $e)
        $w = [System.Windows.Window]::GetWindow($s)
        $r = Get-WVReport $w
        $to = $WV.Helpdesk
        $url = 'mailto:{0}?subject={1}&body={2}' -f $to, [Uri]::EscapeDataString($r.Subject), [Uri]::EscapeDataString($r.Body)
        $done = 'Your email to the helpdesk is ready in your mail app. Check it, add a screenshot if you like, then press Send.'
        if ($url.Length -gt 1900) {
            # Too long for some mail apps to take in one go: the full report goes on the clipboard instead.
            try { [System.Windows.Clipboard]::SetText($r.Body) } catch { }
            $url = 'mailto:{0}?subject={1}&body={2}' -f $to, [Uri]::EscapeDataString($r.Subject),
                   [Uri]::EscapeDataString("Your report is on the clipboard: paste it here (Ctrl+V).`r`n")
            $done = 'Your email to the helpdesk is ready in your mail app. Your report is on the clipboard: paste it into the email (Ctrl+V), then press Send.'
        }
        try {
            [void][System.Diagnostics.Process]::Start($url)
        } catch {
            # No mail app: Outlook on the web instead.
            try {
                [void][System.Diagnostics.Process]::Start(('https://outlook.office.com/mail/deeplink/compose?to={0}&subject={1}&body={2}' -f
                    [Uri]::EscapeDataString($to), [Uri]::EscapeDataString($r.Subject), [Uri]::EscapeDataString($r.Body)))
                $done = 'Your email to the helpdesk is ready in Outlook on the web. Check it, then press Send.'
            } catch {
                try { [System.Windows.Clipboard]::SetText($r.Body) } catch { }
                $done = "Couldn't open an email. Your report is on the clipboard: paste it into an email to $to."
            }
        }
        $w.FindName('DoneText').Text = $done
        $w.FindName('DoneBox').Visibility = 'Visible'
        $w.FindName('CancelReport').Content = 'Close'
    })
    $win.FindName('CopyReport').Add_Click({
        param($s, $e)
        $w = [System.Windows.Window]::GetWindow($s)
        $r = Get-WVReport $w
        try {
            [System.Windows.Clipboard]::SetText("To: $($WV.Helpdesk)`r`nSubject: $($r.Subject)`r`n`r`n$($r.Body)")
            $w.FindName('DoneText').Text = "Copied. Paste it into an email to $($WV.Helpdesk)."
        } catch {
            $w.FindName('DoneText').Text = "Couldn't copy it: $($_.Exception.Message)"
        }
        $w.FindName('DoneBox').Visibility = 'Visible'
    })
    $win.FindName('CancelReport').Add_Click({ param($s, $e) [System.Windows.Window]::GetWindow($s).Close() })
    # The details take a moment (a second or two): read them once the window is showing.
    $win.Add_ContentRendered({
        param($s, $e)
        $text = "Computer: $env:COMPUTERNAME`r`nTLA BootPaper: $($WV.Release)"
        try { $text = Format-WVDeviceDetails (Get-WVDeviceDetails) } catch { }
        $s.FindName('Details').Text = $text
        [void]$s.FindName('Description').Focus()
    })
    return $win
}

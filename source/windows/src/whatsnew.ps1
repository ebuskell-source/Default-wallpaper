# whatsnew.ps1
# The release log ("What's new"). play-video.ps1 shows it once after each new release ($WV.Release),
# right after the video (or on its own if the video doesn't play that time). The TLA BootPaper app
# also opens it from its "What's new" link. The text comes from release-notes.md, shared with the
# Mac version: lines starting with [win] or [mac] only show on that platform.
# 4.3: each release is marked Stable or Experimental (by the release channels in common.ps1), and people only
# see the releases on their own channel.

function Get-WVReleaseNotes([string]$Platform = 'win') {
    $sections = [System.Collections.Generic.List[object]]::new()
    $current  = $null
    $file = [System.IO.Path]::Combine($WV.Dir, 'release-notes.md')
    foreach ($raw in [System.IO.File]::ReadAllLines($file, [System.Text.Encoding]::UTF8)) {
        $line = $raw.Trim()
        if     ($line -match '^#\s+(.+)$') { $kind = 'title' }
        elseif ($line -match '^-\s+(.+)$') { $kind = 'item' }
        else   { continue }
        $text = $Matches[1]
        if ($text -match '^\[(win|mac)\]\s*(.*)$') {
            if ($Matches[1] -ne $Platform) { if ($kind -eq 'title') { $current = $null }; continue }
            $text = $Matches[2]
        }
        if ($kind -eq 'title') {
            $version = if ($text -match 'Version\s+(\d+(\.\d+)*)') { $Matches[1] } else { '' }
            # (a release newer than their channel's isn't shown to them)
            if ($version -and (ConvertTo-WVVersion $version) -gt (ConvertTo-WVVersion (Get-WVChannelRelease))) { $current = $null; continue }
            if ($version) { $text = "$text ($(Get-WVReleaseLabel $version))" }
            $current = @{ Title = $text; Items = [System.Collections.Generic.List[string]]::new() }
            $sections.Add($current)
        } elseif ($current) {
            $current.Items.Add($text)
        }
    }
    return @($sections | Where-Object { $_.Items.Count -gt 0 })
}

# **bold** becomes bold; everything else is plain text.
function Add-WVInlines($TextBlock, [string]$Text) {
    $parts = [regex]::Split($Text, '\*\*(.+?)\*\*')
    for ($i = 0; $i -lt $parts.Count; $i++) {
        if (-not $parts[$i]) { continue }
        $run = [System.Windows.Documents.Run]::new($parts[$i])
        if ($i % 2 -eq 1) { $TextBlock.Inlines.Add([System.Windows.Documents.Bold]::new($run)) }
        else              { $TextBlock.Inlines.Add($run) }
    }
}

$whatsNewXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="TLA BootPaper" Width="540" SizeToContent="Height" ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen" ShowInTaskbar="True"
        FontFamily="Segoe UI" FontSize="14" Background="White" Foreground="#1F1F1F">
  <Window.Resources>
    <Style x:Key="ButtonBase" TargetType="Button">
      <Setter Property="Padding" Value="18,7"/>
      <Setter Property="MinWidth" Value="104"/>
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
        <TextBlock Text="What's new in TLA BootPaper" FontSize="22" FontWeight="SemiBold"/>
        <TextBlock x:Name="Subtitle" Foreground="#5F6368" Margin="0,2,0,0"/>
      </StackPanel>
    </StackPanel>

    <ScrollViewer MaxHeight="440" VerticalScrollBarVisibility="Auto">
      <StackPanel x:Name="Notes" Margin="0,0,6,0"/>
    </ScrollViewer>

    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,20,0,0">
      <Button x:Name="OpenApp" Content="Open TLA BootPaper" Style="{StaticResource Secondary}" Margin="0,0,8,0"/>
      <Button x:Name="GotIt" Content="Got it" Style="{StaticResource Primary}" IsDefault="True" IsCancel="True"/>
    </StackPanel>
  </StackPanel>
</Window>
'@

# ---- "What should we call you?" (4.0) ----------------------------------------------------------------
# Asked once, after the intro video, so the video can greet them by name. They can skip it, and change the
# name any time in the app. Saving or "Not now" both count as asked (4.0.5: closing it any other way doesn't,
# so it's asked again at the next sign-in, up to 3 times).
$nameXaml = $whatsNewXaml -replace '(?s)<StackPanel Margin="28,24,28,22">.*</StackPanel>\s*</Window>', @'
<StackPanel Margin="28,24,28,22">
    <StackPanel Orientation="Horizontal" Margin="0,0,0,14">
      <Image x:Name="Logo" Width="44" Height="44" Margin="0,0,14,0" VerticalAlignment="Center"/>
      <TextBlock Text="What should we call you?" FontSize="22" FontWeight="SemiBold" VerticalAlignment="Center"/>
    </StackPanel>
    <TextBlock TextWrapping="Wrap" Foreground="#5F6368" Margin="0,0,0,14"
               Text="Your intro video will greet you by this name, like &#x201C;Good morning, Sam!&#x201D; You can change it any time in TLA BootPaper."/>
    <TextBox x:Name="NameBox" FontSize="15" Padding="8,6" MaxLength="30"/>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,20,0,0">
      <Button x:Name="NotNow" Content="Not now" Style="{StaticResource Secondary}" Margin="0,0,8,0" IsCancel="True"/>
      <Button x:Name="SaveName" Content="Save" Style="{StaticResource Primary}" IsDefault="True"/>
    </StackPanel>
  </StackPanel>
</Window>
'@

function New-WVNameWindow {
    $win = [System.Windows.Markup.XamlReader]::Parse($nameXaml)
    $box = $win.FindName('NameBox')
    $box.Text = "$(Get-WVSetting 'PreferredName')"
    try {
        $iconBytes = [System.IO.File]::ReadAllBytes([System.IO.Path]::Combine($WV.Dir, 'welcome-video.ico'))
        $decoder = [System.Windows.Media.Imaging.BitmapDecoder]::Create([System.IO.MemoryStream]::new($iconBytes), 'None', 'OnLoad')
        $best = $null
        foreach ($frame in $decoder.Frames) { if (-not $best -or $frame.PixelWidth -gt $best.PixelWidth) { $best = $frame } }
        $win.FindName('Logo').Source = $best
        $win.Icon = $best
    } catch { }
    $win.FindName('SaveName').Add_Click({
        param($s, $e)
        $w = [System.Windows.Window]::GetWindow($s)
        $name = ($w.FindName('NameBox').Text -replace '\s+', ' ').Trim()
        if ($name.Length -gt $WV.NameMax) { $name = $name.Substring(0, $WV.NameMax).Trim() }
        if (Test-WVValid 'PreferredName' $name) {
            try { [Microsoft.Win32.Registry]::SetValue($WV.UserKey, 'PreferredName', $name) } catch { }
        }
        try { [Microsoft.Win32.Registry]::SetValue($WV.StateKey, 'NameAsked', 1) } catch { }
        $w.Close()
    })
    $win.FindName('NotNow').Add_Click({
        param($s, $e)
        try { [Microsoft.Win32.Registry]::SetValue($WV.StateKey, 'NameAsked', 1) } catch { }
        [System.Windows.Window]::GetWindow($s).Close()
    })
    $win.Topmost = $true
    $win.Add_Loaded({ param($s, $e) [void]$s.Activate(); [void]$s.FindName('NameBox').Focus() })
    # Closed without an answer (the window's X, signing out): ask again next time, but not forever.
    $tries = 0; [void][int]::TryParse("$(Get-WVValue $WV.StateKey 'NameTries')", [ref]$tries)
    $tries++
    try {
        [Microsoft.Win32.Registry]::SetValue($WV.StateKey, 'NameTries', "$tries")
        if ($tries -ge 3) { [Microsoft.Win32.Registry]::SetValue($WV.StateKey, 'NameAsked', 1) }
    } catch { }
    return $win
}

# Builds the window. -FromApp: opened from the TLA BootPaper app (no "Open TLA BootPaper" button,
# and it doesn't count as having seen it). Otherwise it records that this release has been seen.
function New-WVWhatsNewWindow([switch]$FromApp) {
    $win = [System.Windows.Markup.XamlReader]::Parse($whatsNewXaml)
    $win.FindName('Subtitle').Text = "You're on version $(Get-WVShownRelease), $($WV.Channels[(Get-WVChannel)])"

    $notes = $win.FindName('Notes')
    $first = $true
    foreach ($section in (Get-WVReleaseNotes 'win')) {
        $heading = [System.Windows.Controls.TextBlock]::new()
        $heading.Text       = $section.Title
        $heading.FontSize   = if ($first) { 16 } else { 14 }
        $heading.FontWeight = 'SemiBold'
        $heading.Margin     = if ($first) { '0,0,0,8' } else { '0,14,0,6' }
        if (-not $first) { $heading.Foreground = '#5F6368' }
        [void]$notes.Children.Add($heading)
        foreach ($item in $section.Items) {
            $row = [System.Windows.Controls.DockPanel]::new()
            $row.Margin = '0,0,0,7'
            $bullet = [System.Windows.Controls.TextBlock]::new()
            $bullet.Text   = [string][char]0x2022
            $bullet.Margin = '4,0,10,0'
            [System.Windows.Controls.DockPanel]::SetDock($bullet, 'Left')
            $text = [System.Windows.Controls.TextBlock]::new()
            $text.TextWrapping = 'Wrap'
            $text.LineHeight   = 20
            if (-not $first) { $text.Foreground = '#5F6368' }
            Add-WVInlines $text $item
            [void]$row.Children.Add($bullet)
            [void]$row.Children.Add($text)
            [void]$notes.Children.Add($row)
        }
        $first = $false
    }

    try {
        $iconBytes = [System.IO.File]::ReadAllBytes([System.IO.Path]::Combine($WV.Dir, 'welcome-video.ico'))
        $decoder = [System.Windows.Media.Imaging.BitmapDecoder]::Create(
            [System.IO.MemoryStream]::new($iconBytes), 'None', 'OnLoad')
        $best = $null
        foreach ($frame in $decoder.Frames) { if (-not $best -or $frame.PixelWidth -gt $best.PixelWidth) { $best = $frame } }
        $win.FindName('Logo').Source = $best
        $win.Icon = $best
    } catch { }

    # Handlers run after this function returns: they reach the window through the clicked button.
    $win.FindName('GotIt').Add_Click({ param($s, $e) [System.Windows.Window]::GetWindow($s).Close() })
    if ($FromApp) {
        $win.FindName('OpenApp').Visibility = 'Collapsed'
    } else {
        $win.Topmost = $true
        $win.FindName('OpenApp').Add_Click({
            param($s, $e)
            try { Start-WVScript 'settings.ps1' } catch { }
            [System.Windows.Window]::GetWindow($s).Close()
        })
        $win.Add_Loaded({ param($s, $e) [void]$s.Activate() })
        try { [Microsoft.Win32.Registry]::SetValue($WV.StateKey, 'SeenRelease', (Get-WVShownRelease)) } catch { }
    }
    return $win
}

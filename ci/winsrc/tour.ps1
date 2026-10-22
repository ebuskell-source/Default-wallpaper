# tour.ps1
# "Welcome to TLA" (5.0): a short tour, after TLA Classic, the first time a prepared computer starts for its new
# owner (see "Prepare for initial unboxing" in the app, and play-video.ps1). Anyone can take it again from the
# TLA BootPaper app. Dot-sourced after common.ps1 (and care.ps1 for the logo). New-WVTourWindow builds it.
# Pages: welcome, their name for the greeting, their background, face or fingerprint sign-in, call backgrounds,
# TLA Care, done. The name and background pages only show when people may change those settings. 5.1.5: the face
# or fingerprint page only on computers that can do it, for people who haven't set it up yet. 5.2.5: full screen
# (other windows it opens, like Settings or TLA Care, still come in front), and "Connect to TLA" on computers Intune
# doesn't manage.

$tourXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Welcome to TLA" WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True" WindowState="Maximized"
        Background="Transparent" WindowStartupLocation="CenterScreen" ShowInTaskbar="True" FontFamily="Segoe UI" FontSize="16">
  <Window.Resources>
    <Style x:Key="TourButton" TargetType="Button">
      <Setter Property="Padding" Value="22,9"/>
      <Setter Property="MinWidth" Value="110"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FontSize" Value="15"/>
      <Setter Property="Foreground" Value="#0B1B33"/>
      <Setter Property="Background" Value="White"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="Bd" Background="{TemplateBinding Background}" CornerRadius="20" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Bd" Property="Opacity" Value="0.88"/></Trigger>
              <Trigger Property="IsPressed" Value="True"><Setter TargetName="Bd" Property="Opacity" Value="0.72"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="GhostButton" TargetType="Button" BasedOn="{StaticResource TourButton}">
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="Background" Value="#33FFFFFF"/>
    </Style>
    <Style x:Key="TileButton" TargetType="Button">
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Margin" Value="0,0,12,12"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="Frame" BorderThickness="3" BorderBrush="{TemplateBinding BorderBrush}" CornerRadius="8" Padding="2" Background="#33000000">
              <ContentPresenter/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Frame" Property="Background" Value="#55FFFFFF"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <Border x:Name="Card" Background="#0B1B33">
    <Grid>
      <Border x:Name="Picture"/>
      <Border>
        <Border.Background>
          <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
            <GradientStop Color="#F2081426" Offset="0"/>
            <GradientStop Color="#C8081426" Offset="0.5"/>
            <GradientStop Color="#30081426" Offset="1"/>
          </LinearGradientBrush>
        </Border.Background>
      </Border>
      <Grid Width="980" Height="620" HorizontalAlignment="Center" VerticalAlignment="Center">
      <Grid Margin="56,40,48,36">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <DockPanel Grid.Row="0">
          <Button x:Name="Skip" DockPanel.Dock="Right" Content="Skip the tour" Style="{StaticResource GhostButton}" Padding="16,6" FontSize="13" MinWidth="0"/>
          <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
            <Image x:Name="Logo" Width="30" Height="30" Margin="0,0,10,0"/>
            <TextBlock x:Name="Kicker" Text="WELCOME TO TLA" Foreground="#F2B830" FontSize="13" FontWeight="SemiBold" VerticalAlignment="Center"/>
          </StackPanel>
        </DockPanel>
        <StackPanel Grid.Row="1" VerticalAlignment="Center" Margin="0,10,0,10">
          <TextBlock x:Name="Heading" Foreground="White" FontSize="38" FontWeight="SemiBold" TextWrapping="Wrap" MaxWidth="620" HorizontalAlignment="Left"/>
          <TextBlock x:Name="Body" Foreground="#E6FFFFFF" FontSize="17" TextWrapping="Wrap" MaxWidth="520" HorizontalAlignment="Left" Margin="0,12,0,18" LineHeight="25"/>
          <StackPanel x:Name="Extra" HorizontalAlignment="Left"/>
        </StackPanel>
        <DockPanel Grid.Row="2">
          <StackPanel x:Name="Dots" Orientation="Horizontal" VerticalAlignment="Center" DockPanel.Dock="Left"/>
          <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="Back" Content="Back" Style="{StaticResource GhostButton}" Margin="0,0,10,0"/>
            <Button x:Name="Next" Content="Next" Style="{StaticResource TourButton}" IsDefault="True"/>
          </StackPanel>
        </DockPanel>
      </Grid>
      </Grid>
    </Grid>
  </Border>
</Window>
'@

# The 16:9 picture of a background (Wide\<name>.jpg) in this person's mode, or the full one.
function Get-WVTourPicture([string]$Id) {
    $shown = Get-WVShownPath $Id
    if (-not $shown) { return $null }
    $wide = [System.IO.Path]::Combine($WV.Dir, 'Wide', "$([System.IO.Path]::GetFileNameWithoutExtension($shown) -replace '-r\d+$', '').jpg")
    if ([System.IO.File]::Exists($wide)) { return $wide }
    return $shown
}

function Set-WVTourPicture {
    $file = Get-WVTourPicture (Get-WVCurrentBackground)
    if (-not $file) { return }
    try {
        $bitmap = [System.Windows.Media.Imaging.BitmapImage]::new()
        $bitmap.BeginInit()
        $bitmap.UriSource = [System.Uri]::new($file)
        $bitmap.CacheOption = 'OnLoad'
        $bitmap.DecodePixelWidth = 1280
        $bitmap.EndInit()
        $brush = [System.Windows.Media.ImageBrush]::new($bitmap)
        $brush.Stretch = 'UniformToFill'
        $script:TourState.Window.FindName('Picture').Background = $brush
    } catch { }
}

# 5.1.5: whether to offer face or fingerprint sign-in: the computer has a fingerprint reader or a face camera
# (a working biometric device), and this person hasn't set either up. care-system.ps1 (as SYSTEM) notes who has;
# until it has looked, Windows' own record is asked. (Not care.ps1's check: the player loads this without it.)
function Test-WVTourHello {
    $reader = $false
    try { $reader = [bool]@(Get-CimInstance -ClassName Win32_PnPEntity -ErrorAction Stop -Filter "PNPClass = 'Biometric' AND ConfigManagerErrorCode = 0").Count } catch { }
    if (-not $reader) { return $false }
    $sid = ''
    try { $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value } catch { }
    if (-not $sid) { return $true }
    if ("$(Get-WVValue 'HKEY_LOCAL_MACHINE\SOFTWARE\WelcomeVideo\Care\Hello' $sid)" -eq '1') { return $false }
    $factors = 0
    try { $factors = [int]"0$(Get-WVValue "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WinBio\AccountInfo\$sid" 'EnrolledFactors')" } catch { }
    return $factors -eq 0
}

function Get-WVTourPages {
    $pages = [System.Collections.Generic.List[string]]::new()
    $pages.Add('welcome')
    if (Test-WVUsersCanChange) { $pages.Add('name'); $pages.Add('background') }
    if (Test-WVTourHello) { $pages.Add('hello') }
    if (Test-WVReleased 'calls') { $pages.Add('calls') }
    if (Test-WVReleased 'care') { $pages.Add('care') }
    if (Test-WVConnectNeeded) { $pages.Add('connect') }   # (5.2.5)
    $pages.Add('done')
    return $pages.ToArray()
}

function New-WVTourButton([string]$Text, [scriptblock]$OnClick) {
    $b = [System.Windows.Controls.Button]::new()
    $b.Content = $Text
    $b.Style = $script:TourState.Window.FindResource('TourButton')
    $b.HorizontalAlignment = 'Left'
    $b.Add_Click($OnClick)
    return $b
}

function Save-WVTourName {
    $box = $script:TourState.NameBox
    if (-not $box) { return }
    $name = ("$($box.Text)" -replace '\s+', ' ').Trim()
    if ($name.Length -gt $WV.NameMax) { $name = $name.Substring(0, $WV.NameMax).Trim() }
    if ($name -and (Test-WVValid 'PreferredName' $name)) {
        try { [Microsoft.Win32.Registry]::SetValue($WV.UserKey, 'PreferredName', $name) } catch { }
    }
    try { [Microsoft.Win32.Registry]::SetValue($WV.StateKey, 'NameAsked', 1) } catch { }
}

function Show-WVTourPage([int]$Index) {
    $t = $script:TourState
    if ($t.Pages[$t.Index] -eq 'name') { Save-WVTourName }
    $t.Index = $Index
    $page = $t.Pages[$Index]
    $w = $t.Window
    $heading = $w.FindName('Heading'); $body = $w.FindName('Body'); $extra = $w.FindName('Extra')
    [void]$extra.Children.Clear()
    $w.FindName('Back').Visibility = if ($Index -gt 0) { 'Visible' } else { 'Collapsed' }
    $w.FindName('Next').Content = if ($page -eq 'done') { 'Get started' } elseif ($page -eq 'welcome') { "Let's go" } else { 'Next' }
    $w.FindName('Skip').Visibility = if ($page -eq 'done') { 'Collapsed' } else { 'Visible' }
    $name = ("$(Get-WVSetting 'PreferredName')" -replace '\s+', ' ').Trim()
    switch ($page) {
        'welcome' {
            $heading.Text = if ($name) { "Welcome to TLA, $name!" } else { 'Welcome to TLA!' }
            $body.Text = "This computer is all set up for you. Here's a quick look at what makes it yours. It takes about a minute."
        }
        'name' {
            $heading.Text = 'What should we call you?'
            $body.Text = 'Your intro video greets you by name, like "Good morning, Sam!" You can change it any time in TLA BootPaper.'
            $box = [System.Windows.Controls.TextBox]::new()
            $box.Width = 340; $box.FontSize = 18; $box.Padding = '10,7'; $box.MaxLength = $WV.NameMax
            $box.Text = $name
            [void]$extra.Children.Add($box)
            $t.NameBox = $box
            [void]$box.Focus()
        }
        'background' {
            $heading.Text = 'Pick your background'
            $body.Text = 'It goes on your desktop and lock screen. Each one has its own intro video, and a light and a dark look that follow Windows.'
            $wrap = [System.Windows.Controls.WrapPanel]::new()
            $wrap.MaxWidth = 880
            $current = "$(Get-WVSetting 'Background')"
            $mode = Get-WVMode
            foreach ($id in $WV.Backgrounds.Keys) {
                if (-not (Test-WVReleased $id) -and $id -ne "$(Get-WVOrgSetting 'Background')") { continue }
                $tile = [System.Windows.Controls.Button]::new()
                $tile.Style = $w.FindResource('TileButton')
                $tile.Tag = $id
                $tile.BorderBrush = if ($id -eq $current) { [System.Windows.Media.Brushes]::White } else { [System.Windows.Media.Brushes]::Transparent }
                $stack = [System.Windows.Controls.StackPanel]::new()
                $img = [System.Windows.Controls.Image]::new()
                $img.Width = 128; $img.Height = 72; $img.Stretch = 'UniformToFill'
                try {
                    $bitmap = [System.Windows.Media.Imaging.BitmapImage]::new()
                    $bitmap.BeginInit()
                    $bitmap.UriSource = [System.Uri]::new((Get-WVThumbnailPath $id $mode))
                    $bitmap.CacheOption = 'OnLoad'
                    $bitmap.DecodePixelWidth = 256
                    $bitmap.EndInit()
                    $img.Source = $bitmap
                } catch { }
                $label = [System.Windows.Controls.TextBlock]::new()
                $label.Text = $WV.Backgrounds[$id]; $label.Foreground = [System.Windows.Media.Brushes]::White
                $label.FontSize = 12; $label.HorizontalAlignment = 'Center'; $label.Margin = '0,3,0,1'
                [void]$stack.Children.Add($img)
                [void]$stack.Children.Add($label)
                $tile.Content = $stack
                $tile.Add_Click({
                    param($s, $e)
                    try {
                        [Microsoft.Win32.Registry]::SetValue($WV.UserKey, 'Background', "$($s.Tag)")
                        $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\WelcomeVideo', $true)
                        if ($key) { $key.DeleteValue('TempBackground', $false); $key.DeleteValue('TempUntil', $false); $key.Close() }
                    } catch { }
                    foreach ($other in $s.Parent.Children) { $other.BorderBrush = [System.Windows.Media.Brushes]::Transparent }
                    $s.BorderBrush = [System.Windows.Media.Brushes]::White
                    Set-WVTourPicture
                    try { Start-WVScript 'apply-background.ps1' '-FromApp' } catch { }
                })
                [void]$wrap.Children.Add($tile)
            }
            [void]$extra.Children.Add($wrap)
        }
        'hello' {
            $heading.Text = 'Sign in with a glance'
            $body.Text = "This computer can sign you in with your face or your fingerprint. Set up Windows Hello: it's faster than typing your password, and just as safe. You can do it any time in Settings > Accounts > Sign-in options."
            [void]$extra.Children.Add((New-WVTourButton 'Set up Windows Hello' {
                try { [void][System.Diagnostics.Process]::Start('ms-settings:signinoptions') } catch { }
            }))
        }
        'calls' {
            $heading.Text = 'Look great on calls'
            $body.Text = if ([System.IO.Directory]::Exists([System.IO.Path]::Combine($env:LOCALAPPDATA, 'Packages', 'MSTeams_8wekyb3d8bbwe'))) {
                'The TLA backgrounds are waiting in Microsoft Teams. In a meeting, open More > Video effects and pick one.'
            } else {
                'The TLA backgrounds are ready for your video calls. When you use Microsoft Teams, they''re in More > Video effects.'
            }
        }
        'care' {
            $heading.Text = 'Help is one click away'
            $body.Text = 'TLA Care keeps an eye on your computer and fixes common problems for you. Something not working? Choose "Report a problem to TLA" in the Start menu: your computer''s details go along, so the helpdesk can help faster.'
            [void]$extra.Children.Add((New-WVTourButton 'Open TLA Care' {
                try { Start-WVScript 'settings.ps1' '-Care' } catch { }
            }))
        }
        'connect' {
            $heading.Text = 'Connect to TLA'
            $body.Text = "This computer isn't connected to TLA yet, so it's missing what TLA sends: the TLA new tab page in Chrome and Edge, apps and updates. Click Connect to TLA, then Connect, and sign in with your TLA account."
            [void]$extra.Children.Add((New-WVTourButton 'Connect to TLA' {
                try { [void][System.Diagnostics.Process]::Start($WV.ConnectPage) } catch { }
            }))
        }
        'done' {
            $heading.Text = "You're all set!"
            $body.Text = "Have a great year. You'll find all of this again in TLA BootPaper, in the Start menu."
        }
    }
    # The dots: one per page, the current one wider.
    $dots = $w.FindName('Dots')
    [void]$dots.Children.Clear()
    for ($i = 0; $i -lt $t.Pages.Count; $i++) {
        $dot = [System.Windows.Controls.Border]::new()
        $dot.Height = 8; $dot.Width = if ($i -eq $Index) { 26 } else { 8 }
        $dot.CornerRadius = [System.Windows.CornerRadius]::new(4)
        $dot.Margin = '0,0,8,0'
        $dot.Background = if ($i -eq $Index) { [System.Windows.Media.Brushes]::White }
                          else { [System.Windows.Media.BrushConverter]::new().ConvertFromString('#66FFFFFF') }
        [void]$dots.Children.Add($dot)
    }
}

function Close-WVTour {
    $t = $script:TourState
    if ($t.Pages[$t.Index] -eq 'name') { Save-WVTourName }
    try { [Microsoft.Win32.Registry]::SetValue($WV.StateKey, 'TourDone', [DateTime]::Now.ToString('s')) } catch { }
    $t.Window.Close()
}

function New-WVTourWindow {
    $win = [System.Windows.Markup.XamlReader]::Parse($tourXaml)
    $script:TourState = @{ Window = $win; Pages = @(Get-WVTourPages); Index = 0; NameBox = $null }
    try {
        $iconBytes = [System.IO.File]::ReadAllBytes([System.IO.Path]::Combine($WV.Dir, 'welcome-video.ico'))
        $decoder = [System.Windows.Media.Imaging.BitmapDecoder]::Create([System.IO.MemoryStream]::new($iconBytes), 'None', 'OnLoad')
        $best = $null
        foreach ($frame in $decoder.Frames) { if (-not $best -or $frame.PixelWidth -gt $best.PixelWidth) { $best = $frame } }
        $win.FindName('Logo').Source = $best
        $win.Icon = $best
    } catch { }
    Set-WVTourPicture
    $win.FindName('Next').Add_Click({
        param($s, $e)
        $t = $script:TourState
        if ($t.Index -ge $t.Pages.Count - 1) { Close-WVTour } else { Show-WVTourPage ($t.Index + 1) }
    })
    $win.FindName('Back').Add_Click({ param($s, $e) if ($script:TourState.Index -gt 0) { Show-WVTourPage ($script:TourState.Index - 1) } })
    $win.FindName('Skip').Add_Click({ param($s, $e) Close-WVTour })
    # 5.2.5: full screen, and it stays that way (it can still be minimized, or go behind what it opened).
    $win.Add_StateChanged({ param($s, $e) if ($s.WindowState -eq 'Normal') { $s.WindowState = 'Maximized' } })
    $win.Add_KeyDown({ param($s, $e) if ($e.Key -eq 'Escape') { Close-WVTour } })
    $win.Add_Loaded({ param($s, $e) [void]$s.Activate() })
    Show-WVTourPage 0
    return $win
}

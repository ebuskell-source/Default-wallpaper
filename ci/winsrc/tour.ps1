# tour.ps1
# "Welcome to TLA" (5.0): a short tour, after TLA Classic, the first time a prepared computer starts for its new
# owner (see "Prepare for initial unboxing" in the app, and play-video.ps1). Anyone can take it again from the
# TLA BootPaper app. Dot-sourced after common.ps1 (and care.ps1 for the logo). New-WVTourWindow builds it.
# Pages: welcome, their name for the greeting, their background, face or fingerprint sign-in, call backgrounds,
# TLA Care, done. The name and background pages only show when people may change those settings. 5.1.5: the face
# or fingerprint page only on computers that can do it, for people who haven't set it up yet. 5.2.5: full screen
# (other windows it opens, like Settings or TLA Care, still come in front), and "Connect to TLA" on computers Intune
# doesn't manage. 6.0.5: the backgrounds page shows one themed section at a time (Tech, Places, Art styles, Animals,
# TLA), picked above the pictures: all of them at once no longer fit, and the last row was cut off.

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
    if (Test-WVSignedOut) { $pages.Add('signin') }   # (6.1.5: their Hub account first)
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
    # 6.2.5: on TLA's own PCs, no skipping the tour until they've signed in.
    $t.MustSignIn = Test-WVMustSignIn
    $w.FindName('Skip').Visibility = if ($page -eq 'done' -or $t.MustSignIn) { 'Collapsed' } else { 'Visible' }
    $name = ("$(Get-WVSetting 'PreferredName')" -replace '\s+', ' ').Trim()
    switch ($page) {
        'signin' {   # (6.1.5)
            if (Test-WVSignedOut) {
                $heading.Text = 'Sign in with your Hub account'
                $body.Text = if ($t.MustSignIn) { 'This computer belongs to TLA, so sign in with the account you use for the TLA Hub before you keep going. Click Sign in: your browser opens the Hub''s sign-in page.' }
                             else { 'Sign in once with the account you use for the TLA Hub. Until you do, your choices are greyed out and you see TLA Classic. Click Sign in: your browser opens the Hub''s sign-in page.' }
                if ($t.SignInNote) {
                    $n0 = [System.Windows.Controls.TextBlock]::new(); $n0.Text = $t.SignInNote
                    $n0.Foreground = [System.Windows.Media.Brushes]::White; $n0.TextWrapping = 'Wrap'; $n0.MaxWidth = 560; $n0.Margin = '0,0,0,10'
                    [void]$extra.Children.Add($n0)
                }
                [void]$extra.Children.Add((New-WVTourButton 'Sign in' {
                    try { Start-WVScript 'settings.ps1' '-SignIn' } catch { }
                    $script:TourState.SignInStarted = $true
                    $n = [System.Windows.Controls.TextBlock]::new()
                    $n.Text = 'Finish signing in in your browser. When it says you''re signed in, come back here and click Next.'
                    $n.Foreground = [System.Windows.Media.Brushes]::White; $n.TextWrapping = 'Wrap'; $n.MaxWidth = 560; $n.Margin = '0,10,0,0'
                    [void]$script:TourState.Window.FindName('Extra').Children.Add($n)
                }))
            } else {
                $heading.Text = "You're signed in"
                $body.Text = 'Your choices are yours to make now. Let''s set them up.'
            }
        }
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
            $current = "$(Get-WVSetting 'Background')"
            $orgBg = "$(Get-WVOrgSetting 'Background')"
            $list = @($WV.Backgrounds.Keys | Where-Object { (Test-WVReleased $_) -or $_ -eq $orgBg })
            # 6.0.5: one themed section at a time, starting with the one their background is in.
            $cats = @($WV.Categories.Keys | Where-Object { $cid = $_; @($list | Where-Object { (Get-WVCategory $_) -eq $cid }).Count })
            if ($cats -notcontains $t.Cat) { $t.Cat = if ($list -contains $current) { Get-WVCategory $current } else { $cats[0] } }
            $tabs = [System.Windows.Controls.WrapPanel]::new()
            $tabs.Margin = '0,0,0,16'
            foreach ($cid in $cats) {
                $tab = [System.Windows.Controls.Button]::new()
                $tab.Content = $WV.Categories[$cid]; $tab.Tag = $cid
                $tab.Style = $w.FindResource($(if ($cid -eq $t.Cat) { 'TourButton' } else { 'GhostButton' }))
                $tab.Padding = '18,7'; $tab.MinWidth = 0; $tab.FontSize = 14; $tab.Margin = '0,0,8,0'
                $tab.Add_Click({ param($s, $e) $script:TourState.Cat = "$($s.Tag)"; Show-WVTourPage $script:TourState.Index })
                [void]$tabs.Children.Add($tab)
            }
            [void]$extra.Children.Add($tabs)
            $wrap = [System.Windows.Controls.WrapPanel]::new()
            $wrap.MaxWidth = 880
            # (room for two rows, the most a section has, so the page doesn't jump between sections)
            $wrap.MinHeight = 2 * (72 + 4 + 22 + 12) + 16
            $mode = Get-WVMode
            foreach ($id in $list) {
                if ((Get-WVCategory $id) -ne $t.Cat) { continue }
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
                $label.Text = $WV.Backgrounds[$id] + $(if ($WV.Captions.ContainsKey($id)) { "`n$($WV.Captions[$id])" })   # (6.1.0: "Windows default")
                $label.TextAlignment = 'Center'; $label.Foreground = [System.Windows.Media.Brushes]::White
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
    if (Test-WVMustSignIn) { return }   # (6.2.5)
    if ($t.Pages[$t.Index] -eq 'name') { Save-WVTourName }
    try { [Microsoft.Win32.Registry]::SetValue($WV.StateKey, 'TourDone', [DateTime]::Now.ToString('s')) } catch { }
    $t.Window.Close()
}

function New-WVTourWindow {
    $win = [System.Windows.Markup.XamlReader]::Parse($tourXaml)
    $script:TourState = @{ Window = $win; Pages = @(Get-WVTourPages); Index = 0; NameBox = $null; Cat = '' }
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
        if ($t.Pages[$t.Index] -eq 'signin' -and (Test-WVMustSignIn)) {   # (6.2.5)
            $t.SignInNote = if ($t.SignInStarted) { 'You''re not signed in yet. Finish signing in in your browser, then click Next.' } else { 'Sign in first: click Sign in below.' }
            Show-WVTourPage $t.Index; return
        }
        $t.SignInNote = ''
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

# ---- 6.2.5: the lock screen -----------------------------------------------------------------------------------
# On TLA's own PCs (joined to TLA's Entra ID or a domain), it covers everything while this person's Hub sign-in has
# run out, or they've never signed in, until they sign in. Not while the PC is offline, when they couldn't anyway.
# settings.ps1 -Lock (the "TLA BootPaper Sign-in Lock" task, at each sign-in) checks every minute. While they sign
# in, their web browser may come in front of it; anything else, it covers again. Signing out of Windows still works.
$WV.LockBrowsers = @('chrome', 'msedge', 'firefox', 'brave', 'opera', 'vivaldi', 'arc')
function Test-WVCorporate {
    if (-not (Test-WVReleased 'lockdown')) { return $false }
    if ($env:TB_TEST_CORPORATE -eq '1') { return $true }   # (developer check: as if it were TLA's)
    try {
        $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine', 'Registry64')
        $k = $base.OpenSubKey('SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo')
        if ($k) { try { if ($k.SubKeyCount -gt 0) { return $true } } finally { $k.Close() } }
        $k = $base.OpenSubKey('SYSTEM\CurrentControlSet\Services\Netlogon\Parameters')
        if ($k) { try { if ("$($k.GetValue('DynamicSiteName'))$($k.GetValue('SiteName'))") { return $true } } finally { $k.Close() } }
    } catch { }
    return $false   # (unlike Test-WVOwnedByTla: only when it's certain)
}
# 7.3.5: only once "Prepare for initial unboxing" has been clicked on this PC, so it doesn't lock while it's being set up.
function Test-WVUnboxPrepared { return @('armed', 'unboxing', 'done') -contains "$(Get-WVValue 'HKEY_LOCAL_MACHINE\SOFTWARE\WelcomeVideo\Unbox' 'State')" }
function Test-WVMustSignIn { return (Test-WVCorporate) -and (Test-WVUnboxPrepared) -and (Get-WVSignIn -Fresh).state -eq 'out' }
function Test-WVLockNeeded {
    if (-not (Test-WVMustSignIn)) { return $false }
    # (not over the welcome video, and not over the tour while it's in front: the tour asks them to sign in itself.
    # 6.5.0: a tour left open behind other windows no longer keeps the lock away, as on Macs in 7.0.5)
    try {
        Add-Type -Namespace WelcomeVideo -Name LockFront -MemberDefinition @'
[DllImport("user32.dll")] public static extern System.IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(System.IntPtr hWnd, out uint pid);
'@ -ErrorAction SilentlyContinue
    } catch { }
    [uint32]$fpid = 0
    try { [void][WelcomeVideo.LockFront]::GetWindowThreadProcessId([WelcomeVideo.LockFront]::GetForegroundWindow(), [ref]$fpid) } catch { }
    $me = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
    foreach ($p in [System.Diagnostics.Process]::GetProcessesByName('powershell')) {
        try {
            if ($p.SessionId -ne $me -or $p.Id -eq $PID) { continue }
            $t = "$($p.MainWindowTitle)"
            if ($t -eq 'TLA BootPaper video') { return $false }
            if ($t -eq 'Welcome to TLA' -and $p.Id -eq $fpid) { return $false }
        } catch { }
    }
    return Test-WVOnline
}

$lockXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="TLA BootPaper sign-in" WindowStyle="None" ResizeMode="NoResize" WindowState="Maximized" Topmost="True"
        Background="#0B1B33" ShowInTaskbar="False" FontFamily="Segoe UI" FontSize="16">
  <Grid>
    <Border x:Name="Picture" Opacity="0.35"/>
    <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center" MaxWidth="640">
      <Image x:Name="Logo" Width="72" Height="72" Margin="0,0,0,18"/>
      <TextBlock Text="Sign in to keep using this computer" Foreground="White" FontSize="34" FontWeight="SemiBold"
                 TextWrapping="Wrap" TextAlignment="Center"/>
      <TextBlock x:Name="Body" Foreground="#E6FFFFFF" FontSize="17" TextWrapping="Wrap" TextAlignment="Center" Margin="0,14,0,24" LineHeight="25"/>
      <Button x:Name="SignIn" Content="Sign in" HorizontalAlignment="Center" Padding="40,10" FontSize="16" IsDefault="True"
              Foreground="#0B1B33" Background="White" BorderThickness="0" Cursor="Hand"/>
      <TextBlock x:Name="Note" Foreground="#CCFFFFFF" FontSize="14" TextWrapping="Wrap" TextAlignment="Center" Margin="0,18,0,0"/>
    </StackPanel>
    <StackPanel VerticalAlignment="Bottom" HorizontalAlignment="Center" Margin="0,0,0,24">
      <Button x:Name="SignOut" Content="Sign out of Windows" HorizontalAlignment="Center" Padding="16,6" FontSize="13"
              Foreground="White" Background="#33FFFFFF" BorderThickness="0" Cursor="Hand"/>
      <TextBlock Text="Need help? Email helpdesk@schoolathome.ca" Foreground="#99FFFFFF" FontSize="12" Margin="0,10,0,0" HorizontalAlignment="Center"/>
    </StackPanel>
  </Grid>
</Window>
'@

# What it did, for TLA Care and the helpdesk: %LOCALAPPDATA%\TLA BootPaper\lock.log (kept short).
function Write-WVLockLog([string]$Text) {
    try {
        $d = [System.IO.Path]::Combine($env:LOCALAPPDATA, 'TLA BootPaper'); [void][System.IO.Directory]::CreateDirectory($d)
        $f = [System.IO.Path]::Combine($d, 'lock.log')
        if ([System.IO.File]::Exists($f) -and (Get-Item $f).Length -gt 65536) { [System.IO.File]::Delete($f) }
        [System.IO.File]::AppendAllText($f, ('{0:yyyy-MM-dd HH:mm:ss} {1} {2}{3}' -f (Get-Date), "$($WV.Release)", $Text, "`r`n"))
    } catch { }
}
# 7.3.0: the lock's sign-in page opens in Edge in kiosk mode (full screen, no address bar, no other tabs or windows), in
# a profile of its own, so signing in doesn't give the browser - and the rest of the internet - meanwhile.
$WV.LockBrowserProfile = [System.IO.Path]::Combine($env:LOCALAPPDATA, 'TLA BootPaper', 'signin-browser')
function Start-WVLockBrowser([string]$Url) {
    $edge = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") |
        Where-Object { [System.IO.File]::Exists($_) } | Select-Object -First 1
    if (-not $edge) { [void][System.Diagnostics.Process]::Start($Url); return $false }   # (no Edge: their default browser)
    Stop-WVLockBrowser
    [void][System.IO.Directory]::CreateDirectory($WV.LockBrowserProfile)
    $a = "--kiosk `"$Url`" --edge-kiosk-type=fullscreen --no-first-run --no-default-browser-check --user-data-dir=`"$($WV.LockBrowserProfile)`""
    [void][System.Diagnostics.Process]::Start($edge, $a)
    return $true
}
# The processes of that browser (by its profile folder), as a list of process IDs.
function Get-WVLockBrowserPids {
    try {
        $p = $WV.LockBrowserProfile.Replace('\', '\\')
        return @(Get-CimInstance Win32_Process -Filter "Name = 'msedge.exe' AND CommandLine LIKE '%$p%'" -ErrorAction Stop | ForEach-Object { [uint32]$_.ProcessId })
    } catch { return @() }
}
function Stop-WVLockBrowser { foreach ($id in (Get-WVLockBrowserPids)) { try { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue } catch { } } }

# 7.3.5: while the lock is up, the Windows key (and Ctrl+Esc, Alt+Tab, Alt+Esc) do nothing, so the Start menu and the
# taskbar can't be reached. (Ctrl+Alt+Del can't be blocked by any app; its menu only offers to lock, switch user or sign out.)
try {
    Add-Type -Namespace WelcomeVideo -Name KeyBlock -MemberDefinition @'
public delegate System.IntPtr HookProc(int code, System.IntPtr wParam, System.IntPtr lParam);
[DllImport("user32.dll")] static extern System.IntPtr SetWindowsHookEx(int id, HookProc fn, System.IntPtr mod, uint thread);
[DllImport("user32.dll")] static extern bool UnhookWindowsHookEx(System.IntPtr h);
[DllImport("user32.dll")] static extern System.IntPtr CallNextHookEx(System.IntPtr h, int code, System.IntPtr w, System.IntPtr l);
[DllImport("user32.dll")] static extern short GetAsyncKeyState(int vk);
[DllImport("kernel32.dll")] static extern System.IntPtr GetModuleHandle(string name);
static System.IntPtr hook = System.IntPtr.Zero;
static HookProc proc = Filter;
static System.IntPtr Filter(int code, System.IntPtr w, System.IntPtr l) {
    if (code >= 0) {
        int vk = Marshal.ReadInt32(l), flags = Marshal.ReadInt32(l, 8);
        bool alt = (flags & 0x20) != 0, ctrl = (GetAsyncKeyState(0x11) & 0x8000) != 0;
        if (vk == 0x5B || vk == 0x5C || (vk == 0x09 && alt) || (vk == 0x1B && (alt || ctrl))) return (System.IntPtr)1;
    }
    return CallNextHookEx(hook, code, w, l);
}
public static void On() { if (hook == System.IntPtr.Zero) hook = SetWindowsHookEx(13, proc, GetModuleHandle(null), 0); }
public static void Off() { if (hook != System.IntPtr.Zero) { UnhookWindowsHookEx(hook); hook = System.IntPtr.Zero; } }
'@ -ErrorAction SilentlyContinue
} catch { }

function New-WVLockWindow {
    try {
        Add-Type -Namespace WelcomeVideo -Name LockFront -MemberDefinition @'
[DllImport("user32.dll")] public static extern System.IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(System.IntPtr hWnd, out uint pid);
'@ -ErrorAction SilentlyContinue
    } catch { }
    $win = [System.Windows.Markup.XamlReader]::Parse($lockXaml)
    $script:LockState = @{ Window = $win; Pending = $null; Wait = $null; NextCheck = [DateTime]::MinValue; Done = $false; Url = '' }
    try {
        $iconBytes = [System.IO.File]::ReadAllBytes([System.IO.Path]::Combine($WV.Dir, 'welcome-video.ico'))
        $decoder = [System.Windows.Media.Imaging.BitmapDecoder]::Create([System.IO.MemoryStream]::new($iconBytes), 'None', 'OnLoad')
        $best = $null
        foreach ($frame in $decoder.Frames) { if (-not $best -or $frame.PixelWidth -gt $best.PixelWidth) { $best = $frame } }
        $win.FindName('Logo').Source = $best; $win.Icon = $best
    } catch { }
    try {
        $file = [System.IO.Path]::Combine($WV.Dir, 'bg-tla-dark.jpg')
        if ([System.IO.File]::Exists($file)) {
            $bitmap = [System.Windows.Media.Imaging.BitmapImage]::new()
            $bitmap.BeginInit(); $bitmap.UriSource = [System.Uri]::new($file); $bitmap.CacheOption = 'OnLoad'; $bitmap.DecodePixelWidth = 1600; $bitmap.EndInit()
            $brush = [System.Windows.Media.ImageBrush]::new($bitmap); $brush.Stretch = 'UniformToFill'
            $win.FindName('Picture').Background = $brush
        }
    } catch { }
    $win.FindName('Body').Text = if ((Get-WVSignIn).reason -eq 'expired') {
        'Your Hub sign-in has run out. Sign in again with the account you use for the TLA Hub to keep using this computer.'
    } else { 'Before you can use this computer, sign in once with the account you use for the TLA Hub.' }

    $lockNote = { param($t) $script:LockState.Window.FindName('Note').Text = $t }
    $lockFront = {
        $w = $script:LockState.Window
        $w.Topmost = $true
        if ($w.WindowState -ne 'Maximized') { $w.WindowState = 'Maximized' }
        try { [void]$w.Activate() } catch { }
    }
    $script:LockFront = $lockFront; $script:LockNote = $lockNote
    $stop = {
        $l = $script:LockState
        if ($l.Pending) { try { $l.Pending.Listener.Stop() } catch { } ; $l.Pending = $null }
        Stop-WVLockBrowser; $l.Kiosk = $false
        $l.Window.FindName('SignIn').Content = 'Sign in'
    }
    $script:LockStop = $stop

    $win.FindName('SignIn').Add_Click({
        $l = $script:LockState
        if ($l.Pending) {   # (the button says "Open the sign-in page again" meanwhile)
            try { $l.Kiosk = Start-WVLockBrowser $l.Pending.Url; $l.BrowserPids = @(); $l.PidCheck = [DateTime]::MinValue } catch { }
            return
        }
        try {
            $l.Pending = Start-WVSignIn
            $l.Kiosk = Start-WVLockBrowser $l.Pending.Url; $l.BrowserPids = @(); $l.PidCheck = [DateTime]::MinValue   # (7.3.0)
            $l.Window.Topmost = $false
            $l.Window.FindName('SignIn').Content = 'Open the sign-in page again'
            & $script:LockNote 'Sign in with your Hub account on the page that opened. This computer unlocks by itself.'
        } catch {
            & $script:LockStop
            & $script:LockNote "Couldn't start signing in ($($_.Exception.Message)). Try again."
        }
    })
    $win.FindName('SignOut').Add_Click({
        & $script:LockStop
        try { [void][System.Diagnostics.Process]::Start([System.IO.Path]::Combine($env:SystemRoot, 'System32\shutdown.exe'), '/l') } catch { }
    })
    # It only closes once they're signed in (or Windows is signing them out).
    $win.Add_Closing({ param($s, $e) if (-not $script:LockState.Done -and -not $script:LockState.Ending) { $e.Cancel = $true } })
    if (-not $script:LockSessionHook) {   # (once per run: the window is made again each time it's needed)
        $script:LockSessionHook = $true
        [Microsoft.Win32.SystemEvents]::add_SessionEnding({ param($s, $e) if ($script:LockState) { $script:LockState.Ending = $true; try { $script:LockState.Window.Close() } catch { } } })
    }
    $win.Add_StateChanged({ param($s, $e) if ($s.WindowState -ne 'Maximized') { $s.WindowState = 'Maximized' } })

    $timer = [System.Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromMilliseconds(250)
    $timer.Add_Tick({
        $l = $script:LockState
        try {
            if ($l.Pending) {
                $answer = $null
                try { $answer = Receive-WVSignIn $l.Pending } catch { $answer = @{} }
                if ($null -ne $answer) {
                    $pending = $l.Pending; $l.Pending = $null
                    Stop-WVLockBrowser; $l.Kiosk = $false   # (7.3.0: the sign-in browser closes once it's done)
                    $l.Window.FindName('SignIn').Content = 'Sign in'
                    $r = Complete-WVSignIn $pending $answer
                    if ($r.ok) {
                        & $script:LockNote 'Signed in. Unlocking...'
                        if ($r.needKeys) { [void](Invoke-WVCareRequest 'signin') }
                        $l.Wait = [DateTime]::UtcNow.AddSeconds(75); $l.NextCheck = [DateTime]::MinValue
                        try { Start-WVScript 'apply-background.ps1' } catch { }
                    } else { & $script:LockNote $r.message }
                    & $script:LockFront
                } else {
                    # Only the sign-in browser may be in front meanwhile (7.3.0: only its own kiosk window, not any browser).
                    $fg = [WelcomeVideo.LockFront]::GetForegroundWindow(); [uint32]$fpid = 0
                    [void][WelcomeVideo.LockFront]::GetWindowThreadProcessId($fg, [ref]$fpid)
                    if ($l.Kiosk) {
                        if ([DateTime]::UtcNow -ge $l.PidCheck) { $l.BrowserPids = Get-WVLockBrowserPids; $l.PidCheck = [DateTime]::UtcNow.AddSeconds(2) }
                        if ($fpid -ne $PID -and $l.BrowserPids -notcontains $fpid) { & $script:LockFront; $l.Window.Topmost = $false }
                    } else {
                        $name = ''
                        if ($fpid -and $fpid -ne $PID) { try { $name = [System.Diagnostics.Process]::GetProcessById([int]$fpid).ProcessName.ToLowerInvariant() } catch { } }
                        if ($fpid -ne $PID -and $WV.LockBrowsers -notcontains $name) { & $script:LockFront; $l.Window.Topmost = $false }
                    }
                }
            } elseif (-not $l.Window.IsActive) {
                & $script:LockFront
            }
            if ([DateTime]::UtcNow -ge $l.NextCheck) {
                $l.NextCheck = [DateTime]::UtcNow.AddSeconds($(if ($l.Wait) { 2 } else { 5 }))
                if ((Get-WVSignIn -Fresh).state -ne 'out') {
                    $l.Done = $true; $script:LockTimer.Stop()
                    & $script:LockStop
                    $l.Window.Close(); return
                }
                if ($l.Wait -and [DateTime]::UtcNow -gt $l.Wait) { $l.Wait = $null; & $script:LockNote 'Couldn''t finish signing in. Try again in a minute.' }
            }
        } catch { Write-WVLockLog "tick: $($_.Exception.Message)" }
    })
    $win.Add_Loaded({ param($s, $e) [void]$s.Activate(); Write-WVLockLog "shown ($((Get-WVSignIn).reason))" })
    $script:LockTimer = $timer
    $win.Add_SourceInitialized({ try { [WelcomeVideo.KeyBlock]::On() } catch { } })   # (7.3.5: no Windows key)
    $win.Add_Closed({ param($s, $e) try { [WelcomeVideo.KeyBlock]::Off() } catch { }; $script:LockTimer.Stop(); & $script:LockStop; Write-WVLockLog 'closed (signed in)' })
    $timer.Start()
    return $win
}

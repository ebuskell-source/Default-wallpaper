# settings.ps1
# The "TLA BootPaper" app in the Start menu (called "Welcome Video" before 3.1). Each person chooses whether, when
# and which welcome video plays for them, and which of the preset backgrounds they get on their desktop and lock
# screen. Changes save as soon as they're made (to HKCU\Software\WelcomeVideo); a new background is applied
# right away by apply-background.ps1. The window can be moved and resized, and scrolls when it doesn't fit.
# 4.3: -Report opens just the "Report a problem" form (the "Report a problem to TLA" Start menu entry).
# 5.0: -Care opens TLA Care (the "TLA Care" Start menu entry), -Tour the Welcome to TLA tour.
param([switch]$Report, [switch]$Care, [switch]$Tour)

$ErrorActionPreference = 'Stop'
. ([System.IO.Path]::Combine($PSScriptRoot, 'common.ps1'))
. ([System.IO.Path]::Combine($PSScriptRoot, 'whatsnew.ps1'))
. ([System.IO.Path]::Combine($PSScriptRoot, 'report.ps1'))
. ([System.IO.Path]::Combine($PSScriptRoot, 'care.ps1'))
. ([System.IO.Path]::Combine($PSScriptRoot, 'tour.ps1'))

foreach ($assembly in 'PresentationFramework', 'PresentationCore', 'WindowsBase') {
    [void][System.Reflection.Assembly]::Load("$assembly, Version=4.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35")
}

# 4.2.5: if the app can't open, say so (and note why in %LOCALAPPDATA%\TLA BootPaper\app-errors.log) instead of
# closing without a word.
trap {
    $err = $_
    $why = "$($err.Exception.Message)`r`n$($err.InvocationInfo.PositionMessage)"
    try {
        $logDir = [System.IO.Path]::Combine($env:LOCALAPPDATA, 'TLA BootPaper')
        [void][System.IO.Directory]::CreateDirectory($logDir)
        [System.IO.File]::AppendAllText([System.IO.Path]::Combine($logDir, 'app-errors.log'),
            ('{0:yyyy-MM-dd HH:mm:ss} {1} {2}{3}' -f (Get-Date), "$($WV.Release)", $why, "`r`n"))
    } catch { }
    try {
        [void][System.Windows.MessageBox]::Show(
            "TLA BootPaper couldn't open.`n`n$($err.Exception.Message)`n`nPlease email helpdesk@schoolathome.ca so it can be fixed.",
            'TLA BootPaper', 'OK', 'Warning')
    } catch { }
    exit 1
}

if ($Report) {
    $reportWindow = New-WVReportWindow
    [void]$reportWindow.ShowDialog()
    return
}
if ($Care) {
    $careWindow = New-WVCareWindow
    [void]$careWindow.ShowDialog()
    return
}
if ($Tour) {
    $tourWindow = New-WVTourWindow
    [void]$tourWindow.ShowDialog()
    return
}

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="TLA BootPaper" Width="790" MinWidth="520" MinHeight="360" SizeToContent="Height" ResizeMode="CanResize"
        WindowStartupLocation="CenterScreen" FontFamily="Segoe UI" FontSize="14"
        Background="#F3F3F3" Foreground="#1F1F1F">
  <Window.Resources>
    <!-- 5.5.5: a new look: sections in white cards, switches, a coloured main button -->
    <Style x:Key="Card" TargetType="Border">
      <Setter Property="Background" Value="White"/>
      <Setter Property="BorderBrush" Value="#E3E3E3"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="CornerRadius" Value="8"/>
      <Setter Property="Padding" Value="20,16"/>
      <Setter Property="Margin" Value="0,0,0,24"/>
    </Style>
    <Style x:Key="Switch" TargetType="CheckBox">
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <Grid Background="Transparent">
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
              </Grid.ColumnDefinitions>
              <ContentPresenter VerticalAlignment="Center" Margin="0,0,16,0" RecognizesAccessKey="True"/>
              <Grid Grid.Column="1" Width="40" Height="20" VerticalAlignment="Center">
                <Border x:Name="Track" CornerRadius="10" BorderThickness="1" BorderBrush="#8A8A8A" Background="White"/>
                <Ellipse x:Name="Thumb" Width="12" Height="12" Fill="#5F5F5F" HorizontalAlignment="Left"
                         VerticalAlignment="Center" Margin="4,0,0,0"/>
              </Grid>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="Track" Property="Background" Value="#0F6CBD"/>
                <Setter TargetName="Track" Property="BorderBrush" Value="#0F6CBD"/>
                <Setter TargetName="Thumb" Property="Fill" Value="White"/>
                <Setter TargetName="Thumb" Property="Margin" Value="24,0,0,0"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.5"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="Primary" TargetType="Button">
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="Bg" Background="#0F6CBD" CornerRadius="4" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bg" Property="Background" Value="#115EA3"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="Bg" Property="Background" Value="#0C3B5E"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="Bg" Property="Background" Value="#A0A0A0"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="Tile" TargetType="RadioButton">
      <Setter Property="Margin" Value="0,0,12,12"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="RadioButton">
            <StackPanel Width="164">
              <Border x:Name="Frame" BorderThickness="3" BorderBrush="Transparent" CornerRadius="9" Padding="2">
                <ContentPresenter/>
              </Border>
              <TextBlock Text="{TemplateBinding Tag}" HorizontalAlignment="Center" Margin="0,5,0,0" TextTrimming="CharacterEllipsis"/>
            </StackPanel>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Frame" Property="BorderBrush" Value="#C8C8C8"/>
              </Trigger>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="Frame" Property="BorderBrush" Value="#0F6CBD"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.55"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <!-- 4.2: the play button on a background's picture (previews its video without picking it) -->
    <Style x:Key="PreviewButton" TargetType="Button">
      <Setter Property="Width" Value="30"/>
      <Setter Property="Height" Value="30"/>
      <Setter Property="HorizontalAlignment" Value="Right"/>
      <Setter Property="VerticalAlignment" Value="Bottom"/>
      <Setter Property="Margin" Value="0,0,6,6"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="Disc" CornerRadius="15" Background="#B3000000" BorderBrush="#E6FFFFFF" BorderThickness="1.5">
              <Path Data="M 0,0 L 9,5.5 L 0,11 Z" Fill="White" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="2,0,0,0"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Disc" Property="Background" Value="#E60F6CBD"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <DockPanel Background="#F3F3F3">
  <Border DockPanel.Dock="Bottom" Background="White" BorderBrush="#E5E5E5" BorderThickness="0,1,0,0" Padding="28,12,28,14">
   <StackPanel>
    <Grid>
      <StackPanel Orientation="Horizontal" VerticalAlignment="Center" HorizontalAlignment="Left">
        <TextBlock x:Name="ResetText" Margin="0,0,18,0">
          <Hyperlink x:Name="Reset">Use my organization's settings</Hyperlink>
        </TextBlock>
        <TextBlock Margin="0,0,18,0">
          <Hyperlink x:Name="WhatsNew">What's new</Hyperlink>
        </TextBlock>
        <TextBlock x:Name="TourText">
          <Hyperlink x:Name="TourLink">Take the Welcome to TLA tour</Hyperlink>
        </TextBlock>
      </StackPanel>
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
        <Button x:Name="PlayNow" Style="{StaticResource Primary}" Content="Play video now" MinWidth="96" Padding="14,6" Margin="0,0,8,0"/>
        <Button x:Name="CloseButton" Content="Close" MinWidth="96" Padding="14,6" IsCancel="True"/>
      </StackPanel>
    </Grid>
    <Grid Margin="0,8,0,0">
      <TextBlock x:Name="VersionText" Foreground="#8A8A8A" FontSize="12" HorizontalAlignment="Left"/>
      <TextBlock HorizontalAlignment="Right" FontSize="12" Margin="0,0,112,0">
        <Hyperlink x:Name="PlayQuiet">Play without sound</Hyperlink>
      </TextBlock>
      <!-- 5.6.0: the staff page (the lock screen announcement, and who uses what), behind TLA staff's Microsoft sign-in -->
      <TextBlock HorizontalAlignment="Right" FontSize="12" Margin="0,0,30,0">
        <Hyperlink x:Name="StaffLink">TLA staff</Hyperlink>
      </TextBlock>
    </Grid>
   </StackPanel>
  </Border>
  <ScrollViewer x:Name="Scroller" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
  <StackPanel Margin="28,22,28,18">
    <TextBlock Text="TLA BootPaper" FontSize="24" FontWeight="SemiBold"/>
    <TextBlock Text="Choose how your welcome video plays and pick your background for the desktop and lock screen."
               Foreground="#5F6368" TextWrapping="Wrap" Margin="0,4,0,18"/>

    <Border x:Name="AnnouncementBox" Visibility="Collapsed" Background="#FFF4CE" BorderBrush="#F2D57C"
            BorderThickness="1" CornerRadius="4" Padding="12,9" Margin="0,0,0,12">
      <TextBlock TextWrapping="Wrap"><Run FontWeight="SemiBold">Announcement:</Run> <Run x:Name="AnnouncementText"/></TextBlock>
    </Border>

    <Border Background="#E7F0FD" BorderBrush="#9CC3F5" BorderThickness="1" CornerRadius="4" Padding="12,9" Margin="0,0,0,18">
      <DockPanel>
        <!-- 4.3: Report a problem (report.ps1); 5.0: TLA Care (care.ps1) -->
        <Button x:Name="ReportProblem" DockPanel.Dock="Right" Content="Report a problem" Padding="14,5" Margin="8,0,0,0"
                VerticalAlignment="Center" Cursor="Hand"/>
        <Button x:Name="OpenCare" DockPanel.Dock="Right" Content="Check my computer" Padding="14,5" Margin="14,0,0,0"
                VerticalAlignment="Center" Cursor="Hand"/>
        <TextBlock TextWrapping="Wrap" Foreground="#102A4C" VerticalAlignment="Center">
          <Run FontWeight="SemiBold">Something not working?</Run> Report it here and your computer's details go along with it.
          For new background requests and ideas, email <Hyperlink x:Name="Helpdesk">helpdesk@schoolathome.ca</Hyperlink>.
        </TextBlock>
      </DockPanel>
    </Border>

    <!-- 5.2.5: Connect to TLA, on computers Intune doesn't manage -->
    <Border x:Name="ConnectBox" Visibility="Collapsed" Background="#DFF6DD" BorderBrush="#9FD89F" BorderThickness="1"
            CornerRadius="4" Padding="12,9" Margin="0,0,0,18">
      <DockPanel>
        <Button x:Name="ConnectTla" DockPanel.Dock="Right" Content="Connect to TLA" Padding="14,5" Margin="14,0,0,0"
                VerticalAlignment="Center" Cursor="Hand"/>
        <TextBlock TextWrapping="Wrap" Foreground="#0E3C0E" VerticalAlignment="Center">
          <Run FontWeight="SemiBold">Connect this computer to TLA.</Run> It isn't connected yet, so it's missing what TLA
          sends: the TLA new tab page in Chrome and Edge, apps and updates. Click Connect to TLA, then Connect, and sign in
          with your TLA account.
        </TextBlock>
      </DockPanel>
    </Border>

    <Border x:Name="LockedNote" Visibility="Collapsed" Background="#FFF4CE" BorderBrush="#F2D57C"
            BorderThickness="1" CornerRadius="4" Padding="12,8" Margin="0,0,0,18">
      <TextBlock Text="Your organization manages these settings, so they can't be changed here."
                 TextWrapping="Wrap"/>
    </Border>

    <TextBlock Text="Welcome video" FontSize="18" FontWeight="SemiBold" Margin="0,0,0,10"/>
    <Border Style="{StaticResource Card}">
    <StackPanel>
    <CheckBox x:Name="Enabled" Style="{StaticResource Switch}" Content="Play the welcome video when I sign in"/>

    <StackPanel x:Name="Options" Margin="0,14,0,0">
      <TextBlock Text="Which video" Foreground="#5F6368" Margin="0,0,0,8"/>
      <ComboBox x:Name="VideoChoice" Width="340" HorizontalAlignment="Left" Margin="0,0,0,16" Padding="8,5"/>

      <TextBlock Text="When to play it" Foreground="#5F6368" Margin="0,0,0,8"/>
      <RadioButton x:Name="EverySignIn" GroupName="PlayWhen" Margin="0,0,0,8"
                   Content="Every time I sign in"/>
      <RadioButton x:Name="OncePerDay" GroupName="PlayWhen" Margin="0,0,0,8"
                   Content="Once a day, the first time I sign in"/>
      <RadioButton x:Name="AfterUpdate" GroupName="PlayWhen" Margin="0,0,0,8"
                   Content="Only after Windows installs an update"/>
      <RadioButton x:Name="FirstTime" GroupName="PlayWhen" Margin="0,0,0,16"
                   Content="Only once, and again when there's a new video"/>

      <TextBlock Text="While it plays" Foreground="#5F6368" Margin="0,0,0,8"/>
      <CheckBox x:Name="Sound" Style="{StaticResource Switch}" Content="Play with sound" Margin="0,0,0,10"/>
      <CheckBox x:Name="AllowSkip" Style="{StaticResource Switch}" Content="Let me close it early with Esc or a click"/>

      <TextBlock Text="Quiet hours (for class time)" Foreground="#5F6368" Margin="0,16,0,8"/>
      <ComboBox x:Name="QuietMode" Width="340" HorizontalAlignment="Left" Padding="8,5"/>
      <StackPanel x:Name="QuietHours" Margin="0,10,0,0">
        <StackPanel Orientation="Horizontal">
          <TextBlock Text="From" VerticalAlignment="Center" Margin="0,0,8,0"/>
          <ComboBox x:Name="QuietStart" Width="90" Padding="8,4"/>
          <TextBlock Text="to" VerticalAlignment="Center" Margin="10,0,8,0"/>
          <ComboBox x:Name="QuietEnd" Width="90" Padding="8,4"/>
        </StackPanel>
        <WrapPanel x:Name="QuietDays" Margin="0,10,0,0"/>
      </StackPanel>

      <TextBlock Text="Greeting" Foreground="#5F6368" Margin="0,16,0,8"/>
      <!-- 5.5.5: on or off, keeping the name -->
      <CheckBox x:Name="GreetingOn" Style="{StaticResource Switch}" Content="Greet me by name when the video starts" Margin="0,0,0,10"/>
      <StackPanel Orientation="Horizontal">
        <TextBox x:Name="PreferredName" Width="220" Padding="6,4" MaxLength="30" VerticalContentAlignment="Center"/>
        <Button x:Name="SaveName" Content="Save" MinWidth="70" Padding="12,4" Margin="8,0,0,0" IsEnabled="False"/>
        <TextBlock x:Name="NameStatus" Foreground="#107C10" VerticalAlignment="Center" TextWrapping="Wrap" MaxWidth="300" Margin="10,0,0,0"/>
      </StackPanel>
      <TextBlock x:Name="NameHint" Foreground="#8A8A8A" FontSize="12" TextWrapping="Wrap" Margin="0,6,0,0"/>
    </StackPanel>

    <TextBlock x:Name="LastPlayed" Foreground="#5F6368" TextWrapping="Wrap" Margin="0,14,0,0"/>
    </StackPanel>
    </Border>

    <TextBlock Text="Background" FontSize="18" FontWeight="SemiBold" Margin="0,0,0,10"/>
    <TextBlock x:Name="BackgroundNote" Foreground="#5F6368" TextWrapping="Wrap" Margin="0,0,0,12"/>
    <!-- 4.2: how long a pick lasts, how the picture fits the screen, and the lock screen's own background -->
    <WrapPanel Margin="0,0,0,8">
      <StackPanel Margin="0,0,24,8">
        <TextBlock Text="Use my pick" Foreground="#5F6368" Margin="0,0,0,6"/>
        <ComboBox x:Name="PickFor" Width="190" Padding="8,5"/>
      </StackPanel>
      <StackPanel Margin="0,0,24,8">
        <TextBlock Text="Fit on the screen" Foreground="#5F6368" Margin="0,0,0,6"/>
        <ComboBox x:Name="FitChoice" Width="240" Padding="8,5"/>
      </StackPanel>
      <StackPanel Margin="0,0,24,8">
        <TextBlock Text="Lock screen" Foreground="#5F6368" Margin="0,0,0,6"/>
        <ComboBox x:Name="LockChoice" Width="220" Padding="8,5"/>
      </StackPanel>
      <!-- 5.0: light and dark -->
      <StackPanel x:Name="LightDarkBox" Margin="0,0,0,8">
        <TextBlock Text="Light or dark" Foreground="#5F6368" Margin="0,0,0,6"/>
        <ComboBox x:Name="LightDarkChoice" Width="240" Padding="8,5"/>
      </StackPanel>
    </WrapPanel>
    <Border x:Name="TempBox" Visibility="Collapsed" Background="#E7F0FD" BorderBrush="#9CC3F5"
            BorderThickness="1" CornerRadius="4" Padding="12,8" Margin="0,0,0,14">
      <TextBlock TextWrapping="Wrap" Foreground="#102A4C"><Run x:Name="TempText"/> <Hyperlink x:Name="TempEnd">Go back now</Hyperlink></TextBlock>
    </Border>
    <StackPanel x:Name="SeasonSection" Visibility="Collapsed">
      <TextBlock Text="Seasonal theme" Foreground="#5F6368" Margin="0,0,0,8"/>
      <WrapPanel x:Name="SeasonTiles" Margin="0,0,-12,0"/>
    </StackPanel>
    <TextBlock Text="With an intro video" Foreground="#5F6368" Margin="0,0,0,8"/>
    <WrapPanel x:Name="Tiles" Margin="0,0,-12,0"/>
    <StackPanel x:Name="MoreSection">
      <TextBlock Text="Intro videos coming soon" Foreground="#5F6368" Margin="0,6,0,2"/>
      <TextBlock Text="Until their own video is ready, these play the TLA Classic video." FontSize="12"
                 Foreground="#8A8A8A" TextWrapping="Wrap" Margin="0,0,0,8"/>
      <WrapPanel x:Name="MoreTiles" Margin="0,0,-12,0"/>
    </StackPanel>

    <!-- 5.0: screensaver, call backgrounds, TLA Care reminders -->
    <StackPanel x:Name="ExtrasSection" Margin="0,24,0,0">
      <TextBlock Text="Screensaver, calls and reminders" FontSize="18" FontWeight="SemiBold" Margin="0,0,0,10"/>
      <Border Style="{StaticResource Card}">
      <StackPanel>
      <CheckBox x:Name="ScreensaverOn" Style="{StaticResource Switch}" Content="Use the TLA screensaver: a slideshow of the TLA backgrounds"/>
      <TextBlock x:Name="ScreensaverNote" Foreground="#8A8A8A" FontSize="12" TextWrapping="Wrap" Margin="0,4,60,14"/>
      <CheckBox x:Name="CallsOn" Style="{StaticResource Switch}" Content="Add the TLA backgrounds to Microsoft Teams"/>
      <TextBlock Foreground="#8A8A8A" FontSize="12" TextWrapping="Wrap" Margin="0,4,60,14">
        <Run x:Name="CallsNote"/> <Hyperlink x:Name="OpenPictures">Open the pictures</Hyperlink>
      </TextBlock>
      <CheckBox x:Name="RemindersOn" Style="{StaticResource Switch}" Content="TLA Care reminders, for example when it's time to restart"/>
      </StackPanel>
      </Border>
    </StackPanel>

    <!-- 4.3: release channels -->
    <TextBlock Text="Updates" FontSize="18" FontWeight="SemiBold" Margin="0,0,0,4"/>
    <TextBlock Text="Choose when new backgrounds, intro videos and features reach you." Foreground="#5F6368"
               TextWrapping="Wrap" Margin="0,0,0,10"/>
    <Border Style="{StaticResource Card}">
    <StackPanel>
    <RadioButton x:Name="ChannelStable" GroupName="Channel" Margin="0,0,0,8" VerticalContentAlignment="Top">
      <TextBlock TextWrapping="Wrap"><Run FontWeight="SemiBold">Stable</Run> (recommended)<LineBreak/><Run Foreground="#5F6368" FontSize="12">New things arrive once they've been tried out.</Run></TextBlock>
    </RadioButton>
    <RadioButton x:Name="ChannelExperimental" GroupName="Channel" Margin="0,0,0,8" VerticalContentAlignment="Top">
      <TextBlock TextWrapping="Wrap"><Run FontWeight="SemiBold">Experimental</Run><LineBreak/><Run Foreground="#5F6368" FontSize="12">Get new backgrounds and features first. They might still have rough edges.</Run></TextBlock>
    </RadioButton>
    <TextBlock x:Name="ChannelStatus" Foreground="#5F6368" TextWrapping="Wrap" Margin="0,4,0,0"/>
    </StackPanel>
    </Border>

    <!-- 5.0: once per computer, for whoever sets it up -->
    <Border x:Name="UnboxBox" Visibility="Collapsed" Background="#F3F0FB" BorderBrush="#C9BCEB" BorderThickness="1"
            CornerRadius="8" Padding="14,12" Margin="0,0,0,0">
      <DockPanel>
        <Button x:Name="PrepareUnbox" DockPanel.Dock="Right" Content="Prepare for initial unboxing" Padding="14,6"
                Margin="14,0,0,0" VerticalAlignment="Center" Cursor="Hand"/>
        <TextBlock TextWrapping="Wrap" Foreground="#2B1F4D" VerticalAlignment="Center">
          <Run FontWeight="SemiBold">Setting this computer up for someone?</Run> When you're done, click this. The computer
          shuts down, and the next time it starts, they get the TLA Classic intro and the Welcome to TLA tour. This can
          only be done once.
        </TextBlock>
      </DockPanel>
    </Border>
  </StackPanel>
  </ScrollViewer>
  </DockPanel>
</Window>
'@

$window = [System.Windows.Markup.XamlReader]::Parse($xaml)
$c = @{}
foreach ($name in 'LockedNote', 'Enabled', 'Options', 'VideoChoice', 'Sound', 'AllowSkip', 'LastPlayed', 'BackgroundNote',
                  'Tiles', 'MoreSection', 'MoreTiles', 'ResetText', 'Reset', 'WhatsNew', 'Helpdesk', 'PlayNow', 'CloseButton', 'VersionText',
                  'AnnouncementBox', 'AnnouncementText', 'QuietMode', 'QuietHours', 'QuietStart', 'QuietEnd', 'QuietDays',
                  'PreferredName', 'SaveName', 'NameStatus', 'SeasonSection', 'SeasonTiles',
                  'PlayQuiet', 'PickFor', 'FitChoice', 'LockChoice', 'TempBox', 'TempText', 'TempEnd',
                  'ReportProblem', 'ChannelStable', 'ChannelExperimental', 'ChannelStatus',
                  'TourText', 'TourLink', 'OpenCare', 'LightDarkBox', 'LightDarkChoice', 'ExtrasSection', 'ScreensaverOn',
                  'ScreensaverNote', 'CallsOn', 'CallsNote', 'OpenPictures', 'RemindersOn', 'UnboxBox', 'PrepareUnbox',
                  'ConnectBox', 'ConnectTla', 'GreetingOn', 'NameHint', 'Scroller', 'StaffLink') {
    $c[$name] = $window.FindName($name)
}
# The organization's announcement (4.0), if there is one.
$announcement = Get-WVAnnouncement
if ($announcement) { $c.AnnouncementText.Text = $announcement; $c.AnnouncementBox.Visibility = 'Visible' }

# Quiet hours (4.0): the mode, the times (every 15 minutes) and the days.
$quietItems = [ordered]@{}
foreach ($id in $WV.QuietModes.Keys) {
    $item = [System.Windows.Controls.ComboBoxItem]::new(); $item.Tag = $id; $item.Content = $WV.QuietModes[$id]
    [void]$c.QuietMode.Items.Add($item); $quietItems[$id] = $item
}
$timeItems = @{ QuietStart = [ordered]@{}; QuietEnd = [ordered]@{} }
foreach ($box in 'QuietStart', 'QuietEnd') {
    for ($m = 0; $m -lt 1440; $m += 15) {
        $t = '{0:00}:{1:00}' -f [Math]::Floor($m / 60), ($m % 60)
        $item = [System.Windows.Controls.ComboBoxItem]::new(); $item.Tag = $t; $item.Content = $t
        [void]$c[$box].Items.Add($item); $timeItems[$box][$t] = $item
    }
}
$dayButtons = [ordered]@{}
foreach ($d in $WV.Days) {
    $b = [System.Windows.Controls.Primitives.ToggleButton]::new()
    $b.Content = $d; $b.Tag = $d; $b.MinWidth = 46; $b.Padding = '8,4'; $b.Margin = '0,0,6,0'
    [void]$c.QuietDays.Children.Add($b); $dayButtons[$d] = $b
}
foreach ($choice in $WV.PlayWhenChoices) { $c[$choice] = $window.FindName($choice) }
# 4.2: background options. "Use my pick" isn't saved: each time the app opens, a pick is for good unless they
# choose otherwise.
$pickItems = [ordered]@{}; $fitItems = [ordered]@{}; $lockItems = [ordered]@{}
foreach ($id in $WV.PickFor.Keys) {
    $item = [System.Windows.Controls.ComboBoxItem]::new(); $item.Tag = $id; $item.Content = $WV.PickFor[$id]
    [void]$c.PickFor.Items.Add($item); $pickItems[$id] = $item
}
$c.PickFor.SelectedItem = $pickItems['Always']
foreach ($id in $WV.FitModes.Keys) {
    $item = [System.Windows.Controls.ComboBoxItem]::new(); $item.Tag = $id; $item.Content = $WV.FitModes[$id]
    [void]$c.FitChoice.Items.Add($item); $fitItems[$id] = $item
}
$lightDarkItems = [ordered]@{}
foreach ($id in $WV.LightDarkModes.Keys) {
    $item = [System.Windows.Controls.ComboBoxItem]::new(); $item.Tag = $id; $item.Content = $WV.LightDarkModes[$id]
    [void]$c.LightDarkChoice.Items.Add($item); $lightDarkItems[$id] = $item
}
foreach ($id in @('same') + @($WV.Backgrounds.Keys)) {
    $item = [System.Windows.Controls.ComboBoxItem]::new(); $item.Tag = $id
    $item.Content = if ($id -eq 'same') { 'Same as my desktop' } else { $WV.Backgrounds[$id] }
    [void]$c.LockChoice.Items.Add($item); $lockItems[$id] = $item
}

try {
    # Loaded from memory so the app never holds the file open (an open file blocks updates).
    $iconBytes = [System.IO.File]::ReadAllBytes([System.IO.Path]::Combine($PSScriptRoot, 'welcome-video.ico'))
    $window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create(
        [System.IO.MemoryStream]::new($iconBytes), 'None', 'OnLoad')
} catch { }

# One tile per preset background. The id travels in the tile's DataContext. Backgrounds that don't have
# an intro video yet go in their own section. 4.0: "Surprise me" (a different one each day) after them, and
# the seasonal theme in its own section while it's on.
function New-WVTile([string]$Id, [string]$Name) {
    $image = [System.Windows.Controls.Image]::new()
    $image.Width   = 154
    $image.Height  = 87
    $image.Stretch = 'UniformToFill'
    try {
        $bitmap = [System.Windows.Media.Imaging.BitmapImage]::new()
        $bitmap.BeginInit()
        $file = Get-WVThumbnailPath $Id (Get-WVMode)   # (5.0: as it looks in their light or dark mode)
        if (-not [System.IO.File]::Exists($file)) { $file = Get-WVShownPath $Id }
        $bitmap.UriSource        = [System.Uri]::new($file)
        $bitmap.CacheOption      = 'OnLoad'
        $bitmap.DecodePixelWidth = 320
        $bitmap.EndInit()
        $image.Source = $bitmap
    } catch { }
    $image.Clip = [System.Windows.Media.RectangleGeometry]::new([System.Windows.Rect]::new(0, 0, 154, 87), 4, 4)
    $tile = [System.Windows.Controls.RadioButton]::new()
    $tile.Style       = $window.FindResource('Tile')
    $tile.GroupName   = 'Background'
    # 4.2: a play button on backgrounds with an intro video: previews it without picking the background.
    # (4.2.5: the picture goes in the tile OR in the frame with the button, never both: WPF refuses to give an
    # element two parents, and in 4.2 that error stopped the app from opening.)
    $videoFile = [System.IO.Path]::Combine($WV.Dir, 'Videos', "$Id.mp4")
    if (-not ($WV.VideoHashes.Contains($Id) -and [System.IO.File]::Exists($videoFile))) {
        $tile.Content = $image
    } else {
        $grid = [System.Windows.Controls.Grid]::new()
        [void]$grid.Children.Add($image)
        $play = [System.Windows.Controls.Button]::new()
        $play.Style   = $window.FindResource('PreviewButton')
        $play.Tag     = $Id
        $play.ToolTip = "Play the $Name video"
        $play.Add_Click({
            param($s, $e)
            $e.Handled = $true
            try { Start-WVScript 'play-video.ps1' ('-Force -Preview "{0}"' -f $s.Tag) } catch { }
        })
        [void]$grid.Children.Add($play)
        $tile.Content = $grid
    }
    $tile.DataContext = $Id
    $tile.Tag         = $Name
    return $tile
}
$tiles = [ordered]@{}
foreach ($id in $WV.Backgrounds.Keys) {
    $tile = New-WVTile $id $WV.Backgrounds[$id]
    if ($WV.Videos.Contains($id)) { [void]$c.Tiles.Children.Add($tile) } else { [void]$c.MoreTiles.Children.Add($tile) }
    $tiles[$id] = $tile
}
$tiles['surprise'] = New-WVTile 'surprise' 'Surprise me'
$tiles['surprise'].ToolTip = 'A different background every day'
[void]$c.Tiles.Children.Add($tiles['surprise'])
if ($c.MoreTiles.Children.Count -eq 0) { $c.MoreSection.Visibility = 'Collapsed' }
$season = Get-WVSeason
$seasonTile = $null
if ($season -and [System.IO.File]::Exists("$(Get-WVBackgroundPath $season)")) {
    $seasonTile = New-WVTile $season $WV.Seasonal[$season]
    $seasonTile.ToolTip = "Until $($WV.SeasonEnds[$season])"
    [void]$c.SeasonTiles.Children.Add($seasonTile)
    $c.SeasonSection.Visibility = 'Visible'
}

# One entry per intro video. The id travels in each entry's Tag.
$videoItems = [ordered]@{}
foreach ($id in $WV.Videos.Keys) {
    $item = [System.Windows.Controls.ComboBoxItem]::new()
    $item.Tag = $id
    [void]$c.VideoChoice.Items.Add($item)
    $videoItems[$id] = $item
}

# Names the videos, marking the organization's default and saying which one "match" plays right now.
function Update-VideoLabels {
    $orgVideo = "$(Get-WVOrgSetting 'Video')"
    foreach ($id in $videoItems.Keys) {
        $label = $WV.Videos[$id]
        if ($id -eq 'match') {
            # What "match" plays right now: the file Get-WVVideoPath picks, named.
            $file = [System.IO.Path]::GetFileNameWithoutExtension((Get-WVVideoPath 'match'))
            $playing = if ($WV.Seasonal.Contains($file)) { $WV.Seasonal[$file] }
                       elseif ($WV.Videos.Contains($file)) { $WV.Videos[$file] } else { $WV.Videos['tla'] }
            $label = "$label ($playing)"
        }
        if ($id -eq $orgVideo) { $label = "$label - default" }
        $videoItems[$id].Content = $label
    }
}

$ui = @{ Loading = $false }

# Show the settings in effect for this person.
function Update-Controls {
    $ui.Loading = $true
    $locked      = -not (Test-WVUsersCanChange)
    $deskLocked  = Test-WVBackgroundLocked
    $lockScreenLocked = Test-WVLockScreenLocked
    $bgLocked    = $deskLocked -and $lockScreenLocked

    foreach ($name in 'Enabled', 'Sound', 'AllowSkip') { $c[$name].IsChecked = (Test-WVOn $name) }
    $c["$(Get-WVSetting 'PlayWhen')"].IsChecked = $true
    Update-VideoLabels
    $c.VideoChoice.SelectedItem = $videoItems["$(Get-WVSetting 'Video')"]

    $c.Enabled.IsEnabled     = -not $locked
    $c.Options.IsEnabled     = (-not $locked) -and [bool]$c.Enabled.IsChecked
    $c.LockedNote.Visibility = if ($locked) { 'Visible' } else { 'Collapsed' }
    $c.ResetText.Visibility  = if ($locked) { 'Collapsed' } else { 'Visible' }

    # Quiet hours and the greeting (4.0).
    $mode = "$(Get-WVSetting 'QuietMode')"
    $c.QuietMode.SelectedItem  = $quietItems[$mode]
    $c.QuietStart.SelectedItem = $timeItems.QuietStart["$(Get-WVSetting 'QuietStart')"]
    $c.QuietEnd.SelectedItem   = $timeItems.QuietEnd["$(Get-WVSetting 'QuietEnd')"]
    $days = "$(Get-WVSetting 'QuietDays')".Split(',')
    foreach ($d in $dayButtons.Keys) { $dayButtons[$d].IsChecked = ($days -contains $d) }
    $c.QuietHours.Visibility = if ($mode -eq 'Hours') { 'Visible' } else { 'Collapsed' }
    if (-not $c.PreferredName.IsKeyboardFocused) { $c.PreferredName.Text = "$(Get-WVSetting 'PreferredName')" }
    # 5.5.5: the greeting on or off (their name stays), once that's out on their channel
    $greetSwitch = Test-WVReleased 'greeting-switch'
    $greetOn = (-not $greetSwitch) -or "$(Get-WVSetting 'Greeting')" -ne '0'
    $c.GreetingOn.Visibility = if ($greetSwitch) { 'Visible' } else { 'Collapsed' }
    $c.GreetingOn.IsChecked = $greetOn
    $c.PreferredName.IsEnabled = $greetOn
    $c.NameHint.Text = if (-not $greetSwitch) { "The video says $([char]0x201C)Good morning$([char]0x201D) with your name. Leave it empty and save for no greeting." }
        elseif (Test-WVReleased 'greeting-styles') { "The video says $([char]0x201C)Good morning$([char]0x201D) with your name, in the style of its theme. Turned off, the greeting doesn't show and your name stays saved." }
        else { "The video says $([char]0x201C)Good morning$([char]0x201D) with your name. Turned off, the greeting doesn't show and your name stays saved." }
    Update-NameButton

    $orgBackground = "$(Get-WVOrgSetting 'Background')"
    foreach ($id in $tiles.Keys) {
        if ($id -ne 'surprise') {
            $tiles[$id].Tag = if ($id -eq $orgBackground) { "$($WV.Backgrounds[$id]) (default)" } else { $WV.Backgrounds[$id] }
            # 4.3: only what's out on their release channel (the organization's default always shows).
            $tiles[$id].Visibility = if ((Test-WVReleased $id) -or $id -eq $orgBackground) { 'Visible' } else { 'Collapsed' }
        }
        $tiles[$id].IsEnabled = -not ($locked -or $bgLocked)
    }
    foreach ($id in $lockItems.Keys) {
        $lockItems[$id].Visibility = if ((Test-WVReleased $id) -or $id -eq $orgBackground) { 'Visible' } else { 'Collapsed' }
    }
    foreach ($id in $videoItems.Keys) {
        $videoItems[$id].Visibility = if ((Test-WVReleased $id) -or $id -eq "$(Get-WVOrgSetting 'Video')") { 'Visible' } else { 'Collapsed' }
    }

    # Release channel (4.3).
    $channel = Get-WVChannel
    $c.ChannelStable.IsChecked       = ($channel -eq 'stable')
    $c.ChannelExperimental.IsChecked = ($channel -eq 'experimental')
    $c.ChannelStable.IsEnabled       = -not $locked
    $c.ChannelExperimental.IsEnabled = -not $locked
    $stableRel = Get-WVChannelRelease 'stable'
    $expRel    = Get-WVChannelRelease 'experimental'
    $c.ChannelStatus.Text = if ($channel -eq 'experimental') {
        "You're on Experimental: version $(Get-WVShownRelease)." +
        $(if ((ConvertTo-WVVersion $expRel) -gt (ConvertTo-WVVersion $stableRel)) { " Stable is on version $stableRel." } else { ' Right now it has the same as Stable.' })
    } else {
        "You're on Stable: version $(Get-WVShownRelease)." +
        $(if ((ConvertTo-WVVersion $expRel) -gt (ConvertTo-WVVersion $stableRel)) { " Experimental has version $expRel to try." } else { '' })
    }
    $c.VersionText.Text = "Version $(Get-WVShownRelease) $([char]0x00B7) $($WV.Channels[$channel])"
    $c.ReportProblem.Visibility = if (Test-WVReleased 'report') { 'Visible' } else { 'Collapsed' }

    # 5.0: light and dark, the screensaver, call backgrounds, TLA Care, the tour, unboxing.
    $c.LightDarkBox.Visibility = if (Test-WVReleased 'lightdark') { 'Visible' } else { 'Collapsed' }
    $c.LightDarkChoice.SelectedItem = $lightDarkItems["$(Get-WVSetting 'LightDark')"]
    $c.LightDarkChoice.IsEnabled = -not ($locked -or $bgLocked)
    $care = Test-WVReleased 'care'
    $c.ExtrasSection.Visibility = if ((Test-WVReleased 'screensaver') -or (Test-WVReleased 'calls') -or $care) { 'Visible' } else { 'Collapsed' }
    $saverStatus = "$(Get-WVValue $WV.StateKey 'ScreensaverStatus')"
    $c.ScreensaverOn.Visibility = if (Test-WVReleased 'screensaver') { 'Visible' } else { 'Collapsed' }
    $c.ScreensaverNote.Visibility = $c.ScreensaverOn.Visibility
    $c.ScreensaverOn.IsChecked = (Test-WVOn 'Screensaver') -and $saverStatus -ne 'theirs' -and $saverStatus -ne 'policy'
    $c.ScreensaverOn.IsEnabled = -not $locked -and $saverStatus -ne 'policy'
    $c.ScreensaverNote.Text = switch ($saverStatus) {
        'policy' { 'Your organization sets the screen saver on this PC.' }
        'theirs' { 'You have a screen saver of your own. Tick this to use the TLA one instead.' }
        default  { 'It starts after a few minutes without use. (To change the time, search the Start menu for "screen saver".)' }
    }
    $c.CallsOn.Visibility = if (Test-WVReleased 'calls') { 'Visible' } else { 'Collapsed' }
    $c.CallsOn.IsChecked  = Test-WVOn 'CallBackgrounds'
    $c.CallsOn.IsEnabled  = -not $locked
    $c.CallsNote.Text = if ("$(Get-WVValue $WV.StateKey 'CallBackgroundStatus')" -eq 'no-teams') {
        "Microsoft Teams isn't on this computer yet. For Zoom or other apps, add them yourself:"
    } else { 'In a Teams meeting: More > Video effects. For Zoom or other apps, add them yourself:' }
    $c.RemindersOn.Visibility = if ($care) { 'Visible' } else { 'Collapsed' }
    $c.RemindersOn.IsChecked  = Test-WVOn 'CareReminders'
    $c.RemindersOn.IsEnabled  = -not $locked
    $c.OpenCare.Visibility = if ($care) { 'Visible' } else { 'Collapsed' }
    $c.TourText.Visibility = if (Test-WVReleased 'tour') { 'Visible' } else { 'Collapsed' }
    $c.ConnectBox.Visibility = if (Test-WVConnectNeeded) { 'Visible' } else { 'Collapsed' }   # (5.2.5)
    $c.UnboxBox.Visibility = if ("$(Get-WVValue 'HKEY_LOCAL_MACHINE\SOFTWARE\WelcomeVideo\Unbox' 'State')" -eq 'ready') { 'Visible' } else { 'Collapsed' }
    $current    = Get-WVCurrentBackground
    $temp       = Get-WVTemporaryBackground
    $seasonalOn = $seasonTile -and $current -eq $season -and -not $temp
    if ($seasonTile) { $seasonTile.IsEnabled = -not ($locked -or $bgLocked) }
    if ($temp) { $tiles[$temp].IsChecked = $true }
    elseif ($seasonalOn) { $seasonTile.IsChecked = $true }
    else { $tiles["$(Get-WVSetting 'Background')"].IsChecked = $true }

    # 4.2: background options, and a note while a pick is just for a while.
    $c.FitChoice.SelectedItem  = $fitItems["$(Get-WVSetting 'WallpaperFit')"]
    $c.LockChoice.SelectedItem = $lockItems["$(Get-WVSetting 'LockBackground')"]
    $c.PickFor.IsEnabled    = -not ($locked -or $bgLocked)
    $c.FitChoice.IsEnabled  = -not ($locked -or $deskLocked)
    $c.LockChoice.IsEnabled = -not ($locked -or $lockScreenLocked)
    if ($temp) {
        $until = [DateTime]::ParseExact("$(Get-WVSetting 'TempUntil')", 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
        $after = if ($season -and (Test-WVOnDefaultBackground)) { $WV.Seasonal[$season] }
                 elseif ("$(Get-WVSetting 'Background')" -eq 'surprise') { 'Surprise me' }
                 else { $WV.Backgrounds["$(Get-WVSetting 'Background')"] }
        $c.TempText.Text = if ($until -le (Get-WVToday)) {
            "You're using $($WV.Backgrounds[$temp]) just for today. Tomorrow it goes back to $after."
        } else {
            "You're using $($WV.Backgrounds[$temp]) until {0:dddd, MMMM d}. Then it goes back to $after." -f $until
        }
        $c.TempBox.Visibility = 'Visible'
    } else {
        $c.TempBox.Visibility = 'Collapsed'
    }
    $name = if ($season) { $WV.Seasonal[$season] } else { '' }
    # (4.2: with a lock screen background of its own, picks change just the desktop)
    $lockOwn = "$(Get-WVSetting 'LockBackground')" -ne 'same'
    $where   = if ($lockOwn) { 'Your desktop' } else { 'Your desktop and lock screen' }
    $c.BackgroundNote.Text = if ($bgLocked) {
        'Your organization sets the desktop and lock screen pictures on this PC, so they can''t be changed here.'
    } elseif ($seasonalOn) {
        "It's $(if ($season -eq 'fall') { 'fall' } else { $name }) time! $where show$(if ($lockOwn) { 's' }) the $name theme until $($WV.SeasonEnds[$season]). Pick a background below to use your own instead."
    } elseif ($deskLocked) {
        'Your organization sets the desktop background on this PC. The one you pick is used for the lock screen.'
    } elseif ($lockScreenLocked) {
        'Your desktop changes as soon as you pick one. (Your organization sets the lock screen picture on this PC.)'
    } elseif ($seasonTile) {
        "$where change$(if ($lockOwn) { 's' }) as soon as you pick one. Click the $name theme to use it until $($WV.SeasonEnds[$season])."
    } elseif ("$(Get-WVSetting 'Background')" -eq 'surprise') {
        "Surprise me: today's background is $($WV.Backgrounds[$current]). Tomorrow brings another (from your next sign-in)."
    } else {
        "$where change$(if ($lockOwn) { 's' }) as soon as you pick one. They're yours alone: other people who use this PC keep their own."
    }

    $last = Get-WVLastPlayed
    $c.LastPlayed.Text = if ($last) {
        'Last played for you on this PC: {0:D}, {0:t}' -f $last
    } else {
        "It hasn't played for you on this PC yet."
    }
    $ui.Loading = $false
}

function Save-UserSetting([string]$Name, $Value) {
    if ($ui.Loading) { return }
    try {
        [Microsoft.Win32.Registry]::SetValue($WV.UserKey, $Name, $Value)
    } catch {
        [System.Windows.MessageBox]::Show("Couldn't save that change: $($_.Exception.Message)", 'TLA BootPaper') | Out-Null
    }
    $c.Options.IsEnabled = [bool]$c.Enabled.IsChecked
}

foreach ($name in 'Enabled', 'Sound', 'AllowSkip') {
    $c[$name].Add_Checked({   param($s, $e) Save-UserSetting $s.Name 1 })
    $c[$name].Add_Unchecked({ param($s, $e) Save-UserSetting $s.Name 0 })
}
foreach ($choice in $WV.PlayWhenChoices) {
    $c[$choice].Add_Checked({ param($s, $e) Save-UserSetting 'PlayWhen' $s.Name })
}
$c.VideoChoice.Add_SelectionChanged({
    param($s, $e)
    if ($ui.Loading -or -not $s.SelectedItem) { return }
    Save-UserSetting 'Video' "$($s.SelectedItem.Tag)"
})
# Forgets a pick that was just for a while (4.2).
function Clear-TempBackground {
    try {
        $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\WelcomeVideo', $true)
        if ($key) { $key.DeleteValue('TempBackground', $false); $key.DeleteValue('TempUntil', $false); $key.Close() }
    } catch { }
}
foreach ($tile in $tiles.Values) {
    $tile.Add_Checked({
        param($s, $e)
        if ($ui.Loading) { return }
        $for = "$($c.PickFor.SelectedItem.Tag)"
        if ($for -ne 'Always' -and "$($s.DataContext)" -ne 'surprise') {
            # Just for a while: the pick lasts until the end of today, or a week; then what was there comes back.
            $until = (Get-WVToday).AddDays($(if ($for -eq 'Week') { 6 } else { 0 })).ToString('yyyy-MM-dd')
            Save-UserSetting 'TempBackground' "$($s.DataContext)"
            Save-UserSetting 'TempUntil' $until
        } else {
            Save-UserSetting 'Background' "$($s.DataContext)"
            Clear-TempBackground
        }
        Update-Controls
        try { Start-WVScript 'apply-background.ps1' '-FromApp' } catch { }
    })
}
# Back to the seasonal theme: forget the background they picked (they're on the default again).
if ($seasonTile) {
    $seasonTile.Add_Checked({
        param($s, $e)
        if ($ui.Loading) { return }
        try {
            $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\WelcomeVideo', $true)
            if ($key) { $key.DeleteValue('Background', $false); $key.Close() }
        } catch { }
        Clear-TempBackground
        Update-Controls
        try { Start-WVScript 'apply-background.ps1' '-FromApp' } catch { }
    })
}

# 4.2: fit, lock screen, "Go back now", and playing without sound.
$c.FitChoice.Add_SelectionChanged({
    param($s, $e)
    if ($ui.Loading -or -not $s.SelectedItem) { return }
    Save-UserSetting 'WallpaperFit' "$($s.SelectedItem.Tag)"
    try { Start-WVScript 'apply-background.ps1' '-FromApp' } catch { }
})
$c.LockChoice.Add_SelectionChanged({
    param($s, $e)
    if ($ui.Loading -or -not $s.SelectedItem) { return }
    Save-UserSetting 'LockBackground' "$($s.SelectedItem.Tag)"
    Update-Controls
    try { Start-WVScript 'apply-background.ps1' '-FromApp' } catch { }
})
$c.TempEnd.Add_Click({
    Clear-TempBackground
    Update-Controls
    try { Start-WVScript 'apply-background.ps1' '-FromApp' } catch { }
})
$c.PlayQuiet.Add_Click({ try { Start-WVScript 'play-video.ps1' '-Force -Mute' } catch { } })
$c.StaffLink.Add_Click({ try { [void][System.Diagnostics.Process]::Start('https://ebuskell-source.github.io/Default-wallpaper/TLA-BootPaper/admin/') } catch { } })   # (5.6.0)

# Quiet hours and the greeting (4.0).
$c.QuietMode.Add_SelectionChanged({
    param($s, $e)
    if ($ui.Loading -or -not $s.SelectedItem) { return }
    Save-UserSetting 'QuietMode' "$($s.SelectedItem.Tag)"
    $c.QuietHours.Visibility = if ("$($s.SelectedItem.Tag)" -eq 'Hours') { 'Visible' } else { 'Collapsed' }
})
foreach ($box in 'QuietStart', 'QuietEnd') {
    $c[$box].Add_SelectionChanged({
        param($s, $e)
        if ($ui.Loading -or -not $s.SelectedItem) { return }
        Save-UserSetting $s.Name "$($s.SelectedItem.Tag)"
    })
}
foreach ($b in $dayButtons.Values) {
    $handler = {
        param($s, $e)
        if ($ui.Loading) { return }
        Save-UserSetting 'QuietDays' ((@($dayButtons.Keys | Where-Object { $dayButtons[$_].IsChecked })) -join ',')
    }
    $b.Add_Checked($handler); $b.Add_Unchecked($handler)
}
# The greeting's name (4.0.5): saved with the Save button (or Enter), and when the window closes.
function Get-NameInBox { return ($c.PreferredName.Text -replace '\s+', ' ').Trim() }
function Update-NameButton {
    $c.SaveName.IsEnabled = (Get-NameInBox) -ne "$(Get-WVSetting 'PreferredName')"
}
function Save-Name {
    $name = Get-NameInBox
    if (-not (Test-WVValid 'PreferredName' $name)) { $c.NameStatus.Text = ''; return }
    try {
        [Microsoft.Win32.Registry]::SetValue($WV.UserKey, 'PreferredName', $name)
        [Microsoft.Win32.Registry]::SetValue($WV.StateKey, 'NameAsked', 1)   # (no need to ask at sign-in now)
    } catch {
        [System.Windows.MessageBox]::Show("Couldn't save your name: $($_.Exception.Message)", 'TLA BootPaper') | Out-Null
        return
    }
    $ui.Loading = $true; $c.PreferredName.Text = $name; $ui.Loading = $false
    $tick = [string][char]0x2713
    $c.NameStatus.Text = if ($name) { "Saved $tick  Your video will say: $(Get-WVGreeting)" } else { "Saved $tick  No greeting." }
    Update-NameButton
}
$c.PreferredName.Add_TextChanged({
    param($s, $e)
    if ($ui.Loading) { return }
    $c.NameStatus.Text = ''
    Update-NameButton
})
$c.GreetingOn.Add_Checked({   param($s, $e) if ($ui.Loading) { return }; Save-UserSetting 'Greeting' 1; $c.NameStatus.Text = ''; Update-Controls })
$c.GreetingOn.Add_Unchecked({ param($s, $e) if ($ui.Loading) { return }; Save-UserSetting 'Greeting' 0; $c.NameStatus.Text = ''; Update-Controls })
$c.PreferredName.Add_KeyDown({ param($s, $e) if ($e.Key -eq 'Return') { Save-Name; $e.Handled = $true } })
$c.SaveName.Add_Click({ Save-Name })
$window.Add_Closing({ if ($c.SaveName.IsEnabled) { Save-Name } })

# Forget this person's choices so the organization's settings apply again (including the background).
# Their name for the greeting stays (5.5.5: and whether the greeting is on).
$c.Reset.Add_Click({
    try {
        $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\WelcomeVideo', $true)
        if ($key) {
            foreach ($name in $WV.Names) { if ($name -ne 'PreferredName' -and $name -ne 'Greeting') { $key.DeleteValue($name, $false) } }   # (5.5.5: and Greeting)
            $key.Close()
        }
    } catch { }
    Update-Controls
    if (Test-WVBackgroundNeeded) { try { Start-WVScript 'apply-background.ps1' '-FromApp' } catch { } }
    else { [void](Start-WVDeviceBackgroundUpdate) }
})

# Requests, bug reports and ideas (3.3.6): opens a new email in the person's mail app, with this PC's
# details filled in (4.0).
$c.Helpdesk.Add_Click({ try { [void][System.Diagnostics.Process]::Start((Get-WVHelpdeskLink)) } catch { } })

# Report a problem (4.3): a short form, then an email with the details (report.ps1).
$c.ReportProblem.Add_Click({
    try {
        $reportWindow = New-WVReportWindow
        $reportWindow.Owner = $window
        $reportWindow.WindowStartupLocation = 'CenterOwner'
        [void]$reportWindow.ShowDialog()
    } catch {
        [void][System.Windows.MessageBox]::Show("Couldn't open the form: $($_.Exception.Message)`n`nPlease email $($WV.Helpdesk) instead.", 'TLA BootPaper')
    }
})

# Release channel (4.3). Moving to Stable hides what's still experimental; a background or video picked from
# that goes back to what was there before, so the desktop is updated.
function Set-WVChannel([string]$Channel) {
    if ($ui.Loading) { return }
    Save-UserSetting 'Channel' $Channel
    Update-Controls
    if (Test-WVBackgroundNeeded) { try { Start-WVScript 'apply-background.ps1' '-FromApp' } catch { } }
    else { [void](Start-WVDeviceBackgroundUpdate) }
}
$c.ChannelStable.Add_Checked({ Set-WVChannel 'stable' })
$c.ChannelExperimental.Add_Checked({ Set-WVChannel 'experimental' })

# ---- 5.0 -------------------------------------------------------------------------------------------------
$c.LightDarkChoice.Add_SelectionChanged({
    param($s, $e)
    if ($ui.Loading -or -not $s.SelectedItem) { return }
    Save-UserSetting 'LightDark' "$($s.SelectedItem.Tag)"
    try { Start-WVScript 'apply-background.ps1' '-FromApp' } catch { }
})
# Turning these on or off takes effect straight away (session.ps1 does the work), then the note is refreshed.
function Start-WVSessionPart([string]$Part) {
    try { Start-WVScript 'session.ps1' "-Only $Part" } catch { }
    $timer = [System.Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromSeconds(4)
    $timer.Add_Tick({ param($s, $e) $s.Stop(); Update-Controls })
    $timer.Start()
}
$c.ScreensaverOn.Add_Checked({   param($s, $e) if ($ui.Loading) { return }; Save-UserSetting 'Screensaver' 1; Start-WVSessionPart 'Screensaver' })
$c.ScreensaverOn.Add_Unchecked({ param($s, $e) if ($ui.Loading) { return }; Save-UserSetting 'Screensaver' 0; Start-WVSessionPart 'Screensaver' })
$c.CallsOn.Add_Checked({         param($s, $e) if ($ui.Loading) { return }; Save-UserSetting 'CallBackgrounds' 1; Start-WVSessionPart 'Calls' })
$c.CallsOn.Add_Unchecked({       param($s, $e) if ($ui.Loading) { return }; Save-UserSetting 'CallBackgrounds' 0; Start-WVSessionPart 'Calls' })
$c.RemindersOn.Add_Checked({     param($s, $e) Save-UserSetting 'CareReminders' 1 })
$c.RemindersOn.Add_Unchecked({   param($s, $e) Save-UserSetting 'CareReminders' 0 })
$c.OpenPictures.Add_Click({
    try { [void][System.Diagnostics.Process]::Start('explorer.exe', "`"$([System.IO.Path]::Combine($WV.Dir, 'Wide'))`"") } catch { }
})
$c.ConnectTla.Add_Click({ try { [void][System.Diagnostics.Process]::Start($WV.ConnectPage) } catch { } })   # (5.2.5)
$c.OpenCare.Add_Click({
    try {
        $careWindow = New-WVCareWindow
        $careWindow.Owner = $window
        $careWindow.WindowStartupLocation = 'CenterOwner'
        [void]$careWindow.ShowDialog()
    } catch {
        [void][System.Windows.MessageBox]::Show("Couldn't open TLA Care: $($_.Exception.Message)", 'TLA BootPaper')
    }
})
$c.TourLink.Add_Click({
    try {
        $tourWindow = New-WVTourWindow
        $tourWindow.Owner = $window
        $tourWindow.WindowStartupLocation = 'CenterOwner'
        [void]$tourWindow.ShowDialog()
        Update-Controls
    } catch { }
})
# "Prepare for initial unboxing": confirm, then the TLA Care task (as SYSTEM) marks the computer and shuts it down.
$c.PrepareUnbox.Add_Click({
    $answer = [System.Windows.MessageBox]::Show(
        "Prepare this computer for unboxing?`n`nIt shuts down straight away, so save your work first. The next time it starts, whoever signs in gets the TLA Classic intro and the Welcome to TLA tour.`n`nThis can only be done once on this computer.",
        'Prepare for initial unboxing', 'OKCancel', 'Warning')
    if ("$answer" -ne 'OK') { return }
    $at = Invoke-WVCareRequest 'unbox'
    if (-not $at) {
        [void][System.Windows.MessageBox]::Show("Couldn't prepare the computer. Try again in a moment, or restart it and try again.", 'TLA BootPaper')
        return
    }
    $c.PrepareUnbox.IsEnabled = $false
    $c.PrepareUnbox.Content = 'Shutting down...'
    $timer = [System.Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromSeconds(1)
    $timer.Tag = @{ At = $at; Until = [DateTime]::Now.AddSeconds(45) }
    $timer.Add_Tick({
        param($s, $e)
        $result = Get-WVCareResult 'unbox' $s.Tag.At
        if ($result -and $result.Text -notlike 'Shutting down*') {
            $s.Stop()
            $c.PrepareUnbox.Content = 'Prepare for initial unboxing'
            [void][System.Windows.MessageBox]::Show($result.Text, 'TLA BootPaper')
            Update-Controls
        } elseif (-not $result -and [DateTime]::Now -gt $s.Tag.Until) {
            $s.Stop()
            $c.PrepareUnbox.IsEnabled = $true
            $c.PrepareUnbox.Content = 'Prepare for initial unboxing'
            [void][System.Windows.MessageBox]::Show("The computer didn't answer. Try again in a moment.", 'TLA BootPaper')
        }
    })
    $timer.Start()
})

$c.WhatsNew.Add_Click({
    try {
        $news = New-WVWhatsNewWindow -FromApp
        $news.Owner = $window
        $news.WindowStartupLocation = 'CenterOwner'
        [void]$news.ShowDialog()
    } catch { }
})

# Plays the chosen video right away, whatever the other settings say, so people can see what it looks like.
$c.PlayNow.Add_Click({ try { Start-WVScript 'play-video.ps1' '-Force' } catch { } })

$c.CloseButton.Add_Click({ $window.Close() })

# Opens at the height of its contents, but never taller than the screen (it scrolls instead). After that
# it can be resized freely.
$workArea = [System.Windows.SystemParameters]::WorkArea
$window.MaxHeight = [Math]::Max(360, $workArea.Height - 16)
if ($window.Width -gt $workArea.Width - 16) { $window.Width = [Math]::Max(520, $workArea.Width - 16) }
$window.Add_ContentRendered({
    $window.SizeToContent = 'Manual'
    $window.MaxHeight     = [double]::PositiveInfinity
})

# 5.5.5: gentler scrolling. WPF moves three lines for every wheel message, whatever its size, so a touchpad (which
# sends many small ones) raced down the page. Now it moves in proportion to the wheel or touchpad, and smoothly.
# (An open list, like the video menu, still scrolls itself.)
$script:scrollTo = $null
$script:scrollTimer = [System.Windows.Threading.DispatcherTimer]::new()
$script:scrollTimer.Interval = [TimeSpan]::FromMilliseconds(15)
$script:scrollTimer.Add_Tick({
    $sv = $c.Scroller; $now = $sv.VerticalOffset; $to = $script:scrollTo
    if ($null -eq $to -or [Math]::Abs($to - $now) -lt 0.5) {
        if ($null -ne $to) { $sv.ScrollToVerticalOffset($to) }
        $script:scrollTo = $null; $script:scrollTimer.Stop(); return
    }
    $sv.ScrollToVerticalOffset($now + ($to - $now) * 0.3)
})
$c.Scroller.Add_PreviewMouseWheel({
    param($s, $e)
    try {
        $src = $e.OriginalSource -as [System.Windows.Media.Visual]
        if ($src -and -not $s.IsAncestorOf($src)) { return }
    } catch { }
    $e.Handled = $true
    $from = if ($null -ne $script:scrollTo) { $script:scrollTo } else { $s.VerticalOffset }
    $script:scrollTo = [Math]::Max(0, [Math]::Min($s.ScrollableHeight, $from - $e.Delta * 0.35))
    if (-not $script:scrollTimer.IsEnabled) { $script:scrollTimer.Start() }
})

Update-Controls
if ($env:TB_TEST) {
    # Developer check (TB_TEST=<folder>): pictures of the window in a few states, then it closes. Not used normally.
    $window.Show()
    $pump = {
        param($ms)
        $f = [System.Windows.Threading.DispatcherFrame]::new()
        $t = [System.Windows.Threading.DispatcherTimer]::new(); $t.Interval = [TimeSpan]::FromMilliseconds($ms); $t.Tag = $f
        $t.Add_Tick({ param($s, $e) $s.Stop(); $s.Tag.Continue = $false }); $t.Start()
        [System.Windows.Threading.Dispatcher]::PushFrame($f)
    }
    $shot = {
        param($name)
        & $pump 500
        $v = $window.Content
        $r = [System.Windows.Media.Imaging.RenderTargetBitmap]::new([int]$v.ActualWidth, [int]$v.ActualHeight, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
        $r.Render($v)
        $enc = [System.Windows.Media.Imaging.PngBitmapEncoder]::new(); $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($r))
        $fs = [System.IO.File]::Create([System.IO.Path]::Combine($env:TB_TEST, $name)); $enc.Save($fs); $fs.Close()
    }
    & $shot 'win1-top.png'
    $c.Scroller.ScrollToVerticalOffset(420); & $shot 'win2-video.png'
    $c.GreetingOn.IsChecked = $false; & $shot 'win3-greeting-off.png'; $c.GreetingOn.IsChecked = $true
    $c.Scroller.ScrollToVerticalOffset(1500); & $shot 'win4-middle.png'
    $c.Scroller.ScrollToBottom(); & $shot 'win5-bottom.png'
    $window.Close()
    return
}
[void]$window.ShowDialog()

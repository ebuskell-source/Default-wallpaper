# uninstall-video.ps1
# Runs as SYSTEM from Intune (5.4: or from "Uninstall TLA BootPaper" on computers set up with the installer). Removes the scheduled tasks, the background policies (where they're ours), the Start menu entry, the organization
# defaults and the files. (Each person's own choices in HKCU stay behind; they're tiny and harmless.)

Unregister-ScheduledTask -TaskName 'Welcome Video' -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName 'TLA BootPaper Backgrounds' -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName 'TLA BootPaper Videos' -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName 'TLA BootPaper Apply' -Confirm:$false -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName 'TLA BootPaper Theme' -Confirm:$false -ErrorAction SilentlyContinue   # (5.0)
Unregister-ScheduledTask -TaskName 'TLA Care' -Confirm:$false -ErrorAction SilentlyContinue              # (5.0)
Unregister-ScheduledTask -TaskName 'TLA BootPaper Updates' -Confirm:$false -ErrorAction SilentlyContinue # (5.4)
# The background policies, where they're ours (leave them if Intune or someone else set them).
$ours = { param($p) $p -and "$p".StartsWith((Join-Path $env:ProgramData 'WelcomeVideo\'), [StringComparison]::OrdinalIgnoreCase) }
$csp = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'
foreach ($kind in 'Desktop', 'LockScreen') {   # 3.2.1 / 3.2.2
    if (& $ours (Get-ItemProperty -LiteralPath $csp -ErrorAction SilentlyContinue)."$($kind)ImagePath") {
        Remove-ItemProperty -LiteralPath $csp -Name "$($kind)ImagePath", "$($kind)ImageUrl", "$($kind)ImageStatus" -ErrorAction SilentlyContinue
    }
}
$lock = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization'
if (& $ours (Get-ItemProperty -LiteralPath $lock -ErrorAction SilentlyContinue).LockScreenImage) {
    Remove-ItemProperty -LiteralPath $lock -Name LockScreenImage, NoChangingLockScreen -ErrorAction SilentlyContinue
}
# Each signed-in person's desktop policy (others are cleared the next time the app would have run; harmless).
foreach ($hive in Get-ChildItem 'Registry::HKEY_USERS' -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^S-1-(5-21|12-1)-[\d-]+$' }) {
    $system = "Registry::HKEY_USERS\$($hive.PSChildName)\Software\Microsoft\Windows\CurrentVersion\Policies\System"
    if (& $ours (Get-ItemProperty -LiteralPath $system -ErrorAction SilentlyContinue).Wallpaper) {
        Remove-ItemProperty -LiteralPath $system -Name Wallpaper, WallpaperStyle -ErrorAction SilentlyContinue
        Remove-ItemProperty -LiteralPath "Registry::HKEY_USERS\$($hive.PSChildName)\Software\Microsoft\Windows\CurrentVersion\Policies\ActiveDesktop" -Name NoChangingWallPaper -ErrorAction SilentlyContinue
    }
}
foreach ($name in 'TLA BootPaper.lnk', 'Report a problem to TLA.lnk', 'TLA Care.lnk', 'Welcome Video.lnk') {
    Remove-Item -LiteralPath (Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs\$name") -Force -ErrorAction SilentlyContinue
}
# (5.0) Windows' "About" support details and the default account pictures, as they were before.
$oem = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation'
$saved = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\WelcomeVideo\OEMBackup' -ErrorAction SilentlyContinue
if ($saved -and $saved.Saved -eq '1') {
    foreach ($name in 'Manufacturer', 'SupportURL', 'SupportPhone', 'SupportHours', 'Logo') {
        $old = $saved.$name
        if ($null -eq $old -or $old -eq '<none>') { Remove-ItemProperty -LiteralPath $oem -Name $name -ErrorAction SilentlyContinue }
        else { Set-ItemProperty -LiteralPath $oem -Name $name -Value $old -ErrorAction SilentlyContinue }
    }
}
$picBackup = Join-Path $env:ProgramData 'WelcomeVideo\AccountPictureBackup'
if (Test-Path -LiteralPath $picBackup) {
    foreach ($f in Get-ChildItem -LiteralPath $picBackup -File) {
        Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $env:ProgramData "Microsoft\User Account Pictures\$($f.Name)") -Force -ErrorAction SilentlyContinue
    }
}
Remove-Item -LiteralPath 'HKLM:\SOFTWARE\WelcomeVideo' -Recurse -Force -ErrorAction SilentlyContinue
# (5.4) The "Installed apps" entry the TLA BootPaper installer adds outside Intune.
Remove-Item -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\TLA BootPaper' -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $env:ProgramData 'WelcomeVideo') -Recurse -Force -ErrorAction SilentlyContinue

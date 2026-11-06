# Update-BootPaper-Now.ps1 - TLA: fixes the clock to BC time right now (UTC-7 all year), and has TLA BootPaper
# install its newest version now instead of at its next 6-hourly check. Intune platform script, SYSTEM, 64-bit.
$want = if ([System.TimeZoneInfo]::GetSystemTimeZones() | Where-Object Id -eq 'British Columbia Standard Time') {
    'British Columbia Standard Time' } else { 'Yukon Standard Time' }
try { Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate' -Name Start -Value 4 } catch { }
& tzutil.exe /s $want
try { Start-ScheduledTask -TaskName 'TLA BootPaper Updates' -ErrorAction Stop; $u = 'update started' } catch { $u = 'no BootPaper update task' }
Write-Output "Time zone: $want; $u"

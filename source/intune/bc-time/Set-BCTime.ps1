# Set-BCTime.ps1 - TLA: British Columbia time, year-round UTC-7 (BC stopped changing clocks on March 8, 2026).
# Intune: Devices > Scripts and remediations > Platform scripts > Add > Windows 10 and later.
#   Run this script using the logged on credentials: No. Enforce script signature check: No. Run in 64-bit PowerShell: Yes.
# Uses "British Columbia Standard Time" (Windows' new BC zone, in the October 13, 2026 update). A PC without that update
# gets "Yukon Standard Time" (also UTC-7 year-round, same clock) until it updates.
$ErrorActionPreference = 'Stop'
$zone = if (Get-TimeZone -ListAvailable | Where-Object Id -eq 'British Columbia Standard Time') {
    'British Columbia Standard Time' } else { 'Yukon Standard Time' }
# Turn off "Set time zone automatically", so location can't move it back to Pacific Time (US & Canada).
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate' -Name Start -Value 4
Stop-Service tzautoupdate -ErrorAction SilentlyContinue
Set-TimeZone -Id $zone
Write-Output "Time zone: $zone ($((Get-Date).ToString('HH:mm zzz')))"

# 7.6.0: TLA Care's own Windows update check (care-system's Update-OSCheck, online), then the row, as is and no room.
$o = "$PWD\out\kiosk"; New-Item -ItemType Directory -Force $o | Out-Null; $r = @()
foreach ($f in 'care.ps1', 'care-system.ps1') { $e = $null; [void][System.Management.Automation.Language.Parser]::ParseFile("$PWD\ci\winsrc\$f", [ref]$null, [ref]$e); $r += "$f parse errors: $($e.Count) $($e | % { $_.Message })" }
New-Item -ItemType Directory -Force "$env:USERPROFILE\Downloads" | Out-Null
$f = [System.IO.File]::Create("$env:USERPROFILE\Downloads\Big test video.mp4"); $f.SetLength(300MB); $f.Close()
$CareKey = 'HKEY_CURRENT_USER\Software\TBTest\Care'; $WV = @{ CareKey = $CareKey }
function Set-Value($Key, $Name, $Value) { [Microsoft.Win32.Registry]::SetValue($Key, $Name, "$Value") }
function Get-WVValue([string]$Key, [string]$Name) { [Microsoft.Win32.Registry]::GetValue($Key, $Name, $null) }
function Write-Log($t) { $script:r += "log: $t" }
function Invoke-WVCareRequest($a) { $script:r += "requested: $a" }
$sys = Get-Content "$PWD\ci\winsrc\care-system.ps1" -Raw; $care = Get-Content "$PWD\ci\winsrc\care.ps1" -Raw
Invoke-Expression ([regex]::Match($sys, '(?ms)^function Update-OSCheck.*?^}').Value)
foreach ($n in 'New-WVCareCheck', 'Get-WVBigFiles', 'Get-WVOSUpdateCheck') { Invoke-Expression ([regex]::Match($care, "(?ms)^function $n.*?^}").Value) }
$t = Measure-Command { Update-OSCheck }; $r += "online check took $([int]$t.TotalSeconds)s"
$row = Get-WVOSUpdateCheck; $r += "row: $($row.Status) | $($row.Title) | $($row.Detail)"
Set-Value "$CareKey\OSUpdate" 'Count' '2'; Set-Value "$CareKey\OSUpdate" 'Names' 'Test update A; Test update B'; Set-Value "$CareKey\OSUpdate" 'Bytes' ([string](500GB))
$row = Get-WVOSUpdateCheck; $r += "no room: $($row.Status) | $($row.Title) | $($row.Detail)"
$r | Set-Content "$o\summary.txt"

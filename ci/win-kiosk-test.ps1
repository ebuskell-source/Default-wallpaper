# 7.6.0: the Windows updates row, as it is and with no room, with a 300 MB file in Downloads.
$o = "$PWD\out\kiosk"; New-Item -ItemType Directory -Force $o | Out-Null; $r = @()
$e = $null; [void][System.Management.Automation.Language.Parser]::ParseFile("$PWD\ci\winsrc\care.ps1", [ref]$null, [ref]$e); $r += "care.ps1 parse errors: $($e.Count) $($e | % { $_.Message })"
New-Item -ItemType Directory -Force "$env:USERPROFILE\Downloads" | Out-Null
$f = [System.IO.File]::Create("$env:USERPROFILE\Downloads\Big test video.mp4"); $f.SetLength(300MB); $f.Close()
$src = Get-Content "$PWD\ci\winsrc\care.ps1" -Raw
foreach ($name in 'New-WVCareCheck', 'Get-WVBigFiles', 'Get-WVOSUpdateCheck') {
  $m = [regex]::Match($src, "(?ms)^function $name.*?^}"); Invoke-Expression $m.Value
}
$t = Measure-Command { $row = Get-WVOSUpdateCheck }
$r += "as is ($([int]$t.TotalSeconds)s): $($row.Status) | $($row.Title) | $($row.Detail)"
Invoke-Expression ([regex]::Match($src, "(?ms)^function Get-WVOSUpdateCheck.*?^}").Value -replace '\$need = \[Math\]::Ceiling\(2 \* \$size / 1GB\) \+ 2', '$need = 99999' -replace "if \(-not \`$found.Count\) \{ return .*?\}", '')
$row = Get-WVOSUpdateCheck
$r += "no room: $($row.Status) | $($row.Title) | $($row.Detail)"
$r | Set-Content "$o\summary.txt"

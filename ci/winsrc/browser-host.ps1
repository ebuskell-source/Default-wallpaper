# browser-host.ps1 (6.3.5) - tells the TLA New Tab extension (Chrome and Edge) which background is on this person's
# desktop, so the TLA new tab page shows the same one. Started by the browser through browser-host.cmd (native
# messaging; browser-host.json, registered for Chrome and Edge, allows only that extension), as the person.
# Answers {"id": "<background>", "look": "light|dark"}, and nothing else.
$ErrorActionPreference = 'Stop'
$id = ''; $look = ''
try {
    . ([System.IO.Path]::Combine($PSScriptRoot, 'common.ps1'))
    $id = if (Test-WVSignedOut) { 'tla' } else { "$(Get-WVCurrentBackground)" }   # (TLA Classic until they sign in)
    $look = "$(Get-WVMode)"
} catch { }
if ($id -notmatch '^[a-z0-9-]{1,40}$') { $id = '' }
if ($look -ne 'light' -and $look -ne 'dark') { $look = '' }
$bytes = [Text.Encoding]::UTF8.GetBytes("{`"id`":`"$id`",`"look`":`"$look`"}")
$out = [Console]::OpenStandardOutput()
$out.Write([BitConverter]::GetBytes([int32]$bytes.Length), 0, 4)   # (the length, lowest byte first, then the JSON)
$out.Write($bytes, 0, $bytes.Length)
$out.Flush()

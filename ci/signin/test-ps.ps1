param([string]$Vectors = 'vectors.json', [string]$Core = 'signin-core.ps1')
$WV = @{}
. (Join-Path $PSScriptRoot $Core)
$v = Get-Content -Raw $Vectors | ConvertFrom-Json
$bad = 0
if ((Get-WVSignInNonce $v.device $v.user $v.salt) -cne $v.nonce) { $bad++; 'FAIL nonce' }
$sw = [Diagnostics.Stopwatch]::StartNew()
foreach ($c in $v.cases) {
    $cfg = Get-WVSignInConfig $(if ($null -ne $c.cfg) { $c.cfg } else { $v.cfg })
    if ($c.fresh) { $r = Test-WVSignInToken $c.token $cfg $v.keys $v.device $v.user $v.salt $v.now -Fresh; $got = if ($r.ok) { @{ ok = $true } } else { @{ ok = $false; reason = $r.reason } } }
    else { $on = [bool]$c.online; $got = Get-WVSignInStatus $cfg $v.keys $c.token $v.salt $v.device $v.user $v.now { $on }.GetNewClosure() }
    $miss = @($c.expect.PSObject.Properties | Where-Object { "$($got[$_.Name])" -ne "$($_.Value)" })
    if ($miss.Count) { $bad++; "FAIL $($c.name): want $($c.expect | ConvertTo-Json -Compress) got $($got | ConvertTo-Json -Compress)" }
}
$m = Merge-WVSignInKeys $v.keys @(,@('google', $v.jwks)) ($v.now)
if ($m.Count -ne 3) { $bad++; "FAIL merge count $($m.Count)" }
if ((Merge-WVSignInKeys $v.keys @() ($v.now + 70 * 86400)).Count -ne 0) { $bad++; 'FAIL merge expiry' }
"$($v.cases.Count) cases, $bad failed, $($sw.ElapsedMilliseconds) ms"
if ($bad) { exit 1 }

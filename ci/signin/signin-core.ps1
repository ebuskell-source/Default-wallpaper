# ---- Hub sign-in (5.7.0): the checks ----------------------------------------------------------------------------------
# The same rules as the Mac and Linux versions (see "TLA BootPaper sign-in" in tech-documentation). A sign-in is a token
# signed by the Hub, or by Google until the Hub's page is ready. It's checked every time against keys only SYSTEM can
# write; its nonce ties it to this PC and this account; it lasts validDays from when it was signed.
$WV.SignInDefaults = @{ required = $false; provider = 'google'; validDays = 30; renewDays = 7; graceDays = 3; remindDays = @(7, 3) }
$WV.GoogleIssuers  = 'https://accounts.google.com', 'accounts.google.com'
$WV.HubAudience    = 'tla-bootpaper'

function ConvertFrom-WVB64Url([string]$Text) {
    if ($Text -notmatch '^[A-Za-z0-9_-]*$' -or $Text.Length % 4 -eq 1) { throw 'not base64url' }
    $t = $Text.Replace('-', '+').Replace('_', '/')
    switch ($t.Length % 4) { 2 { $t += '==' } 3 { $t += '=' } }
    return ,[Convert]::FromBase64String($t)
}
function ConvertTo-WVB64Url([byte[]]$Bytes) { return [Convert]::ToBase64String($Bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_') }
function Get-WVSha256Bytes([byte[]]$Bytes) {
    $h = [System.Security.Cryptography.SHA256]::Create()
    try { return ,$h.ComputeHash($Bytes) } finally { $h.Dispose() }
}
function Test-WVInt($v) { return ($v -is [int] -or $v -is [long]) }
function Get-WVProp($o, [string]$Name) {
    if ($null -eq $o -or $o -isnot [System.Management.Automation.PSCustomObject]) { return $null }
    $p = $o.PSObject.Properties[$Name]
    if ($p) { return ,$p.Value } else { return $null }   # (the comma keeps a one-item list a list)
}

# auth.json, with anything missing or out of range set to its default.
function Get-WVSignInConfig($Raw) {
    $d = $WV.SignInDefaults
    $num = { param($k, $lo, $hi) $v = Get-WVProp $Raw $k; if ((Test-WVInt $v) -and $v -ge $lo -and $v -le $hi) { [int]$v } else { $d[$k] } }
    $str = { param($o, $k) $v = Get-WVProp $o $k; if ($v -is [string]) { $v.Trim() } else { '' } }
    $c = @{}
    $c.required  = (Get-WVProp $Raw 'required') -eq $true -and (Get-WVProp $Raw 'required') -is [bool]
    $p = Get-WVProp $Raw 'provider'
    $c.provider  = if ($p -eq 'hub' -or $p -eq 'google') { "$p" } else { 'google' }
    $c.validDays = & $num 'validDays' 1 120
    $c.renewDays = [Math]::Min((& $num 'renewDays' 0 60), $c.validDays)
    $c.graceDays = & $num 'graceDays' 0 14
    $rd = Get-WVProp $Raw 'remindDays'
    $c.remindDays = if ($rd -is [array]) { @($rd | Where-Object { (Test-WVInt $_) -and $_ -gt 0 -and $_ -le 60 } | ForEach-Object { [int]$_ } | Sort-Object -Unique -Descending) } else { $d.remindDays }
    $g = Get-WVProp $Raw 'google'; $h = Get-WVProp $Raw 'hub'
    $doms = Get-WVProp $g 'domains'
    $c.google = @{ clientId = (& $str $g 'clientId')
                   domains  = @(if ($doms -is [array]) { $doms | Where-Object { $_ -is [string] -and $_ } | ForEach-Object { $_.ToLowerInvariant() } }) }
    $c.hub = @{ signInUrl = (& $str $h 'signInUrl'); issuer = (& $str $h 'issuer'); jwksUrl = (& $str $h 'jwksUrl') }
    return $c
}
# Which sign-ins are accepted: Google's while a client id is set, the Hub's once its issuer and keys are.
function Get-WVSignInKinds($c) {
    $k = @()
    if ($c.google.clientId -and $c.google.domains.Count) { $k += 'google' }
    if ($c.hub.issuer -and $c.hub.jwksUrl -and $c.hub.signInUrl.StartsWith('https://')) { $k += 'hub' }
    return ,$k
}
function Test-WVSignInRequired($c) { return [bool]($c.required -and (Get-WVSignInKinds $c).Count) }
function Get-WVSignInNonce([string]$Device, [string]$User, [string]$Salt) {
    return ConvertTo-WVB64Url (Get-WVSha256Bytes ([Text.Encoding]::UTF8.GetBytes("tla-bootpaper/1`n$Device`n$User`n$Salt")))
}
function Test-WVRs256($Jwk, [string]$SigningInput, [byte[]]$Sig) {
    try {
        $n = ConvertFrom-WVB64Url "$($Jwk.n)"; $e = ConvertFrom-WVB64Url "$($Jwk.e)"
        $i = 0; while ($i -lt $n.Length - 1 -and $n[$i] -eq 0) { $i++ }
        if ($i) { $n = $n[$i..($n.Length - 1)] }
        if ($n.Length -lt 256 -or $Sig.Length -ne $n.Length) { return $false }
        $rsa = [System.Security.Cryptography.RSA]::Create()
        try {
            $p = [System.Security.Cryptography.RSAParameters]::new()
            $p.Modulus = [byte[]]$n; $p.Exponent = [byte[]]$e
            $rsa.ImportParameters($p)
            return $rsa.VerifyData([Text.Encoding]::ASCII.GetBytes($SigningInput), $Sig,
                [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
        } finally { $rsa.Dispose() }
    } catch { return $false }
}

# @{ ok = $true; kind; iat; name; who } for a good token, else @{ ok = $false; reason }. -Fresh: just handed back by the
# sign-in page.
function Test-WVSignInToken([string]$Token, $c, $Keys, [string]$Device, [string]$User, [string]$Salt, [long]$Now, [switch]$Fresh) {
    $bad = @{ ok = $false; reason = 'invalid' }
    $parts = "$Token".Split('.')
    if ($parts.Count -ne 3) { return $bad }
    try {
        $hdr  = [Text.Encoding]::UTF8.GetString((ConvertFrom-WVB64Url $parts[0])) | ConvertFrom-Json
        $body = [Text.Encoding]::UTF8.GetString((ConvertFrom-WVB64Url $parts[1])) | ConvertFrom-Json
        $sig  = ConvertFrom-WVB64Url $parts[2]
    } catch { return $bad }
    if ($hdr -isnot [System.Management.Automation.PSCustomObject] -or $body -isnot [System.Management.Automation.PSCustomObject]) { return $bad }
    $kid = Get-WVProp $hdr 'kid'
    if ((Get-WVProp $hdr 'alg') -cne 'RS256' -or $kid -isnot [string]) { return $bad }
    $kinds = Get-WVSignInKinds $c
    $iss = Get-WVProp $body 'iss'
    if ($iss -is [string] -and $WV.GoogleIssuers -ccontains $iss -and $kinds -contains 'google') { $kind = 'google' }
    elseif ($iss -is [string] -and $c.hub.issuer -and $iss -ceq $c.hub.issuer -and $kinds -contains 'hub') { $kind = 'hub' }
    else { return $bad }
    $jwk = $null
    foreach ($k in @($Keys)) { if ($null -ne $k -and "$($k.kind)" -ceq $kind -and "$($k.kid)" -ceq $kid) { $jwk = $k; break } }
    if ($null -eq $jwk) { return @{ ok = $false; reason = 'pending' } }
    if (-not (Test-WVRs256 $jwk "$($parts[0]).$($parts[1])" $sig)) { return $bad }
    $aud = Get-WVProp $body 'aud'
    if ($kind -eq 'google') {
        $hd = Get-WVProp $body 'hd'; $ev = Get-WVProp $body 'email_verified'
        if ($aud -isnot [string] -or $aud -cne $c.google.clientId -or $ev -isnot [bool] -or -not $ev -or
            $c.google.domains -notcontains "$hd".ToLowerInvariant() -or -not $hd) { return $bad }
    } elseif ($aud -isnot [string] -or $aud -cne $WV.HubAudience) { return $bad }
    $nonce = Get-WVProp $body 'nonce'
    if (-not $Salt -or $nonce -isnot [string] -or $nonce -cne (Get-WVSignInNonce $Device $User $Salt)) { return $bad }
    $iat = Get-WVProp $body 'iat'; $exp = Get-WVProp $body 'exp'
    if (-not (Test-WVInt $iat) -or $iat -gt $Now + 86400) { return $bad }
    if ($Fresh -and ([Math]::Abs($Now - $iat) -gt 600 -or -not (Test-WVInt $exp) -or $exp -lt $Now - 300)) { return @{ ok = $false; reason = 'stale' } }
    $who = if ($kind -eq 'google') { Get-WVProp $body 'email' } else { Get-WVProp $body 'username' }
    $name = "$(Get-WVProp $body 'name')"; if (-not $name) { $name = "$who" }
    return @{ ok = $true; kind = $kind; iat = [long]$iat; name = $name.Substring(0, [Math]::Min(80, $name.Length))
              who = "$who".Substring(0, [Math]::Min(120, "$who".Length)) }
}

# @{ state = off|in|renew|grace|out; ... }. -Online: asked only in the grace days.
function Get-WVSignInStatus($c, $Keys, [string]$Token, [string]$Salt, [string]$Device, [string]$User, [long]$Now, [scriptblock]$Online) {
    if (-not (Test-WVSignInRequired $c)) { return @{ state = 'off' } }
    if (-not $Token) { return @{ state = 'out'; reason = 'none' } }
    $r = Test-WVSignInToken $Token $c $Keys $Device $User $Salt $Now
    if (-not $r.ok) { return @{ state = 'out'; reason = $r.reason } }
    $until = $r.iat + [long]$c.validDays * 86400
    $st = @{ kind = $r.kind; iat = $r.iat; name = $r.name; who = $r.who; until = $until }
    if ($Now -lt $until) {
        $st.days = [int][Math]::Ceiling(($until - $Now) / 86400.0)
        $st.state = if ($st.days -le $c.renewDays) { 'renew' } else { 'in' }
    } elseif ($Now -lt $until + [long]$c.graceDays * 86400 -and $Online -and (& $Online) -eq $false) {
        $st.state = 'grace'
        $st.days = [int][Math]::Ceiling(($until + [long]$c.graceDays * 86400 - $Now) / 86400.0)
    } else { $st.state = 'out'; $st.reason = 'expired' }
    return $st
}

# Root's key list: what it has seen, each kept for 60 days after it was last published.
function Merge-WVSignInKeys($Old, $Fetched, [long]$Now, [int]$KeepDays = 60) {
    $out = [ordered]@{}
    foreach ($k in @($Old)) {
        if ($null -ne $k -and ("$($k.kind)" -eq 'hub' -or "$($k.kind)" -eq 'google') -and $k.kid -is [string] -and (Test-WVInt $k.last) -and $Now - $k.last -lt $KeepDays * 86400) {
            $out["$($k.kind)`n$($k.kid)"] = [ordered]@{ kind = "$($k.kind)"; kid = $k.kid; n = "$($k.n)"; e = "$($k.e)"; first = $k.first; last = [long]$k.last }
        }
    }
    foreach ($f in @($Fetched)) {
        foreach ($j in (Get-WVProp $f[1] 'keys')) {
            if ($null -eq $j -or (Get-WVProp $j 'kty') -ne 'RSA' -or ((Get-WVProp $j 'alg') -and (Get-WVProp $j 'alg') -ne 'RS256') -or
                (Get-WVProp $j 'kid') -isnot [string] -or (Get-WVProp $j 'n') -isnot [string] -or (Get-WVProp $j 'e') -isnot [string]) { continue }
            $id = "$($f[0])`n$($j.kid)"
            $first = if ($out.Contains($id) -and (Test-WVInt $out[$id].first)) { $out[$id].first } else { $Now }
            $out[$id] = [ordered]@{ kind = $f[0]; kid = $j.kid; n = $j.n; e = $j.e; first = [long]$first; last = $Now }
        }
    }
    return ,@($out.Values | Sort-Object { -$_.last } | Select-Object -First 40)
}

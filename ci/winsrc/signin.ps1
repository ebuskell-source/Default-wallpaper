# signin.ps1 - TLA BootPaper (5.7.0): signing in with the Hub account. Loaded by common.ps1.
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

# ---- This PC (5.7.0) -------------------------------------------------------------------------------------------------
# auth.json (on GitHub) switches sign-in on and says how; the "TLA BootPaper Backgrounds" task (SYSTEM) fetches it, with
# the keys sign-ins are checked against, into SignIn\ (people can only read there). Each person's sign-in is in
# HKCU\Software\WelcomeVideo\SignIn (Token, Salt); anyone could edit that, which is why it's checked every time.
$WV.SignInDir    = [System.IO.Path]::Combine($WV.Dir, 'SignIn')
$WV.AuthSource   = 'https://raw.githubusercontent.com/ebuskell-source/Default-wallpaper/main/TLA-BootPaper/auth.json'
$WV.SignInPage   = 'https://ebuskell-source.github.io/Default-wallpaper/TLA-BootPaper/signin/'
$WV.GoogleCerts  = 'https://www.googleapis.com/oauth2/v3/certs'
$WV.SignInSid    = $null      # (the person it's for, when SYSTEM works it out for them: lock-backgrounds.ps1)

function Get-WVSignInKey { return "$($WV.UserKey)\SignIn" }
function Read-WVJsonFile([string]$Path) {
    try { if ([System.IO.File]::Exists($Path)) { return [System.IO.File]::ReadAllText($Path) | ConvertFrom-Json } } catch { }
    return $null
}
function Get-WVSignInSettings { return Get-WVSignInConfig (Read-WVJsonFile ([System.IO.Path]::Combine($WV.SignInDir, 'auth.json'))) }
function Get-WVSignInKeys {
    $k = Get-WVProp (Read-WVJsonFile ([System.IO.Path]::Combine($WV.SignInDir, 'keys.json'))) 'keys'
    if ($null -eq $k) { return ,@() }
    return ,@($k)
}
function Get-WVSignInDevice { return "win:$(Get-WVValue 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Cryptography' 'MachineGuid')" }
function Get-WVSignInUser {
    if ($WV.SignInSid) { return $WV.SignInSid }
    return [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
}
function Get-WVNow { return [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }
function Get-WVWeb([string]$Url, [int]$TimeoutMs = 20000, [switch]$Head) {
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }
    $req = [System.Net.HttpWebRequest]::Create($Url)
    $req.Timeout = $TimeoutMs; $req.ReadWriteTimeout = $TimeoutMs
    $req.CachePolicy = [System.Net.Cache.RequestCachePolicy]::new([System.Net.Cache.RequestCacheLevel]::NoCacheNoStore)
    if ($Head) { $req.Method = 'HEAD' }
    $res = $req.GetResponse()
    try {
        if ($Head) { return '' }
        $r = [System.IO.StreamReader]::new($res.GetResponseStream(), [Text.Encoding]::UTF8)
        try { return $r.ReadToEnd() } finally { $r.Dispose() }
    } finally { $res.Close() }
}
# Can this PC reach the sign-in page? (Asked only when a sign-in has run out, for the grace days; kept 10 minutes.)
function Test-WVOnline {
    $c = "$(Get-WVValue $WV.StateKey 'OnlineCheck')".Split(' ')
    $now = Get-WVNow
    if ($c.Count -eq 2 -and $c[0] -match '^\d+$' -and $now - [long]$c[0] -ge 0 -and $now - [long]$c[0] -lt 600) { return $c[1] -eq '1' }
    $ok = $true
    try { [void](Get-WVWeb $WV.SignInPage 5000 -Head) }
    catch {                                   # (any answer, even "not found", means it's online)
        $e = $_.Exception
        while ($e -and $e -isnot [System.Net.WebException]) { $e = $e.InnerException }
        $ok = [bool]($e -and $null -ne $e.Response)
    }
    try { [Microsoft.Win32.Registry]::SetValue($WV.StateKey, 'OnlineCheck', "$now $(if ($ok) { 1 } else { 0 })") } catch { }
    return $ok
}

# This person's sign-in: @{ state = 'off'|'in'|'renew'|'grace'|'out'; ... } (worked out once per run).
$script:WVSignIn = $null
function Get-WVSignIn([switch]$Fresh) {
    if ($Fresh -or $null -eq $script:WVSignIn) {
        $user = $null
        try { $user = Get-WVSignInUser } catch { }
        if (-not (Test-WVReleased 'signin') -or -not $user -or $user -eq 'S-1-5-18') {
            $script:WVSignIn = @{ state = 'off' }
        } else {
            $key = Get-WVSignInKey
            $script:WVSignIn = Get-WVSignInStatus (Get-WVSignInSettings) (Get-WVSignInKeys) "$(Get-WVValue $key 'Token')" `
                "$(Get-WVValue $key 'Salt')" (Get-WVSignInDevice) $user (Get-WVNow) { Test-WVOnline }
        }
    }
    return $script:WVSignIn
}
# True while this person has to sign in first: their settings don't apply, and they get TLA Classic.
function Test-WVSignedOut { return (Get-WVSignIn).state -eq 'out' }
function Clear-WVSignInCache { $script:WVSignIn = $null }

# SYSTEM (the "TLA BootPaper Backgrounds" task): auth.json and the keys, every 6 hours, or right away when someone's
# sign-in came back signed with a key this PC hasn't fetched yet (TLA Care's "signin" request; at most once a minute).
function Update-WVSignIn([switch]$Force, [scriptblock]$Log = { param($t) }) {
    try {
        [void][System.IO.Directory]::CreateDirectory($WV.SignInDir)
        $stamp = [System.IO.Path]::Combine($WV.SignInDir, '.checked')
        $age = if ([System.IO.File]::Exists($stamp)) { ([DateTime]::UtcNow - [System.IO.File]::GetLastWriteTimeUtc($stamp)).TotalSeconds } else { 1e9 }
        if ($age -lt $(if ($Force) { 60 } else { 6 * 3600 })) { return }
        [System.IO.File]::WriteAllText($stamp, '')
        $authFile = [System.IO.Path]::Combine($WV.SignInDir, 'auth.json')
        try {
            $text = Get-WVWeb "$($WV.AuthSource)?t=$([DateTime]::UtcNow.Ticks)"
            $raw = $text | ConvertFrom-Json
            if ($raw -isnot [System.Management.Automation.PSCustomObject]) { throw "it isn't a JSON object" }
            [System.IO.File]::WriteAllText($authFile, $text)
        } catch { & $Log "Couldn't read the sign-in settings: $($_.Exception.Message)" }
        $c = Get-WVSignInSettings
        $fetched = @()
        if ($c.google.clientId) {
            try { $fetched += ,@('google', (Get-WVWeb $WV.GoogleCerts | ConvertFrom-Json)) } catch { & $Log "Couldn't get Google's keys: $($_.Exception.Message)" }
        }
        if ($c.hub.jwksUrl.StartsWith('https://')) {
            try { $fetched += ,@('hub', (Get-WVWeb $c.hub.jwksUrl | ConvertFrom-Json)) } catch { & $Log "Couldn't get the Hub's keys: $($_.Exception.Message)" }
        }
        $keys = Merge-WVSignInKeys (Get-WVSignInKeys) $fetched (Get-WVNow)
        $json = ConvertTo-Json -InputObject ([ordered]@{ keys = @($keys); updated = (Get-WVNow) }) -Depth 5 -Compress
        [System.IO.File]::WriteAllText([System.IO.Path]::Combine($WV.SignInDir, 'keys.json'), $json)
        & $Log "Sign-in settings: $(if (Test-WVSignInRequired $c) { 'required' } else { 'not required' }), $(@($keys).Count) keys."
    } catch { & $Log "Sign-in settings: $($_.Exception.Message)" }
}

# ---- Signing in (the app) --------------------------------------------------------------------------------------------
# The app waits on 127.0.0.1 (a port Windows picks) for the sign-in page to hand back the token, at most 10 minutes;
# then it sends the browser on to the "you're all set" page. No administrator rights needed.
function Start-WVSignIn {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $listener.Start()
    $port = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $b = [byte[]]::new(16); $rng.GetBytes($b); $salt = ConvertTo-WVB64Url $b
    $rng.GetBytes($b); $state = "$port.$(ConvertTo-WVB64Url $b)"
    $nonce = Get-WVSignInNonce (Get-WVSignInDevice) (Get-WVSignInUser) $salt
    return @{ Listener = $listener; Salt = $salt; State = $state; Until = [DateTime]::UtcNow.AddMinutes(10)
              Url = "$($WV.SignInPage)?state=$([Uri]::EscapeDataString($state))&nonce=$([Uri]::EscapeDataString($nonce))&v=1" }
}
# Called every 200 ms: $null while waiting; otherwise what came back (a hashtable of the query; empty if it gave up).
function Receive-WVSignIn($Pending) {
    $l = $Pending.Listener
    if ([DateTime]::UtcNow -gt $Pending.Until) { $l.Stop(); return @{} }
    while ($l.Pending()) {
        $client = $l.AcceptTcpClient()
        try {
            $client.ReceiveTimeout = 3000
            $stream = $client.GetStream()
            $buf = [byte[]]::new(32768); $n = 0
            while ($n -lt $buf.Length) {
                $k = $stream.Read($buf, $n, $buf.Length - $n)
                if ($k -le 0) { break }
                $n += $k
                if ([Text.Encoding]::ASCII.GetString($buf, 0, $n).Contains("`r`n`r`n")) { break }
            }
            $line = [Text.Encoding]::ASCII.GetString($buf, 0, $n).Split("`r")[0].Split(' ')
            if ($line.Count -ge 2 -and $line[0] -eq 'GET' -and $line[1].StartsWith('/callback?')) {
                $reply = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 302 Found`r`nLocation: $($WV.SignInPage)?done=1`r`nCache-Control: no-store`r`nContent-Length: 0`r`nConnection: close`r`n`r`n")
                $stream.Write($reply, 0, $reply.Length)
                $q = @{}
                foreach ($pair in $line[1].Substring(10).Split('&')) {
                    $i = $pair.IndexOf('=')
                    if ($i -gt 0) { $q[[Uri]::UnescapeDataString($pair.Substring(0, $i).Replace('+', ' '))] = [Uri]::UnescapeDataString($pair.Substring($i + 1).Replace('+', ' ')) }
                }
                $l.Stop()
                return $q
            }
            $nf = [Text.Encoding]::ASCII.GetBytes("HTTP/1.1 404 Not Found`r`nContent-Length: 0`r`nConnection: close`r`n`r`n")
            $stream.Write($nf, 0, $nf.Length)
        } catch { } finally { $client.Close() }
    }
    return $null
}
# What came back: @{ ok; message; needKeys }. Saves it when it's good.
function Complete-WVSignIn($Pending, $Answer) {
    if (-not $Answer -or -not $Answer.Count) { return @{ ok = $false; message = 'Signing in took too long. Try again.' } }
    if ($Answer['state'] -cne $Pending.State) { return @{ ok = $false; message = 'That sign-in was for another window. Try again.' } }
    if ($Answer['error'] -or -not $Answer['token']) {
        return @{ ok = $false; message = $(if ($Answer['error'] -eq 'not_eligible') { 'Your Hub account can''t be used for TLA BootPaper.' } else { 'Signing in didn''t finish. Try again.' }) }
    }
    $c = Get-WVSignInSettings; $now = Get-WVNow
    $token = "$($Answer['token'])"; if ($token.Length -gt 8192) { $token = $token.Substring(0, 8192) }
    $r = Test-WVSignInToken $token $c (Get-WVSignInKeys) (Get-WVSignInDevice) (Get-WVSignInUser) $Pending.Salt $now -Fresh
    $needKeys = $false
    if (-not $r.ok -and $r.reason -eq 'pending') {
        # A key this PC hasn't fetched yet: check it against the keys as published right now, then ask for them.
        $fetched = @()
        if ($c.google.clientId) { try { $fetched += ,@('google', (Get-WVWeb $WV.GoogleCerts | ConvertFrom-Json)) } catch { } }
        if ($c.hub.jwksUrl.StartsWith('https://')) { try { $fetched += ,@('hub', (Get-WVWeb $c.hub.jwksUrl | ConvertFrom-Json)) } catch { } }
        $r = Test-WVSignInToken $token $c (Merge-WVSignInKeys @() $fetched $now) (Get-WVSignInDevice) (Get-WVSignInUser) $Pending.Salt $now -Fresh
        $needKeys = [bool]$r.ok
    }
    if (-not $r.ok) {
        return @{ ok = $false; message = $(if ($r.reason -eq 'stale') { 'This PC''s clock looks wrong, or the sign-in took too long. Check the date and time, then try again.' } else { 'That sign-in couldn''t be checked. Try again.' }) }
    }
    [Microsoft.Win32.Registry]::SetValue((Get-WVSignInKey), 'Token', $token)
    [Microsoft.Win32.Registry]::SetValue((Get-WVSignInKey), 'Salt', $Pending.Salt)
    Clear-WVSignInCache
    return @{ ok = $true; message = "Signed in as $(if ($r.name) { $r.name } else { $r.who })."; needKeys = $needKeys; who = $r.who; kind = $r.kind }
}
function Remove-WVSignIn {
    try { [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree('Software\WelcomeVideo\SignIn', $false) } catch { }
    Clear-WVSignInCache
}

# ---- Reminders (after the video: session.ps1) -------------------------------------------------------------------------
# 7 and 3 days before a sign-in runs out (once each); in the grace days, once a day; signed out, at most once a week.
# Returns @(title, text), or $null when nothing is due (and marks it shown).
function Get-WVSignInReminder {
    $s = Get-WVSignIn
    if ($s.state -eq 'off') { return $null }
    $c = Get-WVSignInSettings
    $rec = $null
    try { $rec = "$(Get-WVValue $WV.StateKey 'SignInReminded')" | ConvertFrom-Json } catch { }
    $iatRec = Get-WVProp $rec 'iat'; $daysRec = @(Get-WVProp $rec 'days' | Where-Object { $null -ne $_ })
    $graceRec = "$(Get-WVProp $rec 'grace')"; $outRec = "$(Get-WVProp $rec 'out')"
    $today = [DateTime]::Today.ToString('yyyy-MM-dd')
    $title = ''; $text = ''
    if ($s.state -eq 'in' -or $s.state -eq 'renew') {
        $due = @($c.remindDays | Where-Object { $s.days -le $_ })
        $done = if ("$iatRec" -eq "$($s.iat)") { $daysRec } else { @() }
        if ($due.Count -and $done -notcontains ($due | Measure-Object -Minimum).Minimum) {
            $daysRec = @($done) + @($due); $iatRec = $s.iat
            $until = [DateTimeOffset]::FromUnixTimeSeconds($s.until).LocalDateTime
            $title = 'Time to sign in to TLA BootPaper again'
            $text = "Your sign-in runs out $(if ($s.days -le 1) { 'tomorrow' } else { "in $($s.days) days" }) ($($until.ToString('dddd, MMMM d'))). Sign in again with your Hub account to keep your video and background."
        }
    } elseif ($s.state -eq 'grace' -and $graceRec -ne $today) {
        $graceRec = $today
        $title = 'Sign in to TLA BootPaper when you''re back online'
        $text = "Your sign-in has run out. You have $($s.days) more day$(if ($s.days -ne 1) { 's' }) to sign in again with your Hub account."
    } elseif ($s.state -eq 'out' -and (-not $outRec -or ([DateTime]::Today - [DateTime]::Parse($outRec)).TotalDays -ge 7)) {
        $outRec = $today
        $title = 'Sign in to TLA BootPaper'
        $text = 'Sign in with your Hub account to choose your welcome video and background. Until then you''ll see TLA Classic.'
    }
    if (-not $title) { return $null }
    $json = ConvertTo-Json -Compress -InputObject ([ordered]@{ iat = $iatRec; days = @($daysRec); grace = $graceRec; out = $outRec })
    try { [Microsoft.Win32.Registry]::SetValue($WV.StateKey, 'SignInReminded', $json) } catch { }
    return @($title, $text)
}

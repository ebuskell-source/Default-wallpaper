# 5.7.0: signing in on a real Windows PC (Windows PowerShell 5.1, as people have it). The scripts run from ci\winsrc,
# with SignIn\ trusting test keys: the shared checks, signed out (TLA Classic), the whole round trip (listener, the
# sign-in page's hand-back, the check), time to sign in again, reminders, SYSTEM's view (another account's key), and
# pictures of the app.
$ErrorActionPreference = 'Continue'
$src = "$PWD\ci\winsrc"; $out = "$PWD\out\signin"; New-Item -ItemType Directory -Force $out | Out-Null
$sum = "$out\summary.txt"
function Log($t) { "== $t" | Out-File $sum -Append -Encoding utf8 }
function Say($t) { "$t" | Out-File $sum -Append -Encoding utf8 }
"PowerShell $($PSVersionTable.PSVersion)" | Out-File $sum -Encoding utf8
python -m pip install --quiet cryptography *> "$out\pip.txt"
python ci\signin\prep.py "$src\SignIn" *> "$out\prep.txt"
[System.IO.File]::WriteAllText("$src\SignIn\.checked", '')
reg add HKCU\Software\WelcomeVideo /v Channel /d experimental /f | Out-Null
reg add HKCU\Software\WelcomeVideo /v Background /d space /f | Out-Null
reg add HKCU\Software\WelcomeVideo /v Video /d space /f | Out-Null
reg add HKCU\Software\WelcomeVideo /v PreferredName /d Sevilen /f | Out-Null

Log 'shared checks (Windows PowerShell 5.1)'
& powershell -NoProfile -ExecutionPolicy Bypass -File ci\signin\test-ps.ps1 -Vectors ci\signin\vectors.json -Core signin-core.ps1 *>> $sum

. "$src\common.ps1"
$dev = Get-WVSignInDevice; $me = Get-WVSignInUser
Say "device $dev user $me"
function Set-Token([int]$DaysAgo, [string]$Salt = 'c2FsdHNhbHRzYWx0c2FsdA') {
    $n = (& python ci\signin\mktoken.py nonce $dev $me 'c2FsdHNhbHRzYWx0c2FsdA').Trim()
    $iat = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $DaysAgo * 86400
    $t = (& python ci\signin\mktoken.py token hub $iat $n).Trim()
    [Microsoft.Win32.Registry]::SetValue('HKEY_CURRENT_USER\Software\WelcomeVideo\SignIn', 'Token', $t)
    [Microsoft.Win32.Registry]::SetValue('HKEY_CURRENT_USER\Software\WelcomeVideo\SignIn', 'Salt', $Salt)
}
function Show-State([string]$What) {
    $s = Get-WVSignIn -Fresh
    Say ("{0}: {1}  | Background={2} Video={3} current={4} channel={5}" -f $What, (($s.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ' '),
         (Get-WVSetting 'Background'), (Get-WVSetting 'Video'), (Get-WVCurrentBackground), (Get-WVChannel))
}
function Shot([string]$Dir) {
    New-Item -ItemType Directory -Force $Dir | Out-Null
    $env:TB_TEST = $Dir
    $p = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$src\settings.ps1`"" -PassThru -RedirectStandardError "$Dir\err.txt"
    if (-not $p.WaitForExit(150000)) { $p.Kill(); Say "settings: timed out ($Dir)" }
    $env:TB_TEST = ''
    Get-Content "$env:LOCALAPPDATA\TLA BootPaper\app-errors.log" -ErrorAction SilentlyContinue | Out-File $sum -Append
}

Log 'signed out'
Show-State 'nothing saved'
Shot "$out\out"

Log 'round trip'
$p = Start-WVSignIn
Say "url: $($p.Url.Substring(0, 110))"
$q = @{}; foreach ($pair in ([Uri]$p.Url).Query.TrimStart('?').Split('&')) { $i = $pair.IndexOf('='); $q[$pair.Substring(0, $i)] = [Uri]::UnescapeDataString($pair.Substring($i + 1)) }
$port = ([System.Net.IPEndPoint]$p.Listener.LocalEndpoint).Port
$tok = (& python ci\signin\mktoken.py token hub ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) $q['nonce']).Trim()
$fav = Start-Process curl.exe -ArgumentList '-s', '-o', 'NUL', '-w', '"favicon %{http_code}"', "http://127.0.0.1:$port/favicon.ico" -PassThru -NoNewWindow -RedirectStandardOutput "$out\fav.txt"
$cb = Start-Process curl.exe -ArgumentList '-s', '-D', "`"$out\cb-headers.txt`"", '-o', 'NUL', "`"http://127.0.0.1:$port/callback?state=$([Uri]::EscapeDataString($p.State))&token=$tok`"" -PassThru -NoNewWindow
$answer = $null; $t0 = [DateTime]::UtcNow
while ($null -eq $answer -and ([DateTime]::UtcNow - $t0).TotalSeconds -lt 15) { $answer = Receive-WVSignIn $p; Start-Sleep -Milliseconds 100 }
[void]$cb.WaitForExit(5000); [void]$fav.WaitForExit(5000)
Say "favicon: $(Get-Content "$out\fav.txt" -Raw)"
Say "browser got: $((Get-Content "$out\cb-headers.txt" -ErrorAction SilentlyContinue | Select-Object -First 2) -join ' | ')"
Say "answer keys: $(($answer.Keys | Sort-Object) -join ',')"
$r = Complete-WVSignIn $p $answer
Say "complete: ok=$($r.ok) message=$($r.message) needKeys=$($r.needKeys)"
Show-State 'after signing in'
Shot "$out\in"

Log 'wrong state, error, too slow'
Say "wrong state: $((Complete-WVSignIn $p @{ state = '1.x'; token = $tok }).message)"
Say "not eligible: $((Complete-WVSignIn $p @{ state = $p.State; error = 'not_eligible' }).message)"
Say "nothing: $((Complete-WVSignIn $p @{}).message)"

Log 'time to sign in again (25 days ago), reminders'
Set-Token 25; Show-State '25 days ago'
$n1 = Get-WVSignInReminder; $n2 = Get-WVSignInReminder
Say "reminder: $($n1 -join ' / ')"; Say "again: [$($n2 -join ' / ')]"
Shot "$out\renew"
Set-Token 28; Say "28 days ago: $((Get-WVSignIn -Fresh).days) days; reminder: $((Get-WVSignInReminder) -join ' / ')"

Log 'ran out (31 days ago, online), edited token, another salt, SYSTEM view'
Set-Token 31; Show-State '31 days ago'
$t = "$(Get-WVValue 'HKEY_CURRENT_USER\Software\WelcomeVideo\SignIn' 'Token')".Split('.')
$body = [Text.Encoding]::UTF8.GetString((ConvertFrom-WVB64Url $t[1])) | ConvertFrom-Json; $body.iat += 20 * 86400
$t[1] = ConvertTo-WVB64Url ([Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Compress)))
[Microsoft.Win32.Registry]::SetValue('HKEY_CURRENT_USER\Software\WelcomeVideo\SignIn', 'Token', ($t -join '.')); Show-State 'edited'
Set-Token 1 'c2FsdHNhbHRzYWx0c2FsdB'; Show-State 'another salt'
Set-Token 2
$sid = $me
$WV.UserKey = "HKEY_USERS\$sid\Software\WelcomeVideo"; $WV.StateKey = "HKEY_USERS\$sid\Software\WelcomeVideo\State"; $WV.SignInSid = $sid
Show-State 'as SYSTEM sees it (HKEY_USERS)'
$WV.UserKey = 'HKEY_CURRENT_USER\Software\WelcomeVideo'; $WV.StateKey = 'HKEY_CURRENT_USER\Software\WelcomeVideo\State'; $WV.SignInSid = $null

Log 'login cost: a new PowerShell loading common.ps1 and working it out'
$sw = [Diagnostics.Stopwatch]::StartNew()
& powershell -NoProfile -ExecutionPolicy Bypass -Command ". '$src\common.ps1'; (Get-WVSignIn).state; Get-WVSetting 'Video'" *>> $sum
Say "took $($sw.ElapsedMilliseconds) ms (with PowerShell's start)"
$sw.Restart()
& powershell -NoProfile -ExecutionPolicy Bypass -Command ". '$src\common.ps1'; Get-WVSetting 'Enabled'" *>> $sum
Say "common.ps1 alone: $($sw.ElapsedMilliseconds) ms"

Log 'sign out'
Remove-WVSignIn; Show-State 'signed out'

Log 'fetching the real settings (GitHub) into a copy'
$WV.SignInDir = "$out\fetched"; Update-WVSignIn -Force -Log { param($t) Say "  $t" }
Get-ChildItem $WV.SignInDir | ForEach-Object { Say "  $($_.Name) $($_.Length)" }

# 5.7.5: the "connected to TLA" check (certificates in both stores, then Windows' enrollment record) and the
# player's wait for the lock screen.
Log '5.7.5 managed check'
$sw = [Diagnostics.Stopwatch]::StartNew()
Say "not enrolled: managed=$(Test-WVIntuneManaged) connectNeeded=$(Test-WVConnectNeeded) ($($sw.ElapsedMilliseconds) ms)"
$enr = 'HKLM:\SOFTWARE\Microsoft\Enrollments\{0F0E0D0C-1111-2222-3333-444455556666}'
New-Item -Path $enr -Force | Out-Null
New-ItemProperty -Path $enr -Name ProviderID -Value 'MS DM Server' -Force | Out-Null
New-ItemProperty -Path $enr -Name EnrollmentState -Value 1 -PropertyType DWord -Force | Out-Null
Say "Intune record: managed=$(Test-WVIntuneManaged) connectNeeded=$(Test-WVConnectNeeded)"
& powershell -NoProfile -ExecutionPolicy Bypass -Command ". '$src\common.ps1'; 'as a new 64-bit PowerShell: ' + (Test-WVIntuneManaged)" *>> $sum
& "$env:SystemRoot\SysWOW64\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command ". '$src\common.ps1'; 'as 32-bit PowerShell: ' + (Test-WVIntuneManaged)" *>> $sum
Set-ItemProperty -Path $enr -Name EnrollmentState -Value 3
Say "record not finished (state 3): managed=$(Test-WVIntuneManaged)"
Set-ItemProperty -Path $enr -Name EnrollmentState -Value 1
Set-ItemProperty -Path $enr -Name ProviderID -Value 'Other MDM'
Say "another provider: managed=$(Test-WVIntuneManaged)"
Remove-Item -Path $enr -Recurse -Force
Say "record removed: managed=$(Test-WVIntuneManaged)"

Log '5.7.5 lock screen wait (a stand-in LogonUI in this session)'
Copy-Item "$env:SystemRoot\System32\PING.EXE" "$out\LogonUI.exe" -Force
$fake = Start-Process "$out\LogonUI.exe" -ArgumentList '-n', '9', '127.0.0.1' -PassThru -WindowStyle Hidden
$sessionId = [System.Diagnostics.Process]::GetCurrentProcess().SessionId
function Test-InSession([string]$ProcessName) {
    foreach ($p in [System.Diagnostics.Process]::GetProcessesByName($ProcessName)) { if ($p.SessionId -eq $sessionId) { return $true } }
    return $false
}
$sw.Restart()
while (Test-InSession 'LogonUI') { [System.Threading.Thread]::Sleep(1000) }
Say "waited $([int]($sw.ElapsedMilliseconds / 1000)) s for the stand-in to end (expect about 8); sessions: test $sessionId, stand-in $($fake.SessionId)"
$real = @([System.Diagnostics.Process]::GetProcessesByName('LogonUI') | ForEach-Object { "$($_.Id)@$($_.SessionId)" })
Say "real LogonUI processes on the runner: $($real -join ', ')"
$t = $null; $e = $null
foreach ($f in 'play-video.ps1', 'care.ps1', 'install-video.ps1', 'common.ps1') {
    [void][System.Management.Automation.Language.Parser]::ParseFile("$src\$f", [ref]$t, [ref]$e)
    Say "$f parse errors: $($e.Count)"
}

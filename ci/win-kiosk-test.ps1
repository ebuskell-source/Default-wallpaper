# 7.3.5: scripts parse, the key block compiles and switches on and off, the unboxing gate reads.
$o = "$PWD\out\kiosk"; New-Item -ItemType Directory -Force $o | Out-Null
$r = @(); $d = "$PWD\ci\winsrc"
foreach ($f in 'tour.ps1','settings.ps1','signin.ps1','sync-videos.ps1','common.ps1','install-video.ps1') {
  $e = $null; [void][System.Management.Automation.Language.Parser]::ParseFile("$d\$f", [ref]$null, [ref]$e); $r += "$f parse errors: $($e.Count) $($e | ForEach-Object { $_.Message + ' @' + $_.Extent.StartLineNumber })"
}
try { . "$d\common.ps1"; . "$d\tour.ps1" 2>$null } catch { $r += "load: $($_.Exception.Message)" }
try { [WelcomeVideo.KeyBlock]::On(); $r += "keyblock on ok"; [WelcomeVideo.KeyBlock]::Off(); $r += "keyblock off ok" } catch { $r += "keyblock: $($_.Exception.Message)" }
try { $r += "prepared(no key)=$(Test-WVUnboxPrepared)"; New-Item 'HKLM:\SOFTWARE\WelcomeVideo\Unbox' -Force | Out-Null; Set-ItemProperty 'HKLM:\SOFTWARE\WelcomeVideo\Unbox' State armed; $r += "prepared(armed)=$(Test-WVUnboxPrepared)" } catch { $r += "unbox: $($_.Exception.Message)" }
$src = Get-Content "$d\tour.ps1" -Raw
$m = [regex]::Match($src, "(?s)-Name KeyBlock -UsingNamespace System.Runtime.InteropServices -MemberDefinition @'\r?\n(.*?)\r?\n'@")
try { Add-Type -Namespace T2 -Name KeyBlock -UsingNamespace System.Runtime.InteropServices -MemberDefinition $m.Groups[1].Value -ErrorAction Stop; $r += "compile ok" } catch { $r += "compile: $($_.Exception.Message) $($_ | Out-String)" }
$r | Set-Content "$o\summary.txt"

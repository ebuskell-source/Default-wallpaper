# 5.9.0: the animal backgrounds, and their own pictures on a PC of their own (a GitHub runner isn't joined to TLA's
# Microsoft Entra ID), with the announcement written on one for the lock screen. Pictures of the app.
$ErrorActionPreference = 'Continue'
$src = "$PWD\ci\winsrc"; $out = "$PWD\out\w59"; New-Item -ItemType Directory -Force $out, "$out\pictures" | Out-Null
$sum = "$out\summary.txt"
function Say($t) { "$t" | Out-File $sum -Append -Encoding utf8 }
. "$src\common.ps1"
reg add HKCU\Software\WelcomeVideo /v Channel /d experimental /f | Out-Null
Say "release $($WV.Release), experimental $(Get-WVChannelRelease 'experimental'), channel $(Get-WVChannel)"
Say "animals out: $(@($WV.Animals | Where-Object { Test-WVReleased $_ }) -join ', ')"
Say "owned by TLA: $(Test-WVOwnedByTla)  own pictures allowed: $(Test-WVOwnPicturesAllowed)  own folder: $(Get-WVOwnDir)"
dsregcmd /status | Select-String 'AzureAdJoined|DomainJoined|WorkplaceJoined' | ForEach-Object { Say "  $($_.Line.Trim())" }
foreach ($b in 'grumpy-cat', 'bonjovi', 'raccoon') {
    Say "$b`: $(Get-WVBackgroundPath $b) | dark $(Get-WVBackgroundPath $b 'dark') | thumb $(Get-WVThumbnailPath $b) | style $($WV.GreetingStyles[$b])"
}
# The app: adds the test pictures (TB_OWN), picks the first, and takes pictures of the Animals and own sections.
$env:TB_TEST = $out
$env:TB_OWN = (@('sideways-exif6.jpg', 'portrait-clear.png', 'tiny.png', 'not-a-picture.jpg', 'sideways-exif6.jpg') |
               ForEach-Object { "$PWD\ci\own\$_" }) -join '|'
$p = Start-Process powershell -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$src\settings.ps1`"" -PassThru -RedirectStandardError "$out\settings-err.txt"
if (-not $p.WaitForExit(180000)) { $p.Kill(); Say 'settings: timed out' } else { Say "settings exit $($p.ExitCode)" }
Get-Content "$out\own.txt" -ErrorAction SilentlyContinue | ForEach-Object { Say "  $_" }
Get-Content "$env:LOCALAPPDATA\TLA BootPaper\app-errors.log" -ErrorAction SilentlyContinue | Out-File $sum -Append
Get-ChildItem (Get-WVOwnDir) -ErrorAction SilentlyContinue | ForEach-Object {
    Copy-Item $_.FullName "$out\pictures\"
    Add-Type -AssemblyName System.Drawing
    $i = [System.Drawing.Image]::FromFile($_.FullName); Say "  $($_.Name) $($i.Width)x$($i.Height) $($_.Length) bytes"; $i.Dispose()
}
Say "valid as Background: $(Test-WVValid 'Background' (@(Get-WVOwnPictures)[0]))  as LockBackground: $(Test-WVValid 'LockBackground' (@(Get-WVOwnPictures)[0]))  a made-up one: $(Test-WVValid 'Background' 'own-00000000')"
Say "reported as: $(Get-WVReportedBackground (@(Get-WVOwnPictures)[0])) / $(Get-WVReportedBackground 'bonjovi')"
Say "our picture? $(Test-WVOurPicture (Get-WVOwnPicturePath (@(Get-WVOwnPictures)[0])))"
# The announcement on their own picture, as lock-backgrounds.ps1 writes it (its function, run here).
$t = $null; $e = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile("$src\lock-backgrounds.ps1", [ref]$t, [ref]$e)
$fn = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'New-AnnouncementPicture' }, $true)
. ([scriptblock]::Create($fn.Extent.Text))
$n = 0
foreach ($id in @(Get-WVOwnPictures)) {
    $n++
    try { New-AnnouncementPicture (Get-WVOwnPicturePath $id) "$out\announce-$n.jpg" 'School is closed on Monday for the PD day. See you Tuesday!'; Say "announcement on $id`: ok" }
    catch { Say "announcement on $id failed: $($_.Exception.Message)" }
}
# On a PC TLA manages, the organization's setting decides: 0 = no own pictures.
reg add HKLM\SOFTWARE\WelcomeVideo /v OwnPictures /t REG_DWORD /d 0 /f | Out-Null
Say "with OwnPictures 0: allowed $(Test-WVOwnPicturesAllowed), valid $(Test-WVValid 'Background' (@(Get-WVOwnPictures)[0])), current $(Get-WVCurrentBackground)"
reg delete HKLM\SOFTWARE\WelcomeVideo /v OwnPictures /f | Out-Null
foreach ($f in Get-ChildItem "$src\*.ps1") { [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$t, [ref]$e); if ($e.Count) { Say "$($f.Name) parse errors: $($e.Count)" } }
Say 'done'

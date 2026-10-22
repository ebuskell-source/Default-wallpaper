# update.ps1 (5.4)
# Runs as SYSTEM from the "TLA BootPaper Updates" scheduled task (created by install-video.ps1): 10 minutes after
# startup and every 6 hours. On a computer Intune manages it does nothing: Intune installs each new version there.
# On the others (set up with the TLA BootPaper installer), it reads windows/latest.json in the organization's GitHub
# repository ({"version", "url", "sha256"}) and, when that version is newer than this one, downloads the installer
# and runs it silently. The installer is used only if it comes from the organization's repository and matches its
# SHA-256. (Like update.zsh on Macs that Intune doesn't manage.)

$ErrorActionPreference = 'Stop'
. ([System.IO.Path]::Combine($PSScriptRoot, 'common.ps1'))

$log = [System.IO.Path]::Combine($WV.Dir, 'updates.log')
function Write-Log([string]$Text) {
    try {
        if ([System.IO.File]::Exists($log) -and ([System.IO.FileInfo]::new($log)).Length -gt 65536) { [System.IO.File]::Delete($log) }
        [System.IO.File]::AppendAllText($log, ('{0:yyyy-MM-dd HH:mm:ss} {1}{2}' -f [DateTime]::Now, $Text, [Environment]::NewLine))
    } catch { }
}

if (Test-WVIntuneManaged) { exit 0 }   # (Intune looks after it; also when it can't tell)

try {
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }
    $client = [System.Net.WebClient]::new()
    try { $json = $client.DownloadString("$($WV.UpdateSource)/latest.json?t=$([DateTime]::UtcNow.Ticks)") } finally { $client.Dispose() }
    $data = $json | ConvertFrom-Json
    $version = "$($data.version)".Trim(); $url = "$($data.url)".Trim(); $want = "$($data.sha256)".Trim().ToLowerInvariant()
    if (-not (Test-WVVersionText $version) -or $want -notmatch '^[0-9a-f]{64}$') { Write-Log "latest.json doesn't look right; no update."; exit 0 }
    if (-not $url.StartsWith("$($WV.UpdateSource)/", [StringComparison]::Ordinal) -or $url -notmatch '/[A-Za-z0-9._-]+\.exe$') {
        Write-Log "latest.json points outside the TLA repository; no update."; exit 0
    }
    if ((ConvertTo-WVVersion $version) -le (ConvertTo-WVVersion $WV.Release)) { exit 0 }

    Write-Log "TLA BootPaper $version is out (this computer has $($WV.Release)): downloading it."
    $dir = [System.IO.Path]::Combine($env:SystemRoot, 'Temp', 'TLA BootPaper update')
    if ([System.IO.Directory]::Exists($dir)) { [System.IO.Directory]::Delete($dir, $true) }
    [void][System.IO.Directory]::CreateDirectory($dir)
    $setup = [System.IO.Path]::Combine($dir, "TLA-BootPaper-Setup-$version.exe")
    $client = [System.Net.WebClient]::new()
    try { $client.DownloadFile($url, $setup) } finally { $client.Dispose() }
    $got = Get-WVSha256 $setup
    if ($got -ne $want) { Write-Log "The TLA BootPaper $version installer doesn't match its SHA-256 ($got); not installing it."; exit 0 }
    # On its own and without waiting: the installer sets up this task again, which it can't do while the task is
    # still running it. (It cleans up its folder the next time.)
    $psi = [System.Diagnostics.ProcessStartInfo]::new($setup, '/S')
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    [void][System.Diagnostics.Process]::Start($psi)
    Write-Log "Installing TLA BootPaper $version."
} catch {
    Write-Log "Couldn't check for an update: $($_.Exception.Message)"
}
exit 0

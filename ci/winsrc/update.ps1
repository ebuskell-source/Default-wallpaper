# update.ps1 (5.4)
# Runs as SYSTEM from the "TLA BootPaper Updates" scheduled task (created by install-video.ps1): 10 minutes after
# startup, every 6 hours, and when someone clicks Check for updates. It reads windows/latest.json in the
# organization's GitHub repository ({"version", "url", "sha256"}) and, when that version is newer than this one,
# downloads the installer and runs it silently. The installer is used only if it comes from the organization's
# repository and matches its SHA-256. (Like update.zsh on Macs.) 5.9.5: on every PC. Until then, a PC Intune manages
# waited for Intune; Intune's detection script accepts newer versions, so it never puts an older one back. What
# happens goes in Care\UpdateStatus for the app's Check for updates (Set-WVUpdateStatus).

$ErrorActionPreference = 'Stop'
. ([System.IO.Path]::Combine($PSScriptRoot, 'common.ps1'))

$log = [System.IO.Path]::Combine($WV.Dir, 'updates.log')
function Write-Log([string]$Text) {
    try {
        if ([System.IO.File]::Exists($log) -and ([System.IO.FileInfo]::new($log)).Length -gt 65536) { [System.IO.File]::Delete($log) }
        [System.IO.File]::AppendAllText($log, ('{0:yyyy-MM-dd HH:mm:ss} {1}{2}' -f [DateTime]::Now, $Text, [Environment]::NewLine))
    } catch { }
}

try {
    try { $latest = Get-WVLatestUpdate }
    catch [System.IO.InvalidDataException] { Write-Log "$($_.Exception.Message); no update."; exit 0 }
    $version = $latest.Version; $url = $latest.Url; $want = $latest.Sha256
    if ((ConvertTo-WVVersion $version) -le (ConvertTo-WVVersion $WV.Release)) { exit 0 }

    Write-Log "TLA BootPaper $version is out (this computer has $($WV.Release)): downloading it."
    Set-WVUpdateStatus 'installing' $version
    $dir = [System.IO.Path]::Combine($env:SystemRoot, 'Temp', 'TLA BootPaper update')
    if ([System.IO.Directory]::Exists($dir)) { [System.IO.Directory]::Delete($dir, $true) }
    [void][System.IO.Directory]::CreateDirectory($dir)
    $setup = [System.IO.Path]::Combine($dir, "TLA-BootPaper-Setup-$version.exe")
    $client = [System.Net.WebClient]::new()
    try { $client.DownloadFile($url, $setup) }
    catch { Set-WVUpdateStatus 'failed' $version 'it couldn''t be downloaded. Check that this PC is online'; throw }
    finally { $client.Dispose() }
    $got = Get-WVSha256 $setup
    if ($got -ne $want) {
        Write-Log "The TLA BootPaper $version installer doesn't match its SHA-256 ($got); not installing it."
        Set-WVUpdateStatus 'failed' $version 'the download didn''t match what TLA published'
        exit 0
    }
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

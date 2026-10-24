# sync-videos.ps1
# Runs as SYSTEM from the "TLA BootPaper Videos" scheduled task (created by install-video.ps1): at startup and
# every 30 minutes. Downloads any intro video that's missing or out of date (see Sync-WVVideos in common.ps1),
# and (4.3) reads which release is on each release channel (Update-WVChannels). 5.7.0: and every 6 hours, the
# sign-in settings and the keys sign-ins are checked against (Update-WVSignIn).
# 4.0.5: its own task, so a long download never holds up the "TLA BootPaper Backgrounds" task, which sets
# the background someone has just picked.

$ErrorActionPreference = 'Stop'
. ([System.IO.Path]::Combine($PSScriptRoot, 'common.ps1'))

$log = [System.IO.Path]::Combine($WV.Dir, 'videos.log')
function Write-Log([string]$Text) {
    try {
        if ([System.IO.File]::Exists($log) -and ([System.IO.FileInfo]::new($log)).Length -gt 65536) { [System.IO.File]::Delete($log) }
        [System.IO.File]::AppendAllText($log, ('{0:yyyy-MM-dd HH:mm:ss} {1}{2}' -f [DateTime]::Now, $Text, [Environment]::NewLine))
    } catch { }
}

Update-WVChannels ${function:Write-Log}   # (4.3: which release is Stable and which is Experimental)
Update-WVSignIn -Log ${function:Write-Log}   # (5.7.0)
Update-WVAnnouncementCopy ${function:Write-Log}   # (5.8.0: for PCs Intune doesn't give the announcement to)
[void](Sync-WVVideos ${function:Write-Log})
exit 0

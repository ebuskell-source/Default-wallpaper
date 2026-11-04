$one = [System.Threading.Mutex]::new($false, 'Local\TLABootPaperSignInLock')
    $mine = $false
    try { $mine = $one.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $mine = $true }
    
if (-not $mine) { 'second: left'; exit }
'first: holds it'; Start-Sleep 8

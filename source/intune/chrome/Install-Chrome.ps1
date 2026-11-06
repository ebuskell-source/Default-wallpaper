# Install-Chrome.ps1 - TLA: puts Google Chrome on this PC if it isn't there (Intune platform script, as SYSTEM, 64-bit).
# Google's enterprise installer (MSI); Chrome then keeps itself up to date. Only installs a file signed by Google LLC.
$ErrorActionPreference = 'Stop'
$paths = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
if ($paths | Where-Object { Test-Path $_ }) { Write-Output 'Chrome already installed'; exit 0 }
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$msi = Join-Path $env:TEMP 'googlechromestandaloneenterprise64.msi'
Invoke-WebRequest -UseBasicParsing -Uri 'https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi' -OutFile $msi
$sig = Get-AuthenticodeSignature $msi
if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'O=Google LLC') { Remove-Item $msi -Force; throw "Signature check failed: $($sig.Status) $($sig.SignerCertificate.Subject)" }
$p = Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /qn /norestart" -Wait -PassThru
Remove-Item $msi -Force -ErrorAction SilentlyContinue
if ($p.ExitCode -notin 0, 3010) { throw "Chrome install failed (msiexec $($p.ExitCode))" }
Write-Output 'Chrome installed'

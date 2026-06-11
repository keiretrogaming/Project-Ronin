<#
.SYNOPSIS
    Project Ronin - Authenticode code-signing helper.

.DESCRIPTION
    Signs the distributable Ronin artifacts with an Authenticode certificate and an
    RFC-3161 timestamp, so the signatures stay valid after the certificate expires.

    Certificate sources (pick one):
      -Thumbprint <hex>   An EV cert on a hardware token / HSM, or an OV cert installed
                          in the Windows certificate store. (EV tokens expose the cert
                          in Cert:\CurrentUser\My or Cert:\LocalMachine\My; sign by
                          thumbprint and the token CSP prompts for the PIN.)
      -PfxPath <file>     A .pfx/.p12 file (use -PfxPassword if it is protected).
      -SelfSignedTest     Generate a throwaway, fully-trusted self-signed cert, sign
                          with it, report the result, then remove it. Use this to prove
                          the pipeline works locally BEFORE you have a real cert.
      (none)              Auto-select the first code-signing cert found in the store.

.NOTES
    EV certificates clear Microsoft SmartScreen immediately and establish publisher
    trust; OV certificates build reputation over time. Either dramatically reduces
    antivirus false positives versus an unsigned script.

.EXAMPLE
    .\Sign-Ronin.ps1 -SelfSignedTest
.EXAMPLE
    .\Sign-Ronin.ps1 -Thumbprint A1B2C3D4E5F6...   # real EV / OV cert
.EXAMPLE
    .\Sign-Ronin.ps1 -VerifyOnly                     # just show current signature status
#>
[CmdletBinding()]
param(
    [string]   $Thumbprint,
    [string]   $PfxPath,
    [string]   $PfxPassword,
    [string]   $TimestampServer = 'http://timestamp.digicert.com',
    [string[]] $Files,
    [switch]   $SelfSignedTest,
    [switch]   $VerifyOnly
)

$ErrorActionPreference = 'Stop'
$BaseDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($BaseDir)) { $BaseDir = $PWD.Path }

# Default file set: the artifacts an end-user actually downloads and runs.
if (-not $Files -or $Files.Count -eq 0) {
    $Files = @(
        (Join-Path $BaseDir 'Ronin.ps1'),
        (Join-Path $BaseDir 'run.ps1')
    )
}
$Files = @($Files | Where-Object { Test-Path $_ })
if ($Files.Count -eq 0) { Write-Error "[!] None of the target files exist. Build first (BuildRonin.ps1)."; exit 1 }

function Show-Status {
    param([string[]]$Paths)
    foreach ($f in $Paths) {
        $s = Get-AuthenticodeSignature -FilePath $f
        $color = switch ($s.Status) { 'Valid' { 'Green' } 'NotSigned' { 'DarkGray' } default { 'Yellow' } }
        Write-Host ("    {0,-13} {1}" -f $s.Status, (Split-Path $f -Leaf)) -ForegroundColor $color
    }
}

if ($VerifyOnly) {
    Write-Host "[*] Current signature status:" -ForegroundColor Cyan
    Show-Status $Files
    return
}

# ---------------------------------------------------------------------------
# Resolve the signing certificate
# ---------------------------------------------------------------------------
$cert            = $null
$cleanupSelfTest = $false
$cerTemp         = $null

if ($SelfSignedTest) {
    Write-Host "[*] Creating a throwaway self-signed code-signing certificate (TEST ONLY)..." -ForegroundColor Yellow
    $cert = New-SelfSignedCertificate -Type CodeSigningCert `
            -Subject "CN=Project Ronin TEST - DO NOT DISTRIBUTE" `
            -CertStoreLocation 'Cert:\CurrentUser\My' `
            -KeyUsage DigitalSignature -KeyExportPolicy Exportable `
            -NotAfter (Get-Date).AddDays(7)

    $cleanupSelfTest = $true
    # A self-signed cert is not chain-trusted, so the resulting status reads 'UnknownError'.
    # We deliberately do NOT install it into the Root store (that pops a Windows security
    # prompt and is a trust-store smell). This mode verifies the signing + timestamp
    # MECHANICS only; a real EV/OV cert is what produces a 'Valid' status.
    Write-Host "[i] Self-signed test: expect status 'UnknownError' (cert is not chain-trusted)." -ForegroundColor DarkGray
    Write-Host "[i] That is normal here -- a real EV/OV certificate reports 'Valid'." -ForegroundColor DarkGray
}
elseif ($PfxPath) {
    if (-not (Test-Path $PfxPath)) { Write-Error "[!] PFX not found: $PfxPath"; exit 1 }
    if ($PfxPassword) {
        $sec = ConvertTo-SecureString $PfxPassword -AsPlainText -Force
        $cert = Get-PfxCertificate -FilePath $PfxPath -Password $sec
    } else {
        $cert = Get-PfxCertificate -FilePath $PfxPath
    }
}
elseif ($Thumbprint -and $Thumbprint.Trim()) {
    $tp   = ($Thumbprint -replace '[^0-9A-Fa-f]', '').ToUpper()
    $cert = Get-ChildItem 'Cert:\CurrentUser\My','Cert:\LocalMachine\My' -CodeSigningCert -ErrorAction SilentlyContinue |
            Where-Object { $_.Thumbprint -eq $tp } | Select-Object -First 1
    if (-not $cert) {
        Write-Error "[!] No code-signing cert with thumbprint $tp in CurrentUser\My or LocalMachine\My. List candidates with:  Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert"
        exit 1
    }
}
else {
    $candidates = @(Get-ChildItem 'Cert:\CurrentUser\My','Cert:\LocalMachine\My' -CodeSigningCert -ErrorAction SilentlyContinue)
    if ($candidates.Count -eq 0) {
        Write-Error "[!] No code-signing certificate found. Provide -Thumbprint, -PfxPath, or use -SelfSignedTest."
        exit 1
    }
    if ($candidates.Count -gt 1) {
        Write-Host "[*] Multiple code-signing certs found; using the first. Specify -Thumbprint to choose:" -ForegroundColor Yellow
        $candidates | ForEach-Object { Write-Host ("    {0}  {1}" -f $_.Thumbprint, $_.Subject) -ForegroundColor DarkGray }
    }
    $cert = $candidates[0]
}

# ---------------------------------------------------------------------------
# Sign
# ---------------------------------------------------------------------------
Write-Host "[*] Signing with: $($cert.Subject)  [$($cert.Thumbprint)]" -ForegroundColor Cyan
Write-Host "[*] Timestamp   : $TimestampServer" -ForegroundColor DarkGray

$failed = 0
foreach ($f in $Files) {
    try {
        $res = Set-AuthenticodeSignature -FilePath $f -Certificate $cert `
               -HashAlgorithm SHA256 -TimestampServer $TimestampServer -ErrorAction Stop
        $ok = ($res.Status -eq 'Valid')
        Write-Host ("    [{0}] {1}" -f $res.Status, (Split-Path $f -Leaf)) -ForegroundColor $(if ($ok) { 'Green' } else { 'Yellow' })
        if (-not $ok -and -not $SelfSignedTest) { $failed++ }
    } catch {
        Write-Host ("    [ERROR] {0}: {1}" -f (Split-Path $f -Leaf), $_.Exception.Message) -ForegroundColor Red
        $failed++
    }
}

# ---------------------------------------------------------------------------
# Cleanup throwaway test cert
# ---------------------------------------------------------------------------
if ($cleanupSelfTest) {
    foreach ($store in 'My','Root','TrustedPublisher') {
        Remove-Item ("Cert:\CurrentUser\{0}\{1}" -f $store, $cert.Thumbprint) -Force -ErrorAction SilentlyContinue
    }
    if ($cerTemp -and (Test-Path $cerTemp)) { Remove-Item $cerTemp -Force -ErrorAction SilentlyContinue }
    Write-Host "[*] Removed throwaway test certificate from all stores." -ForegroundColor DarkGray
    Write-Warning "[!] The TEST signature remains on the files but will no longer validate (cert was removed). Rebuild, or re-sign with a real cert before releasing."
}

if ($failed -gt 0) { Write-Error "[!] $failed file(s) failed to sign."; exit 1 }
Write-Host "[+] Signing complete." -ForegroundColor Green

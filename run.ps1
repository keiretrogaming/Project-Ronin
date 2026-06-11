# ==============================================================================
# Project Ronin - Online Bootstrapper v7.3.1
# https://github.com/keiretrogaming/Project-Ronin
#
# Downloads the latest monolithic Ronin.ps1 from the official GitHub repository
# and runs it. This is the standard one-line installer pattern used by WinUtil,
# Scoop, Chocolatey, and many other reputable Windows utilities.
# ==============================================================================

$ErrorActionPreference = 'Stop'

$ProjectName = 'Project Ronin'
$ProjectUrl  = 'https://github.com/keiretrogaming/Project-Ronin'
$ScriptUrl   = 'https://raw.githubusercontent.com/keiretrogaming/Project-Ronin/main/Ronin.ps1'

# Use ProgramData rather than TEMP - more legitimate location for an admin tool
$DownloadDir = Join-Path $env:ProgramData 'Ronin'
$DownloadPath = Join-Path $DownloadDir 'Ronin.ps1'

if (!(Test-Path $DownloadDir)) {
    New-Item -Path $DownloadDir -ItemType Directory -Force | Out-Null
}

Write-Host ''
Write-Host "  $ProjectName Online Installer" -ForegroundColor Cyan
Write-Host "  $ProjectUrl" -ForegroundColor DarkGray
Write-Host ''
Write-Host '[*] Downloading the latest release...' -ForegroundColor Cyan

# Use TLS 1.2 (required for GitHub on PS 5.1)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

try {
    Invoke-WebRequest -Uri $ScriptUrl -OutFile $DownloadPath -UseBasicParsing
} catch {
    Write-Error "Download failed: $($_.Exception.Message)"
    exit 1
}

if (!(Test-Path $DownloadPath)) {
    Write-Error 'Download did not produce a file.'
    exit 1
}

Write-Host '[+] Download complete.' -ForegroundColor Green
Write-Host '[*] Launching Ronin...' -ForegroundColor Cyan
Write-Host ''

# Launch with proper elevation
$psArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $DownloadPath)
Start-Process -FilePath 'powershell.exe' -ArgumentList $psArgs -Verb RunAs

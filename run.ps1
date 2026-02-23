# Project Ronin: Shogun Bootstrapper
$url = "https://raw.githubusercontent.com/keiretrogaming/Project-Ronin/main/Ronin.ps1"
$tempPath = "$env:TEMP\Ronin_Monolith.ps1"

Write-Host "[*] Downloading Project Ronin Engine..." -ForegroundColor Cyan

# Download the monolithic script to a file instead of RAM
Invoke-RestMethod -Uri $url -OutFile $tempPath

# Launch the file from the disk (This is much more "trustworthy" to AV)
if (Test-Path $tempPath) {
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tempPath`"" -Verb RunAs
} else {
    Write-Error "Download Failed."
}
# run.ps1 - Project Ronin Cloud Bootstrapper v7.0.4
$ErrorActionPreference = "Stop"

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "    INITIALIZING PROJECT RONIN...     " -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

$repoZipUrl = "https://github.com/keiretrogaming/Project-Ronin/archive/refs/heads/main.zip"
$tempZip = "$env:TEMP\Ronin.zip"
$extractPath = "$env:TEMP\Ronin_Live"

# Cleanup
if (Test-Path $tempZip) { Remove-Item $tempZip -Force }
if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }

try {
    Write-Host "Downloading latest engine..." -ForegroundColor Gray
    Invoke-WebRequest -Uri $repoZipUrl -OutFile $tempZip -UseBasicParsing
    
    Write-Host "Extracting assets..." -ForegroundColor Gray
    Expand-Archive -Path $tempZip -DestinationPath $extractPath -Force
    
    $extractedFolder = Get-ChildItem -Path $extractPath -Directory | Select-Object -First 1
    # Ensure this matches your repo structure (src\Ronin.ps1)
    $RoninScript = Join-Path $extractedFolder.FullName "src\Ronin.ps1"
    
    Write-Host "Deploying UI..." -ForegroundColor Green
    
    # GUARDIAN FIX: Removed -WindowStyle Hidden to prevent AV behavioral flags.
    # This matches Winutil's launch transparency.
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$RoninScript`"" -Verb RunAs
} catch {
    Write-Host "FATAL ERROR: Failed to download or run Project Ronin." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Start-Sleep -Seconds 10
}
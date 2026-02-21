# run.ps1 - Project Ronin Cloud Bootstrapper
$ErrorActionPreference = "Stop"

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "   INITIALIZING PROJECT RONIN...     " -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

# Pointing directly to your GitHub repository
$repoZipUrl = "https://github.com/keiretrogaming/Project-Ronin/archive/refs/heads/main.zip"
$tempZip = "$env:TEMP\Ronin.zip"
$extractPath = "$env:TEMP\Ronin_Live"

# Cleanup previous instances
if (Test-Path $tempZip) { Remove-Item $tempZip -Force }
if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }

try {
    Write-Host "Downloading latest engine..." -ForegroundColor Gray
    Invoke-WebRequest -Uri $repoZipUrl -OutFile $tempZip -UseBasicParsing
    
    Write-Host "Extracting assets..." -ForegroundColor Gray
    Expand-Archive -Path $tempZip -DestinationPath $extractPath -Force
    
    # Automatically find the extracted folder
    $extractedFolder = Get-ChildItem -Path $extractPath -Directory | Select-Object -First 1
    $RoninScript = "$($extractedFolder.FullName)\src\Ronin.ps1"
    
    Write-Host "Deploying UI..." -ForegroundColor Green
    
    # Launch bypassed and elevated natively
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$RoninScript`"" -Verb RunAs
} catch {
    Write-Host "FATAL ERROR: Failed to download or run Project Ronin." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Start-Sleep -Seconds 10
}
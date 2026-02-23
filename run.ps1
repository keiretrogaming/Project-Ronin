# run.ps1 - Project Ronin Cloud Bootstrapper v7.1.0
$ErrorActionPreference = "Stop"

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "    INITIALIZING PROJECT RONIN...    " -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

# --- 1. PREPARE WORKSPACE ---
# We use ProgramData instead of Temp as it is more reliable for app setups
$Workspace = Join-Path $env:ProgramData "ProjectRonin"
if (-not (Test-Path $Workspace)) { 
    New-Item -Path $Workspace -ItemType Directory -Force | Out-Null 
}

$repoZipUrl = "https://github.com/keiretrogaming/Project-Ronin/archive/refs/heads/main.zip"
$tempZip = Join-Path $Workspace "RoninCore.zip"
$extractPath = Join-Path $Workspace "Ronin_Live"

# Clean up any files from previous updates
if (Test-Path $tempZip) { Remove-Item $tempZip -Force }
if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }

try {
    # --- 2. DOWNLOAD ENGINE ---
    Write-Host "Downloading latest engine..." -ForegroundColor Gray
    # Using native .NET WebClient for better compatibility and speed
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($repoZipUrl, $tempZip)
    $webClient.Dispose()
    
    # --- 3. EXTRACT ASSETS ---
    Write-Host "Extracting assets..." -ForegroundColor Gray
    # Using native .NET Compression for faster, silent extraction
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($tempZip, $extractPath)
    
    # Locate the extracted source directory automatically
    $extractedFolder = Get-ChildItem -Path $extractPath -Directory | Select-Object -First 1
    $RoninScript = Join-Path $extractedFolder.FullName "src\Ronin.ps1"
    
    # --- 4. LAUNCH UI ---
    Write-Host "Deploying UI..." -ForegroundColor Green
    
    # Launch natively with a visible window (user transparency)
    $launchArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Normal -File `"$RoninScript`""
    Start-Process powershell.exe -ArgumentList $launchArgs -Verb RunAs

} catch {
    Write-Host "FATAL ERROR: Failed to download or deploy Project Ronin." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Start-Sleep -Seconds 10
}
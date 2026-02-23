# Build-Ronin.ps1 - Compiles Project Ronin
$BaseDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($BaseDir)) { $BaseDir = $PWD.Path }

Write-Host "Compiling Single-File Executable..." -ForegroundColor Cyan

$Xaml = Get-Content (Join-Path $BaseDir "UI\Ronin.xaml") -Raw
$Core = Get-Content (Join-Path $BaseDir "src\RoninCore.ps1") -Raw
$DB   = Get-Content (Join-Path $BaseDir "src\RoninDB.ps1") -Raw
$Main = Get-Content (Join-Path $BaseDir "src\Ronin.ps1") -Raw

# 1. Inject the XAML directly as a string (No file reading needed)
$XamlInject = "`$xamlContent = @'`n$Xaml`n'@`n"
$Main = $Main -replace '(?s)\$xamlContent\s*=\s*Get-Content\s*\$XamlPath\s*-Raw\s*-Encoding\s*UTF8', $XamlInject

# 2. Inject the Core and DB logic into the Runspace (No dot-sourcing external files)
$RunspaceInject = @"
        # --- INJECTED CORE & DB ---
        $Core
        $DB
"@
$Main = $Main -replace '(?s)\$CorePath\s*=\s*Join-Path.*?\. \$DBPath', $RunspaceInject

# 3. Strip out the old file integrity checks (Since it's all one file now)
$Main = $Main -replace '(?s)# --- 2\. FILE INTEGRITY CHECKS ---.*?# --- 3\. HARDENED XAML LOADING', '# --- 3. HARDENED XAML LOADING'

# 4. Add the WinUtil-Style Cloud Elevation Header (Relaunches as Admin automatically)
$Header = @"
# ==============================================================================
# PROJECT RONIN // DEFINITIVE EDITION (SINGLE FILE RELEASE)
# ==============================================================================
`$ErrorActionPreference = "Stop"

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Elevating Ronin to Administrator..." -ForegroundColor Cyan
    `$scriptUrl = "https://raw.githubusercontent.com/keiretrogaming/Project-Ronin/main/Ronin.ps1"
    `$script = if (`$PSCommandPath) { "& { & `'`$(`$PSCommandPath)`' }" } else { "&([ScriptBlock]::Create((irm `$scriptUrl)))" }
    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -NoProfile -WindowStyle Normal -Command `"`$script`"" -Verb RunAs
    exit
}

"@

$FinalOutput = $Header + $Main
Set-Content -Path (Join-Path $BaseDir "Ronin.ps1") -Value $FinalOutput -Encoding UTF8

Write-Host "Build Complete! Push the new Ronin.ps1 to GitHub." -ForegroundColor Green
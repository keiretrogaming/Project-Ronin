<#
.SYNOPSIS
    Project Ronin Core Engine v7.3.1 - Background worker, registry helpers, job dispatcher.

.DESCRIPTION
    Module loaded by Ronin.ps1. Contains:
    - Registry read/write helpers with snapshot-based rollback
    - Scheduled task and service helpers (with schtasks.exe fallback)
    - Background runspace worker for async tweak application
    - System audit / sensor / app detection routines

.NOTES
    Project: https://github.com/keiretrogaming/Project-Ronin
    License: MIT
#>

# --- PROJECT RONIN: CORE ENGINE v7.3.1 "SHOGUN EDITION" ---

Add-Type -AssemblyName PresentationFramework, System.Windows.Forms, System.Drawing, WindowsBase

$Global:SnapshotFile = "$env:ProgramData\Ronin\Ronin_Snapshots.json"
$Global:SnapshotCache = @{}

$Global:RoninLogFile = "$env:ProgramData\Ronin\Ronin.log"
$Global:RoninDiagFile = "$env:ProgramData\Ronin\Ronin_Diagnostic.log"
$Global:RoninAuditFile = "$env:ProgramData\Ronin\Ronin_StateReport.txt"
# Diagnostic mode captures verbose internals (thread tags, durations, full exceptions, stack traces).
# Always on by default in 7.3.1 so users can produce a complete log for bug reports.
$Global:RoninDiagMode = $true

function Log ($Msg) { 
    # User-facing log: shows in the console panel + persists to Ronin.log
    $Time = Get-Date -Format "HH:mm:ss"
    $FinalMsg = "[$Time] $Msg"
    # Persist to log file so user can review failures after the fact
    try {
        $logDir = Split-Path $Global:RoninLogFile -Parent
        if (!(Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
        Add-Content -Path $Global:RoninLogFile -Value $FinalMsg -ErrorAction SilentlyContinue
    } catch {}
    # Mirror to the diagnostic log too (so the diag file is a complete superset).
    # Guarded: Log may be called during early startup before Write-Diag is defined.
    if (Get-Command Write-Diag -ErrorAction SilentlyContinue) { Write-Diag $Msg "USER" }
    # Update the on-screen console (guard against shutdown / missing control)
    try {
        if ($SyncHash -and $SyncHash.Window -and -not $SyncHash.Window.Dispatcher.HasShutdownStarted) {
            $SyncHash.Window.Dispatcher.Invoke({ 
                try {
                    if ($SyncHash.Console) {
                        $SyncHash.Console.Text += "`n$FinalMsg"
                        $SyncHash.Scroll.ScrollToEnd()
                    }
                } catch {}
            })
        }
    } catch {}
}

function Write-Diag ($Msg, $Level = "INFO") {
    # Verbose diagnostic logger. Captures thread id, level, millisecond timestamp.
    # Writes to Ronin_Diagnostic.log only (never touches the UI, so it's thread-safe and fast).
    if (-not $Global:RoninDiagMode) { return }
    try {
        $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $threadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        # Identify the thread role where possible
        $role = "?"
        try {
            if ($SyncHash -and $SyncHash.MainThreadId -and $threadId -eq $SyncHash.MainThreadId) { $role = "UI" }
            elseif ($SyncHash -and $SyncHash.EngineThreadId -and $threadId -eq $SyncHash.EngineThreadId) { $role = "ENGINE" }
            elseif ($SyncHash -and $SyncHash.WatcherThreadId -and $threadId -eq $SyncHash.WatcherThreadId) { $role = "WATCHER" }
        } catch {}
        $line = "[$ts][T$threadId/$role][$Level] $Msg"
        $logDir = Split-Path $Global:RoninDiagFile -Parent
        if (!(Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
        Add-Content -Path $Global:RoninDiagFile -Value $line -ErrorAction SilentlyContinue
    } catch {}
}

function Write-DiagException ($Context, $ErrorRecord) {
    # Detailed exception logger - captures message, type, line number, and call stack.
    if (-not $Global:RoninDiagMode) { return }
    try {
        $exMsg  = $ErrorRecord.Exception.Message
        $exType = $ErrorRecord.Exception.GetType().FullName
        $line   = $ErrorRecord.InvocationInfo.ScriptLineNumber
        $cmd    = $ErrorRecord.InvocationInfo.Line
        if ($cmd) { $cmd = $cmd.Trim() }
        Write-Diag "EXCEPTION in [$Context]: $exMsg" "ERROR"
        Write-Diag "  Type: $exType | Line: $line" "ERROR"
        if ($cmd) { Write-Diag "  Statement: $cmd" "ERROR" }
        if ($ErrorRecord.ScriptStackTrace) {
            foreach ($stackLine in ($ErrorRecord.ScriptStackTrace -split "`n")) {
                if ($stackLine.Trim()) { Write-Diag "  Stack: $($stackLine.Trim())" "ERROR" }
            }
        }
    } catch {}
}

function Start-DiagSession {
    # Writes a session header to the diagnostic log with full environment info.
    if (-not $Global:RoninDiagMode) { return }
    try {
        $logDir = Split-Path $Global:RoninDiagFile -Parent
        if (!(Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
        $sep = "=" * 78
        Add-Content -Path $Global:RoninDiagFile -Value "" -ErrorAction SilentlyContinue
        Add-Content -Path $Global:RoninDiagFile -Value $sep -ErrorAction SilentlyContinue
        Add-Content -Path $Global:RoninDiagFile -Value "  PROJECT RONIN DIAGNOSTIC SESSION" -ErrorAction SilentlyContinue
        Add-Content -Path $Global:RoninDiagFile -Value "  Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ErrorAction SilentlyContinue
        Add-Content -Path $Global:RoninDiagFile -Value $sep -ErrorAction SilentlyContinue

        # Environment block - everything needed to reproduce/diagnose
        $os = $null; $cs = $null; $cpu = $null
        try { $os  = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue } catch {}
        try { $cs  = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue } catch {}
        try { $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1 } catch {}
        $gpu = $null
        try { $gpu = (Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select-Object -First 1).Name } catch {}

        Write-Diag "Ronin Version    : 7.3.1" "ENV"
        Write-Diag "OS               : $($os.Caption) (Build $($os.BuildNumber))" "ENV"
        Write-Diag "OS Version       : $($os.Version)" "ENV"
        Write-Diag "PowerShell       : $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))" "ENV"
        Write-Diag "Machine Model    : $($cs.Manufacturer) $($cs.Model)" "ENV"
        Write-Diag "CPU              : $($cpu.Name)" "ENV"
        Write-Diag "GPU              : $gpu" "ENV"
        Write-Diag "RAM (GB)         : $([Math]::Round($cs.TotalPhysicalMemory / 1GB, 1))" "ENV"
        $isAdmin = $false
        try { $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) } catch {}
        Write-Diag "Administrator    : $isAdmin" "ENV"
        Write-Diag "Culture          : $((Get-Culture).Name)" "ENV"
        Add-Content -Path $Global:RoninDiagFile -Value $sep -ErrorAction SilentlyContinue
    } catch {}
}

# --- DEFENSIVE ENGINEER FIX: PS 5.1 Compatible JSON Parsing ---
if (Test-Path $Global:SnapshotFile) {
    try { 
        $jsonContent = Get-Content $Global:SnapshotFile -Raw
        if (-not [string]::IsNullOrWhiteSpace($jsonContent)) {
            $jsonObj = $jsonContent | ConvertFrom-Json
            if ($jsonObj) {
                $jsonObj.psobject.properties | ForEach-Object {
                    $Global:SnapshotCache[$_.Name] = $_.Value
                }
            }
        }
    } catch { 
        Log "Snapshot Warning: Failed to parse previous backups. Initiating fresh cache." 
    }
}

function Backup-Value ($Path, $Name) {
    try {
        $ID = "$Path\$Name".ToLower()
        if ($Global:SnapshotCache.ContainsKey($ID)) { return }
        if (Test-Path $Path) {
            $current = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
            if ($current -and $current.$Name -ne $null) {
                $Global:SnapshotCache[$ID] = $current.$Name
                # NOTE: Disk write is batched after job completion, not per-call
            }
        }
    } catch { Log "Snapshot Error: $($_.Exception.Message)" }
}

function Set-Reg ($Path, $Name, $Val, $Type="DWord") { 
    Backup-Value $Path $Name
    if(!(Test-Path $Path)){ New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -Path $Path -Name $Name -Value $Val -PropertyType $Type -Force | Out-Null
}

function Remove-Reg ($Path, $Name) {
    Backup-Value $Path $Name
    if (Test-Path $Path) { Remove-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue }
}

function Test-Reg-Read ($Path, $Name, $TargetVal) {
    # Uses SilentlyContinue + null check to avoid generating terminating errors
    # for missing properties. Terminating errors get logged to Start-Transcript
    # even when caught, polluting the crash log with hundreds of false positives.
    if (-not (Test-Path -LiteralPath $Path -ErrorAction SilentlyContinue)) { return $false }
    $v = Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction SilentlyContinue
    if ($null -eq $v) { return $false }
    $actual = $v.$Name
    if ($null -eq $actual) { return $false }
    return ("$actual" -eq "$TargetVal")
}

function Test-Reg-Robust ($Path, $Name, $TargetVal, $RetryCount=3) {
    for ($i = 0; $i -lt $RetryCount; $i++) {
        if (Test-Reg-Read $Path $Name $TargetVal) { return $true }
        Start-Sleep -Milliseconds 100
    }
    return $false
}

function Disable-Task ($Path, $Name) {
    $taskFull = ($Path.TrimEnd('\') + '\' + $Name)
    # First check if the task even exists - many tasks listed in our DB are not present on all SKUs
    $task = Get-ScheduledTask -TaskPath ($Path.TrimEnd('\') + '\') -TaskName $Name -ErrorAction SilentlyContinue
    if (-not $task) { Log "  - Task not present (skipped): $taskFull"; return $true }
    if ($task.State -eq 'Disabled') { Log "  - Already disabled: $taskFull"; return $true }
    # Try the cmdlet first
    try {
        Disable-ScheduledTask -TaskPath ($Path.TrimEnd('\') + '\') -TaskName $Name -ErrorAction Stop | Out-Null
        Log "  - Disabled: $taskFull"
        return $true
    } catch {
        # Fallback to schtasks.exe (sometimes succeeds where the cmdlet fails)
        try {
            $out = & schtasks.exe /Change /TN $taskFull /Disable 2>&1
            if ($LASTEXITCODE -eq 0) {
                Log "  - Disabled via schtasks: $taskFull"
                return $true
            } else {
                Log "  - PROTECTED (cannot disable, system-locked): $taskFull"
                return $false
            }
        } catch {
            Log "  - PROTECTED (cannot disable, system-locked): $taskFull"
            return $false
        }
    }
}

function Enable-Task ($Path, $Name) {
    $taskFull = ($Path.TrimEnd('\') + '\' + $Name)
    $task = Get-ScheduledTask -TaskPath ($Path.TrimEnd('\') + '\') -TaskName $Name -ErrorAction SilentlyContinue
    if (-not $task) { Log "  - Task not present (skipped): $taskFull"; return $true }
    if ($task.State -ne 'Disabled') { Log "  - Already enabled: $taskFull"; return $true }
    try {
        Enable-ScheduledTask -TaskPath ($Path.TrimEnd('\') + '\') -TaskName $Name -ErrorAction Stop | Out-Null
        Log "  - Enabled: $taskFull"
        return $true
    } catch {
        try {
            $out = & schtasks.exe /Change /TN $taskFull /Enable 2>&1
            if ($LASTEXITCODE -eq 0) {
                Log "  - Enabled via schtasks: $taskFull"
                return $true
            } else {
                Log "  - PROTECTED (cannot enable): $taskFull"
                return $false
            }
        } catch {
            Log "  - PROTECTED (cannot enable): $taskFull"
            return $false
        }
    }
}

function Set-Service-Registry ($ServiceName, $StartType) {
    # Bypass for system-protected services that reject Set-Service
    # Start values: 2=Automatic, 3=Manual, 4=Disabled
    $val = switch ($StartType) { 'Automatic' { 2 } 'Manual' { 3 } 'Disabled' { 4 } default { 3 } }
    $path = "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName"
    if (Test-Path $path) {
        try {
            Set-ItemProperty -LiteralPath $path -Name "Start" -Value $val -Type DWord -Force -ErrorAction Stop
            Log "  - Service $ServiceName -> $StartType (via registry)"
            return $true
        } catch {
            Log "  - Failed to set $ServiceName via registry: $($_.Exception.Message)"
            return $false
        }
    } else {
        Log "  - Service $ServiceName not present (skipped)"
        return $true
    }
}
function Restart-Explorer { Log "Executing Explorer Shell Refresh..."; Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue }

function Check-Internet { 
    if (Test-Connection 8.8.8.8 -Count 1 -Quiet) { return $true }
    try { $r = Invoke-WebRequest "http://www.msftconnecttest.com/connecttest.txt" -UseBasicParsing -TimeoutSec 1; return ($r.StatusCode -eq 200) } catch { return $false }
}

function Test-BitLocker { try { $bl = Get-BitLockerVolume -MountPoint "C:" -ErrorAction SilentlyContinue; if ($bl -and $bl.ProtectionStatus -eq "On") { return $true } } catch {}; return $false }

function Get-GpuRegistryPath ($VendorString) {
    # Expand vendor aliases so callers can pass simple names ("AMD", "NVIDIA", "Intel")
    # while matching against the official ProviderName strings used by drivers
    # (e.g. AMD's official ProviderName is "Advanced Micro Devices, Inc." which doesn't contain "AMD")
    $expandedPattern = switch -Regex ($VendorString) {
        '^AMD$'                  { 'AMD|Advanced Micro Devices|ATI Technologies' }
        '^NVIDIA$'               { 'NVIDIA' }
        '^Intel$'                { 'Intel' }
        '^NVIDIA\|AMD$|^AMD\|NVIDIA$' { 'NVIDIA|AMD|Advanced Micro Devices|ATI Technologies' }
        default                  { $VendorString }
    }
    try {
        $ClassPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
        if (!(Test-Path -LiteralPath $ClassPath)) { return $null }
        $Keys = Get-ChildItem -LiteralPath $ClassPath -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' }
        foreach ($k in $Keys) {
            $Prov = (Get-ItemProperty -LiteralPath $k.PSPath -Name "ProviderName" -ErrorAction SilentlyContinue).ProviderName
            $Desc = (Get-ItemProperty -LiteralPath $k.PSPath -Name "DriverDesc"   -ErrorAction SilentlyContinue).DriverDesc
            if (($Prov -and $Prov -match $expandedPattern) -or ($Desc -and $Desc -match $expandedPattern)) { 
                return $k.PSPath 
            }
        }
    } catch {}
    return $null
}

function Set-AMD-Feature ($FeatureName, $Value) {
    try {
        $p = Get-GpuRegistryPath "AMD"
        if ($p) {
            # Use -LiteralPath to safely handle the {GUID} braces in the registry path
            Set-ItemProperty -LiteralPath $p -Name $FeatureName -Value $Value -Type DWord -Force -ErrorAction Stop
            Log "  - AMD Feature $FeatureName = $Value (path: $p)"
        } else {
            Log "  - AMD GPU not detected; skipping $FeatureName"
        }
    } catch { Log "  - AMD Feature Error ($FeatureName): $($_.Exception.Message)" }
}

function Get-CpuBoostMode ($State = "AC") {
    try {
        $schemeOutput = powercfg /getactivescheme | Out-String
        if ($schemeOutput -match "([a-fA-F0-9-]{36})") { $guid = $matches[1] } else { return -1 }
        
        # MUST USE /qh for hidden processor settings
        $out = powercfg /qh $guid sub_processor be337238-0d82-4146-a960-4f3749d470c7 | Out-String
        if ($out -match "Current $State Power Setting Index:\s+0x([0-9a-fA-F]+)") {
            return [Convert]::ToInt32($matches[1], 16)
        }
    } catch {}
    return -1
}

function Get-EPP-Value ($State = "AC") {
    try {
        $schemeOutput = powercfg /getactivescheme | Out-String
        if ($schemeOutput -match "([a-fA-F0-9-]{36})") { $guid = $matches[1] } else { return 50 }
        
        # MUST USE /qh for hidden processor settings
        $out = powercfg /qh $guid sub_processor 36687f9e-e3a5-4dbf-b1dc-15eb381c6863 | Out-String
        if ($out -match "Current $State Power Setting Index:\s+0x([0-9a-fA-F]+)") {
            return [Convert]::ToInt32($matches[1], 16)
        }
    } catch {}
    return 50 
}

function Set-PCIe-Mode ($EnablePerformance) {
    try {
        $schemeOutput = powercfg /getactivescheme | Out-String
        if ($schemeOutput -match "([a-fA-F0-9-]{36})") {
            $activeScheme = $matches[1]
            $sub = "501a4d13-42af-4429-9fd1-a8218c268e20"
            $setting = "ee12f906-d277-404b-b6da-e5fa1a576df5"
            if ($EnablePerformance) {
                powercfg /setacvalueindex $activeScheme $sub $setting 0
                powercfg /setdcvalueindex $activeScheme $sub $setting 0
            } else {
                powercfg /setacvalueindex $activeScheme $sub $setting 2
                powercfg /setdcvalueindex $activeScheme $sub $setting 2
            }
            powercfg /setactive $activeScheme
        }
    } catch { Log "PCIe Error: $($_.Exception.Message)" }
}

function Get-PCIe-State {
    try {
        $schemeOutput = powercfg /getactivescheme | Out-String
        if ($schemeOutput -match "([a-fA-F0-9-]{36})") {
            $activeScheme = $matches[1]
            $sub = "501a4d13-42af-4429-9fd1-a8218c268e20"
            $setting = "ee12f906-d277-404b-b6da-e5fa1a576df5"
            $out = powercfg /qh $activeScheme $sub $setting | Out-String
            if ($out -match "Current AC Power Setting Index:\s+0x([0-9a-fA-F]+)") {
                return [Convert]::ToInt32($matches[1], 16)
            }
        }
    } catch {}
    return -1
}

# --- AV SAFE SENSORS (Standard WMI/CIM Loop) ---
function Update-Sensors {
    try {
        if ($SyncHash.Window.Dispatcher.HasShutdownStarted) { return }
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os) {
            $used = [Math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1048576, 1)
            $ram = "$used GB"
        } else { $ram = "..." }
        
        $SyncHash.Window.Dispatcher.Invoke({ 
            try { 
                if ($SyncHash.RamStatus) { $SyncHash.RamStatus.Text = "RAM USAGE: $ram" }
                if ($SyncHash.CpuStatus) { $SyncHash.CpuStatus.Text = $script:CpuName }
            } catch {} 
        })
    } catch {}
}

function Update-Tweaks {
    if ($SyncHash.Window.Dispatcher.HasShutdownStarted) { return }
    Log "Auditing System State..."
    $Status = @{} ; $totalActive = 0; $relevantDbSize = 0
    foreach ($k in $RoninDB.Keys) {
        if ($RoninDB[$k].Check) {
            try {
                $Status[$k] = & {
                    $ErrorActionPreference = 'SilentlyContinue'
                    & $RoninDB[$k].Check
                }
            } catch { $Status[$k] = $false }
        }
    }

    # --- WRITE FULL STATE REPORT ---
    # Persist the on/off state of every tweak so the user can review exactly what is
    # active, inactive, or failing -- the event log shows actions, this shows current state.
    try {
        $rep = New-Object System.Collections.Generic.List[string]
        $rep.Add("=" * 72)
        $rep.Add("  PROJECT RONIN v7.3.1 - SYSTEM STATE REPORT")
        $rep.Add("  Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
        $rep.Add("  Legend: [ON ] active   [off] inactive/default   [SET#] combo-box index")
        $rep.Add("=" * 72)
        $onCount = 0
        foreach ($k in ($Status.Keys | Sort-Object)) {
            $v = $Status[$k]
            if ($v -is [int]) {
                $tag = "SET$v"
                if ($v -ge 1) { $onCount++ }
            } elseif (($v -is [bool] -and $v) -or ("$v" -eq "True")) {
                $tag = "ON "; $onCount++
            } else {
                $tag = "off"
            }
            $rep.Add(("  [{0}] {1}" -f $tag, $k))
        }
        $rep.Add("-" * 72)
        $rep.Add("  Summary: $onCount of $($Status.Count) tweaks active.  Full event log: Ronin.log")
        [System.IO.File]::WriteAllLines($Global:RoninAuditFile, $rep)
        Write-Diag "State report written ($onCount/$($Status.Count) active) -> $Global:RoninAuditFile" "ENGINE"
    } catch { Write-Diag "State report write failed: $($_.Exception.Message)" "ERROR" }

    $SyncHash.Window.Dispatcher.Invoke([Action]{
        # Detect Handheld Status once for math
        $isHandheld = $false
        try { 
            $cimComp = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
            if ($cimComp -and ($cimComp.Model -match "RC71|83[E-G]1|83S|Claw|Jupiter")) { $isHandheld = $true } 
        } catch {}

        foreach ($k in $Status.Keys) {
            $c = $SyncHash.Window.FindName($k)
            if ($null -ne $c) {
                # Hardware Relevance Check
                $isHardwareRelevant = $true
                if ($k.StartsWith("HH_") -and -not $isHandheld) { $isHardwareRelevant = $false }

                if ($c -is [System.Windows.Controls.CheckBox]) { 
                    $c.IsChecked = $Status[$k]
                    if ($Status[$k]) { 
                        $c.Foreground = [System.Windows.Media.Brushes]::LimeGreen
                        if ($isHardwareRelevant) { $totalActive++ } 
                    }
                    else { $c.Foreground = [System.Windows.Media.Brushes]::Gray }
                    
                    # DENOMINATOR: Only count CheckBoxes in the "Total" possible score
                    if ($isHardwareRelevant) { $relevantDbSize++ }
                }
                elseif ($c -is [System.Windows.Controls.ComboBox]) {
                    # Update UI position but EXCLUDE from points math entirely.
                    # Guarded: Status value must be a non-null integer and within the ComboBox range.
                    try {
                        $sval = $Status[$k]
                        if ($null -ne $sval -and $sval -is [int] -and $sval -ge 0 -and $sval -lt $c.Items.Count) {
                            $c.SelectedIndex = $sval
                        }
                    } catch {}
                }
            }
        }
        
        # UI Profile Sync
        foreach ($sysKey in $AutoMap.Keys) {
            $autoC = $SyncHash.Window.FindName($AutoMap[$sysKey])
            if ($null -ne $autoC) { $autoC.IsChecked = $Status[$sysKey]; $autoC.Foreground = if($Status[$sysKey]){ [System.Windows.Media.Brushes]::LimeGreen } else { [System.Windows.Media.Brushes]::Gray } }
        }

        # --- Final Rank Math (weighted, recommended-set based) ---
        # The old math was "active toggles / ALL hardware-relevant toggles", which (a) made
        # 100% impossible without enabling every expert/optional toggle, (b) ignored combo-box
        # tweaks entirely, and (c) rewarded enabling optional features (WSL/Hyper-V) as if they
        # were optimizations. Instead we score against the curated Auto-Optimize set ($AutoMap),
        # weighted by real impact. 100% = "the recommended profile is fully applied".
        $RankWeights = @{
            'Priv_Tele'=3; 'Sys_Recall'=3; 'Game_HAGS'=3; 'Sys_VisualFX'=2; 'Priv_Copilot'=2;
            'Priv_AdID'=2; 'Priv_ActivityUpload'=2; 'Sys_StartAds'=2; 'Game_GameMode'=2;
            'Priv_ConsumerFeatures'=2; 'Sys_CpuOpt'=2; 'Sys_DeviceInstall'=2
        }
        $earned = 0.0; $possible = 0.0
        foreach ($sysKey in $AutoMap.Keys) {
            if (-not $RoninDB.ContainsKey($sysKey)) { continue }
            if ($sysKey.StartsWith("HH_") -and -not $isHandheld) { continue }   # skip handheld tweaks on desktops
            $w = if ($RankWeights.ContainsKey($sysKey)) { $RankWeights[$sysKey] } else { 1 }
            $possible += $w
            $sv = $Status[$sysKey]
            if (($sv -is [bool] -and $sv) -or ("$sv" -eq "True") -or ($sv -is [int] -and $sv -ge 1)) { $earned += $w }
        }
        $percent = if ($possible -gt 0) { [Math]::Min(100, ($earned / $possible) * 100) } else { 0 }
        $SyncHash.HealthBar.Value = $percent
        
        if ($percent -ge 80) {
            $SyncHash.HealthRank.Text = "SYSTEM RANK: S-TIER (FULLY OPTIMIZED)"
            $SyncHash.HealthRank.Foreground = [System.Windows.Media.Brushes]::Cyan
            $SyncHash.HealthBar.Foreground = [System.Windows.Media.Brushes]::Cyan
        }
        elseif ($percent -ge 60) {
            $SyncHash.HealthRank.Text = "SYSTEM RANK: A-TIER (WELL TUNED)"
            $SyncHash.HealthRank.Foreground = [System.Windows.Media.Brushes]::LimeGreen
            $SyncHash.HealthBar.Foreground = [System.Windows.Media.Brushes]::LimeGreen
        }
        elseif ($percent -ge 35) {
            $SyncHash.HealthRank.Text = "SYSTEM RANK: B-TIER (PARTIALLY TUNED)"
            $SyncHash.HealthRank.Foreground = [System.Windows.Media.Brushes]::Yellow
            $SyncHash.HealthBar.Foreground = [System.Windows.Media.Brushes]::Yellow
        }
        else {
            $SyncHash.HealthRank.Text = "SYSTEM RANK: C-TIER (UNOPTIMIZED)"
            $SyncHash.HealthRank.Foreground = [System.Windows.Media.Brushes]::Gray
            $SyncHash.HealthBar.Foreground = [System.Windows.Media.Brushes]::Gray
        }

        $tabs = $SyncHash.Window.FindName("MainTabs")
        if ($tabs) { $tabs.IsEnabled = $true; $tabs.Opacity = 1.0 }

    }, [System.Windows.Threading.DispatcherPriority]::ContextIdle)
    
    Log "System Audit Complete."
}

function New-RoninRestorePoint ($Description, $TimeoutSec = 90) {
    # Creates a System Restore point WITHOUT ever blocking the app indefinitely.
    # Checkpoint-Computer relies on Windows VSS / System Protection, which can hang for
    # a very long time (or is disabled) on some machines -- which previously froze the
    # entire apply on "Creating System Restore Point..." for 30+ minutes. We run it on a
    # throwaway runspace and wait at most $TimeoutSec; if it doesn't finish we log it and
    # move on. Tweaks remain individually reversible via Ronin's own per-tweak snapshots.
    try {
        $rpPs = [PowerShell]::Create()
        [void]$rpPs.AddScript({
            param($desc)
            try { Checkpoint-Computer -Description $desc -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop; "OK" }
            catch { "ERR:$($_.Exception.Message)" }
        }).AddArgument($Description)
        $h = $rpPs.BeginInvoke()
        if ($h.AsyncWaitHandle.WaitOne([TimeSpan]::FromSeconds($TimeoutSec))) {
            $res = "$($rpPs.EndInvoke($h))"
            $rpPs.Dispose()
            if ($res -like "ERR:*") {
                Log "Restore point skipped: $($res.Substring(4)) (System Protection may be off). Continuing - your tweaks are still individually reversible."
                return $false
            }
            Log "Restore point created."
            return $true
        } else {
            # Timed out: VSS / System Protection is stuck or busy. Do NOT block the apply.
            # (We intentionally don't Dispose the stuck runspace -- that would block too.)
            Log "Restore point is taking too long (Windows System Protection / VSS looks busy or disabled). Skipping it and continuing - every tweak is still individually reversible from within Ronin."
            return $false
        }
    } catch {
        Log "Restore point error: $($_.Exception.Message). Continuing."
        try { Write-DiagException "New-RoninRestorePoint" $_ } catch {}
        return $false
    }
}

function Start-RoninLoop ($SyncHash) {
    $script:LastSensorUpdate = [DateTime]::MinValue
    # Record this thread's ID so Write-Diag can tag engine-thread log lines
    try { $SyncHash.EngineThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId } catch {}
    Write-Diag "Engine worker thread started" "ENGINE"
    try {
        $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select -First 1
        if ($cpu) { $script:CpuName = $cpu.Name } else { $script:CpuName = "Unknown CPU" }
    } catch { $script:CpuName = "CPU Detection Failed" }
    if (!(Test-Path "$env:ProgramData\Ronin")) { New-Item -Path "$env:ProgramData\Ronin" -ItemType Directory -Force | Out-Null }
    
    Log "Ronin Core v7.3.1 Shogun Edition Online."

    # --- RE-HOME TWEAK SCRIPTBLOCKS INTO THIS (ENGINE) RUNSPACE ---
    # $RoninDB's Apply/Revert/Check scriptblocks were created on the UI thread and injected
    # here by reference. Executing UI-runspace scriptblocks on the engine thread is fragile:
    # after a handful of invocations the engine intermittently loses command resolution
    # ("X is not recognized" / "module could not be loaded"), so every tweak past that point
    # silently fails to apply. Recreating each scriptblock from its source text binds it to
    # THIS runspace, where the injected helper functions and default cmdlets always resolve
    # (the engine's own native code already works reliably, so re-homed blocks will too).
    try {
        $rehomed = 0
        foreach ($k in @($RoninDB.Keys)) {
            $e = $RoninDB[$k]
            foreach ($slot in 'Apply','Revert','Check') {
                if ($e.$slot -is [scriptblock]) { $e.$slot = [scriptblock]::Create($e.$slot.ToString()); $rehomed++ }
            }
        }
        Write-Diag "Re-homed $rehomed tweak scriptblocks into engine runspace" "ENGINE"
    } catch { Write-Diag "Scriptblock re-home failed: $($_.Exception.Message)" "ERROR" }

    while ($SyncHash.Running) {
        Try {
            if ($SyncHash.Window.Dispatcher.HasShutdownStarted) { break }
            try {
                $lastPowerEvent = Get-WinEvent -ProviderName "Microsoft-Windows-Kernel-Power" -MaxEvents 1 -ErrorAction SilentlyContinue
                if ($lastPowerEvent -and $lastPowerEvent.Id -eq 506) { Start-Sleep -Seconds 5; continue }
            } catch {}
            
            $SleepDuration = 1000 
            
            if ($SyncHash.JobQueue.Count -gt 0) {
                $SleepDuration = 50 
                $job = $SyncHash.JobQueue.Dequeue()
                $jobDesc = if ($job -is [string]) { $job } elseif ($job -is [System.Collections.IEnumerable]) { "BATCH[$($job.Count) items]" } else { "$($job.GetType().Name)" }
                Write-Diag "Job dequeued: $jobDesc (queue depth now $($SyncHash.JobQueue.Count))" "ENGINE"
                $jobStart = Get-Date
                
                if ($job -eq "INIT") { Update-Tweaks }
                elseif ($job -eq "AUDIT_SYSTEM") { Update-Tweaks }
                elseif ($job -eq "RESTART_EXPLORER") { Log "Restarting Explorer..."; Restart-Explorer }
                elseif ($job -eq "LOG_HANDHELD") { Log "Handheld Detected. Optimizations ready." }
                
                elseif ($job -eq "BOOT_UEFI") {
                    Log "SYSTEM: Rebooting to UEFI Firmware..."
                    Start-Sleep -Seconds 1
                    Start-Process "shutdown.exe" -ArgumentList "/r /fw /t 0" -NoNewWindow
                }
                elseif ($job -eq "BOOT_RECOVERY") {
                    Log "SYSTEM: Rebooting to Advanced Recovery..."
                    Start-Sleep -Seconds 1
                    Start-Process "shutdown.exe" -ArgumentList "/r /o /t 0" -NoNewWindow
                }
                elseif ($job -eq "REVERT_ALL") {
                    Log "REVERTING ALL CHANGES..."
                    $SyncHash.Window.Dispatcher.Invoke({ 
                        $tabs = $SyncHash.Window.FindName("MainTabs")
                        if ($tabs) { $tabs.IsEnabled = $false; $tabs.Opacity = 0.5 }
                    })
                    foreach ($key in $RoninDB.Keys) { if ($RoninDB[$key].Revert) { try { Invoke-Command -ScriptBlock $RoninDB[$key].Revert } catch {} } }
                    Update-Tweaks
                    Log "Revert Complete. Please Restart."
                }
                
                elseif ($job -is [System.Collections.IEnumerable] -and $job -isnot [string] -and $job -isnot [System.Collections.DictionaryEntry]) {
                    if ($job.Count -gt 0) {
                        $firstItem = $job[0]

                        if ($firstItem -is [PSCustomObject] -or $firstItem -is [System.Collections.DictionaryEntry] -or $firstItem -is [System.Collections.Hashtable]) {
                            $safeModeRef = [ref]$false
                            $total = $job.Count
                            
                            $SyncHash.Window.Dispatcher.Invoke({ 
                                if ($SyncHash.SafeMode) { $safeModeRef.Value = [bool]$SyncHash.SafeMode.IsChecked }
                                $SyncHash.ProgBar.Visibility = "Visible"
                                $SyncHash.ProgBar.Maximum = $total
                                $SyncHash.ProgBar.Value = 0
                                $tabs = $SyncHash.Window.FindName("MainTabs")
                                if ($tabs) { $tabs.IsEnabled = $false; $tabs.Opacity = 0.5 }
                            })
                            
                            if ($safeModeRef.Value) {
                                Log "Creating System Restore Point (up to 90s)..."
                                New-RoninRestorePoint "Ronin Pre-Flight" | Out-Null
                            }
                            
                            $count = 0
                            $rebootTriggered = $false
                            $applied = 0; $reverted = 0; $skipped = 0; $failed = 0; $failedKeys = @()

                            foreach ($taskItem in $job) {
                                $count++; $SyncHash.Window.Dispatcher.Invoke({ $SyncHash.ProgBar.Value = $count })
                                if ($count % 5 -eq 0) { Start-Sleep -Milliseconds 2 }

                                Try {
                                    $dbEntry = $RoninDB[$taskItem.Key]
                                    if ($dbEntry) {
                                        if ($dbEntry.Check) {
                                            $currentState = & { $ErrorActionPreference='SilentlyContinue'; & $dbEntry.Check }
                                            if ($taskItem.Action -eq "Apply") {
                                                $target = if ($taskItem.Value -ne $null) { $taskItem.Value } else { $true }
                                                if ($target -is [int] -and $target -lt 0) { 
                                                    Log "Skipping $($taskItem.Key) (Invalid or Unselected State)."
                                                    $skipped++; continue
                                                }
                                                if ("$currentState" -eq "$target") { $skipped++; Log "Skipping $($taskItem.Key) (Already Optimized)."; continue }
                                            } else {
                                                if ("$currentState" -eq "$false") { $skipped++; Log "Skipping Rollback (Already at Default)."; continue }
                                            }
                                        }
                                        if ($taskItem.Action -eq "Apply" -and $dbEntry.Apply) { 
                                            Log "APPLY: $($taskItem.Key)..."
                                            $applyStart = Get-Date
                                            try {
                                                if ($taskItem.Value -ne $null) { 
                                                    & { $ErrorActionPreference='Continue'; Invoke-Command -ScriptBlock $dbEntry.Apply -ArgumentList $taskItem.Value } 
                                                } else { 
                                                    & { $ErrorActionPreference='Continue'; Invoke-Command -ScriptBlock $dbEntry.Apply } 
                                                }
                                                $applyMs = [int]((Get-Date) - $applyStart).TotalMilliseconds
                                                # Verify by re-running Check
                                                $verified = $null
                                                if ($dbEntry.Check) { $verified = & { $ErrorActionPreference='SilentlyContinue'; & $dbEntry.Check } }
                                                if ($null -eq $verified) {
                                                    Log "  -> APPLY done ($($applyMs)ms, no Check defined)"; $applied++
                                                } elseif ("$verified" -eq "True" -or "$verified" -eq "1" -or ($null -ne $taskItem.Value -and "$verified" -eq "$($taskItem.Value)")) {
                                                    # Verified: checkbox tweaks return True/1; combo-box tweaks return their
                                                    # selected index, so accept a match against the value we just applied.
                                                    Log "  -> APPLY verified ($($applyMs)ms)"; $applied++
                                                } else {
                                                    Log "  -> APPLY ran but Check still reports not-applied. The tweak may be system-protected on this Windows build, blocked by group policy, or require a reboot to take effect."
                                                    $failed++; $failedKeys += $taskItem.Key
                                                }
                                            } catch {
                                                Log "  -> APPLY FAILED: $($_.Exception.Message)"
                                                Write-DiagException "Apply [$($taskItem.Key)]" $_
                                                $failed++; $failedKeys += $taskItem.Key
                                            }
                                            if ($dbEntry.Reboot) { $rebootTriggered = $true }
                                        } elseif ($taskItem.Action -eq "Revert" -and $dbEntry.Revert) { 
                                            Log "REVERT: $($taskItem.Key)..."
                                            $revertStart = Get-Date
                                            try {
                                                & { $ErrorActionPreference='Continue'; Invoke-Command -ScriptBlock $dbEntry.Revert }
                                                $revertMs = [int]((Get-Date) - $revertStart).TotalMilliseconds
                                                Log "  -> REVERT done ($($revertMs)ms)"; $reverted++
                                            } catch {
                                                Log "  -> REVERT FAILED: $($_.Exception.Message)"
                                                Write-DiagException "Revert [$($taskItem.Key)]" $_
                                                $failed++; $failedKeys += $taskItem.Key
                                            }
                                        }
                                    }
                                } Catch { 
                                    Log "ERROR on $($taskItem.Key): $($_.Exception.Message)"
                                    Write-DiagException "Task processing [$($taskItem.Key)]" $_
                                }
                            }
                            
                            # --- BATCH SUMMARY ---
                            $summaryLine = "Batch complete: $applied applied, $reverted reverted, $skipped already-optimal, $failed failed/incomplete."
                            Log $summaryLine
                            if ($failed -gt 0 -and $failedKeys.Count -gt 0) { Log ("  Needs attention: " + (($failedKeys | Select-Object -Unique) -join ", ")) }

                            # Settle the batch FIRST (re-audit + UI refresh) so the summary dialog appears on
                            # an idle UI and its OK button closes instantly instead of competing with the audit.
                            Start-Sleep -Milliseconds 750
                            Update-Tweaks
                            try { if ($Global:SnapshotCache.Count -gt 0) { $Global:SnapshotCache | ConvertTo-Json -Depth 2 | Set-Content $Global:SnapshotFile -Force } } catch {}
                            $SyncHash.Window.Dispatcher.Invoke({ $SyncHash.ProgBar.Visibility = "Collapsed"; if ($rebootTriggered -and $SyncHash.RebootBanner) { $SyncHash.RebootBanner.Visibility = "Visible" } })

                            try {
                                $SyncHash.Window.Dispatcher.Invoke({
                                    # Theme-matched WPF summary dialog (replaces the plain WinForms box).
                                    # Uses only .NET WPF types, so it is safe to build from this thread.
                                    $accent    = if ($failed -gt 0) { '#FF2E2E' } else { '#00E5FF' }
                                    $failColor = if ($failed -gt 0) { '#FF2E2E' } else { '#888888' }
                                    $hdr       = if ($failed -gt 0) { 'ATTENTION NEEDED' } else { 'BATCH COMPLETE' }
                                    $failBlock = ''
                                    if ($failed -gt 0 -and $failedKeys.Count -gt 0) {
                                        $items = (($failedKeys | Select-Object -Unique) | ForEach-Object { "&#8226;  $_" }) -join '&#10;'
                                        $failBlock = "<Border Background=`"#0C0C0C`" BorderBrush=`"#333`" BorderThickness=`"1`" CornerRadius=`"4`" Margin=`"0,16,0,0`" Padding=`"12`"><StackPanel><TextBlock Text=`"NEEDS ATTENTION`" Foreground=`"#FF2E2E`" FontFamily=`"Consolas`" FontSize=`"11`" FontWeight=`"Bold`" Margin=`"0,0,0,8`"/><ScrollViewer MaxHeight=`"130`" VerticalScrollBarVisibility=`"Auto`"><TextBlock Foreground=`"#E59A9A`" FontFamily=`"Consolas`" FontSize=`"12`" TextWrapping=`"Wrap`" Text=`"$items`"/></ScrollViewer><TextBlock Foreground=`"#777`" FontSize=`"11`" TextWrapping=`"Wrap`" Margin=`"0,10,0,0`" Text=`"May be blocked by group policy, need a reboot, or unsupported on this build. See Ronin.log for details.`"/></StackPanel></Border>"
                                    }
                                    $xamlDlg = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent" ResizeMode="NoResize"
        SizeToContent="WidthAndHeight" WindowStartupLocation="CenterOwner" ShowInTaskbar="False" FontFamily="Segoe UI">
  <Border Background="#161616" BorderBrush="$accent" BorderThickness="1.5" CornerRadius="6" Width="440">
    <StackPanel Margin="24,20,24,20">
      <StackPanel Orientation="Horizontal" Margin="0,0,0,2">
        <Rectangle Width="4" Height="19" Fill="$accent" Margin="0,0,11,0" VerticalAlignment="Center"/>
        <TextBlock Text="$hdr" Foreground="$accent" FontFamily="Consolas" FontSize="16" FontWeight="Bold" VerticalAlignment="Center"/>
      </StackPanel>
      <TextBlock Text="PROJECT RONIN  //  BATCH SUMMARY" Foreground="#666" FontFamily="Consolas" FontSize="10" Margin="15,0,0,18"/>
      <Grid>
        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
        <Grid.RowDefinitions><RowDefinition/><RowDefinition/><RowDefinition/><RowDefinition/></Grid.RowDefinitions>
        <TextBlock Grid.Row="0" Grid.Column="0" Text="Applied" Foreground="#BBB" FontSize="13" Margin="2,4"/>
        <TextBlock Grid.Row="1" Grid.Column="0" Text="Reverted" Foreground="#BBB" FontSize="13" Margin="2,4"/>
        <TextBlock Grid.Row="2" Grid.Column="0" Text="Already optimal" Foreground="#BBB" FontSize="13" Margin="2,4"/>
        <TextBlock Grid.Row="3" Grid.Column="0" Text="Failed / incomplete" Foreground="#BBB" FontSize="13" Margin="2,4"/>
        <TextBlock Grid.Row="0" Grid.Column="1" Text="$applied" Foreground="#39FF6A" FontFamily="Consolas" FontSize="15" FontWeight="Bold" Margin="2,4"/>
        <TextBlock Grid.Row="1" Grid.Column="1" Text="$reverted" Foreground="#00E5FF" FontFamily="Consolas" FontSize="15" FontWeight="Bold" Margin="2,4"/>
        <TextBlock Grid.Row="2" Grid.Column="1" Text="$skipped" Foreground="#888" FontFamily="Consolas" FontSize="15" FontWeight="Bold" Margin="2,4"/>
        <TextBlock Grid.Row="3" Grid.Column="1" Text="$failed" Foreground="$failColor" FontFamily="Consolas" FontSize="15" FontWeight="Bold" Margin="2,4"/>
      </Grid>
      $failBlock
      <Button x:Name="DlgOk" Content="OK" IsDefault="True" HorizontalAlignment="Right" Margin="0,20,0,0" Width="100" Height="34" Cursor="Hand" Foreground="White" FontFamily="Consolas" FontSize="13" FontWeight="Bold">
        <Button.Template>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="#222" BorderBrush="#444" BorderThickness="1" CornerRadius="4">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="BorderBrush" Value="#FF2E2E"/>
                <Setter TargetName="bd" Property="Background" Value="#2A1414"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Button.Template>
      </Button>
    </StackPanel>
  </Border>
</Window>
"@
                                    try {
                                        $dlgReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xamlDlg))
                                        $dlg = [System.Windows.Markup.XamlReader]::Load($dlgReader)
                                        $dlg.Owner = $SyncHash.Window
                                        $okBtn = $dlg.FindName("DlgOk")
                                        # .GetNewClosure() is REQUIRED: this click handler fires later, after
                                        # this delegate returns, so without capturing $dlg the handler can't
                                        # see it and Close() never runs. Also use Show() (NON-modal) not
                                        # ShowDialog() -- a modal dialog disables the main window while open,
                                        # so if close ever fails the whole app freezes. Non-modal can't.
                                        if ($okBtn) { $okBtn.Add_Click({ try { $dlg.Close() } catch {} }.GetNewClosure()) }
                                        $dlg.Show()
                                    } catch {
                                        # Fallback to a basic box if the styled dialog fails to build
                                        [System.Windows.MessageBox]::Show("Applied: $applied   Reverted: $reverted   Already optimal: $skipped   Failed: $failed", "Project Ronin - Batch Summary") | Out-Null
                                    }
                                })
                            } catch {}
                            [System.GC]::Collect()
                        }
                    }
                }
                
                elseif ($job -eq "MAINT_SFC") { Log "Running SFC..."; Start-Process "cmd.exe" -ArgumentList "/k sfc /scannow" }
                elseif ($job -eq "MAINT_DISM") { Log "Running DISM..."; Start-Process "cmd.exe" -ArgumentList "/k dism /online /cleanup-image /restorehealth" }
                elseif ($job -eq "MAINT_CLEAN") { Log "Cleaning Temp..."; Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue }
                elseif ($job -eq "MAINT_UPDATE") { Log "Cleaning Updates..."; Start-Process "cmd.exe" -ArgumentList "/k dism /online /cleanup-image /startcomponentcleanup" }
                elseif ($job -eq "MAINT_NET") { Log "Resetting Network..."; Start-Process "ipconfig" "/flushdns" -Wait; Start-Process "netsh" "winsock reset" -Wait }
                elseif ($job -eq "MAINT_WURESET") {
                    Log "Resetting Windows Update (services + download cache)..."
                    # '&' (not '&&') so the chain continues even if a service is already stopped.
                    # The old version stopped cryptSvc and never restarted it (broke cert checks
                    # until reboot) and never cleared the SoftwareDistribution cache.
                    Start-Process "cmd.exe" -ArgumentList "/k net stop wuauserv & net stop cryptSvc & net stop bits & rd /s /q %systemroot%\SoftwareDistribution.old 2>nul & ren %systemroot%\SoftwareDistribution SoftwareDistribution.old & net start cryptSvc & net start bits & net start wuauserv & echo. & echo Windows Update reset complete. Reboot recommended."
                }
                elseif ($job -eq "MAINT_STORERESET") { 
                    Log "Resetting Microsoft Store..."
                    Start-Process "powershell" -ArgumentList "-Command `"Get-AppxPackage -allusers Microsoft.WindowsStore | Foreach {Add-AppxPackage -DisableDevelopmentMode -Register `"`$(`$_.InstallLocation)\AppXManifest.xml`"`}`"" -NoNewWindow -Wait
                    Log "Store Reset Complete."
                }
                elseif ($job -eq "MAINT_DRIVERS") { 
                    Log "Analyzing GPU Hardware..."
                    $gpu = Get-CimInstance Win32_VideoController | Select -First 1
                    if ($gpu.Name -match "NVIDIA") {
                        Log "NVIDIA Detected. Checking GeForce Experience..."
                        $p = "C:\Program Files\NVIDIA Corporation\NVIDIA GeForce Experience\NVIDIA GeForce Experience.exe"
                        if (Test-Path $p) { Start-Process $p }
                        else { Start-Process "winget" -ArgumentList "upgrade", "Nvidia.GeForceExperience", "--silent", "--accept-source-agreements", "--accept-package-agreements" }
                    } elseif ($gpu.Name -match "AMD|Radeon") {
                        Log "AMD Detected. Checking Adrenalin..."
                        $p = "C:\Program Files\AMD\CNext\CNext\RadeonSoftware.exe"
                        if (Test-Path $p) { Start-Process $p }
                        else { Start-Process "winget" -ArgumentList "upgrade", "AMD.Adrenalin.Edition", "--silent", "--accept-source-agreements", "--accept-package-agreements" }
                    } else {
                        Log "Generic GPU. Running Winget Driver Check..."
                        Start-Process "cmd.exe" -ArgumentList "/k winget upgrade --include-unknown --accept-source-agreements"
                    }
                }
                elseif ($job -eq "MAINT_RESTORE") { Log "Creating Restore Point (up to 90s)..."; New-RoninRestorePoint "Ronin Manual Restore" | Out-Null }
                elseif ($job -eq "MAINT_RECLAIM") {
                    # Deep space reclaim: Windows.old + DISM /ResetBase. Confirm first - ResetBase
                    # permanently compresses superseded updates (they can't be uninstalled after).
                    $msg = "RECLAIM SPACE will:`n`n" +
                           "1. Remove Windows.old (previous Windows installation, if present)`n" +
                           "2. Permanently compress superseded update files (DISM ResetBase)`n`n" +
                           "This typically frees 15-30+ GB but is PERMANENT:`n" +
                           "- You can no longer roll back to the previous Windows version`n" +
                           "- Currently installed updates can no longer be uninstalled`n`n" +
                           "This can take 10-30 minutes. Continue?"
                    $result = "No"
                    try {
                        $result = $SyncHash.Window.Dispatcher.Invoke([System.Func[String]] {
                            return [System.Windows.Forms.MessageBox]::Show($msg, "Reclaim Space - Confirm", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning).ToString()
                        })
                    } catch {}
                    if ($result -eq "Yes") {
                        $before = (Get-PSDrive -Name ($env:SystemDrive.TrimEnd(':')) -ErrorAction SilentlyContinue).Free
                        Log "RECLAIM: Starting deep clean (this can take 10-30 minutes - watch this console)..."
                        # 1. Windows.old via cleanmgr's documented 'Previous Installations' handler
                        #    (avoids ACL battles with takeown/icacls, which are also AV heuristics)
                        if (Test-Path "$env:SystemDrive\Windows.old") {
                            Log "RECLAIM: Removing Windows.old..."
                            $vc = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
                            foreach ($cat in "Previous Installations","Temporary Setup Files") {
                                if (Test-Path "$vc\$cat") { Set-ItemProperty -Path "$vc\$cat" -Name "StateFlags0117" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue }
                            }
                            Start-Process "cleanmgr.exe" -ArgumentList "/sagerun:117" -Wait -NoNewWindow -ErrorAction SilentlyContinue
                        } else { Log "RECLAIM: No Windows.old found (skipping)." }
                        # 2. Deep component-store clean
                        Log "RECLAIM: Compressing superseded updates (DISM ResetBase)..."
                        Start-Process "dism" -ArgumentList "/Online /Cleanup-Image /StartComponentCleanup /ResetBase" -Wait -NoNewWindow
                        $after = (Get-PSDrive -Name ($env:SystemDrive.TrimEnd(':')) -ErrorAction SilentlyContinue).Free
                        if ($before -and $after) {
                            $freedGB = [Math]::Round(($after - $before) / 1GB, 2)
                            if ($freedGB -lt 0) { $freedGB = 0 }
                            Log "RECLAIM COMPLETE: Freed $freedGB GB of disk space."
                        } else { Log "RECLAIM COMPLETE." }
                    } else { Log "Reclaim Space cancelled." }
                }
                elseif ($job -eq "MAINT_BATTERY") { Log "Battery Report..."; Start-Process "powercfg" "/batteryreport /output `"$env:USERPROFILE\Desktop\battery_report.html`"" -Wait; Start-Process "$env:USERPROFILE\Desktop\battery_report.html" }
                elseif ($job -eq "MAINT_SLEEP") { Log "Sleep Study..."; Start-Process "powercfg" "/sleepstudy /output `"$env:USERPROFILE\Desktop\sleep_study.html`"" -Wait; Start-Process "$env:USERPROFILE\Desktop\sleep_study.html" }
                elseif ($job -eq "MAINT_OPEN_BACKUPS") { Log "Opening Snapshot Folder..."; Invoke-Item "$env:ProgramData\Ronin" -ErrorAction SilentlyContinue }
                elseif ($job -eq "MAINT_GPURESET") {
                    Log "INITIATING GPU STACK RESET..."
                    Get-Process -Name "clinfo", "amdocl*", "nvcontainer*", "RadeonSoftware", "NVIDIA Web Helper", "Steam", "EpicGamesLauncher" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
                    $paths = @("$env:LOCALAPPDATA\NVIDIA\GLCache", "$env:LOCALAPPDATA\NVIDIA\DXCache", "$env:LOCALAPPDATA\AMD\DxCache", "$env:LOCALAPPDATA\AMD\GLCache", "$env:LOCALAPPDATA\AMD\OclCache", "$env:LOCALAPPDATA\Intel\ShaderCache", "$env:LOCALAPPDATA\Intel\GPUCache", "$env:LOCALAPPDATA\D3DSCache", "$env:ProgramData\NVIDIA Corporation\NV_Cache")
                    foreach ($p in $paths) { if(Test-Path $p){ Remove-Item "$p\*" -Recurse -Force -ErrorAction SilentlyContinue } }
                    Start-Process "cleanmgr.exe" -ArgumentList "/autoclean /d C: /verylowdisk" -NoNewWindow -Wait
                    Start-Process "pnputil" -ArgumentList "/scan-devices" -NoNewWindow -Wait
                    Log "GPU Stack Reset Complete. Restart Recommended."
                }
                elseif ($job -eq "MAINT_SHADER") { 
                    Log "Clearing Shaders..."
                    Remove-Item "$env:LOCALAPPDATA\NVIDIA\GLCache\*" -Recurse -Force -ErrorAction SilentlyContinue
                    Remove-Item "$env:LOCALAPPDATA\AMD\DxCache\*" -Recurse -Force -ErrorAction SilentlyContinue
                    Remove-Item "$env:LOCALAPPDATA\Intel\ShaderCache\*" -Recurse -Force -ErrorAction SilentlyContinue
                }
                elseif ($job -eq "MAINT_VCREDIST") { if (Check-Internet) { Log "Installing Visual C++..."; Start-Process "winget" -ArgumentList "install", "Microsoft.VCRedist.2015+.x64", "--silent", "--accept-source-agreements", "--accept-package-agreements" -Wait } else { Log "No Internet." } }
                elseif ($job -eq "MAINT_DISKCLEAN") { Log "Auto Disk Cleanup..."; Start-Process "cleanmgr.exe" -ArgumentList "/sagerun:1" }
                elseif ($job -eq "MAINT_TRIM") { 
                    Log "Starting SSD Health Audit..."
                    $health = "Unknown"
                    try {
                        $pd = Get-Partition -DriveLetter C | Get-Disk | Get-PhysicalDisk
                        $stats = Get-StorageReliabilityCounter -PhysicalDisk $pd
                        if ($stats.Wear -ne $null) { 
                            $pct = 100 - $stats.Wear
                            $health = "$pct%"
                        }
                    } catch { $health = "Not Reported by Controller" }
                    Log "Primary Drive Health: $health"
                    if(Test-BitLocker){ Log "Skip TRIM: BitLocker Encrypted" } else { 
                        Log "Forcing TRIM cycle..."
                        Start-Process "powershell" -ArgumentList "Optimize-Volume -DriveLetter C -ReTrim -Verbose; Pause" 
                    } 
                }
                elseif ($job -eq "MAINT_ICON") { Log "Rebuilding Icons..."; Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue; Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force; Start-Process explorer }
                elseif ($job -eq "REPAIR_FULL") { Log "Full Repair..."; Start-Process "cmd.exe" -ArgumentList "/k sfc /scannow && dism /online /cleanup-image /restorehealth && chkdsk C: /scan" }
                elseif ($job -eq "DNS_Cloudflare") { if (Check-Internet) { Log "DNS: Cloudflare (1.1.1.1)"; Get-NetAdapter | Where Status -eq "Up" | Set-DnsClientServerAddress -ServerAddresses ("1.1.1.1","1.0.0.1"); Clear-DnsClientCache -ErrorAction SilentlyContinue; Log "DNS cache flushed." } }
                elseif ($job -eq "DNS_Google") { if (Check-Internet) { Log "DNS: Google (8.8.8.8)"; Get-NetAdapter | Where Status -eq "Up" | Set-DnsClientServerAddress -ServerAddresses ("8.8.8.8","8.8.4.4"); Clear-DnsClientCache -ErrorAction SilentlyContinue; Log "DNS cache flushed." } }
                elseif ($job -eq "DNS_Quad9") { if (Check-Internet) { Log "DNS: Quad9 (9.9.9.9, malware-blocking)"; Get-NetAdapter | Where Status -eq "Up" | Set-DnsClientServerAddress -ServerAddresses ("9.9.9.9","149.112.112.112"); Clear-DnsClientCache -ErrorAction SilentlyContinue; Log "DNS cache flushed." } }
                elseif ($job -eq "DNS_Auto") { Log "DNS: Automatic (DHCP)"; Get-NetAdapter | Where Status -eq "Up" | Set-DnsClientServerAddress -ResetServerAddresses; Clear-DnsClientCache -ErrorAction SilentlyContinue; Log "DNS cache flushed." }
                else { Write-Diag "Unhandled job type: $jobDesc" "WARN" }
                Write-Diag "Job complete: $jobDesc ($([int]((Get-Date) - $jobStart).TotalMilliseconds)ms)" "ENGINE"
            }
            if (((Get-Date) - $script:LastSensorUpdate).TotalSeconds -gt 1) { 
                Update-Sensors
                $script:LastSensorUpdate = Get-Date 
            }
            Start-Sleep -Milliseconds $SleepDuration
        } Catch { 
            Log "Fatal Core Error: $($_.Exception.Message)"
            Write-DiagException "Engine main loop" $_
            Start-Sleep -Seconds 1 
        }
    }
    Write-Diag "Engine worker thread exiting (Running=$($SyncHash.Running))" "ENGINE"
}
# --- PROJECT RONIN: CORE ENGINE v6.5.92 "VANGUARD" ---
# TARGET: Windows 11 24H2 & Legacy Support
# UPDATE: Added "UI Lockdown" Release Protocols to Update-Tweaks/Apps.
# FIX: Replaced WMI Sensor calls with .NET VisualBasic for sub-millisecond responsiveness.
# FIX: Hardened Winget CMD Wrapper with --disable-interactivity to prevent hidden EULA hangs.
# FIX: Added Thread-Yield logic to Tweak Application loop to prevent UI freezing.
# PRIME DIRECTIVE: NO-REFACTOR (Stability & Explicit Binding).

Add-Type -AssemblyName PresentationFramework, System.Windows.Forms, System.Drawing, WindowsBase, Microsoft.VisualBasic

$Global:SnapshotFile = "$env:ProgramData\Ronin\Ronin_Snapshots.json"
$Global:SnapshotCache = @{}

function Log ($Msg) { 
    if ($SyncHash.Window.Dispatcher.HasShutdownStarted) { return }
    $Time = Get-Date -Format "HH:mm:ss"
    $FinalMsg = "[$Time] $Msg"
    $SyncHash.Window.Dispatcher.Invoke({ 
        try {
            if ($SyncHash.Console) {
                $SyncHash.Console.Text += "`n$FinalMsg"
                $SyncHash.Scroll.ScrollToEnd()
            }
        } catch {}
    }) 
}

if (Test-Path $Global:SnapshotFile) {
    try { $Global:SnapshotCache = Get-Content $Global:SnapshotFile | ConvertFrom-Json -AsHashtable } catch {}
}

function Backup-Value ($Path, $Name) {
    try {
        $ID = "$Path\$Name".ToLower()
        if ($Global:SnapshotCache.ContainsKey($ID)) { return }
        if (Test-Path $Path) {
            $current = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
            if ($current -and $current.$Name -ne $null) {
                $Global:SnapshotCache[$ID] = $current.$Name
                $Global:SnapshotCache | ConvertTo-Json -Depth 2 | Set-Content $Global:SnapshotFile -Force
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
    try {
        if (Test-Path $Path) {
            $v = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
            if ("$($v.$Name)" -eq "$TargetVal") { return $true }
        }
    } catch {}
    return $false
}

function Test-Reg-Robust ($Path, $Name, $TargetVal, $RetryCount=3) {
    for ($i = 0; $i -lt $RetryCount; $i++) {
        if (Test-Reg-Read $Path $Name $TargetVal) { return $true }
        Start-Sleep -Milliseconds 100
    }
    return $false
}

function Disable-Task ($Path, $Name) { try { Disable-ScheduledTask -TaskPath $Path -TaskName $Name -ErrorAction SilentlyContinue } catch {} }
function Enable-Task ($Path, $Name) { try { Enable-ScheduledTask -TaskPath $Path -TaskName $Name -ErrorAction SilentlyContinue } catch {} }
function Restart-Explorer { Log "Executing Explorer Shell Refresh..."; Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue }

function Check-Internet { 
    if (Test-Connection 8.8.8.8 -Count 1 -Quiet) { return $true }
    # 24H2 OPTIMIZATION: Reduced timeout to prevent UI thread hang if offline
    try { $r = Invoke-WebRequest "http://www.msftconnecttest.com/connecttest.txt" -UseBasicParsing -TimeoutSec 1; return ($r.StatusCode -eq 200) } catch { return $false }
}

function Test-BitLocker { try { $bl = Get-BitLockerVolume -MountPoint "C:" -ErrorAction SilentlyContinue; if ($bl -and $bl.ProtectionStatus -eq "On") { return $true } } catch {}; return $false }

function Get-GpuRegistryPath ($VendorString) {
    try {
        $ClassPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
        if (!(Test-Path $ClassPath)) { return $null }
        $Keys = Get-ChildItem $ClassPath -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' }
        foreach ($k in $Keys) {
            $Prov = (Get-ItemProperty $k.PSPath -Name "ProviderName" -ErrorAction SilentlyContinue).ProviderName
            $Desc = (Get-ItemProperty $k.PSPath -Name "DriverDesc" -ErrorAction SilentlyContinue).DriverDesc
            if (($Prov -and $Prov -match $VendorString) -or ($Desc -and $Desc -match $VendorString)) { return $k.PSPath }
        }
    } catch {}
    return $null
}
function Set-AMD-Feature ($FeatureName, $Val) { $path = Get-GpuRegistryPath "AMD"; if ($path) { Set-Reg $path $FeatureName $Val; Set-Reg "$path\UMD" $FeatureName $Val; Set-Reg $path "KMD_$FeatureName" $Val } }

function Get-CpuBoostMode {
    try {
        $scheme = (powercfg /getactivescheme).Split()[3]
        $out = powercfg /q $scheme sub_processor be337238-0d82-4146-a960-4f3749d470c7 | Out-String
        if ($out -match "Current AC Power Setting Index:\s+0x([0-9a-fA-F]+)") {
            return [Convert]::ToInt32($matches[1], 16)
        }
    } catch {}
    return -1
}

function Get-EPP-Value {
    try {
        $output = powercfg /getactivescheme
        if ($output -match "([a-fA-F0-9-]{36})") { $guid = $matches[1] } else { return 50 }
        $out = powercfg /qh $guid sub_processor 36687f9e-e3a5-4dbf-b1dc-15eb381c6863 | Out-String
        if ($out -match "Current AC Power Setting Index:\s+0x([0-9a-fA-F]+)") {
            return [Convert]::ToInt32($matches[1], 16)
        }
    } catch {}
    return 50 
}

function Ensure-PCIe-Visibility {
    $Path = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\501a4d13-42af-4429-9fd1-a8218c268e20\ee12f906-d277-404b-b6da-e5fa1a576df5"
    try {
        if (Test-Path $Path) {
            $val = Get-ItemProperty -Path $Path -Name "Attributes" -ErrorAction SilentlyContinue
            if (!$val -or $val.Attributes -eq 1) {
                Set-ItemProperty -Path $Path -Name "Attributes" -Value 2 -Type DWord -Force
            }
        }
    } catch {}
}

function Set-PCIe-Mode ($EnablePerformance) {
    Ensure-PCIe-Visibility
    try {
        $schemeOutput = powercfg /getactivescheme | Out-String
        if ($schemeOutput -match "GUID:\s+([a-fA-F0-9-]+)") {
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
        if ($schemeOutput -match "GUID:\s+([a-fA-F0-9-]+)") {
            $activeScheme = $matches[1]
            $sub = "501a4d13-42af-4429-9fd1-a8218c268e20"
            $setting = "ee12f906-d277-404b-b6da-e5fa1a576df5"
            $out = powercfg /q $activeScheme $sub $setting | Out-String
            if ($out -match "Current AC Power Setting Index:\s+0x([0-9a-fA-F]+)") {
                return [Convert]::ToInt32($matches[1], 16)
            }
        }
    } catch {}
    return -1
}

function Update-Sensors {
    try {
        if ($SyncHash.Window.Dispatcher.HasShutdownStarted) { return }
        $ram = "..."
        
        # 24H2 OPTIMIZATION: Replaced WMI call with .NET VisualBasic.
        # WMI can be slow/laggy on modern Windows. This method is instant.
        try {
            $compInfo = New-Object Microsoft.VisualBasic.Devices.ComputerInfo
            $total = $compInfo.TotalPhysicalMemory
            $avail = $compInfo.AvailablePhysicalMemory
            $usedVal = [Math]::Round(($total - $avail) / 1073741824, 1) # Bytes to GB
            $ram = "$usedVal GB"
        } catch {
            # Fallback to WMI if .NET assembly fails
            try {
                $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
                if ($os) {
                    $used = [Math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1024 / 1024, 1)
                    $ram = "$used GB"
                }
            } catch {}
        }
        
        $SyncHash.Window.Dispatcher.Invoke({ 
            try { 
                if ($SyncHash.RamStatus) { $SyncHash.RamStatus.Text = "RAM USAGE: $ram" }
                if ($SyncHash.CpuStatus -and $script:CpuName) { $SyncHash.CpuStatus.Text = $script:CpuName }
            } catch {} 
        })
    } catch {}
}

function Update-Apps {
    if ($SyncHash.Window.Dispatcher.HasShutdownStarted) { return }
    Log "Scanning Installed Applications..."
    $results = @{}
    $keys = $AppCheckMap.Keys | ForEach-Object { $_ }
    foreach ($appKey in $keys) {
        try {
            $isInstalled = Invoke-Command -ScriptBlock $AppCheckMap[$appKey]
            $results[$appKey] = $isInstalled
        } catch { $results[$appKey] = $false }
    }
    if ($SyncHash.Window.Dispatcher.HasShutdownStarted) { return }
    
    $SyncHash.Window.Dispatcher.Invoke([Action]{
        foreach ($appKey in $results.Keys) {
            try {
                $c = $SyncHash.Window.FindName($appKey)
                if ($c) {
                    if ($results[$appKey]) { $c.IsChecked = $true; $c.Foreground = [System.Windows.Media.Brushes]::LimeGreen; $c.ToolTip = "Status: INSTALLED" }
                    else { $c.IsChecked = $false; $c.Foreground = [System.Windows.Media.Brushes]::Gray; $c.ToolTip = "Status: Not Installed" }
                }
            } catch {}
        }

        # --- UI LOCKDOWN RELEASE PROTOCOL ---
        $tabs = $SyncHash.Window.FindName("MainTabs")
        if ($tabs) { 
            $tabs.IsEnabled = $true
            $tabs.Opacity = 1.0 
        }

    }, [System.Windows.Threading.DispatcherPriority]::ContextIdle)
    
    Log "App Scan Complete."
}

function Update-Tweaks {
    if ($SyncHash.Window.Dispatcher.HasShutdownStarted) { return }
    Log "Auditing System State..."
    $Status = @{} ; $totalActive = 0
    foreach ($k in $RoninDB.Keys) {
        if ($RoninDB[$k].Check) { 
            try { $Status[$k] = Invoke-Command -ScriptBlock $RoninDB[$k].Check } catch { $Status[$k] = $false }
        }
    }
    if ($SyncHash.Window.Dispatcher.HasShutdownStarted) { return }
    
    $SyncHash.Window.Dispatcher.Invoke([Action]{
        foreach ($k in $Status.Keys) {
            try {
                $c = $SyncHash.Window.FindName($k)
                if ($c -is [System.Windows.Controls.CheckBox]) { 
                    $c.IsChecked = $Status[$k]
                    if ($Status[$k]) { $c.Foreground = [System.Windows.Media.Brushes]::LimeGreen; $totalActive++ }
                    else { $c.Foreground = [System.Windows.Media.Brushes]::Gray }
                }
                elseif ($c -is [System.Windows.Controls.ComboBox]) { $c.SelectedIndex = $Status[$k] }
            } catch {}
        }
        foreach ($sysKey in $AutoMap.Keys) {
            try {
                $autoControl = $SyncHash.Window.FindName($AutoMap[$sysKey])
                if ($autoControl) {
                    $autoControl.IsChecked = $Status[$sysKey]
                    $autoControl.Foreground = if($Status[$sysKey]){ [System.Windows.Media.Brushes]::LimeGreen } else { [System.Windows.Media.Brushes]::Gray }
                }
            } catch {}
        }
        if ($SyncHash.HealthRank) {
            $percent = [Math]::Min(100, ($totalActive / 35) * 100)
            $SyncHash.HealthBar.Value = $percent
            if ($totalActive -gt 18) { $SyncHash.HealthRank.Text = "SYSTEM RANK: S-TIER (OPTIMIZED)"; $SyncHash.HealthRank.Foreground = [System.Windows.Media.Brushes]::Cyan; $SyncHash.HealthBar.Foreground = [System.Windows.Media.Brushes]::Cyan }
            elseif ($totalActive -gt 10) { $SyncHash.HealthRank.Text = "SYSTEM RANK: B-TIER (ACCEPTABLE)"; $SyncHash.HealthRank.Foreground = [System.Windows.Media.Brushes]::Yellow; $SyncHash.HealthBar.Foreground = [System.Windows.Media.Brushes]::Yellow }
            else { $SyncHash.HealthRank.Text = "SYSTEM RANK: C-TIER (UNOPTIMIZED)"; $SyncHash.HealthRank.Foreground = [System.Windows.Media.Brushes]::Gray; $SyncHash.HealthBar.Foreground = [System.Windows.Media.Brushes]::Gray }
        }

        # --- UI LOCKDOWN RELEASE PROTOCOL ---
        $tabs = $SyncHash.Window.FindName("MainTabs")
        if ($tabs) { 
            $tabs.IsEnabled = $true
            $tabs.Opacity = 1.0 
        }

    }, [System.Windows.Threading.DispatcherPriority]::ContextIdle)
    
    Log "System Audit Complete."
}

function Start-RoninLoop ($SyncHash) {
    $script:LastSensorUpdate = [DateTime]::MinValue
    try {
        $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select -First 1
        if ($cpu) { $script:CpuName = $cpu.Name } else { $script:CpuName = "Unknown CPU" }
    } catch { $script:CpuName = "CPU Detection Failed" }
    if (!(Test-Path "$env:ProgramData\Ronin")) { New-Item -Path "$env:ProgramData\Ronin" -ItemType Directory -Force | Out-Null }
    Log "Ronin Core v6.5 Online."
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
                
                if ($job -eq "INIT") { Update-Tweaks }
                elseif ($job -eq "AUDIT_SYSTEM") { Update-Tweaks }
                elseif ($job -eq "AUDIT_APPS") { Update-Apps }
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
                    foreach ($key in $RoninDB.Keys) { if ($RoninDB[$key].Revert) { try { Invoke-Command -ScriptBlock $RoninDB[$key].Revert } catch {} } }
                    Update-Tweaks
                    Log "Revert Complete. Please Restart."
                }
                
                # --- UNIFIED JOB PROCESSOR ---
                elseif ($job -is [System.Collections.IEnumerable] -and $job -isnot [string] -and $job -isnot [System.Collections.DictionaryEntry]) {
                    
                    if ($job.Count -gt 0) {
                        $firstItem = $job[0]

                        # --- CASE A: APP INSTALLER (List of Strings) ---
                        if ($firstItem -is [string]) {
                            if (!$WingetMap) { Log "CRITICAL ERROR: Winget Database not loaded!"; continue }
                            if (Check-Internet) { 
                                foreach ($a in $job) { 
                                    if ($WingetMap[$a]) {
                                        $id = $WingetMap[$a]
                                        $msg = "Installing"
                                        $cmd = "install"
                                        if ($AppCheckMap[$a]) {
                                            try {
                                                $isInstalled = Invoke-Command -ScriptBlock $AppCheckMap[$a]
                                                if ($isInstalled) { $cmd = "upgrade"; $msg = "Updating" }
                                            } catch {}
                                        }
                                        Log "$msg $a (ID: $id)..."
                                        
                                        # 24H2 FIX: Added --disable-interactivity to prevent hidden EULA hangs
                                        $winArg = "$cmd --id $id --silent --disable-interactivity --accept-source-agreements --accept-package-agreements --force --include-unknown"
                                        Start-Process "cmd.exe" -ArgumentList "/c winget $winArg" -NoNewWindow -Wait
                                    } else {
                                        Log "ERROR: ID not found for $a"
                                    }
                                } 
                                Log "Install Batch Complete."; Update-Apps
                            } else { Log "INSTALL ERROR: Internet Connection Required." }
                        }

                        # --- CASE B: TWEAK PROCESSOR (List of Objects) ---
                        elseif ($firstItem -is [PSCustomObject] -or $firstItem -is [System.Collections.DictionaryEntry] -or $firstItem -is [System.Collections.Hashtable]) {
                            $SafeModeEnabled = $false
                            $SyncHash.Window.Dispatcher.Invoke({ if ($SyncHash.SafeMode) { $SafeModeEnabled = $SyncHash.SafeMode.IsChecked } })
                            if ($SafeModeEnabled) { 
                                Log "Creating System Restore Point..."
                                Checkpoint-Computer -Description "Ronin Pre-Flight" -RestorePointType "MODIFY_SETTINGS" -ErrorAction SilentlyContinue
                            }
                            $count = 0; $total = $job.Count
                            $rebootTriggered = $false
                            $SyncHash.Window.Dispatcher.Invoke({ $SyncHash.ProgBar.Visibility = "Visible"; $SyncHash.ProgBar.Maximum = $total; $SyncHash.ProgBar.Value = 0 })
                            foreach ($taskItem in $job) {
                                $count++; $SyncHash.Window.Dispatcher.Invoke({ $SyncHash.ProgBar.Value = $count })
                                
                                # 24H2 STABILITY: Thread yield to prevent UI freeze during heavy registry I/O
                                if ($count % 5 -eq 0) { Start-Sleep -Milliseconds 2 }

                                Try {
                                    $dbEntry = $RoninDB[$taskItem.Key]
                                    if ($dbEntry) {
                                        if ($dbEntry.Check) {
                                            $currentState = Invoke-Command -ScriptBlock $dbEntry.Check
                                            if ($taskItem.Action -eq "Apply") {
                                                $target = if ($taskItem.Value -ne $null) { $taskItem.Value } else { $true }
                                                if ("$currentState" -eq "$target") { Log "Skipping $target (Already Optimized)."; continue } 
                                            } else {
                                                if ("$currentState" -eq "$false") { Log "Skipping Rollback (Already at Default)."; continue }
                                            }
                                        }
                                        if ($taskItem.Action -eq "Apply" -and $dbEntry.Apply) { 
                                            Log "APPLY: $($taskItem.Key)..."
                                            if ($taskItem.Value -ne $null) { Invoke-Command -ScriptBlock $dbEntry.Apply -ArgumentList $taskItem.Value }
                                            else { Invoke-Command -ScriptBlock $dbEntry.Apply }
                                            if ($dbEntry.Reboot) { $rebootTriggered = $true }
                                        } elseif ($taskItem.Action -eq "Revert" -and $dbEntry.Revert) { 
                                            Log "REVERT: $($taskItem.Key)..."; Invoke-Command -ScriptBlock $dbEntry.Revert
                                        }
                                    }
                                } Catch { Log "ERROR on $($taskItem.Key): $($_.Exception.Message)" }
                            }
                            Update-Tweaks
                            $SyncHash.Window.Dispatcher.Invoke({ 
                                $SyncHash.ProgBar.Visibility = "Collapsed"
                                if ($rebootTriggered -and $SyncHash.RebootBanner) { $SyncHash.RebootBanner.Visibility = "Visible" }
                            })
                            [System.GC]::Collect()
                        }
                    }
                }
                
                # --- MAINTENANCE ---
                elseif ($job -eq "MAINT_SFC") { Log "Running SFC..."; Start-Process "cmd.exe" -ArgumentList "/k sfc /scannow" }
                elseif ($job -eq "MAINT_DISM") { Log "Running DISM..."; Start-Process "cmd.exe" -ArgumentList "/k dism /online /cleanup-image /restorehealth" }
                elseif ($job -eq "MAINT_CLEAN") { Log "Cleaning Temp..."; Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue }
                elseif ($job -eq "MAINT_UPDATE") { Log "Cleaning Updates..."; Start-Process "cmd.exe" -ArgumentList "/k dism /online /cleanup-image /startcomponentcleanup" }
                elseif ($job -eq "MAINT_NET") { Log "Resetting Network..."; Start-Process "ipconfig" "/flushdns" -Wait; Start-Process "netsh" "winsock reset" -Wait }
                elseif ($job -eq "MAINT_WURESET") { Log "Resetting WU..."; Start-Process "cmd.exe" -ArgumentList "/k net stop wuauserv && net stop cryptSvc && net start wuauserv" }
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
                        else { Start-Process "winget" -ArgumentList "upgrade", "Nvidia.GeForceExperience", "--silent", "--disable-interactivity", "--accept-source-agreements", "--accept-package-agreements" }
                    } elseif ($gpu.Name -match "AMD|Radeon") {
                        Log "AMD Detected. Checking Adrenalin..."
                        $p = "C:\Program Files\AMD\CNext\CNext\RadeonSoftware.exe"
                        if (Test-Path $p) { Start-Process $p }
                        else { Start-Process "winget" -ArgumentList "upgrade", "AMD.Adrenalin.Edition", "--silent", "--disable-interactivity", "--accept-source-agreements", "--accept-package-agreements" }
                    } else {
                        Log "Generic GPU. Running Winget Driver Check..."
                        Start-Process "cmd.exe" -ArgumentList "/k winget upgrade --include-unknown --accept-source-agreements --disable-interactivity"
                    }
                }
                elseif ($job -eq "MAINT_RESTORE") { Log "Creating Restore Point..."; Checkpoint-Computer -Description "Ronin Manual Restore" -RestorePointType "MODIFY_SETTINGS" }
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
                elseif ($job -eq "MAINT_VCREDIST") { if (Check-Internet) { Log "Installing Visual C++..."; Start-Process "winget" -ArgumentList "install", "Microsoft.VCRedist.2015+.x64", "--silent", "--disable-interactivity", "--accept-source-agreements", "--accept-package-agreements" -Wait } else { Log "No Internet." } }
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
                elseif ($job -eq "DNS_Cloudflare") { if (Check-Internet) { Log "DNS: 1.1.1.1"; Get-NetAdapter | Where Status -eq "Up" | Set-DnsClientServerAddress -ServerAddresses ("1.1.1.1","1.0.0.1") } }
                elseif ($job -eq "DNS_Google") { if (Check-Internet) { Log "DNS: 8.8.8.8"; Get-NetAdapter | Where Status -eq "Up" | Set-DnsClientServerAddress -ServerAddresses ("8.8.8.8","8.8.4.4") } }
                elseif ($job -eq "DNS_Auto") { Log "DNS: Auto"; Get-NetAdapter | Where Status -eq "Up" | Set-DnsClientServerAddress -ResetServerAddresses }
            }
            if (((Get-Date) - $script:LastSensorUpdate).TotalSeconds -gt 1) { 
                Update-Sensors
                $script:LastSensorUpdate = Get-Date 
            }
            Start-Sleep -Milliseconds $SleepDuration
        } Catch { Log "Fatal Core Error: $($_.Exception.Message)"; Start-Sleep -Seconds 1 }
    }
}
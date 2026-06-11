<#
.SYNOPSIS
    Project Ronin - Windows 11 Optimization Suite (Shogun Edition v7.3.1)

.DESCRIPTION
    A graphical Windows 11 24H2/25H2 tweak utility inspired by Chris Titus Tech's WinUtil.
    Provides toggleable system, gaming, privacy, handheld, and maintenance optimizations.
    All changes are reversible. Registry snapshots are saved to C:\ProgramData\Ronin\
    before any modification, allowing rollback via the SnapshotTool.

.NOTES
    Version  : 7.3.1
    Author   : KeiRetroGaming
    Project  : https://github.com/keiretrogaming/Project-Ronin
    License  : MIT (Open Source)
    Requires : Windows 11 (24H2 or 25H2), PowerShell 5.1+, Administrator rights

.NOTICE
    This script makes Windows registry modifications and configures system services.
    These are the same operations performed by Microsoft's own group policy templates,
    Chris Titus Tech's WinUtil, and similar legitimate optimization tools.
    
    If your antivirus flags this script, it is a heuristic false positive triggered
    by behavioral patterns common to system management utilities. The full source
    is open and auditable at the project URL above.
#>

# --- PROJECT RONIN: CONTROLLER v7.3.1 ---

$Version = "7.3.1"

Try {
    $ErrorActionPreference = "Stop"

    # --- 0. PROFESSIONAL BOOTSTRAP & PROCESS ELEVATION ---
    if ([System.Environment]::OSVersion.Version.Major -ge 6) {
        try { 
            [System.Windows.Forms.Application]::SetHighDpiMode([System.Windows.Forms.HighDpiMode]::PerMonitorV2)
        } catch {}
    }

    # Ensure log directory exists (running as admin so we can use ProgramData)
    $LogDir = "$env:ProgramData\Ronin"
    if (!(Test-Path $LogDir)) { New-Item -Path $LogDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null }
    $LogPath = Join-Path $LogDir "Ronin_CrashLog.txt"
    Start-Transcript -Path $LogPath -Append -ErrorAction SilentlyContinue

    # --- 1. ADMIN CHECK & ROBUST PATHING ---
    if ($PSCommandPath) { $CurrentPath = $PSCommandPath; $ScriptPath = Split-Path -Parent $CurrentPath }
    else { $CurrentPath = $MyInvocation.MyCommand.Definition; $ScriptPath = Split-Path -Parent $CurrentPath }

    if ([string]::IsNullOrWhiteSpace($ScriptPath)) { $ScriptPath = $PWD.Path }

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        # Display a clear, user-friendly error rather than auto-elevating.
        # Auto-elevation patterns are heuristic AV triggers; the launcher (.bat) handles elevation properly.
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        [System.Windows.Forms.MessageBox]::Show(
            "Project Ronin requires Administrator privileges to modify system settings.`n`n" +
            "Please close this window and run Launch_Ronin.bat instead, or right-click Ronin.ps1 and choose 'Run as Administrator'.",
            "Project Ronin - Administrator Required",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        exit
    }

    Add-Type -AssemblyName PresentationFramework, System.Windows.Forms, System.Drawing, WindowsBase, System.Xml

    # --- 2. FILE INTEGRITY CHECKS ---
    $BaseDir  = Split-Path -Parent $ScriptPath
    $XamlPath = Join-Path $BaseDir "UI\Ronin.xaml"
    $CorePath = Join-Path $ScriptPath "RoninCore.ps1"
    $DBPath   = Join-Path $ScriptPath "RoninDB.ps1"

    $Missing = @()
    if (-not (Test-Path $XamlPath)) { $Missing += "Ronin.xaml" }
    if (-not (Test-Path $CorePath)) { $Missing += "RoninCore.ps1" }
    if (-not (Test-Path $DBPath))   { $Missing += "RoninDB.ps1" }

    if ($Missing.Count -gt 0) {
        [System.Windows.Forms.MessageBox]::Show("FATAL ERROR: Missing critical components:`n`n$($Missing -join "`n")`n`nPlease reinstall Project Ronin.", "Integrity Failure", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        exit
    }

    # --- 3. HARDENED XAML LOADING (XXE PROTECTION) ---
    # Use .NET ReadAllText for bulletproof UTF-8 handling (auto-detects BOM, no PS quirks)
    try {
        $xamlContent = [System.IO.File]::ReadAllText($XamlPath, [System.Text.Encoding]::UTF8)
    } catch {
        $xamlContent = Get-Content $XamlPath -Raw -Encoding UTF8
    }
    
    # Aggressively strip any BOM, replacement chars, or whitespace that could break XmlReader
    $xamlContent = $xamlContent.TrimStart([char]0xFEFF, [char]0xFFFD, [char]0x200B).Trim()
    
    $xamlContent = $xamlContent.Replace('x:Name', 'Name')
    
    $xmlSettings = New-Object System.Xml.XmlReaderSettings
    $xmlSettings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
    
    $sr = [System.IO.StringReader]::new($xamlContent)
    $reader = [System.Xml.XmlReader]::Create($sr, $xmlSettings)
    
    try {
        $window = [System.Windows.Markup.XamlReader]::Load($reader)
    } catch {
        [System.Windows.Forms.MessageBox]::Show("XAML PARSING FAILED:`n$($_.Exception.Message)", "Critical UI Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        exit
    }
    
    $window.Title = "PROJECT RONIN // Definitive Edition (v$Version)"
    $window.Height = 730
    $window.Width = 1100

    # --- 4. THREAD SYNC & UNHANDLED EXCEPTION TRAP ---
    $SyncHash = [Hashtable]::Synchronized(@{})
    $SyncHash.Window = $window
    # Capture the UI (main) thread id so the diagnostic logger can tag lines by thread role
    try { $SyncHash.MainThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId } catch {}
    # Begin the diagnostic session: writes environment header + enables verbose tracing.
    # NOTE: These functions live in RoninCore.ps1 which is dot-sourced LATER, so guard the calls.
    if (Get-Command Start-DiagSession -ErrorAction SilentlyContinue) { try { Start-DiagSession } catch {} }
    if (Get-Command Write-Diag -ErrorAction SilentlyContinue) { Write-Diag "SyncHash created; window object assigned" "UI" }
    
    $window.Dispatcher.Add_UnhandledException({
        param($sender, $e)
        $e.Handled = $true
        $Err = $e.Exception.Message
        [System.IO.File]::AppendAllText("$env:ProgramData\Ronin\Ronin_UI_Errors.txt", "[$([DateTime]::Now)] UI ERROR: $Err`r`n")
        # Also capture full detail in the diagnostic log
        try { if (Get-Command Write-Diag -ErrorAction SilentlyContinue) { Write-Diag "UNHANDLED UI EXCEPTION: $Err" "ERROR" } } catch {}
        try {
            if ($e.Exception.StackTrace) {
                foreach ($sl in ($e.Exception.StackTrace -split "`n")) { if ($sl.Trim()) { Write-Diag "  Stack: $($sl.Trim())" "ERROR" } }
            }
        } catch {}
    })
    
    $Global:RoninDojo = $window.FindName("InfoDojo")
    $script:DojoLock = $false 

    # MAP UI ELEMENTS
    $SyncHash.Console = $window.FindName("ConsoleOutput")
    $SyncHash.Scroll = $window.FindName("ConsoleScroll")
    $SyncHash.InfoDojo = $window.FindName("InfoDojo")
    $SyncHash.RamStatus = $window.FindName("Txt_RamStatus")
    $SyncHash.CpuStatus = $window.FindName("Txt_CpuStatus")
    $SyncHash.HealthRank = $window.FindName("Txt_HealthRank")
    $SyncHash.HealthBar = $window.FindName("HealthBar")
    $SyncHash.ProgBar = $window.FindName("ProgBar")
    $SyncHash.SafeMode = $window.FindName("Global_SafeMode")
    $SyncHash.RebootBanner = $window.FindName("Banner_Reboot")
    
    $SyncHash.JobQueue = [System.Collections.Queue]::Synchronized([System.Collections.Queue]::new())
    $SyncHash.Running = $true
    $SyncHash.StatusCache = [Hashtable]::Synchronized(@{})
    $SyncHash.ActiveTab = "Tab_Auto"

    if ($SyncHash.Console) {
        $SyncHash.Console.Cursor = "Hand"
        $SyncHash.Console.ToolTip = "Click to open the Ronin logs folder (Ronin.log, diagnostics, state report)"
        $SyncHash.Console.Add_MouseLeftButtonUp({
            $logDir = "$env:ProgramData\Ronin"
            if (Test-Path $logDir) { Invoke-Item $logDir }
        })
    }

    # --- 5. INITIAL SESSION STATE & RUNSPACE POOL (THE "BLINDNESS" FIX) ---
    
    # Load core components into Main Thread for development/modular mode
    # (The Compiler strictly replaces these lines with raw file text for the monolithic build)
    if ((Test-Path $CorePath) -and (Test-Path $DBPath)) {
        . $CorePath
        . $DBPath

    }

    # Now that RoninCore is loaded, the diagnostic functions exist. Start the session
    # here (the earlier guarded call was a no-op because these weren't defined yet).
    if (Get-Command Start-DiagSession -ErrorAction SilentlyContinue) { try { Start-DiagSession } catch {} }
    if (Get-Command Write-Diag -ErrorAction SilentlyContinue) { Write-Diag "Core + DB dot-sourced; diagnostics online" "UI" }

    $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    $iss.LanguageMode = [System.Management.Automation.PSLanguageMode]::FullLanguage

    # Inject Database and Memory Maps safely
    if (Get-Variable "RoninDB" -ErrorAction SilentlyContinue) { $iss.Variables.Add((New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry("RoninDB", $RoninDB, ""))) }
    if (Get-Variable "AutoMap" -ErrorAction SilentlyContinue) { $iss.Variables.Add((New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry("AutoMap", $AutoMap, ""))) }

    # CRITICAL: inject the global state RoninCore's functions depend on. Without these the
    # background engine runspace has $null log paths / snapshot cache, so EVERY Log,
    # Write-Diag and Backup-Value call inside the engine silently fails (try/catch swallows
    # it). That is why tweak APPLY/REVERT activity never reached Ronin.log -- only the
    # main-thread environment header did. These must be shared into the runspace's globals.
    $RoninSharedState = @{
        RoninLogFile   = $Global:RoninLogFile
        RoninDiagFile  = $Global:RoninDiagFile
        RoninAuditFile = $Global:RoninAuditFile
        RoninDiagMode  = $Global:RoninDiagMode
        SnapshotFile   = $Global:SnapshotFile
        SnapshotCache  = $Global:SnapshotCache
    }
    foreach ($stateKey in $RoninSharedState.Keys) {
        $iss.Variables.Add((New-Object System.Management.Automation.Runspaces.SessionStateVariableEntry($stateKey, $RoninSharedState[$stateKey], "")))
    }

    # Inject Core Functions into background memory
    $CoreFunctions = @(
        "Start-RoninLoop", "Log", "Write-Diag", "Write-DiagException", "Start-DiagSession",
        "Set-Reg", "Remove-Reg", "Test-Reg-Read", "Test-Reg-Robust",
        "Disable-Task", "Enable-Task", "Set-Service-Registry",
        "Get-PCIe-State", "Set-PCIe-Mode", "Get-CpuBoostMode",
        "Get-EPP-Value", "Test-BitLocker", "Get-GpuRegistryPath", "Set-AMD-Feature", "Get-Intel-Video-Key",
        "Update-Sensors", "Update-Tweaks", "Backup-Value", "Restart-Explorer", "Check-Internet",
        "New-RoninRestorePoint"
    )
    foreach ($funcName in $CoreFunctions) {
        $funcObj = Get-Item -Path "Function:\$funcName" -ErrorAction SilentlyContinue
        if ($funcObj) {
            $iss.Commands.Add((New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry($funcName, $funcObj.ScriptBlock.ToString())))
        }
    }

    $runspacePool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, 2, $iss, $Host)
    $runspacePool.Open()

    # THREAD 1: CORE ENGINE WORKER
    $EnginePs = [PowerShell]::Create()
    $EnginePs.RunspacePool = $runspacePool
    $EnginePs.AddScript({
        param($SyncHash)
        $ErrorActionPreference = "Continue"
        try { Write-Diag "Engine runspace entered; mapping registry drives" "ENGINE" } catch {}
        if (!(Test-Path HKCU:)) { New-PSDrive -Name HKCU -PSProvider Registry -Root HKEY_CURRENT_USER -ErrorAction SilentlyContinue | Out-Null }
        if (!(Test-Path HKLM:)) { New-PSDrive -Name HKLM -PSProvider Registry -Root HKEY_LOCAL_MACHINE -ErrorAction SilentlyContinue | Out-Null }
        Start-RoninLoop -SyncHash $SyncHash
    })
    $EnginePs.AddArgument($SyncHash)
    $EnginePs.BeginInvoke() | Out-Null

    # THREAD 2: ASYNCHRONOUS BITLOCKER WATCHER (Prevents WMI UI Hangs)
    $WatcherPs = [PowerShell]::Create()
    $WatcherPs.RunspacePool = $runspacePool
    $WatcherPs.AddScript({
        param($SyncHash)
        try { $SyncHash.WatcherThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId } catch {}
        try { Write-Diag "BitLocker watcher thread started" "WATCHER" } catch {}
        while ($SyncHash.Running) {
            try {
                $vol = Get-CimInstance -Namespace "root/cimv2/Security/MicrosoftVolumeEncryption" -ClassName Win32_EncryptableVolume -Filter "DriveLetter='C:'" -ErrorAction SilentlyContinue
                if ($vol) {
                    $status = Invoke-CimMethod -InputObject $vol -MethodName GetConversionStatus -ErrorAction SilentlyContinue
                    if ($status) {
                        $SyncHash.BdeStatus = $status.ConversionStatus
                        $SyncHash.BdePct = $status.ConversionPercentage
                        
                        $SyncHash.Window.Dispatcher.Invoke({
                            if ($SyncHash.BdeStatus -eq 3) {
                                $SyncHash.BdeWarningActive = $true
                                $SyncHash.RebootBanner.Visibility = "Visible"
                                $SyncHash.RebootBanner.Background = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(139,0,0))
                                # Name-based lookup (was positional Children[0].Children[1], which silently
                                # breaks if the banner XAML is ever reordered)
                                $tb = $SyncHash.Window.FindName("BannerText")
                                if ($tb) {
                                    $tb.Text = "CRITICAL: DO NOT RESTART - DECRYPTING DRIVE [$($SyncHash.BdePct)%]"
                                    $tb.Foreground = [System.Windows.Media.Brushes]::White
                                }
                            } elseif ($SyncHash.BdeStatus -eq 0 -and $SyncHash.BdeWarningActive) {
                                $SyncHash.BdeWarningActive = $false
                                $SyncHash.RebootBanner.Background = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(0,100,0))
                                $tb = $SyncHash.Window.FindName("BannerText")
                                if ($tb) {
                                    $tb.Text = "DECRYPTION COMPLETE - SAFE TO PROCEED"
                                    $tb.Foreground = [System.Windows.Media.Brushes]::White
                                }
                            }
                        })
                    }
                }
            } catch { try { Write-DiagException "BitLocker watcher" $_ } catch {} }
            Start-Sleep -Seconds 5
        }
        try { Write-Diag "BitLocker watcher thread exiting" "WATCHER" } catch {}
    })
    $WatcherPs.AddArgument($SyncHash)
    $WatcherPs.BeginInvoke() | Out-Null

    # --- APPLY DATA-DRIVEN TWEAK TOOLTIPS ---
    # Feeds the InfoDojo hover/pin descriptions. Only sets a tooltip where the XAML didn't
    # already define one, so hand-authored tooltips win. Missing controls are skipped.
    if (Get-Variable "TweakTips" -ErrorAction SilentlyContinue) {
        foreach ($tipKey in $TweakTips.Keys) {
            try {
                $tc = $window.FindName($tipKey)
                if ($tc -and -not $tc.ToolTip) { $tc.ToolTip = $TweakTips[$tipKey] }
            } catch {}
        }
    }

    # --- 6. EVENTS & LOGIC ---

    # --- WINDOW CHROME LOGIC ---
    $TitleBar = $window.FindName("TitleBar")
    if ($TitleBar) {
        $TitleBar.Add_MouseLeftButtonDown({ $window.DragMove() })
    }
    
    $BtnClose = $window.FindName("Btn_Close")
    if ($BtnClose) { $BtnClose.Add_Click({ $window.Close() }) }

    $BtnMin = $window.FindName("Btn_Min")
    if ($BtnMin) { $BtnMin.Add_Click({ $window.WindowState = "Minimized" }) }

    # --- RECURSIVE VISUAL FINDER ---
    function Get-VisualChildren ($depObj, $depth = 0) {
        $children = @()
        if ($depth -gt 200) { return $children }
        try {
            if ($depObj -is [System.Windows.DependencyObject]) {
                $count = [System.Windows.Media.VisualTreeHelper]::GetChildrenCount($depObj)
                for ($i = 0; $i -lt $count; $i++) {
                    $child = [System.Windows.Media.VisualTreeHelper]::GetChild($depObj, $i)
                    $children += $child
                    $children += Get-VisualChildren $child ($depth + 1)
                }
            }
        } catch {} 
        return $children
    }

    # LOGICAL TREE FINDER (ROBUST FOR LOGIC/TASKS)
    function Find-Controls-Logical ($RootObj) {
        $found = @()
        $queue = [System.Collections.Queue]::new()
        $queue.Enqueue($RootObj)
        while ($queue.Count -gt 0) {
            $current = $queue.Dequeue()
            if ($current -is [System.Windows.Controls.CheckBox] -or $current -is [System.Windows.Controls.Button] -or $current -is [System.Windows.Controls.ComboBox]) { $found += $current }
            if ($current -is [System.Windows.DependencyObject]) {
                try {
                    $children = [System.Windows.LogicalTreeHelper]::GetChildren($current)
                    foreach ($child in $children) { if ($child) { $queue.Enqueue($child) } }
                } catch {}
            }
        }
        return $found
    }

    # VISUAL TREE FINDER (FOR UI BINDING)
    function Find-Controls-Flat ($Obj) {
        $found = @()
        $children = Get-VisualChildren $Obj
        foreach ($c in $children) {
                if ($c -is [System.Windows.Controls.CheckBox]) { $found += $c }
                if ($c -is [System.Windows.Controls.ComboBox]) { $found += $c }
                if ($c -is [System.Windows.Controls.Button]) { $found += $c }
        }
        return $found
    }

    # DYNAMIC INFO DOJO BINDER
    function Bind-InfoDojo {
        param($Container)
        $window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::ContextIdle)
        $ctrls = Get-VisualChildren $Container
        foreach ($c in $ctrls) {
            if (($c -is [System.Windows.Controls.Control]) -and $c.ToolTip -and $c.Tag -ne "Bound") {
                # HOVER
                $c.Add_MouseEnter({ 
                    if ($Global:RoninDojo -and -not $script:DojoLock) {
                        $t = $this.ToolTip
                        $msg = if ($t -is [System.Windows.Controls.ToolTip]) { $t.Content } else { $t.ToString() }
                        $Global:RoninDojo.Text = $msg
                        $Global:RoninDojo.Foreground = [System.Windows.Media.Brushes]::LimeGreen
                    }
                })
                # LEAVE
                $c.Add_MouseLeave({
                    if ($Global:RoninDojo -and -not $script:DojoLock) {
                        $Global:RoninDojo.Text = "Hover over any tweak to learn more..."
                        $Global:RoninDojo.Foreground = [System.Windows.Media.Brushes]::Gray
                    }
                })
                # RIGHT-CLICK: pin / unpin the description. Pinning used to be on LEFT-click,
                # but left-click is also how you toggle a tweak -- so clicking any checkbox (e.g.
                # the Hot-Bag toggle) pinned the dojo and silently disabled ALL hover tooltips.
                # Right-click is a deliberate gesture and leaves left-click free for toggling.
                $c.Add_PreviewMouseRightButtonDown({
                    if ($Global:RoninDojo) {
                        if ($script:DojoLock) {
                            $script:DojoLock = $false
                            $Global:RoninDojo.Text = "Hover over any tweak to learn more..."
                            $Global:RoninDojo.Foreground = [System.Windows.Media.Brushes]::Gray
                        } else {
                            $t = $this.ToolTip
                            $msg = if ($t -is [System.Windows.Controls.ToolTip]) { $t.Content } else { $t.ToString() }
                            $Global:RoninDojo.Text = "$msg (PINNED - right-click to unpin)"
                            $Global:RoninDojo.Foreground = [System.Windows.Media.Brushes]::Cyan
                            $script:DojoLock = $true
                        }
                    }
                })

                if ($c -is [System.Windows.Controls.CheckBox]) {
                    $c.Add_Click({ if ($this.Foreground -ne [System.Windows.Media.Brushes]::Yellow) { $this.Foreground = [System.Windows.Media.Brushes]::Yellow } })
                }
                $c.Tag = "Bound"
            }
        }
    }

    # --- TOUCH MODE & SCALING LOGIC (7.3.1: now properly enlarges UI) ---
    # Saves original window dimensions so we can restore them on uncheck.
    $script:TouchOriginalWidth = $null
    $script:TouchOriginalHeight = $null
    
    $window.FindName("Global_TouchMode").Add_Checked({
        try {
            # Capture current window size before scaling so we can restore later
            if ($null -eq $script:TouchOriginalWidth) {
                $script:TouchOriginalWidth = $window.ActualWidth
                $script:TouchOriginalHeight = $window.ActualHeight
            }
            
            $factor = 1.30
            $scale = New-Object System.Windows.Media.ScaleTransform
            $scale.ScaleX = $factor
            $scale.ScaleY = $factor
            
            # Apply LayoutTransform to the Window itself - this is the correct WPF pattern
            # for full-app scaling. LayoutTransform participates in layout (affects ActualWidth/Height
            # of children) while RenderTransform does not. Using it on Window scales everything inside.
            $window.LayoutTransform = $scale
            
            # Grow the window to fit the scaled content, capped to the primary screen
            $screenW = [System.Windows.SystemParameters]::PrimaryScreenWidth
            $screenH = [System.Windows.SystemParameters]::PrimaryScreenHeight
            $targetW = [Math]::Min([Math]::Round($script:TouchOriginalWidth * $factor), $screenW - 20)
            $targetH = [Math]::Min([Math]::Round($script:TouchOriginalHeight * $factor), $screenH - 60)
            $window.Width  = $targetW
            $window.Height = $targetH
            
            # Recenter on screen
            $window.Left = [Math]::Max(0, ($screenW - $targetW) / 2)
            $window.Top  = [Math]::Max(0, ($screenH - $targetH) / 2)
            
            if ($Global:RoninDojo) {
                $Global:RoninDojo.Text = "TOUCH MODE ACTIVE: Interface scaled to $([Math]::Round($factor * 100))% for easier touch input."
                $Global:RoninDojo.Foreground = [System.Windows.Media.Brushes]::Cyan
            }
        } catch {
            # If LayoutTransform on Window fails for any reason, fall back to Content
            try {
                $root = $window.Content
                if ($root) { 
                    $scale = New-Object System.Windows.Media.ScaleTransform 1.30, 1.30
                    $root.LayoutTransform = $scale
                }
            } catch {}
            if ($Global:RoninDojo) { 
                $Global:RoninDojo.Text = "Touch Mode error: $($_.Exception.Message)"
                $Global:RoninDojo.Foreground = [System.Windows.Media.Brushes]::Red
            }
        }
    })
    
    $window.FindName("Global_TouchMode").Add_Unchecked({
        try {
            # Reset both Window and Content transforms (we set Window in primary path, Content in fallback)
            $window.LayoutTransform = $null
            try { if ($window.Content) { $window.Content.LayoutTransform = $null } } catch {}
            
            if ($null -ne $script:TouchOriginalWidth) {
                $window.Width = $script:TouchOriginalWidth
                $window.Height = $script:TouchOriginalHeight
                $screenW = [System.Windows.SystemParameters]::PrimaryScreenWidth
                $screenH = [System.Windows.SystemParameters]::PrimaryScreenHeight
                $window.Left = ($screenW - $script:TouchOriginalWidth) / 2
                $window.Top  = ($screenH - $script:TouchOriginalHeight) / 2
                $script:TouchOriginalWidth = $null
                $script:TouchOriginalHeight = $null
            }
            
            if ($Global:RoninDojo) {
                $Global:RoninDojo.Text = "Standard UI scale restored."
                $Global:RoninDojo.Foreground = [System.Windows.Media.Brushes]::Gray
            }
        } catch {}
    })

    # --- EXPERT MODE LOGIC ---
    $ExpertControls = @("Sys_Bloatware", "Sys_DeviceInstall", "Adv_Printing", "Adv_TimerOpt", "Sys_SearchIndex", "HH_VMP", "Btn_UndoAll", "Btn_InPlaceUpgrade", "Adv_WSL", "Adv_HyperV", "Adv_RecallRemove", "HH_Encryption")
    
    $window.FindName("Global_ExpertMode").Add_Checked({ 
        foreach ($name in $ExpertControls) {
            $c = $window.FindName($name)
            if ($c) { $c.IsEnabled = $true; $c.Opacity = 1.0 }
        }
        if ($Global:RoninDojo) {
            $Global:RoninDojo.Text = "EXPERT MODE: Dangerous tweaks unlocked. Proceed with caution."
            $Global:RoninDojo.Foreground = [System.Windows.Media.Brushes]::Red
            # Don't pin the dojo here -- pinning is now a deliberate right-click action.
            # (This used to leave DojoLock stuck true, disabling all hover tooltips.)
            $script:DojoLock = $false
        }
    })

    $window.FindName("Global_ExpertMode").Add_Unchecked({ 
        foreach ($name in $ExpertControls) {
            $c = $window.FindName($name)
            if ($c) { 
                $c.IsEnabled = $false; 
                $c.Opacity = 0.5; 
                # Keep HH_Encryption state so we don't accidentally trigger a false Revert state if disabled
                if($c -is [System.Windows.Controls.CheckBox] -and $c.Name -ne "HH_Encryption") { $c.IsChecked = $false } 
            }
        }
        if ($Global:RoninDojo) {
            $Global:RoninDojo.Text = "Standard Mode: Safe optimization profile active."
            $Global:RoninDojo.Foreground = [System.Windows.Media.Brushes]::Gray
            $script:DojoLock = $false
        }
    })
    
    foreach ($name in $ExpertControls) {
        $c = $window.FindName($name)
        if ($c) { $c.IsEnabled = $false; $c.Opacity = 0.5 }
    }

    # --- HARDENED HIBERNATION INTERLOCK ---
    $sysHib = $window.FindName("Sys_Hibernation")
    $hhBag = $window.FindName("HH_HibernateBtn")
    $origHHToolTip = "Changes power button to Hibernate to prevent waking in bag."

    if ($sysHib -and $hhBag) {
        $hibLockAction = {
            if ($sysHib.IsChecked) { 
                $hhBag.IsEnabled = $false; 
                $hhBag.Opacity = 0.3; 
                $hhBag.ToolTip = "LOCKED: Requires Hibernation to be ENABLED in System Core."
                if ($Global:RoninDojo) {
                    $Global:RoninDojo.Text = "INTERLOCK ACTIVE: Hot-Bag Fix disabled because Hibernation is OFF."
                    $Global:RoninDojo.Foreground = [System.Windows.Media.Brushes]::Orange
                    # BUGFIX: this used to set $script:DojoLock = $true to "pin" this message,
                    # but it was never reset -> it permanently disabled ALL hover tooltips
                    # (the MouseEnter handlers bail when DojoLock is true). Keep it released.
                    $script:DojoLock = $false
                }
            }
            else {
                $hhBag.IsEnabled = $true;
                $hhBag.Opacity = 1.0;
                $hhBag.ToolTip = $origHHToolTip
                $script:DojoLock = $false   # self-heal: ensure hover tooltips are re-enabled
            }
        }
        $sysHib.Add_Checked($hibLockAction)
        $sysHib.Add_Unchecked($hibLockAction)
        $window.Dispatcher.InvokeAsync($hibLockAction, [System.Windows.Threading.DispatcherPriority]::ContextIdle)
    }

    # TAB GLOW UI
    function Update-TabUI ($ActiveBtn) {
        if ($window.FindName("SearchBox").Text.Length -gt 0) { return }
        $Tabs = @("Nav_Auto", "Nav_System", "Nav_Gaming", "Nav_Handheld", "Nav_Privacy", "Nav_Advanced", "Nav_Maint")
        foreach ($t in $Tabs) {
            $btn = $window.FindName($t)
            if ($btn) {
                $btn.Opacity = 1.0
                if ($btn.Name -eq $ActiveBtn.Name) {
                    $btn.Foreground = [System.Windows.Media.Brushes]::White
                    $bar = $btn.Template.FindName("AccentBar", $btn); if ($bar) { $bar.Visibility = "Visible" }
                    $btn.Effect = [System.Windows.Media.Effects.DropShadowEffect]::new()
                    $btn.Effect.Color = [System.Windows.Media.Color]::FromRgb(255, 46, 46)
                    $btn.Effect.BlurRadius = 15; $btn.Effect.ShadowDepth = 0; $btn.Effect.Opacity = 0.4
                } else {
                    $btn.Foreground = [System.Windows.Media.Brushes]::Gray
                    $bar = $btn.Template.FindName("AccentBar", $btn); if ($bar) { $bar.Visibility = "Collapsed" }
                    $btn.Effect = $null
                }
            }
        }
    }

    # GLOBAL SEARCH & TARGET LOCK
    $script:SearchTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:SearchTimer.Interval = [TimeSpan]::FromMilliseconds(300)
    $script:SearchTimer.Add_Tick({
        $script:SearchTimer.Stop()
        try {
        $txt = $window.FindName("SearchBox").Text.ToLower()
        $ph = $window.FindName("SearchPlaceholder")
        
        if ($txt.Length -gt 0) { $ph.Visibility = "Collapsed"; $script:DojoLock = $false } else { $ph.Visibility = "Visible" }
        
        $SearchMap = @{ "Tab_Auto"="Nav_Auto"; "Tab_System"="Nav_System"; "Tab_Gaming"="Nav_Gaming"; "Tab_Handheld"="Nav_Handheld"; "Tab_Privacy"="Nav_Privacy"; "Tab_Advanced"="Nav_Advanced"; "Tab_Maint"="Nav_Maint" }
        
        if ($txt.Length -eq 0) {
            foreach ($key in $SearchMap.Keys) {
                $tab = $window.FindName($key)
                $controls = Find-Controls-Logical $tab
                foreach ($c in $controls) {
                    $c.Opacity = 1.0; $c.Effect = $null
                    if ($c -is [System.Windows.Controls.ComboBox]) { $c.Foreground = [System.Windows.Media.Brushes]::White }
                    elseif ($c -is [System.Windows.Controls.CheckBox] -and $c.IsChecked) { $c.Foreground = [System.Windows.Media.Brushes]::LimeGreen }
                    else { $c.Foreground = [System.Windows.Media.Brushes]::LightGray }
                }
            }
            $currTab = $window.FindName("MainTabs").SelectedItem
            if ($currTab) { $currBtnName = $SearchMap[$currTab.Name]; if ($currBtnName) { Update-TabUI ($window.FindName($currBtnName)) } }
            return
        }

        $bestTabName = $null
        $maxMatches = 0
        $currentTabName = $window.FindName("MainTabs").SelectedItem.Name
        $currentTabMatches = 0

        foreach ($tabName in $SearchMap.Keys) {
            $tab = $window.FindName($tabName)
            $navBtn = $window.FindName($SearchMap[$tabName])
            $controls = Find-Controls-Logical $tab
            $tabMatchCount = 0
            
            foreach ($c in $controls) {
                $isMatch = $false
                if ($c.Content -is [string] -and $c.Content.ToLower().Contains($txt)) { $isMatch = $true }
                if (!$isMatch -and $c.ToolTip) {
                     $tt = if ($c.ToolTip -is [System.Windows.Controls.ToolTip]) { $c.ToolTip.Content } else { $c.ToolTip.ToString() }
                     if ($tt -and $tt.ToLower().Contains($txt)) { $isMatch = $true }
                }
                if ($isMatch) {
                    $tabMatchCount++
                    $c.Opacity = 1.0; $c.Foreground = [System.Windows.Media.Brushes]::Cyan
                    $c.Effect = [System.Windows.Media.Effects.DropShadowEffect]::new()
                    $c.Effect.Color = [System.Windows.Media.Color]::FromRgb(0, 255, 255); $c.Effect.BlurRadius = 10; $c.Effect.ShadowDepth = 0
                } else { $c.Opacity = 0.15; $c.Foreground = [System.Windows.Media.Brushes]::Gray; $c.Effect = $null }
            }
            
            if ($tabName -eq $currentTabName) { $currentTabMatches = $tabMatchCount }
            if ($tabMatchCount -gt $maxMatches) { $maxMatches = $tabMatchCount; $bestTabName = $tabName }

            if ($navBtn) {
                if ($tabMatchCount -gt 0) {
                    $navBtn.Foreground = [System.Windows.Media.Brushes]::Cyan; $navBtn.Opacity = 1.0
                    $navBtn.Effect = [System.Windows.Media.Effects.DropShadowEffect]::new()
                    $navBtn.Effect.Color = [System.Windows.Media.Color]::FromRgb(0, 255, 255); $navBtn.Effect.BlurRadius = 20; $navBtn.Effect.ShadowDepth = 0
                } else { $navBtn.Foreground = [System.Windows.Media.Brushes]::DarkGray; $navBtn.Effect = $null; $navBtn.Opacity = 0.3 }
            }
        }

        if ($currentTabMatches -eq 0 -and $maxMatches -gt 0 -and $bestTabName) {
            $window.FindName("MainTabs").SelectedItem = $window.FindName($bestTabName)
        }
        } catch { try { Write-Diag "Search tick error: $($_.Exception.Message)" "UI" } catch {} }
    })

    $window.FindName("SearchBox").Add_TextChanged({ $script:SearchTimer.Stop(); $script:SearchTimer.Start() })

    # NAVIGATION LOGIC
    $window.FindName("Nav_Auto").Add_Click({ $window.FindName("MainTabs").SelectedIndex = 0; Update-TabUI $this })
    $window.FindName("Nav_System").Add_Click({ $window.FindName("MainTabs").SelectedIndex = 1; Update-TabUI $this })
    $window.FindName("Nav_Gaming").Add_Click({ $window.FindName("MainTabs").SelectedIndex = 2; Update-TabUI $this })
    $window.FindName("Nav_Handheld").Add_Click({ $window.FindName("MainTabs").SelectedIndex = 3; Update-TabUI $this })
    $window.FindName("Nav_Privacy").Add_Click({ $window.FindName("MainTabs").SelectedIndex = 4; Update-TabUI $this })
    $window.FindName("Nav_Advanced").Add_Click({ $window.FindName("MainTabs").SelectedIndex = 5; Update-TabUI $this })
    $window.FindName("Nav_Maint").Add_Click({ $window.FindName("MainTabs").SelectedIndex = 6; Update-TabUI $this })

    $window.FindName("MainTabs").Add_SelectionChanged({
        if ($window.FindName("MainTabs").SelectedItem) {
            $SyncHash.ActiveTab = $window.FindName("MainTabs").SelectedItem.Name
            Bind-InfoDojo ($window.FindName("MainTabs").SelectedItem)
            if ($window.FindName("SearchBox").Text.Length -gt 0) { $script:SearchTimer.Stop(); $script:SearchTimer.Start() }
            else {
                $btnName = switch($SyncHash.ActiveTab) {
                    "Tab_Auto" { "Nav_Auto" }; "Tab_System" { "Nav_System" }; "Tab_Gaming" { "Nav_Gaming" }
                    "Tab_Handheld" { "Nav_Handheld" }; "Tab_Privacy" { "Nav_Privacy" }; "Tab_Advanced" { "Nav_Advanced" }
                    "Tab_Maint" { "Nav_Maint" }
                }
                if ($btnName) { Update-TabUI ($window.FindName($btnName)) }
            }
            [System.GC]::Collect()
        }
    })

    # SMART INITIALIZATION
    
    $window.Add_ContentRendered({ 
        try {
            $tabs = $window.FindName("MainTabs")
            if ($tabs) {
                $tabs.IsEnabled = $false
                $tabs.Opacity = 0.5
            }
            if ($SyncHash.Console) { $SyncHash.Console.Text = "> SYSTEM AUDIT SEQUENCE INITIATED...`n> PLEASE WAIT..." }

            $SyncHash.JobQueue.Enqueue("INIT")
            Update-TabUI ($window.FindName("Nav_Auto")); Bind-InfoDojo ($window.FindName("Tab_Auto"))

            try {
                $cimComp = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
                if ($cimComp -and ($cimComp.Model -match "RC71|83[E-G]1|83S|Claw|Jupiter")) {
                    $window.FindName("MainTabs").SelectedIndex = 3 
                    Update-TabUI ($window.FindName("Nav_Handheld")); $SyncHash.JobQueue.Enqueue("LOG_HANDHELD")
                }
            } catch {}

            try {
                $gpuObj = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select -First 1
                if ($gpuObj) {
                    $isIntel = $gpuObj.Name -match "Intel|Arc|Iris"
                    $isNvidia = $gpuObj.Name -match "NVIDIA"
                    
                    $secAMD = $window.FindName("Section_AMD"); $secIntel = $window.FindName("Section_Intel")
                    $autoVari = $window.FindName("Auto_VariBright"); $autoDPST = $window.FindName("Auto_DPST")
                    $nvFlip = $window.FindName("Game_NvidiaFlipMode") 
                    $intMod = $window.FindName("Game_InterruptModeration")

                    if ($isIntel) {
                        if ($secAMD) { $secAMD.IsEnabled = $false; $secAMD.Opacity = 0.3 }
                        if ($secIntel) { $secIntel.Visibility = "Visible" }
                        if ($autoVari) { $autoVari.Visibility = "Collapsed"; $autoVari.IsChecked = $false }
                        if ($autoDPST) { $autoDPST.Visibility = "Visible"; $autoDPST.IsChecked = $true }
                        if ($nvFlip) { $nvFlip.IsEnabled = $false; $nvFlip.Opacity = 0.3; $nvFlip.IsChecked = $false }
                        if ($intMod) { $intMod.IsEnabled = $false; $intMod.Opacity = 0.5; $intMod.IsChecked = $false; $intMod.ToolTip = "LOCKED: Incompatible with Intel Drivers." }
                    } elseif ($isNvidia) {
                        if ($secAMD) { $secAMD.IsEnabled = $false; $secAMD.Opacity = 0.3 }
                        if ($secIntel) { $secIntel.Visibility = "Collapsed" }
                        if ($autoVari) { $autoVari.Visibility = "Visible" } 
                        if ($autoDPST) { $autoDPST.Visibility = "Collapsed"; $autoDPST.IsChecked = $false }
                        if ($nvFlip) { $nvFlip.IsEnabled = $true; $nvFlip.Opacity = 1.0 }
                    } else {
                        if ($secAMD) { $secAMD.IsEnabled = $true; $secAMD.Opacity = 1.0 }
                        if ($secIntel) { $secIntel.Visibility = "Collapsed" }
                        if ($autoVari) { $autoVari.Visibility = "Visible" }
                        if ($autoDPST) { $autoDPST.Visibility = "Collapsed"; $autoDPST.IsChecked = $false }
                        if ($nvFlip) { $nvFlip.IsEnabled = $false; $nvFlip.Opacity = 0.3; $nvFlip.IsChecked = $false }
                    }
                }
            } catch {}
        } catch { Log "Startup Warning: Detection failure." }
    })
    
    # SAFETY: if BitLocker is mid-decryption (ConversionStatus 3), warn before the user
    # closes Ronin -- a reboot/shutdown before 100% triggers a BitLocker recovery screen.
    $window.Add_Closing({
        if ($SyncHash.BdeStatus -eq 3) {
            $pct = if ($null -ne $SyncHash.BdePct) { "$($SyncHash.BdePct)%" } else { "in progress" }
            $r = [System.Windows.Forms.MessageBox]::Show(
                "BitLocker is still DECRYPTING your drive ($pct done).`n`nClosing Ronin is OK, but DO NOT restart or shut down the PC until Windows reports decryption is 100% complete (Control Panel -> BitLocker Drive Encryption), or you may hit a BitLocker recovery screen.`n`nClose Ronin anyway?",
                "Decryption In Progress",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Warning)
            if ($r -ne [System.Windows.Forms.DialogResult]::Yes) { $_.Cancel = $true }
        }
    })

    $window.Add_Closed({
        $SyncHash.Running = $false
        try { $EnginePs.Dispose() } catch {}
        try { $WatcherPs.Dispose() } catch {}
        try { $runspacePool.Close(); $runspacePool.Dispose() } catch {}
        Stop-Transcript -ErrorAction SilentlyContinue
    })

    function Get-Tasks ($Prefix) {
        $list = [System.Collections.ArrayList]::new()
        $allControls = Find-Controls-Logical $window | Where-Object { $_.Name -and $_.Name.StartsWith($Prefix) }
        foreach ($c in $allControls) { 
            if ($c.IsEnabled) {
                if ($c -is [System.Windows.Controls.CheckBox]) { [void]$list.Add([PSCustomObject]@{Key=$c.Name; Action=if($c.IsChecked){"Apply"}else{"Revert"}}) }
                if ($c -is [System.Windows.Controls.ComboBox]) { [void]$list.Add([PSCustomObject]@{Key=$c.Name; Action="Apply"; Value=$c.SelectedIndex}) }
            }
        }
        return ,$list
    }

    $window.FindName("Btn_RestartExp").Add_Click({ $SyncHash.JobQueue.Enqueue("RESTART_EXPLORER") })
    $window.FindName("Btn_Analyze").Add_Click({ $SyncHash.JobQueue.Enqueue("AUDIT_SYSTEM") })
    $window.FindName("Btn_RunSystem").Add_Click({ $SyncHash.JobQueue.Enqueue( (Get-Tasks "Sys_") ) })
    $window.FindName("Btn_RunGaming").Add_Click({ $SyncHash.JobQueue.Enqueue( (Get-Tasks "Game_") ) })
    $window.FindName("Btn_RunHandheld").Add_Click({ $SyncHash.JobQueue.Enqueue( (Get-Tasks "HH_") ) })
    $window.FindName("Btn_RunPrivacy").Add_Click({ $SyncHash.JobQueue.Enqueue( (Get-Tasks "Priv_") ) })
    $window.FindName("Btn_RunAdvanced").Add_Click({ $SyncHash.JobQueue.Enqueue( (Get-Tasks "Adv_") ) })
    
    $window.FindName("Btn_RunAuto").Add_Click({
        $j=[System.Collections.ArrayList]::new(); $controls = Find-Controls-Logical ($window.FindName("Tab_Auto"))
        $controls | ForEach-Object {
            if ($_ -is [System.Windows.Controls.CheckBox]) {
                 $dbKey = switch ($_.Name) {
                    "Auto_Visuals" { "Sys_VisualFX" }; "Auto_Hags" { "Game_HAGS" }; "Auto_GameMode" { "Game_GameMode" }
                    "Auto_Recall" { "Sys_Recall" }; "Auto_SysRestore" { "Sys_SysRestore" }; "Auto_UAC" { "Sys_UAC" }
                    "Auto_CoreIso" { "HH_CoreIso" }; "Auto_Tele" { "Priv_Tele" }; "Auto_AdID" { "Priv_AdID" }; "Auto_Loc" { "Priv_Loc" }
                    "Auto_Wifi" { "Priv_Wifi" }; "Auto_Bing" { "Priv_Bing" }; "Auto_Widgets" { "Priv_Widgets" }; "Auto_Copilot" { "Priv_Copilot" }
                    "Auto_Drivers" { "Sys_DeviceInstall" }; "Auto_Remote" { "Sys_RemoteAssist" }; "Auto_PCIe" { "Game_PCIe" }; "Auto_VariBright" { "Game_VariBright" }
                    "Auto_DPST" { "Game_DPST" }; "Auto_Bright" { "Sys_AutoBright" }; "Auto_Consumer" { "Priv_ConsumerFeatures" }; "Auto_WER" { "Priv_WER" }
                    "Auto_CpuOpt" { "Sys_CpuOpt" }; "Auto_StartAds" { "Sys_StartAds" }; "Auto_Activity" { "Priv_ActivityUpload" }; default { $null }
                 }
                 if($dbKey){ $action = if ($_.IsChecked) { "Apply" } else { "Revert" }; [void]$j.Add([PSCustomObject]@{Key=$dbKey; Action=$action}) }
            }
        }
        $SyncHash.JobQueue.Enqueue($j)
    })

    $window.FindName("Btn_CleanTemp").Add_Click({ $SyncHash.JobQueue.Enqueue("MAINT_CLEAN") })
    $window.FindName("Btn_SFC").Add_Click({ $SyncHash.JobQueue.Enqueue("MAINT_SFC") })
    $window.FindName("Btn_DISM").Add_Click({ $SyncHash.JobQueue.Enqueue("MAINT_DISM") })
    $window.FindName("Btn_CleanUpdate").Add_Click({ $SyncHash.JobQueue.Enqueue("MAINT_UPDATE") })
    $window.FindName("Btn_NetReset").Add_Click({ $SyncHash.JobQueue.Enqueue("MAINT_NET") })
    $window.FindName("Btn_CheckDrivers").Add_Click({ $SyncHash.JobQueue.Enqueue("MAINT_DRIVERS") })
    $window.FindName("Btn_RestorePoint").Add_Click({ $SyncHash.JobQueue.Enqueue("MAINT_RESTORE") })
    $window.FindName("Btn_FullRepair").Add_Click({ $SyncHash.JobQueue.Enqueue("REPAIR_FULL") })
    $window.FindName("Btn_Battery").Add_Click({ $SyncHash.JobQueue.Enqueue("MAINT_BATTERY") })
    $window.FindName("Btn_Sleep").Add_Click({ $SyncHash.JobQueue.Enqueue("MAINT_SLEEP") })
    $window.FindName("Btn_Shader").Add_Click({ $SyncHash.JobQueue.Enqueue("MAINT_SHADER") })
    $window.FindName("Btn_VisualCpp").Add_Click({ $SyncHash.JobQueue.Enqueue("MAINT_VCREDIST") })
    $window.FindName("Btn_OpenBackups").Add_Click({ $SyncHash.JobQueue.Enqueue("MAINT_OPEN_BACKUPS") })
    $window.FindName("Btn_Reclaim").Add_Click({ $SyncHash.JobQueue.Enqueue("MAINT_RECLAIM") })
    $window.FindName("Btn_DiskClean").Add_Click({ $SyncHash.JobQueue.Enqueue("MAINT_DISKCLEAN") })
    $window.FindName("Btn_Trim").Add_Click({ $SyncHash.JobQueue.Enqueue("MAINT_TRIM") })
    $window.FindName("Btn_IconCache").Add_Click({ $SyncHash.JobQueue.Enqueue("MAINT_ICON") })
    $window.FindName("Btn_WuReset").Add_Click({ $SyncHash.JobQueue.Enqueue("MAINT_WURESET") })
    $window.FindName("Btn_StoreReset").Add_Click({ $SyncHash.JobQueue.Enqueue("MAINT_STORERESET") })
    $window.FindName("Btn_GpuReset").Add_Click({ $SyncHash.JobQueue.Enqueue("MAINT_GPURESET") })
    
    $window.FindName("Btn_BootUEFI").Add_Click({ $SyncHash.JobQueue.Enqueue("BOOT_UEFI") })
    $window.FindName("Btn_BootRecovery").Add_Click({ $SyncHash.JobQueue.Enqueue("BOOT_RECOVERY") })

    $window.FindName("Btn_InPlaceUpgrade").Add_Click({ 
        if ($window.FindName("Global_ExpertMode").IsChecked) {
             if ([System.Windows.Forms.MessageBox]::Show("Keep personal files and apps. Proceed?", "Repair", [System.Windows.Forms.MessageBoxButtons]::YesNo) -eq "Yes") { Start-Process "https://www.microsoft.com/software-download/windows11" }
        }
    })

    $window.FindName("Btn_UndoAll").Add_Click({ 
        if ($window.FindName("Global_ExpertMode").IsChecked) {
            if ([System.Windows.Forms.MessageBox]::Show("Revert ALL tweaks?", "Undo", [System.Windows.Forms.MessageBoxButtons]::YesNo) -eq "Yes") { $SyncHash.JobQueue.Enqueue("REVERT_ALL") }
        }
    })

    $window.FindName("Btn_DNS_Cloud").Add_Click({ $SyncHash.JobQueue.Enqueue("DNS_Cloudflare") })
    $window.FindName("Btn_DNS_Google").Add_Click({ $SyncHash.JobQueue.Enqueue("DNS_Google") })
    $window.FindName("Btn_DNS_Quad9").Add_Click({ $SyncHash.JobQueue.Enqueue("DNS_Quad9") })
    $window.FindName("Btn_DNS_Auto").Add_Click({ $SyncHash.JobQueue.Enqueue("DNS_Auto") })

    $window.ShowDialog() | Out-Null
} Catch { 
    $errMsg = $_.Exception.Message
    [System.Windows.Forms.MessageBox]::Show("CRITICAL LAUNCH ERROR:`n`n$errMsg", "Ronin Failed", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
}

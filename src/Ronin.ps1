<#
.SYNOPSIS
    Project Ronin - Windows 11 Optimization Suite (Shogun Edition v8.0.0)

.DESCRIPTION
    A graphical Windows 11 24H2/25H2 tweak utility inspired by Chris Titus Tech's WinUtil.
    Provides toggleable system, gaming, privacy, handheld, and maintenance optimizations.
    All changes are reversible. Ronin records each tweak's original value (and which
    tweaks it applied) under HKLM:\SOFTWARE\Ronin, so every revert restores your own setting.

.NOTES
    Version  : 8.0.0
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

# --- PROJECT RONIN: CONTROLLER v8.0.0 ---

$Version = "8.0.0"

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

    # --- 1b. ONE RONIN AT A TIME (8.0) ---
    # A second copy (a double-click while the UAC prompt was slow, the launcher run twice) started a SECOND
    # engine: both wrote the applied ledger and recorded originals and both restarted Explorer. A named
    # mutex needs no compiled code; the second copy brings the first window forward and exits. A mutex left
    # by a crashed Ronin is "abandoned" - that still counts as ours.
    # If the mutex can't be created at all, run without the guard - it must never stop Ronin starting.
    $script:RoninMutex = $null; $mutexOwned = $true
    try {
        $script:RoninMutex = New-Object System.Threading.Mutex($false, "Global\ProjectRonin.SingleInstance")
        try { $mutexOwned = $script:RoninMutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $mutexOwned = $true }
    } catch { $mutexOwned = $true }
    if (-not $mutexOwned) {
        $shown = $false
        try { Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction Stop; [Microsoft.VisualBasic.Interaction]::AppActivate("PROJECT RONIN //"); $shown = $true } catch {}
        if (-not $shown) {
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
            [System.Windows.Forms.MessageBox]::Show("Project Ronin is already running.", "Project Ronin", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        }
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
    # The window's size is the XAML's (8.0 Black Ice: 1100x760). This used to force 730 here, so the real
    # app opened 30 px shorter than the layout the UI tests measure - every tab drawn ~4% smaller than
    # designed. validate.ps1 fails a literal $window.Height/Width again.

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
    # (8.0 Black Ice brushes and helpers: see "8.0 BLACK ICE" in the 7.6 block.)
    # Controls the search recoloured, with their own Foreground (or UnsetValue), so clearing restores them exactly.
    $script:SearchSaved = New-Object 'System.Collections.Generic.Dictionary[object,object]'

    # MAP UI ELEMENTS
    $SyncHash.Console = $window.FindName("ConsoleOutput")
    $SyncHash.Scroll = $window.FindName("ConsoleScroll")
    # 8.0: the engine's mailbox. The engine only ever DROPS things here; the UI's own timer applies them
    # (Invoke-EngineMailbox). Engine-made closures posted with BeginInvoke were silently LOST while the
    # engine was busy - reproduced: "System Audit Complete." never reached the console, so it sat on
    # "PLEASE WAIT..." after every audit, and the reset-alert / Explorer banners could vanish the same way.
    $SyncHash.LogQueue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]'
    $SyncHash.UiRequests = New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]'
    $SyncHash.InfoDojo = $window.FindName("InfoDojo")
    $SyncHash.RamStatus = $window.FindName("Txt_RamStatus")
    $SyncHash.CpuStatus = $window.FindName("Txt_CpuStatus")
    $SyncHash.HealthRank = $window.FindName("Txt_HealthRank")
    $SyncHash.HealthBar = $window.FindName("HealthBar")
    $SyncHash.ProgBar = $window.FindName("ProgBar")
    $SyncHash.SafeMode = $window.FindName("Global_SafeMode")
    $SyncHash.RebootBanner = $window.FindName("Banner_Reboot")
    $SyncHash.ConsoleLast = $window.FindName("Txt_ConsoleLast")   # 8.0 status bar: the console's newest line
    
    $SyncHash.JobQueue = [System.Collections.Queue]::Synchronized([System.Collections.Queue]::new())
    $SyncHash.Running = $true
    $SyncHash.StatusCache = [Hashtable]::Synchronized(@{})
    $SyncHash.ActiveTab = "Tab_Auto"

    # Session cache for the few CHECKS that are genuinely slow (BitLocker WMI ~5s, NetAdapter
    # power ~0.7s, scheduled-task lookups ~0.5s). Those states only change via a user-initiated
    # apply (which clears its own key) or a manual Run System Audit (which clears the whole cache),
    # so reusing the value across the automatic post-batch audits is safe and saves seconds each.
    $SyncHash.SlowCheckCache = [hashtable]::Synchronized(@{})

    # Detect handheld ONCE, here, before the engine runspace launches. The audit reads this
    # cached flag instead of calling Get-CimInstance on the UI thread mid-audit (WMI can stall
    # for seconds and freeze the UI). Model strings are static per machine, so one query suffices.
    $SyncHash.IsHandheld = $false
    try {
        $cimComp = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
        if ($cimComp -and ($cimComp.Model -match "RC71|83[E-G]1|83S|Claw|Jupiter")) { $SyncHash.IsHandheld = $true }
    } catch {}

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
        "New-RoninRestorePoint",
        "Save-OriginalState", "Get-OriginalState", "Clear-OriginalState",
        "Get-PowerIndex", "Save-PowerOriginal", "Restore-PowerOriginal", "Save-RegOriginal", "Restore-RegOriginal",
        "Add-AppliedMark", "Remove-AppliedMark", "Get-AppliedMarks", "Get-UndoneTweaks", "Get-AppliedLedger", "Invoke-ResetCheck",
        "Test-AppliedMark", "Clear-PartnerMarks", "Invoke-RoninProcess",
        "ConvertFrom-DxSettings", "ConvertTo-DxSettings", "Get-DxUserSetting", "Set-DxUserSetting",
        "Get-ExpiredTweaks", "Invoke-SpecApply", "Invoke-SpecRevert", "Test-Spec",
        "ConvertFrom-WuTime", "Get-WuPauseDaysLeft", "Read-WuPauseExpiry", "Set-WuPause", "Restore-WuPause",
        "Add-RemovedApp", "ConvertFrom-RemovedRecord", "Get-RemovedApps",
        "ConvertTo-DnsRecord", "ConvertFrom-DnsRecord", "Save-DnsOriginals", "Set-RoninDns", "Restore-RoninDns"
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
    # Seed the watchdog's liveness clock HERE, not in the engine: if the engine runspace throws
    # on entry and never reaches Start-RoninLoop, LastBeat would stay null and the watchdog would
    # sit silent through the exact failure it exists to catch.
    $SyncHash.LastBeat = Get-Date
    $SyncHash.CurrentOp = "engine starting"
    $EnginePs = [PowerShell]::Create()
    $EnginePs.RunspacePool = $runspacePool
    [void]$EnginePs.AddScript({
        param($SyncHash)
        $ErrorActionPreference = "Continue"
        try { Write-Diag "Engine runspace entered; mapping registry drives" "ENGINE" } catch {}
        if (!(Test-Path HKCU:)) { New-PSDrive -Name HKCU -PSProvider Registry -Root HKEY_CURRENT_USER -ErrorAction SilentlyContinue | Out-Null }
        if (!(Test-Path HKLM:)) { New-PSDrive -Name HKLM -PSProvider Registry -Root HKEY_LOCAL_MACHINE -ErrorAction SilentlyContinue | Out-Null }
        Start-RoninLoop -SyncHash $SyncHash
    })
    [void]$EnginePs.AddArgument($SyncHash)
    $EnginePs.BeginInvoke() | Out-Null

    # THREAD 2: ASYNCHRONOUS BITLOCKER WATCHER (Prevents WMI UI Hangs)
    $WatcherPs = [PowerShell]::Create()
    $WatcherPs.RunspacePool = $runspacePool
    [void]$WatcherPs.AddScript({
        param($SyncHash)
        try { $SyncHash.WatcherThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId } catch {}
        try { Write-Diag "BitLocker watcher thread started" "WATCHER" } catch {}
        while ($SyncHash.Running) {
            try {
                $vol = Get-CimInstance -Namespace "root/cimv2/Security/MicrosoftVolumeEncryption" -ClassName Win32_EncryptableVolume -Filter "DriveLetter='C:'" -ErrorAction SilentlyContinue
                # Share the answer with the audit: HH_Encryption's Check needs exactly this, and the
                # BitLocker WMI provider costs ~5 s per query. Same rule as the Check: no volume
                # object = not encrypted = "applied".
                if ($SyncHash.SlowCheckCache) { $SyncHash.SlowCheckCache['HH_Encryption'] = [bool]((-not $vol) -or ($vol.ProtectionStatus -eq 0)); $SyncHash.BdeSeeded = $true }
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
            # Poll fast only while a drive is (de/en)crypting (status 2/3) or right after Ronin started a
            # decryption; otherwise once a minute. It used to run the ~5 s BitLocker WMI query every
            # 5 s forever - permanent WMI load on PCs where nothing was ever converting.
            $fast = ($SyncHash.BdeStatus -eq 2 -or $SyncHash.BdeStatus -eq 3 -or ($SyncHash.BdeFastUntil -and (Get-Date) -lt $SyncHash.BdeFastUntil))
            $waitS = if ($fast) { 5 } else { 60 }
            for ($w = 0; $w -lt $waitS -and $SyncHash.Running; $w++) {
                Start-Sleep -Seconds 1
                # Ronin just started a decryption: wake up immediately so the progress banner appears.
                if (-not $fast -and $SyncHash.BdeFastUntil -and (Get-Date) -lt $SyncHash.BdeFastUntil) { break }
            }
        }
        try { Write-Diag "BitLocker watcher thread exiting" "WATCHER" } catch {}
    })
    [void]$WatcherPs.AddArgument($SyncHash)
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
    # --- 8.0 EDITION HONESTY ---
    # Some policies are only honoured by some Windows editions. A tweak declares EditionNote="..." and,
    # on editions other than Enterprise/Education, the note is appended to its tooltip (InfoDojo shows
    # it on hover) - a green toggle must not imply it did something this edition ignores.
    # Registry read (instant), not WMI (invariant 8).
    $SyncHash.EditionId = ''
    try { $SyncHash.EditionId = "$((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop).EditionID)" } catch {}
    if ($SyncHash.EditionId -and $SyncHash.EditionId -notmatch '^(Enterprise|Education|IoTEnterprise|ServerRdsh)') {
        $edName = switch -Regex ($SyncHash.EditionId) { '^Core' { 'Home' } '^Professional' { 'Pro' } default { $SyncHash.EditionId } }
        foreach ($ek in @($RoninDB.Keys)) {
            $note = $RoninDB[$ek].EditionNote
            if (-not $note) { continue }
            try { $ec = $window.FindName($ek); if ($ec) { $ec.ToolTip = "$($ec.ToolTip)`n`nON WINDOWS ${edName}: $note" } } catch {}
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
    # 8.0 Black Ice: bound controls are remembered in a set, not by writing "Bound" into their Tag -
    # a tweak checkbox's Tag now carries its queued mark ("Q", read by the switch style).
    function Bind-InfoDojo {
        param($Container)
        if ($null -eq $script:DojoBound) { $script:DojoBound = New-Object 'System.Collections.Generic.HashSet[object]' }
        $window.Dispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::ContextIdle)
        # 8.0 fix: a tab's controls are drawn under the TabControl's content host, not under the TabItem (whose
        # header is collapsed, so it has NO visual children). Walking the TabItem found nothing, so hovering a
        # tweak never filled the info panel. Walk the tab's content instead (shown, so its tree exists).
        if ($Container -is [System.Windows.Controls.TabItem]) { $Container = $Container.Content }
        if (-not $Container) { return }
        $ctrls = Get-VisualChildren $Container
        foreach ($c in $ctrls) {
            if (($c -is [System.Windows.Controls.Control]) -and $c.ToolTip -and -not $script:DojoBound.Contains($c)) {
                # HOVER
                $c.Add_MouseEnter({ if (-not $script:DojoLock) { Show-DojoInfo $this } })
                # LEAVE
                $c.Add_MouseLeave({ if (-not $script:DojoLock) { Show-DojoInfo $null } })
                # RIGHT-CLICK: pin / unpin the description. Pinning used to be on LEFT-click,
                # but left-click is also how you toggle a tweak -- so clicking any checkbox (e.g.
                # the Hot-Bag toggle) pinned the dojo and silently disabled ALL hover tooltips.
                # Right-click is a deliberate gesture and leaves left-click free for toggling.
                $c.Add_PreviewMouseRightButtonDown({
                    if ($script:DojoLock) { $script:DojoLock = $false; Show-DojoInfo $null }
                    else { Show-DojoInfo $this -Pinned; $script:DojoLock = $true }
                })

                # A user click (never the audit: Click is not raised when code sets IsChecked) marks the
                # switch queued when it now differs from what the audit found, then recounts the tab.
                if ($c -is [System.Windows.Controls.CheckBox] -and $script:TweakBoxNames -and $script:TweakBoxNames.Contains($c.Name)) {
                    $c.Add_Click({ Invoke-UiSafe 'Tweak switch click' { Invoke-TweakClicked $this } })
                }
                [void]$script:DojoBound.Add($c)
            }
        }
    }

    # --- TOUCH MODE & SCALING LOGIC (7.3.1: now properly enlarges UI) ---
    # Saves original window dimensions so we can restore them on uncheck.
    $script:TouchOriginalWidth = $null
    $script:TouchOriginalHeight = $null
    
    # 8.0: the scale goes on the window's CONTENT. Since 7.3.1 it was set on the Window itself, which
    # WPF silently ignores (measured: a nav button rendered 38.7 px normally and 41.9 px in "130%"
    # Touch Mode, where the bigger window only let the tab Viewbox stop shrinking). So Touch Mode
    # topped out at 100% while announcing 130% - and on a screen smaller than 130% of the window (a
    # 1280x720 handheld) the window got SHORTER and everything got smaller. The factor is now capped
    # to what the screen's work area can show; returns the factor used, 0 if the screen is already full.
    function Set-TouchScale ([bool]$On, $WorkArea = [System.Windows.SystemParameters]::WorkArea) {
        if ($On) {
            if ($null -eq $script:TouchOriginalWidth) {
                $script:TouchOriginalWidth  = if ($window.ActualWidth -gt 0) { $window.ActualWidth } else { $window.Width }
                $script:TouchOriginalHeight = if ($window.ActualHeight -gt 0) { $window.ActualHeight } else { $window.Height }
            }
            $factor = [Math]::Min(1.30, [Math]::Min(($WorkArea.Width - 20) / $script:TouchOriginalWidth, ($WorkArea.Height - 20) / $script:TouchOriginalHeight))
            if ($factor -lt 1.05) {
                $window.Content.LayoutTransform = $null
                $script:TouchOriginalWidth = $null; $script:TouchOriginalHeight = $null
                return 0
            }
            $window.Content.LayoutTransform = New-Object System.Windows.Media.ScaleTransform($factor, $factor)
            $w = [Math]::Round($script:TouchOriginalWidth * $factor); $h = [Math]::Round($script:TouchOriginalHeight * $factor)
            $window.Width = $w; $window.Height = $h
            $window.Left = $WorkArea.Left + [Math]::Max(0, ($WorkArea.Width - $w) / 2)
            $window.Top  = $WorkArea.Top + [Math]::Max(0, ($WorkArea.Height - $h) / 2)
            return $factor
        }
        $window.LayoutTransform = $null
        $window.Content.LayoutTransform = $null
        if ($null -ne $script:TouchOriginalWidth) {
            $window.Width = $script:TouchOriginalWidth; $window.Height = $script:TouchOriginalHeight
            $window.Left = $WorkArea.Left + [Math]::Max(0, ($WorkArea.Width - $script:TouchOriginalWidth) / 2)
            $window.Top  = $WorkArea.Top + [Math]::Max(0, ($WorkArea.Height - $script:TouchOriginalHeight) / 2)
            $script:TouchOriginalWidth = $null; $script:TouchOriginalHeight = $null
        }
        return 1
    }

    $window.FindName("Global_TouchMode").Add_Checked({
        try {
            $f = Set-TouchScale $true
            if ($Global:RoninDojo) {
                $Global:RoninDojo.Text = if ($f -gt 0) { "TOUCH MODE ACTIVE: interface scaled to $([Math]::Round($f * 100))% for easier touch input." }
                                         else { "TOUCH MODE: Ronin already fills this screen, so it can't get any bigger here. To enlarge everything, use Windows Settings > System > Display > Scale." }
                $Global:RoninDojo.Foreground = [System.Windows.Media.Brushes]::Cyan
            }
        } catch {
            if ($Global:RoninDojo) {
                $Global:RoninDojo.Text = "Touch Mode error: $($_.Exception.Message)"
                $Global:RoninDojo.Foreground = [System.Windows.Media.Brushes]::Red
            }
        }
    })

    $window.FindName("Global_TouchMode").Add_Unchecked({
        try {
            [void](Set-TouchScale $false)
            if ($Global:RoninDojo) {
                $Global:RoninDojo.Text = "Standard UI scale restored."
                $Global:RoninDojo.Foreground = [System.Windows.Media.Brushes]::Gray
            }
        } catch {}
    })

    # --- EXPERT MODE LOGIC ---
    $ExpertControls = @("Dcl_WU_Off", "Sys_DeviceInstall", "Adv_Printing", "Adv_TimerOpt", "Sys_SearchIndex", "HH_VMP", "Btn_UndoAll", "Btn_InPlaceUpgrade", "Adv_WSL", "Adv_HyperV", "Adv_RecallRemove", "HH_Encryption")
    
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
        [void]$window.Dispatcher.InvokeAsync($hibLockAction, [System.Windows.Threading.DispatcherPriority]::ContextIdle)
    }

    # TAB GLOW UI
    function Update-TabUI ($ActiveBtn) {
        if ($window.FindName("SearchBox").Text.Length -gt 0) { return }
        $Tabs = @("Nav_Auto", "Nav_System", "Nav_Gaming", "Nav_Handheld", "Nav_Privacy", "Nav_Declutter", "Nav_Advanced", "Nav_Maint")
        foreach ($t in $Tabs) {
            $btn = $window.FindName($t)
            if ($btn) {
                $btn.Opacity = 1.0; $btn.Effect = $null
                # 8.0 Black Ice: the active tab gets the red chevron + bar (template parts); the label colour
                # comes from the style, so clear any colour a search left behind.
                $on = ($ActiveBtn -and $btn.Name -eq $ActiveBtn.Name)
                if ($on) { $btn.Foreground = [System.Windows.Media.Brushes]::White } else { $btn.ClearValue([System.Windows.Controls.Control]::ForegroundProperty) }
                try { $btn.ApplyTemplate() | Out-Null } catch {}
                foreach ($part in 'AccentBar', 'ActiveBg') { $p = $btn.Template.FindName($part, $btn); if ($p) { $p.Visibility = if ($on) { "Visible" } else { "Collapsed" } } }
                $idx = $btn.Template.FindName("Idx", $btn); if ($idx) { $idx.Foreground = if ($on) { $window.FindResource("Accent") } else { $script:BrushIdx } }
                $cnt = $btn.Template.FindName("Count", $btn); if ($cnt) { $cnt.Foreground = if ($on) { [System.Windows.Media.Brushes]::White } else { $script:BrushMuted } }
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
        if ($null -eq $script:SearchSaved) { $script:SearchSaved = New-Object 'System.Collections.Generic.Dictionary[object,object]' }
        
        if ($txt.Length -gt 0) { $ph.Visibility = "Collapsed"; $script:DojoLock = $false } else { $ph.Visibility = "Visible" }
        
        $SearchMap = @{ "Tab_Auto"="Nav_Auto"; "Tab_System"="Nav_System"; "Tab_Gaming"="Nav_Gaming"; "Tab_Handheld"="Nav_Handheld"; "Tab_Privacy"="Nav_Privacy"; "Tab_Advanced"="Nav_Advanced"; "Tab_Maint"="Nav_Maint"; "Tab_Declutter"="Nav_Declutter" }
        
        if ($txt.Length -eq 0) {
            foreach ($key in $SearchMap.Keys) {
                $tab = $window.FindName($key)
                $controls = Find-Controls-Logical $tab
                foreach ($c in $controls) {
                    # 8.0: a control that is switched off (Expert Mode lock, wrong GPU vendor) stays dimmed -
                    # clearing a search used to bring every one back to full brightness.
                    $c.Opacity = if ($c.IsEnabled) { 1.0 } else { 0.5 }; $c.Effect = $null
                    # 8.0 Black Ice: put back the control's OWN colour (its style's, or what its XAML set), recorded
                    # the first time the search recoloured it. Switch labels follow the switch through the style.
                    if ($script:SearchSaved.ContainsKey($c)) {
                        $v = $script:SearchSaved[$c]
                        if ($v -eq [System.Windows.DependencyProperty]::UnsetValue) { $c.ClearValue([System.Windows.Controls.Control]::ForegroundProperty) } else { $c.Foreground = $v }
                    }
                }
            }
            $script:SearchSaved.Clear()
            foreach ($nb in $SearchMap.Values) { $b = $window.FindName($nb); if ($b) { $b.Opacity = 1.0; $b.Effect = $null } }
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
                if (-not $script:SearchSaved.ContainsKey($c)) { $script:SearchSaved[$c] = $c.ReadLocalValue([System.Windows.Controls.Control]::ForegroundProperty) }
                if ($isMatch) {
                    $tabMatchCount++
                    $c.Opacity = 1.0; $c.Foreground = [System.Windows.Media.Brushes]::White
                    $c.Effect = [System.Windows.Media.Effects.DropShadowEffect]::new()
                    $c.Effect.Color = [System.Windows.Media.Color]::FromRgb(255, 46, 58); $c.Effect.BlurRadius = 12; $c.Effect.ShadowDepth = 0
                } else { $c.Opacity = 0.15; $c.Foreground = [System.Windows.Media.Brushes]::Gray; $c.Effect = $null }
            }
            
            if ($tabName -eq $currentTabName) { $currentTabMatches = $tabMatchCount }
            if ($tabMatchCount -gt $maxMatches) { $maxMatches = $tabMatchCount; $bestTabName = $tabName }

            if ($navBtn) {
                if ($tabMatchCount -gt 0) {
                    $navBtn.Foreground = [System.Windows.Media.Brushes]::White; $navBtn.Opacity = 1.0
                    $navBtn.Effect = [System.Windows.Media.Effects.DropShadowEffect]::new()
                    $navBtn.Effect.Color = [System.Windows.Media.Color]::FromRgb(255, 46, 58); $navBtn.Effect.BlurRadius = 16; $navBtn.Effect.ShadowDepth = 0
                } else { $navBtn.Foreground = [System.Windows.Media.Brushes]::DarkGray; $navBtn.Effect = $null; $navBtn.Opacity = 0.3 }
            }
        }

        if ($currentTabMatches -eq 0 -and $maxMatches -gt 0 -and $bestTabName) {
            $window.FindName("MainTabs").SelectedItem = $window.FindName($bestTabName)
        }
        } catch { try { Write-Diag "Search tick error: $($_.Exception.Message)" "UI" } catch {} }
    })

    $window.FindName("SearchBox").Add_TextChanged({ $script:SearchTimer.Stop(); $script:SearchTimer.Start() })

    # --- ENGINE WATCHDOG ---
    # The engine stamps $SyncHash.LastBeat everywhere it proves it is still moving (loop pass,
    # job dequeue, every task inside a batch). If that stops advancing the engine thread is dead
    # or deadlocked - previously that was completely invisible: the app just sat there looking
    # fine and users killed the process, taking the evidence with them.
    # Runs on the UI thread, so it stays responsive even when the engine is wedged.
    # Threshold is deliberately generous (180s): the app's slowest legitimate operations
    # (DISM ResetBase, CompactOS, the 90s restore-point cap) must never raise a false alarm.
    # This only ever SHOWS A BANNER - it never restarts, cancels, or touches the engine.
    $script:EngineWatchdog = New-Object System.Windows.Threading.DispatcherTimer
    $script:EngineWatchdog.Interval = [TimeSpan]::FromSeconds(15)
    $script:EngineWatchdog.Add_Tick({
        try {
            $banner = $window.FindName("Banner_Engine")
            if (-not $banner) { return }
            $stale = $false; $age = 0
            if ($SyncHash.Running -and $SyncHash.LastBeat) {
                $age = [int]((Get-Date) - $SyncHash.LastBeat).TotalSeconds
                if ($age -ge 180) { $stale = $true }
            }
            $script:EngineStalled = $stale   # 8.0: the title bar's engine light (Update-EngineState)
            if ($stale) {
                $mins = [Math]::Max(1, [int][Math]::Round($age / 60))
                $op = if ($SyncHash.CurrentOp) { "$($SyncHash.CurrentOp)" } else { "unknown" }
                $window.FindName("EngineBannerText").Text = "ENGINE NOT RESPONDING ($mins MIN) - LAST OPERATION: $op"
                if ($banner.Visibility -ne "Visible") {
                    $banner.Visibility = "Visible"
                    try { Write-Diag "WATCHDOG: engine beat stale ${age}s, last op '$op'" "ERROR" } catch {}
                }
            } elseif ($banner.Visibility -eq "Visible") {
                # Beats resumed (it was a long operation after all) - stand down silently.
                $banner.Visibility = "Collapsed"
                try { Write-Diag "WATCHDOG: engine beat resumed; banner cleared" "UI" } catch {}
            }
        } catch {}
    })
    $script:EngineWatchdog.Start()

    # NAVIGATION LOGIC
    $window.FindName("Nav_Auto").Add_Click({ $window.FindName("MainTabs").SelectedIndex = 0; Update-TabUI $this })
    $window.FindName("Nav_System").Add_Click({ $window.FindName("MainTabs").SelectedIndex = 1; Update-TabUI $this })
    $window.FindName("Nav_Gaming").Add_Click({ $window.FindName("MainTabs").SelectedIndex = 2; Update-TabUI $this })
    $window.FindName("Nav_Handheld").Add_Click({ $window.FindName("MainTabs").SelectedIndex = 3; Update-TabUI $this })
    $window.FindName("Nav_Privacy").Add_Click({ $window.FindName("MainTabs").SelectedIndex = 4; Update-TabUI $this })
    $window.FindName("Nav_Advanced").Add_Click({ $window.FindName("MainTabs").SelectedIndex = 5; Update-TabUI $this })
    $window.FindName("Nav_Maint").Add_Click({ $window.FindName("MainTabs").SelectedIndex = 6; Update-TabUI $this })
    # 8.0: Declutter is the LAST TabItem (index 7) so every existing index above stays valid.
    $window.FindName("Nav_Declutter").Add_Click({ $window.FindName("MainTabs").SelectedIndex = 7; Update-TabUI $this })

    # (Tab-change handling lives in the 7.6 block: one SelectedIndex listener, see Register-TabChange.)


    # SMART INITIALIZATION
    
    $window.Add_ContentRendered({ 
        try {
            $tabs = $window.FindName("MainTabs")
            if ($tabs) {
                $tabs.IsEnabled = $false
                $tabs.Opacity = 0.5
            }
            if ($SyncHash.Console) { $SyncHash.Console.Text = "> SYSTEM AUDIT SEQUENCE INITIATED...`n> PLEASE WAIT..." }
            if ($SyncHash.ConsoleLast) { $SyncHash.ConsoleLast.Text = "system audit running - please wait" }

            $SyncHash.JobQueue.Enqueue("INIT")

            # 7.6: restore remembered toggles. Setting IsChecked fires their existing handlers, which
            # apply Expert gating / Touch scaling exactly as a click would. Saves are suppressed until
            # loading finishes ($script:SettingsLoading).
            try {
                if ($script:Settings.ExpertMode) { $window.FindName("Global_ExpertMode").IsChecked = $true }
                if ($script:Settings.TouchMode)  { $window.FindName("Global_TouchMode").IsChecked = $true }
                $window.FindName("Global_SafeMode").IsChecked = [bool]$script:Settings.AutoBackup
            } catch { Log "Could not restore saved toggles: $($_.Exception.Message)" }

            # 7.6: start tab. "smart" = the old fixed behaviour (Handheld on handhelds, else Auto Optimize).
            try {
                $tabOrder = @('Tab_Auto','Tab_System','Tab_Gaming','Tab_Handheld','Tab_Privacy','Tab_Advanced','Tab_Maint','Tab_Declutter')
                $navFor = @{ Tab_Auto='Nav_Auto'; Tab_System='Nav_System'; Tab_Gaming='Nav_Gaming'; Tab_Handheld='Nav_Handheld'; Tab_Privacy='Nav_Privacy'; Tab_Advanced='Nav_Advanced'; Tab_Maint='Nav_Maint'; Tab_Declutter='Nav_Declutter' }
                $smart = if ($SyncHash.IsHandheld) { 'Tab_Handheld' } else { 'Tab_Auto' }
                $start = switch ($script:Settings.StartTab) {
                    'smart' { $smart }
                    'last'  { if ($tabOrder -contains $script:Settings.LastTab) { $script:Settings.LastTab } else { $smart } }
                    default { if ($tabOrder -contains $script:Settings.StartTab) { $script:Settings.StartTab } else { $smart } }
                }
                $window.FindName("MainTabs").SelectedIndex = [array]::IndexOf($tabOrder, $start)
                Update-TabUI ($window.FindName($navFor[$start])); Bind-InfoDojo ($window.FindName($start))
                Update-TabHeader ($window.FindName($start))   # 8.0: SelectedIndex 0 -> 0 raises no tab-change
                if ($SyncHash.IsHandheld) { $SyncHash.JobQueue.Enqueue("LOG_HANDHELD") }
            } catch {}
            $script:SettingsLoading = $false
            Save-CurrentSettings    # first run writes the defaults; every run records the Windows build
            if ($script:Settings._LoadError) { Log "Settings file couldn't be read, so defaults are in use ($($script:Settings._LoadError))." }
            try { Show-UpdatesReminderIfDue } catch { try { Write-Diag "Updates reminder check failed: $($_.Exception.Message)" "ERROR" } catch {} }

            # Known limitation, stated honestly rather than silently misreporting. 8.0 moved every
            # powercfg Check to Get-PowerIndex, which works in any display language. Two Checks still
            # read English command output (Compact OS, Reserved Storage - flagged LocaleText=$true).
            # UI culture, not regional format, decides the language those tools print in.
            try {
                $ui = (Get-UICulture).Name
                if ($ui -and $ui -notlike 'en-*') {
                    Log "NOTE: Windows display language is '$ui'. The Compact OS and Reserved Storage status checks read English command output and may show as not applied. Applying and reverting still work normally."
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
            # Owned WPF box (invariant 2): an ownerless WinForms box can open BEHIND the window.
            $r = [System.Windows.MessageBox]::Show($window,
                "BitLocker is still DECRYPTING your drive ($pct done).`n`nClosing Ronin is OK, but DO NOT restart or shut down the PC until Windows reports decryption is 100% complete (Control Panel -> BitLocker Drive Encryption), or you may hit a BitLocker recovery screen.`n`nClose Ronin anyway?",
                "Decryption In Progress",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Warning)
            if ("$r" -ne "Yes") { $_.Cancel = $true }
        }
    })

    $window.Add_Closed({
        $SyncHash.Running = $false
        try { $EnginePs.Dispose() } catch {}
        try { $WatcherPs.Dispose() } catch {}
        try { $runspacePool.Close(); $runspacePool.Dispose() } catch {}
        Stop-Transcript -ErrorAction SilentlyContinue
    })

    # 8.0: two checkboxes that drive the SAME Windows setting ($RoninDB Twin) must move together.
    # The audit always shows them identically, so a batch with one ticked and one unticked means the
    # user just changed ONE of them - and the other task then undid it in the same batch: ticking
    # "Disable MPO" alone applied it, verified it, then the unticked "Legacy Flip Mode" next to it
    # reverted the very same value (summary: success; result: off). If the pair is on now the
    # change was an untick (both revert), otherwise a tick (both apply). Edits the tasks in place.
    function Resolve-TwinTasks ($Tasks, $Status) {
        foreach ($t in @($Tasks)) {
            if (-not $RoninDB.ContainsKey($t.Key)) { continue }
            $tw = $RoninDB[$t.Key].Twin
            if (-not $tw) { continue }
            foreach ($u in @($Tasks)) {
                if ($u.Key -ne $tw -or $u.Action -eq $t.Action) { continue }
                $on = [bool]($Status -and $Status.ContainsKey($t.Key) -and "$($Status[$t.Key])" -eq "True")
                $want = if ($on) { "Revert" } else { "Apply" }
                $t.Action = $want; $u.Action = $want
            }
        }
    }

    function Get-Tasks ($Prefix) {
        $list = [System.Collections.ArrayList]::new()
        $allControls = Find-Controls-Logical $window | Where-Object { $_.Name -and $_.Name.StartsWith($Prefix) }
        foreach ($c in $allControls) {
            if ($c.IsEnabled) {
                if ($c -is [System.Windows.Controls.CheckBox]) { [void]$list.Add([PSCustomObject]@{Key=$c.Name; Action=if($c.IsChecked){"Apply"}else{"Revert"}}) }
                if ($c -is [System.Windows.Controls.ComboBox]) { [void]$list.Add([PSCustomObject]@{Key=$c.Name; Action="Apply"; Value=$c.SelectedIndex}) }
            }
        }
        Resolve-TwinTasks $list $SyncHash.StatusCache
        return ,$list
    }

    # --- SETTINGS (7.6) ---
    # C:\ProgramData\Ronin\settings.json, read and written on the UI thread only. The engine never
    # touches the file; values it needs are copied into $SyncHash.Settings. A missing or corrupt file
    # means defaults - never a crash, never a half-written file (temp file + move).
    function Get-RoninSettingDefaults {
        return [ordered]@{
            ExpertMode = $false; TouchMode = $false; AutoBackup = $true
            StartTab = 'smart'; LastTab = ''
            ResetAlert = $true; PreviewBeforeApply = $true
            ExplorerRestart = 'auto'; LastOsBuild = ''; LastRonin = ''
            UpdatesReminderAfter = ''
        }
    }

    # One place for the path, so tests can point it at a temp file instead of the real settings.
    if (-not $script:SettingsPath) { $script:SettingsPath = "$env:ProgramData\Ronin\settings.json" }

    function Get-RoninSettings ($Path = $script:SettingsPath) {
        $def = Get-RoninSettingDefaults
        $s = @{}; foreach ($k in $def.Keys) { $s[$k] = $def[$k] }
        if (-not (Test-Path -LiteralPath $Path)) { return $s }
        try {
            $j = [System.IO.File]::ReadAllText($Path) | ConvertFrom-Json -ErrorAction Stop
            foreach ($p in $j.PSObject.Properties) {
                if (-not $def.Contains($p.Name) -or $null -eq $p.Value) { continue }
                # Type-checked: a hand-edited "ExpertMode": "yes" must not become truthy by accident.
                if ($def[$p.Name] -is [bool]) { if ($p.Value -is [bool]) { $s[$p.Name] = $p.Value } }
                else { $s[$p.Name] = "$($p.Value)" }
            }
        } catch { $s['_LoadError'] = $_.Exception.Message }
        if ($s.ExplorerRestart -notin @('auto','ask')) { $s.ExplorerRestart = 'auto' }
        if ($s.StartTab -notin @('smart','last','Tab_Auto','Tab_System','Tab_Gaming','Tab_Handheld','Tab_Privacy','Tab_Advanced','Tab_Maint','Tab_Declutter')) { $s.StartTab = 'smart' }
        return $s
    }

    function Save-RoninSettings ($Settings, $Path = $script:SettingsPath) {
        try {
            $o = [ordered]@{}
            foreach ($k in (Get-RoninSettingDefaults).Keys) { $o[$k] = $Settings[$k] }
            $dir = Split-Path -Parent $Path
            if (-not (Test-Path -LiteralPath $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
            $tmp = "$Path.tmp"
            [System.IO.File]::WriteAllText($tmp, ($o | ConvertTo-Json), (New-Object System.Text.UTF8Encoding($false)))
            Move-Item -LiteralPath $tmp -Destination $Path -Force
            return $true
        } catch {
            try { Write-Diag "Settings save failed: $($_.Exception.Message)" "ERROR" } catch {}
            return $false
        }
    }

    # --- BATCH PREVIEW (7.6) ---
    # What a batch will actually change, computed from the last audit. Mirrors the engine's own skip
    # rules exactly (same string comparisons) so the preview never promises a different count than
    # the engine then delivers:
    #   Apply  -> skipped when "$status" -eq "$target" (target = combo value, else $true);
    #             combos with a negative index are skipped as "unselected".
    #   Revert -> skipped when "$status" -eq "False".
    # A tweak with no audit result is counted as a change (the engine will run it).
    function Get-BatchPreview ($Tasks, $Status) {
        $change = New-Object System.Collections.Generic.List[string]
        $same = 0; $reboot = 0
        foreach ($t in @($Tasks)) {
            if (-not $t -or -not $t.Key) { continue }
            $has = ($Status -and $Status.ContainsKey($t.Key))
            $st = if ($has) { "$($Status[$t.Key])" } else { $null }
            if ($t.Action -eq "Apply") {
                $target = if ($null -ne $t.Value) { $t.Value } else { $true }
                if ($target -is [int] -and $target -lt 0) { $same++; continue }
                $will = (-not $has) -or ($st -ne "$target")
            } else {
                $will = (-not $has) -or ($st -ne "False")
            }
            if ($will) {
                # 8.0: a Twin pair is ONE setting - count it once ("1 change", not 2).
                if ($RoninDB.ContainsKey($t.Key) -and $RoninDB[$t.Key].Twin -and $change.Contains("$($RoninDB[$t.Key].Twin)")) { continue }
                $change.Add($t.Key)
                if ($RoninDB.ContainsKey($t.Key) -and $RoninDB[$t.Key].Reboot) { $reboot++ }
            } else { $same++ }
        }
        return @{ Change = $change.ToArray(); Same = $same; Reboot = $reboot }
    }

    # Builds the "Reset All" revert batch. Pure function of its inputs (unit-tested):
    #   $Applied = names from the applied ledger (Get-AppliedMarks) - tweaks Ronin changed here.
    #   $Status  = last audit results (key -> Check result) from $SyncHash.StatusCache.
    # 1) every ledger entry that has a Revert;
    # 2) LEGACY fallback for PCs tweaked by Ronin before the ledger existed: tweaks the audit shows as
    #    applied, EXCEPT UserState=$true ones - settings a person (or Windows itself) commonly sets, where
    #    "applied" proves nothing about Ronin (WSL, Hyper-V, dark mode, Game Mode...).
    #    Combo tweaks (int status) are skipped: there is no "off" to revert them to without a record.
    function Get-ResetAllBatch ($Applied, $Status) {
        $list = [System.Collections.ArrayList]::new()
        $seen = @{}
        foreach ($k in @($Applied)) {
            if ($k -and $RoninDB.ContainsKey($k) -and $RoninDB[$k].Revert -and -not $seen.ContainsKey($k)) {
                [void]$list.Add([PSCustomObject]@{ Key = $k; Action = "Revert" }); $seen[$k] = $true
            }
        }
        if ($Status) {
            foreach ($k in @($Status.Keys)) {
                if ($seen.ContainsKey($k) -or -not $RoninDB.ContainsKey($k)) { continue }
                $e = $RoninDB[$k]
                if (-not $e.Revert -or $e.UserState) { continue }
                $v = $Status[$k]
                if (($v -is [bool] -and $v) -or "$v" -eq "True") {
                    [void]$list.Add([PSCustomObject]@{ Key = $k; Action = "Revert" }); $seen[$k] = $true
                }
            }
        }
        return ,$list
    }

    # --- SINGLE JOB-SUBMISSION CHOKE POINT ---
    # Every UI button that hands work to the engine goes through here. Without it a double-click
    # queued the same job twice: the 7.5.0 test session logged two DEBLOAT_SCAN jobs 1s apart and
    # opened two Debloat Centers; the same double-click on Full Repair or Reset All ran it twice.
    # Reuses the engine's own liveness field ($SyncHash.CurrentOp) - no second source of truth.
    # Drops are LOGGED, never silent, so a "nothing happened" report is explainable from the log.
    function Submit-RoninJob ($Job) {
        $isBatch = ($Job -is [System.Collections.IEnumerable] -and $Job -isnot [string])
        $name = if ($isBatch) { "BATCH" } else { "$Job" }
        $cur = "$($SyncHash.CurrentOp)"
        # 8.0: CurrentJob names the running job even while CurrentOp shows its progress
        # ("Install 7zip.7zip (1/3)") - a second INSTALL / REMOVE click used to slip through.
        $curJob = "$($SyncHash.CurrentJob)"
        $busy = $false
        if ($isBatch) {
            # CurrentOp reads "BATCH[n items]" at dequeue, then "Apply/Revert <Key> (i/n)" per task.
            if ($cur -match '^(BATCH|Apply |Revert )' -or $curJob -like 'BATCH*') { $busy = $true }
            foreach ($q in $SyncHash.JobQueue.ToArray()) { if ($q -is [System.Collections.IEnumerable] -and $q -isnot [string]) { $busy = $true } }
        } else {
            if ($cur -eq $name -or $curJob -eq $name) { $busy = $true }
            foreach ($q in $SyncHash.JobQueue.ToArray()) { if ($q -is [string] -and $q -eq $name) { $busy = $true } }
            # The scan job finishes in under a second, but its dialog stays open - the second
            # click in the logged incident arrived AFTER the first job had already completed.
            if ($name -eq "DEBLOAT_SCAN" -and $SyncHash.DebloatOpen) { $busy = $true }
        }
        if ($busy) {
            try { Log "Ignored duplicate request: $name (already running or queued)." } catch {}
            return
        }
        if ($isBatch) { Confirm-RiskyTasks $Job }
        $SyncHash.JobQueue.Enqueue($Job)
    }

    # Confirmations for destructive tweaks happen HERE, on the UI thread, before the job is queued -
    # never from inside a tweak on the engine thread (a modal shown from the engine via
    # Dispatcher.Invoke is the pattern that froze the Debloat Center). Owned WPF MessageBox so it
    # can't open behind the main window. A "No" removes just that tweak from the batch.
    function Confirm-RiskyTasks ($Batch) {
        $SyncHash.EncryptionConfirmed = $false
        $enc = $null
        foreach ($t in $Batch) { if ($t.Key -eq 'HH_Encryption' -and $t.Action -eq 'Apply') { $enc = $t } }
        if (-not $enc) { return }
        # Cached BitLocker status (true = already decrypted): no point warning about a no-op.
        if ($SyncHash.SlowCheckCache -and $SyncHash.SlowCheckCache['HH_Encryption'] -eq $true) { return }
        $msg = "Decrypting your system drive runs silently in the background and can take a long time.`n`n" +
               "If you restart BEFORE it reaches 100%, you will get a BitLocker Recovery screen (a black screen on handhelds).`n`n" +
               "Begin decrypting drive C: now?"
        $ans = [System.Windows.MessageBox]::Show($window, $msg, "Project Ronin - BitLocker Warning", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
        if ("$ans" -eq "Yes") { $SyncHash.EncryptionConfirmed = $true }
        else {
            [void]$Batch.Remove($enc)
            try { Log "Drive decryption skipped (not confirmed). The rest of the batch will still run." } catch {}
        }
    }

    $window.FindName("Btn_RestartExp").Add_Click({ Submit-RoninJob ("RESTART_EXPLORER") })
    $window.FindName("Btn_Debloat").Add_Click({ Submit-RoninJob ("DEBLOAT_SCAN") })
    $window.FindName("Btn_Analyze").Add_Click({ Submit-RoninJob ("AUDIT_SYSTEM") })
    # Every Apply button goes through Invoke-ApplyButton (7.6 two-step preview).
    $window.FindName("Btn_RunSystem").Add_Click({ Invoke-ApplyButton $this (Get-Tasks "Sys_") })
    $window.FindName("Btn_RunGaming").Add_Click({ Invoke-ApplyButton $this (Get-Tasks "Game_") })
    $window.FindName("Btn_RunHandheld").Add_Click({ Invoke-ApplyButton $this (Get-Tasks "HH_") })
    $window.FindName("Btn_RunPrivacy").Add_Click({ Invoke-ApplyButton $this (Get-Tasks "Priv_") })
    $window.FindName("Btn_RunAdvanced").Add_Click({ Invoke-ApplyButton $this (Get-Tasks "Adv_") })
    
    # 8.0: driven by $AutoMap - the same map the audit uses to tick these boxes and the health score
    # uses to rank. This used to be a second, hand-copied 25-entry switch; a box added to one and not
    # the other would show its status but be silently skipped by AUTO OPTIMIZE.
    function Get-AutoTasks {
        $j = [System.Collections.ArrayList]::new()
        $byBox = @{}; foreach ($k in $AutoMap.Keys) { $byBox[$AutoMap[$k]] = $k }
        $controls = Find-Controls-Logical ($window.FindName("Tab_Auto"))   # assign, never pipe a function's array
        foreach ($c in @($controls)) {
            if ($c -is [System.Windows.Controls.CheckBox] -and $c.Name -and $byBox.ContainsKey($c.Name)) {
                $action = if ($c.IsChecked) { "Apply" } else { "Revert" }
                [void]$j.Add([PSCustomObject]@{ Key = $byBox[$c.Name]; Action = $action })
            }
        }
        return ,$j
    }
    $window.FindName("Btn_RunAuto").Add_Click({ Invoke-ApplyButton $this (Get-AutoTasks) })

    # --- BUG REPORT BUNDLER ---
    # Collects every Ronin log into ONE zip on the Desktop so a user can attach it to a report.
    # Deliberately runs entirely on the UI thread with plain .NET: no JobQueue, no engine
    # helpers, no Dispatcher round-trip. The whole point is that it still works when the engine
    # is dead or deadlocked, which is exactly when someone needs to send logs.
    # Nothing is uploaded - the file is written locally and left for the user to send.
    function New-RoninBugReport {
        $srcDir = "$env:ProgramData\Ronin"
        $stamp  = Get-Date -Format "yyyyMMdd-HHmmss"
        $dest   = Join-Path ([Environment]::GetFolderPath('Desktop')) "Ronin_BugReport_$stamp.zip"
        # These entry names must land at the ZIP ROOT exactly as spelled - ronin-triage matches
        # them by name. Ronin_UI_Errors.txt in particular used to be written and then collected
        # by nothing, so WPF crashes left their evidence behind.
        $wanted = @("Ronin_Diagnostic.log","Ronin_CrashLog.txt","Ronin.log","Ronin_UI_Errors.txt","Ronin_StateReport.txt","Ronin_Snapshots.json","settings.json")
        $maxBytes = 5MB   # logs never rotate; without a cap an old install could produce an unsendable zip

        Add-Type -AssemblyName System.IO.Compression -ErrorAction SilentlyContinue
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

        $included = @(); $truncated = @(); $missing = @()
        $zipStream = [System.IO.File]::Open($dest, [System.IO.FileMode]::Create)
        $zip = New-Object System.IO.Compression.ZipArchive($zipStream, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            foreach ($name in $wanted) {
                $p = Join-Path $srcDir $name
                if (-not [System.IO.File]::Exists($p)) { $missing += $name; continue }
                # FileShare::ReadWrite is REQUIRED. Start-Transcript holds Ronin_CrashLog.txt open
                # for the entire session, and the logs are appended to live - a default open (or
                # Copy-Item) fails with "the process cannot access the file".
                $fs = New-Object System.IO.FileStream($p, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                try {
                    if ($fs.Length -gt $maxBytes) { $fs.Position = $fs.Length - $maxBytes; $truncated += $name }
                    $entry = $zip.CreateEntry($name)
                    $es = $entry.Open()
                    try { $fs.CopyTo($es) } finally { $es.Dispose() }
                    $included += $name
                } finally { $fs.Dispose() }
            }

            # Header entry: identifies the bundle even when every log happens to be empty.
            $beat = "unknown"; $op = "unknown"
            try {
                if ($SyncHash.LastBeat) {
                    $age = [int]((Get-Date) - $SyncHash.LastBeat).TotalSeconds
                    $beat = "$($SyncHash.LastBeat.ToString('yyyy-MM-dd HH:mm:ss')) ($age s ago)"
                }
                if ($SyncHash.CurrentOp) { $op = "$($SyncHash.CurrentOp)" }
            } catch {}
            $lines = @(
                "PROJECT RONIN - BUG REPORT BUNDLE",
                "Created        : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
                "Ronin Version  : $Version",
                "OS             : $([System.Environment]::OSVersion.VersionString)",
                "PowerShell     : $($PSVersionTable.PSVersion)",
                "Culture        : $((Get-Culture).Name)",
                "Engine LastBeat: $beat",
                "Engine LastOp  : $op",
                "",
                "Included  : $($included -join ', ')",
                "Missing   : $(if($missing){$missing -join ', '}else{'none'})",
                "Truncated : $(if($truncated){"$($truncated -join ', ') (kept the most recent 5 MB of each)"}else{'none'})",
                "",
                "Nothing here was uploaded anywhere. Attach this zip to your bug report."
            )
            $hdr = $zip.CreateEntry("BugReport.txt")
            $hs = $hdr.Open()
            try {
                $sw = New-Object System.IO.StreamWriter($hs)
                try { foreach ($l in $lines) { $sw.WriteLine($l) } } finally { $sw.Dispose() }
            } finally { $hs.Dispose() }
        } finally {
            $zip.Dispose(); $zipStream.Dispose()
        }
        return $dest
    }

    # Shared by the Maintenance button and the watchdog banner button.
    $script:SaveBugReport = {
        try {
            $path = New-RoninBugReport
            $sizeKb = [Math]::Round((Get-Item $path).Length / 1KB, 1)
            try { Log "Bug report saved: $path ($sizeKb KB)" } catch {}
            # /select, needs the path as one token; Start-Process splits on spaces otherwise.
            try { Start-Process "explorer.exe" -ArgumentList "/select,`"$path`"" } catch {}
            [System.Windows.MessageBox]::Show($window, "Bug report saved to your Desktop:`n`n$(Split-Path $path -Leaf)  ($sizeKb KB)`n`nNothing was uploaded. Attach this file to your bug report.", "Project Ronin - Bug Report") | Out-Null
        } catch {
            try { Write-Diag "Bug report failed: $($_.Exception.Message)" "ERROR" } catch {}
            [System.Windows.MessageBox]::Show($window, "Could not save the bug report:`n`n$($_.Exception.Message)`n`nYou can still zip C:\ProgramData\Ronin by hand.", "Project Ronin - Bug Report") | Out-Null
        }
    }
    $window.FindName("Btn_BugReport").Add_Click($script:SaveBugReport)
    $window.FindName("Btn_EngineBugReport").Add_Click($script:SaveBugReport)

    # =====================================================================================
    # 7.6 - SETTINGS, APPLY PREVIEW, RESET ALERT, CHANGES LIST. All UI-thread code.
    # The engine only ever reads $SyncHash.Settings and sets flags/versions; it never calls
    # into anything here (scriptblocks from the engine runspace must not run on the UI thread).
    # =====================================================================================
    $script:Settings = Get-RoninSettings
    $SyncHash.Settings = [hashtable]::Synchronized(@{})
    $SyncHash.LedgerVersion = 0     # bumped by Add-/Remove-AppliedMark; polled by the UI
    foreach ($sk in @($script:Settings.Keys)) { $SyncHash.Settings[$sk] = $script:Settings[$sk] }
    $script:SettingsLoading = $true     # suppress saves while settings are being applied to controls

    # Every 7.6 UI entry point runs inside this. A bug in a handler must never again break tab
    # navigation (the 7.6.0 Maintenance-tab bug threw out of a SelectionChanged handler and aborted
    # the nav click half-way). The full error goes to the diagnostic log; the console gets one line.
    # test-ui.ps1 fails if anything lands here during its run, so this can't hide bugs from tests.
    function Invoke-UiSafe ($Where, [scriptblock]$Action) {
        # 8.0: remember the last UI action, so the engine's UI-thread watchdog can name it if the
        # window stops responding (the poll tick is excluded - it would mask the real culprit).
        if ($Where -ne 'UiPollTimer Tick') { $SyncHash.UiOp = "$Where"; $SyncHash.UiOpAt = Get-Date }
        try { & $Action }
        catch {
            try { Write-Diag "UI ERROR in ${Where}: $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))" "ERROR" } catch {}
            try { Log "Something went wrong in $Where - details are in the diagnostic log (Settings > Save bug report)." } catch {}
        }
    }

    function Save-CurrentSettings {
        if ($script:SettingsLoading) { return }
        foreach ($sk in @($script:Settings.Keys)) { $SyncHash.Settings[$sk] = $script:Settings[$sk] }
        [void](Save-RoninSettings $script:Settings)
    }

    # --- remembered toggles: save whenever the user flips one ---
    # One shared handler; the sender says which toggle it was, so no per-toggle closure is needed.
    $script:ToggleSettingKey = @{ Global_ExpertMode = 'ExpertMode'; Global_TouchMode = 'TouchMode'; Global_SafeMode = 'AutoBackup' }
    $script:ToggleSaver = { param($s, $e) $k = $script:ToggleSettingKey[$s.Name]; if ($k) { $script:Settings[$k] = [bool]$s.IsChecked; Save-CurrentSettings } }
    foreach ($tn in @($script:ToggleSettingKey.Keys)) {
        $tog = $window.FindName($tn)
        if ($tog) { $tog.Add_Checked($script:ToggleSaver); $tog.Add_Unchecked($script:ToggleSaver) }
    }
    # --- THE tab-change listener (one, for everything that reacts to switching tabs) ---
    # Listens to the TabControl's own SelectedIndex property, NOT the routed SelectionChanged event.
    # Routed handlers on the tab control also fire for every checkbox/combo event bubbling up from
    # inside the tabs - including the ~100 the engine's startup audit raises while syncing the boxes
    # from inside its Dispatcher.Invoke. A UI-runspace PowerShell handler called from there costs
    # ~265 ms (measured: 80 calls = 21 s), which is what made 7.6.0's first audit take 30 s instead
    # of 7. This listener fires only when the TAB actually changes. ronin-build lints against
    # re-adding routed handlers to MainTabs.
    $script:OnTabChanged = [System.EventHandler]{ Invoke-UiSafe 'Tab change' {
        $sel = $window.FindName("MainTabs").SelectedItem
        if (-not $sel) { return }
        $SyncHash.ActiveTab = $sel.Name
        Bind-InfoDojo $sel
        Update-TabHeader $sel   # 8.0 Black Ice: shared header, counters, status bar ~/tab
        if ($window.FindName("SearchBox").Text.Length -gt 0) { $script:SearchTimer.Stop(); $script:SearchTimer.Start() }
        else {
            $btnName = switch ($SyncHash.ActiveTab) {
                "Tab_Auto" { "Nav_Auto" }; "Tab_System" { "Nav_System" }; "Tab_Gaming" { "Nav_Gaming" }
                "Tab_Handheld" { "Nav_Handheld" }; "Tab_Privacy" { "Nav_Privacy" }; "Tab_Advanced" { "Nav_Advanced" }
                "Tab_Maint" { "Nav_Maint" }; "Tab_Declutter" { "Nav_Declutter" }
            }
            if ($btnName) { Update-TabUI ($window.FindName($btnName)) }
        }
        if ($script:ApplyOriginal -and $script:ApplyOriginal.Count) { Reset-ApplyButtons }   # a preview belongs to its tab
        if ($sel.Name -eq "Tab_Maint") { Update-ChangesList }
        if ($sel.Name -eq "Tab_Declutter") { Update-WuStatus; $script:LastWuLedgerSeen = $SyncHash.LedgerVersion }
        $script:Settings.LastTab = $sel.Name; Save-CurrentSettings
        [System.GC]::Collect()
    } }
    [System.ComponentModel.DependencyPropertyDescriptor]::FromProperty([System.Windows.Controls.Primitives.Selector]::SelectedIndexProperty, [System.Windows.Controls.TabControl]).AddValueChanged($window.FindName("MainTabs"), $script:OnTabChanged)

    # --- two-step Apply (preview) ---
    # The timer only clears the 2 s "NOTHING TO CHANGE" flash; an armed preview has no timeout (see Invoke-ApplyButton).
    $script:ApplyOriginal = @{}
    $script:ApplyDisarmTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:ApplyDisarmTimer.Interval = [TimeSpan]::FromSeconds(2)
    $script:ApplyDisarmTimer.Add_Tick({ Invoke-UiSafe 'ApplyDisarmTimer Tick' { Reset-ApplyButtons } })

    function Reset-ApplyButtons {
        $script:ApplyDisarmTimer.Stop()
        foreach ($n in @($script:ApplyOriginal.Keys)) {
            $b = $window.FindName($n)
            if ($b) { $b.Content = $script:ApplyOriginal[$n].Content; $b.Background = $script:ApplyOriginal[$n].Background; $b.Tag = $null }
        }
        $script:ApplyOriginal.Clear()
        try { Update-TabCounts } catch {}   # 8.0: the restored label may be a stale "APPLY N CHANGES"
    }

    # What a batch would do, as one comparable string. The confirm click only applies if this still
    # matches what was previewed - replacing the per-checkbox "disarm" listeners that slowed startup.
    function Get-BatchSignature ($Batch) {
        $parts = foreach ($t in @($Batch)) { if ($t -and $t.Key) { "$($t.Key)|$($t.Action)|$($t.Value)" } }
        return (@($parts) | Sort-Object) -join ';'
    }

    function Invoke-ApplyButton ($Btn, $Batch) { Invoke-UiSafe 'Invoke-ApplyButton' {
        if (-not $script:Settings.PreviewBeforeApply) { Submit-RoninJob $Batch; return }
        $sig = Get-BatchSignature $Batch
        if ($Btn.Tag -eq 'ARMED') {
            if ($script:ApplyOriginal.ContainsKey($Btn.Name) -and $script:ApplyOriginal[$Btn.Name].Sig -eq $sig) {
                Reset-ApplyButtons; Submit-RoninJob $Batch; return
            }
            # Ticked or unticked something since the preview: never apply a batch the user didn't see.
            Log "Your selection changed since the preview - here is the updated one."
        }
        Reset-ApplyButtons
        $p = Get-BatchPreview $Batch $SyncHash.StatusCache
        $script:ApplyOriginal[$Btn.Name] = @{ Content = $Btn.Content; Background = $Btn.Background; Sig = $sig }
        if ($p.Change.Count -eq 0) {
            $Btn.Content = "NOTHING TO CHANGE"; $Btn.Tag = 'FLASH'
            Log "Preview: nothing to change - all $($p.Same) setting(s) on this tab are already how you've set them."
            $script:ApplyDisarmTimer.Interval = [TimeSpan]::FromSeconds(2); $script:ApplyDisarmTimer.Start()
            return
        }
        $n = $p.Change.Count
        # 8.0.0 tester: "the shade of red is misleading - I hit apply and just walked away". The confirm used to be
        # a darker red that disarmed after 15 s, so it looked like Apply had hung. Now: amber (Black Ice's
        # "waiting on you"), says what to do, and WAITS - until it's clicked, the tab changes, a switch is clicked,
        # DISCARD, or the preview setting changes. Safe to wait: the confirm only applies the batch it previewed.
        # (Must fit the Gaming button's 250 px: "CLICK AGAIN TO APPLY 15 CHANGES" didn't.)
        $Btn.Content = if ($n -eq 1) { "CLICK AGAIN: APPLY 1 CHANGE" } else { "CLICK AGAIN: APPLY $n CHANGES" }
        $Btn.Background = $script:BrushAmber
        $Btn.Tag = 'ARMED'
        # Amber already says "pending"; the queued stripes would run into the label on the 250 px Gaming button.
        try { [void]$Btn.ApplyTemplate(); $hz = $Btn.Template.FindName("Hazard", $Btn); if ($hz) { $hz.Visibility = "Collapsed" } } catch {}
        $rb = if ($p.Reboot -gt 0) { ", $($p.Reboot) need a reboot" } else { "" }
        Log "Preview: $n will change, $($p.Same) already set$rb. Click again to confirm (the amber button): $($p.Change -join ', ')"
    } }

    # (No checkbox/combo listeners for disarming: they sat in the startup audit's path and cost ~265 ms
    # per event. A stale preview is caught at the confirm click instead - see Invoke-ApplyButton.)

    # --- settings panel ---
    function Show-SettingsPanel { Invoke-UiSafe 'Show-SettingsPanel' {
        $script:SettingsLoading = $true
        foreach ($it in $window.FindName("Set_StartTab").Items) { if ("$($it.Tag)" -eq $script:Settings.StartTab) { $window.FindName("Set_StartTab").SelectedItem = $it } }
        foreach ($it in $window.FindName("Set_ExplorerRestart").Items) { if ("$($it.Tag)" -eq $script:Settings.ExplorerRestart) { $window.FindName("Set_ExplorerRestart").SelectedItem = $it } }
        $window.FindName("Set_ResetAlert").IsChecked = [bool]$script:Settings.ResetAlert
        $window.FindName("Set_Preview").IsChecked = [bool]$script:Settings.PreviewBeforeApply
        $window.FindName("Txt_SettingsPath").Text = "Saved in $script:SettingsPath"
        $script:SettingsLoading = $false
        $window.FindName("SettingsOverlay").Visibility = "Visible"
        # One short slide-in, answering the click. Skipped when Windows animations are turned off.
        $slide = $window.FindName("SettingsPanel").RenderTransform
        if ([System.Windows.SystemParameters]::ClientAreaAnimation) {
            $anim = New-Object System.Windows.Media.Animation.DoubleAnimation(380, 0, [TimeSpan]::FromMilliseconds(160))
            $anim.EasingFunction = New-Object System.Windows.Media.Animation.CubicEase
            $slide.BeginAnimation([System.Windows.Media.TranslateTransform]::XProperty, $anim)
        } else { $slide.X = 0 }
    } }
    function Hide-SettingsPanel {
        $window.FindName("SettingsOverlay").Visibility = "Collapsed"
        $r = $window.FindName("Btn_SetReset"); if ($r.Tag -eq 'ARMED') { $r.Tag = $null; $r.Content = "RESET RONIN'S SETTINGS" }
    }
    $window.FindName("Btn_Settings").Add_Click({ Invoke-UiSafe 'Btn_Settings Click' { if ($window.FindName("SettingsOverlay").Visibility -eq "Visible") { Hide-SettingsPanel } else { Show-SettingsPanel } } })
    $window.FindName("Btn_SettingsClose").Add_Click({ Invoke-UiSafe 'Btn_SettingsClose Click' { Hide-SettingsPanel } })
    $window.FindName("SettingsScrim").Add_MouseLeftButtonDown({ Invoke-UiSafe 'SettingsScrim MouseLeftButtonDown' { Hide-SettingsPanel } })
    # Esc closes the settings panel, then the log; 8.0: Ctrl+K jumps to search, F5 runs the audit (the hints the
    # title bar and the audit button show).
    $window.Add_PreviewKeyDown({ param($s, $e) Invoke-UiSafe 'window PreviewKeyDown' {
        if ($e.Key -eq 'Escape' -and $window.FindName("SettingsOverlay").Visibility -eq "Visible") { Hide-SettingsPanel; $e.Handled = $true }
        elseif ($e.Key -eq 'Escape' -and $window.FindName("LogPanel").Visibility -eq "Visible") { Set-LogPanel $false; $e.Handled = $true }
        elseif ($e.Key -eq 'K' -and ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control)) { $sb = $window.FindName("SearchBox"); [void]$sb.Focus(); $sb.SelectAll(); $e.Handled = $true }
        elseif ($e.Key -eq 'F5') { Submit-RoninJob ("AUDIT_SYSTEM"); $e.Handled = $true }
    } })

    $window.FindName("Set_StartTab").Add_SelectionChanged({ Invoke-UiSafe 'Set_StartTab SelectionChanged' { $it = $window.FindName("Set_StartTab").SelectedItem; if ($it) { $script:Settings.StartTab = "$($it.Tag)"; Save-CurrentSettings } } })
    $window.FindName("Set_ExplorerRestart").Add_SelectionChanged({ Invoke-UiSafe 'Set_ExplorerRestart SelectionChanged' { $it = $window.FindName("Set_ExplorerRestart").SelectedItem; if ($it) { $script:Settings.ExplorerRestart = "$($it.Tag)"; Save-CurrentSettings } } })
    $window.FindName("Set_ResetAlert").Add_Click({ Invoke-UiSafe 'Set_ResetAlert Click' { $script:Settings.ResetAlert = [bool]$window.FindName("Set_ResetAlert").IsChecked; Save-CurrentSettings } })
    $window.FindName("Set_Preview").Add_Click({ Invoke-UiSafe 'Set_Preview Click' { $script:Settings.PreviewBeforeApply = [bool]$window.FindName("Set_Preview").IsChecked; Reset-ApplyButtons; Save-CurrentSettings } })
    $window.FindName("Btn_SetBugReport").Add_Click($script:SaveBugReport)
    # Direct, not via the engine: must work even if the engine has stopped responding.
    $window.FindName("Btn_SetOpenLogs").Add_Click({ Invoke-UiSafe 'Btn_SetOpenLogs Click' { try { Start-Process "explorer.exe" -ArgumentList "`"$env:ProgramData\Ronin`"" } catch {} } })
    # Two-step, like Debloat's Remove: first click arms, second resets. Preferences only - never tweaks.
    $window.FindName("Btn_SetReset").Add_Click({ Invoke-UiSafe 'Btn_SetReset Click' {
        $r = $window.FindName("Btn_SetReset")
        if ($r.Tag -ne 'ARMED') { $r.Tag = 'ARMED'; $r.Content = "CONFIRM RESET"; return }
        $r.Tag = $null; $r.Content = "RESET RONIN'S SETTINGS"
        try { Remove-Item -LiteralPath $script:SettingsPath -Force -ErrorAction SilentlyContinue } catch {}
        $keepBuild = $script:Settings.LastOsBuild; $keepRonin = $script:Settings.LastRonin
        $script:Settings = Get-RoninSettings
        $script:Settings.LastOsBuild = $keepBuild; $script:Settings.LastRonin = $keepRonin
        $window.FindName("Global_ExpertMode").IsChecked = $false
        $window.FindName("Global_TouchMode").IsChecked = $false
        $window.FindName("Global_SafeMode").IsChecked = $true
        Save-CurrentSettings
        Show-SettingsPanel
        Log "Ronin's settings were reset to defaults. Your tweaks were not changed."
    } })

    # --- reset alert (shown by the engine after the startup audit; acted on here) ---
    $window.FindName("Btn_ResetReapply").Add_Click({ Invoke-UiSafe 'Btn_ResetReapply Click' {
        $batch = [System.Collections.ArrayList]::new()
        foreach ($k in @($SyncHash.UndoneTweaks)) { if ($k) { [void]$batch.Add([PSCustomObject]@{ Key = $k; Action = "Apply" }) } }
        $window.FindName("Banner_Reset").Visibility = "Collapsed"
        if ($batch.Count) { Log "Re-applying $($batch.Count) tweak(s) that were undone."; Submit-RoninJob $batch }
    } })
    $window.FindName("Btn_ResetShow").Add_Click({ Invoke-UiSafe 'Btn_ResetShow Click' {
        Log "Undone since Ronin applied them:"
        foreach ($k in @($SyncHash.UndoneTweaks)) { $c = $window.FindName($k); Log ("  - " + $(if ($c -and $c.Content) { "$($c.Content)" } else { $k })) }
        $window.FindName("MainTabs").SelectedIndex = 6; Update-TabUI ($window.FindName("Nav_Maint"))
        Update-ChangesList
    } })
    $window.FindName("Btn_ResetKeep").Add_Click({ Invoke-UiSafe 'Btn_ResetKeep Click' {
        $n = 0
        foreach ($k in @($SyncHash.UndoneTweaks)) { if ($k) { Remove-AppliedMark $k; $n++ } }
        $SyncHash.UndoneTweaks = @()
        $window.FindName("Banner_Reset").Visibility = "Collapsed"
        Log "Kept your way: Ronin forgot $n tweak(s) and won't mention them again."
        Update-ChangesList
    } })
    $window.FindName("Btn_ExplorerNow").Add_Click({ Invoke-UiSafe 'Btn_ExplorerNow Click' { $window.FindName("Banner_Explorer").Visibility = "Collapsed"; Submit-RoninJob ("RESTART_EXPLORER") } })
    $window.FindName("Btn_ExplorerLater").Add_Click({ Invoke-UiSafe 'Btn_ExplorerLater Click' { $window.FindName("Banner_Explorer").Visibility = "Collapsed"; Log "Explorer not restarted: the taskbar/Start/Explorer changes will show after you next sign in." } })

    # --- "Changes made by Ronin" list (Maintenance) ---
    $script:UndoRowHandler = {
        param($s, $e) Invoke-UiSafe 'Changes list Undo' {
        $k = "$($s.Tag)"; if (-not $k) { return }
        $s.IsEnabled = $false; $s.Content = "QUEUED"
        $b = [System.Collections.ArrayList]::new(); [void]$b.Add([PSCustomObject]@{ Key = $k; Action = "Revert" })
        Submit-RoninJob $b
    } }
    function Update-ChangesList { Invoke-UiSafe 'Update-ChangesList' {
        $pnl = $window.FindName("Pnl_Changes"); if (-not $pnl) { return }
        $pnl.Children.Clear()
        # ASSIGN first, never pipe: Get-AppliedLedger returns ",array", and piping that sends the whole
        # array down the pipeline as ONE object - $_.Key was $null for an empty ledger (ContainsKey
        # threw, which broke opening the Maintenance tab) and an array of every key otherwise (so no
        # row ever matched). Assignment unwraps it to the rows themselves.
        $ledger = Get-AppliedLedger
        $kept = @()
        foreach ($r in @($ledger)) { if ($r -and $r.Key -and $RoninDB.ContainsKey("$($r.Key)")) { $kept += $r } }
        $rows = @($kept | Sort-Object When -Descending)
        # 8.0: apps the Debloat Center removed (assign, never pipe - same ",array" shape).
        $removedRaw = Get-RemovedApps
        $removed = @(@($removedRaw) | Where-Object { $_ -and $_.Name } | Sort-Object When -Descending)
        $script:LastLedgerSeen = $SyncHash.LedgerVersion
        $cnt = $window.FindName("Txt_ChangesCount")
        $parts = @()
        if ($rows.Count -eq 1) { $parts += "1 change" } elseif ($rows.Count) { $parts += "$($rows.Count) changes" }
        if ($removed.Count -eq 1) { $parts += "1 app removed" } elseif ($removed.Count) { $parts += "$($removed.Count) apps removed" }
        $cnt.Text = $parts -join ', '
        if ($rows.Count -eq 0 -and $removed.Count -eq 0) {
            $tb = New-Object System.Windows.Controls.TextBlock
            $tb.Text = "Ronin hasn't changed anything on this PC yet."
            # 8.0: wrap - the 3-column Maintenance card is narrower than 7.6's, and this clipped mid-sentence.
            $tb.TextWrapping = [System.Windows.TextWrapping]::Wrap
            $tb.Foreground = [System.Windows.Media.Brushes]::Gray; $tb.FontFamily = "Consolas"; $tb.FontSize = 12
            $tb.Margin = [System.Windows.Thickness]::new(0, 4, 0, 4)
            [void]$pnl.Children.Add($tb); return
        }
        foreach ($row in $rows) {
            $g = New-Object System.Windows.Controls.Grid
            $g.Margin = [System.Windows.Thickness]::new(0, 0, 0, 4)
            foreach ($w in @('*', 'Auto', 'Auto')) {
                $cd = New-Object System.Windows.Controls.ColumnDefinition
                $cd.Width = if ($w -eq '*') { [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) } else { [System.Windows.GridLength]::Auto }
                [void]$g.ColumnDefinitions.Add($cd)
            }
            $ctl = $window.FindName($row.Key)
            $name = New-Object System.Windows.Controls.TextBlock
            $name.Text = if ($ctl -and $ctl.Content) { "$($ctl.Content)" } else { $row.Key }
            $name.ToolTip = $name.Text   # full name: the column truncates long ones
            $name.Foreground = [System.Windows.Media.Brushes]::White; $name.FontFamily = "Consolas"; $name.FontSize = 12
            $name.TextTrimming = "CharacterEllipsis"; $name.VerticalAlignment = "Center"
            $when = New-Object System.Windows.Controls.TextBlock
            $when.Text = $row.When
            $when.Foreground = [System.Windows.Media.Brushes]::Gray; $when.FontFamily = "Consolas"; $when.FontSize = 11
            $when.VerticalAlignment = "Center"; $when.Margin = [System.Windows.Thickness]::new(10, 0, 10, 0)
            [System.Windows.Controls.Grid]::SetColumn($when, 1)
            $undo = New-Object System.Windows.Controls.Button
            $undo.Content = "UNDO"; $undo.FontFamily = "Consolas"; $undo.FontSize = 11; $undo.FontWeight = "Bold"
            $undo.Padding = [System.Windows.Thickness]::new(10, 2, 10, 2)
            $undo.Background = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(37, 37, 38))
            $undo.Foreground = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(255, 153, 153))
            $undo.ToolTip = "Undo this change"
            [System.Windows.Controls.Grid]::SetColumn($undo, 2)
            # The row's tweak key travels on the button itself; one shared handler reads it.
            $undo.Tag = $row.Key
            $undo.Add_Click($script:UndoRowHandler)
            [void]$g.Children.Add($name); [void]$g.Children.Add($when); [void]$g.Children.Add($undo)
            [void]$pnl.Children.Add($g)
        }
        # 8.0: removal record rows - grey, no UNDO (Ronin can't reinstall; the tooltip says how to).
        $grey = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(140, 140, 140))
        foreach ($rm in $removed) {
            $g = New-Object System.Windows.Controls.Grid
            $g.Margin = [System.Windows.Thickness]::new(0, 0, 0, 4)
            foreach ($w in @('*', 'Auto', 'Auto')) {
                $cd = New-Object System.Windows.Controls.ColumnDefinition
                $cd.Width = if ($w -eq '*') { [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star) } else { [System.Windows.GridLength]::Auto }
                [void]$g.ColumnDefinitions.Add($cd)
            }
            $g.ToolTip = "Removed by the Debloat Center ($($rm.Name)). Ronin can't reinstall apps - get it back from the Microsoft Store if you want it."
            $name = New-Object System.Windows.Controls.TextBlock
            $name.Text = "$($rm.Friendly)"; $name.Foreground = $grey; $name.FontFamily = "Consolas"; $name.FontSize = 12
            $name.TextTrimming = "CharacterEllipsis"; $name.VerticalAlignment = "Center"
            $when = New-Object System.Windows.Controls.TextBlock
            $when.Text = "$($rm.When)"; $when.Foreground = [System.Windows.Media.Brushes]::Gray; $when.FontFamily = "Consolas"; $when.FontSize = 11
            $when.VerticalAlignment = "Center"; $when.Margin = [System.Windows.Thickness]::new(10, 0, 10, 0)
            [System.Windows.Controls.Grid]::SetColumn($when, 1)
            $tag = New-Object System.Windows.Controls.TextBlock
            $tag.Text = "REMOVED"; $tag.Foreground = $grey; $tag.FontFamily = "Consolas"; $tag.FontSize = 11; $tag.FontWeight = "Bold"
            $tag.VerticalAlignment = "Center"; $tag.Margin = [System.Windows.Thickness]::new(0, 0, 6, 0)
            [System.Windows.Controls.Grid]::SetColumn($tag, 2)
            [void]$g.Children.Add($name); [void]$g.Children.Add($when); [void]$g.Children.Add($tag)
            [void]$pnl.Children.Add($g)
        }
    } }

    # --- ENGINE-REQUESTED DIALOGS (7.6.0 freeze fix) -------------------------------------------------
    # The Debloat Center and the batch summary used to be BUILT BY THE ENGINE inside its
    # Dispatcher.Invoke, which made every click/close handler an ENGINE-runspace scriptblock. Windows
    # PowerShell runs a scriptblock on the runspace that created it, so clicking CANCEL handed the
    # handler to the engine, and its $dlg.Close() raised a Closed handler that had to wait for the engine
    # again: the UI thread hung forever while the engine kept beating (reproduced 3/3 in a probe, 0/700
    # when built here). Now the engine only publishes data and BeginInvokes these UI-runspace delegates.
    # Invariant 12: the engine never creates a window or attaches an event handler.

    # 8.0 Black Ice dialog frame, shared by the Debloat Center, batch summary, Startup Apps and Install Apps (they
    # were 7.x cyan / blue / green with Consolas). The main header in miniature: red slash, condensed title, red
    # block; dark card with red-lit corners (all red when -Alert) and a soft shadow, which is why the card keeps an
    # 18 px margin inside its transparent window. $Body is the dialog's own XAML. Buttons get their styles from
    # Set-DialogLook. Returns one string (never an array - see the ",array" pipeline trap).
    function New-DialogXaml ([string]$Title, [string]$Sub, [int]$Width, [string]$Body, [switch]$Alert) {
        $t = [System.Security.SecurityElement]::Escape($Title); $s = [System.Security.SecurityElement]::Escape($Sub)
        $tc = if ($Alert) { '#FF2E3A' } else { '#F4F6F8' }
        $frame = if ($Alert) { '<SolidColorBrush Color="#FF2E3A"/>' } else { '<LinearGradientBrush StartPoint="0,0" EndPoint="1,1"><GradientStop Color="#D0FF2E3A" Offset="0"/><GradientStop Color="#1D2128" Offset="0.12"/><GradientStop Color="#1D2128" Offset="0.88"/><GradientStop Color="#D0FF2E3A" Offset="1"/></LinearGradientBrush>' }
        return @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent" ResizeMode="NoResize" Foreground="#E6EAEE"
        SizeToContent="WidthAndHeight" WindowStartupLocation="CenterOwner" ShowInTaskbar="False" FontFamily="Segoe UI Variable Text, Segoe UI">
  <Border BorderThickness="1" CornerRadius="2" Width="$Width" Margin="18">
    <Border.Effect><DropShadowEffect BlurRadius="22" ShadowDepth="0" Opacity="0.7" Color="#000000"/></Border.Effect>
    <Border.Background><LinearGradientBrush StartPoint="0,0" EndPoint="0,1"><GradientStop Color="#111318" Offset="0"/><GradientStop Color="#0A0B0E" Offset="1"/></LinearGradientBrush></Border.Background>
    <Border.BorderBrush>$frame</Border.BorderBrush>
    <StackPanel Margin="24,18,24,20">
      <StackPanel Orientation="Horizontal">
        <TextBlock Text="/" FontFamily="Bahnschrift, Segoe UI" FontStretch="SemiCondensed" FontWeight="SemiBold" FontSize="24" Foreground="#FF2E3A" Margin="0,0,8,0"/>
        <TextBlock Text="$t" FontFamily="Bahnschrift, Segoe UI" FontStretch="SemiCondensed" FontWeight="SemiBold" FontSize="24" Foreground="$tc"/>
        <Rectangle Width="8" Height="17" Fill="#FF2E3A" Margin="8,3,0,0" VerticalAlignment="Center"/>
      </StackPanel>
      <TextBlock Text="PROJECT RONIN  //  $s" Foreground="#7D8692" FontFamily="Cascadia Mono, Consolas" FontSize="10" Margin="1,0,0,16"/>
      $Body
    </StackPanel>
  </Border>
</Window>
"@
    }

    $script:DebloatDlg = $null
    function Show-DebloatCenter {
        if ($script:DebloatDlg -and $script:DebloatDlg.IsVisible) { try { [void]$script:DebloatDlg.Activate() } catch {}; return }
        $body = @"
      <Border Background="#0B0D11" BorderBrush="#1B1F26" BorderThickness="1" CornerRadius="2" Padding="10,8,6,8">
        <ScrollViewer MaxHeight="380" VerticalScrollBarVisibility="Auto">
          <StackPanel x:Name="DbList"/>
        </ScrollViewer>
      </Border>
      <TextBlock x:Name="DbCount" Foreground="#8A939E" FontFamily="Cascadia Mono, Consolas" FontSize="11.5" Margin="2,10,0,0"/>
      <TextBlock Foreground="#7D8692" FontSize="11" TextWrapping="Wrap" Margin="2,6,0,0"
                 Text="Removal is permanent from Ronin's side - removed apps can be reinstalled from the Microsoft Store. Junk apps are pre-selected; Xbox / Game Pass apps are never pre-selected."/>
      <Grid Margin="0,16,0,0">
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Left">
          <Button x:Name="DbRec" Content="RECOMMENDED" Width="120" Height="32" Margin="0,0,8,0"/>
          <Button x:Name="DbClear" Content="CLEAR ALL" Width="90" Height="32"/>
        </StackPanel>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
          <Button x:Name="DbCancel" Content="CANCEL" Width="90" Height="32" Margin="0,0,8,0"/>
          <Button x:Name="DbGo" Content="REMOVE SELECTED" Width="172" Height="32" FontSize="12"/>
        </StackPanel>
      </Grid>
"@
        $dlg = [System.Windows.Markup.XamlReader]::Parse((New-DialogXaml 'DEBLOAT CENTER' 'SELECT APPS TO REMOVE' 560 $body))
        $dlg.Owner = $window; Set-DialogLook $dlg @{ DbRec = 'GhostBtn'; DbClear = 'GhostBtn'; DbCancel = 'GhostBtn'; DbGo = 'ApplyBtn' }
        $list  = $dlg.FindName("DbList")
        $count = $dlg.FindName("DbCount")
        $goBtn = $dlg.FindName("DbGo")
        $amber = $script:BrushAmber   # captured: $script: inside a GetNewClosure block is the closure's own scope
        # Labels follow the switch (bright on, grey off) like the main window - no colour set in code.
        foreach ($app in @($SyncHash.DebloatApps)) {
            $cb = New-Object System.Windows.Controls.CheckBox
            $cb.Content = $app.Display; $cb.Tag = $app.Pkg; $cb.DataContext = $app
            $cb.IsChecked = [bool]$app.Rec
            $cb.FontSize = 13; $cb.Margin = New-Object System.Windows.Thickness(2,3,2,3)
            $cb.ToolTip = $app.Pkg
            [void]$list.Children.Add($cb)
        }
        $disarm = { if ($goBtn.Tag -eq "ARMED") { $goBtn.Tag = $null; $goBtn.Content = "REMOVE SELECTED"; $goBtn.ClearValue([System.Windows.Controls.Control]::BackgroundProperty) } }.GetNewClosure()
        $refreshCount = {
            $n = 0; foreach ($c in $list.Children) { if ($c.IsChecked) { $n++ } }
            $count.Text = "$n of $($list.Children.Count) selected for removal"
            & $disarm
        }.GetNewClosure()
        & $refreshCount
        foreach ($c in $list.Children) { $c.Add_Click($refreshCount) }
        $dlg.FindName("DbRec").Add_Click({
            foreach ($c in $list.Children) { $c.IsChecked = [bool]$c.DataContext.Rec }
            & $refreshCount
        }.GetNewClosure())
        $dlg.FindName("DbClear").Add_Click({
            foreach ($c in $list.Children) { $c.IsChecked = $false }
            & $refreshCount
        }.GetNewClosure())
        $dlg.FindName("DbCancel").Add_Click({
            Invoke-UiSafe 'Debloat Center CANCEL' { Write-Diag "Cancel clicked" "DEBLOAT"; $dlg.Close() }
        }.GetNewClosure())
        # Two-step confirm: first click ARMS the button, second click submits. Never a modal.
        $goBtn.Add_Click({ Invoke-UiSafe 'Debloat Center REMOVE' {
            $sel = @(); foreach ($c in $list.Children) { if ($c.IsChecked) { $sel += $c.Tag } }
            Write-Diag "RemoveSelected clicked (armed=$($goBtn.Tag -eq 'ARMED'), $($sel.Count) selected)" "DEBLOAT"
            if ($sel.Count -eq 0) { $count.Text = "Nothing selected."; & $disarm; return }
            if ($goBtn.Tag -ne "ARMED") {
                $goBtn.Tag = "ARMED"
                $goBtn.Content = "CONFIRM REMOVE ($($sel.Count))"
                $goBtn.Background = $amber   # the confirm colour everywhere (8.0.0 tester: a shade of red misleads)
                $count.Text = "Click CONFIRM to remove $($sel.Count) app(s) - reinstallable from the Microsoft Store."
                return
            }
            $SyncHash.DebloatSelection = $sel
            $dlg.Close()
            Submit-RoninJob "DEBLOAT_REMOVE"
        } }.GetNewClosure())
        # One Closed handler covers every way out (Cancel, Remove, Alt+F4), so the "open" flag can't stick.
        $dlg.Add_Closed({ $SyncHash.DebloatOpen = $false; $script:DebloatDlg = $null })
        $script:DebloatDlg = $dlg
        $SyncHash.DebloatOpen = $true
        $dlg.Show()
        # Activate so the first click lands on a control, not on window activation.
        try { [void]$dlg.Activate() } catch {}
        Write-Diag "DEBLOAT: dialog open ($($list.Children.Count) apps)" "UI"
    }

    function Show-BatchSummary {
        $d = $SyncHash.BatchSummary
        if (-not $d) { return }
        $applied = [int]$d.Applied; $reverted = [int]$d.Reverted; $skipped = [int]$d.Skipped; $failed = [int]$d.Failed
        # 8.0 Black Ice (was 7.x cyan/Consolas): the main header in miniature - red slash, condensed title - and the
        # header's KPI tiles for the counts. A tile at 0 goes quiet (muted value, idle bar), like ACTIVE/QUEUED/REBOOT.
        $hdr      = if ($failed -gt 0) { 'ATTENTION NEEDED' } else { 'BATCH COMPLETE' }
        $tiles = ''
        $spec = @(@('APPLIED', $applied, '#7FD9A0'), @('REVERTED', $reverted, '#F4F6F8'), @('ALREADY SET', $skipped, '#C9D0D7'), @('FAILED', $failed, '#FF5A63'))
        for ($i = 0; $i -lt $spec.Count; $i++) {
            $on = ([int]$spec[$i][1] -gt 0)
            $bar = if ($on) { $spec[$i][2] } else { '#2E343C' }
            $fg  = if ($on) { $spec[$i][2] } else { '#5C6570' }
            $mg  = if ($i -lt $spec.Count - 1) { '0,0,6,0' } else { '0' }
            $tiles += "<Grid Margin=`"$mg`"><Border Background=`"#0B0D11`" BorderBrush=`"#1B1F26`" BorderThickness=`"1`"/><Rectangle Height=`"2`" VerticalAlignment=`"Top`" Fill=`"$bar`"/><StackPanel Margin=`"10,8,8,6`"><TextBlock Text=`"$($spec[$i][0])`" FontFamily=`"Cascadia Mono, Consolas`" FontSize=`"8.5`" Foreground=`"#7D8692`"/><TextBlock Text=`"$($spec[$i][1])`" FontFamily=`"Bahnschrift, Segoe UI`" FontWeight=`"SemiBold`" FontSize=`"24`" Foreground=`"$fg`"/></StackPanel></Grid>"
        }
        $failBlock = ''
        $uniq = @(); foreach ($k in @($d.FailedKeys)) { if ($k -and $uniq -notcontains $k) { $uniq += $k } }
        if ($failed -gt 0 -and $uniq.Count -gt 0) {
            # 8.0: the label the user clicked, with the internal key kept for bug reports ("Priv_Widgets" alone meant nothing).
            $bullets = @(); foreach ($k in $uniq) { $c = $window.FindName([string]$k); $lbl = if ($c -and $c.Content -is [string]) { "$($c.Content)  ($k)" } else { [string]$k }; $bullets += "&#8226;  $([System.Security.SecurityElement]::Escape($lbl))" }
            $items = $bullets -join '&#10;'
            $failBlock = "<Border Background=`"#0B0D11`" BorderBrush=`"#3A1A1E`" BorderThickness=`"1`" CornerRadius=`"2`" Margin=`"0,14,0,0`" Padding=`"12`"><StackPanel><TextBlock Text=`"NEEDS ATTENTION`" Foreground=`"#FF2E3A`" FontFamily=`"Cascadia Mono, Consolas`" FontSize=`"10.5`" FontWeight=`"Bold`" Margin=`"0,0,0,8`"/><ScrollViewer MaxHeight=`"130`" VerticalScrollBarVisibility=`"Auto`"><TextBlock Foreground=`"#FFB3B8`" FontFamily=`"Cascadia Mono, Consolas`" FontSize=`"11.5`" TextWrapping=`"Wrap`" Text=`"$items`"/></ScrollViewer><TextBlock Foreground=`"#8A939E`" FontSize=`"11`" TextWrapping=`"Wrap`" Margin=`"0,10,0,0`" Text=`"May be blocked by group policy, need a reboot, or unsupported on this build. See Ronin.log for details.`"/></StackPanel></Border>"
        }
        $body = @"
      <UniformGrid Columns="4">$tiles</UniformGrid>
      $failBlock
      <Grid Margin="0,18,0,0">
        <TextBlock Text="every step: status bar &gt; LOG" Foreground="#5C6570" FontFamily="Cascadia Mono, Consolas" FontSize="10" VerticalAlignment="Center"/>
        <Button x:Name="DlgOk" Content="OK" IsDefault="True" HorizontalAlignment="Right" Width="100" Height="34" FontSize="12"/>
      </Grid>
"@
        $dlg = [System.Windows.Markup.XamlReader]::Parse((New-DialogXaml $hdr 'BATCH SUMMARY' 440 $body -Alert:($failed -gt 0)))
        $dlg.Owner = $window; Set-DialogLook $dlg @{ DlgOk = 'GhostBtn' }
        $okBtn = $dlg.FindName("DlgOk")
        $okBtn.Add_Click({ Invoke-UiSafe 'Batch summary OK' { Write-Diag "OK clicked" "SUMMARY"; $dlg.Close() } }.GetNewClosure())
        $script:SummaryDlg = $dlg
        $dlg.Show()
        # Activate + focus so the FIRST click on OK lands on the button, not on window activation.
        try { [void]$dlg.Activate(); [void]$okBtn.Focus() } catch {}
    }

    # The engine BeginInvokes these. They are created HERE, so they run in the UI runspace.
    $SyncHash.ShowDebloatCenter = [System.Action]{ Invoke-UiSafe 'Debloat Center' { Show-DebloatCenter } }
    $SyncHash.ShowBatchSummary  = [System.Action]{ Invoke-UiSafe 'Batch summary' { Show-BatchSummary } }

    # =====================================================================================
    # 8.0 - DECLUTTER: Windows Update conflicts/status/reminder, Startup Apps, Windows Tools.
    # UI thread only. Every registry read here is a single .NET value read (microseconds) - nothing
    # that can stall the UI (no WMI, no external commands; invariant 8). All handlers are created
    # here, in the UI runspace (invariant 12).
    # =====================================================================================

    # Pause and Off write the same values. Pure function (unit-tested):
    #  - both ticked: keep Off (it already covers pausing) and drop the Pause task;
    #  - Reverts of either run BEFORE Applies: unticking Off while ticking Pause must first put the
    #    pre-Off state back and THEN record it as Pause's original - the other order would let the
    #    Off revert wipe the brand-new pause.
    #  - Off's revert runs BEFORE Pause's: if Pause was applied first and Off later, Off's recorded
    #    original IS the 35-day pause, so Off's revert brings it back - and only then is Pause's Check
    #    on, so its revert actually runs (the other order skipped it and left updates paused).
    function Resolve-WuConflicts ($Tasks) {
        $list = [System.Collections.ArrayList]::new()
        $wuRev = @(); $wuApp = @(); $offApply = $false
        foreach ($t in @($Tasks)) { if ($t -and $t.Key -eq 'Dcl_WU_Off' -and $t.Action -eq 'Apply') { $offApply = $true } }
        foreach ($t in @($Tasks)) {
            if (-not $t) { continue }
            if ($t.Key -ne 'Dcl_WU_Pause' -and $t.Key -ne 'Dcl_WU_Off') { [void]$list.Add($t); continue }
            if ($t.Key -eq 'Dcl_WU_Pause' -and $t.Action -eq 'Apply' -and $offApply) { continue }
            if ($t.Action -eq 'Revert') { $wuRev += $t } else { $wuApp += $t }
        }
        foreach ($t in @($wuRev | Where-Object { $_.Key -eq 'Dcl_WU_Off' })) { [void]$list.Add($t) }
        foreach ($t in @($wuRev | Where-Object { $_.Key -ne 'Dcl_WU_Off' })) { [void]$list.Add($t) }
        foreach ($t in $wuApp) { [void]$list.Add($t) }
        return ,$list
    }

    # Pure (unit-tested). $Expiry = raw PauseUpdatesExpiryTime; $NoRestart = Ronin's active-hours set.
    function Get-WuStatusText ($Expiry, $Now, [bool]$NoRestart) {
        $days = Get-WuPauseDaysLeft $Expiry $Now
        if ($days -gt 0) {
            $until = (ConvertFrom-WuTime $Expiry).ToLocalTime().ToString('d MMM yyyy', [Globalization.CultureInfo]::InvariantCulture)
            $s = if ($days -gt 36) { "Updates are OFF until $until." } else { "Updates paused until $until ($days day$(if ($days -ne 1) { 's' }) left)." }
        } else { $s = "Updates are on." }
        if ($NoRestart) { $s += " No restarts between 08:00 and 02:00." }
        return $s
    }

    function Update-WuStatus {
        $tb = $window.FindName("Txt_WuStatus"); if (-not $tb) { return }
        $exp = $null; $nr = $false
        try {
            $k = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SOFTWARE\Microsoft\WindowsUpdate\UX\Settings')
            if ($k) {
                $exp = $k.GetValue('PauseUpdatesExpiryTime')
                $nr = ("$($k.GetValue('SmartActiveHoursState'))" -eq '0' -and "$($k.GetValue('ActiveHoursStart'))" -eq '8' -and "$($k.GetValue('ActiveHoursEnd'))" -eq '2')
                $k.Close()
            }
        } catch {}
        $tb.Text = Get-WuStatusText $exp $null $nr
        $days = Get-WuPauseDaysLeft $exp $null
        $rgb = if ($days -gt 36) { @(255, 170, 0) } elseif ($days -gt 0) { @(255, 215, 120) } else { @(124, 252, 154) }
        $tb.Foreground = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb($rgb[0], $rgb[1], $rgb[2]))
    }

    # Pure (unit-tested). Show the "updates are off" reminder? $OffSince = the ledger time of
    # Dcl_WU_Off ("yyyy-MM-dd HH:mm"); $SnoozeUntil = settings UpdatesReminderAfter ("yyyy-MM-dd" or '').
    function Test-UpdatesReminderDue ($OffSince, $SnoozeUntil, $Now) {
        if (-not $Now) { $Now = Get-Date }
        $inv = [Globalization.CultureInfo]::InvariantCulture
        $off = [datetime]::MinValue
        if (-not [datetime]::TryParseExact("$OffSince", 'yyyy-MM-dd HH:mm', $inv, [Globalization.DateTimeStyles]::None, [ref]$off)) { return $false }
        if (($Now - $off).TotalDays -lt 30) { return $false }
        $sn = [datetime]::MinValue
        if ("$SnoozeUntil" -and [datetime]::TryParseExact("$SnoozeUntil", 'yyyy-MM-dd', $inv, [Globalization.DateTimeStyles]::None, [ref]$sn) -and $Now -lt $sn) { return $false }
        return $true
    }

    function Show-UpdatesReminderIfDue {
        # Assign, never pipe: Get-AppliedLedger returns ",array" (see Update-ChangesList).
        $ledger = Get-AppliedLedger
        $row = $null; foreach ($r in @($ledger)) { if ($r -and $r.Key -eq 'Dcl_WU_Off') { $row = $r } }
        if (-not $row) { return }
        # Still actually off? (Settings' own "Resume updates" may have ended it since.)
        $exp = $null
        try { $k = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'); if ($k) { $exp = $k.GetValue('PauseUpdatesExpiryTime'); $k.Close() } } catch {}
        if ((Get-WuPauseDaysLeft $exp $null) -le 36) { return }
        if (-not (Test-UpdatesReminderDue $row.When $script:Settings.UpdatesReminderAfter (Get-Date))) { return }
        $since = $row.When
        try { $since = [datetime]::ParseExact("$($row.When)", 'yyyy-MM-dd HH:mm', [Globalization.CultureInfo]::InvariantCulture).ToString('d MMM yyyy', [Globalization.CultureInfo]::InvariantCulture) } catch {}
        $window.FindName("UpdatesBannerText").Text = "Windows updates have been off since $since. Security fixes are waiting."
        $window.FindName("Banner_Updates").Visibility = "Visible"
        Log "Reminder: Windows updates have been off since $since."
    }

    $window.FindName("Btn_UpdatesOn").Add_Click({ Invoke-UiSafe 'Btn_UpdatesOn Click' {
        $window.FindName("Banner_Updates").Visibility = "Collapsed"
        $b = [System.Collections.ArrayList]::new(); [void]$b.Add([PSCustomObject]@{ Key = 'Dcl_WU_Off'; Action = 'Revert' })
        Log "Turning Windows updates back on."
        Submit-RoninJob $b
    } })
    $window.FindName("Btn_UpdatesSnooze").Add_Click({ Invoke-UiSafe 'Btn_UpdatesSnooze Click' {
        $window.FindName("Banner_Updates").Visibility = "Collapsed"
        $script:Settings.UpdatesReminderAfter = (Get-Date).AddDays(30).ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
        Save-CurrentSettings
        Log "OK - updates stay off. Ronin will remind you again after $($script:Settings.UpdatesReminderAfter)."
    } })

    $window.FindName("Btn_RunDeclutter").Add_Click({ Invoke-ApplyButton $this (Resolve-WuConflicts (Get-Tasks "Dcl_")) })
    $window.FindName("Btn_DebloatDcl").Add_Click({ Submit-RoninJob ("DEBLOAT_SCAN") })

    # --- Two-step confirm for actions that can't be taken back (8.0) ---
    # First click arms the button (red, "CONFIRM ...", the warning printed in the console); a second click
    # within 12 s runs it; otherwise it disarms itself. Never a modal. Used by RECLAIM SPACE (its confirm
    # used to be a MODAL MessageBox from the ENGINE thread - invariants 2 and 12) and by the BIOS /
    # Recovery buttons, which used to restart the PC on the FIRST click, with no warning at all.
    $script:Armed = @{}
    $script:ArmTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:ArmTimer.Interval = [TimeSpan]::FromSeconds(12)
    function Reset-ArmedButtons {
        $script:ArmTimer.Stop()
        foreach ($n in @($script:Armed.Keys)) { $b = $window.FindName($n); if ($b) { $b.Content = $script:Armed[$n].Content; $b.Background = $script:Armed[$n].Background; $b.Tag = $null } }
        $script:Armed.Clear()
    }
    function Invoke-ArmedButton ($Name, $ConfirmText, $Warning, [scriptblock]$Action) {
        $b = $window.FindName($Name); if (-not $b) { return }
        if ($b.Tag -ne 'ARMED') {
            Reset-ArmedButtons
            $script:Armed[$Name] = @{ Content = $b.Content; Background = $b.Background }
            $b.Tag = 'ARMED'; $b.Content = $ConfirmText; $b.Background = [System.Windows.Media.Brushes]::Firebrick
            Log $Warning
            $script:ArmTimer.Start()
            return
        }
        Reset-ArmedButtons
        & $Action
    }
    $script:ArmTimer.Add_Tick({ Invoke-UiSafe 'Armed button timeout' { Reset-ArmedButtons } })
    $window.FindName("Btn_Reclaim").Add_Click({ Invoke-UiSafe 'Btn_Reclaim Click' {
        Invoke-ArmedButton "Btn_Reclaim" "CONFIRM: PERMANENT CLEAN" "RECLAIM SPACE is permanent: it removes Windows.old (no going back to your previous Windows) and compresses old updates (installed updates can't be uninstalled afterwards). Frees 15-30+ GB and takes 10-30 minutes. Click CONFIRM within 12 seconds to start." { Submit-RoninJob ("MAINT_RECLAIM") }
    } })
    $window.FindName("Btn_BootUEFI").Add_Click({ Invoke-UiSafe 'Btn_BootUEFI Click' {
        Invoke-ArmedButton "Btn_BootUEFI" "RESTART NOW?" "BIOS / UEFI restarts your PC IMMEDIATELY into firmware setup - save your work in other apps first. Click RESTART NOW? within 12 seconds to go." { Submit-RoninJob ("BOOT_UEFI") }
    } })
    $window.FindName("Btn_BootRecovery").Add_Click({ Invoke-UiSafe 'Btn_BootRecovery Click' {
        Invoke-ArmedButton "Btn_BootRecovery" "RESTART NOW?" "RECOVERY MENU restarts your PC IMMEDIATELY into Advanced Startup - save your work in other apps first. Click RESTART NOW? within 12 seconds to go." { Submit-RoninJob ("BOOT_RECOVERY") }
    } })
    # --- Windows Tools: plain launchers (Tag = command). Nothing here changes a setting. ---
    $script:ToolClick = { param($s, $e) Invoke-UiSafe 'Windows tool' {
        $cmd = "$($s.Tag)"; if (-not $cmd) { return }
        if ($cmd -like '*.cpl') { Start-Process "control.exe" -ArgumentList $cmd } else { Start-Process $cmd }
        Log "Opened $($s.Content)."
    } }
    foreach ($tn in 'Tool_Control','Tool_Devices','Tool_Network','Tool_Power','Tool_Sound','Tool_Programs','Tool_Services','Tool_Disks','Tool_Events','Tool_SysProps') {
        $tb = $window.FindName($tn); if ($tb) { $tb.Add_Click($script:ToolClick) }
    }

    # --- Startup Apps ---
    # Windows' own on/off switch for startup entries - the one Task Manager's Startup tab flips:
    #   ...\CurrentVersion\Explorer\StartupApproved\<Run|Run32|StartupFolder>\<entry> = 12-byte BINARY
    #   no value, or an even first byte (02/06) = enabled; odd (03) = disabled; bytes 4-11 = when.
    # The Run entries and shortcut files themselves are never touched, so every switch can be flipped
    # back here or in Task Manager. Store apps keep their own switch (Settings > Apps > Startup).
    function Test-StartupApprovedEnabled ($Bytes) {      # pure, unit-tested
        if ($null -eq $Bytes -or $Bytes.Length -eq 0) { return $true }
        return (($Bytes[0] -band 1) -eq 0)
    }
    function New-StartupApprovedBytes ([bool]$Enabled, [datetime]$When) {     # pure, unit-tested
        $b = New-Object byte[] 12
        if ($Enabled) { $b[0] = 2 }
        else { $b[0] = 3; [Array]::Copy([BitConverter]::GetBytes($When.ToFileTimeUtc()), 0, $b, 4, 8) }
        return ,$b
    }
    function Get-StartupEntries {
        $out = New-Object System.Collections.Generic.List[object]
        $ap = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
        $regSources = @(
            @{ Hive = 'HKCU'; Run = 'Software\Microsoft\Windows\CurrentVersion\Run'; Approved = "$ap\Run"; Where = 'you' }
            @{ Hive = 'HKLM'; Run = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; Approved = "$ap\Run"; Where = 'all users' }
            @{ Hive = 'HKLM'; Run = 'SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Approved = "$ap\Run32"; Where = 'all users, 32-bit' }
        )
        foreach ($s in $regSources) {
            $root = if ($s.Hive -eq 'HKCU') { [Microsoft.Win32.Registry]::CurrentUser } else { [Microsoft.Win32.Registry]::LocalMachine }
            $rk = $null; $ak = $null
            try {
                $rk = $root.OpenSubKey($s.Run)
                if ($rk) {
                    $ak = $root.OpenSubKey($s.Approved)
                    foreach ($n in $rk.GetValueNames()) {
                        if (-not $n) { continue }
                        $bytes = if ($ak) { $ak.GetValue($n) } else { $null }
                        $out.Add([PSCustomObject]@{ Name = $n; Command = "$($rk.GetValue($n))"; Where = $s.Where; Hive = $s.Hive; Approved = $s.Approved; Enabled = (Test-StartupApprovedEnabled $bytes) })
                    }
                }
            } catch {} finally { if ($rk) { $rk.Close() }; if ($ak) { $ak.Close() } }
        }
        $folders = @(
            @{ Path = [Environment]::GetFolderPath('Startup'); Hive = 'HKCU'; Where = 'you, Startup folder' }
            @{ Path = [Environment]::GetFolderPath('CommonStartup'); Hive = 'HKLM'; Where = 'all users, Startup folder' }
        )
        foreach ($f in $folders) {
            if (-not $f.Path -or -not [IO.Directory]::Exists($f.Path)) { continue }
            $root = if ($f.Hive -eq 'HKCU') { [Microsoft.Win32.Registry]::CurrentUser } else { [Microsoft.Win32.Registry]::LocalMachine }
            $ak = $null
            try {
                $ak = $root.OpenSubKey("$ap\StartupFolder")
                foreach ($file in [IO.Directory]::GetFiles($f.Path)) {
                    $fn = [IO.Path]::GetFileName($file)
                    if ($fn -ieq 'desktop.ini') { continue }
                    $bytes = if ($ak) { $ak.GetValue($fn) } else { $null }
                    $out.Add([PSCustomObject]@{ Name = $fn; Command = $file; Where = $f.Where; Hive = $f.Hive; Approved = "$ap\StartupFolder"; Enabled = (Test-StartupApprovedEnabled $bytes) })
                }
            } catch {} finally { if ($ak) { $ak.Close() } }
        }
        return ,$out.ToArray()
    }
    function Set-StartupEntryState ($Entry, [bool]$Enabled) {
        $root = if ($Entry.Hive -eq 'HKCU') { [Microsoft.Win32.Registry]::CurrentUser } else { [Microsoft.Win32.Registry]::LocalMachine }
        $k = $root.CreateSubKey($Entry.Approved)
        try { $bytes = New-StartupApprovedBytes $Enabled (Get-Date); $k.SetValue($Entry.Name, [byte[]]$bytes, [Microsoft.Win32.RegistryValueKind]::Binary) }
        finally { $k.Close() }
        $Entry.Enabled = $Enabled
        Log "Startup app '$($Entry.Name)' $(if ($Enabled) { 'will start with Windows again' } else { 'will no longer start with Windows' }) (same switch as Task Manager)."
    }

    $script:StartupDlg = $null
    function Show-StartupApps {
        if ($script:StartupDlg -and $script:StartupDlg.IsVisible) { try { [void]$script:StartupDlg.Activate() } catch {}; return }
        $body = @"
      <Border Background="#0B0D11" BorderBrush="#1B1F26" BorderThickness="1" CornerRadius="2" Padding="10,8,6,8">
        <ScrollViewer MaxHeight="380" VerticalScrollBarVisibility="Auto">
          <StackPanel x:Name="SuList"/>
        </ScrollViewer>
      </Border>
      <TextBlock x:Name="SuCount" Foreground="#8A939E" FontFamily="Cascadia Mono, Consolas" FontSize="11.5" Margin="2,10,0,0"/>
      <TextBlock Foreground="#7D8692" FontSize="11" TextWrapping="Wrap" Margin="2,6,0,0"
                 Text="Untick an app to stop it starting with Windows. Nothing is uninstalled or deleted - it's the same switch as Task Manager's Startup tab, and it takes effect at your next sign-in."/>
      <Grid Margin="0,16,0,0">
        <Button x:Name="SuStore" Content="STORE APPS..." HorizontalAlignment="Left" Width="120" Height="32" ToolTip="Store apps have their own startup switches in Settings &gt; Apps &gt; Startup."/>
        <Button x:Name="SuClose" Content="DONE" HorizontalAlignment="Right" Width="100" Height="32" FontSize="12"/>
      </Grid>
"@
        $dlg = [System.Windows.Markup.XamlReader]::Parse((New-DialogXaml 'STARTUP APPS' 'WHAT STARTS WITH WINDOWS' 600 $body))
        $dlg.Owner = $window; Set-DialogLook $dlg @{ SuStore = 'GhostBtn'; SuClose = 'GhostBtn' }
        $list  = $dlg.FindName("SuList")
        $count = $dlg.FindName("SuCount")
        $entries = Get-StartupEntries
        # The app name follows the switch (bright on, grey off) through the shared switch style; only the
        # "you / all users" tag and the command line are drawn dim here.
        $cmdBrush = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb(0x5C, 0x65, 0x70))
        $refreshCount = {
            $on = 0; foreach ($c in $list.Children) { if ($c -is [System.Windows.Controls.CheckBox] -and $c.IsChecked) { $on++ } }
            $tot = 0; foreach ($c in $list.Children) { if ($c -is [System.Windows.Controls.CheckBox]) { $tot++ } }
            $count.Text = if ($tot -eq 0) { "No startup apps found." } else { "$on of $tot start with Windows" }
        }.GetNewClosure()
        foreach ($en in @($entries)) {
            $cb = New-Object System.Windows.Controls.CheckBox
            $tbx = New-Object System.Windows.Controls.TextBlock
            $run1 = New-Object System.Windows.Documents.Run ("$($en.Name)")
            $run1.FontSize = 13
            $run2 = New-Object System.Windows.Documents.Run ("   $($en.Where)")
            $run2.FontSize = 10; $run2.Foreground = $cmdBrush
            [void]$tbx.Inlines.Add($run1); [void]$tbx.Inlines.Add($run2)
            $cb.Content = $tbx
            $cb.IsChecked = [bool]$en.Enabled
            $cb.Margin = New-Object System.Windows.Thickness(2,4,2,0)
            $cb.ToolTip = $en.Command
            $cb.Tag = $en
            [void]$list.Children.Add($cb)
            $cmd = New-Object System.Windows.Controls.TextBlock
            $cmd.Text = $en.Command; $cmd.FontSize = 10; $cmd.FontFamily = "Cascadia Mono, Consolas"; $cmd.Foreground = $cmdBrush
            $cmd.TextTrimming = "CharacterEllipsis"; $cmd.Margin = New-Object System.Windows.Thickness(22,0,2,4)
            [void]$list.Children.Add($cmd)
        }
        & $refreshCount
        # One shared toggle handler; the entry travels on the checkbox's Tag. Click (not Checked) so
        # only a real user click writes anything.
        $toggle = { param($s, $e) Invoke-UiSafe 'Startup app toggle' {
            $on = [bool]$s.IsChecked
            try { Set-StartupEntryState $s.Tag $on }
            catch { $s.IsChecked = -not $on; Log "Couldn't change '$($s.Tag.Name)': $($_.Exception.Message)" }
            & $refreshCount
        } }.GetNewClosure()
        foreach ($c in $list.Children) { if ($c -is [System.Windows.Controls.CheckBox]) { $c.Add_Click($toggle) } }
        $dlg.FindName("SuStore").Add_Click({ Invoke-UiSafe 'Startup apps STORE' { Start-Process "ms-settings:startupapps" } })
        $dlg.FindName("SuClose").Add_Click({ Invoke-UiSafe 'Startup apps DONE' { $dlg.Close() } }.GetNewClosure())
        $dlg.Add_Closed({ $script:StartupDlg = $null })
        $script:StartupDlg = $dlg
        $dlg.Show()
        try { [void]$dlg.Activate() } catch {}
        Write-Diag "STARTUP APPS: dialog open ($(@($entries).Count) entries)" "UI"
    }
    $window.FindName("Btn_StartupApps").Add_Click({ Invoke-UiSafe 'Startup Apps' { Show-StartupApps } })

    # --- Install Apps (winget, on click only) ---
    # A FIXED list: every ID was checked against microsoft/winget-pkgs (2026-11-20). Nothing the user
    # types ever reaches winget, and the engine re-validates each ID's characters before running it.
    # This is the only Ronin feature that downloads anything, and only after a two-step confirm.
    $script:AppCatalog = @(
        @{ Cat = 'BROWSERS';   Apps = @( @('Mozilla.Firefox','Firefox'), @('Google.Chrome','Google Chrome'), @('Brave.Brave','Brave'), @('LibreWolf.LibreWolf','LibreWolf') ) }
        @{ Cat = 'GAMING';     Apps = @( @('Valve.Steam','Steam'), @('EpicGames.EpicGamesLauncher','Epic Games Launcher'), @('GOG.Galaxy','GOG Galaxy'), @('ElectronicArts.EADesktop','EA app'), @('Ubisoft.Connect','Ubisoft Connect'), @('HeroicGamesLauncher.HeroicGamesLauncher','Heroic Games Launcher'), @('Playnite.Playnite','Playnite'), @('Discord.Discord','Discord'), @('Guru3D.Afterburner','MSI Afterburner'), @('Libretro.RetroArch','RetroArch') ) }
        @{ Cat = 'STREAMING';  Apps = @( @('OBSProject.OBSStudio','OBS Studio'), @('MoonlightGameStreamingProject.Moonlight','Moonlight'), @('LizardByte.Sunshine','Sunshine'), @('Parsec.Parsec','Parsec') ) }
        @{ Cat = 'MEDIA';      Apps = @( @('VideoLAN.VLC','VLC'), @('Spotify.Spotify','Spotify'), @('HandBrake.HandBrake','HandBrake'), @('Audacity.Audacity','Audacity') ) }
        @{ Cat = 'UTILITIES';  Apps = @( @('7zip.7zip','7-Zip'), @('voidtools.Everything','Everything (file search)'), @('Microsoft.PowerToys','PowerToys'), @('ShareX.ShareX','ShareX'), @('Notepad++.Notepad++','Notepad++'), @('Bitwarden.Bitwarden','Bitwarden'), @('KeePassXCTeam.KeePassXC','KeePassXC'), @('qBittorrent.qBittorrent','qBittorrent'), @('SumatraPDF.SumatraPDF','SumatraPDF'), @('Malwarebytes.Malwarebytes','Malwarebytes') ) }
        @{ Cat = 'HARDWARE';   Apps = @( @('CrystalDewWorld.CrystalDiskInfo','CrystalDiskInfo'), @('REALiX.HWiNFO','HWiNFO'), @('CPUID.CPU-Z','CPU-Z'), @('TechPowerUp.GPU-Z','GPU-Z') ) }
        @{ Cat = 'GAME RUNTIMES'; Apps = @( @('Microsoft.VCRedist.2015+.x64','Visual C++ 2015-2022 (x64)'), @('Microsoft.DotNet.DesktopRuntime.8','.NET 8 Desktop Runtime'), @('Microsoft.DirectX','DirectX End-User Runtime') ) }
        @{ Cat = 'DEVELOPER';  Apps = @( @('Microsoft.VisualStudioCode','Visual Studio Code'), @('Git.Git','Git'), @('Python.Python.3.12','Python 3.12'), @('OpenJS.NodeJS.LTS','Node.js LTS') ) }
    )

    $script:InstallDlg = $null
    function Show-AppInstaller {
        if ($script:InstallDlg -and $script:InstallDlg.IsVisible) { try { [void]$script:InstallDlg.Activate() } catch {}; return }
        $body = @"
      <Border Background="#0B0D11" BorderBrush="#1B1F26" BorderThickness="1" CornerRadius="2" Padding="10,4,6,8">
        <ScrollViewer MaxHeight="400" VerticalScrollBarVisibility="Auto">
          <StackPanel x:Name="InList"/>
        </ScrollViewer>
      </Border>
      <TextBlock x:Name="InCount" Foreground="#8A939E" FontFamily="Cascadia Mono, Consolas" FontSize="11.5" Margin="2,10,0,0"/>
      <TextBlock Foreground="#7D8692" FontSize="11" TextWrapping="Wrap" Margin="2,6,0,0"
                 Text="This is the only part of Ronin that uses the internet, and only when you confirm. Apps download from their publishers through winget and install silently; each app's own license applies. Already-installed apps are skipped. Uninstall them later from Settings &gt; Apps as usual."/>
      <Grid Margin="0,16,0,0">
        <Button x:Name="InClear" Content="CLEAR" HorizontalAlignment="Left" Width="90" Height="32"/>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
          <Button x:Name="InCancel" Content="CANCEL" Width="90" Height="32" Margin="0,0,8,0"/>
          <Button x:Name="InGo" Content="INSTALL SELECTED" Width="182" Height="32" FontSize="12"/>
        </StackPanel>
      </Grid>
"@
        $dlg = [System.Windows.Markup.XamlReader]::Parse((New-DialogXaml 'INSTALL APPS' "VIA WINGET (MICROSOFT'S PACKAGE MANAGER)" 640 $body))
        $dlg.Owner = $window; Set-DialogLook $dlg @{ InClear = 'GhostBtn'; InCancel = 'GhostBtn'; InGo = 'ApplyBtn' }
        $list  = $dlg.FindName("InList")
        $count = $dlg.FindName("InCount")
        $goBtn = $dlg.FindName("InGo")
        $amber = $script:BrushAmber   # captured: $script: inside a GetNewClosure block is the closure's own scope
        $h1 = $window.TryFindResource('H1')   # the main window's red "//" section tag
        $boxes = New-Object System.Collections.Generic.List[object]
        foreach ($grp in $script:AppCatalog) {
            $h = New-Object System.Windows.Controls.ContentControl
            if ($h1) { $h.Style = $h1 }
            $h.Content = $grp.Cat
            $h.Margin = New-Object System.Windows.Thickness(0, 10, 4, 6)
            [void]$list.Children.Add($h)
            $ug = New-Object System.Windows.Controls.Primitives.UniformGrid
            $ug.Columns = 2
            foreach ($a in $grp.Apps) {
                $cb = New-Object System.Windows.Controls.CheckBox
                $cb.Content = $a[1]; $cb.Tag = $a[0]; $cb.ToolTip = "winget ID: $($a[0])"
                $cb.FontSize = 13
                $cb.Margin = New-Object System.Windows.Thickness(2, 3, 2, 3)
                [void]$ug.Children.Add($cb); $boxes.Add($cb)
            }
            [void]$list.Children.Add($ug)
        }
        $disarm = { if ($goBtn.Tag -eq "ARMED") { $goBtn.Tag = $null; $goBtn.Content = "INSTALL SELECTED"; $goBtn.ClearValue([System.Windows.Controls.Control]::BackgroundProperty) } }.GetNewClosure()
        $refreshCount = {
            $n = 0; foreach ($c in $boxes) { if ($c.IsChecked) { $n++ } }
            $count.Text = "$n of $($boxes.Count) selected"
            & $disarm
        }.GetNewClosure()
        & $refreshCount
        foreach ($c in $boxes) { $c.Add_Click($refreshCount) }
        $dlg.FindName("InClear").Add_Click({ foreach ($c in $boxes) { $c.IsChecked = $false }; & $refreshCount }.GetNewClosure())
        $dlg.FindName("InCancel").Add_Click({ Invoke-UiSafe 'Install Apps CANCEL' { $dlg.Close() } }.GetNewClosure())
        # Two-step confirm, like Debloat's REMOVE. Never a modal.
        $goBtn.Add_Click({ Invoke-UiSafe 'Install Apps INSTALL' {
            $sel = @(); foreach ($c in $boxes) { if ($c.IsChecked) { $sel += [PSCustomObject]@{ Id = "$($c.Tag)"; Name = "$($c.Content)" } } }
            if ($sel.Count -eq 0) { $count.Text = "Nothing selected."; & $disarm; return }
            if ($goBtn.Tag -ne "ARMED") {
                $goBtn.Tag = "ARMED"; $goBtn.Content = "CONFIRM INSTALL ($($sel.Count))"
                $goBtn.Background = $amber   # the confirm colour everywhere
                $count.Text = "Click CONFIRM to download and install $($sel.Count) app(s) from the internet."
                return
            }
            $SyncHash.InstallSelection = $sel
            $dlg.Close()
            Submit-RoninJob "WINGET_INSTALL"
        } }.GetNewClosure())
        $dlg.Add_Closed({ $script:InstallDlg = $null })
        $script:InstallDlg = $dlg
        $dlg.Show()
        try { [void]$dlg.Activate() } catch {}
        Write-Diag "INSTALL APPS: dialog open ($($boxes.Count) apps)" "UI"
    }
    $window.FindName("Btn_InstallApps").Add_Click({ Invoke-UiSafe 'Install Apps' { Show-AppInstaller } })


    # =====================================================================================
    # 8.0 BLACK ICE - the code-painted parts of the redesign: the shared tab header and its counters,
    # queued switches, per-tab nav counts, the rank card, the info panel's registry line, the status
    # bar. All UI-thread code. The engine only leaves data in $SyncHash and asks through the mailbox
    # ('RANK', 'COUNTS'); it never touches these elements (invariant 12).
    # A tweak checkbox's Tag is its queued mark: "Q" = the user changed it here and it now differs
    # from what the last audit found (the switch style draws it amber). The audit clears every mark.
    # =====================================================================================
    function New-FrozenBrush ([string]$Hex) { $b = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString($Hex)); $b.Freeze(); return $b }
    $script:BrushIdx = New-FrozenBrush '#5C6570'; $script:BrushMuted = New-FrozenBrush '#7D8692'; $script:BrushInk = New-FrozenBrush '#F4F6F8'
    $script:BrushAmber = New-FrozenBrush '#F2A93B'; $script:BrushIdle = New-FrozenBrush '#2E343C'; $script:BrushBlue = New-FrozenBrush '#93BCE3'
    $script:BrushAccent = New-FrozenBrush '#FF2E3A'; $script:BrushDojo = New-FrozenBrush '#D5DBE1'; $script:BrushDark = New-FrozenBrush '#12030A'
    $script:BrushChipOff = New-FrozenBrush '#14FFFFFF'; $script:BrushChipLit = New-FrozenBrush '#24FF2E3A'; $script:BrushChipLitText = New-FrozenBrush '#D9FF2E3A'
    $script:BrushGreen = New-FrozenBrush '#7FD9A0'; $script:BrushDotGreen = New-FrozenBrush '#5BD68A'; $script:BrushRed = New-FrozenBrush '#FF5A63'

    # Which checkboxes are tweak switches: every $RoninDB key, plus the Auto Optimize boxes (mapped to their tweak).
    $script:TweakBoxNames = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($k in @($RoninDB.Keys)) { [void]$script:TweakBoxNames.Add($k) }
    $script:AutoBoxKey = @{}
    foreach ($k in @($AutoMap.Keys)) { $script:AutoBoxKey[$AutoMap[$k]] = $k; [void]$script:TweakBoxNames.Add($AutoMap[$k]) }

    $script:TabMeta = [ordered]@{
        Tab_Auto      = @{ Title = 'AUTO OPTIMIZE';  Crumb = 'auto';        Ghost = 'AUTO';      Nav = 'Nav_Auto';      Apply = 'Btn_RunAuto';      Sub = 'Standard issue: the Ronin core protocol for all operatives.' }
        Tab_System    = @{ Title = 'SYSTEM CORE';    Crumb = 'system';      Ghost = 'SYSTEM';    Nav = 'Nav_System';    Apply = 'Btn_RunSystem';    Sub = 'Fundamental Windows configuration.' }
        Tab_Gaming    = @{ Title = 'GAMING & GPU';   Crumb = 'gaming';      Ghost = 'GAMING';    Nav = 'Nav_Gaming';    Apply = 'Btn_RunGaming';    Sub = 'Frame pacing, input latency and GPU scheduling.' }
        Tab_Handheld  = @{ Title = 'HANDHELD';       Crumb = 'handheld';    Ghost = 'HANDHELD';  Nav = 'Nav_Handheld';  Apply = 'Btn_RunHandheld';  Sub = 'Optimizations for ROG Ally, Legion Go, MSI Claw and Steam Deck.' }
        Tab_Privacy   = @{ Title = 'PRIVACY SHIELD'; Crumb = 'privacy';     Ghost = 'PRIVACY';   Nav = 'Nav_Privacy';   Apply = 'Btn_RunPrivacy';   Sub = 'Advanced telemetry blocking and data protection.' }
        Tab_Advanced  = @{ Title = 'ADVANCED TOOLS'; Crumb = 'advanced';    Ghost = 'ADVANCED';  Nav = 'Nav_Advanced';  Apply = 'Btn_RunAdvanced';  Sub = 'Expert tweaks for low latency and deep optimization.' }
        Tab_Maint     = @{ Title = 'MAINTENANCE';    Crumb = 'maintenance'; Ghost = 'REPAIR';    Nav = 'Nav_Maint';     Apply = $null;              Sub = 'Repair, clean up, and see (or undo) everything Ronin changed.' }
        Tab_Declutter = @{ Title = 'DECLUTTER';      Crumb = 'declutter';   Ghost = 'DECLUTTER'; Nav = 'Nav_Declutter'; Apply = 'Btn_RunDeclutter'; Sub = 'Ads, nags and surprise restarts out. Your PC, your rules - every change reverts.' }
    }
    # Each Apply button's own label, so "APPLY 3 CHANGES" can go back to it when nothing is queued.
    $script:ApplyLabels = @{}
    foreach ($tn in @($script:TabMeta.Keys)) { $an = $script:TabMeta[$tn].Apply; if ($an) { $ab = $window.FindName($an); if ($ab) { $script:ApplyLabels[$an] = "$($ab.Content)" } } }

    # What the last audit found for this switch: $true / $false, or $null before the first audit.
    function Get-AuditState ($Box) {
        if (-not $Box -or -not $Box.Name) { return $null }
        $key = if ($script:AutoBoxKey.ContainsKey($Box.Name)) { $script:AutoBoxKey[$Box.Name] } else { $Box.Name }
        $sc = $SyncHash.StatusCache
        if (-not $sc -or -not $sc.ContainsKey($key)) { return $null }
        $v = $sc[$key]
        return [bool](($v -is [bool] -and $v) -or "$v" -eq 'True')
    }
    function Set-QueueMark ($Box) {
        $st = Get-AuditState $Box
        $q = ($null -ne $st -and $Box.IsEnabled -and ([bool]$Box.IsChecked) -ne $st)
        if ($q) { if ("$($Box.Tag)" -ne 'Q') { $Box.Tag = 'Q' } } elseif ("$($Box.Tag)" -eq 'Q') { $Box.Tag = $null }
    }
    # A switch the user can't see (a collapsed vendor section, a hidden Auto row) doesn't count.
    function Test-ShownInTab ($El) {
        $p = $El
        while ($p -and -not ($p -is [System.Windows.Controls.TabItem])) {
            if ($p -is [System.Windows.UIElement] -and $p.Visibility -eq 'Collapsed') { return $false }
            $p = [System.Windows.LogicalTreeHelper]::GetParent($p)
        }
        return $true
    }
    function Get-TabTweakBoxes ($Tab) {
        if (-not $Tab) { return ,@() }
        if (-not $script:TabBoxCache) { $script:TabBoxCache = @{} }
        if (-not $script:TabBoxCache.ContainsKey($Tab.Name)) {
            $found = Find-Controls-Logical $Tab   # assign, never pipe a function's array
            $script:TabBoxCache[$Tab.Name] = @(foreach ($c in @($found)) { if ($c -is [System.Windows.Controls.CheckBox] -and $c.Name -and $script:TweakBoxNames.Contains($c.Name)) { $c } })
        }
        return ,$script:TabBoxCache[$Tab.Name]
    }
    # On = switches the audit found on; Queued = switches changed here and not applied (a twin pair counts once,
    # as it does in the Apply preview); Reboot = queued ones that need a restart.
    function Get-TabCounts ($Tab) {
        $r = @{ On = 0; Total = 0; Queued = 0; Reboot = 0 }
        $seen = @{}
        $boxes = Get-TabTweakBoxes $Tab
        foreach ($b in @($boxes)) {
            if (-not (Test-ShownInTab $b)) { continue }
            $st = Get-AuditState $b
            if ($null -ne $st) { $r.Total++; if ($st) { $r.On++ } }
            if ("$($b.Tag)" -ne 'Q') { continue }
            $key = if ($script:AutoBoxKey.ContainsKey($b.Name)) { $script:AutoBoxKey[$b.Name] } else { $b.Name }
            $tw = if ($RoninDB.ContainsKey($key)) { $RoninDB[$key].Twin } else { $null }
            if ($tw -and $seen.ContainsKey($tw)) { continue }
            $seen[$key] = $true
            $r.Queued++
            if ($RoninDB.ContainsKey($key) -and $RoninDB[$key].Reboot) { $r.Reboot++ }
        }
        return $r
    }
    function Set-NavCount ($NavName, $Counts) {
        $nb = $window.FindName($NavName); if (-not $nb) { return }
        try { [void]$nb.ApplyTemplate() } catch {}
        $t = $nb.Template.FindName("Count", $nb); if (-not $t) { return }
        $t.Text = if ($Counts.Total -gt 0) { "$($Counts.On)/$($Counts.Total)" } else { "" }
    }
    function Update-NavCounts {
        foreach ($tn in @($script:TabMeta.Keys)) { $tab = $window.FindName($tn); if ($tab) { Set-NavCount $script:TabMeta[$tn].Nav (Get-TabCounts $tab) } }
    }
    # The header's ACTIVE / QUEUED / REBOOT tiles, DISCARD, this tab's nav count, and its Apply button
    # ("APPLY 3 CHANGES" + hazard stripes while something is queued; a preview waiting for its confirm is left alone).
    function Update-TabCounts {
        $tab = $window.FindName("MainTabs").SelectedItem
        if (-not $tab) { return }
        $m = $script:TabMeta[$tab.Name]
        $c = Get-TabCounts $tab
        $window.FindName("Kpi_Active").Text = if ($c.Total -gt 0) { "$($c.On)/$($c.Total)" } else { "--" }
        $kq = $window.FindName("Kpi_Queued"); $kq.Text = "$($c.Queued)"; $kq.Foreground = if ($c.Queued) { $script:BrushAmber } else { $script:BrushMuted }
        $window.FindName("KpiBar_Queued").Fill = if ($c.Queued) { $script:BrushAmber } else { $script:BrushIdle }
        $kr = $window.FindName("Kpi_Reboot"); $kr.Text = "$($c.Reboot)"; $kr.Foreground = if ($c.Reboot) { $script:BrushBlue } else { $script:BrushMuted }
        $window.FindName("KpiBar_Reboot").Fill = if ($c.Reboot) { $script:BrushBlue } else { $script:BrushIdle }
        $window.FindName("Btn_Discard").Visibility = if ($c.Queued) { "Visible" } else { "Collapsed" }
        if (-not $m) { return }
        Set-NavCount $m.Nav $c
        if ($m.Apply) {
            $btn = $window.FindName($m.Apply)
            if ($btn -and $script:ApplyLabels.ContainsKey($m.Apply)) {
                if ("$($btn.Tag)" -ne 'ARMED' -and "$($btn.Tag)" -ne 'FLASH') {
                    $btn.Content = if ($c.Queued -eq 1) { "APPLY 1 CHANGE" } elseif ($c.Queued -gt 1) { "APPLY $($c.Queued) CHANGES" } else { $script:ApplyLabels[$m.Apply] }
                }
                try { [void]$btn.ApplyTemplate(); $hz = $btn.Template.FindName("Hazard", $btn); if ($hz) { $hz.Visibility = if ($c.Queued -and "$($btn.Tag)" -ne 'ARMED') { "Visible" } else { "Collapsed" } } } catch {}
            }
        }
    }
    # A user click on a tweak switch (wired in Bind-InfoDojo). Twins are one Windows switch, so the partner
    # moves with it - exactly what Resolve-TwinTasks does to the batch at Apply.
    function Invoke-TweakClicked ($Box) {
        if (-not $script:AutoBoxKey.ContainsKey($Box.Name) -and $RoninDB.ContainsKey($Box.Name) -and $RoninDB[$Box.Name].Twin) {
            $tw = $window.FindName($RoninDB[$Box.Name].Twin)
            if ($tw -is [System.Windows.Controls.CheckBox] -and $tw.IsEnabled -and $tw.IsChecked -ne $Box.IsChecked) { $tw.IsChecked = $Box.IsChecked; Set-QueueMark $tw }
        }
        Set-QueueMark $Box
        # The preview no longer times out, so a click on a switch retires it: the button goes back to
        # "APPLY N CHANGES" with the new count instead of offering a stale one.
        if ($script:ApplyOriginal.Count) { Reset-ApplyButtons }
        Update-TabCounts
    }
    # DISCARD: this tab's queued switches go back to what the audit found. Nothing on the PC changes.
    function Invoke-DiscardQueued {
        $tab = $window.FindName("MainTabs").SelectedItem
        $n = 0
        $boxes = Get-TabTweakBoxes $tab
        foreach ($b in @($boxes)) {
            if ("$($b.Tag)" -ne 'Q') { continue }
            $st = Get-AuditState $b
            if ($null -ne $st) { $b.IsChecked = $st; $n++ }
            $b.Tag = $null
        }
        Reset-ApplyButtons
        Update-TabCounts
        if ($n) { Log "Put $n switch$(if ($n -ne 1) { 'es' }) back to how this PC is set. Nothing was changed on the PC." }
    }
    $window.FindName("Btn_Discard").Add_Click({ Invoke-UiSafe 'Btn_Discard Click' { Invoke-DiscardQueued } })

    # Header: title, subtitle, the big outlined word behind it, the status bar's ~/tab, a few cursor blinks.
    function Set-HeaderGhost ([string]$Word) {
        $p = $window.FindName("Hdr_Ghost"); if (-not $p) { return }
        if (-not $script:GhostCache) { $script:GhostCache = @{} }
        if (-not $script:GhostCache.ContainsKey($Word)) {
            $tf = New-Object System.Windows.Media.Typeface((New-Object System.Windows.Media.FontFamily('Bahnschrift')), [System.Windows.FontStyles]::Normal, [System.Windows.FontWeights]::Bold, [System.Windows.FontStretches]::Condensed)
            $ft = New-Object System.Windows.Media.FormattedText($Word, [Globalization.CultureInfo]::InvariantCulture, [System.Windows.FlowDirection]::LeftToRight, $tf, 112, [System.Windows.Media.Brushes]::White, 1.0)
            $g = $ft.BuildGeometry((New-Object System.Windows.Point(0, 0))); $g.Freeze()
            $script:GhostCache[$Word] = $g
        }
        $p.Data = $script:GhostCache[$Word]
    }
    # Six blinks, then a steady block: an endless animation would redraw the (layered) window forever.
    function Start-CursorBlink {
        $cur = $window.FindName("Hdr_Cursor"); if (-not $cur) { return }
        if (-not [System.Windows.SystemParameters]::ClientAreaAnimation) { return }
        $a = New-Object System.Windows.Media.Animation.DoubleAnimationUsingKeyFrames
        [void]$a.KeyFrames.Add((New-Object System.Windows.Media.Animation.DiscreteDoubleKeyFrame(1.0, [System.Windows.Media.Animation.KeyTime]::FromTimeSpan([TimeSpan]::Zero))))
        [void]$a.KeyFrames.Add((New-Object System.Windows.Media.Animation.DiscreteDoubleKeyFrame(0.0, [System.Windows.Media.Animation.KeyTime]::FromTimeSpan([TimeSpan]::FromMilliseconds(550)))))
        $a.Duration = New-Object System.Windows.Duration([TimeSpan]::FromMilliseconds(1100))
        $a.RepeatBehavior = New-Object System.Windows.Media.Animation.RepeatBehavior(6.0)
        $a.FillBehavior = [System.Windows.Media.Animation.FillBehavior]::Stop
        [System.Windows.Media.Animation.Timeline]::SetDesiredFrameRate($a, 10)
        $cur.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $a)
    }
    function Update-TabHeader ($Tab) {
        if (-not $Tab) { $Tab = $window.FindName("MainTabs").SelectedItem }
        if (-not $Tab) { return }
        $m = $script:TabMeta[$Tab.Name]; if (-not $m) { return }
        $window.FindName("Hdr_Title").Text = $m.Title
        $window.FindName("Hdr_Sub").Text = $m.Sub
        $st = $window.FindName("Txt_StatusTab"); if ($st) { $st.Text = "~/$($m.Crumb)" }
        try { Set-HeaderGhost $m.Ghost } catch {}
        Start-CursorBlink
        Update-TabCounts
    }

    # Rank card, painted from what the audit left in $SyncHash (mailbox 'RANK').
    function Update-RankCard {
        $tier = "$($SyncHash.RankTier)"; if (-not $tier) { return }
        $window.FindName("Txt_RankLetter").Text = $tier
        $window.FindName("Txt_RankNote").Text = "$($SyncHash.RankNote)"
        $col = switch ($tier) { 'S' { '#FF2E3A' } 'A' { '#FF2E3A' } 'B' { '#F2A93B' } default { '#5C6570' } }
        $c1 = [System.Windows.Media.ColorConverter]::ConvertFromString($col)
        $c2 = [System.Windows.Media.Color]::FromRgb([byte]($c1.R * 0.5), [byte]($c1.G * 0.5), [byte]($c1.B * 0.5))
        $window.FindName("Rank_Hex").Fill = New-Object System.Windows.Media.LinearGradientBrush($c1, $c2, 70.0)
        $badge = $window.FindName("Rank_Badge")
        if ($badge -and $badge.Effect) { $badge.Effect.Color = $c1; $badge.Effect.Opacity = $(if ($tier -eq 'C') { 0.0 } else { 0.55 }) }
        $lit = New-Object System.Windows.Media.SolidColorBrush($c1); $lit.Freeze()
        $order = @('C', 'B', 'A', 'S'); $chips = @('Rank_C', 'Rank_B', 'Rank_A', 'Rank_S'); $at = [array]::IndexOf($order, $tier)
        for ($i = 0; $i -lt $order.Count; $i++) {
            $chip = $window.FindName($chips[$i]); if (-not $chip) { continue }
            if ($i -lt $at) { $chip.Background = $script:BrushChipLit; $chip.Child.Foreground = $script:BrushChipLitText }
            elseif ($i -eq $at) { $chip.Background = $lit; $chip.Child.Foreground = $script:BrushDark }
            else { $chip.Background = $script:BrushChipOff; $chip.Child.Foreground = $script:BrushIdx }
        }
    }

    # Info panel. The registry line is read from the tweak's own definition: its first Spec row, or the first
    # literal Set-Reg in its Apply ("+N more" when it writes several). Nothing is shown when it isn't a plain value.
    function Format-RegPath ([string]$P) {
        $p2 = $P -replace '^HKLM:\\', 'HKLM\' -replace '^HKCU:\\', 'HKCU\' -replace '^Registry::HKEY_LOCAL_MACHINE\\', 'HKLM\' -replace '^Registry::HKEY_CURRENT_USER\\', 'HKCU\'
        $parts = $p2 -split '\\'
        if ($parts.Count -gt 5) { $p2 = ($parts[0..1] -join '\') + '\...\' + ($parts[($parts.Count - 2)..($parts.Count - 1)] -join '\') }
        return $p2
    }
    function Get-RegTarget ([string]$Name) {
        if (-not $Name) { return "" }
        $key = if ($script:AutoBoxKey.ContainsKey($Name)) { $script:AutoBoxKey[$Name] } else { $Name }
        if (-not $RoninDB.ContainsKey($key)) { return "" }
        if (-not $script:RegTargetCache) { $script:RegTargetCache = @{} }
        if ($script:RegTargetCache.ContainsKey($key)) { return $script:RegTargetCache[$key] }
        $out = ""
        try {
            $e = $RoninDB[$key]
            if ($e.Spec -and @($e.Spec).Count) {
                $rows = @($e.Spec); $s = $rows[0]
                $out = "$(Format-RegPath $s.P)  $($s.N) = $($s.V)"
                if ($rows.Count -gt 1) { $out += "  (+$($rows.Count - 1) more)" }
            } elseif ($e.Apply) {
                $all = [regex]::Matches($e.Apply.ToString(), 'Set-Reg\s+"([^"$]+)"\s+"([^"$]+)"\s+("[^"$]*"|[^\s;})$]+)')
                if ($all.Count) {
                    $m0 = $all[0]
                    $out = "$(Format-RegPath $m0.Groups[1].Value)  $($m0.Groups[2].Value) = $($m0.Groups[3].Value)"
                    if ($all.Count -gt 1) { $out += "  (+$($all.Count - 1) more)" }
                }
            }
        } catch {}
        $script:RegTargetCache[$key] = $out
        return $out
    }
    function Show-DojoInfo ($Ctrl, [switch]$Pinned) {
        $d = $Global:RoninDojo; if (-not $d) { return }
        $title = $window.FindName("Txt_DojoTitle"); $reg = $window.FindName("Txt_DojoReg")
        if (-not $Ctrl) {
            $d.Text = "Hover over any tweak to learn more..."; $d.Foreground = $script:BrushMuted
            if ($title) { $title.Text = "HOVER A TWEAK" }; if ($reg) { $reg.Text = "" }
            return
        }
        $t = $Ctrl.ToolTip
        $msg = if ($t -is [System.Windows.Controls.ToolTip]) { "$($t.Content)" } else { "$t" }
        $d.Text = if ($Pinned) { "$msg (PINNED - right-click to unpin)" } else { $msg }
        $d.Foreground = if ($Pinned) { $script:BrushBlue } else { $script:BrushDojo }
        if ($title) { $lbl = if ($Ctrl.Content -is [string]) { $Ctrl.Content } else { $Ctrl.Name }; $title.Text = "$lbl".ToUpper() }
        if ($reg) { $reg.Text = Get-RegTarget $Ctrl.Name }
    }

    # Status bar: a short CPU name, the console's newest line without its timestamp.
    function Format-CpuName ([string]$N) {
        $s = $N -replace '\((R|TM|tm|r)\)', '' -replace '\bCPU\b', '' -replace '\bProcessor\b', '' -replace '\b\d+-Core\b', '' -replace 'with Radeon.*$', '' -replace '@.*$', ''
        return (($s -replace '\s+', ' ').Trim())
    }
    function Format-ConsoleLast ([string]$L) {
        $s = "$L".Trim() -replace '^>\s*', '' -replace '^\[\d{4}-\d\d-\d\d \d\d:\d\d:\d\d\]\s*', ''
        return $s
    }
    $script:StatusCaret = $window.FindName("Status_Caret"); $script:BarRam = $window.FindName("Bar_Ram")
    $script:EngineStateTxt = $window.FindName("Txt_EngineState"); $script:EngineDot = $window.FindName("Dot_Engine")
    $script:CaretTick = 0; $script:EngineStateShown = ''
    # online / busy / stalled - the watchdog sets $script:EngineStalled; busy = a job is running.
    function Update-EngineState {
        $busy = ("$($SyncHash.CurrentJob)" -and "$($SyncHash.CurrentJob)" -ne 'idle')
        $state = if ($script:EngineStalled) { 'stalled' } elseif ($busy) { 'busy' } else { 'online' }
        if ($script:StatusCaret) { $script:CaretTick = ($script:CaretTick + 1) % 6; $script:StatusCaret.Opacity = $(if ($busy -and $script:CaretTick -ge 3) { 0.0 } else { 1.0 }) }
        if ($state -eq $script:EngineStateShown -or -not $script:EngineStateTxt) { return }
        $script:EngineStateShown = $state
        switch ($state) {
            'stalled' { $script:EngineStateTxt.Text = 'ENGINE NOT RESPONDING'; $script:EngineStateTxt.Foreground = $script:BrushRed; $script:EngineDot.Fill = $script:BrushRed }
            'busy'    { $script:EngineStateTxt.Text = 'ENGINE WORKING';        $script:EngineStateTxt.Foreground = $script:BrushAmber; $script:EngineDot.Fill = $script:BrushAmber }
            default   { $script:EngineStateTxt.Text = 'ENGINE ONLINE';         $script:EngineStateTxt.Foreground = $script:BrushGreen; $script:EngineDot.Fill = $script:BrushDotGreen }
        }
        try { $script:EngineDot.Effect.Color = $script:EngineDot.Fill.Color } catch {}
    }

    # Dialogs (Debloat Center, batch summary, Startup Apps, Install Apps) use the main window's switches, not
    # Windows' white boxes. A Style is shareable between windows on the same thread.
    # 8.0 Black Ice: also its tooltips, no-stock-chrome buttons and a dark scrollbar (Install Apps showed Windows'
    # light grey one), and $Styles names a keyed style per button ({ DbGo = 'ApplyBtn'; DbCancel = 'GhostBtn' }) -
    # set from code, because a dialog parsed on its own can't see the main window's StaticResources.
    function Set-DialogLook ($Dlg, [hashtable]$Styles) {
        foreach ($ty in @([System.Windows.Controls.CheckBox], [System.Windows.Controls.Button], [System.Windows.Controls.ToolTip])) {
            try { $st = $window.TryFindResource($ty); if ($st -and -not $Dlg.Resources.Contains($ty)) { $Dlg.Resources.Add($ty, $st) } } catch {}
        }
        try {
            $sb = $window.TryFindResource('DlgScrollBar'); $sbt = [System.Windows.Controls.Primitives.ScrollBar]
            if ($sb -and -not $Dlg.Resources.Contains($sbt)) { $Dlg.Resources.Add($sbt, $sb) }
        } catch {}
        if ($Styles) {
            foreach ($n in @($Styles.Keys)) {
                try { $c = $Dlg.FindName($n); $s = $window.TryFindResource($Styles[$n]); if ($c -and $s) { $c.Style = $s } } catch {}
            }
        }
    }

    # Short windows (a 7" 1080p handheld at 150% has ~672 px): drop the header subtitle and show two description
    # lines, so the switches are drawn no smaller than in 8.0's first layout. The tooltip still has it all.
    function Set-CompactLayout {
        $s = 1.0; try { $lt = $window.Content.LayoutTransform; if ($lt -is [System.Windows.Media.ScaleTransform] -and $lt.ScaleY -gt 0) { $s = $lt.ScaleY } } catch {}
        $compact = (($window.ActualHeight / $s) -lt 720)
        if ($compact -eq $script:CompactShown) { return }
        $script:CompactShown = $compact
        $window.FindName("Hdr_Sub").Visibility = if ($compact) { "Collapsed" } else { "Visible" }
        $d = $window.FindName("InfoDojo"); if ($d) { $d.Height = if ($compact) { 29 } else { 44 } }
    }
    $script:CompactShown = $null
    $window.Add_SizeChanged({ Invoke-UiSafe 'window SizeChanged' { Set-CompactLayout } })

    # Full engine log: the status bar's LOG button (or Esc / X to close).
    function Set-LogPanel ([bool]$Open) {
        $lp = $window.FindName("LogPanel"); if (-not $lp) { return }
        $lp.Visibility = if ($Open) { "Visible" } else { "Collapsed" }
        if ($Open) { $lp.UpdateLayout(); if ($SyncHash.Scroll) { $SyncHash.Scroll.ScrollToEnd() } }
    }
    $window.FindName("Btn_Log").Add_Click({ Invoke-UiSafe 'Btn_Log Click' { Set-LogPanel ($window.FindName("LogPanel").Visibility -ne "Visible") } })
    $window.FindName("Btn_LogClose").Add_Click({ Invoke-UiSafe 'Btn_LogClose Click' { Set-LogPanel $false } })
    $window.FindName("Status_Msg").Add_MouseLeftButtonUp({ Invoke-UiSafe 'Status_Msg Click' { Set-LogPanel ($window.FindName("LogPanel").Visibility -ne "Visible") } })
    $sp = $window.FindName("SearchPlaceholder"); if ($sp) { $sp.Text = "search $($RoninDB.Count) tweaks..." }

    # 8.0: apply what the engine left in its mailbox - console lines, one-shot UI requests, sensor labels.
    # Runs on the UI thread from a UI-made timer, so no engine code ever runs here (see LogQueue above).
    function Invoke-EngineMailbox {
        try {
            $q = $SyncHash.LogQueue
            if ($q -and -not $q.IsEmpty -and $SyncHash.Console) {
                $sb = New-Object System.Text.StringBuilder; $line = $null; $lastLine = $null
                while ($q.TryDequeue([ref]$line)) { [void]$sb.Append("`n").Append($line); $lastLine = $line }   # a failed TryDequeue nulls $line
                $existing = "$($SyncHash.Console.Text)"
                # Cap console growth (the text is rebuilt on every append): keep the newest ~45k chars.
                if ($existing.Length -gt 60000) { $existing = $existing.Substring($existing.Length - 45000); $nl = $existing.IndexOf("`n"); if ($nl -ge 0) { $existing = $existing.Substring($nl + 1) } }
                $SyncHash.Console.Text = $existing + $sb.ToString()
                if ($SyncHash.Scroll) { $SyncHash.Scroll.ScrollToEnd() }
                if ($SyncHash.ConsoleLast -and $lastLine) { $SyncHash.ConsoleLast.Text = Format-ConsoleLast $lastLine }   # 8.0 status bar
            }
            $rq = $SyncHash.UiRequests; $r = $null
            while ($rq -and $rq.TryDequeue([ref]$r)) {
                if ($r -eq 'RESET_BANNER') { $window.FindName("ResetBannerText").Text = "$($SyncHash.ResetBannerMsg)"; $window.FindName("Banner_Reset").Visibility = "Visible" }
                elseif ($r -eq 'EXPLORER_BANNER') { $window.FindName("Banner_Explorer").Visibility = "Visible" }
                elseif ($r -eq 'RECOVER_UI') { $t = $window.FindName("MainTabs"); if ($t) { $t.IsEnabled = $true; $t.Opacity = 1.0 }; if ($SyncHash.ProgBar) { $SyncHash.ProgBar.Visibility = "Collapsed" } }
                elseif ($r -eq 'RANK') { try { Update-RankCard } catch {} }                         # 8.0: after every audit
                elseif ($r -eq 'COUNTS') { try { Update-NavCounts; Update-TabCounts } catch {} }    # 8.0: after every audit
            }
            if ($SyncHash.SensorRam -and $SyncHash.RamStatus) { $txt = "$($SyncHash.SensorRam)"; if ($SyncHash.RamStatus.Text -ne $txt) { $SyncHash.RamStatus.Text = $txt } }
            if ($null -ne $SyncHash.SensorRamPct -and $script:BarRam) { $w = [Math]::Round(40 * [Math]::Max(0, [Math]::Min(100, [double]$SyncHash.SensorRamPct)) / 100); if ($script:BarRam.Width -ne $w) { $script:BarRam.Width = $w } }
            if ($SyncHash.SensorCpu -and $SyncHash.CpuStatus) { $cpu = Format-CpuName "$($SyncHash.SensorCpu)"; if ($SyncHash.CpuStatus.Text -ne $cpu) { $SyncHash.CpuStatus.Text = $cpu } }
            Update-EngineState
        } catch {}
    }
    $script:MailboxTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:MailboxTimer.Interval = [TimeSpan]::FromMilliseconds(150)
    $script:MailboxTimer.Add_Tick({ Invoke-EngineMailbox })
    $script:MailboxTimer.Start()

    # One light UI-thread poll: refresh the changes list when the engine has changed the ledger and
    # the Maintenance tab is showing. (The engine bumps $SyncHash.LedgerVersion; it never calls in.)
    $script:LastLedgerSeen = -1
    $script:LastWuLedgerSeen = -1
    $script:UiPollTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:UiPollTimer.Interval = [TimeSpan]::FromSeconds(2)
    $script:UiPollTimer.Add_Tick({ Invoke-UiSafe 'UiPollTimer Tick' {
        # 8.0: UI liveness stamp, read by the engine's UI-thread watchdog (Start-RoninLoop).
        $SyncHash.UiBeat = Get-Date
        try {
            $sel = $window.FindName("MainTabs").SelectedItem
            if ($sel -and $sel.Name -eq "Tab_Maint" -and $SyncHash.LedgerVersion -ne $script:LastLedgerSeen) { Update-ChangesList }
            if ($sel -and $sel.Name -eq "Tab_Declutter" -and $SyncHash.LedgerVersion -ne $script:LastWuLedgerSeen) { $script:LastWuLedgerSeen = $SyncHash.LedgerVersion; Update-WuStatus }
        } catch {}
    } })
    $script:UiPollTimer.Start()

    # Windows build, for the reset alert's wording ("Windows updated to build X and undid...").
    try {
        $cv = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction Stop
        $build = "$($cv.CurrentBuild).$($cv.UBR)"
        $tb = $window.FindName("Txt_Build"); if ($tb) { $tb.Text = $build }   # 8.0 status bar
        $SyncHash.BuildChangedTo = if ($script:Settings.LastOsBuild -and $script:Settings.LastOsBuild -ne $build) { $build } else { $null }
        $script:Settings.LastOsBuild = $build
    } catch { $SyncHash.BuildChangedTo = $null }
    # 8.0: Ronin version, for the same check. A tweak whose status check a new version CORRECTED (8.0's
    # Variable Refresh Rate never actually worked before) reads "off" on the first launch after updating.
    # That is Ronin's change, not Windows undoing anything, so Invoke-ResetCheck says so in the console
    # instead of raising the "Windows undid your tweaks" banner. 7.x never recorded its version: no
    # record + an existing applied ledger = an upgrade.
    try {
        $hadLedger = $false; try { $hadLedger = (@(Get-AppliedMarks).Count -gt 0) } catch {}
        $SyncHash.RoninChangedFrom = if ($script:Settings.LastRonin -and $script:Settings.LastRonin -ne $Version) { $script:Settings.LastRonin }
                                     elseif (-not $script:Settings.LastRonin -and $hadLedger) { "an earlier version" } else { $null }
        $script:Settings.LastRonin = $Version
    } catch { $SyncHash.RoninChangedFrom = $null }

    $window.FindName("Btn_CleanTemp").Add_Click({ Submit-RoninJob ("MAINT_CLEAN") })
    $window.FindName("Btn_SFC").Add_Click({ Submit-RoninJob ("MAINT_SFC") })
    $window.FindName("Btn_DISM").Add_Click({ Submit-RoninJob ("MAINT_DISM") })
    $window.FindName("Btn_CleanUpdate").Add_Click({ Submit-RoninJob ("MAINT_UPDATE") })
    $window.FindName("Btn_NetReset").Add_Click({ Submit-RoninJob ("MAINT_NET") })
    $window.FindName("Btn_CheckDrivers").Add_Click({ Submit-RoninJob ("MAINT_DRIVERS") })
    $window.FindName("Btn_RestorePoint").Add_Click({ Submit-RoninJob ("MAINT_RESTORE") })
    $window.FindName("Btn_FullRepair").Add_Click({ Submit-RoninJob ("REPAIR_FULL") })
    $window.FindName("Btn_Battery").Add_Click({ Submit-RoninJob ("MAINT_BATTERY") })
    $window.FindName("Btn_Sleep").Add_Click({ Submit-RoninJob ("MAINT_SLEEP") })
    $window.FindName("Btn_Shader").Add_Click({ Submit-RoninJob ("MAINT_SHADER") })
    $window.FindName("Btn_VisualCpp").Add_Click({ Submit-RoninJob ("MAINT_VCREDIST") })
    $window.FindName("Btn_OpenBackups").Add_Click({ Submit-RoninJob ("MAINT_OPEN_BACKUPS") })
    # (Btn_Reclaim is wired in the 8.0 block: Invoke-ArmedButton.)
    $window.FindName("Btn_DiskClean").Add_Click({ Submit-RoninJob ("MAINT_DISKCLEAN") })
    $window.FindName("Btn_Trim").Add_Click({ Submit-RoninJob ("MAINT_TRIM") })
    $window.FindName("Btn_IconCache").Add_Click({ Submit-RoninJob ("MAINT_ICON") })
    $window.FindName("Btn_WuReset").Add_Click({ Submit-RoninJob ("MAINT_WURESET") })
    $window.FindName("Btn_StoreReset").Add_Click({ Submit-RoninJob ("MAINT_STORERESET") })
    # 8.0: it force-closes Steam / Epic (and with them any game they're running) - ask first.
    $window.FindName("Btn_GpuReset").Add_Click({ Invoke-UiSafe 'Btn_GpuReset Click' {
        Invoke-ArmedButton "Btn_GpuReset" "CONFIRM: CLOSE STEAM/EPIC" "RESET GPU DRIVER STACK force-closes Steam and the Epic Games Launcher (and any game they're running), clears GPU shader caches and rescans devices. Save your game first. Click CONFIRM within 12 seconds to go." { Submit-RoninJob ("MAINT_GPURESET") }
    } })
    

    $window.FindName("Btn_InPlaceUpgrade").Add_Click({ 
        if ($window.FindName("Global_ExpertMode").IsChecked) {
             $ans = [System.Windows.MessageBox]::Show($window, "This opens Microsoft's Windows 11 download page so you can run a repair install that keeps your personal files and apps. Continue?", "Project Ronin - Repair", [System.Windows.MessageBoxButton]::YesNo)
             if ("$ans" -eq "Yes") { Start-Process "https://www.microsoft.com/software-download/windows11" }
        }
    })

    # Reset All = undo exactly what RONIN changed, as a normal revert batch (Check-gated, each revert
    # verified, one Explorer restart, summary dialog). It used to run EVERY Revert in the database
    # unconditionally - disabling WSL/Hyper-V the user had enabled, re-enabling Recall, flipping
    # dark mode, etc.
    $window.FindName("Btn_UndoAll").Add_Click({
        if (-not $window.FindName("Global_ExpertMode").IsChecked) { return }
        $batch = Resolve-WuConflicts (Get-ResetAllBatch (Get-AppliedMarks) $SyncHash.StatusCache)   # 8.0: Off reverts before Pause
        if ($batch.Count -eq 0) {
            [System.Windows.MessageBox]::Show($window, "Nothing to undo: Ronin has no changes recorded on this PC.", "Project Ronin - Reset") | Out-Null
            return
        }
        $ans = [System.Windows.MessageBox]::Show($window,
            "Undo $($batch.Count) change(s) Ronin made on this PC?`n`nSettings you chose yourself - WSL, Hyper-V, dark mode, file extensions, hibernation and similar - are left alone. Every undo is checked and listed in the summary.",
            "Project Ronin - Reset", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
        if ("$ans" -eq "Yes") { Submit-RoninJob $batch }
    })

    $window.FindName("Btn_DNS_Cloud").Add_Click({ Submit-RoninJob ("DNS_Cloudflare") })
    $window.FindName("Btn_DNS_Google").Add_Click({ Submit-RoninJob ("DNS_Google") })
    $window.FindName("Btn_DNS_Quad9").Add_Click({ Submit-RoninJob ("DNS_Quad9") })
    $window.FindName("Btn_DNS_Auto").Add_Click({ Submit-RoninJob ("DNS_Auto") })

    # 8.0: fit the window to the screen. A 7" 1080p handheld at Windows' default 150% scaling has about
    # 1280x672 of usable space, and the 1100x730 window ran under the taskbar there - hiding the info
    # panel and the bottom of every tab. Too big = shrink it to the work area (the tab Viewbox scales
    # the content to match); CenterScreen then centres it within the work area.
    try {
        $wa = [System.Windows.SystemParameters]::WorkArea
        if ($window.Height -gt $wa.Height) { $window.Height = [Math]::Max($window.MinHeight, [Math]::Floor($wa.Height)) }
        if ($window.Width -gt $wa.Width) { $window.Width = [Math]::Max($window.MinWidth, [Math]::Floor($wa.Width)) }
    } catch {}

    $window.ShowDialog() | Out-Null
    # Run from an open PowerShell console, the process outlives the window - free the single-instance
    # lock so Ronin can be opened again from anywhere.
    try { if ($script:RoninMutex) { $script:RoninMutex.ReleaseMutex() } } catch {}
} Catch {
    $errMsg = $_.Exception.Message
    [System.Windows.Forms.MessageBox]::Show("CRITICAL LAUNCH ERROR:`n`n$errMsg", "Ronin Failed", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
}

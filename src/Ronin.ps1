# --- PROJECT RONIN: CONTROLLER v6.5.98 "SENTINEL" ---
# STATUS: GOLD MASTER // ENTERPRISE GRADE
# UPDATE: Synchronized with "Definitive Edition" UI (Boxed Layout).
# UPDATE: Hardened Logic Tree Traversal for deep-nested controls.
# PRIME DIRECTIVE: NO-REFACTOR (Logic Integrity Maintained).

$Version = "6.5.98"

Try {
    $ErrorActionPreference = "Stop"

    # --- 0. PROFESSIONAL BOOTSTRAP & PROCESS ELEVATION ---
    if ([System.Environment]::OSVersion.Version.Major -ge 6) {
        try { 
            [System.Runtime.InteropServices.Marshal]::PrelinkAll([System.Windows.Forms.Application])
            [System.Windows.Application]::SetHighDpiMode([System.Windows.Forms.HighDpiMode]::PerMonitorV2)
            # FORCE SOFTWARE RENDERING IF GPU IS UNSTABLE (Enterprise Stability)
            # [System.Windows.Media.RenderOptions]::ProcessRenderMode = [System.Windows.Interop.RenderMode]::SoftwareOnly 
        } catch {}
    }

    # Elevate UI Process Priority for "AAA" Smoothness
    try {
        $proc = Get-Process -Id $PID
        if ($proc.PriorityClass -eq "Normal") { $proc.PriorityClass = "AboveNormal" }
    } catch {}

    $LogPath = "$env:TEMP\Ronin_CrashLog.txt"
    Start-Transcript -Path $LogPath -Append -ErrorAction SilentlyContinue

    # --- 1. ADMIN CHECK & ROBUST PATHING ---
    # Resolve path correctly regardless of host (ISE, Console, VSCode)
    if ($PSCommandPath) { $CurrentPath = $PSCommandPath; $ScriptPath = Split-Path -Parent $CurrentPath }
    else { $CurrentPath = $MyInvocation.MyCommand.Definition; $ScriptPath = Split-Path -Parent $CurrentPath }

    # Fallback for complex hosting environments
    if ([string]::IsNullOrWhiteSpace($ScriptPath)) { $ScriptPath = $PWD.Path }

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        if ($CurrentPath) { 
            Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$CurrentPath`"" -Verb RunAs
            exit 
        } else { 
            Write-Warning "CRITICAL: Administrator privileges required."
            Pause
            exit 
        }
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
    # FIX: Force UTF8 reading and trim potential BOM/Whitespace issues
    $xamlContent = Get-Content $XamlPath -Raw -Encoding UTF8
    if ($xamlContent -match "^\s*<") { $xamlContent = $xamlContent.Trim() } 
    
    # Fix XML namespace issues for strict XAML parsing (PowerShell XAML Parser quirk fix)
    $xamlContent = $xamlContent -replace 'x:Name', 'Name'
    
    # SECURITY: Prohibit DTD processing to prevent XML Injection attacks
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
    
    # LAYOUT FIX: Updated to 730x1100 to match new Borderless Box Layout
    $window.Height = 730
    $window.Width = 1100

    # --- 4. THREAD SYNC & UNHANDLED EXCEPTION TRAP ---
    $sync = [Hashtable]::Synchronized(@{})
    $sync.Window = $window
    
    # TRAP: Catch silent UI thread crashes
    $window.Dispatcher.Add_UnhandledException({
        param($sender, $e)
        $e.Handled = $true
        $Err = $e.Exception.Message
        [System.IO.File]::AppendAllText("$env:TEMP\Ronin_UI_Errors.txt", "[$([DateTime]::Now)] UI ERROR: $Err`r`n")
    })
    
    $Global:RoninDojo = $window.FindName("InfoDojo")
    $script:DojoLock = $false 

    # MAP UI ELEMENTS
    $sync.Console = $window.FindName("ConsoleOutput")
    $sync.Scroll = $window.FindName("ConsoleScroll")
    $sync.InfoDojo = $window.FindName("InfoDojo")
    $sync.RamStatus = $window.FindName("Txt_RamStatus")
    $sync.CpuStatus = $window.FindName("Txt_CpuStatus")
    $sync.HealthRank = $window.FindName("Txt_HealthRank")
    $sync.HealthBar = $window.FindName("HealthBar")
    $sync.ProgBar = $window.FindName("ProgBar")
    $sync.SafeMode = $window.FindName("Global_SafeMode")
    $sync.RebootBanner = $window.FindName("Banner_Reboot")
    
    $sync.JobQueue = [System.Collections.Queue]::Synchronized([System.Collections.Queue]::new())
    $sync.Running = $true
    $sync.StatusCache = [Hashtable]::Synchronized(@{})
    $sync.ActiveTab = "Tab_Auto"

    # --- 4a. DIAGNOSTICS BINDING ---
    if ($sync.Console) {
        $sync.Console.Cursor = "Hand"
        $sync.Console.ToolTip = "Click to open full Crash Log (Notepad)"
        $sync.Console.Add_MouseLeftButtonUp({
            if (Test-Path $LogPath) { Invoke-Item $LogPath }
        })
    }

    # --- 5. BACKGROUND WORKER (CORE ENGINE) ---
    $runspace = [PowerShell]::Create()
    $RunspaceArgs = @{ SyncHash = $sync; ScriptRoot = $ScriptPath }

    $ScriptBlock = {
        param($ArgsHash)
        $SyncHash = $ArgsHash.SyncHash
        $Root     = $ArgsHash.ScriptRoot
        $ErrorActionPreference = "Continue"

        if (!(Test-Path HKCU:)) { New-PSDrive -Name HKCU -PSProvider Registry -Root HKEY_CURRENT_USER -ErrorAction SilentlyContinue | Out-Null }
        if (!(Test-Path HKLM:)) { New-PSDrive -Name HKLM -PSProvider Registry -Root HKEY_LOCAL_MACHINE -ErrorAction SilentlyContinue | Out-Null }

        $CorePath = Join-Path $Root "RoninCore.ps1"
        $DBPath   = Join-Path $Root "RoninDB.ps1"

        if (!(Test-Path $CorePath) -or !(Test-Path $DBPath)) {
            $SyncHash.Window.Dispatcher.Invoke({ [System.Windows.Forms.MessageBox]::Show("Critical Error: Missing RoninCore.ps1 or RoninDB.ps1") })
            return
        }

        . $CorePath
        . $DBPath

        Start-RoninLoop -SyncHash $SyncHash
    }
    
    $runspace.AddScript($ScriptBlock)
    $runspace.AddArgument($RunspaceArgs)
    $runspace.BeginInvoke()
    
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

    # DYNAMIC INFO DOJO BINDER (FIXED: REMOVED RIGHT-CLICK LOGIC)
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
                # CLICK (LEFT): Pinning
                $c.Add_PreviewMouseLeftButtonDown({
                    if ($Global:RoninDojo) {
                        $t = $this.ToolTip
                        $msg = if ($t -is [System.Windows.Controls.ToolTip]) { $t.Content } else { $t.ToString() }
                        $Global:RoninDojo.Text = "$msg (PINNED)"
                        $Global:RoninDojo.Foreground = [System.Windows.Media.Brushes]::Cyan
                        $script:DojoLock = $true
                    }
                })

                if ($c -is [System.Windows.Controls.CheckBox]) {
                    $c.Add_Click({ if ($this.Foreground -ne [System.Windows.Media.Brushes]::Yellow) { $this.Foreground = [System.Windows.Media.Brushes]::Yellow } })
                    # NOTE: Precision Strike (Right-Click) logic has been removed here for stability.
                }
                $c.Tag = "Bound"
            }
        }
    }

    $AllControls = Find-Controls-Flat $window

    # --- EXPERT MODE LOGIC ---
    $ExpertControls = @("Sys_Bloatware", "Sys_DeviceInstall", "Adv_Printing", "Adv_TimerOpt", "Sys_SearchIndex", "HH_VMP", "Btn_UndoAll", "Btn_InPlaceUpgrade")
    
    $window.FindName("Global_ExpertMode").Add_Checked({ 
        foreach ($name in $ExpertControls) {
            $c = $window.FindName($name)
            if ($c) { $c.IsEnabled = $true; $c.Opacity = 1.0 }
        }
        if ($Global:RoninDojo) {
            $Global:RoninDojo.Text = "EXPERT MODE: Dangerous tweaks unlocked. Proceed with caution."
            $Global:RoninDojo.Foreground = [System.Windows.Media.Brushes]::Red
            $script:DojoLock = $true
        }
    })

    $window.FindName("Global_ExpertMode").Add_Unchecked({ 
        foreach ($name in $ExpertControls) {
            $c = $window.FindName($name)
            if ($c) { $c.IsEnabled = $false; $c.Opacity = 0.5; if($c -is [System.Windows.Controls.CheckBox]){$c.IsChecked = $false} }
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
                    $script:DojoLock = $true
                }
            }
            else { 
                $hhBag.IsEnabled = $true; 
                $hhBag.Opacity = 1.0; 
                $hhBag.ToolTip = $origHHToolTip 
            }
        }
        $sysHib.Add_Checked($hibLockAction)
        $sysHib.Add_Unchecked($hibLockAction)
        $window.Dispatcher.InvokeAsync($hibLockAction, [System.Windows.Threading.DispatcherPriority]::ContextIdle)
    }

    # TAB GLOW UI
    function Update-TabUI ($ActiveBtn) {
        if ($window.FindName("SearchBox").Text.Length -gt 0) { return }
        $Tabs = @("Nav_Auto", "Nav_System", "Nav_Gaming", "Nav_Handheld", "Nav_Privacy", "Nav_Advanced", "Nav_Install", "Nav_Maint")
        foreach ($t in $Tabs) {
            $btn = $window.FindName($t)
            if ($btn) {
                $btn.Opacity = 1.0
                if ($btn.Name -eq $ActiveBtn.Name) {
                    $btn.Foreground = [System.Windows.Media.Brushes]::White
                    $btn.Template.FindName("AccentBar", $btn).Visibility = "Visible"
                    $btn.Effect = [System.Windows.Media.Effects.DropShadowEffect]::new()
                    $btn.Effect.Color = [System.Windows.Media.Color]::FromRgb(255, 46, 46)
                    $btn.Effect.BlurRadius = 15; $btn.Effect.ShadowDepth = 0; $btn.Effect.Opacity = 0.4
                } else {
                    $btn.Foreground = [System.Windows.Media.Brushes]::Gray
                    $btn.Template.FindName("AccentBar", $btn).Visibility = "Collapsed"
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
        $txt = $window.FindName("SearchBox").Text.ToLower()
        $ph = $window.FindName("SearchPlaceholder")
        
        # Unlock Dojo if searching
        if ($txt.Length -gt 0) { $ph.Visibility = "Collapsed"; $script:DojoLock = $false } else { $ph.Visibility = "Visible" }
        
        $SearchMap = @{ "Tab_Auto"="Nav_Auto"; "Tab_System"="Nav_System"; "Tab_Gaming"="Nav_Gaming"; "Tab_Handheld"="Nav_Handheld"; "Tab_Privacy"="Nav_Privacy"; "Tab_Advanced"="Nav_Advanced"; "Tab_Apps"="Nav_Install"; "Tab_Maint"="Nav_Maint" }
        
        # CLEAR SEARCH
        if ($txt.Length -eq 0) {
            foreach ($key in $SearchMap.Keys) {
                $tab = $window.FindName($key)
                $controls = Find-Controls-Logical $tab
                foreach ($c in $controls) {
                    $c.Opacity = 1.0; $c.Effect = $null
                    if ($c -is [System.Windows.Controls.ComboBox]) { $c.Foreground = [System.Windows.Media.Brushes]::Black }
                    elseif ($c -is [System.Windows.Controls.CheckBox] -and $c.IsChecked) { $c.Foreground = [System.Windows.Media.Brushes]::LimeGreen }
                    else { $c.Foreground = [System.Windows.Media.Brushes]::LightGray }
                }
            }
            $currTab = $window.FindName("MainTabs").SelectedItem
            if ($currTab) { $currBtnName = $SearchMap[$currTab.Name]; if ($currBtnName) { Update-TabUI ($window.FindName($currBtnName)) } }
            return
        }

        # PERFORM SEARCH & TRACK BEST TAB
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

        # --- FEATURE: TARGET LOCK (Auto-Tab Switch) ---
        if ($currentTabMatches -eq 0 -and $maxMatches -gt 0 -and $bestTabName) {
            $window.FindName("MainTabs").SelectedItem = $window.FindName($bestTabName)
        }
    })

    $window.FindName("SearchBox").Add_TextChanged({ $script:SearchTimer.Stop(); $script:SearchTimer.Start() })

    # NAVIGATION LOGIC
    $window.FindName("Nav_Auto").Add_Click({ $window.FindName("MainTabs").SelectedIndex = 0; Update-TabUI $this })
    $window.FindName("Nav_System").Add_Click({ $window.FindName("MainTabs").SelectedIndex = 1; Update-TabUI $this })
    $window.FindName("Nav_Gaming").Add_Click({ $window.FindName("MainTabs").SelectedIndex = 2; Update-TabUI $this })
    $window.FindName("Nav_Handheld").Add_Click({ $window.FindName("MainTabs").SelectedIndex = 3; Update-TabUI $this })
    $window.FindName("Nav_Privacy").Add_Click({ $window.FindName("MainTabs").SelectedIndex = 4; Update-TabUI $this })
    $window.FindName("Nav_Advanced").Add_Click({ $window.FindName("MainTabs").SelectedIndex = 5; Update-TabUI $this })
    $window.FindName("Nav_Install").Add_Click({ $window.FindName("MainTabs").SelectedIndex = 6; Update-TabUI $this })
    $window.FindName("Nav_Maint").Add_Click({ $window.FindName("MainTabs").SelectedIndex = 7; Update-TabUI $this })

    $window.FindName("MainTabs").Add_SelectionChanged({
        if ($window.FindName("MainTabs").SelectedItem) {
            $sync.ActiveTab = $window.FindName("MainTabs").SelectedItem.Name
            Bind-InfoDojo ($window.FindName("MainTabs").SelectedItem)
            if ($window.FindName("SearchBox").Text.Length -gt 0) { $script:SearchTimer.Stop(); $script:SearchTimer.Start() }
            else {
                $btnName = switch($sync.ActiveTab) {
                    "Tab_Auto" { "Nav_Auto" }; "Tab_System" { "Nav_System" }; "Tab_Gaming" { "Nav_Gaming" }
                    "Tab_Handheld" { "Nav_Handheld" }; "Tab_Privacy" { "Nav_Privacy" }; "Tab_Advanced" { "Nav_Advanced" }
                    "Tab_Apps" { "Nav_Install" }; "Tab_Maint" { "Nav_Maint" }
                }
                if ($btnName) { Update-TabUI ($window.FindName($btnName)) }
            }
            # FREE MEMORY AFTER HEAVY UI SWITCHING
            [System.GC]::Collect()
        }
    })

    # SMART INITIALIZATION
    $window.Add_ContentRendered({ 
        try {
            # --- UI LOCKDOWN INITIATED ---
            $tabs = $window.FindName("MainTabs")
            if ($tabs) {
                $tabs.IsEnabled = $false
                $tabs.Opacity = 0.5
            }
            if ($sync.Console) { $sync.Console.Text = "> SYSTEM AUDIT SEQUENCE INITIATED...`n> PLEASE WAIT..." }

            $sync.JobQueue.Enqueue("INIT"); $sync.JobQueue.Enqueue("AUDIT_APPS")
            Update-TabUI ($window.FindName("Nav_Auto")); Bind-InfoDojo ($window.FindName("Tab_Auto"))

            # --- MODEL DETECTION ---
            try {
                $cimComp = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
                if ($cimComp -and ($cimComp.Model -match "RC71|83[E-G]1|83S|Claw|Jupiter")) {
                    $window.FindName("MainTabs").SelectedIndex = 3 
                    Update-TabUI ($window.FindName("Nav_Handheld")); $sync.JobQueue.Enqueue("LOG_HANDHELD")
                }
            } catch {}

            # GPU VENDOR DETECTION
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
    
    $window.Add_Closed({ $sync.Running = $false; $runspace.Close(); $runspace.Dispose(); Stop-Transcript })

    # TASK HANDLING (FIX: USE LOGICAL TREE FOR ROBUSTNESS)
    function Get-Tasks ($Prefix) {
        $list = [System.Collections.ArrayList]::new()
        # FIX: Flat (Visual) -> Logical to ensure off-screen/unrendered controls are found
        $allControls = Find-Controls-Logical $window | Where-Object { $_.Name -and $_.Name.StartsWith($Prefix) }
        foreach ($c in $allControls) { 
            if ($c.IsEnabled) {
                if ($c -is [System.Windows.Controls.CheckBox]) { [void]$list.Add([PSCustomObject]@{Key=$c.Name; Action=if($c.IsChecked){"Apply"}else{"Revert"}}) }
                if ($c -is [System.Windows.Controls.ComboBox]) { [void]$list.Add([PSCustomObject]@{Key=$c.Name; Action="Apply"; Value=$c.SelectedIndex}) }
            }
        }
        return ,$list
    }

    $window.FindName("Btn_RestartExp").Add_Click({ $sync.JobQueue.Enqueue("RESTART_EXPLORER") })
    $window.FindName("Btn_Analyze").Add_Click({ $sync.JobQueue.Enqueue("AUDIT_SYSTEM") })
    $window.FindName("Btn_RunSystem").Add_Click({ $sync.JobQueue.Enqueue( (Get-Tasks "Sys_") ) })
    $window.FindName("Btn_RunGaming").Add_Click({ $sync.JobQueue.Enqueue( (Get-Tasks "Game_") ) })
    $window.FindName("Btn_RunHandheld").Add_Click({ $sync.JobQueue.Enqueue( (Get-Tasks "HH_") ) })
    $window.FindName("Btn_RunPrivacy").Add_Click({ $sync.JobQueue.Enqueue( (Get-Tasks "Priv_") ) })
    $window.FindName("Btn_RunAdvanced").Add_Click({ $sync.JobQueue.Enqueue( (Get-Tasks "Adv_") ) })
    
    $window.FindName("Btn_RunAuto").Add_Click({
        $j=[System.Collections.ArrayList]::new(); $controls = Find-Controls-Logical ($window.FindName("Tab_Auto"))
        $controls | ForEach-Object {
            if ($_ -is [System.Windows.Controls.CheckBox]) {
                 $dbKey = switch ($_.Name) {
                    "Auto_Visuals" { "Sys_VisualFX" }; "Auto_Turbo" { "Auto_Turbo" }; "Auto_Hags" { "Game_HAGS" }; "Auto_GameMode" { "Game_GameMode" }
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
        $sync.JobQueue.Enqueue($j)
    })

    # MAINTENANCE CLICKERS
    $window.FindName("Btn_CleanTemp").Add_Click({ $sync.JobQueue.Enqueue("MAINT_CLEAN") })
    $window.FindName("Btn_SFC").Add_Click({ $sync.JobQueue.Enqueue("MAINT_SFC") })
    $window.FindName("Btn_DISM").Add_Click({ $sync.JobQueue.Enqueue("MAINT_DISM") })
    $window.FindName("Btn_CleanUpdate").Add_Click({ $sync.JobQueue.Enqueue("MAINT_UPDATE") })
    $window.FindName("Btn_NetReset").Add_Click({ $sync.JobQueue.Enqueue("MAINT_NET") })
    $window.FindName("Btn_CheckDrivers").Add_Click({ $sync.JobQueue.Enqueue("MAINT_DRIVERS") })
    $window.FindName("Btn_RestorePoint").Add_Click({ $sync.JobQueue.Enqueue("MAINT_RESTORE") })
    $window.FindName("Btn_FullRepair").Add_Click({ $sync.JobQueue.Enqueue("REPAIR_FULL") })
    $window.FindName("Btn_Battery").Add_Click({ $sync.JobQueue.Enqueue("MAINT_BATTERY") })
    $window.FindName("Btn_Sleep").Add_Click({ $sync.JobQueue.Enqueue("MAINT_SLEEP") })
    $window.FindName("Btn_Shader").Add_Click({ $sync.JobQueue.Enqueue("MAINT_SHADER") })
    $window.FindName("Btn_VisualCpp").Add_Click({ $sync.JobQueue.Enqueue("MAINT_VCREDIST") })
    $window.FindName("Btn_OpenBackups").Add_Click({ $sync.JobQueue.Enqueue("MAINT_OPEN_BACKUPS") })
    $window.FindName("Btn_DiskClean").Add_Click({ $sync.JobQueue.Enqueue("MAINT_DISKCLEAN") })
    $window.FindName("Btn_Trim").Add_Click({ $sync.JobQueue.Enqueue("MAINT_TRIM") })
    $window.FindName("Btn_IconCache").Add_Click({ $sync.JobQueue.Enqueue("MAINT_ICON") })
    $window.FindName("Btn_WuReset").Add_Click({ $sync.JobQueue.Enqueue("MAINT_WURESET") })
    $window.FindName("Btn_StoreReset").Add_Click({ $sync.JobQueue.Enqueue("MAINT_STORERESET") })
    $window.FindName("Btn_GpuReset").Add_Click({ $sync.JobQueue.Enqueue("MAINT_GPURESET") })
    
    $window.FindName("Btn_BootUEFI").Add_Click({ $sync.JobQueue.Enqueue("BOOT_UEFI") })
    $window.FindName("Btn_BootRecovery").Add_Click({ $sync.JobQueue.Enqueue("BOOT_RECOVERY") })

    $window.FindName("Btn_InPlaceUpgrade").Add_Click({ 
        if ($window.FindName("Global_ExpertMode").IsChecked) {
             if ([System.Windows.Forms.MessageBox]::Show("Keep personal files and apps. Proceed?", "Repair", [System.Windows.Forms.MessageBoxButtons]::YesNo) -eq "Yes") { Start-Process "https://www.microsoft.com/software-download/windows11" }
        }
    })

    $window.FindName("Btn_UndoAll").Add_Click({ 
        if ($window.FindName("Global_ExpertMode").IsChecked) {
            if ([System.Windows.Forms.MessageBox]::Show("Revert ALL tweaks?", "Undo", [System.Windows.Forms.MessageBoxButtons]::YesNo) -eq "Yes") { $sync.JobQueue.Enqueue("REVERT_ALL") }
        }
    })

    $window.FindName("Btn_DNS_Cloud").Add_Click({ $sync.JobQueue.Enqueue("DNS_Cloudflare") })
    $window.FindName("Btn_DNS_Google").Add_Click({ $sync.JobQueue.Enqueue("DNS_Google") })
    $window.FindName("Btn_DNS_Auto").Add_Click({ $sync.JobQueue.Enqueue("DNS_Auto") })

    # FIX: APP INSTALLER NOW USES LOGICAL TREE (ROBUST)
    $window.FindName("Btn_InstallApps").Add_Click({
        $apps = [System.Collections.Generic.List[string]]::new()
        # CHANGED: Use Logical Tree to find checkboxes even if Tab is not fully rendered visually
        $controls = Find-Controls-Logical ($window.FindName("Tab_Apps"))
        $controls | Where-Object {$_.IsChecked} | ForEach-Object { [void]$apps.Add($_.Name) }; $sync.JobQueue.Enqueue($apps)
    })

    $window.ShowDialog() | Out-Null
} Catch { 
    $errMsg = $_.Exception.Message
    [System.Windows.Forms.MessageBox]::Show("CRITICAL LAUNCH ERROR:`n`n$errMsg", "Ronin Failed", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
}
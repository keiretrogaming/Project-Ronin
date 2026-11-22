<#
.SYNOPSIS
    Project Ronin Core Engine v8.0.0 - Background worker, registry helpers, job dispatcher.

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

# --- PROJECT RONIN: CORE ENGINE v8.0.0 "SHOGUN EDITION" ---

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
    # Full date in every line: Ronin.log persists across days, and dateless timestamps made a
    # 4-day-old crash bundle look current during triage. Costs a little width, removes ambiguity.
    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
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
    # On-screen console: drop the line in the UI's mailbox; the UI's own timer appends it
    # (Invoke-EngineMailbox, src/Ronin.ps1). 8.0: this used to BeginInvoke an engine-made closure,
    # and those were silently LOST while the engine was busy - the console stayed on "PLEASE
    # WAIT..." after every audit because "System Audit Complete." never arrived. Safe from any thread.
    try { if ($SyncHash -and $SyncHash.LogQueue) { $SyncHash.LogQueue.Enqueue($FinalMsg) } } catch {}
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

        Write-Diag "Ronin Version    : 8.0.0" "ENV"
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

# --- ORIGINAL-STATE MARKERS (HKLM:\SOFTWARE\Ronin\Originals) ---
# For values that are MACHINE-SPECIFIC (a service's original startup type, an OEM auto-start
# command line), Revert has to restore what THIS machine had - "set it to Automatic" is a
# change, not a revert, on a box that shipped it Manual.
# $Global:SnapshotCache cannot be used for this: Set-Reg/Remove-Reg call Backup-Value, which
# re-poisons the cache with the APPLIED value, so the second apply/revert cycle restores the
# wrong thing (this is the bug that made the old FSE tweak un-revertable).
# These write the marker with raw cmdlets, deliberately NOT Set-Reg, so recording an original
# can never feed back into the snapshot cache.
function Save-OriginalState ($Id, $Value) {
    try {
        $p = "HKLM:\SOFTWARE\Ronin\Originals"
        if (!(Test-Path $p)) { New-Item -Path $p -Force -ErrorAction Stop | Out-Null }
        # Record only the FIRST time. A second Apply without an intervening Revert must not
        # overwrite the true original with the already-applied value.
        $cur = Get-ItemProperty -Path $p -Name $Id -ErrorAction SilentlyContinue
        if ($cur -and $null -ne $cur.$Id) { return }
        New-ItemProperty -Path $p -Name $Id -Value "$Value" -PropertyType String -Force -ErrorAction Stop | Out-Null
    } catch { Log "  - Could not record original state for ${Id}: $($_.Exception.Message)" }
}

function Get-OriginalState ($Id) {
    try {
        $v = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Ronin\Originals" -Name $Id -ErrorAction SilentlyContinue).$Id
        if (-not [string]::IsNullOrWhiteSpace("$v")) { return "$v" }
    } catch {}
    return $null
}

function Clear-OriginalState ($Id) {
    # Cleared after a successful restore so the next Apply captures a fresh original.
    try { Remove-ItemProperty -Path "HKLM:\SOFTWARE\Ronin\Originals" -Name $Id -ErrorAction SilentlyContinue } catch {}
}

# --- APPLIED LEDGER (HKLM:\SOFTWARE\Ronin\Applied) ---
# Records which tweaks RONIN actually changed on this PC. "Reset All" undoes exactly this set.
# Without it, Reset All ran every Revert in the database: on a PC where the user had enabled WSL or
# Hyper-V themselves, "reset to default" DISABLED them (and re-enabled Recall, turned hibernation
# on, switched off dark mode...). Check can't tell "Ronin did this" from "you did this"; this can.
# Raw cmdlets, not Set-Reg, so the ledger never feeds the snapshot cache.
function Add-AppliedMark ($Key) {
    try {
        $p = "HKLM:\SOFTWARE\Ronin\Applied"
        if (!(Test-Path $p)) { New-Item -Path $p -Force -ErrorAction Stop | Out-Null }
        New-ItemProperty -Path $p -Name $Key -Value (Get-Date -Format 'yyyy-MM-dd HH:mm') -PropertyType String -Force -ErrorAction Stop | Out-Null
        # The UI polls this to know the "Changes made by Ronin" list is stale (it never gets called into).
        if ($SyncHash) { $SyncHash.LedgerVersion = [int]$SyncHash.LedgerVersion + 1 }
    } catch { Write-Diag "Applied-ledger write failed for ${Key}: $($_.Exception.Message)" "ERROR" }
}

function Remove-AppliedMark ($Key) {
    try { Remove-ItemProperty -Path "HKLM:\SOFTWARE\Ronin\Applied" -Name $Key -ErrorAction SilentlyContinue } catch {}
    if ($SyncHash) { $SyncHash.LedgerVersion = [int]$SyncHash.LedgerVersion + 1 }
}

# Tweaks Ronin applied (ledger) whose Check now says they're off: something - usually a Windows
# update - undid them. Pure function (unit-tested). Combo tweaks are skipped: the ledger records
# THAT they were applied, not which value, so "different value now" can't be told from "undone".
#   8.0: tweaks flagged Expires=$true (an update pause) are skipped - a pause running out is the
#   tweak doing what it said, not Windows undoing it. On a non-English display language, tweaks
#   flagged LocaleText=$true (the two Checks that still read English command output) are skipped
#   instead of switching the whole alert off, as 7.6 did.
function Get-UndoneTweaks ($Applied, $Status, [bool]$NonEnglish = $false) {
    $out = @()
    if (-not $Status) { return ,$out }
    foreach ($k in @($Applied)) {
        if (-not $k -or -not $RoninDB.ContainsKey($k) -or -not $Status.ContainsKey($k)) { continue }
        if ($RoninDB[$k].Expires) { continue }
        if ($NonEnglish -and $RoninDB[$k].LocaleText) { continue }
        $v = $Status[$k]
        if ($v -is [int]) { continue }
        if ("$v" -eq "False") { $out += $k }
    }
    return ,$out
}

# 8.0: ledger keys of Expires tweaks whose Check is now off - their time ran out. Pure (unit-tested).
function Get-ExpiredTweaks ($Applied, $Status) {
    $out = @()
    if (-not $Status) { return ,$out }
    foreach ($k in @($Applied)) {
        if (-not $k -or -not $RoninDB.ContainsKey($k) -or -not $RoninDB[$k].Expires -or -not $Status.ContainsKey($k)) { continue }
        if ("$($Status[$k])" -eq "False") { $out += $k }
    }
    return ,$out
}

# 7.6: after the STARTUP audit only, find tweaks Ronin applied that are now off and show the banner.
# Runs on the engine; the UI acts on $SyncHash.UndoneTweaks when a banner button is clicked.
function Invoke-ResetCheck {
    try {
        $SyncHash.UndoneTweaks = @()
        $marks = Get-AppliedMarks
        # 8.0: a finished update pause leaves the ledger quietly, with one log line.
        $expired = Get-ExpiredTweaks $marks $SyncHash.StatusCache
        foreach ($k in $expired) {
            Remove-AppliedMark $k
            $what = if ($k -eq 'Dcl_WU_Off') { "'Turn Updates Off'" } else { "update pause" }
            Log "Your Windows Update $what has ended (or was resumed in Settings), so it's no longer listed as a Ronin change."
        }
        if (-not ($SyncHash.Settings -and $SyncHash.Settings.ResetAlert)) { return }
        $ui = (Get-UICulture).Name
        $nonEnglish = [bool]($ui -and $ui -notlike 'en-*')
        if ($nonEnglish) { Write-Diag "Reset alert: non-English display language ($ui) - skipping the LocaleText checks" "ENGINE" }
        $undone = Get-UndoneTweaks $marks $SyncHash.StatusCache $nonEnglish
        if ($undone.Count -eq 0) { return }
        # 8.0: first launch after a Ronin update - these read "off" because the new version checks them
        # correctly (or works differently), not because Windows undid them. Say that, once, in the console;
        # no banner. Their ledger marks go, so the same message never comes back.
        if ($SyncHash.RoninChangedFrom) {
            foreach ($k in $undone) { Remove-AppliedMark $k }
            Log "Ronin was updated (from $($SyncHash.RoninChangedFrom)) and now checks some tweaks more accurately. These aren't on in their corrected form on this PC: $($undone -join ', '). Tick them and Apply to switch them on."
            return
        }
        $SyncHash.UndoneTweaks = $undone
        # "undid one of your tweaks" / "undid 3 of your tweaks" (it used to say "undid 1 of your tweak").
        $n = $undone.Count; $what = if ($n -eq 1) { "one of your tweaks" } else { "$n of your tweaks" }
        $msg = if ($SyncHash.BuildChangedTo) { "Windows updated to build $($SyncHash.BuildChangedTo) and undid $what." }
               else { "A Windows update or another app undid $what." }
        Log "Reset alert: $msg ($($undone -join ', '))"
        # 8.0: via the UI's mailbox (an engine-made BeginInvoke closure could be lost while the engine was busy).
        $SyncHash.ResetBannerMsg = $msg
        if ($SyncHash.UiRequests) { $SyncHash.UiRequests.Enqueue('RESET_BANNER') }
    } catch { Write-DiagException "Reset check" $_ }
}

# Ledger entries with their timestamps, for the "Changes made by Ronin" list.
function Get-AppliedLedger {
    $rows = @()
    try {
        $k = Get-Item -Path "HKLM:\SOFTWARE\Ronin\Applied" -ErrorAction Stop
        foreach ($n in $k.GetValueNames()) { if ($n) { $rows += [PSCustomObject]@{ Key = $n; When = "$($k.GetValue($n))" } } }
    } catch {}
    return ,$rows
}

# --- 8.0: DNS (Advanced > DNS Command Center) ---
# 7.x set only IPv4 servers. On dual-stack networks (most home ISPs now) Windows kept asking the ISP's
# IPv6 DNS, so "Cloudflare / Google / Quad9" was only half applied. And AUTO reset every adapter to
# DHCP, wiping DNS servers the user had typed in themselves. Now each provider sets IPv4 AND IPv6, and
# the first change records each active adapter's own static servers per family (empty = automatic),
# so AUTO puts back exactly that. Record: "{guid}|v4 servers|v6 servers;..." in the Originals key.
function ConvertTo-DnsRecord ($Rows) {      # pure, unit-tested
    $parts = @(); foreach ($r in @($Rows)) { if ($r -and $r.Guid) { $parts += "$($r.Guid)|$("$($r.V4)" -replace '[|;]', '')|$("$($r.V6)" -replace '[|;]', '')" } }
    return ($parts -join ';')
}

function ConvertFrom-DnsRecord ($Text) {    # pure, unit-tested
    $out = @()
    foreach ($part in "$Text".Split(';')) {
        $f = $part.Split('|')
        if ($f.Count -ne 3 -or $f[0] -notmatch '^\{[0-9A-Fa-f-]{36}\}$') { continue }
        $out += [PSCustomObject]@{ Guid = $f[0]; V4 = $f[1]; V6 = $f[2] }
    }
    return ,$out
}

function Save-DnsOriginals {
    if (Get-OriginalState "DNS.Adapters") { return }     # first change only: keep the TRUE original
    $rows = @()
    foreach ($a in @(Get-NetAdapter -ErrorAction SilentlyContinue)) {
        if ($a.Status -ne 'Up') { continue }
        $g = "$($a.InterfaceGuid)"
        $v4 = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$g" -Name NameServer -ErrorAction SilentlyContinue).NameServer
        $v6 = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\Interfaces\$g" -Name NameServer -ErrorAction SilentlyContinue).NameServer
        $rows += [PSCustomObject]@{ Guid = $g; V4 = "$v4"; V6 = "$v6" }
    }
    if ($rows.Count) { Save-OriginalState "DNS.Adapters" (ConvertTo-DnsRecord $rows) }
}

function Set-RoninDns ($Label, [string[]]$Servers) {
    Save-DnsOriginals
    $n = 0
    foreach ($a in @(Get-NetAdapter -ErrorAction SilentlyContinue)) {
        if ($a.Status -ne 'Up') { continue }
        try { Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses $Servers -ErrorAction Stop; $n++ }
        catch { Log "  - $($a.Name): couldn't set DNS ($($_.Exception.Message))" }
    }
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    Log "DNS: $Label on $n adapter(s), IPv4 and IPv6. Cache flushed. AUTO puts your previous DNS back."
}

function Restore-RoninDns {
    $byGuid = @{}
    $rec = ConvertFrom-DnsRecord (Get-OriginalState "DNS.Adapters")
    foreach ($r in $rec) { $byGuid[$r.Guid.ToUpper()] = $r }
    if ($rec.Count -eq 0) { Log "DNS: no record of your earlier DNS (it was never changed by Ronin 8.0+), so every adapter goes back to automatic." }
    foreach ($a in @(Get-NetAdapter -ErrorAction SilentlyContinue)) {
        if ($a.Status -ne 'Up') { continue }
        $r = $byGuid["$($a.InterfaceGuid)".ToUpper()]
        $own = @(); if ($r) { foreach ($s in ("$($r.V4) $($r.V6)" -split '[,\s]+')) { if ($s) { $own += $s } } }
        try {
            # Reset BOTH families to automatic first, then put back any servers typed in by hand -
            # setting only the static family would leave Ronin's servers on the other one.
            Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ResetServerAddresses -ErrorAction Stop
            if ($own.Count) { Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses $own -ErrorAction Stop; Log "  - $($a.Name): back to your own DNS ($($own -join ', '))." }
            else { Log "  - $($a.Name): automatic DNS (from your router)." }
        } catch { Log "  - $($a.Name): couldn't restore DNS ($($_.Exception.Message))" }
    }
    Clear-OriginalState "DNS.Adapters"
    Clear-DnsClientCache -ErrorAction SilentlyContinue
}

# --- 8.0: DEBLOAT REMOVAL RECORD (HKLM:\SOFTWARE\Ronin\Removed) ---
# App removal is the one thing Ronin can't undo, so it is at least written down: value name =
# package, data = "yyyy-MM-dd HH:mm|Friendly name". Shown (no UNDO) in Maintenance > Changes made by
# Ronin. Never part of Reset All or the reset alert - those read the Applied ledger only.
function Add-RemovedApp ($Pkg, $Friendly) {
    try {
        $p = "HKLM:\SOFTWARE\Ronin\Removed"
        if (!(Test-Path $p)) { New-Item -Path $p -Force -ErrorAction Stop | Out-Null }
        New-ItemProperty -Path $p -Name "$Pkg" -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm')|$Friendly" -PropertyType String -Force -ErrorAction Stop | Out-Null
        if ($SyncHash) { $SyncHash.LedgerVersion = [int]$SyncHash.LedgerVersion + 1 }
    } catch { Write-Diag "Removal record write failed for ${Pkg}: $($_.Exception.Message)" "ERROR" }
}

# Pure parse of one record value (unit-tested): "yyyy-MM-dd HH:mm|Friendly" -> When/Friendly.
function ConvertFrom-RemovedRecord ($Pkg, $Data) {
    $s = "$Data"; $i = $s.IndexOf('|')
    if ($i -lt 0) { return [PSCustomObject]@{ Name = "$Pkg"; Friendly = "$Pkg"; When = $s } }
    $f = $s.Substring($i + 1); if (-not $f) { $f = "$Pkg" }
    return [PSCustomObject]@{ Name = "$Pkg"; Friendly = $f; When = $s.Substring(0, $i) }
}

function Get-RemovedApps {
    $rows = @()
    try {
        $k = Get-Item -Path "HKLM:\SOFTWARE\Ronin\Removed" -ErrorAction Stop
        foreach ($n in $k.GetValueNames()) { if ($n) { $rows += (ConvertFrom-RemovedRecord $n $k.GetValue($n)) } }
    } catch {}
    return ,$rows
}

function Get-AppliedMarks {
    $names = @()
    try {
        $k = Get-Item -Path "HKLM:\SOFTWARE\Ronin\Applied" -ErrorAction Stop
        foreach ($n in $k.GetValueNames()) { if ($n) { $names += $n } }
    } catch {}
    return ,$names
}

# --- MACHINE-ORIGINAL HELPERS (built on the markers above) ---
# The 7.5.0 hand audit found 15 tweaks whose Revert wrote a GUESS instead of what the machine
# had - e.g. HH_WifiPower reverted Wi-Fi to "maximum power saving" even on AC, HH_CoreIso forced
# Memory Integrity ON for machines that never had it. These record the real original at Apply.
# Every Restore takes a fallback for when nothing was recorded (tweak applied by an older Ronin,
# or never applied by Ronin at all), so a revert is never worse than the old hardcoded value.

function Get-PowerIndex ($Sub, $Setting) {
    # Locale-independent: powercfg /qh always prints the CURRENT AC then DC index as the last two
    # 0x%08X tokens, in any display language. (Min/max/increment lines of range settings come
    # before them.) Avoids the English "Current AC Power Setting Index" text the old Checks parse.
    # A setting that doesn't exist on this hardware makes powercfg write to stderr, which becomes a
    # TERMINATING error under a caller's ErrorActionPreference=Stop. Contain it locally and return
    # $null, so no bogus "original" is ever recorded.
    $ErrorActionPreference = 'SilentlyContinue'
    $o = ""
    try { $o = (& powercfg /qh scheme_current $Sub $Setting 2>$null) | Out-String } catch { return $null }
    if ($LASTEXITCODE -ne 0) { return $null }
    $hex = @()
    foreach ($m in [regex]::Matches($o, '0x[0-9a-fA-F]{8}')) { $hex += $m.Value }
    if ($hex.Count -lt 2) { return $null }
    return @{ AC = [Convert]::ToInt64($hex[$hex.Count - 2], 16); DC = [Convert]::ToInt64($hex[$hex.Count - 1], 16) }
}

function Save-PowerOriginal ($Id, $Sub, $Setting) {
    $v = Get-PowerIndex $Sub $Setting
    if ($v) { Save-OriginalState $Id "$($v.AC),$($v.DC)" }
}

function Restore-PowerOriginal ($Id, $Sub, $Setting, $FallbackAC, $FallbackDC, $Side = 'Both') {
    # $Side matters for the AC/DC combo pairs (HH_BoostMode_*, HH_EPP_*): they share one setting
    # GUID, so reverting the AC tweak must never also rewrite the DC value (and vice versa).
    $ac = $FallbackAC; $dc = $FallbackDC
    $o = Get-OriginalState $Id
    if ($o -match '^(\d+),(\d+)$') { $ac = [int64]$Matches[1]; $dc = [int64]$Matches[2] }
    elseif ($null -ne $FallbackAC -or $null -ne $FallbackDC) { Log "  - No recorded original for $Id; restoring the Windows default instead." }
    else { Log "  - No recorded original for $Id; leaving the current value (it was never changed by Ronin)." }
    if ($Side -ne 'DC' -and $null -ne $ac) { powercfg /setacvalueindex scheme_current $Sub $Setting $ac | Out-Null }
    if ($Side -ne 'AC' -and $null -ne $dc) { powercfg /setdcvalueindex scheme_current $Sub $Setting $dc | Out-Null }
    powercfg /setactive scheme_current | Out-Null
    Clear-OriginalState $Id
}

function Save-RegOriginal ($Id, $Path, $Name) {
    # Records "ABSENT" or "<Kind>|<value>" so Revert can put back exactly what was there,
    # including restoring absence (the common case for policy values).
    # 8.0: Binary is recorded as hex and MultiString one entry per line - "$val" used to flatten
    # both into a space-separated string that Restore then wrote back as a plain String.
    $state = "ABSENT"
    try {
        if (Test-Path $Path) {
            $k = Get-Item -Path $Path -ErrorAction Stop
            $val = $k.GetValue($Name, $null, 'DoNotExpandEnvironmentNames')
            if ($null -ne $val) {
                $kind = "$($k.GetValueKind($Name))"
                $txt = if ($kind -eq 'Binary') { -join @(foreach ($b in $val) { ([byte]$b).ToString('X2') }) }
                       elseif ($kind -eq 'MultiString') { @($val) -join "`n" }
                       else { "$val" }
                $state = "$kind|$txt"
            }
        }
    } catch {}
    Save-OriginalState $Id $state
}

function Restore-RegOriginal ($Id, $Path, $Name) {
    # Returns $false when nothing was recorded, so the caller can apply its own fallback.
    $o = Get-OriginalState $Id
    if (-not $o) { return $false }
    if ($o -eq "ABSENT") { Remove-Reg $Path $Name }
    elseif ($o -match '(?s)^(\w+)\|(.*)$') {
        $kind = $Matches[1]; $val = $Matches[2]
        switch ($kind) {
            'DWord'        { Set-Reg $Path $Name ([int]$val) 'DWord' }
            'QWord'        { Set-Reg $Path $Name ([long]$val) 'QWord' }
            'ExpandString' { Set-Reg $Path $Name $val 'ExpandString' }
            'Binary'       { $bytes = [byte[]]@(for ($i = 0; $i + 1 -lt $val.Length; $i += 2) { [Convert]::ToByte($val.Substring($i, 2), 16) }); Set-Reg $Path $Name $bytes 'Binary' }
            'MultiString'  { Set-Reg $Path $Name ([string[]]@($val -split "`n")) 'MultiString' }
            default        { Set-Reg $Path $Name $val 'String' }
        }
    }
    Clear-OriginalState $Id
    return $true
}

# 8.0: did Ronin itself apply this tweak (and not revert it since)? Reads the applied ledger.
function Test-AppliedMark ($Key) {
    try { return ($null -ne (Get-ItemProperty -Path "HKLM:\SOFTWARE\Ronin\Applied" -Name $Key -ErrorAction SilentlyContinue)) } catch { return $false }
}

# 8.0: tweaks that write a value in common - Twin (two boxes for the very same Windows setting) or
# Shares (one value in common). Reverting one can switch its partner off as well; that is Ronin
# doing what the user asked, not "Windows undid it", so the partner's ledger mark goes too and the
# startup reset alert doesn't blame a Windows update for it.
function Clear-PartnerMarks ($Key) {
    $e = $RoninDB[$Key]
    if (-not $e) { return }
    foreach ($o in @(@($e.Twin) + @($e.Shares))) {
        if (-not $o -or -not $RoninDB.ContainsKey($o) -or -not $RoninDB[$o].Check) { continue }
        if (-not (Test-AppliedMark $o)) { continue }
        $on = & { $ErrorActionPreference = 'SilentlyContinue'; & $RoninDB[$o].Check }
        if ("$on" -ne "True" -and "$on" -ne "1") { Remove-AppliedMark $o; Log "  - $o shares a setting with $Key, so it is now off as well." }
    }
}

# --- 8.0: DIRECTX GRAPHICS SETTINGS (Settings > Display > Graphics) ---
# Windows keeps several of these in ONE string value, e.g. on the dev PC:
#   HKCU\Software\Microsoft\DirectX\UserGpuPreferences\DirectXUserGlobalSettings =
#   "AutoHDREnable=1;VRROptimizeEnable=0;SwapEffectUpgradeEnable=1;"
# Game_VRR used to overwrite the whole string with "VRROptimize=1": a name Windows never reads (the
# tweak did nothing) that also wiped Auto HDR and "Optimizations for windowed games". These change ONE
# entry and leave the rest exactly as they were.
function ConvertFrom-DxSettings ($Text) {    # pure, unit-tested
    $d = [ordered]@{}
    foreach ($part in ("$Text" -split ';')) { if ($part -match '^\s*([^=]+?)\s*=\s*(.*?)\s*$') { $d[$Matches[1]] = $Matches[2] } }
    return $d
}

function ConvertTo-DxSettings ($Dict) {      # pure, unit-tested
    $s = ''; foreach ($k in $Dict.Keys) { $s += "$k=$($Dict[$k]);" }; return $s
}

function Get-DxUserSetting ($Name) {
    $v = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" -Name "DirectXUserGlobalSettings" -ErrorAction SilentlyContinue).DirectXUserGlobalSettings
    $d = ConvertFrom-DxSettings $v
    if ($d.Contains($Name)) { return $d[$Name] }
    return $null
}

function Set-DxUserSetting ($Name, $Value) {    # $null removes that entry; every other entry is kept
    $p = "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences"
    $v = (Get-ItemProperty -Path $p -Name "DirectXUserGlobalSettings" -ErrorAction SilentlyContinue).DirectXUserGlobalSettings
    $d = ConvertFrom-DxSettings $v
    if ($null -eq $Value) { if ($d.Contains($Name)) { $d.Remove($Name) } } else { $d[$Name] = "$Value" }
    $s = ConvertTo-DxSettings $d
    if ($s) { Set-Reg $p "DirectXUserGlobalSettings" $s "String" } elseif ($null -ne $v) { Remove-Reg $p "DirectXUserGlobalSettings" }
}

# --- 8.0: DECLARATIVE REGISTRY TWEAKS ---
# A pure-registry tweak can declare its values once and use these three helpers:
#   Spec = @( @{ P = <path>; N = <name>; V = <applied value>; T = 'DWord'|'String'; D = <fallback> }, ... )
#   Apply={ Invoke-SpecApply 'Key' }   Revert={ Invoke-SpecRevert 'Key' }   Check={ Test-Spec 'Key' }
# Check mirrors Apply BY CONSTRUCTION (invariant 4 can't drift), and every value's original is
# recorded before the first write and put back exactly (absent -> removed again). D is only used
# when no original was recorded (applied by hand or by an older Ronin): $null removes the value,
# anything else is written back. Originals are keyed "<Key>.<index>" - never reorder a Spec.
function Invoke-SpecApply ($Key) {
    $i = 0
    foreach ($s in @($RoninDB[$Key].Spec)) {
        $t = if ($s.T) { $s.T } else { 'DWord' }
        Save-RegOriginal "$Key.$i" $s.P $s.N
        Set-Reg $s.P $s.N $s.V $t
        $i++
    }
}

function Invoke-SpecRevert ($Key) {
    $i = 0
    foreach ($s in @($RoninDB[$Key].Spec)) {
        $t = if ($s.T) { $s.T } else { 'DWord' }
        if (-not (Restore-RegOriginal "$Key.$i" $s.P $s.N)) {
            if ($null -eq $s.D) { Remove-Reg $s.P $s.N } else { Set-Reg $s.P $s.N $s.D $t }
        }
        $i++
    }
}

function Test-Spec ($Key) {
    $spec = @($RoninDB[$Key].Spec)
    if ($spec.Count -eq 0) { return $false }
    foreach ($s in $spec) { if (-not (Test-Reg-Read $s.P $s.N $s.V)) { return $false } }
    return $true
}

# --- 8.0: WINDOWS UPDATE PAUSE ---
# Uses the values the Settings app itself writes (HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings)
# on EVERY edition: no policy keys, so Settings never says "managed by your organization", and
# Settings' own "Resume updates" button keeps working. Times are UTC "yyyy-MM-ddTHH:mm:ssZ".
function ConvertFrom-WuTime ($s) {
    if ([string]::IsNullOrWhiteSpace("$s")) { return $null }
    $d = [datetime]::MinValue
    $styles = [Globalization.DateTimeStyles]::AdjustToUniversal -bor [Globalization.DateTimeStyles]::AssumeUniversal
    if ([datetime]::TryParse("$s", [Globalization.CultureInfo]::InvariantCulture, $styles, [ref]$d)) { return $d }
    return $null
}

# Pure (unit-tested): whole days of pause left, 0 = not paused. $Expiry = raw PauseUpdatesExpiryTime.
function Get-WuPauseDaysLeft ($Expiry, $Now) {
    if (-not $Now) { $Now = (Get-Date).ToUniversalTime() }
    $e = ConvertFrom-WuTime $Expiry
    if (-not $e) { return 0 }
    $left = ($e - $Now).TotalDays
    if ($left -le 0) { return 0 }
    return [int][Math]::Ceiling($left)
}

function Read-WuPauseExpiry {
    try { return (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "PauseUpdatesExpiryTime" -ErrorAction SilentlyContinue).PauseUpdatesExpiryTime } catch { return $null }
}

function Set-WuPause ($Key, [int]$Days) {
    $p = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
    $inv = [Globalization.CultureInfo]::InvariantCulture
    $now = (Get-Date).ToUniversalTime()
    $start = $now.ToString("yyyy-MM-ddTHH:mm:ssZ", $inv)
    $end = $now.AddDays($Days).ToString("yyyy-MM-ddTHH:mm:ssZ", $inv)
    $names = @("PauseFeatureUpdatesStartTime", "PauseFeatureUpdatesEndTime", "PauseQualityUpdatesStartTime", "PauseQualityUpdatesEndTime", "PauseUpdatesStartTime", "PauseUpdatesExpiryTime")
    $i = 0
    foreach ($n in $names) { Save-RegOriginal "$Key.$i" $p $n; $i++ }
    # Beyond Windows' own 35-day limit the pause ceiling has to be raised too (the Settings app's
    # pause list grows to match). Recorded and restored like everything else.
    if ($Days -gt 35) { Save-RegOriginal "$Key.Max" $p "FlightSettingsMaxPauseDays"; Set-Reg $p "FlightSettingsMaxPauseDays" $Days }
    Set-Reg $p "PauseFeatureUpdatesStartTime" $start "String"
    Set-Reg $p "PauseFeatureUpdatesEndTime" $end "String"
    Set-Reg $p "PauseQualityUpdatesStartTime" $start "String"
    Set-Reg $p "PauseQualityUpdatesEndTime" $end "String"
    Set-Reg $p "PauseUpdatesStartTime" $start "String"
    Set-Reg $p "PauseUpdatesExpiryTime" $end "String"
    # 8.0: Windows' own pause STATE as well (0 = not paused, 1 = paused, 2 = auto-resumed), as written when
    # you pause in Settings - the widely used "pause-windows-updates" .reg sets the same four values. Without
    # them the pause depended on Windows re-reading the UX values above. Recorded and restored like the rest.
    $up = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings"
    $j = 0
    foreach ($n in @("PausedFeatureStatus", "PausedQualityStatus", "PausedFeatureDate", "PausedQualityDate")) { Save-RegOriginal "$Key.UP$j" $up $n; $j++ }
    Set-Reg $up "PausedFeatureStatus" 1; Set-Reg $up "PausedQualityStatus" 1
    Set-Reg $up "PausedFeatureDate" $start "String"; Set-Reg $up "PausedQualityDate" $start "String"
    Log "  - Windows Update paused until $($now.AddDays($Days).ToLocalTime().ToString('d MMM yyyy'))."
}

function Restore-WuPause ($Key) {
    $p = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
    $names = @("PauseFeatureUpdatesStartTime", "PauseFeatureUpdatesEndTime", "PauseQualityUpdatesStartTime", "PauseQualityUpdatesEndTime", "PauseUpdatesStartTime", "PauseUpdatesExpiryTime")
    $i = 0
    # No recorded original = "not paused" is the true default: remove the pause values.
    foreach ($n in $names) { if (-not (Restore-RegOriginal "$Key.$i" $p $n)) { Remove-Reg $p $n }; $i++ }
    # The ceiling is only touched if this tweak recorded it (never removes a value someone else set).
    [void](Restore-RegOriginal "$Key.Max" $p "FlightSettingsMaxPauseDays")
    # 8.0: Windows' pause state. No record (paused by an earlier 8.0 build) = "not paused": status 0, no dates.
    $up = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings"
    $j = 0
    foreach ($n in @("PausedFeatureStatus", "PausedQualityStatus", "PausedFeatureDate", "PausedQualityDate")) {
        if (-not (Restore-RegOriginal "$Key.UP$j" $up $n)) { if ($n -like '*Status') { Set-Reg $up $n 0 } else { Remove-Reg $up $n } }
        $j++
    }
}

function Set-Reg ($Path, $Name, $Val, $Type="DWord") {
    Backup-Value $Path $Name
    # Failures are LOGGED, never rethrown (a tweak keeps its non-terminating flow).
    # Silent write failures made "APPLY ran but Check still reports not-applied" undiagnosable
    # from user logs (see the Priv_Widgets false-fail on the G14 bundle) - now the log names
    # exactly which write failed and why.
    try {
        if(!(Test-Path $Path)){ New-Item -Path $Path -Force -ErrorAction Stop | Out-Null }
        New-ItemProperty -Path $Path -Name $Name -Value $Val -PropertyType $Type -Force -ErrorAction Stop | Out-Null
    } catch {
        Log "  - Registry write FAILED: $Path\$Name : $($_.Exception.Message)"
        if (Get-Command Write-Diag -ErrorAction SilentlyContinue) { Write-Diag "Set-Reg failed: $Path\$Name : $($_.Exception.Message)" "ERROR" }
    }
}

function Remove-Reg ($Path, $Name) {
    Backup-Value $Path $Name
    if (Test-Path $Path) {
        # Removing an ABSENT value stays a silent no-op (that is normal revert behavior);
        # only a real removal failure (e.g. ACL/tamper protection) is logged.
        $existing = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        if ($null -ne $existing) {
            try {
                Remove-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
            } catch {
                Log "  - Registry delete FAILED: $Path\$Name : $($_.Exception.Message)"
                if (Get-Command Write-Diag -ErrorAction SilentlyContinue) { Write-Diag "Remove-Reg failed: $Path\$Name : $($_.Exception.Message)" "ERROR" }
            }
        }
    }
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
function Restart-Explorer {
    # Kill-and-hope was the old behaviour: Windows only respawns the shell when Winlogon's
    # AutoRestartShell is on. Debloated machines sometimes have it off, which left the user on a
    # permanently blank screen. Wait for the automatic respawn, and start it ourselves if it
    # doesn't come back.
    Log "Restarting Explorer to apply shell changes..."
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    $back = $false
    for ($i = 0; $i -lt 20; $i++) {
        Start-Sleep -Milliseconds 250
        if (Get-Process explorer -ErrorAction SilentlyContinue) { $back = $true; break }
    }
    if (-not $back) {
        Log "  - Explorer did not respawn on its own; starting it."
        try { Start-Process "explorer.exe" -ErrorAction Stop } catch { Log "  - Could not start Explorer: $($_.Exception.Message). Press Ctrl+Shift+Esc > Run new task > explorer." }
    }
}

# 8.0: start a program and wait for it while stamping the engine's liveness beat every second. A plain
# "Start-Process -Wait" froze the beat, so DISM /ResetBase (often 10-30 min) raised a false "ENGINE NOT
# RESPONDING" banner after 3 minutes. Stops WAITING (never kills) after $MaxMinutes. Returns the exit
# code, or $null if it couldn't start or is still running.
function Invoke-RoninProcess ($File, $Arguments, [int]$MaxMinutes = 60) {
    $sp = @{ FilePath = $File; PassThru = $true; NoNewWindow = $true; ErrorAction = 'Stop' }
    if ($Arguments) { $sp.ArgumentList = $Arguments }
    try { $p = Start-Process @sp } catch { Log "  - Could not start ${File}: $($_.Exception.Message)"; return $null }
    $null = $p.Handle   # keeps ExitCode readable after the process exits
    $t0 = Get-Date
    while (-not $p.WaitForExit(1000)) {
        $SyncHash.LastBeat = Get-Date
        if (((Get-Date) - $t0).TotalMinutes -ge $MaxMinutes) { Log "  - $File is still running after $MaxMinutes min; Ronin stopped waiting for it (it carries on in the background)."; return $null }
    }
    $SyncHash.LastBeat = Get-Date
    return $p.ExitCode
}

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

# 8.0: these three read through Get-PowerIndex (hex tokens, any display language) instead of
# matching the English "Current AC Power Setting Index" text. Same return values as before.
function Get-CpuBoostMode ($State = "AC") {
    try { $v = Get-PowerIndex sub_processor be337238-0d82-4146-a960-4f3749d470c7; if ($v) { return [int]$v[$State] } } catch {}
    return -1
}

function Get-EPP-Value ($State = "AC") {
    try { $v = Get-PowerIndex sub_processor 36687f9e-e3a5-4dbf-b1dc-15eb381c6863; if ($v) { return [int]$v[$State] } } catch {}
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
    try { $v = Get-PowerIndex 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5; if ($v) { return [int]$v.AC } } catch {}
    return -1
}

# --- AV SAFE SENSORS (Standard WMI/CIM Loop) ---
function Update-Sensors {
    try {
        if ($SyncHash.Window.Dispatcher.HasShutdownStarted) { return }
        # Was a WMI Win32_OperatingSystem query (~97 ms + WmiPrvSE load) EVERY SECOND for one label.
        # ComputerInfo reads the same numbers from GlobalMemoryStatusEx in ~0.5 ms.
        if (-not $script:CompInfo) {
            Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue
            $script:CompInfo = New-Object Microsoft.VisualBasic.Devices.ComputerInfo
        }
        $ram = "..."
        try {
            $used = $script:CompInfo.TotalPhysicalMemory - $script:CompInfo.AvailablePhysicalMemory
            $ram = "$([Math]::Round($used / 1GB, 1)) GB"
            $SyncHash.SensorRamPct = [Math]::Round(100.0 * $used / $script:CompInfo.TotalPhysicalMemory)   # 8.0: status bar meter
        } catch {}
        # 8.0: publish the values; the UI's mailbox timer writes the labels (engine-made BeginInvoke
        # closures could be lost while the engine was busy).
        $SyncHash.SensorRam = $ram
        $SyncHash.SensorCpu = $script:CpuName
    } catch {}
}

function Update-Tweaks {
    if ($SyncHash.Window.Dispatcher.HasShutdownStarted) { return }
    Log "Auditing System State..."
    $Status = @{} ; $totalActive = 0; $relevantDbSize = 0
    foreach ($k in $RoninDB.Keys) {
        if ($RoninDB[$k].Check) {
            # SlowCheck=$true used to be documentation only - nothing read it, so every post-batch
            # audit re-ran each slow check. Now their results are cached for the session under
            # "audit:<key>". The batch loop drops a key's entry whenever it touches that tweak, and
            # Run System Audit clears the whole cache, so the audit never shows a stale state.
            $ck = "audit:$k"
            if ($RoninDB[$k].SlowCheck -and $SyncHash.SlowCheckCache -and $SyncHash.SlowCheckCache.ContainsKey($ck)) {
                $Status[$k] = $SyncHash.SlowCheckCache[$ck]; continue
            }
            try {
                $Status[$k] = & {
                    $ErrorActionPreference = 'SilentlyContinue'
                    & $RoninDB[$k].Check
                }
            } catch { $Status[$k] = $false }
            if ($RoninDB[$k].SlowCheck -and $SyncHash.SlowCheckCache) { $SyncHash.SlowCheckCache[$ck] = $Status[$k] }
        }
    }

    # Publish the results so the UI thread can use them without running Checks itself
    # (Reset All builds its legacy fallback from this). Plain loop on the engine thread.
    if ($SyncHash.StatusCache) { foreach ($sk in $Status.Keys) { $SyncHash.StatusCache[$sk] = $Status[$sk] } }

    # --- WRITE FULL STATE REPORT ---
    # Persist the on/off state of every tweak so the user can review exactly what is
    # active, inactive, or failing -- the event log shows actions, this shows current state.
    try {
        $rep = New-Object System.Collections.Generic.List[string]
        $rep.Add("=" * 72)
        $rep.Add("  PROJECT RONIN v8.0.0 - SYSTEM STATE REPORT")
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

    # Read the cached handheld flag (computed ONCE at startup). NEVER call Get-CimInstance
    # inside the Dispatcher.Invoke below: WMI can stall for seconds, which froze the whole
    # UI thread mid-audit (intermittent "the app froze during audit" bug). Lazy-compute as a
    # null-safe fallback only if the cache was never populated (e.g. direct Update-Tweaks).
    $isHandheld = $SyncHash.IsHandheld
    if ($null -eq $isHandheld) {
        $isHandheld = $false
        try {
            $cimComp = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
            if ($cimComp -and ($cimComp.Model -match "RC71|83[E-G]1|83S|Claw|Jupiter")) { $isHandheld = $true }
        } catch {}
        $SyncHash.IsHandheld = $isHandheld
    }

    $SyncHash.Window.Dispatcher.Invoke([Action]{
        foreach ($k in $Status.Keys) {
            $c = $SyncHash.Window.FindName($k)
            if ($null -ne $c) {
                # Hardware Relevance Check
                $isHardwareRelevant = $true
                if ($k.StartsWith("HH_") -and -not $isHandheld) { $isHardwareRelevant = $false }

                if ($c -is [System.Windows.Controls.CheckBox]) {
                    $c.IsChecked = $Status[$k]
                    # 8.0 Black Ice: the switch style colours the label from IsChecked, so no Foreground here
                    # (a local value would override the style), and the audit clears the "queued" mark.
                    $c.Tag = $null
                    if ($Status[$k] -and $isHardwareRelevant) { $totalActive++ }

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
            if ($null -ne $autoC) { $autoC.IsChecked = $Status[$sysKey]; $autoC.Tag = $null }
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

        # 8.0 Black Ice: the card shows the tier big and the score + verdict small; the UI paints the hex badge
        # and the C/B/A/S ladder from these fields (mailbox 'RANK', queued after this Invoke).
        $tier = if ($percent -ge 80) { 'S' } elseif ($percent -ge 60) { 'A' } elseif ($percent -ge 35) { 'B' } else { 'C' }
        $verdict = if ($tier -eq 'S') { 'FULLY OPTIMIZED' } elseif ($tier -eq 'A') { 'WELL TUNED' } elseif ($tier -eq 'B') { 'PARTLY TUNED' } else { 'UNOPTIMIZED' }
        $SyncHash.HealthRank.Text = "$tier-TIER"
        $SyncHash.RankTier = $tier
        $SyncHash.RankNote = "$([int][Math]::Round($percent))/100 $verdict"

        $tabs = $SyncHash.Window.FindName("MainTabs")
        if ($tabs) { $tabs.IsEnabled = $true; $tabs.Opacity = 1.0 }

    }, [System.Windows.Threading.DispatcherPriority]::ContextIdle)

    # 8.0 Black Ice: the rank card and the per-tab counts are painted by the UI from the fields above.
    try { if ($SyncHash.UiRequests) { $SyncHash.UiRequests.Enqueue('RANK'); $SyncHash.UiRequests.Enqueue('COUNTS') } } catch {}
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
            # Windows allows ONE restore point per 24 h by default (SystemRestorePointCreationFrequency).
            # Inside that window Checkpoint-Computer only WARNS and creates nothing - which used to be
            # logged as "Restore point created." So count real restore points before and after.
            try {
                $before = @(Get-ComputerRestorePoint -ErrorAction SilentlyContinue)
                Checkpoint-Computer -Description $desc -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop -WarningAction SilentlyContinue
                $after = @(Get-ComputerRestorePoint -ErrorAction SilentlyContinue)
                if ($after.Count -gt $before.Count) { "OK" }
                else {
                    $last = $after | Sort-Object SequenceNumber | Select-Object -Last 1
                    $when = if ($last) { try { ([Management.ManagementDateTimeConverter]::ToDateTime($last.CreationTime)).ToString('yyyy-MM-dd HH:mm') } catch { "earlier today" } } else { "earlier today" }
                    "THROTTLED:$when"
                }
            }
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
            if ($res -like "THROTTLED:*") {
                Log "No new restore point: Windows allows one per 24 hours, and the most recent is from $($res.Substring(10)). Continuing - every tweak is individually reversible."
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
    $script:LastDiagBeat = Get-Date
    # Liveness signal read by the UI watchdog (see the DispatcherTimer in Ronin.ps1). LastBeat is
    # stamped everywhere the engine proves it is still moving; CurrentOp names what it was doing
    # so a stall can be reported instead of just sitting there silently. Assignments are inline
    # (not a helper) on purpose: helpers must be added to $CoreFunctions to cross the runspace,
    # and a missed injection would silently disable the watchdog.
    $SyncHash.LastBeat = Get-Date
    $SyncHash.CurrentOp = "starting up"
    # Record this thread's ID so Write-Diag can tag engine-thread log lines
    try { $SyncHash.EngineThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId } catch {}
    Write-Diag "Engine worker thread started" "ENGINE"
    # CPU name straight from the registry (instant). It was a WMI Win32_Processor query that took
    # ~1 s of every startup, before the first audit could begin.
    $script:CpuName = "Unknown CPU"
    try {
        $n = (Get-ItemProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0" -Name ProcessorNameString -ErrorAction Stop).ProcessorNameString
        if ($n) { $script:CpuName = $n.Trim() }
    } catch {}
    $script:LastPowerCheck = [DateTime]::MinValue
    $script:InStandby = $false
    if (!(Test-Path "$env:ProgramData\Ronin")) { New-Item -Path "$env:ProgramData\Ronin" -ItemType Directory -Force | Out-Null }
    
    Log "Ronin Core v8.0.0 Shogun Edition Online."

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
            # Modern-Standby guard: pause while the device is entering standby (Kernel-Power 506).
            # Was queried on EVERY loop pass (~27 ms each, forever); every 10 s is plenty.
            if (((Get-Date) - $script:LastPowerCheck).TotalSeconds -ge 10) {
                $script:LastPowerCheck = Get-Date
                try {
                    $lastPowerEvent = Get-WinEvent -ProviderName "Microsoft-Windows-Kernel-Power" -MaxEvents 1 -ErrorAction SilentlyContinue
                    $script:InStandby = [bool]($lastPowerEvent -and $lastPowerEvent.Id -eq 506)
                } catch { $script:InStandby = $false }
            }
            if ($script:InStandby) { Start-Sleep -Seconds 5; $script:LastPowerCheck = [DateTime]::MinValue; continue }
            
            $SleepDuration = 1000 
            
            if ($SyncHash.JobQueue.Count -gt 0) {
                $SleepDuration = 50 
                $job = $SyncHash.JobQueue.Dequeue()
                $jobDesc = if ($job -is [string]) { $job } elseif ($job -is [System.Collections.IEnumerable]) { "BATCH[$($job.Count) items]" } else { "$($job.GetType().Name)" }
                Write-Diag "Job dequeued: $jobDesc (queue depth now $($SyncHash.JobQueue.Count))" "ENGINE"
                # 8.0: CurrentJob = WHICH job is running (Submit-RoninJob's duplicate check). CurrentOp may be
                # overwritten with progress ("Install 7zip.7zip (1/3)"), which used to defeat that check.
                $SyncHash.LastBeat = Get-Date; $SyncHash.CurrentOp = $jobDesc; $SyncHash.CurrentJob = $jobDesc
                $jobStart = Get-Date
                
                if ($job -eq "INIT") { Update-Tweaks; Invoke-ResetCheck }
                elseif ($job -eq "AUDIT_SYSTEM") { if ($SyncHash.SlowCheckCache) { $SyncHash.SlowCheckCache.Clear() }; Update-Tweaks }
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
                # (REVERT_ALL removed in 7.5.0: "Reset All" now builds a normal revert batch from the
                # applied ledger in the controller - see Get-ResetAllBatch - so it gets the Check
                # gate, per-tweak verification, one Explorer restart and the summary dialog.)

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
                            $restartShell = $false   # set by tweaks flagged Explorer=$true; restart ONCE after the batch
                            $applied = 0; $reverted = 0; $skipped = 0; $failed = 0; $failedKeys = @()

                            foreach ($taskItem in $job) {
                                $count++; $SyncHash.Window.Dispatcher.Invoke({ $SyncHash.ProgBar.Value = $count })
                                if ($count % 5 -eq 0) { Start-Sleep -Milliseconds 2 }
                                # Per-task liveness beat. WITHOUT this the watchdog is unusable: the
                                # loop-bottom heartbeat can't fire while a single slow tweak runs
                                # (CompactOS ~35s, DISM ResetBase minutes), so a legitimate long
                                # operation would look exactly like a deadlock and raise a false alarm.
                                $SyncHash.LastBeat = Get-Date
                                $SyncHash.CurrentOp = "$($taskItem.Action) $($taskItem.Key) ($count/$total)"
                                # This tweak is about to change: its cached audit result is now stale.
                                if ($SyncHash.SlowCheckCache) { $SyncHash.SlowCheckCache.Remove("audit:$($taskItem.Key)") }

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
                                                if ("$currentState" -eq "$target") { $skipped++; Log "Skipping $($taskItem.Key) (Already Optimized)."; if ($dbEntry.SlowCheck -and $SyncHash.SlowCheckCache) { $SyncHash.SlowCheckCache["audit:$($taskItem.Key)"] = $currentState }; continue }
                                            } else {
                                                if ("$currentState" -eq "$false") { $skipped++; Log "Skipping Rollback (Already at Default)."; if ($dbEntry.SlowCheck -and $SyncHash.SlowCheckCache) { $SyncHash.SlowCheckCache["audit:$($taskItem.Key)"] = $currentState }; continue }
                                            }
                                            # (8.0: a SKIPPED slow tweak keeps the fresh result just read above as its
                                            # audit cache entry. It used to stay dropped, so the re-audit after every
                                            # batch re-ran each slow Check in the tab - e.g. two scheduled-task Checks,
                                            # ~1.5 s each, on every Privacy Apply - for tweaks the batch never touched.)
                                        }
                                        if ($taskItem.Action -eq "Apply" -and $dbEntry.Apply) { 
                                            Log "APPLY: $($taskItem.Key)..."
                                            $applyStart = Get-Date
                                            try {
                                                if ($taskItem.Value -ne $null) { 
                                                    & { $ErrorActionPreference='Continue'; Invoke-Command -ScriptBlock $dbEntry.Apply -ArgumentList $taskItem.Value } | Out-Null
                                                } else { 
                                                    & { $ErrorActionPreference='Continue'; Invoke-Command -ScriptBlock $dbEntry.Apply } | Out-Null
                                                }
                                                $applyMs = [int]((Get-Date) - $applyStart).TotalMilliseconds
                                                # Verify by re-running Check
                                                $verified = $null
                                                if ($dbEntry.Check) { $verified = & { $ErrorActionPreference='SilentlyContinue'; & $dbEntry.Check } }
                                                if ($null -eq $verified) {
                                                    Log "  -> APPLY done ($($applyMs)ms, no Check defined)"; $applied++; Add-AppliedMark $taskItem.Key
                                                } elseif ("$verified" -eq "True" -or "$verified" -eq "1" -or ($null -ne $taskItem.Value -and "$verified" -eq "$($taskItem.Value)")) {
                                                    # Verified: checkbox tweaks return True/1; combo-box tweaks return their
                                                    # selected index, so accept a match against the value we just applied.
                                                    Log "  -> APPLY verified ($($applyMs)ms)"; $applied++; Add-AppliedMark $taskItem.Key
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
                                            if ($dbEntry.Explorer) { $restartShell = $true }
                                        } elseif ($taskItem.Action -eq "Revert" -and $dbEntry.Revert) { 
                                            Log "REVERT: $($taskItem.Key)..."
                                            if ($dbEntry.Explorer) { $restartShell = $true }
                                            $revertStart = Get-Date
                                            $revBefore = $reverted
                                            try {
                                                & { $ErrorActionPreference='Continue'; Invoke-Command -ScriptBlock $dbEntry.Revert } | Out-Null
                                                $revertMs = [int]((Get-Date) - $revertStart).TotalMilliseconds
                                                # Verify the revert exactly like Apply is verified. This used to log
                                                # "REVERT done" unconditionally - Adv_PhotoViewer and Sys_DupliDrive
                                                # "reverted" for months while changing nothing. Now every revert a
                                                # user runs either proves itself or names itself in the summary.
                                                $stillOn = $null
                                                if ($dbEntry.Check) { $stillOn = & { $ErrorActionPreference='SilentlyContinue'; & $dbEntry.Check } }
                                                if ($null -eq $stillOn) {
                                                    Log "  -> REVERT done ($($revertMs)ms, no Check defined)"; $reverted++; Remove-AppliedMark $taskItem.Key
                                                } elseif (("$stillOn" -eq "True" -or "$stillOn" -eq "1") -and $dbEntry.Reboot) {
                                                    # Optional features / VBS legitimately read as ON until restart -
                                                    # reporting those as failures would be crying wolf.
                                                    Log "  -> REVERT staged ($($revertMs)ms) - takes effect after a reboot"; $reverted++; $rebootTriggered = $true; Remove-AppliedMark $taskItem.Key
                                                } elseif (("$stillOn" -eq "True" -or "$stillOn" -eq "1") -and $dbEntry.RevertNote) {
                                                    # A few tweaks can't be reversed by Ronin itself (re-encrypting a
                                                    # drive) or were already at the Windows default. Say so plainly
                                                    # instead of reporting a policy/MDM failure that isn't real.
                                                    Log "  -> REVERT: $($dbEntry.RevertNote)"; $reverted++; Remove-AppliedMark $taskItem.Key
                                                } elseif ("$stillOn" -eq "True" -or "$stillOn" -eq "1") {
                                                    Log "  -> REVERT ran but Check still reports applied. The setting may be enforced by group policy / an MDM profile, or need a reboot."
                                                    $failed++; $failedKeys += $taskItem.Key
                                                } else {
                                                    Log "  -> REVERT verified ($($revertMs)ms)"; $reverted++; Remove-AppliedMark $taskItem.Key
                                                }
                                                if ($reverted -gt $revBefore -and ($dbEntry.Twin -or $dbEntry.Shares)) { Clear-PartnerMarks $taskItem.Key }
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

                            # One announced shell restart for the whole batch, before the re-audit so the
                            # audit reads the settled state. Previously Gallery/Home each force-killed
                            # Explorer mid-batch - a blank screen that users read as a crash.
                            if ($restartShell) {
                                # 7.6 "Only when I click a button": never prompt from the engine (no modals
                                # here) - show the non-modal Explorer banner and let the user choose.
                                if ($SyncHash.Settings -and $SyncHash.Settings.ExplorerRestart -eq 'ask') {
                                    Log "Taskbar / Start / Explorer changes are ready - restart Explorer from the banner above when it suits you."
                                    if ($SyncHash.UiRequests) { $SyncHash.UiRequests.Enqueue('EXPLORER_BANNER') }
                                } else { Restart-Explorer }
                            }

                            # Settle the batch FIRST (re-audit + UI refresh) so the summary dialog appears on
                            # an idle UI and its OK button closes instantly instead of competing with the audit.
                            Start-Sleep -Milliseconds 750
                            Update-Tweaks
                            try { if ($Global:SnapshotCache.Count -gt 0) { $Global:SnapshotCache | ConvertTo-Json -Depth 2 | Set-Content $Global:SnapshotFile -Force } } catch {}
                            $SyncHash.Window.Dispatcher.Invoke({ $SyncHash.ProgBar.Visibility = "Collapsed"; if ($rebootTriggered -and $SyncHash.RebootBanner) { $SyncHash.RebootBanner.Visibility = "Visible" } })

                            # The summary dialog is built by the UI (Show-BatchSummary in src/Ronin.ps1). The engine
                            # never creates windows or attaches handlers: an engine-runspace OK/Close handler
                            # can hang the UI thread (invariant 12). Publish the numbers, ask the UI, move on.
                            $SyncHash.BatchSummary = @{ Applied = $applied; Reverted = $reverted; Skipped = $skipped; Failed = $failed; FailedKeys = @($failedKeys) }
                            if ($SyncHash.ShowBatchSummary) { [void]$SyncHash.Window.Dispatcher.BeginInvoke($SyncHash.ShowBatchSummary) }
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
                    [void](Invoke-RoninProcess "powershell" "-Command `"Get-AppxPackage -allusers Microsoft.WindowsStore | Foreach {Add-AppxPackage -DisableDevelopmentMode -Register `"`$(`$_.InstallLocation)\AppXManifest.xml`"`}`"" 15)
                    Log "Store Reset Complete."
                }
                elseif ($job -eq "MAINT_DRIVERS") {
                    # 8.0 fix: the old fallback ran "winget upgrade Nvidia.GeForceExperience" /
                    # "AMD.Adrenalin.Edition" - neither ID exists in winget (verified against
                    # microsoft/winget-pkgs), so on PCs without the vendor app this silently did
                    # nothing. It also only looked at the FIRST GPU, which on gaming laptops is the
                    # integrated one. Now: every GPU is checked (discrete vendor first); the vendor's
                    # own app opens if installed, otherwise the vendor's official driver page opens in
                    # the browser - through explorer.exe, so the browser doesn't run as administrator.
                    Log "Checking your graphics hardware..."
                    $gpuNames = @(); foreach ($vc in @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)) { if ($vc.Name) { $gpuNames += "$($vc.Name)" } }
                    $nv = $null; $amd = $null; $intel = $null
                    foreach ($gn in $gpuNames) { if (-not $nv -and $gn -match 'NVIDIA') { $nv = $gn } elseif (-not $amd -and $gn -match 'AMD|Radeon') { $amd = $gn } elseif (-not $intel -and $gn -match 'Intel') { $intel = $gn } }
                    $vendorApp = $null; $page = $null; $label = $null
                    if ($nv) {
                        $label = "NVIDIA ($nv)"; $page = "https://www.nvidia.com/en-us/geforce/drivers/"
                        foreach ($c in @("$env:ProgramFiles\NVIDIA Corporation\NVIDIA App\CEF\NVIDIA App.exe", "$env:ProgramFiles\NVIDIA Corporation\NVIDIA GeForce Experience\NVIDIA GeForce Experience.exe")) { if (-not $vendorApp -and (Test-Path -LiteralPath $c)) { $vendorApp = $c } }
                    } elseif ($amd) {
                        $label = "AMD ($amd)"; $page = "https://www.amd.com/en/support/download/drivers.html"
                        $c = "$env:ProgramFiles\AMD\CNext\CNext\RadeonSoftware.exe"; if (Test-Path -LiteralPath $c) { $vendorApp = $c }
                    } elseif ($intel) {
                        $label = "Intel ($intel)"; $page = "https://www.intel.com/content/www/us/en/support/detect.html"
                    }
                    if ($vendorApp) { Log "$label - opening the vendor app; use its Drivers page to update."; Start-Process $vendorApp }
                    elseif ($page) { Log "$label - no vendor app installed, so opening the official driver page in your browser."; Start-Process "explorer.exe" -ArgumentList $page }
                    else { Log "No NVIDIA, AMD or Intel graphics found - opening Windows Update's optional (driver) updates."; Start-Process "ms-settings:windowsupdate-optionalupdates" }
                }
                elseif ($job -eq "MAINT_RESTORE") { Log "Creating Restore Point (up to 90s)..."; New-RoninRestorePoint "Ronin Manual Restore" | Out-Null }
                elseif ($job -eq "MAINT_RECLAIM") {
                    # Deep space reclaim: Windows.old + DISM /ResetBase (permanent).
                    # 8.0: the confirmation is the UI's two-step button (src/Ronin.ps1, Btn_Reclaim) and
                    # this job is only queued after it. It used to show a MODAL MessageBox from here,
                    # through Dispatcher.Invoke - the engine-modal pattern behind earlier freezes
                    # (invariants 2 and 12). ronin-build now rejects any MessageBox in the engine.
                    $result = "Yes"
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
                            [void](Invoke-RoninProcess "cleanmgr.exe" "/sagerun:117" 60)
                        } else { Log "RECLAIM: No Windows.old found (skipping)." }
                        # 2. Deep component-store clean
                        Log "RECLAIM: Compressing superseded updates (DISM ResetBase)..."
                        [void](Invoke-RoninProcess "dism" "/Online /Cleanup-Image /StartComponentCleanup /ResetBase" 120)
                        $after = (Get-PSDrive -Name ($env:SystemDrive.TrimEnd(':')) -ErrorAction SilentlyContinue).Free
                        if ($before -and $after) {
                            $freedGB = [Math]::Round(($after - $before) / 1GB, 2)
                            if ($freedGB -lt 0) { $freedGB = 0 }
                            Log "RECLAIM COMPLETE: Freed $freedGB GB of disk space."
                        } else { Log "RECLAIM COMPLETE." }
                    } else { Log "Reclaim Space cancelled." }
                }
                # 8.0: the REAL Desktop (OneDrive's Desktop backup moves it - %USERPROFILE%\Desktop may not exist), and a
                # plain message when there's no report (a desktop PC has no battery) instead of opening a missing file.
                elseif ($job -eq "MAINT_BATTERY") { Log "Battery Report..."; $rpt = Join-Path ([Environment]::GetFolderPath('Desktop')) "battery_report.html"; Start-Process "powercfg" "/batteryreport /output `"$rpt`"" -Wait -WindowStyle Hidden; if (Test-Path $rpt) { Start-Process $rpt; Log "  - Saved to your Desktop: battery_report.html" } else { Log "  - No battery report: this PC has no battery Windows can report on." } }
                elseif ($job -eq "MAINT_SLEEP") { Log "Sleep Study..."; $rpt = Join-Path ([Environment]::GetFolderPath('Desktop')) "sleep_study.html"; Start-Process "powercfg" "/sleepstudy /output `"$rpt`"" -Wait -WindowStyle Hidden; if (Test-Path $rpt) { Start-Process $rpt; Log "  - Saved to your Desktop: sleep_study.html" } else { Log "  - No sleep study: it needs Modern Standby (most laptops and handhelds; not most desktops)." } }
                elseif ($job -eq "MAINT_OPEN_BACKUPS") { Log "Opening Snapshot Folder..."; Invoke-Item "$env:ProgramData\Ronin" -ErrorAction SilentlyContinue }
                elseif ($job -eq "MAINT_GPURESET") {
                    Log "INITIATING GPU STACK RESET..."
                    Get-Process -Name "clinfo", "amdocl*", "nvcontainer*", "RadeonSoftware", "NVIDIA Web Helper", "Steam", "EpicGamesLauncher" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
                    $paths = @("$env:LOCALAPPDATA\NVIDIA\GLCache", "$env:LOCALAPPDATA\NVIDIA\DXCache", "$env:LOCALAPPDATA\AMD\DxCache", "$env:LOCALAPPDATA\AMD\GLCache", "$env:LOCALAPPDATA\AMD\OclCache", "$env:LOCALAPPDATA\Intel\ShaderCache", "$env:LOCALAPPDATA\Intel\GPUCache", "$env:LOCALAPPDATA\D3DSCache", "$env:ProgramData\NVIDIA Corporation\NV_Cache")
                    foreach ($p in $paths) { if(Test-Path $p){ Remove-Item "$p\*" -Recurse -Force -ErrorAction SilentlyContinue } }
                    # 8.0: was "cleanmgr /autoclean /d C: /verylowdisk" - a full, unscoped Disk Cleanup with
                    # Windows' default selections, nothing to do with the GPU. Now only the DirectX shader
                    # cache, through Ronin's own Disk Cleanup profile 119.
                    $d3d = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\D3D Shader Cache"
                    if (Test-Path $d3d) {
                        try { Set-ItemProperty -Path $d3d -Name "StateFlags0119" -Value 2 -Type DWord -Force -ErrorAction Stop; [void](Invoke-RoninProcess "cleanmgr.exe" "/sagerun:119" 30) } catch {}
                    }
                    [void](Invoke-RoninProcess "pnputil" "/scan-devices" 10)
                    Log "GPU Stack Reset Complete. Restart Recommended."
                }
                elseif ($job -eq "MAINT_SHADER") {
                    # 8.0: covers the same caches as the GPU stack reset (it used to clear only NVIDIA's
                    # OpenGL cache, AMD's DX cache and Intel's - missing NVIDIA's DirectX cache and Windows'
                    # own D3D cache, the ones most games use). Caches rebuild themselves as games run.
                    Log "Clearing GPU shader caches (games rebuild them on next launch)..."
                    $freed = 0
                    foreach ($sc in @("$env:LOCALAPPDATA\NVIDIA\DXCache", "$env:LOCALAPPDATA\NVIDIA\GLCache", "$env:ProgramData\NVIDIA Corporation\NV_Cache",
                                      "$env:LOCALAPPDATA\AMD\DxCache", "$env:LOCALAPPDATA\AMD\DxcCache", "$env:LOCALAPPDATA\AMD\GLCache", "$env:LOCALAPPDATA\AMD\VkCache",
                                      "$env:LOCALAPPDATA\Intel\ShaderCache", "$env:LOCALAPPDATA\D3DSCache")) {
                        if (Test-Path -LiteralPath $sc) {
                            try { $freed += (Get-ChildItem -LiteralPath $sc -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum } catch {}
                            Remove-Item -Path "$sc\*" -Recurse -Force -ErrorAction SilentlyContinue
                        }
                    }
                    Log "Shader caches cleared (about $([Math]::Round($freed / 1MB)) MB; files in use by a running game are skipped)."
                }
                elseif ($job -eq "MAINT_VCREDIST") {
                    # 8.0: x64 AND x86 (32-bit games - most "MSVCP140.dll missing" errors - need the x86 runtime),
                    # with the same non-interactive, exact-ID flags as Install Apps (winget could otherwise sit on
                    # an invisible prompt). Both IDs verified in winget-pkgs 2026-11-20.
                    if (Check-Internet) {
                        foreach ($vc in @("Microsoft.VCRedist.2015+.x64", "Microsoft.VCRedist.2015+.x86")) {
                            Log "Installing $vc..."
                            $rc = Invoke-RoninProcess "winget" @("install", "--id", $vc, "--exact", "--source", "winget", "--silent", "--disable-interactivity", "--accept-source-agreements", "--accept-package-agreements") 30
                            # same codes as Install Apps: 0x8A150061 already installed, 0x8A15002B no newer version
                            if ($rc -eq 0) { Log "  -> installed." } elseif ($rc -eq -1978335135 -or $rc -eq -1978335189) { Log "  -> already installed." } elseif ($null -ne $rc) { Log ("  -> winget exit code 0x{0:X8}." -f $rc) }
                        }
                    } else { Log "No Internet." }
                }
                elseif ($job -eq "MAINT_DISKCLEAN") {
                    # 8.0 fix: "/sagerun:1" only cleans what an earlier "/sageset:1" ticked - and nothing
                    # ever ticked anything, so this ran Disk Cleanup with every box empty. Ronin now ticks
                    # its OWN profile (118, inert unless run) with a SAFE list only: temp files, caches,
                    # logs and crash dumps. Never Downloads, the Recycle Bin, Windows.old, old drivers,
                    # update rollback files, or the Reset-this-PC image.
                    $vc = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
                    $safe = @("Active Setup Temp Folders", "D3D Shader Cache", "Delivery Optimization Files", "Diagnostic Data Viewer database files",
                              "Downloaded Program Files", "Feedback Hub Archive log files", "Internet Cache Files", "Old ChkDsk Files",
                              "RetailDemo Offline Content", "Setup Log Files", "System error memory dump files", "System error minidump files",
                              "Temporary Files", "Thumbnail Cache", "Windows Error Reporting Files", "Windows Reset Log Files", "Windows Upgrade Log Files")
                    $cats = 0
                    foreach ($cat in $safe) { if (Test-Path "$vc\$cat") { try { Set-ItemProperty -Path "$vc\$cat" -Name "StateFlags0118" -Value 2 -Type DWord -Force -ErrorAction Stop; $cats++ } catch {} } }
                    $before = (Get-PSDrive -Name ($env:SystemDrive.TrimEnd(':')) -ErrorAction SilentlyContinue).Free
                    Log "Disk Cleanup: cleaning $cats safe categories (temp files, caches, logs, crash dumps)..."
                    try {
                        $p = Start-Process "cleanmgr.exe" -ArgumentList "/sagerun:118" -PassThru
                        $null = $p.Handle; $t0 = Get-Date
                        while (-not $p.WaitForExit(1000)) { $SyncHash.LastBeat = Get-Date; if (((Get-Date) - $t0).TotalMinutes -ge 30) { break } }
                        $after = (Get-PSDrive -Name ($env:SystemDrive.TrimEnd(':')) -ErrorAction SilentlyContinue).Free
                        if ($before -and $after) { $freed = [Math]::Max(0, [Math]::Round(($after - $before) / 1GB, 2)); Log "Disk Cleanup complete: freed $freed GB." } else { Log "Disk Cleanup complete." }
                    } catch { Log "Disk Cleanup couldn't start: $($_.Exception.Message)" }
                }
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
                    # 8.0: TRIM works on BitLocker drives (Windows' own weekly Optimize Drives retrims them), so the
                    # old "Skip TRIM: BitLocker Encrypted" made this do nothing on every PC with device encryption on.
                    Log "Forcing TRIM cycle..."
                    Start-Process "powershell" -ArgumentList "Optimize-Volume -DriveLetter C -ReTrim -Verbose; Pause"
                }
                elseif ($job -eq "MAINT_ICON") {
                    # 8.0 fix: Windows 10/11 keep the icon cache in Explorer\iconcache_*.db; the old code only
                    # deleted the legacy IconCache.db, so the rebuild changed nothing on current Windows. It
                    # also started explorer.exe itself every time (from this ELEVATED engine) instead of
                    # letting Windows respawn the shell as the user - same respawn logic as Restart-Explorer.
                    Log "Rebuilding the icon cache (the taskbar and desktop blink for a moment)..."
                    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
                    Start-Sleep -Milliseconds 500
                    $cleared = 0
                    $cacheFiles = @(Get-Item -LiteralPath "$env:LOCALAPPDATA\IconCache.db" -Force -ErrorAction SilentlyContinue) + @(Get-ChildItem -LiteralPath "$env:LOCALAPPDATA\Microsoft\Windows\Explorer" -Filter "iconcache_*.db" -Force -ErrorAction SilentlyContinue)
                    foreach ($fi in $cacheFiles) { if ($fi) { try { Remove-Item -LiteralPath $fi.FullName -Force -ErrorAction Stop; $cleared++ } catch {} } }
                    $back = $false
                    for ($i = 0; $i -lt 20; $i++) { Start-Sleep -Milliseconds 250; if (Get-Process explorer -ErrorAction SilentlyContinue) { $back = $true; break } }
                    if (-not $back) { try { Start-Process "explorer.exe" -ErrorAction Stop } catch { Log "  - Could not start Explorer: press Ctrl+Shift+Esc > Run new task > explorer." } }
                    Log "Icon cache rebuilt ($cleared cache file(s) cleared). If an icon still looks wrong, sign out and back in."
                }
                # 8.0: DISM first, then SFC (Microsoft's own order: SFC repairs from the component store DISM fixes), and
                # "&" not "&&" - SFC's non-zero exit after finding problems used to skip DISM, the step that fixes them.
                elseif ($job -eq "REPAIR_FULL") { Log "Full Repair (DISM RestoreHealth, then SFC, then a CHKDSK scan)..."; Start-Process "cmd.exe" -ArgumentList "/k dism /online /cleanup-image /restorehealth & sfc /scannow & chkdsk C: /scan" }
                elseif ($job -eq "DEBLOAT_SCAN") {
                    Log "DEBLOAT: Scanning installed apps (a few seconds)..."
                    # Never shown - removing these breaks Windows, the Store, winget, or Ronin itself
                    $dbProtected = @(
                        "Microsoft.WindowsStore","Microsoft.DesktopAppInstaller","Microsoft.SecHealthUI",
                        "Microsoft.WindowsTerminal","Microsoft.AAD.BrokerPlugin","Microsoft.AccountsControl",
                        "Microsoft.Windows.ShellExperienceHost","Microsoft.Windows.StartMenuExperienceHost",
                        "Microsoft.Windows.Search","Microsoft.UI.Xaml","Microsoft.VCLibs","Microsoft.NET",
                        "Microsoft.WindowsAppRuntime","Microsoft.Win32WebViewHost","Microsoft.MicrosoftEdge",
                        "Microsoft.EdgeWebView","MicrosoftWindows.Client","Microsoft.Windows.CloudExperienceHost",
                        "Microsoft.ApplicationCompatibilityEnhancements","Microsoft.AV1VideoExtension",
                        "Microsoft.HEVCVideoExtension","Microsoft.VP9VideoExtensions","Microsoft.WebpImageExtension",
                        "Microsoft.HEIFImageExtension","Microsoft.RawImageExtension","Microsoft.StorePurchaseApp",
                        "Microsoft.Services.Store.Engagement","Microsoft.XboxGameCallableUI","Microsoft.Windows.NarratorQuickStart",
                        # 8.0: infrastructure the scan used to OFFER under raw package names (found on the dev PC):
                        # display-language packs, the Windows App Runtime's other package names, winget's own
                        # sources (Install Apps + the VC++ button need them), Game Pass' Gaming Services,
                        # media codecs, handwriting recognition, the widgets runtime, and WSL.
                        "Microsoft.LanguageExperiencePack","Microsoft.Ink.Handwriting","Microsoft.WinAppRuntime",
                        "MicrosoftCorporationII.WinAppRuntime","Microsoft.Winget.","Microsoft.GamingServices",
                        "Microsoft.WebMediaExtensions","Microsoft.MPEG2VideoExtension","Microsoft.AVCEncoderVideoExtension",
                        "Microsoft.DolbyAudioExtensions","Microsoft.WidgetsPlatformRuntime","MicrosoftCorporationII.WindowsSubsystemForLinux"
                    )
                    # Pre-checked junk. Xbox/Game Bar apps deliberately NOT pre-checked (handheld users need Game Pass).
                    $dbRecommended = @(
                        "Microsoft.BingNews","Microsoft.BingWeather","Microsoft.BingSearch","Microsoft.GetHelp",
                        "Microsoft.Getstarted","Microsoft.MicrosoftOfficeHub","Microsoft.MicrosoftSolitaireCollection",
                        "Microsoft.People","Microsoft.SkypeApp","Microsoft.Wallet","Microsoft.WindowsFeedbackHub",
                        "Microsoft.WindowsMaps","Microsoft.ZuneVideo","Microsoft.MixedReality.Portal",
                        "Microsoft.Microsoft3DViewer","MSTeams","MicrosoftTeams","Clipchamp.Clipchamp",
                        "Microsoft.OutlookForWindows","Microsoft.PowerAutomateDesktop","Microsoft.Todos",
                        "MicrosoftCorporationII.MicrosoftFamily","Microsoft.OneConnect","Microsoft.Print3D",
                        "SpotifyAB.SpotifyMusic","Disney.37853FC22B2CE","Netflix.Netflix","BytedancePte.Ltd.TikTok",
                        "king.com.CandyCrushSaga","king.com.CandyCrushSodaSaga","Facebook.Facebook","Facebook.InstagramBeta",
                        "7EE7776C.LinkedInforWindows","AmazonVideo.PrimeVideo"
                    )
                    $dbFriendly = @{
                        "Microsoft.BingNews"="Microsoft News"; "Microsoft.BingWeather"="Weather"; "Microsoft.BingSearch"="Bing Search";
                        "Microsoft.GetHelp"="Get Help"; "Microsoft.Getstarted"="Tips / Get Started"; "Microsoft.MicrosoftOfficeHub"="Office Hub (M365 promo)";
                        "Microsoft.MicrosoftSolitaireCollection"="Solitaire Collection"; "Microsoft.People"="People"; "Microsoft.SkypeApp"="Skype";
                        "Microsoft.Wallet"="Microsoft Wallet"; "Microsoft.WindowsFeedbackHub"="Feedback Hub"; "Microsoft.WindowsMaps"="Windows Maps";
                        "Microsoft.ZuneVideo"="Movies & TV"; "Microsoft.ZuneMusic"="Windows Media Player"; "Microsoft.MixedReality.Portal"="Mixed Reality Portal";
                        "Microsoft.Microsoft3DViewer"="3D Viewer"; "MSTeams"="Microsoft Teams"; "MicrosoftTeams"="Microsoft Teams (Classic)";
                        "Clipchamp.Clipchamp"="Clipchamp Video Editor"; "Microsoft.OutlookForWindows"="Outlook (new)"; "Microsoft.PowerAutomateDesktop"="Power Automate";
                        "Microsoft.Todos"="Microsoft To Do"; "MicrosoftCorporationII.MicrosoftFamily"="Family Safety"; "Microsoft.OneConnect"="Mobile Plans";
                        "Microsoft.Print3D"="Print 3D"; "Microsoft.Office.OneNote"="OneNote (Store)"; "Microsoft.WindowsAlarms"="Clock & Alarms";
                        "Microsoft.WindowsCamera"="Camera"; "Microsoft.WindowsCalculator"="Calculator"; "Microsoft.Windows.Photos"="Photos";
                        "Microsoft.WindowsNotepad"="Notepad"; "Microsoft.ScreenSketch"="Snipping Tool"; "Microsoft.Paint"="Paint";
                        "Microsoft.WindowsSoundRecorder"="Sound Recorder"; "Microsoft.YourPhone"="Phone Link"; "Microsoft.GamingApp"="Xbox App (Game Pass)";
                        "Microsoft.XboxGamingOverlay"="Xbox Game Bar"; "Microsoft.XboxIdentityProvider"="Xbox Identity (sign-in)";
                        "Microsoft.XboxSpeechToTextOverlay"="Xbox Speech-to-Text"; "Microsoft.Xbox.TCUI"="Xbox Social (TCUI)";
                        "microsoft.windowscommunicationsapps"="Mail & Calendar (legacy)"; "Microsoft.MicrosoftStickyNotes"="Sticky Notes";
                        "SpotifyAB.SpotifyMusic"="Spotify (preinstalled stub)"; "Disney.37853FC22B2CE"="Disney+"; "Netflix.Netflix"="Netflix";
                        "BytedancePte.Ltd.TikTok"="TikTok"; "king.com.CandyCrushSaga"="Candy Crush Saga"; "king.com.CandyCrushSodaSaga"="Candy Crush Soda";
                        "Facebook.Facebook"="Facebook"; "Facebook.InstagramBeta"="Instagram"; "7EE7776C.LinkedInforWindows"="LinkedIn";
                        "AmazonVideo.PrimeVideo"="Prime Video"; "Microsoft.549981C3F5F10"="Cortana"; "Microsoft.WindowsLiveTiles"="Live Tiles";
                        "Microsoft.Windows.DevHome"="Dev Home"; "MicrosoftCorporationII.QuickAssist"="Quick Assist";
                        "Microsoft.StartExperiencesApp"="Start Experiences (Start menu ads)";
                        # 8.0: driver / hardware companions get plain labels so nobody removes them by mistake
                        "NVIDIACorp.NVIDIAControlPanel"="NVIDIA Control Panel (driver settings)";
                        "AdvancedMicroDevicesInc-2.AMDRadeonSoftware"="AMD Radeon Software (driver settings)";
                        "AppUp.IntelGraphicsExperience"="Intel Graphics Command Center (driver settings)";
                        "RealtekSemiconductorCorp.RealtekAudioControl"="Realtek Audio Console (audio settings)";
                        "DolbyLaboratories.DolbyAccess"="Dolby Access (audio settings)"; "9426MICRO-STARINTERNATION.MSICenter"="MSI Center";
                        "MicrosoftCorporationII.WindowsHDRCalibration"="Windows HDR Calibration"; "MicrosoftWindows.CrossDevice"="Cross-device experiences (Phone Link helper)";
                        "Microsoft.XboxApp"="Xbox Console Companion (old)"; "Microsoft.XboxGameOverlay"="Xbox Game Bar add-on (old)";
                        "Microsoft.Copilot"="Copilot"; "Microsoft.Edge.GameAssist"="Edge Game Assist"
                    }
                    $found = New-Object System.Collections.Generic.List[object]
                    try {
                        $pkgs = Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object {
                            -not $_.IsFramework -and -not $_.NonRemovable
                        } | Sort-Object Name -Unique
                        foreach ($p in $pkgs) {
                            $isProtected = $false
                            foreach ($pref in $dbProtected) { if ($p.Name -like "$pref*") { $isProtected = $true; break } }
                            if ($isProtected) { continue }
                            $disp = if ($dbFriendly.ContainsKey($p.Name)) { $dbFriendly[$p.Name] } else { ($p.Name -replace '^(Microsoft(CorporationII)?|MicrosoftWindows)\.','') }
                            $rec = ($dbRecommended -contains $p.Name)
                            $found.Add([PSCustomObject]@{ Pkg=$p.Name; Display=$disp; Rec=$rec })
                        }
                    } catch { Log "DEBLOAT: Scan error: $($_.Exception.Message)" }
                    # OneDrive desktop app (not an Appx) - offered as an extra entry when present
                    $odSetup = if ([Environment]::Is64BitOperatingSystem) { "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" } else { "$env:SystemRoot\System32\OneDriveSetup.exe" }
                    if ((Test-Path $odSetup) -and (Test-Path "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe")) {
                        $found.Add([PSCustomObject]@{ Pkg="RONIN_ONEDRIVE"; Display="Microsoft OneDrive (desktop app)"; Rec=$false })
                    }
                    $SyncHash.DebloatApps = @($found | Sort-Object @{e={-not $_.Rec}}, Display)
                    Log "DEBLOAT: Found $($SyncHash.DebloatApps.Count) removable apps."
                    # The dialog is built by the UI (Show-DebloatCenter in src/Ronin.ps1), never here: when the
                    # engine built it, CANCEL could hang the UI thread forever (invariant 12).
                    if ($SyncHash.ShowDebloatCenter) { [void]$SyncHash.Window.Dispatcher.BeginInvoke($SyncHash.ShowDebloatCenter); Write-Diag "DEBLOAT: asked the UI to open the dialog" "ENGINE" }
                    else { Log "DEBLOAT: Could not open the Debloat Center (UI not ready)." }
                }
                elseif ($job -eq "DEBLOAT_REMOVE") {
                    $sel = @($SyncHash.DebloatSelection)
                    if ($sel.Count -gt 0) {
                        Log "DEBLOAT: Removing $($sel.Count) app(s)..."
                        $SyncHash.Window.Dispatcher.Invoke({ $SyncHash.ProgBar.Visibility = "Visible"; $SyncHash.ProgBar.Maximum = $sel.Count; $SyncHash.ProgBar.Value = 0 })
                        $okCount = 0; $failCount = 0; $n = 0
                        # 8.0: friendly names for the removal record (Maintenance > Changes made by Ronin).
                        $friendly = @{}; foreach ($a in @($SyncHash.DebloatApps)) { if ($a -and $a.Pkg) { $friendly["$($a.Pkg)"] = "$($a.Display)" } }
                        # 8.0: the provisioned-package list (several seconds to read) is read ONCE, not once per app.
                        $prov = @(); try { $prov = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue) } catch {}
                        foreach ($name in $sel) {
                            $n++; $SyncHash.Window.Dispatcher.Invoke({ $SyncHash.ProgBar.Value = $n })
                            # 8.0: per-app liveness beat. An all-users removal can take 10-30 s, so 20 apps
                            # outlasted the 180 s watchdog and raised a false "ENGINE NOT RESPONDING" banner.
                            $SyncHash.CurrentOp = "Remove $name ($n/$($sel.Count))"; $SyncHash.LastBeat = Get-Date
                            if ($name -eq "RONIN_ONEDRIVE") {
                                Log "  - Uninstalling OneDrive (desktop app)..."
                                try {
                                    Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
                                    $odSetup = if ([Environment]::Is64BitOperatingSystem) { "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" } else { "$env:SystemRoot\System32\OneDriveSetup.exe" }
                                    if (Test-Path $odSetup) { [void](Invoke-RoninProcess $odSetup "/uninstall" 15); $okCount++; Add-RemovedApp $name "Microsoft OneDrive (desktop app)" }
                                } catch { Log "    -> OneDrive removal error: $($_.Exception.Message)"; $failCount++ }
                                continue
                            }
                            Log "  - Removing $name..."
                            try {
                                Get-AppxPackage -Name $name -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                                foreach ($pp in $prov) { if ($pp.DisplayName -eq $name) { $pp | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null } }
                                if (Get-AppxPackage -Name $name -ErrorAction SilentlyContinue) {
                                    $failCount++; Log "    -> still present (system-protected on this build)"
                                } else { $okCount++; Add-RemovedApp $name $(if ($friendly.ContainsKey($name)) { $friendly[$name] } else { $name }) }
                            } catch { $failCount++; Log "    -> FAILED: $($_.Exception.Message)" }
                        }
                        $SyncHash.Window.Dispatcher.Invoke({ $SyncHash.ProgBar.Visibility = "Collapsed" })
                        Log "DEBLOAT COMPLETE: $okCount removed, $failCount could not be removed."
                    }
                }
                elseif ($job -eq "WINGET_INSTALL") {
                    # 8.0 App installer (Declutter > Install Apps). The ONLY Ronin feature that reaches the
                    # internet on its own initiative - through Microsoft's winget, and only after the user
                    # ticks apps and confirms. Package IDs are a fixed, verified list in src/Ronin.ps1
                    # ($script:AppCatalog); nothing typed by anyone is ever passed to winget.
                    $sel = @($SyncHash.InstallSelection)
                    $wg = Get-Command "winget.exe" -ErrorAction SilentlyContinue
                    if ($sel.Count -eq 0) { Log "INSTALL: nothing selected." }
                    elseif (-not $wg) { Log "INSTALL: winget isn't available on this PC. Install or update 'App Installer' from the Microsoft Store, then try again." }
                    else {
                        Log "INSTALL: $($sel.Count) app(s) via winget. This downloads from each app's publisher."
                        $SyncHash.Window.Dispatcher.Invoke({ $SyncHash.ProgBar.Visibility = "Visible"; $SyncHash.ProgBar.Maximum = $sel.Count; $SyncHash.ProgBar.Value = 0 })
                        $ok = 0; $had = 0; $bad = 0; $n = 0
                        foreach ($app in $sel) {
                            $n++; $SyncHash.Window.Dispatcher.Invoke({ $SyncHash.ProgBar.Value = $n })
                            if ("$($app.Id)" -notmatch '^[A-Za-z0-9][A-Za-z0-9.+_-]*$') { Log "  - Skipped '$($app.Id)' (not a valid package ID)."; $bad++; continue }
                            $SyncHash.CurrentOp = "Install $($app.Id) ($n/$($sel.Count))"; $SyncHash.LastBeat = Get-Date
                            Log "  - Installing $($app.Name)..."
                            $wargs = "install --id $($app.Id) --exact --source winget --silent --disable-interactivity --accept-package-agreements --accept-source-agreements"
                            try {
                                $p = Start-Process -FilePath $wg.Source -ArgumentList $wargs -WindowStyle Hidden -PassThru
                                $null = $p.Handle   # PS 5.1: without this ExitCode can come back $null
                                $t0 = Get-Date
                                # Installers can take minutes: keep the engine's liveness beat moving so the
                                # watchdog never mistakes a big download for a hang; give up after 30 min.
                                while (-not $p.WaitForExit(1000)) {
                                    $SyncHash.LastBeat = Get-Date
                                    if (((Get-Date) - $t0).TotalMinutes -ge 30) { try { $p.Kill() } catch {}; break }
                                }
                                $code = if ($p.HasExited) { $p.ExitCode } else { $null }
                                # winget codes: 0 ok; 0x8A150061 already installed; 0x8A15002B no newer version;
                                # 0x8A150014 no package found. Anything else is reported with its hex for lookup.
                                if ($code -eq 0) { $ok++; Log "    -> installed." }
                                elseif ($code -eq -1978335135 -or $code -eq -1978335189) { $had++; Log "    -> already installed." }
                                elseif ($null -eq $code) { $bad++; Log "    -> stopped after 30 minutes (still not finished)." }
                                else { $bad++; Log ("    -> failed (winget code 0x{0:X8}). Check your internet connection, or install it from the publisher's site." -f $code) }
                            } catch { $bad++; Log "    -> couldn't start winget: $($_.Exception.Message)" }
                        }
                        $SyncHash.Window.Dispatcher.Invoke({ $SyncHash.ProgBar.Visibility = "Collapsed" })
                        Log "INSTALL COMPLETE: $ok installed, $had already installed, $bad failed."
                    }
                }
                # 8.0: IPv4 + IPv6 for every provider, and AUTO restores what each adapter had (Set-/Restore-RoninDns).
                elseif ($job -eq "DNS_Cloudflare") { Set-RoninDns "Cloudflare (1.1.1.1)" @("1.1.1.1", "1.0.0.1", "2606:4700:4700::1111", "2606:4700:4700::1001") }
                elseif ($job -eq "DNS_Google") { Set-RoninDns "Google (8.8.8.8)" @("8.8.8.8", "8.8.4.4", "2001:4860:4860::8888", "2001:4860:4860::8844") }
                elseif ($job -eq "DNS_Quad9") { Set-RoninDns "Quad9 (9.9.9.9, blocks known malware domains)" @("9.9.9.9", "149.112.112.112", "2620:fe::fe", "2620:fe::9") }
                elseif ($job -eq "DNS_Auto") { Log "DNS: putting your previous DNS back..."; Restore-RoninDns; Log "DNS restored. Cache flushed." }
                else { Write-Diag "Unhandled job type: $jobDesc" "WARN" }
                Write-Diag "Job complete: $jobDesc ($([int]((Get-Date) - $jobStart).TotalMilliseconds)ms)" "ENGINE"
                $SyncHash.LastBeat = Get-Date; $SyncHash.CurrentOp = "idle"; $SyncHash.CurrentJob = "idle"
            }
            if (((Get-Date) - $script:LastSensorUpdate).TotalSeconds -ge 3) {
                Update-Sensors
                $script:LastSensorUpdate = Get-Date
            }
            # Liveness beat, stamped every loop pass. The UI watchdog reads this; if it goes
            # stale the engine thread is dead or deadlocked.
            $SyncHash.LastBeat = Get-Date
            # 8.0 UI-THREAD WATCHDOG (diagnose-only, never touches the UI). The UI stamps
            # $SyncHash.UiBeat every 2 s; if that stops while the engine is idle, the window is
            # hung - exactly what the 7.6.0 Debloat freeze looked like (engine beating, UI dead,
            # nothing in any log). This writes the evidence: how long, and the last UI action.
            # After any gap in this loop (sleep/hibernate, a long job) it waits 15 s before judging,
            # so a resumed PC never reports a false stall.
            $nowLoop = Get-Date
            if ($script:LastLoopAt -and ($nowLoop - $script:LastLoopAt).TotalSeconds -gt 10) { $script:UiGraceUntil = $nowLoop.AddSeconds(15) }
            $script:LastLoopAt = $nowLoop
            if ($SyncHash.UiBeat -and (-not $script:UiGraceUntil -or $nowLoop -gt $script:UiGraceUntil)) {
                $uiAge = [int]($nowLoop - $SyncHash.UiBeat).TotalSeconds
                if ($uiAge -ge 30 -and -not $script:UiStallLogged) {
                    $script:UiStallLogged = $true
                    $opAt = if ($SyncHash.UiOpAt) { $SyncHash.UiOpAt.ToString('HH:mm:ss') } else { '?' }
                    Write-Diag "UI THREAD NOT RESPONDING for ${uiAge}s - last UI action: '$($SyncHash.UiOp)' at $opAt" "ERROR"
                } elseif ($uiAge -lt 10 -and $script:UiStallLogged) {
                    $script:UiStallLogged = $false
                    Write-Diag "UI thread responding again" "UI"
                }
            }
            # Heartbeat: if this line stops appearing in the diag log, the engine
            # thread is dead or deadlocked - the smoking gun for "app went silent"
            if (((Get-Date) - $script:LastDiagBeat).TotalSeconds -ge 60) {
                Write-Diag "Engine heartbeat (queue=$($SyncHash.JobQueue.Count))" "ENGINE"
                $script:LastDiagBeat = Get-Date
            }
            Start-Sleep -Milliseconds $SleepDuration
        } Catch { 
            Log "Fatal Core Error: $($_.Exception.Message)"
            Write-DiagException "Engine main loop" $_
            # 8.0: RECOVER instead of staying "busy". A job that died here left CurrentOp/CurrentJob naming
            # it, so Submit-RoninJob refused that button - after a crashed batch, EVERY Apply ("Ignored
            # duplicate request: BATCH") - until another job happened to run, and the tabs stayed greyed
            # out and the progress bar showing: an app that looks frozen. Plain assignments only (inv. 1).
            $SyncHash.CurrentOp = "idle"; $SyncHash.CurrentJob = "idle"
            try { if ($SyncHash.UiRequests) { $SyncHash.UiRequests.Enqueue('RECOVER_UI') } } catch {}
            Start-Sleep -Seconds 1
        }
    }
    Write-Diag "Engine worker thread exiting (Running=$($SyncHash.Running))" "ENGINE"
}
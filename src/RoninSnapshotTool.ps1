<#
.SYNOPSIS
    Project Ronin - Snapshot Recovery Tool v1.1.0

.DESCRIPTION
    Standalone recovery tool for restoring registry values that Ronin backed up
    before applying tweaks. Reads the snapshot database from
    C:\ProgramData\Ronin\Ronin_Snapshots.json and presents a list of original
    values that can be restored individually.

.NOTES
    Project: https://github.com/keiretrogaming/Project-Ronin
    License: MIT
    Requires: Administrator rights (to write to HKLM)
#>

# --- PROJECT RONIN: SNAPSHOT RECOVERY TOOL v1.1.0 ---

Add-Type -AssemblyName PresentationFramework, System.Windows.Forms

$SnapshotFile = "$env:ProgramData\Ronin\Ronin_Snapshots.json"

if (!(Test-Path $SnapshotFile)) {
    [System.Windows.Forms.MessageBox]::Show(
        "No Ronin Snapshots found. System is currently in its original state.",
        "Ronin Recovery"
    ) | Out-Null
    exit
}

# --- PS 5.1 Compatible JSON Parsing ---
$Snapshots = @{}
try {
    $jsonContent = Get-Content $SnapshotFile -Raw
    if (-not [string]::IsNullOrWhiteSpace($jsonContent)) {
        $jsonObj = $jsonContent | ConvertFrom-Json
        if ($jsonObj) {
            $jsonObj.psobject.properties | ForEach-Object {
                $Snapshots[$_.Name] = $_.Value
            }
        }
    }
} catch {
    [System.Windows.Forms.MessageBox]::Show(
        "Failed to parse the Snapshot database. The file may be corrupted or locked.",
        "Ronin Recovery Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit
}

if ($Snapshots.Keys.Count -eq 0) {
    [System.Windows.Forms.MessageBox]::Show(
        "Snapshot database is empty. No backups to recover.",
        "Ronin Recovery"
    ) | Out-Null
    exit
}

$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="RONIN // Snapshot Recovery" Height="500" Width="800" Background="#0A0A0A" Foreground="White">
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <StackPanel Grid.Row="0" Margin="0,0,0,15">
            <TextBlock Text="RECOVERY_PROTOCOL" FontSize="24" FontWeight="Thin" Foreground="#FF2E2E" FontFamily="Consolas"/>
            <TextBlock Text="Select a backup entry and click RESTORE to revert it to its original Windows value." Foreground="#888"/>
        </StackPanel>

        <ListView x:Name="List_Snapshots" Grid.Row="1" Background="#111" Foreground="#CCC" BorderBrush="#333">
            <ListView.View>
                <GridView>
                    <GridViewColumn Header="REGISTRY PATH" DisplayMemberBinding="{Binding Path}" Width="500"/>
                    <GridViewColumn Header="ORIGINAL VALUE" DisplayMemberBinding="{Binding Value}" Width="200"/>
                </GridView>
            </ListView.View>
        </ListView>

        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,15,0,0">
            <Button x:Name="Btn_RestoreAll" Content="RESTORE ALL" Width="130" Height="35" Background="#444" Foreground="White" Margin="0,0,10,0"/>
            <Button x:Name="Btn_Restore" Content="RESTORE SELECTED" Width="160" Height="35" Background="#FF2E2E" Foreground="White" FontWeight="Bold" Margin="0,0,10,0"/>
            <Button x:Name="Btn_Close" Content="CLOSE" Width="100" Height="35" Background="#222" Foreground="White"/>
        </StackPanel>
    </Grid>
</Window>
"@

$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [System.Windows.Markup.XamlReader]::Load($reader)

$list          = $window.FindName("List_Snapshots")
$btnRestore    = $window.FindName("Btn_Restore")
$btnRestoreAll = $window.FindName("Btn_RestoreAll")
$btnClose      = $window.FindName("Btn_Close")

# --- Load snapshots into the ListView ---
foreach ($key in $Snapshots.Keys) {
    $parts   = $key -split "\\"
    $valName = $parts[-1]
    $regPath = ($parts[0..($parts.Length - 2)] -join "\")
    
    $list.Items.Add([PSCustomObject]@{
        Path  = $key
        Value = $Snapshots[$key]
        Name  = $valName
        Reg   = $regPath
    }) | Out-Null
}

function Restore-SnapshotEntry ($entry) {
    # Determine registry hive from the snapshot path
    $hive = if ($entry.Reg -match '^(?i)(hkey_current_user|hkcu)') { "HKCU:" } else { "HKLM:" }
    $cleanPath = $entry.Reg -replace '(?i)^(hkey_current_user\\|hkcu:?\\|hkey_local_machine\\|hklm:?\\)', ''
    $finalPath = "$hive\$cleanPath"

    # Determine value type from PowerShell type
    $type = "DWord"
    if ($entry.Value -is [string]) { $type = "String" }
    elseif ($entry.Value -is [byte[]]) { $type = "Binary" }
    elseif ($entry.Value -is [string[]]) { $type = "MultiString" }

    # Ensure key path exists
    if (!(Test-Path $finalPath)) {
        New-Item -Path $finalPath -Force -ErrorAction Stop | Out-Null
    }

    # Use New-ItemProperty if value doesn't exist yet, Set-ItemProperty otherwise
    # (Set-ItemProperty does NOT accept -PropertyType - that was the bug in v1.0.1)
    $existing = Get-ItemProperty -LiteralPath $finalPath -Name $entry.Name -ErrorAction SilentlyContinue
    if ($null -eq $existing) {
        New-ItemProperty -Path $finalPath -Name $entry.Name -Value $entry.Value -PropertyType $type -Force -ErrorAction Stop | Out-Null
    } else {
        Set-ItemProperty -Path $finalPath -Name $entry.Name -Value $entry.Value -Force -ErrorAction Stop
    }
}

$btnRestore.Add_Click({
    $selected = $list.SelectedItem
    if (-not $selected) {
        [System.Windows.Forms.MessageBox]::Show("Please select an entry first.", "No Selection") | Out-Null
        return
    }
    try {
        Restore-SnapshotEntry $selected
        [System.Windows.Forms.MessageBox]::Show("Restored: $($selected.Name)", "Success") | Out-Null
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Restore Failed: $($_.Exception.Message)",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
})

$btnRestoreAll.Add_Click({
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        "Restore ALL $($list.Items.Count) snapshot entries to their original values?",
        "Confirm Restore All",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    
    $ok = 0; $fail = 0; $errors = @()
    foreach ($item in $list.Items) {
        try {
            Restore-SnapshotEntry $item
            $ok++
        } catch {
            $fail++
            $errors += "$($item.Name): $($_.Exception.Message)"
        }
    }
    
    $msg = "Restore complete.`n`nSuccessful: $ok`nFailed: $fail"
    if ($errors.Count -gt 0) {
        $msg += "`n`nFirst few errors:`n" + ($errors | Select-Object -First 5 | Out-String)
    }
    [System.Windows.Forms.MessageBox]::Show($msg, "Restore All Results") | Out-Null
})

$btnClose.Add_Click({ $window.Close() })

$window.ShowDialog() | Out-Null

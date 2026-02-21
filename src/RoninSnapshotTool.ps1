# --- PROJECT RONIN: SNAPSHOT RECOVERY TOOL (v1.0) ---
# Use this tool to manually view or restore individual registry values 
# backed up by the Ronin Engine.

Add-Type -AssemblyName PresentationFramework, System.Windows.Forms

$SnapshotFile = "$env:ProgramData\Ronin\Ronin_Snapshots.json"

if (!(Test-Path $SnapshotFile)) {
    [System.Windows.Forms.MessageBox]::Show("No Ronin Snapshots found. System is currently in its original state.", "Ronin Recovery")
    exit
}

$Snapshots = Get-Content $SnapshotFile | ConvertFrom-Json -AsHashtable

$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="RONIN // Snapshot Recovery" Height="500" Width="800" Background="#0A0A0A" Foreground="White">
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <StackPanel Grid.Row="0" Margin="0,0,0,15">
            <TextBlock Text="RECOVERY_PROTOCOL" FontSize="24" FontWeight="Thin" Foreground="#FF2E2E" FontFamily="Consolas"/>
            <TextBlock Text="Select a backup entry to restore it to its original Windows value." Foreground="#888"/>
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
            <Button x:Name="Btn_Restore" Content="RESTORE SELECTED" Width="150" Height="35" Background="#FF2E2E" Foreground="White" FontWeight="Bold" Margin="0,0,10,0"/>
            <Button x:Name="Btn_Close" Content="CLOSE" Width="100" Height="35" Background="#222" Foreground="White"/>
        </StackPanel>
    </Grid>
</Window>
"@

$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($xaml))
$window = [System.Windows.Markup.XamlReader]::Load($reader)

$list = $window.FindName("List_Snapshots")
$btnRestore = $window.FindName("Btn_Restore")
$btnClose = $window.FindName("Btn_Close")

# Load snapshots into view
foreach ($key in $Snapshots.Keys) {
    $parts = $key -split "\\"
    $valName = $parts[-1]
    $regPath = ($parts[0..($parts.Length-2)] -join "\")
    
    $list.Items.Add([PSCustomObject]@{
        Path  = $key
        Value = $Snapshots[$key]
        Name  = $valName
        Reg   = $regPath
    })
}

$btnRestore.Add_Click({
    $selected = $list.SelectedItem
    if ($selected) {
        try {
            # Determine Registry Hive
            $hive = if ($selected.Reg -match "hkey_current_user|hkcu") { "HKCU:" } else { "HKLM:" }
            $cleanPath = $selected.Reg -replace "hkey_current_user\\|hkcu:\\|hkey_local_machine\\|hklm:\\", ""
            $finalPath = Join-Path $hive $cleanPath
            
            # Identify Property Type
            $type = "DWord"
            if ($selected.Value -is [string]) { $type = "String" }
            if ($selected.Value -is [byte[]]) { $type = "Binary" }

            if (!(Test-Path $finalPath)) { New-Item -Path $finalPath -Force | Out-Null }
            Set-ItemProperty -Path $finalPath -Name $selected.Name -Value $selected.Value -PropertyType $type -Force
            
            [System.Windows.Forms.MessageBox]::Show("Restored: $($selected.Name)", "Success")
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Restore Failed: $($_.Exception.Message)", "Error")
        }
    }
})

$btnClose.Add_Click({ $window.Close() })

$window.ShowDialog() | Out-Null
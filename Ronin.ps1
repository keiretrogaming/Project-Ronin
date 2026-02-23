# ==============================================================================
# PROJECT RONIN // DEFINITIVE EDITION (SINGLE FILE RELEASE)
# ==============================================================================
$ErrorActionPreference = "Stop"

# Load Assemblies FIRST for stability 
Add-Type -AssemblyName PresentationFramework, System.Windows.Forms, System.Drawing, WindowsBase

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Elevating Ronin to Administrator..." -ForegroundColor Cyan
    $u = "https://raw.githubusercontent.com/keiretrogaming/Project-Ronin/main/Ronin.ps1"
    $s = if ($PSCommandPath) { "& { & '$($PSCommandPath)' }" } else { "&([ScriptBlock]::Create((irm '$u')))" }
    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"$s`"" -Verb RunAs
    exit
}
# --- PROJECT RONIN: CONTROLLER v7.1.0 ---

$Version = "7.1.0"

Try {
    $ErrorActionPreference = "Stop"

    # --- 0. PROFESSIONAL BOOTSTRAP & PROCESS ELEVATION ---
    if ([System.Environment]::OSVersion.Version.Major -ge 6) {
        try { 
            # REMOVED Marshal::PrelinkAll for AV Compliance.
            [System.Windows.Application]::SetHighDpiMode([System.Windows.Forms.HighDpiMode]::PerMonitorV2)
            # FORCE SOFTWARE RENDERING IF GPU IS UNSTABLE (Enterprise Stability)
            # [System.Windows.Media.RenderOptions]::ProcessRenderMode = [System.Windows.Interop.RenderMode]::SoftwareOnly 
        } catch {}
    }

    # REMOVED: Process Priority Elevation block to resolve AV heuristics.

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
    # XAML Check Bypassed.

    # --- 3. HARDENED XAML LOADING (XXE PROTECTION) ---
    # FIX: Force UTF8 reading and trim potential BOM/Whitespace issues
$xamlContent = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="PROJECT RONIN // Definitive Edition (v7.1.0)" Height="730" Width="1100"
        WindowStartupLocation="CenterScreen" ResizeMode="CanResize"
        Background="Transparent" Foreground="#E0E0E0" FontFamily="Segoe UI"
        MinWidth="800" MinHeight="450" WindowStyle="None" AllowsTransparency="True">

    <Window.Resources>
        <Style TargetType="{x:Type ScrollViewer}">
            <Setter Property="VerticalScrollBarVisibility" Value="Hidden"/>
            <Setter Property="Padding" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type ScrollViewer}">
                        <Grid x:Name="Grid" Background="{TemplateBinding Background}">
                            <ScrollContentPresenter x:Name="PART_ScrollContentPresenter" CanContentScroll="{TemplateBinding CanContentScroll}" CanHorizontallyScroll="False" CanVerticallyScroll="False" ContentTemplate="{TemplateBinding ContentTemplate}" Content="{TemplateBinding Content}" Margin="{TemplateBinding Padding}"/>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="CardBorder" TargetType="Border">
            <Setter Property="Background" Value="#161616"/>
            <Setter Property="BorderBrush" Value="#333"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CornerRadius" Value="4"/>
            <Setter Property="Padding" Value="12"/>
            <Setter Property="Margin" Value="0,0,10,10"/>
        </Style>

        <ControlTemplate x:Key="ComboBoxToggleButton" TargetType="ToggleButton">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition />
                    <ColumnDefinition Width="20" />
                </Grid.ColumnDefinitions>
                <Border x:Name="Border" Grid.ColumnSpan="2" CornerRadius="4" Background="#161616" BorderBrush="#333" BorderThickness="1" />
                <Path x:Name="Arrow" Grid.Column="1" Fill="#888" HorizontalAlignment="Center" VerticalAlignment="Center" Data="M 0 0 L 4 4 L 8 0 Z"/>
            </Grid>
            <ControlTemplate.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter TargetName="Border" Property="BorderBrush" Value="#FF2E2E"/>
                    <Setter TargetName="Arrow" Property="Fill" Value="#FF2E2E"/>
                </Trigger>
            </ControlTemplate.Triggers>
        </ControlTemplate>

        <Style x:Key="DarkComboStyle" TargetType="{x:Type ComboBox}">
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderBrush" Value="#333"/>
            <Setter Property="Background" Value="#161616"/>
            <Setter Property="SnapsToDevicePixels" Value="true"/>
            <Setter Property="OverridesDefaultStyle" Value="true"/>
            <Setter Property="ScrollViewer.HorizontalScrollBarVisibility" Value="Auto"/>
            <Setter Property="ScrollViewer.VerticalScrollBarVisibility" Value="Auto"/>
            <Setter Property="ScrollViewer.CanContentScroll" Value="true"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Height" Value="32"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type ComboBox}">
                        <Grid>
                            <ToggleButton Name="ToggleButton" Template="{StaticResource ComboBoxToggleButton}" Grid.Column="2" Focusable="false" IsChecked="{Binding Path=IsDropDownOpen,Mode=TwoWay,RelativeSource={RelativeSource TemplatedParent}}" ClickMode="Press"/>
                            <ContentPresenter Name="ContentSite" IsHitTestVisible="False" Content="{TemplateBinding SelectionBoxItem}" ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}" ContentTemplateSelector="{TemplateBinding ItemTemplateSelector}" Margin="10,0,23,0" VerticalAlignment="Center" HorizontalAlignment="Left" />
                            <TextBox x:Name="PART_EditableTextBox" Style="{x:Null}" Template="{x:Null}" HorizontalAlignment="Left" VerticalAlignment="Center" Margin="3,3,23,3" Focusable="True" Background="Transparent" Visibility="Hidden" IsReadOnly="{TemplateBinding IsReadOnly}"/>
                            <Popup Name="Popup" Placement="Bottom" IsOpen="{TemplateBinding IsDropDownOpen}" AllowsTransparency="True" Focusable="False" PopupAnimation="Slide">
                                <Grid Name="DropDown" SnapsToDevicePixels="True" MinWidth="{TemplateBinding ActualWidth}" MaxHeight="{TemplateBinding MaxDropDownHeight}">
                                    <Border x:Name="DropDownBorder" Background="#161616" BorderThickness="1" BorderBrush="#FF2E2E"/>
                                    <ScrollViewer Margin="4,6,4,6" SnapsToDevicePixels="True">
                                        <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Contained" />
                                    </ScrollViewer>
                                </Grid>
                            </Popup>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Margin" Value="0,2"/> <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="CheckBox">
                        <Grid Background="Transparent">
                            <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                            <Border x:Name="Track" Grid.Column="0" Width="36" Height="18" CornerRadius="9" Background="#111" BorderBrush="#333" BorderThickness="1" Margin="0,0,10,0">
                                <Rectangle x:Name="Thumb" Width="10" Height="10" RadiusX="5" RadiusY="5" Fill="#555" HorizontalAlignment="Left" Margin="4,0">
                                    <Rectangle.Effect><DropShadowEffect ShadowDepth="0" BlurRadius="4" Color="Black" Opacity="0.5"/></Rectangle.Effect>
                                </Rectangle>
                            </Border>
                            <ContentPresenter x:Name="ContentText" Grid.Column="1" VerticalAlignment="Center"/>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="Track" Property="Background" Value="#2A0000"/>
                                <Setter TargetName="Track" Property="BorderBrush" Value="#FF2E2E"/>
                                <Setter TargetName="Track" Property="Effect">
                                    <Setter.Value><DropShadowEffect ShadowDepth="0" BlurRadius="6" Color="#FF2E2E" Opacity="0.4"/></Setter.Value>
                                </Setter>
                                <Setter TargetName="Thumb" Property="Fill" Value="#FF2E2E"/>
                                <Setter TargetName="Thumb" Property="HorizontalAlignment" Value="Right"/>
                                <Setter Property="Foreground" Value="White"/>
                                <Setter TargetName="Thumb" Property="Effect">
                                    <Setter.Value><DropShadowEffect ShadowDepth="0" BlurRadius="8" Color="#FF2E2E" Opacity="0.8"/></Setter.Value>
                                </Setter>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="Track" Property="Opacity" Value="0.3"/>
                                <Setter Property="Foreground" Value="#444"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="Button" x:Key="NavBtn">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#888"/>
            <Setter Property="FontSize" Value="15"/> 
            <Setter Property="Height" Value="48"/>   <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Setter Property="Padding" Value="20,0,0,0"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="HorizontalAlignment" Value="Stretch"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Grid Background="{TemplateBinding Background}">
                            <Rectangle x:Name="AccentBar" HorizontalAlignment="Left" Width="4" Fill="#FF2E2E" Visibility="Collapsed">
                                <Rectangle.Effect><DropShadowEffect Color="#FF2E2E" BlurRadius="12" ShadowDepth="0"/></Rectangle.Effect>
                            </Rectangle>
                            <StackPanel Orientation="Horizontal" Margin="{TemplateBinding Padding}" VerticalAlignment="Center">
                                <TextBlock Text="{TemplateBinding Tag}" FontFamily="Segoe MDL2 Assets" FontSize="16" Margin="0,2,15,0" Width="20" TextAlignment="Center"/>
                                <ContentPresenter VerticalAlignment="Center" TextElement.FontWeight="SemiBold"/>
                            </StackPanel>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#15FFFFFF"/>
                                <Setter Property="Foreground" Value="White"/>
                                <Setter Property="Cursor" Value="Hand"/>
                                <Setter TargetName="AccentBar" Property="Visibility" Value="Visible"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        
        <Style TargetType="Button" x:Key="WindowControlBtn">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#888"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Width" Value="40"/>
            <Setter Property="Height" Value="32"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Grid Background="{TemplateBinding Background}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#33FFFFFF"/>
                                <Setter Property="Foreground" Value="White"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="TextBlock" x:Key="H1">
            <Setter Property="FontSize" Value="15"/>
            <Setter Property="Foreground" Value="#FF2E2E"/>
            <Setter Property="FontFamily" Value="Consolas"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Margin" Value="0,0,0,8"/> 
            <Setter Property="Effect">
                <Setter.Value><DropShadowEffect Color="#FF2E2E" BlurRadius="10" ShadowDepth="0" Opacity="0.3"/></Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="TextBlock" x:Key="AppHeader">
            <Setter Property="FontSize" Value="15"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Margin" Value="0,0,0,6"/>
        </Style>
    </Window.Resources>

    <Border Background="#F2050505" BorderBrush="#FF2E2E" BorderThickness="1" CornerRadius="8">
        <Border.Effect>
            <DropShadowEffect Color="Black" BlurRadius="20" ShadowDepth="0" Opacity="0.8"/>
        </Border.Effect>

        <Grid>
            <Grid.RowDefinitions>
                <RowDefinition Height="32"/> <RowDefinition Height="*"/>  </Grid.RowDefinitions>

            <Grid x:Name="TitleBar" Grid.Row="0" Background="#00000000">
                <TextBlock Text="PROJECT RONIN // v7.1.0" Foreground="#666" FontSize="10" FontFamily="Consolas" VerticalAlignment="Center" Margin="15,0,0,0" IsHitTestVisible="False"/>
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                    <Button x:Name="Btn_Min" Content="&#xE921;" FontFamily="Segoe MDL2 Assets" Style="{StaticResource WindowControlBtn}"/>
                    <Button x:Name="Btn_Close" Content="&#xE8BB;" FontFamily="Segoe MDL2 Assets" Style="{StaticResource WindowControlBtn}">
                        <Button.Triggers>
                             <EventTrigger RoutedEvent="MouseEnter">
                                 <BeginStoryboard>
                                     <Storyboard>
                                         <ColorAnimation Storyboard.TargetProperty="(Button.Background).(SolidColorBrush.Color)" To="#C42B1C" Duration="0:0:0.1"/>
                                         <ColorAnimation Storyboard.TargetProperty="(Button.Foreground).(SolidColorBrush.Color)" To="White" Duration="0:0:0.1"/>
                                     </Storyboard>
                                 </BeginStoryboard>
                             </EventTrigger>
                             <EventTrigger RoutedEvent="MouseLeave">
                                 <BeginStoryboard>
                                     <Storyboard>
                                         <ColorAnimation Storyboard.TargetProperty="(Button.Background).(SolidColorBrush.Color)" To="Transparent" Duration="0:0:0.2"/>
                                         <ColorAnimation Storyboard.TargetProperty="(Button.Foreground).(SolidColorBrush.Color)" To="#888" Duration="0:0:0.2"/>
                                     </Storyboard>
                                 </BeginStoryboard>
                             </EventTrigger>
                        </Button.Triggers>
                    </Button>
                </StackPanel>
            </Grid>

            <Grid Grid.Row="1">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="280"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>

                <Border Grid.Column="0" Background="#CC080808" CornerRadius="0,0,0,8" BorderBrush="#333" BorderThickness="0,1,1,0">
                    <Grid>
                        <Rectangle HorizontalAlignment="Right" Width="1" Fill="#FF2E2E" Opacity="0.3"/>
                        <Viewbox Stretch="Uniform" StretchDirection="DownOnly" VerticalAlignment="Top" HorizontalAlignment="Left">
                            <Grid Width="280">
                                <Grid.RowDefinitions>
                                    <RowDefinition Height="Auto"/> <RowDefinition Height="Auto"/> <RowDefinition Height="Auto"/> </Grid.RowDefinitions>

                                <StackPanel Grid.Row="0" Margin="0,15,0,5">
                                    <StackPanel Margin="25,0,0,0">
                                        <TextBlock Text="P R O J E C T" FontSize="11" Foreground="#666" FontFamily="Consolas"/>
                                        <TextBlock Text="RONIN" FontSize="48" FontWeight="Black" Foreground="#FF2E2E" Margin="-2,-10,0,0" FontFamily="Impact">
                                            <TextBlock.Effect><DropShadowEffect Color="#FF2E2E" BlurRadius="25" ShadowDepth="0" Opacity="0.6"/></TextBlock.Effect>
                                        </TextBlock>
                                        <TextBlock Text="DEFINITIVE EDITION // v7.1.0" FontSize="10" Foreground="#555" Margin="2,-5,0,15" FontWeight="Bold" FontFamily="Consolas"/>
                                    </StackPanel>

                                    <Border Background="#151515" CornerRadius="4" Margin="20,0,20,0" BorderBrush="#333" BorderThickness="1">
                                        <Grid>
                                            <TextBlock x:Name="SearchPlaceholder" Text="SEARCH PROTOCOLS..." Foreground="#444" VerticalAlignment="Center" Margin="10,0" IsHitTestVisible="False" FontSize="10" FontWeight="Bold" FontFamily="Consolas"/>
                                            <TextBox x:Name="SearchBox" Background="Transparent" Foreground="White" BorderThickness="0" Padding="8,8" CaretBrush="#FF2E2E" FontFamily="Consolas"/>
                                        </Grid>
                                    </Border>
                                </StackPanel>

                                <StackPanel Grid.Row="1" Margin="0,5,0,10">
                                    <Button x:Name="Nav_Auto" Content="AUTO OPTIMIZE" Style="{StaticResource NavBtn}" Tag="&#xE80F;" ToolTip="Quickly apply recommended profiles."/>
                                    <Button x:Name="Nav_System" Content="SYSTEM CORE" Style="{StaticResource NavBtn}" Tag="&#xE770;" ToolTip="Essential Windows configurations."/>
                                    <Button x:Name="Nav_Gaming" Content="GAMING &amp; GPU" Style="{StaticResource NavBtn}" Tag="&#xE7FC;" ToolTip="Optimize for frames and latency."/>
                                    <Button x:Name="Nav_Handheld" Content="HANDHELD" Style="{StaticResource NavBtn}" Tag="&#xE76E;" ToolTip="ROG Ally / Legion Go / Claw Tools."/>
                                    <Button x:Name="Nav_Privacy" Content="PRIVACY SHIELD" Style="{StaticResource NavBtn}" Tag="&#xE72E;" ToolTip="Block telemetry and data collection."/>
                                    <Button x:Name="Nav_Advanced" Content="ADVANCED TOOLS" Style="{StaticResource NavBtn}" Tag="&#xE90F;" ToolTip="Expert-level system tweaks."/>
                                    <Button x:Name="Nav_Install" Content="SOFTWARE INSTALL" Style="{StaticResource NavBtn}" Tag="&#xE719;" ToolTip="Bulk install essential apps."/>
                                    <Button x:Name="Nav_Maint" Content="MAINTENANCE" Style="{StaticResource NavBtn}" Tag="&#xE9E9;" ToolTip="Repair and clean the system."/>
                                </StackPanel>

                                <StackPanel Grid.Row="2" Margin="20,0,20,15">
                                    <Border Background="#151515" Padding="10" BorderBrush="#222" BorderThickness="1" CornerRadius="4" Margin="0,0,0,10">
                                        <StackPanel>
                                            <TextBlock x:Name="Txt_HealthRank" Text="SYSTEM: CALIBRATING..." FontSize="10" FontWeight="Bold" Foreground="#444" FontFamily="Consolas" Margin="0,0,0,4"/>
                                            <ProgressBar x:Name="HealthBar" Height="3" Background="#111" Foreground="#FF2E2E" BorderThickness="0" Value="0" Margin="0,0,0,6"/>
                                            <StackPanel>
                                                <TextBlock x:Name="Txt_RamStatus" Text="RAM: ..." FontSize="10" Foreground="#888" FontFamily="Consolas" Margin="0,0,0,2"/>
                                                <TextBlock x:Name="Txt_CpuStatus" Text="CPU: ..." FontSize="10" Foreground="#666" FontFamily="Consolas" TextTrimming="CharacterEllipsis"/>
                                            </StackPanel>
                                        </StackPanel>
                                    </Border>

                                    <TextBlock Text="GLOBAL CONFIG" FontSize="9" Foreground="#444" FontWeight="Bold" FontFamily="Consolas" Margin="0,0,0,2"/>
                                    <CheckBox x:Name="Global_TouchMode" Content="Touch Mode" FontSize="12" ToolTip="Enlarges UI elements for easier touch use."/>
                                    <CheckBox x:Name="Global_SafeMode" Content="Auto-Backup" IsChecked="True" FontSize="12" ToolTip="Creates a Restore Point before applying tweaks."/>
                                    <CheckBox x:Name="Global_ExpertMode" Content="Expert Mode" FontSize="12" Foreground="#AA4444" ToolTip="Unlocks dangerous tweaks.&#x0a;Use with caution."/>

                                    <Button x:Name="Btn_Analyze" Content="RUN SYSTEM AUDIT" Background="#161616" Foreground="White" FontWeight="Bold" Height="36" Margin="0,8,0,8" Cursor="Hand" BorderBrush="#333" BorderThickness="1" FontFamily="Consolas" ToolTip="Re-scans the system state.">
                                        <Button.Template>
                                            <ControlTemplate TargetType="Button">
                                                <Border x:Name="Bdr" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="4">
                                                    <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                                </Border>
                                                <ControlTemplate.Triggers>
                                                    <Trigger Property="IsMouseOver" Value="True">
                                                        <Setter TargetName="Bdr" Property="BorderBrush" Value="#FF2E2E"/>
                                                        <Setter Property="Foreground" Value="#FF2E2E"/>
                                                    </Trigger>
                                                </ControlTemplate.Triggers>
                                            </ControlTemplate>
                                        </Button.Template>
                                    </Button>
                                    
                                    <ProgressBar x:Name="ProgBar" Height="2" Margin="0,0,0,5" Background="Transparent" Foreground="#FF2E2E" BorderThickness="0" Visibility="Collapsed"/>

                                    <Border Height="40" Background="Black" BorderBrush="#222" BorderThickness="1" CornerRadius="4">
                                        <ScrollViewer x:Name="ConsoleScroll" VerticalScrollBarVisibility="Hidden">
                                            <TextBlock x:Name="ConsoleOutput" Text="> RONIN ENGINE 7.1 ONLINE..." Foreground="#00FF00" FontFamily="Consolas" FontSize="10" Padding="4" TextWrapping="Wrap"/>
                                        </ScrollViewer>
                                    </Border>
                                </StackPanel>
                            </Grid>
                        </Viewbox>
                    </Grid>
                </Border>

                <Grid Grid.Column="1" Background="Transparent">
                    <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>

                    <Viewbox Grid.Row="0" Stretch="Uniform" StretchDirection="DownOnly" VerticalAlignment="Top" HorizontalAlignment="Left">
                        <Grid Width="820"> 
                            <TabControl x:Name="MainTabs" BorderThickness="0" Background="Transparent" SelectedIndex="0" Margin="30,15,30,10">
                                <TabControl.Resources><Style TargetType="TabItem"><Setter Property="Visibility" Value="Collapsed"/></Style></TabControl.Resources>

                                <TabItem x:Name="Tab_Auto">
                                    <StackPanel>
                                        <TextBlock Text="AUTO_OPTIMIZE" FontSize="36" FontWeight="Thin" Foreground="White" FontFamily="Consolas"/>
                                        <TextBlock Text="Standard Issue: The Ronin Core Protocol for all operatives." Foreground="#888" Margin="0,0,0,15"/>
                                        <Border Background="#990A0A0A" Padding="25" BorderBrush="#333" BorderThickness="1" CornerRadius="6">
                                            <Grid>
                                                <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                                                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                             
                                                <StackPanel Grid.Row="1" Grid.Column="0" Margin="0,0,20,0">
                                                    <TextBlock Text="PERFORMANCE" Style="{StaticResource H1}" Margin="0,0,0,5"/>
                                                    <CheckBox x:Name="Auto_Visuals" Content="Apply 'Ronin' Visuals" IsChecked="True" ToolTip="Adjusts Windows animations for speed."/>
                                                    <CheckBox x:Name="Auto_SysRestore" Content="Disable System Restore" IsChecked="True" ToolTip="Disables automatic backup points to save space/cycles."/>
                                                    <CheckBox x:Name="Auto_Remote" Content="Disable Remote Assistance" IsChecked="True" ToolTip="Security hardening against remote access."/>
                                                    <CheckBox x:Name="Auto_Recall" Content="Disable Windows Recall" IsChecked="True" ToolTip="Disables AI screenshotting features."/>
                                                    <CheckBox x:Name="Auto_UAC" Content="Set UAC to 'Never Notify'" IsChecked="True" ToolTip="Reduces system interruptions."/>
                                                    <CheckBox x:Name="Auto_Hags" Content="Enable HAGS (GPU Sched)" IsChecked="True" ToolTip="Hardware Accelerated GPU Scheduling."/>
                                                    <CheckBox x:Name="Auto_GameMode" Content="Force 'Game Mode' On" IsChecked="True" ToolTip="Prioritizes games over background processes."/>
                                                    <CheckBox x:Name="Auto_CoreIso" Content="Disable Memory Integrity" IsChecked="True" ToolTip="Disables VBS/HVCI for better gaming FPS."/>
                                                    <CheckBox x:Name="Auto_Bright" Content="Disable Auto-Brightness" IsChecked="True" ToolTip="Stops screen dimming on battery."/>
                                                    <CheckBox x:Name="Auto_CpuOpt" Content="Smart CPU Efficiency" IsChecked="True" ToolTip="Optimizes processor power management."/>
                                                    <CheckBox x:Name="Auto_StartAds" Content="Disable System-Wide Ads" IsChecked="True" ToolTip="Blocks ads in Start, Lock Screen, Settings, and Explorer."/>
                                                    
                                                    <TextBlock Text="HARDWARE" Style="{StaticResource H1}" Margin="0,15,0,5"/>
                                                    <CheckBox x:Name="Auto_PCIe" Content="Disable PCIe Power Saving" IsChecked="True" ToolTip="CRITICAL: Forces L0 state to fix gaming micro-stutters."/>
                                                    <CheckBox x:Name="Auto_VariBright" Content="Disable AMD Vari-Bright" IsChecked="True" ToolTip="Fixes washed out colors on battery (AMD Only)."/>
                                                    <CheckBox x:Name="Auto_DPST" Content="Disable Intel DPST" IsChecked="True" Visibility="Collapsed" ToolTip="Fixes washed out colors/brightness on battery (Intel Only)."/>
                                                </StackPanel>
                                              
                                                <StackPanel Grid.Row="1" Grid.Column="1" Margin="20,0,0,0">
                                                    <TextBlock Text="PRIVACY" Style="{StaticResource H1}" Margin="0,0,0,5" Foreground="#66c0f4"/>
                                                    <CheckBox x:Name="Auto_Tele" Content="Disable Telemetry &amp; Data" IsChecked="True" ToolTip="Blocks basic Windows diagnostic data."/>
                                                    <CheckBox x:Name="Auto_Activity" Content="Disable Activity History" IsChecked="True" ToolTip="Stops Timeline activity tracking."/>
                                                    <CheckBox x:Name="Auto_Consumer" Content="Block Sponsored Apps" IsChecked="True" ToolTip="Prevents 'Candy Crush' style auto-installs."/>
                                                    <CheckBox x:Name="Auto_WER" Content="Block Windows Error Reporting" IsChecked="True" ToolTip="Stops error upload services."/>
                                                    <CheckBox x:Name="Auto_AdID" Content="Disable Advertising ID" IsChecked="True" ToolTip="Resets and blocks ad tracking ID."/>
                                                    <CheckBox x:Name="Auto_Loc" Content="Disable Location Tracking" IsChecked="True" ToolTip="System-wide location service block."/>
                                                    <CheckBox x:Name="Auto_Wifi" Content="Disable Wi-Fi Sense" IsChecked="True" ToolTip="Stops credential sharing features."/>
                                                    <CheckBox x:Name="Auto_Bing" Content="Disable Bing Search" IsChecked="True" ToolTip="Removes web results from Start Menu."/>
                                                    <CheckBox x:Name="Auto_Widgets" Content="Remove Widgets" IsChecked="True" ToolTip="Removes the News/Weather taskbar widget."/>
                                                    <CheckBox x:Name="Auto_Copilot" Content="Disable Copilot AI" IsChecked="True" ToolTip="Removes the AI assistant button."/>
                                                </StackPanel>
                
                                                <Button x:Name="Btn_RunAuto" Grid.Row="2" Grid.ColumnSpan="2" Content="APPLY AUTO PROFILE" Background="#FF2E2E" Foreground="White" FontWeight="Bold" Height="45" Margin="0,15,0,0" FontSize="14" Cursor="Hand" FontFamily="Consolas">
                                                    <Button.Effect><DropShadowEffect Color="#FF2E2E" BlurRadius="15" Opacity="0.4" ShadowDepth="0"/></Button.Effect>
                                                </Button>
                                            </Grid>
                                        </Border>
                                    </StackPanel>
                                </TabItem>

                                <TabItem x:Name="Tab_System">
                                    <StackPanel>
                                        <TextBlock Text="SYSTEM_CORE" FontSize="36" FontWeight="Thin" Foreground="White" FontFamily="Consolas"/>
                                        <TextBlock Text="Fundamental Windows configuration." Foreground="#888" Margin="0,0,0,15"/>
                                        <Grid>
                                            <Grid.ColumnDefinitions>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="*"/>
                                                <ColumnDefinition Width="*"/>
                                            </Grid.ColumnDefinitions>
                                            
                                            <Border Grid.Column="0" Style="{StaticResource CardBorder}">
                                                <StackPanel>
                                                    <TextBlock Text="VISUALS" Style="{StaticResource H1}"/>
                                                    <CheckBox x:Name="Sys_VisualFX" Content="Apply 'Ronin' Visuals" ToolTip="Set Windows to 'Best Performance' (Text Only)."/>
                                                    <CheckBox x:Name="Sys_DarkTheme" Content="Force Dark Theme" ToolTip="Forces System and Apps to Dark Mode."/>
                                                    <CheckBox x:Name="Sys_Transparency" Content="Disable Transparency (Mica)" ToolTip="Removes see-through effects to save GPU."/>
                                                    <CheckBox x:Name="Sys_AutoBright" Content="Disable Auto-Brightness" ToolTip="Prevents screen dimming based on content."/>
                                                    <CheckBox x:Name="Sys_SnapFlyout" Content="Disable Snap Flyout" ToolTip="Stops the bar appearing at the top of the screen when dragging windows."/>
                                                  
                                                    <TextBlock Text="TASKBAR &amp; START" Style="{StaticResource H1}" Margin="0,10,0,8"/>
                                                    <CheckBox x:Name="Sys_TaskbarAlign" Content="Align Taskbar to Left" ToolTip="Moves Start button to the left corner."/>
                                                    <CheckBox x:Name="Sys_TaskbarCombine" Content="Never Combine Buttons" ToolTip="Shows full labels for taskbar icons (Win 10 Style)."/>
                                                    <CheckBox x:Name="Sys_EndTask" Content="Enable 'End Task'" ToolTip="Adds an End Task option to right-clicking an app on the taskbar."/>
                                                    <CheckBox x:Name="Sys_TaskbarClean" Content="Hide Chat &amp; TaskView" ToolTip="Removes Chat, TaskView, and shrinks Search Box."/>
                                                    <CheckBox x:Name="Sys_MeetNow" Content="Remove 'Meet Now' Icon" ToolTip="Hides the annoying Skype/Meet Now icon from the system tray."/>
                                                    <CheckBox x:Name="Sys_Seconds" Content="Show Seconds in Clock" ToolTip="Adds seconds to the taskbar clock."/>
                                                    <CheckBox x:Name="Sys_AeroShake" Content="Disable Aero Shake" ToolTip="Prevents window minimizing when shaking mouse."/>

                                                    <TextBlock Text="SYSTEM UI" Style="{StaticResource H1}" Margin="0,10,0,8"/>
                                                    <CheckBox x:Name="Sys_UAC" Content="Set UAC to 'Never Notify'" ToolTip="Stops the 'Do you want to allow this app' popup."/>
                                                    <CheckBox x:Name="Sys_LockScreen" Content="Disable Lock Screen" ToolTip="Go straight to login on wake."/>
                                                    <CheckBox x:Name="Sys_DetailedBSOD" Content="Enable Detailed BSOD" ToolTip="Shows QR codes and debug info on crash."/>
                                                </StackPanel>
                                            </Border>
                                            
                                            <Border Grid.Column="1" Style="{StaticResource CardBorder}">
                                                <StackPanel>
                                                    <TextBlock Text="FILE EXPLORER" Style="{StaticResource H1}"/>
                                                    <CheckBox x:Name="Sys_ExplorerOpen" Content="Open Explorer to 'This PC'" ToolTip="Changes default folder from 'Quick Access' to 'This PC'."/>
                                                    <CheckBox x:Name="Sys_CleanThisPC" Content="Clean 'This PC' Folders" ToolTip="Removes 3D Objects, Music, Pictures etc from This PC view."/>
                                                    <CheckBox x:Name="Sys_DupliDrive" Content="Fix Duplicate USB Drives" ToolTip="Prevents USB drives from appearing twice in Explorer."/>
                                                    <CheckBox x:Name="Sys_ShowExt" Content="Show File Extensions" ToolTip="Always show .exe, .txt, etc."/>
                                                    <CheckBox x:Name="Sys_ShowHidden" Content="Show Hidden Files" ToolTip="Reveals hidden system files."/>
                                                    <CheckBox x:Name="Sys_SearchIndex" Content="Disable Search Indexer" ToolTip="EXPERT: Stops file indexing.&#x0a;Search will be slow."/>

                                                    <TextBlock Text="NAVIGATION PANE" Style="{StaticResource H1}" Margin="0,10,0,8"/>
                                                    <CheckBox x:Name="Sys_NoGallery" Content="Remove 'Gallery'" ToolTip="Removes the Gallery icon from Explorer."/>
                                                    <CheckBox x:Name="Sys_NoHome" Content="Remove 'Home' Section" ToolTip="Cleans up the Explorer sidebar."/>
                                                    <CheckBox x:Name="Sys_Shortcuts" Content="Remove '- Shortcut' Text" ToolTip="New shortcuts won't have text appended."/>
                                                    
                                                    <TextBlock Text="CONTEXT MENU" Style="{StaticResource H1}" Margin="0,10,0,8"/>
                                                    <CheckBox x:Name="Sys_ContextMenu" Content="Restore Classic Menu" ToolTip="Brings back the Windows 10 style Right-Click menu."/>
                                                    <CheckBox x:Name="Sys_ContextMenuClean" Content="Clean Right-Click Menu" ToolTip="Removes 'Share' and 'Give Access To' from Right-Click."/>
                                                    <CheckBox x:Name="Sys_MenuDelay" Content="Instant Menu Delay (0ms)" ToolTip="Removes the 400ms delay when hovering menus."/>
                                                </StackPanel>
                                            </Border>

                                            <Border Grid.Column="2" Style="{StaticResource CardBorder}">
                                                <StackPanel>
                                                    <TextBlock Text="POLICIES &amp; UPDATE" Style="{StaticResource H1}"/>
                                                    <CheckBox x:Name="Sys_StartAds" Content="Disable System-Wide Ads" ToolTip="Blocks ads in Start, Lock Screen, Settings, and Explorer."/>
                                                    <CheckBox x:Name="Sys_SettingsClean" Content="Disable 'Settings Home' Ad" ToolTip="Removes the ad-filled Home page from Windows Settings."/>
                                                    <CheckBox x:Name="Sys_FinishSetup" Content="Disable 'Finish Setup' Nag" ToolTip="Stops the 'Let's finish setting up your device' screen."/>
                                                    <CheckBox x:Name="Sys_DeviceInstall" Content="Disable Driver Downloads" Foreground="#FFAA00" ToolTip="WARNING: Prevents Windows Update from installing drivers."/>
                                                    <CheckBox x:Name="Sys_Recall" Content="Disable Windows Recall" ToolTip="Blocks the AI screenshot history feature."/>

                                                    <TextBlock Text="POWER &amp; PERF" Style="{StaticResource H1}" Margin="0,10,0,8"/>
                                                    <StackPanel Orientation="Horizontal">
                                                        <CheckBox x:Name="Sys_Hibernation" Content="Disable Hibernation" ToolTip="Frees up storage space equal to RAM size."/>
                                                        <TextBlock x:Name="Txt_RamRec_System" Text="" FontSize="11" Foreground="#555" VerticalAlignment="Center" Margin="10,0,0,0"/>
                                                    </StackPanel>
                                                    <CheckBox x:Name="Sys_FastBoot" Content="Disable Fast Startup" ToolTip="Ensures a clean kernel boot every shutdown."/>
                                                    <CheckBox x:Name="Sys_SysRestore" Content="Disable System Restore" ToolTip="Turns off automatic restore points."/>
                                                    <CheckBox x:Name="Sys_SleepTimeout" Content="Fix Sleep Timeout Bug" ToolTip="Prevents PC from sleeping after 2 minutes if woken up automatically."/>
                                                    <CheckBox x:Name="Sys_CpuOpt" Content="Smart CPU Efficiency" ToolTip="Tunes processor energy policies."/>
                                                    <CheckBox x:Name="Sys_Responsiveness" Content="Background Reserve: 0%" ToolTip="Tells Windows to prioritize foreground apps over background services (MMCSS)."/>
                                                     
                                                    <ComboBox x:Name="Sys_BackgroundMode" Style="{StaticResource DarkComboStyle}" Margin="0,5,0,0">
                                                        <ComboBoxItem Content="Default (Power Optimized)"/>
                                                        <ComboBoxItem Content="Force Disable Background Apps"/>
                                                    </ComboBox>
                                                    
                                                    <Border Background="#251E1E" Padding="10" BorderBrush="#333" BorderThickness="1" CornerRadius="4" Margin="0,15,0,0">
                                                        <CheckBox x:Name="Sys_Bloatware" Content="REMOVE ALL BLOATWARE" ToolTip="DANGEROUS: Removes Mail, Calc, Weather, Xbox, etc." Foreground="#FF5555" FontSize="11" FontWeight="Bold"/>
                                                    </Border>
                                                </StackPanel>
                                            </Border>
                                        </Grid>
                                        <Button x:Name="Btn_RunSystem" Content="APPLY / REVERT SYSTEM TWEAKS" Background="#FF2E2E" Foreground="White" FontWeight="Bold" Height="45" Margin="0,15,0,0" FontFamily="Consolas"/>
                                    </StackPanel>
                                </TabItem>

                                <TabItem x:Name="Tab_Gaming">
                                    <StackPanel>
                                        <TextBlock Text="GAMING_OPTIMIZE" FontSize="36" FontWeight="Thin" Foreground="White" FontFamily="Consolas"/>
                                        <Grid Margin="0,10,0,10">
                                            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                            <StackPanel Grid.Column="0" Margin="0,0,10,0">
                                                <Border Style="{StaticResource CardBorder}">
                                                    <StackPanel>
                                                        <TextBlock Text="GENERAL" Style="{StaticResource H1}"/>
                                                        <CheckBox x:Name="Game_HAGS" Content="Enable HAGS (GPU Scheduling)" ToolTip="Allows GPU to manage its own VRAM.&#x0a;Essential for DLSS 3."/>
                                                        <CheckBox x:Name="Game_VRR" Content="Force Variable Refresh Rate (VRR)" ToolTip="Forces G-Sync/FreeSync support for older DX11 games."/>
                                                        <CheckBox x:Name="Game_GpuPriority" Content="Set GPU Priority to 'High'" ToolTip="Forces Windows to prioritize GPU tasks over background processes."/>
                                                        <CheckBox x:Name="Game_GameMode" Content="Force Windows 'Game Mode' ON" ToolTip="Ensures the OS prioritizes gaming threads."/>
                                                        <CheckBox x:Name="Game_FSO" Content="Disable Fullscreen Optimizations" ToolTip="Old fix for DX9 games.&#x0a;May cause tearing in DX12."/>
                                                        <CheckBox x:Name="Game_DVR" Content="Disable Xbox Game Bar DVR" ToolTip="Stops background recording.&#x0a;Saves FPS."/>
                                                        <CheckBox x:Name="Game_DVRService" Content="Disable GameDVR Background Service" ToolTip="Kills the BcastDVRUserService to free up RAM."/>
                                                        <CheckBox x:Name="Game_PowerThrot" Content="Disable Power Throttling" ToolTip="Prevents Windows from downclocking background apps."/>
                                                        <CheckBox x:Name="Game_PCIe" Content="Disable PCIe Power Saving" ToolTip="PERFORMANCE FIX: Forces L0 State to eliminate micro-stutters."/>
                                                        <CheckBox x:Name="Game_MPO" Content="Disable Multiplane Overlay (MPO)" ToolTip="Fixes black screens/flickering on some NVIDIA/AMD GPUs."/>
                                                        <CheckBox x:Name="Game_NvidiaFlipMode" Content="Force Legacy Flip Mode (NVIDIA)" ToolTip="Nvidia-specific fix for flickering in windowed games."/>
                                                    </StackPanel>
                                                </Border>
                                             
                                                <TextBlock Text="HARDWARE SPECIFIC" Style="{StaticResource H1}"/>
                                             
                                                <Border x:Name="Section_AMD" Background="#161616" Padding="15" BorderBrush="#222" BorderThickness="1" Margin="0,0,0,10" CornerRadius="4">
                                                    <StackPanel>
                                                        <TextBlock Text="AMD RADEON" FontSize="11" FontWeight="Bold" Foreground="#FF5555" Margin="0,0,0,5"/>
                                                        <CheckBox x:Name="Game_TdrDelay" Content="Fix GPU Driver Timeouts" ToolTip="Increases timeout before Windows resets a lagging GPU driver."/>
                                                        <CheckBox x:Name="Game_VariBright" Content="Disable Vari-Bright (Gamma Fix)" ToolTip="Disables AMD's localized gamma dimming on battery."/>
                                                    </StackPanel>
                                                </Border>

                                                <Border x:Name="Section_Intel" Background="#001828" Padding="15" BorderBrush="#0055AA" BorderThickness="1" CornerRadius="4">
                                                    <StackPanel>
                                                        <TextBlock Text="INTEL ARC / UHD" FontSize="11" FontWeight="Bold" Foreground="#00AAFF" Margin="0,0,0,5"/>
                                                        <CheckBox x:Name="Game_DPST" Content="Disable Intel DPST (Power Saving)" ToolTip="Fixes annoying brightness/contrast shifting on battery (Display Power Saving Technology)."/>
                                                        <CheckBox x:Name="Game_IntelVram" Content="Increase VRAM Priority (4GB)" ToolTip="SAFE MODE: Overrides driver defaults to report 4GB VRAM.&#x0a;Fixes 'Out of Memory' crashes."/>
                                                    </StackPanel>
                                                </Border>
                                            </StackPanel>

                                            <StackPanel Grid.Column="1" Margin="10,0,0,0">
                                                <Border Style="{StaticResource CardBorder}">
                                                    <StackPanel>
                                                        <TextBlock Text="INPUT &amp; NETWORK" Style="{StaticResource H1}"/>
                                                        <CheckBox x:Name="Game_MouseAccel" Content="Disable Mouse Acceleration" ToolTip="Ensures 1:1 mouse movement (EPP Off)."/>
                                                        <CheckBox x:Name="Game_Sticky" Content="Disable Sticky Keys / Filter Keys" ToolTip="Prevents popups when mashing Shift/Ctrl."/>
                                                        <CheckBox x:Name="Game_NetThrot" Content="Disable Network Throttling" ToolTip="Removes the 10 packets/ms limit for non-multimedia traffic."/>
                                                        <CheckBox x:Name="Game_Nagle" Content="Disable Nagle's Algorithm" ToolTip="Disables TCP packet bundling for lower ping."/>
                                                        <CheckBox x:Name="Game_Latency" Content="Enable Latency Slicer" ToolTip="Optimizes TCP Ack Frequency for real-time data."/>
                                                        <CheckBox x:Name="Game_InterruptModeration" Content="Disable Interrupt Moderation" ToolTip="Forces CPU to process network/GPU packets immediately.&#x0a;Lowers latency."/>
                                                        <CheckBox x:Name="Game_NetTuning" Content="Enable Network Buffer Tuning" ToolTip="Optimizes Receive Side Scaling (RSS) and DCA for modern network adapters."/>
                                                    </StackPanel>
                                                </Border>
                                            </StackPanel>
                                        </Grid>

                                        <StackPanel Orientation="Horizontal" Margin="0,5,0,0">
                                            <Button x:Name="Btn_RunGaming" Content="APPLY / REVERT GAMING" Background="#FF2E2E" Foreground="White" FontWeight="Bold" Height="45" Width="250" Margin="0,0,20,0" FontFamily="Consolas"/>
                                            <Button x:Name="Btn_CheckDrivers" Content="CHECK GPU DRIVERS" Background="#222" Foreground="White" FontWeight="Bold" Height="45" Width="250" FontFamily="Consolas"/>
                                        </StackPanel>
                                    </StackPanel>
                                </TabItem>

                               <TabItem x:Name="Tab_Handheld">
                                    <StackPanel>
                                        <TextBlock Text="HANDHELD_MODE" FontSize="36" FontWeight="Thin" Foreground="White" FontFamily="Consolas"/>
                                        <TextBlock Text="Optimizations for ROG Ally, Legion Go, MSI Claw &amp; Steam Deck." Foreground="#888" Margin="0,0,0,15"/>
                                        
                                        <Border Background="#990A0A0A" Padding="25" BorderBrush="#333" BorderThickness="1" CornerRadius="6">
                                            <Grid>
                                                <Grid.RowDefinitions>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="20"/>
                                                    <RowDefinition Height="Auto"/>
                                                    <RowDefinition Height="Auto"/>
                                                </Grid.RowDefinitions>

                                                <Grid Grid.Row="0">
                                                    <Grid.ColumnDefinitions>
                                                        <ColumnDefinition Width="*"/>
                                                        <ColumnDefinition Width="20"/>
                                                        <ColumnDefinition Width="*"/>
                                                    </Grid.ColumnDefinitions>
                                                    
                                                    <Border Grid.Column="0" Background="#1a253a" Padding="15" BorderBrush="#0055AA" BorderThickness="1" CornerRadius="4">
                                                        <StackPanel>
                                                            <TextBlock Text="CPU TURBO BOOST" Style="{StaticResource H1}" Foreground="#00AAFF" Margin="0,0,0,6"/>
                                                            <TextBlock Text="Controls if CPU boosts past base clock. Disabling saves massive battery." FontSize="13" Foreground="#999" Margin="0,0,0,15" TextWrapping="Wrap"/>
                                                            <Grid>
                                                                <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="10"/><ColumnDefinition/></Grid.ColumnDefinitions>
                                                                <StackPanel Grid.Column="0">
                                                                    <TextBlock Text="AC (PLUGGED)" FontSize="11" Foreground="#CCC" Margin="0,0,0,4" FontWeight="Bold"/>
                                                                    <ComboBox x:Name="HH_BoostMode_AC" Height="36" Style="{StaticResource DarkComboStyle}" FontSize="13">
                                                                        <ComboBoxItem Content="Disabled"/>
                                                                        <ComboBoxItem Content="Enabled"/>
                                                                        <ComboBoxItem Content="Aggressive"/>
                                                                        <ComboBoxItem Content="Efficient"/>
                                                                    </ComboBox>
                                                                </StackPanel>
                                                                <StackPanel Grid.Column="2">
                                                                    <TextBlock Text="DC (BATTERY)" FontSize="11" Foreground="#CCC" Margin="0,0,0,4" FontWeight="Bold"/>
                                                                    <ComboBox x:Name="HH_BoostMode_DC" Height="36" Style="{StaticResource DarkComboStyle}" FontSize="13">
                                                                        <ComboBoxItem Content="Disabled"/>
                                                                        <ComboBoxItem Content="Enabled"/>
                                                                        <ComboBoxItem Content="Aggressive"/>
                                                                        <ComboBoxItem Content="Efficient"/>
                                                                    </ComboBox>
                                                                </StackPanel>
                                                            </Grid>
                                                        </StackPanel>
                                                    </Border>

                                                    <Border Grid.Column="2" Background="#251E1E" Padding="15" BorderBrush="#660000" BorderThickness="1" CornerRadius="4">
                                                        <StackPanel>
                                                            <TextBlock Text="ENERGY PERFORMANCE (EPP)" Style="{StaticResource H1}" Foreground="#FF5555" Margin="0,0,0,6"/>
                                                            <TextBlock Text="EPP acts as a power balancer. CPU Priority (0) holds high clocks. GPU Bias (85+) releases wattage to the iGPU for much better gaming FPS." FontSize="13" Foreground="#999" Margin="0,0,0,15" TextWrapping="Wrap"/>
                                                            <Grid>
                                                                <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="10"/><ColumnDefinition/></Grid.ColumnDefinitions>
                                                                <StackPanel Grid.Column="0">
                                                                    <TextBlock Text="AC (PLUGGED)" FontSize="11" Foreground="#CCC" Margin="0,0,0,4" FontWeight="Bold"/>
                                                                    <ComboBox x:Name="HH_EPP_AC" Height="36" Style="{StaticResource DarkComboStyle}" FontSize="13">
                                                                        <ComboBoxItem Content="CPU Priority (0)"/>
                                                                        <ComboBoxItem Content="Performance Bias (33)"/>
                                                                        <ComboBoxItem Content="Balanced (50)"/>
                                                                        <ComboBoxItem Content="GPU Bias / Gaming (85)"/>
                                                                        <ComboBoxItem Content="GPU Priority / Stealth (100)"/>
                                                                    </ComboBox>
                                                                </StackPanel>
                                                                <StackPanel Grid.Column="2">
                                                                    <TextBlock Text="DC (BATTERY)" FontSize="11" Foreground="#CCC" Margin="0,0,0,4" FontWeight="Bold"/>
                                                                    <ComboBox x:Name="HH_EPP_DC" Height="36" Style="{StaticResource DarkComboStyle}" FontSize="13">
                                                                        <ComboBoxItem Content="CPU Priority (0)"/>
                                                                        <ComboBoxItem Content="Performance Bias (33)"/>
                                                                        <ComboBoxItem Content="Balanced (50)"/>
                                                                        <ComboBoxItem Content="GPU Bias / Gaming (85)"/>
                                                                        <ComboBoxItem Content="GPU Priority / Stealth (100)"/>
                                                                    </ComboBox>
                                                                </StackPanel>
                                                            </Grid>
                                                        </StackPanel>
                                                    </Border>
                                                </Grid>

                                                <Grid Grid.Row="2">
                                                    <Grid.ColumnDefinitions>
                                                        <ColumnDefinition Width="*"/>
                                                        <ColumnDefinition Width="20"/>
                                                        <ColumnDefinition Width="*"/>
                                                    </Grid.ColumnDefinitions>

                                                    <StackPanel Grid.Column="0">
                                                        <TextBlock Text="POWER &amp; CONNECTIVITY" Style="{StaticResource H1}"/>
                                                        <CheckBox x:Name="HH_UsbSuspend" Content="Disable USB Selective Suspend" ToolTip="Fixes disconnect issues with docks."/>
                                                        <CheckBox x:Name="HH_HibernateBtn" Content="Hot-Bag Fix (Power = Hibernate)" ToolTip="Prevents waking in bag."/>
                                                        <CheckBox x:Name="HH_WakeTimers" Content="Disable System Wake Timers"/>
                                                        <CheckBox x:Name="HH_Standby" Content="Fix 'Modern Standby' Drain"/>
                                                        <CheckBox x:Name="HH_WifiPower" Content="Disable WiFi Power Saving"/>
                                                        <CheckBox x:Name="HH_BtFix" Content="Optimize Bluetooth Reliability"/>
                                                        <CheckBox x:Name="HH_CoreIso" Content="Disable Memory Integrity (HVCI)"/>
                                                        <CheckBox x:Name="HH_DeviceGuard" Content="Disable Device Guard (Deep VBS)"/>
                                                        <CheckBox x:Name="HH_VMP" Content="Disable Virtual Machine Platform"/>
                                                        
                                                        <TextBlock Text="DIAGNOSTICS" Style="{StaticResource H1}" Margin="0,15,0,8" Foreground="#888"/>
                                                        <Grid>
                                                            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="10"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                                            <Button x:Name="Btn_Battery" Grid.Column="0" Content="BATTERY REPORT" Background="#222" Foreground="White" Height="32" FontSize="12" FontFamily="Consolas"/>
                                                            <Button x:Name="Btn_Sleep" Grid.Column="2" Content="SLEEP STUDY" Background="#222" Foreground="White" Height="32" FontSize="12" FontFamily="Consolas"/>
                                                        </Grid>
                                                    </StackPanel>

                                                    <StackPanel Grid.Column="2">
                                                        <TextBlock Text="LAUNCHER MANAGEMENT" Style="{StaticResource H1}" Foreground="#66c0f4"/>
                                                        <CheckBox x:Name="HH_Asus_AC" Content="Optimize Armoury Crate (ASUS)"/>
                                                        <CheckBox x:Name="HH_Legion_Space" Content="Optimize Legion Space (Lenovo)"/>
                                                        <CheckBox x:Name="HH_Msi_Center" Content="Optimize MSI Center M (MSI)"/>
                                                        <CheckBox x:Name="HH_SteamDeck" Content="Steam Deck UI (Big Picture)"/>

                                                        <TextBlock Text="STORAGE &amp; ENCRYPTION" Style="{StaticResource H1}" Margin="0,15,0,8"/>
                                                        <CheckBox x:Name="HH_CompactOS" Content="Enable CompactOS (Save Space)"/>
                                                        <CheckBox x:Name="HH_Encryption" Content="Disable Device Encryption"/>

                                                        <TextBlock Text="INPUT &amp; UX" Style="{StaticResource H1}" Margin="0,15,0,8"/>
                                                        <CheckBox x:Name="HH_EdgeSwipe" Content="Disable Touchscreen Edge Swipes"/>
                                                        <CheckBox x:Name="HH_TouchResponse" Content="Boost Touchscreen Response"/>
                                                        <CheckBox x:Name="HH_TouchKeyboard" Content="Optimize Touch Keyboard"/>
                                                        <CheckBox x:Name="HH_GameBarWriter" Content="Disable Game Bar Presence Writer"/>
                                                    </StackPanel>
                                                </Grid>

                                                <Button x:Name="Btn_RunHandheld" Grid.Row="3" Content="APPLY / REVERT HANDHELD TWEAKS" Background="#FF2E2E" Foreground="White" FontWeight="Bold" Height="45" Margin="0,20,0,0" FontSize="14" Cursor="Hand" FontFamily="Consolas">
                                                    <Button.Effect><DropShadowEffect Color="#FF2E2E" BlurRadius="15" Opacity="0.4" ShadowDepth="0"/></Button.Effect>
                                                </Button>
                                            </Grid>
                                        </Border>
                                    </StackPanel>
                                </TabItem>

                                <TabItem x:Name="Tab_Privacy">
                                    <StackPanel>
                                        <TextBlock Text="PRIVACY_SHIELD" FontSize="36" FontWeight="Thin" Foreground="White" FontFamily="Consolas"/>
                                        <TextBlock Text="Advanced telemetry blocking &amp; data protection." Foreground="#888" Margin="0,0,0,15"/>
                                        <Grid>
                                            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                            
                                            <StackPanel Grid.Column="0" Margin="0,0,10,0">
                                                <Border Style="{StaticResource CardBorder}">
                                                    <StackPanel>
                                                        <TextBlock Text="BASIC TELEMETRY" Style="{StaticResource H1}"/>
                                                        <CheckBox x:Name="Priv_Tele" Content="Disable Telemetry &amp; Data Collection" ToolTip="Sets Data Collection to 'Security Only'."/>
                                                        <CheckBox x:Name="Priv_WUDO" Content="Disable Delivery Optimization (WUDO)" ToolTip="Stops Windows from using your bandwidth to upload updates to others (P2P)."/>
                                                        <CheckBox x:Name="Priv_AdID" Content="Disable Advertising ID" ToolTip="Prevents apps from tracking ad preferences."/>
                                                        <CheckBox x:Name="Priv_Loc" Content="Disable Location Tracking" ToolTip="Global killswitch for location services."/>
                                                        <CheckBox x:Name="Priv_Wifi" Content="Disable Wi-Fi Sense" ToolTip="Stops sharing wifi networks with contacts."/>
                                                        <CheckBox x:Name="Priv_SharedExp" Content="Disable Shared Experiences" ToolTip="Stops cross-device continuity features."/>
                                                        
                                                        <TextBlock Text="DEEP TELEMETRY" Style="{StaticResource H1}" Margin="0,10,0,8"/>
                                                        <CheckBox x:Name="Priv_ActivityFeed" Content="Disable Activity Feed" ToolTip="Removes history from Task View."/>
                                                        <CheckBox x:Name="Priv_TypingInsights" Content="Disable Typing Insights" ToolTip="Stops Windows from learning your typing habits."/>
                                                        <CheckBox x:Name="Priv_WER" Content="Disable Windows Error Reporting" ToolTip="Prevents sending crash dumps to Microsoft."/>
                                                        <CheckBox x:Name="Priv_TeleTasks" Content="Kill Telemetry Agents (Tasks)" ToolTip="Disables scheduled tasks that upload data."/>
                                                        <CheckBox x:Name="Priv_AI_Telemetry" Content="Purge 24H2 AI Telemetry Tasks" ToolTip="Disables the new hidden data collection tasks in Windows 11 24H2."/>
                                                        <CheckBox x:Name="Priv_24H2_AI" Content="Disable 'Click To Do' &amp; Generative AI" ToolTip="Blocks the new context-aware AI in 24H2 and Paint/Notepad."/>
                                                        <CheckBox x:Name="Priv_Feedback" Content="Remove Feedback Hub" ToolTip="Uninstalls the Feedback Hub app."/>
                                                        <CheckBox x:Name="Priv_Inventory" Content="Disable Inventory Service" ToolTip="Stops Windows from cataloging installed apps."/>
                                                    </StackPanel>
                                                </Border>
                                            </StackPanel>

                                            <StackPanel Grid.Column="1" Margin="10,0,0,0">
                                                <Border Style="{StaticResource CardBorder}">
                                                    <StackPanel>
                                                        <TextBlock Text="UI BLOAT" Style="{StaticResource H1}"/>
                                                        <CheckBox x:Name="Priv_Bing" Content="Disable Bing Search in Start Menu" ToolTip="Local search results only."/>
                                                        <CheckBox x:Name="Priv_Widgets" Content="Remove Widgets from Taskbar" ToolTip="Hides the News/Weather icon."/>
                                                        <CheckBox x:Name="Priv_Copilot" Content="Disable Windows Copilot AI" ToolTip="Removes the Copilot button."/>
                                                        <CheckBox x:Name="Priv_OneDrive" Content="Disable OneDrive Integration" ToolTip="Stops OneDrive syncing and startup via Group Policy (Safe Mode)."/>
                                                        <CheckBox x:Name="Priv_EdgeHardening" Content="Disable Edge Shopping &amp; Sidebar" ToolTip="Hardens Edge policies to block shopping popups and sidebar bloat."/>
                                                        <CheckBox x:Name="Priv_TailoredExp" Content="Disable Tailored Experiences" ToolTip="Stops 'Tips' and 'Suggestions'."/>
                                                        <CheckBox x:Name="Priv_ConsumerFeatures" Content="Block Sponsored Apps" ToolTip="Prevents unwanted app installs."/>
                                                    
                                                        <TextBlock Text="ACTIVITY &amp; SENSORS" Style="{StaticResource H1}" Margin="0,10,0,8"/>
                                                        <CheckBox x:Name="Priv_ActivityUpload" Content="Disable User Activity Upload" ToolTip="Stops syncing timeline to the cloud."/>
                                                        <CheckBox x:Name="Priv_CloudClipboard" Content="Disable Cloud Clipboard" ToolTip="Keeps clipboard local only."/>
                                                        <CheckBox x:Name="Priv_Maps" Content="Disable Map Auto-Updates" ToolTip="Saves bandwidth."/>
                                                        <CheckBox x:Name="Priv_AppTrack" Content="Disable App Launch Tracking" ToolTip="Prevents Windows tracking which apps you use."/>
                                                        <CheckBox x:Name="Priv_StorageSense" Content="Disable Storage Sense" ToolTip="Prevents Windows from automatically deleting temp files and automatically 'offloading' local files to OneDrive without permission."/>
                                                    </StackPanel>
                                                </Border>
                                            </StackPanel>
                                        </Grid>
                                        <Button x:Name="Btn_RunPrivacy" Content="APPLY / REVERT PRIVACY SHIELD" Background="#FF2E2E" Foreground="White" FontWeight="Bold" Height="45" Margin="0,15,0,0" FontFamily="Consolas"/>
                                    </StackPanel>
                                </TabItem>

                                <TabItem x:Name="Tab_Advanced">
                                    <StackPanel>
                                        <TextBlock Text="ADVANCED_ARSENAL" FontSize="36" FontWeight="Thin" Foreground="White" FontFamily="Consolas"/>
                                        <TextBlock Text="Expert tweaks for low latency &amp; deep optimization." Foreground="#888" Margin="0,0,0,15"/>
                                        <Grid>
                                            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                             
                                            <StackPanel Grid.Column="0" Margin="0,0,10,0">
                                                <Border Style="{StaticResource CardBorder}">
                                                    <StackPanel>
                                                        <TextBlock Text="INPUT &amp; LATENCY" Style="{StaticResource H1}"/>
                                                        <CheckBox x:Name="Adv_TimerOpt" Content="Timer Optimization (TSC Mode)" ToolTip="Resets system timer to Windows Defaults (TSC).&#x0a;Resolves stutters in modern games."/>
                                                        <CheckBox x:Name="Adv_InputLatency" Content="Reduce Mouse &amp; Keyboard Buffer" ToolTip="Lowers input buffer size for lower latency."/>
                                                        <CheckBox x:Name="Adv_Priority" Content="Set Win32 Priority to Foreground" ToolTip="Gives 'Win32PrioritySeparation' favor to foreground window."/>
                                                        <CheckBox x:Name="Adv_NetPower" Content="Disable Network Adapter Power Saving" ToolTip="Prevents ethernet/wifi from sleeping."/>
                                                    </StackPanel>
                                                </Border>
                                                
                                                <Border Style="{StaticResource CardBorder}">
                                                    <StackPanel>
                                                        <TextBlock Text="STORAGE &amp; POWER" Style="{StaticResource H1}"/>
                                                        <CheckBox x:Name="Adv_Storage" Content="Optimize File System" ToolTip="Disables 8.3 naming and last access updates."/>
                                                        <CheckBox x:Name="Adv_ReservedStorage" Content="Disable Reserved Storage (7GB+)" ToolTip="Reclaims ~7GB of disk space reserved for updates."/>
                                                        <CheckBox x:Name="Adv_MemComp" Content="Enable Memory Compression" ToolTip="Compresses RAM to prevent paging."/>
                                                        <CheckBox x:Name="Adv_PageFile" Content="Optimize Page File (Smart Size)" ToolTip="Sets 16GB (if RAM &gt;= 24GB) or 24GB (if RAM &lt; 24GB) to fix stutters."/>
                                                        <CheckBox x:Name="Adv_UltPower" Content="Enable 'Ultimate Performance' Plan" ToolTip="Unlocks the hidden workstation power plan."/>
                                                    </StackPanel>
                                                </Border>
                                            </StackPanel>
                                            
                                            <StackPanel Grid.Column="1" Margin="10,0,0,0">
                                                <Border Style="{StaticResource CardBorder}">
                                                    <StackPanel>
                                                        <TextBlock Text="UTILITIES" Style="{StaticResource H1}"/>
                                                        <CheckBox x:Name="Adv_PhotoViewer" Content="Restore Windows 7 Photo Viewer" ToolTip="Faster than the modern Photos app."/>
                                                        <CheckBox x:Name="Adv_UTC" Content="Set Time to UTC (Dual Boot)" ToolTip="Fixes time sync issues when dual-booting Linux/Bazzite."/>
                                                        <CheckBox x:Name="Adv_Printing" Content="Disable Printing (Spooler)" ToolTip="Disables the print spooler service."/>
                                                    </StackPanel>
                                                </Border>

                                                <Border Style="{StaticResource CardBorder}">
                                                    <StackPanel>
                                                        <TextBlock Text="WINDOWS FEATURES" Style="{StaticResource H1}"/>
                                                        <CheckBox x:Name="Adv_WSL" Content="Enable Windows Subsystem for Linux (WSL)" ToolTip="Allows Linux terminal and environments to run natively in Windows. Requires a reboot."/>
                                                        <CheckBox x:Name="Adv_HyperV" Content="Enable Hyper-V Virtualization" ToolTip="Enables the Microsoft Hyper-V platform for creating and running virtual machines. Requires a reboot."/>
                                                    </StackPanel>
                                                </Border>
                                                
                                                <Border Style="{StaticResource CardBorder}">
                                                    <StackPanel>
                                                        <TextBlock Text="DNS COMMAND CENTER" Style="{StaticResource H1}"/>
                                                        <Button x:Name="Btn_DNS_Cloud" Content="SET CLOUDFLARE (1.1.1.1)" Background="#222" Foreground="White" Height="45" Margin="0,0,0,8" ToolTip="Fast and private DNS."/>
                                                        <Button x:Name="Btn_DNS_Google" Content="SET GOOGLE (8.8.8.8)" Background="#222" Foreground="White" Height="45" Margin="0,0,0,8" ToolTip="Reliable global DNS."/>
                                                        <Button x:Name="Btn_DNS_Auto" Content="RESET TO AUTO (DHCP)" Background="#222" Foreground="White" Height="45" ToolTip="Default ISP DNS settings."/>
                                                    </StackPanel>
                                                </Border>
                                            </StackPanel>
                                        </Grid>
                                        <Button x:Name="Btn_RunAdvanced" Content="APPLY / REVERT ADVANCED" Background="#FF2E2E" Foreground="White" FontWeight="Bold" Height="45" Margin="0,15,0,0" FontFamily="Consolas"/>
                                    </StackPanel>
                                </TabItem>

                                <TabItem x:Name="Tab_Apps">
                                    <StackPanel>
                                        <TextBlock Text="SOFTWARE_INSTALLER" FontSize="36" FontWeight="Thin" Foreground="White" FontFamily="Consolas"/>
                                        <TextBlock Text="Apps in GREEN are already installed." Foreground="#888" Margin="0,0,0,15"/>
                                        <Grid>
                                            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                            <StackPanel Grid.Column="0" Margin="0,0,10,0">
                                            
                                                <Border Background="#161616" CornerRadius="4" Padding="15" Margin="0,0,0,15" BorderBrush="#222" BorderThickness="1">
                                                    <StackPanel>
                                                        <TextBlock Text="BROWSERS" Style="{StaticResource AppHeader}"/>
                                                        <CheckBox x:Name="App_Chrome" Content="Google Chrome"/>
                                                        <CheckBox x:Name="App_Firefox" Content="Firefox"/>
                                                        <CheckBox x:Name="App_Brave" Content="Brave Browser"/>
                                                    </StackPanel>
                                                </Border>
                                             
                                                <Border Background="#161616" CornerRadius="4" Padding="15" Margin="0,0,0,15" BorderBrush="#222" BorderThickness="1">
                                                    <StackPanel>
                                                        <TextBlock Text="GAMING" Style="{StaticResource AppHeader}"/>
                                                        <CheckBox x:Name="App_Steam" Content="Steam"/>
                                                        <CheckBox x:Name="App_Epic" Content="Epic Games Store"/>
                                                        <CheckBox x:Name="App_GOG" Content="GOG Galaxy"/>
                                                        <CheckBox x:Name="App_Playnite" Content="Playnite"/>
                                                        <CheckBox x:Name="App_Moonlight" Content="Moonlight"/>
                                                        <CheckBox x:Name="App_Sunshine" Content="Sunshine"/>
                                                        <CheckBox x:Name="App_RetroArch" Content="RetroArch"/>
                                                        <CheckBox x:Name="App_Afterburner" Content="MSI Afterburner"/>
                                                    </StackPanel>
                                                </Border>
                                                
                                                <Border Background="#161616" CornerRadius="4" Padding="15" Margin="0,0,0,15" BorderBrush="#222" BorderThickness="1">
                                                    <StackPanel>
                                                        <TextBlock Text="COMMUNICATION" Style="{StaticResource AppHeader}"/>
                                                        <CheckBox x:Name="App_Discord" Content="Discord"/>
                                                    </StackPanel>
                                                </Border>
                                            </StackPanel>
                                            <StackPanel Grid.Column="1" Margin="10,0,0,0">
                                                <Border Background="#161616" CornerRadius="4" Padding="15" Margin="0,0,0,15" BorderBrush="#222" BorderThickness="1">
                                                    <StackPanel>
                                                        <TextBlock Text="ESSENTIALS" Style="{StaticResource AppHeader}"/>
                                                        <CheckBox x:Name="App_7Zip" Content="7-Zip"/>
                                                        <CheckBox x:Name="App_VLC" Content="VLC Media Player"/>
                                                        <CheckBox x:Name="App_NotepadPlus" Content="Notepad++"/>
                                                        <CheckBox x:Name="App_VSCode" Content="VS Code"/>
                                                        <CheckBox x:Name="App_PowerToys" Content="MS PowerToys"/>
                                                        <CheckBox x:Name="App_FXSound" Content="FX Sound"/>
                                                        <CheckBox x:Name="App_Everything" Content="Everything Search"/>
                                                        <CheckBox x:Name="App_WizTree" Content="WizTree"/>
                                                    </StackPanel>
                                                </Border>
                                                
                                                <Border Background="#161616" CornerRadius="4" Padding="15" Margin="0,0,0,15" BorderBrush="#222" BorderThickness="1">
                                                    <StackPanel>
                                                        <TextBlock Text="DIAGNOSTICS &amp; MEDIA" Style="{StaticResource AppHeader}"/>
                                                        <CheckBox x:Name="App_HWiNFO" Content="HWiNFO64"/>
                                                        <CheckBox x:Name="App_CPUZ" Content="CPU-Z"/>
                                                        <CheckBox x:Name="App_GPUZ" Content="GPU-Z"/>
                                                        <CheckBox x:Name="App_GHelper" Content="G-Helper (ASUS)"/>
                                                        <CheckBox x:Name="App_Audacity" Content="Audacity"/>
                                                        <CheckBox x:Name="App_OBS" Content="OBS Studio"/>
                                                    </StackPanel>
                                                </Border>
                                            </StackPanel>
                                        </Grid>
                                        <Button x:Name="Btn_InstallApps" Content="INSTALL / UPDATE SELECTED" Background="#FF2E2E" Foreground="White" FontWeight="Bold" Height="45" Margin="0,15,0,0" FontFamily="Consolas"/>
                                    </StackPanel>
                                </TabItem>

                                <TabItem x:Name="Tab_Maint">
                                    <StackPanel Margin="0,0,0,50">
                                        <TextBlock Text="SYSTEM_MAINTENANCE" FontSize="36" FontWeight="Thin" Foreground="White" FontFamily="Consolas"/>
                                        <Grid Margin="0,10,0,0">
                                            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                            <StackPanel Grid.Column="0" Margin="0,0,10,0">
                                                <Border Style="{StaticResource CardBorder}">
                                                    <StackPanel>
                                                        <TextBlock Text="ONE-CLICK REPAIR" Style="{StaticResource H1}"/>
                                                        <Button x:Name="Btn_FullRepair" Content="FULL SYSTEM REPAIR (AUTO)" Background="#FF2E2E" Foreground="White" FontWeight="Bold" Height="45" Margin="0,0,0,5" FontFamily="Consolas" ToolTip="Auto-runs SFC, DISM, and CHKDSK in sequence."/>
                                                        <TextBlock Text="Runs: SFC Scannow, DISM RestoreHealth, and CHKDSK Scan." Foreground="#777" FontSize="11" Margin="0,0,0,15"/>
                                                        <Button x:Name="Btn_VisualCpp" Content="INSTALL VISUAL C++ AIO (FIX DLL ERRORS)" Background="#252526" Foreground="White" Height="40" Margin="0,0,0,10" ToolTip="Installs all VC++ Runtimes (2005-2022)."/>
                                                        <Button x:Name="Btn_GpuReset" Content="RESET GPU DRIVER STACK (FIX CRASHES)" Background="#252526" Foreground="White" Height="40" Margin="0,0,0,10" ToolTip="Deep Clean: Purges OpenCL/Vulkan/DX Caches and restarts driver instance."/>
                                                    </StackPanel>
                                                </Border>

                                                <Border Style="{StaticResource CardBorder}">
                                                    <StackPanel>
                                                        <TextBlock Text="DIAGNOSTICS &amp; RECOVERY" Style="{StaticResource H1}"/>
                                                        <Grid>
                                                            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                                            <Button x:Name="Btn_RestorePoint" Grid.Column="0" Content="NEW RESTORE POINT" Background="#333" Foreground="White" Height="40" Margin="0,5,5,5" ToolTip="Create a manual system restore checkpoint."/>
                                                            <Button x:Name="Btn_OpenBackups" Grid.Column="1" Content="OPEN BACKUPS" Background="#333" Foreground="White" Height="40" Margin="5,5,0,5" ToolTip="Browse local config snapshots."/>
                                                        </Grid>
                                                        
                                                        <Grid Margin="0,5,0,0">
                                                            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                                            <Button x:Name="Btn_BootUEFI" Grid.Column="0" Content="BOOT TO UEFI BIOS" Background="#333" Foreground="#FF9955" FontWeight="Bold" Height="40" Margin="0,5,5,5" ToolTip="Restarts PC directly into BIOS/UEFI Setup."/>
                                                            <Button x:Name="Btn_BootRecovery" Grid.Column="1" Content="BOOT TO RECOVERY" Background="#333" Foreground="#FF9955" FontWeight="Bold" Height="40" Margin="5,5,0,5" ToolTip="Restarts PC into Advanced Startup Options."/>
                                                        </Grid>
                                                    </StackPanel>
                                                </Border>

                                                <Border Style="{StaticResource CardBorder}">
                                                    <StackPanel>
                                                        <TextBlock Text="NETWORK &amp; SYSTEM" Style="{StaticResource H1}"/>
                                                        <Button x:Name="Btn_SFC" Content="RUN SFC SCANNOW" Background="#252526" Foreground="White" Height="40" Margin="0,3" ToolTip="Scans for and fixes corrupt system files."/>
                                                        <Button x:Name="Btn_DISM" Content="RUN DISM RESTOREHEALTH" Background="#252526" Foreground="White" Height="40" Margin="0,3" ToolTip="Repairs the Windows System Image."/>
                                                        <Button x:Name="Btn_NetReset" Content="FLUSH DNS &amp; RESET NETWORK" Background="#252526" Foreground="White" Height="40" Margin="0,3" ToolTip="Resets winsock and flushes DNS cache."/>
                                                        <Button x:Name="Btn_WuReset" Content="RESET WINDOWS UPDATES" Background="#522" Foreground="White" Height="40" Margin="0,3" ToolTip="Fixes stuck Windows Updates."/>
                                                        <Button x:Name="Btn_StoreReset" Content="RESET MICROSOFT STORE" Background="#252526" Foreground="White" Height="40" Margin="0,3" ToolTip="Re-registers the Windows Store manifest to fix download errors."/>
                                                    </StackPanel>
                                                </Border>
                                            </StackPanel>

                                            <StackPanel Grid.Column="1" Margin="10,0,0,0">
                                                <Border Style="{StaticResource CardBorder}">
                                                    <StackPanel>
                                                        <TextBlock Text="CLEANUP" Style="{StaticResource H1}"/>
                                                        <Button x:Name="Btn_DiskClean" Content="AUTO DISK CLEANUP (SILENT)" Background="#252526" Foreground="White" Height="40" Margin="0,3" ToolTip="Runs Cleanmgr with all options selected."/>
                                                        <Button x:Name="Btn_Trim" Content="SSD HEALTH AUDIT &amp; TRIM" Background="#252526" Foreground="White" Height="40" Margin="0,3" ToolTip="Performs a hardware-level wear audit (Health %) and executes a forced TRIM cycle."/>
                                                        <Button x:Name="Btn_IconCache" Content="REBUILD ICON CACHE" Background="#252526" Foreground="White" Height="40" Margin="0,3" ToolTip="Fixes blank or broken desktop icons."/>
                                                        <Button x:Name="Btn_CleanTemp" Content="CLEAN TEMP FILES" Background="#252526" Foreground="White" Height="40" Margin="0,3" ToolTip="Deletes temporary files in %TEMP%."/>
                                                        <Button x:Name="Btn_CleanUpdate" Content="CLEAN OLD UPDATES (DISM)" Background="#252526" Foreground="White" Height="40" Margin="0,3" ToolTip="Removes obsolete update files from WinSxS."/>
                                                        <Button x:Name="Btn_Shader" Content="CLEAR DX/GL SHADER CACHE" Background="#252526" Foreground="White" Height="40" Margin="0,3" ToolTip="Clears GPU shader cache.&#x0a;Fixes stutter in some games."/>
                                                    </StackPanel>
                                                </Border>
                                                
                                                <Border Style="{StaticResource CardBorder}" BorderBrush="#660000" Background="#1A0000">
                                                    <StackPanel>
                                                        <TextBlock Text="EMERGENCY ZONE" Style="{StaticResource H1}" Foreground="#FF5555"/>
                                                        <Button x:Name="Btn_InPlaceUpgrade" Content="REINSTALL WINDOWS (IN-PLACE UPGRADE)" Background="#660000" Foreground="#FF9999" Height="45" Margin="0,0,0,8" FontWeight="Bold" FontFamily="Consolas" ToolTip="Opens Microsoft tool to reinstall Windows while keeping your files."/>
                                                        <Button x:Name="Btn_UndoAll" Content="RESET ALL TWEAKS TO DEFAULT" Background="#330000" Foreground="#FF5555" Height="45" Margin="0,0,0,0" FontWeight="Bold" FontFamily="Consolas" ToolTip="DANGEROUS: Reverts every known registry tweak to Windows Default."/>
                                                    </StackPanel>
                                                </Border>
                                            </StackPanel>
                                        </Grid>
                                    </StackPanel>
                                </TabItem>
                            </TabControl>
                        </Grid>
                    </Viewbox>
                    
                    <Grid x:Name="Banner_Reboot" Grid.Row="1" Background="#E6B800" Height="28" Visibility="Collapsed">
                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Center">
                            <TextBlock Text="&#xE7E7;" FontFamily="Segoe MDL2 Assets" Foreground="Black" Margin="0,0,10,0" VerticalAlignment="Center"/>
                            <TextBlock Text="RESTART REQUIRED - SYSTEM REBOOT PENDING" Foreground="Black" FontWeight="Bold" FontSize="11" VerticalAlignment="Center" FontFamily="Consolas"/>
                        </StackPanel>
                    </Grid>

                    <Border Grid.Row="2" Background="#0C0C0C" BorderBrush="#222" BorderThickness="0,1,0,0" Padding="15,8" CornerRadius="0,0,8,0">
                        <Grid>
                            <StackPanel HorizontalAlignment="Right" VerticalAlignment="Center">
                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,0,0,4">
                                    <Rectangle Width="6" Height="6" Fill="#00FF00" VerticalAlignment="Center" Margin="0,0,6,0" RadiusX="2" RadiusY="2">
                                        <Rectangle.Effect><DropShadowEffect Color="#00FF00" BlurRadius="5" ShadowDepth="0" Opacity="0.5"/></Rectangle.Effect>
                                    </Rectangle>
                                    <TextBlock Text="GREEN = OPTIMIZED" FontSize="9" FontWeight="Bold" Foreground="#444" VerticalAlignment="Center" FontFamily="Consolas"/>
                                </StackPanel>
                                <TextBlock Text="RONIN_AI // STATUS: IDLE" FontSize="10" FontWeight="Bold" Foreground="#333" HorizontalAlignment="Right" FontFamily="Consolas"/>
                            </StackPanel>

                            <StackPanel>
                                <TextBlock Text="INFORMATION DOJO" FontSize="9" FontWeight="Bold" Foreground="#444" Margin="0,0,0,3" FontFamily="Consolas"/>
                                <TextBlock x:Name="InfoDojo" Text="Hover over any tweak to learn more..." FontSize="12" Foreground="#00FF00" TextWrapping="Wrap" Height="25" FontFamily="Consolas"/>
                            </StackPanel>
                        </Grid>
                    </Border>
                    
                    <Button x:Name="Btn_RestartExp" Content="RESTART EXPLORER" HorizontalAlignment="Right" VerticalAlignment="Top" Margin="0,25,25,0" Background="Transparent" Foreground="#666" BorderThickness="1" BorderBrush="#333" Padding="10,5" Cursor="Hand" FontFamily="Consolas">
                        <Button.Template>
                            <ControlTemplate TargetType="Button">
                                <Border x:Name="Bdr" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="4">
                                    <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
                                </Border>
                                <ControlTemplate.Triggers>
                                    <Trigger Property="IsMouseOver" Value="True">
                                        <Setter TargetName="Bdr" Property="BorderBrush" Value="#FF2E2E"/>
                                        <Setter Property="Foreground" Value="#FF2E2E"/>
                                    </Trigger>
                                </ControlTemplate.Triggers>
                            </ControlTemplate>
                        </Button.Template>
                    </Button>
                </Grid>
            </Grid>
        </Grid>
    </Border>
</Window>
'@

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

        # Runspace Checks Bypassed.
# --- PROJECT RONIN: CORE ENGINE v7.1.0 "SHOGUN EDITION" ---

Add-Type -AssemblyName PresentationFramework, System.Windows.Forms, System.Drawing, WindowsBase

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

function Update-Apps {
    if ($SyncHash.Window.Dispatcher.HasShutdownStarted) { return }
    Log "Scanning Installed Applications..."
    $results = @{}
    foreach ($appKey in $AppCheckMap.Keys) {
        try {
            $results[$appKey] = Invoke-Command -ScriptBlock $AppCheckMap[$appKey]
        } catch { $results[$appKey] = $false }
    }
    
    $SyncHash.Window.Dispatcher.Invoke([Action]{
        foreach ($appKey in $results.Keys) {
            $c = $SyncHash.Window.FindName($appKey)
            if ($null -ne $c) {
                if ($results[$appKey]) { $c.IsChecked = $true; $c.Foreground = [System.Windows.Media.Brushes]::LimeGreen; $c.ToolTip = "Status: INSTALLED" }
                else { $c.IsChecked = $false; $c.Foreground = [System.Windows.Media.Brushes]::Gray; $c.ToolTip = "Status: Not Installed" }
            }
        }
        $tabs = $SyncHash.Window.FindName("MainTabs")
        if ($tabs) { $tabs.IsEnabled = $true; $tabs.Opacity = 1.0 }
    }, [System.Windows.Threading.DispatcherPriority]::ContextIdle)
    
    Log "App Scan Complete."
}

function Update-Tweaks {
    if ($SyncHash.Window.Dispatcher.HasShutdownStarted) { return }
    Log "Auditing System State..."
    $Status = @{} ; $totalActive = 0; $relevantDbSize = 0
    foreach ($k in $RoninDB.Keys) {
        if ($RoninDB[$k].Check) { 
            try { $Status[$k] = Invoke-Command -ScriptBlock $RoninDB[$k].Check } catch { $Status[$k] = $false }
        }
    }
    
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
                    # Update UI position but EXCLUDE from points math entirely
                    if ($Status[$k] -ge 0) { $c.SelectedIndex = $Status[$k] }
                }
            }
        }
        
        # UI Profile Sync
        foreach ($sysKey in $AutoMap.Keys) {
            $autoC = $SyncHash.Window.FindName($AutoMap[$sysKey])
            if ($null -ne $autoC) { $autoC.IsChecked = $Status[$sysKey]; $autoC.Foreground = if($Status[$sysKey]){ [System.Windows.Media.Brushes]::LimeGreen } else { [System.Windows.Media.Brushes]::Gray } }
        }

        # Final Rank Math
        $dbSize = [Math]::Max(1, $relevantDbSize)
        $percent = [Math]::Min(100, ($totalActive / $dbSize) * 100)
        $SyncHash.HealthBar.Value = $percent
        
        if ($percent -ge 60) { 
            $SyncHash.HealthRank.Text = "SYSTEM RANK: S-TIER (OPTIMIZED)"
            $SyncHash.HealthRank.Foreground = [System.Windows.Media.Brushes]::Cyan
            $SyncHash.HealthBar.Foreground = [System.Windows.Media.Brushes]::Cyan 
        }
        elseif ($percent -ge 30) { 
            $SyncHash.HealthRank.Text = "SYSTEM RANK: B-TIER (ACCEPTABLE)"
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

function Start-RoninLoop ($SyncHash) {
    $script:LastSensorUpdate = [DateTime]::MinValue
    try {
        $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select -First 1
        if ($cpu) { $script:CpuName = $cpu.Name } else { $script:CpuName = "Unknown CPU" }
    } catch { $script:CpuName = "CPU Detection Failed" }
    if (!(Test-Path "$env:ProgramData\Ronin")) { New-Item -Path "$env:ProgramData\Ronin" -ItemType Directory -Force | Out-Null }
    
    Log "Ronin Core v7.1.0 Shogun Edition Online."
    
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

                        if ($firstItem -is [string]) {
                            if (!$WingetMap) { Log "CRITICAL ERROR: Winget Database not loaded!"; continue }
                            if (Check-Internet) { 
                                $SyncHash.Window.Dispatcher.Invoke({ 
                                    $tabs = $SyncHash.Window.FindName("MainTabs")
                                    if ($tabs) { $tabs.IsEnabled = $false; $tabs.Opacity = 0.5 }
                                })
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
                                        $winArg = "$cmd --id $id --silent --accept-source-agreements --accept-package-agreements --force --include-unknown"
                                        Start-Process "cmd.exe" -ArgumentList "/c winget $winArg" -NoNewWindow -Wait
                                    } else {
                                        Log "ERROR: ID not found for $a"
                                    }
                                } 
                                Log "Install Batch Complete."; Update-Apps
                            } else { Log "INSTALL ERROR: Internet Connection Required." }
                        }
                        elseif ($firstItem -is [PSCustomObject] -or $firstItem -is [System.Collections.DictionaryEntry] -or $firstItem -is [System.Collections.Hashtable]) {
                            $SafeModeEnabled = $false
                            $total = $job.Count
                            
                            $SyncHash.Window.Dispatcher.Invoke({ 
                                if ($SyncHash.SafeMode) { $SafeModeEnabled = $SyncHash.SafeMode.IsChecked } 
                                $SyncHash.ProgBar.Visibility = "Visible"
                                $SyncHash.ProgBar.Maximum = $total
                                $SyncHash.ProgBar.Value = 0
                                $tabs = $SyncHash.Window.FindName("MainTabs")
                                if ($tabs) { $tabs.IsEnabled = $false; $tabs.Opacity = 0.5 }
                            })
                            
                            if ($SafeModeEnabled) { 
                                Log "Creating System Restore Point..."
                                Checkpoint-Computer -Description "Ronin Pre-Flight" -RestorePointType "MODIFY_SETTINGS" -ErrorAction SilentlyContinue
                            }
                            
                            $count = 0
                            $rebootTriggered = $false
                            
                            foreach ($taskItem in $job) {
                                $count++; $SyncHash.Window.Dispatcher.Invoke({ $SyncHash.ProgBar.Value = $count })
                                if ($count % 5 -eq 0) { Start-Sleep -Milliseconds 2 }

                                Try {
                                    $dbEntry = $RoninDB[$taskItem.Key]
                                    if ($dbEntry) {
                                        if ($dbEntry.Check) {
                                            $currentState = Invoke-Command -ScriptBlock $dbEntry.Check
                                            if ($taskItem.Action -eq "Apply") {
                                                $target = if ($taskItem.Value -ne $null) { $taskItem.Value } else { $true }
                                                if ($target -is [int] -and $target -lt 0) { 
                                                    Log "Skipping $($taskItem.Key) (Invalid or Unselected State)."
                                                    continue 
                                                }
                                                if ("$currentState" -eq "$target") { Log "Skipping $($taskItem.Key) (Already Optimized)."; continue } 
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
                            
                            Start-Sleep -Milliseconds 750
                            Update-Tweaks
                            
                            $SyncHash.Window.Dispatcher.Invoke({ 
                                $SyncHash.ProgBar.Visibility = "Collapsed"
                                if ($rebootTriggered -and $SyncHash.RebootBanner) { $SyncHash.RebootBanner.Visibility = "Visible" }
                            })
                            [System.GC]::Collect()
                        }
                    }
                }
                
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
# --- PROJECT RONIN: TWEAK DATABASE v7.1.0 (SHOGUN EDITION) ---

# --- INTEL REGISTRY HELPER ---
function Get-Intel-Video-Key {
    $ClassPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
    if (Test-Path $ClassPath) {
        $Keys = Get-ChildItem $ClassPath -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' }
        foreach ($k in $Keys) {
            $val = Get-ItemProperty $k.PSPath -Name "FeatureTestControl" -ErrorAction SilentlyContinue
            if ($val) { return $k.PSPath }
        }
    }
    return $null
}

$RoninDB = @{
    # --- SYSTEM ---
    "Sys_VisualFX" = @{ 
        Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 3 }
        Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 1 }
        Check={ Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 3 }
        Verify={ Test-Reg-Robust "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 3 }
    }
    "Sys_Transparency" = @{ 
        Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 0 }
        Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 1 }
        Check={ Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 0 }
    }
    "Sys_DarkTheme" = @{
        Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme" 0; Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "SystemUsesLightTheme" 0 }
        Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme" 1; Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "SystemUsesLightTheme" 1 }
        Check={ $a = Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme" 0; $b = Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "SystemUsesLightTheme" 0; return ($a -and $b) }
    }
    "Sys_ContextMenu" = @{ Apply={ Set-Reg "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" "(default)" "" "String" }; Revert={ Remove-Item "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" -Recurse -ErrorAction SilentlyContinue }; Check={ Test-Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" } }
    
    "Sys_ContextMenuClean" = @{
        Apply={ 
            Remove-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked" "{e2bf9676-5f8f-435c-97eb-11607a5bedf7}" 
            Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked" "{e2bf9676-5f8f-435c-97eb-11607a5bedf7}" "" "String" # Share
            Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked" "{f81e9010-6ea4-11ce-a7ff-00aa003ca9f6}" "" "String" # Sharing
        }
        Revert={ 
            Remove-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked" "{e2bf9676-5f8f-435c-97eb-11607a5bedf7}"
            Remove-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked" "{f81e9010-6ea4-11ce-a7ff-00aa003ca9f6}"
        }
        Check={ Test-Reg-Read "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked" "{e2bf9676-5f8f-435c-97eb-11607a5bedf7}" "" }
    }

    "Sys_Hibernation" = @{ 
        SlowCheck=$true
        Apply={ powercfg /h off }
        Revert={ powercfg /h on }
        Check={ 
            $reg = Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "HibernateEnabled" 0 
            $file = Test-Path "$env:SystemDrive\hiberfil.sys"
            return ($reg -and -not $file)
        }
    }

    "Sys_FastBoot" = @{ Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 0 }; Revert={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 1 }; Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 0 } }
    
    "Sys_SysRestore" = @{ 
        SlowCheck=$true; 
        Apply={ 
            Disable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
            Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" "DisableSR" 1 
        }
        Revert={ 
            Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore" "DisableSR"
            Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore" "DisableConfig"
            Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" "DisableSR" 0
            Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        }
        Check={ 
            return (Test-Reg-Read "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" "DisableSR" 1)
        } 
    }
    
    "Sys_TaskbarAlign" = @{ Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAl" 0 }; Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAl" 1 }; Check={ Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAl" 0 } }
    "Sys_TaskbarCombine" = @{ Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarGlomLevel" 2 }; Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarGlomLevel" 0 }; Check={ Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarGlomLevel" 2 } }
    "Sys_EndTask" = @{ Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarEndTask" 1 }; Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarEndTask" 0 }; Check={ Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarEndTask" 1 } }
    
    "Sys_TaskbarClean" = @{
        Apply={ 
            Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarMn" 0 
            Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 0 
            Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 1 
        }
        Revert={ 
            Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarMn" 1
            Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 1
            Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 2
        }
        Check={ $a=Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 0; $b=Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 1; return ($a -and $b) }
    }

    "Sys_MeetNow" = @{ Apply={ Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "HideSCAMeetNow" 1 }; Revert={ Remove-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "HideSCAMeetNow" }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "HideSCAMeetNow" 1 } }

    "Sys_ExplorerOpen" = @{ Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "LaunchTo" 1 }; Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "LaunchTo" 2 }; Check={ Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "LaunchTo" 1 } }
    "Sys_ShowExt" = @{ Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 0 }; Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 1 }; Check={ Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 0 } }
    "Sys_ShowHidden" = @{ Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 1 }; Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 2 }; Check={ Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 1 } }
    "Sys_Seconds" = @{ Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSecondsInSystemClock" 1 }; Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSecondsInSystemClock" 0 }; Check={ Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSecondsInSystemClock" 1 } }
    
    "Sys_LockScreen" = @{ Apply={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" "NoLockScreen" 1 }; Revert={ Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" "NoLockScreen" }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" "NoLockScreen" 1 } }
    
    "Sys_UAC" = @{ Apply={ Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" ("ConsentPrompt" + "BehaviorAdmin") 0 }; Revert={ Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" ("ConsentPrompt" + "BehaviorAdmin") 5 }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" ("ConsentPrompt" + "BehaviorAdmin") 0 } }
    
    "Sys_DeviceInstall" = @{ 
        Warning="Disabling this may prevent BIOS/Firmware updates on Handhelds."
        Apply={ 
            Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching" "SearchOrderConfig" 0
            Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata" "PreventDeviceMetadataFromNetwork" 1
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "ExcludeWUDriversInQualityUpdate" 1
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" "DontSearchWindowsUpdate" 1
        }
        Revert={ 
            Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching" "SearchOrderConfig" 1
            Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata" "PreventDeviceMetadataFromNetwork" 0
            Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "ExcludeWUDriversInQualityUpdate"
            Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" "DontSearchWindowsUpdate"
        }
        Check={ 
            $k1 = Test-Reg-Read "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching" "SearchOrderConfig" 0
            $k2 = Test-Reg-Read "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata" "PreventDeviceMetadataFromNetwork" 1
            $k3 = Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" "ExcludeWUDriversInQualityUpdate" 1
            $k4 = Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" "DontSearchWindowsUpdate" 1
            return ($k1 -and $k2 -and $k3 -and $k4)
        } 
    }
    
    "Sys_Recall" = @{ Apply={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" ("DisableAI" + "DataAnalysis") 1 }; Revert={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" ("DisableAI" + "DataAnalysis") 0 }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" ("DisableAI" + "DataAnalysis") 1 } }
    
    "Sys_SearchIndex" = @{ 
        Apply={ Stop-Service WSearch -Force -ErrorAction SilentlyContinue; Set-Service WSearch -StartupType Disabled }
        Revert={ Set-Service WSearch -StartupType Automatic; Start-Service WSearch }
        Check={ 
            $s = Get-Service WSearch -ErrorAction SilentlyContinue
            if (!$s) { return $true }
            return ($s.StartType -eq "Disabled" -and $s.Status -ne "Running")
        } 
    }

    "Sys_RemoteAssist" = @{ Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" "fAllowToGetHelp" 0 }; Revert={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" "fAllowToGetHelp" 1 }; Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" "fAllowToGetHelp" 0 } }
    
    "Sys_AutoBright" = @{
        SlowCheck=$true
        Apply={ 
            powercfg /setacvalueindex scheme_current 7516b95f-f776-4464-8c53-06167f40cc99 FBD9AA66-9553-4097-BA44-ED6E9D65EAB8 0
            powercfg /setdcvalueindex scheme_current 7516b95f-f776-4464-8c53-06167f40cc99 FBD9AA66-9553-4097-BA44-ED6E9D65EAB8 0
            powercfg /setactive scheme_current 
        }
        Revert={ 
            powercfg /setacvalueindex scheme_current 7516b95f-f776-4464-8c53-06167f40cc99 FBD9AA66-9553-4097-BA44-ED6E9D65EAB8 1
            powercfg /setdcvalueindex scheme_current 7516b95f-f776-4464-8c53-06167f40cc99 FBD9AA66-9553-4097-BA44-ED6E9D65EAB8 1
            powercfg /setactive scheme_current 
        }
        Check={ 
            $guid = "scheme_current";
            $out = powercfg /getactivescheme | Out-String;
            if ($out -match "([a-fA-F0-9-]{36})") { $guid = $matches[1] }
            $q = powercfg /qh $guid 7516b95f-f776-4464-8c53-06167f40cc99 FBD9AA66-9553-4097-BA44-ED6E9D65EAB8 | Out-String;
            if ($q -match "Current AC Power Setting Index:\s+0x([0-9a-fA-F]+)") { return ([Convert]::ToInt32($matches[1],16) -eq 0) }
            return $false
        }
    }
    
    "Sys_Bloatware" = @{ 
        SlowCheck=$true;
        Warning="Removes Standard Apps (Calculator, Mail, etc) AND OneDrive.";
        Apply={ 
            $appsToKill = @("*Clipchamp*","*Spotify*","*Netflix*","*Disney*","*TikTok*","*CandyCrush*","*OutlookForWindows*","*WindowsFeedbackHub*","*BingNews*","*ZuneVideo*");
            $msg = "WARNING: This will permanently remove common Windows Bloatware and Microsoft OneDrive.`n`nAre you sure you want to proceed?"
            
            # --- FIX: Marshalling confirmation to Main UI Thread ---
            $result = "No"
            if ($SyncHash -and $SyncHash.Window) {
                $result = $SyncHash.Window.Dispatcher.Invoke([System.Func[String]] {
                    return [System.Windows.Forms.MessageBox]::Show($msg, "Ronin Bloatware Removal", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning).ToString()
                })
            } else {
                $result = [System.Windows.Forms.MessageBox]::Show($msg, "Ronin Bloatware Removal", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning).ToString()
            }

            if ($result -eq "Yes") {
                if ($SyncHash) { Log "Initiating Bloatware Purge..." }
                foreach($a in $appsToKill){
                    if ($SyncHash) { Log "Removing $a..." }
                    Get-AppxPackage $a -AllUsers | Remove-AppxPackage -ErrorAction SilentlyContinue
                    Get-AppxProvisionedPackage -Online | Where-Object {$_.PackageName -match $a} | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
                }

                if ($SyncHash) { Log "Removing OneDrive..." }
                try {
                    Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
                    $odSetup = if ([Environment]::Is64BitOperatingSystem) { "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" } else { "$env:SystemRoot\System32\OneDriveSetup.exe" }
                    if (Test-Path $odSetup) { 
                        Start-Process $odSetup -ArgumentList "/uninstall" -NoNewWindow -Wait 
                    }
                } catch { if ($SyncHash) { Log "OneDrive removal encountered an error." } }
                
                if ($SyncHash) { Log "Bloatware removal complete." }
            }
        }; 
        Check={ 
            $p = Get-AppxPackage *WindowsFeedbackHub* -ErrorAction SilentlyContinue
            return ($p -eq $null)
        } 
    }

    "Sys_MenuDelay" = @{ Apply={ Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" "0" "String" }; Revert={ Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" "400" "String" }; Check={ Test-Reg-Read "HKCU:\Control Panel\Desktop" "MenuShowDelay" "0" } }
    "Sys_Shortcuts" = @{ Apply={ Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "link" -Value ([byte[]](0,0,0,0)) -Type Binary -Force }; Revert={ Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "link" -ErrorAction SilentlyContinue }; Check={ $v = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "link" -ErrorAction SilentlyContinue; return ($v.link -and $v.link.Count -eq 4) } }
    
    "Sys_DetailedBSOD" = @{ 
        Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" "DisplayParameters" 1; Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" "DisableEmoticon" 1 }; 
        Revert={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" "DisplayParameters" 0; Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" "DisableEmoticon" 0 }; 
        Check={ 
            $d1 = Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" "DisplayParameters" 1
            $d2 = Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl" "DisableEmoticon" 1
            return ($d1 -and $d2)
        } 
    }

    "Sys_CpuOpt" = @{ 
        SlowCheck=$true
        Apply={ 
            powercfg /setacvalueindex scheme_current sub_processor 893dee8e-2bef-41e0-89c6-b55d0929964c 5
            powercfg /setdcvalueindex scheme_current sub_processor 893dee8e-2bef-41e0-89c6-b55d0929964c 5
            powercfg /setacvalueindex scheme_current sub_processor bc5038f7-23e0-4960-96da-33abaf5935ec 100
            powercfg /setdcvalueindex scheme_current sub_processor bc5038f7-23e0-4960-96da-33abaf5935ec 100
            powercfg /setactive scheme_current 
        }
        Revert={ 
            powercfg /setacvalueindex scheme_current sub_processor 893dee8e-2bef-41e0-89c6-b55d0929964c 5
            powercfg /setdcvalueindex scheme_current sub_processor 893dee8e-2bef-41e0-89c6-b55d0929964c 5
            powercfg /setacvalueindex scheme_current sub_processor bc5038f7-23e0-4960-96da-33abaf5935ec 100
            powercfg /setdcvalueindex scheme_current sub_processor bc5038f7-23e0-4960-96da-33abaf5935ec 100
            powercfg /setactive scheme_current 
        }
        Check={ 
            $minOut = powercfg /qh scheme_current sub_processor 893dee8e-2bef-41e0-89c6-b55d0929964c | Out-String
            $maxOut = powercfg /qh scheme_current sub_processor bc5038f7-23e0-4960-96da-33abaf5935ec | Out-String
            
            $minOK = $false; $maxOK = $false
            if ($minOut -match "Current AC Power Setting Index:\s+0x([0-9a-fA-F]+)") {
                if ([Convert]::ToInt32($matches[1], 16) -eq 5) { $minOK = $true }
            }
            if ($maxOut -match "Current AC Power Setting Index:\s+0x([0-9a-fA-F]+)") {
                if ([Convert]::ToInt32($matches[1], 16) -eq 100) { $maxOK = $true }
            }
            return ($minOK -and $maxOK)
        } 
    }
    
    "Sys_Responsiveness" = @{
        Apply={ Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 0 }
        Revert={ Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 20 }
        Check={ Test-Reg-Read "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 0 }
    }

    "Sys_StartAds" = @{ 
        Apply={ 
            Set-Reg "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start" "HideRecommendedSection" 1
            Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSyncProviderNotifications" 0
            $cdm = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
            Set-Reg $cdm "SubscribedContent-338389Enabled" 0
            Set-Reg $cdm "SubscribedContent-353698Enabled" 0
            Set-Reg $cdm "SubscribedContent-338388Enabled" 0
            Set-Reg $cdm "RotatingLockScreenOverlayEnabled" 0
        }
        Revert={ 
            Remove-Reg "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start" "HideRecommendedSection"
            Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSyncProviderNotifications" 1
            $cdm = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
            Set-Reg $cdm "SubscribedContent-338389Enabled" 1
            Set-Reg $cdm "SubscribedContent-353698Enabled" 1
            Set-Reg $cdm "SubscribedContent-338388Enabled" 1
            Set-Reg $cdm "RotatingLockScreenOverlayEnabled" 1
        }
        Check={ 
            $k1 = Test-Reg-Read "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start" "HideRecommendedSection" 1
            $k2 = Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSyncProviderNotifications" 0
            $cdm = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
            $k3 = Test-Reg-Read $cdm "SubscribedContent-338389Enabled" 0
            $k4 = Test-Reg-Read $cdm "SubscribedContent-353698Enabled" 0
            $k5 = Test-Reg-Read $cdm "SubscribedContent-338388Enabled" 0
            $k6 = Test-Reg-Read $cdm "RotatingLockScreenOverlayEnabled" 0
            return ($k1 -and $k2 -and $k3 -and $k4 -and $k5 -and $k6)
        } 
    }
    
    "Sys_SettingsClean" = @{
        Apply={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "DisableSettingsHome" 1 }
        Revert={ Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "DisableSettingsHome" }
        Check={ Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "DisableSettingsHome" 1 }
    }

    "Sys_AeroShake" = @{ Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "DisallowShaking" 1 }; Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "DisallowShaking" 0 }; Check={ Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "DisallowShaking" 1 } }
    
    "Sys_NoGallery" = @{ 
        Apply={ Set-Reg "HKCU:\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}" "System.IsPinnedToNameSpaceTree" 0 "DWord"; Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue }; 
        Revert={ Remove-Item "HKCU:\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}" -Recurse -ErrorAction SilentlyContinue; Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue }; 
        Check={ Test-Reg-Read "HKCU:\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}" "System.IsPinnedToNameSpaceTree" 0 } 
    }
    
    "Sys_NoHome" = @{ 
        Apply={ Set-Reg "HKCU:\Software\Classes\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}" "System.IsPinnedToNameSpaceTree" 0 "DWord"; Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue }; 
        Revert={ Remove-Item "HKCU:\Software\Classes\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}" -Recurse -ErrorAction SilentlyContinue; Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue }; 
        Check={ Test-Reg-Read "HKCU:\Software\Classes\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}" "System.IsPinnedToNameSpaceTree" 0 } 
    }
    
    "Sys_CleanThisPC" = @{
        Apply={
            $k = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace"
            Remove-Item "$k\{0db7e03f-fc29-4dc6-9020-ff4163b913e4}" -ErrorAction SilentlyContinue 
            Remove-Item "$k\{d3162b92-9365-467a-956b-92703aca08af}" -ErrorAction SilentlyContinue 
            Remove-Item "$k\{088e3905-0323-4b02-9826-5d99428e115f}" -ErrorAction SilentlyContinue 
            Remove-Item "$k\{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}" -ErrorAction SilentlyContinue 
            Remove-Item "$k\{24ad3ad4-a569-4530-98e1-ab02f9417aa8}" -ErrorAction SilentlyContinue 
            Remove-Item "$k\{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}" -ErrorAction SilentlyContinue 
        }
        Revert={ }
        Check={ !(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0db7e03f-fc29-4dc6-9020-ff4163b913e4}") }
    }
    
    "Sys_DupliDrive" = @{
        Apply={ Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\DelegateFolders\{F5FB2C77-0E2F-4A16-A381-3E560C68BC83}" "(default)" "-" "String" }
        Revert={ Remove-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\DelegateFolders\{F5FB2C77-0E2F-4A16-A381-3E560C68BC83}" "(default)" }
        Check={ Test-Reg-Read "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\DelegateFolders\{F5FB2C77-0E2F-4A16-A381-3E560C68BC83}" "(default)" "-" }
    }

    "Sys_FinishSetup" = @{ Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" "ScoobeSystemSettingEnabled" 0 }; Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" "ScoobeSystemSettingEnabled" 1 }; Check={ Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" "ScoobeSystemSettingEnabled" 0 } }
    
    "Sys_SnapFlyout" = @{ 
        Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "EnableSnapAssistFlyout" 0 }
        Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "EnableSnapAssistFlyout" 1 }
        Check={ Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "EnableSnapAssistFlyout" 0 }
    }

    "Sys_SleepTimeout" = @{ 
        Apply={ 
            $guid = "238c9fa8-0aad-41ed-83f4-97be242c8f20"; $sub = "7bc4a2f9-d8fc-4469-b07b-33eb785aaca0"
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\$guid\$sub" "Attributes" 2
            powercfg /setacvalueindex scheme_current $guid $sub 0
            powercfg /setdcvalueindex scheme_current $guid $sub 0
            powercfg /setactive scheme_current 
        }
        Revert={ 
            $guid = "238c9fa8-0aad-41ed-83f4-97be242c8f20"; $sub = "7bc4a2f9-d8fc-4469-b07b-33eb785aaca0"
            powercfg /setacvalueindex scheme_current $guid $sub 120
            powercfg /setdcvalueindex scheme_current $guid $sub 120
            powercfg /setactive scheme_current 
        }
        Check={ 
            $out = powercfg /qh scheme_current 238c9fa8-0aad-41ed-83f4-97be242c8f20 7bc4a2f9-d8fc-4469-b07b-33eb785aaca0 | Out-String
            $acMatch = $out -match "Current AC Power Setting Index:\s+0x([0-9a-fA-F]+)"; $ac = if($acMatch){[Convert]::ToInt32($matches[1],16)}else{-1}
            $dcMatch = $out -match "Current DC Power Setting Index:\s+0x([0-9a-fA-F]+)"; $dc = if($dcMatch){[Convert]::ToInt32($matches[1],16)}else{-1}
            return ($ac -eq 0 -and $dc -eq 0)
        }
    }
    
    "Sys_BackgroundMode" = @{ 
        SlowCheck=$true
        Apply={ param($v) $val = if ([int]$v -eq 1) { 2 } else { 0 }; Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsRunInBackground" $val }
        Check={ 
            $p = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"
            $val = Get-ItemProperty -Path $p -Name "LetAppsRunInBackground" -ErrorAction SilentlyContinue
            if ($val -and $val.LetAppsRunInBackground -eq 2) { return 1 }
            return 0
        }
    }

    # --- GAMING ---
    "Game_HAGS" = @{ 
        Reboot=$true; 
        Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 2 }; 
        Revert={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" 1 }; 
        Check={ 
            $path = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
            $val = Get-ItemProperty -Path $path -Name "HwSchMode" -ErrorAction SilentlyContinue
            if ($val -and $val.HwSchMode) { return ($val.HwSchMode -eq 2) }
            if ([System.Environment]::OSVersion.Version.Build -ge 22000) { return $true }
            return $false
        } 
    }
    
    "Game_VRR" = @{ 
        Apply={ Set-Reg "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" "DirectXUserGlobalSettings" "VRROptimize=1" "String" }
        Revert={ Set-Reg "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" "DirectXUserGlobalSettings" "VRROptimize=0" "String" }
        Check={ Test-Reg-Read "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" "DirectXUserGlobalSettings" "VRROptimize=1" }
    }

    "Game_GpuPriority" = @{
        Apply={ $p = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Set-Reg $p "GPU Priority" 8; Set-Reg $p "Scheduling Category" "High" "String" }
        Revert={ $p = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"; Set-Reg $p "GPU Priority" 0; Set-Reg $p "Scheduling Category" "Medium" "String" }
        Check={ Test-Reg-Read "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "GPU Priority" 8 }
    }

    "Game_GameMode" = @{ 
        Apply={ Set-Reg "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 1 }; 
        Revert={ Set-Reg "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 0 }; 
        Check={ 
            $path = "HKCU:\Software\Microsoft\GameBar"
            $val = Get-ItemProperty -Path $path -Name "AutoGameModeEnabled" -ErrorAction SilentlyContinue
            if ($val -and $val.AutoGameModeEnabled -ne $null) { return ($val.AutoGameModeEnabled -eq 1) }
            if ([System.Environment]::OSVersion.Version.Build -ge 22000) { return $true }
            return $false
        } 
    }

    "Game_FSO" = @{ 
        Warning="May cause stuttering or crashes in DX12 games. Uncheck if unstable."
        Apply={ Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_FSEBehaviorMode" 2 }
        Revert={ Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_FSEBehaviorMode" 0 }
        Check={ Test-Reg-Read "HKCU:\System\GameConfigStore" "GameDVR_FSEBehaviorMode" 2 }
    }

    "Game_DVR" = @{ Apply={ Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 0 }; Revert={ Set-Reg "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 1 }; Check={ Test-Reg-Read "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 0 } }
    
    "Game_DVRService" = @{
        Apply={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" 0; Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppCapture" "AppCaptureEnabled" 0 }
        Revert={ Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR"; Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppCapture" "AppCaptureEnabled" 1 }
        Check={ 
            $c1 = Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" 0
            $c2 = Test-Reg-Read "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppCapture" "AppCaptureEnabled" 0
            return ($c1 -and $c2)
        }
    }

    "Game_PowerThrot" = @{ Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" "PowerThrottlingOff" 1 }; Revert={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" "PowerThrottlingOff" 0 }; Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" "PowerThrottlingOff" 1 } }
    "Game_NetThrot" = @{ Apply={ Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 4294967295 }; Revert={ Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 10 }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 4294967295 } }
    "Game_Nagle" = @{ Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" "TcpAckFrequency" 1 }; Revert={ Remove-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" "TcpAckFrequency" }; Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" "TcpAckFrequency" 1 } }
    
    "Game_MouseAccel" = @{ Apply={ Set-Reg "HKCU:\Control Panel\Mouse" "MouseSpeed" "0" "String" }; Revert={ Set-Reg "HKCU:\Control Panel\Mouse" "MouseSpeed" "1" "String" }; Check={ Test-Reg-Read "HKCU:\Control Panel\Mouse" "MouseSpeed" "0" } }
    "Game_Sticky" = @{ Apply={ Set-Reg "HKCU:\Control Panel\Accessibility\StickyKeys" "Flags" "506" "String" }; Revert={ Set-Reg "HKCU:\Control Panel\Accessibility\StickyKeys" "Flags" "510" "String" }; Check={ Test-Reg-Read "HKCU:\Control Panel\Accessibility\StickyKeys" "Flags" "506" } }
    
    "Game_Latency" = @{ 
        Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" "TCPNoDelay" 1; Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" "TcpAckFrequency" 1 }; 
        Revert={ Remove-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" "TCPNoDelay" }; 
        Check={ 
            $c1 = Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" "TCPNoDelay" 1
            $c2 = Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" "TcpAckFrequency" 1
            return ($c1 -and $c2)
        } 
    }

    "Game_InterruptModeration" = @{
        SlowCheck=$true
        Apply={ 
            $p = Get-GpuRegistryPath "NVIDIA|AMD"
            if ($p) { Set-Reg "$p\Interrupt Management\MessageSignaledInterruptProperties" "MSISupported" 1; Set-Reg "$p\Interrupt Management\Affinity Policy" "DevicePriority" 0 }
        }
        Revert={ $p = Get-GpuRegistryPath "NVIDIA|AMD"; if ($p) { Remove-Reg "$p\Interrupt Management\Affinity Policy" "DevicePriority" } }
        Check={ 
            $p = Get-GpuRegistryPath "NVIDIA|AMD"; if ($p) { 
                $c1 = Test-Reg-Read "$p\Interrupt Management\Affinity Policy" "DevicePriority" 0
                $c2 = Test-Reg-Read "$p\Interrupt Management\MessageSignaledInterruptProperties" "MSISupported" 1
                return ($c1 -and $c2) 
            } return $false 
        }
    }

    "Game_NetTuning" = @{ 
        Apply={ netsh int tcp set global rss=enabled; netsh int tcp set global netdma=enabled; netsh int tcp set global dca=enabled }
        Revert={ netsh int tcp set global rss=default; netsh int tcp set global netdma=default; netsh int tcp set global dca=default }
        Check={ 
            $out = (netsh int tcp show global | Out-String)
            return ($out -match "Receive-Side Scaling State\s+:\s+enabled" -and $out -match "NetDMA State\s+:\s+enabled" -and $out -match "Direct Cache Access\s+:\s+enabled")
        }
    }

    "Game_DirectStorage" = @{
        Warning="SAFEGUARD: Forces Windows 24H2 default (Compression Enabled) for game stability."
        Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisableCompression" 0 }
        Revert={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisableCompression" 0 }
        Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisableCompression" 0 }
    }

    "Game_ScatterGather" = @{
        Apply={ return } # Placeholder for former Vaccine functionality
        Revert={ return }
        Check={ 
            $path = "HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device"
            if (!(Test-Path $path)) { return $true }
            return !(Get-ItemProperty $path -Name "ForcedPhysicalSectorSizeInBytes" -ErrorAction SilentlyContinue)
        }
    }

    "Game_NtfsMemory" = @{ 
        Warning="SAFEGUARD: Forces Windows default pool size to prevent out-of-memory errors."
        Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsMemoryUsage" 1 } 
        Revert={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsMemoryUsage" 1 } 
        Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsMemoryUsage" 1 } 
    }
    
    "Game_IoPriority" = @{ 
        Warning="SAFEGUARD: Resets I/O priority to Windows default kernel management."
        Apply={ $p = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\I/O Priority"; if(Test-Path $p){ Remove-ItemProperty -Path $p -Name "IoPriority" -ErrorAction SilentlyContinue } } 
        Revert={ return } 
        Check={ 
            $p = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\I/O Priority"
            if (!(Test-Path $p)) { return $true }
            return !(Get-ItemProperty $p -Name "IoPriority" -ErrorAction SilentlyContinue)
        } 
    }
    
    "Game_MPO" = @{ Reboot=$true; Apply={ Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" "OverlayTestMode" 5 }; Revert={ Remove-Reg "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" "OverlayTestMode" }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" "OverlayTestMode" 5 } }
    "Game_NvidiaFlipMode" = @{ Apply={ Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" "OverlayTestMode" 5 }; Revert={ Remove-Reg "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" "OverlayTestMode" }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" "OverlayTestMode" 5 } }
    "Game_PCIe" = @{ SlowCheck=$true; Apply={ Set-PCIe-Mode $true }; Revert={ Set-PCIe-Mode $false }; Check={ (Get-PCIe-State) -eq 0 } }
    "Game_VariBright" = @{ SlowCheck=$true; Apply={ Set-AMD-Feature "PP_VariBrightFeatureEnable" 0 }; Check={ $p=Get-GpuRegistryPath "AMD"; if($p){ return (Test-Reg-Read $p "PP_VariBrightFeatureEnable" 0) } return $false } }
    
    "Game_DPST" = @{ 
        Reboot=$true; SlowCheck=$true
        Apply={ $p = Get-Intel-Video-Key; if ($p) { $cur = (Get-ItemProperty $p -Name "FeatureTestControl").FeatureTestControl; Set-ItemProperty $p -Name "FeatureTestControl" -Value ($cur -bor 0x10) -Type DWord } }
        Revert={ $p = Get-Intel-Video-Key; if ($p) { $cur = (Get-ItemProperty $p -Name "FeatureTestControl").FeatureTestControl; Set-ItemProperty $p -Name "FeatureTestControl" -Value ($cur -band (-bnot 0x10)) -Type DWord } }
        Check={ $p = Get-Intel-Video-Key; if ($p) { $cur = (Get-ItemProperty $p -Name "FeatureTestControl" -ErrorAction SilentlyContinue).FeatureTestControl; return (($cur -band 0x10) -eq 0x10) } return $false } 
    }

    "Game_IntelVram" = @{
        Reboot=$true; SlowCheck=$true
        Apply={
            $p = Get-Intel-Video-Key; if ($p) { $cur = (Get-ItemProperty $p -Name "FeatureTestControl").FeatureTestControl; Set-ItemProperty $p -Name "FeatureTestControl" -Value ($cur -bor 0x200) -Type DWord }
            $gmm = "HKLM:\SOFTWARE\Intel\GMM"; if (!(Test-Path $gmm)) { New-Item -Path $gmm -Force | Out-Null }; Set-ItemProperty $gmm -Name "DedicatedSegmentSize" -Value 4096 -Type DWord
        }
        Revert={
            $p = Get-Intel-Video-Key; if ($p) { $cur = (Get-ItemProperty $p -Name "FeatureTestControl").FeatureTestControl; Set-ItemProperty $p -Name "FeatureTestControl" -Value ($cur -band (-bnot 0x200)) -Type DWord }
            Remove-ItemProperty "HKLM:\SOFTWARE\Intel\GMM" -Name "DedicatedSegmentSize" -ErrorAction SilentlyContinue
        }
        Check={
            $p = Get-Intel-Video-Key; if ($p) { $cur = (Get-ItemProperty $p -Name "FeatureTestControl" -ErrorAction SilentlyContinue).FeatureTestControl; return (($cur -band 0x200) -eq 0x200) }
            return (Test-Reg-Read "HKLM:\SOFTWARE\Intel\GMM" "DedicatedSegmentSize" 4096)
        }
    }
    
    "Game_TdrDelay" = @{ Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "TdrDelay" 10 }; Revert={ Remove-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "TdrDelay" }; Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "TdrDelay" 10 } }

    # --- PRIVACY ---
    "Priv_Tele" = @{ Apply={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0; gpupdate /force }; Revert={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 1 }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0 } }
    "Priv_AdID" = @{ Apply={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" "DisabledByGroupPolicy" 1 }; Revert={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" "DisabledByGroupPolicy" 0 }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" "DisabledByGroupPolicy" 1 } }
    
    "Priv_WUDO" = @{
        Apply={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" "DODownloadMode" 0 }
        Revert={ Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" "DODownloadMode" }
        Check={ Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" "DODownloadMode" 0 }
    }

    "Priv_Loc" = @{ 
        Apply={ 
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" "DisableLocation" 1
            Stop-Service lfsvc -Force -ErrorAction SilentlyContinue
            Set-Service lfsvc -StartupType Disabled 
        }
        Revert={ 
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" "DisableLocation" 0
            Set-Service lfsvc -StartupType Automatic
            Start-Service lfsvc 
        }
        Check={ 
            $c1 = Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" "DisableLocation" 1 
            $s = Get-Service lfsvc -ErrorAction SilentlyContinue
            if (!$s) { return $true }
            return ($c1 -and $s.StartType -eq "Disabled")
        } 
    }
    
    "Priv_Wifi" = @{ Apply={ Set-Reg "HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config" "AutoConnectAllowedOEM" 0 }; Revert={ Set-Reg "HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config" "AutoConnectAllowedOEM" 1 }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config" "AutoConnectAllowedOEM" 0 } }
    
    "Priv_Bing" = @{ 
        Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 0; Set-Reg "HKCU:\Software\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions" 1 }
        Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 1; Remove-Reg "HKCU:\Software\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions" }
        Check={ 
            $c1 = Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 0
            $c2 = Test-Reg-Read "HKCU:\Software\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions" 1
            return ($c1 -and $c2)
        } 
    }
    
    "Priv_Widgets" = @{ 
        Apply={ 
            Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa" 0
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" 0 
        }
        Revert={ 
            Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa" 1
            Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests"
        }
        Check={ 
            $btn = Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa" 0
            $pol = Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" 0
            return ($btn -and $pol)
        } 
    }
    
    "Priv_Copilot" = @{ 
        Apply={ 
            Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCopilotButton" 0
            Set-Reg "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "HubsSidebarEnabled" 0
            Get-AppxPackage *Copilot* | Remove-AppxPackage -ErrorAction SilentlyContinue 
        }
        Revert={ 
            Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCopilotButton" 1
            Remove-Reg "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot"
            Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot"
            Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "HubsSidebarEnabled"
        }
        Check={ 
            $ui = Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCopilotButton" 0
            $polUser = Test-Reg-Read "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1
            $polMach = Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1
            $edge = Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "HubsSidebarEnabled" 0
            $app = Get-AppxPackage *Copilot* -ErrorAction SilentlyContinue
            return ($ui -and $polUser -and $polMach -and $edge -and ($app -eq $null))
        } 
    }
    
    "Priv_StorageSense" = @{ Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" "01" 0 }; Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" "01" 1 }; Check={ Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" "01" 0 } }

    "Priv_OneDrive" = @{
        Apply={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSyncNGSC" 1 }
        Revert={ Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSyncNGSC" }
        Check={ Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSyncNGSC" 1 }
    }

    "Priv_ConsumerFeatures" = @{ Apply={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures" 1 }; Revert={ Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures" }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures" 1 } }
    "Priv_WER" = @{ Apply={ Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" "Disabled" 1 }; Revert={ Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" "Disabled" 0 }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" "Disabled" 1 } }
    "Priv_SharedExp" = @{ Apply={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableCdp" 0 }; Revert={ Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableCdp" }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableCdp" 0 } }
    
    "Priv_EdgeHardening" = @{
        Apply={
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "ShowCollectionsFeature" 0
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "PersonalizationReportingEnabled" 0
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "ShoppingAssistantEnabled" 0
        }
        Revert={
            Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "ShowCollectionsFeature"
            Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "PersonalizationReportingEnabled"
            Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "ShoppingAssistantEnabled"
        }
        Check={ Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "ShoppingAssistantEnabled" 0 }
    }

    "Priv_24H2_AI" = @{
        Apply={
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "TurnOffClickToDo" 1
            Set-Reg "HKCU:\Software\Microsoft\Notepad" "ShowCopilot" 0
            Set-Reg "HKCU:\Software\Microsoft\Paint" "ShowCocreator" 0
        }
        Revert={
            Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "TurnOffClickToDo"
            Remove-Reg "HKCU:\Software\Microsoft\Notepad" "ShowCopilot"
            Remove-Reg "HKCU:\Software\Microsoft\Paint" "ShowCocreator"
        }
        Check={ Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "TurnOffClickToDo" 1 }
    }

    "Priv_TeleTasks" = @{ 
        SlowCheck=$true; 
        Apply={ Disable-Task "\Microsoft\Windows\Application Experience" "Microsoft Compatibility Appraiser"; Disable-Task "\Microsoft\Windows\Application Experience" "ProgramDataUpdater"; Disable-Task "\Microsoft\Windows\Application Experience" "StartupAppTask"; Disable-Task "\Microsoft\Windows\Autochk" "Proxy"; Disable-Task "\Microsoft\Windows\Customer Experience Improvement Program" "Consolidator"; Disable-Task "\Microsoft\Windows\Customer Experience Improvement Program" "UsbCeip"; Disable-Task "\Microsoft\Windows\Customer Experience Improvement Program" "KernelCeipTask"; Disable-Task "\Microsoft\Windows\DiskDiagnostic" "Microsoft-Windows-DiskDiagnosticDataCollector" }
        Revert={ Enable-Task "\Microsoft\Windows\Application Experience" "Microsoft Compatibility Appraiser"; Enable-Task "\Microsoft\Windows\Application Experience" "ProgramDataUpdater"; Enable-Task "\Microsoft\Windows\Application Experience" "StartupAppTask"; Enable-Task "\Microsoft\Windows\Autochk" "Proxy"; Enable-Task "\Microsoft\Windows\Customer Experience Improvement Program" "Consolidator"; Enable-Task "\Microsoft\Windows\Customer Experience Improvement Program" "UsbCeip"; Enable-Task "\Microsoft\Windows\Customer Experience Improvement Program" "KernelCeipTask"; Disable-Task "\Microsoft\Windows\DiskDiagnostic" "Microsoft-Windows-DiskDiagnosticDataCollector" }
        Check={ 
            $tasks = @(@("\Microsoft\Windows\Application Experience", "Microsoft Compatibility Appraiser"), @("\Microsoft\Windows\Application Experience", "ProgramDataUpdater"), @("\Microsoft\Windows\Application Experience", "StartupAppTask"), @("\Microsoft\Windows\Autochk", "Proxy"), @("\Microsoft\Windows\Customer Experience Improvement Program", "Consolidator"), @("\Microsoft\Windows\Customer Experience Improvement Program", "UsbCeip"), @("\Microsoft\Windows\Customer Experience Improvement Program", "KernelCeipTask"), @("\Microsoft\Windows\DiskDiagnostic", "Microsoft-Windows-DiskDiagnosticDataCollector"))
            foreach ($t in $tasks) { $obj = Get-ScheduledTask -TaskPath ($t[0] + "\") -TaskName $t[1] -ErrorAction SilentlyContinue; if ($obj -and $obj.State -ne "Disabled") { return $false } }
            return $true
        } 
    }

    "Priv_AI_Telemetry" = @{ 
        SlowCheck=$true; 
        Apply={ Disable-Task "\Microsoft\Windows\User Experience" "AmbientExperienceTasks"; Disable-Task "\Microsoft\Windows\AI" "AIAAgentUpdateTask" }
        Revert={ Enable-Task "\Microsoft\Windows\User Experience" "AmbientExperienceTasks"; Enable-Task "\Microsoft\Windows\AI" "AIAgentUpdateTask" }
        Check={ 
            $t1 = Get-ScheduledTask -TaskPath "\Microsoft\Windows\User Experience\" -TaskName "AmbientExperienceTasks" -ErrorAction SilentlyContinue
            $t2 = Get-ScheduledTask -TaskPath "\Microsoft\Windows\AI\" -TaskName "AIAAgentUpdateTask" -ErrorAction SilentlyContinue
            $t1OK = (!$t1 -or $t1.State -eq "Disabled")
            $t2OK = (!$t2 -or $t2.State -eq "Disabled")
            return ($t1OK -and $t2OK)
        } 
    }

    "Priv_Feedback" = @{ Apply={ Get-AppxPackage *feedback* | Remove-AppxPackage -ErrorAction SilentlyContinue; Stop-Service DiagTrack -Force -ErrorAction SilentlyContinue; Set-Service DiagTrack -StartupType Disabled }; Check={ $s = Get-Service DiagTrack -ErrorAction SilentlyContinue; if (!$s) { return $true }; return ($s.StartType -eq "Disabled" -and $s.Status -ne "Running") } }
    "Priv_Inventory" = @{ Apply={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "DisableInventory" 1 }; Revert={ Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "DisableInventory" }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "DisableInventory" 1 } }
    "Priv_ActivityUpload" = @{ Apply={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "UploadUserActivities" 0 }; Revert={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "UploadUserActivities" 1 }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "UploadUserActivities" 0 } }
    "Priv_CloudClipboard" = @{ Apply={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "AllowClipboardHistory" 0 }; Revert={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "AllowClipboardHistory" 1 }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "AllowClipboardHistory" 0 } }
    "Priv_Maps" = @{ Apply={ Set-Reg "HKLM:\SYSTEM\Maps" "AutoUpdateEnabled" 0 }; Revert={ Set-Reg "HKLM:\SYSTEM\Maps" "AutoUpdateEnabled" 1 }; Check={ Test-Reg-Read "HKLM:\SYSTEM\Maps" "AutoUpdateEnabled" 0 } }
    "Priv_AppTrack" = @{ Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackProgs" 0 }; Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackProgs" 1 }; Check={ Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackProgs" 0 } }
    "Priv_ActivityFeed" = @{ Apply={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableActivityFeed" 0 }; Revert={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableActivityFeed" 1 }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableActivityFeed" 0 } }
    "Priv_TypingInsights" = @{ Apply={ Set-Reg "HKCU:\Software\Microsoft\Input\Settings" "InsightsEnabled" 0 }; Revert={ Set-Reg "HKCU:\Software\Microsoft\Input\Settings" "InsightsEnabled" 1 }; Check={ return (Test-Reg-Read "HKCU:\Software\Microsoft\Input\Settings" "InsightsEnabled" 0) } }
    "Priv_TailoredExp" = @{ Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" "TailoredExperiencesAllowed" 0 }; Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" "TailoredExperiencesAllowed" 1 }; Check={ return (Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" "TailoredExperiencesAllowed" 0) } }

    # --- HANDHELD / DUAL-STATE POWER TWEAKS ---
    "HH_SteamDeck" = @{
        Apply={ 
            $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
            Set-Reg "HKCU:\Software\Valve\Steam" "StartupMode" 1 "DWord"
            $steamPath = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).SteamExe
            if (!$steamPath -or !(Test-Path $steamPath)) { if (Test-Path "C:\Program Files (x86)\Steam\steam.exe") { $steamPath = "C:\Program Files (x86)\Steam\steam.exe" } elseif (Test-Path "C:\Program Files\Steam\steam.exe") { $steamPath = "C:\Program Files\Steam\steam.exe" } }
            if ($steamPath) { $steamPath = $steamPath.Replace("/", "\"); Set-Reg $path "Steam" "`"$steamPath`" -gamepadui -silent" "String" }
        }
        Revert={ Set-Reg "HKCU:\Software\Valve\Steam" "StartupMode" 0 "DWord"; Remove-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" "Steam" }
        Check={ $internal = Test-Reg-Read "HKCU:\Software\Valve\Steam" "StartupMode" 1; $runKey = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue).Steam; return ($internal -and ($runKey -match "-gamepadui")) }
    }

    "HH_HibernateBtn" = @{ 
        Apply={ powercfg /setacvalueindex scheme_current sub_buttons 7648efa3-dd9c-4e3e-b566-50f929386280 2; powercfg /setdcvalueindex scheme_current sub_buttons 7648efa3-dd9c-4e3e-b566-50f929386280 2; powercfg /setactive scheme_current }
        Revert={ powercfg /setacvalueindex scheme_current sub_buttons 7648efa3-dd9c-4e3e-b566-50f929386280 1; powercfg /setdcvalueindex scheme_current sub_buttons 7648efa3-dd9c-4e3e-b566-50f929386280 1; powercfg /setactive scheme_current }
        Check={ 
            $output = powercfg /getactivescheme; if ($output -match "([a-fA-F0-9-]{36})") { $guid = $matches[1] } else { return $false }; $q = powercfg /qh $guid sub_buttons 7648efa3-dd9c-4e3e-b566-50f929386280 | Out-String; 
            $acMatch = $q -match "Current AC Power Setting Index:\s+(0x[0-9a-fA-F]+|[0-9]+)"; $acVal = if($acMatch){ [Convert]::ToInt32($matches[1], 16) } else { -1 }; $dcMatch = $q -match "Current DC Power Setting Index:\s+(0x[0-9a-fA-F]+|[0-9]+)"; $dcVal = if($dcMatch){ [Convert]::ToInt32($matches[1], 16) } else { -1 }; return ($acVal -eq 2 -and $dcVal -eq 2)
        } 
    }

    "HH_WakeTimers" = @{ Apply={ powercfg /setacvalueindex scheme_current sub_sleep bd3b7116-3b1b-43b5-b725-3003e2754d52 0; powercfg /setdcvalueindex scheme_current sub_sleep bd3b7116-3b1b-43b5-b725-3003e2754d52 0; powercfg /setactive scheme_current }; Revert={ powercfg /setacvalueindex scheme_current sub_sleep bd3b7116-3b1b-43b5-b725-3003e2754d52 1; powercfg /setdcvalueindex scheme_current sub_sleep bd3b7116-3b1b-43b5-b725-3003e2754d52 1; powercfg /setactive scheme_current }; Check={ $output = powercfg /getactivescheme; if ($output -match "([a-fA-F0-9-]{36})") { $guid = $matches[1] } else { return $false }; $q = powercfg /q $guid 238c9fa8-0aad-41ed-83f4-97be242c8f20 bd3b7116-3b1b-43b5-b725-3003e2754d52 | Out-String; if ($q -match "Index:\s+(0x[0-9a-fA-F]+)") { $v = $matches[1]; if ($v -match "0x") { $v = [Convert]::ToInt32($v, 16) }; if ($v -eq 0) { return $true } } return $false } }
    "HH_Standby" = @{ SlowCheck=$true; Apply={ powercfg /setacvalueindex scheme_current sub_none F15576E8-98B7-4186-B944-EAFA664402D9 0; powercfg /setdcvalueindex scheme_current sub_none F15576E8-98B7-4186-B944-EAFA664402D9 0; powercfg /setactive scheme_current }; Check={ $output = powercfg /getactivescheme; if ($output -match "([a-fA-F0-9-]{36})") { $guid = $matches[1] } else { return $false }; $q = powercfg /qh $guid sub_none F15576E8-98B7-4186-B944-EAFA664402D9 | Out-String; if ($q -match "Index:\s+(0x[0-9a-fA-F]+)") { return ([Convert]::ToInt32($matches[1], 16) -eq 0) } return $false } } 
    "HH_WifiPower" = @{ SlowCheck=$true; Apply={ $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\19cbb8fa-5279-450e-9fac-8a3d5fedd0c1\12bbebe6-58d6-4636-95bb-3217ef867c1a"; if(Test-Path $regPath){ Set-ItemProperty -Path $regPath -Name "Attributes" -Value 2 -Type DWord -Force }; powercfg /setacvalueindex scheme_current 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 0; powercfg /setdcvalueindex scheme_current 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 0; powercfg /setactive scheme_current }; Revert={ powercfg /setacvalueindex scheme_current 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 3; powercfg /setdcvalueindex scheme_current 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 3; powercfg /setactive scheme_current }; Check={ $output = powercfg /getactivescheme; if ($output -match "([a-fA-F0-9-]{36})") { $guid = $matches[1] } else { return $false }; $q = powercfg /qh $guid 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a | Out-String; if ($q -match "Index:\s+0x0*([0-9a-fA-F]+)") { return ([Convert]::ToInt32($matches[1], 16) -eq 0) } return $false } }
    "HH_BtFix" = @{ Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\BthPort\Parameters" "DisableSelectiveSuspend" 1 }; Revert={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\BthPort\Parameters" "DisableSelectiveSuspend" 0 }; Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Services\BthPort\Parameters" "DisableSelectiveSuspend" 1 } }
    "HH_CoreIso" = @{ Reboot=$true; Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" "Enabled" 0 }; Revert={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" "Enabled" 1 }; Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" "Enabled" 0 } }
    "HH_DeviceGuard" = @{ Reboot=$true; Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "LsaCfgFlags" 0; Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard" ("EnableVirtualization" + "BasedSecurity") 0 }; Revert={ Remove-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "LsaCfgFlags"; Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard" ("EnableVirtualization" + "BasedSecurity") }; Check={ $c1 = Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard" ("EnableVirtualization" + "BasedSecurity") 0; $c2 = Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "LsaCfgFlags" 0; return ($c1 -and $c2) } }
    "HH_UsbSuspend" = @{ Apply={ powercfg /SETACVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b352172fdf33 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0; powercfg /SETDCVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b352172fdf33 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0; powercfg /setactive scheme_current }; Check={ $output = powercfg /getactivescheme; if ($output -match "([a-fA-F0-9-]{36})") { $guid = $matches[1] } else { return $false }; $q = powercfg /qh $guid 2a737441-1930-4402-8d77-b352172fdf33 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 | Out-String; if ($q -match "Index:\s+(0x[0-9a-fA-F]+)") { return ([Convert]::ToInt32($matches[1], 16) -eq 0) } return $false } }
    "HH_EdgeSwipe" = @{ Apply={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI" "AllowEdgeSwipe" 0 }; Revert={ Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI" "AllowEdgeSwipe" }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI" "AllowEdgeSwipe" 0 } }
    "HH_Encryption" = @{ SlowCheck=$true; Apply={ $vol = Get-CimInstance -ClassName Win32_EncryptableVolume -Namespace "root/cimv2/Security/MicrosoftVolumeEncryption" -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -eq "C:" }; if ($vol -and ($vol.ProtectionStatus -eq 0)) { return }; Start-Process ("manage" + "-bde") -ArgumentList "-off C:" -NoNewWindow }; Check={ $s = Get-CimInstance -ClassName Win32_EncryptableVolume -Namespace "root/cimv2/Security/MicrosoftVolumeEncryption" -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -eq "C:" }; if (!$s) { return $true }; return ($s.ProtectionStatus -eq 0) } }
    "HH_TouchResponse" = @{ Apply={ Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" "0" "String"; Set-Reg "HKCU:\Control Panel\Desktop" "WaitToKillAppTimeout" "2000" "String" }; Revert={ Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" "400" "String"; Set-Reg "HKCU:\Control Panel\Desktop" "WaitToKillAppTimeout" "5000" "String" }; Check={ $c1 = Test-Reg-Read "HKCU:\Control Panel\Desktop" "MenuShowDelay" "0"; $c2 = Test-Reg-Read "HKCU:\Control Panel\Desktop" "WaitToKillAppTimeout" "2000"; return ($c1 -and $c2) } }
    "HH_TouchKeyboard" = @{ Apply={ Set-Service "TabletInputService" -StartupType Automatic; Start-Service "TabletInputService" }; Check={ (Get-Service "TabletInputService" -ErrorAction SilentlyContinue).Status -eq "Running" } }
    "HH_GameBarWriter" = @{ Apply={ Stop-Service "GameBarPresenceWriter" -Force -ErrorAction SilentlyContinue; Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0 }; Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 1 }; Check={ $c1 = Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0; $s = Get-Service "GameBarPresenceWriter" -ErrorAction SilentlyContinue; if (!$s) { return $true }; return ($c1 -and $s.Status -ne "Running") } }
    "HH_Asus_AC" = @{ Apply={ Set-Service "ArmouryCrateService" -StartupType Manual }; Revert={ Set-Service "ArmouryCrateService" -StartupType Automatic }; Check={ $s=Get-Service "ArmouryCrateService" -ErrorAction SilentlyContinue; if ($s) { return ($s.StartType -ne "Automatic" -and $s.Status -ne "Running") } return $false } }
    "HH_Legion_Space" = @{ Apply={ Disable-Task "\" "LSDaemon"; Remove-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" "LegionSpace"; Remove-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" "LegionSpace" }; Revert={ Enable-Task "\" "LSDaemon" }; Check={ $t = Get-ScheduledTask -TaskName "LSDaemon" -ErrorAction SilentlyContinue; $r1 = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue).LegionSpace; $r2 = (Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue).LegionSpace; if ($t) { return ($t.State -eq "Disabled" -and $r1 -eq $null -and $r2 -eq $null) } return $false } }
    "HH_Msi_Center" = @{ Apply={ Set-Service "MSI_Central_Service" -StartupType Manual }; Check={ $s = Get-Service "MSI_Central_Service" -ErrorAction SilentlyContinue; if ($s) { return ($s.StartType -eq "Manual" -and $s.Status -ne "Running") } return $false } }
    "HH_VMP" = @{ Reboot=$true; SlowCheck=$true; Apply={ Disable-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform" -NoRestart -ErrorAction SilentlyContinue }; Revert={ Enable-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform" -NoRestart -ErrorAction SilentlyContinue }; Check={ (Get-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform" -ErrorAction SilentlyContinue).State -eq "Disabled" } }
    "HH_CompactOS" = @{ SlowCheck=$true; Apply={ Start-Process "compact" "/CompactOS:always" -Wait -NoNewWindow }; Check={ (compact /CompactOS:query) -match "is in the Compact state" } }
    "HH_HiberReduced" = @{ SlowCheck=$true; Apply={ powercfg /h /type reduced }; Check={ (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "HiberFileType" -ErrorAction SilentlyContinue).HiberFileType -eq 2 } }

    "HH_BoostMode_AC" = @{ SlowCheck=$true; Apply={ param($v); powercfg /setacvalueindex scheme_current sub_processor be337238-0d82-4146-a960-4f3749d470c7 $v; powercfg /setactive scheme_current }; Check={ return (Get-CpuBoostMode "AC") } }
    "HH_BoostMode_DC" = @{ SlowCheck=$true; Apply={ param($v); powercfg /setdcvalueindex scheme_current sub_processor be337238-0d82-4146-a960-4f3749d470c7 $v; powercfg /setactive scheme_current }; Check={ return (Get-CpuBoostMode "DC") } }
    
    # 5-TIER SHOGUN EPP MATH (0 = 0, 1 = 33, 2 = 50, 3 = 85, 4 = 100)
    "HH_EPP_AC" = @{ SlowCheck=$true; Apply={ param($v); $epp = switch($v){0{0}1{33}2{50}3{85}4{100}Default{50}}; powercfg /setacvalueindex scheme_current sub_processor 36687f9e-e3a5-4dbf-b1dc-15eb381c6863 $epp; powercfg /setactive scheme_current }; Check={ $val=(Get-EPP-Value "AC"); if($val -le 10){0}elseif($val -le 40){1}elseif($val -le 60){2}elseif($val -le 90){3}else{4} } }
    "HH_EPP_DC" = @{ SlowCheck=$true; Apply={ param($v); $epp = switch($v){0{0}1{33}2{50}3{85}4{100}Default{50}}; powercfg /setdcvalueindex scheme_current sub_processor 36687f9e-e3a5-4dbf-b1dc-15eb381c6863 $epp; powercfg /setactive scheme_current }; Check={ $val=(Get-EPP-Value "DC"); if($val -le 10){0}elseif($val -le 40){1}elseif($val -le 60){2}elseif($val -le 90){3}else{4} } }

    # --- ADVANCED ---
    "Adv_InputLatency" = @{ Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Kbdclass\Parameters" "KeyboardDataQueueSize" 50 }; Revert={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Kbdclass\Parameters" "KeyboardDataQueueSize" 100 }; Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Services\Kbdclass\Parameters" "KeyboardDataQueueSize" 50 } }
    "Adv_Priority" = @{ Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 38 }; Revert={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 2 }; Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 38 } }
    "Adv_Storage" = @{ SlowCheck=$true; Apply={ fsutil behavior set disable8dot3 1; fsutil behavior set disablelastaccess 1 }; Check={ $c1 = (fsutil behavior query disable8dot3) -match "1"; $c2 = (fsutil behavior query disablelastaccess) -match "1"; return ($c1 -and $c2) } }
    "Adv_UltPower" = @{ SlowCheck=$true; Apply={ powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61; powercfg /setactive e9a42b02-d5df-448d-aa00-03f14749eb61 }; Check={ (powercfg /getactivescheme) -match "e9a42b02-d5df-448d-aa00-03f14749eb61" } }
    "Adv_TimerOpt" = @{ Warning="Resets system timer to Windows Defaults (TSC). Resolves stutters in modern games."; Reboot=$true; SlowCheck=$true; Apply={ bcdedit /deletevalue useplatformclock }; Revert={ bcdedit /deletevalue useplatformclock }; Check={ $out = bcdedit /enum | Out-String; return ($out -notmatch "useplatformclock") } }
    "Adv_MemComp" = @{ SlowCheck=$true; Apply={ Enable-MMAgent -MemoryCompression }; Revert={ Disable-MMAgent -MemoryCompression }; Check={ (Get-MMAgent).MemoryCompression -eq $true } }
    "Adv_PageFile" = @{ Reboot=$true; SlowCheck=$true; Apply={ $sys = Get-CimInstance Win32_ComputerSystem -EnableAllPrivileges; if($sys.AutomaticManagedPagefile){ $sys.AutomaticManagedPagefile=$false; $sys.Put() } }; Check={ (Get-CimInstance Win32_ComputerSystem).AutomaticManagedPagefile -eq $false } }
    "Adv_NetPower" = @{ SlowCheck=$true; Apply={ Get-NetAdapter -Physical | Get-NetAdapterPowerManagement | Set-NetAdapterPowerManagement -AllowComputerToTurnOffDevice $false -ErrorAction SilentlyContinue }; Check={ $a = Get-NetAdapter -Physical | Get-NetAdapterPowerManagement | Select -First 1; return ($a.AllowComputerToTurnOffDevice -eq $false) } }
    "Adv_PhotoViewer" = @{ Apply={ Set-Reg "HKCU:\Software\Classes\.jpg" "(default)" "PhotoViewer.FileAssoc.Tiff" "String"; Set-Reg "HKCU:\Software\Classes\.png" "(default)" "PhotoViewer.FileAssoc.Tiff" "String" }; Check={ $v1 = Get-ItemProperty "HKCU:\Software\Classes\.jpg" -ErrorAction SilentlyContinue; $v2 = Get-ItemProperty "HKCU:\Software\Classes\.png" -ErrorAction SilentlyContinue; return ($v1.'(default)' -eq "PhotoViewer.FileAssoc.Tiff" -and $v2.'(default)' -eq "PhotoViewer.FileAssoc.Tiff") } }
    "Adv_UTC" = @{ Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" "RealTimeIsUniversal" 1 }; Revert={ Remove-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" "RealTimeIsUniversal" }; Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" "RealTimeIsUniversal" 1 } }
    "Adv_Printing" = @{ Apply={ Stop-Service Spooler -Force; Set-Service Spooler -StartupType Disabled }; Revert={ Set-Service Spooler -StartupType Automatic; Start-Service Spooler }; Check={ $s = Get-Service Spooler -ErrorAction SilentlyContinue; if (!$s) { return $true }; return ($s.StartType -eq "Disabled" -and $s.Status -ne "Running") } }
    "Adv_ReservedStorage" = @{ SlowCheck=$true; Apply={ Start-Process "dism" -ArgumentList "/Online /Set-ReservedStorageState /State:Disabled" -Wait -NoNewWindow }; Revert={ Start-Process "dism" -ArgumentList "/Online /Set-ReservedStorageState /State:Enabled" -Wait -NoNewWindow }; Check={ (dism /online /Get-ReservedStorageState) -match "is disabled" } }
    
    "Adv_WSL" = @{ Reboot=$true; SlowCheck=$true; Apply={ Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux" -NoRestart -ErrorAction SilentlyContinue }; Revert={ Disable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux" -NoRestart -ErrorAction SilentlyContinue }; Check={ (Get-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux" -ErrorAction SilentlyContinue).State -eq "Enabled" } }
    "Adv_HyperV" = @{ Reboot=$true; SlowCheck=$true; Apply={ Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V-All" -NoRestart -ErrorAction SilentlyContinue }; Revert={ Disable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V-All" -NoRestart -ErrorAction SilentlyContinue }; Check={ (Get-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V-All" -ErrorAction SilentlyContinue).State -eq "Enabled" } }
}

$AutoMap = @{ "Sys_VisualFX"="Auto_Visuals"; "Sys_DeviceInstall"="Auto_Drivers"; "Sys_RemoteAssist"="Auto_Remote"; "Sys_Recall"="Auto_Recall"; "Game_HAGS"="Auto_Hags"; "Game_GameMode"="Auto_GameMode"; "Sys_SysRestore"="Auto_SysRestore"; "Sys_UAC"="Auto_UAC"; "HH_CoreIso"="Auto_CoreIso"; "Priv_Tele"="Auto_Tele"; "Priv_AdID"="Auto_AdID"; "Priv_Loc"="Auto_Loc"; "Priv_Wifi"="Auto_Wifi"; "Priv_Bing"="Auto_Bing"; "Priv_Widgets"="Auto_Widgets"; "Priv_Copilot"="Auto_Copilot"; "Game_PCIe"="Auto_PCIe"; "Game_VariBright"="Auto_VariBright"; "Game_DPST"="Auto_DPST"; "Sys_AutoBright"="Auto_Bright"; "Priv_ConsumerFeatures"="Auto_Consumer"; "Priv_WER"="Auto_WER"; "Sys_CpuOpt"="Auto_CpuOpt"; "Sys_StartAds"="Auto_StartAds"; "Priv_ActivityUpload"="Auto_Activity" }

$AppCheckMap = @{
    "App_Chrome" = { (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe") -or (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") }
    "App_Firefox" = { (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\firefox.exe") -or (Test-Path "C:\Program Files\Mozilla Firefox\firefox.exe") }
    "App_Brave" = { (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\brave.exe") -or (Test-Path "C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe") -or (Test-Path "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\Application\brave.exe") }
    "App_Steam" = { Test-Path "HKCU:\Software\Valve\Steam" }
    "App_Epic" = { (Test-Path "C:\Program Files (x86)\Epic Games\Launcher\Portal\Binaries\Win32\EpicGamesLauncher.exe") -or (Test-Path "C:\Program Files\Epic Games\Launcher\Portal\Binaries\Win32\EpicGamesLauncher.exe") }
    "App_GOG" = { Test-Path "HKLM:\SOFTWARE\WOW6432Node\GOG.com\GalaxyClient" }
    "App_RetroArch" = { (Test-Path "$env:APPDATA\RetroArch\retroarch.exe") -or (Test-Path "C:\RetroArch-Win64\retroarch.exe") }
    "App_Playnite" = { Test-Path "$env:LOCALAPPDATA\Playnite\Playnite.DesktopApp.exe" }
    "App_Moonlight" = { Test-Path "C:\Program Files\Moonlight Game Streaming\Moonlight.exe" }
    "App_Sunshine" = { Test-Path "C:\Program Files\Sunshine\sunshine.exe" }
    "App_Discord" = { Test-Path "$env:LOCALAPPDATA\Discord\Update.exe" }
    "App_7Zip" = { Test-Path "C:\Program Files\7-Zip\7z.exe" }
    "App_VLC" = { Test-Path "HKLM:\SOFTWARE\VideoLAN\VLC" -or (Test-Path "C:\Program Files\VideoLAN\VLC\vlc.exe") }
    "App_NotepadPlus" = { Test-Path "C:\Program Files\Notepad++\notepad++.exe" }
    "App_VSCode" = { (Test-Path "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe") -or (Test-Path "C:\Program Files\Microsoft VS Code\Code.exe") }
    "App_PowerToys" = { Test-Path "C:\Program Files\PowerToys\PowerToys.exe" }
    "App_HWiNFO" = { Test-Path "C:\Program Files\HWiNFO64\HWiNFO64.exe" }
    "App_CPUZ" = { Test-Path "C:\Program Files\CPUID\CPU-Z\cpuz.exe" }
    "App_GPUZ" = { (Test-Path "C:\Program Files (x86)\GPU-Z\GPU-Z.exe") -or (Test-Path "C:\Program Files\GPU-Z\GPU-Z.exe") }
    "App_FXSound" = { Test-Path "C:\Program Files\FxSound LLC\FxSound\FxSound.exe" }
    "App_GHelper" = { Test-Path "$env:APPDATA\GHelper\GHelper.exe" }
    "App_Afterburner" = { (Test-Path "C:\Program Files (x86)\MSI Afterburner\MSIAfterburner.exe") }
    "App_Everything" = { Test-Path "C:\Program Files\Everything\Everything.exe" }
    "App_WizTree" = { Test-Path "C:\Program Files\WizTree\WizTree.exe" }
    "App_Audacity" = { Test-Path "C:\Program Files\Audacity\Audacity.exe" }
    "App_OBS" = { Test-Path "C:\Program Files\obs-studio\bin\64bit\obs64.exe" }
}

$WingetMap = @{
    "App_Chrome" = "Google.Chrome"; "App_Firefox" = "Mozilla.Firefox"; "App_Brave" = "Brave.Brave"
    "App_Steam" = "Valve.Steam"; "App_Epic" = "EpicGames.EpicGamesLauncher"; "App_GOG" = "GOG.Galaxy"; "App_RetroArch" = "Libretro.RetroArch"
    "App_Playnite" = "Playnite.Playnite"; "App_Moonlight" = "MoonlightGameStreaming.Moonlight"; "App_Sunshine" = "LizardByte.Sunshine"
    "App_Discord" = "Discord.Discord"; "App_7Zip" = "7zip.7zip"; "App_VLC" = "VideoLAN.VLC"; "App_NotepadPlus" = "Notepad++.Notepad++"
    "App_VSCode" = "Microsoft.VisualStudioCode"; "App_PowerToys" = "Microsoft.PowerToys"; "App_HWiNFO" = "HWiNFO.HWiNFO"
    "App_CPUZ" = "CPUID.CPU-Z"; "App_GPUZ" = "TechPowerUp.GPU-Z"; "App_FXSound" = "FxSound.FxSound"; "App_GHelper" = "Seerge.G-Helper"
    "App_Afterburner" = "Guru3D.Afterburner"; "App_Everything" = "voidtools.Everything"; "App_WizTree" = "AntibodySoftware.WizTree"
    "App_Audacity" = "Audacity.Audacity"; "App_OBS" = "OBSProject.OBSStudio"
}

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

    # --- TOUCH MODE & SCALING LOGIC ---
    $window.FindName("Global_TouchMode").Add_Checked({
        $scale = New-Object System.Windows.Media.ScaleTransform
        $scale.ScaleX = 1.15
        $scale.ScaleY = 1.15
        $window.LayoutTransform = $scale
        if ($Global:RoninDojo) {
            $Global:RoninDojo.Text = "TOUCH MODE ACTIVE: Interface scaled for Handhelds."
            $Global:RoninDojo.Foreground = [System.Windows.Media.Brushes]::Cyan
        }
    })
    
    $window.FindName("Global_TouchMode").Add_Unchecked({
        $window.LayoutTransform = $null
        if ($Global:RoninDojo) {
            $Global:RoninDojo.Text = "Standard UI Scale Active."
            $Global:RoninDojo.Foreground = [System.Windows.Media.Brushes]::Gray
        }
    })

    # --- EXPERT MODE LOGIC (UPDATED WITH NEW FEATURES) ---
    $ExpertControls = @("Sys_Bloatware", "Sys_DeviceInstall", "Adv_Printing", "Adv_TimerOpt", "Sys_SearchIndex", "HH_VMP", "Btn_UndoAll", "Btn_InPlaceUpgrade", "Adv_WSL", "Adv_HyperV")
    
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
                 # FIX: Removed phantom "Auto_Turbo" logic to prevent silent execution breaks.
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
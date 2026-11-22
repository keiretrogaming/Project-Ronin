<#
.SYNOPSIS
    Project Ronin Tweak Database v8.0.0 - Declarative registry/service tweak definitions.

.DESCRIPTION
    Hashtable of all available system tweaks. Each entry has Apply, Revert, and Check
    scriptblocks. The same registry paths and values used here are documented at
    elevenforum.com and other reputable Windows administration sources, and mirror
    the operations performed by Microsoft's own Group Policy templates.

.NOTES
    Project: https://github.com/keiretrogaming/Project-Ronin
    License: MIT
#>

# --- PROJECT RONIN: TWEAK DATABASE v8.0.0 (SHOGUN EDITION) ---

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
    # 8.0: Explorer=$true on every tweak whose change Explorer/Start/the taskbar only reads at start-up (classic
    # context menu, blocked shell extensions, taskbar layout, clock seconds...). Without it those tweaks applied
    # but showed no change until the next sign-in, which read as 'didn't work'. The engine restarts Explorer
    # ONCE per batch (or shows the banner when Settings > Explorer restart is 'ask').
    # 8.0: VisualFXSetting only records which Performance Options radio button is selected - writing it alone
    # changed no effect at all, so this tweak (pre-ticked in Auto Optimize) did nothing. The effects live in
    # these values; the set matches WinUtil's widely used "performance visuals" (UserPreferencesMask =
    # Windows' own best-performance mask). Font smoothing and thumbnails are left alone ("Custom", 3).
    # Spec: every original recorded and restored exactly (incl. the binary mask). Full effect after sign-in.
    "Sys_VisualFX" = @{ Explorer=$true
        Spec=@(
            @{ P="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"; N="VisualFXSetting"; V=3; D=0 }
            @{ P="HKCU:\Control Panel\Desktop"; N="UserPreferencesMask"; V=([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)); T="Binary"; D=([byte[]](0x9E,0x1E,0x07,0x80,0x12,0x00,0x00,0x00)) }   # D = Windows' default mask (never delete this value)
            @{ P="HKCU:\Control Panel\Desktop"; N="DragFullWindows"; V="0"; T="String"; D="1" }
            @{ P="HKCU:\Control Panel\Desktop\WindowMetrics"; N="MinAnimate"; V="0"; T="String"; D="1" }
            @{ P="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; N="ListviewAlphaSelect"; V=0; D=1 }
            @{ P="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; N="ListviewShadow"; V=0; D=1 }
            @{ P="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; N="TaskbarAnimations"; V=0; D=1 }
            @{ P="HKCU:\Software\Microsoft\Windows\DWM"; N="EnableAeroPeek"; V=0; D=1 }
        )
        Apply={ Invoke-SpecApply 'Sys_VisualFX' }; Revert={ Invoke-SpecRevert 'Sys_VisualFX' }; Check={ Test-Spec 'Sys_VisualFX' }
    }
    "Sys_Transparency" = @{ UserState=$true; 
        Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 0 }
        Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 1 }
        Check={ Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 0 }
    }
    "Sys_DarkTheme" = @{ UserState=$true;
        Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme" 0; Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "SystemUsesLightTheme" 0 }
        Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme" 1; Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "SystemUsesLightTheme" 1 }
        Check={ $a = Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme" 0; $b = Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" "SystemUsesLightTheme" 0; return ($a -and $b) }
    }
    "Sys_ContextMenu" = @{ Explorer=$true; Apply={ Set-Reg "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" "(default)" "" "String" }; Revert={ Remove-Item "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" -Recurse -ErrorAction SilentlyContinue }; Check={ Test-Path "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" } }
    
    "Sys_ContextMenuClean" = @{ Explorer=$true;
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

    "Sys_Hibernation" = @{ UserState=$true; 
        SlowCheck=$true
        Apply={ powercfg /h off }
        Revert={ powercfg /h on }
        Check={ 
            $reg = Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "HibernateEnabled" 0 
            $file = Test-Path "$env:SystemDrive\hiberfil.sys"
            return ($reg -and -not $file)
        }
    }

    "Sys_FastBoot" = @{ UserState=$true; Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 0 }; Revert={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 1 }; Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" "HiberbootEnabled" 0 } }
    
    "Sys_SysRestore" = @{ UserState=$true; 
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
    
    "Sys_TaskbarAlign" = @{ Explorer=$true; UserState=$true; Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAl" 0 }; Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAl" 1 }; Check={ Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAl" 0 } }
    "Sys_TaskbarCombine" = @{ Explorer=$true; UserState=$true; Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarGlomLevel" 2 }; Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarGlomLevel" 0 }; Check={ Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarGlomLevel" 2 } }
    "Sys_EndTask" = @{ Explorer=$true; UserState=$true; Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarEndTask" 1 }; Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarEndTask" 0 }; Check={ Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarEndTask" 1 } }
    
    "Sys_TaskbarClean" = @{ Explorer=$true;
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

    "Sys_MeetNow" = @{ Explorer=$true; Apply={ Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "HideSCAMeetNow" 1 }; Revert={ Remove-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "HideSCAMeetNow" }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "HideSCAMeetNow" 1 } }

    "Sys_ExplorerOpen" = @{ UserState=$true; Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "LaunchTo" 1 }; Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "LaunchTo" 2 }; Check={ Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "LaunchTo" 1 } }
    "Sys_ShowExt" = @{ UserState=$true; Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 0 }; Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 1 }; Check={ Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 0 } }
    "Sys_ShowHidden" = @{ UserState=$true; Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 1 }; Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 2 }; Check={ Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 1 } }
    "Sys_Seconds" = @{ Explorer=$true; UserState=$true; Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSecondsInSystemClock" 1 }; Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSecondsInSystemClock" 0 }; Check={ Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSecondsInSystemClock" 1 } }
    
    "Sys_LockScreen" = @{ UserState=$true; Apply={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" "NoLockScreen" 1 }; Revert={ Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" "NoLockScreen" }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" "NoLockScreen" 1 } }
    
    "Sys_UAC" = @{ UserState=$true; Apply={ Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "ConsentPromptBehaviorAdmin" 0 }; Revert={ Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "ConsentPromptBehaviorAdmin" 5 }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "ConsentPromptBehaviorAdmin" 0 } }
    
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
    
    "Sys_Recall" = @{ 
        Apply={ 
            # Disable Recall via three reinforcing policy keys (24H2 + 25H2 coverage)
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" 1
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "AllowRecallEnablement" 0
            Set-Reg "HKCU:\Software\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" 1
        }
        Revert={ 
            Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis"
            Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "AllowRecallEnablement"
            Remove-Reg "HKCU:\Software\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis"
        }
        Check={ 
            $c1 = Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" 1
            $c2 = Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "AllowRecallEnablement" 0
            return ($c1 -and $c2)
        } 
    }
    
    # 8.0: Revert set plain "Automatic"; Windows ships Windows Search as Automatic (Delayed Start).
    # The startup type is now recorded at Apply and restored exactly - via sc.exe, because
    # Set-Service on PowerShell 5.1 has no "delayed" option.
    "Sys_SearchIndex" = @{ UserState=$true;
        Apply={
            $svc = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\WSearch" -ErrorAction SilentlyContinue
            $orig = if ($svc -and "$($svc.Start)" -eq "2") { if ("$($svc.DelayedAutostart)" -eq "1") { "delayed-auto" } else { "auto" } } elseif ($svc -and "$($svc.Start)" -eq "3") { "demand" } else { $null }
            if ($orig) { Save-OriginalState "Sys_SearchIndex.Start" $orig }
            Stop-Service WSearch -Force -ErrorAction SilentlyContinue; Set-Service WSearch -StartupType Disabled
        }
        Revert={
            $orig = Get-OriginalState "Sys_SearchIndex.Start"
            if ($orig -notin @("delayed-auto", "auto", "demand")) { $orig = "delayed-auto" }
            & sc.exe config WSearch start= $orig | Out-Null
            if ($orig -ne "demand") { Start-Service WSearch -ErrorAction SilentlyContinue }
            Clear-OriginalState "Sys_SearchIndex.Start"
        }
        Check={ 
            $s = Get-Service WSearch -ErrorAction SilentlyContinue
            if (!$s) { return $true }
            return ($s.StartType -eq "Disabled" -and $s.Status -ne "Running")
        } 
    }

    "Sys_RemoteAssist" = @{ Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" "fAllowToGetHelp" 0 }; Revert={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" "fAllowToGetHelp" 1 }; Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" "fAllowToGetHelp" 0 } }
    
    "Sys_AutoBright" = @{
        SlowCheck=$true
        Apply={ # Record this machine's original value BEFORE changing it (restored exactly on Revert).
            Save-PowerOriginal "Sys_AutoBright" 7516b95f-f776-4464-8c53-06167f40cc99 FBD9AA66-9553-4097-BA44-ED6E9D65EAB8;
            
            powercfg /setacvalueindex scheme_current 7516b95f-f776-4464-8c53-06167f40cc99 FBD9AA66-9553-4097-BA44-ED6E9D65EAB8 0
            powercfg /setdcvalueindex scheme_current 7516b95f-f776-4464-8c53-06167f40cc99 FBD9AA66-9553-4097-BA44-ED6E9D65EAB8 0
            powercfg /setactive scheme_current 
        }
        Revert={ Restore-PowerOriginal "Sys_AutoBright" 7516b95f-f776-4464-8c53-06167f40cc99 FBD9AA66-9553-4097-BA44-ED6E9D65EAB8 1 1 'Both' }
        # 8.0: Get-PowerIndex reads the hex tokens, not the English "Current AC Power Setting Index"
        # text, so this Check works in every display language (AC only, as before).
        Check={ $v = Get-PowerIndex 7516b95f-f776-4464-8c53-06167f40cc99 FBD9AA66-9553-4097-BA44-ED6E9D65EAB8; return ($null -ne $v -and $v.AC -eq 0) }
    }
    
    # NOTE: the old all-or-nothing "Sys_Bloatware" tweak was replaced in 7.4 by the
    # Debloat Center (Btn_Debloat -> DEBLOAT_SCAN/DEBLOAT_REMOVE in RoninCore.ps1),
    # which scans installed apps and lets the user select exactly what to remove.

    "Sys_MenuDelay" = @{ Shares="HH_TouchResponse"; Apply={ Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" "0" "String" }; Revert={ Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" "400" "String" }; Check={ Test-Reg-Read "HKCU:\Control Panel\Desktop" "MenuShowDelay" "0" } }
    # 8.0: Check tested only that "link" was 4 bytes long, so ANY 4-byte value there (Explorer keeps
    # its own data in it) read as ON without the tweak being applied. It now checks the zeros Apply
    # writes, and Revert puts back the value that was there (removing it only if there was none).
    "Sys_Shortcuts" = @{
        Apply={ Save-RegOriginal "Sys_Shortcuts.Link" "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" "link"; Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" "link" ([byte[]](0,0,0,0)) "Binary" }
        Revert={ if (-not (Restore-RegOriginal "Sys_Shortcuts.Link" "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" "link")) { Remove-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" "link" } }
        Check={ $v = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -Name "link" -ErrorAction SilentlyContinue; return [bool]($v -and $v.link -and (@($v.link) -join ',') -eq '0,0,0,0') } }
    
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
        Apply={ # Record this machine's original value BEFORE changing it (restored exactly on Revert).
            Save-PowerOriginal "Sys_CpuOpt.Min" sub_processor 893dee8e-2bef-41e0-89c6-b55d0929964c; Save-PowerOriginal "Sys_CpuOpt.Max" sub_processor bc5038f7-23e0-4960-96da-33abaf5935ec;
            
            # Set min processor to 0% (deeper idle states, more efficient than Balanced default of 5%)
            powercfg /setacvalueindex scheme_current sub_processor 893dee8e-2bef-41e0-89c6-b55d0929964c 0
            powercfg /setdcvalueindex scheme_current sub_processor 893dee8e-2bef-41e0-89c6-b55d0929964c 0
            powercfg /setacvalueindex scheme_current sub_processor bc5038f7-23e0-4960-96da-33abaf5935ec 100
            powercfg /setdcvalueindex scheme_current sub_processor bc5038f7-23e0-4960-96da-33abaf5935ec 100
            powercfg /setactive scheme_current 
        }
        Revert={ Restore-PowerOriginal "Sys_CpuOpt.Min" sub_processor 893dee8e-2bef-41e0-89c6-b55d0929964c 5 5 'Both'; Restore-PowerOriginal "Sys_CpuOpt.Max" sub_processor bc5038f7-23e0-4960-96da-33abaf5935ec 100 100 'Both' }
        Check={
            $mn = Get-PowerIndex sub_processor 893dee8e-2bef-41e0-89c6-b55d0929964c
            $mx = Get-PowerIndex sub_processor bc5038f7-23e0-4960-96da-33abaf5935ec
            return ($null -ne $mn -and $null -ne $mx -and $mn.AC -eq 0 -and $mx.AC -eq 100)
        }
    }
    
    "Sys_Responsiveness" = @{
        Apply={ Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 0 }
        Revert={ Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 20 }
        Check={ Test-Reg-Read "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 0 }
    }

    "Sys_StartAds" = @{ Explorer=$true; 
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
    
    "Sys_NoGallery" = @{ Explorer=$true; 
        Apply={ Set-Reg "HKCU:\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}" "System.IsPinnedToNameSpaceTree" 0 "DWord" }; 
        Revert={ Remove-Item "HKCU:\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}" -Recurse -ErrorAction SilentlyContinue }; 
        Check={ Test-Reg-Read "HKCU:\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}" "System.IsPinnedToNameSpaceTree" 0 } 
    }
    
    "Sys_NoHome" = @{ Explorer=$true; 
        Apply={ Set-Reg "HKCU:\Software\Classes\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}" "System.IsPinnedToNameSpaceTree" 0 "DWord" }; 
        Revert={ Remove-Item "HKCU:\Software\Classes\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}" -Recurse -ErrorAction SilentlyContinue }; 
        Check={ Test-Reg-Read "HKCU:\Software\Classes\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}" "System.IsPinnedToNameSpaceTree" 0 } 
    }
    
    "Sys_CleanThisPC" = @{ Explorer=$true;
        Apply={
            $k = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace"
            Remove-Item "$k\{0db7e03f-fc29-4dc6-9020-ff4163b913e4}" -ErrorAction SilentlyContinue 
            Remove-Item "$k\{d3162b92-9365-467a-956b-92703aca08af}" -ErrorAction SilentlyContinue 
            Remove-Item "$k\{088e3905-0323-4b02-9826-5d99428e115f}" -ErrorAction SilentlyContinue 
            Remove-Item "$k\{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}" -ErrorAction SilentlyContinue 
            Remove-Item "$k\{24ad3ad4-a569-4530-98e1-ab02f9417aa8}" -ErrorAction SilentlyContinue 
            Remove-Item "$k\{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}" -ErrorAction SilentlyContinue 
        }
        Revert={ 
            $k = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace"
            New-Item "$k\{0db7e03f-fc29-4dc6-9020-ff4163b913e4}" -Force -ErrorAction SilentlyContinue | Out-Null
            New-Item "$k\{d3162b92-9365-467a-956b-92703aca08af}" -Force -ErrorAction SilentlyContinue | Out-Null
            New-Item "$k\{088e3905-0323-4b02-9826-5d99428e115f}" -Force -ErrorAction SilentlyContinue | Out-Null
            New-Item "$k\{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}" -Force -ErrorAction SilentlyContinue | Out-Null
            New-Item "$k\{24ad3ad4-a569-4530-98e1-ab02f9417aa8}" -Force -ErrorAction SilentlyContinue | Out-Null
            New-Item "$k\{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}" -Force -ErrorAction SilentlyContinue | Out-Null
        }
        Check={ !(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0db7e03f-fc29-4dc6-9020-ff4163b913e4}") }
    }
    
    # NOTE: a registry DEFAULT value cannot be deleted with Remove-ItemProperty - the call
    # silently succeeds and leaves the value in place. Any tweak that writes "(default)" must
    # therefore revert by WRITING the original back (or removing the key it created), never by
    # trying to remove the value. This one and Adv_PhotoViewer both used to fail that way and
    # simply never reverted.
    "Sys_DupliDrive" = @{ Explorer=$true;
        Apply={
            $p = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\DelegateFolders\{F5FB2C77-0E2F-4A16-A381-3E560C68BC83}"
            if (Test-Path $p) { $o = (Get-ItemProperty -Path $p -ErrorAction SilentlyContinue).'(default)'; Save-OriginalState "Sys_DupliDrive.Default" "V:$o" }
            else { Save-OriginalState "Sys_DupliDrive.Default" "ABSENT" }
            Set-Reg $p "(default)" "-" "String"
        }
        Revert={
            $p = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\DelegateFolders\{F5FB2C77-0E2F-4A16-A381-3E560C68BC83}"
            $orig = Get-OriginalState "Sys_DupliDrive.Default"
            if (-not $orig -or $orig -eq "ABSENT") { Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue }
            else { Set-Reg $p "(default)" ($orig.Substring(2)) "String" }
            Clear-OriginalState "Sys_DupliDrive.Default"
        }
        Check={ Test-Reg-Read "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\DelegateFolders\{F5FB2C77-0E2F-4A16-A381-3E560C68BC83}" "(default)" "-" }
    }

    "Sys_FinishSetup" = @{ Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" "ScoobeSystemSettingEnabled" 0 }; Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" "ScoobeSystemSettingEnabled" 1 }; Check={ Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" "ScoobeSystemSettingEnabled" 0 } }
    
    "Sys_SnapFlyout" = @{ 
        Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "EnableSnapAssistFlyout" 0 }
        Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "EnableSnapAssistFlyout" 1 }
        Check={ Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "EnableSnapAssistFlyout" 0 }
    }

    "Sys_SleepTimeout" = @{ 
        Apply={ # Record this machine's original value BEFORE changing it (restored exactly on Revert).
            Save-PowerOriginal "Sys_SleepTimeout" 238c9fa8-0aad-41ed-83f4-97be242c8f20 7bc4a2f9-d8fc-4469-b07b-33eb785aaca0;
            
            $guid = "238c9fa8-0aad-41ed-83f4-97be242c8f20"; $sub = "7bc4a2f9-d8fc-4469-b07b-33eb785aaca0"
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\$guid\$sub" "Attributes" 2
            powercfg /setacvalueindex scheme_current $guid $sub 0
            powercfg /setdcvalueindex scheme_current $guid $sub 0
            powercfg /setactive scheme_current 
        }
        Revert={ Restore-PowerOriginal "Sys_SleepTimeout" 238c9fa8-0aad-41ed-83f4-97be242c8f20 7bc4a2f9-d8fc-4469-b07b-33eb785aaca0 120 120 'Both' }
        Check={ $v = Get-PowerIndex 238c9fa8-0aad-41ed-83f4-97be242c8f20 7bc4a2f9-d8fc-4469-b07b-33eb785aaca0; return ($null -ne $v -and $v.AC -eq 0 -and $v.DC -eq 0) }
    }
    
    "Sys_BackgroundMode" = @{ 
        SlowCheck=$true
        Apply={ param($v) $val = if ([int]$v -eq 1) { 2 } else { 0 }; Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsRunInBackground" $val }
        Revert={ Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsRunInBackground" }
        Check={ 
            $p = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"
            $val = Get-ItemProperty -Path $p -Name "LetAppsRunInBackground" -ErrorAction SilentlyContinue
            if ($val -and $val.LetAppsRunInBackground -eq 2) { return 1 }
            return 0
        }
    }

    # --- GAMING ---
    "Game_HAGS" = @{ UserState=$true; 
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
    
    # 8.0: Settings > Display > Graphics > "Variable refresh rate" is VRROptimizeEnable INSIDE a shared
    # settings string (see Set-DxUserSetting). The old tweak wrote "VRROptimize=1" as the whole value: a
    # name Windows never reads (it did nothing), and it wiped Auto HDR + "Optimizations for windowed
    # games". Now only this entry changes; its own original is recorded and put back.
    "Game_VRR" = @{ UserState=$true;
        Apply={
            $o = Get-DxUserSetting "VRROptimizeEnable"
            Save-OriginalState "Game_VRR.Entry" $(if ($null -eq $o) { "ABSENT" } else { "V:$o" })
            Set-DxUserSetting "VRROptimize" $null          # the stray entry older Ronin versions wrote
            Set-DxUserSetting "VRROptimizeEnable" 1
        }
        Revert={
            $o = Get-OriginalState "Game_VRR.Entry"
            Set-DxUserSetting "VRROptimize" $null
            if ($o -and $o -ne "ABSENT") { Set-DxUserSetting "VRROptimizeEnable" $o.Substring(2) } else { Set-DxUserSetting "VRROptimizeEnable" $null }
            Clear-OriginalState "Game_VRR.Entry"
        }
        Check={ "$(Get-DxUserSetting 'VRROptimizeEnable')" -eq "1" }
    }

    "Game_GpuPriority" = @{
        Apply={
            $p = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
            Save-RegOriginal "Game_GpuPriority.Gpu" $p "GPU Priority"
            Save-RegOriginal "Game_GpuPriority.Sched" $p "Scheduling Category"
            Set-Reg $p "GPU Priority" 8; Set-Reg $p "Scheduling Category" "High" "String"
        }
        # Old Revert wrote GPU Priority 0 - BELOW the Windows default of 8 - so "undo" made games
        # worse than never having touched Ronin. Fallbacks are now the real Windows defaults.
        Revert={
            $p = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
            if (-not (Restore-RegOriginal "Game_GpuPriority.Gpu" $p "GPU Priority")) { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "GPU Priority" 8 }
            if (-not (Restore-RegOriginal "Game_GpuPriority.Sched" $p "Scheduling Category")) { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Scheduling Category" "Medium" "String" }
        }
        # Check must mirror BOTH values Apply writes. It used to test only GPU Priority=8, which is
        # already the Windows default - so the tweak read "Already Optimized" on every stock PC and
        # the part that actually does something (Scheduling Category=High) was never applied.
        Check={
            $p = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
            return ((Test-Reg-Read $p "GPU Priority" 8) -and (Test-Reg-Read $p "Scheduling Category" "High"))
        }
    }

    "Game_GameMode" = @{ UserState=$true; 
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
    "Game_Nagle" = @{
        # Nagle settings only take effect on the per-interface subkeys (Interfaces\{GUID}),
        # not the parent Interfaces key - the old single-key write was a silent no-op.
        Apply={
            Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" -ErrorAction SilentlyContinue | ForEach-Object {
                Set-Reg $_.PSPath "TcpAckFrequency" 1
                Set-Reg $_.PSPath "TCPNoDelay" 1
            }
        }
        Revert={
            Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" -ErrorAction SilentlyContinue | ForEach-Object {
                Remove-Reg $_.PSPath "TcpAckFrequency"
                Remove-Reg $_.PSPath "TCPNoDelay"
            }
            # Clean up the stray value older builds wrote on the parent key
            Remove-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" "TcpAckFrequency"
        }
        Check={
            foreach ($i in (Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" -ErrorAction SilentlyContinue)) {
                if ((Get-ItemProperty $i.PSPath -Name "TcpAckFrequency" -ErrorAction SilentlyContinue).TcpAckFrequency -eq 1) { return $true }
            }
            return $false
        }
    }
    
    "Game_MouseAccel" = @{ UserState=$true; 
        Apply={ 
            Set-Reg "HKCU:\Control Panel\Mouse" "MouseSpeed" "0" "String"
            Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold1" "0" "String"
            Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold2" "0" "String"
        }
        Revert={ 
            Set-Reg "HKCU:\Control Panel\Mouse" "MouseSpeed" "1" "String"
            Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold1" "6" "String"
            Set-Reg "HKCU:\Control Panel\Mouse" "MouseThreshold2" "10" "String"
        }
        Check={ 
            $c1 = Test-Reg-Read "HKCU:\Control Panel\Mouse" "MouseSpeed" "0"
            $c2 = Test-Reg-Read "HKCU:\Control Panel\Mouse" "MouseThreshold1" "0"
            $c3 = Test-Reg-Read "HKCU:\Control Panel\Mouse" "MouseThreshold2" "0"
            return ($c1 -and $c2 -and $c3)
        }
    }
    "Game_Sticky" = @{ UserState=$true; Apply={ Set-Reg "HKCU:\Control Panel\Accessibility\StickyKeys" "Flags" "506" "String" }; Revert={ Set-Reg "HKCU:\Control Panel\Accessibility\StickyKeys" "Flags" "510" "String" }; Check={ Test-Reg-Read "HKCU:\Control Panel\Accessibility\StickyKeys" "Flags" "506" } }
    
    "Game_Latency" = @{ 
        Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" "TCPNoDelay" 1; Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" "TcpAckFrequency" 1 }; 
        Revert={ Remove-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" "TCPNoDelay"; Remove-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" "TcpAckFrequency" }; 
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
            if ($p) {
                Save-RegOriginal "Game_InterruptModeration.MSI" "$p\Interrupt Management\MessageSignaledInterruptProperties" "MSISupported"
                Save-RegOriginal "Game_InterruptModeration.Prio" "$p\Interrupt Management\Affinity Policy" "DevicePriority"
                Set-Reg "$p\Interrupt Management\MessageSignaledInterruptProperties" "MSISupported" 1; Set-Reg "$p\Interrupt Management\Affinity Policy" "DevicePriority" 0
            }
        }
        # Many current NVIDIA/AMD drivers ship MSISupported=1 THEMSELVES. The old Revert deleted it
        # unconditionally, switching the GPU back to line-based interrupts - a revert that undid the
        # driver's own setting. Now restores exactly what the driver had.
        Revert={
            $p = Get-GpuRegistryPath "NVIDIA|AMD"
            if ($p) {
                if (-not (Restore-RegOriginal "Game_InterruptModeration.Prio" "$p\Interrupt Management\Affinity Policy" "DevicePriority")) { Remove-Reg "$p\Interrupt Management\Affinity Policy" "DevicePriority" }
                if (-not (Restore-RegOriginal "Game_InterruptModeration.MSI" "$p\Interrupt Management\MessageSignaledInterruptProperties" "MSISupported")) { Remove-Reg "$p\Interrupt Management\MessageSignaledInterruptProperties" "MSISupported" }
            }
        }
        Check={ 
            $p = Get-GpuRegistryPath "NVIDIA|AMD"; if ($p) { 
                $c1 = Test-Reg-Read "$p\Interrupt Management\Affinity Policy" "DevicePriority" 0
                $c2 = Test-Reg-Read "$p\Interrupt Management\MessageSignaledInterruptProperties" "MSISupported" 1
                return ($c1 -and $c2) 
            } return $false 
        }
    }

    "Game_DirectStorage" = @{ UserState=$true;
        Warning="SAFEGUARD: Forces Windows default (Compression Enabled) for game stability."
        Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisableCompression" 0 }
        Revert={ Remove-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisableCompression" }
        Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisableCompression" 0 }
    }

    "Game_ScatterGather" = @{
        Apply={ Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device" -Name "ForcedPhysicalSectorSizeInBytes" -Value @("4096") -Type MultiString -Force -ErrorAction SilentlyContinue } 
        Revert={ Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device" -Name "ForcedPhysicalSectorSizeInBytes" -ErrorAction SilentlyContinue }
        Check={
            # Was INVERTED: it returned "applied" when the value was ABSENT (and even when the
            # key didn't exist), so the toggle read as already-optimized on every machine and a
            # real Apply then reported "ran but Check still reports not-applied".
            $path = "HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device"
            if (!(Test-Path $path)) { return $false }
            return [bool](Get-ItemProperty $path -Name "ForcedPhysicalSectorSizeInBytes" -ErrorAction SilentlyContinue)
        }
    }

    "Game_NtfsMemory" = @{ 
        Warning="SAFEGUARD: Forces Windows default pool size to prevent out-of-memory errors."
        Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsMemoryUsage" 2 } 
        Revert={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsMemoryUsage" 1 } 
        Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsMemoryUsage" 2 } 
    }
    
    "Game_IoPriority" = @{ UserState=$true; 
        Warning="SAFEGUARD: Resets I/O priority to Windows default kernel management."
        Apply={ $p = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\I/O Priority"; if(Test-Path $p){ Remove-ItemProperty -Path $p -Name "IoPriority" -ErrorAction SilentlyContinue } } 
        Revert={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\I/O Priority" "IoPriority" 2 } 
        Check={ 
            $p = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\I/O Priority"
            if (!(Test-Path $p)) { return $true }
            return !(Get-ItemProperty $p -Name "IoPriority" -ErrorAction SilentlyContinue)
        } 
    }
    
    # 8.0 Twin: both boxes are the same DWM flag (OverlayTestMode=5). Before, ticking "Disable MPO"
    # alone applied it and the unticked Flip Mode box right after it reverted it in the same batch.
    # Get-Tasks (Resolve-TwinTasks) now moves the pair together; both need a restart.
    "Game_MPO" = @{ Reboot=$true; Twin="Game_NvidiaFlipMode"; Apply={ Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" "OverlayTestMode" 5 }; Revert={ Remove-Reg "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" "OverlayTestMode" }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" "OverlayTestMode" 5 } }
    "Game_NvidiaFlipMode" = @{ Reboot=$true; Twin="Game_MPO"; Apply={ Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" "OverlayTestMode" 5 }; Revert={ Remove-Reg "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" "OverlayTestMode" }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" "OverlayTestMode" 5 } }
    "Game_PCIe" = @{ SlowCheck=$true; Apply={ Set-PCIe-Mode $true }; Revert={ Set-PCIe-Mode $false }; Check={ (Get-PCIe-State) -eq 0 } }
    
    "Game_VariBright" = @{ 
        SlowCheck=$true
        Warning="REQUIRES MOBILE AMD GPU. Skipped silently on non-AMD systems."
        Apply={ Log "  - Disabling AMD VariBright (auto-dimming)"; Set-AMD-Feature "PP_VariBrightFeatureEnable" 0 }
        Revert={ Log "  - Re-enabling AMD VariBright"; Set-AMD-Feature "PP_VariBrightFeatureEnable" 1 }
        Check={ 
            $p = Get-GpuRegistryPath "AMD"
            if ($p) { return (Test-Reg-Read $p "PP_VariBrightFeatureEnable" 0) }
            return $false 
        } 
    }
    
    "Game_DPST" = @{ 
        Reboot=$true; SlowCheck=$true
        Apply={ $p = Get-Intel-Video-Key; if ($p) { $cur = (Get-ItemProperty -LiteralPath $p -Name "FeatureTestControl" -ErrorAction SilentlyContinue).FeatureTestControl; if ($null -eq $cur) { $cur = 0 }; Set-ItemProperty -LiteralPath $p -Name "FeatureTestControl" -Value ($cur -bor 0x10) -Type DWord -Force } }
        Revert={ $p = Get-Intel-Video-Key; if ($p) { $cur = (Get-ItemProperty -LiteralPath $p -Name "FeatureTestControl" -ErrorAction SilentlyContinue).FeatureTestControl; if ($null -eq $cur) { return }; Set-ItemProperty -LiteralPath $p -Name "FeatureTestControl" -Value ($cur -band (-bnot 0x10)) -Type DWord -Force } }
        Check={ $p = Get-Intel-Video-Key; if ($p) { $cur = (Get-ItemProperty $p -Name "FeatureTestControl" -ErrorAction SilentlyContinue).FeatureTestControl; return (($cur -band 0x10) -eq 0x10) } return $false } 
    }

    "Game_IntelVram" = @{
        Reboot=$true; SlowCheck=$true
        Apply={
            $p = Get-Intel-Video-Key; if ($p) { $cur = (Get-ItemProperty -LiteralPath $p -Name "FeatureTestControl" -ErrorAction SilentlyContinue).FeatureTestControl; if ($null -eq $cur) { $cur = 0 }; Set-ItemProperty -LiteralPath $p -Name "FeatureTestControl" -Value ($cur -bor 0x200) -Type DWord -Force }
            $gmm = "HKLM:\SOFTWARE\Intel\GMM"; if (!(Test-Path $gmm)) { New-Item -Path $gmm -Force | Out-Null }; Set-ItemProperty $gmm -Name "DedicatedSegmentSize" -Value 4096 -Type DWord
        }
        Revert={
            $p = Get-Intel-Video-Key; if ($p) { $cur = (Get-ItemProperty -LiteralPath $p -Name "FeatureTestControl" -ErrorAction SilentlyContinue).FeatureTestControl; if ($null -eq $cur) { return }; Set-ItemProperty -LiteralPath $p -Name "FeatureTestControl" -Value ($cur -band (-bnot 0x200)) -Type DWord -Force }
            Remove-ItemProperty "HKLM:\SOFTWARE\Intel\GMM" -Name "DedicatedSegmentSize" -ErrorAction SilentlyContinue
        }
        Check={
            $p = Get-Intel-Video-Key; if ($p) { $cur = (Get-ItemProperty $p -Name "FeatureTestControl" -ErrorAction SilentlyContinue).FeatureTestControl; return (($cur -band 0x200) -eq 0x200) }
            return (Test-Reg-Read "HKLM:\SOFTWARE\Intel\GMM" "DedicatedSegmentSize" 4096)
        }
    }
    
    "Game_TdrDelay" = @{ Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "TdrDelay" 10 }; Revert={ Remove-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "TdrDelay" }; Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "TdrDelay" 10 } }

    # --- PRIVACY ---
    # 8.0 EditionNote: shown in the tooltip on editions other than Enterprise/Education.
    "Priv_Tele" = @{ EditionNote="Windows Home and Pro treat telemetry level 0 as level 1 (Required diagnostic data) - Microsoft only honours 0 on Enterprise and Education. Ronin still sets 0, so you get the lowest level your edition allows.";
        
        Apply={ 
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0
            Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\DataCollection" "AllowTelemetry" 0
            Start-Process "gpupdate" -ArgumentList "/force" -NoNewWindow -ErrorAction SilentlyContinue
        }
        Revert={ 
            # Removing the policy returns to Microsoft default rather than forcing Basic telemetry
            Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry"
            Remove-Reg "HKLM:\SOFTWARE\Microsoft\Windows\DataCollection" "AllowTelemetry"
        }
        Check={ Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0 } 
    }
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
        # Old Revert wrote the policy as 0 (leaving a policy key behind) and set lfsvc to Automatic +
        # started it. Windows default is NO policy value and lfsvc Manual (trigger-start).
        Revert={
            Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" "DisableLocation"
            Set-Service lfsvc -StartupType Manual
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
    
    # 8.0 ROOT CAUSE of the G14 false-fail (build 26200): current Windows 11 guards the taskbar's
    # TaskbarDa value with the User Choice Protection Driver (UCPD). Writes from PowerShell are refused
    # ("Attempted to perform an unauthorized operation" - reproduced on the dev PC), so Apply could never
    # set it and the Check, which required it, failed forever unless the button was already off. The
    # Widgets POLICY is what turns Widgets off (button included) and writes fine, so Check tests the
    # policy only. TaskbarDa is still set where Windows allows it (UCPD absent or disabled), recorded,
    # and put back on revert. Ronin never disables UCPD (a Windows protection). Explorer restarts once
    # so the button goes straight away.
    "Priv_Widgets" = @{ Explorer=$true
        Apply={
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" 0
            $adv = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
            if (-not (Test-Reg-Read $adv "TaskbarDa" 0)) {
                $ucpd = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\UCPD" -Name "Start" -ErrorAction SilentlyContinue
                if ($ucpd -and "$($ucpd.Start)" -ne "4") { Log "  - Windows protects the Widgets button setting on this build, so the Widgets policy removes the button instead (after Explorer restarts)." }
                else { Save-RegOriginal "Priv_Widgets.TaskbarDa" $adv "TaskbarDa"; Set-Reg $adv "TaskbarDa" 0 }
            }
        }
        Revert={
            Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests"
            [void](Restore-RegOriginal "Priv_Widgets.TaskbarDa" "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa")
        }
        Check={ Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" 0 }
    }
    
    "Priv_Copilot" = @{ Explorer=$true; 
        Apply={ 
            Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCopilotButton" 0
            Set-Reg "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "HubsSidebarEnabled" 0
            # Best-effort AppxPackage removal (system-protected packages will not remove on 24H2/25H2)
            try { Get-AppxPackage *Copilot* -ErrorAction SilentlyContinue | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -ErrorAction SilentlyContinue } } catch {}
        }
        Revert={ 
            Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCopilotButton" 1
            Remove-Reg "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot"
            Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot"
            Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "HubsSidebarEnabled"
        }
        Check={ 
            # Copilot AppxPackage is system-protected on 24H2/25H2 and cannot be removed
            # We verify only the policy registry keys (sufficient to disable the feature)
            $ui = Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCopilotButton" 0
            $polUser = Test-Reg-Read "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1
            $polMach = Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1
            $edge = Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "HubsSidebarEnabled" 0
            return ($ui -and $polUser -and $polMach -and $edge)
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
        SlowCheck=$true
        Warning="Disables CEIP and telemetry scheduled tasks. Some are system-protected on 24H2/25H2; the tweak reports applied if at least one was successfully disabled."
        Apply={ 
            # Registry backstops run FIRST so the tweak is detectable even if task ops fail
            try { Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "AITEnable" 0 } catch { Log "  - AITEnable write failed: $($_.Exception.Message)" }
            try { Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "DisableUAR" 1 } catch { Log "  - DisableUAR write failed: $($_.Exception.Message)" }
            # (AllowTelemetry is NOT written here any more: it belongs to Priv_Tele. Writing it from
            # this tweak meant reverting Priv_TeleTasks could never remove it, and removing it would
            # have silently undone Priv_Tele.)
            # Best-effort task disabling - protected tasks will log "PROTECTED" but not abort the apply
            try { Disable-Task "\Microsoft\Windows\Application Experience" "Microsoft Compatibility Appraiser" } catch {}
            try { Disable-Task "\Microsoft\Windows\Application Experience" "ProgramDataUpdater" } catch {}
            try { Disable-Task "\Microsoft\Windows\Application Experience" "StartupAppTask" } catch {}
            try { Disable-Task "\Microsoft\Windows\Autochk" "Proxy" } catch {}
            try { Disable-Task "\Microsoft\Windows\Customer Experience Improvement Program" "Consolidator" } catch {}
            try { Disable-Task "\Microsoft\Windows\Customer Experience Improvement Program" "UsbCeip" } catch {}
            try { Disable-Task "\Microsoft\Windows\Customer Experience Improvement Program" "KernelCeipTask" } catch {}
            try { Disable-Task "\Microsoft\Windows\DiskDiagnostic" "Microsoft-Windows-DiskDiagnosticDataCollector" } catch {}
        }
        Revert={ 
            Enable-Task "\Microsoft\Windows\Application Experience" "Microsoft Compatibility Appraiser"
            Enable-Task "\Microsoft\Windows\Application Experience" "ProgramDataUpdater"
            Enable-Task "\Microsoft\Windows\Application Experience" "StartupAppTask"
            Enable-Task "\Microsoft\Windows\Autochk" "Proxy"
            Enable-Task "\Microsoft\Windows\Customer Experience Improvement Program" "Consolidator"
            Enable-Task "\Microsoft\Windows\Customer Experience Improvement Program" "UsbCeip"
            Enable-Task "\Microsoft\Windows\Customer Experience Improvement Program" "KernelCeipTask"
            Enable-Task "\Microsoft\Windows\DiskDiagnostic" "Microsoft-Windows-DiskDiagnosticDataCollector"
            Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "AITEnable"
            Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "DisableUAR"
        }
        Check={ 
            # Registry backstop check: if our policy keys are set, tweak is applied
            if (Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "AITEnable" 0) { return $true }
            # Lenient task check: verify at least one of the 8 targeted tasks is Disabled.
            # Many are admin-protected on 24H2/25H2 - we accept best-effort.
            $tasks = @(@("\Microsoft\Windows\Application Experience\","Microsoft Compatibility Appraiser"),@("\Microsoft\Windows\Application Experience\","ProgramDataUpdater"),@("\Microsoft\Windows\Application Experience\","StartupAppTask"),@("\Microsoft\Windows\Autochk\","Proxy"),@("\Microsoft\Windows\Customer Experience Improvement Program\","Consolidator"),@("\Microsoft\Windows\Customer Experience Improvement Program\","UsbCeip"),@("\Microsoft\Windows\Customer Experience Improvement Program\","KernelCeipTask"),@("\Microsoft\Windows\DiskDiagnostic\","Microsoft-Windows-DiskDiagnosticDataCollector"))
            foreach ($t in $tasks) {
                $obj = Get-ScheduledTask -TaskPath $t[0] -TaskName $t[1] -ErrorAction SilentlyContinue
                if ($obj -and $obj.State -eq "Disabled") { return $true }
            }
            return $false
        } 
    }

    # 8.0: this tweak's "registry backstops" were three values OWNED by other tweaks
    # (TurnOffClickToDo = Priv_24H2_AI, DisableInventory = Priv_Inventory, DisableAIDataAnalysis =
    # Sys_Recall), and its Check passed on either of the first two. So with "Disable Click To Do"
    # ticked and this box unticked, EVERY Privacy-tab Apply ran this Revert: it deleted Click To Do's
    # value (re-applied a moment later by its own box), the Inventory value, and Recall's
    # DisableAIDataAnalysis policy - silently, from another tab, every time. It now owns only its
    # tasks. Revert still removes those values when their owner isn't applied, which cleans up what
    # versions before 8.0 wrote here.
    "Priv_AI_Telemetry" = @{
        SlowCheck=$true
        Warning="Disables the 24H2/25H2 AI telemetry tasks. Some are system-protected and cannot be disabled; the tweak reports applied if at least one was disabled (none present on your build = not applied)."
        Apply={
            # Best-effort task disabling - protected tasks log warnings but won't abort the apply
            try { Disable-Task "\Microsoft\Windows\User Experience" "AmbientExperienceTasks" } catch {}
            try { Disable-Task "\Microsoft\Windows\WindowsAI" "AI Phi Silica Cleanup" } catch {}
            try { Disable-Task "\Microsoft\Windows\WindowsAI" "ClickToDoUpdateTask" } catch {}
            try { Disable-Task "\Microsoft\Windows\PushToInstall" "Registration" } catch {}
        }
        Revert={
            Enable-Task "\Microsoft\Windows\User Experience" "AmbientExperienceTasks"
            Enable-Task "\Microsoft\Windows\WindowsAI" "AI Phi Silica Cleanup"
            Enable-Task "\Microsoft\Windows\WindowsAI" "ClickToDoUpdateTask"
            Enable-Task "\Microsoft\Windows\PushToInstall" "Registration"
            # Cleanup of the values versions before 8.0 wrote from here - only where their owning tweak
            # is not applied (by the ledger; for Recall also its own AllowRecallEnablement value).
            if (-not (Test-AppliedMark "Priv_24H2_AI")) { Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "TurnOffClickToDo" }
            if (-not (Test-AppliedMark "Priv_Inventory")) { Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "DisableInventory" }
            if (-not (Test-AppliedMark "Sys_Recall") -and -not (Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "AllowRecallEnablement" 0)) { Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" }
        }
        Check={
            # Applied = at least one task we disable is Disabled (robust across 24H2/25H2 task path
            # variations). Never reads another tweak's values (see above).
            $candidates = @(
                @("\Microsoft\Windows\User Experience\","AmbientExperienceTasks"),
                @("\Microsoft\Windows\WindowsAI\","AI Phi Silica Cleanup"),
                @("\Microsoft\Windows\WindowsAI\","ClickToDoUpdateTask"),
                @("\Microsoft\Windows\PushToInstall\","Registration")
            )
            foreach ($c in $candidates) {
                $t = Get-ScheduledTask -TaskPath $c[0] -TaskName $c[1] -ErrorAction SilentlyContinue
                if ($t -and $t.State -eq "Disabled") { return $true }
            }
            return $false
        } 
    }

    "Priv_Feedback" = @{ 
        Warning="Feedback App removal is permanent (reinstall it from the Microsoft Store). Revert restores the DiagTrack and dmwappushservice services."
        Apply={ 
            try { Get-AppxPackage *feedback* -ErrorAction SilentlyContinue | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -ErrorAction SilentlyContinue } } catch {}
            try { Stop-Service DiagTrack -Force -ErrorAction SilentlyContinue } catch {}
            # DiagTrack is protected on 24H2/25H2 - use registry to set Start=4 (Disabled)
            Set-Service-Registry "DiagTrack" "Disabled" | Out-Null
            Set-Service-Registry "dmwappushservice" "Disabled" | Out-Null
        }
        Revert={ 
            Set-Service-Registry "DiagTrack" "Automatic" | Out-Null
            try { Start-Service DiagTrack -ErrorAction SilentlyContinue } catch {}
            # Apply disables this too and it was never restored. It is the WAP push service that
            # device-management (MDM/Intune) enrollment depends on; Windows default is Manual.
            Set-Service-Registry "dmwappushservice" "Manual" | Out-Null
        }
        Check={ 
            # Verify via registry since Get-Service caches and may report stale state
            $s = Get-ItemProperty -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Services\DiagTrack" -Name "Start" -ErrorAction SilentlyContinue
            if ($null -eq $s) { return $true }
            return ($s.Start -eq 4)
        } 
    }
    
    "Priv_Inventory" = @{ Apply={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "DisableInventory" 1 }; Revert={ Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "DisableInventory" }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "DisableInventory" 1 } }
    "Priv_ActivityUpload" = @{ Apply={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "UploadUserActivities" 0 }; Revert={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "UploadUserActivities" 1 }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "UploadUserActivities" 0 } }
    "Priv_CloudClipboard" = @{ Apply={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "AllowClipboardHistory" 0 }; Revert={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "AllowClipboardHistory" 1 }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "AllowClipboardHistory" 0 } }
    "Priv_Maps" = @{ Apply={ Set-Reg "HKLM:\SYSTEM\Maps" "AutoUpdateEnabled" 0 }; Revert={ Set-Reg "HKLM:\SYSTEM\Maps" "AutoUpdateEnabled" 1 }; Check={ Test-Reg-Read "HKLM:\SYSTEM\Maps" "AutoUpdateEnabled" 0 } }
    "Priv_AppTrack" = @{ Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackProgs" 0 }; Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackProgs" 1 }; Check={ Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackProgs" 0 } }
    "Priv_ActivityFeed" = @{ Apply={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableActivityFeed" 0 }; Revert={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableActivityFeed" 1 }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableActivityFeed" 0 } }
    # 8.0: Settings > Privacy & security > Inking & typing personalization ("custom dictionary"): the
    # values that switch writes. Stops Windows collecting your handwriting and typing (and your
    # contacts' names) to build a personal dictionary. Spec: originals recorded, restored exactly.
    "Priv_InkTyping" = @{ UserState=$true
        Spec=@(
            @{ P="HKCU:\Software\Microsoft\InputPersonalization"; N="RestrictImplicitInkCollection"; V=1 }
            @{ P="HKCU:\Software\Microsoft\InputPersonalization"; N="RestrictImplicitTextCollection"; V=1 }
            @{ P="HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore"; N="HarvestContacts"; V=0 }
            @{ P="HKCU:\Software\Microsoft\Personalization\Settings"; N="AcceptedPrivacyPolicy"; V=0 }
        )
        Apply={ Invoke-SpecApply 'Priv_InkTyping' }; Revert={ Invoke-SpecRevert 'Priv_InkTyping' }; Check={ Test-Spec 'Priv_InkTyping' } }
    "Priv_TypingInsights" = @{ Apply={ Set-Reg "HKCU:\Software\Microsoft\Input\Settings" "InsightsEnabled" 0 }; Revert={ Set-Reg "HKCU:\Software\Microsoft\Input\Settings" "InsightsEnabled" 1 }; Check={ return (Test-Reg-Read "HKCU:\Software\Microsoft\Input\Settings" "InsightsEnabled" 0) } }
    "Priv_TailoredExp" = @{ Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" "TailoredExperiencesAllowed" 0 }; Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" "TailoredExperiencesAllowed" 1 }; Check={ return (Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" "TailoredExperiencesAllowed" 0) } }

    "Priv_EdgeCopilot" = @{
        Apply={
            # Documented Edge enterprise policies: block Copilot reading page content + hide M365 chat icon
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "CopilotPageContext" 0
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "CopilotCDPPageContext" 0
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "Microsoft365CopilotChatIconEnabled" 0
        }
        Revert={
            Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "CopilotPageContext"
            Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "CopilotCDPPageContext"
            Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "Microsoft365CopilotChatIconEnabled"
        }
        Check={ Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "CopilotPageContext" 0 }
    }

    "Priv_AIExtras" = @{
        Apply={
            # Paint generative AI (documented Paint policy CSP, 23H2+)
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Paint" "DisableImageCreator" 1
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Paint" "DisableCocreator" 1
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Paint" "DisableGenerativeFill" 1
            # Office AI training opt-out (harmless no-op if Office is absent)
            Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common\ai\training\general" "disabletraining" 1
            # 8.0: Notepad's own policy that switches off its AI features (Rewrite / Summarize / Copilot)
            Set-Reg "HKLM:\SOFTWARE\Policies\WindowsNotepad" "DisableAIFeatures" 1
            # Hide the 'AI Components' Settings page. Only creates or appends to a hide: list;
            # never touches a showonly: list (that would hide every OTHER Settings page).
            $pvPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
            $cur = (Get-ItemProperty -LiteralPath $pvPath -Name "SettingsPageVisibility" -ErrorAction SilentlyContinue).SettingsPageVisibility
            if ([string]::IsNullOrWhiteSpace($cur)) {
                Set-Reg $pvPath "SettingsPageVisibility" "hide:aicomponents" "String"
            } elseif ($cur -like "hide:*" -and $cur -notmatch "aicomponents") {
                Set-Reg $pvPath "SettingsPageVisibility" "$cur;aicomponents" "String"
            }
        }
        Revert={
            Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Paint" "DisableImageCreator"
            Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Paint" "DisableCocreator"
            Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Paint" "DisableGenerativeFill"
            Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\common\ai\training\general" "disabletraining"
            Remove-Reg "HKLM:\SOFTWARE\Policies\WindowsNotepad" "DisableAIFeatures"
            $pvPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer"
            $cur = (Get-ItemProperty -LiteralPath $pvPath -Name "SettingsPageVisibility" -ErrorAction SilentlyContinue).SettingsPageVisibility
            if ($cur -like "hide:*") {
                $parts = @(); foreach ($p in ($cur.Substring(5) -split ';')) { if ($p -and $p -ne "aicomponents") { $parts += $p } }
                if ($parts.Count -gt 0) { Set-Reg $pvPath "SettingsPageVisibility" ("hide:" + ($parts -join ';')) "String" }
                else { Remove-Reg $pvPath "SettingsPageVisibility" }
            }
        }
        Check={ Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Paint" "DisableImageCreator" 1 }
    }

    # --- HANDHELD / DUAL-STATE POWER TWEAKS ---
    # Universal console mode (works on desktop / laptop / handheld - Steam Big Picture is a full
    # console UI on any hardware). Lives in the Gaming tab so HTPC/living-room desktops can use it,
    # not just handhelds. Renamed from HH_SteamDeck; Check reads live state so prior applies still register.
    "Game_ConsoleMode" = @{
        Apply={
            $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
            Set-Reg "HKCU:\Software\Valve\Steam" "StartupMode" 1 "DWord"
            $steamPath = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).SteamExe
            if (!$steamPath -or !(Test-Path $steamPath)) { if (Test-Path "C:\Program Files (x86)\Steam\steam.exe") { $steamPath = "C:\Program Files (x86)\Steam\steam.exe" } elseif (Test-Path "C:\Program Files\Steam\steam.exe") { $steamPath = "C:\Program Files\Steam\steam.exe" } }
            if ($steamPath) { $steamPath = $steamPath.Replace("/", "\"); Set-Reg $path "Steam" "`"$steamPath`" -gamepadui -silent" "String"; Log "Console Mode armed: this PC will boot into Steam Big Picture." }
            else { Log "Console Mode: Steam not found. Install Steam, then re-apply (StartupMode set, but boot-launch needs steam.exe)." }
        }
        Revert={ Set-Reg "HKCU:\Software\Valve\Steam" "StartupMode" 0 "DWord"; Remove-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" "Steam" }
        Check={ $internal = Test-Reg-Read "HKCU:\Software\Valve\Steam" "StartupMode" 1; $runKey = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue).Steam; return ($internal -and ($runKey -match "-gamepadui")) }
    }

    "HH_HibernateBtn" = @{ 
        Apply={ # Record this machine's original value BEFORE changing it (restored exactly on Revert).
            Save-PowerOriginal "HH_HibernateBtn" sub_buttons 7648efa3-dd9c-4e3e-b566-50f929386280;
            powercfg /setacvalueindex scheme_current sub_buttons 7648efa3-dd9c-4e3e-b566-50f929386280 2; powercfg /setdcvalueindex scheme_current sub_buttons 7648efa3-dd9c-4e3e-b566-50f929386280 2; powercfg /setactive scheme_current }
        Revert={ Restore-PowerOriginal "HH_HibernateBtn" sub_buttons 7648efa3-dd9c-4e3e-b566-50f929386280 1 1 'Both' }
        Check={ $v = Get-PowerIndex sub_buttons 7648efa3-dd9c-4e3e-b566-50f929386280; return ($null -ne $v -and $v.AC -eq 2 -and $v.DC -eq 2) }
    }

    "HH_WakeTimers" = @{ 
        Apply={ # Record this machine's original value BEFORE changing it (restored exactly on Revert).
            Save-PowerOriginal "HH_WakeTimers" sub_sleep bd3b7116-3b1b-43b5-b725-3003e2754d52;
            
            try {
                & powercfg /setacvalueindex scheme_current sub_sleep bd3b7116-3b1b-43b5-b725-3003e2754d52 0 2>&1 | Out-Null
                & powercfg /setdcvalueindex scheme_current sub_sleep bd3b7116-3b1b-43b5-b725-3003e2754d52 0 2>&1 | Out-Null
                & powercfg /setactive scheme_current 2>&1 | Out-Null
            } catch { Log "  - WakeTimers Apply error: $($_.Exception.Message)" }
        }
        Revert={ Restore-PowerOriginal "HH_WakeTimers" sub_sleep bd3b7116-3b1b-43b5-b725-3003e2754d52 1 1 'Both' }; Check={ $v = Get-PowerIndex 238c9fa8-0aad-41ed-83f4-97be242c8f20 bd3b7116-3b1b-43b5-b725-3003e2754d52; return ($null -ne $v -and $v.AC -eq 0) } }
    
    "HH_Standby" = @{ 
        SlowCheck=$true
        Apply={ # Record this machine's original value BEFORE changing it (restored exactly on Revert).
            Save-PowerOriginal "HH_Standby" sub_none F15576E8-98B7-4186-B944-EAFA664402D9;
            powercfg /setacvalueindex scheme_current sub_none F15576E8-98B7-4186-B944-EAFA664402D9 0; powercfg /setdcvalueindex scheme_current sub_none F15576E8-98B7-4186-B944-EAFA664402D9 0; powercfg /setactive scheme_current }
        Revert={ Restore-PowerOriginal "HH_Standby" sub_none F15576E8-98B7-4186-B944-EAFA664402D9 1 1 'Both' }
        Check={ $v = Get-PowerIndex sub_none F15576E8-98B7-4186-B944-EAFA664402D9; return ($null -ne $v -and $v.AC -eq 0) }
    } 
    
    "HH_WifiPower" = @{ SlowCheck=$true; Apply={ # Record this machine's original value BEFORE changing it (restored exactly on Revert).
            Save-PowerOriginal "HH_WifiPower" 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a;
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\19cbb8fa-5279-450e-9fac-8a3d5fedd0c1\12bbebe6-58d6-4636-95bb-3217ef867c1a"; if(Test-Path $regPath){ Set-ItemProperty -Path $regPath -Name "Attributes" -Value 2 -Type DWord -Force }; powercfg /setacvalueindex scheme_current 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 0; powercfg /setdcvalueindex scheme_current 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 0; powercfg /setactive scheme_current }; Revert={ Restore-PowerOriginal "HH_WifiPower" 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 0 2 'Both' }; Check={ $v = Get-PowerIndex 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a; return ($null -ne $v -and $v.AC -eq 0) } }
    "HH_BtFix" = @{ Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\BthPort\Parameters" "DisableSelectiveSuspend" 1 }; Revert={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\BthPort\Parameters" "DisableSelectiveSuspend" 0 }; Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Services\BthPort\Parameters" "DisableSelectiveSuspend" 1 } }
    
    "HH_CoreIso" = @{ 
        Reboot=$true; 
        Apply={ 
            if (Test-BitLocker) { Log "SAFEGUARD: Skipping Core Isolation tweak to prevent BitLocker Boot Loop."; return }
            Save-RegOriginal "HH_CoreIso" "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" "Enabled"
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" "Enabled" 0
        };
        # Old Revert forced Memory Integrity ON (Enabled=1) even on machines where it had never been
        # on - on hardware with incompatible drivers that's a device-breaking change, not an undo.
        # Restores what was there; the legacy "turn it on" only applies when nothing was recorded.
        Revert={ if (-not (Restore-RegOriginal "HH_CoreIso" "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" "Enabled")) { Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" "Enabled" 1 } };
        Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" "Enabled" 0 } 
    }
    
    "HH_DeviceGuard" = @{ 
        Reboot=$true; 
        Apply={ 
            if (Test-BitLocker) { Log "SAFEGUARD: Skipping Device Guard tweak to prevent BitLocker Boot Loop."; return }
            Save-RegOriginal "HH_DeviceGuard.Lsa" "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "LsaCfgFlags"
            Save-RegOriginal "HH_DeviceGuard.Vbs" "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard" "EnableVirtualizationBasedSecurity"
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "LsaCfgFlags" 0; Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard" "EnableVirtualizationBasedSecurity" 0
        };
        # Credential Guard can be pre-configured (LsaCfgFlags=1/2 on many OEM and work images). The
        # old Revert deleted the values, which left it OFF rather than back how it shipped.
        Revert={
            if (-not (Restore-RegOriginal "HH_DeviceGuard.Lsa" "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "LsaCfgFlags")) { Remove-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "LsaCfgFlags" }
            if (-not (Restore-RegOriginal "HH_DeviceGuard.Vbs" "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard" "EnableVirtualizationBasedSecurity")) { Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard" "EnableVirtualizationBasedSecurity" }
        };
        Check={ $c1 = Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard" "EnableVirtualizationBasedSecurity" 0; $c2 = Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "LsaCfgFlags" 0; return ($c1 -and $c2) } 
    }

    "HH_UsbSuspend" = @{ 
        Apply={ # Record this machine's original value BEFORE changing it (restored exactly on Revert).
            Save-PowerOriginal "HH_UsbSuspend" 2a737441-1930-4402-8d77-b352172fdf33 48e6b7a6-50f5-4782-a5d4-53bb8f07e226;
            
            try {
                $ac = & powercfg /SETACVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b352172fdf33 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>&1
                $dc = & powercfg /SETDCVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b352172fdf33 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>&1
                $sa = & powercfg /setactive scheme_current 2>&1
                if ($LASTEXITCODE -ne 0) { Log "  - powercfg returned exit code $LASTEXITCODE" }
            } catch { Log "  - USB Suspend Apply error: $($_.Exception.Message)" }
        }
        Revert={ Restore-PowerOriginal "HH_UsbSuspend" 2a737441-1930-4402-8d77-b352172fdf33 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1 1 'Both' }
        Check={ $v = Get-PowerIndex 2a737441-1930-4402-8d77-b352172fdf33 48e6b7a6-50f5-4782-a5d4-53bb8f07e226; return ($null -ne $v -and $v.AC -eq 0) }
    }
    
    "HH_EdgeSwipe" = @{ Apply={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI" "AllowEdgeSwipe" 0 }; Revert={ Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI" "AllowEdgeSwipe" }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI" "AllowEdgeSwipe" 0 } }
    
    "HH_Encryption" = @{ UserState=$true; 
        SlowCheck=$true; 
        Warning="Re-encrypting your drive requires manual setup via Windows Settings -> Privacy & Security -> Device Encryption."
        Apply={
            if ($SyncHash.SlowCheckCache) { $SyncHash.SlowCheckCache.Remove('HH_Encryption') }
            $vol = Get-CimInstance -ClassName Win32_EncryptableVolume -Namespace "root/cimv2/Security/MicrosoftVolumeEncryption" -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -eq "C:" };
            if ($vol -and ($vol.ProtectionStatus -eq 0)) { return }

            # The confirmation used to be a modal, ownerless WinForms MessageBox shown via
            # Dispatcher.Invoke FROM THE ENGINE THREAD - the exact pattern that froze the app in the
            # Debloat Center (invariants 1 + 2). It now happens on the UI thread BEFORE the job is
            # queued (Confirm-RiskyTasks in Ronin.ps1). This flag is defence in depth: no
            # confirmation recorded = no decryption, whatever path reached this Apply.
            if (-not $SyncHash.EncryptionConfirmed) { Log "Decryption NOT started: it was not confirmed. Tick the box and click Apply again to be asked."; return }
            $SyncHash.EncryptionConfirmed = $false   # one confirmation = one decryption
            Start-Process "manage-bde" -ArgumentList "-off C:" -NoNewWindow
            # The BitLocker watcher polls once a minute when idle; make it poll every 5 s for a while
            # so the "DO NOT RESTART - DECRYPTING [x%]" banner appears right away.
            $SyncHash.BdeFastUntil = (Get-Date).AddMinutes(5)
            Log "Decryption Initiated. Check Control Panel -> BitLocker for progress. DO NOT RESTART until 100% complete."
        };
        RevertNote="Windows can only turn drive encryption back on from Settings > Privacy & security > Device encryption, which Ronin has opened for you."
        Revert={ if ($SyncHash.SlowCheckCache) { $SyncHash.SlowCheckCache.Remove('HH_Encryption') }; Start-Process "ms-settings:deviceencryption" -ErrorAction SilentlyContinue }
        Check={
            # The Win32_EncryptableVolume (BitLocker) WMI provider takes ~5s on machines without
            # active encryption. Cache it for the session - status only changes via a multi-minute
            # decrypt the user starts (Apply clears the key) or a manual audit (clears the cache).
            if ($SyncHash.SlowCheckCache -and $SyncHash.SlowCheckCache.ContainsKey('HH_Encryption')) { return $SyncHash.SlowCheckCache['HH_Encryption'] }
            # At startup the BitLocker watcher thread is already running this same ~5 s query in
            # parallel and writes its answer into the cache - wait for it rather than paying twice.
            # Only before its first answer (BdeSeeded): after a manual audit clears the cache the
            # watcher may be in its 60 s idle sleep, so querying directly is faster then.
            if ($SyncHash.SlowCheckCache -and -not $SyncHash.BdeSeeded) {
                for ($i = 0; $i -lt 70; $i++) {
                    if ($SyncHash.SlowCheckCache.ContainsKey('HH_Encryption')) { return $SyncHash.SlowCheckCache['HH_Encryption'] }
                    Start-Sleep -Milliseconds 100
                }
            }
            $s = Get-CimInstance -ClassName Win32_EncryptableVolume -Namespace "root/cimv2/Security/MicrosoftVolumeEncryption" -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -eq "C:" };
            $r = if (!$s) { $true } else { ($s.ProtectionStatus -eq 0) }
            if ($SyncHash.SlowCheckCache) { $SyncHash.SlowCheckCache['HH_Encryption'] = $r }
            return $r
        }
    }
    
    # 8.0 Shares MenuShowDelay with Sys_MenuDelay. Undoing this no longer resets the menu delay while
    # "Instant Menu Delay" is applied (that silently undid the System Core tweak), and
    # WaitToKillAppTimeout comes back as it was - Windows 11 has no such value by default, and the
    # old revert wrote "5000", a setting the PC never had.
    "HH_TouchResponse" = @{ Shares="Sys_MenuDelay"
        Apply={ Save-RegOriginal "HH_TouchResponse.Wait" "HKCU:\Control Panel\Desktop" "WaitToKillAppTimeout"; Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" "0" "String"; Set-Reg "HKCU:\Control Panel\Desktop" "WaitToKillAppTimeout" "2000" "String" }
        Revert={
            if (-not (Test-AppliedMark "Sys_MenuDelay")) { Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" "400" "String" }
            if (-not (Restore-RegOriginal "HH_TouchResponse.Wait" "HKCU:\Control Panel\Desktop" "WaitToKillAppTimeout")) { Remove-Reg "HKCU:\Control Panel\Desktop" "WaitToKillAppTimeout" }
        }
        Check={ $c1 = Test-Reg-Read "HKCU:\Control Panel\Desktop" "MenuShowDelay" "0"; $c2 = Test-Reg-Read "HKCU:\Control Panel\Desktop" "WaitToKillAppTimeout" "2000"; return ($c1 -and $c2) } }
    
    "HH_TouchKeyboard" = @{ UserState=$true; 
        Apply={ Set-Service "TabletInputService" -StartupType Automatic; Start-Service "TabletInputService" -ErrorAction SilentlyContinue }
        Revert={ Set-Service "TabletInputService" -StartupType Manual; Stop-Service "TabletInputService" -Force -ErrorAction SilentlyContinue }
        Check={ (Get-Service "TabletInputService" -ErrorAction SilentlyContinue).Status -eq "Running" } 
    }
    
    # 8.0: the Check used to return TRUE whenever the GameBarPresenceWriter service was absent -
    # and on current builds it is not a service at all (it is launched on demand), so the tweak
    # showed ON for everyone, applied or not. It now mirrors Apply: the AppCaptureEnabled value
    # always, plus "not running" only where the service exists. Revert restores the recorded value.
    "HH_GameBarWriter" = @{
        Apply={ Save-RegOriginal "HH_GameBarWriter.AppCapture" "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled"; Stop-Service "GameBarPresenceWriter" -Force -ErrorAction SilentlyContinue; Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0 }
        Revert={
            if (-not (Restore-RegOriginal "HH_GameBarWriter.AppCapture" "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled")) { Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 1 }
            if (Get-Service "GameBarPresenceWriter" -ErrorAction SilentlyContinue) { Set-Service "GameBarPresenceWriter" -StartupType Manual -ErrorAction SilentlyContinue; Start-Service "GameBarPresenceWriter" -ErrorAction SilentlyContinue }
        }
        Check={ $c1 = Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0; $s = Get-Service "GameBarPresenceWriter" -ErrorAction SilentlyContinue; if (!$s) { return $c1 }; return ($c1 -and $s.Status -ne "Running") }
    }
    
    # Vendor launcher services. Apply must STOP the service as well as demote it: Check requires
    # Status -ne Running, so demoting alone reported "APPLY ran but Check still reports
    # not-applied" until the next reboot. Revert restores the startup type recorded at Apply -
    # a blanket "Automatic" would be a change, not a revert, on machines that shipped it Manual.
    "HH_Asus_AC" = @{
        Apply={
            $s = Get-Service "ArmouryCrateService" -ErrorAction SilentlyContinue
            if (-not $s) { return }
            Save-OriginalState "HH_Asus_AC.StartType" $s.StartType
            Set-Service "ArmouryCrateService" -StartupType Manual
            Stop-Service "ArmouryCrateService" -Force -ErrorAction SilentlyContinue
        }
        Revert={
            $s = Get-Service "ArmouryCrateService" -ErrorAction SilentlyContinue
            if (-not $s) { return }
            $orig = Get-OriginalState "HH_Asus_AC.StartType"
            if ($orig -notin @("Automatic","Manual","Disabled")) { $orig = "Automatic" }
            Set-Service "ArmouryCrateService" -StartupType $orig
            if ($orig -eq "Automatic") { Start-Service "ArmouryCrateService" -ErrorAction SilentlyContinue }
            Clear-OriginalState "HH_Asus_AC.StartType"
        }
        Check={ $s=Get-Service "ArmouryCrateService" -ErrorAction SilentlyContinue; if ($s) { return ($s.StartType -ne "Automatic" -and $s.Status -ne "Running") } return $false }
    }
    
    "HH_Legion_Space" = @{
        SlowCheck=$true;
        Apply={
            if ($SyncHash.SlowCheckCache) { $SyncHash.SlowCheckCache.Remove('HH_Legion_Space') }
            # Record the auto-start command lines BEFORE deleting them. They vary by Legion Space
            # version and install path, so they can only come back from what this machine had.
            $r1 = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue).LegionSpace
            $r2 = (Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue).LegionSpace
            if ($r1) { Save-OriginalState "HH_Legion_Space.RunHKLM" $r1 }
            if ($r2) { Save-OriginalState "HH_Legion_Space.RunHKCU" $r2 }
            Disable-Task "\" "LSDaemon"
            Remove-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" "LegionSpace"
            Remove-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" "LegionSpace"
        }
        Revert={
            if ($SyncHash.SlowCheckCache) { $SyncHash.SlowCheckCache.Remove('HH_Legion_Space') }
            Enable-Task "\" "LSDaemon"
            # Previously this re-enabled the task ONLY and silently left Legion Space's auto-start
            # entries deleted - an incomplete revert that never came back.
            $o1 = Get-OriginalState "HH_Legion_Space.RunHKLM"
            $o2 = Get-OriginalState "HH_Legion_Space.RunHKCU"
            if ($o1) { Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" "LegionSpace" $o1 "String"; Clear-OriginalState "HH_Legion_Space.RunHKLM" }
            if ($o2) { Set-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" "LegionSpace" $o2 "String"; Clear-OriginalState "HH_Legion_Space.RunHKCU" }
        }
        Check={
            # Get-ScheduledTask is ~0.5s (slow on machines without the task); cache per session.
            if ($SyncHash.SlowCheckCache -and $SyncHash.SlowCheckCache.ContainsKey('HH_Legion_Space')) { return $SyncHash.SlowCheckCache['HH_Legion_Space'] }
            # Fast path for every non-Lenovo PC: Get-ScheduledTask takes ~0.5 s to report a task that
            # doesn't exist. The scheduler's own registry cache answers "is LSDaemon registered?"
            # instantly; absent task = $false, exactly what the full check returns in that case.
            if (-not (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache\Tree\LSDaemon")) {
                if ($SyncHash.SlowCheckCache) { $SyncHash.SlowCheckCache['HH_Legion_Space'] = $false }
                return $false
            }
            $t = Get-ScheduledTask -TaskName "LSDaemon" -ErrorAction SilentlyContinue; $r1 = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue).LegionSpace; $r2 = (Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue).LegionSpace
            $r = if ($t) { ($t.State -eq "Disabled" -and $r1 -eq $null -and $r2 -eq $null) } else { $false }
            if ($SyncHash.SlowCheckCache) { $SyncHash.SlowCheckCache['HH_Legion_Space'] = $r }
            return $r
        }
    }
    
    "HH_Msi_Center" = @{
        Apply={
            $s = Get-Service "MSI_Central_Service" -ErrorAction SilentlyContinue
            if (-not $s) { return }
            Save-OriginalState "HH_Msi_Center.StartType" $s.StartType
            Set-Service "MSI_Central_Service" -StartupType Manual
            Stop-Service "MSI_Central_Service" -Force -ErrorAction SilentlyContinue
        }
        Revert={
            $s = Get-Service "MSI_Central_Service" -ErrorAction SilentlyContinue
            if (-not $s) { return }
            $orig = Get-OriginalState "HH_Msi_Center.StartType"
            if ($orig -notin @("Automatic","Manual","Disabled")) { $orig = "Automatic" }
            Set-Service "MSI_Central_Service" -StartupType $orig
            # Only restart it if it was an auto-start service. The old code always started it,
            # so a revert could leave a service running that had never been running.
            if ($orig -eq "Automatic") { Start-Service "MSI_Central_Service" -ErrorAction SilentlyContinue }
            Clear-OriginalState "HH_Msi_Center.StartType"
        }
        Check={ $s = Get-Service "MSI_Central_Service" -ErrorAction SilentlyContinue; if ($s) { return ($s.StartType -eq "Manual" -and $s.Status -ne "Running") } return $false }
    }
    
    "HH_VMP" = @{ UserState=$true; 
        Reboot=$true; SlowCheck=$true; 
        Apply={ 
            if (Test-BitLocker) { Log "SAFEGUARD: Skipping VMP tweak to prevent BitLocker Boot Loop."; return }
            Disable-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform" -NoRestart -ErrorAction SilentlyContinue 
        }; 
        Revert={ Enable-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform" -NoRestart -ErrorAction SilentlyContinue }; 
        Check={ (Get-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform" -ErrorAction SilentlyContinue).State -eq "Disabled" } 
    }
    
    "HH_CompactOS" = @{ UserState=$true; LocaleText=$true; 
        SlowCheck=$true; 
        Apply={ [void](Invoke-RoninProcess "compact" "/CompactOS:always" 120) }   # can take many minutes on handheld storage: keeps the engine beat
        Revert={ [void](Invoke-RoninProcess "compact" "/CompactOS:never" 120) }
        Check={ [bool]((compact /CompactOS:query | Out-String) -match "is in the Compact state") }
    }
    
    "HH_HiberReduced" = @{ UserState=$true; 
        SlowCheck=$true; 
        Apply={ powercfg /h /type reduced }
        Revert={ powercfg /h /type full }
        Check={ (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "HiberFileType" -ErrorAction SilentlyContinue).HiberFileType -eq 2 } 
    }

    "HH_BoostMode_AC" = @{ SlowCheck=$true; Apply={ param($v)
            # Record this machine's original value BEFORE changing it (restored exactly on Revert).
            Save-PowerOriginal "HH_BoostMode_AC" sub_processor be337238-0d82-4146-a960-4f3749d470c7
            powercfg /setacvalueindex scheme_current sub_processor be337238-0d82-4146-a960-4f3749d470c7 $v; powercfg /setactive scheme_current }; Revert={ Restore-PowerOriginal "HH_BoostMode_AC" sub_processor be337238-0d82-4146-a960-4f3749d470c7 $null $null 'AC' }; Check={ $v = Get-CpuBoostMode "AC"; if ($v -gt 3) { $v = switch ($v) { 4 {3} 5 {2} 6 {3} default {3} } }; return $v } }
    "HH_BoostMode_DC" = @{ SlowCheck=$true; Apply={ param($v)
            # Record this machine's original value BEFORE changing it (restored exactly on Revert).
            Save-PowerOriginal "HH_BoostMode_DC" sub_processor be337238-0d82-4146-a960-4f3749d470c7
            powercfg /setdcvalueindex scheme_current sub_processor be337238-0d82-4146-a960-4f3749d470c7 $v; powercfg /setactive scheme_current }; Revert={ Restore-PowerOriginal "HH_BoostMode_DC" sub_processor be337238-0d82-4146-a960-4f3749d470c7 $null $null 'DC' }; Check={ $v = Get-CpuBoostMode "DC"; if ($v -gt 3) { $v = switch ($v) { 4 {3} 5 {2} 6 {3} default {3} } }; return $v } }
    
    # 5-TIER SHOGUN EPP MATH (0 = 0, 1 = 33, 2 = 50, 3 = 85, 4 = 100)
    "HH_EPP_AC" = @{ SlowCheck=$true; Apply={ param($v)
            # Record this machine's original value BEFORE changing it (restored exactly on Revert).
            Save-PowerOriginal "HH_EPP_AC" sub_processor 36687f9e-e3a5-4dbf-b1dc-15eb381c6863
            $epp = switch($v){0{0}1{33}2{50}3{85}4{100}Default{50}}; powercfg /setacvalueindex scheme_current sub_processor 36687f9e-e3a5-4dbf-b1dc-15eb381c6863 $epp; powercfg /setactive scheme_current }; Revert={ Restore-PowerOriginal "HH_EPP_AC" sub_processor 36687f9e-e3a5-4dbf-b1dc-15eb381c6863 $null $null 'AC' }; Check={ $val=(Get-EPP-Value "AC"); if($val -le 10){0}elseif($val -le 40){1}elseif($val -le 60){2}elseif($val -le 90){3}else{4} } }
    "HH_EPP_DC" = @{ SlowCheck=$true; Apply={ param($v)
            # Record this machine's original value BEFORE changing it (restored exactly on Revert).
            Save-PowerOriginal "HH_EPP_DC" sub_processor 36687f9e-e3a5-4dbf-b1dc-15eb381c6863
            $epp = switch($v){0{0}1{33}2{50}3{85}4{100}Default{50}}; powercfg /setdcvalueindex scheme_current sub_processor 36687f9e-e3a5-4dbf-b1dc-15eb381c6863 $epp; powercfg /setactive scheme_current }; Revert={ Restore-PowerOriginal "HH_EPP_DC" sub_processor 36687f9e-e3a5-4dbf-b1dc-15eb381c6863 $null $null 'DC' }; Check={ $val=(Get-EPP-Value "DC"); if($val -le 10){0}elseif($val -le 40){1}elseif($val -le 60){2}elseif($val -le 90){3}else{4} } }

    # --- ADVANCED ---
    "Adv_InputLatency" = @{ Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Kbdclass\Parameters" "KeyboardDataQueueSize" 50 }; Revert={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Kbdclass\Parameters" "KeyboardDataQueueSize" 100 }; Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Services\Kbdclass\Parameters" "KeyboardDataQueueSize" 50 } }
    "Adv_Priority" = @{ Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 38 }; Revert={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 2 }; Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 38 } }
    
    "Adv_Storage" = @{ 
        SlowCheck=$true; 
        Apply={
            # fsutil only writes these two FileSystem values, so recording them captures the original.
            Save-RegOriginal "Adv_Storage.8dot3" "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisable8dot3NameCreation"
            Save-RegOriginal "Adv_Storage.LastAccess" "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisableLastAccessUpdate"
            fsutil behavior set disable8dot3 1; fsutil behavior set disablelastaccess 1
        }
        # Old Revert used 0/0 = "create 8.3 names on every volume" + "user-managed, update last
        # access on every read": both AWAY from the Windows defaults (2 = per-volume, 2 = system-
        # managed), costing NTFS performance. Restores the recorded values; true defaults otherwise.
        Revert={
            if (-not (Restore-RegOriginal "Adv_Storage.8dot3" "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisable8dot3NameCreation")) { fsutil behavior set disable8dot3 2 }
            if (-not (Restore-RegOriginal "Adv_Storage.LastAccess" "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisableLastAccessUpdate")) { fsutil behavior set disablelastaccess 2 }
        }
        Check={ $c1 = Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisable8dot3NameCreation" 1; $la = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "NtfsDisableLastAccessUpdate" -ErrorAction SilentlyContinue).NtfsDisableLastAccessUpdate; return ($c1 -and ($null -ne $la) -and (($la -band 1) -eq 1)) }
    }
    
    "Adv_UltPower" = @{ UserState=$true; 
        SlowCheck=$true; 
        # The old Apply duplicated the Ultimate Performance template (Windows gives the copy a NEW
        # random GUID) and then activated the TEMPLATE GUID, which usually isn't an installed plan -
        # so activation failed, Check (looking for the template GUID) reported not-applied, and
        # every retry added another "Ultimate Performance" plan to Power Options. Now: reuse the
        # plan Ronin created before, else duplicate ONCE and activate the GUID Windows returned.
        # GUIDs are parsed with a regex, so this works in any display language.
        Apply={
            $tmpl = "e9a42b02-d5df-448d-aa00-03f14749eb61"
            $cur = powercfg /getactivescheme | Out-String
            if ($cur -match '([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})') { Save-OriginalState "Adv_UltPower.Prev" $Matches[1] }
            $list = powercfg /list | Out-String
            $target = $null
            if ($list -match $tmpl) { $target = $tmpl }
            else {
                $mine = Get-OriginalState "Adv_UltPower.Scheme"
                if ($mine -and $list -match $mine) { $target = $mine }
                else {
                    $dup = powercfg -duplicatescheme $tmpl | Out-String
                    if ($dup -match '([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})') {
                        $target = $Matches[1]
                        # Clear-then-save: this marker is deliberately never cleared on revert, so
                        # the plan is reused across apply/revert cycles instead of duplicated.
                        Clear-OriginalState "Adv_UltPower.Scheme"; Save-OriginalState "Adv_UltPower.Scheme" $target
                    } else { Log "  - Could not create the Ultimate Performance plan on this edition of Windows." }
                }
            }
            if ($target) { powercfg /setactive $target | Out-Null }
        }
        Revert={
            $prev = Get-OriginalState "Adv_UltPower.Prev"
            if (-not $prev) { $prev = "381b4222-f694-41f0-9685-ff5bb260df2e"; Log "  - No recorded previous plan; switching to Balanced." }
            powercfg /setactive $prev | Out-Null
            Clear-OriginalState "Adv_UltPower.Prev"
        }
        Check={
            $act = powercfg /getactivescheme | Out-String
            if ($act -match "e9a42b02-d5df-448d-aa00-03f14749eb61") { return $true }
            $mine = Get-OriginalState "Adv_UltPower.Scheme"
            return [bool]($mine -and $act -match $mine)
        }
    }
    
    "Adv_TimerOpt" = @{ UserState=$true; 
        Warning="Resets system timer to Windows Defaults (TSC). Resolves stutters in modern games."
        RevertNote="The platform clock is already at the Windows default, so there was nothing to undo."
        Reboot=$true; SlowCheck=$true; 
        Apply={
            # Record whether something had forced the platform clock, and to what, before removing it.
            $o = bcdedit /enum "{current}" | Out-String
            if ($o -match 'useplatformclock\s+(\S+)') { Save-OriginalState "Adv_TimerOpt" "V:$($Matches[1])" } else { Save-OriginalState "Adv_TimerOpt" "ABSENT" }
            bcdedit /deletevalue useplatformclock
        }
        # Old Revert ran "useplatformclock true" unconditionally - FORCING the HPET platform clock,
        # which Windows doesn't do by default and which adds input latency. Now it only puts back a
        # value that was actually there. Absent originally = already the Windows default.
        Revert={
            $orig = Get-OriginalState "Adv_TimerOpt"
            if ($orig -and $orig -ne "ABSENT") {
                # bcdedit prints Yes/No in the display language; anything not a "no" word means on.
                # \u00e3 = the a-tilde of Portuguese "nao": the shipped file has no BOM, so Windows PowerShell
                # reads it as ANSI and a literal non-ASCII letter would never match (ASCII-only lint).
                $on = ($orig.Substring(2) -notmatch '^(no|false|off|nein|non|nee|nej|nie|n\u00e3o)$')
                bcdedit /set useplatformclock $(if ($on) { "true" } else { "false" })
            } else { Log "  - Platform clock was already at the Windows default; nothing to restore." }
            Clear-OriginalState "Adv_TimerOpt"
        }
        Check={ $out = bcdedit /enum | Out-String; return ($out -notmatch "useplatformclock") } 
    }
    
    "Adv_MemComp" = @{ UserState=$true; SlowCheck=$true; Apply={ Enable-MMAgent -MemoryCompression }; Revert={ Disable-MMAgent -MemoryCompression }; Check={ (Get-MMAgent).MemoryCompression -eq $true } }
    
    "Adv_PageFile" = @{ UserState=$true; 
        Reboot=$true; SlowCheck=$true; 
        Apply={ try { $sys = Get-CimInstance Win32_ComputerSystem -EnableAllPrivileges -ErrorAction Stop; if($sys.AutomaticManagedPagefile){ $sys.AutomaticManagedPagefile=$false; $sys.Put() } } catch { Log "PageFile Apply failed: $($_.Exception.Message)" } }
        Revert={ try { $sys = Get-CimInstance Win32_ComputerSystem -EnableAllPrivileges -ErrorAction Stop; if(!$sys.AutomaticManagedPagefile){ $sys.AutomaticManagedPagefile=$true; $sys.Put() } } catch { Log "PageFile Revert failed: $($_.Exception.Message)" } }
        Check={ try { (Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).AutomaticManagedPagefile -eq $false } catch { $false } } 
    }
    
    "Adv_NetPower" = @{
        SlowCheck=$true;
        # Per adapter, skipping "Not Present" ghosts (an old Wi-Fi card / unplugged USB dongle still
        # registered with Windows). The old Check sampled only the FIRST adapter, which on the dev PC
        # is such a ghost - so the status described a device that doesn't exist, and one failing
        # adapter in the pipeline broke the whole Apply.
        Apply={
            if ($SyncHash.SlowCheckCache) { $SyncHash.SlowCheckCache.Remove('Adv_NetPower') }
            foreach ($ad in @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue)) {
                if ($ad.Status -eq 'Not Present') { continue }
                try { Set-NetAdapterPowerManagement -Name $ad.Name -AllowComputerToTurnOffDevice Disabled -ErrorAction Stop }
                catch { Log "  - $($ad.Name): power management not adjustable ($($_.Exception.Message))" }
            }
        }
        Revert={
            if ($SyncHash.SlowCheckCache) { $SyncHash.SlowCheckCache.Remove('Adv_NetPower') }
            foreach ($ad in @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue)) {
                if ($ad.Status -eq 'Not Present') { continue }
                try { Set-NetAdapterPowerManagement -Name $ad.Name -AllowComputerToTurnOffDevice Enabled -ErrorAction Stop } catch {}
            }
        }
        Check={
            # CIM-backed (~0.7s); cache per session.
            if ($SyncHash.SlowCheckCache -and $SyncHash.SlowCheckCache.ContainsKey('Adv_NetPower')) { return $SyncHash.SlowCheckCache['Adv_NetPower'] }
            # Applied = every PRESENT adapter we can read has "allow the computer to turn off this
            # device" switched off. Adapters that can't be queried are ignored; none readable = $false.
            $readable = 0; $allOff = $true
            foreach ($ad in @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue)) {
                if ($ad.Status -eq 'Not Present') { continue }
                try {
                    $pm = Get-NetAdapterPowerManagement -Name $ad.Name -ErrorAction Stop
                    $readable++
                    if ("$($pm.AllowComputerToTurnOffDevice)" -ne 'Disabled') { $allOff = $false }
                } catch {}
            }
            $r = ($readable -gt 0 -and $allOff)
            if ($SyncHash.SlowCheckCache) { $SyncHash.SlowCheckCache['Adv_NetPower'] = $r }
            return $r
        }
    }
    
    "Adv_PhotoViewer" = @{ 
        # Reverts by restoring the original file association, or deleting the key if Ronin
        # created it. Removing a "(default)" value is a silent no-op (see Sys_DupliDrive), so
        # the old revert left Photo Viewer associated forever.
        Apply={
            foreach ($ext in @(".jpg", ".png")) {
                $p = "HKCU:\Software\Classes\$ext"
                if (Test-Path $p) { $o = (Get-ItemProperty -Path $p -ErrorAction SilentlyContinue).'(default)'; Save-OriginalState "Adv_PhotoViewer$ext" "V:$o" }
                else { Save-OriginalState "Adv_PhotoViewer$ext" "ABSENT" }
                Set-Reg $p "(default)" "PhotoViewer.FileAssoc.Tiff" "String"
            }
        }
        Revert={
            foreach ($ext in @(".jpg", ".png")) {
                $p = "HKCU:\Software\Classes\$ext"
                $orig = Get-OriginalState "Adv_PhotoViewer$ext"
                if (-not $orig -or $orig -eq "ABSENT") { Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue }
                else { Set-Reg $p "(default)" ($orig.Substring(2)) "String" }
                Clear-OriginalState "Adv_PhotoViewer$ext"
            }
        }
        Check={ $v1 = Get-ItemProperty "HKCU:\Software\Classes\.jpg" -ErrorAction SilentlyContinue; $v2 = Get-ItemProperty "HKCU:\Software\Classes\.png" -ErrorAction SilentlyContinue; return ($v1.'(default)' -eq "PhotoViewer.FileAssoc.Tiff" -and $v2.'(default)' -eq "PhotoViewer.FileAssoc.Tiff") } 
    }
    
    "Adv_UTC" = @{ UserState=$true; Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" "RealTimeIsUniversal" 1 }; Revert={ Remove-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" "RealTimeIsUniversal" }; Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" "RealTimeIsUniversal" 1 } }
    "Adv_Printing" = @{ UserState=$true; Apply={ Stop-Service Spooler -Force; Set-Service Spooler -StartupType Disabled }; Revert={ Set-Service Spooler -StartupType Automatic; Start-Service Spooler }; Check={ $s = Get-Service Spooler -ErrorAction SilentlyContinue; if (!$s) { return $true }; return ($s.StartType -eq "Disabled" -and $s.Status -ne "Running") } }
    "Adv_ReservedStorage" = @{ UserState=$true; SlowCheck=$true; LocaleText=$true; Apply={ [void](Invoke-RoninProcess "dism" "/Online /Set-ReservedStorageState /State:Disabled" 30) }; Revert={ [void](Invoke-RoninProcess "dism" "/Online /Set-ReservedStorageState /State:Enabled" 30) }; Check={ [bool]((dism /online /Get-ReservedStorageState | Out-String) -match "is disabled") } }
    
    "Adv_WSL" = @{ UserState=$true; Reboot=$true; SlowCheck=$true; Apply={ Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux" -NoRestart -ErrorAction SilentlyContinue }; Revert={ Disable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux" -NoRestart -ErrorAction SilentlyContinue }; Check={ (Get-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux" -ErrorAction SilentlyContinue).State -eq "Enabled" } }
    "Adv_HyperV" = @{ UserState=$true; Reboot=$true; SlowCheck=$true; Apply={ Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V-All" -NoRestart -ErrorAction SilentlyContinue }; Revert={ Disable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V-All" -NoRestart -ErrorAction SilentlyContinue }; Check={ (Get-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V-All" -ErrorAction SilentlyContinue).State -eq "Enabled" } }

    # EXPERT: fully REMOVE the Recall optional feature (Microsoft's official uninstall path),
    # not just policy-disable it like Sys_Recall. More aggressive and less cleanly reversible.
    # No-op on builds where the feature isn't present (Check returns false).
    "Adv_RecallRemove" = @{ UserState=$true; Reboot=$true; SlowCheck=$true; Warning="Fully removes the Recall component (Disable-WindowsOptionalFeature). Re-adding it requires toggling this back on plus a reboot. The standard Privacy > Disable Recall policy is enough for most users."; Apply={ Disable-WindowsOptionalFeature -Online -FeatureName "Recall" -NoRestart -ErrorAction SilentlyContinue | Out-Null }; Revert={ Enable-WindowsOptionalFeature -Online -FeatureName "Recall" -NoRestart -ErrorAction SilentlyContinue | Out-Null }; Check={ $f = Get-WindowsOptionalFeature -Online -FeatureName "Recall" -ErrorAction SilentlyContinue; if (!$f) { return $false }; return ($f.State -ne "Enabled") } }

    # WPBT (Windows Platform Binary Table): firmware mechanism OEMs use to auto-inject
    # their software (e.g. Armoury Crate) into Windows at every boot, even clean installs.
    "Adv_WPBT" = @{ Reboot=$true; Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" "DisableWpbtExecution" 1 }; Revert={ Remove-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" "DisableWpbtExecution" }; Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" "DisableWpbtExecution" 1 } }

    # 8.0: legacy-game Windows features. UserState: games prompt people to add these themselves.
    # NetFx3's payload comes from Windows Update (Features on Demand) - if it can't download, Apply
    # simply fails verification and the summary says so. DirectPlay needs its parent LegacyComponents;
    # its original state is recorded so Revert only turns LegacyComponents off if Ronin turned it on.
    "Adv_NetFx3" = @{ UserState=$true; SlowCheck=$true
        Apply={ Enable-WindowsOptionalFeature -Online -FeatureName "NetFx3" -All -NoRestart -ErrorAction SilentlyContinue | Out-Null }
        Revert={ Disable-WindowsOptionalFeature -Online -FeatureName "NetFx3" -NoRestart -ErrorAction SilentlyContinue | Out-Null }
        Check={ (Get-WindowsOptionalFeature -Online -FeatureName "NetFx3" -ErrorAction SilentlyContinue).State -eq "Enabled" } }
    "Adv_DirectPlay" = @{ UserState=$true; SlowCheck=$true
        Apply={
            $lc = Get-WindowsOptionalFeature -Online -FeatureName "LegacyComponents" -ErrorAction SilentlyContinue
            if ($lc) { Save-OriginalState "Adv_DirectPlay.Legacy" "$($lc.State)" }
            Enable-WindowsOptionalFeature -Online -FeatureName "DirectPlay" -All -NoRestart -ErrorAction SilentlyContinue | Out-Null
        }
        Revert={
            Disable-WindowsOptionalFeature -Online -FeatureName "DirectPlay" -NoRestart -ErrorAction SilentlyContinue | Out-Null
            if ((Get-OriginalState "Adv_DirectPlay.Legacy") -eq "Disabled") { Disable-WindowsOptionalFeature -Online -FeatureName "LegacyComponents" -NoRestart -ErrorAction SilentlyContinue | Out-Null }
            Clear-OriginalState "Adv_DirectPlay.Legacy"
        }
        Check={ (Get-WindowsOptionalFeature -Online -FeatureName "DirectPlay" -ErrorAction SilentlyContinue).State -eq "Enabled" } }

    # =========================================================================================
    # --- DECLUTTER (8.0) ---
    # Declarative Spec tweaks (see Invoke-SpecApply in RoninCore): Check mirrors Apply by
    # construction and every original is recorded and restored. All are things the user can also
    # set in Settings, so all are UserState (Reset All only touches what Ronin itself applied).
    # Values never overlap an older tweak's values (two tweaks recording the same original would
    # undo each other) - e.g. Sys_StartAds already owns RotatingLockScreenOverlayEnabled.
    # =========================================================================================
    # Ads & suggestions
    "Dcl_StartRecs" = @{ UserState=$true; Explorer=$true
        Spec=@( @{ P="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; N="Start_IrisRecommendations"; V=0 } )
        Apply={ Invoke-SpecApply 'Dcl_StartRecs' }; Revert={ Invoke-SpecRevert 'Dcl_StartRecs' }; Check={ Test-Spec 'Dcl_StartRecs' } }
    "Dcl_SearchHighlights" = @{ UserState=$true; Explorer=$true
        Spec=@( @{ P="HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"; N="IsDynamicSearchBoxEnabled"; V=0 } )
        Apply={ Invoke-SpecApply 'Dcl_SearchHighlights' }; Revert={ Invoke-SpecRevert 'Dcl_SearchHighlights' }; Check={ Test-Spec 'Dcl_SearchHighlights' } }
    "Dcl_AccountNags" = @{ UserState=$true; Explorer=$true
        Spec=@( @{ P="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; N="Start_AccountNotifications"; V=0 } )
        Apply={ Invoke-SpecApply 'Dcl_AccountNags' }; Revert={ Invoke-SpecRevert 'Dcl_AccountNags' }; Check={ Test-Spec 'Dcl_AccountNags' } }
    "Dcl_SettingsTips" = @{ UserState=$true
        Spec=@(
            @{ P="HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; N="SubscribedContent-338393Enabled"; V=0 }
            @{ P="HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; N="SubscribedContent-353694Enabled"; V=0 }
            @{ P="HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; N="SubscribedContent-353696Enabled"; V=0 }
        )
        Apply={ Invoke-SpecApply 'Dcl_SettingsTips' }; Revert={ Invoke-SpecRevert 'Dcl_SettingsTips' }; Check={ Test-Spec 'Dcl_SettingsTips' } }
    "Dcl_WelcomeExp" = @{ UserState=$true
        Spec=@( @{ P="HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; N="SubscribedContent-310093Enabled"; V=0 } )
        Apply={ Invoke-SpecApply 'Dcl_WelcomeExp' }; Revert={ Invoke-SpecRevert 'Dcl_WelcomeExp' }; Check={ Test-Spec 'Dcl_WelcomeExp' } }
    "Dcl_LockTips" = @{ UserState=$true
        Spec=@( @{ P="HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; N="SubscribedContent-338387Enabled"; V=0 } )
        Apply={ Invoke-SpecApply 'Dcl_LockTips' }; Revert={ Invoke-SpecRevert 'Dcl_LockTips' }; Check={ Test-Spec 'Dcl_LockTips' } }
    "Dcl_SpotlightIcon" = @{ UserState=$true; Explorer=$true
        Spec=@( @{ P="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"; N="{2cc5ca98-6485-489a-920e-b3e88a6ccce3}"; V=1 } )
        Apply={ Invoke-SpecApply 'Dcl_SpotlightIcon' }; Revert={ Invoke-SpecRevert 'Dcl_SpotlightIcon' }; Check={ Test-Spec 'Dcl_SpotlightIcon' } }
    "Dcl_EdgeNags" = @{ UserState=$true
        Spec=@(
            @{ P="HKLM:\SOFTWARE\Policies\Microsoft\Edge"; N="HideFirstRunExperience"; V=1 }
            @{ P="HKLM:\SOFTWARE\Policies\Microsoft\Edge"; N="ShowRecommendationsEnabled"; V=0 }
            @{ P="HKLM:\SOFTWARE\Policies\Microsoft\Edge"; N="StartupBoostEnabled"; V=0 }
            @{ P="HKLM:\SOFTWARE\Policies\Microsoft\Edge"; N="BackgroundModeEnabled"; V=0 }
            @{ P="HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate"; N="CreateDesktopShortcutDefault"; V=0 }
            # (appended - Spec originals are keyed by index, so new rows only ever go at the end)
            @{ P="HKLM:\SOFTWARE\Policies\Microsoft\Edge"; N="ShowMicrosoftRewards"; V=0 }
            @{ P="HKLM:\SOFTWARE\Policies\Microsoft\Edge"; N="MicrosoftEdgeInsiderPromotionEnabled"; V=0 }
            @{ P="HKLM:\SOFTWARE\Policies\Microsoft\Edge"; N="DefaultBrowserSettingsCampaignEnabled"; V=0 }
        )
        Apply={ Invoke-SpecApply 'Dcl_EdgeNags' }; Revert={ Invoke-SpecRevert 'Dcl_EdgeNags' }; Check={ Test-Spec 'Dcl_EdgeNags' } }

    # Quality of life
    # 8.0 (pass 2): Settings > Personalization > Start > "Show recommended files in Start, recent files in File
    # Explorer, and items in Jump Lists". Explorer reads it at start-up (Jump Lists, Home).
    "Dcl_RecentItems" = @{ UserState=$true; Explorer=$true
        Spec=@( @{ P="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; N="Start_TrackDocs"; V=0 } )
        Apply={ Invoke-SpecApply 'Dcl_RecentItems' }; Revert={ Invoke-SpecRevert 'Dcl_RecentItems' }; Check={ Test-Spec 'Dcl_RecentItems' } }
    # 8.0 (pass 2): Settings > Printers & scanners > "Let Windows manage my default printer" OFF - Windows stops
    # switching the default to whichever printer you used last.
    "Dcl_DefaultPrinter" = @{ UserState=$true
        Spec=@( @{ P="HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows"; N="LegacyDefaultPrinterMode"; V=1 } )
        Apply={ Invoke-SpecApply 'Dcl_DefaultPrinter' }; Revert={ Invoke-SpecRevert 'Dcl_DefaultPrinter' }; Check={ Test-Spec 'Dcl_DefaultPrinter' } }
    "Dcl_BatteryPct" = @{ UserState=$true; Explorer=$true
        Spec=@( @{ P="HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"; N="IsBatteryPercentageEnabled"; V=1 } )
        Apply={ Invoke-SpecApply 'Dcl_BatteryPct' }; Revert={ Invoke-SpecRevert 'Dcl_BatteryPct' }; Check={ Test-Spec 'Dcl_BatteryPct' } }
    "Dcl_Scrollbars" = @{ UserState=$true
        Spec=@( @{ P="HKCU:\Control Panel\Accessibility"; N="DynamicScrollbars"; V=0 } )
        Apply={ Invoke-SpecApply 'Dcl_Scrollbars' }; Revert={ Invoke-SpecRevert 'Dcl_Scrollbars' }; Check={ Test-Spec 'Dcl_Scrollbars' } }
    # Both the user's own value and the sign-in screen's (.DEFAULT). Strings, as Windows stores them.
    "Dcl_NumLock" = @{ UserState=$true
        Spec=@(
            @{ P="HKCU:\Control Panel\Keyboard"; N="InitialKeyboardIndicators"; V="2"; T="String"; D="0" }
            @{ P="Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard"; N="InitialKeyboardIndicators"; V="2"; T="String"; D="2147483648" }
        )
        Apply={ Invoke-SpecApply 'Dcl_NumLock' }; Revert={ Invoke-SpecRevert 'Dcl_NumLock' }; Check={ Test-Spec 'Dcl_NumLock' } }
    "Dcl_FolderDiscovery" = @{ UserState=$true; Explorer=$true
        Spec=@( @{ P="HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell"; N="FolderType"; V="NotSpecified"; T="String" } )
        Apply={ Invoke-SpecApply 'Dcl_FolderDiscovery' }; Revert={ Invoke-SpecRevert 'Dcl_FolderDiscovery' }; Check={ Test-Spec 'Dcl_FolderDiscovery' } }
    "Dcl_LongPaths" = @{ UserState=$true
        Spec=@( @{ P="HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"; N="LongPathsEnabled"; V=1; D=0 } )
        Apply={ Invoke-SpecApply 'Dcl_LongPaths' }; Revert={ Invoke-SpecRevert 'Dcl_LongPaths' }; Check={ Test-Spec 'Dcl_LongPaths' } }
    "Dcl_VerboseLogon" = @{ UserState=$true
        Spec=@( @{ P="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"; N="VerboseStatus"; V=1 } )
        Apply={ Invoke-SpecApply 'Dcl_VerboseLogon' }; Revert={ Invoke-SpecRevert 'Dcl_VerboseLogon' }; Check={ Test-Spec 'Dcl_VerboseLogon' } }
    "Dcl_LogonBlur" = @{ UserState=$true
        Spec=@( @{ P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"; N="DisableAcrylicBackgroundOnLogon"; V=1 } )
        Apply={ Invoke-SpecApply 'Dcl_LogonBlur' }; Revert={ Invoke-SpecRevert 'Dcl_LogonBlur' }; Check={ Test-Spec 'Dcl_LogonBlur' } }

    # Windows Update (Settings-app values on every edition - see Set-WuPause in RoninCore).
    # No surprise restarts: an 18-hour manual active-hours window (08:00-02:00, Windows' maximum),
    # "Get me up to date" off (it restarts ASAP regardless of active hours), and restart
    # notifications on so a pending restart is announced instead of sprung.
    "Dcl_WU_NoRestart" = @{ UserState=$true
        Spec=@(
            @{ P="HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; N="SmartActiveHoursState"; V=0 }
            @{ P="HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; N="ActiveHoursStart"; V=8; D=8 }
            @{ P="HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; N="ActiveHoursEnd"; V=2; D=17 }
            @{ P="HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; N="IsExpedited"; V=0 }
            @{ P="HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; N="RestartNotificationsAllowed2"; V=1 }
        )
        Apply={ Invoke-SpecApply 'Dcl_WU_NoRestart' }; Revert={ Invoke-SpecRevert 'Dcl_WU_NoRestart' }; Check={ Test-Spec 'Dcl_WU_NoRestart' } }
    # Expires: a pause running out is the tweak doing what it said, not Windows undoing it - the
    # reset alert skips it and Invoke-ResetCheck quietly drops its ledger mark (Get-ExpiredTweaks).
    "Dcl_WU_Pause" = @{ UserState=$true; Expires=$true
        Apply={ Set-WuPause 'Dcl_WU_Pause' 35 }
        Revert={ Restore-WuPause 'Dcl_WU_Pause' }
        Check={ $d = Get-WuPauseDaysLeft (Read-WuPauseExpiry); return ($d -gt 0 -and $d -le 36) } }
    # Expert only. "Off" = a one-year pause plus a raised pause ceiling; Ronin reminds the user every
    # 30 days (Banner_Updates). Never touches update services or policies, so Settings' own
    # "Resume updates" button still turns updates back on instantly.
    "Dcl_WU_Off" = @{ UserState=$true; Expires=$true
        Apply={ Set-WuPause 'Dcl_WU_Off' 365 }
        Revert={ Restore-WuPause 'Dcl_WU_Off' }
        Check={ return ((Get-WuPauseDaysLeft (Read-WuPauseExpiry)) -gt 36) } }
}

$AutoMap = @{ "Sys_VisualFX"="Auto_Visuals"; "Sys_DeviceInstall"="Auto_Drivers"; "Sys_RemoteAssist"="Auto_Remote"; "Sys_Recall"="Auto_Recall"; "Game_HAGS"="Auto_Hags"; "Game_GameMode"="Auto_GameMode"; "Sys_SysRestore"="Auto_SysRestore"; "Sys_UAC"="Auto_UAC"; "HH_CoreIso"="Auto_CoreIso"; "Priv_Tele"="Auto_Tele"; "Priv_AdID"="Auto_AdID"; "Priv_Loc"="Auto_Loc"; "Priv_Wifi"="Auto_Wifi"; "Priv_Bing"="Auto_Bing"; "Priv_Widgets"="Auto_Widgets"; "Priv_Copilot"="Auto_Copilot"; "Game_PCIe"="Auto_PCIe"; "Game_VariBright"="Auto_VariBright"; "Game_DPST"="Auto_DPST"; "Sys_AutoBright"="Auto_Bright"; "Priv_ConsumerFeatures"="Auto_Consumer"; "Priv_WER"="Auto_WER"; "Sys_CpuOpt"="Auto_CpuOpt"; "Sys_StartAds"="Auto_StartAds"; "Priv_ActivityUpload"="Auto_Activity" }

# --- TWEAK DESCRIPTIONS ---
# Centralized hover-text for tweaks, surfaced by the InfoDojo panel. Keyed by control name.
# Entries whose control isn't found are harmlessly ignored, so this map is safe to extend.
$TweakTips = @{
    # System
    "Sys_VisualFX"          = "Turns off Windows animations, shadows, window-drag previews and Aero Peek for a snappier desktop. Keeps smooth fonts and thumbnails. Purely cosmetic; full effect after you sign out and back in."
    "Sys_DeviceInstall"     = "Stops Windows from auto-installing generic/older drivers over the ones you chose. Recommended for gaming rigs."
    "Sys_RemoteAssist"      = "Turns off Windows Remote Assistance, closing a remote-access surface you almost certainly don't use."
    "Sys_Recall"            = "Disables Windows Recall, the AI feature that screenshots your activity. Major privacy win on 24H2/25H2."
    "Sys_BackgroundMode"    = "Background apps. 'Force Disable' sets the Windows policy that stops Microsoft Store apps running in the background: saves battery and memory, but those apps can't sync or notify you until you open them. 'Default' leaves it to Windows."
    "Sys_SysRestore"        = "Turns OFF System Restore to save disk space and background cycles. WARNING: this also disables Ronin's own Auto-Backup restore points - leave unchecked unless storage is critical."
    "Sys_UAC"               = "Tunes User Account Control prompts. Lowering prompts is convenient but slightly less secure."
    "Sys_CpuOpt"            = "Applies CPU scheduling tweaks for better responsiveness under load."
    "Sys_StartAds"          = "Removes 'suggested' app ads and promotions from the Start Menu."
    "Sys_AutoBright"        = "Disables adaptive/automatic brightness so the screen stops changing on its own."
    "Btn_Debloat"           = "Scans the apps installed on THIS machine and opens a selectable removal menu - junk pre-selected, Xbox/Game Pass never pre-selected, nothing removed until you confirm."
    "Sys_SearchIndex"       = "Disables the Windows Search indexer service. Saves disk activity; search becomes slower."
    "Sys_MeetNow"           = "Removes the 'Meet Now' Skype shortcut from the taskbar/system tray."
    "Sys_Hibernation"       = "Turns hibernation OFF (powercfg /h off) to reclaim hiberfil.sys disk space. NOTE: the handheld Hot-Bag fix REQUIRES hibernation, so leave this unchecked if you use Hot-Bag."

    # Gaming / GPU
    "Game_HAGS"             = "Hardware-Accelerated GPU Scheduling - can reduce latency on modern GPUs. Test per-game; reboot required."
    "Game_GameMode"         = "Enables Windows Game Mode to prioritize the foreground game."
    "Game_PCIe"             = "Sets PCIe link power management to maximum performance (no downclocking the GPU bus)."
    "Game_VariBright"       = "Disables AMD VariBright, which dims the screen on battery and hurts visual consistency."
    "Game_DPST"             = "Disables Intel Display Power Saving (DPST/DRRS) that alters brightness/refresh to save power."
    "Game_NvidiaFlipMode"   = "Sets the same Windows display flag as 'Disable MPO' (the two boxes always change together). A common fix for flicker in windowed and borderless games on NVIDIA. Needs a restart."
    "Game_InterruptModeration" = "Adjusts GPU interrupt moderation. Advanced latency tuning."

    # Privacy
    "Priv_Tele"             = "Sets Windows telemetry to the minimum the OS allows. Stops most background data collection."
    "Priv_AdID"             = "Disables the per-user Advertising ID so apps can't build an ad profile of you."
    "Priv_Loc"             = "Turns off the system Location service."
    "Priv_Wifi"             = "Disables Wi-Fi Sense and automatic hotspot connection."
    "Priv_Bing"             = "Removes Bing/web results from Start Menu search, keeping it local-only and faster."
    "Priv_Widgets"          = "Disables the Widgets board (news/weather feed) and its background process."
    "Priv_Copilot"          = "Disables Windows Copilot AI integration and its taskbar button."
    "Priv_EdgeCopilot"      = "Blocks Edge's Copilot from reading the pages you browse and hides the Copilot chat icon. Pure Edge policy keys - fully reversible."
    "Priv_InkTyping"        = "Turns off 'Inking & typing personalization' (Settings > Privacy & security): Windows stops collecting your handwriting, typing and contact names to build a personal dictionary. Handwriting and text suggestions may get slightly less personal."
    "Priv_AIExtras"         = "Disables Paint's generative AI (Image Creator / Cocreator / Generative Fill) and Notepad's AI features (by policy), opts out of Office AI training, and hides the 'AI Components' Settings page. Registry-only and fully reversible."
    "Priv_ConsumerFeatures" = "Blocks 'consumer experiences' - the silent auto-installing of promoted apps and games."
    "Priv_WER"              = "Disables Windows Error Reporting uploads."
    "Priv_ActivityUpload"   = "Stops uploading your Activity/Timeline history to Microsoft's cloud."
    "Priv_StorageSense"     = "Turns OFF Windows Storage Sense (the automatic temp-file and recycle-bin cleanup), keeping cleanup fully manual."

    # Handheld
    "Game_ConsoleMode"      = "Console Mode: boots this PC straight into Steam Big Picture's controller UI at startup - a living-room console front-end on any hardware (desktop, laptop, or handheld). Fully reversible. (Requires Steam installed.)"
    "HH_CoreIso"            = "Toggles Core Isolation / Memory Integrity. OFF can improve game performance; ON is more secure. Auto-skipped if BitLocker is on."
    "HH_Encryption"         = "Decrypts your OS drive (BitLocker). CRITICAL: do not shut down until decryption hits 100% or you'll get a recovery screen."
    "HH_BoostMode_AC"       = "CPU boost behavior while PLUGGED IN (AC power). 'Aggressive' = max performance."
    "HH_BoostMode_DC"       = "CPU boost behavior while on BATTERY (DC power). Lower = longer battery life."
    "HH_EPP_AC"             = "Energy Performance Preference while PLUGGED IN. Lower value = favors performance."
    "HH_EPP_DC"             = "Energy Performance Preference while on BATTERY. Higher value = favors efficiency."
    "HH_TouchKeyboard"      = "Keeps the touch keyboard service running so it pops up reliably on handhelds/tablets."
    "HH_TouchResponse"      = "Reduces menu/UI delays for a snappier touch experience (includes System Core's 'Instant Menu Delay') and shortens how long shutdown waits for apps to close."
    "HH_VMP"                = "Toggles the Virtual Machine Platform feature. EXPERT: affects WSL/sandbox. Auto-skipped if BitLocker is on."
    "HH_UsbSuspend"         = "Stops Windows powering down USB ports to save energy. Fixes controllers, docks and hubs that randomly disconnect or fail to wake. Costs a small amount of battery life."
    "HH_HibernateBtn"       = "Hot-Bag Fix: makes the power button HIBERNATE instead of sleep. A sleeping handheld can wake up inside a bag and cook itself; a hibernated one cannot. Resume takes a few seconds longer."
    "HH_WakeTimers"         = "Blocks scheduled tasks and updates from waking the device on their own. Stops the 'it turned itself on in my bag' problem. Note: also blocks wake-to-run alarms and scheduled backups."
    "HH_Standby"            = "Disables Modern Standby's network connectivity while asleep, the usual cause of overnight battery drain. Push notifications and background sync won't arrive while it's asleep."
    "HH_WifiPower"          = "Stops the Wi-Fi adapter entering power-saving mode. Fixes lag spikes, high ping and dropouts in online games. Costs a little battery on the go."
    "HH_BtFix"              = "Keeps Bluetooth radios fully powered instead of selectively suspending them. Fixes stuttering audio and controllers that disconnect after idling. Slight battery cost."
    "HH_DeviceGuard"        = "EXPERT: turns off Device Guard / Credential Guard (deep virtualization-based security). Can noticeably help performance on handhelds but lowers protection against credential theft. Auto-skipped if BitLocker is on. Reboot required."
    "HH_GameBarWriter"      = "Stops the Game Bar Presence Writer service and background game recording. Frees CPU and memory. Game Bar overlay and manual clip capture stop working until reverted."
    "HH_CompactOS"          = "Compresses Windows system files in place to reclaim several GB on small handheld SSDs. Costs a tiny amount of CPU on file reads. Applying and reverting both take a while (this is normal)."
    "HH_EdgeSwipe"          = "Disables touchscreen edge swipes (the gestures that yank in the notification centre and task view). Stops accidental menus while gaming with a controller in hand."
    # These three demote the vendor's own launcher service. Say so plainly - on a handheld that
    # service can be what actually controls fan curves and TDP, and a vague "optimize" label
    # turned that into a hardware complaint instead of an informed choice.
    "HH_Asus_AC"            = "Stops the Armoury Crate service starting with Windows (it stays installed and opens when launched), freeing CPU and RAM. WARNING: on ASUS handhelds and laptops it can control fans, TDP and buttons - if those change, revert this. Revert restores the original startup type."
    "HH_Legion_Space"       = "Stops Legion Space starting with Windows (it stays installed and opens when launched). WARNING: on the Legion Go it can control TDP, fans and the button mapping - if performance or controls change, revert this. Revert restores its auto-start entries and daemon task."
    "HH_Msi_Center"         = "Stops the MSI Center M service starting with Windows (it stays installed and opens when you launch it). WARNING: on the MSI Claw it can control fans, TDP and the button mapping - if those change, revert this. Revert restores the original startup type."
    "HH_HiberReduced"       = "Shrinks hiberfil.sys to roughly half of RAM instead of full size, recovering 4-8 GB on a small SSD. Fast Startup keeps working; full hibernation of a completely loaded system may not fit."

    # Advanced
    "Adv_Printing"          = "Disables the Print Spooler service. EXPERT: only if you never print (closes a known attack surface)."
    "Adv_WSL"               = "Enables the Windows Subsystem for Linux. Optional developer feature; adds overhead. Reboot required."
    "Adv_HyperV"            = "Enables Hyper-V virtualization. Optional; can impact gaming latency. Reboot required."
    "Adv_RecallRemove"      = "EXPERT: fully REMOVES the Recall feature from Windows (not just policy-disabled). The standard 'Disable Recall' on the Privacy tab is enough for most people. Reboot required; re-adding needs this toggled back on."
    "Adv_WPBT"              = "Blocks the Windows Platform Binary Table - the firmware backdoor OEMs use to auto-install their software (Armoury Crate, etc.) into every Windows install. You bought the hardware; you decide what runs on it. Reversible; reboot required."
    "Adv_UTC"               = "Stores the hardware clock as UTC (useful for Linux dual-boot). May confuse Windows time on its own."
    "Adv_ReservedStorage"   = "Disables Windows Reserved Storage, reclaiming ~7GB. Updates may need that space temporarily."

    "Adv_NetFx3"            = "Adds the .NET Framework 3.5 runtime that many older games and tools need (the 'This app needs .NET Framework 3.5' prompt). Windows downloads it from Windows Update, so it needs internet and won't install while updates are paused or off. Revert removes it again."
    "Adv_DirectPlay"        = "Adds DirectPlay, the old networking component many 2000s-era games need to start (the 'An app on your PC needs DirectPlay' prompt). Revert removes it, and also turns Legacy Components back off if Ronin was the one that turned them on."

    # Declutter (8.0)
    "Dcl_StartRecs"         = "Turns off 'Show recommendations for tips, shortcuts, new apps, and more' in Start - the promoted apps and tips. Your recent files are left alone. Same switch as Settings > Personalization > Start."
    "Dcl_SearchHighlights"  = "Turns off search highlights - the daily doodles, trending searches and promos in the Start search box. Same switch as Settings > Privacy & security > Search permissions."
    "Dcl_AccountNags"       = "Stops the 'back up your PC' / 'sign in with a Microsoft account' nag badges on your profile picture in Start."
    "Dcl_SettingsTips"      = "Removes the 'suggested content' cards Windows shows inside the Settings app."
    "Dcl_WelcomeExp"        = "Stops the full-screen 'Welcome to Windows' / 'what's new' page that can appear after big updates."
    "Dcl_LockTips"          = "Stops tips, tricks and fun facts appearing on the lock screen. Your lock screen picture is unchanged."
    "Dcl_SpotlightIcon"     = "Hides the 'Learn about this picture' icon that Windows Spotlight puts on the desktop. Spotlight wallpapers keep rotating."
    "Dcl_EdgeNags"          = "Edge policies: no first-run pages, recommendation popups, Rewards offers, 'make Edge default' or Insider promos, or new desktop shortcuts. Edge stops preloading at sign-in and running after you close it. It then says 'Managed by your organization' (that only means policies are set)."
    "Dcl_RecentItems"       = "Stops Start, File Explorer's Home and Jump Lists showing the files you opened recently (Settings > Personalization > Start). Your files aren't touched; the lists just stay empty."
    "Dcl_DefaultPrinter"    = "Turns off 'Let Windows manage my default printer', so Windows stops switching your default to whichever printer you used last. The printer you choose stays the default."
    "Dcl_BatteryPct"        = "Shows the battery percentage next to the battery icon on the taskbar. Needs Windows 11 24H2 or newer; no effect on desktops."
    "Dcl_Scrollbars"        = "Keeps scrollbars visible instead of shrinking them to thin lines that only appear on hover. Same switch as Settings > Accessibility > Visual effects."
    "Dcl_NumLock"           = "Turns Num Lock on at the sign-in screen and after you sign in. Skip this on small laptops whose letter keys double as a number pad."
    "Dcl_FolderDiscovery"   = "Stops File Explorer guessing a folder's type from its contents (the reason big download folders open slowly as 'Pictures' or 'Music'). Applies to folders without a saved view of their own."
    "Dcl_LongPaths"         = "Lets apps that support it use file paths longer than 260 characters. Mostly helps developers, modders and deep game-mod folders. Harmless otherwise."
    "Dcl_VerboseLogon"      = "Shows what Windows is doing during startup, sign-in and shutdown ('Applying user settings...') instead of just 'Please wait'. Handy for spotting what makes boot slow."
    "Dcl_LogonBlur"         = "Shows the sign-in screen background sharp instead of blurred."
    "Dcl_WU_NoRestart"      = "Sets Windows Update's active hours to 08:00-02:00 (18 hours, the most Windows allows, set manually), turns off 'Get the latest updates as soon as they're available', and has Windows warn you before restarting. Updates still install; restarts just wait."
    "Dcl_WU_Pause"          = "Pauses Windows Update for 5 weeks (35 days, Windows' own maximum) using the same pause as Settings > Windows Update. 'Resume updates' in Settings still works. When the pause ends, updates resume by themselves."
    "Dcl_WU_Off"            = "EXPERT: stops Windows Update for a year by extending Windows' own pause (no services or policies are touched, so 'Resume updates' in Settings always turns it back on). You'll miss security fixes while it's off - Ronin reminds you every 30 days."
    "Btn_StartupApps"       = "See every app that starts with Windows and switch each one on or off. Same switch as Task Manager's Startup tab - nothing is uninstalled or deleted."
}

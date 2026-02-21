# --- PROJECT RONIN: TWEAK DATABASE v7.0.0 (STANDARDIZED) ---
# BASE: Core v6.5.92 // TITANIUM MASTER v6.5.95
# STATUS: SECURITY FRIENDLY // EXTERNAL RELEASE CANDIDATE
# UPDATE: REMOVED "The Vaccine" (Boot-time Sanitation) to resolve AV Flagging.
# UPDATE: Sys_SysRestore normalized to use standard WMI/CIM cmdlets instead of Policy Lockdown.
# PRIME DIRECTIVE: NO-REFACTOR (Stability & Density Guaranteed)

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

# --- CRITICAL STABILITY: BOOT-TIME SANITATION (THE VACCINE) ---
# DELETED for v7.0 to resolve Heuristic AV Flagging.
# Logic previously targeting IoPageLockLimit, NtfsMemoryUsage, and IoPriority removed.

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
            # STANDARDIZED v7.0: Switched from Policy Lockdown to Standard Management
            Disable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
            Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" "DisableSR" 1 
        }
        Revert={ 
            # CLEANUP: Scouring old Policy keys to ensure standard behavior
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

    "Sys_ExplorerOpen" = @{ Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "LaunchTo" 1 }; Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "LaunchTo" 2 }; Check={ Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "LaunchTo" 1 } }
    "Sys_ShowExt" = @{ Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 0 }; Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 1 }; Check={ Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 0 } }
    "Sys_ShowHidden" = @{ Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 1 }; Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 2 }; Check={ Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 1 } }
    "Sys_Seconds" = @{ Apply={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSecondsInSystemClock" 1 }; Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSecondsInSystemClock" 0 }; Check={ Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSecondsInSystemClock" 1 } }
    
    "Sys_LockScreen" = @{ Apply={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" "NoLockScreen" 1 }; Revert={ Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" "NoLockScreen" }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" "NoLockScreen" 1 } }
    "Sys_UAC" = @{ Apply={ Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "ConsentPromptBehaviorAdmin" 0 }; Revert={ Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "ConsentPromptBehaviorAdmin" 5 }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" "ConsentPromptBehaviorAdmin" 0 } }
    
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
    
    "Sys_Recall" = @{ Apply={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" 1 }; Revert={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" 0 }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" 1 } }
    
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
        Apply={ powercfg /setacvalueindex scheme_current 7516b95f-f776-4464-8c53-06167f40cc99 FBD9AA66-9553-4097-BA44-ED6E9D65EAB8 0; powercfg /setactive scheme_current }
        Revert={ powercfg /setacvalueindex scheme_current 7516b95f-f776-4464-8c53-06167f40cc99 FBD9AA66-9553-4097-BA44-ED6E9D65EAB8 1; powercfg /setactive scheme_current }
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
            $l=@("*Clipchamp*","*Spotify*","*Netflix*","*Disney*","*TikTok*","*CandyCrush*","*OutlookForWindows*");
            $appList = ($l -join "`n").Replace("*", "")
            $msg = "WARNING: This will permanently remove the following pre-installed apps:`n`n$appList`n`nPLUS: Microsoft OneDrive (Full Uninstall)`n`nAre you sure you want to proceed?"
            $result = [System.Windows.Forms.MessageBox]::Show($msg, "Confirm Bloatware Removal", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
            if ($result -eq "Yes") {
                foreach($a in $l){Get-AppxPackage $a|Remove-AppxPackage -ErrorAction SilentlyContinue};
                try {
                    Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
                    $od = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
                    if (!(Test-Path $od)) { $od = "$env:SystemRoot\System32\OneDriveSetup.exe" }
                    if (Test-Path $od) { Start-Process $od -ArgumentList "/uninstall" -Wait -NoNewWindow }
                } catch {}
            }
        }; 
        Check={ 
            $p = Get-AppxPackage *WindowsFeedbackHub* -ErrorAction SilentlyContinue
            $od1 = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
            $od2 = "$env:SystemRoot\System32\OneDriveSetup.exe"
            $hasOneDrive = (Test-Path $od1) -or (Test-Path $od2)
            return ($p -eq $null -and !$hasOneDrive)
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
            powercfg /setacvalueindex scheme_current sub_processor bc5038f7-23e0-4960-96da-33abaf5935ec 100
            powercfg /setactive scheme_current 
        }
        Revert={ 
            powercfg /setacvalueindex scheme_current sub_processor 893dee8e-2bef-41e0-89c6-b55d0929964c 5
            powercfg /setacvalueindex scheme_current sub_processor bc5038f7-23e0-4960-96da-33abaf5935ec 100
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

    # --- HANDHELD ---
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
    "HH_Standby" = @{ SlowCheck=$true; Apply={ powercfg /setacvalueindex scheme_current sub_none F15576E8-98B7-4186-B944-EAFA664402D9 0 }; Check={ $output = powercfg /getactivescheme; if ($output -match "([a-fA-F0-9-]{36})") { $guid = $matches[1] } else { return $false }; $q = powercfg /qh $guid sub_none F15576E8-98B7-4186-B944-EAFA664402D9 | Out-String; if ($q -match "Index:\s+(0x[0-9a-fA-F]+)") { return ([Convert]::ToInt32($matches[1], 16) -eq 0) } return $false } } 
    "HH_WifiPower" = @{ SlowCheck=$true; Apply={ $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\19cbb8fa-5279-450e-9fac-8a3d5fedd0c1\12bbebe6-58d6-4636-95bb-3217ef867c1a"; if(Test-Path $regPath){ Set-ItemProperty -Path $regPath -Name "Attributes" -Value 2 -Type DWord -Force }; powercfg /setacvalueindex scheme_current 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 0; powercfg /setdcvalueindex scheme_current 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 0; powercfg /setactive scheme_current }; Revert={ powercfg /setacvalueindex scheme_current 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 3; powercfg /setdcvalueindex scheme_current 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 3; powercfg /setactive scheme_current }; Check={ $output = powercfg /getactivescheme; if ($output -match "([a-fA-F0-9-]{36})") { $guid = $matches[1] } else { return $false }; $q = powercfg /qh $guid 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a | Out-String; if ($q -match "Index:\s+0x0*([0-9a-fA-F]+)") { return ([Convert]::ToInt32($matches[1], 16) -eq 0) } return $false } }
    "HH_BtFix" = @{ Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\BthPort\Parameters" "DisableSelectiveSuspend" 1 }; Revert={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\BthPort\Parameters" "DisableSelectiveSuspend" 0 }; Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Services\BthPort\Parameters" "DisableSelectiveSuspend" 1 } }
    "HH_CoreIso" = @{ Reboot=$true; Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" "Enabled" 0 }; Revert={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" "Enabled" 1 }; Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" "Enabled" 0 } }
    "HH_DeviceGuard" = @{ Reboot=$true; Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "LsaCfgFlags" 0; Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard" "EnableVirtualizationBasedSecurity" 0 }; Revert={ Remove-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "LsaCfgFlags"; Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard" "EnableVirtualizationBasedSecurity" }; Check={ $c1 = Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard" "EnableVirtualizationBasedSecurity" 0; $c2 = Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "LsaCfgFlags" 0; return ($c1 -and $c2) } }
    "HH_UsbSuspend" = @{ Apply={ powercfg /SETACVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b352172fdf33 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0; powercfg /SETDCVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b352172fdf33 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0; powercfg /setactive scheme_current }; Check={ $output = powercfg /getactivescheme; if ($output -match "([a-fA-F0-9-]{36})") { $guid = $matches[1] } else { return $false }; $q = powercfg /qh $guid 2a737441-1930-4402-8d77-b352172fdf33 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 | Out-String; if ($q -match "Index:\s+(0x[0-9a-fA-F]+)") { return ([Convert]::ToInt32($matches[1], 16) -eq 0) } return $false } }
    "HH_EdgeSwipe" = @{ Apply={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI" "AllowEdgeSwipe" 0 }; Revert={ Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI" "AllowEdgeSwipe" }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI" "AllowEdgeSwipe" 0 } }
    "HH_Encryption" = @{ SlowCheck=$true; Apply={ $vol = Get-CimInstance -ClassName Win32_EncryptableVolume -Namespace "root/cimv2/Security/MicrosoftVolumeEncryption" -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -eq "C:" }; if ($vol -and ($vol.ProtectionStatus -eq 0)) { return }; Start-Process "manage-bde" -ArgumentList "-off C:" -NoNewWindow }; Check={ $s = Get-CimInstance -ClassName Win32_EncryptableVolume -Namespace "root/cimv2/Security/MicrosoftVolumeEncryption" -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -eq "C:" }; if (!$s) { return $true }; return ($s.ProtectionStatus -eq 0) } }
    "HH_TouchResponse" = @{ Apply={ Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" "0" "String"; Set-Reg "HKCU:\Control Panel\Desktop" "WaitToKillAppTimeout" "2000" "String" }; Revert={ Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" "400" "String"; Set-Reg "HKCU:\Control Panel\Desktop" "WaitToKillAppTimeout" "5000" "String" }; Check={ $c1 = Test-Reg-Read "HKCU:\Control Panel\Desktop" "MenuShowDelay" "0"; $c2 = Test-Reg-Read "HKCU:\Control Panel\Desktop" "WaitToKillAppTimeout" "2000"; return ($c1 -and $c2) } }
    "HH_TouchKeyboard" = @{ Apply={ Set-Service "TabletInputService" -StartupType Automatic; Start-Service "TabletInputService" }; Check={ (Get-Service "TabletInputService" -ErrorAction SilentlyContinue).Status -eq "Running" } }
    "HH_GameBarWriter" = @{ Apply={ Stop-Service "GameBarPresenceWriter" -Force -ErrorAction SilentlyContinue; Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0 }; Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 1 }; Check={ $c1 = Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0; $s = Get-Service "GameBarPresenceWriter" -ErrorAction SilentlyContinue; if (!$s) { return $true }; return ($c1 -and $s.Status -ne "Running") } }
    "HH_Asus_AC" = @{ Apply={ Set-Service "ArmouryCrateService" -StartupType Manual }; Revert={ Set-Service "ArmouryCrateService" -StartupType Automatic }; Check={ $s=Get-Service "ArmouryCrateService" -ErrorAction SilentlyContinue; if ($s) { return ($s.StartType -ne "Automatic" -and $s.Status -ne "Running") } return $false } }
    "HH_Legion_Space" = @{ Apply={ Disable-Task "\" "LSDaemon"; Remove-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" "LegionSpace"; Remove-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" "LegionSpace" }; Revert={ Enable-Task "\" "LSDaemon" }; Check={ $t = Get-ScheduledTask -TaskName "LSDaemon" -ErrorAction SilentlyContinue; $r1 = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue).LegionSpace; $r2 = (Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue).LegionSpace; if ($t) { return ($t.State -eq "Disabled" -and $r1 -eq $null -and $r2 -eq $null) } return $false } }
    "HH_Msi_Center" = @{ Apply={ Set-Service "MSI_Central_Service" -StartupType Manual }; Check={ $s = Get-Service "MSI_Central_Service" -ErrorAction SilentlyContinue; if ($s) { return ($s.StartType -eq "Manual" -and $s.Status -ne "Running") } return $false } }
    "HH_VMP" = @{ Reboot=$true; SlowCheck=$true; Apply={ Disable-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform" -NoRestart }; Check={ (Get-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform").State -eq "Disabled" } }
    "HH_CompactOS" = @{ SlowCheck=$true; Apply={ Start-Process "compact" "/CompactOS:always" -Wait -NoNewWindow }; Check={ (compact /CompactOS:query) -match "is in the Compact state" } }
    "HH_HiberReduced" = @{ SlowCheck=$true; Apply={ powercfg /h /type reduced }; Check={ (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "HiberFileType" -ErrorAction SilentlyContinue).HiberFileType -eq 2 } }
    "HH_BoostMode" = @{ SlowCheck=$true; Apply={ param($v); powercfg /setacvalueindex scheme_current sub_processor be337238-0d82-4146-a960-4f3749d470c7 $v; powercfg /setactive scheme_current }; Check={ $v=2; try { $out = powercfg /qh scheme_current sub_processor be337238-0d82-4146-a960-4f3749d470c7 | Out-String; if($out -match "Index:\s+0x([0-9a-fA-F]+)"){ $v=[Convert]::ToInt32($matches[1],16) } } catch {}; return $v } }
    "HH_EPP_Slicer" = @{ SlowCheck=$true; Apply={ param($v); $eppValue = switch($v){0{0}1{33}2{50}3{85}Default{50}}; powercfg /setacvalueindex scheme_current sub_processor 36687f9e-e3a5-4dbf-b1dc-15eb381c6863 $eppValue; powercfg /setactive scheme_current }; Check={ $val = (Get-EPP-Value); if($val -le 10){0}elseif($val -le 40){1}elseif($val -le 60){2}else{3} } }

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
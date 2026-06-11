<#
.SYNOPSIS
    Project Ronin Tweak Database v7.3.1 - Declarative registry/service tweak definitions.

.DESCRIPTION
    Hashtable of all available system tweaks. Each entry has Apply, Revert, and Check
    scriptblocks. The same registry paths and values used here are documented at
    elevenforum.com and other reputable Windows administration sources, and mirror
    the operations performed by Microsoft's own Group Policy templates.

.NOTES
    Project: https://github.com/keiretrogaming/Project-Ronin
    License: MIT
#>

# --- PROJECT RONIN: TWEAK DATABASE v7.3.1 (SHOGUN EDITION) ---

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
            # Set min processor to 0% (deeper idle states, more efficient than Balanced default of 5%)
            powercfg /setacvalueindex scheme_current sub_processor 893dee8e-2bef-41e0-89c6-b55d0929964c 0
            powercfg /setdcvalueindex scheme_current sub_processor 893dee8e-2bef-41e0-89c6-b55d0929964c 0
            powercfg /setacvalueindex scheme_current sub_processor bc5038f7-23e0-4960-96da-33abaf5935ec 100
            powercfg /setdcvalueindex scheme_current sub_processor bc5038f7-23e0-4960-96da-33abaf5935ec 100
            powercfg /setactive scheme_current 
        }
        Revert={ 
            # Restore Windows Balanced plan defaults (min=5%, max=100%)
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
                if ([Convert]::ToInt32($matches[1], 16) -eq 0) { $minOK = $true }
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
        Revert={ Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsRunInBackground" }
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
    
    "Game_MouseAccel" = @{ 
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
    "Game_Sticky" = @{ Apply={ Set-Reg "HKCU:\Control Panel\Accessibility\StickyKeys" "Flags" "506" "String" }; Revert={ Set-Reg "HKCU:\Control Panel\Accessibility\StickyKeys" "Flags" "510" "String" }; Check={ Test-Reg-Read "HKCU:\Control Panel\Accessibility\StickyKeys" "Flags" "506" } }
    
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
            if ($p) { Set-Reg "$p\Interrupt Management\MessageSignaledInterruptProperties" "MSISupported" 1; Set-Reg "$p\Interrupt Management\Affinity Policy" "DevicePriority" 0 }
        }
        Revert={ $p = Get-GpuRegistryPath "NVIDIA|AMD"; if ($p) { Remove-Reg "$p\Interrupt Management\Affinity Policy" "DevicePriority"; Remove-Reg "$p\Interrupt Management\MessageSignaledInterruptProperties" "MSISupported" } }
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
        Warning="SAFEGUARD: Forces Windows default (Compression Enabled) for game stability."
        Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisableCompression" 0 }
        Revert={ Remove-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisableCompression" }
        Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisableCompression" 0 }
    }

    "Game_ScatterGather" = @{
        Apply={ Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device" -Name "ForcedPhysicalSectorSizeInBytes" -Value @("4096") -Type MultiString -Force -ErrorAction SilentlyContinue } 
        Revert={ Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device" -Name "ForcedPhysicalSectorSizeInBytes" -ErrorAction SilentlyContinue }
        Check={ 
            $path = "HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device"
            if (!(Test-Path $path)) { return $true }
            return !(Get-ItemProperty $path -Name "ForcedPhysicalSectorSizeInBytes" -ErrorAction SilentlyContinue)
        }
    }

    "Game_NtfsMemory" = @{ 
        Warning="SAFEGUARD: Forces Windows default pool size to prevent out-of-memory errors."
        Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsMemoryUsage" 2 } 
        Revert={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsMemoryUsage" 1 } 
        Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsMemoryUsage" 2 } 
    }
    
    "Game_IoPriority" = @{ 
        Warning="SAFEGUARD: Resets I/O priority to Windows default kernel management."
        Apply={ $p = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\I/O Priority"; if(Test-Path $p){ Remove-ItemProperty -Path $p -Name "IoPriority" -ErrorAction SilentlyContinue } } 
        Revert={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\I/O Priority" "IoPriority" 2 } 
        Check={ 
            $p = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\I/O Priority"
            if (!(Test-Path $p)) { return $true }
            return !(Get-ItemProperty $p -Name "IoPriority" -ErrorAction SilentlyContinue)
        } 
    }
    
    "Game_MPO" = @{ Reboot=$true; Apply={ Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" "OverlayTestMode" 5 }; Revert={ Remove-Reg "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" "OverlayTestMode" }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" "OverlayTestMode" 5 } }
    "Game_NvidiaFlipMode" = @{ Apply={ Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" "OverlayTestMode" 5 }; Revert={ Remove-Reg "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" "OverlayTestMode" }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" "OverlayTestMode" 5 } }
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
    "Priv_Tele" = @{ 
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
            try { Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0 } catch {}
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

    "Priv_AI_Telemetry" = @{ 
        SlowCheck=$true
        Warning="Disables 24H2/25H2 AI telemetry. Some tasks are system-protected and cannot be disabled; the tweak reports applied if at least one was successfully disabled."
        Apply={ 
            # Registry backstops run FIRST so the tweak is detectable even if task ops fail
            try { Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "TurnOffClickToDo" 1 } catch { Log "  - TurnOffClickToDo write failed: $($_.Exception.Message)" }
            try { Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "DisableInventory" 1 } catch { Log "  - DisableInventory write failed: $($_.Exception.Message)" }
            try { Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" 1 } catch {}
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
            Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "TurnOffClickToDo"
            Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "DisableInventory"
        }
        Check={ 
            # Tweak is "applied" if EITHER the registry backstop is set 
            # OR at least one task we tried to disable is now Disabled.
            # This is robust across 24H2/25H2 task path variations.
            if (Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" "TurnOffClickToDo" 1) { return $true }
            if (Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "DisableInventory" 1) { return $true }
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
        Warning="Feedback App removal is permanent. Revert only restores the DiagTrack service."
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

    "HH_WakeTimers" = @{ 
        Apply={ 
            try {
                & powercfg /setacvalueindex scheme_current sub_sleep bd3b7116-3b1b-43b5-b725-3003e2754d52 0 2>&1 | Out-Null
                & powercfg /setdcvalueindex scheme_current sub_sleep bd3b7116-3b1b-43b5-b725-3003e2754d52 0 2>&1 | Out-Null
                & powercfg /setactive scheme_current 2>&1 | Out-Null
            } catch { Log "  - WakeTimers Apply error: $($_.Exception.Message)" }
        }
        Revert={ 
            try {
                & powercfg /setacvalueindex scheme_current sub_sleep bd3b7116-3b1b-43b5-b725-3003e2754d52 1 2>&1 | Out-Null
                & powercfg /setdcvalueindex scheme_current sub_sleep bd3b7116-3b1b-43b5-b725-3003e2754d52 1 2>&1 | Out-Null
                & powercfg /setactive scheme_current 2>&1 | Out-Null
            } catch { Log "  - WakeTimers Revert error: $($_.Exception.Message)" }
        }; Check={ $output = powercfg /getactivescheme; if ($output -match "([a-fA-F0-9-]{36})") { $guid = $matches[1] } else { return $false }; $q = powercfg /q $guid 238c9fa8-0aad-41ed-83f4-97be242c8f20 bd3b7116-3b1b-43b5-b725-3003e2754d52 | Out-String; if ($q -match "Index:\s+(0x[0-9a-fA-F]+)") { $v = $matches[1]; if ($v -match "0x") { $v = [Convert]::ToInt32($v, 16) }; if ($v -eq 0) { return $true } } return $false } }
    
    "HH_Standby" = @{ 
        SlowCheck=$true
        Apply={ powercfg /setacvalueindex scheme_current sub_none F15576E8-98B7-4186-B944-EAFA664402D9 0; powercfg /setdcvalueindex scheme_current sub_none F15576E8-98B7-4186-B944-EAFA664402D9 0; powercfg /setactive scheme_current }
        Revert={ powercfg /setacvalueindex scheme_current sub_none F15576E8-98B7-4186-B944-EAFA664402D9 1; powercfg /setdcvalueindex scheme_current sub_none F15576E8-98B7-4186-B944-EAFA664402D9 1; powercfg /setactive scheme_current }
        Check={ $output = powercfg /getactivescheme; if ($output -match "([a-fA-F0-9-]{36})") { $guid = $matches[1] } else { return $false }; $q = powercfg /qh $guid sub_none F15576E8-98B7-4186-B944-EAFA664402D9 | Out-String; if ($q -match "Index:\s+(0x[0-9a-fA-F]+)") { return ([Convert]::ToInt32($matches[1], 16) -eq 0) } return $false } 
    } 
    
    "HH_WifiPower" = @{ SlowCheck=$true; Apply={ $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\19cbb8fa-5279-450e-9fac-8a3d5fedd0c1\12bbebe6-58d6-4636-95bb-3217ef867c1a"; if(Test-Path $regPath){ Set-ItemProperty -Path $regPath -Name "Attributes" -Value 2 -Type DWord -Force }; powercfg /setacvalueindex scheme_current 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 0; powercfg /setdcvalueindex scheme_current 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 0; powercfg /setactive scheme_current }; Revert={ powercfg /setacvalueindex scheme_current 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 3; powercfg /setdcvalueindex scheme_current 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a 3; powercfg /setactive scheme_current }; Check={ $output = powercfg /getactivescheme; if ($output -match "([a-fA-F0-9-]{36})") { $guid = $matches[1] } else { return $false }; $q = powercfg /qh $guid 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a | Out-String; if ($q -match "Index:\s+0x0*([0-9a-fA-F]+)") { return ([Convert]::ToInt32($matches[1], 16) -eq 0) } return $false } }
    "HH_BtFix" = @{ Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\BthPort\Parameters" "DisableSelectiveSuspend" 1 }; Revert={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\BthPort\Parameters" "DisableSelectiveSuspend" 0 }; Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Services\BthPort\Parameters" "DisableSelectiveSuspend" 1 } }
    
    "HH_CoreIso" = @{ 
        Reboot=$true; 
        Apply={ 
            if (Test-BitLocker) { Log "SAFEGUARD: Skipping Core Isolation tweak to prevent BitLocker Boot Loop."; return }
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" "Enabled" 0 
        }; 
        Revert={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" "Enabled" 1 }; 
        Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" "Enabled" 0 } 
    }
    
    "HH_DeviceGuard" = @{ 
        Reboot=$true; 
        Apply={ 
            if (Test-BitLocker) { Log "SAFEGUARD: Skipping Device Guard tweak to prevent BitLocker Boot Loop."; return }
            Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "LsaCfgFlags" 0; Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard" "EnableVirtualizationBasedSecurity" 0 
        }; 
        Revert={ Remove-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "LsaCfgFlags"; Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard" "EnableVirtualizationBasedSecurity" }; 
        Check={ $c1 = Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard" "EnableVirtualizationBasedSecurity" 0; $c2 = Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" "LsaCfgFlags" 0; return ($c1 -and $c2) } 
    }

    "HH_UsbSuspend" = @{ 
        Apply={ 
            try {
                $ac = & powercfg /SETACVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b352172fdf33 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>&1
                $dc = & powercfg /SETDCVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b352172fdf33 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0 2>&1
                $sa = & powercfg /setactive scheme_current 2>&1
                if ($LASTEXITCODE -ne 0) { Log "  - powercfg returned exit code $LASTEXITCODE" }
            } catch { Log "  - USB Suspend Apply error: $($_.Exception.Message)" }
        }
        Revert={ 
            try {
                & powercfg /SETACVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b352172fdf33 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1 2>&1 | Out-Null
                & powercfg /SETDCVALUEINDEX SCHEME_CURRENT 2a737441-1930-4402-8d77-b352172fdf33 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 1 2>&1 | Out-Null
                & powercfg /setactive scheme_current 2>&1 | Out-Null
            } catch { Log "  - USB Suspend Revert error: $($_.Exception.Message)" }
        }
        Check={ $output = powercfg /getactivescheme; if ($output -match "([a-fA-F0-9-]{36})") { $guid = $matches[1] } else { return $false }; $q = powercfg /qh $guid 2a737441-1930-4402-8d77-b352172fdf33 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 | Out-String; if ($q -match "Index:\s+(0x[0-9a-fA-F]+)") { return ([Convert]::ToInt32($matches[1], 16) -eq 0) } return $false } 
    }
    
    "HH_EdgeSwipe" = @{ Apply={ Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI" "AllowEdgeSwipe" 0 }; Revert={ Remove-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI" "AllowEdgeSwipe" }; Check={ Test-Reg-Read "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI" "AllowEdgeSwipe" 0 } }
    
    "HH_Encryption" = @{ 
        SlowCheck=$true; 
        Warning="Re-encrypting your drive requires manual setup via Windows Settings -> Privacy & Security -> Device Encryption."
        Apply={ 
            $vol = Get-CimInstance -ClassName Win32_EncryptableVolume -Namespace "root/cimv2/Security/MicrosoftVolumeEncryption" -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -eq "C:" }; 
            if ($vol -and ($vol.ProtectionStatus -eq 0)) { return }
            
            $msg = "CRITICAL WARNING: Decrypting your OS drive operates silently in the background.`n`nIf you restart your device BEFORE decryption reaches 100%, you WILL trigger a BitLocker Recovery Screen (Black Screen on Handhelds).`n`nDo you want to begin decryption?"
            $result = "No"
            
            if ($SyncHash -and $SyncHash.Window) {
                $result = $SyncHash.Window.Dispatcher.Invoke([System.Func[String]] {
                    return [System.Windows.Forms.MessageBox]::Show($msg, "BitLocker Warning", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning).ToString()
                })
            } else {
                $result = [System.Windows.Forms.MessageBox]::Show($msg, "BitLocker Warning", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning).ToString()
            }

            if ($result -eq "Yes") {
                Start-Process "manage-bde" -ArgumentList "-off C:" -NoNewWindow
                if ($SyncHash) { Log "Decryption Initiated. Check Control Panel -> BitLocker for progress. DO NOT RESTART until 100% complete." }
            } else {
                if ($SyncHash) { Log "Decryption Aborted." }
            }
        }; 
        Revert={ Start-Process "ms-settings:privacy" -NoNewWindow }
        Check={ 
            $s = Get-CimInstance -ClassName Win32_EncryptableVolume -Namespace "root/cimv2/Security/MicrosoftVolumeEncryption" -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -eq "C:" }; 
            if (!$s) { return $true }; 
            return ($s.ProtectionStatus -eq 0) 
        } 
    }
    
    "HH_TouchResponse" = @{ Apply={ Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" "0" "String"; Set-Reg "HKCU:\Control Panel\Desktop" "WaitToKillAppTimeout" "2000" "String" }; Revert={ Set-Reg "HKCU:\Control Panel\Desktop" "MenuShowDelay" "400" "String"; Set-Reg "HKCU:\Control Panel\Desktop" "WaitToKillAppTimeout" "5000" "String" }; Check={ $c1 = Test-Reg-Read "HKCU:\Control Panel\Desktop" "MenuShowDelay" "0"; $c2 = Test-Reg-Read "HKCU:\Control Panel\Desktop" "WaitToKillAppTimeout" "2000"; return ($c1 -and $c2) } }
    
    "HH_TouchKeyboard" = @{ 
        Apply={ Set-Service "TabletInputService" -StartupType Automatic; Start-Service "TabletInputService" -ErrorAction SilentlyContinue }
        Revert={ Set-Service "TabletInputService" -StartupType Manual; Stop-Service "TabletInputService" -Force -ErrorAction SilentlyContinue }
        Check={ (Get-Service "TabletInputService" -ErrorAction SilentlyContinue).Status -eq "Running" } 
    }
    
    "HH_GameBarWriter" = @{ 
        Apply={ Stop-Service "GameBarPresenceWriter" -Force -ErrorAction SilentlyContinue; Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0 }
        Revert={ Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 1; Set-Service "GameBarPresenceWriter" -StartupType Manual; Start-Service "GameBarPresenceWriter" -ErrorAction SilentlyContinue }
        Check={ $c1 = Test-Reg-Read "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0; $s = Get-Service "GameBarPresenceWriter" -ErrorAction SilentlyContinue; if (!$s) { return $true }; return ($c1 -and $s.Status -ne "Running") } 
    }
    
    "HH_Asus_AC" = @{ Apply={ Set-Service "ArmouryCrateService" -StartupType Manual }; Revert={ Set-Service "ArmouryCrateService" -StartupType Automatic }; Check={ $s=Get-Service "ArmouryCrateService" -ErrorAction SilentlyContinue; if ($s) { return ($s.StartType -ne "Automatic" -and $s.Status -ne "Running") } return $false } }
    
    "HH_Legion_Space" = @{ 
        Apply={ Disable-Task "\" "LSDaemon"; Remove-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" "LegionSpace"; Remove-Reg "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" "LegionSpace" }
        Revert={ Enable-Task "\" "LSDaemon" }
        Check={ $t = Get-ScheduledTask -TaskName "LSDaemon" -ErrorAction SilentlyContinue; $r1 = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue).LegionSpace; $r2 = (Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -ErrorAction SilentlyContinue).LegionSpace; if ($t) { return ($t.State -eq "Disabled" -and $r1 -eq $null -and $r2 -eq $null) } return $false } 
    }
    
    "HH_Msi_Center" = @{ 
        Apply={ Set-Service "MSI_Central_Service" -StartupType Manual }
        Revert={ Set-Service "MSI_Central_Service" -StartupType Automatic; Start-Service "MSI_Central_Service" -ErrorAction SilentlyContinue }
        Check={ $s = Get-Service "MSI_Central_Service" -ErrorAction SilentlyContinue; if ($s) { return ($s.StartType -eq "Manual" -and $s.Status -ne "Running") } return $false } 
    }
    
    "HH_VMP" = @{ 
        Reboot=$true; SlowCheck=$true; 
        Apply={ 
            if (Test-BitLocker) { Log "SAFEGUARD: Skipping VMP tweak to prevent BitLocker Boot Loop."; return }
            Disable-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform" -NoRestart -ErrorAction SilentlyContinue 
        }; 
        Revert={ Enable-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform" -NoRestart -ErrorAction SilentlyContinue }; 
        Check={ (Get-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform" -ErrorAction SilentlyContinue).State -eq "Disabled" } 
    }
    
    "HH_CompactOS" = @{ 
        SlowCheck=$true; 
        Apply={ Start-Process "compact" "/CompactOS:always" -Wait -NoNewWindow }
        Revert={ Start-Process "compact" "/CompactOS:never" -Wait -NoNewWindow }
        Check={ [bool]((compact /CompactOS:query | Out-String) -match "is in the Compact state") }
    }
    
    "HH_HiberReduced" = @{ 
        SlowCheck=$true; 
        Apply={ powercfg /h /type reduced }
        Revert={ powercfg /h /type full }
        Check={ (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -Name "HiberFileType" -ErrorAction SilentlyContinue).HiberFileType -eq 2 } 
    }

    "HH_BoostMode_AC" = @{ SlowCheck=$true; Apply={ param($v); powercfg /setacvalueindex scheme_current sub_processor be337238-0d82-4146-a960-4f3749d470c7 $v; powercfg /setactive scheme_current }; Check={ $v = Get-CpuBoostMode "AC"; if ($v -gt 3) { $v = switch ($v) { 4 {3} 5 {2} 6 {3} default {3} } }; return $v } }
    "HH_BoostMode_DC" = @{ SlowCheck=$true; Apply={ param($v); powercfg /setdcvalueindex scheme_current sub_processor be337238-0d82-4146-a960-4f3749d470c7 $v; powercfg /setactive scheme_current }; Check={ $v = Get-CpuBoostMode "DC"; if ($v -gt 3) { $v = switch ($v) { 4 {3} 5 {2} 6 {3} default {3} } }; return $v } }
    
    # 5-TIER SHOGUN EPP MATH (0 = 0, 1 = 33, 2 = 50, 3 = 85, 4 = 100)
    "HH_EPP_AC" = @{ SlowCheck=$true; Apply={ param($v); $epp = switch($v){0{0}1{33}2{50}3{85}4{100}Default{50}}; powercfg /setacvalueindex scheme_current sub_processor 36687f9e-e3a5-4dbf-b1dc-15eb381c6863 $epp; powercfg /setactive scheme_current }; Check={ $val=(Get-EPP-Value "AC"); if($val -le 10){0}elseif($val -le 40){1}elseif($val -le 60){2}elseif($val -le 90){3}else{4} } }
    "HH_EPP_DC" = @{ SlowCheck=$true; Apply={ param($v); $epp = switch($v){0{0}1{33}2{50}3{85}4{100}Default{50}}; powercfg /setdcvalueindex scheme_current sub_processor 36687f9e-e3a5-4dbf-b1dc-15eb381c6863 $epp; powercfg /setactive scheme_current }; Check={ $val=(Get-EPP-Value "DC"); if($val -le 10){0}elseif($val -le 40){1}elseif($val -le 60){2}elseif($val -le 90){3}else{4} } }

    # --- ADVANCED ---
    "Adv_InputLatency" = @{ Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Kbdclass\Parameters" "KeyboardDataQueueSize" 50 }; Revert={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Kbdclass\Parameters" "KeyboardDataQueueSize" 100 }; Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Services\Kbdclass\Parameters" "KeyboardDataQueueSize" 50 } }
    "Adv_Priority" = @{ Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 38 }; Revert={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 2 }; Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 38 } }
    
    "Adv_Storage" = @{ 
        SlowCheck=$true; 
        Apply={ fsutil behavior set disable8dot3 1; fsutil behavior set disablelastaccess 1 }
        Revert={ fsutil behavior set disable8dot3 0; fsutil behavior set disablelastaccess 0 }
        Check={ $c1 = Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" "NtfsDisable8dot3NameCreation" 1; $la = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "NtfsDisableLastAccessUpdate" -ErrorAction SilentlyContinue).NtfsDisableLastAccessUpdate; return ($c1 -and ($null -ne $la) -and (($la -band 1) -eq 1)) }
    }
    
    "Adv_UltPower" = @{ 
        SlowCheck=$true; 
        Apply={ powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61; powercfg /setactive e9a42b02-d5df-448d-aa00-03f14749eb61 }
        Revert={ powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e }
        Check={ [bool]((powercfg /getactivescheme | Out-String) -match "e9a42b02-d5df-448d-aa00-03f14749eb61") }
    }
    
    "Adv_TimerOpt" = @{ 
        Warning="Resets system timer to Windows Defaults (TSC). Resolves stutters in modern games."
        Reboot=$true; SlowCheck=$true; 
        Apply={ bcdedit /deletevalue useplatformclock }
        Revert={ bcdedit /set useplatformclock true }
        Check={ $out = bcdedit /enum | Out-String; return ($out -notmatch "useplatformclock") } 
    }
    
    "Adv_MemComp" = @{ SlowCheck=$true; Apply={ Enable-MMAgent -MemoryCompression }; Revert={ Disable-MMAgent -MemoryCompression }; Check={ (Get-MMAgent).MemoryCompression -eq $true } }
    
    "Adv_PageFile" = @{ 
        Reboot=$true; SlowCheck=$true; 
        Apply={ try { $sys = Get-CimInstance Win32_ComputerSystem -EnableAllPrivileges -ErrorAction Stop; if($sys.AutomaticManagedPagefile){ $sys.AutomaticManagedPagefile=$false; $sys.Put() } } catch { Log "PageFile Apply failed: $($_.Exception.Message)" } }
        Revert={ try { $sys = Get-CimInstance Win32_ComputerSystem -EnableAllPrivileges -ErrorAction Stop; if(!$sys.AutomaticManagedPagefile){ $sys.AutomaticManagedPagefile=$true; $sys.Put() } } catch { Log "PageFile Revert failed: $($_.Exception.Message)" } }
        Check={ try { (Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).AutomaticManagedPagefile -eq $false } catch { $false } } 
    }
    
    "Adv_NetPower" = @{ 
        SlowCheck=$true; 
        Apply={ Get-NetAdapter -Physical | Get-NetAdapterPowerManagement | Set-NetAdapterPowerManagement -AllowComputerToTurnOffDevice $false -ErrorAction SilentlyContinue }
        Revert={ Get-NetAdapter -Physical | Get-NetAdapterPowerManagement | Set-NetAdapterPowerManagement -AllowComputerToTurnOffDevice $true -ErrorAction SilentlyContinue }
        Check={ $a = Get-NetAdapter -Physical | Get-NetAdapterPowerManagement | Select -First 1; return ($a.AllowComputerToTurnOffDevice -eq $false) } 
    }
    
    "Adv_PhotoViewer" = @{ 
        Apply={ Set-Reg "HKCU:\Software\Classes\.jpg" "(default)" "PhotoViewer.FileAssoc.Tiff" "String"; Set-Reg "HKCU:\Software\Classes\.png" "(default)" "PhotoViewer.FileAssoc.Tiff" "String" }
        Revert={ Remove-ItemProperty -Path "HKCU:\Software\Classes\.jpg" -Name "(default)" -ErrorAction SilentlyContinue; Remove-ItemProperty -Path "HKCU:\Software\Classes\.png" -Name "(default)" -ErrorAction SilentlyContinue }
        Check={ $v1 = Get-ItemProperty "HKCU:\Software\Classes\.jpg" -ErrorAction SilentlyContinue; $v2 = Get-ItemProperty "HKCU:\Software\Classes\.png" -ErrorAction SilentlyContinue; return ($v1.'(default)' -eq "PhotoViewer.FileAssoc.Tiff" -and $v2.'(default)' -eq "PhotoViewer.FileAssoc.Tiff") } 
    }
    
    "Adv_UTC" = @{ Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" "RealTimeIsUniversal" 1 }; Revert={ Remove-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" "RealTimeIsUniversal" }; Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" "RealTimeIsUniversal" 1 } }
    "Adv_Printing" = @{ Apply={ Stop-Service Spooler -Force; Set-Service Spooler -StartupType Disabled }; Revert={ Set-Service Spooler -StartupType Automatic; Start-Service Spooler }; Check={ $s = Get-Service Spooler -ErrorAction SilentlyContinue; if (!$s) { return $true }; return ($s.StartType -eq "Disabled" -and $s.Status -ne "Running") } }
    "Adv_ReservedStorage" = @{ SlowCheck=$true; Apply={ Start-Process "dism" -ArgumentList "/Online /Set-ReservedStorageState /State:Disabled" -Wait -NoNewWindow }; Revert={ Start-Process "dism" -ArgumentList "/Online /Set-ReservedStorageState /State:Enabled" -Wait -NoNewWindow }; Check={ [bool]((dism /online /Get-ReservedStorageState | Out-String) -match "is disabled") } }
    
    "Adv_WSL" = @{ Reboot=$true; SlowCheck=$true; Apply={ Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux" -NoRestart -ErrorAction SilentlyContinue }; Revert={ Disable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux" -NoRestart -ErrorAction SilentlyContinue }; Check={ (Get-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux" -ErrorAction SilentlyContinue).State -eq "Enabled" } }
    "Adv_HyperV" = @{ Reboot=$true; SlowCheck=$true; Apply={ Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V-All" -NoRestart -ErrorAction SilentlyContinue }; Revert={ Disable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V-All" -NoRestart -ErrorAction SilentlyContinue }; Check={ (Get-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V-All" -ErrorAction SilentlyContinue).State -eq "Enabled" } }

    # EXPERT: fully REMOVE the Recall optional feature (Microsoft's official uninstall path),
    # not just policy-disable it like Sys_Recall. More aggressive and less cleanly reversible.
    # No-op on builds where the feature isn't present (Check returns false).
    "Adv_RecallRemove" = @{ Reboot=$true; SlowCheck=$true; Warning="Fully removes the Recall component (Disable-WindowsOptionalFeature). Re-adding it requires toggling this back on plus a reboot. The standard Privacy > Disable Recall policy is enough for most users."; Apply={ Disable-WindowsOptionalFeature -Online -FeatureName "Recall" -NoRestart -ErrorAction SilentlyContinue | Out-Null }; Revert={ Enable-WindowsOptionalFeature -Online -FeatureName "Recall" -NoRestart -ErrorAction SilentlyContinue | Out-Null }; Check={ $f = Get-WindowsOptionalFeature -Online -FeatureName "Recall" -ErrorAction SilentlyContinue; if (!$f) { return $false }; return ($f.State -ne "Enabled") } }

    # WPBT (Windows Platform Binary Table): firmware mechanism OEMs use to auto-inject
    # their software (e.g. Armoury Crate) into Windows at every boot, even clean installs.
    "Adv_WPBT" = @{ Reboot=$true; Apply={ Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" "DisableWpbtExecution" 1 }; Revert={ Remove-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" "DisableWpbtExecution" }; Check={ Test-Reg-Read "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" "DisableWpbtExecution" 1 } }
}

$AutoMap = @{ "Sys_VisualFX"="Auto_Visuals"; "Sys_DeviceInstall"="Auto_Drivers"; "Sys_RemoteAssist"="Auto_Remote"; "Sys_Recall"="Auto_Recall"; "Game_HAGS"="Auto_Hags"; "Game_GameMode"="Auto_GameMode"; "Sys_SysRestore"="Auto_SysRestore"; "Sys_UAC"="Auto_UAC"; "HH_CoreIso"="Auto_CoreIso"; "Priv_Tele"="Auto_Tele"; "Priv_AdID"="Auto_AdID"; "Priv_Loc"="Auto_Loc"; "Priv_Wifi"="Auto_Wifi"; "Priv_Bing"="Auto_Bing"; "Priv_Widgets"="Auto_Widgets"; "Priv_Copilot"="Auto_Copilot"; "Game_PCIe"="Auto_PCIe"; "Game_VariBright"="Auto_VariBright"; "Game_DPST"="Auto_DPST"; "Sys_AutoBright"="Auto_Bright"; "Priv_ConsumerFeatures"="Auto_Consumer"; "Priv_WER"="Auto_WER"; "Sys_CpuOpt"="Auto_CpuOpt"; "Sys_StartAds"="Auto_StartAds"; "Priv_ActivityUpload"="Auto_Activity" }

# --- TWEAK DESCRIPTIONS ---
# Centralized hover-text for tweaks, surfaced by the InfoDojo panel. Keyed by control name.
# Entries whose control isn't found are harmlessly ignored, so this map is safe to extend.
$TweakTips = @{
    # System
    "Sys_VisualFX"          = "Disables Windows animations and transparency for a snappier, lower-latency desktop. Purely cosmetic - no features lost."
    "Sys_DeviceInstall"     = "Stops Windows from auto-installing generic/older drivers over the ones you chose. Recommended for gaming rigs."
    "Sys_RemoteAssist"      = "Turns off Windows Remote Assistance, closing a remote-access surface you almost certainly don't use."
    "Sys_Recall"            = "Disables Windows Recall, the AI feature that screenshots your activity. Major privacy win on 24H2/25H2."
    "Sys_SysRestore"        = "Turns OFF System Restore to save disk space and background cycles. WARNING: this also disables Ronin's own Auto-Backup restore points - leave unchecked unless storage is critical."
    "Sys_UAC"               = "Tunes User Account Control prompts. Lowering prompts is convenient but slightly less secure."
    "Sys_CpuOpt"            = "Applies CPU scheduling tweaks for better responsiveness under load."
    "Sys_StartAds"          = "Removes 'suggested' app ads and promotions from the Start Menu."
    "Sys_AutoBright"        = "Disables adaptive/automatic brightness so the screen stops changing on its own."
    "Sys_Bloatware"         = "Removes preinstalled bloatware apps. EXPERT: review before running - some apps may be wanted."
    "Sys_SearchIndex"       = "Disables the Windows Search indexer service. Saves disk activity; search becomes slower."
    "Sys_MeetNow"           = "Removes the 'Meet Now' Skype shortcut from the taskbar/system tray."
    "Sys_Hibernation"       = "Turns hibernation OFF (powercfg /h off) to reclaim hiberfil.sys disk space. NOTE: the handheld Hot-Bag fix REQUIRES hibernation, so leave this unchecked if you use Hot-Bag."

    # Gaming / GPU
    "Game_HAGS"             = "Hardware-Accelerated GPU Scheduling - can reduce latency on modern GPUs. Test per-game; reboot required."
    "Game_GameMode"         = "Enables Windows Game Mode to prioritize the foreground game."
    "Game_PCIe"             = "Sets PCIe link power management to maximum performance (no downclocking the GPU bus)."
    "Game_VariBright"       = "Disables AMD VariBright, which dims the screen on battery and hurts visual consistency."
    "Game_DPST"             = "Disables Intel Display Power Saving (DPST/DRRS) that alters brightness/refresh to save power."
    "Game_NvidiaFlipMode"   = "Forces NVIDIA hardware-accelerated flip presentation for lower latency. NVIDIA only."
    "Game_InterruptModeration" = "Adjusts GPU interrupt moderation. Advanced latency tuning."

    # Privacy
    "Priv_Tele"             = "Sets Windows telemetry to the minimum the OS allows. Stops most background data collection."
    "Priv_AdID"             = "Disables the per-user Advertising ID so apps can't build an ad profile of you."
    "Priv_Loc"             = "Turns off the system Location service."
    "Priv_Wifi"             = "Disables Wi-Fi Sense and automatic hotspot connection."
    "Priv_Bing"             = "Removes Bing/web results from Start Menu search, keeping it local-only and faster."
    "Priv_Widgets"          = "Disables the Widgets board (news/weather feed) and its background process."
    "Priv_Copilot"          = "Disables Windows Copilot AI integration and its taskbar button."
    "Priv_ConsumerFeatures" = "Blocks 'consumer experiences' - the silent auto-installing of promoted apps and games."
    "Priv_WER"              = "Disables Windows Error Reporting uploads."
    "Priv_ActivityUpload"   = "Stops uploading your Activity/Timeline history to Microsoft's cloud."
    "Priv_StorageSense"     = "Turns OFF Windows Storage Sense (the automatic temp-file and recycle-bin cleanup), keeping cleanup fully manual."

    # Handheld
    "HH_CoreIso"            = "Toggles Core Isolation / Memory Integrity. OFF can improve game performance; ON is more secure. Auto-skipped if BitLocker is on."
    "HH_Encryption"         = "Decrypts your OS drive (BitLocker). CRITICAL: do not shut down until decryption hits 100% or you'll get a recovery screen."
    "HH_BoostMode_AC"       = "CPU boost behavior while PLUGGED IN (AC power). 'Aggressive' = max performance."
    "HH_BoostMode_DC"       = "CPU boost behavior while on BATTERY (DC power). Lower = longer battery life."
    "HH_EPP_AC"             = "Energy Performance Preference while PLUGGED IN. Lower value = favors performance."
    "HH_EPP_DC"             = "Energy Performance Preference while on BATTERY. Higher value = favors efficiency."
    "HH_TouchKeyboard"      = "Keeps the touch keyboard service running so it pops up reliably on handhelds/tablets."
    "HH_TouchResponse"      = "Reduces menu/UI delays for a snappier touch experience."
    "HH_VMP"                = "Toggles the Virtual Machine Platform feature. EXPERT: affects WSL/sandbox. Auto-skipped if BitLocker is on."

    # Advanced
    "Adv_Printing"          = "Disables the Print Spooler service. EXPERT: only if you never print (closes a known attack surface)."
    "Adv_WSL"               = "Enables the Windows Subsystem for Linux. Optional developer feature; adds overhead. Reboot required."
    "Adv_HyperV"            = "Enables Hyper-V virtualization. Optional; can impact gaming latency. Reboot required."
    "Adv_RecallRemove"      = "EXPERT: fully REMOVES the Recall feature from Windows (not just policy-disabled). The standard 'Disable Recall' on the Privacy tab is enough for most people. Reboot required; re-adding needs this toggled back on."
    "Adv_WPBT"              = "Blocks the Windows Platform Binary Table - the firmware backdoor OEMs use to auto-install their software (Armoury Crate, etc.) into every Windows install. You bought the hardware; you decide what runs on it. Reversible; reboot required."
    "Adv_UTC"               = "Stores the hardware clock as UTC (useful for Linux dual-boot). May confuse Windows time on its own."
    "Adv_ReservedStorage"   = "Disables Windows Reserved Storage, reclaiming ~7GB. Updates may need that space temporarily."
}

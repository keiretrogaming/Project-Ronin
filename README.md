# ⚔️ Project Ronin

<img width="1664" height="1105" alt="Project Ronin Hero" src="https://github.com/user-attachments/assets/004afab0-1820-4802-9c4a-35eb00a8f9a9" />

### *A transparent, policy-driven optimization suite for Windows 11.*

**Project Ronin** is a comprehensive PowerShell utility designed to strip away Windows 11 telemetry, stabilize gaming frame times, and optimize Windows handheld devices. 

---

> [!CAUTION]
> ### 🛡️ Antivirus False Positives & Microsoft Review Status
> **Current Status:** Manual False-Positive Review in Progress.
>
> Because Ronin modifies deep system settings, aggressive engines may flag the launch command. **This is a False Positive.** You can audit the code in the `/src` folder.

---

## 🚀 Quick Launch (No Download Required)

The fastest way to run Project Ronin. This command securely downloads the latest release into your temporary files and launches the UI natively.

1. Right-click the Windows Start button.
2. Select **Terminal (Admin)** or **Windows PowerShell (Admin)**.
3. Paste the following command and press Enter:

```powershell
irm https://raw.githubusercontent.com/keiretrogaming/Project-Ronin/main/run.ps1 | iex

```

---

## 🛡️ The "No-Regret" Policy (Safety First)

* **Automatic Restore Points:** Triggered before any major modifications are applied.
* **Policy-Based Tweaks:** Leverages official Windows registry flags; your system stays "valid" and stable.
* **Standardized APIs:** Utilizes official Windows Management (CIM/WMI) pathways for all sensors and tweaks.
* **Non-Destructive:** No `System32` files are deleted. Features can be toggled back on easily.
* **Hardware Aware:** Automatically detects if you are on an NVIDIA desktop or an AMD handheld like the ROG Ally.

---

## 🕹️ Core Modules

| Module | Purpose | Key Tweaks |
| --- | --- | --- |
| **Auto-Optimize** | The Baseline | Safe, high-impact defaults that work for 99% of users. |
| **System Core** | UI & Background | Fixes "Ghost Sleep," removes Start Menu ads, and streamlines Explorer. |
| **Gaming & GPU** | Latency & Stability | Sets HAGS/VRR flags and safely disables MPO to prevent flickering. |
| **Handheld** | Portables & Battery | Includes "Hot-Bag" fix; optimizes CPU EPP Power Slicing. |
| **Privacy Shield** | 24H2 Hardening | Disables Recall AI, Copilot, and aggressive data-mining. |
| **Maintenance** | Diagnostics | Implements "One-Click Repair" logic, resets MS Store, and audits SSD health. |

---

## 📸 Feature Showcase

### **Gaming & Latency**

*Aggressive optimizations for frame-time stability and GPU priority scaling.*
<img width="1663" height="1111" alt="Gaming Tab" src="https://github.com/user-attachments/assets/b9052f99-0dfb-4049-a7fe-cc5f2ce8529b" />

### **Handheld Supremacy**

*Full support for ROG Ally, Legion Go, and MSI Claw—featuring EPP Power Slicing.*
<img width="1667" height="1113" alt="Handheld Tab" src="https://github.com/user-attachments/assets/7568ab32-44ab-4940-81d6-4e2d33ce340f" />

### **System Core & UI**

*Streamline the Windows 11 interface and remove background bloat.*
<img width="1663" height="1109" alt="System Core" src="https://github.com/user-attachments/assets/60901e5d-90d7-4fb2-847a-01c442876a49" />

---

## ❓ Frequently Asked Questions

**Will this break Windows Update?** No. Core security patching remains fully intact.
**Why PowerShell instead of an .exe?** Transparency. A script is plain text that you can audit; an `.exe` is a "black box."
**Is this safe for Handhelds?** Yes. It detects handheld hardware automatically and unlocks specific portable optimizations.

---

## ⚖️ Disclaimer

*Project Ronin is shared as an open-source tool. Modifying system-level settings always carries a small inherent risk. Always maintain a current backup. Provided "as-is" under the MIT License.*

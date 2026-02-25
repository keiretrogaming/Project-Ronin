
# Project Ronin

### *Reclaim your hardware. A one-click, policy-driven optimization suite for Windows 11.*

I built Project Ronin for myself because I was tired of fighting my own computers. I’ve used amazing tools like WinUtil and Ultimate Windows Tweaker for years, but they never quite had *everything* I wanted in one place. I needed a single utility to repair Windows, check my SSD health, and clear out cluttered GPU driver caches without having to hunt through menus.

Visually, I wanted a clean, retro-cmd cyberpunk aesthetic—something that feels nostalgic, looks awesome but operates with modern efficiency. 

The name Ronin implies a masterless samurai—you bought your hardware, so you should be the one in control of it, not Microsoft. If you paid for high-end silicon, you deserve 100% of its power! 

Ronin uses official **Group Policies** and **Registry Flags** to ensure your system remains stable, secure, and entirely reversible.
<img width="1664" height="1113" alt="image" src="https://github.com/user-attachments/assets/0b49822c-fa6f-4a3c-a999-c35da5e007fa" />

---

## Disclosure

I’ve wanted to build an app like this for years, but the syntax of programming never quite "clicked" for me. I used an LM to bridge that gap and finally build this. However, I didn't just copy-paste. Every single tweak has been cross-referenced against trusted communities and tools like *ElevenForum* and *WinUtil*. 

More importantly, I've personally verified these tweaks on my own fleet of Windows Devices: an **MSI Claw 8 AI**, a **2023 & 2025 Zephyrus G14**, and two custom desktops. My first priority to you is stability and transparency. There's a poetic irony in using AI to rip the unwanted AI features out of Windows, but it works beautifully.

---

## ⚠️ Known Issues (PLEASE READ)

*I’m currently hunting down fixes for these bugs for the upcoming Shogun release. In the meantime, definitely keep an eye on these before you start tweaking:*

* **CRITICAL: The BitLocker "Black Screen" Trap**
Disabling Device Encryption (Handheld Tab) happens silently in the background. **Don’t restart your device immediately.** Depending on your SSD, decryption can take anywhere from 10 minutes to an hour. If you reboot before it hits 0%, you’ll trip a BitLocker recovery loop—which usually looks like a scary black or sideways screen on handhelds like the ROG Ally.
* **FIX:** If you run this tweak, manually open **Control Panel > BitLocker** and wait until it says "Fully Decrypted" before you even think about hitting restart.


* **Core Isolation & VMP Boot Risks**
Disabling Memory Integrity (HVCI) or the Virtual Machine Platform (VMP) changes how Windows handles its "trusted" boot environment. If your drive is still encrypted when you toggle these, Windows might get suspicious and lock you out on the next boot.
* **FIX:** Always make sure your drive is 100% decrypted before messing with Core Isolation or VMP settings.


* **Progress Bar Hijacking**
If you start a long-running job (like a Full System Repair or Decryption) and then jump to another tab to apply more tweaks, the Progress Bar will get "hijacked" by the new tasks. The original task is still finishing in the background, but you won't be able to see its status anymore.
* **The Hot-Bag Interlock**
The "Hot-Bag Fix" (which forces your power button to Hibernate) relies on Windows Hibernation being turned on. If you disable Hibernation in the System tab, this fix might fail or cause your power button to act up when you toss your device in your bag.

---

## 🚀 Quick Launch (No Download Required)

The fastest way to run Project Ronin. This command securely downloads the latest release into your temporary files, temporarily bypasses local execution policies, and launches the UI natively.

1. Right-click the Windows Start button.
2. Search for and select **Windows PowerShell (run as Admin)**.
3. Paste the following command and press Enter:

```powershell
irm "https://raw.githubusercontent.com/keiretrogaming/Project-Ronin/main/run.ps1?$(Get-Random)" | iex 

```

---

## 📥 Manual Installation

If you prefer to download the files and run them locally:

1. Download the latest `.zip` from the releases tab and extract it.
2. Double-click the **`Launch_Ronin.bat`** file.
3. Accept the Administrator prompt. *(The batch file automatically handles PowerShell execution policies for you).*

---

## 🛡️ The Non-Destructive Optimization Policy

Trust is built on transparency and the ability to roll back changes. Project Ronin is built on the following safety principles:

* **Automatic Restore Points:** A system restore point is triggered before any major modifications are applied.
* **Policy-Based Tweaks:** We use Group Policy and official Windows registry flags. Windows recognizes these changes as "intended settings" rather than corrupted files.
* **Non-Destructive:** We do not delete `System32` components. If you want a feature back (like Windows Copilot or the Snap Flyout), you can simply toggle it back on.
* **Hardware Aware:** The script checks your hardware ID on launch. It won't attempt to push NVIDIA-specific latency tweaks to an AMD-based handheld device.

---

## 🕹️ Core Modules

| Module | Purpose | Key Tweaks |
| --- | --- | --- |
| **Auto-Optimize** | My Personal Baseline | Safe, high-impact defaults I put on every new machine I build. |

<img width="1660" height="1111" alt="image" src="https://github.com/user-attachments/assets/e3b527b4-b822-42c4-97fa-8caa616215d2" />

| Module | Purpose | Key Tweaks |
| --- | --- | --- |
| **System Core** | UI & Background | Fixes "Ghost Sleep," removes Start Menu ads, and streamlines Explorer. |

<img width="1659" height="1108" alt="image" src="https://github.com/user-attachments/assets/50414530-3183-4d7e-a076-2017498fcf34" />

| Module | Purpose | Key Tweaks |
| --- | --- | --- |
| **Gaming & GPU** | Latency & Stability | Sets HAGS/VRR flags and safely disables MPO to prevent flickering. |

<img width="1665" height="1108" alt="image" src="https://github.com/user-attachments/assets/71f6a5da-98ea-42a6-b181-5e76c7ec5934" />

| Module | Purpose | Key Tweaks |
| --- | --- | --- |
| **Handheld** | Portable Devices | **Essential for x86 Handhelds.** Fixes "Hot-Bag" issues by forcing Hibernate, disables encryption/VBS for APU gains, and checks battery health. |

<img width="1669" height="1114" alt="image" src="https://github.com/user-attachments/assets/11d52281-ce66-41bc-bd20-a180675ab90b" />

| Module | Purpose | Key Tweaks |
| --- | --- | --- |
| **Privacy Shield** | De-AI Windows | Strips out Recall AI, Copilot, and aggressive telemetry data-mining. |

<img width="1664" height="1109" alt="image" src="https://github.com/user-attachments/assets/2add469c-ec66-4094-b68a-49833954f9b0" />

| Module | Purpose | Key Tweaks |
| --- | --- | --- |
| **Maintenance** | Diagnostics | My one-click cure-all. Repairs the Windows image, resets MS Store, clears GPU caches, and audits SSD health. |

<img width="1660" height="1107" alt="image" src="https://github.com/user-attachments/assets/0d6a7d40-9179-4d33-aaa8-99cb26c77367" />

---

## 🗺️ Roadmap & Community

My roadmap is whatever *you* want it to be! I built this to solve my own headaches, but if you have ideas, tweaks, or specific features you want to see added to Project Ronin, let me know. Drop a suggestion in the **Issues** tab!

---

## ❓ Frequently Asked Questions

**Will this break Windows Update?** No. Project Ronin disables the *annoyances* of Windows Update (like forced auto-restarts and using your bandwidth to seed updates to other PCs via WUDO), but the core security patching engine remains fully intact.

**Why not just use WinUtil?** I love WinUtil, but Ronin includes specific tools I wanted in a single click, like checking SSD health, resetting the GPU driver stack, and deep handheld-specific optimizations. WinUtil, while being amazing, never had everything that I wanted. 

**Is this safe for Handhelds (MSI Claw, ROG Ally, Legion Go)?** Absolutely. I'm a massive handheld fan, and Project Ronin automatically detects handheld hardware. The dedicated **Handheld** tab includes specific fixes for Modern Standby issues and custom EPP power slicing.

---

## ⚖️ Disclaimer

*Project Ronin is shared as an open-source tool. I built it for myself, but modifying system-level settings always carries a small inherent risk. Always maintain a current backup of your important files. Provided "as-is" under the MIT License.*

---


```markdown
# ⚔️ Project Ronin: Shogun Edition (v7.1.0)

> [!IMPORTANT]
> [cite_start]**Developer Note on Antivirus:** Because Ronin touches deep registry keys and system policies, tools like Windows Defender or Bitdefender might flag the launch command as a "threat." [cite: 6] [cite_start]This is a false positive based on the *behavior* of modifying system settings, not malicious code. [cite: 6] [cite_start]You can audit every line in the `/src` folder yourself. [cite: 6] [cite_start]If your system blocks the cloud command, just download the .zip and run it manually. [cite: 6]

[cite_start]Project Ronin is a policy-driven optimization suite built for Windows 11 power users and handheld gamers. [cite: 6] [cite_start]Unlike debloaters that take a "scorched earth" approach and break Windows Update, Ronin uses official registry flags and Group Policies to keep your OS lean and fast without making it unserviceable. [cite: 6]

---

## 🚀 Quick Launch

No installation needed. Run this from an **Admin Terminal** to pull the latest Shogun build directly into memory:

```powershell
irm [https://get.ronin.dev](https://get.ronin.dev) | iex

```

*Note: If the cloud command fails due to local execution policies, download the [Latest Release](https://github.com/keiretrogaming/Project-Ronin/releases) and run `Launch_Ronin.bat`.* 

---

## 🏯 What’s New in the Shogun Edition (v7.1.0)?

The 7.1 release is a complete engine overhaul focused on handheld hardware and system stability. 

* 
**Shogun Power Architecture:** A new 5-tier EPP (Energy Performance Preference) system. You can now balance your power budget between the CPU and GPU (GPU Bias) to get better FPS in AAA games on handhelds. 


* 
**Dual-State Logic:** Tweaks now apply to both AC (Plugged In) and DC (Battery) states independently. 


* 
**Engine Hardening:** We added a 750ms "registry settling" delay and strict UI tab-locking. This stops race conditions and ensures your settings actually "stick" the first time. 


* 
**AV Compliance:** We removed aggressive hooks like "The Vaccine" and process priority elevation. Ronin now plays nice with Windows Defender while maintaining its optimization power. 


* 
**Universal Compatibility:** Moved from English-string parsing to 36-character GUID RegEx. Ronin now works on any language version of Windows. 



---

## 🛠️ Optimization Protocols

| Module | Focus | What it actually does |
| --- | --- | --- |
| **Auto Optimize** | Standard Issue | Applies the "Ronin Core" set: disables telemetry, ads, and fixes PCIe stutters. 

 |
| **System Core** | OS Fundamentals | Cleans up Explorer, fixes the Right-Click menu, and tunes kernel responsiveness. 

 |
| **Gaming & GPU** | Frame Times | Enables HAGS, VRR, and optimizes network buffers for lower latency. 

 |
| **Handheld** | Portables | <br>**Shogun Exclusive:** 5-Tier EPP slicing, Modern Standby fixes, and "Hot-Bag" prevention. 

 |
| **Privacy Shield** | 24H2 Hardening | Kills Recall AI, Copilot, and background data-mining tasks. 

 |
| **Maintenance** | Diagnostics | SSD health audits, TRIM cycles, and DISM/SFC system repairs. 

 |

---

## ❓ Frequently Asked Questions

**Will this break my Windows Updates?**
No. We kill the annoying parts (forced restarts and bandwidth stealing), but the core security patching stays intact. 

**Is this safe for my ROG Ally / Legion Go / MSI Claw?**
Yes—it was built for them. Ronin detects your hardware and unlocks the Handheld tab automatically, giving you better control over battery drain and thermal throttling than the factory software. 

**Can I undo the changes?**
Everything Ronin does is backed up to a local snapshot. Use the built-in **Snapshot Recovery Tool** or the "Undo All" button in Expert Mode to return to Windows defaults. 

---

## ⚖️ Disclaimer

Project Ronin is open-source. While I’ve tested this rigorously on my own machines, you’re modifying system-level settings.  Always keep a backup. Provided "as-is" under the MIT License. 

```

```
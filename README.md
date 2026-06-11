# Project Ronin

### *Reclaim your hardware. A one-click optimization suite for Windows 11.*

I built Project Ronin because I got tired of fighting my own computers. I've used great tools like WinUtil and Ultimate Windows Tweaker for years, but none of them had *everything* I wanted in one place. I kept bouncing between three apps just to repair Windows, check SSD health, and clear out a bloated GPU driver cache. So I made the tool I actually wanted.

It also had to look the part. The whole UI is a retro-cmd, cyberpunk styled. Nostalgic on the surface, modern underneath.

The name is the point. A ronin is a masterless samurai. You bought your hardware, so you're the one who should control it, not Microsoft. You paid for the silicon, you should get all of it.

Everything runs through official **Group Policies** and **registry flags**, so your system stays stable, secure, and every change can be undone.

<img width="1664" height="1113" alt="image" src="https://github.com/user-attachments/assets/0b49822c-fa6f-4a3c-a999-c35da5e007fa" />

---

## Disclosure

I've wanted to build something like this for years, but programming syntax never clicked for me. I used an LM to bridge that gap. I didn't just copy-paste and hope for the best, though. Every tweak is cross-referenced against trusted sources like *ElevenForum* and *WinUtil*, and I run all of them on my own hardware: an **MSI Claw 8 AI**, a **2023 and 2025 Zephyrus G14**, and two custom desktops.

Stability and transparency come first. And yes, there's a certain irony in using AI to rip the unwanted AI out of Windows. It works anyway.

---

## ⚠️ Read This Before Tweaking

Most of the scary stuff from older versions is now handled by the app itself, but you should still know how Windows behaves:

* **BitLocker decryption takes time.** Turning off Device Encryption (Handheld tab) decrypts your drive in the background, anywhere from 10 minutes to an hour depending on your SSD. Ronin now shows a live **"DO NOT RESTART - DECRYPTING [X%]"** banner and warns you if you try to close the app mid-decrypt. The rule still stands: **don't reboot until it hits 100%**, or you'll trip a BitLocker recovery screen (the infamous black/sideways screen on handhelds).

* **Core Isolation & VMP are guarded now.** Toggling Memory Integrity (HVCI) or the Virtual Machine Platform while your drive is encrypted can lock you out on the next boot. Ronin automatically **skips these tweaks while BitLocker is active**, so you can't shoot yourself in the foot. Decrypt first, then toggle.

* **Known issue: progress bar hijacking.** If you start a long job (Full System Repair, decryption) and then fire off more tweaks from another tab, the new tasks take over the progress bar. The original job is still running fine in the background, you just lose the visual. On my list.

* **The Hot-Bag interlock.** The Hot-Bag Fix (power button = Hibernate) needs Windows Hibernation enabled. If you've disabled Hibernation in the System tab, Ronin locks the Hot-Bag toggle and tells you why instead of letting it half-apply.

---

## 📥 Installation

Windows blocks files downloaded from the internet, and some antivirus side-eyes any system tweaker. Two steps and you're past all of it:

**1. Unblock the zip *before* extracting.**
Right-click the downloaded `.zip` → **Properties** → tick **Unblock** at the bottom → **OK**. *Then* extract it. Doing it in this order clears the block on every file inside at once, so you never have to unblock anything one by one.

> Already extracted? No problem. Open the folder, type `powershell` in the address bar, hit Enter, and run:
> ```powershell
> Get-ChildItem -Recurse | Unblock-File
> ```

**2. Run it.**
Right-click **`Launch_Ronin.bat`** → **Run as administrator**. If a blue "Windows protected your PC" box pops up, click **More info → Run anyway**. That's standard for any new unsigned app.

The launcher loosens the execution policy for that one window only. No permanent changes to your system, and everything Ronin does is reversible from inside the app.

---

## 🛡️ The Non-Destructive Optimization Policy

Trust is built on transparency and the ability to roll back:

* **Automatic Restore Points:** Ronin triggers a system restore point before major modifications (and tells you plainly if Windows can't make one).
* **Policy-Based Tweaks:** Group Policy and official registry flags. Windows treats these as intended settings, not corruption.
* **Non-Destructive:** Nothing in `System32` gets deleted. Want Copilot or the Snap flyout back? Toggle it back on.
* **Hardware Aware:** Ronin checks your hardware on launch. It won't push NVIDIA latency tweaks to an AMD handheld.

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
| **Privacy Shield** | De-AI Windows | Strips out Recall AI, Copilot, and aggressive telemetry data-mining. Even blocks WPBT, the firmware trick vendors use to auto-install their software on clean installs. |

<img width="1664" height="1109" alt="image" src="https://github.com/user-attachments/assets/2add469c-ec66-4094-b68a-49833954f9b0" />

| Module | Purpose | Key Tweaks |
| --- | --- | --- |
| **Maintenance** | Diagnostics | My one-click cure-all. Repairs the Windows image, resets MS Store, clears GPU caches, audits SSD health, and the new **Reclaim Space** deep clean typically frees 15-30+ GB. |

<img width="1660" height="1107" alt="image" src="https://github.com/user-attachments/assets/0d6a7d40-9179-4d33-aaa8-99cb26c77367" />

---

## 🗺️ Roadmap & Community

Honestly, the roadmap is whatever you want it to be. I built this to solve my own headaches. If there's a tweak or feature you want in Ronin, drop it in the **Issues** tab and I'll take a look.

---

## ❓ Frequently Asked Questions

**Will this break Windows Update?** No. Ronin kills the *annoyances* (forced auto-restarts, seeding updates to strangers via WUDO) but leaves the actual security patching alone.

**My antivirus flagged it. Is it a virus?** No. Ronin edits deep Windows settings, which is exactly what heuristic scanners look for. There's no telemetry, no obfuscation, and every line of code is public in this repo for you to read. If your AV blocks it, that's a false positive you can report to Microsoft.

**Why not just use WinUtil?** I love WinUtil. But Ronin bundles things I always wished it had in one click: SSD health checks, a full GPU driver-stack reset, and deep handheld tuning. WinUtil is amazing, it just never had *everything* I wanted.

**Is this safe for Handhelds (MSI Claw, ROG Ally, Legion Go)?** That's the whole reason it exists. I'm a massive handheld fan, and Ronin auto-detects handheld hardware and opens a dedicated tab with Modern Standby fixes and custom EPP power slicing.

**Where are the logs?** Click the green console in the bottom-left (or Maintenance → Open Logs & Backups). Every action gets logged, and `Ronin_StateReport.txt` shows exactly which tweaks are on or off right now.

---

## ⚖️ Disclaimer

*Project Ronin is open-source and shared as-is under the MIT License. I built it for myself and run it on my own machines, but system-level tweaking always carries some inherent risk. Keep a backup of anything you can't afford to lose.*

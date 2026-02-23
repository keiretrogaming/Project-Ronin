
# Project Ronin

### *A transparent, policy-driven optimization suite for Windows 11.*

**Project Ronin** is a comprehensive PowerShell utility designed to strip away Windows 11 telemetry, stabilize gaming frame times, and optimize windows handheld devices.

Unlike "scorched-earth" debloaters that permanently delete system files and break Windows Update, Ronin uses official **Group Policies** and **Registry Flags** to ensure your system remains stable, secure, and entirely reversible.
<img width="1664" height="1113" alt="image" src="https://github.com/user-attachments/assets/0b49822c-fa6f-4a3c-a999-c35da5e007fa" />

---

## 🚀 Quick Launch (No Download Required)

The fastest way to run Project Ronin. This command securely downloads the latest release into your temporary files, temporarily bypasses local execution policies, and launches the UI natively.

1. Right-click the Windows Start button.
2. Select **Terminal (Admin)** or **Windows PowerShell (Admin)**.
3. Paste the following command and press Enter:

```powershell
irm https://raw.githubusercontent.com/keiretrogaming/Project-Ronin/main/run.ps1 | iex

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
| **Auto-Optimize** | The Baseline | Safe, high-impact defaults that work for 99% of users. |
<img width="1660" height="1111" alt="image" src="https://github.com/user-attachments/assets/e3b527b4-b822-42c4-97fa-8caa616215d2" />

| **System Core** | UI & Background | Fixes "Ghost Sleep," removes Start Menu ads, and streamlines Explorer. |
<img width="1659" height="1108" alt="image" src="https://github.com/user-attachments/assets/50414530-3183-4d7e-a076-2017498fcf34" />

| **Gaming & GPU** | Latency & Stability | Sets HAGS/VRR flags and safely disables MPO to prevent flickering. |
<img width="1665" height="1108" alt="image" src="https://github.com/user-attachments/assets/71f6a5da-98ea-42a6-b181-5e76c7ec5934" />

| **Handheld** | Portable Devices | Fixes "Hot-Bag" issues by forcing Hibernate; optimizes CPU EPP. |
<img width="1669" height="1114" alt="image" src="https://github.com/user-attachments/assets/11d52281-ce66-41bc-bd20-a180675ab90b" />

| **Privacy Shield** | Disables Recall AI, Copilot, and aggressive telemetry data-mining. |
<img width="1664" height="1109" alt="image" src="https://github.com/user-attachments/assets/2add469c-ec66-4094-b68a-49833954f9b0" />

| **Maintenance** | Diagnostics | One Click Repair for Windows 11, resets MS Store, and audits SSD health. |
<img width="1660" height="1107" alt="image" src="https://github.com/user-attachments/assets/0d6a7d40-9179-4d33-aaa8-99cb26c77367" />

---

## ❓ Frequently Asked Questions

**Will this break Windows Update?** No. Project Ronin disables the *annoyances* of Windows Update (like forced auto-restarts and using your bandwidth to seed updates to other PCs via WUDO), but the core security patching engine remains fully intact.

**Why is this a PowerShell script instead of an executable (.exe)?** Authenticity and security. An `.exe` is a black box. A `.ps1` file is plain text. You should never run a system-level optimizer if you cannot easily audit the code behind it.

**Is this safe for Handhelds (MSI Claw, ROG Ally, Legion Go)?** Yes. Project Ronin automatically detects handheld hardware. The dedicated **Handheld** tab includes specific fixes for Modern Standby issues, custom EPP power slicing, and manufacturer bloatware management.

---

## ⚖️ Disclaimer

*Project Ronin is shared as an open-source tool. While it is rigorously tested for stability, modifying system-level settings always carries a small inherent risk. Always maintain a current backup of your important files. Provided "as-is" under the MIT License.*

---


# Changelog

All notable changes to **Project Ronin** are documented in this file.
This project adheres to [Semantic Versioning](https://semver.org/).

## [7.3.1] — 2026-06-11

Stability and polish patch. **If you downloaded 7.3.0, please update** — this fixes a
critical engine bug that could silently stop tweaks from applying.

### Added
- **Reclaim Space (Maintenance)** — one-click deep clean: removes `Windows.old` and
  permanently compresses superseded update files (DISM ResetBase). Typically frees
  15–30+ GB and reports the exact amount freed. Includes a clear warning first.
- **Block Vendor Software Injection / WPBT (Advanced)** — stops motherboard and laptop
  firmware from auto-installing vendor software (e.g. Armoury Crate) into every Windows
  install. You bought the hardware; you decide what runs. Reversible; reboot required.
- **Quad9 DNS (Advanced)** — added the security-focused Quad9 resolver (blocks known
  malware domains) to the DNS Command Center. DNS cache now auto-flushes after switching.
- **Theme-matched batch summary** — applying tweaks now ends with a styled summary
  (applied / reverted / already-optimal / failed, with failing tweaks named) instead of a
  plain Windows message box.

### Fixed
- **Critical: the background engine could stop applying tweaks partway through a batch**
  (commands intermittently failed to resolve). Tweaks now apply and revert reliably.
- Restore-point creation can no longer hang the app indefinitely (90-second cap with a
  clear message, e.g. when System Protection is off).
- Dropdown tweaks falsely reported "failed" after applying successfully.
- "Already optimized" detection for CompactOS, Reserved Storage, Ultimate Performance and
  file-system tweaks — broken state checks forced slow re-applies (e.g. a ~35s CompactOS
  run on every batch even when nothing changed).
- Windows Update Reset left Cryptographic Services stopped and never cleared the download
  cache; it now performs the full standard reset sequence.
- Nagle's Algorithm tweak was a silent no-op (wrote to the wrong registry level); it now
  applies per network interface and cleans up the old stray value on revert.
- CPU boost-mode dropdowns now correctly reflect OEM power schemes (values 4–6).
- Clearing the search box left dropdown text invisible (black-on-black).
- Hover descriptions permanently stopped working after toggling any tweak; pinning a
  description is now **right-click** (left-click just toggles).
- "Disable System Restore" is no longer pre-checked in Auto-Optimize — it silently broke
  Ronin's own Auto-Backup restore points.
- BitLocker decryption banner hardened (named lookup) and a close-guard warns if you exit
  Ronin while a drive is still decrypting.

---

## [7.3.0] — 2026-06-09

A near-complete rewrite of the engine and UI since the public **7.0.0** build. The
background worker, diagnostics, logging, status detection, ranking, and the UI controller
were substantially rebuilt (RoninCore +57%, controller +40%, tweak database +24% by size),
**nearly every tweak gained a verified Revert and Check**, and **40+ bugs were fixed**
across the engine, tweak application, and UI.

### Added
- **Reclaim Space (Maintenance)** — one-click deep clean: removes `Windows.old` and
  permanently compresses superseded update files (DISM ResetBase), typically freeing
  15–30+ GB, with a confirmation warning and a freed-space report in the console.
- **Full reversibility** — Revert support added across the tweak database: **126 of 131
  tweaks are now reversible** (up from 106 of 125 in 7.0), each paired with a Check so the
  app can detect and roll back state accurately.
- **Diagnostics & logging subsystem** — `Write-Diag`, `Write-DiagException`, and
  `Start-DiagSession` (verbose internals, exception traces, and an environment header for
  bug reports) — all new since 7.0.
- **Safer service handling** — `Set-Service-Registry` disables services via the registry
  instead of fragile `Set-Service` calls that could fail or hang.
- **System State Report** — `C:\ProgramData\Ronin\Ronin_StateReport.txt`, a full ON/OFF
  snapshot of every tweak, regenerated after each audit. Click the on-screen console (or
  Maintenance → **Open Logs & Backups**) to open the logs folder.
- **Post-batch summary dialog** — after applying/reverting, shows counts (applied,
  reverted, already-optimal, failed) and names any tweaks that need attention.
- **Weighted System Rank** — scored against the curated Auto-Optimize recommended set and
  weighted by impact, so 100% is achievable and optional features no longer inflate it.
- **Per-tweak descriptions** — 45+ hover descriptions surfaced in the Information Dojo.
  Right-click a tweak to **pin** its description.
- **BitLocker safety** — live decryption-progress banner plus a close-guard that warns
  before you exit Ronin mid-decryption.
- **Diagnostics engine** — structured `Ronin.log` (events) and `Ronin_Diagnostic.log`
  (verbose, with environment header) for clean bug reports.
- **Touch Mode** — scales the UI for handheld touchscreens.
- **Code-signing pipeline** — `Sign-Ronin.ps1` (EV / OV / PFX / self-signed-test, with
  RFC-3161 timestamping); `BuildRonin.ps1 -Sign` builds and signs in one step.
- **New tweaks** — Storage Sense, Meet Now removal, WSL and Hyper-V toggles, and
  per-power-state (AC/DC) handheld Boost Mode and EPP controls.

### Fixed
- **40+ stability, correctness, and reliability fixes** across the engine, tweak
  application, and UI since 7.0 — including the major ones called out below. (See the
  release's closed issues / commit history for the full itemized list.)
- **Tweak activity now actually logs.** The background engine ran in a runspace that never
  received the log-file paths, so every apply/revert/skip/failure silently failed to
  write (only the environment header appeared). Engine logging and snapshot backups now
  work.
- **Hover tooltips stopped after toggling a tweak.** Pinning was on left-click, which also
  toggles a tweak — so any click froze the description panel and disabled all hover text.
  Resolved (see *Changed*). The hibernation interlock and Expert Mode also left it stuck;
  both now release it.
- **Search clear hid combo-box text.** Clearing the search box reset dropdown text to black
  on the dark theme, making it invisible. Now restored to white.
- **Build could silently produce a broken monolith.** If a source file was saved with CRLF
  line endings, XAML failed to inline (a ~170 KB output instead of ~275 KB). The build now
  normalizes line endings and verifies the output, failing loudly if anything didn't inline.

### Changed
- **Pin a description with right-click** (was left-click), leaving left-click free to
  toggle tweaks.
- The on-screen console and the Maintenance button now open the **logs folder** (was: the
  crash transcript / config snapshots only).
- **Version unified to 7.3.0** across all files.
- **Removed the `irm … | iex` one-line installer** from the README — it is the single most
  common antivirus/AMSI trigger. Install by downloading and running `Launch_Ronin.bat`.
- De-obfuscated an internal `manage-bde` call (string-splitting tripped AV heuristics).

### Security
- No telemetry, no network payloads, no obfuscation, and no Windows Defender tampering.
  All tweaks use documented Group Policy / registry settings and are reversible. Antivirus
  flags are heuristic false positives; the full source is auditable under `src/`. Report
  false positives at <https://www.microsoft.com/wdsi/filesubmission>.

[7.3.0]: https://github.com/keiretrogaming/Project-Ronin/releases

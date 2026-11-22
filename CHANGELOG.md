# Changelog

All notable changes to **Project Ronin** are documented in this file.
This project adheres to [Semantic Versioning](https://semver.org/).

## [8.0.0] — 2026-11-20 — the Declutter update

**Includes everything from 7.6.0.** Nothing that worked in 7.6 changed how it behaves; 8.0 adds
a tab, fixes, and safety nets.

### Added
- **DECLUTTER tab** (new, between Privacy Shield and Advanced Tools). One place to take Windows'
  ads, nags and surprises out. Every switch reverts, and Ronin records each setting's original
  value first so undo puts back exactly what your PC had.
  - **Ads & suggestions:** hide Start recommendations, search highlights, account nags in Start,
    suggestions inside Settings, the post-update "Welcome" screen, lock-screen tips, and the
    Spotlight "Learn about this picture" desktop icon. **Quiet Microsoft Edge** stops its first-run
    pages, recommendation popups, desktop shortcut after every update, and running in the background.
  - **Quality of life:** battery percentage on the taskbar, always-visible scrollbars, Num Lock on
    at startup, no more folder-type guessing in Explorer (slow "Pictures" downloads folders),
    long file paths, detailed startup messages, clear sign-in background.
- **Windows Update control** (Declutter tab), using Windows' own settings so the Settings app
  always agrees with Ronin and never says "managed by your organization":
  - **No surprise restarts:** active hours 08:00–02:00 (Windows' 18-hour maximum), no "get me up to
    date" forced restarts, and a heads-up before any restart.
  - **Pause updates (5 weeks):** the same pause as Settings. Settings' "Resume updates" still works.
  - **Turn updates off (Expert Mode):** a one-year pause. Ronin reminds you every 30 days with a
    banner: **TURN BACK ON** or **REMIND ME IN 30 DAYS**.
  - A status line shows exactly what's set: "Updates paused until 25 Dec 2026 (35 days left)".
- **Startup Apps** (Declutter tab). Every app that starts with Windows, each with an on/off switch.
  It's the same switch as Task Manager's Startup tab, so nothing is uninstalled or deleted and you
  can flip it back any time.
- **Install Apps** (Declutter tab). Tick apps from a checked list of 43 — browsers, game launchers
  (Steam, Epic, GOG, EA, Ubisoft, Heroic, Playnite), Discord, OBS, Moonlight/Sunshine, VLC, 7-Zip,
  PowerToys, hardware monitors, game runtimes (Visual C++, .NET, DirectX) and developer tools — and
  Ronin installs them silently with winget, Microsoft's package manager. Every package ID was
  checked against Microsoft's winget repository. This is the only Ronin feature that uses the
  internet, and only after a two-step confirm. Already-installed apps are skipped.
- **Windows Tools** (Declutter tab). One-click shortcuts to Control Panel, Device Manager, Network
  adapters, Power plans, Sound, Programs, Services, Disk Management, Event Viewer and System
  Properties.
- **Older-game support** (Advanced Tools > Windows Features): **Add .NET Framework 3.5** and **Add
  DirectPlay**, the two components 2000s-era games most often ask for. Both revert; DirectPlay's
  revert also turns Legacy Components back off if Ronin turned them on.
- **Hide Recent Files** and **Keep My Default Printer** (Declutter): stop Start, File Explorer's Home and
  Jump Lists listing your recent files, and stop Windows switching your default printer to the last one
  you used. Both are Settings switches; originals are recorded and restored.
- **Disable Inking & Typing Personalization** (Privacy Shield): the Settings switch that lets Windows
  collect your handwriting, typing and contact names to build a personal dictionary. Original values
  are recorded and restored exactly.
- **Quiet Microsoft Edge** also turns off Microsoft Rewards offers and the "make Edge your default" and
  Edge Insider promotions. **Disable Paint/Office AI** now also switches off Notepad's AI features
  through Notepad's own policy.
- **Removed apps are now recorded.** Apps the Debloat Center removes are listed under Maintenance >
  Changes made by Ronin, with the date. Ronin can't reinstall them; the tooltip says where to get
  them back.
- **Honest edition notes.** When your Windows edition ignores a setting, the tweak's description
  says so (e.g. Home and Pro treat telemetry level 0 as level 1).

### Fixed
- **Status checks now work on every Windows display language.** Eight power-related checks (and
  the CPU boost / energy preference / PCIe readouts) read English text from `powercfg`, so on
  non-English Windows applied tweaks showed as off. They now read the language-independent values.
  The "Windows undid your tweaks" alert, which 7.6 switched off entirely on non-English Windows, now
  works there too (it skips only the two checks that still read English text).
- **"Stop Game Bar Writer" always showed as applied** on current Windows builds, applied or not.
  It now reports the real state, and undo restores your original Game Bar recording setting.
- **CHECK GPU DRIVERS did nothing on most NVIDIA and AMD PCs.** Without the vendor app installed it
  asked winget for "Nvidia.GeForceExperience" / "AMD.Adrenalin.Edition", and neither exists in
  winget, so nothing happened. It also only looked at the first graphics adapter, which on gaming
  laptops is the integrated one. It now checks every GPU, opens the NVIDIA app / AMD Software if
  installed, and otherwise opens the vendor's official driver page in your browser.
- **AUTO DISK CLEANUP cleaned nothing.** It ran Windows Disk Cleanup with a saved profile that
  nothing had ever filled in, so every category was unticked. It now ticks a safe list of its own —
  temp files, caches, logs and crash dumps — and reports how much space it freed. It never touches
  Downloads, the Recycle Bin, Windows.old, old drivers, update rollback files or the Reset-this-PC
  image.
- **The DNS buttons only switched half of your DNS.** They set IPv4 servers only, so on dual-stack
  home networks (most ISPs now) Windows kept asking your ISP's IPv6 DNS. Cloudflare, Google and Quad9
  now set both. **AUTO is now UNDO / AUTO:** Ronin records each network adapter's own DNS before its
  first change, and this button puts exactly that back — including servers you had typed in yourself,
  which the old AUTO wiped.
- **REBUILD ICON CACHE didn't rebuild anything on Windows 10/11.** It deleted only the old
  `IconCache.db`; current Windows keeps the cache in `Explorer\iconcache_*.db`. It now clears both and
  lets Windows bring the taskbar back normally.
- **CLEAR DX/GL SHADER CACHE missed the caches most games use** (NVIDIA's DirectX cache and Windows'
  own D3D cache). It now clears every NVIDIA, AMD, Intel and Windows shader cache and reports how much.
- **RESET GPU DRIVER STACK ran a full, unscoped Disk Cleanup** as a side effect, and force-closed
  Steam/Epic (and any game they were running) without warning. It now cleans only the DirectX shader
  cache and asks for a second click first.
- **BIOS / UEFI and Recovery Menu restarted the PC on the first click**, with no warning, which could
  lose unsaved work in other apps. Both now ask "RESTART NOW?" first, with a save-your-work note.
- **RECLAIM SPACE no longer pops up a blocking dialog from the background engine** (the same kind
  of popup behind earlier freezes). Like the restart buttons, it now asks for a second click
  ("CONFIRM: PERMANENT CLEAN") with the warning in the console, and resets itself after 12 seconds.
- The "restart Explorer" banner said it was for Gallery and Home changes only.
- **Ticking "Disable Multiplane Overlay (MPO)" on its own did nothing**, while the summary reported
  success. "Force Legacy Flip Mode" is the same Windows setting; its unticked box, next in the batch,
  switched it straight back off. The two boxes now always change together.
- **Privacy Shield quietly undid other tweaks on every Apply.** With "Disable 'Click To Do' &
  Generative AI" ticked and "Purge 24H2 AI Telemetry Tasks" not, every Privacy Apply ran the purge's
  undo. That deleted Click To Do's setting (re-applied a moment later), the Inventory setting, and
  half of System Core's **Disable Windows Recall** policy, from a different tab. "Purge 24H2 AI
  Telemetry Tasks" now only touches its own tasks; values older versions wrote there are still
  cleaned up on undo, but only when their own tweak isn't on.
- **Undoing "Boost Touchscreen Response" also undid System Core's "Instant Menu Delay"** (they share
  one setting), and set a shutdown timeout your PC never had. Now each keeps the other, the shutdown
  timeout comes back exactly as it was, and the startup alert no longer blames a Windows update for
  a change Ronin made at your request.
- **"Remove '- Shortcut' text" could show as applied when it wasn't.** It checked only the length
  of the setting, not its value. Undo now restores the original value.
- **Undoing "Disable Search Indexing" set Windows Search to plain Automatic**; Windows ships it as
  Automatic (Delayed Start). Undo now restores whatever startup type your PC had.
- **"Ronin hasn't changed anything on…" was cut off** in the Changes by Ronin card (thanks for the
  report). The message wraps now.
- **The Information Dojo cut most descriptions off mid-sentence.** Its text box was a line and a half
  tall, so longer descriptions ran past the bottom of the window and under the "GREEN = OPTIMIZED"
  legend. It now has room for three full lines beside the legend (every description fits; the
  five longest were tightened), and the footer is no taller.
- The Apply preview counted "Disable MPO" and its twin as two changes and two restarts; it's one of each.
- **The Debloat Center offered to remove parts of Windows.** It hid a list of protected packages, but
  newer Windows packages fell outside it and were listed under raw package names: display-language
  packs, the Windows App Runtime (many modern apps need it), winget's own sources (which Install Apps
  and the VC++ button need), Gaming Services (Game Pass games), media codecs, handwriting recognition and
  WSL. None was pre-ticked, but one stray click could break things. They are now hidden. Driver and
  hardware apps (NVIDIA Control Panel, Realtek Audio Console, MSI Center...) are now labelled plainly.
- **"Remove Widgets from Taskbar" failed on current Windows 11 unless the button was already off.**
  Windows now protects the taskbar's Widgets button setting (the User Choice Protection Driver) and
  refuses changes to it from scripts, and the tweak's status check required that setting. The tweak
  now relies on the Widgets policy, which is what turns Widgets off, button included. It still changes the button
  setting where Windows allows it, and restarts Explorer once so the button disappears straight away.
  Ronin does not switch off Windows' protection.
- **Touch Mode didn't actually enlarge anything.** It applied its 130% scale where Windows ignores it,
  so all it did was make the window bigger (and on a small handheld screen, shorter, so everything got
  smaller). It now really scales the interface, by up to 130% depending on what your screen can fit. If
  Ronin already fills the screen, it says so and points to Windows' own display scaling.
- **Ronin now fits on small screens.** On a 7" 1080p handheld at Windows' default 150% scaling, the
  window was taller than the usable screen and its bottom (the info panel and the end of each tab) sat
  under the taskbar. It now opens sized to fit.
- **The info panel never showed anything on hover.** It was meant to fill with a tweak's description when
  you point at it, but it attached to the wrong part of each tab and found no switches, so it always
  said "Hover over any tweak". It works now, on every tab (right-click still pins a description).
- **Clearing a search left odd colours behind** (every label went light grey or green). Each control
  now gets its own colour back.
- **The banners lost their buttons in a narrow window.** At the smallest window size, the reset alert,
  update reminder, Explorer banner and engine warning pushed their buttons (KEEP IT MY WAY, REMIND
  ME IN 30 DAYS, LATER, SAVE BUG REPORT) off the edge. The message now wraps and the buttons stay put.
- **The new look opened 30 px too short.** The new layout is 760 px tall, but older startup code still forced
  the window to 730, so every tab was drawn about 4% smaller than designed (the automated checks measured
  the layout, not the running app). The window now opens at its designed size; a check stops it coming back.
- **Hovering a Maintenance button turned it light blue** with white text on it (also the DNS, Debloat /
  Startup / Install Apps, Battery / Sleep, banner and Settings buttons, and the changes list's UNDO).
  Those buttons were still using Windows' own button look; they now get a red edge on hover like the rest.
  Tooltips are dark too, instead of Windows' light grey box.
- **Apply looked like it hung (tester report).** The first click on Apply only previews; its confirm state
  was a slightly darker red with near-black text, and it quietly reset after 15 seconds. A tester clicked
  Apply, walked away, came back to an unchanged button and read the launcher console as "stuck". Nothing was
  wrong and nothing had been applied. The confirm is now **amber** and says what to do ("CLICK AGAIN: APPLY
  15 CHANGES"), and it **waits** until you click it, switch tabs, flip a switch or press DISCARD. That is
  safe: the confirm only ever applies the exact list it previewed.
- **The launcher console printed internal objects at startup** (ending in `Status : Pending`), which looked
  like something stuck. Those return values are now discarded, and the console starts **minimised** (still
  on the taskbar, not hidden) from both `Launch_Ronin.bat` and the online installer.
- **The reset alert said "undid 1 of your tweak".** It now says "undid one of your tweaks".
- **Undoing "Timer Optimization" on Portuguese Windows could force the platform clock on.** The check for
  the Portuguese "Não" never matched (a non-ASCII letter in a file Windows PowerShell reads as ANSI). A
  new check blocks any non-ASCII character in the source.

### Design — a new look
Same red-on-black terminal identity, sharpened. Every font ships with Windows 11 (Cascadia Mono,
Bahnschrift, Segoe UI Variable), so nothing new is bundled, and there is no compiled code.
- **New frame:** the search moved up into the title bar (**Ctrl+K**), with an engine light beside it
  (green online, amber working, red not responding). The RONIN logo is cut by a katana stroke, the
  menu items are numbered and show how many of each tab's switches are on, and the active tab gets a
  red chevron.
- **Rank card:** a hex badge with your tier, the score, and a C · B · A · S ladder showing where you stand.
- **One header for every tab:** title, a short description, and three counters for that tab: **ACTIVE**
  (switches on), **QUEUED** (changed here, not applied yet) and **REBOOT** (queued ones that need a restart).
- **Queued switches are amber.** Flip a switch and it turns amber with hazard stripes until you apply,
  so it's always clear what Apply will change. The Apply button says how many ("APPLY 3 CHANGES") and
  **DISCARD** puts everything back without touching the PC. The two switches that share one Windows
  flag (Disable MPO / Legacy Flip Mode) now move together on screen, as they already did when applied.
- **Switches:** labels are bright when on and grey when off. 8.0 coloured them green and the switches
  red, which read as "danger" and "good" at the same time.
- **Info panel:** shows the tweak's name and the exact registry value it writes
  (e.g. `HKLM\SOFTWARE\Microsoft\Windows\Dwm  OverlayTestMode = 5`).
- **Status bar:** the console's newest line, the open tab, live CPU / RAM and the Windows build. The
  caret blinks while the engine works. **LOG** opens the full console; **F5** runs the audit.
- **Cards:** dark cards with red-lit corners and angled section tags; faint CRT scanlines over the whole window.
- **Dialogs** (Debloat Center, Startup Apps, Install Apps, batch summary) are redrawn in the new look. They were
  still 7.x boxes in three different accent colours (red, blue, green). Now they share one frame: the header's
  red slash and condensed title, a dark card with red-lit corners, the main window's buttons (a red slab for
  the main action, outlined for the rest), its switches and tooltips, red `//` section tags in Install Apps,
  and a thin dark scrollbar instead of Windows' light grey one. Their two-step confirms (CONFIRM REMOVE,
  CONFIRM INSTALL) turn amber, like Apply's. The Declutter tab's APPS buttons that open them lost their
  old blue / red / green too.
- **Batch summary:** the counts are four tiles (APPLIED / REVERTED / ALREADY SET / FAILED) like the
  header's counters. A tile at 0 goes quiet; anything that failed turns the frame red and lists it.
- **Sizing:** the default window is 30 px taller (760) for the status bar, so no tab is drawn smaller than
  before. On a short screen (a 7" handheld at 150%) the header drops its description line and the info
  panel shows two lines, so the switches stay as large as before. Animations stop by themselves: the
  title cursor blinks six times, the caret only while the engine is working.

### Design
- **Maintenance is readable again.** Its layout was taller than the window, so the whole tab was
  drawn about 25% smaller, and it shrank further as the changes list grew. It's now three columns
  (Repair / Cleanup + Diagnostics / Changes by Ronin) at full size, with a fixed-height changes list.
- The sidebar fits its new eighth button without getting any smaller (nav buttons are a little shorter).
- **Advanced Tools and Handheld** were also drawn slightly smaller than intended. Advanced now fits
  at full size: the DNS card moved to the left column with a 2×2 button grid. Handheld is tighter,
  so it is shrunk much less.

### Reliability
- **UI freeze watchdog.** If Ronin's window ever stops responding for 30 seconds, the diagnostic log
  now records it, with the last button or action that ran, and records when it recovers. Bug
  reports from a frozen window now point straight at the cause.
- New automated checks block a release if an engine helper isn't reachable from the background
  engine, or if any check parses English command text again.
- Every new tweak is proven reversible by the dry-run from both starting points (setting absent,
  and setting already present).
- **No registry value has two owners any more.** A new build check blocks any value written by two
  tweaks unless both declare it, and blocks any status check that reads another tweak's value. Those
  two patterns caused the MPO and Privacy bugs above.
- Bug-report triage now names a job that crashed (the engine recovers from those now, so nothing else
  would show it), and no longer mistakes a long job like DISM for a frozen engine.
- **Cut-off text check.** The UI test now lays out every tab, dialog and banner (at the default and
  the smallest window size) and fails the build if any text or row is clipped.
- Recorded originals now keep binary and multi-line registry values intact; before, those came back
  as plain text.
- AUTO OPTIMIZE now builds its list from the same map the audit and health score use, instead of a
  second hand-copied list that could drift out of step.
- The Background Apps drop-down (System Core) now has a description in the info panel.
- The batch summary names a tweak that needs attention by its label ("Remove Widgets from Taskbar"), not
  its internal key ("Priv_Widgets", which stays in brackets for bug reports).
- Clearing the search box no longer makes locked tweaks (Expert Mode, other GPU vendors) look active.
- The Windows Update pause also sets Windows' own pause state (as pausing in Settings does), so it no
  longer depends on Windows re-reading the pause settings. Both are recorded and undone exactly.
- **No more false "ENGINE NOT RESPONDING" during long jobs.** RECLAIM SPACE (DISM can take 10-30
  minutes), Compact OS on handheld storage, the GPU reset, the Store reset, the Visual C++ install and big
  Debloat removals didn't tell
  the watchdog they were still working, so after 3 minutes it warned that the engine had hung. They now
  check in every second. Debloat removal is also faster: it reads Windows' provisioned-app list once
  instead of once per app.
- **The console stayed on "PLEASE WAIT..." after the audit had finished** (thanks for the report). Messages
  the background engine sent to the window while it was busy were silently lost, so "System Audit
  Complete." and later lines never appeared. The same could drop the "Windows undid your tweaks" and "Restart
  Explorer" banners. The engine now leaves messages in a mailbox that the window collects itself, several
  times a second, so nothing is lost. A new build check keeps it that way.
- **"Apply 'Ronin' Visuals" did nothing.** It only set which radio button Performance Options shows; the
  actual effects are separate settings. It now turns off animations, shadows, window-drag previews and Aero
  Peek (the widely used performance-visuals set), keeps smooth fonts and thumbnails, and restores every
  original exactly. Full effect after you sign out and back in.
- **No false alarm after updating Ronin.** Some tweaks are now checked more accurately (VRR, Visuals, AI
  telemetry). On a PC where an older Ronin had "applied" them, they'd read as off and Ronin would have
  claimed a Windows update undid them. The first launch after an update now says so plainly in the console
  instead, with no banner.
- **"Force Variable Refresh Rate" did nothing, and switched off Auto HDR.** Windows keeps several graphics
  settings in one value; the tweak replaced the whole value with a setting name Windows doesn't read. So it
  never turned VRR on, and it switched off Auto HDR and "Optimizations for windowed games" if you had them
  on (undo didn't bring them back). It now changes only the VRR setting and leaves the others as they
  are. If an older Ronin version cleared Auto HDR / windowed-game optimizations on your PC, turn them
  back on in Settings > Display > Graphics.
- **Taskbar and context-menu tweaks now show straight away.** Classic Context Menu, Clean Context Menu,
  taskbar alignment / combining / buttons / clock seconds / End Task, Meet Now, Copilot button, Start ads and
  the This PC / duplicate-drive cleanups only take effect when Explorer restarts. Ronin didn't restart it for
  them, so they looked like they hadn't worked until you next signed in. Explorer now restarts once after
  the batch (or Ronin asks first, if you chose that in Settings).
- **FULL SYSTEM REPAIR ran its steps in the wrong order.** It ran SFC before DISM, and only continued if each
  step reported no problems, so the repair that SFC depends on was skipped exactly when it was needed.
  It now runs DISM RestoreHealth, then SFC, then a CHKDSK scan (Microsoft's order), each regardless.
- **SSD HEALTH AUDIT & TRIM never trimmed on encrypted drives.** It skipped TRIM whenever BitLocker /
  device encryption was on, which is the default on many laptops and handhelds. TRIM works on encrypted
  drives (Windows' own weekly optimisation does it), so it now always runs.
- **BATTERY REPORT and SLEEP STUDY** saved to a Desktop folder that doesn't exist when OneDrive backs up
  your Desktop, so nothing appeared. They now use your real Desktop, and say so plainly when a PC has
  no battery or no Modern Standby to report on.
- **INSTALL VISUAL C++ now installs the 32-bit runtime too.** It installed only the 64-bit one, but
  most "MSVCP140.dll / VCRUNTIME140.dll is missing" errors come from 32-bit games and launchers. It
  also runs winget without prompts (one could stall it invisibly) and reports each result.
- **Only one Ronin at a time.** Opening Ronin while it was already running (say, a double-click while
  the admin prompt was slow) started a second copy, and both changed the same settings and restarted
  Explorer. The second copy now brings the first window forward and closes.
- **The engine recovers if a job crashes.** Before, a job that failed in an unexpected way left Ronin
  thinking it was still running: that button (after a failed Apply, every Apply button) answered "Ignored
  duplicate request", and the tabs stayed greyed out, which looked like a freeze. Now it logs the error,
  re-enables the tabs and carries on.
- A second click on INSTALL or REMOVE while apps are still installing or being removed is now ignored,
  instead of queuing the whole job again.
- **Faster after Apply.** The re-check after a batch no longer re-runs the slow status checks (scheduled
  tasks, BitLocker, network adapters...) of tweaks the batch skipped as already set. It reuses the
  result it had just read. On Privacy Shield that saves a few seconds per Apply.

## [7.6.0] — 2026-11-12

**Includes everything from 7.5.0**, which was built but never published on its own. 7.4 was the
last public release before 8.0; if you are coming from it, read the 7.5.0 section too.

### Added
- **Ronin tells you when Windows undoes your tweaks.** Big Windows updates often switch tweaks back
  off without telling anyone. Ronin now remembers what it applied, and when you open it, it checks
  whether any of those were turned off since. If so, a banner says how many (and which Windows
  build did it, when the build changed), with three choices: **Re-apply**, **Show me** (lists them
  and opens the changes list), or **Keep it my way** (Ronin forgets them and won't ask again). Turn
  the alert off in Settings. On non-English Windows it stays off, because some status checks there
  can misread.
- **See before you apply.** Each tab's Apply button now asks for a second click and shows the
  count first: "CONFIRM 12 CHANGES", with the list of what will change in the console. If nothing
  would change, it says so and does nothing. Ticking or unticking anything resets it. You can switch
  this off in Settings for one-click applying.
- **Changes made by Ronin** (Maintenance). A list of every change Ronin made on this PC, newest
  first, with the date and an Undo button for each one. "Undo all changes" replaces the old
  reset button and works the same way as in 7.5 (only what Ronin changed).
- **Settings** (gear icon, top right). Choose which tab Ronin opens on, turn the Windows-update
  alert and the apply preview on or off, choose whether Explorer restarts automatically after
  Gallery/Home changes or only when you click, and find Save bug report, Open logs folder and Reset
  Ronin's settings in one place. Press Esc or click outside to close.
- **Ronin remembers your toggles.** Expert Mode, Touch Mode and Auto-Backup now stay how you left
  them between launches. Settings are kept in `C:\ProgramData\Ronin\settings.json` and included in
  bug reports.

### Fixed
- **Closing the Debloat Center could freeze Ronin.** Pressing CANCEL (or CONFIRM REMOVE) sometimes
  left the whole window unresponsive until it was force-closed — an old, intermittent bug going back
  to 7.3. The Debloat Center and the batch-summary popup were built by Ronin's background engine, and
  Windows PowerShell hands such a window's button clicks back to that busy engine; closing the window
  from there could hang the screen for good. Both popups are now built by the window itself. A new
  automated test reproduces the freeze (it fails against the old code) and the build now rejects any
  window or button handler created by the engine.
- The console's first line showed an old version number ("Ronin Engine 7.1") at every startup.

## [7.5.0] — 2026-11-11

*Built but never published as its own release; all of it ships inside 7.6.0.*

**Includes everything from 7.4.0.**

### Reliability (public-release hardening)
- **Double-clicks can no longer run things twice.** Every button that hands work to Ronin now
  goes through one gate: clicking Open Debloat Center twice used to open two Debloat windows,
  and a double-click on Full Repair, Reset All or an Apply button ran it twice. Repeats are now
  ignored, and the log says so.
- **Every revert is now checked.** After undoing a tweak, Ronin re-reads the setting to confirm
  it actually went back, exactly as it already did for Apply. Before, it reported "done" no matter
  what. A revert that doesn't stick now shows up in the summary by name.
- **No more blank screen in the middle of a batch.** Hiding Gallery or Home used to force-close
  Explorer on the spot, once per tweak. Ronin now restarts Explorer once, at the end, and tells
  you, and it starts Explorer itself if Windows doesn't bring it back.
- **Undo now restores what *your* PC had, not a guess.** A review of every tweak the automated
  checks can't cover found 15 whose undo wrote a fixed value instead of your original. These now
  remember your setting before changing it and put back exactly that:
  - **Power settings** — Wi-Fi power saving (undo used to set *maximum* power saving even when
    plugged in), Modern Standby networking, power-button action, USB suspend, wake timers,
    adaptive brightness, CPU min/max state and unattended sleep timeout.
  - **CPU Boost Mode and EPP dropdowns** now have an undo at all (Reset All skipped them).
  - **Memory Integrity** — undo no longer forces it *on* for PCs where it was never on.
  - **Platform clock (HPET)** — undo no longer forces HPET on, which Windows doesn't do by default.
  - **GPU Priority** — undo set it *below* the Windows default; and the tweak never applied its
    real change, because it only checked a value that's already the default.
  - **GPU interrupt mode** — undo no longer removes the MSI setting your graphics driver sets itself.
  - **Device Guard / Credential Guard**, and the **NTFS 8.3-name / last-access** settings.
  - **Ultimate Performance** — no longer adds another duplicate "Ultimate Performance" plan to
    Power Options on every apply (and now actually activates), and undo returns you to the plan
    you were on instead of Balanced.
  - **Location**, **Feedback/DiagTrack** and **AI telemetry** undos no longer leave settings behind.
- **Drive decryption no longer risks freezing the app.** Its confirmation used to appear from the
  background engine; it now appears before anything starts, and decryption can't begin without it.
- **Non-English Windows:** Ronin now says at startup that some status checks read English command
  output and may show tweaks as not applied. Applying and reverting work in any language.
- **"Reset All Tweaks to Default" no longer changes things you set yourself.** It used to run every
  undo in the app whether or not Ronin had changed that setting — on a PC where you had turned on
  WSL or Hyper-V yourself, "reset" turned them *off*, and it also re-enabled Recall, turned
  hibernation on and could flip dark mode, file extensions and taskbar alignment. Ronin now keeps a
  record of what it actually changed, and Reset All undoes exactly that, as a normal batch (each
  undo checked, Explorer restarted once, summary at the end). It also tells you how many changes it
  will undo before it starts.
- **Auto-Backup no longer claims a restore point it didn't make.** Windows allows only one restore
  point per 24 hours; a second batch the same day used to log "Restore point created." anyway. Ronin
  now checks, and says when Windows declined.
- **"Disable Network Adapter Power Saving" now actually works.** It passed a value Windows doesn't
  accept, so it never changed anything, and its status check looked only at the first adapter —
  often a leftover from hardware you no longer have. It now sets every connected adapter and checks
  them all.
- **DNS buttons work without an internet connection** — usually exactly when you need them.
- Confirmation prompts (Reset All, repair install, closing during decryption) now always appear on
  top of Ronin instead of possibly behind it.
- Removed `RoninSnapshotTool.ps1`: nothing in Ronin opened it, and its "restore all" relied on data
  that wasn't reliable.

### Performance
- **Much lighter while idle.** Ronin was querying Windows Management (WMI) every second just to show
  RAM usage, checking the power-event log every second, and re-running a ~5-second BitLocker query
  every few seconds even when no drive was encrypting. Idle background work is now a small fraction
  of what it was.
- **Faster startup audit** (about 8.8 s → 3.7 s on the test PC): the slow BitLocker check now runs
  in parallel instead of holding up the audit, the CPU name is read instantly instead of via a
  1-second query, and vendor checks skip straight past apps that aren't installed.
- **Faster audits after applying tweaks:** checks marked as slow are now remembered for the session
  (and refreshed whenever you change that tweak or click Run System Audit).

### Added
- **The app now tells you when it has stopped responding.** A background watchdog watches the
  engine's heartbeat; if it stalls, a banner appears naming the last operation it was running,
  with a one-click **Save Bug Report**. Previously a frozen engine looked like a working app,
  so the only options were to wait or kill it — and killing it took the evidence with it.
- **Save Bug Report (Maintenance → Diagnostics & Recovery).** Collects every Ronin log into a
  single zip on your Desktop and opens the folder with it selected. Nothing is uploaded — the
  file stays on your PC until you choose to send it. It is written without help from the
  background engine, so it still works when the app has locked up, and it now includes the
  UI-error log that no bug report used to contain.

### Changed
- The three vendor-launcher tweaks are renamed from "Optimize *X*" to **"Stop *X* Auto-Start"**.
  They demote the vendor's background service, and on a handheld that service can be what
  controls fan curves and TDP — "Optimize" undersold what you were agreeing to.
- **14 handheld tweaks that had no description now have one**, including all three vendor
  entries above, each stating the trade-off and how to undo it.

### Fixed
- "Stop Armoury Crate Auto-Start" and "Stop MSI Center M Auto-Start" reported **"needs
  attention"** after a successful apply. They lowered the service to manual start but left it
  running, which is not the state the app then checked for; they now stop the service too.
- Reverting those two set the service to **Automatic** regardless of how it started out, so on
  a PC where it shipped as Manual or Disabled, "revert" quietly changed a setting instead of
  restoring it. The original startup type is now recorded when you apply and restored exactly
  when you revert. Revert also no longer force-starts a service that was never running.
- "Stop Legion Space Auto-Start" removed Legion Space's start-up entries but **never put them
  back** — reverting re-enabled its scheduled task only, so Legion Space still didn't start
  with Windows. The original entries are now recorded and restored.
- **"Restore Windows Photo Viewer" could not be undone.** Reverting tried to delete the file
  association it had written, but Windows silently ignores that kind of deletion, so .jpg and
  .png stayed pointed at Photo Viewer forever. Ronin now remembers what those file types were
  set to beforehand and puts it back exactly (or removes the entry it created, if there wasn't
  one). Same fix for **"Remove Duplicate Drive Entries"**, which had the identical flaw.
- **"Fix NVMe Sector Alignment (4K)" reported itself backwards.** Its status check was
  inverted, so the toggle looked already-applied on every PC, and actually applying it then
  reported "needs attention" even though it had worked.

### Developer tooling (not shipped in the app)
- The reversibility harness can now sweep the **entire** tweak database in one run instead of
  one tweak at a time, choosing the correct starting state per tweak, and it fails loudly if
  anything no longer round-trips. Fixing it also closed a hole where it could write to the
  live registry instead of its sandbox.

## [7.4.0] — 2026-07-03

*Built but never published as its own release; all of it ships inside 7.5.0.*

### Performance
- System audit and Apply/Revert batches are much faster after the first run. A handful of
  status checks were expensive (the BitLocker/`Win32_EncryptableVolume` query alone took ~5s,
  plus the network-adapter and scheduled-task lookups), and the audit re-runs after every
  batch — so those seconds were paid repeatedly. Those few slow checks are now cached for the
  session (cleared automatically when you apply the related tweak or hit Run System Audit),
  cutting a full audit from ~8s to under 2s on repeat runs.

### Added
- **Debloat Center (System Core)** — replaces the old all-or-nothing bloatware checkbox
  with a professional removal menu: scans the apps actually installed on your machine,
  pre-selects known junk (Bing apps, Office promos, Teams, third-party stubs like TikTok
  and Candy Crush), never pre-selects Xbox / Game Pass apps, and removes only what you
  confirm. Includes Recommended / Clear All quick-selects, a live selection counter, and
  per-app progress and results in the console. Critical packages (Store, winget, Defender
  UI, Terminal) are never shown. OneDrive desktop is offered as an optional entry.
  Also lists Dev Home, Quick Assist, and Start Experiences with friendly names.
- **Console mode (Gaming → Console Mode):** *Boot to Steam Big Picture* boots the PC straight
  into Steam Big Picture's controller UI at startup — a living-room console front-end that
  works on **any** hardware (desktop, laptop, or handheld), not just handhelds. Reworked from
  the old handheld-only "Steam Deck UI" toggle and moved to the Gaming tab so HTPC/desktop
  users can find it. Fully reversible; requires Steam installed.
- **Two new Privacy Shield tweaks** (safe subset of RemoveWindowsAI, registry-only,
  fully reversible): *Block Copilot in Edge* (stops Copilot reading page content,
  hides the chat icon) and *Disable Paint/Office AI & Hide AI Settings* (Paint Image
  Creator / Cocreator / Generative Fill policies, Office AI training opt-out, hides
  the 'AI Components' Settings page).

### Removed
- "Enable Network Buffer Tuning" (Game_NetTuning) — its verification depended on NetDMA, which
  Microsoft removed from Windows years ago, so it could never report as applied. RSS (its other
  setting) is already on by default on modern multi-core Windows, so the tweak no longer earned
  its place.

### Fixed
- "Enable Xbox Full Screen Experience" couldn't be reverted after the first apply/revert
  cycle: its revert read the shared snapshot cache, which the revert's own cleanup then
  re-poisoned with the applied value, so later reverts restored the value instead of
  removing it. Revert is now deterministic via a dedicated marker (everything reverts).
- System audit could intermittently freeze the app: handheld detection ran a WMI query
  on the UI thread mid-audit, and WMI can stall for seconds. Detection now runs once at
  startup and is cached; console logging is non-blocking and length-capped so log bursts
  during an audit no longer serialize the engine against the UI.
- Batch summary dialog required two clicks on OK - the unfocused window ate the first
  click as activation. Dialogs now activate and focus on open (Debloat Center too).
- Engine thread could deadlock (silently freezing all background jobs) when building
  dialogs from the engine: nested scriptblock evaluation inside a Dispatcher delegate.
  Affected the Debloat Center on open and the batch summary when failures were listed.
- Debloat Center "Remove Selected" froze the app at the confirmation prompt. The modal
  message box is gone entirely - the button now arms to a red "CONFIRM REMOVE (N)" and a
  second click executes (changing the selection disarms it). Reclaim Space's confirm
  prompt now appears on top of the window instead of potentially behind it.

### Diagnostics
- Engine writes a heartbeat line to the diagnostic log every 60 seconds, Debloat Center
  buttons log their clicks, and dialog construction is bracketed in the log - so any
  future freeze shows exactly where things stopped.
- Registry writes that fail no longer fail silently: the log names the exact key, value,
  and error. "Applied but didn't verify" reports now explain themselves (the Widgets
  tweak additionally reports which of its two values didn't stick).
- Log timestamps now include the date, so multi-day logs and bug-report bundles are
  unambiguous about when something actually happened.

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

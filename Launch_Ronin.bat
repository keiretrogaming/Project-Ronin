@echo off
Title Project Ronin Launcher
echo Requesting Administrator privileges...

:: Check for Admin rights
net session >nul 2>&1
if %errorLevel% == 0 (
    goto :RunRonin
) else (
    echo Elevating permissions...
    powershell -Command "Start-Process cmd -ArgumentList '/c \"%~dpnx0\"' -Verb RunAs"
    exit
)

:RunRonin
echo Launching Project Ronin...
:: Runs the self-contained monolith. -ExecutionPolicy Bypass is scoped to this process
:: only and makes no permanent system change. No -WindowStyle Hidden, to avoid AV
:: "evasion" heuristics. 8.0: started MINIMISED (still on the taskbar) - testers read its
:: startup text as Ronin's status ("cmd popped up, hung there"). Ronin shows its own errors
:: in a message box, and nothing ever waits for console input.
start "Project Ronin" /min powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Ronin.ps1"

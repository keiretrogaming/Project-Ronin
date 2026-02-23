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
:: STANDARD PRACTICE: Removed Hidden flag to avoid AV "Evasion" triggers.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0src\Ronin.ps1"
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
:: Temporarily bypass execution policy and run the script from the /src folder
powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0src\Ronin.ps1"
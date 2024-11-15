@echo off
set currentPath=%~dp0
:: Check for administrative privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/c %~f0 %*' -Verb RunAs"
    exit /b
)

powershell.exe -ExecutionPolicy Bypass -File %currentPath%scripts\USB-copier-config.ps1


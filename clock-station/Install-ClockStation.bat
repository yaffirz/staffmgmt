@echo off
rem Double-click to set up this PC as a Clock-in Station.
rem Runs the PowerShell installer (which will request admin rights).
setlocal
set "HERE=%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%HERE%Install-ClockStation.ps1" %*

@echo off
rem Build ClockInStationSetup.exe from ClockInStation.iss using Inno Setup 6.
rem Requires Inno Setup 6 (https://jrsoftware.org/isdl.php). Optionally drop the
rem HID installers in .\vendor first so they're bundled into the .exe.
setlocal
set "ISCC="
for %%P in (
  "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
  "%ProgramFiles%\Inno Setup 6\ISCC.exe"
) do if exist "%%~P" set "ISCC=%%~P"

if "%ISCC%"=="" (
  echo Inno Setup 6 not found. Install it from https://jrsoftware.org/isdl.php
  echo or: winget install -e --id JRSoftware.InnoSetup
  exit /b 1
)

"%ISCC%" "%~dp0ClockInStation.iss"
echo.
echo Output: %~dp0dist\ClockInStationSetup.exe

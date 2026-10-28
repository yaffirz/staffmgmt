<#
.SYNOPSIS
    Sets up a Windows PC as a fingerprint Clock-in Station for the Staff Portal.

.DESCRIPTION
    Does the three things a station needs:
      1. Installs the HID DigitalPersona reader driver + Authentication Device
         Client (the local agent the browser talks to) from .\vendor, if present
         and not already installed.
      2. Creates a kiosk launcher that opens the Clock-in Station full-screen in
         Microsoft Edge (or Chrome), plus a Desktop shortcut.
      3. Optionally auto-starts the station at logon.

    HID's installers are NOT redistributed here - download them once from HID and
    drop them in .\vendor (see vendor\README.txt). The script runs whatever it
    finds there; if the agent is already installed it skips that step.

.PARAMETER Url
    The Clock-in Station URL. Default is the public portal's kiosk route.

.PARAMETER AutoStart
    Also launch the station automatically at Windows logon.

.PARAMETER SkipHid
    Skip the HID driver/agent step (already installed).

.EXAMPLE
    .\Install-ClockStation.ps1
    .\Install-ClockStation.ps1 -Url "https://gbgstaff.atmix.io/?kiosk=1" -AutoStart
#>
[CmdletBinding()]
param(
    [string]$Url = "https://gbgstaff.atmix.io/?kiosk=1",
    [string]$VendorDir = (Join-Path $PSScriptRoot "vendor"),
    [switch]$AutoStart,
    [switch]$SkipHid,
    [switch]$NoPause
)

$ErrorActionPreference = "Stop"

function Write-Step([string]$msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok([string]$msg)   { Write-Host "    [OK] $msg" -ForegroundColor Green }
function Write-Warn2([string]$msg){ Write-Host "    [! ] $msg" -ForegroundColor Yellow }

# --- Re-launch elevated if needed (driver/agent install + startup need admin) ---
$isAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Requesting administrator rights..." -ForegroundColor Yellow
    $argList = @("-ExecutionPolicy","Bypass","-File","`"$PSCommandPath`"","-Url","`"$Url`"","-VendorDir","`"$VendorDir`"")
    if ($AutoStart) { $argList += "-AutoStart" }
    if ($SkipHid)   { $argList += "-SkipHid" }
    if ($NoPause)   { $argList += "-NoPause" }
    Start-Process powershell.exe -Verb RunAs -ArgumentList $argList
    return
}

Write-Host "================ Staff Portal - Clock-in Station setup ================" -ForegroundColor White
Write-Host "URL: $Url"

# --- 1. HID reader driver + Authentication Device Client -------------------
function Test-HidAgent {
    $svc = Get-Service -Name "DpHost" -ErrorAction SilentlyContinue
    if (-not $svc) {
        $svc = Get-Service -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -match "Authentication Device|DigitalPersona" } |
            Select-Object -First 1
    }
    return $svc
}

if ($SkipHid) {
    Write-Step "Skipping HID install (requested)."
} else {
    Write-Step "Checking the HID fingerprint agent..."
    $agent = Test-HidAgent
    if ($agent) {
        Write-Ok "HID agent service present: '$($agent.DisplayName)' ($($agent.Status))."
        if ($agent.Status -ne "Running") {
            try { Start-Service $agent.Name; Write-Ok "Started the agent service." }
            catch { Write-Warn2 "Could not start the agent service: $_" }
        }
    } else {
        Write-Warn2 "HID agent not found. Looking for installers in: $VendorDir"
        if (Test-Path $VendorDir) {
            $installers = Get-ChildItem -Path $VendorDir -Include *.exe,*.msi -File -Recurse -ErrorAction SilentlyContinue |
                Sort-Object Name
            if ($installers) {
                foreach ($inst in $installers) {
                    Write-Step "Running installer: $($inst.Name)  (follow its prompts)"
                    if ($inst.Extension -ieq ".msi") {
                        Start-Process msiexec.exe -ArgumentList "/i `"$($inst.FullName)`"" -Wait
                    } else {
                        Start-Process $inst.FullName -Wait
                    }
                }
                Start-Sleep -Seconds 3
                $agent = Test-HidAgent
                if ($agent) {
                    Write-Ok "HID agent now present: '$($agent.DisplayName)'."
                } else {
                    Write-Warn2 "Still not detecting the HID agent - install the driver + Authentication Device Client, then re-run with -SkipHid."
                }
            } else {
                Write-Warn2 "No .exe/.msi found in vendor. See vendor\README.txt for the two HID downloads, drop them there, and re-run."
            }
        } else {
            Write-Warn2 "No vendor folder. Create '$VendorDir', add the HID driver + Authentication Device Client, and re-run. (See vendor\README.txt.)"
        }
    }
}

# --- 2. Kiosk launcher + Desktop shortcut ----------------------------------
Write-Step "Creating the kiosk launcher..."

function Resolve-Browser {
    $edge = @(
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($edge) { return @{ Path = $edge; Kind = "edge" } }
    $chrome = @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($chrome) { return @{ Path = $chrome; Kind = "chrome" } }
    return $null
}

$browser = Resolve-Browser
if (-not $browser) { throw "Neither Microsoft Edge nor Google Chrome was found. Install one, then re-run." }

# A dedicated browser profile keeps the kiosk clean and separate. Use the cmd-time
# %LOCALAPPDATA% so it resolves to whichever user actually launches the station.
$profileArg = '%LOCALAPPDATA%\ClockStation\browser'

if ($browser.Kind -eq "edge") {
    $browserArgs = "--kiosk `"$Url`" --edge-kiosk-type=fullscreen --no-first-run --disable-features=TranslateUI --user-data-dir=`"$profileArg`""
} else {
    $browserArgs = "--kiosk `"$Url`" --no-first-run --disable-translate --user-data-dir=`"$profileArg`""
}

$launcher = Join-Path $PSScriptRoot "Launch-ClockStation.cmd"
$cmdLines = @(
    '@echo off',
    'rem Auto-generated by Install-ClockStation.ps1 - opens the Clock-in Station full-screen.',
    ('start "" "{0}" {1}' -f $browser.Path, $browserArgs)
)
Set-Content -Path $launcher -Value $cmdLines -Encoding ASCII
Write-Ok "Launcher: $launcher  (browser: $($browser.Kind))"

function New-Shortcut([string]$linkPath, [string]$target) {
    $ws = New-Object -ComObject WScript.Shell
    $sc = $ws.CreateShortcut($linkPath)
    $sc.TargetPath = $target
    $sc.WorkingDirectory = (Split-Path $target)
    $sc.IconLocation = "$($browser.Path),0"
    $sc.Description = "Staff Portal - Clock-in Station"
    $sc.Save()
}

$desktop = [Environment]::GetFolderPath("Desktop")
$desktopLink = Join-Path $desktop "Clock-in Station.lnk"
New-Shortcut $desktopLink $launcher
Write-Ok "Desktop shortcut: $desktopLink"

# --- 3. Optional auto-start at logon ---------------------------------------
if ($AutoStart) {
    Write-Step "Enabling auto-start at logon..."
    $startup = [Environment]::GetFolderPath("Startup")
    New-Shortcut (Join-Path $startup "Clock-in Station.lnk") $launcher
    Write-Ok "Will launch automatically when this user signs in."
}

Write-Host "`n================ Done ================" -ForegroundColor White
Write-Host "Reader status:" -NoNewline
$agent = Test-HidAgent
if ($agent) {
    Write-Host " agent '$($agent.DisplayName)' ($($agent.Status))" -ForegroundColor Green
} else {
    Write-Host " agent NOT detected - install the HID driver + Authentication Device Client (vendor\README.txt)" -ForegroundColor Yellow
}
Write-Host "Launch the station from the Desktop shortcut 'Clock-in Station', or run:"
Write-Host "    `"$launcher`""
Write-Host "In the browser kiosk, press Alt+F4 to exit.`n"
if (-not $NoPause) { Read-Host "Press Enter to close" }

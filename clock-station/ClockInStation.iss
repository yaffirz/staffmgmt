; Inno Setup script — builds a single ClockInStationSetup.exe for a clock-in
; station PC. It installs the helper files, optionally bundles the HID installers
; you drop in .\vendor before building, and runs Install-ClockStation.ps1 to set
; up the HID agent + full-screen kiosk launcher.
;
; Build:  "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" ClockInStation.iss
;         (or run build.bat). Output lands in .\dist\ClockInStationSetup.exe

#define AppName "Staff Portal Clock-in Station"
#define AppVersion "1.0.0"
#define DefaultUrl "https://gbgstaff.atmix.io/?kiosk=1"

[Setup]
AppId={{B6B0F2B2-9C7E-4E55-9B1B-5C7C0C10CA11}}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Arif Asad Ali
DefaultDirName={autopf}\ClockStation
DefaultGroupName=Clock-in Station
DisableProgramGroupPage=yes
UninstallDisplayName={#AppName}
OutputDir=dist
OutputBaseFilename=ClockInStationSetup
Compression=lzma2
SolidCompression=yes
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern

[Files]
Source: "Install-ClockStation.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "README.md";                DestDir: "{app}"; Flags: ignoreversion
Source: "vendor\README.txt";        DestDir: "{app}\vendor"; Flags: ignoreversion
; Optional: HID driver + Authentication Device Client, IF you place them in
; .\vendor before building. Compilation still works when the folder is empty.
Source: "vendor\*.exe"; DestDir: "{app}\vendor"; Flags: ignoreversion skipifsourcedoesntexist
Source: "vendor\*.msi"; DestDir: "{app}\vendor"; Flags: ignoreversion skipifsourcedoesntexist

[Tasks]
Name: "autostart"; Description: "Launch the Clock-in Station automatically when this PC signs in"; GroupDescription: "Options:"

[Run]
; Runs the setup helper (HID install + kiosk launcher + shortcut). Inno is already
; elevated, so the script won't prompt again; -NoPause keeps it non-interactive.
Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\Install-ClockStation.ps1"" {code:GetPsArgs}"; \
  StatusMsg: "Setting up the Clock-in Station (installing reader software + kiosk launcher)..."; \
  Flags: waituntilterminated

[UninstallDelete]
Type: files; Name: "{app}\Launch-ClockStation.cmd"

[Code]
var
  UrlPage: TInputQueryWizardPage;

procedure InitializeWizard;
begin
  UrlPage := CreateInputQueryPage(wpSelectTasks,
    'Clock-in Station address',
    'Where should this station open?',
    'Enter the Clock-in Station web address. This is your Staff Portal URL with ' +
    '"?kiosk=1" on the end, which opens straight to the scan screen.');
  UrlPage.Add('Station URL:', False);
  UrlPage.Values[0] := '{#DefaultUrl}';
end;

function GetPsArgs(Param: String): String;
var
  Url: String;
begin
  Url := Trim(UrlPage.Values[0]);
  if Url = '' then
    Url := '{#DefaultUrl}';
  Result := '-NoPause -Url "' + Url + '" -VendorDir "' + ExpandConstant('{app}\vendor') + '"';
  if WizardIsTaskSelected('autostart') then
    Result := Result + ' -AutoStart';
end;

; Inno Setup script for Wave. Built by .github/workflows/windows.yml.
#define AppVersion GetEnv("WAVE_VERSION")
#if AppVersion == ""
  #define AppVersion "0.1.0"
#endif

[Setup]
AppId={{6B1E3C52-7A0D-4E63-9D0B-3F5C2A8E91D4}
AppName=Wave
AppVersion={#AppVersion}
AppPublisher=Pheenikks
AppPublisherURL=https://github.com/pheenikks/wave
DefaultDirName={autopf}\Wave
DefaultGroupName=Wave
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\dist
OutputBaseFilename=Wave-Setup
SetupIconFile=wave.ico
UninstallDisplayIcon={app}\Wave.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked
Name: "autostart"; Description: "Start Wave when I sign in (it waits in the tray)"

[Files]
Source: "..\dist\Wave\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{group}\Wave"; Filename: "{app}\Wave.exe"; Parameters: "--show"
Name: "{autodesktop}\Wave"; Filename: "{app}\Wave.exe"; Parameters: "--show"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "Wave"; ValueData: """{app}\Wave.exe"""; Flags: uninsdeletevalue; Tasks: autostart

[Run]
Filename: "{app}\Wave.exe"; Parameters: "--show"; Description: "Open Wave"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "taskkill"; Parameters: "/IM Wave.exe /F"; Flags: runhidden; RunOnceId: "StopWave"

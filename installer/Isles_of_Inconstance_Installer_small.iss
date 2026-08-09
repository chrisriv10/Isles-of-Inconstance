; Inno Setup script for Isles of Inconstance (small / itch.io build)
; Packages the reduced-audio Windows build from build/small/

#define MyAppName "Isles of Inconstance"
#define MyAppVersion "0.2.1"
#define MyAppPublisher "Christopher Rivera"
#define MyAppURL "https://github.com/chrisriv10/Isles-of-Inconstance"
#define MyAppExeName "Isles of Inconstance.exe"

[Setup]
AppId={{8A3B9C1E-5D4F-4A7E-9B2C-1D3E5F6A7B8C}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf64}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=..\
OutputBaseFilename=Isles_of_Inconstance_Setup_v{#MyAppVersion}_small
Compression=lzma2/ultra
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"; Flags: checkedonce

[Files]
Source: "..\build\small\Isles of Inconstance.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\small\Isles of Inconstance.pck"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\small\EOSSDK-Win64-Shipping.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\small\xaudio2_9redist.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\small\libeosg.windows.template_release.x86_64.dll"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

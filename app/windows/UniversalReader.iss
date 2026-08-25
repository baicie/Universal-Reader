; Inno Setup script for Universal Reader.
; The CI workflow supplies the Flutter release bundle as the source directory.
#define MyAppName "Universal Reader"
#define MyAppVersion GetEnv("RELEASE_VERSION")
#define MyAppTag GetEnv("RELEASE_TAG")
#define MyAppPublisher "Universal Reader"
#define MyAppExeName "app.exe"

[Setup]
AppId={{F5E6F0EA-2D22-4E6D-9B46-1D1CFC98A7E4}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\Universal Reader
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=.
OutputBaseFilename=universal-reader-{#MyAppTag}-windows-x86_64-setup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
UninstallDisplayIcon={app}\{#MyAppExeName}

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent

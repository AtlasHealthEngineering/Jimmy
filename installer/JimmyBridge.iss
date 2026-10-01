#define MyAppName "Jimmy Bridge"
#define MyAppVersion "0.4.5"
#define MyAppPublisher "KnowAtlas"
[Setup]
AppId={{A7D9D78B-33F2-4F5E-9D2E-1B39EBD44D51}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={localappdata}\JimmyBridge
DefaultGroupName=Jimmy Bridge
PrivilegesRequired=lowest
DisableProgramGroupPage=yes
OutputDir=output-045
OutputBaseFilename=Jimmy Bridge Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayName=Jimmy Bridge
[Files]
Source: "..\src\*"; DestDir: "{app}\src"; Flags: ignoreversion recursesubdirs
Source: "..\node_modules\*"; DestDir: "{app}\node_modules"; Flags: ignoreversion recursesubdirs
Source: "..\runtime\node.exe"; DestDir: "{app}\runtime"; Flags: ignoreversion
Source: "..\package.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\install.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\uninstall.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\support-check.ps1"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Jimmy Support Check"; Filename: "powershell.exe"; Parameters: "-NoProfile -STA -ExecutionPolicy Bypass -File ""{app}\support-check.ps1"""
Name: "{group}\Antigravity"; Filename: "{localappdata}\Programs\antigravity\Antigravity.exe"; Check: FileExists(ExpandConstant('{localappdata}\Programs\antigravity\Antigravity.exe'))

[Run]
Filename: "powershell.exe"; Parameters: "-NoProfile -STA -ExecutionPolicy Bypass -File ""{app}\install.ps1"""; Flags: waituntilterminated; StatusMsg: "Getting Jimmy ready..."

[UninstallRun]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\uninstall.ps1"""; Flags: runhidden waituntilterminated; RunOnceId: "JimmyBridgeUninstall"

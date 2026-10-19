#define MyAppName "Jimmy Bridge"
#define MyAppVersion "0.4.6"
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
OutputDir=output-046
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
Name: "{group}\Jimmy"; Filename: "powershell.exe"; Parameters: "-NoProfile -STA -ExecutionPolicy Bypass -File ""{app}\src\jimmy-chat.ps1"""
Name: "{userdesktop}\Jimmy"; Filename: "powershell.exe"; Parameters: "-NoProfile -STA -ExecutionPolicy Bypass -File ""{app}\src\jimmy-chat.ps1"""
Name: "{group}\Jimmy Support Check"; Filename: "powershell.exe"; Parameters: "-NoProfile -STA -ExecutionPolicy Bypass -File ""{app}\support-check.ps1"""
Name: "{group}\Antigravity"; Filename: "{localappdata}\Programs\antigravity\Antigravity.exe"; Check: FileExists(ExpandConstant('{localappdata}\Programs\antigravity\Antigravity.exe'))

[Run]
Filename: "powershell.exe"; Parameters: "-NoProfile -STA -ExecutionPolicy Bypass -File ""{app}\install.ps1"" {code:GetConsentMode}"; Flags: waituntilterminated; StatusMsg: "Getting Jimmy ready..."

[UninstallRun]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\uninstall.ps1"""; Flags: runhidden waituntilterminated; RunOnceId: "JimmyBridgeUninstall"

[Code]
// Consent is collected by the native installer BEFORE any files are installed.
var
  ConsentGranted: Boolean;

function InitializeSetup(): Boolean;
var
  ConsentFile: String;
begin
  Result := True;
  ConsentFile := ExpandConstant('{userappdata}\JimmyBridge\browser-consent-v1.json');
  if FileExists(ConsentFile) then Exit;
  if WizardSilent then begin
    Log('Jimmy setup aborted: silent install cannot grant browser consent.');
    Result := False;
    Exit;
  end;
  ConsentGranted := (MsgBox(
    'Authorize Jimmy to navigate websites, inspect pages, edit fields, preview and save drafts, and remember workflows without repeated tool prompts?' + #13#10 + #13#10 +
    'Publishing requires a separate local human approval. Deletion, purchases, payment, and account/security changes remain blocked. Website login and MFA may still be required.' + #13#10 + #13#10 +
    'Choose Yes to authorize Jimmy on this Windows account. Choose No to cancel setup.',
    mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES);
  if not ConsentGranted then Result := False;
end;

function GetConsentMode(Param: String): String;
begin
  if WizardSilent then Result := '-NoConsentUI'
  else if ConsentGranted then Result := '-ConsentGranted'
  else Result := '';
end;

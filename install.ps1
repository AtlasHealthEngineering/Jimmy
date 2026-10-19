param([switch]$NoConsentUI)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$helper=Join-Path $root 'src\approval-helper.ps1'
$startup=Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\JimmyBridgeApproval.cmd'
$node=Join-Path $root 'runtime\node.exe'
$antigravity=Join-Path $env:LOCALAPPDATA 'Programs\antigravity\Antigravity.exe'
function Resolve-Agy {
  $legacy=Join-Path $env:LOCALAPPDATA 'agy\bin\agy.exe'
  if(Test-Path $legacy){ return $legacy }
  $cmd=Get-Command agy -ErrorAction SilentlyContinue
  if($cmd -and (Test-Path $cmd.Source)){ return $cmd.Source }
  $pkgRoot=Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
  if(Test-Path $pkgRoot){
    $found=Get-ChildItem $pkgRoot -Directory -Filter 'Google.AntigravityCLI_*' -ErrorAction SilentlyContinue |
      ForEach-Object { Get-ChildItem $_.FullName -Recurse -Filter agy.exe -File -ErrorAction SilentlyContinue } |
      Select-Object -First 1
    if($found){ return $found.FullName }
  }
  return $null
}
function Resolve-Chrome {
  $candidates=@(
    'C:\Program Files\Google\Chrome\Application\chrome.exe',
    'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
    (Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe')
  )
  foreach($c in $candidates){ if($c -and (Test-Path $c)){ return $c } }
  return $null
}
function Install-WingetPackage([string]$id) {
  $winget=(Get-Command winget -ErrorAction SilentlyContinue)
  if(!$winget){ throw 'Windows App Installer (winget) is required. Run Windows Update, then retry Jimmy Setup.' }
  & $winget.Source install --id $id --exact --silent --accept-source-agreements --accept-package-agreements
  if($LASTEXITCODE -ne 0){ throw ('Could not install prerequisite: '+$id) }
}
if(!(Test-Path $node)){ throw 'Jimmy private runtime is missing. Re-download Jimmy Setup.' }
# One-time, per-Windows-user consent for routine browser work. No silent enrollment.
$consentDir=Join-Path $env:APPDATA 'JimmyBridge'
$consentPath=Join-Path $consentDir 'browser-consent-v1.json'
$consentScope='jimmy-browser-routine-v1'
$userSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$hasConsent=$false
if(Test-Path $consentPath){
  try {
    $savedConsent=Get-Content $consentPath -Raw | ConvertFrom-Json
    $hasConsent=($savedConsent.scope -eq $consentScope -and
      $savedConsent.userSid -eq $userSid -and $savedConsent.decision -eq 'allow')
  } catch { $hasConsent=$false }
}
if(!$hasConsent){
  if($NoConsentUI -or ![Environment]::UserInteractive){ throw 'Jimmy requires one-time interactive browser authorization during setup. Silent/headless setup cannot grant consent.' }
  Add-Type -AssemblyName System.Windows.Forms
  $explanation=@(
    'Authorize Jimmy for routine website work on this Windows account?'
    ''
    'Jimmy may open and inspect sites, navigate, edit ordinary fields, preview, save drafts and remember workflows without asking again. Those actions may change drafts or other non-published data on websites where you are signed in.'
    ''
    'Publishing requires a separate independent local-human approval. Deletion, purchases, billing, account/security and credential changes remain blocked. Website sign-in or MFA may still be necessary.'
    ''
    'Choose Yes to authorize. No cancels setup.'
  ) -join [Environment]::NewLine
  $decision=[System.Windows.Forms.MessageBox]::Show($explanation,'Jimmy - One-time browser authorization',
    [System.Windows.Forms.MessageBoxButtons]::YesNo,[System.Windows.Forms.MessageBoxIcon]::Information,
    [System.Windows.Forms.MessageBoxDefaultButton]::Button2)
  if($decision -ne [System.Windows.Forms.DialogResult]::Yes){ throw 'Jimmy browser authorization was declined. Routine MCP tools were not enrolled.' }
  New-Item -ItemType Directory -Force -Path $consentDir | Out-Null
  $receipt=[pscustomobject]@{scope=$consentScope;decision='allow';userSid=$userSid;consentedUtc=[DateTime]::UtcNow.ToString('o')}
  [IO.File]::WriteAllText($consentPath,($receipt|ConvertTo-Json -Depth 4),[Text.UTF8Encoding]::new($false))
}

$agy=Resolve-Agy
if(!$agy){ Install-WingetPackage 'Google.AntigravityCLI'; $agy=Resolve-Agy }
if(!(Test-Path $antigravity)){ Install-WingetPackage 'Google.Antigravity' }
if(!(Resolve-Chrome)){ Install-WingetPackage 'Google.Chrome' }
if(!$agy -or !(Test-Path $agy)){ throw 'Antigravity CLI installation did not complete.' }
if(!(Test-Path $antigravity)){ throw 'Antigravity installation did not complete.' }
if(!(Resolve-Chrome)){ throw 'Google Chrome installation did not complete.' }
[IO.File]::WriteAllText((Join-Path $root 'agy-path.txt'),$agy,[Text.Encoding]::UTF8)
$line='@echo off'+[Environment]::NewLine+'start "" /min powershell.exe -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+$helper+'"'
[IO.File]::WriteAllText($startup,$line,[Text.Encoding]::ASCII)
$oldEap=$ErrorActionPreference
$ErrorActionPreference='Continue'
$mcpList=(& $agy mcp list 2>&1 | Out-String)
$removeCode=0
if($mcpList -match '(?m)^jimmy-bridge\s'){ & $agy mcp remove jimmy-bridge 2>&1 | Out-Null; $removeCode=$LASTEXITCODE }
& $agy mcp add jimmy-bridge $node (Join-Path $root 'src\server.js') 2>&1 | Out-Null
$addCode=$LASTEXITCODE
$ErrorActionPreference=$oldEap
if($removeCode -ne 0){ throw 'Jimmy could not refresh its Antigravity registration.' }
if($addCode -ne 0){ throw 'Jimmy could not register with Antigravity.' }
# Pre-govern only Jimmy's routine MCP capabilities. Never grant generic command/file authority
# and never auto-approve protected publication capabilities.
$settingsDir=Join-Path $HOME '.gemini\antigravity-cli'
$settingsPath=Join-Path $settingsDir 'settings.json'
New-Item -ItemType Directory -Force -Path $settingsDir | Out-Null
try {
  if(Test-Path $settingsPath){ $settings=Get-Content $settingsPath -Raw | ConvertFrom-Json } else { $settings=[pscustomobject]@{} }
  if(!$settings.permissions){ $settings | Add-Member -NotePropertyName permissions -NotePropertyValue ([pscustomobject]@{}) }
  $routine=@(
    'mcp(jimmy-bridge/browser_open)','mcp(jimmy-bridge/browser_inspect)',
    'mcp(jimmy-bridge/browser_set_field)','mcp(jimmy-bridge/browser_safe_action)',
    'mcp(jimmy-bridge/browser_verify)','mcp(jimmy-bridge/browser_close)',
    'mcp(jimmy-bridge/memory_remember)','mcp(jimmy-bridge/memory_recall)',
    'mcp(jimmy-bridge/memory_outcome)','mcp(jimmy-bridge/memory_forget)'
  )
  # Calling a governed publish tool does NOT authorize publication. The server
  # still requires a separate, session-bound, short-lived local-human approval.
  # Preallow the MCP transport to avoid a redundant headless CLI permission prompt.
  $publishWorkflow=@('mcp(jimmy-bridge/request_publish)','mcp(jimmy-bridge/publish_status)','mcp(jimmy-bridge/execute_approved_publish)')
  $granted=@($routine + $publishWorkflow)
  $deny=@($settings.permissions.deny | Where-Object { $_ })
  foreach($permission in $granted){
    if($permission -in $deny -or 'mcp(jimmy-bridge/*)' -in $deny){
      throw ('Jimmy MCP permission is explicitly denied in Antigravity settings: '+$permission+'. Review the local deny rule before continuing.')
    }
  }
  $allow=@($settings.permissions.allow | Where-Object { $_ -and $_ -ne 'mcp(jimmy-bridge/*)' })
  $allow=@($allow + $granted | Select-Object -Unique)
  if($settings.permissions.PSObject.Properties.Name -contains 'allow'){ $settings.permissions.allow=$allow } else { $settings.permissions | Add-Member -NotePropertyName allow -NotePropertyValue $allow }
  $ask=@($settings.permissions.ask | Where-Object { $_ -and $_ -notin $granted })
  if($settings.permissions.PSObject.Properties.Name -contains 'ask'){ $settings.permissions.ask=$ask } else { $settings.permissions | Add-Member -NotePropertyName ask -NotePropertyValue $ask }
  [IO.File]::WriteAllText($settingsPath, ($settings | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
} catch { throw ('Jimmy could not establish its governed Antigravity permissions: '+$_.Exception.Message) }
Start-Process powershell.exe -ArgumentList @('-NoProfile','-STA','-WindowStyle','Hidden','-ExecutionPolicy','Bypass','-File',$helper)
$ErrorActionPreference='Continue'
$authOutput=(& $agy models 2>&1 | Out-String)
$authCode=$LASTEXITCODE
$ErrorActionPreference=$oldEap
$needsSignIn=($authCode -ne 0 -or $authOutput -match 'Please sign in')
if($needsSignIn){ Start-Process $agy }
if($needsSignIn){
  $notice="Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show('Jimmy Sign-In is open. Choose Google OAuth; your browser will open. After Google signs you in, copy the code it shows and paste it into Jimmy Sign-In. Finish the one-time Antigravity setup prompts, then close Jimmy Sign-In. No commands are required.','Jimmy needs one sign-in','OK','Information') | Out-Null"
} else {
  $notice="Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show('Jimmy is installed and connected. You can open Antigravity and start using Jimmy.','Jimmy is ready','OK','Information') | Out-Null"
}
$encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($notice))
Start-Process powershell.exe -ArgumentList @('-NoProfile','-STA','-EncodedCommand',$encoded)

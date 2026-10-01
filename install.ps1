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
  $protected=@('mcp(jimmy-bridge/request_publish)','mcp(jimmy-bridge/publish_status)','mcp(jimmy-bridge/execute_approved_publish)')
  $allow=@($settings.permissions.allow | Where-Object { $_ -and $_ -ne 'mcp(jimmy-bridge/*)' -and $_ -notin $protected })
  $allow=@($allow + $routine | Select-Object -Unique)
  if($settings.permissions.PSObject.Properties.Name -contains 'allow'){ $settings.permissions.allow=$allow } else { $settings.permissions | Add-Member -NotePropertyName allow -NotePropertyValue $allow }
  $ask=@($settings.permissions.ask | Where-Object { $_ })
  $ask=@($ask + $protected | Select-Object -Unique)
  if($settings.permissions.PSObject.Properties.Name -contains 'ask'){ $settings.permissions.ask=$ask } else { $settings.permissions | Add-Member -NotePropertyName ask -NotePropertyValue $ask }
  $settings | ConvertTo-Json -Depth 20 | Set-Content -Path $settingsPath -Encoding UTF8
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

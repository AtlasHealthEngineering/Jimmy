$ErrorActionPreference='SilentlyContinue'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$antigravity=Join-Path $env:LOCALAPPDATA 'Programs\antigravity\Antigravity.exe'
function Resolve-Agy {
  $saved=Join-Path $root 'agy-path.txt'
  if(Test-Path $saved){ $p=(Get-Content $saved -Raw).Trim(); if(Test-Path $p){ return $p } }
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
function Resolve-Browser {
  $candidates=@(
    'C:\Program Files\Google\Chrome\Application\chrome.exe',
    'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe',
    (Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe'),
    'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
    'C:\Program Files\Microsoft\Edge\Application\msedge.exe'
  )
  foreach($c in $candidates){ if($c -and (Test-Path $c)){ return $c } }
  return $null
}
$agy=Resolve-Agy
$browser=Resolve-Browser
$helper=Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*JimmyBridge*approval-helper.ps1*' -or $_.CommandLine -like '*jimmy-bridge*approval-helper.ps1*' }
$registered=$false
if($agy){ $registered=((& $agy mcp list 2>$null) -match 'jimmy-bridge') }
$auth=$false
if($agy){
  $authOut=(& $agy models 2>&1 | Out-String)
  $auth=($LASTEXITCODE -eq 0 -and $authOut -notmatch 'Please sign in')
}
$installed=(Test-Path (Join-Path $root 'src\server.js'))
$runtime=(Test-Path (Join-Path $root 'runtime\node.exe'))
$ready=$installed -and $runtime -and [bool]$agy -and [bool]$browser -and $registered -and $auth -and [bool]$helper
$nl=[Environment]::NewLine
Add-Type -AssemblyName PresentationFramework
if($ready){
  $message='Jimmy is ready.'+$nl+$nl+'Installed: Yes'+$nl+'Browser: Ready'+$nl+'Antigravity: Signed in'+$nl+'Jimmy connected: Yes'+$nl+'Approval helper: Running'
  [System.Windows.MessageBox]::Show($message,'Jimmy Support Check','OK','Information') | Out-Null
} elseif($agy -and !$auth) {
  $choice=[System.Windows.MessageBox]::Show('Jimmy is installed, but Antigravity still needs your Google sign-in. Open sign-in now?','Jimmy needs sign-in','YesNo','Information')
  if($choice -eq 'Yes'){ Start-Process $agy -WindowStyle Hidden }
} else {
  $message='Jimmy needs attention.'+$nl+$nl+'Installed: '+$installed+$nl+'Private runtime: '+$runtime+$nl+'Browser: '+[bool]$browser+$nl+'Antigravity CLI: '+[bool]$agy+$nl+'Antigravity app: '+(Test-Path $antigravity)+$nl+'Jimmy connected: '+$registered+$nl+'Approval helper: '+[bool]$helper
  [System.Windows.MessageBox]::Show($message,'Jimmy Support Check','OK','Warning') | Out-Null
}

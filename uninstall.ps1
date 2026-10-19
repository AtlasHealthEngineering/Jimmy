$ErrorActionPreference='SilentlyContinue'
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$startup=Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\JimmyBridgeApproval.cmd'
Remove-Item $startup -Force -ErrorAction SilentlyContinue
# Uninstall revokes one-time consent and removes only Jimmy's own MCP grants.
$consentPath=Join-Path $env:APPDATA 'JimmyBridge\browser-consent-v1.json'
Remove-Item $consentPath -Force -ErrorAction SilentlyContinue
$settingsPath=Join-Path $HOME '.gemini\antigravity-cli\settings.json'
if(Test-Path $settingsPath){
  try {
    $settings=Get-Content $settingsPath -Raw | ConvertFrom-Json
    if($settings.permissions){
      foreach($key in @('allow','ask')){
        if($settings.permissions.PSObject.Properties.Name -contains $key){
          $existing=@($settings.permissions.$key)
          $settings.permissions.$key=@($existing | Where-Object { $_ -and $_ -notmatch '^mcp\(jimmy-bridge/' })
        }
      }
      [IO.File]::WriteAllText($settingsPath,($settings|ConvertTo-Json -Depth 20),[Text.UTF8Encoding]::new($false))
    }
  } catch {}
}

$saved=Join-Path $root 'agy-path.txt'
$agy=$null
if(Test-Path $saved){ $candidate=(Get-Content $saved -Raw).Trim(); if(Test-Path $candidate){ $agy=$candidate } }
if(!$agy){ $legacy=Join-Path $env:LOCALAPPDATA 'agy\bin\agy.exe'; if(Test-Path $legacy){ $agy=$legacy } }
if(!$agy){
  $pkgRoot=Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
  if(Test-Path $pkgRoot){
    $found=Get-ChildItem $pkgRoot -Directory -Filter 'Google.AntigravityCLI_*' -ErrorAction SilentlyContinue |
      ForEach-Object { Get-ChildItem $_.FullName -Recurse -Filter agy.exe -File -ErrorAction SilentlyContinue } | Select-Object -First 1
    if($found){ $agy=$found.FullName }
  }
}
if($agy){ $list=(& $agy mcp list 2>&1 | Out-String); if($list -match '(?m)^jimmy-bridge\s'){ & $agy mcp remove jimmy-bridge 2>&1 | Out-Null } }
Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -match '(?i)-File\s+"?[^"]*approval-helper\.ps1' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Remove-Item $saved -Force -ErrorAction SilentlyContinue

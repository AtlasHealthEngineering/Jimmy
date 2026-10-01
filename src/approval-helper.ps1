$ErrorActionPreference = "Continue"
$dir = Join-Path $env:USERPROFILE ".jimmy-bridge"
$pendingPath = Join-Path $dir "pending-publish.json"
$approvalPath = Join-Path $dir "publish-approval.json"
$logPath = Join-Path $dir "approval-ui.log"
$mutex = New-Object Threading.Mutex($false,"Local\JimmyBridgeApprovalHelper")
if (!$mutex.WaitOne(0,$false)) { Add-Content $logPath "DUPLICATE_HELPER_EXIT"; exit 0 }
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Content $logPath ((Get-Date -Format o) + " HELPER_STARTED_SINGLE")
$seenId = $null
while ($true) {
 Start-Sleep -Milliseconds 400
 if (!(Test-Path $pendingPath)) { continue }
 try { $p=Get-Content $pendingPath -Raw|ConvertFrom-Json } catch { continue }
 $now=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
 if ($now -ge [int64]$p.expires) { Remove-Item $pendingPath -Force -ErrorAction SilentlyContinue; Remove-Item $approvalPath -Force -ErrorAction SilentlyContinue; Add-Content $logPath "EXPIRED"; continue }
 if ($seenId -eq $p.id) { continue }
 if (Test-Path $approvalPath) { try { $a=Get-Content $approvalPath -Raw|ConvertFrom-Json; if ($a.id -eq $p.id) { $seenId=$p.id; continue } } catch {} }
 $seenId=$p.id
 $form=New-Object System.Windows.Forms.Form
 $form.Text="Jimmy Bridge - Publish Approval"; $form.Width=620; $form.Height=330
 $form.StartPosition="CenterScreen"; $form.TopMost=$true; $form.ShowInTaskbar=$true
 $label=New-Object System.Windows.Forms.Label; $label.Left=25; $label.Top=25; $label.Width=550; $label.Height=170
 $label.Font=New-Object System.Drawing.Font("Segoe UI",11)
 $changeText = if ($p.changes -and $p.changes.Count -gt 0) { ($p.changes | ForEach-Object { "- " + $_.field + ": " + $_.text }) -join "`r`n" } else { "- No field edits recorded in this bridge session" }
 $label.Text="Jimmy wants to publish these website changes.`r`n`r`nOperation: Publish`r`nPage: $($p.title)`r`nLocation: $($p.url)`r`nChanges:`r`n$changeText"
 $yes=New-Object System.Windows.Forms.Button; $yes.Text="APPROVE PUBLISH"; $yes.Left=275; $yes.Top=220; $yes.Width=145; $yes.Height=35
 $no=New-Object System.Windows.Forms.Button; $no.Text="CANCEL"; $no.Left=435; $no.Top=220; $no.Width=110; $no.Height=35
 $form.Controls.AddRange(@($label,$yes,$no)); $form.AcceptButton=$yes; $form.CancelButton=$no
 $script:decision="deny"; $script:expiredDuringDialog=$false
 $yes.Add_Click({$script:decision="approve";$form.Close()}); $no.Add_Click({$form.Close()})
 $timer=New-Object System.Windows.Forms.Timer; $timer.Interval=250
 $timer.Add_Tick({ if ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() -ge [int64]$p.expires) { $script:expiredDuringDialog=$true; $form.Close() } })
 Add-Content $logPath ("FORM_SHOW "+$p.id)
 $timer.Start(); $null=$form.ShowDialog(); $timer.Stop(); $timer.Dispose()
 $now=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
 if ($script:expiredDuringDialog -or $now -ge [int64]$p.expires) {
  Remove-Item $pendingPath -Force -ErrorAction SilentlyContinue
  Remove-Item $approvalPath -Force -ErrorAction SilentlyContinue
  Add-Content $logPath ("EXPIRED_DIALOG "+$p.id)
  continue
 }
 $record=@{id=$p.id;session=$p.session;decision=$script:decision;created=$now;expires=[Math]::Min([int64]$p.expires,($now+60000))}
 $json=$record|ConvertTo-Json -Compress
 [IO.File]::WriteAllText($approvalPath,$json,(New-Object Text.UTF8Encoding($false)))
 Add-Content $logPath ("DECISION "+$script:decision+" WRITTEN")
}

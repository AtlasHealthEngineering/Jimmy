Add-Type -AssemblyName PresentationFramework
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$agyPath=Join-Path $root 'agy-path.txt'
if(!(Test-Path $agyPath)){[System.Windows.MessageBox]::Show('Jimmy needs setup before chat can start.','Jimmy')|Out-Null;exit 1}
$agy=(Get-Content $agyPath -Raw).Trim([char]0xFEFF).Trim()
[xml]$xaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" Title="Jimmy" Height="620" Width="520" MinHeight="420" MinWidth="380" WindowStartupLocation="CenterScreen">
<Grid Margin="16"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
<StackPanel><TextBlock Text="Jimmy" FontSize="24" FontWeight="SemiBold"/><TextBlock Text="Ready" Opacity="0.6" Margin="0,2,0,12"/></StackPanel>
<ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto"><TextBlock Name="Conversation" TextWrapping="Wrap" FontSize="14"/></ScrollViewer>
<Grid Grid.Row="2" Margin="0,12,0,0"><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><TextBox Name="Input" MinHeight="42" Padding="10" VerticalContentAlignment="Center"/><Button Name="Send" Grid.Column="1" Content="Send" Width="72" Margin="8,0,0,0"/></Grid>
</Grid></Window>
'@
$reader=New-Object System.Xml.XmlNodeReader $xaml
$w=[Windows.Markup.XamlReader]::Load($reader);$c=$w.FindName('Conversation');$i=$w.FindName('Input');$b=$w.FindName('Send')
$send={
 $q=$i.Text.Trim();if(!$q){return};$i.Clear();$c.Text += "You: $q`n`n";$b.IsEnabled=$false
 try{
 $policy="You are operating through Jimmy Bridge. For website/browser work use only jimmy-bridge browser and memory tools. Recall Jimmy memory before rediscovering known workflows. Do not use shell, PowerShell, process inspection, filesystem search, generic URL tools, or credential discovery for routine website work. If authentication is required, navigate to the login page, ask the human to sign in, and wait. Protected publish/delete/account/security/billing/credential actions remain outside routine authority and must use Jimmy's protected approval path. User request: "+$q
 $out=& $agy -p $policy --print-timeout 120s 2>&1|Out-String;if($out -match 'Authentication required'){ $reply='Google sign-in is required. Jimmy will not switch to a paid API. Sign in to Antigravity, then try again.' } else {$reply=$out.Trim()};if(!$reply){$reply='Jimmy did not return a response.'}}
 catch{$reply='Jimmy could not complete that request. '+$_.Exception.Message}
 $c.Text += "Jimmy: $reply`n`n";$b.IsEnabled=$true;$i.Focus()
}
$b.Add_Click($send);$i.Add_KeyDown({if($_.Key -eq 'Enter'){& $send}});$w.ShowDialog()|Out-Null

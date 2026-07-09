$ErrorActionPreference = 'Stop'

# Relaunch as administrator if not elevated
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $scriptPath = $MyInvocation.MyCommand.Path
    Start-Process -FilePath 'powershell.exe' -ArgumentList @('-ExecutionPolicy', 'Bypass', '-NoProfile', '-File', $scriptPath) -Verb RunAs
    exit
}

Add-Type -AssemblyName PresentationFramework

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$startPs1 = Join-Path $scriptDir 'start.ps1'

# Launch GoodbyeDPI now (hidden)
& $startPs1

# Remove leftover shortcut from the old VBScript-based version
$shortcutPath = Join-Path ([Environment]::GetFolderPath('Startup')) 'GoodbyeDPI.lnk'
if (Test-Path -LiteralPath $shortcutPath) {
    Remove-Item -LiteralPath $shortcutPath -Force
}

# Create a scheduled task that runs start.ps1 at logon with highest privileges (no UAC prompt)
$taskName = 'GoodbyeDPI'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$startPs1`""
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -GroupId 'Users' -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -Hidden

if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null

[System.Windows.MessageBox]::Show("GoodbyeDPI has successfully started running in the background. It will also now run automatically on every startup so you don't have to run it every time.`r`n`r`nYou can now bypass all access barriers on the Internet. Long live freedom!", 'GoodbyeDPI', 'OK', 'Information')

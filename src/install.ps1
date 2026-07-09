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

# Launch GoodbyeDPI now (async - start.ps1 blocks on tray loop)
Start-Process -FilePath 'powershell.exe' -ArgumentList @('-ExecutionPolicy', 'Bypass', '-NoProfile', '-STA', '-WindowStyle', 'Hidden', '-File', $startPs1) -WindowStyle Hidden

# Remove leftover shortcut from the old VBScript-based version
$shortcutPath = Join-Path ([Environment]::GetFolderPath('Startup')) 'GoodbyeDPI.lnk'
if (Test-Path -LiteralPath $shortcutPath) {
    Remove-Item -LiteralPath $shortcutPath -Force
}

# Create a scheduled task that runs start.ps1 at logon with highest privileges (no UAC prompt)
$taskName = 'GoodbyeDPI'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -NoProfile -STA -WindowStyle Hidden -File `"$startPs1`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -UserId $env:USERNAME
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -Hidden -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null

[System.Windows.MessageBox]::Show("GoodByeDPI-Plus is now running in the background. Look for its icon in the system tray (near the clock).`r`n`r`nRight-click the tray icon to edit programs.txt or stop the service.`r`n`r`nIt will also start automatically on every logon. Long live freedom!", 'GoodByeDPI-Plus', 'OK', 'Information')

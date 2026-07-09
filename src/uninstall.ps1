$ErrorActionPreference = 'Stop'

# Relaunch as administrator if not elevated (needed for sc.exe / killing protected process)
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $scriptPath = $MyInvocation.MyCommand.Path
    Start-Process -FilePath 'powershell.exe' -ArgumentList @('-ExecutionPolicy', 'Bypass', '-NoProfile', '-File', $scriptPath) -Verb RunAs
    exit
}

Add-Type -AssemblyName PresentationFramework

$taskName = 'GoodbyeDPI'
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

# Remove leftover shortcut from the old VBScript-based version
$shortcutPath = Join-Path ([Environment]::GetFolderPath('Startup')) 'GoodbyeDPI.lnk'
if (Test-Path -LiteralPath $shortcutPath) {
    Remove-Item -LiteralPath $shortcutPath -Force
}

Stop-Process -Name 'goodbyedpi' -Force -ErrorAction SilentlyContinue
& sc.exe stop WinDivert 2>$null | Out-Null

[System.Windows.MessageBox]::Show("GoodbyeDPI has been successfully uninstalled.`r`n`r`nI think the internet is freer now!", 'GoodbyeDPI', 'OK', 'Information')

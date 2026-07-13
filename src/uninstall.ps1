$ErrorActionPreference = 'Stop'

# Relaunch as administrator if not elevated (needed for sc.exe / killing protected process)
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $scriptPath = $MyInvocation.MyCommand.Path
    Start-Process -FilePath 'powershell.exe' -ArgumentList @('-ExecutionPolicy', 'Bypass', '-NoProfile', '-File', $scriptPath) -Verb RunAs
    exit
}

Add-Type -AssemblyName PresentationFramework

# Remove scheduled tasks (both old and new names)
foreach ($taskName in @('GoodbyeDPI', 'GoodByeDPI-Plus')) {
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }
}

# Remove Start Menu shortcut
$startMenuShortcut = Join-Path ([Environment]::GetFolderPath('Programs')) 'GoodByeDPI-Plus.lnk'
if (Test-Path -LiteralPath $startMenuShortcut) {
    Remove-Item -LiteralPath $startMenuShortcut -Force
}

# Remove leftover shortcut from the old VBScript-based version
$oldStartupShortcut = Join-Path ([Environment]::GetFolderPath('Startup')) 'GoodbyeDPI.lnk'
if (Test-Path -LiteralPath $oldStartupShortcut) {
    Remove-Item -LiteralPath $oldStartupShortcut -Force
}

# Kill tray host (powershell.exe running start.ps1) and goodbyedpi itself
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like '*start.ps1*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Stop-Process -Name 'goodbyedpi' -Force -ErrorAction SilentlyContinue
& sc.exe stop WinDivert 2>$null | Out-Null

[System.Windows.MessageBox]::Show("GoodByeDPI-Plus has been successfully uninstalled.`r`n`r`nThe internet is freer now!", 'GoodByeDPI-Plus', 'OK', 'Information')

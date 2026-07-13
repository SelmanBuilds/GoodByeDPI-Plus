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
$iconPath = Join-Path $scriptDir 'icon.ico'

# Remove old scheduled tasks (migration from previous versions)
foreach ($taskName in @('GoodbyeDPI', 'GoodByeDPI-Plus')) {
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }
}

# Remove leftover shortcut from the old VBScript-based version
$oldStartupShortcut = Join-Path ([Environment]::GetFolderPath('Startup')) 'GoodbyeDPI.lnk'
if (Test-Path -LiteralPath $oldStartupShortcut) {
    Remove-Item -LiteralPath $oldStartupShortcut -Force
}

# Create Start Menu shortcut
$startMenuPath = Join-Path ([Environment]::GetFolderPath('Programs')) 'GoodByeDPI-Plus.lnk'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($startMenuPath)
$shortcut.TargetPath = 'powershell.exe'
$shortcut.Arguments = "-ExecutionPolicy Bypass -NoProfile -STA -WindowStyle Hidden -File `"$startPs1`""
$shortcut.WorkingDirectory = $scriptDir
if (Test-Path -LiteralPath $iconPath) {
    $shortcut.IconLocation = $iconPath
}
$shortcut.Description = 'GoodByeDPI-Plus - DPI bypass with per-program filtering'
$shortcut.Save()

# Launch GoodbyeDPI now (hidden, STA for tray)
Start-Process -FilePath 'powershell.exe' -ArgumentList "-ExecutionPolicy Bypass -NoProfile -STA -WindowStyle Hidden -File `"$startPs1`"" -WindowStyle Hidden

# Wait and verify goodbyedpi started
Start-Sleep -Seconds 3
$running = $false
if (Get-Process -Name 'goodbyedpi' -ErrorAction SilentlyContinue) {
    $running = $true
}

if ($running) {
    [System.Windows.MessageBox]::Show("GoodByeDPI-Plus is now running. Look for its icon in the system tray (near the clock).`r`n`r`nStart Menu shortcut created.`r`n`r`nTo enable auto-start at logon, right-click the tray icon and check 'Auto Start'.`r`n`r`nLong live freedom!", 'GoodByeDPI-Plus', 'OK', 'Information')
} else {
    [System.Windows.MessageBox]::Show("GoodByeDPI-Plus was installed but the process is not running.`r`n`r`nStart it manually from the Start Menu shortcut.`r`n`r`nIf it still fails, make sure you run as administrator.", 'GoodByeDPI-Plus', 'OK', 'Warning')
}

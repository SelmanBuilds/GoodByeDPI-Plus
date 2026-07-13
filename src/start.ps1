param(
    [switch]$NoTray,
    [switch]$NoDnsDetect,
    [switch]$TrayMode,
    [int]$GoodbyePid,
    [string]$DnsLabel,
    [string]$ProgramsList,
    [string]$IconPath,
    [int]$CurrentDnsIndex = -1,
    [string]$DnsCandidatesInfo = '',
    [int]$ForceDnsIndex = -1,
    [string]$StartScriptPath = ''
)

$ErrorActionPreference = 'Stop'

# =============================================================================
# Tray Mode - standalone tray icon process
# =============================================================================
if ($TrayMode) {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # Copy params to script scope so .NET event handlers can access them
    $script:ProgramsList    = $ProgramsList
    $script:GoodbyePid      = $GoodbyePid
    $script:notify          = $null
    $script:StartScriptPath = $StartScriptPath

    # Parse DnsCandidatesInfo: "Name|Addr|Port|TimeMs|Status;Name|Addr|Port|TimeMs|Status;..."
    $script:dnsItems = @()
    if ($DnsCandidatesInfo) {
        foreach ($entry in $DnsCandidatesInfo.Split(';')) {
            if (-not $entry) { continue }
            $parts = $entry.Split('|')
            if ($parts.Count -ge 5) {
                $script:dnsItems += @{
                    Name   = $parts[0]
                    Addr   = $parts[1]
                    Port   = [int]$parts[2]
                    TimeMs = [int]$parts[3]
                    Status = $parts[4]
                }
            }
        }
    }
    $script:currentDnsIndex = $CurrentDnsIndex

    if (Test-Path -LiteralPath $IconPath) {
        $icon = New-Object System.Drawing.Icon($IconPath)
    } else {
        $icon = [System.Drawing.SystemIcons]::Application
    }

    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Icon    = $icon
    $notify.Text    = 'GoodByeDPI-Plus'
    $notify.Visible = $true
    $script:notify  = $notify

    $menu = New-Object System.Windows.Forms.ContextMenuStrip

    # DNS dropdown menu
    $dnsMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $dnsMenuItem.Text = "DNS: $DnsLabel"

    # Add each candidate as a sub-item
    for ($i = 0; $i -lt $script:dnsItems.Count; $i++) {
        $item = $script:dnsItems[$i]
        $timeStr = if ($item.TimeMs -ge 0) { "$($item.TimeMs)ms" } else { 'n/a' }
        $label = "$($item.Name) $($item.Addr):$($item.Port) ($timeStr)"
        if ($item.Status -ne 'ok') {
            $label += " [$($item.Status)]"
        }
        $subItem = New-Object System.Windows.Forms.ToolStripMenuItem
        $subItem.Text = $label
        $subItem.Tag = $i
        if ($i -eq $script:currentDnsIndex) {
            $subItem.Checked = $true
        }
        $subItem.Add_Click({
            $idx = [int]$this.Tag
            try {
                Stop-Process -Id $script:GoodbyePid -Force -ErrorAction SilentlyContinue
            } catch { }
            try {
                if ($script:notify) { $script:notify.Visible = $false }
            } catch { }
            $restartStr = "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$($script:StartScriptPath)`" -ForceDnsIndex $idx"
            Start-Process -FilePath 'powershell.exe' -ArgumentList $restartStr -WindowStyle Hidden
            [System.Windows.Forms.Application]::Exit()
        })
        [void]$dnsMenuItem.DropDownItems.Add($subItem)
    }

    # Separator + Auto-detect option in dropdown
    [void]$dnsMenuItem.DropDownItems.Add('-')

    $autoItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $autoItem.Text = 'Auto-detect (re-test)'
    $autoItem.Add_Click({
        try {
            Stop-Process -Id $script:GoodbyePid -Force -ErrorAction SilentlyContinue
        } catch { }
        try {
            if ($script:notify) { $script:notify.Visible = $false }
        } catch { }
        $restartStr = "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$($script:StartScriptPath)`""
        Start-Process -FilePath 'powershell.exe' -ArgumentList $restartStr -WindowStyle Hidden
        [System.Windows.Forms.Application]::Exit()
    })
    [void]$dnsMenuItem.DropDownItems.Add($autoItem)

    [void]$menu.Items.Add($dnsMenuItem)

    [void]$menu.Items.Add('-')

    $editItem = $menu.Items.Add('Edit programs.txt')
    $editItem.Add_Click({
        try {
            Start-Process -FilePath $script:ProgramsList
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to open programs.txt:`r`n$_", 'GoodByeDPI-Plus', 'OK', 'Warning')
        }
    })

    [void]$menu.Items.Add('-')

    # Auto Start toggle
    $autoStartItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $autoStartItem.Text = 'Auto Start'
    $taskName = 'GoodByeDPI-Plus'
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        $autoStartItem.Checked = $true
    }
    $autoStartItem.Add_Click({
        $taskName = 'GoodByeDPI-Plus'
        try {
            if ($this.Checked) {
                # Disable auto-start
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
                $this.Checked = $false
                if ($script:notify) {
                    $script:notify.ShowBalloonTip(2000, 'GoodByeDPI-Plus', 'Auto-start disabled', [System.Windows.Forms.ToolTipIcon]::Info)
                }
            } else {
                # Enable auto-start
                $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-ExecutionPolicy Bypass -NoProfile -STA -WindowStyle Hidden -File `"$($script:StartScriptPath)`""
                $trigger = New-ScheduledTaskTrigger -AtLogOn
                $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
                $settings = New-ScheduledTaskSettingsSet -Hidden -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
                if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
                    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
                }
                Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
                $this.Checked = $true
                if ($script:notify) {
                    $script:notify.ShowBalloonTip(2000, 'GoodByeDPI-Plus', 'Auto-start enabled', [System.Windows.Forms.ToolTipIcon]::Info)
                }
            }
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to toggle auto-start.`r`n$_`r`n`r`nMake sure you run as administrator.", 'GoodByeDPI-Plus', 'OK', 'Warning')
        }
    })
    [void]$menu.Items.Add($autoStartItem)

    [void]$menu.Items.Add('-')

    $exitItem = $menu.Items.Add('Exit')
    $exitItem.Add_Click({
        try {
            if ($script:notify) { $script:notify.Visible = $false }
        } catch { }
        try {
            Stop-Process -Id $script:GoodbyePid -Force -ErrorAction SilentlyContinue
        } catch { }
        [System.Windows.Forms.Application]::Exit()
    })

    $notify.ContextMenuStrip = $menu
    $notify.ShowBalloonTip(3000, 'GoodByeDPI-Plus', "Running - DNS: $DnsLabel", [System.Windows.Forms.ToolTipIcon]::Info)

    $exitForm = New-Object System.Windows.Forms.Form
    $exitForm.ShowInTaskbar = $false
    $exitForm.WindowState   = 'Minimized'
    $exitForm.Opacity       = 0
    $exitForm.Add_FormClosed({
        try { if ($script:notify) { $script:notify.Visible = $false } } catch { }
        try { if ($script:notify) { $script:notify.Dispose() } } catch { }
    })
    $notify.Tag = $exitForm

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 500
    $timer.Add_Tick({
        try {
            $p = Get-Process -Id $script:GoodbyePid -ErrorAction SilentlyContinue
            if (-not $p) {
                if ($script:notify) {
                    $script:notify.ShowBalloonTip(3000, 'GoodByeDPI-Plus', 'goodbyedpi.exe exited unexpectedly', [System.Windows.Forms.ToolTipIcon]::Warning)
                }
                Start-Sleep -Milliseconds 2
                $timer.Stop()
                $exitForm.Close()
            }
        } catch { }
    })
    $timer.Start()

    [void]$exitForm.ShowDialog()
    exit
}

# =============================================================================
# Config
# =============================================================================
$enableTray      = $true
$autoDetectDns   = $true
$dnsTimeoutMs    = 800
$dnsTestDomain   = 'discord.com'
$blockPageRanges = @('195.175.254.')
$bypassMode      = '--auto-ttl --max-payload'

$dnsCandidates = @(
    @{ Name='Yandex';     Addr='77.88.8.8';      Port=1253; V6Addr='2a02:6b8::feed:0ff';    V6Port=1253 }
    @{ Name='Yandex';     Addr='77.88.8.8';      Port=53;   V6Addr='2a02:6b8::feed:0ff';    V6Port=53 }
    @{ Name='Cloudflare'; Addr='1.1.1.1';        Port=53;   V6Addr='2606:4700:4700::1111';  V6Port=53 }
    @{ Name='Quad9';      Addr='9.9.9.9';        Port=53;   V6Addr='2620:fe::fe';           V6Port=53 }
    @{ Name='AdGuard';    Addr='94.140.14.14';   Port=53;   V6Addr='2a10:50c0::ad1:ff';     V6Port=53 }
)
$fallbackDns = @{ Name='Yandex'; Addr='77.88.8.8'; Port=1253; V6Addr='2a02:6b8::feed:0ff'; V6Port=1253; TimeMs=0 }

# =============================================================================
# Setup
# =============================================================================
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$programsListPath = Join-Path $scriptDir 'programs.txt'
$iconPath = Join-Path $scriptDir 'icon.ico'
$startScriptPath = $MyInvocation.MyCommand.Path

if ($env:PROCESSOR_ARCHITEW6432 -ne '') {
    $arch = 'x86_64'
} elseif ($env:PROCESSOR_ARCHITECTURE -match 'AMD64') {
    $arch = 'x86_64'
} else {
    $arch = 'x86'
}
$exePath = Join-Path $scriptDir "$arch\GoodbyeDPI.exe"

if ($NoTray)      { $enableTray    = $false }
if ($NoDnsDetect) { $autoDetectDns = $false }

# =============================================================================
# DNS Functions
# =============================================================================

function Build-DnsQuery {
    param([string]$Domain)
    $b = [System.Collections.Generic.List[byte]]::new()
    $b.Add(0x12); $b.Add(0x34)
    $b.Add(0x01); $b.Add(0x00)
    $b.Add(0x00); $b.Add(0x01)
    $b.Add(0x00); $b.Add(0x00)
    $b.Add(0x00); $b.Add(0x00)
    $b.Add(0x00); $b.Add(0x00)
    foreach ($label in $Domain.Split('.')) {
        $b.Add([byte]$label.Length)
        $b.AddRange([System.Text.Encoding]::ASCII.GetBytes($label))
    }
    $b.Add(0x00)
    $b.Add(0x00); $b.Add(0x01)
    $b.Add(0x00); $b.Add(0x01)
    return $b.ToArray()
}

function Parse-DnsResponseA {
    param([byte[]]$Data)
    if ($Data.Length -lt 12) { return $null }
    $pos = 12
    while ($pos -lt $Data.Length -and $Data[$pos] -ne 0) {
        $pos += $Data[$pos] + 1
    }
    $pos += 5
    $answerCount = ($Data[6] -shl 8) -bor $Data[7]
    for ($i = 0; $i -lt $answerCount; $i++) {
        if ($pos -ge $Data.Length) { break }
        if ($Data[$pos] -band 0xC0) {
            $pos += 2
        } else {
            while ($pos -lt $Data.Length -and $Data[$pos] -ne 0) {
                $pos += $Data[$pos] + 1
            }
            $pos += 1
        }
        if ($pos + 10 -gt $Data.Length) { break }
        $type = ($Data[$pos] -shl 8) -bor $Data[$pos + 1]
        $pos += 8
        $rdLength = ($Data[$pos] -shl 8) -bor $Data[$pos + 1]
        $pos += 2
        if ($type -eq 1 -and $rdLength -eq 4 -and ($pos + 4) -le $Data.Length) {
            return "$($Data[$pos]).$($Data[$pos + 1]).$($Data[$pos + 2]).$($Data[$pos + 3])"
        }
        $pos += $rdLength
    }
    return $null
}

function Test-PoisonedIp {
    param([string]$Ip, [string[]]$BlockRanges)
    foreach ($range in $BlockRanges) {
        if ($Ip.StartsWith($range)) { return $true }
    }
    return $false
}

# Returns @{ Best=<hashtable>; Results=<array>; BestIndex=<int> }
# Each item in Results: @{ Name; Addr; Port; V6Addr; V6Port; TimeMs; Status }
function Find-FastestDns {
    $query = Build-DnsQuery $dnsTestDomain
    $states = [System.Collections.ArrayList]::new()

    foreach ($c in $dnsCandidates) {
        try {
            $udp = New-Object System.Net.Sockets.UdpClient
            $udp.Client.ReceiveTimeout = $dnsTimeoutMs
            $udp.Connect($c.Addr, $c.Port)
            $udp.Send($query, $query.Length) | Out-Null
            [void]$states.Add(@{ Udp = $udp; Server = $c; Ip = $null; TimeMs = -1 })
        } catch {
            [void]$states.Add(@{ Udp = $null; Server = $c; Ip = $null; TimeMs = -1; Error = $_.Exception.Message })
        }
    }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $dnsTimeoutMs) {
        $anyPending = $false
        foreach ($s in $states) {
            if ($s.Ip -ne $null -or $s.Udp -eq $null) { continue }
            $anyPending = $true
            try {
                if ($s.Udp.Client.Poll(0, [System.Net.Sockets.SelectMode]::SelectRead)) {
                    $ep = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
                    $data = $s.Udp.Receive([ref]$ep)
                    $s.TimeMs = $sw.ElapsedMilliseconds
                    $ip = Parse-DnsResponseA $data
                    if ($ip -and -not (Test-PoisonedIp $ip $blockPageRanges)) {
                        $s.Ip = $ip
                        Write-Host "[dns] $($s.Server.Name) $($s.Server.Addr):$($s.Server.Port) -> $ip ($($s.TimeMs)ms) OK"
                    } else {
                        $s.Ip = $null
                        $s.Status = if ($ip) { 'poisoned' } else { 'no-record' }
                        $label = if ($ip) { "$ip (poisoned)" } else { "no A record" }
                        Write-Host "[dns] $($s.Server.Name) $($s.Server.Addr):$($s.Server.Port) -> $label SKIP"
                    }
                }
            } catch { }
        }
        if (-not $anyPending) { break }
        Start-Sleep -Milliseconds 30
    }
    $sw.Stop()

    # Build results array (same order as $dnsCandidates)
    $results = @()
    for ($i = 0; $i -lt $dnsCandidates.Count; $i++) {
        $s = $states[$i]
        $status = 'ok'
        if ($s.Ip -eq $null) {
            if ($s.Udp -eq $null) {
                $status = 'unreachable'
            } elseif ($s.Status) {
                $status = $s.Status
            } else {
                $status = 'no-response'
            }
        }
        if ($s.Ip -eq $null -and $s.TimeMs -eq -1) {
            Write-Host "[dns] $($s.Server.Name) $($s.Server.Addr):$($s.Server.Port) -> no response SKIP"
        }
        $results += @{
            Name   = $s.Server.Name
            Addr   = $s.Server.Addr
            Port   = $s.Server.Port
            V6Addr = $s.Server.V6Addr
            V6Port = $s.Server.V6Port
            TimeMs = $s.TimeMs
            Status = $status
        }
    }

    foreach ($s in $states) {
        try { if ($s.Udp) { $s.Udp.Close() } } catch { }
    }

    # Find best (fastest valid)
    $bestIndex = -1
    $bestTimeMs = [int]::MaxValue
    for ($i = 0; $i -lt $results.Count; $i++) {
        if ($results[$i].Status -eq 'ok' -and $results[$i].TimeMs -ge 0 -and $results[$i].TimeMs -lt $bestTimeMs) {
            $bestIndex = $i
            $bestTimeMs = $results[$i].TimeMs
        }
    }

    if ($bestIndex -ge 0) {
        $best = $results[$bestIndex]
        Write-Host "[dns] Selected: $($best.Name) $($best.Addr):$($best.Port) ($($best.TimeMs)ms)"
    } else {
        Write-Host "[dns] No valid server found - using fallback: $($fallbackDns.Name) $($fallbackDns.Addr):$($fallbackDns.Port)"
        $bestIndex = 0
        $best = @{
            Name   = $fallbackDns.Name
            Addr   = $fallbackDns.Addr
            Port   = $fallbackDns.Port
            V6Addr = $fallbackDns.V6Addr
            V6Port = $fallbackDns.V6Port
            TimeMs = 0
            Status = 'fallback'
        }
        $results[0] = $best
    }

    return @{ Best = $best; Results = $results; BestIndex = $bestIndex }
}

# =============================================================================
# Main
# =============================================================================

# Kill existing goodbyedpi instances (prevent duplicates)
Get-Process -Name 'goodbyedpi' -ErrorAction SilentlyContinue | Stop-Process -Force

# Kill old tray processes (powershell.exe with -TrayMode in command line)
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like '*-TrayMode*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

# Check exe
if (-not (Test-Path -LiteralPath $exePath)) {
    Write-Error "GoodbyeDPI.exe not found at $exePath"
    return
}

# DNS detection
$dnsResults = $null
if ($autoDetectDns -or $ForceDnsIndex -ge 0) {
    try {
        $dnsResults = Find-FastestDns
    } catch {
        Write-Host "[dns] Detection failed: $_ - using fallback"
    }
}

# Determine which DNS to use
if ($ForceDnsIndex -ge 0 -and $ForceDnsIndex -lt $dnsCandidates.Count) {
    # Manual override from tray menu
    $c = $dnsCandidates[$ForceDnsIndex]
    $dns = @{ Name=$c.Name; Addr=$c.Addr; Port=$c.Port; V6Addr=$c.V6Addr; V6Port=$c.V6Port; TimeMs=0; Status='manual' }
    $currentDnsIndex = $ForceDnsIndex
    Write-Host "[dns] Forced: $($dns.Name) $($dns.Addr):$($dns.Port)"
    # Build results from detection if available, otherwise build from candidates
    if (-not $dnsResults) {
        $dnsResults = @{ Best = $dns; Results = @(); BestIndex = $ForceDnsIndex }
        foreach ($c2 in $dnsCandidates) {
            $dnsResults.Results += @{ Name=$c2.Name; Addr=$c2.Addr; Port=$c2.Port; V6Addr=$c2.V6Addr; V6Port=$c2.V6Port; TimeMs=-1; Status='unknown' }
        }
        $dnsResults.Results[$ForceDnsIndex] = $dns
    }
} elseif ($dnsResults -and $dnsResults.Best) {
    $dns = $dnsResults.Best
    $currentDnsIndex = $dnsResults.BestIndex
} else {
    $dns = $fallbackDns
    $currentDnsIndex = 0
    $dnsResults = @{ Best = $dns; Results = @(); BestIndex = 0 }
    $dnsResults.Results += $dns
    for ($i = 1; $i -lt $dnsCandidates.Count; $i++) {
        $c = $dnsCandidates[$i]
        $dnsResults.Results += @{ Name=$c.Name; Addr=$c.Addr; Port=$c.Port; V6Addr=$c.V6Addr; V6Port=$c.V6Port; TimeMs=-1; Status='unknown' }
    }
}

# Build DnsCandidatesInfo string for tray
$dnsInfoParts = @()
foreach ($r in $dnsResults.Results) {
    $dnsInfoParts += "$($r.Name)|$($r.Addr)|$($r.Port)|$($r.TimeMs)|$($r.Status)"
}
$dnsCandidatesInfo = $dnsInfoParts -join ';'

# Build params
$params = "--dns-addr $($dns.Addr) --dns-port $($dns.Port) --dnsv6-addr $($dns.V6Addr) --dnsv6-port $($dns.V6Port)"
if ($bypassMode) {
    $params = $params + " $bypassMode"
}
if (Test-Path -LiteralPath $programsListPath) {
    $params = $params + " --only-programs `"$programsListPath`""
}

# Start goodbyedpi
$proc = Start-Process -FilePath $exePath -ArgumentList $params -WindowStyle Hidden -PassThru

# Health check
Start-Sleep -Milliseconds 500
if ($proc.HasExited) {
    Write-Error "GoodbyeDPI.exe exited immediately. Run as administrator."
    if ($enableTray) {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show("GoodbyeDPI.exe failed to start.`r`nMake sure you run as administrator.", 'GoodByeDPI-Plus', 'OK', 'Error')
    }
    return
}

# Spawn tray process and exit (terminal closes, tray stays)
if ($enableTray) {
    $timeStr = if ($dns.TimeMs -gt 0) { "$($dns.TimeMs)ms" } else { 'fallback' }
    $dnsLabel = "$($dns.Name) $($dns.Addr):$($dns.Port) ($timeStr)"
    $trayStr = "-ExecutionPolicy Bypass -NoProfile -STA -WindowStyle Hidden -File `"$startScriptPath`" -TrayMode -GoodbyePid $($proc.Id) -DnsLabel `"$dnsLabel`" -ProgramsList `"$programsListPath`" -IconPath `"$iconPath`" -CurrentDnsIndex $currentDnsIndex -DnsCandidatesInfo `"$dnsCandidatesInfo`" -StartScriptPath `"$startScriptPath`""
    Start-Process -FilePath 'powershell.exe' -ArgumentList $trayStr -WindowStyle Hidden
}

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if ($env:PROCESSOR_ARCHITECTURE -match 'AMD64') {
    $arch = 'x86_64'
} else {
    $arch = 'x86'
}
if ($env:PROCESSOR_ARCHITEW6432 -ne '') {
    $arch = 'x86_64'
}

$exePath = Join-Path $scriptDir "$arch\GoodbyeDPI.exe"
$programsList = Join-Path $scriptDir 'programs.txt'
$params = '--dns-addr 77.88.8.8 --dns-port 1253 --dnsv6-addr 2a02:6b8::feed:0ff --dnsv6-port 1253'
if (Test-Path -LiteralPath $programsList) {
    $params = $params + ' --only-programs "' + $programsList + '"'
}

Start-Process -FilePath $exePath -ArgumentList $params -WindowStyle Hidden

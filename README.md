# GoodByeDPI-Plus

GoodByeDPI-Plus is an enhanced fork of [GoodbyeDPI](https://github.com/ValdikSS/GoodbyeDPI) that adds **per-program DPI bypass filtering** — only the traffic of programs you choose (browsers, Discord, etc.) gets bypass tricks applied, while everything else passes through untouched.

It also ships with a one-click installer that sets up a hidden Windows scheduled task so bypass runs automatically at every logon — no console window, no UAC prompt, no manual launch.

---

## What's new vs. original GoodbyeDPI

| Feature | Original | GoodByeDPI-Plus |
|---------|----------|-----------------|
| Per-program whitelist | No — all traffic processed | **Yes** via `--only-programs` |
| Hot-reload of whitelist | N/A | **Yes** — edit `programs.txt` while running, applies in ~2 s |
| One-click auto-startup | `.cmd` scripts only | **Scheduled task** installer (`install.bat`) |
| System tray icon | None | **Yes** — right-click to edit whitelist or stop |
| DNS auto-detection | Manual `--dns-addr` | **Yes** — tests 5 servers, picks fastest non-poisoned |
| Hidden background run | Console window visible | **Hidden** — no taskbar clutter |
| SNI DPI bypass | Manual `-5`/`-9` flags | **Auto** via `$bypassMode` config |
| DNS poisoning bypass | `--dns-addr` | Same, with auto-detection |

---

## How it works

GoodbyeDPI-Plus uses WinDivert's **FLOW layer** to learn which process owns each network connection. A background thread receives `(5-tuple, PID)` notifications for every new flow, resolves the PID to an executable path, and matches it against the whitelist in `programs.txt`. The result is stored in a thread-safe hash map keyed by 5-tuple.

The main packet loop queries this map for every TCP/UDP packet. If the owning process is **on the whitelist**, normal bypass tricks (fragmentation, fake packets, etc.) are applied. If it is **not**, the packet is reinjected untouched and skipped — zero overhead for that flow.

At startup, a snapshot of already-open connections is taken via `GetExtendedTcpTable` / `GetExtendedUdpTable`, so existing browser tabs are not missed.

DNS redirect (`--dns-addr`) is **exempt** from the per-program gate: it works globally so the system resolver (`svchost.exe`, which is not on your whitelist) can still resolve domains through the redirect. Without this, DNS would be poisoned by the ISP and no bypass trick could help.

A **watcher thread** polls `programs.txt` for mtime changes every 2 seconds. When you edit the file, the whitelist is atomically swapped, the 5-tuple map is cleared, and connections are re-seeded — no restart needed.

---

## Quick start

1. Download the [latest release](../../releases) and unzip it.
2. Run **`install.bat`** as administrator.
3. That's it. GoodByeDPI-Plus is now running in the background and will start automatically on every logon. A **system tray icon** appears near the clock — right-click it to edit the whitelist or stop the service.

To stop and remove it, run **`uninstall.bat`** as administrator.

> Place the folder somewhere permanent before running `install.bat`. The scheduled task points to `src\start.ps1` inside this folder. If you move the folder, run `install.bat` again.

---

## System tray

When `start.ps1` runs (either manually or via the scheduled task), a **system tray icon** appears near the clock. Right-click it to access:

- **DNS: …** — dropdown menu showing all tested DNS servers with response times and status. The currently active server is checkmarked. Click any server to instantly switch (goodbyedpi restarts with the new DNS). Includes an **Auto-detect (re-test)** option to re-run the speed test.
- **Edit programs.txt** — opens the whitelist in your default text editor; changes hot-reload in ~2 s
- **Exit** — kills `goodbyedpi.exe` and removes the tray icon

If `goodbyedpi.exe` crashes or exits unexpectedly, the tray icon shows a warning balloon and cleans up automatically.

To disable the tray icon (headless mode), run:

```powershell
powershell -ExecutionPolicy Bypass -File src\start.ps1 -NoTray
```

Or set `$enableTray = $false` at the top of `src\start.ps1`.

---

## DNS auto-detection

At every launch, `start.ps1` can automatically test multiple DNS servers and pick the **fastest one that returns a non-poisoned response**. This ensures you always get the best DNS redirect without manual tuning.

**How it works:**

1. Sends a DNS query for `discord.com` (a commonly blocked domain) to all candidate servers **in parallel**.
2. Measures each server's response time.
3. Discards servers that return a known **ISP block-page IP** (e.g. `195.175.254.*` for Türk Telekom).
4. Selects the fastest valid server.
5. Falls back to **Yandex 77.88.8.8:1253** if no server responds correctly.

**Candidate servers:**

| Server | Port | Provider |
|--------|------|----------|
| 77.88.8.8 | 1253 | Yandex (alt port) |
| 77.88.8.8 | 53 | Yandex (standard) |
| 1.1.1.1 | 53 | Cloudflare |
| 9.9.9.9 | 53 | Quad9 |
| 94.140.14.14 | 53 | AdGuard |

To disable auto-detection and use the hardcoded fallback:

```powershell
powershell -ExecutionPolicy Bypass -File src\start.ps1 -NoDnsDetect
```

Or set `$autoDetectDns = $false` at the top of `src\start.ps1`.

You can also customize the candidate list, timeout, test domain, and block-page IP ranges in the **Config** section at the top of `src\start.ps1`.

---

## Configuration

### Choosing which programs get bypassed

Open `src\programs.txt` in a text editor. One program per line. Lines starting with `#` are comments.

```
# Browsers
chrome.exe
msedge.exe
firefox.exe

# Discord
discord.exe
Vesktop.exe
```

**Matching rules** (case-insensitive):

- If the entry **contains** a path separator (`\` or `/`), it is matched as a **substring of the full process path**.
  Example: `Google\Chrome\chrome.exe` matches
  `C:\Program Files\Google\Chrome\Application\chrome.exe`.
- If the entry has **no** separator, it is matched against the **file name only** (exact match).
  Example: `chrome.exe` matches any `chrome.exe`, but `chrome` does not.

Changes take effect within ~2 seconds — no restart needed (hot-reload).

### Adjusting bypass parameters

Edit `src\start.ps1` to change the command-line arguments passed to `goodbyedpi.exe`. By default, DNS redirect parameters are built dynamically from the auto-detection result. The Config section at the top of the file lets you toggle features and customize DNS candidates:

```powershell
$enableTray      = $true    # System tray icon
$autoDetectDns   = $true    # Auto-pick fastest non-poisoned DNS
$dnsTimeoutMs    = 800      # Per-batch DNS test timeout
$dnsTestDomain   = 'discord.com'
$blockPageRanges = @('195.175.254.')  # ISP block-page IPs to reject
$bypassMode      = '--auto-ttl --max-payload'  # SNI DPI bypass tricks
```

When auto-detection is enabled, the `--dns-addr` / `--dns-port` / `--dnsv6-addr` / `--dnsv6-port` flags are set automatically. When disabled, the fallback (Yandex 77.88.8.8:1253) is used.

The `$bypassMode` variable controls SNI-based DPI bypass tricks applied to whitelisted programs' traffic. The default `--auto-ttl --max-payload` is a minimal working set that bypasses SNI inspection without triggering excessive Cloudflare challenges. You can change it to `-5` (aggressive: adds `--reverse-frag`), `-9` (most aggressive), or `''` (empty — DNS redirect only, for ISPs that only do DNS poisoning). See `goodbyedpi.exe -h` for all options.

If your ISP also does SNI-based DPI blocking (not just DNS poisoning), you can add bypass trick modesets such as `-9`, `-5`, `--native-frag`, etc. See `goodbyedpi.exe -h` for the full list.

> **Note:** Some ISPs do **only** DNS poisoning and have no SNI/TCP DPI blocking — in that case you can set `$bypassMode = ''` (empty) for DNS redirect only. However, many ISPs (including some in Turkey) do **both** DNS poisoning **and** SNI-based DPI blocking, in which case bypass tricks like `--auto-ttl --max-payload` are required. Cloudflare bot verification may appear in `curl` tests but is automatically resolved by real browsers via JavaScript challenge.

### Supported arguments

Run `goodbyedpi.exe -h` for the full, up-to-date list. Key additions in this fork:

```
--only-programs <txtfile>  Apply DPI bypass tricks ONLY to traffic of programs
                            listed in the text file (one basename or path
                            substring per line). Other programs' traffic is
                            left untouched. # comments allowed.
--debug-proc               Print per-program gate decisions (first 300 packets).
```

All original GoodbyeDPI arguments (`-p`, `-q`, `-r`, `-s`, `-e`, `-f`, `--dns-addr`, `--blacklist`, `-5`..`-9`, etc.) are also supported.

---

## How to build from source

### Prerequisites

- [MSYS2](https://www.msys2.org/) with `mingw-w64-x86_64-gcc` installed
- [WinDivert 2.2.0-A](https://reqrypt.org/download/WinDivert-2.2.0-A.zip) SDK (header + libs)

### Build (x86_64)

Open the **MSYS2 mingw64** terminal and run:

```bash
cd src
make BIT64=1 \
  WINDIVERTHEADERS=/path/to/WinDivert-2.2.0-A/include \
  WINDIVERTLIBS=/path/to/WinDivert-2.2.0-A/x64
```

### Build (x86)

```bash
cd src
make CPREFIX=i686-w64-mingw32- \
  WINDIVERTHEADERS=/path/to/WinDivert-2.2.0-A/include \
  WINDIVERTLIBS=/path/to/WinDivert-2.2.0-A/x86
```

The resulting `goodbyedpi.exe` will be in `src/`. Copy it along with `WinDivert.dll` and `WinDivert64.sys` (or `WinDivert32.sys`) into the `x86_64/` (or `x86/`) folder.

GitHub Actions CI also builds both architectures automatically on every push — see [.github/workflows/build.yml](.github/workflows/build.yml).

---

## How to check if it works

1. With GoodByeDPI-Plus **running**, try opening a previously-blocked website in a whitelisted browser.
2. Run `uninstall.bat`, then try the same website again — it should be blocked.
3. Re-run `install.bat` to start it again.

### Debug mode

To verify the per-program gate is working correctly, run `start.ps1` with `--debug-proc` appended. The easiest way is to temporarily edit the `$params` line in `src\start.ps1`:

```powershell
$params = "--dns-addr $($dns.Addr) --dns-port $($dns.Port) --dnsv6-addr $($dns.V6Addr) --dnsv6-port $($dns.V6Port) --only-programs `"$programsList`" --debug-proc"
```

Or run goodbyedpi.exe directly:

```powershell
.\src\x86_64\goodbyedpi.exe --dns-addr 77.88.8.8 --dns-port 1253 --only-programs .\src\programs.txt --debug-proc
```

This prints `[GATE] PASS` / `[GATE] BLOCK` decisions for the first 300 packets to stdout.

To see DNS auto-detection output, run `start.ps1` from a terminal (not via `install.bat`):

```powershell
powershell -ExecutionPolicy Bypass -File src\start.ps1 -NoTray
```

---

## Uninstall

Run `uninstall.bat` as administrator. This:
- Removes the scheduled task
- Kills the tray host (`powershell.exe` running `start.ps1`)
- Stops the running `goodbyedpi.exe` process
- Stops the WinDivert driver

---

## Project structure

```
GoodByeDPI-Plus/
├── install.bat              # One-click installer (calls src/install.ps1)
├── uninstall.bat            # One-click uninstaller
├── README.md
├── LICENSE                  # Apache 2.0
├── NOTICE                   # Attribution & modified-files notice
├── .editorconfig
├── .gitignore
├── .github/
│   ├── workflows/build.yml  # CI: auto-build x86 + x86_64
│   └── ISSUE_TEMPLATE/      # Bug report & feature request templates
└── src/
    ├── goodbyedpi.c         # Main packet loop + per-program gate (--only-programs)
    ├── proctrack.c          # Per-program 5-tuple→PID→exe→whitelist tracker
    ├── proctrack.h
    ├── goodbyedpi.h
    ├── blackwhitelist.c/.h  # Original host-based blacklist
    ├── dnsredir.c/.h        # DNS redirect logic
    ├── fakepackets.c/.h     # Fake packet generation
    ├── service.c/.h         # Windows service helpers
    ├── ttltrack.c/.h        # TTL tracking
    ├── utils/               # getline, repl_str, uthash
    ├── Makefile
    ├── goodbyedpi-rc.rc     # Windows resource (icon, manifest)
    ├── icon.ico
    ├── start.ps1            # Launcher script (DNS redirect + --only-programs)
    ├── install.ps1          # Scheduled task installer
    ├── uninstall.ps1        # Scheduled task uninstaller
    ├── programs.txt         # Per-program whitelist (editable, hot-reloaded)
    ├── x86_64/              # 64-bit prebuilt binaries
    │   ├── goodbyedpi.exe
    │   ├── WinDivert.dll
    │   └── WinDivert64.sys
    └── x86/                 # 32-bit prebuilt binaries
        ├── goodbyedpi.exe
        ├── WinDivert.dll
        ├── WinDivert32.sys
        └── WinDivert64.sys
```

---

## Credits

- **[ValdikSS/GoodbyeDPI](https://github.com/ValdikSS/GoodbyeDPI)** — the original Deep Packet Inspection circumvention utility. This project is a fork of it.
- **[basil00/WinDivert](https://github.com/basil00/Divert)** — the packet capture/divert library that makes all of this possible.
- **[keift/goodbyedpi](https://github.com/keift/goodbyedpi)** — inspiration for the one-click startup installer concept.

---

## License

Licensed under the **Apache License, Version 2.0**. See [LICENSE](LICENSE) and [NOTICE](NOTICE) for details.

This project is a derivative work of GoodbyeDPI by ValdikSS, also licensed under Apache 2.0.

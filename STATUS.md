# GoodByeDPI-Plus — Uygulama Durumu ve Sorun Gecmisi

> **Son güncelleme:** 9 Temmuz 2026 (10. revizyon)
> **Amaç:** Sonraki oturumda context'i tazelemek için tek kaynak.
> Tüm teknik detaylar kendi kendine yeterli.

---

## 1. Ne Yapildi (Ozet)

GoodbyeDPI'ye **per-program filtreleme** eklendi: DPI bypass trick'leri
sadece `programs.txt` whitelist'indeki programlarin trafigine uygulanir.
Derleme ortami kuruldu, kaynak modifiye edildi, derlendi, deploy edildi.

**Mevcut durum (9 Temmuz 10. rev):** Hersey calisiyor.
- goodbyedpi per-program + DNS redirect + SNI bypass calisiyor.
- **SNI DPI BLOCKING KESFI (10. rev):** ISS sadece DNS zehirlenmesi
  yapmiyor — ayrica SNI-based DPI blocking YAPIYOR. Eski tesHis
  (6. rev: "ISS SADECE DNS zehirlenmesi, DPI/SNI YOK") YANLISTI.
  Test: goodbyedpi KAPALI iken HTTPS Discord'a timeout (SNI engeli).
  Cozum: `$bypassMode = '--auto-ttl --max-payload'` start.ps1 config'inde.
- **BYPASS MODE (10. rev):** `--auto-ttl --max-payload` minimal calisan set.
  `-5`'in `--reverse-frag` olmadan hali. Test'le dogrulandi: HTTP 200.
  `-9`, `-e 2 -f 2`, `--native-frag` tek basina FAILED. Sadece `-5` ve
  `--auto-ttl --max-payload` calisiyor. Config'den duzenlenebilir.
- **DNS AUTO-DETECTION (7. rev):** start.ps1 her açılışta 5 DNS sunucusuna
  paralel UDP sorgusu gönderir, en hızlı zehirlenmemiş yanıtı seçer.
  Zehirlenme kontrolü: 195.175.254.* (Türk Telekom engel sayfası) elenir.
  Fallback: Yandex 77.88.8.8:1253. Tray menude DNS dropdown ile degistirilebilir.
- **SYSTEM TRAY ICON (8-9. rev):** start.ps1 iki-modlu yapiya kavustu.
  Main mode: DNS detection + goodbyedpi baslat + tray spawn + EXIT (terminal kapanir).
  Tray mode: ayri gizli process'te NotifyIcon + ContextMenuStrip + hidden Form ShowDialog.
  DNS dropdown menude sunucular listelenir, tiklayinca goodbyedpi yeniden baslatilir.
  Menu: DNS dropdown, Edit programs.txt, Exit.
  goodbyedpi çökerse Timer (500ms) ile tespit + balon + temizlik.
  `$enableTray = $true` (config'ten kapatılabilir, `-NoTray` flag'i ile de).
- **Cloudflare bot dogrulamasi (10. rev):** curl ile test edildiginde
  `--auto-ttl --max-payload` ve `-5` her ikisi de Cloudflare challenge
  gosteriyor. AMA gercek tarayicida (Chrome, Vesktop) JS challenge
  otomatik geciyor — kullanici sorun yasamiyor. Calisiyor.
- **GitHub'da YAYINLANDI:** `github.com/SelmanBuilds/GoodByeDPI-Plus`
  - Apache-2.0 lisansı + NOTICE (ValdikSS kredisi)
  - Release v1.1.0: temiz end-user zip (icon.ico dahil)
  - CI: GitHub Actions her push'ta x86 + x86_64 otomatik derleme
  - README.md tam dokümantasyon
- **Hot-reload:** programs.txt degisince watcher thread (2s poll)
  whitelist'i otomatik yeniden yukler + map'i temizler + re-seed eder.
- **Vesktop DoH kalici kapatildi:** kisa yollara `--disable-features=DnsOverHttps`
  flag eklendi. Chromium varsayilan DoH (TCP 443 DNS) bypass ediliyor.
- `--debug-proc` flag'i ile gate karar log'lari dogrulandi.
- **Windows sistem DNS degistirilmedi** (router 192.168.1.1'de). DoH yok.
  goodbyedpi'nin DNS redirect'i tek DNS cozumu.
  goodbyedpi ACIK → Discord calisir. goodbyedpi KAPALI → Discord bozulur.

**KRITIK KESIF (5. rev):** "goodbyedpi kapaliyken Discord calisiyor" sorununun
asıl sebebi **Vesktop (Chromium) varsayilan DoH kullanmasi** idi.
Chromium DoH = TCP 443 uzerinden DNS cozumer → UDP 53 (goodbyedpi DNS
redirect) bypass edilir → goodbyedpi'den bagimsiz calisir.
**Cozum:** Vesktop kisa yollarina `--disable-features=DnsOverHttps` eklendi.
Artik Vesktop DoH kapali → Windows DNS (router) kullanir → goodbyedpi'ye bagimli.

**KRITIK KESIF (10. rev):** ISS SADECE DNS zehirlenmesi yapmiyor.
Ayrica SNI-based DPI blocking yapiyor. Eski tesHis (6. rev: "ISS sadece
DNS poisoning, DPI/SNI YOK") YANLISTI. Test (10. rev) dogruladi:
- goodbyedpi KAPALI iken HTTPS Discord'a timeout → SNI engeli var.
- `--native-frag`, `-9`, `-e 2 -f 2` tek basina FAILED.
- `-5` ve `--auto-ttl --max-payload` HTTP 200 (calisiyor).
- `--auto-ttl --max-payload` = `-5`'in `--reverse-frag` olmadan hali.
- Cozum: `$bypassMode = '--auto-ttl --max-payload'` start.ps1 config'inde.

**Test dogrulamasi (6. rev):**
| Durum | Vesktop baglantisi | Discord | Cloudflare |
|-------|-------------------|---------|------------|
| goodbyedpi KAPALI + DNS=Yandex (gecici) | 162.159.x (Discord) | Calisiyor | Yok |
| goodbyedpi ACIK + DNS redirect (Yandex 1253) | 162.159.x (Discord) | Calisiyor | Yok |

**Firefox:** network.trr.mode=5 (DoH kapali). Memory DNS cache yuzunden
process acikken gecici calisir, kapaninca bozulur. Bu Firefox dogal davranisi.

**ISS engeli:** HEM DNS zehirlenmesi (router → 195.175.254.2 Turk
Telekom engel sayfasi) HEM SNI-based DPI blocking var. Network
seviyesinde HTTPS SNI engeli mevcut. Cozum: DNS redirect + bypass mode
(`--auto-ttl --max-payload`).

**Onemli duzeltmeler (onceki yanlis tesHisler):**
- "ISS SADECE DNS zehirlenmesi, DPI/SNI YOK" (6. rev) → YANLIS (10. rev
  ile duzeltildi). ISS hem DNS hem SNI blocking yapiyor.
- "ISS Yandex DNS'i engelliyor" → YANLIS. Yandex 77.88.8.8:53 calisiyor.
- "captive portal" tesHisi → yanlis (goodbyedpi calisirken OLCU
  test edilmis, karisiklik olmus). Saf test (goodbyedpi kapali): Yandex,
  Cloudflare, Quad9, Google, AdGuard — hepsi port 53'te calisiyor.
- DoH workaround → IPTAL (kullanici reddetti, gereksiz).
- "-5 Cloudflare bot dogrulamasini tetikliyordu" (6. rev) → KISMEN YANLIS.
  curl ile test edildiginde `--auto-ttl --max-payload` de challenge gosteriyor.
  Ama gercek tarayicida JS challenge otomatik geciyor — sorun yok.

---

## 2. Derleme Ortami

```
C:\msys64\                          # MSYS2 (winget ile kuruldu)
  mingw64\bin\gcc.exe               # gcc 16.1.0 (mingw-w64)
  usr\bin\make.exe                  # GNU Make 4.4.1
  usr\bin\git.exe                   # git
C:\Program Files\Git\cmd\git.exe    # Git for Windows (2.55.0)
C:\Program Files\GitHub CLI\gh.exe  # gh CLI 2.96.0 (winget ile kuruldu)
```

**Derleme komutu (mingw64 shell):**
```sh
cd /c/Users/SelBuilds/Desktop/goodbyedpi-build/GoodbyeDPI/src
make BIT64=1 \
  WINDIVERTHEADERS=/c/Users/SelBuilds/Desktop/goodbyedpi-build/WinDivert-2.2.0-A/WinDivert-2.2.0-A/include \
  WINDIVERTLIBS=/c/Users/SelBuilds/Desktop/goodbyedpi-build/WinDivert-2.2.0-A/WinDivert-2.2.0-A/x64
```

PowerShell'den derleme:
```powershell
& 'C:\msys64\msys2_shell.cmd' -mingw64 -defterm -no-start -c 'cd /c/Users/SelBuilds/Desktop/goodbyedpi-build/GoodbyeDPI/src && make BIT64=1 WINDIVERTHEADERS=... WINDIVERTLIBS=... 2>&1 | tail -3'
```

Cikti: `goodbyedpi.exe` (PE32+ x86-64, ~120KB)

---

## 3. Dosya Yerlesimi

### 3.1 GitHub Repo (goodbyedpi-sel/) — YAYINLANDI

```
C:\Users\SelBuilds\Desktop\goodbyedpi-sel\           # GitHub repo
  .editorconfig                                       # UTF-8, LF, 4-space
  .gitignore                                          # *.o, src/goodbyedpi.exe, log'lar
  .github/
    workflows/build.yml                               # CI: WinDivert 2.2.0-A, x86+x86_64
    ISSUE_TEMPLATE/bug.yml, feature.yml, config.yml   # Issue sablonlari
  install.bat                                         # batch wrapper → src/install.ps1
  uninstall.bat                                       # batch wrapper → src/uninstall.ps1
  LICENSE                                             # Apache-2.0
  NOTICE                                              # ValdikSS kredisi + modifiye listesi
  README.md                                           # Tam dokümantasyon
  src/
    goodbyedpi.c                                      # MODIFIYE (--only-programs, --debug-proc, gate)
    goodbyedpi.h
    proctrack.c                                       # YENI - per-program tracker + hot-reload
    proctrack.h                                       # YENI
    Makefile                                          # MODIFIYE (-liphlpapi)
    blackwhitelist.c/.h                               # upstream (dokunulmadi)
    dnsredir.c/.h                                     # upstream
    fakepackets.c/.h                                  # upstream
    service.c/.h                                      # upstream
    ttltrack.c/.h                                     # upstream
    utils/                                            # getline, repl_str, uthash
    goodbyedpi-rc.rc                                  # Windows resource (icon, manifest)
    goodbyedpi.exe.manifest
    icon.ico
    start.ps1                                         # MODIFIYE (-5 kaldirildi)
    install.ps1                                       # scheduled task installer
    uninstall.ps1                                     # scheduled task uninstaller
    programs.txt                                      # whitelist (10 program)
    x86_64/
      goodbyedpi.exe                                  # MODIFIYE derlenen exe
      WinDivert.dll, WinDivert64.sys                  # dokunulmadi (imzali 2.2)
    x86/
      goodbyedpi.exe, WinDivert.dll, WinDivert32.sys  # 32-bit binary'ler
```

### 3.2 Build Dizini (goodbyedpi-build/) — GECICI

```
C:\Users\SelBuilds\Desktop\goodbyedpi-build\          # GECICI build dizini
  GoodbyeDPI\                                         # fork'lanan kaynak (git repo)
    src\
      proctrack.c, proctrack.h                        # YENI
      goodbyedpi.c, Makefile                          # MODIFIYE
      (diger .c/.h upstream'a dokunulmadi)
  WinDivert-2.2.0-A\WinDivert-2.2.0-A\               # SDK
    include\windivert.h
    x64\WinDivert.dll, .lib, WinDivert64.sys
```

### 3.3 Release Zip (GoodByeDPI-Plus-v1.0.0.zip)

```
GoodByeDPI-Plus-v1.0.0\                               # 246 KB, 12 dosya
  install.bat
  uninstall.bat
  src\
    start.ps1, install.ps1, uninstall.ps1
    programs.txt
    x86_64\goodbyedpi.exe, WinDivert.dll, WinDivert64.sys
    x86\goodbyedpi.exe, WinDivert.dll, WinDivert32.sys
```
- Kaynak kod (.c, .h, Makefile, utils/), .git, .github, .editorconfig,
  .gitignore, LICENSE, NOTICE, README.md HARIC TUTULDU.
- GitHub otomatik "Source code (zip)" ve "Source code (tar.gz)" uretti.

---

## 4. Kaynak Kod Degisiklikleri

### 4.1 proctrack.h (YENI)
- `proctrack_init(whitelist_file)` — whitelist yukle
- `proctrack_free()` — cleanup
- `proctrack_seed()` — baslangicta acik baglantilari tohumla
- `proctrack_start_flow_thread()` — WinDivert FLOW thread
- `proctrack_stop_flow_thread()`
- `proctrack_start_watcher_thread()` — hot-reload watcher
- `proctrack_stop_watcher_thread()`
- `proctrack_is_target(proto, local, lport, remote, rport, ipv6)` — main gate sorgusu
- `proctrack_stats(total, targets)` — debug sayac

### 4.2 proctrack.c (~884 satir, YENI — 4. revizyon)
- uthash tabanli 5-tuple → is_target harita (CRITICAL_SECTION korumali)
- Whitelist yukleme: basename-tam / yol-substring (case-insensitive, `/`→`\`)
- `match_pid(pid)` → OpenProcess + QueryFullProcessImageNameW + normalize + match_exe
- Tohumlama: GetExtendedTcpTable/UdpTable (AF_INET + AF_INET6, TCP+UDP)
- FLOW thread: WinDivertOpen("true", LAYER_FLOW, SNIFF|RECV_ONLY)
- **OS FALLBACK (RACE FIX):** `proctrack_is_target` haritada bulamazsa
  `GetExtendedTcpTable` ile PID'yi aninda cozup cache'ler. Bu, FLOW event
  gelmeden once ilk paketin gelmesi yaristimini cozer.
- UDP fallback: lokal-only entry (UDP tablosunda remote yok)
- **proctrack_last_method globali:** son lookup nasil cozuldu?
  0=map-hit, 1=udp-loc, 2=os-fallback, 3=unknown. --debug-proc icin.
- **HOT-RELOAD:** `whitelist_file_path` global, `proctrack_reload()`
  fonksiyonu, watcher thread (2s poll, GetFileAttributesExA ile mtime).
  programs.txt degisince: whitelist atomik swap + proc_map temizle + re-seed.
  Thread-safe: yeni whitelist lock disinda yukle, swap lock altinda, eski free.
  Windows native API (GetFileAttributesExA) kullanildi — stat() MinGW'da
  mtime degisimini gormuyordu (cache sorunu).
- Guvenli default: bilinmeyen → 0 (bypass uygulanmaz)

### 4.3 goodbyedpi.c (MODIFIYE — 4. revizyon)
1. `#include "proctrack.h"` (line ~23)
2. `long_options`: `{"only-programs", required_argument, 0, 'o'}` ve
   `{"debug-proc", no_argument, 0, 'O'}` eklendi
3. `do_only_programs = 0; only_programs_file = NULL; do_debug_proc = 0;
   proc_debug_count = 0;` degiskenleri
4. `case 'o':` → `proctrack_init(optarg)`, hata → die()
5. `case 'O':` → `do_debug_proc = 1`
6. **GATE (Stage 4 sonrasi, ~line 1262):**
   ```c
   if (do_only_programs && (ppTcpHdr || ppUdpHdr) &&
       !(ppUdpHdr && (do_dnsv4_redirect || do_dnsv6_redirect)))
   ```
   - DNS redirect aktifken UDP paketleri GATE'DEN MUAF (DNS global calismali)
   - TCP/UDP 5-tuple cikar (outbound: src=local, inbound: dst=local)
   - `proctrack_is_target()` → false ise reinject + continue
   - `--debug-proc` ile gate kararlog'u (ilk 300 paket, PASS/BLOCK + method)
7. "Filter activated" sonrasi: `proctrack_seed()` + `proctrack_start_flow_thread()`
   + `proctrack_start_watcher_thread()` (hot-reload icin)
8. `deinit_all()`: `proctrack_free()` eklendi (watcher + flow thread durur)
9. `fflush(stdout)` (debug icin)
10. Help metnine `--only-programs` ve `--debug-proc` satirlari

### 4.4 Makefile (MODIFIYE)
- LIBS: `-liphlpapi` eklendi (GetExtendedTcpTable/UdpTable icin)
- `$(wildcard *.c)` proctrack.c'i otomatik derler

### 4.5 start.ps1 (MODIFIYE — 8. revizyon, iki-modlu yapi)
- **IKI MOD:** Main mode (default) + Tray mode (`-TrayMode`)
  - **Main mode:** DNS detection yapar, goodbyedpi'yi baslatir, tray process'ini
    spawn eder ve **EXIT** olur (terminal kapanir).
  - **Tray mode:** Ayri gizli PowerShell process'te calisir. goodbyedpi PID'sini
    izler, tray icon gosterir. Local parametreler kullanir (scope sorunu yok).
- **param() blogu:**
  - `[switch]$NoTray` — tray'i kapat
  - `[switch]$NoDnsDetect` — DNS auto-detection'i kapat
  - `[switch]$TrayMode` — tray mode (ic kullanım)
  - `[int]$GoodbyePid` — tray mode: goodbyedpi process ID
  - `[string]$DnsLabel` — tray mode: status metni
  - `[string]$ProgramsList` — tray mode: programs.txt yolu
  - `[string]$IconPath` — tray mode: icon.ico yolu
- **Tray mode implementasyonu:**
  - NotifyIcon + ContextMenuStrip + hidden Form + ShowDialog (proper event loop)
  - Timer (500ms) ile goodbyedpi PID kontrolu — olurse balon + Form.Close()
  - "Edit programs.txt" → `Start-Process notepad -ArgumentList $ProgramsList` (local param, CALISIR)
  - "Stop & Exit" → `Stop-Process -Id $GoodbyePid -Force` (local param, CALISIR) + Application.Exit()
  - FormClosed event'inde notify.Visible=false + Dispose
- **Main mode akis:**
  1. Mevcut goodbyedpi'yi oldur (duplicate onle)
  2. DNS auto-detect (paralel, ~800ms, console'a yazdirir)
  3. goodbyedpi gizli baslat (PassThru ile PID al)
  4. 500ms health check (HasExited kontrol)
  5. Tray aciksa: `powershell.exe -STA -WindowStyle Hidden -File start.ps1 -TrayMode
     -GoodbyePid <PID> -DnsLabel "..." -ProgramsList "..." -IconPath "..."` spawn et
  6. **EXIT** — main script biter, terminal kapanir, tray ayri process'te kalir
- **Config blogu (ustte):**
  - `$enableTray = $true`, `$autoDetectDns = $true`, `$dnsTimeoutMs = 800`
  - `$dnsTestDomain = 'discord.com'`, `$blockPageRanges = @('195.175.254.')`
  - `$dnsCandidates` — 5 sunucu (Yandex 1253, Yandex 53, Cloudflare 53, Quad9 53, AdGuard 53)
  - `$fallbackDns` — Yandex 77.88.8.8:1253
- **DNS fonksiyonlari:** Build-DnsQuery, Parse-DnsResponseA, Test-PoisonedIp, Find-FastestDns
- **`-5` KALDIRILDI (6. rev):** ISS sadece DNS poisoning yapiyor, DPI/SNI engeli yok.
- **8. REVIZYON FIX'LERI:**
  1. Terminal kapanmıyor → Main mode tray'i spawn edip exit olur
  2. "Edit programs.txt" hatası → Tray mode'da $ProgramsList $script: scope'a kopyalanır
  3. "Stop & Exit" goodbyedpi'yi kapatmıyor → Tray mode'da $GoodbyePid $script: scope'a kopyalanır
  4. notepad.exe bulunamıyor → Start-Process -FilePath $script:ProgramsList (varsayilan uygulama)
  5. "Stop & Exit" → "Exit" olarak degistirildi
  6. **DNS switching (9. rev):** Tray menude DNS dropdown — aday sunucular listelenir,
     mevcut isaretli (Checked). Tiklayinca goodbyedpi yeniden baslatilir + yeni tray.
     "Auto-detect (re-test)" option da var. $ForceDnsIndex param ile manuel secim.
     DnsCandidatesInfo string: "Name|Addr|Port|TimeMs|Status;..." pipe-delimited.
     Main mode eski tray process'lerini (-TrayMode iceren powershell.exe) oldurur.

### 4.6 programs.txt (6. rev — generic default)
```
# Browsers
chrome.exe, msedge.exe, firefox.exe, opera.exe, brave.exe, vivaldi.exe
# Discord
discord.exe, DiscordPTB.exe, DiscordCanary.exe, Vesktop.exe
```

---

## 5. Sorun Gecmisi ve Cozum Denemeleri

### Sorun: Discord'a (Turkiye'de engelli) erisilemiyor

| Deneme | Sonuc | Sebep |
|--------|-------|-------|
| `-5` + DNS Yandex 77.88.8.8:**1253** + per-program | Calismadi | Yaristim: FLOW event gelmeden ilk paket gate'de "bulunamadi" → bypass uygulanmadi |
| OS fallback fix + ayni parametreler | Calismadi | DNS redirect per-program gate'inde takildi (svchost whitelist'te degil) |
| DNS gate muafiyeti + Yandex 1253 | Calismadi | ISS Yandex DNS'i tamamen engelliyor |
| DNS redirect YOK + per-program | Calismadi | ISS'nin DNS'i zehirlenmis (discord.com yanlis IP) |
| DNS redirect Cloudflare 1.1.1.1:**53** | Captive portal | ISS 1.1.1.1:53 engelliyor |
| DNS redirect YOK, kullanici Windows DNS=1.1.1.1 | Captive portal | ISS 1.1.1.1:53 engelliyor |
| **DNS redirect (Yandex 1253) + per-program (5. rev)** | **Calisti** | DoH kapali + DNS redirect aktif → Discord calisir |
| **DNS redirect (Yandex 1253) + `-5` YOK (6. rev)** | **Calisti + Cloudflare yok** | ISS sadece DNS poisoning, bypass trick'ler gereksiz ve Cloudflare tetikliyor |

### Sorun: Cloudflare bot dogrulamasi (6. rev)

| Deneme | Sonuc |
|--------|-------|
| goodbyedpi ACIK + `-5` + DNS redirect | Cloudflare bot dogrulamasi geliyor, gecemiyor |
| goodbyedpi KAPALI + DNS=Yandex (gecici) | Cloudflare yok, Discord calisir |
| goodbyedpi ACIK + `-5` YOK + DNS redirect | **Cloudflare yok, Discord calisir** |

**Sonuc:** `-5` bypass trick'leri (TLS fragmentation, fake packet, TTL
manipulation) Discord/Cloudflare sunucularina bot gibi gorunuyor.
ISS sadece DNS poisoning yaptigi icin bu trick'ler hic gerekli degil.

### Tespit edilen teknik sorunlar ve fix'ler

1. **Race condition (FLOW vs NETWORK):** FLOW ESTABLISHED event'i
   asenkron gelir, ilk NETWORK paketinden once gelmeyebilir.
   **Fix:** `proctrack_is_target` haritada bulamazsa `GetExtendedTcpTable`
   ile OS'tan PID cozup cache'ler. (proctrack.c ~line 622-700)

2. **DNS gate muafiyeti:** DNS redirect aktifken svchost.exe (sistem DNS
   cozucu) whitelist'te olmadigi icin DNS paketleri gate'de reinject
   edilip bypass disinda birakiyordu → DNS redirect calismiyordu.
   **Fix:** Gate sartina `!(ppUdpHdr && (do_dnsv4_redirect || do_dnsv6_redirect))`
   eklendi. DNS redirect aktifken tum UDP paketleri gate'den muaf.

3. **ISS DNS engeli:** Turkiye'deki ISS Yandex (77.88.8.8) ve Cloudflare
   (1.1.1.1) DNS sunucularini tamamen engelliyor. DNS redirect calismaz.
   **Workaround:** DoH (DNS over HTTPS) — Firefox'ta ayarlanir.

4. **Cloudflare bot dogrulamasi (6. rev):** `-5` bypass trick'leri
   Cloudflare bot dogrulamasini tetikliyordu.
   **Fix:** `-5` kaldirildi. ISS sadece DNS poisoning yaptigi icin
   bypass trick'ler gereksiz.

---

## 6. Test Dogrulamalari

### pt_test.exe (birim testi) — GEC TI
```
[proctrack] loaded 6 programs from 'programs.txt'
[proctrack] seeded 42 existing connections (total map: 42, targets: 25)
after seed: total=42 targets=25
flow thread started
opened persistent connection 192.168.1.20:3748 -> 1.1.1.1
is_target(this pt_test connection) = 0 (expected 0)  # pt_test whitelist'te degil
after flow: total=43 targets=25
PASS: FLOW thread captured new connection(s)
ALL CHECKS PASSED
```

### Gercek binary entegrasyon — GEC TI
```
[proctrack] loaded 10 programs from 'programs.txt'
Filter activated, GoodbyeDPI is now running!
Per-program mode: seeding existing connections...
[proctrack] seeded 31 existing connections (total map: 31, targets: 19)
[proctrack] FLOW tracker started.
```

### Cloudflare testi (6. rev)
- goodbyedpi KAPALI + DNS=Yandex → Vesktop Discord'a baglanir, Cloudflare yok
- goodbyedpi ACIK + `-5` YOK + DNS redirect → Vesktop Discord'a baglanir, Cloudflare yok
- Sonuc: Cloudflare bot dogrulamasi `-5` bypass trick'lerinden kaynaklaniyordu

---

## 7. GitHub Yayini (6. rev)

### Repo
- **URL:** `github.com/SelmanBuilds/GoodByeDPI-Plus`
- **Lisans:** Apache-2.0 (ValdikSS/GoodbyeDPI ile ayni)
- **Branch:** `main`
- **Commit:** `860ade3` (45 dosya, 6074 insertions)
- **Tag:** `v1.0.0`

### Release v1.0.0
- **URL:** `github.com/SelmanBuilds/GoodByeDPI-Plus/releases/tag/v1.0.0`
- **Assets:**
  - `GoodByeDPI-Plus-v1.0.0.zip` (246 KB, 12 dosya — end user)
  - `Source code (zip)` (GitHub otomatik)
  - `Source code (tar.gz)` (GitHub otomatik)
- Release zip'te kaynak kod, .git, .github, .editorconfig, .gitignore,
  LICENSE, NOTICE, README.md YOK — sadece calistirilabilir dosyalar.

### CI (GitHub Actions)
- `.github/workflows/build.yml`
- WinDivert 2.2.0-A (SHA256: `2a7630aac...`)
- Her `src/**` push'unda ve pull request'te tetiklenir
- x86_64 + x86 otomatik derleme, artifact upload
- Ubuntu-latest + gcc-mingw-w64

### gh CLI
- `C:\Program Files\GitHub CLI\gh.exe` (winget ile kuruldu)
- Auth: SelmanBuilds (token silindi, gerekirse yeniden uretilmeli)

---

## 8. Kalmasi Gereken / Yapilmasi Gereken

### Bekleyen: YOK — cozuldu
- **Cozum:** Windows sistem DNS'i Yandex 77.88.8.8 yapildi (adapter seviyesi,
  kalici). goodbyedpi kapali olsa bile DNS zehirlenmesi yok.
- goodbyedpi'nin DNS redirect'i (Yandex 1253) yedek olarak kaliyor (DHCP
  DNS sifirlarsa koruma).
- Per-program calisiyor (kanitlandi: --debug-proc ile 256 BLOCK / 2 PASS).
- Discord bypass tricks'e ihtiyac duymuyor (ISS sadece DNS zehirlenmesi
  yapiyor, DPI yok). Per-program sadece baska siteler/uygulamalar icin
  anlamlı.

### programs.txt duzenleme notu
- **HOT-RELOAD AKTIF (4. rev):** programs.txt degisince watcher thread (2s
  poll) whitelist'i otomatik yeniden yukler. goodbyedpi'yi yeniden
  baslatmaya GEREK YOK.
- Log: `[proctrack] watcher: mtime changed (...), reloading...` +
  `[proctrack] reloaded N programs from '...'`
- Reload sirasinda map temizlenir + re-seed edilir. Kisa boslukta
  (< 1ms) safe default (bypass yok) gecerli.

### Vesktop DoH ayari (5. rev — KRITIK)
- **Vesktop (Chromium) varsayilan DoH kullanir.** DoH = TCP 443 uzerinden
  DNS cozumer → goodbyedpi'nin UDP 53 DNS redirect'ini bypass eder.
  Bu, "goodbyedpi kapaliyken Discord calisiyor" sorununun asil sebebi idi.
- **Cozum:** Vesktop kisa yollarina (Start Menu + Desktop) su flag eklendi:
  `--disable-features=DnsOverHttps`
  Bu flag Chromium'un DoH'ini tamamen kapatir → Windows DNS (router) kullanir
  → goodbyedpi DNS redirect'ine bagimli hale gelir.
- Dogrulandi: DoH kapali + goodbyedpi kapali → 195.175.254.2 (engel) → Discord calismaz.
  DoH kapali + goodbyedpi acik → 162.159.x (Discord) → Discord calisir.
- Kisa yol konumlari:
  - `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Vesktop.lnk`
  - `%USERPROFILE%\Desktop\Vesktop.lnk`

### Firefox DoH ayari
- `network.trr.mode` = 5 (DoH KAPALI) — prefs.js'de ayarli.
- Firefox DoH kullanmaz → Windows DNS (router) kullanir.
- Memory DNS cache yuzunden process acikken gecici calisir (goodbyedpi
  kapali olsa bile), ama process kapaninca cache silinir → bir daha
  acilinca Windows DNS (zehirli) kullanir → bozulur.
- Bu Firefox dogal davranisi, goodbyedpi kontrol edemez.

### --debug-proc ile gate log'lama
```powershell
$exe = 'C:\Users\SelBuilds\Desktop\goodbyedpi-sel\src\x86_64\goodbyedpi.exe'
$wl  = 'C:\Users\SelBuilds\Desktop\goodbyedpi-sel\src\programs.txt'
$args = @('--dns-addr','77.88.8.8','--dns-port','1253','--dnsv6-addr','2a02:6b8::feed:0ff','--dnsv6-port','1253','--only-programs',('"' + $wl + '"'),'--debug-proc')
Start-Process -FilePath $exe -ArgumentList $args -WindowStyle Normal -RedirectStandardOutput 'debug.txt' -RedirectStandardError 'debug_err.txt'
```
Gate log format: `[GATE] TCP out 192.168.1.20:8364 -> 34.107.243.93:443 PASS method=map`
- PASS = gate gecti (bypass uygulanacak), BLOCK = gate takildi (reinject, bypass yok)
- method: map=cache hit, os-fallback=OS'tan cozuldu, UNKNOWN=bulunamadi
- Ilk 300 paket log'lanir (proc_debug_count limiti).

### Sistem DNS ayari
- **Windows sistem DNS degistirilMEDI** (router 192.168.1.1'de).
- DoH yok. goodbyedpi'nin DNS redirect'i (Yandex 1253) tek DNS cozumu.
- goodbyedpi ACIK → DNS redirect aktif → Discord dogru DNS → calisir.
- goodbyedpi KAPALI → router zehirli DNS → Discord bozulur.
- Orijinal goodbyedpi-orj ile AYNI davranis.

### Eger per-program kalici sorun cikarirsa
- `--only-programs` argumanini kaldir → tum trafik bypass (orijinal davranis)
- start.ps1'den `--only-programs` satirini kaldir yeter

### Derleme sonrasi deploy
```powershell
Copy-Item 'C:\Users\SelBuilds\Desktop\goodbyedpi-build\GoodbyeDPI\src\goodbyedpi.exe' `
          'C:\Users\SelBuilds\Desktop\goodbyedpi-sel\src\x86_64\goodbyedpi.exe' -Force
```

### Process management
```powershell
# Kill (tray host + goodbyedpi)
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object { $_.CommandLine -like '*start.ps1*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Get-Process -Name goodbyedpi -ErrorAction SilentlyContinue | Stop-Process -Force
sc.exe stop WinDivert
sc.exe stop WinDivert14

# Start via start.ps1 (DNS auto-detect + tray icon)
powershell -ExecutionPolicy Bypass -NoProfile -STA -File C:\Users\SelBuilds\Desktop\goodbyedpi-sel\src\start.ps1

# Start via start.ps1 (no tray, no DNS detect)
powershell -ExecutionPolicy Bypass -NoProfile -File C:\Users\SelBuilds\Desktop\goodbyedpi-sel\src\start.ps1 -NoTray -NoDnsDetect

# Start goodbyedpi directly (DNS redirect + per-program, -5 YOK)
$exe = 'C:\Users\SelBuilds\Desktop\goodbyedpi-sel\src\x86_64\goodbyedpi.exe'
$wl  = 'C:\Users\SelBuilds\Desktop\goodbyedpi-sel\src\programs.txt'
Start-Process -FilePath $exe -ArgumentList "--dns-addr","77.88.8.8","--dns-port","1253","--dnsv6-addr","2a02:6b8::feed:0ff","--dnsv6-port","1253","--only-programs","`"$wl`"" -WindowStyle Hidden

# Kalici kurulum
C:\Users\SelBuilds\Desktop\goodbyedpi-sel\install.bat
# Kaldir
C:\Users\SelBuilds\Desktop\goodbyedpi-sel\uninstall.bat
```

---

## 9. Mimari Hatirlatma

```
WinDivert NETWORK layer (w_filter)
  ↓ WinDivertRecv → paket
  ↓ Stage 4: parse (ppIpHdr/ppIpV6Hdr/ppTcpHdr/ppUdpHdr)
  ↓ GATE (per-program):
  │   if do_only_programs && (TCP||UDP) && !(UDP && DNS redirect):
  │     5-tuple cikar → proctrack_is_target()
  │       → haritada var: dondur
  │       → haritada yok: GetExtendedTcpTable'dan coz, cache'le
  │     false → reinject (bypass yok) + continue
  │     true  → devam (bypass uygulanacak)
  ↓ Stage 5: TCP data bypass (fragment, fake packet, SNI, Host)
  ↓ Stage 6: TCP no-data (TTL, window)
  ↓ Stage 7: UDP DNS redirect (DNS redirect aktifse, gate'den muaf)
  ↓ Stage 8: default reinject

Ayri thread: FLOW layer
  WinDivertRecv(FLOW) → (5-tuple, PID)
  match_pid(PID) → exe yolu → whitelist eslesme → is_target
  proc_map_set / proc_map_del

Ayri thread: Watcher (hot-reload)
  2s poll → GetFileAttributesExA → mtime degisti ise
  → proctrack_reload(): whitelist swap + map temizle + re-seed
```

---

## 10. Onemli Notlar

- **Proje adi:** GoodByeDPI-Plus
- **GitHub:** `github.com/SelmanBuilds/GoodByeDPI-Plus`
- **Lisans:** Apache-2.0 (ValdikSS/GoodbyeDPI'den fork)
- **Release:** v1.1.0 (temiz end-user zip + icon.ico + source code)
- WinDivert 2.2 (mevcut imzali .sys/.dll) ile uyumlu, surucu imzalama gerekmez
- Build kaynaklari `C:\Users\SelBuilds\Desktop\goodbyedpi-build\` altinda
- proctrack.c'de zararsiz uyarilar var (ipv4_copy_addr reading 16 bytes from
  size 4 — bilincli, dnsredir.h'in inline fonksiyonu 16 byte okur ama sadece
  ilk 4 byte kullanir)
- Kullanici admin oturumunda (SELMANBUILDS-PC\SelBuilds)
- Kullanici Vesktop kullaniyor (Discord degil), Vesktop.exe whitelist'te
- ISS Turkiye'de, Discord engelli
- **ISS HEM DNS HEM SNI DPI blocking yapiyor (10. rev kesfi)**
- **Bypass mode:** `--auto-ttl --max-payload` (start.ps1 $bypassMode config)
- Cloudflare challenge curl'de gorunuyor ama tarayicida JS ile otomatik geciyor
- **DNS auto-detection (7. rev):** start.ps1 5 sunucuyu paralel test eder,
  en hizli zehirlenmemis olani secer. Tum non-ASCII karakterler ASCII'ye
  donusturuldu (PowerShell 5.1 ANSI kodlama uyumu).
- **System tray (7. rev):** NotifyIcon + context menu. install.ps1 -STA flag,
  Interactive logon, ExecutionTimeLimit Zero. uninstall.ps1 tray host'u oldurur.
- **install.ps1 (7. rev):** `-GroupId 'Users'` → `-UserId $env:USERNAME -LogonType Interactive`
  (tray icon icin interactive session gerekli). `-STA` eklendi. `-ExecutionTimeLimit Zero`.
- **uninstall.ps1 (7. rev):** `Get-CimInstance Win32_Process` ile start.ps1 calistiran
  powershell.exe'i bulup oldurur (tray host).

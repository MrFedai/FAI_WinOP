# FAI_WinOP — Beyin Fırtınası, Mimari ve Roadmap

> Bu dosya kendi başına okunacak şekilde yazıldı. Geliştirme ortamındaki ajan (Ubuntu) bu konuşmayı görmeyecek; her şey burada.
> İlham kaynağı: [FR33THY/Ultimate](https://github.com/FR33THYFR33THY/Ultimate) (MIT). **Kod kopyalanmayacak**; ayarların mantığı incelenip yeniden tasarlanacak. README'de ilham kaynağına atıf verilecek.

---

## 0. Özet

**FAI_WinOP**: Windows 11 için kişisel, nesne tabanlı, profil odaklı optimizer.
Format sonrası tek komut → kullanıcının profili (ayarlar + uygulamalar + masaüstü/görev çubuğu düzeni) uygulanır.
Açık GitHub reposunda barınır; başka kullanıcılar kendi profillerini yazıp aynı komutla yükler.

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/MrFedai/FAI_WinOP/main/install.ps1))) -Profile fedai
```

Repo: **https://github.com/MrFedai/FAI_WinOP** (public)

İlk profil (`fedai`) hedef makinesi:
- Windows 11 **Pro**, Insider build 26300 (Home'dan yükseltildi)
- **Dizüstü** — Ryzen 7 7840HS, 32 GB RAM
- **Hibrit GPU** — RTX 4070 Laptop + Radeon 780M (masaüstünü 780M sürer)

---

## 1. Beyin fırtınası

### 1.1 Ultimate'ten öğrendiklerimiz
| Ultimate'te | Sorun | FAI_WinOP'ta |
|---|---|---|
| 108 ayrı `.ps1`, her biri menülü | Tekrar eden kod, toplu uygulama yok | Ayarlar **veri** (`.psd1`), motor **sınıf** |
| Geri alma = "Windows varsayılanına dön" | Kullanıcının önceki durumu kaybolur | Uygulamadan önce **snapshot**, `-Undo` gerçek önceki duruma döner |
| Bloatware: "şunlar dışındakileri sil" | WhatsApp, Claude gibi Store uygulamaları da silindi | **Kara liste** (adıyla), önizleme + onay, korunan liste |
| Uygulamalar elle indiriliyor (44 KB kod) | Bakımı zor, sürümler eskir | **winget / msstore**, katalog JSON |
| Riskli ve güvenli ayarlar aynı menüde | Yanlışlıkla güvenlik kapatılabilir | **Risk seviyesi** + çalışma anı onayı |
| Donanımdan bağımsız | Dizüstüne masaüstü ayarı uygulanıyor | **Koşullar** (`IsLaptop`, `HasNvidia`…) |
| Birçok dosya sadece ayar sayfası açıyor | Otomasyon yok | Mümkün olanlar doğrudan uygulanır |

### 1.2 Geliştirme ortamı — WSL Ubuntu + gerçek Windows 11 Pro
- Geliştirme: aynı makinede **WSL 2 Ubuntu** (ajan + pwsh 7 + Pester + PSScriptAnalyzer).
- Repo kullanıcının düzenine uygun olarak **WSL tarafında** durur: `~/PROJECTS/FAI_WinOP` (Windows'tan `\\wsl.localhost\Ubuntu\home\mrfedai\PROJECTS\FAI_WinOP`). Projeye `/proje-kur` ile bağlanır; ortak kurallar `~/PROJECTS/claude-ortak`'tan gelir (proje `CLAUDE.md`'si yalnız farkı yazar).
- Windows testleri için `tools/Sync-ToWindows.sh`: bundle + test dosyalarını `/mnt/c/Users/MrFedai/FAI_WinOP_test/` altına kopyalar. `powershell.exe` (5.1) ve Windows Sandbox (`MappedFolders` UNC yolu desteklemez) bu Windows kopyasını kullanır. WSL'den doğrudan `powershell.exe -ExecutionPolicy Bypass -File C:\Users\MrFedai\FAI_WinOP_test\...` çağrılabilir.
- `.gitattributes`: `*.ps1 *.psd1 *.psm1 *.cs text eol=crlf`, `*.json *.md text eol=lf` (WSL ↔ Windows satır sonu karmaşasını önler).
- Referans: Ultimate klasörü `C:\Users\MrFedai\Desktop\Ultimate` (WSL: `/mnt/c/Users/MrFedai/Desktop/Ultimate`) — sadece okunur, repoya girmez.
- Windows 11 **Pro** sayesinde: **Windows Sandbox** (her açılışta temiz, kapanınca silinen Win11) ve **Hyper-V** (tam temiz kurulum VM'i) kullanılabilir.

Ubuntu'da **PowerShell 7 (pwsh)** çalışır, ama hedef **Windows PowerShell 5.1** ve Windows API'leri (kayıt defteri, servisler, Appx, winget, COM) Linux'ta yok. Çözüm üç katmanlı test:

| Katman | Nerede | Ne test edilir |
|---|---|---|
| **Statik** | Ubuntu (pwsh) | PSScriptAnalyzer + **5.1 uyumluluk kuralları** (`PSUseCompatibleSyntax`, `PSUseCompatibleCommands` hedef: `desktop-5.1.14393.206-windows`), tweak/profil şema doğrulama, bundle üretimi |
| **Birim** | Ubuntu (pwsh + Pester 5) | Motor mantığı **sahte sağlayıcılarla** (FakeRegistry, FakeServiceManager…): koşullar, risk/onay, snapshot/undo, dry-run raporu, profil birleştirme |
| **Entegrasyon** | GitHub Actions `windows-latest` (**powershell.exe 5.1**) | Gerçek kayıt defteri/servis eylemleri (geri alınabilir test anahtarlarında), bundle'ın 5.1'de yüklenmesi |
| **Sandbox** | Windows Sandbox (yerel) | Her tweak grubu temiz bir Win11'de uygula → doğrula → `-Undo`; sandbox kapanınca her şey silinir. `tests/Sandbox/FAI_WinOP.wsb` repo klasörünü salt okunur bağlar ve testi otomatik başlatır |
| **Gerçek donanım** | Hedef dizüstü | Sandbox'ta geçen sürüm: `-DryRun` → geri yükleme noktası → uygula → `-Undo` |
| **Temiz kurulum** | Hyper-V VM | Win11 ISO + tek satır komut, uçtan uca (uygulamalar, bloatware, düzen) |

> Tasarım sonucu: **Her Windows bağımlılığı bir sağlayıcı (provider) arayüzünün arkasında olacak.** Eylemler doğrudan `Set-ItemProperty` çağırmaz; `$ctx.Registry.SetValue(...)` çağırır. Linux'ta sahte, Windows'ta gerçek sağlayıcı enjekte edilir.

> Not: Windows Sandbox, Appx/Store ve winget açısından sınırlıdır (Store yok, bazı paketler kurulamaz). Bloatware ve uygulama kurulumu fazları Hyper-V VM'de doğrulanır.

### 1.3 PowerShell 5.1 + sınıflar — bilinen tuzaklar
- 5.1'de sınıflar `using module` ile yüklenmeli; `irm | iex` akışında bu çalışmaz → **bundle** tüm sınıfları tek script'te, bağımlılık sırasına göre birleştirir.
- Sınıf içinde başka dosyadaki tip, parse anında bilinmeli → bundle sırası: `Core/Interfaces` → `Core/*` → `Actions/*` → `Providers/*` → `Engine` → `Cli`.
  `Core/*` alfabetik değil, `build/Bundle.ps1` içindeki `$coreOrder` bağımlılık sırasıdır (yeni Core dosyası eklenince oraya da yazılır). `Providers/Fake/*` yalnız `Bundle.ps1 -IncludeFakes` çıktısına (`dist/install.fakes.ps1`) girer.
- Sınıf yerel değişkeni, aynı sınıfın özellik adıyla (büyük/küçük harf fark etmez) atanamaz (`$ctx = ...` + `[ExecutionContext] $Ctx` özelliği = parse hatası). Yöntem argümanında `-f` ve virgül: `.Add('{0}' -f $a, $b)` iki argüman sayılır → `.Add(('{0}' -f $a, $b))`.
- Bundle dışı kod (testler) `[IServiceProvider]` gibi .NET ile çakışan adları parse anında .NET tipine çözer; bu yüzden arayüz adı `IServiceManager`. `Should -BeOfType [SınıfAdı]` betik içi sınıfları çözemez → `.GetType().Name` ile karşılaştır.
- Fonksiyondan dizi döndürmek: `return ,$dizi` (tek eleman / boş dizi açılmasın); `return (f)` yine açar, önce değişkene ata.
- Sınıf yönteminde `return (& $betik)` betik hiç çıktı vermezse 5.1'de `Index was out of range` fırlatır → `$out = @(& $betik)` ile topla, sonra döndür (`WindowsScriptHost::Invoke`). Sınıf yönteminde yalnız `try` içinde atanan değişken sonra okunursa ayrıştırma hatası ("Variable is not assigned") → önce varsayılan ata.
- Add-Type ile gelen native tip bundle ayrıştırılırken yoktur: sınıf gövdesinde `[FaiWinOP.Native.X]` yazılamaz → `('FaiWinOP.Native.X' -as [type])`. C# kaynakları 5.1 derleyicisi (C# 5) ile uyumlu yazılır.
- 5.1'de `?.`, `??`, ternary, `&&` yok. `ConvertFrom-Json -AsHashtable` yok → kendi `ConvertTo-Hashtable` yardımcı fonksiyonu.
- 5.1 varsayılan kodlaması → tüm dosyalar **UTF-8 BOM'lu** (Türkçe karakterler için şart).
- Native kısımlar (Core Audio ses seviyesi, Timer Resolution servisi) `Add-Type` ile C# olarak gömülü; Linux'ta derlenmez → sağlayıcının arkasında, birimde sahte.

### 1.4 Açık repo = güvenlik ve gizlilik
- Profillerde kişisel veri yok: Wi-Fi şifresi, lisans anahtarı, token, e-posta. Yollar `%USERPROFILE%` ile.
- `-Profile` üç kaynak kabul eder: repo içi ad (`fedai`), yerel yol (USB), URL (gizli gist).
- Release'lerde `install.ps1.sha256`; tek satır komut isteğe bağlı `-Version vX.Y.Z` alır.
- Repoya asla: korsan aktivasyon, imzasız üçüncü parti ikili dosyalar (ihtiyaç olursa resmi kaynaktan indirilir + hash doğrulanır).

---

## 2. Mimari

### 2.1 Katmanlar
```
Profile (JSON)  ──►  Engine  ──►  Tweak (psd1 veri)  ──►  Action (sınıf)  ──►  Provider (arayüz)
                       │                                                          ├─ Windows*  (gerçek)
                       ├─ ConditionEvaluator (donanım/sistem)                     └─ Fake*     (test)
                       ├─ RiskPolicy + Prompt (onay)
                       ├─ BackupStore (snapshot / undo)
                       └─ Reporter + Logger (dry-run raporu, log)
```

### 2.2 Sınıflar (taslak)
- `Tweak` — `Id, Title, Description, Category, Risk, Confirm, Conditions[], Actions[], Params`
- `ActionBase` (soyut) — `Test($ctx)`, `Snapshot($ctx)`, `Apply($ctx)`, `Revert($ctx, $snapshot)`, `Describe()`
  - `RegistryAction`, `ServiceAction`, `ScheduledTaskAction`, `AppxAction`, `WingetAction`, `PowerAction`, `FileAction`, `ShortcutAction`, `ScriptAction`, `NativeAction` (ses, timer)
- `Profile` — tweak id listesi, parametre geçersiz kılmaları, `apps[]`, `games[]`, `layout`, `exceptions`
- `ExecutionContext` — sağlayıcılar, `DryRun`, `Unattended`, logger, backup oturumu, sistem bilgisi
- `Condition` — `IsLaptop`, `HasNvidia`, `HasAmdGpu`, `HasIntelGpu`, `Edition`, `MinBuild`, `MinRamGB`
- `RiskPolicy` — `Safe` doğrudan · `Caution` ⚠ uyarı + E/H · `Risk` kırmızı uyarı + "EVET" yaz; `-Unattended` modda `Risk` asla uygulanmaz, `Caution` profilde `autoConfirm` yoksa atlanır

### 2.3 Tweak dosyası örneği
```powershell
# tweaks/sound/startup-sound-off.psd1
@{
  Id          = 'sound.startup-sound-off'
  Title       = 'Açılış sesini kapat'
  Description = 'Windows oturum açma sesini devre dışı bırakır.'
  Category    = 'sound'
  Risk        = 'Safe'
  Conditions  = @()
  Actions     = @(
    @{ Type='Registry'; Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\BootAnimation'; Name='DisableStartupSound'; Value=1; Kind='DWord' }
    @{ Type='Registry'; Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\EditionOverrides'; Name='UserSetting_DisableStartupSound'; Value=1; Kind='DWord' }
  )
}
```

### 2.4 CLI
```
install.ps1 [-Profile <ad|yol|url>] [-DryRun] [-Unattended] [-Undo [<oturum>]]
            [-Only <id,...>] [-Skip <id,...>] [-UpdatesOn] [-UpdatesOff]
            [-ExportProfile <ad>] [-ExportLayout] [-Version <vX.Y.Z>] [-List]
```
- `-Profile` yoksa etkileşimli menü (kategori → onay kutulu liste, risk renkleriyle).
- `-ExportLayout`: mevcut görev çubuğu sabitlemeleri + Başlat düzeni + masaüstü simgeleri profile yazılır.

### 2.5 Repo yapısı
```
FAI_WinOP/
  install.ps1                  # bundle çıktısı (CI üretir, elle düzenlenmez)
  src/
    Core/        Interfaces.ps1 Tweak.ps1 Profile.ps1 Condition.ps1 RiskPolicy.ps1
                 BackupStore.ps1 Logger.ps1 Reporter.ps1 ExecutionContext.ps1 Json.ps1
    Actions/     Registry Service ScheduledTask Appx Winget Power File Shortcut Script Native
    Providers/   Windows/*  Fake/*
    Native/      AudioEndpoint.cs  TimerResolution.cs
    Engine.ps1   Cli.ps1  Menu.ps1
  tweaks/        setup/ ui/ bloat/ privacy/ sound/ power/ graphics/ gaming/ system/
  apps/          catalog.json
  profiles/      fedai.json  _schema.json
  tests/         Unit/  Integration/  Fixtures/
  build/         Bundle.ps1  Lint.ps1  PSScriptAnalyzerSettings.psd1
  .github/workflows/  ci.yml (ubuntu: lint+unit+bundle; windows: integration 5.1)  release.yml
  docs/          TWEAKS.md (otomatik üretilen katalog)  PROFILE.md  CONTRIBUTING.md
  README.md  LICENSE (MIT)
```

---

## 3. `fedai` profili — kesin içerik

### 3.1 Hedef masaüstü (referans ekran görüntüsünden)
- Duvar kağıdı **düz siyah**, sistem **koyu tema**, saydamlık kapalı
- Masaüstü simgeleri: **Bu Bilgisayar** + **Geri Dönüşüm Kutusu** görünür, **sağ alt köşede** hizalı (simge konumu en iyi çaba; olmazsa "sağa hizala" yeterli)
- Görev çubuğu **ortalanmış**, **otomatik gizlenir**
- Sabitlemeler (sırayla): **Dosya Gezgini**, **Google Chrome** — başka hiçbir şey yok
- Arama kutusu, Görev Görünümü, Widgets, Copilot, Sohbet düğmeleri **yok**
- Sistem tepsisi: taşma oku + Wi-Fi + ses + pil; diğer simgeler taşma menüsünde
- Kilit ekranı ve hesap resimleri siyah

### 3.2 Tweak listesi
**Setup**
- `setup.mmagent-off` — bellek sıkıştırma + prefetch + uygulama ön yükleme kapalı (32 GB RAM)
- ~~`setup.edition-pro`~~ — makine artık Pro; katalogda isteğe bağlı `Caution` tweak olarak kalır (koşul `Edition=Core`), `fedai`'de yok
- `setup.background-apps-off` — istisna: **WhatsApp, Telegram**
- `setup.store-optimize` — Store otomatik güncelleme/video/kişiselleştirme kapalı; Store uygulamaları `winget upgrade` ile güncellenir
- `setup.updates-staged` — önce **bekleyen tüm güncellemeler** kurulur (gerekirse yeniden başlatma sonrası devam), sonra **365 gün duraklatılır**; `-UpdatesOn/-UpdatesOff`
- Dil, bölge, klavye ve saat dilimine **dokunulmaz** — kullanıcı kendisi ayarlar

**Fare** (kullanıcının mevcut ayarları, ekran görüntüsü + kayıt defterinden okundu)
- `input.mouse` — parametreler: birincil düğme **Sol**, işaretçi hızı **7** (`MouseSensitivity`), **İşaretçi hassasiyetini artır: AÇIK** (`MouseSpeed=1`, `Threshold1=6`, `Threshold2=10`), tekerlek **satır satır, 5 satır** (`WheelScrollLines`), **etkin olmayan pencereleri kaydır: AÇIK** (`MouseWheelRouting=2`), kaydırma yönü normal
- Not: Ultimate işaretçi hassasiyetini kapatır; `fedai` profili bilinçli olarak **açık** tutar

**Uygulamalar** (winget sessiz; kimlikler Faz 4'te doğrulanacak)
Claude · Telegram · WhatsApp (msstore) · Discord · Steam · TradingView · Ollama · VS Code · Proton VPN · Google Chrome (**varsayılan tarayıcı**) · Spotify · OBS Studio
Kurulum sonrası: otomatik başlatma kaldır (`keepAutostart` istisna listesi), Başlat kısayollarını düzleştir, **masaüstü kısayolu oluşturma / oluşanları sil**.

**Graphics**
- `graphics.nvidia-settings` · koşul `HasNvidia`
- `graphics.amd-settings` · koşul `HasAmdGpu`
- `graphics.p0-state` · **Caution** — her çalıştırmada "⚠ dizüstünde pil ve ısı artar" uyarısıyla sorulur

**UI**
- `ui.theme-black` · `ui.lockscreen-black` · `ui.account-pictures-black`
- `ui.taskbar` — 3.1'deki düzen (ortalı, otomatik gizle, 2 sabitleme, düğmeler kapalı)
- `ui.desktop-icons` — Bu Bilgisayar + Geri Dönüşüm Kutusu
- `ui.widgets-off` · `ui.copilot-off` · `ui.notepad-settings`
- `ui.explorer` — Bu Bilgisayar açılır, uzantılar görünür, tam yol, Galeri/Ana Sayfa/3D Nesneler gizli
- `ui.visual-effects` — animasyon/gölge/solma kapalı, yazı yumuşatma açık
- `ui.notifications` — sistem/öneri bildirimleri kapalı, istisna: **WhatsApp, Telegram**

**Bloatware**
- `bloat.remove` — kara liste, önizleme + onay; **korunan:** Store, Ekran Alıntısı Aracı, WhatsApp, Claude, profildeki tüm uygulamalar, sistem bileşenleri
- `bloat.persistence` — provisioned paketler, ContentDelivery/önerilen uygulamalar kapalı, büyük güncelleme sonrası yeniden çalışan görev
- `bloat.edge-remove` — Edge kaldır, **WebView2 kalır** (güncellemeleri açık), `microsoft-edge:` → varsayılan tarayıcı, Edge'in geri kurulması politika ile engelli (WhatsApp'ın WebView2 bağımlılığı doğrulanacak)

**Gizlilik ve ses**
- `sound.startup-sound-off` · `sound.volume` `{ level: 15 }`
- `privacy.telemetry` — min seviye, DiagTrack + dmwappushservice, CEIP/uyumluluk görevleri, reklam kimliği, tailored experiences, geri bildirim, hata raporlama, etkinlik geçmişi
- `privacy.app-permissions` — kapalı, **kamera ve mikrofon açık**
- `privacy.search-ads` — web araması, vurgular, öneriler, reklamlar kapalı

**Sistem ve güç**
- `system.restore-point` — her çalıştırmada ilk adım
- `power.plan` — `IsLaptop` ise iki varyant: **prizde** yüksek performans (park/throttling kapalı), **pilde** dengeli (uyku/hazırda bekletme açık)
- `system.timer-resolution` — 0.5 ms servis
- `refresh.reboot-to-bios` — menü aracı (otomatik çalışmaz)

**Gaming**
- `gaming.per-game` — profilde `games[]`: her oyun için `priority`, `smtOff`, `excludeCore0` (varsayılan liste boş, SMT/çekirdek test amaçlı)

### 3.3 Bilinçli olarak dahil edilmeyenler
1 Check ve 7 Hardware (seçilmedi) · Keys (korsan) · PC Build Guide · ReBar force · MPO · FSE/Composed flip · ULPS · Defender/Firewall/Spectre/DEP/WHQL (katalogda `Risk` olarak tanımlanabilir, `fedai`'de yok) · Edge optimize (Edge kaldırılıyor) · görev çubuğunu sola hizalama (kullanıcı ortalı istiyor)

---

## 4. Roadmap

Her faz kendi başına bir ajan promptu olarak verilebilir. Bir faz **kabul kriterleri** sağlanmadan sonrakine geçilmez.

### Faz 0 — Repo iskeleti ve araçlar
**Prompt:**
> FAI_WinOP reposunun iskeletini 2.5'teki yapıyla kur. Ubuntu'da pwsh 7 hazır (7.7.0); Pester 5 ve PSScriptAnalyzer'ı `CurrentUser` kapsamında kur. `build/PSScriptAnalyzerSettings.psd1` içinde PS 5.1 uyumluluk kurallarını (`PSUseCompatibleSyntax`, `PSUseCompatibleCommands`, hedef `desktop-5.1.14393.206-windows`) etkinleştir. `build/Lint.ps1`, boş `build/Bundle.ps1` ve `.github/workflows/ci.yml` yaz: ubuntu job'u lint + unit, windows-latest job'u `powershell.exe` (5.1) ile bundle yükleme testi. Tüm `.ps1/.psd1` dosyaları UTF-8 BOM. 1.2'deki `.gitattributes` kurallarını ekle. `tools/Sync-ToWindows.sh` yaz (1.2). `tests/Sandbox/FAI_WinOP.wsb` yaz: Windows'taki test kopyasını sandbox'a salt okunur bağlasın, açılışta `powershell.exe` ile `tests/Sandbox/Run.ps1`'i çalıştırsın ve sonucu bağlı bir `out/` klasörüne yazsın. README (ilham kaynağı atfı dahil) ve MIT LICENSE ekle.

**Kabul:** CI iki işletim sisteminde yeşil; lint bilerek eklenen bir `??` operatörünü yakalıyor.

### Faz 1 — Çekirdek motor (Linux'ta tamamen test edilebilir)
**Prompt:**
> 2.2'deki sınıfları yaz: `Tweak`, `ActionBase`, `Profile`, `Condition`, `RiskPolicy`, `BackupStore`, `Logger`, `Reporter`, `ExecutionContext`. Sağlayıcı arayüzlerini (`IRegistryProvider`, `IServiceManager` (Faz 1'de `IServiceProvider` yerine bu ad: `System.IServiceProvider` ile çakışıyordu), `ITaskProvider`, `IAppxProvider`, `IPackageProvider`, `ISystemInfoProvider`, `IPromptProvider`) tanımla ve her biri için `Fake*` uygulamasını yaz. Engine akışı: profil yükle → tweak'leri çöz → koşulları değerlendir → risk politikası/onay → snapshot → uygula → rapor. `-DryRun` hiçbir sağlayıcıyı yazma modunda çağırmaz. `-Undo` son oturumun snapshot'ını ters sırada geri uygular. `.psd1` tweak ve `.json` profil için şema doğrulayıcı yaz. 5.1 için `ConvertTo-Hashtable` yardımcı fonksiyonunu ekle. Her şey Pester ile Fake sağlayıcılara karşı test edilsin.

**Kabul:** Birim testleri: koşul atlama, Caution onay red/kabul, Risk'in `-Unattended` modda asla uygulanmaması, snapshot → undo'nun başlangıç durumunu birebir geri getirmesi, dry-run'da sıfır yazma.

### Faz 2 — Windows eylemleri ve sağlayıcıları
**Prompt:**
> `Windows*` sağlayıcılarını ve eylemleri yaz: Registry (HKLM/HKCU/HKU, DWord/QWord/String/ExpandString/Binary/MultiString, değer silme), Service (başlangıç türü + durum), ScheduledTask (etkin/devre dışı), Appx (kullanıcı + provisioned), Winget/MsStore, Power (powercfg, AC/DC ayrı), File, Shortcut, Script. Native: `AudioEndpoint.cs` (varsayılan çıkış sesi oku/yaz) ve `TimerResolution.cs` (servis) `Add-Type` ile. Her eylem `Snapshot` + `Revert` desteklesin. Entegrasyon testleri `windows-latest`'te `powershell.exe` ile, sadece `HKCU:\Software\FAI_WinOP_Test` gibi zararsız anahtarlarda.

**Kabul:** Windows CI'da her eylem türü için uygula → doğrula → geri al döngüsü geçiyor.

**Faz 2 notları (uygulama kararları):**
- Eylem türleri: `Registry` · `Service` (StartType'a `AutomaticDelayedStart` eklendi) · `ScheduledTask` · `Appx` (yalnız kaldırma; kurulum `Winget` + `Source='msstore'`) · `Winget` · `Power` (ayar kipi AC/DC ayrı; `ActiveScheme` kipi) · `File` · `Shortcut` · `Script` · `Volume` · `TimerResolution`. Alanlar her dosyanın başındaki örnekte; şema `Get-FaiActionError`.
- Yeni arayüzler: `IFileProvider`, `IShortcutProvider`, `IPowerProvider`, `IScriptHost`, `IAudioProvider`, `ITimerResolutionProvider`; `IAppxProvider.RestoreInstalled`, `IRegistryProvider.DeleteEmptyKey`. Gerçek bağlam: `New-FaiWindowsContext`.
- Registry geri alma: değer için oluşturulan anahtar zinciri (snapshot `MissingFrom`) boş kaldıysa silinir → birebir dönüş.
- Appx geri alma: kullanıcı paketi provisioned kopyadan yeniden kaydedilir; provisioned kopya kaldırıldıysa dönüş yok → hata değil uyarı (Faz 5'te tweak'in Risk/açıklamasına yazılır).
- File / Shortcut snapshot'ı dosyanın baytlarını (base64) tutar; 5 MB üstü dosyaya dokunulmaz.
- Native: `src/Native/*.cs` bundle'a `Get-FaiNativeSource` ile gömülür. Ses bellekte `Add-Type`; TimerResolution ayrı `powershell.exe` sürecinde `.exe`'ye derlenir, `FAI_TimerResolution` servisi olarak kurulur (`%ProgramFiles%\FAI_WinOP`). Win11'de sistem geneli etki için `GlobalTimerResolutionRequests=1` gerekir (Faz 7 tweak'i).
- Power okuma `powercfg /qh` (gizli ayarlar dahil) çıktısının son iki onaltılık değeri (AC, DC); yerelleştirmeden bağımsız.
- Entegrasyon: `tests/Integration/Windows-Actions.ps1` — gerçek sağlayıcılarla her tür uygula → doğrula → geri al + motor `-Undo`. Yalnız `GITHUB_ACTIONS=true` ya da Sandbox (`WDAGUtilityAccount`) içinde çalışır; gerçek makinede `-Force` olmadan 2 ile çıkar. CI windows job'unda ve `tests/Sandbox/Run.ps1`'de koşar. Appx gerçek kaldırma yalnız makinede provisioned kopyası olan aday paket varsa, Winget yalnız winget varsa koşar (yoksa ATLA; Sandbox'ta ikisi de yok) — tam doğrulama Faz 4/5'te Hyper-V VM.

### Faz 3 — Tweak kataloğu: kullanıcının öncelikli istekleri
**Prompt:**
> Şu tweak'leri `.psd1` olarak yaz ve her birine açıklama, risk, koşul ekle: `sound.startup-sound-off`, `sound.volume` (parametre `level`, varsayılan 15), `privacy.telemetry` (Home/Pro'da mümkün olan en düşük seviye — `AllowTelemetry=0` yalnızca Enterprise/Education'da tam etkili; sürüme göre nelerin etkisiz olduğunu açıklamada belirt), `privacy.app-permissions` (kamera/mikrofon hariç), `privacy.search-ads`, `ui.explorer`, `ui.visual-effects`, `ui.notifications` (istisna listesi parametresiyle). Ultimate'teki `6 Windows/22 Control Panel Settings.ps1` dosyasını sadece **referans** olarak kullan; değerleri tek tek doğrula, kopyalama. `docs/TWEAKS.md` katalog dosyasını tweak dosyalarından otomatik üreten script yaz.

**Kabul:** Şema doğrulamasından geçiyor; dry-run raporu her tweak için okunabilir bir değişiklik listesi veriyor.

**Faz 3 notları (uygulama kararları):**
- Yeni eylem türü `RegistryEach`: bir anahtarın her alt anahtarına aynı değeri yazar, `Exclude` (-like kalıpları, parametre dizisi düzleştirilir) hariç; yeni anahtar oluşturmaz. Yeni arayüz yöntemi `IRegistryProvider.GetSubKeyNames`. `ui.notifications` bununla "hepsi kapalı, istisnalar açık" yapar; `setup.background-apps-off` (istisna listesi) aynı eylemi kullanabilir.
- `ui.notifications`: `ToastEnabled=1` (Ultimate genel anahtarı kapatıyor; o zaman istisna çalışmaz), gönderenler tek tek kapalı; Defender / Windows Güvenliği / Güvenlik ve Bakım her zaman korunur. Uygulamanın bildirim anahtarı ilk bildiriminde oluşur → profil uygulamalardan (Faz 4) sonra yeniden çalıştırılınca yakalanır.
- Değerler Ultimate'le değil, bu makinede (`reg.exe query`, salt okunur; 11 Pro 26H2) doğrulandı. Ultimate farkları: `UserPreferencesMask` Ultimate'te `hex(2)` (REG_EXPAND_SZ) yazılmış, doğrusu REG_BINARY; "animate controls" biti kapalı (makinedeki değer). `musicLibrary` ve `systemAIModels` izinleri yalnız HKCU'da var; `downloadsFolder` / `passkeys` 26H2'de yok → yazılmadı. Uyumluluk görevi 26H2'de `Microsoft Compatibility Appraiser Exp` adını almış (ikisi de listede; olmayan görev atlanır).
- `ui.explorer`: Ana Sayfa `HubMode=1` ile (Ultimate'in CLSID yöntemi yeni sürümde bozuk), Galeri CLSID `System.IsPinnedToNameSpaceTree=0`, 3D Nesneler `ThisPCPolicy=Hide` (Windows 11'de zaten yok, güvence). Ana Sayfa gizleme Faz 9'da gerçek donanımda doğrulanacak.
- `ui.visual-effects`: pencere sürüklerken içerik ve Peek açık bırakıldı (istek: animasyon / gölge / solma kapalı).
- Katalog belgesi: `build/TweaksDoc.ps1` → `docs/TWEAKS.md` (parametresiz yazar; `-Check` CI'da güncellik denetimi). Kabul testleri `tests/Unit/Catalog.Tests.ps1`: şema, dosya yolu = Id, kişisel veri yok, tam katalog dry-run (sıfır yazma, her tweak ÖNİZLEME + satırlar), uygula → ZATEN UYGUN → `-Undo` = başlangıç durumu, profil parametreleri.

### Faz 4 — Uygulama kataloğu ve kurulum
**Prompt:**
> `apps/catalog.json` yaz: her uygulama için `id`, `source` (winget/msstore), `packageId`, `postInstall` kuralları (`removeAutostart`, `flattenStartMenu`, `removeDesktopShortcut`, `startupRegistryNames`, `startupTaskNames`). 3.2'deki 12 uygulamanın kimliklerini `winget search` ile doğrulayan bir script ekle (Windows CI'da çalışır). Varsayılan tarayıcı ayarı için yöntemi araştır (Win11'de UserChoice hash koruması var; güvenilir yol yoksa kullanıcıya Ayarlar sayfasını açıp yönlendir). WhatsApp'ın WebView2 bağımlılığını araştırıp `docs/` altına not düş.

**Kabul:** Tüm paket kimlikleri doğrulanmış; kurulum sonrası masaüstünde yeni kısayol kalmıyor.

**Faz 4 notları (uygulama kararları):** ayrıntı `docs/APPS.md`.
- Profil `apps`: `"chrome"` ya da `{ "id": "telegram", "keepAutostart": true }`. Motor uygulamaları tweak'lerden ÖNCE
  `app.<id>` tweak'i olarak işler (Faz 6 Chrome sabitlemesi ve `ui.notifications` istisnaları kurulu uygulama ister;
  Faz 7 `system.restore-point` "ilk adım" kalacaksa motorun ön adımı olmalı) (`ConvertTo-FaiAppTweak`; `Invoke-FaiEngine -AppCatalog`). Katalog alanları roadmap'teki
  listeye ek: `startupFolderNames` (Başlangıç klasörü .lnk), `desktopShortcutNames`, `startMenuFolders`, `notes`.
- Yeni eylem `App` (kurulum + düzen tek eylemde): otomatik başlatma Run değeri silinerek değil `StartupApproved` kapalı
  işaretiyle (Görev Yöneticisi gibi; uygulama Run'ı yeniden yazsa da kapalı); jokersiz ad önceden kapatılır. Masaüstü:
  kurulum anındaki önce / sonra farkı + bilinen adlar. Başlat: klasör köke düzleştirilir.
- Geri alma günlüğü: `App.Apply` dokunduğu her şeyin eski hâlini snapshot'a ekler, motor Apply sonrası oturumu yeniden
  kaydeder (`Session.Save()`); kurulduğu çalıştırma geri alınırsa uygulama kaldırılır.
- Yeni arayüzler: `IRegistryProvider.GetValueNames`, `IFileProvider.ListFiles / DeleteEmptyDirectory / GetKnownFolder`
  (OneDrive yönlendirmeli masaüstü için), `IShellProvider.OpenUri`.
- Varsayılan tarayıcı: `setup.default-browser` (Caution, eylem `DefaultBrowser`) — UserChoice karması + UCPD yüzünden
  programla yazılmaz; `ms-settings:defaultapps?registeredAppMachine=Google%20Chrome` açılır, kullanıcı tek tıklar, sonuç
  `UserChoiceLatest\ProgId` (yoksa `UserChoice`) ile denetlenir. Etkileşimsiz kipte uygulanmaz.
- Kimlikler: 12/12 `winget show` ile doğrulandı; `tests/Integration/App-Ids.ps1` Windows CI'da her push'ta. Gerçek kurulum
  `tests/Integration/Apps-Install.ps1` (CI `apps` işi yalnız elle tetikleme; Hyper-V VM'de `-Force -Undo`): masaüstünde
  yeni kısayol kalırsa HATA + Run / Başlangıç / Başlat keşif dökümü → katalogdaki tahmini adlar bununla düzeltilir.
- WhatsApp Temmuz 2025'ten beri WebView2 tabanlı → Faz 5'te WebView2 Runtime + güncellemesi korunmalı.
- İlk CI `apps` koşusu: 11 kurulum, masaüstünde 0 yeni kısayol (kabul), ikinci çalıştırma ZATEN UYGUN. Spotify winget
  kurucusu yönetici oturumunu reddediyor → Store (`9NCBCSZSJRSB`). Araç yönetici çalıştığından yönetici olmadan kurulmak
  isteyen başka kurucu çıkarsa aynı yol (Store) ya da kullanıcı bağlamında kurulum (henüz yok).
- Steam geri alma: kaldırma kaydında sessiz komut yok → winget kaldırıcıyı argümansız (etkileşimli) başlatır ve yine
  başarı döner. Katalog alanı `quietUninstall { path, args }` → `IPackageProvider.RunUninstaller`. Her kaldırmadan sonra
  paket listeden düşene kadar beklenir (120 sn), düşmezse HATA.

### Faz 5 — Bloatware ve Edge
**Prompt:**
> `bloat.remove` için açık bir kara liste yaz (joker yok, her paket adıyla). Korunan liste: Store, Ekran Alıntısı Aracı, WhatsApp, Claude, profildeki tüm uygulamalar, sistem bileşenleri (Ultimate'teki `13 Bloatware.ps1` içindeki "breaks …" notlarını referans al). Çalışmadan önce silinecekleri tablo halinde göster ve onay iste. `bloat.persistence`: provisioned paket kaldırma, ContentDeliveryManager/önerilen uygulama kapatma, büyük güncelleme sonrası temizliği tekrarlayan zamanlanmış görev. `bloat.edge-remove`: Edge'i kaldır, WebView2'ye dokunma, `microsoft-edge:` protokolünü varsayılan tarayıcıya yönlendir, EdgeUpdate politikasıyla Edge'in yeniden kurulmasını engelle ama WebView2 güncellemesine izin ver.

**Kabul:** Dry-run listesinde korunan hiçbir paket yok; birim testi korunan listeyi kara listeyle kesişmeye karşı doğruluyor.

**Faz 5 notları (uygulama kararları):**
- Kara liste veri: `tweaks/bloat/remove.psd1` (44 `Appx` eylemi, `Scope=User`, joker yok). Korunan liste kod:
  `Get-FaiBloatProtected` (`src/Core/Bloat.ps1`, `-like` kalıbı + gerekçe; Ultimate "breaks …" notları dahil). Korumada
  joker güvenli tarafta (fazla korur). Profil uygulamaları: katalogda yeni alan `appxNames` (WhatsApp, Spotify).
- Çalışma anı koruması: motor her çalıştırmada `ExecutionContext.ProtectedAppx`'i doldurur; `Appx` ve `AppxCleanup`
  eşleşen pakete dokunmaz (Test `$true`, önizlemede "korunuyor"). Kara listeye yanlışlıkla korunan ad girse de silinmez.
- Onay tablosu: Caution / Risk sorusunda bekleyen eylemlerin önizlemesi numaralı tablo olarak gösterilir
  (`RiskPolicy.Decide(..., $Details)`; bütün Caution tweak'ler için genel).
- `bloat.remove` yalnız kullanıcı paketi (geri alınabilir); `bloat.persistence` provisioned kopyayı kaldırır (geri
  alınamaz) + ContentDeliveryManager / CloudContent + açılış görevi. Yeni eylem `AppxCleanup`: görev `\FAI_WinOP\BloatCleanup`
  (SYSTEM, açılışta) `%ProgramData%\FAI_WinOP\BloatCleanup.ps1`'i çalıştırır; yapı numarası (CurrentBuild.UBR)
  değiştiyse listeyi bütün kullanıcılardan + provisioned'dan yeniden kaldırır, günlük `BloatCleanup.log`. Ad listesi
  remove ile birebir (birim testi). Yeni arayüz yöntemleri: `ITaskProvider.GetTaskAction / RegisterStartupTask / UnregisterTask`.
- `bloat.edge-remove`: yeni eylem `EdgeRemove` + `IEdgeProvider` (Edge'in kendi `setup.exe --uninstall --system-level
  --force-uninstall`; AB dışı engeli için geçici SystemApps\…\MicrosoftEdge.exe; yalnız `msedge` süreçleri durur).
  EdgeUpdate'e dokunulmaz (WebView2 güncellemesi onunla): ilke `Install{56EB18F8…}=0` (Edge), `Install/Update{F3017226…}=1`
  (WebView2). `microsoft-edge:` → `HKLM\SOFTWARE\Classes\microsoft-edge` + `EdgeRedirect.ps1` (yalnız http / https).
  `EdgeRemove` tweak'te ilk eylem: geri alma ters sırada, ilke kalkınca Edge winget ile kurulur.
- Bu makinede salt okunur dry-run (5.1): `bloat.remove` ZATEN UYGUN (Ultimate temizlemiş), Edge 158 + WebView2 158;
  Claude'un Appx adı `Claude` (korunuyor). CI `windows` işine 3 adım: AppxCleanup gerçek görev döngüsü, Edge salt okunur,
  Faz 5 dry-run (korunan paket planlanmamalı).
- Açık (VM'de doğrulanacak): Edge kaldırıcısının gerçek davranışı ve WebView2'nin kaldığı, `microsoft-edge:` yönlendirmesi
  (UserChoice Edge'e bağlıysa Windows bir kez sorabilir), Appx kaldır → geri kaydet döngüsü, açılış görevinin büyük
  güncelleme sonrası çalışması. Windows Update ayrı Edge paketi gönderirse Edge geri gelebilir.

### Faz 6 — Masaüstü ve görev çubuğu düzeni
**Prompt:**
> 3.1'deki hedef masaüstünü uygulayan tweak'leri yaz: `ui.theme-black` (koyu tema, saydamlık kapalı, düz siyah duvar kağıdı), `ui.taskbar` (ortalı, otomatik gizle — StuckRects3, sabitlemeler sadece Dosya Gezgini + Chrome, arama/görev görünümü/widgets/copilot düğmeleri kapalı), `ui.desktop-icons` (Bu Bilgisayar + Geri Dönüşüm Kutusu; sağ alt hizalama en iyi çaba), `ui.lockscreen-black`, `ui.account-pictures-black`, `ui.widgets-off`, `ui.copilot-off`, `ui.notepad-settings`. `-ExportLayout` komutunu yaz: mevcut sabitlemeleri, Başlat düzenini ve masaüstü simge ayarlarını profile `layout` bölümü olarak kaydetsin; uygularken aynı düzeni geri yüklesin.

**Kabul:** Referans ekran görüntüsüyle aynı görünüm; `-ExportLayout` → `-Undo` → profil uygula döngüsü düzeni birebir geri getiriyor.

**Faz 6 notları (uygulama kararları):**
- 8 tweak `tweaks/ui/`: `theme-black` (koyu + saydamlık kapalı + vurgu #191919, paletin açık tonları gri: Ayarlar
  düğmeleri okunur; düz siyah masaüstü: `WallPaper=''`, `Colors\Background='0 0 0'`, `BackgroundType=1`), `taskbar`,
  `desktop-icons`, `lockscreen-black` (üretilen `C:\ProgramData\FAI_WinOP\Black.png` + PersonalizationCSP; yol C: varsayılır,
  ilke değeri ortam değişkeni açmaz), `account-pictures-black` (varsayılan resimler boyutu korunarak siyah), `widgets-off`
  (yalnız ilke: `TaskbarDa` UCPD korumalı), `copilot-off`, `notepad-settings` (settings.dat; değer adları Ultimate'ten,
  anlamları VM'de doğrulanacak). Sohbet düğmesi `TaskbarMn` yerine ilke `ChatIcon=3`.
- Yeni eylemler: `RegistryByte` (ikili değerin tek baytı + maske: StuckRects3 8. bayt 0. bit = otomatik gizle),
  `TaskbarPins`, `SolidImage` (tek renk görüntü, `IImageProvider` System.Drawing), `AppSetting` (paketli uygulama
  settings.dat hive'ı: `reg load` + ham tür 0x5F5E10B bool / 0x5F5E104 int32 + 8 bayt FILETIME; `IAppSettingsProvider`),
  `File` + `Base64` (ikili içerik). Native `src/Native/ShellNative.cs`: duvar kağıdı, masaüstü rengi, WM_SETTINGCHANGE, ham
  kayıt defteri değeri.
- Görev çubuğu sabitlemeleri: Windows'un desteklenen yolu, tek seferlik. Taskband değerleri + `User Pinned\TaskBar`
  silinir → `LayoutModification.xml` (`PinListPlacement="Replace"`) + HKCU "Start Layout" ilkesi (`LockedStartLayout=1`) →
  Gezgin yeniden başlar → düzen Taskband'e yazılınca ilke ve XML eski haline döner (kullanıcı sonra serbestçe sabitler).
  Mevcut sabitlemeler: kısayol hedefi; Windows 11'in Gezgin kısayolu hedefsizdir, kimliği (`Microsoft.Windows.Explorer`)
  dosya içinde UTF-16 aranır; Store uygulamaları Favorites ikilisindeki AUMID'den; sıra Favorites içindeki konumdan.
  Etkileşimli kabuk yoksa (CI) uygulanamaz: hata.
- Motor: tweak alanı `Refresh` (`Desktop`, `Settings`, `StartMenu`, `Shell`; `IDesktopProvider`). Uygulama / geri alma
  sonunda türü başına bir kez, bu sırayla; oturum kaydı `Refresh`'i taşır (Undo da yeniler). Hata rapora `refresh.<tür>`.
- `-ExportLayout`: `Export-FaiLayout` (salt okunur) + `Save-FaiProfileLayout` / `Invoke-FaiExportLayout -ProfilePath`
  (`src/Core/Layout.ps1`; CLI bağlaması Faz 8). Profil `layout`: `taskbar {alignment, autoHide, pins[appId|link|aumid]}`,
  `desktopIcons {thisPC, recycleBin, userFiles, network, controlPanel}`, `desktop {flags, iconSize, iconLayouts}`,
  `start {start2}`. Sabitlemeler taşınabilir: Gezgin → appId, masaüstü uygulaması → Başlat menüsündeki aynı hedefli
  kısayol (`%ProgramData%\...`), Store → aumid. `iconLayouts` (masaüstü öğe adları) ve `start2` (start2.bin) ham: Export
  uyarır, açık repoya koymadan gözden geçirilmeli. Motor `layout`'u tweak'lerden sonra `layout.profile` tweak'i olarak
  uygular; -Undo geri alır. Sağ alt simge konumu: elle yerleştir → -ExportLayout → profil.
- Kabul: birim testi (Gezgin taklidi `Enable-FakeShellLayout`) Export → Undo → profil uygula düzeni birebir getiriyor;
  ikinci çalıştırma ZATEN UYGUN; Undo başa döner. Bu makinede salt okunur (5.1): Export → ortalı, otomatik gizli,
  Gezgin + Chrome (sıra doğru), Bu Bilgisayar + Geri Dönüşüm, FFlags 0x40200224; `ui.account-pictures-black` ZATEN UYGUN.
- Windows-Actions'a 6 adım (23): RegistryByte, SolidImage, AppSetting (reg save ile sentetik hive), kabuk sağlayıcısı,
  Faz 6 dry-run + Export, Faz 6 uygula → Undo (yalnız etkileşimli kabukta: Sandbox).
- Sandbox (5.1, etkileşimli kabuk) 23 adım 0 HATA: Faz 6 görünüm tweak'leri gerçek Gezgin'de uygulandı — sabitlemeler
  Gezgin + Edge → yalnız Gezgin (Chrome kurulu değil, atlandı; Start Layout yöntemi var olan kullanıcıda çalışıyor),
  otomatik gizleme açık, ikinci çalıştırma ZATEN UYGUN, -Undo düzeni (Gezgin + Edge) birebir geri getirdi. AppSetting
  sentetik hive'da Bool + Int32 döngüsü geçti.
- Açık (VM / gerçek donanım): referans görünümün görsel kontrolü (Faz 9), start2.bin geri yazımı, Not Defteri değer anlamları, PersonalizationCSP'nin Pro'da etkisi, IconLayouts geri yazımının
  konumları getirdiği.

### Faz 7 — Sistem, güç, grafik, oyun
**Prompt:**
> `system.restore-point`, `power.plan` (IsLaptop → AC/DC iki varyant), `system.timer-resolution`, `setup.mmagent-off`, `setup.background-apps-off` (istisnalı), `setup.store-optimize`, `setup.updates-staged` + `-UpdatesOn/-UpdatesOff`, `setup.edition-pro` (Caution), `graphics.nvidia-settings`, `graphics.amd-settings`, `graphics.p0-state` (Caution, dizüstü uyarısı), `gaming.per-game` (IFEO: CpuPriorityClass + affinity maskesi; SMT kapalı ve çekirdek 0 hariç maskelerini mantıksal işlemci sayısından hesapla), `refresh.reboot-to-bios`. Ultimate'teki ilgili dosyalar sadece referans.

**Kabul:** Dizüstü koşulunda güç planının pil varyantı uyku/hazırda beklemeyi açık bırakıyor; P0 her çalıştırmada soruluyor.

> Faz 2'de görüldü: hedef dizüstünde yalnız Ultimate'in içe aktardığı plan var (`99999999-9999-9999-9999-999999999999`, "Ultimate Performance"); Balanced / High performance silinmiş. `power.plan` var olmayan planı varsaymamalı (`powercfg /duplicatescheme` ile kendi planını kurup etkinleştirmeli; geri alma eski planı etkin yapar).

### Faz 8 — CLI, menü, paketleme, yayın
**Prompt:**
> `Cli.ps1` (2.4'teki parametreler) ve `Menu.ps1` (profil yoksa kategori → onay kutulu liste, risk renkleri, Türkçe) yaz. Yönetici değilse kendini yükseltsin. `Bundle.ps1` tüm kaynakları bağımlılık sırasıyla tek `install.ps1`'e birleştirsin; tweak/katalog/profil verileri ya gömülü olsun ya da aynı sürüm etiketinden `raw.githubusercontent` ile çekilsin (karar ver ve gerekçelendir). `release.yml`: etiketle sürüm, `install.ps1` + `.sha256` yayınla. `-ExportProfile` yaz.

**Kabul:** Temiz bir Windows CI runner'ında tek satır komut `-DryRun` ile uçtan uca çalışıyor; hash doğrulaması başarısız olursa çalıştırma duruyor.

### Faz 9 — Gerçek donanım doğrulaması
**Kontrol listesi (kullanıcı ile birlikte, hedef dizüstünde):**
1. `-Profile fedai -DryRun` raporu incelenir
2. Geri yükleme noktası + tam uygulama
3. Görsel kontrol: referans masaüstü, ses %15, açılış sesi yok, bildirim istisnaları çalışıyor
4. WhatsApp/Claude/Telegram açılıyor; Edge yok, WebView2 var
5. `-Undo` → önceki duruma dönüş
6. Hyper-V VM'de temiz Win11 kurulumu → tek satır komut → uçtan uca

---

## 5. Açık sorular
- [x] GitHub: `MrFedai/FAI_WinOP` (public)
- [x] Güncellemeler: bekleyenlerin hepsi alınır, sonra durdurulur
- [x] Dil/bölge/klavye: kullanıcı ayarlar, araç dokunmaz
- [x] Ultimate referansı: Windows'taki mevcut klasör, WSL'den `/mnt/c/...` ile okunur
- [x] Sürüm: Windows 11 Pro → Sandbox + Hyper-V test ortamı

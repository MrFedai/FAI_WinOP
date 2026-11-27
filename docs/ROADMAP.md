# FAI_WinOP — Beyin Fırtınası, Mimari ve Roadmap

> Bu dosya kendi başına okunacak şekilde yazıldı. Geliştirme ortamındaki ajan (Ubuntu) bu konuşmayı görmeyecek; her şey burada.
> İlham kaynağı: [FR33THY/Ultimate](https://github.com/FR33THYFR33THY/Ultimate) (MIT). **Kod kopyalanmayacak**; ayarların mantığı incelenip yeniden tasarlanacak. README'de ilham kaynağına atıf verilecek.

---

## 0. Özet

**FAI_WinOP**: Windows 11 için kişisel, nesne tabanlı, profil odaklı optimizer.
Format sonrası tek komut → kullanıcının profili (ayarlar + uygulamalar + masaüstü/görev çubuğu düzeni) uygulanır.
Açık GitHub reposunda barınır; başka kullanıcılar kendi profillerini yazıp aynı komutla yükler.

```powershell
& ([scriptblock]::Create((irm https://github.com/MrFedai/FAI_WinOP/releases/latest/download/get.ps1))) -Profile fedai
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
- Windows testleri için `tools/Sync-ToWindows.sh`: bundle + test dosyalarını `/mnt/c/Users/<kullanıcı>/FAI_WinOP_test/` altına kopyalar. `powershell.exe` (5.1) ve Windows Sandbox (`MappedFolders` UNC yolu desteklemez) bu Windows kopyasını kullanır. WSL'den doğrudan `powershell.exe -ExecutionPolicy Bypass -File C:\Users\<kullanıcı>\FAI_WinOP_test\...` çağrılabilir.
- `.gitattributes`: `*.ps1 *.psd1 *.psm1 *.cs text eol=crlf`, `*.json *.md text eol=lf` (WSL ↔ Windows satır sonu karmaşasını önler).
- Referans: Ultimate klasörü `%USERPROFILE%\Desktop\Ultimate` (WSL: `/mnt/c/Users/<kullanıcı>/Desktop/Ultimate`) — sadece okunur, repoya girmez.
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
install.ps1 [-Profile <ad|yol|url>] [-DryRun] [-Unattended] [-Undo [-Session <oturum>] [-SkipFailed]]
            [-Only <id,...>] [-Skip <id,...>] [-UpdatesOn] [-UpdatesOff]
            [-ExportProfile <ad|yol>] [-ExportLayout] [-Version <vX.Y.Z>] [-List]
```
- `-Undo [<oturum>]` PowerShell'de hem anahtar hem isteğe bağlı değer olamaz → `-Undo` + `-Session <oturum>` (Faz 8).
- `-Undo -SkipFailed`: geri alınamayan kayıtlar atlanır, oturum kapanır (v0.1.1); verilmezse yeniden `-Undo` yalnız kalanları dener.
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
    Engine.ps1   Cli.ps1  Menu.ps1  Entry.ps1 (install.ps1 param bloğu + giriş)
    Bootstrap/   get.ps1 (önyükleyici: indir → SHA-256 → çalıştır; ASCII, BOM'suz)
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
- ~~`setup.mmagent-off`~~ — katalogda kalır, profilden çıktı (Faz 9: açılış ön getirmesini kapatıyor, açılış uzuyor; Hyper-V'de prefetch değişikliği reddediliyor)
- ~~`setup.edition-pro`~~ — makine artık Pro; katalogda isteğe bağlı `Caution` tweak olarak kalır (koşul `Edition=Core`), `fedai`'de yok
- `setup.background-apps-off` — istisna: **WhatsApp, Telegram**
- `setup.store-optimize` — Store otomatik güncelleme/video/kişiselleştirme kapalı; Store uygulamaları `winget upgrade` ile güncellenir
- `setup.updates-staged` — önce **bekleyen tüm güncellemeler** kurulur (gerekirse yeniden başlatma sonrası devam), sonra **365 gün duraklatılır**; `-UpdatesOn/-UpdatesOff`
- Dil, bölge, klavye ve saat dilimine **dokunulmaz** — kullanıcı kendisi ayarlar

**Fare** (kullanıcının mevcut ayarları, ekran görüntüsü + kayıt defterinden okundu)
- `input.mouse` (katalogda yok, sonra) — parametreler: birincil düğme **Sol**, işaretçi hızı **7** (`MouseSensitivity`), **İşaretçi hassasiyetini artır: AÇIK** (`MouseSpeed=1`, `Threshold1=6`, `Threshold2=10`), tekerlek **satır satır, 5 satır** (`WheelScrollLines`), **etkin olmayan pencereleri kaydır: AÇIK** (`MouseWheelRouting=2`), kaydırma yönü normal
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
- `ui.taskbar` — 2 sabitleme, düğmeler kapalı, tepsi taşma menüsünde (hiza / otomatik gizle / masaüstü simgeleri: profil `layout`, 0100)
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
- v0.1.3 (4.3, karar 0100): görsel düzenin tek kaynağı profil `layout`; `ui.desktop-icons` katalogdan kalktı, `ui.taskbar`'dan hiza / otomatik gizle ve `ShowCopilotButton` çıktı (Copilot düğmesi `ui.copilot-off`'ta).
- 8 tweak `tweaks/ui/`: `theme-black` (koyu + saydamlık kapalı + vurgu #191919, paletin açık tonları gri: Ayarlar
  düğmeleri okunur; düz siyah masaüstü: `WallPaper=''`, `Colors\Background='0 0 0'`, `BackgroundType=1`), `taskbar`,
  `desktop-icons`, `lockscreen-black` (üretilen `C:\ProgramData\FAI_WinOP\Black.png` + PersonalizationCSP; yol C: varsayılır,
  ilke değeri ortam değişkeni açmaz), `account-pictures-black` (varsayılan resimler boyutu korunarak siyah), `widgets-off`
  (yalnız ilke: `TaskbarDa` UCPD korumalı), `copilot-off`, `notepad-settings` (settings.dat; değer adları Ultimate'ten,
  anlamları VM'de doğrulanacak). Sohbet düğmesi `TaskbarMn` yerine ilke `ChatIcon=3`.
- Yeni eylemler: `RegistryByte` (ikili değerin tek baytı + maske: StuckRects3 8. bayt 0. bit = otomatik gizle),
  `TaskbarPins`, `SolidImage` (tek renk görüntü, `IImageProvider` System.Drawing), `AppSetting` (paketli uygulama
  settings.dat hive'ı: `RegLoadAppKey` (Faz 8'e kadar `reg load`) + ham tür 0x5F5E10B bool / 0x5F5E104 int32 + 8 bayt FILETIME; `IAppSettingsProvider`),
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

**Faz 7 notları (uygulama kararları):**
- Tweak alanları: `First` (apps'ten de önce: `system.restore-point`), `AlwaysConfirm` (profil autoConfirm işlemez,
  -Unattended'da atlanır, bekleyen eylem varsa her çalıştırmada sorulur: `graphics.p0-state`), `Tool` (profille
  çalışmaz; `-AllowTools`, Faz 8 menü / -Only: `refresh.reboot-to-bios`). Eylem düzeyi koşul `When` (ör. hazırda
  bekletme yalnız `IsLaptop`); oturum kaydına girmez.
- Yeni arayüzler: `ISystemControlProvider` (geri yükleme noktası, firmware'e yeniden başlatma), `IMemoryAgentProvider`,
  `IUpdateProvider` (WUA COM, ilerleme basar); `IPowerProvider.CreateScheme / DeleteScheme / Get|SetHibernate`,
  `ISystemInfoProvider.GetLogicalProcessorCount / GetCoreCount`, `ITaskProvider.RegisterWatcherTask` (süresiz görev),
  `ExecutionContext.ResumeCommand` (Faz 8 CLI doldurur). Yeni eylemler: `RestorePoint`, `Reboot`, `OpenSettings`,
  `PowerScheme`, `Hibernate`, `MMAgent`, `WindowsUpdate`, `UpdatePause`, `GameAffinity`; `RegistryEach` + `Include` /
  `SubKey` / `Match` (GPU sınıf anahtarı: yalnız eşleşen bağdaştırıcı); `AppSetting` + `Key` (LocalState alt anahtarı).
- `power.plan`: kendi plan `46414900-5769-4e4f-9000-000000000001` ("FAI_WinOP"), Balanced'tan kopya (silinmişse uyarı +
  etkin plandan). Prizde yüksek performans (işlemci 100, park kapalı, USB / PCIe tasarrufu kapalı, uyku yok), pilde
  Balanced + uyku 15 dk / hazırda bekletme 180 dk (params), hazırda bekletme açık (`When='IsLaptop'`). Undo eski etkin
  plana döner, kendi planı siler.
- `setup.background-apps-off`: ilke `LetAppsRunInBackground=2` + `_ForceAllowTheseApps` (PFN listesi, varsayılan
  WhatsApp). `GlobalUserDisabled` istisnaları da kapattığı için kullanılmadı; Win32 uygulamaları (winget Telegram)
  etkilenmez. `setup.store-optimize`: `AutoDownload=2` + Store settings.dat (VideoAutoplay, EnableAppInstallNotifications,
  PersistentSettings\PersonalizationEnabled). `setup.mmagent-off` (≥16 GB): bellek sıkıştırma, uygulama prefetch / ön
  yükleme kapalı + `EnablePrefetcher=0`.
- `setup.edition-pro`: anahtar içermez; Ayarlar → Etkinleştirme açılır, kullanıcı kendi anahtarını girer.
- `graphics.nvidia-settings` yalnız kayıt defteri (NvTray, EnableGR535 — anahtar varsa). Panel ayarları (düşük gecikme,
  güç yönetimi, V-Sync) DRS veritabanında: imzasız Profile Inspector kullanılmaz → NVAPI ile sonra (gerçek donanım).
  `graphics.amd-settings`: CN / DVR + bağdaştırıcı `KMD_DeLagEnabled`, UMD (VSync / TFQ / Tessellation), power_v1 abmlevel.
- `setup.updates-staged`: `WindowsUpdate` (bekleyenlerin hepsi) → `UpdatePause` (`pauseDays` 365; Ayarlar'ın 6 UX
  değeri). Yeniden başlatma gerekirse hata ile durur, duraklatma o çalıştırmada uygulanmaz; `ResumeCommand` doluysa HKLM
  RunOnce. `-UpdatesOn/-UpdatesOff` → `Invoke-FaiUpdatesSwitch` (`Engine.RunTweaks`, -Undo'lanır; CLI bağlaması Faz 8).
- `gaming.per-game`: profil `games[] {exe, priority, smtOff, excludeCore0}` → motor tweak'lerden sonra tek tweak üretir.
  Öncelik IFEO `PerfOptions\CpuPriorityClass`. IFEO'da benzeşim yok → `GameAffinity`: maskeler gömülü betik
  (`%ProgramData%\FAI_WinOP`) + SYSTEM izleyici görevi `\FAI_WinOP\GameAffinity` (`Win32_ProcessStartTrace`).
  `Get-FaiAffinityMask`: SMT'li çekirdekler önce ve yan yana varsayılır (hibrit Intel P+E dahil), >64 LP hata.
- Kabul (birim): dizüstünde pil varyantı uyku / hazırda beklemeyi açık bırakıyor; P0 autoConfirm'e rağmen soruluyor,
  -Unattended'da atlanıyor. 338 birim testi, lint temiz; 5.1'de bundle + smoke geçti. Windows-Actions 28 adım (Faz 7:
  güç planı döngüsü, MMAgent / geri yükleme okuma, UpdatePause döngüsü, WU bekleyen listesi yalnız CI, Faz 7 dry-run).
- CI windows işi (5.1) 28 adım 0 HATA 2 ATLA: PowerScheme Balanced'tan kopyala → etkin → geri al, UpdatePause döngüsü,
  WU araması 6 sn (0 bekleyen), Faz 7 dry-run gerçek sağlayıcılarla 8 planlanan / 5 koşul dışı (runner 4 LP / 2 çekirdek).
- Açık (VM / gerçek donanım): silinmiş Balanced'ın kopyalanabildiği, powercfg takma adları (CPMINCORES, SYSCOOLPOL,
  ASPM) `/qh` ile, WU kurulum + yeniden başlatma algısı, 365 günlük duraklatmanın Ayarlar'daki görünümü,
  GameAffinity izleyicisi, AMD / NVIDIA değerlerinin etkisi, bellek sıkıştırmanın yeniden başlatma sonrası kapalı kalması.

### Faz 8 — CLI, menü, paketleme, yayın
**Prompt:**
> `Cli.ps1` (2.4'teki parametreler) ve `Menu.ps1` (profil yoksa kategori → onay kutulu liste, risk renkleri, Türkçe) yaz. Yönetici değilse kendini yükseltsin. `Bundle.ps1` tüm kaynakları bağımlılık sırasıyla tek `install.ps1`'e birleştirsin; tweak/katalog/profil verileri ya gömülü olsun ya da aynı sürüm etiketinden `raw.githubusercontent` ile çekilsin (karar ver ve gerekçelendir). `release.yml`: etiketle sürüm, `install.ps1` + `.sha256` yayınla. `-ExportProfile` yaz.

**Kabul:** Temiz bir Windows CI runner'ında tek satır komut `-DryRun` ile uçtan uca çalışıyor; hash doğrulaması başarısız olursa çalıştırma duruyor.

**Faz 8 notları (uygulama kararları):**
- Veri **gömülü** (`build/Bundle.ps1` → `Get-FaiEmbeddedData`; okuma `src/Core/Data.ps1`). Gerekçe: tek dosya = tek
  SHA-256 (veri de doğrulanır; ayrı raw indirmeleri ayrı ayrı doğrulanmak zorunda kalırdı), kod + veri aynı etiketten
  (kayma yok), çevrimdışı çalışır (format sonrası sürücüsüz Wi-Fi), daha az ağ isteği. Bedeli ~100 KB. `.psd1` metni
  yürütülmeden okunur (`HashtableAst.SafeGetValue`). Satır başında `'@` olan dosya (edge-remove) base64. Kullanıcı
  profili yine yol ya da https URL ile verilebilir (düz http reddedilir).
- Tek satır: `& ([scriptblock]::Create((irm .../releases/latest/download/get.ps1))) -Profile fedai -DryRun`.
  `get.ps1` install.ps1 + .sha256 indirir, doğrular (tutmazsa siler, hata, çalıştırmaz); yönetici süreci (değilse UAC ile
  yeni pencerede, `-NoExit -EncodedCommand`) dosyayı `%ProgramData%\FAI_WinOP_get_<guid>` (yalnız SYSTEM + Administrators)
  klasörüne kopyalar, orada yeniden doğrular ve yalnız o kopyayı çalıştırır (v0.1.0, 1.4). `irm install.ps1 | iex`
  doğrulanamaz; README yalnız get.ps1'i önerir. get.ps1 saf ASCII ve BOM'suz (5.1 `irm` charset'siz yanıtı ISO-8859-1
  çözer); lint BOM kuralı "BOM yok ve ASCII dışı bayt var" olarak daraldı, birim testi get.ps1'i denetler.
- `install.ps1` başında param bloğu (`src/Entry.ps1`; Bundle AST ile böler: param başa, giriş sona). Nokta-kaynakta
  (testler) çalışmaz; dosyadan çalıştıysa `exit <kod>`, `iex`'te exit yok. Param değişkeni `FaiProfile`
  (`[Alias('Profile')]`; `$PROFILE` ezilmesin). Nokta-kaynak eden betik aynı adlı değişkenlerini korumalı
  (Apps-Install `-Only / -Undo`).
- Yükseltme: `-List / -ExportProfile / -ExportLayout / -Version` yönetici istemez; diğerleri dosyadan çalıştıysa UAC ile
  yeniden başlar (aynı parametreler), `iex`'te get.ps1 önerilir. Çıkış kodları 0 / 1 HATA / 2 kullanım / 3 yükseltme.
- `-Only`: profille süzgeç, profilsiz geçici profil ('secim'), araçlara (Tool) izin. Kimlikler tweak Id, `app.<id>`,
  `gaming.per-game`, `layout.profile`; `-Skip` aynı kimliklerle (yalnız -Profile ile). `-Version vX.Y.Z`: o etiketin
  install.ps1 + .sha256'sı doğrulanıp onunla çalışır. `ResumeCommand`: dosyadan, dry-run olmayan profil çalıştırmasında
  betik `%ProgramData%\FAI_WinOP\install.ps1`'e kopyalanır, aynı parametrelerle (yerel profil yolu mutlak).
  Günlük `%ProgramData%\FAI_WinOP\logs\<zaman>.log`.
- `-ExportProfile <ad|yol>`: motor dry-run + Unattended ile bütün (araç dışı) tweak'ler + katalog uygulamaları → ZATEN
  UYGUN olanlar profile girer (varsayılan parametrelerle), düzen `Export-FaiLayout`; doğrulanıp `Belgeler\FAI_WinOP\<ad>.json`.
  `-ExportLayout`: `-Profile <yol.json>` ya da `Belgeler\FAI_WinOP\layout.json`.
- Menü (`src/Menu.ps1`): 1 profil (gömülü / yol / URL) · 2 kategori → onay kutulu liste (risk renkli; `1 3-5`, h / y) →
  c çalıştır · 3 son oturumu geri al · 4 Windows Update · 5 araçlar. Her çalıştırmada Ö önizle / U uygula / G geri.
  Girdi `IPromptProvider.ReadLine` (yeni; Fake kuyruğu ile test).
- `profiles/fedai.json`: 3.2'deki tweak'ler (setup.updates-staged en sonda: yeniden başlatma isterse diğerleri uygulanmış
  olur), 12 uygulama (Telegram / WhatsApp keepAutostart), autoConfirm boş. `input.mouse` katalogda yok (sonra) → profilde yok.
- `release.yml`: `v*` etiketi → lint + birim → `Bundle.ps1 -Version <etiket>` → install.ps1, install.ps1.sha256, get.ps1
  sürüme. CI windows işi `tests/Integration/OneLiner.ps1`: yerel HTTP (python) → tek satır `-Profile fedai -DryRun` 0
  dönmeli; install.ps1'i kurcalanmış kopyada çıkış ≠ 0 ve eklenen satır çalışmamış olmalı.
- Gerçek makinede ilk `-Profile fedai -DryRun` (yönetici): 31 önizleme · 8 zaten uygun · 3 HATA. `reg load` gerçek
  uygulama `settings.dat`'ında "The filename or extension is too long" (store-optimize, notepad-settings) →
  `WindowsAppSettingsProvider` `RegLoadAppKey`'e geçti (yönetici gerekmez; bu makinede yükseltmesiz okuma doğrulandı,
  yazma döngüsü CI'da). `bloat.persistence`: "Access is denied" (betik / görev yok → büyük olasılıkla
  `Get-AppxProvisionedPackage -Online`); teşhis için motor hatası artık "eylem N (Tür) denetlenemedi: ..." der.
  Düzeltme sonrası ikinci çalıştırma (yönetici): 33 önizleme · 9 zaten uygun · 0 HATA; persistence tek başına da
  hatasız → "Access is denied" tekrarlanmadı (geçici; o anda bekleyen Defender güncellemesi vardı).
- Kabul ✓ CI windows işi (5.1, temiz runner): tek satır get.ps1 → SHA-256 doğrulandı → `-Profile fedai -DryRun` çıkış 0
  (37 önizleme · 2 zaten uygun · 3 atlandı, 67 sn); kurcalanmış install.ps1 → "BASARISIZ", çıkış 1, eklenen satır
  çalışmadı. Windows eylem entegrasyonu 28 adım 0 HATA (AppSetting yazma döngüsü RegLoadAppKey ile geçti).
- Birim: 374 (Cli.Tests 34: gömülü veri, CLI, menü, dışa aktarma, SHA-256), lint temiz; 5.1'de `-List` ve bundle
  yükleme geçti.

### Faz 9 — Gerçek donanım doğrulaması
**Kontrol listesi (kullanıcı ile birlikte, hedef dizüstünde):**
1. `-Profile fedai -DryRun` raporu incelenir
2. Geri yükleme noktası + tam uygulama
3. Görsel kontrol: referans masaüstü, ses %15, açılış sesi yok, bildirim istisnaları çalışıyor
4. WhatsApp/Claude/Telegram açılıyor; Edge yok, WebView2 var
5. `-Undo` → önceki duruma dönüş
6. Hyper-V VM'de temiz Win11 kurulumu → tek satır komut → uçtan uca

**Faz 9 notları:**
- Hedef dizüstü (RTX + iGPU, Modern Standby) (pil var → `power.plan` dizüstü varyantı), Windows 11 Pro, Hyper-V çalışıyor.
- Rapor artık günlükte madde madde (`Logger.Block` ← `Write-FaiReport -Logger`; CLI ve menü):
  `%ProgramData%\FAI_WinOP\logs\<zaman>.log` = özet + her tweak'in eylem satırları. Adım 1 ve 5 bu dosyadan incelenir.
- Adım 1–5 yerel kopyadan (`tools/Sync-ToWindows.sh`; yönetici PowerShell):
  `& "$env:USERPROFILE\FAI_WinOP_test\repo\dist\install.ps1" -Profile fedai -DryRun`.
  Uygulama sonrası aynı dry-run'da her şey ZATEN UYGUN olmalı (araç / her seferinde onaylı olanlar hariç).
- Adım 6 ön koşulu: ilk sürüm etiketi (`releases/latest/download/get.ps1`; kullanıcı) + Win11 ISO.
- Adım 1 ✓ dry-run 33 önizleme · 9 zaten uygun · 0 HATA. Makine önceden Ultimate ile ayarlanmış (yalnız `9999…`
  "Ultimate Performance" planı, bildirimler kapalı, siyah kilit ekranı) → `-Undo` oraya döner. Atlandı:
  `graphics.p0-state` (Optimus dizüstü: dGPU hep P0), `app.chrome` (winget kararlı Chrome'u Beta sanıyor).
- Adım 2 uygulama: 28 uygulandı · 9 zaten uygun · 3 HATA, ~16 dk (6 uygulama kurulumu dahil):
  - `setup.mmagent-off`: `Disable-MMAgent -MemoryCompression` "The request is not supported" verdi ama ayar kaydoldu
    (Hyper-V açık). → MMAgent eylemi hatadan sonra durumu yeniden okur; tutuyorsa uyarı + başarı.
  - `ui.widgets-off`: `HKLM\...\Policies\Microsoft\Dsh` yönetici olarak da yazılamıyor (UCPD sürücüsü; ACL değil).
    Bu makinede WebExperience paketi yok (pencere öğeleri zaten yok). Temiz kurulumda paket var → çözüm VM'de (adım 6).
  - `power.plan`: Modern Standby (S0) + silinmiş Balanced → `/duplicatescheme` ne Balanced ne etkin plan için çalışıyor.
    Temiz kurulumda Balanced var. Hata mesajı artık `powercfg -restoredefaultschemes` önerir.
- `setup.mmagent-off` profilden çıktı (kullanıcı: açılış uzun bekliyor); bellek sıkıştırma elle geri açıldı. Kalan uygulama
  sonucu: `power.plan` `restoredefaultschemes` sonrası uygulandı (FAI_WinOP etkin, hazırda bekletme açık).
- Tema kararı (kullanıcı, adım 3): vurgu rengi Otomatik, Başlat / görev çubuğu ve başlıklarda vurgu kapalı, saydamlık
  kapalı → `ui.theme-black` siyah vurgu paleti ve DWM renklendirmesi yerine `AutoColorization=1`, iki `ColorPrevalence=0`.
- Uygulama sonrası dry-run (27.11): 33 zaten uygun · 7 önizleme. Önizlemeler:
  - `bloat.edge-remove`: `HKLM\SOFTWARE\Classes\microsoft-edge` varsayılan değeri + `URL Protocol` yok → yönlendirme çalışmaz.
    Neden: motor bekleyen eylemleri en başta seçiyordu; iki değer o an (Edge'in kendi kaydı) uygundu, sonra Edge kaldırıcısı
    sınıfı sildi. → Motor uygun sayılan eylemi, kendinden önce bir eylem uygulandıysa, uygulamadan hemen önce yeniden denetler.
  - `layout.profile`: düzen profile adım 2'den sonra girdi (beklenen). `ui.widgets-off`: UCPD (bilinen, adım 6).
  - `ui.notifications`: sonradan kaydolan uygulamalar (Claude, Ekran Alıntısı) varsayılan açık; joker yalnız var olan alt anahtarlara.
  - `app.discord`: Discord güncelleyicisi Başlat klasörünü (`Discord Inc`) geri getiriyor. `sound.volume`: şu an %0 + sessiz.
- Widgets kararı (kullanıcı, 27.11): `ui.widgets-off` Dsh ilkesi yerine `MicrosoftWindows.Client.WebExperience` paketini
  kullanıcıdan kaldırır (Scope User, geri alınabilir). Korunan `MicrosoftWindows.Client.*` kalıbı daraltılmadı; birebir ad
  istisnası `Get-FaiBloatUnprotected`. UCPD'yi kapatmak (varsayılan tarayıcı koruması da gider) reddedildi. VM'de doğrulanacak.
  `Windows Feeds\EnableFeeds` ilkesi de UCPD korumasında (yeniden uygulamada aynı hata) ve Windows 11'de etkisiz → eylem çıktı.
- Adım 3–4 ✓ (kullanıcı: tamam). Adım 5 (kullanıcı kararı: yalnız son oturum; tam geri alma uygulamaları kaldırıp Edge'i
  kurar → VM'de): `-Undo` 27.11 oturumunu seçti, 11 eylem GERİ ALINDI · 0 hata. Doğrulandı: Edge sınıf değerleri silindi,
  `Discord Inc` geri geldi, Claude / Ekran Alıntısı bildirim değerleri kalktı. Kusur: `-Undo -DryRun` dönülecek eski durumu
  değil eylemin hedefini gösteriyor (ses "%15 [şu an %15]") → önizleme snapshot'tan üretilmeli.

---

## 5. Açık sorular
- [x] GitHub: `MrFedai/FAI_WinOP` (public)
- [x] Güncellemeler: bekleyenlerin hepsi alınır, sonra durdurulur
- [x] Dil/bölge/klavye: kullanıcı ayarlar, araç dokunmaz
- [x] Ultimate referansı: Windows'taki mevcut klasör, WSL'den `/mnt/c/...` ile okunur
- [x] Sürüm: Windows 11 Pro → Sandbox + Hyper-V test ortamı

---

## 6. İnceleme düzeltmeleri — sürüm planı (27.11.2026)

Kaynak: kod incelemesi (lint temiz, 379 birim testi yeşilken bulunanlar). Sıra = önem. Her madde ayrı commit, görev dalı
`gorev/inceleme-duzeltmeleri` (`dev`'den). Bir sürümün maddeleri bitmeden sonrakine geçilmez. Etiket ve `main` kullanıcıda.
"(olası)" = Windows davranışına dayanıyor, VM / CI'da doğrulanacak.

### v0.1.0 — ilk yayın öncesi: güvenlik ve yayın kapısı (ilk etiketi bekletir)
- [x] **1.1 Veri klasörü izinleri** · Efor: high — `%ProgramData%\FAI_WinOP` yalnız SYSTEM + Administrators (kalıtım kapalı),
  sağlayıcı arkasında. Yönetici olmayan sahibin dosyası (yedek oturumu, betik) güvenilmez sayılır; yeniden ayrıştırma noktası
  reddedilir. Yönetici gerektirmeyen yollar (`-ExportProfile`, `-ExportLayout`) ProgramData'ya dokunmaz. ✓ `932f3d3`
- [x] **1.2 Risk seviyeleri** · Efor: medium — `setup.updates-staged` (365 gün, güvenlik yamaları dahil), `setup.store-optimize`,
  `ui.notifications` `Safe` → `Caution`; güncelleme duraklatma her seferinde onay ister. Açıklamalara Insider uyarısı
  (`AllowTelemetry=0` uçuşları keser, uzun duraklatma yapının süresini doldurur; olası). ✓ `62ad792`
- [x] **1.3 Yayın kapısı** · Efor: medium — `release.yml` Windows 5.1 işini bekler ve yayınlanacak bundle'ı 5.1'de yükler;
  `ci.yml` Pester birim testlerini `powershell.exe` 5.1'de de koşar; action'lar commit SHA'sına sabitlenir. ✓ `3928516`
- [x] **1.4 Önyükleyici** · Efor: high — `get.ps1`: `FAI_WINOP_BASEURL` yalnız https / localhost; doğrulanan betik yükseltmeden
  sonra, yalnız yöneticinin yazabildiği yerde yeniden doğrulanıp çalışır (`%TEMP%`'te doğrula → yükselt aralığı kapanır).
  README: SHA-256 yalnız bozulmayı yakalar, kaynağı kanıtlamaz (imza / attestation "sonra bak"). ✓ `52346de`
- [x] **1.5 Belgeler** · Efor: low — ROADMAP'ten makine modeli + kullanıcı adı içeren yollar, eski tek satır komut (§0),
  olmayan `input.mouse`; README "Faz 8" ve "-Undo gerçek önceki duruma döner" iddiası (geri alınamayanlar yazılır). ✓ `bb44a73`

### v0.1.1 — geri alma sağlamlığı
- [x] **2.1 Atomik oturum kaydı** · Efor: medium — geçici dosya + yer değiştirme; `GetLatest` bozuk dosyayı uyarıp atlar. ✓ `86ae162`
- [x] **2.2 Kayıt başına "geri alındı"** · Efor: high — başarısız kayıt oturumu kilitlemez; yeniden denemede başarılılar atlanır,
  "hatalıyı atla, oturumu kapat" seçeneği. ✓ `86ae162`
- [x] **2.3 `-Undo -DryRun` önizlemesi** · Efor: medium — snapshot'tan (dönülecek durum), eylemin hedefinden değil. ✓ `f39c47a`
- [x] **2.4 Kayıt defteri türü** · Efor: medium — `REG_NONE` / bilinmeyen tür ham bayt olarak yedeklenir ve geri yüklenir. ✓ `e722a20`
- [x] **2.5 Kaldırıcı çıkış kodu** · Efor: low — 3010 (yeniden başlatma gerekli) başarı sayılır. ✓ `95fe493`
- [x] **2.6 Devam sonrası geri alma** · Efor: medium — yeniden başlatma sonrası devam aynı oturuma yazar (ya da kullanıcıya iki
  oturum olduğu söylenir); oturum JSON'u her eylemde iki kez baştan yazılmaz. ✓ `86ae162`

### v0.1.2 — çalışma zamanı sağlamlığı
- [x] **3.1 Yükseltilmiş kullanıcı denetimi** · Efor: high — yükseltilmiş kullanıcı ≠ oturum sahibi ise dur / uyar (HKCU,
  masaüstü, sabitlemeler yanlış profile gitmesin). ✓ `976ddbf`
- [x] **3.2 Yükseltmede yollar** · Efor: low — UAC ve `-Version` yeniden başlatmasında göreli yol mutlak yapılır (olası). ✓ `976ddbf`
- [x] **3.3 Dış süreç zaman aşımı** · Efor: medium — winget, Edge `setup.exe`, kaldırıcı; aşımda süreç ağacı sonlanır. ✓ `2b516bc`
- [x] **3.4 Bloat temizlik damgası** · Efor: low — yalnız hatasız bitişte yazılır (açılışta AppX hazır değilse yinelenir; olası). ✓ `f5adf28`
- [x] **3.5 CLI kenar durumları** · Efor: low — `-Version V1.2.3`; `-ExportLayout` + `-Only` / `-Skip` kullanım hatası; menü çıkış
  kodu; `-ExportProfile` denetlenemeyen tweak'i uyarır; devam kopyası başarısızsa RunOnce yazılmaz. ✓ `f5adf28`

### v0.1.3 — test gerçekliği ve temizlik
- [x] **4.1 Fake = gerçek** · Efor: medium — `DeleteEmptyKey` kovan altı anahtar, winget kimliği harf duyarlılığı, kısayol
  `IconLocation` biçimi. ✓ `c011bac`
- [x] **4.2 Küçük doğruluk** · Efor: low — `Script` Test sonucunda `"False"` / `"0"`; `TimerResolution.cs` `MarshalAs(U1)`;
  `IsLaptop` UPS'li masaüstü; `Bundle.ps1` `-Version` kaçışı. ✓ `cf2f432`
- [x] **4.3 Veri temizliği** · Efor: low — kullanılmayan profil alanı `exceptions`; iki tweak'te `ShowCopilotButton`; `layout` ile
  `ui.taskbar` / `ui.desktop-icons` çakışması tek kaynağa (karar 0100: `layout`). ✓ `7cd000a`
- [x] **4.4 Araçlar** · Efor: low — `Sync-ToWindows.sh` ilerleme + `sed` kaçışı. ✓ `cf2f432`

### Sonra bak
- Bundle imzası (Authenticode) ya da `actions/attest-build-provenance`; `get.ps1`'e gömülü sürüm özeti.
- `store-optimize` yerine zamanlanmış `winget upgrade`; `power.plan` prizde ısı / fan (dizüstü).
- `settings.dat` uygulama açıkken kopyalanamıyorsa açık hata (olası).
- v0.1.0 1.1: kilit ekranı `Black.png` veri kökünde (VM'de okunamazsa `shared\`'e); hardlink saldırısı (bağlantı sayısı denetimi);
  güvenilir sahipli alt öğelerdeki açık izin kuralları sıfırlanmıyor. VM'de doğrula (olası): yükseltilmiş yöneticinin yeni dosya
  sahibi Administrators; Gezgin düzeni `shared\`'ten okuyor; Set-Acl kalıtım yayılımı önceden konmuş junction'a girmiyor.
- v0.1.0 1.3 / 1.4: CI'da 5.1 Pester ve yönetici-yalnız get.ps1 akışı ilk koşuda görülecek.
- v0.1.1 2.1 / 2.2: `Load` oturum kimliği beyaz liste denetimi; tamamen geri alınmış oturuma `-Undo` mesajı; BackupStore
  doğrudan `System.IO` (sağlayıcı arkasına alınabilir). 2.4: REG_NONE / ham tür yedek + geri yükleme Sandbox'ta doğrulanacak (olası).
- v0.1.2 3.1: UAC'de başka yönetici hesabıyla gerçek deneme VM'de (explorer.exe sahibi tespiti; RunOnce açılışında kabuk yoksa uyarıp sürer).
  `-Version` ile eski sürüme `-AllowOtherUser` geçilirse eski sürümde parametre yok (bağlama hatası). `Resolve-FaiExportTarget`,
  `-ExportLayout` `[IO.Path]::GetFullPath` ile süreç klasörüne göre çözer, PowerShell konumuna göre değil.
- v0.1.2 3.3: zaman aşımı + `taskkill /T` yolu ve kaldırıcının artık gizli pencere / `UseShellExecute=false` ile açılması Sandbox'ta doğrulanacak (olası).
  3.4: `Get-AppxPackage -AllUsers` hatası damgayı engellemiyor (yalnız provisioned liste ve kaldırma hataları).
- v0.1.3 4.2: `IsLaptop` kasa türü öncelikli (masaüstü kasada UPS pili sayılmaz) gerçek donanımda; `NtSetTimerResolution` `U1` hizmette (olası).
  4.3: kaldırılan `ui.desktop-icons`'ı içeren eski profil o satırda `Failed` ("katalogda yok") verir; istenirse eskimiş kimlik için "layout'a taşındı" uyarısı.
  4.4: `Sync-ToWindows.sh` `set -e` + `pipefail` altında rsync hatasında açık "HATA" iletisinden önce çıkar (rsync'in kendi iletisi görünür).

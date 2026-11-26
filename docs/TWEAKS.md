# Tweak kataloğu

> Otomatik üretilir: `pwsh -NoProfile -File build/TweaksDoc.ps1` (kaynak: `tweaks/**/*.psd1`). Elle düzenlemeyin.

Risk: **Safe** doğrudan uygulanır · **⚠ Caution** onay ister · **⛔ Risk** "EVET" yazılmasını ister, `-Unattended` kipte uygulanmaz.
Değişiklikler varsayılan parametrelerle listelenir; profil parametreleri geçersiz kılabilir.

Profilden üretilen tweak'ler katalogda dosya olarak yok: `app.<id>` (profil `apps`, `apps/catalog.json`), `gaming.per-game` (profil `games`: IFEO `CpuPriorityClass` + işlemci benzeşimi için `\FAI_WinOP\GameAffinity` açılış görevi; maskeler makinenin işlemci sayısından), `layout.profile` (profil `layout`), `updates.on` / `updates.off` (`-UpdatesOn` / `-UpdatesOff`). Biçim: `profiles/_schema.json`.

| Id | Başlık | Risk | Koşul | Parametre |
| --- | --- | --- | --- | --- |
| [`bloat.edge-remove`](#bloatedge-remove) | Microsoft Edge'i kaldır (WebView2 kalır) | ⚠ Caution | — | — |
| [`bloat.persistence`](#bloatpersistence) | Kaldırılan uygulamaların geri gelmesini engelle | ⚠ Caution | — | — |
| [`bloat.remove`](#bloatremove) | Gereksiz Store uygulamalarını kaldır | ⚠ Caution | — | — |
| [`graphics.amd-settings`](#graphicsamd-settings) | AMD: Adrenalin sadeleştirme ve düşük gecikme | Safe | HasAmdGpu | — |
| [`graphics.nvidia-settings`](#graphicsnvidia-settings) | NVIDIA: tepsi simgesi ve eski keskinleştirme kapalı | Safe | HasNvidia | — |
| [`graphics.p0-state`](#graphicsp0-state) | NVIDIA: P0 güç durumunda sabit tut | ⚠ Caution | HasNvidia | — |
| [`power.plan`](#powerplan) | Güç planı: prizde yüksek performans, pilde dengeli | Safe | — | `hibernateOnBatterySec`, `sleepOnBatterySec` |
| [`privacy.app-permissions`](#privacyapp-permissions) | Uygulama izinlerini kapat (kamera ve mikrofon açık) | Safe | — | — |
| [`privacy.search-ads`](#privacysearch-ads) | Arama ve Başlat reklamlarını kapat | Safe | — | — |
| [`privacy.telemetry`](#privacytelemetry) | Telemetriyi en aza indir | Safe | — | — |
| [`refresh.reboot-to-bios`](#refreshreboot-to-bios) | UEFI (BIOS) ayarlarına yeniden başlat | ⚠ Caution | — | `delay` |
| [`setup.background-apps-off`](#setupbackground-apps-off) | Arka plan uygulamalarını kapat (istisna listesi hariç) | Safe | — | `exceptions` |
| [`setup.default-browser`](#setupdefault-browser) | Varsayılan tarayıcı (Ayarlar üzerinden) | ⚠ Caution | — | `appName`, `progId`, `scope` |
| [`setup.edition-pro`](#setupedition-pro) | Windows Home → Pro yükseltmesi (Ayarlar üzerinden) | ⚠ Caution | Edition Core | — |
| [`setup.mmagent-off`](#setupmmagent-off) | Bellek sıkıştırma ve ön getirmeyi kapat | Safe | MinRamGB 16 | — |
| [`setup.store-optimize`](#setupstore-optimize) | Microsoft Store: otomatik güncelleme, video ve kişiselleştirme kapalı | Safe | — | — |
| [`setup.updates-staged`](#setupupdates-staged) | Windows Update: önce bekleyenleri kur, sonra duraklat | Safe | — | `pauseDays` |
| [`sound.startup-sound-off`](#soundstartup-sound-off) | Açılış sesini kapat | Safe | — | — |
| [`sound.volume`](#soundvolume) | Ses seviyesini ayarla | Safe | — | `level` |
| [`system.restore-point`](#systemrestore-point) | Sistem Geri Yükleme noktası | Safe | — | `description` |
| [`system.timer-resolution`](#systemtimer-resolution) | Zamanlayıcı çözünürlüğü 0,5 ms | Safe | — | `resolution` |
| [`ui.account-pictures-black`](#uiaccount-pictures-black) | Varsayılan hesap resimleri siyah | Safe | — | — |
| [`ui.copilot-off`](#uicopilot-off) | Copilot'u kapat | Safe | — | — |
| [`ui.desktop-icons`](#uidesktop-icons) | Masaüstü simgeleri: Bu Bilgisayar + Geri Dönüşüm Kutusu | Safe | — | — |
| [`ui.explorer`](#uiexplorer) | Dosya Gezgini düzeni | Safe | — | — |
| [`ui.lockscreen-black`](#uilockscreen-black) | Kilit ve oturum açma ekranı siyah | Safe | — | — |
| [`ui.notepad-settings`](#uinotepad-settings) | Not Defteri ayarları | Safe | — | `aiRewrite`, `openInNewWindow`, `restoreSession` |
| [`ui.notifications`](#uinotifications) | Bildirimleri kapat (istisna listesi hariç) | Safe | — | `exceptions` |
| [`ui.taskbar`](#uitaskbar) | Görev çubuğu: ortalı, otomatik gizlenir, yalnız Dosya Gezgini + Chrome | Safe | — | `autoHide` |
| [`ui.theme-black`](#uitheme-black) | Siyah tema (koyu, saydamlık kapalı, otomatik vurgu, düz siyah duvar kağıdı) | Safe | — | — |
| [`ui.visual-effects`](#uivisual-effects) | Görsel efektleri azalt (yazı yumuşatma açık) | Safe | — | — |
| [`ui.widgets-off`](#uiwidgets-off) | Pencere öğelerini (Widgets) kapat | Safe | — | — |

## bloat

### bloat.edge-remove

**Microsoft Edge'i kaldır (WebView2 kalır)** · Risk: ⚠ Caution

Edge'i (Chromium) kendi kurucusuyla sistem düzeyinde kaldırır. WebView2 Runtime'a ve EdgeUpdate'e dokunmaz: WhatsApp gibi WebView2 kullanan uygulamalar çalışmaya, WebView2 güncellenmeye devam eder. EdgeUpdate ilkesiyle Edge'in yeniden kurulması engellenir (Install{Edge}=0), WebView2'nin kurulması ve güncellenmesi açıkça izinli kalır. microsoft-edge: bağlantıları (Ayarlar, Widget'lar, arama sonuçları) küçük bir yönlendirme betiğiyle varsayılan tarayıcıda açılır; yalnız http / https adresi kabul edilir. Sınırlar: Windows Update ayrı bir Edge paketi gönderirse Edge geri gelebilir (EdgeUpdate ilkesi onu durdurmaz); msedge.exe'yi doğrudan çağıran sistem bileşenleri açılmaz; microsoft-edge: için kullanıcı seçimi (UserChoice) önceden Edge'e bağlıysa Windows bir kez "nasıl açılsın" sorabilir. Geri alma: önce ilke ve yönlendirme kalkar, sonra Edge winget ile yeniden kurulur.

Onay uyarısı: Edge kaldırılacak. Sık kullanılanları / parolaları önce Chrome'a aktarın. WebView2 kalır.

Değişiklikler (8):

- `Microsoft Edge kaldırılır (WebView2 Runtime ve güncellemesi kalır)`
- `Kayıt defteri: HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate\Install{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062} = 0 (DWord)`
- `Kayıt defteri: HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate\Install{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5} = 1 (DWord)`
- `Kayıt defteri: HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate\Update{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5} = 1 (DWord)`
- `Dosya: %ProgramData%\FAI_WinOP\EdgeRedirect.ps1 yazılır (570 karakter, UTF8BOM)`
- `Kayıt defteri: HKLM:\SOFTWARE\Classes\microsoft-edge\ = URL:microsoft-edge (String)`
- `Kayıt defteri: HKLM:\SOFTWARE\Classes\microsoft-edge\URL Protocol =  (String)`
- `Kayıt defteri: HKLM:\SOFTWARE\Classes\microsoft-edge\shell\open\command\ = "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "%ProgramData%\FAI_WinOP\EdgeRedirect.ps1" "%1" (ExpandString)`

### bloat.persistence

**Kaldırılan uygulamaların geri gelmesini engelle** · Risk: ⚠ Caution

bloat.remove listesindeki paketlerin provisioned kopyalarını kaldırır (yeni kullanıcılara ve güncellemeden sonra yeniden kurulmasınlar), Windows'un önerilen / sponsorlu uygulamaları kendiliğinden kurmasını kapatır (ContentDeliveryManager ve CloudContent ilkesi) ve açılışta Windows yapı numarası değiştiyse (büyük ya da aylık güncelleme) aynı listeyi bütün kullanıcılardan yeniden kaldıran bir zamanlanmış görev (\\FAI\_WinOP\\BloatCleanup, SYSTEM) kurar; görev %ProgramData%\\FAI\_WinOP\\BloatCleanup.log dosyasına yazar. Korunan liste ve profildeki uygulamalar görev betiğine de girmez. Provisioned kaldırmanın geri dönüşü yoktur: geri alma görevi ve betiği siler, ayarları döndürür; uygulamalar Store'dan yeniden kurulur. DisableWindowsConsumerFeatures ilkesi resmî olarak yalnız Enterprise / Education'da etkilidir; Pro'da asıl işi ContentDeliveryManager değerleri yapar.

Onay uyarısı: Provisioned paket kaldırma geri alınamaz (uygulama gerekirse Store'dan kurulur).

Değişiklikler (10):

- `Bloatware kalıcılığı: 44 paketin provisioned kopyası kaldırılır, açılış görevi \FAI_WinOP\BloatCleanup güncelleme sonrası yineler`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SilentInstalledAppsEnabled = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\PreInstalledAppsEnabled = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\PreInstalledAppsEverEnabled = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\OemPreInstalledAppsEnabled = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SubscribedContentEnabled = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\FeatureManagementEnabled = 0 (DWord)`
- `Kayıt defteri: HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent\DisableWindowsConsumerFeatures = 1 (DWord)`
- `Kayıt defteri: HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent\DisableConsumerAccountStateContent = 1 (DWord)`
- `Kayıt defteri: HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent\DisableCloudOptimizedContent = 1 (DWord)`

### bloat.remove

**Gereksiz Store uygulamalarını kaldır** · Risk: ⚠ Caution

Açık kara listedeki (joker yok, her paket adıyla) önceden kurulu Store uygulamalarını oturumdaki kullanıcıdan kaldırır. Çalışmadan önce kurulu olanlar tablo olarak gösterilir ve onay istenir. Korunan liste (src/Core/Bloat.ps1, Get-FaiBloatProtected) ve profildeki uygulamaların Appx adları (apps/catalog.json appxNames) hiçbir koşulda kaldırılmaz: Store, winget (App Installer), Ekran Alıntısı Aracı, WhatsApp, Claude, kabuk / sistem bileşenleri, kodekler, Fotoğraflar, Paint, Not Defteri, Terminal, Hesap Makinesi, Medya Oynatıcı, sürücü panelleri, Xbox kimliği. Geri alma: provisioned kopyası makinede durdukça paket yeniden kaydedilir; bloat.persistence provisioned kopyayı da kaldırdıysa geri alma uyarı verir, uygulama Store'dan yeniden kurulur.

Onay uyarısı: Yukarıdaki uygulamalar kaldırılacak (Store'dan yeniden kurulabilir).

Değişiklikler (44):

- `Appx: Clipchamp.Clipchamp kaldırılır (kullanıcı)`
- `Appx: Microsoft.549981C3F5F10 kaldırılır (kullanıcı)`
- `Appx: Microsoft.BingFinance kaldırılır (kullanıcı)`
- `Appx: Microsoft.BingNews kaldırılır (kullanıcı)`
- `Appx: Microsoft.BingSearch kaldırılır (kullanıcı)`
- `Appx: Microsoft.BingSports kaldırılır (kullanıcı)`
- `Appx: Microsoft.BingWeather kaldırılır (kullanıcı)`
- `Appx: Microsoft.Copilot kaldırılır (kullanıcı)`
- `Appx: Microsoft.GamingApp kaldırılır (kullanıcı)`
- `Appx: Microsoft.GetHelp kaldırılır (kullanıcı)`
- `Appx: Microsoft.Getstarted kaldırılır (kullanıcı)`
- `Appx: Microsoft.Messaging kaldırılır (kullanıcı)`
- `Appx: Microsoft.Microsoft3DViewer kaldırılır (kullanıcı)`
- `Appx: Microsoft.MicrosoftOfficeHub kaldırılır (kullanıcı)`
- `Appx: Microsoft.MicrosoftSolitaireCollection kaldırılır (kullanıcı)`
- `Appx: Microsoft.MicrosoftStickyNotes kaldırılır (kullanıcı)`
- `Appx: Microsoft.MixedReality.Portal kaldırılır (kullanıcı)`
- `Appx: Microsoft.MSPaint kaldırılır (kullanıcı)`
- `Appx: Microsoft.Office.OneNote kaldırılır (kullanıcı)`
- `Appx: Microsoft.OneConnect kaldırılır (kullanıcı)`
- `Appx: Microsoft.OutlookForWindows kaldırılır (kullanıcı)`
- `Appx: Microsoft.People kaldırılır (kullanıcı)`
- `Appx: Microsoft.PowerAutomateDesktop kaldırılır (kullanıcı)`
- `Appx: Microsoft.Print3D kaldırılır (kullanıcı)`
- `Appx: Microsoft.SkypeApp kaldırılır (kullanıcı)`
- `Appx: Microsoft.Todos kaldırılır (kullanıcı)`
- `Appx: Microsoft.Wallet kaldırılır (kullanıcı)`
- `Appx: Microsoft.Windows.DevHome kaldırılır (kullanıcı)`
- `Appx: Microsoft.WindowsAlarms kaldırılır (kullanıcı)`
- `Appx: Microsoft.WindowsFeedbackHub kaldırılır (kullanıcı)`
- `Appx: Microsoft.WindowsMaps kaldırılır (kullanıcı)`
- `Appx: Microsoft.WindowsSoundRecorder kaldırılır (kullanıcı)`
- `Appx: Microsoft.XboxApp kaldırılır (kullanıcı)`
- `Appx: Microsoft.YourPhone kaldırılır (kullanıcı)`
- `Appx: Microsoft.ZuneVideo kaldırılır (kullanıcı)`
- `Appx: MicrosoftCorporationII.QuickAssist kaldırılır (kullanıcı)`
- `Appx: MicrosoftTeams kaldırılır (kullanıcı)`
- `Appx: MSTeams kaldırılır (kullanıcı)`
- `Appx: 5A894077.McAfeeSecurity kaldırılır (kullanıcı)`
- `Appx: AmazonVideo.PrimeVideo kaldırılır (kullanıcı)`
- `Appx: BytedancePte.Ltd.TikTok kaldırılır (kullanıcı)`
- `Appx: Disney.37853FC22B2CE kaldırılır (kullanıcı)`
- `Appx: king.com.CandyCrushSaga kaldırılır (kullanıcı)`
- `Appx: king.com.CandyCrushSodaSaga kaldırılır (kullanıcı)`

## graphics

### graphics.amd-settings

**AMD: Adrenalin sadeleştirme ve düşük gecikme** · Risk: Safe

AMD Software (Adrenalin) ayarları, yalnız kayıt defteriyle: otomatik güncelleme, sistem tepsisi, web içeriği, animasyonlar, bildirim baloncukları ve oyun içi kaplama kapalı. Sağlayıcısı AMD olan ekran bağdaştırıcısı sınıf anahtarında Radeon Anti-Lag açık (KMD\_DeLagEnabled=1); UMD altında dikey eşitleme her zaman kapalı, doku filtreleme kalitesi performans, mozaikleme uygulama ayarını geçersiz kılar; power\_v1 altında Vari-Bright (abmlevel) kapalı. UMD değerleri UTF-16 metin rakamıdır (ör. 30 00 = "0"). Değerler Ultimate referansından alındı, gerçek AMD donanımında doğrulanmadı; sürücü güncellemesi bazılarını sıfırlayabilir.

Koşul: HasAmdGpu

Değişiklikler (12):

- `Kayıt defteri: HKCU:\Software\AMD\CN\AutoUpdate = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\AMD\CN\SystemTray = false (String)`
- `Kayıt defteri: HKCU:\Software\AMD\CN\AllowWebContent = false (String)`
- `Kayıt defteri: HKCU:\Software\AMD\CN\AnimationEffect = false (String)`
- `Kayıt defteri: HKCU:\Software\AMD\CN\CN_Hide_Toast_Notification = true (String)`
- `Kayıt defteri: HKCU:\Software\AMD\DVR\ShowRSOverlay = false (String)`
- `Kayıt defteri: HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\*\KMD_DeLagEnabled = 1 (DWord) — yalnız: [0-9][0-9][0-9][0-9] — ProviderName: Advanced Micro Devices* / AMD* / ATI*`
- `Kayıt defteri: HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\*\UMD\VSyncControl = 48,0 (Binary) — yalnız: [0-9][0-9][0-9][0-9] — ProviderName: Advanced Micro Devices* / AMD* / ATI*`
- `Kayıt defteri: HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\*\UMD\TFQ = 50,0 (Binary) — yalnız: [0-9][0-9][0-9][0-9] — ProviderName: Advanced Micro Devices* / AMD* / ATI*`
- `Kayıt defteri: HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\*\UMD\Tessellation = 49,0 (Binary) — yalnız: [0-9][0-9][0-9][0-9] — ProviderName: Advanced Micro Devices* / AMD* / ATI*`
- `Kayıt defteri: HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\*\UMD\Tessellation_OPTION = 50,0 (Binary) — yalnız: [0-9][0-9][0-9][0-9] — ProviderName: Advanced Micro Devices* / AMD* / ATI*`
- `Kayıt defteri: HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\*\power_v1\abmlevel = 0,0,0,0 (Binary) — yalnız: [0-9][0-9][0-9][0-9] — ProviderName: Advanced Micro Devices* / AMD* / ATI*`

### graphics.nvidia-settings

**NVIDIA: tepsi simgesi ve eski keskinleştirme kapalı** · Risk: Safe

Yalnız kayıt defteriyle yapılabilen NVIDIA ayarları: oturum açılışında NVIDIA tepsi simgesi başlamaz (NvTray\\StartOnLogin=0) ve eski görüntü keskinleştirme ölçekleyicisi kapanır (nvlddmkm FTS\\EnableGR535=0; yalnız sürücünün oluşturduğu FTS anahtarı varsa yazılır). Denetim Masası ayarları (düşük gecikme, güç yönetimi, dikey eşitleme, doku filtreleme…) NVIDIA DRS veritabanındadır; imzasız üçüncü parti araç (Profile Inspector) kullanılmadığından bu tweak'in kapsamı dışındadır (NVAPI ile sonra). Gerçek NVIDIA donanımında doğrulanmadı.

Koşul: HasNvidia

Değişiklikler (3):

- `Kayıt defteri: HKCU:\Software\NVIDIA Corporation\NvTray\StartOnLogin = 0 (DWord)`
- `Kayıt defteri: HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\*\EnableGR535 = 0 (DWord) — yalnız: FTS`
- `Kayıt defteri: HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\*\FTS\EnableGR535 = 0 (DWord) — yalnız: Parameters`

### graphics.p0-state

**NVIDIA: P0 güç durumunda sabit tut** · Risk: ⚠ Caution

NVIDIA ekran kartının dinamik P-state geçişlerini kapatır (DisableDynamicPstate=1): kart boştayken de en yüksek güç durumunda (P0) kalır, saat düşüşünden gelen gecikme sıçramaları azalır. Değer yalnız sağlayıcısı NVIDIA olan ekran bağdaştırıcısı sınıf anahtarına (0000, 0001…) yazılır; Intel / AMD anahtarlarına dokunulmaz. Dizüstünde pil süresi kısalır ve ısı artar; bu yüzden onay her çalıştırmada istenir (profil autoConfirm'i işlemez, -Unattended'da uygulanmaz). Sürücü yeniden yüklenince ya da yeniden başlatınca etkin olur. Not: etkisi gerçek donanımda ölçülmedi (Faz 9).

Onay uyarısı: Ekran kartı boştayken de tam güçte kalır: dizüstünde pil süresi kısalır ve ısı artar.

Çalışma: onay her çalıştırmada sorulur (autoConfirm işlemez, `-Unattended` kipte uygulanmaz)

Koşul: HasNvidia

Değişiklikler (1):

- `Kayıt defteri: HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\*\DisableDynamicPstate = 1 (DWord) — yalnız: [0-9][0-9][0-9][0-9] — ProviderName: NVIDIA*`

## power

### power.plan

**Güç planı: prizde yüksek performans, pilde dengeli** · Risk: Safe

Aracın kendi güç planını (FAI\_WinOP, sabit GUID) Balanced'dan kopyalayıp etkin yapar; var olan bir planın varlığı varsayılmaz (Balanced silinmişse etkin planın kopyası alınır). Prizde (AC): işlemci en düşük / en yüksek durum %100, çekirdek park etme kapalı (en az çekirdek %100), soğutma etkin, USB seçici askıya alma ve PCIe bağlantı durumu güç yönetimi kapalı, disk kapanmaz, kablosuz bağdaştırıcı en yüksek performans, uyku ve hazırda bekletme yok. Pilde (DC): Balanced varsayılanları kalır; uyku (sleepOnBatterySec, varsayılan 900 sn) ve hazırda bekletme (hibernateOnBatterySec, varsayılan 10800 sn) açıkça açık. Dizüstünde hazırda bekletme (powercfg /hibernate on) da açılır. Ekran ve parlaklığa dokunulmaz. Geri alma önceki etkin plana döner ve aracın planını siler.

Parametreler (varsayılan): `hibernateOnBatterySec` = `10800` · `sleepOnBatterySec` = `900`

Değişiklikler (12):

- `Güç planı 'FAI_WinOP' (46414900-5769-4e4f-9000-000000000001): yoksa 381b4222-f694-41f0-9685-ff5bb260df2e kopyası olarak kurulur, etkin olur`
- `Güç: 46414900-5769-4e4f-9000-000000000001 / SUB_PROCESSOR / PROCTHROTTLEMIN → prizde = 100`
- `Güç: 46414900-5769-4e4f-9000-000000000001 / SUB_PROCESSOR / PROCTHROTTLEMAX → prizde = 100`
- `Güç: 46414900-5769-4e4f-9000-000000000001 / SUB_PROCESSOR / CPMINCORES → prizde = 100`
- `Güç: 46414900-5769-4e4f-9000-000000000001 / SUB_PROCESSOR / SYSCOOLPOL → prizde = 1`
- `Güç: 46414900-5769-4e4f-9000-000000000001 / 2a737441-1930-4402-8d77-b2bebba308a3 / 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 → prizde = 0`
- `Güç: 46414900-5769-4e4f-9000-000000000001 / SUB_PCIEXPRESS / ASPM → prizde = 0`
- `Güç: 46414900-5769-4e4f-9000-000000000001 / SUB_DISK / DISKIDLE → prizde = 0`
- `Güç: 46414900-5769-4e4f-9000-000000000001 / 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 / 12bbebe6-58d6-4636-95bb-3217ef867c1a → prizde = 0`
- `Güç: 46414900-5769-4e4f-9000-000000000001 / SUB_SLEEP / STANDBYIDLE → prizde = 0, pilde = 900`
- `Güç: 46414900-5769-4e4f-9000-000000000001 / SUB_SLEEP / HIBERNATEIDLE → prizde = 0, pilde = 10800`
- `Hazırda bekletme açılır`

## privacy

### privacy.app-permissions

**Uygulama izinlerini kapat (kamera ve mikrofon açık)** · Risk: Safe

Ayarlar \> Gizlilik ve güvenlik \> Uygulama izinleri altındaki izinleri cihaz düzeyinde kapatır: konum, bildirimlere erişim, hesap bilgisi, kişiler, takvim, telefon aramaları, arama geçmişi, e-posta, görevler, mesajlaşma, radyolar, diğer cihazlarla eşitleme, uygulama tanılaması, belgeler, resimler, videolar, müzik, dosya sistemi, metin / görüntü üretimi (yapay zekâ modelleri) ve geçiş anahtarı listeleme. Kamera ve mikrofon açık tutulur (cihaz ve kullanıcı düzeyinde). İzinler çoğunlukla Store (paketli) uygulamaları etkiler; masaüstü uygulamalarında yalnız konum, kamera ve mikrofon izni geçerlidir. Konum kapalıyken otomatik saat dilimi ve Cihazımı bul çalışmaz. İzin anahtarı olmayan bir sürümde (ör. müzik, yapay zekâ modelleri) değer yine yazılır, etkisi olmaz.

Değişiklikler (24):

- `Kayıt defteri: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam\Value = Allow (String)`
- `Kayıt defteri: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone\Value = Allow (String)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\webcam\Value = Allow (String)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone\Value = Allow (String)`
- `Kayıt defteri: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location\Value = Deny (String)`
- `Kayıt defteri: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userNotificationListener\Value = Deny (String)`
- `Kayıt defteri: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userAccountInformation\Value = Deny (String)`
- `Kayıt defteri: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\contacts\Value = Deny (String)`
- `Kayıt defteri: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\appointments\Value = Deny (String)`
- `Kayıt defteri: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\phoneCall\Value = Deny (String)`
- `Kayıt defteri: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\phoneCallHistory\Value = Deny (String)`
- `Kayıt defteri: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\email\Value = Deny (String)`
- `Kayıt defteri: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userDataTasks\Value = Deny (String)`
- `Kayıt defteri: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\chat\Value = Deny (String)`
- `Kayıt defteri: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\radios\Value = Deny (String)`
- `Kayıt defteri: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\bluetoothSync\Value = Deny (String)`
- `Kayıt defteri: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\appDiagnostics\Value = Deny (String)`
- `Kayıt defteri: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\documentsLibrary\Value = Deny (String)`
- `Kayıt defteri: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\picturesLibrary\Value = Deny (String)`
- `Kayıt defteri: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\videosLibrary\Value = Deny (String)`
- `Kayıt defteri: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\broadFileSystemAccess\Value = Deny (String)`
- `Kayıt defteri: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\passkeysEnumeration\Value = Deny (String)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\musicLibrary\Value = Deny (String)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\systemAIModels\Value = Deny (String)`

### privacy.search-ads

**Arama ve Başlat reklamlarını kapat** · Risk: Safe

Başlat aramasında web (Bing) sonuçlarını ve önerilerini, arama vurgularını (dinamik arama kutusu), Microsoft / iş hesabı bulut içerik aramasını ve cihaz arama geçmişini kapatır. Başlat menüsündeki öneri ve hesap bildirimlerini, Ayarlar uygulamasındaki önerilen içeriği ve Dosya Gezgini'ndeki eşitleme sağlayıcısı (OneDrive / Microsoft 365) tanıtımlarını kapatır. Yerel dosya ve uygulama araması çalışmaya devam eder. Etkisi için Gezgin'in yeniden başlaması ya da oturumun kapatılıp açılması gerekebilir.

Değişiklikler (15):

- `Kayıt defteri: HKCU:\Software\Policies\Microsoft\Windows\Explorer\DisableSearchBoxSuggestions = 1 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\Search\BingSearchEnabled = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings\IsDynamicSearchBoxEnabled = 0 (DWord)`
- `Kayıt defteri: HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search\EnableDynamicContentInWSB = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings\IsMSACloudSearchEnabled = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings\IsAADCloudSearchEnabled = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings\IsDeviceSearchHistoryEnabled = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SubscribedContent-338388Enabled = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SystemPaneSuggestionsEnabled = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\Start_IrisRecommendations = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\Start_AccountNotifications = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SubscribedContent-338393Enabled = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SubscribedContent-353694Enabled = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SubscribedContent-353696Enabled = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ShowSyncProviderNotifications = 0 (DWord)`

### privacy.telemetry

**Telemetriyi en aza indir** · Risk: Safe

Tanılama verisini sürümün izin verdiği en düşük düzeye indirir: telemetri ilkesi, DiagTrack (Bağlı Kullanıcı Deneyimleri ve Telemetri) ve dmwappushservice servisleri, CEIP / uyumluluk / disk tanılama görevleri, reklam kimliği, kişiye özel deneyimler, geri bildirim istekleri, hata raporlama, etkinlik geçmişi, mürekkep ve yazma verisi gönderimi. Sürüm farkı: AllowTelemetry=0 (Güvenlik) yalnız Enterprise, Education ve Server sürümlerinde tam etkilidir; Home ve Pro bu değeri 1 (Gerekli tanılama verisi) olarak uygular, yani Home / Pro için ulaşılabilecek en düşük ilke düzeyi Gerekli'dir. Home / Pro'da gönderimi asıl durduran DiagTrack servisinin kapatılmasıdır. CEIPEnable ve AITEnable ilkeleri yeni sürümlerde etkisiz olabilir, eski bileşenler için yazılır. Windows Update, Store ve Defender çalışmaya devam eder; Ayarlar'da "Bazı ayarlar kuruluşunuz tarafından yönetiliyor" yazısı görünür. MDM / Intune ile yönetilen cihazda kullanmayın (dmwappushservice kayıt iletilerini taşır).

Değişiklikler (30):

- `Kayıt defteri: HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection\AllowTelemetry = 0 (DWord)`
- `Kayıt defteri: HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection\DoNotShowFeedbackNotifications = 1 (DWord)`
- `Servis: DiagTrack → başlangıç = Disabled, durum = Stopped`
- `Servis: dmwappushservice → başlangıç = Disabled, durum = Stopped`
- `Kayıt defteri: HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows\CEIPEnable = 0 (DWord)`
- `Kayıt defteri: HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat\AITEnable = 0 (DWord)`
- `Kayıt defteri: HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat\DisableInventory = 1 (DWord)`
- `Zamanlanmış görev: \Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser → devre dışı`
- `Zamanlanmış görev: \Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser Exp → devre dışı`
- `Zamanlanmış görev: \Microsoft\Windows\Application Experience\ProgramDataUpdater → devre dışı`
- `Zamanlanmış görev: \Microsoft\Windows\Application Experience\MareBackup → devre dışı`
- `Zamanlanmış görev: \Microsoft\Windows\Customer Experience Improvement Program\Consolidator → devre dışı`
- `Zamanlanmış görev: \Microsoft\Windows\Customer Experience Improvement Program\UsbCeip → devre dışı`
- `Zamanlanmış görev: \Microsoft\Windows\Autochk\Proxy → devre dışı`
- `Zamanlanmış görev: \Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector → devre dışı`
- `Zamanlanmış görev: \Microsoft\Windows\Feedback\Siuf\DmClient → devre dışı`
- `Zamanlanmış görev: \Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload → devre dışı`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo\Enabled = 0 (DWord)`
- `Kayıt defteri: HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo\DisabledByGroupPolicy = 1 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy\TailoredExperiencesWithDiagnosticDataEnabled = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\CPSS\Store\TailoredExperiencesWithDiagnosticDataEnabled\Value = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Policies\Microsoft\Windows\CloudContent\DisableTailoredExperiencesWithDiagnosticData = 1 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Siuf\Rules\NumberOfSIUFInPeriod = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Siuf\Rules\PeriodInNanoSeconds silinir`
- `Kayıt defteri: HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting\Disabled = 1 (DWord)`
- `Kayıt defteri: HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting\Disabled = 1 (DWord)`
- `Kayıt defteri: HKLM:\SOFTWARE\Policies\Microsoft\Windows\System\EnableActivityFeed = 0 (DWord)`
- `Kayıt defteri: HKLM:\SOFTWARE\Policies\Microsoft\Windows\System\PublishUserActivities = 0 (DWord)`
- `Kayıt defteri: HKLM:\SOFTWARE\Policies\Microsoft\Windows\System\UploadUserActivities = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Input\TIPC\Enabled = 0 (DWord)`

## refresh

### refresh.reboot-to-bios

**UEFI (BIOS) ayarlarına yeniden başlat** · Risk: ⚠ Caution

Araç: bilgisayarı birkaç saniye sonra doğrudan UEFI ürün yazılımı ayarlarına yeniden başlatır (shutdown /r /fw). Profille otomatik çalışmaz; yalnız menüden ya da -Only ile, onayla. Açık belgeleri kaydedin. Vazgeçmek için süre dolmadan: shutdown /a. Eski (Legacy BIOS) kurulumlarda desteklenmez.

Onay uyarısı: Bilgisayar birkaç saniye içinde yeniden başlayacak; kaydedilmemiş işler kaybolur.

Çalışma: araç: profille otomatik çalışmaz, menüden / `-Only` ile

Parametreler (varsayılan): `delay` = `10`

Değişiklikler (1):

- `10 sn sonra UEFI (BIOS) ayarlarına yeniden başlat`

## setup

### setup.background-apps-off

**Arka plan uygulamalarını kapat (istisna listesi hariç)** · Risk: Safe

Gizlilik ilkesiyle (AppPrivacy\\LetAppsRunInBackground=2, "zorla reddet") Store / paketli uygulamaların arka planda çalışması kapatılır; exceptions parametresindeki paket aile adları (varsayılan WhatsApp: 5319275A.WhatsAppDesktop\_cv1g1gvanyjgm) LetAppsRunInBackground\_ForceAllowTheseApps ile açık kalır. İlke sonradan kurulan uygulamaları da kapsar; Ayarlar'daki uygulama başına seçenek ilke yüzünden gri görünür. Win32 uygulamaları (ör. winget ile kurulan Telegram Desktop) bu ayardan etkilenmez, bu yüzden listede yok. Kullanıcı genel anahtarı (GlobalUserDisabled) kullanılmadı: o istisnaları da kapatır.

Parametreler (varsayılan): `exceptions` = `5319275A.WhatsAppDesktop_cv1g1gvanyjgm`

Değişiklikler (2):

- `Kayıt defteri: HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy\LetAppsRunInBackground = 2 (DWord)`
- `Kayıt defteri: HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy\LetAppsRunInBackground_ForceAllowTheseApps = 5319275A.WhatsAppDesktop_cv1g1gvanyjgm (MultiString)`

### setup.default-browser

**Varsayılan tarayıcı (Ayarlar üzerinden)** · Risk: ⚠ Caution

https için varsayılan tarayıcı appName değilse Ayarlar \> Varsayılan uygulamalar sayfasını o uygulamada açar; "Varsayılan olarak ayarla" düğmesine kullanıcı basar, sonra sonuç denetlenir. Windows 11 UserChoice karma koruması ve UCPD sürücüsü yüzünden programla güvenilir yol yok (docs/APPS.md). Etkileşimsiz kipte uygulanmaz; geri alma da Ayarlar sayfasından elle yapılır.

Onay uyarısı: Ayarlar sayfası açılacak; "Varsayılan olarak ayarla" düğmesine sizin basmanız gerekir.

Parametreler (varsayılan): `appName` = `Google Chrome` · `progId` = `ChromeHTML` · `scope` = `Machine`

Değişiklikler (1):

- `Varsayılan tarayıcı: Google Chrome (ChromeHTML) — Ayarlar'da tek tıkla, elle`

### setup.edition-pro

**Windows Home → Pro yükseltmesi (Ayarlar üzerinden)** · Risk: ⚠ Caution

Yalnız Home (Core) sürümde: Ayarlar \> Etkinleştirme sayfasını açar; Pro'ya yükseltme kullanıcının kendi ürün anahtarıyla ("Ürün anahtarını değiştir") ya da Microsoft Store'dan satın alınan yükseltmeyle yapılır. Araç anahtar içermez, genel / KMS anahtarı girmez ve hiçbir etkinleştirme atlatması yapmaz (korsan aktivasyon yok). Yükseltme sonunda Windows yeniden başlar; sürüm Pro olunca tweak koşulu sağlanmaz, atlanır. Etkileşimsiz kipte uygulanmaz; geri alma yoktur.

Onay uyarısı: Ayarlar \> Etkinleştirme açılacak; yükseltmeyi kendi ürün anahtarınızla ya da Store'dan siz yaparsınız.

Koşul: Edition Core

Değişiklikler (1):

- `Ayarlar açılır (ms-settings:activation): Etkinleştirme sayfası açıldı: "Ürün anahtarını değiştir" ile kendi Pro anahtarınızı girin ya da Store'dan Pro yükseltmesini alın. Yükseltme sonrası Windows yeniden başlar.`

### setup.mmagent-off

**Bellek sıkıştırma ve ön getirmeyi kapat** · Risk: Safe

Bellek yöneticisinde (MMAgent) bellek sıkıştırma, uygulama başlatma ön getirmesi (prefetch) ve uygulama ön yüklemesi (PreLaunch) kapatılır; ayrıca PrefetchParameters\\EnablePrefetcher=0. Bol RAM'li (en az 16 GB) makine içindir: sıkıştırma için harcanan işlemci zamanı ve arka plan disk okumaları kalkar. Sayfa birleştirme ve OperationAPI'ye dokunulmaz. Bellek sıkıştırma yeniden başlatınca etkinleşir. Get-MMAgent SysMain servisinin çalışmasını ister. Bedeli: EnablePrefetcher=0 açılış ön getirmesini de kapatır, açılış ve ilk uygulama açılışları uzayabilir; NVMe SSD'de kazanç küçük. Hyper-V açık makinede Windows ön getirme değişikliğini reddedebilir ("The request is not supported"). fedai profilinde değil (Faz 9: açılışı uzattığı gözlendi).

Koşul: MinRamGB 16

Değişiklikler (4):

- `Bellek yöneticisi: MemoryCompression → kapalı`
- `Bellek yöneticisi: ApplicationLaunchPrefetching → kapalı`
- `Bellek yöneticisi: ApplicationPreLaunch → kapalı`
- `Kayıt defteri: HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters\EnablePrefetcher = 0 (DWord)`

### setup.store-optimize

**Microsoft Store: otomatik güncelleme, video ve kişiselleştirme kapalı** · Risk: Safe

Store uygulamalarının otomatik indirilip güncellenmesi kapatılır (WindowsStore\\WindowsUpdate\\AutoDownload=2); Store uygulamaları bunun yerine winget upgrade ile güncellenir. Store'un kendi ayarlarında (settings.dat) videoların otomatik oynatılması, uygulama kurulum bildirimleri ve kişiselleştirilmiş deneyim kapatılır. Store hiç açılmamışsa ayar dosyası yoktur: o adımlar atlanır, Store bir kez açıldıktan sonraki çalıştırmada uygulanır. Yazarken Store açıksa kapatılır.

Değişiklikler (4):

- `Kayıt defteri: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsStore\WindowsUpdate\AutoDownload = 2 (DWord)`
- `Uygulama ayarı: Microsoft.WindowsStore VideoAutoplay = False (Bool)`
- `Uygulama ayarı: Microsoft.WindowsStore EnableAppInstallNotifications = False (Bool)`
- `Uygulama ayarı: Microsoft.WindowsStore PersistentSettings\PersonalizationEnabled = False (Bool)`

### setup.updates-staged

**Windows Update: önce bekleyenleri kur, sonra duraklat** · Risk: Safe

Önce bekleyen bütün yazılım güncellemeleri (Windows Update Agent; sürücüler hariç) indirilip kurulur, ilerleme basılır. Kurulum yeniden başlatma isterse çalıştırma burada durur: yeniden başlatıp profili tekrar çalıştırın (CLI ResumeCommand verirse RunOnce ile kendiliğinden sürer); kalan güncellemeler ve duraklatma o çalıştırmada yapılır. Hiç bekleyen kalmayınca güncellemeler pauseDays (varsayılan 365) gün duraklatılır: Ayarlar \> Windows Update'in duraklatma değerleri (UX\\Settings, başlangıç / bitiş UTC). FlightSettingsMaxPauseDays yazılmaz; 365 günün Ayarlar'da nasıl göründüğü VM'de doğrulanacak. -UpdatesOn / -UpdatesOff ayrıca duraklatmayı kaldırır / yeniden koyar. -Undo duraklatmayı kaldırır; kurulan güncellemeler geri alınmaz.

Parametreler (varsayılan): `pauseDays` = `365`

Değişiklikler (2):

- `Windows Update: bekleyen bütün güncellemeler kurulur`
- `Windows Update: 365 gün duraklatılır`

## sound

### sound.startup-sound-off

**Açılış sesini kapat** · Risk: Safe

Windows oturum açma (başlangıç) sesini kapatır. Ayarlar \> Kişiselleştirme \> Temalar \> Sesler \> "Windows Başlangıç sesini çal" kutusunun karşılığı; iki değer birlikte yazılır, biri yalnız bazı sürümlerde okunur.

Değişiklikler (2):

- `Kayıt defteri: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\BootAnimation\DisableStartupSound = 1 (DWord)`
- `Kayıt defteri: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\EditionOverrides\UserSetting_DisableStartupSound = 1 (DWord)`

### sound.volume

**Ses seviyesini ayarla** · Risk: Safe

Varsayılan ses çıkış aygıtının seviyesini level parametresine (0-100, varsayılan 15) getirir. Çıkış aygıtı yoksa (sunucu, sanal makine) atlanır. Aygıt değişirse yeni aygıt kendi seviyesini kullanır.

Parametreler (varsayılan): `level` = `15`

Değişiklikler (1):

- `Ses: varsayılan çıkış → seviye = %15`

## system

### system.restore-point

**Sistem Geri Yükleme noktası** · Risk: Safe

Her çalıştırmada ilk adım (First): profildeki uygulamalardan ve öteki tweak'lerden önce bir Sistem Geri Yükleme noktası oluşturur. Sistem sürücüsünde Sistem Koruması kapalıysa açar. Windows'un 24 saatte bir nokta sınırı (SystemRestorePointCreationFrequency) oluşturma sırasında geçici olarak kaldırılır, sonra eski hâline döner. -Undo noktayı silmez; FAI\_WinOP'un kendi geri alması ayrıca vardır, bu nokta son çare (rstrui). Not: Sistem Koruması açma / nokta oluşturma gerçek makinede (VM) doğrulanmadı.

Çalışma: her çalıştırmada ilk adım (uygulamalardan önce)

Parametreler (varsayılan): `description` = `FAI_WinOP`

Değişiklikler (1):

- `Sistem Geri Yükleme noktası: 'FAI_WinOP'`

### system.timer-resolution

**Zamanlayıcı çözünürlüğü 0,5 ms** · Risk: Safe

FAI\_TimerResolution servisini kurar (src/Native/TimerResolution.cs, açılışta otomatik başlar) ve sistem zamanlayıcısını 0,5 ms'ye (5000 × 100 ns) çeker. Windows 11'de bir sürecin istediği çözünürlük yalnız o süreci etkiler; sistem geneli etki için GlobalTimerResolutionRequests=1 gerekir (Session Manager\\kernel). Pilde güç tüketimini biraz artırabilir. -Undo servisi kaldırır, değeri siler.

Parametreler (varsayılan): `resolution` = `5000`

Değişiklikler (2):

- `Kayıt defteri: HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel\GlobalTimerResolutionRequests = 1 (DWord)`
- `Zamanlayıcı çözünürlüğü servisi: 0.5 ms`

## ui

### ui.account-pictures-black

**Varsayılan hesap resimleri siyah** · Risk: Safe

Windows'un varsayılan kullanıcı ve konuk resimleri (%ProgramData%\\Microsoft\\User Account Pictures içindeki .png / .bmp dosyaları) aynı boyutta düz siyah görüntüyle değiştirilir; hesabına kendi resmini koymamış kullanıcılar Başlat'ta, giriş ekranında ve Ayarlar'da siyah daire görür. Alt klasörler (kullanıcıların kendi resimleri) ve kullanıcının seçtiği resim değişmez. Özgün dosyalar yedeklenir, geri alma birebir geri yazar. Etkisi oturum yeniden açılınca görülür.

Değişiklikler (1):

- `Görüntü: %ProgramData%\Microsoft\User Account Pictures\*.png,*.bmp tek renk #000000 (boyut korunur)`

### ui.copilot-off

**Copilot'u kapat** · Risk: Safe

Windows Copilot ilkeyle kapatılır ("Windows Copilot'u kapat", kullanıcı ve makine) ve görev çubuğundaki Copilot düğmesi gizlenir. Copilot uygulamasının kendisi bloat.remove ile kaldırılır (Microsoft.Copilot). Yeni yapılarda Copilot ayrı bir uygulama olduğundan ilke yalnız eski bütünleşik Copilot'u etkiler; düğme ve uygulama kaldırma asıl işi yapar. Gezgin yeniden başlar.

Değişiklikler (3):

- `Kayıt defteri: HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot\TurnOffWindowsCopilot = 1 (DWord)`
- `Kayıt defteri: HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot\TurnOffWindowsCopilot = 1 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ShowCopilotButton = 0 (DWord)`

### ui.desktop-icons

**Masaüstü simgeleri: Bu Bilgisayar + Geri Dönüşüm Kutusu** · Risk: Safe

Masaüstünde Bu Bilgisayar ve Geri Dönüşüm Kutusu gösterilir (Ayarlar \> Kişiselleştirme \> Temalar \> Masaüstü simgesi ayarları). "Simgeleri otomatik düzenle" kapatılır, "Simgeleri kılavuza hizala" açık kalır (FFlags: Windows varsayılanı 0x40200225, otomatik düzenle biti 0x1 kaldırılır); böylece simgeler sürüklendikleri yerde kalır. Sağ alt köşe konumu: simgeler bir kez elle yerleştirilip -ExportLayout ile profile alınır (desktop.iconLayouts), profil uygulanınca aynı konumlar geri gelir. Gezgin yeniden başlar.

Değişiklikler (3):

- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel\{20D04FE0-3AEA-1069-A2D8-08002B30309D} = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel\{645FF040-5081-101B-9F08-00AA002F954E} = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\Shell\Bags\1\Desktop\FFlags = 1075839524 (DWord)`

### ui.explorer

**Dosya Gezgini düzeni** · Risk: Safe

Dosya Gezgini Bu Bilgisayar ile açılır, dosya uzantıları görünür, başlık çubuğunda tam yol yazar. Gezinti bölmesinde Galeri ve Ana Sayfa gizlenir; 3D Nesneler Bu Bilgisayar'dan gizlenir (Windows 11'de zaten yoktur, eylem yalnız güvencedir). Ana Sayfa HubMode ilkesiyle gizlenir: Microsoft bu davranışı güncellemelerle değiştirebilir, gerçek donanımda doğrulanacak (Faz 9). Gezinti bölmesi değişiklikleri Gezgin yeniden başlayınca görünür.

Değişiklikler (6):

- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\LaunchTo = 1 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\HideFileExt = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState\FullPath = 1 (DWord)`
- `Kayıt defteri: HKCU:\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}\System.IsPinnedToNameSpaceTree = 0 (DWord)`
- `Kayıt defteri: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\HubMode = 1 (DWord)`
- `Kayıt defteri: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{31C0DD25-9439-4F12-BF41-7FF4EDA38722}\PropertyBag\ThisPCPolicy = Hide (String)`

### ui.lockscreen-black

**Kilit ve oturum açma ekranı siyah** · Risk: Safe

Düz siyah bir görüntü (C:\\ProgramData\\FAI\_WinOP\\Black.png, 1920x1080) üretilir ve kilit ekranı görüntüsü olarak ilkeyle (PersonalizationCSP) atanır; Windows Spotlight ve kilit ekranı ipuçları bu görüntüyle devre dışı kalır, kullanıcı Ayarlar'dan değiştiremez. Oturum açma ekranındaki bulanık (akrilik) arka plan kapatılır, böylece giriş ekranı da siyah görünür. Yol sistem sürücüsü C: varsayılarak yazılır (ilke değeri ortam değişkeni açmaz). Etkisi bir sonraki kilitlemede görülür.

Değişiklikler (5):

- `Görüntü: C:\ProgramData\FAI_WinOP\Black.png tek renk #000000 (1920x1080, varsa boyutu korunur)`
- `Kayıt defteri: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP\LockScreenImagePath = C:\ProgramData\FAI_WinOP\Black.png (String)`
- `Kayıt defteri: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP\LockScreenImageUrl = C:\ProgramData\FAI_WinOP\Black.png (String)`
- `Kayıt defteri: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP\LockScreenImageStatus = 1 (DWord)`
- `Kayıt defteri: HKLM:\SOFTWARE\Policies\Microsoft\Windows\System\DisableAcrylicBackgroundOnLogon = 1 (DWord)`

### ui.notepad-settings

**Not Defteri ayarları** · Risk: Safe

Not Defteri (Store sürümü) kendi ayar dosyasından (settings.dat) ayarlanır: dosyalar yeni pencerede açılır (sekme yerine), açılışta önceki oturum geri yüklenmez (kaydedilmemiş sekmeler hatırlanmaz), Copilot ile yeniden yazma (AI) kapalı. Not Defteri açıksa kapatılır. Ayar dosyası uygulama ilk açılışında oluşur: Not Defteri hiç açılmadıysa tweak "zaten uygun" görünür ve bir sonraki çalıştırmada uygulanır. Değer adları ve anlamları Not Defteri sürümüne bağlıdır; gerçek makinede doğrulanacak (Faz 9).

Parametreler (varsayılan): `aiRewrite` = `False` · `openInNewWindow` = `1` · `restoreSession` = `False`

Değişiklikler (3):

- `Uygulama ayarı: Microsoft.WindowsNotepad OpenFile = 1 (Int32)`
- `Uygulama ayarı: Microsoft.WindowsNotepad GhostFile = False (Bool)`
- `Uygulama ayarı: Microsoft.WindowsNotepad RewriteEnabled = False (Bool)`

### ui.notifications

**Bildirimleri kapat (istisna listesi hariç)** · Risk: Safe

Bildirimler genel olarak açık tutulur, ama bildirim gönderen uygulama ve sistem bileşenlerinin hepsi tek tek kapatılır; exceptions parametresindeki kalıplara (-like, varsayılan \*WhatsApp\*, \*Telegram\*) uyanlar açık kalır. Windows Güvenliği / Defender ile Güvenlik ve Bakım bildirimleri her zaman korunur. Ayrıca Windows hoş geldin deneyimi, kurulumu tamamlama önerileri ve ipucu / öneri bildirimleri kapanır. Bir uygulamanın bildirim kaydı ilk bildiriminde oluşur: sonradan kurulan uygulama profil yeniden çalıştırılınca kapanır.

Parametreler (varsayılan): `exceptions` = `*WhatsApp*, *Telegram*`

Değişiklikler (10):

- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications\ToastEnabled = 1 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.Suggested\Enabled = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.StartupApp\Enabled = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Microsoft.SkyDrive.Desktop\Enabled = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\windows.immersivecontrolpanel_cw5n1h2txyewy!microsoft.windows.immersivecontrolpanel\Enabled = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\*\Enabled = 0 (DWord) — hariç: Windows.Defender*, *SecHealthUI*, Windows.SystemToast.SecurityAndMaintenance, *WhatsApp*, *Telegram*`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SubscribedContent-310093Enabled = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SubscribedContent-338389Enabled = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SoftLandingEnabled = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement\ScoobeSystemSettingEnabled = 0 (DWord)`

### ui.taskbar

**Görev çubuğu: ortalı, otomatik gizlenir, yalnız Dosya Gezgini + Chrome** · Risk: Safe

Görev çubuğu ortalanır ve otomatik gizlenir (StuckRects3). Arama kutusu, Görev Görünümü, Sohbet ve Copilot düğmeleri kaldırılır (Widgets düğmesi ui.widgets-off ilkesiyle). Bildirim alanında yalnız taşma oku ve sistem simgeleri (Wi-Fi, ses, pil) kalır: uygulama simgeleri taşma menüsüne alınır, sonradan gelen uygulamalar da Windows'un varsayılanıyla oraya düşer. Sabitlemeler yalnız Dosya Gezgini ve Google Chrome olur (diğerleri kalkar; Windows'un "Start Layout" ilkesi tek seferlik kullanılır, sonra kullanıcı istediğini sabitleyebilir). Chrome kurulu değilse yalnız Gezgin sabitlenir, sonraki çalıştırmada Chrome eklenir. Gezgin yeniden başlar; etkileşimli oturum yoksa (CI) sabitleme adımı uygulanamaz.

Parametreler (varsayılan): `autoHide` = `True`

Değişiklikler (8):

- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarAl = 1 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3\Settings [8. bayt, maske 0x01] = 0x01`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\Search\SearchboxTaskbarMode = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ShowTaskViewButton = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ShowCopilotButton = 0 (DWord)`
- `Kayıt defteri: HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Chat\ChatIcon = 3 (DWord)`
- `Kayıt defteri: HKCU:\Control Panel\NotifyIconSettings\*\IsPromoted = 0 (DWord)`
- `Görev çubuğu sabitlemeleri yalnız: Microsoft.Windows.Explorer, Google Chrome.lnk`

### ui.theme-black

**Siyah tema (koyu, saydamlık kapalı, otomatik vurgu, düz siyah duvar kağıdı)** · Risk: Safe

Uygulamalar ve Windows koyu kipe geçer, saydamlık efektleri kapanır. Vurgu rengi Otomatik (duvar kağıdından; düz siyahta Windows varsayılanı) ve Başlat / görev çubuğu ile pencere başlıklarında gösterilmez: yüzeyler koyu kipin kendi koyu grisinde kalır. Duvar kağıdı kaldırılır, masaüstü düz siyah renk olur (Kişiselleştir \> Arka plan: Düz renk). Değişiklikler hemen yayınlanır; bazı uygulamalar yeniden açılınca koyulaşır.

Değişiklikler (9):

- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize\AppsUseLightTheme = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize\SystemUsesLightTheme = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize\EnableTransparency = 0 (DWord)`
- `Kayıt defteri: HKCU:\Control Panel\Desktop\AutoColorization = 1 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize\ColorPrevalence = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\DWM\ColorPrevalence = 0 (DWord)`
- `Kayıt defteri: HKCU:\Control Panel\Desktop\WallPaper =  (String)`
- `Kayıt defteri: HKCU:\Control Panel\Colors\Background = 0 0 0 (String)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers\BackgroundType = 1 (DWord)`

### ui.visual-effects

**Görsel efektleri azalt (yazı yumuşatma açık)** · Risk: Safe

Sistem \> Gelişmiş sistem ayarları \> Performans seçenekleri "Özel" yapılır: menü / araç ipucu solma ve kayma animasyonları, açılır kutu ve liste kaydırma animasyonları, fare işaretçisi ve pencere gölgeleri, simge etiketi gölgeleri, yarı saydam seçim dikdörtgeni, pencere küçültme / büyütme ve görev çubuğu animasyonları kapanır. Ekran yazı tiplerinin kenarlarını yumuşatma (ClearType) ve küçük resim önizlemeleri açık kalır; pencere sürüklenirken içerik gösterilmeye devam eder. UserPreferencesMask ikili (REG\_BINARY) değerdir; değişiklikler oturum kapatılıp açılınca tam etkili olur.

Değişiklikler (8):

- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects\VisualFXSetting = 3 (DWord)`
- `Kayıt defteri: HKCU:\Control Panel\Desktop\UserPreferencesMask = 144,18,3,128,16,0,0,0 (Binary)`
- `Kayıt defteri: HKCU:\Control Panel\Desktop\WindowMetrics\MinAnimate = 0 (String)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarAnimations = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ListviewAlphaSelect = 0 (DWord)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ListviewShadow = 0 (DWord)`
- `Kayıt defteri: HKCU:\Control Panel\Desktop\FontSmoothing = 2 (String)`
- `Kayıt defteri: HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\IconsOnly = 0 (DWord)`

### ui.widgets-off

**Pencere öğelerini (Widgets) kapat** · Risk: Safe

Pencere öğeleri panosu ve görev çubuğundaki düğmesi ilkeyle kapatılır ("Pencere öğelerine izin ver" = Devre dışı); Windows 10 mirası Haberler ve ilgi alanları da kapalı. Düğme ilkeyle kalkar: TaskbarDa kullanıcı değeri yeni yapılarda Windows tarafından korunur (UCPD), dışarıdan yazılamaz. Pencere öğeleri uygulaması (MicrosoftWindows.Client.WebExperience) kaldırılmaz. Gezgin yeniden başlar.

Değişiklikler (2):

- `Kayıt defteri: HKLM:\SOFTWARE\Policies\Microsoft\Dsh\AllowNewsAndInterests = 0 (DWord)`
- `Kayıt defteri: HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds\EnableFeeds = 0 (DWord)`

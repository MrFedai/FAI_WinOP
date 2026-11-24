# Tweak kataloğu

> Otomatik üretilir: `pwsh -NoProfile -File build/TweaksDoc.ps1` (kaynak: `tweaks/**/*.psd1`). Elle düzenlemeyin.

Risk: **Safe** doğrudan uygulanır · **⚠ Caution** onay ister · **⛔ Risk** "EVET" yazılmasını ister, `-Unattended` kipte uygulanmaz.
Değişiklikler varsayılan parametrelerle listelenir; profil parametreleri geçersiz kılabilir.

| Id | Başlık | Risk | Koşul | Parametre |
| --- | --- | --- | --- | --- |
| [`privacy.app-permissions`](#privacyapp-permissions) | Uygulama izinlerini kapat (kamera ve mikrofon açık) | Safe | — | — |
| [`privacy.search-ads`](#privacysearch-ads) | Arama ve Başlat reklamlarını kapat | Safe | — | — |
| [`privacy.telemetry`](#privacytelemetry) | Telemetriyi en aza indir | Safe | — | — |
| [`setup.default-browser`](#setupdefault-browser) | Varsayılan tarayıcı (Ayarlar üzerinden) | ⚠ Caution | — | `appName`, `progId`, `scope` |
| [`sound.startup-sound-off`](#soundstartup-sound-off) | Açılış sesini kapat | Safe | — | — |
| [`sound.volume`](#soundvolume) | Ses seviyesini ayarla | Safe | — | `level` |
| [`ui.explorer`](#uiexplorer) | Dosya Gezgini düzeni | Safe | — | — |
| [`ui.notifications`](#uinotifications) | Bildirimleri kapat (istisna listesi hariç) | Safe | — | `exceptions` |
| [`ui.visual-effects`](#uivisual-effects) | Görsel efektleri azalt (yazı yumuşatma açık) | Safe | — | — |

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

## setup

### setup.default-browser

**Varsayılan tarayıcı (Ayarlar üzerinden)** · Risk: ⚠ Caution

https için varsayılan tarayıcı appName değilse Ayarlar \> Varsayılan uygulamalar sayfasını o uygulamada açar; "Varsayılan olarak ayarla" düğmesine kullanıcı basar, sonra sonuç denetlenir. Windows 11 UserChoice karma koruması ve UCPD sürücüsü yüzünden programla güvenilir yol yok (docs/APPS.md). Etkileşimsiz kipte uygulanmaz; geri alma da Ayarlar sayfasından elle yapılır.

Onay uyarısı: Ayarlar sayfası açılacak; "Varsayılan olarak ayarla" düğmesine sizin basmanız gerekir.

Parametreler (varsayılan): `appName` = `Google Chrome` · `progId` = `ChromeHTML` · `scope` = `Machine`

Değişiklikler (1):

- `Varsayılan tarayıcı: Google Chrome (ChromeHTML) — Ayarlar'da tek tıkla, elle`

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

## ui

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

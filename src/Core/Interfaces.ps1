# Sağlayıcı arayüzleri. PowerShell 5.1'de 'interface' yok: arayüz = soyut taban sınıf; yöntemler
# NotImplementedException atar, gerçek (Windows*) ve sahte (Fake*) sağlayıcılar bunları ezer.
# Eylemler Windows'a yalnız bu arayüzler üzerinden dokunur (CLAUDE.md: doğrudan Set-ItemProperty vb. yok).

# Kayıt defteri. Yol biçimi: 'HKLM:\SOFTWARE\...' (HKLM, HKCU, HKCR, HKU, HKCC).
class IRegistryProvider {
    [bool] KeyExists([string] $Path) { throw [System.NotImplementedException]::new('IRegistryProvider.KeyExists') }
    [bool] ValueExists([string] $Path, [string] $Name) { throw [System.NotImplementedException]::new('IRegistryProvider.ValueExists') }
    # Doğrudan alt anahtar adları (yalnız son parça); anahtar yoksa boş dizi.
    [string[]] GetSubKeyNames([string] $Path) { throw [System.NotImplementedException]::new('IRegistryProvider.GetSubKeyNames') }
    # Anahtardaki değer adları (varsayılan değer hariç); anahtar yoksa boş dizi.
    [string[]] GetValueNames([string] $Path) { throw [System.NotImplementedException]::new('IRegistryProvider.GetValueNames') }
    # Değer yoksa $null.
    [object] GetValue([string] $Path, [string] $Name) { throw [System.NotImplementedException]::new('IRegistryProvider.GetValue') }
    # String | ExpandString | Binary | DWord | MultiString | QWord; değer yoksa boş metin.
    [string] GetValueKind([string] $Path, [string] $Name) { throw [System.NotImplementedException]::new('IRegistryProvider.GetValueKind') }
    # Anahtar yoksa oluşturur. YAZMA.
    [void] SetValue([string] $Path, [string] $Name, [object] $Value, [string] $Kind) { throw [System.NotImplementedException]::new('IRegistryProvider.SetValue') }
    # Ham okuma: @{ Type = <int ham tür (REG_*)>; Bytes = <byte[]> }; değer yoksa $null. REG_NONE / bilinmeyen tür için.
    [hashtable] GetRawValue([string] $Path, [string] $Name) { throw [System.NotImplementedException]::new('IRegistryProvider.GetRawValue') }
    # Ham yazma: tür numarası aynen korunur. Anahtar yoksa oluşturur. YAZMA.
    [void] SetRawValue([string] $Path, [string] $Name, [int] $Type, [byte[]] $Bytes) { throw [System.NotImplementedException]::new('IRegistryProvider.SetRawValue') }
    # Değer yoksa sessizce geçer. YAZMA.
    [void] DeleteValue([string] $Path, [string] $Name) { throw [System.NotImplementedException]::new('IRegistryProvider.DeleteValue') }
    # Anahtarda değer ve alt anahtar yoksa siler; anahtar yoksa ya da doluysa sessizce geçer. YAZMA.
    [void] DeleteEmptyKey([string] $Path) { throw [System.NotImplementedException]::new('IRegistryProvider.DeleteEmptyKey') }
}

# Servisler. Ad 'IServiceProvider' DEĞİL: System.IServiceProvider ile çakışır; bundle dışındaki kod (testler) [IServiceProvider]
# yazınca parse anında .NET arayüzüne çözülür. StartType: Automatic | Manual | Disabled. Status: Running | Stopped.
class IServiceManager {
    [bool] ServiceExists([string] $Name) { throw [System.NotImplementedException]::new('IServiceManager.ServiceExists') }
    [string] GetStartType([string] $Name) { throw [System.NotImplementedException]::new('IServiceManager.GetStartType') }
    [string] GetStatus([string] $Name) { throw [System.NotImplementedException]::new('IServiceManager.GetStatus') }
    # YAZMA.
    [void] SetStartType([string] $Name, [string] $StartType) { throw [System.NotImplementedException]::new('IServiceManager.SetStartType') }
    # YAZMA.
    [void] StartService([string] $Name) { throw [System.NotImplementedException]::new('IServiceManager.StartService') }
    # YAZMA.
    [void] StopService([string] $Name) { throw [System.NotImplementedException]::new('IServiceManager.StopService') }
}

# Zamanlanmış görevler. Durum: Enabled | Disabled; görev yoksa boş metin.
class ITaskProvider {
    [string] GetTaskState([string] $TaskPath) { throw [System.NotImplementedException]::new('ITaskProvider.GetTaskState') }
    # YAZMA.
    [void] SetTaskEnabled([string] $TaskPath, [bool] $Enabled) { throw [System.NotImplementedException]::new('ITaskProvider.SetTaskEnabled') }
    # Görevin çalıştırdığı komut: @{ Execute; Arguments }; görev yoksa $null.
    [hashtable] GetTaskAction([string] $TaskPath) { throw [System.NotImplementedException]::new('ITaskProvider.GetTaskAction') }
    # Açılışta SYSTEM hesabıyla (en yüksek yetki) çalışan görevi kaydeder; varsa üzerine yazar. YAZMA.
    [void] RegisterStartupTask([string] $TaskPath, [string] $Execute, [string] $Arguments, [string] $Description) { throw [System.NotImplementedException]::new('ITaskProvider.RegisterStartupTask') }
    # Görevi siler; yoksa sessizce geçer. YAZMA.
    [void] UnregisterTask([string] $TaskPath) { throw [System.NotImplementedException]::new('ITaskProvider.UnregisterTask') }
    # RegisterStartupTask gibi, ama süre sınırı yok (sürekli çalışan izleyici, ör. gaming.per-game). YAZMA.
    [void] RegisterWatcherTask([string] $TaskPath, [string] $Execute, [string] $Arguments, [string] $Description) { throw [System.NotImplementedException]::new('ITaskProvider.RegisterWatcherTask') }
}

# Appx (Store) paketleri: kullanıcı ve provisioned.
class IAppxProvider {
    [string[]] GetInstalled() { throw [System.NotImplementedException]::new('IAppxProvider.GetInstalled') }
    [string[]] GetProvisioned() { throw [System.NotImplementedException]::new('IAppxProvider.GetProvisioned') }
    # YAZMA.
    [void] RemoveInstalled([string] $Name) { throw [System.NotImplementedException]::new('IAppxProvider.RemoveInstalled') }
    # YAZMA.
    [void] RemoveProvisioned([string] $Name) { throw [System.NotImplementedException]::new('IAppxProvider.RemoveProvisioned') }
    # Kaldırılan kullanıcı paketini makinedeki kopyasından (provisioned / başka kullanıcı) yeniden kaydeder; kopya yoksa
    # hata fırlatır. Provisioned kaldırmanın geri dönüşü yoktur (kaynak paket silinir). YAZMA.
    [void] RestoreInstalled([string] $Name) { throw [System.NotImplementedException]::new('IAppxProvider.RestoreInstalled') }
}

# Paket yöneticisi (winget / msstore). Source: 'winget' | 'msstore'.
class IPackageProvider {
    [bool] IsInstalled([string] $PackageId, [string] $Source) { throw [System.NotImplementedException]::new('IPackageProvider.IsInstalled') }
    # YAZMA.
    [void] Install([string] $PackageId, [string] $Source) { throw [System.NotImplementedException]::new('IPackageProvider.Install') }
    # YAZMA.
    [void] Uninstall([string] $PackageId, [string] $Source) { throw [System.NotImplementedException]::new('IPackageProvider.Uninstall') }
    # Uygulamanın kendi kaldırıcısını (FilePath açılmış yol + Arguments) çalıştırır, paket listeden düşene kadar bekler.
    # Kaldırma kaydında sessiz komut olmayan kurucular için (winget onları argümansız, etkileşimli başlatır). YAZMA.
    [void] RunUninstaller([string] $PackageId, [string] $Source, [string] $FilePath, [string] $Arguments) { throw [System.NotImplementedException]::new('IPackageProvider.RunUninstaller') }
}

# Sistem bilgisi (koşullar için, salt okunur).
class ISystemInfoProvider {
    [bool] IsLaptop() { throw [System.NotImplementedException]::new('ISystemInfoProvider.IsLaptop') }
    [bool] HasNvidia() { throw [System.NotImplementedException]::new('ISystemInfoProvider.HasNvidia') }
    [bool] HasAmdGpu() { throw [System.NotImplementedException]::new('ISystemInfoProvider.HasAmdGpu') }
    [bool] HasIntelGpu() { throw [System.NotImplementedException]::new('ISystemInfoProvider.HasIntelGpu') }
    # Windows sürümü: Core | Pro | Enterprise | Education | ...
    [string] GetEdition() { throw [System.NotImplementedException]::new('ISystemInfoProvider.GetEdition') }
    [int] GetBuild() { throw [System.NotImplementedException]::new('ISystemInfoProvider.GetBuild') }
    [double] GetRamGB() { throw [System.NotImplementedException]::new('ISystemInfoProvider.GetRamGB') }
    # Mantıksal işlemci (iş parçacığı) sayısı, bütün soketler toplamı.
    [int] GetLogicalProcessorCount() { throw [System.NotImplementedException]::new('ISystemInfoProvider.GetLogicalProcessorCount') }
    # Fiziksel çekirdek sayısı, bütün soketler toplamı (SMT varsa mantıksal sayıdan az).
    [int] GetCoreCount() { throw [System.NotImplementedException]::new('ISystemInfoProvider.GetCoreCount') }
}

# Sistem denetimi: Sistem Geri Yükleme (sistem sürücüsü) ve yeniden başlatma.
class ISystemControlProvider {
    # Sistem sürücüsünde Sistem Koruması açık mı.
    [bool] IsRestoreEnabled() { throw [System.NotImplementedException]::new('ISystemControlProvider.IsRestoreEnabled') }
    # Sistem sürücüsünde Sistem Korumasını açar. YAZMA.
    [void] EnableRestore() { throw [System.NotImplementedException]::new('ISystemControlProvider.EnableRestore') }
    # Geri yükleme noktası oluşturur (Windows'un 24 saatte bir sınırı geçici olarak kaldırılır). YAZMA.
    [void] CreateRestorePoint([string] $Description) { throw [System.NotImplementedException]::new('ISystemControlProvider.CreateRestorePoint') }
    # DelaySeconds sonra UEFI ürün yazılımı ayarlarına (BIOS) yeniden başlatır. YAZMA.
    [void] RestartToFirmware([int] $DelaySeconds) { throw [System.NotImplementedException]::new('ISystemControlProvider.RestartToFirmware') }
}

# Bellek yöneticisi özellikleri (Get-MMAgent): MemoryCompression, PageCombining, ApplicationLaunchPrefetching,
# ApplicationPreLaunch, OperationAPI. Değişikliklerin bir kısmı yeniden başlatınca etkinleşir.
class IMemoryAgentProvider {
    # Özellik adı → açık mı (bool).
    [hashtable] GetState() { throw [System.NotImplementedException]::new('IMemoryAgentProvider.GetState') }
    # YAZMA.
    [void] SetFeature([string] $Feature, [bool] $Enabled) { throw [System.NotImplementedException]::new('IMemoryAgentProvider.SetFeature') }
}

# Windows Update (Windows Update Agent). Yalnız yazılım güncellemeleri (sürücüler hariç), gizlenmemiş ve kurulmamış olanlar.
class IUpdateProvider {
    # Bekleyen güncellemelerin başlıkları (arama sürebilir; salt okunur).
    [string[]] GetPending() { throw [System.NotImplementedException]::new('IUpdateProvider.GetPending') }
    # Bekleyenleri indirir ve kurar (ilerleme basar): @{ Installed = <int>; Failed = <int>; RebootRequired = <bool> }. YAZMA.
    [hashtable] InstallPending() { throw [System.NotImplementedException]::new('IUpdateProvider.InstallPending') }
    # Kurulmuş güncelleme yeniden başlatma bekliyor mu.
    [bool] IsRebootPending() { throw [System.NotImplementedException]::new('IUpdateProvider.IsRebootPending') }
}

# Kullanıcıya soru. Onaylar yalnız buradan gelir (Unattended modda motor bunu hiç çağırmaz).
class IPromptProvider {
    # E/H sorusu (Caution). Evet ise $true.
    [bool] Confirm([string] $Message) { throw [System.NotImplementedException]::new('IPromptProvider.Confirm') }
    # Tam metin ister (Risk: 'EVET' yazılmalı). Yazılan Expected ile birebir eşitse $true.
    [bool] ConfirmExact([string] $Message, [string] $Expected) { throw [System.NotImplementedException]::new('IPromptProvider.ConfirmExact') }
    # Serbest metin satırı (menü seçimi). Yanıt yoksa boş metin.
    [string] ReadLine([string] $Message) { throw [System.NotImplementedException]::new('IPromptProvider.ReadLine') }
}

# Dosyalar. Yollar ortam değişkenleri AÇILMIŞ olarak gelir (eylem açar). Yalnız dosya; klasör silinmez.
class IFileProvider {
    [bool] FileExists([string] $Path) { throw [System.NotImplementedException]::new('IFileProvider.FileExists') }
    # Bayt cinsinden boyut; dosya yoksa -1.
    [long] GetSize([string] $Path) { throw [System.NotImplementedException]::new('IFileProvider.GetSize') }
    [byte[]] ReadBytes([string] $Path) { throw [System.NotImplementedException]::new('IFileProvider.ReadBytes') }
    # Üst klasör yoksa oluşturur; dosya varsa üzerine yazar. YAZMA.
    [void] WriteBytes([string] $Path, [byte[]] $Bytes) { throw [System.NotImplementedException]::new('IFileProvider.WriteBytes') }
    # Dosya yoksa sessizce geçer. YAZMA.
    [void] DeleteFile([string] $Path) { throw [System.NotImplementedException]::new('IFileProvider.DeleteFile') }
    # Klasördeki dosyaların tam yolları (alt klasörler hariç, sıralı); klasör yoksa boş dizi.
    [string[]] ListFiles([string] $Directory) { throw [System.NotImplementedException]::new('IFileProvider.ListFiles') }
    # Klasör boşsa siler; yoksa ya da doluysa sessizce geçer. YAZMA.
    [void] DeleteEmptyDirectory([string] $Directory) { throw [System.NotImplementedException]::new('IFileProvider.DeleteEmptyDirectory') }
    # Klasör ve bütün alt klasörlerdeki, -like kalıbına (ör. '*.lnk') uyan dosyaların tam yolları (sıralı); klasör yoksa boş.
    [string[]] FindFiles([string] $Directory, [string] $Filter) { throw [System.NotImplementedException]::new('IFileProvider.FindFiles') }
    # Bilinen klasör ([Environment+SpecialFolder] adı: DesktopDirectory, CommonDesktopDirectory, Programs, CommonPrograms,
    # Startup, CommonStartup). OneDrive yönlendirmesi dahil gerçek yol; tanımsızsa boş metin.
    [string] GetKnownFolder([string] $Name) { throw [System.NotImplementedException]::new('IFileProvider.GetKnownFolder') }
}

# Kısayollar (.lnk). Özellikler: TargetPath, Arguments, WorkingDirectory, IconLocation, Description.
class IShortcutProvider {
    # Kısayol yoksa $null; varsa özellik hashtable'ı.
    [hashtable] ReadShortcut([string] $Path) { throw [System.NotImplementedException]::new('IShortcutProvider.ReadShortcut') }
    # Verilen özelliklerle oluşturur / üzerine yazar (verilmeyen özellik boş kalır). YAZMA.
    [void] WriteShortcut([string] $Path, [hashtable] $Properties) { throw [System.NotImplementedException]::new('IShortcutProvider.WriteShortcut') }
}

# Güç planları (powercfg). Scheme: GUID ya da powercfg takma adı (SCHEME_CURRENT, SCHEME_MIN...); Subgroup / Setting:
# GUID ya da takma ad (SUB_SLEEP, STANDBYIDLE...). AC = prizde, DC = pilde.
class IPowerProvider {
    # Etkin planın GUID'i (küçük harf).
    [string] GetActiveScheme() { throw [System.NotImplementedException]::new('IPowerProvider.GetActiveScheme') }
    # GUID ya da takma ad → plan GUID'i (küçük harf); plan yoksa boş metin.
    [string] ResolveScheme([string] $Scheme) { throw [System.NotImplementedException]::new('IPowerProvider.ResolveScheme') }
    # YAZMA.
    [void] SetActiveScheme([string] $Scheme) { throw [System.NotImplementedException]::new('IPowerProvider.SetActiveScheme') }
    # Ayarın şu anki indeksi; ayar yoksa hata.
    [long] GetValue([string] $Scheme, [string] $Subgroup, [string] $Setting, [bool] $OnAC) { throw [System.NotImplementedException]::new('IPowerProvider.GetValue') }
    # Plan etkinse değişiklik hemen uygulanır. YAZMA.
    [void] SetValue([string] $Scheme, [string] $Subgroup, [string] $Setting, [bool] $OnAC, [long] $Value) { throw [System.NotImplementedException]::new('IPowerProvider.SetValue') }
    # Source planını (GUID ya da takma ad) Guid kimliğiyle kopyalar ve Name adını verir; kopyalanamazsa hata. YAZMA.
    [void] CreateScheme([string] $Source, [string] $Guid, [string] $Name) { throw [System.NotImplementedException]::new('IPowerProvider.CreateScheme') }
    # Planı siler (etkin plan silinemez: hata). YAZMA.
    [void] DeleteScheme([string] $Guid) { throw [System.NotImplementedException]::new('IPowerProvider.DeleteScheme') }
    # Hazırda bekletme (hiberfil) açık mı.
    [bool] GetHibernate() { throw [System.NotImplementedException]::new('IPowerProvider.GetHibernate') }
    # powercfg /hibernate on|off. YAZMA.
    [void] SetHibernate([bool] $Enabled) { throw [System.NotImplementedException]::new('IPowerProvider.SetHibernate') }
}

# PowerShell betiği çalıştırıcı (Script eylemi). Kod tek bağımsız değişken alır: param($Snapshot).
class IScriptHost {
    # Salt okunur betik (Test / Snapshot); yazma yapmamalı.
    [object] Query([string] $Code, [object] $Argument) { throw [System.NotImplementedException]::new('IScriptHost.Query') }
    # Durum değiştiren betik (Apply / Revert). YAZMA.
    [object] Run([string] $Code, [object] $Argument) { throw [System.NotImplementedException]::new('IScriptHost.Run') }
}

# Varsayılan ses çıkış aygıtı (Core Audio; src/Native/AudioEndpoint.cs). Seviye 0-100.
class IAudioProvider {
    # Varsayılan çıkış aygıtı var mı (sunucu / CI makinesinde olmayabilir).
    [bool] HasDevice() { throw [System.NotImplementedException]::new('IAudioProvider.HasDevice') }
    [int] GetVolume() { throw [System.NotImplementedException]::new('IAudioProvider.GetVolume') }
    # YAZMA.
    [void] SetVolume([int] $Level) { throw [System.NotImplementedException]::new('IAudioProvider.SetVolume') }
    [bool] GetMute() { throw [System.NotImplementedException]::new('IAudioProvider.GetMute') }
    # YAZMA.
    [void] SetMute([bool] $Mute) { throw [System.NotImplementedException]::new('IAudioProvider.SetMute') }
}

# Zamanlayıcı çözünürlüğü servisi (src/Native/TimerResolution.cs). Çözünürlük 100 ns biriminde (5000 = 0,5 ms).
class ITimerResolutionProvider {
    [bool] IsInstalled() { throw [System.NotImplementedException]::new('ITimerResolutionProvider.IsInstalled') }
    # Kurulu servisin istediği çözünürlük; kurulu değilse 0.
    [int] GetResolution() { throw [System.NotImplementedException]::new('ITimerResolutionProvider.GetResolution') }
    # Derler, servisi kurar (otomatik başlar) ve başlatır; kuruluysa yeniden kurar. YAZMA.
    [void] Install([int] $Resolution) { throw [System.NotImplementedException]::new('ITimerResolutionProvider.Install') }
    # Servisi durdurur, siler, ikiliyi kaldırır; kurulu değilse sessizce geçer. YAZMA.
    [void] Uninstall() { throw [System.NotImplementedException]::new('ITimerResolutionProvider.Uninstall') }
}

# Kabuk: URI / ms-settings: sayfası açar (varsayılan tarayıcı gibi yalnız kullanıcının yapabildiği adımlar için).
class IShellProvider {
    # YAZMA (kullanıcıya pencere açar; dry-run'da çağrılmaz).
    [void] OpenUri([string] $Uri) { throw [System.NotImplementedException]::new('IShellProvider.OpenUri') }
}

# Microsoft Edge (Chromium) ve WebView2 Runtime. Sürüm boşsa kurulu değil. WebView2'ye hiçbir yöntem dokunmaz.
class IEdgeProvider {
    [string] GetEdgeVersion() { throw [System.NotImplementedException]::new('IEdgeProvider.GetEdgeVersion') }
    [string] GetWebView2Version() { throw [System.NotImplementedException]::new('IEdgeProvider.GetWebView2Version') }
    # Edge'i sistem düzeyinde kaldırır (EdgeUpdate ve WebView2 kalır); kaldırılamazsa hata fırlatır. YAZMA.
    [void] UninstallEdge() { throw [System.NotImplementedException]::new('IEdgeProvider.UninstallEdge') }
    # Edge'i yeniden kurar (geri alma). YAZMA.
    [void] InstallEdge() { throw [System.NotImplementedException]::new('IEdgeProvider.InstallEdge') }
}

# Kabuk görünümü: Gezgin (görev çubuğu / masaüstü) ve ayar yayınları. Kayıt defterine yazılan görünüm ayarlarının etkisi
# için motor tweak'in Refresh listesini çalıştırmanın sonunda bir kez buradan ister.
#   Shell     → explorer.exe yeniden başlar (görev çubuğu, sabitlemeler, masaüstü simgeleri)
#   Desktop   → duvar kağıdı ve masaüstü rengi kayıt defterinden yeniden okunur
#   Settings  → WM_SETTINGCHANGE (tema / renk: ImmersiveColorSet) yayınlanır
#   StartMenu → Başlat (StartMenuExperienceHost) yeniden başlar
class IDesktopProvider {
    # Etkileşimli kabuk (explorer.exe) çalışıyor mu; CI / hizmet oturumunda çalışmaz.
    [bool] IsShellRunning() { throw [System.NotImplementedException]::new('IDesktopProvider.IsShellRunning') }
    # Kabuk çalışmıyorsa Shell / StartMenu sessizce geçer. YAZMA.
    [void] Refresh([string] $Kind) { throw [System.NotImplementedException]::new('IDesktopProvider.Refresh') }
    # Bekleme (Gezgin'in yeniden başlayıp ayarı yazmasını beklemek için; sahte sağlayıcıda anında döner).
    [void] Wait([int] $Milliseconds) { throw [System.NotImplementedException]::new('IDesktopProvider.Wait') }
}

# Görüntü dosyaları (tek renkli kilit ekranı / hesap resmi). Renk 'RRGGBB' (onaltılık). Yollar açılmış gelir.
class IImageProvider {
    # @(genişlik, yükseklik); dosya yoksa ya da görüntü değilse $null.
    [int[]] GetSize([string] $Path) { throw [System.NotImplementedException]::new('IImageProvider.GetSize') }
    # Görüntü baştan sona verilen renkte mi (örnekleme); dosya yoksa ya da okunamıyorsa $false.
    [bool] IsSolid([string] $Path, [string] $Color) { throw [System.NotImplementedException]::new('IImageProvider.IsSolid') }
    # Tek renkli görüntünün dosya baytları. Format: png | jpg | bmp. Salt üretim (diske yazmaz).
    [byte[]] NewSolid([int] $Width, [int] $Height, [string] $Color, [string] $Format) { throw [System.NotImplementedException]::new('IImageProvider.NewSolid') }
}

# Paketli (Store) uygulamanın ayar deposu: %LOCALAPPDATA%\Packages\<paket>\Settings\settings.dat, LocalState anahtarı.
# Name 'Alt\Ad' biçiminde olabilir: alt anahtar LocalState'e göreli (ör. 'PersistentSettings\PersonalizationEnabled').
# Değerler özel türlüdür (ör. 0x5F5E10B = bool, 0x5F5E104 = int32); veri = yük + 8 bayt FILETIME zaman damgası.
class IAppSettingsProvider {
    # Paketin ayar dosyası var mı (uygulama kurulu ve en az bir kez açılmış).
    [bool] HasSettings([string] $Package) { throw [System.NotImplementedException]::new('IAppSettingsProvider.HasSettings') }
    # @{ Type = <int>; Data = <byte[]> }; değer yoksa $null.
    [hashtable] GetValue([string] $Package, [string] $Name) { throw [System.NotImplementedException]::new('IAppSettingsProvider.GetValue') }
    # Uygulama açıksa kapatılır (dosya kilitli olur). YAZMA.
    [void] SetValue([string] $Package, [string] $Name, [int] $Type, [byte[]] $Data) { throw [System.NotImplementedException]::new('IAppSettingsProvider.SetValue') }
    # Değer yoksa sessizce geçer. YAZMA.
    [void] DeleteValue([string] $Package, [string] $Name) { throw [System.NotImplementedException]::new('IAppSettingsProvider.DeleteValue') }
}

# Dosya sistemi güvenliği (veri klasörü %ProgramData%\FAI_WinOP: sahip, yeniden ayrıştırma noktası, izin). Yollar açılmış,
# '\' ayırıcılı gelir. Sahip / kural kimlikleri SID metni (yerelleştirilmiş ad değil). Kullanım: src/Core/DataGuard.ps1.
class IFileSecurityProvider {
    # Güvenilen sahipler: SYSTEM, BUILTIN\Administrators. Başka sahibin öğesi (yönetici olmayan kullanıcının bıraktığı
    # yedek oturumu / betik) kullanılmaz.
    static [string[]] $TrustedOwnerSid = @('S-1-5-18', 'S-1-5-32-544')

    # '' (yok) | 'File' | 'Directory'. Bağlantı hedefine bakılmaz: kırık bağlantı da var sayılır.
    [string] GetItemType([string] $Path) { throw [System.NotImplementedException]::new('IFileSecurityProvider.GetItemType') }
    # Junction, sembolik bağlantı ya da başka yeniden ayrıştırma noktası mı.
    [bool] IsReparsePoint([string] $Path) { throw [System.NotImplementedException]::new('IFileSecurityProvider.IsReparsePoint') }
    # Sahibin SID'i; okunamıyorsa boş metin.
    [string] GetOwnerSid([string] $Path) { throw [System.NotImplementedException]::new('IFileSecurityProvider.GetOwnerSid') }
    # Klasörün doğrudan öğelerinin (dosya + klasör) tam yolları, sıralı; bağlantıların içine girilmez.
    [string[]] GetEntries([string] $Directory) { throw [System.NotImplementedException]::new('IFileSecurityProvider.GetEntries') }
    # Klasörün izni: @{ Protected = <kalıtım kapalı>; Owner = <SID>; Rules = @(@{ Sid; Access = Full | Read | Write;
    # Deny = <bool>; Inherited = <bool>; Inherits = <alt klasör + dosyaya geçer> }) }. Read = okuma / çalıştırma;
    # Write = okumadan fazlası ama tam değil.
    [hashtable] GetAcl([string] $Path) { throw [System.NotImplementedException]::new('IFileSecurityProvider.GetAcl') }
    # Klasör oluşturur (üst klasörler dahil); varsa geçer. YAZMA.
    [void] CreateDirectory([string] $Path) { throw [System.NotImplementedException]::new('IFileSecurityProvider.CreateDirectory') }
    # Öğeyi taşır / yeniden adlandırır; bağlantının kendisi taşınır, hedefi değil. YAZMA.
    [void] MoveItem([string] $Path, [string] $Destination) { throw [System.NotImplementedException]::new('IFileSecurityProvider.MoveItem') }
    # Klasörün izni: kalıtım kapalı; SYSTEM + Administrators tam, ReaderSid'ler okuma (alt öğelere geçer); sahip
    # Administrators. Var olan alt öğeler yeni kalıtımı alır. YAZMA.
    [void] SetRestrictedAcl([string] $Path, [string[]] $ReaderSid) { throw [System.NotImplementedException]::new('IFileSecurityProvider.SetRestrictedAcl') }

    # Öğe var, bağlantı değil ve sahibi güvenilen SID'lerden biri.
    [bool] IsTrusted([string] $Path) {
        if ($this.GetItemType($Path) -eq '') { return $false }
        if ($this.IsReparsePoint($Path)) { return $false }
        return ([IFileSecurityProvider]::TrustedOwnerSid -contains $this.GetOwnerSid($Path))
    }
}

# Oturum kullanıcısı (salt okunur): yükseltilmiş süreç başka hesapla çalışıyorsa HKCU, masaüstü ve sabitlemeler o
# hesabın profiline gider. Kullanıcı = @{ Name = 'MAKINE\ad'; Sid = 'S-1-5-21-...' } (Sid okunamazsa boş metin).
# Kullanım: src/Cli.ps1 Test-FaiSessionUser.
class ISessionUserProvider {
    # Bu süreci çalıştıran hesap (UAC'de yükselten hesap).
    [hashtable] GetProcessUser() { throw [System.NotImplementedException]::new('ISessionUserProvider.GetProcessUser') }
    # Bu sürecin oturumundaki etkileşimli masaüstünün (kabuk) sahibi; bulunamazsa $null.
    [hashtable] GetSessionOwner() { throw [System.NotImplementedException]::new('ISessionUserProvider.GetSessionOwner') }
}

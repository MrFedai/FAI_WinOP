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
}

# Kullanıcıya soru. Onaylar yalnız buradan gelir (Unattended modda motor bunu hiç çağırmaz).
class IPromptProvider {
    # E/H sorusu (Caution). Evet ise $true.
    [bool] Confirm([string] $Message) { throw [System.NotImplementedException]::new('IPromptProvider.Confirm') }
    # Tam metin ister (Risk: 'EVET' yazılmalı). Yazılan Expected ile birebir eşitse $true.
    [bool] ConfirmExact([string] $Message, [string] $Expected) { throw [System.NotImplementedException]::new('IPromptProvider.ConfirmExact') }
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

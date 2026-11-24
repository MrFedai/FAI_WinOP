# Sağlayıcı arayüzleri. PowerShell 5.1'de 'interface' yok: arayüz = soyut taban sınıf; yöntemler
# NotImplementedException atar, gerçek (Windows*) ve sahte (Fake*) sağlayıcılar bunları ezer.
# Eylemler Windows'a yalnız bu arayüzler üzerinden dokunur (CLAUDE.md: doğrudan Set-ItemProperty vb. yok).

# Kayıt defteri. Yol biçimi: 'HKLM:\SOFTWARE\...' (HKLM, HKCU, HKCR, HKU, HKCC).
class IRegistryProvider {
    [bool] KeyExists([string] $Path) { throw [System.NotImplementedException]::new('IRegistryProvider.KeyExists') }
    [bool] ValueExists([string] $Path, [string] $Name) { throw [System.NotImplementedException]::new('IRegistryProvider.ValueExists') }
    # Değer yoksa $null.
    [object] GetValue([string] $Path, [string] $Name) { throw [System.NotImplementedException]::new('IRegistryProvider.GetValue') }
    # String | ExpandString | Binary | DWord | MultiString | QWord; değer yoksa boş metin.
    [string] GetValueKind([string] $Path, [string] $Name) { throw [System.NotImplementedException]::new('IRegistryProvider.GetValueKind') }
    # Anahtar yoksa oluşturur. YAZMA.
    [void] SetValue([string] $Path, [string] $Name, [object] $Value, [string] $Kind) { throw [System.NotImplementedException]::new('IRegistryProvider.SetValue') }
    # Değer yoksa sessizce geçer. YAZMA.
    [void] DeleteValue([string] $Path, [string] $Name) { throw [System.NotImplementedException]::new('IRegistryProvider.DeleteValue') }
}

# Servisler. StartType: Automatic | Manual | Disabled. Status: Running | Stopped.
class IServiceProvider {
    [bool] ServiceExists([string] $Name) { throw [System.NotImplementedException]::new('IServiceProvider.ServiceExists') }
    [string] GetStartType([string] $Name) { throw [System.NotImplementedException]::new('IServiceProvider.GetStartType') }
    [string] GetStatus([string] $Name) { throw [System.NotImplementedException]::new('IServiceProvider.GetStatus') }
    # YAZMA.
    [void] SetStartType([string] $Name, [string] $StartType) { throw [System.NotImplementedException]::new('IServiceProvider.SetStartType') }
    # YAZMA.
    [void] StartService([string] $Name) { throw [System.NotImplementedException]::new('IServiceProvider.StartService') }
    # YAZMA.
    [void] StopService([string] $Name) { throw [System.NotImplementedException]::new('IServiceProvider.StopService') }
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

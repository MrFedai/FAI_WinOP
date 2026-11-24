# Yürütme bağlamı: sağlayıcılar + çalışma kipi. Eylemler yalnız bunun üzerinden Windows'a dokunur.
class ExecutionContext {
    [IRegistryProvider] $Registry
    [IServiceManager] $Services
    [ITaskProvider] $Tasks
    [IAppxProvider] $Appx
    [IPackageProvider] $Packages
    [ISystemInfoProvider] $SystemInfo
    [IPromptProvider] $Prompt
    [IFileProvider] $Files
    [IShortcutProvider] $Shortcuts
    [IPowerProvider] $Power
    [IScriptHost] $Scripts
    [IAudioProvider] $Audio
    [ITimerResolutionProvider] $TimerResolution
    [IShellProvider] $Shell
    [IEdgeProvider] $Edge
    [IDesktopProvider] $Desktop
    [IImageProvider] $Images
    [IAppSettingsProvider] $AppSettings
    [ISystemControlProvider] $SystemControl
    [IMemoryAgentProvider] $MemoryAgent
    [IUpdateProvider] $Updates

    [BackupStore] $Backup
    [Logger] $Logger

    # -DryRun: hiçbir sağlayıcı yazma modunda çağrılmaz, yedek oturumu açılmaz, soru sorulmaz.
    [bool] $DryRun = $false
    # -Unattended: soru sorulmaz; Risk asla, Caution yalnız profilde autoConfirm varsa uygulanır.
    [bool] $Unattended = $false
    # Asla kaldırılmayacak Appx paketleri (-like kalıpları): sabit korunan liste (Get-FaiBloatProtected) + profildeki
    # uygulamaların Appx adları. Motor her çalıştırmada doldurur; Appx / AppxCleanup eylemleri bunlara dokunmaz.
    [string[]] $ProtectedAppx = @()
    # Yeniden başlatma sonrası aynı çalıştırmayı sürdürecek komut satırı (CLI doldurur, Faz 8). Boşsa yeniden başlatma
    # gerektiren eylem (ör. bekleyen güncellemeler) kullanıcıya "yeniden başlatıp tekrar çalıştırın" der.
    [string] $ResumeCommand = ''

    ExecutionContext() {
        $this.Logger = [Logger]::new()
    }
}

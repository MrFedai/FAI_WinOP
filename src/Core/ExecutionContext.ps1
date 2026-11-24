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

    [BackupStore] $Backup
    [Logger] $Logger

    # -DryRun: hiçbir sağlayıcı yazma modunda çağrılmaz, yedek oturumu açılmaz, soru sorulmaz.
    [bool] $DryRun = $false
    # -Unattended: soru sorulmaz; Risk asla, Caution yalnız profilde autoConfirm varsa uygulanır.
    [bool] $Unattended = $false

    ExecutionContext() {
        $this.Logger = [Logger]::new()
    }
}

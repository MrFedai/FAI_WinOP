# Yürütme bağlamı: sağlayıcılar + çalışma kipi. Eylemler yalnız bunun üzerinden Windows'a dokunur.
class ExecutionContext {
    [IRegistryProvider] $Registry
    [IServiceProvider] $Services
    [ITaskProvider] $Tasks
    [IAppxProvider] $Appx
    [IPackageProvider] $Packages
    [ISystemInfoProvider] $SystemInfo
    [IPromptProvider] $Prompt

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

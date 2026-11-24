# Gerçek (Windows*) sağlayıcılarla yürütme bağlamı kurar.

function New-FaiWindowsContext {
    <#
    .SYNOPSIS
        Bütün sağlayıcıları Windows* olan bir ExecutionContext döndürür.
    .PARAMETER BackupRoot
        Snapshot oturumlarının klasörü. Varsayılan %ProgramData%\FAI_WinOP\backup.
    .PARAMETER LogPath
        Günlük dosyası (boşsa yalnız bellekte).
    .PARAMETER ShowLog
        Günlük satırlarını konsola da basar.
    #>
    [CmdletBinding()]
    param(
        [string] $BackupRoot = (Join-Path $env:ProgramData 'FAI_WinOP\backup'),
        [string] $LogPath = '',
        [switch] $DryRun,
        [switch] $Unattended,
        [switch] $ShowLog
    )

    $ctx = [ExecutionContext]::new()
    $ctx.Registry = [WindowsRegistryProvider]::new()
    $ctx.Services = [WindowsServiceManager]::new()
    $ctx.Tasks = [WindowsTaskProvider]::new()
    $ctx.Appx = [WindowsAppxProvider]::new()
    $ctx.Packages = [WindowsPackageProvider]::new()
    $ctx.SystemInfo = [WindowsSystemInfoProvider]::new()
    $ctx.Prompt = [WindowsPromptProvider]::new()
    $ctx.Files = [WindowsFileProvider]::new()
    $ctx.Shortcuts = [WindowsShortcutProvider]::new()
    $ctx.Power = [WindowsPowerProvider]::new()
    $ctx.Scripts = [WindowsScriptHost]::new()
    $ctx.Audio = [WindowsAudioProvider]::new()
    $ctx.TimerResolution = [WindowsTimerResolutionProvider]::new()
    $ctx.Shell = [WindowsShellProvider]::new()
    $ctx.Edge = [WindowsEdgeProvider]::new()
    $ctx.Desktop = [WindowsDesktopProvider]::new()
    $ctx.Images = [WindowsImageProvider]::new()
    $ctx.AppSettings = [WindowsAppSettingsProvider]::new()
    $ctx.SystemControl = [WindowsSystemControlProvider]::new()
    $ctx.Backup = [BackupStore]::new($BackupRoot)
    $ctx.Logger = [Logger]::new($LogPath, (-not $ShowLog.IsPresent))
    $ctx.DryRun = $DryRun.IsPresent
    $ctx.Unattended = $Unattended.IsPresent
    return $ctx
}

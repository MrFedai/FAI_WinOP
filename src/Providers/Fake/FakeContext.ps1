# Fake sağlayıcılarla hazır bağlam kurar (testler ve Engine-Smoke). Üretim bundle'ına girmez.

function New-FakeContext {
    <#
    .SYNOPSIS
        Bütün sağlayıcıları Fake* olan bir ExecutionContext döndürür.
    .PARAMETER BackupRoot
        BackupStore kökü (testte TestDrive altında).
    .PARAMETER Answers
        FakePromptProvider'a sırayla verilecek yanıtlar (örn. 'E', 'EVET', 'H').
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $BackupRoot,
        [switch] $DryRun,
        [switch] $Unattended,
        [string[]] $Answers = @()
    )

    $ctx = [ExecutionContext]::new()
    $ctx.Registry = [FakeRegistryProvider]::new()
    $ctx.Services = [FakeServiceManager]::new()
    $ctx.Tasks = [FakeTaskProvider]::new()
    $ctx.Appx = [FakeAppxProvider]::new()
    $ctx.Packages = [FakePackageProvider]::new()
    $ctx.SystemInfo = [FakeSystemInfoProvider]::new()
    $files = [FakeFileProvider]::new()
    $ctx.Files = $files
    $ctx.Shortcuts = [FakeShortcutProvider]::new($files)
    $ctx.Power = [FakePowerProvider]::new()
    $ctx.Scripts = [FakeScriptHost]::new()
    $ctx.Audio = [FakeAudioProvider]::new()
    $ctx.TimerResolution = [FakeTimerResolutionProvider]::new()
    $prompt = [FakePromptProvider]::new()
    if ($Answers.Count -gt 0) { $prompt.Enqueue($Answers) }
    $ctx.Prompt = $prompt
    $ctx.Backup = [BackupStore]::new($BackupRoot)
    $ctx.DryRun = $DryRun.IsPresent
    $ctx.Unattended = $Unattended.IsPresent
    return $ctx
}

function Get-FakeWriteCount {
    <# .SYNOPSIS  Bağlamdaki bütün Fake sağlayıcıların toplam yazma çağrısı sayısı. #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true, Position = 0)] [ExecutionContext] $Ctx)

    return ([int]$Ctx.Registry.WriteCount + [int]$Ctx.Services.WriteCount + [int]$Ctx.Tasks.WriteCount +
        [int]$Ctx.Appx.WriteCount + [int]$Ctx.Packages.WriteCount + [int]$Ctx.Files.WriteCount +
        [int]$Ctx.Shortcuts.WriteCount + [int]$Ctx.Power.WriteCount + [int]$Ctx.Scripts.WriteCount +
        [int]$Ctx.Audio.WriteCount + [int]$Ctx.TimerResolution.WriteCount)
}

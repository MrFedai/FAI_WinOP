# Fake sağlayıcılarla hazır bağlam kurar (testler ve Engine-Smoke). Üretim bundle'ına girmez.

function New-FakeContext {
    <#
    .SYNOPSIS
        Bütün sağlayıcıları Fake* olan bir ExecutionContext döndürür.
    .PARAMETER BackupRoot
        BackupStore kökü (testte TestDrive altında).
    .PARAMETER Answers
        FakePromptProvider'a sırayla verilecek yanıtlar (örn. 'Y', 'YES', 'N').
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
    $ctx.Shell = [FakeShellProvider]::new()
    $ctx.Edge = [FakeEdgeProvider]::new()
    $ctx.Desktop = [FakeDesktopProvider]::new()
    $ctx.Images = [FakeImageProvider]::new($files)
    $ctx.AppSettings = [FakeAppSettingsProvider]::new()
    $ctx.SystemControl = [FakeSystemControlProvider]::new()
    $ctx.MemoryAgent = [FakeMemoryAgentProvider]::new()
    $ctx.Updates = [FakeUpdateProvider]::new()
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
        [int]$Ctx.Audio.WriteCount + [int]$Ctx.TimerResolution.WriteCount + [int]$Ctx.Shell.WriteCount + [int]$Ctx.Edge.WriteCount +
        [int]$Ctx.Desktop.WriteCount + [int]$Ctx.AppSettings.WriteCount + [int]$Ctx.SystemControl.WriteCount + [int]$Ctx.MemoryAgent.WriteCount + [int]$Ctx.Updates.WriteCount)
}

function Enable-FakeShellLayout {
    <#
    .SYNOPSIS
        Gezgin taklidi: Refresh('Shell') çağrısında "Start Layout" ilkesi kuruluysa (StartLayoutFile + LockedStartLayout=1)
        XML'deki görev çubuğu sabitlemelerini Taskband 'Favorites' ikilisine ve User Pinned\TaskBar kısayollarına yazar.
        Yazmalar Seed ile yapılır (aracın değil Windows'un yazması: yazma sayacına girmez).
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [ExecutionContext] $Ctx)

    $c = $Ctx
    # Not: GetNewClosure yalnız yakalanan değişkenleri görür; betik kapsamındaki Fai fonksiyonları çağrılamaz.
    $Ctx.Desktop.OnRefresh = {
        param($Kind)
        if ($Kind -ne 'Shell') { return }
        $pol = 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'
        if (-not $c.Registry.ValueExists($pol, 'StartLayoutFile') -or [int]$c.Registry.GetValue($pol, 'LockedStartLayout') -ne 1) { return }
        $xmlPath = [Environment]::ExpandEnvironmentVariables([string]$c.Registry.GetValue($pol, 'StartLayoutFile'))
        $doc = New-Object System.Xml.XmlDocument
        $doc.LoadXml([System.Text.Encoding]::UTF8.GetString($c.Files.ReadBytes($xmlPath)).TrimStart([char]0xFEFF))
        $dir = [Environment]::ExpandEnvironmentVariables('%APPDATA%\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar')
        $text = New-Object System.Text.StringBuilder
        foreach ($n in @($doc.SelectNodes("//*[local-name()='DesktopApp' or local-name()='UWA']"))) {
            $name = ''
            if ($n.GetAttribute('DesktopApplicationID') -eq 'Microsoft.Windows.Explorer') {
                $name = 'File Explorer.lnk'
                # Windows 11'deki gibi hedefsiz kabuk kısayolu; AppUserModelID dosyanın içinde (sahte: Description).
                $c.Shortcuts.Seed(($dir.TrimEnd('\') + '\' + $name), @{ Description = 'Microsoft.Windows.Explorer' })
            }
            elseif ($n.GetAttribute('DesktopApplicationLinkPath')) {
                $src = [Environment]::ExpandEnvironmentVariables($n.GetAttribute('DesktopApplicationLinkPath'))
                $sc = $c.Shortcuts.ReadShortcut($src)
                if ($null -eq $sc) { continue }
                $name = ($src -split '[\\/]')[-1]
                $c.Shortcuts.Seed(($dir.TrimEnd('\') + '\' + $name), $sc)
            }
            elseif ($n.GetAttribute('AppUserModelID')) { $name = $n.GetAttribute('AppUserModelID') }
            [void]$text.Append($name).Append([char]0)
        }
        $bytes = @([byte]0x00, [byte]0x14) + [System.Text.Encoding]::Unicode.GetBytes($text.ToString())
        $c.Registry.Seed('HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband', 'Favorites', [byte[]]$bytes, 'Binary')
    }.GetNewClosure()
}

function Initialize-FakeShellState {
    <#
    .SYNOPSIS
        Temiz Windows 11'e benzer görünüm durumu: StuckRects3 (otomatik gizleme kapalı), görev çubuğunda Gezgin + Edge +
        Store, Başlat'ta Chrome kısayolu, varsayılan hesap resimleri (beyaz), Not Defteri ayar dosyası.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [ExecutionContext] $Ctx)

    $stuck = New-Object byte[] 48
    $stuck[0] = 0x30
    $stuck[8] = 0x02
    $stuck[12] = 0x03
    $Ctx.Registry.Seed('HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3', 'Settings', $stuck, 'Binary')
    $dir = Expand-FaiPath '%APPDATA%\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar'
    $Ctx.Shortcuts.Seed(($dir.TrimEnd('\') + '\' + 'File Explorer.lnk'), @{ TargetPath = (Expand-FaiPath '%SystemRoot%\explorer.exe') })
    $Ctx.Shortcuts.Seed(($dir.TrimEnd('\') + '\' + 'Microsoft Edge.lnk'), @{ TargetPath = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe' })
    $fav = [System.Text.Encoding]::Unicode.GetBytes("File Explorer.lnk`0Microsoft Edge.lnk`0Microsoft.WindowsStore_8wekyb3d8bbwe!App`0")
    $Ctx.Registry.Seed('HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband', 'Favorites', [byte[]](@([byte]0, [byte]0x14) + $fav), 'Binary')
    $Ctx.Registry.Seed('HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband', 'FavoritesVersion', 3, 'DWord')
    $Ctx.Shortcuts.Seed((Expand-FaiPath '%ProgramData%\Microsoft\Windows\Start Menu\Programs\Google Chrome.lnk'), @{ TargetPath = 'C:\Program Files\Google\Chrome\Application\chrome.exe' })
    $pics = Expand-FaiPath '%ProgramData%\Microsoft\User Account Pictures'
    $Ctx.Files.Seed(($pics.TrimEnd('\') + '\' + 'user.png'), [FakeImageProvider]::Encode(448, 448, '0078D4'))
    $Ctx.Files.Seed(($pics.TrimEnd('\') + '\' + 'guest.bmp'), [FakeImageProvider]::Encode(448, 448, '0078D4'))
    $Ctx.Files.SeedText(($pics.TrimEnd('\') + '\' + 'readme.txt'), 'not an image')
    $now = [System.BitConverter]::GetBytes([long]133000000000000000)
    $Ctx.AppSettings.Seed('Microsoft.WindowsNotepad_8wekyb3d8bbwe', 'OpenFile', 100000004, [byte[]](@([byte]0, [byte]0, [byte]0, [byte]0) + $now))
    $Ctx.AppSettings.Seed('Microsoft.WindowsNotepad_8wekyb3d8bbwe', 'GhostFile', 100000011, [byte[]](@([byte]1) + $now))
    Enable-FakeShellLayout -Ctx $Ctx
}

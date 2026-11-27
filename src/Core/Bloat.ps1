# Bloatware yardımcıları (Faz 5): asla kaldırılmayacak Appx paketleri ve bloat.persistence'ın açılış görevi betiği.
#
# Kara liste veri: tweaks/bloat/remove.psd1 (Appx eylemleri, joker yok) ve tweaks/bloat/persistence.psd1 (aynı adlar).
# Korunan liste burada, -like kalıplarıyla: korumada joker GÜVENLİ taraftadır (fazla korur, fazla silmez).
# Motor her çalıştırmada ExecutionContext.ProtectedAppx'i bu liste + profildeki uygulamaların Appx adlarıyla doldurur;
# Appx ve AppxCleanup eylemleri eşleşen pakete dokunmaz. Birim testi kara listenin bu listeyle kesişmediğini denetler.
# Gerekçeler Ultimate'teki "breaks ..." notlarından ve Windows 11 bileşen bağımlılıklarından.

function Get-FaiBloatProtected {
    <# .SYNOPSIS  Korunan Appx kalıbı → gerekçe (sıralı). #>
    $p = [ordered]@{}
    # Kullanıcının istekleri
    $p['Microsoft.WindowsStore'] = 'Microsoft Store (msstore installs: WhatsApp, Spotify)'
    $p['Microsoft.StorePurchaseApp'] = 'Store purchases / licenses'
    $p['Microsoft.DesktopAppInstaller'] = 'winget (every app install depends on it)'
    $p['Microsoft.ScreenSketch'] = 'Snipping Tool'
    $p['*WhatsApp*'] = 'WhatsApp (profile app)'
    $p['*Claude*'] = 'Claude (profile app)'
    # Kabuk ve sistem bileşenleri (kaldırılırsa görev çubuğu / Başlat / Ayarlar / oturum açma bozulur)
    $p['*CBS*'] = 'Windows shell component packages (Ultimate: breaks File Explorer)'
    $p['MicrosoftWindows.Client.*'] = 'Windows client shell components'
    $p['Microsoft.Windows.ShellExperienceHost'] = 'taskbar / notification area (Ultimate note)'
    $p['Microsoft.Windows.StartMenuExperienceHost'] = 'Start menu (Ultimate note)'
    $p['windows.immersivecontrolpanel'] = 'Settings app (Ultimate note)'
    $p['Microsoft.Windows.Search'] = 'Windows Search'
    $p['Microsoft.Windows.CloudExperienceHost'] = 'sign-in / OOBE'
    $p['Microsoft.AAD.BrokerPlugin'] = 'Microsoft / work account sign-in'
    $p['Microsoft.AccountsControl'] = 'account management'
    $p['Microsoft.LockApp'] = 'lock screen'
    $p['Microsoft.CredDialogHost'] = 'credential dialog'
    $p['Microsoft.Win32WebViewHost'] = 'desktop web view host'
    $p['Microsoft.Windows.ContentDeliveryManager'] = 'lock screen / Start infrastructure (suggestions are turned off by bloat.persistence)'
    $p['Microsoft.Windows.Apprep.ChxApp'] = 'SmartScreen'
    $p['Microsoft.SecHealthUI'] = 'Windows Security (Defender) UI (Ultimate note)'
    $p['Microsoft.Windows.SecHealthUI'] = 'Windows Security (old name)'
    $p['Microsoft.Windows.ParentalControls'] = 'Family Safety system component'
    $p['Microsoft.Windows.PeopleExperienceHost'] = 'shell component'
    $p['Microsoft.Windows.PinningConfirmationDialog'] = 'pin confirmation (Phase 6 taskbar)'
    $p['Microsoft.Windows.CapturePicker'] = 'screen capture picker'
    $p['Microsoft.Windows.XGpuEjectDialog'] = 'external GPU eject'
    $p['Microsoft.Windows.AssignedAccessLockApp'] = 'assigned access lock'
    $p['Microsoft.Windows.OOBENetworkCaptivePortal'] = 'network sign-in during setup'
    $p['Microsoft.Windows.OOBENetworkConnectionFlow'] = 'network connection during setup'
    $p['Microsoft.Windows.NarratorQuickStart'] = 'Narrator'
    $p['Microsoft.ECApp'] = 'eye control (accessibility)'
    $p['Microsoft.BioEnrollment'] = 'Windows Hello enrollment'
    $p['Microsoft.Windows.PrintQueueActionCenter'] = 'print queue'
    $p['Microsoft.WindowsAppRuntime*'] = 'Windows App SDK runtime (apps depend on it)'
    $p['Microsoft.UI.Xaml*'] = 'WinUI framework package (apps depend on it)'
    $p['Microsoft.VCLibs*'] = 'C++ runtime framework package'
    $p['Microsoft.NET.Native*'] = '.NET Native framework package'
    $p['Microsoft.Services.Store.Engagement'] = 'Store framework package'
    # Edge yalnız bloat.edge-remove ile (WebView2 korunarak) kaldırılır
    $p['Microsoft.MicrosoftEdge*'] = 'Edge: managed by bloat.edge-remove (WebView2 is kept)'
    $p['*WebView*'] = 'WebView2 Runtime (WhatsApp and many apps depend on it)'
    # Dosya Gezgini küçük resimleri ve kodekler (Ultimate: breaks file explorer)
    $p['Microsoft.AV1VideoExtension'] = 'AV1 codec'
    $p['Microsoft.AVCEncoderVideoExtension'] = 'AVC encoder'
    $p['Microsoft.HEIFImageExtension'] = 'HEIF images (thumbnails)'
    $p['Microsoft.HEVCVideoExtension'] = 'HEVC codec'
    $p['Microsoft.MPEG2VideoExtension'] = 'MPEG-2 codec'
    $p['Microsoft.RawImageExtension'] = 'RAW images (thumbnails)'
    $p['Microsoft.VP9VideoExtensions'] = 'VP9 codec'
    $p['Microsoft.WebMediaExtensions'] = 'web media codecs'
    $p['Microsoft.WebpImageExtension'] = 'WebP images (thumbnails)'
    # Temel araçlar
    $p['Microsoft.Windows.Photos'] = 'Photos (default image viewer)'
    $p['Microsoft.Paint'] = 'Paint'
    $p['Microsoft.WindowsNotepad'] = 'Notepad (ui.notepad-settings)'
    $p['Microsoft.WindowsTerminal'] = 'Terminal (default console)'
    $p['Microsoft.WindowsCalculator'] = 'Calculator'
    $p['Microsoft.ZuneMusic'] = 'Media Player (default audio / video player)'
    # Sürücü panelleri (Faz 7 grafik ayarları)
    $p['NVIDIACorp.NVIDIAControlPanel'] = 'NVIDIA Control Panel (Ultimate note)'
    $p['AdvancedMicroDevicesInc-2.AMDRadeonSoftware'] = 'AMD Radeon Software'
    $p['AppUp.IntelGraphicsExperience'] = 'Intel graphics panel'
    $p['RealtekSemiconductorCorp.RealtekAudioControl'] = 'Realtek audio panel'
    # Oyun kimliği (Steam dışı oyunlar, Game Pass, Xbox hesabı isteyen oyunlar)
    $p['Microsoft.XboxIdentityProvider'] = 'Xbox identity (game sign-ins)'
    $p['Microsoft.Xbox.TCUI'] = 'Xbox in-game UI'
    return $p
}

function Get-FaiBloatUnprotected {
    <#
    .SYNOPSIS  Korunan bir kalıba uyduğu hâlde kaldırılabilen paketler (birebir ad → gerekçe).
    .NOTES     İstisna kalıbı daraltmaktan güvenli: kalıp yeni kabuk bileşenlerini de korumaya devam eder.
    #>
    $u = [ordered]@{}
    # ui.widgets-off: Dsh ilkesi UCPD yüzünden yazılamıyor; pano yalnız bu paketle gelir, kabuk ona bağlı değil.
    $u['MicrosoftWindows.Client.WebExperience'] = 'Widgets board: removed by ui.widgets-off'
    return $u
}

function Test-FaiAppxProtected {
    <# .SYNOPSIS  Paket adı korunan kalıplardan birine uyuyor mu (büyük / küçük harf duyarsız; Get-FaiBloatUnprotected hariç). #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)] [string] $Name,
        [Parameter(Position = 1)] [AllowEmptyCollection()] [string[]] $Patterns = @()
    )
    foreach ($exempt in @((Get-FaiBloatUnprotected).Keys)) {
        if ($Name -eq $exempt) { return $false }
    }
    foreach ($pattern in $Patterns) {
        if ($pattern -and $Name -like $pattern) { return $true }
    }
    return $false
}

function Get-FaiBloatCleanupScript {
    <#
    .SYNOPSIS
        bloat.persistence görevinin betiği: Windows yapı numarası (CurrentBuild.UBR) değiştiyse listedeki paketleri bütün
        kullanıcılardan ve provisioned kopyadan yeniden kaldırır. Büyük güncelleme kaldırılan uygulamaları geri getirir.
    .PARAMETER Names
        Kaldırılacak paket adları (korunanlar önceden süzülmüş, birebir ad).
    .PARAMETER StateDirectory
        Durum ve günlük klasörü (betik içinde %ProgramData% açılır).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [AllowEmptyCollection()] [string[]] $Names,
        [string] $StateDirectory = '%ProgramData%\FAI_WinOP'
    )
    foreach ($n in $Names) {
        if ($n -notmatch '^[A-Za-z0-9][A-Za-z0-9.\-]*$') { throw "Package name must be exact: $n" }
    }
    $quoted = (@($Names | ForEach-Object { "'" + $_ + "'" }) -join ",`r`n    ")
    $lines = @(
        '# FAI_WinOP bloat.persistence: at startup, removes the listed packages again if the Windows build changed.'
        '# Generated automatically; do not edit. To remove, run FAI_WinOP -Undo (the task and script go together).'
        '$ErrorActionPreference = ''Continue'''
        '$names = @('
        "    $quoted"
        ')'
        ('$dir = [Environment]::ExpandEnvironmentVariables(''{0}'')' -f $StateDirectory)
        '$stamp = Join-Path $dir ''BloatCleanup.build'''
        '$log = Join-Path $dir ''BloatCleanup.log'''
        '$cv = Get-ItemProperty -LiteralPath ''HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'''
        '$build = ''{0}.{1}'' -f $cv.CurrentBuild, $cv.UBR'
        'if ((Test-Path -LiteralPath $stamp) -and ([string](Get-Content -LiteralPath $stamp -Raw)).Trim() -eq $build) { return }'
        'function Write-CleanupLog([string] $Text) { Add-Content -LiteralPath $log -Value (''{0:yyyy-MM-dd HH:mm:ss} {1}'' -f (Get-Date), $Text) -Encoding UTF8 }'
        'Write-CleanupLog "build ${build}: cleanup started"'
        '$failed = $false'
        '$provisioned = @()'
        'try { $provisioned = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop) }'
        'catch { $failed = $true; Write-CleanupLog "could not get provisioned list: $($_.Exception.Message)" }'
        'foreach ($n in $names) {'
        '    foreach ($p in @($provisioned | Where-Object { $_.DisplayName -eq $n })) {'
        '        try { Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction Stop | Out-Null; Write-CleanupLog "provisioned removed: $n" }'
        '        catch { $failed = $true; Write-CleanupLog "provisioned not removed: ${n}: $($_.Exception.Message)" }'
        '    }'
        '    foreach ($p in @(Get-AppxPackage -AllUsers -Name $n -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $n })) {'
        '        try { Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Stop; Write-CleanupLog "removed: $n" }'
        '        catch { $failed = $true; Write-CleanupLog "not removed: ${n}: $($_.Exception.Message)" }'
        '    }'
        '}'
        'if ($failed) { Write-CleanupLog "build ${build}: cleanup finished with errors: stamp not written, will retry at next startup" }'
        'else {'
        '    Set-Content -LiteralPath $stamp -Value $build -Encoding ASCII'
        '    Write-CleanupLog "build ${build}: cleanup finished"'
        '}'
    )
    return (($lines -join "`r`n") + "`r`n")
}

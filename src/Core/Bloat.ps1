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
    $p['Microsoft.WindowsStore'] = 'Microsoft Store (msstore kurulumları: WhatsApp, Spotify)'
    $p['Microsoft.StorePurchaseApp'] = 'Store satın alma / lisans'
    $p['Microsoft.DesktopAppInstaller'] = 'winget (bütün uygulama kurulumu buna bağlı)'
    $p['Microsoft.ScreenSketch'] = 'Ekran Alıntısı Aracı'
    $p['*WhatsApp*'] = 'WhatsApp (profil uygulaması)'
    $p['*Claude*'] = 'Claude (profil uygulaması)'
    # Kabuk ve sistem bileşenleri (kaldırılırsa görev çubuğu / Başlat / Ayarlar / oturum açma bozulur)
    $p['*CBS*'] = 'Windows kabuk bileşen paketleri (Ultimate: Dosya Gezgini bozulur)'
    $p['MicrosoftWindows.Client.*'] = 'Windows istemci kabuk bileşenleri'
    $p['Microsoft.Windows.ShellExperienceHost'] = 'görev çubuğu / bildirim alanı (Ultimate notu)'
    $p['Microsoft.Windows.StartMenuExperienceHost'] = 'Başlat menüsü (Ultimate notu)'
    $p['windows.immersivecontrolpanel'] = 'Ayarlar uygulaması (Ultimate notu)'
    $p['Microsoft.Windows.Search'] = 'Windows araması'
    $p['Microsoft.Windows.CloudExperienceHost'] = 'oturum açma / OOBE'
    $p['Microsoft.AAD.BrokerPlugin'] = 'Microsoft / iş hesabı oturumu'
    $p['Microsoft.AccountsControl'] = 'hesap yönetimi'
    $p['Microsoft.LockApp'] = 'kilit ekranı'
    $p['Microsoft.CredDialogHost'] = 'kimlik bilgisi penceresi'
    $p['Microsoft.Win32WebViewHost'] = 'masaüstü web görünümü barındırıcısı'
    $p['Microsoft.Windows.ContentDeliveryManager'] = 'kilit ekranı / Başlat altyapısı (öneriler bloat.persistence ile kapatılır)'
    $p['Microsoft.Windows.Apprep.ChxApp'] = 'SmartScreen'
    $p['Microsoft.SecHealthUI'] = 'Windows Güvenliği (Defender) arayüzü (Ultimate notu)'
    $p['Microsoft.Windows.SecHealthUI'] = 'Windows Güvenliği (eski ad)'
    $p['Microsoft.Windows.ParentalControls'] = 'Aile güvenliği sistem bileşeni'
    $p['Microsoft.Windows.PeopleExperienceHost'] = 'kabuk bileşeni'
    $p['Microsoft.Windows.PinningConfirmationDialog'] = 'sabitleme onayı (Faz 6 görev çubuğu)'
    $p['Microsoft.Windows.CapturePicker'] = 'ekran yakalama seçici'
    $p['Microsoft.Windows.XGpuEjectDialog'] = 'harici GPU çıkarma'
    $p['Microsoft.Windows.AssignedAccessLockApp'] = 'atanmış erişim kilidi'
    $p['Microsoft.Windows.OOBENetworkCaptivePortal'] = 'kurulumda ağ girişi'
    $p['Microsoft.Windows.OOBENetworkConnectionFlow'] = 'kurulumda ağ bağlantısı'
    $p['Microsoft.Windows.NarratorQuickStart'] = 'Ekran Okuyucu'
    $p['Microsoft.ECApp'] = 'göz denetimi (erişilebilirlik)'
    $p['Microsoft.BioEnrollment'] = 'Windows Hello kaydı'
    $p['Microsoft.Windows.PrintQueueActionCenter'] = 'yazdırma kuyruğu'
    $p['Microsoft.WindowsAppRuntime*'] = 'Windows App SDK çalışma zamanı (uygulamalar bağımlı)'
    $p['Microsoft.UI.Xaml*'] = 'WinUI çerçeve paketi (uygulamalar bağımlı)'
    $p['Microsoft.VCLibs*'] = 'C++ çalışma zamanı çerçeve paketi'
    $p['Microsoft.NET.Native*'] = '.NET Native çerçeve paketi'
    $p['Microsoft.Services.Store.Engagement'] = 'Store çerçeve paketi'
    # Edge yalnız bloat.edge-remove ile (WebView2 korunarak) kaldırılır
    $p['Microsoft.MicrosoftEdge*'] = 'Edge: bloat.edge-remove yönetir (WebView2 korunur)'
    $p['*WebView*'] = 'WebView2 Runtime (WhatsApp ve birçok uygulama bağımlı)'
    # Dosya Gezgini küçük resimleri ve kodekler (Ultimate: breaks file explorer)
    $p['Microsoft.AV1VideoExtension'] = 'AV1 kodeği'
    $p['Microsoft.AVCEncoderVideoExtension'] = 'AVC kodlayıcı'
    $p['Microsoft.HEIFImageExtension'] = 'HEIF görüntü (küçük resimler)'
    $p['Microsoft.HEVCVideoExtension'] = 'HEVC kodeği'
    $p['Microsoft.MPEG2VideoExtension'] = 'MPEG-2 kodeği'
    $p['Microsoft.RawImageExtension'] = 'RAW görüntü (küçük resimler)'
    $p['Microsoft.VP9VideoExtensions'] = 'VP9 kodeği'
    $p['Microsoft.WebMediaExtensions'] = 'web medya kodekleri'
    $p['Microsoft.WebpImageExtension'] = 'WebP görüntü (küçük resimler)'
    # Temel araçlar
    $p['Microsoft.Windows.Photos'] = 'Fotoğraflar (varsayılan görüntüleyici)'
    $p['Microsoft.Paint'] = 'Paint'
    $p['Microsoft.WindowsNotepad'] = 'Not Defteri (ui.notepad-settings)'
    $p['Microsoft.WindowsTerminal'] = 'Terminal (varsayılan konsol)'
    $p['Microsoft.WindowsCalculator'] = 'Hesap Makinesi'
    $p['Microsoft.ZuneMusic'] = 'Medya Oynatıcı (varsayılan ses / video oynatıcı)'
    # Sürücü panelleri (Faz 7 grafik ayarları)
    $p['NVIDIACorp.NVIDIAControlPanel'] = 'NVIDIA Denetim Masası (Ultimate notu)'
    $p['AdvancedMicroDevicesInc-2.AMDRadeonSoftware'] = 'AMD Radeon yazılımı'
    $p['AppUp.IntelGraphicsExperience'] = 'Intel grafik paneli'
    $p['RealtekSemiconductorCorp.RealtekAudioControl'] = 'Realtek ses paneli'
    # Oyun kimliği (Steam dışı oyunlar, Game Pass, Xbox hesabı isteyen oyunlar)
    $p['Microsoft.XboxIdentityProvider'] = 'Xbox kimliği (oyun girişleri)'
    $p['Microsoft.Xbox.TCUI'] = 'Xbox oyun içi arayüz'
    return $p
}

function Get-FaiBloatUnprotected {
    <#
    .SYNOPSIS  Korunan bir kalıba uyduğu hâlde kaldırılabilen paketler (birebir ad → gerekçe).
    .NOTES     İstisna kalıbı daraltmaktan güvenli: kalıp yeni kabuk bileşenlerini de korumaya devam eder.
    #>
    $u = [ordered]@{}
    # ui.widgets-off: Dsh ilkesi UCPD yüzünden yazılamıyor; pano yalnız bu paketle gelir, kabuk ona bağlı değil.
    $u['MicrosoftWindows.Client.WebExperience'] = 'Pencere öğeleri (Widgets) panosu: ui.widgets-off kaldırır'
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
        if ($n -notmatch '^[A-Za-z0-9][A-Za-z0-9.\-]*$') { throw "Paket adı birebir olmalı: $n" }
    }
    $quoted = (@($Names | ForEach-Object { "'" + $_ + "'" }) -join ",`r`n    ")
    $lines = @(
        '# FAI_WinOP bloat.persistence: açılışta, Windows yapısı değiştiyse kaldırılan paketleri yeniden kaldırır.'
        '# Otomatik üretildi; elle düzenlemeyin. Kaldırmak için FAI_WinOP -Undo (görev ve betik birlikte gider).'
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
        'Write-CleanupLog "yapı ${build}: temizlik başladı"'
        '$failed = $false'
        '$provisioned = @()'
        'try { $provisioned = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop) }'
        'catch { $failed = $true; Write-CleanupLog "provisioned liste alınamadı: $($_.Exception.Message)" }'
        'foreach ($n in $names) {'
        '    foreach ($p in @($provisioned | Where-Object { $_.DisplayName -eq $n })) {'
        '        try { Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction Stop | Out-Null; Write-CleanupLog "provisioned kaldırıldı: $n" }'
        '        catch { $failed = $true; Write-CleanupLog "provisioned kaldırılamadı: ${n}: $($_.Exception.Message)" }'
        '    }'
        '    foreach ($p in @(Get-AppxPackage -AllUsers -Name $n -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $n })) {'
        '        try { Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Stop; Write-CleanupLog "kaldırıldı: $n" }'
        '        catch { $failed = $true; Write-CleanupLog "kaldırılamadı: ${n}: $($_.Exception.Message)" }'
        '    }'
        '}'
        'if ($failed) { Write-CleanupLog "yapı ${build}: temizlik bitti, hata var: damga yazılmadı, sonraki açılışta yinelenir" }'
        'else {'
        '    Set-Content -LiteralPath $stamp -Value $build -Encoding ASCII'
        '    Write-CleanupLog "yapı ${build}: temizlik bitti"'
        '}'
    )
    return (($lines -join "`r`n") + "`r`n")
}

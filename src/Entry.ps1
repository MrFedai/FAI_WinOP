<#
.SYNOPSIS
    FAI_WinOP — Windows 11 için profil odaklı optimizer. Profil yoksa etkileşimli menü açılır.

.DESCRIPTION
    Önerilen kurulum (SHA-256 doğrulamalı, yönetici PowerShell'de):
        & ([scriptblock]::Create((irm https://github.com/MrFedai/FAI_WinOP/releases/latest/download/get.ps1))) -Profile fedai -DryRun
    Yönetici değilse kendini yükseltir (UAC). Bu dosya build/Bundle.ps1 ile üretilir; kaynak: src/Entry.ps1.

.PARAMETER FaiProfile
    -Profile: gömülü profil adı (fedai), .json yolu ya da https URL. Verilmezse menü.
.PARAMETER DryRun
    Önizleme: hiçbir şey değişmez, soru sorulmaz.
.PARAMETER Unattended
    Soru sorulmaz: Risk hiç, Caution yalnız profildeki autoConfirm ile uygulanır.
.PARAMETER Undo
    Geri alınmamış son oturumu (ya da -Session ile verileni) geri alır.
.PARAMETER Session
    -Undo ile: oturum kimliği. -Profile / -Only ile: yarıda kalan bu oturuma devam (yeniden başlatma sonrası devam
    komutu kendisi ekler; güvenilmez ya da geri alınmış oturuma yazılmaz, yeni oturum açılır).
.PARAMETER SkipFailed
    -Undo ile: geri alınamayan kayıtları atlar ve oturumu kapatır (atlananlar raporda). Verilmezse oturum açık kalır,
    yeniden -Undo yalnız kalanları dener.
.PARAMETER Only
    Yalnız bu tweak'ler (virgüllü). Profil yoksa yalnız bunlar çalışır; araç tweak'lerine (Tool) izin verir.
.PARAMETER Skip
    Profilden çıkarılacak tweak / uygulama kimlikleri (uygulama: app.<id>).
.PARAMETER UpdatesOn
    Windows Update duraklatmasını kaldırır.
.PARAMETER UpdatesOff
    Windows Update'i 365 gün duraklatır.
.PARAMETER ExportProfile
    Bu makinenin durumunu profil olarak yazar: ad (Belgeler\FAI_WinOP\<ad>.json) ya da .json yolu.
.PARAMETER ExportLayout
    Görev çubuğu / Başlat / masaüstü düzenini profilin layout bölümüne yazar (-Profile .json yolu ya da
    Belgeler\FAI_WinOP\layout.json).
.PARAMETER Version
    Bu sürümü (vX.Y.Z) GitHub sürümünden indirir, SHA-256 doğrular ve onunla çalıştırır.
.PARAMETER List
    Tweak'leri, uygulamaları ve gömülü profilleri listeler.

.EXAMPLE
    .\install.ps1 -Profile fedai -DryRun
.EXAMPLE
    .\install.ps1 -Undo
.EXAMPLE
    .\install.ps1 -Only refresh.reboot-to-bios
#>
[CmdletBinding()]
param(
    # -Profile ($PROFILE otomatik değişkenini ezmemek için değişken adı FaiProfile).
    [Alias('Profile')] [string] $FaiProfile = '',
    [switch] $DryRun,
    [switch] $Unattended,
    [switch] $Undo,
    [string] $Session = '',
    [switch] $SkipFailed,
    [string[]] $Only = @(),
    [string[]] $Skip = @(),
    [switch] $UpdatesOn,
    [switch] $UpdatesOff,
    [string] $ExportProfile = '',
    [switch] $ExportLayout,
    [string] $Version = '',
    [switch] $List
)

# Nokta-kaynak (birim testleri, Load-Bundle) yalnız tanımları yükler, çalıştırmaz.
if ($MyInvocation.InvocationName -ne '.') {
    $faiExitCode = Invoke-FaiCli -Bound $PSBoundParameters -ScriptPath $PSCommandPath
    # Dosya olarak çalıştıysa süreç çıkış kodu; irm | iex'te exit kullanıcının penceresini kapatırdı.
    if ($PSCommandPath) { exit $faiExitCode }
}

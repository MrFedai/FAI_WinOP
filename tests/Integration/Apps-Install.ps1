<#
.SYNOPSIS
    Katalogdaki uygulamaları GERÇEK winget ile kurar ve kurulum sonrası düzeni doğrular (Faz 4 kabulü: masaüstünde yeni
    kısayol kalmıyor). Katalogdaki tahmini adları (Run değeri, Başlat klasörü...) doğrulamak için keşif dökümü basar.

.DESCRIPTION
    Üretim bundle'ını yükler, gerçek sağlayıcılarla (New-FaiWindowsContext, -Unattended) şu adımları koşar:
      1. Önce: masaüstleri (.lnk), Run anahtarları, Başlangıç klasörleri, Başlat > Programlar klasörleri kaydedilir.
      2. Profil (yalnız apps) uygulanır; her uygulama kurulur + düzen uygulanır.
      3. Doğrulama: masaüstünde ÖNCE olmayan .lnk kalmamalı (HATA); ikinci çalıştırma her uygulama için ZATEN UYGUN olmalı.
      4. Keşif: kurulumla gelen Run değerleri, Başlangıç kısayolları, Başlat klasörleri ve StartupApproved durumları
         basılır → apps/catalog.json'daki adlar bununla karşılaştırılır (docs/APPS.md "doğrulanacak" sütunu).
      5. -Undo verildiyse: motor -Undo → bu çalıştırmada kurulanlar kaldırılır.
    msstore kaynağı yoksa (sunucu runner'ı) Store uygulamaları ATLA.

    GÜVENLİK: yalnız GitHub Actions'ta (GITHUB_ACTIONS=true) ya da Windows Sandbox'ta çalışır (Hyper-V VM'de -Force);
    gerçek makinede -Force olmadan hiçbir şeye dokunmadan 2 ile çıkar. Yönetici gerekir. Süre: uygulama başına ~0,5-3 dk.
    Sonuç: 0 başarılı, 1 HATA.

.PARAMETER Only
    Yalnız bu uygulama kimlikleri (ör. -Only chrome,spotify). Varsayılan: katalogdaki hepsi.

.PARAMETER Undo
    Sonunda -Undo ile geri al (kurulanları kaldır).

.PARAMETER Force
    CI / Sandbox dışında da çalıştır (Hyper-V test VM'i için; gerçek makinede ÖNERİLMEZ).

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\Integration\Apps-Install.ps1 -Undo
#>
[CmdletBinding()]
param(
    [string[]] $Only = @(),
    [switch] $Undo,
    [switch] $Force,
    [string] $BundlePath
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not $BundlePath) { $BundlePath = Join-Path (Join-Path $repoRoot 'dist') 'install.ps1' }

# --- Güvenlik kapısı -----------------------------------------------------------------------------------------------
$inCi = $env:GITHUB_ACTIONS -eq 'true'
$inSandbox = $env:USERNAME -eq 'WDAGUtilityAccount'
if (-not ($inCi -or $inSandbox -or $Force.IsPresent)) {
    Write-Host 'Apps-Install: gerçek uygulama kurar; yalnız GitHub Actions, Windows Sandbox ya da (-Force ile) test VM''inde.' -ForegroundColor Yellow
    Write-Host '  Çalıştırılmadı.' -ForegroundColor Yellow
    exit 2
}
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Apps-Install: yönetici olarak çalıştırılmalı.' -ForegroundColor Red
    exit 1
}
if (-not (Test-Path -LiteralPath $BundlePath -PathType Leaf)) { Write-Host '  Bundle yok; önce build\Bundle.ps1' -ForegroundColor Red; exit 1 }
# Bundle'ın param bloğu (install.ps1 -Only / -Undo ...) nokta-kaynakta aynı adlı değişkenleri varsayılana çeker.
$appsOnly = $Only
$appsUndo = $Undo.IsPresent
. $BundlePath
$Only = $appsOnly
$Undo = [System.Management.Automation.SwitchParameter]::new($appsUndo)

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$failed = 0
function Fail([string] $Message) { $script:failed++; Write-Host ("  HATA  {0}" -f $Message) -ForegroundColor Red }

$catalog = Import-FaiAppCatalog -Path (Join-Path (Join-Path $repoRoot 'apps') 'catalog.json')
$ctx = New-FaiWindowsContext -BackupRoot (Join-Path $env:TEMP 'FAI_WinOP_AppsTest\backup') -Unattended -ShowLog

$ids = @($catalog.Keys | Sort-Object)
if ($Only.Count -gt 0) { $ids = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
$unknown = @($ids | Where-Object { -not $catalog.ContainsKey($_) })
if ($unknown.Count -gt 0) { Write-Host ("Katalogda yok: {0}" -f ($unknown -join ', ')) -ForegroundColor Red; exit 1 }

$sources = (& winget.exe source list --disable-interactivity 2>&1 | Out-String)
$hasStore = $sources -match '(?im)^\s*msstore\b'
$selected = New-Object 'System.Collections.Generic.List[string]'
foreach ($id in $ids) {
    if ($catalog[$id]['source'] -eq 'msstore' -and -not $hasStore) { Write-Host ("  ATLA  {0}: msstore kaynağı yok" -f $id) -ForegroundColor Yellow; continue }
    $selected.Add($id)
}

# --- durum dökümü --------------------------------------------------------------------------------------------------
function Get-Inventory {
    $inv = @{ Desktop = @(); Run = @(); Startup = @(); Programs = @(); Approved = @() }
    foreach ($f in @('DesktopDirectory', 'CommonDesktopDirectory')) {
        $inv.Desktop += @($ctx.Files.ListFiles($ctx.Files.GetKnownFolder($f)) | Where-Object { $_ -like '*.lnk' })
    }
    foreach ($src in [AppAction]::RunSources()) {
        $inv.Run += @($ctx.Registry.GetValueNames($src['Run']) | ForEach-Object { '{0} :: {1}' -f $src['Run'], $_ })
        foreach ($n in $ctx.Registry.GetValueNames($src['Approved'])) {
            $b = [byte[]]@($ctx.Registry.GetValue($src['Approved'], $n))
            $inv.Approved += ('{0} :: {1} = {2:X2}' -f $src['Approved'], $n, $b[0])
        }
    }
    foreach ($sf in [AppAction]::StartupFolders()) {
        $inv.Startup += @($ctx.Files.ListFiles($ctx.Files.GetKnownFolder($sf['Folder'])) | Where-Object { $_ -notlike '*desktop.ini' })
    }
    foreach ($root in @('Programs', 'CommonPrograms')) {
        $dir = $ctx.Files.GetKnownFolder($root)
        $inv.Programs += @(Get-ChildItem -LiteralPath $dir -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
    }
    return $inv
}

function Show-New([string] $Title, [object[]] $Before, [object[]] $After) {
    $new = @($After | Where-Object { $Before -notcontains $_ })
    Write-Host ("  {0}: {1}" -f $Title, $new.Count)
    foreach ($n in $new) { Write-Host ("    + {0}" -f $n) }
    return $new
}

Write-Host ("Apps-Install: {0} uygulama ({1}), CI={2}, Sandbox={3}" -f $selected.Count, ($selected -join ', '), $inCi, $inSandbox)
$before = Get-Inventory
$procBefore = @(Get-Process | ForEach-Object { $_.ProcessName } | Sort-Object -Unique)
# Önceden kurulu olanlar (runner imajında Chrome gibi) geri almada kaldırılmaz.
$preInstalled = @($selected | Where-Object { $ctx.Packages.IsInstalled($catalog[$_]['packageId'], $catalog[$_]['source']) })
if ($preInstalled.Count -gt 0) { Write-Host ("  Önceden kurulu: {0}" -f ($preInstalled -join ', ')) }

$appProfile = [Profile]::FromHashtable(@{ name = 'apps-test'; tweaks = @(); apps = @($selected.ToArray()) }, 'Apps-Install')
Write-Host '[1/3] Kurulum + düzen (uygulama başına birkaç dakika sürebilir; ilerleme günlükte)'
$r = Invoke-FaiEngine -Profile $appProfile -Context $ctx -Catalog @{} -AppCatalog $catalog
Write-Host ($r.Render())
foreach ($item in $r.Items) { if ($item.Status -eq 'Failed') { Fail ("{0}: {1}" -f $item.TweakId, $item.Reason) } }

$after = Get-Inventory
Write-Host '[2/3] Doğrulama ve keşif'
$newDesktop = Show-New 'Masaüstünde yeni kısayol (0 olmalı)' $before.Desktop $after.Desktop
if (@($newDesktop).Count -gt 0) { Fail ('masaüstünde yeni kısayol kaldı: ' + ($newDesktop -join ', ')) }
[void](Show-New 'Yeni Run değerleri' $before.Run $after.Run)
[void](Show-New 'Yeni Başlangıç klasörü öğeleri' $before.Startup $after.Startup)
[void](Show-New 'Yeni Başlat > Programlar öğeleri' $before.Programs $after.Programs)
[void](Show-New 'StartupApproved (03 = kapalı)' $before.Approved $after.Approved)
$procAfter = @(Get-Process | ForEach-Object { $_.ProcessName } | Sort-Object -Unique)
[void](Show-New 'Kurulumdan sonra çalışan yeni süreçler' $procBefore $procAfter)

$again = Invoke-FaiEngine -Profile $appProfile -Context $ctx -Catalog @{} -AppCatalog $catalog
foreach ($item in $again.Items) {
    if ($item.Status -ne 'UpToDate') { Fail ("{0}: ikinci çalıştırmada {1} ({2}) {3}" -f $item.TweakId, $item.Status, $item.Reason, ($item.Lines -join ' ')) }
}

if ($Undo.IsPresent) {
    # Her çalıştırma (ikinci çalıştırmada bir hata olsa bile) ayrı oturum açabilir: hepsi yeniden eskiye geri alınır.
    Write-Host '[3/3] -Undo (bu test kökündeki bütün oturumlar, yeniden eskiye)'
    for ($n = 1; $n -le 5; $n++) {
        if ($null -eq $ctx.Backup.GetLatest()) { break }
        $u = Invoke-FaiEngine -Undo -Context $ctx -Catalog @{}
        Write-Host ($u.Render())
        foreach ($item in $u.Items) { if ($item.Status -eq 'Failed') { Fail ("geri alma {0}: {1}" -f $item.TweakId, $item.Reason) } }
        if ($u.HasFailures()) { break }
    }
    $left = @($selected | Where-Object { $ctx.Packages.IsInstalled($catalog[$_]['packageId'], $catalog[$_]['source']) -and $preInstalled -notcontains $_ })
    if ($left.Count -gt 0) {
        Fail ('geri almadan sonra hâlâ kurulu: ' + ($left -join ', '))
        # Teşhis: kaldırma kaydı (ARP), çalışan süreçler, winget'in son çıktısı.
        $arpRoots = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall')
        foreach ($id in $left) {
            $name = [string]$catalog[$id]['name']
            Write-Host ("  Teşhis {0}:" -f $id)
            foreach ($root in $arpRoots) {
                foreach ($k in @(Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue)) {
                    $p = Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction SilentlyContinue
                    if ([string]$p.DisplayName -notlike "*$name*") { continue }
                    Write-Host ("    ARP {0}: {1} | Uninstall: {2} | Quiet: {3}" -f $k.PSChildName, $p.DisplayName, $p.UninstallString, $p.QuietUninstallString)
                }
            }
            $procs = @(Get-Process | Where-Object { $_.ProcessName -like "*$id*" -or $_.ProcessName -like 'Au_*' -or $_.ProcessName -like '*uninst*' })
            Write-Host ("    Süreçler: {0}" -f (($procs | ForEach-Object { '{0}({1})' -f $_.ProcessName, $_.Id }) -join ', '))
            Write-Host ("    winget son çıktı: {0}" -f $ctx.Packages.LastOutput)
        }
    }
}
else { Write-Host '[3/3] -Undo verilmedi; kurulumlar yerinde.' }

Write-Host ("Apps-Install: {0} HATA ({1:n1} dk)" -f $failed, $sw.Elapsed.TotalMinutes)
if ($failed -gt 0) { exit 1 }
exit 0

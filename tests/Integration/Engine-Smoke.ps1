<#
.SYNOPSIS
    Fake sağlayıcılı bundle'ı (dist/install.fakes.ps1) gerçek Windows PowerShell 5.1'de yükler ve motoru uçtan uca dener.

.DESCRIPTION
    1. PowerShell sürümü 5.1 mi (-AnyVersion ile atlanır; Linux'ta pwsh denemesi için)
    2. Fakes bundle'ı ayrıştırılıyor ve yükleniyor mu (sınıflar 5.1'de parse ediliyor mu)
    3. Fixture tweak kataloğu + örnek profil şema doğrulamasından geçiyor mu
    4. Dry-run: sıfır yazma, BackupStore oturumu açılmaz, durum değişmez
    5. Uygula: durum değişir (Unattended; Caution tweak profilde autoConfirm ile)
    6. Undo: durum başlangıçla birebir aynı
    Yalnız Fake sağlayıcı kullanır; gerçek kayıt defterine / servise HİÇ dokunmaz.
    Başarılıysa 0, değilse 1 ile çıkar. Windows CI ve elle çalıştırma için.

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\Integration\Engine-Smoke.ps1
    pwsh -NoProfile -File tests/Integration/Engine-Smoke.ps1 -AnyVersion
#>
[CmdletBinding()]
param(
    [string] $BundlePath,
    [switch] $AnyVersion
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not $BundlePath) { $BundlePath = Join-Path (Join-Path $repoRoot 'dist') 'install.fakes.ps1' }
$tweakDir = Join-Path $repoRoot 'tests/Fixtures/Tweaks/valid'
$profilePath = Join-Path $repoRoot 'tests/Fixtures/Profiles/smoke.json'

$requireV51 = -not $AnyVersion.IsPresent
$failed = 0
function Step([string] $Name, [scriptblock] $Body) {
    try {
        $detail = & $Body
        Write-Host ("  OK    {0} {1}" -f $Name, $detail) -ForegroundColor Green
    }
    catch {
        $script:failed++
        Write-Host ("  HATA  {0}: {1}" -f $Name, $_.Exception.Message) -ForegroundColor Red
    }
}

function Assert([bool] $Condition, [string] $Message) {
    if (-not $Condition) { throw $Message }
}

Write-Host ("Motor smoke testi: {0}" -f $BundlePath)

Step 'PowerShell 5.1' {
    $v = $PSVersionTable.PSVersion
    if ($requireV51 -and -not ($v.Major -eq 5 -and $v.Minor -eq 1)) { throw "beklenen 5.1, bulunan $v ($($PSVersionTable.PSEdition))" }
    "($v $($PSVersionTable.PSEdition))"
}

Step 'Fakes bundle var' {
    if (-not (Test-Path -LiteralPath $BundlePath -PathType Leaf)) { throw 'yok; önce build/Bundle.ps1 -IncludeFakes (tools/Sync-ToWindows.sh üretir)' }
    "($((Get-Item -LiteralPath $BundlePath).Length) bayt)"
}

Step 'Ayrıştırma (sınıflar dahil)' {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($BundlePath, [ref]$tokens, [ref]$errors)
    if ($errors -and $errors.Count -gt 0) { throw (($errors | ForEach-Object { "$($_.Extent.StartLineNumber): $($_.Message)" }) -join '; ') }
    "($($tokens.Count) belirteç)"
}

if ($failed -gt 0) {
    Write-Host ("Motor smoke testi BAŞARISIZ: {0} adım" -f $failed) -ForegroundColor Red
    exit 1
}

# Sınıflar yalnız nokta-kaynak yapılan kapsamda görünür; bu yüzden Step dışında, betik kapsamında yüklenir.
# (Bu betikte sınıf adı yazılmaz: parse anında henüz tanımlı değiller. Yalnız fonksiyonlar ve nesne üyeleri kullanılır.)
try { . $BundlePath }
catch {
    Write-Host ("  HATA  Yükleme: {0}" -f $_.Exception.Message) -ForegroundColor Red
    Write-Host 'Motor smoke testi BAŞARISIZ: yükleme' -ForegroundColor Red
    exit 1
}
Write-Host ("  OK    Yükleme (sürüm {0})" -f $script:FaiWinOPVersion) -ForegroundColor Green

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('FAI_WinOP_smoke_' + [guid]::NewGuid().ToString('N'))
$key = 'HKCU:\Software\FAI_WinOP_Test\Demo'
$state = @{}

try {
    Step 'ConvertTo-Hashtable 5.1 tuzakları (tek / boş dizi, null, türler)' {
        $h = ConvertFrom-JsonText '{"one":[7],"none":[],"objs":[{"x":1}],"n":null,"t":true,"i":5,"nest":{"a":{"b":[[1,2],[3]]}}}'
        Assert ($h -is [hashtable]) 'kök hashtable olmalı'
        Assert ($h['one'] -is [array] -and $h['one'].Count -eq 1 -and $h['one'][0] -eq 7) 'tek elemanlı dizi açıldı'
        Assert ($h['none'] -is [array] -and $h['none'].Count -eq 0) 'boş dizi korunmadı'
        Assert ($h['objs'] -is [array] -and $h['objs'][0] -is [hashtable]) 'nesne dizisi hashtable dizisi olmalı'
        Assert ($h.ContainsKey('n') -and $null -eq $h['n']) 'null korunmadı'
        Assert ($h['t'] -is [bool] -and $h['t']) 'bool türü korunmadı'
        Assert ($h['i'] -is [int] -or $h['i'] -is [long]) 'sayı türü korunmadı'
        Assert ($h['nest']['a']['b'][1] -is [array] -and $h['nest']['a']['b'][1].Count -eq 1) 'iç içe tek elemanlı dizi açıldı'
        $top = ConvertFrom-JsonText '[5]'
        Assert ($top -is [array] -and $top.Count -eq 1) 'en üst düzey tek elemanlı dizi açıldı'
        $empty = ConvertFrom-JsonText '[]'
        Assert ($null -ne $empty -and $empty -is [array] -and $empty.Count -eq 0) 'en üst düzey boş dizi korunmadı'
        '(geçti)'
    }

    Step 'Katalog + profil şema doğrulaması' {
        $state.Catalog = Import-FaiTweakCatalog -Path $tweakDir
        Assert ($state.Catalog.Count -eq 3) "3 tweak bekleniyordu, bulunan $($state.Catalog.Count)"
        $state.Profile = Import-FaiProfileFile -Path $profilePath
        Assert ($state.Profile.Tweaks.Count -eq 3) 'profilde 3 tweak bekleniyordu'
        "(3 tweak, profil $($state.Profile.Name))"
    }

    # Sahte makine: var olan bir değer, silinecek bir değer, çalışan bir servis.
    $ctx = New-FakeContext -BackupRoot (Join-Path $tmp 'backup') -Unattended
    $ctx.Registry.Seed($key, 'Existing', 1, 'DWord')
    $ctx.Registry.Seed($key, 'Obsolete', 'eski', 'String')
    $ctx.Registry.Seed($key, 'Untouched', 7, 'DWord')
    $ctx.Services.Seed('FaiDemoSvc', 'Automatic', 'Running')
    $baseline = (@($ctx.Registry.Dump()) + @($ctx.Services.Dump())) -join "`n"

    Step 'Dry-run: sıfır yazma, oturum açılmaz' {
        $ctx.DryRun = $true
        $r = Invoke-FaiEngine -Profile $state.Profile -Context $ctx -Catalog $state.Catalog
        $ctx.DryRun = $false
        Assert ($r.Count('Planned') -eq 3) "3 tweak önizlenmeliydi: $($r.Summary())"
        Assert ((Get-FakeWriteCount $ctx) -eq 0) "dry-run $(Get-FakeWriteCount $ctx) yazma yaptı"
        Assert ($ctx.Backup.SessionsOpened -eq 0) 'dry-run yedek oturumu açtı'
        Assert (-not (Test-Path -LiteralPath $ctx.Backup.Root)) 'dry-run yedek klasörü oluşturdu'
        $now = (@($ctx.Registry.Dump()) + @($ctx.Services.Dump())) -join "`n"
        Assert ($now -ceq $baseline) 'dry-run durumu değiştirdi'
        "(3 önizleme, 0 yazma)"
    }

    Step 'Uygula: durum değişir' {
        $r = Invoke-FaiEngine -Profile $state.Profile -Context $ctx -Catalog $state.Catalog
        Assert ($r.Count('Applied') -eq 3) "3 tweak uygulanmalıydı: $($r.Summary())"
        Assert (-not $r.HasFailures()) 'uygulamada hata var'
        Assert ($ctx.Registry.GetValue($key, 'Existing') -eq 2) 'Existing 2 olmalıydı'
        Assert ($ctx.Registry.GetValue($key, 'Level') -eq 30) 'profil parametresi (level=30) uygulanmadı'
        Assert (-not $ctx.Registry.ValueExists($key, 'Obsolete')) 'Obsolete silinmeliydi'
        Assert ($ctx.Registry.GetValueKind($key, 'NewBinary') -eq 'Binary') 'NewBinary Binary olmalıydı'
        Assert ($ctx.Services.GetStatus('FaiDemoSvc') -eq 'Stopped') 'servis durmalıydı'
        $now = (@($ctx.Registry.Dump()) + @($ctx.Services.Dump())) -join "`n"
        Assert ($now -cne $baseline) 'durum değişmedi'
        "($($ctx.Backup.ListSessionIds().Count) oturum, $(Get-FakeWriteCount $ctx) yazma)"
    }

    Step 'Undo: durum başlangıçla birebir aynı' {
        $r = Invoke-FaiEngine -Context $ctx -Catalog $state.Catalog -Undo
        Assert (-not $r.HasFailures()) 'undo hata verdi'
        Assert ($r.Count('Reverted') -ge 3) "geri alınan eylem sayısı beklenenden az: $($r.Summary())"
        $now = (@($ctx.Registry.Dump()) + @($ctx.Services.Dump())) -join "`n"
        Assert ($now -ceq $baseline) "undo sonrası durum başlangıçtan farklı:`n--- beklenen`n$baseline`n--- bulunan`n$now"
        Assert ($ctx.Registry.GetValue($key, 'Obsolete') -eq 'eski') 'Obsolete geri gelmedi'
        Assert (-not $ctx.Registry.ValueExists($key, 'Level')) 'önceden olmayan Level silinmeliydi'
        "($($r.Count('Reverted')) eylem geri alındı)"
    }

    Step 'İkinci Undo: geri alınacak oturum kalmadı' {
        $r = Invoke-FaiEngine -Context $ctx -Catalog $state.Catalog -Undo
        Assert ($r.Items.Count -eq 1 -and $r.Items[0].Status -eq 'Skipped') 'ikinci undo tek "oturum yok" kaydı vermeliydi'
        '(oturum yok)'
    }
}
finally {
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}

if ($failed -gt 0) {
    Write-Host ("Motor smoke testi BAŞARISIZ: {0} adım" -f $failed) -ForegroundColor Red
    exit 1
}
Write-Host 'Motor smoke testi geçti.' -ForegroundColor Green
exit 0

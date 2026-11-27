<#
.SYNOPSIS
    Gerçek Windows sağlayıcılarıyla her eylem türü için uygula → doğrula → geri al döngüsü (Faz 2 kabul testi).

.DESCRIPTION
    Üretim bundle'ını (dist/install.ps1) yükler, New-FaiWindowsContext ile GERÇEK sağlayıcılar kurar ve her eylem türünü
    yalnız zararsız test hedeflerinde dener:
      Registry        HKCU:\Software\FAI_WinOP_Test + HKLM:\SOFTWARE\FAI_WinOP_Test (her tür + değer silme)
      RegistryEach    HKCU test anahtarının alt anahtarları (istisna kalıbı)
      Service         geçici FAI_WinOP_TestSvc servisi (başlangıç türü) + Spooler / W32Time (durum)
      ScheduledTask   geçici \FAI_WinOP_Test\Deneme görevi
      Appx            listeleme + makinede provisioned kopyası olan zararsız bir gelen kutusu uygulaması (yoksa ATLA)
      Winget          jqlang.jq kur / kaldır (winget yoksa ATLA)
      Power           etkin planda SUB_SLEEP/STANDBYIDLE AC+DC + etkin plan değişimi
      File, Shortcut  %TEMP%\FAI_WinOP_Test
      Script          HKCU test anahtarı üzerinden
      Volume          varsayılan çıkış aygıtı (yoksa ATLA: sunucu / CI)
      TimerResolution FAI_TimerResolution servisi derle → kur → kaldır
      Motor           gerçek sağlayıcılarla tweak uygula → -Undo (diskteki oturumdan)
      AppxCleanup     açılış görevi \FAI_WinOP_Test\BloatCleanup (SYSTEM) + betik; paket listesi makinede olmayan ad
      Edge            salt okunur: Edge ve WebView2 sürümü
      Faz 5 dry-run   gerçek paket listesiyle bloat.remove / persistence / edge-remove önizlemesi: korunan paket yok
      RegistryByte    HKCU test anahtarında ikili değerin tek biti
      SolidImage      %TEMP%\FAI_WinOP_Test\pics (System.Drawing: oluştur, boyut korunarak boya)
      AppSetting      sentetik paket FAI.WinOPTest_0123456789abc (reg save ile üretilen settings.dat hive'ı)
      Kabuk           IsShellRunning, Settings / Desktop / StartMenu yenilemesi
      Faz 6 dry-run   ui.* görünüm tweak'leri önizlemesi + Export-FaiLayout (salt okunur)
      Faz 6 uygula    yalnız etkileşimli kabukta (Sandbox): görünüm tweak'leri uygula → düzen doğrula → -Undo (CI'da ATLA)
      PowerScheme     geçici test planı (etkin plandan kopya): oluştur → etkin → geri al (plan silinir); hazırda bekletme okunur
      Salt okunur     MMAgent özellikleri, Sistem Geri Yükleme durumu
      UpdatePause     Windows Update 7 gün duraklat → geri al (UX\Settings değerleri birebir)
      Windows Update  bekleyen güncelleme listesi (salt okunur; yalnız CI, Sandbox'ta ATLA)
      Faz 7 dry-run   sistem / güç / grafik / setup tweak'leri + profil games önizlemesi (gerçek sağlayıcılar, sıfır hata)
    Her döngüde snapshot JSON'a yazılıp okunur (BackupStore gibi). Test hedefleri sonda temizlenir.

    GÜVENLİK: yalnız GitHub Actions'ta (GITHUB_ACTIONS=true) ya da Windows Sandbox'ta (WDAGUtilityAccount) çalışır;
    başka makinede -Force olmadan hiçbir şeye dokunmadan 2 ile çıkar. Yönetici gerekir.
    Sonuç: hepsi geçtiyse 0, HATA varsa 1. ATLA hata sayılmaz (nedeni yazılır).

.PARAMETER BundlePath
    Varsayılan dist/install.ps1.

.PARAMETER SkipWinget
    Winget döngüsünü atla (ağ yoksa).

.PARAMETER Force
    CI / Sandbox dışında da çalıştır (gerçek makinede ÖNERİLMEZ).

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\Integration\Windows-Actions.ps1
#>
[CmdletBinding()]
param(
    [string] $BundlePath,
    [switch] $SkipWinget,
    [switch] $Force
)

$ErrorActionPreference = 'Stop'
$wingetOff = $SkipWinget.IsPresent
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not $BundlePath) { $BundlePath = Join-Path (Join-Path $repoRoot 'dist') 'install.ps1' }

# --- Güvenlik kapısı -----------------------------------------------------------------------------------------------
$inCi = $env:GITHUB_ACTIONS -eq 'true'
$inSandbox = $env:USERNAME -eq 'WDAGUtilityAccount'
if (-not ($inCi -or $inSandbox -or $Force.IsPresent)) {
    Write-Host 'Windows-Actions: gerçek sistemi değiştirir; yalnız GitHub Actions ya da Windows Sandbox''ta çalışır.' -ForegroundColor Yellow
    Write-Host '  Çalıştırılmadı. (Bilerek istiyorsan: -Force; gerçek makinede önerilmez.)' -ForegroundColor Yellow
    exit 2
}
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Windows-Actions: yönetici olarak çalıştırılmalı.' -ForegroundColor Red
    exit 1
}

$failed = 0
$skipped = 0
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$stepNo = 0
$stepTotal = 28
function Step([string] $Name, [scriptblock] $Body) {
    $script:stepNo++
    $t = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $detail = & $Body
        if ($detail -is [string] -and $detail.StartsWith('ATLA')) {
            $script:skipped++
            Write-Host ("  [{0}/{1}] ATLA  {2} {3}" -f $script:stepNo, $script:stepTotal, $Name, $detail.Substring(4).Trim()) -ForegroundColor Yellow
        }
        else {
            Write-Host ("  [{0}/{1}] OK    {2} {3} ({4:n1} sn)" -f $script:stepNo, $script:stepTotal, $Name, $detail, $t.Elapsed.TotalSeconds) -ForegroundColor Green
        }
    }
    catch {
        $script:failed++
        Write-Host ("  [{0}/{1}] HATA  {2}: {3}" -f $script:stepNo, $script:stepTotal, $Name, $_.Exception.Message) -ForegroundColor Red
        Write-Host ("        {0}" -f ($_.ScriptStackTrace -split "`n" | Select-Object -First 3) -join ' · ') -ForegroundColor DarkGray
    }
}

function Assert([bool] $Condition, [string] $Message) { if (-not $Condition) { throw $Message } }

Write-Host ("Windows eylem entegrasyonu: {0} (CI={1}, Sandbox={2})" -f $BundlePath, $inCi, $inSandbox)
if (-not (Test-Path -LiteralPath $BundlePath -PathType Leaf)) { Write-Host '  Bundle yok; önce build\Bundle.ps1' -ForegroundColor Red; exit 1 }
. $BundlePath

$testRoot = Join-Path $env:TEMP 'FAI_WinOP_Test'
if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
New-Item -ItemType Directory -Path $testRoot | Out-Null
$ctx = New-FaiWindowsContext -BackupRoot (Join-Path $testRoot 'backup') -ShowLog
$hkcu = 'HKCU:\Software\FAI_WinOP_Test'
$hklm = 'HKLM:\SOFTWARE\FAI_WinOP_Test'
$svcName = 'FAI_WinOP_TestSvc'
$taskPath = '\FAI_WinOP_Test\Deneme'

# Snapshot JSON'a yazılıp okunur → Apply → Test → Revert. State: durumun karşılaştırılabilir metni.
function Invoke-Cycle([hashtable] $Definition, [scriptblock] $State) {
    $action = New-FaiAction -Definition $Definition
    $errs = @(Get-FaiActionError -Definition $Definition)
    if ($errs.Count -gt 0) { throw ('şema: ' + ($errs -join '; ')) }
    $before = [string](& $State)
    $snap = [hashtable](ConvertFrom-JsonText -Json ($action.Snapshot($ctx) | ConvertTo-Json -Depth 10))
    $action.Apply($ctx)
    Assert $action.Test($ctx) ('uygulandıktan sonra Test $false: ' + $action.Describe())
    $after = [string](& $State)
    $action.Revert($ctx, $snap)
    $restored = [string](& $State)
    Assert ($restored -eq $before) ("geri alma farklı: önce '{0}', sonra '{1}' ({2})" -f $before, $restored, $action.Describe())
    return $after
}

function Get-RegState([string] $Path) {
    if (-not $ctx.Registry.KeyExists($Path)) { return '(anahtar yok)' }
    $lines = foreach ($n in @('S', 'E', 'D', 'Q', 'M', 'B', 'Del')) {
        if ($ctx.Registry.ValueExists($Path, $n)) {
            '{0}={1}:{2}' -f $n, $ctx.Registry.GetValueKind($Path, $n), ((@($ctx.Registry.GetValue($Path, $n)) | ForEach-Object { [string]$_ }) -join ',')
        }
    }
    return (@($lines) -join ';')
}

try {
    Step 'Registry (HKCU, her tür + silme)' {
        $ctx.Registry.SetValue($hkcu, 'D', 7, 'DWord')
        $ctx.Registry.SetValue($hkcu, 'Del', 'silinecek', 'String')
        $defs = @(
            @{ Type = 'Registry'; Path = $hkcu; Name = 'S'; Value = 'Açılış ğüşİ'; Kind = 'String' }
            @{ Type = 'Registry'; Path = $hkcu; Name = 'E'; Value = '%SystemRoot%\x'; Kind = 'ExpandString' }
            @{ Type = 'Registry'; Path = $hkcu; Name = 'D'; Value = 4294967295; Kind = 'DWord' }
            @{ Type = 'Registry'; Path = $hkcu; Name = 'Q'; Value = 4294967296; Kind = 'QWord' }
            @{ Type = 'Registry'; Path = $hkcu; Name = 'M'; Value = @('a', 'b'); Kind = 'MultiString' }
            @{ Type = 'Registry'; Path = $hkcu; Name = 'B'; Value = @(0, 1, 255); Kind = 'Binary' }
            @{ Type = 'Registry'; Path = $hkcu; Name = 'Del'; Ensure = 'Absent' }
        )
        foreach ($d in $defs) { [void](Invoke-Cycle $d { Get-RegState $hkcu }) }
        # Bağımsız okuma: Windows'un kendi cmdlet'i aynı değeri görüyor mu (ExpandString açılmadan saklanmış mı)?
        $a = New-FaiAction -Definition $defs[1]
        $a.Apply($ctx)
        $raw = (Get-Item -LiteralPath $hkcu).GetValue('E', $null, 'DoNotExpandEnvironmentNames')
        Assert ($raw -eq '%SystemRoot%\x') "ExpandString açılmış saklandı: $raw"
        Assert ((Get-ItemProperty -LiteralPath $hkcu -Name 'D').D -eq 7) 'DWord geri alınmadı'
        "($($defs.Count) döngü)"
    }

    Step 'Registry (HKLM, yönetici; oluşturulan anahtar zinciri geri almada silinir)' {
        $state = { '{0}|{1}' -f (Get-RegState "$hklm\Alt"), $ctx.Registry.KeyExists($hklm) }
        $after = Invoke-Cycle @{ Type = 'Registry'; Path = "$hklm\Alt"; Name = 'D'; Value = 1; Kind = 'DWord' } $state
        Assert ($after -eq 'D=DWord:1|True') "beklenmeyen: $after"
        Assert (-not (Test-Path -LiteralPath $hklm)) 'test anahtarı geri almada silinmedi'
        ''
    }

    Step 'RegistryEach (alt anahtarlar, istisna kalıbı, geri alma)' {
        $root = "$hkcu\Each"
        $ctx.Registry.SetValue("$root\App.One", 'Rank', 1, 'DWord')
        $ctx.Registry.SetValue("$root\App.Two", 'Enabled', 1, 'DWord')
        $ctx.Registry.SetValue("$root\Keep.Me", 'Enabled', 1, 'DWord')
        $names = @($ctx.Registry.GetSubKeyNames($root) | Sort-Object)
        Assert (($names -join ',') -eq 'App.One,App.Two,Keep.Me') ("GetSubKeyNames: " + ($names -join ','))
        $state = {
            (@('App.One', 'App.Two', 'Keep.Me') | ForEach-Object {
                    $p = "$root\$_"
                    if ($ctx.Registry.ValueExists($p, 'Enabled')) { '{0}={1}' -f $_, $ctx.Registry.GetValue($p, 'Enabled') } else { "$_=yok" }
                }) -join ';'
        }
        $after = Invoke-Cycle @{ Type = 'RegistryEach'; Path = $root; Name = 'Enabled'; Value = 0; Kind = 'DWord'; Exclude = @('keep*') } $state
        Assert ($after -eq 'App.One=0;App.Two=0;Keep.Me=1') "beklenmeyen: $after"
        ''
    }

    Step 'Service (başlangıç türü: geçici servis; durum: gerçek servis)' {
        if (Get-Service -Name $svcName -ErrorAction SilentlyContinue) { & sc.exe delete $svcName | Out-Null }
        $bin = Join-Path $env:SystemRoot 'System32\svchost.exe'
        New-Service -Name $svcName -BinaryPathName "`"$bin`" -k FAI_WinOP_Test" -StartupType Manual -DisplayName 'FAI_WinOP test' | Out-Null
        $state = { '{0}|{1}' -f $ctx.Services.GetStartType($svcName), $ctx.Services.GetStatus($svcName) }
        foreach ($st in @('Disabled', 'AutomaticDelayedStart', 'Automatic')) {
            $after = Invoke-Cycle @{ Type = 'Service'; Name = $svcName; StartType = $st } $state
            Assert ($after -like "$st|*") "beklenmeyen: $after"
        }
        $real = $null
        foreach ($n in @('Spooler', 'W32Time')) { if (Get-Service -Name $n -ErrorAction SilentlyContinue) { $real = $n; break } }
        if (-not $real) { return 'ATLA durum döngüsü: Spooler / W32Time yok' }
        $now = $ctx.Services.GetStatus($real)
        $want = 'Running'
        if ($now -eq 'Running') { $want = 'Stopped' }
        if ($ctx.Services.GetStartType($real) -eq 'Disabled') { return "ATLA durum döngüsü: $real devre dışı" }
        [void](Invoke-Cycle @{ Type = 'Service'; Name = $real; State = $want } { $ctx.Services.GetStatus($real) })
        "(3 başlangıç türü + $real $now→$want→$now)"
    }

    Step 'ScheduledTask' {
        $p = [WindowsTaskProvider]::SplitPath($taskPath)
        Unregister-ScheduledTask -TaskPath $p[0] -TaskName $p[1] -Confirm:$false -ErrorAction SilentlyContinue
        $act = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument '/c exit 0'
        Register-ScheduledTask -TaskPath $p[0] -TaskName $p[1] -Action $act -Description 'FAI_WinOP test' | Out-Null
        $after = Invoke-Cycle @{ Type = 'ScheduledTask'; Path = $taskPath; State = 'Disabled' } { $ctx.Tasks.GetTaskState($taskPath) }
        Assert ($after -eq 'Disabled') "beklenmeyen: $after"
        Assert ((Get-ScheduledTask -TaskPath $p[0] -TaskName $p[1]).State.ToString() -ne 'Disabled') 'geri alma sonrası hâlâ devre dışı'
        Assert ($ctx.Tasks.GetTaskState('\FAI_WinOP_Test\Yok') -eq '') 'olmayan görev boş dönmeli'
        ''
    }

    Step 'AppxCleanup (açılış görevi SYSTEM + betik, geri alma siler)' {
        $cleanupTask = '\FAI_WinOP_Test\BloatCleanup'
        $scriptFile = Join-Path $testRoot 'BloatCleanup.ps1'
        $def = @{ Type = 'AppxCleanup'; Names = @('FAI.WinOP.Yok'); TaskPath = $cleanupTask; ScriptPath = '%TEMP%\FAI_WinOP_Test\BloatCleanup.ps1' }
        $state = { '{0}|{1}' -f ($null -ne $ctx.Tasks.GetTaskAction($cleanupTask)), (Test-Path -LiteralPath $scriptFile) }
        $action = New-FaiAction -Definition $def
        $snap = [hashtable](ConvertFrom-JsonText -Json ($action.Snapshot($ctx) | ConvertTo-Json -Depth 10))
        $before = & $state
        $action.Apply($ctx)
        Assert $action.Test($ctx) 'uygulandıktan sonra Test $false'
        Assert ((& $state) -eq 'True|True') ('beklenmeyen: ' + (& $state))
        $p = [WindowsTaskProvider]::SplitPath($cleanupTask)
        $t = Get-ScheduledTask -TaskPath $p[0] -TaskName $p[1]
        Assert ($t.Principal.UserId -match 'SYSTEM') ('görev hesabı: ' + $t.Principal.UserId)
        Assert (@($t.Triggers | Where-Object { $_.CimClass.CimClassName -eq 'MSFT_TaskBootTrigger' }).Count -eq 1) 'açılış tetikleyicisi yok'
        $tokens = $null; $parseErrors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($scriptFile, [ref]$tokens, [ref]$parseErrors)
        Assert (@($parseErrors).Count -eq 0) ('betik 5.1''de ayrışmıyor: ' + (@($parseErrors) -join '; '))
        $action.Revert($ctx, $snap)
        Assert ((& $state) -eq $before) ('geri alma farklı: ' + (& $state))
        ''
    }

    Step 'Edge sağlayıcısı (salt okunur: Edge + WebView2 sürümü)' {
        $edge = $ctx.Edge.GetEdgeVersion()
        $wv = $ctx.Edge.GetWebView2Version()
        if (-not $edge -and -not $wv) { return 'ATLA Edge ve WebView2 yok (Sandbox / sunucu imajı)' }
        "(Edge: $edge; WebView2: $wv)"
    }

    Step 'Faz 5 dry-run: bloat önizlemesinde korunan paket yok' {
        $catalog = Import-FaiTweakCatalog -Path (Join-Path $repoRoot 'tweaks')
        $faiProfile = [Profile]::FromHashtable(@{ name = 'bloat-dry'; tweaks = @('bloat.remove', 'bloat.persistence', 'bloat.edge-remove') }, 'test')
        $ctx.DryRun = $true
        try { $dry = Invoke-FaiEngine -Profile $faiProfile -Context $ctx -Catalog $catalog }
        finally { $ctx.DryRun = $false }
        Assert (-not $dry.HasFailures()) ('dry-run hatası: ' + $dry.Render())
        $protected = [string[]]@((Get-FaiBloatProtected).Keys)
        $installed = @($ctx.Appx.GetInstalled())
        $planned = New-Object 'System.Collections.Generic.List[string]'
        foreach ($item in $dry.Items) {
            foreach ($l in @($item.Lines)) {
                if ($l -match '^Appx: (\S+) is removed') {
                    Assert (-not (Test-FaiAppxProtected -Name $Matches[1] -Patterns $protected)) "korunan paket listede: $($Matches[1])"
                    $planned.Add($Matches[1])
                }
            }
        }
        foreach ($n in $installed) {
            if (Test-FaiAppxProtected -Name $n -Patterns $protected) { Assert ($planned -notcontains $n) "korunan kurulu paket planlandı: $n" }
        }
        Write-Host ($dry.Render())
        "(kurulu $($installed.Count) paket; kaldırılacak $($planned.Count): $($planned -join ', '))"
    }

    Step 'RegistryByte (ikili değerin tek biti, değerin geri kalanı korunur)' {
        $blob = [byte[]]@(0x30, 0, 0, 0, 0xFE, 0xFF, 0xFF, 0xFF, 0x02, 0, 0, 0, 0x03, 0, 0, 0)
        $ctx.Registry.SetValue($hkcu, 'Stuck', $blob, 'Binary')
        $state = { (@($ctx.Registry.GetValue($hkcu, 'Stuck')) | ForEach-Object { [string]$_ }) -join ',' }
        $after = Invoke-Cycle @{ Type = 'RegistryByte'; Path = $hkcu; Name = 'Stuck'; Offset = 8; Mask = 1; Value = $true } $state
        Assert ($after -eq '48,0,0,0,254,255,255,255,3,0,0,0,3,0,0,0') "beklenmeyen değer: $after"
        "($after)"
    }

    Step 'SolidImage (System.Drawing: oluştur + klasörde boyut korunarak boya)' {
        $pics = Join-Path $testRoot 'pics'
        New-Item -ItemType Directory -Path $pics -Force | Out-Null
        [System.IO.File]::WriteAllBytes((Join-Path $pics 'user.png'), $ctx.Images.NewSolid(448, 448, '0078D4', 'png'))
        [System.IO.File]::WriteAllBytes((Join-Path $pics 'guest.bmp'), $ctx.Images.NewSolid(64, 32, 'FFFFFF', 'bmp'))
        [System.IO.File]::WriteAllText((Join-Path $pics 'readme.txt'), 'görüntü değil')
        $state = { (@(Get-ChildItem -LiteralPath $pics -File | Sort-Object Name | ForEach-Object { '{0}:{1}' -f $_.Name, (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.Substring(0, 12) })) -join ';' }
        [void](Invoke-Cycle @{ Type = 'SolidImage'; Directory = $pics; Filter = @('*.png', '*.bmp', '*.txt'); Color = '000000' } $state)
        $a = New-FaiAction @{ Type = 'SolidImage'; Directory = $pics; Filter = @('*.png', '*.bmp'); Color = '000000' }
        $a.Apply($ctx)
        $size = $ctx.Images.GetSize((Join-Path $pics 'guest.bmp'))
        Assert ($size[0] -eq 64 -and $size[1] -eq 32) ('boyut korunmadı: ' + ($size -join 'x'))
        Assert ($ctx.Images.IsSolid((Join-Path $pics 'user.png'), '000000')) 'user.png siyah değil'
        $black = Join-Path $testRoot 'Black.png'
        [void](Invoke-Cycle @{ Type = 'SolidImage'; Path = $black; Color = '000000'; Width = 1920; Height = 1080 } { Test-Path -LiteralPath $black })
        "(boyut korundu: $($size -join 'x'))"
    }

    Step 'AppSetting (settings.dat hive: sentetik paket, Bool + Int32)' {
        $pkg = 'FAI.WinOPTest_0123456789abc'
        $pkgRoot = Join-Path $env:LOCALAPPDATA "Packages\$pkg"
        $src = 'HKCU:\Software\FAI_WinOP_Test\Hive\LocalState'
        New-Item -Path $src -Force | Out-Null
        New-ItemProperty -Path $src -Name 'Dummy' -Value 1 -PropertyType DWord -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $pkgRoot 'Settings') -Force | Out-Null
        $dat = Join-Path $pkgRoot 'Settings\settings.dat'
        & reg.exe save 'HKCU\Software\FAI_WinOP_Test\Hive' $dat /y 2>&1 | Out-Null
        Assert ($LASTEXITCODE -eq 0) 'reg save başarısız'
        try {
            Assert ($ctx.AppSettings.HasSettings($pkg)) 'settings.dat görülmedi'
            $state = {
                $g = $ctx.AppSettings.GetValue($pkg, 'GhostFile')
                $o = $ctx.AppSettings.GetValue($pkg, 'OpenFile')
                $gs = 'yok'
                $os = 'yok'
                if ($null -ne $g) { $gs = '{0}:{1}' -f $g['Type'], $g['Data'][0] }
                if ($null -ne $o) { $os = '{0}:{1}' -f $o['Type'], $o['Data'][0] }
                "$gs|$os"
            }
            $a1 = Invoke-Cycle @{ Type = 'AppSetting'; Package = $pkg; Name = 'GhostFile'; Kind = 'Bool'; Value = $true } $state
            $a2 = Invoke-Cycle @{ Type = 'AppSetting'; Package = $pkg; Name = 'OpenFile'; Kind = 'Int32'; Value = 1 } $state
            Assert ($a1 -eq '100000011:1|yok') "Bool: $a1"
            Assert ($a2 -eq 'yok|100000004:1') "Int32: $a2"
            "($a1 · $a2)"
        }
        finally { Remove-Item -LiteralPath $pkgRoot -Recurse -Force -ErrorAction SilentlyContinue }
    }

    Step 'Kabuk sağlayıcısı (IsShellRunning, Settings / Desktop / StartMenu yenilemesi)' {
        $shell = $ctx.Desktop.IsShellRunning()
        $ctx.Desktop.Refresh('Settings')
        $ctx.Desktop.Refresh('Desktop')
        $ctx.Desktop.Refresh('StartMenu')
        "(etkileşimli kabuk: $shell)"
    }

    $faz6 = @('ui.theme-black', 'ui.taskbar','ui.lockscreen-black', 'ui.account-pictures-black', 'ui.widgets-off', 'ui.copilot-off', 'ui.notepad-settings')
    Step 'Faz 6 dry-run: görünüm tweak''leri + Export-FaiLayout (salt okunur)' {
        $catalog = Import-FaiTweakCatalog -Path (Join-Path $repoRoot 'tweaks')
        $faiProfile = [Profile]::FromHashtable(@{ name = 'faz6-dry'; tweaks = $faz6 }, 'test')
        $ctx.DryRun = $true
        try { $dry = Invoke-FaiEngine -Profile $faiProfile -Context $ctx -Catalog $catalog }
        finally { $ctx.DryRun = $false }
        Assert (-not $dry.HasFailures()) ('dry-run hatası: ' + $dry.Render())
        Write-Host ($dry.Render())
        $exp = Export-FaiLayout -Context $ctx
        $pins = (@($exp.Layout['taskbar']['pins']) | ForEach-Object { @($_.Values)[0] }) -join ', '
        Write-Host ("  sabitlemeler: {0} · otomatik gizle: {1} · uyarı: {2}" -f $pins, $exp.Layout['taskbar']['autoHide'], ($exp.Warnings -join ' | '))
        "(planlanan $($dry.Count('Planned')), zaten uygun $($dry.Count('UpToDate')))"
    }

    Step 'Faz 6 uygula → düzen doğrula → -Undo (yalnız etkileşimli kabukta)' {
        if (-not $ctx.Desktop.IsShellRunning()) { return 'ATLA etkileşimli kabuk yok (CI hizmet oturumu)' }
        $catalog = Import-FaiTweakCatalog -Path (Join-Path $repoRoot 'tweaks')
        # 4.3'ten beri otomatik gizleme ve masaüstü simgeleri tweak'te değil, profilin layout bölümünde
        $faz6Layout = @{ taskbar = @{ autoHide = $true }; desktopIcons = @{ thisPC = $true; recycleBin = $true } }
        $faiProfile = [Profile]::FromHashtable(@{ name = 'faz6'; tweaks = $faz6; layout = $faz6Layout }, 'test')
        # Karşılaştırma görev çubuğu + masaüstü simgeleri üzerinden (simge konumlarını / start2.bin'i Gezgin kendisi de yazar).
        $view = { $l = (Export-FaiLayout -Context $ctx).Layout; @{ taskbar = $l['taskbar']; desktopIcons = $l['desktopIcons'] } | ConvertTo-Json -Depth 10 -Compress }
        $before = & $view
        $run = Invoke-FaiEngine -Profile $faiProfile -Context $ctx -Catalog $catalog
        Write-Host ($run.Render())
        Assert (-not $run.HasFailures()) 'uygulamada hata'
        $now = (Export-FaiLayout -Context $ctx).Layout
        $pins = @($now['taskbar']['pins'])
        Assert ($pins.Count -ge 1 -and $pins[0]['appId'] -eq 'Microsoft.Windows.Explorer') ('ilk sabitleme Gezgin değil: ' + ($now['taskbar'] | ConvertTo-Json -Compress))
        Assert ($now['taskbar']['autoHide'] -eq $true) 'otomatik gizleme açılmadı'
        Assert ($now['desktopIcons']['thisPC'] -and $now['desktopIcons']['recycleBin']) 'masaüstü simgeleri görünmüyor'
        $again = Invoke-FaiEngine -Profile $faiProfile -Context $ctx -Catalog $catalog
        Assert ($again.Find('ui.taskbar').Status -eq 'UpToDate') ('ikinci çalıştırmada ui.taskbar: ' + $again.Find('ui.taskbar').Status)
        $ctx.Backup = [BackupStore]::new($ctx.Backup.Root)
        $undo = Invoke-FaiEngine -Undo -Context $ctx -Catalog $catalog
        Assert (-not $undo.HasFailures()) ('geri almada hata: ' + $undo.Render())
        $after = & $view
        Assert ($after -eq $before) ("geri alma düzeni getirmedi:`n  önce  $before`n  sonra $after")
        "(sabitlemeler: $((@($pins) | ForEach-Object { @($_.Values)[0] }) -join ', '))"
    }

    Step 'PowerScheme (geçici plan: oluştur → etkin → geri al) + hazırda bekletme okuma' {
        $active = $ctx.Power.GetActiveScheme()
        $testGuid = 'fa1f7e57-0000-4000-8000-000000000007'
        if ($ctx.Power.ResolveScheme($testGuid)) { & powercfg.exe /delete $testGuid | Out-Null }
        $state = { '{0}|{1}' -f $ctx.Power.GetActiveScheme(), [bool]$ctx.Power.ResolveScheme($testGuid) }
        try {
            $after = Invoke-Cycle @{ Type = 'PowerScheme'; Guid = $testGuid; Name = 'FAI_WinOP_Test'; Base = $active } $state
            Assert ($after -eq "$testGuid|True") "plan etkin olmadı: $after"
        }
        finally {
            if ($ctx.Power.GetActiveScheme() -ne $active) { $ctx.Power.SetActiveScheme($active) }
            if ($ctx.Power.ResolveScheme($testGuid)) { & powercfg.exe /delete $testGuid | Out-Null }
        }
        Assert ($ctx.Power.GetActiveScheme() -eq $active) 'etkin plan geri dönmedi'
        "(hazırda bekletme: $($ctx.Power.GetHibernate()))"
    }

    Step 'MMAgent + Sistem Geri Yükleme (salt okunur)' {
        $mm = $ctx.MemoryAgent.GetState()
        foreach ($f in @('MemoryCompression', 'ApplicationLaunchPrefetching', 'ApplicationPreLaunch')) { Assert $mm.ContainsKey($f) "MMAgent özelliği okunamadı: $f" }
        $on = @($mm.Keys | Sort-Object | ForEach-Object { '{0}={1}' -f $_, $mm[$_] }) -join ', '
        "($on; geri yükleme koruması: $($ctx.SystemControl.IsRestoreEnabled()))"
    }

    Step 'UpdatePause (7 gün duraklat → geri al)' {
        $ux = Get-FaiUpdatePauseKey
        $state = { (@((Get-FaiUpdatePauseName).Keys) | ForEach-Object { '{0}={1}' -f $_, [string]$ctx.Registry.GetValue($ux, $_) }) -join ';' }
        $after = Invoke-Cycle @{ Type = 'UpdatePause'; Days = 7 } $state
        Assert ($after -match 'PauseUpdatesExpiryTime=\d{4}-\d\d-\d\dT') "duraklatma yazılmadı: $after"
        ''
    }

    Step 'Windows Update (salt okunur: bekleyen liste)' {
        if (-not $inCi) { return 'ATLA yalnız CI (Sandbox''ta Windows Update kapalı / yavaş)' }
        $t = [System.Diagnostics.Stopwatch]::StartNew()
        $pending = @($ctx.Updates.GetPending())
        "($($pending.Count) bekleyen, yeniden başlatma bekliyor: $($ctx.Updates.IsRebootPending()), arama $([int]$t.Elapsed.TotalSeconds) sn)"
    }

    Step 'Faz 7 dry-run: sistem / güç / grafik / setup + games (gerçek sağlayıcılar)' {
        $catalog = Import-FaiTweakCatalog -Path (Join-Path $repoRoot 'tweaks')
        $faz7 = @('system.restore-point', 'system.timer-resolution', 'power.plan', 'setup.mmagent-off', 'setup.background-apps-off',
            'setup.store-optimize', 'setup.edition-pro', 'graphics.nvidia-settings', 'graphics.amd-settings', 'graphics.p0-state', 'refresh.reboot-to-bios')
        if ($inCi) { $faz7 += 'setup.updates-staged' }
        $faiProfile = [Profile]::FromHashtable(@{ name = 'faz7-dry'; tweaks = $faz7; games = @(@{ exe = 'fai-test.exe'; priority = 'High'; smtOff = $true; excludeCore0 = $true }) }, 'test')
        $ctx.DryRun = $true
        try { $dry = Invoke-FaiEngine -Profile $faiProfile -Context $ctx -Catalog $catalog }
        finally { $ctx.DryRun = $false }
        Write-Host ($dry.Render())
        Assert (-not $dry.HasFailures()) ('dry-run hatası: ' + $dry.Render())
        Assert ($dry.Find('refresh.reboot-to-bios').Status -eq 'Skipped') 'araç tweak''i profilde atlanmadı'
        Assert ($dry.Find('gaming.per-game').Status -eq 'Planned') 'games önizlenmedi'
        "(planlanan $($dry.Count('Planned')), atlanan $($dry.Count('Skipped')), zaten uygun $($dry.Count('UpToDate')); $($ctx.SystemInfo.GetLogicalProcessorCount()) mantıksal / $($ctx.SystemInfo.GetCoreCount()) çekirdek)"
    }

    Step 'Appx (listeleme + kullanıcı paketi kaldır / geri kaydet)' {
        $installed = @($ctx.Appx.GetInstalled())
        $provisioned = @($ctx.Appx.GetProvisioned())
        $none = New-FaiAction -Definition @{ Type = 'Appx'; Name = 'FAI.WinOP.Yok' }
        Assert $none.Test($ctx) 'olmayan paket Test $true olmalı'
        $candidates = @('Microsoft.WindowsCalculator', 'Microsoft.MicrosoftStickyNotes', 'Microsoft.WindowsAlarms', 'Microsoft.Paint',
            'Microsoft.WindowsNotepad', 'Microsoft.GetHelp', 'Microsoft.BingWeather', 'Microsoft.ZuneMusic')
        $pick = $null
        foreach ($c in $candidates) { if ($installed -contains $c -and $provisioned -contains $c) { $pick = $c; break } }
        if (-not $pick) { return ("ATLA gerçek kaldırma: aday paket yok (kurulu {0}, provisioned {1}); Faz 5'te Hyper-V VM" -f $installed.Count, $provisioned.Count) }
        $after = Invoke-Cycle @{ Type = 'Appx'; Name = $pick; Scope = 'User' } { [string]($ctx.Appx.GetInstalled() -contains $pick) }
        Assert ($after -eq 'False') "kaldırılmadı: $pick"
        "($pick; kurulu $($installed.Count), provisioned $($provisioned.Count))"
    }

    Step 'Winget (jqlang.jq kur / kaldır)' {
        if ($wingetOff) { return 'ATLA -SkipWinget' }
        if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) { return 'ATLA winget yok (Sandbox / eski imaj)' }
        $id = 'jqlang.jq'
        if ($ctx.Packages.IsInstalled($id, 'winget')) { return "ATLA $id zaten kurulu" }
        $after = Invoke-Cycle @{ Type = 'Winget'; Id = $id } { [string]$ctx.Packages.IsInstalled($id, 'winget') }
        Assert ($after -eq 'True') 'kurulmadı'
        ''
    }

    Step 'Power (AC/DC ayar + etkin plan)' {
        $scheme = $ctx.Power.GetActiveScheme()
        $state = { '{0}|{1}' -f $ctx.Power.GetValue($scheme, 'SUB_SLEEP', 'STANDBYIDLE', $true), $ctx.Power.GetValue($scheme, 'SUB_SLEEP', 'STANDBYIDLE', $false) }
        $start = & $state
        $ac = 1234
        $dc = 567
        $after = Invoke-Cycle @{ Type = 'Power'; Subgroup = 'SUB_SLEEP'; Setting = 'STANDBYIDLE'; AC = $ac; DC = $dc } $state
        Assert ($after -eq "$ac|$dc") "beklenmeyen: $after"
        # Plan değişimi: etkin planın geçici kopyasına geçilir, geri alınır, kopya silinir (yeni Win11'de çoğu zaman tek plan var).
        $dup = [regex]::Match(((& powercfg.exe /duplicatescheme $scheme 2>&1) -join ' '), [WindowsPowerProvider]::GuidPattern()).Value.ToLowerInvariant()
        Assert ([bool]$dup) 'geçici plan kopyalanamadı'
        try {
            Assert ($ctx.Power.ResolveScheme($dup) -eq $dup) 'kopya plan çözülemedi'
            $now = Invoke-Cycle @{ Type = 'Power'; ActiveScheme = $dup } { $ctx.Power.GetActiveScheme() }
            Assert ($now -eq $dup) "etkin plan değişmedi: $now"
        }
        finally { & powercfg.exe /delete $dup | Out-Null }
        $planNote = 'etkin plan döngüsü (geçici kopya plan)'
        Assert ($ctx.Power.GetActiveScheme() -eq $scheme) 'etkin plan geri dönmedi'
        "(önce $start; $planNote)"
    }

    Step 'File (yeni, üzerine yaz, sil)' {
        $state = { (Get-ChildItem -LiteralPath $testRoot -File | Sort-Object Name | ForEach-Object { '{0}:{1}' -f $_.Name, [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($_.FullName)) }) -join ';' }
        [System.IO.File]::WriteAllBytes((Join-Path $testRoot 'var.ini'), [byte[]](0xFF, 0xFE, 0x41, 0x00))
        [void](Invoke-Cycle @{ Type = 'File'; Path = '%TEMP%\FAI_WinOP_Test\yeni.txt'; Content = 'ğüşİ'; Encoding = 'UTF8BOM' } $state)
        [void](Invoke-Cycle @{ Type = 'File'; Path = '%TEMP%\FAI_WinOP_Test\var.ini'; Content = "a=1`r`n" } $state)
        [void](Invoke-Cycle @{ Type = 'File'; Path = '%TEMP%\FAI_WinOP_Test\var.ini'; Ensure = 'Absent' } $state)
        '(3 döngü)'
    }

    Step 'Shortcut (oluştur, değiştir, sil)' {
        $lnk = '%TEMP%\FAI_WinOP_Test\Not Defteri.lnk'
        $full = [Environment]::ExpandEnvironmentVariables($lnk)
        $state = { if (Test-Path -LiteralPath $full) { [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($full)) } else { 'yok' } }
        $create = @{ Type = 'Shortcut'; Path = $lnk; TargetPath = '%SystemRoot%\System32\notepad.exe'; Arguments = '/A'; Description = 'FAI test' }
        [void](Invoke-Cycle $create $state)
        (New-FaiAction -Definition $create).Apply($ctx)
        $shell = New-Object -ComObject WScript.Shell
        $read = $shell.CreateShortcut($full)
        Assert ($read.TargetPath -like '*\notepad.exe' -and $read.Arguments -eq '/A') ('kısayol okunamadı: ' + $read.TargetPath)
        [void](Invoke-Cycle @{ Type = 'Shortcut'; Path = $lnk; TargetPath = '%SystemRoot%\System32\calc.exe' } $state)
        [void](Invoke-Cycle @{ Type = 'Shortcut'; Path = $lnk; Ensure = 'Absent' } $state)
        '(3 döngü)'
    }

    Step 'Script' {
        $ctx.Registry.SetValue($hkcu, 'Betik', 'eski', 'String')
        $def = @{
            Type        = 'Script'; Description = 'test'
            Test        = "(Get-ItemProperty -LiteralPath 'HKCU:\Software\FAI_WinOP_Test').Betik -eq 'yeni'"
            Snapshot    = "(Get-ItemProperty -LiteralPath 'HKCU:\Software\FAI_WinOP_Test').Betik"
            Apply       = "Set-ItemProperty -LiteralPath 'HKCU:\Software\FAI_WinOP_Test' -Name Betik -Value 'yeni'"
            Revert      = "param(`$Snapshot) Set-ItemProperty -LiteralPath 'HKCU:\Software\FAI_WinOP_Test' -Name Betik -Value `$Snapshot"
        }
        $after = Invoke-Cycle $def { [string]$ctx.Registry.GetValue($hkcu, 'Betik') }
        Assert ($after -eq 'yeni') "beklenmeyen: $after"
        ''
    }

    Step 'Volume (varsayılan çıkış)' {
        if (-not $ctx.Audio.HasDevice()) { return 'ATLA ses çıkış aygıtı yok (sunucu / CI); AudioEndpoint derlendi ve sorgulandı' }
        $start = $ctx.Audio.GetVolume()
        $want = 15
        if ($start -eq 15) { $want = 16 }
        $after = Invoke-Cycle @{ Type = 'Volume'; Level = $want } { '{0}|{1}' -f $ctx.Audio.GetVolume(), $ctx.Audio.GetMute() }
        Assert ($after -like "$want|*") "beklenmeyen: $after"
        "(%$start → %$want → %$start)"
    }

    Step 'TimerResolution (derle → servis kur → kaldır)' {
        if ($ctx.TimerResolution.IsInstalled()) { return 'ATLA FAI_TimerResolution zaten kurulu' }
        $after = Invoke-Cycle @{ Type = 'TimerResolution'; Resolution = 5000 } { '{0}|{1}' -f $ctx.TimerResolution.IsInstalled(), $ctx.TimerResolution.GetResolution() }
        Assert ($after -eq 'True|5000') "beklenmeyen: $after"
        Assert (-not (Test-Path -LiteralPath (Join-Path $env:ProgramFiles 'FAI_WinOP\FAI_TimerResolution.exe'))) 'ikili silinmedi'
        ''
    }

    Step 'Motor: gerçek sağlayıcılarla uygula → -Undo (diskteki oturum)' {
        $tweak = [Tweak]::FromHashtable(@{
                Id = 'test.windows-engine'; Title = 'Gerçek motor'; Description = 'test'; Category = 'test'; Risk = 'Safe'
                Actions = @(
                    @{ Type = 'Registry'; Path = $hkcu; Name = 'Motor'; Value = 1; Kind = 'DWord' }
                    @{ Type = 'File'; Path = '%TEMP%\FAI_WinOP_Test\motor.txt'; Content = 'motor' }
                    @{ Type = 'ScheduledTask'; Path = $taskPath; State = 'Disabled' }
                )
            }, 'test')
        $catalog = @{ 'test.windows-engine' = $tweak }
        $faiProfile = [Profile]::FromHashtable(@{ name = 'windows-test'; tweaks = @('test.windows-engine') }, 'test')
        $state = { '{0}|{1}|{2}' -f (Get-RegState $hkcu), (Test-Path -LiteralPath (Join-Path $testRoot 'motor.txt')), $ctx.Tasks.GetTaskState($taskPath) }
        $before = & $state
        $ctx.DryRun = $true
        $dry = Invoke-FaiEngine -Profile $faiProfile -Context $ctx -Catalog $catalog
        $ctx.DryRun = $false
        Assert ($dry.Find('test.windows-engine').Status -eq 'Planned') 'dry-run Planned değil'
        Assert ((& $state) -eq $before) 'dry-run durumu değiştirdi'
        $run = Invoke-FaiEngine -Profile $faiProfile -Context $ctx -Catalog $catalog
        Assert ($run.Find('test.windows-engine').Status -eq 'Applied') ('uygulanmadı: ' + $run.Find('test.windows-engine').Reason)
        Assert ((& $state) -ne $before) 'uygulama durumu değiştirmedi'
        $ctx.Backup = [BackupStore]::new($ctx.Backup.Root)
        $undo = Invoke-FaiEngine -Undo -Context $ctx -Catalog $catalog
        Assert (-not $undo.HasFailures()) 'geri almada hata'
        Assert ((& $state) -eq $before) ("undo farklı: önce '{0}', sonra '{1}'" -f $before, (& $state))
        ''
    }
}
finally {
    Write-Host '== Temizlik'
    Remove-Item -LiteralPath $hkcu -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $hklm -Recurse -Force -ErrorAction SilentlyContinue
    if (Get-Service -Name $svcName -ErrorAction SilentlyContinue) { & sc.exe delete $svcName | Out-Null }
    $p = [WindowsTaskProvider]::SplitPath($taskPath)
    Unregister-ScheduledTask -TaskPath $p[0] -TaskName $p[1] -Confirm:$false -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskPath $p[0] -TaskName 'BloatCleanup' -Confirm:$false -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ("Sonuç: {0} adım, {1} HATA, {2} ATLA ({3:n0} sn)" -f $stepNo, $failed, $skipped, $sw.Elapsed.TotalSeconds)
if ($failed -gt 0) {
    Write-Host 'Windows eylem entegrasyonu BAŞARISIZ.' -ForegroundColor Red
    exit 1
}
Write-Host 'Windows eylem entegrasyonu geçti.' -ForegroundColor Green
exit 0

# Komut satırı (docs/ROADMAP.md 2.4). Giriş: src/Entry.ps1 → Invoke-FaiCli -Bound $PSBoundParameters.
#
# Çıkış kodları: 0 tamam · 1 raporda HATA ya da çalıştırma hatası · 2 kullanım hatası · 3 yükseltme reddedildi / yok.
# Yönetici gerektirmeyenler: -List, -ExportProfile, -ExportLayout, -Version (indirilen sürüm kendi yükseltir).
# Diğer her şey yönetici ister: dosyadan çalıştıysa UAC ile kendini aynı parametrelerle yeniden başlatır; irm | iex
# ile (dosyasız) çalıştıysa yükseltemez, get.ps1 tek satırını önerir.
# Yükseltme farklı bir yönetici hesabıyla yapılırsa HKCU o hesabınkidir: araç kendi hesabınızda (yönetici) çalışmalı.

function Get-FaiRepoUrl { return 'https://github.com/MrFedai/FAI_WinOP' }

function Get-FaiDataDir {
    <# .SYNOPSIS  %ProgramData%\FAI_WinOP (yedek, günlük, yeniden başlatma sonrası devam kopyası). #>
    return (Join-Path $env:ProgramData 'FAI_WinOP')
}

function Get-FaiDocumentsDir {
    <# .SYNOPSIS  Belgeler\FAI_WinOP (dışa aktarılan profiller). #>
    return (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'FAI_WinOP')
}

function Test-FaiIsAdmin {
    <# .SYNOPSIS  Süreç yükseltilmiş yönetici olarak mı çalışıyor. #>
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return ([Security.Principal.WindowsPrincipal]::new($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Split-FaiList {
    <# .SYNOPSIS  '-Only a,b' (powershell -File virgüllü listeyi tek metin verir) → @('a','b'); boşlar atılır. #>
    [CmdletBinding()]
    param([AllowNull()] [AllowEmptyCollection()] [string[]] $Items)

    $out = New-Object 'System.Collections.Generic.List[string]'
    foreach ($item in @($Items)) {
        foreach ($p in ([string]$item -split ',')) {
            $t = $p.Trim()
            if ($t -and -not $out.Contains($t)) { $out.Add($t) }
        }
    }
    return , $out.ToArray()
}

function ConvertTo-FaiArgumentString {
    <#
    .SYNOPSIS
        $PSBoundParameters → komut satırı metni (yeniden başlatma için). Anahtarlar sabit sırada, Exclude'dakiler hariç.
        Anahtar (switch) yalnız açıksa yazılır; dizi virgülle birleşir; değer çift tırnak içinde.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [System.Collections.IDictionary] $Bound,
        [string[]] $Exclude = @()
    )

    $parts = New-Object 'System.Collections.Generic.List[string]'
    foreach ($key in @($Bound.Keys | ForEach-Object { [string]$_ } | Sort-Object)) {
        if ($Exclude -contains $key) { continue }
        $v = $Bound[$key]
        if ($v -is [System.Management.Automation.SwitchParameter]) {
            if ($v.IsPresent) { $parts.Add('-' + $key) }
            continue
        }
        if ($v -is [bool]) {
            if ($v) { $parts.Add('-' + $key) }
            continue
        }
        if ($v -is [array]) { $v = (@($v) | ForEach-Object { [string]$_ }) -join ',' }
        $text = [string]$v
        if ($text -eq '') { continue }
        $parts.Add(('-{0} "{1}"' -f $key, $text.Replace('"', '\"')))
    }
    return ($parts -join ' ')
}

function Get-FaiWebText {
    <# .SYNOPSIS  URL'nin içeriğini UTF-8 metin olarak indirir (TLS 1.2 açık). #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [string] $Url)

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $wc = New-Object System.Net.WebClient
    try {
        $wc.Encoding = [System.Text.Encoding]::UTF8
        return $wc.DownloadString($Url)
    }
    finally { $wc.Dispose() }
}

function Test-FaiSha256 {
    <#
    .SYNOPSIS
        Dosyanın SHA-256'sı .sha256 metnindeki ('<hex>  <ad>' ya da yalnız '<hex>') değerle aynı mı. Biçim bozuksa hata.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $Path,
        [Parameter(Mandatory = $true)] [AllowEmptyString()] [string] $HashText
    )

    $expected = ([string]$HashText).Trim().Split([char[]]@(' ', "`t", "`r", "`n"), [StringSplitOptions]::RemoveEmptyEntries)
    if ($expected.Count -lt 1 -or $expected[0] -notmatch '^[0-9a-fA-F]{64}$') { throw 'SHA-256 dosyası geçersiz.' }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    return ($actual.ToLowerInvariant() -eq $expected[0].ToLowerInvariant())
}

function Get-FaiVerifiedScript {
    <#
    .SYNOPSIS
        BaseUrl/install.ps1 ve BaseUrl/install.ps1.sha256'yı indirir, doğrular; doğru ise yerel yolu döndürür.
        Eşleşmezse dosyayı siler ve hata fırlatır (çalıştırma durur).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $BaseUrl,
        [Parameter(Mandatory = $true)] [string] $Destination
    )

    $base = $BaseUrl.TrimEnd('/')
    $dir = Split-Path -Parent $Destination
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { [void](New-Item -ItemType Directory -Path $dir -Force) }
    Write-Host ("İndiriliyor: {0}/install.ps1" -f $base)
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $wc = New-Object System.Net.WebClient
    try { $wc.DownloadFile($base + '/install.ps1', $Destination) }
    finally { $wc.Dispose() }
    $hashText = Get-FaiWebText -Url ($base + '/install.ps1.sha256')
    if (-not (Test-FaiSha256 -Path $Destination -HashText $hashText)) {
        Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
        throw 'SHA-256 doğrulaması BAŞARISIZ: indirilen install.ps1 yayımlanan özetle eşleşmiyor; çalıştırılmadı.'
    }
    Write-Host 'SHA-256 doğrulandı.' -ForegroundColor Green
    return $Destination
}

function Resolve-FaiProfile {
    <#
    .SYNOPSIS
        -Profile değeri → Profile: https URL (indirilir), var olan / .json ile biten yol, yoksa gömülü profil adı.
        Düz http reddedilir.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [string] $Spec)

    if ($Spec -match '^https://') {
        $text = Get-FaiWebText -Url $Spec
        return [Profile]::FromHashtable((ConvertFrom-JsonText -Json $text.TrimStart([char]0xFEFF)), $Spec)
    }
    if ($Spec -match '^[a-zA-Z][a-zA-Z0-9+.-]*://') { throw "Profil URL'si yalnız https olabilir: $Spec" }
    if ((Test-Path -LiteralPath $Spec -PathType Leaf) -or $Spec -like '*.json') { return Import-FaiProfileFile -Path $Spec }
    return Import-FaiEmbeddedProfile -Name $Spec
}

function Select-FaiProfileItem {
    <#
    .SYNOPSIS
        Profili -Only / -Skip ile süzer (yeni Profile döndürür). Kimlikler: tweak Id, uygulama 'app.<id>',
        oyunlar 'gaming.per-game', düzen 'layout.profile'. Only boşsa hepsi; Skip her zaman çıkarır.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [Profile] $FaiProfile,
        [string[]] $Only = @(),
        [string[]] $Skip = @()
    )

    $p = [Profile]::new()
    $p.Name = $FaiProfile.Name
    $p.Description = $FaiProfile.Description
    $p.AutoConfirm = $FaiProfile.AutoConfirm
    $p.Exceptions = $FaiProfile.Exceptions
    $tweaks = New-Object 'System.Collections.Generic.List[hashtable]'
    foreach ($t in $FaiProfile.Tweaks) { if (Test-FaiKeepId -Id ([string]$t['Id']) -Only $Only -Skip $Skip) { $tweaks.Add($t) } }
    $p.Tweaks = $tweaks.ToArray()
    $apps = New-Object 'System.Collections.Generic.List[hashtable]'
    foreach ($a in $FaiProfile.Apps) { if (Test-FaiKeepId -Id ('app.' + [string]$a['Id']) -Only $Only -Skip $Skip) { $apps.Add($a) } }
    $p.Apps = $apps.ToArray()
    if (Test-FaiKeepId -Id 'gaming.per-game' -Only $Only -Skip $Skip) { $p.Games = $FaiProfile.Games }
    if (Test-FaiKeepId -Id 'layout.profile' -Only $Only -Skip $Skip) { $p.Layout = $FaiProfile.Layout }
    return $p
}

function Test-FaiKeepId {
    <# .SYNOPSIS  Kimlik -Only / -Skip süzgecinden geçer mi (Skip her zaman çıkarır; Only boşsa hepsi). #>
    param([string] $Id, [string[]] $Only = @(), [string[]] $Skip = @())
    if (@($Skip) -contains $Id) { return $false }
    return (@($Only).Count -eq 0 -or @($Only) -contains $Id)
}

function New-FaiSelectionProfile {
    <#
    .SYNOPSIS
        Kimlik listesinden geçici profil ('secim'): 'app.<id>' uygulama, diğerleri tweak. Bilinmeyen kimlik hata.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string[]] $Ids,
        [Parameter(Mandatory = $true)] [hashtable] $Catalog,
        [hashtable] $AppCatalog = @{},
        [string] $Name = 'secim'
    )

    $tweaks = New-Object 'System.Collections.Generic.List[hashtable]'
    $apps = New-Object 'System.Collections.Generic.List[hashtable]'
    $unknown = New-Object 'System.Collections.Generic.List[string]'
    foreach ($id in $Ids) {
        if ($id -like 'app.*') {
            $appId = $id.Substring(4)
            if ($AppCatalog.ContainsKey($appId)) { $apps.Add(@{ Id = $appId; KeepAutostart = $false }) }
            else { $unknown.Add($id) }
        }
        elseif ($Catalog.ContainsKey($id)) { $tweaks.Add(@{ Id = $id; Params = @{} }) }
        else { $unknown.Add($id) }
    }
    if ($unknown.Count -gt 0) { throw ('Bilinmeyen kimlik: {0} (-List ile bakın)' -f ($unknown -join ', ')) }
    $p = [Profile]::new()
    $p.Name = $Name
    $p.Tweaks = $tweaks.ToArray()
    $p.Apps = $apps.ToArray()
    return $p
}

function Get-FaiStatusColor {
    param([string] $Status)
    switch ($Status) {
        'Applied' { return 'Green' }
        'Planned' { return 'Cyan' }
        'UpToDate' { return 'DarkGray' }
        'Skipped' { return 'Yellow' }
        'Failed' { return 'Red' }
        'Reverted' { return 'Magenta' }
    }
    return 'Gray'
}

function Write-FaiReport {
    <# .SYNOPSIS  Raporu durum renkleriyle basar (Reporter.Render ile aynı içerik); Logger verilirse günlüğe de yazar. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [Reporter] $Report,
        [Logger] $Logger
    )

    if ($null -ne $Logger) { $Logger.Block($Report.Render()) }

    Write-Host ''
    Write-Host $Report.Heading -ForegroundColor White
    foreach ($i in $Report.Items) {
        $line = '  [{0}] {1} — {2}' -f [Reporter]::StatusLabel($i.Status), $i.TweakId, $i.Title
        if ($i.Reason) { $line += ' (' + $i.Reason + ')' }
        Write-Host $line -ForegroundColor (Get-FaiStatusColor $i.Status)
        foreach ($l in $i.Lines) { Write-Host ('      · ' + $l) }
    }
    $color = 'Green'
    if ($Report.HasFailures()) { $color = 'Red' }
    Write-Host $Report.Summary() -ForegroundColor $color
}

function Show-FaiList {
    <# .SYNOPSIS  -List: kategori sırasıyla tweak'ler (risk renkli), uygulamalar, gömülü profiller. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [hashtable] $Catalog,
        [hashtable] $AppCatalog = @{}
    )

    foreach ($cat in (Get-FaiMenuCategory -Catalog $Catalog)) {
        Write-Host ''
        Write-Host ('{0} ({1})' -f $cat.Label, $cat.Name) -ForegroundColor White
        foreach ($t in $cat.Tweaks) {
            $tags = @($t.Risk)
            if ($t.Tool) { $tags += 'araç' }
            if ($t.AlwaysConfirm) { $tags += 'her seferinde sorar' }
            Write-Host ('  {0,-28} {1}  [{2}]' -f $t.Id, $t.Title, ($tags -join ', ')) -ForegroundColor (Get-FaiRiskColor $t.Risk)
        }
    }
    if ($AppCatalog.Count -gt 0) {
        Write-Host ''
        Write-Host 'Uygulamalar (app.<id>)' -ForegroundColor White
        foreach ($k in @($AppCatalog.Keys | Sort-Object)) {
            Write-Host ('  app.{0,-24} {1}  [{2}]' -f $k, $AppCatalog[$k]['name'], $AppCatalog[$k]['source'])
        }
    }
    Write-Host ''
    Write-Host ('Gömülü profiller: {0}' -f ((Get-FaiEmbeddedProfileName) -join ', ')) -ForegroundColor White
}

function Export-FaiProfile {
    <#
    .SYNOPSIS
        Bu makinenin durumunu profil olarak dışa aktarır: hedef durumu ZATEN sağlanan tweak'ler (araçlar hariç,
        varsayılan parametrelerle), kurulu katalog uygulamaları ve düzen (Export-FaiLayout). Hiçbir şey değişmez
        (motor dry-run + Unattended koşar). Profil doğrulanıp yazılır; hashtable döndürür.
    .PARAMETER Name
        Profil adı (küçük harf, rakam, tire).
    .PARAMETER Path
        Yazılacak .json yolu (boşsa yazılmaz).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [ExecutionContext] $Context,
        [Parameter(Mandatory = $true)] [hashtable] $Catalog,
        [hashtable] $AppCatalog = @{},
        [Parameter(Mandatory = $true)] [string] $Name,
        [string] $Path = ''
    )

    $probe = [Profile]::new()
    $probe.Name = $Name
    $ids = @($Catalog.Keys | Where-Object { -not $Catalog[$_].Tool } | Sort-Object)
    $probe.Tweaks = @($ids | ForEach-Object { @{ Id = [string]$_; Params = @{} } })
    $probe.Apps = @($AppCatalog.Keys | Sort-Object | ForEach-Object { @{ Id = [string]$_; KeepAutostart = $false } })

    $wasDry = $Context.DryRun
    $wasUnattended = $Context.Unattended
    $Context.DryRun = $true
    $Context.Unattended = $true
    try { $report = Invoke-FaiEngine -FaiProfile $probe -Context $Context -Catalog $Catalog -AppCatalog $AppCatalog }
    finally {
        $Context.DryRun = $wasDry
        $Context.Unattended = $wasUnattended
    }

    $tweaks = New-Object 'System.Collections.Generic.List[string]'
    $apps = New-Object 'System.Collections.Generic.List[string]'
    foreach ($item in $report.Items) {
        if ($item.Status -ne 'UpToDate') { continue }
        if ($item.TweakId -like 'app.*') { $apps.Add($item.TweakId.Substring(4)) }
        elseif ($Catalog.ContainsKey($item.TweakId)) { $tweaks.Add($item.TweakId) }
    }

    $layout = @{}
    try { $layout = (Export-FaiLayout -Context $Context).Layout }
    catch { Write-Host ('UYARI: düzen okunamadı, profile girmedi: {0}' -f $_.Exception.Message) -ForegroundColor Yellow }

    $data = [ordered]@{
        name        = $Name
        description = ('FAI_WinOP -ExportProfile ile {0} tarihinde dışa aktarıldı.' -f (Get-Date -Format 'yyyy-MM-dd'))
        tweaks      = $tweaks.ToArray()
        autoConfirm = @()
        apps        = $apps.ToArray()
        games       = @()
        layout      = $layout
        exceptions  = @{}
    }
    $check = @{}
    foreach ($k in $data.Keys) { $check[$k] = $data[$k] }
    $errors = @(Get-FaiProfileError -Data $check)
    if ($errors.Count -gt 0) { throw ("Dışa aktarılan profil geçersiz:`n  " + ($errors -join "`n  ")) }

    if ($Path) {
        $full = [System.IO.Path]::GetFullPath($Path)
        $dir = [System.IO.Path]::GetDirectoryName($full)
        if ($dir -and -not [System.IO.Directory]::Exists($dir)) { [void][System.IO.Directory]::CreateDirectory($dir) }
        $json = ($data | ConvertTo-Json -Depth 20) -replace "`r`n", "`n"
        [System.IO.File]::WriteAllText($full, $json + "`n", (New-Object System.Text.UTF8Encoding($false)))
    }
    return $check
}

function Resolve-FaiExportTarget {
    <#
    .SYNOPSIS  -ExportProfile değeri → @{ Name; Path }: .json yolu ya da ad (Belgeler\FAI_WinOP\<ad>.json).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $Spec,
        [string] $DefaultDir = ''
    )

    if ($Spec -like '*.json' -or $Spec.Contains('\') -or $Spec.Contains('/')) {
        $path = [System.IO.Path]::GetFullPath($Spec)
        $base = [System.IO.Path]::GetFileNameWithoutExtension($path)
    }
    else {
        if (-not $DefaultDir) { $DefaultDir = Get-FaiDocumentsDir }
        $base = $Spec
        $path = Join-Path $DefaultDir ($Spec + '.json')
    }
    $name = ($base.ToLowerInvariant() -replace '[^a-z0-9-]', '-').Trim('-')
    if (-not $name -or $name -notmatch '^[a-z0-9][a-z0-9-]*$') { throw "Geçersiz profil adı: $Spec" }
    return @{ Name = $name; Path = $path }
}

function Get-FaiResumeCommand {
    <#
    .SYNOPSIS
        Yeniden başlatma sonrası devam komutu (HKLM RunOnce): betiği %ProgramData%\FAI_WinOP\install.ps1'e kopyalar,
        aynı parametrelerle (yerel profil yolu mutlak) çalıştıran powershell.exe satırını döndürür.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $ScriptPath,
        [Parameter(Mandatory = $true)] [System.Collections.IDictionary] $Bound,
        [string] $DataDir = ''
    )

    if (-not $DataDir) { $DataDir = Get-FaiDataDir }
    $target = Join-Path $DataDir 'install.ps1'
    if (-not (Test-Path -LiteralPath $DataDir)) { [void](New-Item -ItemType Directory -Path $DataDir -Force) }
    if ([System.IO.Path]::GetFullPath($ScriptPath) -ne [System.IO.Path]::GetFullPath($target)) {
        Copy-Item -LiteralPath $ScriptPath -Destination $target -Force
    }
    $args2 = ConvertTo-FaiArgumentString -Bound $Bound -Exclude @('Version')
    return ('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{0}" {1}' -f $target, $args2).TrimEnd()
}

function Invoke-FaiElevated {
    <#
    .SYNOPSIS
        Betiği yönetici olarak (UAC) aynı parametrelerle yeni pencerede başlatır. Pencere açık kalır (-NoExit: rapor
        okunur); bu süreç beklemez. UAC reddedilirse 3.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $ScriptPath,
        [Parameter(Mandatory = $true)] [System.Collections.IDictionary] $Bound
    )

    $argLine = '-NoProfile -ExecutionPolicy Bypass -NoExit -File "{0}" {1}' -f $ScriptPath, (ConvertTo-FaiArgumentString -Bound $Bound)
    Write-Host 'Yönetici izni isteniyor (UAC)...' -ForegroundColor Yellow
    try { Start-Process -FilePath 'powershell.exe' -ArgumentList $argLine -Verb RunAs | Out-Null }
    catch {
        Write-Host ('Yükseltme reddedildi ya da başarısız: {0}' -f $_.Exception.Message) -ForegroundColor Red
        return 3
    }
    Write-Host 'Yönetici penceresinde sürüyor.'
    return 0
}

function Invoke-FaiCli {
    <#
    .SYNOPSIS
        install.ps1 parametrelerini işler; çıkış kodu döndürür.
    .PARAMETER Bound
        Giriş betiğinin $PSBoundParameters'ı (Profile, DryRun, Unattended, Undo, Session, Only, Skip, UpdatesOn,
        UpdatesOff, ExportProfile, ExportLayout, Version, List).
    .PARAMETER ScriptPath
        Betik dosyası (irm | iex ile çalıştıysa boş): yükseltme ve yeniden başlatma sonrası devam için.
    .PARAMETER Context
        Testler: hazır bağlam (verilirse yükseltme denetimi yapılmaz, Windows bağlamı kurulmaz).
    .PARAMETER Catalog
        Testler: tweak kataloğu (boşsa gömülü veri).
    .PARAMETER AppCatalog
        Testler: uygulama kataloğu (Catalog verildiyse bu da kullanılır; boş olabilir).
    #>
    [CmdletBinding()]
    param(
        [System.Collections.IDictionary] $Bound = @{},
        [string] $ScriptPath = '',
        [ExecutionContext] $Context,
        [hashtable] $Catalog,
        [hashtable] $AppCatalog
    )

    # Giriş betiği -Profile'ı FaiProfile adıyla bağlar; içeride (ve yeniden başlatma satırında) 'Profile' kullanılır.
    $o = @{}
    foreach ($k in @($Bound.Keys)) {
        $name = [string]$k
        if ($name -eq 'FaiProfile') { $name = 'Profile' }
        $o[$name] = $Bound[$k]
    }
    $flag = { param([string] $Name) return ($o.ContainsKey($Name) -and [bool]$o[$Name]) }
    $text = { param([string] $Name) if ($o.ContainsKey($Name)) { return [string]$o[$Name] } return '' }
    $only = Split-FaiList -Items @($o['Only'])
    $skip = Split-FaiList -Items @($o['Skip'])
    $profileSpec = & $text 'Profile'

    Write-Host ('FAI_WinOP {0}' -f $script:FaiWinOPVersion) -ForegroundColor White

    # Kullanım denetimi: tek bir ana iş.
    $modes = @()
    if (& $flag 'List') { $modes += '-List' }
    if (& $flag 'Undo') { $modes += '-Undo' }
    if ((& $flag 'UpdatesOn') -or (& $flag 'UpdatesOff')) { $modes += '-UpdatesOn/-UpdatesOff' }
    if (& $text 'ExportProfile') { $modes += '-ExportProfile' }
    if (& $flag 'ExportLayout') { $modes += '-ExportLayout' }
    $problem = ''
    if ($modes.Count -gt 1) { $problem = 'Birlikte kullanılamaz: ' + ($modes -join ', ') }
    elseif ((& $flag 'UpdatesOn') -and (& $flag 'UpdatesOff')) { $problem = '-UpdatesOn ve -UpdatesOff birlikte kullanılamaz' }
    elseif ($modes.Count -eq 1 -and $modes[0] -ne '-ExportLayout' -and ($profileSpec -or $only.Count -gt 0 -or $skip.Count -gt 0)) {
        $problem = "$($modes[0]) ile -Profile / -Only / -Skip kullanılamaz"
    }
    elseif ((& $text 'Session') -and -not (& $flag 'Undo')) { $problem = '-Session yalnız -Undo ile' }
    elseif ($skip.Count -gt 0 -and -not $profileSpec) { $problem = '-Skip yalnız -Profile ile' }
    elseif ($modes.Count -eq 0 -and -not $profileSpec -and $only.Count -eq 0 -and (& $flag 'Unattended')) {
        $problem = 'Menü -Unattended ile açılamaz: -Profile ya da -Only verin'
    }
    if ($problem) {
        Write-Host $problem -ForegroundColor Red
        Write-Host 'Yardım: Get-Help .\install.ps1 -Detailed'
        return 2
    }

    try {
        # Başka sürüm: indir, doğrula, onunla çalıştır (kendi yükseltmesini kendisi yapar).
        $wanted = & $text 'Version'
        if ($wanted -and $wanted.TrimStart('v') -ne ([string]$script:FaiWinOPVersion).TrimStart('v')) {
            if ($wanted -notmatch '^v?\d+\.\d+\.\d+$') { Write-Host "Geçersiz sürüm: $wanted (vX.Y.Z)" -ForegroundColor Red; return 2 }
            $tag = 'v' + $wanted.TrimStart('v')
            $dest = Join-Path $env:TEMP ('FAI_WinOP\install-{0}.ps1' -f $tag)
            $path = Get-FaiVerifiedScript -BaseUrl ('{0}/releases/download/{1}' -f (Get-FaiRepoUrl), $tag) -Destination $dest
            $argLine = ConvertTo-FaiArgumentString -Bound $o -Exclude @('Version')
            $p = Start-Process -FilePath 'powershell.exe' -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "{0}" {1}' -f $path, $argLine) -NoNewWindow -PassThru -Wait
            return [int]$p.ExitCode
        }

        $injected = $null -ne $Context
        if ($null -eq $Catalog) {
            $Catalog = Import-FaiEmbeddedTweakCatalog
            if ($null -eq $AppCatalog) { $AppCatalog = Import-FaiEmbeddedAppCatalog }
        }
        if ($null -eq $AppCatalog) { $AppCatalog = @{} }

        if (& $flag 'List') {
            Show-FaiList -Catalog $Catalog -AppCatalog $AppCatalog
            return 0
        }

        $needsAdmin = -not ((& $text 'ExportProfile') -or (& $flag 'ExportLayout'))
        if ($needsAdmin -and -not $injected -and -not (Test-FaiIsAdmin)) {
            if ($ScriptPath) { return (Invoke-FaiElevated -ScriptPath $ScriptPath -Bound $o) }
            Write-Host 'Yönetici yetkisi gerekiyor. Yönetici PowerShell açın ya da doğrulamalı tek satırı kullanın:' -ForegroundColor Red
            Write-Host ('  & ([scriptblock]::Create((irm {0}/releases/latest/download/get.ps1)))' -f (Get-FaiRepoUrl))
            return 3
        }

        if (-not $injected) {
            $logDir = Join-Path (Get-FaiDataDir) 'logs'
            if (-not (Test-Path -LiteralPath $logDir)) { [void](New-Item -ItemType Directory -Path $logDir -Force) }
            $logPath = Join-Path $logDir ((Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
            $Context = New-FaiWindowsContext -LogPath $logPath
            Write-Host ('Günlük: {0}' -f $logPath) -ForegroundColor DarkGray
        }
        $Context.DryRun = (& $flag 'DryRun')
        $Context.Unattended = (& $flag 'Unattended')

        $exportName = & $text 'ExportProfile'
        if ($exportName) {
            $target = Resolve-FaiExportTarget -Spec $exportName
            $data = Export-FaiProfile -Context $Context -Catalog $Catalog -AppCatalog $AppCatalog -Name $target.Name -Path $target.Path
            Write-Host ('Profil yazıldı: {0}' -f $target.Path) -ForegroundColor Green
            Write-Host ('  {0} tweak, {1} uygulama, düzen: {2}' -f @($data['tweaks']).Count, @($data['apps']).Count, ($data['layout'].Count -gt 0))
            return 0
        }

        if (& $flag 'ExportLayout') {
            $layoutPath = Join-Path (Get-FaiDocumentsDir) 'layout.json'
            if ($profileSpec) {
                if ($profileSpec -notlike '*.json') { Write-Host '-ExportLayout ile -Profile bir .json yolu olmalı' -ForegroundColor Red; return 2 }
                $layoutPath = [System.IO.Path]::GetFullPath($profileSpec)
            }
            [void](Invoke-FaiExportLayout -ProfilePath $layoutPath -Context $Context)
            return 0
        }

        $report = $null
        if (& $flag 'Undo') {
            $report = Invoke-FaiEngine -Undo -Session (& $text 'Session') -Context $Context -Catalog $Catalog -AppCatalog $AppCatalog
        }
        elseif ((& $flag 'UpdatesOn') -or (& $flag 'UpdatesOff')) {
            if (& $flag 'UpdatesOn') { $report = Invoke-FaiUpdatesSwitch -Context $Context -On }
            else { $report = Invoke-FaiUpdatesSwitch -Context $Context -Off }
        }
        elseif ($profileSpec -or $only.Count -gt 0) {
            if ($profileSpec) {
                $fp = Select-FaiProfileItem -FaiProfile (Resolve-FaiProfile -Spec $profileSpec) -Only $only -Skip $skip
            }
            else { $fp = New-FaiSelectionProfile -Ids $only -Catalog $Catalog -AppCatalog $AppCatalog }
            if ($ScriptPath -and -not $Context.DryRun -and -not $injected) {
                $resume = @{}
                foreach ($k in $o.Keys) { $resume[$k] = $o[$k] }
                if ($profileSpec -and (Test-Path -LiteralPath $profileSpec -PathType Leaf)) {
                    $resume['Profile'] = (Resolve-Path -LiteralPath $profileSpec).Path
                }
                $Context.ResumeCommand = Get-FaiResumeCommand -ScriptPath $ScriptPath -Bound $resume
            }
            $report = Invoke-FaiEngine -FaiProfile $fp -Context $Context -Catalog $Catalog -AppCatalog $AppCatalog -AllowTools:($only.Count -gt 0)
        }
        else {
            return (Invoke-FaiMenu -Context $Context -Catalog $Catalog -AppCatalog $AppCatalog)
        }

        Write-FaiReport -Report $report -Logger $Context.Logger
        if ($report.HasFailures()) { return 1 }
        return 0
    }
    catch {
        Write-Host ('HATA: {0}' -f $_.Exception.Message) -ForegroundColor Red
        return 1
    }
}

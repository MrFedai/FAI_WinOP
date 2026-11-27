<#
.SYNOPSIS
    src/ altındaki kaynakları bağımlılık sırasıyla tek bir install.ps1'e birleştirir.

.DESCRIPTION
    PowerShell 5.1'de sınıflar 'using module' ister; 'irm | iex' akışında bu çalışmaz. Bu yüzden bütün sınıflar
    tek script'te, parse anında tipleri bilinecek sırayla birleştirilir:
        Entry.ps1 param bloğu (betiğin ilk deyimi olmalı) → Core (Interfaces ilk, sonra aşağıdaki açık sıra) →
        Actions/* → Native/*.cs (gömülü) → Providers/Windows/* → [Providers/Fake/*] → Engine.ps1 → Menu.ps1 → Cli.ps1 →
        gömülü veri (Get-FaiEmbeddedData) → Entry.ps1'in param bloğundan sonraki kısmı (CLI çağrısı)
    Core içinde sıra alfabetik DEĞİL, bağımlılık sırasıdır ($coreOrder): bir sınıf yalnız kendinden önce
    tanımlı sınıfları alan / parametre türü olarak kullanabilir. Listede olmayan Core dosyası sona eklenir.

    Native/*.cs (C#) bundle'a metin olarak gömülür: Get-FaiNativeSource -Name <dosya adı, uzantısız> kaynağı döndürür;
    Windows sağlayıcıları onu Add-Type ile derler. Kaynakta satır başında '@ olamaz (here-string sonu).

    Providers/Fake/* yalnız testler içindir: üretim bundle'ına GİRMEZ; -IncludeFakes ile ayrı bir çıktıya
    (varsayılan dist/install.fakes.ps1) Windows sağlayıcılarından sonra, Engine'den önce eklenir.

    Veri (tweaks/**/*.psd1, apps/catalog.json, profiles/*.json; _schema.json hariç) gömülür: Get-FaiEmbeddedData
    yol → metin döndürür (gerekçe: src/Core/Data.ps1). Satır başında '@ içeren dosya here-string'e sığmaz: base64.

    Çıktı UTF-8 BOM'lu ve CRLF. Üretim bundle'ının yanına <çıktı>.sha256 yazılır (sha256sum biçimi: '<hex>  <ad>');
    release.yml bunu yayınlar, önyükleyici (src/Bootstrap/get.ps1) ve -Version doğrular.

.PARAMETER OutFile
    Çıktı yolu. Varsayılan dist/install.ps1 (-IncludeFakes ile dist/install.fakes.ps1).

.PARAMETER Version
    Bundle'a yazılan sürüm. Varsayılan 0.0.0-dev.

.PARAMETER IncludeFakes
    Fake* sağlayıcılarını da ekler (testler ve Engine-Smoke için; yayınlanmaz).

.EXAMPLE
    pwsh -NoProfile -File build/Bundle.ps1
    pwsh -NoProfile -File build/Bundle.ps1 -IncludeFakes
    powershell.exe -NoProfile -File build\Bundle.ps1 -Version v0.1.0
#>
[CmdletBinding()]
param(
    [string] $OutFile,
    [string] $Version = '0.0.0-dev',
    [switch] $IncludeFakes
)

$ErrorActionPreference = 'Stop'
# Sürüm üretilen betiğe tek tırnaklı metin olarak yazılır: biçimi doğrula (tırnak / enjeksiyon olmasın).
if ($Version -notmatch '^v?\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?$') { throw "Invalid -Version: '$Version' (expected: 0.1.2, v0.1.2 or 0.0.0-dev)" }
$repoRoot = Split-Path -Parent $PSScriptRoot
$src = Join-Path $repoRoot 'src'
if (-not $OutFile) {
    $name = 'install.ps1'
    if ($IncludeFakes) { $name = 'install.fakes.ps1' }
    $OutFile = Join-Path (Join-Path $repoRoot 'dist') $name
}

# Core bağımlılık sırası (sınıf alanı / parametre türü olarak kullanılan sınıf önce tanımlı olmalı).
$coreOrder = @(
    'Interfaces.ps1', 'Json.ps1', 'Logger.ps1', 'BackupStore.ps1', 'Condition.ps1', 'ExecutionContext.ps1',
    'RiskPolicy.ps1', 'ActionBase.ps1', 'Tweak.ps1', 'Profile.ps1', 'Reporter.ps1', 'Schema.ps1'
)

function Get-SourceFile([string] $Relative) {
    $full = Join-Path $src $Relative
    if (Test-Path -LiteralPath $full -PathType Leaf) { return @(Get-Item -LiteralPath $full) }
    return @()
}

function Get-SourceDir([string] $Relative, [string[]] $Skip) {
    $full = Join-Path $src $Relative
    if (-not (Test-Path -LiteralPath $full -PathType Container)) { return @() }
    return @(Get-ChildItem -LiteralPath $full -Filter '*.ps1' -File |
            Where-Object { $Skip -notcontains $_.Name } |
            Sort-Object Name)
}

# Giriş: param bloğu (yardım yorumu dahil) betiğin başına, geri kalanı (CLI çağrısı) sonuna.
function Split-EntryFile {
    $path = Join-Path $src 'Entry.ps1'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @{ Head = ''; Tail = '' } }
    $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8).TrimStart([char]0xFEFF) -replace "`r?`n", "`n"
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$tokens, [ref]$errors)
    if ($errors -and $errors.Count -gt 0) { throw "src/Entry.ps1 could not be parsed: $($errors[0].Message)" }
    if ($null -eq $ast.ParamBlock) { throw 'src/Entry.ps1: no param block' }
    $end = $ast.ParamBlock.Extent.EndOffset
    return @{ Head = $text.Substring(0, $end).TrimEnd(); Tail = $text.Substring($end).Trim() }
}

# Bağımlılık sırası (bkz. docs/ROADMAP.md 1.3).
$ordered = @()
foreach ($coreFile in $coreOrder) { $ordered += Get-SourceFile ('Core/' + $coreFile) }
$ordered += Get-SourceDir 'Core' $coreOrder
$ordered += Get-SourceDir 'Actions' @()
# Native/*.cs: sırayı korumak için yer tutucu (aşağıda gömülü fonksiyon olarak yazılır).
$nativeMarker = 'NATIVE'
$ordered += $nativeMarker
$ordered += Get-SourceDir 'Providers/Windows' @()
if ($IncludeFakes) { $ordered += Get-SourceDir 'Providers/Fake' @() }
$ordered += Get-SourceFile 'Engine.ps1'
$ordered += Get-SourceFile 'Menu.ps1'
$ordered += Get-SourceFile 'Cli.ps1'

# Native C# kaynaklarını tek fonksiyonda here-string olarak gömer.
function Get-NativeRegion([string] $Nl) {
    $dir = Join-Path $src 'Native'
    $files = @()
    if (Test-Path -LiteralPath $dir -PathType Container) { $files = @(Get-ChildItem -LiteralPath $dir -Filter '*.cs' -File | Sort-Object Name) }
    $b = New-Object System.Text.StringBuilder
    [void]$b.Append($Nl + '#region src/Native (embedded C#)' + $Nl)
    [void]$b.Append('function Get-FaiNativeSource {' + $Nl)
    [void]$b.Append('    <# .SYNOPSIS  src/Native/<Name>.cs source (embedded in the bundle; compiled with Add-Type). #>' + $Nl)
    [void]$b.Append('    [CmdletBinding()]' + $Nl + '    param([Parameter(Mandatory = $true)] [string] $Name)' + $Nl)
    [void]$b.Append('    switch ($Name) {' + $Nl)
    foreach ($f in $files) {
        $code = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8).TrimStart([char]0xFEFF)
        $code = ($code -replace "`r?`n", $Nl).TrimEnd()
        if ($code -match "(^|`n)'@") { throw "src/Native/$($f.Name): '@ is not allowed at the start of a line (here-string terminator)" }
        $name = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
        Write-Host ("        embedded: src/Native/{0}" -f $f.Name)
        [void]$b.Append("        '$name' {" + $Nl + "            return @'" + $Nl + $code + $Nl + "'@" + $Nl + '        }' + $Nl)
    }
    [void]$b.Append('        default { throw "Embedded native source not found: $Name" }' + $Nl + '    }' + $Nl + '}' + $Nl)
    [void]$b.Append('#endregion src/Native' + $Nl)
    return $b.ToString()
}

# Veri dosyalarını tek fonksiyonda gömer (yol → metin).
function Get-DataRegion([string] $Nl) {
    $files = @()
    $tw = Join-Path $repoRoot 'tweaks'
    if (Test-Path -LiteralPath $tw -PathType Container) { $files += @(Get-ChildItem -LiteralPath $tw -Recurse -File -Filter '*.psd1') }
    $cat = Join-Path $repoRoot 'apps/catalog.json'
    if (Test-Path -LiteralPath $cat -PathType Leaf) { $files += @(Get-Item -LiteralPath $cat) }
    $pr = Join-Path $repoRoot 'profiles'
    if (Test-Path -LiteralPath $pr -PathType Container) {
        $files += @(Get-ChildItem -LiteralPath $pr -File -Filter '*.json' | Where-Object { -not $_.Name.StartsWith('_') })
    }
    $b = New-Object System.Text.StringBuilder
    [void]$b.Append($Nl + '#region data (embedded: tweaks, apps/catalog.json, profiles)' + $Nl)
    [void]$b.Append('function Get-FaiEmbeddedData {' + $Nl)
    [void]$b.Append('    <# .SYNOPSIS  Embedded data files: repo path → UTF-8 text (generated by build/Bundle.ps1). #>' + $Nl)
    [void]$b.Append('    [CmdletBinding()]' + $Nl + '    param()' + $Nl + '    $d = @{}' + $Nl)
    $rels = @()
    foreach ($f in $files) { $rels += $f.FullName.Substring($repoRoot.Length).TrimStart('/', '\').Replace('\', '/') }
    $n = 0
    foreach ($rel in @($rels | Sort-Object)) {
        $full = Join-Path $repoRoot $rel
        $text = [System.IO.File]::ReadAllText($full, [System.Text.Encoding]::UTF8).TrimStart([char]0xFEFF)
        $text = ($text -replace "`r?`n", $Nl).TrimEnd()
        if ($rel.Contains("'")) { throw "Data path cannot contain a quote: $rel" }
        if ($text -match "(^|`n)'@") {
            $b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($text))
            [void]$b.Append("    `$d['$rel'] = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$b64'))" + $Nl)
        }
        else {
            [void]$b.Append("    `$d['$rel'] = @'" + $Nl + $text + $Nl + "'@" + $Nl)
        }
        $n++
    }
    [void]$b.Append('    return $d' + $Nl + '}' + $Nl + '#endregion veri' + $Nl)
    Write-Host ("  embedded data: {0} files" -f $n)
    return $b.ToString()
}

$entry = Split-EntryFile
$nl = "`r`n"
$sb = New-Object System.Text.StringBuilder
[void]$sb.Append('# FAI_WinOP install.ps1 — GENERATED FILE, do not edit by hand (build/Bundle.ps1).' + $nl)
[void]$sb.Append('# https://github.com/MrFedai/FAI_WinOP · MIT' + $nl)
[void]$sb.Append("# Version: $Version" + $nl)
if ($IncludeFakes) { [void]$sb.Append('# WARNING: contains Fake* providers (test only); not published.' + $nl) }
[void]$sb.Append($nl)
if ($entry.Head) { [void]$sb.Append(($entry.Head -replace "`n", $nl) + $nl + $nl) }
[void]$sb.Append("`$script:FaiWinOPVersion = '$Version'" + $nl)

Write-Host ("Bundle: {0} source files" -f $ordered.Count)
$i = 0
foreach ($f in $ordered) {
    $i++
    if ($f -is [string] -and $f -eq $nativeMarker) {
        Write-Host ("  [{0}/{1}] src/Native/*.cs" -f $i, $ordered.Count)
        [void]$sb.Append((Get-NativeRegion $nl))
        continue
    }
    $rel = $f.FullName.Substring($src.Length).TrimStart('/', '\').Replace('\', '/')
    Write-Host ("  [{0}/{1}] src/{2}" -f $i, $ordered.Count, $rel)
    $text = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
    $text = $text.TrimStart([char]0xFEFF) -replace "`r?`n", $nl
    [void]$sb.Append($nl + "#region src/$rel" + $nl + $text.TrimEnd() + $nl + "#endregion src/$rel" + $nl)
}

[void]$sb.Append((Get-DataRegion $nl))
if ($entry.Tail) { [void]$sb.Append($nl + '#region src/Entry.ps1 (entry)' + $nl + ($entry.Tail -replace "`n", $nl) + $nl + '#endregion src/Entry.ps1' + $nl) }

$outDir = Split-Path -Parent $OutFile
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
$utf8Bom = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($OutFile, $sb.ToString(), $utf8Bom)

# Üretilen dosya ayrıştırılabilmeli.
$tokens = $null
$errors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($OutFile, [ref]$tokens, [ref]$errors)
if ($errors -and $errors.Count -gt 0) {
    foreach ($e in $errors) { Write-Host ("  {0}: {1}" -f $e.Extent.StartLineNumber, $e.Message) -ForegroundColor Red }
    throw "Bundle could not be parsed: $OutFile"
}

Write-Host ("Bundle written: {0} ({1} bytes, version {2})" -f $OutFile, (Get-Item -LiteralPath $OutFile).Length, $Version) -ForegroundColor Green

# Yayın / önyükleyici doğrulaması için SHA-256 (yalnız üretim bundle'ı).
if (-not $IncludeFakes) {
    $hash = (Get-FileHash -LiteralPath $OutFile -Algorithm SHA256).Hash.ToLowerInvariant()
    $hashFile = $OutFile + '.sha256'
    [System.IO.File]::WriteAllText($hashFile, ('{0}  {1}' -f $hash, (Split-Path -Leaf $OutFile)) + "`n", (New-Object System.Text.UTF8Encoding($false)))
    Write-Host ("SHA-256: {0} → {1}" -f $hash, $hashFile)
}

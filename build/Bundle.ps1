<#
.SYNOPSIS
    src/ altındaki kaynakları bağımlılık sırasıyla tek bir install.ps1'e birleştirir.

.DESCRIPTION
    PowerShell 5.1'de sınıflar 'using module' ister; 'irm | iex' akışında bu çalışmaz. Bu yüzden bütün sınıflar
    tek script'te, parse anında tipleri bilinecek sırayla birleştirilir:
        Core (Interfaces ilk, sonra aşağıdaki açık sıra) → Actions/* → Native/*.cs (gömülü) → Providers/Windows/* →
        [Providers/Fake/*] → Engine.ps1 → Menu.ps1 → Cli.ps1
    Core içinde sıra alfabetik DEĞİL, bağımlılık sırasıdır ($coreOrder): bir sınıf yalnız kendinden önce
    tanımlı sınıfları alan / parametre türü olarak kullanabilir. Listede olmayan Core dosyası sona eklenir.

    Native/*.cs (C#) bundle'a metin olarak gömülür: Get-FaiNativeSource -Name <dosya adı, uzantısız> kaynağı döndürür;
    Windows sağlayıcıları onu Add-Type ile derler. Kaynakta satır başında '@ olamaz (here-string sonu).

    Providers/Fake/* yalnız testler içindir: üretim bundle'ına GİRMEZ; -IncludeFakes ile ayrı bir çıktıya
    (varsayılan dist/install.fakes.ps1) Windows sağlayıcılarından sonra, Engine'den önce eklenir.

    Çıktı UTF-8 BOM'lu ve CRLF. Veri gömme / indirme kararı Faz 8'de.

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
    [void]$b.Append($Nl + '#region src/Native (gömülü C#)' + $Nl)
    [void]$b.Append('function Get-FaiNativeSource {' + $Nl)
    [void]$b.Append('    <# .SYNOPSIS  src/Native/<Name>.cs kaynağı (bundle''a gömülü; Add-Type ile derlenir). #>' + $Nl)
    [void]$b.Append('    [CmdletBinding()]' + $Nl + '    param([Parameter(Mandatory = $true)] [string] $Name)' + $Nl)
    [void]$b.Append('    switch ($Name) {' + $Nl)
    foreach ($f in $files) {
        $code = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8).TrimStart([char]0xFEFF)
        $code = ($code -replace "`r?`n", $Nl).TrimEnd()
        if ($code -match "(^|`n)'@") { throw "src/Native/$($f.Name): satır başında '@ olamaz (here-string sonu)" }
        $name = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
        Write-Host ("        gömülü: src/Native/{0}" -f $f.Name)
        [void]$b.Append("        '$name' {" + $Nl + "            return @'" + $Nl + $code + $Nl + "'@" + $Nl + '        }' + $Nl)
    }
    [void]$b.Append('        default { throw "Gömülü native kaynak yok: $Name" }' + $Nl + '    }' + $Nl + '}' + $Nl)
    [void]$b.Append('#endregion src/Native' + $Nl)
    return $b.ToString()
}

$nl = "`r`n"
$sb = New-Object System.Text.StringBuilder
[void]$sb.Append('# FAI_WinOP install.ps1 — ÜRETİLMİŞ DOSYA, elle düzenlenmez (build/Bundle.ps1).' + $nl)
[void]$sb.Append('# https://github.com/MrFedai/FAI_WinOP · MIT' + $nl)
[void]$sb.Append("# Sürüm: $Version" + $nl)
if ($IncludeFakes) { [void]$sb.Append('# DİKKAT: Fake* sağlayıcıları içerir (yalnız test); yayınlanmaz.' + $nl) }
[void]$sb.Append($nl)
[void]$sb.Append("`$script:FaiWinOPVersion = '$Version'" + $nl)

Write-Host ("Bundle: {0} kaynak dosya" -f $ordered.Count)
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
    throw "Bundle ayrıştırılamadı: $OutFile"
}

Write-Host ("Bundle yazıldı: {0} ({1} bayt, sürüm {2})" -f $OutFile, (Get-Item -LiteralPath $OutFile).Length, $Version) -ForegroundColor Green

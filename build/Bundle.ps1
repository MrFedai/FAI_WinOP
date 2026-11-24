<#
.SYNOPSIS
    src/ altındaki kaynakları bağımlılık sırasıyla tek bir install.ps1'e birleştirir.

.DESCRIPTION
    PowerShell 5.1'de sınıflar 'using module' ister; 'irm | iex' akışında bu çalışmaz. Bu yüzden bütün sınıflar
    tek script'te, parse anında tipleri bilinecek sırayla birleştirilir:
        Core/Interfaces.ps1 → Core/* → Actions/* → Providers/Windows/* → Engine.ps1 → Menu.ps1 → Cli.ps1
    Providers/Fake/* yalnız testler içindir, bundle'a girmez.

    Faz 0: src/ boş; çıktı yalnız başlık + sürüm değişkeni. Veri gömme / indirme kararı Faz 8'de.
    Çıktı UTF-8 BOM'lu ve CRLF.

.PARAMETER OutFile
    Çıktı yolu. Varsayılan dist/install.ps1.

.PARAMETER Version
    Bundle'a yazılan sürüm. Varsayılan 0.0.0-dev.

.EXAMPLE
    pwsh -NoProfile -File build/Bundle.ps1
    powershell.exe -NoProfile -File build\Bundle.ps1 -Version v0.1.0
#>
[CmdletBinding()]
param(
    [string] $OutFile,
    [string] $Version = '0.0.0-dev'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$src = Join-Path $repoRoot 'src'
if (-not $OutFile) { $OutFile = Join-Path (Join-Path $repoRoot 'dist') 'install.ps1' }

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
$ordered += Get-SourceFile 'Core/Interfaces.ps1'
$ordered += Get-SourceDir 'Core' @('Interfaces.ps1')
$ordered += Get-SourceDir 'Actions' @()
$ordered += Get-SourceDir 'Providers/Windows' @()
$ordered += Get-SourceFile 'Engine.ps1'
$ordered += Get-SourceFile 'Menu.ps1'
$ordered += Get-SourceFile 'Cli.ps1'

$nl = "`r`n"
$sb = New-Object System.Text.StringBuilder
[void]$sb.Append('# FAI_WinOP install.ps1 — ÜRETİLMİŞ DOSYA, elle düzenlenmez (build/Bundle.ps1).' + $nl)
[void]$sb.Append('# https://github.com/MrFedai/FAI_WinOP · MIT' + $nl)
[void]$sb.Append("# Sürüm: $Version" + $nl + $nl)
[void]$sb.Append("`$script:FaiWinOPVersion = '$Version'" + $nl)

Write-Host ("Bundle: {0} kaynak dosya" -f $ordered.Count)
$i = 0
foreach ($f in $ordered) {
    $i++
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

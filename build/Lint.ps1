<#
.SYNOPSIS
    FAI_WinOP lint: PSScriptAnalyzer (PS 5.1 uyumluluk kuralları dahil) + UTF-8 BOM + 7'ye özgü işleç taraması.

.DESCRIPTION
    Parametresiz çağrı bütün depoyu tarar (tests/Fixtures, dist ve .git hariç).
    Her dosya için:
      1. UTF-8 BOM var mı (.ps1 / .psd1 / .psm1); yalnız ASCII baytlı dosyada BOM gerekmez (src/Bootstrap/get.ps1
         BOM'suz ASCII olmak zorunda: 5.1 irm charset'siz yanıtı ISO-8859-1 çözer, BOM bozulur)
      2. 5.1'de olmayan ?. ve ?[ işleçleri (belirteç taraması)
      3. Invoke-ScriptAnalyzer, ayar: build/PSScriptAnalyzerSettings.psd1
    Bulgu varsa listeler ve 1 ile çıkar; yoksa 0.

.PARAMETER Path
    Taranacak dosya ya da klasörler. Verilmezse depo kökü.

.EXAMPLE
    pwsh -NoProfile -File build/Lint.ps1
    pwsh -NoProfile -File build/Lint.ps1 -Path tests/Fixtures/Lint/NullCoalescing.ps1
#>
[CmdletBinding()]
param(
    [string[]] $Path,
    [string]   $Settings
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $Settings) { $Settings = Join-Path $PSScriptRoot 'PSScriptAnalyzerSettings.psd1' }

if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    throw 'PSScriptAnalyzer is missing. Install: Install-Module PSScriptAnalyzer -Scope CurrentUser'
}
Import-Module PSScriptAnalyzer

$explicit = $true
if (-not $Path -or $Path.Count -eq 0) {
    $Path = @($repoRoot)
    $explicit = $false
}

# Depo taramasında hariç tutulan klasörler (bilerek hatalı örnekler, üretilmiş çıktı).
$excluded = @(
    (Join-Path $repoRoot 'tests/Fixtures'),
    (Join-Path $repoRoot 'dist'),
    (Join-Path $repoRoot '.git')
) | ForEach-Object { [System.IO.Path]::GetFullPath($_) }

function Test-Excluded([string] $FullName) {
    foreach ($e in $excluded) {
        if ($FullName.StartsWith($e + [System.IO.Path]::DirectorySeparatorChar) -or $FullName -eq $e) { return $true }
    }
    return $false
}

$files = New-Object System.Collections.Generic.List[string]
foreach ($p in $Path) {
    $item = Get-Item -LiteralPath $p
    if ($item.PSIsContainer) {
        Get-ChildItem -LiteralPath $item.FullName -Recurse -File -Include '*.ps1', '*.psd1', '*.psm1' |
            Where-Object { -not (Test-Excluded $_.FullName) } |
            ForEach-Object { $files.Add($_.FullName) }
    }
    else {
        if ($explicit -or -not (Test-Excluded $item.FullName)) { $files.Add($item.FullName) }
    }
}

# Pester testleri pwsh 7'de koşar ve 5.1 profilindeki eski Pester'ı (3.4) değil Pester 5'i kullanır:
# *.Tests.ps1 için PSUseCompatibleCommands kapalı (sözdizimi denetimi açık kalır).
$settingsData = Import-PowerShellDataFile -LiteralPath $Settings
$testSettings = $settingsData.Clone()
$testSettings.ExcludeRules = @($settingsData.ExcludeRules) + 'PSUseCompatibleCommands'

$utf8Bom = [byte[]](0xEF, 0xBB, 0xBF)
$findings = New-Object System.Collections.Generic.List[object]
$i = 0
$sw = [System.Diagnostics.Stopwatch]::StartNew()

Write-Host ("Lint: {0} files, settings {1}" -f $files.Count, (Resolve-Path -LiteralPath $Settings -Relative))

foreach ($file in $files) {
    $i++
    $rel = $file
    if ($file.StartsWith($repoRoot)) { $rel = $file.Substring($repoRoot.Length).TrimStart('/', '\') }
    Write-Host ("  [{0}/{1}] {2}" -f $i, $files.Count, $rel)

    # 1. UTF-8 BOM
    $bytes = [System.IO.File]::ReadAllBytes($file)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq $utf8Bom[0] -and $bytes[1] -eq $utf8Bom[1] -and $bytes[2] -eq $utf8Bom[2]
    $nonAscii = $false
    foreach ($b in $bytes) { if ($b -ge 0x80) { $nonAscii = $true; break } }
    if (-not $hasBom -and $nonAscii) {
        $findings.Add([pscustomobject]@{ File = $rel; Line = 1; Rule = 'FAI.Utf8Bom'; Message = 'UTF-8 BOM missing (5.1 corrupts non-ASCII characters).' })
    }

    # 2. 7'ye özgü ?. ve ?[ (ad sınırı belirsiz olduğundan ayrıca belirteçten bakılır)
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tokens, [ref]$parseErrors)
    foreach ($err in $parseErrors) {
        # Sınıflar dosyalar arası tipleri kullanır (ActionBase, ExecutionContext...); tek dosyada bu tipler bilinmez.
        # Tip çözümlemesi bundle'ın ayrıştırılmasında denetlenir (build/Bundle.ps1 hata verirse bundle üretilmez).
        if ($err.ErrorId -eq 'TypeNotFound') { continue }
        $findings.Add([pscustomobject]@{ File = $rel; Line = $err.Extent.StartLineNumber; Rule = 'FAI.Parse'; Message = $err.Message })
    }
    foreach ($t in $tokens) {
        $kind = $t.Kind.ToString()
        if ($kind -eq 'QuestionDot' -or $kind -eq 'QuestionLBracket') {
            $findings.Add([pscustomobject]@{ File = $rel; Line = $t.Extent.StartLineNumber; Rule = 'FAI.NullConditional'; Message = "The '$($t.Text)' operator does not exist in PowerShell 5.1." })
        }
    }

    # 3. PSScriptAnalyzer
    $fileSettings = $settingsData
    if ($file.EndsWith('.Tests.ps1')) { $fileSettings = $testSettings }
    foreach ($r in (Invoke-ScriptAnalyzer -Path $file -Settings $fileSettings)) {
        if ($r.RuleName -eq 'TypeNotFound') { continue }   # yukarıdaki açıklama: tip çözümlemesi bundle'da
        $findings.Add([pscustomobject]@{ File = $rel; Line = $r.Line; Rule = $r.RuleName; Message = $r.Message })
    }
}

$sw.Stop()
if ($findings.Count -gt 0) {
    Write-Host ''
    Write-Host ("Lint FAILED: {0} findings ({1:N1} s)" -f $findings.Count, $sw.Elapsed.TotalSeconds) -ForegroundColor Red
    foreach ($f in $findings) {
        Write-Host ("  {0}:{1}  {2}  {3}" -f $f.File, $f.Line, $f.Rule, $f.Message) -ForegroundColor Red
    }
    exit 1
}

Write-Host ("Lint clean: {0} files ({1:N1} s)" -f $files.Count, $sw.Elapsed.TotalSeconds) -ForegroundColor Green
exit 0

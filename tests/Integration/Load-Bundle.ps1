<#
.SYNOPSIS
    Bundle'ın (dist/install.ps1) Windows PowerShell 5.1'de yüklendiğini doğrular.

.DESCRIPTION
    1. PowerShell sürümü 5.1 mi (-AnyVersion ile atlanır; Linux'ta pwsh denemesi için)
    2. Bundle ayrıştırılıyor mu
    3. Ayrı bir kapsamda nokta-kaynak (dot-source) ile yükleniyor mu, sürüm değişkeni tanımlı mı
    Başarılıysa 0, değilse 1 ile çıkar. Windows CI ve tests/Sandbox/Run.ps1 bunu çağırır.

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\Integration\Load-Bundle.ps1
#>
[CmdletBinding()]
param(
    [string] $BundlePath,
    [switch] $AnyVersion
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not $BundlePath) { $BundlePath = Join-Path (Join-Path $repoRoot 'dist') 'install.ps1' }

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

Write-Host ("Bundle yükleme testi: {0}" -f $BundlePath)

Step 'PowerShell 5.1' {
    $v = $PSVersionTable.PSVersion
    if ($requireV51 -and -not ($v.Major -eq 5 -and $v.Minor -eq 1)) { throw "beklenen 5.1, bulunan $v ($($PSVersionTable.PSEdition))" }
    "($v $($PSVersionTable.PSEdition))"
}

Step 'Dosya var' {
    if (-not (Test-Path -LiteralPath $BundlePath -PathType Leaf)) { throw 'yok; önce build/Bundle.ps1' }
    "($((Get-Item -LiteralPath $BundlePath).Length) bayt)"
}

Step 'Ayrıştırma' {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($BundlePath, [ref]$tokens, [ref]$errors)
    if ($errors -and $errors.Count -gt 0) { throw (($errors | ForEach-Object { "$($_.Extent.StartLineNumber): $($_.Message)" }) -join '; ') }
    "($($tokens.Count) belirteç)"
}

Step 'Yükleme' {
    $loaded = & {
        . $BundlePath
        $script:FaiWinOPVersion
    }
    if (-not $loaded) { throw 'FaiWinOPVersion tanımlı değil' }
    "(sürüm $loaded)"
}

if ($failed -gt 0) {
    Write-Host ("Bundle yükleme testi BAŞARISIZ: {0} adım" -f $failed) -ForegroundColor Red
    exit 1
}
Write-Host 'Bundle yükleme testi geçti.' -ForegroundColor Green
exit 0

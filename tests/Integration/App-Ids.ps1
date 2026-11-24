<#
.SYNOPSIS
    apps/catalog.json'daki her paket kimliğini winget ile doğrular (Faz 4 kabulü). SALT OKUNUR: hiçbir şey kurmaz.

.DESCRIPTION
    Her uygulama için 'winget show --id <packageId> --exact --source <source>' çalışır; çıkış kodu 0 ve çıktıda
    '[<packageId>]' görünürse OK. msstore kaynağı makinede tanımlı değilse (ör. sunucu runner'ı) o uygulama ATLA.
    winget yoksa HATA (doğrulama yapılamadı). Gerçek makinede de güvenle çalışır.
    Sonuç: hepsi OK / ATLA ise 0, en az bir HATA varsa 1.

.PARAMETER CatalogPath
    Varsayılan apps/catalog.json.

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\Integration\App-Ids.ps1
#>
[CmdletBinding()]
param([string] $CatalogPath)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not $CatalogPath) { $CatalogPath = Join-Path (Join-Path $repoRoot 'apps') 'catalog.json' }

$winget = Get-Command -Name 'winget.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $winget) {
    $pattern = Join-Path $env:ProgramFiles 'WindowsApps\Microsoft.DesktopAppInstaller_*_8wekyb3d8bbwe\winget.exe'
    $winget = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
}
if (-not $winget) { Write-Host 'App-Ids: HATA winget bulunamadı (App Installer); kimlikler doğrulanamadı.' -ForegroundColor Red; exit 1 }
$wingetPath = if ($winget.Source) { $winget.Source } else { $winget.FullName }

# PS 5.1: ConvertFrom-Json PSCustomObject döndürür; yalnız okunuyor.
$apps = @((Get-Content -LiteralPath $CatalogPath -Raw -Encoding UTF8 | ConvertFrom-Json).apps)
$sources = (& $wingetPath source list --disable-interactivity 2>&1 | Out-String)
$hasStore = $sources -match '(?im)^\s*msstore\b'

Write-Host ("App-Ids: {0} uygulama, winget {1}, msstore kaynağı: {2}" -f $apps.Count, ((& $wingetPath --version) -join ''), $hasStore)
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$failed = 0
$skipped = 0
$i = 0
foreach ($app in $apps) {
    $i++
    $label = '[{0}/{1}] {2,-12} {3} ({4})' -f $i, $apps.Count, $app.id, $app.packageId, $app.source
    if ($app.source -eq 'msstore' -and -not $hasStore) {
        $skipped++
        Write-Host ("  ATLA  {0}: msstore kaynağı yok" -f $label) -ForegroundColor Yellow
        continue
    }
    $t = [System.Diagnostics.Stopwatch]::StartNew()
    $out = (& $wingetPath show --id $app.packageId --exact --source $app.source --accept-source-agreements --disable-interactivity 2>&1 | Out-String)
    $code = $LASTEXITCODE
    $found = $out.Contains('[' + $app.packageId + ']')
    if ($code -eq 0 -and $found) {
        $name = ([regex]::Match($out, '(?m)^\S.*\[' + [regex]::Escape($app.packageId) + '\]')).Value.Trim()
        Write-Host ("  OK    {0}: {1} ({2:n1} sn)" -f $label, $name, $t.Elapsed.TotalSeconds) -ForegroundColor Green
    }
    else {
        $failed++
        $tail = (@($out -split "`r?`n" | Where-Object { $_.Trim() }) | Select-Object -Last 2) -join ' | '
        Write-Host ("  HATA  {0}: çıkış {1}; {2}" -f $label, $code, $tail) -ForegroundColor Red
    }
    $left = ($sw.Elapsed.TotalSeconds / $i) * ($apps.Count - $i)
    if ($i -lt $apps.Count -and $sw.Elapsed.TotalSeconds -gt 10) { Write-Host ("        geçen {0:n0} sn, tahmini kalan {1:n0} sn" -f $sw.Elapsed.TotalSeconds, $left) -ForegroundColor DarkGray }
}

Write-Host ("App-Ids: {0} OK, {1} ATLA, {2} HATA ({3:n0} sn)" -f ($apps.Count - $failed - $skipped), $skipped, $failed, $sw.Elapsed.TotalSeconds)
if ($failed -gt 0) { exit 1 }
exit 0

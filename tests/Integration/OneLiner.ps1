<#
.SYNOPSIS
    Faz 8 kabulü: tek satır komut (get.ps1 → SHA-256 → install.ps1) -DryRun ile uçtan uca çalışıyor; özet tutmazsa
    çalıştırma duruyor.

.DESCRIPTION
    dist/install.ps1 + .sha256 + src/Bootstrap/get.ps1 yerel HTTP sunucusundan (python -m http.server, 127.0.0.1)
    iki klasörde sunulur:
      good/  özgün dosyalar            → çıkış 0, 'SHA-256 dogrulandi', rapor 'ÖNİZLEME'
      bad/   install.ps1'e satır eklenmiş (özet aynı) → çıkış ≠ 0, 'BASARISIZ', eklenen satır ÇALIŞMAMIŞ
    Ayrıca: çalışan kopya yönetici-yalnız klasörde yeniden doğrulanır; https / localhost dışı FAI_WINOP_BASEURL reddedilir.
    Tek satır kullanıcınınkiyle aynıdır; yalnız FAI_WINOP_BASEURL yerel sunucuyu gösterir. Yönetici (CI runner) ister.
    Başarılıysa 0, değilse 1 ile çıkar. Önce: build\Bundle.ps1.

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\Integration\OneLiner.ps1
#>
[CmdletBinding()]
param(
    [string] $ProfileName = 'fedai',
    [int] $Port = 8765
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$dist = Join-Path $repoRoot 'dist'
$failed = 0
function Step([string] $Name, [scriptblock] $Body) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $detail = & $Body
        Write-Host ("  OK    {0} {1} ({2:N0} sn)" -f $Name, $detail, $sw.Elapsed.TotalSeconds) -ForegroundColor Green
    }
    catch {
        $script:failed++
        Write-Host ("  HATA  {0}: {1}" -f $Name, $_.Exception.Message) -ForegroundColor Red
    }
}

foreach ($f in @('install.ps1', 'install.ps1.sha256')) {
    if (-not (Test-Path -LiteralPath (Join-Path $dist $f))) { Write-Host "dist\$f yok; önce build\Bundle.ps1" -ForegroundColor Red; exit 1 }
}

$serve = Join-Path ([System.IO.Path]::GetTempPath()) ('fai-oneliner-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
foreach ($d in @('good', 'bad')) {
    $dir = Join-Path $serve $d
    [void](New-Item -ItemType Directory -Path $dir -Force)
    Copy-Item -LiteralPath (Join-Path $dist 'install.ps1') -Destination $dir
    Copy-Item -LiteralPath (Join-Path $dist 'install.ps1.sha256') -Destination $dir
    Copy-Item -LiteralPath (Join-Path $repoRoot 'src\Bootstrap\get.ps1') -Destination $dir
}
# Kurcalanmış kopya: sona çalışırsa iz bırakan satır eklenir; özet dosyası özgün kalır.
$marker = Join-Path $serve 'KURCALANDI.txt'
[System.IO.File]::AppendAllText((Join-Path $serve 'bad\install.ps1'), "`r`nSet-Content -LiteralPath '$marker' -Value 'x'`r`n")

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { Write-Host 'python yok (yerel HTTP sunucusu için gerekli)' -ForegroundColor Red; exit 1 }
$server = Start-Process -FilePath $python.Source -ArgumentList @('-m', 'http.server', $Port, '--bind', '127.0.0.1', '--directory', $serve) -PassThru -WindowStyle Hidden
try {
    $base = "http://127.0.0.1:$Port"
    $ready = $false
    for ($i = 0; $i -lt 40 -and -not $ready; $i++) {
        try { [void](Invoke-WebRequest -UseBasicParsing -Uri "$base/good/get.ps1" -TimeoutSec 2); $ready = $true }
        catch { Start-Sleep -Milliseconds 500 }
    }
    if (-not $ready) { throw 'yerel HTTP sunucusu açılmadı' }
    Write-Host ("Yerel sunucu: {0} → {1}" -f $base, $serve)

    function Invoke-OneLiner([string] $Sub, [string] $BaseUrl) {
        # 5.1: Stop + 2>&1 yerel komutun stderr satırını sonlandırıcı hataya çevirir.
        $ErrorActionPreference = 'Continue'
        if ($BaseUrl) { $env:FAI_WINOP_BASEURL = $BaseUrl } else { $env:FAI_WINOP_BASEURL = "$base/$Sub" }
        $cmd = "& ([scriptblock]::Create((irm '$base/$Sub/get.ps1'))) -Profile $ProfileName -DryRun; exit `$LASTEXITCODE"
        Write-Host ("  > {0}" -f $cmd)
        $out = & powershell.exe -NoProfile -Command $cmd 2>&1 | Out-String
        return @{ Code = $LASTEXITCODE; Output = $out }
    }

    Step "Tek satır -Profile $ProfileName -DryRun (özet doğru)" {
        $r = Invoke-OneLiner 'good'
        Write-Host $r.Output
        if ($r.Code -ne 0) { throw "çıkış kodu $($r.Code)" }
        if ($r.Output -notmatch 'SHA-256 dogrulandi') { throw 'doğrulama satırı yok' }
        # Çalışan kopya %TEMP%'teki değil, yönetici-yalnız klasörde yeniden doğrulanan (ProgramData) kopya.
        if ($r.Output -notmatch 'Yonetici-yalniz kopya yeniden dogrulandi') { throw 'yönetici-yalnız kopya doğrulama satırı yok' }
        if (@(Get-ChildItem -LiteralPath $env:ProgramData -Directory -Filter 'FAI_WinOP_get_*' -ErrorAction SilentlyContinue).Count -gt 0) {
            throw 'yönetici-yalnız geçici klasör silinmedi'
        }
        if ($r.Output -notmatch 'ÖNİZLEME|ONIZLEME|dry-run') { throw 'dry-run raporu yok' }
        $sum = ($r.Output -split "`r?`n" | Where-Object { $_ -match '^Özet:|^Ozet:|Özet:' } | Select-Object -Last 1)
        "($sum)"
    }

    Step 'Kurcalanmış install.ps1 (özet tutmaz) → çalıştırılmaz' {
        $r = Invoke-OneLiner 'bad'
        Write-Host $r.Output
        if ($r.Code -eq 0) { throw 'çıkış kodu 0 (durmalıydı)' }
        if ($r.Output -notmatch 'BASARISIZ') { throw 'başarısızlık iletisi yok' }
        if (Test-Path -LiteralPath $marker) { throw 'kurcalanmış betik ÇALIŞTI' }
        if (Test-Path -LiteralPath (Join-Path $env:TEMP 'FAI_WinOP\install.ps1')) {
            $h = (Get-FileHash -LiteralPath (Join-Path $env:TEMP 'FAI_WinOP\install.ps1') -Algorithm SHA256).Hash
            $bad = (Get-FileHash -LiteralPath (Join-Path $serve 'bad\install.ps1') -Algorithm SHA256).Hash
            if ($h -eq $bad) { throw 'kurcalanmış dosya diskte kaldı' }
        }
        "(çıkış $($r.Code))"
    }

    Step 'https / localhost dışı FAI_WINOP_BASEURL → reddedilir, indirilmez' {
        $r = Invoke-OneLiner 'good' 'http://example.com/good'
        Write-Host $r.Output
        if ($r.Code -eq 0) { throw 'çıkış kodu 0 (reddetmeliydi)' }
        if ($r.Output -notmatch 'FAI_WINOP_BASEURL reddedildi') { throw 'red iletisi yok' }
        if ($r.Output -match 'Indiriliyor') { throw 'indirmeye başladı' }
        "(çıkış $($r.Code))"
    }
}
finally {
    Remove-Item Env:\FAI_WINOP_BASEURL -ErrorAction SilentlyContinue
    if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue }
}

if ($failed -gt 0) { Write-Host ("Tek satır testi: {0} HATA" -f $failed) -ForegroundColor Red; exit 1 }
Write-Host 'Tek satır testi: geçti' -ForegroundColor Green
exit 0

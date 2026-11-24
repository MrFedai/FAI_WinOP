<#
.SYNOPSIS
    Windows Sandbox içinde açılışta çalışan test koşucusu (tests/Sandbox/FAI_WinOP.wsb başlatır).

.DESCRIPTION
    Test kopyası sandbox'a salt okunur bağlıdır (C:\FAI_WinOP); sonuçlar yazılabilir bağlı klasöre (C:\FAI_out) gider:
      out\run-<zaman>.log   ayrıntılı kayıt (transcript)
      out\SONUC.txt         tek satır: GECTI / KALDI + zaman
    Faz 0: sistem bilgisi + bundle yükleme testi. Sonraki fazlar tweak grubu uygula → doğrula → -Undo adımlarını ekler.

.PARAMETER OutDir
    Sonuç klasörü. Varsayılan C:\FAI_out (sandbox içi).

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\FAI_WinOP\tests\Sandbox\Run.ps1
#>
[CmdletBinding()]
param(
    [string] $OutDir = 'C:\FAI_out'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$log = Join-Path $OutDir "run-$stamp.log"
$result = Join-Path $OutDir 'SONUC.txt'

Start-Transcript -LiteralPath $log | Out-Null
$exitCode = 1
try {
    Write-Host '== Sistem'
    $os = Get-CimInstance Win32_OperatingSystem
    Write-Host ("  {0} · derleme {1} · PowerShell {2}" -f $os.Caption, $os.BuildNumber, $PSVersionTable.PSVersion)
    Write-Host ("  Depo kopyası: {0}" -f $repoRoot)

    Write-Host '== Bundle yükleme'
    $bundle = Join-Path (Join-Path $repoRoot 'dist') 'install.ps1'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot 'tests\Integration\Load-Bundle.ps1') -BundlePath $bundle
    $exitCode = $LASTEXITCODE
}
catch {
    Write-Host ("HATA: {0}" -f $_.Exception.Message) -ForegroundColor Red
    $exitCode = 1
}
finally {
    Stop-Transcript | Out-Null
}

$verdict = 'KALDI'
if ($exitCode -eq 0) { $verdict = 'GECTI' }
$line = '{0} {1} (log: run-{2}.log)' -f $verdict, (Get-Date -Format 's'), $stamp
[System.IO.File]::WriteAllText($result, $line + "`r`n", (New-Object System.Text.UTF8Encoding($true)))
Write-Host $line
exit $exitCode

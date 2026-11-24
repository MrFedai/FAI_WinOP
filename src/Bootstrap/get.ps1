# FAI_WinOP onyukleyici (get.ps1): install.ps1 ve install.ps1.sha256'yi indirir, SHA-256 dogrular, sonra calistirir.
# Dogrulama basarisizsa install.ps1 silinir ve CALISTIRILMAZ (hata ile durur).
#
#   & ([scriptblock]::Create((irm https://github.com/MrFedai/FAI_WinOP/releases/latest/download/get.ps1))) -Profile fedai -DryRun
#
# Butun argumanlar install.ps1'e aynen gecer. Yonetici degilse install.ps1 yeni pencerede yonetici olarak (UAC) acilir.
# Bu dosya BILEREK yalniz ASCII ve BOM'suz: Windows PowerShell 5.1 irm charset'siz yaniti ISO-8859-1 cozer.
# FAI_WINOP_BASEURL ortam degiskeni indirme kokunu degistirir (yalniz test: CI yerel sunucu).

$ErrorActionPreference = 'Stop'
$faiBase = 'https://github.com/MrFedai/FAI_WinOP/releases/latest/download'
if ($env:FAI_WINOP_BASEURL) { $faiBase = $env:FAI_WINOP_BASEURL.TrimEnd('/') }

# Argumanlar: -Ad bicimi aynen, deger dizisi virgulle birlesir (powershell -File tek metin verir).
$faiArgs = New-Object 'System.Collections.Generic.List[string]'
foreach ($a in $args) {
    if ($a -is [array]) { $faiArgs.Add((@($a) | ForEach-Object { [string]$_ }) -join ',') }
    else { $faiArgs.Add([string]$a) }
}

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$faiDir = Join-Path $env:TEMP 'FAI_WinOP'
if (-not (Test-Path -LiteralPath $faiDir)) { [void](New-Item -ItemType Directory -Path $faiDir -Force) }
$faiFile = Join-Path $faiDir 'install.ps1'

Write-Host ('Indiriliyor: {0}/install.ps1' -f $faiBase)
$wc = New-Object System.Net.WebClient
try {
    $wc.DownloadFile($faiBase + '/install.ps1', $faiFile)
    $faiHashText = [System.Text.Encoding]::ASCII.GetString($wc.DownloadData($faiBase + '/install.ps1.sha256'))
}
finally { $wc.Dispose() }

$faiExpected = @($faiHashText.Trim() -split '\s+')[0]
$faiActual = (Get-FileHash -LiteralPath $faiFile -Algorithm SHA256).Hash
if ($faiExpected -notmatch '^[0-9a-fA-F]{64}$' -or $faiActual.ToLowerInvariant() -ne $faiExpected.ToLowerInvariant()) {
    Remove-Item -LiteralPath $faiFile -Force -ErrorAction SilentlyContinue
    Write-Host 'SHA-256 dogrulamasi BASARISIZ: install.ps1 yayimlanan ozetle eslesmiyor; calistirilmadi.' -ForegroundColor Red
    throw 'FAI_WinOP: SHA-256 dogrulamasi basarisiz'
}
Write-Host ('SHA-256 dogrulandi: {0}' -f $faiActual.ToLowerInvariant()) -ForegroundColor Green

$faiPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if ($faiPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $faiFile @faiArgs
}
else {
    $faiQuoted = @($faiArgs | ForEach-Object { if ($_ -match '[\s"]') { '"' + $_.Replace('"', '\"') + '"' } else { $_ } })
    $faiLine = ('-NoProfile -ExecutionPolicy Bypass -NoExit -File "{0}" {1}' -f $faiFile, ($faiQuoted -join ' ')).TrimEnd()
    Write-Host 'Yonetici izni isteniyor (UAC); arac yeni pencerede acilacak.' -ForegroundColor Yellow
    Start-Process -FilePath 'powershell.exe' -ArgumentList $faiLine -Verb RunAs | Out-Null
}

# FAI_WinOP onyukleyici (get.ps1): install.ps1 ve install.ps1.sha256'yi indirir, SHA-256 dogrular, sonra calistirir.
# Dogrulama basarisizsa install.ps1 silinir ve CALISTIRILMAZ (hata ile durur).
#
#   & ([scriptblock]::Create((irm https://github.com/MrFedai/FAI_WinOP/releases/latest/download/get.ps1))) -Profile fedai -DryRun
#
# Butun argumanlar install.ps1'e aynen gecer. Yonetici degilse yeni pencerede yonetici olarak (UAC) devam eder.
# Bu dosya BILEREK yalniz ASCII ve BOM'suz: Windows PowerShell 5.1 irm charset'siz yaniti ISO-8859-1 cozer.
# FAI_WINOP_BASEURL ortam degiskeni indirme kokunu degistirir (yalniz test: CI yerel sunucu); yalniz https://
# ya da http://localhost / http://127.0.0.1 kabul edilir, baskasi reddedilir.
#
# TOCTOU: %TEMP%'teki dosya kullanicinin yazabildigi yerdedir; dogrulama ile calistirma arasinda degistirilebilir.
# Bu yuzden %TEMP%'teki dosya hicbir zaman dogrudan calistirilmaz. Yonetici sureci (UAC sonrasi ya da zaten yonetici)
# %ProgramData% altinda her calistirmada YENI bir klasor acar; klasor ACL'i olusturma aninda verilir (sahip
# Administrators, yalniz SYSTEM + Administrators tam denetim, kalitim kapali). install.ps1 oraya kopyalanir,
# ozet (ilk asamada indirilen, yukseltilmis komuta gomulu) kopyada yeniden dogrulanir ve yalniz o kopya calisir.

$ErrorActionPreference = 'Stop'

function Test-FaiBaseUrl([string] $Url) {
    # https (her ana bilgisayar) ya da http yalniz localhost / 127.0.0.1. Kullanici bilgisi (@) iceren adres reddedilir.
    $uri = $null
    if (-not [Uri]::TryCreate($Url, [UriKind]::Absolute, [ref] $uri)) { return $false }
    if ($uri.UserInfo) { return $false }
    if ($uri.Scheme -eq 'https') { return $true }
    if ($uri.Scheme -eq 'http' -and ($uri.Host -eq 'localhost' -or $uri.Host -eq '127.0.0.1')) { return $true }
    return $false
}

function Get-FaiExpectedHash([string] $Text) {
    # install.ps1.sha256 metninin ilk sozcugu; 64 onaltilik degilse $null.
    if (-not $Text) { return $null }
    $h = @($Text.Trim() -split '\s+')[0]
    if ($h -notmatch '^[0-9a-fA-F]{64}$') { return $null }
    return $h.ToLowerInvariant()
}

function Test-FaiFileHash([string] $Path, [string] $Expected) {
    if ($Expected -notmatch '^[0-9a-f]{64}$') { return $false }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    return ($actual -eq $Expected)
}

function ConvertTo-FaiLiteral([string] $Value) {
    # Tek tirnakli PowerShell metni; PowerShell'in tek tirnak saydigi U+2018..U+201B de ikilenir.
    $q = "(['" + [char]0x2018 + [char]0x2019 + [char]0x201A + [char]0x201B + "])"
    return "'" + ($Value -replace $q, '$1$1') + "'"
}

function New-FaiAdminDir {
    # Yonetici sureci: %ProgramData%\FAI_WinOP_get_<guid>, ACL olusturma aninda (yaris yok). Sonra yeniden denetlenir.
    $root = [Environment]::GetFolderPath('CommonApplicationData')
    $path = Join-Path $root ('FAI_WinOP_get_' + [guid]::NewGuid().ToString('N'))
    if (Test-Path -LiteralPath $path) { throw ('FAI_WinOP: folder already exists: {0}' -f $path) }
    $admins = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
    $system = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-18')
    $sec = New-Object System.Security.AccessControl.DirectorySecurity
    $sec.SetAccessRuleProtection($true, $false)
    $sec.SetOwner($admins)
    foreach ($sid in @($system, $admins)) {
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($sid, 'FullControl', 'ContainerInherit, ObjectInherit', 'None', 'Allow')
        $sec.AddAccessRule($rule)
    }
    [void][System.IO.Directory]::CreateDirectory($path, $sec)

    $item = Get-Item -LiteralPath $path -Force
    $acl = Get-Acl -LiteralPath $path
    $ok = (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -eq 0) -and $acl.AreAccessRulesProtected
    $owner = $acl.GetOwner([System.Security.Principal.SecurityIdentifier]).Value
    if ($owner -ne $admins.Value -and $owner -ne $system.Value) { $ok = $false }
    foreach ($r in $acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])) {
        if ($r.IdentityReference.Value -ne $admins.Value -and $r.IdentityReference.Value -ne $system.Value) { $ok = $false }
    }
    if (-not $ok) {
        Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
        throw ('FAI_WinOP: could not set up the admin-only folder: {0}' -f $path)
    }
    return $path
}

function Start-FaiInstaller([string] $Path, [string[]] $Arguments) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments
}

function Invoke-FaiSecureRun([string] $Source, [string] $Expected, [string[]] $Arguments) {
    # Yonetici surecinde: kopyala -> kopyada yeniden dogrula -> yalniz kopyayi calistir -> klasoru sil.
    $dir = New-FaiAdminDir
    try {
        $target = Join-Path $dir 'install.ps1'
        [System.IO.File]::Copy($Source, $target, $false)
        if (-not (Test-FaiFileHash -Path $target -Expected $Expected)) {
            Write-Host 'SHA-256 verification FAILED: the admin copy does not match the hash (the file changed after verification); not run.' -ForegroundColor Red
            throw 'FAI_WinOP: admin copy SHA-256 verification failed'
        }
        Write-Host ('Admin-only copy re-verified: {0}' -f $target) -ForegroundColor Green
        Start-FaiInstaller -Path $target -Arguments $Arguments
    }
    finally {
        Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function New-FaiElevatedScript([string] $Source, [string] $Expected, [string[]] $Arguments) {
    # UAC ile acilan surecin betigi: gereken fonksiyonlar + Invoke-FaiSecureRun cagrisi (degerler tek tirnakli metin).
    if ($Expected -notmatch '^[0-9a-f]{64}$') { throw 'FAI_WinOP: invalid hash' }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("`$ErrorActionPreference = 'Stop'")
    foreach ($n in @('Test-FaiFileHash', 'New-FaiAdminDir', 'Start-FaiInstaller', 'Invoke-FaiSecureRun')) {
        $body = (Get-Command -Name $n -CommandType Function).ScriptBlock.ToString()
        [void]$sb.AppendLine(('function {0} {{{1}}}' -f $n, $body))
    }
    $argText = (@($Arguments) | ForEach-Object { ConvertTo-FaiLiteral $_ }) -join ', '
    [void]$sb.AppendLine(('Invoke-FaiSecureRun -Source {0} -Expected {1} -Arguments @({2})' -f (ConvertTo-FaiLiteral $Source), (ConvertTo-FaiLiteral $Expected), $argText))
    return $sb.ToString()
}

# Fonksiyonlar yukarida; asagisi calistirma. Birim testleri yalniz fonksiyonlari AST ile alir.
$faiBase = 'https://github.com/MrFedai/FAI_WinOP/releases/latest/download'
if ($env:FAI_WINOP_BASEURL) {
    if (-not (Test-FaiBaseUrl $env:FAI_WINOP_BASEURL)) {
        Write-Host ('FAI_WINOP_BASEURL rejected: {0} (only https:// or http://localhost, http://127.0.0.1 are allowed); not run.' -f $env:FAI_WINOP_BASEURL) -ForegroundColor Red
        throw 'FAI_WinOP: FAI_WINOP_BASEURL rejected'
    }
    $faiBase = $env:FAI_WINOP_BASEURL.TrimEnd('/')
}

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

Write-Host ('Downloading: {0}/install.ps1' -f $faiBase)
$wc = New-Object System.Net.WebClient
try {
    $wc.DownloadFile($faiBase + '/install.ps1', $faiFile)
    $faiHashText = [System.Text.Encoding]::ASCII.GetString($wc.DownloadData($faiBase + '/install.ps1.sha256'))
}
finally { $wc.Dispose() }

# Ilk dogrulama (erken hata): kullanicinin %TEMP%'inde. Calistirilan kopya yonetici surecinde yeniden dogrulanir.
$faiExpected = Get-FaiExpectedHash $faiHashText
if (-not $faiExpected -or -not (Test-FaiFileHash -Path $faiFile -Expected $faiExpected)) {
    Remove-Item -LiteralPath $faiFile -Force -ErrorAction SilentlyContinue
    Write-Host 'SHA-256 verification FAILED: install.ps1 does not match the published hash; not run.' -ForegroundColor Red
    throw 'FAI_WinOP: SHA-256 verification failed'
}
Write-Host ('SHA-256 verified: {0}' -f $faiExpected) -ForegroundColor Green

$faiPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if ($faiPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Invoke-FaiSecureRun -Source $faiFile -Expected $faiExpected -Arguments $faiArgs.ToArray()
}
else {
    $faiScript = New-FaiElevatedScript -Source $faiFile -Expected $faiExpected -Arguments $faiArgs.ToArray()
    $faiEncoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($faiScript))
    if ($faiEncoded.Length -gt 30000) { throw 'FAI_WinOP: arguments too long (the admin command would exceed the 32 KB limit)' }
    Write-Host 'Requesting administrator permission (UAC); the tool will open in a new window.' -ForegroundColor Yellow
    Start-Process -FilePath 'powershell.exe' -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -NoExit -EncodedCommand ' + $faiEncoded) -Verb RunAs | Out-Null
}

# Veri kaynağı: tweak kataloğu (tweaks/**/*.psd1), uygulama kataloğu (apps/catalog.json), profiller (profiles/*.json).
#
# Karar (Faz 8): veri install.ps1'e GÖMÜLÜR (build/Bundle.ps1 → Get-FaiEmbeddedData), indirilmez. Gerekçe:
#   - Tek dosya = tek SHA-256: yayımlanan install.ps1.sha256 tweak / katalog / profil verisini de kapsar; ayrı
#     raw.githubusercontent indirmeleri ayrı ayrı doğrulanmak zorunda kalırdı.
#   - Sürüm tutarlılığı: kod ve veri aynı etiketten gelir; etiketle veri arasında kayma olamaz.
#   - Çevrimdışı / ağ kısıtlı kurulum (format sonrası sürücüsüz Wi-Fi) ve daha az ağ isteği.
#   Bedeli ~100 KB; kullanıcı profili yine yol ya da https URL ile dışarıdan verilebilir (-Profile).
#
# Gömülü veri yolu → UTF-8 metin sözlüğüdür (ör. 'tweaks/ui/taskbar.psd1'). .psd1 metni yürütülmeden, yalnız
# ayrıştırılarak okunur (HashtableAst.SafeGetValue; Import-PowerShellDataFile ile aynı kısıt: kod çalışmaz).

function Get-FaiDataFile {
    <#
    .SYNOPSIS
        Bundle'a gömülü veri dosyaları: yol → metin (hashtable). Gömülü veri yoksa boş hashtable.
    .PARAMETER Prefix
        Yalnız bu önekle başlayan yollar (ör. 'tweaks/').
    #>
    [CmdletBinding()]
    param([string] $Prefix = '')

    $all = @{}
    if (Get-Command -Name 'Get-FaiEmbeddedData' -CommandType Function -ErrorAction SilentlyContinue) { $all = Get-FaiEmbeddedData }
    if (-not $Prefix) { return $all }
    $out = @{}
    foreach ($k in @($all.Keys)) { if ([string]$k -like ($Prefix + '*')) { $out[[string]$k] = $all[$k] } }
    return $out
}

function ConvertFrom-FaiPsd1Text {
    <#
    .SYNOPSIS
        .psd1 metnini YÜRÜTMEDEN hashtable'a çevirir (yalnız sabit değerler; Import-PowerShellDataFile ile aynı kural).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [AllowEmptyString()] [string] $Text,
        [string] $Source = '<metin>'
    )

    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($Text.TrimStart([char]0xFEFF), [ref]$tokens, [ref]$errors)
    if ($errors -and $errors.Count -gt 0) { throw ("{0}: ayrıştırılamadı: {1}" -f $Source, $errors[0].Message) }
    # İlk (en dıştaki) tablo; Import-PowerShellDataFile de böyle okur.
    $table = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.HashtableAst] }, $false)
    if ($null -eq $table) { throw "${Source}: @{ } veri tablosu yok" }
    try { $value = $table.SafeGetValue() }
    catch { throw ("{0}: yalnız sabit değer içerebilir: {1}" -f $Source, $_.Exception.Message) }
    return $value
}

function ConvertTo-FaiTweakCatalog {
    <#
    .SYNOPSIS
        Kaynak adı → tweak hashtable sözlüğünden Id → Tweak kataloğu kurar. Bütün geçersizler tek hatada; yinelenen Id hata.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [hashtable] $Sources)

    $catalog = @{}
    $problems = New-Object 'System.Collections.Generic.List[string]'
    foreach ($src in @($Sources.Keys | Sort-Object)) {
        try {
            $t = [Tweak]::FromHashtable($Sources[$src], [string]$src)
            if ($catalog.ContainsKey($t.Id)) { $problems.Add("${src}: Id '$($t.Id)' birden çok dosyada") }
            else { $catalog[$t.Id] = $t }
        }
        catch { $problems.Add($_.Exception.Message) }
    }
    if ($problems.Count -gt 0) { throw ("Tweak kataloğu geçersiz:`n" + ($problems -join "`n")) }
    return $catalog
}

function Import-FaiEmbeddedTweakCatalog {
    <# .SYNOPSIS  Gömülü tweaks/**/*.psd1 verisinden Id → Tweak kataloğu. Gömülü veri yoksa hata. #>
    [CmdletBinding()]
    param()

    $files = Get-FaiDataFile -Prefix 'tweaks/'
    if ($files.Count -eq 0) { throw 'Gömülü tweak verisi yok (bundle build/Bundle.ps1 ile üretilmeli).' }
    $sources = @{}
    $problems = New-Object 'System.Collections.Generic.List[string]'
    foreach ($k in @($files.Keys)) {
        try { $sources[[string]$k] = ConvertFrom-FaiPsd1Text -Text $files[$k] -Source ([string]$k) }
        catch { $problems.Add($_.Exception.Message) }
    }
    if ($problems.Count -gt 0) { throw ("Tweak kataloğu geçersiz:`n" + ($problems -join "`n")) }
    return ConvertTo-FaiTweakCatalog -Sources $sources
}

function ConvertTo-FaiAppCatalog {
    <# .SYNOPSIS  Uygulama kataloğu verisini (hashtable) doğrular; id → kayıt döndürür. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [hashtable] $Data,
        [string] $Source = 'apps/catalog.json'
    )

    $errors = @(Get-FaiAppCatalogError -Data $Data)
    if ($errors.Count -gt 0) { throw ("Uygulama kataloğu geçersiz ({0}):`n  {1}" -f $Source, ($errors -join "`n  ")) }
    $catalog = @{}
    foreach ($app in $Data['apps']) { $catalog[[string]$app['id']] = $app }
    return $catalog
}

function Import-FaiEmbeddedAppCatalog {
    <# .SYNOPSIS  Gömülü apps/catalog.json → id → uygulama kaydı. Gömülü değilse boş hashtable. #>
    [CmdletBinding()]
    param()

    $files = Get-FaiDataFile -Prefix 'apps/catalog.json'
    if (-not $files.ContainsKey('apps/catalog.json')) { return @{} }
    return ConvertTo-FaiAppCatalog -Data (ConvertFrom-JsonText -Json $files['apps/catalog.json'])
}

function Get-FaiEmbeddedProfileName {
    <# .SYNOPSIS  Gömülü profillerin adları (profiles/<ad>.json), sıralı. #>
    [CmdletBinding()]
    param()

    $names = New-Object 'System.Collections.Generic.List[string]'
    foreach ($k in @((Get-FaiDataFile -Prefix 'profiles/').Keys | Sort-Object)) {
        $n = [System.IO.Path]::GetFileNameWithoutExtension([string]$k)
        if (-not $n.StartsWith('_')) { $names.Add($n) }
    }
    return , $names.ToArray()
}

function Import-FaiEmbeddedProfile {
    <# .SYNOPSIS  Gömülü profiles/<Name>.json → Profile. Yoksa hata (gömülü profilleri listeler). #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [string] $Name)

    $key = 'profiles/' + $Name.ToLowerInvariant() + '.json'
    $files = Get-FaiDataFile -Prefix 'profiles/'
    if (-not $files.ContainsKey($key)) {
        throw ("Profil bulunamadı: '{0}'. Gömülü profiller: {1}" -f $Name, ((Get-FaiEmbeddedProfileName) -join ', '))
    }
    return [Profile]::FromHashtable((ConvertFrom-JsonText -Json $files[$key]), $key)
}

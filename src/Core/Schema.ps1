# Şema doğrulayıcı: tweak (.psd1) ve profil (.json). 5.1'de Test-Json yok; doğrulama burada, PowerShell'de.
# profiles/_schema.json yalnız belge / editör desteğidir; izin verilen alanlar bu dosyayla birebir tutulur (birim testi denetler).
# Hata iletisi biçimi: '<alan yolu>: <neden>' (ör. 'Actions[1].Path: zorunlu alan eksik').

function Test-FaiIsList {
    [CmdletBinding()]
    param([Parameter(Position = 0)] [AllowNull()] [object] $Value)
    return ($null -ne $Value -and $Value -is [System.Collections.IEnumerable] -and $Value -isnot [string] -and $Value -isnot [System.Collections.IDictionary])
}

function Get-FaiIdPattern { return '^[a-z][a-z0-9]*\.[a-z0-9]+(-[a-z0-9]+)*$' }
function Get-FaiTweakKey { return [string[]]@('Id', 'Title', 'Description', 'Category', 'Risk', 'Confirm', 'Conditions', 'Params', 'Refresh', 'First', 'AlwaysConfirm', 'Tool', 'Actions') }
# Tweak uygulandıktan / geri alındıktan sonra istenebilecek kabuk yenilemeleri; motor bu sırayla, çalıştırma sonunda bir kez yapar.
function Get-FaiRefreshKind { return [string[]]@('Desktop', 'Settings', 'StartMenu', 'Shell') }
function Get-FaiProfileKey { return [string[]]@('$schema', 'name', 'description', 'tweaks', 'autoConfirm', 'apps', 'games', 'layout', 'exceptions') }

function Get-FaiTweakError {
    <# .SYNOPSIS  Tweak verisinin (Import-PowerShellDataFile çıktısı) şema hatalarını '<yol>: <neden>' metinleri olarak döndürür. #>
    [CmdletBinding()]
    param([Parameter(Position = 0)] [AllowNull()] [object] $Data)

    $errs = New-Object 'System.Collections.Generic.List[string]'
    if ($Data -isnot [System.Collections.IDictionary]) {
        $errs.Add('(kök): tweak dosyası hashtable olmalı')
        return $errs.ToArray()
    }

    $allowed = Get-FaiTweakKey
    foreach ($k in @($Data.Keys)) {
        if ($allowed -cnotcontains [string]$k) {
            $errs.Add("${k}: bilinmeyen alan (izin verilenler: " + ($allowed -join ', ') + ')')
        }
    }

    foreach ($req in @('Id', 'Title', 'Description', 'Category', 'Risk')) {
        if (-not $Data.Contains($req)) { $errs.Add("${req}: zorunlu alan eksik"); continue }
        if ($Data[$req] -isnot [string] -or [string]::IsNullOrWhiteSpace($Data[$req])) { $errs.Add("${req}: boş olmayan metin olmalı") }
    }
    if ($Data.Contains('Id') -and $Data['Id'] -is [string] -and $Data['Id'] -cnotmatch (Get-FaiIdPattern)) {
        $errs.Add("Id: '$($Data['Id'])' geçersiz (biçim: kategori.ad-küçük-harf, ör. sound.startup-sound-off)")
    }
    if ($Data.Contains('Category') -and $Data['Category'] -is [string] -and $Data['Category'] -cnotmatch '^[a-z][a-z0-9-]*$') {
        $errs.Add("Category: '$($Data['Category'])' geçersiz (küçük harf, rakam, tire)")
    }
    if ($Data.Contains('Risk') -and $Data['Risk'] -is [string] -and [RiskPolicy]::Levels() -cnotcontains $Data['Risk']) {
        $errs.Add("Risk: '$($Data['Risk'])' geçersiz (Safe, Caution ya da Risk olmalı)")
    }
    if ($Data.Contains('Confirm') -and $Data['Confirm'] -isnot [string]) { $errs.Add('Confirm: metin olmalı') }
    foreach ($flag in @('First', 'AlwaysConfirm', 'Tool')) {
        if ($Data.Contains($flag) -and $Data[$flag] -isnot [bool]) { $errs.Add("${flag}: `$true ya da `$false olmalı") }
    }
    if ($Data.Contains('Refresh')) {
        $bad = @(@($Data['Refresh']) | Where-Object { $_ -isnot [string] -or (Get-FaiRefreshKind) -cnotcontains $_ })
        if (-not (Test-FaiIsList $Data['Refresh']) -or $bad.Count -gt 0) { $errs.Add('Refresh: ' + ((Get-FaiRefreshKind) -join ', ') + ' değerlerinden oluşan dizi olmalı') }
    }

    if ($Data.Contains('Conditions')) {
        if (-not (Test-FaiIsList $Data['Conditions'])) { $errs.Add('Conditions: dizi olmalı') }
        else {
            $i = 0
            foreach ($c in $Data['Conditions']) {
                foreach ($m in [Condition]::Validate($c)) { $errs.Add("Conditions[$i]: $m") }
                $i++
            }
        }
    }

    $paramNames = @()
    if ($Data.Contains('Params')) {
        if ($Data['Params'] -isnot [System.Collections.IDictionary]) { $errs.Add('Params: hashtable olmalı') }
        else {
            foreach ($pk in @($Data['Params'].Keys)) {
                if ([string]$pk -cnotmatch '^[A-Za-z][A-Za-z0-9_]*$') { $errs.Add("Params.${pk}: geçersiz parametre adı") }
            }
            $paramNames = @($Data['Params'].Keys | ForEach-Object { [string]$_ })
        }
    }

    if (-not $Data.Contains('Actions')) { $errs.Add('Actions: zorunlu alan eksik') }
    elseif (-not (Test-FaiIsList $Data['Actions'])) { $errs.Add('Actions: dizi olmalı') }
    elseif (@($Data['Actions']).Count -eq 0) { $errs.Add('Actions: en az bir eylem gerekir') }
    else {
        $i = 0
        foreach ($a in $Data['Actions']) {
            $path = "Actions[$i]"
            foreach ($m in @(Get-FaiActionError -Definition $a -Path $path)) { $errs.Add($m) }
            foreach ($ph in @(Get-FaiPlaceholder -Value $a)) {
                if ($paramNames -cnotcontains $ph) { $errs.Add("${path}: '{{$ph}}' yer tutucusu Params içinde tanımlı değil") }
            }
            $i++
        }
    }
    return $errs.ToArray()
}

function Get-FaiProfileError {
    <# .SYNOPSIS  Profil verisinin (JSON'dan hashtable) şema hatalarını '<yol>: <neden>' metinleri olarak döndürür. #>
    [CmdletBinding()]
    param([Parameter(Position = 0)] [AllowNull()] [object] $Data)

    $errs = New-Object 'System.Collections.Generic.List[string]'
    if ($Data -isnot [System.Collections.IDictionary]) {
        $errs.Add('(kök): profil JSON nesnesi olmalı')
        return $errs.ToArray()
    }

    $allowed = Get-FaiProfileKey
    foreach ($k in @($Data.Keys)) {
        if ($allowed -cnotcontains [string]$k) {
            $errs.Add("${k}: bilinmeyen alan (izin verilenler: " + ($allowed -join ', ') + ')')
        }
    }

    if (-not $Data.Contains('name')) { $errs.Add('name: zorunlu alan eksik') }
    elseif ($Data['name'] -isnot [string] -or $Data['name'] -cnotmatch '^[a-z0-9][a-z0-9-]*$') {
        $errs.Add('name: küçük harf, rakam ve tireden oluşan metin olmalı')
    }
    if ($Data.Contains('description') -and $Data['description'] -isnot [string]) { $errs.Add('description: metin olmalı') }

    $tweakIds = New-Object 'System.Collections.Generic.List[string]'
    if (-not $Data.Contains('tweaks')) { $errs.Add('tweaks: zorunlu alan eksik') }
    elseif (-not (Test-FaiIsList $Data['tweaks'])) { $errs.Add('tweaks: dizi olmalı') }
    else {
        $i = 0
        foreach ($t in $Data['tweaks']) {
            $path = "tweaks[$i]"
            $id = $null
            if ($t -is [string]) { $id = $t }
            elseif ($t -is [System.Collections.IDictionary]) {
                foreach ($k in @($t.Keys)) {
                    if (@('id', 'params') -cnotcontains [string]$k) { $errs.Add("${path}.${k}: bilinmeyen alan (izin verilenler: id, params)") }
                }
                if (-not $t.Contains('id')) { $errs.Add("${path}.id: zorunlu alan eksik") }
                elseif ($t['id'] -isnot [string]) { $errs.Add("${path}.id: metin olmalı") }
                else { $id = $t['id'] }
                if ($t.Contains('params') -and $t['params'] -isnot [System.Collections.IDictionary]) { $errs.Add("${path}.params: nesne olmalı") }
            }
            else { $errs.Add("${path}: tweak kimliği (metin) ya da { id, params } nesnesi olmalı") }

            if ($null -ne $id) {
                if ($id -cnotmatch (Get-FaiIdPattern)) { $errs.Add("${path}: '$id' geçerli bir tweak kimliği değil") }
                elseif ($tweakIds.Contains($id)) { $errs.Add("${path}: '$id' birden çok kez listelenmiş") }
                else { $tweakIds.Add($id) }
            }
            $i++
        }
    }

    if ($Data.Contains('autoConfirm')) {
        if (-not (Test-FaiIsList $Data['autoConfirm'])) { $errs.Add('autoConfirm: dizi olmalı') }
        else {
            $i = 0
            foreach ($a in $Data['autoConfirm']) {
                if ($a -isnot [string]) { $errs.Add("autoConfirm[$i]: metin olmalı") }
                elseif (-not $tweakIds.Contains($a)) { $errs.Add("autoConfirm[$i]: '$a' tweaks listesinde yok") }
                $i++
            }
        }
    }
    if ($Data.Contains('apps')) {
        if (-not (Test-FaiIsList $Data['apps'])) { $errs.Add('apps: dizi olmalı') }
        else {
            $appIds = @{}
            $i = 0
            foreach ($a in $Data['apps']) {
                $path = "apps[$i]"
                $i++
                $id = $null
                if ($a -is [string]) { $id = $a }
                elseif ($a -is [System.Collections.IDictionary]) {
                    foreach ($k in @($a.Keys)) {
                        if (@('id', 'keepAutostart') -cnotcontains [string]$k) { $errs.Add("${path}.${k}: bilinmeyen alan (izin verilenler: id, keepAutostart)") }
                    }
                    if (-not $a.Contains('id')) { $errs.Add("${path}.id: zorunlu alan eksik") }
                    elseif ($a['id'] -isnot [string]) { $errs.Add("${path}.id: metin olmalı") }
                    else { $id = $a['id'] }
                    if ($a.Contains('keepAutostart') -and $a['keepAutostart'] -isnot [bool]) { $errs.Add("${path}.keepAutostart: true ya da false olmalı") }
                }
                else { $errs.Add("${path}: uygulama kimliği (metin) ya da { id, keepAutostart } nesnesi olmalı") }
                if ($null -ne $id) {
                    if ($id -cnotmatch (Get-FaiAppIdPattern)) { $errs.Add("${path}: '$id' geçerli bir uygulama kimliği değil") }
                    elseif ($appIds.ContainsKey($id)) { $errs.Add("${path}: '$id' birden çok kez listelenmiş") }
                    else { $appIds[$id] = $true }
                }
            }
        }
    }
    if ($Data.Contains('games')) {
        foreach ($m in @(Get-FaiGameError -Games $Data['games'])) { $errs.Add($m) }
    }
    foreach ($objKey in @('layout', 'exceptions')) {
        if ($Data.Contains($objKey) -and $Data[$objKey] -isnot [System.Collections.IDictionary]) { $errs.Add("${objKey}: nesne olmalı") }
    }
    if ($Data.Contains('layout') -and $Data['layout'] -is [System.Collections.IDictionary] -and $Data['layout'].Count -gt 0) {
        foreach ($m in @(Get-FaiLayoutError -Layout $Data['layout'])) { $errs.Add($m) }
    }
    return $errs.ToArray()
}

function Import-FaiTweakFile {
    <# .SYNOPSIS  Tek bir tweak .psd1 dosyasını okur, doğrular, Tweak döndürür (geçersizse alan yoluyla hata fırlatır). #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true, Position = 0)] [string] $Path)

    $data = Import-PowerShellDataFile -LiteralPath $Path
    return [Tweak]::FromHashtable($data, $Path)
}

function Import-FaiProfileFile {
    <# .SYNOPSIS  Profil .json dosyasını okur, doğrular, Profile döndürür. #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true, Position = 0)] [string] $Path)

    $data = Read-JsonFile -Path $Path
    return [Profile]::FromHashtable($data, $Path)
}

function Import-FaiTweakCatalog {
    <#
    .SYNOPSIS
        Klasördeki (alt klasörler dahil) bütün tweak .psd1 dosyalarını yükler; Id → Tweak hashtable döndürür.
        Bütün geçersiz dosyalar tek hatada listelenir; yinelenen Id hatadır.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true, Position = 0)] [string] $Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { throw "Tweak klasörü yok: $Path" }
    $catalog = @{}
    $problems = New-Object 'System.Collections.Generic.List[string]'
    foreach ($f in @(Get-ChildItem -LiteralPath $Path -Recurse -File -Filter '*.psd1' | Sort-Object FullName)) {
        try {
            $t = Import-FaiTweakFile -Path $f.FullName
            if ($catalog.ContainsKey($t.Id)) { $problems.Add("$($f.FullName): Id '$($t.Id)' birden çok dosyada") }
            else { $catalog[$t.Id] = $t }
        }
        catch { $problems.Add($_.Exception.Message) }
    }
    if ($problems.Count -gt 0) { throw ("Tweak kataloğu geçersiz:`n" + ($problems -join "`n")) }
    return $catalog
}

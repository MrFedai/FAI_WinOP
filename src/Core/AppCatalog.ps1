# Uygulama kataloğu (apps/catalog.json): profil 'apps' listesindeki kimlikleri paket + kurulum sonrası kurallara çevirir.
# Biçim belgesi: apps/_schema.json (editör desteği); asıl doğrulama burada (Get-FaiAppCatalogError).
#
#   { "apps": [ { "id": "spotify", "name": "Spotify", "source": "winget", "packageId": "Spotify.Spotify",
#                 "postInstall": { "removeAutostart": true, "startupRegistryNames": ["Spotify"],
#                                  "removeDesktopShortcut": true, "desktopShortcutNames": ["Spotify.lnk"],
#                                  "flattenStartMenu": true, "startMenuFolders": [] } } ] }
#
# Her uygulama motorda 'app.<id>' kimlikli tek eylemli (App) bir tweak'e dönüşür (ConvertTo-FaiAppTweak); dry-run,
# rapor, snapshot ve -Undo tweak'lerle aynı yoldan geçer.

function Get-FaiAppIdPattern { return '^[a-z0-9]+(-[a-z0-9]+)*$' }
function Get-FaiAppKey { return [string[]]@('id', 'name', 'source', 'packageId', 'notes', 'appxNames', 'quietUninstall', 'postInstall') }
function Get-FaiAppPostInstallKey {
    return [string[]]@('removeAutostart', 'startupRegistryNames', 'startupFolderNames', 'startupTaskNames',
        'removeDesktopShortcut', 'desktopShortcutNames', 'flattenStartMenu', 'startMenuFolders')
}

function Get-FaiAppCatalogError {
    <# .SYNOPSIS  Katalog verisinin (JSON'dan hashtable) şema hatalarını '<yol>: <neden>' metinleri olarak döndürür. #>
    [CmdletBinding()]
    param([Parameter(Position = 0)] [AllowNull()] [object] $Data)

    $errs = New-Object 'System.Collections.Generic.List[string]'
    if ($Data -isnot [System.Collections.IDictionary]) { $errs.Add('(kök): katalog JSON nesnesi olmalı'); return $errs.ToArray() }
    foreach ($k in @($Data.Keys)) {
        if (@('$schema', 'apps') -cnotcontains [string]$k) { $errs.Add("${k}: bilinmeyen alan (izin verilenler: `$schema, apps)") }
    }
    if (-not $Data.Contains('apps')) { $errs.Add('apps: zorunlu alan eksik'); return $errs.ToArray() }
    if (-not (Test-FaiIsList $Data['apps'])) { $errs.Add('apps: dizi olmalı'); return $errs.ToArray() }

    $ids = @{}
    $packages = @{}
    $i = 0
    foreach ($app in $Data['apps']) {
        $at = "apps[$i]"
        $i++
        if ($app -isnot [System.Collections.IDictionary]) { $errs.Add("${at}: nesne olmalı"); continue }
        foreach ($k in @($app.Keys)) {
            if ((Get-FaiAppKey) -cnotcontains [string]$k) { $errs.Add("${at}.${k}: bilinmeyen alan (izin verilenler: " + ((Get-FaiAppKey) -join ', ') + ')') }
        }
        foreach ($req in @('id', 'name', 'source', 'packageId')) {
            if (-not $app.Contains($req)) { $errs.Add("${at}.${req}: zorunlu alan eksik") }
            elseif ($app[$req] -isnot [string] -or [string]::IsNullOrWhiteSpace($app[$req])) { $errs.Add("${at}.${req}: boş olmayan metin olmalı") }
        }
        if ($app['id'] -is [string]) {
            if ($app['id'] -cnotmatch (Get-FaiAppIdPattern)) { $errs.Add("${at}.id: '$($app['id'])' geçersiz (küçük harf, rakam, tire)") }
            elseif ($ids.ContainsKey($app['id'])) { $errs.Add("${at}.id: '$($app['id'])' birden çok kez tanımlı") }
            else { $ids[$app['id']] = $true }
        }
        if ($app['source'] -is [string] -and @('winget', 'msstore') -cnotcontains $app['source']) { $errs.Add("${at}.source: winget ya da msstore olmalı") }
        if ($app['packageId'] -is [string]) {
            if ($app['packageId'] -notmatch '^[A-Za-z0-9][A-Za-z0-9.\-_+]*$') { $errs.Add("${at}.packageId: paket kimliği olmalı (boşluk yok)") }
            elseif ($packages.ContainsKey($app['packageId'].ToLowerInvariant())) { $errs.Add("${at}.packageId: '$($app['packageId'])' başka uygulamada da var") }
            else { $packages[$app['packageId'].ToLowerInvariant()] = $true }
        }
        if ($app.Contains('notes') -and $app['notes'] -isnot [string]) { $errs.Add("${at}.notes: metin olmalı") }
        if ($app.Contains('appxNames')) {
            $an = $app['appxNames']
            if ($an -is [string] -or $an -isnot [System.Collections.IEnumerable] -or @($an).Count -eq 0) { $errs.Add("${at}.appxNames: boş olmayan paket adı listesi olmalı") }
            else {
                foreach ($n in @($an)) {
                    if ($n -isnot [string] -or $n -notmatch '^[A-Za-z0-9][A-Za-z0-9.\-]*$') { $errs.Add("${at}.appxNames: '$n' birebir Appx paket adı olmalı") }
                }
            }
        }
        if ($app.Contains('quietUninstall')) {
            $qu = $app['quietUninstall']
            if ($qu -isnot [System.Collections.IDictionary]) { $errs.Add("${at}.quietUninstall: nesne olmalı ({ path, args })") }
            else {
                foreach ($k in @($qu.Keys)) { if (@('path', 'args') -cnotcontains [string]$k) { $errs.Add("${at}.quietUninstall.${k}: bilinmeyen alan (izin verilenler: path, args)") } }
                if (-not $qu.Contains('path')) { $errs.Add("${at}.quietUninstall.path: zorunlu alan eksik") }
                elseif (-not (Test-FaiWindowsPath $qu['path'])) { $errs.Add("${at}.quietUninstall.path: mutlak yol olmalı (%ProgramFiles%\... gibi)") }
                if ($qu.Contains('args') -and $qu['args'] -isnot [string]) { $errs.Add("${at}.quietUninstall.args: metin olmalı") }
            }
        }
        if (-not $app.Contains('postInstall')) { continue }
        $pi = $app['postInstall']
        if ($pi -isnot [System.Collections.IDictionary]) { $errs.Add("${at}.postInstall: nesne olmalı"); continue }
        foreach ($k in @($pi.Keys)) {
            if ((Get-FaiAppPostInstallKey) -cnotcontains [string]$k) {
                $errs.Add("${at}.postInstall.${k}: bilinmeyen alan (izin verilenler: " + ((Get-FaiAppPostInstallKey) -join ', ') + ')')
            }
        }
        foreach ($k in @('removeAutostart', 'removeDesktopShortcut', 'flattenStartMenu')) {
            if ($pi.Contains($k) -and $pi[$k] -isnot [bool]) { $errs.Add("${at}.postInstall.${k}: true ya da false olmalı") }
        }
        foreach ($k in @('startupRegistryNames', 'startupFolderNames', 'startupTaskNames', 'desktopShortcutNames', 'startMenuFolders')) {
            if (-not $pi.Contains($k)) { continue }
            if (-not (Test-FaiIsList $pi[$k])) { $errs.Add("${at}.postInstall.${k}: dizi olmalı"); continue }
            $j = 0
            foreach ($item in $pi[$k]) {
                $p = "${at}.postInstall.${k}[$j]"
                $j++
                if ($item -isnot [string] -or [string]::IsNullOrWhiteSpace($item)) { $errs.Add("${p}: boş olmayan metin olmalı"); continue }
                if ($k -eq 'startupFolderNames' -and $item -notlike '*.lnk') { $errs.Add("${p}: .lnk dosya adı olmalı") }
                if ($k -eq 'startupRegistryNames' -and $item -like '*.lnk') { $errs.Add("${p}: Run değeri adı olmalı (.lnk startupFolderNames'e)") }
            }
        }
    }
    # Eylem düzeyindeki kurallar (yol / joker / görev yolu) dönüştürülmüş tanım üzerinden denetlenir.
    if ($errs.Count -eq 0) {
        foreach ($app in $Data['apps']) {
            $def = ConvertTo-FaiAppActionDefinition -App $app -KeepAutostart $false
            foreach ($m in (Get-FaiActionError -Definition $def -Path ("apps[{0}] ({1})" -f $app['id'], 'App'))) { $errs.Add($m) }
        }
    }
    return $errs.ToArray()
}

function ConvertTo-FaiAppActionDefinition {
    <# .SYNOPSIS  Katalog kaydını App eylem tanımına çevirir (doğrulanmış kayıt beklenir). #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [System.Collections.IDictionary] $App,
        [bool] $KeepAutostart = $false
    )

    $def = @{ Type = 'App'; Id = [string]$App['packageId']; Source = [string]$App['source'] }
    if ($App.Contains('quietUninstall')) {
        $def['UninstallPath'] = [string]$App['quietUninstall']['path']
        if ($App['quietUninstall'].Contains('args')) { $def['UninstallArgs'] = [string]$App['quietUninstall']['args'] }
    }
    $pi = @{}
    if ($App.Contains('postInstall')) { $pi = $App['postInstall'] }
    if ([bool]$pi['removeAutostart'] -and -not $KeepAutostart) {
        $names = @(@($pi['startupRegistryNames']) + @($pi['startupFolderNames']) | Where-Object { $_ })
        if ($names.Count -gt 0) { $def['DisableStartup'] = [string[]]$names }
        $tasks = @(@($pi['startupTaskNames']) | Where-Object { $_ })
        if ($tasks.Count -gt 0) { $def['DisableTasks'] = [string[]]$tasks }
    }
    if ([bool]$pi['removeDesktopShortcut']) {
        $def['CleanNewShortcuts'] = $true
        $links = @(@($pi['desktopShortcutNames']) | Where-Object { $_ })
        if ($links.Count -gt 0) { $def['RemoveShortcuts'] = [string[]]$links }
    }
    if ([bool]$pi['flattenStartMenu']) {
        $folders = @(@($pi['startMenuFolders']) | Where-Object { $_ })
        if ($folders.Count -gt 0) { $def['FlattenFolders'] = [string[]]$folders }
    }
    return $def
}

function ConvertTo-FaiAppTweak {
    <#
    .SYNOPSIS
        Katalog kaydından 'app.<id>' kimlikli tweak üretir (tek App eylemi, Risk Safe, kategori apps).
    .PARAMETER KeepAutostart
        Profilde keepAutostart: otomatik başlatma kuralları uygulanmaz (ör. WhatsApp, Telegram).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [System.Collections.IDictionary] $App,
        [bool] $KeepAutostart = $false
    )

    $def = ConvertTo-FaiAppActionDefinition -App $App -KeepAutostart $KeepAutostart
    $desc = 'Kurulum: {0} {1} (sessiz).' -f $App['source'], $App['packageId']
    if ($App.Contains('notes') -and $App['notes']) { $desc += ' ' + [string]$App['notes'] }
    $data = @{
        Id          = 'app.' + [string]$App['id']
        Title       = [string]$App['name']
        Description = $desc
        Category    = 'apps'
        Risk        = 'Safe'
        Actions     = @($def)
    }
    return [Tweak]::FromHashtable($data, 'apps/catalog.json')
}

function Import-FaiAppCatalog {
    <# .SYNOPSIS  apps/catalog.json'u okur, doğrular; id → uygulama kaydı (hashtable) döndürür. #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true, Position = 0)] [string] $Path)

    return ConvertTo-FaiAppCatalog -Data (Read-JsonFile -Path $Path) -Source $Path
}

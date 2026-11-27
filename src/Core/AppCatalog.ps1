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
    if ($Data -isnot [System.Collections.IDictionary]) { $errs.Add('(root): catalog must be a JSON object'); return $errs.ToArray() }
    foreach ($k in @($Data.Keys)) {
        if (@('$schema', 'apps') -cnotcontains [string]$k) { $errs.Add("${k}: unknown field (allowed: `$schema, apps)") }
    }
    if (-not $Data.Contains('apps')) { $errs.Add('apps: required field missing'); return $errs.ToArray() }
    if (-not (Test-FaiIsList $Data['apps'])) { $errs.Add('apps: must be an array'); return $errs.ToArray() }

    $ids = @{}
    $packages = @{}
    $i = 0
    foreach ($app in $Data['apps']) {
        $at = "apps[$i]"
        $i++
        if ($app -isnot [System.Collections.IDictionary]) { $errs.Add("${at}: must be an object"); continue }
        foreach ($k in @($app.Keys)) {
            if ((Get-FaiAppKey) -cnotcontains [string]$k) { $errs.Add("${at}.${k}: unknown field (allowed: " + ((Get-FaiAppKey) -join ', ') + ')') }
        }
        foreach ($req in @('id', 'name', 'source', 'packageId')) {
            if (-not $app.Contains($req)) { $errs.Add("${at}.${req}: required field missing") }
            elseif ($app[$req] -isnot [string] -or [string]::IsNullOrWhiteSpace($app[$req])) { $errs.Add("${at}.${req}: must be a non-empty string") }
        }
        if ($app['id'] -is [string]) {
            if ($app['id'] -cnotmatch (Get-FaiAppIdPattern)) { $errs.Add("${at}.id: '$($app['id'])' is invalid (lowercase letters, digits, hyphens)") }
            elseif ($ids.ContainsKey($app['id'])) { $errs.Add("${at}.id: '$($app['id'])' is defined more than once") }
            else { $ids[$app['id']] = $true }
        }
        if ($app['source'] -is [string] -and @('winget', 'msstore') -cnotcontains $app['source']) { $errs.Add("${at}.source: must be winget or msstore") }
        if ($app['packageId'] -is [string]) {
            if ($app['packageId'] -notmatch '^[A-Za-z0-9][A-Za-z0-9.\-_+]*$') { $errs.Add("${at}.packageId: must be a package ID (no spaces)") }
            elseif ($packages.ContainsKey($app['packageId'].ToLowerInvariant())) { $errs.Add("${at}.packageId: '$($app['packageId'])' is also used by another app") }
            else { $packages[$app['packageId'].ToLowerInvariant()] = $true }
        }
        if ($app.Contains('notes') -and $app['notes'] -isnot [string]) { $errs.Add("${at}.notes: must be a string") }
        if ($app.Contains('appxNames')) {
            $an = $app['appxNames']
            if ($an -is [string] -or $an -isnot [System.Collections.IEnumerable] -or @($an).Count -eq 0) { $errs.Add("${at}.appxNames: must be a non-empty list of package names") }
            else {
                foreach ($n in @($an)) {
                    if ($n -isnot [string] -or $n -notmatch '^[A-Za-z0-9][A-Za-z0-9.\-]*$') { $errs.Add("${at}.appxNames: '$n' must be an exact Appx package name") }
                }
            }
        }
        if ($app.Contains('quietUninstall')) {
            $qu = $app['quietUninstall']
            if ($qu -isnot [System.Collections.IDictionary]) { $errs.Add("${at}.quietUninstall: must be an object ({ path, args })") }
            else {
                foreach ($k in @($qu.Keys)) { if (@('path', 'args') -cnotcontains [string]$k) { $errs.Add("${at}.quietUninstall.${k}: unknown field (allowed: path, args)") } }
                if (-not $qu.Contains('path')) { $errs.Add("${at}.quietUninstall.path: required field missing") }
                elseif (-not (Test-FaiWindowsPath $qu['path'])) { $errs.Add("${at}.quietUninstall.path: must be an absolute path (e.g. %ProgramFiles%\...)") }
                if ($qu.Contains('args') -and $qu['args'] -isnot [string]) { $errs.Add("${at}.quietUninstall.args: must be a string") }
            }
        }
        if (-not $app.Contains('postInstall')) { continue }
        $pi = $app['postInstall']
        if ($pi -isnot [System.Collections.IDictionary]) { $errs.Add("${at}.postInstall: must be an object"); continue }
        foreach ($k in @($pi.Keys)) {
            if ((Get-FaiAppPostInstallKey) -cnotcontains [string]$k) {
                $errs.Add("${at}.postInstall.${k}: unknown field (allowed: " + ((Get-FaiAppPostInstallKey) -join ', ') + ')')
            }
        }
        foreach ($k in @('removeAutostart', 'removeDesktopShortcut', 'flattenStartMenu')) {
            if ($pi.Contains($k) -and $pi[$k] -isnot [bool]) { $errs.Add("${at}.postInstall.${k}: must be true or false") }
        }
        foreach ($k in @('startupRegistryNames', 'startupFolderNames', 'startupTaskNames', 'desktopShortcutNames', 'startMenuFolders')) {
            if (-not $pi.Contains($k)) { continue }
            if (-not (Test-FaiIsList $pi[$k])) { $errs.Add("${at}.postInstall.${k}: must be an array"); continue }
            $j = 0
            foreach ($item in $pi[$k]) {
                $p = "${at}.postInstall.${k}[$j]"
                $j++
                if ($item -isnot [string] -or [string]::IsNullOrWhiteSpace($item)) { $errs.Add("${p}: must be a non-empty string"); continue }
                if ($k -eq 'startupFolderNames' -and $item -notlike '*.lnk') { $errs.Add("${p}: must be a .lnk file name") }
                if ($k -eq 'startupRegistryNames' -and $item -like '*.lnk') { $errs.Add("${p}: must be a Run value name (.lnk files go in startupFolderNames)") }
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
    $desc = 'Install: {0} {1} (silent).' -f $App['source'], $App['packageId']
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

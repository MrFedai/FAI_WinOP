# Profil düzeni ('layout'): görev çubuğu, masaüstü simgeleri ve Başlat sabitlemeleri. Export-FaiLayout mevcut düzeni
# okur (-ExportLayout), motor profildeki düzeni 'layout.profile' tweak'i olarak uygular (ConvertTo-FaiLayoutTweak) ve
# -Undo onu diğer tweak'ler gibi geri alır. Her bölüm isteğe bağlıdır; yalnız yazılan alanlar uygulanır.
#
#   "layout": {
#     "taskbar":      { "alignment": "center", "autoHide": true,
#                       "pins": [ { "appId": "Microsoft.Windows.Explorer" },
#                                 { "link": "%ProgramData%\\Microsoft\\Windows\\Start Menu\\Programs\\Google Chrome.lnk" },
#                                 { "aumid": "Microsoft.WindowsStore_8wekyb3d8bbwe!App" } ] },
#     "desktopIcons": { "thisPC": true, "recycleBin": true, "userFiles": false, "network": false, "controlPanel": false },
#     "desktop":      { "flags": 1075839524, "iconSize": 48, "iconLayouts": "<base64>" },   // simge konumları (ham)
#     "start":        { "start2": "<base64>" }                                               // Başlat sabitlemeleri (ham)
#   }
# 'desktop.iconLayouts' masaüstündeki öğe adlarını, 'start.start2' Başlat sabitlemelerini içerir: açık repoya koymadan
# önce gözden geçirilmeli (Export uyarır).

function Get-FaiDesktopIconMap {
    <# .SYNOPSIS  layout.desktopIcons anahtarı → @{ Clsid; Default (değer yokken görünür mü) }. #>
    return [ordered]@{
        thisPC       = @{ Clsid = '{20D04FE0-3AEA-1069-A2D8-08002B30309D}'; Default = $false }
        recycleBin   = @{ Clsid = '{645FF040-5081-101B-9F08-00AA002F954E}'; Default = $true }
        userFiles    = @{ Clsid = '{59031a47-3f72-44a7-89c5-5595fe6b30ee}'; Default = $false }
        network      = @{ Clsid = '{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}'; Default = $false }
        controlPanel = @{ Clsid = '{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}'; Default = $false }
    }
}

function Get-FaiLayoutPath {
    <# .SYNOPSIS  Düzenin okunduğu / yazıldığı sabit yerler. #>
    return @{
        Advanced       = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        StuckRects     = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
        DesktopIcons   = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel'
        DesktopBag     = 'HKCU:\Software\Microsoft\Windows\Shell\Bags\1\Desktop'
        Start2         = '%LOCALAPPDATA%\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin'
    }
}

function Get-FaiLayoutError {
    <# .SYNOPSIS  layout nesnesinin yapı hataları ('layout.<yol>: <neden>'); eylem düzeyi denetimi ConvertTo-FaiLayoutTweak yapar. #>
    [CmdletBinding()]
    param([Parameter(Position = 0)] [AllowNull()] [object] $Layout)

    $errs = New-Object 'System.Collections.Generic.List[string]'
    if ($Layout -isnot [System.Collections.IDictionary]) { $errs.Add('layout: must be an object'); return $errs.ToArray() }
    $sections = @{
        taskbar      = @('alignment', 'autoHide', 'pins')
        desktopIcons = @((Get-FaiDesktopIconMap).Keys)
        desktop      = @('flags', 'iconSize', 'iconLayouts')
        start        = @('start2')
    }
    foreach ($k in @($Layout.Keys)) {
        $key = [string]$k
        if (-not $sections.ContainsKey($key)) { $errs.Add("layout.${key}: unknown field (allowed: " + (@($sections.Keys | Sort-Object) -join ', ') + ')'); continue }
        $sec = $Layout[$k]
        if ($sec -isnot [System.Collections.IDictionary]) { $errs.Add("layout.${key}: must be an object"); continue }
        foreach ($sk in @($sec.Keys)) {
            if ($sections[$key] -cnotcontains [string]$sk) { $errs.Add("layout.${key}.${sk}: unknown field (allowed: " + ($sections[$key] -join ', ') + ')') }
        }
    }
    if ($errs.Count -gt 0) { return $errs.ToArray() }

    if ($Layout.Contains('taskbar')) {
        $tb = $Layout['taskbar']
        if ($tb.Contains('alignment') -and @('center', 'left') -cnotcontains $tb['alignment']) { $errs.Add('layout.taskbar.alignment: must be center or left') }
        if ($tb.Contains('autoHide') -and $tb['autoHide'] -isnot [bool]) { $errs.Add('layout.taskbar.autoHide: must be true or false') }
        if ($tb.Contains('pins')) {
            if (-not (Test-FaiIsList $tb['pins']) -and $null -ne $tb['pins']) { $errs.Add('layout.taskbar.pins: must be an array') }
            else {
                $i = 0
                foreach ($p in @($tb['pins'])) {
                    $keys = @()
                    if ($p -is [System.Collections.IDictionary]) { $keys = @($p.Keys | ForEach-Object { [string]$_ }) }
                    if ($keys.Count -ne 1 -or @('appId', 'link', 'aumid') -cnotcontains $keys[0] -or $p[$keys[0]] -isnot [string]) {
                        $errs.Add("layout.taskbar.pins[$i]: must be an { appId | link | aumid: string } object")
                    }
                    $i++
                }
            }
        }
    }
    if ($Layout.Contains('desktopIcons')) {
        foreach ($k in @($Layout['desktopIcons'].Keys)) {
            if ($Layout['desktopIcons'][$k] -isnot [bool]) { $errs.Add("layout.desktopIcons.${k}: must be true or false") }
        }
    }
    if ($Layout.Contains('desktop')) {
        $d = $Layout['desktop']
        foreach ($k in @('flags', 'iconSize')) {
            if ($d.Contains($k) -and -not (Test-FaiIsInteger $d[$k])) { $errs.Add("layout.desktop.${k}: must be an integer") }
        }
        if ($d.Contains('iconLayouts') -and -not (Test-FaiIsBase64 $d['iconLayouts'])) { $errs.Add('layout.desktop.iconLayouts: must be a base64 string') }
    }
    if ($Layout.Contains('start') -and $Layout['start'].Contains('start2') -and -not (Test-FaiIsBase64 $Layout['start']['start2'])) {
        $errs.Add('layout.start.start2: must be a base64 string')
    }
    if ($errs.Count -gt 0) { return $errs.ToArray() }

    # Eylem düzeyi (yol, AUMID biçimi...) denetimi.
    try { [void](ConvertTo-FaiLayoutTweak -Layout $Layout) }
    catch { $errs.Add('layout: ' + $_.Exception.Message) }
    return $errs.ToArray()
}

function Test-FaiIsBase64 {
    [CmdletBinding()]
    param([Parameter(Position = 0)] [AllowNull()] [object] $Value)
    if ($Value -isnot [string] -or $Value.Length -eq 0) { return $false }
    try { [void][Convert]::FromBase64String($Value); return $true }
    catch { return $false }
}

function ConvertTo-FaiLayoutTweak {
    <#
    .SYNOPSIS
        Profilin layout nesnesinden 'layout.profile' tweak'i üretir (Registry, RegistryByte, File, TaskbarPins eylemleri).
        Sabitlemeler (Gezgin'i yeniden başlatır) en sonda; Başlat ve Gezgin çalıştırma sonunda yeniden başlar.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [System.Collections.IDictionary] $Layout)

    $p = Get-FaiLayoutPath
    $actions = New-Object 'System.Collections.Generic.List[hashtable]'
    $tb = $null
    if ($Layout.Contains('taskbar')) { $tb = $Layout['taskbar'] }

    if ($null -ne $tb -and $tb.Contains('alignment')) {
        $al = 1
        if ($tb['alignment'] -eq 'left') { $al = 0 }
        $actions.Add(@{ Type = 'Registry'; Path = $p.Advanced; Name = 'TaskbarAl'; Value = $al; Kind = 'DWord' })
    }
    if ($null -ne $tb -and $tb.Contains('autoHide')) {
        $actions.Add(@{ Type = 'RegistryByte'; Path = $p.StuckRects; Name = 'Settings'; Offset = 8; Mask = 1; Value = [bool]$tb['autoHide'] })
    }
    if ($Layout.Contains('desktopIcons')) {
        $map = Get-FaiDesktopIconMap
        foreach ($k in @($map.Keys)) {
            if (-not $Layout['desktopIcons'].Contains($k)) { continue }
            $hidden = 1
            if ([bool]$Layout['desktopIcons'][$k]) { $hidden = 0 }
            $actions.Add(@{ Type = 'Registry'; Path = $p.DesktopIcons; Name = $map[$k].Clsid; Value = $hidden; Kind = 'DWord' })
        }
    }
    if ($Layout.Contains('desktop')) {
        $d = $Layout['desktop']
        if ($d.Contains('flags')) { $actions.Add(@{ Type = 'Registry'; Path = $p.DesktopBag; Name = 'FFlags'; Value = [long]$d['flags']; Kind = 'DWord' }) }
        if ($d.Contains('iconSize')) { $actions.Add(@{ Type = 'Registry'; Path = $p.DesktopBag; Name = 'IconSize'; Value = [long]$d['iconSize']; Kind = 'DWord' }) }
        if ($d.Contains('iconLayouts')) {
            $bytes = [Convert]::FromBase64String([string]$d['iconLayouts'])
            $actions.Add(@{ Type = 'Registry'; Path = $p.DesktopBag; Name = 'IconLayouts'; Value = [int[]]@($bytes | ForEach-Object { [int]$_ }); Kind = 'Binary' })
        }
    }
    if ($Layout.Contains('start') -and $Layout['start'].Contains('start2')) {
        $actions.Add(@{ Type = 'File'; Path = $p.Start2; Base64 = [string]$Layout['start']['start2'] })
    }
    if ($null -ne $tb -and $tb.Contains('pins')) {
        $pins = New-Object 'System.Collections.Generic.List[hashtable]'
        foreach ($pin in @($tb['pins'])) {
            if ($null -eq $pin) { continue }
            if ($pin.Contains('appId')) { $pins.Add(@{ AppId = [string]$pin['appId'] }) }
            elseif ($pin.Contains('link')) { $pins.Add(@{ Link = [string]$pin['link'] }) }
            else { $pins.Add(@{ Aumid = [string]$pin['aumid'] }) }
        }
        $actions.Add(@{ Type = 'TaskbarPins'; Pins = $pins.ToArray() })
    }
    if ($actions.Count -eq 0) { throw 'layout is empty: nothing to apply' }

    $data = @{
        Id          = 'layout.profile'
        Title       = 'Profile layout (taskbar, desktop, Start)'
        Description = 'The profile layout section (captured with -ExportLayout): taskbar alignment / auto-hide / pins, desktop icons and their positions, Start pins.'
        Category    = 'ui'
        Risk        = 'Safe'
        Refresh     = @('StartMenu', 'Shell')
        Actions     = $actions.ToArray()
    }
    return [Tweak]::FromHashtable($data, 'profile.layout')
}

function ConvertTo-FaiPortablePath {
    <# .SYNOPSIS  Mutlak yolu ortam değişkenli biçime çevirir (%APPDATA%, %ProgramData%...); kullanıcı adı repoya girmesin. #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true, Position = 0)] [string] $Path)

    foreach ($var in @('APPDATA', 'LOCALAPPDATA', 'ProgramData', 'USERPROFILE', 'ProgramFiles(x86)', 'ProgramFiles', 'SystemRoot')) {
        $token = '%' + $var + '%'
        $value = Expand-FaiPath $token
        if ($value -eq $token -or -not $value) { continue }
        if ($Path.StartsWith($value.TrimEnd('\') + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
            return $token + $Path.Substring($value.TrimEnd('\').Length)
        }
    }
    return $Path
}

function Export-FaiLayout {
    <#
    .SYNOPSIS
        Mevcut düzeni (salt okunur) profil layout nesnesi olarak okur: @{ Layout; Warnings }.
    .DESCRIPTION
        Görev çubuğu sabitlemeleri taşınabilir biçime çevrilir: Gezgin → appId, masaüstü uygulaması → Başlat menüsündeki
        aynı hedefli kısayolun yolu (link), Store uygulaması → aumid. Başlat menüsünde kısayolu olmayan sabitleme
        alınamaz (uyarı).
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [ExecutionContext] $Context)

    $cx = $Context
    $p = Get-FaiLayoutPath
    $warn = New-Object 'System.Collections.Generic.List[string]'
    $layout = [ordered]@{}

    # Görev çubuğu
    $tb = [ordered]@{}
    $al = 'center'
    if ($cx.Registry.ValueExists($p.Advanced, 'TaskbarAl') -and [int]$cx.Registry.GetValue($p.Advanced, 'TaskbarAl') -eq 0) { $al = 'left' }
    $tb['alignment'] = $al
    $byte = ([RegistryByteAction]::new(@{ Type = 'RegistryByte'; Path = $p.StuckRects; Name = 'Settings'; Offset = 8; Mask = 1; Value = 1 })).Current($cx)
    if ($byte -ge 0) { $tb['autoHide'] = (($byte -band 1) -eq 1) }
    else { $warn.Add('StuckRects3 not found: auto-hide could not be read') }

    $menuLinks = @()
    foreach ($folder in @('CommonPrograms', 'Programs')) {
        $dir = $cx.Files.GetKnownFolder($folder)
        if ($dir) { $menuLinks += @($cx.Files.FindFiles($dir, '*.lnk')) }
    }
    $pins = New-Object System.Collections.ArrayList
    foreach ($cur in [TaskbarPinsAction]::Current($cx)) {
        if ($cur.ContainsKey('Aumid')) { [void]$pins.Add([ordered]@{ aumid = [string]$cur['Aumid'] }); continue }
        $key = [string]$cur['Key']
        if ($key.StartsWith('appid:')) {
            $id = @([TaskbarPinsAction]::KnownAppIds().Keys | Where-Object { $_.ToLowerInvariant() -eq $key.Substring(6) })[0]
            [void]$pins.Add([ordered]@{ appId = [string]$id })
            continue
        }
        $target = [TaskbarPinsAction]::NormTarget([string]$cur['Target'])
        $match = $null
        foreach ($l in $menuLinks) {
            $sc = $cx.Shortcuts.ReadShortcut($l)
            if ($target -and $null -ne $sc -and $sc['TargetPath'] -and [TaskbarPinsAction]::NormTarget([string]$sc['TargetPath']) -eq $target) { $match = $l; break }
        }
        if ($null -eq $match) { $warn.Add(('Pin not captured (no Start menu shortcut with the same target): {0}' -f $cur['Label'])); continue }
        [void]$pins.Add([ordered]@{ link = (ConvertTo-FaiPortablePath $match) })
    }
    $tb['pins'] = $pins.ToArray()
    $layout['taskbar'] = $tb

    # Masaüstü simgeleri
    $icons = [ordered]@{}
    $map = Get-FaiDesktopIconMap
    foreach ($k in @($map.Keys)) {
        $shown = [bool]$map[$k].Default
        if ($cx.Registry.ValueExists($p.DesktopIcons, $map[$k].Clsid)) { $shown = ([int]$cx.Registry.GetValue($p.DesktopIcons, $map[$k].Clsid) -eq 0) }
        $icons[$k] = $shown
    }
    $layout['desktopIcons'] = $icons

    # Masaüstü görünümü ve simge konumları
    $desk = [ordered]@{}
    if ($cx.Registry.ValueExists($p.DesktopBag, 'FFlags')) { $desk['flags'] = [long]([uint32]([int]$cx.Registry.GetValue($p.DesktopBag, 'FFlags') -band 0xFFFFFFFFL)) }
    if ($cx.Registry.ValueExists($p.DesktopBag, 'IconSize')) { $desk['iconSize'] = [long][int]$cx.Registry.GetValue($p.DesktopBag, 'IconSize') }
    if ($cx.Registry.ValueExists($p.DesktopBag, 'IconLayouts')) {
        $desk['iconLayouts'] = [Convert]::ToBase64String([byte[]](ConvertTo-FaiRegistryValue -Value $cx.Registry.GetValue($p.DesktopBag, 'IconLayouts') -Kind 'Binary'))
        $warn.Add('desktop.iconLayouts contains the names of items on your desktop: review it before putting it in a public repo')
    }
    if ($desk.Count -gt 0) { $layout['desktop'] = $desk }

    # Başlat
    $start2 = Expand-FaiPath $p.Start2
    if ($cx.Files.FileExists($start2)) {
        $layout['start'] = [ordered]@{ start2 = [Convert]::ToBase64String($cx.Files.ReadBytes($start2)) }
        $warn.Add('start.start2 contains your Start pins (binary): review it before putting it in a public repo')
    }
    else { $warn.Add('start2.bin not found: Start layout not captured') }

    return @{ Layout = $layout; Warnings = $warn.ToArray() }
}

function Save-FaiProfileLayout {
    <#
    .SYNOPSIS
        Düzeni profil dosyasının 'layout' bölümüne yazar (dosya yoksa adını dosyadan alan boş profil oluşturur).
        Alanlar şemadaki sırayla yazılır; sonuç Get-FaiProfileError ile doğrulanır, geçersizse yazılmaz.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $Path,
        [Parameter(Mandatory = $true)] [System.Collections.IDictionary] $Layout
    )

    $data = @{}
    if (Test-Path -LiteralPath $Path -PathType Leaf) { $data = Read-JsonFile -Path $Path }
    else {
        $data['name'] = ([System.IO.Path]::GetFileNameWithoutExtension($Path)).ToLowerInvariant()
        $data['tweaks'] = @()
    }
    $data['layout'] = $Layout
    $errors = @(Get-FaiProfileError -Data (ConvertFrom-JsonText -Json ($data | ConvertTo-Json -Depth 20)))
    if ($errors.Count -gt 0) { throw ("Invalid profile, not written ({0}):`n  {1}" -f $Path, ($errors -join "`n  ")) }
    $ordered = [ordered]@{}
    foreach ($k in (Get-FaiProfileKey)) { if ($data.Contains($k)) { $ordered[$k] = $data[$k] } }
    $json = ($ordered | ConvertTo-Json -Depth 20) -replace "`r`n", "`n"
    $dir = [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($Path))
    if ($dir -and -not [System.IO.Directory]::Exists($dir)) { [void][System.IO.Directory]::CreateDirectory($dir) }
    [System.IO.File]::WriteAllText([System.IO.Path]::GetFullPath($Path), $json + "`n", (New-Object System.Text.UTF8Encoding($false)))
}

function Invoke-FaiExportLayout {
    <#
    .SYNOPSIS
        -ExportLayout: mevcut düzeni okur, profil dosyasının layout bölümüne yazar, özeti ve uyarıları basar.
    .PARAMETER ProfilePath
        Yazılacak profil .json dosyası (yoksa oluşturulur).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $ProfilePath,
        [Parameter(Mandatory = $true)] [ExecutionContext] $Context
    )

    $result = Export-FaiLayout -Context $Context
    Save-FaiProfileLayout -Path $ProfilePath -Layout $result.Layout
    $tb = $result.Layout['taskbar']
    $pinText = (@($tb['pins']) | ForEach-Object { @($_.Values)[0] }) -join ', '
    Write-Host ('Layout written: {0}' -f $ProfilePath)
    Write-Host ('  taskbar: {0}, auto-hide: {1}, pins: {2}' -f $tb['alignment'], $tb['autoHide'], $pinText)
    Write-Host ('  desktop icons: {0}' -f ((@($result.Layout['desktopIcons'].Keys) | Where-Object { $result.Layout['desktopIcons'][$_] }) -join ', '))
    foreach ($w in $result.Warnings) { Write-Host ('  WARNING: {0}' -f $w) -ForegroundColor Yellow }
    return $result.Layout
}

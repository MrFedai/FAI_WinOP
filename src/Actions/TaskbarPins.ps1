# TaskbarPinsAction: görev çubuğu sabitlemelerini verilen listeyle (sırayla) DEĞİŞTİRİR; listede olmayan her şey kalkar.
#
#   @{ Type='TaskbarPins'; Pins=@(
#        @{ AppId='Microsoft.Windows.Explorer' }                                                   # Dosya Gezgini
#        @{ Link='%ProgramData%\Microsoft\Windows\Start Menu\Programs\Google Chrome.lnk' }         # masaüstü uygulaması
#        @{ Aumid='Microsoft.WindowsStore_8wekyb3d8bbwe!App' } ) }                                 # Store (UWP) uygulaması
#
# Windows'un desteklenen yolu kullanılır (LayoutModification.xml, "Start Layout" ilkesi, PinListPlacement=Replace):
#   1) var olan sabitlemeler silinir: HKCU\...\Explorer\Taskband değerleri + User Pinned\TaskBar\*.lnk
#   2) XML %ProgramData%\FAI_WinOP\shared\TaskbarLayout.xml'e yazılır, ilke (StartLayoutFile + LockedStartLayout=1) kurulur
#      (Gezgin kullanıcı bağlamında okur: shared\ alt klasörünü Users okur, yalnız yönetici yazar)
#   3) Gezgin yeniden başlar, düzeni uygular (Taskband'e yazar); en çok ~15 sn beklenir
#   4) ilke ve XML eski haline döner (tek seferlik: kullanıcı sonradan sabitleme ekleyip çıkarabilir)
# Kısayolu (Link) olmayan uygulama atlanır (henüz kurulu değil): sonraki çalıştırmada eklenir.
# Mevcut sabitlemeler: User Pinned\TaskBar kısayollarının hedefleri + Taskband 'Favorites' ikilisindeki AUMID'ler; sıra
# Favorites içindeki geçiş sırasından okunur.
# Undo: Taskband değerleri ve kısayol dosyaları birebir geri yazılır, Gezgin yeniden başlar.
# Etkileşimli kabuk yoksa (CI, hizmet oturumu) uygulanamaz: hata.

class TaskbarPinsAction : ActionBase {
    static [string] $TaskbandKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband'
    static [string] $PinnedDir = '%APPDATA%\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar'
    static [string] $PolicyKey = 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'
    static [string] $XmlPath = '%ProgramData%\FAI_WinOP\shared\TaskbarLayout.xml'

    TaskbarPinsAction([hashtable] $Definition) : base($Definition) { }

    # Bilinen masaüstü uygulama kimlikleri → hedef .exe (Test bu hedefle eşleştirir).
    static [hashtable] KnownAppIds() {
        return @{ 'Microsoft.Windows.Explorer' = '%SystemRoot%\explorer.exe' }
    }

    static [string] AumidPattern() { return '[A-Za-z0-9][A-Za-z0-9.\-]*_[a-z0-9]{13}![A-Za-z0-9][A-Za-z0-9.\-]*' }

    static [string[]] Validate([object] $Def) {
        $e = New-Object 'System.Collections.Generic.List[string]'
        foreach ($m in (Get-FaiUnknownKeyError $Def @('Type', 'Pins'))) { $e.Add($m) }
        if (-not $Def.Contains('Pins')) { $e.Add('Pins: zorunlu alan eksik'); return $e.ToArray() }
        if (Test-FaiHasPlaceholder $Def['Pins']) { return $e.ToArray() }
        if (-not (Test-FaiIsList $Def['Pins'])) { $e.Add('Pins: dizi olmalı (boş dizi = hiç sabitleme yok)'); return $e.ToArray() }
        $i = 0
        foreach ($p in $Def['Pins']) {
            $path = "Pins[$i]"
            $i++
            if ($p -isnot [System.Collections.IDictionary]) { $e.Add("${path}: @{ AppId | Link | Aumid = '...' } olmalı"); continue }
            $keys = @($p.Keys | ForEach-Object { [string]$_ })
            if ($keys.Count -ne 1 -or @('AppId', 'Link', 'Aumid') -cnotcontains $keys[0]) { $e.Add("${path}: tam olarak bir alan olmalı: AppId, Link ya da Aumid"); continue }
            $v = $p[$keys[0]]
            if ($v -isnot [string] -or [string]::IsNullOrWhiteSpace($v)) { $e.Add("${path}.$($keys[0]): boş olmayan metin olmalı"); continue }
            switch ($keys[0]) {
                'AppId' {
                    if (-not [TaskbarPinsAction]::KnownAppIds().ContainsKey($v)) {
                        $e.Add("${path}.AppId: bilinmeyen kimlik '$v' (bilinenler: " + (@([TaskbarPinsAction]::KnownAppIds().Keys) -join ', ') + '; diğerleri için Link)')
                    }
                }
                'Link' { if (-not (Test-FaiWindowsPath $v) -or $v -notlike '*.lnk') { $e.Add("${path}.Link: .lnk dosyasının mutlak yolu olmalı (%ProgramData%\...)") } }
                'Aumid' { if ($v -cnotmatch ('^' + [TaskbarPinsAction]::AumidPattern() + '$')) { $e.Add("${path}.Aumid: '<paket ailesi>!<uygulama>' biçiminde olmalı") } }
            }
        }
        return $e.ToArray()
    }

    static [string] NormTarget([string] $Path) {
        if (-not $Path) { return '' }
        return (Expand-FaiPath $Path).ToLowerInvariant()
    }

    # İstenen sabitlemeler, sırayla: @{ Key; Label; Kind; Value } ('appid:<kimlik>' / 'link:<hedef>' / 'aumid:<kimlik>');
    # kısayolu olmayan Link atlanır.
    [hashtable[]] Wanted([ExecutionContext] $Ctx) {
        $out = New-Object 'System.Collections.Generic.List[hashtable]'
        foreach ($p in @($this.Definition['Pins'])) {
            if ($p.Contains('AppId')) {
                $id = [string]$p['AppId']
                $out.Add(@{ Key = 'appid:' + $id.ToLowerInvariant(); Label = $id; Kind = 'AppId'; Value = $id })
            }
            elseif ($p.Contains('Link')) {
                $link = [string]$p['Link']
                $sc = $Ctx.Shortcuts.ReadShortcut((Expand-FaiPath $link))
                if ($null -eq $sc -or -not $sc['TargetPath']) { continue }
                $out.Add(@{ Key = 'link:' + [TaskbarPinsAction]::NormTarget([string]$sc['TargetPath']); Label = (Get-FaiFileName $link); Kind = 'Link'; Value = $link })
            }
            else {
                $a = [string]$p['Aumid']
                $out.Add(@{ Key = 'aumid:' + $a.ToLowerInvariant(); Label = $a; Kind = 'Aumid'; Value = $a })
            }
        }
        return $out.ToArray()
    }

    # Taskband 'Favorites' ikilisi UTF-16 metin olarak (iki hizalama; kabuk öğe kimliklerinde metin tek adreste olabilir).
    static [string[]] FavoritesText([ExecutionContext] $Ctx) {
        $key = [TaskbarPinsAction]::TaskbandKey
        if (-not $Ctx.Registry.ValueExists($key, 'Favorites')) { return [string[]]@() }
        return [TaskbarPinsAction]::Utf16Texts([byte[]](ConvertTo-FaiRegistryValue -Value $Ctx.Registry.GetValue($key, 'Favorites') -Kind 'Binary'))
    }

    # Baytlar UTF-16 metin olarak, iki hizalamada (çift / tek adres).
    static [string[]] Utf16Texts([byte[]] $Bytes) {
        if ($null -eq $Bytes -or $Bytes.Length -lt 2) { return [string[]]@() }
        $u = [System.Text.Encoding]::Unicode
        return [string[]]@($u.GetString($Bytes, 0, $Bytes.Length - ($Bytes.Length % 2)), $u.GetString($Bytes, 1, ($Bytes.Length - 1) - (($Bytes.Length - 1) % 2)))
    }

    # Sabitleme kısayolunun kimliği: bilinen uygulama → 'appid:<kimlik>' (hedef .exe'si ya da, Windows 11'in hedefsiz kabuk
    # kısayolunda olduğu gibi, dosyanın içindeki AppUserModelID metniyle); diğerleri 'link:<hedef>'; hedefsiz ve
    # tanınmayan kısayol 'file:<ad>'.
    static [string] LinkKey([ExecutionContext] $Ctx, [string] $File, [string] $Target) {
        $known = [TaskbarPinsAction]::KnownAppIds()
        $norm = [TaskbarPinsAction]::NormTarget($Target)
        foreach ($id in @($known.Keys)) {
            if ($norm -and $norm -eq [TaskbarPinsAction]::NormTarget([string]$known[$id])) { return 'appid:' + $id.ToLowerInvariant() }
        }
        if ($norm) { return 'link:' + $norm }
        $bytes = $Ctx.Files.ReadBytes($File)
        $texts = @([TaskbarPinsAction]::Utf16Texts($bytes)) + @([System.Text.Encoding]::UTF8.GetString($bytes))
        foreach ($id in @($known.Keys)) {
            foreach ($t in $texts) { if ($t.IndexOf($id, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { return 'appid:' + $id.ToLowerInvariant() } }
        }
        return 'file:' + (Get-FaiFileName $File).ToLowerInvariant()
    }

    # Metinlerde ilk geçiş konumu (bayt yaklaşık); yoksa int.MaxValue.
    static [int] FirstIndex([string[]] $Texts, [string] $Needle) {
        $best = [int]::MaxValue
        for ($i = 0; $i -lt $Texts.Count; $i++) {
            $at = $Texts[$i].IndexOf($Needle, [System.StringComparison]::OrdinalIgnoreCase)
            if ($at -ge 0 -and ($at * 2 + $i) -lt $best) { $best = $at * 2 + $i }
        }
        return $best
    }

    # Mevcut sabitlemeler, sırayla: @{ Key; Label; File (Link ise kısayol yolu); Target / Aumid }.
    static [hashtable[]] Current([ExecutionContext] $Ctx) {
        $texts = [TaskbarPinsAction]::FavoritesText($Ctx)
        $items = New-Object 'System.Collections.Generic.List[hashtable]'
        foreach ($f in @($Ctx.Files.ListFiles((Expand-FaiPath ([TaskbarPinsAction]::PinnedDir))))) {
            if ($f -notlike '*.lnk') { continue }
            $target = ''
            try {
                $sc = $Ctx.Shortcuts.ReadShortcut($f)
                if ($null -ne $sc) { $target = [string]$sc['TargetPath'] }
            }
            catch { $target = '' }
            $name = (Get-FaiFileName $f)
            $items.Add(@{ Key = [TaskbarPinsAction]::LinkKey($Ctx, $f, $target); Label = $name; File = $f; Target = $target; Pos = [TaskbarPinsAction]::FirstIndex($texts, $name) })
        }
        $seen = @{}
        for ($i = 0; $i -lt $texts.Count; $i++) {
            foreach ($m in [regex]::Matches($texts[$i], [TaskbarPinsAction]::AumidPattern())) {
                $a = $m.Value
                if ($seen.ContainsKey($a.ToLowerInvariant())) { continue }
                $seen[$a.ToLowerInvariant()] = $true
                $items.Add(@{ Key = 'aumid:' + $a.ToLowerInvariant(); Label = $a; Aumid = $a; Pos = [TaskbarPinsAction]::FirstIndex($texts, $a) })
            }
        }
        # Kararlı sıralama: konum, sonra ad.
        $sorted = @($items.ToArray() | Sort-Object -Property @{ Expression = { [int]$_['Pos'] } }, @{ Expression = { [string]$_['Label'] } })
        return [hashtable[]]$sorted
    }

    [bool] Test([ExecutionContext] $Ctx) {
        $want = @($this.Wanted($Ctx) | ForEach-Object { [string]$_['Key'] })
        $have = @([TaskbarPinsAction]::Current($Ctx) | ForEach-Object { [string]$_['Key'] })
        return (($want -join '|') -eq ($have -join '|'))
    }

    static [hashtable] RegistrySnapshot([ExecutionContext] $Ctx, [string] $Path, [string] $Name) {
        if (-not $Ctx.Registry.ValueExists($Path, $Name)) { return @{ Exists = $false } }
        return @{ Exists = $true; Value = $Ctx.Registry.GetValue($Path, $Name); Kind = $Ctx.Registry.GetValueKind($Path, $Name) }
    }

    static [void] RegistryRestore([ExecutionContext] $Ctx, [string] $Path, [string] $Name, [hashtable] $Snap) {
        if ($Snap['Exists']) {
            $kind = [string]$Snap['Kind']
            $Ctx.Registry.SetValue($Path, $Name, (ConvertTo-FaiRegistryValue -Value $Snap['Value'] -Kind $kind), $kind)
        }
        elseif ($Ctx.Registry.ValueExists($Path, $Name)) { $Ctx.Registry.DeleteValue($Path, $Name) }
    }

    [hashtable] Snapshot([ExecutionContext] $Ctx) {
        $key = [TaskbarPinsAction]::TaskbandKey
        $band = New-Object System.Collections.ArrayList
        foreach ($n in @($Ctx.Registry.GetValueNames($key))) {
            [void]$band.Add(@{ Name = $n; Value = $Ctx.Registry.GetValue($key, $n); Kind = $Ctx.Registry.GetValueKind($key, $n) })
        }
        $links = New-Object System.Collections.ArrayList
        foreach ($f in @($Ctx.Files.ListFiles((Expand-FaiPath ([TaskbarPinsAction]::PinnedDir))))) {
            $b = [FileAction]::BackupFile($Ctx, $f)
            [void]$links.Add(@{ Name = (Get-FaiFileName $f); Bytes = $b['Bytes'] })
        }
        return @{
            Taskband = $band.ToArray()
            Pinned   = $links.ToArray()
            Layout   = [TaskbarPinsAction]::RegistrySnapshot($Ctx, [TaskbarPinsAction]::PolicyKey, 'StartLayoutFile')
            Locked   = [TaskbarPinsAction]::RegistrySnapshot($Ctx, [TaskbarPinsAction]::PolicyKey, 'LockedStartLayout')
            Xml      = [FileAction]::BackupFile($Ctx, (Expand-FaiPath ([TaskbarPinsAction]::XmlPath)))
        }
    }

    static [string] XmlEscape([string] $Text) { return [System.Security.SecurityElement]::Escape($Text) }

    [string] LayoutXml([ExecutionContext] $Ctx) {
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.AppendLine('<?xml version="1.0" encoding="utf-8"?>')
        [void]$sb.AppendLine('<LayoutModificationTemplate xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification" xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout" xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout" xmlns:taskbar="http://schemas.microsoft.com/Start/2014/TaskbarLayout" Version="1">')
        [void]$sb.AppendLine('  <CustomTaskbarLayoutCollection PinListPlacement="Replace">')
        [void]$sb.AppendLine('    <defaultlayout:TaskbarLayout>')
        [void]$sb.AppendLine('      <taskbar:TaskbarPinList>')
        foreach ($w in $this.Wanted($Ctx)) {
            $v = [TaskbarPinsAction]::XmlEscape([string]$w['Value'])
            switch ([string]$w['Kind']) {
                'AppId' { [void]$sb.AppendLine(('        <taskbar:DesktopApp DesktopApplicationID="{0}" />' -f $v)) }
                'Link' { [void]$sb.AppendLine(('        <taskbar:DesktopApp DesktopApplicationLinkPath="{0}" />' -f $v)) }
                'Aumid' { [void]$sb.AppendLine(('        <taskbar:UWA AppUserModelID="{0}" />' -f $v)) }
            }
        }
        [void]$sb.AppendLine('      </taskbar:TaskbarPinList>')
        [void]$sb.AppendLine('    </defaultlayout:TaskbarLayout>')
        [void]$sb.AppendLine('  </CustomTaskbarLayoutCollection>')
        [void]$sb.AppendLine('</LayoutModificationTemplate>')
        return $sb.ToString()
    }

    # Taskband değerleri ve kısayol dosyaları silinir (Gezgin yeniden başlayınca sabitleme kalmaz).
    static [void] ClearPins([ExecutionContext] $Ctx) {
        $key = [TaskbarPinsAction]::TaskbandKey
        foreach ($n in @($Ctx.Registry.GetValueNames($key))) { $Ctx.Registry.DeleteValue($key, $n) }
        foreach ($f in @($Ctx.Files.ListFiles((Expand-FaiPath ([TaskbarPinsAction]::PinnedDir))))) { $Ctx.Files.DeleteFile($f) }
    }

    [void] Apply([ExecutionContext] $Ctx) {
        if (-not $Ctx.Desktop.IsShellRunning()) { throw 'Etkileşimli kabuk (explorer.exe) çalışmıyor: görev çubuğu sabitlemeleri oturum açıkken uygulanır' }
        $before = $this.Snapshot($Ctx)
        $xmlFull = Expand-FaiPath ([TaskbarPinsAction]::XmlPath)
        [TaskbarPinsAction]::ClearPins($Ctx)
        $Ctx.Files.WriteBytes($xmlFull, [FileAction]::Encode($this.LayoutXml($Ctx), 'UTF8BOM'))
        $Ctx.Registry.SetValue([TaskbarPinsAction]::PolicyKey, 'StartLayoutFile', [TaskbarPinsAction]::XmlPath, 'ExpandString')
        $Ctx.Registry.SetValue([TaskbarPinsAction]::PolicyKey, 'LockedStartLayout', 1, 'DWord')
        try {
            $Ctx.Desktop.Refresh('Shell')
            for ($i = 0; $i -lt 15 -and -not $this.Test($Ctx); $i++) { $Ctx.Desktop.Wait(1000) }
        }
        finally {
            # Tek seferlik: ilke ve XML eski haline (sabitlemeler Taskband'de kalır).
            [TaskbarPinsAction]::RegistryRestore($Ctx, [TaskbarPinsAction]::PolicyKey, 'LockedStartLayout', [hashtable]$before['Locked'])
            [TaskbarPinsAction]::RegistryRestore($Ctx, [TaskbarPinsAction]::PolicyKey, 'StartLayoutFile', [hashtable]$before['Layout'])
            [FileAction]::RestoreFile($Ctx, $xmlFull, [hashtable]$before['Xml'])
        }
        if (-not $this.Test($Ctx)) {
            $have = @([TaskbarPinsAction]::Current($Ctx) | ForEach-Object { [string]$_['Label'] }) -join ', '
            throw ('Gezgin sabitleme düzenini uygulamadı (şu an: {0})' -f $have)
        }
    }

    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) {
        [TaskbarPinsAction]::ClearPins($Ctx)
        $key = [TaskbarPinsAction]::TaskbandKey
        foreach ($v in @($Snapshot['Taskband'])) {
            if ($null -eq $v) { continue }
            $kind = [string]$v['Kind']
            $Ctx.Registry.SetValue($key, [string]$v['Name'], (ConvertTo-FaiRegistryValue -Value $v['Value'] -Kind $kind), $kind)
        }
        $dir = Expand-FaiPath ([TaskbarPinsAction]::PinnedDir)
        foreach ($l in @($Snapshot['Pinned'])) {
            if ($null -eq $l -or -not $l['Bytes']) { continue }
            $Ctx.Files.WriteBytes(($dir.TrimEnd('\') + '\' + ([string]$l['Name'])), [Convert]::FromBase64String([string]$l['Bytes']))
        }
        [TaskbarPinsAction]::RegistryRestore($Ctx, [TaskbarPinsAction]::PolicyKey, 'LockedStartLayout', [hashtable]$Snapshot['Locked'])
        [TaskbarPinsAction]::RegistryRestore($Ctx, [TaskbarPinsAction]::PolicyKey, 'StartLayoutFile', [hashtable]$Snapshot['Layout'])
        [FileAction]::RestoreFile($Ctx, (Expand-FaiPath ([TaskbarPinsAction]::XmlPath)), [hashtable]$Snapshot['Xml'])
        # Gezgin bellekteki düzeni geri yazmasın diye hemen yeniden başlar.
        $Ctx.Desktop.Refresh('Shell')
    }

    [string] Describe() {
        $labels = New-Object 'System.Collections.Generic.List[string]'
        foreach ($p in @($this.Definition['Pins'])) {
            if ($p.Contains('AppId')) { $labels.Add([string]$p['AppId']) }
            elseif ($p.Contains('Link')) { $labels.Add((Get-FaiFileName ([string]$p['Link']))) }
            else { $labels.Add([string]$p['Aumid']) }
        }
        $shown = $labels -join ', '
        if (-not $shown) { $shown = '(yok)' }
        return ('Görev çubuğu sabitlemeleri yalnız: {0}' -f $shown)
    }

    [string] Preview([ExecutionContext] $Ctx) {
        $have = @([TaskbarPinsAction]::Current($Ctx) | ForEach-Object { [string]$_['Label'] }) -join ', '
        if (-not $have) { $have = 'yok' }
        $wantKeys = @($this.Wanted($Ctx) | ForEach-Object { [string]$_['Label'] })
        $missing = @($this.Definition['Pins']).Count - $wantKeys.Count
        $text = '{0} [şu an: {1}]' -f $this.Describe(), $have
        if ($missing -gt 0) { $text += (' — {0} kısayol yok, atlanır' -f $missing) }
        return $text
    }
}

# ShortcutAction: .lnk kısayolu oluşturur / günceller ya da siler. $Ctx.Shortcuts (özellikler) + $Ctx.Files (yedek).
#
#   @{ Type='Shortcut'; Path='%APPDATA%\Microsoft\Windows\Start Menu\Programs\Not Defteri.lnk'
#      TargetPath='%WINDIR%\System32\notepad.exe'; Arguments=''; WorkingDirectory='%USERPROFILE%' }
#   @{ Type='Shortcut'; Path='%PUBLIC%\Desktop\Microsoft Edge.lnk'; Ensure='Absent' }
# Özellikler: TargetPath (zorunlu), Arguments, WorkingDirectory, IconLocation, Description. Verilmeyen özellik Test'te
# karşılaştırılmaz. Snapshot kısayol dosyasının baytlarını tutar: geri alma birebir aynı .lnk'yi geri yazar.

class ShortcutAction : ActionBase {
    ShortcutAction([hashtable] $Definition) : base($Definition) { }

    static [string[]] PropertyNames() { return [string[]]@('TargetPath', 'Arguments', 'WorkingDirectory', 'IconLocation', 'Description') }

    static [string[]] Validate([object] $Def) {
        $e = New-Object 'System.Collections.Generic.List[string]'
        $allowed = @('Type', 'Path', 'Ensure') + [ShortcutAction]::PropertyNames()
        foreach ($m in (Get-FaiUnknownKeyError $Def $allowed)) { $e.Add($m) }
        if (-not $Def.Contains('Path')) { $e.Add('Path: zorunlu alan eksik') }
        elseif (-not (Test-FaiWindowsPath $Def['Path']) -or $Def['Path'] -notmatch '\.lnk$') { $e.Add('Path: .lnk ile biten mutlak yol olmalı') }
        $ensure = 'Present'
        if ($Def.Contains('Ensure')) {
            if ($Def['Ensure'] -isnot [string] -or @('Present', 'Absent') -cnotcontains $Def['Ensure']) { $e.Add('Ensure: Present ya da Absent olmalı') }
            else { $ensure = $Def['Ensure'] }
        }
        if ($ensure -eq 'Absent') {
            foreach ($p in [ShortcutAction]::PropertyNames()) { if ($Def.Contains($p)) { $e.Add("${p}: Ensure=Absent iken verilmez") } }
            return $e.ToArray()
        }
        if (-not $Def.Contains('TargetPath')) { $e.Add('TargetPath: zorunlu alan eksik') }
        foreach ($p in [ShortcutAction]::PropertyNames()) {
            if ($Def.Contains($p) -and $Def[$p] -isnot [string]) { $e.Add("${p}: metin olmalı") }
        }
        return $e.ToArray()
    }

    [string] FullPath() { return (Expand-FaiPath ([string]$this.Definition['Path'])) }

    [bool] IsAbsent() { return ([string]$this.Definition['Ensure'] -eq 'Absent') }

    # Windows kısayolu yolları açar ve büyük/küçük harfi korumaz: karşılaştırma açılmış ve harf duyarsız.
    [bool] Test([ExecutionContext] $Ctx) {
        $p = $this.FullPath()
        if ($this.IsAbsent()) { return (-not $Ctx.Files.FileExists($p)) }
        $now = $Ctx.Shortcuts.ReadShortcut($p)
        if ($null -eq $now) { return $false }
        foreach ($name in [ShortcutAction]::PropertyNames()) {
            if (-not $this.Definition.ContainsKey($name)) { continue }
            $want = Expand-FaiPath ([string]$this.Definition[$name])
            $have = Expand-FaiPath ([string]$now[$name])
            if ($want -ne $have) { return $false }
        }
        return $true
    }

    [hashtable] Snapshot([ExecutionContext] $Ctx) { return [FileAction]::BackupFile($Ctx, $this.FullPath()) }

    [void] Apply([ExecutionContext] $Ctx) {
        $p = $this.FullPath()
        if ($this.IsAbsent()) {
            if ($Ctx.Files.FileExists($p)) { $Ctx.Files.DeleteFile($p) }
            return
        }
        $props = @{}
        foreach ($name in [ShortcutAction]::PropertyNames()) {
            if ($this.Definition.ContainsKey($name)) { $props[$name] = [string]$this.Definition[$name] }
        }
        $Ctx.Shortcuts.WriteShortcut($p, $props)
    }

    [void] Revert([ExecutionContext] $Ctx, [hashtable] $Snapshot) { [FileAction]::RestoreFile($Ctx, $this.FullPath(), $Snapshot) }

    [string] Describe() {
        if ($this.IsAbsent()) { return ('Kısayol: {0} silinir' -f $this.Definition['Path']) }
        $tail = ''
        if ($this.Definition.ContainsKey('Arguments') -and $this.Definition['Arguments']) { $tail = ' ' + $this.Definition['Arguments'] }
        return ('Kısayol: {0} → {1}{2}' -f $this.Definition['Path'], $this.Definition['TargetPath'], $tail)
    }

    [string] Preview([ExecutionContext] $Ctx) {
        $now = $Ctx.Shortcuts.ReadShortcut($this.FullPath())
        if ($null -eq $now) { return ('{0} [şu an: yok]' -f $this.Describe()) }
        return ('{0} [şu an: → {1}]' -f $this.Describe(), $now['TargetPath'])
    }
}

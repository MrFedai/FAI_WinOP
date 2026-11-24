# Sahte dosya, kısayol, güç, betik, ses ve zamanlayıcı sağlayıcıları. Yazma çağrıları sayılır ve kaydedilir.

class FakeFileProvider : IFileProvider {
    # küçük harf yol → @{ Path; Bytes }
    [hashtable] $Files = @{}
    [int] $WriteCount = 0
    [System.Collections.ArrayList] $WriteLog = (New-Object System.Collections.ArrayList)

    FakeFileProvider() { }

    static [string] Norm([string] $Path) { return $Path.Replace('/', '\').ToLowerInvariant() }

    [void] Seed([string] $Path, [byte[]] $Bytes) { $this.Files[[FakeFileProvider]::Norm($Path)] = @{ Path = $Path; Bytes = $Bytes } }

    [void] SeedText([string] $Path, [string] $Text) { $this.Seed($Path, [System.Text.Encoding]::UTF8.GetBytes($Text)) }

    [bool] FileExists([string] $Path) { return $this.Files.ContainsKey([FakeFileProvider]::Norm($Path)) }

    [long] GetSize([string] $Path) {
        if (-not $this.FileExists($Path)) { return -1 }
        return ([byte[]]$this.Files[[FakeFileProvider]::Norm($Path)]['Bytes']).Length
    }

    [byte[]] ReadBytes([string] $Path) {
        if (-not $this.FileExists($Path)) { throw "Dosya yok: $Path" }
        return [byte[]]$this.Files[[FakeFileProvider]::Norm($Path)]['Bytes']
    }

    [void] WriteBytes([string] $Path, [byte[]] $Bytes) {
        $this.WriteCount++
        [void]$this.WriteLog.Add("WriteBytes $Path")
        $this.Files[[FakeFileProvider]::Norm($Path)] = @{ Path = $Path; Bytes = $Bytes }
    }

    [void] DeleteFile([string] $Path) {
        $this.WriteCount++
        [void]$this.WriteLog.Add("DeleteFile $Path")
        $this.Files.Remove([FakeFileProvider]::Norm($Path))
    }

    [string[]] ListFiles([string] $Directory) {
        $prefix = [FakeFileProvider]::Norm($Directory).TrimEnd('\') + '\'
        $found = New-Object 'System.Collections.Generic.List[string]'
        foreach ($k in $this.Files.Keys) {
            if ($k.StartsWith($prefix) -and $k.Substring($prefix.Length) -notmatch '\\') { $found.Add([string]$this.Files[$k]['Path']) }
        }
        $arr = $found.ToArray()
        [System.Array]::Sort($arr, [System.StringComparer]::OrdinalIgnoreCase)
        return $arr
    }

    # Klasörler örtük (dosya varsa klasör var); boş klasör zaten yok sayılır. Yalnız çağrıyı kaydeder.
    [void] DeleteEmptyDirectory([string] $Directory) {
        $this.WriteCount++
        [void]$this.WriteLog.Add("DeleteEmptyDirectory $Directory")
    }

    # Testte değiştirilebilir bilinen klasör tablosu.
    [hashtable] $KnownFolders = @{
        DesktopDirectory       = 'C:\Users\fai\Desktop'
        CommonDesktopDirectory = 'C:\Users\Public\Desktop'
        Programs               = 'C:\Users\fai\AppData\Roaming\Microsoft\Windows\Start Menu\Programs'
        CommonPrograms         = 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs'
        Startup                = 'C:\Users\fai\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup'
        CommonStartup          = 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup'
    }

    [string] GetKnownFolder([string] $Name) {
        if ($this.KnownFolders.ContainsKey($Name)) { return [string]$this.KnownFolders[$Name] }
        return ''
    }

    # Sıralı döküm: 'yol|base64'.
    [string[]] Dump() {
        $lines = New-Object 'System.Collections.Generic.List[string]'
        foreach ($k in $this.Files.Keys) { $lines.Add(('{0}|{1}' -f $k, [Convert]::ToBase64String([byte[]]$this.Files[$k]['Bytes']))) }
        $arr = $lines.ToArray()
        [System.Array]::Sort($arr, [System.StringComparer]::Ordinal)
        return $arr
    }
}

# Kısayolu FakeFileProvider'daki bir dosya olarak tutar (içerik = özelliklerin JSON'u): gerçekteki gibi kısayol
# bir dosyadır ve bayt yedeğiyle birebir geri gelir.
class FakeShortcutProvider : IShortcutProvider {
    [FakeFileProvider] $Files
    [int] $WriteCount = 0
    [System.Collections.ArrayList] $WriteLog = (New-Object System.Collections.ArrayList)

    FakeShortcutProvider([FakeFileProvider] $Files) { $this.Files = $Files }

    static [string[]] PropertyNames() { return [string[]]@('TargetPath', 'Arguments', 'WorkingDirectory', 'IconLocation', 'Description') }

    static [byte[]] Encode([hashtable] $Properties) {
        $clean = [ordered]@{}
        foreach ($n in [FakeShortcutProvider]::PropertyNames()) { $clean[$n] = [string]$Properties[$n] }
        return [System.Text.Encoding]::UTF8.GetBytes(($clean | ConvertTo-Json -Compress))
    }

    [void] Seed([string] $Path, [hashtable] $Properties) { $this.Files.Seed($Path, [FakeShortcutProvider]::Encode($Properties)) }

    [hashtable] ReadShortcut([string] $Path) {
        if (-not $this.Files.FileExists($Path)) { return $null }
        $text = [System.Text.Encoding]::UTF8.GetString($this.Files.ReadBytes($Path))
        $data = ConvertFrom-JsonText -Json $text
        $result = @{}
        foreach ($n in [FakeShortcutProvider]::PropertyNames()) { $result[$n] = [string]$data[$n] }
        return $result
    }

    [void] WriteShortcut([string] $Path, [hashtable] $Properties) {
        $this.WriteCount++
        [void]$this.WriteLog.Add("WriteShortcut $Path")
        # Dosya sağlayıcısının sayacını şişirmeden doğrudan yazar.
        $this.Files.Files[[FakeFileProvider]::Norm($Path)] = @{ Path = $Path; Bytes = [FakeShortcutProvider]::Encode($Properties) }
    }
}

class FakePowerProvider : IPowerProvider {
    [string] $Active = '381b4222-f694-41f0-9685-ff5bb260df2e'
    # küçük harf plan GUID'i → (küçük harf 'alt grup|ayar' → @{ AC; DC })
    [hashtable] $Schemes = @{}
    [int] $WriteCount = 0
    [System.Collections.ArrayList] $WriteLog = (New-Object System.Collections.ArrayList)

    FakePowerProvider() {
        $this.Schemes['381b4222-f694-41f0-9685-ff5bb260df2e'] = @{}
        $this.Schemes['8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'] = @{}
        $this.Schemes['a1841308-3541-4fab-bc81-f71556f20b4a'] = @{}
    }

    hidden [string] Resolve([string] $Scheme) {
        $s = $Scheme.ToLowerInvariant()
        if ($s -eq 'scheme_current') { return $this.Active }
        if ($s -eq 'scheme_balanced') { return '381b4222-f694-41f0-9685-ff5bb260df2e' }
        if ($s -eq 'scheme_min') { return '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' }
        if ($s -eq 'scheme_max') { return 'a1841308-3541-4fab-bc81-f71556f20b4a' }
        return $s
    }

    static [string] Key([string] $Subgroup, [string] $Setting) { return ('{0}|{1}' -f $Subgroup, $Setting).ToLowerInvariant() }

    [void] Seed([string] $Scheme, [string] $Subgroup, [string] $Setting, [long] $AC, [long] $DC) {
        $g = $this.Resolve($Scheme)
        if (-not $this.Schemes.ContainsKey($g)) { $this.Schemes[$g] = @{} }
        $this.Schemes[$g][[FakePowerProvider]::Key($Subgroup, $Setting)] = @{ AC = $AC; DC = $DC }
    }

    [string] GetActiveScheme() { return $this.Active }

    [string] ResolveScheme([string] $Scheme) {
        $g = $this.Resolve($Scheme)
        if ($this.Schemes.ContainsKey($g)) { return $g }
        return ''
    }

    [void] SetActiveScheme([string] $Scheme) {
        $this.WriteCount++
        [void]$this.WriteLog.Add("SetActiveScheme $Scheme")
        $g = $this.Resolve($Scheme)
        if (-not $this.Schemes.ContainsKey($g)) { throw "Güç planı yok: $Scheme" }
        $this.Active = $g
    }

    [long] GetValue([string] $Scheme, [string] $Subgroup, [string] $Setting, [bool] $OnAC) {
        $g = $this.Resolve($Scheme)
        $k = [FakePowerProvider]::Key($Subgroup, $Setting)
        if (-not $this.Schemes.ContainsKey($g) -or -not $this.Schemes[$g].ContainsKey($k)) { throw "Güç ayarı yok: $Scheme $Subgroup $Setting" }
        if ($OnAC) { return [long]$this.Schemes[$g][$k]['AC'] }
        return [long]$this.Schemes[$g][$k]['DC']
    }

    [void] SetValue([string] $Scheme, [string] $Subgroup, [string] $Setting, [bool] $OnAC, [long] $Value) {
        $this.WriteCount++
        [void]$this.WriteLog.Add("SetValue $Scheme $Subgroup $Setting $OnAC $Value")
        $g = $this.Resolve($Scheme)
        $k = [FakePowerProvider]::Key($Subgroup, $Setting)
        if (-not $this.Schemes.ContainsKey($g) -or -not $this.Schemes[$g].ContainsKey($k)) { throw "Güç ayarı yok: $Scheme $Subgroup $Setting" }
        if ($OnAC) { $this.Schemes[$g][$k]['AC'] = $Value }
        else { $this.Schemes[$g][$k]['DC'] = $Value }
    }

    # Sıralı döküm: 'etkin=...' + 'plan|alt grup|ayar|AC|DC'.
    [string[]] Dump() {
        $lines = New-Object 'System.Collections.Generic.List[string]'
        foreach ($g in $this.Schemes.Keys) {
            foreach ($k in $this.Schemes[$g].Keys) { $lines.Add(('{0}|{1}|{2}|{3}' -f $g, $k, $this.Schemes[$g][$k]['AC'], $this.Schemes[$g][$k]['DC'])) }
        }
        $arr = $lines.ToArray()
        [System.Array]::Sort($arr, [System.StringComparer]::Ordinal)
        return [string[]](@('etkin=' + $this.Active) + $arr)
    }
}

# Betikleri gerçekten çalıştırır (testler zararsız betik verir); Run çağrıları yazma sayılır.
# Betikler paylaşılan $State hashtable'ını FakeScriptHost::State üzerinden görebilir:
#   param($Snapshot) [FakeScriptHost]::State['x'] = 1
class FakeScriptHost : IScriptHost {
    static [hashtable] $State = @{}
    [int] $WriteCount = 0
    [int] $QueryCount = 0
    [System.Collections.ArrayList] $WriteLog = (New-Object System.Collections.ArrayList)

    FakeScriptHost() { }

    # Çalıştırma gerçek sağlayıcıyla aynı (5.1 boş çıktı tuzağı dahil).
    [object] Query([string] $Code, [object] $Argument) {
        $this.QueryCount++
        return [WindowsScriptHost]::Invoke($Code, $Argument)
    }

    [object] Run([string] $Code, [object] $Argument) {
        $this.WriteCount++
        [void]$this.WriteLog.Add('Run')
        return [WindowsScriptHost]::Invoke($Code, $Argument)
    }
}

class FakeAudioProvider : IAudioProvider {
    [bool] $Device = $true
    [int] $Volume = 50
    [bool] $Muted = $false
    [int] $WriteCount = 0
    [System.Collections.ArrayList] $WriteLog = (New-Object System.Collections.ArrayList)

    FakeAudioProvider() { }

    [bool] HasDevice() { return $this.Device }

    [int] GetVolume() {
        if (-not $this.Device) { throw 'Ses çıkış aygıtı yok' }
        return $this.Volume
    }

    [void] SetVolume([int] $Level) {
        $this.WriteCount++
        [void]$this.WriteLog.Add("SetVolume $Level")
        if (-not $this.Device) { throw 'Ses çıkış aygıtı yok' }
        $this.Volume = $Level
    }

    [bool] GetMute() {
        if (-not $this.Device) { throw 'Ses çıkış aygıtı yok' }
        return $this.Muted
    }

    [void] SetMute([bool] $Mute) {
        $this.WriteCount++
        [void]$this.WriteLog.Add("SetMute $Mute")
        if (-not $this.Device) { throw 'Ses çıkış aygıtı yok' }
        $this.Muted = $Mute
    }
}

class FakeTimerResolutionProvider : ITimerResolutionProvider {
    [bool] $Installed = $false
    [int] $Resolution = 0
    [int] $WriteCount = 0
    [System.Collections.ArrayList] $WriteLog = (New-Object System.Collections.ArrayList)

    FakeTimerResolutionProvider() { }

    [bool] IsInstalled() { return $this.Installed }

    [int] GetResolution() {
        if (-not $this.Installed) { return 0 }
        return $this.Resolution
    }

    [void] Install([int] $Resolution) {
        $this.WriteCount++
        [void]$this.WriteLog.Add("Install $Resolution")
        $this.Installed = $true
        $this.Resolution = $Resolution
    }

    [void] Uninstall() {
        $this.WriteCount++
        [void]$this.WriteLog.Add('Uninstall')
        $this.Installed = $false
        $this.Resolution = 0
    }
}

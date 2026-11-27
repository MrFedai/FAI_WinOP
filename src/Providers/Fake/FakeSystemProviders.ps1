# Sahte dosya, kısayol, güç, betik, ses, oturum kullanıcısı ve zamanlayıcı sağlayıcıları. Yazma çağrıları sayılır ve kaydedilir.

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
        if (-not $this.FileExists($Path)) { throw "File not found: $Path" }
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

    [string[]] FindFiles([string] $Directory, [string] $Filter) {
        $prefix = [FakeFileProvider]::Norm($Directory).TrimEnd('\') + '\'
        $found = New-Object 'System.Collections.Generic.List[string]'
        foreach ($k in $this.Files.Keys) {
            $full = [string]$this.Files[$k]['Path']
            if ($k.StartsWith($prefix) -and ($full.Split('\')[-1] -like $Filter)) { $found.Add($full) }
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

# Sahte görüntü: dosya içeriği 'FAKEIMG|<genişlik>|<yükseklik>|<RRGGBB>' (ASCII). Görüntü dosyalara FakeFileProvider
# üzerinden yazılır; bu sağlayıcı yalnız okur / üretir (yazma sayacı yok).
class FakeImageProvider : IImageProvider {
    [FakeFileProvider] $Files

    FakeImageProvider([FakeFileProvider] $Files) { $this.Files = $Files }

    static [byte[]] Encode([int] $Width, [int] $Height, [string] $Color) {
        return [System.Text.Encoding]::ASCII.GetBytes(('FAKEIMG|{0}|{1}|{2}' -f $Width, $Height, $Color.ToUpperInvariant()))
    }

    # Sahte görüntü değilse $null; değilse @(genişlik, yükseklik, renk).
    hidden [object[]] Parse([string] $Path) {
        if (-not $this.Files.FileExists($Path)) { return $null }
        $parts = [System.Text.Encoding]::ASCII.GetString($this.Files.ReadBytes($Path)).Split('|')
        if ($parts.Count -ne 4 -or $parts[0] -ne 'FAKEIMG') { return $null }
        return @([int]$parts[1], [int]$parts[2], $parts[3])
    }

    [int[]] GetSize([string] $Path) {
        $p = $this.Parse($Path)
        if ($null -eq $p) { return $null }
        return [int[]]@($p[0], $p[1])
    }

    [bool] IsSolid([string] $Path, [string] $Color) {
        $p = $this.Parse($Path)
        return ($null -ne $p -and [string]$p[2] -eq $Color.ToUpperInvariant())
    }

    [byte[]] NewSolid([int] $Width, [int] $Height, [string] $Color, [string] $Format) {
        return [FakeImageProvider]::Encode($Width, $Height, $Color)
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
        # WScript.Shell IconLocation'ı 'yol,indeks' döndürür; indeks yoksa ',0' eklenir (boş değer ',0' olur).
        if ($result['IconLocation'] -notmatch ',-?\d+$') { $result['IconLocation'] = $result['IconLocation'] + ',0' }
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
    # GUID → plan adı (CreateScheme verir).
    [hashtable] $Names = @{}
    [bool] $Hibernate = $false
    # Kopyalanamayan kaynak planlar (silinmiş varsayılan plan taklidi).
    [string[]] $NoCopy = @()
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
        if (-not $this.Schemes.ContainsKey($g)) { throw "Power plan not found: $Scheme" }
        $this.Active = $g
    }

    [long] GetValue([string] $Scheme, [string] $Subgroup, [string] $Setting, [bool] $OnAC) {
        $g = $this.Resolve($Scheme)
        $k = [FakePowerProvider]::Key($Subgroup, $Setting)
        if (-not $this.Schemes.ContainsKey($g) -or -not $this.Schemes[$g].ContainsKey($k)) { throw "Power setting not found: $Scheme $Subgroup $Setting" }
        if ($OnAC) { return [long]$this.Schemes[$g][$k]['AC'] }
        return [long]$this.Schemes[$g][$k]['DC']
    }

    [void] SetValue([string] $Scheme, [string] $Subgroup, [string] $Setting, [bool] $OnAC, [long] $Value) {
        $this.WriteCount++
        [void]$this.WriteLog.Add("SetValue $Scheme $Subgroup $Setting $OnAC $Value")
        $g = $this.Resolve($Scheme)
        $k = [FakePowerProvider]::Key($Subgroup, $Setting)
        if (-not $this.Schemes.ContainsKey($g) -or -not $this.Schemes[$g].ContainsKey($k)) { throw "Power setting not found: $Scheme $Subgroup $Setting" }
        if ($OnAC) { $this.Schemes[$g][$k]['AC'] = $Value }
        else { $this.Schemes[$g][$k]['DC'] = $Value }
    }

    [void] CreateScheme([string] $Source, [string] $Guid, [string] $Name) {
        $this.WriteCount++
        [void]$this.WriteLog.Add("CreateScheme $Source $Guid $Name")
        $src = $this.Resolve($Source)
        $g = $Guid.ToLowerInvariant()
        if (-not $this.Schemes.ContainsKey($src) -or $this.NoCopy -contains $src) { throw "Power plan could not be copied: $Source" }
        if ($this.Schemes.ContainsKey($g)) { throw "Power plan already exists: $Guid" }
        $copy = @{}
        foreach ($k in $this.Schemes[$src].Keys) { $copy[$k] = @{ AC = $this.Schemes[$src][$k]['AC']; DC = $this.Schemes[$src][$k]['DC'] } }
        $this.Schemes[$g] = $copy
        $this.Names[$g] = $Name
    }

    [void] DeleteScheme([string] $Guid) {
        $this.WriteCount++
        [void]$this.WriteLog.Add("DeleteScheme $Guid")
        $g = $Guid.ToLowerInvariant()
        if ($g -eq $this.Active) { throw "Active power plan cannot be deleted: $Guid" }
        $this.Schemes.Remove($g)
        $this.Names.Remove($g)
    }

    [bool] GetHibernate() { return $this.Hibernate }

    [void] SetHibernate([bool] $Enabled) {
        $this.WriteCount++
        [void]$this.WriteLog.Add("SetHibernate $Enabled")
        $this.Hibernate = $Enabled
    }

    # Sıralı döküm: 'etkin=...' + 'hibernate=...' + 'plan|alt grup|ayar|AC|DC'.
    [string[]] Dump() {
        $lines = New-Object 'System.Collections.Generic.List[string]'
        foreach ($g in $this.Schemes.Keys) {
            foreach ($k in $this.Schemes[$g].Keys) { $lines.Add(('{0}|{1}|{2}|{3}' -f $g, $k, $this.Schemes[$g][$k]['AC'], $this.Schemes[$g][$k]['DC'])) }
        }
        $arr = $lines.ToArray()
        [System.Array]::Sort($arr, [System.StringComparer]::Ordinal)
        return [string[]](@('etkin=' + $this.Active, 'hibernate=' + $this.Hibernate) + $arr)
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
        if (-not $this.Device) { throw 'No audio output device' }
        return $this.Volume
    }

    [void] SetVolume([int] $Level) {
        $this.WriteCount++
        [void]$this.WriteLog.Add("SetVolume $Level")
        if (-not $this.Device) { throw 'No audio output device' }
        $this.Volume = $Level
    }

    [bool] GetMute() {
        if (-not $this.Device) { throw 'No audio output device' }
        return $this.Muted
    }

    [void] SetMute([bool] $Mute) {
        $this.WriteCount++
        [void]$this.WriteLog.Add("SetMute $Mute")
        if (-not $this.Device) { throw 'No audio output device' }
        $this.Muted = $Mute
    }
}

# Sahte oturum kullanıcısı: varsayılan süreç = masaüstü sahibi (aynı hesap). Owner = $null → sahip bulunamadı.
class FakeSessionUserProvider : ISessionUserProvider {
    [hashtable] $Process = @{ Name = 'PC\fai'; Sid = 'S-1-5-21-1-2-3-1001' }
    [hashtable] $Owner = @{ Name = 'PC\fai'; Sid = 'S-1-5-21-1-2-3-1001' }

    FakeSessionUserProvider() { }

    FakeSessionUserProvider([hashtable] $Process, [hashtable] $Owner) {
        $this.Process = $Process
        $this.Owner = $Owner
    }

    [hashtable] GetProcessUser() { return $this.Process }
    [hashtable] GetSessionOwner() { return $this.Owner }
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

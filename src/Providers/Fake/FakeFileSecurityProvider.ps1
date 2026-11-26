# Sahte dosya sistemi güvenliği: öğeler bellekte (yol → tür, sahip, bağlantı mı, izin). Yollar '\' ya da '/' ile
# verilebilir, büyük / küçük harf duyarsız. Bilinmeyen yolun sahibi okunamaz (boş SID). Üretim bundle'ına girmez.

class FakeFileSecurityProvider : IFileSecurityProvider {
    # küçük harf yol → @{ Path; Type; Owner; Reparse; Acl }
    [hashtable] $Items = @{}
    [int] $WriteCount = 0
    [System.Collections.ArrayList] $WriteLog = (New-Object System.Collections.ArrayList)
    # Okuma dahil bütün çağrılar ('Yöntem yol'): "ProgramData'ya hiç dokunulmadı" testleri için.
    [System.Collections.ArrayList] $CallLog = (New-Object System.Collections.ArrayList)
    # CreateDirectory'nin yeni klasöre verdiği sahip (yükseltilmiş yönetici varsayılanı: Administrators).
    [string] $CreatorSid = 'S-1-5-32-544'

    FakeFileSecurityProvider() { }

    static [string] Norm([string] $Path) { return $Path.Replace('/', '\').TrimEnd('\').ToLowerInvariant() }

    # Varsayılan izin: %ProgramData% altındaki gibi kalıtılmış, Users yazabilir.
    static [hashtable] InheritedAcl([string] $Owner) {
        return @{
            Protected = $false; Owner = $Owner
            Rules     = @(
                @{ Sid = 'S-1-5-18'; Access = 'Full'; Deny = $false; Inherited = $true; Inherits = $true },
                @{ Sid = 'S-1-5-32-544'; Access = 'Full'; Deny = $false; Inherited = $true; Inherits = $true },
                @{ Sid = 'S-1-5-32-545'; Access = 'Write'; Deny = $false; Inherited = $true; Inherits = $true }
            )
        }
    }

    [void] Seed([string] $Path, [string] $Type, [string] $Owner, [bool] $Reparse) {
        $this.Items[[FakeFileSecurityProvider]::Norm($Path)] = @{
            Path = $Path.Replace('/', '\').TrimEnd('\'); Type = $Type; Owner = $Owner; Reparse = $Reparse
            Acl = [FakeFileSecurityProvider]::InheritedAcl($Owner)
        }
    }

    [void] SeedDirectory([string] $Path, [string] $Owner) { $this.Seed($Path, 'Directory', $Owner, $false) }
    [void] SeedFile([string] $Path, [string] $Owner) { $this.Seed($Path, 'File', $Owner, $false) }
    # Bağlantı (junction / symlink); Type: hedefin türü gibi görünen tür.
    [void] SeedLink([string] $Path, [string] $Type, [string] $Owner) { $this.Seed($Path, $Type, $Owner, $true) }

    hidden [hashtable] Item([string] $Path) { return $this.Items[[FakeFileSecurityProvider]::Norm($Path)] }

    hidden [void] Log([string] $Line) { [void]$this.CallLog.Add($Line) }

    hidden [void] LogWrite([string] $Line) {
        $this.WriteCount++
        [void]$this.WriteLog.Add($Line)
        [void]$this.CallLog.Add($Line)
    }

    [string] GetItemType([string] $Path) {
        $this.Log("GetItemType $Path")
        $i = $this.Item($Path)
        if ($null -eq $i) { return '' }
        return [string]$i['Type']
    }

    [bool] IsReparsePoint([string] $Path) {
        $this.Log("IsReparsePoint $Path")
        $i = $this.Item($Path)
        if ($null -eq $i) { return $false }
        return [bool]$i['Reparse']
    }

    [string] GetOwnerSid([string] $Path) {
        $this.Log("GetOwnerSid $Path")
        $i = $this.Item($Path)
        if ($null -eq $i) { return '' }
        return [string]$i['Owner']
    }

    [string[]] GetEntries([string] $Directory) {
        $this.Log("GetEntries $Directory")
        $prefix = [FakeFileSecurityProvider]::Norm($Directory) + '\'
        $found = New-Object 'System.Collections.Generic.List[string]'
        foreach ($k in $this.Items.Keys) {
            if ($k.StartsWith($prefix) -and $k.Substring($prefix.Length) -notmatch '\\') { $found.Add([string]$this.Items[$k]['Path']) }
        }
        $arr = $found.ToArray()
        [System.Array]::Sort($arr, [System.StringComparer]::OrdinalIgnoreCase)
        return $arr
    }

    [hashtable] GetAcl([string] $Path) {
        $this.Log("GetAcl $Path")
        $i = $this.Item($Path)
        if ($null -eq $i) { throw "Öğe yok: $Path" }
        return [hashtable]$i['Acl']
    }

    [void] CreateDirectory([string] $Path) {
        $this.LogWrite("CreateDirectory $Path")
        if ($null -eq $this.Item($Path)) { $this.SeedDirectory($Path, $this.CreatorSid) }
    }

    # Öğe ve (bağlantı değilse) altındakiler yeni yola taşınır.
    [void] MoveItem([string] $Path, [string] $Destination) {
        $this.LogWrite("MoveItem $Path -> $Destination")
        $from = [FakeFileSecurityProvider]::Norm($Path)
        if (-not $this.Items.ContainsKey($from)) { throw "Taşınacak öğe yok: $Path" }
        $to = $Destination.Replace('/', '\').TrimEnd('\')
        foreach ($k in @($this.Items.Keys)) {
            if ($k -ne $from -and -not $k.StartsWith($from + '\')) { continue }
            $item = $this.Items[$k]
            $this.Items.Remove($k)
            $item['Path'] = $to + ([string]$item['Path']).Substring($Path.Replace('/', '\').TrimEnd('\').Length)
            $this.Items[[FakeFileSecurityProvider]::Norm([string]$item['Path'])] = $item
        }
    }

    [void] SetRestrictedAcl([string] $Path, [string[]] $ReaderSid) {
        $this.LogWrite("SetRestrictedAcl $Path")
        $i = $this.Item($Path)
        if ($null -eq $i) { throw "Öğe yok: $Path" }
        $rules = New-Object System.Collections.ArrayList
        foreach ($sid in @('S-1-5-18', 'S-1-5-32-544')) {
            [void]$rules.Add(@{ Sid = $sid; Access = 'Full'; Deny = $false; Inherited = $false; Inherits = $true })
        }
        foreach ($sid in @($ReaderSid)) {
            if ($sid) { [void]$rules.Add(@{ Sid = $sid; Access = 'Read'; Deny = $false; Inherited = $false; Inherits = $true }) }
        }
        $i['Owner'] = 'S-1-5-32-544'
        $i['Acl'] = @{ Protected = $true; Owner = 'S-1-5-32-544'; Rules = $rules.ToArray() }
    }

    # Yolun herhangi bir çağrıda geçip geçmediği (ör. 'C:\ProgramData').
    [bool] Touched([string] $Prefix) {
        $p = $Prefix.Replace('/', '\').ToLowerInvariant()
        foreach ($line in $this.CallLog) { if (([string]$line).ToLowerInvariant().Contains($p)) { return $true } }
        return $false
    }
}

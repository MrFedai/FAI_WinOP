# Bellek içi sahte kayıt defteri (testler ve Engine-Smoke için). Yazma çağrılarını sayar ve kaydeder:
# dry-run'da WriteCount'un 0 kalması kabul kriteridir. Üretim bundle'ına girmez (Bundle.ps1 -IncludeFakes).

class FakeRegistryProvider : IRegistryProvider {
    # normalleştirilmiş yol → (küçük harf ad → @{ Name; Value; Kind })
    [hashtable] $Keys = @{}
    # normalleştirilmiş yol → ilk yazıldığı biçim (GetSubKeyNames adın büyük/küçük harfini korusun diye)
    [hashtable] $Spelling = @{}
    [int] $WriteCount = 0
    # Doluysa bu adlı değere SetValue hata fırlatır (hata yolu testleri için).
    [string] $FailOnName = ''
    [System.Collections.ArrayList] $WriteLog = (New-Object System.Collections.ArrayList)

    FakeRegistryProvider() { }

    static [string] NormPath([string] $Path) { return $Path.TrimEnd('\').ToLowerInvariant() }

    # Başlangıç durumu kurar (yazma sayılmaz).
    [void] Seed([string] $Path, [string] $Name, [object] $Value, [string] $Kind) {
        $this.Store($Path, $Name, $Value, $Kind)
    }

    hidden [void] Store([string] $Path, [string] $Name, [object] $Value, [string] $Kind) {
        $p = [FakeRegistryProvider]::NormPath($Path)
        if (-not $this.Keys.ContainsKey($p)) { $this.Keys[$p] = @{} }
        if (-not $this.Spelling.ContainsKey($p)) { $this.Spelling[$p] = $Path.TrimEnd('\') }
        $coerced = ConvertTo-FaiRegistryValue -Value $Value -Kind $Kind
        $this.Keys[$p][$Name.ToLowerInvariant()] = @{ Name = $Name; Value = $coerced; Kind = $Kind }
    }

    # Anahtar kendisi ya da bir alt anahtarı kayıtlıysa vardır (gerçekteki gibi üst anahtarlar örtük oluşur).
    [bool] KeyExists([string] $Path) {
        $p = [FakeRegistryProvider]::NormPath($Path)
        if ($this.Keys.ContainsKey($p)) { return $true }
        foreach ($k in $this.Keys.Keys) { if ($k.StartsWith($p + '\')) { return $true } }
        return $false
    }

    # Kayıtlı anahtarlardan türetilir (örtük üst anahtarlar dahil); sıralı.
    [string[]] GetSubKeyNames([string] $Path) {
        $p = [FakeRegistryProvider]::NormPath($Path)
        $names = @{}
        foreach ($k in $this.Keys.Keys) {
            if (-not $k.StartsWith($p + '\')) { continue }
            $original = $this.Spelling[$k]
            $rest = $original.Substring($p.Length + 1)
            $first = ($rest -split '\\')[0]
            if (-not $names.ContainsKey($first.ToLowerInvariant())) { $names[$first.ToLowerInvariant()] = $first }
        }
        return [string[]]@($names.Values | Sort-Object)
    }

    [void] DeleteEmptyKey([string] $Path) {
        $this.WriteCount++
        [void]$this.WriteLog.Add("DeleteEmptyKey $Path")
        $p = [FakeRegistryProvider]::NormPath($Path)
        # Gerçek sağlayıcı gibi: kovanın hemen altındaki anahtarı (HKCU:\Foo) silmez.
        if ($p -notmatch '^[^\\]+\\.+\\') { return }
        if (-not $this.Keys.ContainsKey($p) -or $this.Keys[$p].Count -gt 0) { return }
        foreach ($k in $this.Keys.Keys) { if ($k.StartsWith($p + '\')) { return } }
        $this.Keys.Remove($p)
    }

    [bool] ValueExists([string] $Path, [string] $Name) {
        $p = [FakeRegistryProvider]::NormPath($Path)
        return ($this.Keys.ContainsKey($p) -and $this.Keys[$p].ContainsKey($Name.ToLowerInvariant()))
    }

    [string[]] GetValueNames([string] $Path) {
        $p = [FakeRegistryProvider]::NormPath($Path)
        if (-not $this.Keys.ContainsKey($p)) { return [string[]]@() }
        return [string[]]@($this.Keys[$p].Values | ForEach-Object { [string]$_['Name'] } | Sort-Object)
    }

    [object] GetValue([string] $Path, [string] $Name) {
        if (-not $this.ValueExists($Path, $Name)) { return $null }
        return $this.Keys[[FakeRegistryProvider]::NormPath($Path)][$Name.ToLowerInvariant()]['Value']
    }

    # Değer yoksa boş metin.
    [string] GetValueKind([string] $Path, [string] $Name) {
        if (-not $this.ValueExists($Path, $Name)) { return '' }
        return [string]$this.Keys[[FakeRegistryProvider]::NormPath($Path)][$Name.ToLowerInvariant()]['Kind']
    }

    [void] SetValue([string] $Path, [string] $Name, [object] $Value, [string] $Kind) {
        $this.WriteCount++
        [void]$this.WriteLog.Add("SetValue $Path $Name")
        if ($this.FailOnName -and $Name -eq $this.FailOnName) { throw "Sahte yazma hatası: $Name" }
        $this.Store($Path, $Name, $Value, $Kind)
    }

    # Ham türlü (REG_NONE=0, REG_RESOURCE_LIST=8 vb.) başlangıç değeri kurar (yazma sayılmaz).
    [void] SeedRaw([string] $Path, [string] $Name, [int] $Type, [byte[]] $Bytes) {
        $this.StoreRaw($Path, $Name, $Type, $Bytes)
    }

    hidden [void] StoreRaw([string] $Path, [string] $Name, [int] $Type, [byte[]] $Bytes) {
        $p = [FakeRegistryProvider]::NormPath($Path)
        if (-not $this.Keys.ContainsKey($p)) { $this.Keys[$p] = @{} }
        if (-not $this.Spelling.ContainsKey($p)) { $this.Spelling[$p] = $Path.TrimEnd('\') }
        $kind = 'Unknown'
        $map = @{ 0 = 'None'; 1 = 'String'; 2 = 'ExpandString'; 3 = 'Binary'; 4 = 'DWord'; 7 = 'MultiString'; 11 = 'QWord' }
        if ($map.ContainsKey($Type)) { $kind = $map[$Type] }
        $copy = [byte[]]@($Bytes)
        $this.Keys[$p][$Name.ToLowerInvariant()] = @{ Name = $Name; Value = $copy; Kind = $kind; RawType = $Type; RawBytes = $copy }
    }

    # Ham tür + bayt (SeedRaw / SetRawValue ile yazılmışsa); diğer değerler için bilinen türden türetilir.
    [hashtable] GetRawValue([string] $Path, [string] $Name) {
        if (-not $this.ValueExists($Path, $Name)) { return $null }
        $e = $this.Keys[[FakeRegistryProvider]::NormPath($Path)][$Name.ToLowerInvariant()]
        if ($e.ContainsKey('RawType')) { return @{ Type = [int]$e['RawType']; Bytes = [byte[]]@($e['RawBytes']) } }
        $v = $e['Value']
        switch ([string]$e['Kind']) {
            'Binary' { return @{ Type = 3; Bytes = [byte[]]@($v) } }
            'DWord' { return @{ Type = 4; Bytes = [System.BitConverter]::GetBytes([int]$v) } }
            'QWord' { return @{ Type = 11; Bytes = [System.BitConverter]::GetBytes([long]$v) } }
            'String' { return @{ Type = 1; Bytes = [System.Text.Encoding]::Unicode.GetBytes([string]$v + [char]0) } }
            'ExpandString' { return @{ Type = 2; Bytes = [System.Text.Encoding]::Unicode.GetBytes([string]$v + [char]0) } }
            default { return @{ Type = 7; Bytes = [System.Text.Encoding]::Unicode.GetBytes((@($v) -join [string][char]0) + [string][char]0 + [char]0) } }
        }
        return $null
    }

    [void] SetRawValue([string] $Path, [string] $Name, [int] $Type, [byte[]] $Bytes) {
        $this.WriteCount++
        [void]$this.WriteLog.Add("SetRawValue $Path $Name")
        if ($this.FailOnName -and $Name -eq $this.FailOnName) { throw "Sahte yazma hatası: $Name" }
        $this.StoreRaw($Path, $Name, $Type, $Bytes)
    }

    [void] DeleteValue([string] $Path, [string] $Name) {
        $this.WriteCount++
        [void]$this.WriteLog.Add("DeleteValue $Path $Name")
        $p = [FakeRegistryProvider]::NormPath($Path)
        if ($this.Keys.ContainsKey($p)) { $this.Keys[$p].Remove($Name.ToLowerInvariant()) }
    }

    # Bütün değerlerin sıralı, karşılaştırılabilir dökümü (boş anahtarlar dahil değil): 'yol|ad|tür|değer'.
    [string[]] Dump() {
        $lines = New-Object 'System.Collections.Generic.List[string]'
        foreach ($p in $this.Keys.Keys) {
            foreach ($entry in $this.Keys[$p].Values) {
                $shown = (@($entry['Value']) | ForEach-Object { [string]$_ }) -join ','
                $lines.Add(('{0}|{1}|{2}|{3}' -f $p, $entry['Name'], $entry['Kind'], $shown))
            }
        }
        $arr = $lines.ToArray()
        [System.Array]::Sort($arr, [System.StringComparer]::Ordinal)
        return $arr
    }
}

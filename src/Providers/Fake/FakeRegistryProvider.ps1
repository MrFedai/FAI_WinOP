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

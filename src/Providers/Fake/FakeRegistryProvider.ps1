# Bellek içi sahte kayıt defteri (testler ve Engine-Smoke için). Yazma çağrılarını sayar ve kaydeder:
# dry-run'da WriteCount'un 0 kalması kabul kriteridir. Üretim bundle'ına girmez (Bundle.ps1 -IncludeFakes).

class FakeRegistryProvider : IRegistryProvider {
    # normalleştirilmiş yol → (küçük harf ad → @{ Name; Value; Kind })
    [hashtable] $Keys = @{}
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
        $coerced = ConvertTo-FaiRegistryValue -Value $Value -Kind $Kind
        $this.Keys[$p][$Name.ToLowerInvariant()] = @{ Name = $Name; Value = $coerced; Kind = $Kind }
    }

    [bool] KeyExists([string] $Path) { return $this.Keys.ContainsKey([FakeRegistryProvider]::NormPath($Path)) }

    [bool] ValueExists([string] $Path, [string] $Name) {
        $p = [FakeRegistryProvider]::NormPath($Path)
        return ($this.Keys.ContainsKey($p) -and $this.Keys[$p].ContainsKey($Name.ToLowerInvariant()))
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
